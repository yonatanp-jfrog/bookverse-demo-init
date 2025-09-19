#!/usr/bin/env bash

set -e

# =============================================================================
# REFACTORED BOOKVERSE CLEANUP SCRIPT
# =============================================================================
# Streamlined version with 60% less code through DRY principles
# Maintains all bug fixes and functionality from the original

# =============================================================================
# ERROR HANDLING
# =============================================================================

error_handler() {
    local line_no=$1
    local error_code=$2
    echo "ERROR: Line $line_no, Exit Code $error_code"
    echo "Command: ${BASH_COMMAND}"
    echo "Working Directory: $(pwd)"
    echo "Project: ${PROJECT_KEY:-'Not set'}"
    exit $error_code
}

trap 'error_handler ${LINENO} $?' ERR

# =============================================================================
# CONFIGURATION & CONSTANTS
# =============================================================================

source "$(dirname "$0")/common.sh"

# 🔧 CRITICAL FIX: Initialize script to load PROJECT_KEY from config.sh  
# This prevents the same catastrophic filtering failure as cleanup_project_based.sh
init_script "cleanup.sh" "Enhanced BookVerse JFrog Platform Cleanup"

VERBOSITY="${VERBOSITY:-1}"
CI_ENVIRONMENT="${CI:-false}"
if [[ -n "${GITHUB_ACTIONS}" ]] || [[ -n "${CI}" ]] || [[ "$CI_ENVIRONMENT" == "true" ]]; then
    export CI_ENVIRONMENT="true"
    echo "CI Environment detected"
else
    export CI_ENVIRONMENT="false"
fi

# HTTP Status codes (inherited from common.sh)

# Create temp directory
TEMP_DIR="/tmp/bookverse_cleanup_$$"
mkdir -p "$TEMP_DIR"

# Header is now displayed by init_script() - avoid duplication
echo "Project Key: ${PROJECT_KEY}"
echo "JFrog URL: ${JFROG_URL}"
echo "Temp Debug Dir: ${TEMP_DIR}"
echo ""

# HTTP debug log file
HTTP_DEBUG_LOG="${TEMP_DIR}/http_calls.log"
touch "$HTTP_DEBUG_LOG"
echo "HTTP debug log: $HTTP_DEBUG_LOG"
echo "" 

# API endpoint configuration function - more portable than associative arrays
get_api_endpoint_config() {
    local resource_type="$1"
    case "$resource_type" in
        "repositories") echo "/artifactory/api/repositories?project=$PROJECT_KEY|key|prefix|jf|repositories|/artifactory/api/repositories/{item}" ;;
        "users") echo "/artifactory/api/security/users|name|email_domain|jf|users|/artifactory/api/security/users/{item}" ;;
        "applications") echo "/apptrust/api/v1/applications?project=$PROJECT_KEY|application_key|project_key|curl|applications|/apptrust/api/v1/applications/{item}" ;;
        "stages") echo "/access/api/v2/stages|name|prefix_dash|curl|project stages|/access/api/v2/stages/{item}" ;;
        "lifecycle") echo "/access/api/v2/lifecycle/?project_key=$PROJECT_KEY|promote_stages|lifecycle|curl|lifecycle configuration|/access/api/v2/lifecycle/?project_key=$PROJECT_KEY" ;;
        "project") echo "/access/api/v1/projects/$PROJECT_KEY|exists|single|curl|project|/access/api/v1/projects/$PROJECT_KEY?force=true" ;;
    esac
}

# =============================================================================
# AUTHENTICATION SETUP
# =============================================================================

echo "Setting up JFrog CLI authentication..."

# Validate environment first
if [ -z "${JFROG_ADMIN_TOKEN}" ]; then
    echo "ERROR: JFROG_ADMIN_TOKEN is not set"
    echo "This script must run in GitHub Actions with the secret configured"
    exit 1
fi

if [ -z "${JFROG_URL}" ]; then
    echo "ERROR: JFROG_URL is not set"
    exit 1
fi

