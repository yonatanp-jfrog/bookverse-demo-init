#!/usr/bin/env bash

set -e

source "$(dirname "$0")/config.sh"
source "$(dirname "$0")/common.sh"
source "$(dirname "$0")/cleanup_project_based.sh"

PHASE="${1:-}"
DRY_RUN="${2:-false}"

echo "🗑️ Starting real-time cleanup phase: $PHASE"
echo "🔄 Mode: $([ "$DRY_RUN" == "true" ] && echo "DRY RUN (preview)" || echo "EXECUTE")"

# Initialize global counters
successful_deletions=0
failed_deletions=0
builds_not_found=0
total_resources=0

# Define the execute_deletion function for real-time cleanup
execute_deletion() {
    local resource_type="$1"
    local resource_name="$2"
    local api_endpoint="$3"
    local description="$4"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "🔍 [DRY RUN] Would delete $resource_type: $resource_name"
        echo "    API: DELETE ${JFROG_URL}${api_endpoint}"
        return 0
    fi
    
    echo "Removing $description: $resource_name"
    
    local delete_response=$(mktemp)
    local delete_code=$(curl -s \
        --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
        -X DELETE \
        -w "%{http_code}" -o "$delete_response" \
        "${JFROG_URL}${api_endpoint}")
    
    if [[ "$delete_code" -ge 200 && "$delete_code" -lt 300 ]]; then
        echo "✅ $description '$resource_name' deleted successfully"
        rm -f "$delete_response"
        return 0
    elif [[ "$delete_code" -eq 404 ]]; then
        echo "ℹ️  $description '$resource_name' not found (already deleted or never existed)"
        rm -f "$delete_response"
        return 0
    elif [[ "$delete_code" -eq 400 ]]; then
        # Check if it's a dependency error
        local error_msg=$(cat "$delete_response" 2>/dev/null || echo "")
        if echo "$error_msg" | grep -q "contains versions\|has dependencies\|in use"; then
            echo "⚠️ $description '$resource_name' has dependencies that need to be removed first"
            echo "Error: $error_msg"
            rm -f "$delete_response"
            return 1
        else
            echo "❌ Failed to delete $description '$resource_name' (HTTP $delete_code - Bad Request)"
            echo "Response: $(cat "$delete_response")"
            rm -f "$delete_response"
            return 1
        fi
    else
        echo "❌ Failed to delete $description '$resource_name' (HTTP $delete_code)"
        echo "Response: $(cat "$delete_response")"
        rm -f "$delete_response"
        return 1
    fi
}

