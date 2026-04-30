#!/bin/bash
# filepath: scripts/user-data.sh
# User data script for EC2 instances in Auto Scaling Group
# This script runs on instance startup

set -e

# Configuration
APP_NAME="my-app"
APP_DIR="/opt/${APP_NAME}"
AWS_REGION="us-east-1"
ECR_REPOSITORY="${APP_NAME}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Update system
log_info "Updating system packages..."
yum update -y

# Install Docker
log_info "Installing Docker..."
amazon-linux-extras install docker -y
systemctl enable docker
systemctl start docker
usermod -a -G docker ec2-user

# Install Docker Compose
log_info "Installing Docker Compose..."
curl -L "https://github.com/docker/compose/releases/download/v2.24.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Install AWS CLI v2
log_info "Installing AWS CLI v2..."
curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
./aws/install
rm -rf awscliv2.zip aws

# Install CloudWatch Agent
log_info "Installing CloudWatch Agent..."
yum install -y amazon-cloudwatch-agent

# Configure CloudWatch Agent
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'EOF'
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/${APP_NAME}/application.log",
            "log_group_name": "/aws/ec2/${APP_NAME}",
            "log_stream_name": "{instance_id}",
            "timestamp_format": "%Y-%m-%d %H:%M:%S"
          }
        ]
      }
    }
  },
  "metrics": {
    "metrics_collected": {
      "collectd": {
        "metrics_aggregation_interval": 60
      },
      "cpu": {
        "measurement": [
          "cpu_usage_idle",
          "cpu_usage_iowait",
          "cpu_usage_user",
          "cpu_usage_system"
        ],
        "metrics_collection_interval": 60,
        "resources": [
          "*"
        ]
      },
      "disk": {
        "measurement": [
          "disk_used_percent",
          "disk_inodes_free"
        ],
        "metrics_collection_interval": 60,
        "resources": [
          "/"
        ]
      },
      "mem": {
        "measurement": [
          "mem_used_percent",
          "mem_available"
        ],
        "metrics_collection_interval": 60
      }
    }
  }
}
EOF

# Create application directory
log_info "Creating application directory..."
mkdir -p ${APP_DIR}
mkdir -p /var/log/${APP_NAME}

# Configure Docker to use CloudWatch logging
mkdir -p /etc/docker
cat > /etc/docker/daemon.json << 'EOF'
{
  "log-driver": "awslogs",
  "log-opts": {
    "awslogs-group": "/aws/ec2/${APP_NAME}",
    "awslogs-region": "${AWS_REGION}",
    "awslogs-stream-prefix": "ecs"
  }
}
EOF

systemctl restart docker

# Pull latest Docker image
log_info "Pulling Docker image..."
$(aws ecr get-login-password --region ${AWS_REGION}) | docker login --username AWS --password-stdin ${ECR_REPOSITORY}.dkr.ecr.${AWS_REGION}.amazonaws.com
docker pull ${ECR_REPOSITORY}.dkr.ecr.${AWS_REGION}.amazonaws.com/${APP_NAME}:latest

# Create Docker Compose file
cat > ${APP_DIR}/docker-compose.yml << 'EOF'
version: '3.8'

services:
  app:
    image: my-app:latest
    container_name: my-app
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
      - AWS_REGION=us-east-1
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    restart: unless-stopped
    logging:
      driver: awslogs
      options:
        awslogs-group: /aws/ec2/my-app
        awslogs-region: us-east-1
        awslogs-stream-prefix: ecs
EOF

# Start application
log_info "Starting application..."
cd ${APP_DIR}
docker-compose up -d

# Start CloudWatch Agent
log_info "Starting CloudWatch Agent..."
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a start \
    -m ec2 \
    -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json

log_info "EC2 instance initialization complete!"