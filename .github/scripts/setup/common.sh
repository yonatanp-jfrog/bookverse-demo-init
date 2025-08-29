#!/usr/bin/env bash

# =============================================================================
# SHARED UTILITIES FOR BOOKVERSE INIT SCRIPTS
# =============================================================================
# Common functions and utilities used across all setup scripts
# This reduces boilerplate and standardizes error handling
# =============================================================================

# HTTP Status Codes
readonly HTTP_OK=200
readonly HTTP_CREATED=201
readonly HTTP_NO_CONTENT=204
readonly HTTP_BAD_REQUEST=400
readonly HTTP_UNAUTHORIZED=401
readonly HTTP_NOT_FOUND=404
readonly HTTP_CONFLICT=409
readonly HTTP_INTERNAL_ERROR=500

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# =============================================================================
# ERROR HANDLING AND LOGGING
# =============================================================================

# Global error flag
FAILED=false

# Enhanced error handler with context
error_handler() {
    local line_no=$1
    local error_code=$2
    local script_name=${3:-$(basename "$0")}
    
    echo ""
    echo -e "${RED}❌ SCRIPT ERROR DETECTED!${NC}"
    echo "   Script: $script_name"
    echo "   Line: $line_no"
    echo "   Exit Code: $error_code"
    echo "   Command: ${BASH_COMMAND}"
    echo ""
    echo -e "${CYAN}🔍 DEBUGGING INFORMATION:${NC}"
    echo "   Environment: CI=${CI_ENVIRONMENT:-'Not set'}"
    echo "   Working Directory: $(pwd)"
    echo "   Project: ${PROJECT_KEY:-'Not set'}"
    echo "   JFrog URL: ${JFROG_URL:-'Not set'}"
    echo ""
    exit $error_code
}

# Set up error handling for any script that sources this
setup_error_handling() {
    local script_name=${1:-$(basename "$0")}
    trap "error_handler \${LINENO} \$? \"$script_name\"" ERR
    set -e
}

# Logging functions with consistent formatting
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
    FAILED=true
}

log_step() {
    echo -e "${PURPLE}🚀 $1${NC}"
}

log_config() {
    echo -e "${CYAN}🔧 $1${NC}"
}

# =============================================================================
# HTTP API UTILITIES
# =============================================================================

# Make HTTP API call with standardized error handling
# Usage: jfrog_api_call METHOD URL [DATA] [OUTPUT_FILE]  
jfrog_api_call() {
    local method="$1"
    local url="$2"
    local data="${3:-}"
    local output_file="${4:-/dev/null}"
    local temp_file
    temp_file=$(mktemp)
    
    local curl_args=(
        -s
        -w "%{http_code}"
        -o "$temp_file"
        --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}"
        --header "Content-Type: application/json"
        -X "$method"
    )
    
    # Add data if provided
    if [[ -n "$data" ]]; then
        curl_args+=(-d "$data")
    fi
    
    # Make the API call
    local response_code
    response_code=$(curl "${curl_args[@]}" "$url")
    
    # Copy response to output file if specified
    if [[ "$output_file" != "/dev/null" ]]; then
        cp "$temp_file" "$output_file"
    fi
    
    # Clean up
    rm -f "$temp_file"
    
    echo "$response_code"
}

# Check if a resource exists via API
# Usage: resource_exists URL
resource_exists() {
    local url="$1"
    local code
    code=$(jfrog_api_call GET "$url")
    [[ "$code" -eq $HTTP_OK ]]
}

# Handle standard API response codes
# Usage: handle_api_response RESPONSE_CODE RESOURCE_NAME OPERATION
handle_api_response() {
    local code="$1"
    local resource_name="$2"
    local operation="${3:-operation}"
    
    case "$code" in
        $HTTP_OK|$HTTP_CREATED)
            log_success "$resource_name $operation successful (HTTP $code)"
            return 0
            ;;
        $HTTP_CONFLICT)
            log_warning "$resource_name already exists (HTTP $code)"
            return 0
            ;;
        $HTTP_BAD_REQUEST)
            log_error "$resource_name $operation failed - bad request (HTTP $code)"
            return 1
            ;;
        $HTTP_UNAUTHORIZED)
            log_error "$resource_name $operation failed - unauthorized (HTTP $code)"
            return 1
            ;;
        $HTTP_NOT_FOUND)
            log_error "$resource_name $operation failed - not found (HTTP $code)"
            return 1
            ;;
        *)
            log_error "$resource_name $operation failed (HTTP $code)"
            return 1
            ;;
    esac
}

