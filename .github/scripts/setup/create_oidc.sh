#!/usr/bin/env bash

# =============================================================================
# SIMPLIFIED OIDC INTEGRATION SCRIPT
# =============================================================================
# Creates OIDC integrations without shared utility dependencies
# =============================================================================

set -e

# Load configuration
source "$(dirname "$0")/config.sh"

echo ""
echo "🚀 Creating OIDC integrations and identity mappings"
echo "🔧 Project: $PROJECT_KEY"
echo "🔧 JFrog URL: $JFROG_URL"
echo ""

# OIDC configuration definitions: service|username|display_name
OIDC_CONFIGS=(
    "inventory|frank.inventory@bookverse.com|BookVerse Inventory"
    "recommendations|grace.ai@bookverse.com|BookVerse Recommendations" 
    "checkout|henry.checkout@bookverse.com|BookVerse Checkout"
    "platform|diana.architect@bookverse.com|BookVerse Platform"
    "web|alice.developer@bookverse.com|BookVerse Web"
)

# Function to create OIDC integration
create_oidc_integration() {
    local service_name="$1"
    local username="$2"
    local display_name="$3"
    local integration_name="github-${PROJECT_KEY}-${service_name}"
    
    echo "Creating OIDC integration: $integration_name"
    echo "  Service: $service_name"
    echo "  User: $username"
    echo "  Display: $display_name"
    
    # Build OIDC integration payload
    local integration_payload=$(jq -n \
        --arg name "$integration_name" \
        --arg issuer_url "https://token.actions.githubusercontent.com" \
        --arg provider_type "GitHub" \
        '{
            "name": $name,
            "description": ("GitHub OIDC integration for " + $name),
            "issuer_url": $issuer_url,
            "provider_type": $provider_type,
            "audience": "jfrog-github"
        }')
    
    # Create OIDC integration
    local temp_response=$(mktemp)
    local response_code=$(curl -s --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
        --header "Content-Type: application/json" \
        -X POST \
        -d "$integration_payload" \
        --write-out "%{http_code}" \
        --output "$temp_response" \
        "${JFROG_URL}/access/api/v1/oidc")
    
    case "$response_code" in
        200|201)
            echo "✅ OIDC integration '$integration_name' created successfully (HTTP $response_code)"
            ;;
        409)
            echo "⚠️  OIDC integration '$integration_name' already exists (HTTP $response_code)"
            ;;
        400)
            # Check if it's the "already exists" error
            if grep -q -i "already exists\|integration.*exists" "$temp_response"; then
                echo "⚠️  OIDC integration '$integration_name' already exists (HTTP $response_code)"
            else
                echo "❌ Failed to create OIDC integration '$integration_name' (HTTP $response_code)"
                echo "Response body: $(cat "$temp_response")"
                rm -f "$temp_response"
                return 1
            fi
            ;;
        *)
            echo "❌ Failed to create OIDC integration '$integration_name' (HTTP $response_code)"
            echo "Response body: $(cat "$temp_response")"
            rm -f "$temp_response"
            return 1
            ;;
    esac
    
    rm -f "$temp_response"
    
    # Create identity mapping
    echo "Creating identity mapping for: $integration_name → $username"
    
    # Build identity mapping payload
    local mapping_payload=$(jq -n \
        --arg name "$integration_name" \
        --arg priority "1" \
        --arg claims_json "{\"repository\": \"yonatanp-jfrog/bookverse-${service_name}\"}" \
        --arg token_spec "{\"username\": \"$username\", \"scope\": \"applied-permissions/user\"}" \
        '{
            "name": $name,
            "description": ("Identity mapping for " + $name),
            "priority": ($priority | tonumber),
            "claims_json": $claims_json,
            "token_spec": ($token_spec | fromjson)
        }')
    
    # Create identity mapping
    local temp_response2=$(mktemp)
    local response_code2=$(curl -s --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
        --header "Content-Type: application/json" \
        -X POST \
        -d "$mapping_payload" \
        --write-out "%{http_code}" \
        --output "$temp_response2" \
        "${JFROG_URL}/access/api/v1/oidc/${integration_name}/identity_mappings")
    
    case "$response_code2" in
        200|201)
            echo "✅ Identity mapping for '$integration_name' created successfully (HTTP $response_code2)"
            ;;
        409)
            echo "⚠️  Identity mapping for '$integration_name' already exists (HTTP $response_code2)"
            ;;
        400)
            # Check if it's the "already exists" error
            if grep -q -i "already exists\|mapping.*exists" "$temp_response2"; then
                echo "⚠️  Identity mapping for '$integration_name' already exists (HTTP $response_code2)"
            else
                echo "❌ Failed to create identity mapping for '$integration_name' (HTTP $response_code2)"
                echo "Response body: $(cat "$temp_response2")"
                rm -f "$temp_response2"
                return 1
            fi
            ;;
        *)
            echo "❌ Failed to create identity mapping for '$integration_name' (HTTP $response_code2)"
            echo "Response body: $(cat "$temp_response2")"
            rm -f "$temp_response2"
            return 1
            ;;
    esac
    
    rm -f "$temp_response2"
    echo ""
}

echo "ℹ️  OIDC configurations to create:"
for oidc_data in "${OIDC_CONFIGS[@]}"; do
    IFS='|' read -r service_name username display_name <<< "$oidc_data"
    echo "   - $display_name → $username"
done

echo ""
echo "🚀 Processing ${#OIDC_CONFIGS[@]} OIDC configurations..."
echo ""

# Process each OIDC configuration
for oidc_data in "${OIDC_CONFIGS[@]}"; do
    IFS='|' read -r service_name username display_name <<< "$oidc_data"
    
    create_oidc_integration "$service_name" "$username" "$display_name"
done

echo "✅ OIDC integration creation completed successfully!"
echo ""
echo "🔐 Created OIDC Integrations Summary:"
for oidc_data in "${OIDC_CONFIGS[@]}"; do
    IFS='|' read -r service_name username display_name <<< "$oidc_data"
    echo "   - github-${PROJECT_KEY}-${service_name} → $username"
done

echo ""
echo "🎯 All OIDC integrations are now configured for GitHub Actions"
echo "   GitHub workflows can now authenticate to JFrog using OIDC tokens"
echo ""