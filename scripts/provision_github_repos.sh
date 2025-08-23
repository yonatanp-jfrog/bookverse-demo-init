#!/usr/bin/env bash
set -euo pipefail

# Requires: GH_TOKEN with repo scope, and ORG env var

ORG="${ORG:?Set ORG to your GitHub org}" 
REPOS=(
  "bookverse-inventory"
  "bookverse-recommendations"
  "bookverse-checkout"
  "bookverse-platform"
  "bookverse-web"
  "bookverse-demo-assets"
)

api() {
  curl -sS -H "Authorization: Bearer ${GH_TOKEN}" -H "Accept: application/vnd.github+json" "$@"
}

create_repo() {
  local name="$1"
  echo "➡️  Creating repo: $ORG/$name"
  code=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer ${GH_TOKEN}" -H "Accept: application/vnd.github+json" \
    -X POST https://api.github.com/orgs/$ORG/repos \
    -d "{\"name\":\"$name\",\"private\":false,\"has_issues\":true,\"has_projects\":true,\"has_wiki\":false}")
  if [[ "$code" == "201" || "$code" == "422" ]]; then
    echo "✅ Repo $name ready (HTTP $code)"
  else
    echo "❌ Failed to create $name (HTTP $code)"; return 1
  fi
}

for r in "${REPOS[@]}"; do
  create_repo "$r"
done

echo "✅ All repos processed."


