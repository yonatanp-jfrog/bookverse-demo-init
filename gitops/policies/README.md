## Policies (Demo placeholders)

For demo simplicity, policies are described here but not implemented:

- Prefer immutable image references from JFrog (`@sha256:<digest>`); avoid `latest`.
- Prefer signed images (cosign) and Helm provenance files (`.prov`).
- Scope deploys to PROD only, triggered by AppTrust Recommended Platform versions.

These can be implemented with Kyverno or Gatekeeper in a production setup.


