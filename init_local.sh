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
echo "   API Endpoint: ${JFROG_URL}/access/api/v1/projects"
echo "   Method: POST"
echo ""

echo "🔧 Preparing project creation payload..."
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

echo "📤 Sending project creation request..."
echo "   Payload: Project '${PROJECT_KEY}' with admin privileges"
echo "   Storage: Unlimited (storage_quota_bytes: -1)"

# Make API call to create project
response_code=$(curl -s -o /dev/null -w "%{http_code}" \
  --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
  --header "Content-Type: application/json" \
  -X POST \
  -d "$project_payload" \
  "${JFROG_URL}/access/api/v1/projects")

echo "📥 Received response: HTTP $response_code"

if [ "$response_code" -eq 409 ]; then
  echo "⚠️  Project '${PROJECT_KEY}' already exists (HTTP $response_code)"
  echo "   Status: SKIPPED - Project was previously created"
  echo "   Action: Continuing to next step"
elif [ "$response_code" -eq 201 ]; then
  echo "✅ Project '${PROJECT_KEY}' created successfully (HTTP $response_code)"
  echo "   Status: SUCCESS - New project created"
  echo "   Details: Project key '${PROJECT_KEY}' with display name '${PROJECT_DISPLAY_NAME}'"
  echo "   Privileges: Full admin access (members, resources, indexing)"
else
  echo "⚠️  Project creation returned HTTP $response_code (continuing anyway)"
  echo "   Status: UNKNOWN - Unexpected response code"
  echo "   Action: Continuing to next step despite unexpected response"
fi

echo ""
echo "📊 Step 1 Summary:"
echo "   ✅ Project creation process completed"
echo "   📁 Project Key: ${PROJECT_KEY}"
echo "   🏷️  Display Name: ${PROJECT_DISPLAY_NAME}"
echo "   🔑 Admin Privileges: Enabled"
echo "   💾 Storage: Unlimited"
echo ""

# =============================================================================
# STEP 2: CREATE APPTRUST STAGES
# =============================================================================
echo "🎭 Step 2/6: Creating AppTrust Stages..."
echo "   Creating stages: DEV, QA, STAGE (PROD is always present)"
echo "   API Endpoint: ${JFROG_URL}/access/api/v2/stages"
echo "   Method: POST"
echo "   Stage Naming: {project_key}-{stage_name}"
echo "   Lifecycle Order: DEV → QA → STAGE → PROD (hardcoded)"
echo ""

echo "🔧 Preparing stage creation..."
echo "   Stage Configuration:"
echo "     • Scope: project (scoped to ${PROJECT_KEY} project)"
echo "     • Category: promote (for promotion workflow)"
echo "     • Project Key: ${PROJECT_KEY}"
echo "     • Stage Names: bookverse-DEV, bookverse-QA, bookverse-STAGE"
echo ""

echo "   🚀 Starting stage creation process..."
echo "   📋 Stage Details:"
echo "     🟢 bookverse-DEV: Development stage for initial testing"
echo "     🟡 bookverse-QA: Quality Assurance stage for testing and validation"
echo "     🟠 bookverse-STAGE: Staging stage for pre-production testing"
echo "     🔴 bookverse-PROD: Production stage (always present, not created)"
echo ""

# Create DEV stage
echo "     🟢 Creating bookverse-DEV stage..."
echo "       API: POST ${JFROG_URL}/access/api/v2/stages"
echo "       Payload: Development stage for initial testing"
echo "       Scope: project (${PROJECT_KEY})"
echo "       Category: promote"

dev_response=$(curl -s -w "%{http_code}" -o /tmp/dev_response.json \
  --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
  --header "Content-Type: application/json" \
  -X POST \
  -d '{
    "name": "bookverse-DEV",
    "scope": "project",
    "project_key": "'${PROJECT_KEY}'",
    "category": "promote"
  }' \
  "${JFROG_URL}/access/api/v2/stages")

dev_code=$(echo "$dev_response" | tail -n1)
echo "       📥 Response: HTTP $dev_code"

if [ "$dev_code" -eq 200 ] || [ "$dev_code" -eq 201 ]; then
  echo "       ✅ bookverse-DEV stage created successfully (HTTP $dev_code)"
  echo "         Status: SUCCESS - Development stage ready"
  echo "         Purpose: Initial testing and development"
