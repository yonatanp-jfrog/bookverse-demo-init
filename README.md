# BookVerse JFrog Platform Demo - Complete Deployment Guide

A comprehensive demo setup for the BookVerse microservices platform using JFrog Platform (Artifactory + AppTrust). This guide provides step-by-step instructions to deploy a complete microservices demonstration environment.

## 🏗️ Architecture Overview

BookVerse is a complete SaaS solution demonstrating secure software delivery with microservices:

- **📦 Inventory Service** - Manages book inventory and availability
- **🤖 Recommendations Service** - Provides AI-powered book recommendations  
- **💳 Checkout Service** - Handles payment processing and order management
- **🌐 Web UI** - Modern frontend application consuming microservice APIs
- **⎈ Helm Charts** - Kubernetes deployment charts with GitOps integration
- **🚀 Platform Solution** - Combined platform aggregating all microservices

**Key Features:**
- ✅ Zero-trust CI/CD with OIDC authentication (no stored tokens)
- ✅ Automated SBOM generation and vulnerability scanning
- ✅ End-to-end artifact traceability from code to production
- ✅ Multi-stage promotion workflows (DEV → QA → STAGING → PROD)
- ✅ Cryptographic evidence signing and verification
- ✅ GitOps deployment automation

---

## 🚀 Quick Deployment Guide

### Prerequisites Checklist

**Core Demo Requirements** (JFrog Platform + CI/CD Pipeline):

- [ ] **JFrog Platform access** with admin privileges
- [ ] **GitHub organization** with repository creation permissions
- [ ] **GitHub CLI (`gh`)** installed and authenticated
- [ ] **Basic tools**: `curl`, `jq`, `bash`
- [ ] **15-30 minutes** for complete setup

**Optional Kubernetes Extension** (Runtime Deployment Demo):

- [ ] **Kubernetes cluster access** (Rancher Desktop recommended for JFrog employees, or any other local/cloud cluster)
- [ ] **kubectl** and **helm** installed and configured for your cluster
- [ ] **JFrog Artifactory credentials** for pulling BookVerse Docker images (demo user or project member with read access)
- [ ] **Additional 10-15 minutes** for K8s setup

> 💡 **Note**: The core BookVerse demo (JFrog Platform setup, CI/CD pipelines, artifact promotion) works completely **without Kubernetes**. The K8s deployment is an optional extension that demonstrates runtime deployment with GitOps.

### Tool Installation (Mac)

If you need to install the required tools on macOS:

```bash
# Install Homebrew (if not already installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install core tools
brew install curl jq

# Install GitHub CLI
brew install gh

# Optional: Kubernetes tools (if using K8s extension)
brew install kubectl helm
```

**Verify installations:**
```bash
gh --version      # GitHub CLI
curl --version    # Should be installed by default on macOS
jq --version      # JSON processor
kubectl version   # Kubernetes CLI (if installed)
helm version      # Helm package manager (if installed)
```

