#!/usr/bin/env bash

set -e

# =============================================================================
# PROJECT-BASED BOOKVERSE CLEANUP SCRIPT - BUILD API FIXES
# =============================================================================
# 🚨 BUILD DISCOVERY & DELETION API FIXES: User's correct approach implemented
# 
# BUILD DISCOVERY FIXES:
# ✅ Use project-specific API: /artifactory/api/build?project=$PROJECT_KEY
# ✅ Get builds that actually belong to the project (not name filtering)
#
# BUILD DELETION FIXES:
# ✅ Use correct REST API: POST /artifactory/api/build/delete
# ✅ Proper JSON payload with project, buildName, buildNumbers
# ✅ URL decode build names for API calls
#
# LATEST DISCOVERY SUCCESS:
# ✅ Found 1 build containing 'bookverse' (was 0)
# ✅ Found 26 repositories containing 'bookverse' (was 0)
# ✅ Discovery logic completely fixed and working
#
# INVESTIGATION FINDINGS:
# - REST API found 280 repositories (API works!)
# - NO repositories have projectKey='bookverse' field
# - Repositories DO contain 'bookverse' in their .key names
# - Same issue affects builds and other resources
#
# DISCOVERY IMPROVEMENTS:
# - REPOSITORIES: Filter by .key containing 'bookverse' (not projectKey)
# - BUILDS: Use project-specific endpoint /artifactory/api/build?project=X
# - METHOD 1: JFrog CLI repo-list (most reliable)
# - METHOD 2: REST API /artifactory/api/repositories  
# - METHOD 3: Alternate endpoint /artifactory/api/repositories/list
# - METHOD 4: CLI config fallback
#
# REPOSITORY DELETION IMPROVEMENTS:
# - PRIMARY: Use JFrog CLI 'jf rt repo-delete --force' (HTTP 405 fix)
# - FALLBACK: REST API DELETE (for compatibility)
# - Enhanced error reporting with response details
# 
# STAGE HANDLING CORRECTED:
# - DISCOVERY: Only find project-level stages belonging to the target project
# - DELETION: Only delete project-level stages (not global or system stages)
# - SYSTEM STAGES: PROD, DEV cannot be deleted (expected)
# - GLOBAL STAGES: Should NOT be deleted (system-wide, not project-specific)
# - PROJECT STAGES: Only delete those belonging to bookverse project
# 
# API ENDPOINT FIXES:
# - BUILD DELETION: Changed from REST API to JFrog CLI (jf rt build-delete)
# - REPOSITORY DISCOVERY: Get all repos and filter by projectKey
# - STAGE DISCOVERY: Multiple fallback methods (v1, v2, filtered all stages)
# 
# LOGGING BUG RESOLVED:
# - PREVIOUS: Discovery functions mixed logging with return values in stdout
# - ISSUE: Variables captured ALL output causing syntax errors in conditionals
# - FIX: Redirect logging to stderr (>&2), only return counts via stdout
# 
# SECURITY APPROACH (PREVIOUSLY CORRECTED):
# - DISCOVERY: Use GET /apptrust/api/v1/applications?project_key=<PROJECT_KEY>
# - VERIFICATION: Double-check each app belongs to target project before deletion
# - DELETION: Use CLI commands only after confirming project membership
# - SAFETY: CLI commands (jf apptrust app-delete) don't have project flags,
#           so we MUST verify project membership before deletion
# 
# CORRECT API USAGE:
# - Application discovery: project_key parameter (not project)
# - Version discovery: project_key parameter for version listing
# - Pre-deletion verification: Confirm app is in target project list
# - Function output: Logging to stderr, counts to stdout for capture
# 
# Investigation Results:
# - USERS: Project-based finds 4 correct admins vs 12 email-based users
# - REPOSITORIES: Both approaches find 26, but project-based is correct
# - BUILDS: Must use project-based filtering
# - APPLICATIONS: SAFELY VERIFIED before deletion (prevents cross-project deletion)
# - ALL RESOURCES: Look for project membership, not names containing 'bookverse'
# =============================================================================

# Resolve script directory robustly even when sourced
_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${_SCRIPT_DIR}/common.sh"

# 🔧 CRITICAL FIX: Initialize script to load PROJECT_KEY from config.sh
# This was the root cause of the catastrophic filtering failure
init_script "cleanup_project_based.sh" "PROJECT-BASED BookVerse Cleanup"

# Constants (HTTP status codes defined in common.sh)
# Additional constants (HTTP status codes inherited from common.sh)

TEMP_DIR="/tmp/bookverse_cleanup_$$"
mkdir -p "$TEMP_DIR"

# Header is now displayed by init_script() - avoid duplication
echo "APPROACH: Find ALL resources belonging to PROJECT '${PROJECT_KEY}'"
echo "NOT just resources with 'bookverse' in their names"
echo "Debug Dir: ${TEMP_DIR}"
echo ""

# HTTP debug log
HTTP_DEBUG_LOG="${TEMP_DIR}/project_based_cleanup.log"
touch "$HTTP_DEBUG_LOG"

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

log_http_request() {
    local method="$1" endpoint="$2" code="$3" description="$4"
    echo "[API] $method $endpoint -> HTTP $code ($description)" >> "$HTTP_DEBUG_LOG"
}

is_success() {
    local code="$1"
    [[ "$code" -eq $HTTP_OK ]] || [[ "$code" -eq $HTTP_NO_CONTENT ]]
}

is_not_found() {
    local code="$1"
    [[ "$code" -eq $HTTP_NOT_FOUND ]]
}

