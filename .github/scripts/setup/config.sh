#!/usr/bin/env bash

# =============================================================================
# BookVerse Platform - Centralized Configuration Management Script
# =============================================================================
#
# This critical configuration script provides centralized environment variable
# management and platform-wide configuration standards for the BookVerse
# ecosystem, implementing enterprise-grade configuration governance, security
# best practices, and operational consistency across all setup automation
# scripts and deployment operations.
#
# 🔧 CONFIGURATION MANAGEMENT STRATEGY:
#     - Centralized Configuration: Single source of truth for all platform configuration
#     - Environment Variable Standards: Consistent naming and structure across all scripts
#     - Security Configuration: Secure credential management and API authentication
#     - Repository Management: Standardized artifact repository configuration and access
#     - Lifecycle Stage Management: Environment promotion and deployment stage definitions
#     - Integration Standards: GitHub Actions, JFrog Platform, and OIDC configuration
#
# 📊 PLATFORM CONFIGURATION DOMAINS:
#     - Project Identity: Core project identification and branding configuration
#     - JFrog Platform: Complete JFrog Platform integration and authentication
#     - Repository Management: Artifact repository organization and access patterns
#     - Environment Stages: Deployment lifecycle and promotion stage definitions
#     - Security Integration: OIDC authentication and cryptographic configuration
#     - Operational Parameters: API timeouts, retry logic, and performance tuning
#
# 🛡️ SECURITY AND COMPLIANCE CONFIGURATION:
#     - Credential Management: Secure handling of authentication tokens and API keys
#     - OIDC Integration: GitHub Actions OpenID Connect authentication configuration
#     - Repository Security: Secure artifact repository access and permission management
#     - Cryptographic Standards: RSA key size and security algorithm configuration
#     - API Security: Timeout and retry configuration for secure API operations
#     - Audit Trail: Configuration change tracking and compliance documentation
#
# 🚀 USAGE PATTERNS AND INTEGRATION:
#     - Script Sourcing: Universal configuration import for all setup scripts
#     - Environment Validation: Required configuration validation and error handling
#     - Cross-Script Consistency: Standardized configuration across all automation
#     - Dynamic Configuration: Runtime configuration validation and adjustment
#     - Error Recovery: Configuration failure detection and recovery procedures
#     - Documentation Standards: Inline documentation for all configuration variables
#
# 📋 CONFIGURATION VARIABLES DOCUMENTATION:
#     - PROJECT_KEY: Core project identifier used throughout BookVerse platform
#     - JFROG_URL: JFrog Platform endpoint for artifact management and AppTrust integration
#     - Repository Configuration: Docker and PyPI repository naming and organization
#     - Stage Definitions: Environment promotion lifecycle and deployment targets
#     - Security Parameters: OIDC configuration and cryptographic standards
#     - Operational Tuning: API timeouts, retry logic, and performance optimization
#
# 🔐 SECURITY CONSIDERATIONS:
#     - Token Management: Secure environment variable handling for authentication tokens
#     - Validation Logic: Required configuration validation and security verification
#     - Error Handling: Secure error reporting without credential exposure
#     - Access Control: Configuration-based role and permission management
#     - Audit Compliance: Configuration change logging and compliance tracking
#     - Credential Rotation: Support for credential rotation and security updates
#
# 🛠️ OPERATIONAL EXCELLENCE:
#     - Default Values: Sensible defaults for operational and security parameters
#     - Error Detection: Comprehensive validation for required configuration
#     - Performance Tuning: API timeout and retry configuration for optimal performance
#     - Cache Management: Temporary directory and cache configuration for efficiency
#     - Monitoring Integration: Configuration for observability and alerting systems
#     - Change Management: Configuration versioning and change control procedures
#
# 📈 SCALABILITY AND MAINTENANCE:
#     - Environment Scaling: Configuration support for multi-environment deployments
#     - Repository Scaling: Artifact repository organization for growth and expansion
#     - Security Scaling: Cryptographic and authentication configuration for enterprise scale
#     - Performance Scaling: API and operational parameter tuning for high-volume operations
#     - Compliance Scaling: Configuration management for regulatory and audit requirements
#     - Integration Scaling: Configuration standards for new service and tool integration
#
# Authors: BookVerse Platform Team
# Version: 1.0.0
# Last Updated: 2024
#
# Dependencies:
#   - Environment Variables: JFROG_URL, JFROG_ADMIN_TOKEN (required)
#   - Shell Environment: Bash 4.0+ with array support
#   - Network Access: Connectivity to JFrog Platform and GitHub Actions
#
# Security Notes:
#   - Never commit authentication tokens to version control
#   - Use environment variables or secure secret management for credentials
#   - Validate all configuration values before use in production operations
#   - Follow principle of least privilege for token and API access permissions
#
# =============================================================================

