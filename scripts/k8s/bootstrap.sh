#!/usr/bin/env bash
set -euo pipefail

# PROD-only defaults
ENV="prod"
PORT_FORWARD=false
ARGO_NS="argocd"
REGISTRY_SERVER="${REGISTRY_SERVER:-}"

usage() {
  cat <<'EOF'
Usage: ./scripts/k8s/bootstrap.sh [--port-forward] [--help]

PROD-only bootstrap for local Kubernetes + Argo CD. No defaults are assumed.

Environment variables (required to create image pull secret):
  REGISTRY_SERVER     Container registry hostname (no repo path), e.g., registry.example.com
  REGISTRY_USERNAME   Registry username
  REGISTRY_PASSWORD   Registry password or token
  REGISTRY_EMAIL      Email for the registry secret (optional; JFrog user email recommended)

Behavior:
  - Installs/updates Argo CD in namespace "argocd"
  - Creates namespace "bookverse-prod"
  - If REGISTRY_SERVER/USERNAME/PASSWORD are set (EMAIL optional), creates/updates imagePullSecret "jfrog-docker-pull" and attaches it to the default ServiceAccount
  - Applies GitOps: gitops/projects/bookverse-prod.yaml and gitops/apps/prod/platform.yaml
  - Waits for Argo CD Application to be Synced/Healthy
  - With --port-forward, starts local tunnels: Argo CD (https://localhost:8081), Web (http://localhost:8080)

Examples:
  # JFrog SaaS
  export REGISTRY_SERVER='your-tenant.jfrog.io'
  export REGISTRY_USERNAME='alice'
  export REGISTRY_PASSWORD='***'
  export REGISTRY_EMAIL='alice@example.com'   # optional
  ./scripts/k8s/bootstrap.sh --port-forward

  # Local JFrog (default platform port)
  export REGISTRY_SERVER='localhost:8082'
  export REGISTRY_USERNAME='admin'
  export REGISTRY_PASSWORD='***'
  # REGISTRY_EMAIL optional (e.g., 'admin@local')
  ./scripts/k8s/bootstrap.sh --port-forward
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --port-forward) PORT_FORWARD=true; shift;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown arg: $1"; usage; exit 1;;
  esac
done

NS="bookverse-${ENV}"
APP_NAME="platform-${ENV}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GITOPS_DIR="${ROOT}/gitops"

echo "==> Ensuring Argo CD installed in namespace ${ARGO_NS}"
kubectl get ns "${ARGO_NS}" >/dev/null 2>&1 || kubectl create ns "${ARGO_NS}"
kubectl apply -n "${ARGO_NS}" -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl -n "${ARGO_NS}" rollout status deploy/argocd-server --timeout=180s || true

echo "==> Creating namespace ${NS}"
kubectl get ns "${NS}" >/dev/null 2>&1 || kubectl create ns "${NS}"

if [[ -n "${REGISTRY_SERVER:-}" && -n "${REGISTRY_USERNAME:-}" && -n "${REGISTRY_PASSWORD:-}" ]]; then
  echo "==> Creating/updating docker-registry secret in ${NS}"
  EMAIL_ARG=()
  if [[ -n "${REGISTRY_EMAIL:-}" ]]; then
    EMAIL_ARG=(--docker-email "${REGISTRY_EMAIL}")
  fi
  kubectl -n "${NS}" create secret docker-registry jfrog-docker-pull \
    --docker-server="${REGISTRY_SERVER}" \
    --docker-username="${REGISTRY_USERNAME}" \
    --docker-password="${REGISTRY_PASSWORD}" \
    "${EMAIL_ARG[@]}" \
    --dry-run=client -o yaml | kubectl apply -f -
  kubectl -n "${NS}" patch serviceaccount default \
    -p '{"imagePullSecrets":[{"name":"jfrog-docker-pull"}]}' >/dev/null
else
  echo "WARN: REGISTRY_SERVER / REGISTRY_USERNAME / REGISTRY_PASSWORD not all set;"
  echo "      Skipping imagePullSecret creation. Images may fail to pull until you configure credentials."
fi

echo "==> Applying AppProject (PROD-only)"
kubectl apply -f "${GITOPS_DIR}/projects/bookverse-prod.yaml"

echo "==> Applying Application for PROD"
kubectl apply -f "${GITOPS_DIR}/apps/prod/platform.yaml"

echo "==> Waiting for Argo CD app to become Synced/Healthy"
for i in {1..60}; do
  SYNC=$(kubectl -n "${ARGO_NS}" get application.argoproj.io "${APP_NAME}" -o jsonpath='{.status.sync.status}' 2>/dev/null || true)
  HEALTH=$(kubectl -n "${ARGO_NS}" get application.argoproj.io "${APP_NAME}" -o jsonpath='{.status.health.status}' 2>/dev/null || true)
  echo "   Sync=${SYNC:-N/A} Health=${HEALTH:-N/A}"
  if [[ "${SYNC}" == "Synced" && "${HEALTH}" == "Healthy" ]]; then
    break
  fi
  sleep 5
done

echo "==> Showing workloads in ${NS}"
kubectl -n "${NS}" get deploy,svc,pod

if [[ "${PORT_FORWARD}" == "true" ]]; then
  echo "==> Starting port-forward for Argo CD and Web (Ctrl-C to stop)"
  (kubectl -n "${ARGO_NS}" port-forward svc/argocd-server 8081:443 >/dev/null 2>&1) &
  (kubectl -n "${NS}" port-forward svc/platform-web 8080:80 >/dev/null 2>&1) &
  wait
fi

echo "Done. Web: http://localhost:8080  |  Argo CD: https://localhost:8081"


