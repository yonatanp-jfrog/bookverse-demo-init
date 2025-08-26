#!/usr/bin/env bash

set -e

# =============================================================================
# ERROR HANDLING
# =============================================================================

# Function to handle script errors
error_handler() {
    local line_no=$1
    local error_code=$2
    echo ""
    echo "❌ OIDC SCRIPT ERROR DETECTED!"
    echo "   Line: $line_no"
    echo "   Exit Code: $error_code"
    echo "   Command: ${BASH_COMMAND}"
    echo ""
    echo "🔍 DEBUGGING INFORMATION:"
    echo "   Environment: CI=${CI_ENVIRONMENT:-'Not set'}, VERBOSITY=${VERBOSITY:-'Not set'}"
    echo "   Working Directory: $(pwd)"
    echo "   Project: ${PROJECT_KEY:-'Not set'}"
    echo "   JFrog URL: ${JFROG_URL:-'Not set'}"
    echo ""
    echo "💡 TROUBLESHOOTING TIPS:"
    echo "   1. Check that JFROG_URL and JFROG_ADMIN_TOKEN are set correctly"
    echo "   2. Verify network connectivity to JFrog platform"
    echo "   3. Ensure the admin token has OIDC management permissions"
    echo "   4. Check if required users exist before creating identity mappings"
    echo "   5. Verify that GitHub Actions OIDC is enabled in JFrog"
    echo ""
    exit $error_code
}

# Set up error handling
trap 'error_handler ${LINENO} $?' ERR

# =============================================================================
# CI ENVIRONMENT DETECTION
# =============================================================================
# Detect if we're running in a CI environment (GitHub Actions, etc.)
CI_ENVIRONMENT="${CI:-false}"
if [[ -n "${GITHUB_ACTIONS}" ]] || [[ -n "${CI}" ]] || [[ "$CI_ENVIRONMENT" == "true" ]]; then
    export CI_ENVIRONMENT="true"
    echo "🤖 CI Environment detected - enhanced error reporting enabled"
else
    export CI_ENVIRONMENT="false"
fi

# Source global configuration
source "$(dirname "$0")/config.sh"

# Validate environment variables
validate_environment

FAILED=false

create_oidc_integration() {
  local display_name="$1"
  local payload="$2"
  
  # Extract the actual integration name from the payload
  local integration_name
  integration_name=$(echo "$payload" | jq -r '.name')

  echo "🔐 Creating OIDC integration: $display_name"
  echo "   Integration Name: $integration_name"

  # Enhanced debugging in CI environment
  if [ "$CI_ENVIRONMENT" = "true" ]; then
    echo "   🐛 DEBUG: Checking existing integration at ${JFROG_URL}/access/api/v1/oidc/${integration_name}"
  fi

  # Idempotency: check if provider already exists using the actual integration name
  local temp_response_check=$(mktemp)
  local get_code
  get_code=$(curl -s -w "%{http_code}" -o "$temp_response_check" \
    --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
    "${JFROG_URL}/access/api/v1/oidc/${integration_name}")
  
  if [ "$CI_ENVIRONMENT" = "true" ]; then
    echo "   🐛 DEBUG: Check response code: $get_code"
    if [ -s "$temp_response_check" ]; then
      echo "   🐛 DEBUG: Check response body: $(cat "$temp_response_check")"
    fi
  fi
  rm -f "$temp_response_check"
  
  if [ "$get_code" -eq 200 ]; then
    echo "⚠️  OIDC integration '$integration_name' already exists (HTTP $get_code)"
    echo ""
    return 0
  fi

  # Create provider
  local temp_response
  temp_response=$(mktemp)
  local code
  
  if [ "$CI_ENVIRONMENT" = "true" ]; then
    echo "   🐛 DEBUG: Creating integration with payload: $payload"
  fi
  
  code=$(curl -s -w "%{http_code}" -o "$temp_response" \
    --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
    --header "Content-Type: application/json" \
    -X POST \
    -d "$payload" \
    "${JFROG_URL}/access/api/v1/oidc")
  local body
  body=$(cat "$temp_response")
  rm -f "$temp_response"

  if [ "$CI_ENVIRONMENT" = "true" ]; then
    echo "   🐛 DEBUG: Create response code: $code"
    echo "   🐛 DEBUG: Create response body: $body"
  fi

  if [ "$code" -eq 200 ] || [ "$code" -eq 201 ]; then
    echo "✅ OIDC integration '$integration_name' created successfully (HTTP $code)"
  elif [ "$code" -eq 409 ] || echo "$body" | grep -qi "already exist"; then
    echo "⚠️  OIDC integration '$integration_name' already exists (HTTP $code)"
  else
    echo "❌ Failed to create OIDC integration '$integration_name' (HTTP $code)"
    echo "   Response: $body"
    FAILED=true
  fi
  echo ""
}

