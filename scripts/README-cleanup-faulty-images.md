# BookVerse Docker Image Cleanup

## Problem Description

The BookVerse checkout service has a faulty Docker image with tag `180-1` which is not a valid semantic version. This occurred due to a fallback mechanism in the CI workflow that uses the GitHub build number (`${{ github.run_number }}-${{ github.run_attempt }}`) when no specific Docker tag variable is set.

## Root Cause Analysis

In `/bookverse-checkout/.github/workflows/ci.yml` lines 164-169:

```bash
DOCKER_TAG_VAR="DOCKER_TAG_$(echo "$SERVICE_NAME" | tr '[:lower:]' '[:upper:]' | tr '-' '_')"
if [[ -n "${!DOCKER_TAG_VAR:-}" ]]; then
  IMAGE_TAG="${!DOCKER_TAG_VAR}"
else
  IMAGE_TAG="$BUILD_NUMBER"  # ← This creates non-semver tags like "180-1"
fi
```

The `BUILD_NUMBER` is set to `${{ github.run_number }}-${{ github.run_attempt }}` (line 100), which creates tags like `180-1` instead of proper semantic versions.

## Services Affected

Based on analysis of CI workflows:

- ✅ **inventory**: Uses `$INVENTORY_VERSION` (proper semver)
- ✅ **recommendations**: Uses `$RECOMMENDATIONS_VERSION` (proper semver)  
- ❌ **checkout**: Falls back to `$BUILD_NUMBER` (creates faulty tags like "180-1")
- ✅ **platform**: Uses proper semver versioning
- ✅ **web**: Uses proper semver versioning

## Solution

### 1. Immediate Cleanup

Use the provided cleanup script to identify and delete faulty Docker images:

```bash
# Set up environment
export JFROG_URL="https://your-jfrog-instance.jfrog.io"
export PROJECT_KEY="bookverse"

# Dry run to see what would be deleted
./scripts/cleanup-faulty-docker-images.sh --dry-run --verbose

# Delete the specific faulty tag
./scripts/cleanup-faulty-docker-images.sh --target-tag "180-1"

# Scan all services for faulty images
./scripts/cleanup-faulty-docker-images.sh --dry-run

# Clean up all faulty images (if any found)
./scripts/cleanup-faulty-docker-images.sh
```

### 2. Authentication

The script supports multiple authentication methods:

1. **GitHub Actions OIDC** (automatic in CI):
   - Uses `ACTIONS_ID_TOKEN_REQUEST_TOKEN` and `ACTIONS_ID_TOKEN_REQUEST_URL`
   - Exchanges GitHub token for JFrog token automatically

2. **Manual OIDC token** (for local execution):
   ```bash
   export JF_OIDC_TOKEN="your-jfrog-oidc-token"
   ```

### 3. Prevention

The checkout service CI workflow should be fixed to ensure it always uses proper semantic versioning instead of falling back to build numbers.

## Repository Structure

Faulty images would be found in repositories following this pattern:
- `bookverse-{service}-internal-docker-nonprod-local/{service}:{tag}`
- `bookverse-{service}-internal-docker-prod-local/{service}:{tag}`

For checkout service specifically:
- Main image: `bookverse-checkout-internal-docker-nonprod-local/checkout:180-1`
- Worker image: `bookverse-checkout-internal-docker-nonprod-local/checkout-worker:180-1`
- Migrations image: `bookverse-checkout-internal-docker-nonprod-local/checkout-migrations:180-1`

## Script Features

The cleanup script provides:

- ✅ **Dry run mode**: See what would be deleted without making changes
- ✅ **Targeted deletion**: Delete specific tags by name
- ✅ **Service filtering**: Focus on specific services only
- ✅ **Comprehensive scanning**: Check all BookVerse repositories
- ✅ **Semver validation**: Distinguish between valid and invalid tags
- ✅ **Verbose logging**: Detailed API calls and responses
- ✅ **Safe authentication**: Uses OIDC tokens, no stored credentials

## Usage Examples

```bash
# Quick check for the specific faulty tag
./scripts/cleanup-faulty-docker-images.sh --target-tag "180-1" --dry-run

# Comprehensive scan with details
./scripts/cleanup-faulty-docker-images.sh --dry-run --verbose

# Clean up only checkout service
./scripts/cleanup-faulty-docker-images.sh --service checkout

# Delete all faulty non-semver images
./scripts/cleanup-faulty-docker-images.sh
```

## Expected Output

The script will show:
- Total tags found per image
- Categorization: semver tags, build number tags, other tags
- Detailed information about faulty tags (creation date, size)
- Deletion results and summary

Example:
```
📦 Scanning service: checkout
   Repository: bookverse-checkout-internal-docker-nonprod-local
      Image: checkout
         Total tags: 15
         Semver tags: 12
         Build number tags: 1 ⚠️
         Other tags: 2
         🚨 Found 1 faulty tags:
            - 180-1 (created: 2025-09-21T08:05:46.123Z, size: 245MB)
            ✅ Deleted bookverse-checkout-internal-docker-nonprod-local/checkout:180-1
```
