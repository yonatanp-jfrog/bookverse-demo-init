#!/usr/bin/env bash

set -e

# =============================================================================
# ROBUST BOOKVERSE CLEANUP SCRIPT
# =============================================================================
# This script dynamically discovers and deletes ALL BookVerse resources
# and validates that they are actually removed from the JFrog platform.

# =============================================================================
# ERROR HANDLING
# =============================================================================

error_handler() {
    local line_no=$1
    local error_code=$2
    echo ""
    echo "❌ SCRIPT ERROR DETECTED!"
    echo "   Line: $line_no"
    echo "   Exit Code: $error_code"
    echo "   Command: ${BASH_COMMAND}"
    echo ""
    echo "🔍 DEBUGGING INFORMATION:"
    echo "   Environment: CI=${CI_ENVIRONMENT}, VERBOSITY=${VERBOSITY}"
    echo "   Working Directory: $(pwd)"
    echo "   Project: ${PROJECT_KEY:-'Not set'}"
    echo "   JFrog URL: ${JFROG_URL:-'Not set'}"
    echo ""
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
    echo "🤖 CI Environment detected - interactive prompts will be skipped"
else
    export CI_ENVIRONMENT="false"
fi

# =============================================================================
# API HELPER FUNCTIONS
# =============================================================================

# Make authenticated API call using JFrog CLI
jf_api_call() {
    local method="$1"
    local endpoint="$2"
    local description="$3"
    local data="$4"
    
    if [ "$VERBOSITY" -ge 2 ]; then
        echo "   🌐 API Call: $method $endpoint"
        if [ -n "$data" ]; then
            echo "   📤 Payload: $data"
        fi
    fi
    
    local temp_response=$(mktemp)
    local http_code
    
    if [ -n "$data" ]; then
        http_code=$(jf rt curl -X "$method" "$endpoint" \
            --header "Content-Type: application/json" \
            --data "$data" \
            --write-out "%{http_code}" \
            --output "$temp_response" \
            --silent)
    else
        http_code=$(jf rt curl -X "$method" "$endpoint" \
            --write-out "%{http_code}" \
            --output "$temp_response" \
            --silent)
    fi
    
    if [ "$VERBOSITY" -ge 2 ]; then
        echo "   📥 Response Code: $http_code"
        if [ -s "$temp_response" ]; then
            echo "   📥 Response Body: $(cat "$temp_response")"
        fi
    fi
    
    # Check for authentication failures
    if [ "$http_code" -eq 401 ]; then
        echo "   ❌ AUTHENTICATION FAILED (HTTP 401)"
        echo "   This indicates the JFROG_ADMIN_TOKEN is invalid or expired."
        echo "   Response: $(cat "$temp_response")"
        rm -f "$temp_response"
        exit 1
    fi
    
    # Store response for caller
    export LAST_API_RESPONSE=$(cat "$temp_response")
    export LAST_API_CODE="$http_code"
    
    rm -f "$temp_response"
    echo "$http_code"
}

# =============================================================================
# RESOURCE DISCOVERY FUNCTIONS
# =============================================================================

discover_repositories() {
    echo "🔍 Discovering repositories with '$PROJECT_KEY' prefix..."
    
    local code=$(jf_api_call "GET" "/api/repositories" "List all repositories")
    
    if [ "$code" -eq 200 ]; then
        local repos=$(echo "$LAST_API_RESPONSE" | jq -r --arg prefix "$PROJECT_KEY" '.[] | select(.key | startswith($prefix)) | .key' 2>/dev/null || echo "")
        echo "$repos"
    else
        echo "   ❌ Failed to list repositories (HTTP $code)"
        echo ""
    fi
}

discover_users() {
    echo "🔍 Discovering users with '@bookverse.com' domain..."
    
    local code=$(jf_api_call "GET" "/api/security/users" "List all users")
    
    if [ "$code" -eq 200 ]; then
        local users=$(echo "$LAST_API_RESPONSE" | jq -r '.[] | select(.name | contains("@bookverse.com")) | .name' 2>/dev/null || echo "")
        echo "$users"
    else
        echo "   ❌ Failed to list users (HTTP $code)"
        echo ""
    fi
}

discover_project() {
    echo "🔍 Checking if project '$PROJECT_KEY' exists..."
    
    local code=$(jf_api_call "GET" "/api/access/api/v1/projects/$PROJECT_KEY" "Get project details")
    
    if [ "$code" -eq 200 ]; then
        echo "$PROJECT_KEY"
    elif [ "$code" -eq 404 ]; then
        echo "   ℹ️  Project '$PROJECT_KEY' not found"
        echo ""
    else
        echo "   ⚠️  Failed to check project (HTTP $code)"
        echo ""
    fi
}

# =============================================================================
# DELETION FUNCTIONS WITH VALIDATION
# =============================================================================

delete_repositories() {
    local repos="$1"
    local deleted_count=0
    local failed_count=0
    
    echo "📦 Deleting discovered repositories..."
    
    if [ -z "$repos" ]; then
        echo "   ℹ️  No repositories found to delete"
        return 0
    fi
    
    while IFS= read -r repo; do
        if [ -n "$repo" ]; then
            echo "   🗑️  Deleting repository: $repo"
            
            local code=$(jf_api_call "DELETE" "/api/repositories/$repo" "Delete repository $repo")
            
            if [ "$code" -eq 200 ] || [ "$code" -eq 204 ]; then
                echo "     ✅ Repository '$repo' deleted successfully (HTTP $code)"
                ((deleted_count++))
                
                # Validate deletion
                sleep 1
                local verify_code=$(jf_api_call "GET" "/api/repositories/$repo" "Verify repository deletion")
                if [ "$verify_code" -eq 404 ]; then
                    echo "     ✅ Deletion confirmed - repository no longer exists"
                else
                    echo "     ⚠️  Repository may still exist (HTTP $verify_code)"
                fi
            elif [ "$code" -eq 404 ]; then
                echo "     ⚠️  Repository '$repo' not found (HTTP $code)"
            else
                echo "     ❌ Failed to delete repository '$repo' (HTTP $code)"
                ((failed_count++))
            fi
        fi
    done <<< "$repos"
    
    echo "   📊 Repository deletion summary: $deleted_count deleted, $failed_count failed"
}

delete_users() {
    local users="$1"
    local deleted_count=0
    local failed_count=0
    
    echo "👥 Deleting discovered users..."
    
    if [ -z "$users" ]; then
        echo "   ℹ️  No users found to delete"
        return 0
    fi
    
    while IFS= read -r user; do
        if [ -n "$user" ]; then
            echo "   🗑️  Deleting user: $user"
            
            local code=$(jf_api_call "DELETE" "/api/security/users/$user" "Delete user $user")
            
            if [ "$code" -eq 200 ] || [ "$code" -eq 204 ]; then
                echo "     ✅ User '$user' deleted successfully (HTTP $code)"
                ((deleted_count++))
                
                # Validate deletion
                sleep 1
                local verify_code=$(jf_api_call "GET" "/api/security/users/$user" "Verify user deletion")
                if [ "$verify_code" -eq 404 ]; then
                    echo "     ✅ Deletion confirmed - user no longer exists"
                else
                    echo "     ⚠️  User may still exist (HTTP $verify_code)"
                fi
            elif [ "$code" -eq 404 ]; then
                echo "     ⚠️  User '$user' not found (HTTP $code)"
            else
                echo "     ❌ Failed to delete user '$user' (HTTP $code)"
                ((failed_count++))
            fi
        fi
    done <<< "$users"
    
    echo "   📊 User deletion summary: $deleted_count deleted, $failed_count failed"
}

delete_project() {
    local project="$1"
    
    echo "🏗️  Deleting project..."
    
    if [ -z "$project" ]; then
        echo "   ℹ️  No project found to delete"
        return 0
    fi
    
    echo "   🗑️  Deleting project: $project"
    
    local code=$(jf_api_call "DELETE" "/api/access/api/v1/projects/$project" "Delete project $project")
    
    if [ "$code" -eq 200 ] || [ "$code" -eq 204 ]; then
        echo "     ✅ Project '$project' deleted successfully (HTTP $code)"
        
        # Validate deletion
        sleep 2
        local verify_code=$(jf_api_call "GET" "/api/access/api/v1/projects/$project" "Verify project deletion")
        if [ "$verify_code" -eq 404 ]; then
            echo "     ✅ Deletion confirmed - project no longer exists"
            return 0
        else
            echo "     ⚠️  Project may still exist (HTTP $verify_code)"
            return 1
        fi
    elif [ "$code" -eq 404 ]; then
        echo "     ⚠️  Project '$project' not found (HTTP $code)"
        return 0
    else
        echo "     ❌ Failed to delete project '$project' (HTTP $code)"
        return 1
    fi
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

echo "🧹 BookVerse JFrog Platform Robust Cleanup"
echo "============================================="
echo ""
echo "📋 Configuration:"
echo "   Project Key: ${PROJECT_KEY}"
echo "   JFrog URL: ${JFROG_URL}"
echo "   Authentication: JFrog CLI configured"
echo ""

# Confirmation
if [ "$CI_ENVIRONMENT" != "true" ]; then
    echo "⚠️  WARNING: This will DELETE ALL BookVerse resources!"
    echo "   This action is IRREVERSIBLE!"
    echo ""
    read -p "Type 'DELETE' to confirm: " confirmation
    
    if [ "$confirmation" != "DELETE" ]; then
        echo "❌ Cleanup cancelled"
        exit 0
    fi
fi

echo "🔄 Starting robust cleanup sequence..."
echo ""

# Setup JFrog CLI
echo "🔧 Setting up JFrog CLI authentication..."

# Validate environment first
if [ -z "${JFROG_ADMIN_TOKEN}" ]; then
    echo "   ❌ JFROG_ADMIN_TOKEN is not set!"
    echo "   This script must run in GitHub Actions with the secret configured."
    exit 1
fi

if [ -z "${JFROG_URL}" ]; then
    echo "   ❌ JFROG_URL is not set!"
    exit 1
fi

echo "   📋 Using JFrog URL: ${JFROG_URL}"
echo "   📋 Token length: ${#JFROG_ADMIN_TOKEN} characters"

jf c add bookverse-admin --url="${JFROG_URL}" --access-token="${JFROG_ADMIN_TOKEN}" --interactive=false --overwrite
jf c use bookverse-admin

# Test authentication
echo "   🔍 Testing authentication..."
auth_test_code=$(jf rt curl -X GET "/api/system/ping" --write-out "%{http_code}" --output /dev/null --silent)
if [ "$auth_test_code" -eq 200 ]; then
    echo "   ✅ JFrog CLI configured and authenticated successfully"
else
    echo "   ❌ Authentication test failed (HTTP $auth_test_code)"
    echo "   Check that JFROG_ADMIN_TOKEN is valid and has admin permissions."
    exit 1
fi
echo ""

# Discover and delete resources
FAILED=false

# Step 1: Discover and delete repositories
repos=$(discover_repositories)
delete_repositories "$repos" || FAILED=true
echo ""

# Step 2: Discover and delete users  
users=$(discover_users)
delete_users "$users" || FAILED=true
echo ""

# Step 3: Discover and delete project
project=$(discover_project)
delete_project "$project" || FAILED=true
echo ""

# =============================================================================
# FINAL VALIDATION
# =============================================================================
echo "🔍 FINAL VALIDATION - Verifying complete cleanup..."
echo ""

echo "📦 Checking for remaining repositories..."
remaining_repos=$(discover_repositories)
if [ -n "$remaining_repos" ]; then
    echo "   ❌ Found remaining repositories:"
    echo "$remaining_repos" | sed 's/^/     - /'
    FAILED=true
else
    echo "   ✅ No repositories found - cleanup successful"
fi

echo ""
echo "👥 Checking for remaining users..."
remaining_users=$(discover_users)
if [ -n "$remaining_users" ]; then
    echo "   ❌ Found remaining users:"
    echo "$remaining_users" | sed 's/^/     - /'
    FAILED=true
else
    echo "   ✅ No users found - cleanup successful"
fi

echo ""
echo "🏗️  Checking for remaining project..."
remaining_project=$(discover_project)
if [ -n "$remaining_project" ]; then
    echo "   ❌ Project still exists: $remaining_project"
    FAILED=true
else
    echo "   ✅ No project found - cleanup successful"
fi

echo ""

# =============================================================================
# SUMMARY
# =============================================================================
if [ "$FAILED" = true ]; then
    echo "⚠️  CLEANUP INCOMPLETE!"
    echo "   Some resources may still exist in the JFrog platform."
    echo "   Check the logs above for specific failures."
    echo ""
    echo "   Manual cleanup may be required for remaining resources."
    echo "   You can also re-run this script to retry failed deletions."
    exit 1
else
    echo "✅ CLEANUP COMPLETED SUCCESSFULLY!"
    echo "   All BookVerse resources have been completely removed."
    echo "   The JFrog platform has been restored to its pre-BookVerse state."
    echo ""
    echo "   🎯 Verified cleanup of:"
    echo "     • All repositories with '$PROJECT_KEY' prefix"
    echo "     • All users with '@bookverse.com' domain"
    echo "     • Project '$PROJECT_KEY'"
    echo ""
    echo "   🔍 Final validation confirmed no remaining resources."
fi

echo ""
echo "🧹 Robust cleanup process finished!"
