#!/usr/bin/env bash
set -euo pipefail

# Quick Demo Setup - Uses existing JFROG_URL and K8s user
# This script assumes you already have JFROG_URL set and uses the dedicated K8s user

# Parse command line arguments
SETUP_MODE=false
CHECK_MODE=false

usage() {
  cat << EOF
🚀 BookVerse Quick Demo Setup

USAGE:
  ./scripts/quick-demo.sh [OPTIONS]

OPTIONS:
  --setup     One-time setup (modifies /etc/hosts, full bootstrap)
  --check     Check current /etc/hosts status (no changes made)
  --help, -h  Show this help message

MODES:
  Default (Steady Mode):
    - Assumes /etc/hosts already configured
    - Only ensures port-forward is running
    - Fast restart for interrupted sessions

  Setup Mode (--setup):
    - First-time setup or reset
    - Prompts for sudo password EARLY (before long bootstrap)
    - Modifies /etc/hosts, then full bootstrap with ingress creation

EXAMPLES:
  # First time setup (one-time only)
  ./scripts/quick-demo.sh --setup

  # Regular usage (restart after interruption)
  ./scripts/quick-demo.sh

EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --setup) SETUP_MODE=true; shift;;
    --check) CHECK_MODE=true; shift;;
    -h|--help) usage; exit 0;;
    *) echo "❌ Unknown option: $1"; usage; exit 1;;
  esac
done

if [[ "${CHECK_MODE}" == "true" ]]; then
  echo "🔍 BookVerse Demo Status Check"
  echo "=============================="
  echo ""
  
  # Check /etc/hosts status
  if grep -q "bookverse.demo" /etc/hosts 2>/dev/null; then
    BOOKVERSE_COUNT=$(grep "bookverse.demo" /etc/hosts 2>/dev/null | wc -l | tr -d ' ')
  else
    BOOKVERSE_COUNT="0"
  fi
  
  if grep -q "argocd.demo" /etc/hosts 2>/dev/null; then
    ARGOCD_COUNT=$(grep "argocd.demo" /etc/hosts 2>/dev/null | wc -l | tr -d ' ')
  else
    ARGOCD_COUNT="0"
  fi
  
  echo "📋 /etc/hosts Status:"
  if [[ "$BOOKVERSE_COUNT" -gt 0 ]]; then
    echo "   ✅ bookverse.demo (${BOOKVERSE_COUNT} entries)"
  else
    echo "   ❌ bookverse.demo (not found)"
  fi
  
  if [[ "$ARGOCD_COUNT" -gt 0 ]]; then
    echo "   ✅ argocd.demo (${ARGOCD_COUNT} entries)"
  else
    echo "   ❌ argocd.demo (not found)"
  fi
  
  # Check if port-forward is running
  if pgrep -f "kubectl.*port-forward.*traefik" >/dev/null 2>&1; then
    echo "   ✅ Traefik port-forward is running"
  else
    echo "   ❌ Traefik port-forward is not running"
  fi
  
  echo ""
  if [[ "$BOOKVERSE_COUNT" -gt 0 && "$ARGOCD_COUNT" -gt 0 ]]; then
    echo "🎯 Status: Ready for steady mode (./scripts/quick-demo.sh)"
  else
    echo "🔧 Status: Needs setup mode (./scripts/quick-demo.sh --setup)"
  fi
  
  exit 0
elif [[ "${SETUP_MODE}" == "true" ]]; then
  echo "🚀 BookVerse Quick Demo Setup (SETUP MODE)"
  echo "=========================================="
  echo ""
  echo "⚠️  Setup mode will prompt for sudo password early in the process"
  echo "   to add demo domains to /etc/hosts. Please stay nearby!"
else
  echo "🚀 BookVerse Quick Demo (STEADY MODE)"
  echo "===================================="
fi

# Check if JFROG_URL is already set
if [[ -z "${JFROG_URL:-}" ]]; then
  echo "❌ JFROG_URL not found in environment"
  echo "   Please set: export JFROG_URL='https://apptrustswampupc.jfrog.io'"
  exit 1
fi

echo "✅ Using existing JFROG_URL: ${JFROG_URL}"

# Set up the registry credentials using your existing infrastructure
export REGISTRY_SERVER="${JFROG_URL#https://}"  # Extract hostname
export REGISTRY_USERNAME='k8s.pull@bookverse.com'
export REGISTRY_PASSWORD='K8sPull2024!'  # Default K8s pull user password
export REGISTRY_EMAIL='k8s.pull@bookverse.com'

echo "🔐 Using dedicated K8s pull user: ${REGISTRY_USERNAME}"
echo "📡 Registry server: ${REGISTRY_SERVER}"

# Run appropriate setup based on mode
echo ""
if [[ "${SETUP_MODE}" == "true" ]]; then
  echo "🏗️  Starting full demo setup (one-time)..."
  ./scripts/demo-setup.sh --setup
else
  echo "🔄 Starting steady mode (port-forward only)..."
  ./scripts/demo-setup.sh --steady
fi
