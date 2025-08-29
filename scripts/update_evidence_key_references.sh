#!/usr/bin/env bash

set -e

# =============================================================================
# UPDATE EVIDENCE KEY REFERENCES SCRIPT
# =============================================================================
# This script updates references to EVIDENCE_PUBLIC_KEY from secrets to variables
# across all BookVerse repositories in preparation for the evidence key overhaul.
#
# Changes:
# - secrets.EVIDENCE_PUBLIC_KEY → vars.EVIDENCE_PUBLIC_KEY
# - Updates CI workflows to treat public key as environment variable
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
        exit 1
    fi
    
    if ! gh auth status &> /dev/null; then
        log_error "GitHub CLI is not authenticated"
        exit 1
    fi
    
    log_success "Prerequisites satisfied"
}

# =============================================================================
# REPOSITORY UPDATE FUNCTIONS
# =============================================================================

get_workflow_files() {
    local repo="$1"
    
    # Get all workflow files from the repository
    gh api "repos/$repo/contents/.github/workflows" --jq '.[].name' 2>/dev/null || echo ""
}

download_workflow() {
    local repo="$1"
    local workflow_file="$2"
    local local_file="$3"
    
    gh api "repos/$repo/contents/.github/workflows/$workflow_file" --jq '.content' | base64 -d > "$local_file"
}

upload_workflow() {
    local repo="$1"
    local workflow_file="$2"
    local local_file="$3"
    local commit_message="$4"
    
    # Get the current file SHA for updating
    local sha
    sha=$(gh api "repos/$repo/contents/.github/workflows/$workflow_file" --jq '.sha' 2>/dev/null || echo "")
    
    local content_base64
    content_base64=$(base64 -i "$local_file")
    
    local json_payload
    if [[ -n "$sha" ]]; then
        json_payload=$(jq -n \
            --arg message "$commit_message" \
            --arg content "$content_base64" \
            --arg sha "$sha" \
            '{
                message: $message,
                content: $content,
                sha: $sha
            }')
    else
        json_payload=$(jq -n \
            --arg message "$commit_message" \
            --arg content "$content_base64" \
            '{
                message: $message,
                content: $content
            }')
    fi
    
    gh api "repos/$repo/contents/.github/workflows/$workflow_file" \
        --method PUT \
        --input - <<< "$json_payload" > /dev/null
}

update_workflow_file() {
    local workflow_file="$1"
    
    log_info "    Updating $workflow_file..."
    
    # Track if any changes were made
    local changes_made=false
    
    # Update secrets.EVIDENCE_PUBLIC_KEY to vars.EVIDENCE_PUBLIC_KEY
    if grep -q 'secrets\.EVIDENCE_PUBLIC_KEY' "$workflow_file"; then
        sed -i.bak 's/secrets\.EVIDENCE_PUBLIC_KEY/vars.EVIDENCE_PUBLIC_KEY/g' "$workflow_file"
        changes_made=true
        log_info "      → Updated secrets.EVIDENCE_PUBLIC_KEY to vars.EVIDENCE_PUBLIC_KEY"
    fi
    
    # Update any conditional checks for the public key secret
    if grep -q '\[\[ -n "\${{ secrets\.EVIDENCE_PUBLIC_KEY }}"' "$workflow_file"; then
        sed -i.bak 's/\[\[ -n "\${{ secrets\.EVIDENCE_PUBLIC_KEY }}"/[[ -n "${{ vars.EVIDENCE_PUBLIC_KEY }}"/g' "$workflow_file"
        changes_made=true
        log_info "      → Updated conditional check for public key"
    fi
    
    # Update any other patterns where public key is treated as secret
    if grep -q 'if: \${{ secrets\.EVIDENCE_PUBLIC_KEY }}' "$workflow_file"; then
        sed -i.bak 's/if: \${{ secrets\.EVIDENCE_PUBLIC_KEY }}/if: ${{ vars.EVIDENCE_PUBLIC_KEY }}/g' "$workflow_file"
        changes_made=true
        log_info "      → Updated conditional if statement for public key"
    fi
    
    # Clean up backup file
    rm -f "$workflow_file.bak"
    
    if [[ "$changes_made" == true ]]; then
        log_success "      ✅ Changes made to $workflow_file"
        return 0
    else
        log_info "      ⏭️  No changes needed in $workflow_file"
        return 1
    fi
}

