#!/usr/bin/env bash

# =============================================================================
# BookVerse Platform - Unified Policy Creation Script
# =============================================================================
#
# This comprehensive script creates and configures all BookVerse unified
# policies according to the specified lifecycle gate requirements, implementing
# enterprise-grade policy management for evidence collection, compliance
# enforcement, and lifecycle gate automation.
#
# 🚀 POLICY ARCHITECTURE:
#     - DEV Stage: Entry gates for Jira and SLSA, Exit gate for smoke tests
#     - QA Stage: Exit gates for DAST and Postman collection testing
#     - STAGING Stage: Exit gates for penetration testing, change management, and IaC scanning
#     - PROD Stage: Release gates for stage completion verification
#
# 📋 POLICIES CREATED:
#     DEV Entry: Atlassian Jira Required, SLSA Provenance Required
#     DEV Exit: Smoke Test Required
#     QA Exit: Invicti DAST Required, Postman Collection Required
#     STAGING Exit: Cobalt Pentest Required, ServiceNow Change Required, Snyk IaC Required
#     PROD Release: DEV Completion Required, QA Completion Required, STAGING Completion Required
#
# Authors: BookVerse Platform Team
# Version: 1.0.0
# Last Updated: 2024
#

set -euo pipefail

source "$(dirname "$0")/common.sh"
source "$(dirname "$0")/config.sh"

log_info "🔐 Creating BookVerse Unified Policies..."

# Check required environment variables
check_env_vars JFROG_URL JFROG_ADMIN_TOKEN PROJECT_KEY

API_BASE="$JFROG_URL/unifiedpolicy/api/v1"
AUTH_HEADER="Authorization: Bearer $JFROG_ADMIN_TOKEN"

# Function to create a unified policy
create_policy() {
    local name="$1"
    local description="$2"
    local stage_key="$3"
    local gate="$4"
    local rule_name="$5"
    local mode="${6:-warning}"
    
    log_info "Creating policy: $name"
    
    # First, find the rule ID by name
    local rule_id
    rule_id=$(curl -s -H "$AUTH_HEADER" "$API_BASE/rules" | \
              jq -r ".items[] | select(.name == \"$rule_name\") | .id" | head -1)
    
    if [[ -z "$rule_id" || "$rule_id" == "null" ]]; then
        log_error "Rule not found: $rule_name"
        return 1
    fi
    
    log_debug "Found rule ID: $rule_id for rule: $rule_name"
    
    # Create the policy
    local policy_data
    policy_data=$(cat <<EOF
{
    "description": "$description",
    "name": "$name",
    "action": {
        "stage": {
            "gate": "$gate",
            "key": "$stage_key"
        },
        "type": "certify_to_gate"
    },
    "enabled": true,
    "mode": "$mode",
    "rule_ids": ["$rule_id"],
    "scope": {
        "project_keys": ["$PROJECT_KEY"],
        "type": "project"
    }
}
EOF
    )
    
    local response
    response=$(curl -s -w "%{http_code}" -X POST \
        -H "$AUTH_HEADER" \
        -H "Content-Type: application/json" \
        -d "$policy_data" \
        "$API_BASE/policies")
    
    local http_code="${response: -3}"
    local body="${response%???}"
    
    if [[ "$http_code" == "200" || "$http_code" == "201" ]]; then
        local policy_id
        policy_id=$(echo "$body" | jq -r '.id')
        log_success "✅ Created policy: $name (ID: $policy_id)"
        return 0
    else
        log_error "❌ Failed to create policy: $name (HTTP $http_code)"
        log_debug "Response: $body"
        return 1
    fi
}

# Function to check if a policy already exists
policy_exists() {
    local name="$1"
    local existing_id
    existing_id=$(curl -s -H "$AUTH_HEADER" "$API_BASE/policies?projectKey=$PROJECT_KEY" | \
                  jq -r ".items[] | select(.name == \"$name\") | .id")
    
    if [[ -n "$existing_id" && "$existing_id" != "null" ]]; then
        log_info "Policy already exists: $name (ID: $existing_id)"
        return 0
    else
        return 1
    fi
}

# Create all BookVerse policies
log_info "📋 Creating BookVerse Unified Policies..."

# DEV Stage Policies
log_section "DEV Stage Policies"

if ! policy_exists "BookVerse DEV Entry - Atlassian Jira Required"; then
    create_policy \
        "BookVerse DEV Entry - Atlassian Jira Required" \
        "Requires Atlassian Jira release evidence for DEV stage entry" \
        "$PROJECT_KEY-DEV" \
        "entry" \
        "BookVerse Atlassian Jira Evidence - DEV Entry"
