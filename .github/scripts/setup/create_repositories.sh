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
      -X POST \
      -d "$(printf '%s' "$repo_payload")" \
      "${JFROG_URL}/artifactory/api/onboarding/createQuickRepos")
    
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

echo "Creating Repositories and inserting them to indexing..."
echo "API Endpoint: ${JFROG_URL}/artifactory/api/onboarding/createQuickRepos"
echo "Project: ${PROJECT_KEY}"
echo ""

# Create repository payloads for different package types and environments
# Docker repositories
docker_repo_payload=$(jq -n '{"repositories":[{"repoName":"'${PROJECT_KEY}'-docker-local","project":"'${PROJECT_KEY}'","envs":["DEV"],"packageType":"Docker","repoType":"LOCAL","xrayEnabled":true},{"repoName":"'${PROJECT_KEY}'-docker-remote","project":"'${PROJECT_KEY}'","envs":["DEV"],"packageType":"Docker","repoType":"REMOTE","xrayEnabled":true},{"repoName":"'${PROJECT_KEY}'-docker","project":"'${PROJECT_KEY}'","envs":["DEV"],"packageType":"Docker","repoType":"VIRTUAL","defaultDeploymentRepo":"'${PROJECT_KEY}'-docker-local","includedLocalRepositories":["'${PROJECT_KEY}'-docker-local"],"xrayEnabled":true,"includedRemoteRepositories":["'${PROJECT_KEY}'-docker-remote"]}]}')

docker_dev_repo_payload=$(jq -n '{"repositories":[{"repoName":"'${PROJECT_KEY}'-dev-docker-local","project":"'${PROJECT_KEY}'","envs":["DEV"],"packageType":"Docker","repoType":"LOCAL","xrayEnabled":true},{"repoName":"'${PROJECT_KEY}'-dev-docker-remote","project":"'${PROJECT_KEY}'","envs":["DEV"],"packageType":"Docker","repoType":"REMOTE","xrayEnabled":true},{"repoName":"'${PROJECT_KEY}'-dev-docker","project":"'${PROJECT_KEY}'","envs":["DEV"],"packageType":"Docker","repoType":"VIRTUAL","defaultDeploymentRepo":"'${PROJECT_KEY}'-dev-docker-local","includedLocalRepositories":["'${PROJECT_KEY}'-dev-docker-local"],"xrayEnabled":true,"includedRemoteRepositories":["'${PROJECT_KEY}'-dev-docker-remote"]}]}')

docker_qa_repo_payload=$(jq -n '{"repositories":[{"repoName":"'${PROJECT_KEY}'-qa-docker-local","project":"'${PROJECT_KEY}'","envs":["QA"],"packageType":"Docker","repoType":"LOCAL","xrayEnabled":true},{"repoName":"'${PROJECT_KEY}'-qa-docker-remote","project":"'${PROJECT_KEY}'","envs":["QA"],"packageType":"Docker","repoType":"REMOTE","xrayEnabled":true},{"repoName":"'${PROJECT_KEY}'-qa-docker","project":"'${PROJECT_KEY}'","envs":["QA"],"packageType":"Docker","repoType":"VIRTUAL","defaultDeploymentRepo":"'${PROJECT_KEY}'-qa-docker-local","includedLocalRepositories":["'${PROJECT_KEY}'-qa-docker-local"],"xrayEnabled":true,"includedRemoteRepositories":["'${PROJECT_KEY}'-qa-docker-remote"]}]}')

docker_stage_repo_payload=$(jq -n '{"repositories":[{"repoName":"'${PROJECT_KEY}'-stage-docker-local","project":"'${PROJECT_KEY}'","envs":["STAGE"],"packageType":"Docker","repoType":"LOCAL","xrayEnabled":true},{"repoName":"'${PROJECT_KEY}'-stage-docker-remote","project":"'${PROJECT_KEY}'","envs":["STAGE"],"packageType":"Docker","repoType":"REMOTE","xrayEnabled":true},{"repoName":"'${PROJECT_KEY}'-stage-docker","project":"'${PROJECT_KEY}'","envs":["STAGE"],"packageType":"Docker","repoType":"VIRTUAL","defaultDeploymentRepo":"'${PROJECT_KEY}'-stage-docker-local","includedLocalRepositories":["'${PROJECT_KEY}'-stage-docker-local"],"xrayEnabled":true,"includedRemoteRepositories":["'${PROJECT_KEY}'-stage-docker-remote"]}]}')

