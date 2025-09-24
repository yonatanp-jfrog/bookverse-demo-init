# BookVerse Switch Platform Workflow

## Overview

The **Switch Platform Workflow** (`🔄-switch-platform.yml`) automates migrating the BookVerse platform from one JFrog instance to another. This workflow updates all repository configurations, secrets, and variables to point to a new JFrog Platform deployment.

### What It Does

The workflow performs a complete platform migration:

1. **Validates New Platform**
   - Checks host format and connectivity
   - Tests authentication with provided admin token
   - Verifies required JFrog services are available

2. **Updates All Repositories**
   - Updates `JFROG_URL` variable in all BookVerse repositories
   - Refreshes `JFROG_ADMIN_TOKEN` secret across all repos
   - Configures Docker registry settings for new platform

3. **Optional Kubernetes Update**
   - Updates container registry credentials in K8s cluster
   - Refreshes image pull secrets for new platform
   - Restarts deployments to use new registry

4. **Validates Migration**
   - Tests connectivity to new platform
   - Verifies repository access and permissions
   - Confirms successful configuration update

### When to Use

**Common Use Cases:**
- **Platform Migration**: Moving from trial to production JFrog instance
- **Organization Transfer**: Switching between different company JFrog instances
- **Regional Migration**: Moving to different JFrog Platform regions
- **Testing**: Validating demo on different platform configurations

**Trigger Methods:**
- Manual execution via GitHub Actions UI (workflow_dispatch)
- Provides interactive input prompts for new platform details

### Prerequisites

Before running the workflow, ensure you have:

1. **Source Platform Access**
   - Current platform must be accessible
   - Existing admin token must be valid

2. **Target Platform Access**
   - Admin-level access to new JFrog instance
   - New platform admin token ready
   - Target platform accessible from GitHub Actions

3. **GitHub Permissions**
   - Admin access to all BookVerse repositories
   - Valid `GH_TOKEN` with repository management permissions

### How to Run

1. **Navigate to Actions**: Go to the GitHub Actions tab in the bookverse-demo-init repository

2. **Select Workflow**: Choose "🔄 Switch Platform" from the workflow list

3. **Provide Inputs**: Enter the required information:
   - **Platform Host**: New JFrog Platform URL (e.g., `https://mycompany.jfrog.io`)
   - **Admin Token**: Admin token for the new platform
   - **Confirmation**: Type `SWITCH` to confirm the migration
   - **Update Kubernetes**: Check if you want to update K8s cluster registry

4. **Monitor Progress**: Watch the workflow execution for validation and migration steps

5. **Verify Results**: Check that all repositories and services are working with the new platform

### Expected Outcomes

Upon successful completion:

- **All Repositories Updated**: Every BookVerse repository now points to the new platform
- **Secrets Refreshed**: All authentication tokens updated for new platform
- **Variables Updated**: Registry and URL configurations reflect new platform
- **Kubernetes Updated**: (Optional) Cluster configured for new container registry
- **Validation Complete**: All services confirmed working with new platform

### Repositories Updated

The workflow automatically updates these repositories:
- `bookverse-inventory`
- `bookverse-recommendations`
- `bookverse-checkout`
- `bookverse-platform`
- `bookverse-web`
- `bookverse-helm`
- `bookverse-demo-init`

### Troubleshooting

**Common Issues:**
- **Invalid Host Format**: Ensure URL includes `https://` and correct domain
- **Authentication Failure**: Verify admin token has proper permissions
- **Network Connectivity**: Check if new platform is accessible from GitHub Actions
- **Repository Access**: Confirm GitHub token has admin access to all repos

**Recovery:**
- **Failed Migration**: Re-run workflow with corrected parameters
- **Partial Update**: Check individual repository settings manually
- **Rollback**: Run switch workflow again with original platform details

**Getting Help:**
- Review workflow logs for specific error messages
- Verify new platform is properly configured and accessible
- Check that all prerequisites are met before retrying

### Alternative Methods

**Interactive Script**: For local testing or manual operation:
```bash
./scripts/switch_jfrog_platform_interactive.sh
```

---

**Note**: This workflow affects all BookVerse repositories and requires careful validation. Always verify the new platform is properly configured before running the migration.