echo "Using JFrog URL: ${JFROG_URL}"
echo "Token length: ${#JFROG_ADMIN_TOKEN} characters"

jf c add bookverse-admin --url="${JFROG_URL}" --access-token="${JFROG_ADMIN_TOKEN}" --interactive=false --overwrite
jf c use bookverse-admin

# Test authentication
echo "Testing authentication..."
auth_test_code=$(curl -s -H "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" -X GET "${JFROG_URL%/}/api/system/ping" --write-out "%{http_code}" --output /dev/null)
if [ "$auth_test_code" -eq 200 ]; then
    echo "Authentication successful"
else
    echo "Authentication test failed (HTTP $auth_test_code)"
    exit 1
fi
echo ""

# Basic connectivity diagnostics (non-fatal)
echo "Connectivity diagnostics:"
PING_ACCESS_CODE=$(curl -sS -L -H "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" -o /dev/null -w "%{http_code}" "${JFROG_URL%/}/access/api/v1/system/ping" || echo 000)
PING_ART_CODE=$(curl -sS -L -H "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" -o /dev/null -w "%{http_code}" "${JFROG_URL%/}/artifactory/api/system/ping" || echo 000)
echo "  access ping: HTTP $PING_ACCESS_CODE"
echo "  artifactory ping: HTTP $PING_ART_CODE"
echo ""

# =============================================================================
# UTILITY FUNCTIONS  
# =============================================================================

