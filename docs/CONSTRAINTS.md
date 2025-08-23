### BookVerse Constraints and Conventions

This document defines the non-negotiable rules for stage naming, lifecycle/PROD handling, and verbosity UX for automation and demo workflows.

### 1) Stage Naming and Lifecycle
- Project stages must be prefixed with the project key:
  - `bookverse-DEV`, `bookverse-QA`, `bookverse-STAGING`
- The release stage `PROD` is global, always present, and always last in the lifecycle.
  - Do not create `PROD` with stage APIs.
  - Do not include `PROD` in lifecycle PATCH payloads.
- Lifecycle configuration:
  - Promote order: `bookverse-DEV → bookverse-QA → bookverse-STAGING` (system-managed `PROD` is implied after STAGING).
  - Validation: `GET /access/api/v2/lifecycle/?project_key=bookverse` must show only project-prefixed stages in the promote category.

### 2) Repository Environments Mapping
- Internal repositories (per service/package):
  - Key pattern: `${PROJECT_KEY}-{name}-{package}-internal-local`
  - `"environments": ["bookverse-DEV","bookverse-QA","bookverse-STAGING"]`
- Release repositories (per service/package):
  - Key pattern: `${PROJECT_KEY}-{name}-{package}-release-local`
  - `"environments": ["PROD"]` (global stage)
- Always use the field name `environments` (never `envs`).
- When referencing stages in repository definitions, use project-prefixed names for DEV/QA/STAGING; use plain `PROD` for release repos.

### 3) Verbosity and Output UX (Automation Scripts)
- Verbosity levels (environment variable `VERBOSITY`):
  - `0` (silent): no output; commands run non-interactively.
  - `1` (feedback – default): show step headers, progress, and concise results; hide curl verbose output.
  - `2` (debug):
    - Show each API call (curl) before execution with tokens obfuscated.
    - Execute and show the response (status and body) after.
    - Maintain non-interactive behavior; no prompts required.
- Token handling: obfuscate bearer tokens as `Bearer ***` in any printed command.
- Error handling (idempotent patterns):
  - Treat `409 Conflict` (already exists) as a non-fatal, continue.
  - Log unexpected codes and continue to next step when safe.

### 4) Evidence and Metadata (for demo)
- Application SBOM: generated and managed automatically by JFrog AppTrust; do not generate or sign SBOMs in CI.
- Build metadata captured in CI:
  - Commit author and committer (from git) recorded in build-info.
  - Reviewer(s) recorded (can be synthetic for demo purposes).
  - SLSA provenance/attestation attached (may be synthetic for demo).
- Promotion evidence:
  - On promotion (QA/STAGING/PROD), attach relevant evidence (e.g., QA test summary, approvals, ticket refs). Evidence may be synthetic for demo.


