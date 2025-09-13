#!/usr/bin/env bash

# =============================================================================
# SIMPLIFIED APPLICATION CREATION SCRIPT
# =============================================================================
# Creates BookVerse applications without shared utility dependencies
# =============================================================================

set -e

# Load configuration
source "$(dirname "$0")/config.sh"

echo ""
echo "🚀 Creating BookVerse applications"
echo "🔧 Project: $PROJECT_KEY"
echo "🔧 JFrog URL: $JFROG_URL"
echo ""

# Application definitions: app_key|app_name|description|criticality|maturity|team|owner
BOOKVERSE_APPLICATIONS=(
    "bookverse-core|BookVerse Core Library|Shared libraries and utilities providing common functionality (authentication, configuration, API utilities) used across all BookVerse microservices|high|production|platform|diana.architect@bookverse.com"
    "bookverse-inventory|BookVerse Inventory Service|Microservice responsible for managing book inventory, stock levels, and availability tracking across all BookVerse locations|high|production|inventory-team|frank.inventory@bookverse.com"
    "bookverse-recommendations|BookVerse Recommendations Service|AI-powered microservice that provides personalized book recommendations based on user preferences, reading history, and collaborative filtering|medium|production|ai-ml-team|grace.ai@bookverse.com"
    "bookverse-checkout|BookVerse Checkout Service|Secure microservice handling payment processing, order fulfillment, and transaction management for book purchases|high|production|checkout-team|henry.checkout@bookverse.com"
    "bookverse-platform|BookVerse Platform|Integrated platform solution combining all microservices with unified API gateway, monitoring, and operational tooling|high|production|platform|diana.architect@bookverse.com"
    "bookverse-web|BookVerse Web Application|Frontend web application delivering the BookVerse user interface and static assets, served via nginx with versioned bundles|medium|production|web-team|alice.developer@bookverse.com"
)

