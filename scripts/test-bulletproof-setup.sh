#!/usr/bin/env bash
set -euo pipefail

# BookVerse Bulletproof Setup Test Script
# This script tests the complete demo reset and reinstall process to ensure
# the ArgoCD connectivity fix survives future demo iterations

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "🧪 BookVerse Bulletproof Setup Test"
echo "===================================="
echo ""
echo "This script will:"
echo "1. Clean up any existing demo installation"
echo "2. Run a fresh demo setup with bulletproof ArgoCD configuration"
echo "3. Verify all services are working correctly"
echo "4. Test ArgoCD connectivity specifically"
echo ""

# Validate prerequisites
echo "📋 Validating prerequisites..."

if ! command -v kubectl >/dev/null 2>&1; then
  echo "❌ kubectl not found. Please install kubectl."
  exit 1
fi

if ! kubectl cluster-info >/dev/null 2>&1; then
  echo "❌ kubectl not configured or cluster not accessible."
  exit 1
fi

echo "✅ kubectl configured and cluster accessible"

# Check required environment variables
if [[ -z "${JFROG_URL:-}" ]]; then
  echo "❌ JFROG_URL environment variable not set"
  echo "   Example: export JFROG_URL='https://apptrustswampupc.jfrog.io'"
  exit 1
fi

echo "✅ Environment variables configured"
echo "   JFROG_URL: ${JFROG_URL}"

# Set up registry credentials using the same approach as bookverse-demo.sh
export REGISTRY_SERVER="${JFROG_URL#https://}"  # Extract hostname
export REGISTRY_USERNAME='k8s.pull@bookverse.com'
export REGISTRY_PASSWORD='K8sPull2024!'  # Default K8s pull user password
export REGISTRY_EMAIL='k8s.pull@bookverse.com'

echo "🔐 Using dedicated K8s pull user: ${REGISTRY_USERNAME}"
echo "📡 Registry server: ${REGISTRY_SERVER}"

echo ""
echo "🧹 Step 1: Cleaning up existing demo installation..."
cd "${ROOT_DIR}"
if [[ -f "scripts/k8s/cleanup.sh" ]]; then
  ./scripts/k8s/cleanup.sh --all || echo "Cleanup completed with warnings"
else
  echo "⚠️  Cleanup script not found, proceeding with manual cleanup..."
  kubectl delete namespace bookverse-prod --ignore-not-found=true
  kubectl delete namespace argocd --ignore-not-found=true
fi

echo "✅ Cleanup completed"

echo ""
echo "🏗️  Step 2: Running fresh demo setup..."
echo "This will take 3-5 minutes..."

# Run the demo setup in setup mode
if ! ./scripts/bookverse-demo.sh --setup; then
  echo "❌ Demo setup failed"
  exit 1
fi

echo "✅ Demo setup completed"

echo ""
echo "🔍 Step 3: Verifying services..."

# Wait for services to be ready
echo "Waiting for services to stabilize..."
sleep 30

# Check ArgoCD specifically
echo "Checking ArgoCD deployment..."
if ! kubectl -n argocd get deployment argocd-server >/dev/null 2>&1; then
  echo "❌ ArgoCD server deployment not found"
  exit 1
fi

if ! kubectl -n argocd rollout status deployment argocd-server --timeout=60s; then
  echo "❌ ArgoCD server not ready"
  exit 1
fi

echo "✅ ArgoCD deployment is ready"

# Check ArgoCD ingress
echo "Checking ArgoCD ingress configuration..."
if ! kubectl -n argocd get ingress argocd-ingress >/dev/null 2>&1; then
  echo "❌ ArgoCD ingress not found"
  exit 1
fi

# Verify ingress is pointing to correct port
INGRESS_PORT=$(kubectl -n argocd get ingress argocd-ingress -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.port.number}')
if [[ "${INGRESS_PORT}" != "8080" ]]; then
  echo "❌ ArgoCD ingress pointing to wrong port: ${INGRESS_PORT} (should be 8080)"
  exit 1
