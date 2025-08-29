#!/usr/bin/env bash

set -euo pipefail

# Evidence keys and secrets setup
# - Generates an ed25519 keypair (if not already provided)
# - Stores private key as GitHub secret across BookVerse service repos
# - Stores public key and alias as GitHub variables across repos
# - Uploads public key to JFrog Platform trusted keys (for evidence verification)

# Requirements:
# - Env: JFROG_URL, JFROG_ADMIN_TOKEN, GH_TOKEN
# - Tools: openssl, gh, curl, jq

ALIAS_DEFAULT="BookVerse-Evidence-Key"
KEY_ALIAS="${EVIDENCE_KEY_ALIAS:-$ALIAS_DEFAULT}"
PREVIOUS_ALIAS="${PREVIOUS_EVIDENCE_KEY_ALIAS:-bookverse-ev-key}"

# Service repositories to configure
SERVICE_REPOS=(
  "yonatanp-jfrog/bookverse-inventory"
  "yonatanp-jfrog/bookverse-recommendations"
  "yonatanp-jfrog/bookverse-checkout"
  "yonatanp-jfrog/bookverse-platform"
  "yonatanp-jfrog/bookverse-web"
  "yonatanp-jfrog/bookverse-helm"
)

echo "🔐 Evidence Keys Setup"
echo "   🗝️  Alias: $KEY_ALIAS"
echo "   🔁 Previous alias (if exists): $PREVIOUS_ALIAS"
echo "   🐸 JFrog: ${JFROG_URL:-unset}"

if [[ -z "${JFROG_URL:-}" || -z "${JFROG_ADMIN_TOKEN:-}" ]]; then
  echo "❌ Missing JFROG_URL or JFROG_ADMIN_TOKEN in environment" >&2
  exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "❌ GitHub CLI (gh) not found" >&2
  exit 1
fi

if ! command -v openssl >/dev/null 2>&1; then
  echo "❌ openssl not found" >&2
  exit 1
fi

# 1) Generate keypair (unless provided through env)
WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT

if [[ -n "${EVIDENCE_PRIVATE_KEY:-}" && -n "${EVIDENCE_PUBLIC_KEY:-}" ]]; then
  echo "✅ Using evidence keys provided via environment"
  printf "%s" "$EVIDENCE_PRIVATE_KEY" > "$WORKDIR/evidence_private.pem"
  printf "%s" "$EVIDENCE_PUBLIC_KEY" > "$WORKDIR/evidence_public.pem"
else
  echo "🔧 Generating new ed25519 keypair"
  openssl genpkey -algorithm ED25519 -out "$WORKDIR/evidence_private.pem" >/dev/null 2>&1
  openssl pkey -in "$WORKDIR/evidence_private.pem" -pubout -out "$WORKDIR/evidence_public.pem" >/dev/null 2>&1
fi

chmod 600 "$WORKDIR/evidence_private.pem"
chmod 644 "$WORKDIR/evidence_public.pem"

PRIVATE_KEY_CONTENT=$(cat "$WORKDIR/evidence_private.pem")
PUBLIC_KEY_CONTENT=$(cat "$WORKDIR/evidence_public.pem")

echo "🧪 Key fingerprints:"
openssl pkey -in "$WORKDIR/evidence_private.pem" -pubout 2>/dev/null | openssl sha256 || true

# 2) Distribute keys to GitHub repositories as secrets/variables
for repo in "${SERVICE_REPOS[@]}"; do
  echo "📦 Configuring secrets and variables for $repo"
  printf "%s" "$PRIVATE_KEY_CONTENT" | gh secret set EVIDENCE_PRIVATE_KEY --repo "$repo" >/dev/null && echo "   ✅ EVIDENCE_PRIVATE_KEY (secret)"
  gh variable set EVIDENCE_PUBLIC_KEY --body "$PUBLIC_KEY_CONTENT" --repo "$repo" >/dev/null && echo "   ✅ EVIDENCE_PUBLIC_KEY (variable)"
  gh variable set EVIDENCE_KEY_ALIAS --body "$KEY_ALIAS" --repo "$repo" >/dev/null && echo "   ✅ EVIDENCE_KEY_ALIAS (variable)"
done

