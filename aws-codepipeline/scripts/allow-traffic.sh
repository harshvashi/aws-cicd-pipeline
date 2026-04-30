#!/bin/bash
# filepath: aws-codepipeline/scripts/allow-traffic.sh
# CodeDeploy hook: AllowTraffic (for Blue/Green deployments)

set -e

APP_NAME="my-app"

echo "=== AllowTraffic Hook ==="

# For Blue/Green deployments, this script runs after traffic is shifted
# It can be used for post-traffic-shift validation

# Get instance ID
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
echo "Instance ID: $INSTANCE_ID"

# Log traffic shift completion
echo "Traffic shift completed for instance: $INSTANCE_ID"

# Additional post-traffic validation can be added here
echo "=== AllowTraffic Complete ==="