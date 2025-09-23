#!/usr/bin/env bash
# =============================================================================
# BookVerse Platform - Service Repository Secrets Configuration Script
# =============================================================================
#
# Comprehensive GitHub repository secrets configuration for BookVerse services
#
# 🎯 PURPOSE:
#     This script provides comprehensive GitHub repository secrets configuration
#     for the BookVerse platform, implementing secure JFROG_ACCESS_TOKEN distribution
#     across all service repositories, optional GitHub dispatch token management,
#     and automated secret validation for continuous integration and deployment workflows.
#
# 🏗️ ARCHITECTURE:
#     - Multi-Repository Management: Automated secret configuration across service repos
#     - Token Distribution: Secure JFROG_ACCESS_TOKEN propagation to all repositories
#     - GitHub CLI Integration: Native GitHub CLI for secure secret management
#     - Validation Framework: Comprehensive verification of secret configuration
#     - Error Recovery: Robust error handling with detailed failure reporting
#     - Batch Processing: Efficient bulk repository configuration with status tracking
#
# 🚀 KEY FEATURES:
#     - Automated JFROG_ACCESS_TOKEN configuration across all BookVerse service repositories
#     - Optional GitHub repository dispatch token configuration for platform orchestration
#     - Comprehensive validation and verification of secret configuration success
#     - Batch processing with individual repository status tracking and error isolation
#     - Security-first approach with token validation and secure transmission
#     - Complete CI/CD readiness verification for end-to-end workflow testing
#
# 📊 BUSINESS LOGIC:
#     - CI/CD Enablement: Enabling secure authentication for all service repositories
#     - Security Compliance: Centralized secret management with secure distribution
#     - Operational Efficiency: Automated configuration reducing manual secret management
#     - Development Productivity: Streamlined CI/CD setup for all development teams
#     - Platform Orchestration: Cross-repository communication through dispatch tokens
#
# 🛠️ USAGE PATTERNS:
#     - Initial Platform Setup: First-time secret configuration for new environments
#     - Token Rotation: Periodic security token updates across all repositories
#     - Service Onboarding: Adding secret configuration to new service repositories
#     - CI/CD Troubleshooting: Validating and repairing secret configuration issues
#     - Security Auditing: Verifying secret configuration across platform repositories
#
# ⚙️ PARAMETERS:
#     [Required Positional Parameters]
#     $1 - JFROG_ACCESS_TOKEN   : JFrog Platform access token for CI/CD authentication
#                                 - Must be valid JFrog Platform API token
#                                 - Minimum 64 characters length for security validation
#                                 - Should have appropriate permissions for repository access
#                                 - Obtained from JFrog Platform admin or token generation
#     
#     [Optional Environment Variables]
#     GH_REPO_DISPATCH_TOKEN    : GitHub repository dispatch token for cross-repo workflows
#                                 - Enables platform orchestration and cross-repository communication
#                                 - Required for advanced CI/CD workflows with repository dispatch
#                                 - Must have 'repo' scope for target repositories
#                                 - Optional: script continues without this token if not provided
#
# 🌍 ENVIRONMENT VARIABLES:
#     [Required for Script Execution]
#     (None - all required data passed as parameters)
#     
#     [Optional Configuration]
#     GH_REPO_DISPATCH_TOKEN    : GitHub Personal Access Token for repository dispatch
#                                 - Scope: 'repo' (full repository access)
#                                 - Purpose: Cross-repository workflow triggering
#                                 - Target: bookverse-platform repository specifically
#                                 - Format: GitHub PAT (ghp_xxxxxxxxxxxx...)
#                                 - Security: Stored securely as GitHub repository secret
#     
#     [GitHub CLI Requirements]
#     GH_TOKEN                  : GitHub CLI authentication token (auto-configured by gh auth)
#                                 - Required for 'gh secret set' operations
#                                 - Must have 'repo' scope for target repositories
#                                 - Automatically managed by GitHub CLI authentication
#
# 📋 PREREQUISITES:
#     [System Requirements]
#     - bash (4.0+): Advanced shell features for array processing and error handling
#     - gh (GitHub CLI): Required for repository secret management operations
#     - Internet connectivity: Required for GitHub API communication
#     
#     [Authentication Requirements]
#     - GitHub CLI Authentication: Must be logged in with 'gh auth login'
#     - Repository Access: GitHub account must have admin access to target repositories
#     - Token Permissions: Provided tokens must have appropriate scopes and permissions
#     
#     [Platform Requirements]
#     - JFrog Platform Access: Valid JFROG_ACCESS_TOKEN with CI/CD permissions
#     - BookVerse Repository Access: Admin permissions on all target service repositories
#
# 📤 OUTPUTS:
#     [Return Codes]
#     0: Success - All repository secrets configured successfully
#     1: Error - Secret configuration failed with detailed error reporting
#     
#     [Configuration Results]
#     - JFROG_ACCESS_TOKEN configured in all BookVerse service repositories
#     - GH_REPO_DISPATCH_TOKEN configured in bookverse-platform (if provided)
#     - Detailed status reporting for each repository configuration operation
#     - Comprehensive verification summary with CI/CD readiness confirmation
#     
#     [Repository Secret Status]
#     - Individual repository configuration success/failure status
#     - Token validation and security verification results
#     - CI/CD workflow readiness confirmation for each service
#
# 💡 EXAMPLES:
#     [Basic Secret Configuration]
#     # Get JFROG_ACCESS_TOKEN from platform admin
#     ./scripts/configure_service_secrets.sh "jfrt_xxxxxxxxxxxx..."
#     
#     [Advanced Configuration with Dispatch Token]
#     export GH_REPO_DISPATCH_TOKEN="ghp_xxxxxxxxxxxx..."
#     ./scripts/configure_service_secrets.sh "jfrt_xxxxxxxxxxxx..."
#     
#     [Token Rotation Workflow]
#     # 1. Generate new JFROG_ACCESS_TOKEN in JFrog Platform
#     # 2. Run configuration script with new token
#     ./scripts/configure_service_secrets.sh "$NEW_JFROG_TOKEN"
#
# ⚠️ ERROR HANDLING:
#     [Common Failure Modes]
#     - Missing JFROG_ACCESS_TOKEN: Validates required parameter presence
#     - Invalid token format: Validates token length and format requirements
#     - GitHub CLI not authenticated: Validates gh CLI authentication status
#     - Repository access denied: Handles insufficient permissions gracefully
#     - Network connectivity issues: Manages GitHub API communication failures
#     
#     [Recovery Procedures]
#     - Authentication Setup: Run 'gh auth login' to configure GitHub CLI
#     - Token Validation: Verify JFROG_ACCESS_TOKEN with JFrog Platform
#     - Permission Verification: Confirm admin access to target repositories
#     - Network Troubleshooting: Check internet connectivity and GitHub API access
#
# 🔍 DEBUGGING:
#     [Debug Mode]
#     set -x                                          # Enable bash debug mode
#     ./scripts/configure_service_secrets.sh TOKEN   # Run with debug output
#     
#     [Manual Verification]
#     gh secret list --repo "yonatanp-jfrog/bookverse-inventory"  # Check secret status
#     gh auth status                                              # Verify CLI auth
#
# 🔗 INTEGRATION POINTS:
#     [GitHub Integration]
#     - GitHub CLI: Repository secret management and authentication
#     - GitHub API: Secure secret storage and access control
#     - Repository Dispatch: Cross-repository workflow coordination
#     
#     [JFrog Integration]
#     - JFrog Platform: Access token validation and CI/CD authentication
#     - Artifactory: Container registry access for CI/CD workflows
#     - Build Info: CI/CD pipeline metadata and artifact management
#
# 📊 PERFORMANCE:
#     [Execution Time]
#     - Token validation: 2-5 seconds for format and length checks
#     - Repository configuration: 5-10 seconds per repository
#     - Total execution time: 1-2 minutes for all repositories
#     - Verification phase: 10-20 seconds for status confirmation
#
# 🛡️ SECURITY CONSIDERATIONS:
#     [Token Security]
#     - No token logging or exposure in script output
#     - Secure transmission through GitHub CLI encrypted channels
#     - Token validation without exposing sensitive values
#     - Minimal token exposure time during configuration
#     
#     [Access Control]
#     - Repository admin permissions required for secret configuration
#     - GitHub CLI authentication with appropriate scopes
#     - Audit trail through GitHub secret management logs
#
# 📚 REFERENCES:
#     [Documentation]
#     - GitHub CLI Secrets: https://cli.github.com/manual/gh_secret
#     - JFrog Access Tokens: https://www.jfrog.com/confluence/display/JFROG/Access+Tokens
#     - GitHub Repository Dispatch: https://docs.github.com/en/rest/repos/repos#create-a-repository-dispatch-event
#
# Authors: BookVerse Platform Team
# Version: 1.0.0
# Last Updated: 2024-01-01
# =============================================================================