case "$PHASE" in
    "app_versions")
        echo "📱 Cleaning up application versions using real-time discovery..."
        
        # Use the real-time discovery function
        if ! discover_project_applications; then
            echo "❌ Failed to discover applications for project '$PROJECT_KEY'"
            exit 1
        fi
        
        if [[ -f "$TEMP_DIR/project_applications.txt" && -s "$TEMP_DIR/project_applications.txt" ]]; then
            total_resources=$(wc -l < "$TEMP_DIR/project_applications.txt")
            echo "📊 Found $total_resources applications to process for version cleanup"
            
            while read -r app_name; do
                if [[ -n "$app_name" ]]; then
                    echo "Processing application versions: $app_name"
                    
                    if [[ "$DRY_RUN" == "true" ]]; then
                        echo "  🔍 [DRY RUN] Would delete all versions of application: $app_name"
                        successful_deletions=$((successful_deletions + 1))
                    else
                        # Get versions for this application
                        versions_response=$(mktemp)
                        versions_code=$(curl -s \
                            --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
                            -X GET \
                            -w "%{http_code}" -o "$versions_response" \
                            "${JFROG_URL}/apptrust/api/v1/applications/${app_name}/versions")
                        
                        if [[ "$versions_code" -eq 200 ]]; then
                            # Parse versions and delete each one individually
                            version_count=$(jq -r '.versions | length' "$versions_response" 2>/dev/null || echo "0")
                            echo "  📋 Found $version_count versions for application '$app_name'"
                            
                            if [[ "$version_count" -gt 0 ]]; then
                                local app_success=0
                                local app_failed=0
                                
                                # Extract version names and delete each one using array instead of while loop
                                echo "  🔍 DEBUG: Parsing versions from response..." >&2
                                
                                # Read version names into an array to avoid subshell issues
                                mapfile -t version_array < <(jq -r '.versions[]?.version' "$versions_response" 2>/dev/null || true)
                                
                                if [[ ${#version_array[@]} -eq 0 ]]; then
                                    echo "  ⚠️  No version names could be parsed from response" >&2
                                    echo "  🔍 DEBUG: Response content: $(cat "$versions_response")" >&2
                                else
                                    echo "  🔍 DEBUG: Found ${#version_array[@]} version names to delete" >&2
                                fi
                                
                                # Delete each version
                                for version_name in "${version_array[@]}"; do
                                    if [[ -n "$version_name" ]]; then
                                        echo "    🗑️  Deleting version: $version_name"
                                        version_delete_code=$(curl -s \
                                            --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
                                            -X DELETE \
                                            -w "%{http_code}" \
                                            "${JFROG_URL}/apptrust/api/v1/applications/${app_name}/versions/${version_name}")
                                        
                                        if [[ "$version_delete_code" -ge 200 && "$version_delete_code" -lt 300 ]]; then
                                            echo "    ✅ Version '$version_name' deleted successfully"
                                            ((app_success++))
                                        elif [[ "$version_delete_code" -eq 404 ]]; then
                                            echo "    ℹ️  Version '$version_name' not found (already deleted)"
                                            ((app_success++))
                                        else
                                            echo "    ❌ Failed to delete version '$version_name' (HTTP $version_delete_code)"
                                            ((app_failed++))
                                        fi
                                    fi
                                done
                                
                                # Note: The while loop runs in a subshell, so we can't update outer counters directly
                                # We'll do a final check by re-querying the versions
                                final_check_code=$(curl -s \
                                    --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
                                    -X GET \
                                    -w "%{http_code}" -o /dev/null \
                                    "${JFROG_URL}/apptrust/api/v1/applications/${app_name}/versions")
                                
                                if [[ "$final_check_code" -eq 404 ]] || [[ "$final_check_code" -eq 200 ]]; then
                                    # Check if any versions remain
                                    remaining_response=$(mktemp)
                                    remaining_code=$(curl -s \
                                        --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
                                        -X GET \
                                        -w "%{http_code}" -o "$remaining_response" \
                                        "${JFROG_URL}/apptrust/api/v1/applications/${app_name}/versions")
                                    
                                    if [[ "$remaining_code" -eq 404 ]] || [[ "$(jq -r '.versions | length' "$remaining_response" 2>/dev/null || echo "0")" -eq 0 ]]; then
                                        echo "  ✅ All versions for application '$app_name' deleted successfully"
                                        successful_deletions=$((successful_deletions + 1))
                                    else
                                        echo "  ⚠️  Some versions for application '$app_name' may still exist"
                                        failed_deletions=$((failed_deletions + 1))
                                    fi
                                    rm -f "$remaining_response"
                                else
                                    echo "  ❌ Failed to verify version deletion for application '$app_name'"
                                    failed_deletions=$((failed_deletions + 1))
                                fi
                            else
                                echo "  ℹ️  No versions found for application '$app_name'"
                                successful_deletions=$((successful_deletions + 1))
                            fi
                        elif [[ "$versions_code" -eq 404 ]]; then
                            echo "  ℹ️  Application '$app_name' not found (already deleted or never existed)"
                            builds_not_found=$((builds_not_found + 1))
                        else
                            echo "  ❌ Failed to get versions for application '$app_name' (HTTP $versions_code)"
                            failed_deletions=$((failed_deletions + 1))
                        fi
                        rm -f "$versions_response"
                    fi
                fi
            done < "$TEMP_DIR/project_applications.txt"
        else
            echo "📊 No applications found to process for version cleanup"
            total_resources=0
        fi
        
        # Report summary
        echo ""
        echo "📊 Application versions cleanup summary:"
        if [[ "$DRY_RUN" == "true" ]]; then
            echo "   🔍 Total applications that would be processed: $total_resources"
        else
            echo "   ✅ Successfully deleted: $successful_deletions"
            echo "   ℹ️  Not found (already deleted): $builds_not_found"
            echo "   ❌ Failed to delete: $failed_deletions"
            
            if [[ $failed_deletions -gt 0 ]]; then
                echo "❌ Some application version deletions failed!"
                exit 1
            elif [[ $total_resources -eq 0 ]]; then
                echo "ℹ️  No applications found in project"
            else
                echo "✅ All application versions cleaned up successfully"
            fi
        fi
        ;;

    "users")
        echo "👥 Cleaning up users using real-time discovery..."
        
        # Use the real-time discovery function
        if ! discover_project_users; then
            echo "❌ Failed to discover users for project '$PROJECT_KEY'"
            exit 1
        fi
        
        if [[ -f "$TEMP_DIR/project_users.txt" && -s "$TEMP_DIR/project_users.txt" ]]; then
            total_resources=$(wc -l < "$TEMP_DIR/project_users.txt")
            echo "📊 Found $total_resources users to clean up"
            
            while read -r username; do
                if [[ -n "$username" ]]; then
                    echo "Processing user: $username"
                    
                    if [[ "$DRY_RUN" == "true" ]]; then
                        echo "  🔍 [DRY RUN] Would delete user: $username"
                        successful_deletions=$((successful_deletions + 1))
                    else
                        # First remove from project
                        removal_code=$(curl -s \
                            --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
                            -X DELETE \
                            -w "%{http_code}" \
                            "${JFROG_URL}/access/api/v1/projects/${PROJECT_KEY}/users/${username}")
                        
                        # Then delete user entirely
                        deletion_code=$(curl -s \
                            --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
                            -X DELETE \
                            -w "%{http_code}" \
                            "${JFROG_URL}/access/api/v2/users/${username}")
                        
                        if [[ "$deletion_code" -ge 200 && "$deletion_code" -lt 300 ]] || [[ "$deletion_code" -eq 404 ]]; then
                            echo "  ✅ User '$username' deleted successfully"
                            successful_deletions=$((successful_deletions + 1))
                        else
                            echo "  ❌ Failed to delete user '$username' (HTTP $deletion_code)"
                            failed_deletions=$((failed_deletions + 1))
                        fi
                    fi
                fi
            done < "$TEMP_DIR/project_users.txt"
        else
            echo "📊 No users found to clean up"
            total_resources=0
        fi
        
        # Report summary
        echo ""
        echo "📊 Users cleanup summary:"
        if [[ "$DRY_RUN" == "true" ]]; then
            echo "   🔍 Total users that would be processed: $total_resources"
        else
            echo "   ✅ Successfully deleted: $successful_deletions"
            echo "   ❌ Failed to delete: $failed_deletions"
            
            if [[ $failed_deletions -gt 0 ]]; then
                echo "❌ Some user deletions failed!"
                exit 1
            elif [[ $total_resources -eq 0 ]]; then
                echo "ℹ️  No users found in project"
            else
                echo "✅ All users cleaned up successfully"
            fi
        fi
        ;;

    "domain_users")
        echo "🌐 Cleaning up domain users using real-time discovery..."
        # For domain users, we can reuse the same logic as regular users
        # since discover_project_users should find all users including domain users
        
        if ! discover_project_users; then
            echo "❌ Failed to discover users for project '$PROJECT_KEY'"
            exit 1
        fi
        
        if [[ -f "$TEMP_DIR/project_users.txt" && -s "$TEMP_DIR/project_users.txt" ]]; then
            # Filter for domain users (typically contain @ or specific patterns)
            grep '@\|domain' "$TEMP_DIR/project_users.txt" > "$TEMP_DIR/domain_users.txt" 2>/dev/null || echo "" > "$TEMP_DIR/domain_users.txt"
            
            if [[ -s "$TEMP_DIR/domain_users.txt" ]]; then
                total_resources=$(wc -l < "$TEMP_DIR/domain_users.txt")
                echo "📊 Found $total_resources domain users to clean up"
                
                while read -r username; do
                    if [[ -n "$username" ]]; then
                        echo "Processing domain user: $username"
                        
                        if [[ "$DRY_RUN" == "true" ]]; then
                            echo "  🔍 [DRY RUN] Would delete domain user: $username"
                            successful_deletions=$((successful_deletions + 1))
                        else
                            # Remove from project and delete user
                            removal_code=$(curl -s \
                                --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
                                -X DELETE \
                                -w "%{http_code}" \
                                "${JFROG_URL}/access/api/v1/projects/${PROJECT_KEY}/users/${username}")
                            
                            deletion_code=$(curl -s \
                                --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
                                -X DELETE \
                                -w "%{http_code}" \
                                "${JFROG_URL}/access/api/v2/users/${username}")
                            
                            if [[ "$deletion_code" -ge 200 && "$deletion_code" -lt 300 ]] || [[ "$deletion_code" -eq 404 ]]; then
                                echo "  ✅ Domain user '$username' deleted successfully"
                                successful_deletions=$((successful_deletions + 1))
                            else
                                echo "  ❌ Failed to delete domain user '$username' (HTTP $deletion_code)"
                                failed_deletions=$((failed_deletions + 1))
                            fi
                        fi
                    fi
                done < "$TEMP_DIR/domain_users.txt"
            else
                echo "📊 No domain users found to clean up"
                total_resources=0
            fi
        else
            echo "📊 No users found to check for domain users"
            total_resources=0
        fi
        
        # Report summary
        echo ""
        echo "📊 Domain users cleanup summary:"
        if [[ "$DRY_RUN" == "true" ]]; then
            echo "   🔍 Total domain users that would be processed: $total_resources"
        else
            echo "   ✅ Successfully deleted: $successful_deletions"
            echo "   ❌ Failed to delete: $failed_deletions"
            
            if [[ $failed_deletions -gt 0 ]]; then
                echo "❌ Some domain user deletions failed!"
                exit 1
            elif [[ $total_resources -eq 0 ]]; then
                echo "ℹ️  No domain users found in project"
            else
                echo "✅ All domain users cleaned up successfully"
            fi
        fi
        ;;

    "stages")
        echo "🏗️ Cleaning up stages using real-time discovery..."
        
        # Use the real-time discovery function
        if ! discover_project_stages; then
            echo "❌ Failed to discover stages for project '$PROJECT_KEY'"
            exit 1
        fi
        
        if [[ -f "$TEMP_DIR/project_stages.txt" && -s "$TEMP_DIR/project_stages.txt" ]]; then
            total_resources=$(wc -l < "$TEMP_DIR/project_stages.txt")
            echo "📊 Found $total_resources stages to clean up"
            
            while read -r stage_name; do
                if [[ -n "$stage_name" ]]; then
                    echo "Processing stage: $stage_name"
                    
                    if [[ "$DRY_RUN" == "true" ]]; then
                        echo "  🔍 [DRY RUN] Would delete stage: $stage_name"
                        successful_deletions=$((successful_deletions + 1))
                    else
                        deletion_code=$(curl -s \
                            --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
                            -X DELETE \
                            -w "%{http_code}" \
                            "${JFROG_URL}/access/api/v2/stages/${stage_name}")
                        
                        if [[ "$deletion_code" -ge 200 && "$deletion_code" -lt 300 ]]; then
                            echo "  ✅ Stage '$stage_name' deleted successfully"
                            successful_deletions=$((successful_deletions + 1))
                        elif [[ "$deletion_code" -eq 404 ]]; then
                            echo "  ℹ️  Stage '$stage_name' not found (already deleted or never existed)"
                            builds_not_found=$((builds_not_found + 1))
                        else
                            echo "  ❌ Failed to delete stage '$stage_name' (HTTP $deletion_code)"
                            failed_deletions=$((failed_deletions + 1))
                        fi
                    fi
                fi
            done < "$TEMP_DIR/project_stages.txt"
        else
            echo "📊 No stages found to clean up"
            total_resources=0
        fi
        
        # Report summary
        echo ""
        echo "📊 Stages cleanup summary:"
        if [[ "$DRY_RUN" == "true" ]]; then
            echo "   🔍 Total stages that would be processed: $total_resources"
        else
            echo "   ✅ Successfully deleted: $successful_deletions"
            echo "   ℹ️  Not found (already deleted): $builds_not_found"
            echo "   ❌ Failed to delete: $failed_deletions"
            
            if [[ $failed_deletions -gt 0 ]]; then
                echo "❌ Some stage deletions failed!"
                exit 1
            elif [[ $total_resources -eq 0 ]]; then
                echo "ℹ️  No stages found in project"
            else
                echo "✅ All stages cleaned up successfully"
            fi
        fi
        ;;

    "oidc")
        echo "🔐 Cleaning up OIDC integrations using real-time discovery..."
        
        # Use the real-time discovery function
        if ! discover_project_oidc; then
            echo "❌ Failed to discover OIDC integrations for project '$PROJECT_KEY'"
            exit 1
        fi
        
        if [[ -f "$TEMP_DIR/project_oidc.txt" && -s "$TEMP_DIR/project_oidc.txt" ]]; then
            total_resources=$(wc -l < "$TEMP_DIR/project_oidc.txt")
            echo "📊 Found $total_resources OIDC integrations to clean up"
            
            while read -r integration_name; do
                if [[ -n "$integration_name" ]]; then
                    echo "Processing OIDC integration: $integration_name"
                    
                    if [[ "$DRY_RUN" == "true" ]]; then
                        echo "  🔍 [DRY RUN] Would delete OIDC integration: $integration_name"
                        successful_deletions=$((successful_deletions + 1))
                    else
                        deletion_code=$(curl -s \
                            --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
                            -X DELETE \
                            -w "%{http_code}" \
                            "${JFROG_URL}/access/api/v1/oidc/${integration_name}")
                        
                        if [[ "$deletion_code" -ge 200 && "$deletion_code" -lt 300 ]]; then
                            echo "  ✅ OIDC integration '$integration_name' deleted successfully"
                            successful_deletions=$((successful_deletions + 1))
                        elif [[ "$deletion_code" -eq 404 ]]; then
                            echo "  ℹ️  OIDC integration '$integration_name' not found (already deleted or never existed)"
                            builds_not_found=$((builds_not_found + 1))
                        else
                            echo "  ❌ Failed to delete OIDC integration '$integration_name' (HTTP $deletion_code)"
                            failed_deletions=$((failed_deletions + 1))
                        fi
                    fi
                fi
            done < "$TEMP_DIR/project_oidc.txt"
        else
            echo "📊 No OIDC integrations found to clean up"
            total_resources=0
        fi
        
        # Report summary
        echo ""
        echo "📊 OIDC integrations cleanup summary:"
        if [[ "$DRY_RUN" == "true" ]]; then
            echo "   🔍 Total OIDC integrations that would be processed: $total_resources"
        else
            echo "   ✅ Successfully deleted: $successful_deletions"
            echo "   ℹ️  Not found (already deleted): $builds_not_found"
            echo "   ❌ Failed to delete: $failed_deletions"
            
            if [[ $failed_deletions -gt 0 ]]; then
                echo "❌ Some OIDC integration deletions failed!"
                exit 1
            elif [[ $total_resources -eq 0 ]]; then
                echo "ℹ️  No OIDC integrations found in project"
            else
                echo "✅ All OIDC integrations cleaned up successfully"
            fi
        fi
        ;;
        
    "builds")
        echo "🔧 Cleaning up builds using real-time discovery..."
        
        # Use the real-time discovery function
        discover_project_builds
        
        if [[ -f "$TEMP_DIR/project_builds.txt" && -s "$TEMP_DIR/project_builds.txt" ]]; then
            total_resources=$(wc -l < "$TEMP_DIR/project_builds.txt")
            echo "📊 Found $total_resources builds to clean up"
            
            while read -r build_name; do
                if [[ -n "$build_name" ]]; then
                    echo "Processing build: $build_name"
                    
                    if [[ "$DRY_RUN" == "true" ]]; then
                        echo "  🔍 [DRY RUN] Would delete build: $build_name"
                        successful_deletions=$((successful_deletions + 1))
                    else
                        # URL encode the build name for the API call
                        encoded_build_name=$(printf '%s' "$build_name" | jq -sRr @uri)
                        
                        # Capture the output to determine success type
                        deletion_output=$(mktemp)
                        execute_deletion "build" "$build_name" "/artifactory/api/build/${encoded_build_name}?deleteAll=1&project=${PROJECT_KEY}" "build" 2>&1 | tee "$deletion_output"
                        deletion_exit_code=${PIPESTATUS[0]}
                        
                        if [[ $deletion_exit_code -eq 0 ]]; then
                            # Check the actual output to determine if it was successfully deleted or not found
                            if grep -q "✅.*deleted successfully" "$deletion_output"; then
                                successful_deletions=$((successful_deletions + 1))
                            elif grep -q "ℹ️.*not found" "$deletion_output"; then
                                builds_not_found=$((builds_not_found + 1))
                            else
                                # This shouldn't happen if execute_deletion works correctly, but handle it
                                successful_deletions=$((successful_deletions + 1))
                            fi
                        else
                            echo "❌ Failed to delete build: $build_name"
                            failed_deletions=$((failed_deletions + 1))
                        fi
                        rm -f "$deletion_output"
                    fi
                fi
            done < "$TEMP_DIR/project_builds.txt"
        else
            echo "📊 No builds found to clean up"
            total_resources=0
        fi
        
        # Report summary
        echo ""
        echo "📊 Build cleanup summary:"
        echo "   Total builds processed: $total_resources"
        
        if [[ "$DRY_RUN" == "true" ]]; then
            echo "   🔍 [DRY RUN] All $total_resources builds would be processed"
        else
            echo "   ✅ Successfully deleted: $successful_deletions"
            echo "   ℹ️  Not found (already deleted): $builds_not_found"
            echo "   ❌ Failed to delete: $failed_deletions"
            
            if [[ $failed_deletions -gt 0 ]]; then
                echo "❌ Some build deletions failed!"
                exit 1
            elif [[ $total_resources -eq 0 ]]; then
                echo "ℹ️  No builds found in project"
            else
                echo "✅ All builds cleaned up successfully"
            fi
        fi
        ;;
        
    "repositories")
        echo "📦 Cleaning up repositories using real-time discovery..."
        
        # Use the real-time discovery function
        discover_project_repositories
        
        if [[ -f "$TEMP_DIR/project_repositories.txt" && -s "$TEMP_DIR/project_repositories.txt" ]]; then
            total_resources=$(wc -l < "$TEMP_DIR/project_repositories.txt")
            echo "📊 Found $total_resources repositories to clean up"
            
            while read -r repo_key; do
                if [[ -n "$repo_key" ]]; then
                    echo "Processing repository: $repo_key"
                    
                    if [[ "$DRY_RUN" == "true" ]]; then
                        echo "  🔍 [DRY RUN] Would delete repository: $repo_key"
                        successful_deletions=$((successful_deletions + 1))
                    else
                        deletion_output=$(mktemp)
                        execute_deletion "repository" "$repo_key" "/artifactory/api/repositories/${repo_key}" "repository" 2>&1 | tee "$deletion_output"
                        deletion_exit_code=${PIPESTATUS[0]}
                        
                        if [[ $deletion_exit_code -eq 0 ]]; then
                            if grep -q "✅.*deleted successfully" "$deletion_output"; then
                                successful_deletions=$((successful_deletions + 1))
                            elif grep -q "ℹ️.*not found" "$deletion_output"; then
                                builds_not_found=$((builds_not_found + 1))
                            else
                                successful_deletions=$((successful_deletions + 1))
                            fi
                        else
                            echo "❌ Failed to delete repository: $repo_key"
                            failed_deletions=$((failed_deletions + 1))
                        fi
                        rm -f "$deletion_output"
                    fi
                fi
            done < "$TEMP_DIR/project_repositories.txt"
        else
            echo "📊 No repositories found to clean up"
            total_resources=0
        fi
        
        # Report summary
        echo ""
        echo "📊 Repository cleanup summary:"
        echo "   Total repositories processed: $total_resources"
        
        if [[ "$DRY_RUN" == "true" ]]; then
            echo "   🔍 [DRY RUN] All $total_resources repositories would be processed"
        else
            echo "   ✅ Successfully deleted: $successful_deletions"
            echo "   ℹ️  Not found (already deleted): $builds_not_found"
            echo "   ❌ Failed to delete: $failed_deletions"
            
            if [[ $failed_deletions -gt 0 ]]; then
                echo "❌ Some repository deletions failed!"
                exit 1
            elif [[ $total_resources -eq 0 ]]; then
                echo "ℹ️  No repositories found in project"
            else
                echo "✅ All repositories cleaned up successfully"
            fi
        fi
        ;;
        
    "applications")
        echo "🚀 Cleaning up applications using real-time discovery..."
        
        # Use the real-time discovery function
        discover_project_applications
        
        if [[ -f "$TEMP_DIR/project_applications.txt" && -s "$TEMP_DIR/project_applications.txt" ]]; then
            total_resources=$(wc -l < "$TEMP_DIR/project_applications.txt")
            echo "📊 Found $total_resources applications to clean up"
            
            while read -r app_name; do
                if [[ -n "$app_name" ]]; then
                    echo "Processing application: $app_name"
                    
                    if [[ "$DRY_RUN" == "true" ]]; then
                        echo "  🔍 [DRY RUN] Would delete application: $app_name"
                        successful_deletions=$((successful_deletions + 1))
                    else
                        deletion_output=$(mktemp)
                        execute_deletion "application" "$app_name" "/apptrust/api/v1/applications/${app_name}" "application" 2>&1 | tee "$deletion_output"
                        deletion_exit_code=${PIPESTATUS[0]}
                        
                        if [[ $deletion_exit_code -eq 0 ]]; then
                            if grep -q "✅.*deleted successfully" "$deletion_output"; then
                                successful_deletions=$((successful_deletions + 1))
                            elif grep -q "ℹ️.*not found" "$deletion_output"; then
                                builds_not_found=$((builds_not_found + 1))
                            else
                                successful_deletions=$((successful_deletions + 1))
                            fi
                        else
                            echo "❌ Failed to delete application: $app_name"
                            failed_deletions=$((failed_deletions + 1))
                        fi
                        rm -f "$deletion_output"
                    fi
                fi
            done < "$TEMP_DIR/project_applications.txt"
        else
            echo "📊 No applications found to clean up"
            total_resources=0
        fi
        
        # Report summary
        echo ""
        echo "📊 Application cleanup summary:"
        echo "   Total applications processed: $total_resources"
        
        if [[ "$DRY_RUN" == "true" ]]; then
            echo "   🔍 [DRY RUN] All $total_resources applications would be processed"
        else
            echo "   ✅ Successfully deleted: $successful_deletions"
            echo "   ℹ️  Not found (already deleted): $builds_not_found"
            echo "   ❌ Failed to delete: $failed_deletions"
            
            if [[ $failed_deletions -gt 0 ]]; then
                echo "❌ Some application deletions failed!"
                exit 1
            elif [[ $total_resources -eq 0 ]]; then
                echo "ℹ️  No applications found in project"
            else
                echo "✅ All applications cleaned up successfully"
            fi
        fi
        ;;
        
    "project")
        echo "🎯 Cleaning up project using real-time discovery..."
        
        if [[ "$DRY_RUN" == "true" ]]; then
            echo "🔍 [DRY RUN] Would delete project: $PROJECT_KEY"
        else
            echo "Removing project: $PROJECT_KEY"
            if execute_deletion "project" "$PROJECT_KEY" "/access/api/v1/projects/$PROJECT_KEY" "project"; then
                echo "✅ Project '$PROJECT_KEY' deleted successfully"
            else
                echo "❌ Failed to delete project '$PROJECT_KEY'"
                exit 1
            fi
        fi
        ;;
        
    *)
        echo "❌ Unknown cleanup phase: $PHASE"
        echo "Supported phases: app_versions, users, domain_users, oidc, stages, builds, repositories, applications, project"
        exit 1
        ;;
esac

echo "✅ Cleanup phase '$PHASE' completed"
