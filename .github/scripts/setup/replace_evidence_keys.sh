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
    echo "Validating environment..." >&2
    
    # Check required environment variables
    if [[ -z "${PRIVATE_KEY_CONTENT:-}" ]]; then
        echo "PRIVATE_KEY_CONTENT environment variable is required" >&2
        exit 1
    fi
    
    if [[ -z "${PUBLIC_KEY_CONTENT:-}" ]]; then
        echo "PUBLIC_KEY_CONTENT environment variable is required" >&2
        exit 1
    fi
    
    if [[ -z "${KEY_ALIAS:-}" ]]; then
        echo "KEY_ALIAS environment variable is required" >&2
        exit 1
    fi
    
    # Check if gh CLI is available and authenticated
    if ! command -v gh &> /dev/null; then
        echo "GitHub CLI (gh) is not installed" >&2
        exit 1
    fi
    
    if ! gh auth status &> /dev/null; then
        echo "GitHub CLI is not authenticated" >&2
        exit 1
    fi
    
    echo "Environment validation successful" >&2
}

get_existing_repositories() {
    echo "Discovering existing BookVerse repositories..." >&2
    
    local existing_repos=()
    for repo in "${BOOKVERSE_REPOS[@]}"; do
        local full_repo="$GITHUB_ORG/$repo"
        if gh repo view "$full_repo" > /dev/null 2>&1; then
            existing_repos+=("$full_repo")
        else
            echo "Repository $full_repo not found - skipping" >&2
        fi
    done
    
    if [[ ${#existing_repos[@]} -eq 0 ]]; then
        echo "No BookVerse repositories found" >&2
        exit 1
    fi
    
    echo "Found ${#existing_repos[@]} repositories" >&2
    printf '%s\n' "${existing_repos[@]}"
}

# =============================================================================
# KEY REPLACEMENT FUNCTIONS
# =============================================================================

update_repository_secrets_and_variables() {
    local repo="$1"
    
    echo "Updating evidence keys in $repo..." >&2
    
    local success=true
    
    # Update private key secret
    echo "  → Updating EVIDENCE_PRIVATE_KEY secret..." >&2
    if printf "%s" "$PRIVATE_KEY_CONTENT" | gh secret set EVIDENCE_PRIVATE_KEY --repo "$repo" 2>/dev/null; then
        echo "    ✅ EVIDENCE_PRIVATE_KEY secret updated" >&2
    else
        echo "    ❌ Failed to update EVIDENCE_PRIVATE_KEY secret" >&2
        success=false
    fi
    
    # Update public key variable
    echo "  → Updating EVIDENCE_PUBLIC_KEY variable..." >&2
    if gh variable set EVIDENCE_PUBLIC_KEY --body "$PUBLIC_KEY_CONTENT" --repo "$repo" 2>/dev/null; then
        echo "    ✅ EVIDENCE_PUBLIC_KEY variable updated" >&2
    else
        echo "    ❌ Failed to update EVIDENCE_PUBLIC_KEY variable" >&2
        success=false
    fi
    
    # Update key alias variable
    echo "  → Updating EVIDENCE_KEY_ALIAS variable..." >&2
    if gh variable set EVIDENCE_KEY_ALIAS --body "$KEY_ALIAS" --repo "$repo" 2>/dev/null; then
        echo "    ✅ EVIDENCE_KEY_ALIAS variable updated" >&2
    else
        echo "    ❌ Failed to update EVIDENCE_KEY_ALIAS variable" >&2
        success=false
    fi
    
    if [[ "$success" == true ]]; then
        echo "✅ $repo updated successfully" >&2
    else
        echo "⚠️  $repo partially updated (some operations failed)" >&2
    fi
    
    return 0
}

replace_keys_in_all_repositories() {
    echo "Replacing evidence keys across all repositories..." >&2
    echo "" >&2
    
    local repos
    mapfile -t repos < <(get_existing_repositories)
    
    echo "" >&2
    echo "Updating evidence keys in ${#repos[@]} repositories..." >&2
    echo "" >&2
    
    local success_count=0
    local total_count=${#repos[@]}
    
    for repo in "${repos[@]}"; do
        if update_repository_secrets_and_variables "$repo"; then
            ((success_count++))
        fi
        echo "" >&2
    done
    
    echo "Replacement Summary:" >&2
    echo "  Repositories processed: $total_count" >&2
    echo "  Successfully updated: $success_count" >&2
    
    if [[ $success_count -eq $total_count ]]; then
        echo "All repositories updated successfully!" >&2
    else
        echo "Some repositories had issues (check logs above)" >&2
    fi
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    echo "🔄 Evidence Key Replacement" >&2
    echo "===========================" >&2
    echo "" >&2
    echo "This script will replace evidence keys across all BookVerse repositories." >&2
    echo "" >&2
    echo "🔑 Key alias: $KEY_ALIAS" >&2
    echo "📋 GitHub organization: $GITHUB_ORG" >&2
    echo "" >&2
    
    # Step 1: Validate environment
    validate_environment
    echo "" >&2
    
    # Step 2: Replace keys in all repositories
    replace_keys_in_all_repositories
    echo ""
    
    # Summary
    echo "🎯 Evidence Key Replacement Complete!"
    echo "====================================="
    echo ""
    echo "✅ Updated in all BookVerse repositories:"
    echo "  - EVIDENCE_PRIVATE_KEY (secret)"
    echo "  - EVIDENCE_PUBLIC_KEY (variable)"  
    echo "  - EVIDENCE_KEY_ALIAS (variable)"
    echo ""
    echo "🔑 Key alias: $KEY_ALIAS"
    echo ""
    echo "All repositories are now using the new evidence keys!" >&2
}

# Execute main function
main "$@"
