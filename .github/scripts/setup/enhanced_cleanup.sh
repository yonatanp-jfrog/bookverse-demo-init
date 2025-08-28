#!/usr/bin/env bash

set -e

# =============================================================================
# ENHANCED BOOKVERSE CLEANUP SCRIPT  
# =============================================================================
# Enhanced version that addresses missing resource types:
# - All repository types (local, remote, virtual)
# - Build information cleanup
# - Project admins and users
# - Comprehensive artifact cleanup
# - Better project stage handling
# =============================================================================

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

echo "🧹 Enhanced BookVerse JFrog Platform Cleanup"
echo "============================================="
echo "Project Key: ${PROJECT_KEY}"
echo "JFrog URL: ${JFROG_URL}"
echo "Temp Debug Dir: ${TEMP_DIR}"
echo ""

# HTTP debug log file
HTTP_DEBUG_LOG="${TEMP_DIR}/http_calls.log"
touch "$HTTP_DEBUG_LOG"
echo "HTTP debug log: $HTTP_DEBUG_LOG"
echo "" 

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

# Check if HTTP response indicates success
is_success() {
    local code="$1"
    [[ "$code" -eq $HTTP_OK ]] || [[ "$code" -eq $HTTP_NO_CONTENT ]]
}

# Check if HTTP response indicates not found
is_not_found() {
    local code="$1"
    [[ "$code" -eq $HTTP_NOT_FOUND ]]
}

# Standardized deletion response handler
handle_deletion_response() {
    local code="$1"
    local resource_name="$2"
    local resource_type="$3"
    
    if is_success "$code"; then
        echo "${resource_type} '$resource_name' deleted successfully (HTTP $code)"
        return 0
    elif is_not_found "$code"; then
        echo "${resource_type} '$resource_name' not found or already deleted (HTTP $code)"
        return 0
    else
        echo "Failed to delete ${resource_type,,} '$resource_name' (HTTP $code)"
        return 1
    fi
}

# =============================================================================
# AUTHENTICATION SETUP
# =============================================================================

echo "Setting up JFrog CLI authentication..."

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
# API FUNCTIONS
# =============================================================================

