# BookVerse Web Application Troubleshooting Guide

## Overview

This document provides troubleshooting guidance for the BookVerse web application, focusing on common configuration and connectivity issues.

## Common Issues

### Issue 1: Website Shows Broken Design or Missing Content

**Symptoms:**
- Empty or broken web pages
- Missing book catalog data
- Service connectivity indicators show "n/a"
- Network connection errors in browser console

**Root Cause:**
The web application cannot connect to backend services due to incorrect URL configuration.

**Diagnosis:**
```bash
# 1. Check web service deployment status
kubectl -n bookverse-prod get deployment platform-web
kubectl -n bookverse-prod get pods -l app=platform-web

# 2. Verify current configuration
kubectl -n bookverse-prod exec deploy/platform-web -- cat /usr/share/nginx/html/config.js

# 3. Test backend service accessibility
curl -s http://localhost:8001/api/v1/books | jq '.books | length'  # Should return 20
curl -s http://localhost:8003/health  # Should return {"status":"ok"}
curl -s http://localhost:8002/health  # Should return {"status":"ok"}

# 4. Check port-forwarding status
ps aux | grep "port-forward" | grep -v grep
```

**Solution for Local Development:**
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

# Verify the fix
curl -s http://localhost:8080/config.js
```

**Expected Result:**
The web application at http://localhost:8080 should now display:
- Modern dark theme with gradient background
- Book catalog with cover images and metadata
- Working navigation (Home, Catalog, Cart)
- Functional "Add to Cart" and "View" buttons
- Service connectivity indicators showing proper URLs

### Issue 2: Environment Variables Not Substituting

**Symptoms:**
- Configuration file contains literal `${VARIABLE_NAME}` instead of actual values
- Backend URLs show as empty strings or placeholder values

**Root Cause:**
The `entrypoint.sh` script is using single quotes in heredoc, preventing shell variable expansion.

**Diagnosis:**
```bash
# Check if environment variables are set in container
kubectl -n bookverse-prod exec deploy/platform-web -- env | grep -E "(INVENTORY|RECOMMENDATIONS|CHECKOUT)_BASE_URL"

# Check entrypoint script syntax
kubectl -n bookverse-prod exec deploy/platform-web -- cat /entrypoint.sh | grep -A 10 "cat >"
```

**Solution:**
Update the `entrypoint.sh` script in the source code:

```bash
# INCORRECT (prevents variable expansion):
cat >/usr/share/nginx/html/config.js <<'CFG'
window.__BOOKVERSE_CONFIG__ = {
  env: "${BOOKVERSE_ENV:-DEV}",
  inventoryBaseUrl: "${INVENTORY_BASE_URL:-}",
  ...
};
CFG

# CORRECT (enables variable expansion):
cat >/usr/share/nginx/html/config.js <<CFG
window.__BOOKVERSE_CONFIG__ = {
  env: "${BOOKVERSE_ENV:-DEV}",
  inventoryBaseUrl: "${INVENTORY_BASE_URL:-}",
  ...
};
CFG
```

**Follow Proper CI/CD Process:**
1. Fix the `entrypoint.sh` in source code
2. Increment version numbers in `config/version-map.yaml`
3. Trigger CI workflow: `gh workflow run ci.yml -R yonatanp-jfrog/bookverse-web`
4. Promote to PROD: `gh workflow run promote.yml -R yonatanp-jfrog/bookverse-web -f target_stage=PROD`
5. Trigger platform aggregate: `gh workflow run aggregate.yml -R yonatanp-jfrog/bookverse-platform`
6. Promote platform to STAGING: `gh workflow run promote.yml -R yonatanp-jfrog/bookverse-platform -f target_stage=STAGING`
7. Release to PROD: `gh workflow run release.yml -R yonatanp-jfrog/bookverse-platform`

## Configuration Reference

### Backend URL Patterns

**Production/Kubernetes (Internal Services):**
```javascript
window.__BOOKVERSE_CONFIG__ = {
  env: "PROD",
  inventoryBaseUrl: "http://inventory",
  recommendationsBaseUrl: "http://recommendations",
  checkoutBaseUrl: "http://checkout"
};
```

**Local Development (Port-Forwarding):**
```javascript
window.__BOOKVERSE_CONFIG__ = {
  env: "DEV", 
  inventoryBaseUrl: "http://localhost:8001",
  recommendationsBaseUrl: "http://localhost:8003",
  checkoutBaseUrl: "http://localhost:8002"
};
```

### Access Setup

```bash
# Use resilient demo setup (recommended)
./scripts/bookverse-demo.sh
# Access via: http://bookverse.demo

# Legacy manual port-forward (not recommended)
kubectl -n bookverse-prod port-forward svc/platform-web 8080:80 &
# Access via: http://localhost:8080
```

## Testing and Validation

### Basic Connectivity Test
```bash
# Test web application (resilient demo)
curl -s http://bookverse.demo | grep "<title>"

# Test web application (legacy localhost)
curl -s http://localhost:8080 | grep "<title>"

# Test configuration loading
curl -s http://localhost:8080/config.js

# Test backend services
curl -s http://localhost:8001/api/v1/books | jq '.books[0].title'
curl -s http://localhost:8003/health | jq '.status'
curl -s http://localhost:8002/health | jq '.status'
```

### Browser Testing Checklist
- [ ] Website loads at http://localhost:8080
- [ ] Dark theme with gradient background displays correctly
- [ ] Navigation bar shows (Home, Catalog, Cart) links
- [ ] Home page displays service URLs (not "n/a")
- [ ] Catalog page loads with book covers and metadata
- [ ] Search functionality works
- [ ] "Add to Cart" buttons are functional
- [ ] "View" buttons navigate to book details

## Prevention

### Code Review Checklist
- [ ] Verify `entrypoint.sh` uses `<<CFG` (not `<<'CFG'`)
- [ ] Ensure environment variables are properly set in Helm values
- [ ] Test both production and development URL configurations
- [ ] Validate configuration substitution in CI pipeline

### Documentation Updates
- [ ] Update Helm chart comments for URL configuration
- [ ] Document local development setup requirements
- [ ] Include troubleshooting steps in deployment guides

## Related Documentation

- [DEMO_RUNBOOK.md](./DEMO_RUNBOOK.md) - Complete demo operation guide
- [K8S_ARGO_BOOTSTRAP.md](./K8S_ARGO_BOOTSTRAP.md) - Kubernetes deployment guide
- [bookverse-web/README.md](../bookverse-web/README.md) - Web application documentation
