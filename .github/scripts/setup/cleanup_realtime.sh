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

case "$PHASE" in
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
                        encoded_build_name=$(printf '%s\n' "$build_name" | jq -sRr @uri)
                        
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
        echo "Supported phases: builds, repositories, applications, project"
        exit 1
        ;;
esac

echo "✅ Cleanup phase '$PHASE' completed"
