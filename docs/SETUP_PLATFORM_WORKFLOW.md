# BookVerse Setup Platform Workflow

## Overview

The **Setup Platform Workflow** (`🚀-setup-platform.yml`) is a comprehensive GitHub Actions workflow that automates the complete provisioning and configuration of the BookVerse platform infrastructure.

### What It Does

The workflow performs end-to-end platform setup in a single automated execution:

1. **JFrog Platform Setup**
   - Creates the BookVerse project with proper configuration
   - Sets up lifecycle stages (DEV, QA, STAGING, PROD)
   - Creates service-specific repositories for all microservices
   - Configures dependency repositories and caches

2. **User & Security Management**
   - Creates custom roles with appropriate permissions
   - Sets up users with role-based access control
   - Configures OIDC authentication for zero-trust security
   - Establishes application registrations

3. **GitHub Repository Management**
   - Creates all BookVerse service repositories
   - Sets up CI/CD workflows for each service
   - Configures repository secrets and variables
   - Establishes proper access controls

4. **Infrastructure Validation**
   - Validates all created resources
   - Verifies connectivity and permissions
   - Provides comprehensive setup summary

### When to Use

**Primary Use Cases:**
- **New Environment Setup**: Initial provisioning of a complete BookVerse environment
- **Disaster Recovery**: Rebuilding the platform after infrastructure loss
- **Demo Preparation**: Setting up clean environments for demonstrations
- **Development Environment**: Creating isolated development platforms

**Trigger Methods:**
- Manual execution via GitHub Actions UI (workflow_dispatch)
- API calls via repository dispatch events

### Prerequisites

Before running the workflow, ensure you have:

1. **JFrog Platform Access**
   - Admin-level access to your JFrog instance
   - `JFROG_URL` configured as a repository variable
   - `JFROG_ADMIN_TOKEN` configured as a repository secret

2. **GitHub Permissions**
   - Admin access to the GitHub organization
   - `GH_TOKEN` configured as a repository secret with repo creation permissions

3. **Environment Configuration**
   - Target JFrog instance properly configured and accessible
   - GitHub organization ready for repository creation

### How to Run

1. **Navigate to Actions**: Go to the GitHub Actions tab in the bookverse-demo-init repository

2. **Select Workflow**: Choose "🚀 Setup Platform" from the workflow list

3. **Trigger Execution**: Click "Run workflow" and confirm execution

4. **Monitor Progress**: Watch the workflow execution through the GitHub Actions interface

5. **Review Results**: Check the workflow summary for validation results and any issues

### Expected Outcomes

Upon successful completion, you will have:

- **Complete JFrog Project**: Fully configured with all repositories and stages
- **User Management**: All roles and users properly configured
- **GitHub Repositories**: All BookVerse service repositories created with CI/CD
- **Security Integration**: OIDC authentication fully configured
- **Validated Setup**: All components tested and verified

### Troubleshooting

**Common Issues:**
- **Permission Errors**: Verify admin tokens have sufficient privileges
- **Network Connectivity**: Ensure JFrog instance is accessible
- **Resource Conflicts**: Check if resources already exist from previous runs
- **Token Expiration**: Refresh expired authentication tokens

**Getting Help:**
- Check workflow logs for detailed error messages
- Verify all prerequisites are met
- Ensure environment variables and secrets are properly configured

### Related Workflows

- **🔄 Switch Platform**: Migrate between different JFrog instances
- **📋 Validate K8s**: Validate Kubernetes cluster configuration
- **🗑️ Execute Cleanup**: Clean up platform resources

---

**Note**: This workflow requires significant permissions and will create substantial infrastructure. Always run in appropriate environments and verify configurations before execution.
