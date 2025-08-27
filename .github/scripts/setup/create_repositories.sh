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
    
    # Get environments based on repo type
    local environments
    case "$repo_type" in
        "internal") environments="\"${PROJECT_KEY}-DEV\", \"${PROJECT_KEY}-QA\", \"${PROJECT_KEY}-STAGING\"" ;;
        "release") environments="\"${PROJECT_KEY}-PROD\"" ;;
    esac
    
    # Build repository configuration
    local repo_config=$(jq -n \
        --arg key "$repo_key" \
        --arg packageType "$package_type" \
        --arg description "Repository for $service $package_type packages ($repo_type)" \
        --arg projectKey "$PROJECT_KEY" \
        --argjson environments "[$environments]" \
        '{
            "key": $key,
            "packageType": $packageType,
            "description": $description,
            "projectKey": $projectKey,
            "environments": $environments
        }')
    
    echo "Creating repository: $repo_key"
    
    # Create repository
    local response_code=$(curl -s --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
        --header "Content-Type: application/json" \
        -X PUT \
        -d "$repo_config" \
        --write-out "%{http_code}" \
        --output /dev/null \
        "${JFROG_URL}/artifactory/api/repositories/${repo_key}")
    
    case "$response_code" in
        200|201)
            echo "✅ Repository '$repo_key' created successfully (HTTP $response_code)"
            ;;
        409)
            echo "⚠️  Repository '$repo_key' already exists (HTTP $response_code)"
            ;;
        *)
            echo "❌ Failed to create repository '$repo_key' (HTTP $response_code)"
            return 1
            ;;
    esac
}

# Services and their package types
declare -A SERVICE_PACKAGES=(
    ["inventory"]="python"
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

echo "✅ Repository creation completed successfully!"
echo ""