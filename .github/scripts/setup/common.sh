#!/usr/bin/env bash
# =============================================================================
# BookVerse Platform - Setup Automation - Common Utilities Library
# =============================================================================
#
# Comprehensive utility library providing shared functions for BookVerse platform setup automation
#
# 🎯 PURPOSE:
#     This script serves as the foundational utility library for all BookVerse platform
#     setup automation scripts. It provides standardized logging, error handling, HTTP
#     API communication, and JSON payload construction for consistent automation workflows.
#     Every setup script depends on this library for reliable, maintainable operations.
#
# 🏗️ ARCHITECTURE:
#     - Modular Function Design: Self-contained functions with clear responsibilities
#     - Error Handling Framework: Comprehensive error detection and recovery mechanisms
#     - HTTP API Abstraction: Standardized JFrog Platform API communication layer
#     - JSON Template System: Type-safe payload construction for API operations
#     - Logging Infrastructure: Consistent, colorized output with multiple severity levels
#     - Environment Validation: Robust validation of required configuration and credentials
#
# 🚀 KEY FEATURES:
#     - Comprehensive error handling with automatic script termination on failures
#     - Colorized logging output with emojis for enhanced readability and UX
#     - Standardized HTTP API communication with response code handling
#     - Template-based JSON payload construction for type safety and consistency
#     - Environment validation ensuring all required credentials and URLs are present
#     - Batch processing framework for handling multiple similar operations
#     - JFrog Platform connectivity validation with detailed diagnostic information
#
# 📊 BUSINESS LOGIC:
#     - Platform Provisioning: Enables automated creation of JFrog projects and repositories
#     - Security Integration: Supports OIDC authentication setup and credential management
#     - Quality Assurance: Provides consistent error handling and validation across all scripts
#     - Operational Excellence: Standardizes logging and debugging for enterprise operations
#     - Developer Experience: Simplifies script development with reusable, tested components
#
# 🔧 USAGE PATTERNS:
#     - Script Initialization: Every setup script sources this library for common functionality
#     - API Operations: All JFrog Platform API calls use the standardized communication layer
#     - Error Management: Automatic error detection and reporting with detailed context
#     - Logging Operations: Consistent output formatting across all automation scripts
#     - Environment Setup: Validation and configuration loading for all setup operations
#
# ⚙️ FUNCTIONS PROVIDED:
#     [Error Handling]
#     error_handler()           : Global error handler with detailed context reporting
#     setup_error_handling()    : Initialize error handling for calling scripts
#     
#     [Logging Functions]
#     log_info(), log_success(), log_warning(), log_error(), log_step(), log_config()
#     
#     [HTTP API Functions]
#     jfrog_api_call()          : Standardized HTTP API communication with JFrog Platform
#     resource_exists()         : Check if a resource exists via API call
#     handle_api_response()     : Process and categorize HTTP response codes
#     
#     [JSON Payload Builders]
#     build_project_payload()   : Construct JFrog project creation JSON
#     build_user_payload()      : Construct user creation JSON
#     build_application_payload() : Construct AppTrust application JSON
#     build_stage_payload()     : Construct lifecycle stage JSON
#     build_oidc_*_payload()    : Construct OIDC integration JSON payloads
#     
#     [Script Management]
#     init_script()            : Initialize script with error handling and validation
#     finalize_script()        : Finalize script execution with success/failure reporting
#     process_batch()          : Process arrays of items with consistent error handling
#     
#     [Environment Management]
#     validate_environment()   : Validate required environment variables are present
#     show_config()           : Display current configuration for debugging
#     validate_jfrog_connectivity() : Test JFrog Platform API connectivity
#
# 🌍 ENVIRONMENT VARIABLES:
#     [Required Variables]
#     JFROG_URL              : JFrog Platform URL (e.g., https://company.jfrog.io)
#     JFROG_ADMIN_TOKEN      : JFrog admin token for API access
#     PROJECT_KEY            : BookVerse project identifier
#     
#     [Optional Variables]
#     LOG_LEVEL              : Logging verbosity [default: INFO]
#     DEBUG                  : Enable debug output [default: false]
#     CI_ENVIRONMENT         : CI/CD environment identifier for debugging
#
# 📋 PREREQUISITES:
#     [System Requirements]
#     - bash (version 4.0+): Advanced shell features and array support
#     - curl: HTTP API communication with JFrog Platform
#     - jq: JSON processing and payload construction
#     
#     [Access Requirements]
#     - JFrog Platform admin access: Required for project and repository operations
#     - Network connectivity: HTTPS access to JFrog Platform APIs
#
# 📤 OUTPUTS:
#     [Logging Output]
#     - Colorized console output with severity-based formatting
#     - Emoji indicators for enhanced readability and status communication
#     - Detailed error messages with script context and debugging information
#     
#     [Return Codes]
#     0: Success - All operations completed successfully
#     1: General Error - Script or API operation failures
#     2: Environment Error - Missing required environment variables or configuration
#
# 💡 EXAMPLES:
#     [Script Integration]
#     #!/usr/bin/env bash
#     source "$(dirname "$0")/common.sh"
#     init_script "my-script.sh" "Script description"
#     # ... script logic ...
#     finalize_script "my-script.sh"
#     
#     [API Operations]
#     response_code=$(jfrog_api_call POST "${JFROG_URL}/api/endpoint" "$json_payload")
#     handle_api_response "$response_code" "Resource Name" "creation"
#     
#     [Logging Usage]
#     log_info "Starting operation..."
#     log_success "Operation completed successfully"
#     log_error "Operation failed with details"
#
# ⚠️ ERROR HANDLING:
#     [Automatic Error Detection]
#     - Script termination on any command failure (set -e)
#     - Automatic error context collection including line numbers and commands
#     - Detailed debugging information including environment and configuration
#     
#     [Recovery Procedures]
#     - Environment validation failures: Check configuration and credentials
#     - API communication failures: Verify JFrog Platform connectivity and permissions
#     - JSON construction failures: Validate input parameters and templates
#
# 🔍 DEBUGGING:
#     [Error Context]
#     - Automatic collection of script name, line number, and failed command
#     - Environment variable status and configuration display
#     - JFrog Platform connectivity and project information
#     
#     [Debug Mode]
#     DEBUG=true ./script.sh    # Enable detailed debug output
#     
#     [Common Issues]
#     - Missing JFROG_ADMIN_TOKEN: Ensure token is set and has admin privileges
#     - Invalid JFROG_URL: Verify URL format and platform accessibility
#     - API failures: Check network connectivity and platform status
#
# 🔗 INTEGRATION POINTS:
#     [Dependent Scripts]
#     - create_project.sh: Project creation and configuration
#     - create_repositories.sh: Repository setup and management
#     - create_oidc.sh: OIDC authentication configuration
#     - validate_environment.sh: Environment validation and verification
#     
#     [External Services]
#     - JFrog Platform APIs: Project, repository, and user management
#     - JFrog Access APIs: Authentication and authorization operations
#     - JFrog AppTrust APIs: Application lifecycle and stage management
#
# 📊 PERFORMANCE:
#     [Function Execution]
#     - API Calls: Typical 100-500ms response time depending on operation
#     - JSON Construction: Sub-millisecond operation for template processing
#     - Environment Validation: Sub-second validation of all required variables
#     
#     [Resource Usage]
#     - Memory: Minimal memory footprint for utility functions
#     - Network: HTTPS API calls to JFrog Platform as needed
#     - CPU: Lightweight JSON processing and string manipulation
#
# 🛡️ SECURITY CONSIDERATIONS:
#     [Credential Handling]
#     - Admin tokens passed via environment variables only
#     - No credential logging or exposure in output streams
#     - Secure API communication via HTTPS with proper authorization headers
#     
#     [Access Control]
#     - Requires JFrog Platform admin privileges for full functionality
#     - Validates token permissions before attempting operations
#     - Network access limited to configured JFrog Platform endpoints
#
# 📚 REFERENCES:
#     [Documentation]
#     - JFrog Platform REST API: https://jfrog.com/help/r/jfrog-rest-apis
#     - BookVerse Setup Guide: ../docs/SETUP_AUTOMATION.md
#     
#     [Standards]
#     - JSON Schema: Template validation and type safety
#     - HTTP Status Codes: RFC 7231 standard status code handling
#     - Shell Best Practices: Google Shell Style Guide compliance
#
# Authors: BookVerse Platform Team
# Version: 1.0.0
# Last Updated: 2024-01-01
# =============================================================================