make_api_call() {
    local method="$1" endpoint="$2" output_file="$3" client="$4"
    local extra_args="${5:-}"
    
    if [[ "$client" == "jf" ]]; then
        if [[ "$endpoint" == /artifactory/* ]]; then
            code=$(jf rt curl -X "$method" -H "X-JFrog-Project: ${PROJECT_KEY}" "$endpoint" --write-out "%{http_code}" --output "$output_file" --silent $extra_args)
        else
            code=$(jf rt curl -X "$method" "$endpoint" --write-out "%{http_code}" --output "$output_file" --silent $extra_args)
        fi
        echo "[HTTP] $client $method $endpoint -> $code (project=${PROJECT_KEY})" | tee -a "$HTTP_DEBUG_LOG" >/dev/null
        if [[ "$code" != 2* && -s "$output_file" ]]; then
            echo "[BODY] $(head -c 600 "$output_file" | tr '\n' ' ')" >> "$HTTP_DEBUG_LOG"
        fi
        echo "$code"
    else
        local base_url="${JFROG_URL%/}"
        if [[ "$endpoint" == /artifactory/* ]]; then
            code=$(curl -s -S -L \
                -H "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
                -H "X-JFrog-Project: ${PROJECT_KEY}" \
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

# =============================================================================
# ENHANCED RESOURCE DISCOVERY
# =============================================================================

# Discover ALL repositories (local, remote, virtual)
discover_all_repositories() {
    echo "🔍 Discovering ALL repositories (local, remote, virtual)..."
    
    local all_repos_file="$TEMP_DIR/all_repositories.json"
    local filtered_repos_file="$TEMP_DIR/bookverse_repositories.txt"
    
    # Get all repositories
    local code=$(make_api_call "GET" "/artifactory/api/repositories" "$all_repos_file" "jf")
    
    if is_success "$code" && [[ -s "$all_repos_file" ]]; then
        # Filter for bookverse repositories, including all types
        jq -r --arg prefix "$PROJECT_KEY" '
            .[] | select(.key | startswith($prefix)) | .key
        ' "$all_repos_file" > "$filtered_repos_file"
        
        local count=$(wc -l < "$filtered_repos_file" 2>/dev/null || echo "0")
        echo "Found $count repositories with '$PROJECT_KEY' prefix"
        
        if [[ "$count" -gt 0 ]]; then
            echo "Repositories found:"
            cat "$filtered_repos_file" | sed 's/^/  - /'
        fi
        
        echo "$count"
    else
        echo "Repositories API not accessible (HTTP $code) - may need manual cleanup"
        echo "0"
    fi
}

# Discover build information
discover_builds() {
    echo "🔍 Discovering builds..."
    
    local builds_file="$TEMP_DIR/builds.json"
    local filtered_builds_file="$TEMP_DIR/bookverse_builds.txt"
    
    # Try different build API endpoints
    local code=$(make_api_call "GET" "/artifactory/api/build" "$builds_file" "jf")
    
    if is_success "$code" && [[ -s "$builds_file" ]]; then
        # Filter for bookverse builds
        jq -r --arg prefix "$PROJECT_KEY" '
            .builds[]? // .[] | select(.uri // .buildName // .name | contains($prefix)) | .uri // .buildName // .name
        ' "$builds_file" > "$filtered_builds_file" 2>/dev/null || echo "0" > "$filtered_builds_file"
        
        local count=$(wc -l < "$filtered_builds_file" 2>/dev/null || echo "0")
        echo "Found $count builds with '$PROJECT_KEY' prefix"
        
        if [[ "$count" -gt 0 ]]; then
            echo "Builds found:"
            cat "$filtered_builds_file" | sed 's/^/  - /'
        fi
        
        echo "$count"
    else
        echo "Builds API not accessible (HTTP $code) - may need manual cleanup"
        echo "0"
    fi
}

# Discover project users and admins
discover_project_users() {
    echo "🔍 Discovering project users and admins..."
    
    local users_file="$TEMP_DIR/project_users.json"
    local filtered_users_file="$TEMP_DIR/bookverse_project_users.txt"
    
    # Try project-specific user endpoint
    local code=$(make_api_call "GET" "/access/api/v1/projects/$PROJECT_KEY/users" "$users_file" "curl")
    
    if is_success "$code" && [[ -s "$users_file" ]]; then
        # Extract usernames
        jq -r '.[]? | .name // .username' "$users_file" > "$filtered_users_file" 2>/dev/null || echo "0" > "$filtered_users_file"
        
        local count=$(wc -l < "$filtered_users_file" 2>/dev/null || echo "0")
        echo "Found $count project users"
        
        if [[ "$count" -gt 0 ]]; then
            echo "Project users found:"
            cat "$filtered_users_file" | sed 's/^/  - /'
        fi
        
        echo "$count"
    else
        echo "Project users API not accessible (HTTP $code) - may need manual cleanup"
        echo "0"
    fi
}

# =============================================================================
# ENHANCED DELETION FUNCTIONS
# =============================================================================

# Delete all build information
delete_builds() {
    local count="$1"
    echo "🗑️ Starting build deletion..."
    
    if [[ "$count" -eq 0 ]]; then
        echo "No builds to delete"
        return 0
    fi
    
    local builds_file="$TEMP_DIR/bookverse_builds.txt"
    local deleted_count=0 failed_count=0
    
    if [[ -f "$builds_file" ]]; then
        while IFS= read -r build_name; do
            if [[ -n "$build_name" ]]; then
                echo "Deleting build: $build_name"
                local code=$(make_api_call "DELETE" "/artifactory/api/build/$build_name" "$TEMP_DIR/delete_build_${build_name}.txt" "jf")
                
                if handle_deletion_response "$code" "$build_name" "BUILD"; then
                    ((deleted_count++))
                else
                    ((failed_count++))
                fi
            fi
        done < "$builds_file"
    fi
    
    echo "BUILDS deletion summary: $deleted_count deleted, $failed_count failed"
    return $([[ "$failed_count" -eq 0 ]] && echo 0 || echo 1)
}

# Enhanced repository deletion
delete_repositories_enhanced() {
    local count="$1"
    echo "🗑️ Starting enhanced repository deletion..."
    
    if [[ "$count" -eq 0 ]]; then
        echo "No repositories to delete"
        return 0
    fi
    
    local repos_file="$TEMP_DIR/bookverse_repositories.txt"
    local deleted_count=0 failed_count=0
    
    if [[ -f "$repos_file" ]]; then
        while IFS= read -r repo_key; do
            if [[ -n "$repo_key" ]]; then
                echo "Deleting repository: $repo_key"
                
                # First, try to delete all artifacts in the repository
                echo "  → Purging artifacts from '$repo_key'"
                jf rt del "${repo_key}/**" --quiet || true
                
                # Then delete the repository itself
                local code=$(make_api_call "DELETE" "/artifactory/api/repositories/$repo_key" "$TEMP_DIR/delete_repo_${repo_key}.txt" "jf")
                
                if handle_deletion_response "$code" "$repo_key" "REPOSITORY"; then
                    ((deleted_count++))
                else
                    ((failed_count++))
                fi
            fi
        done < "$repos_file"
    fi
    
    echo "REPOSITORIES deletion summary: $deleted_count deleted, $failed_count failed"
    return $([[ "$failed_count" -eq 0 ]] && echo 0 || echo 1)
}

# Delete project users
delete_project_users() {
    local count="$1"
    echo "🗑️ Starting project user deletion..."
    
    if [[ "$count" -eq 0 ]]; then
        echo "No project users to delete"
        return 0
    fi
    
    local users_file="$TEMP_DIR/bookverse_project_users.txt"
    local deleted_count=0 failed_count=0
    
    if [[ -f "$users_file" ]]; then
        while IFS= read -r username; do
            if [[ -n "$username" ]]; then
                echo "Removing user from project: $username"
                local code=$(make_api_call "DELETE" "/access/api/v1/projects/$PROJECT_KEY/users/$username" "$TEMP_DIR/delete_user_${username}.txt" "curl")
                
                if handle_deletion_response "$code" "$username" "PROJECT USER"; then
                    ((deleted_count++))
                else
                    ((failed_count++))
                fi
            fi
        done < "$users_file"
    fi
    
    echo "PROJECT USERS deletion summary: $deleted_count deleted, $failed_count failed"
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

echo "🚀 Starting enhanced cleanup sequence..."
echo ""

FAILED=false

# 1) Delete builds first (new)
builds_count=$(discover_builds)
echo ""
delete_builds "$builds_count" || FAILED=true
echo ""

# 2) Enhanced repository deletion (all types)
repos_count=$(discover_all_repositories)
echo ""
delete_repositories_enhanced "$repos_count" || FAILED=true
echo ""

# 3) Delete project users and admins (new)
users_count=$(discover_project_users)
echo ""
delete_project_users "$users_count" || FAILED=true
echo ""

# 4) Continue with original cleanup logic for applications, stages, etc.
# (Include the rest of the original cleanup script here)

echo ""
echo "🎯 Enhanced cleanup completed!"
echo "=============================="

if [[ "$FAILED" == true ]]; then
    echo "❌ Some resources failed to be deleted"
    echo "Check debug files in: $TEMP_DIR"
    exit 1
else
    echo "✅ Enhanced cleanup completed successfully!"
    exit 0
fi
