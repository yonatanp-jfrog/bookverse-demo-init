#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# UPDATE KUBERNETES REGISTRY CONFIGURATION
# =============================================================================
# Updates existing K8s cluster to use a new JFrog Platform registry
# This script handles:
# - Updating docker-registry secrets with new credentials
# - Regenerating access tokens for the new platform
# - Restarting deployments to pull from new registry
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

usage() {
    cat <<'EOF'
Usage: ./scripts/k8s/update-registry.sh [OPTIONS]

Updates existing Kubernetes cluster to use a new JFrog Platform registry.

Environment variables (required):
  NEW_JFROG_URL           New JFrog Platform URL (e.g., https://acme.jfrog.io)
  NEW_JFROG_ADMIN_TOKEN   Admin token for the new platform
  
Environment variables (optional):
  K8S_NAMESPACE           Kubernetes namespace (default: bookverse-prod)
  K8S_SECRET_NAME         Docker registry secret name (default: jfrog-docker-pull)
  K8S_USERNAME            Registry username (default: k8s.pull@bookverse.com)
  SKIP_TOKEN_GENERATION   Skip access token generation, use K8S_PASSWORD directly
  K8S_PASSWORD            Registry password (if SKIP_TOKEN_GENERATION=true)

Options:
  --dry-run              Show what would be done without making changes
  --restart-deployments  Restart deployments after updating registry
  --help, -h             Show this help message

Examples:
  # Update with auto-generated access token (recommended)
  export NEW_JFROG_URL='https://acme.jfrog.io'
  export NEW_JFROG_ADMIN_TOKEN='your-admin-token'
  ./scripts/k8s/update-registry.sh --restart-deployments

  # Update with existing password/token
  export NEW_JFROG_URL='https://acme.jfrog.io'
  export NEW_JFROG_ADMIN_TOKEN='your-admin-token'
  export SKIP_TOKEN_GENERATION=true
  export K8S_PASSWORD='existing-user-password-or-token'
  ./scripts/k8s/update-registry.sh --dry-run

EOF
}

# Default values
K8S_NAMESPACE="${K8S_NAMESPACE:-bookverse-prod}"
K8S_SECRET_NAME="${K8S_SECRET_NAME:-jfrog-docker-pull}"
K8S_USERNAME="${K8S_USERNAME:-k8s.pull@bookverse.com}"
K8S_EMAIL="${K8S_EMAIL:-${K8S_USERNAME}}"
DRY_RUN=false
RESTART_DEPLOYMENTS=false
SKIP_TOKEN_GENERATION="${SKIP_TOKEN_GENERATION:-false}"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --restart-deployments)
            RESTART_DEPLOYMENTS=true
            shift
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

# Validate required environment variables
if [[ -z "${NEW_JFROG_URL:-}" ]]; then
    log_error "NEW_JFROG_URL environment variable is required"
    exit 1
fi

if [[ -z "${NEW_JFROG_ADMIN_TOKEN:-}" ]]; then
    log_error "NEW_JFROG_ADMIN_TOKEN environment variable is required"
    exit 1
fi

# Extract registry server from URL
NEW_REGISTRY_SERVER=$(echo "$NEW_JFROG_URL" | sed 's|https://||')

log_info "Kubernetes Registry Update Configuration:"
log_info "  Target namespace: $K8S_NAMESPACE"
log_info "  Secret name: $K8S_SECRET_NAME"
log_info "  Registry server: $NEW_REGISTRY_SERVER"
log_info "  Registry username: $K8S_USERNAME"
log_info "  Dry run: $DRY_RUN"
log_info "  Restart deployments: $RESTART_DEPLOYMENTS"
echo

# Function to execute kubectl commands with dry-run support
kubectl_exec() {
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "[DRY RUN] kubectl $*"
    else
        kubectl "$@"
    fi
}