# Function to create an application
create_application() {
    local app_key="$1"
    local app_name="$2"
    local description="$3"
    local criticality="$4"
    local maturity="$5"
    local team="$6"
    local owner="$7"
    
    echo "Creating application: $app_name"
    echo "  Key: $app_key"
    echo "  Criticality: $criticality"
    echo "  Owner: $owner"
    
    # Build application JSON payload (using correct AppTrust API format)
    local app_payload=$(jq -n \
        --arg project "$PROJECT_KEY" \
        --arg key "$app_key" \
        --arg name "$app_name" \
        --arg desc "$description" \
        --arg crit "$criticality" \
        --arg mat "$maturity" \
        --arg team "$team" \
        --arg owner "$owner" \
        '{
            "project_key": $project,
            "application_key": $key,
            "application_name": $name,
            "description": $desc,
            "criticality": $crit,
            "maturity_level": $mat,
            "labels": {
                "team": $team,
                "type": "microservice",
                "architecture": "microservices",
                "environment": "production"
            },
            "user_owners": [$owner],
            "group_owners": []
        }')
    
    # Validate payload before sending
    if ! echo "$app_payload" | jq . >/dev/null 2>&1; then
        echo "❌ CRITICAL: Generated payload is not valid JSON!"
        echo "Raw payload: $app_payload"
        return 1
    fi
    
    # Check for required fields
    local missing_fields=()
    for field in "project_key" "application_key" "application_name" "criticality"; do
        if ! echo "$app_payload" | jq -e ".$field" >/dev/null 2>&1; then
            missing_fields+=("$field")
        fi
    done
    
    if [[ ${#missing_fields[@]} -gt 0 ]]; then
        echo "❌ CRITICAL: Missing required fields in payload: ${missing_fields[*]}"
        echo "Generated payload:"
        echo "$app_payload" | jq .
        return 1
    fi
    
    # Create application with detailed debugging and retry logic
    local temp_response=$(mktemp)
    local temp_headers=$(mktemp)
    local endpoint="${JFROG_URL}/apptrust/api/v1/applications"
    
    echo "🔍 DEBUG: About to create application with the following details:"
    echo "   • Endpoint: $endpoint"
    echo "   • Application Key: $app_key"
    echo "   • Owner: $owner"
    echo "   • Payload being sent:"
    echo "$app_payload" | jq . 2>/dev/null || echo "$app_payload"
    echo ""
    
    # Try up to 3 times for 500 errors (server issues)
    local max_attempts=3
    local attempt=1
    local response_code
    
    while [[ $attempt -le $max_attempts ]]; do
        echo "🔄 Attempt $attempt/$max_attempts: Creating application '$app_name'"
        
        response_code=$(curl -s \
            --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
            --header "Content-Type: application/json" \
            --header "User-Agent: BookVerse-Setup/1.0" \
            -X POST \
            -d "$app_payload" \
            --write-out "%{http_code}" \
            --output "$temp_response" \
            --dump-header "$temp_headers" \
            --max-time 30 \
            "$endpoint")
        
        echo "📡 Response received: HTTP $response_code"
        
        # If not a 500 error, break out of retry loop
        if [[ "$response_code" != "500" ]]; then
            break
        fi
        
        # For 500 errors, provide extensive debugging
        echo "❌ HTTP 500 ERROR - Server Internal Error (Attempt $attempt/$max_attempts)"
        echo ""
        echo "🔍 FULL DEBUGGING INFORMATION:"
        echo "================================"
        echo "📋 Request Details:"
        echo "   • Method: POST"
        echo "   • URL: $endpoint"
        echo "   • Content-Type: application/json"
        echo "   • Authorization: Bearer [REDACTED]"
        echo "   • User-Agent: BookVerse-Setup/1.0"
        echo ""
        echo "📤 Request Payload:"
        echo "$app_payload" | jq . 2>/dev/null || echo "$app_payload"
        echo ""
        echo "📥 Response Headers:"
        cat "$temp_headers" 2>/dev/null || echo "   (No headers captured)"
        echo ""
        echo "📥 Response Body:"
        cat "$temp_response" 2>/dev/null || echo "   (No response body)"
        echo ""
        echo "🔧 Server Analysis:"
        echo "   • This suggests the AppTrust API server is experiencing issues"
        echo "   • Could be: payload format issue, server overload, API version mismatch"
        echo "   • Server should be investigated by platform team"
        echo ""
        
        if [[ $attempt -lt $max_attempts ]]; then
            echo "⏳ Waiting 5 seconds before retry..."
            sleep 5
        fi
        
        ((attempt++))
    done
    
    case "$response_code" in
        200|201)
            echo "✅ Application '$app_name' created successfully (HTTP $response_code)"
            ;;
        409)
            echo "⚠️  Application '$app_name' already exists (HTTP $response_code)"
            ;;
        400)
            # Check if it's the "already exists" error
            if grep -q -i "already exists\|application.*exists" "$temp_response"; then
                echo "⚠️  Application '$app_name' already exists (HTTP $response_code)"
            else
                echo "❌ Failed to create application '$app_name' (HTTP $response_code)"
                echo "Response body: $(cat "$temp_response")"
                rm -f "$temp_response"
                return 1
            fi
            ;;
        500)
            # Check if this is the specific AppTrust bug (returns 500 instead of 409 for conflicts)
            response_body=$(cat "$temp_response" 2>/dev/null || echo "")
            if [[ "$response_body" == *'"An unexpected error occurred"'* ]]; then
                echo "🐛 DETECTED: AppTrust API bug - HTTP 500 instead of 409 for conflict"
                echo "🔍 Checking if application '$app_name' already exists..."
                
                # Check if the application already exists
                existing_check=$(curl -s \
                    --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
                    --write-out "%{http_code}" \
                    --output /dev/null \
                    --max-time 15 \
                    "${JFROG_URL}/apptrust/api/v1/applications/${app_key}")
                
                if [[ "$existing_check" == "200" ]]; then
                    echo "✅ WORKAROUND: Application '$app_name' already exists (confirmed via GET)"
                    echo "🐛 AppTrust API bug confirmed: Returns HTTP 500 instead of HTTP 409 for conflicts"
                    echo "📋 This should be reported to JFrog support for fixing"
                else
                    echo "❌ CRITICAL: Real HTTP 500 error - application does not exist"
                    echo "🚨 This is a genuine server error that needs immediate investigation!"
                    echo ""
                    echo "🔍 FINAL ATTEMPT DEBUGGING INFO:"
                    echo "================================"
                    echo "📥 Final Response Headers:"
                    cat "$temp_headers" 2>/dev/null || echo "   (No headers captured)"
                    echo ""
                    echo "📥 Final Response Body:"
                    cat "$temp_response" 2>/dev/null || echo "   (No response body)"
                    echo ""
                    echo "🎯 RECOMMENDED ACTIONS:"
                    echo "   1. Check AppTrust API server status and logs"
                    echo "   2. Verify endpoint: ${JFROG_URL}/apptrust/api/v1/applications"
                    echo "   3. Test API endpoint manually with curl"
                    echo "   4. Check server capacity and performance"
                    echo "   5. Review server-side application creation logic"
                    echo ""
                    echo "⚠️  TREATING AS NON-CRITICAL FOR NOW - but this needs investigation"
                fi
            else
                echo "❌ CRITICAL: AppTrust API returned HTTP 500 for '$app_name' after $max_attempts attempts"
                echo "🚨 This is a REAL server error that needs immediate investigation!"
                echo ""
                echo "🔍 FINAL ATTEMPT DEBUGGING INFO:"
                echo "================================"
                echo "📥 Final Response Headers:"
                cat "$temp_headers" 2>/dev/null || echo "   (No headers captured)"
                echo ""
                echo "📥 Final Response Body:"
                cat "$temp_response" 2>/dev/null || echo "   (No response body)"
                echo ""
                echo "🎯 RECOMMENDED ACTIONS:"
                echo "   1. Check AppTrust API server status and logs"
                echo "   2. Verify endpoint: ${JFROG_URL}/apptrust/api/v1/applications"
                echo "   3. Test API endpoint manually with curl"
                echo "   4. Check server capacity and performance"
                echo "   5. Review server-side application creation logic"
                echo ""
                echo "⚠️  TREATING AS NON-CRITICAL FOR NOW - but this needs investigation"
            fi
            ;;
        502|503|504)
            echo "❌ AppTrust API unavailable for '$app_name' (HTTP $response_code)"
            echo "🔍 DEBUG: Response details:"
            echo "Response headers: $(cat "$temp_headers" 2>/dev/null || echo 'none')"
            echo "Response body: $(cat "$temp_response" 2>/dev/null || echo 'none')"
            echo "💡 Temporary server issue - applications may need manual verification"
            ;;
        *)
            echo "❌ Failed to create application '$app_name' (HTTP $response_code)"
            echo "🔍 DEBUG: Full response details:"
            echo "Response headers: $(cat "$temp_headers" 2>/dev/null || echo 'none')"
            echo "Response body: $(cat "$temp_response" 2>/dev/null || echo 'none')"
            echo "💡 This may be due to API format changes or permission issues"
            echo "🎯 RECOMMENDED: Check API documentation for correct payload format"
            # Don't exit on application failures - they're not critical for platform function
            ;;
    esac
    
    rm -f "$temp_response" "$temp_headers"
    echo ""
}

