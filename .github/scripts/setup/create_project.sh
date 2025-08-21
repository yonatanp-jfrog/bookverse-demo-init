#!/usr/bin/env bash

set -e

# Source global configuration
source "$(dirname "$0")/config.sh"

# Validate environment variables
validate_environment

echo "🚀 Creating project ${PROJECT_KEY}..."

# Create detailed project payload with admin privileges
project_payload=$(jq -n '{
        "display_name": "'${PROJECT_DISPLAY_NAME}'",
        "admin_privileges": {
            "manage_members": true,
            "manage_resources": true,
            "index_resources": true
        },
        "storage_quota_bytes": -1,
        "project_key": "'${PROJECT_KEY}'"
    }')

echo "🔧 Creating project with configuration..."
echo "   Project Key: ${PROJECT_KEY}"
echo "   Display Name: ${PROJECT_DISPLAY_NAME}"
echo "   Admin Privileges: Full management enabled"
echo "   Storage Quota: Unlimited (-1)"
echo ""

# Make API call to create project
response_code=$(curl -s -o /dev/null -w "%{http_code}" \
  --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
  --header "Content-Type: application/json" \
  -X POST \
  -d "$project_payload" \
  "${JFROG_URL}/access/api/v1/projects")

# Handle response codes
if [ "$response_code" -eq 409 ]; then
  echo "⚠️  Project '${PROJECT_KEY}' already exists (HTTP $response_code)"
elif [ "$response_code" -eq 201 ]; then
  echo "✅ Project '${PROJECT_KEY}' created successfully (HTTP $response_code)"
else
  echo "❌ Failed to create project '${PROJECT_KEY}' (HTTP $response_code)"
  echo "   Expected: 201 (Created) or 409 (Already Exists)"
  echo "   Received: $response_code"
  exit 1
fi

echo ""
echo "✨ Project creation process completed!"
