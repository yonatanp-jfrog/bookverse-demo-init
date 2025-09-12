#!/bin/bash
set -euo pipefail

# BookVerse Service Split using git subtree
# This approach is cleaner for splitting services

SERVICE="$1"
ORG="${2:-yonatanp-jfrog}"

if [[ -z "$SERVICE" ]]; then
    echo "❌ Usage: $0 <service-name> [org-name]"
    echo "📋 Available services:"
    ls -d bookverse-* | grep -v bookverse-demo
    exit 1
fi

echo "🚀 Splitting service: $SERVICE using git subtree"
echo "🏢 GitHub organization: $ORG"

# Check if service directory exists
if [[ ! -d "$SERVICE" ]]; then
    echo "❌ Directory $SERVICE not found!"
    exit 1
fi

echo "📋 Step 1: Creating GitHub repository..."
if gh repo view "$ORG/$SERVICE" >/dev/null 2>&1; then
    echo "📦 Repository $ORG/$SERVICE already exists"
    read -p "🤔 Delete and recreate? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        gh repo delete "$ORG/$SERVICE" --yes
        gh repo create "$ORG/$SERVICE" --private --description "BookVerse $SERVICE service"
    else
        echo "⏭️  Skipping repository creation"
        exit 1
    fi
else
    gh repo create "$ORG/$SERVICE" --private --description "BookVerse $SERVICE service"
fi

echo "📋 Step 2: Pushing service history using git subtree..."
git subtree push --prefix="$SERVICE" "git@github.com:$ORG/$SERVICE.git" main

echo "✅ Successfully created $ORG/$SERVICE with full git history"
echo "🌐 View at: https://github.com/$ORG/$SERVICE"

echo ""
echo "📋 Next steps for $SERVICE:"
echo "1. ✅ Clone the new repository to verify structure"
echo "2. 🔧 Set up repository variables (PROJECT_KEY, JFROG_URL, etc.)"
echo "3. 🔑 Set up repository secrets (EVIDENCE_PRIVATE_KEY, etc.)"
echo "4. 🔗 Configure OIDC provider: $SERVICE-github"
echo "5. 🧪 Test the CI workflow"
