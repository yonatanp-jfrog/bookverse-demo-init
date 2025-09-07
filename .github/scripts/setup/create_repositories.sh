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

# Determine visibility for a given service (defaults to internal)
get_visibility_for_service() {
    local service_name="$1"
    case "$service_name" in
        platform)
            echo "public"
            ;;
        *)
            echo "internal"
            ;;
    esac
}

# Repository creation function
create_repository() {
    local service="$1"
    local package_type="$2"
    local repo_type="$3"
    
    local visibility
    visibility=$(get_visibility_for_service "$service")
    local stage_group
    if [[ "$repo_type" == "internal" ]]; then
        stage_group="nonprod"
    else
        stage_group="release"
    fi
    local repo_key="${PROJECT_KEY}-${service}-${visibility}-${package_type}-${stage_group}-local"
    
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

# Services and their package types (portable across older Bash versions)
SERVICES=("inventory" "recommendations" "checkout" "platform" "web" "helm")

get_packages_for_service() {
    case "$1" in
        inventory|recommendations|checkout)
            echo "python docker generic"
            ;;
        platform)
            # Platform follows Python + Docker packaging in this demo (public visibility)
            echo "python docker generic"
            ;;
        web)
            echo "npm docker generic"
            ;;
        helm)
            echo "helm generic"
            ;;
        *)
            echo ""
            ;;
    esac
}

echo "Creating repositories for services..."
echo ""

# Create repositories for each service
for service in "${SERVICES[@]}"; do
    # Get package types for this service
    package_types="$(get_packages_for_service "$service")"
    echo "Processing service: $service (creating: $package_types)"

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

# ----------------------------
# Prune old/misnamed repositories
# ----------------------------

prune_old_repositories() {
    echo ""; echo "🧹 Pruning old/misnamed local repositories (project=${PROJECT_KEY})"

    # Build EXPECTED list (compatible with macOS bash)
    local expected_file
    expected_file=$(mktemp)
    for service in "${SERVICES[@]}"; do
        package_types="$(get_packages_for_service "$service")"
        visibility="$(get_visibility_for_service "$service")"
        for package_type in $package_types; do
            for repo_type in internal release; do
                if [[ "$repo_type" == "internal" ]]; then stage_group="nonprod"; else stage_group="release"; fi
                key="${PROJECT_KEY}-${service}-${visibility}-${package_type}-${stage_group}-local"
                echo "$key" >> "$expected_file"
            done
        done
    done

    # List current local repos for the project and filter to our naming scheme
    local list_file candidates_file
    list_file=$(mktemp)
    candidates_file=$(mktemp)
    local code=$(curl -s --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
        --header "X-JFrog-Project: ${PROJECT_KEY}" \
        --header "Accept: application/json" \
        --write-out "%{http_code}" --output "$list_file" \
        "${JFROG_URL}/artifactory/api/repositories?type=local")
    if [[ "$code" -lt 200 || "$code" -ge 300 ]]; then
        echo "⚠️  Failed to list repositories (HTTP $code); skipping prune"
        rm -f "$list_file" "$candidates_file"
        return 0
    fi

    # Collect candidates: keys that belong to this project
    jq -r --arg p "${PROJECT_KEY}-" '[ .[] | select(.key|startswith($p)) | .key ] | .[]' "$list_file" 2>/dev/null > "$candidates_file" || printf '' > "$candidates_file"
    rm -f "$list_file"

    # Read candidates into an array (portable)
    CANDIDATES=()
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        CANDIDATES+=("$line")
    done < "$candidates_file"
    rm -f "$candidates_file"

    # Prune any candidate not in EXPECTED and that matches our service-repo naming convention
    local pruned=0
    for key in "${CANDIDATES[@]}"; do
        # Only consider repos that contain a visibility token and end with -local
        if [[ "$key" != *"-internal-"* && "$key" != *"-public-"* ]]; then continue; fi
        if [[ "$key" != *"-local" ]]; then continue; fi
        if grep -Fxq "$key" "$expected_file"; then continue; fi
        echo "🗑️  Deleting outdated repo: $key"
        local del_code=$(curl -s -X DELETE \
            --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
            --header "X-JFrog-Project: ${PROJECT_KEY}" \
            --write-out "%{http_code}" --output /dev/null \
            "${JFROG_URL}/artifactory/api/repositories/${key}" || echo 000)
        if [[ "$del_code" =~ ^2 ]]; then
            echo "✅ Deleted $key"
            pruned=$((pruned+1))
        else
            echo "⚠️  Failed to delete $key (HTTP $del_code)"
        fi
    done

    if [[ "$pruned" -gt 0 ]]; then
        echo "🧹 Prune complete. Removed $pruned repos."
    else
        echo "🧹 No outdated repos found to prune."
    fi

    rm -f "$expected_file"
}

prune_old_repositories