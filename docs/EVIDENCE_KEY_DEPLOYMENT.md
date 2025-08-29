# Evidence Key Deployment Guide

This guide explains how to deploy evidence keys across the BookVerse demo environment after generation.

## Overview

After generating evidence keys, you need to update:
1. **Repository secrets/variables** - For CI/CD pipelines to use the keys
2. **JFrog Platform trusted keys** - For evidence verification

## Deployment Options

### Option 1: Local Script (Recommended)

Use the provided local script for repository updates:

```bash
./scripts/update_evidence_keys_local.sh \
  --private-key private.pem \
  --public-key public.pem \
  --alias "bookverse_evidence_key"
```

**Benefits:**
- ✅ Uses your GitHub credentials (full permissions)
- ✅ Updates all repositories at once
- ✅ Handles secret-to-variable migration automatically
- ✅ Includes dry-run mode for testing

### Option 2: Manual Repository Updates

Update each repository individually:

#### For each BookVerse repository:
1. Go to repository **Settings** → **Secrets and variables** → **Actions**
2. Update/Create secrets:
   - `EVIDENCE_PRIVATE_KEY` = [Private key content]
3. Update/Create variables:
   - `EVIDENCE_PUBLIC_KEY` = [Public key content]
   - `EVIDENCE_KEY_ALIAS` = [Key alias, e.g., "bookverse_evidence_key"]

#### BookVerse Repositories:
- `bookverse-inventory`
- `bookverse-recommendations`
- `bookverse-checkout`
- `bookverse-platform`
- `bookverse-web`
- `bookverse-helm`
- `bookverse-demo-assets`
- `bookverse-demo-init`

### Option 3: JFrog Platform Update

Use the GitHub Actions workflow:

1. Go to **Actions** → **Evidence Keys Management**
2. Select "Update JFrog Platform"
3. Paste your public key content
4. Set key alias
5. Run workflow

## Local Script Usage

### Prerequisites

```bash
# Install GitHub CLI
brew install gh  # macOS
# or
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update && sudo apt install gh  # Ubuntu

# Authenticate
gh auth login
```

### Basic Usage

```bash
# Update all repositories
./scripts/update_evidence_keys_local.sh \
  --private-key private.pem \
  --public-key public.pem

# With custom alias
./scripts/update_evidence_keys_local.sh \
  --private-key private.pem \
  --public-key public.pem \
  --alias "my_evidence_key_2024"

# Dry run (see what would be changed)
./scripts/update_evidence_keys_local.sh \
  --private-key private.pem \
  --public-key public.pem \
  --dry-run

# Verbose output
./scripts/update_evidence_keys_local.sh \
  --private-key private.pem \
  --public-key public.pem \
  --verbose
```

### Script Features

- ✅ **Key Validation**: Verifies PEM format and key pair matching
- ✅ **Repository Discovery**: Automatically finds accessible repositories
- ✅ **Secret Migration**: Migrates `EVIDENCE_PUBLIC_KEY` from secret to variable
- ✅ **Error Handling**: Clear error messages and recovery suggestions
- ✅ **Dry Run Mode**: Test without making changes
- ✅ **Progress Tracking**: Shows status for each repository

## Manual Process Details

### Repository Secret/Variable Structure

Each repository should have:

| Name | Type | Description | Example |
|------|------|-------------|---------|
| `EVIDENCE_PRIVATE_KEY` | Secret | Private key for signing | `-----BEGIN PRIVATE KEY-----\nMII...` |
| `EVIDENCE_PUBLIC_KEY` | Variable | Public key for verification | `-----BEGIN PUBLIC KEY-----\nMII...` |
| `EVIDENCE_KEY_ALIAS` | Variable | Key identifier | `bookverse_evidence_key` |

### Why Variables for Public Data?

- **Public keys** are not sensitive and can be stored as variables
- **Variables** are visible in workflow logs (helpful for debugging)
- **Private keys** remain as secrets (encrypted and hidden)

## JFrog Platform Integration

### Automatic Upload (Workflow)

The workflow automatically:
1. Validates public key format
2. Uploads to `/artifactory/api/security/keys/trusted`
3. Verifies upload success
4. Lists current trusted keys

### Manual Upload

If needed, upload manually:

```bash
# Extract base64 content (remove headers/footers)
PUBLIC_KEY_B64=$(grep -v "BEGIN\|END" public.pem | tr -d '\n')

# Create payload
cat > payload.json << EOF
{
  "alias": "bookverse_evidence_key",
  "public_key": "$PUBLIC_KEY_B64"
}
EOF

# Upload
curl -X POST \
  -H "Authorization: Bearer $JFROG_TOKEN" \
  -H "Content-Type: application/json" \
  -d @payload.json \
  "$JFROG_URL/artifactory/api/security/keys/trusted"
```

## Verification

### Repository Verification

Check that secrets/variables are set:

```bash
# Check secrets (names only)
gh secret list --repo yonatanp-jfrog/bookverse-inventory

# Check variables
gh variable list --repo yonatanp-jfrog/bookverse-inventory
```

### JFrog Platform Verification

```bash
# List trusted keys
curl -H "Authorization: Bearer $JFROG_TOKEN" \
  "$JFROG_URL/artifactory/api/security/keys/trusted"
```

### Pipeline Verification

Run a test build to ensure:
- Private key is accessible for signing
- Public key is used for verification
- Evidence generation works correctly

## Troubleshooting

### Common Issues

**"Repository not found"**
- Ensure you have access to the repository
- Check GitHub CLI authentication: `gh auth status`

**"Failed to update secret/variable"**
- Verify repository permissions
- Check if you're using the correct organization name

**"Invalid key format"**
- Ensure PEM format with proper headers/footers
- Validate with: `openssl pkey -check -noout -in private.pem`

**"JFrog upload failed"**
- Check JFrog token permissions
- Verify JFrog URL format
- Ensure trusted keys API is accessible

### Debug Mode

Use verbose mode for detailed output:

```bash
./scripts/update_evidence_keys_local.sh \
  --private-key private.pem \
  --public-key public.pem \
  --verbose
```

### Recovery

If deployment fails partway through:
1. Use `--dry-run` to see current state
2. Re-run the script (it's idempotent)
3. Check individual repositories manually
4. Contact platform team if issues persist

## Security Considerations

### Private Key Security
- ✅ Store private keys in password managers
- ✅ Use encrypted storage for key files
- ❌ Never commit private keys to version control
- ❌ Never share private keys in chat/email

### Access Control
- ✅ Limit who can run key updates
- ✅ Use audit logs to track key changes
- ✅ Rotate keys periodically

### Key Rotation
When rotating keys:
1. Generate new key pair
2. Update all repositories with new keys
3. Update JFrog Platform trusted keys
4. Test evidence generation/verification
5. Archive old private key securely
6. Remove old public key from JFrog Platform

## Related Documentation

- [Key Generation Guide](EVIDENCE_KEY_GENERATION.md) - How to generate keys
- [Local Script Reference](../scripts/README.md) - Detailed script documentation
- [JFrog Platform Guide](JFROG_SETUP.md) - JFrog configuration details
- [Troubleshooting Guide](TROUBLESHOOTING.md) - Common issues and solutions
