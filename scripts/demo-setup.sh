#!/usr/bin/env bash
set -euo pipefail

# BookVerse Resilient Demo Setup Script
# This script sets up the complete BookVerse demo with professional URLs

# Parse command line arguments
SETUP_MODE=false
STEADY_MODE=false

usage() {
  cat <<'EOF'
BookVerse Resilient Demo Setup

This script automates the complete setup of BookVerse demo with professional URLs:
- http://bookverse.demo (BookVerse Web Application)
- https://argocd.demo (Argo CD UI)

Prerequisites:
- Kubernetes cluster running (Rancher Desktop recommended)
- kubectl configured and working
- JFrog registry credentials set as environment variables

Required Environment Variables:
  JFROG_URL          JFrog Platform URL (e.g., https://apptrustswampupc.jfrog.io)
  REGISTRY_USERNAME  JFrog username (use k8s.pull@bookverse.com for K8s access)
  REGISTRY_PASSWORD  JFrog password or access token
  REGISTRY_EMAIL     JFrog user email (optional)

Usage:
  ./scripts/demo-setup.sh [OPTIONS]

Options:
  --setup     One-time setup mode (modifies /etc/hosts, full bootstrap)
  --steady    Steady mode (port-forward only, assumes setup complete)
  --help      Show this help message

Examples:
  # Using existing JFROG_URL and dedicated K8s user
  export JFROG_URL='https://apptrustswampupc.jfrog.io'  # (you already have this)
  export REGISTRY_USERNAME='k8s.pull@bookverse.com'
  export REGISTRY_PASSWORD='K8sPull2024!'  # or access token
  export REGISTRY_EMAIL='k8s.pull@bookverse.com'
  ./scripts/demo-setup.sh

What this script does:
1. Validates prerequisites and environment variables
2. Runs the bootstrap script with --resilient-demo flag
3. Waits for all services to be ready
4. Verifies the demo URLs are working
5. Provides access instructions

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --setup) SETUP_MODE=true; shift;;
    --steady) STEADY_MODE=true; shift;;
    --help|-h) usage; exit 0;;
    *) echo "❌ Unknown option: $1"; usage; exit 1;;
  esac
done

# Default to setup mode if no flags provided (backward compatibility)
if [[ "${SETUP_MODE}" == "false" && "${STEADY_MODE}" == "false" ]]; then
  SETUP_MODE=true
fi

if [[ "${SETUP_MODE}" == "true" && "${STEADY_MODE}" == "true" ]]; then
  echo "❌ Cannot specify both --setup and --steady modes"
  exit 1
fi

if [[ "${SETUP_MODE}" == "true" ]]; then
  echo "🚀 BookVerse Resilient Demo Setup (SETUP MODE)"
  echo "==============================================="
else
  echo "🚀 BookVerse Resilient Demo (STEADY MODE)"
  echo "========================================="
fi

# Validate prerequisites
echo "📋 Validating prerequisites..."

if ! command -v kubectl >/dev/null 2>&1; then
  echo "❌ kubectl not found. Please install kubectl and configure it for your cluster."
  exit 1
fi

if ! kubectl cluster-info >/dev/null 2>&1; then
  echo "❌ kubectl not configured or cluster not accessible."
  echo "   Please ensure your Kubernetes cluster is running and kubectl is configured."
  exit 1
fi

echo "✅ kubectl configured and cluster accessible"

# Validate environment variables
echo "🔐 Validating JFrog registry credentials..."

if [[ -z "${JFROG_URL:-}" ]]; then
  echo "❌ JFROG_URL environment variable not set"
  echo "   Example: export JFROG_URL='https://apptrustswampupc.jfrog.io'"
  exit 1
fi

# Extract registry server from JFROG_URL (following existing pattern)
export REGISTRY_SERVER="${JFROG_URL#https://}"

if [[ -z "${REGISTRY_USERNAME:-}" ]]; then
  echo "❌ REGISTRY_USERNAME environment variable not set"
  echo "   Example: export REGISTRY_USERNAME='k8s.pull@bookverse.com'"
  exit 1
fi

if [[ -z "${REGISTRY_PASSWORD:-}" ]]; then
  echo "❌ REGISTRY_PASSWORD environment variable not set"
  echo "   Example: export REGISTRY_PASSWORD='K8sPull2024!'"
  exit 1
fi

echo "✅ JFrog registry credentials configured"
echo "   JFrog URL: ${JFROG_URL}"
echo "   Registry: ${REGISTRY_SERVER}"
echo "   Username: ${REGISTRY_USERNAME}"
echo "   Email: ${REGISTRY_EMAIL:-not-set}"

