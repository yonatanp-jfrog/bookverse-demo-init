#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# SHARED OIDC TOKEN EXCHANGE SCRIPT
# =============================================================================
# This script consolidates the OIDC token exchange logic used across all
# BookVerse services, eliminating ~25 lines of duplicate code per service.
#
# Usage:
#   ./exchange-oidc-token.sh --service-name recommendations \
#                           --provider-name bookverse-recommendations-github \
#                           --jfrog-url "$JFROG_URL" \
#                           --docker-registry "$DOCKER_REGISTRY"
#
# Environment Variables Required:
#   ACTIONS_ID_TOKEN_REQUEST_URL  - GitHub Actions OIDC token request URL
#   ACTIONS_ID_TOKEN_REQUEST_TOKEN - GitHub Actions OIDC token request token
#
# Environment Variables Set:
#   JF_OIDC_TOKEN - JFrog access token for subsequent steps
#
# Outputs (for GitHub Actions):
#   token - JFrog access token (same as JF_OIDC_TOKEN)
#
# =============================================================================

# Default values
SERVICE_NAME=""
PROVIDER_NAME=""
JFROG_URL=""
DOCKER_REGISTRY=""
VERBOSE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --service-name)
      SERVICE_NAME="$2"
      shift 2
      ;;
    --provider-name)
      PROVIDER_NAME="$2"
      shift 2
      ;;
    --jfrog-url)
      JFROG_URL="$2"
      shift 2
      ;;
    --docker-registry)
      DOCKER_REGISTRY="$2"
      shift 2
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    *)
      echo "❌ Unknown parameter: $1" >&2
      exit 1
      ;;
  esac
done

# Validate required parameters
if [[ -z "$SERVICE_NAME" || -z "$PROVIDER_NAME" || -z "$JFROG_URL" ]]; then
  echo "❌ Missing required parameters" >&2
  echo "Usage: $0 --service-name <name> --provider-name <provider> --jfrog-url <url> [--docker-registry <registry>]" >&2
  exit 1
fi

if [[ "$VERBOSE" == "true" ]]; then
  echo "🔐 Starting OIDC token exchange for service: $SERVICE_NAME"
  echo "🎯 Provider: $PROVIDER_NAME"
  echo "🏢 JFrog URL: $JFROG_URL"
  echo "🐳 Docker Registry: ${DOCKER_REGISTRY:-'Not specified'}"
fi

# Ensure jq is available
if ! command -v jq >/dev/null 2>&1; then
  echo "📦 Installing jq..."
  sudo apt-get update -y && sudo apt-get install -y jq
fi

# Step 1: Get GitHub OIDC ID token
if [[ "$VERBOSE" == "true" ]]; then
  echo "🔄 Step 1: Requesting GitHub OIDC ID token..."
fi

if [[ -z "${ACTIONS_ID_TOKEN_REQUEST_URL:-}" || -z "${ACTIONS_ID_TOKEN_REQUEST_TOKEN:-}" ]]; then
  echo "❌ Missing GitHub OIDC request environment variables" >&2
  echo "   ACTIONS_ID_TOKEN_REQUEST_URL: ${ACTIONS_ID_TOKEN_REQUEST_URL:+SET}" >&2
  echo "   ACTIONS_ID_TOKEN_REQUEST_TOKEN: ${ACTIONS_ID_TOKEN_REQUEST_TOKEN:+SET}" >&2
  exit 1
fi

GH_ID_TOKEN=$(curl -sS -H "Authorization: Bearer ${ACTIONS_ID_TOKEN_REQUEST_TOKEN}" \
  "${ACTIONS_ID_TOKEN_REQUEST_URL}&audience=${JFROG_URL}" | jq -r .value)

if [[ -z "$GH_ID_TOKEN" || "$GH_ID_TOKEN" == "null" ]]; then
  echo "❌ Failed to fetch GitHub OIDC ID token" >&2
  exit 1
fi

if [[ "$VERBOSE" == "true" ]]; then
  echo "✅ GitHub OIDC ID token obtained"
fi

# Step 2: Exchange GitHub token for JFrog access token
if [[ "$VERBOSE" == "true" ]]; then
  echo "🔄 Step 2: Exchanging token at JFrog Access API..."
fi

PAYLOAD=$(jq -n --arg jwt "$GH_ID_TOKEN" --arg provider "$PROVIDER_NAME" \
  '{grant_type: "urn:ietf:params:oauth:grant-type:token-exchange", subject_token: $jwt, subject_token_type: "urn:ietf:params:oauth:token-type:id_token", provider_name: $provider}')

JF_ACCESS_TOKEN=$(curl -sS -X POST "${JFROG_URL}/access/api/v1/oidc/token" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" | jq -r .access_token)

if [[ -z "$JF_ACCESS_TOKEN" || "$JF_ACCESS_TOKEN" == "null" ]]; then
  echo "❌ Failed to exchange OIDC token at JFrog" >&2
  exit 1
fi

if [[ "$VERBOSE" == "true" ]]; then
  echo "✅ JFrog access token obtained"
fi

# Step 3: Set environment variables and outputs
echo "JF_OIDC_TOKEN=$JF_ACCESS_TOKEN" >> $GITHUB_ENV
echo "token=$JF_ACCESS_TOKEN" >> $GITHUB_OUTPUT

if [[ "$VERBOSE" == "true" ]]; then
  echo "✅ Environment variables set: JF_OIDC_TOKEN"
fi

# Step 4: Docker registry login (if registry specified)
if [[ -n "$DOCKER_REGISTRY" ]]; then
  if [[ "$VERBOSE" == "true" ]]; then
    echo "🔄 Step 3: Configuring Docker registry authentication..."
  fi
  
  # Extract username from JWT token payload
  b64pad() { 
    local l=${#1}
    local m=$((l % 4))
    if [ $m -eq 2 ]; then echo "$1=="
    elif [ $m -eq 3 ]; then echo "$1="
    else echo "$1"
    fi
  }
  
  PAY=$(echo "$JF_ACCESS_TOKEN" | cut -d. -f2 || true)
  PAY_PAD=$(b64pad "$PAY")
  CLAIMS=$(echo "$PAY_PAD" | tr '_-' '/+' | base64 -d 2>/dev/null || true)
  DOCKER_USER=$(echo "$CLAIMS" | jq -r '.username // .sub // .subject // empty' 2>/dev/null || true)
  
  # If sub is in the form jfac@.../users/<username>, extract the trailing <username>
  if [[ "$DOCKER_USER" == *"/users/"* ]]; then
    DOCKER_USER=${DOCKER_USER##*/users/}
  fi
  
  # Fallback to oauth2_access_token if no username found
  if [[ -z "$DOCKER_USER" || "$DOCKER_USER" == "null" ]]; then
    DOCKER_USER="oauth2_access_token"
  fi
  
  if [[ "$VERBOSE" == "true" ]]; then
    echo "🐳 Docker username: $DOCKER_USER"
  fi
  
  # Perform Docker login
  echo "$JF_ACCESS_TOKEN" | docker login "$DOCKER_REGISTRY" -u "$DOCKER_USER" --password-stdin
  
  if [[ "$VERBOSE" == "true" ]]; then
    echo "✅ Docker registry authentication configured"
  fi
fi

if [[ "$VERBOSE" == "true" ]]; then
  echo "🎉 OIDC token exchange completed successfully for $SERVICE_NAME"
fi
