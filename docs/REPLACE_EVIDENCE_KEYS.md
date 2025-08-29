# Replace Evidence Keys Workflow

## Overview

The **Replace Evidence Keys** workflow allows you to update all BookVerse repositories with custom evidence keys for signing and verifying evidence. This workflow replaces the automatic key generation with user-provided key pairs.

## 🔑 Key Generation

Before using the workflow, you need to generate a cryptographic key pair. You can choose from several key types:

### RSA Key Pair (2048-bit)
```bash
openssl genrsa -out private.pem 2048
openssl rsa -in private.pem -pubout -out public.pem
```

### Elliptic Curve Key Pair (secp256r1)
```bash
openssl ecparam -name secp256r1 -genkey -noout -out private.pem
openssl ec -in private.pem -pubout > public.pem
```

### ED25519 Key Pair (Recommended)
```bash
openssl genpkey -algorithm ed25519 -out private.pem
openssl pkey -in private.pem -pubout -out public.pem
```

> **💡 Recommendation**: ED25519 keys are recommended for their security, performance, and compact size.

## 🚀 Using the Workflow

### Step 1: Access the Workflow

1. Navigate to the **bookverse-demo-init** repository
2. Go to **Actions** → **Replace Evidence Keys**
3. Click **Run workflow**

### Step 2: Provide Key Content

The workflow requires the following inputs:

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| **Private Key Content** | Complete content of `private.pem` file | ✅ Yes | - |
| **Public Key Content** | Complete content of `public.pem` file | ✅ Yes | - |
| **Key Alias** | Identifier for the key in JFrog Platform | ❌ No | `bookverse_evidence_key` |
| **Update JFrog Platform** | Whether to upload key to JFrog trusted keys | ❌ No | `true` |

### Step 3: Copy Key Contents

1. **For Private Key Content:**
   ```bash
   cat private.pem
   ```
   Copy the entire output (including `-----BEGIN...` and `-----END...` lines)

2. **For Public Key Content:**
   ```bash
   cat public.pem
   ```
   Copy the entire output (including `-----BEGIN...` and `-----END...` lines)

### Step 4: Run the Workflow

1. Paste the private key content into the **Private Key Content** field
2. Paste the public key content into the **Public Key Content** field
3. Optionally customize the **Key Alias** (default: `bookverse_evidence_key`)
4. Click **Run workflow**

## 📋 What the Workflow Does

### 1. Validation Phase
- ✅ Validates private key format
- ✅ Validates public key format  
- ✅ Verifies that private and public keys match
- ✅ Identifies key type (RSA, EC, ED25519)

### 2. Repository Updates
Updates all 8 BookVerse repositories:
- `bookverse-inventory`
- `bookverse-recommendations`
- `bookverse-checkout`
- `bookverse-platform`
- `bookverse-web`
- `bookverse-helm`
- `bookverse-demo-assets`
- `bookverse-demo-init`

**For each repository:**
- 🔒 **EVIDENCE_PRIVATE_KEY** → Updated as **secret**
- 📄 **EVIDENCE_PUBLIC_KEY** → Updated as **variable**
- 🏷️ **EVIDENCE_KEY_ALIAS** → Updated as **variable**

### 3. JFrog Platform Integration
- 📤 Uploads public key to JFrog Platform trusted keys registry
- 🔗 Associates key with the specified alias
- ✅ Enables evidence verification across the platform

### 4. Verification Phase
- 🔍 Verifies secrets and variables were created in all repositories
- 📊 Provides detailed summary of changes
- ✅ Confirms successful deployment

## 🎯 Expected Outcomes

### GitHub Repository Updates
After successful execution, all BookVerse repositories will have:

```yaml
# Secrets (encrypted)
EVIDENCE_PRIVATE_KEY: [Your private key content]

# Variables (accessible in workflows)
EVIDENCE_PUBLIC_KEY: [Your public key content]
EVIDENCE_KEY_ALIAS: bookverse_evidence_key
```

### JFrog Platform Integration
Your public key will be registered in JFrog Platform as a trusted key:

```json
{
  "kid": "abc123",
  "fingerprint": "xx:xx:xx:xx:xx:xx:xx:xx",
  "alias": "bookverse_evidence_key",
  "key": "-----BEGIN PUBLIC KEY-----\n...\n-----END PUBLIC KEY-----",
  "issued_on": "2024-01-01T00:00:00.000Z",
  "issued_by": "your@email.com"
}
```

### Evidence Signing & Verification
- 🖊️ **Evidence Signing**: Workflows will use the new private key
- 🔍 **Evidence Verification**: JFrog Platform will trust the new public key
- 📋 **Key Alias**: Evidence will be associated with your custom alias

## 🔧 Troubleshooting

### Key Format Issues
If you encounter key format errors:

1. **Check file contents**: Ensure you copied the complete key including headers/footers
2. **Verify key pair**: Ensure both keys were generated together
3. **Test locally**: Validate keys work with OpenSSL:
   ```bash
   openssl pkey -in private.pem -check
   openssl pkey -in public.pem -pubin -check
   ```

### Repository Access Issues
If repository updates fail:
- Ensure your GitHub token has sufficient permissions
- Verify all repositories exist and are accessible
- Check organization settings for secret/variable management

### JFrog Platform Issues  
If JFrog Platform upload fails:
- Verify `JFROG_URL` and `JFROG_ADMIN_TOKEN` are correctly configured
- Check network connectivity to JFrog Platform
- Ensure admin token has trusted key management permissions

## 🔄 Key Rotation

To rotate evidence keys:

1. Generate new key pair using the commands above
2. Run the **Replace Evidence Keys** workflow with new keys
3. Verify evidence generation works with new keys
4. Update any external systems that rely on the old public key

## 🛡️ Security Best Practices

- 🚫 **Never commit private keys** to version control
- 🔒 **Store private keys securely** on your local machine
- 🗑️ **Delete temporary key files** after uploading
- 🔄 **Rotate keys regularly** (e.g., annually)
- 🔍 **Monitor key usage** in JFrog Platform logs
- 📋 **Document key changes** for audit purposes

## 📞 Support

If you encounter issues with the evidence key replacement workflow:

1. Check the workflow run logs for detailed error messages
2. Verify key format and compatibility
3. Ensure all prerequisites are met
4. Review the troubleshooting section above

The workflow provides comprehensive logging and error reporting to help diagnose any issues.
