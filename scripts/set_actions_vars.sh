#!/usr/bin/env bash
set -euo pipefail

# Bulk-sets GitHub Actions variables for BookVerse repos.
# Requires: GH_TOKEN (repo scope). ORG optional; owner auto-detected from local clones in repos/* if present.

REPOS=(
  "bookverse-inventory"
  "bookverse-recommendations"
  "bookverse-checkout"
  "bookverse-platform"
  "bookverse-demo-assets"
)

if [[ -z "${GH_TOKEN:-}" ]]; then
  echo "❌ GH_TOKEN is not set (needs repo scope)" >&2
  exit 1
fi

ORG="${ORG:-}"

api() {
  curl -sS -H "Authorization: Bearer ${GH_TOKEN}" -H "Accept: application/vnd.github+json" "$@"
}

get_token_owner() {
  local login
  login=$(api https://api.github.com/user | jq -r '.login // empty')
  if [[ -z "$login" ]]; then
    echo "❌ Unable to determine authenticated user; check GH_TOKEN" >&2
    exit 1
  fi
  echo "$login"
}

set_repo_variable() {
  local owner="$1"; local repo="$2"; local name="$3"; local value="$4"
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

detect_owner_for_repo() {
  local repo="$1"
  local token_owner="$2"
  local owner=""
  if [[ -d "repos/${repo}/.git" ]]; then
    local url
    url=$(git -C "repos/${repo}" remote get-url origin 2>/dev/null || true)
    # handle https URL like https://github.com/OWNER/REPO.git
    owner=$(echo "$url" | sed -n 's#.*/\([^/]*\)/[^/]*\.git#\1#p')
  fi
  if [[ -z "$owner" ]]; then
    if [[ -n "$ORG" ]]; then owner="$ORG"; else owner="$token_owner"; fi
  fi
  echo "$owner"
}

main() {
  local token_owner
  token_owner=$(get_token_owner)
  echo "🔑 Authenticated as: $token_owner"
  if [[ -n "$ORG" ]]; then echo "🏢 Preferred org: $ORG"; fi

  # Inputs
  local project_key="${PROJECT_KEY:-bookverse}"
  local jfrog_url_default="${JFROG_URL:-}"
  local docker_registry_default="${DOCKER_REGISTRY:-}"

  for r in "${REPOS[@]}"; do
    local owner
    owner=$(detect_owner_for_repo "$r" "$token_owner")
    echo "\n🔧 Setting variables for ${owner}/${r}"
    if [[ -n "$project_key" ]]; then set_repo_variable "$owner" "$r" PROJECT_KEY "$project_key"; fi
    if [[ -n "$jfrog_url_default" ]]; then set_repo_variable "$owner" "$r" JFROG_URL "$jfrog_url_default"; fi
    if [[ -n "$docker_registry_default" ]]; then set_repo_variable "$owner" "$r" DOCKER_REGISTRY "$docker_registry_default"; fi
  done
  echo "\n✅ Finished setting GitHub Actions variables"
}

main "$@"


