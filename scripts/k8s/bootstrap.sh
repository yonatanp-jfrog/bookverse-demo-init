#!/usr/bin/env bash
set -euo pipefail

# PROD-only defaults
ENV="prod"
PORT_FORWARD=false
ARGO_NS="argocd"
REGISTRY_SERVER="${REGISTRY_SERVER:-apptrustswampupc.jfrog.io}"

usage() {
  cat <<EOF
Usage: $0 [--port-forward]
PROD-only bootstrap. Optional --port-forward starts local tunnels for Argo CD (8081) and Web (8080).
Exports used: REGISTRY_USERNAME, REGISTRY_PASSWORD, REGISTRY_EMAIL, REGISTRY_SERVER (optional)
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

if [[ -n "${REGISTRY_USERNAME:-}" && -n "${REGISTRY_PASSWORD:-}" && -n "${REGISTRY_EMAIL:-}" ]]; then
  echo "==> Creating/updating docker-registry secret in ${NS}"
  kubectl -n "${NS}" create secret docker-registry jfrog-docker-pull \
    --docker-server="${REGISTRY_SERVER}" \
    --docker-username="${REGISTRY_USERNAME}" \
    --docker-password="${REGISTRY_PASSWORD}" \
    --docker-email="${REGISTRY_EMAIL}" \
    --dry-run=client -o yaml | kubectl apply -f -
  kubectl -n "${NS}" patch serviceaccount default \
    -p '{"imagePullSecrets":[{"name":"jfrog-docker-pull"}]}' >/dev/null
else
  echo "WARN: REGISTRY_USERNAME / REGISTRY_PASSWORD / REGISTRY_EMAIL not set; images may fail to pull."
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


