#!/usr/bin/env bash

set -euo pipefail

# =============================================================================
# REPLACE EVIDENCE KEYS SCRIPT
# =============================================================================
# This script replaces evidence keys across all BookVerse repositories with
# user-provided keys. It updates both secrets and variables as needed.
#
# Environment variables required:
# - PRIVATE_KEY_CONTENT: The private key content
# - PUBLIC_KEY_CONTENT: The public key content  
# - KEY_ALIAS: The key alias (from workflow input)
# - GH_TOKEN: GitHub token for authentication
# =============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions - ALL output to stderr to avoid contaminating stdout
log_info() { echo -e "${BLUE}ℹ️  $1${NC}" >&2; }
log_success() { echo -e "${GREEN}✅ $1${NC}" >&2; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}" >&2; }
log_error() { echo -e "${RED}❌ $1${NC}" >&2; }

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

# Get GitHub organization
if [[ -n "${GITHUB_REPOSITORY:-}" ]]; then
    GITHUB_ORG=$(echo "$GITHUB_REPOSITORY" | cut -d'/' -f1)
else
    GITHUB_ORG="${GITHUB_ORG:-$(gh api user --jq .login)}"
fi

# =============================================================================
# VALIDATION FUNCTIONS
# =============================================================================

validate_environment() {
    log_info "Validating environment..."
    
    # Check required environment variables
    if [[ -z "${PRIVATE_KEY_CONTENT:-}" ]]; then
        log_error "PRIVATE_KEY_CONTENT environment variable is required"
        exit 1
    fi
    
    if [[ -z "${PUBLIC_KEY_CONTENT:-}" ]]; then
        log_error "PUBLIC_KEY_CONTENT environment variable is required"
        exit 1
    fi
    
    if [[ -z "${KEY_ALIAS:-}" ]]; then
        log_error "KEY_ALIAS environment variable is required"
        exit 1
    fi
    
    # Check if gh CLI is available and authenticated
    if ! command -v gh &> /dev/null; then
        log_error "GitHub CLI (gh) is not installed"
        exit 1
    fi
    
    if ! gh auth status &> /dev/null; then
        log_error "GitHub CLI is not authenticated"
        exit 1
    fi
    
    log_success "Environment validation successful"
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
    # Output repository list to stdout (clean for GitHub CLI)
    printf '%s\n' "${existing_repos[@]}"
}

# =============================================================================
# KEY REPLACEMENT FUNCTIONS
# =============================================================================

update_repository_secrets_and_variables() {
    local repo="$1"
    
    log_info "Updating evidence keys in $repo..."
    
    local success=true
    
    # Update private key secret
    log_info "  → Updating EVIDENCE_PRIVATE_KEY secret..."
    if printf "%s" "$PRIVATE_KEY_CONTENT" | gh secret set EVIDENCE_PRIVATE_KEY --repo "$repo" 2>/dev/null; then
        log_success "    ✅ EVIDENCE_PRIVATE_KEY secret updated"
    else
        log_error "    ❌ Failed to update EVIDENCE_PRIVATE_KEY secret"
        success=false
    fi
    
    # Migrate public key from secret to variable (delete secret first if it exists)
    log_info "  → Migrating EVIDENCE_PUBLIC_KEY from secret to variable..."
    # Try to delete existing secret (ignore failure if it doesn't exist)
    gh secret delete EVIDENCE_PUBLIC_KEY --repo "$repo" 2>/dev/null || true
    log_info "    → Setting EVIDENCE_PUBLIC_KEY variable..."
    if gh variable set EVIDENCE_PUBLIC_KEY --body "$PUBLIC_KEY_CONTENT" --repo "$repo" 2>/dev/null; then
        log_success "    ✅ EVIDENCE_PUBLIC_KEY variable updated"
    else
        log_error "    ❌ Failed to update EVIDENCE_PUBLIC_KEY variable"
        success=false
    fi
    
    # Update key alias variable
    log_info "  → Updating EVIDENCE_KEY_ALIAS variable..."
    if gh variable set EVIDENCE_KEY_ALIAS --body "$KEY_ALIAS" --repo "$repo" 2>/dev/null; then
        log_success "    ✅ EVIDENCE_KEY_ALIAS variable updated"
    else
        log_error "    ❌ Failed to update EVIDENCE_KEY_ALIAS variable"
        success=false
    fi
    
    if [[ "$success" == true ]]; then
        log_success "✅ $repo updated successfully"
    else
        log_warning "⚠️  $repo partially updated (some operations failed)"
    fi
    
    return 0
}

replace_keys_in_all_repositories() {
    log_info "Replacing evidence keys across all repositories..."
    echo ""
    
    local repos
    mapfile -t repos < <(get_existing_repositories)
    
    echo ""
    log_info "Updating evidence keys in ${#repos[@]} repositories..."
    echo ""
    
    local success_count=0
    local total_count=${#repos[@]}
    
    for repo in "${repos[@]}"; do
        if update_repository_secrets_and_variables "$repo"; then
            ((success_count++))
        fi
        echo ""
    done
    
    log_info "Replacement Summary:"
    log_info "  Repositories processed: $total_count"
    log_info "  Successfully updated: $success_count"
    
    if [[ $success_count -eq $total_count ]]; then
        log_success "All repositories updated successfully!"
    else
        log_warning "Some repositories had issues (check logs above)"
    fi
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    log_info "🔄 Evidence Key Replacement"
    log_info "==========================="
    echo ""
    log_info "This script will replace evidence keys across all BookVerse repositories."
    echo ""
    log_info "🔑 Key alias: $KEY_ALIAS"
    log_info "📋 GitHub organization: $GITHUB_ORG"
    echo ""
    
    # Step 1: Validate environment
    validate_environment
    echo ""
    
    # Step 2: Replace keys in all repositories
    replace_keys_in_all_repositories
    echo ""
    
    # Summary
    log_success "🎯 Evidence Key Replacement Complete!"
    log_success "====================================="
    echo ""
    log_success "✅ Updated in all BookVerse repositories:"
    log_success "  - EVIDENCE_PRIVATE_KEY (secret)"
    log_success "  - EVIDENCE_PUBLIC_KEY (variable)"  
    log_success "  - EVIDENCE_KEY_ALIAS (variable)"
    echo ""
    log_info "🔑 Key alias: $KEY_ALIAS"
    echo ""
    log_success "All repositories are now using the new evidence keys!"
}

# Execute main function
main "$@"
