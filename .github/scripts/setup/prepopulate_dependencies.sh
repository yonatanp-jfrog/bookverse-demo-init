#!/usr/bin/env bash

# =============================================================================
# DEPENDENCY PRE-POPULATION SCRIPT (CORRECTED)
# =============================================================================
# Pre-populates critical dependencies used by BookVerse services
# This ensures all CI/CD pipelines can run with dependencies from Artifactory
# =============================================================================

set -e

# Load configuration
source "$(dirname "$0")/config.sh"

echo ""
echo "🚀 Pre-populating dependencies for BookVerse platform"
echo "🔧 Project: $PROJECT_KEY"
echo "🔧 JFrog URL: $JFROG_URL"
echo ""

# Function to download and cache Python packages
cache_python_package() {
    local package="$1"
    local version="${2:-latest}"
    
    echo "📦 Caching Python package: $package${version:+ ($version)}"
    
    # Use 'pip download' which respects the config from 'jf pipc'
    # This will download the package and its dependencies into Artifactory's cache
    if [[ "$version" == "latest" ]]; then
        pip download "$package" --no-deps > /dev/null 2>&1 || echo "⚠️ Warning: Could not cache $package"
    else
        pip download "$package==$version" --no-deps > /dev/null 2>&1 || echo "⚠️ Warning: Could not cache $package==$version"
    fi
    # Clean up locally downloaded files
    rm -f *.whl *.tar.gz
}

# Function to download and cache npm packages
cache_npm_package() {
    local package="$1"
    local version="${2:-latest}"
    
    echo "📦 Caching npm package: $package${version:+ ($version)}"
    
    # Use 'npm pack' which respects the config from 'jf npmc'
    if [[ "$version" == "latest" ]]; then
        npm pack "$package" > /dev/null 2>&1 || echo "⚠️ Warning: Could not cache $package"
    else
        npm pack "$package@$version" > /dev/null 2>&1 || echo "⚠️ Warning: Could not cache $package@$version"
    fi
    
    # Clean up downloaded tarballs
    rm -f *.tgz
}