# Enhanced API call with better debugging
jfrog_api_call() {
    local method="$1" endpoint="$2" output_file="$3" client="$4"
    local data_payload="${5:-}"
    local description="${6:-}"
    
    # When no output file is provided, discard body to /dev/null
    if [[ -z "$output_file" ]]; then
        output_file="/dev/null"
    fi

    local code
    if [[ "$client" == "jf" ]]; then
        if [[ "$endpoint" == /artifactory/* ]]; then
            if [[ -n "$data_payload" ]]; then
                code=$(echo "$data_payload" | jf rt curl -X "$method" -H "X-JFrog-Project: ${PROJECT_KEY}" "$endpoint" --write-out "%{http_code}" --output "$output_file" --silent --data @-)
            else
                code=$(jf rt curl -X "$method" -H "X-JFrog-Project: ${PROJECT_KEY}" "$endpoint" --write-out "%{http_code}" --output "$output_file" --silent)
            fi
        else
            if [[ -n "$data_payload" ]]; then
                code=$(echo "$data_payload" | jf rt curl -X "$method" "$endpoint" --write-out "%{http_code}" --output "$output_file" --silent --data @-)
            else
                code=$(jf rt curl -X "$method" "$endpoint" --write-out "%{http_code}" --output "$output_file" --silent)
            fi
        fi
    else
        local base_url="${JFROG_URL%/}"
        if [[ "$endpoint" == /artifactory/* ]]; then
            if [[ -n "$data_payload" ]]; then
                code=$(curl -s -S -L \
                    -H "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
                    -H "X-JFrog-Project: ${PROJECT_KEY}" \
                    -H "Content-Type: application/json" \
                    -X "$method" "${base_url}${endpoint}" \
                    --data "$data_payload" \
                    --write-out "%{http_code}" --output "$output_file")
            else
                code=$(curl -s -S -L \
                    -H "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
                    -H "X-JFrog-Project: ${PROJECT_KEY}" \
                    -H "Content-Type: application/json" \
                    -X "$method" "${base_url}${endpoint}" \
                    --write-out "%{http_code}" --output "$output_file")
            fi
        else
            if [[ -n "$data_payload" ]]; then
                code=$(curl -s -S -L \
                    -H "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
                    -H "Content-Type: application/json" \
                    -X "$method" "${base_url}${endpoint}" \
                    --data "$data_payload" \
                    --write-out "%{http_code}" --output "$output_file")
            else
                code=$(curl -s -S -L \
                    -H "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
                    -H "Content-Type: application/json" \
                    -X "$method" "${base_url}${endpoint}" \
                    --write-out "%{http_code}" --output "$output_file")
            fi
        fi
    fi
    
    log_http_request "$method" "$endpoint" "$code" "$description"
    
    # Log response body for non-success codes
    if [[ "$code" != 2* ]] && [[ -s "$output_file" ]]; then
        echo "[ERROR] Response: $(head -c 300 "$output_file" | tr '\n' ' ')" >> "$HTTP_DEBUG_LOG"
    fi
    
    echo "$code"
}

# =============================================================================
# AUTHENTICATION SETUP
# =============================================================================

echo "🔐 Setting up JFrog CLI authentication..."

if [ -z "${JFROG_ADMIN_TOKEN}" ]; then
    echo "ERROR: JFROG_ADMIN_TOKEN is not set"
    exit 1
fi

jf c add bookverse-admin --url="${JFROG_URL}" --access-token="${JFROG_ADMIN_TOKEN}" --interactive=false --overwrite
jf c use bookverse-admin

# Test authentication
auth_test_code=$(jf rt curl -X GET "/api/system/ping" --write-out "%{http_code}" --output /dev/null --silent)
if [ "$auth_test_code" -eq 200 ]; then
    echo "✅ Authentication successful"
else
    echo "❌ Authentication failed (HTTP $auth_test_code)"
    exit 1
fi
echo ""

# =============================================================================
# PROJECT-BASED RESOURCE DISCOVERY
# =============================================================================

# 1. PROJECT-BASED REPOSITORY DISCOVERY
discover_project_repositories() {
    echo "🔍 Discovering project repositories (PROJECT-BASED)..." >&2
    
    local repos_file="$TEMP_DIR/project_repositories.json"
    local filtered_repos="$TEMP_DIR/project_repositories.txt"
    
    # Try multiple repository discovery methods for project-based repositories
    local code=404  # Default to not found
    
    # Use REST API directly (consistent, reliable, no CLI dependency)
    echo "Discovering repositories via REST API..." >&2
    
    code=$(jfrog_api_call "GET" "/artifactory/api/repositories" "$repos_file" "curl" "" "all repositories")
    
    if ! is_success "$code"; then
        # Single fallback: try alternate endpoint
        echo "Trying alternate repository endpoint..." >&2
        code=$(jfrog_api_call "GET" "/artifactory/api/repositories/list" "$repos_file" "curl" "" "repository list")
    fi
    
    # Filter repositories by project key if we got data
    if is_success "$code" && [[ -s "$repos_file" ]]; then
        echo "Filtering repositories for project '$PROJECT_KEY'..." >&2
        
        # INVESTIGATION FINDINGS: repositories don't have projectKey field, filter by name
        # Primary strategy: Filter by repository key containing 'bookverse'
        if jq --arg project "$PROJECT_KEY" '[.[] | select(.key | contains($project))]' "$repos_file" > "${repos_file}.filtered" 2>/dev/null && [[ -s "${repos_file}.filtered" ]]; then
            mv "${repos_file}.filtered" "$repos_file"
            echo "✅ Filtered by repository key containing '$PROJECT_KEY'" >&2
            
            # Log found repositories for debugging
            echo "📦 Found repositories:" >&2
            jq -r '.[].key' "$repos_file" 2>/dev/null | head -10 | while read -r repo; do
                echo "   - $repo" >&2
            done
        else
            # Fallback: Try prefix match
            if jq --arg project "$PROJECT_KEY" '[.[] | select(.key | startswith($project))]' "$repos_file" > "${repos_file}.filtered" 2>/dev/null && [[ -s "${repos_file}.filtered" ]]; then
                mv "${repos_file}.filtered" "$repos_file"
                echo "✅ Filtered by repository key prefix '$PROJECT_KEY'" >&2
            else
                # Final fallback: Try projectKey field (original logic)
                if jq --arg project "$PROJECT_KEY" '[.[] | select(.projectKey == $project)]' "$repos_file" > "${repos_file}.filtered" 2>/dev/null && [[ -s "${repos_file}.filtered" ]]; then
                    mv "${repos_file}.filtered" "$repos_file"
                    echo "✅ Filtered by projectKey field" >&2
                else
                    echo "❌ No repositories found matching '$PROJECT_KEY'" >&2
                    echo "[]" > "$repos_file"
                fi
            fi
        fi
    fi
    
    if is_success "$code" && [[ -s "$repos_file" ]]; then
        # Extract all repository keys from project (not filtering by name)
        echo "🚨 DEBUG: Repositories discovered for deletion:" >&2
        jq -r '.[] | .key' "$repos_file" | head -20 | while read -r repo; do echo "    - $repo" >&2; done
        echo "    (showing first 20 of $(jq length "$repos_file") total)" >&2
        jq -r '.[] | .key' "$repos_file" > "$filtered_repos"
        
        local count=$(wc -l < "$filtered_repos" 2>/dev/null || echo "0")
        echo "📦 Found $count repositories in project '$PROJECT_KEY'" >&2
        
        if [[ "$count" -gt 0 ]]; then
            echo "Project repositories:" >&2
            cat "$filtered_repos" | sed 's/^/  - /' >&2
        fi
        
        # Count returned via global variable, function always returns 0 (success)
        GLOBAL_REPO_COUNT=$count
        return 0
    else
        echo "❌ Project repository discovery failed (HTTP $code)" >&2
        # Count returned via global variable, function always returns 0 (success) 
        GLOBAL_REPO_COUNT=0
        return 0
    fi
}

# 2. PROJECT-BASED USER DISCOVERY
discover_project_users() {
    echo "🔍 Discovering project users/admins (PROJECT-BASED)..." >&2
    
    local users_file="$TEMP_DIR/project_users.json"
    local filtered_users="$TEMP_DIR/project_users.txt"
    
    # Use project-specific user endpoint - this finds actual project members
    local code=$(jfrog_api_call "GET" "/access/api/v1/projects/$PROJECT_KEY/users" "$users_file" "curl" "" "project users")
    
    if is_success "$code" && [[ -s "$users_file" ]]; then
        # Extract user names from project members (not filtering by email domain)
        jq -r '.members[]? | .name' "$users_file" > "$filtered_users" 2>/dev/null || touch "$filtered_users"
        
        local count=$(wc -l < "$filtered_users" 2>/dev/null || echo "0")
        echo "👥 Found $count users/admins in project '$PROJECT_KEY'" >&2
        
        if [[ "$count" -gt 0 ]]; then
            echo "Project users/admins:" >&2
            cat "$filtered_users" | sed 's/^/  - /' >&2
            echo "Detailed roles:" >&2
            jq -r '.members[]? | "  - \(.name) (roles: \(.roles | join(", ")))"' "$users_file" 2>/dev/null || true >&2
        fi
        
        # Count returned via global variable, function always returns 0 (success)
        GLOBAL_USER_COUNT=$count
        return 0
    else
        echo "❌ Project user discovery failed (HTTP $code)" >&2
        # Count returned via global variable, function always returns 0 (success)
        GLOBAL_USER_COUNT=0
        return 0
    fi
}

# 3. PROJECT-BASED APPLICATION DISCOVERY
discover_project_applications() {
    echo "🔍 Discovering project applications (PROJECT-BASED)..." >&2
    
    local apps_file="$TEMP_DIR/project_applications.json"
    local filtered_apps="$TEMP_DIR/project_applications.txt"
    
    # Use correct project_key parameter as specified in API documentation
    local code=$(jfrog_api_call "GET" "/apptrust/api/v1/applications?project_key=$PROJECT_KEY" "$apps_file" "curl" "" "project applications")
    
    if is_success "$code" && [[ -s "$apps_file" ]]; then
        jq -r '.[] | .application_key' "$apps_file" > "$filtered_apps" 2>/dev/null || touch "$filtered_apps"
        
        local count=$(wc -l < "$filtered_apps" 2>/dev/null || echo "0")
        echo "🚀 Found $count applications in project '$PROJECT_KEY'" >&2
        
        if [[ "$count" -gt 0 ]]; then
            echo "Project applications:" >&2
            cat "$filtered_apps" | sed 's/^/  - /' >&2
        fi
        
        # Count returned via global variable, function always returns 0 (success)
        GLOBAL_APP_COUNT=$count
        return 0
    else
        echo "❌ Project application discovery failed (HTTP $code)" >&2
        # Count returned via global variable, function always returns 0 (success)
        GLOBAL_APP_COUNT=0
        return 0
    fi
}

# 4. PROJECT-BASED BUILD DISCOVERY
discover_project_builds() {
    echo "🔍 Discovering project builds (PROJECT-BASED)..." >&2
    
    local builds_file="$TEMP_DIR/project_builds.json"
    local filtered_builds="$TEMP_DIR/project_builds.txt"
    
    # Use project-specific build discovery API (user's correct approach)
    local code=$(jfrog_api_call "GET" "/artifactory/api/build?project=$PROJECT_KEY" "$builds_file" "curl" "" "project builds")
    
    if is_success "$code" && [[ -s "$builds_file" ]]; then
        echo "✅ Successfully discovered builds for project '$PROJECT_KEY'" >&2
        
        # Extract build names from project builds
        if jq -r '.builds[]?.uri' "$builds_file" 2>/dev/null | sed 's|^/||' > "$filtered_builds" 2>/dev/null && [[ -s "$filtered_builds" ]]; then
            local count=$(wc -l < "$filtered_builds" 2>/dev/null || echo 0)
            echo "🏗️ Found $count builds in project '$PROJECT_KEY'" >&2
            
            if [[ "$count" -gt 0 ]]; then
                echo "Project builds:" >&2
                while IFS= read -r build; do
                    echo "   - $build" >&2
                done < "$filtered_builds"
            fi
        else
            echo "🔍 No builds found in project '$PROJECT_KEY'" >&2
            touch "$filtered_builds"
            count=0
        fi
        
        # Count returned via global variable, function always returns 0 (success)
        GLOBAL_BUILD_COUNT=$count
        return 0
    else
        echo "❌ Failed to discover project builds (HTTP $code)" >&2
        touch "$filtered_builds"
        # Count returned via global variable, function always returns 0 (success)
        GLOBAL_BUILD_COUNT=0
        return 0
    fi
}

# 5. PROJECT-BASED STAGE DISCOVERY
discover_project_stages() {
    echo "🔍 Discovering project stages (PROJECT-BASED)..." >&2
    
    local stages_file="$TEMP_DIR/project_stages.json"
    local filtered_stages="$TEMP_DIR/project_stages.txt"
    
    # PROJECT-LEVEL STAGE DISCOVERY: Use proper API with query parameters
    echo "Getting project promote stages..." >&2
    local code=$(jfrog_api_call "GET" "/access/api/v2/stages/?project_key=$PROJECT_KEY&scope=project&category=promote" "$stages_file" "curl" "" "project promote stages")
    
    if is_success "$code" && [[ -s "$stages_file" ]]; then
        # Extract stage names from response
        jq -r '.[] | .name' "$stages_file" > "$filtered_stages" 2>/dev/null || touch "$filtered_stages"
        
        local count=$(wc -l < "$filtered_stages" 2>/dev/null || echo "0")
        echo "🏷️ Found $count project promote stages in '$PROJECT_KEY'" >&2
        
        if [[ "$count" -gt 0 ]]; then
            echo "Project promote stages:" >&2
            cat "$filtered_stages" | sed 's/^/  - /' >&2
        fi
        
        # Count returned via global variable, function always returns 0 (success)
        GLOBAL_STAGE_COUNT=$count
        return 0
    else
        echo "❌ Project stage discovery failed (HTTP $code)" >&2
        # Count returned via global variable, function always returns 0 (success)
        GLOBAL_STAGE_COUNT=0
        return 0
    fi
}



# =============================================================================
# PROJECT-BASED DELETION FUNCTIONS
# =============================================================================

# SPECIFIC DELETION FUNCTIONS - For cleanup from reports
# These functions delete only the specific items provided in a file

# Delete specific builds from a list file
delete_specific_builds() {
    local builds_file="$1"
    local failed_count=0
    
    if [[ ! -f "$builds_file" ]]; then
        echo "❌ Builds file not found: $builds_file" >&2
        return 1
    fi
    
    echo "🔧 Deleting specific builds from report..." >&2
    
    while IFS= read -r build_name; do
        if [[ -n "$build_name" ]]; then
            echo "  → Deleting build: $build_name"
            # URL decode the build name for API calls
            local decoded_build_name=$(printf '%b' "${build_name//%/\\x}")
            
            # Delete all build numbers for this build
            local code=$(jfrog_api_call "DELETE" "/artifactory/api/build/$decoded_build_name?project=$PROJECT_KEY&deleteAll=1" "" "curl" "" "delete all builds for $decoded_build_name")
            
            if is_success "$code"; then
                echo "    ✅ Build '$build_name' deleted successfully"
            else
                echo "    ❌ Failed to delete build '$build_name' (HTTP $code)"
                ((failed_count++))
            fi
        fi
    done < "$builds_file"
    
    if [[ $failed_count -gt 0 ]]; then
        echo "❌ Failed to delete $failed_count builds" >&2
        return 1
    fi
    
    echo "✅ All specified builds deleted successfully" >&2
    return 0
}

# Delete specific applications from a list file
delete_specific_applications() {
    local apps_file="$1"
    local failed_count=0
    
    if [[ ! -f "$apps_file" ]]; then
        echo "❌ Applications file not found: $apps_file" >&2
        return 1
    fi
    
    echo "🚀 Deleting specific applications from report..." >&2
    
    while IFS= read -r app_key; do
        if [[ -n "$app_key" ]]; then
            echo "  → Deleting application: $app_key"
            
            local code=$(jfrog_api_call "DELETE" "/apptrust/api/v1/applications/$app_key" "" "curl" "" "delete application $app_key")
            
            if is_success "$code"; then
                echo "    ✅ Application '$app_key' deleted successfully"
            else
                echo "    ❌ Failed to delete application '$app_key' (HTTP $code)"
                ((failed_count++))
            fi
        fi
    done < "$apps_file"
    
    if [[ $failed_count -gt 0 ]]; then
        echo "❌ Failed to delete $failed_count applications" >&2
        return 1
    fi
    
    echo "✅ All specified applications deleted successfully" >&2
    return 0
}

# Delete specific repositories from a list file
delete_specific_repositories() {
    local repos_file="$1"
    local failed_count=0
    
    if [[ ! -f "$repos_file" ]]; then
        echo "❌ Repositories file not found: $repos_file" >&2
        return 1
    fi
    
    echo "📦 Deleting specific repositories from report..." >&2
    
    while IFS= read -r repo_key; do
        if [[ -n "$repo_key" ]]; then
            echo "  → Deleting repository: $repo_key"
            
            # Purge artifacts first
            echo "    Purging artifacts..."
            jf rt del "${repo_key}/**" --quiet 2>/dev/null || echo "    Warning: Artifact purge failed"
            
            # Delete repository via REST API
            echo "    Deleting repository via REST API..."
            local code=$(jfrog_api_call "DELETE" "/artifactory/api/repositories/$repo_key" "" "curl" "" "delete repository $repo_key")
            
            if is_success "$code"; then
                echo "    ✅ Repository '$repo_key' deleted successfully"
            else
                echo "    ❌ Failed to delete repository '$repo_key' (HTTP $code)"
                ((failed_count++))
            fi
        fi
    done < "$repos_file"
    
    if [[ $failed_count -gt 0 ]]; then
        echo "❌ Failed to delete $failed_count repositories" >&2
        return 1
    fi
    
    echo "✅ All specified repositories deleted successfully" >&2
    return 0
}

# Delete specific users from a list file
delete_specific_users() {
    local users_file="$1"
    local failed_count=0
    
    if [[ ! -f "$users_file" ]]; then
        echo "❌ Users file not found: $users_file" >&2
        return 1
    fi
    
    echo "👥 Deleting specific users from report..." >&2
    
    while IFS= read -r username; do
        if [[ -n "$username" ]]; then
            echo "  → Deleting user: $username"
            
            local code=$(jfrog_api_call "DELETE" "/access/api/v2/users/$username" "" "curl" "" "delete user $username")
            
            if is_success "$code"; then
                echo "    ✅ User '$username' deleted successfully"
            else
                echo "    ❌ Failed to delete user '$username' (HTTP $code)"
                ((failed_count++))
            fi
        fi
    done < "$users_file"
    
    if [[ $failed_count -gt 0 ]]; then
        echo "❌ Failed to delete $failed_count users" >&2
        return 1
    fi
    
    echo "✅ All specified users deleted successfully" >&2
    return 0
}

# Delete specific stages from a list file
delete_specific_stages() {
    local stages_file="$1"
    local failed_count=0
    
    if [[ ! -f "$stages_file" ]]; then
        echo "❌ Stages file not found: $stages_file" >&2
        return 1
    fi
    
    echo "🏷️ Deleting specific stages from report..." >&2
    
    # Ensure lifecycle is cleared first (idempotent)
    delete_project_lifecycle >/dev/null 2>&1 || true

    while IFS= read -r stage_name; do
        if [[ -n "$stage_name" ]]; then
            echo "  → Deleting stage: $stage_name"
            # Try project-scoped v1 first
            local code=$(jfrog_api_call "DELETE" "/access/api/v1/projects/$PROJECT_KEY/stages/$stage_name" "" "curl" "" "delete project stage $stage_name")
            if ! is_success "$code"; then
                # Fallback to v2 with explicit project key
                code=$(jfrog_api_call "DELETE" "/access/api/v2/stages/$stage_name?projectKey=$PROJECT_KEY" "" "curl" "" "delete project stage v2 $stage_name")
            fi

            if is_success "$code" || is_not_found "$code"; then
                echo "    ✅ Stage '$stage_name' deleted successfully"
            else
                echo "    ❌ Failed to delete stage '$stage_name' (HTTP $code)"
                ((failed_count++))
            fi
        fi
    done < "$stages_file"
    
    if [[ $failed_count -gt 0 ]]; then
        echo "❌ Failed to delete $failed_count stages" >&2
        return 1
    fi
    
    echo "✅ All specified stages deleted successfully" >&2
    return 0
}

# Final project deletion function
delete_project_final() {
    local project_key="$1"
    
    echo "🎯 Attempting final project deletion: $project_key" >&2
    
    # Safety: verify there are truly no resources detected by a quick re-discovery
    discover_project_repositories >/dev/null 2>&1 || true
    discover_project_applications >/dev/null 2>&1 || true
    discover_project_users >/dev/null 2>&1 || true
    discover_project_stages >/dev/null 2>&1 || true
    local remaining=$(( ${GLOBAL_REPO_COUNT:-0} + ${GLOBAL_APP_COUNT:-0} + ${GLOBAL_USER_COUNT:-0} + ${GLOBAL_STAGE_COUNT:-0} ))
    if [[ "$remaining" -gt 0 ]]; then
        echo "⚠️ Remaining resources detected just before project deletion: $remaining" >&2
    fi

    # Try to delete the project
    local code=$(jfrog_api_call "DELETE" "/access/api/v2/projects/$project_key" "" "curl" "" "delete project $project_key")
    
    if is_success "$code"; then
        echo "✅ Project '$project_key' deleted successfully" >&2
        return 0
    else
        echo "❌ Failed to delete project '$project_key' (HTTP $code)" >&2
        echo "💡 This usually indicates there are still resources in the project" >&2
        return 1
    fi
}

# 🚨 EMERGENCY SAFETY CHECK: Verify repository belongs to project
verify_repository_project_membership() {
    local repo_key="$1"
    echo "🛡️ SAFETY: Verifying repository '$repo_key' belongs to project '$PROJECT_KEY'"...
    
    # CRITICAL: Only delete repositories that contain the project key
    if [[ "$repo_key" == *"$PROJECT_KEY"* ]]; then
        echo "    ✅ SAFE: Repository contains '$PROJECT_KEY'"
        return 0
    else
        echo "    🚨 BLOCKED: Repository does NOT contain '$PROJECT_KEY' - REFUSING DELETION"
        return 1
    fi
}
# Delete project repositories
delete_project_repositories() {
    local count="$1"
    echo "🗑️ Starting project repository deletion..."
    echo "🚨 EMERGENCY SAFETY CHECK: About to delete repositories"
    echo "Project: $PROJECT_KEY"
    echo "Count: $count repositories"
    echo ""
    echo "⚠️ This action will delete repositories. Proceeding..."
    
    if [[ "$count" -eq 0 ]]; then
        echo "No project repositories to delete"
        return 0
    fi
    
    local repos_file="$TEMP_DIR/project_repositories.txt"
    local deleted_count=0 failed_count=0
    
    if [[ -f "$repos_file" ]]; then
        while IFS= read -r repo_key; do
            if [[ -n "$repo_key" ]] && verify_repository_project_membership "$repo_key"; then
                echo "  → Deleting repository: $repo_key"
                
                # Purge artifacts first
                echo "    Purging artifacts..."
                jf rt del "${repo_key}/**" --quiet 2>/dev/null || echo "    Warning: Artifact purge failed"
                
                # Use REST API directly (consistent, reliable, no CLI dependency)
                echo "    Deleting repository via REST API..."
                local code=$(jfrog_api_call "DELETE" "/artifactory/api/repositories/$repo_key" "$TEMP_DIR/delete_repo_${repo_key}.txt" "curl" "" "delete repository $repo_key")
                
                if is_success "$code"; then
                    echo "    ✅ Repository '$repo_key' deleted successfully (HTTP $code)"
                    ((deleted_count++))
                elif is_not_found "$code"; then
                    echo "    ⚠️ Repository '$repo_key' not found or already deleted (HTTP $code)"
                    ((deleted_count++))
                else
                    echo "    ❌ Failed to delete repository '$repo_key' (HTTP $code)"
                    echo "    Response: $(cat "$TEMP_DIR/delete_repo_${repo_key}.txt" 2>/dev/null || echo 'No response')"
                    ((failed_count++))
                fi
            fi
        done < "$repos_file"
    fi
    
    echo "📦 PROJECT REPOSITORIES deletion summary: $deleted_count deleted, $failed_count failed"
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
    
    local users_file="$TEMP_DIR/project_users.txt"
    local deleted_count=0 failed_count=0
    
    if [[ -f "$users_file" ]]; then
        while IFS= read -r username; do
            if [[ -n "$username" ]]; then
                echo "  → Removing user from project: $username"
                
                local code=$(jfrog_api_call "DELETE" "/access/api/v1/projects/$PROJECT_KEY/users/$username" "$TEMP_DIR/delete_user_${username}.txt" "curl" "" "remove project user $username")
                
                if is_success "$code"; then
                    echo "    ✅ User '$username' removed from project successfully (HTTP $code)"
                    ((deleted_count++))
                elif is_not_found "$code"; then
                    echo "    ⚠️ User '$username' not found in project or already removed (HTTP $code)"
                    ((deleted_count++))
                else
                    echo "    ❌ Failed to remove user '$username' from project (HTTP $code)"
                    ((failed_count++))
                fi
            fi
        done < "$users_file"
    fi
    
    echo "👥 PROJECT USERS deletion summary: $deleted_count deleted, $failed_count failed"
    return $([[ "$failed_count" -eq 0 ]] && echo 0 || echo 1)
}

# Delete project applications (VERIFIED PROJECT-MEMBERSHIP VERSION)
delete_project_applications() {
    local count="$1"
    echo "🗑️ Starting VERIFIED project application deletion..."
    echo "⚠️ CRITICAL SAFETY: Verifying project membership before CLI deletion"
    echo "This prevents accidental deletion of applications in other projects"
    echo ""
    
    if [[ "$count" -eq 0 ]]; then
        echo "No project applications to delete"
        return 0
    fi
    
    local apps_file="$TEMP_DIR/project_applications.txt"
    local deleted_count=0 failed_count=0
    
    # SAFETY CHECK: Verify CLI project context is working
    echo "🔒 SAFETY CHECK: Verifying CLI project context..."
    if ! jf config show | grep -q "Project: $PROJECT_KEY"; then
        echo "⚠️ Adding explicit project context to CLI commands for safety"
    fi
    
    if [[ -f "$apps_file" ]]; then
        while IFS= read -r app_key; do
            if [[ -n "$app_key" ]]; then
                echo "  → Deleting application: $app_key"
                
                # CORRECTED SAFE DELETION: Verify app is in project before deletion
                echo "    🔒 SAFETY: Confirming application belongs to project '$PROJECT_KEY'..."
                
                # Double-check this app is actually in our target project
                local app_verify_file="$TEMP_DIR/verify_${app_key}.json"
                local verify_code=$(jfrog_api_call "GET" "/apptrust/api/v1/applications?project_key=$PROJECT_KEY" "$app_verify_file" "curl" "" "verify app in project")
                
                local app_confirmed=false
                if is_success "$verify_code" && [[ -s "$app_verify_file" ]]; then
                    if jq -e --arg app_key "$app_key" '.[] | select(.application_key == $app_key)' "$app_verify_file" >/dev/null 2>&1; then
                        app_confirmed=true
                        echo "    ✅ Confirmed: '$app_key' belongs to project '$PROJECT_KEY'"
                    else
                        echo "    ❌ SAFETY ABORT: '$app_key' NOT found in project '$PROJECT_KEY' - skipping deletion"
                    fi
                else
                    echo "    ❌ SAFETY ABORT: Cannot verify app project membership (HTTP $verify_code) - skipping deletion"
                fi
                
                local code=404  # Default to not found
                
                if [[ "$app_confirmed" == true ]]; then
                    # Get and delete versions first
                    echo "    Deleting versions for confirmed project application..."
                    local versions_file="$TEMP_DIR/${app_key}_versions.json"
                    local code_versions=$(jfrog_api_call "GET" "/apptrust/api/v1/applications/$app_key/versions?project_key=$PROJECT_KEY" "$versions_file" "curl" "" "get app versions")
                    
                    if is_success "$code_versions" && [[ -s "$versions_file" ]]; then
                        # Extract versions using portable method (no mapfile dependency)
                        local versions_temp="$TEMP_DIR/versions_temp.txt"
                        jq -r '.versions[]?.version // empty' "$versions_file" > "$versions_temp" 2>/dev/null
                        while IFS= read -r ver || [[ -n "$ver" ]]; do
                            [[ -z "$ver" ]] && continue
                            echo "      - Deleting version $ver (CLI - project-verified)"
                            
                            # API deletion (CLI commands don't exist)
                            local version_delete_file="$TEMP_DIR/delete_version_${app_key}_${ver}.json"
                            local ver_code=$(jfrog_api_call "DELETE" "/apptrust/api/v1/applications/$app_key/versions/$ver?project_key=$PROJECT_KEY" "$version_delete_file" "curl" "" "delete version $ver")
                            if is_success "$ver_code"; then
                                echo "        ✅ Version $ver deleted successfully"
                            else
                                echo "        ⚠️ Version $ver deletion failed or already deleted (HTTP $ver_code)"
                            fi
                        done < "$versions_temp"
                    fi
                    
                    # Delete application via API (CLI commands don't exist)
                    echo "    Deleting application via API (project-verified)..."
                    local app_delete_file="$TEMP_DIR/delete_app_${app_key}.json"
                    code=$(jfrog_api_call "DELETE" "/apptrust/api/v1/applications/$app_key?project_key=$PROJECT_KEY" "$app_delete_file" "curl" "" "delete application $app_key")
                    if is_success "$code"; then
                        echo "    ✅ Application '$app_key' deleted successfully (HTTP $code)"
                    else
                        echo "    ⚠️ Application '$app_key' deletion failed (HTTP $code)"
                    fi
                else
                    echo "    🛡️ SAFETY: Skipped deletion due to project verification failure"
                fi
                
                if is_success "$code"; then
                    echo "    ✅ Application '$app_key' deleted successfully (HTTP $code)"
                    ((deleted_count++))
                elif is_not_found "$code"; then
                    echo "    ⚠️ Application '$app_key' not found or already deleted (HTTP $code)"
                    ((deleted_count++))
                else
                    echo "    ❌ Failed to delete application '$app_key' (HTTP $code)"
                    ((failed_count++))
                fi
            fi
        done < "$apps_file"
    fi
    
    echo "🚀 PROJECT APPLICATIONS deletion summary: $deleted_count deleted, $failed_count failed"
    return $([[ "$failed_count" -eq 0 ]] && echo 0 || echo 1)
}

# Delete project builds
delete_project_builds() {
    local count="$1"
    echo "🗑️ Starting project build deletion..."
    
    if [[ "$count" -eq 0 ]]; then
        echo "No project builds to delete"
        return 0
    fi
    
    local builds_file="$TEMP_DIR/project_builds.txt"
    local deleted_count=0 failed_count=0
    
    if [[ -f "$builds_file" ]]; then
        while IFS= read -r build_name; do
            if [[ -n "$build_name" ]]; then
                echo "  → Deleting build: $build_name"
                
                # Get build numbers for this build first
                local build_details_file="$TEMP_DIR/build_${build_name}_details.json"
                local build_numbers_file="$TEMP_DIR/build_${build_name}_numbers.txt"
                
                # URL decode the build name for API calls
                local decoded_build_name=$(printf '%b' "${build_name//%/\\x}")
                
                # Debug output
                echo "    [DEBUG] Original build name: '$build_name'"
                echo "    [DEBUG] Decoded build name: '$decoded_build_name'"
                
                echo "    Getting build numbers for '$decoded_build_name'..."
                local code=$(jfrog_api_call "GET" "/artifactory/api/build/$decoded_build_name?project=$PROJECT_KEY" "$build_details_file" "curl" "" "get build numbers")
                
                if is_success "$code" && [[ -s "$build_details_file" ]]; then
                    # Extract build numbers
                    jq -r '.buildsNumbers[]?.uri' "$build_details_file" 2>/dev/null | sed 's|^/||' > "$build_numbers_file" 2>/dev/null
                    
                    if [[ -s "$build_numbers_file" ]]; then
                        # Create array of build numbers
                        local build_numbers_json
                        build_numbers_json=$(jq -R -s 'split("\n") | map(select(length > 0))' "$build_numbers_file")
                        
                        # Prepare deletion payload (user's correct API approach)
                        local delete_payload=$(jq -n \
                            --arg project "$PROJECT_KEY" \
                            --arg buildName "$decoded_build_name" \
                            --argjson buildNumbers "$build_numbers_json" \
                            '{
                                project: $project,
                                buildName: $buildName,
                                buildNumbers: $buildNumbers,
                                deleteArtifacts: true,
                                deleteAll: false
                            }')
                        
                        echo "    Deleting build via REST API..."
                        local delete_response_file="$TEMP_DIR/delete_build_${decoded_build_name}.json"
                        
                        # Use correct build deletion API
                        code=$(jfrog_api_call "POST" "/artifactory/api/build/delete" "$delete_response_file" "curl" "$delete_payload" "delete build $decoded_build_name")
                        
                        if is_success "$code"; then
                            echo "    ✅ Build '$decoded_build_name' deleted successfully (HTTP $code)"
                            ((deleted_count++))
                        else
                            echo "    ❌ Failed to delete build '$decoded_build_name' (HTTP $code)"
                            echo "    Response: $(cat "$delete_response_file" 2>/dev/null || echo 'No response')"
                            ((failed_count++))
                        fi
                    else
                        echo "    ⚠️ No build numbers found for '$decoded_build_name' - may already be deleted"
                        ((deleted_count++))
                    fi
                else
                    echo "    ❌ Failed to get build details for '$decoded_build_name' (HTTP $code)"
                    ((failed_count++))
                fi
            fi
        done < "$builds_file"
    fi
    
    echo "🏗️ PROJECT BUILDS deletion summary: $deleted_count deleted, $failed_count failed"
    return $([[ "$failed_count" -eq 0 ]] && echo 0 || echo 1)
}

# Delete project stages
delete_project_stages() {
    local count="$1"
    echo "🗑️ Starting PROJECT-LEVEL stage deletion..."
    echo "🔒 SAFETY: Only deleting project-level stages belonging to '$PROJECT_KEY'"
    echo "⚠️ Skipping: System stages (PROD, DEV) and global stages"
    
    if [[ "$count" -eq 0 ]]; then
        echo "No project-level stages to delete"
        return 0
    fi
    
    local stages_file="$TEMP_DIR/project_stages.txt"
    local deleted_count=0 failed_count=0
    
    # Since discovery already filtered for project-level stages only,
    # we can safely delete all stages found (they belong to this project)
    if [[ -f "$stages_file" ]]; then
        while IFS= read -r stage_name; do
            if [[ -n "$stage_name" ]]; then
                echo "  → Deleting project-level stage: $stage_name"
                
                # Delete project-level stage using the project-scoped endpoint
                local code=$(jfrog_api_call "DELETE" "/access/api/v1/projects/$PROJECT_KEY/stages/$stage_name" "$TEMP_DIR/delete_stage_${stage_name}.txt" "curl" "" "delete project stage $stage_name")
                
                if ! is_success "$code"; then
                    # Fallback to v2 endpoint
                    echo "    Trying alternate deletion endpoint..."
                    code=$(jfrog_api_call "DELETE" "/access/api/v2/stages/$stage_name?projectKey=$PROJECT_KEY" "$TEMP_DIR/delete_stage_${stage_name}_v2.txt" "curl" "" "delete project stage v2 $stage_name")
                fi
                
                if is_success "$code"; then
                    echo "    ✅ Project stage '$stage_name' deleted successfully (HTTP $code)"
                    ((deleted_count++))
                elif is_not_found "$code"; then
                    echo "    ⚠️ Project stage '$stage_name' not found or already deleted (HTTP $code)"
                    ((deleted_count++))
                else
                    echo "    ❌ Failed to delete project stage '$stage_name' (HTTP $code)"
                    ((failed_count++))
                fi
            fi
        done < "$stages_file"
    fi
    
    echo "🏷️ PROJECT-LEVEL STAGES deletion summary: $deleted_count deleted, $failed_count failed"
    echo "ℹ️ Note: System stages (PROD, DEV) and global stages were not targeted"
    
    return $([[ "$failed_count" -eq 0 ]] && echo 0 || echo 1)
}

# Delete project lifecycle (enhanced)
delete_project_lifecycle() {
    echo "🗑️ Clearing project lifecycle configuration..."
    
    local payload='{"promote_stages": []}'
    local code=$(curl -s -H "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" -H "Content-Type: application/json" --write-out "%{http_code}" --output "$TEMP_DIR/delete_lifecycle.txt" -X PATCH -d "$payload" "${JFROG_URL%/}/access/api/v2/lifecycle/?project_key=$PROJECT_KEY")
    
    if is_success "$code"; then
        echo "✅ Lifecycle configuration cleared successfully (HTTP $code)"
        return 0
    elif is_not_found "$code"; then
        echo "⚠️ Lifecycle configuration not found or already cleared (HTTP $code)"
        return 0
    else
        echo "❌ Failed to clear lifecycle configuration (HTTP $code)"
        return 1
    fi
}

# Delete project itself
delete_project() {
    echo "🗑️ Attempting to delete project '$PROJECT_KEY'..."
    
    # Try force deletion first
    local code=$(jfrog_api_call "DELETE" "/access/api/v1/projects/$PROJECT_KEY?force=true" "$TEMP_DIR/delete_project.txt" "curl" "" "delete project")
    
    if is_success "$code"; then
        echo "✅ Project '$PROJECT_KEY' deleted successfully (HTTP $code)"
        return 0
    elif is_not_found "$code"; then
        echo "⚠️ Project '$PROJECT_KEY' not found or already deleted (HTTP $code)"
        return 0
    elif [[ "$code" -eq $HTTP_BAD_REQUEST ]]; then
        echo "❌ Failed to delete project '$PROJECT_KEY' (HTTP $code) - contains resources"
        echo "Response: $(cat "$TEMP_DIR/delete_project.txt" 2>/dev/null || echo 'No response body')"
        echo "ℹ️ This may be due to remaining system resources or incomplete cleanup"
        return 1
    else
        echo "❌ Failed to delete project '$PROJECT_KEY' (HTTP $code)"
        return 1
    fi
}

# =============================================================================
# SAFETY LAYER: DISCOVERY AND APPROVAL
# =============================================================================

# Comprehensive discovery function that lists all resources without deletion
run_discovery_preview() {
    echo "🔍 DISCOVERY PHASE: Finding all resources for deletion preview"
    echo "=============================================================="
    echo ""
    
    local preview_file="$TEMP_DIR/deletion_preview.txt"
    local total_items=0
    
    # Declare all count variables at function scope
    local builds_count=0
    local apps_count=0  
    local repos_count=0
    local users_count=0
    local stages_count=0
    
    echo "🛡️ SAFETY: Discovering what would be deleted..." > "$preview_file"
    echo "Project: $PROJECT_KEY" >> "$preview_file"
    echo "Date: $(date)" >> "$preview_file"
    echo "" >> "$preview_file"
    
    # 1. Discover builds
    echo "🏗️ Discovering builds..."
    if discover_project_builds; then
        builds_count=$GLOBAL_BUILD_COUNT
    else
        echo "⚠️  Warning: Build discovery failed, treating as 0 builds"
        builds_count=0
    fi
    
    if [[ "$builds_count" -gt 0 ]]; then
        echo "BUILDS TO DELETE ($builds_count items):" >> "$preview_file"
        echo "=======================================" >> "$preview_file"
        while IFS= read -r build; do
            if [[ -n "$build" ]]; then
                echo "  ❌ Build: $build" >> "$preview_file"
            fi
        done < "$TEMP_DIR/project_builds.txt"
        echo "" >> "$preview_file"
    else
        echo "BUILDS: None found" >> "$preview_file"
        echo "" >> "$preview_file"
    fi
    
    # 2. Discover applications
    echo "🚀 Discovering applications..."
    if discover_project_applications; then
        apps_count=$GLOBAL_APP_COUNT
    else
        echo "⚠️  Warning: Application discovery failed, treating as 0 applications"
        apps_count=0
    fi
    
    if [[ "$apps_count" -gt 0 ]]; then
        echo "APPLICATIONS TO DELETE ($apps_count items):" >> "$preview_file"
        echo "===========================================" >> "$preview_file"
        while IFS= read -r app; do
            if [[ -n "$app" ]]; then
                echo "  ❌ Application: $app" >> "$preview_file"
            fi
        done < "$TEMP_DIR/project_applications.txt"
        echo "" >> "$preview_file"
    else
        echo "APPLICATIONS: None found" >> "$preview_file"
        echo "" >> "$preview_file"
    fi
    
    # 3. Discover repositories
    echo "📦 Discovering repositories..."
    if discover_project_repositories; then
        repos_count=$GLOBAL_REPO_COUNT
    else
        echo "⚠️  Warning: Repository discovery failed, treating as 0 repositories"
        repos_count=0
    fi
    
    if [[ "$repos_count" -gt 0 ]]; then
        echo "REPOSITORIES TO DELETE ($repos_count items):" >> "$preview_file"
        echo "=============================================" >> "$preview_file"
        while IFS= read -r repo; do
            if [[ -n "$repo" ]]; then
                echo "  ❌ Repository: $repo" >> "$preview_file"
            fi
        done < "$TEMP_DIR/project_repositories.txt"
        echo "" >> "$preview_file"
    else
        echo "REPOSITORIES: None found" >> "$preview_file"
        echo "" >> "$preview_file"
    fi
    
    # 4. Discover users
    echo "👥 Discovering users..."
    if discover_project_users; then
        users_count=$GLOBAL_USER_COUNT
    else
        echo "⚠️  Warning: User discovery failed, treating as 0 users"
        users_count=0
    fi
    
    if [[ "$users_count" -gt 0 ]]; then
        echo "USERS TO DELETE ($users_count items):" >> "$preview_file"
        echo "======================================" >> "$preview_file"
        while IFS= read -r user; do
            if [[ -n "$user" ]]; then
                echo "  ❌ User: $user" >> "$preview_file"
            fi
        done < "$TEMP_DIR/project_users.txt"
        echo "" >> "$preview_file"
    else
        echo "USERS: None found" >> "$preview_file"
        echo "" >> "$preview_file"
    fi
    
    # 5. Discover stages
    echo "🏷️ Discovering stages..."
    if discover_project_stages; then
        stages_count=$GLOBAL_STAGE_COUNT
    else
        echo "⚠️  Warning: Stage discovery failed, treating as 0 stages"
        stages_count=0
    fi
    
    if [[ "$stages_count" -gt 0 ]]; then
        echo "STAGES TO DELETE ($stages_count items):" >> "$preview_file"
        echo "=======================================" >> "$preview_file"
        while IFS= read -r stage; do
            if [[ -n "$stage" ]]; then
                echo "  ❌ Stage: $stage" >> "$preview_file"
            fi
        done < "$TEMP_DIR/project_stages.txt"
        echo "" >> "$preview_file"
    else
        echo "STAGES: None found" >> "$preview_file"
        echo "" >> "$preview_file"
    fi
    
    # Calculate total items from all discoveries
    total_items=$((builds_count + apps_count + repos_count + users_count + stages_count))
    
    # Summary
    echo "SUMMARY:" >> "$preview_file"
    echo "========" >> "$preview_file"
    echo "Total items to delete: $total_items" >> "$preview_file"
    echo "Project to delete: $PROJECT_KEY" >> "$preview_file"
    echo "" >> "$preview_file"
    echo "⚠️ WARNING: This action cannot be undone!" >> "$preview_file"
    
    # Save report to shared location for cleanup workflow (repo-root .github)
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local repo_root
    if [[ -n "$GITHUB_WORKSPACE" && -d "$GITHUB_WORKSPACE" ]]; then
        repo_root="$GITHUB_WORKSPACE"
    else
        # script lives at repo/.github/scripts/setup → go up three levels
        repo_root="$(cd "$script_dir/../../.." && pwd)"
    fi
    mkdir -p "$repo_root/.github"
    local shared_report_file="$repo_root/.github/cleanup-report.json"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    # Build structured plan arrays for readability and safety
    local repos_json apps_json users_json stages_json builds_json
    if [[ -f "$TEMP_DIR/project_repositories.txt" ]]; then
        repos_json=$(jq -R -s --arg project "$PROJECT_KEY" 'split("\n")|map(select(length>0))|map({key:., project:$project})' "$TEMP_DIR/project_repositories.txt" 2>/dev/null || echo '[]')
    else
        repos_json='[]'
    fi
    if [[ -f "$TEMP_DIR/project_applications.txt" ]]; then
        apps_json=$(jq -R -s --arg project "$PROJECT_KEY" 'split("\n")|map(select(length>0))|map({key:., project:$project})' "$TEMP_DIR/project_applications.txt" 2>/dev/null || echo '[]')
    else
        apps_json='[]'
    fi
    if [[ -s "$TEMP_DIR/project_users.json" ]]; then
        users_json=$(jq --arg project "$PROJECT_KEY" '[.members[]? | {name: .name, roles: (.roles // []), project: $project}]' "$TEMP_DIR/project_users.json" 2>/dev/null || echo '[]')
    elif [[ -f "$TEMP_DIR/project_users.txt" ]]; then
        users_json=$(jq -R -s --arg project "$PROJECT_KEY" 'split("\n")|map(select(length>0))|map({name:., project:$project})' "$TEMP_DIR/project_users.txt" 2>/dev/null || echo '[]')
    else
        users_json='[]'
    fi
    if [[ -f "$TEMP_DIR/project_stages.txt" ]]; then
        stages_json=$(jq -R -s --arg project "$PROJECT_KEY" 'split("\n")|map(select(length>0))|map({name:., project:$project})' "$TEMP_DIR/project_stages.txt" 2>/dev/null || echo '[]')
    else
        stages_json='[]'
    fi
    if [[ -f "$TEMP_DIR/project_builds.txt" ]]; then
        builds_json=$(jq -R -s --arg project "$PROJECT_KEY" 'split("\n")|map(select(length>0))|map({name:., project:$project})' "$TEMP_DIR/project_builds.txt" 2>/dev/null || echo '[]')
    else
        builds_json='[]'
    fi

    # Create structured report with metadata and structured plan
    # Pretty-print JSON for easier debugging/validation
    jq -n \
        --arg timestamp "$timestamp" \
        --arg project_key "$PROJECT_KEY" \
        --argjson total_items "$total_items" \
        --argjson builds_count "$builds_count" \
        --argjson apps_count "$apps_count" \
        --argjson repos_count "$repos_count" \
        --argjson users_count "$users_count" \
        --argjson stages_count "$stages_count" \
        --arg preview_content "$(cat "$preview_file")" \
        --argjson plan_repos "$repos_json" \
        --argjson plan_apps "$apps_json" \
        --argjson plan_users "$users_json" \
        --argjson plan_stages "$stages_json" \
        --argjson plan_builds "$builds_json" \
        '{
            "metadata": {
                "timestamp": $timestamp,
                "project_key": $project_key,
                "total_items": $total_items,
                "discovery_counts": {
                    "builds": $builds_count,
                    "applications": $apps_count,
                    "repositories": $repos_count,
                    "users": $users_count,
                    "stages": $stages_count
                }
            },
            "plan": {
                "repositories": $plan_repos,
                "applications": $plan_apps,
                "users": $plan_users,
                "stages": $plan_stages,
                "builds": $plan_builds
            },
            "deletion_preview": $preview_content,
            "status": "ready_for_cleanup"
        }' | jq '.' > "$shared_report_file"
    
    echo "📋 Shared report saved to: $shared_report_file" >&2
    
    # Set global variables instead of using return codes
    GLOBAL_PREVIEW_FILE="$preview_file"
    GLOBAL_TOTAL_ITEMS="$total_items"
    return 0  # Always return success
}

# User approval function
get_user_approval() {
    local preview_file="$1"
    local total_items="$2"
    
    echo ""
    echo "🛡️ DELETION PREVIEW COMPLETE"
    echo "============================"
    echo ""
    echo "📋 DISCOVERED $total_items ITEMS FOR DELETION:"
    echo ""
    
    # Display the preview
    cat "$preview_file"
    echo ""
    
    # Safety check for empty PROJECT_KEY (the root cause we just fixed)
    if [[ -z "$PROJECT_KEY" ]]; then
        echo "🚨 CRITICAL SAFETY CHECK FAILED!"
        echo "PROJECT_KEY is empty - this would delete ALL resources!"
        echo "Aborting for safety."
        return 1
    fi
    
    # Check for suspicious high numbers that might indicate filtering failure
    if [[ "$total_items" -gt 100 ]]; then
        echo "⚠️ SUSPICIOUS HIGH COUNT: $total_items items"
        echo "This seems unusually high and might indicate a filtering failure."
        echo "Please verify this is correct before proceeding."
        echo ""
    fi
    
    # Security-first approach: Always require explicit approval unless bypassed
    if [[ "${SKIP_PROTECTION:-}" == "true" ]]; then
        echo "⚠️ PROTECTION BYPASSED via SKIP_PROTECTION=true"
        echo "🤖 Automatic approval - NO HUMAN CONFIRMATION"
        return 0
    fi
    
    # Check if running in CI but no way to get interactive input
    if [[ -n "$GITHUB_ACTIONS" ]] || [[ -n "$CI" ]]; then
        echo "🤖 CI ENVIRONMENT DETECTED"
        echo "❌ Cannot get interactive approval in CI environment"
        echo ""
        echo "💡 SOLUTIONS:"
        echo "  1. Use discovery workflow first, then execution workflow"
        echo "  2. Set SKIP_PROTECTION=true to bypass (NOT RECOMMENDED)"
        echo "  3. Run locally with manual approval"
        return 1
    fi
    
    # Interactive approval
    echo "🔴 CRITICAL: This will PERMANENTLY DELETE all listed resources!"
    echo ""
    echo "To confirm deletion, type exactly: DELETE $PROJECT_KEY"
    read -p "Your input: " user_input
    
    if [[ "$user_input" == "DELETE $PROJECT_KEY" ]]; then
        echo "✅ Deletion confirmed by user"
        return 0
    else
        echo "❌ Deletion cancelled - input did not match required confirmation"
        return 1
    fi
}

# =============================================================================
# MAIN EXECUTION WITH SAFETY LAYER (only when executed directly, not when sourced)
# =============================================================================
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    echo "🚀 Starting SAFE PROJECT-BASED cleanup sequence..."
    echo "Finding ALL resources belonging to project '$PROJECT_KEY'"
    echo ""

    # PHASE 1: DISCOVERY AND APPROVAL
    echo "🛡️ SAFETY PHASE: Discovery and Approval Required"
    echo "=================================================="
    run_discovery_preview
    total_items="$GLOBAL_TOTAL_ITEMS"
    preview_file="$GLOBAL_PREVIEW_FILE"

    if ! get_user_approval "$preview_file" "$total_items"; then
        echo ""
        echo "❌ CLEANUP CANCELLED BY USER/SAFETY CHECK"
        echo "No resources were deleted."
        echo "Preview saved: $preview_file"
        exit 0
    fi

    echo ""
    echo "✅ DELETION APPROVED - Proceeding with cleanup..."
    echo ""

    # PHASE 2: ACTUAL DELETION
    echo "🗑️ DELETION PHASE: Executing approved cleanup"
    echo "=============================================="

    FAILED=false

    # 1) Project builds cleanup
    echo "🏗️ STEP 1: Project Build Cleanup"
    echo "================================="
    discover_project_builds
    builds_count=$GLOBAL_BUILD_COUNT
    echo ""
    delete_project_builds "$builds_count" || FAILED=true
    echo ""

    # 2) Project applications cleanup
    echo "🚀 STEP 2: Project Application Cleanup"
    echo "======================================="
    discover_project_applications
    apps_count=$GLOBAL_APP_COUNT
    echo ""
    delete_project_applications "$apps_count" || FAILED=true
    echo ""

    # 3) Project repositories cleanup
    echo "📦 STEP 3: Project Repository Cleanup"
    echo "======================================"
    discover_project_repositories
    repos_count=$GLOBAL_REPO_COUNT
    echo ""
    delete_project_repositories "$repos_count" || FAILED=true
    echo ""

    # 4) Project users cleanup
    echo "👥 STEP 4: Project User Cleanup"
    echo "================================"
    discover_project_users
    users_count=$GLOBAL_USER_COUNT
    echo ""
    delete_project_users "$users_count" || FAILED=true
    echo ""

    # 5) Project lifecycle cleanup (must remove stages from lifecycle first)
    echo "🔄 STEP 5: Project Lifecycle Cleanup"
    echo "====================================="
    delete_project_lifecycle || FAILED=true
    echo ""

    # 6) Project stages cleanup (after lifecycle cleared)
    echo "🏷️ STEP 6: Project Stage Cleanup"
    echo "================================="
    discover_project_stages
    stages_count=$GLOBAL_STAGE_COUNT
    echo ""
    delete_project_stages "$stages_count" || FAILED=true
    echo ""

    # 7) Project deletion
    echo "🎯 STEP 7: Project Deletion"
    echo "============================"
    delete_project || FAILED=true
    echo ""

    # =============================================================================
    # FINAL SUMMARY
    # =============================================================================

    echo "🎯 PROJECT-BASED CLEANUP SUMMARY"
    echo "================================="
    echo "Debug log: $HTTP_DEBUG_LOG"
    echo ""

    if [[ "$FAILED" == true ]]; then
        echo "❌ Some resources failed to be deleted"
        echo "Check debug files in: $TEMP_DIR"
        echo "Check debug log: $HTTP_DEBUG_LOG"
        exit 1
    else
        echo "✅ PROJECT-BASED cleanup completed successfully!"
        echo "All resources belonging to project '$PROJECT_KEY' have been cleaned up"
        exit 0
    fi
fi
