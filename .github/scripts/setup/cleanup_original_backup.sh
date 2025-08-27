#!/usr/bin/env bash

set -e

# =============================================================================
# ENHANCED BOOKVERSE CLEANUP SCRIPT
# =============================================================================
# This script uses simple, single-line commands to avoid terminal hangs
# and provides comprehensive debugging for reliable resource cleanup.

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
# CONFIGURATION
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

# Create temp directory for debugging
TEMP_DIR="/tmp/bookverse_cleanup_$$"
mkdir -p "$TEMP_DIR"

echo "Enhanced BookVerse JFrog Platform Cleanup"
echo "========================================"
echo "Project Key: ${PROJECT_KEY}"
echo "JFrog URL: ${JFROG_URL}"
echo "Temp Debug Dir: ${TEMP_DIR}"
echo ""

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
# DISCOVERY FUNCTIONS
# =============================================================================

discover_repositories() {
    echo "Discovering repositories with '$PROJECT_KEY' prefix..." >&2
    
    # Save raw API response for debugging
    jf rt curl -X GET "/api/repositories" --silent > "$TEMP_DIR/all_repos.json" 2>&1
    
    if [ $? -eq 0 ] && [ -s "$TEMP_DIR/all_repos.json" ]; then
        # Extract repository names with bookverse prefix
        jq -r --arg prefix "$PROJECT_KEY" '.[] | select(.key | startswith($prefix)) | .key' "$TEMP_DIR/all_repos.json" > "$TEMP_DIR/bookverse_repos.txt" 2>/dev/null || true
        
        # Count and display results
        local count=$(wc -l < "$TEMP_DIR/bookverse_repos.txt" 2>/dev/null || echo "0")
        echo "Found $count repositories with '$PROJECT_KEY' prefix" >&2
        
        if [ "$count" -gt 0 ]; then
            echo "Repository list saved to: $TEMP_DIR/bookverse_repos.txt" >&2
            if [ "$VERBOSITY" -ge 1 ]; then
                cat "$TEMP_DIR/bookverse_repos.txt" | sed 's/^/  - /' >&2
            fi
        fi
        
        echo "$count"
    else
        echo "Failed to retrieve repositories" >&2
        echo "0"
    fi
}

discover_users() {
    echo "Discovering users with '@bookverse.com' domain..." >&2
    
    # Save raw API response for debugging
    jf rt curl -X GET "/api/security/users" --silent > "$TEMP_DIR/all_users.json" 2>&1
    
    if [ $? -eq 0 ] && [ -s "$TEMP_DIR/all_users.json" ]; then
        # Extract users with bookverse domain
        jq -r '.[] | select(.name | contains("@bookverse.com")) | .name' "$TEMP_DIR/all_users.json" > "$TEMP_DIR/bookverse_users.txt" 2>/dev/null || true
        
        # Count and display results
        local count=$(wc -l < "$TEMP_DIR/bookverse_users.txt" 2>/dev/null || echo "0")
        echo "Found $count users with '@bookverse.com' domain" >&2
        
        if [ "$count" -gt 0 ]; then
            echo "User list saved to: $TEMP_DIR/bookverse_users.txt" >&2
            if [ "$VERBOSITY" -ge 1 ]; then
                cat "$TEMP_DIR/bookverse_users.txt" | sed 's/^/  - /' >&2
            fi
        fi
        
        echo "$count"
    else
        echo "Failed to retrieve users" >&2
        echo "0"
    fi
}

