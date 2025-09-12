#!/bin/bash
set -euo pipefail

# Simple BookVerse Repository Split
# Creates one service repository at a time

SERVICE="$1"
ORG="yonatanp-jfrog"

echo "🚀 Creating repository for: $SERVICE"

# Create temp workspace
TEMP_DIR=$(mktemp -d)
echo "📂 Using temp: $TEMP_DIR"

# Copy service (excluding large unnecessary files)
cp -r "$SERVICE" "$TEMP_DIR/"
cd "$TEMP_DIR/$SERVICE"

# Remove unnecessary files
find . -name ".venv" -type d -exec rm -rf {} + 2>/dev/null || true
find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
find . -name "*.pyc" -delete 2>/dev/null || true
find . -name "*.db" -delete 2>/dev/null || true
find . -name "node_modules" -type d -exec rm -rf {} + 2>/dev/null || true

# Initialize git
git init
git branch -m main
git add .
git commit -m "Initial commit: $SERVICE service

- Migrated from monorepo structure
- Contains complete service code and workflows
- Ready for independent CI/CD operations"

# Create GitHub repo (delete if exists)
echo "📋 Creating GitHub repository..."
gh repo delete "$ORG/$SERVICE" --yes 2>/dev/null || true
gh repo create "$ORG/$SERVICE" --private --description "BookVerse $SERVICE service"

# Push to GitHub
git remote remove origin 2>/dev/null || true
git remote add origin "git@github.com:$ORG/$SERVICE.git"
git push -u origin main

echo "✅ Successfully created: https://github.com/$ORG/$SERVICE"

# Cleanup
cd /
rm -rf "$TEMP_DIR"
echo "🗑️  Cleaned up temp directory"
