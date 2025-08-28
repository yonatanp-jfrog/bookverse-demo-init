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

source "$(dirname "$0")/config.sh"
validate_environment

VERBOSITY="${VERBOSITY:-1}"
CI_ENVIRONMENT="${CI:-false}"
if [[ -n "${GITHUB_ACTIONS}" ]] || [[ -n "${CI}" ]] || [[ "$CI_ENVIRONMENT" == "true" ]]; then
    export CI_ENVIRONMENT="true"
    echo "CI Environment detected"
else
    export CI_ENVIRONMENT="false"
fi

# HTTP Status codes
readonly HTTP_OK=200
readonly HTTP_CREATED=201
readonly HTTP_NO_CONTENT=204
readonly HTTP_BAD_REQUEST=400
readonly HTTP_NOT_FOUND=404

# Create temp directory
TEMP_DIR="/tmp/bookverse_cleanup_$$"
mkdir -p "$TEMP_DIR"

echo "Enhanced BookVerse JFrog Platform Cleanup"
echo "========================================"
echo "Project Key: ${PROJECT_KEY}"
echo "JFrog URL: ${JFROG_URL}"
echo "Temp Debug Dir: ${TEMP_DIR}"
echo ""

# Resource configuration function - more portable than associative arrays
get_resource_config() {
    local resource_type="$1"
    case "$resource_type" in
        "repositories") echo "api/repositories|key|prefix|jf|repositories|api/repositories/{item}" ;;
        "users") echo "api/security/users|name|email_domain|jf|users|api/security/users/{item}" ;;
        "applications") echo "/apptrust/api/v1/applications?project=$PROJECT_KEY|application_key|project_key|curl|applications|/apptrust/api/v1/applications/{item}" ;;
        "stages") echo "/access/api/v2/stages|name|prefix_dash|curl|project stages|/access/api/v2/stages/{item}" ;;
        "lifecycle") echo "/access/api/v2/lifecycle/?project_key=$PROJECT_KEY|promote_stages|lifecycle|curl|lifecycle configuration|/access/api/v2/lifecycle/?project_key=$PROJECT_KEY" ;;
        "project") echo "/access/api/v1/projects/$PROJECT_KEY|exists|single|curl|project|/access/api/v1/projects/$PROJECT_KEY" ;;
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
auth_test_code=$(jf rt curl -X GET "/api/system/ping" --write-out "%{http_code}" --output /dev/null --silent)
if [ "$auth_test_code" -eq 200 ]; then
    echo "Authentication successful"
else
    echo "Authentication test failed (HTTP $auth_test_code)"
    exit 1
fi
echo ""

# =============================================================================
# UTILITY FUNCTIONS  
# =============================================================================

# Generic API call with consistent error handling
make_api_call() {
    local method="$1" endpoint="$2" output_file="$3" client="$4"
    local extra_args="${5:-}"
    
    if [[ "$client" == "jf" ]]; then
        jf rt curl -X "$method" "$endpoint" --write-out "%{http_code}" --output "$output_file" --silent $extra_args
    else
        # Use curl with proper URL construction (avoid double slashes)
        curl -s --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" -X "$method" "${JFROG_URL}${endpoint}" --write-out "%{http_code}" --output "$output_file" $extra_args
    fi
}

# Apply jq filter based on resource type and filter specification
apply_filter() {
    local resource_type="$1" filter_type="$2" response_file="$3" output_file="$4"
    
    case "$filter_type" in
        "prefix")
            # Exclude internal Artifactory system repos (e.g., *-release-bundles-v2) which cannot be deleted
            jq -r --arg prefix "$PROJECT_KEY" '.[] 
              | select(.key | startswith($prefix))
              | select((.key | test("-release-bundles-v2$")) | not)
              | .key' "$response_file" > "$output_file"
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
            if jq -e '.categories[] | select(.category=="promote") | .stages | length > 0' "$response_file" >/dev/null 2>&1; then
                echo "1" > "$output_file"
            else
                echo "0" > "$output_file"
            fi
            ;;
        "single")
            echo "1" > "$output_file"  # If we got HTTP 200, resource exists
            ;;
    esac
}

