#!/usr/bin/env bash


set -e

source "$(dirname "$0")/config.sh"

echo ""
echo "📦 Publishing BookVerse Libraries"
echo "🔧 Project: $PROJECT_KEY"
echo "🔧 JFrog URL: $JFROG_URL"
echo ""

INFRA_REPO_OWNER="${GITHUB_REPOSITORY_OWNER:-yonatanp-jfrog}"
INFRA_REPO_NAME="bookverse-infra"

echo "🔍 Checking bookverse-infra repository..."
if ! gh repo view "$INFRA_REPO_OWNER/$INFRA_REPO_NAME" >/dev/null 2>&1; then
    echo "❌ bookverse-infra repository not found or not accessible"
    echo "   Expected: $INFRA_REPO_OWNER/$INFRA_REPO_NAME"
    echo "   Please ensure the repository exists and you have access"
    exit 1
fi

echo "✅ bookverse-infra repository found: $INFRA_REPO_OWNER/$INFRA_REPO_NAME"

echo ""
echo "🚀 Triggering CI workflow to publish libraries..."
echo "   This will build and publish bookverse-core and bookverse-devops packages"

TRIGGER_REASON="Library publishing for demo setup - triggered by setup script"

if gh workflow run ci.yml \
    --repo "$INFRA_REPO_OWNER/$INFRA_REPO_NAME" \
    --field reason="$TRIGGER_REASON" \
    --field force_app_version=true; then
    echo "✅ CI workflow triggered successfully"
else
    echo "❌ Failed to trigger CI workflow"
    echo "   Please check GitHub CLI authentication and repository permissions"
    exit 1
fi

echo ""
echo "⏳ Waiting for workflow to start..."
sleep 10

echo "🔍 Monitoring workflow progress..."
LATEST_RUN_ID=$(gh run list --repo "$INFRA_REPO_OWNER/$INFRA_REPO_NAME" --limit 1 --json databaseId --jq '.[0].databaseId')

if [[ -z "$LATEST_RUN_ID" ]]; then
    echo "❌ Could not find workflow run"
    exit 1
fi

echo "📋 Workflow run ID: $LATEST_RUN_ID"
echo "🔗 View progress: https://github.com/$INFRA_REPO_OWNER/$INFRA_REPO_NAME/actions/runs/$LATEST_RUN_ID"

echo ""
echo "⏳ Waiting for workflow to complete (this may take 5-10 minutes)..."
echo "   You can monitor progress at the URL above"

MAX_WAIT_MINUTES=15
WAIT_COUNT=0

while [[ $WAIT_COUNT -lt $((MAX_WAIT_MINUTES * 12)) ]]; do
    RUN_STATUS=$(gh api "repos/$INFRA_REPO_OWNER/$INFRA_REPO_NAME/actions/runs/$LATEST_RUN_ID" --jq '.status')
    RUN_CONCLUSION=$(gh api "repos/$INFRA_REPO_OWNER/$INFRA_REPO_NAME/actions/runs/$LATEST_RUN_ID" --jq '.conclusion // "null"')
    
    echo "   Status: $RUN_STATUS, Conclusion: $RUN_CONCLUSION"
    
    if [[ "$RUN_STATUS" == "completed" ]]; then
        if [[ "$RUN_CONCLUSION" == "success" ]]; then
            echo ""
            echo "✅ Library publishing completed successfully!"
            echo "📦 bookverse-core and bookverse-devops are now available in JFrog registry"
            break
        else
            echo ""
            echo "❌ Library publishing failed with conclusion: $RUN_CONCLUSION"
            echo "🔗 Check logs: https://github.com/$INFRA_REPO_OWNER/$INFRA_REPO_NAME/actions/runs/$LATEST_RUN_ID"
            exit 1
        fi
    fi
    
    sleep 5
    ((WAIT_COUNT++))
done

if [[ $WAIT_COUNT -ge $((MAX_WAIT_MINUTES * 12)) ]]; then
    echo ""
    echo "⚠️  Workflow is taking longer than expected ($MAX_WAIT_MINUTES minutes)"
    echo "🔗 Please check manually: https://github.com/$INFRA_REPO_OWNER/$INFRA_REPO_NAME/actions/runs/$LATEST_RUN_ID"
    echo "   The setup will continue, but services may fail if libraries aren't published yet"
fi

echo ""
echo "📋 Library Publishing Summary:"
echo "   - bookverse-core: Python commons library"
echo "   - bookverse-devops: CI/CD workflows and scripts"
echo "   - Published to: $JFROG_URL"
echo "   - Available for service consumption"
echo ""
echo "✅ Library publishing process completed"