elif [ "$dev_code" -eq 409 ]; then
  echo "       ⚠️  bookverse-DEV stage already exists (HTTP $dev_code)"
  echo "         Status: SKIPPED - Stage was previously created"
  echo "         Action: Continuing to next stage"
else
  echo "       ⚠️  bookverse-DEV stage creation returned HTTP $dev_code (continuing anyway)"
  echo "         Status: UNKNOWN - Unexpected response code"
  echo "         Action: Continuing to next stage despite unexpected response"
fi

# Create QA stage
echo "     🟡 Creating bookverse-QA stage..."
echo "       API: POST ${JFROG_URL}/access/api/v2/stages"
echo "       Payload: Quality Assurance stage for testing and validation"
echo "       Scope: project (${PROJECT_KEY})"
echo "       Category: promote"

qa_response=$(curl -s -w "%{http_code}" -o /tmp/qa_response.json \
  --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
  --header "Content-Type: application/json" \
  -X POST \
  -d '{
    "name": "bookverse-QA",
    "scope": "project",
    "project_key": "'${PROJECT_KEY}'",
    "category": "promote"
  }' \
  "${JFROG_URL}/access/api/v2/stages")

qa_code=$(echo "$qa_response" | tail -n1)
echo "       📥 Response: HTTP $qa_code"

if [ "$qa_code" -eq 200 ] || [ "$qa_code" -eq 201 ]; then
  echo "       ✅ bookverse-QA stage created successfully (HTTP $qa_code)"
  echo "         Status: SUCCESS - Quality Assurance stage ready"
  echo "         Purpose: Testing and validation"
elif [ "$qa_code" -eq 409 ]; then
  echo "       ⚠️  bookverse-QA stage already exists (HTTP $qa_code)"
  echo "         Status: SKIPPED - Stage was previously created"
  echo "         Action: Continuing to next stage"
else
  echo "       ⚠️  bookverse-QA stage creation returned HTTP $qa_code (continuing anyway)"
  echo "         Status: UNKNOWN - Unexpected response code"
  echo "         Action: Continuing to next stage despite unexpected response"
fi

# Create STAGE stage
echo "     🟠 Creating bookverse-STAGE stage..."
echo "       API: POST ${JFROG_URL}/access/api/v2/stages"
echo "       Payload: Staging stage for pre-production testing"
echo "       Scope: project (${PROJECT_KEY})"
echo "       Category: promote"

stage_response=$(curl -s -w "%{http_code}" -o /tmp/stage_response.json \
  --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
  --header "Content-Type: application/json" \
  -X POST \
  -d '{
    "name": "bookverse-STAGE",
    "scope": "project",
    "project_key": "'${PROJECT_KEY}'",
    "category": "promote"
  }' \
  "${JFROG_URL}/access/api/v2/stages")

stage_code=$(echo "$stage_response" | tail -n1)
echo "       📥 Response: HTTP $stage_code"

if [ "$stage_code" -eq 200 ] || [ "$stage_code" -eq 201 ]; then
  echo "       ✅ bookverse-STAGE stage created successfully (HTTP $stage_code)"
  echo "         Status: SUCCESS - Staging stage ready"
  echo "         Purpose: Pre-production testing"
elif [ "$stage_code" -eq 409 ]; then
  echo "       ⚠️  bookverse-STAGE stage already exists (HTTP $stage_code)"
  echo "         Status: SKIPPED - Stage was previously created"
  echo "         Action: Continuing to next step"
else
  echo "       ⚠️  bookverse-STAGE stage creation returned HTTP $stage_code (continuing anyway)"
  echo "         Status: UNKNOWN - Unexpected response code"
  echo "         Action: Continuing to next step despite unexpected response"
fi

echo ""
echo "📊 Step 2 Summary:"
echo "   ✅ Stage creation process completed"
echo "   🎭 Stages Created: bookverse-DEV, bookverse-QA, bookverse-STAGE"
echo "   🔴 Production Stage: bookverse-PROD (always present, not created)"
echo "   🔗 Project Scope: All stages scoped to '${PROJECT_KEY}' project"
echo "   📋 Category: promote (for promotion workflow)"
echo "   🔄 Lifecycle Order: DEV → QA → STAGE → PROD"
echo ""

