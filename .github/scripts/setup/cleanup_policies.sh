#!/usr/bin/env bash

# =============================================================================
# BookVerse Platform - Unified Policy Cleanup Script
# =============================================================================
#
# This script safely removes all BookVerse unified policies during platform
# cleanup operations, ensuring complete removal of policy configurations
# while maintaining data integrity and proper cleanup sequencing.
#
# 🗑️ CLEANUP OPERATIONS:
#     - Policy Identification: Locate all BookVerse project policies
#     - Safe Removal: Remove policies in proper dependency order
#     - Verification: Confirm complete policy removal
#     - Error Handling: Robust error handling for cleanup operations
#
# Authors: BookVerse Platform Team
# Version: 1.0.0
# Last Updated: 2024
#

set -euo pipefail

source "$(dirname "$0")/common.sh"
source "$(dirname "$0")/config.sh"

log_info "🗑️ Cleaning up BookVerse Unified Policies..."

# Check required environment variables
if [[ -z "$JFROG_URL" || -z "$JFROG_ADMIN_TOKEN" || -z "$PROJECT_KEY" ]]; then
    echo "❌ Missing required environment variables: JFROG_URL, JFROG_ADMIN_TOKEN, PROJECT_KEY"
    exit 1
fi

API_BASE="$JFROG_URL/unifiedpolicy/api/v1"
AUTH_HEADER="Authorization: Bearer $JFROG_ADMIN_TOKEN"

# Function to delete a policy by ID
delete_policy() {
    local policy_id="$1"
    local policy_name="$2"
    
    log_info "Deleting policy: $policy_name (ID: $policy_id)"
    
    local response
    response=$(curl -s -w "%{http_code}" -X DELETE \
        -H "$AUTH_HEADER" \
        "$API_BASE/policies/$policy_id")
    
    local http_code="${response: -3}"
    local body="${response%???}"
    
    if [[ "$http_code" == "200" || "$http_code" == "204" || "$http_code" == "404" ]]; then
        log_success "✅ Deleted policy: $policy_name"
        return 0
    else
        log_warning "⚠️ Failed to delete policy: $policy_name (HTTP $http_code)"
        echo "   Response: $body"
        return 1
    fi
}

# Get all BookVerse policies
log_info "🔍 Finding BookVerse policies to delete..."

policies_response=$(curl -s -H "$AUTH_HEADER" "$API_BASE/policies?projectKey=$PROJECT_KEY" || echo '{"items":[]}')
policy_count=$(echo "$policies_response" | jq '.items | length')

if [[ "$policy_count" -eq 0 ]]; then
    log_info "✅ No BookVerse policies found to delete"
    exit 0
fi

log_info "📊 Found $policy_count BookVerse policies to delete"

# Extract policy information
policies_info=$(echo "$policies_response" | jq -r '.items[] | "\(.id)|\(.name)"')

# Delete policies
log_info "📋 Deleting BookVerse Policies"

deleted_count=0
failed_count=0

while IFS='|' read -r policy_id policy_name; do
    if [[ -n "$policy_id" && "$policy_id" != "null" ]]; then
        if delete_policy "$policy_id" "$policy_name"; then
            ((deleted_count++))
        else
            ((failed_count++))
        fi
    fi
done <<< "$policies_info"

# Verification
log_info "🔍 Cleanup Verification"

remaining_policies=$(curl -s -H "$AUTH_HEADER" "$API_BASE/policies?projectKey=$PROJECT_KEY" | \
                    jq '.items | length')

log_info "📊 Cleanup Summary:"
log_info "  ✅ Policies deleted: $deleted_count"
log_info "  ❌ Policies failed: $failed_count"
log_info "  📋 Policies remaining: $remaining_policies"

if [[ "$remaining_policies" -eq 0 ]]; then
    log_success "🎉 All BookVerse policies cleaned up successfully!"
    exit 0
elif [[ "$failed_count" -eq 0 ]]; then
    log_warning "⚠️ Some policies may still exist (possibly from other operations)"
    exit 0
else
    log_error "❌ Some policies could not be deleted"
    exit 1
fi
