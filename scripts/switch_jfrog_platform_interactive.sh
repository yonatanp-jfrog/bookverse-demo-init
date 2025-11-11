#!/usr/bin/env bash

set -e


RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;36m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }
log_prompt() { echo -e "${CYAN}🔹 $1${NC}"; }


prompt_for_project_prefix() {
    echo ""
    log_prompt "Enter an optional prefix for the BookVerse project (leave empty for no prefix):"
    log_info "This allows multiple BookVerse instances in the same JPD"
    log_info "Format: prefix (will create 'prefix-bookverse' project)"
    log_info "Example: 'demo1' creates 'demo1-bookverse'"
    echo ""
    read -p "Project Prefix (optional): " project_prefix
    
    # Validate prefix format if provided
    if [[ -n "$project_prefix" ]]; then
        if [[ ! "$project_prefix" =~ ^[a-z0-9][a-z0-9-]*[a-z0-9]$|^[a-z0-9]$ ]]; then
            log_error "Invalid prefix format. Use lowercase letters, numbers, and hyphens only."
            log_error "Must start and end with alphanumeric characters."
            exit 1
        fi
        log_info "Using project prefix: '$project_prefix' (project will be '${project_prefix}-bookverse')"
    else
        log_info "No prefix specified (project will be 'bookverse')"
    fi
    
    echo "$project_prefix"
}

prompt_for_jpd_host() {
    echo ""
    log_prompt "Enter the new JFrog Platform host URL:"
    log_info "Format: https://yourcompany.jfrog.io"
    log_info "Example: https://acme.jfrog.io"
    echo ""
    read -p "JFrog Platform Host URL: " jpd_host
    
    jpd_host=$(echo "$jpd_host" | sed 's:/*$::')
    
    if [[ -z "$jpd_host" ]]; then
        log_error "Host URL is required"
        exit 1
    fi
    
    echo "$jpd_host"
}

prompt_for_admin_token() {
    echo ""
    log_prompt "Enter the admin token for the new JFrog Platform:"
    log_warning "This token will be used to validate connectivity and update repositories"
    echo ""
    read -s -p "Admin Token: " admin_token
    echo ""
    
    if [[ -z "$admin_token" ]]; then
        log_error "Admin token is required"
        exit 1
    fi
    
    echo "$admin_token"
}

confirm_switch() {
    local jpd_host="$1"
    local current_host="${JFROG_URL:-}"
    
    echo ""
    echo "🔄 JFrog Platform Switch Confirmation"
    echo "===================================="
    echo ""
    echo "Current Platform: $current_host"
    echo "New Platform:     $jpd_host"
    echo ""
    log_warning "This will update secrets and variables in ALL BookVerse repositories!"
    echo ""
    log_prompt "Type 'SWITCH' to confirm platform migration:"
    read -p "Confirmation: " confirmation
    
    if [[ "$confirmation" != "SWITCH" ]]; then
        log_error "Platform switch cancelled"
        exit 1
    fi
    
    log_success "Platform switch confirmed"
}


validate_prerequisites() {
    log_info "Checking prerequisites..."
    
    if ! command -v gh &> /dev/null; then
        log_error "GitHub CLI (gh) is not installed"
        log_info "Install it from: https://cli.github.com/"
        exit 1
    fi
    
    if ! gh auth status &> /dev/null; then
        log_error "GitHub CLI is not authenticated"
        log_info "Run: gh auth login"
        exit 1
    fi
    
    if ! command -v curl &> /dev/null; then
        log_error "curl is not installed"
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        log_error "jq is not installed" 
        exit 1
    fi
    
    log_success "All prerequisites satisfied"
}

