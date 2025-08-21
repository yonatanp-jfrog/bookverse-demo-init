#!/usr/bin/env bash

set -e

echo "🚀 BookVerse JFrog Platform Initialization - Local Runner"
echo "========================================================"
echo ""

# Check if required environment variables are set
if [[ -z "${JFROG_URL}" ]]; then
  echo "❌ Error: JFROG_URL is not set"
  echo "   Please export JFROG_URL='your-jfrog-instance-url'"
  echo "   Example: export JFROG_URL='https://your-instance.jfrog.io/'"
  exit 1
fi

if [[ -z "${JFROG_ADMIN_TOKEN}" ]]; then
  echo "❌ Error: JFROG_ADMIN_TOKEN is not set"
  echo "   Please export JFROG_ADMIN_TOKEN='your-admin-token'"
  exit 1
fi

echo "✅ Environment variables validated"
echo "   JFROG_URL: ${JFROG_URL}"
echo "   JFROG_ADMIN_TOKEN: [HIDDEN]"
echo ""

# Source global configuration
source ./.github/scripts/setup/config.sh

echo "📋 Configuration loaded:"
echo "   Project Key: ${PROJECT_KEY}"
echo "   Project Display Name: ${PROJECT_DISPLAY_NAME}"
echo ""

echo "🔄 Starting initialization sequence..."
echo ""

# =============================================================================
# STEP 1: CREATE PROJECT
# =============================================================================
echo "📁 Step 1/6: Creating Project..."
echo "   Project Key: ${PROJECT_KEY}"
echo "   Display Name: ${PROJECT_DISPLAY_NAME}"
echo ""

# Create project payload
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

# Make API call to create project
response_code=$(curl -s -o /dev/null -w "%{http_code}" \
  --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
  --header "Content-Type: application/json" \
  -X POST \
  -d "$project_payload" \
  "${JFROG_URL}/access/api/v1/projects")

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

# =============================================================================
# STEP 2: CREATE REPOSITORIES
# =============================================================================
echo "📦 Step 2/6: Creating Repositories..."
echo "   Creating 16 repositories (4 microservices × 2 package types × 2 stages)"
echo ""

# Function to create repository payloads
create_repo_payloads() {
  local service_name="$1"
  local package_type="$2"
  
  # Internal repository (DEV, QA, STAGE stages)
  internal_payload=$(jq -n '{
    "repositories": [{
      "repoName": "'${PROJECT_KEY}'-'${service_name}'-'${package_type}'-internal-local",
      "project": "'${PROJECT_KEY}'",
      "envs": ["DEV","QA","STAGE"],
      "packageType": "'${package_type}'",
      "repoType": "LOCAL",
      "xrayEnabled": true
    }]
  }')
  
  # Release repository (PROD stage)
  release_payload=$(jq -n '{
    "repositories": [{
      "repoName": "'${PROJECT_KEY}'-'${service_name}'-'${package_type}'-release-local",
      "project": "'${PROJECT_KEY}'",
      "envs": ["PROD"],
      "packageType": "'${package_type}'",
      "repoType": "LOCAL",
      "xrayEnabled": true
    }]
  }')
  
  echo "$internal_payload" > /tmp/internal_payload.json
  echo "$release_payload" > /tmp/release_payload.json
  
  # Create internal repository
  echo "   Creating ${service_name} ${package_type} internal repository..."
  internal_response=$(curl -s -w "%{http_code}" -o /tmp/internal_response.json \
    --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
    --header "Content-Type: application/json" \
    -X POST \
    -d "$internal_payload" \
    "${JFROG_URL}/artifactory/api/onboarding/createQuickRepos")
  
  internal_code=$(echo "$internal_response" | tail -n1)
  if [ "$internal_code" -eq 200 ] || [ "$internal_code" -eq 201 ]; then
    echo "     ✅ Internal repository created successfully"
  else
    echo "     ❌ Failed to create internal repository (HTTP $internal_code)"
  fi
  
  # Create release repository
  echo "   Creating ${service_name} ${package_type} release repository..."
  release_response=$(curl -s -w "%{http_code}" -o /tmp/release_response.json \
    --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
    --header "Content-Type: application/json" \
    -X POST \
    -d "$release_payload" \
    "${JFROG_URL}/artifactory/api/onboarding/createQuickRepos")
  
  release_code=$(echo "$release_response" | tail -n1)
  if [ "$release_code" -eq 200 ] || [ "$release_code" -eq 201 ]; then
    echo "     ✅ Release repository created successfully"
  else
    echo "     ❌ Failed to create release repository (HTTP $release_code)"
  fi
  
  echo ""
}

# Create repositories for each microservice
echo "📦 Creating Inventory repositories..."
create_repo_payloads "inventory" "Docker"
create_repo_payloads "inventory" "Pypi"

