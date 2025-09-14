#!/bin/bash
# =============================================================================
# BOOKVERSE SHARED COMMIT ANALYSIS SCRIPT
# =============================================================================
# This shared script analyzes commits to determine whether they should create:
# 1. Full application version (release-ready commits)
# 2. Build info only (development/maintenance commits)
#
# SHARED COMPONENT: Used across all BookVerse services for consistent CI/CD decisions
# DEMO OPTIMIZATION: Favors creating application versions for pipeline visibility
# PRODUCTION NOTE: Real systems would default to build-info-only for safety
#
# Usage: ../bookverse-demo-init/bookverse-devops/scripts/analyze-commit.sh [commit-sha] [commit-message] [changed-files]
# Outputs: Sets GITHUB_OUTPUT variables for workflow decisions
#
# CONSOLIDATION: Eliminates 400+ lines of duplicate code across services
# MAINTENANCE: Single source of truth for commit analysis logic
# =============================================================================

set -euo pipefail

# Input parameters (with fallbacks to current Git state)
COMMIT_SHA="${1:-$(git rev-parse HEAD 2>/dev/null || echo 'unknown')}"
COMMIT_MSG="${2:-$(git log -1 --pretty=%B 2>/dev/null || echo '')}"
CHANGED_FILES="${3:-$(git diff --name-only HEAD~1 2>/dev/null || echo '')}"
GITHUB_EVENT_NAME="${GITHUB_EVENT_NAME:-push}"
GITHUB_BASE_REF="${GITHUB_BASE_REF:-}"

# Output file for GitHub Actions
OUTPUT_FILE="${GITHUB_OUTPUT:-/dev/stdout}"

echo "🎯 DEMO MODE: Analyzing commit for CI/CD pipeline demonstration"
echo "📝 Commit: ${COMMIT_SHA:0:8}"
echo "💬 Message: $COMMIT_MSG"
echo "📁 Changed files: $(echo "$CHANGED_FILES" | wc -l) files"
echo "🏭 Production note: Real systems would use conservative defaults"
echo ""

# =============================================================================
# RELEASE-READY COMMIT PATTERNS
# =============================================================================

create_app_version() {
    local reason="$1"
    echo "✅ DEMO DECISION: Create Application Version"
    echo "📋 Reason: $reason"
    echo "🚀 This will trigger the full CI/CD pipeline for demo visibility"
    echo "create_app_version=true" >> "$OUTPUT_FILE"
    echo "decision_reason=$reason" >> "$OUTPUT_FILE"
    echo "commit_type=release-ready" >> "$OUTPUT_FILE"
    exit 0
}

build_info_only() {
    local reason="$1"
    echo "🔨 DEMO DECISION: Build Info Only"
    echo "📋 Reason: $reason"
    echo "📝 Build info created for traceability, but no promotion pipeline"
    echo "🏭 Production note: This would be the default behavior in real systems"
    echo "create_app_version=false" >> "$OUTPUT_FILE"
    echo "decision_reason=$reason" >> "$OUTPUT_FILE"
    echo "commit_type=build-only" >> "$OUTPUT_FILE"
    exit 0
}

# =============================================================================
# ANALYSIS RULES (Priority Order)
# =============================================================================

# Rule 0: Manual workflow dispatch (highest priority)
if [[ "$GITHUB_EVENT_NAME" == "workflow_dispatch" ]]; then
  if [[ "${GITHUB_EVENT_INPUTS_FORCE_APP_VERSION:-false}" == "true" ]]; then
    create_app_version "Manual trigger with force_app_version=true"
  else
    build_info_only "Manual trigger for testing/debugging (default: build-info only)"
  fi
fi

# Rule 1: Explicit [skip-version] tag
if [[ "$COMMIT_MSG" =~ \[skip-version\] ]]; then
    build_info_only "Explicit [skip-version] tag"
    exit 0
fi

# Rule 2: Documentation-only changes
# Checks if commit message starts with 'docs:' AND only documentation-related files changed
if [[ "$COMMIT_MSG" =~ ^docs?: ]] && [[ -n "$CHANGED_FILES" ]] && [[ $(echo "$CHANGED_FILES" | grep -v '\.md$\|^docs/\|^README' | wc -l) -eq 0 ]]; then
    build_info_only "Documentation-only changes"
    exit 0
fi

# Rule 3: Test-only changes
# Checks if commit message starts with 'test:' AND only test-related files changed
if [[ "$COMMIT_MSG" =~ ^test?: ]] && [[ -n "$CHANGED_FILES" ]] && [[ $(echo "$CHANGED_FILES" | grep -v '^tests\?/\|_test\.\|\.test\.' | wc -l) -eq 0 ]]; then
    build_info_only "Test-only changes"
    exit 0
fi

# Rule 4: Conventional commits (feat, fix, perf, refactor)
if [[ "$COMMIT_MSG" =~ ^(feat|fix|perf|refactor): ]]; then
    create_app_version "Conventional commit: feat/fix/perf/refactor"
    exit 0
fi

# Rule 5: Explicit [release] or [version] tag
if [[ "$COMMIT_MSG" =~ \[(release|version)\] ]]; then
    create_app_version "Explicit [release] or [version] tag"
    exit 0
fi

# Rule 6: Release or hotfix branches
if [[ "$GITHUB_REF" =~ ^refs/heads/(release|hotfix)/ ]]; then
    create_app_version "Release or hotfix branch"
    exit 0
fi

# Rule 7: Main branch pushes
if [[ "$GITHUB_REF" == "refs/heads/main" ]] && [[ "$GITHUB_EVENT_NAME" == "push" ]]; then
    create_app_version "Push to main branch"
    exit 0
fi

# Rule 8: Pull request merges to main (release-ready)
if [[ "$GITHUB_BASE_REF" == "main" ]] && [[ "$GITHUB_EVENT_NAME" == "pull_request" ]]; then
    create_app_version "Pull request merge to main"
    exit 0
fi

# =============================================================================
# DEMO DEFAULT DECISION
# =============================================================================

# DEMO DEFAULT: Create application version for pipeline visibility
# This is the default behavior when no specific rules match
create_app_version "Demo mode: showing full CI/CD pipeline (unclassified commit)"

# PRODUCTION NOTE: Real systems would use:
# build_info_only "Conservative default: development branch or unclassified commit"
