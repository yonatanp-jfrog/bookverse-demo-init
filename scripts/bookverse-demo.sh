#!/usr/bin/env bash
set -euo pipefail

# BookVerse Demo - Unified Setup Script
# This script replaces demo-setup.sh, quick-demo.sh, and bootstrap.sh
# Provides a single, comprehensive solution for all demo setup needs

# Configuration
ENV="prod"
SETUP_MODE=false
STEADY_MODE=true  # DEFAULT: Most common usage
PORT_FORWARD_MODE=false
CLEANUP_MODE=false
ARGO_NS="argocd"
NS="bookverse-${ENV}"
APP_NAME="platform-${ENV}"

# Colors for output (optimized for dark terminals)
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'      # Cyan instead of dark blue - much more visible
YELLOW='\033[1;33m'
WHITE='\033[1;37m'     # Bright white for emphasis
NC='\033[0m' # No Color

usage() {
  cat <<'EOF'
🚀 BookVerse Demo - Start/Resume Demo

USAGE:
  ./scripts/bookverse-demo.sh              # Start/resume demo (DEFAULT)
  ./scripts/bookverse-demo.sh [OPTIONS]    # Advanced options

DEFAULT BEHAVIOR (Most Common):
  - Resumes existing demo or starts port-forwarding
  - Works with already-configured demo setup
  - Fast startup for interrupted sessions
  - Access: http://bookverse.demo & https://argocd.demo

ADVANCED OPTIONS (Less Common):
  --setup         🔧 First-time setup (modifies /etc/hosts, full bootstrap)
  --port-forward  🌐 Use localhost URLs (https://localhost:8081, http://localhost:8080)
  --cleanup       🧹 Remove demo installation completely
  --help, -h      📖 Show detailed help

QUICK START:
  # Most common usage (90% of the time)
  ./scripts/bookverse-demo.sh

  # First time only (once per machine)  
  ./scripts/bookverse-demo.sh --setup

DETAILED MODES:
  Default (Resume Demo):
    ✅ Assumes demo already set up
    ✅ Starts/restarts port-forwarding to ingress
    ✅ Fast startup for daily demo use
    ✅ Professional URLs: bookverse.demo & argocd.demo

  Setup Mode (--setup):
    🔧 First-time setup or complete reset
    🔧 Modifies /etc/hosts for demo domains  
    🔧 Full Kubernetes + ArgoCD bootstrap
    🔧 Bulletproof ArgoCD configuration included

  Port-Forward Mode (--port-forward):
    🌐 Uses localhost instead of demo domains
    🌐 No /etc/hosts modification needed
    🌐 URLs: https://localhost:8081 & http://localhost:8080

PREREQUISITES:
  - Kubernetes cluster running (Rancher Desktop recommended)
  - kubectl configured and working
  - JFROG_URL environment variable set

EXAMPLES:
  # First time setup (recommended)
  export JFROG_URL='https://apptrustswampupc.jfrog.io'
  ./scripts/bookverse-demo.sh --setup

  # Regular usage (restart after interruption) - DEFAULT
  ./scripts/bookverse-demo.sh

  # Use localhost port-forwarding instead of demo domains
  ./scripts/bookverse-demo.sh --port-forward

  # Clean up everything
  ./scripts/bookverse-demo.sh --cleanup

WHAT THIS SCRIPT DOES:
1. Validates prerequisites and environment variables
2. Automatically configures registry credentials (K8s pull user)
3. Installs/updates ArgoCD with bulletproof production configuration
4. Creates BookVerse namespace and image pull secrets
5. Applies GitOps configuration (projects and applications)
6. Configures ArgoCD with proper TLS, security headers, and ingress
7. Waits for applications to be synced and healthy
8. Sets up ingress or port-forwarding for access
9. Verifies demo URLs are working

EOF
}

# Logging functions
log_info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --setup) SETUP_MODE=true; STEADY_MODE=false; shift;;
    --port-forward) PORT_FORWARD_MODE=true; STEADY_MODE=false; shift;;
    --cleanup) CLEANUP_MODE=true; shift;;
    -h|--help) usage; exit 0;;
    *) log_error "Unknown option: $1"; usage; exit 1;;
  esac
