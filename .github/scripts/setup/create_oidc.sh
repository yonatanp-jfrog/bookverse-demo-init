#!/usr/bin/env bash

# =============================================================================
# SIMPLIFIED OIDC INTEGRATION SCRIPT
# =============================================================================
# Creates OIDC integrations without shared utility dependencies
# =============================================================================

set -e

# Load configuration
source "$(dirname "$0")/config.sh"

echo ""
echo "🚀 Creating OIDC integrations and identity mappings"
echo "🔧 Project: $PROJECT_KEY"
echo "🔧 JFrog URL: $JFROG_URL"
echo ""

# OIDC configuration definitions: service|username|display_name
OIDC_CONFIGS=(
    "inventory|frank.inventory@bookverse.com|BookVerse Inventory"
    "recommendations|grace.ai@bookverse.com|BookVerse Recommendations" 
    "checkout|pipeline.checkout@bookverse.com|BookVerse Checkout"
    "platform|diana.architect@bookverse.com|BookVerse Platform"
    "web|alice.developer@bookverse.com|BookVerse Web"
)

# Helper: check if an OIDC integration already exists (best-effort via list API)
integration_exists() {
    local name="$1"
    local tmp=$(mktemp)
    local code=$(curl -s \
        --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
        --header "Accept: application/json" \
        -w "%{http_code}" -o "$tmp" \
        "${JFROG_URL}/access/api/v1/oidc")
    if [[ "$code" -ge 200 && "$code" -lt 300 ]]; then
        if grep -q '"name"\s*:\s*"'"$name"'"' "$tmp" 2>/dev/null; then
            rm -f "$tmp"
            return 0
        fi
    fi
    rm -f "$tmp"
    return 1
}

# Helper: check if identity mapping exists for an integration (best-effort)
mapping_exists() {
    local integration_name="$1"
    local tmp=$(mktemp)
    local code=$(curl -s \
        --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
        --header "Accept: application/json" \
        -w "%{http_code}" -o "$tmp" \
        "${JFROG_URL}/access/api/v1/oidc/${integration_name}/identity_mappings")
    if [[ "$code" -ge 200 && "$code" -lt 300 ]]; then
        if grep -q '"name"\s*:\s*"'"$integration_name"'"' "$tmp" 2>/dev/null; then
            rm -f "$tmp"
            return 0
        fi
    fi
    rm -f "$tmp"
    return 1
}

