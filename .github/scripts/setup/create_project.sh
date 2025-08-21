#!/bin/bash
set -e

# Source global configuration
source "$(dirname "$0")/config.sh"

echo "Creating BookVerse Project..."
echo "Project Key: ${PROJECT_KEY}"
echo "Project Name: ${PROJECT_DISPLAY_NAME}"
echo ""

# This script uses the JFrog CLI, which must be configured with the admin token
jf project create "${PROJECT_KEY}" --display-name="${PROJECT_DISPLAY_NAME}"

echo "✅ Project '${PROJECT_KEY}' created successfully!"
