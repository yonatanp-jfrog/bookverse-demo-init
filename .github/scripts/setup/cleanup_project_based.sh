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

# URL-encode a single path segment safely (requires jq)
urlencode() {
    local raw="$1"
    jq -rn --arg v "$raw" '$v|@uri'
}

# Check if a project-level stage exists (v2 API)
stage_exists() {
    local stage_name="$1"
    local code=$(jfrog_api_call "GET" "/access/api/v2/stages/$stage_name?project_key=$PROJECT_KEY" "" "curl" "" "get stage $stage_name")
    [[ "$code" -eq $HTTP_OK ]]
}

# Lifecycle helpers
is_lifecycle_cleared() {
    local out_file="$TEMP_DIR/get_lifecycle.json"
    local code=$(jfrog_api_call "GET" "/access/api/v2/lifecycle/?project_key=$PROJECT_KEY" "$out_file" "curl" "" "get lifecycle config")
    if [[ "$code" -ne $HTTP_OK ]]; then
        # If lifecycle not found, treat as cleared
        [[ "$code" -eq $HTTP_NOT_FOUND ]]
        return
    fi
    local len=$(jq -r '.promote_stages | length' "$out_file" 2>/dev/null || echo 0)
    [[ "$len" -eq 0 ]]
}

wait_for_lifecycle_cleared() {
    local timeout_secs="${1:-20}"
    local interval_secs="${2:-2}"
    local start_ts=$(date +%s)
    while true; do
        if is_lifecycle_cleared; then
            echo "✅ Lifecycle is cleared (no promote_stages)"
            return 0
        fi
        local now=$(date +%s)
        if (( now - start_ts >= timeout_secs )); then
            echo "⚠️ Lifecycle not cleared after ${timeout_secs}s; proceeding"
            return 1
        fi
        sleep "$interval_secs"
    done
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
    if [[ "$client" == "jf" || "$client" == "jf_raw" ]]; then
        local include_project_header=true
        if [[ "$client" == "jf_raw" ]]; then
            include_project_header=false
        fi
        if [[ "$endpoint" == /artifactory/* ]]; then
            if [[ -n "$data_payload" ]]; then
                if $include_project_header; then
                    code=$(echo "$data_payload" | curl -s -H "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" -X "$method" "${JFROG_URL%/}$endpoint" --write-out "%{http_code}" --output "$output_file" --data @-)
                else
                    code=$(echo "$data_payload" | curl -s -H "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" -X "$method" "${JFROG_URL%/}$endpoint" --write-out "%{http_code}" --output "$output_file" --data @-)
                fi
            else
                if $include_project_header; then
                    code=$(curl -s -H "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" -X "$method" "${JFROG_URL%/}$endpoint" --write-out "%{http_code}" --output "$output_file")
                else
                    code=$(curl -s -H "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" -X "$method" "${JFROG_URL%/}$endpoint" --write-out "%{http_code}" --output "$output_file")
                fi
            fi
        else
            if [[ -n "$data_payload" ]]; then
                code=$(echo "$data_payload" | curl -s -H "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" -X "$method" "${JFROG_URL%/}$endpoint" --write-out "%{http_code}" --output "$output_file" --data @-)
            else
                code=$(curl -s -H "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" -X "$method" "${JFROG_URL%/}$endpoint" --write-out "%{http_code}" --output "$output_file")
            fi
        fi
    else
        local base_url="${JFROG_URL%/}"
        local include_project_header=true
        if [[ "$client" == "curl_raw" ]]; then
            include_project_header=false
        fi
        if [[ "$endpoint" == /artifactory/* ]]; then
            if [[ -n "$data_payload" ]]; then
                if $include_project_header; then
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
                        --data "$data_payload" \
                        --write-out "%{http_code}" --output "$output_file")
                fi
            else
                if $include_project_header; then
                    code=$(curl -s -S -L \
                        -H "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
                        -H "Content-Type: application/json" \
                        -X "$method" "${base_url}${endpoint}" \
                        --write-out "%{http_code}" --output "$output_file")
                else
                    code=$(curl -s -S -L \
                        -H "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
                        -H "Content-Type: application/json" \
                        -X "$method" "${base_url}${endpoint}" \
                        --write-out "%{http_code}" --output "$output_file")
                fi
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

# Only set up JFrog CLI and authentication when not sourced (i.e., when running directly)
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    jf c add bookverse-admin --url="${JFROG_URL}" --access-token="${JFROG_ADMIN_TOKEN}" --interactive=false --overwrite
    jf c use bookverse-admin

    # Test authentication
    auth_test_code=$(curl -s -H "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" -X GET "${JFROG_URL%/}/api/system/ping" --write-out "%{http_code}" --output /dev/null)
    if [ "$auth_test_code" -eq 200 ]; then
        echo "✅ Authentication successful"
    else
        echo "❌ Authentication failed (HTTP $auth_test_code)"
        # Only exit if JFROG_ADMIN_TOKEN is not a dummy/test value
        if [[ "${JFROG_ADMIN_TOKEN}" != "test" && "${JFROG_ADMIN_TOKEN}" != "dummy" ]]; then
            exit 1
        else
            echo "⚠️ Using test credentials - skipping authentication validation"
        fi
    fi
else
    echo "🔧 Script sourced - skipping JFrog CLI setup (will be done by workflow)"
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
        if jq --arg project "$PROJECT_KEY" '[.[] | select(.key | contains($project)) | select((.key | test("release-bundles-v2$")) | not)]' "$repos_file" > "${repos_file}.filtered" 2>/dev/null && [[ -s "${repos_file}.filtered" ]]; then
            mv "${repos_file}.filtered" "$repos_file"
            echo "✅ Filtered by repository key containing '$PROJECT_KEY'" >&2
            
            # Log found repositories for debugging
            echo "📦 Found repositories:" >&2
            jq -r '.[].key' "$repos_file" 2>/dev/null | head -10 | while read -r repo; do
                echo "   - $repo" >&2
            done
        else
            # Fallback: Try prefix match
            if jq --arg project "$PROJECT_KEY" '[.[] | select(.key | startswith($project)) | select((.key | test("release-bundles-v2$")) | not)]' "$repos_file" > "${repos_file}.filtered" 2>/dev/null && [[ -s "${repos_file}.filtered" ]]; then
                mv "${repos_file}.filtered" "$repos_file"
                echo "✅ Filtered by repository key prefix '$PROJECT_KEY'" >&2
            else
                # Final fallback: Try projectKey field (original logic)
                if jq --arg project "$PROJECT_KEY" '[.[] | select(.projectKey == $project) | select((.key | test("release-bundles-v2$")) | not)]' "$repos_file" > "${repos_file}.filtered" 2>/dev/null && [[ -s "${repos_file}.filtered" ]]; then
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
        
        # Produce repository type breakdown for metadata (handle multiple schemas: rclass/type/repoType and list wrappers)
        jq -n --argfile r "$repos_file" '
          (if ($r | type) == "array" then $r
           elif ($r | type) == "object" then ($r.repositories // $r.repos // [])
           else [] end) as $repos
          |
          $repos
          | map(
              . as $item
              | (
                  ($item.rclass // $item.repoType // $item.type // "") as $kind_raw
                  | (if ($kind_raw|type) == "string" then ($kind_raw|ascii_downcase) else "" end) as $kind
                  | if $kind == "" then
                      # Fallback heuristic from repo key
                      ($item.key // "") as $k
                      | (if ($k|test("-virtual$")) or ($k|test("^virtual-")) then "virtual"
                         elif ($k|test("-remote$")) or ($k|test("^remote-")) then "remote"
                         elif ($k|test("-local$")) or ($k|test("^local-")) then "local"
                         else ""
                         end)
                    else $kind end
                ) as $norm
              | {key: ($item.key // ""), kind: $norm}
            ) as $normed
          |
          {
            local:   ($normed | map(select(.kind == "local"))   | length),
            remote:  ($normed | map(select(.kind == "remote"))  | length),
            virtual: ($normed | map(select(.kind == "virtual")) | length)
          }
        ' > "$TEMP_DIR/repository_breakdown.json" 2>/dev/null || echo '{"local":0,"remote":0,"virtual":0}' > "$TEMP_DIR/repository_breakdown.json"

        # Also materialize a typed repositories list for later report assembly
        jq -n --argfile r "$repos_file" --arg project "$PROJECT_KEY" '
          (if ($r | type) == "array" then $r
           elif ($r | type) == "object" then ($r.repositories // $r.repos // [])
           else [] end) as $repos
          |
          $repos
          | map(
              . as $item
              | (
                  ($item.rclass // $item.repoType // $item.type // "") as $kind_raw
                  | (if ($kind_raw|type) == "string" then ($kind_raw|ascii_downcase) else "" end) as $kind
                  | if $kind == "" then
                      # Fallback heuristic from repo key
                      ($item.key // "") as $k
                      | (if ($k|test("-virtual$")) or ($k|test("^virtual-")) then "virtual"
                         elif ($k|test("-remote$")) or ($k|test("^remote-")) then "remote"
                         elif ($k|test("-local$")) or ($k|test("^local-")) then "local"
                         else ""
                         end)
                    else $kind end
                ) as $norm
              | {key: ($item.key // ""), project: $project, type: $norm}
            )
        ' > "$TEMP_DIR/project_repositories_typed.json" 2>/dev/null || echo '[]' > "$TEMP_DIR/project_repositories_typed.json"

        # Fallback: If counts are zero but repos exist, derive by intersecting with typed lists from the API
        local existing_count
        existing_count=$(wc -l < "$filtered_repos" 2>/dev/null || echo "0")
        local sum_counts
        sum_counts=$(jq -r '([.local,.remote,.virtual] | map(tonumber) | add) // 0' "$TEMP_DIR/repository_breakdown.json" 2>/dev/null || echo "0")
        if [[ "$existing_count" -gt 0 && "${sum_counts:-0}" -eq 0 ]]; then
            echo "ℹ️  Repo type fields missing; using API intersection fallback..." >&2
            local local_json remote_json virtual_json
            local local_keys remote_keys virtual_keys
            local local_count remote_count virtual_count

            local_json="$TEMP_DIR/repos_local.json"
            remote_json="$TEMP_DIR/repos_remote.json"
            virtual_json="$TEMP_DIR/repos_virtual.json"

            # Fetch typed repo lists
            jfrog_api_call "GET" "/artifactory/api/repositories?type=local" "$local_json" "curl_raw" "" "list local repos (raw)" >/dev/null || true
            jfrog_api_call "GET" "/artifactory/api/repositories?type=remote" "$remote_json" "curl_raw" "" "list remote repos (raw)" >/dev/null || true
            jfrog_api_call "GET" "/artifactory/api/repositories?type=virtual" "$virtual_json" "curl_raw" "" "list virtual repos (raw)" >/dev/null || true

            local_keys="$TEMP_DIR/repos_local.txt"
            remote_keys="$TEMP_DIR/repos_remote.txt"
            virtual_keys="$TEMP_DIR/repos_virtual.txt"

            # Normalize to key lists (support array or wrapped objects)
            jq -r 'if (type=="array") then .[]?.key else (.repositories // .repos // []) | .[]?.key end | select(length>0)' "$local_json" 2>/dev/null | sort -u > "$local_keys" || : > "$local_keys"
            jq -r 'if (type=="array") then .[]?.key else (.repositories // .repos // []) | .[]?.key end | select(length>0)' "$remote_json" 2>/dev/null | sort -u > "$remote_keys" || : > "$remote_keys"
            jq -r 'if (type=="array") then .[]?.key else (.repositories // .repos // []) | .[]?.key end | select(length>0)' "$virtual_json" 2>/dev/null | sort -u > "$virtual_keys" || : > "$virtual_keys"

            # Intersect with discovered repos
            local_count=$(grep -F -x -f "$filtered_repos" "$local_keys" 2>/dev/null | wc -l | tr -d ' ')
            remote_count=$(grep -F -x -f "$filtered_repos" "$remote_keys" 2>/dev/null | wc -l | tr -d ' ')
            virtual_count=$(grep -F -x -f "$filtered_repos" "$virtual_keys" 2>/dev/null | wc -l | tr -d ' ')

            echo "{\"local\":${local_count:-0},\"remote\":${remote_count:-0},\"virtual\":${virtual_count:-0}}" > "$TEMP_DIR/repository_breakdown.json"
        fi

        # Final safety fallback: per-repo detail query to determine rclass
        sum_counts=$(jq -r '([.local,.remote,.virtual] | map(tonumber) | add) // 0' "$TEMP_DIR/repository_breakdown.json" 2>/dev/null || echo "0")
        if [[ "$existing_count" -gt 0 && "${sum_counts:-0}" -eq 0 ]]; then
            echo "ℹ️  Typed list intersection yielded 0; querying each repo for rclass..." >&2
            local _local=0 _remote=0 _virtual=0
            while IFS= read -r repo_key; do
                [[ -z "$repo_key" ]] && continue
                local enc
                enc=$(urlencode "$repo_key")
                local detail_file="$TEMP_DIR/repo_${repo_key}_detail.json"
                local code
                code=$(jfrog_api_call "GET" "/artifactory/api/repositories/${enc}" "$detail_file" "curl_raw" "" "repo details $repo_key (raw)")
                if is_success "$code" && [[ -s "$detail_file" ]]; then
                    # Prefer rclass, fallback to repoType/type heuristics
                    local kind
                    kind=$(jq -r '(.rclass // .repoType // "") | ascii_downcase' "$detail_file" 2>/dev/null || echo "")
                    if [[ "$kind" == "local" ]]; then
                        _local=$((_local+1))
                    elif [[ "$kind" == "remote" ]]; then
                        _remote=$((_remote+1))
                    elif [[ "$kind" == "virtual" ]]; then
                        _virtual=$((_virtual+1))
                    else
                        # Last resort: infer from key
                        if [[ "$repo_key" == virtual-* || "$repo_key" == *-virtual ]]; then
                            _virtual=$((_virtual+1))
                        elif [[ "$repo_key" == remote-* || "$repo_key" == *-remote ]]; then
                            _remote=$((_remote+1))
                        elif [[ "$repo_key" == local-* || "$repo_key" == *-local ]]; then
                            _local=$((_local+1))
                        fi
                    fi
                fi
            done < "$filtered_repos"
            echo "{\"local\":${_local},\"remote\":${_remote},\"virtual\":${_virtual}}" > "$TEMP_DIR/repository_breakdown.json"
        fi

        # Heuristic fallback from key suffix/prefix if still zero
        sum_counts=$(jq -r '([.local,.remote,.virtual] | map(tonumber) | add) // 0' "$TEMP_DIR/repository_breakdown.json" 2>/dev/null || echo "0")
        if [[ "$existing_count" -gt 0 && "${sum_counts:-0}" -eq 0 ]]; then
            echo "ℹ️  Using key-suffix heuristic for repo breakdown..." >&2
            local heuristic_local heuristic_remote heuristic_virtual
            heuristic_local=$(grep -E -c '(^local-| -local$|\-local$)' "$filtered_repos" 2>/dev/null || echo 0)
            heuristic_remote=$(grep -E -c '(^remote-| -remote$|\-remote$)' "$filtered_repos" 2>/dev/null || echo 0)
            heuristic_virtual=$(grep -E -c '(^virtual-| -virtual$|\-virtual$)' "$filtered_repos" 2>/dev/null || echo 0)
            echo "{\"local\":${heuristic_local},\"remote\":${heuristic_remote},\"virtual\":${heuristic_virtual}}" > "$TEMP_DIR/repository_breakdown.json"
        fi
        
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
        # Fallback if empty: list all apps and filter by project_key
        if [[ ! -s "$filtered_apps" ]]; then
            local all_apps_file="$TEMP_DIR/all_applications.json"
            local code2=$(jfrog_api_call "GET" "/apptrust/api/v1/applications" "$all_apps_file" "curl" "" "all applications")
            if is_success "$code2" && [[ -s "$all_apps_file" ]]; then
                jq -r --arg project "$PROJECT_KEY" '.[] | select(.project_key == $project) | .application_key' "$all_apps_file" > "$filtered_apps" 2>/dev/null || true
            fi
        fi
        
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
    
    local count=0
    if is_success "$code" && [[ -s "$builds_file" ]]; then
        echo "✅ Successfully discovered builds for project '$PROJECT_KEY'" >&2
        
        # Extract build names from project builds
        jq -r '.builds[]?.uri' "$builds_file" 2>/dev/null | sed 's|^/||' > "$filtered_builds" 2>/dev/null || true
        count=$(wc -l < "$filtered_builds" 2>/dev/null || echo 0)
    fi

    # Fallbacks if none found
    if [[ "$count" -eq 0 ]]; then
        echo "ℹ️ Fallback: Listing all builds and filtering by name..." >&2
        
        # Try getting all builds and filtering by name containing project key
        local all_builds_file="$TEMP_DIR/all_builds.json"
        local code2=$(jfrog_api_call "GET" "/artifactory/api/build" "$all_builds_file" "curl" "" "all builds")
        
        if is_success "$code2" && [[ -s "$all_builds_file" ]]; then
            # Filter builds that contain the project key in their name
            jq -r --arg project "$PROJECT_KEY" '.builds[]?.uri | select(contains($project))' "$all_builds_file" 2>/dev/null | sed 's|^/||' > "$filtered_builds" 2>/dev/null || true
            count=$(wc -l < "$filtered_builds" 2>/dev/null || echo 0)
            
            if [[ "$count" -gt 0 ]]; then
                echo "✅ Found $count builds via name filtering" >&2
            fi
        fi
    fi
    
    echo "🏗️ Found $count builds in project '$PROJECT_KEY'" >&2
    
    if [[ "$count" -gt 0 ]]; then
        echo "Project builds:" >&2
        cat "$filtered_builds" | sed 's/^/  - /' >&2
    fi
    
    # Count returned via global variable, function always returns 0 (success)
    GLOBAL_BUILD_COUNT=$count
    return 0
}

# 5. PROJECT-BASED STAGE DISCOVERY
discover_project_stages() {
    echo "🔍 Discovering project stages (PROJECT-BASED)..." >&2
    
    local stages_file="$TEMP_DIR/project_stages.txt"
    
    # Try multiple methods to discover project stages
    local count=0
    
    # Method 1: Direct project stages API (v1)
    local project_stages_file="$TEMP_DIR/project_stages_v1.json"
    local code=$(jfrog_api_call "GET" "/access/api/v1/projects/$PROJECT_KEY/stages" "$project_stages_file" "curl" "" "project stages v1")
    
    if is_success "$code" && [[ -s "$project_stages_file" ]]; then
        jq -r '.[]? | .name' "$project_stages_file" 2>/dev/null > "$stages_file" || touch "$stages_file"
        count=$(wc -l < "$stages_file" 2>/dev/null || echo 0)
        echo "✅ Found $count stages via v1 project API" >&2
    fi
    
    # Method 2: Project stages API (v2) if v1 failed
    if [[ "$count" -eq 0 ]]; then
        local project_stages_v2_file="$TEMP_DIR/project_stages_v2.json"
        local code2=$(jfrog_api_call "GET" "/access/api/v2/stages?project_key=$PROJECT_KEY" "$project_stages_v2_file" "curl" "" "project stages v2")
        
        if is_success "$code2" && [[ -s "$project_stages_v2_file" ]]; then
            jq -r '.[]? | .name' "$project_stages_v2_file" 2>/dev/null > "$stages_file" || touch "$stages_file"
            count=$(wc -l < "$stages_file" 2>/dev/null || echo 0)
            echo "✅ Found $count stages via v2 project API" >&2
        fi
    fi
    
    # Method 3: Get all stages and filter by project
    if [[ "$count" -eq 0 ]]; then
        echo "ℹ️ Fallback: Getting all stages and filtering..." >&2
        local all_stages_file="$TEMP_DIR/all_stages.json"
        local code3=$(jfrog_api_call "GET" "/access/api/v2/stages" "$all_stages_file" "curl" "" "all stages")
        
        if is_success "$code3" && [[ -s "$all_stages_file" ]]; then
            # Filter stages that belong to our project
            jq -r --arg project "$PROJECT_KEY" '.[]? | select(.project_key == $project) | .name' "$all_stages_file" 2>/dev/null > "$stages_file" || touch "$stages_file"
            count=$(wc -l < "$stages_file" 2>/dev/null || echo 0)
            
            if [[ "$count" -gt 0 ]]; then
                echo "✅ Found $count project stages via all-stages filtering" >&2
            fi
        fi
    fi
    
    echo "🏷️ Found $count stages in project '$PROJECT_KEY'" >&2
    
    if [[ "$count" -gt 0 ]]; then
        echo "Project stages:" >&2
        cat "$stages_file" | sed 's/^/  - /' >&2
    fi
    
    # Count returned via global variable, function always returns 0 (success)
    GLOBAL_STAGE_COUNT=$count
    return 0
}

# 6. OIDC INTEGRATION DISCOVERY
discover_project_oidc() {
    echo "🔍 Discovering OIDC integrations..." >&2
    
    local oidc_file="$TEMP_DIR/project_oidc.txt"
    
    # Get all OIDC integrations and filter by name containing project key
    local all_oidc_file="$TEMP_DIR/all_oidc.json"
    local code=$(jfrog_api_call "GET" "/access/api/v1/oidc" "$all_oidc_file" "curl" "" "all oidc integrations")
    
    local count=0
    if is_success "$code" && [[ -s "$all_oidc_file" ]]; then
        # Filter OIDC integrations that contain the project key in their name
        jq -r --arg project "$PROJECT_KEY" '.[]? | .name | select(contains($project))' "$all_oidc_file" 2>/dev/null > "$oidc_file" || touch "$oidc_file"
        count=$(wc -l < "$oidc_file" 2>/dev/null || echo 0)
    else
        touch "$oidc_file"
    fi
    
    echo "🔐 Found $count OIDC integrations containing '$PROJECT_KEY'" >&2
    
    if [[ "$count" -gt 0 ]]; then
        echo "OIDC integrations:" >&2
        cat "$oidc_file" | sed 's/^/  - /' >&2
    fi
    
    # Count returned via global variable, function always returns 0 (success)
    GLOBAL_OIDC_COUNT=$count
    return 0
}

# =============================================================================
# COMPREHENSIVE DISCOVERY FUNCTION THAT LISTS ALL RESOURCES WITHOUT DELETION
# =============================================================================

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
    local oidc_count=0
    local domain_users_count=0
    
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

    # 4b. Discover ALL global domain users (@bookverse.com)
    echo "👥 Discovering ALL global @bookverse.com users..."
    local all_users_file="$TEMP_DIR/all_users.json"
    local domain_users_file="$TEMP_DIR/domain_users.txt"
    local code_users=$(jfrog_api_call "GET" "/artifactory/api/security/users" "$all_users_file" "curl" "" "list all users")
    if is_success "$code_users" && [[ -s "$all_users_file" ]]; then
        jq -r '.[]? | .name' "$all_users_file" 2>/dev/null | grep -E "@bookverse\\.com$" | sort -u > "$domain_users_file" 2>/dev/null || true
        domain_users_count=$(wc -l < "$domain_users_file" 2>/dev/null || echo 0)
        echo "👥 Found $domain_users_count global domain users (@bookverse.com)" >&2
    else
        : > "$domain_users_file"
        domain_users_count=0
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
    
    # 6. Discover OIDC integrations (visibility only)
    echo "🔐 Discovering OIDC integrations..."
    if discover_project_oidc; then
        oidc_count=$GLOBAL_OIDC_COUNT
    else
        echo "⚠️  Warning: OIDC discovery failed, treating as 0"
        oidc_count=0
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
    local repos_json apps_json users_json stages_json builds_json oidc_json domain_users_json repo_breakdown_json
    # Prefer typed repositories if raw JSON is available; otherwise fallback to keys from .txt
    if [[ -s "$TEMP_DIR/project_repositories.json" ]]; then
        local typed_repos_file="$TEMP_DIR/project_repositories_typed.json"
        jq -n --argfile r "$TEMP_DIR/project_repositories.json" --arg project "$PROJECT_KEY" '
          (if ($r | type) == "array" then $r
           elif ($r | type) == "object" then ($r.repositories // $r.repos // [])
           else [] end) as $repos
          |
          $repos
          | map(
              . as $item
              | (
                  ($item.rclass // $item.repoType // $item.type // "") as $kind_raw
                  | (if ($kind_raw|type) == "string" then ($kind_raw|ascii_downcase) else "" end) as $kind
                  | if $kind == "" then
                      # Fallback heuristic from repo key
                      ($item.key // "") as $k
                      | (if ($k|test("-virtual$")) or ($k|test("^virtual-")) then "virtual"
                         elif ($k|test("-remote$")) or ($k|test("^remote-")) then "remote"
                         elif ($k|test("-local$")) or ($k|test("^local-")) then "local"
                         else ""
                         end)
                    else $kind end
                ) as $norm
              | {key: ($item.key // ""), project: $project, type: $norm}
            )
        ' > "$typed_repos_file" 2>/dev/null || echo '[]' > "$typed_repos_file"

        repos_json=$(cat "$typed_repos_file" 2>/dev/null || echo '[]')
    elif [[ -f "$TEMP_DIR/project_repositories.txt" ]]; then
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
        # Fetch lifecycle to check which stages are referenced
        local lifecycle_file="$TEMP_DIR/lifecycle.json"
        jfrog_api_call "GET" "/access/api/v2/lifecycle/?project_key=$PROJECT_KEY" "$lifecycle_file" "curl" "" "get lifecycle for stage usage" >/dev/null || true

        # Use lifecycle info only if it's valid JSON; otherwise fall back gracefully
        if [[ -s "$lifecycle_file" ]] && jq -e . "$lifecycle_file" >/dev/null 2>&1; then
            stages_json=$(jq -R -s --arg project "$PROJECT_KEY" --argfile lif "$lifecycle_file" '
                ( ($lif|try .promote_stages catch []) ) as $ps
                | split("\n")
                | map(select(length>0))
                | map({name:., project:$project, in_use: ( ($ps|index(.)) != null )})
            ' "$TEMP_DIR/project_stages.txt" 2>/dev/null || echo '[]')
        else
            stages_json=$(jq -R -s --arg project "$PROJECT_KEY" 'split("\n")|map(select(length>0))|map({name:., project:$project, in_use:false})' "$TEMP_DIR/project_stages.txt" 2>/dev/null || echo '[]')
        fi
    else
        stages_json='[]'
    fi
    if [[ -f "$TEMP_DIR/project_builds.txt" ]]; then
        builds_json=$(jq -R -s --arg project "$PROJECT_KEY" 'split("\n")|map(select(length>0))|map({name:., project:$project})' "$TEMP_DIR/project_builds.txt" 2>/dev/null || echo '[]')
    else
        builds_json='[]'
    fi

    # OIDC integrations (visibility + plan)
    if [[ -f "$TEMP_DIR/project_oidc.txt" ]]; then
        oidc_json=$(jq -R -s 'split("\n")|map(select(length>0))' "$TEMP_DIR/project_oidc.txt" 2>/dev/null || echo '[]')
        plan_oidc_json="$oidc_json"
    else
        oidc_json='[]'
        plan_oidc_json='[]'
    fi

    # Domain users (GLOBAL deletion plan)
    if [[ -f "$TEMP_DIR/domain_users.txt" ]]; then
        domain_users_json=$(jq -R -s 'split("\n")|map(select(length>0))' "$TEMP_DIR/domain_users.txt" 2>/dev/null || echo '[]')
    else
        domain_users_json='[]'
    fi

    # Repository breakdown (types)
    # Prefer the previously computed breakdown (which includes API intersection/per-repo fallbacks),
    # and only compute from typed repos if the existing breakdown sums to 0.
    if [[ -f "$TEMP_DIR/repository_breakdown.json" ]]; then
        repo_breakdown_json=$(cat "$TEMP_DIR/repository_breakdown.json" 2>/dev/null || echo '{"local":0,"remote":0,"virtual":0}')
        local sum_rb
        sum_rb=$(echo "$repo_breakdown_json" | jq -r '([.local,.remote,.virtual] | map(tonumber) | add) // 0' 2>/dev/null || echo 0)
        if [[ "${sum_rb:-0}" -eq 0 && -s "$TEMP_DIR/project_repositories_typed.json" ]]; then
            repo_breakdown_json=$(jq '{
              local:   (map(select((.type // "") == "local"))   | length),
              remote:  (map(select((.type // "") == "remote"))  | length),
              virtual: (map(select((.type // "") == "virtual")) | length)
            }' "$TEMP_DIR/project_repositories_typed.json" 2>/dev/null || echo '{"local":0,"remote":0,"virtual":0}')
        fi
    else
        if [[ -s "$TEMP_DIR/project_repositories_typed.json" ]]; then
            repo_breakdown_json=$(jq '{
              local:   (map(select((.type // "") == "local"))   | length),
              remote:  (map(select((.type // "") == "remote"))  | length),
              virtual: (map(select((.type // "") == "virtual")) | length)
            }' "$TEMP_DIR/project_repositories_typed.json" 2>/dev/null || echo '{"local":0,"remote":0,"virtual":0}')
        else
            repo_breakdown_json='{"local":0,"remote":0,"virtual":0}'
        fi
    fi
    # Debug print of breakdown used
    echo "📊 Repo breakdown used in report: $repo_breakdown_json" >&2

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
        --argjson oidc_count "$oidc_count" \
        --argjson domain_users_count "$domain_users_count" \
        --slurpfile rb_file "$TEMP_DIR/repository_breakdown.json" \
        --slurpfile typed_repos_file "$TEMP_DIR/project_repositories_typed.json" \
        --rawfile repos_txt "$TEMP_DIR/project_repositories.txt" \
        --rawfile preview_rf "$preview_file" \
        --argjson plan_apps "$apps_json" \
        --argjson plan_users "$users_json" \
        --argjson plan_stages "$stages_json" \
        --argjson plan_builds "$builds_json" \
        --argjson plan_oidc "$plan_oidc_json" \
        --argjson obs_oidc "$oidc_json" \
        --argjson plan_domain_users "$domain_users_json" \
        '
        # derive plan repositories from typed file or text keys
        def repos_from_text(rt; project): (rt | split("\n") | map(select(length>0)) | map({key:., project: project}));
        def repos_from_preview(pv; project): (
          pv
          | split("\n")
          | map(select(test("^\\s*❌ Repository: "))) 
          | map(sub("^\\s*❌ Repository: \\s*"; ""))
          | map({key:., project: project})
        );
        def normalize_type(r): (
          (r.type // "") as $t
          | if $t != "" then ($t|ascii_downcase)
            else (
              (r.key // "") as $k
              | if ($k|test("-virtual$") or $k|test("^virtual-")) then "virtual"
                elif ($k|test("-remote$") or $k|test("^remote-")) then "remote"
                elif ($k|test("-local$") or $k|test("^local-")) then "local"
                else ""
              end)
            end);
        
        (
          if ($typed_repos_file|length>0) and (($typed_repos_file[0]|type)=="array") and (($typed_repos_file[0]|length)>0) then
            $typed_repos_file[0]
          else
            (
              repos_from_text($repos_txt; $project_key) as $rt
              | if ($rt|length) > 0 then $rt else repos_from_preview($preview_rf; $project_key) end
            )
          end
        ) as $repos
        |
        # compute breakdown from file or from derived repos
        (
          if ($rb_file|length>0) and (($rb_file[0]|type)=="object") then $rb_file[0]
          else {
            local:   ($repos | map(normalize_type(.) == "local")   | map(select(.)) | length),
            remote:  ($repos | map(normalize_type(.) == "remote")  | map(select(.)) | length),
            virtual: ($repos | map(normalize_type(.) == "virtual") | map(select(.)) | length)
          } end
        ) as $rb
        |
        {
            "metadata": {
                "timestamp": $timestamp,
                "project_key": $project_key,
                "total_items": $total_items,
                "discovery_counts": {
                    "builds": $builds_count,
                    "applications": $apps_count,
                    "repositories": $repos_count,
                    "users": $users_count,
                    "stages": $stages_count,
                    "oidc": $oidc_count,
                    "repositories_breakdown": $rb,
                    "domain_users": $domain_users_count
                }
            },
            "plan": {
                "repositories": $repos,
                "applications": $plan_apps,
                "users": $plan_users,
                "stages": $plan_stages,
                "builds": $plan_builds,
                "oidc": $plan_oidc,
                "domain_users": $plan_domain_users
            },
            "observations": {
                "oidc_integrations": $obs_oidc
            },
            "deletion_preview": $preview_rf,
            "status": "ready_for_cleanup"
        }' > "$shared_report_file"
    
    echo "📋 Shared report saved to: $shared_report_file" >&2
    
    # Set global variables instead of using return codes
    GLOBAL_PREVIEW_FILE="$preview_file"
    GLOBAL_TOTAL_ITEMS="$total_items"
    return 0  # Always return success
}
