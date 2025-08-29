#!/usr/bin/env bash

# =============================================================================
# ENVIRONMENT VALIDATION SCRIPT
# =============================================================================
# Consolidated validation for JFrog connectivity and token permissions
# Replaces scattered validation logic across multiple workflow steps
# =============================================================================

# Load shared utilities and configuration
source "$(dirname "$0")/common.sh"

# Initialize script with error handling and validation
init_script "$(basename "$0")" "Validating JFrog platform environment"

# =============================================================================
# TOKEN VALIDATION
# =============================================================================

log_step "Validating JFROG_ADMIN_TOKEN"

if [[ -z "${JFROG_ADMIN_TOKEN}" ]]; then
    log_error "JFROG_ADMIN_TOKEN is empty or not configured"
    exit 1
fi

log_success "JFROG_ADMIN_TOKEN present (length: ${#JFROG_ADMIN_TOKEN})"

# =============================================================================
# CONNECTIVITY VALIDATION
# =============================================================================

# Use shared utility for comprehensive connectivity testing
validate_jfrog_connectivity

# =============================================================================
# API PERMISSIONS VALIDATION
# =============================================================================

log_step "Validating API permissions"

declare -a API_TESTS=(
    "GET|/access/api/v1/system/ping|System ping"
    "GET|/access/api/v1/projects|Projects API"
    "GET|/access/api/v2/lifecycle/?project_key=test|Lifecycle API"
    "GET|/api/security/users|Users API"
    "GET|/apptrust/api/v1/applications|AppTrust API"
    "GET|/access/api/v1/oidc|OIDC API"
)

for test in "${API_TESTS[@]}"; do
    IFS='|' read -r method endpoint description <<< "$test"
    
    log_info "Testing $description..."
    response_code=$(jfrog_api_call "$method" "${JFROG_URL}${endpoint}")
    
    # Accept 200 or 404 (for endpoints that require specific resources)
    if [[ "$response_code" -eq $HTTP_OK ]] || [[ "$response_code" -eq $HTTP_NOT_FOUND ]]; then
        log_success "$description accessible (HTTP $response_code)"
    else
        log_error "$description failed (HTTP $response_code)"
        FAILED=true
    fi
done

# =============================================================================
# CONFIGURATION DISPLAY
# =============================================================================

log_step "Environment configuration summary"
show_config

# Finalize script with standard status reporting
finalize_script "$(basename "$0")"
