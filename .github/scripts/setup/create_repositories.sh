#!/usr/bin/env bash

# =============================================================================
# SIMPLIFIED REPOSITORIES CREATION SCRIPT
# =============================================================================
# Creates BookVerse repositories without shared utility dependencies
# =============================================================================

set -e

# Load configuration
source "$(dirname "$0")/config.sh"

echo ""
echo "🚀 Creating repositories for BookVerse microservices platform"
echo "🔧 Project: $PROJECT_KEY"
echo "🔧 JFrog URL: $JFROG_URL"
echo ""

# Repository creation function
create_repository() {
    local service="$1"
    local package_type="$2"
    local repo_type="$3"
    
    local repo_key="${PROJECT_KEY}-${service}-${package_type}-${repo_type}-local"
    
    # Build repository configuration (release repos don't need environment restrictions)
    if [[ "$repo_type" == "internal" ]]; then
        # Internal repositories are restricted to specific environments
        local environments="\"${PROJECT_KEY}-DEV\", \"${PROJECT_KEY}-QA\", \"${PROJECT_KEY}-STAGING\""
        local repo_config=$(jq -n \
            --arg key "$repo_key" \
            --arg rclass "local" \
            --arg packageType "$package_type" \
            --arg description "Repository for $service $package_type packages ($repo_type)" \
            --arg projectKey "$PROJECT_KEY" \
            --argjson environments "[$environments]" \
            '{
                "key": $key,
                "rclass": $rclass,
                "packageType": $packageType,
                "description": $description,
                "projectKey": $projectKey,
                "environments": $environments
            }')
    else
        # Release repositories are for production use without environment restrictions
        local repo_config=$(jq -n \
            --arg key "$repo_key" \
            --arg rclass "local" \
            --arg packageType "$package_type" \
            --arg description "Repository for $service $package_type packages ($repo_type)" \
            --arg projectKey "$PROJECT_KEY" \
            '{
                "key": $key,
                "rclass": $rclass,
                "packageType": $packageType,
                "description": $description,
                "projectKey": $projectKey
            }')
    fi
    
    echo "Creating repository: $repo_key"
    
    # Create repository
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
            echo "✅ Repository '$repo_key' created successfully (HTTP $response_code)"
            ;;
        409)
            echo "⚠️  Repository '$repo_key' already exists (HTTP $response_code)"
            ;;
        400)
            # Check if it's the "already exists" error which should be treated as success
            if grep -q "already exists" "$temp_response"; then
                echo "⚠️  Repository '$repo_key' already exists (HTTP $response_code)"
            else
                echo "❌ Failed to create repository '$repo_key' (HTTP $response_code)"
                echo "Response body: $(cat "$temp_response")"
                echo "Repository config sent:"
                echo "$repo_config" | jq .
                rm -f "$temp_response"
                return 1
            fi
            ;;
        *)
            echo "❌ Failed to create repository '$repo_key' (HTTP $response_code)"
            echo "Response body: $(cat "$temp_response")"
            echo "Repository config sent:"
            echo "$repo_config" | jq .
            rm -f "$temp_response"
            return 1
            ;;
    esac
    
    rm -f "$temp_response"
}

# Services and their package types
declare -A SERVICE_PACKAGES=(
    ["inventory"]="python docker"
    ["recommendations"]="python"  
    ["checkout"]="python"
    ["platform"]="maven"
    ["web"]="npm docker"
    ["helm"]="helm"
)

echo "Creating repositories for services..."
echo ""

# Create repositories for each service
for service in "${!SERVICE_PACKAGES[@]}"; do
    echo "Processing service: $service"
    
    # Get package types for this service
    package_types="${SERVICE_PACKAGES[$service]}"
    
    for package_type in $package_types; do
        # Create internal repository (for DEV/QA/STAGING)
        create_repository "$service" "$package_type" "internal"
        
        # Create release repository (for PROD)  
        create_repository "$service" "$package_type" "release"
    done
    
    echo ""
done

echo "✅ Service repositories creation completed successfully!"
echo ""

echo "=== Creating dependency repositories ==="
echo ""

# Create dependency repositories (remote, virtual, cache)
if [[ -f "$(dirname "$0")/create_dependency_repos.sh" ]]; then
    bash "$(dirname "$0")/create_dependency_repos.sh"
else
    echo "⚠️ Warning: create_dependency_repos.sh not found, skipping dependency repositories"
fi

echo ""
echo "=== Pre-populating dependencies ==="
echo ""

# Pre-populate critical dependencies
if [[ -f "$(dirname "$0")/prepopulate_dependencies.sh" ]]; then
    bash "$(dirname "$0")/prepopulate_dependencies.sh"
else
    echo "⚠️ Warning: prepopulate_dependencies.sh not found, skipping dependency pre-population"
fi

echo ""
echo "✅ Complete repository setup finished successfully!"
echo ""
echo "📋 Created repository types:"
echo "   🏢 Service repositories: Local repos for each microservice artifact"
echo "   🌐 Dependency repositories: Virtual repos for external dependencies"  
echo "   📦 Pre-populated dependencies: Critical packages cached in Artifactory"
echo ""