#!/bin/bash
set -euo pipefail

# BookVerse Docker Image Cleanup Script
# Identifies and deletes faulty non-semver Docker images from JFrog repositories
# 
# Usage:
#   ./cleanup-faulty-docker-images.sh [OPTIONS]
#
# Options:
#   --dry-run              Show what would be deleted without actually deleting
#   --target-tag TAG       Delete specific tag (e.g., "180-1")
#   --service SERVICE      Target specific service only
#   --verbose              Enable verbose logging
#   --help                 Show this help message

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Default values
DRY_RUN=""
TARGET_TAG=""
SERVICE=""
VERBOSE=""
HELP=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN="--dry-run"
            shift
            ;;
        --target-tag)
            TARGET_TAG="$2"
            shift 2
            ;;
        --service)
            SERVICE="$2"
            shift 2
            ;;
        --verbose)
            VERBOSE="--verbose"
            shift
            ;;
        --help)
            HELP="true"
            shift
            ;;
        *)
            echo "❌ Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Show help
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
    echo "  # Dry run to see what would be deleted"
    echo "  $0 --dry-run"
    echo ""
    echo "  # Delete specific faulty tag"
    echo "  $0 --target-tag 180-1"
    echo ""
    echo "  # Clean up only checkout service"
    echo "  $0 --service checkout"
    echo ""
    echo "  # Verbose dry run"
    echo "  $0 --dry-run --verbose"
    exit 0
fi

# Check required environment variables
if [[ -z "${JFROG_URL:-}" ]]; then
    echo "❌ JFROG_URL environment variable is required"
    echo "   Example: export JFROG_URL='https://your-instance.jfrog.io'"
    exit 1
fi

PROJECT_KEY="${PROJECT_KEY:-bookverse}"

echo "🧹 BookVerse Docker Image Cleanup"
echo "=================================="
echo ""

# Get OIDC token
JF_OIDC_TOKEN=""

# Try to get token from environment first
if [[ -n "${JF_OIDC_TOKEN:-}" ]]; then
    echo "✅ Using JF_OIDC_TOKEN from environment"
elif [[ -n "${ACTIONS_ID_TOKEN_REQUEST_TOKEN:-}" && -n "${ACTIONS_ID_TOKEN_REQUEST_URL:-}" ]]; then
    echo "🔐 Generating OIDC token from GitHub Actions..."
    
    # Get GitHub OIDC token
    GITHUB_TOKEN=$(curl -sS -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" \
        "$ACTIONS_ID_TOKEN_REQUEST_URL&audience=$JFROG_URL" | jq -r '.value')
    
    if [[ -z "$GITHUB_TOKEN" || "$GITHUB_TOKEN" == "null" ]]; then
        echo "❌ Failed to get GitHub OIDC token"
        exit 1
    fi
    
    # Exchange for JFrog token
    JF_OIDC_TOKEN=$(curl -sS -X POST "$JFROG_URL/access/api/v1/oidc/token" \
        -H "Content-Type: application/json" \
        -d "{\"grant_type\": \"urn:ietf:params:oauth:grant-type:token-exchange\", \"subject_token\": \"$GITHUB_TOKEN\", \"subject_token_type\": \"urn:ietf:params:oauth:token-type:id_token\", \"provider_name\": \"bookverse-checkout-github\"}" \
        | jq -r '.access_token')
    
    if [[ -z "$JF_OIDC_TOKEN" || "$JF_OIDC_TOKEN" == "null" ]]; then
        echo "❌ Failed to exchange GitHub token for JFrog token"
        exit 1
    fi
    
    echo "✅ Successfully generated JFrog OIDC token"
else
    echo "❌ No authentication method available"
    echo "   Either set JF_OIDC_TOKEN environment variable"
    echo "   or run from GitHub Actions with OIDC enabled"
    exit 1
fi

# Check if Python script exists
PYTHON_SCRIPT="$SCRIPT_DIR/cleanup-faulty-docker-images.py"
if [[ ! -f "$PYTHON_SCRIPT" ]]; then
    echo "❌ Python script not found: $PYTHON_SCRIPT"
    exit 1
fi

# Make Python script executable
chmod +x "$PYTHON_SCRIPT"

# Build Python command
PYTHON_CMD=(
    python3 "$PYTHON_SCRIPT"
    --jfrog-url "$JFROG_URL"
    --jfrog-token "$JF_OIDC_TOKEN"
    --project-key "$PROJECT_KEY"
)

# Add optional arguments
if [[ -n "$DRY_RUN" ]]; then
    PYTHON_CMD+=("$DRY_RUN")
fi

if [[ -n "$TARGET_TAG" ]]; then
    PYTHON_CMD+=(--target-tag "$TARGET_TAG")
fi

if [[ -n "$SERVICE" ]]; then
    PYTHON_CMD+=(--service "$SERVICE")
fi

if [[ -n "$VERBOSE" ]]; then
    PYTHON_CMD+=("$VERBOSE")
fi

# Run the Python script
echo "🚀 Running cleanup script..."
echo ""

if "${PYTHON_CMD[@]}"; then
    echo ""
    echo "✅ Cleanup completed successfully"
else
    echo ""
    echo "❌ Cleanup failed"
    exit 1
fi
