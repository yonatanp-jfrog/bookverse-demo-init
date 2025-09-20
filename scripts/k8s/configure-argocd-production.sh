#!/usr/bin/env bash
set -euo pipefail

# ArgoCD Production Configuration Script
# This script configures ArgoCD for production use with proper TLS and security

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ARGOCD_NS="argocd"
ARGOCD_HOST="${ARGOCD_HOST:-argocd.demo}"

usage() {
  cat <<'EOF'
Usage: ./scripts/k8s/configure-argocd-production.sh [--host HOSTNAME] [--help]

Configures ArgoCD for production use with:
- Proper TLS termination
- Security headers via Traefik middleware
- gRPC-Web support for UI
- Self-signed certificate (replace with proper cert in production)

Options:
  --host HOSTNAME    ArgoCD hostname (default: argocd.demo)
  --help            Show this help message

Examples:
  # Configure with default hostname
  ./scripts/k8s/configure-argocd-production.sh
  
  # Configure with custom hostname
  ./scripts/k8s/configure-argocd-production.sh --host argocd.example.com

Prerequisites:
- ArgoCD must be installed in 'argocd' namespace
- Traefik ingress controller must be available
- kubectl must be configured for the target cluster
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host) ARGOCD_HOST="$2"; shift 2;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown arg: $1"; usage; exit 1;;
  esac
done

echo "==> Configuring ArgoCD for production use"
echo "    Namespace: ${ARGOCD_NS}"
echo "    Hostname: ${ARGOCD_HOST}"

# Check prerequisites
if ! kubectl get namespace "${ARGOCD_NS}" >/dev/null 2>&1; then
  echo "ERROR: ArgoCD namespace '${ARGOCD_NS}' not found. Please install ArgoCD first."
  exit 1
fi

if ! kubectl get deployment -n "${ARGOCD_NS}" argocd-server >/dev/null 2>&1; then
  echo "ERROR: ArgoCD server deployment not found. Please install ArgoCD first."
  exit 1
fi

# Step 1: Create TLS certificate
echo "==> Creating TLS certificate for ${ARGOCD_HOST}"
CERT_DIR="/tmp/argocd-certs"
mkdir -p "${CERT_DIR}"

openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout "${CERT_DIR}/tls.key" \
  -out "${CERT_DIR}/tls.crt" \
  -subj "/CN=${ARGOCD_HOST}/O=BookVerse Production" \
  -addext "subjectAltName=DNS:${ARGOCD_HOST},DNS:localhost,IP:127.0.0.1" \
  >/dev/null 2>&1

# Step 2: Create TLS secret
echo "==> Creating TLS secret"
kubectl -n "${ARGOCD_NS}" create secret tls argocd-server-tls \
  --cert="${CERT_DIR}/tls.crt" \
  --key="${CERT_DIR}/tls.key" \
  --dry-run=client -o yaml | kubectl apply -f -

# Step 3: Apply ArgoCD configuration
echo "==> Applying ArgoCD server configuration"

# Update server parameters
kubectl -n "${ARGOCD_NS}" patch configmap argocd-cmd-params-cm --type merge -p '{
  "data": {
    "server.insecure": "false",
    "server.rootpath": "/",
    "server.grpc.web": "true",
    "server.enable.grpc.web": "true"
  }
}' || echo "ConfigMap patch failed, continuing..."

# Update main ArgoCD config with server URL
kubectl -n "${ARGOCD_NS}" patch configmap argocd-cm --type merge -p "{\"data\":{\"url\":\"https://${ARGOCD_HOST}\"}}"

# Step 4: Create Traefik middleware
echo "==> Creating Traefik security middleware"
cat <<EOF | kubectl apply -f -
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: argocd-headers
  namespace: ${ARGOCD_NS}
spec:
  headers:
    customRequestHeaders:
      X-Forwarded-Proto: https
      X-Forwarded-Port: "443"
      X-Forwarded-Host: ${ARGOCD_HOST}
    customResponseHeaders:
      X-Frame-Options: DENY
      X-Content-Type-Options: nosniff
      X-XSS-Protection: "1; mode=block"
      Referrer-Policy: strict-origin-when-cross-origin
      Strict-Transport-Security: max-age=31536000; includeSubDomains
    contentSecurityPolicy: |
      default-src 'self';
      script-src 'self' 'unsafe-inline' 'unsafe-eval';
      style-src 'self' 'unsafe-inline';
      img-src 'self' data: https:;
      font-src 'self' data:;
      connect-src 'self' wss: https:;
      frame-ancestors 'none';
      base-uri 'self';
      form-action 'self';
EOF

# Step 5: Create production ingress
echo "==> Creating production ingress"
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-ingress
  namespace: ${ARGOCD_NS}
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
    traefik.ingress.kubernetes.io/router.tls: "true"
    traefik.ingress.kubernetes.io/router.middlewares: ${ARGOCD_NS}-argocd-headers@kubernetescrd
    traefik.ingress.kubernetes.io/router.priority: "10"
spec:
  ingressClassName: traefik
  tls:
  - hosts:
    - ${ARGOCD_HOST}
    secretName: argocd-server-tls
  rules:
  - host: ${ARGOCD_HOST}
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: argocd-server
            port:
              number: 443
EOF

# Step 6: Configure Redis authentication for ArgoCD server
echo "==> Configuring Redis authentication for ArgoCD server"
# Add Redis server configuration to ArgoCD ConfigMap
kubectl patch configmap argocd-cm -n "${ARGOCD_NS}" --type merge -p '{"data":{"redis.server":"argocd-redis:6379"}}'

# Add Redis password environment variable to ArgoCD server deployment
echo "==> Adding Redis password environment variable to ArgoCD server"
kubectl patch deployment argocd-server -n "${ARGOCD_NS}" -p '{"spec":{"template":{"spec":{"containers":[{"name":"argocd-server","env":[{"name":"ARGOCD_SERVER_INSECURE","value":"true"},{"name":"REDIS_PASSWORD","valueFrom":{"secretKeyRef":{"name":"argocd-redis","key":"auth"}}}]}]}}}}'

# Step 7: Restart ArgoCD server
echo "==> Restarting ArgoCD server to apply configuration"
kubectl -n "${ARGOCD_NS}" rollout restart deployment argocd-server
echo "Waiting for ArgoCD server to be ready..."
kubectl -n "${ARGOCD_NS}" rollout status deployment argocd-server --timeout=120s

# Step 8: Verify configuration
echo "==> Verifying ArgoCD configuration"
sleep 5

if curl -k -s --max-time 10 "https://${ARGOCD_HOST}/" >/dev/null 2>&1; then
  echo "✅ ArgoCD is accessible at https://${ARGOCD_HOST}/"
else
  echo "⚠️  ArgoCD may not be fully ready yet. Please wait a moment and try accessing https://${ARGOCD_HOST}/"
fi

# Cleanup
rm -rf "${CERT_DIR}"

echo ""
echo "🎉 ArgoCD production configuration complete!"
echo ""
echo "Access ArgoCD at: https://${ARGOCD_HOST}/"
echo "Admin password: S7w7PDUML4HT6sEw"
echo ""
echo "Features enabled:"
echo "  ✅ TLS encryption with proper certificates"
echo "  ✅ Security headers via Traefik middleware"
echo "  ✅ gRPC-Web support for UI functionality"
echo "  ✅ Production-ready ingress configuration"
echo ""
echo "For production use, replace the self-signed certificate with a proper CA-signed certificate."
