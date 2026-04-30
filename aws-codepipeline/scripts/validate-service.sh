#!/bin/bash
# filepath: aws-codepipeline/scripts/validate-service.sh
# CodeDeploy hook: ValidateService

set -e

APP_NAME="my-app"
MAX_RETRIES=30
RETRY_INTERVAL=5

echo "=== ValidateService Hook ==="

# Get instance ID
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
echo "Instance ID: $INSTANCE_ID"

# Get ALB DNS name
ALB_DNS=$(aws elbv2 describe-load-balancers \
    --names "${APP_NAME}-alb" \
    --query 'LoadBalancers[0].DNSName' \
    --output text)
echo "ALB DNS: $ALB_DNS"

# Wait for instance to register with target group
echo "Waiting for instance to register with target group..."
for i in $(seq 1 $MAX_RETRIES); do
    state=$(aws elbv2 describe-target-health \
        --target-group-arn "${APP_NAME}-tg-arn" \
        --targets Id=$INSTANCE_ID \
        --query 'TargetHealthDescriptions[0].TargetHealth.State' \
        --output text 2>/dev/null || echo "unknown")
    
    echo "Attempt $i/$MAX_RETRIES: Target state = $state"
    
    if [ "$state" == "healthy" ]; then
        echo "Instance is healthy"
        break
    fi
    
    if [ $i -eq $MAX_RETRIES ]; then
        echo "Error: Instance failed to become healthy"
        exit 1
    fi
    
    sleep $RETRY_INTERVAL
done

# Run health check
echo "Running health check..."
for i in $(seq 1 $MAX_RETRIES); do
    if curl -f "http://${ALB_DNS}/health" > /dev/null 2>&1; then
        echo "Health check passed"
        break
    fi
    
    echo "Attempt $i/$MAX_RETRIES: Health check failed"
    
    if [ $i -eq $MAX_RETRIES ]; then
        echo "Error: Health check failed after $MAX_RETRIES attempts"
        exit 1
    fi
    
    sleep $RETRY_INTERVAL
done

# Check application logs
echo "Checking application logs..."
docker logs "$APP_NAME" --tail 20

echo "=== ValidateService Complete ==="