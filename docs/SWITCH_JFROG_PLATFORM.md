# Switch Platform

## Overview

The BookVerse demo provides tools to easily switch between different JFrog Platform deployments. This is useful when:

- Moving from a trial to a production JFrog Platform instance
- Switching between different organizational JFrog Platform instances
- Testing the demo on different JFrog Platform configurations
- Migrating between JFrog Platform regions or deployments

## Available Methods

### Method 1: GitHub Actions Workflow (Recommended)

Use the automated GitHub Actions workflow for a seamless switch:

1. **Navigate to Actions**: Go to the `bookverse-demo-init` repository → Actions tab
2. **Select Workflow**: Choose "🔄 Switch Platform"
3. **Run Workflow**: Click "Run workflow" and provide:
   - **Platform Host**: Your new platform URL (e.g., `https://mycompany.jfrog.io`)
   - **Admin Token**: Admin token for the new platform
   - **Confirmation**: Type `SWITCH` to confirm
   - **Update Kubernetes**: ✅ Check to automatically update K8s cluster registry (optional)

**Features:**
- ✅ Automated validation of host format and connectivity
- ✅ Service availability testing
- ✅ Updates all 8 BookVerse repositories automatically
- ✅ Optional Kubernetes cluster registry update
- ✅ Comprehensive error handling and rollback capability
- ✅ Full audit trail in GitHub Actions logs

### Method 2: Interactive Script (Local Testing)

Use the interactive script for local testing or manual control:

```bash
cd bookverse-demo-init
./scripts/switch_jfrog_platform_interactive.sh
```

**Features:**
- ✅ Interactive prompts for host and token
- ✅ Real-time validation and testing
- ✅ Step-by-step confirmation process
- ✅ Automatic repository discovery
- ✅ Detailed progress feedback

## What Gets Updated

The platform switch process updates the following in all BookVerse repositories:

### GitHub Actions Secrets
- `JFROG_ADMIN_TOKEN` → New admin token
- `JFROG_ACCESS_TOKEN` → New admin token (fallback)

### GitHub Actions Variables  
- `JFROG_URL` → New platform URL
- `DOCKER_REGISTRY` → New platform hostname (extracted from URL)

### Repository List
The following repositories are automatically updated:
- `bookverse-inventory` - Inventory microservice
- `bookverse-recommendations` - Recommendations microservice  
- `bookverse-checkout` - Checkout microservice
- `bookverse-platform` - Platform aggregation service
- `bookverse-web` - Frontend web application
- `bookverse-helm` - Kubernetes deployment charts
- `bookverse-demo-assets` - GitOps and demo materials
- `bookverse-demo-init` - Setup and initialization scripts

## Validation Process

Both methods perform comprehensive validation:

### 1. Host Format Validation
- ✅ Ensures URL format: `https://hostname.jfrog.io`
- ✅ Strips trailing slashes automatically
- ✅ Validates hostname pattern

### 2. Connectivity Testing
- ✅ Basic HTTP connectivity to the platform
- ✅ Network reachability verification
- ✅ SSL/TLS certificate validation

### 3. Authentication Testing
- ✅ Admin token validation
- ✅ API endpoint accessibility
- ✅ Permission level verification

### 4. Service Availability Testing
- ✅ Artifactory service: Required
- ✅ Access service: Optional (some deployments)
- ✅ System health checks

## Prerequisites

### For GitHub Actions Method
- GitHub repository access with Actions enabled
- `GH_TOKEN` secret configured in `bookverse-demo-init`
- Admin privileges on target JFrog platform

### For Interactive Script Method
- GitHub CLI (`gh`) installed and authenticated
- `curl` and `jq` utilities available
- Admin privileges on target JFrog platform
- Network access to both old and new JFrog platforms

## Example Usage

### Switching to Production Platform

```bash
# From trial platform
FROM: https://old-instance.jfrog.io

# To production platform  
TO: https://new-instance.jfrog.io

# All repositories automatically updated with:
JFROG_URL: https://new-instance.jfrog.io
DOCKER_REGISTRY: new-instance.jfrog.io
JFROG_ADMIN_TOKEN: <new-production-token>
```

### Regional Migration

```bash
# From US region
FROM: https://acme-us.jfrog.io

# To EU region
TO: https://acme-eu.jfrog.io

# Maintains all project settings, updates endpoints only
```

## Error Handling

### Common Issues and Solutions

#### "Invalid host format"
- **Cause**: Host URL doesn't match expected pattern
- **Solution**: Use format `https://hostname.jfrog.io` (no trailing slash)

#### "Authentication failed (HTTP 401)"
- **Cause**: Invalid or expired admin token
- **Solution**: Generate new admin token from JFrog platform

#### "Authentication failed (HTTP 403)"  
- **Cause**: Token lacks admin privileges
- **Solution**: Ensure token has admin/platform scope