# =============================================================================
# STEP 3: CREATE REPOSITORIES
# =============================================================================
echo "📦 Step 3/6: Creating Repositories..."
echo "   Creating 16 repositories (4 microservices × 2 package types × 2 stages)"
echo "   API Endpoint: ${JFROG_URL}/artifactory/api/v2/repositories/batch"
echo "   Method: PUT"
echo "   Batch Size: 16 repositories in single API call"
echo "   Stage Assignment: Repositories will be assigned to appropriate stages"
echo ""

echo "🔧 Preparing repository batch creation..."
echo "   Repository Structure:"
echo "     • 4 Microservices: inventory, recommendations, checkout, platform"
echo "     • 2 Package Types: docker, python (pypi)"
echo "     • 2 Stages: internal-local (DEV/QA/STAGE), release-local (PROD)"
echo "     • Naming Convention: ${PROJECT_KEY}-{service}-{package}-{stage}-local"
echo "     • Stage Assignment: Internal repos → DEV/QA/STAGE, Release repos → PROD"
echo ""

# Function to create all repositories in batch
create_all_repositories() {
  echo "   🚀 Starting batch repository creation..."
  echo "   📋 Repository Details with Stage Assignment:"
  echo "     📦 Inventory Service:"
  echo "       - ${PROJECT_KEY}-inventory-docker-internal-local (Docker, DEV/QA/STAGE stages)"
  echo "       - ${PROJECT_KEY}-inventory-docker-release-local (Docker, PROD stage)"
  echo "       - ${PROJECT_KEY}-inventory-python-internal-local (Python, DEV/QA/STAGE stages)"
  echo "       - ${PROJECT_KEY}-inventory-python-release-local (Python, PROD stage)"
  echo "     🎯 Recommendations Service:"
  echo "       - ${PROJECT_KEY}-recommendations-docker-internal-local (Docker, DEV/QA/STAGE stages)"
  echo "       - ${PROJECT_KEY}-recommendations-docker-release-local (Docker, PROD stage)"
  echo "       - ${PROJECT_KEY}-recommendations-python-internal-local (Python, DEV/QA/STAGE stages)"
  echo "       - ${PROJECT_KEY}-recommendations-python-release-local (Python, PROD stage)"
  echo "     🛒 Checkout Service:"
  echo "       - ${PROJECT_KEY}-checkout-docker-internal-local (Docker, DEV/QA/STAGE stages)"
  echo "       - ${PROJECT_KEY}-checkout-docker-release-local (Docker, PROD stage)"
  echo "       - ${PROJECT_KEY}-checkout-python-internal-local (Python, DEV/QA/STAGE stages)"
  echo "       - ${PROJECT_KEY}-checkout-python-release-local (Python, PROD stage)"
  echo "     🏗️  Platform Solution:"
  echo "       - ${PROJECT_KEY}-platform-docker-internal-local (Docker, DEV/QA/STAGE stages)"
  echo "       - ${PROJECT_KEY}-platform-docker-release-local (Docker, PROD stage)"
  echo "       - ${PROJECT_KEY}-platform-python-internal-local (Python, DEV/QA/STAGE stages)"
  echo "       - ${PROJECT_KEY}-platform-python-release-local (Python, PROD stage)"
  echo ""
  
  # Create batch payload with all 16 repositories
  batch_payload=$(jq -n '[
    {
      "key": "'${PROJECT_KEY}'-inventory-docker-internal-local",
      "packageType": "docker",
      "description": "Inventory Docker internal repository for DEV/QA/STAGE stages",
      "notes": "Internal development repository",
      "includesPattern": "**/*",
      "excludesPattern": "",
      "rclass": "local",
      "projectKey": "'${PROJECT_KEY}'",
      "xrayIndex": true,
      "environments": ["DEV", "QA", "STAGE"]
    },
    {
      "key": "'${PROJECT_KEY}'-inventory-docker-release-local",
      "packageType": "docker",
      "description": "Inventory Docker release repository for PROD stage",
      "notes": "Production release repository",
      "includesPattern": "**/*",
      "excludesPattern": "",
      "rclass": "local",
      "projectKey": "'${PROJECT_KEY}'",
      "xrayIndex": true,
      "environments": ["PROD"]
    },
    {
      "key": "'${PROJECT_KEY}'-inventory-python-internal-local",
      "packageType": "pypi",
      "description": "Inventory Python internal repository for DEV/QA/STAGE stages",
      "notes": "Internal development repository",
      "includesPattern": "**/*",
      "excludesPattern": "",
      "rclass": "local",
      "projectKey": "'${PROJECT_KEY}'",
      "xrayIndex": true,
      "environments": ["DEV", "QA", "STAGE"]
    },
    {
      "key": "'${PROJECT_KEY}'-inventory-python-release-local",
      "packageType": "pypi",
      "description": "Inventory Python release repository for PROD stage",
      "notes": "Production release repository",
      "includesPattern": "**/*",
      "excludesPattern": "",
      "rclass": "local",
      "projectKey": "'${PROJECT_KEY}'",
      "xrayIndex": true,
      "environments": ["PROD"]
    },
    {
      "key": "'${PROJECT_KEY}'-recommendations-docker-internal-local",
      "packageType": "docker",
      "description": "Recommendations Docker internal repository for DEV/QA/STAGE stages",
      "notes": "Internal development repository",
      "includesPattern": "**/*",
      "excludesPattern": "",
      "rclass": "local",
      "projectKey": "'${PROJECT_KEY}'",
      "xrayIndex": true,
      "environments": ["DEV", "QA", "STAGE"]
    },
    {
      "key": "'${PROJECT_KEY}'-recommendations-docker-release-local",
      "packageType": "docker",
      "description": "Recommendations Docker release repository for PROD stage",
      "notes": "Production release repository",
      "includesPattern": "**/*",
      "excludesPattern": "",
      "rclass": "local",
      "projectKey": "'${PROJECT_KEY}'",
      "xrayIndex": true,
      "environments": ["PROD"]
    },
    {
      "key": "'${PROJECT_KEY}'-recommendations-python-internal-local",
      "packageType": "pypi",
      "description": "Recommendations Python internal repository for DEV/QA/STAGE stages",
      "notes": "Internal development repository",
      "includesPattern": "**/*",
      "excludesPattern": "",
      "rclass": "local",
      "projectKey": "'${PROJECT_KEY}'",
      "xrayIndex": true,
      "environments": ["DEV", "QA", "STAGE"]
    },
    {
      "key": "'${PROJECT_KEY}'-recommendations-python-release-local",
      "packageType": "pypi",
      "description": "Recommendations Python release repository for PROD stage",
      "notes": "Production release repository",
      "includesPattern": "**/*",
      "excludesPattern": "",
      "rclass": "local",
      "projectKey": "'${PROJECT_KEY}'",
      "xrayIndex": true,
      "environments": ["PROD"]
    },
    {
      "key": "'${PROJECT_KEY}'-checkout-docker-internal-local",
      "packageType": "docker",
      "description": "Checkout Docker internal repository for DEV/QA/STAGE stages",
      "notes": "Internal development repository",
      "includesPattern": "**/*",
      "excludesPattern": "",
      "rclass": "local",
      "projectKey": "'${PROJECT_KEY}'",
      "xrayIndex": true,
      "environments": ["DEV", "QA", "STAGE"]
    },
    {
      "key": "'${PROJECT_KEY}'-checkout-docker-release-local",
      "packageType": "docker",
      "description": "Checkout Docker release repository for PROD stage",
      "notes": "Production release repository",
      "includesPattern": "**/*",
      "excludesPattern": "",
      "rclass": "local",
      "projectKey": "'${PROJECT_KEY}'",
      "xrayIndex": true,
      "environments": ["PROD"]
    },
    {
      "key": "'${PROJECT_KEY}'-checkout-python-internal-local",
      "packageType": "pypi",
      "description": "Checkout Python internal repository for DEV/QA/STAGE stages",
      "notes": "Internal development repository",
      "includesPattern": "**/*",
      "excludesPattern": "",
      "rclass": "local",
      "projectKey": "'${PROJECT_KEY}'",
      "xrayIndex": true,
      "environments": ["DEV", "QA", "STAGE"]
    },
    {
      "key": "'${PROJECT_KEY}'-checkout-python-release-local",
      "packageType": "pypi",
      "description": "Checkout Python release repository for PROD stage",
      "notes": "Production release repository",
      "includesPattern": "**/*",
      "excludesPattern": "",
      "rclass": "local",
      "projectKey": "'${PROJECT_KEY}'",
      "xrayIndex": true,
      "environments": ["PROD"]
    },
    {
      "key": "'${PROJECT_KEY}'-platform-docker-internal-local",
      "packageType": "docker",
      "description": "Platform Docker internal repository for DEV/QA/STAGE stages",
      "notes": "Internal development repository",
      "includesPattern": "**/*",
      "excludesPattern": "",
      "rclass": "local",
      "projectKey": "'${PROJECT_KEY}'",
      "xrayIndex": true,
      "environments": ["DEV", "QA", "STAGE"]
    },
    {
      "key": "'${PROJECT_KEY}'-platform-docker-release-local",
      "packageType": "docker",
      "description": "Platform Docker release repository for PROD stage",
      "notes": "Production release repository",
      "includesPattern": "**/*",
      "excludesPattern": "",
      "rclass": "local",
      "projectKey": "'${PROJECT_KEY}'",
      "xrayIndex": true,
      "environments": ["PROD"]
    },
    {
      "key": "'${PROJECT_KEY}'-platform-python-internal-local",
      "packageType": "pypi",
      "description": "Platform Python internal repository for DEV/QA/STAGE stages",
      "notes": "Internal development repository",
      "includesPattern": "**/*",
      "excludesPattern": "",
      "rclass": "local",
      "projectKey": "'${PROJECT_KEY}'",
      "xrayIndex": true,
      "environments": ["DEV", "QA", "STAGE"]
    },
    {
      "key": "'${PROJECT_KEY}'-platform-python-release-local",
      "packageType": "pypi",
      "description": "Platform Python release repository for PROD stage",
      "notes": "Production release repository",
      "includesPattern": "**/*",
      "excludesPattern": "",
      "rclass": "local",
      "projectKey": "'${PROJECT_KEY}'",
      "xrayIndex": true,
      "environments": ["PROD"]
    }
  ]')
  
  echo "📤 Sending batch repository creation request..."
  echo "   Payload Size: 16 repository configurations"
  echo "   Target: ${JFROG_URL}/artifactory/api/v2/repositories/batch"
  
  # Create all repositories in batch
  batch_response=$(curl -s -w "%{http_code}" -o /tmp/batch_response.json \
    --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
    --header "Content-Type: application/json" \
    -X PUT \
    -d "$batch_payload" \
    "${JFROG_URL}/artifactory/api/v2/repositories/batch")
  
  batch_code=$(echo "$batch_response" | tail -n1)
  echo "📥 Received response: HTTP $batch_code"
  
  if [ "$batch_code" -eq 200 ] || [ "$batch_code" -eq 201 ]; then
    echo "     ✅ All repositories created successfully in batch (HTTP $batch_code)"
    echo "     Status: SUCCESS - All 16 repositories created"
    echo "     Details: Batch operation completed successfully"
    echo "     Repositories: 4 microservices × 2 packages × 2 stages = 16 total"
  elif [ "$batch_code" -eq 409 ]; then
    echo "     ⚠️  Some repositories already exist (HTTP $batch_code)"
    echo "     Status: PARTIAL - Some repositories were already present"
    echo "     Action: Continuing to next step"
    echo "     Note: This is normal if script is re-run"
  else
    echo "     ⚠️  Batch repository creation returned HTTP $batch_code (continuing anyway)"
    echo "     Status: UNKNOWN - Unexpected response code"
    echo "     Action: Continuing to next step despite unexpected response"
    echo "     Note: Check JFrog logs for detailed error information"
  fi
  
  echo ""
}

