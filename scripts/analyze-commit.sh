#!/bin/bash
# =============================================================================
# DEMO-OPTIMIZED COMMIT ANALYSIS SCRIPT
# =============================================================================
# This script analyzes commits to determine whether they should create:
# 1. Full application version (release-ready commits)
# 2. Build info only (development/maintenance commits)
#
# DEMO OPTIMIZATION: Favors creating application versions for pipeline visibility
# PRODUCTION NOTE: Real systems would default to build-info-only for safety
#
# Usage: ./analyze-commit.sh [commit-sha] [commit-message] [changed-files]
# Outputs: Sets GITHUB_OUTPUT variables for workflow decisions
# =============================================================================

set -euo pipefail

# Input parameters (with fallbacks to current Git state)
COMMIT_SHA="${1:-$(git rev-parse HEAD 2>/dev/null || echo 'unknown')}"
COMMIT_MSG="${2:-$(git log -1 --pretty=%B 2>/dev/null || echo '')}"
CHANGED_FILES="${3:-$(git diff --name-only HEAD~1 2>/dev/null || echo '')}"

# GitHub context (available in GitHub Actions)
GITHUB_REF="${GITHUB_REF:-}"
GITHUB_EVENT_NAME="${GITHUB_EVENT_NAME:-}"
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

# Rule 1: Explicit version control tags
if [[ "$COMMIT_MSG" =~ \[skip-version\] ]] || [[ "$COMMIT_MSG" =~ \[build-only\] ]]; then
    build_info_only "Explicit [skip-version] or [build-only] tag"
fi

if [[ "$COMMIT_MSG" =~ \[release\] ]] || [[ "$COMMIT_MSG" =~ \[version\] ]]; then
    create_app_version "Explicit [release] or [version] tag"
fi

# Rule 2: Conventional Commit prefixes (release-ready)
if [[ "$COMMIT_MSG" =~ ^(feat|fix|perf|refactor)(\(.+\))?!?: ]]; then
    create_app_version "Conventional commit: $(echo "$COMMIT_MSG" | grep -o '^[^:]*:')"
fi

# Rule 3: Hotfix and release branches
if [[ "$GITHUB_REF" =~ ^refs/heads/(release|hotfix)/ ]]; then
    create_app_version "Release/hotfix branch: $(echo "$GITHUB_REF" | sed 's|refs/heads/||')"
fi

# Rule 4: Work-in-progress commits (build-only)
if [[ "$COMMIT_MSG" =~ ^(wip|WIP): ]] || [[ "$COMMIT_MSG" =~ \[WIP\] ]]; then
    build_info_only "Work-in-progress commit"
fi

# Rule 5: Documentation-only changes
if [[ "$COMMIT_MSG" =~ ^docs?: ]] || [[ "$CHANGED_FILES" =~ ^[[:space:]]*$ ]] || \
   [[ -n "$CHANGED_FILES" && $(echo "$CHANGED_FILES" | grep -v '\.md$\|^docs/\|^README' | wc -l) -eq 0 ]]; then
    build_info_only "Documentation-only changes"
fi

# Rule 6: CI/CD configuration changes only
if [[ "$COMMIT_MSG" =~ ^(ci|build)?: ]] || \
   [[ -n "$CHANGED_FILES" && $(echo "$CHANGED_FILES" | grep -v '^\.github/\|^ci/\|^scripts/.*\.yml$\|^scripts/.*\.yaml$' | wc -l) -eq 0 ]]; then
    build_info_only "CI/CD configuration changes only"
fi

# Rule 7: Test-only changes
if [[ "$COMMIT_MSG" =~ ^test?: ]] || \
   [[ -n "$CHANGED_FILES" && $(echo "$CHANGED_FILES" | grep -v '^tests\?/\|.*_test\.\|.*\.test\.' | wc -l) -eq 0 ]]; then
    build_info_only "Test-only changes"
fi

# Rule 8: Dependency updates (usually build-only unless breaking)
if [[ "$COMMIT_MSG" =~ ^(deps|chore)?: ]] && [[ ! "$COMMIT_MSG" =~ BREAKING ]]; then
    build_info_only "Dependency/chore update (non-breaking)"
fi

# Rule 9: Main branch pushes (default to release-ready)
if [[ "$GITHUB_REF" == "refs/heads/main" ]] && [[ "$GITHUB_EVENT_NAME" == "push" ]]; then
    create_app_version "Direct push to main branch"
fi

# Rule 10: Pull request merges to main (release-ready)
if [[ "$GITHUB_BASE_REF" == "main" ]] && [[ "$GITHUB_EVENT_NAME" == "pull_request" ]]; then
    create_app_version "Pull request merge to main"
fi

# =============================================================================
# DEMO DEFAULT DECISION
# =============================================================================

# DEMO DEFAULT: Create application version for pipeline visibility
create_app_version "Demo mode: showing full CI/CD pipeline (unclassified commit)"

# PRODUCTION NOTE: Real systems would use:
# build_info_only "Conservative default: development branch or unclassified commit"
