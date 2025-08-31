# PROD Tagging and Rollback Plan

## Objective
Define deterministic rules and automation to manage application version tags for the PROD environment across BookVerse services using semantic versioning (SemVer). Ensure that:
- When an application version is released to PROD and it is the highest SemVer among all PROD versions of that application, before changing its tag, persist the current tag value into the version’s properties key `original_tag_before_latest`, then replace its single mutable tag to `latest`.
- If another version previously held the `latest` tag, replace that version’s tag with the value stored in its `original_tag_before_latest` property (fallback to its version string or empty per policy if the property is absent).
- Any PROD version that is rolled back has its tag replaced to `quarantine`. If the rolled-back version had `latest`, the next-highest SemVer in PROD receives the `latest` tag.

## Scope
Applies per application (e.g., `web`, `inventory`, `recommendations`, `checkout`). Operates exclusively through AppTrust application versions and their tag and properties APIs.

## Key Clarifications and Constraints
- Single tag per version: Each application version has exactly one mutable tag (string up to 128 chars) that can be replaced at any time.
- Properties: Each version supports mutable properties (key:value) that can be added/updated/removed.
- Release status: PROD visibility is driven by `release_status` which can be `RELEASED` or `TRUSTED_RELEASE` (quality-gated). The Get Content API returns `release_status`.
- Version identity: The version object name is the SemVer string itself (e.g., `1.5.0`).
- SemVer sorting: Prefer server-side sorting using AppTrust API where available.
- Tag removal semantics: Tags cannot be removed; they can be replaced (including with empty string). This plan uses replacement only.
- No state file: The system must be stateless between runs; source of truth is AppTrust APIs.
- Terminology: We are operating on application versions, not container images.

## Tagging Policy
- Default tag when creating versions: Set to the version string by convention (e.g., `1.5.0`).
- `latest` tag: At most one PROD version per application should have the tag `latest` at any time.
- `quarantine` tag: Indicates a rolled-back version. A quarantined version must not carry `latest`.
- Empty tag: If needed, use empty string to clear a tag when policy requires no tag.

## Invariants
- At most one PROD version per application is tagged `latest`.
- A version tagged `quarantine` is not tagged `latest`.
- Tag transitions are done via replacement, not deletion.

## High-Level Flows

### A) Promote/Release to PROD
1. Ensure/create the application version (SemVer name), with properties set as needed.
2. Mark/verify `release_status` as `RELEASED` or `TRUSTED_RELEASE` (depending on pipeline outcome).
3. Query application versions with SemVer sorting descending (server-side if available). For each version, fetch details/Get Content to read `release_status` and keep only `RELEASED`/`TRUSTED_RELEASE`.
4. Identify SemVer-max version (first result if server-side sort is used).
5. If the newly released version is the SemVer-max:
   - Replace its tag to `latest`.
   - Identify any other PROD version currently tagged `latest` and replace its tag back to its version string (or empty, per policy).
6. If not SemVer-max: leave its tag as the version string.

### B) Rollback in PROD
1. Identify the target PROD version to rollback.
2. Replace its tag to `quarantine`.
3. If the target previously had `latest`:
   - Query remaining PROD versions (excluding the quarantined version) with SemVer sorting descending.
   - Select the next SemVer-max and replace its tag to `latest`.
4. If no other PROD versions remain, then no `latest` exists until a new release.

## Algorithmic Details

### Determining PROD Set
- List application versions for the target application (use built-in SemVer sort where supported).
- For each version, fetch details via Get Content/Get Application Version to obtain `release_status`.
- Keep only versions with `release_status` ∈ {`RELEASED`, `TRUSTED_RELEASE`}.

### SemVer Comparison
- Prefer server-side SemVer sort. If client-side is needed, parse `MAJOR.MINOR.PATCH[-PRERELEASE][+BUILD]` and compare per semver.org rules:
  1. Compare MAJOR, then MINOR, then PATCH.
  2. Non-pre-release > pre-release.
  3. If both pre-release, compare identifiers according to SemVer precedence rules.

