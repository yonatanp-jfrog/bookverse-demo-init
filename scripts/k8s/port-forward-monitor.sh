#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# KUBERNETES PORT-FORWARD MONITOR SCRIPT
# =============================================================================
# Dedicated script to monitor running port-forwards
# Works independently of the main port-forward script
# =============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
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
MONITOR_INTERVAL=60
LOG_FILE="/tmp/bookverse-port-forward-monitor.log"
BACKGROUND=false
STATUS=false

usage() {
    cat <<'EOF'
Usage: ./scripts/k8s/port-forward-monitor.sh [OPTIONS]

Monitors running Kubernetes port-forwards for BookVerse services.

Options:
  --background, -b       Run monitor in background (non-blocking)
  --status, -s          Show current status from log
  --interval N          Check interval in seconds (default: 60)
  --log-file FILE       Log file path (default: /tmp/bookverse-port-forward-monitor.log)
  --help, -h            Show this help

Examples:
  # Monitor in foreground (shows updates on screen)
  ./scripts/k8s/port-forward-monitor.sh

  # Monitor in background
  ./scripts/k8s/port-forward-monitor.sh --background

  # Check status
  ./scripts/k8s/port-forward-monitor.sh --status

  # Custom interval (every 30 seconds)
  ./scripts/k8s/port-forward-monitor.sh --interval 30

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -b|--background)
            BACKGROUND=true
            shift
            ;;
        -s|--status)
            STATUS=true
            shift
            ;;
        --interval)
            MONITOR_INTERVAL="$2"
            shift 2
            ;;
        --log-file)
            LOG_FILE="$2"
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

# Function to check if port-forward is still running
check_port_forward_status() {
    local pid="$1"
    local service="$2"
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

# Function to detect running port-forwards
detect_port_forwards() {
    local pids=()
    local services=()
    local ports=()
    
    # Find kubectl port-forward processes
    while read -r line; do
        if [[ -n "$line" ]]; then
            local pid=$(echo "$line" | awk '{print $1}')
            local cmd=$(echo "$line" | cut -d' ' -f2-)
            
            # Parse service and port from command
            if echo "$cmd" | grep -q "argocd-server.*8081:443"; then
                pids+=("$pid")
                services+=("Argo CD")
                ports+=("8081")
            elif echo "$cmd" | grep -q "platform-web.*8080:80"; then
                pids+=("$pid")
                services+=("BookVerse Web")
                ports+=("8080")
            fi
        fi
    done < <(pgrep -f "kubectl.*port-forward" | xargs -I {} ps -p {} -o pid,command | tail -n +2 2>/dev/null || true)
    
    # Return arrays via global variables
    DETECTED_PIDS=("${pids[@]}")
    DETECTED_SERVICES=("${services[@]}")
    DETECTED_PORTS=("${ports[@]}")
}

# Function to show current status
show_status() {
    log_info "Port-forward Status Check"
    
    # Check if log file exists and show recent entries
    if [[ -f "$LOG_FILE" ]]; then
        log_info "Latest status from monitor log:"
        echo
        tail -5 "$LOG_FILE" | while read -r line; do
            echo "  $line"
        done
        echo
        log_info "Full log available at: $LOG_FILE"
    else
        log_warning "No monitoring log found at: $LOG_FILE"
    fi
    
    # Check current running processes
    detect_port_forwards
    
    if [[ ${#DETECTED_PIDS[@]} -gt 0 ]]; then
        log_success "Found ${#DETECTED_PIDS[@]} active port-forward(s)"
        echo "Active processes:"
        for i in "${!DETECTED_PIDS[@]}"; do
            echo "  PID: ${DETECTED_PIDS[$i]} - ${DETECTED_SERVICES[$i]} (Port: ${DETECTED_PORTS[$i]})"
        done
    else
        log_error "No port-forward processes found"
        return 1
    fi
}

# Function to monitor port-forwards
monitor_port_forwards() {
    local monitor_id="bookverse-pf-monitor-$$"
    
    # Create log file
    echo "BookVerse Port-Forward Monitor Started at $(date)" > "$LOG_FILE"
    echo "Monitor ID: $monitor_id" >> "$LOG_FILE"
    echo "Check interval: ${MONITOR_INTERVAL}s" >> "$LOG_FILE"
    echo "---" >> "$LOG_FILE"
    
    if [[ "$BACKGROUND" == "false" ]]; then
        log_info "Starting port-forward monitoring (Ctrl+C to stop)"
        log_info "Log file: $LOG_FILE"
        log_info "Check interval: ${MONITOR_INTERVAL} seconds"
        echo
    fi
    
    while true; do
        detect_port_forwards
        
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        local all_good=true
        local status_msg="[$timestamp] Port-forward status:"
        
        if [[ ${#DETECTED_PIDS[@]} -eq 0 ]]; then
            status_msg="$status_msg No port-forwards detected"
            all_good=false
        else
            for i in "${!DETECTED_PIDS[@]}"; do
                local pid="${DETECTED_PIDS[$i]}"
                local service="${DETECTED_SERVICES[$i]}"
                local port="${DETECTED_PORTS[$i]}"
                
                if check_port_forward_status "$pid" "$service" "$port"; then
                    status_msg="$status_msg ✅ $service (PID: $pid, Port: $port)"
                else
                    status_msg="$status_msg ❌ $service (PID: $pid, Port: $port) - FAILED"
                    all_good=false
                fi
            done
        fi
        
        # Log to file
        echo "$status_msg" >> "$LOG_FILE"
        
        if [[ "$all_good" == "false" ]]; then
            echo "⚠️  Some port-forwards have issues. Check log: $LOG_FILE" >> "$LOG_FILE"
        fi
        
        # Show on console if not in background
        if [[ "$BACKGROUND" == "false" ]]; then
            echo "$status_msg"
            if [[ "$all_good" == "false" ]]; then
                log_warning "Some port-forwards have issues. Check log: $LOG_FILE"
            fi
        fi
        
        sleep "$MONITOR_INTERVAL"
    done
}

# Main execution
main() {
    if [[ "$STATUS" == "true" ]]; then
        show_status
        exit $?
    fi
    
    monitor_port_forwards
}

# Run main function
main "$@"
