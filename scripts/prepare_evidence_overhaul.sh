#!/usr/bin/env bash

set -e

# =============================================================================
# PREPARE EVIDENCE KEY OVERHAUL SCRIPT
# =============================================================================
# This script orchestrates the complete preparation for evidence key overhaul:
# 1. Removes existing evidence key secrets from all repositories
# 2. Updates references to treat public key as variable instead of secret
# 3. Commits any workflow changes to repositories
# =============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    echo "🔄 Evidence Key Overhaul Preparation"
    echo "===================================="
    echo ""
    echo "This script will prepare all BookVerse repositories for the"
    echo "evidence key generation overhaul by:"
    echo ""
    echo "1. 🗑️  Removing existing evidence key secrets"
    echo "2. 🔄 Updating public key references (secret → variable)"
    echo "3. 📝 Committing workflow changes to repositories"
    echo ""
    
    # Confirmation
    read -p "Continue with evidence key overhaul preparation? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Preparation cancelled by user"
        exit 0
    fi
    echo ""
    
    # Get script directory
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # Step 1: Remove existing evidence key secrets
    log_info "Step 1: Removing existing evidence key secrets..."
    echo ""
    if [[ -f "$script_dir/cleanup_evidence_keys.sh" ]]; then
        "$script_dir/cleanup_evidence_keys.sh"
    else
        log_error "cleanup_evidence_keys.sh not found!"
        exit 1
    fi
    
    echo ""
    echo "=========================================="
    echo ""
    
    # Step 2: Update public key references
    log_info "Step 2: Updating public key references..."
    echo ""
    if [[ -f "$script_dir/update_evidence_key_references.sh" ]]; then
        "$script_dir/update_evidence_key_references.sh"
    else
        log_error "update_evidence_key_references.sh not found!"
        exit 1
    fi
    
    echo ""
    echo "=========================================="
    echo ""
    
    # Summary
    echo "🎉 Evidence Key Overhaul Preparation Complete!"
    echo "=============================================="
    echo ""
    echo "✅ Completed tasks:"
    echo "  1. Removed existing evidence key secrets from all repositories"
    echo "  2. Updated public key references to use variables instead of secrets"
    echo "  3. Updated evidence_keys_setup.sh to use new approach"
    echo ""
    echo "🚀 Ready for evidence key generation overhaul!"
    echo ""
    log_success "All BookVerse repositories are now prepared for the new evidence key system"
}

# Execute main function
main "$@"
