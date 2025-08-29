# BookVerse Scripts

This directory contains scripts for managing the BookVerse demo environment.

## Evidence Key Management

### update_evidence_keys_local.sh

Local script for updating evidence keys across all BookVerse repositories.

**Features:**
- Updates all repositories with a single command
- Uses your GitHub CLI authentication (full permissions)
- Validates key formats and matching before updates
- Migrates `EVIDENCE_PUBLIC_KEY` from secret to variable automatically
- Supports dry-run mode for testing
- Detailed progress reporting and error handling

**Prerequisites:**
```bash
# Install GitHub CLI
brew install gh  # macOS
# or
sudo apt install gh  # Ubuntu

# Authenticate
gh auth login
```

**Usage:**
```bash
# Basic usage
./update_evidence_keys_local.sh \
  --private-key private.pem \
  --public-key public.pem

# With custom alias
./update_evidence_keys_local.sh \
  --private-key private.pem \
  --public-key public.pem \
  --alias "my_evidence_key_2024"

# Dry run (preview changes)
./update_evidence_keys_local.sh \
  --private-key private.pem \
  --public-key public.pem \
  --dry-run

# Verbose output
./update_evidence_keys_local.sh \
  --private-key private.pem \
  --public-key public.pem \
  --verbose

# Help
./update_evidence_keys_local.sh --help
```

**Options:**
- `--private-key <file>` - Path to private key PEM file (required)
- `--public-key <file>` - Path to public key PEM file (required)
- `--alias <name>` - Key alias (default: bookverse_evidence_key)
- `--org <name>` - GitHub organization (default: yonatanp-jfrog)
- `--dry-run` - Show what would be done without making changes
- `--verbose` - Show detailed output
- `--help` - Show usage information

**Repositories Updated:**
- bookverse-inventory
- bookverse-recommendations
- bookverse-checkout
- bookverse-platform
- bookverse-web
- bookverse-helm
- bookverse-demo-assets
- bookverse-demo-init

**What Gets Updated:**
- `EVIDENCE_PRIVATE_KEY` (secret) - Private key for signing
- `EVIDENCE_PUBLIC_KEY` (variable) - Public key for verification
- `EVIDENCE_KEY_ALIAS` (variable) - Key identifier

## Other Scripts

### JPD Platform Management

- `switch_jpd_platform.sh` - Switch to different JFrog Platform instance
- `switch_jpd_interactive.sh` - Interactive JPD switching

### Environment Setup  

- `evidence_keys_setup.sh` - Initial evidence key setup
- Various cleanup and initialization scripts

## Security Notes

- ✅ Scripts use your local GitHub authentication
- ✅ Private keys are never stored or logged
- ✅ All operations are auditable through GitHub
- ❌ Never run scripts with untrusted key files
- ❌ Never commit private keys to version control

## Troubleshooting

**"GitHub CLI not authenticated"**
```bash
gh auth login
gh auth status  # Verify
```

**"Repository not found"**
- Ensure you have access to the repository
- Check organization name is correct

**"Invalid key format"**
```bash
# Validate your keys
openssl pkey -in private.pem -check -noout
openssl pkey -in public.pem -pubin -check -noout
```

**"Permission denied"**
- Ensure script is executable: `chmod +x update_evidence_keys_local.sh`
- Check repository permissions in GitHub

For more help, see the [troubleshooting guide](../docs/EVIDENCE_KEY_DEPLOYMENT.md#troubleshooting).
