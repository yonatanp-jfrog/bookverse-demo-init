#!/usr/bin/env bash

# =============================================================================
# UNIFIED BOOKVERSE RESOURCE CLEANUP SCRIPT
# =============================================================================
# Streamlined cleanup script combining the best of cleanup.sh and 
# cleanup_project_based.sh with improved efficiency and reduced complexity
# =============================================================================

set -e

source "$(dirname "$0")/common.sh"

# =============================================================================
# CONFIGURATION & CONSTANTS
# =============================================================================

readonly SCRIPT_NAME="BookVerse Resource Cleanup"
readonly MAX_PARALLEL_JOBS=3
readonly TEMP_DIR_BASE="${TEMP_DIR_PREFIX:-bookverse_cleanup}_$(date +%s)"
readonly HTTP_DEBUG_LOG="$TEMP_DIR_BASE/api_calls.log"

# Create temp directory and debug log
mkdir -p "$TEMP_DIR_BASE"
touch "$HTTP_DEBUG_LOG"

# Resource types to clean up (in dependency order)
readonly CLEANUP_RESOURCES=(
    "applications"
    "builds"
    "repositories"
    "users"
    "stages"
    "lifecycle"
    "project"
)

# =============================================================================
# DISCOVERY FUNCTIONS
# =============================================================================

discover_applications() {
    local apps_file="$1"
    log_info "Discovering applications in project '$PROJECT_KEY'..."
    
    local code=$(jfrog_api_call "GET" "${JFROG_URL%/}/apptrust/api/v1/applications?project_key=$PROJECT_KEY" "$apps_file" "curl" "" "project applications")
    
    if [[ $(jq length "$apps_file" 2>/dev/null || echo 0) -gt 0 ]]; then
        local count=$(jq -r '.[].application_key' "$apps_file" | wc -l)
        log_success "Found $count applications"
        return 0
    fi
    
    log_info "No applications found in project"
    return 1
}

discover_repositories() {
    local repos_file="$1"
    log_info "Discovering repositories with '$PROJECT_KEY' prefix..."
    
    # Method 1: Try JFrog CLI (most reliable)
    if jf rt repo-list --json > "$repos_file" 2>/dev/null; then
        # Filter for repositories containing project key
        jq --arg project "$PROJECT_KEY" '[.[] | select(.key | contains($project))]' "$repos_file" > "${repos_file}.tmp" && mv "${repos_file}.tmp" "$repos_file"
        
        if [[ $(jq length "$repos_file" 2>/dev/null || echo 0) -gt 0 ]]; then
            local count=$(jq length "$repos_file")
            log_success "Found $count repositories via CLI"
            return 0
        fi
    fi
    
    # Method 2: REST API fallback
    local code=$(jfrog_api_call "GET" "${JFROG_URL%/}/artifactory/api/repositories" "$repos_file" "curl" "" "all repositories")
    if [[ "$code" == "200" ]]; then
        # Filter for repositories containing project key  
        jq --arg project "$PROJECT_KEY" '[.[] | select(.key | contains($project))]' "$repos_file" > "${repos_file}.tmp" && mv "${repos_file}.tmp" "$repos_file"
        
        if [[ $(jq length "$repos_file" 2>/dev/null || echo 0) -gt 0 ]]; then
            local count=$(jq length "$repos_file")
            log_success "Found $count repositories via REST API"
            return 0
        fi
    fi
    
    log_info "No repositories found"
    return 1
}

discover_builds() {
    local builds_file="$1"
    log_info "Discovering builds in project '$PROJECT_KEY'..."
    
    local code=$(jfrog_api_call "GET" "${JFROG_URL%/}/artifactory/api/build?project=$PROJECT_KEY" "$builds_file" "curl" "" "project builds")
    
    if [[ "$code" == "200" ]] && [[ $(jq length "$builds_file" 2>/dev/null || echo 0) -gt 0 ]]; then
        local count=$(jq -r '.builds[].uri' "$builds_file" | wc -l)
        log_success "Found $count builds"
        return 0
    fi
    
    log_info "No builds found in project"
    return 1
}