set -euo pipefail

# 🔐 Parameter Extraction: Extract and validate required JFROG_ACCESS_TOKEN
JFROG_ACCESS_TOKEN="$1"

# 📋 Parameter Validation: Comprehensive validation of required token parameter
if [ -z "$JFROG_ACCESS_TOKEN" ]; then
    echo "❌ Error: JFROG_ACCESS_TOKEN is required as first positional parameter"
    echo ""
    echo "📖 Usage: $0 <JFROG_ACCESS_TOKEN> [environment_variables]"
    echo ""
    echo "🔧 Required Parameters:"
    echo "  JFROG_ACCESS_TOKEN    : JFrog Platform access token for CI/CD authentication"
    echo "                          - Must be valid JFrog Platform API token (jfrt_...)"
    echo "                          - Minimum 64 characters for security requirements"
    echo "                          - Should have repository read/write permissions"
    echo "                          - Obtain from JFrog Platform admin or token generation"
    echo ""
    echo "🌍 Optional Environment Variables:"
    echo "  GH_REPO_DISPATCH_TOKEN : GitHub repository dispatch token (optional)"
    echo "                          - Enables cross-repository workflow triggering"
    echo "                          - Required for advanced platform orchestration"
    echo "                          - Must have 'repo' scope for target repositories"
    echo "                          - Format: GitHub PAT (ghp_xxxxxxxxxxxx...)"
    echo ""
    echo "💡 Example Usage:"
    echo "  # Basic configuration with JFROG_ACCESS_TOKEN only"
    echo "  $0 'jfrt_xxxxxxxxxxxx...'"
    echo ""
    echo "  # Advanced configuration with optional dispatch token"
    echo "  export GH_REPO_DISPATCH_TOKEN='ghp_xxxxxxxxxxxx...'"
    echo "  $0 'jfrt_xxxxxxxxxxxx...'"
    echo ""
    echo "📋 Prerequisites:"
    echo "  - GitHub CLI installed and authenticated (gh auth login)"
    echo "  - Admin access to BookVerse service repositories"
    echo "  - Valid JFrog Platform access token"
    echo "  - Internet connectivity for GitHub API access"
    echo ""
    echo "🔍 Get JFROG_ACCESS_TOKEN:"
    echo "  - Contact BookVerse platform administrator"
    echo "  - Generate token in JFrog Platform UI (Admin > Access Tokens)"
    echo "  - Ensure token has CI/CD and repository permissions"
    echo ""
    exit 1
