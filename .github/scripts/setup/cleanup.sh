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
    jf rt curl -X GET "/api/repositories" > "$TEMP_DIR/all_repos.json" 2>&1
    
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
    jf rt curl -X GET "/api/security/users" > "$TEMP_DIR/all_users.json" 2>&1
    
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

discover_project() {
    echo "Checking if project '$PROJECT_KEY' exists..." >&2
    
    local code=$(jf rt curl -X GET "/api/access/api/v1/projects/$PROJECT_KEY" --write-out "%{http_code}" --output "$TEMP_DIR/project_response.txt" --silent)
    
    if [ "$code" -eq 200 ]; then
        echo "Project '$PROJECT_KEY' exists" >&2
        echo "1"
    elif [ "$code" -eq 404 ]; then
        echo "Project '$PROJECT_KEY' not found" >&2
        echo "0"
    else
        echo "Failed to check project (HTTP $code)" >&2
        echo "0"
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

delete_project() {
    local project_exists="$1"
    
    echo "Starting project deletion..."
    
    if [ "$project_exists" -eq 0 ]; then
        echo "No project to delete"
        return 0
    fi
    
    echo "Deleting project: $PROJECT_KEY"
    
    local code=$(jf rt curl -X DELETE "/api/access/api/v1/projects/$PROJECT_KEY" --write-out "%{http_code}" --output "$TEMP_DIR/delete_project.txt" --silent)
    
    if [ "$code" -eq 200 ] || [ "$code" -eq 204 ]; then
        echo "Project '$PROJECT_KEY' deleted successfully (HTTP $code)"
        
        # Verify deletion
        sleep 2
        local verify_code=$(jf rt curl -X GET "/api/access/api/v1/projects/$PROJECT_KEY" --write-out "%{http_code}" --output /dev/null --silent)
        if [ "$verify_code" -eq 404 ]; then
            echo "Deletion confirmed - project no longer exists"
            return 0
        else
            echo "Warning: Project may still exist (HTTP $verify_code)"
            return 1
        fi
    elif [ "$code" -eq 404 ] || [ "$code" -eq 405 ]; then
        echo "Project '$PROJECT_KEY' not found or already deleted (HTTP $code)"
        return 0
    else
        echo "Failed to delete project '$PROJECT_KEY' (HTTP $code)"
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

# Step 3: Discover and delete project
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

if [ "$FAILED" = true ]; then
    echo "CLEANUP INCOMPLETE!"
    echo "Some resources may still exist in the JFrog platform"
    echo "Check the debug files for detailed information"
    exit 1
else
    echo "CLEANUP COMPLETED SUCCESSFULLY!"
    echo "All BookVerse resources have been completely removed"
    echo "The JFrog platform has been restored to its pre-BookVerse state"
    echo ""
    echo "Verified cleanup of:"
    echo "  - All repositories with '$PROJECT_KEY' prefix"
    echo "  - All users with '@bookverse.com' domain"
    echo "  - Project '$PROJECT_KEY'"
    echo ""
    echo "Final validation confirmed no remaining resources"
fi

echo ""
echo "Enhanced cleanup process finished!"