create_oidc_identity_mapping() {
  local integration_name="$1"
  local payload="$2"
  
  # Extract mapping name from payload for better identification
  local mapping_name
  mapping_name=$(echo "$payload" | jq -r '.name')

  echo "🗺️  Creating identity mapping for: $integration_name"
  echo "   Mapping Name: $mapping_name"

  if [ "$CI_ENVIRONMENT" = "true" ]; then
    echo "   🐛 DEBUG: Checking existing mappings at ${JFROG_URL}/access/api/v1/oidc/$integration_name/identity_mappings"
  fi

  # Idempotency: list mappings and skip if name already present
  local list_temp=$(mktemp)
  local list_code
  list_code=$(curl -s -w "%{http_code}" -o "$list_temp" \
    --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
    "${JFROG_URL}/access/api/v1/oidc/$integration_name/identity_mappings")
  local list_json
  list_json=$(cat "$list_temp")
  rm -f "$list_temp"
  
  if [ "$CI_ENVIRONMENT" = "true" ]; then
    echo "   🐛 DEBUG: List mappings response code: $list_code"
    echo "   🐛 DEBUG: List mappings response: $list_json"
  fi
  
  if [ "$list_code" -eq 200 ] && echo "$list_json" | jq -e --arg n "$mapping_name" '.mappings // .identity_mappings // . | map(select(.name==$n)) | length > 0' >/dev/null 2>&1; then
    echo "⚠️  Identity mapping '$mapping_name' already exists"
    echo ""
    return 0
  fi

  if [ "$CI_ENVIRONMENT" = "true" ]; then
    echo "   🐛 DEBUG: Creating identity mapping with payload: $payload"
  fi

  local temp_response
  temp_response=$(mktemp)
  local code
  code=$(curl -s -w "%{http_code}" -o "$temp_response" \
    --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
    --header "Content-Type: application/json" \
    -X POST \
    -d "$payload" \
    "${JFROG_URL}/access/api/v1/oidc/$integration_name/identity_mappings")
  local body
  body=$(cat "$temp_response")
  rm -f "$temp_response"

  if [ "$CI_ENVIRONMENT" = "true" ]; then
    echo "   🐛 DEBUG: Create mapping response code: $code"
    echo "   🐛 DEBUG: Create mapping response body: $body"
  fi

  if [ "$code" -eq 200 ] || [ "$code" -eq 201 ]; then
    echo "✅ Identity mapping '$mapping_name' created successfully (HTTP $code)"
  elif [ "$code" -eq 409 ] || echo "$body" | grep -qi "already exist"; then
    echo "⚠️  Identity mapping '$mapping_name' already exists (HTTP $code)"
  else
    echo "❌ Failed to create identity mapping '$mapping_name' (HTTP $code)"
    echo "   Response: $body"
    FAILED=true
  fi
  echo ""
}

echo "🔐 Creating OIDC integrations and identity mappings for BookVerse..."
echo "📡 API Endpoint: ${JFROG_URL}/access/api/v1/oidc"
echo "📋 Project: ${PROJECT_KEY}"
echo ""

# =============================================================================
# OIDC INTEGRATION PAYLOADS
# =============================================================================

# GitHub Actions OIDC integrations for each microservice team
inventory_integration_payload=$(jq -n '{"name": "github-'${PROJECT_KEY}'-inventory","issuer_url": "https://token.actions.githubusercontent.com/"}')

recommendations_integration_payload=$(jq -n '{"name": "github-'${PROJECT_KEY}'-recommendations","issuer_url": "https://token.actions.githubusercontent.com/"}')

checkout_integration_payload=$(jq -n '{"name": "github-'${PROJECT_KEY}'-checkout","issuer_url": "https://token.actions.githubusercontent.com/"}')

platform_integration_payload=$(jq -n '{"name": "github-'${PROJECT_KEY}'-platform","issuer_url": "https://token.actions.githubusercontent.com/"}')

web_integration_payload=$(jq -n '{"name": "github-'${PROJECT_KEY}'-web","issuer_url": "https://token.actions.githubusercontent.com/"}')

# =============================================================================
# IDENTITY MAPPING PAYLOADS
# =============================================================================

# Identity mappings for each team with appropriate permissions
inventory_identity_mapping_payload=$(jq -n '{
  "name": "github-'${PROJECT_KEY}'-inventory",
  "provider_name": "github-'${PROJECT_KEY}'-inventory",
  "claims": {"iss":"https://token.actions.githubusercontent.com"},
  "token_spec": {
    "username": "frank.inventory@bookverse.com",
    "scope": "applied-permissions/admin"
  },
  "priority": 1
}')

recommendations_identity_mapping_payload=$(jq -n '{
  "name": "github-'${PROJECT_KEY}'-recommendations",
  "provider_name": "github-'${PROJECT_KEY}'-recommendations",
  "claims": {"iss":"https://token.actions.githubusercontent.com"},
  "token_spec": {
    "username": "grace.ai@bookverse.com",
    "scope": "applied-permissions/admin"
  },
  "priority": 1
}')