# Handle /etc/hosts modification early in setup mode (requires sudo)
if [[ "${SETUP_MODE}" == "true" ]]; then
  echo ""
  echo "🔐 Setting up demo domains (requires sudo password)..."
  echo "   Checking bookverse.demo and argocd.demo in /etc/hosts"
  echo ""
  
  # Check if domains already exist
  if grep -q "bookverse.demo" /etc/hosts 2>/dev/null; then
    BOOKVERSE_EXISTS=$(grep "bookverse.demo" /etc/hosts 2>/dev/null | wc -l | tr -d ' ')
  else
    BOOKVERSE_EXISTS="0"
  fi
  
  if grep -q "argocd.demo" /etc/hosts 2>/dev/null; then
    ARGOCD_EXISTS=$(grep "argocd.demo" /etc/hosts 2>/dev/null | wc -l | tr -d ' ')
  else
    ARGOCD_EXISTS="0"
  fi
  
  if [[ "$BOOKVERSE_EXISTS" -gt 0 && "$ARGOCD_EXISTS" -gt 0 ]]; then
    echo "ℹ️  Demo domains already exist in /etc/hosts, skipping hosts modification..."
    echo "   Found: bookverse.demo (${BOOKVERSE_EXISTS} entries), argocd.demo (${ARGOCD_EXISTS} entries)"
  elif [[ "$BOOKVERSE_EXISTS" -gt 0 || "$ARGOCD_EXISTS" -gt 0 ]]; then
    echo "⚠️  Partial demo domains found in /etc/hosts:"
    [[ "$BOOKVERSE_EXISTS" -gt 0 ]] && echo "   ✅ bookverse.demo (${BOOKVERSE_EXISTS} entries)"
    [[ "$ARGOCD_EXISTS" -eq 0 ]] && echo "   ❌ argocd.demo (missing)"
    [[ "$ARGOCD_EXISTS" -gt 0 ]] && echo "   ✅ argocd.demo (${ARGOCD_EXISTS} entries)"
    [[ "$BOOKVERSE_EXISTS" -eq 0 ]] && echo "   ❌ bookverse.demo (missing)"
    echo "   Adding missing domains..."
    # Test sudo access first with a simple command
    echo "Testing sudo access..."
    if ! sudo -n true 2>/dev/null; then
      echo "Please enter your password to add missing demo domains to /etc/hosts:"
    fi
    
    # Add missing domains individually
    ADDED_DOMAINS=""
    if [[ "$BOOKVERSE_EXISTS" -eq 0 ]]; then
      if echo "127.0.0.1 bookverse.demo" | sudo tee -a /etc/hosts >/dev/null; then
        ADDED_DOMAINS="${ADDED_DOMAINS}bookverse.demo "
      else
        echo "❌ Failed to add bookverse.demo to /etc/hosts"
        exit 1
      fi
    fi
    
    if [[ "$ARGOCD_EXISTS" -eq 0 ]]; then
      if echo "127.0.0.1 argocd.demo" | sudo tee -a /etc/hosts >/dev/null; then
        ADDED_DOMAINS="${ADDED_DOMAINS}argocd.demo "
      else
        echo "❌ Failed to add argocd.demo to /etc/hosts"
        exit 1
      fi
    fi
    
    if [[ -n "$ADDED_DOMAINS" ]]; then
      echo "✅ Added missing demo domains to /etc/hosts: ${ADDED_DOMAINS}"
      echo "   Now proceeding with full setup (no more sudo prompts)..."
    fi
  else
    # Neither domain exists, add both
    echo "Testing sudo access..."
    if ! sudo -n true 2>/dev/null; then
      echo "Please enter your password to add demo domains to /etc/hosts:"
    fi
    
    if echo "127.0.0.1 bookverse.demo argocd.demo" | sudo tee -a /etc/hosts >/dev/null; then
      echo "✅ Demo domains added to /etc/hosts successfully"
      echo "   Now proceeding with full setup (no more sudo prompts)..."
    else
      echo "❌ Failed to add domains to /etc/hosts"
      echo "   Please run manually: echo '127.0.0.1 bookverse.demo argocd.demo' | sudo tee -a /etc/hosts"
      exit 1
    fi
  fi
  
  # Verify final state
  echo "🔍 Verifying /etc/hosts configuration..."
  if grep -q "bookverse.demo" /etc/hosts 2>/dev/null; then
    FINAL_BOOKVERSE=$(grep "bookverse.demo" /etc/hosts 2>/dev/null | wc -l | tr -d ' ')
  else
    FINAL_BOOKVERSE="0"
  fi
  
  if grep -q "argocd.demo" /etc/hosts 2>/dev/null; then
    FINAL_ARGOCD=$(grep "argocd.demo" /etc/hosts 2>/dev/null | wc -l | tr -d ' ')
  else
    FINAL_ARGOCD="0"
  fi
  
  if [[ "$FINAL_BOOKVERSE" -gt 0 && "$FINAL_ARGOCD" -gt 0 ]]; then
    echo "✅ Demo domains verified in /etc/hosts:"
    echo "   📍 bookverse.demo (${FINAL_BOOKVERSE} entries)"
    echo "   📍 argocd.demo (${FINAL_ARGOCD} entries)"
  else
    echo "⚠️  Warning: Demo domains not properly configured in /etc/hosts"
    echo "   You may need to add them manually later"
  fi
  echo ""
