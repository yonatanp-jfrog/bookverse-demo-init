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
CYAN='\033[0;36m'  # Changed from dark blue to cyan for better readability
NC='\033[0m' # No Color

# Disable colors when NO_COLOR is set or stdout is not a TTY
if [[ -n "${NO_COLOR:-}" || ! -t 1 ]]; then
    RED=''
    GREEN=''
    YELLOW=''
    CYAN=''
    NC=''
fi

# Logging functions
log_info() { echo -e "${CYAN}ℹ️  $1${NC}"; }
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
STATUS=false

usage() {
    cat <<'EOF'
Usage: ./scripts/k8s/port-forward.sh [OPTIONS]

Starts port-forwarding for BookVerse services.

Options:
  --background, -b       Run port-forwards in background (non-blocking)
                         Includes automatic monitoring with status updates
  --stop, -s            Stop all existing port-forwards and monitoring
  --status              Check current port-forward status
  --web-only            Only forward BookVerse Web (port 8080)
  --argocd-only         Only forward Argo CD (port 8081)
  --namespace NS        BookVerse namespace (default: bookverse-prod)
  --argocd-ns NS        Argo CD namespace (default: argocd)
  --help, -h            Show this help

Default behavior:
  - Forwards both Argo CD (8081) and BookVerse Web (8080)
  - Runs in foreground (blocks terminal)
  - Press Ctrl+C to stop

Background mode features:
  - Timestamped status updates every minute
  - Automatic failure detection and notifications
  - Monitor log: /tmp/bookverse-port-forward-monitor.log

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
        --status)
            STATUS=true
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
    log_info "Stopping existing port-forwards and monitoring..."
    
    # Kill monitoring processes more aggressively
    pkill -f "monitor_port_forwards" 2>/dev/null || true
    pkill -f "bookverse.*port-forward.*monitor" 2>/dev/null || true
    sleep 1
    
    # Kill kubectl port-forward processes
    if pgrep -f "kubectl.*port-forward" >/dev/null; then
        pkill -f "kubectl.*port-forward" || true
        sleep 2
        log_success "Existing port-forwards stopped"
    else
        log_info "No existing port-forwards found"
    fi
    
    # Clean up log file
    local log_file="/tmp/bookverse-port-forward-monitor.log"
    if [[ -f "$log_file" ]]; then
        rm -f "$log_file"
        log_info "Cleaned up monitor log file"
    fi
    
    log_info "All cleanup completed"
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

# Function to check if port-forward is still running
check_port_forward_status() {
    local pid="$1"
    local name="$2"
    local port="$3"
    
    if kill -0 "$pid" 2>/dev/null; then
        # Additional check: verify port is actually listening
        if command -v lsof >/dev/null && lsof -i ":$port" >/dev/null 2>&1; then
            return 0  # Running and port is active
        elif command -v netstat >/dev/null && netstat -an 2>/dev/null | grep -q ":$port.*LISTEN"; then
            return 0  # Running and port is active
        else
            return 1  # Process exists but port might not be listening
        fi
    else
        return 1  # Process not running
    fi
}

