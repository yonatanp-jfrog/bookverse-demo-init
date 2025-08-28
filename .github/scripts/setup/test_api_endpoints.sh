#!/usr/bin/env bash

set -e

# Quick API endpoints validation script
source "$(dirname "$0")/config.sh"
validate_environment

echo "🔍 Testing JFrog API Endpoints"
echo "==============================="
echo "Project: ${PROJECT_KEY}"
echo "JFrog URL: ${JFROG_URL}"
echo ""

# Setup JFrog CLI
jf c add bookverse-admin --url="${JFROG_URL}" --access-token="${JFROG_ADMIN_TOKEN}" --interactive=false --overwrite
jf c use bookverse-admin

# Test function
test_endpoint() {
    local endpoint="$1"
    local description="$2"
    local method="${3:-GET}"
    
    echo "Testing: $description"
    echo "  Endpoint: $endpoint"
    
    local response_file=$(mktemp)
    local http_code
    
    http_code=$(curl -s -w "%{http_code}" \
        -H "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
        -H "Content-Type: application/json" \
        -X "$method" \
        "${JFROG_URL%/}${endpoint}" \
        -o "$response_file" 2>/dev/null || echo "000")
    
    echo "  Result: HTTP $http_code"
    
    if [[ "$http_code" == "200" || "$http_code" == "201" ]]; then
        echo "  ✅ Success"
        echo "  Response size: $(wc -c < "$response_file") bytes"
    elif [[ "$http_code" == "404" ]]; then
        echo "  ⚠️  Not found (may be empty or not exist yet)"
    elif [[ "$http_code" == "000" ]]; then
        echo "  ❌ Connection failed - check endpoint URL"
    else
        echo "  ❌ Failed"
        echo "  Response: $(head -c 200 "$response_file")"
    fi
    
    rm -f "$response_file"
    echo ""
}

# Test core endpoints
test_endpoint "/artifactory/api/system/ping" "Artifactory System Ping"
test_endpoint "/access/api/v1/system/ping" "Access System Ping"
test_endpoint "/artifactory/api/repositories" "Artifactory Repositories List"
test_endpoint "/access/api/v1/users" "Access Users List"
test_endpoint "/apptrust/api/v1/applications?project=${PROJECT_KEY}" "AppTrust Applications"
test_endpoint "/access/api/v2/stages" "Access Stages List"
test_endpoint "/access/api/v1/projects/${PROJECT_KEY}" "Project Info"
test_endpoint "/access/api/v2/lifecycle/?project_key=${PROJECT_KEY}" "Lifecycle Configuration"

echo "🎯 API Endpoints Test Complete"
echo "==============================="
echo "If any endpoints show connection failures (HTTP 000),"
echo "this indicates the same issues the cleanup script encountered."
echo ""
echo "Next steps:"
echo "1. If all endpoints work: retry cleanup with: ./cleanup.sh"
echo "2. If some fail: check JFrog instance configuration"
echo "3. Verify token permissions cover all required APIs"
