#!/usr/bin/env bash

# =============================================================================
# SIMPLIFIED REPOSITORIES CREATION SCRIPT
# =============================================================================
# Creates BookVerse repositories without shared utility dependencies
# =============================================================================

set -e

# Load configuration
source "$(dirname "$0")/config.sh"

echo ""
echo "🚀 Creating repositories for BookVerse microservices platform"
echo "🔧 Project: $PROJECT_KEY"
echo "🔧 JFrog URL: $JFROG_URL"
echo ""

# Repository creation function
create_repository() {
    local service="$1"
    local package_type="$2"
    local repo_type="$3"
    
    local repo_key="${PROJECT_KEY}-${service}-${package_type}-${repo_type}-local"
    
    # Build repository configuration (release repos don't need environment restrictions)
    if [[ "$repo_type" == "internal" ]]; then
        # Internal repositories are restricted to specific environments
        local environments="\"${PROJECT_KEY}-DEV\", \"${PROJECT_KEY}-QA\", \"${PROJECT_KEY}-STAGING\""
        local repo_config=$(jq -n \
            --arg key "$repo_key" \
            --arg rclass "local" \
            --arg packageType "$package_type" \
            --arg description "Repository for $service $package_type packages ($repo_type)" \
            --arg projectKey "$PROJECT_KEY" \
            --argjson environments "[$environments]" \
            '{
                "key": $key,
                "rclass": $rclass,
                "packageType": $packageType,
                "description": $description,
                "projectKey": $projectKey,
                "environments": $environments
            }')
    else
        # Release repositories are used for production; attach to PROD environment
        local environments='["PROD"]'
        local repo_config=$(jq -n \
            --arg key "$repo_key" \
            --arg rclass "local" \
            --arg packageType "$package_type" \
            --arg description "Repository for $service $package_type packages ($repo_type)" \
            --arg projectKey "$PROJECT_KEY" \
            --argjson environments "$environments" \
            '{
                "key": $key,
                "rclass": $rclass,
                "packageType": $packageType,
                "description": $description,
                "projectKey": $projectKey,
                "environments": $environments
            }')
    fi
    
    echo "Creating repository: $repo_key"
    
    # Create repository
    local temp_response=$(mktemp)
    local response_code=$(curl -s --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
        --header "X-JFrog-Project: ${PROJECT_KEY}" \
        --header "Content-Type: application/json" \
        -X PUT \
        -d "$repo_config" \
        --write-out "%{http_code}" \
        --output "$temp_response" \
        "${JFROG_URL}/artifactory/api/repositories/${repo_key}")
    
    case "$response_code" in
        200|201)
            echo "✅ Repository '$repo_key' created successfully (HTTP $response_code)"
            ;;
        409)
            echo "✅ Repository '$repo_key' already exists and is configured"
            ;;
        400)
            # Check if it's the "already exists" error which should be treated as success
            if grep -q -i "already exists\|repository.*exists\|case insensitive.*already exists" "$temp_response"; then
                echo "✅ Repository '$repo_key' already exists (case-insensitive match)"
            else
                echo "⚠️  Repository '$repo_key' creation issue (HTTP $response_code)"
                if [[ "${VERBOSITY:-0}" -ge 1 ]]; then
                    echo "Response body: $(cat "$temp_response")"
                    echo "Repository config sent:"
                    echo "$repo_config" | jq .
                fi
                echo "💡 Repository may exist with different configuration or permissions issue"
                rm -f "$temp_response"
                # Don't return 1 for repos - they're often pre-existing
            fi
            ;;
        *)
            echo "❌ Failed to create repository '$repo_key' (HTTP $response_code)"
            if [[ "${VERBOSITY:-0}" -ge 1 ]]; then
                echo "Response body: $(cat "$temp_response")"
                echo "Repository config sent:"
                echo "$repo_config" | jq .
            fi
            echo "💡 This may be due to permissions, API changes, or network issues"
            rm -f "$temp_response"
            return 1
            ;;
    esac
    
    rm -f "$temp_response"

    # Ensure repository has expected environment attachments (idempotent)
    local expected_envs_json
    if [[ "$repo_type" == "internal" ]]; then
        expected_envs_json=$(jq -nc --arg p "$PROJECT_KEY" '[($p+"-DEV"), ($p+"-QA"), ($p+"-STAGING")]')
    else
        expected_envs_json='["PROD"]'
    fi

    local get_resp_file=$(mktemp)
    local get_code=$(curl -s --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
        --header "X-JFrog-Project: ${PROJECT_KEY}" \
        --write-out "%{http_code}" --output "$get_resp_file" \
        "${JFROG_URL}/artifactory/api/repositories/${repo_key}")
    if [[ "$get_code" =~ ^2 ]]; then
        # Compare current environments with expected
        local envs_match
        envs_match=$(jq --argjson exp "$expected_envs_json" '(
            ( .environments // [] ) as $cur
            | ($cur | length) == ($exp | length)
            and ((($cur - $exp) | length) == 0)
            and ((($exp - $cur) | length) == 0)
        )' "$get_resp_file" 2>/dev/null || echo "false")
        if [[ "$envs_match" != "true" ]]; then
            echo "Updating environments for repository: $repo_key"
            local updated_config
            updated_config=$(jq --arg projectKey "$PROJECT_KEY" --argjson envs "$expected_envs_json" \
                '.projectKey = $projectKey | .environments = $envs' "$get_resp_file")
            local up_tmp=$(mktemp)
            local up_code=$(curl -s --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
                --header "X-JFrog-Project: ${PROJECT_KEY}" \
                --header "Content-Type: application/json" -X POST \
                -d "$updated_config" --write-out "%{http_code}" --output "$up_tmp" \
                "${JFROG_URL}/artifactory/api/repositories/${repo_key}")
            case "$up_code" in
                200)
                    echo "✅ Repository '$repo_key' environments updated"
                    ;;
                *)
                    echo "⚠️  Failed to update environments for '$repo_key' (HTTP $up_code)"
                    if [[ "${VERBOSITY:-0}" -ge 1 ]]; then
                        echo "Response body: $(cat "$up_tmp")"
                    fi
                    ;;
            esac
            rm -f "$up_tmp"
        fi
    else
        echo "⚠️  Could not fetch repository '$repo_key' to verify environments (HTTP $get_code)"
    fi
    rm -f "$get_resp_file"
}