# PyPI repositories
pypi_repo_payload=$(jq -n '{"repositories":[{"repoName":"'${PROJECT_KEY}'-pypi-local","project":"'${PROJECT_KEY}'","envs":["DEV"],"packageType":"Pypi","repoType":"LOCAL","xrayEnabled":true},{"repoName":"'${PROJECT_KEY}'-pypi-remote","project":"'${PROJECT_KEY}'","envs":["DEV"],"packageType":"Pypi","repoType":"REMOTE","xrayEnabled":true},{"repoName":"'${PROJECT_KEY}'-pypi","project":"'${PROJECT_KEY}'","envs":["DEV"],"packageType":"Pypi","repoType":"VIRTUAL","defaultDeploymentRepo":"'${PROJECT_KEY}'-pypi-local","includedLocalRepositories":["'${PROJECT_KEY}'-pypi-local"],"xrayEnabled":true,"includedRemoteRepositories":["'${PROJECT_KEY}'-pypi-remote"]}]}')

pypi_dev_repo_payload=$(jq -n '{"repositories":[{"repoName":"'${PROJECT_KEY}'-dev-pypi-local","project":"'${PROJECT_KEY}'","envs":["DEV"],"packageType":"Pypi","repoType":"LOCAL","xrayEnabled":true},{"repoName":"'${PROJECT_KEY}'-dev-pypi-remote","project":"'${PROJECT_KEY}'","envs":["DEV"],"packageType":"Pypi","repoType":"REMOTE","xrayEnabled":true},{"repoName":"'${PROJECT_KEY}'-dev-pypi","project":"'${PROJECT_KEY}'","envs":["DEV"],"packageType":"Pypi","repoType":"VIRTUAL","defaultDeploymentRepo":"'${PROJECT_KEY}'-dev-pypi-local","includedLocalRepositories":["'${PROJECT_KEY}'-dev-pypi-local"],"xrayEnabled":true,"includedRemoteRepositories":["'${PROJECT_KEY}'-dev-pypi-remote"]}]}')

pypi_qa_repo_payload=$(jq -n '{"repositories":[{"repoName":"'${PROJECT_KEY}'-qa-pypi-local","project":"'${PROJECT_KEY}'","envs":["QA"],"packageType":"Pypi","repoType":"LOCAL","xrayEnabled":true},{"repoName":"'${PROJECT_KEY}'-qa-pypi-remote","project":"'${PROJECT_KEY}'","envs":["QA"],"packageType":"Pypi","repoType":"REMOTE","xrayEnabled":true},{"repoName":"'${PROJECT_KEY}'-qa-pypi","project":"'${PROJECT_KEY}'","envs":["QA"],"packageType":"Pypi","repoType":"VIRTUAL","defaultDeploymentRepo":"'${PROJECT_KEY}'-qa-pypi-local","includedLocalRepositories":["'${PROJECT_KEY}'-qa-pypi-local"],"xrayEnabled":true,"includedRemoteRepositories":["'${PROJECT_KEY}'-qa-pypi-remote"]}]}')

pypi_stage_repo_payload=$(jq -n '{"repositories":[{"repoName":"'${PROJECT_KEY}'-stage-pypi-local","project":"'${PROJECT_KEY}'","envs":["STAGE"],"packageType":"Pypi","repoType":"LOCAL","xrayEnabled":true},{"repoName":"'${PROJECT_KEY}'-stage-pypi-remote","project":"'${PROJECT_KEY}'","envs":["STAGE"],"packageType":"Pypi","repoType":"REMOTE","xrayEnabled":true},{"repoName":"'${PROJECT_KEY}'-stage-pypi","project":"'${PROJECT_KEY}'","envs":["STAGE"],"packageType":"Pypi","repoType":"VIRTUAL","defaultDeploymentRepo":"'${PROJECT_KEY}'-stage-pypi-local","includedLocalRepositories":["'${PROJECT_KEY}'-stage-pypi-local"],"xrayEnabled":true,"includedRemoteRepositories":["'${PROJECT_KEY}'-stage-pypi-remote"]}]}')

# Create repositories for each package type and environment
echo "🚀 Creating Docker repositories..."
create_repo "Docker" "$docker_repo_payload"
create_repo "Docker Dev" "$docker_dev_repo_payload"
create_repo "Docker QA" "$docker_qa_repo_payload"
create_repo "Docker Stage" "$docker_stage_repo_payload"

echo "🐍 Creating PyPI repositories..."
create_repo "PyPI" "$pypi_repo_payload"
create_repo "PyPI Dev" "$pypi_dev_repo_payload"
create_repo "PyPI QA" "$pypi_qa_repo_payload"
create_repo "PyPI Stage" "$pypi_stage_repo_payload"

# Check if any operations failed
if [ "$FAILED" = true ]; then
  echo "❌ One or more critical repository operations failed. Exiting with error."
  exit 1
fi

echo "✅ Repository creation process completed!"
echo "All repository groups have been processed successfully."
echo ""
echo "📊 Summary of created repositories:"
echo "   - Docker repositories for DEV, QA, and STAGE environments"
echo "   - PyPI repositories for DEV, QA, and STAGE environments"
echo "   - All repositories are Xray-enabled and properly configured"
