# Unified SemVer Strategy - Long-Term Solution

## Overview

This document describes the comprehensive long-term solution implemented to prevent JFrog Artifactory 409 conflicts caused by semver determination logic falling back to seed versions that conflict with promoted Release Bundles.

## Problem Statement

The original issue was:
```
Error: 9 [Error] server response: 409 
{
  "errors" : [ {
    "status" : 409,
    "message" : "org.artifactory.exception.CancelException: The artifact bookverse-web-internal-generic-nonprod-local/web/assets/3.31.40/web-assets-3.31.40.tar.gz is associated with one or more promoted Release Bundle v2 versions and cannot be deleted directly. To delete the promotion."
  } ]
}
```

**Root Cause**: Semver determination logic fell back to seed versions and tried to use a version (3.31.40) that already existed and was part of a promoted Release Bundle v2.

## Solution Architecture

### 1. Unified Semver Determination Script

Created two scripts in `bookverse-demo-init/scripts/`:

- **`semver_versioning.py`**: Core Python logic for querying existing versions and determining next versions
- **`determine-semver.sh`**: Shell wrapper for easy CI integration

### 2. Key Improvements

#### Always Bump Seeds
```python
# Before: Used seed directly (dangerous)
return str(seed)

# After: Always bump seeds to avoid conflicts
return bump_patch(str(seed))
```

#### Proper Repository Querying
- **Docker packages**: Query Docker registry API via `/v2/{repo}/tags/list`
- **Generic packages**: Use AQL (Artifactory Query Language) via `/artifactory/api/search/aql`
- **Applications**: Query AppTrust API `/apptrust/api/v1/applications/{key}/versions`

#### Robust Error Handling
- Graceful fallback when API calls fail
- Proper JSON validation
- Network timeout handling
- Clear error messages

### 3. Deployment Strategy

#### Scripts Distribution
All services now have local copies of the unified scripts:
- `bookverse-inventory/scripts/`
- `bookverse-recommendations/scripts/`
- `bookverse-checkout/scripts/`
- `bookverse-web/scripts/`
- `bookverse-platform/scripts/`

#### CI Integration
Each service CI workflow now uses:
```bash
./scripts/determine-semver.sh \
  --application-key "$APPLICATION_KEY" \
  --version-map "./config/version-map.yaml" \
  --jfrog-url "$JFROG_URL" \
  --jfrog-token "$JF_ACCESS_TOKEN" \
  --project-key "$PROJECT_KEY" \
  --packages "service-name,package-name" \
  --verbose
```

## Technical Details

### Version Resolution Flow

1. **Query Existing Versions**
   - AppTrust API for application versions
   - Docker Registry API for container images
   - AQL for generic repository artifacts

2. **Determine Next Version**
   - If existing versions found: `max(versions) + 1 patch`
   - If no versions found: `seed + 1 patch` (prevents conflicts)

3. **Export to CI Environment**
   - `APP_VERSION`: Application version
   - `BUILD_NUMBER`: Build number
   - `DOCKER_TAG_*`: Package-specific tags

### Example Version Progression

**Scenario**: web-assets package with seed `3.31.50`

1. **First run** (no existing versions):
   - Seed: `3.31.50` → Next: `3.31.51` ✅

2. **Second run** (finds `3.31.51`):
   - Latest: `3.31.51` → Next: `3.31.52` ✅

3. **Conflict avoided**: Never uses exact seed version `3.31.50`

### Repository Naming Patterns

The script correctly handles repository naming:
- **Docker**: `{project}-{service}-internal-docker-nonprod-local`
- **Generic**: `{project}-{service}-internal-generic-nonprod-local`

### Package Type Support

- **`docker`**: Container images with semantic version tags
- **`generic`**: Tar files, assets with version paths like `/web/assets/1.6.14/`

## Configuration

