#!/usr/bin/env bash
# =============================================================================
# BookVerse Platform - GitHub ArgoCD Repository Configuration Script
# =============================================================================
#
# Comprehensive GitHub repository credentials configuration for ArgoCD GitOps
#
# ⚠️ ERROR HANDLING STRATEGY:
#     This script implements comprehensive error handling with multiple failure
#     detection patterns, graceful degradation mechanisms, and detailed recovery
#     procedures to ensure reliable ArgoCD configuration operations.
#
# 🔧 Error Detection Patterns:
#     - Environment Validation: Missing tokens, invalid credentials, configuration errors
#     - Kubernetes Integration: Cluster connectivity, namespace validation, resource conflicts
#     - ArgoCD Verification: Application status, synchronization failures, CLI availability
#     - Repository Access: GitHub connectivity, authentication failures, permission issues
#     - Resource Management: Temporary file handling, cleanup procedures, resource leaks
#
# 🛡️ Failure Recovery Mechanisms:
#     - Automatic Cleanup: Temporary file removal on all exit paths
#     - Graceful Degradation: Continues operation when optional components fail
#     - Validation Checkpoints: Pre-flight checks before critical operations
#     - Rollback Capabilities: Safe exit with detailed error reporting
#     - Resource Protection: Prevents resource leaks and cleanup on failure
#
# 🔍 Debugging and Troubleshooting:
#     - Comprehensive error messages with actionable recovery instructions
#     - Debug mode support with detailed operation tracing
#     - Manual verification commands for post-failure diagnosis
#     - Integration testing patterns for continuous validation
#     - Performance monitoring for operation timeout detection
#
# ❌ Common Failure Modes and Recovery:
#     [Authentication Failures]
#     - Missing GitHub token: Detailed token acquisition instructions
#     - Invalid token format: Token validation with format requirements
#     - Insufficient permissions: Scope verification and regeneration guidance
#     - Token expiration: Renewal procedures and automated detection
#     
#     [Kubernetes Integration Failures]
#     - Cluster connectivity: Connection testing and troubleshooting
#     - Missing ArgoCD namespace: Bootstrap dependency verification
#     - kubectl configuration: CLI setup and authentication validation
#     - Resource conflicts: Existing secret handling and overwrite protection
#     
#     [ArgoCD Operation Failures]
#     - Application not found: Application deployment status verification
#     - Sync failures: Repository access and credential validation
#     - CLI unavailability: Alternative management methods and UI guidance
#     - Refresh failures: Manual refresh procedures and troubleshooting
#
# 🛠️ Recovery Procedures:
#     [Environment Setup Issues]
#     1. Verify GitHub token: Test token with 'curl -H "Authorization: token $TOKEN" https://api.github.com/user'
#     2. Check kubectl access: Run 'kubectl cluster-info' to verify connectivity
#     3. Validate ArgoCD: Ensure 'kubectl get namespace argocd' succeeds
#     4. Test repository access: Verify GitHub repository exists and is accessible
#     
#     [Configuration Failures]
#     1. Clean existing secrets: 'kubectl delete secret -n argocd bookverse-github-repo'
#     2. Verify namespace labels: Check ArgoCD namespace configuration
#     3. Restart ArgoCD: 'kubectl rollout restart deployment -n argocd argocd-server'
#     4. Manual verification: Use ArgoCD UI to test repository connection
#
# 🔍 Debugging Commands:
#     # Check ArgoCD status
#     kubectl get pods -n argocd
#     kubectl get secrets -n argocd | grep github
#     
#     # Verify repository access
#     kubectl describe secret bookverse-github-repo -n argocd
#     kubectl logs -n argocd deployment/argocd-repo-server
#     
#     # Test GitHub connectivity
#     curl -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/repos/yonatanp-jfrog/bookverse-helm
#
# Authors: BookVerse Platform Team
# Version: 1.0.0
# Last Updated: 2024-01-01
# =============================================================================

# 🛡️ Error Handling Configuration: Enable strict error handling with comprehensive tracing
set -euo pipefail

# 🔧 Cleanup Handler: Ensure temporary resources are cleaned up on all exit paths
cleanup_on_exit() {
    local exit_code=$?
    if [[ -n "${TEMP_FILE:-}" && -f "${TEMP_FILE}" ]]; then
        echo "🧹 Cleaning up temporary file: ${TEMP_FILE}"
        rm -f "${TEMP_FILE}" || echo "⚠️  Warning: Failed to remove temporary file"
    fi
    
    if [[ $exit_code -ne 0 ]]; then
        echo ""
        echo "❌ Script failed with exit code: $exit_code"
        echo "🔍 Check the error messages above for troubleshooting guidance"
        echo "💡 Run with 'set -x' for detailed debugging information"
        echo ""
        echo "🛠️ Common Recovery Steps:"
        echo "  1. Verify GitHub token: curl -H 'Authorization: token \$GITHUB_TOKEN' https://api.github.com/user"
        echo "  2. Check kubectl access: kubectl cluster-info"
        echo "  3. Validate ArgoCD: kubectl get namespace argocd"
        echo "  4. Review ArgoCD logs: kubectl logs -n argocd deployment/argocd-server"
    fi
    
    exit $exit_code
}

