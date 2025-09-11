#!/usr/bin/env bash

set -Eeuo pipefail

# =============================================================================
# SWITCH JFROG PLATFORM DEPLOYMENT (JPD) SCRIPT
# =============================================================================
# This script validates a new JPD platform and updates all BookVerse
# repositories with new JFROG_URL, JFROG_ADMIN_TOKEN, and DOCKER_REGISTRY values
# =============================================================================

# Enable xtrace when requested (useful in CI with BASH_XTRACE_ENABLED)
if [[ "${BASH_XTRACE_ENABLED:-0}" == "1" ]]; then
    set -x
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Disable colors when NO_COLOR is set or stdout is not a TTY
if [[ -n "${NO_COLOR:-}" || ! -t 1 ]]; then
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

# Logging functions
log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# Error handler to provide actionable diagnostics on failure
on_error() {
    local exit_code=$?
    local failed_command=${BASH_COMMAND}
    local src=${BASH_SOURCE[1]:-$0}
    local line=${BASH_LINENO[0]:-0}
    local func=${FUNCNAME[1]:-main}
    echo
    log_error "Command failed with exit code ${exit_code}"
    log_error "Location: ${src}:${line} (in ${func}())"
    log_error "Failed command: ${failed_command}"
    echo
    log_info "GitHub CLI status:" 
    if ! gh auth status 2>&1; then
        log_warning "gh auth status failed. Ensure GH_TOKEN is set with repo admin scopes."
    fi
    exit ${exit_code}
}

trap on_error ERR

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

# Track per-repository results
declare -a SUCCEEDED_REPOS=()
declare -a FAILED_REPOS=()
AUTH_FAILED=0
SERVICES_FAILED=0

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
    local was_xtrace=0
    if [[ -o xtrace ]]; then was_xtrace=1; set +x; fi
    # Show a sanitized version of the request for reproducibility
    log_info "Command: curl -s --max-time 10 --header 'Authorization: Bearer ***' --write-out '%{http_code}' '$NEW_JFROG_URL/artifactory/api/system/ping'"
    response=$(curl -s --max-time 10 \
        --header "Authorization: Bearer $NEW_JFROG_ADMIN_TOKEN" \
        --write-out "%{http_code}" \
        "$NEW_JFROG_URL/artifactory/api/system/ping")
    if [[ $was_xtrace -eq 1 ]]; then set -x; fi
    
    local http_code="${response: -3}"
    local body="${response%???}"
    
    if [[ "$http_code" != "200" ]]; then
        log_error "Authentication failed (HTTP $http_code)"
        log_error "Response: $body"
        echo
        log_info "Reproduce locally:"
        echo "curl -i -s --max-time 10 --header 'Authorization: Bearer ***' '$NEW_JFROG_URL/artifactory/api/system/ping'"
        if [[ "${CONTINUE_ON_AUTH_FAILURE:-0}" == "1" ]]; then
            AUTH_FAILED=1
            log_warning "Continuing despite authentication failure to update GitHub repo secrets/variables"
            return 0
        fi
        exit 1
    fi
    
    log_success "Authentication successful"
}

test_platform_services() {
    log_info "Testing platform services..."
    
    # Test Artifactory service
    local was_xtrace=0
    if [[ -o xtrace ]]; then was_xtrace=1; set +x; fi
    log_info "Command: curl -s --fail --max-time 10 --header 'Authorization: Bearer ***' '$NEW_JFROG_URL/artifactory/api/system/ping'"
    if ! curl -s --fail --max-time 10 \
        --header "Authorization: Bearer $NEW_JFROG_ADMIN_TOKEN" \
        "$NEW_JFROG_URL/artifactory/api/system/ping" > /dev/null; then
        log_error "Artifactory service is not available"
        if [[ $was_xtrace -eq 1 ]]; then set -x; fi
        if [[ "${CONTINUE_ON_AUTH_FAILURE:-0}" == "1" ]]; then
            SERVICES_FAILED=1
            log_warning "Continuing despite service check failure to update GitHub repo secrets/variables"
            return 0
        fi
        exit 1
    fi
    
    # Test Access service
    log_info "Command: curl -s --fail --max-time 10 --header 'Authorization: Bearer ***' '$NEW_JFROG_URL/access/api/v1/system/ping'"
    if ! curl -s --fail --max-time 10 \
        --header "Authorization: Bearer $NEW_JFROG_ADMIN_TOKEN" \
        "$NEW_JFROG_URL/access/api/v1/system/ping" > /dev/null; then
        log_warning "Access service is not available (may be expected for some deployments)"
    fi
    if [[ $was_xtrace -eq 1 ]]; then set -x; fi
    
    log_success "Core services are available"
}

