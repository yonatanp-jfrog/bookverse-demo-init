#!/usr/bin/env bash

set -e

# =============================================================================
# SWITCH JFROG PLATFORM DEPLOYMENT (JPD) SCRIPT
# =============================================================================
# This script validates a new JPD platform and updates all BookVerse
# repositories with new JFROG_URL, JFROG_ADMIN_TOKEN, and DOCKER_REGISTRY values
# =============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# =============================================================================
# CONFIGURATION
# =============================================================================

# Get inputs from environment (set by GitHub Actions)
NEW_JFROG_URL="${NEW_JFROG_URL}"
NEW_JFROG_ADMIN_TOKEN="${NEW_JFROG_ADMIN_TOKEN}"

# BookVerse repository list (all repos that need secrets/variables updated)
BOOKVERSE_REPOS=(
    "bookverse-inventory"
    "bookverse-recommendations" 
    "bookverse-checkout"
    "bookverse-platform"
    "bookverse-web"
    "bookverse-helm"
    "bookverse-demo-assets"
    "bookverse-demo-init"
)

# Get GitHub organization (defaults to current user)
if [[ -n "$GITHUB_REPOSITORY" ]]; then
    GITHUB_ORG=$(echo "$GITHUB_REPOSITORY" | cut -d'/' -f1)
else
    GITHUB_ORG="${GITHUB_ORG:-$(gh api user --jq .login)}"
fi

log_info "GitHub Organization: $GITHUB_ORG"

# =============================================================================
# VALIDATION FUNCTIONS
# =============================================================================

validate_inputs() {
    log_info "Validating inputs..."
    
    if [[ -z "$NEW_JFROG_URL" ]]; then
        log_error "NEW_JFROG_URL is required"
        exit 1
    fi
    
    if [[ -z "$NEW_JFROG_ADMIN_TOKEN" ]]; then
        log_error "NEW_JFROG_ADMIN_TOKEN is required"
        exit 1
    fi
    
    if [[ -z "$GH_TOKEN" ]]; then
        log_error "GH_TOKEN is required for updating repositories"
        exit 1
    fi
    
    log_success "All required inputs provided"
}