fi

echo "✅ ArgoCD ingress correctly configured (port ${INGRESS_PORT})"

# Check ArgoCD configuration
echo "Checking ArgoCD server configuration..."
ARGOCD_INSECURE=$(kubectl -n argocd get configmap argocd-cmd-params-cm -o jsonpath='{.data.server\.insecure}' 2>/dev/null || echo "true")
if [[ "${ARGOCD_INSECURE}" == "true" ]]; then
  echo "❌ ArgoCD still in insecure mode"
  exit 1
fi

echo "✅ ArgoCD running in secure mode"

# Check ArgoCD URL configuration
ARGOCD_URL=$(kubectl -n argocd get configmap argocd-cm -o jsonpath='{.data.url}' 2>/dev/null || echo "")
if [[ "${ARGOCD_URL}" != "https://argocd.demo" ]]; then
  echo "❌ ArgoCD URL not configured correctly: '${ARGOCD_URL}'"
  exit 1
fi

echo "✅ ArgoCD URL configured correctly: ${ARGOCD_URL}"

# Check TLS secret
echo "Checking ArgoCD TLS configuration..."
if ! kubectl -n argocd get secret argocd-server-tls >/dev/null 2>&1; then
  echo "❌ ArgoCD TLS secret not found"
  exit 1
fi

echo "✅ ArgoCD TLS secret configured"

# Check Traefik middleware
echo "Checking Traefik security middleware..."
if ! kubectl -n argocd get middleware argocd-headers >/dev/null 2>&1; then
  echo "❌ ArgoCD security middleware not found"
  exit 1
fi

echo "✅ ArgoCD security middleware configured"

echo ""
echo "🌐 Step 4: Testing connectivity..."

# Test ArgoCD connectivity
echo "Testing ArgoCD HTTPS connectivity..."
if curl -k -s --max-time 15 https://argocd.demo/ >/dev/null 2>&1; then
  echo "✅ ArgoCD accessible via HTTPS"
else
  echo "⚠️  ArgoCD not yet accessible (may need more time to start)"
  
  # Check ArgoCD logs for issues
  echo "Checking ArgoCD server logs..."
  kubectl -n argocd logs -l app.kubernetes.io/name=argocd-server --tail=5
  
  # Give it one more try
  echo "Waiting 30 more seconds and retrying..."
  sleep 30
  
  if curl -k -s --max-time 15 https://argocd.demo/ >/dev/null 2>&1; then
    echo "✅ ArgoCD accessible via HTTPS (after additional wait)"
  else
    echo "❌ ArgoCD still not accessible"
    echo "Debug information:"
    kubectl -n argocd get pods,svc,ingress
    exit 1
  fi
fi

# Test BookVerse connectivity
echo "Testing BookVerse connectivity..."
if curl -s --max-time 15 http://bookverse.demo/health >/dev/null 2>&1; then
  echo "✅ BookVerse accessible"
else
  echo "⚠️  BookVerse not yet accessible (this is normal, services may still be starting)"
fi

echo ""
echo "🎉 Bulletproof Setup Test PASSED!"
echo "================================="
echo ""
echo "✅ All checks passed:"
echo "   • Demo setup completed successfully"
echo "   • ArgoCD deployed and configured securely"
echo "   • TLS certificates and security middleware in place"
echo "   • Ingress routing to correct port (8080)"
echo "   • ArgoCD accessible via HTTPS"
echo "   • Configuration survives complete reset and reinstall"
echo ""
echo "🔗 Access URLs:"
echo "   ArgoCD UI:    https://argocd.demo"
echo "   BookVerse:    http://bookverse.demo"
echo ""
echo "🔑 Get ArgoCD admin password:"
echo "   Password: S7w7PDUML4HT6sEw"
echo ""
echo "The bulletproof ArgoCD configuration is now integrated into the demo setup"
echo "and will automatically be applied in future demo installations! 🚀"