fi

if ! policy_exists "BookVerse DEV Entry - SLSA Provenance Required"; then
    create_policy \
        "BookVerse DEV Entry - SLSA Provenance Required" \
        "Requires SLSA provenance evidence for DEV stage entry" \
        "$PROJECT_KEY-DEV" \
        "entry" \
        "BookVerse SLSA Provenance Evidence - DEV Entry"
fi

if ! policy_exists "BookVerse DEV Exit - Smoke Test Required"; then
    create_policy \
        "BookVerse DEV Exit - Smoke Test Required" \
        "Requires smoke test evidence for DEV stage exit" \
        "$PROJECT_KEY-DEV" \
        "exit" \
        "BookVerse Smoke Test Evidence - DEV Exit"
fi

# QA Stage Policies
log_section "QA Stage Policies"

if ! policy_exists "BookVerse QA Exit - Invicti DAST Required"; then
    create_policy \
        "BookVerse QA Exit - Invicti DAST Required" \
        "Requires Invicti DAST scan evidence for QA stage exit" \
        "$PROJECT_KEY-QA" \
        "exit" \
        "BookVerse Invicti DAST Evidence - QA Exit"
fi

if ! policy_exists "BookVerse QA Exit - Postman Collection Required"; then
    create_policy \
        "BookVerse QA Exit - Postman Collection Required" \
        "Requires Postman collection test evidence for QA stage exit" \
        "$PROJECT_KEY-QA" \
        "exit" \
        "BookVerse Postman Collection Evidence - QA Exit"
fi

# STAGING Stage Policies
log_section "STAGING Stage Policies"

if ! policy_exists "BookVerse STAGING Exit - Cobalt Pentest Required"; then
    create_policy \
        "BookVerse STAGING Exit - Cobalt Pentest Required" \
        "Requires Cobalt penetration testing evidence for STAGING stage exit" \
        "$PROJECT_KEY-STAGING" \
        "exit" \
        "BookVerse Cobalt Pentest Evidence - STAGING"
fi

if ! policy_exists "BookVerse STAGING Exit - ServiceNow Change Required"; then
    create_policy \
        "BookVerse STAGING Exit - ServiceNow Change Required" \
        "Requires ServiceNow change approval evidence for STAGING stage exit" \
        "$PROJECT_KEY-STAGING" \
        "exit" \
        "BookVerse ServiceNow Change Evidence - STAGING"
fi

if ! policy_exists "BookVerse STAGING Exit - Snyk IaC Required"; then
    create_policy \
        "BookVerse STAGING Exit - Snyk IaC Required" \
        "Requires Snyk Infrastructure as Code scan evidence for STAGING stage exit" \
        "$PROJECT_KEY-STAGING" \
        "exit" \
        "BookVerse Snyk IaC Evidence - STAGING"
fi

# PROD Stage Policies
log_section "PROD Stage Policies"

if ! policy_exists "BookVerse PROD Release - DEV Completion Required"; then
    create_policy \
        "BookVerse PROD Release - DEV Completion Required" \
        "Requires DEV stage completion before PROD release" \
        "$PROJECT_KEY-PROD" \
        "release" \
        "BookVerse DEV Stage Completion for PROD"
fi

if ! policy_exists "BookVerse PROD Release - QA Completion Required"; then
    create_policy \
        "BookVerse PROD Release - QA Completion Required" \
        "Requires QA stage completion before PROD release" \
        "$PROJECT_KEY-PROD" \
        "release" \
        "BookVerse QA Stage Completion for PROD"
fi

if ! policy_exists "BookVerse PROD Release - STAGING Completion Required"; then
    create_policy \
        "BookVerse PROD Release - STAGING Completion Required" \
        "Requires STAGING stage completion before PROD release" \
        "$PROJECT_KEY-PROD" \
        "release" \
        "BookVerse STAGING Stage Completion for PROD"
fi

# Verify all policies were created
log_section "Policy Verification"
log_info "🔍 Verifying all policies were created..."

policy_count=$(curl -s -H "$AUTH_HEADER" "$API_BASE/policies?projectKey=$PROJECT_KEY" | \
               jq '.items | length')

log_info "📊 Total BookVerse policies created: $policy_count"

# List all created policies
log_info "📋 BookVerse Policy Summary:"
curl -s -H "$AUTH_HEADER" "$API_BASE/policies?projectKey=$PROJECT_KEY" | \
    jq -r '.items[] | "  ✅ \(.name) (\(.action.stage.key) \(.action.stage.gate))"' | \
    sort

log_success "🎉 BookVerse Unified Policies creation completed successfully!"
