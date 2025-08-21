#!/usr/bin/env bash

set -e

echo "🚀 BookVerse JFrog Platform Initialization - Local Runner"
echo "========================================================"
echo ""

# Check if required environment variables are set
if [[ -z "${JFROG_URL}" ]]; then
  echo "❌ Error: JFROG_URL is not set"
  echo "   Please export JFROG_URL='your-jfrog-instance-url'"
  exit 1
fi

if [[ -z "${JFROG_ADMIN_TOKEN}" ]]; then
  echo "❌ Error: JFROG_ADMIN_TOKEN is not set"
  echo "   Please export JFROG_ADMIN_TOKEN='your-admin-token'"
  exit 1
fi

echo "✅ Environment variables validated"
echo "   JFROG_URL: ${JFROG_URL}"
echo "   JFROG_ADMIN_TOKEN: [HIDDEN]"
echo ""

# Source global configuration
source ./.github/scripts/setup/config.sh

echo "📋 Configuration loaded:"
echo "   Project Key: ${PROJECT_KEY}"
echo "   Project Display Name: ${PROJECT_DISPLAY_NAME}"
echo ""

echo "🔄 Starting initialization sequence..."
echo ""

# Step 1: Create Project
echo "📁 Step 1/6: Creating Project..."
./.github/scripts/setup/create_project.sh
echo ""

# Step 2: Create Repositories
echo "📦 Step 2/6: Creating Repositories..."
./.github/scripts/setup/create_repositories.sh
echo ""

# Step 3: Create AppTrust Stages
echo "🎭 Step 3/6: Creating AppTrust Stages..."
./.github/scripts/setup/create_stages.sh
echo ""

# Step 4: Create Users
echo "👥 Step 4/6: Creating Users..."
./.github/scripts/setup/create_users.sh
echo ""

# Step 5: Create Applications
echo "📱 Step 5/6: Creating Applications..."
./.github/scripts/setup/create_applications.sh
echo ""

# Step 6: Create OIDC Integrations
echo "🔐 Step 6/6: Creating OIDC Integrations..."
./.github/scripts/setup/create_oidc.sh
echo ""

echo "🎉 BookVerse JFrog Platform initialization completed successfully!"
echo ""
echo "📊 Summary of what was created:"
echo "   ✅ Project: ${PROJECT_KEY}"
echo "   ✅ Repositories: 16 (4 microservices × 2 package types × 2 stages)"
echo "   ✅ AppTrust Stages: DEV, QA, STAGE, PROD"
echo "   ✅ Users: 12 (8 human + 4 pipeline)"
echo "   ✅ Applications: 4 microservices + 1 platform"
echo "   ✅ OIDC Integrations: 4 (one per microservice team)"
echo ""
echo "🚀 Your BookVerse platform is ready for development!"
echo "💡 Next steps: Configure GitHub Actions secrets and run the workflow"
