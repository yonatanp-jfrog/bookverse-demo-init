## BookVerse Demo – Plan of Action

Link to source playbook: [JFrog AppTrust Demo Playbook: The BookVerse Scenario](https://docs.google.com/document/d/1IJZDSFB_AtP4JDqHjWQ6z_geb--fngAnqup2TTGRNrw/edit?usp=sharing)

### Scope
- Project key: `bookverse`
- Stages: project-level `bookverse-DEV`, `bookverse-QA`, `bookverse-STAGING`; global `PROD` exists and is last in lifecycle.
- Services: `inventory`, `recommendations`, `checkout`, `platform`
- Packages: `python` (pypi), `docker`

### Service Plans (quick links)
- Checkout: see `CHECKOUT_PLAN_OF_ACTION.md` (central copy; source at `bookverse-checkout/PLAN_OF_ACTION.md`)

### Guardrails and Constraints
- Stage names must be project-prefixed (e.g., `bookverse-QA`).
- `PROD` is global and must not be created or included in lifecycle API payloads.
- Scripts use verbosity levels: 0 none, 1 feedback (default), 2 debug. In debug, show API before execution, show output after, and obfuscate tokens.
- Application owners are managers or architects; 1–2 owners per application.

### Repositories (GitHub) to Create
- `bookverse-inventory`
- `bookverse-recommendations`
- `bookverse-checkout`
- `bookverse-platform`
- `bookverse-demo-assets` (datasets, SBOMs, shared workflows, runbook materials)

Each service repo includes:
- Minimal Python service, tests, `Dockerfile`, and `requirements.txt`/`pyproject.toml`
- Workflows:
  - `ci.yml`: test → build → SBOM/sign → publish to Artifactory
  - `promote.yml`: DEV→QA→STAGING→PROD promotion with checks
- OIDC to JFrog per repo; identity mapping in JFrog

### Artifactory Repository Model
- Internal (DEV/QA/STAGING): `${PROJECT_KEY}-{service}-internal-{package}-nonprod-local` with `"environments": ["bookverse-DEV","bookverse-QA","bookverse-STAGING"]`
- Release (PROD): `${PROJECT_KEY}-{service}-internal-{package}-release-local` with `"environments": ["PROD"]` (platform visibility is `public`; others `internal`)
- Batch creation via `PUT /artifactory/api/v2/repositories/batch`

### AppTrust Stages & Lifecycle
- Create project stages via `POST /access/api/v2/stages` for `bookverse-DEV|QA|STAGING` (scope `project`, category `promote`).
- Patch lifecycle via `PATCH /access/api/v2/lifecycle/?project_key=bookverse` with only promote stages `[bookverse-DEV, bookverse-QA, bookverse-STAGING]`.
- Validate with `GET /access/api/v2/lifecycle/?project_key=bookverse`.

### Users, Roles, and Applications
- Create 8 human users + 4 pipeline users. Assign project roles via `PUT /access/api/v1/projects/{projectKey}/users/{username}` with allowed roles only: Developer, Contributor, Viewer, Release Manager, Security Manager, Application Admin, Project Admin.
- Applications (AppTrust): one per service plus `platform`. Owners must be managers/architects.

### OIDC & Identity Mappings
- One OIDC integration per service + platform. Set issuer `https://token.actions.githubusercontent.com/` and identity mappings per GitHub repo.

### CI/CD per Service Repository
- `ci.yml`: run tests, build python wheel + docker image, generate SBOM, sign, OIDC login, publish to internal repos.
- `promote.yml`: manual/dispatch with target stage; validate artifact existence and lifecycle order; promote to QA→STAGING; for PROD, publish to release repos.

### Website Packaging & Runtime Images
- Web UI is built from the platform/web project and served via a container image (e.g., NGINX).
- Add web Docker repos (if not present): `${PROJECT_KEY}-web-internal-docker-nonprod-local` (DEV/QA/STAGING), `${PROJECT_KEY}-web-internal-docker-release-local` (PROD).
- CI builds `bookverse-web` image, tags with commit SHA/semver, and pushes to the internal Docker repo. Promotion/publish to release repo on PROD.

### Helm Charts & Release
- Primary chart: `platform` (includes and pins all microservice images used by the platform release).
- Optional internal charts: per-service charts may exist for testing but are NOT deployed to clusters.
- Charts are versioned and packaged in CI, then pushed to `${PROJECT_KEY}-helm-internal-helm-nonprod-local` (and to `${PROJECT_KEY}-helm-internal-helm-release-local` for PROD).
- Provide per-environment values files (DEV/QA/STAGING/PROD) overriding image tags, resources, and config.

### GitOps with ArgoCD
- Store ArgoCD app manifests in `bookverse-demo-assets` under `gitops/`:
  - `projects/` definitions (e.g., `bookverse-dev`, `bookverse-qa`, `bookverse-staging`, `bookverse-prod`).
  - `apps/` per environment that deploy ONLY the `platform` chart and values.
- ArgoCD integrates with the JFrog Helm repo (`${JFROG_URL}/artifactory/${PROJECT_KEY}-helm-internal-helm-nonprod-local`) and the Docker registry for image pulls.
- A webhook from AppTrust triggers a GitHub workflow to update the platform Helm chart values (image tags) when the `platform` application version is promoted to PROD.

### Kubernetes Cluster Prerequisites
- Namespaces: `bookverse-dev`, `bookverse-qa`, `bookverse-staging`, `bookverse-prod`.
- Image pull secrets configured for JFrog Docker registry access (or anonymous if allowed).
- ArgoCD repository credentials to access the JFrog Helm repo.
- Optional: Ingress controller and DNS for the BookVerse web UI.

### Promotion & GitOps Flow
- Microservices: CI publishes artifacts and creates AppTrust application versions; microservice versions run through DEV→QA→STAGING→PROD.
- Platform: a scheduled process aggregates the latest microservice PROD versions, creates a combined `platform` application version, and runs it through DEV→QA→STAGING→PROD.
- On `platform` promotion to PROD, a webhook triggers a GitHub action to update the platform Helm chart values (pins microservice image tags) and ArgoCD syncs the platform only.

### AppTrust Release Orchestration (Microservices → Platform aggregation)
- Each microservice has its own AppTrust application and versions tied to builds; versions are promoted independently through the SDLC.
- The `platform` application periodically (bi-weekly) queries AppTrust for the latest released (PROD) versions of each microservice.
- The process creates a combined `platform` application version with metadata that references the exact microservice versions/images.
- The combined `platform` version is promoted through the SDLC. Upon promotion to PROD, an AppTrust webhook calls a GitHub workflow to update the platform Helm chart values (locking image tags) and commit changes in `bookverse-demo-assets`.

### Demo Assets Repository
- Store datasets, SBOMs, policy files, shared GH Action composites, screenshots, and the presenter runbook.

### Current Bootstrap Repo (this repo) – Required State
- `.github/scripts/setup/config.sh`: `PROJECT_KEY=bookverse`; `LOCAL_STAGES=("DEV" "QA" "STAGING")`
- `create_stages.sh`: uses project-prefixed names; updates lifecycle without `PROD`.
- `create_repositories.sh`: creates service and generic repos only (environments mapped).
  `create_dependency_repos.sh` and `prepopulate_dependencies.sh` are run separately.
- `create_users.sh`: role mapping conforms to JFrog roles; assigns to project.
- `create_applications.sh`: creates apps; owners are managers/architects.
- `create_oidc.sh`: OIDC per service and identity mappings.
- Verbosity framework respected by all scripts (0/1/2); debug prints commands and outputs with obfuscated tokens.

### Operator Runbook (High-Level)
1. Export `JFROG_URL` and `JFROG_ADMIN_TOKEN` (or run via OIDC bootstrap).
2. Run `./init_local.sh` (or `./init_debug.sh` for step-by-step). Confirm lifecycle.
3. Create/push code scaffolds to the five GitHub repos.
4. Configure OIDC trust per repo.
5. Run each repo’s `ci.yml` to publish to DEV.
6. Use `promote.yml` to move artifacts through QA → STAGING → PROD.
7. Demonstrate AppTrust, scans, SBOMs, signatures, and policies.
8. Cleanup via `cleanup_local.sh` or workflow.

### Validation Checklist
- Lifecycle promote stages show only `bookverse-DEV|QA|STAGING`; release shows `PROD (global)`.
- All internal repos list environments `[bookverse-DEV, bookverse-QA, bookverse-STAGING]`.
- Release repos list environments `[PROD]`.
- Users exist, roles assigned, apps created with valid owners.
- OIDC works (no PATs/tokens in GH).

---

### TODOs

1) Define repo architecture and naming across services/packages
2) Document constraints: stage naming, PROD handling, verbosity UX
3) Update current init/cleanup repo with final scripts and docs
4) Provision five GitHub repos (inventory, recommendations, checkout, platform, demo-assets)
5) Add standard CI: build/test/publish (python+docker) for each repo
6) Add promotion workflows: DEV→QA→STAGING→PROD with checks
7) Set up OIDC trust and identity mappings per repo
8) Create users and assign project roles; add pipeline users
9) Create AppTrust applications with correct owners per service
10) Batch-create Artifactory repos with environments mapping
11) Secrets & variables: define org/repo vars and bootstrap instructions
12) Seed sample services and artifacts for demo flow (images, wheels, SBOMs)
13) Centralized cleanup in demo-init (no per-repo cleanup workflows)
14) Create demo runbook and operator checklist
15) Validation checks and smoke tests for each stage
16) Website build & containerization (bookverse-web Docker image)
   16.1) Add `web/` app scaffold under `bookverse-platform` (static assets or SPA)
   16.2) Create `Dockerfile` (multi-stage build; final NGINX/Alpine image)
   16.3) Add CI steps to build/tag/push `bookverse-web` to internal Docker repo
   16.4) Add promotion logic to publish image to release repo on PROD
   16.5) Parameterize base path/env via build args and runtime config map
   16.6) Add SBOM/signing step for web image
   16.7) Update service README with run/debug/publish instructions