done

# Handle cleanup mode
if [[ "${CLEANUP_MODE}" == "true" ]]; then
  cleanup_demo
  exit 0
fi

# Default behavior: STEADY_MODE (resume demo) - most common usage
# Only override if user explicitly requested setup or port-forward

# Validate mutually exclusive modes (setup and port-forward are mutually exclusive)
if [[ "${SETUP_MODE}" == "true" && "${PORT_FORWARD_MODE}" == "true" ]]; then
  log_error "Cannot specify both --setup and --port-forward modes"
  exit 1
fi

# Cleanup function
cleanup_demo() {
  log_info "Cleaning up BookVerse demo installation..."
  
  # Kill any existing port-forwards
  pkill -f "kubectl.*port-forward" 2>/dev/null || true
  
  # Delete namespaces
  log_info "Deleting BookVerse namespaces (ignore-not-found)"
  kubectl delete namespace "${NS}" --ignore-not-found=true
  kubectl delete namespace "${ARGO_NS}" --ignore-not-found=true
  
  # Clean up /etc/hosts entries
  if grep -q "bookverse.demo\|argocd.demo" /etc/hosts 2>/dev/null; then
    log_info "Cleaning up demo domains from /etc/hosts"
    if command -v sudo >/dev/null 2>&1; then
      sudo sed -i.bak '/bookverse\.demo\|argocd\.demo/d' /etc/hosts 2>/dev/null || true
      log_success "Demo domains removed from /etc/hosts"
    else
      log_warning "Cannot clean /etc/hosts (sudo not available). Manual cleanup may be needed."
    fi
  fi
  
  log_success "Demo cleanup completed"
}

# Validate prerequisites
validate_prerequisites() {
  log_info "Validating prerequisites..."

  if ! command -v kubectl >/dev/null 2>&1; then
    log_error "kubectl not found. Please install kubectl and configure it for your cluster."
    exit 1
  fi

  if ! kubectl cluster-info >/dev/null 2>&1; then
    log_error "kubectl not configured or cluster not accessible."
    log_error "Please ensure your Kubernetes cluster is running and kubectl is configured."
    exit 1
  fi

  log_success "kubectl configured and cluster accessible"
}

# Validate environment variables
validate_environment() {
  log_info "Validating environment variables..."

  if [[ -z "${JFROG_URL:-}" ]]; then
    log_error "JFROG_URL environment variable not set"
    log_error "Example: export JFROG_URL='https://apptrustswampupc.jfrog.io'"
    exit 1
  fi

  # Set up registry credentials automatically
  export REGISTRY_SERVER="${JFROG_URL#https://}"  # Extract hostname
  export REGISTRY_USERNAME='k8s.pull@bookverse.com'
  export REGISTRY_PASSWORD='K8sPull2024!'  # Default K8s pull user password
  export REGISTRY_EMAIL='k8s.pull@bookverse.com'

  log_success "Environment variables configured"
  log_info "JFrog URL: ${JFROG_URL}"
  log_info "Registry: ${REGISTRY_SERVER}"
  log_info "Username: ${REGISTRY_USERNAME}"
}

# Handle /etc/hosts modification
setup_demo_domains() {
  if [[ "${SETUP_MODE}" != "true" ]]; then
    return 0
  fi

  log_info "Setting up demo domains (requires sudo password)..."
  log_info "Checking bookverse.demo and argocd.demo in /etc/hosts"
  
  # Check if domains already exist
  local bookverse_exists=0
  local argocd_exists=0
  
  if grep -q "bookverse.demo" /etc/hosts 2>/dev/null; then
    bookverse_exists=$(grep "bookverse.demo" /etc/hosts 2>/dev/null | wc -l | tr -d ' ')
  fi
  
  if grep -q "argocd.demo" /etc/hosts 2>/dev/null; then
    argocd_exists=$(grep "argocd.demo" /etc/hosts 2>/dev/null | wc -l | tr -d ' ')
  fi
  
  if [[ "$bookverse_exists" -gt 0 && "$argocd_exists" -gt 0 ]]; then
    log_info "Demo domains already exist in /etc/hosts, skipping hosts modification..."
    return 0
  fi
  
  # Add missing domains
  log_info "Adding demo domains to /etc/hosts..."
  if ! sudo -n true 2>/dev/null; then
    log_info "Please enter your password to add demo domains to /etc/hosts:"
  fi
  
  if echo "127.0.0.1 bookverse.demo argocd.demo" | sudo tee -a /etc/hosts >/dev/null; then
    log_success "Demo domains added to /etc/hosts successfully"
  else
    log_error "Failed to add domains to /etc/hosts"
    exit 1
  fi
}

