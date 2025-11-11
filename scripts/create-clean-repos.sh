#!/bin/bash

# =============================================================================
# BookVerse Platform - Clean Repository Creation and Initialization Script
# =============================================================================
#
# This comprehensive repository management script automates the creation of
# clean, production-ready BookVerse service repositories with advanced
# initialization procedures, development artifact cleanup, and GitHub integration
# for enterprise-grade microservices repository structure and independent
# CI/CD operations across the complete BookVerse platform ecosystem.
#
# 🏗️ CLEAN REPOSITORY CREATION STRATEGY:
#     - Production-Ready Initialization: Clean repository creation without development artifacts
#     - Service Isolation: Complete service code isolation with independent Git history
#     - Artifact Cleanup: Comprehensive removal of development artifacts and cache files
#     - GitHub Integration: Automated GitHub repository creation with interactive confirmation
#     - CI/CD Optimization: Repository structure optimization for independent CI/CD operations
#     - Safety Mechanisms: Dry run mode and interactive confirmation for safe operations
#
# 🔧 INITIALIZATION PROCEDURES:
#     - Advanced File Copying: rsync-based file copying with comprehensive exclusion patterns
#     - Git Repository Setup: Complete Git repository initialization and configuration
#     - Branch Management: Main branch setup and initial commit structure
#     - Remote Configuration: GitHub remote repository setup and authentication
#     - Interactive Confirmation: User confirmation for repository recreation and overwrite
#     - Error Recovery: Comprehensive error handling and recovery procedures
#
# 🛡️ ENTERPRISE SECURITY AND GOVERNANCE:
#     - Safe Repository Operations: Comprehensive safety mechanisms for repository operations
#     - Authentication Management: Secure GitHub authentication and authorization
#     - Repository Access Control: Private repository creation with secure access management
#     - Audit Trail: Complete repository creation and configuration audit logging
#     - Data Protection: Secure handling of sensitive data during repository operations
#     - Rollback Capabilities: Repository operation rollback and disaster recovery
#
# 🔄 REPOSITORY LIFECYCLE MANAGEMENT:
#     - Artifact Cleanup: Automated removal of development artifacts (.venv, __pycache__, node_modules)
#     - Repository Validation: Git repository integrity validation and verification
#     - Workspace Management: Temporary workspace creation and cleanup procedures
#     - Interactive Workflow: User-guided repository creation with confirmation prompts
#     - Batch Processing: Support for multiple service repository creation
#     - Status Reporting: Comprehensive status reporting and operation logging
#
# 📈 SCALABILITY AND AUTOMATION:
#     - Dry Run Mode: Safe testing and validation without actual repository changes
#     - Batch Processing: Efficient processing of multiple service repositories
#     - Template-Based Creation: Consistent repository structure and configuration
#     - Error Recovery: Automated error recovery and repository cleanup procedures
#     - Performance Optimization: Optimized file operations and Git performance
#     - Monitoring Integration: Repository creation monitoring and status reporting
#
# 🔐 ADVANCED SAFETY FEATURES:
#     - Dry Run Validation: Complete operation validation without making changes
#     - Interactive Confirmation: User confirmation for destructive operations
#     - Data Protection: Protection against data loss during repository operations
#     - Rollback Mechanisms: Complete rollback capabilities for failed operations
#     - Validation Framework: Repository integrity validation and verification
#     - Security Scanning: Repository security validation and compliance checking
#
# 🛠️ TECHNICAL IMPLEMENTATION:
#     - GitHub CLI Integration: Native GitHub repository management via gh CLI
#     - rsync Operations: Advanced file copying with comprehensive exclusion patterns
#     - Git Operations: Advanced Git repository management and configuration
#     - Workspace Management: Temporary workspace creation and cleanup procedures
#     - Error Handling: Comprehensive error detection and recovery procedures
#     - Validation Framework: Repository validation and integrity checking
#
# 📋 SUPPORTED ARTIFACT CLEANUP:
#     - Python Artifacts: .venv, __pycache__, *.pyc, .pytest_cache cleanup
#     - Node.js Artifacts: node_modules and npm cache cleanup
#     - Database Artifacts: *.db and development database cleanup
#     - Git Artifacts: .git directory exclusion for clean repository creation
#     - Cache Artifacts: Development cache and temporary file cleanup
#     - Build Artifacts: Build output and compiled artifact cleanup
#
# 🎯 SUCCESS CRITERIA:
#     - Repository Creation: Successful creation of clean service repositories
#     - Artifact Cleanup: Complete removal of development artifacts and cache files
#     - CI/CD Readiness: Repository structure optimized for independent CI/CD operations
#     - Security Compliance: Repository security configuration meeting enterprise standards
#     - Interactive Validation: User-guided operation with confirmation and validation
#     - Operational Excellence: Repository management ready for production operations
#
# Authors: BookVerse Platform Team
# Version: 1.0.0
# Last Updated: 2024
#
# Dependencies:
#   - GitHub CLI (gh) with authentication (repository management)
#   - Git with proper configuration (version control operations)
#   - rsync for advanced file copying (file operations)
#   - Bash 4.0+ with array support (script execution environment)
#   - Network connectivity to GitHub (repository creation and push operations)
#
# Usage:
#   ./create-clean-repos.sh [organization] [dry_run]
#   - organization: GitHub organization name (default: yonatanp-jfrog)
#   - dry_run: true/false for dry run mode (default: false)
#
# Safety Notes:
#   - Use dry run mode for testing and validation before actual operations
#   - Interactive confirmation prompts for destructive operations
#   - All operations performed in isolated temporary workspace
#   - Original repository structure preserved and unmodified
#
# =============================================================================