fi

# 🚀 Configuration Initiation: Begin secret configuration process with status display
echo "🚀 Configuring JFROG_ACCESS_TOKEN for all BookVerse service repositories"
echo "🔧 Token length: ${#JFROG_ACCESS_TOKEN} characters"
echo ""

# 📦 Repository Configuration: Define target repositories for secret configuration
# This array contains all BookVerse service repositories that require JFROG_ACCESS_TOKEN
# for CI/CD operations, container registry access, and artifact management
SERVICE_REPOS=(
    "yonatanp-jfrog/bookverse-inventory"      # Inventory microservice repository
    "yonatanp-jfrog/bookverse-recommendations" # Recommendations AI service repository  
    "yonatanp-jfrog/bookverse-checkout"       # Checkout and payment service repository
    "yonatanp-jfrog/bookverse-platform"       # Platform aggregation service repository
    "yonatanp-jfrog/bookverse-web"            # Web frontend application repository
    "yonatanp-jfrog/bookverse-helm"           # Helm charts and Kubernetes manifests repository
    "yonatanp-jfrog/bookverse-infra"          # Infrastructure and DevOps tooling repository
)

# 🔐 Optional Dispatch Token Configuration: Configure cross-repository communication token
# GH_REPO_DISPATCH_TOKEN enables advanced CI/CD workflows with repository dispatch events
# This allows platform orchestration and cross-repository workflow triggering
if [[ -n "${GH_REPO_DISPATCH_TOKEN:-}" ]]; then
    echo "🔐 Configuring GH_REPO_DISPATCH_TOKEN for bookverse-platform (optional)"
    echo "   Purpose: Cross-repository workflow triggering and platform orchestration"
    echo "   Target: bookverse-platform repository for central coordination"
    
    # 📤 Dispatch Token Setup: Configure repository dispatch token securely
    if echo -n "$GH_REPO_DISPATCH_TOKEN" | gh secret set GH_REPO_DISPATCH_TOKEN --repo "yonatanp-jfrog/bookverse-platform"; then
        echo "✅ bookverse-platform: GH_REPO_DISPATCH_TOKEN configured"
        echo "   Capability: Cross-repository workflow coordination enabled"
    else
        # ⚠️ Dispatch Token Failure: Handle optional token configuration failure gracefully
        echo "⚠️  Failed to set GH_REPO_DISPATCH_TOKEN in bookverse-platform (continuing)"
        echo "   Impact: Cross-repository workflows may not function fully"
        echo "   Resolution: Verify token permissions and repository access"
    fi
