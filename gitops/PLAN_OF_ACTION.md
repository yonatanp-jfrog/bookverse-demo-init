## BookVerse GitOps Plan of Action (PROD-only)

This document outlines a simple, demo‑focused GitOps strategy. Only the PROD environment deploys to Kubernetes via Argo CD. DEV/QA/STAGING are not connected or monitored.

### Objectives
- Single source of truth: manifests in this repo and `bookverse-helm`.
- Simplicity for demo: minimal, readable manifests.
- PROD-only live deploys triggered by AppTrust Recommended Platform versions.
- Automated drift detection and reconciliation via Argo CD auto-sync.

### Repos and Responsibilities
- `bookverse-demo-init` (this repo): GitOps control-plane assets, bootstrap docs/scripts.
- `bookverse-helm`: Application Helm charts using `charts/platform/values.yaml`.
- Service repos: build/publish images and update Helm values via PR.
- AppTrust: source of truth for Recommended Platform Versions in PROD.

### High-level Flow
1. Bootstrap cluster with `gitops/bootstrap/*` (Argo CD repo creds and docker pull secret).
2. Apply `gitops/projects/bookverse-prod.yaml` (AppProject).
3. Apply `gitops/apps/prod/platform.yaml` (Application → `bookverse-helm/charts/platform`).
4. CI updates Helm values on release; Argo CD reconciles and deploys.

### Secrets Management
- Namespaced `Secret` (`jfrog-docker-pull`) created in `bookverse-prod`.
- Pods use `imagePullSecrets` for JFrog registry access.

### Operational Runbooks
- Bootstrap: see `docs/K8S_ARGO_BOOTSTRAP.md`.
- Rotate credentials: update bootstrap secrets and re-apply.
- Rollback: use Argo CD UI/CLI to revert to last healthy revision.

### Acceptance Criteria
- PROD deploys successfully via Argo CD when a Recommended Platform Version is released.
- Changes flow via PRs; no manual kubectl in managed namespace.