> 💡 **Other platforms**: For Linux/Windows, see [GitHub CLI](https://cli.github.com/), [kubectl](https://kubernetes.io/docs/tasks/tools/), and [Helm](https://helm.sh/docs/intro/install/) installation guides.

### Step 1: Environment Setup

Set up your deployment environment:

```bash
# 1. Configure JFrog Platform connection
export JFROG_URL="https://your-jfrog-instance.jfrog.io"
export JFROG_ADMIN_TOKEN="your-admin-token"

# 2. Verify connectivity
curl -s --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
  "${JFROG_URL}/artifactory/api/system/ping"
# Expected output: OK

# 3. Configure GitHub CLI (if not already done)
gh auth login
gh auth status  # Verify authentication
```

### Step 2: Deploy Using GitHub Actions (Recommended)

The easiest deployment method uses our automated GitHub Actions workflow:

```bash
# 1. Clone this repository
git clone https://github.com/yonatanp-jfrog/bookverse-demo-init.git
cd bookverse-demo-init

# 2. Set repository variables
gh variable set JFROG_URL --body "$JFROG_URL"
gh secret set JFROG_ADMIN_TOKEN --body "$JFROG_ADMIN_TOKEN"

# 3. Set GitHub token for repository management
gh secret set GH_TOKEN --body "$(gh auth token)"

# 4. If this is a different JFrog instance, run switch platform first (optional)
# gh workflow run "🔄 Switch Platform" -f jfrog_url="$JFROG_URL" -f confirmation="SWITCH"

# 5. Run the complete setup workflow
gh workflow run "🚀 Setup Platform"

# 6. Monitor progress
gh run watch
```

**What this creates:**
- ✅ JFrog project `bookverse` with full configuration
- ✅ Multiple Artifactory repositories for all services and package types
- ✅ AppTrust lifecycle stages (DEV → QA → STAGING → PROD)
- ✅ AppTrust applications with ownership and criticality settings (inventory, recommendations, checkout, platform, web)
- ✅ Custom project roles with specific permissions (including `k8s_image_pull` for container deployment)
- ✅ Demo users with appropriate role assignments
- ✅ OIDC integrations for passwordless GitHub Actions
- ✅ Evidence keys for cryptographic signing and verification

### Step 3: Set Up Service Repositories

Configure variables across all BookVerse service repositories:

```bash
# Set common variables for all service repositories
export GH_TOKEN=$(gh auth token)
export ORG=your-github-org              # Default: your username  
export PROJECT_KEY=bookverse
export DOCKER_REGISTRY=${JFROG_URL#https://}  # Remove https:// prefix to get hostname

# Run the batch variable setup
bash scripts/set_actions_vars.sh
```

> 💡 **Note**: The `${JFROG_URL#https://}` syntax removes the `https://` prefix from your JFrog URL to extract just the hostname (e.g., `your-instance.jfrog.io`) which is needed for Docker registry configuration.

This configures the following repositories:
- `bookverse-inventory`, `bookverse-recommendations`, `bookverse-checkout`
- `bookverse-platform`, `bookverse-web`, `bookverse-helm`

### Step 4: Clone BookVerse Repositories

Clone all the BookVerse service repositories to your local environment:

```bash
# Create a workspace directory for all BookVerse repositories
mkdir -p ~/bookverse-workspace
cd ~/bookverse-workspace

# Clone all BookVerse service repositories
# Replace 'your-org' with your actual GitHub organization
ORG=your-org  # or use: ORG=$(gh api user --jq .login) for personal account

gh repo clone $ORG/bookverse-inventory
gh repo clone $ORG/bookverse-recommendations  
gh repo clone $ORG/bookverse-checkout
gh repo clone $ORG/bookverse-platform
gh repo clone $ORG/bookverse-web
gh repo clone $ORG/bookverse-helm

# Optional: Clone demo assets and this init repository
gh repo clone $ORG/bookverse-demo-assets
gh repo clone $ORG/bookverse-demo-init

# Verify all repositories are cloned
ls -la
```

**Repository Overview:**
- 📦 **bookverse-inventory** - Inventory management microservice
- 🤖 **bookverse-recommendations** - AI recommendation engine
- 💳 **bookverse-checkout** - Payment processing service
- 🚀 **bookverse-platform** - Platform aggregation service
- 🌐 **bookverse-web** - Frontend web application
- ⎈ **bookverse-helm** - Kubernetes deployment charts
- 📁 **bookverse-demo-assets** - Demo materials and GitOps configs
- 🔧 **bookverse-demo-init** - Setup and initialization scripts

> 💡 **Note**: If any repositories don't exist in your organization yet, you'll need to create them from templates or fork them from the reference repositories.

### Step 5: Configure Evidence Keys

Set up cryptographic keys for artifact signing and verification:

```bash
# Generate new keys and deploy to all repositories (recommended)
./scripts/update_evidence_keys.sh --generate

# Alternative: Use existing keys
./scripts/update_evidence_keys.sh \
  --private-key path/to/private.pem \
  --public-key path/to/public.pem
```

**What this does:**
- 🔐 Generates ED25519 key pair (or uses your existing keys)
- 📤 Updates all service repositories with evidence keys
- 🔑 Uploads public key to JFrog Platform trusted keys
- ✅ Validates key format and deployment

### Step 6: Validation and Testing

Verify your complete deployment:

```bash
# Run comprehensive validation
./.github/scripts/setup/validate_setup.sh

# Expected validation results:
# ✅ Project 'bookverse' exists
# ✅ Found multiple repositories for all services
# ✅ Found AppTrust applications (inventory, recommendations, checkout, platform, web)
# ✅ Found OIDC integrations for passwordless authentication
# ✅ Found demo users with appropriate roles
# ✅ GitHub repositories accessible
```

### Step 7: Test the CI/CD Pipeline

Now that you have all repositories cloned, test the CI/CD pipeline:

```bash
# Navigate to one of the service repositories
cd ~/bookverse-workspace/bookverse-inventory

# Make a test change to trigger CI
echo "# Test deployment $(date)" >> README.md
git add README.md
git commit -m "Test: Verify CI/CD pipeline deployment"
git push origin main

# Watch the workflow execution
gh run watch

# You can also check the workflow status
gh run list --limit 5
```

**What to expect:**
- ✅ OIDC authentication to JFrog Platform (no stored tokens)
- ✅ Docker image build and push to internal repository
- ✅ SBOM generation and vulnerability scanning
- ✅ Evidence generation and cryptographic signing
- ✅ AppTrust application version creation

---

## 🛠️ Manual Deployment (Alternative)

If you prefer manual control or need to customize the deployment:

### Step 1: Create JFrog Project and Lifecycle

```bash
# Load configuration
source .github/scripts/setup/config.sh

# Create the BookVerse project
./.github/scripts/setup/create_project.sh

# Create AppTrust stages (DEV, QA, STAGING)
./.github/scripts/setup/create_stages.sh
```

### Step 2: Create Repositories

```bash
# Create service repositories (Docker, Python, etc.)
./.github/scripts/setup/create_repositories.sh

# Create dependency repositories and caches
./.github/scripts/setup/create_dependency_repos.sh
./.github/scripts/setup/prepopulate_dependencies.sh
```

### Step 3: Create Users and Applications

```bash
# Create demo users with appropriate roles
./.github/scripts/setup/create_users.sh

# Create AppTrust applications
./.github/scripts/setup/create_applications.sh
```

### Step 4: Configure Security Integration

```bash
# Set up OIDC integrations for GitHub Actions
./.github/scripts/setup/create_oidc.sh

# Configure evidence keys
./.github/scripts/setup/evidence_keys_setup.sh
```

---

## 🔐 Security Configuration

### GitHub PAT for Repository Dispatch

The platform webhook flow requires a GitHub Personal Access Token:

#### 1. Create Fine-Grained PAT

1. Go to GitHub → Settings → Developer settings → Personal access tokens → Fine-grained tokens
2. Create token with:
   - **Name**: "BookVerse Helm Dispatch"
   - **Repository access**: Only `bookverse-helm`
   - **Permissions**: Contents (Read and write)

#### 2. Configure the Token

```bash
# Set the token as environment variable
export GH_REPO_DISPATCH_TOKEN="your-fine-grained-pat"

# Create Kubernetes secret for platform service
kubectl -n bookverse create secret generic platform-repo-dispatch \
  --from-literal=GITHUB_TOKEN="$GH_REPO_DISPATCH_TOKEN"
```

#### 3. Validate Token

```bash
# Test repository dispatch capability
curl -i \
  -H "Authorization: Bearer $GH_REPO_DISPATCH_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  https://api.github.com/repos/your-org/bookverse-helm/dispatches \
  -d '{"event_type": "release_completed", "client_payload": {"dry_run": true}}'
# Expected: HTTP/1.1 204 No Content
```

### Evidence Key Management

Generate and manage cryptographic keys for evidence signing:

```bash
# Generate ED25519 keys (recommended)
openssl genpkey -algorithm ed25519 -out private.pem
openssl pkey -in private.pem -pubout -out public.pem

# Alternative: RSA 2048-bit
openssl genrsa -out private.pem 2048
openssl rsa -in private.pem -pubout -out public.pem

# Deploy keys to all repositories
./scripts/update_evidence_keys.sh \
  --private-key private.pem \
  --public-key public.pem \
  --alias "bookverse_evidence_key"
```

---

## ⎈ Optional: Kubernetes Runtime Deployment

**This section is completely optional!** The core BookVerse demo (JFrog Platform, CI/CD, artifact promotion) works without Kubernetes. This extension adds runtime deployment demonstration.

Deploy BookVerse to any Kubernetes cluster with Argo CD:

### Prerequisites

**Rancher Desktop (Recommended for JFrog Employees)**

Rancher Desktop is provided to JFrog employees and includes everything needed:

1. **Download Rancher Desktop** from your company software catalog or [rancherdesktop.io](https://rancherdesktop.io)

2. **Install and Configure**:
   - Install Rancher Desktop
   - Launch the application
   - Go to **Preferences** → **Kubernetes**
   - Enable Kubernetes
   - Set memory to at least **4GB** (8GB recommended)
   - Wait for Kubernetes to start (green status indicator)

3. **Verify Installation**:
   ```bash
   # Check Rancher Desktop Kubernetes context
   kubectl config current-context
   # Should show: rancher-desktop
   
   # Verify cluster is running
   kubectl get nodes
   # Should show your local node as Ready
   ```

**Alternative Options**
If you prefer a different setup, you can use any local or cloud Kubernetes cluster instead (Docker Desktop, minikube, EKS, GKE, AKS, etc.). Just ensure `kubectl` and `helm` are configured for your cluster.

### Bootstrap Deployment

```bash
# 1. Verify Rancher Desktop cluster access
kubectl config current-context  # Should show: rancher-desktop
kubectl get nodes              # Should show local node as Ready

# 2. Set JFrog Artifactory registry credentials for pulling BookVerse images
export REGISTRY_SERVER="${JFROG_URL#https://}"  # Extract hostname from JFROG_URL
export REGISTRY_USERNAME='your-jfrog-username'  # JFrog Platform user (see permissions below)
export REGISTRY_PASSWORD='your-jfrog-password'  # User password or access token
export REGISTRY_EMAIL='your-email@example.com'  # Optional: JFrog user email

# 3. Bootstrap Argo CD and deploy BookVerse (this will take 3-5 minutes)
./scripts/k8s/bootstrap.sh --port-forward

# 4. Access applications (for local clusters with port-forward)
# Argo CD UI: https://localhost:8081
# BookVerse Web: http://localhost:8080
```

### What the Bootstrap Script Does

The `bootstrap.sh` script automates the complete Kubernetes deployment setup:

**1. Installs Argo CD**
- Creates `argocd` namespace
- Deploys Argo CD manifests from the official repository
- Waits for Argo CD server to be ready

**2. Sets Up BookVerse Namespace**
- Creates `bookverse-prod` namespace for the application
- Configures the namespace for production deployment

**3. Configures Image Pull Secrets**
- Creates a Docker registry secret (`jfrog-docker-pull`) with your JFrog credentials
- Attaches the secret to the default ServiceAccount
- Enables Kubernetes to pull BookVerse images from JFrog Artifactory

**4. Deploys GitOps Configuration**
- Applies Argo CD AppProject: `gitops/projects/bookverse-prod.yaml`
- Applies Argo CD Application: `gitops/apps/prod/platform.yaml`
- Sets up GitOps automation for continuous deployment

**5. Waits for Application Health**
- Monitors Argo CD application status until it's "Synced" and "Healthy"
- Ensures all BookVerse services are deployed and running

**6. Sets Up Access (with --port-forward flag)**
- Creates local port forwards for easy access:
  - Argo CD UI: `https://localhost:8081`
  - BookVerse Web: `http://localhost:8080`

**Why This is Needed:**
- **GitOps Integration**: Demonstrates how BookVerse integrates with GitOps workflows
- **Production Simulation**: Shows real-world Kubernetes deployment patterns
- **Continuous Deployment**: Argo CD will automatically sync changes from the Git repository
- **Complete Demo**: Provides a running application to demonstrate the full BookVerse platform

**What You'll See During Execution:**
```text
==> Ensuring Argo CD installed in namespace argocd
==> Creating namespace bookverse-prod
==> Creating/updating docker-registry secret in bookverse-prod
==> Applying AppProject (PROD-only)
==> Applying Application for PROD
==> Waiting for Argo CD app to become Synced/Healthy
   Sync=Synced Health=Progressing
   Sync=Synced Health=Healthy
==> Application platform-prod is Synced and Healthy
==> Starting port forwards (Ctrl+C to stop)
```

The script will pause at "Waiting for Argo CD app" while Kubernetes pulls images and starts services. This is normal and may take 2-3 minutes depending on your internet connection and cluster performance.

### JFrog Registry User Requirements

**Option 1: Use Dedicated K8s Pull User (Recommended)**
The setup automatically creates a dedicated Kubernetes user with minimal permissions:
```bash
# Use the dedicated K8s pull user created during setup
export REGISTRY_USERNAME='k8s.pull@bookverse.com'
export REGISTRY_PASSWORD='K8sPull2024!'  # Default password
```
This user has the `k8s_image_pull` project role with read-only access to PROD repositories.

**Option 2: Use BookVerse Project User**
Use one of the demo users created during setup:
```bash
# Example with a demo user that has project access
export REGISTRY_USERNAME='alice.developer@bookverse.com'
export REGISTRY_PASSWORD='BookVerse2024!'  # Default demo password
```

**Option 3: Use Your JFrog Platform User**
Your user needs these **minimum permissions**:
- **Read access** to BookVerse Docker repositories:
  - `bookverse-*-docker-release-local` (PROD images only)
- **Project membership** in the `bookverse` project (custom `k8s_image_pull` project role or Viewer minimum)

**Using Access Tokens (Recommended for Production)**
Instead of passwords, use JFrog access tokens:

**Option A: Generate via API (Recommended)**
```bash
# Generate access token for k8s user programmatically
ACCESS_TOKEN=$(curl -s -X POST \
  --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
  --header "Content-Type: application/json" \
  --data '{
    "username": "k8s.pull@bookverse.com",
    "scope": "applied-permissions/user",
    "expires_in": 31536000,
    "description": "K8s image pull token"
  }' \
  "${JFROG_URL}/access/api/v1/tokens" | jq -r '.access_token')

# Validate token generation was successful
if [[ -z "$ACCESS_TOKEN" || "$ACCESS_TOKEN" == "null" ]]; then
  echo "❌ Failed to generate access token"
  echo "Check your JFROG_ADMIN_TOKEN and ensure k8s.pull@bookverse.com user exists"
  echo "Please fix the issues above and retry the token generation"
else
  echo "✅ Access token generated successfully"
  
  # Test the token works by authenticating with it
  if curl -s --fail --header "Authorization: Bearer $ACCESS_TOKEN" \
     "${JFROG_URL}/artifactory/api/system/ping" >/dev/null; then
    echo "✅ Token authentication verified"
  else
    echo "⚠️  Token generated but authentication test failed"
    echo "Token may have limited permissions (expected for K8s pull user)"
  fi
  
  export REGISTRY_PASSWORD="$ACCESS_TOKEN"  # Use token instead of password
  echo "🔐 REGISTRY_PASSWORD set to generated access token"
fi
```

**Option B: Generate via UI**
```bash
# Generate access token in JFrog Platform UI: User Profile → Access Tokens
export REGISTRY_PASSWORD='your-access-token'  # Instead of password
```

> ⚠️ **Important**: Do **NOT** use your admin token (`JFROG_ADMIN_TOKEN`) for Kubernetes registry access. The admin token is for platform setup only. Use a regular user account or dedicated pull user with minimal read permissions for security.

**Kubernetes Deployment Options:**

**Option 1: Local Development (Rancher Desktop, Docker Desktop, etc.)**
```bash
# Deploy with automatic port-forwarding for local access
./scripts/k8s/bootstrap.sh --port-forward

# This will start local tunnels:
# - Argo CD: https://localhost:8081
# - BookVerse Web: http://localhost:8080
```

**Option 2: Cloud Clusters or Remote Access**
```bash
# Deploy without port-forward 
./scripts/k8s/bootstrap.sh

# Check service endpoints
kubectl -n argocd get svc argocd-server
kubectl -n bookverse-prod get svc bookverse-web

# Access via cluster-specific methods:
# - LoadBalancer: External IP assigned by cloud provider
# - NodePort: Access via cluster node IP and port
# - Ingress: Configure ingress controller for domain access
```

**Access Methods Summary:**
- **Local clusters** (Rancher Desktop): Use `--port-forward` for easy localhost access
- **Cloud clusters**: Use LoadBalancer, NodePort, or Ingress based on your setup
- **Both**: The bootstrap script works the same way, only access method differs

**What this creates:**
- ⎈ Argo CD installation in `argocd` namespace
- 📦 BookVerse PROD deployment in `bookverse-prod` namespace
- 🔗 GitOps integration with automated deployments
- 🌐 Port forwards for easy access

### Get Argo CD Admin Password

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d; echo
```

---

## 🔄 Platform Management

### Switch JFrog Platform

To switch to a different JFrog Platform instance:

```bash
# Option 1: Interactive script
./scripts/switch_jfrog_platform_interactive.sh

# Option 2: GitHub Actions workflow
gh workflow run "🔄 Switch Platform" \
  -f jfrog_url="https://new-instance.jfrog.io" \
  -f admin_token="new-admin-token" \
  -f confirmation="SWITCH"
```

### Update Evidence Keys

Replace evidence keys across all repositories:

```bash
# Generate new keys and update everything
./scripts/update_evidence_keys.sh --generate --key-type ed25519

# Use existing keys with custom alias
./scripts/update_evidence_keys.sh \
  --private-key new-private.pem \
  --public-key new-public.pem \
  --alias "bookverse_2024_key"

# Dry run to preview changes
./scripts/update_evidence_keys.sh --generate --dry-run
```

---

## 🧹 Cleanup and Maintenance

### Complete Environment Cleanup

```bash
# Option 1: GitHub Actions workflow (recommended)
gh workflow run "🗑️ Execute Cleanup" -f confirm_cleanup=DELETE

# Option 2: Local cleanup script
./scripts/cleanup_local.sh

# Option 3: Kubernetes cleanup
./scripts/k8s/cleanup.sh --all
```

### Identity Mappings Cleanup

If project deletion fails due to OIDC identity mappings:

```bash
# Discover problematic mappings
python scripts/identity_mappings.py discover --project bookverse

# Clean up mappings (dry run first)
python scripts/identity_mappings.py cleanup --project bookverse --dry-run
python scripts/identity_mappings.py cleanup --project bookverse

# Clean up project roles
python scripts/project_roles.py cleanup --project bookverse --role-prefix bookverse-
```

---

## 🎭 Demo Usage

### Running a Live Demo

Follow the [Demo Runbook](docs/DEMO_RUNBOOK.md) for step-by-step demo instructions:

1. **Platform Overview** (5 min) - Show BookVerse architecture and JFrog project
2. **CI/CD and OIDC** (10 min) - Demonstrate passwordless authentication and workflows
3. **Artifact Management** (10 min) - Show SBOM generation and vulnerability scanning
4. **AppTrust Lifecycle** (15 min) - Demonstrate promotion workflows DEV→QA→STAGING→PROD
5. **Platform Aggregation** (10 min) - Show microservice coordination and GitOps
6. **Security & Compliance** (10 min) - Highlight audit trails and compliance reporting

### Test Promotion Workflow

```bash
# Trigger promotion from DEV to QA
gh workflow run promote.yml -R yonatanp-jfrog/bookverse-inventory \
  -f target_stage=QA \
  -f version=1.0.0

# Monitor promotion progress
gh run watch -R yonatanp-jfrog/bookverse-inventory
```

---

## 🎛️ Verbosity Control

All scripts support flexible verbosity levels:

```bash
# Silent mode (automation/CI)
export VERBOSITY=0
./scripts/any_script.sh

# Feedback mode (default) - shows progress
export VERBOSITY=1  
./scripts/any_script.sh

# Debug mode - shows all commands and responses
export VERBOSITY=2
./scripts/any_script.sh
```

**Verbosity Levels:**
- **Level 0 (Silent)**: No output, commands execute silently, perfect for automation
- **Level 1 (Feedback)**: Shows progress and results, no user interaction required
- **Level 2 (Debug)**: Shows each command before execution, full output, requires confirmations

---

## 📋 What Gets Created

### Complete Resource Inventory

| Resource Type | Count | Examples |
|---------------|-------|----------|
| **JFrog Projects** | 1 | `bookverse` |
| **AppTrust Stages** | 3 | `bookverse-DEV`, `bookverse-QA`, `bookverse-STAGING` |
| **Repositories** | Multiple | Service repos for Docker, Python, npm, Maven, Helm |
| **Applications** | 5 | inventory, recommendations, checkout, platform, web |
| **Users** | Multiple | Developers, managers, pipeline users with different roles |
| **OIDC Integrations** | Multiple | GitHub Actions authentication for each service |
| **GitHub Repositories** | Multiple | All service repos + helm + demo assets |

### Repository Structure

**Naming Convention**: `{project}-{service}-{package}-{stage}-local`

**Examples:**
- `bookverse-inventory-internal-docker-nonprod-local` (DEV/QA/STAGING)
- `bookverse-inventory-internal-docker-release-local` (PROD)
- `bookverse-recommendations-internal-python-nonprod-local`
- `bookverse-helm-internal-helm-nonprod-local`

---

## 🔧 Troubleshooting

### Common Issues and Solutions

#### Authentication Problems

**Problem**: HTTP 401 (Unauthorized)
```bash
# Check token validity
curl -s --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
  "${JFROG_URL}/artifactory/api/system/ping"

# Verify token has admin permissions
curl -s --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
  "${JFROG_URL}/access/api/v1/projects" | jq .
```

**Problem**: GitHub CLI not authenticated
```bash
gh auth login
gh auth status
gh auth refresh  # If token expired
```

#### Resource Creation Issues

**Problem**: HTTP 409 (Conflict) - Resource already exists
- This is normal for re-runs and scripts handle it gracefully
- Scripts are designed to be idempotent

**Problem**: Project deletion fails
```bash
# Check for OIDC identity mappings
python scripts/identity_mappings.py discover --project bookverse

# Clean up mappings first, then retry project deletion
python scripts/identity_mappings.py cleanup --project bookverse
```

#### Pipeline Issues

**Problem**: OIDC authentication fails in GitHub Actions
- Verify repository variables are set: `PROJECT_KEY`, `JFROG_URL`
- Check OIDC integration exists in JFrog Platform
- Ensure subject claims match repository patterns

**Problem**: Evidence signing fails
```bash
# Check evidence keys are properly deployed
gh variable list -R yonatanp-jfrog/bookverse-inventory
gh secret list -R yonatanp-jfrog/bookverse-inventory

# Re-deploy evidence keys if needed
./scripts/update_evidence_keys.sh --generate
```

### Debug Commands

```bash
# Check project status
curl "${JFROG_URL}/access/api/v1/projects/bookverse" \
  --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}"

# List all repositories
curl "${JFROG_URL}/artifactory/api/repositories" \
  --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" | \
  jq -r '.[] | select(.key | startswith("bookverse")) | .key'

# Check lifecycle configuration
curl "${JFROG_URL}/access/api/v2/lifecycle/?project_key=bookverse" \
  --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}"

