#!/usr/bin/env bash

# =============================================================================
# BookVerse Platform - JFrog Event Subscription (Webhook) Creation Script
# =============================================================================
#
# This script creates the JFrog Platform Event Subscription webhook that
# automatically triggers GitHub repository dispatch events when AppTrust
# releases are completed, enabling seamless integration between JFrog Platform
# release management and GitHub Actions CI/CD workflows.
#
# 🏗️ WEBHOOK ARCHITECTURE:
#     - Event Subscription: JFrog Platform Event Subscription for AppTrust events
#     - Event Filter: Listens for 'release_completed' events from AppTrust domain
#     - GitHub Integration: Triggers repository dispatch to bookverse-helm repository
#     - Authentication: Uses GitHub token stored as JFrog secret for API access
#     - Payload Mapping: Maps AppTrust event data to GitHub Actions client payload
#
# 🚀 KEY FEATURES:
#     - Automated Deployment: Trigger downstream deployment workflows on release completion
#     - Cross-Platform Integration: Bridge JFrog AppTrust events with GitHub Actions
#     - Event-Driven Architecture: Enable reactive deployment patterns based on release events
#     - Platform Orchestration: Coordinate multi-repository workflows from central release events
#     - Secure Authentication: Uses encrypted GitHub token for API authentication
#
# 📊 BUSINESS LOGIC:
#     - Release Automation: Automatic deployment triggers when releases reach PROD stage
#     - GitOps Integration: Seamless integration with GitOps deployment workflows
#     - Multi-Service Coordination: Centralized release events for distributed services
#     - Audit Trail: Complete event tracking from release to deployment
#
# 🛠️ USAGE PATTERNS:
#     - Production Deployment: Automatic deployment triggers for production releases
#     - GitOps Workflows: Integration with ArgoCD and Kubernetes deployment pipelines
#     - Multi-Repository Coordination: Centralized event distribution to multiple repositories
#     - Release Management: Automated downstream processes on release completion
#
# Authors: BookVerse Platform Team
# Version: 1.0.0
# Last Updated: 2024
#
# Dependencies:
#   - config.sh (configuration management)
#   - JFrog Platform with Event Subscriptions API
#   - Valid admin authentication token
#   - GitHub token secret configured in JFrog Platform
#
# =============================================================================

set -euo pipefail

source "$(dirname "$0")/config.sh"

echo ""
echo "🔗 Creating JFrog Event Subscription Webhook for BookVerse Platform"
echo "🔧 JFrog URL: $JFROG_URL"
echo "🔧 Project: $PROJECT_KEY"
echo ""

# Check required environment variables
if [[ -z "${JFROG_URL:-}" ]]; then
    echo "❌ JFROG_URL is required"
    exit 1
fi

if [[ -z "${JFROG_ADMIN_TOKEN:-}" ]]; then
    echo "❌ JFROG_ADMIN_TOKEN is required"
    exit 1
fi

if [[ -z "${PROJECT_KEY:-}" ]]; then
    echo "❌ PROJECT_KEY is required"
    exit 1
fi

# GitHub organization for repository dispatch
GITHUB_ORG="${GITHUB_REPOSITORY_OWNER:-yonatanp-jfrog}"

# Event subscription configuration
WEBHOOK_KEY="${PROJECT_KEY}-release-to-github-action"
WEBHOOK_DESCRIPTION="${PROJECT_DISPLAY_NAME} release completion webhook for GitHub Actions integration"

echo "🔧 Webhook Configuration:"
echo "  Key: $WEBHOOK_KEY"
echo "  Target Repository: $GITHUB_ORG/bookverse-helm"
echo "  Event Type: release_completed"
echo "  Domain: app_trust"
echo ""