update_repository_workflows() {
    local repo="$1"
    local full_repo="$GITHUB_ORG/$repo"
    
    log_info "Updating workflow files in $full_repo..."
    
    # Check if repository exists
    if ! gh repo view "$full_repo" > /dev/null 2>&1; then
        log_warning "  Repository $full_repo not found - skipping"
        return 0
    fi
    
    # Get workflow files
    local workflow_files
    workflow_files=$(get_workflow_files "$full_repo")
    
    if [[ -z "$workflow_files" ]]; then
        log_info "  No workflow files found in $full_repo"
        return 0
    fi
    
    # Create temporary directory for this repository
    local temp_dir
    temp_dir=$(mktemp -d)
    trap "rm -rf $temp_dir" EXIT
    
    local updated_files=()
    local total_files=0
    
    while IFS= read -r workflow_file; do
        if [[ -n "$workflow_file" ]]; then
            ((total_files++))
            local local_file="$temp_dir/$workflow_file"
            
            # Download the workflow file
            if download_workflow "$full_repo" "$workflow_file" "$local_file"; then
                # Update the file
                if update_workflow_file "$local_file"; then
                    # Upload the updated file
                    local commit_message="🔧 Update EVIDENCE_PUBLIC_KEY from secret to variable

- Changed secrets.EVIDENCE_PUBLIC_KEY to vars.EVIDENCE_PUBLIC_KEY
- Updated conditional checks and references
- Part of evidence key generation overhaul preparation"
                    
                    if upload_workflow "$full_repo" "$workflow_file" "$local_file" "$commit_message"; then
                        updated_files+=("$workflow_file")
                        log_success "    ✅ Updated and uploaded $workflow_file"
                    else
                        log_error "    ❌ Failed to upload $workflow_file"
                    fi
                else
                    log_info "    ⏭️  No updates needed for $workflow_file"
                fi
            else
                log_warning "    ⚠️  Could not download $workflow_file"
            fi
        fi
    done <<< "$workflow_files"
    
    if [[ ${#updated_files[@]} -gt 0 ]]; then
        log_success "  ✅ Updated ${#updated_files[@]}/$total_files workflow files in $repo"
        for file in "${updated_files[@]}"; do
            log_info "    - $file"
        done
    else
        log_info "  ⏭️  No workflow files needed updates in $repo"
    fi
    
    return 0
}

update_all_repositories() {
    log_info "Updating evidence key references in all repositories..."
    echo ""
    
    local success_count=0
    local total_count=${#BOOKVERSE_REPOS[@]}
    
    for repo in "${BOOKVERSE_REPOS[@]}"; do
        if update_repository_workflows "$repo"; then
            ((success_count++))
        fi
        echo ""
    done
    
    log_info "Update Summary:"
    log_info "  Repositories processed: $total_count"
    log_info "  Successfully updated: $success_count"
    
    if [[ $success_count -eq $total_count ]]; then
        log_success "All repositories processed successfully!"
    else
        log_warning "Some repositories had issues (check logs above)"
    fi
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    echo "🔄 Evidence Key Reference Updates"
    echo "=================================="
    echo ""
    echo "This script updates references to EVIDENCE_PUBLIC_KEY from secrets"
    echo "to variables across all BookVerse repository workflows."
    echo ""
    echo "Changes to be made:"
    echo "  - secrets.EVIDENCE_PUBLIC_KEY → vars.EVIDENCE_PUBLIC_KEY"
    echo "  - Update conditional checks and references"
    echo ""
    echo "GitHub Organization: $GITHUB_ORG"
    echo ""
    
    # Confirmation prompt
    read -p "Continue with evidence key reference updates? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Update cancelled by user"
        exit 0
    fi
    echo ""
    
    # Step 1: Validate prerequisites
    validate_prerequisites
    echo ""
    
    # Step 2: Update all repositories
    update_all_repositories
    echo ""
    
    # Summary
    echo "🎯 Evidence Key Reference Updates Complete!"
    echo "==========================================="
    echo ""
    echo "✅ Updated all references from secrets to variables:"
    echo "  - secrets.EVIDENCE_PUBLIC_KEY → vars.EVIDENCE_PUBLIC_KEY"
    echo ""
    log_success "Ready for evidence key generation overhaul!"
}

# Execute main function
main "$@"
