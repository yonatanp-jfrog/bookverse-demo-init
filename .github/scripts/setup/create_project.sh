#!/usr/bin/env bash
# =============================================================================
# BookVerse Platform - Setup Automation - JFrog Project Creation
# =============================================================================
#
# Creates and configures the foundational JFrog project for the BookVerse platform
#
# 🎯 PURPOSE:
#     This script creates the core JFrog project that serves as the foundation for all
#     BookVerse platform operations. The project acts as a logical container for
#     repositories, applications, lifecycle stages, and security policies, enabling
#     centralized management and governance of the entire platform ecosystem.
#
# 🏗️ ARCHITECTURE:
#     - Project Creation: Establishes project with unlimited storage and full privileges
#     - Admin Configuration: Configures management permissions for complete platform control
#     - API Integration: Uses JFrog Access API for project provisioning and validation
#     - Idempotent Operations: Safely handles repeated execution without duplicate creation
#     - Error Recovery: Comprehensive error handling with detailed failure diagnostics
#
# 🚀 KEY FEATURES:
#     - Automated project creation with standardized configuration
#     - Unlimited storage quota configuration for enterprise-scale operations
#     - Full administrative privileges enabling complete platform management
#     - Conflict detection and resolution for existing projects
#     - Comprehensive logging and status reporting throughout the creation process
#
# 📊 BUSINESS LOGIC:
#     - Platform Foundation: Establishes the organizational structure for all BookVerse resources
#     - Resource Management: Enables centralized governance and policy enforcement
#     - Team Collaboration: Provides shared workspace for development and operations teams
#     - Enterprise Compliance: Supports audit trails and access control requirements
#     - Operational Excellence: Standardizes project configuration across environments
#
# 🔧 USAGE PATTERNS:
#     - Initial Setup: First step in complete platform provisioning workflow
#     - Environment Creation: Foundation for DEV, QA, STAGING, and PROD environments
#     - Disaster Recovery: Project recreation for backup and restore operations
#     - Infrastructure as Code: Automated project provisioning in CI/CD pipelines
#     - Multi-tenancy: Template for creating additional projects for different teams
#
# ⚙️ PARAMETERS:
#     [Environment Variables - Required]
#     PROJECT_KEY           : Unique project identifier (e.g., "bookverse")
#     PROJECT_DISPLAY_NAME  : Human-readable project name (e.g., "BookVerse Platform")
#     JFROG_URL            : JFrog Platform URL (e.g., https://company.jfrog.io)
#     JFROG_ADMIN_TOKEN    : JFrog admin token with project creation privileges
#
# 🌍 ENVIRONMENT VARIABLES:
#     [Required Configuration]
#     PROJECT_KEY           : Project identifier used throughout the platform
#     PROJECT_DISPLAY_NAME  : Display name shown in JFrog Platform UI
#     JFROG_URL            : Base URL for JFrog Platform API access
#     JFROG_ADMIN_TOKEN    : Admin token with sufficient privileges for project operations
#     
#     [Auto-Configured]
#     STORAGE_QUOTA        : Set to unlimited (-1) for enterprise operations
#     ADMIN_PRIVILEGES     : Enabled for complete platform management capabilities
#
# 📋 PREREQUISITES:
#     [System Requirements]
#     - bash (4.0+): Advanced shell features for array and JSON processing
#     - curl: HTTP API communication with JFrog Platform
#     - jq: JSON payload construction and response processing
#     
#     [Access Requirements]
#     - JFrog Platform admin privileges: Required for project creation operations
#     - Network connectivity: HTTPS access to JFrog Platform APIs
#     - Valid admin token: Token must have project creation and management permissions
#     
#     [Configuration Prerequisites]
#     - config.sh: Configuration file with project and platform settings loaded
#     - common.sh: Shared utility functions and error handling framework
#
# 📤 OUTPUTS:
#     [Return Codes]
#     0: Success - Project created successfully or already exists
#     1: API Error - JFrog Platform API communication failure
#     2: Environment Error - Missing required environment variables or configuration
#     
#     [Generated Resources]
#     - JFrog Project: Created with specified key and display name
#     - Admin Privileges: Full management capabilities enabled
#     - Storage Configuration: Unlimited storage quota configured
#     
#     [Logging Output]
#     - Project configuration details for verification
#     - API response status and validation results
#     - Success confirmation with project details
#
# 💡 EXAMPLES:
#     [Basic Usage]
#     ./create_project.sh
#     
#     [CI/CD Integration]
#     - name: Create BookVerse Project
#       run: ./.github/scripts/setup/create_project.sh
#       env:
#         PROJECT_KEY: bookverse
#         PROJECT_DISPLAY_NAME: "BookVerse Platform"
#         JFROG_URL: ${{ vars.JFROG_URL }}
#         JFROG_ADMIN_TOKEN: ${{ secrets.JFROG_ADMIN_TOKEN }}
#     
#     [Local Development]
#     export PROJECT_KEY="bookverse-dev"
#     export PROJECT_DISPLAY_NAME="BookVerse Development"
#     ./create_project.sh
#
# ⚠️ ERROR HANDLING:
#     [Common Failure Modes]
#     - Missing Environment Variables: Validates all required configuration before execution
#     - Invalid Admin Token: Verifies token permissions and platform connectivity
#     - Project Already Exists: Handles conflicts gracefully with appropriate logging
#     - Network Connectivity: Provides clear diagnostics for API communication failures
#     
#     [Recovery Procedures]
#     - Environment Validation: Check config.sh and environment variable configuration
#     - Token Verification: Ensure admin token has project creation privileges
#     - Platform Connectivity: Verify JFrog Platform accessibility and API availability
#     - Conflict Resolution: Existing projects are detected and reported as success
#
# 🔍 DEBUGGING:
#     [Debug Mode]
#     DEBUG=true ./create_project.sh    # Enable detailed debug output
#     
#     [Verification Steps]
#     1. Check JFrog Platform UI for created project
#     2. Verify project configuration matches specified parameters
#     3. Confirm admin privileges are properly configured
#     4. Test project accessibility with provided credentials
#     
#     [Common Issues]
#     - Insufficient Permissions: Ensure admin token has project creation rights
#     - Invalid Project Key: Verify project key format meets JFrog requirements
#     - Platform Connectivity: Check network access and JFrog Platform availability
#
# 🔗 INTEGRATION POINTS:
#     [Dependent Scripts]
#     - create_repositories.sh: Creates repositories within the project
#     - create_applications.sh: Sets up AppTrust applications in the project
#     - create_stages.sh: Configures lifecycle stages for the project
#     - create_oidc.sh: Establishes OIDC authentication for the project
#     
#     [External Services]
#     - JFrog Access API: Project creation and management operations
#     - JFrog Platform UI: Visual confirmation and management interface
#     - CI/CD Pipelines: Automated project provisioning workflows
#
# 📊 PERFORMANCE:
#     [Execution Time]
#     - Typical Runtime: 2-5 seconds for project creation
#     - Network Latency: Dependent on JFrog Platform response times
#     - Conflict Detection: Sub-second for existing project validation
#     
#     [Resource Usage]
#     - CPU: Minimal - basic JSON processing and HTTP operations
#     - Memory: Minimal - small JSON payloads and response processing
#     - Network: Single HTTPS POST request to JFrog Platform API
#
# 🛡️ SECURITY CONSIDERATIONS:
#     [Credential Security]
#     - Admin token passed via environment variables only
#     - No credential logging or exposure in output streams
#     - Secure HTTPS communication with JFrog Platform APIs
#     
#     [Access Control]
#     - Requires admin-level privileges for project creation
#     - Project configured with full management capabilities
#     - Audit trail maintained through JFrog Platform logging
#
# 📚 REFERENCES:
#     [Documentation]
#     - JFrog Projects API: https://jfrog.com/help/r/jfrog-rest-apis/projects
#     - BookVerse Setup Guide: ../docs/SETUP_AUTOMATION.md
#     - Common Utilities: ./common.sh function documentation
#     
#     [Related Scripts]
#     - validate_environment.sh: Environment validation and verification
#     - config.sh: Configuration file with project settings
#
# Authors: BookVerse Platform Team
# Version: 1.0.0
# Last Updated: 2024-01-01
# =============================================================================

# Import shared utilities and error handling framework
source "$(dirname "$0")/common.sh"

# Initialize script with comprehensive error handling and environment validation
init_script "$(basename "$0")" "Creating BookVerse project"

# Construct JSON payload for project creation using standardized template
# Configures project with unlimited storage and full administrative privileges
project_payload=$(build_project_payload \
    "$PROJECT_KEY" \
    "$PROJECT_DISPLAY_NAME" \
    -1)  # -1 indicates unlimited storage quota for enterprise operations

# Display project configuration for verification and audit trail
log_config "Project Key: ${PROJECT_KEY}"
log_config "Display Name: ${PROJECT_DISPLAY_NAME}"
log_config "Admin Privileges: Full management enabled"
log_config "Storage Quota: Unlimited (-1)"

# Execute project creation via JFrog Access API with error handling
response_code=$(jfrog_api_call POST \
    "${JFROG_URL}/access/api/v1/projects" \
    "$project_payload")

# Process API response and handle success, conflict, or error conditions
handle_api_response "$response_code" "Project '${PROJECT_KEY}'" "creation"

# Finalize script execution with success/failure reporting
finalize_script "$(basename "$0")"