# Enhanced discovery function with project fallback for project resource
discover_resource() {
    local resource_type="$1"
    local config="$(get_resource_config "$resource_type")"
    IFS='|' read -r endpoint key_field filter_type client display_name delete_pattern <<< "$config"
    
    echo "Discovering $display_name with '$PROJECT_KEY' prefix..." >&2
    
    local response_file="$TEMP_DIR/${resource_type}_response.json"
    local items_file="$TEMP_DIR/bookverse_${resource_type}.txt"
    
    local code=$(make_api_call "GET" "$endpoint" "$response_file" "$client")
    
    # Special handling for project resource (try both APIs)
    if [[ "$resource_type" == "project" ]] && [[ "$code" -eq $HTTP_NOT_FOUND ]]; then
        echo "Project '$PROJECT_KEY' not found via jf rt curl" >&2
        # Try alternative API path with curl
        local code2=$(make_api_call "GET" "$endpoint" "$TEMP_DIR/project_response_alt.txt" "curl")
        
        if [[ "$code2" -eq $HTTP_OK ]]; then
            echo "Project '$PROJECT_KEY' found via direct API" >&2
            echo "1"
            return
        elif [[ "$code2" -eq $HTTP_NOT_FOUND ]]; then
            echo "Project '$PROJECT_KEY' not found via any API method" >&2
            echo "0"
            return
        else
            echo "Project API not accessible (HTTP $code2) - project may exist but not accessible" >&2
            echo "1"  # Assume exists if API not accessible
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
        echo "$(echo "$display_name" | tr '[:lower:]' '[:upper:]') API not accessible (HTTP $code)" > "$TEMP_DIR/${resource_type}_api_status.txt"
        echo "0"
    fi
}

# Generic deletion function for all resource types  
delete_resource() {
    local resource_type="$1" count="$2"
    local config="$(get_resource_config "$resource_type")"
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
            local code=$(curl -s --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" --header "Content-Type: application/json" --write-out "%{http_code}" --output "$TEMP_DIR/delete_lifecycle.txt" -X PATCH -d "$payload" "${JFROG_URL}${delete_pattern}")
            
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
            local code=$(make_api_call "DELETE" "$delete_pattern" "$TEMP_DIR/delete_project.txt" "$client")
            
            if [[ "$code" -eq $HTTP_OK ]] || [[ "$code" -eq $HTTP_NO_CONTENT ]]; then
                echo "Project '$PROJECT_KEY' deleted successfully (HTTP $code)"
                
                # Verify deletion with both methods
                sleep 2
                local verify_code1=$(jf rt curl -X GET "/access/api/v1/projects/$PROJECT_KEY" --write-out "%{http_code}" --output /dev/null --silent)
                local verify_code2=$(make_api_call "GET" "/access/api/v1/projects/$PROJECT_KEY" "/dev/null" "curl")
                
                if [[ "$verify_code1" -eq $HTTP_NOT_FOUND ]] && [[ "$verify_code2" -eq $HTTP_NOT_FOUND ]]; then
                    echo "Deletion confirmed - project no longer exists"
                    return 0
                else
                    echo "Warning: Project may still exist (verify codes: $verify_code1, $verify_code2)"
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
                            code_versions=$(make_api_call "GET" "/apptrust/api/v1/applications/$item/versions?project=$PROJECT_KEY" "$versions_file" "curl")
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
                                        del_ver_code=$(make_api_call "DELETE" "/apptrust/api/v1/applications/$item/versions/$ver?project=$PROJECT_KEY" "$TEMP_DIR/delete_${item}_${ver}.txt" "curl")
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
                        local code=$(make_api_call "DELETE" "$delete_endpoint" "$TEMP_DIR/delete_${item}.txt" "$client")
                        
                        if [[ "$code" -eq $HTTP_OK ]] || [[ "$code" -eq $HTTP_NO_CONTENT ]]; then
                            echo "$(echo "$display_name" | sed 's/s$//' | sed 's/repositorie/repository/' | tr '[:lower:]' '[:upper:]') '$item' deleted successfully (HTTP $code)"
                            ((deleted_count++))
                            
                            # Verify deletion for repositories
                            if [[ "$resource_type" == "repositories" ]]; then
                                sleep 1
                                local verify_code=$(jf rt curl -X GET "/api/repositories/$item" --write-out "%{http_code}" --output /dev/null --silent)
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

# Define resource processing order (dependencies matter)
RESOURCE_ORDER=("repositories" "users" "applications" "stages" "lifecycle" "project")
FAILED=false

# Discovery and deletion loop  
for resource in "${RESOURCE_ORDER[@]}"; do
    count=$(discover_resource "$resource")
    echo ""
    delete_resource "$resource" "$count" || FAILED=true
    echo ""
done

# =============================================================================
# FINAL VALIDATION
# =============================================================================

echo "FINAL VALIDATION - Verifying complete cleanup..."
echo ""

all_resources_deleted=true

for resource in "${RESOURCE_ORDER[@]}"; do
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