#!/usr/bin/env bash

# =============================================================================
# DEPENDENCY REPOSITORIES CREATION SCRIPT
# =============================================================================
# Creates remote, local, and virtual repositories for external dependencies
# Pre-populates critical dependencies used by BookVerse services
# =============================================================================

set -e

# Load configuration
source "$(dirname "$0")/config.sh"

echo ""
echo "🚀 Creating dependency repositories for BookVerse platform"
echo "🔧 Project: $PROJECT_KEY"
echo "🔧 JFrog URL: $JFROG_URL"
echo ""

# Function to create remote repository
create_remote_repository() {
    local repo_key="$1"
    local package_type="$2"
    local url="$3"
    local description="$4"
    
    local repo_config=$(jq -n \
        --arg key "$repo_key" \
        --arg rclass "remote" \
        --arg packageType "$package_type" \
        --arg url "$url" \
        --arg description "$description" \
        --arg projectKey "$PROJECT_KEY" \
        '{
            "key": $key,
            "rclass": $rclass,
            "packageType": $packageType,
            "url": $url,
            "description": $description,
            "projectKey": $projectKey
        }')
    
    echo "Creating remote repository: $repo_key"
    
    local temp_response=$(mktemp)
    local response_code=$(curl -s --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
        --header "Content-Type: application/json" \
        -X PUT \
        -d "$repo_config" \
        --write-out "%{http_code}" \
        --output "$temp_response" \
        "${JFROG_URL}/artifactory/api/repositories/${repo_key}")
    
    case "$response_code" in
        200|201)
            echo "✅ Remote repository '$repo_key' created successfully (HTTP $response_code)"
            ;;
        409|400)
            if grep -qi "already exists" "$temp_response"; then
                echo "⚠️  Remote repository '$repo_key' already exists - attempting update"
                # Remove projectKey for updates
                local update_config=$(echo "$repo_config" | jq 'del(.projectKey)')
                local update_resp=$(mktemp)
                local update_code=$(curl -s --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
                    --header "Content-Type: application/json" \
                    -X PUT \
                    -d "$update_config" \
                    --write-out "%{http_code}" \
                    --output "$update_resp" \
                    "${JFROG_URL}/artifactory/api/repositories/${repo_key}")
                if [[ "$update_code" == "200" ]]; then
                    echo "✅ Remote repository '$repo_key' updated successfully (HTTP $update_code)"
                else
                    echo "⚠️  Update of remote repository '$repo_key' returned HTTP $update_code"
                    echo "Response body: $(cat "$update_resp")"
                fi
                rm -f "$update_resp"
            else
                echo "❌ Failed to create remote repository '$repo_key' (HTTP $response_code)"
                echo "Response body: $(cat "$temp_response")"
                rm -f "$temp_response"
                return 1
            fi
            ;;
        *)
            echo "❌ Failed to create remote repository '$repo_key' (HTTP $response_code)"
            echo "Response body: $(cat "$temp_response")"
            rm -f "$temp_response"
            return 1
            ;;
    esac
    
    rm -f "$temp_response"
}

# Function to create virtual repository
create_virtual_repository() {
    local repo_key="$1"
    local package_type="$2"
    local repositories="$3"
    local description="$4"
    
    local repo_config=$(jq -n \
        --arg key "$repo_key" \
        --arg rclass "virtual" \
        --arg packageType "$package_type" \
        --arg description "$description" \
        --arg projectKey "$PROJECT_KEY" \
        --argjson repositories "$repositories" \
        '{
            "key": $key,
            "rclass": $rclass,
            "packageType": $packageType,
            "description": $description,
            "projectKey": $projectKey,
            "repositories": $repositories
        }')
    
    echo "Creating virtual repository: $repo_key"
    
    local temp_response=$(mktemp)
    local response_code=$(curl -s --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
        --header "Content-Type: application/json" \
        -X PUT \
        -d "$repo_config" \
        --write-out "%{http_code}" \
        --output "$temp_response" \
        "${JFROG_URL}/artifactory/api/repositories/${repo_key}")
    
    case "$response_code" in
        200|201)
            echo "✅ Virtual repository '$repo_key' created successfully (HTTP $response_code)"
            ;;
        409|400)
            if grep -q "already exists" "$temp_response"; then
                echo "⚠️  Virtual repository '$repo_key' already exists (HTTP $response_code)"
            else
                echo "❌ Failed to create virtual repository '$repo_key' (HTTP $response_code)"
                echo "Response body: $(cat "$temp_response")"
                rm -f "$temp_response"
                return 1
            fi
            ;;
        *)
            echo "❌ Failed to create virtual repository '$repo_key' (HTTP $response_code)"
            echo "Response body: $(cat "$temp_response")"
            rm -f "$temp_response"
            return 1
            ;;
    esac
    
    rm -f "$temp_response"
}

