#!/bin/bash

# Configure JFROG_ACCESS_TOKEN for all BookVerse service repositories
# Usage: ./configure_service_secrets.sh <JFROG_ACCESS_TOKEN>

set -e

JFROG_ACCESS_TOKEN="$1"

if [ -z "$JFROG_ACCESS_TOKEN" ]; then
    echo "❌ Error: JFROG_ACCESS_TOKEN is required"
    echo "Usage: $0 <JFROG_ACCESS_TOKEN>"
    echo ""
    echo "💡 Get the token value from bookverse-demo-init repository admin"
    exit 1
fi

echo "🚀 Configuring JFROG_ACCESS_TOKEN for all BookVerse service repositories"
echo "🔧 Token length: ${#JFROG_ACCESS_TOKEN} characters"
echo ""

# List of service repositories that need JFROG_ACCESS_TOKEN
SERVICE_REPOS=(
    "yonatanp-jfrog/bookverse-inventory"
    "yonatanp-jfrog/bookverse-recommendations"
    "yonatanp-jfrog/bookverse-checkout"
    "yonatanp-jfrog/bookverse-platform"
    "yonatanp-jfrog/bookverse-web"
    "yonatanp-jfrog/bookverse-helm"
)

# Optional: Configure GH_REPO_DISPATCH_TOKEN for platform repo (for CI validation)
if [[ -n "${GH_REPO_DISPATCH_TOKEN:-}" ]]; then
    echo "🔐 Configuring GH_REPO_DISPATCH_TOKEN for bookverse-platform (optional)"
    if echo -n "$GH_REPO_DISPATCH_TOKEN" | gh secret set GH_REPO_DISPATCH_TOKEN --repo "yonatanp-jfrog/bookverse-platform"; then
        echo "✅ bookverse-platform: GH_REPO_DISPATCH_TOKEN configured"
    else
        echo "⚠️  Failed to set GH_REPO_DISPATCH_TOKEN in bookverse-platform (continuing)"
    fi
else
    echo "ℹ️ GH_REPO_DISPATCH_TOKEN not provided; skipping repo secret configuration"
fi

# Configure secret for each repository
for repo in "${SERVICE_REPOS[@]}"; do
    echo "📦 Configuring ${repo}..."
    
    # Set the secret using GitHub CLI
    if echo "$JFROG_ACCESS_TOKEN" | gh secret set JFROG_ACCESS_TOKEN --repo "$repo"; then
        echo "✅ ${repo}: JFROG_ACCESS_TOKEN configured successfully"
    else
        echo "❌ ${repo}: Failed to configure JFROG_ACCESS_TOKEN"
        exit 1
    fi
    echo ""
done

echo "🎉 SUCCESS: JFROG_ACCESS_TOKEN configured for all service repositories!"
echo ""
echo "📋 Configured repositories:"
for repo in "${SERVICE_REPOS[@]}"; do
    echo "  ✅ ${repo}"
done
echo ""
echo "🔍 Verification:"
echo "You can now run CI workflows on any service repository."
echo "They should successfully authenticate with JFrog Platform."
echo ""
echo "🚀 Ready for complete end-to-end CI/CD testing!"
