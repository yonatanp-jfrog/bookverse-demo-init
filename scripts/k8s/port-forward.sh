#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# KUBERNETES PORT-FORWARDING SCRIPT
# =============================================================================
# Dedicated script to start/stop port-forwarding for BookVerse services
# Can be run independently of bootstrap for convenience
# =============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Disable colors when NO_COLOR is set or stdout is not a TTY
if [[ -n "${NO_COLOR:-}" || ! -t 1 ]]; then
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

# Logging functions
log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# Default values
NAMESPACE="${NAMESPACE:-bookverse-prod}"
ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
BACKGROUND=false
STOP=false
WEB_ONLY=false
ARGOCD_ONLY=false

usage() {
    cat <<'EOF'
Usage: ./scripts/k8s/port-forward.sh [OPTIONS]

Starts port-forwarding for BookVerse services.

Options:
  --background, -b       Run port-forwards in background (non-blocking)
  --stop, -s            Stop all existing port-forwards
  --web-only            Only forward BookVerse Web (port 8080)
  --argocd-only         Only forward Argo CD (port 8081)
  --namespace NS        BookVerse namespace (default: bookverse-prod)
  --argocd-ns NS        Argo CD namespace (default: argocd)
  --help, -h            Show this help

Default behavior:
  - Forwards both Argo CD (8081) and BookVerse Web (8080)
  - Runs in foreground (blocks terminal)
  - Press Ctrl+C to stop

Examples:
  # Standard foreground mode
  ./scripts/k8s/port-forward.sh

  # Background mode (keeps terminal available)
  ./scripts/k8s/port-forward.sh --background

  # Only web app
  ./scripts/k8s/port-forward.sh --web-only

  # Stop all port-forwards
  ./scripts/k8s/port-forward.sh --stop

Access URLs:
  - Argo CD:        https://localhost:8081
  - BookVerse Web:  http://localhost:8080

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -b|--background)
            BACKGROUND=true
            shift
            ;;
        -s|--stop)
            STOP=true
            shift
            ;;
        --web-only)
            WEB_ONLY=true
            shift
            ;;
        --argocd-only)
            ARGOCD_ONLY=true
            shift
            ;;
        --namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        --argocd-ns)
            ARGOCD_NAMESPACE="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Function to stop existing port-forwards
stop_port_forwards() {
    log_info "Stopping existing port-forwards..."
    
    # Kill kubectl port-forward processes
    if pgrep -f "kubectl.*port-forward" >/dev/null; then
        pkill -f "kubectl.*port-forward" || true
        sleep 2
        log_success "Existing port-forwards stopped"
    else
        log_info "No existing port-forwards found"
    fi
}

# Function to check if a service exists
check_service() {
    local namespace="$1"
    local service="$2"
    
    if kubectl -n "$namespace" get svc "$service" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Function to start port-forward
start_port_forward() {
    local namespace="$1"
    local service="$2"
    local local_port="$3"
    local remote_port="$4"
    local name="$5"
    
    log_info "Starting port-forward for $name ($service)..."
    
    if ! check_service "$namespace" "$service"; then
        log_error "Service '$service' not found in namespace '$namespace'"
        return 1
    fi
    
    if [[ "$BACKGROUND" == "true" ]]; then
        kubectl -n "$namespace" port-forward "svc/$service" "$local_port:$remote_port" >/dev/null 2>&1 &
        local pid=$!
        sleep 1
        if kill -0 $pid 2>/dev/null; then
            log_success "$name port-forward started in background (PID: $pid)"
            log_info "  Access: http://localhost:$local_port"
        else
            log_error "Failed to start $name port-forward"
            return 1
        fi
    else
        log_success "$name port-forward starting..."
        log_info "  Access: http://localhost:$local_port"
        kubectl -n "$namespace" port-forward "svc/$service" "$local_port:$remote_port"
    fi
}

# Main execution
main() {
    if [[ "$STOP" == "true" ]]; then
        stop_port_forwards
        exit 0
    fi
    
    log_info "BookVerse Port-Forward Setup"
    log_info "Namespace: $NAMESPACE"
    log_info "Argo CD Namespace: $ARGOCD_NAMESPACE"
    log_info "Mode: $([ "$BACKGROUND" == "true" ] && echo "Background" || echo "Foreground")"
    echo
    
    # Stop existing port-forwards first
    stop_port_forwards
    
    # Start port-forwards based on options
    if [[ "$ARGOCD_ONLY" == "true" ]]; then
        start_port_forward "$ARGOCD_NAMESPACE" "argocd-server" "8081" "443" "Argo CD"
    elif [[ "$WEB_ONLY" == "true" ]]; then
        start_port_forward "$NAMESPACE" "platform-web" "8080" "80" "BookVerse Web"
    else
        # Start both services
        if [[ "$BACKGROUND" == "true" ]]; then
            start_port_forward "$ARGOCD_NAMESPACE" "argocd-server" "8081" "443" "Argo CD"
            start_port_forward "$NAMESPACE" "platform-web" "8080" "80" "BookVerse Web"
            echo
            log_success "All port-forwards started in background"
            log_info "Use 'jobs' to see running processes"
            log_info "Use '$0 --stop' to stop all port-forwards"
            log_info "Access URLs:"
            log_info "  - Argo CD:        https://localhost:8081"
            log_info "  - BookVerse Web:  http://localhost:8080"
        else
            log_info "Starting port-forwards (will block terminal)..."
            log_info "Press Ctrl+C to stop all port-forwards"
            echo
            
            # Start Argo CD in background
            kubectl -n "$ARGOCD_NAMESPACE" port-forward svc/argocd-server 8081:443 >/dev/null 2>&1 &
            local argocd_pid=$!
            
            # Start Web in foreground (this will block)
            trap "log_info 'Stopping port-forwards...'; kill $argocd_pid 2>/dev/null || true; exit 0" INT TERM
            
            log_success "Argo CD:        https://localhost:8081"
            log_success "BookVerse Web:  http://localhost:8080"
            echo
            
            start_port_forward "$NAMESPACE" "platform-web" "8080" "80" "BookVerse Web"
        fi
    fi
}

# Run main function
main "$@"