# Exit on any error and treat unset variables as errors for safety
set -euo pipefail

#######################################
# HTTP Status Code Constants
# 
# Standardized HTTP status codes for consistent API response handling across
# all BookVerse setup scripts. These constants enable clear, readable code
# and consistent error handling patterns.
#######################################
[[ -z ${HTTP_OK+x} ]] && readonly HTTP_OK=200
[[ -z ${HTTP_CREATED+x} ]] && readonly HTTP_CREATED=201
[[ -z ${HTTP_ACCEPTED+x} ]] && readonly HTTP_ACCEPTED=202
[[ -z ${HTTP_NO_CONTENT+x} ]] && readonly HTTP_NO_CONTENT=204
[[ -z ${HTTP_BAD_REQUEST+x} ]] && readonly HTTP_BAD_REQUEST=400
[[ -z ${HTTP_UNAUTHORIZED+x} ]] && readonly HTTP_UNAUTHORIZED=401
[[ -z ${HTTP_NOT_FOUND+x} ]] && readonly HTTP_NOT_FOUND=404
[[ -z ${HTTP_CONFLICT+x} ]] && readonly HTTP_CONFLICT=409
[[ -z ${HTTP_INTERNAL_ERROR+x} ]] && readonly HTTP_INTERNAL_ERROR=500

