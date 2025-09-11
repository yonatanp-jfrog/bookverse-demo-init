### Kubernetes + Argo CD Bootstrap (PROD-only Demo)

This guide lets anyone install and run the BookVerse demo on a local Kubernetes cluster with Argo CD, with zero prior setup. The cluster and Argo CD manage only the PROD environment, deploying platform versions that have been released.

#### Prerequisites
- kubectl and helm installed
- A local cluster (Rancher Desktop recommended)
- Container registry credentials (hostname, username, password/token, email)

#### 1) Start from a clean slate (optional)
```bash
cd bookverse-demo-init
./scripts/k8s/cleanup.sh --all
```

#### 2) Bootstrap Argo CD and deploy BookVerse (PROD)
```bash
cd bookverse-demo-init
export REGISTRY_SERVER='your.registry.example.com'   # host only, no path
export REGISTRY_USERNAME='<jfrog-username>'
export REGISTRY_PASSWORD='<jfrog-password-or-token>'
export REGISTRY_EMAIL='you@example.com'
./scripts/k8s/bootstrap.sh --port-forward
# Argo CD UI: https://localhost:8081 (accept self-signed cert)
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo
# Web app: http://localhost:8080
```

What the bootstrap does:
- Installs Argo CD in `argocd` namespace
- Creates `bookverse-prod` namespace
- Adds `imagePullSecrets` if all REGISTRY_* vars are provided (no defaults assumed)
- Applies `gitops/projects/bookverse-prod.yaml` and `gitops/apps/prod/platform.yaml`
- Waits for the Argo CD Application to be Synced and Healthy
- Optionally starts port-forwards for Argo CD and the web app

#### 3) Verify
```bash
kubectl -n argocd get applications.argoproj.io platform-prod
kubectl -n bookverse-prod get deploy,svc,pod
```

#### Troubleshooting
- ImagePullBackOff: ensure `REGISTRY_*` variables were set before running bootstrap; re-run `bootstrap.sh` or restart deployments:
```bash
kubectl -n bookverse-prod rollout restart deploy
```
- Argo CD app OutOfSync/Missing tags: confirm `bookverse-helm/charts/platform/values.yaml` on `main` contains non-empty tags for all services (the demo CI/CD sets these on release).
- Access without port-forward: enable Ingress in the Helm chart (`web.ingress.enabled=true`, set `web.ingress.host`) and expose via your local ingress controller (e.g., Traefik).

#### Uninstall
```bash
cd bookverse-demo-init
./scripts/k8s/cleanup.sh --all
```

Notes:
- This demo intentionally deploys only to `bookverse-prod`. DEV/QA/STAGING are not connected or monitored by Argo CD.
- Argo CD pulls manifests from the public `bookverse-helm` GitHub repo; images are pulled from JFrog registry using your provided credentials.


