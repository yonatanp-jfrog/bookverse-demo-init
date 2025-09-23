# BookVerse Platform - Getting Started Guide

**Complete setup and deployment instructions for the BookVerse microservices platform**

This guide provides step-by-step instructions to deploy BookVerse in your environment, from initial setup through full platform deployment and verification.

---

## 📋 Prerequisites

### 🔑 **Required Access & Accounts**

| Requirement | Description | Purpose |
|-------------|-------------|---------|
| **JFrog Platform** | Admin privileges on Artifactory + AppTrust | Platform provisioning and artifact management |
| **GitHub Organization** | Repository creation permissions | Source code hosting and CI/CD automation |
| **Domain Access** | DNS configuration capability | Platform ingress and service routing |

### 🛠️ **Required Tools**

#### **Core Tools** (Required)
```bash
# Verify installations
gh --version      # GitHub CLI (required: v2.0+)
curl --version    # HTTP client (usually pre-installed)
jq --version      # JSON processor (required: v1.6+)
git --version     # Git client (required: v2.25+)
```

#### **Container Tools** (Optional - for local development)
```bash
docker --version   # Container runtime (v20.10+)
kubectl version    # Kubernetes client (v1.21+)
helm version       # Helm package manager (v3.7+)
```

### 💻 **Tool Installation**

<details>
<summary><strong>📱 macOS Installation</strong></summary>

```bash
# Install Homebrew (if not already installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install core tools
brew install gh curl jq git

# Optional: Container tools
brew install docker kubectl helm

# Verify installations
for tool in gh curl jq git; do
  echo "✓ $tool: $($tool --version | head -1)"
done
```
</details>

<details>
<summary><strong>🐧 Linux Installation (Ubuntu/Debian)</strong></summary>

```bash
# Update package list
sudo apt update

# Install core tools
sudo apt install -y curl jq git

# Install GitHub CLI
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update && sudo apt install -y gh

# Optional: Container tools
curl -fsSL https://get.docker.com -o get-docker.sh && sh get-docker.sh
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```
</details>

<details>
<summary><strong>🪟 Windows Installation (PowerShell)</strong></summary>

```powershell
# Install using winget (Windows Package Manager)
winget install --id GitHub.cli
winget install --id Git.Git
winget install --id jqlang.jq

# Install curl (usually pre-installed on Windows 10+)
# If needed: winget install --id cURL.cURL

# Optional: Container tools
winget install --id Docker.DockerDesktop
winget install --id Kubernetes.kubectl
winget install --id Helm.Helm

# Verify installations
gh --version; git --version; jq --version; curl --version
```
</details>

---

## 🚀 Platform Deployment

### 📥 **Step 1: Repository Setup**

```bash
# 1. Clone the BookVerse platform
git clone https://github.com/your-org/bookverse-platform.git
cd bookverse-platform

# 2. Authenticate with GitHub
gh auth login
gh auth status  # Verify authentication

# 3. Verify directory structure
ls -la
# Expected: README.md, docs/, scripts/, gitops/, .github/
```

### 🔧 **Step 2: Environment Configuration**

Create your environment configuration file:

```bash
# Create configuration file
cat > .env << EOF
# JFrog Platform Configuration
JFROG_URL="https://your-instance.jfrog.io"
JFROG_ADMIN_TOKEN="your-admin-token"

# GitHub Configuration
GITHUB_ORG="your-github-org"
GH_TOKEN="$(gh auth token)"

# Platform Configuration
PROJECT_KEY="bookverse"
DOCKER_REGISTRY="${JFROG_URL#https://}"  # Extracts hostname
PLATFORM_DOMAIN="bookverse.your-domain.com"

# Optional: Kubernetes Configuration
KUBE_CONTEXT="your-k8s-context"
NAMESPACE="bookverse"
EOF

# Load environment variables
source .env
```

### 🏗️ **Step 3: Platform Provisioning**

#### **Automated Setup (Recommended)**

```bash
# Run the automated platform setup
./scripts/setup-platform.sh

# Monitor setup progress
tail -f setup.log
```

#### **Manual Setup (Advanced)**

<details>
<summary><strong>🔧 Manual Setup Steps</strong></summary>