# Function to monitor port-forwards in background
monitor_port_forwards() {
    local pids=("$@")
    local services=("Argo CD" "BookVerse Web")
    local ports=("8081" "8080")
    local log_file="/tmp/bookverse-port-forward-monitor.log"
    local monitor_id="bookverse-pf-monitor-$$"
    
    # Create log file
    echo "BookVerse Port-Forward Monitor Started at $(date)" > "$log_file"
    echo "Monitor ID: $monitor_id" >> "$log_file"
    echo "PIDs: ${pids[*]}" >> "$log_file"
    echo "---" >> "$log_file"
    
    while true; do
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        local all_good=true
        local status_msg="[$timestamp] Port-forward status:"
        
        for i in "${!pids[@]}"; do
            local pid="${pids[$i]}"
            local service="${services[$i]}"
            local port="${ports[$i]}"
            
            if [[ -n "$pid" ]] && check_port_forward_status "$pid" "$service" "$port"; then
                status_msg="$status_msg ✅ $service (PID: $pid, Port: $port)"
            else
                status_msg="$status_msg ❌ $service (PID: $pid, Port: $port) - FAILED"
                all_good=false
            fi
        done
        
        # Log to file only - no terminal output to avoid conflicts
        echo "$status_msg" >> "$log_file"
        
        if [[ "$all_good" == "false" ]]; then
            echo "⚠️  Some port-forwards have failed. Check log: $log_file" >> "$log_file"
            echo "💡 Run '$0 --stop && $0 --background' to restart" >> "$log_file"
        fi
        
        sleep 60  # Check every minute
    done
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
            echo "$pid"  # Return PID for monitoring
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

# Function to show status
show_status() {
    local log_file="/tmp/bookverse-port-forward-monitor.log"
    
    log_info "Port-forward Status Check"
    
    # Check if log file exists
    if [[ ! -f "$log_file" ]]; then
        log_warning "No monitoring log found. Port-forwards may not be running."
        return 1
    fi
    
    # Show last few entries from log
    log_info "Latest status from monitor log:"
    echo
    tail -10 "$log_file" | while read -r line; do
        echo "  $line"
    done
    
    echo
    log_info "Full log available at: $log_file"
    
    # Check if processes are running
    if pgrep -f "kubectl.*port-forward" >/dev/null; then
        log_success "Port-forward processes are running"
        echo "Active processes:"
        pgrep -f "kubectl.*port-forward" | while read -r pid; do
            ps -p "$pid" -o pid,command | tail -n +2 | sed 's/^/  /'
        done
    else
        log_error "No port-forward processes found"
    fi
}

# Main execution
main() {
    if [[ "$STOP" == "true" ]]; then
        stop_port_forwards
        exit 0
    fi
    
    if [[ "$STATUS" == "true" ]]; then
        show_status
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
        if [[ "$BACKGROUND" == "true" ]]; then
            local argocd_pid=$(start_port_forward "$ARGOCD_NAMESPACE" "argocd-server" "8081" "443" "Argo CD")
            if [[ -n "$argocd_pid" ]]; then
                echo
                log_success "Argo CD port-forward started in background"
                log_info "Monitor log: /tmp/bookverse-port-forward-monitor.log"
                log_info "Use '$0 --stop' to stop port-forward"
                log_info "Access URL: https://localhost:8081"
                echo
                log_info "Starting background monitoring (silent mode - check log for updates)..."
                log_info "Use '$0 --status' to check current status"
                # Give port-forward time to establish before starting monitoring
                (sleep 5 && monitor_port_forwards "$argocd_pid") >/dev/null 2>&1 &
            fi
        else
            start_port_forward "$ARGOCD_NAMESPACE" "argocd-server" "8081" "443" "Argo CD"
        fi
    elif [[ "$WEB_ONLY" == "true" ]]; then
        if [[ "$BACKGROUND" == "true" ]]; then
            local web_pid=$(start_port_forward "$NAMESPACE" "platform-web" "8080" "80" "BookVerse Web")
            if [[ -n "$web_pid" ]]; then
                echo
                log_success "BookVerse Web port-forward started in background"
                log_info "Monitor log: /tmp/bookverse-port-forward-monitor.log"
                log_info "Use '$0 --stop' to stop port-forward"
                log_info "Access URL: http://localhost:8080"
                echo
                log_info "Starting background monitoring (silent mode - check log for updates)..."
                log_info "Use '$0 --status' to check current status"
                # Give port-forward time to establish before starting monitoring
                (sleep 5 && monitor_port_forwards "" "$web_pid") >/dev/null 2>&1 &
            fi
        else
            start_port_forward "$NAMESPACE" "platform-web" "8080" "80" "BookVerse Web"
        fi
    else
        # Start both services
        if [[ "$BACKGROUND" == "true" ]]; then
            local argocd_pid=$(start_port_forward "$ARGOCD_NAMESPACE" "argocd-server" "8081" "443" "Argo CD")
            local web_pid=$(start_port_forward "$NAMESPACE" "platform-web" "8080" "80" "BookVerse Web")
            
            if [[ -n "$argocd_pid" || -n "$web_pid" ]]; then
                echo
                log_success "Port-forwards started in background"
                log_info "Monitor log: /tmp/bookverse-port-forward-monitor.log"
                log_info "Use '$0 --stop' to stop all port-forwards"
                log_info "Access URLs:"
                log_info "  - Argo CD:        https://localhost:8081"
                log_info "  - BookVerse Web:  http://localhost:8080"
                echo
                log_info "Starting background monitoring (silent mode - check log for updates)..."
                log_info "Use '$0 --status' to check current status"
                # Give port-forwards time to establish before starting monitoring
                (sleep 5 && monitor_port_forwards "$argocd_pid" "$web_pid") >/dev/null 2>&1 &
            fi
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
