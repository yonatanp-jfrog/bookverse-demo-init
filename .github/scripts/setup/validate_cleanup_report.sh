#!/usr/bin/env bash

# =============================================================================
# BookVerse Platform - Cleanup Report Validation Script
# =============================================================================
#
# Validates cleanup report freshness and integrity before allowing cleanup execution.
# Ensures reports are not stale (older than 30 minutes) and contain valid data.
#
# Exit Codes:
#   0: Report is valid and fresh
#   1: Report is missing, invalid, or stale
#   2: Environment error (missing required variables)
#
# =============================================================================

set -euo pipefail

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"
source "${SCRIPT_DIR}/config.sh"

# Configuration
CLEANUP_REPORT_FILE="${CLEANUP_REPORT_FILE:-.github/cleanup-report.json}"
REPORT_TTL_MINUTES=30

#######################################
# Validate cleanup report exists and is readable
# Globals:
#   CLEANUP_REPORT_FILE
# Returns:
#   0 if report exists and is readable, 1 otherwise
#######################################
validate_report_exists() {
    if [[ ! -f "$CLEANUP_REPORT_FILE" ]]; then
        log_error "Cleanup report not found: $CLEANUP_REPORT_FILE"
        echo "Please run the 🔍 Discover Cleanup workflow first to generate a report."
        return 1
    fi
    
    if [[ ! -r "$CLEANUP_REPORT_FILE" ]]; then
        log_error "Cleanup report is not readable: $CLEANUP_REPORT_FILE"
        return 1
    fi
    
    return 0
}

#######################################
# Validate cleanup report contains valid JSON
# Globals:
#   CLEANUP_REPORT_FILE
# Returns:
#   0 if report contains valid JSON, 1 otherwise
#######################################
validate_report_json() {
    if ! jq empty "$CLEANUP_REPORT_FILE" 2>/dev/null; then
        log_error "Cleanup report contains invalid JSON: $CLEANUP_REPORT_FILE"
        return 1
    fi
    
    return 0
}

#######################################
# Validate cleanup report contains required fields
# Globals:
#   CLEANUP_REPORT_FILE
# Returns:
#   0 if report contains required fields, 1 otherwise
#######################################
validate_report_structure() {
    local required_fields=(
        ".metadata.timestamp"
        ".metadata.project_key"
        ".metadata.total_items"
        ".plan"
        ".status"
    )
    
    for field in "${required_fields[@]}"; do
        if ! jq -e "$field" "$CLEANUP_REPORT_FILE" >/dev/null 2>&1; then
            log_error "Cleanup report missing required field: $field"
            return 1
        fi
    done
    
    # Check that plan contains at least some data structures
    local plan_fields=(
        ".plan.repositories"
        ".plan.applications"
        ".plan.users"
        ".plan.stages"
        ".plan.builds"
    )
    
    for field in "${plan_fields[@]}"; do
        if ! jq -e "$field" "$CLEANUP_REPORT_FILE" >/dev/null 2>&1; then
            log_warning "Cleanup report missing plan field: $field (will be treated as empty)"
        fi
    done
    
    return 0
}

#######################################
# Validate cleanup report timestamp is fresh (within TTL)
# Globals:
#   CLEANUP_REPORT_FILE
#   REPORT_TTL_MINUTES
# Returns:
#   0 if report is fresh, 1 if stale
#######################################
validate_report_freshness() {
    local timestamp
    timestamp=$(jq -r '.metadata.timestamp // empty' "$CLEANUP_REPORT_FILE")
    
    if [[ -z "$timestamp" ]]; then
        log_error "Cleanup report missing timestamp"
        return 1
    fi
    
    # Convert timestamp to epoch seconds
    local report_epoch
    if ! report_epoch=$(date -d "$timestamp" +%s 2>/dev/null); then
        log_error "Invalid timestamp format in cleanup report: $timestamp"
        return 1
    fi
    
    # Get current time
    local current_epoch
    current_epoch=$(date +%s)
    
    # Calculate age in minutes
    local age_seconds=$((current_epoch - report_epoch))
    local age_minutes=$((age_seconds / 60))
    
    log_info "Report age: $age_minutes minutes (TTL: $REPORT_TTL_MINUTES minutes)"
    
    if [[ $age_minutes -gt $REPORT_TTL_MINUTES ]]; then
        log_error "Cleanup report is stale (${age_minutes}m old, max age: ${REPORT_TTL_MINUTES}m)"
        echo "Report timestamp: $(date -d "$timestamp" '+%a, %b %d %Y %H:%M:%S %Z' 2>/dev/null || echo "$timestamp")"
        echo "Please run the 🔍 Discover Cleanup workflow to generate a fresh report."
        return 1
    fi
    
    return 0
}

