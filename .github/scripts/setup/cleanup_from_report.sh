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

log_info "📋 Executing cleanup from report"
log_config "   • Report generated: $report_timestamp"
log_config "   • Project: $project_key"
log_config "   • Total items to delete: $total_items"
echo ""

# Materialize structured plan files from report (filter by expected project for safety)
repos_file="/tmp/repos_to_delete.txt"
apps_file="/tmp/apps_to_delete.txt"
users_file="/tmp/users_to_delete.txt"
stages_file="/tmp/stages_to_delete.txt"
builds_file="/tmp/builds_to_delete.txt"

jq -r --arg p "$project_key" '.plan.repositories[]? | select(.project==$p) | .key' "$SHARED_REPORT_FILE" > "$repos_file" 2>/dev/null || true
jq -r --arg p "$project_key" '.plan.applications[]? | select(.project==$p) | .key' "$SHARED_REPORT_FILE" > "$apps_file" 2>/dev/null || true
jq -r --arg p "$project_key" '.plan.users[]? | select(.project==$p) | .name' "$SHARED_REPORT_FILE" > "$users_file" 2>/dev/null || true
jq -r --arg p "$project_key" '.plan.stages[]? | select(.project==$p) | .name' "$SHARED_REPORT_FILE" > "$stages_file" 2>/dev/null || true
jq -r --arg p "$project_key" '.plan.builds[]? | select(.project==$p) | .name' "$SHARED_REPORT_FILE" > "$builds_file" 2>/dev/null || true

# Run the actual cleanup logic from the main script
log_info "🗑️ Starting deletion process..."
echo ""

# Source the main cleanup script to get the deletion functions
source "$(dirname "$0")/cleanup_project_based.sh"

# Execute the deletion phase only (skip discovery)
FAILED=false
# Enforce protection layer: this script assumes discovery produced the report
if [[ ! -f ".github/cleanup-report.json" ]]; then
    log_error "❌ Cleanup report missing. Run discovery first."
    exit 1
fi

# Parse deletion plan and execute deletions for ONLY the items in the report
# Extract resource lists from the report for targeted deletion

# 1) Delete builds from structured plan
if [[ -s "$builds_file" ]]; then
    builds_count=$(wc -l < "$builds_file")
    log_info "🔧 Deleting $builds_count builds from report..."
    delete_specific_builds "$builds_file" || FAILED=true
else
    log_info "🔧 No builds found in report to delete"
fi

# 2) Delete applications from structured plan
if [[ -s "$apps_file" ]]; then
    apps_count=$(wc -l < "$apps_file")
    log_info "🚀 Deleting $apps_count applications from report..."
    delete_specific_applications "$apps_file" || FAILED=true
else
    log_info "🚀 No applications found in report to delete"
fi

# 3) Delete repositories from structured plan
if [[ -s "$repos_file" ]]; then
    repos_count=$(wc -l < "$repos_file")
    log_info "📦 Deleting $repos_count repositories from report..."
    delete_specific_repositories "$repos_file" || FAILED=true
else
    log_info "📦 No repositories found in report to delete"
fi

# 4) Delete users from structured plan
if [[ -s "$users_file" ]]; then
    users_count=$(wc -l < "$users_file")
    log_info "👥 Deleting $users_count users from report..."
    delete_specific_users "$users_file" || FAILED=true
else
    log_info "👥 No users found in report to delete"
fi

# 5) Delete stages from structured plan
if [[ -s "$stages_file" ]]; then
    stages_count=$(wc -l < "$stages_file")
    log_info "🏷️ Deleting $stages_count stages from report..."
    delete_specific_stages "$stages_file" || FAILED=true
else
    log_info "🏷️ No stages found in report to delete"
fi

# Clean up temporary files
rm -f "$repos_file" "$apps_file" "$users_file" "$stages_file" "$builds_file"

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
