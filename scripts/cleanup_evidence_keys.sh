#!/usr/bin/env bash

set -e

# =============================================================================
# CLEANUP EVIDENCE KEY SECRETS SCRIPT
# =============================================================================
# This script removes existing EVIDENCE_PRIVATE_KEY and EVIDENCE_PUBLIC_KEY 
# secrets from all BookVerse repositories in preparation for the evidence 
# key generation overhaul.
#
# NOTE: This only removes SECRETS, not variables. The secrets will be recreated.
# The public key will become an environment variable instead of a secret.
# =============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# =============================================================================
# CONFIGURATION
# =============================================================================

# BookVerse repository list
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

# Evidence key secrets to remove
EVIDENCE_SECRETS=(
    "EVIDENCE_PRIVATE_KEY"
    "EVIDENCE_PUBLIC_KEY"
)

# Get GitHub organization (defaults to current user)
if [[ -n "$GITHUB_REPOSITORY" ]]; then
    GITHUB_ORG=$(echo "$GITHUB_REPOSITORY" | cut -d'/' -f1)
else
    GITHUB_ORG="${GITHUB_ORG:-$(gh api user --jq .login)}"
fi

# =============================================================================
# VALIDATION FUNCTIONS
# =============================================================================

validate_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if gh CLI is installed and authenticated
    if ! command -v gh &> /dev/null; then
        log_error "GitHub CLI (gh) is not installed"
        log_info "Install it from: https://cli.github.com/"
        exit 1
    fi
    
    # Check if authenticated
    if ! gh auth status &> /dev/null; then
        log_error "GitHub CLI is not authenticated"
        log_info "Run: gh auth login"
        exit 1
    fi
    
    log_success "Prerequisites satisfied"
}

get_existing_repositories() {
    log_info "Discovering existing BookVerse repositories..."
    
    local existing_repos=()
    for repo in "${BOOKVERSE_REPOS[@]}"; do
        local full_repo="$GITHUB_ORG/$repo"
        if gh repo view "$full_repo" > /dev/null 2>&1; then
            existing_repos+=("$full_repo")
        else
            log_warning "Repository $full_repo not found - skipping"
        fi
    done
    
    if [[ ${#existing_repos[@]} -eq 0 ]]; then
        log_error "No BookVerse repositories found"
        exit 1
    fi
    
    log_info "Found ${#existing_repos[@]} repositories"
    printf '%s\n' "${existing_repos[@]}"
}

# =============================================================================
# SECRET CLEANUP FUNCTIONS
# =============================================================================

check_secret_exists() {
    local repo="$1"
    local secret_name="$2"
    
    # Use gh to list secrets and check if our secret exists
    if gh secret list --repo "$repo" 2>/dev/null | grep -q "^$secret_name"; then
        return 0  # Secret exists
    else
        return 1  # Secret does not exist
    fi
}

remove_secret_from_repo() {
    local repo="$1"
    local secret_name="$2"
    
    log_info "  → Checking $secret_name in $repo..."
    
    if check_secret_exists "$repo" "$secret_name"; then
        if gh secret remove "$secret_name" --repo "$repo" 2>/dev/null; then
            log_success "    ✅ Removed $secret_name from $repo"
            return 0
        else
            log_error "    ❌ Failed to remove $secret_name from $repo"
            return 1
        fi
    else
        log_info "    ⏭️  $secret_name not found in $repo (already clean)"
        return 0
    fi
}

cleanup_repository() {
    local repo="$1"
    
    log_info "Cleaning up evidence key secrets in $repo..."
    
    local success=true
    for secret in "${EVIDENCE_SECRETS[@]}"; do
        if ! remove_secret_from_repo "$repo" "$secret"; then
            success=false
        fi
    done
    
    if [[ "$success" == true ]]; then
        log_success "✅ $repo cleaned successfully"
    else
        log_warning "⚠️  $repo partially cleaned (some secrets failed to remove)"
    fi
    
    return 0
}

cleanup_all_repositories() {
    log_info "Starting evidence key secret cleanup across all repositories..."
    echo ""
    
    local repos
    mapfile -t repos < <(get_existing_repositories)
    
    echo ""
    log_info "Cleaning up evidence key secrets in ${#repos[@]} repositories..."
    echo ""
    
    local success_count=0
    local total_count=${#repos[@]}
    
    for repo in "${repos[@]}"; do
        if cleanup_repository "$repo"; then
            ((success_count++))
        fi
        echo ""
    done
    
    log_info "Cleanup Summary:"
    log_info "  Repositories processed: $total_count"
    log_info "  Successfully cleaned: $success_count"
    
    if [[ $success_count -eq $total_count ]]; then
        log_success "All repositories cleaned successfully!"
    else
        log_warning "Some repositories had issues (check logs above)"
    fi
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    echo "🧹 Evidence Key Secret Cleanup"
    echo "==============================="
    echo ""
    echo "This script will remove existing evidence key secrets from all"
    echo "BookVerse repositories in preparation for the evidence key overhaul."
    echo ""
    echo "Secrets to be removed:"
    for secret in "${EVIDENCE_SECRETS[@]}"; do
        echo "  - $secret"
    done
    echo ""
    echo "GitHub Organization: $GITHUB_ORG"
    echo ""
    
    # Confirmation prompt
    read -p "Continue with evidence key secret cleanup? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Cleanup cancelled by user"
        exit 0
    fi
    echo ""
    
    # Step 1: Validate prerequisites
    validate_prerequisites
    echo ""
    
    # Step 2: Clean up all repositories
    cleanup_all_repositories
    echo ""
    
    # Summary
    echo "🎯 Evidence Key Secret Cleanup Complete!"
    echo "========================================"
    echo ""
    echo "✅ Removed secrets from all BookVerse repositories:"
    for secret in "${EVIDENCE_SECRETS[@]}"; do
        echo "  - $secret"
    done
    echo ""
    log_info "Ready for evidence key generation overhaul!"
    echo ""
    log_warning "Note: Public key references should now be updated to use"
    log_warning "      environment variables instead of secrets"
}

# Execute main function
main "$@"
