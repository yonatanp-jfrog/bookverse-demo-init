#!/bin/bash
set -euo pipefail

# Fix and push all BookVerse service repositories

SERVICES=(
    "bookverse-recommendations"
    "bookverse-checkout"
    "bookverse-platform"
    "bookverse-web"
    "bookverse-helm"
)

echo "🔧 Fixing and pushing all BookVerse service repositories"
echo ""

for SERVICE in "${SERVICES[@]}"; do
    echo "🔄 Processing: $SERVICE"
    
    TEMP_DIR=$(mktemp -d)
    echo "📂 Using temp: $TEMP_DIR"
    
    # Copy service files
    cp -r "$SERVICE" "$TEMP_DIR/"
    cd "$TEMP_DIR/$SERVICE"
    
    # Clean up unnecessary files
    find . -name ".venv" -type d -exec rm -rf {} + 2>/dev/null || true
    find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
    find . -name "*.pyc" -delete 2>/dev/null || true
    find . -name "*.db" -delete 2>/dev/null || true
    find . -name "node_modules" -type d -exec rm -rf {} + 2>/dev/null || true
    
    # Initialize git and commit
    git init
    git branch -m main
    git add .
    git commit -m "Initial commit: $SERVICE service

- Migrated from monorepo structure
- Contains complete service code and workflows
- Ready for independent CI/CD operations"
    
    # Push to GitHub
    git remote remove origin 2>/dev/null || true
    git remote add origin "git@github.com:yonatanp-jfrog/$SERVICE.git"
    git push -u origin main
    
    echo "✅ Successfully pushed: https://github.com/yonatanp-jfrog/$SERVICE"
    
    # Cleanup
    cd /
    rm -rf "$TEMP_DIR"
    
    echo ""
done

echo "🎉 All repositories fixed and pushed successfully!"
