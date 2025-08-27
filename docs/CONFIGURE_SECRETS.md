# Configure JFrog Access Tokens for BookVerse Repositories

## Overview
All BookVerse service repositories need the `JFROG_ACCESS_TOKEN` secret configured to enable CI/CD workflows with JFrog Platform integration.

## Current Status

### ✅ Properly Configured Repositories
- **bookverse-demo-init**: Has `JFROG_ADMIN_TOKEN` secret ✅

### ❌ Repositories Missing Access Token
The following repositories need `JFROG_ACCESS_TOKEN` configured:
- bookverse-inventory
- bookverse-recommendations
- bookverse-checkout
- bookverse-platform
- bookverse-web
- bookverse-helm

### ✅ All Repositories Have Required Variables
All repositories are properly configured with:
- `JFROG_URL`: `https://evidencetrial.jfrog.io`
- `PROJECT_KEY`: `bookverse`
- `DOCKER_REGISTRY`: `evidencetrial.jfrog.io`

## Configuration Options

### Option 1: Automated Script (Recommended)

Use the provided script to configure all repositories at once:

```bash
# Run from the bookverse-demo-init directory
./scripts/configure_service_secrets.sh <JFROG_ACCESS_TOKEN>
```

**Steps:**
1. Get the admin token value from your JFrog Platform
2. Run the script with the token as parameter
3. Script will configure all 6 service repositories automatically

### Option 2: Manual Configuration

Configure each repository individually via GitHub UI:

1. Go to repository → Settings → Secrets and Variables → Actions
2. Click "New repository secret"
3. Name: `JFROG_ACCESS_TOKEN`
4. Value: Your JFrog access token
5. Repeat for all 6 service repositories

### Option 3: GitHub CLI Manual

Configure each repository using GitHub CLI:

```bash
# For each repository
echo "<your-token>" | gh secret set JFROG_ACCESS_TOKEN --repo yonatanp-jfrog/bookverse-inventory
echo "<your-token>" | gh secret set JFROG_ACCESS_TOKEN --repo yonatanp-jfrog/bookverse-recommendations
echo "<your-token>" | gh secret set JFROG_ACCESS_TOKEN --repo yonatanp-jfrog/bookverse-checkout
echo "<your-token>" | gh secret set JFROG_ACCESS_TOKEN --repo yonatanp-jfrog/bookverse-platform
echo "<your-token>" | gh secret set JFROG_ACCESS_TOKEN --repo yonatanp-jfrog/bookverse-web
echo "<your-token>" | gh secret set JFROG_ACCESS_TOKEN --repo yonatanp-jfrog/bookverse-helm
```

## Verification

After configuration, verify by running a CI workflow on any service repository:

```bash
# Example: Test bookverse-inventory
cd bookverse-inventory
gh workflow run "CI" --field reason="Test JFROG_ACCESS_TOKEN configuration"
```

The workflow should:
1. ✅ Authenticate with JFrog Platform
2. ✅ Install dependencies from Artifactory  
3. ✅ Run tests and generate coverage
4. ✅ Build and push Docker images
5. ✅ Create AppTrust application versions
6. ✅ Attach evidence to artifacts

## Required Permissions

The JFROG_ACCESS_TOKEN needs the following permissions:
- **Artifactory**: Read/write access to all BookVerse repositories
- **AppTrust**: Create application versions and attach evidence
- **Build Info**: Publish build information
- **Docker**: Push to Docker repositories

## Security Notes

- Use the same token value as the admin token for demo purposes
- In production, create service-specific tokens with minimal required permissions
- Rotate tokens regularly according to security policies
- Never commit token values to source code

## Troubleshooting

### Common Issues

1. **Authentication Failed**
   - Verify token has correct permissions
   - Check token hasn't expired
   - Confirm JFrog URL is correct

2. **Repository Access Denied**
   - Ensure repositories exist in JFrog Platform
   - Verify token has access to project repositories
   - Check repository naming conventions

3. **AppTrust API Errors**
   - Confirm AppTrust is enabled on JFrog Platform
   - Verify token has AppTrust permissions
   - Check application key naming

## Next Steps

Once configured, the BookVerse platform will have:
- ✅ Complete CI/CD pipeline functionality
- ✅ JFrog Platform integration
- ✅ AppTrust governance capabilities
- ✅ End-to-end evidence management
- ✅ Professional DevSecOps workflows

Ready for enterprise-grade demonstrations! 🚀
