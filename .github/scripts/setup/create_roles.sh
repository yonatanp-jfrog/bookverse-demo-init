#!/usr/bin/env bash

# =============================================================================
# CUSTOM ROLE CREATION SCRIPT
# =============================================================================
# Creates custom BookVerse roles with specific permissions
# =============================================================================

set -e

# Load configuration
source "$(dirname "$0")/config.sh"

echo ""
echo "🚀 Creating BookVerse custom roles"
echo "🔧 Project: $PROJECT_KEY"
echo "🔧 JFrog URL: $JFROG_URL"
echo ""

# Function to create a custom role
create_role() {
    local role_name="$1"
    local role_description="$2"
    local permissions="$3"
    local environments="$4"
    
    echo "Creating role: $role_name"
    echo "  Description: $role_description"
    echo "  Environments: $environments"
    
    # Build role JSON payload
    local role_payload=$(jq -n \
        --arg name "$role_name" \
        --arg desc "$role_description" \
        --arg project "$PROJECT_KEY" \
        --argjson perms "$permissions" \
        --argjson envs "$environments" \
        '{
            "name": $name,
            "description": $desc,
            "type": "CUSTOM",
            "environment": "PROJECT",
            "project_key": $project,
            "actions": $perms,
            "environments": $envs
        }')
    
    # Create role using JFrog API
    local response_code
    response_code=$(curl -s --write-out "%{http_code}" \
        --output /dev/null \
        --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
        --header "Content-Type: application/json" \
        --request POST \
        --data "$role_payload" \
        "${JFROG_URL}/access/api/v1/roles")
    
    case "$response_code" in
        201)
            echo "✅ Role '$role_name' created successfully"
            ;;
        409)
            echo "✅ Role '$role_name' already exists"
            ;;
        *)
            echo "⚠️  Role '$role_name' creation returned HTTP $response_code"
            ;;
    esac
    echo ""
}

# =============================================================================
# ROLE DEFINITIONS
# =============================================================================

# Kubernetes Image Pull Role - minimal permissions for container deployment
echo "Creating Kubernetes Image Pull role..."

k8s_permissions='[
    "READ_REPOSITORY",
    "READ_RELEASE_BUNDLE"
]'

k8s_environments='["PROD"]'

create_role \
    "bookverse-k8s-image-pull" \
    "Kubernetes Image Pull - Read access to PROD Docker repositories for container deployment" \
    "$k8s_permissions" \
    "$k8s_environments"

# =============================================================================
# SUMMARY
# =============================================================================

echo "📋 Role creation summary:"
echo ""
echo "✅ bookverse-k8s-image-pull"
echo "   • Purpose: Kubernetes container image pulling"
echo "   • Permissions: READ_REPOSITORY, READ_RELEASE_BUNDLE"
echo "   • Environments: PROD only"
echo "   • Use case: Container runtime image access"
echo ""

echo "🎯 Custom roles are now available for assignment to users"
echo ""