# =============================================================================
# DELETION FUNCTIONS
# =============================================================================

delete_applications() {
    local apps_file="$1"
    log_step "Deleting applications..."
    
    local apps_deleted=0
    local apps_failed=0
    
    while IFS= read -r app_key; do
        if [[ -n "$app_key" ]]; then
            log_info "Deleting application: $app_key"
            
            # Delete all versions first (pagination-safe loop)
            local safety_loops=0
            while true; do
                local versions_file="$TEMP_DIR_BASE/versions_${app_key}.json"
                local code=$(jfrog_api_call "GET" "${JFROG_URL%/}/apptrust/api/v1/applications/$app_key/versions?limit=250&order_by=created&order_asc=false" "$versions_file" "curl" "" "get app versions (paged)")
                if [[ "$code" =~ ^2[0-9][0-9]$ ]] && [[ $(jq length "$versions_file" 2>/dev/null || echo 0) -gt 0 ]]; then
                    local any_deleted=false
                    while IFS= read -r version; do
                        if [[ -n "$version" ]] && [[ "$version" != "null" ]]; then
                            log_info "  Deleting version: $version"
                            local ver_code=$(jfrog_api_call "DELETE" "${JFROG_URL%/}/apptrust/api/v1/applications/$app_key/versions/$version" "/dev/null" "curl" "" "delete version")
                            if [[ "$ver_code" =~ ^2[0-9][0-9]$ ]] || [[ "$ver_code" == "404" ]]; then
                                log_success "    Version $version deleted"
                                any_deleted=true
                            else
                                log_warning "    Failed to delete version $version (HTTP $ver_code)"
                            fi
                        fi
                    done < <(jq -r '.versions[]?.version // empty' "$versions_file" 2>/dev/null)
                    # If none deleted, break to avoid infinite loop
                    if [[ "$any_deleted" != true ]]; then
                        break
                    fi
                else
                    break
                fi
                ((safety_loops++))
                if [[ "$safety_loops" -gt 50 ]]; then
                    log_warning "    Aborting version deletion loop after 50 iterations for safety"
                    break
                fi
            done
            
            # Delete the application
            local app_code=$(jfrog_api_call "DELETE" "${JFROG_URL%/}/apptrust/api/v1/applications/$app_key" "/dev/null" "curl" "" "delete application")
            if [[ "$app_code" =~ ^2[0-9][0-9]$ ]]; then
                log_success "Application '$app_key' deleted"
                ((apps_deleted++))
            else
                log_error "Failed to delete application '$app_key' (HTTP $app_code)"
                ((apps_failed++))
            fi
        fi
    done < <(jq -r '.[].application_key' "$apps_file" 2>/dev/null)
    
    log_info "Applications: $apps_deleted deleted, $apps_failed failed"
}

delete_repositories() {
    local repos_file="$1"
    log_step "Deleting repositories..."
    
    local repos_deleted=0
    local repos_failed=0
    
    while IFS= read -r repo_key; do
        if [[ -n "$repo_key" ]]; then
            log_info "Deleting repository: $repo_key"
            
            # Use REST API directly (consistent, reliable, faster)
            local code=$(jfrog_api_call "DELETE" "${JFROG_URL%/}/artifactory/api/repositories/$repo_key" "/dev/null" "curl" "" "delete repository")
            if [[ "$code" =~ ^2[0-9][0-9]$ ]] || [[ "$code" == "404" ]]; then
                log_success "Repository '$repo_key' deleted (HTTP $code)"
                ((repos_deleted++))
            else
                log_error "Failed to delete repository '$repo_key' (HTTP $code)"
                ((repos_failed++))
            fi
        fi
    done < <(jq -r '.[].key' "$repos_file" 2>/dev/null)
    
    log_info "Repositories: $repos_deleted deleted, $repos_failed failed"
}