#### "Cannot reach JFrog platform"
- **Cause**: Network connectivity or DNS issues
- **Solution**: Verify hostname and network access

#### "Repository not found"
- **Cause**: BookVerse repository doesn't exist in GitHub org
- **Solution**: Repository is skipped automatically (expected behavior)

## Kubernetes Cluster Updates

When switching JFrog platforms, your Kubernetes cluster needs to be updated to pull images from the new registry.

### Automatic Update (Recommended)

The GitHub Actions workflow can automatically update your K8s cluster:

1. **Check "Update Kubernetes"** when running the switch workflow
2. **Ensure cluster access**: GitHub Actions runner must have kubectl access to your cluster
3. **Automatic process**:
   - Generates new access token for `k8s.pull@bookverse.com` user
   - Updates docker registry secret in `bookverse-prod` namespace
   - Restarts deployments to pull from new registry

### Manual Update

If automatic update isn't available, update manually:

```bash
# Set environment variables for new platform
export NEW_JFROG_URL='https://your-new-platform.jfrog.io'
export NEW_JFROG_ADMIN_TOKEN='your-admin-token'

# Run the update script
cd bookverse-demo-init
./scripts/k8s/update-registry.sh --restart-deployments
```

**Options:**
- `--dry-run`: Preview changes without applying them
- `--restart-deployments`: Restart deployments after updating registry

### Manual Alternative

If the script is not available, update manually with kubectl:

```bash
# 1. Generate access token for K8s user
ACCESS_TOKEN=$(curl -s -X POST \
  --header "Authorization: Bearer ${NEW_JFROG_ADMIN_TOKEN}" \
  --header "Content-Type: application/json" \
  --data '{
    "username": "k8s.pull@bookverse.com",
    "scope": "applied-permissions/user", 
    "expires_in": 31536000,
    "description": "K8s image pull token"
  }' \
  "${NEW_JFROG_URL}/access/api/v1/tokens" | jq -r '.access_token')

# 2. Extract registry hostname
NEW_REGISTRY=$(echo "$NEW_JFROG_URL" | sed 's|https://||')

# 3. Update Kubernetes secret
kubectl -n bookverse-prod create secret docker-registry jfrog-docker-pull \
  --docker-server="$NEW_REGISTRY" \
  --docker-username="k8s.pull@bookverse.com" \
  --docker-password="$ACCESS_TOKEN" \
  --docker-email="k8s.pull@bookverse.com" \
  --dry-run=client -o yaml | kubectl apply -f -

# 4. Restart deployments
kubectl -n bookverse-prod rollout restart deployment --all
```

## Post-Switch Verification

After switching platforms, verify the configuration:

### 1. Check Repository Variables
```bash
# Example: Check inventory service
gh variable list --repo yonatanp-jfrog/bookverse-inventory
```

### 2. Test CI/CD Pipeline
- Trigger a workflow in any BookVerse repository
- Verify it connects to the new JFrog platform
- Check artifact uploads and downloads

### 3. Validate Platform Integration
- Ensure OIDC integrations work (if configured)
- Test AppTrust application mappings
- Verify repository and project access

### 4. Verify Kubernetes Cluster (if applicable)
```bash
# Check registry secret
kubectl -n bookverse-prod get secret jfrog-docker-pull -o yaml

# Verify deployments are running with new images
kubectl -n bookverse-prod get pods

# Check recent events for image pull issues
kubectl -n bookverse-prod get events --sort-by='.lastTimestamp'
```

## Security Considerations

### Token Management
- 🔒 Admin tokens are stored as GitHub Secrets (encrypted)
- 🔒 Tokens are never logged or displayed in plain text
- 🔒 Use least-privilege tokens when possible

### Network Security
- 🔒 All communications use HTTPS/TLS
- 🔒 Validation occurs before any updates
- 🔒 Atomic updates prevent partial configurations

### Audit Trail
- 📝 All changes logged in GitHub Actions
- 📝 Timestamped execution records
- 📝 Success/failure status for each repository

## Troubleshooting

### Debug Mode
Enable debug mode for additional logging:

```bash
# For interactive script
DEBUG=1 ./scripts/switch_jfrog_platform_interactive.sh
```

### Manual Rollback
If needed, manually revert by running the switch process with the original platform details.

### Support
- Check GitHub Actions logs for detailed error messages
- Verify JFrog platform status and accessibility
- Ensure GitHub CLI authentication is current
- Validate admin token permissions on target platform

## Advanced Configuration

### Custom Repository List
To update a different set of repositories, modify the `BOOKVERSE_REPOS` array in the script:

```bash
BOOKVERSE_REPOS=(
    "your-custom-repo-1"
    "your-custom-repo-2"
    # ... add your repositories
)
```

### Additional Variables
To update additional GitHub Actions variables, extend the update functions in the script.

### Integration Testing
Consider setting up a test repository to validate the switch process before applying to production repositories.