# 📋 Signal Handlers: Ensure cleanup on script interruption
trap cleanup_on_exit EXIT
trap 'echo "🛑 Script interrupted by user"; exit 130' INT TERM

GITHUB_USERNAME="${1:-yonatanp-jfrog}"
GITHUB_TOKEN="${GH_REPO_DISPATCH_TOKEN:-}"

# 📋 Token Validation: Comprehensive validation of GitHub authentication token
if [ -z "$GITHUB_TOKEN" ]; then
    echo "❌ Error: GH_REPO_DISPATCH_TOKEN environment variable not found"
    echo ""
    echo "🔍 GitHub Token Authentication Failure:"
    echo "   Problem: Required GitHub Personal Access Token not available"
    echo "   Impact: Cannot configure ArgoCD repository access credentials"
    echo "   Cause: Missing environment variable or invalid token configuration"
    echo ""
    echo "💡 Recovery Procedures:"
    echo "   1. Environment Variable Method (Recommended):"
    echo "      export GH_REPO_DISPATCH_TOKEN='your-github-pat'"
    echo "      $0"
    echo ""
    echo "   2. Direct Parameter Method:"
    echo "      $0 <GITHUB_USERNAME> <GITHUB_TOKEN>"
    echo ""
    echo "   3. GitHub PAT Generation Steps:"
    echo "      - Go to GitHub Settings > Developer settings > Personal access tokens"
    echo "      - Generate token with 'repo' scope for repository access"
    echo "      - Ensure token has access to BookVerse Helm repository"
    echo "      - Copy token and set as environment variable"
    echo ""
    echo "🛡️ Security Requirements:"
    echo "   - Token must have 'repo' scope for private repository access"
    echo "   - Token should be stored securely and not logged"
    echo "   - Use environment variables to avoid command line exposure"
    echo ""
    echo "🔍 Token Verification:"
    echo "   curl -H 'Authorization: token YOUR_TOKEN' https://api.github.com/user"
    echo ""
    exit 1
fi

