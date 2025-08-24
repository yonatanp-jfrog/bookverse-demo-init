#!/usr/bin/env bash
set -euo pipefail

# Provision BookVerse GitHub repositories and clone locally.
# Requires: GH_TOKEN with repo scope. If ORG is set, tries org repos first, else falls back to user.

if [[ -z "${GH_TOKEN:-}" ]]; then
  echo "❌ GH_TOKEN is not set (needs repo scope)" >&2
  exit 1
fi

# ORG is optional; if unset we'll create under the authenticated user
ORG="${ORG:-}"
REPOS=(
  "bookverse-inventory"
  "bookverse-recommendations"
  "bookverse-checkout"
  "bookverse-platform"
  "bookverse-demo-assets"
)

api() {
  curl -sS -H "Authorization: Bearer ${GH_TOKEN}" -H "Accept: application/vnd.github+json" "$@"
}

create_repo_org() {
  local name="$1"
  if [[ -z "$ORG" ]]; then
    return 1
  fi
  echo "➡️  Creating repo: $ORG/$name"
  code=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer ${GH_TOKEN}" -H "Accept: application/vnd.github+json" \
    -X POST https://api.github.com/orgs/$ORG/repos \
    -d "{\"name\":\"$name\",\"private\":false,\"has_issues\":true,\"has_projects\":true,\"has_wiki\":false}")
  if [[ "$code" == "201" || "$code" == "422" ]]; then
    echo "✅ Repo $name ready (HTTP $code)"
    return 0
  else
    echo "⚠️  Org create failed for $name (HTTP $code)"; return 1
  fi
}

create_repo_user() {
  local name="$1"
  echo "➡️  Creating user repo: $name"
  code=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer ${GH_TOKEN}" -H "Accept: application/vnd.github+json" \
    -X POST https://api.github.com/user/repos \
    -d "{\"name\":\"$name\",\"private\":false,\"has_issues\":true,\"has_projects\":true,\"has_wiki\":false}")
  if [[ "$code" == "201" || "$code" == "422" ]]; then
    echo "✅ Repo $name ready under user (HTTP $code)"
    return 0
  else
    echo "❌ Failed to create user repo $name (HTTP $code)"; return 1
  fi
}

OWNER_JSON=$(curl -s -H "Authorization: Bearer ${GH_TOKEN}" -H "Accept: application/vnd.github+json" https://api.github.com/user)
TOKEN_OWNER=$(echo "$OWNER_JSON" | jq -r '.login')
if [[ -z "$TOKEN_OWNER" || "$TOKEN_OWNER" == "null" ]]; then
  echo "❌ Unable to determine authenticated user; check GH_TOKEN" >&2
  exit 1
fi

echo "🔑 Authenticated as: $TOKEN_OWNER"
if [[ -n "$ORG" ]]; then
  echo "🏢 Target org: $ORG (will fallback to user if org create fails)"
else
  echo "👤 Target user: $TOKEN_OWNER"
fi

mkdir -p repos

# Helper: create/update GitHub Actions variables on the repo
set_repo_variable() {
  local owner="$1"; local repo="$2"; local name="$3"; local value="$4"
  # Try create
  local create_code
  create_code=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "Authorization: Bearer ${GH_TOKEN}" -H "Accept: application/vnd.github+json" \
    -X POST "https://api.github.com/repos/${owner}/${repo}/actions/variables" \
    -d "{\"name\":\"${name}\",\"value\":\"${value}\"}")
  if [[ "$create_code" == "201" ]]; then
    echo "   ▫️ Set variable $name"
    return 0
  fi
  if [[ "$create_code" == "409" ]]; then
    # Update existing
    local update_code
    update_code=$(curl -s -o /dev/null -w "%{http_code}" \
      -H "Authorization: Bearer ${GH_TOKEN}" -H "Accept: application/vnd.github+json" \
      -X PATCH "https://api.github.com/repos/${owner}/${repo}/actions/variables/${name}" \
      -d "{\"name\":\"${name}\",\"value\":\"${value}\"}")
    if [[ "$update_code" == "204" ]]; then
      echo "   ▫️ Updated variable $name"
      return 0
    fi
  fi
  echo "   ⚠️  Failed to set variable $name (HTTP $create_code)"
}

for r in "${REPOS[@]}"; do
  if create_repo_org "$r"; then
    OWNER="$ORG"
  else
    create_repo_user "$r" || true
    OWNER="$TOKEN_OWNER"
  fi

  echo "⬇️  Cloning $OWNER/$r into repos/$r"
  if [[ -d "repos/$r/.git" ]]; then
    echo "   ↻ Repo exists locally; fetching latest"
    git -C "repos/$r" -c http.extraheader="AUTHORIZATION: bearer ${GH_TOKEN}" fetch --all --prune || true
  else
    git -c http.extraheader="AUTHORIZATION: bearer ${GH_TOKEN}" clone https://github.com/$OWNER/$r.git "repos/$r" || true
  fi

  echo "🔧 Setting default GitHub Actions variables"
  [[ -n "${PROJECT_KEY:-}" ]] && set_repo_variable "$OWNER" "$r" PROJECT_KEY "${PROJECT_KEY}"
  [[ -n "${JFROG_URL:-}" ]] && set_repo_variable "$OWNER" "$r" JFROG_URL "${JFROG_URL}"
  [[ -n "${DOCKER_REGISTRY:-}" ]] && set_repo_variable "$OWNER" "$r" DOCKER_REGISTRY "${DOCKER_REGISTRY}"
done

echo "✅ All repos processed."


