# BookVerse Platform - Evidence Guide

**Complete guide to evidence collection, signing, and verification in the BookVerse demo platform**

This guide covers all aspects of working with evidence in the BookVerse platform, including JFrog AppTrust integration, cryptographic signing, key management, and evidence lifecycle automation.

---

## 📋 Table of Contents

- [Overview](#-overview)
- [Evidence Architecture](#-evidence-architecture)
- [Evidence Types & Configuration](#-evidence-types--configuration)
- [Evidence Collection Implementation](#-evidence-collection-implementation)
- [Key Management](#-key-management)
- [Evidence Templates](#-evidence-templates)
- [Policy-Driven Evidence Requirements](#-policy-driven-evidence-requirements)- [Web UI Integration](#-web-ui-integration)
- [CI/CD Integration](#-cicd-integration)
- [Troubleshooting](#-troubleshooting)
- [Best Practices](#-best-practices)

---

## 🎯 Overview

The BookVerse platform implements **real JFrog AppTrust evidence collection** with cryptographic signing to ensure software supply chain integrity. Our evidence system:

- **Integrates with JFrog AppTrust APIs** for evidence storage and lifecycle management
- **Uses cryptographic signing** with RSA/EC/ED25519 keys for evidence integrity
- **Supports stage-based evidence gates** from UNASSIGNED → DEV → QA → STAGING → PROD
- **Provides automated evidence collection** in CI/CD pipelines
- **Displays evidence transparency** in the web UI trust panel
- **Enables promotion workflows** with evidence-based quality gates

### Key Components

| Component | Description | Location |
|-----------|-------------|----------|
| **Evidence Library** | Core shell functions for evidence operations | `bookverse-infra/libraries/bookverse-devops/scripts/evidence-lib.sh` |
| **Evidence Matrix** | Configuration defining all evidence types | `bookverse-infra/libraries/bookverse-devops/evidence/config/evidence-matrix.yml` |
| **Evidence Templates** | JSON templates for different evidence types | `bookverse-infra/libraries/bookverse-devops/evidence/templates/` |
| **Key Management** | Cryptographic key generation and deployment | `scripts/update_evidence_keys.sh` |
| **Trust Panel** | Web UI for evidence transparency | `bookverse-web/src/trust/panel.js` |
| **AppTrust Clients** | API clients for JFrog AppTrust integration | Multiple `AppTrustClient` implementations |


---

## 🏗️ Evidence Architecture

### Evidence Flow

The BookVerse evidence system follows this flow:

1. **CI/CD Pipeline** triggers evidence collection
2. **Evidence Library** (`evidence-lib.sh`) processes evidence templates
3. **Cryptographic Signing** with RSA/EC/ED25519 keys
4. **JFrog AppTrust** stores evidence with lifecycle management
5. **Quality Gates** validate evidence for stage promotions
6. **Web UI Trust Panel** displays evidence transparency

### Evidence Lifecycle Stages

The BookVerse platform uses the following promotion stages:

1. **UNASSIGNED**: Initial build evidence (SLSA provenance, JIRA releases)
2. **DEV**: Development environment evidence (smoke tests)
3. **QA**: Quality assurance evidence (DAST scans, API tests)
4. **STAGING**: Pre-production evidence (infrastructure scans, penetration tests, change approvals)
5. **PROD**: Production evidence (deployment verification)

Each stage can have **evidence gates** that must be satisfied before promotion to the next stage.

---

## 📊 Evidence Types & Configuration

### Evidence Matrix Structure

Our evidence is organized into three main categories defined in `evidence-matrix.yml`:

#### 1. Package Evidence
Evidence attached to specific packages (Docker images, Python packages, etc.):

```yaml
package_evidence:
  docker:
    - name: "pytest-results"
      predicate_type: "https://pytest.org/evidence/results/v1"
      description: "Unit test results and coverage from pytest"
      required: true
      
    - name: "sast-scan"
      predicate_type: "https://checkmarx.com/evidence/sast/v1.1"
      description: "Static Application Security Testing results"
      required: true
```

#### 2. Build Evidence
Evidence attached to build artifacts:

```yaml
build_evidence:
  - name: "fossa-license-scan"
    predicate_type: "https://fossa.com/evidence/license-scan/v2.1"
    description: "License compliance scan results for all dependencies"
    required: true
    
  - name: "sonar-quality-gate"
    predicate_type: "https://sonarsource.com/evidence/quality-gate/v1"
    description: "Code quality analysis and quality gate results"
    required: true
```

#### 3. Application Evidence
Evidence attached to application versions at specific lifecycle stages:

```yaml
application_evidence:
  unassigned:
    - name: "slsa-provenance"
      predicate_type: "https://slsa.dev/provenance/v1"
      description: "SLSA provenance for supply chain security"
      required: true
      attach_stage: "UNASSIGNED"
      gate_for_promotion_to: "DEV"
```

### Complete Evidence Matrix

| Stage | Evidence Type | Required | Purpose |
|-------|---------------|----------|---------|
| **Package** | pytest-results | ✅ | Unit test coverage |
| **Package** | sast-scan | ✅ | Static security analysis |
| **Build** | fossa-license-scan | ✅ | License compliance |
| **Build** | sonar-quality-gate | ✅ | Code quality |
| **UNASSIGNED** | slsa-provenance | ✅ | Supply chain security |
| **UNASSIGNED** | jira-release | ✅ | Release tracking |
| **DEV** | smoke-tests | ❌ | Basic functionality |
| **QA** | dast-scan | ❌ | Dynamic security testing |
| **QA** | api-tests | ❌ | Integration testing |
| **STAGING** | iac-scan | ✅ | Infrastructure security |
| **STAGING** | pentest | ✅ | Penetration testing |
| **STAGING** | change-approval | ✅ | Change management |
| **PROD** | deployment-verification | ❌ | Production health |


---

## 🔧 Evidence Collection Implementation

### Core Evidence Library (`evidence-lib.sh`)

The evidence library provides shell functions for evidence operations:

#### Key Functions

```bash
# Core evidence creation function
evd_create() {
  local predicate_file="${1}"
  local predicate_type="${2}" 
  local markdown_file="${3:-}"
  
  # Attaches evidence to packages, builds, or release bundles
  # Uses JFrog CLI for AppTrust API integration
}

# Package evidence attachment
attach_package_evidence() {
  local package_name="${1:-$PACKAGE_NAME}"
  local package_version="${2:-$PACKAGE_VERSION}"
  
  # Attach evidence to Docker images or other packages
}

# Application evidence by stage
attach_evidence_for_stage() {
  local stage_name="${1}"
  case "$stage_name" in
    UNASSIGNED) attach_application_unassigned_evidence ;;
    DEV) attach_application_dev_evidence ;;
    QA) attach_application_qa_evidence ;;
    STAGING) attach_application_staging_evidence ;;
    PROD) attach_application_prod_evidence ;;
  esac
}
```

#### Environment Variables

The evidence library auto-configures these variables:

```bash
export SERVICE_NAME="${SERVICE_NAME:-inventory}"
export PROJECT_KEY="${PROJECT_KEY:-bookverse}"
export APPLICATION_KEY="${APPLICATION_KEY:-bookverse-inventory}"
export BUILD_NAME="${BUILD_NAME:-bookverse-inventory_CI_build}"
export BUILD_NUMBER="${BUILD_NUMBER:-1}"
export APP_VERSION="${APP_VERSION:-1.0.0}"
export COVERAGE_PERCENT="${COVERAGE_PERCENT:-85.0}"
```

#### Evidence Attachment Modes

The library supports three attachment modes:

1. **Package Evidence** (`ATTACH_TO_PACKAGE=true`): Attach to Docker images or packages
2. **Build Evidence** (`ATTACH_TO_BUILD=true`): Attach to build artifacts
3. **Application Evidence** (default): Attach to release bundles/application versions

### Usage Examples

#### Basic Evidence Collection

```bash
# Source the evidence library
source /path/to/evidence-lib.sh

# Set environment variables
export SERVICE_NAME="inventory"
export APP_VERSION="1.2.3"
export ATTACH_TO_PACKAGE="true"
export PACKAGE_NAME="bookverse-inventory"
export PACKAGE_VERSION="1.2.3"

# Attach pytest results to Docker image
attach_package_pytest_evidence
```

#### Stage-Based Evidence Collection

```bash
# Attach evidence for DEV stage promotion
attach_evidence_for_stage "DEV"

# Attach evidence for STAGING stage promotion  
attach_evidence_for_stage "STAGING"
```


---

## 🔑 Key Management

### Evidence Key Types

BookVerse supports three cryptographic algorithms for evidence signing:

| Algorithm | Key Size | Performance | Security | Use Case |
|-----------|----------|-------------|----------|----------|
| **RSA** | 2048-bit | Good | Excellent | Broad compatibility |
| **EC** | secp256r1 | Excellent | Excellent | Smaller keys |
| **ED25519** | 256-bit | Excellent | Excellent | Modern, recommended |

### Key Generation

#### Option 1: Automated Script (Recommended)

```bash
# Generate ED25519 keys and update all repositories
./scripts/update_evidence_keys.sh --generate

# Generate RSA keys with custom alias
./scripts/update_evidence_keys.sh --generate --key-type rsa --alias "prod-evidence-2024"

# Test configuration without changes
./scripts/update_evidence_keys.sh --generate --dry-run
```

#### Option 2: Manual Key Generation

**ED25519 Keys (Recommended):**
```bash
# Generate private key
openssl genpkey -algorithm ED25519 -out private.pem

# Extract public key
openssl pkey -in private.pem -pubout -out public.pem
```

**RSA Keys:**
```bash
# Generate private key
openssl genrsa -out private.pem 2048

# Extract public key
openssl rsa -in private.pem -pubout -out public.pem
```

**EC Keys:**
```bash
# Generate private key
openssl ecparam -genkey -name secp256r1 -out private.pem

# Extract public key
openssl ec -in private.pem -pubout -out public.pem
```

### Key Deployment

#### Automated Deployment

The `update_evidence_keys.sh` script automatically:

1. **Generates key pair** (if requested)
2. **Updates GitHub repository secrets/variables** for all BookVerse repositories
3. **Uploads public key to JFrog Platform** for verification
4. **Displays generated keys** for secure storage
5. **Cleans up temporary files**

#### Repository Configuration

For each BookVerse repository, the following secrets/variables are configured:

**Secrets:**
- `EVIDENCE_PRIVATE_KEY`: Private key for signing evidence

**Variables:**
- `EVIDENCE_PUBLIC_KEY`: Public key for verification
- `EVIDENCE_KEY_ALIAS`: Key alias for JFrog platform

#### Manual Repository Updates

If you need to update repositories individually:

1. Go to repository **Settings** → **Secrets and variables** → **Actions**
2. Update/Create secrets:
   - `EVIDENCE_PRIVATE_KEY` = [Private key content]
3. Update/Create variables:
   - `EVIDENCE_PUBLIC_KEY` = [Public key content]
   - `EVIDENCE_KEY_ALIAS` = [Key alias]

#### JFrog Platform Configuration

Public keys are uploaded to JFrog for evidence verification:

```bash
# The script automatically uploads to JFrog
curl -X POST "${JFROG_URL}/artifactory/api/security/keys/trusted" \
  -H "Authorization: Bearer ${JFROG_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "alias": "bookverse-evidence-key",
    "public_key": "-----BEGIN PUBLIC KEY-----\n...\n-----END PUBLIC KEY-----"
  }'
```

### Key Rotation

Evidence keys should be rotated regularly for security:

```bash
# Generate new keys with date-based alias
./scripts/update_evidence_keys.sh --generate --alias "bookverse-evidence-$(date +%Y%m%d)"

# Emergency key rotation
export EMERGENCY_ALIAS="emergency-evidence-$(date +%Y%m%d-%H%M%S)"
./scripts/update_evidence_keys.sh --generate --key-type ed25519 --alias "$EMERGENCY_ALIAS"
```


---

## 📝 Evidence Templates

### Template Structure

Evidence templates are JSON files with variable substitution:

```json
{
  "framework": "pytest",
  "status": "PASSED",
  "serviceName": "${SERVICE_NAME}",
  "version": "${APP_VERSION}",
  "generatedAt": "${NOW_TS}",
  "testResults": {
    "totalTests": 275,
    "passedTests": 270,
    "coverage": "90.5%"
  }
}
```

### Available Templates

The templates are organized by evidence type and stage:

#### Package Evidence Templates

**Docker Package Evidence:**
- `package/docker/pytest-results.json.template`: Unit test results
- `package/docker/sast-scan.json.template`: Static security analysis

**Generic Package Evidence:**
- `package/generic/config-bundle.json.template`: Configuration verification

#### Application Evidence Templates

**UNASSIGNED Stage:**
- `application/unassigned/slsa-provenance.json.template`: SLSA provenance
- `application/unassigned/jira-release.json.template`: Release tracking

**DEV Stage:**
- `application/dev/smoke-tests.json.template`: Basic functionality tests

**QA Stage:**
- `application/qa/dast-scan.json.template`: Dynamic security testing
- `application/qa/api-tests.json.template`: API integration tests

**STAGING Stage:**
- `application/staging/iac-scan.json.template`: Infrastructure security
- `application/staging/pentest.json.template`: Penetration testing
- `application/staging/change-approval.json.template`: Change management

**PROD Stage:**
- `application/prod/deployment-verification.json.template`: Production health

### Template Variables

Templates support the following variable substitutions:

| Variable | Description | Example |
|----------|-------------|---------|
| `${SERVICE_NAME}` | Service name without prefix | `inventory` |
| `${PROJECT_KEY}` | Project identifier | `bookverse` |
| `${APPLICATION_KEY}` | Full application name | `bookverse-inventory` |
| `${APP_VERSION}` | Application version | `1.2.3` |
| `${BUILD_NAME}` | CI build name | `bookverse-inventory_CI_build` |
| `${BUILD_NUMBER}` | CI build number | `42` |
| `${NOW_TS}` | Current ISO timestamp | `2024-01-15T10:30:00Z` |
| `${GITHUB_SHA}` | Git commit SHA | `abc123...` |
| `${GITHUB_REF_NAME}` | Git branch name | `main` |
| `${COVERAGE_PERCENT}` | Test coverage percentage | `85.0` |

### Creating Custom Templates

1. **Create template file** in appropriate directory:
   ```bash
   mkdir -p evidence/templates/custom
   cat > evidence/templates/custom/my-evidence.json.template << 'EOF'
   {
     "customType": "my-test",
     "service": "${SERVICE_NAME}",
     "version": "${APP_VERSION}",
     "result": "PASSED",
     "timestamp": "${NOW_TS}"
   }
   EOF
   ```

2. **Use template in evidence library**:
   ```bash
   # Generate evidence from template
   NOW_TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
   envsubst < evidence/templates/custom/my-evidence.json.template > /tmp/my-evidence.json
   
   # Attach to JFrog AppTrust
   evd_create "/tmp/my-evidence.json" "https://bookverse.com/evidence/custom/v1"
   ```


---

## 🌐 Web UI Integration

### Trust Panel

The BookVerse web application includes a **Trust Panel** that displays evidence transparency to users.

#### Trust Panel Features

- **Evidence Display**: Shows AppTrust evidence from `/.well-known/apptrust/evidence.json`
- **Container Verification**: Displays container images with digest verification
- **Service Status**: Real-time service configuration and health
- **Supply Chain Transparency**: Complete evidence display for users

#### Implementation

The trust panel is implemented in `bookverse-web/src/trust/panel.js`:

```javascript
export async function attachTrustPanel() {
  // Creates floating trust button
  // Fetches evidence from /.well-known/apptrust/evidence.json
  // Displays evidence in modal overlay
  // Shows container images, versions, and evidence
}
```

#### Evidence Integration

The trust panel attempts to fetch evidence from:
```
GET /.well-known/apptrust/evidence.json
```

This endpoint should return evidence data in the format:
```json
{
  "application": {
    "name": "bookverse-inventory",
    "version": "1.2.3"
  },
  "evidence": [
    {
      "type": "pytest-results",
      "status": "PASSED",
      "timestamp": "2024-01-15T10:30:00Z"
    }
  ],
  "containers": [
    {
      "image": "bookverse-inventory:1.2.3",
      "digest": "sha256:abc123..."
    }
  ]
}
```

#### Graceful Fallbacks

If evidence is not available, the trust panel:
- Shows application information without evidence
- Displays service configuration and status
- Provides runtime information and diagnostics

---

## 🔄 CI/CD Integration

### GitHub Actions Integration

Evidence collection is integrated into GitHub Actions workflows using the evidence library.

#### Basic Workflow Integration

```yaml
name: Build and Evidence Collection

on:
  push:
    branches: [ main ]

jobs:
  build-and-evidence:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup JFrog CLI
        uses: jfrog/setup-jfrog-cli@v3
        env:
          JF_URL: ${{ vars.JFROG_URL }}
          JF_ACCESS_TOKEN: ${{ secrets.JFROG_ACCESS_TOKEN }}
      
      - name: Build and Test
        run: |
          # Build application
          docker build -t bookverse-inventory:${{ github.sha }} .
          
          # Run tests and generate evidence
          pytest --cov=app --cov-report=json
      
      - name: Collect Package Evidence
        env:
          SERVICE_NAME: inventory
          APP_VERSION: ${{ github.sha }}
          ATTACH_TO_PACKAGE: "true"
          PACKAGE_NAME: "bookverse-inventory"
          PACKAGE_VERSION: ${{ github.sha }}
          EVIDENCE_PRIVATE_KEY: ${{ secrets.EVIDENCE_PRIVATE_KEY }}
          EVIDENCE_KEY_ALIAS: ${{ vars.EVIDENCE_KEY_ALIAS }}
        run: |
          # Source evidence library
          source libs/bookverse-devops/scripts/evidence-lib.sh
          
          # Attach pytest results
          attach_package_pytest_evidence
          
          # Attach SAST scan results  
          attach_package_sast_evidence
```

#### Environment Variables

CI/CD workflows require these environment variables:

**Required:**
- `JFROG_URL`: JFrog platform URL
- `JFROG_ACCESS_TOKEN`: Access token for JFrog APIs
- `EVIDENCE_PRIVATE_KEY`: Private key for evidence signing
- `EVIDENCE_KEY_ALIAS`: Key alias in JFrog platform

**Optional:**
- `SERVICE_NAME`: Service name (defaults to repo name)
- `PROJECT_KEY`: Project key (defaults to "bookverse")
- `ATTACH_TO_PACKAGE`: Attach evidence to packages
- `ATTACH_TO_BUILD`: Attach evidence to builds

### JFrog AppTrust API Integration

Evidence is attached using JFrog CLI commands:

```bash
# Package evidence
jf evd create-evidence \
  --predicate evidence.json \
  --predicate-type "https://pytest.org/evidence/results/v1" \
  --package-name "bookverse-inventory" \
  --package-version "1.2.3" \
  --package-repo-name "bookverse-inventory-internal-docker-nonprod-local" \
  --project "bookverse" \
  --provider-id github-actions \
  --key "${EVIDENCE_PRIVATE_KEY}" \
  --key-alias "${EVIDENCE_KEY_ALIAS}"

# Application evidence
jf evd create-evidence \
  --predicate evidence.json \
  --predicate-type "https://slsa.dev/provenance/v1" \
  --release-bundle "bookverse-inventory" \
  --release-bundle-version "1.2.3" \
  --project "bookverse" \
  --provider-id github-actions \
  --key "${EVIDENCE_PRIVATE_KEY}" \
  --key-alias "${EVIDENCE_KEY_ALIAS}"
```


---

## 🔍 Troubleshooting

### Common Issues

#### 1. Evidence Attachment Failures

**Symptoms:**
- `❌ Failed to attach evidence to package` errors
- Evidence not visible in JFrog AppTrust

**Diagnosis:**
```bash
# Check JFrog connectivity
jf rt ping

# Verify authentication
jf rt system-info

# Check key configuration
echo "Private key configured: ${EVIDENCE_PRIVATE_KEY:+YES}"
echo "Key alias: ${EVIDENCE_KEY_ALIAS}"
```

**Solutions:**
```bash
# Update JFrog authentication
export JF_URL="https://swampupsec.jfrog.io"
export JF_ACCESS_TOKEN="your-access-token"

# Regenerate evidence keys
./scripts/update_evidence_keys.sh --generate

# Verify key upload to JFrog
curl -H "Authorization: Bearer ${JF_ACCESS_TOKEN}" \
  "${JF_URL}/artifactory/api/security/keys/trusted"
```

#### 2. Key Configuration Issues

**Symptoms:**
- "Check EVIDENCE_PRIVATE_KEY and EVIDENCE_KEY_ALIAS configuration" errors
- Signature verification failures

**Diagnosis:**
```bash
# Check key format
echo "${EVIDENCE_PRIVATE_KEY}" | head -1
# Should show: -----BEGIN PRIVATE KEY-----

# Verify key alias exists in JFrog
curl -H "Authorization: Bearer ${JF_ACCESS_TOKEN}" \
  "${JF_URL}/artifactory/api/security/keys/trusted/${EVIDENCE_KEY_ALIAS}"
```

**Solutions:**
```bash
# Regenerate and deploy keys
./scripts/update_evidence_keys.sh --generate --key-type ed25519

# Manually update repository secrets
gh secret set EVIDENCE_PRIVATE_KEY --body "$(cat private.pem)"
gh variable set EVIDENCE_KEY_ALIAS --body "bookverse-evidence-key"
```

#### 3. Template Processing Errors

**Symptoms:**
- Variables not substituted in evidence templates
- Invalid JSON in generated evidence

**Diagnosis:**
```bash
# Check environment variables
env | grep -E "(SERVICE_NAME|APP_VERSION|PROJECT_KEY)"

# Test template processing
envsubst < template.json.template
```

**Solutions:**
```bash
# Set missing environment variables
export SERVICE_NAME="inventory"
export APP_VERSION="1.2.3"
export PROJECT_KEY="bookverse"

# Validate JSON output
envsubst < template.json.template | jq .
```

### Debug Mode

Enable debug output for troubleshooting:

```bash
# Enable verbose JFrog CLI output
export JFROG_CLI_LOG_LEVEL=DEBUG

# Enable evidence library debug mode
export EVIDENCE_DEBUG=true

# Run with verbose output
bash -x ./scripts/evidence-operation.sh
```


---

## ✅ Best Practices

### Evidence Collection

1. **Collect Early and Often**: Attach evidence at every significant step in the pipeline
2. **Use Meaningful Evidence**: Ensure evidence provides real value for security and compliance
3. **Stage-Appropriate Evidence**: Attach evidence appropriate for each lifecycle stage
4. **Automate Collection**: Use CI/CD integration for consistent evidence collection
5. **Validate Evidence**: Always verify evidence is correctly attached and signed

### Key Management

1. **Regular Rotation**: Rotate evidence keys every 90 days minimum
2. **Secure Storage**: Store private keys securely, never in code repositories
3. **Algorithm Choice**: Use ED25519 for new deployments, RSA for compatibility
4. **Key Backup**: Maintain secure backups of evidence keys
5. **Access Control**: Limit access to evidence signing keys to authorized systems

### Template Management

1. **Version Templates**: Keep evidence templates under version control
2. **Validate Templates**: Test template processing before deployment
3. **Standard Formats**: Use consistent formats across all evidence types
4. **Documentation**: Document custom evidence types and their purpose
5. **Schema Validation**: Validate evidence JSON against schemas when possible

### CI/CD Integration

1. **Fail Fast**: Fail builds if evidence attachment fails
2. **Parallel Collection**: Collect evidence in parallel with other build steps
3. **Error Handling**: Provide clear error messages for evidence failures
4. **Retry Logic**: Implement retry logic for transient failures
5. **Environment Separation**: Use different keys for different environments

### Monitoring and Maintenance

1. **Monitor Evidence Health**: Track evidence collection success rates
2. **Audit Evidence**: Regularly audit attached evidence for completeness
3. **Performance Monitoring**: Monitor impact of evidence collection on build times
4. **Compliance Tracking**: Track evidence against compliance requirements
5. **Regular Updates**: Keep evidence library and templates up to date

---

## 🔗 Related Documentation

- [JFrog CLI Documentation](https://jfrog.com/help/r/jfrog-cli) - Official JFrog CLI reference including evidence commands
- [JFrog Platform Trust & Compliance](https://jfrog.com/compliance/) - JFrog security and compliance practices
- [SLSA Framework](https://slsa.dev/) - Supply-chain Levels for Software Artifacts
- [Sigstore](https://www.sigstore.dev/) - Software signing and verification
- [NIST SSDF](https://csrc.nist.gov/Projects/ssdf) - Secure Software Development Framework

### BookVerse Documentation

- [Architecture Guide](ARCHITECTURE.md) - Overall platform architecture
- [OIDC Authentication](OIDC_AUTHENTICATION.md) - Authentication setup
- [JFrog Integration](JFROG_INTEGRATION.md) - JFrog platform configuration
- [AppTrust Lifecycle](APPTRUST_LIFECYCLE.md) - Application lifecycle management

---

## 📞 Support

For issues with evidence collection:

1. **Check this guide** for troubleshooting steps
2. **Review logs** from CI/CD pipelines and JFrog platform
3. **Validate configuration** using provided diagnostic commands
4. **Test with debug mode** enabled for detailed output

---

*This evidence guide covers the complete BookVerse evidence collection system with real JFrog AppTrust integration, cryptographic signing, and automated CI/CD workflows for software supply chain security.*
