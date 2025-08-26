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

# JFrog Platform Configuration
export JFROG_URL="${JFROG_URL:-https://evidencetrial.jfrog.io}"
export JFROG_ADMIN_TOKEN="${JFROG_ADMIN_TOKEN}"

# Repository Configuration
export DOCKER_INTERNAL_REPO="docker-internal"
export DOCKER_INTERNAL_PROD_REPO="docker-internal-prod"
export DOCKER_EXTERNAL_PROD_REPO="docker-external-prod"
export PYPI_LOCAL_REPO="pypi-local"

# Stage Configuration
export LOCAL_STAGES=("DEV" "QA" "STAGING")  # Local stages to create (PROD is always last)
export PROD_STAGE="PROD"                   # Production stage (always present, always last)

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

# Function to validate required environment variables
validate_environment() {
    local missing_vars=()
    
    if [[ -z "${JFROG_ADMIN_TOKEN}" ]]; then
        missing_vars+=("JFROG_ADMIN_TOKEN")
    fi
    
    if [[ -z "${JFROG_URL}" ]]; then
        missing_vars+=("JFROG_URL")
    fi
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        echo "❌ Error: Missing required environment variables:"
        printf '   - %s\n' "${missing_vars[@]}"
        echo ""
        echo "Please set these variables and try again."
        exit 1
    fi
}

# Function to display current configuration
show_config() {
    echo "🔧 Current BookVerse Configuration:"
    echo "   Project Key: ${PROJECT_KEY}"
    echo "   Project Name: ${PROJECT_DISPLAY_NAME}"
    echo "   JFrog URL: ${JFROG_URL}"
    echo "   Local Stages: ${LOCAL_STAGES[*]}"
    echo "   Production Stage: ${PROD_STAGE}"
    echo ""
}

# =============================================================================
# AUTO-LOAD CONFIGURATION
# =============================================================================
# This file is designed to be sourced by other scripts
# Usage: source .github/scripts/setup/config.sh