# Function to create OIDC integration (idempotent + retries)
create_oidc_integration() {
    local service_name="$1"
    local username="$2"
    local display_name="$3"
    # Integration name should have 'github' at the end per requirements
    local integration_name="${PROJECT_KEY}-${service_name}-github"
    
    echo "Creating OIDC integration: $integration_name"
    echo "  Service: $service_name"
    echo "  User: $username"
    echo "  Display: $display_name"
    echo "  Provider: GitHub"
    
    # Build provider-specific OIDC integration payload (GitHub), with fallback to minimal if unsupported
    local org_name="${ORG:-yonatanp-jfrog}"
    local integration_payload_github=$(jq -n \
        --arg name "$integration_name" \
        --arg issuer_url "https://token.actions.githubusercontent.com" \
        --arg provider_type "GitHub" \
        --arg projectKey "$PROJECT_KEY" \
        --arg audience "$JFROG_URL" \
        --arg organization "$org_name" \
        --arg description "OIDC integration for GitHub Actions" \
        '{
            "name": $name,
            "provider_type": $provider_type,
            "issuer_url": $issuer_url,
            "projectKey": $projectKey,
            "audience": $audience,
            "organization": $organization,
            "description": $description
        }')
    local integration_payload_minimal=$(jq -n \
        --arg name "$integration_name" \
        --arg issuer_url "https://token.actions.githubusercontent.com" \
        '{
            "name": $name,
            "issuer_url": $issuer_url
        }')
    
    # If integration appears to exist already, skip creation
    if integration_exists "$integration_name"; then
        echo "⚠️  OIDC integration '$integration_name' already exists (pre-check)"
    else
        # Attempt GitHub provider first; on 400 fallback to minimal payload; retry 5xx up to 3 times
        local temp_response=$(mktemp)
        local response_code=$(curl -s --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
            --header "Content-Type: application/json" \
            -X POST \
            -d "$integration_payload_github" \
            --write-out "%{http_code}" \
            --output "$temp_response" \
            "${JFROG_URL}/access/api/v1/oidc")

        case "$response_code" in
            200|201)
                echo "✅ OIDC integration '$integration_name' created successfully (GitHub provider)"
                rm -f "$temp_response"
                ;;
            409)
                echo "⚠️  OIDC integration '$integration_name' already exists (HTTP $response_code)"
                rm -f "$temp_response"
                ;;
            400)
                echo "⚠️  GitHub provider not accepted by this JFrog version. Falling back to minimal payload."
                echo "Response body: $(cat "$temp_response")"
                rm -f "$temp_response"
                # Fallback attempt (no retries on 400)
                temp_response=$(mktemp)
                response_code=$(curl -s --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
                    --header "Content-Type: application/json" \
                    -X POST \
                    -d "$integration_payload_minimal" \
                    --write-out "%{http_code}" \
                    --output "$temp_response" \
                    "${JFROG_URL}/access/api/v1/oidc")
                case "$response_code" in
                    200|201)
                        echo "✅ OIDC integration '$integration_name' created successfully (generic provider)"
                        rm -f "$temp_response"
                        ;;
                    409)
                        echo "⚠️  OIDC integration '$integration_name' already exists (HTTP $response_code)"
                        rm -f "$temp_response"
                        ;;
                    500|502|503|504)
                        echo "⚠️  Transient error creating '$integration_name' (HTTP $response_code)"
                        echo "Response body: $(cat "$temp_response")"
                        rm -f "$temp_response"
                        # Retry up to 3 times for transient errors
                        local attempt
                        for attempt in 1 2 3; do
                            temp_response=$(mktemp)
                            response_code=$(curl -s --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
                                --header "Content-Type: application/json" \
                                -X POST \
                                -d "$integration_payload_minimal" \
                                --write-out "%{http_code}" \
                                --output "$temp_response" \
                                "${JFROG_URL}/access/api/v1/oidc")
                            if [[ "$response_code" =~ ^20|^409 ]]; then
                                echo "✅ OIDC integration '$integration_name' created (after retry)"
                                rm -f "$temp_response"
                                break
                            fi
                            rm -f "$temp_response"
                            sleep $((attempt * 3))
                        done
                        ;;
                    *)
                        echo "❌ Failed to create OIDC integration '$integration_name' (HTTP $response_code)"
                        echo "Response body: $(cat "$temp_response")"
                        rm -f "$temp_response"
                        return 1
                        ;;
                esac
                ;;
            500|502|503|504)
                echo "⚠️  Transient error creating '$integration_name' (HTTP $response_code)"
                echo "Response body: $(cat "$temp_response")"
                rm -f "$temp_response"
                # Retry GitHub payload first, then fallback to minimal if still failing
                local attempt
                for attempt in 1 2 3; do
                    temp_response=$(mktemp)
                    response_code=$(curl -s --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
                        --header "Content-Type: application/json" \
                        -X POST \
                        -d "$integration_payload_github" \
                        --write-out "%{http_code}" \
                        --output "$temp_response" \
                        "${JFROG_URL}/access/api/v1/oidc")
                    if [[ "$response_code" =~ ^20|^409 ]]; then
                        echo "✅ OIDC integration '$integration_name' created (GitHub provider after retry)"
                        rm -f "$temp_response"
                        break
                    fi
                    rm -f "$temp_response"
                    sleep $((attempt * 3))
                done
                if ! [[ "$response_code" =~ ^20|^409 ]]; then
                    echo "ℹ️  Falling back to minimal payload after GitHub retries"
                    temp_response=$(mktemp)
                    response_code=$(curl -s --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
                        --header "Content-Type: application/json" \
                        -X POST \
                        -d "$integration_payload_minimal" \
                        --write-out "%{http_code}" \
                        --output "$temp_response" \
                        "${JFROG_URL}/access/api/v1/oidc")
                    if [[ "$response_code" =~ ^20|^409 ]]; then
                        echo "✅ OIDC integration '$integration_name' created (generic provider after retry)"
                        rm -f "$temp_response"
                    else
                        echo "❌ Failed to create OIDC integration '$integration_name' (HTTP $response_code)"
                        echo "Response body: $(cat "$temp_response")"
                        rm -f "$temp_response"
                        return 1
                    fi
                fi
                ;;
            *)
                echo "❌ Failed to create OIDC integration '$integration_name' (HTTP $response_code)"
                echo "Response body: $(cat "$temp_response")"
                rm -f "$temp_response"
                return 1
                ;;
        esac
    fi
    
    # Create identity mapping
    echo "Creating identity mapping for: $integration_name → $username"
    
    # Build identity mapping payload with roles-based token scope
    local mapping_payload=$(jq -n \
        --arg name "$integration_name" \
        --arg priority "1" \
        --arg repo "${org_name}/bookverse-${service_name}" \
        --arg scope "applied-permissions/roles:${PROJECT_KEY}:cicd_pipeline" \
        '{
            "name": $name,
            "description": ("Identity mapping for " + $name),
            "priority": ($priority | tonumber),
            "claims": {"repository": $repo},
            "token_spec": {"scope": $scope}
        }')

    # Debug: show first payload for troubleshooting
    echo "OIDC identity mapping payload:"; echo "$mapping_payload" | jq . || echo "$mapping_payload"
    
    # Create identity mapping (idempotent + retries)
    if mapping_exists "$integration_name"; then
        echo "⚠️  Identity mapping for '$integration_name' already exists (pre-check)"
    else
        local attempt2
        for attempt2 in 1 2 3; do
            local temp_response2=$(mktemp)
            echo "Sending identity mapping, attempt ${attempt2}..."
            echo "$mapping_payload" | jq . || echo "$mapping_payload"
            local response_code2=$(curl -s --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
                --header "Content-Type: application/json" \
                -X POST \
                -d "$mapping_payload" \
                --write-out "%{http_code}" \
                --output "$temp_response2" \
                "${JFROG_URL}/access/api/v1/oidc/${integration_name}/identity_mappings")

            case "$response_code2" in
                200|201)
                    echo "✅ Identity mapping for '$integration_name' created successfully (HTTP $response_code2)"
                    rm -f "$temp_response2"
                    break
                    ;;
                409)
                    echo "⚠️  Identity mapping for '$integration_name' already exists (HTTP $response_code2)"
                    rm -f "$temp_response2"
                    break
                    ;;
                500|502|503|504|404)
                    echo "⚠️  Transient error creating identity mapping for '$integration_name' (HTTP $response_code2)"
                    echo "Response body: $(cat "$temp_response2")"
                    rm -f "$temp_response2"
                    if mapping_exists "$integration_name"; then
                        echo "ℹ️  Detected identity mapping present after error; continuing"
                        break
                    fi
                    if [[ "$attempt2" -lt 3 ]]; then
                        sleep $((attempt2 * 3))
                        continue
                    else
                        echo "❌ Failed to create identity mapping for '$integration_name' after retries"
                        return 1
                    fi
                    ;;
                400)
                    echo "❌ Identity mapping creation returned 400"
                    echo "Response body: $(cat "$temp_response2")"
                    rm -f "$temp_response2"
                    return 1
                    ;;
                *)
                    echo "❌ Failed to create identity mapping for '$integration_name' (HTTP $response_code2)"
                    echo "Response body: $(cat "$temp_response2")"
                    rm -f "$temp_response2"
                    return 1
                    ;;
            esac
        done
    fi
    echo ""
}

echo "ℹ️  OIDC configurations to create:"
for oidc_data in "${OIDC_CONFIGS[@]}"; do
    IFS='|' read -r service_name username display_name <<< "$oidc_data"
    echo "   - $display_name → $username"
done

echo ""
echo "🚀 Processing ${#OIDC_CONFIGS[@]} OIDC configurations..."
echo ""

# Process each OIDC configuration
for oidc_data in "${OIDC_CONFIGS[@]}"; do
    IFS='|' read -r service_name username display_name <<< "$oidc_data"
    
    create_oidc_integration "$service_name" "$username" "$display_name"
done

echo "✅ OIDC integration process completed!"
echo ""
echo "🔐 OIDC Integrations Summary:"
for oidc_data in "${OIDC_CONFIGS[@]}"; do
    IFS='|' read -r service_name username display_name <<< "$oidc_data"
    echo "   - ${PROJECT_KEY}-${service_name}-github → $username"
done

echo ""
echo "🎯 OIDC integrations setup completed"
echo "   Successfully created integrations are ready for GitHub Actions"
echo "   Any integrations with validation issues may require manual setup"
echo ""