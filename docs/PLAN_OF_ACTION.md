## BookVerse Demo – Plan of Action

Link to source playbook: [JFrog AppTrust Demo Playbook: The BookVerse Scenario](https://docs.google.com/document/d/1IJZDSFB_AtP4JDqHjWQ6z_geb--fngAnqup2TTGRNrw/edit?usp=sharing)

### Scope
- Project key: `bookverse`
- Stages: project-level `bookverse-DEV`, `bookverse-QA`, `bookverse-STAGING`; global `PROD` exists and is last in lifecycle.
- Services: `inventory`, `recommendations`, `checkout`, `platform`
- Packages: `python` (pypi), `docker`

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
- Internal (DEV/QA/STAGING): `${PROJECT_KEY}-{service}-{package}-internal-local` with `"environments": ["bookverse-DEV","bookverse-QA","bookverse-STAGING"]`
- Release (PROD): `${PROJECT_KEY}-{service}-{package}-release-local` with `"environments": ["PROD"]`
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

### Demo Assets Repository
- Store datasets, SBOMs, policy files, shared GH Action composites, screenshots, and the presenter runbook.

### Current Bootstrap Repo (this repo) – Required State
- `.github/scripts/setup/config.sh`: `PROJECT_KEY=bookverse`; `LOCAL_STAGES=("DEV" "QA" "STAGING")`
- `create_stages.sh`: uses project-prefixed names; updates lifecycle without `PROD`.
- `create_repositories.sh`: batch creation; uses `"environments"` only; maps to project stages.
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
12) Seed sample services and artifacts for demo flow
13) Add cleanup workflows per repo and centralized cleanup
14) Create demo runbook and operator checklist
15) Validation checks and smoke tests for each stage

Status: pending for all tasks above. As items complete, update this section with dates and links to PRs.