# =============================================================================
# REPOSITORY UPDATE FUNCTIONS
# =============================================================================

extract_docker_registry() {
    # Extract hostname from JFROG_URL for DOCKER_REGISTRY
    echo "$NEW_JFROG_URL" | sed 's|https://||'
}

validate_gh_auth() {
    log_info "Validating GitHub CLI authentication..."
    # Avoid interactive prompts
    gh config set prompt disabled true >/dev/null 2>&1 || true
    if gh auth status >/dev/null 2>&1; then
        local gh_user
        gh_user=$(gh api user --jq .login 2>/dev/null || echo "unknown")
        log_success "GitHub CLI authenticated as: ${gh_user}"
    else
        log_error "GitHub CLI not authenticated. Set GH_TOKEN with required scopes (repo, actions, admin:repo_hook)."
        exit 1
    fi
}

trim_whitespace() {
    # Trim leading/trailing whitespace from a string
    local s="$1"
    # shellcheck disable=SC2001
    s=$(echo "$s" | sed 's/^\s*//;s/\s*$//')
    echo "$s"
}

get_variable_value() {
    # Retrieve repository variable value using GitHub REST API for stronger consistency
    # Falls back to gh variable get if REST call fails
    local full_repo="$1"
    local name="$2"
    local value
    value=$(gh api -H "Accept: application/vnd.github+json" \
        "repos/$full_repo/actions/variables/$name" --jq .value 2>/dev/null || echo "")
    if [[ -z "$value" ]]; then
        value=$(gh variable get "$name" --repo "$full_repo" 2>/dev/null || echo "")
    fi
    value=$(trim_whitespace "$value")
    echo "$value"
}

verify_variable_with_retry() {
    local full_repo="$1"
    local name="$2"
    local expected="$3"
    local attempts=0
    local max_attempts=12
    local delay_seconds=1
    local current

    expected=$(trim_whitespace "$expected")

    while (( attempts < max_attempts )); do
        current=$(get_variable_value "$full_repo" "$name")
        if [[ "$current" == "$expected" ]]; then
            log_success "  → Verified $name=$current"
            return 0
        fi
        ((attempts++))
        if (( attempts < max_attempts )); then
            sleep "$delay_seconds"
            # Exponential backoff with cap at 8 seconds
            if (( delay_seconds < 16 )); then
                delay_seconds=$(( delay_seconds * 2 ))
                if (( delay_seconds > 16 )); then delay_seconds=16; fi
            fi
        fi
    done

    log_warning "  → Verification failed for $name (expected: '$expected', got: '$current')"
    return 1
}

