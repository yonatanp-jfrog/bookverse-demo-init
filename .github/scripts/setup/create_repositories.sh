#!/bin/bash
set -e

# Source global configuration
source "$(dirname "$0")/config.sh"

echo "Creating repositories in BookVerse project..."
echo "Project Key: ${PROJECT_KEY}"
echo ""

# Define repository types and keys using global config
REPOS=(
    "docker:${DOCKER_INTERNAL_REPO}"
    "docker:${DOCKER_INTERNAL_PROD_REPO}"
    "docker:${DOCKER_EXTERNAL_PROD_REPO}"
    "pypi:${PYPI_LOCAL_REPO}"
)

for repo in "${REPOS[@]}"; do
    TYPE="${repo%%:*}"
    KEY="${repo#*:}"
    echo "Creating ${TYPE} repo: ${KEY}"
    jf rt repo-create "{\"key\":\"${KEY}\",\"type\":\"${TYPE}\",\"projectKey\":\"${PROJECT_KEY}\"}" --project="${PROJECT_KEY}"
done

echo "✅ All repositories created successfully!"
