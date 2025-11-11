#!/usr/bin/env bash
# =============================================================================
# BookVerse Platform - Docker Image Cleanup and Registry Management Script
# =============================================================================
#
# Comprehensive Docker image cleanup for faulty non-semver images in JFrog registry
#
# 🎯 PURPOSE:
#     This script provides comprehensive Docker image cleanup and registry management
#     for the BookVerse platform, implementing sophisticated image identification,
#     faulty version detection, OIDC authentication, and automated cleanup workflows
#     for maintaining clean and efficient container registry operations.
#
# 🏗️ ARCHITECTURE:
#     - Image Analysis: Comprehensive Docker image version analysis and validation
#     - Registry Management: JFrog Artifactory integration with OIDC authentication
#     - Faulty Detection: Sophisticated non-semver image identification and classification
#     - Cleanup Automation: Automated deletion with safety checks and validation
#     - Authentication Integration: OIDC token management with GitHub Actions support
#     - Operation Modes: Dry-run, targeted deletion, and comprehensive cleanup modes
#
# 🚀 KEY FEATURES:
#     - Automated faulty Docker image detection with non-semver version identification
#     - JFrog Artifactory integration with secure OIDC authentication
#     - Comprehensive cleanup modes supporting dry-run and targeted deletion
#     - GitHub Actions OIDC integration for secure CI/CD authentication
#     - Service-specific cleanup with granular control over deletion operations
#     - Safety mechanisms with dry-run mode and verbose logging for operation transparency
#
# 📊 BUSINESS LOGIC:
#     - Registry Optimization: Removing faulty images to optimize storage and performance
#     - Version Management: Ensuring clean semver versioning across all services
#     - Operational Efficiency: Automated cleanup reducing manual registry maintenance
#     - Cost Optimization: Storage cleanup reducing registry storage costs
#     - Quality Assurance: Maintaining high-quality image repository standards
#
# 🛠️ USAGE PATTERNS:
#     - CI/CD Cleanup: Automated cleanup in continuous integration pipelines
#     - Development Maintenance: Regular cleanup of development and testing images
#     - Registry Housekeeping: Periodic maintenance for registry optimization
#     - Incident Response: Emergency cleanup of problematic image versions
#     - Version Migration: Cleanup during version control system migrations
#
# ⚙️ PARAMETERS:
#     [Command Line Options]
#     --dry-run             : Preview mode showing deletion targets without execution
#     --target-tag TAG      : Delete specific tag version (e.g., '180-1')
#     --service SERVICE     : Target specific service (inventory, recommendations, checkout, platform, web)
#     --verbose             : Enable detailed logging and operation visibility
#     --help, -h           : Display comprehensive help information
#     
#     [No Parameters]
#     Default Behavior     : Comprehensive cleanup of all faulty non-semver images
#
# 🌍 ENVIRONMENT VARIABLES:
#     [Required Configuration]
#     JFROG_URL            : JFrog Platform base URL (e.g., https://swampupsec.jfrog.io)
#     
#     [Optional Configuration]
#     PROJECT_KEY          : JFrog project key (default: bookverse)
#     JF_OIDC_TOKEN        : Pre-generated JFrog OIDC token for authentication
#     
#     [GitHub Actions Integration]
#     ACTIONS_ID_TOKEN_REQUEST_TOKEN : GitHub Actions OIDC token request token
#     ACTIONS_ID_TOKEN_REQUEST_URL   : GitHub Actions OIDC token request URL
#
# 📋 PREREQUISITES:
#     [System Requirements]
#     - bash (4.0+): Advanced shell features for complex cleanup operations
#     - python3: Python runtime for cleanup script execution
#     - curl: HTTP client for JFrog API communication and OIDC authentication
#     - jq: JSON processor for API response parsing and token management
#     
#     [Platform Requirements]
#     - JFrog Artifactory access: Registry access with appropriate permissions
#     - OIDC Provider configuration: GitHub Actions or external OIDC integration
#     - Network connectivity: Internet access for JFrog API communication
#
# 📤 OUTPUTS:
#     [Return Codes]
#     0: Success - Cleanup completed successfully without errors
#     1: Error - Cleanup failed with detailed error reporting
#     
#     [Cleanup Results]
#     - List of identified faulty images with non-semver versioning
#     - Deletion confirmation for each removed image with detailed logging
#     - Summary statistics of cleanup operation and storage reclamation
#     - Dry-run preview showing deletion targets without execution
#     
#     [Registry State]
#     - Clean registry with only semver-compliant images
#     - Optimized storage utilization with faulty image removal
#     - Maintained service integrity with targeted cleanup operations
#
# 💡 EXAMPLES:
#     [Dry-Run Preview Mode]
#     export JFROG_URL='https://swampupsec.jfrog.io'
#     ./scripts/cleanup-faulty-docker-images.sh --dry-run
#     
#     [Targeted Tag Deletion]
#     ./scripts/cleanup-faulty-docker-images.sh --target-tag "180-1"
#     
#     [Service-Specific Cleanup]
#     ./scripts/cleanup-faulty-docker-images.sh --service checkout --verbose
#     
#     [Comprehensive Cleanup]
#     ./scripts/cleanup-faulty-docker-images.sh --verbose
#
# ⚠️ ERROR HANDLING:
#     [Common Failure Modes]
#     - JFROG_URL not configured: Validates JFrog Platform URL configuration
#     - Authentication failure: Handles OIDC token generation and validation errors
#     - Network connectivity: Manages API communication and timeout errors
#     - Insufficient permissions: Validates registry access and deletion permissions
#     - Python script missing: Checks for required cleanup script dependencies
#     
#     [Recovery Procedures]
#     - Environment Validation: Ensure JFROG_URL and authentication are configured
#     - OIDC Configuration: Verify GitHub Actions OIDC or JF_OIDC_TOKEN setup
#     - Permission Validation: Confirm registry access and deletion permissions
#     - Network Troubleshooting: Check connectivity and DNS resolution
#
# 🔍 DEBUGGING:
#     [Debug Mode]
#     set -x                                       # Enable bash debug mode
#     ./scripts/cleanup-faulty-docker-images.sh   # Run with debug output
#     
#     [Verbose Operation]
#     ./scripts/cleanup-faulty-docker-images.sh --verbose --dry-run
#     
#     [Manual Validation]
#     curl -H "Authorization: Bearer $TOKEN" "$JFROG_URL/artifactory/api/repositories"
#
# 🔗 INTEGRATION POINTS:
#     [JFrog Integration]
#     - Artifactory API: Repository and image management operations
#     - OIDC Authentication: Secure token-based authentication
#     - Project Management: Multi-project registry organization
#     
#     [CI/CD Integration]
#     - GitHub Actions: Automated cleanup in deployment pipelines
#     - OIDC Provider: Secure authentication without stored credentials
#     - Python Cleanup Script: Advanced image analysis and deletion logic
#
# 📊 PERFORMANCE:
#     [Execution Time]
#     - Image Analysis: 30-60 seconds for complete registry scan
#     - Deletion Operations: 10-30 seconds per image depending on size
#     - OIDC Authentication: 5-10 seconds for token generation
#     - Total Cleanup Time: 2-10 minutes depending on image count
#
# 🛡️ SECURITY CONSIDERATIONS:
#     [Authentication Security]
#     - OIDC token-based authentication without stored credentials
#     - Short-lived tokens with automatic expiration
#     - Secure token exchange with GitHub Actions integration
#     
#     [Operation Security]
#     - Dry-run mode for safe operation preview
#     - Targeted deletion preventing accidental removal
#     - Audit logging for compliance and troubleshooting
#
# 📚 REFERENCES:
#     [Documentation]
#     - JFrog Artifactory API: https://www.jfrog.com/confluence/display/JFROG/Artifactory+REST+API
#     - GitHub OIDC: https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect
#     - Python Cleanup Script: ./cleanup-faulty-docker-images.py
#
# Authors: BookVerse Platform Team
# Version: 1.0.0
# Last Updated: 2024-01-01
# =============================================================================

