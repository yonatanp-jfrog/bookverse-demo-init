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

# Function to pull and cache Docker images
cache_docker_image() {
    local image="$1"
    local tag="${2:-latest}"
    
    echo "🐳 Caching Docker image: $image:$tag"
    
    local docker_registry_host=$(echo "$JFROG_URL" | sed 's|https://||' | sed 's|http://||')
    local virtual_repo_path="${docker_registry_host}/${PROJECT_KEY}-dockerhub-virtual"
    
    # Pull through Artifactory virtual repository
    docker pull "${virtual_repo_path}/$image:$tag" > /dev/null 2>&1 || \
        echo "⚠️ Warning: Could not cache Docker image $image:$tag"
}

echo "=== Configuring JFrog CLI for dependency management ==="
jf c use bookverse-admin

# Ensure Docker is logged in to the JFrog registry for pulls via virtual repos
if command -v jf >/dev/null 2>&1; then
  jf rt docker-login >/dev/null 2>&1 || echo "⚠️ Warning: jf rt docker-login failed; Docker image caching may be skipped"
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