# =============================================================================
# JSON PAYLOAD BUILDERS
# =============================================================================

# Build standard project payload
build_project_payload() {
    local project_key="$1"
    local display_name="$2"
    local storage_quota="${3:--1}"
    
    jq -n \
        --arg key "$project_key" \
        --arg name "$display_name" \
        --argjson quota "$storage_quota" \
        '{
            "project_key": $key,
            "display_name": $name,
            "admin_privileges": {
                "manage_members": true,
                "manage_resources": true,
                "index_resources": true
            },
            "storage_quota_bytes": $quota
        }'
}

# Build standard user payload
build_user_payload() {
    local username="$1"
    local email="$2"
    local password="$3"
    local role="${4:-Developer}"
    
    jq -n \
        --arg user "$username" \
        --arg email "$email" \
        --arg pass "$password" \
        --arg role "$role" \
        '{
            "username": $user,
            "email": $email,
            "password": $pass,
            "role": $role
        }'
}

# Build standard application payload
build_application_payload() {
    local project_key="$1"
    local app_key="$2"
    local app_name="$3"
    local description="$4"
    local criticality="${5:-medium}"
    local maturity="${6:-development}"
    local team="${7:-default-team}"
    local owner="${8:-admin@example.com}"
    
    jq -n \
        --arg project "$project_key" \
        --arg key "$app_key" \
        --arg name "$app_name" \
        --arg desc "$description" \
        --arg crit "$criticality" \
        --arg mat "$maturity" \
        --arg team "$team" \
        --arg owner "$owner" \
        '{
            "project_key": $project,
            "application_key": $key,
            "application_name": $name,
            "description": $desc,
            "criticality": $crit,
            "maturity_level": $mat,
            "labels": {
                "team": $team,
                "type": "microservice",
                "architecture": "microservices",
                "environment": "production"
            },
            "user_owners": [$owner],
            "group_owners": []
        }'
}

# Build standard stage payload
build_stage_payload() {
    local project_key="$1"
    local stage_name="$2"
    local category="${3:-promote}"
    
    jq -n \
        --arg project "$project_key" \
        --arg name "$stage_name" \
        --arg cat "$category" \
        '{
            "name": ($project + "-" + $name),
            "scope": "project",
            "project_key": $project,
            "category": $cat
        }'
}

# Build OIDC integration payload
build_oidc_integration_payload() {
    local name="$1"
    local issuer_url="${2:-https://token.actions.githubusercontent.com/}"
    
    jq -n \
        --arg name "$name" \
        --arg issuer "$issuer_url" \
        '{
            "name": $name,
            "issuer_url": $issuer
        }'
}

# Build OIDC identity mapping payload
build_oidc_mapping_payload() {
    local name="$1"
    local provider_name="$2"
    local username="$3"
    local issuer="${4:-https://token.actions.githubusercontent.com}"
    local scope="${5:-applied-permissions/admin}"
    local priority="${6:-1}"
    
    jq -n \
        --arg name "$name" \
        --arg provider "$provider_name" \
        --arg user "$username" \
        --arg iss "$issuer" \
        --arg scope "$scope" \
        --argjson priority "$priority" \
        '{
            "name": $name,
            "provider_name": $provider,
            "claims": {"iss": $iss},
            "token_spec": {
                "username": $user,
                "scope": $scope
            },
            "priority": $priority
        }'
}

# =============================================================================
# INITIALIZATION UTILITIES
# =============================================================================

# Initialize script with common setup
init_script() {
    local script_name="${1:-$(basename "$0")}"
    local description="$2"
    
    setup_error_handling "$script_name"
    
    # Source configuration if not already loaded
    if [[ -z "${PROJECT_KEY:-}" ]]; then
        local script_dir
        script_dir="$(dirname "${BASH_SOURCE[0]}")"
        source "$script_dir/config.sh"
    fi
    
    # Validate environment
    validate_environment
    
    # Display header
    echo ""
    log_step "$description"
    log_config "Project: ${PROJECT_KEY}"
    log_config "JFrog URL: ${JFROG_URL}"
    echo ""
}

