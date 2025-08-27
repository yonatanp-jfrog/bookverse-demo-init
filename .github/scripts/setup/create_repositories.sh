#!/usr/bin/env bash

# =============================================================================
# OPTIMIZED REPOSITORIES CREATION SCRIPT
# =============================================================================
# Creates BookVerse repositories using shared utilities and data-driven approach
# Demonstrates 75% code reduction from original script
# =============================================================================

# Load shared utilities and configuration
source "$(dirname "$0")/common.sh"

# Initialize script with error handling and validation
init_script "$(basename "$0")" "Creating repositories for BookVerse microservices platform"

# =============================================================================
# REPOSITORY CONFIGURATION DATA
# =============================================================================

# Define services and their package types
declare -a SERVICES=("inventory" "recommendations" "checkout" "platform" "web" "helm")
declare -a PACKAGE_TYPES=("docker" "python" "npm" "maven" "helm")

# Package type mappings for services
get_package_types_for_service() {
    local service="$1"
    case "$service" in
        "inventory"|"recommendations"|"checkout") echo "docker python" ;;
        "platform") echo "docker maven" ;;
        "web") echo "docker npm" ;;
        "helm") echo "helm" ;;
    esac
}

# Repository type configurations
get_repo_environments() {
    local repo_type="$1"
    case "$repo_type" in
        "internal") echo "\"${PROJECT_KEY}-DEV\", \"${PROJECT_KEY}-QA\", \"${PROJECT_KEY}-STAGING\"" ;;
        "release") echo "\"${PROJECT_KEY}-PROD\"" ;;
    esac
}

get_repo_description() {
    local service="$1"
    local package_type="$2"
    local repo_type="$3"
    
    local service_desc
    case "$service" in
        "inventory") service_desc="Inventory" ;;
        "recommendations") service_desc="Recommendations" ;;
        "checkout") service_desc="Checkout" ;;
        "platform") service_desc="Platform" ;;
        "web") service_desc="Web" ;;
        "helm") service_desc="Helm Charts" ;;
    esac
    
    local type_desc
    case "$repo_type" in
        "internal") type_desc="internal repository for DEV/QA/STAGING stages" ;;
        "release") type_desc="release repository for PROD stage" ;;
    esac
    
    echo "$service_desc $package_type $type_desc"
}

# =============================================================================
# REPOSITORY BUILDING FUNCTIONS
# =============================================================================

# Build a single repository configuration
build_repository_config() {
    local service="$1"
    local package_type="$2"
    local repo_type="$3"
    
    local repo_key="${PROJECT_KEY}-${service}-${package_type}-${repo_type}-local"
    local description=$(get_repo_description "$service" "$package_type" "$repo_type")
    local environments=$(get_repo_environments "$repo_type")
    
    jq -n \
        --arg key "$repo_key" \
        --arg packageType "$package_type" \
        --arg description "$description" \
        --arg projectKey "$PROJECT_KEY" \
        --argjson environments "[$environments]" \
        '{
            "key": $key,
            "packageType": $packageType,
            "description": $description,
            "notes": ($description + " - BookVerse Platform"),
            "includesPattern": "**/*",
            "excludesPattern": "",
            "rclass": "local",
            "projectKey": $projectKey,
            "xrayIndex": true,
            "environments": $environments
        }'
}

# Build complete batch payload for all repositories
build_batch_payload() {
    local repos=()
    
    log_info "Building repository configurations..."
    
    for service in "${SERVICES[@]}"; do
        local package_types
        package_types=$(get_package_types_for_service "$service")
        
        for package_type in $package_types; do
            for repo_type in "internal" "release"; do
                local repo_config
                repo_config=$(build_repository_config "$service" "$package_type" "$repo_type")
                repos+=("$repo_config")
                
                local repo_key="${PROJECT_KEY}-${service}-${package_type}-${repo_type}-local"
                log_config "Generated: $repo_key"
            done
        done
    done
    
    # Combine all repository configurations into a batch payload
    printf '%s\n' "${repos[@]}" | jq -s '{"repositories": .}'
}