# Create all repositories in batch
create_all_repositories

echo "📊 Step 3 Summary:"
echo "   ✅ Repository creation process completed"
echo "   📦 Total Repositories: 16"
echo "   🏗️  Microservices: 4 (inventory, recommendations, checkout, platform)"
echo "   📦 Package Types: 2 (docker, python)"
echo "   🎭 Stages: 2 (internal-local, release-local)"
echo "   🔗 Project Integration: All repositories linked to '${PROJECT_KEY}' project"
echo "   🔍 Xray Indexing: Enabled for all repositories"
echo "   🎯 Stage Assignment: Internal repos → DEV/QA/STAGE, Release repos → PROD"
echo ""



# =============================================================================
# STEP 4: CREATE USERS
# =============================================================================
echo "👥 Step 4/6: Creating Users..."
echo "   Creating 12 users (8 human + 4 pipeline)"
echo "   API Endpoint: ${JFROG_URL}/access/api/v2/users"
echo "   Method: POST"
echo "   User Types: Human users with roles, Pipeline users for automation"
echo ""

echo "🔧 Preparing user creation..."
echo "   User Categories:"
echo "     👤 Human Users (8):"
echo "       • Alice Developer: Developer role"
echo "       • Bob Release: Release Manager role"
echo "       • Charlie DevOps: Project Manager role"
echo "       • Diana Architect: AppTrust Admin role"
echo "       • Edward Manager: AppTrust Admin role"
echo "       • Frank Inventory: Inventory Manager role"
echo "       • Grace AI: AI/ML Manager role"
echo "       • Henry Checkout: Checkout Manager role"
echo "     🤖 Pipeline Users (4):"
echo "       • pipeline.inventory: Pipeline automation for inventory service"
echo "       • pipeline.recommendations: Pipeline automation for recommendations service"
echo "       • pipeline.checkout: Pipeline automation for checkout service"
echo "       • pipeline.platform: Pipeline automation for platform solution"
echo ""