17) Helm charts (platform-centric) and publish to Helm repos
   17.1) Create Helm chart skeleton for `platform` (and optional `web`)
   17.2) Define values.yaml (per microservice image repo/tag, resources, env, probes)
   17.3) Create per-env values: `values-dev.yaml`, `values-qa.yaml`, `values-staging.yaml`, `values-prod.yaml`
   17.4) Add CI packaging step (helm package) and push to Helm internal repo
   17.5) Implement chart version bumping tied to platform app/image versions
   17.6) Add NOTES.txt and standard templates (deployment, service, ingress)
   17.7) Update docs with install/upgrade commands via Helm
18) GitOps: ArgoCD projects/apps per env; integrate with JFrog repos (platform-only deploy)
   18.1) Define ArgoCD Projects: dev/qa/staging/prod with allowed sources/destinations
   18.2) Create App-of-Apps per env pointing to `bookverse-demo-assets/gitops/apps/<env>`
   18.3) Add app definition for platform (and optional web) Helm chart only
   18.4) Configure repo credentials for JFrog Helm and Docker registry
   18.5) Add CI step to update chart versions/image tags via GitOps commits when platform is released
   18.6) Document bootstrap commands to register ArgoCD repos and sync apps
   18.7) Document AppTrust webhook endpoint to trigger the GitHub workflow