# Function to generate access token for K8s user
generate_access_token() {
    log_info "Generating access token for K8s user..."
    
    local token_response
    if ! token_response=$(curl -s -X POST \
        --header "Authorization: Bearer ${NEW_JFROG_ADMIN_TOKEN}" \
        --header "Content-Type: application/json" \
        --data "{
            \"username\": \"${K8S_USERNAME}\",
            \"scope\": \"applied-permissions/user\",
            \"expires_in\": 31536000,
            \"description\": \"K8s image pull token - auto-generated\"
        }" \
        "${NEW_JFROG_URL}/access/api/v1/tokens" 2>/dev/null); then
        log_error "Failed to generate access token"
        return 1
    fi
    
    local access_token
    if ! access_token=$(echo "$token_response" | jq -r '.access_token' 2>/dev/null); then
        log_error "Failed to parse access token from response"
        return 1
    fi
    
    if [[ "$access_token" == "null" || -z "$access_token" ]]; then
        log_error "Invalid access token received"
        return 1
    fi
    
    log_success "Access token generated successfully"
    echo "$access_token"
}

# Main execution
main() {
    log_info "Starting Kubernetes registry update process..."
    echo
    
    # Check if namespace exists
    if ! kubectl get namespace "$K8S_NAMESPACE" >/dev/null 2>&1; then
        log_error "Namespace '$K8S_NAMESPACE' does not exist"
        log_info "Please create the namespace first or run the K8s bootstrap script"
        exit 1
    fi
    
    # Determine password/token to use
    local k8s_password
    if [[ "$SKIP_TOKEN_GENERATION" == "true" ]]; then
        if [[ -z "${K8S_PASSWORD:-}" ]]; then
            log_error "K8S_PASSWORD is required when SKIP_TOKEN_GENERATION=true"
            exit 1
        fi
        k8s_password="$K8S_PASSWORD"
        log_info "Using provided password/token"
    else
        if ! k8s_password=$(generate_access_token); then
            log_error "Failed to generate access token"
            exit 1
        fi
    fi
    
    # Update docker registry secret
    log_info "Updating docker registry secret '$K8S_SECRET_NAME' in namespace '$K8S_NAMESPACE'..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would update secret with:"
        log_info "  Server: $NEW_REGISTRY_SERVER"
        log_info "  Username: $K8S_USERNAME" 
        log_info "  Password: [REDACTED]"
        log_info "  Email: $K8S_EMAIL"
    else
        # Create/update the secret
        kubectl -n "$K8S_NAMESPACE" create secret docker-registry "$K8S_SECRET_NAME" \
            --docker-server="$NEW_REGISTRY_SERVER" \
            --docker-username="$K8S_USERNAME" \
            --docker-password="$k8s_password" \
            --docker-email="$K8S_EMAIL" \
            --dry-run=client -o yaml | kubectl apply -f -
        
        log_success "Docker registry secret updated successfully"
    fi
    
    # Restart deployments if requested
    if [[ "$RESTART_DEPLOYMENTS" == "true" ]]; then
        log_info "Restarting deployments in namespace '$K8S_NAMESPACE'..."
        
        local deployments
        if deployments=$(kubectl -n "$K8S_NAMESPACE" get deployments -o name 2>/dev/null); then
            if [[ -n "$deployments" ]]; then
                echo "$deployments" | while read -r deployment; do
                    log_info "  Restarting $deployment..."
                    kubectl_exec -n "$K8S_NAMESPACE" rollout restart "$deployment"
                done
                
                if [[ "$DRY_RUN" == "false" ]]; then
                    log_info "Waiting for deployments to be ready..."
                    echo "$deployments" | while read -r deployment; do
                        kubectl -n "$K8S_NAMESPACE" rollout status "$deployment" --timeout=300s
                    done
                fi
            else
                log_info "No deployments found in namespace '$K8S_NAMESPACE'"
            fi
        else
            log_warning "Could not list deployments in namespace '$K8S_NAMESPACE'"
        fi
    fi
    
    echo
    log_success "Kubernetes registry update completed successfully!"
    log_info "Registry Configuration:"
    log_info "  Server: $NEW_REGISTRY_SERVER"
    log_info "  Username: $K8S_USERNAME"
    log_info "  Secret: $K8S_SECRET_NAME (in namespace $K8S_NAMESPACE)"
    
    if [[ "$RESTART_DEPLOYMENTS" == "false" ]]; then
        echo
        log_warning "Deployments were not restarted automatically."
        log_info "To pull images from the new registry, manually restart your deployments:"
        log_info "  kubectl -n $K8S_NAMESPACE rollout restart deployment --all"
    fi
}

# Trap errors and provide helpful context
trap 'log_error "Script failed at line $LINENO. Check the error above for details."' ERR

# Run main function
main "$@"