```bash
# 1. Validate environment
./scripts/validate-environment.sh

# 2. Create JFrog project and repositories
./scripts/setup/create-project.sh
./scripts/setup/create-repositories.sh

# 3. Configure AppTrust lifecycle
./scripts/setup/create-stages.sh
./scripts/setup/create-applications.sh

# 4. Setup OIDC authentication
./scripts/setup/create-oidc.sh

# 5. Configure users and permissions
./scripts/setup/create-users.sh
./scripts/setup/create-roles.sh

# 6. Generate evidence keys
./scripts/setup/evidence-keys-setup.sh

# 7. Create GitHub repositories
./scripts/setup/create-repositories.sh

# 8. Configure repository variables
./scripts/configure-repositories.sh
```
</details>

### ✅ **Step 4: Deployment Verification**

```bash
# Run comprehensive validation
./scripts/validate-platform.sh

# Expected output:
# ✅ JFrog Platform connectivity verified
# ✅ Project 'bookverse' configured successfully
# ✅ Found 14 repositories across all package types
# ✅ Found 4 applications with lifecycle stages
# ✅ Found 5 OIDC integrations configured
# ✅ GitHub repositories created and configured
# ✅ CI/CD pipelines ready for deployment
```

---

## ☸️ Kubernetes Deployment (Optional)

### 🎯 **Prerequisites for Kubernetes**

- Kubernetes cluster (v1.21+) with admin access
- kubectl configured and authenticated
- Helm 3.7+ installed
- Ingress controller configured
- DNS configuration capability

### 🚀 **Kubernetes Setup**

```bash
# 1. Verify Kubernetes access
kubectl cluster-info
kubectl get nodes

# 2. Create namespace
kubectl create namespace bookverse
kubectl config set-context --current --namespace=bookverse

# 3. Install ArgoCD
./scripts/k8s/bootstrap.sh

# 4. Configure ingress
./scripts/k8s/configure-ingress.sh

# 5. Deploy platform services
helm upgrade --install bookverse-platform ./charts/platform \
  --namespace bookverse \
  --set global.domain=$PLATFORM_DOMAIN \
  --set global.registry=$DOCKER_REGISTRY

# 6. Verify deployment
kubectl get pods -n bookverse
kubectl get ingress -n bookverse
```

### 🌐 **Access URLs**

After successful Kubernetes deployment:

```bash
# Display access URLs
echo "Platform Dashboard: https://$PLATFORM_DOMAIN"
echo "API Documentation: https://api.$PLATFORM_DOMAIN/docs"
echo "ArgoCD Interface: https://argocd.$PLATFORM_DOMAIN"
echo "Monitoring: https://monitoring.$PLATFORM_DOMAIN"
```

---

## 🔐 Security Configuration

### 🔑 **OIDC Authentication Setup**

BookVerse uses OIDC for zero-trust CI/CD authentication:

```bash
# Verify OIDC configuration
./scripts/validate-oidc.sh

# Expected OIDC integrations:
# ✅ github-bookverse-inventory
# ✅ github-bookverse-recommendations  
# ✅ github-bookverse-checkout
# ✅ github-bookverse-platform
# ✅ github-bookverse-web
```

### 🔏 **Evidence Key Management**

```bash
# Generate evidence signing keys
./scripts/setup/evidence-keys-setup.sh

# Verify key deployment
./scripts/validate-evidence-keys.sh

# Output shows:
# ✅ Private key securely stored in JFrog
# ✅ Public key configured for verification
# ✅ Evidence collection enabled for all applications
```

### 🛡️ **Security Validation**

```bash
# Run security validation
./scripts/validate-security.sh

# Checks performed:
# ✅ OIDC token exchange working
# ✅ Repository permissions configured
# ✅ Evidence signing functional
# ✅ SBOM generation enabled
# ✅ Vulnerability scanning active
```

---

## 🧪 Platform Testing

### 🔄 **CI/CD Pipeline Testing**

```bash
# Test service CI/CD pipelines
./scripts/test-pipelines.sh

# This will:
# 1. Trigger builds for all services
# 2. Verify artifact creation
# 3. Test promotion workflows
# 4. Validate evidence collection
```

### 📊 **End-to-End Testing**

```bash
# Run comprehensive E2E tests
./scripts/test-e2e.sh

# Test scenarios:
# ✅ Service deployment and health checks
# ✅ Inter-service communication
# ✅ API endpoint functionality
# ✅ Database connectivity
# ✅ Authentication flows
# ✅ Order processing workflows
```

### 🌐 **Web Application Testing**

