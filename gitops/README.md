## BookVerse GitOps (PROD-only)

This demo uses Argo CD to deploy only to PROD. Deployments occur when AppTrust designates a Platform release as "Recommended for PROD" and CI/CD updates the Helm values accordingly.

### Flow
1. AppTrust marks a Platform version as Recommended for PROD.
2. CI/CD updates `bookverse-helm/charts/platform/values.yaml` (chart/image versions) via PR and merge.
3. Argo CD auto-syncs `apps/prod/platform.yaml` to the `bookverse-prod` namespace.

### Bootstrap (PROD only)
1. Apply `gitops/bootstrap/*`.
2. Apply `gitops/projects/bookverse-prod.yaml`.
3. Apply `gitops/apps/prod/platform.yaml`.

See `docs/K8S_ARGO_BOOTSTRAP.md` for one-command local bootstrap.

### Policies
Policies are placeholders for demo purposes and are not enforced. See `gitops/policies/` for notes.