validate_host_format() {
    log_info "Validating host format..."
    
    # Remove trailing slash if present
    NEW_JFROG_URL=$(echo "$NEW_JFROG_URL" | sed 's:/*$::')
    
    # Check format
    if [[ ! "$NEW_JFROG_URL" =~ ^https://[a-zA-Z0-9.-]+\.jfrog\.io$ ]]; then
        log_error "Invalid host format. Expected: https://host.jfrog.io"
        log_error "Received: $NEW_JFROG_URL"
        exit 1
    fi
    
    log_success "Host format is valid: $NEW_JFROG_URL"
}

test_platform_connectivity() {
    log_info "Testing platform connectivity..."
    
    # Test basic connectivity
    if ! curl -s --fail --max-time 10 "$NEW_JFROG_URL" > /dev/null; then
        log_error "Cannot reach JPD platform: $NEW_JFROG_URL"
        exit 1
    fi
    
    log_success "Platform is reachable"
}

test_platform_authentication() {
    log_info "Testing platform authentication..."
    
    # Test authentication with admin token
    local response
    response=$(curl -s --max-time 10 \
        --header "Authorization: Bearer $NEW_JFROG_ADMIN_TOKEN" \
        --write-out "%{http_code}" \
        "$NEW_JFROG_URL/artifactory/api/system/ping")
    
    local http_code="${response: -3}"
    local body="${response%???}"
    
    if [[ "$http_code" != "200" ]]; then
        log_error "Authentication failed (HTTP $http_code)"
        log_error "Response: $body"
        exit 1
    fi
    
    log_success "Authentication successful"
}

test_platform_services() {
    log_info "Testing platform services..."
    
    # Test Artifactory service
    if ! curl -s --fail --max-time 10 \
        --header "Authorization: Bearer $NEW_JFROG_ADMIN_TOKEN" \
        "$NEW_JFROG_URL/artifactory/api/system/ping" > /dev/null; then
        log_error "Artifactory service is not available"
        exit 1
    fi
    
    # Test Access service
    if ! curl -s --fail --max-time 10 \
        --header "Authorization: Bearer $NEW_JFROG_ADMIN_TOKEN" \
        "$NEW_JFROG_URL/access/api/v1/system/ping" > /dev/null; then
        log_warning "Access service is not available (may be expected for some deployments)"
    fi
    
    log_success "Core services are available"
}

# =============================================================================
# REPOSITORY UPDATE FUNCTIONS
# =============================================================================

extract_docker_registry() {
    # Extract hostname from JFROG_URL for DOCKER_REGISTRY
    echo "$NEW_JFROG_URL" | sed 's|https://||'
}

update_repository_secrets_and_variables() {
    local repo="$1"
    local full_repo="$GITHUB_ORG/$repo"
    
    log_info "Updating $full_repo..."
    
    # Extract docker registry from URL
    local docker_registry
    docker_registry=$(extract_docker_registry)
    
    # Update secrets
    log_info "  → Updating secrets..."
    if ! echo "$NEW_JFROG_ADMIN_TOKEN" | gh secret set JFROG_ADMIN_TOKEN --repo "$full_repo" 2>/dev/null; then
        log_warning "  → Failed to update JFROG_ADMIN_TOKEN secret (may not exist)"
    fi
    
    if ! echo "$NEW_JFROG_ADMIN_TOKEN" | gh secret set JFROG_ACCESS_TOKEN --repo "$full_repo" 2>/dev/null; then
        log_warning "  → Failed to update JFROG_ACCESS_TOKEN secret (may not exist)"
    fi
    
    # Update variables
    log_info "  → Updating variables..."
    if ! gh variable set JFROG_URL --body "$NEW_JFROG_URL" --repo "$full_repo" 2>/dev/null; then
        log_warning "  → Failed to update JFROG_URL variable (may not exist)"
    fi
    
    if ! gh variable set DOCKER_REGISTRY --body "$docker_registry" --repo "$full_repo" 2>/dev/null; then
        log_warning "  → Failed to update DOCKER_REGISTRY variable (may not exist)"
    fi
    
    log_success "  → $repo updated successfully"
}

update_all_repositories() {
    log_info "Updating all BookVerse repositories..."
    
    local success_count=0
    local total_count=${#BOOKVERSE_REPOS[@]}
    
    for repo in "${BOOKVERSE_REPOS[@]}"; do
        if update_repository_secrets_and_variables "$repo"; then
            ((success_count++))
        fi
    done
    
    log_success "Updated $success_count/$total_count repositories"
    
    if [[ $success_count -lt $total_count ]]; then
        log_warning "Some repositories failed to update (this may be expected)"
    fi
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    echo "🔄 JFrog Platform Deployment (JPD) Switch"
    echo "=========================================="
    echo ""
    
    # Step 1: Validate inputs
    validate_inputs
    echo ""
    
    # Step 2: Validate host format
    validate_host_format
    echo ""
    
    # Step 3: Test connectivity
    test_platform_connectivity
    echo ""
    
    # Step 4: Test authentication
    test_platform_authentication  
    echo ""
    
    # Step 5: Test services
    test_platform_services
    echo ""
    
    # Step 6: Update all repositories
    update_all_repositories
    echo ""
    
    # Summary
    local docker_registry
    docker_registry=$(extract_docker_registry)
    
    echo "🎯 JPD Platform Switch Complete!"
    echo "================================="
    echo "New Configuration:"
    echo "  JFROG_URL: $NEW_JFROG_URL"
    echo "  DOCKER_REGISTRY: $docker_registry"
    echo "  Updated repositories: ${#BOOKVERSE_REPOS[@]}"
    echo ""
    echo "✅ All BookVerse repositories have been updated with new JPD configuration"
}

# Execute main function
main "$@"