### version-map.yaml Structure
```yaml
applications:
  - key: bookverse-web
    seeds:
      application: 2.4.16
      build: 3.7.25
    packages:
      - type: docker
        name: web
        seed: 1.6.14
      - type: generic
        name: web-assets.tar.gz
        seed: 3.31.50  # Updated to avoid conflicts
```

### Environment Variables
The script sets these variables for CI workflows:
- `APP_VERSION`: Application version
- `BUILD_NUMBER`: Build version
- `IMAGE_TAG`: Defaults to BUILD_NUMBER
- `DOCKER_TAG_{PACKAGE}`: Per-package versions

## Benefits

### Immediate Benefits
- ✅ **No more 409 conflicts**: Seeds are always bumped
- ✅ **Accurate versioning**: Queries existing artifacts
- ✅ **Consistent behavior**: Same logic across all services

### Long-term Benefits
- 🔧 **Maintainable**: Centralized logic in one script
- 📈 **Scalable**: Easy to add new package types
- 🛡️ **Robust**: Comprehensive error handling
- 📊 **Observable**: Verbose logging and clear output

## Migration Impact

### Services Updated
- ✅ bookverse-inventory
- ✅ bookverse-web 
- ⏳ bookverse-recommendations (ready for deployment)
- ⏳ bookverse-checkout (ready for deployment)
- ⏳ bookverse-platform (ready for deployment)

### Backward Compatibility
- Existing version-map.yaml files remain compatible
- Environment variable exports match previous behavior
- CI job outputs unchanged

## Usage Guidelines

### For Developers
1. **Never modify seeds directly** - use the script to determine versions
2. **Check CI logs** for version determination details
3. **Report conflicts** if 409 errors still occur

### For DevOps
1. **Monitor version progression** in JFrog repositories
2. **Update seeds** only when starting new version ranges
3. **Use `--verbose` flag** for troubleshooting

### For CI/CD
```bash
# Install dependencies
pip install PyYAML

# Run unified script
./scripts/determine-semver.sh \
  --application-key "bookverse-{service}" \
  --version-map "./config/version-map.yaml" \
  --jfrog-url "$JFROG_URL" \
  --jfrog-token "$JF_ACCESS_TOKEN" \
  --project-key "$PROJECT_KEY" \
  --packages "{package-list}" \
  --verbose
```

## Monitoring and Troubleshooting

### Success Indicators
- No 409 errors in CI logs
- Sequential version numbers in repositories
- Clear logging of version determination logic

### Common Issues
1. **"No valid seed"**: Check version-map.yaml syntax
2. **"PyYAML required"**: Install Python dependencies
3. **API timeouts**: Check JFrog connectivity

### Debug Commands
```bash
# Test script locally
./scripts/determine-semver.sh --help

# Verify Python dependencies
python3 -c "import yaml; print('OK')"

# Check repository versions
curl -H "Authorization: Bearer $TOKEN" \
  "$JFROG_URL/artifactory/api/search/aql" \
  -d 'items.find({"repo":"bookverse-web-internal-generic-nonprod-local"}).include("name","path")'
```

## Future Enhancements

### Planned Improvements
- 🎯 **Automatic seed bumping**: When conflicts detected
- 📊 **Version analytics**: Track version usage patterns
- 🔄 **Release bundle integration**: Check promotions before versioning
- 🚀 **Performance optimization**: Cache API responses

### Extension Points
- Additional package types (npm, maven, etc.)
- Custom version schemes (CalVer, etc.)
- Integration with other CI systems

---

## Quick Reference

| Component | Location | Purpose |
|-----------|----------|---------|
| `semver_versioning.py` | `scripts/` | Core version logic |
| `determine-semver.sh` | `scripts/` | CI wrapper script |
| `version-map.yaml` | `config/` | Seed versions |
| CI workflows | `.github/workflows/ci.yml` | Integration |

**Last Updated**: 2025-09-12  
**Version**: 1.0.0  
**Status**: ✅ Production Ready
