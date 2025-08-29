#!/usr/bin/env bash

# Debug script for evidence keys setup
# Run this locally to debug the evidence keys issue

echo "🐛 EVIDENCE KEYS DEBUG SCRIPT"
echo "============================="
echo ""

# Check if environment file exists
if [[ -f "env.sh" ]]; then
    echo "📁 Loading environment from env.sh..."
    source env.sh
    echo "  ✅ Environment loaded"
else
    echo "📝 Set your credentials here (or create env.sh file):"
    echo ""
    echo "# Create env.sh with your actual values:"
    echo "export JFROG_URL='https://evidencetrial.jfrog.io'"
    echo "export JFROG_ADMIN_TOKEN='your-admin-token-here'"
    echo "export GH_TOKEN='your-github-token-here'"
    echo "export EVIDENCE_KEY_ALIAS='BookVerse-Evidence-Key'"
    echo ""
    
    # Use defaults for testing (user needs to replace)
    export JFROG_URL='https://evidencetrial.jfrog.io'
    export JFROG_ADMIN_TOKEN='your-admin-token-here'  # Replace with actual token
    export GH_TOKEN='your-github-token-here'          # Replace with actual token
    export EVIDENCE_KEY_ALIAS='BookVerse-Evidence-Key'
fi

echo "🔧 Environment:"
echo "  JFROG_URL: ${JFROG_URL}"
echo "  JFROG_ADMIN_TOKEN: ${JFROG_ADMIN_TOKEN:0:10}..."
echo "  GH_TOKEN: ${GH_TOKEN:0:10}..."
echo "  EVIDENCE_KEY_ALIAS: ${EVIDENCE_KEY_ALIAS}"
echo ""

# Check tools
echo "🔍 Checking required tools..."
for tool in gh curl jq; do
    if command -v "$tool" >/dev/null 2>&1; then
        echo "  ✅ $tool: $(which $tool)"
    else
        echo "  ❌ $tool: not found"
        echo "  💡 Install missing tools and try again"
        exit 1
    fi
done
echo ""

# Validate credentials are set
if [[ "$JFROG_ADMIN_TOKEN" == "your-admin-token-here" ]] || [[ -z "$JFROG_ADMIN_TOKEN" ]]; then
    echo "❌ Please set your actual JFROG_ADMIN_TOKEN"
    echo "💡 Edit this script or create env.sh file"
    exit 1
fi

if [[ "$GH_TOKEN" == "your-github-token-here" ]] || [[ -z "$GH_TOKEN" ]]; then
    echo "❌ Please set your actual GH_TOKEN"
    echo "💡 Edit this script or create env.sh file"
    exit 1
fi

# Test JFrog connectivity
echo "🌐 Testing JFrog Platform connectivity..."
if curl -s --fail --header "Authorization: Bearer $JFROG_ADMIN_TOKEN" \
    "${JFROG_URL}/artifactory/api/system/ping" > /dev/null; then
    echo "  ✅ JFrog Platform accessible"
else
    echo "  ❌ JFrog Platform connection failed"
    echo "  💡 Check JFROG_URL and JFROG_ADMIN_TOKEN"
    exit 1
fi
echo ""

# Test GitHub CLI
echo "🐙 Testing GitHub CLI..."
if gh auth status > /dev/null 2>&1; then
    echo "  ✅ GitHub CLI authenticated"
else
    echo "  ❌ GitHub CLI not authenticated"
    echo "  💡 Run: gh auth login"
    exit 1
fi
echo ""

# Show existing trusted keys for context
echo "🔍 Current trusted keys in JFrog Platform:"
curl -s -X GET "$JFROG_URL/artifactory/api/security/keys/trusted" \
  -H "Authorization: Bearer $JFROG_ADMIN_TOKEN" | \
  jq -r '.keys[] | "  - \(.alias) (kid: \(.kid))"' || echo "  (failed to fetch)"
echo ""

echo "🚀 Running evidence keys setup script with FIXED logic..."
echo "========================================================="

# Run the actual script with verbose output
bash -x ./.github/scripts/setup/evidence_keys_setup.sh

echo ""
echo "🏁 Debug session complete!"
echo ""
echo "💡 Key improvements in the fix:"
echo "  ✅ HTTP 409 (conflict) now handled gracefully"
echo "  ✅ Key content comparison to avoid unnecessary replacements"
echo "  ✅ Smart replace logic: delete old → upload new"
echo "  ✅ Better error handling and user feedback"
