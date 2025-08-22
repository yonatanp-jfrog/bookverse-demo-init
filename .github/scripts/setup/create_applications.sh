#!/usr/bin/env bash

set -e

# Source global configuration
source "$(dirname "$0")/config.sh"

# Validate environment variables
validate_environment

FAILED=false

create_application() {
  local app_name="$1"
  local payload="$2"

  echo ""
  echo "📱 Creating application: $app_name"
  response=$(curl -s -o /dev/null -w "%{http_code}" \
    --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
    --header "Content-Type: application/json" \
    -X POST \
    -d "$payload" \
    "${JFROG_URL}/apptrust/api/v1/applications")

  if [ "$response" -eq 201 ]; then
    echo "✅ Application '$app_name' created successfully (HTTP $response)"
  elif [ "$response" -eq 409 ]; then
    echo "⚠️  Application '$app_name' already exists (HTTP $response)"
  else
    echo "❌ Failed to create application '$app_name' (HTTP $response)"
    FAILED=true
  fi
}

echo "🚀 Creating BookVerse applications using REST API..."
echo "📡 API Endpoint: ${JFROG_URL}/apptrust/api/v1/applications"
echo "📋 Project: ${PROJECT_KEY}"
echo ""

# =============================================================================
# BOOKVERSE INVENTORY MICROSERVICE APPLICATION
# =============================================================================
echo "📦 Creating BookVerse Inventory Microservice application..."

inventory_app_payload=$(jq -n \
  --arg project_key "${PROJECT_KEY}" \
  --arg app_key "bookverse-inventory" \
  --arg app_name "BookVerse Inventory Service" \
  --arg description "Microservice responsible for managing book inventory, stock levels, and availability tracking across all BookVerse locations" \
  --arg criticality "high" \
  --arg maturity "production" \
  --arg team "inventory-team" \
  --arg owner "frank.inventory@bookverse.com" \
  '{
    "project_key": $project_key,
    "application_key": $app_key,
    "application_name": $app_name,
    "description": $description,
    "criticality": $criticality,
    "maturity_level": $maturity,
    "labels": {
      "type": "microservice",
      "domain": "inventory",
      "architecture": "microservices",
      "environment": "production",
      "team": $team
    },
    "user_owners": [$owner],
    "group_owners": []
  }')

# =============================================================================
# BOOKVERSE RECOMMENDATIONS MICROSERVICE APPLICATION
# =============================================================================
echo "🎯 Creating BookVerse Recommendations Microservice application..."

recommendations_app_payload=$(jq -n \
  --arg project_key "${PROJECT_KEY}" \
  --arg app_key "bookverse-recommendations" \
  --arg app_name "BookVerse Recommendations Service" \
  --arg description "AI-powered microservice that provides personalized book recommendations based on user preferences, reading history, and collaborative filtering" \
  --arg criticality "medium" \
  --arg maturity "production" \
  --arg team "ai-ml-team" \
  --arg owner "grace.ai@bookverse.com" \
  '{
    "project_key": $project_key,
    "application_key": $app_key,
    "application_name": $app_name,
    "description": $description,
    "criticality": $criticality,
    "maturity_level": $maturity,
    "labels": {
      "type": "microservice",
      "domain": "recommendations",
      "architecture": "microservices",
      "environment": "production",
      "team": $team
    },
    "user_owners": [$owner],
    "group_owners": []
  }')

# =============================================================================
# BOOKVERSE CHECKOUT MICROSERVICE APPLICATION
# =============================================================================
echo "🛒 Creating BookVerse Checkout Microservice application..."

checkout_app_payload=$(jq -n \
  --arg project_key "${PROJECT_KEY}" \
  --arg app_key "bookverse-checkout" \
  --arg app_name "BookVerse Checkout Service" \
  --arg description "Secure microservice handling payment processing, order fulfillment, and transaction management for book purchases" \
  --arg criticality "high" \
  --arg maturity "production" \
  --arg team "checkout-team" \
  --arg owner "henry.checkout@bookverse.com" \
  '{
    "project_key": $project_key,
    "application_key": $app_key,
    "application_name": $app_name,
    "description": $description,
    "criticality": $criticality,
    "maturity_level": $maturity,
    "labels": {
      "type": "microservice",
      "domain": "checkout",
      "architecture": "microservices",
      "environment": "production",
      "team": $team,
      "compliance": "pci"
    },
    "user_owners": [$owner],
    "group_owners": []
  }')

# =============================================================================
# BOOKVERSE PLATFORM APPLICATION
# =============================================================================
echo "🏗️  Creating BookVerse Platform application..."

platform_app_payload=$(jq -n \
  --arg project_key "${PROJECT_KEY}" \
  --arg app_key "bookverse-platform" \
  --arg app_name "BookVerse Platform" \
  --arg description "Integrated platform solution combining all microservices with unified API gateway, monitoring, and operational tooling" \
  --arg criticality "high" \
  --arg maturity "production" \
  --arg team "platform" \
  '{
    "project_key": $project_key,
    "application_key": $app_key,
    "application_name": $app_name,
    "description": $description,
    "criticality": $criticality,
    "maturity_level": $maturity,
    "labels": {
      "type": "platform",
      "domain": "platform",
      "architecture": "microservices",
      "environment": "production",
      "team": $team
    },
    "user_owners": ["diana.architect@bookverse.com", "edward.manager@bookverse.com", "charlie.devops@bookverse.com", "bob.release@bookverse.com"],
    "group_owners": []
  }')

# Create all applications
create_application "BookVerse Inventory Service" "$inventory_app_payload"
create_application "BookVerse Recommendations Service" "$recommendations_app_payload"
create_application "BookVerse Checkout Service" "$checkout_app_payload"
create_application "BookVerse Platform" "$platform_app_payload"

# Check if any operations failed
if [ "$FAILED" = true ]; then
  echo "❌ One or more critical application creation operations failed. Exiting with error."
  exit 1
fi

echo ""
echo "✨ Application creation process completed!"
echo "📊 All BookVerse applications have been processed successfully."
echo ""
echo "📋 Summary of created applications:"
echo ""
echo "📦 BookVerse Inventory Service:"
echo "     - Application Key: bookverse-inventory"
echo "     - Criticality: High"
echo "     - Team: Inventory Team"
echo "     - Owner: Frank Inventory (Inventory Manager)"
echo "     - Description: Inventory management and stock tracking"
echo ""
echo "🎯 BookVerse Recommendations Service:"
echo "     - Application Key: bookverse-recommendations"
echo "     - Criticality: Medium"
echo "     - Team: AI/ML Team"
echo "     - Owner: Grace AI (AI/ML Manager)"
echo "     - Description: AI-powered book recommendations"
echo ""
echo "🛒 BookVerse Checkout Service:"
echo "     - Application Key: bookverse-checkout"
echo "     - Criticality: High (PCI Compliance)"
echo "     - Team: Checkout Team"
echo "     - Owner: Henry Checkout (Checkout Manager)"
echo "     - Description: Payment processing and order fulfillment"
echo ""
echo "🏗️  BookVerse Platform:"
echo "     - Application Key: bookverse-platform"
echo "     - Criticality: High"
echo "     - Team: Platform Team"
echo "     - Owners: Diana Architect, Edward Manager, Charlie DevOps, Bob Release Manager"
echo "     - Description: Integrated platform solution"
echo ""
echo "💡 Each microservice is managed by a dedicated team with specific ownership."
echo "   The Release Manager (Bob) oversees all services at the project level."
echo "   Applications are configured with appropriate criticality levels and maturity stages."
