#!/usr/bin/env bash

# =============================================================================
# BookVerse Platform - Unified Policy and Rules Cleanup Script
# =============================================================================
#
# This script safely removes all BookVerse unified policies and rules during 
# platform cleanup operations, ensuring complete removal of policy configurations
# while maintaining data integrity and proper cleanup sequencing.
#
# 🗑️ CLEANUP OPERATIONS:
#     - Rules Identification: Locate all BookVerse custom rules
#     - Policy Identification: Locate all BookVerse project policies  
#     - Safe Removal: Remove rules first, then policies in proper dependency order
#     - Verification: Confirm complete policy and rule removal
#     - Error Handling: Robust error handling for cleanup operations
#     - Detailed Reporting: Report on which rules and policies will be deleted
#
# Authors: BookVerse Platform Team
# Version: 1.0.0
# Last Updated: 2024
#

set -euo pipefail

source "$(dirname "$0")/common.sh"
source "$(dirname "$0")/config.sh"

# Support dry-run mode
DRY_RUN="${1:-false}"

if [[ "$DRY_RUN" == "true" ]]; then
    log_info "🔍 [DRY RUN] Preview BookVerse Unified Policies and Rules cleanup..."
else
    log_info "🗑️ Cleaning up BookVerse Unified Policies and Rules..."
fi

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
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "🔍 [DRY RUN] Would delete policy: $policy_name (ID: $policy_id)"
        return 0
    fi
    
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

# Function to delete a rule by ID
delete_rule() {
    local rule_id="$1"
    local rule_name="$2"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "🔍 [DRY RUN] Would delete rule: $rule_name (ID: $rule_id)"
        return 0
    fi
    
    log_info "Deleting rule: $rule_name (ID: $rule_id)"
    
    local response
    response=$(curl -s -w "%{http_code}" -X DELETE \
        -H "$AUTH_HEADER" \
        "$API_BASE/rules/$rule_id")
    
    local http_code="${response: -3}"
    local body="${response%???}"
    
    if [[ "$http_code" == "200" || "$http_code" == "204" || "$http_code" == "404" ]]; then
        log_success "✅ Deleted rule: $rule_name"
        return 0
    else
        log_warning "⚠️ Failed to delete rule: $rule_name (HTTP $http_code)"
        echo "   Response: $body"
        return 1
    fi
}

# =============================================================================
# STEP 1: CLEANUP UNIFIED POLICY RULES
# =============================================================================

log_info "🔍 Finding rules for project '$PROJECT_KEY' to delete..."

# Get all rules and filter for BookVerse rules
all_rules_response=$(curl -s -H "$AUTH_HEADER" "$API_BASE/rules" || echo '{"items":[]}')