# Services and their package types
declare -A SERVICE_PACKAGES=(
    ["inventory"]="python docker"
    ["recommendations"]="python docker"
    ["checkout"]="python docker"
    ["platform"]="maven"
    ["web"]="npm docker"
    ["helm"]="helm"
)

echo "Creating repositories for services..."
echo ""

# Create project-level generic repo for shared artifacts (internal)
{
    repo_key="${PROJECT_KEY}-generic-internal-local"
    echo "Creating repository: $repo_key"
    environments="\"${PROJECT_KEY}-DEV\", \"${PROJECT_KEY}-QA\", \"${PROJECT_KEY}-STAGING\""
    repo_config=$(jq -n \
        --arg key "$repo_key" \
        --arg rclass "local" \
        --arg packageType "generic" \
        --arg description "Generic repository for shared artifacts (internal)" \
        --arg projectKey "$PROJECT_KEY" \
        --argjson environments "[$environments]" \
        '{
            "key": $key,
            "rclass": $rclass,
            "packageType": $packageType,
            "description": $description,
            "projectKey": $projectKey,
            "environments": $environments
        }')

    temp_response=$(mktemp)
    response_code=$(curl -s --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
        --header "Content-Type: application/json" \
        -X PUT \
        -d "$repo_config" \
        --write-out "%{http_code}" \
        --output "$temp_response" \
        "${JFROG_URL}/artifactory/api/repositories/${repo_key}")

    case "$response_code" in
        200|201)
            echo "✅ Repository '$repo_key' created successfully (HTTP $response_code)"
            ;;
        409)
            echo "✅ Repository '$repo_key' already exists and is configured"
            ;;
        400)
            if grep -q -i "already exists\|repository.*exists\|case insensitive.*already exists" "$temp_response"; then
                echo "✅ Repository '$repo_key' already exists (case-insensitive match)"
            else
                echo "⚠️  Repository '$repo_key' creation issue (HTTP $response_code)"
                if [[ "${VERBOSITY:-0}" -ge 1 ]]; then
                    echo "Response body: $(cat "$temp_response")"
                    echo "Repository config sent:"
                    echo "$repo_config" | jq .
                fi
            fi
            ;;
        *)
            echo "❌ Failed to create repository '$repo_key' (HTTP $response_code)"
            if [[ "${VERBOSITY:-0}" -ge 1 ]]; then
                echo "Response body: $(cat "$temp_response")"
                echo "Repository config sent:"
                echo "$repo_config" | jq .
            fi
            ;;
    esac

    rm -f "$temp_response"
}

# Create repositories for each service
for service in "${!SERVICE_PACKAGES[@]}"; do
    echo "Processing service: $service (creating ${package_type} repositories)"
    
    # Get package types for this service
    package_types="${SERVICE_PACKAGES[$service]}"
    
    for package_type in $package_types; do
        # Create internal repository (for DEV/QA/STAGING)
        create_repository "$service" "$package_type" "internal"
        
        # Create release repository (for PROD)  
        create_repository "$service" "$package_type" "release"
    done
    
    echo ""
done

echo "✅ Service repositories creation completed successfully!"
echo ""
echo "ℹ️ Dependency repositories and prepopulation are now run by workflow steps."