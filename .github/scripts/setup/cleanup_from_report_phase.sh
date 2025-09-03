#!/usr/bin/env bash

set -euo pipefail

# Load shared utilities
source "$(dirname "$0")/common.sh"

# Initialize script
init_script "$(basename "$0")" "Executing cleanup for a specific phase from shared report"

SHARED_REPORT_FILE=".github/cleanup-report.json"

if [[ ! -f "$SHARED_REPORT_FILE" ]]; then
    log_error "❌ No cleanup report found - run 🔍 Discover Cleanup first"
    exit 1
fi

phase="${1:-}"  # builds|applications|repositories|users|stages|oidc|domain_users|project
if [[ -z "$phase" ]]; then
    log_error "❌ Missing required argument: phase"
    echo "Usage: $0 <builds|applications|repositories|users|stages|oidc|domain_users|project>"
    exit 2
fi

# Load report metadata
report_timestamp=$(jq -r '.metadata.timestamp' "$SHARED_REPORT_FILE")
project_key=$(jq -r '.metadata.project_key' "$SHARED_REPORT_FILE")

log_info "📋 Report generated: $report_timestamp"
log_info "🔑 Project: $project_key"

# Materialize structured plan files from report (filter by expected project for safety)
repos_file="/tmp/repos_to_delete.txt"
apps_file="/tmp/apps_to_delete.txt"
users_file="/tmp/users_to_delete.txt"
stages_file="/tmp/stages_to_delete.txt"
builds_file="/tmp/builds_to_delete.txt"
oidc_file="/tmp/oidc_to_delete.txt"
domain_users_file="/tmp/domain_users_to_delete.txt"

jq -r --arg p "$project_key" '.plan.repositories[]? | select(.project==$p) | .key' "$SHARED_REPORT_FILE" > "$repos_file" 2>/dev/null || true
jq -r --arg p "$project_key" '.plan.applications[]? | select(.project==$p) | .key' "$SHARED_REPORT_FILE" > "$apps_file" 2>/dev/null || true
jq -r --arg p "$project_key" '.plan.users[]? | select(.project==$p) | .name' "$SHARED_REPORT_FILE" > "$users_file" 2>/dev/null || true
jq -r --arg p "$project_key" '.plan.stages[]? | select(.project==$p) | .name' "$SHARED_REPORT_FILE" > "$stages_file" 2>/dev/null || true
jq -r --arg p "$project_key" '.plan.builds[]? | select(.project==$p) | .name' "$SHARED_REPORT_FILE" > "$builds_file" 2>/dev/null || true
# OIDC integrations (global; not scoped by project)
jq -r '.plan.oidc[]? // empty' "$SHARED_REPORT_FILE" > "$oidc_file" 2>/dev/null || true
# Global domain users (not scoped by project)
jq -r '.plan.domain_users[]? // empty' "$SHARED_REPORT_FILE" > "$domain_users_file" 2>/dev/null || true

# Load deletion functions
source "$(dirname "$0")/cleanup_project_based.sh"

FAILED=false

case "$phase" in
  builds)
    if [[ -s "$builds_file" ]]; then
      count=$(wc -l < "$builds_file")
      log_step "🔧 Deleting $count builds from report"
      delete_specific_builds "$builds_file" || FAILED=true
    else
      log_info "🔧 No builds found in report to delete"
    fi
    ;;
  applications)
    if [[ -s "$apps_file" ]]; then
      count=$(wc -l < "$apps_file")
      log_step "🚀 Deleting $count applications from report"
      delete_specific_applications "$apps_file" || FAILED=true
    else
      log_info "🚀 No applications found in report to delete"
    fi
    ;;
  repositories)
    if [[ -s "$repos_file" ]]; then
      count=$(wc -l < "$repos_file")
      log_step "📦 Deleting $count repositories from report"
      delete_specific_repositories "$repos_file" || FAILED=true
    else
      log_info "📦 No repositories found in report to delete"
    fi
    ;;
  users)
    if [[ -s "$users_file" ]]; then
      count=$(wc -l < "$users_file")
      log_step "👥 Removing $count project members from report"
      delete_specific_users "$users_file" || FAILED=true
    else
      log_info "👥 No project members found in report to remove"
    fi
    ;;
  stages)
    if [[ -s "$stages_file" ]]; then
      count=$(wc -l < "$stages_file")
      log_step "🏷️ Deleting $count stages from report"
      delete_specific_stages "$stages_file" || FAILED=true
    else
      log_info "🏷️ No stages found in report to delete"
    fi
    ;;
  oidc)
    if [[ -s "$oidc_file" ]]; then
      count=$(wc -l < "$oidc_file")
      log_step "🔐 Deleting $count OIDC integrations from report"
      delete_specific_oidc_integrations "$oidc_file" || FAILED=true
    else
      log_info "🔐 No OIDC integrations found in report to delete"
    fi
    ;;
  domain_users)
    if [[ -s "$domain_users_file" ]]; then
      count=$(wc -l < "$domain_users_file")
      log_step "👥 Deleting $count global @bookverse.com users from report"
      delete_specific_users "$domain_users_file" || FAILED=true
    else
      log_info "👥 No global domain users found in report to delete"
    fi
    ;;
  project)
    log_step "🎯 Attempting final project deletion: $project_key"
    if delete_project_final "$project_key"; then
      log_success "✅ Project '$project_key' deleted successfully"
    else
      log_error "❌ Failed to delete project '$project_key'"
      FAILED=true
    fi
    ;;
  *)
    log_error "❌ Unknown phase: $phase"
    exit 2
    ;;
esac

if [[ "$FAILED" == "true" ]]; then
  exit 1
fi

exit 0