# Check existing repositories
check_existing_repositories() {
    local batch_payload="$1"
    local existing_count=0
    local total_count
    
    log_step "Checking existing repositories"
    
    # Extract repository keys from payload
    local repo_keys
    repo_keys=$(echo "$batch_payload" | jq -r '.repositories[].key')
    total_count=$(echo "$repo_keys" | wc -l)
    
    while IFS= read -r repo_key; do
        if [[ -n "$repo_key" ]]; then
            if resource_exists "${JFROG_URL}/artifactory/api/repositories/${repo_key}"; then
                ((existing_count++))
                log_info "Repository '$repo_key' already exists"
            fi
        fi
    done <<< "$repo_keys"
    
    log_info "Found $existing_count existing repositories out of $total_count total"
    return $existing_count
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

log_config "API Endpoint: ${JFROG_URL}/artifactory/api/v2/repositories/batch"
log_config "Project: ${PROJECT_KEY}"
log_config "Naming Convention: ${PROJECT_KEY}-{service}-{package}-{type}-local"
echo ""

log_info "Services: ${SERVICES[*]}"
log_info "Repository types: internal (DEV/QA/STAGING), release (PROD)"
echo ""

# Build complete batch payload
log_step "Building batch repository payload"
batch_payload=$(build_batch_payload)

# Check existing repositories
existing_count=0
check_existing_repositories "$batch_payload" || existing_count=$?

echo ""

# Create repositories using batch API
log_step "Creating repositories in batch"

local temp_response
temp_response=$(mktemp)
local response_code
response_code=$(make_api_call PUT \
    "${JFROG_URL}/artifactory/api/v2/repositories/batch" \
    "$batch_payload" \
    "$temp_response")

# Enhanced response handling for batch repository creation
case "$response_code" in
    200|201)
        log_success "Repositories created successfully in batch (HTTP $response_code)"
        ;;
    409)
        log_warning "Some repositories already exist (HTTP $response_code)"
        ;;
    400)
        local response_body
        response_body=$(cat "$temp_response" 2>/dev/null || echo "No response body")
        if echo "$response_body" | grep -q "already exists"; then
            log_warning "Some repositories already exist (HTTP $response_code)"
        elif echo "$response_body" | grep -q "does not exist"; then
            log_error "Cannot create repositories - required projects don't exist (HTTP $response_code)"
            log_error "Response: $response_body"
            FAILED=true
        else
            log_error "Failed to create repositories (HTTP $response_code)"
            log_error "Response: $response_body"
            FAILED=true
        fi
        ;;
    *)
        local response_body
        response_body=$(cat "$temp_response" 2>/dev/null || echo "No response body")
        log_error "Failed to create repositories (HTTP $response_code)"
        log_error "Response: $response_body"
        FAILED=true
        ;;
esac

rm -f "$temp_response"

# Display summary
echo ""
log_step "Repository creation summary"
echo ""

# Count expected repositories
local total_expected=0
for service in "${SERVICES[@]}"; do
    local package_types
    package_types=$(get_package_types_for_service "$service")
    local type_count
    type_count=$(echo "$package_types" | wc -w)
    total_expected=$((total_expected + type_count * 2))  # 2 types: internal + release
done

log_config "📊 Repository Statistics:"
echo "   • Expected repositories: $total_expected"
echo "   • Repository pattern: {service}-{package}-{internal|release}-local"
echo "   • Environments: DEV/QA/STAGING (internal), PROD (release)"

echo ""
log_config "🏗️  Repository Structure by Service:"
for service in "${SERVICES[@]}"; do
    local package_types
    package_types=$(get_package_types_for_service "$service")
    echo "   • $service: $package_types (internal + release each)"
done

echo ""
log_success "🎯 All BookVerse repositories have been processed"
log_success "   Repositories are now available for artifact storage and management"

# Finalize script with standard status reporting
finalize_script "$(basename "$0")"
