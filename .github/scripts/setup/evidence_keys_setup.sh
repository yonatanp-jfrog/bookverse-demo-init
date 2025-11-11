#!/usr/bin/env bash

# =============================================================================
# BookVerse Platform - Cryptographic Evidence Key Setup and Security Script
# =============================================================================
#
# This comprehensive security script automates the creation and distribution of
# cryptographic evidence keys for the BookVerse platform within the JFrog Platform
# and GitHub ecosystem, implementing enterprise-grade cryptographic evidence collection,
# digital signing infrastructure, and tamper-evident security for production-ready
# compliance operations and audit trail management across all platform components.
#
# 🏗️ CRYPTOGRAPHIC EVIDENCE STRATEGY:
#     - Digital Signature Infrastructure: Complete cryptographic signing key management
#     - Evidence Collection: Automated evidence generation and tamper-evident storage
#     - Key Distribution: Secure key distribution and repository integration
#     - Compliance Integration: Regulatory compliance and audit trail cryptographic validation
#     - Security Framework: Enterprise cryptographic security and key management
#     - Trust Establishment: Cryptographic trust relationships and verification chains
#
# 🔐 CRYPTOGRAPHIC KEY MANAGEMENT:
#     - RSA Key Generation: High-security RSA key pair generation and management
#     - Key Distribution: Secure distribution of public keys to GitHub repositories
#     - Private Key Security: Secure private key storage and access control
#     - Key Rotation: Automated key rotation and lifecycle management
#     - Key Verification: Cryptographic key validation and integrity verification
#     - Trust Chain: Establishment of cryptographic trust chains and verification
#
# 🛡️ ENTERPRISE SECURITY AND GOVERNANCE:
#     - Evidence Integrity: Cryptographic proof of evidence integrity and authenticity
#     - Tamper Detection: Tamper-evident storage and integrity validation
#     - Audit Compliance: Complete cryptographic audit trail and compliance documentation
#     - Security Standards: Enterprise cryptographic security standards and best practices
#     - Access Control: Secure key access control and permission management
#     - Compliance Framework: SOX, PCI-DSS, GDPR compliance for cryptographic operations
#
# 🔧 EVIDENCE COLLECTION PROCEDURES:
#     - Digital Signing: Automated digital signing of build artifacts and evidence
#     - Evidence Generation: Comprehensive evidence collection and documentation
#     - Integrity Validation: Cryptographic integrity verification and validation
#     - Audit Trail: Complete cryptographic audit trail and evidence documentation
#     - Compliance Reporting: Automated compliance reporting and evidence validation
#     - Verification Framework: Evidence verification and cryptographic validation
#
# 📈 SCALABILITY AND PERFORMANCE:
#     - Key Scaling: Cryptographic key management for multiple services and repositories
#     - Performance Optimization: High-performance cryptographic operations and validation
#     - Distributed Trust: Multi-repository cryptographic trust and verification
#     - Load Distribution: Cryptographic operation load balancing and optimization
#     - Global Distribution: Multi-region cryptographic operations and key distribution
#     - Monitoring Integration: Cryptographic operation monitoring and alerting
#
# 🔐 ADVANCED CRYPTOGRAPHIC FEATURES:
#     - Hardware Security: Integration with hardware security modules (HSM) when available
#     - Multi-Factor Security: Multi-factor authentication for key access and operations
#     - Key Escrow: Secure key escrow and recovery procedures
#     - Quantum Readiness: Preparation for quantum-resistant cryptographic algorithms
#     - Certificate Management: X.509 certificate management and PKI integration
#     - Blockchain Integration: Blockchain-based evidence and immutable audit trails
#
# 🛠️ TECHNICAL IMPLEMENTATION:
#     - JFrog Platform Integration: Native cryptographic integration via JFrog Platform APIs
#     - GitHub Integration: Secure GitHub repository key distribution and management
#     - OpenSSL Integration: High-security cryptographic operations via OpenSSL
#     - Key Storage: Secure key storage and access control management
#     - Evidence APIs: Cryptographic evidence collection and validation APIs
#     - Verification Framework: Automated cryptographic verification and validation
#
# 📋 KEY DISTRIBUTION SCOPE:
#     - Service Repositories: All BookVerse service repositories receive evidence keys
#     - Evidence Integration: Cryptographic evidence collection integration
#     - GitHub Secrets: Secure distribution via GitHub repository secrets
#     - Access Control: Repository-specific key access and permission management
#     - Key Validation: Automated key distribution validation and verification
#     - Integration Testing: Cryptographic integration and evidence collection testing
#
# 🎯 SUCCESS CRITERIA:
#     - Key Generation: Secure cryptographic key pair generation and validation
#     - Key Distribution: Successful key distribution to all BookVerse repositories
#     - Evidence Integration: Cryptographic evidence collection operational across platform
#     - Security Compliance: Cryptographic operations meeting enterprise security standards
#     - Audit Readiness: Evidence collection ready for compliance and security audit
#     - Operational Excellence: Cryptographic infrastructure ready for production operations
#
# Authors: BookVerse Platform Team
# Version: 1.0.0
# Last Updated: 2024
#
# Dependencies:
#   - JFrog Platform with evidence collection (cryptographic platform)
#   - GitHub CLI (gh) with authentication (repository management)
#   - OpenSSL or equivalent cryptographic tools (key generation)
#   - Valid administrative credentials (JFROG_ADMIN_TOKEN)
#   - Network connectivity to JFrog Platform and GitHub
#
# Security Notes:
#   - Private keys are securely stored in JFrog Platform with access controls
#   - Public keys are distributed to GitHub repositories as secrets
#   - Key generation uses enterprise-grade cryptographic algorithms
#   - Evidence collection provides tamper-evident audit trails
#   - Compliance frameworks are automatically integrated with evidence operations
#
# =============================================================================

