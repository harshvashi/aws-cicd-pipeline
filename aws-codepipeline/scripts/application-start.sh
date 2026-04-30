#!/bin/bash
# filepath: aws-codepipeline/scripts/application-start.sh
# CodeDeploy hook: ApplicationStart

set -e

APP_DIR="/opt/my-app"
APP_NAME="my-app"

echo "=== ApplicationStart Hook ==="

# Stop existing container if running
echo "Stopping existing container..."
docker-compose -f "$APP_DIR/docker-compose.yml" down 2>/dev/null || true

# Start application
echo "Starting application..."
cd "$APP_DIR"
docker-compose up -d

# Wait for application to start
echo "Waiting for application to start..."
sleep 10

# Check if container is running
if docker ps | grep -q "$APP_NAME"; then
    echo "Application container is running"
else
    echo "Warning: Application container may not be running"
    docker ps
fi

echo "=== ApplicationStart Complete ==="