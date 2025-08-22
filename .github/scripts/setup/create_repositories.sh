#!/usr/bin/env bash

set -e

# Source global configuration
source "$(dirname "$0")/config.sh"

# Validate environment variables
validate_environment

FAILED=false

# Function to check if a repository already exists
check_repo_exists() {
  local repo_name="$1"
  
  response_code=$(curl -s -o /dev/null -w "%{http_code}" \
    --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
    --header "Content-Type: application/json" \
    -X GET \
    "${JFROG_URL}/artifactory/api/repositories/${repo_name}")
  
  if [ "$response_code" -eq 200 ]; then
    return 0  # Repository exists
  else
    return 1  # Repository doesn't exist
  fi
}

# Function to check which repositories exist and which are missing
check_repos_in_payload() {
  local repo_payload="$1"
  local existing_repos=()
  local missing_repos=()
  
  # Extract repository names from the payload
  repo_names=$(echo "$repo_payload" | jq -r '.repositories[].repoName')
  
  while IFS= read -r repo_name; do
    if [ -n "$repo_name" ]; then  # Skip empty lines
      if check_repo_exists "$repo_name"; then
        existing_repos+=("$repo_name")
      else
        missing_repos+=("$repo_name")
      fi
    fi
  done <<< "$repo_names"
  
  # Set global variables for use in create_repo function
  existing_repos_list="${existing_repos[*]}"
  missing_repos_list="${missing_repos[*]}"
}

# Function to create repositories from a batch payload
create_repo() {
  local repo_name="$1"
  local repo_payload="$2"

  echo "🚧 Creating $repo_name..."
  
  # Create temporary files for response handling
  temp_response=$(mktemp)
  
  response_code=$(curl -s -w "%{http_code}" -o "$temp_response" \
    --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
    --header "Content-Type: application/json" \
    -X PUT \
    -d "$(printf '%s' "$repo_payload")" \
    "${JFROG_URL}/artifactory/api/v2/repositories/batch")
  
  response_body=$(cat "$temp_response")
  
  # Clean up temporary files
  rm -f "$temp_response"
  
  if [ "$response_code" -eq 200 ] || [ "$response_code" -eq 201 ]; then
    echo "✅ $repo_name created successfully in batch (HTTP $response_code)"
  elif [ "$response_code" -eq 409 ]; then
    echo "⚠️  Some repositories already exist (HTTP $response_code)"
  elif [ "$response_code" -eq 400 ] && echo "$response_body" | grep -q "already exists"; then
    echo "⚠️  Some repositories already exist (HTTP $response_code)"
  elif [ "$response_code" -eq 400 ] && echo "$response_body" | grep -q "does not exist"; then
    echo "❌ Cannot create repositories - required projects don't exist (HTTP $response_code)"
    echo "   Response: $response_body"
    FAILED=true
  else
    echo "❌ Failed to create $repo_name (HTTP $response_code)"
    echo "   Response body: $response_body"
    echo "   Response code: $response_code"
    FAILED=true
  fi
  echo ""
}

echo "Creating Repositories for BookVerse Microservices Platform..."
echo "API Endpoint: ${JFROG_URL}/artifactory/api/v2/repositories/batch"
echo "Project: ${PROJECT_KEY}"
echo "Naming Convention: ${PROJECT_KEY}-{service_name}-{package}-{type}-local"
echo ""

# Create all repositories in batch
echo "📦 Creating all 16 repositories in batch..."

# Create batch payload with all repositories
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
    "xrayIndex": true
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
    "xrayIndex": true
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
    "xrayIndex": true
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
    "xrayIndex": true
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
    "xrayIndex": true
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
    "xrayIndex": true
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
    "xrayIndex": true
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
    "xrayIndex": true
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
    "xrayIndex": true
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
    "xrayIndex": true
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
    "xrayIndex": true
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
    "xrayIndex": true
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
    "xrayIndex": true
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
    "xrayIndex": true
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
    "xrayIndex": true
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
    "xrayIndex": true
  }
]')

# Create all repositories in batch
create_repo "All BookVerse Repositories" "$batch_payload"

# Check if any operations failed
if [ "$FAILED" = true ]; then
  echo "❌ One or more critical repository operations failed. Exiting with error."
  exit 1
fi

echo "✅ Repository creation process completed!"
echo "All repository groups have been processed successfully."
echo ""
echo "📊 Summary of created repositories by microservice:"
echo ""
echo "📦 BookVerse Inventory Microservice:"
echo "     - ${PROJECT_KEY}-inventory-docker-internal-local (DEV, QA, STAGE stages)"
echo "     - ${PROJECT_KEY}-inventory-docker-release-local (PROD stage)"
echo "     - ${PROJECT_KEY}-inventory-python-internal-local (DEV, QA, STAGE stages)"
echo "     - ${PROJECT_KEY}-inventory-python-release-local (PROD stage)"
echo ""
echo "🎯 BookVerse Recommendations Microservice:"
echo "     - ${PROJECT_KEY}-recommendations-docker-internal-local (DEV, QA, STAGE stages)"
echo "     - ${PROJECT_KEY}-recommendations-docker-release-local (PROD stage)"
echo "     - ${PROJECT_KEY}-recommendations-python-internal-local (DEV, QA, STAGE stages)"
echo "     - ${PROJECT_KEY}-recommendations-python-release-local (PROD stage)"
echo ""
echo "🛒 BookVerse Checkout Microservice:"
echo "     - ${PROJECT_KEY}-checkout-docker-internal-local (DEV, QA, STAGE stages)"
echo "     - ${PROJECT_KEY}-checkout-docker-release-local (PROD stage)"
echo "     - ${PROJECT_KEY}-checkout-python-internal-local (DEV, QA, STAGE stages)"
echo "     - ${PROJECT_KEY}-checkout-python-release-local (PROD stage)"
echo ""
echo "🏗️  BookVerse Platform Solution:"
echo "     - ${PROJECT_KEY}-platform-docker-internal-local (DEV, QA, STAGE stages)"
echo "     - ${PROJECT_KEY}-platform-docker-release-local (PROD stage)"
echo "     - ${PROJECT_KEY}-platform-python-internal-local (DEV, QA, STAGE stages)"
echo "     - ${PROJECT_KEY}-platform-python-release-local (PROD stage)"
echo ""
echo "🔗 Repository-Stage Mapping:"
echo "   - Internal repositories: DEV, QA, STAGE stages"
echo "   - Release repositories: PROD stage"
echo ""
echo "💡 Note: Each microservice has 2 repositories per package type"
echo "   Total repositories: 16 (4 microservices × 2 package types × 2 repository types)"
