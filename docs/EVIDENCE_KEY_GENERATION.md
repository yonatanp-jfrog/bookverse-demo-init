# Evidence Key Generation Guide

This guide explains how to generate cryptographic key pairs for evidence signing and verification in the BookVerse demo environment.

## Overview

Evidence keys are used to cryptographically sign and verify build artifacts and deployment evidence. BookVerse supports three key algorithms:

- **RSA 2048-bit**: Widely supported, good performance
- **EC secp256r1**: Smaller keys, excellent security
- **ED25519**: Modern, fast, and secure

## Key Generation Methods

### Option 1: Use Local Script (Recommended)

The easiest way to generate and deploy keys is using our local script:

```bash
# Generate ED25519 keys and update all repositories
./scripts/update_evidence_keys.sh --generate

# Generate RSA keys and update all repositories
./scripts/update_evidence_keys.sh --generate --key-type rsa

# Generate EC keys and update all repositories  
./scripts/update_evidence_keys.sh --generate --key-type ec
```

This automatically:
- Generates the key pair
- Updates all BookVerse repositories
- Shows you the keys to save securely
- Cleans up temporary files

### Option 2: Generate Keys Locally with OpenSSL

#### RSA 2048-bit Key Pair

```bash
# Generate private key
openssl genrsa -out private.pem 2048

# Extract public key
openssl rsa -in private.pem -pubout -out public.pem
```

#### EC secp256r1 Key Pair

```bash
# Generate private key
openssl ecparam -name secp256r1 -genkey -noout -out private.pem

# Extract public key
openssl ec -in private.pem -pubout > public.pem
```

#### ED25519 Key Pair

```bash
# Generate private key
openssl genpkey -algorithm ed25519 -out private.pem

# Extract public key
openssl pkey -in private.pem -pubout -out public.pem
```

## Key Validation

Before using your keys, validate them with OpenSSL:

```bash
# Validate private key
openssl pkey -in private.pem -check -noout

# Validate public key
openssl pkey -in public.pem -pubin -check -noout

# Verify key pair match
diff <(openssl pkey -in private.pem -pubout) public.pem
```

## Key Format Requirements

### Private Key Format
- Must be in PEM format
- Must include `-----BEGIN PRIVATE KEY-----` header
- Must include `-----END PRIVATE KEY-----` footer
- Content must be base64 encoded

### Public Key Format
- Must be in PEM format
- Must include `-----BEGIN PUBLIC KEY-----` header
- Must include `-----END PUBLIC KEY-----` footer
- Content must be base64 encoded

## Example Valid Key Formats

### RSA Private Key
```
-----BEGIN PRIVATE KEY-----
MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQC...
...
-----END PRIVATE KEY-----
```

### EC Private Key
```
-----BEGIN PRIVATE KEY-----
MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQg...
...
-----END PRIVATE KEY-----
```

### ED25519 Private Key
```
-----BEGIN PRIVATE KEY-----
MC4CAQAwBQYDK2VwBCIEIJDsQyTXlcU2MPONSnx8G5VN902D...
-----END PRIVATE KEY-----
```

### Public Key (all algorithms)
```
-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAlw4u...
...
-----END PUBLIC KEY-----
```

## Security Best Practices

### Key Storage
- ✅ Store private keys in secure password managers
- ✅ Use encrypted storage for key files
- ✅ Limit access to private keys
- ❌ Never commit private keys to version control
- ❌ Never share private keys in chat/email

### Key Distribution
- ✅ Public keys can be shared openly
- ✅ Store public keys in repository variables
- ✅ Upload public keys to JFrog Platform trusted keys
- ❌ Never store private keys in repository secrets long-term

### Key Rotation
- 🔄 Rotate keys periodically (recommended: annually)
- 🔄 Generate new keys when team members leave
- 🔄 Update all repositories and platforms when rotating

## Next Steps

After generating your keys:

1. **Save keys securely** - Store private key in password manager
2. **Update repositories** - Use the local script or manual process
3. **Update JFrog Platform** - Use the workflow or manual upload
4. **Verify deployment** - Test evidence signing with new keys

## Related Documentation

- [Repository Update Guide](EVIDENCE_KEY_DEPLOYMENT.md) - How to update repository secrets/variables
- [Local Script Usage](../scripts/README.md) - Using the local update script
- [JFrog Platform Setup](JFROG_SETUP.md) - Manual JFrog configuration

## Troubleshooting

### Common Issues

**"Invalid private key format"**
- Ensure proper PEM headers/footers
- Check for missing newlines
- Validate with `openssl pkey -check`

**"Key pair mismatch"**  
- Re-extract public key from private key
- Verify both keys are from same generation

**"OpenSSL command not found"**
- Install OpenSSL: `brew install openssl` (macOS) or `apt-get install openssl` (Ubuntu)

For additional help, see the [troubleshooting section](TROUBLESHOOTING.md) or contact the platform team.
