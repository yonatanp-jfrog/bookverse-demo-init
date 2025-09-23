#!/usr/bin/env bash

set -e


PROJECT_KEY="bookverse"
JFROG_URL="${JFROG_URL:-https://apptrustswampupc.jfrog.io}"
TEMP_DIR="/tmp/resource_investigation_$$"

mkdir -p "$TEMP_DIR"

echo "🔍 INVESTIGATING ACTUAL RESOURCES IN PROJECT '$PROJECT_KEY'"
echo "============================================================="
echo "🎯 User reports: builds, artifacts, repositories still exist"
echo "📊 Script reports: 0 builds, 0 repos - DISCOVERY LOGIC BROKEN"
echo ""


log_attempt() {
    echo "🔍 TRYING: $1" >&2
}

log_success() {
    echo "✅ SUCCESS: $1" >&2
}

log_fail() {
    echo "❌ FAILED: $1" >&2
}


echo "📦 REPOSITORY INVESTIGATION"
echo "==========================="

log_attempt "JFrog CLI repo-list"
if jf rt repo-list > "$TEMP_DIR/repos_cli.txt" 2>/dev/null; then
    repo_count=$(wc -l < "$TEMP_DIR/repos_cli.txt" 2>/dev/null || echo 0)
    log_success "CLI found $repo_count total repositories"
    echo "First 10 repositories:"
    head -10 "$TEMP_DIR/repos_cli.txt" 2>/dev/null || echo "No output"
    
    echo ""
    echo "🔍 Repositories containing 'bookverse':"
    grep -i bookverse "$TEMP_DIR/repos_cli.txt" 2>/dev/null || echo "None found"
else
    log_fail "CLI repo-list failed"
fi

echo ""
log_attempt "REST API /artifactory/api/repositories"
if curl -s -H "Authorization: Bearer $JFROG_ADMIN_TOKEN" \
    "${JFROG_URL%/}/artifactory/api/repositories" > "$TEMP_DIR/repos_api.json" 2>/dev/null; then
    repo_count=$(jq '. | length' "$TEMP_DIR/repos_api.json" 2>/dev/null || echo 0)
    log_success "API found $repo_count total repositories"
    
    echo "Repository keys (first 10):"
    jq -r '.[].key' "$TEMP_DIR/repos_api.json" 2>/dev/null | head -10 || echo "No keys found"
    
    echo ""
    echo "🔍 Repositories with projectKey = '$PROJECT_KEY':"
    jq --arg project "$PROJECT_KEY" '.[] | select(.projectKey == $project) | .key' "$TEMP_DIR/repos_api.json" 2>/dev/null || echo "None found"
    
    echo ""
    echo "🔍 Repositories containing 'bookverse' in key:"
    jq -r '.[] | select(.key | contains("bookverse")) | .key' "$TEMP_DIR/repos_api.json" 2>/dev/null || echo "None found"
else
    log_fail "REST API failed"
fi


echo ""
echo "🏗️ BUILD INVESTIGATION"
echo "====================="

log_attempt "JFrog CLI build-info list"
if jf rt builds > "$TEMP_DIR/builds_cli.txt" 2>/dev/null; then
    build_count=$(wc -l < "$TEMP_DIR/builds_cli.txt" 2>/dev/null || echo 0)
    log_success "CLI found $build_count total builds"
    echo "All builds:"
    cat "$TEMP_DIR/builds_cli.txt" 2>/dev/null || echo "No output"
    
    echo ""
    echo "🔍 Builds containing 'bookverse':"
    grep -i bookverse "$TEMP_DIR/builds_cli.txt" 2>/dev/null || echo "None found"
else
    log_fail "CLI builds list failed"
fi

echo ""
log_attempt "REST API /artifactory/api/build"
if curl -s -H "Authorization: Bearer $JFROG_ADMIN_TOKEN" \
    "${JFROG_URL%/}/artifactory/api/build" > "$TEMP_DIR/builds_api.json" 2>/dev/null; then
    
    if [[ -s "$TEMP_DIR/builds_api.json" ]]; then
        log_success "API returned build data"
        echo "Build API response:"
        jq '.' "$TEMP_DIR/builds_api.json" 2>/dev/null || cat "$TEMP_DIR/builds_api.json"
    else
        log_fail "API returned empty response"
    fi
else
    log_fail "REST API failed"
fi


echo ""
echo "🎯 PROJECT DETAILS INVESTIGATION"
echo "================================"

log_attempt "Project details API"
if curl -s -H "Authorization: Bearer $JFROG_ADMIN_TOKEN" \
    "${JFROG_URL%/}/access/api/v1/projects/$PROJECT_KEY" > "$TEMP_DIR/project_details.json" 2>/dev/null; then
    log_success "Project details retrieved"
    echo "Project details:"
    jq '.' "$TEMP_DIR/project_details.json" 2>/dev/null || cat "$TEMP_DIR/project_details.json"
else
    log_fail "Project details failed"
fi

echo ""
log_attempt "Project resources API"
if curl -s -H "Authorization: Bearer $JFROG_ADMIN_TOKEN" \
    "${JFROG_URL%/}/access/api/v1/projects/$PROJECT_KEY/resources" > "$TEMP_DIR/project_resources.json" 2>/dev/null; then
    log_success "Project resources retrieved"
    echo "Project resources:"
    jq '.' "$TEMP_DIR/project_resources.json" 2>/dev/null || cat "$TEMP_DIR/project_resources.json"
else
    log_fail "Project resources failed"
fi


echo ""
echo "📋 ARTIFACT INVESTIGATION" 
echo "========================="

log_attempt "Search for artifacts in project repositories"
if [[ -f "$TEMP_DIR/repos_cli.txt" ]]; then
    while IFS= read -r repo_key; do
        if [[ -n "$repo_key" && "$repo_key" =~ bookverse ]]; then
            echo "🔍 Searching artifacts in repository: $repo_key"
            if jf rt search "$repo_key/*" --json > "$TEMP_DIR/artifacts_${repo_key}.json" 2>/dev/null; then
                artifact_count=$(jq '. | length' "$TEMP_DIR/artifacts_${repo_key}.json" 2>/dev/null || echo 0)
                echo "  Found $artifact_count artifacts"
                if [[ "$artifact_count" -gt 0 ]]; then
                    echo "  Sample artifacts:"
                    jq -r '.[].path' "$TEMP_DIR/artifacts_${repo_key}.json" 2>/dev/null | head -5
                fi
            fi
        fi
    done < "$TEMP_DIR/repos_cli.txt"
fi

echo ""
echo "🎯 INVESTIGATION COMPLETE"
echo "========================"
echo "Debug files saved in: $TEMP_DIR"
echo ""
echo "🔍 KEY FINDINGS TO REVIEW:"
echo "• Total repositories found vs. filtered repositories"
echo "• Build names and patterns"  
echo "• Project resource details"
echo "• Artifact locations and counts"