# Function to check if webhook already exists
webhook_exists() {
    local webhook_key="$1"
    local response
    response=$(curl -s -H "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
        "${JFROG_URL}/event/api/v1/subscriptions/${webhook_key}" 2>/dev/null || echo "")
    
    if echo "$response" | jq -e '.key' >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Function to create the event subscription webhook
create_event_subscription() {
    local webhook_key="$1"
    local description="$2"
    
    echo "🔗 Creating event subscription: $webhook_key"
    
    # Create the webhook payload based on the existing working configuration
    local webhook_payload
    webhook_payload=$(jq -n \
        --arg key "$webhook_key" \
        --arg description "$description" \
        --arg project_key "$PROJECT_KEY" \
        --arg github_org "$GITHUB_ORG" \
        --arg jfrog_url "$JFROG_URL" \
        '{
            "key": $key,
            "description": $description,
            "enabled": true,
            "event_filter": {
                "domain": "app_trust",
                "event_types": [
                    "release_completed"
                ],
                "criteria": {}
            },
            "handlers": [
                {
                    "handler_type": "custom-webhook",
                    "url": ("https://api.github.com/repos/" + $github_org + "/bookverse-helm/dispatches"),
                    "method": "POST",
                    "payload": ("{\n  \"event_type\": \"release_completed\",\n  \"client_payload\": {\n    \"domain\": \"app_trust\",\n    \"event_type\": \"release_completed\",\n    \"data\": {\n      \"application_key\": \"{{.data.application_key}}\",\n      \"application_version\": \"{{.data.application_version}}\",\n      \"stage\": \"{{.data.stage}}\"\n    },\n    \"subscription_key\": \"" + $key + "\",\n    \"jpd_origin\": \"" + $jfrog_url + "\",\n    \"source\": \"AppTrust\"\n  }\n}"),
                    "http_headers": [
                        {
                            "name": "Authorization",
                            "value": "Bearer {{.secrets.github_token}}"
                        },
                        {
                            "name": "Accept",
                            "value": "application/vnd.github+json"
                        },
                        {
                            "name": "Content-Type",
                            "value": "application/json"
                        }
                    ],
                    "secrets": [
                        {
                            "name": "github_token"
                        }
                    ]
                }
            ],
            "debug": false,
            "project_key": $project_key
        }')
    
    # Create the webhook
    local temp_response=$(mktemp)
    local response_code
    response_code=$(curl -s -w "%{http_code}" -X POST \
        -H "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "$webhook_payload" \
        --output "$temp_response" \
        "${JFROG_URL}/event/api/v1/subscriptions")
    
    local response_body
    response_body=$(cat "$temp_response")
    rm -f "$temp_response"
    
    case "$response_code" in
        200|201)
            echo "✅ Event subscription created successfully: $webhook_key"
            echo "📋 Webhook Details:"
            echo "  - Event Filter: app_trust domain, release_completed events"
            echo "  - Target: GitHub repository dispatch to $GITHUB_ORG/bookverse-helm"
            echo "  - Authentication: GitHub token secret (github_token)"
            echo "  - Project Scope: $PROJECT_KEY"
            return 0
            ;;
        409)
            echo "ℹ️  Event subscription already exists: $webhook_key"
            return 0
            ;;
        *)
            echo "❌ Failed to create event subscription: $webhook_key (HTTP $response_code)"
            echo "Response: $response_body"
            return 1
            ;;
    esac
}

# Function to validate webhook configuration
validate_webhook() {
    local webhook_key="$1"
    
    echo "🔍 Validating event subscription: $webhook_key"
    
    local webhook_config
    webhook_config=$(curl -s -H "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
        "${JFROG_URL}/event/api/v1/subscriptions/${webhook_key}" 2>/dev/null || echo "")
    
    if echo "$webhook_config" | jq -e '.key' >/dev/null 2>&1; then
        local enabled
        enabled=$(echo "$webhook_config" | jq -r '.enabled')
        local project_key
        project_key=$(echo "$webhook_config" | jq -r '.project_key // "none"')
        local event_types
        event_types=$(echo "$webhook_config" | jq -r '.event_filter.event_types[]' | tr '\n' ',' | sed 's/,$//')
        local target_url
        target_url=$(echo "$webhook_config" | jq -r '.handlers[0].url')
        
        echo "✅ Webhook validation successful:"
        echo "  - Key: $webhook_key"
        echo "  - Enabled: $enabled"
        echo "  - Project: $project_key"
        echo "  - Events: $event_types"
        echo "  - Target: $target_url"
        return 0
    else
        echo "❌ Webhook validation failed: $webhook_key not found or misconfigured"
        return 1
    fi
}