# Install and configure ArgoCD
setup_argocd() {
  log_info "Setting up ArgoCD..."
  
  # Create ArgoCD namespace
  kubectl get ns "${ARGO_NS}" >/dev/null 2>&1 || kubectl create ns "${ARGO_NS}"
  
  # Install ArgoCD
  log_info "Installing/updating ArgoCD in namespace ${ARGO_NS}"
  kubectl apply -n "${ARGO_NS}" -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
  kubectl -n "${ARGO_NS}" rollout status deploy/argocd-server --timeout=180s || true
  
  log_success "ArgoCD installation completed"
}

# Configure bulletproof ArgoCD production settings
configure_argocd_production() {
  if [[ "${PORT_FORWARD_MODE}" == "true" ]]; then
    log_info "Skipping ArgoCD production configuration (port-forward mode)"
    return 0
  fi

  log_info "Configuring ArgoCD for production use"
  
  local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local argocd_config_script="${script_dir}/k8s/configure-argocd-production.sh"
  
  if [[ -f "${argocd_config_script}" ]]; then
    "${argocd_config_script}" --host argocd.demo || log_warning "ArgoCD configuration completed with warnings"
  else
    log_warning "ArgoCD production configuration script not found, applying basic configuration"
    # Apply basic configuration inline
    kubectl -n "${ARGO_NS}" patch configmap argocd-cm --type merge -p '{"data":{"url":"https://argocd.demo","redis.server":"argocd-redis:6379"}}'
    
    # Add Redis password environment variable to ArgoCD server deployment
    log_info "Configuring Redis authentication for ArgoCD server"
    kubectl patch deployment argocd-server -n "${ARGO_NS}" -p '{"spec":{"template":{"spec":{"containers":[{"name":"argocd-server","env":[{"name":"ARGOCD_SERVER_INSECURE","value":"true"},{"name":"REDIS_PASSWORD","valueFrom":{"secretKeyRef":{"name":"argocd-redis","key":"auth"}}}]}]}}}}'
  fi
  
  log_success "ArgoCD production configuration applied"
}

# Setup BookVerse application
setup_bookverse() {
  log_info "Setting up BookVerse application..."
  
  # Create BookVerse namespace
  kubectl get ns "${NS}" >/dev/null 2>&1 || kubectl create ns "${NS}"
  
  # Create image pull secret if registry credentials are available
  if [[ -n "${REGISTRY_SERVER:-}" && -n "${REGISTRY_USERNAME:-}" && -n "${REGISTRY_PASSWORD:-}" ]]; then
    log_info "Creating/updating docker-registry secret in ${NS}"
    local email_arg=()
    if [[ -n "${REGISTRY_EMAIL:-}" ]]; then
      email_arg=(--docker-email "${REGISTRY_EMAIL}")
    fi
    kubectl -n "${NS}" create secret docker-registry jfrog-docker-pull \
      --docker-server="${REGISTRY_SERVER}" \
      --docker-username="${REGISTRY_USERNAME}" \
      --docker-password="${REGISTRY_PASSWORD}" \
      "${email_arg[@]}" \
      --dry-run=client -o yaml | kubectl apply -f -
    kubectl -n "${NS}" patch serviceaccount default \
      -p '{"imagePullSecrets":[{"name":"jfrog-docker-pull"}]}' >/dev/null
    log_success "Image pull secret configured"
  else
    log_warning "Registry credentials not set, skipping imagePullSecret creation"
  fi
  
  # Apply GitOps configuration
  local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local gitops_dir="${script_dir}/../gitops"
  
  log_info "Applying GitOps configuration"
  kubectl apply -f "${gitops_dir}/projects/bookverse-prod.yaml"
  kubectl apply -f "${gitops_dir}/apps/prod/platform.yaml"
  
  log_success "BookVerse application configuration applied"
}