### Tag Transition Rules (stateless)
- To set `latest` on version `Vnew`:
  - Read `currentTag := Vnew.tag`.
  - Upsert property `original_tag_before_latest = currentTag` on `Vnew`.
  - Replace tag for `Vnew` → `latest` (idempotent if already `latest`).
  - Find any other PROD version with tag `latest` (`Vold`), read `original := Vold.properties.original_tag_before_latest` (fallback to `Vold.version` or empty per policy if missing), and replace `Vold` tag → `original`. Skip if none.
- To quarantine `Vx`:
  - Optionally upsert `original_tag_before_quarantine = Vx.tag` for audit/restore.
  - Replace tag for `Vx` → `quarantine` (idempotent if already `quarantine`).
  - If `Vx` had `latest`, select next SemVer-max `Vnext` and replace its tag → `latest`.

### Properties Usage (required for tag backup/restore)
- Required keys:
  - `original_tag_before_latest` (string): the tag value that existed just before a version was tagged `latest`. Used to restore when it loses `latest`.
  - `original_tag_before_quarantine` (string, optional): the tag value before a version was quarantined.
- Advisory keys (optional): `is_latest=true/false`, `quarantined=true/false`, `rollback_reason`.
- Note: `promoted_at` and `promoted_by` are captured automatically by the platform’s audit/evidence systems and should not be duplicated as properties.
- Keep properties consistent with tags in the same execution; do not rely on external state. If `original_tag_before_latest` is absent on restore, fall back to the version string (or empty per policy).

### Edge Cases
- Pre-release in PROD: `1.5.0-rc.1` will not outrank `1.5.0`.
- Trusted vs Released: Prefer `TRUSTED_RELEASE` when selecting a successor for `latest` if a tie exists in precedence and both statuses are present. Otherwise follow pure SemVer ordering.
- No `latest` exists: First qualifying release sets `latest` automatically at next promote.
- Empty tag policy: If policy dictates no tag for non-latest, replace tag to the exact version string or empty string as configured.

## Implementation Steps

### 1) API Interactions
- List application versions: `GET /applications/{appKey}/versions?sort=semver_desc` (release_status filter not yet available).
- Read version details to obtain `release_status` (e.g., `GET /applications/{appKey}/versions/{version}` or Get Content).
- Filter client-side to `RELEASED` and `TRUSTED_RELEASE`.
- Replace tag: `PUT /applications/{appKey}/versions/{version}/tag` with body `{ tag: "latest" | "quarantine" | "<version>" | "" }`.
- Update properties: `PUT /applications/{appKey}/versions/{version}/properties`.

### 2) Library Utilities
- `getProdVersions(appKey): Version[]` // semver-sorted by API where possible; filters client-side by release_status using per-version details
- `setTag(appKey, version, tag)` // idempotent replace
- `backupTagThenSet(appKey, version, propKey, newTag)` // reads current tag, stores to property, then replaces tag
- `restoreTagFromProperty(appKey, version, propKey, fallbackTag)` // reads property and sets tag to it or fallback
- `setProperties(appKey, version, props)` // advisory metadata
- `pickNextLatest(versions, excludeVersion)`
  - From the semver-sorted list, skip `excludeVersion` and any with tag `quarantine` (by convention), choose first; prefer `TRUSTED_RELEASE` over `RELEASED` when SemVer equal.

### 3) Promote Flow
`promoteToProd(appKey, newVersion)`
- versions = `getProdVersions(appKey)`
- top = versions[0] (SemVer-max)
- if `newVersion == top.version`:
  - `backupTagThenSet(appKey, newVersion, 'original_tag_before_latest', 'latest')`
  - find any `v` ≠ `newVersion` where `v.tag == 'latest'` and `restoreTagFromProperty(appKey, v.version, 'original_tag_before_latest', v.version)`
- else: ensure `setTag(appKey, newVersion, newVersion)` (or no-op)
- optionally set properties: sync `is_latest`

