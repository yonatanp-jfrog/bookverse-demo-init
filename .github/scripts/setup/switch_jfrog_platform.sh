#!/usr/bin/env bash

set -Eeuo pipefail


if [[ "${BASH_XTRACE_ENABLED:-0}" == "1" ]]; then
    set -x
fi

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

if [[ -n "${NO_COLOR:-}" || ! -t 1 ]]; then
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

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


NEW_JFROG_URL="${NEW_JFROG_URL}"
NEW_JFROG_ADMIN_TOKEN="${NEW_JFROG_ADMIN_TOKEN}"

BOOKVERSE_REPOS=(
    "inventory"
    "recommendations" 
    "checkout"
    "platform"
    "web"
    "helm"
    "demo-init"
)

if [[ -n "$GITHUB_REPOSITORY" ]]; then
    GITHUB_ORG=$(echo "$GITHUB_REPOSITORY" | cut -d'/' -f1)
else
    GITHUB_ORG="${GITHUB_ORG:-$(gh api user --jq .login)}"
fi

log_info "GitHub Organization: $GITHUB_ORG"

declare -a SUCCEEDED_REPOS=()
declare -a FAILED_REPOS=()
AUTH_FAILED=0
SERVICES_FAILED=0


validate_inputs() {
    log_info "Validating inputs..."
    
    if [[ -n "$NEW_JFROG_URL" ]]; then
        log_info "NEW_JFROG_URL length: ${#NEW_JFROG_URL}"
        log_info "NEW_JFROG_URL starts with: ${NEW_JFROG_URL:0:8}..."
        log_info "NEW_JFROG_URL ends with: ...${NEW_JFROG_URL: -10}"
    else
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
    
    NEW_JFROG_URL=$(echo "$NEW_JFROG_URL" | sed 's:/*$::')
    
    if [[ ! "$NEW_JFROG_URL" =~ ^https://[a-zA-Z0-9.-]+\.jfrog\.io$ ]]; then
        log_error "Invalid host format. Expected: https://host.jfrog.io"
        log_error "Received: $NEW_JFROG_URL"
        exit 1
    fi
    
    log_success "Host format is valid: $NEW_JFROG_URL"
}

check_same_platform() {
    log_info "Checking for same-platform switch..."
    
    local current_url="${GITHUB_REPOSITORY_VARS_JFROG_URL:-}"
    
    current_url=$(echo "$current_url" | sed 's:/*$::')
    local new_url=$(echo "$NEW_JFROG_URL" | sed 's:/*$::')
    
    if [[ "$current_url" == "$new_url" ]]; then
        log_warning "Same-platform switch detected!"
        log_warning "Current: $current_url"
        log_warning "Target:  $new_url"
        log_info "This will refresh all repository configurations with the same platform"
        log_info "Useful for troubleshooting or resetting to a good state"
        echo ""
    else
        log_info "Platform migration detected:"
        log_info "From: $current_url"
        log_info "To:   $new_url"
        echo ""
    fi
}

test_platform_connectivity() {
    log_info "Testing platform connectivity..."
    
    if ! curl -s --fail --max-time 10 "$NEW_JFROG_URL" > /dev/null; then
        log_error "Cannot reach JPD platform: $NEW_JFROG_URL"
        exit 1
    fi
    
    log_success "Platform is reachable"
}

test_platform_authentication() {
    log_info "Testing platform authentication..."
    
    local response
    local was_xtrace=0
    if [[ -o xtrace ]]; then was_xtrace=1; set +x; fi
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
    
    log_info "Command: curl -s --fail --max-time 10 --header 'Authorization: Bearer ***' '$NEW_JFROG_URL/access/api/v1/system/ping'"
    if ! curl -s --fail --max-time 10 \
        --header "Authorization: Bearer $NEW_JFROG_ADMIN_TOKEN" \
        "$NEW_JFROG_URL/access/api/v1/system/ping" > /dev/null; then
        log_warning "Access service is not available (may be expected for some deployments)"
    fi
    if [[ $was_xtrace -eq 1 ]]; then set -x; fi
    
    log_success "Core services are available"
}


extract_docker_registry() {
    echo "$NEW_JFROG_URL" | sed 's|https://||'
}

validate_gh_auth() {
    log_info "Validating GitHub CLI authentication..."
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
    local s="$1"
    s=$(echo "$s" | sed 's/^\s*//;s/\s*$//')
    echo "$s"
}

get_variable_value() {
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
    
    local docker_registry
    docker_registry=$(extract_docker_registry)

    # Determine PROJECT_KEY from environment or default to bookverse
    local project_key="${PROJECT_KEY:-bookverse}"

    local repo_ok=1

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

    log_info "  → Updating variables..."
    if ! output=$(gh variable set JFROG_URL --body "$NEW_JFROG_URL" --repo "$full_repo" 2>&1); then
        log_warning "  → Failed to update JFROG_URL: ${output}"
        repo_ok=0
    fi

    if ! output=$(gh variable set DOCKER_REGISTRY --body "$docker_registry" --repo "$full_repo" 2>&1); then
        log_warning "  → Failed to update DOCKER_REGISTRY: ${output}"
        repo_ok=0
    fi

    # Update PROJECT_KEY environment variable
    if ! output=$(gh variable set PROJECT_KEY --body "$project_key" --repo "$full_repo" 2>&1); then
        log_warning "  → Failed to update PROJECT_KEY: ${output}"
        repo_ok=0
    fi

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
        gh variable set DOCKER_REGISTRY --body "$docker_registry" --repo "$full_repo" >/dev/null 2>&1 || true
        if ! verify_variable_with_retry "$full_repo" "DOCKER_REGISTRY" "$docker_registry"; then
            repo_ok=0
        else
            log_success "  → DOCKER_REGISTRY verified after retry"
        fi
    fi
    if ! verify_variable_with_retry "$full_repo" "PROJECT_KEY" "$project_key"; then
        log_warning "  → PROJECT_KEY verification failed, retrying update once..."
        gh variable set PROJECT_KEY --body "$project_key" --repo "$full_repo" >/dev/null 2>&1 || true
        if ! verify_variable_with_retry "$full_repo" "PROJECT_KEY" "$project_key"; then
            repo_ok=0
        else
            log_success "  → PROJECT_KEY verified after retry"
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
        # Construct full repository name: bookverse-{service} or {prefix}-bookverse-{service}
        local repo_name
        if [[ "$repo" == "demo-init" ]]; then
            repo_name="bookverse-demo-init"
        else
            repo_name="bookverse-${repo}"
        fi
        
        if update_repository_secrets_and_variables "$repo_name"; then
            ((++success_count))
        fi

        local default_branch
        default_branch=$(gh repo view "$GITHUB_ORG/$repo_name" --json defaultBranchRef --jq .defaultBranchRef.name 2>/dev/null || echo "main")

        local workdir
        workdir=$(mktemp -d)
        pushd "$workdir" >/dev/null
        if gh repo clone "$GITHUB_ORG/$repo_name" repo >/dev/null 2>&1; then
            cd repo
            
            # Configure git identity for this repository
            log_info "  → Configuring git identity for repository commits"
            git config user.name "github-actions[bot]"
            git config user.email "github-actions[bot]@users.noreply.github.com"
            
            # Configure git authentication for push operations
            if [[ -n "${GH_TOKEN:-}" ]]; then
                log_info "  → Configuring git authentication for push operations"
                git config url."https://x-access-token:${GH_TOKEN}@github.com/".insteadOf "https://github.com/"
                git remote set-url origin "https://x-access-token:${GH_TOKEN}@github.com/${GITHUB_ORG}/${repo_name}.git"
            else
                log_warning "  → GH_TOKEN not available, git push may fail"
            fi
            
            # Verify git configuration
            if ! git config user.name >/dev/null 2>&1 || ! git config user.email >/dev/null 2>&1; then
                log_warning "  → Failed to configure git identity, commits may fail"
            fi
            
            git checkout -b chore/switch-platform-$(date +%Y%m%d%H%M%S) >/dev/null 2>&1 || true

            local new_registry
            new_registry=$(extract_docker_registry)

            
            local changes_made=false
            
            # Comprehensive approach: Replace ALL .jfrog.io domain references
            # This works regardless of what the old platform was and catches all patterns
            
            # Define file exclusions for better performance and safety
            local exclude_args=(
                --exclude-dir=.git
                --exclude-dir=node_modules
                --exclude-dir=.venv
                --exclude-dir=__pycache__
                --exclude="*.pyc"
                --exclude="*.log"
                --exclude="*.tmp"
            )
            
            # Step 1: Replace full HTTPS URLs (https://anything.jfrog.io -> NEW_JFROG_URL)
            if grep -RIl "${exclude_args[@]}" -E "https://[A-Za-z0-9.-]*\.jfrog\.io" . >/dev/null 2>&1; then
                log_info "  → Found files with JFrog HTTPS URLs, updating to ${NEW_JFROG_URL}"
                if [[ "$OSTYPE" == "darwin"* ]]; then
                    grep -RIl "${exclude_args[@]}" -E "https://[A-Za-z0-9.-]*\.jfrog\.io" . | \
                        xargs sed -i '' -E "s|https://[A-Za-z0-9.-]+\.jfrog\.io|${NEW_JFROG_URL}|g"
                else
                    grep -RIl "${exclude_args[@]}" -E "https://[A-Za-z0-9.-]*\.jfrog\.io" . | \
                        xargs sed -i -E "s|https://[A-Za-z0-9.-]+\.jfrog\.io|${NEW_JFROG_URL}|g"
                fi
                changes_made=true
            fi
            
            # Step 2: Replace registry-only references with word boundaries (anything.jfrog.io -> new_registry)
            # This handles Docker image references and YAML values
            if grep -RIl "${exclude_args[@]}" -E "[A-Za-z0-9.-]+\.jfrog\.io" . >/dev/null 2>&1; then
                log_info "  → Found files with JFrog registry references, updating to ${new_registry}"
                if [[ "$OSTYPE" == "darwin"* ]]; then
                    grep -RIl "${exclude_args[@]}" -E "[A-Za-z0-9.-]+\.jfrog\.io" . | \
                        xargs sed -i '' -E "s|[A-Za-z0-9.-]+\.jfrog\.io|${new_registry}|g"
                else
                    grep -RIl "${exclude_args[@]}" -E "[A-Za-z0-9.-]+\.jfrog\.io" . | \
                        xargs sed -i -E "s|[A-Za-z0-9.-]+\.jfrog\.io|${new_registry}|g"
                fi
                changes_made=true
            fi
            
            # Step 3: Handle backup files and documentation (replace with full URL)
            if grep -RIl "${exclude_args[@]}" -E "[A-Za-z0-9.-]+\.jfrog\.io" . >/dev/null 2>&1; then
                log_info "  → Performing final cleanup of any remaining JFrog references"
                if [[ "$OSTYPE" == "darwin"* ]]; then
                    # Replace any remaining .jfrog.io references that might be in different contexts
                    find . -type f \( -name "*.md*" -o -name "*.txt" -o -name "*.sh" -o -name "*.py" -o -name "*.yaml" -o -name "*.yml" \) \
                        ! -path "./.git/*" ! -path "./node_modules/*" ! -path "./.venv/*" \
                        -exec grep -l "\.jfrog\.io" {} \; | \
                        xargs sed -i '' -E "s|[A-Za-z0-9.-]+\.jfrog\.io|${new_registry}|g" 2>/dev/null || true
                else
                    find . -type f \( -name "*.md*" -o -name "*.txt" -o -name "*.sh" -o -name "*.py" -o -name "*.yaml" -o -name "*.yml" \) \
                        ! -path "./.git/*" ! -path "./node_modules/*" ! -path "./.venv/*" \
                        -exec grep -l "\.jfrog\.io" {} \; | \
                        xargs sed -i -E "s|[A-Za-z0-9.-]+\.jfrog\.io|${new_registry}|g" 2>/dev/null || true
                fi
            fi

            # Check if there are actual changes to commit
            if ! git diff --quiet; then
                git add -A
                if git commit -m "chore: switch platform host to ${new_registry}"; then
                    if git push -u origin HEAD; then
                        if pr_url=$(gh pr create --title "chore: switch platform host to ${new_registry}" \
                          --body "Automated replacement of hardcoded JFrog hosts with ${NEW_JFROG_URL}." \
                          --base "$default_branch"); then
                            log_info "  → Created PR: $pr_url"
                            
                            # Auto-merge the PR since this is an automated platform switch
                            log_info "  → Auto-merging PR for automated platform switch"
                            sleep 2  # Brief delay to ensure PR is fully created
                            if gh pr merge "$pr_url" --squash --delete-branch; then
                                log_success "  → Successfully merged PR and updated $repo"
                            else
                                log_warning "  → Failed to auto-merge PR for $repo, manual merge required: $pr_url"
                            fi
                        else
                            log_warning "  → Failed to create PR for $repo, but changes were pushed"
                        fi
                    else
                        log_warning "  → Failed to push changes for $repo"
                    fi
                else
                    log_warning "  → Failed to commit changes for $repo"
                fi
            elif [[ "$changes_made" == "true" ]]; then
                log_info "  → Platform references were processed but no changes detected in $repo"
            else
                log_info "  → No platform references found in $repo"
            fi
        fi
        popd >/dev/null || true
        rm -rf "$workdir"
    done

    log_info "Repository update results:"
    echo "  ✓ Success: ${success_count}/${total_count}"
    echo "  ✗ Failed: $((total_count - success_count))/${total_count}"
}

final_verification_pass() {
    if [[ ${#FAILED_REPOS[@]} -eq 0 ]]; then
        return 0
    fi

    log_info "Performing final verification pass for repositories with errors..."

    local docker_registry
    docker_registry=$(extract_docker_registry)
    
    # Determine PROJECT_KEY from environment or default to bookverse
    local project_key="${PROJECT_KEY:-bookverse}"

    local to_check=("${FAILED_REPOS[@]}")
    local still_failed=()

    for repo in "${to_check[@]}"; do
        local full_repo="$GITHUB_ORG/$repo"
        log_info "  → Re-verifying $full_repo"

        sleep 2

        local ok=1
        if ! verify_variable_with_retry "$full_repo" "JFROG_URL" "$NEW_JFROG_URL"; then
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

        if ! verify_variable_with_retry "$full_repo" "PROJECT_KEY" "$project_key"; then
            gh variable set PROJECT_KEY --body "$project_key" --repo "$full_repo" >/dev/null 2>&1 || true
            if ! verify_variable_with_retry "$full_repo" "PROJECT_KEY" "$project_key"; then
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

    FAILED_REPOS=("${still_failed[@]}")
}


main() {
    echo "🔄 JFrog Platform Deployment (JPD) Switch"
    echo "=========================================="
    echo ""
    
    validate_inputs
    echo ""
    
    validate_host_format
    echo ""
    
    check_same_platform
    
    test_platform_connectivity
    echo ""
    
    test_platform_authentication  
    echo ""
    
    test_platform_services
    echo ""
    
    validate_gh_auth
    echo ""
    
    update_all_repositories
    echo ""

    final_verification_pass
    echo ""
    
    local docker_registry
    docker_registry=$(extract_docker_registry)
    
    # Determine PROJECT_KEY from environment or default to bookverse
    local project_key="${PROJECT_KEY:-bookverse}"
    
    local failed_count
    failed_count=${#FAILED_REPOS[@]}
    local success_count
    success_count=${#SUCCEEDED_REPOS[@]}

    echo "🎯 JPD Platform Switch Summary"
    echo "================================="
    echo "New Configuration:"
    echo "  JFROG_URL: $NEW_JFROG_URL"
    echo "  DOCKER_REGISTRY: $docker_registry"
    echo "  PROJECT_KEY: $project_key"
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
        exit 1
    else
        echo ""
        log_success "All BookVerse repositories have been updated with new JPD configuration"
    fi
}

main "$@"
