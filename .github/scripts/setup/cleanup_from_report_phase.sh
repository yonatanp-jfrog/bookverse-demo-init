#!/usr/bin/env bash


set -e

source "$(dirname "$0")/config.sh"
source "$(dirname "$0")/common.sh"

PHASE="${1:-}"
DRY_RUN="${2:-false}"
CLEANUP_REPORT_FILE="${CLEANUP_REPORT_FILE:-.github/cleanup-report.json}"

if [[ -z "$PHASE" ]]; then
    echo "❌ Usage: $0 <phase> [dry_run]" >&2
    echo "Valid phases: app_versions, builds, repositories, applications, users, domain_users, oidc, stages, project" >&2
    echo "Set dry_run=true to preview without actual deletion" >&2
    exit 1
fi

if [[ ! -f "$CLEANUP_REPORT_FILE" ]]; then
    echo "❌ Cleanup report not found: $CLEANUP_REPORT_FILE" >&2
    exit 1
fi

if [[ "$DRY_RUN" == "true" ]]; then
    echo "🔍 DRY RUN: Preview cleanup phase: $PHASE"
    echo "📋 Using report: $CLEANUP_REPORT_FILE"
    echo "⚠️  No actual deletions will be performed"
else
    echo "🗑️ Starting cleanup phase: $PHASE"
    echo "📋 Using report: $CLEANUP_REPORT_FILE"
fi

#######################################
# Execute API deletion call or preview in dry-run mode
# Arguments:
#   $1 - resource_type: Type of resource being deleted
#   $2 - resource_name: Name/ID of the resource
#   $3 - api_endpoint: API endpoint for deletion
#   $4 - description: Human-readable description of the operation
# Globals:
#   DRY_RUN - Whether to execute or just preview
#   JFROG_URL - JFrog platform URL
#   JFROG_ADMIN_TOKEN - Admin token for API access
# Returns:
#   0 if successful (or dry-run) - check output for success vs not-found
#   1 if failed - actual deletion failure
#######################################
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

cleanup_cicd_temp_user() {
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "🔍 [DRY RUN] Would check and remove temporary cicd platform admin user"
        return 0
    fi
    
    echo "🔧 Cleaning up temporary cicd platform admin user (workaround)..."
    
    local user_check_response=$(mktemp)
    local user_check_code=$(curl -s \
        --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
        --header "Accept: application/json" \
        -w "%{http_code}" -o "$user_check_response" \
        "${JFROG_URL}/access/api/v2/users/cicd")
    
    if [[ "$user_check_code" -eq 200 ]]; then
        echo "Found temporary cicd user - attempting removal..."
        
        local delete_response=$(mktemp)
        local delete_code=$(curl -s \
            --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
            -X DELETE \
            -w "%{http_code}" -o "$delete_response" \
            "${JFROG_URL}/access/api/v2/users/cicd")
        
        if [[ "$delete_code" -ge 200 && "$delete_code" -lt 300 ]]; then
            echo "✅ Temporary cicd user removed successfully"
        else
            echo "⚠️  Warning: Could not remove cicd user (HTTP $delete_code)"
            echo "Response: $(cat "$delete_response")"
            echo "💡 This user may need to be removed manually from the JFrog Platform UI"
        fi
        rm -f "$delete_response"
    else
        echo "ℹ️  Temporary cicd user not found (already removed or never created)"
    fi
    
    rm -f "$user_check_response"
    echo ""
}


