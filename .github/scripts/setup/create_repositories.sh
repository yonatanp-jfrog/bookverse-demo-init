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

# Function to create repositories from a payload
create_repo() {
  local repo_name="$1"
  local repo_payload="$2"

  echo "Checking $repo_name repositories..."
  
  # Check which repositories already exist
  check_repos_in_payload "$repo_payload"
  
  if [ ${#missing_repos_list} -eq 0 ]; then
    echo "⚠️  All $repo_name repositories already exist (skipping creation)"
    echo ""
    return 0
  fi
  
  if [ ${#existing_repos_list} -gt 0 ]; then
    echo "📋 Some $repo_name repositories already exist: $existing_repos_list"
  fi
  
  if [ ${#missing_repos_list} -gt 0 ]; then
    echo "🚧 Creating missing $repo_name repositories: $missing_repos_list"
    
    # Create temporary files for response handling
    temp_response=$(mktemp)
    
    response_code=$(curl -s -w "%{http_code}" -o "$temp_response" \
      --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
      --header "Content-Type: application/json" \
      -X PUT \
      -d "$(printf '%s' "$repo_payload")" \
      "${JFROG_URL}/api/repositories/$(echo "$repo_payload" | jq -r '.key')")
    
    response_body=$(cat "$temp_response")
    
    # Clean up temporary files
    rm -f "$temp_response"
    
    if [ "$response_code" -eq 200 ] || [ "$response_code" -eq 201 ]; then
      echo "✅ $repo_name repositories created successfully (HTTP $response_code)"
    elif [ "$response_code" -eq 400 ] && echo "$response_body" | grep -q "already exists"; then
      echo "⚠️  $repo_name repositories already exist (HTTP $response_code)"
    elif [ "$response_code" -eq 400 ] && echo "$response_body" | grep -q "does not exist"; then
      echo "❌ Cannot create $repo_name repositories - required projects don't exist (HTTP $response_code)"
      echo "   Response: $response_body"
      FAILED=true
    else
      echo "❌ Failed to create $repo_name repositories (HTTP $response_code)"
      echo "   Response body: $response_body"
      FAILED=true
    fi
  fi
  echo ""
}

echo "Creating Repositories for BookVerse Microservices Platform..."
echo "API Endpoint: ${JFROG_URL}/api/repositories/{repoKey}"
echo "Project: ${PROJECT_KEY}"
echo "Naming Convention: ${PROJECT_KEY}-{service_name}-{package}-{type}-local"
echo ""

# Create repository payloads for each microservice and package type
# Each service gets 2 repositories per package: internal-local and release-local

# =============================================================================
# BOOKVERSE INVENTORY MICROSERVICE
# =============================================================================
echo "📦 Creating BookVerse Inventory Microservice repositories..."

# Inventory repositories
inventory_docker_internal_payload=$(jq -n '{"key":"'${PROJECT_KEY}'-inventory-docker-internal-local","rclass":"local","packageType":"Docker","description":"Inventory Docker internal repository for DEV/QA/STAGE stages","xrayIndex":true}')

inventory_docker_release_payload=$(jq -n '{"key":"'${PROJECT_KEY}'-inventory-docker-release-local","rclass":"local","packageType":"Docker","description":"Inventory Docker release repository for PROD stage","xrayIndex":true}')

inventory_python_internal_payload=$(jq -n '{"key":"'${PROJECT_KEY}'-inventory-python-internal-local","rclass":"local","packageType":"Pypi","description":"Inventory Python internal repository for DEV/QA/STAGE stages","xrayIndex":true}')

inventory_python_release_payload=$(jq -n '{"key":"'${PROJECT_KEY}'-inventory-python-release-local","rclass":"local","packageType":"Pypi","description":"Inventory Python release repository for PROD stage","xrayIndex":true}')

create_repo "Inventory Docker Internal" "$inventory_docker_internal_payload"
create_repo "Inventory Docker Release" "$inventory_docker_release_payload"
create_repo "Inventory Python Internal" "$inventory_python_internal_payload"
create_repo "Inventory Python Release" "$inventory_python_release_payload"

# =============================================================================
# BOOKVERSE RECOMMENDATIONS MICROSERVICE
# =============================================================================
echo "🎯 Creating BookVerse Recommendations Microservice repositories..."

# Recommendations repositories
recommendations_docker_internal_payload=$(jq -n '{"key":"'${PROJECT_KEY}'-recommendations-docker-internal-local","rclass":"local","packageType":"Docker","description":"Recommendations Docker internal repository for DEV/QA/STAGE stages","xrayIndex":true}')

recommendations_docker_release_payload=$(jq -n '{"key":"'${PROJECT_KEY}'-recommendations-docker-release-local","rclass":"local","packageType":"Docker","description":"Recommendations Docker release repository for PROD stage","xrayIndex":true}')

recommendations_python_internal_payload=$(jq -n '{"key":"'${PROJECT_KEY}'-recommendations-python-internal-local","rclass":"local","packageType":"Pypi","description":"Recommendations Python internal repository for DEV/QA/STAGE stages","xrayIndex":true}')

recommendations_python_release_payload=$(jq -n '{"key":"'${PROJECT_KEY}'-recommendations-python-release-local","rclass":"local","packageType":"Pypi","description":"Recommendations Python release repository for PROD stage","xrayIndex":true}')

create_repo "Recommendations Docker Internal" "$recommendations_docker_internal_payload"
create_repo "Recommendations Docker Release" "$recommendations_docker_release_payload"
create_repo "Recommendations Python Internal" "$recommendations_python_internal_payload"
create_repo "Recommendations Python Release" "$recommendations_python_release_payload"

# =============================================================================
# BOOKVERSE CHECKOUT MICROSERVICE
# =============================================================================
echo "🛒 Creating BookVerse Checkout Microservice repositories..."

# Checkout repositories
checkout_docker_internal_payload=$(jq -n '{"key":"'${PROJECT_KEY}'-checkout-docker-internal-local","rclass":"local","packageType":"Docker","description":"Checkout Docker internal repository for DEV/QA/STAGE stages","xrayIndex":true}')

checkout_docker_release_payload=$(jq -n '{"key":"'${PROJECT_KEY}'-checkout-docker-release-local","rclass":"local","packageType":"Docker","description":"Checkout Docker release repository for PROD stage","xrayIndex":true}')

checkout_python_internal_payload=$(jq -n '{"key":"'${PROJECT_KEY}'-checkout-python-internal-local","rclass":"local","packageType":"Pypi","description":"Checkout Python internal repository for DEV/QA/STAGE stages","xrayIndex":true}')

checkout_python_release_payload=$(jq -n '{"key":"'${PROJECT_KEY}'-checkout-python-release-local","rclass":"local","packageType":"Pypi","description":"Checkout Python release repository for PROD stage","xrayIndex":true}')

create_repo "Checkout Docker Internal" "$checkout_docker_internal_payload"
create_repo "Checkout Docker Release" "$checkout_docker_release_payload"
create_repo "Checkout Python Internal" "$checkout_python_internal_payload"
create_repo "Checkout Python Release" "$checkout_python_release_payload"

# =============================================================================
# BOOKVERSE PLATFORM SOLUTION
# =============================================================================
echo "🏗️  Creating BookVerse Platform Solution repositories..."

# Platform repositories
platform_docker_internal_payload=$(jq -n '{"key":"'${PROJECT_KEY}'-platform-docker-internal-local","rclass":"local","packageType":"Docker","description":"Platform Docker internal repository for DEV/QA/STAGE stages","xrayIndex":true}')

platform_docker_release_payload=$(jq -n '{"key":"'${PROJECT_KEY}'-platform-docker-release-local","rclass":"local","packageType":"Docker","description":"Platform Docker release repository for PROD stage","xrayIndex":true}')

platform_python_internal_payload=$(jq -n '{"key":"'${PROJECT_KEY}'-platform-python-internal-local","rclass":"local","packageType":"Pypi","description":"Platform Python internal repository for DEV/QA/STAGE stages","xrayIndex":true}')

platform_python_release_payload=$(jq -n '{"key":"'${PROJECT_KEY}'-platform-python-release-local","rclass":"local","packageType":"Pypi","description":"Platform Python release repository for PROD stage","xrayIndex":true}')

create_repo "Platform Docker Internal" "$platform_docker_internal_payload"
create_repo "Platform Docker Release" "$platform_docker_release_payload"
create_repo "Platform Python Internal" "$platform_python_internal_payload"
create_repo "Platform Python Release" "$platform_python_release_payload"

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
