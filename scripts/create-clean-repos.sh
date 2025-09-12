#!/bin/bash
set -euo pipefail

# BookVerse Clean Repository Creation Script
# Creates individual service repositories with current code (fresh start approach)

ORG="${1:-yonatanp-jfrog}"
DRY_RUN="${2:-false}"

SERVICES=(
    "bookverse-inventory"
    "bookverse-recommendations" 
    "bookverse-checkout"
    "bookverse-platform"
    "bookverse-web"
    "bookverse-helm"
)

echo "🚀 Creating clean BookVerse service repositories"
echo "🏢 GitHub organization: $ORG"
echo "🧪 Dry run mode: $DRY_RUN"
echo ""

if [[ "$DRY_RUN" == "true" ]]; then
    echo "🔍 DRY RUN MODE - No actual changes will be made"
    echo ""
fi

# Create temporary workspace
TEMP_WORKSPACE=$(mktemp -d)
echo "📂 Temporary workspace: $TEMP_WORKSPACE"

for SERVICE in "${SERVICES[@]}"; do
    echo ""
    echo "🔄 Processing service: $SERVICE"
    
    # Check if service directory exists
    if [[ ! -d "$SERVICE" ]]; then
        echo "⚠️  Directory $SERVICE not found, skipping..."
        continue
    fi
    
    # Create service workspace
    SERVICE_WORKSPACE="$TEMP_WORKSPACE/$SERVICE"
    mkdir -p "$SERVICE_WORKSPACE"
    
    echo "📋 Step 1: Copying service files..."
    # Copy all service files (excluding .git and unnecessary files)
    rsync -av \
        --exclude='.git' \
        --exclude='.venv' \
        --exclude='__pycache__' \
        --exclude='*.pyc' \
        --exclude='node_modules' \
        --exclude='.pytest_cache' \
        --exclude='*.db' \
        "$SERVICE/" "$SERVICE_WORKSPACE/"
    
    # Initialize new git repository
    cd "$SERVICE_WORKSPACE"
    git init
    git branch -m main
    
    echo "📋 Step 2: Creating initial commit..."
    git add .
    git commit -m "Initial commit: $SERVICE service

- Migrated from monorepo structure
- Contains complete service code and workflows
- Ready for independent CI/CD operations"
    
    if [[ "$DRY_RUN" != "true" ]]; then
        echo "📋 Step 3: Creating GitHub repository..."
        if gh repo view "$ORG/$SERVICE" >/dev/null 2>&1; then
            echo "📦 Repository $ORG/$SERVICE already exists"
            read -p "🤔 Delete and recreate? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                gh repo delete "$ORG/$SERVICE" --yes
                gh repo create "$ORG/$SERVICE" --private --description "BookVerse $SERVICE service"
            else
                echo "⏭️  Skipping repository creation for $SERVICE"
                cd - >/dev/null
                continue
            fi
        else
            gh repo create "$ORG/$SERVICE" --private --description "BookVerse $SERVICE service"
        fi
        
        echo "📋 Step 4: Pushing to GitHub..."
        git remote add origin "git@github.com:$ORG/$SERVICE.git"
        git push -u origin main
        
        echo "✅ Successfully created $ORG/$SERVICE"
        echo "🌐 View at: https://github.com/$ORG/$SERVICE"
    else
        echo "🔍 DRY RUN: Would create repository $ORG/$SERVICE"
        echo "📁 Files that would be included:"
        find . -type f -name "*.yml" -o -name "*.yaml" -o -name "*.py" -o -name "*.js" -o -name "*.md" | head -10
        if [[ $(find . -type f | wc -l) -gt 10 ]]; then
            echo "   ... and $(($(find . -type f | wc -l) - 10)) more files"
        fi
    fi
    
    cd - >/dev/null
done

echo ""
if [[ "$DRY_RUN" != "true" ]]; then
    echo "🎉 Repository creation complete!"
    echo ""
    echo "📋 Next steps:"
    echo "1. 🔧 Set up repository variables for each service"
    echo "2. 🔑 Set up repository secrets"  
    echo "3. 🔗 Configure OIDC providers"
    echo "4. 🧪 Test CI workflows"
    echo "5. 🧹 Clean up monorepo duplicate workflows"
else
    echo "🔍 Dry run complete - no repositories were created"
    echo "Run without 'true' as second argument to create repositories"
fi

echo ""
read -p "🧹 Clean up temp workspace? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -rf "$TEMP_WORKSPACE"
    echo "🗑️  Cleaned up temporary workspace"
else
    echo "📁 Preserved workspace: $TEMP_WORKSPACE"
fi