case "$PHASE" in
    "app_versions")
        echo "📱 Cleaning up application versions..."
        jq -r '.plan.applications[]?.key // empty' "$CLEANUP_REPORT_FILE" | while read -r app_name; do
            if [[ -n "$app_name" ]]; then
                if [[ "$DRY_RUN" == "true" ]]; then
                    echo "🔍 [DRY RUN] Would delete all versions of application: $app_name"
                else
                    echo "🗑️ Deleting all versions of application: $app_name"
                    versions_response=$(mktemp)
                    versions_code=$(curl -s \
                        --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
                        -X GET \
                        -w "%{http_code}" -o "$versions_response" \
                        "${JFROG_URL}/apptrust/api/v1/applications/${app_name}/versions")
                    
                    if [[ "$versions_code" -eq 200 ]]; then
                        # Delete each version
                        jq -r '.versions[]?.version // empty' "$versions_response" 2>/dev/null | while read -r version; do
                            if [[ -n "$version" ]]; then
                                echo "  🗑️ Deleting version: $version"
                                delete_version_response=$(mktemp)
                                delete_version_code=$(curl -s \
                                    --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
                                    -X DELETE \
                                    -w "%{http_code}" -o "$delete_version_response" \
                                    "${JFROG_URL}/apptrust/api/v1/applications/${app_name}/versions/${version}")
                                
                                if [[ "$delete_version_code" -ge 200 && "$delete_version_code" -lt 300 ]]; then
                                    echo "  ✅ Version '$version' deleted successfully"
                                elif [[ "$delete_version_code" -eq 404 ]]; then
                                    echo "  ℹ️  Version '$version' not found (already deleted)"
                                else
                                    echo "  ⚠️ Failed to delete version '$version' (HTTP $delete_version_code)"
                                fi
                                rm -f "$delete_version_response"
                            fi
                        done
                    elif [[ "$versions_code" -eq 404 ]]; then
                        echo "  ℹ️  Application '$app_name' not found or has no versions"
                    else
                        echo "  ⚠️ Failed to get versions for application '$app_name' (HTTP $versions_code)"
                    fi
                    rm -f "$versions_response"
                fi
            fi
        done
        ;;

    "users")
        echo "👥 Cleaning up project users..."
        jq -r '.plan.users[]?.name // empty' "$CLEANUP_REPORT_FILE" | while read -r username; do
            if [[ -n "$username" ]]; then
                # Note: Project users are removed from project, not deleted globally
                if [[ "$DRY_RUN" == "true" ]]; then
                    echo "🔍 [DRY RUN] Would remove user from project: $username"
                else
                    echo "Removing user from project: $username"
                    execute_deletion "user" "$username" "/access/api/v1/projects/${PROJECT_KEY}/users/${username}" "project user"
                fi
            fi
        done
        ;;
        
    "domain_users")
        echo "👥 Cleaning up domain users..."
        jq -r '.plan.domain_users[]? // empty' "$CLEANUP_REPORT_FILE" | while read -r username; do
            if [[ -n "$username" ]]; then
                execute_deletion "user" "$username" "/access/api/v2/users/${username}" "domain user"
            fi
        done
        
        cleanup_cicd_temp_user
        ;;
        
    "oidc")
        echo "🔐 Cleaning up OIDC integrations..."
        jq -r '.plan.oidc[]? // empty' "$CLEANUP_REPORT_FILE" | while read -r integration_name; do
            if [[ -n "$integration_name" ]]; then
                execute_deletion "oidc" "$integration_name" "/access/api/v1/oidc/${integration_name}" "OIDC integration"
            fi
        done
        ;;
        
    "repositories")
        echo "📦 Cleaning up repositories..."
        
        # Track success/failure counts for better reporting
        total_repos=0
        successful_deletions=0
        failed_deletions=0
        repos_not_found=0
        failed_repo_list=""
        
        # Count total repositories first
        total_repos=$(jq -r '.plan.repositories[]?.key // empty' "$CLEANUP_REPORT_FILE" | grep -c . || echo "0")
        echo "📊 Found $total_repos repositories to clean up"
        
        # Process each repository and track results
        while read -r repo_key; do
            if [[ -n "$repo_key" ]]; then
                echo "Processing repository: $repo_key"
                
                # Capture the output to determine success type
                deletion_output=$(mktemp)
                execute_deletion "repository" "$repo_key" "/artifactory/api/repositories/${repo_key}" "repository" 2>&1 | tee "$deletion_output"
                deletion_exit_code=${PIPESTATUS[0]}
                if [[ $deletion_exit_code -eq 0 ]]; then
                    if [[ "$DRY_RUN" == "true" ]]; then
                        echo "  🔍 [DRY RUN] Would delete repository: $repo_key"
                    else
                        # Check the actual output to determine if it was successfully deleted or not found
                        if grep -q "✅.*deleted successfully" "$deletion_output"; then
                            ((successful_deletions++))
                        elif grep -q "ℹ️.*not found" "$deletion_output"; then
                            ((repos_not_found++))
                        else
                            # This shouldn't happen if execute_deletion works correctly, but handle it
                            ((successful_deletions++))
                        fi
                    fi
                else
                    echo "❌ Failed to delete repository: $repo_key"
                    ((failed_deletions++))
                    if [[ -z "$failed_repo_list" ]]; then
                        failed_repo_list="$repo_key"
                    else
                        failed_repo_list="$failed_repo_list, $repo_key"
                    fi
                fi
                rm -f "$deletion_output"
            fi
        done < <(jq -r '.plan.repositories[]?.key // empty' "$CLEANUP_REPORT_FILE")
        
        # Report summary
        echo ""
        echo "📊 Repository cleanup summary:"
        echo "   Total repositories processed: $total_repos"
        
        if [[ "$DRY_RUN" == "true" ]]; then
            echo "   🔍 [DRY RUN] All $total_repos repositories would be processed"
        else
            echo "   ✅ Successfully deleted: $successful_deletions"
            echo "   ℹ️  Not found (already deleted): $repos_not_found"
            echo "   ❌ Failed to delete: $failed_deletions"
            
            if [[ $failed_deletions -gt 0 ]]; then
                echo "   Failed repositories: $failed_repo_list"
                echo "❌ Some repository deletions failed!"
                exit 1
            elif [[ $total_repos -eq 0 ]]; then
                echo "ℹ️  No repositories found in cleanup report"
            else
                echo "✅ All repositories cleaned up successfully"
            fi
        fi
        ;;
        
    "applications")
        echo "🚀 Cleaning up applications..."
        echo "ℹ️  Note: Application versions should have been deleted in previous step"
        
        # Track success/failure counts for better reporting
        total_apps=0
        successful_deletions=0
        failed_deletions=0
        apps_not_found=0
        failed_app_list=""
        
        # Count total applications first
        total_apps=$(jq -r '.plan.applications[]?.key // empty' "$CLEANUP_REPORT_FILE" | grep -c . || echo "0")
        echo "📊 Found $total_apps applications to clean up"
        
        # Process each application and track results
        while read -r app_name; do
            if [[ -n "$app_name" ]]; then
                echo "Processing application: $app_name"
                
                # Capture the output to determine success type
                deletion_output=$(mktemp)
                execute_deletion "application" "$app_name" "/apptrust/api/v1/applications/${app_name}" "application" 2>&1 | tee "$deletion_output"
                deletion_exit_code=${PIPESTATUS[0]}
                if [[ $deletion_exit_code -eq 0 ]]; then
                    if [[ "$DRY_RUN" == "true" ]]; then
                        echo "  🔍 [DRY RUN] Would delete application: $app_name"
                    else
                        # Check the actual output to determine if it was successfully deleted or not found
                        if grep -q "✅.*deleted successfully" "$deletion_output"; then
                            ((successful_deletions++))
                        elif grep -q "ℹ️.*not found" "$deletion_output"; then
                            ((apps_not_found++))
                        else
                            # This shouldn't happen if execute_deletion works correctly, but handle it
                            ((successful_deletions++))
                        fi
                    fi
                else
                    echo "❌ Failed to delete application: $app_name"
                    ((failed_deletions++))
                    if [[ -z "$failed_app_list" ]]; then
                        failed_app_list="$app_name"
                    else
                        failed_app_list="$failed_app_list, $app_name"
                    fi
                fi
                rm -f "$deletion_output"
            fi
        done < <(jq -r '.plan.applications[]?.key // empty' "$CLEANUP_REPORT_FILE")
        
        # Report summary
        echo ""
        echo "📊 Application cleanup summary:"
        echo "   Total applications processed: $total_apps"
        
        if [[ "$DRY_RUN" == "true" ]]; then
            echo "   🔍 [DRY RUN] All $total_apps applications would be processed"
        else
            echo "   ✅ Successfully deleted: $successful_deletions"
            echo "   ℹ️  Not found (already deleted): $apps_not_found"
            echo "   ❌ Failed to delete: $failed_deletions"
            
            if [[ $failed_deletions -gt 0 ]]; then
                echo "   Failed applications: $failed_app_list"
                echo "❌ Some application deletions failed!"
                exit 1
            elif [[ $total_apps -eq 0 ]]; then
                echo "ℹ️  No applications found in cleanup report"
            else
                echo "✅ All applications cleaned up successfully"
            fi
        fi
        ;;
        
    "stages")
        echo "🏷️ Cleaning up lifecycle stages..."
        jq -r '.plan.stages[]?.name // empty' "$CLEANUP_REPORT_FILE" | while read -r stage_name; do
            if [[ -n "$stage_name" ]]; then
                execute_deletion "stage" "$stage_name" "/access/api/v2/stages/${stage_name}" "lifecycle stage"
            fi
        done
        ;;
        
    "builds")
        echo "🔧 Cleaning up builds..."
        
        # Track success/failure counts for better reporting
        total_builds=0
        successful_deletions=0
        failed_deletions=0
        builds_not_found=0
        failed_build_list=""
        
        # Count total builds first
        total_builds=$(jq -r '.plan.builds[]?.name // empty' "$CLEANUP_REPORT_FILE" | grep -c . || echo "0")
        echo "📊 Found $total_builds builds to clean up"
        
        # Process each build and track results
        while read -r build_name; do
            if [[ -n "$build_name" ]]; then
                echo "Processing build: $build_name"
                
                # URL encode the build name for the API call
                encoded_build_name=$(printf '%s\n' "$build_name" | jq -sRr @uri)
                
                # Capture the output to determine success type
                deletion_output=$(mktemp)
                execute_deletion "build" "$build_name" "/artifactory/api/build/${encoded_build_name}?deleteAll=1&project=${PROJECT_KEY}" "build" 2>&1 | tee "$deletion_output"
                deletion_exit_code=${PIPESTATUS[0]}
                echo "DEBUG: execute_deletion exit code: $deletion_exit_code"
                if [[ $deletion_exit_code -eq 0 ]]; then
                    if [[ "$DRY_RUN" == "true" ]]; then
                        echo "  🔍 [DRY RUN] Would delete build: $build_name"
                    else
                        # Check the actual output to determine if it was successfully deleted or not found
                        if grep -q "✅.*deleted successfully" "$deletion_output"; then
                            ((successful_deletions++))
                        elif grep -q "ℹ️.*not found" "$deletion_output"; then
                            ((builds_not_found++))
                        else
                            # This shouldn't happen if execute_deletion works correctly, but handle it
                            ((successful_deletions++))
                        fi
                    fi
                else
                    echo "❌ Failed to delete build: $build_name"
                    ((failed_deletions++))
                    if [[ -z "$failed_build_list" ]]; then
                        failed_build_list="$build_name"
                    else
                        failed_build_list="$failed_build_list, $build_name"
                    fi
                fi
                rm -f "$deletion_output"
            fi
        done < <(jq -r '.plan.builds[]?.name // empty' "$CLEANUP_REPORT_FILE")
        
        # Report summary
        echo ""
        echo "📊 Build cleanup summary:"
        echo "   Total builds processed: $total_builds"
        
        if [[ "$DRY_RUN" == "true" ]]; then
            echo "   🔍 [DRY RUN] All $total_builds builds would be processed"
        else
            echo "   ✅ Successfully deleted: $successful_deletions"
            echo "   ℹ️  Not found (already deleted): $builds_not_found"
            echo "   ❌ Failed to delete: $failed_deletions"
            
            if [[ $failed_deletions -gt 0 ]]; then
                echo "   Failed builds: $failed_build_list"
                echo "❌ Some build deletions failed!"
                exit 1
            elif [[ $total_builds -eq 0 ]]; then
                echo "ℹ️  No builds found in cleanup report"
            else
                echo "✅ All builds cleaned up successfully"
            fi
        fi
        ;;
        
    "project")
        echo "🎯 Cleaning up project..."
        project_key=$(jq -r '.metadata.project_key // empty' "$CLEANUP_REPORT_FILE")
        
        if [[ -n "$project_key" ]]; then
            execute_deletion "project" "$project_key" "/access/api/v1/projects/${project_key}" "project"
        else
            echo "⚠️  No project key found in cleanup report"
        fi
        ;;
        
    *)
        echo "❌ Unknown cleanup phase: $PHASE" >&2
        exit 1
        ;;
esac

if [[ "$DRY_RUN" == "true" ]]; then
    echo "✅ Dry-run for cleanup phase '$PHASE' completed"
else
    echo "✅ Cleanup phase '$PHASE' completed"
fi
