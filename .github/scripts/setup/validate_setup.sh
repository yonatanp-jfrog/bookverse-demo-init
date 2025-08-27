#!/usr/bin/env bash

# =============================================================================
# SETUP VALIDATION SCRIPT
# =============================================================================
# Validates that all BookVerse resources were created successfully
# Provides comprehensive verification of the complete setup
# =============================================================================

# Load shared utilities and configuration
source "$(dirname "$0")/common.sh"

# Initialize script with error handling and validation
init_script "$(basename "$0")" "Validating complete BookVerse setup"

# =============================================================================
# VALIDATION FUNCTIONS
# =============================================================================

# Count resources of a specific type
count_resources() {
    local endpoint="$1"
    local filter="$2"
    local description="$3"
    
    log_info "Counting $description..."
    
    local temp_file
    temp_file=$(mktemp)
    local response_code
    response_code=$(make_api_call GET "$endpoint" "" "$temp_file")
    
    if [[ "$response_code" -eq $HTTP_OK ]]; then
        local count
        count=$(jq -r "$filter" "$temp_file" 2>/dev/null | wc -l)
        log_success "Found $count $description"
        echo "$count"
    else
        log_warning "$description API not accessible (HTTP $response_code)"
        echo "0"
    fi
    
    rm -f "$temp_file"
}

# Validate specific resource exists
validate_resource_exists() {
    local endpoint="$1"
    local resource_name="$2"
    
    log_info "Validating $resource_name..."
    
    if resource_exists "$endpoint"; then
        log_success "$resource_name exists"
        return 0
    else
        log_error "$resource_name not found"
        return 1
    fi
}

# =============================================================================
# RESOURCE VALIDATION
# =============================================================================

log_step "Validating core project infrastructure"

# Validate project exists
validate_resource_exists \
    "${JFROG_URL}/access/api/v1/projects/${PROJECT_KEY}" \
    "Project '${PROJECT_KEY}'"

# Count repositories
repo_count=$(count_resources \
    "${JFROG_URL}/artifactory/api/repositories" \
    '.[] | select(.key | startswith("'${PROJECT_KEY}'")) | .key' \
    "repositories")

# Count users
user_count=$(count_resources \
    "${JFROG_URL}/api/security/users" \
    '.[] | select(.email | contains("@bookverse.com")) | .name' \
    "BookVerse users")

# Count applications
app_count=$(count_resources \
    "${JFROG_URL}/apptrust/api/v1/applications" \
    '.[] | select(.project_key == "'${PROJECT_KEY}'") | .application_key' \
    "applications")

# Count stages
stage_count=$(count_resources \
    "${JFROG_URL}/access/api/v2/stages" \
    '.[] | select(.name | startswith("'${PROJECT_KEY}'-")) | .name' \
    "project stages")

# Count OIDC integrations
oidc_count=$(count_resources \
    "${JFROG_URL}/access/api/v1/oidc" \
    '.[] | select(.name | startswith("github-'${PROJECT_KEY}'")) | .name' \
    "OIDC integrations")

# =============================================================================
# SUMMARY REPORT
# =============================================================================

echo ""
log_step "Setup validation summary"
echo ""
log_config "📋 BookVerse Resources Created:"
echo "   • Project: ${PROJECT_KEY}"
echo "   • Repositories: $repo_count"
echo "   • Users: $user_count" 
echo "   • Applications: $app_count"
echo "   • Stages: $stage_count"
echo "   • OIDC Integrations: $oidc_count"

echo ""
expected_repos=22
expected_users=12
expected_apps=4
expected_stages=3
expected_oidc=5

if [[ "$repo_count" -ge "$expected_repos" ]] && \
   [[ "$user_count" -ge "$expected_users" ]] && \
   [[ "$app_count" -ge "$expected_apps" ]] && \
   [[ "$stage_count" -ge "$expected_stages" ]] && \
   [[ "$oidc_count" -ge "$expected_oidc" ]]; then
    log_success "✨ BookVerse platform setup completed successfully!"
    log_success "🚀 Ready for development workflows and CI/CD operations"
else
    log_warning "⚠️  Some resources may be missing - review counts above"
    log_info "Expected: $expected_repos repos, $expected_users users, $expected_apps apps, $expected_stages stages, $expected_oidc OIDC"
fi

# Finalize script with standard status reporting
finalize_script "$(basename "$0")"
