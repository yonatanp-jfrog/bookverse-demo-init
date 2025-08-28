#!/usr/bin/env bash

set -e

echo "🔍 INVESTIGATING PROJECT-BASED RESOURCE DISCOVERY"
echo "================================================="
echo "Goal: Find ALL resources belonging to 'bookverse' PROJECT"
echo "NOT just resources with 'bookverse' in their names"
echo ""

# Source configuration
source "$(dirname "$0")/config.sh"
validate_environment

# Setup JFrog CLI  
jf c add bookverse-admin --url="${JFROG_URL}" --access-token="${JFROG_ADMIN_TOKEN}" --interactive=false --overwrite
jf c use bookverse-admin

echo "Project: ${PROJECT_KEY}"
echo "JFrog URL: ${JFROG_URL}"
echo ""

# Function to safely call API
call_project_api() {
    local endpoint="$1"
    local description="$2"
    local method="${3:-GET}"
    local client="${4:-curl}"
    
    echo "📡 $description"
    echo "   Endpoint: $endpoint"
    echo "   Method: $method"
    echo "   Client: $client"
    
    local response_file=$(mktemp)
    local http_code
    
    if [[ "$client" == "jf" ]]; then
        if [[ "$endpoint" == /artifactory/* ]]; then
            http_code=$(jf rt curl -X "$method" -H "X-JFrog-Project: ${PROJECT_KEY}" "$endpoint" --write-out "%{http_code}" --output "$response_file" --silent)
        else
            http_code=$(jf rt curl -X "$method" "$endpoint" --write-out "%{http_code}" --output "$response_file" --silent)
        fi
    else
        if [[ "$endpoint" == /artifactory/* ]]; then
            http_code=$(curl -s -w "%{http_code}" \
                -H "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
                -H "X-JFrog-Project: ${PROJECT_KEY}" \
                -H "Content-Type: application/json" \
                -X "$method" \
                "${JFROG_URL%/}${endpoint}" \
                -o "$response_file" 2>/dev/null || echo "000")
        else
            http_code=$(curl -s -w "%{http_code}" \
                -H "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
                -H "Content-Type: application/json" \
                -X "$method" \
                "${JFROG_URL%/}${endpoint}" \
                -o "$response_file" 2>/dev/null || echo "000")
        fi
    fi
    
    echo "   Result: HTTP $http_code"
    
    if [[ "$http_code" == "200" || "$http_code" == "201" ]]; then
        echo "   ✅ Success"
        if [[ -s "$response_file" ]]; then
            local size=$(wc -c < "$response_file")
            echo "   Response size: $size bytes"
            
            # Try to parse as JSON and show sample
            if jq . "$response_file" >/dev/null 2>&1; then
                echo "   📋 Response structure:"
                jq 'keys' "$response_file" 2>/dev/null | head -10 || jq '. | type' "$response_file"
                echo "   📋 Sample content:"
                jq . "$response_file" 2>/dev/null | head -20 || head -10 "$response_file"
            else
                echo "   📋 Response (not JSON):"
                head -10 "$response_file"
            fi
        fi
    elif [[ "$http_code" == "404" ]]; then
        echo "   ⚠️  Not found (empty or doesn't exist)"
    else
        echo "   ❌ Failed"
        if [[ -s "$response_file" ]]; then
            echo "   Error response:"
            head -5 "$response_file"
        fi
    fi
    
    rm -f "$response_file"
    echo ""
}

echo "🔍 PROJECT-BASED REPOSITORY INVESTIGATION"
echo "=========================================="

# Test project-specific repository endpoints
call_project_api "/artifactory/api/repositories?project=${PROJECT_KEY}" "Project Repositories (with project param)" "GET" "jf"
call_project_api "/access/api/v1/projects/${PROJECT_KEY}/repositories" "Project Repositories (access API)" "GET" "curl"

echo "🔍 PROJECT-BASED USER INVESTIGATION"
echo "==================================="

# Test project-specific user endpoints
call_project_api "/access/api/v1/projects/${PROJECT_KEY}/users" "Project Users (access API)" "GET" "curl"
call_project_api "/access/api/v1/projects/${PROJECT_KEY}/groups" "Project Groups (access API)" "GET" "curl"

echo "🔍 PROJECT-BASED BUILD INVESTIGATION"
echo "===================================="

# Test project-specific build endpoints
call_project_api "/artifactory/api/build?project=${PROJECT_KEY}" "Project Builds (with project param)" "GET" "curl"
call_project_api "/artifactory/api/builds?project=${PROJECT_KEY}" "Project Builds Alternative (with project param)" "GET" "curl"

echo "🔍 PROJECT-BASED APPLICATION INVESTIGATION"
echo "=========================================="

# Test project-specific application endpoints (this should already be correct)
call_project_api "/apptrust/api/v1/applications?project=${PROJECT_KEY}" "Project Applications (apptrust API)" "GET" "curl"

echo "🔍 PROJECT-BASED STAGE INVESTIGATION"
echo "===================================="

# Test project-specific stage endpoints
call_project_api "/access/api/v1/projects/${PROJECT_KEY}/stages" "Project Stages (access API)" "GET" "curl"
call_project_api "/access/api/v2/stages?project=${PROJECT_KEY}" "Project Stages v2 (with project param)" "GET" "curl"

echo "🔍 PROJECT INFORMATION INVESTIGATION"
echo "===================================="

# Get complete project information
call_project_api "/access/api/v1/projects/${PROJECT_KEY}" "Project Details" "GET" "curl"

echo ""
echo "🎯 PROJECT-BASED INVESTIGATION COMPLETE"
echo "======================================="
echo "This should reveal the correct APIs to find ALL resources"
echo "belonging to the '${PROJECT_KEY}' project, regardless of names."