# Function to create local dependency cache repository
create_local_cache_repository() {
    local repo_key="$1"
    local package_type="$2"
    local description="$3"
    
    local repo_config=$(jq -n \
        --arg key "$repo_key" \
        --arg rclass "local" \
        --arg packageType "$package_type" \
        --arg description "$description" \
        --arg projectKey "$PROJECT_KEY" \
        '{
            "key": $key,
            "rclass": $rclass,
            "packageType": $packageType,
            "description": $description,
            "projectKey": $projectKey
        }')
    
    echo "Creating local cache repository: $repo_key"
    
    local temp_response=$(mktemp)
    local response_code=$(curl -s --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
        --header "Content-Type: application/json" \
        -X PUT \
        -d "$repo_config" \
        --write-out "%{http_code}" \
        --output "$temp_response" \
        "${JFROG_URL}/artifactory/api/repositories/${repo_key}")
    
    case "$response_code" in
        200|201)
            echo "✅ Local cache repository '$repo_key' created successfully (HTTP $response_code)"
            ;;
        409|400)
            if grep -q "already exists" "$temp_response"; then
                echo "⚠️  Local cache repository '$repo_key' already exists (HTTP $response_code)"
            else
                echo "❌ Failed to create local cache repository '$repo_key' (HTTP $response_code)"
                echo "Response body: $(cat "$temp_response")"
                rm -f "$temp_response"
                return 1
            fi
            ;;
        *)
            echo "❌ Failed to create local cache repository '$repo_key' (HTTP $response_code)"
            echo "Response body: $(cat "$temp_response")"
            rm -f "$temp_response"
            return 1
            ;;
    esac
    
    rm -f "$temp_response"
}

echo "=== Creating Python Dependency Repositories ==="

# Create Python remote repository (PyPI)
create_remote_repository \
    "${PROJECT_KEY}-pypi-remote" \
    "pypi" \
    "https://pypi.org" \
    "Remote proxy for PyPI.org - Python packages"

# Create Python local cache repository
create_local_cache_repository \
    "${PROJECT_KEY}-pypi-cache-local" \
    "pypi" \
    "Local cache for frequently used Python packages"

# Create Python virtual repository
create_virtual_repository \
    "${PROJECT_KEY}-pypi-virtual" \
    "pypi" \
    "[\"${PROJECT_KEY}-pypi-cache-local\", \"${PROJECT_KEY}-pypi-remote\"]" \
    "Virtual repository aggregating local cache and PyPI remote"

echo ""
echo "=== Creating npm Dependency Repositories ==="

# Create npm remote repository
create_remote_repository \
    "${PROJECT_KEY}-npm-remote" \
    "npm" \
    "https://registry.npmjs.org" \
    "Remote proxy for npmjs.org - Node.js packages"

# Create npm local cache repository
create_local_cache_repository \
    "${PROJECT_KEY}-npm-cache-local" \
    "npm" \
    "Local cache for frequently used npm packages"

# Create npm virtual repository
create_virtual_repository \
    "${PROJECT_KEY}-npm-virtual" \
    "npm" \
    "[\"${PROJECT_KEY}-npm-cache-local\", \"${PROJECT_KEY}-npm-remote\"]" \
    "Virtual repository aggregating local cache and npm remote"

echo ""
echo "=== Creating Docker Dependency Repositories ==="

# Create Docker Hub remote repository
create_remote_repository \
    "${PROJECT_KEY}-dockerhub-remote" \
    "docker" \
    "https://registry-1.docker.io" \
    "Remote proxy for Docker Hub - Base images and tools"

# Create Docker local cache repository
create_local_cache_repository \
    "${PROJECT_KEY}-dockerhub-cache-local" \
    "docker" \
    "Local cache for frequently used Docker images"

# Create Docker virtual repository
create_virtual_repository \
    "${PROJECT_KEY}-dockerhub-virtual" \
    "docker" \
    "[\"${PROJECT_KEY}-dockerhub-cache-local\", \"${PROJECT_KEY}-dockerhub-remote\"]" \
    "Virtual repository aggregating local cache and Docker Hub remote"

echo ""
echo "✅ Dependency repositories creation completed successfully!"
echo ""
echo "📋 Created repositories:"
echo "   🐍 Python: ${PROJECT_KEY}-pypi-virtual (cache + PyPI.org)"
echo "   📦 npm: ${PROJECT_KEY}-npm-virtual (cache + npmjs.org)"
echo "   🐳 Docker: ${PROJECT_KEY}-dockerhub-virtual (cache + Docker Hub)"
echo ""
