# BookVerse Platform - GitOps Deployment Guide

**Understanding the automated GitOps setup and ArgoCD configuration**

This guide explains what the BookVerse Platform bootstrap script automatically configures for GitOps deployment using ArgoCD. This is for understanding only - everything described here is handled automatically by the Getting Started guide.

---

## 📋 Table of Contents

- [What Gets Automated](#-what-gets-automated)
- [ArgoCD Installation](#-argocd-installation)
- [GitOps Configuration](#-gitops-configuration)
- [Application Deployment](#-application-deployment)
- [Accessing ArgoCD](#-accessing-argocd)
- [Understanding the Setup](#-understanding-the-setup)
- [Troubleshooting](#-troubleshooting)

---

## 🤖 What Gets Automated

When you run the Getting Started guide, the bootstrap script (`./scripts/bookverse-demo.sh --setup`) automatically handles all GitOps configuration. Here's exactly what happens:

### 🔧 **Automatic Setup Steps**

1. **ArgoCD Installation**: Standard ArgoCD deployment in `argocd` namespace
2. **Namespace Creation**: Creates `bookverse-prod` namespace for applications
3. **Registry Secrets**: Configures image pull secrets for JFrog registry access
4. **GitOps Project**: Applies ArgoCD project configuration for BookVerse
5. **Application Deployment**: Creates ArgoCD application pointing to Helm charts
6. **Sync Monitoring**: Waits for applications to become healthy

> **💡 Important**: You don't need to run any commands from this guide - it's all automated!

---

## 🔄 ArgoCD Installation

### What the Bootstrap Script Does

```bash
# 1. Creates ArgoCD namespace
kubectl create ns argocd

# 2. Installs ArgoCD using official manifests
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 3. Waits for ArgoCD server to be ready
kubectl -n argocd rollout status deploy/argocd-server --timeout=180s
```

### ArgoCD Configuration Used

The bootstrap script uses the **standard ArgoCD installation** with:
- Default RBAC settings
- Standard UI and API server
- Built-in repository server
- No custom OIDC configuration (uses admin user)

This is intentionally simple for demo purposes - no complex enterprise configurations needed.

---

## 📋 GitOps Configuration

### Project Configuration

The script applies this simple ArgoCD project:

```yaml
# gitops/projects/bookverse-prod.yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: bookverse-prod
  namespace: argocd
spec:
  description: BookVerse PROD environment (PROD-only GitOps)
  sourceRepos:
    - 'https://github.com/yonatanp-jfrog/bookverse-helm.git'    # Helm charts
    - 'https://github.com/yonatanp-jfrog/bookverse-demo-init.git' # GitOps configs
  destinations:
    - namespace: 'bookverse-prod'
      server: 'https://kubernetes.default.svc'
  clusterResourceWhitelist:
    - group: '*'
      kind: '*'
```

**What this does:**
- Creates an ArgoCD project named `bookverse-prod`
- Allows access to BookVerse repositories
- Permits deployment to `bookverse-prod` namespace
- Allows all Kubernetes resource types (for demo simplicity)

### Application Configuration

The script then applies this ArgoCD application:

```yaml
# gitops/apps/prod/platform.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: platform-prod
  namespace: argocd
spec:
  project: bookverse-prod
  source:
    repoURL: https://github.com/yonatanp-jfrog/bookverse-helm.git
    targetRevision: main
    path: charts/platform
  destination:
    server: https://kubernetes.default.svc
    namespace: bookverse-prod
  syncPolicy:
    automated: {}
    syncOptions:
      - CreateNamespace=true
```

**What this does:**
- Creates an ArgoCD application named `platform-prod`
- Points to the BookVerse Helm charts repository
- Automatically syncs changes from the `main` branch
- Deploys to `bookverse-prod` namespace
- Creates the namespace if it doesn't exist

---

## 🚀 Application Deployment

### Registry Authentication

If registry credentials are provided, the script creates image pull secrets:

```bash
# Creates docker registry secret
kubectl -n bookverse-prod create secret docker-registry jfrog-docker-pull \
  --docker-server="${REGISTRY_SERVER}" \
  --docker-username="${REGISTRY_USERNAME}" \
  --docker-password="${REGISTRY_PASSWORD}"

# Attaches secret to default service account
kubectl -n bookverse-prod patch serviceaccount default \
  -p '{"imagePullSecrets":[{"name":"jfrog-docker-pull"}]}'
```

### Deployment Process

1. **ArgoCD Application Created**: The application definition is applied to ArgoCD
2. **Automatic Sync**: ArgoCD automatically pulls from the Helm repository
3. **Helm Chart Deployment**: ArgoCD deploys the platform Helm chart
4. **Health Monitoring**: ArgoCD monitors application health
5. **Sync Validation**: Bootstrap script waits for "Synced" and "Healthy" status

---

## 🌐 Accessing ArgoCD

### Access Methods

The bootstrap script provides two access modes:

#### **Port Forward Mode** (`--port-forward`)
```bash
# ArgoCD UI
https://localhost:8081

# BookVerse App
http://localhost:8080
```

#### **Resilient Demo Mode** (`--resilient-demo`)
```bash
# ArgoCD UI
https://argocd.demo

# BookVerse App  
http://bookverse.demo
```

### Login Credentials

**Default ArgoCD Login:**
- Username: `admin`
- Password: Get with `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d`

---

## 🔍 Understanding the Setup

### Why This Approach?

The BookVerse demo uses a **simplified GitOps setup** because:

1. **Demo Focus**: Designed for showcasing concepts, not production complexity
2. **Single Environment**: Only PROD environment to keep it simple  
3. **Automated Everything**: No manual steps required for setup
4. **Standard Tools**: Uses vanilla ArgoCD without customizations

### What's NOT Included

Unlike complex production setups, this demo doesn't include:
- OIDC authentication integration
- Multi-environment ApplicationSets
- Complex sync policies and hooks
- Progressive delivery patterns
- Advanced RBAC configurations
- Disaster recovery procedures

### GitOps Principles Applied

Even though simplified, the setup follows GitOps principles:

✅ **Declarative**: All configurations in YAML manifests  
✅ **Versioned**: Stored in Git repositories  
✅ **Immutable**: Container images and configurations are immutable  
✅ **Pulled**: ArgoCD pulls changes, no push access to cluster  
✅ **Auditable**: All changes tracked through Git history  

---

## 🔧 Troubleshooting

### Common Issues

#### **ArgoCD Application Not Syncing**
```bash
# Check application status
kubectl -n argocd get application platform-prod -o yaml

# Check ArgoCD logs
kubectl -n argocd logs deployment/argocd-application-controller
```

#### **Image Pull Failures**
```bash
# Verify registry secret exists
kubectl -n bookverse-prod get secret jfrog-docker-pull

# Check service account configuration
kubectl -n bookverse-prod get serviceaccount default -o yaml
```

#### **Application Pods Not Starting**
```bash
# Check pod status
kubectl -n bookverse-prod get pods

# Check pod logs
kubectl -n bookverse-prod logs <pod-name>

# Check events
kubectl -n bookverse-prod get events --sort-by='.lastTimestamp'
```

### Health Checks

**Verify GitOps Setup:**
```bash
# Check ArgoCD is running
kubectl -n argocd get pods

# Check application is synced
kubectl -n argocd get application platform-prod

# Check application pods
kubectl -n bookverse-prod get pods
```

---

## 🎯 Key Takeaways

1. **Fully Automated**: The Getting Started guide handles all GitOps setup automatically
2. **Simple but Effective**: Uses standard ArgoCD with minimal configuration
3. **Demo Focused**: Optimized for demonstration rather than production complexity
4. **GitOps Compliant**: Follows GitOps principles despite simplicity
5. **No Manual Steps**: Everything is scripted and automated

**Remember**: This guide is for understanding only. The actual setup is handled automatically by running `./scripts/bookverse-demo.sh --setup` from the Getting Started guide.

---

*For the automated setup process, see the [Getting Started Guide](GETTING_STARTED.md).*
