#!/bin/bash

# 🚨 EMERGENCY PATCH: Stop catastrophic repository deletion
# This script fixes the critical bug where ALL repositories are being deleted

echo "🚨 APPLYING EMERGENCY SECURITY PATCH"
echo "===================================="
echo ""
echo "CRITICAL BUG: cleanup_project_based.sh is deleting ALL repositories"
echo "USER EVIDENCE: carmit-*, catalina-* repos being deleted (no 'bookverse'!)"
echo ""

# Create backup
cp ./.github/scripts/setup/cleanup_project_based.sh ./.github/scripts/setup/cleanup_project_based.sh.DANGEROUS_BACKUP

echo "📋 APPLYING EMERGENCY FIXES:"
echo ""

# 1. Add EMERGENCY SAFETY CHECK before any repository deletion
echo "1. Adding pre-deletion safety verification..."

# Insert safety check before repository deletion
sed -i.bak '/# Delete project repositories/i\
# 🚨 EMERGENCY SAFETY CHECK: Verify repository belongs to project\
verify_repository_project_membership() {\
    local repo_key="$1"\
    echo "🛡️ SAFETY: Verifying repository '\''$repo_key'\'' belongs to project '\''$PROJECT_KEY'\''"...\
    \
    # CRITICAL: Only delete repositories that contain the project key\
    if [[ "$repo_key" == *"$PROJECT_KEY"* ]]; then\
        echo "    ✅ SAFE: Repository contains '\''$PROJECT_KEY'\''"\
        return 0\
    else\
        echo "    🚨 BLOCKED: Repository does NOT contain '\''$PROJECT_KEY'\'' - REFUSING DELETION"\
        return 1\
    fi\
}\
' ./.github/scripts/setup/cleanup_project_based.sh

# 2. Modify the repository deletion loop to use safety check
echo "2. Adding safety check to deletion loop..."

sed -i.bak2 's/if \[\[ -n "$repo_key" \]\]; then/if [[ -n "$repo_key" ]] \&\& verify_repository_project_membership "$repo_key"; then/' ./.github/scripts/setup/cleanup_project_based.sh

# 3. Add emergency logging to see what's being discovered
echo "3. Adding emergency discovery logging..."

sed -i.bak3 '/# Extract all repository keys from project/a\
        echo "🚨 DEBUG: Repositories discovered for deletion:" >&2\
        jq -r '\''.[] | .key'\'' "$repos_file" | head -20 | while read -r repo; do echo "    - $repo" >&2; done\
        echo "    (showing first 20 of $(jq length "$repos_file") total)" >&2\
' ./.github/scripts/setup/cleanup_project_based.sh

# 4. Add final safety check before starting deletion
echo "4. Adding final safety prompt..."

sed -i.bak4 '/🗑️ Starting project repository deletion/a\
    echo "🚨 EMERGENCY SAFETY CHECK: About to delete repositories"\
    echo "Project: $PROJECT_KEY"\
    echo "Count: $count repositories"\
    echo ""\
    echo "⚠️ This action will delete repositories. Proceeding..."\
' ./.github/scripts/setup/cleanup_project_based.sh

echo ""
echo "✅ EMERGENCY PATCH APPLIED!"
echo ""
echo "🛡️ SAFETY MEASURES ADDED:"
echo "  1. Pre-deletion repository verification"
echo "  2. Project membership check for each repo"
echo "  3. Enhanced discovery logging"
echo "  4. Safety prompts and warnings"
echo ""
echo "📋 BACKUPS CREATED:"
echo "  - cleanup_project_based.sh.DANGEROUS_BACKUP (original)"
echo "  - cleanup_project_based.sh.bak* (intermediate backups)"
echo ""
echo "🚨 CRITICAL: This patch provides emergency protection"
echo "    but the underlying filtering logic still needs proper fix!"
