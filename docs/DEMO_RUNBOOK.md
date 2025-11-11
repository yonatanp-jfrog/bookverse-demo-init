# BookVerse Demo - Operator Runbook

## Overview

This runbook provides step-by-step instructions for demonstrating JFrog AppTrust capabilities using the BookVerse microservices scenario. The demo showcases secure software delivery across microservices with SBOM generation, artifact signing, and OIDC-based CI/CD.

## Prerequisites

### Required Access
- **JFrog Platform Instance**: Access to a JFrog Platform with AppTrust enabled
- **GitHub Organization**: Write access to repositories under the `yonatanp-jfrog` organization
- **Administrative Privileges**: JFrog admin token for platform setup

### Required Tools
- `gh` CLI (GitHub CLI) - authenticated
- `jq` - JSON processing
- `curl` - API interactions
- `docker` - local testing (optional)

## Demo Environment Status

### ✅ Infrastructure (Complete)
- **JFrog Project**: `bookverse` 
- **Repositories**: 14 repositories across all services and package types
- **Users**: 12 users with appropriate role assignments
- **Stages**: DEV → QA → STAGING → PROD lifecycle
- **Applications**: 4 AppTrust applications (inventory, recommendations, checkout, platform)
- **OIDC**: 5 GitHub integrations configured

### ✅ GitHub Repositories (Complete)
- `bookverse-inventory` - Inventory microservice
- `bookverse-recommendations` - AI/ML recommendations service  
- `bookverse-checkout` - Payment processing service
- `bookverse-platform` - Platform aggregation service
- `bookverse-web` - Frontend web application
- `bookverse-helm` - Kubernetes deployment charts
- `bookverse-demo-assets` - GitOps and demo materials (integrated as subfolder in bookverse-demo-init)

## Demo Preparation

### Step 1: Environment Setup

```bash
# Set required environment variables
export JFROG_URL="https://apptrusttraining1.jfrog.io"
export JFROG_ADMIN_TOKEN=$(cat /Users/yonatanp/playground/JFROG_ADMIN_TOKEN)

# Verify connectivity
curl -s --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
  "${JFROG_URL}/artifactory/api/system/ping"
```

### Step 2: Platform Validation

```bash
cd bookverse-demo-init

# Run comprehensive validation
./.github/scripts/setup/validate_setup.sh

# Expected output:
# ✅ Project 'bookverse' exists
# ✅ Found 14 repositories  
# ✅ Found 4 applications
# ✅ Found 5 OIDC integrations
```

### Step 3: Repository Variables Check

Verify all service repositories have correct variables:

```bash
# Check each repository
for repo in inventory recommendations checkout platform web; do
  echo "Checking bookverse-${repo}..."
  gh variable list -R yonatanp-jfrog/bookverse-${repo}
done

# Expected variables:
# PROJECT_KEY=bookverse
# JFROG_URL=https://apptrusttraining1.jfrog.io  
# DOCKER_REGISTRY=apptrusttraining1.jfrog.io
```

## Demo Flow

### Phase 1: Platform Overview (5 minutes)

**Talking Points:**
- "BookVerse is a microservices-based book recommendation platform"
- "Four core services: inventory, recommendations, checkout, and platform aggregation"
- "Demonstrates end-to-end secure software delivery with JFrog AppTrust"

**Show:**
1. **JFrog Project Structure**
   - Navigate to `bookverse` project in JFrog Platform
   - Show 14 repositories across services and package types
   - Highlight environment-based repository structure

2. **AppTrust Applications**
   - Show 4 applications in AppTrust dashboard
   - Point out application owners and criticality levels
   - Explain microservice → platform aggregation model

### Phase 2: CI/CD and OIDC Security (10 minutes)

**Demonstrate:**
1. **GitHub Repository Structure**
   ```bash
   # Show repository structure
   gh repo view yonatanp-jfrog/bookverse-inventory
   ```

2. **OIDC Integration** 
   - Show GitHub Actions without stored secrets
   - Explain passwordless authentication to JFrog
   - Demonstrate repository-specific permissions

3. **CI Workflow Trigger**
   ```bash
   # Make a small change to trigger CI
   gh repo clone yonatanp-jfrog/bookverse-inventory /tmp/inventory
   cd /tmp/inventory
   echo "# Demo update $(date)" >> README.md
   git add README.md
   git commit -m "Demo: Trigger CI workflow"
   git push origin main
   
   # Watch workflow execution
   gh run watch
   ```

### Phase 3: Artifact Management and SBOM (10 minutes)

**Show in JFrog Platform:**
1. **Published Artifacts**
   - Navigate to `bookverse-inventory-internal-docker-nonprod-local`
   - Show Docker images with metadata
   - Display build info and provenance

2. **SBOM Generation**
   - Show automatically generated SBOMs
   - Explain component analysis
   - Highlight vulnerability scanning results

3. **Repository Environments**
   - Show DEV/QA/STAGING environment restrictions
   - Explain promotion workflow concept

### Phase 4: AppTrust Lifecycle and Promotion (15 minutes)

**Demonstrate:**
1. **Application Versions**
   - Show application versions in AppTrust
   - Explain build → version creation
   - Display metadata and provenance

2. **Promotion Workflow**
   ```bash
   # Trigger promotion workflow
   gh workflow run promote.yml -R yonatanp-jfrog/bookverse-inventory \
     -f target_stage=QA \
     -f version=1.0.0
   
   # Monitor promotion
   gh run watch -R yonatanp-jfrog/bookverse-inventory
   ```

3. **Stage Progression**
   - Show artifact movement: DEV → QA → STAGING → PROD
   - Explain gates and approvals
   - Highlight audit trail

