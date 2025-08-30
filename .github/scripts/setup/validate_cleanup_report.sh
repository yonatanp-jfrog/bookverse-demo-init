#!/usr/bin/env bash

# =============================================================================
# CLEANUP REPORT VALIDATION SCRIPT
# =============================================================================
# Validates that a fresh cleanup report exists before allowing cleanup execution
# Ensures reports are not older than 30 minutes for safety
# =============================================================================

set -euo pipefail

# Load shared utilities
source "$(dirname "$0")/common.sh"

# Initialize script
init_script "$(basename "$0")" "Validating cleanup report freshness and availability"

SHARED_REPORT_FILE=".github/cleanup-report.json"
MAX_AGE_MINUTES=30

# Check if report file exists
if [[ ! -f "$SHARED_REPORT_FILE" ]]; then
    log_error "❌ No cleanup report found"
    echo ""
    log_info "📋 To run cleanup, you must first:"
    log_info "   1. Run the 🔍 Discover Cleanup workflow"
    log_info "   2. Wait for it to generate a fresh discovery report"
    log_info "   3. Then run this cleanup workflow"
    echo ""
    log_error "🚨 CLEANUP BLOCKED: Discovery required"
    exit 1
fi

# Check if report is valid JSON and has required structure
if ! jq -e '.metadata.timestamp' "$SHARED_REPORT_FILE" >/dev/null 2>&1; then
    log_error "❌ Invalid cleanup report format"
    echo ""
    log_info "📋 The cleanup report appears to be corrupted."
    log_info "   Please run the 🔍 Discover Cleanup workflow again."
    echo ""
    log_error "🚨 CLEANUP BLOCKED: Invalid report"
    exit 1
fi

# Get report timestamp and validate age
report_timestamp=$(jq -r '.metadata.timestamp' "$SHARED_REPORT_FILE")
report_epoch=$(date -d "$report_timestamp" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%SZ" "$report_timestamp" +%s 2>/dev/null || echo "0")
current_epoch=$(date +%s)
age_minutes=$(( (current_epoch - report_epoch) / 60 ))

if [[ $age_minutes -gt $MAX_AGE_MINUTES ]]; then
    log_error "❌ Cleanup report is too old"
    echo ""
    log_info "📋 Report details:"
    log_info "   • Generated: $report_timestamp"
    log_info "   • Age: $age_minutes minutes"
    log_info "   • Maximum allowed age: $MAX_AGE_MINUTES minutes"
    echo ""
    log_info "🔄 To proceed with cleanup:"
    log_info "   1. Run the 🔍 Discover Cleanup workflow"
    log_info "   2. Wait for fresh discovery to complete"
    log_info "   3. Run cleanup within $MAX_AGE_MINUTES minutes"
    echo ""
    log_error "🚨 CLEANUP BLOCKED: Report expired"
    # Mark report as stale to prevent accidental reuse
    tmpfile=$(mktemp)
    jq '.status = "stale_report"' "$SHARED_REPORT_FILE" > "$tmpfile" && mv "$tmpfile" "$SHARED_REPORT_FILE"
    exit 1
fi

# Check report status
report_status=$(jq -r '.status' "$SHARED_REPORT_FILE")
if [[ "$report_status" != "ready_for_cleanup" ]]; then
    log_error "❌ Cleanup report is not ready"
    echo ""
    log_info "📋 Report status: $report_status"
    log_info "   Expected status: ready_for_cleanup"
    echo ""
    log_error "🚨 CLEANUP BLOCKED: Report not ready"
    exit 1
fi

# Get counts from report
total_items=$(jq -r '.metadata.total_items' "$SHARED_REPORT_FILE")
project_key=$(jq -r '.metadata.project_key' "$SHARED_REPORT_FILE")

# Validation successful - display report summary
log_success "✅ Cleanup report validation passed"
echo ""
log_config "📋 Report Summary:"
log_config "   • Project: $project_key"
log_config "   • Generated: $report_timestamp ($age_minutes minutes ago)"
log_config "   • Total items to delete: $total_items"
log_config "   • Status: $report_status"
echo ""

# Display breakdown if available
builds_count=$(jq -r '.metadata.discovery_counts.builds // 0' "$SHARED_REPORT_FILE")
apps_count=$(jq -r '.metadata.discovery_counts.applications // 0' "$SHARED_REPORT_FILE")
repos_count=$(jq -r '.metadata.discovery_counts.repositories // 0' "$SHARED_REPORT_FILE")
users_count=$(jq -r '.metadata.discovery_counts.users // 0' "$SHARED_REPORT_FILE")
stages_count=$(jq -r '.metadata.discovery_counts.stages // 0' "$SHARED_REPORT_FILE")

log_config "🎯 Resource Breakdown:"
log_config "   • 🔧 Builds: $builds_count"
log_config "   • 🚀 Applications: $apps_count"
log_config "   • 📦 Repositories: $repos_count"
log_config "   • 👥 Users: $users_count"
log_config "   • 🏷️ Stages: $stages_count"

echo ""
log_success "🎯 Ready to proceed with cleanup execution"

# Finalize script
finalize_script "$(basename "$0")"