#######################################
# Validate cleanup report project matches expected project
# Globals:
#   CLEANUP_REPORT_FILE
#   PROJECT_KEY
# Returns:
#   0 if project matches, 1 otherwise
#######################################
validate_report_project() {
    local report_project
    report_project=$(jq -r '.metadata.project_key // empty' "$CLEANUP_REPORT_FILE")
    
    if [[ -z "$report_project" ]]; then
        log_error "Cleanup report missing project key"
        return 1
    fi
    
    if [[ "$report_project" != "$PROJECT_KEY" ]]; then
        log_error "Project key mismatch: report=$report_project, expected=$PROJECT_KEY"
        return 1
    fi
    
    return 0
}

#######################################
# Validate cleanup report status is ready for cleanup
# Globals:
#   CLEANUP_REPORT_FILE
# Returns:
#   0 if status is valid, 1 otherwise
#######################################
validate_report_status() {
    local status
    status=$(jq -r '.status // empty' "$CLEANUP_REPORT_FILE")
    
    case "$status" in
        "ready_for_cleanup")
            log_success "Report status: ready for cleanup"
            return 0
            ;;
        "cleanup_completed")
            log_error "Report indicates cleanup already completed"
            return 1
            ;;
        "stale_report")
            log_error "Report marked as stale"
            return 1
            ;;
        "")
            log_error "Report missing status field"
            return 1
            ;;
        *)
            log_warning "Unknown report status: $status (proceeding with caution)"
            return 0
            ;;
    esac
}

#######################################
# Display cleanup report summary for user verification
# Globals:
#   CLEANUP_REPORT_FILE
#######################################
display_report_summary() {
    log_step "Cleanup Report Summary"
    
    local project_key timestamp total_items
    project_key=$(jq -r '.metadata.project_key // "unknown"' "$CLEANUP_REPORT_FILE")
    timestamp=$(jq -r '.metadata.timestamp // "unknown"' "$CLEANUP_REPORT_FILE")
    total_items=$(jq -r '.metadata.total_items // 0' "$CLEANUP_REPORT_FILE")
    
    echo "Project: $project_key"
    echo "Generated: $(date -d "$timestamp" '+%a, %b %d %Y %H:%M:%S %Z' 2>/dev/null || echo "$timestamp")"
    echo "Total items to delete: $total_items"
    
    # Show breakdown by resource type
    if [[ -s "$CLEANUP_REPORT_FILE" ]]; then
        local repos apps users stages builds oidc
        repos=$(jq -r '.metadata.discovery_counts.repositories // 0' "$CLEANUP_REPORT_FILE")
        apps=$(jq -r '.metadata.discovery_counts.applications // 0' "$CLEANUP_REPORT_FILE")
        users=$(jq -r '.metadata.discovery_counts.users // 0' "$CLEANUP_REPORT_FILE")
        stages=$(jq -r '.metadata.discovery_counts.stages // 0' "$CLEANUP_REPORT_FILE")
        builds=$(jq -r '.metadata.discovery_counts.builds // 0' "$CLEANUP_REPORT_FILE")
        oidc=$(jq -r '.metadata.discovery_counts.oidc // 0' "$CLEANUP_REPORT_FILE")
        
        echo "Breakdown:"
        echo "  - Repositories: $repos"
        echo "  - Applications: $apps"
        echo "  - Users: $users"
        echo "  - Stages: $stages"
        echo "  - Builds: $builds"
        echo "  - OIDC Integrations: $oidc"
    fi
    
    echo ""
}

#######################################
# Main validation function
# Returns:
#   0 if all validations pass, 1 otherwise
#######################################
main() {
    log_step "Validating cleanup report for execution"
    
    # Validate environment
    if [[ -z "${PROJECT_KEY:-}" ]]; then
        log_error "PROJECT_KEY environment variable not set"
        return 2
    fi
    
    # Run all validations
    local validation_failed=false
    
    if ! validate_report_exists; then
        validation_failed=true
    elif ! validate_report_json; then
        validation_failed=true
    elif ! validate_report_structure; then
        validation_failed=true
    elif ! validate_report_freshness; then
        validation_failed=true
    elif ! validate_report_project; then
        validation_failed=true
    elif ! validate_report_status; then
        validation_failed=true
    fi
    
    if [[ "$validation_failed" == "true" ]]; then
        echo ""
        log_error "Cleanup report validation failed"
        return 1
    fi
    
    # Display summary for user verification
    echo ""
    display_report_summary
    
    log_success "Cleanup report validation passed - ready for execution"
    return 0
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
