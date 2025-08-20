#!/bin/bash
set -e
echo "Creating repositories in BookVerse project..."
REPOS=( "docker:docker-internal" "docker:docker-internal-prod" "docker:docker-external-prod" "pypi:pypi-local" )
for repo in "${REPOS[@]}"; do
    TYPE="${repo%%:*}"
    KEY="${repo#*:}"
    echo "Creating ${TYPE} repo: ${KEY}"
    jf rt repo-create "{\"key\":\"${KEY}\",\"type\":\"${TYPE}\",\"projectKey\":\"bookverse\"}" --project=bookverse
done