set -euo pipefail

# 📁 Directory Configuration: Script and project directory resolution
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# 🔧 Parameter Configuration: Command line option variables
DRY_RUN=""        # Preview mode flag for safe operation testing
TARGET_TAG=""     # Specific tag for targeted deletion operations
SERVICE=""        # Service filter for granular cleanup control
VERBOSE=""        # Detailed logging flag for operation visibility
HELP=""          # Help display flag for usage information

# 📋 Command Line Parsing: Process user options and configure operation mode
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            # 👁️ Dry Run Mode: Enable preview without actual deletion
            DRY_RUN="--dry-run"
            shift
            ;;
        --target-tag)
            # 🎯 Targeted Deletion: Specify exact tag for removal
            TARGET_TAG="$2"
            shift 2
            ;;
        --service)
            # 🔍 Service Filter: Limit cleanup to specific service
            SERVICE="$2"
            shift 2
            ;;
        --verbose)
            # 📊 Verbose Logging: Enable detailed operation reporting
            VERBOSE="--verbose"
            shift
            ;;
        --help)
            # 📖 Help Request: Display comprehensive usage information
            HELP="true"
            shift
            ;;
        *)
            # ❌ Invalid Option: Handle unknown command line arguments
            echo "❌ Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

if [[ -n "$HELP" ]]; then
    echo "BookVerse Docker Image Cleanup Script"
    echo ""
    echo "This script identifies and deletes faulty non-semver Docker images that were"
    echo "created with build numbers (e.g., '180-1') instead of proper semantic versions."
    echo ""
    echo "Usage:"
    echo "  $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --dry-run              Show what would be deleted without actually deleting"
    echo "  --target-tag TAG       Delete specific tag (e.g., '180-1')"
    echo "  --service SERVICE      Target specific service (inventory, recommendations, checkout, platform, web)"
    echo "  --verbose              Enable verbose logging"
    echo "  --help                 Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  JFROG_URL             JFrog base URL (required)"
    echo "  PROJECT_KEY           Project key (default: bookverse)"
    echo ""
    echo "Authentication:"
    echo "  Uses OIDC token from GitHub Actions or JF_OIDC_TOKEN environment variable"
    echo ""
    echo "Examples:"
    echo ""
    echo "  $0 --dry-run"
    echo ""
    echo ""
    echo "  $0 --target-tag 180-1"
    echo ""
    echo ""
    echo "  $0 --service checkout"
    echo ""
    echo ""
    echo "  $0 --dry-run --verbose"
    exit 0