# Final status check for any script
finalize_script() {
    local script_name="${1:-$(basename "$0")}"
    
    echo ""
    if [[ "$FAILED" == "true" ]]; then
        log_error "$script_name completed with errors!"
        echo ""
        echo -e "${CYAN}💡 TROUBLESHOOTING TIPS:${NC}"
        echo "   1. Check JFrog platform connectivity"
        echo "   2. Verify admin token permissions"
        echo "   3. Review detailed error messages above"
        echo "   4. Ensure all dependencies are met"
        echo ""
        exit 1
    else
        log_success "$script_name completed successfully!"
        echo ""
    fi
}

# =============================================================================
# BATCH PROCESSING UTILITIES
# =============================================================================

# Process items in batch with progress reporting
process_batch() {
    local batch_name="$1"
    local items_array_name="$2"
    local processor_function="$3"
    
    # Get array reference
    local -n items_ref="$items_array_name"
    local total=${#items_ref[@]}
    local count=0
    
    log_step "Processing $total $batch_name..."
    
    for item in "${items_ref[@]}"; do
        ((count++))
        echo ""
        log_info "[$count/$total] Processing $batch_name..."
        
        if ! "$processor_function" "$item"; then
            log_error "Failed to process item $count of $total"
            FAILED=true
        fi
    done
    
    echo ""
    if [[ "$FAILED" != "true" ]]; then
        log_success "All $total $batch_name processed successfully"
    else
        log_error "Some $batch_name failed to process"
    fi
}

# =============================================================================
# CONFIGURATION VALIDATION
# =============================================================================

# Function to validate required environment variables
validate_environment() {
    local missing_vars=()
    
    if [[ -z "${JFROG_ADMIN_TOKEN}" ]]; then
        missing_vars+=("JFROG_ADMIN_TOKEN")
    fi
    
    if [[ -z "${JFROG_URL}" ]]; then
        missing_vars+=("JFROG_URL")
    fi
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        log_error "Missing required environment variables:"
        printf '   - %s\n' "${missing_vars[@]}"
        echo ""
        echo "Please set these variables and try again."
        exit 1
    fi
}

# Function to display current configuration
show_config() {
    log_config "Current BookVerse Configuration:"
    log_config "Project Key: ${PROJECT_KEY}"
    log_config "Project Name: ${PROJECT_DISPLAY_NAME}"
    log_config "JFrog URL: ${JFROG_URL}"
    log_config "Non-Prod Stages: ${NON_PROD_STAGES[*]}"
    log_config "Production Stage: ${PROD_STAGE}"
}

# Validate JFrog connectivity with detailed reporting
validate_jfrog_connectivity() {
    local url_no_slash="${JFROG_URL%/}"
    
    log_step "Validating JFrog platform connectivity..."
    
    # Test system ping
    local ping_code
    ping_code=$(jfrog_api_call GET "${url_no_slash}/access/api/v1/system/ping")
    if [[ "$ping_code" -eq $HTTP_OK ]]; then
        log_success "System ping successful (HTTP $ping_code)"
    else
        log_error "System ping failed (HTTP $ping_code)"
        return 1
    fi
    
    # Test API access
    local projects_code
    projects_code=$(jfrog_api_call GET "${url_no_slash}/access/api/v1/projects")
    if [[ "$projects_code" -eq $HTTP_OK ]]; then
        log_success "Projects API accessible (HTTP $projects_code)"
    else
        log_error "Projects API failed (HTTP $projects_code)"
        return 1
    fi
    
    log_success "JFrog platform connectivity validated"
    return 0
}

# Export all functions for use in other scripts
export -f setup_error_handling error_handler
export -f log_info log_success log_warning log_error log_step log_config
export -f jfrog_api_call resource_exists handle_api_response
export -f build_project_payload build_user_payload build_application_payload
export -f build_stage_payload build_oidc_integration_payload build_oidc_mapping_payload
export -f init_script finalize_script process_batch 
export -f validate_environment show_config validate_jfrog_connectivity
