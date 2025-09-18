# BookVerse DevOps Scripts

This directory contains shared scripts used by the BookVerse CI/CD workflows.

## Semver Determination Scripts

### `semver_versioning.py`

Core Python script for semantic version determination across all BookVerse services.

**Purpose**: Prevents JFrog Artifactory 409 conflicts by intelligently determining next versions based on existing artifacts in repositories.

**Key Features**:
- Queries existing versions from Docker registries, generic repositories, and AppTrust
- Always bumps seed versions to avoid conflicts with promoted Release Bundles
- Supports multiple package types (Docker, generic, applications)
- Robust error handling with graceful fallbacks

**Usage**:
```bash
python3 semver_versioning.py \
  --application-key bookverse-inventory \
  --version-map ./config/version-map.yaml \
  --jfrog-url "$JFROG_URL" \
  --jfrog-token "$JF_OIDC_TOKEN" \
  --project-key bookverse \
  --packages "inventory,inventory-worker"
```

### `determine-semver.sh`

Shell wrapper for easy CI integration of the semver determination logic.

**Purpose**: Provides a simple interface for GitHub Actions workflows to determine versions and set environment variables.

**Environment Variables Set**:
- `APP_VERSION` - Application version (e.g., 2.4.17)
- `BUILD_NUMBER` - Build number (e.g., 3.7.26)  
- `IMAGE_TAG` - Docker image tag (defaults to BUILD_NUMBER)
- `DOCKER_TAG_*` - Package-specific tags (e.g., DOCKER_TAG_INVENTORY=1.6.15)

**Usage in GitHub Actions**:
```yaml
- name: "🧮 Determine Versions"
  run: |
    ./scripts/determine-semver.sh \
      --application-key "${{ env.APPLICATION_KEY }}" \
      --version-map "./config/version-map.yaml" \
      --jfrog-url "${{ vars.JFROG_URL }}" \
      --jfrog-token "${{ env.JF_OIDC_TOKEN }}" \
      --project-key "${{ vars.PROJECT_KEY }}" \
      --packages "${{ env.PACKAGES }}"
```

## Integration with Shared Workflows

These scripts are designed to be used by the shared workflows in `.github/workflows/`:

- `shared-build.yml` - Uses semver determination for build versioning
- `shared-promote.yml` - Uses semver determination for promotion versioning

## Demo Context

**DEMO PURPOSE**: These scripts demonstrate how to eliminate version determination duplication across services. Previously, each service had its own copy of these scripts, leading to maintenance overhead and inconsistency.

**Consolidation Benefits**:
- ✅ Single source of truth for version determination logic
- ✅ Consistent versioning behavior across all services  
- ✅ Centralized bug fixes and improvements
- ✅ Reduced maintenance overhead
- ✅ Prevents version conflicts with Release Bundles

## Requirements

- Python 3.7+
- PyYAML (`pip install PyYAML`)
- JFrog CLI (for OIDC authentication)
- Valid JFrog access token with appropriate permissions

## Error Handling

The scripts include comprehensive error handling:
- Network timeout handling for API calls
- Graceful fallback when repositories are empty
- Clear error messages for debugging
- Proper JSON validation for API responses

## Version Map Configuration

The scripts require a `version-map.yaml` file that defines seed versions for each service:

```yaml
applications:
  bookverse-inventory:
    seed: "1.0.0"
    packages:
      inventory: "1.0.0"
      inventory-worker: "1.0.0"
  bookverse-recommendations:
    seed: "1.0.0" 
    packages:
      recommendations: "1.0.0"
      recommendations-worker: "1.0.0"
```

This configuration ensures consistent version seeding across all services while allowing for independent versioning of individual packages.