fi

# 🌍 Environment Validation: Verify required configuration variables
if [[ -z "${JFROG_URL:-}" ]]; then
    echo "❌ JFROG_URL environment variable is required"
    echo "   Example: export JFROG_URL='https://swampupsec.jfrog.io'"
    exit 1
fi

# 📋 Project Configuration: Set JFrog project key with default fallback
PROJECT_KEY="${PROJECT_KEY:-bookverse}"

echo "🧹 BookVerse Docker Image Cleanup"
echo "=================================="
echo ""

# 🔐 Authentication Initialization: Prepare OIDC token for JFrog access
JF_OIDC_TOKEN=""

# 🔑 Authentication Strategy: Multiple authentication methods for flexibility
if [[ -n "${JF_OIDC_TOKEN:-}" ]]; then
    # ✅ Pre-Generated Token: Use existing JFrog OIDC token from environment
    echo "✅ Using JF_OIDC_TOKEN from environment"
elif [[ -n "${ACTIONS_ID_TOKEN_REQUEST_TOKEN:-}" && -n "${ACTIONS_ID_TOKEN_REQUEST_URL:-}" ]]; then
    # 🔐 GitHub Actions OIDC: Generate token through GitHub Actions integration
    echo "🔐 Generating OIDC token from GitHub Actions..."
    
    # 🎫 GitHub Token Request: Obtain GitHub OIDC token for JFrog exchange
    GITHUB_TOKEN=$(curl -sS -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" \
        "$ACTIONS_ID_TOKEN_REQUEST_URL&audience=$JFROG_URL" | jq -r '.value')
    
    # ❌ GitHub Token Validation: Ensure successful token acquisition
    if [[ -z "$GITHUB_TOKEN" || "$GITHUB_TOKEN" == "null" ]]; then
        echo "❌ Failed to get GitHub OIDC token"
        exit 1
    fi
    
    # 🔄 Token Exchange: Convert GitHub token to JFrog access token
    JF_OIDC_TOKEN=$(curl -sS -X POST "$JFROG_URL/access/api/v1/oidc/token" \
        -H "Content-Type: application/json" \
        -d "{\"grant_type\": \"urn:ietf:params:oauth:grant-type:token-exchange\", \"subject_token\": \"$GITHUB_TOKEN\", \"subject_token_type\": \"urn:ietf:params:oauth:token-type:id_token\", \"provider_name\": \"bookverse-checkout-github\"}" \
        | jq -r '.access_token')
    
    # ❌ JFrog Token Validation: Ensure successful token exchange
    if [[ -z "$JF_OIDC_TOKEN" || "$JF_OIDC_TOKEN" == "null" ]]; then
        echo "❌ Failed to exchange GitHub token for JFrog token"
        exit 1
    fi
    
    echo "✅ Successfully generated JFrog OIDC token"
else
    # ❌ Authentication Failure: No valid authentication method available
    echo "❌ No authentication method available"
    echo "   Either set JF_OIDC_TOKEN environment variable"
    echo "   or run from GitHub Actions with OIDC enabled"
    exit 1
fi

# 🐍 Python Script Validation: Verify cleanup script availability
PYTHON_SCRIPT="$SCRIPT_DIR/cleanup-faulty-docker-images.py"
if [[ ! -f "$PYTHON_SCRIPT" ]]; then
    echo "❌ Python script not found: $PYTHON_SCRIPT"
    exit 1
fi

# 🔐 Script Permissions: Ensure Python script is executable
chmod +x "$PYTHON_SCRIPT"

# 🛠️ Command Construction: Build Python script execution command with authentication
PYTHON_CMD=(
    python3 "$PYTHON_SCRIPT"          # Python interpreter and script path
    --jfrog-url "$JFROG_URL"          # JFrog Platform base URL
    --jfrog-token "$JF_OIDC_TOKEN"    # OIDC authentication token
    --project-key "$PROJECT_KEY"      # JFrog project key for scope
)

# 🔧 Command Options: Add user-specified options to Python command
if [[ -n "$DRY_RUN" ]]; then
    # 👁️ Dry Run: Add preview mode flag
    PYTHON_CMD+=("$DRY_RUN")
fi

if [[ -n "$TARGET_TAG" ]]; then
    # 🎯 Targeted Deletion: Add specific tag parameter
    PYTHON_CMD+=(--target-tag "$TARGET_TAG")
fi

if [[ -n "$SERVICE" ]]; then
    # 🔍 Service Filter: Add service-specific filtering
    PYTHON_CMD+=(--service "$SERVICE")
fi

if [[ -n "$VERBOSE" ]]; then
    # 📊 Verbose Output: Add detailed logging flag
    PYTHON_CMD+=("$VERBOSE")
fi

echo "🚀 Running cleanup script..."
echo ""

# 🏃 Script Execution: Execute Python cleanup script with error handling
if "${PYTHON_CMD[@]}"; then
    # ✅ Success: Cleanup completed without errors
    echo ""
    echo "✅ Cleanup completed successfully"
else
    # ❌ Failure: Cleanup failed with error reporting
    echo ""
    echo "❌ Cleanup failed"
    exit 1
fi