# 🏷️ Core Project Identity Configuration
# These variables define the fundamental project identification used throughout
# the BookVerse platform for consistent naming and branding across all systems

# Support for multiple instances with optional prefix
PROJECT_PREFIX="${PROJECT_PREFIX:-}"      # Optional prefix for multi-instance support (from environment)
if [[ -n "${PROJECT_PREFIX}" ]]; then
    export PROJECT_KEY="${PROJECT_PREFIX}-bookverse"  # Primary project identifier with prefix
    export PROJECT_DISPLAY_NAME="${PROJECT_PREFIX} BookVerse"  # Human-readable project name with prefix
else
    export PROJECT_KEY="bookverse"           # Primary project identifier for all platform operations
    export PROJECT_DISPLAY_NAME="BookVerse"  # Human-readable project name for UI and documentation
fi

# 🔗 JFrog Platform Integration Configuration
# Critical configuration for JFrog Platform connectivity and authentication
# JFROG_URL is required and must be provided via environment variable for security
if [[ -z "${JFROG_URL:-}" ]]; then
  echo "❌ JFROG_URL is required (no default provided for security)" >&2
  echo "   Please set JFROG_URL environment variable with your JFrog Platform endpoint" >&2
  exit 2
fi
export JFROG_URL                                    # JFrog Platform endpoint URL (required)
export JFROG_ADMIN_TOKEN="${JFROG_ADMIN_TOKEN}"    # Admin authentication token (required)

# 📦 Repository Management Configuration
# Standardized artifact repository organization and naming conventions
# for Docker containers, Python packages, and multi-environment deployment
export DOCKER_INTERNAL_REPO="docker-internal"           # Internal Docker repository for development and staging
export DOCKER_INTERNAL_PROD_REPO="docker-internal-prod" # Production Docker repository for internal services
export DOCKER_EXTERNAL_PROD_REPO="docker-external-prod" # Production Docker repository for external dependencies
export PYPI_LOCAL_REPO="pypi-local"                     # Local PyPI repository for Python package management

# 🎯 Environment Lifecycle Stage Configuration
# Deployment stage definitions for application promotion and lifecycle management
# Supports enterprise-grade environment promotion with proper governance
export NON_PROD_STAGES=("DEV" "QA" "STAGING")  # Non-production stages for development and testing
export PROD_STAGE="PROD"                       # Production stage for live customer-facing deployments

# 🔐 Security and Authentication Configuration
# OIDC and security parameter configuration for secure platform operations
# and enterprise-grade authentication across all platform integrations
export GITHUB_ACTIONS_ISSUER_URL="https://token.actions.githubusercontent.com/"  # GitHub OIDC issuer endpoint
export JFROG_CLI_SERVER_ID="bookverse-admin"                                    # JFrog CLI server configuration ID
export DEFAULT_RSA_KEY_SIZE=2048                                                 # RSA key size for cryptographic operations

# ⚙️ Operational Performance Configuration
# API interaction parameters for optimal performance and reliability
# across all platform operations and external service integrations
export DEFAULT_API_RETRIES=3      # Number of API retry attempts for resilient operations
export API_TIMEOUT=30             # API timeout in seconds for reliable service interactions

# 🗂️ Temporary File and Cache Management Configuration
# Operational parameters for temporary file handling and cache optimization
# to ensure clean operations and optimal performance during setup procedures
export TEMP_DIR_PREFIX="bookverse_cleanup"  # Prefix for temporary directories during cleanup operations
export CACHE_TTL_SECONDS=300                # Cache time-to-live in seconds for performance optimization