echo "ℹ️  Applications to be created:"
for app_data in "${BOOKVERSE_APPLICATIONS[@]}"; do
    IFS='|' read -r app_key app_name _ criticality _ team owner <<< "$app_data"
    echo "   - $app_name ($app_key) → $owner [$criticality]"
done

echo ""
echo "🚀 Processing ${#BOOKVERSE_APPLICATIONS[@]} applications..."
echo ""

# Process each application
for app_data in "${BOOKVERSE_APPLICATIONS[@]}"; do
    IFS='|' read -r app_key app_name description criticality maturity team owner <<< "$app_data"
    
    create_application "$app_key" "$app_name" "$description" "$criticality" "$maturity" "$team" "$owner"
done

echo "✅ Application creation process completed!"
echo ""
echo "📱 Applications Summary:"
for app_data in "${BOOKVERSE_APPLICATIONS[@]}"; do
    IFS='|' read -r app_key app_name _ criticality _ team owner <<< "$app_data"
    echo "   - $app_name (Key: $app_key, Owner: $owner, Team: $team)"
done

echo ""
echo "🎯 BookVerse applications setup completed"
echo "   Successfully created applications are available in AppTrust"
echo "   Any applications with HTTP 500 errors may require manual setup"
echo ""

# -----------------------------------------------------------------------------
# Update service repositories with the correct JFrog application key
# -----------------------------------------------------------------------------

# Update .jfrog/config.yml in a service repository to set the application key
update_repo_jfrog_config() {
    local app_key="$1"
    local repo_name="$app_key"    # repo names match application keys (e.g., bookverse-inventory)
    local owner="${GITHUB_REPOSITORY_OWNER:-yonatanp-jfrog}"

    # Ensure GitHub CLI is available
    if ! command -v gh >/dev/null 2>&1; then
        echo "⚠️  GitHub CLI (gh) not found; skipping .jfrog/config.yml update for $owner/$repo_name"
        return 0
    fi

    echo "🔧 Updating .jfrog/config.yml in $owner/$repo_name"

    # Determine default branch (fallback to main)
    local branch
    branch=$(gh api "repos/$owner/$repo_name" -q .default_branch 2>/dev/null || echo "main")

    # Prepare file content and base64 encode it
    local file_content
    file_content=$(printf "application:\n  key: \"%s\"\n" "$app_key")
    local b64
    b64=$(printf "%s" "$file_content" | base64 | tr -d '\n')

    # Fetch existing file SHA if present
    local sha
    sha=$(gh api -X GET "repos/$owner/$repo_name/contents/.jfrog/config.yml" -f ref="$branch" -q .sha 2>/dev/null || echo "")

    # Build payload (include sha only if file exists)
    local payload
    payload=$(jq -n \
        --arg message "chore: set JFrog application key ($app_key)" \
        --arg content "$b64" \
        --arg branch "$branch" \
        --arg sha "$sha" \
        'if ($sha | length) > 0 then {message:$message, content:$content, branch:$branch, sha:$sha} else {message:$message, content:$content, branch:$branch} end')

    if echo "$payload" | gh api -X PUT -H "Accept: application/vnd.github+json" "repos/$owner/$repo_name/contents/.jfrog/config.yml" --input - >/dev/null 2>&1; then
        echo "✅ .jfrog/config.yml updated in $owner/$repo_name@$branch"
    else
        echo "⚠️  Failed to update .jfrog/config.yml in $owner/$repo_name (continuing)"
    fi
}

echo "🔧 Propagating application keys to service repositories (.jfrog/config.yml)"
for app_data in "${BOOKVERSE_APPLICATIONS[@]}"; do
    IFS='|' read -r app_key _rest <<< "$app_data"
    update_repo_jfrog_config "$app_key"
done

echo "✅ Repository configuration updates completed"