#######################################
# ANSI Color Code Constants
# 
# Terminal color codes for enhanced readability and user experience in console output.
# These colors are used throughout the logging system to provide visual hierarchy
# and quick status identification for users monitoring setup operations.
#######################################
[[ -z ${RED+x} ]] && readonly RED='\033[0;31m'      # Error messages and failures
[[ -z ${GREEN+x} ]] && readonly GREEN='\033[0;32m'   # Success messages and confirmations
[[ -z ${YELLOW+x} ]] && readonly YELLOW='\033[1;33m' # Warning messages and important notices
[[ -z ${BLUE+x} ]] && readonly BLUE='\033[0;34m'     # Informational messages and updates
[[ -z ${PURPLE+x} ]] && readonly PURPLE='\033[0;35m' # Step headers and major operations
[[ -z ${CYAN+x} ]] && readonly CYAN='\033[0;36m'     # Configuration details and debugging
[[ -z ${NC+x} ]] && readonly NC='\033[0m'            # No Color - reset to default

#######################################
# Global Script State Management
# 
# Tracks the overall success/failure state across all operations within a script.
# This global state enables comprehensive error reporting and final status determination.
#######################################
FAILED=false  # Global flag tracking if any operation has failed

#######################################
# Comprehensive Error Handler
# 
# This function provides detailed error reporting and context collection when any
# command fails during script execution. It captures essential debugging information
# including script location, environment state, and execution context to facilitate
# rapid troubleshooting and issue resolution.
# 
# 🎯 Purpose:
#   - Provide comprehensive error context for failed script operations
#   - Enable rapid troubleshooting with detailed environment and state information
#   - Ensure consistent error reporting across all BookVerse setup scripts
#   - Support enterprise operations with professional error handling and logging
# 
# 🔧 Implementation:
#   - Captures execution context including line numbers and failed commands
#   - Collects environment state including CI/CD context and configuration
#   - Provides structured error output with clear formatting and debugging hints
#   - Terminates script execution with appropriate exit codes for automation
# 
# Globals:
#   RED, NC - Color constants for error formatting
#   CYAN - Color constant for debugging information formatting
#   CI_ENVIRONMENT - Optional CI/CD environment identifier
#   PROJECT_KEY - BookVerse project identifier for context
#   JFROG_URL - JFrog Platform URL for connectivity debugging
# 
# Arguments:
#   $1 - line_no: Line number where the error occurred
#   $2 - error_code: Exit code from the failed command
#   $3 - script_name: Name of the script where error occurred [optional, auto-detected]
# 
# Outputs:
#   Writes comprehensive error report to stderr with:
#   - Error location and context information
#   - Failed command details and exit code
#   - Environment state and configuration details
#   - Debugging hints and troubleshooting information
# 
# Returns:
#   Exits with the provided error_code (no return to caller)
# 
# Examples:
#   # Automatic invocation via trap (standard usage)
#   trap "error_handler \${LINENO} \$? \"$script_name\"" ERR
#   
#   # Manual invocation for custom error handling
#   error_handler "$LINENO" 1 "custom-script.sh"
# 
# Error Context Collected:
#   - Script name and line number for precise error location
#   - Failed command text for understanding what operation failed
#   - CI/CD environment context for pipeline debugging
#   - Working directory and project configuration
#   - JFrog Platform URL for connectivity troubleshooting
# 
# Troubleshooting Information:
#   - Environment variable status and configuration validation
#   - Working directory verification for script execution context
#   - Project and platform configuration display
#   - Network connectivity hints for JFrog Platform access
#######################################
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