# 3) Upload public key to JFrog trusted keys (best-effort)
echo "📤 Uploading public key to JFrog trusted keys"
PUB_ESC=$(awk '{printf "%s\\n", $0}' "$WORKDIR/evidence_public.pem" | sed 's/"/\\"/g')
REQ_BODY_JSON="{\"alias\":\"$KEY_ALIAS\",\"public_key_pem\":\"$PUB_ESC\"}"

attempt_upload() {
  local endpoint="$1"
  local resp
  local code
  resp=$(mktemp)
  # If Artifactory security API, use PUT with text/plain body to alias path
  if echo "$endpoint" | grep -q "/artifactory/api/security/keys/trusted$"; then
    code=$(curl -sS -L -o "$resp" -w "%{http_code}" -X PUT \
      "$endpoint/$KEY_ALIAS" \
      -H "Authorization: Bearer $JFROG_ADMIN_TOKEN" \
      -H "Content-Type: text/plain" \
      --data-binary @"$WORKDIR/evidence_public.pem") || code=000
  else
    code=$(curl -sS -L -o "$resp" -w "%{http_code}" -X POST \
      "$endpoint" \
      -H "Authorization: Bearer $JFROG_ADMIN_TOKEN" \
      -H "Content-Type: application/json" \
      -d "$REQ_BODY_JSON") || code=000
  fi
  echo "   → $endpoint (HTTP $code)"
  if [[ "$code" == "200" || "$code" == "201" ]]; then
    echo "   ✅ Uploaded trusted key"
    rm -f "$resp"
    return 0
  fi
  if [[ "$code" == "409" ]]; then
    echo "   ⚠️ Key already exists (alias=$KEY_ALIAS)"
    rm -f "$resp"
    return 0
  fi
  echo "   Body:"; cat "$resp" || true
  rm -f "$resp"
  return 1
}

ENDPOINTS=(
  "$JFROG_URL/access/api/v1/keys/trusted"
  "$JFROG_URL/artifactory/api/security/keys/trusted"
  "$JFROG_URL/access/api/v1/projects/${PROJECT_KEY}/keys/trusted"
)

# Attempt to delete a trusted key by alias (best-effort, ignore errors)
attempt_delete_alias() {
  local alias="$1"
  local del_endpoint
  local code
  for base in "${ENDPOINTS[@]}"; do
    del_endpoint="$base/$alias"
    code=$(curl -sS -o /dev/null -w "%{http_code}" -X DELETE \
      "$del_endpoint" \
      -H "Authorization: Bearer $JFROG_ADMIN_TOKEN" \
      -H "Content-Type: application/json") || code=000
    echo "   → DELETE $del_endpoint (HTTP $code)"
    if [[ "$code" == "200" || "$code" == "204" || "$code" == "404" ]]; then
      return 0
    fi
  done
  return 0
}

uploaded=false
for ep in "${ENDPOINTS[@]}"; do
  if attempt_upload "$ep"; then
    uploaded=true
    break
  fi
done

# Additional fallbacks: try query-parameter alias style for Artifactory API
if [[ "$uploaded" != true ]]; then
  ALT_EP="$JFROG_URL/artifactory/api/security/keys/trusted?alias=$KEY_ALIAS"
  resp=$(mktemp)
  code=$(curl -sS -L -o "$resp" -w "%{http_code}" -X PUT \
    "$ALT_EP" \
    -H "Authorization: Bearer $JFROG_ADMIN_TOKEN" \
    -H "Content-Type: text/plain" \
    --data-binary @"$WORKDIR/evidence_public.pem") || code=000
  echo "   → $ALT_EP (HTTP $code)"
  if [[ "$code" == "200" || "$code" == "201" || "$code" == "204" ]]; then
    echo "   ✅ Uploaded trusted key"
    uploaded=true
  else
    echo "   Body:"; cat "$resp" || true
  fi
  rm -f "$resp"
fi

if [[ "$uploaded" != true ]]; then
  echo "⚠️ Unable to upload trusted key to JFrog automatically. You can verify locally using --public-keys."
else
  # If the alias changed, try to remove the previous alias to avoid confusion
  if [[ "$PREVIOUS_ALIAS" != "$KEY_ALIAS" && -n "$PREVIOUS_ALIAS" ]]; then
    echo "🧹 Cleaning up previous trusted key alias: $PREVIOUS_ALIAS"
    attempt_delete_alias "$PREVIOUS_ALIAS" || true
  fi
fi

echo "🎉 Evidence keys setup completed"


