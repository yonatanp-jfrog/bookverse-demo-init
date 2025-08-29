#!/usr/bin/env bash

# =============================================================================
# CLEANUP FROM SHARED REPORT SCRIPT  
# =============================================================================
# Executes cleanup based on a pre-generated shared report
# Does not perform discovery - only deletes items from the existing report
# =============================================================================

set -euo pipefail

# Load shared utilities
source "$(dirname "$0")/common.sh"

# Initialize script
init_script "$(basename "$0")" "Executing cleanup from shared discovery report"

SHARED_REPORT_FILE=".github/cleanup-report.json"

# Validate report exists (should be caught by validation script)
if [[ ! -f "$SHARED_REPORT_FILE" ]]; then
    log_error "❌ No cleanup report found - validation should have caught this"
    exit 1
fi

# Load report metadata
report_timestamp=$(jq -r '.metadata.timestamp' "$SHARED_REPORT_FILE")
project_key=$(jq -r '.metadata.project_key' "$SHARED_REPORT_FILE")
total_items=$(jq -r '.metadata.total_items' "$SHARED_REPORT_FILE")
deletion_plan=$(jq -r '.deletion_plan' "$SHARED_REPORT_FILE")

log_info "📋 Executing cleanup from report"
log_config "   • Report generated: $report_timestamp"
log_config "   • Project: $project_key"
log_config "   • Total items to delete: $total_items"
echo ""

# Create temporary deletion plan file from report
temp_deletion_file="/tmp/deletion_plan_from_report.txt"
echo "$deletion_plan" > "$temp_deletion_file"

# Run the actual cleanup logic from the main script
log_info "🗑️ Starting deletion process..."
echo ""

# Source the main cleanup script to get the deletion functions
source "$(dirname "$0")/cleanup_project_based.sh"

# Execute the deletion phase only (skip discovery)
FAILED=false

# Parse deletion plan and execute deletions for ONLY the items in the report
# Extract resource lists from the report for targeted deletion

# 1) Extract and delete builds (if any)
builds_to_delete=$(grep "❌ Build:" "$temp_deletion_file" 2>/dev/null | sed 's/.*❌ Build: //' || true)
if [[ -n "$builds_to_delete" && -n "$(echo "$builds_to_delete" | tr -d '[:space:]')" ]]; then
    builds_count=$(echo "$builds_to_delete" | wc -l)
    log_info "🔧 Deleting $builds_count builds from report..."
    
    # Create temporary file with builds to delete
    echo "$builds_to_delete" > "/tmp/builds_to_delete.txt"
    delete_specific_builds "/tmp/builds_to_delete.txt" || FAILED=true
else
    log_info "🔧 No builds found in report to delete"
fi

# 2) Extract and delete applications
apps_to_delete=$(grep "❌ Application:" "$temp_deletion_file" 2>/dev/null | sed 's/.*❌ Application: //' || true)
if [[ -n "$apps_to_delete" && -n "$(echo "$apps_to_delete" | tr -d '[:space:]')" ]]; then
    apps_count=$(echo "$apps_to_delete" | wc -l)
    log_info "🚀 Deleting $apps_count applications from report..."
    
    # Create temporary file with applications to delete
    echo "$apps_to_delete" > "/tmp/apps_to_delete.txt"
    delete_specific_applications "/tmp/apps_to_delete.txt" || FAILED=true
else
    log_info "🚀 No applications found in report to delete"
fi

# 3) Extract and delete repositories
repos_to_delete=$(grep "❌ Repository:" "$temp_deletion_file" 2>/dev/null | sed 's/.*❌ Repository: //' || true)
if [[ -n "$repos_to_delete" && -n "$(echo "$repos_to_delete" | tr -d '[:space:]')" ]]; then
    repos_count=$(echo "$repos_to_delete" | wc -l)
    log_info "📦 Deleting $repos_count repositories from report..."
    
    # Create temporary file with repositories to delete
    echo "$repos_to_delete" > "/tmp/repos_to_delete.txt"
    delete_specific_repositories "/tmp/repos_to_delete.txt" || FAILED=true