# List OIDC integrations
curl "${JFROG_URL}/access/api/v1/oidc" \
  --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" | \
  jq -r '.[] | select(.name | startswith("bookverse")) | .name'
```

### Reset Complete Environment

If you need to start fresh:

```bash
# 1. Clean up everything
gh workflow run "🗑️ Execute Cleanup" -f confirm_cleanup=DELETE

# 2. Wait for cleanup to complete (check in Actions tab)
sleep 60

# 3. Re-run complete setup
gh workflow run "🚀 Setup Platform"

# 4. Verify new setup
./.github/scripts/setup/validate_setup.sh
```

---

## 📚 Additional Resources

### Documentation

- **[Demo Runbook](docs/DEMO_RUNBOOK.md)** - Complete demo presentation guide
- **[Repository Architecture](docs/REPO_ARCHITECTURE.md)** - Technical architecture details
- **[Evidence Key Generation](docs/EVIDENCE_KEY_GENERATION.md)** - Cryptographic key management
- **[Evidence Key Deployment](docs/EVIDENCE_KEY_DEPLOYMENT.md)** - Key deployment procedures
- **[Kubernetes Bootstrap](docs/K8S_ARGO_BOOTSTRAP.md)** - Local K8s deployment guide
- **[Script Documentation](scripts/README.md)** - Detailed script reference

### External Resources

- **[JFrog REST API Documentation](https://jfrog.com/help/r/jfrog-rest-apis)**
- **[JFrog CLI Documentation](https://jfrog.com/help/r/jfrog-cli)**
- **[AppTrust Lifecycle Management](https://jfrog.com/help/r/jfrog-apptrust-lifecycle-management)**
- **[GitHub CLI Documentation](https://cli.github.com/manual/)**

### Support

For issues with this demo:
1. Check the troubleshooting section above
2. Review the validation output for specific errors
3. Consult the detailed documentation in the `docs/` directory
4. Check GitHub Actions logs for workflow failures

---

## ✨ Success Metrics

After successful deployment, you should have:

- ✅ **Zero-trust CI/CD** - No stored secrets, OIDC authentication working
- ✅ **Automated Security** - SBOM generation, vulnerability scanning active
- ✅ **Complete Traceability** - Full audit trail from code commit to production
- ✅ **Promotion Workflows** - DEV→QA→STAGING→PROD lifecycle operational
- ✅ **Evidence Signing** - Cryptographic verification of all artifacts
- ✅ **GitOps Integration** - Automated Kubernetes deployments
- ✅ **Platform Aggregation** - Microservice coordination via AppTrust

**Ready for Demo**: The environment is now ready for live demonstrations, POCs, or development work!

---

*Last Updated: September 2024*  
*Maintainer: DevRel Team*  
*Version: 2.0*