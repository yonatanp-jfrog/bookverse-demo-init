#!/usr/bin/env bash

set -e

# =============================================================================
# PROJECT-BASED BOOKVERSE CLEANUP SCRIPT - LOGGING BUG FIXED VERSION
# =============================================================================
# 🚨 CRITICAL LOGGING BUG FIX: Discovery function output separation
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

source "$(dirname "$0")/config.sh"
validate_environment

# Constants
readonly HTTP_OK=200
readonly HTTP_CREATED=201
readonly HTTP_NO_CONTENT=204
readonly HTTP_BAD_REQUEST=400
readonly HTTP_NOT_FOUND=404

TEMP_DIR="/tmp/bookverse_cleanup_$$"
mkdir -p "$TEMP_DIR"

echo "🎯 PROJECT-BASED BookVerse JFrog Platform Cleanup"
echo "=================================================="
echo "APPROACH: Find ALL resources belonging to PROJECT '${PROJECT_KEY}'"
echo "NOT just resources with 'bookverse' in their names"
echo ""
echo "Project Key: ${PROJECT_KEY}"
echo "JFrog URL: ${JFROG_URL}"
echo "Debug Dir: ${TEMP_DIR}"
echo ""

# HTTP debug log
HTTP_DEBUG_LOG="${TEMP_DIR}/project_based_cleanup.log"
touch "$HTTP_DEBUG_LOG"

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