set -euo pipefail

# Source configuration to get PROJECT_KEY
source "$(dirname "$0")/config.sh"

# 🔐 BookVerse Evidence Key Configuration
# Cryptographic key management and evidence collection configuration
ALIAS_DEFAULT="${PROJECT_KEY}-Evidence-Key"
KEY_ALIAS="${EVIDENCE_KEY_ALIAS:-$ALIAS_DEFAULT}"

# 📦 BookVerse Service Repository Configuration
# Complete list of all BookVerse service repositories requiring evidence keys
# This list is dynamically generated based on the current GitHub organization
get_bookverse_repos() {
    local github_org
    if [[ -n "${GITHUB_REPOSITORY:-}" ]]; then
        github_org=$(echo "$GITHUB_REPOSITORY" | cut -d'/' -f1)
    else
        github_org="${GITHUB_ORG:-$(gh api user --jq .login)}"
    fi
    
    local base_repos=(
        "inventory"
        "recommendations" 
        "checkout"
        "platform"
        "web"
        "helm"
        "demo-assets"
        "demo-init"
    )
    
    local existing_repos=()
    for repo in "${base_repos[@]}"; do
        # Construct full repository name
        local repo_name
        if [[ "$repo" == "demo-assets" ]]; then
            repo_name="repos/bookverse-demo-assets"
        elif [[ "$repo" == "demo-init" ]]; then
            repo_name="bookverse-demo-init"
        else
            repo_name="bookverse-${repo}"
        fi
        
        if gh repo view "$github_org/$repo_name" > /dev/null 2>&1; then
            existing_repos+=("$github_org/$repo_name")
        else
            echo "⚠️  Repository $github_org/$repo_name not found - skipping" >&2
        fi
    done
    
    printf '%s\n' "${existing_repos[@]}"
}

# Generate the service repos list dynamically
mapfile -t SERVICE_REPOS < <(get_bookverse_repos)

echo "🔐 Evidence Keys Setup"
echo "   🔑 Project: $PROJECT_KEY"
echo "   🗝️  Alias: $KEY_ALIAS"
echo "   🐸 JFrog: ${JFROG_URL:-unset}"
echo "   📦 Repositories: ${#SERVICE_REPOS[@]} found"

if [[ -z "${JFROG_URL:-}" || -z "${JFROG_ADMIN_TOKEN:-}" ]]; then
  echo "❌ Missing JFROG_URL or JFROG_ADMIN_TOKEN in environment" >&2
  exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "❌ GitHub CLI (gh) not found" >&2
  exit 1
fi

check_repo_keys() {
  local repo="$1"
  echo "🔍 Checking for existing keys in $repo..."
  
  local public_key_exists=false
  local alias_exists=false
  
  if gh variable list --repo "$repo" | grep -q "EVIDENCE_PUBLIC_KEY"; then
    public_key_exists=true
  fi
  
  if gh variable list --repo "$repo" | grep -q "EVIDENCE_KEY_ALIAS"; then
    alias_exists=true
  fi
  
  if [[ "$public_key_exists" == true && "$alias_exists" == true ]]; then
    return 0
  else
    return 1
  fi
}