validate_host_format() {
    local host="$1"
    
    log_info "Validating host format..."
    
    if [[ ! "$host" =~ ^https://[a-zA-Z0-9.-]+\.jfrog\.io$ ]]; then
        log_error "Invalid host format"
        log_error "Expected: https://host.jfrog.io"
        log_error "Received: $host"
        exit 1
    fi
    
    log_success "Host format is valid"
}

test_connectivity_and_auth() {
    local host="$1"
    local token="$2"
    
    log_info "Testing connectivity and authentication..."
    
    if ! curl -s --fail --max-time 10 "$host" > /dev/null; then
        log_error "Cannot reach JFrog platform: $host"
        exit 1
    fi
    
    local response
    response=$(curl -s --max-time 10 \
        --header "Authorization: Bearer $token" \
        --write-out "%{http_code}" \
        "$host/artifactory/api/system/ping" 2>/dev/null || echo "000")
    
    local http_code="${response: -3}"
    
    if [[ "$http_code" != "200" ]]; then
        log_error "Authentication failed (HTTP $http_code)"
        if [[ "$http_code" == "000" ]]; then
            log_error "Connection failed - check host URL and network connectivity"
        elif [[ "$http_code" == "401" ]]; then
            log_error "Invalid admin token"
        elif [[ "$http_code" == "403" ]]; then
            log_error "Token lacks required permissions"
        fi
        exit 1
    fi
    
    log_success "Connectivity and authentication verified"
}

test_services() {
    local host="$1"
    local token="$2"
    
    log_info "Testing platform services..."
    
    if curl -s --fail --max-time 10 \
        --header "Authorization: Bearer $token" \
        "$host/artifactory/api/system/ping" > /dev/null; then
        log_success "Artifactory service: Available"
    else
        log_error "Artifactory service: Not available"
        exit 1
    fi
    
    if curl -s --fail --max-time 10 \
        --header "Authorization: Bearer $token" \
        "$host/access/api/v1/system/ping" > /dev/null 2>&1; then
        log_success "Access service: Available"
    else
        log_warning "Access service: Not available (may be expected)"
    fi
}


patch_repo_envs() {
    local jpd_host="$1"
    local admin_token="$2"
    local repo_key="$3"
    shift 3
    local -a envs=("$@")

    local env_json
    env_json=$(printf '"%s",' "${envs[@]}")
    env_json="[${env_json%,}]"

    local body
    body=$(mktemp)
    local code
    code=$(curl -sS -L -o "$body" -w "%{http_code}" -X PATCH \
        "$jpd_host/artifactory/api/v2/repositories/$repo_key" \
        -H "Authorization: Bearer $admin_token" \
        -H "Content-Type: application/json" \
        -d "{\"environments\": $env_json}" || echo 000)

    if [[ "$code" -ge 200 && "$code" -lt 300 ]]; then
        log_success "  → $repo_key environments set to $env_json"
    else
        log_warning "  → Failed to patch $repo_key environments (HTTP $code)"
        cat "$body" 2>/dev/null || true
    fi
    rm -f "$body"
}

repair_repository_environments() {
    local jpd_host="$1"
    local admin_token="$2"
    local project_prefix="$3"

    log_info "Repairing repository environments mapping (internal → DEV/QA/STAGING, release → PROD)"

    local project_key
    if [[ -n "$project_prefix" ]]; then
        project_key="${project_prefix}-bookverse"
    else
        project_key="bookverse"
    fi

    local dev_envs=("${project_key}-DEV" "${project_key}-QA" "${project_key}-STAGING")

    local list_json
    list_json=$(curl -sS -L -H "Authorization: Bearer $admin_token" \
        "$jpd_host/artifactory/api/repositories" 2>/dev/null || echo "[]")

    mapfile -t repo_keys < <(echo "$list_json" | jq -r --arg p "${project_key}-" '.[]? | select(.key | startswith($p)) | .key')

    for key in "${repo_keys[@]}"; do
        if [[ "$key" == *"-internal-local" ]]; then
            patch_repo_envs "$jpd_host" "$admin_token" "$key" "${dev_envs[@]}"
        elif [[ "$key" == *"-release-local" ]]; then
            patch_repo_envs "$jpd_host" "$admin_token" "$key" "PROD"
        fi
    done

    log_success "Repository environments mapping repaired."
}


get_bookverse_repos() {
    local github_org
    github_org=$(gh api user --jq .login)
    
    local base_repos=(
        "inventory"
        "recommendations" 
        "checkout"
        "platform"
        "web"
        "helm"
        "demo-assets"
        "demo-init"
    )
    
    local existing_repos=()
    for repo in "${base_repos[@]}"; do
        # Construct full repository name
        local repo_name
        if [[ "$repo" == "demo-assets" ]]; then
            repo_name="repos/bookverse-demo-assets"
        elif [[ "$repo" == "demo-init" ]]; then
            repo_name="bookverse-demo-init"
        else
            repo_name="bookverse-${repo}"
        fi
        
        if gh repo view "$github_org/$repo_name" > /dev/null 2>&1; then
            existing_repos+=("$github_org/$repo_name")
        else
            log_warning "Repository $github_org/$repo_name not found - skipping"
        fi
    done
    
    printf '%s\n' "${existing_repos[@]}"
}

update_repository() {
    local full_repo="$1"
    local jpd_host="$2"
    local admin_token="$3"
    local project_prefix="$4"
    
    log_info "Updating $full_repo..."
    
    local docker_registry
    docker_registry=$(echo "$jpd_host" | sed 's|https://||')
    
    local project_key
    if [[ -n "$project_prefix" ]]; then
        project_key="${project_prefix}-bookverse"
    else
        project_key="bookverse"
    fi
    
    local success=true
    
    echo "$admin_token" | gh secret set JFROG_ADMIN_TOKEN --repo "$full_repo" 2>/dev/null || true
    echo "$admin_token" | gh secret set JFROG_ACCESS_TOKEN --repo "$full_repo" 2>/dev/null || true
    
    if ! gh variable set JFROG_URL --body "$jpd_host" --repo "$full_repo" 2>/dev/null; then
        log_warning "  → Could not update JFROG_URL variable"
        success=false
    fi
    
    if ! gh variable set DOCKER_REGISTRY --body "$docker_registry" --repo "$full_repo" 2>/dev/null; then
        log_warning "  → Could not update DOCKER_REGISTRY variable"
        success=false
    fi
    
    # Update PROJECT_KEY environment variable
    if ! gh variable set PROJECT_KEY --body "$project_key" --repo "$full_repo" 2>/dev/null; then
        log_warning "  → Could not update PROJECT_KEY variable"
        success=false
    fi
    
    if [[ "$success" == true ]]; then
        log_success "  → $full_repo updated successfully"
    else
        log_warning "  → $full_repo partially updated"
    fi
    
    local default_branch
    default_branch=$(gh repo view "$full_repo" --json defaultBranchRef --jq .defaultBranchRef.name 2>/dev/null || echo "main")

    local workdir
    workdir=$(mktemp -d)
    pushd "$workdir" >/dev/null

    if gh repo clone "$full_repo" repo >/dev/null 2>&1; then
        cd repo
        git checkout -b chore/switch-platform-$(date +%Y%m%d%H%M%S) >/dev/null 2>&1 || true

        local new_registry
        new_registry=$(echo "$jpd_host" | sed 's|https://||')

        if grep -RIl --exclude-dir=.git -e "https://[A-Za-z0-9.-]*\\.jfrog\\.io" . >/dev/null 2>&1; then
            grep -RIl --exclude-dir=.git -e "https://[A-Za-z0-9.-]*\\.jfrog\\.io" . | xargs sed -i '' -E "s|https://[A-Za-z0-9.-]+\\.jfrog\\.io|${jpd_host}|g"
        fi

        if grep -RIl --exclude-dir=.git -e "[A-Za-z0-9.-]*\\.jfrog\\.io" . >/dev/null 2>&1; then
            grep -RIl --exclude-dir=.git -e "[A-Za-z0-9.-]*\\.jfrog\\.io" . | xargs sed -i '' -E "s|\b[A-Za-z0-9.-]+\\.jfrog\\.io\b|${new_registry}|g"
        fi

        if ! git diff --quiet; then
            git add -A
            git commit -m "chore: switch platform host to ${new_registry}" >/dev/null 2>&1 || true
            git push -u origin HEAD >/dev/null 2>&1 || true
            gh pr create --title "chore: switch platform host to ${new_registry}" \
              --body "Automated replacement of old host with ${jpd_host}." \
              --base "$default_branch" >/dev/null 2>&1 || true
            log_success "  → Opened PR with host replacements in $full_repo"
        else
            log_info "  → No host replacements needed in $full_repo"
        fi
    else
        log_warning "  → Could not clone $full_repo for in-repo replacements"
    fi

    popd >/dev/null || true
    rm -rf "$workdir"

    return 0
}

update_all_repositories() {
    local jpd_host="$1"
    local admin_token="$2"
    local project_prefix="$3"
    
    log_info "Discovering BookVerse repositories..."
    
    local repos
    mapfile -t repos < <(get_bookverse_repos)
    
    if [[ ${#repos[@]} -eq 0 ]]; then
        log_error "No BookVerse repositories found"
        exit 1
    fi
    
    log_info "Found ${#repos[@]} BookVerse repositories"
    echo ""
    
    local success_count=0
    for repo in "${repos[@]}"; do
        if update_repository "$repo" "$jpd_host" "$admin_token" "$project_prefix"; then
            ((success_count++))
        fi
    done
    
    echo ""
    log_success "Updated $success_count/${#repos[@]} repositories successfully"
}


main() {
    echo "🔄 Interactive Platform Switch"
    echo "==================================="
    echo ""
    echo "This script will help you switch to a new JFrog Platform Deployment"
    echo "and update all BookVerse repositories with the new configuration."
    echo ""
    
    validate_prerequisites
    echo ""
    
    local project_prefix
    project_prefix=$(prompt_for_project_prefix)
    
    local jpd_host
    jpd_host=$(prompt_for_jpd_host)
    
    validate_host_format "$jpd_host"
    echo ""
    
    local admin_token
    admin_token=$(prompt_for_admin_token)
    echo ""
    
    test_connectivity_and_auth "$jpd_host" "$admin_token"
    echo ""
    
    test_services "$jpd_host" "$admin_token"
    echo ""
    
    confirm_switch "$jpd_host"
    echo ""
    
    update_all_repositories "$jpd_host" "$admin_token" "$project_prefix"
    echo ""

    repair_repository_environments "$jpd_host" "$admin_token" "$project_prefix"
    echo ""
    
    local docker_registry
    docker_registry=$(echo "$jpd_host" | sed 's|https://||')
    
    echo "🎯 Platform Switch Complete!"
    echo "================================="
    echo "New Configuration:"
    echo "  JFROG_URL: $jpd_host"
    echo "  DOCKER_REGISTRY: $docker_registry"
    if [[ -n "$project_prefix" ]]; then
        echo "  PROJECT_KEY: ${project_prefix}-bookverse"
    else
        echo "  PROJECT_KEY: bookverse"
    fi
    echo ""
    echo "✅ All BookVerse repositories have been updated!"
    echo ""
    log_info "You can now run workflows on the new JFrog platform"
}

main "$@"
