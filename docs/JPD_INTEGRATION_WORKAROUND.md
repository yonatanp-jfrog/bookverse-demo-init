# JPD Integration Workaround Documentation

## Overview

This document describes a temporary workaround implemented to address a critical bug in JFrog Platform (JPD) that prevents OIDC integrations from working correctly with project-specific roles.

## The Problem

The intended design uses:
- **Username**: Service-specific users (e.g., `grace.ai@bookverse.com` for recommendations)
- **Scope**: `applied-permissions/roles:bookverse:cicd_pipeline` (project-specific role)

However, due to a JPD bug, this approach is currently not working.

## The Workaround

The temporary workaround uses:
- **Username**: `cicd` (a platform admin user)
- **Scope**: `applied-permissions/admin` (platform admin permissions)

This gives broader permissions than necessary but allows the integrations to function.

## Implementation Details

### Setup Script Changes

**File**: `.github/scripts/setup/create_oidc.sh`

1. **Workaround Configuration**:
   ```bash
   USE_PLATFORM_ADMIN_WORKAROUND="${USE_PLATFORM_ADMIN_WORKAROUND:-true}"
   CICD_TEMP_USERNAME="cicd"
   CICD_TEMP_PASSWORD="CicdTemp2024!"
   ```

2. **Conditional Logic**: The script now creates different identity mappings based on the workaround flag:
   - **Workaround ON** (default): Uses platform admin user `cicd` with `applied-permissions/admin` scope
   - **Workaround OFF**: Uses service-specific users with `applied-permissions/roles:bookverse:cicd_pipeline` scope

3. **User Creation**: When the workaround is enabled, it creates a temporary `cicd` platform admin user.

### Cleanup Script Changes

**File**: `.github/scripts/setup/cleanup_from_report_phase.sh`

- Added `cleanup_cicd_temp_user()` function to remove the temporary cicd user
- The cleanup runs during the `domain_users` phase

## How to Use

### Enable Workaround (Default)
```bash
# This is the default - no action needed
# The workaround is active by default
```

### Test the Correct Method
To test the intended approach once the JPD bug is fixed:
```bash
export USE_PLATFORM_ADMIN_WORKAROUND=false
./.github/scripts/setup/create_oidc.sh
```

### Switch Back to Workaround
```bash
export USE_PLATFORM_ADMIN_WORKAROUND=true
./.github/scripts/setup/create_oidc.sh
```

## Current Status

- ✅ **Web Integration**: Using workaround (manually fixed)
- ✅ **Recommendations Integration**: Using workaround (manually fixed)
- ✅ **All Other Integrations**: Will use workaround by default

## Security Implications

⚠️ **Important**: The workaround grants broader permissions than necessary:
- The `cicd` user has platform admin privileges
- This provides access beyond just the BookVerse project
- This is acceptable as a temporary measure but should be reverted once the bug is fixed

## Reverting the Workaround

Once the JPD integration bug is fixed:

1. **Update the default**:
   ```bash
   # In create_oidc.sh, change:
   USE_PLATFORM_ADMIN_WORKAROUND="${USE_PLATFORM_ADMIN_WORKAROUND:-false}"
   ```

2. **Remove workaround code**:
   - Remove the `create_cicd_temp_user()` function
   - Remove the conditional logic in identity mapping creation
   - Remove the `cleanup_cicd_temp_user()` function from cleanup script

3. **Clean up existing integrations**:
   - Run cleanup to remove existing workaround-based integrations
   - Re-run setup to create correct project role-based integrations

## Files Modified

- `.github/scripts/setup/create_oidc.sh` - Main integration setup with workaround logic
- `.github/scripts/setup/cleanup_from_report_phase.sh` - Cleanup script with cicd user removal
- `docs/JPD_INTEGRATION_WORKAROUND.md` - This documentation

## Testing

### Verify Current Configuration
```bash
# Check current integration setup
curl -s --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
  "${JFROG_URL}/access/api/v1/oidc/bookverse-web-github/identity_mappings" | jq .

# Should show:
# - name: "cicd-temp" 
# - token_spec.username: "cicd"
# - token_spec.scope: "applied-permissions/admin"
```

### Test Integration
```bash
# Test that GitHub Actions can authenticate using the integration
# This would be done in the actual CI/CD pipelines
```

## Monitoring

Watch for these indicators that the bug might be fixed:
- JPD release notes mentioning OIDC integration fixes
- Successful authentication using project role-based scope
- JFrog support confirmation that the issue is resolved

## Contact

- **Bug Reporter**: [User who identified the issue]
- **Workaround Implementer**: AI Assistant
- **JFrog Support Case**: [If applicable]
