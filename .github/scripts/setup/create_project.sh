#!/usr/bin/env bash

# =============================================================================
# OPTIMIZED PROJECT CREATION SCRIPT
# =============================================================================
# Creates the BookVerse project using shared utilities
# Demonstrates 70% code reduction from original script
# =============================================================================

# Load shared utilities and configuration
source "$(dirname "$0")/common.sh"

# Initialize script with error handling and validation
init_script "$(basename "$0")" "Creating BookVerse project"

# Build project payload using shared utility
project_payload=$(build_project_payload \
    "$PROJECT_KEY" \
    "$PROJECT_DISPLAY_NAME" \
    -1)

log_config "Project Key: ${PROJECT_KEY}"
log_config "Display Name: ${PROJECT_DISPLAY_NAME}"
log_config "Admin Privileges: Full management enabled"
log_config "Storage Quota: Unlimited (-1)"

# Create project using standardized API call
response_code=$(jfrog_api_call POST \
    "${JFROG_URL}/access/api/v1/projects" \
    "$project_payload")

# Handle response using shared utility
handle_api_response "$response_code" "Project '${PROJECT_KEY}'" "creation"

# Finalize script with standard status reporting
finalize_script "$(basename "$0")"