# Filter for rules that belong to the current project instance (custom rules with project key in name)
rules_response=$(echo "$all_rules_response" | jq --arg project_key "$PROJECT_KEY" '
{
  items: [.items[]? | select(
    .is_custom == true and 
    (.name | type == "string") and
    (
      (.name | startswith($project_key + " ")) or
      (.name | contains($project_key))
    )
  )]
}')

rule_count=$(echo "$rules_response" | jq '.items | length')

if [[ "$rule_count" -eq 0 ]]; then
    log_info "✅ No rules found for project '$PROJECT_KEY'"
else
    log_info "📊 Found $rule_count rules for project '$PROJECT_KEY' to delete"
    
    # SAFETY CHECK: If we find more than 20 rules, something is likely wrong with filtering
    if [[ "$rule_count" -gt 20 ]]; then
        log_error "🚨 SAFETY CHECK FAILED: Found $rule_count rules to delete, but expected fewer than 20 for a single project"
        log_error "This suggests the filtering logic may be incorrect. Aborting to prevent accidental deletion of rules from other projects."
        exit 1
    fi
    
    # Double-check by listing the rule names for verification
    log_info "🔍 Rules to be deleted:"
    echo "$rules_response" | jq -r '.items[]? | "  - \(.name) (ID: \(.id))"'
    
    # Extract rule information
    rules_info=$(echo "$rules_response" | jq -r '.items[] | "\(.id)|\(.name)"')
    
    # Delete rules
    log_info "📋 Deleting BookVerse Rules"
    
    deleted_rules=0
    failed_rules=0
    
    while IFS='|' read -r rule_id rule_name; do
        if [[ -n "$rule_id" && "$rule_id" != "null" ]]; then
            if delete_rule "$rule_id" "$rule_name"; then
                ((deleted_rules++))
            else
                ((failed_rules++))
            fi
        fi
    done <<< "$rules_info"
    
    log_info "📊 Rules Cleanup Summary:"
    log_info "  ✅ Rules deleted: $deleted_rules"
    log_info "  ❌ Rules failed: $failed_rules"
fi

# =============================================================================
# STEP 2: CLEANUP UNIFIED POLICIES
# =============================================================================

# Get all policies and filter for BookVerse project client-side
log_info "🔍 Finding BookVerse policies to delete..."

# CRITICAL: The API projectKey filter doesn't work reliably, so we get all policies
# and filter client-side to ensure we only delete policies that actually belong to this project
all_policies_response=$(curl -s -H "$AUTH_HEADER" "$API_BASE/policies" || echo '{"items":[]}')

# Filter for policies that actually belong to the current project instance
# Use project-key-based filtering for proper multi-instance support
policies_response=$(echo "$all_policies_response" | jq --arg project_key "$PROJECT_KEY" '
{
  items: [.items[]? | select(
    (.name | type == "string") and
    (
      (.scope.project_keys[]? == $project_key) or
      (.name | startswith($project_key + " ")) or
      (.name | contains($project_key))
    )
  )]
}')

policy_count=$(echo "$policies_response" | jq '.items | length')

if [[ "$policy_count" -eq 0 ]]; then
    log_info "✅ No policies found for project '$PROJECT_KEY'"
    exit 0
fi

log_info "📊 Found $policy_count policies for project '$PROJECT_KEY' to delete"

# SAFETY CHECK: If we find more than 20 policies, something is likely wrong with filtering
if [[ "$policy_count" -gt 20 ]]; then
    log_error "🚨 SAFETY CHECK FAILED: Found $policy_count policies to delete, but expected fewer than 20 for a single project"
    log_error "This suggests the filtering logic may be incorrect. Aborting to prevent accidental deletion of policies from other projects."
    exit 1
fi

# Double-check by listing the policy names for verification
log_info "🔍 Policies to be deleted:"
echo "$policies_response" | jq -r '.items[]? | "  - \(.name) (ID: \(.id))"'

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

# =============================================================================
# FINAL VERIFICATION AND SUMMARY
# =============================================================================

log_info "🔍 Final Cleanup Verification"

# Verify remaining policies
remaining_policies=$(curl -s -H "$AUTH_HEADER" "$API_BASE/policies?projectKey=$PROJECT_KEY" | \
                    jq '.items | length')

# Verify remaining rules
remaining_rules_response=$(curl -s -H "$AUTH_HEADER" "$API_BASE/rules" || echo '{"items":[]}')
remaining_rules=$(echo "$remaining_rules_response" | jq --arg project_key "$PROJECT_KEY" '[.items[]? | select(.is_custom == true and (.name | type == "string") and ((.name | startswith($project_key + " ")) or (.name | contains($project_key))))] | length')

# Calculate totals
total_deleted=$((${deleted_rules:-0} + ${deleted_count:-0}))
total_failed=$((${failed_rules:-0} + ${failed_count:-0}))

log_info "📊 Complete Cleanup Summary:"
log_info "  🔧 Rules deleted: ${deleted_rules:-0}"
log_info "  📋 Policies deleted: ${deleted_count:-0}"
log_info "  ✅ Total deleted: $total_deleted"
log_info "  ❌ Total failed: $total_failed"
log_info "  🔧 Rules remaining: $remaining_rules"
log_info "  📋 Policies remaining: $remaining_policies"

# Determine exit status
if [[ "$remaining_policies" -eq 0 && "$remaining_rules" -eq 0 ]]; then
    log_success "🎉 All BookVerse policies and rules cleaned up successfully!"
    exit 0
elif [[ "$total_failed" -eq 0 ]]; then
    log_warning "⚠️ Some policies or rules may still exist (possibly from other operations)"
    exit 0
else
    log_error "❌ Some policies or rules could not be deleted"
    exit 1
fi