Status:
Completed:
- 1) Repo architecture and naming defined ✅
- 2) Constraints documented (stage naming, PROD, verbosity UX) ✅
- 3) Init/cleanup repo updated with final scripts and docs ✅
- 4) Five GitHub repos provisioned ✅
- 5) CI workflows added to all service repos ✅
- 6) Promotion workflows added to all service repos ✅
- 8) Users created and project roles assigned; pipeline users added ✅
- 9) AppTrust applications created with correct owners ✅
- 10) Artifactory repos batch-created with environments mapping ✅
- 11) Secrets & variables configured; bootstrap script added ✅
- 13) Centralized cleanup enhanced in demo-init only ✅
- 16.1) Platform web scaffold ✅ (moved to bookverse-web repo per architecture)
- 16.2) Web Dockerfile ✅
- 16.3) CI build/push of web image ✅ (push deferred until connectivity)
 
- 16.5) Runtime config entrypoint ✅
- 16.6) SBOM/sign placeholders ✅
- 16.7) Web README ✅
- 17) Helm charts (platform-centric) ✅ (chart, env values, CI placeholder)
- 18) ArgoCD GitOps (platform-only) ✅ (projects/apps scaffolding)

Pending/Skipped:
- 7) OIDC trust and identity mappings – pending ⚠️ (endpoint alignment in progress)
- 12) Seed sample services and artifacts – cancelled ❌ (per decision to drop task for now)
- 15) Validation checks and smoke tests for each stage – cancelled ❌ (per decision to drop task for now)
- 16.4) Web image release (publish to PROD repo) – cancelled ❌ (per decision to drop task for now)
- Remaining items – pending ⚠️