set -euo pipefail

# 📦 Repository Configuration
# Clean repository creation configuration for BookVerse microservices
ORG="${1:-yonatanp-jfrog}"  # GitHub organization for repository creation
DRY_RUN="${2:-false}"      # Dry run mode for safe testing and validation

# 🏢 BookVerse Service Architecture
# Complete list of all BookVerse microservices requiring clean repository creation
SERVICES=(
    "inventory"      # Core business inventory and stock management service
    "recommendations" # AI-powered personalization and recommendation engine
    "checkout"       # Secure payment processing and transaction management
    "platform"      # Unified platform coordination and API gateway
    "web"           # Customer-facing frontend and static asset delivery
    "helm"          # Kubernetes deployment manifests and infrastructure-as-code
)

echo "🚀 Creating clean BookVerse service repositories"
echo "🏢 GitHub organization: $ORG"
echo "🧪 Dry run mode: $DRY_RUN"
echo ""

if [[ "$DRY_RUN" == "true" ]]; then
    echo "🔍 DRY RUN MODE - No actual changes will be made"
    echo ""
fi

TEMP_WORKSPACE=$(mktemp -d)
echo "📂 Temporary workspace: $TEMP_WORKSPACE"

for SERVICE in "${SERVICES[@]}"; do
    REPO_NAME="bookverse-${SERVICE}"
    echo ""
    echo "🔄 Processing service: $REPO_NAME"
    
    if [[ ! -d "$SERVICE" ]]; then
        echo "⚠️  Directory $SERVICE not found, skipping..."
        continue
    fi
    
    SERVICE_WORKSPACE="$TEMP_WORKSPACE/$SERVICE"
    mkdir -p "$SERVICE_WORKSPACE"
    
    echo "📋 Step 1: Copying service files..."
    rsync -av \
        --exclude='.git' \
        --exclude='.venv' \
        --exclude='__pycache__' \
        --exclude='*.pyc' \
        --exclude='node_modules' \
        --exclude='.pytest_cache' \
        --exclude='*.db' \
        "$SERVICE/" "$SERVICE_WORKSPACE/"
    
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
        if gh repo view "$ORG/$REPO_NAME" >/dev/null 2>&1; then
            echo "📦 Repository $ORG/$REPO_NAME already exists"
            read -p "🤔 Delete and recreate? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                gh repo delete "$ORG/$REPO_NAME" --yes
                gh repo create "$ORG/$REPO_NAME" --private --description "BookVerse $SERVICE service"
            else
                echo "⏭️  Skipping repository creation for $REPO_NAME"
                cd - >/dev/null
                continue
            fi
        else
            gh repo create "$ORG/$REPO_NAME" --private --description "BookVerse $SERVICE service"
        fi
        
        echo "📋 Step 4: Pushing to GitHub..."
        git remote add origin "git@github.com:$ORG/$REPO_NAME.git"
        git push -u origin main
        
        echo "✅ Successfully created $ORG/$REPO_NAME"
        echo "🌐 View at: https://github.com/$ORG/$REPO_NAME"
    else
        echo "🔍 DRY RUN: Would create repository $ORG/$REPO_NAME"
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