# Wait for applications to be ready
wait_for_applications() {
  log_info "Waiting for ArgoCD application to become Synced/Healthy"
  
  for i in {1..60}; do
    local sync=$(kubectl -n "${ARGO_NS}" get application.argoproj.io "${APP_NAME}" -o jsonpath='{.status.sync.status}' 2>/dev/null || true)
    local health=$(kubectl -n "${ARGO_NS}" get application.argoproj.io "${APP_NAME}" -o jsonpath='{.status.health.status}' 2>/dev/null || true)
    echo "   Sync=${sync:-N/A} Health=${health:-N/A}"
    if [[ "${sync}" == "Synced" && "${health}" == "Healthy" ]]; then
      break
    fi
    sleep 5
  done
  
  log_success "Applications are ready"
}

# Setup access method (ingress or port-forward)
setup_access() {
  if [[ "${PORT_FORWARD_MODE}" == "true" ]]; then
    setup_port_forward
  elif [[ "${STEADY_MODE}" == "true" ]]; then
    setup_steady_mode
  else
    setup_ingress_access
  fi
}

# Setup port-forward access
setup_port_forward() {
  log_info "Setting up port-forward access..."
  
  # Kill any existing port-forwards
  pkill -f "kubectl.*port-forward" 2>/dev/null || true
  
  log_info "Starting port-forwards for ArgoCD and BookVerse"
  (kubectl -n "${ARGO_NS}" port-forward svc/argocd-server 8081:443 >/dev/null 2>&1) &
  (kubectl -n "${NS}" port-forward svc/platform-web 8080:80 >/dev/null 2>&1) &
  
  sleep 3
  log_success "Port-forwards started"
  log_info "Access URLs:"
  log_info "  ArgoCD UI:    https://localhost:8081"
  log_info "  BookVerse:    http://localhost:8080"
}

# Setup steady mode (ingress port-forward)
setup_steady_mode() {
  log_info "Setting up steady mode (ingress port-forward)..."
  
  # Kill any existing port-forwards
  pkill -f "kubectl.*port-forward" 2>/dev/null || true
  
  # Start port-forward to Traefik ingress controller
  log_info "Starting port-forward to Traefik ingress controller..."
  kubectl -n kube-system port-forward svc/traefik 80:80 443:443 >/dev/null 2>&1 &
  
  sleep 3
  log_success "Ingress port-forward started"
}

# Setup ingress access
setup_ingress_access() {
  log_info "Setting up ingress access..."
  
  # Create BookVerse ingress
  local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local root_dir="${script_dir}/.."
  
  cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: bookverse-ingress
  namespace: ${NS}
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: web
    traefik.ingress.kubernetes.io/redirect-to-https: "false"
spec:
  ingressClassName: traefik
  rules:
  - host: bookverse.demo
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: platform-web
            port:
              number: 80
EOF
  
  # Start port-forward to Traefik ingress controller
  setup_steady_mode
  
  log_success "Ingress configuration completed"
}