### Phase 5: Platform Aggregation (10 minutes)

**Explain the Model:**
- Individual microservices develop independently
- Platform service aggregates latest PROD versions bi-weekly
- Combined platform application goes through full lifecycle
- GitOps integration updates Kubernetes deployments

**Show:**
1. **Platform Application**
   - Navigate to `bookverse-platform` application
   - Show combined metadata from all microservices
   - Explain aggregation strategy

2. **Helm Charts and GitOps**
   ```bash
   # Show Helm chart structure
   gh repo view yonatanp-jfrog/bookverse-helm
   
   # Show GitOps configuration
   # Demo assets are now in repos/bookverse-demo-assets/ subfolder
   ```

### Phase 6: Security and Compliance (10 minutes)

**Demonstrate:**
1. **Xray Security Scanning**
   - Show security policies
   - Display vulnerability reports
   - Explain license compliance

2. **Audit and Traceability**
   - Show complete artifact lineage
   - Display who, what, when for each change
   - Explain compliance reporting

## Troubleshooting

### Common Issues

**1. OIDC Authentication Failures**
```bash
# Check OIDC integration status
curl -s --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
  "${JFROG_URL}/access/api/v1/oidc" | jq -r '.[] | .name'

# Verify repository variables
gh variable list -R yonatanp-jfrog/bookverse-inventory
```

**2. Workflow Failures**
```bash
# Check recent workflow runs
gh run list -R yonatanp-jfrog/bookverse-inventory --limit 5

# Get detailed logs
gh run view [RUN_ID] --log
```

**3. Missing Artifacts**
```bash
# Verify repository structure
curl -s --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
  "${JFROG_URL}/artifactory/api/repositories" | \
  jq -r '.[] | select(.key | contains("bookverse")) | .key'
```

**4. BookVerse Web Application Issues**

*Problem*: Website shows broken design or can't connect to backend services

*Symptoms*:
- Empty pages or missing content
- Network errors in browser console
- Service connectivity indicators show "n/a"

*Diagnosis*:
```bash
# Check web service status
kubectl -n bookverse-prod get deployment platform-web
kubectl -n bookverse-prod get pods -l app=platform-web

# Verify configuration
kubectl -n bookverse-prod exec deploy/platform-web -- cat /usr/share/nginx/html/config.js

# Test backend connectivity (from local machine)
curl -s http://localhost:8001/api/v1/books | jq '.books | length'  # Should return 20
curl -s http://localhost:8003/health  # Should return {"status":"ok"}
curl -s http://localhost:8002/health  # Should return {"status":"ok"}
```

*Solution for Local Development*:
```bash
# Fix backend URLs for local port-forwarding
kubectl -n bookverse-prod exec deploy/platform-web -- sh -c 'cat > /usr/share/nginx/html/config.js <<EOF
window.__BOOKVERSE_CONFIG__ = {
  env: "DEV",
  inventoryBaseUrl: "http://localhost:8001",
  recommendationsBaseUrl: "http://localhost:8003", 
  checkoutBaseUrl: "http://localhost:8002"
};
EOF'

# Verify fix
curl -s http://localhost:8080/config.js
```

*Root Cause*: The web application was configured to use internal Kubernetes service names (`http://inventory`) which are not accessible from the browser. For local development with port-forwarding, localhost URLs must be used.

*Permanent Fix*: The `entrypoint.sh` script in bookverse-web has been updated to properly substitute environment variables. Ensure the heredoc uses `<<CFG` (not `<<'CFG'`) to enable variable expansion.

### Reset Demo Environment

If needed, reset the entire environment:

```bash
cd bookverse-demo-init

# Clean everything
gh workflow run 🗑️-execute-cleanup.yml -f confirm_cleanup=DELETE

# Wait for cleanup completion
sleep 60

# Rebuild everything  
gh workflow run 🚀-setup-platform.yml

# Verify setup
./.github/scripts/setup/validate_setup.sh
```

## Demo Variations

### Quick Demo (20 minutes)
- Focus on Phases 1, 2, and 4
- Skip deep technical details
- Emphasize business value

### Technical Deep Dive (45 minutes)
- Cover all phases in detail
- Show configuration files
- Explain API interactions
- Demonstrate troubleshooting

### Executive Overview (10 minutes)
- Phase 1: Platform overview
- Phase 4: Show promotion and audit trail
- Phase 6: Security and compliance value

## Demo Assets and Resources

### Screenshots and Materials
- Located in `bookverse-demo-assets` repository
- Pre-captured screenshots for backup
- Policy configurations
- Sample SBOMs and reports

### Supporting Documentation
- `REPO_ARCHITECTURE.md` - Technical architecture
- `CONSTRAINTS.md` - Demo limitations and assumptions
- `WEB_APPLICATION_TROUBLESHOOTING.md` - Web application configuration and troubleshooting guide

## Success Metrics

By the end of the demo, audience should understand:
- ✅ **Zero-trust CI/CD** with OIDC authentication
- ✅ **Automated SBOM generation** and vulnerability scanning  
- ✅ **End-to-end traceability** from code to production
- ✅ **Promotion workflows** with gates and approvals
- ✅ **GitOps integration** for deployment automation
- ✅ **Platform aggregation** for microservices coordination

## Post-Demo Follow-Up

### Next Steps for Prospects
1. **Trial Setup**: Provide trial instance configuration
2. **POC Planning**: Discuss customer-specific use cases
3. **Technical Resources**: Share implementation guides
4. **Training**: Schedule AppTrust training sessions

### Internal Debrief
- Document any issues encountered
- Update runbook based on feedback
- Refresh demo environment if needed

---

**Last Updated**: $(date)
**Version**: 1.0
**Maintainer**: DevRel Team
