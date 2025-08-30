# Evidence Plan (Non-JFrog)

This document defines the non-JFrog evidence attached by BookVerse CI to packages, builds, and application versions, and when that evidence gates promotions between stages. JFrog-native evidence (SBOM, provenance, etc.) is handled automatically and is not described here.

## Subjects and Stages

- Package subject (Docker image): `${PROJECT_KEY}-${SERVICE_NAME}-docker-internal-local/${SERVICE_NAME}:${APP_VERSION}`
- Build subject: `${BUILD_NAME}#${BUILD_NUMBER}`
- Application Version (Release Bundle) subject: `${APPLICATION_KEY}@${APP_VERSION}`

Stages used for gates:
- UNASSIGNED → gate to DEV
- QA → gate to STAGING
- STAGING → gate to PROD
- PROD → post-deploy verification

## Evidence Matrix

- Package (at Package Creation)
  - PyTest Results (predicate-type: `https://pytest.org/evidence/results/v1`, slug: `unit-tests`)
    - Randomized: testsPassed [220..280], coveragePercent [90.0..95.0]
  - Checkmarx SAST (predicate-type: `https://checkmarx.com/evidence/sast/v1.1`, slug: `sast-scan`)
    - Randomized: scanId (GUID), counts for severities

- Build (at Build Aggregation)
  - SonarQube Quality Gate (predicate-type: `https://sonarsource.com/evidence/quality-gate/v1`, slug: `code-quality`)
  - FOSSA License Compliance (predicate-type: `https://fossa.com/evidence/license-scan/v2.1`, slug: `license-compliance`)

- Application Version (at Application Versioning)
  - SLSA Provenance (predicate-type: `https://slsa.dev/provenance/v1`, slug: `slsa-provenance`)
    - attachStage: UNASSIGNED, gateForPromotionTo: DEV
  - Jira Tickets (predicate-type: `https://atlassian.com/evidence/jira/release/v1`, slug: `jira-tickets`)
    - attachStage: UNASSIGNED, gateForPromotionTo: DEV

- Application Version (Promotion to QA)
  - Invicti DAST (predicate-type: `https://invicti.com/evidence/dast/v3`, slug: `dast-scan`)
    - attachStage: QA, gateForPromotionTo: STAGING
  - Postman API Tests (predicate-type: `https://postman.com/evidence/collection/v2.2`, slug: `api-tests`)
    - attachStage: QA, gateForPromotionTo: STAGING

- Application Version (Promotion to STAGING)
  - Snyk IaC (predicate-type: `https://snyk.io/evidence/iac/v1`, slug: `iac-scan`)
    - attachStage: STAGING, gateForPromotionTo: PROD
  - Cobalt.io Pentest (predicate-type: `https://cobalt.io/evidence/pentest/v1`, slug: `pentest-summary`)
    - attachStage: STAGING, gateForPromotionTo: PROD
  - ServiceNow Change Approval (predicate-type: `https://servicenow.com/evidence/change-request/v1`, slug: `change-approval`)
    - attachStage: STAGING, gateForPromotionTo: PROD (represents managerial approval)

- Application Version (Production Verification)
  - ArgoCD Deployment (predicate-type: `https://argoproj.github.io/argo-cd/evidence/deployment/v1`, slug: `argocd-deploy`)
    - attachStage: PROD (post-deploy), not a gate

## Randomization

To simulate real evidence each run, fields are pseudo-randomized using the CI run id/attempt or shell RNG. Examples:
- GUIDs via `uuidgen` or `/proc/sys/kernel/random/uuid`
- Integers with `$((MIN + RANDOM % RANGE))`
- Floats via `awk` seeded with `$RANDOM`
- Timestamps via `date -u +%Y-%m-%dT%H:%M:%SZ`

## Implementation Status

- Implemented in `bookverse-inventory/.github/workflows/ci.yml`:
  - PyTest (package), Checkmarx SAST (package), SLSA (UNASSIGNED→DEV), Jira (UNASSIGNED→DEV)
- Planned next:
  - QA gates: Invicti DAST, Postman API tests
  - STAGING gates: Snyk IaC, Cobalt Pentest, ServiceNow change approval
  - PROD verification: ArgoCD deployment evidence
