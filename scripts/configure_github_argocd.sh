#!/bin/bash

# Configure GitHub repository access for ArgoCD using existing webhook PAT
# Usage: ./configure_github_argocd.sh [GITHUB_USERNAME]

set -e

GITHUB_USERNAME="${1:-yonatanp-jfrog}"
GITHUB_TOKEN="${GH_REPO_DISPATCH_TOKEN:-}"

# Check if we have the GitHub token from environment (webhook token)
if [ -z "$GITHUB_TOKEN" ]; then
    echo "❌ Error: GH_REPO_DISPATCH_TOKEN environment variable not found"
    echo ""
    echo "💡 This script uses the existing webhook GitHub PAT from environment."
    echo "   If the token is not available, you can:"
    echo "   1. Set it as environment variable: export GH_REPO_DISPATCH_TOKEN='your-token'"
    echo "   2. Or use the manual configuration: $0 <GITHUB_USERNAME> <GITHUB_TOKEN>"
    exit 1
fi

# Allow manual override with username and token
if [ $# -eq 2 ]; then
    GITHUB_USERNAME="$1"
    GITHUB_TOKEN="$2"
fi

echo "🚀 Configuring GitHub repository access for ArgoCD"
echo "🔧 Username: $GITHUB_USERNAME"
echo "🔧 Token length: ${#GITHUB_TOKEN} characters"
echo ""

# Check if ArgoCD namespace exists
if ! kubectl get namespace argocd >/dev/null 2>&1; then
    echo "❌ Error: ArgoCD namespace 'argocd' does not exist"
    echo "💡 Run the bootstrap script first: ./scripts/k8s/bootstrap.sh"
    exit 1
fi

# Create temporary file with the secret configuration
TEMP_FILE=$(mktemp)
cat > "$TEMP_FILE" << EOF
apiVersion: v1
kind: Secret
metadata:
  name: bookverse-github-repo
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
type: Opaque
stringData:
  name: bookverse-github-repo
  type: git
  url: https://github.com/yonatanp-jfrog/bookverse-helm.git
  username: $GITHUB_USERNAME
  password: $GITHUB_TOKEN
---
apiVersion: v1
kind: Secret
metadata:
  name: github-yonatanp-jfrog-creds
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repo-creds
type: Opaque
stringData:
  name: github-yonatanp-jfrog-creds
  type: git
  url: https://github.com/yonatanp-jfrog
  username: $GITHUB_USERNAME
  password: $GITHUB_TOKEN
EOF

echo "📦 Applying GitHub repository credentials to ArgoCD..."

# Apply the secret
if kubectl apply -f "$TEMP_FILE"; then
    echo "✅ GitHub repository credentials configured successfully"
else
    echo "❌ Failed to configure GitHub repository credentials"
    rm -f "$TEMP_FILE"
    exit 1
fi

# Clean up temporary file
rm -f "$TEMP_FILE"

echo ""
echo "🔄 Refreshing ArgoCD application..."

# Refresh the ArgoCD application to retry repository access
if kubectl -n argocd get application.argoproj.io platform-prod >/dev/null 2>&1; then
    # Try to refresh the application
    if command -v argocd >/dev/null 2>&1; then
        echo "📱 Using argocd CLI to refresh application..."
        argocd app get platform-prod --refresh 2>/dev/null || echo "⚠️  ArgoCD CLI refresh failed (this is normal if not logged in)"
    else
        echo "💡 ArgoCD CLI not available - you can refresh manually in the ArgoCD UI"
    fi
    
    echo "🔍 Checking application status..."
    kubectl -n argocd get application.argoproj.io platform-prod -o jsonpath='{.status.sync.status}' || true
    echo ""
else
    echo "⚠️  ArgoCD application 'platform-prod' not found"
fi

echo ""
echo "🎉 SUCCESS: GitHub repository access configured for ArgoCD!"
echo ""
echo "💡 Next steps:"
echo "   1. Check ArgoCD UI at https://localhost:8081 (if port-forwarded)"
echo "   2. Verify the application can sync successfully"
echo "   3. If issues persist, check that the repository https://github.com/yonatanp-jfrog/bookverse-helm.git exists and is accessible"