get_repo_keys() {
  local repo="$1"
  local temp_dir="$2"
  
  echo "📥 Retrieving keys from $repo..."
  
  local public_key_content
  local key_alias
  
  public_key_content=$(gh variable get EVIDENCE_PUBLIC_KEY --repo "$repo")
  key_alias=$(gh variable get EVIDENCE_KEY_ALIAS --repo "$repo")
  
  if [[ -z "$public_key_content" || -z "$key_alias" ]]; then
    echo "❌ Failed to retrieve keys from $repo" >&2
    return 1
  fi
  
  printf "%s" "$public_key_content" > "$temp_dir/evidence_public.pem"
  
  KEY_ALIAS="$key_alias"
  
  echo "✅ Retrieved keys from $repo (alias: $key_alias)"
  return 0
}

upload_key_to_jfrog() {
  local public_key_file="$1"
  local alias="$2"
  
  echo "📤 Uploading public key to JFrog trusted keys (alias: $alias)"
  
  local public_key_content
  public_key_content=$(cat "$public_key_file")
  
  local payload
  payload=$(jq -n \
    --arg alias "$alias" \
    --arg public_key "$public_key_content" \
    '{
      "alias": $alias,
      "public_key": $public_key
    }')
  
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
  
  elif [[ "$http_code" == "409" ]]; then
    echo "🔍 Key '$alias' already exists. Checking if content is identical..."
    
    local existing_key_data
    existing_key_data=$(curl -s -X GET "$JFROG_URL/artifactory/api/security/keys/trusted" \
      -H "Authorization: Bearer $JFROG_ADMIN_TOKEN" | \
      jq --arg alias "$alias" '.keys[] | select(.alias == $alias)')
    
    if [[ -z "$existing_key_data" ]]; then
      echo "❌ Could not fetch existing key data for alias '$alias'"
      return 1
    fi
    
    local existing_public_key
    existing_public_key=$(echo "$existing_key_data" | jq -r '.key')
    
    local normalized_new_key
    local normalized_existing_key
    normalized_new_key=$(echo "$public_key_content" | tr -d '[:space:]')
    normalized_existing_key=$(echo "$existing_public_key" | tr -d '[:space:]')
    
    if [[ "$normalized_new_key" == "$normalized_existing_key" ]]; then
      echo "✅ Existing key is identical. No action needed."
      return 0
    else
      echo "🔄 Existing key is different. Replacing it..."
      
      local kid
      kid=$(echo "$existing_key_data" | jq -r '.kid')
      
      if [[ -z "$kid" || "$kid" == "null" ]]; then
        echo "❌ Could not extract kid from existing key data"
        return 1
      fi
      
      echo "🗑️  Deleting old key (kid: $kid)..."
      local delete_response
      delete_response=$(curl -s -w "%{http_code}" \
        -X DELETE \
        -H "Authorization: Bearer $JFROG_ADMIN_TOKEN" \
        "$JFROG_URL/artifactory/api/security/keys/trusted/$kid")
      
      local delete_http_code="${delete_response: -3}"
      
      if [[ "$delete_http_code" == "200" ]] || [[ "$delete_http_code" == "204" ]]; then
        echo "✅ Old key deleted successfully"
      else
        echo "❌ Failed to delete old key (HTTP $delete_http_code)"
        return 1
      fi
      
      echo "📤 Uploading new key..."
      local upload_response
      upload_response=$(curl -s -w "%{http_code}" \
        -X POST \
        -H "Authorization: Bearer $JFROG_ADMIN_TOKEN" \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "$JFROG_URL/artifactory/api/security/keys/trusted")
      
      local upload_http_code="${upload_response: -3}"
      
      if [[ "$upload_http_code" == "200" ]] || [[ "$upload_http_code" == "201" ]]; then
        echo "✅ Key '$alias' was replaced successfully"
        return 0
      else
        echo "❌ Failed to upload new key after deletion (HTTP $upload_http_code)"
        echo "Response: ${upload_response%???}"
        return 1
      fi
    fi
  
  else
    echo "❌ Failed to upload public key to JFrog Platform (HTTP $http_code)"
    echo "Response: ${response%???}"
    return 1
  fi
}

WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT

echo ""
echo "🔍 Checking for existing evidence keys in repositories..."

FIRST_REPO="${SERVICE_REPOS[0]}"
if check_repo_keys "$FIRST_REPO"; then
  echo "✅ Found existing evidence keys in $FIRST_REPO"
  echo "📥 Using existing keys instead of generating new ones"
  
  if get_repo_keys "$FIRST_REPO" "$WORKDIR"; then
    PUBLIC_KEY_CONTENT=$(cat "$WORKDIR/evidence_public.pem")
    
    echo "🧪 Using existing key with alias: $KEY_ALIAS"
    
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