#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# UNIFIED SEMVER DETERMINATION SCRIPT
# =============================================================================
# This script provides a unified approach to semver determination across all
# BookVerse services, preventing the fallback-to-seed conflicts with Release Bundles.
#
# Usage:
#   ./determine-semver.sh --application-key bookverse-web \
#                        --version-map ./config/version-map.yaml \
#                        --jfrog-url "$JFROG_URL" \
#                        --jfrog-token "$JF_ACCESS_TOKEN" \
#                        --project-key "$PROJECT_KEY" \
#                        --packages "web,web-assets.tar.gz"
#
# Environment Variables Set:
#   APP_VERSION     - Application version (e.g., 2.4.17)
#   BUILD_NUMBER    - Build number (e.g., 3.7.26)
#   IMAGE_TAG       - Docker image tag (defaults to BUILD_NUMBER)
#   DOCKER_TAG_*    - Package-specific tags (e.g., DOCKER_TAG_WEB=1.6.15)
#
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_SCRIPT="$SCRIPT_DIR/semver_versioning.py"

# Check if Python script exists
if [[ ! -f "$PYTHON_SCRIPT" ]]; then
    echo "❌ Error: Python script not found at $PYTHON_SCRIPT" >&2
    exit 1
fi

# Check if Python 3 is available
if ! command -v python3 >/dev/null 2>&1; then
    echo "❌ Error: python3 is required but not found" >&2
    exit 1
fi

# Check if PyYAML is available
if ! python3 -c "import yaml" >/dev/null 2>&1; then
    echo "❌ Error: PyYAML is required. Install with: pip install PyYAML" >&2
    exit 1
fi

# Default values
APPLICATION_KEY=""
VERSION_MAP=""
JFROG_URL=""
JFROG_TOKEN=""
PROJECT_KEY=""
PACKAGES=""
VERBOSE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --application-key)
            APPLICATION_KEY="$2"
            shift 2
            ;;
        --version-map)
            VERSION_MAP="$2"
            shift 2
            ;;
        --jfrog-url)
            JFROG_URL="$2"
            shift 2
            ;;
        --jfrog-token)
            JFROG_TOKEN="$2"
            shift 2
            ;;
        --project-key)
            PROJECT_KEY="$2"
            shift 2
            ;;
        --packages)
            PACKAGES="$2"
            shift 2
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 --application-key KEY --version-map PATH --jfrog-url URL --jfrog-token TOKEN [OPTIONS]"
            echo ""
            echo "Required arguments:"
            echo "  --application-key KEY    Application key (e.g., bookverse-web)"
            echo "  --version-map PATH       Path to version-map.yaml file"
            echo "  --jfrog-url URL         JFrog platform URL"
            echo "  --jfrog-token TOKEN     JFrog access token"
            echo ""
            echo "Optional arguments:"
            echo "  --project-key KEY       Project key (default: bookverse)"
            echo "  --packages LIST         Comma-separated package names"
            echo "  --verbose, -v           Enable verbose output"
            echo "  --help, -h              Show this help message"
            exit 0
            ;;
        *)
            echo "❌ Error: Unknown argument $1" >&2
            echo "Use --help for usage information" >&2
            exit 1
            ;;
    esac
done

# Validate required arguments
if [[ -z "$APPLICATION_KEY" ]]; then
    echo "❌ Error: --application-key is required" >&2
    exit 1
fi

if [[ -z "$VERSION_MAP" ]]; then
    echo "❌ Error: --version-map is required" >&2
    exit 1
fi

if [[ -z "$JFROG_URL" ]]; then
    echo "❌ Error: --jfrog-url is required" >&2
    exit 1
fi

if [[ -z "$JFROG_TOKEN" ]]; then
    echo "❌ Error: --jfrog-token is required" >&2
    exit 1
fi

if [[ ! -f "$VERSION_MAP" ]]; then
    echo "❌ Error: Version map file not found: $VERSION_MAP" >&2
    exit 1
fi

# Prepare arguments for Python script
PYTHON_ARGS=(
    --application-key "$APPLICATION_KEY"
    --version-map "$VERSION_MAP"
    --jfrog-url "$JFROG_URL"
    --jfrog-token "$JFROG_TOKEN"
)

if [[ -n "$PROJECT_KEY" ]]; then
    PYTHON_ARGS+=(--project-key "$PROJECT_KEY")
fi

if [[ -n "$PACKAGES" ]]; then
    PYTHON_ARGS+=(--packages "$PACKAGES")
fi

# Execute Python script
if [[ "$VERBOSE" == "true" ]]; then
    echo "🔧 Executing: python3 $PYTHON_SCRIPT ${PYTHON_ARGS[*]}"
fi

OUTPUT=$(python3 "$PYTHON_SCRIPT" "${PYTHON_ARGS[@]}")
EXIT_CODE=$?

if [[ $EXIT_CODE -ne 0 ]]; then
    echo "❌ Error: Python script failed with exit code $EXIT_CODE" >&2
    echo "$OUTPUT" >&2
    exit $EXIT_CODE
fi

if [[ "$VERBOSE" == "true" ]]; then
    echo "📊 Python script output:"
    echo "$OUTPUT"
fi

# Parse JSON output to show summary
if command -v jq >/dev/null 2>&1; then
    echo "🧮 Version determination results:"
    echo "$OUTPUT" | jq -r '"  App Version: " + .app_version'
    echo "$OUTPUT" | jq -r '"  Build Number: " + .build_number'
    if [[ $(echo "$OUTPUT" | jq -r '.package_tags | length') -gt 0 ]]; then
        echo "  Package Tags:"
        echo "$OUTPUT" | jq -r '.package_tags | to_entries[] | "    " + .key + ": " + .value'
    fi
else
    echo "✅ Semver determination completed successfully"
    echo "📊 Raw output: $OUTPUT"
fi

echo "✅ Environment variables have been set in \$GITHUB_ENV"
