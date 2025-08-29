#!/usr/bin/env bash

set -euo pipefail

# Evidence keys and secrets setup
# - Checks if evidence keys exist in repositories
# - If found, uploads public key to JFrog Platform trusted keys
# - If not found, warns user to run the key replacement script

# Requirements:
# - Env: JFROG_URL, JFROG_ADMIN_TOKEN, GH_TOKEN
# - Tools: gh, curl, jq

ALIAS_DEFAULT="BookVerse-Evidence-Key"
KEY_ALIAS="${EVIDENCE_KEY_ALIAS:-$ALIAS_DEFAULT}"

# Service repositories to check
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
echo "   🐸 JFrog: ${JFROG_URL:-unset}"

if [[ -z "${JFROG_URL:-}" || -z "${JFROG_ADMIN_TOKEN:-}" ]]; then
  echo "❌ Missing JFROG_URL or JFROG_ADMIN_TOKEN in environment" >&2
  exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "❌ GitHub CLI (gh) not found" >&2
  exit 1
fi

# Function to check if keys exist in a repository
check_repo_keys() {
  local repo="$1"
  echo "🔍 Checking for existing keys in $repo..."
  
  # Check if both public key and alias variables exist
  local public_key_exists=false
  local alias_exists=false
  
  if gh variable list --repo "$repo" | grep -q "EVIDENCE_PUBLIC_KEY"; then
    public_key_exists=true
  fi
  
  if gh variable list --repo "$repo" | grep -q "EVIDENCE_KEY_ALIAS"; then
    alias_exists=true
  fi
  
  if [[ "$public_key_exists" == true && "$alias_exists" == true ]]; then
    return 0  # Keys exist
  else
    return 1  # Keys missing
  fi
}

# Function to get keys from repository
get_repo_keys() {
  local repo="$1"
  local temp_dir="$2"
  
  echo "📥 Retrieving keys from $repo..."
  
  # Get public key and alias from repository variables
  local public_key_content
  local key_alias
  
  public_key_content=$(gh variable get EVIDENCE_PUBLIC_KEY --repo "$repo")
  key_alias=$(gh variable get EVIDENCE_KEY_ALIAS --repo "$repo")
  
  if [[ -z "$public_key_content" || -z "$key_alias" ]]; then
    echo "❌ Failed to retrieve keys from $repo" >&2
    return 1
  fi
  
  # Save to temporary files
  printf "%s" "$public_key_content" > "$temp_dir/evidence_public.pem"
  
  # Update global variables
  KEY_ALIAS="$key_alias"
  
  echo "✅ Retrieved keys from $repo (alias: $key_alias)"
  return 0
}

# Function to upload key to JFrog Platform
upload_key_to_jfrog() {
  local public_key_file="$1"
  local alias="$2"
  
  echo "📤 Uploading public key to JFrog trusted keys (alias: $alias)"
  
  # Read public key content (use full PEM format including headers)
  local public_key_content
  public_key_content=$(cat "$public_key_file")
  
  # Create JSON payload with full PEM format (same as update_evidence_keys.sh)
  local payload
  payload=$(jq -n \
    --arg alias "$alias" \
    --arg public_key "$public_key_content" \
    '{
      "alias": $alias,
      "public_key": $public_key
    }')
  
  # Upload to JFrog Platform
  local response
  local http_code
  response=$(curl -s -w "%{http_code}" \
    -X POST \
    -H "Authorization: Bearer $JFROG_ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$payload" \
    "$JFROG_URL/artifactory/api/security/keys/trusted")
  
  http_code="${response: -3}"
  
  if [[ "$http_code" == "200" ]] || [[ "$http_code" == "201" ]]; then
    echo "✅ Public key uploaded to JFrog Platform successfully"
    return 0
  else
    echo "⚠️  Failed to upload public key to JFrog Platform (HTTP $http_code)"
    echo "Response: ${response%???}"  # Remove last 3 chars (HTTP code)
    return 1
  fi
}

# Check if any repository already has evidence keys configured
WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT

echo ""
echo "🔍 Checking for existing evidence keys in repositories..."

# Check first repository for existing keys
FIRST_REPO="${SERVICE_REPOS[0]}"
if check_repo_keys "$FIRST_REPO"; then
  echo "✅ Found existing evidence keys in $FIRST_REPO"
  echo "📥 Using existing keys instead of generating new ones"
  
  # Get keys from the repository
  if get_repo_keys "$FIRST_REPO" "$WORKDIR"; then
    PUBLIC_KEY_CONTENT=$(cat "$WORKDIR/evidence_public.pem")
    
    echo "🧪 Using existing key with alias: $KEY_ALIAS"
    
    # Upload existing public key to JFrog Platform
    if upload_key_to_jfrog "$WORKDIR/evidence_public.pem" "$KEY_ALIAS"; then
      echo "✅ Evidence keys setup complete using existing keys"
    else
      echo "⚠️  Evidence keys setup completed, but JFrog Platform update failed"
    fi
  else
    echo "❌ Failed to retrieve keys from $FIRST_REPO" >&2
    exit 1
  fi
else
  echo "⚠️  No evidence keys found in repositories"
  echo "⚠️  Please run the key replacement script to generate and deploy evidence keys:"
  echo "     ./scripts/update_evidence_keys.sh --generate"
  echo ""
  echo "🚫 Skipping evidence key setup until keys are deployed"
fi

echo "🎉 Evidence keys setup completed"