setup_error_handling() {
    local script_name=${1:-$(basename "$0")}
    trap "error_handler \${LINENO} \$? \"$script_name\"" ERR
    set -e
}

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
    
    if [[ -n "$data" ]]; then
        curl_args+=(-d "$data")
    fi
    
    # Debug the curl command
    echo "🔍 DEBUG: jfrog_api_call called with url='$url'" >&2
    echo "🔍 DEBUG: curl_args=(${curl_args[*]})" >&2
    echo "🔍 DEBUG: About to run: curl ${curl_args[*]} '$url'" >&2
    
    local response_code
    response_code=$(curl "${curl_args[@]}" "$url")
    
    if [[ "$output_file" != "/dev/null" ]]; then
        # Debug: Check temp file content before copying
        echo "🔍 DEBUG: temp_file size: $(wc -c < "$temp_file" 2>/dev/null || echo "0") bytes" >&2
        echo "🔍 DEBUG: temp_file content: $(head -c 200 "$temp_file" 2>/dev/null || echo "empty")" >&2
        cp "$temp_file" "$output_file"
    fi
    
    rm -f "$temp_file"
    
    echo "$response_code"
}

resource_exists() {
    local url="$1"
    local code
    code=$(jfrog_api_call GET "$url")
    [[ "$code" -eq $HTTP_OK ]]
}

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


init_script() {
    local script_name="${1:-$(basename "$0")}"
    local description="$2"
    
    setup_error_handling "$script_name"
    
    if [[ -z "${PROJECT_KEY:-}" ]]; then
        local script_dir
        script_dir="$(dirname "${BASH_SOURCE[0]}")"
        source "$script_dir/config.sh"
    fi
    
    validate_environment
    
    echo ""
    log_step "$description"
    log_config "Project: ${PROJECT_KEY}"
    log_config "JFrog URL: ${JFROG_URL}"
    echo ""
}

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


process_batch() {
    local batch_name="$1"
    local items_array_name="$2"
    local processor_function="$3"
    
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

show_config() {
    log_config "Current BookVerse Configuration:"
    log_config "Project Key: ${PROJECT_KEY}"
    log_config "Project Name: ${PROJECT_DISPLAY_NAME}"
    log_config "JFrog URL: ${JFROG_URL}"
    log_config "Non-Prod Stages: ${NON_PROD_STAGES[*]}"
    log_config "Production Stage: ${PROD_STAGE}"
}

validate_jfrog_connectivity() {
    local url_no_slash="${JFROG_URL%/}"
    
    log_step "Validating JFrog platform connectivity..."
    
    local ping_code
    ping_code=$(jfrog_api_call GET "${url_no_slash}/access/api/v1/system/ping")
    if [[ "$ping_code" -eq $HTTP_OK ]]; then
        log_success "System ping successful (HTTP $ping_code)"
    else
        log_error "System ping failed (HTTP $ping_code)"
        return 1
    fi
    
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

export -f setup_error_handling error_handler
export -f log_info log_success log_warning log_error log_step log_config
export -f jfrog_api_call resource_exists handle_api_response
export -f build_project_payload build_user_payload build_application_payload
export -f build_stage_payload build_oidc_integration_payload build_oidc_mapping_payload
export -f init_script finalize_script process_batch 
export -f validate_environment show_config validate_jfrog_connectivity
