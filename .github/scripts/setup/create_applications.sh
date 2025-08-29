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
    "bookverse-inventory|BookVerse Inventory Service|Microservice responsible for managing book inventory, stock levels, and availability tracking across all BookVerse locations|high|production|inventory-team|frank.inventory@bookverse.com"
    "bookverse-recommendations|BookVerse Recommendations Service|AI-powered microservice that provides personalized book recommendations based on user preferences, reading history, and collaborative filtering|medium|production|ai-ml-team|grace.ai@bookverse.com"
    "bookverse-checkout|BookVerse Checkout Service|Secure microservice handling payment processing, order fulfillment, and transaction management for book purchases|high|production|checkout-team|henry.checkout@bookverse.com"
    "bookverse-platform|BookVerse Platform|Integrated platform solution combining all microservices with unified API gateway, monitoring, and operational tooling|high|production|platform|diana.architect@bookverse.com"
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
    
    # Create application
    local temp_response=$(mktemp)
    local response_code=$(curl -s --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
        --header "Content-Type: application/json" \
        -X POST \
        -d "$app_payload" \
        --write-out "%{http_code}" \
        --output "$temp_response" \
        "${JFROG_URL}/apptrust/api/v1/applications")
    
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
            echo "⚠️  AppTrust API server error for '$app_name' (HTTP 500) - treating as non-critical"
            echo "💡 Server-side issue with AppTrust API - applications may be created despite error"
            if [[ $VERBOSITY -ge 2 ]]; then
                echo "Response body: $(cat "$temp_response")"
            fi
            ;;
        502|503|504)
            echo "⚠️  AppTrust API unavailable for '$app_name' (HTTP $response_code) - treating as non-critical"
            echo "💡 Temporary server issue - applications may need manual verification"
            ;;
        *)
            echo "❌ Failed to create application '$app_name' (HTTP $response_code)"
            if [[ $VERBOSITY -ge 1 ]]; then
                echo "Response body: $(cat "$temp_response")"
            fi
            echo "💡 This may be due to API format changes or permission issues"
            # Don't exit on application failures - they're not critical for platform function
            ;;
    esac
    
    rm -f "$temp_response"
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