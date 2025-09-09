#!/usr/bin/env bash

# =============================================================================
# GLOBAL CONFIGURATION FOR BOOKVERSE WORKSPACE
# =============================================================================
# This file contains global variables that are used across all setup scripts
# Modify these values to customize your BookVerse setup
# =============================================================================

# Project Configuration
export PROJECT_KEY="bookverse"
export PROJECT_DISPLAY_NAME="BookVerse"

# JFrog Platform Configuration (required)
if [[ -z "${JFROG_URL:-}" ]]; then
  echo "JFROG_URL is required (no default)." >&2
  exit 2
fi
export JFROG_URL
export JFROG_ADMIN_TOKEN="${JFROG_ADMIN_TOKEN}"

# Repository Configuration
export DOCKER_INTERNAL_REPO="docker-internal"
export DOCKER_INTERNAL_PROD_REPO="docker-internal-prod"
export DOCKER_EXTERNAL_PROD_REPO="docker-external-prod"
export PYPI_LOCAL_REPO="pypi-local"

# Stage Configuration
export NON_PROD_STAGES=("DEV" "QA" "STAGING")  # Non-production stages to create (PROD is global)
export PROD_STAGE="PROD"                       # Production stage (global, not project-specific)

# API and Integration Constants
export GITHUB_ACTIONS_ISSUER_URL="https://token.actions.githubusercontent.com/"
export JFROG_CLI_SERVER_ID="bookverse-admin"
export DEFAULT_RSA_KEY_SIZE=2048
export DEFAULT_API_RETRIES=3
export API_TIMEOUT=30

# Temporary Directory Configuration
export TEMP_DIR_PREFIX="bookverse_cleanup"
export CACHE_TTL_SECONDS=300  # 5 minutes cache for API responses

# =============================================================================
# HELPER FUNCTIONS - MOVED TO common.sh
# =============================================================================
# Note: validate_environment() and show_config() functions have been
# consolidated into common.sh to eliminate duplication

# =============================================================================
# AUTO-LOAD CONFIGURATION
# =============================================================================
# This file is designed to be sourced by other scripts
# Usage: source .github/scripts/setup/config.sh