update_repository_secrets_and_variables() {
    local repo="$1"
    local full_repo="$GITHUB_ORG/$repo"
    
    log_info "Updating $full_repo..."
    
    # Extract docker registry from URL
    local docker_registry
    docker_registry=$(extract_docker_registry)

    local repo_ok=1

    # Update secrets
    log_info "  → Updating secrets..."
    local output
    local was_xtrace=0
    if [[ -o xtrace ]]; then was_xtrace=1; set +x; fi
    if ! output=$(gh secret set JFROG_ADMIN_TOKEN --repo "$full_repo" --body "$NEW_JFROG_ADMIN_TOKEN" 2>&1); then
        log_warning "  → Failed to update JFROG_ADMIN_TOKEN: ${output}"
        repo_ok=0
    fi

    if ! output=$(gh secret set JFROG_ACCESS_TOKEN --repo "$full_repo" --body "$NEW_JFROG_ADMIN_TOKEN" 2>&1); then
        log_warning "  → Failed to update JFROG_ACCESS_TOKEN: ${output}"
        repo_ok=0
    fi
    if [[ $was_xtrace -eq 1 ]]; then set -x; fi

    # Update variables
    log_info "  → Updating variables..."
    if ! output=$(gh variable set JFROG_URL --body "$NEW_JFROG_URL" --repo "$full_repo" 2>&1); then
        log_warning "  → Failed to update JFROG_URL: ${output}"
        repo_ok=0
    fi

    if ! output=$(gh variable set DOCKER_REGISTRY --body "$docker_registry" --repo "$full_repo" 2>&1); then
        log_warning "  → Failed to update DOCKER_REGISTRY: ${output}"
        repo_ok=0
    fi

    # Verify variables were set correctly (with retries to avoid eventual consistency issues)
    if ! verify_variable_with_retry "$full_repo" "JFROG_URL" "$NEW_JFROG_URL"; then
        log_warning "  → JFROG_URL verification failed, retrying update once..."
        gh variable set JFROG_URL --body "$NEW_JFROG_URL" --repo "$full_repo" >/dev/null 2>&1 || true
        if ! verify_variable_with_retry "$full_repo" "JFROG_URL" "$NEW_JFROG_URL"; then
            repo_ok=0
        else
            log_success "  → JFROG_URL verified after retry"
        fi
    fi
    if ! verify_variable_with_retry "$full_repo" "DOCKER_REGISTRY" "$docker_registry"; then
        log_warning "  → DOCKER_REGISTRY verification failed, retrying update once..."
        # Reapply the variable to mitigate eventual consistency and retry
        gh variable set DOCKER_REGISTRY --body "$docker_registry" --repo "$full_repo" >/dev/null 2>&1 || true
        if ! verify_variable_with_retry "$full_repo" "DOCKER_REGISTRY" "$docker_registry"; then
            repo_ok=0
        else
            log_success "  → DOCKER_REGISTRY verified after retry"
        fi
    fi

    if [[ $repo_ok -eq 1 ]]; then
        log_success "  → $repo updated successfully"
        SUCCEEDED_REPOS+=("$repo")
        return 0
    else
        log_warning "  → $repo updated with errors"
        FAILED_REPOS+=("$repo")
        return 1
    fi
}