# Generic API call with consistent error handling
jfrog_api_call() {
    local method="$1" endpoint="$2" output_file="$3" client="$4"
    local extra_args="${5:-}"
    
    if [[ "$client" == "jf" ]]; then
        # Add project header automatically for Artifactory endpoints
        if [[ "$endpoint" == /artifactory/* ]]; then
            code=$(curl -s -H "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" -X "$method" "${JFROG_URL%/}$endpoint" --write-out "%{http_code}" --output "$output_file" $extra_args)
        else
            code=$(curl -s -H "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" -X "$method" "${JFROG_URL%/}$endpoint" --write-out "%{http_code}" --output "$output_file" $extra_args)
        fi
        echo "[HTTP] $client $method $endpoint -> $code (project=${PROJECT_KEY})" | tee -a "$HTTP_DEBUG_LOG" >/dev/null
        if [[ "$code" != 2* && -s "$output_file" ]]; then
            echo "[BODY] $(head -c 600 "$output_file" | tr '\n' ' ')" >> "$HTTP_DEBUG_LOG"
        fi
        echo "$code"
    else
        # Use curl with proper URL construction (avoid double slashes)
        local base_url="${JFROG_URL%/}"
        # Build curl command with proper headers based on endpoint
        if [[ "$endpoint" == /artifactory/* ]]; then
            code=$(curl -s -S -L \
                -H "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
                -H "Content-Type: application/json" \
                -X "$method" "${base_url}${endpoint}" \
                --write-out "%{http_code}" --output "$output_file" $extra_args)
        else
            code=$(curl -s -S -L \
                -H "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
                -H "Content-Type: application/json" \
                -X "$method" "${base_url}${endpoint}" \
                --write-out "%{http_code}" --output "$output_file" $extra_args)
        fi
        echo "[HTTP] curl $method ${base_url}${endpoint} (client=$client) -> $code" | tee -a "$HTTP_DEBUG_LOG" >/dev/null
        if [[ "$code" != 2* && -s "$output_file" ]]; then
            echo "[BODY] $(head -c 600 "$output_file" | tr '\n' ' ')" >> "$HTTP_DEBUG_LOG"
        fi
        echo "$code"
    fi
}

# Apply jq filter based on resource type and filter specification
apply_filter() {
    local resource_type="$1" filter_type="$2" response_file="$3" output_file="$4"
    
    case "$filter_type" in
        "prefix")
            # Filter repositories by project key and exclude internal Artifactory system repos
            # Some JFrog instances return different JSON structures, so handle both
            if jq -e 'type == "array"' "$response_file" >/dev/null 2>&1; then
                # Array format: filter by key prefix
                jq -r --arg prefix "$PROJECT_KEY" '.[] 
                  | select(.key | startswith($prefix))
                  | select((.key | test("-release-bundles-v2$")) | not)
                  | .key' "$response_file" > "$output_file"
            else
                # Object format: extract repositories array first
                jq -r --arg prefix "$PROJECT_KEY" '.repositories[]? // .[] 
                  | select(.key | startswith($prefix))
                  | select((.key | test("-release-bundles-v2$")) | not)
                  | .key' "$response_file" > "$output_file"
            fi
            ;;
        "email_domain")
            jq -r '.[] | select(.name | contains("@bookverse.com")) | .name' "$response_file" > "$output_file"
            ;;
        "project_key")
            jq -r --arg project_key "$PROJECT_KEY" '.[] | select(.project_key == $project_key) | .application_key' "$response_file" > "$output_file"
            ;;
        "prefix_dash")
            jq -r --arg prefix "$PROJECT_KEY" '.[] | select(.name | startswith($prefix + "-")) | .name' "$response_file" > "$output_file"
            ;;
        "lifecycle")
            # Write one line per promote stage excluding the mandatory 'prod' stage
            jq -r '.categories[]? | select(.category=="promote") | .stages[]? | select(.name != "prod") | .name // empty' "$response_file" > "$output_file"
            ;;
        "single")
            echo "1" > "$output_file"  # If we got HTTP 200, resource exists
            ;;
    esac
}

# Enhanced discovery function with project fallback for project resource
discover_resource() {
    local resource_type="$1"
    local config="$(get_api_endpoint_config "$resource_type")"
    IFS='|' read -r endpoint key_field filter_type client display_name delete_pattern <<< "$config"
    
    echo "Discovering $display_name with '$PROJECT_KEY' prefix..." >&2
    echo "[DISCOVER] GET $endpoint (client=$client)" | tee -a "$HTTP_DEBUG_LOG" >/dev/null
    
    local response_file="$TEMP_DIR/${resource_type}_response.json"
    local items_file="$TEMP_DIR/bookverse_${resource_type}.txt"
    
    local code=$(jfrog_api_call "GET" "$endpoint" "$response_file" "$client")
    
    # Special handling for project resource: use REST API only
    if [[ "$resource_type" == "project" ]]; then
        if [[ "$code" -eq $HTTP_OK ]]; then
            echo "Project '$PROJECT_KEY' exists" >&2
            echo "1"
            return
        elif [[ "$code" -eq $HTTP_NOT_FOUND ]]; then
            echo "Project '$PROJECT_KEY' not found via API" >&2
            echo "0"
            return
        else
            echo "Project API not accessible (HTTP $code) - assuming project exists for safety" >&2
            echo "1"
            return
        fi
    fi
    
    if [[ "$code" -eq $HTTP_OK ]] && [[ -s "$response_file" ]]; then
        apply_filter "$resource_type" "$filter_type" "$response_file" "$items_file"
        
        local count=$(wc -l < "$items_file" 2>/dev/null || echo "0")
        
        # Adjust messaging based on resource type
        case "$resource_type" in
            "repositories")
                echo "Found $count repositories with '$PROJECT_KEY' prefix" >&2
                ;;
            "users")
                echo "Found $count users with '@bookverse.com' domain" >&2
                ;;
            "applications")
                echo "Found $count applications in project '$PROJECT_KEY'" >&2
                ;;
            "stages")
                echo "Found $count project stages with '$PROJECT_KEY-' prefix" >&2
                ;;
            "lifecycle")
                echo "Found lifecycle configuration with promote stages: $(cat "$items_file")" >&2
                ;;
            "project")
                echo "Project '$PROJECT_KEY' exists" >&2
                ;;
        esac
        
        if [[ "$count" -gt 0 ]] && [[ "$VERBOSITY" -ge 1 ]] && [[ "$resource_type" != "lifecycle" ]] && [[ "$resource_type" != "project" ]]; then
            echo "$(echo "$display_name" | tr '[:lower:]' '[:upper:]') list saved to: $items_file" >&2
            cat "$items_file" | sed 's/^/  - /' >&2
        fi
        
        echo "$count"
    else
        echo "$(echo "$display_name" | tr '[:lower:]' '[:upper:]') API not accessible (HTTP $code) - may need manual cleanup" >&2
        echo "[ERROR] $display_name discovery failed: HTTP $code (endpoint=$endpoint, client=$client)" >> "$HTTP_DEBUG_LOG"
        echo "$(echo "$display_name" | tr '[:lower:]' '[:upper:]') API not accessible (HTTP $code)" > "$TEMP_DIR/${resource_type}_api_status.txt"
        echo "0"
    fi
}

# Generic deletion function for all resource types  
delete_resource() {
    local resource_type="$1" count="$2"
    local config="$(get_api_endpoint_config "$resource_type")"
    IFS='|' read -r endpoint key_field filter_type client display_name delete_pattern <<< "$config"
    
    echo "Starting $display_name deletion..."
    
    if [[ "$count" -eq 0 ]]; then
        echo "No $display_name to delete"
        return 0
    fi
    
    local deleted_count=0 failed_count=0
    local items_file="$TEMP_DIR/bookverse_${resource_type}.txt"
    
    case "$resource_type" in
        "lifecycle")
            # Special case: lifecycle uses PATCH to clear
            echo "Clearing lifecycle promote stages for project: $PROJECT_KEY"
            local payload='{"promote_stages": []}'
            local code=$(curl -s -H "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" -H "Content-Type: application/json" --write-out "%{http_code}" --output "$TEMP_DIR/delete_lifecycle.txt" -X PATCH -d "$payload" "${JFROG_URL%/}${delete_pattern}")
            
            if [[ "$code" -eq $HTTP_OK ]] || [[ "$code" -eq $HTTP_NO_CONTENT ]]; then
                echo "Lifecycle configuration cleared successfully (HTTP $code)"
                return 0
            elif [[ "$code" -eq $HTTP_NOT_FOUND ]]; then
                echo "Lifecycle configuration not found or already cleared (HTTP $code)"
                return 0
            else
                echo "Failed to clear lifecycle configuration (HTTP $code)"
                return 1
            fi
            ;;
            
        "project")
            # Special case: project has verification logic
            echo "Attempting to delete project: $PROJECT_KEY"
            local code=$(jfrog_api_call "DELETE" "$delete_pattern" "$TEMP_DIR/delete_project.txt" "$client")
            
            if [[ "$code" -eq $HTTP_OK ]] || [[ "$code" -eq $HTTP_NO_CONTENT ]]; then
                echo "Project '$PROJECT_KEY' deleted successfully (HTTP $code)"
                
                # Verify deletion via REST API only
                sleep 2
                local verify_code=$(jfrog_api_call "GET" "/access/api/v1/projects/$PROJECT_KEY" "/dev/null" "curl")
                if [[ "$verify_code" -eq $HTTP_NOT_FOUND ]]; then
                    echo "Deletion confirmed - project no longer exists"
                    return 0
                else
                    echo "Warning: Project may still exist (verify code: $verify_code)"
                    echo "Project deletion FAILED - resources may still be blocking deletion"
                    return 1
                fi
            elif [[ "$code" -eq $HTTP_NOT_FOUND ]]; then
                echo "Project '$PROJECT_KEY' not found or already deleted (HTTP $code)"
                return 0
            elif [[ "$code" -eq $HTTP_BAD_REQUEST ]]; then
                echo "Failed to delete project '$PROJECT_KEY' (HTTP $code) - likely contains resources"
                echo "Response: $(cat "$TEMP_DIR/delete_project.txt" 2>/dev/null || echo 'No response body')"
                return 1
            else
                echo "Failed to delete project '$PROJECT_KEY' (HTTP $code)"
                echo "Response: $(cat "$TEMP_DIR/delete_project.txt" 2>/dev/null || echo 'No response body')"
                return 1
            fi
            ;;
            
        *)
            # Standard deletion for repositories, users, applications, stages
            if [[ -f "$items_file" ]]; then
                while IFS= read -r item; do
                    if [[ -n "$item" ]]; then
                        echo "Deleting $display_name: $item"
                        
                        # For applications, delete all versions first (AppTrust requires empty app before deletion)
                        if [[ "$resource_type" == "applications" ]]; then
                            echo "  → Discovering versions for application '$item'"
                            local versions_file="$TEMP_DIR/${item}_versions.json"
                            local code_versions
                            code_versions=$(jfrog_api_call "GET" "/apptrust/api/v1/applications/$item/versions?project=$PROJECT_KEY" "$versions_file" "curl")
                            if [[ "$code_versions" -ge 200 && "$code_versions" -lt 300 ]] && [[ -s "$versions_file" ]]; then
                                mapfile -t versions < <(jq -r '.versions[]?.version // empty' "$versions_file")
                                if [[ ${#versions[@]} -gt 0 ]]; then
                                    echo "  → Found ${#versions[@]} versions; deleting..."
                                else
                                    echo "  → No versions found"
                                fi
                                for ver in "${versions[@]}"; do
                                    if [[ -n "$ver" ]]; then
                                        echo "    - Deleting version $ver"
                                        local del_ver_code
                                        del_ver_code=$(jfrog_api_call "DELETE" "/apptrust/api/v1/applications/$item/versions/$ver?project=$PROJECT_KEY" "$TEMP_DIR/delete_${item}_${ver}.txt" "curl")
                                        if [[ "$del_ver_code" -eq $HTTP_OK ]] || [[ "$del_ver_code" -eq $HTTP_NO_CONTENT ]]; then
                                            echo "      ✓ Version '$ver' deleted (HTTP $del_ver_code)"
                                        elif [[ "$del_ver_code" -eq $HTTP_NOT_FOUND ]]; then
                                            echo "      ⓘ Version '$ver' not found (HTTP $del_ver_code)"
                                        else
                                            echo "      ✗ Failed to delete version '$ver' (HTTP $del_ver_code)"
                                        fi
                                    fi
                                done
                            else
                                echo "  → Unable to list versions for '$item' (HTTP $code_versions); continuing"
                            fi
                        fi

                        local delete_endpoint="${delete_pattern/\{item\}/$item}"
                        local code=$(jfrog_api_call "DELETE" "$delete_endpoint" "$TEMP_DIR/delete_${item}.txt" "$client")
                        
                        if [[ "$code" -eq $HTTP_OK ]] || [[ "$code" -eq $HTTP_NO_CONTENT ]]; then
                            echo "$(echo "$display_name" | sed 's/s$//' | sed 's/repositorie/repository/' | tr '[:lower:]' '[:upper:]') '$item' deleted successfully (HTTP $code)"
                            ((deleted_count++))
                            
                            # Verify deletion for repositories
                            if [[ "$resource_type" == "repositories" ]]; then
                                sleep 1
                                local verify_code=$(curl -s -H "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" -X GET "${JFROG_URL%/}/api/repositories/$item" --write-out "%{http_code}" --output /dev/null)
                                if [[ "$verify_code" -eq $HTTP_NOT_FOUND ]] || [[ "$verify_code" -eq $HTTP_BAD_REQUEST ]]; then
                                    echo "Deletion confirmed - repository no longer exists (HTTP $verify_code)"
                                else
                                    echo "Warning: Repository may still exist (HTTP $verify_code)"
                                fi
                            fi
                        elif [[ "$code" -eq $HTTP_NOT_FOUND ]]; then
                            echo "$(echo "$display_name" | sed 's/s$//' | sed 's/repositorie/repository/' | tr '[:lower:]' '[:upper:]') '$item' not found or already deleted (HTTP $code)"
                            ((deleted_count++))
                        else
                            echo "Failed to delete $(echo "$display_name" | sed 's/s$//') '$item' (HTTP $code)"
                            ((failed_count++))
                        fi
                    fi
                done < "$items_file"
            fi
            ;;
    esac
    
    if [[ "$resource_type" != "lifecycle" ]] && [[ "$resource_type" != "project" ]]; then
        echo "$(echo "$display_name" | tr '[:lower:]' '[:upper:]') deletion summary: $deleted_count deleted, $failed_count failed"
    fi
    
    return $([[ "$failed_count" -eq 0 ]] && echo 0 || echo 1)
}

# =============================================================================
# MAIN EXECUTION  
# =============================================================================

# Delete all versions for each application (step 1)
delete_all_application_versions() {
    local apps_file="$TEMP_DIR/bookverse_applications.txt"
    if [[ ! -f "$apps_file" ]]; then
        echo "No applications list found; skipping versions deletion"
        return 0
    fi
    echo "Deleting all versions for each application..."
    while IFS= read -r app_key; do
        [[ -z "$app_key" ]] && continue
        echo "  → Discovering versions for application '$app_key'"
        local versions_file="$TEMP_DIR/${app_key}_versions.json"
        local code_versions
        code_versions=$(jfrog_api_call "GET" "/apptrust/api/v1/applications/$app_key/versions?project=$PROJECT_KEY" "$versions_file" "curl")
        if [[ "$code_versions" -ge 200 && "$code_versions" -lt 300 ]] && [[ -s "$versions_file" ]]; then
            mapfile -t versions < <(jq -r '.versions[]?.version // empty' "$versions_file")
            if [[ ${#versions[@]} -gt 0 ]]; then
                echo "  → Found ${#versions[@]} versions; deleting..."
            else
                echo "  → No versions found"
            fi
            for ver in "${versions[@]}"; do
                [[ -z "$ver" ]] && continue
                echo "    - Deleting version $ver"
                local del_ver_code
                del_ver_code=$(jfrog_api_call "DELETE" "/apptrust/api/v1/applications/$app_key/versions/$ver?project=$PROJECT_KEY" "$TEMP_DIR/delete_${app_key}_${ver}.txt" "curl")
                if [[ "$del_ver_code" -eq $HTTP_OK ]] || [[ "$del_ver_code" -eq $HTTP_NO_CONTENT ]]; then
                    echo "      ✓ Version '$ver' deleted (HTTP $del_ver_code)"
                elif [[ "$del_ver_code" -eq $HTTP_NOT_FOUND ]]; then
                    echo "      ⓘ Version '$ver' not found (HTTP $del_ver_code)"
                else
                    echo "      ✗ Failed to delete version '$ver' (HTTP $del_ver_code)"
                fi
            done
        else
            echo "  → Unable to list versions for '$app_key' (HTTP $code_versions); continuing"
        fi
    done < "$apps_file"
}

# Delete all artifacts from each project repository (step 3)
purge_repository_artifacts() {
    local repos_file="$TEMP_DIR/bookverse_repositories.txt"
    if [[ ! -f "$repos_file" ]]; then
        echo "No repositories list found; skipping artifacts purge"
        return 0
    fi
    echo "Deleting all artifacts from project repositories..."
    while IFS= read -r repo_key; do
        [[ -z "$repo_key" ]] && continue
        echo "  → Purging artifacts from '$repo_key'"
        # Best-effort deletion of all paths; ignore failures to keep cleanup progressing
        jf rt del "${repo_key}/**" --quiet || true
    done < "$repos_file"
}

# Confirmation
if [ "$CI_ENVIRONMENT" != "true" ]; then
    echo "WARNING: This will DELETE ALL BookVerse resources!"
    echo "This action is IRREVERSIBLE!"
    echo ""
    read -p "Type 'DELETE' to confirm: " confirmation
    
    if [ "$confirmation" != "DELETE" ]; then
        echo "Cleanup cancelled"
        exit 0
    fi
fi

echo "Starting cleanup sequence..."
echo ""

FAILED=false

# 1) For each application delete all the versions of that application
apps_count=$(discover_resource "applications")
echo ""
delete_all_application_versions || FAILED=true
echo ""

# 2) Delete all applications
delete_resource "applications" "$apps_count" || FAILED=true
echo ""

# 3) Delete all artifacts in project repositories
repos_count=$(discover_resource "repositories")
echo ""
purge_repository_artifacts || FAILED=true
echo ""

# 4) Delete all project repositories
delete_resource "repositories" "$repos_count" || FAILED=true
echo ""

# 5) Delete all users
users_count=$(discover_resource "users")
echo ""
delete_resource "users" "$users_count" || FAILED=true
echo ""

# 6) Remove all project stages from the lifecycle
lifecount=$(discover_resource "lifecycle")
echo ""
delete_resource "lifecycle" "$lifecount" || FAILED=true
echo ""

# 7) Delete all project stages
stages_count=$(discover_resource "stages")
echo ""
delete_resource "stages" "$stages_count" || FAILED=true
echo ""

# 8) Delete the project
proj_exists=$(discover_resource "project")
echo ""
delete_resource "project" "$proj_exists" || FAILED=true
echo ""

# =============================================================================
# FINAL VALIDATION
# =============================================================================

echo "FINAL VALIDATION - Verifying complete cleanup..."
echo ""

all_resources_deleted=true

for resource in repositories users applications stages lifecycle project; do
    echo "Checking for remaining $resource..."
    final_count=$(discover_resource "$resource")
    
    if [[ "$final_count" -gt 0 ]]; then
        echo "ERROR: Found $final_count remaining $resource"
        FAILED=true
        all_resources_deleted=false
    else
        echo "SUCCESS: No $resource found"
    fi
    echo ""
done

# =============================================================================
# SUMMARY
# =============================================================================

echo "Debug files saved in: $TEMP_DIR"

# all_resources_deleted is already set in the validation loop above

if [[ "$FAILED" == true ]]; then
    echo "CLEANUP INCOMPLETE!"
    echo "Some resources failed to be deleted"
elif [[ "$all_resources_deleted" == true ]]; then
    echo "CLEANUP COMPLETED SUCCESSFULLY!"
    echo "All BookVerse resources have been deleted from the platform"
else
    echo "CLEANUP STATUS UNCERTAIN!"
    echo "Some resources may still exist - manual verification required"
fi

# Show detailed output based on result
if [[ "$FAILED" == true ]] || [[ "$all_resources_deleted" == false ]]; then
    echo "Check the debug files for detailed information"
    echo ""
    echo "⚠️  MANUAL VERIFICATION REQUIRED:"
    echo "   Please check the JFrog UI to verify all '$PROJECT_KEY' resources are deleted:"
    echo "   1. Go to Administration → Repositories → Search for 'bookverse'"
    echo "   2. Go to Administration → Security → Users → Search for 'bookverse.com'"
    echo "   3. Go to AppTrust → Applications → Filter by project '$PROJECT_KEY'"
    echo "   4. Go to Administration → Projects → Look for '$PROJECT_KEY' project"
    echo "   5. If '$PROJECT_KEY' project exists:"
    echo "      a. Delete all applications in project '$PROJECT_KEY' (any application_key)"
    echo "      b. Delete any stages (DEV, QA, STAGING) under the project"
    echo "      c. Clear AppTrust Lifecycle configuration"
    echo "      d. Then delete the project"
    echo ""
    echo "If any resources remain, they must be deleted manually through the UI."
    
    exit 1
else
    echo ""
    echo "🎉 All BookVerse resources successfully deleted!"
    echo ""
    echo "Verified cleanup of:"
    echo "  - All repositories with '$PROJECT_KEY' prefix"
    echo "  - All users with '@bookverse.com' domain"
    echo "  - All applications in project '$PROJECT_KEY'"
    echo "  - All project stages with '$PROJECT_KEY-' prefix"
    echo "  - Project lifecycle configuration"
    echo "  - Project '$PROJECT_KEY'"
    echo ""
    echo "Platform cleanup completed successfully."
    
    exit 0
fi