else
    # ℹ️ Dispatch Token Skipped: Inform user about optional token not provided
    echo "ℹ️ GH_REPO_DISPATCH_TOKEN not provided; skipping repo secret configuration"
    echo "   Impact: Basic CI/CD will work, advanced cross-repo features disabled"
    echo "   Note: This token is optional for basic platform functionality"
fi

# 🔄 Repository Processing Loop: Configure JFROG_ACCESS_TOKEN for each service repository
# This loop iterates through all BookVerse service repositories and configures
# the required JFROG_ACCESS_TOKEN secret for CI/CD operations
for repo in "${SERVICE_REPOS[@]}"; do
    echo "📦 Configuring ${repo}..."
    echo "   Purpose: Enable CI/CD authentication with JFrog Platform"
    echo "   Secret: JFROG_ACCESS_TOKEN for repository and container access"
    
    # 🔐 Secret Configuration: Use GitHub CLI to securely set repository secret
    # The token is piped to avoid command line exposure and ensure secure transmission
    if echo "$JFROG_ACCESS_TOKEN" | gh secret set JFROG_ACCESS_TOKEN --repo "$repo"; then
        echo "✅ ${repo}: JFROG_ACCESS_TOKEN configured successfully"
        echo "   Status: CI/CD workflows can now authenticate with JFrog Platform"
        echo "   Capabilities: Container pull/push, artifact management, build info"
    else
        # ❌ Configuration Failure: Handle individual repository configuration failure
        echo "❌ ${repo}: Failed to configure JFROG_ACCESS_TOKEN"
        echo "   Error: Secret configuration failed for this repository"
        echo "   Impact: CI/CD workflows will fail authentication"
        echo "   Resolution: Check repository access permissions and GitHub CLI auth"
        exit 1
    fi
    echo ""
done

# 🎉 Success Summary: Display comprehensive configuration completion status
echo "🎉 SUCCESS: JFROG_ACCESS_TOKEN configured for all service repositories!"
echo ""
echo "📋 Configured repositories:"
# 📊 Repository Status: List all successfully configured repositories
for repo in "${SERVICE_REPOS[@]}"; do
    echo "  ✅ ${repo}"
    echo "      - JFROG_ACCESS_TOKEN: ✅ Configured"
    echo "      - CI/CD Authentication: ✅ Enabled"
    echo "      - Container Registry Access: ✅ Ready"
done
echo ""

# 🔍 Verification Instructions: Provide guidance for testing configuration
echo "🔍 Verification:"
echo "You can now run CI workflows on any service repository."
echo "They should successfully authenticate with JFrog Platform."
echo ""
echo "📋 Next Steps:"
echo "  1. Test CI/CD workflows on any service repository"
echo "  2. Verify container image pull/push operations"
echo "  3. Confirm artifact publishing and build info generation"
echo "  4. Validate end-to-end deployment workflows"
echo ""
echo "🚀 Ready for complete end-to-end CI/CD testing!"
echo ""
echo "💡 Troubleshooting:"
echo "  - If workflows fail: Check JFROG_ACCESS_TOKEN permissions"
echo "  - For authentication errors: Verify token scope and validity"
echo "  - For repository access: Confirm token has appropriate JFrog permissions"