### 4) Rollback Flow
`rollbackInProd(appKey, targetVersion)`
- `setTag(appKey, targetVersion, 'quarantine')`
- versions = `getProdVersions(appKey)` (now includes target with tag `quarantine`)
- if target had `latest`:
  - `next = pickNextLatest(versions, targetVersion)`
  - if `next`: `setTag(appKey, next.version, 'latest')`

### 5) Idempotency and Safety
- Always read current tag before replacing; skip if already desired value.
- Never depend on external state; compute from live API each run.
- Serialize per-application updates to avoid concurrent conflicting writes.

### 6) CI/CD Integration
- On successful PROD release job: call `promoteToProd`.
- On rollback job: call `rollbackInProd`.
- Emit logs/artifacts describing tag transitions and properties changes.

### 7) Testing
- Unit tests: tag transition logic with mocked API responses.
- Integration tests: against a staging AppTrust tenant.
- Dry-run: print intended API calls without sending requests.

## Example Transitions
- Start: PROD has `1.4.0` tagged `latest`, `1.3.2` tagged `1.3.2`.
- Release `1.5.0`: becomes `latest`; `1.4.0` tag replaced to `1.4.0`.
- Rollback `1.5.0`: tag replaced to `quarantine`; `1.4.0` tag replaced to `latest`.
- Release `1.5.1-rc.1`: no change to `latest` until `1.5.1` is released.

## Step-by-step TODO Checklist

1. Establish policy switches and defaults
   - Acceptance criteria:
     - Policy for non-latest tag value decided (version string or empty).
     - Pre-release handling in PROD clarified (ignore or allow) and documented.
     - Preference between `TRUSTED_RELEASE` and `RELEASED` defined when SemVer equal.
   - Tests:
     - Review checklist approved by stakeholders; policy values recorded in repo config.

2. Implement AppTrust API client utilities
   - Acceptance criteria:
     - `getProdVersions(appKey)` filters by `release_status in {RELEASED, TRUSTED_RELEASE}` and returns SemVer-sorted list (server-side when supported).
     - `setTag(appKey, version, tag)` replaces the single tag idempotently.
     - `setProperties(appKey, version, props)` upserts properties.
   - Tests:
     - Live/staging smoke: list versions, update tag, update properties, verify via Get Content.

3. Implement SemVer helpers (fallback only)
   - Acceptance criteria:
     - `parseSemver`, `compareSemver`, `sortSemverDesc` match semver.org precedence including pre-release rules.
     - Invalid SemVer returns null and is excluded from ordering.
   - Tests:
     - Unit tests covering MAJOR/MINOR/PATCH, pre-release ordering, build metadata ignored.

4. Implement `pickNextLatest(versions, excludeVersion)`
   - Acceptance criteria:
     - Returns first non-quarantined entry in semver-desc list excluding `excludeVersion`.
     - When SemVer equal, prefers `TRUSTED_RELEASE` over `RELEASED` per policy.
   - Tests:
     - Unit tests for tie-breaking, quarantine exclusion, and empty result cases.

5. Implement promote flow `promoteToProd(appKey, newVersion)`
   - Acceptance criteria:
     - If `newVersion` is SemVer-max: tag replaced to `latest`; any prior `latest` retagged to version string (or empty per policy).
     - If not SemVer-max: tag remains/updated to version string (or empty per policy).
     - Idempotent when run multiple times.
   - Tests:
     - Scenario A: prior `latest` exists; deploy higher version → `latest` moves.
     - Scenario B: deploy lower version → no `latest` change.
     - Scenario C: no prior `latest` → first qualifying release sets `latest`.

6. Implement rollback flow `rollbackInProd(appKey, targetVersion)`
   - Acceptance criteria:
     - Target tag replaced to `quarantine` always, backing up existing tag to `original_tag_before_quarantine`.
     - If target had `latest`, next SemVer-max non-quarantined gets `latest`; otherwise, no `latest` remains.
     - Idempotent when run multiple times.
   - Tests:
     - Scenario A: rollback current `latest` → successor gets `latest`; property `original_tag_before_quarantine` captured.
     - Scenario B: rollback non-latest → no `latest` change; property captured.
     - Scenario C: only one version → ends with no `latest`; property captured.

