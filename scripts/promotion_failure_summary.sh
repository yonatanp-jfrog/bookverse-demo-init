#!/usr/bin/env bash
# =============================================================================
# BookVerse Platform - Promotion Failure Summary Script
# =============================================================================
#
# Handles promotion policy failures by creating comprehensive job summaries
# that provide clear guidance on how to fix policy violations.
#
# This script is designed to be called when a promotion fails due to policy
# violations, providing developers with actionable information to resolve
# the issues and successfully retry the promotion.
#
# Usage:
#   ./promotion_failure_summary.sh '{"application_key":"bookverse-inventory",...}'
#   echo '{"json":"data"}' | ./promotion_failure_summary.sh
#   ./promotion_failure_summary.sh --help
#
# Features:
# - Parses promotion failure JSON data
# - Generates detailed GitHub job summaries
# - Provides specific remediation guidance
# - Explains policy requirements and next steps
# - Integrates with CI/CD workflows
#
# Authors: BookVerse Platform Team
# Version: 1.0.0
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HANDLER_SCRIPT="${SCRIPT_DIR}/handle_promotion_failure.py"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}" >&2
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}" >&2
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}" >&2
}

log_error() {
    echo -e "${RED}❌ $1${NC}" >&2
}

show_usage() {
    cat << 'EOF'
BookVerse Promotion Failure Summary Generator

USAGE:
    ./promotion_failure_summary.sh [JSON_DATA]
    echo '{"json":"data"}' | ./promotion_failure_summary.sh
    ./promotion_failure_summary.sh --help

DESCRIPTION:
    Processes promotion failure data and generates comprehensive job summaries
    with actionable guidance for fixing policy violations.

PARAMETERS:
    JSON_DATA    Promotion failure data as JSON string (optional, reads from stdin if not provided)
    --help       Show this help message

EXAMPLES:
    # From command line parameter
    ./promotion_failure_summary.sh '{"application_key":"bookverse-inventory","version":"2.7.24",...}'
    
    # From stdin (useful in pipelines)
    echo '{"application_key":"bookverse-inventory",...}' | ./promotion_failure_summary.sh
    
    # In GitHub Actions workflow
    - name: Handle Promotion Failure
      if: failure()
      run: |
        echo '${{ steps.promotion.outputs.failure_data }}' | ./scripts/promotion_failure_summary.sh

ENVIRONMENT VARIABLES:
    GITHUB_STEP_SUMMARY    If set, the summary will be written to GitHub job summary
    VERBOSE               Enable verbose output (set to any non-empty value)

OUTPUT:
    The script outputs a formatted markdown summary that includes:
    - Promotion failure details
    - Specific policy violations
    - Remediation guidance for each failed policy
    - Stage transition information
    - Next steps and useful links

INTEGRATION:
    This script is designed to be called from CI/CD workflows when promotions
    fail due to policy violations. It helps developers understand what went
    wrong and how to fix the issues.

EOF
}

# Check if help is requested
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    show_usage
    exit 0
fi

# Check if the handler script exists
if [[ ! -f "${HANDLER_SCRIPT}" ]]; then
    log_error "Handler script not found: ${HANDLER_SCRIPT}"
    log_error "Please ensure handle_promotion_failure.py is in the same directory as this script."
    exit 1
fi

# Check if Python is available
if ! command -v python3 >/dev/null 2>&1; then
    log_error "Python 3 is required but not found in PATH"
    exit 1
fi

# Determine input source
if [[ $# -eq 0 ]]; then
    # Read from stdin
    if [[ "${VERBOSE:-}" ]]; then
        log_info "Reading promotion failure data from stdin..."
    fi
    
    if [[ -t 0 ]]; then
        log_error "No input provided. Either pass JSON data as parameter or pipe it to stdin."
        log_info "Use --help for usage information."
        exit 1
    fi
    
    # Read all input from stdin
    FAILURE_DATA=$(cat)
    
    if [[ -z "${FAILURE_DATA}" ]]; then
        log_error "No data received from stdin"
        exit 1
    fi
    
    if [[ "${VERBOSE:-}" ]]; then
        log_info "Received $(echo "${FAILURE_DATA}" | wc -c) characters from stdin"
    fi
    
else
    # Use command line parameter
    FAILURE_DATA="$1"
    
    if [[ "${VERBOSE:-}" ]]; then
        log_info "Using failure data from command line parameter"
    fi
fi

# Validate that we have JSON-like data
if [[ ! "${FAILURE_DATA}" =~ ^\s*\{ ]]; then
    log_error "Input does not appear to be JSON data (should start with '{')"
    log_error "Received: ${FAILURE_DATA:0:100}..."
    exit 1
fi

# Process the failure data
if [[ "${VERBOSE:-}" ]]; then
    log_info "Processing promotion failure data..."
fi

# Build the command arguments
HANDLER_ARGS=(
    "--failure-json" "${FAILURE_DATA}"
)

# Add GitHub summary flag if environment variable is set
if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    HANDLER_ARGS+=("--github-summary")
    if [[ "${VERBOSE:-}" ]]; then
        log_info "GitHub Step Summary path detected: ${GITHUB_STEP_SUMMARY}"
    fi
fi

# Add verbose flag if set
if [[ "${VERBOSE:-}" ]]; then
    HANDLER_ARGS+=("--verbose")
fi

# Execute the handler script
if python3 "${HANDLER_SCRIPT}" "${HANDLER_ARGS[@]}"; then
    if [[ "${VERBOSE:-}" ]]; then
        log_success "Promotion failure summary generated successfully"
        
        if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
            log_success "Summary written to GitHub job summary"
        fi
    fi
else
    EXIT_CODE=$?
    log_error "Failed to generate promotion failure summary (exit code: ${EXIT_CODE})"
    exit ${EXIT_CODE}
fi

# Additional guidance
if [[ "${VERBOSE:-}" ]]; then
    echo >&2
    log_info "Next steps:"
    echo "  1. Review the generated summary above" >&2
    echo "  2. Address each failed policy requirement" >&2
    echo "  3. Re-run the promotion once issues are resolved" >&2
    echo "  4. Contact platform support if you need assistance" >&2
fi