delete_builds() {
    local builds_file="$1"
    log_step "Deleting builds..."
    
    local builds_deleted=0
    local builds_failed=0
    
    while IFS= read -r build_name; do
        if [[ -n "$build_name" ]]; then
            # URL decode the build name
            local decoded_name=$(printf '%b' "${build_name//%/\\x}")
            log_info "Deleting build: $decoded_name"
            
            # Get build numbers for this build
            local build_details="$TEMP_DIR_BASE/build_${build_name//\//_}.json"
            local code=$(jfrog_api_call "GET" "${JFROG_URL%/}/artifactory/api/build/$decoded_name?project=$PROJECT_KEY" "$build_details" "curl" "" "get build details")
            
            if [[ "$code" == "200" ]] && [[ -s "$build_details" ]]; then
                local build_numbers=($(jq -r '.buildsNumbers[].uri' "$build_details" 2>/dev/null | sed 's|.*/||'))
                
                if [[ ${#build_numbers[@]} -gt 0 ]]; then
                    # Create deletion payload
                    local delete_payload=$(jq -n \
                        --arg project "$PROJECT_KEY" \
                        --arg buildName "$decoded_name" \
                        --argjson buildNumbers "$(printf '"%s"\n' "${build_numbers[@]}" | jq -s '.')" \
                        '{
                            project: $project,
                            buildName: $buildName,
                            buildNumbers: $buildNumbers
                        }')
                    
                    local delete_code=$(jfrog_api_call "POST" "${JFROG_URL%/}/artifactory/api/build/delete" "/dev/null" "curl" "$delete_payload" "delete build")
                    if [[ "$delete_code" =~ ^2[0-9][0-9]$ ]]; then
                        log_success "Build '$decoded_name' deleted"
                        ((builds_deleted++))
                    else
                        log_error "Failed to delete build '$decoded_name' (HTTP $delete_code)"
                        ((builds_failed++))
                    fi
                fi
            fi
        fi
    done < <(jq -r '.builds[].uri' "$builds_file" 2>/dev/null | sed 's|.*/||')
    
    log_info "Builds: $builds_deleted deleted, $builds_failed failed"
}

delete_project() {
    log_step "Deleting project '$PROJECT_KEY'..."
    
    local code=$(jfrog_api_call "DELETE" "${JFROG_URL%/}/access/api/v1/projects/$PROJECT_KEY?force=true" "/dev/null" "curl" "" "delete project")
    if [[ "$code" =~ ^2[0-9][0-9]$ ]]; then
        log_success "Project '$PROJECT_KEY' deleted successfully"
    else
        log_error "Failed to delete project '$PROJECT_KEY' (HTTP $code)"
        return 1
    fi
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    init_script "$SCRIPT_NAME" "Enhanced BookVerse Resource Cleanup"
    
    log_step "Starting cleanup for project: $PROJECT_KEY"
    log_config "Temp Directory: $TEMP_DIR_BASE"
    log_config "Debug Log: $HTTP_DEBUG_LOG"
    
    local total_errors=0
    
    # Process each resource type
    for resource in "${CLEANUP_RESOURCES[@]}"; do
        case "$resource" in
            "applications")
                local apps_file="$TEMP_DIR_BASE/applications.json"
                if discover_applications "$apps_file"; then
                    delete_applications "$apps_file" || ((total_errors++))
                fi
                ;;
            "repositories")
                local repos_file="$TEMP_DIR_BASE/repositories.json"
                if discover_repositories "$repos_file"; then
                    delete_repositories "$repos_file" || ((total_errors++))
                fi
                ;;
            "builds")
                local builds_file="$TEMP_DIR_BASE/builds.json"
                if discover_builds "$builds_file"; then
                    delete_builds "$builds_file" || ((total_errors++))
                fi
                ;;
            "project")
                delete_project || ((total_errors++))
                ;;
        esac
    done
    
    # Cleanup temporary files
    log_info "Cleaning up temporary files..."
    rm -rf "$TEMP_DIR_BASE"
    
    # Final status
    if [[ $total_errors -eq 0 ]]; then
        log_success "🎉 Cleanup completed successfully!"
        log_success "All BookVerse resources have been removed"
    else
        log_error "⚠️ Cleanup completed with $total_errors errors"
        log_error "Check the logs above for details"
        exit 1
    fi
}

# Run main function
main "$@"