7. Properties synchronization (optional, observability)
   - Acceptance criteria:
     - When tags change, properties updated in same execution, including `original_tag_before_latest` (on promote to latest) and `original_tag_before_quarantine` (on rollback), plus advisory (`is_latest`, `quarantined`, `rollback_reason`).
     - `promoted_at` and `promoted_by` are not set as properties; they are sourced from audit/evidence.
     - Properties are best-effort and never override tag truth.
   - Tests:
     - Verify properties reflect tag state after promote and rollback, and that tags restore from saved properties when moving `latest` off an older version.

8. Concurrency and serialization safeguards
   - Acceptance criteria:
     - Per-application operations serialized (e.g., unique workflow concurrency group).
     - Re-running flows is safe and yields the same final state (idempotent writes).
   - Tests:
     - Simulate concurrent promotes in staging (two runs) → exactly one `latest` at end.

9. Dry-run mode
   - Acceptance criteria:
     - Flows accept `dryRun=true` to log intended tag/property changes without API mutations.
   - Tests:
     - Verify no write calls issued; logs reflect planned actions.

10. CI/CD integration (Promote)
    - Acceptance criteria:
      - GitHub Action step/job invokes `promoteToProd` on successful PROD release with inputs: `appKey`, `version`, optional flags.
      - Secrets and base URL configured via environment.
    - Tests:
      - Workflow run in staging app updates tags as expected; artifacts/logs attached.

11. CI/CD integration (Rollback)
    - Acceptance criteria:
      - Workflow dispatch/manual job invoking `rollbackInProd` with `appKey`, `version`.
      - Proper permissions; safe to run repeatedly.
    - Tests:
      - Manual run on staging app applies quarantine and reassigns `latest` per logic.

12. Reconciliation job (periodic, stateless)
    - Acceptance criteria:
      - Scans applications, ensures invariants: one `latest` max; no `latest` on quarantined.
      - Applies corrective tag replacements using same selection logic.
    - Tests:
      - Seed inconsistent state (two latests, or latest on quarantined); job fixes state deterministically.

13. Error handling and retries
    - Acceptance criteria:
      - Retries with backoff on transient errors (429/5xx); clear errors for 4xx (e.g., 403).
      - Partial failures leave system in a consistent state or provide clear follow-up instructions.
    - Tests:
      - Inject failures in mocks; verify retries, aborts, and idempotency.

14. Audit and logging
    - Acceptance criteria:
      - Structured logs include appKey, version, previous tag, new tag, actor, timestamp, correlation id.
      - Optional JSON artifact summarizing all transitions per run.
    - Tests:
      - Verify artifact contents for promote and rollback scenarios.

15. End-to-end validation in staging
    - Acceptance criteria:
      - Create multiple versions (including pre-release), set release statuses, run promote and rollback flows.
      - Final tags match expected outcomes from this plan.
    - Tests:
      - Automated E2E suite creates and cleans up staging data; assertions made via API.

16. Documentation updates
    - Acceptance criteria:
      - This document updated with concrete endpoint names used, inputs, and examples.
      - CI/CD README includes how to trigger workflows and interpret results.
    - Tests:
      - Peer review; runbook steps validated by a fresh engineer.

17. Inline documentation in code
    - Acceptance criteria:
      - Public functions (`promoteToProd`, `rollbackInProd`, `getProdVersions`, `pickNextLatest`, tag backup/restore helpers) include concise docstrings explaining purpose, params, return values, idempotency, and side effects.
      - Complex decision points (SemVer tie-breaking, TRUSTED vs RELEASED preference, property fallback) are documented near the relevant logic without duplicating this plan.
      - Example snippets provided in comments where helpful (e.g., expected input/output for `pickNextLatest`).
    - Tests:
      - Lint/doc check passes (e.g., pydocstyle/ESLint JSDoc if applicable).
      - Spot-check rendered docs or IDE hovers show accurate summaries.