else
    log_info "📦 No repositories found in report to delete"
fi

# 4) Extract and delete users
users_to_delete=$(grep "❌ User:" "$temp_deletion_file" 2>/dev/null | sed 's/.*❌ User: //' || true)
if [[ -n "$users_to_delete" && -n "$(echo "$users_to_delete" | tr -d '[:space:]')" ]]; then
    users_count=$(echo "$users_to_delete" | wc -l)
    log_info "👥 Deleting $users_count users from report..."
    
    # Create temporary file with users to delete
    echo "$users_to_delete" > "/tmp/users_to_delete.txt"
    delete_specific_users "/tmp/users_to_delete.txt" || FAILED=true
else
    log_info "👥 No users found in report to delete"
fi

# 5) Extract and delete stages
stages_to_delete=$(grep "❌ Stage:" "$temp_deletion_file" 2>/dev/null | sed 's/.*❌ Stage: //' || true)
if [[ -n "$stages_to_delete" && -n "$(echo "$stages_to_delete" | tr -d '[:space:]')" ]]; then
    stages_count=$(echo "$stages_to_delete" | wc -l)
    log_info "🏷️ Deleting $stages_count stages from report..."
    
    # Create temporary file with stages to delete
    echo "$stages_to_delete" > "/tmp/stages_to_delete.txt"
    delete_specific_stages "/tmp/stages_to_delete.txt" || FAILED=true
else
    log_info "🏷️ No stages found in report to delete"
fi

# Clean up temporary files
rm -f "$temp_deletion_file"
rm -f /tmp/builds_to_delete.txt /tmp/apps_to_delete.txt /tmp/repos_to_delete.txt /tmp/users_to_delete.txt /tmp/stages_to_delete.txt

# Check if there were any failures during deletion
if [[ "$FAILED" == "true" ]]; then
    log_error "❌ Some deletions failed - cleanup incomplete"
    log_info "📋 Shared report will NOT be cleared due to failures"
    log_info "🔄 Fix any issues and try running cleanup again"
    exit 1
fi

# Try to delete the project itself (final step)
log_info "🎯 Attempting to delete project '$project_key'..."
if delete_project_final "$project_key"; then
    log_success "✅ Project '$project_key' deleted successfully"
    
    # Clear the shared report after successful cleanup
    log_info "🧹 Clearing shared cleanup report..."
    jq -n '{
        "metadata": {
            "timestamp": now | strftime("%Y-%m-%dT%H:%M:%SZ"),
            "project_key": "'$project_key'",
            "total_items": 0,
            "discovery_counts": {
                "builds": 0,
                "applications": 0,
                "repositories": 0,
                "users": 0,
                "stages": 0
            }
        },
        "deletion_plan": "No items found for deletion",
        "status": "cleanup_completed",
        "last_cleanup": "'$report_timestamp'"
    }' > "$SHARED_REPORT_FILE"
    
    log_success "✅ Cleanup completed successfully"
    log_info "📋 Shared report cleared - new discovery required for next cleanup"
else
    log_error "❌ Failed to delete project '$project_key'"
    echo ""
    log_info "💡 This usually means there are still resources in the project that were not in the original report."
    log_info "📋 Possible causes:"
    log_info "   • New resources were created after the discovery was run"
    log_info "   • Some resources failed to delete due to dependencies"
    log_info "   • Resources exist that weren't detected in the original discovery"
    echo ""
    log_info "🔄 Recommended actions:"
    log_info "   1. Run the 🔍 Discover Cleanup workflow to get a fresh resource list"
    log_info "   2. Review any new resources that appeared since the last discovery"
    log_info "   3. Run this cleanup workflow again with the updated report"
    echo ""
    log_info "📋 The cleanup report will remain available for retry"
    log_error "🚨 PROJECT DELETION INCOMPLETE - Fresh discovery recommended"
    exit 1
fi

# Finalize script
finalize_script "$(basename "$0")"
