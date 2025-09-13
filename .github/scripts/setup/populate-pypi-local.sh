#!/usr/bin/env bash

# =============================================================================
# PYPI LOCAL REPOSITORY POPULATION SCRIPT
# =============================================================================
# Downloads Python packages and uploads them to JFrog local PyPI repository
# This bypasses the need for PyPI proxy connectivity issues
# =============================================================================

set -euo pipefail

# Load configuration
source "$(dirname "$0")/../.github/scripts/setup/config.sh"

echo ""
echo "🐍 Populating PyPI local repository with required packages"
echo "🔧 Project: $PROJECT_KEY"
echo "🔧 JFrog URL: $JFROG_URL"
echo ""

# Create temporary directory for downloads
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

echo "📁 Using temporary directory: $TEMP_DIR"

# Define packages to download (based on inventory service requirements)
PACKAGES=(
    "fastapi==0.111.0"
    "uvicorn[standard]==0.30.0"
    "requests==2.31.0"
    "pytest==8.3.2"
    "pytest-cov==4.0.0"
    "httpx==0.27.0"
    # Add common dependencies that these packages need
    "starlette"
    "pydantic"
    "typing-extensions"
    "click"
    "h11"
    "anyio"
    "sniffio"
    "idna"
    "certifi"
    "charset-normalizer"
    "urllib3"
    "coverage"
    "pluggy"
    "iniconfig"
    "packaging"
    "httpcore"
)

echo "📦 Downloading packages..."
cd "$TEMP_DIR"

# Download packages using pip download
for package in "${PACKAGES[@]}"; do
    echo "  📥 Downloading: $package"
    pip3 download --no-deps "$package" || echo "    ⚠️ Failed to download $package"
done

# Also download with dependencies for the main packages
echo ""
echo "📦 Downloading packages with dependencies..."
pip3 download fastapi==0.111.0 uvicorn==0.30.0 requests==2.31.0 pytest==8.3.2 pytest-cov==4.0.0 httpx==0.27.0

echo ""
echo "📊 Downloaded files:"
ls -la *.whl *.tar.gz 2>/dev/null || echo "No wheel/tar files found"

echo ""
echo "📤 Uploading packages to JFrog local repository..."

# Upload all downloaded packages to the local PyPI repository
for file in *.whl *.tar.gz; do
    if [[ -f "$file" ]]; then
        echo "  📤 Uploading: $file"
        curl -s -H "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
             -X PUT \
             -T "$file" \
             "${JFROG_URL}/artifactory/${PROJECT_KEY}-pypi-cache-local/$file" \
             > /dev/null && echo "    ✅ Uploaded successfully" || echo "    ❌ Upload failed"
    fi
done

echo ""
echo "✅ PyPI local repository population completed!"
echo "🔍 You can verify uploads at: ${JFROG_URL}/ui/repos/tree/General/${PROJECT_KEY}-pypi-cache-local"
