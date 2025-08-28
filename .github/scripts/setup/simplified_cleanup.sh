#!/usr/bin/env bash

set -e

# Simple cleanup script with better error handling for API failures
source "$(dirname "$0")/config.sh"
validate_environment

echo "🧹 Simplified BookVerse Cleanup"
echo "================================"
echo "Project: ${PROJECT_KEY}"
echo "JFrog URL: ${JFROG_URL}"
echo ""

# Setup JFrog CLI
jf c add bookverse-admin --url="${JFROG_URL}" --access-token="${JFROG_ADMIN_TOKEN}" --interactive=false --overwrite
jf c use bookverse-admin

# Test basic connectivity
echo "Testing connectivity..."
if ! jf rt ping > /dev/null 2>&1; then
    echo "❌ JFrog connectivity test failed"
    exit 1
fi
echo "✅ JFrog connectivity OK"
echo ""

# Function to safely make API calls with curl
safe_api_call() {
    local method="$1"
    local endpoint="$2"
    local description="$3"
    
    echo "🔍 $description..."
    
    local response_file=$(mktemp)
    local http_code
    
    http_code=$(curl -s -w "%{http_code}" \
        -H "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
        -H "Content-Type: application/json" \
        -X "$method" \
        "${JFROG_URL}${endpoint}" \
        -o "$response_file" 2>/dev/null || echo "000")
    
    echo "   HTTP $http_code: $endpoint"
    
    if [[ "$http_code" == "200" || "$http_code" == "201" || "$http_code" == "204" ]]; then
        echo "   ✅ Success"
        if [[ -s "$response_file" ]]; then
            cat "$response_file" | head -c 500 | jq . 2>/dev/null || cat "$response_file" | head -c 200
        fi
    elif [[ "$http_code" == "404" ]]; then
        echo "   ⚠️  Not found (may already be deleted)"
    elif [[ "$http_code" == "400" ]]; then
        echo "   ❌ Bad request - likely contains resources"
        if [[ -s "$response_file" ]]; then
            echo "   Response: $(cat "$response_file")"
        fi
    elif [[ "$http_code" == "000" ]]; then
        echo "   ❌ Connection failed - endpoint may not exist or be accessible"
    else
        echo "   ❌ Failed (HTTP $http_code)"
        if [[ -s "$response_file" ]]; then
            echo "   Response: $(cat "$response_file" | head -c 200)"
        fi
    fi
    
    rm -f "$response_file"
    echo ""
    
    return 0
}

# Check what resources exist
echo "🔍 DISCOVERY PHASE"
echo "=================="

# Check project existence
safe_api_call "GET" "/access/api/v1/projects/${PROJECT_KEY}" "Checking project existence"

# Check applications in project
safe_api_call "GET" "/apptrust/api/v1/applications?project=${PROJECT_KEY}" "Checking applications in project"

# Check repositories
safe_api_call "GET" "/artifactory/api/repositories?project=${PROJECT_KEY}" "Checking repositories"

# Check project stages
safe_api_call "GET" "/access/api/v2/stages" "Checking project stages"

# Check lifecycle configuration
safe_api_call "GET" "/access/api/v2/lifecycle/?project_key=${PROJECT_KEY}" "Checking lifecycle configuration"

echo "🗑️  CLEANUP PHASE"
echo "================="

# Try to clear lifecycle configuration
safe_api_call "PATCH" "/access/api/v2/lifecycle/?project_key=${PROJECT_KEY}" "Clearing lifecycle configuration"

# Try to delete project stages
for stage in "DEV" "QA" "STAGING"; do
    safe_api_call "DELETE" "/access/api/v2/stages/${PROJECT_KEY}-${stage}" "Deleting stage ${PROJECT_KEY}-${stage}"
done

# Try to delete project (this will fail if resources remain)
safe_api_call "DELETE" "/access/api/v1/projects/${PROJECT_KEY}?force=true" "Deleting project ${PROJECT_KEY}"

echo "🎯 FINAL VERIFICATION"
echo "===================="

# Final check
safe_api_call "GET" "/access/api/v1/projects/${PROJECT_KEY}" "Final project check"

echo ""
echo "🔍 MANUAL VERIFICATION STEPS:"
echo "=============================="
echo "1. Visit: ${JFROG_URL}"
echo "2. Check Administration → Projects → Look for '${PROJECT_KEY}'"
echo "3. Check AppTrust → Applications → Filter by project '${PROJECT_KEY}'"
echo "4. Check Administration → Repositories → Search for '${PROJECT_KEY}'"
echo ""
echo "If resources still exist, delete them manually through the UI."
echo "The project can only be deleted when all contained resources are removed."