update_all_repositories() {
    log_info "Updating all BookVerse repositories..."
    
    local total_count=${#BOOKVERSE_REPOS[@]}
    local success_count=0

    for repo in "${BOOKVERSE_REPOS[@]}"; do
        if update_repository_secrets_and_variables "$repo"; then
            ((++success_count))
        fi

        # After variables are updated, open a PR in each repo to replace hardcoded host strings
        # Best-effort only; skips if clone or PR fails
        local default_branch
        default_branch=$(gh repo view "$GITHUB_ORG/$repo" --json defaultBranchRef --jq .defaultBranchRef.name 2>/dev/null || echo "main")

        local workdir
        workdir=$(mktemp -d)
        pushd "$workdir" >/dev/null
        if gh repo clone "$GITHUB_ORG/$repo" repo >/dev/null 2>&1; then
            cd repo
            git checkout -b chore/switch-platform-$(date +%Y%m%d%H%M%S) >/dev/null 2>&1 || true

            local new_registry
            new_registry=$(extract_docker_registry)

            # Replace occurrences of the old host
            if rg -l "evidencetrial\\.jfrog\\.io" >/dev/null 2>&1; then
                rg -l "evidencetrial\\.jfrog\\.io" | xargs sed -i '' -e "s|evidencetrial\\.jfrog\\.io|${new_registry}|g"
            fi

            if rg -l "https://evidencetrial\\.jfrog\\.io" >/dev/null 2>&1; then
                rg -l "https://evidencetrial\\.jfrog\\.io" | xargs sed -i '' -e "s|https://evidencetrial\\.jfrog\\.io|${NEW_JFROG_URL}|g"
            fi

            if ! git diff --quiet; then
                git add -A
                git commit -m "chore: switch platform host to ${new_registry}" >/dev/null 2>&1 || true
                git push -u origin HEAD >/dev/null 2>&1 || true
                gh pr create --title "chore: switch platform host to ${new_registry}" \
                  --body "Automated replacement of old host with ${NEW_JFROG_URL}." \
                  --base "$default_branch" >/dev/null 2>&1 || true
                log_success "  → Opened PR with host replacements in $repo"
            else
                log_info "  → No host replacements needed in $repo"
            fi
        fi
        popd >/dev/null || true
        rm -rf "$workdir"
    done

    log_info "Repository update results:"
    echo "  ✓ Success: ${success_count}/${total_count}"
    echo "  ✗ Failed: $((total_count - success_count))/${total_count}"
}

# Perform a final re-verification pass for any repositories that reported verification errors.
# This mitigates GitHub API eventual consistency by giving changes extra time to propagate.
final_verification_pass() {
    if [[ ${#FAILED_REPOS[@]} -eq 0 ]]; then
        return 0
    fi

    log_info "Performing final verification pass for repositories with errors..."

    local docker_registry
    docker_registry=$(extract_docker_registry)

    # Make a copy, as we'll mutate FAILED_REPOS during iteration
    local to_check=("${FAILED_REPOS[@]}")
    local still_failed=()

    for repo in "${to_check[@]}"; do
        local full_repo="$GITHUB_ORG/$repo"
        log_info "  → Re-verifying $full_repo"

        # Small delay before re-check to allow propagation
        sleep 2

        local ok=1
        if ! verify_variable_with_retry "$full_repo" "JFROG_URL" "$NEW_JFROG_URL"; then
            # Reapply and retry once more
            gh variable set JFROG_URL --body "$NEW_JFROG_URL" --repo "$full_repo" >/dev/null 2>&1 || true
            if ! verify_variable_with_retry "$full_repo" "JFROG_URL" "$NEW_JFROG_URL"; then
                ok=0
            fi
        fi

        if ! verify_variable_with_retry "$full_repo" "DOCKER_REGISTRY" "$docker_registry"; then
            gh variable set DOCKER_REGISTRY --body "$docker_registry" --repo "$full_repo" >/dev/null 2>&1 || true
            if ! verify_variable_with_retry "$full_repo" "DOCKER_REGISTRY" "$docker_registry"; then
                ok=0
            fi
        fi

        if [[ $ok -eq 1 ]]; then
            log_success "  → $repo verified successfully on final pass"
            SUCCEEDED_REPOS+=("$repo")
        else
            log_warning "  → $repo still failing after final pass"
            still_failed+=("$repo")
        fi
    done

    # Replace FAILED_REPOS with those still failing
    FAILED_REPOS=("${still_failed[@]}")
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
    
    # Step 5.5: Validate GitHub CLI auth (for cross-repo updates)
    validate_gh_auth
    echo ""
    
    # Step 6: Update all repositories
    update_all_repositories
    echo ""

    # Step 6.5: Final verification pass to reduce false negatives
    final_verification_pass
    echo ""
    
    # Summary
    local docker_registry
    docker_registry=$(extract_docker_registry)
    
    local failed_count
    failed_count=${#FAILED_REPOS[@]}
    local success_count
    success_count=${#SUCCEEDED_REPOS[@]}

    echo "🎯 JPD Platform Switch Summary"
    echo "================================="
    echo "New Configuration:"
    echo "  JFROG_URL: $NEW_JFROG_URL"
    echo "  DOCKER_REGISTRY: $docker_registry"
    echo "  Total repositories: ${#BOOKVERSE_REPOS[@]}"
    echo "  Success: ${success_count}"
    echo "  Failed: ${failed_count}"

    if [[ ${success_count} -gt 0 ]]; then
        echo ""
        echo "✓ Updated repositories: ${SUCCEEDED_REPOS[*]}"
    fi

    if [[ ${failed_count} -gt 0 ]]; then
        echo ""
        echo "✗ Repositories with errors: ${FAILED_REPOS[*]}"
        echo ""
        log_error "Some repositories failed to update. See messages above."
        # Exit non-zero to mark the step as failed, but only after printing summary
        exit 1
    else
        echo ""
        log_success "All BookVerse repositories have been updated with new JPD configuration"
    fi
}

# Execute main function
main "$@"