# Function to pull and cache Docker images (supports Docker Hub library namespace)
cache_docker_image() {
    local image="$1"
    local tag="${2:-latest}"
    
    echo "🐳 Caching Docker image: $image:$tag"
    
    local docker_registry_host=$(echo "$JFROG_URL" | sed 's|https://||' | sed 's|http://||')
    local virtual_repo_path="${docker_registry_host}/${PROJECT_KEY}-dockerhub-virtual"
    
    # Official Docker Hub images require the 'library/' prefix when pulled via Artifactory
    local image_path="$image"
    if [[ "$image" != */* ]]; then
        image_path="library/$image"
    fi
    
    # Use JFrog CLI for secure Docker operations if available
    if [[ "$USE_JF_DOCKER" == "true" ]]; then
        # Retry pulls using JFrog CLI to handle transient network/remote hiccups
        local attempt
        for attempt in 1 2 3; do
            if jf docker pull "${virtual_repo_path}/${image_path}:$tag" 2>/dev/null; then
                return 0
            fi
            # Fallback: try without 'library/' if the first path failed
            if [[ "$image_path" == library/* ]]; then
                if jf docker pull "${virtual_repo_path}/${image}:$tag" 2>/dev/null; then
                    return 0
                fi
            fi
            sleep $((attempt * 2))
        done
    else
        # Fallback to direct docker pull (may have authentication issues)
        local attempt
        for attempt in 1 2 3; do
            if docker pull "${virtual_repo_path}/${image_path}:$tag"; then
                return 0
            fi
            # Fallback: try without 'library/' if the first path failed
            if [[ "$image_path" == library/* ]]; then
                if docker pull "${virtual_repo_path}/${image}:$tag"; then
                    return 0
                fi
            fi
            sleep $((attempt * 2))
        done
    fi
    echo "⚠️ docker pull failed for $image:$tag via ${virtual_repo_path}; attempting API prefetch"

    # Fallback: Prefetch via Artifactory Docker API (manifest + blobs) using admin token
    local base_api="${JFROG_URL%/}/artifactory/api/docker/${PROJECT_KEY}-dockerhub-virtual/v2"
    local manifest_url="$base_api/${image_path}/manifests/$tag"
    local mf=$(mktemp)
    local code
    code=$(curl -sS -L -o "$mf" -w "%{http_code}" \
        -H "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
        -H "Accept: application/vnd.docker.distribution.manifest.v2+json, application/vnd.oci.image.manifest.v1+json" \
        "$manifest_url" 2>/dev/null || echo 000)
    if [[ "$code" -ge 200 && "$code" -lt 300 ]]; then
        # Fetch config and layers to warm cache
        local config_digest
        config_digest=$(jq -r '.config.digest // empty' "$mf" 2>/dev/null || echo "")
        if [[ -n "$config_digest" ]]; then
            curl -sS -L -o /dev/null -w "%{http_code}" \
                -H "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
                "$base_api/${image_path}/blobs/${config_digest}" >/dev/null 2>&1 || true
        fi
        local digests
        digests=$(jq -r '.layers[]?.digest // empty' "$mf" 2>/dev/null || echo "")
        if [[ -n "$digests" ]]; then
            while IFS= read -r d; do
                [[ -z "$d" ]] && continue
                curl -sS -L -o /dev/null -w "%{http_code}" \
                    -H "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
                    "$base_api/${image_path}/blobs/${d}" >/dev/null 2>&1 || true
            done <<< "$digests"
        fi
        rm -f "$mf"
        echo "✅ Prefetched $image:$tag via API"
        return 0
    else
        echo "⚠️ Manifest prefetch failed for $image:$tag (HTTP $code)"
        echo "⚠️ Warning: Could not cache Docker image $image:$tag"
        rm -f "$mf"
    fi
}

echo "=== Configuring JFrog CLI for dependency management ==="
jf c use bookverse-admin

# Configure secure Docker authentication for JFrog registry and virtual repositories
echo "🔐 Configuring secure Docker authentication..."

# Extract registry host from JFROG_URL
DOCKER_REG_HOST=$(echo "$JFROG_URL" | sed 's|https://||' | sed 's|http://||')
VIRTUAL_REPO_HOST="${DOCKER_REG_HOST}/${PROJECT_KEY}-dockerhub-virtual"

if command -v jf >/dev/null 2>&1; then
  # Method 1: Use JFrog CLI for secure authentication to virtual repository
  echo "Configuring authentication for Docker virtual repository..."
  
  # First ensure JFrog CLI is authenticated
  if jf rt ping >/dev/null 2>&1; then
    echo "✅ JFrog CLI authentication verified"
    
    # Use JFrog CLI's secure approach for Docker operations instead of direct docker commands
    echo "ℹ️ Using JFrog CLI for secure Docker operations"
    echo "ℹ️ This prevents unencrypted credential storage in ~/.docker/config.json"
    
    # Set up an environment variable to track that we should use JF CLI commands
    export USE_JF_DOCKER="true"
    
  else
    echo "❌ JFrog CLI authentication failed"
    echo "❌ Docker image caching will be limited"
    export USE_JF_DOCKER="false"
  fi
else
  echo "❌ JFrog CLI not available - Docker image caching will be skipped"
  export USE_JF_DOCKER="false"
fi

echo ""
echo "=== Pre-populating Python dependencies ==="

# Configure pip to resolve from the virtual repository
jf pipc --repo-resolve "${PROJECT_KEY}-pypi-virtual"

# Core Python CI tools
cache_python_package "pip" "24.2"

# Testing tools
cache_python_package "pytest" "7.4.3"
cache_python_package "pytest-cov" "4.1.0"
cache_python_package "httpx" "0.25.2"

# FastAPI ecosystem
cache_python_package "fastapi" "0.111.0"
cache_python_package "uvicorn" "0.30.0"
cache_python_package "pydantic" "2.5.0"
cache_python_package "sqlalchemy" "2.0.23"

# Security tools
cache_python_package "safety" "3.2.7"

# Code quality tools
cache_python_package "black" "23.9.1"
cache_python_package "isort" "5.12.0"
cache_python_package "mypy" "1.5.1"

echo ""
echo "=== Pre-populating npm dependencies ==="

# Configure npm to resolve from the virtual repository
jf npmc --repo-resolve "${PROJECT_KEY}-npm-virtual"

# Core npm tools
cache_npm_package "npm" "10.8.2"
cache_npm_package "yarn" "1.22.22"

# Frontend build tools
cache_npm_package "vite" "5.4.1"
cache_npm_package "typescript" "5.5.4"
cache_npm_package "@vitejs/plugin-react" "4.3.1"

# React ecosystem
cache_npm_package "react" "18.3.1"
cache_npm_package "react-dom" "18.3.1"
cache_npm_package "@types/react" "18.3.3"
cache_npm_package "@types/react-dom" "18.3.0"

# Testing tools
cache_npm_package "vitest" "2.0.5"
cache_npm_package "jsdom" "25.0.0"

# Security tools
cache_npm_package "audit-ci" "7.1.0"

echo ""
echo "=== Pre-populating Docker base images ==="

# Python base images
cache_docker_image "python" "3.11-slim"
cache_docker_image "python" "3.11-alpine"

# Node.js base images
cache_docker_image "node" "20-alpine"
cache_docker_image "node" "20-slim"

# Nginx for web frontend
cache_docker_image "nginx" "1.25-alpine"

# Utility images for CI/CD
cache_docker_image "alpine" "3.18"
cache_docker_image "ubuntu" "22.04"

echo ""
echo "✅ Dependency pre-population completed successfully!"
echo ""
echo "📋 Cached dependencies:"
echo "   🐍 Python: Core tools, FastAPI, testing, security, code quality"
echo "   📦 npm: Build tools, React, TypeScript, testing, security"
echo "   🐳 Docker: Base images for Python, Node.js, nginx, CI tools"
echo ""
echo "🔧 All services can now use dependencies from Artifactory repositories"
echo ""