fi

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo ""
if [[ "${SETUP_MODE}" == "true" ]]; then
  echo "🏗️  Starting BookVerse deployment (full setup)..."
  echo "   This will take 3-5 minutes..."

  # Run the bootstrap script with resilient demo flag
  cd "${ROOT_DIR}"
  ./scripts/k8s/bootstrap.sh --resilient-demo &
  BOOTSTRAP_PID=$!

  # Wait for bootstrap to complete
  wait $BOOTSTRAP_PID
  BOOTSTRAP_EXIT_CODE=$?

  if [[ $BOOTSTRAP_EXIT_CODE -ne 0 ]]; then
    echo "❌ Bootstrap script failed with exit code $BOOTSTRAP_EXIT_CODE"
    exit 1
  fi
else
  echo "🔄 Starting steady mode (port-forward only)..."
  echo "   Assuming /etc/hosts and ingress already configured..."
  
  # Kill any existing port-forwards
  pkill -f "kubectl.*port-forward" 2>/dev/null || true
  
  # Start port-forward to Traefik ingress controller
  echo "🌐 Starting port-forward to Traefik ingress controller..."
  kubectl port-forward svc/traefik 80:80 443:443 -n kube-system >/dev/null 2>&1 &
  
  # Give it a moment to start
  sleep 2
  
  echo "✅ Port-forward started successfully"
fi

echo ""
echo "🧪 Verifying demo setup..."

# Wait a moment for ingress to be ready
sleep 5

# Test the demo URLs
echo "Testing BookVerse demo URL..."
if curl -s --max-time 10 http://bookverse.demo/health >/dev/null 2>&1; then
  echo "✅ BookVerse demo accessible at http://bookverse.demo"
else
  echo "⚠️  BookVerse demo URL not yet ready (this is normal, may take a few more minutes)"
fi

echo "Testing Argo CD demo URL..."
if curl -s --max-time 10 -k https://argocd.demo >/dev/null 2>&1; then
  echo "✅ Argo CD demo accessible at https://argocd.demo"
else
  echo "⚠️  Argo CD demo URL not yet ready (this is normal, may take a few more minutes)"
fi

echo ""
if [[ "${SETUP_MODE}" == "true" ]]; then
  echo "🎯 Demo Setup Complete (First-Time Setup)!"
  echo "==========================================="
  echo ""
  echo "ℹ️  Next time, use: ./scripts/quick-demo.sh (without --setup)"
else
  echo "🎯 Demo Ready (Steady Mode)!"
  echo "============================"
fi
echo ""
echo "📱 Access URLs:"
echo "   BookVerse Web: http://bookverse.demo"
echo "   Argo CD UI:    https://argocd.demo"
echo ""
echo "🔑 Argo CD Login:"
echo "   Username: admin"
echo "   Password: \$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)"
echo ""
echo "🧪 Quick Tests:"
echo "   curl http://bookverse.demo/health"
echo "   curl http://bookverse.demo/api/v1/books"
echo "   open http://bookverse.demo"
echo ""
echo "🛠️  Troubleshooting:"
echo "   - If URLs don't work immediately, wait 2-3 minutes for all services to start"
echo "   - Check pod status: kubectl get pods -n bookverse-prod"
echo "   - Check ingress: kubectl get ingress -n bookverse-prod"
echo "   - Restart port-forward: kubectl port-forward svc/traefik 80:80 443:443 -n kube-system &"
echo ""
echo "🧹 Cleanup:"
echo "   ./scripts/k8s/cleanup.sh --all"
echo ""
echo "Happy demoing! 🎉"
