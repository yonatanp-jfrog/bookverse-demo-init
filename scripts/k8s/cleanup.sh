#!/usr/bin/env bash
set -euo pipefail

ALL=false
usage() {
  echo "Usage: $0 [--all]   # --all also removes argocd ns and CRDs"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --all) ALL=true; shift;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown arg: $1"; usage; exit 1;;
  esac
done

echo "==> Deleting BookVerse namespaces (ignore-not-found)"
kubectl delete ns bookverse-prod bookverse --ignore-not-found

echo "==> Cleaning up demo domains from /etc/hosts"
if grep -q "bookverse.demo" /etc/hosts 2>/dev/null; then
  sudo sed -i '' '/bookverse.demo/d' /etc/hosts 2>/dev/null || true
  echo "Removed bookverse.demo from /etc/hosts"
fi
if grep -q "argocd.demo" /etc/hosts 2>/dev/null; then
  sudo sed -i '' '/argocd.demo/d' /etc/hosts 2>/dev/null || true
  echo "Removed argocd.demo from /etc/hosts"
fi

echo "==> Stopping any running port-forwards"
pkill -f "kubectl.*port-forward" 2>/dev/null || true

if $ALL; then
  echo "==> Deleting Argo CD namespace and CRDs (ignore-not-found)"
  kubectl delete ns argocd --ignore-not-found
  kubectl get crd | awk '/argoproj.io/{print $1}' | xargs -r kubectl delete crd
fi

echo "Cleanup complete."