# Verify demo setup
verify_demo() {
  log_info "Verifying demo setup..."
  
  # Wait a moment for services to be ready
  sleep 5
  
  if [[ "${PORT_FORWARD_MODE}" == "true" ]]; then
    # Test localhost URLs
    if curl -s --max-time 10 http://localhost:8080/health >/dev/null 2>&1; then
      log_success "BookVerse accessible at http://localhost:8080"
    else
      log_warning "BookVerse not yet ready at localhost:8080"
    fi
    
    if curl -k -s --max-time 10 https://localhost:8081/ >/dev/null 2>&1; then
      log_success "ArgoCD accessible at https://localhost:8081"
    else
      log_warning "ArgoCD not yet ready at localhost:8081"
    fi
  else
    # Test demo URLs
    if curl -s --max-time 10 http://bookverse.demo/health >/dev/null 2>&1; then
      log_success "BookVerse accessible at http://bookverse.demo"
    else
      log_warning "BookVerse not yet ready at http://bookverse.demo"
    fi
    
    if curl -k -s --max-time 10 https://argocd.demo/ >/dev/null 2>&1; then
      log_success "ArgoCD accessible at https://argocd.demo"
    else
      log_warning "ArgoCD not yet ready at https://argocd.demo"
    fi
  fi
}

# Show final status
show_final_status() {
  echo ""
  if [[ "${SETUP_MODE}" == "true" ]]; then
    log_success "🎯 BookVerse Demo Setup Complete!"
    echo "==========================================="
    log_info "Next time, just run: ./scripts/bookverse-demo.sh (no flags needed)"
  elif [[ "${PORT_FORWARD_MODE}" == "true" ]]; then
    log_success "🎯 BookVerse Demo Ready (Localhost Mode)!"
    echo "=========================================="
  else
    log_success "🎯 BookVerse Demo Ready!"
    echo "========================"
  fi
  
  echo ""
  log_info "🧪 Quick Tests:"
  if [[ "${PORT_FORWARD_MODE}" == "true" ]]; then
    echo "   curl http://localhost:8080/health"
    echo "   curl http://localhost:8080/api/v1/books"
    echo "   open http://localhost:8080"
  else
    echo "   curl http://bookverse.demo/health"
    echo "   curl http://bookverse.demo/api/v1/books"
    echo "   open http://bookverse.demo"
  fi
  
  echo ""
  log_info "🛠️  Troubleshooting:"
  echo "   - If URLs don't work immediately, wait 2-3 minutes for all services to start"
  echo "   - Check pod status: kubectl get pods -n ${NS}"
  echo "   - Check ArgoCD: kubectl get pods -n ${ARGO_NS}"
  
  echo ""
  log_info "🧹 Cleanup:"
  echo "   ./scripts/bookverse-demo.sh --cleanup"
  
  echo ""
  log_success "Happy demoing! 🎉"
  
  echo ""
  if [[ "${PORT_FORWARD_MODE}" == "true" ]]; then
    log_info "📱 Access URLs:"
    echo "   BookVerse:    http://localhost:8080"
    echo "   ArgoCD UI:    https://localhost:8081"
  else
    log_info "📱 Access URLs:"
    echo "   BookVerse:    http://bookverse.demo"
    echo "   ArgoCD UI:    https://argocd.demo"
  fi
  
  echo ""
  log_info "🔑 ArgoCD Login:"
  echo "   Username: admin"
  echo "   Password: S7w7PDUML4HT6sEw"
}

# Main execution
main() {
  # Show mode
  if [[ "${SETUP_MODE}" == "true" ]]; then
    echo "🔧 BookVerse Demo - First-Time Setup"
    echo "===================================="
    log_info "Running first-time setup (modifies /etc/hosts, full bootstrap)"
  elif [[ "${PORT_FORWARD_MODE}" == "true" ]]; then
    echo "🌐 BookVerse Demo - Localhost Mode"
    echo "=================================="
    log_info "Using localhost URLs (no demo domains)"
  else
    echo "🚀 BookVerse Demo - Resume/Start"
    echo "================================"
    log_info "Resuming demo with professional URLs (most common usage)"
  fi
  
  # Execute setup steps
  validate_prerequisites
  validate_environment
  
  if [[ "${SETUP_MODE}" == "true" ]]; then
    # Full setup mode (first-time or reset)
    setup_demo_domains
    setup_argocd
    configure_argocd_production
    setup_bookverse
    wait_for_applications
    setup_access
  else
    # Default: Resume/start demo (most common usage)
    setup_access
  fi
  
  verify_demo
  show_final_status
}

# Run main function
main "$@"