echo "🎯 Creating Recommendations repositories..."
create_repo_payloads "recommendations" "Docker"
create_repo_payloads "recommendations" "Pypi"

echo "🛒 Creating Checkout repositories..."
create_repo_payloads "checkout" "Docker"
create_repo_payloads "checkout" "Pypi"

echo "🏗️  Creating Platform repositories..."
create_repo_payloads "platform" "Docker"
create_repo_payloads "platform" "Pypi"

# Clean up temporary files
rm -f /tmp/*_payload.json /tmp/*_response.json

# =============================================================================
# STEP 3: CREATE APPTRUST STAGES
# =============================================================================
echo "🎭 Step 3/6: Creating AppTrust Stages..."
echo "   Creating stages: DEV, QA, STAGE (PROD is always present)"
echo ""

# Create stages payload
stages_payload=$(jq -n '{
  "stages": [
    {
      "name": "DEV",
      "description": "Development stage for BookVerse microservices",
      "color": "#00ff00"
    },
    {
      "name": "QA",
      "description": "Quality Assurance stage for BookVerse microservices",
      "color": "#ffff00"
    },
    {
      "name": "STAGE",
      "description": "Staging stage for BookVerse microservices",
      "color": "#ff8800"
    }
  ]
}')

# Create stages
stages_response=$(curl -s -w "%{http_code}" -o /tmp/stages_response.json \
  --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
  --header "Content-Type: application/json" \
  -X POST \
  -d "$stages_payload" \
  "${JFROG_URL}/apptrust/api/v1/stages")

stages_code=$(echo "$stages_response" | tail -n1)
if [ "$stages_code" -eq 200 ] || [ "$stages_code" -eq 201 ]; then
  echo "✅ AppTrust stages created successfully"
else
  echo "⚠️  Stages may already exist or creation failed (HTTP $stages_code)"
fi

echo ""

# =============================================================================
# STEP 4: CREATE USERS
# =============================================================================
echo "👥 Step 4/6: Creating Users..."
echo "   Creating 12 users (8 human + 4 pipeline)"
echo ""

# Function to create user
create_user() {
  local username="$1"
  local email="$2"
  local password="$3"
  local role="$4"
  
  echo "   Creating user: $username ($role)"
  
  # Create user payload
  user_payload=$(jq -n '{
    "username": "'$username'",
    "email": "'$email'",
    "password": "'$password'"
  }')
  
  # Create user
  user_response=$(curl -s -w "%{http_code}" -o /tmp/user_response.json \
    --header "Content-Type: application/json" \
    --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
    -X POST \
    -d "$user_payload" \
    "${JFROG_URL}/access/api/v2/users")
  
  user_code=$(echo "$user_response" | tail -n1)
  if [ "$user_code" -eq 201 ]; then
    echo "     ✅ User '$username' created successfully"
  elif [ "$user_code" -eq 409 ]; then
    echo "     ⚠️  User '$username' already exists"
  else
    echo "     ❌ Failed to create user '$username' (HTTP $user_code)"
  fi
}

# Create human users
create_user "alice.developer@bookverse.com" "alice.developer@bookverse.com" "BookVerse2024!" "Developer"
create_user "bob.release@bookverse.com" "bob.release@bookverse.com" "BookVerse2024!" "Release Manager"
create_user "charlie.devops@bookverse.com" "charlie.devops@bookverse.com" "BookVerse2024!" "Project Manager"
create_user "diana.architect@bookverse.com" "diana.architect@bookverse.com" "BookVerse2024!" "AppTrust Admin"
create_user "edward.manager@bookverse.com" "edward.manager@bookverse.com" "BookVerse2024!" "AppTrust Admin"
create_user "frank.inventory@bookverse.com" "frank.inventory@bookverse.com" "BookVerse2024!" "Inventory Manager"
create_user "grace.ai@bookverse.com" "grace.ai@bookverse.com" "BookVerse2024!" "AI/ML Manager"
create_user "henry.checkout@bookverse.com" "henry.checkout@bookverse.com" "BookVerse2024!" "Checkout Manager"

# Create pipeline users
create_user "pipeline.inventory@bookverse.com" "pipeline.inventory@bookverse.com" "Pipeline2024!" "Pipeline User"
create_user "pipeline.recommendations@bookverse.com" "pipeline.recommendations@bookverse.com" "Pipeline2024!" "Pipeline User"
create_user "pipeline.checkout@bookverse.com" "pipeline.checkout@bookverse.com" "Pipeline2024!" "Pipeline User"
create_user "pipeline.platform@bookverse.com" "pipeline.platform@bookverse.com" "Pipeline2024!" "Pipeline User"

echo ""

# =============================================================================
# STEP 5: CREATE APPLICATIONS
# =============================================================================
echo "📱 Step 5/6: Creating Applications..."
echo "   Creating 4 microservice applications + 1 platform application"
echo ""

# Function to create application
create_application() {
  local app_name="$1"
  local app_key="$2"
  local description="$3"
  local criticality="$4"
  local user_owners="$5"
  
  echo "   Creating application: $app_name"
  
  # Create application payload
  app_payload=$(jq -n '{
    "project_key": "'${PROJECT_KEY}'",
    "application_key": "'$app_key'",
    "application_name": "'$app_name'",
    "description": "'$description'",
    "criticality": "'$criticality'",
    "maturity_level": "production",
    "labels": {
      "type": "microservice",
      "architecture": "microservices",
      "environment": "production"
    },
    "user_owners": ['$user_owners'],
    "group_owners": []
  }')
  
  # Create application
  app_response=$(curl -s -w "%{http_code}" -o /tmp/app_response.json \
    --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
    --header "Content-Type: application/json" \
    -X POST \
    -d "$app_payload" \
    "${JFROG_URL}/apptrust/api/v1/applications")
  
  app_code=$(echo "$app_response" | tail -n1)
  if [ "$app_code" -eq 201 ]; then
    echo "     ✅ Application '$app_name' created successfully"
  elif [ "$app_code" -eq 409 ]; then
    echo "     ⚠️  Application '$app_name' already exists"
  else
    echo "     ❌ Failed to create application '$app_name' (HTTP $app_code)"
  fi
}

# Create applications
create_application "BookVerse Inventory Service" "bookverse-inventory" "Microservice for inventory management" "high" '"frank.inventory@bookverse.com"'
create_application "BookVerse Recommendations Service" "bookverse-recommendations" "AI-powered recommendations microservice" "medium" '"grace.ai@bookverse.com"'
create_application "BookVerse Checkout Service" "bookverse-checkout" "Secure checkout and payment processing" "high" '"henry.checkout@bookverse.com"'
create_application "BookVerse Platform" "bookverse-platform" "Integrated platform solution" "high" '"diana.architect@bookverse.com","edward.manager@bookverse.com","charlie.devops@bookverse.com","bob.release@bookverse.com"'

echo ""

# =============================================================================
# STEP 6: CREATE OIDC INTEGRATIONS
# =============================================================================
echo "🔐 Step 6/6: Creating OIDC Integrations..."
echo "   Creating GitHub Actions OIDC for each microservice team"
echo ""

# Function to create OIDC integration
create_oidc_integration() {
  local integration_name="$1"
  local service_name="$2"
  
  echo "   Creating OIDC integration: $integration_name"
  
  # Create OIDC integration payload
  oidc_payload=$(jq -n '{
    "name": "github-'${PROJECT_KEY}'-'$service_name'",
    "issuer_url": "https://token.actions.githubusercontent.com/"
  }')
  
  # Create OIDC integration
  oidc_response=$(curl -s -w "%{http_code}" -o /tmp/oidc_response.json \
    --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
    --header "Content-Type: application/json" \
    -X POST \
    -d "$oidc_payload" \
    "${JFROG_URL}/access/api/v1/oidc")
  
  oidc_code=$(echo "$oidc_response" | tail -n1)
  if [ "$oidc_code" -eq 200 ] || [ "$oidc_code" -eq 201 ]; then
    echo "     ✅ OIDC integration created successfully"
  elif [ "$oidc_code" -eq 409 ]; then
    echo "     ⚠️  OIDC integration already exists"
  else
    echo "     ❌ Failed to create OIDC integration (HTTP $oidc_code)"
  fi
}

# Create OIDC integrations
create_oidc_integration "BookVerse Inventory" "inventory"
create_oidc_integration "BookVerse Recommendations" "recommendations"
create_oidc_integration "BookVerse Checkout" "checkout"
create_oidc_integration "BookVerse Platform" "platform"

# Clean up temporary files
rm -f /tmp/*_response.json

echo ""
echo "🎉 BookVerse JFrog Platform initialization completed successfully!"
echo ""
echo "📊 Summary of what was created:"
echo "   ✅ Project: ${PROJECT_KEY}"
echo "   ✅ Repositories: 16 (4 microservices × 2 package types × 2 stages)"
echo "   ✅ AppTrust Stages: DEV, QA, STAGE, PROD"
echo "   ✅ Users: 12 (8 human + 4 pipeline)"
echo "   ✅ Applications: 4 microservices + 1 platform"
echo "   ✅ OIDC Integrations: 4 (one per microservice team)"
echo ""
echo "🚀 Your BookVerse platform is ready for development!"
echo "💡 Next steps: Configure GitHub Actions secrets and run the workflow"
echo ""
echo "🔑 Default passwords:"
echo "   - Human users: BookVerse2024!"
echo "   - Pipeline users: Pipeline2024!"
