### Repository Architecture and Naming (BookVerse)

Link: Plan of Action (`docs/PLAN_OF_ACTION.md`) and the BookVerse playbook (`https://docs.google.com/document/d/1IJZDSFB_AtP4JDqHjWQ6z_geb--fngAnqup2TTGRNrw/edit?usp=sharing`).

### Goals
- Clear, repeatable structure for four services and shared assets
- Consistent naming across GitHub and Artifactory
- CI/CD that maps cleanly to AppTrust lifecycle: DEV → QA → STAGING → PROD

### GitHub repositories
- bookverse-inventory
- bookverse-recommendations
- bookverse-checkout
- bookverse-platform
- bookverse-demo-assets (datasets, shared workflows, runbook artifacts)

Optional: bookverse-infra (only if you want infra automation separate from this repo).

### Artifactory repository keys (local)
- Internal (project stages): `${PROJECT_KEY}-{service}-{package}-internal-local`
  - environments: `["bookverse-DEV","bookverse-QA","bookverse-STAGING"]`
- Release (PROD): `${PROJECT_KEY}-{service}-{package}-release-local`
  - environments: `["PROD"]` (PROD is global and not included in lifecycle APIs)

Where:
- `PROJECT_KEY = bookverse`
- `service ∈ {inventory,recommendations,checkout,platform}`
- `package ∈ {docker,python}` (`python` is pypi)

Examples:
- `bookverse-inventory-docker-internal-local`
- `bookverse-inventory-docker-release-local`
- `bookverse-platform-python-internal-local`

### Stage and lifecycle
- Project stages: `bookverse-DEV`, `bookverse-QA`, `bookverse-STAGING`
- Global release stage: `PROD` (always last; do not send in lifecycle PATCH)
- Lifecycle promote order: DEV → QA → STAGING → PROD

### Docker and Python publish targets
- Docker image:
  - Registry: `<JFROG_URL_HOST>` (e.g., `z0apptrustdev.jfrogdev.org`)
  - Target repo: `${PROJECT_KEY}-{service}-docker-{internal|release}-local`
  - Image: `<JFROG_URL_HOST>/${PROJECT_KEY}-{service}-docker-{internal|release}-local/{service}:{version}`
- Python package (pypi):
  - Name: `bookverse-{service}`
  - Repo: `${PROJECT_KEY}-{service}-python-{internal|release}-local`

### Service repo structure (per repo)
```
.
├─ src/
│  └─ bookverse_{service}/
├─ tests/
├─ Dockerfile
├─ pyproject.toml (or requirements.txt)
├─ .github/
│  └─ workflows/
│     ├─ ci.yml
│     └─ promote.yml
└─ README.md
```

### GitHub Actions (per service)
- `ci.yml`
  - Checkout → setup-python → install deps → tests
  - Build python wheel (pypi) and Docker image
  - Generate SBOM and sign (e.g., Syft + Cosign)
  - OIDC login to JFrog (no stored tokens)
  - Publish artifacts:
    - Branch builds → internal repos
    - Tagged releases (e.g., `vX.Y.Z`) → release repos (PROD)
- `promote.yml`
  - Workflow dispatch with `target_stage` (QA or STAGING or PROD)
  - Preconditions: artifact exists in source stage; lifecycle order respected
  - Promote/move artifacts; for PROD use release repos
  - Emit build-info and notifications

### Branching, tagging, and versions
- Default branch: `main`
- SemVer tags `vX.Y.Z` trigger release packaging and publication to `*-release-local`
- Non-tag builds publish to `*-internal-local` with commit SHA labels/metadata

### OIDC and identity mapping
- One OIDC integration per service (name: `github-bookverse-{service}`)
- Issuer: `https://token.actions.githubusercontent.com/`
- Subject filter examples:
  - `repo:{org}/bookverse-{service}:ref:refs/heads/*` for branches
  - `repo:{org}/bookverse-{service}:ref:refs/tags/*` for tags
- Map to project `bookverse` and allow publish to the service’s repos

### Required variables (per service repo)
- Repository variables (no secrets needed with OIDC):
  - `PROJECT_KEY=bookverse`
  - `JFROG_URL` (e.g., `https://z0apptrustdev.jfrogdev.org`)
  - Optional: `DOCKER_REGISTRY` (host portion of `JFROG_URL`)

### Demo assets repo (bookverse-demo-assets)
- Store datasets, SBOMs, policy files, re-usable workflow composites, screenshots, and the presenter runbook.

### Validation checklist (per repo)
- CI publishes to internal repos with environments `[bookverse-DEV, bookverse-QA, bookverse-STAGING]`
- Tag release publishes to release repo with environments `[PROD]`
- OIDC access works (no PAT)
- Build-info present; SBOM and signatures attached

### Notes
- Stage names must be project-prefixed; `PROD` is global and excluded from lifecycle API payloads.
- Verbosity: scripts support 0 (silent), 1 (feedback, default), 2 (debug with obfuscated tokens).