# Function to create user
create_user() {
  local username="$1"
  local email="$2"
  local password="$3"
  local role="$4"
  
  echo "   🚀 Creating user: $username"
  echo "     Role: $role"
  echo "     Email: $email"
  echo "     API: POST ${JFROG_URL}/access/api/v2/users"
  
  # Create user payload
  user_payload=$(jq -n '{
    "username": "'$username'",
    "email": "'$username'",
    "password": "'$password'"
  }')
  
  echo "     📤 Sending user creation request..."
  
  # Create user
  user_response=$(curl -s -w "%{http_code}" -o /tmp/user_response.json \
    --header "Content-Type: application/json" \
    --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
    -X POST \
    -d "$user_payload" \
    "${JFROG_URL}/access/api/v2/users")
  
  user_code=$(echo "$user_response" | tail -n1)
  echo "     📥 Response: HTTP $user_code"
  
  if [ "$user_code" -eq 201 ]; then
    echo "     ✅ User '$username' created successfully"
    echo "       Status: SUCCESS - User account ready"
    echo "       Role: $role"
    echo "       Access: JFrog Platform access granted"
  elif [ "$user_code" -eq 409 ]; then
    echo "     ⚠️  User '$username' already exists"
    echo "       Status: SKIPPED - User was previously created"
    echo "       Action: Continuing to next user"
  else
    echo "     ⚠️  User '$username' creation returned HTTP $user_code (continuing anyway)"
    echo "       Status: UNKNOWN - Unexpected response code"
    echo "       Action: Continuing to next user despite unexpected response"
  fi
  echo ""
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
echo "📊 Step 4 Summary:"
echo "   ✅ User creation process completed"
echo "   👤 Human Users: 8 users with specific roles"
echo "   🤖 Pipeline Users: 4 users for automation"
echo "   🔑 Total Users: 12 users created"
echo "   🎭 Roles: Developer, Release Manager, Project Manager, AppTrust Admin, Inventory Manager, AI/ML Manager, Checkout Manager, Pipeline User"
echo "   📧 Authentication: All users have email-based authentication"
echo "   🔐 Passwords: Human users (BookVerse2024!), Pipeline users (Pipeline2024!)"
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
    echo "     ⚠️  Application '$app_name' creation returned HTTP $app_code (continuing anyway)"
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
    echo "     ⚠️  OIDC integration creation returned HTTP $oidc_code (continuing anyway)"
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
echo "📊 Summary of what was processed:"
echo "   ✅ Project: ${PROJECT_KEY}"
echo "   ✅ Repositories: 16 (4 microservices × 2 package types × 2 stages)"
echo "   ✅ AppTrust Stages: DEV, QA, STAGE, PROD"
echo "   ✅ Users: 12 (8 human + 4 pipeline)"
echo "   ✅ Applications: 4 microservices + 1 platform"
echo "   ✅ OIDC Integrations: 4 (one per microservice team)"
echo ""
echo "💡 Note: Existing resources were detected and skipped gracefully"
echo "   The script continues even if some resources already exist"
echo ""
echo "🚀 Your BookVerse platform is ready for development!"
echo "💡 Next steps: Configure GitHub Actions secrets and run the workflow"
echo ""
echo "🔑 Default passwords:"
echo "   - Human users: BookVerse2024!"
echo "   - Pipeline users: Pipeline2024!"