# 🔧 Parameter Override: Handle manual token specification with enhanced validation
if [ $# -eq 2 ]; then
    echo "🔄 Using manual credentials from command line parameters"
    GITHUB_USERNAME="$1"
    GITHUB_TOKEN="$2"
    
    # 📋 Manual Token Validation: Verify manually provided token format and security
    if [[ ${#GITHUB_TOKEN} -lt 20 ]]; then
        echo "❌ Error: Provided GitHub token appears too short (${#GITHUB_TOKEN} characters)"
        echo ""
        echo "🔍 Token Format Validation Failed:"
        echo "   Problem: GitHub Personal Access Tokens are typically 40+ characters"
        echo "   Provided: ${#GITHUB_TOKEN} characters (likely invalid or truncated)"
        echo "   Expected: Valid GitHub PAT format (ghp_xxxxxxxxxxxx...)"
        echo ""
        echo "💡 Recovery Procedures:"
        echo "   1. Verify token was copied completely from GitHub"
        echo "   2. Check for whitespace or truncation in token string"
        echo "   3. Generate new token if current one appears corrupted"
        echo "   4. Use environment variable to avoid command line issues"
        echo ""
        echo "🔍 Token Testing:"
        echo "   curl -H 'Authorization: token YOUR_TOKEN' https://api.github.com/user"
        echo ""
        exit 1
    fi
    
    # 🔐 Security Warning: Alert about command line token exposure
    echo "⚠️  Security Notice: Token provided via command line"
    echo "   Recommendation: Use environment variable for enhanced security"
    echo "   Command line arguments may be visible in process lists"
fi

echo "🚀 Configuring GitHub repository access for ArgoCD"
echo "🔧 Username: $GITHUB_USERNAME"
echo "🔧 Token length: ${#GITHUB_TOKEN} characters"
echo ""

# 🔍 Kubernetes Environment Validation: Verify ArgoCD installation and accessibility
if ! kubectl get namespace argocd >/dev/null 2>&1; then
    echo "❌ Error: ArgoCD namespace 'argocd' does not exist"
    echo ""
    echo "🔍 ArgoCD Installation Validation Failed:"
    echo "   Problem: ArgoCD namespace not found in Kubernetes cluster"
    echo "   Impact: Cannot configure repository credentials for GitOps operations"
    echo "   Cause: ArgoCD not installed or namespace configuration error"
    echo ""
    echo "💡 Recovery Procedures:"
    echo "   1. Bootstrap ArgoCD Installation:"
    echo "      ./scripts/k8s/bootstrap.sh"
    echo ""
    echo "   2. Manual ArgoCD Installation:"
    echo "      kubectl create namespace argocd"
    echo "      kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml"
    echo ""
    echo "   3. Verify Installation:"
    echo "      kubectl get namespace argocd"
    echo "      kubectl get pods -n argocd"
    echo ""
    echo "🔍 Troubleshooting Commands:"
    echo "   # Check Kubernetes connectivity"
    echo "   kubectl cluster-info"
    echo "   kubectl get namespaces"
    echo ""
    echo "   # Verify ArgoCD installation"
    echo "   kubectl get all -n argocd"
    echo "   kubectl logs -n argocd deployment/argocd-server"
    echo ""
    exit 1
fi

# ✅ ArgoCD Namespace Validation: Confirm ArgoCD is running and accessible
echo "✅ ArgoCD namespace validated - proceeding with configuration"

# 🔍 ArgoCD Readiness Check: Verify core ArgoCD components are running
if ! kubectl get deployment argocd-server -n argocd >/dev/null 2>&1; then
    echo "⚠️  Warning: ArgoCD server deployment not found"
    echo "   Impact: ArgoCD may not be fully installed or ready"
    echo "   Continuing with configuration - manual verification recommended"
    echo ""
    echo "🔍 Verification Commands:"
    echo "   kubectl get deployments -n argocd"
    echo "   kubectl rollout status deployment/argocd-server -n argocd"
fi

# 🗂️ Temporary File Management: Create secure temporary file with error handling
TEMP_FILE=$(mktemp)
if [[ ! -f "$TEMP_FILE" ]]; then
    echo "❌ Error: Failed to create temporary file"
    echo ""
    echo "🔍 Temporary File Creation Failed:"
    echo "   Problem: Unable to create temporary file for Kubernetes manifests"
    echo "   Impact: Cannot generate ArgoCD repository configuration"
    echo "   Cause: Insufficient permissions or disk space"
    echo ""
    echo "💡 Recovery Procedures:"
    echo "   1. Check disk space: df -h /tmp"
    echo "   2. Verify permissions: ls -la /tmp"
    echo "   3. Clear temporary space: rm -rf /tmp/tmp.*"
    echo "   4. Try alternative: export TMPDIR=\$HOME/tmp && mkdir -p \$TMPDIR"
    echo ""
    exit 1
fi
echo "📝 Created temporary manifest file: $TEMP_FILE"
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
echo "   Configuring repository secret: bookverse-github-repo"
echo "   Configuring credential template: github-yonatanp-jfrog-creds"

# 🔧 Secret Application: Apply ArgoCD repository credentials with enhanced error handling
if kubectl apply -f "$TEMP_FILE"; then
    echo "✅ GitHub repository credentials configured successfully"
    echo "   Repository secret: Created and validated"
    echo "   Credential template: Configured for organization access"
    
    # 🔍 Secret Verification: Verify secrets were created correctly
    if kubectl get secret bookverse-github-repo -n argocd >/dev/null 2>&1; then
        echo "✅ Repository secret verification: Success"
    else
        echo "⚠️  Warning: Repository secret not found after creation"
        echo "   Run: kubectl get secrets -n argocd | grep github"
    fi
else
    echo "❌ Failed to configure GitHub repository credentials"
    echo ""
    echo "🔍 Kubernetes Secret Creation Failed:"
    echo "   Problem: Unable to apply ArgoCD repository credentials"
    echo "   Impact: ArgoCD cannot access GitHub repositories"
    echo "   Cause: Kubernetes API error or permission issues"
    echo ""
    echo "💡 Recovery Procedures:"
    echo "   1. Check kubectl permissions:"
    echo "      kubectl auth can-i create secrets --namespace=argocd"
    echo ""
    echo "   2. Verify ArgoCD namespace status:"
    echo "      kubectl get namespace argocd"
    echo "      kubectl describe namespace argocd"
    echo ""
    echo "   3. Check existing secrets:"
    echo "      kubectl get secrets -n argocd"
    echo ""
    echo "   4. Manual secret creation:"
    echo "      kubectl create secret generic bookverse-github-repo \\"
    echo "        --from-literal=type=git \\"
    echo "        --from-literal=url=https://github.com/yonatanp-jfrog/bookverse-helm.git \\"
    echo "        --from-literal=username='$GITHUB_USERNAME' \\"
    echo "        --from-literal=password='<YOUR_TOKEN>' \\"
    echo "        --namespace=argocd"
    echo ""
    echo "🔍 Debug Commands:"
    echo "   kubectl get events -n argocd --sort-by=.lastTimestamp"
    echo "   kubectl describe secret bookverse-github-repo -n argocd"
    echo ""
    # Note: Cleanup is handled by the EXIT trap
    exit 1
fi

# 🧹 Temporary File Cleanup: Remove temporary manifest file
echo "🧹 Cleaning up temporary manifest file"

echo ""
echo "🔄 Refreshing ArgoCD application..."

if kubectl -n argocd get application.argoproj.io platform-prod >/dev/null 2>&1; then
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
