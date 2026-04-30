#!/bin/bash
# filepath: aws-codepipeline/scripts/before-install.sh
# CodeDeploy hook: BeforeInstall

set -e

APP_DIR="/opt/my-app"
APP_NAME="my-app"

echo "=== BeforeInstall Hook ==="

# Backup current application if exists
if [ -d "$APP_DIR" ]; then
    echo "Backing up current application..."
    timestamp=$(date +%Y%m%d%H%M%S)
    mv "$APP_DIR" "${APP_DIR}.backup.${timestamp}"
    echo "Backup created: ${APP_DIR}.backup.${timestamp}"
fi

# Create application directory
echo "Creating application directory..."
mkdir -p "$APP_DIR"
mkdir -p "/var/log/${APP_NAME}"

echo "=== BeforeInstall Complete ==="