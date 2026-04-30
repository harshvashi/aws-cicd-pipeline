#!/bin/bash
# filepath: scripts/deploy.sh
# Application deployment script for EC2 Auto Scaling Group

set -e

# Configuration
APP_NAME="my-app"
AWS_REGION="us-east-1"
ASG_NAME="${APP_NAME}-asg"
DEPLOYMENT_GROUP="${APP_NAME}-deployment"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed"
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        log_error "jq is not installed"
        exit 1
    fi
    
    log_info "Prerequisites check passed"
}

# Get current instance IDs
get_instance_ids() {
    local instance_ids=$(aws autoscaling describe-auto-scaling-groups \
        --auto-scaling-group-names "$ASG_NAME" \
        --region "$AWS_REGION" \
        --query 'AutoScalingGroups[0].Instances[?HealthStatus==`Healthy`].InstanceId' \
        --output text)
    
    echo "$instance_ids"
}

# Deploy to a single instance
deploy_to_instance() {
    local instance_id=$1
    local app_version=$2
    
    log_info "Deploying to instance: $instance_id"
    
    # Copy deployment package to instance
    aws s3 cp s3://${APP_NAME}-deployments/latest.tar.gz /tmp/app.tar.gz --region "$AWS_REGION"
    
    # Execute deployment commands via SSM
    aws ssm send-command \
        --instance-ids "$instance_id" \
        --document-name "AWS-RunShellScript" \
        --parameters "commands=['cd /opt/${APP_NAME} && tar -xzf /tmp/app.tar.gz && systemctl restart ${APP_NAME}']" \
        --region "$AWS_REGION" \
        --output json
    
    log_info "Deployment initiated for instance: $instance_id"
}

# Wait for instance to become healthy
wait_for_healthy() {
    local instance_id=$1
    local max_attempts=30
    local attempt=1
    
    log_info "Waiting for instance $instance_id to become healthy..."
    
    while [ $attempt -le $max_attempts ]; do
        local health_status=$(aws autoscaling describe-auto-scaling-instances \
            --instance-ids "$instance_id" \
            --region "$AWS_REGION" \
            --query 'AutoScalingInstances[0].HealthStatus' \
            --output text)
        
        if [ "$health_status" == "Healthy" ]; then
            log_info "Instance $instance_id is healthy"
            return 0
        fi
        
        echo "Attempt $attempt/$max_attempts: Instance status = $health_status"
        sleep 10
        attempt=$((attempt + 1))
    done
    
    log_error "Instance $instance_id failed to become healthy"
    return 1
}

# Run smoke tests
run_smoke_tests() {
    local alb_dns=$1
    
    log_info "Running smoke tests against $alb_dns"
    
    # Test health endpoint
    if curl -f "http://${alb_dns}/health" > /dev/null 2>&1; then
        log_info "Health check passed"
    else
        log_error "Health check failed"
        return 1
    fi
    
    # Test API endpoint
    if curl -f "http://${alb_dns}/api/status" > /dev/null 2>&1; then
        log_info "API check passed"
    else
        log_error "API check failed"
        return 1
    fi
    
    log_info "All smoke tests passed"
    return 0
}

# Main deployment function
main() {
    local app_version=${1:-"latest"}
    
    log_info "Starting deployment for $APP_NAME version $app_version"
    
    check_prerequisites
    
    # Get ALB DNS name
    local alb_dns=$(aws elbv2 describe-load-balancers \
        --names "${APP_NAME}-alb" \
        --region "$AWS_REGION" \
        --query 'LoadBalancers[0].DNSName' \
        --output text)
    
    # Get instance IDs
    local instance_ids=$(get_instance_ids)
    
    if [ -z "$instance_ids" ]; then
        log_error "No healthy instances found in ASG"
        exit 1
    fi
    
    # Deploy to each instance
    for instance_id in $instance_ids; do
        deploy_to_instance "$instance_id" "$app_version"
        wait_for_healthy "$instance_id" || log_warn "Instance $instance_id may not be healthy"
    done
    
    # Run smoke tests
    run_smoke_tests "$alb_dns"
    
    log_info "Deployment completed successfully!"
}

# Handle script arguments
case "${1:-}" in
    -h|--help)
        echo "Usage: $0 [version]"
        echo ""
        echo "Arguments:"
        echo "  version    Application version to deploy (default: latest)"
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac