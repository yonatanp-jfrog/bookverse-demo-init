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

inventory_app_payload=$(jq -n '{
  "project_key": "'${PROJECT_KEY}'",
  "application_key": "bookverse-inventory",
  "application_name": "BookVerse Inventory Service",
  "description": "Microservice responsible for managing book inventory, stock levels, and availability tracking across all BookVerse locations",
  "criticality": "high",
  "maturity_level": "production",
  "labels": {
    "type": "microservice",
    "domain": "inventory",
    "architecture": "microservices",
    "environment": "production",
    "team": "backend"
  },
  "user_owners": ["alice.developer@bookverse.com", "charlie.devops@bookverse.com"],
  "group_owners": []
}')

# =============================================================================
# BOOKVERSE RECOMMENDATIONS MICROSERVICE APPLICATION
# =============================================================================
echo "🎯 Creating BookVerse Recommendations Microservice application..."

recommendations_app_payload=$(jq -n '{
  "project_key": "'${PROJECT_KEY}'",
  "application_key": "bookverse-recommendations",
  "application_name": "BookVerse Recommendations Service",
  "description": "AI-powered microservice that provides personalized book recommendations based on user preferences, reading history, and collaborative filtering",
  "criticality": "medium",
  "maturity_level": "production",
  "labels": {
    "type": "microservice",
    "domain": "recommendations",
    "architecture": "microservices",
    "environment": "production",
    "team": "ai-ml"
  },
  "user_owners": ["alice.developer@bookverse.com", "diana.architect@bookverse.com"],
  "group_owners": []
}')

# =============================================================================
# BOOKVERSE CHECKOUT MICROSERVICE APPLICATION
# =============================================================================
echo "🛒 Creating BookVerse Checkout Microservice application..."

checkout_app_payload=$(jq -n '{
  "project_key": "'${PROJECT_KEY}'",
  "application_key": "bookverse-checkout",
  "application_name": "BookVerse Checkout Service",
  "description": "Secure microservice handling payment processing, order fulfillment, and transaction management for book purchases",
  "criticality": "high",
  "maturity_level": "production",
  "labels": {
    "type": "microservice",
    "domain": "checkout",
    "architecture": "microservices",
    "environment": "production",
    "team": "backend",
    "compliance": "pci"
  },
  "user_owners": ["bob.release@bookverse.com", "edward.manager@bookverse.com"],
  "group_owners": []
}')

# =============================================================================
# BOOKVERSE PLATFORM APPLICATION
# =============================================================================
echo "🏗️  Creating BookVerse Platform application..."

platform_app_payload=$(jq -n '{
  "project_key": "'${PROJECT_KEY}'",
  "application_key": "bookverse-platform",
  "application_name": "BookVerse Platform",
  "description": "Integrated platform solution combining all microservices with unified API gateway, monitoring, and operational tooling",
  "criticality": "high",
  "maturity_level": "production",
  "labels": {
    "type": "platform",
    "domain": "platform",
    "architecture": "microservices",
    "environment": "production",
    "team": "platform"
  },
  "user_owners": ["diana.architect@bookverse.com", "edward.manager@bookverse.com", "charlie.devops@bookverse.com"],
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
echo "     - Owners: Alice Developer, Charlie DevOps"
echo "     - Description: Inventory management and stock tracking"
echo ""
echo "🎯 BookVerse Recommendations Service:"
echo "     - Application Key: bookverse-recommendations"
echo "     - Criticality: Medium"
echo "     - Owners: Alice Developer, Diana Architect"
echo "     - Description: AI-powered book recommendations"
echo ""
echo "🛒 BookVerse Checkout Service:"
echo "     - Application Key: bookverse-checkout"
echo "     - Criticality: High (PCI Compliance)"
echo "     - Owners: Bob Release Manager, Edward Manager"
echo "     - Description: Payment processing and order fulfillment"
echo ""
echo "🏗️  BookVerse Platform:"
echo "     - Application Key: bookverse-platform"
echo "     - Criticality: High"
echo "     - Owners: Diana Architect, Edward Manager, Charlie DevOps"
echo "     - Description: Integrated platform solution"
echo ""
echo "💡 Each application is configured with appropriate criticality levels,"
echo "   maturity stages, and ownership assignments based on team roles."