# Function to create GitHub token secret in JFrog platform
create_github_token_secret() {
    echo "🔑 Creating GitHub token secret in JFrog Platform..."
    
    # Check if GH_TOKEN is available
    if [[ -z "${GH_TOKEN:-}" ]]; then
        echo "❌ GH_TOKEN environment variable is required but not set"
        echo "   This token is needed for GitHub API authentication in webhooks"
        return 1
    fi
    
    # Create the secret payload
    local secret_payload
    secret_payload=$(jq -n \
        --arg name "github_token" \
        --arg value "$GH_TOKEN" \
        '{
            "name": $name,
            "value": $value
        }')
    
    # Create the secret in JFrog platform
    local temp_response=$(mktemp)
    local response_code
    response_code=$(curl -s -w "%{http_code}" -X POST \
        -H "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "$secret_payload" \
        --output "$temp_response" \
        "${JFROG_URL}/event/api/v1/secrets")
    
    local response_body
    response_body=$(cat "$temp_response")
    rm -f "$temp_response"
    
    case "$response_code" in
        200|201)
            echo "✅ GitHub token secret created successfully in JFrog Platform"
            echo "   Secret name: github_token"
            echo "   Usage: Webhook authentication for GitHub API calls"
            return 0
            ;;
        409)
            echo "ℹ️  GitHub token secret already exists in JFrog Platform"
            return 0
            ;;
        *)
            echo "❌ Failed to create GitHub token secret (HTTP $response_code)"
            echo "Response: $response_body"
            echo "   This secret is required for webhook GitHub API authentication"
            return 1
            ;;
    esac
}

# Main execution
echo "📋 Creating BookVerse Event Subscription Webhook..."
echo ""

# Check if webhook already exists
if webhook_exists "$WEBHOOK_KEY"; then
    echo "ℹ️  Event subscription already exists: $WEBHOOK_KEY"
    echo "🔍 Validating existing configuration..."
    
    if validate_webhook "$WEBHOOK_KEY"; then
        echo "✅ Existing webhook is properly configured"
    else
        echo "⚠️  Existing webhook validation failed"
        exit 1
    fi
else
    echo "🔗 Creating new event subscription..."
    
    # Create GitHub token secret in JFrog platform
    if ! create_github_token_secret; then
        echo "❌ Failed to create GitHub token secret - webhook creation aborted"
        exit 1
    fi
    
    # Create the webhook
    if create_event_subscription "$WEBHOOK_KEY" "$WEBHOOK_DESCRIPTION"; then
        echo ""
        echo "🔍 Validating newly created webhook..."
        if validate_webhook "$WEBHOOK_KEY"; then
            echo "✅ Webhook creation and validation successful"
        else
            echo "⚠️  Webhook created but validation failed"
            exit 1
        fi
    else
        echo "❌ Failed to create event subscription"
        exit 1
    fi
fi

echo ""
echo "🎉 BookVerse Event Subscription Webhook setup completed successfully!"
echo ""
echo "📋 Integration Details:"
echo "  - JFrog Events: AppTrust release_completed events"
echo "  - GitHub Actions: Repository dispatch to bookverse-helm"
echo "  - Deployment: Automatic GitOps deployment triggers"
echo "  - Authentication: Secure GitHub token integration"
echo ""
echo "🔄 Next Steps:"
echo "  - Verify GitHub token secret has repository dispatch permissions"
echo "  - Test webhook by completing a release to PROD stage"
echo "  - Monitor GitHub Actions workflows in bookverse-helm repository"
echo ""