checkout_identity_mapping_payload=$(jq -n '{
  "name": "github-'${PROJECT_KEY}'-checkout",
  "provider_name": "github-'${PROJECT_KEY}'-checkout",
  "claims": {"iss":"https://token.actions.githubusercontent.com"},
  "token_spec": {
    "username": "henry.checkout@bookverse.com",
    "scope": "applied-permissions/admin"
  },
  "priority": 1
}')

platform_identity_mapping_payload=$(jq -n '{
  "name": "github-'${PROJECT_KEY}'-platform",
  "provider_name": "github-'${PROJECT_KEY}'-platform",
  "claims": {"iss":"https://token.actions.githubusercontent.com"},
  "token_spec": {
    "username": "diana.architect@bookverse.com",
    "scope": "applied-permissions/admin"
  },
  "priority": 1
}')

web_identity_mapping_payload=$(jq -n '{
  "name": "github-'${PROJECT_KEY}'-web",
  "provider_name": "github-'${PROJECT_KEY}'-web",
  "claims": {"iss":"https://token.actions.githubusercontent.com"},
  "token_spec": {
    "username": "alice.developer@bookverse.com",
    "scope": "applied-permissions/admin"
  },
  "priority": 1
}')

# =============================================================================
# CREATE OIDC INTEGRATIONS
# =============================================================================

echo "🚀 Creating OIDC integrations for each microservice team..."
echo ""

create_oidc_integration "BookVerse Inventory" "$inventory_integration_payload"
create_oidc_integration "BookVerse Recommendations" "$recommendations_integration_payload"
create_oidc_integration "BookVerse Checkout" "$checkout_integration_payload"
create_oidc_integration "BookVerse Platform" "$platform_integration_payload"
create_oidc_integration "BookVerse Web" "$web_integration_payload"

# =============================================================================
# CREATE IDENTITY MAPPINGS
# =============================================================================

echo "🗺️  Creating identity mappings for each team..."
echo ""

create_oidc_identity_mapping "github-${PROJECT_KEY}-inventory" "$inventory_identity_mapping_payload"
create_oidc_identity_mapping "github-${PROJECT_KEY}-recommendations" "$recommendations_identity_mapping_payload"
create_oidc_identity_mapping "github-${PROJECT_KEY}-checkout" "$checkout_identity_mapping_payload"
create_oidc_identity_mapping "github-${PROJECT_KEY}-platform" "$platform_identity_mapping_payload"
create_oidc_identity_mapping "github-${PROJECT_KEY}-web" "$web_identity_mapping_payload"

# Check if any operations failed
if [ "$FAILED" = true ]; then
  echo ""
  echo "❌ OIDC SETUP FAILED"
  echo "================================"
  echo "One or more critical OIDC operations failed."
  echo ""
  echo "🔍 Common Issues:"
  echo "   • Missing OIDC feature in JFrog Platform"
  echo "   • Insufficient permissions for admin token"
  echo "   • Required users don't exist yet"
  echo "   • Network connectivity issues"
  echo "   • Invalid token or URL configuration"
  echo ""
  echo "💡 Next Steps:"
  echo "   1. Check the detailed error messages above"
  echo "   2. Verify all required users exist in the platform"
  echo "   3. Ensure admin token has OIDC management permissions"
  echo "   4. Try running with VERBOSITY=2 for more debug info"
  echo ""
  exit 1
fi

echo "✅ OIDC integration and identity mapping process completed!"
echo "📊 All integrations have been processed successfully."
echo ""
echo "📋 Summary of created OIDC integrations:"
echo ""
echo "📦 BookVerse Inventory:"
echo "     - Integration: github-${PROJECT_KEY}-inventory"
echo "     - Issuer: https://token.actions.githubusercontent.com/"
echo "     - Identity Mapping: frank.inventory@bookverse.com (Admin)"
echo ""
echo "🎯 BookVerse Recommendations:"
echo "     - Integration: github-${PROJECT_KEY}-recommendations"
echo "     - Issuer: https://token.actions.githubusercontent.com/"
echo "     - Identity Mapping: grace.ai@bookverse.com (Admin)"
echo ""
echo "🛒 BookVerse Checkout:"
echo "     - Integration: github-${PROJECT_KEY}-checkout"
echo "     - Issuer: https://token.actions.githubusercontent.com/"
echo "     - Identity Mapping: henry.checkout@bookverse.com (Admin)"
echo ""
echo "🏗️  BookVerse Platform:"
echo "     - Integration: github-${PROJECT_KEY}-platform"
echo "     - Issuer: https://token.actions.githubusercontent.com/"
echo "     - Identity Mapping: diana.architect@bookverse.com (Admin)"
echo ""
echo "🕸️  BookVerse Web:"
echo "     - Integration: github-${PROJECT_KEY}-web"
echo "     - Issuer: https://token.actions.githubusercontent.com/"
echo "     - Identity Mapping: alice.developer@bookverse.com (Admin)"
echo ""
echo "💡 Each OIDC integration enables secure GitHub Actions authentication"
echo "   for the respective microservice team with appropriate permissions."
