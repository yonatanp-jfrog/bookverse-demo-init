#!/usr/bin/env bash

set -e

# Source global configuration
source "$(dirname "$0")/config.sh"

# Validate environment variables
validate_environment

FAILED=false

create_oidc_integration() {
  local integration_name="$1"
  local payload="$2"
  
  echo "🔐 Creating OIDC integration: $integration_name"
  
  response=$(curl -s -o /dev/null -w "%{http_code}" \
    --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
    --header "Content-Type: application/json" \
    -X POST \
    -d "$payload" \
    "${JFROG_URL}/access/api/v1/oidc")
  
  if [ "$response" -eq 200 ] || [ "$response" -eq 201 ]; then
    echo "✅ OIDC integration '$integration_name' created successfully (HTTP $response)"
  elif [ "$response" -eq 409 ]; then
    echo "⚠️  OIDC integration '$integration_name' already exists (HTTP $response)"
  else
    echo "❌ Failed to create OIDC integration '$integration_name' (HTTP $response)"
    FAILED=true
  fi
  echo ""
}

create_oidc_identity_mapping() {
  local integration_name="$1"
  local payload="$2"
  
  echo "🗺️  Creating identity mapping for: $integration_name"
  
  response=$(curl -s -o /dev/null -w "%{http_code}" \
    --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
    --header "Content-Type: application/json" \
    -X POST \
    -d "$payload" \
    "${JFROG_URL}/access/api/v1/oidc/$integration_name/identity_mappings")
  
  if [ "$response" -eq 200 ] || [ "$response" -eq 201 ]; then
    echo "✅ Identity mapping for '$integration_name' created successfully (HTTP $response)"
  elif [ "$response" -eq 409 ]; then
    echo "⚠️  Identity mapping for '$integration_name' already exists (HTTP $response)"
  else
    echo "❌ Failed to create identity mapping for '$integration_name' (HTTP $response)"
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
  echo "❌ One or more critical OIDC operations failed. Exiting with error."
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