discover_stages() {
    echo "Discovering project stages with '$PROJECT_KEY' prefix..." >&2
    
    # Try stages API (may not be accessible)
    local code=$(curl -s --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" --write-out "%{http_code}" --output "$TEMP_DIR/all_stages.json" -X GET "${JFROG_URL}access/api/v2/stages")
    
    if [ "$code" -eq 200 ] && [ -s "$TEMP_DIR/all_stages.json" ]; then
        # Extract stage names with bookverse prefix
        jq -r --arg prefix "$PROJECT_KEY" '.[] | select(.name | startswith($prefix + "-")) | .name' "$TEMP_DIR/all_stages.json" > "$TEMP_DIR/bookverse_stages.txt" 2>/dev/null || true
        
        local count=$(wc -l < "$TEMP_DIR/bookverse_stages.txt" 2>/dev/null || echo "0")
        echo "Found $count project stages with '$PROJECT_KEY-' prefix" >&2
        
        if [ "$count" -gt 0 ]; then
            echo "Stage list saved to: $TEMP_DIR/bookverse_stages.txt" >&2
if [ "$VERBOSITY" -ge 1 ]; then
                cat "$TEMP_DIR/bookverse_stages.txt" | sed 's/^/  - /' >&2
            fi
        fi
        
        echo "$count"
    else
        echo "Stages API not accessible (HTTP $code) - may need manual cleanup" >&2
        echo "Stages API not accessible (HTTP $code)" > "$TEMP_DIR/stages_api_status.txt"
        echo "0"
    fi
}

discover_applications() {
    echo "Discovering applications in project '$PROJECT_KEY'..." >&2
    
    # Try AppTrust applications API  
    local code=$(curl -s --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" --write-out "%{http_code}" --output "$TEMP_DIR/all_applications.json" -X GET "${JFROG_URL}apptrust/api/v1/applications")
    
    if [ "$code" -eq 200 ] && [ -s "$TEMP_DIR/all_applications.json" ]; then
        # Extract application keys by project_key filter
        jq -r --arg project_key "$PROJECT_KEY" '.[] | select(.project_key == $project_key) | .application_key' "$TEMP_DIR/all_applications.json" > "$TEMP_DIR/bookverse_applications.txt" 2>/dev/null || true
        
        local count=$(wc -l < "$TEMP_DIR/bookverse_applications.txt" 2>/dev/null || echo "0")
        echo "Found $count applications in project '$PROJECT_KEY'" >&2
        
        if [ "$count" -gt 0 ]; then
            echo "Application list saved to: $TEMP_DIR/bookverse_applications.txt" >&2
            if [ "$VERBOSITY" -ge 1 ]; then
                cat "$TEMP_DIR/bookverse_applications.txt" | sed 's/^/  - /' >&2
            fi
        fi
        
        echo "$count"
    else
        echo "AppTrust API not accessible (HTTP $code) - may need manual cleanup" >&2
        echo "AppTrust API not accessible (HTTP $code)" > "$TEMP_DIR/apptrust_api_status.txt"
        echo "0"
    fi
}

discover_lifecycle() {
    echo "Checking project lifecycle configuration..." >&2
    
    # Try lifecycle API
    local code=$(curl -s --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" --write-out "%{http_code}" --output "$TEMP_DIR/lifecycle_config.json" -X GET "${JFROG_URL}access/api/v2/lifecycle/?project_key=$PROJECT_KEY")
    
    if [ "$code" -eq 200 ] && [ -s "$TEMP_DIR/lifecycle_config.json" ]; then
        # Check if lifecycle has promote stages
        if jq -e '.categories[] | select(.category=="promote") | .stages | length > 0' "$TEMP_DIR/lifecycle_config.json" >/dev/null 2>&1; then
            echo "Found lifecycle configuration with promote stages: true" >&2
            echo "1"
        else
            echo "Found lifecycle configuration with promote stages: false" >&2
            echo "0"
        fi
    else
        echo "Lifecycle API not accessible (HTTP $code) - may need manual cleanup" >&2
        echo "Lifecycle API not accessible (HTTP $code)" > "$TEMP_DIR/lifecycle_api_status.txt"
        echo "0"
    fi
}

discover_project() {
    echo "Checking if project '$PROJECT_KEY' exists..." >&2
    
    # Try both API approaches for project discovery
    local code=$(jf rt curl -X GET "/access/api/v1/projects/$PROJECT_KEY" --write-out "%{http_code}" --output "$TEMP_DIR/project_response.txt" --silent)
    
    if [ "$code" -eq 200 ]; then
        echo "Project '$PROJECT_KEY' exists" >&2
        echo "1"
    elif [ "$code" -eq 404 ]; then
        echo "Project '$PROJECT_KEY' not found via jf rt curl" >&2
        
        # Try alternative API path
        local code2=$(curl -s --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" --write-out "%{http_code}" --output "$TEMP_DIR/project_response_alt.txt" -X GET "${JFROG_URL}access/api/v1/projects/$PROJECT_KEY")
        
        if [ "$code2" -eq 200 ]; then
            echo "Project '$PROJECT_KEY' found via direct API" >&2
            echo "1"
        elif [ "$code2" -eq 404 ]; then
            echo "Project '$PROJECT_KEY' not found via any API method" >&2
            echo "0"
        else
            echo "Project API not accessible (HTTP $code2) - project may exist but not accessible" >&2
            echo "1"  # Assume exists if API not accessible
        fi
    else
        echo "Project API not accessible (HTTP $code) - project may exist but not accessible" >&2
        echo "1"  # Assume exists if API not accessible
    fi
}

# =============================================================================
# DELETION FUNCTIONS
# =============================================================================

delete_repositories() {
    local repo_count="$1"
    
    echo "Starting repository deletion..."
    
    if [ "$repo_count" -eq 0 ]; then
        echo "No repositories to delete"
        return 0
    fi
    
    local deleted_count=0
    local failed_count=0
    
    while IFS= read -r repo; do
        if [ -n "$repo" ]; then
            echo "Deleting repository: $repo"
            
            local code=$(jf rt curl -X DELETE "/api/repositories/$repo" --write-out "%{http_code}" --output "$TEMP_DIR/delete_${repo}.txt" --silent)
            
            if [ "$code" -eq 200 ] || [ "$code" -eq 204 ]; then
                echo "Repository '$repo' deleted successfully (HTTP $code)"
                ((deleted_count++))
                
                # Verify deletion
                sleep 1
                local verify_code=$(jf rt curl -X GET "/api/repositories/$repo" --write-out "%{http_code}" --output /dev/null --silent)
                if [ "$verify_code" -eq 404 ]; then
                    echo "Deletion confirmed - repository no longer exists"
                else
                    echo "Warning: Repository may still exist (HTTP $verify_code)"
                fi
            else
                echo "Failed to delete repository '$repo' (HTTP $code)"
                ((failed_count++))
            fi
        fi
    done < "$TEMP_DIR/bookverse_repos.txt"
    
    echo "Repository deletion summary: $deleted_count deleted, $failed_count failed"
    
    if [ "$failed_count" -gt 0 ]; then
        return 1
    fi
    return 0
}

delete_users() {
    local user_count="$1"
    
    echo "Starting user deletion..."
    
    if [ "$user_count" -eq 0 ]; then
        echo "No users to delete"
        return 0
    fi
    
    local deleted_count=0
    local failed_count=0
    
    while IFS= read -r user; do
        if [ -n "$user" ]; then
            echo "Deleting user: $user"
            
            local code=$(jf rt curl -X DELETE "/api/security/users/$user" --write-out "%{http_code}" --output "$TEMP_DIR/delete_user_${user}.txt" --silent)
            
            if [ "$code" -eq 200 ] || [ "$code" -eq 204 ]; then
                echo "User '$user' deleted successfully (HTTP $code)"
                ((deleted_count++))
            else
                echo "Failed to delete user '$user' (HTTP $code)"
                ((failed_count++))
            fi
        fi
    done < "$TEMP_DIR/bookverse_users.txt"
    
    echo "User deletion summary: $deleted_count deleted, $failed_count failed"
    
    if [ "$failed_count" -gt 0 ]; then
        return 1
    fi
    return 0
}

delete_applications() {
    local app_count="$1"
    
    echo "Starting applications deletion..."
    
    if [ "$app_count" -eq 0 ]; then
        echo "No applications to delete"
        return 0
    fi
    
    local deleted_count=0
    local failed_count=0
    
    if [ -f "$TEMP_DIR/bookverse_applications.txt" ]; then
        while IFS= read -r app; do
            if [ -n "$app" ]; then
                echo "Deleting application: $app"
                
                local code=$(curl -s --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" --write-out "%{http_code}" --output "$TEMP_DIR/delete_app_${app}.txt" -X DELETE "${JFROG_URL}apptrust/api/v1/applications/$app")
                
                if [ "$code" -eq 200 ] || [ "$code" -eq 204 ]; then
                    echo "Application '$app' deleted successfully (HTTP $code)"
                    ((deleted_count++))
                elif [ "$code" -eq 404 ]; then
                    echo "Application '$app' not found or already deleted (HTTP $code)"
                    ((deleted_count++))
                else
                    echo "Failed to delete application '$app' (HTTP $code)"
                    ((failed_count++))
                fi
            fi
        done < "$TEMP_DIR/bookverse_applications.txt"
    fi
    
    echo "Application deletion summary: $deleted_count deleted, $failed_count failed"
    
    if [ "$failed_count" -gt 0 ]; then
        return 1
    fi
    return 0
}

delete_stages() {
    local stage_count="$1"
    
    echo "Starting project stages deletion..."
    
    if [ "$stage_count" -eq 0 ]; then
        echo "No project stages to delete"
        return 0
    fi
    
    local deleted_count=0
    local failed_count=0
    
    if [ -f "$TEMP_DIR/bookverse_stages.txt" ]; then
        while IFS= read -r stage; do
            if [ -n "$stage" ]; then
                echo "Deleting stage: $stage"
                
                local code=$(curl -s --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" --write-out "%{http_code}" --output "$TEMP_DIR/delete_stage_${stage}.txt" -X DELETE "${JFROG_URL}access/api/v2/stages/$stage")
                
                if [ "$code" -eq 200 ] || [ "$code" -eq 204 ]; then
                    echo "Stage '$stage' deleted successfully (HTTP $code)"
                    ((deleted_count++))
                elif [ "$code" -eq 404 ]; then
                    echo "Stage '$stage' not found or already deleted (HTTP $code)"
                    ((deleted_count++))
                else
                    echo "Failed to delete stage '$stage' (HTTP $code)"
                    ((failed_count++))
                fi
            fi
        done < "$TEMP_DIR/bookverse_stages.txt"
    fi
    
    echo "Stage deletion summary: $deleted_count deleted, $failed_count failed"
    
    if [ "$failed_count" -gt 0 ]; then
        return 1
    fi
    return 0
}

delete_lifecycle() {
    local lifecycle_exists="$1"
    
    echo "Starting lifecycle configuration cleanup..."
    
    if [ "$lifecycle_exists" -eq 0 ]; then
        echo "No lifecycle configuration to clean up"
        return 0
    fi
    
    echo "Clearing lifecycle promote stages for project: $PROJECT_KEY"
    
    # Clear the promote stages by setting empty array
    local lifecycle_payload='{"promote_stages": []}'
    
    local code=$(curl -s --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" --header "Content-Type: application/json" --write-out "%{http_code}" --output "$TEMP_DIR/delete_lifecycle.txt" -X PATCH -d "$lifecycle_payload" "${JFROG_URL}access/api/v2/lifecycle/?project_key=$PROJECT_KEY")
    
    if [ "$code" -eq 200 ] || [ "$code" -eq 204 ]; then
        echo "Lifecycle configuration cleared successfully (HTTP $code)"
        return 0
    elif [ "$code" -eq 404 ]; then
        echo "Lifecycle configuration not found or already cleared (HTTP $code)"
        return 0
    else
        echo "Failed to clear lifecycle configuration (HTTP $code)"
        return 1
    fi
}

delete_project() {
    local project_exists="$1"
    
    echo "Starting project deletion..."
    
    if [ "$project_exists" -eq 0 ]; then
        echo "No project to delete"
        return 0
    fi
    
    echo "Attempting to delete project: $PROJECT_KEY"
    
    # Try both API methods for deletion
    local code=$(curl -s --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" --write-out "%{http_code}" --output "$TEMP_DIR/delete_project.txt" -X DELETE "${JFROG_URL}access/api/v1/projects/$PROJECT_KEY")
    
    if [ "$code" -eq 200 ] || [ "$code" -eq 204 ]; then
        echo "Project '$PROJECT_KEY' deleted successfully (HTTP $code)"
        
        # Verify deletion with both methods
        sleep 2
        local verify_code1=$(jf rt curl -X GET "/access/api/v1/projects/$PROJECT_KEY" --write-out "%{http_code}" --output /dev/null --silent)
        local verify_code2=$(curl -s --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" --write-out "%{http_code}" --output /dev/null -X GET "${JFROG_URL}access/api/v1/projects/$PROJECT_KEY")
        
        if [ "$verify_code1" -eq 404 ] && [ "$verify_code2" -eq 404 ]; then
            echo "Deletion confirmed - project no longer exists"
            return 0
        else
            echo "Warning: Project may still exist (verify codes: $verify_code1, $verify_code2)"
            echo "Project deletion FAILED - resources may still be blocking deletion"
            return 1
        fi
    elif [ "$code" -eq 404 ]; then
        echo "Project '$PROJECT_KEY' not found or already deleted (HTTP $code)"
        return 0
    elif [ "$code" -eq 400 ]; then
        echo "Failed to delete project '$PROJECT_KEY' (HTTP $code) - likely contains resources"
        echo "Response: $(cat "$TEMP_DIR/delete_project.txt" 2>/dev/null || echo 'No response body')"
        return 1
    else
        echo "Failed to delete project '$PROJECT_KEY' (HTTP $code)"
        echo "Response: $(cat "$TEMP_DIR/delete_project.txt" 2>/dev/null || echo 'No response body')"
        return 1
    fi
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

FAILED=false

# Step 1: Discover and delete repositories
repo_count=$(discover_repositories)
echo ""
delete_repositories "$repo_count" || FAILED=true
echo ""

# Step 2: Discover and delete users  
user_count=$(discover_users)
echo ""
delete_users "$user_count" || FAILED=true
echo ""

# Step 3: Discover and delete applications
app_count=$(discover_applications)
echo ""
delete_applications "$app_count" || FAILED=true
echo ""

# Step 4: Discover and delete project stages
stage_count=$(discover_stages)
echo ""
delete_stages "$stage_count" || FAILED=true
echo ""

# Step 5: Discover and clear lifecycle configuration
lifecycle_exists=$(discover_lifecycle)
echo ""
delete_lifecycle "$lifecycle_exists" || FAILED=true
echo ""

# Step 6: Discover and delete project (after clearing resources)
project_exists=$(discover_project)
echo ""
delete_project "$project_exists" || FAILED=true
echo ""

# =============================================================================
# FINAL VALIDATION
# =============================================================================

echo "FINAL VALIDATION - Verifying complete cleanup..."
  echo ""

echo "Checking for remaining repositories..."
final_repo_count=$(discover_repositories)
if [ "$final_repo_count" -gt 0 ]; then
    echo "ERROR: Found $final_repo_count remaining repositories"
    FAILED=true
else
    echo "SUCCESS: No repositories found"
fi

echo ""
echo "Checking for remaining users..."
final_user_count=$(discover_users)
if [ "$final_user_count" -gt 0 ]; then
    echo "ERROR: Found $final_user_count remaining users"
    FAILED=true
else
    echo "SUCCESS: No users found"
fi

echo ""
echo "Checking for remaining applications..."
final_app_count=$(discover_applications)
if [ "$final_app_count" -gt 0 ]; then
    echo "ERROR: Found $final_app_count remaining applications in project"
    FAILED=true
else
    echo "SUCCESS: No applications found in project"
fi

echo ""
echo "Checking for remaining project stages..."
final_stage_count=$(discover_stages)
if [ "$final_stage_count" -gt 0 ]; then
    echo "ERROR: Found $final_stage_count remaining project stages"
    FAILED=true
else
    echo "SUCCESS: No project stages found"
fi

echo ""
echo "Checking for remaining lifecycle configuration..."
final_lifecycle_exists=$(discover_lifecycle)
if [ "$final_lifecycle_exists" -gt 0 ]; then
    echo "ERROR: Lifecycle configuration still exists"
    FAILED=true
else
    echo "SUCCESS: No lifecycle configuration found"
fi

echo ""
echo "Checking for remaining project..."
final_project_exists=$(discover_project)
if [ "$final_project_exists" -gt 0 ]; then
    echo "ERROR: Project still exists"
    FAILED=true
else
    echo "SUCCESS: No project found"
fi

echo ""

# =============================================================================
# SUMMARY
# =============================================================================

echo "Debug files saved in: $TEMP_DIR"

# Check if we have any remaining resources after cleanup
all_resources_deleted=true
if [ "$final_repo_count" -gt 0 ] || [ "$final_user_count" -gt 0 ] || [ "$final_app_count" -gt 0 ] || [ "$final_stage_count" -gt 0 ] || [ "$final_lifecycle_exists" -gt 0 ] || [ "$final_project_exists" -gt 0 ]; then
    all_resources_deleted=false
fi

if [ "$FAILED" = true ]; then
    echo "CLEANUP INCOMPLETE!"
    echo "Some resources failed to be deleted"
elif [ "$all_resources_deleted" = true ]; then
    echo "CLEANUP COMPLETED SUCCESSFULLY!"
    echo "All BookVerse resources have been deleted from the platform"
else
    echo "CLEANUP STATUS UNCERTAIN!"
    echo "Some resources may still exist - manual verification required"
fi

# Show detailed output based on result
if [ "$FAILED" = true ] || [ "$all_resources_deleted" = false ]; then
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

echo ""
echo "Enhanced cleanup process finished!"