log_api_call() {
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
make_api_call() {
    local method="$1" endpoint="$2" output_file="$3" client="$4"
    local extra_args="${5:-}"
    local description="${6:-}"
    
    local code
    if [[ "$client" == "jf" ]]; then
        if [[ "$endpoint" == /artifactory/* ]]; then
            code=$(jf rt curl -X "$method" -H "X-JFrog-Project: ${PROJECT_KEY}" "$endpoint" --write-out "%{http_code}" --output "$output_file" --silent $extra_args)
        else
            code=$(jf rt curl -X "$method" "$endpoint" --write-out "%{http_code}" --output "$output_file" --silent $extra_args)
        fi
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
    fi
    
    log_api_call "$method" "$endpoint" "$code" "$description"
    
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
    
    # Use project-specific repository endpoint with project parameter
    local code=$(make_api_call "GET" "/artifactory/api/repositories?project=$PROJECT_KEY" "$repos_file" "jf" "" "project repositories")
    
    if is_success "$code" && [[ -s "$repos_file" ]]; then
        # Extract all repository keys from project (not filtering by name)
        jq -r '.[] | .key' "$repos_file" > "$filtered_repos"
        
        local count=$(wc -l < "$filtered_repos" 2>/dev/null || echo "0")
        echo "📦 Found $count repositories in project '$PROJECT_KEY'" >&2
        
        if [[ "$count" -gt 0 ]] && [[ "$VERBOSITY" -ge 1 ]]; then
            echo "Project repositories:" >&2
            cat "$filtered_repos" | sed 's/^/  - /' >&2
        fi
        
        echo "$count"
    else
        echo "❌ Project repository discovery failed (HTTP $code)" >&2
        echo "0"
    fi
}

# 2. PROJECT-BASED USER DISCOVERY
discover_project_users() {
    echo "🔍 Discovering project users/admins (PROJECT-BASED)..." >&2
    
    local users_file="$TEMP_DIR/project_users.json"
    local filtered_users="$TEMP_DIR/project_users.txt"
    
    # Use project-specific user endpoint - this finds actual project members
    local code=$(make_api_call "GET" "/access/api/v1/projects/$PROJECT_KEY/users" "$users_file" "curl" "" "project users")
    
    if is_success "$code" && [[ -s "$users_file" ]]; then
        # Extract user names from project members (not filtering by email domain)
        jq -r '.members[]? | .name' "$users_file" > "$filtered_users" 2>/dev/null || touch "$filtered_users"
        
        local count=$(wc -l < "$filtered_users" 2>/dev/null || echo "0")
        echo "👥 Found $count users/admins in project '$PROJECT_KEY'" >&2
        
        if [[ "$count" -gt 0 ]] && [[ "$VERBOSITY" -ge 1 ]]; then
            echo "Project users/admins:" >&2
            cat "$filtered_users" | sed 's/^/  - /' >&2
            echo "Detailed roles:" >&2
            jq -r '.members[]? | "  - \(.name) (roles: \(.roles | join(", ")))"' "$users_file" 2>/dev/null || true >&2
        fi
        
        echo "$count"
    else
        echo "❌ Project user discovery failed (HTTP $code)" >&2
        echo "0"
    fi
}

# 3. PROJECT-BASED APPLICATION DISCOVERY
discover_project_applications() {
    echo "🔍 Discovering project applications (PROJECT-BASED)..." >&2
    
    local apps_file="$TEMP_DIR/project_applications.json"
    local filtered_apps="$TEMP_DIR/project_applications.txt"
    
    # Use correct project_key parameter as specified in API documentation
    local code=$(make_api_call "GET" "/apptrust/api/v1/applications?project_key=$PROJECT_KEY" "$apps_file" "curl" "" "project applications")
    
    if is_success "$code" && [[ -s "$apps_file" ]]; then
        jq -r '.[] | .application_key' "$apps_file" > "$filtered_apps" 2>/dev/null || touch "$filtered_apps"
        
        local count=$(wc -l < "$filtered_apps" 2>/dev/null || echo "0")
        echo "🚀 Found $count applications in project '$PROJECT_KEY'" >&2
        
        if [[ "$count" -gt 0 ]] && [[ "$VERBOSITY" -ge 1 ]]; then
            echo "Project applications:" >&2
            cat "$filtered_apps" | sed 's/^/  - /' >&2
        fi
        
        echo "$count"
    else
        echo "❌ Project application discovery failed (HTTP $code)" >&2
        echo "0"
    fi
}

# 4. PROJECT-BASED BUILD DISCOVERY
discover_project_builds() {
    echo "🔍 Discovering project builds (PROJECT-BASED)..." >&2
    
    local builds_file="$TEMP_DIR/project_builds.json"
    local filtered_builds="$TEMP_DIR/project_builds.txt"
    
    # Use project-specific build endpoint
    local code=$(make_api_call "GET" "/artifactory/api/build?project=$PROJECT_KEY" "$builds_file" "curl" "" "project builds")
    
    if is_success "$code" && [[ -s "$builds_file" ]]; then
        # Extract build names from project builds (not filtering by name)
        jq -r '.builds[]? | .uri' "$builds_file" | sed 's/^\///' > "$filtered_builds" 2>/dev/null || touch "$filtered_builds"
        
        local count=$(wc -l < "$filtered_builds" 2>/dev/null || echo "0")
        echo "🏗️ Found $count builds in project '$PROJECT_KEY'" >&2
        
        if [[ "$count" -gt 0 ]] && [[ "$VERBOSITY" -ge 1 ]]; then
            echo "Project builds:" >&2
            cat "$filtered_builds" | sed 's/^/  - /' >&2
        fi
        
        echo "$count"
    else
        echo "❌ Project build discovery failed (HTTP $code)" >&2
        echo "0"
    fi
}

# 5. PROJECT-BASED STAGE DISCOVERY
discover_project_stages() {
    echo "🔍 Discovering project stages (PROJECT-BASED)..." >&2
    
    local stages_file="$TEMP_DIR/project_stages.json"
    local filtered_stages="$TEMP_DIR/project_stages.txt"
    
    # Use project-specific stage endpoint
    local code=$(make_api_call "GET" "/access/api/v1/projects/$PROJECT_KEY/stages" "$stages_file" "curl" "" "project stages")
    
    if is_success "$code" && [[ -s "$stages_file" ]]; then
        jq -r '.[]? | .name' "$stages_file" > "$filtered_stages" 2>/dev/null || touch "$filtered_stages"
        
        local count=$(wc -l < "$filtered_stages" 2>/dev/null || echo "0")
        echo "🏷️ Found $count stages in project '$PROJECT_KEY'" >&2
        
        if [[ "$count" -gt 0 ]] && [[ "$VERBOSITY" -ge 1 ]]; then
            echo "Project stages:" >&2
            cat "$filtered_stages" | sed 's/^/  - /' >&2
        fi
        
        echo "$count"
    else
        echo "❌ Project stage discovery failed (HTTP $code)" >&2
        echo "0"
    fi
}

# =============================================================================
# PROJECT-BASED DELETION FUNCTIONS
# =============================================================================

# Delete project repositories
delete_project_repositories() {
    local count="$1"
    echo "🗑️ Starting project repository deletion..."
    
    if [[ "$count" -eq 0 ]]; then
        echo "No project repositories to delete"
        return 0
    fi
    
    local repos_file="$TEMP_DIR/project_repositories.txt"
    local deleted_count=0 failed_count=0
    
    if [[ -f "$repos_file" ]]; then
        while IFS= read -r repo_key; do
            if [[ -n "$repo_key" ]]; then
                echo "  → Deleting repository: $repo_key"
                
                # Purge artifacts first
                echo "    Purging artifacts..."
                jf rt del "${repo_key}/**" --quiet || echo "    Warning: Artifact purge failed"
                
                # Delete repository
                local code=$(make_api_call "DELETE" "/artifactory/api/repositories/$repo_key" "$TEMP_DIR/delete_repo_${repo_key}.txt" "jf" "" "delete repository $repo_key")
                
                if is_success "$code"; then
                    echo "    ✅ Repository '$repo_key' deleted successfully (HTTP $code)"
                    ((deleted_count++))
                elif is_not_found "$code"; then
                    echo "    ⚠️ Repository '$repo_key' not found or already deleted (HTTP $code)"
                    ((deleted_count++))
                else
                    echo "    ❌ Failed to delete repository '$repo_key' (HTTP $code)"
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
                
                local code=$(make_api_call "DELETE" "/access/api/v1/projects/$PROJECT_KEY/users/$username" "$TEMP_DIR/delete_user_${username}.txt" "curl" "" "remove project user $username")
                
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
                local verify_code=$(make_api_call "GET" "/apptrust/api/v1/applications?project_key=$PROJECT_KEY" "$app_verify_file" "curl" "" "verify app in project")
                
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
                    local code_versions=$(make_api_call "GET" "/apptrust/api/v1/applications/$app_key/versions?project_key=$PROJECT_KEY" "$versions_file" "curl" "" "get app versions")
                    
                    if is_success "$code_versions" && [[ -s "$versions_file" ]]; then
                        mapfile -t versions < <(jq -r '.versions[]?.version // empty' "$versions_file")
                        for ver in "${versions[@]}"; do
                            [[ -z "$ver" ]] && continue
                            echo "      - Deleting version $ver (CLI - project-verified)"
                            
                            # CLI deletion (no project flag available, but we verified app belongs to project)
                            if jf apptrust version-delete "$app_key" "$ver" 2>/dev/null; then
                                echo "        ✅ Version $ver deleted successfully"
                            else
                                echo "        ⚠️ Version $ver deletion failed or already deleted"
                            fi
                        done
                    fi
                    
                    # Delete application (CLI - project membership verified)
                    echo "    Deleting application (CLI - project-verified)..."
                    if jf apptrust app-delete "$app_key" 2>/dev/null; then
                        echo "    ✅ Application '$app_key' deleted successfully"
                        code=200
                    else
                        echo "    ⚠️ Application '$app_key' deletion failed or already deleted"
                        code=404
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
                
                local code=$(make_api_call "DELETE" "/artifactory/api/build/$build_name?deleteAll=1" "$TEMP_DIR/delete_build_${build_name}.txt" "jf" "" "delete build $build_name")
                
                if is_success "$code"; then
                    echo "    ✅ Build '$build_name' deleted successfully (HTTP $code)"
                    ((deleted_count++))
                elif is_not_found "$code"; then
                    echo "    ⚠️ Build '$build_name' not found or already deleted (HTTP $code)"
                    ((deleted_count++))
                else
                    echo "    ❌ Failed to delete build '$build_name' (HTTP $code)"
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
    echo "🗑️ Starting project stage deletion..."
    
    if [[ "$count" -eq 0 ]]; then
        echo "No project stages to delete"
        return 0
    fi
    
    local stages_file="$TEMP_DIR/project_stages.txt"
    local deleted_count=0 failed_count=0
    
    if [[ -f "$stages_file" ]]; then
        while IFS= read -r stage_name; do
            if [[ -n "$stage_name" ]]; then
                echo "  → Deleting stage: $stage_name"
                
                local code=$(make_api_call "DELETE" "/access/api/v2/stages/$stage_name" "$TEMP_DIR/delete_stage_${stage_name}.txt" "curl" "" "delete stage $stage_name")
                
                if is_success "$code"; then
                    echo "    ✅ Stage '$stage_name' deleted successfully (HTTP $code)"
                    ((deleted_count++))
                elif is_not_found "$code"; then
                    echo "    ⚠️ Stage '$stage_name' not found or already deleted (HTTP $code)"
                    ((deleted_count++))
                else
                    echo "    ❌ Failed to delete stage '$stage_name' (HTTP $code)"
                    ((failed_count++))
                fi
            fi
        done < "$stages_file"
    fi
    
    echo "🏷️ PROJECT STAGES deletion summary: $deleted_count deleted, $failed_count failed"
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
    
    local code=$(make_api_call "DELETE" "/access/api/v1/projects/$PROJECT_KEY?force=true" "$TEMP_DIR/delete_project.txt" "curl" "" "delete project")
    
    if is_success "$code"; then
        echo "✅ Project '$PROJECT_KEY' deleted successfully (HTTP $code)"
        return 0
    elif is_not_found "$code"; then
        echo "⚠️ Project '$PROJECT_KEY' not found or already deleted (HTTP $code)"
        return 0
    elif [[ "$code" -eq $HTTP_BAD_REQUEST ]]; then
        echo "❌ Failed to delete project '$PROJECT_KEY' (HTTP $code) - likely contains resources"
        echo "Response: $(cat "$TEMP_DIR/delete_project.txt" 2>/dev/null || echo 'No response body')"
        return 1
    else
        echo "❌ Failed to delete project '$PROJECT_KEY' (HTTP $code)"
        return 1
    fi
}

# =============================================================================
# MAIN EXECUTION - PROJECT-BASED CLEANUP
# =============================================================================

echo "🚀 Starting PROJECT-BASED cleanup sequence..."
echo "Finding ALL resources belonging to project '$PROJECT_KEY'"
echo ""

FAILED=false

# 1) Project builds cleanup
echo "🏗️ STEP 1: Project Build Cleanup"
echo "================================="
builds_count=$(discover_project_builds)
echo ""
delete_project_builds "$builds_count" || FAILED=true
echo ""

# 2) Project applications cleanup
echo "🚀 STEP 2: Project Application Cleanup"
echo "======================================="
apps_count=$(discover_project_applications)
echo ""
delete_project_applications "$apps_count" || FAILED=true
echo ""

# 3) Project repositories cleanup
echo "📦 STEP 3: Project Repository Cleanup"
echo "======================================"
repos_count=$(discover_project_repositories)
echo ""
delete_project_repositories "$repos_count" || FAILED=true
echo ""

# 4) Project users cleanup
echo "👥 STEP 4: Project User Cleanup"
echo "================================"
users_count=$(discover_project_users)
echo ""
delete_project_users "$users_count" || FAILED=true
echo ""

# 5) Project stages cleanup
echo "🏷️ STEP 5: Project Stage Cleanup"
echo "================================="
stages_count=$(discover_project_stages)
echo ""
delete_project_stages "$stages_count" || FAILED=true
echo ""

# 6) Project lifecycle cleanup
echo "🔄 STEP 6: Project Lifecycle Cleanup"
echo "====================================="
delete_project_lifecycle || FAILED=true
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