```bash
# Test web application deployment
curl -s https://$PLATFORM_DOMAIN/health | jq

# Expected response:
# {
#   "status": "healthy",
#   "services": {
#     "inventory": "up",
#     "recommendations": "up", 
#     "checkout": "up",
#     "platform": "up"
#   },
#   "version": "1.0.0"
# }
```

---

## 🎯 Next Steps

### 🏗️ **Development Setup**

Ready to start developing? Set up your local environment:

```bash
# Follow the development setup guide
cat docs/development/LOCAL_DEVELOPMENT.md
```

### 📚 **Explore the Platform**

- **📖 [Architecture Guide](ARCHITECTURE.md)** - Understanding system design
- **🔧 [Operations Guide](operations/)** - Platform management and monitoring
- **📝 [API Documentation](api/)** - Service APIs and integration patterns
- **🧪 [Testing Guide](development/TESTING.md)** - Testing strategies and frameworks

### 🔧 **Configuration & Customization**

- **⚙️ [Configuration Reference](CONFIGURATION.md)** - Environment and service configuration
- **🎨 [Customization Guide](CUSTOMIZATION.md)** - Adapting BookVerse for your needs
- **🔌 [Integration Patterns](INTEGRATION.md)** - Connecting with external systems

---

## 🆘 Troubleshooting

### 🔍 **Common Setup Issues**

<details>
<summary><strong>❌ JFrog connectivity issues</strong></summary>

**Problem**: Cannot connect to JFrog Platform

**Solutions**:
```bash
# 1. Verify URL format (must include https://)
echo $JFROG_URL  # Should be: https://your-instance.jfrog.io

# 2. Test connectivity
curl -s -H "Authorization: Bearer $JFROG_ADMIN_TOKEN" "$JFROG_URL/artifactory/api/system/ping"
# Expected: OK

# 3. Verify token permissions
./scripts/validate-token.sh
```
</details>

<details>
<summary><strong>❌ GitHub authentication problems</strong></summary>

**Problem**: GitHub CLI authentication fails

**Solutions**:
```bash
# 1. Re-authenticate with GitHub
gh auth logout
gh auth login --with-token < your-token-file

# 2. Verify authentication and permissions
gh auth status
gh repo list --limit 1  # Test API access

# 3. Check organization membership
gh api user/orgs | jq '.[].login'
```
</details>

<details>
<summary><strong>❌ Repository creation failures</strong></summary>

**Problem**: Cannot create GitHub repositories

**Solutions**:
```bash
# 1. Verify organization permissions
gh api orgs/$GITHUB_ORG/members/$GITHUB_USERNAME

# 2. Check repository limits
gh api orgs/$GITHUB_ORG | jq '.plan'

# 3. Manual repository creation
./scripts/setup/create-repositories.sh --manual --repo inventory
```
</details>

### 📞 **Getting Help**

- **📖 [Troubleshooting Guide](TROUBLESHOOTING.md)** - Comprehensive issue resolution
- **🐛 [Issue Tracker](../../issues)** - Report bugs and request features  
- **💬 [Discussions](../../discussions)** - Community support and questions
- **📧 Support**: For enterprise support, contact support@bookverse.com

---

## ✅ Deployment Checklist

Use this checklist to ensure successful platform deployment:

### 🔧 **Prerequisites**
- [ ] JFrog Platform access with admin privileges
- [ ] GitHub organization with repository creation permissions
- [ ] Required tools installed and verified
- [ ] Environment configuration completed

### 🏗️ **Platform Setup**
- [ ] BookVerse repository cloned and configured
- [ ] Environment variables configured in `.env`
- [ ] JFrog project and repositories created
- [ ] AppTrust lifecycle and applications configured
- [ ] OIDC integrations created and tested

### 🔐 **Security Configuration**
- [ ] Evidence keys generated and deployed
- [ ] Repository permissions configured
- [ ] Security validation passed
- [ ] SBOM generation verified

### 🚀 **Deployment Verification**
- [ ] Platform validation script passed
- [ ] All services health checks passing
- [ ] CI/CD pipelines functional
- [ ] Web application accessible
- [ ] API endpoints responding correctly

### ☸️ **Kubernetes (Optional)**
- [ ] Kubernetes cluster access verified
- [ ] ArgoCD installed and configured
- [ ] Platform services deployed
- [ ] Ingress configuration working
- [ ] DNS records configured

**🎉 Congratulations! Your BookVerse platform is ready for use.**

---

*Need help? Check our [comprehensive documentation](../README.md) or reach out to the [BookVerse community](../../discussions).*
