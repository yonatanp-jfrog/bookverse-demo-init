#!/bin/bash
set -euo pipefail


SERVICE="$1"
ORG="${2:-yonatanp-jfrog}"

if [[ -z "$SERVICE" ]]; then
    echo "❌ Usage: $0 <service-name> [org-name]"
    echo "📋 Available services:"
    ls -d bookverse-* | grep -v bookverse-demo
    exit 1
fi

echo "🚀 Splitting service: $SERVICE"
echo "🏢 GitHub organization: $ORG"

if [[ ! -d "$SERVICE" ]]; then
    echo "❌ Directory $SERVICE not found!"
    exit 1
fi

TEMP_DIR=$(mktemp -d)
echo "📂 Temporary directory: $TEMP_DIR"

echo "📋 Step 1: Cloning monorepo..."
REMOTE_URL=$(git remote get-url origin)
git clone "$REMOTE_URL" "$TEMP_DIR/$SERVICE"

cd "$TEMP_DIR/$SERVICE"

echo "📋 Step 2: Filtering git history for $SERVICE..."

export PATH="$PATH:/Users/$USER/Library/Python/3.9/bin"

if command -v git-filter-repo >/dev/null 2>&1; then
    echo "🚀 Using git-filter-repo (fast)"
    git filter-repo --force --path "$SERVICE/" --path-rename "$SERVICE/:"
else
    echo "⚠️  Using git filter-branch (slower)"
    git filter-branch --prune-empty --subdirectory-filter "$SERVICE" HEAD
fi

echo "📋 Step 3: Cleaning up..."
git for-each-ref --format="%(refname)" refs/original/ | xargs -n 1 git update-ref -d 2>/dev/null || true
git reflog expire --expire=now --all
git gc --aggressive --prune=now

echo "📋 Step 4: Repository status"
echo "📁 Files in root:"
ls -la

echo "📁 Git log (last 3 commits):"
git log --oneline -3

echo ""
echo "🤔 Does this look correct? The service files should be in the root."
read -p "Continue with GitHub repository creation? (y/N): " -n 1 -r
echo

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Aborting. Temp directory preserved: $TEMP_DIR"
    exit 1
fi

echo "📋 Step 5: Creating GitHub repository..."
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

echo "📋 Step 6: Pushing to GitHub..."
git remote remove origin
git remote add origin "git@github.com:$ORG/$SERVICE.git"
git push -u origin main

echo "✅ Successfully created $ORG/$SERVICE"
echo "🌐 View at: https://github.com/$ORG/$SERVICE"

echo ""
read -p "🧹 Clean up temp directory? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -rf "$TEMP_DIR"
    echo "🗑️  Cleaned up"
else
    echo "📁 Preserved: $TEMP_DIR"
fi

echo ""
echo "📋 Next steps for $SERVICE:"
echo "1. ✅ Check the repository workflows"
echo "2. 🔧 Set up repository variables (PROJECT_KEY, JFROG_URL, etc.)"
echo "3. 🔑 Set up repository secrets (EVIDENCE_PRIVATE_KEY, etc.)"
echo "4. 🔗 Configure OIDC provider: $SERVICE-github"
echo "5. 🧪 Test the CI workflow"
