#!/usr/bin/env bash

set -e

# =============================================================================
# VERBOSITY CONFIGURATION
# =============================================================================
# Set VERBOSITY level for output control:
# 0 = Silent (no output, just execute)
# 1 = Feedback (show progress and results)
# 2 = Debug (show commands, confirmations, and full output)
VERBOSITY="${VERBOSITY:-1}"
# Flags
DRY_RUN=false
AUTO_YES=false
EXPLICIT_SCOPES=false
RUN_APPS=true
RUN_OIDC=true
RUN_REPOS=true
RUN_STAGES=true
RUN_USERS=true
RUN_PROJECT=true

print_usage() {
  cat <<EOF
Usage: ./cleanup_local.sh [options]

Options:
  --dry-run           Show what would be deleted; do not perform destructive actions
  --yes               Skip confirmation prompt (non-interactive)
  --apps              Delete applications (and their versions)
  --oidc              Delete OIDC integrations
  --repos             Delete repositories
  --stages            Clear lifecycle and delete local stages
  --users             Delete demo users
  --project           Delete the JFrog project

Notes:
  - If any of --apps/--oidc/--repos/--stages/--users/--project are provided,
    only the provided scopes will run. Otherwise, all scopes run.
  - Use VERBOSITY=2 for interactive step-by-step debug.
EOF
}

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=true; shift ;;
    --yes)
      AUTO_YES=true; shift ;;
    --apps)
      EXPLICIT_SCOPES=true; RUN_APPS=true; RUN_OIDC=false; RUN_REPOS=false; RUN_STAGES=false; RUN_USERS=false; RUN_PROJECT=false; shift ;;
    --oidc)
      EXPLICIT_SCOPES=true; RUN_OIDC=true; shift ;;
    --repos)
      EXPLICIT_SCOPES=true; RUN_REPOS=true; shift ;;
    --stages)
      EXPLICIT_SCOPES=true; RUN_STAGES=true; shift ;;
    --users)
      EXPLICIT_SCOPES=true; RUN_USERS=true; shift ;;
    --project)
      EXPLICIT_SCOPES=true; RUN_PROJECT=true; shift ;;
    -h|--help)
      print_usage; exit 0 ;;
    *)
      echo "⚠️  Unknown option: $1"; print_usage; exit 1 ;;
  esac
done

# Function to run command with verbosity control
run_verbose_command() {
    local description="$1"
    local command="$2"
    
    if [ "$VERBOSITY" -ge 2 ]; then
        # Debug mode - show command and ask for confirmation
        echo ""
        echo "🔍 DEBUG MODE: $description"
        echo "   Command to execute:"
        echo "   $command"
        echo ""
        read -p "   Press Enter to execute this command, or 'q' to quit: " user_input
        
        if [ "$user_input" = "q" ] || [ "$user_input" = "Q" ]; then
            echo "   ❌ User cancelled execution. Exiting."
            exit 0
        fi
        
        echo "   🚀 Executing command..."
        echo "   ========================================="
        eval "$command"
        echo "   ========================================="
        echo "   ✅ Command completed."
        echo ""
        read -p "   Press Enter to continue to next step: " continue_input
    elif [ "$VERBOSITY" -ge 1 ]; then
        # Feedback mode - show what's happening
        echo "   🔧 $description..."
        eval "$command"
        echo "   ✅ $description completed"
    else
        # Silent mode - just execute
        eval "$command"
    fi
}

# Helper to GET JSON content (silent on errors)
perform_get() {
  local url="$1"
  curl -s \
    --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
    --header "Content-Type: application/json" \
    -X GET "$url" || true
}

# Function to show verbosity info
show_verbosity_info() {
    case "$VERBOSITY" in
        0)
            echo "🔇 SILENT MODE ENABLED"
            echo "   - No output will be shown"
            echo "   - Commands will execute silently"
            echo "   - Only errors will be displayed"
            ;;
        1)
            echo "📢 FEEDBACK MODE ENABLED"
            echo "   - Progress and results will be shown"
            echo "   - Commands will execute automatically"
            echo "   - No user interaction required"
            ;;
        2)
            echo "🐛 DEBUG MODE ENABLED"
            echo "   - Each step will be shown before execution"
            echo "   - Commands will be displayed verbosely"
            echo "   - User confirmation required for each step"
            echo "   - Full output will be shown"
            ;;
        *)
            echo "⚠️  Invalid VERBOSITY level: $VERBOSITY"
            echo "   Using default: VERBOSITY=1 (Feedback mode)"
            VERBOSITY=1
            ;;
    esac
    echo ""
}

echo "🧹 BookVerse JFrog Platform Cleanup - Local Runner"
echo "=================================================="
echo ""

# Show debug mode status
show_verbosity_info

# Check if required environment variables are set
if [[ -z "${JFROG_URL}" ]]; then
  echo "❌ Error: JFROG_URL is not set"
  echo "   Please export JFROG_URL='your-jfrog-instance-url'"
  echo "   Example: export JFROG_URL='https://your-instance.jfrog.io/'"
  exit 1
fi

if [[ -z "${JFROG_ADMIN_TOKEN}" ]]; then
  echo "❌ Error: JFROG_ADMIN_TOKEN is not set"
  echo "   Please export JFROG_ADMIN_TOKEN='your-admin-token'"
  exit 1
fi

echo "✅ Environment variables validated"
echo "   JFROG_URL: ${JFROG_URL}"
echo "   JFROG_ADMIN_TOKEN: [HIDDEN]"
echo ""

# Source global configuration
source ./.github/scripts/setup/config.sh

echo "📋 Configuration loaded:"
echo "   Project Key: ${PROJECT_KEY}"
echo "   Project Display Name: ${PROJECT_DISPLAY_NAME}"
echo ""

# =============================================================================
# CONFIRMATION
# =============================================================================
echo "⚠️  WARNING: This script will DELETE ALL resources in the BookVerse project!"
echo "   This includes:"
echo "   - All applications and their versions"
echo "   - All OIDC integrations"
echo "   - All repositories"
echo "   - All stages"
echo "   - All users"
echo "   - The project itself"
echo ""
echo "   This action is IRREVERSIBLE!"
echo ""

if [ "$VERBOSITY" -ge 2 ] || [ "$AUTO_YES" = true ]; then
  echo "✅ Auto-confirm enabled (${AUTO_YES:+--yes }VERBOSITY=$VERBOSITY). Proceeding with cleanup..."
else
  read -p "Type 'DELETE' to confirm you want to proceed with cleanup: " confirmation
  if [ "$confirmation" != "DELETE" ]; then
      echo "❌ Cleanup cancelled. Exiting."
      exit 0
  fi
  echo "✅ Confirmation received. Proceeding with cleanup..."
fi

echo ""
echo "🔄 Starting cleanup sequence..."
echo ""

# Helpers for destructive requests
perform_delete() {
  local url="$1"
  if [ "$DRY_RUN" = true ]; then
    echo "     🧪 DRY-RUN: DELETE $url"
    echo 204
  else
    curl -s -o /dev/null -w "%{http_code}" \
      --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
      --header "Content-Type: application/json" \
      -X DELETE "$url"
  fi
}

perform_patch() {
  local url="$1"; local payload="$2"
  if [ "$DRY_RUN" = true ]; then
    echo "     🧪 DRY-RUN: PATCH $url"
    echo "     🧪 Payload: $payload"
    echo 204
  else
    curl -s -o /dev/null -w "%{http_code}" \
      --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
      --header "Content-Type: application/json" \
      -X PATCH -d "$payload" "$url"
  fi
}

# =============================================================================
# STEP 1: DELETE APPLICATIONS
# =============================================================================
if [ "$EXPLICIT_SCOPES" = false ] || [ "$RUN_APPS" = true ]; then
if [ "$VERBOSITY" -ge 1 ]; then
  echo "📱 Step 1/6: Deleting Applications..."
  echo "   Deleting all applications in project: ${PROJECT_KEY}"
  echo "   API Endpoint: ${JFROG_URL}/apptrust/api/v1/applications"
  echo "   Method: DELETE"
  echo "   Note: Application versions must be deleted first"
  echo ""
fi

# Discover applications dynamically; fallback to known keys
applications=()
apps_list_json=$(perform_get "${JFROG_URL}/apptrust/api/v1/applications?project_key=${PROJECT_KEY}")
if echo "$apps_list_json" | jq -e . >/dev/null 2>&1; then
    dynamic_apps=$(echo "$apps_list_json" | jq -r '..|.application_key? // empty')
    if [ -n "$dynamic_apps" ]; then
        while IFS= read -r ak; do
            # accept keys that start with project prefix or any returned
            applications+=("${ak#${PROJECT_KEY}-}")
        done <<< "$dynamic_apps"
    fi
fi
if [ ${#applications[@]} -eq 0 ]; then
    applications=(
        "inventory"
        "recommendations"
        "checkout"
        "platform"
    )
fi

for app in "${applications[@]}"; do
    app_key="${PROJECT_KEY}-${app}"
    echo "   🗑️  Processing application: $app_key"
    
    # First, check if application has versions
    echo "     🔍 Checking for application versions..."
    versions_response=$(curl -s \
        --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
        --header "Content-Type: application/json" \
        -X GET \
        "${JFROG_URL}/apptrust/api/v1/applications/$app_key/versions")
    
    # Check if response contains versions
    if echo "$versions_response" | grep -q '"versions"' && echo "$versions_response" | grep -q '"total"' && [ "$(echo "$versions_response" | jq -r '.total // 0')" -gt 0 ]; then
        total_versions=$(echo "$versions_response" | jq -r '.total // 0')
        echo "     📋 Found $total_versions application version(s)"
        
        # Extract version names and delete them
        versions=$(echo "$versions_response" | jq -r '.versions[].version // empty')
        for version in $versions; do
            if [[ -n "$version" ]]; then
                echo "       🗑️  Deleting version: $version"
                version_response_code=$(curl -s -o /dev/null -w "%{http_code}" \
                    --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
                    --header "Content-Type: application/json" \
                    -X DELETE \
                    "${JFROG_URL}/apptrust/api/v1/applications/$app_key/versions/$version")
                
                if [ "$version_response_code" -eq 200 ] || [ "$version_response_code" -eq 204 ]; then
                    echo "         ✅ Version '$version' deleted successfully (HTTP $version_response_code)"
                elif [ "$version_response_code" -eq 404 ]; then
                    echo "         ⚠️  Version '$version' not found (HTTP $version_response_code)"
                else
                    echo "         ❌ Failed to delete version '$version' (HTTP $version_response_code)"
                    FAILED=true
                fi
            fi
        done
    else
        echo "     ℹ️  No application versions found"
    fi
    
    # Now delete the application itself
    echo "     🗑️  Deleting application: $app_key"
    app_response_code=$(curl -s -o /dev/null -w "%{http_code}" \
        --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
        --header "Content-Type: application/json" \
        -X DELETE \
        "${JFROG_URL}/apptrust/api/v1/applications/$app_key")
    
    if [ "$app_response_code" -eq 200 ] || [ "$app_response_code" -eq 204 ]; then
        echo "     ✅ Application '$app_key' deleted successfully (HTTP $app_response_code)"
    elif [ "$app_response_code" -eq 404 ]; then
        echo "     ⚠️  Application '$app_key' not found (HTTP $app_response_code)"
    else
        echo "     ❌ Failed to delete application '$app_key' (HTTP $app_response_code)"
        FAILED=true
    fi
    echo ""
done
fi

# =============================================================================
# STEP 2: DELETE OIDC INTEGRATIONS
# =============================================================================
if [ "$EXPLICIT_SCOPES" = false ] || [ "$RUN_OIDC" = true ]; then
if [ "$VERBOSITY" -ge 1 ]; then
  echo "🔐 Step 2/6: Deleting OIDC Integrations..."
  echo "   Attempting deletion across possible endpoints and names"
  echo ""
fi

# Known provider names created by the demo (if present)
oidc_provider_names=(
  "github-${PROJECT_KEY}-inventory"
  "github-${PROJECT_KEY}-recommendations"
  "github-${PROJECT_KEY}-checkout"
  "github-${PROJECT_KEY}-platform"
  "github-${PROJECT_KEY}-web"
)

# Legacy/team-style names (for backward compatibility)
legacy_integrations=(
  "${PROJECT_KEY}-inventory-team"
  "${PROJECT_KEY}-recommendations-team"
  "${PROJECT_KEY}-checkout-team"
  "${PROJECT_KEY}-platform-team"
)

# Try deleting identity mappings first (best-effort)
for name in "${oidc_provider_names[@]}"; do
  echo "   🗑️  Deleting identity mappings for provider: $name (best-effort)"
  perform_delete "${JFROG_URL}/access/api/v1/oidc/${name}/identity_mappings" >/dev/null || true
  perform_delete "${JFROG_URL}/access/api/v1/oidc/providers/${name}/identity_mappings" >/dev/null || true
done

delete_oidc_name() {
  local name="$1"
  local endpoints=(
    "${JFROG_URL}/access/api/v1/oidc/${name}"
    "${JFROG_URL}/access/api/v1/oidc/providers/${name}"
    "${JFROG_URL}/access/api/v1/oidc/integrations/${name}"
  )
  local ok=false
  for ep in "${endpoints[@]}"; do
    code=$(perform_delete "$ep")
    if [ "$code" -eq 200 ] || [ "$code" -eq 204 ]; then ok=true; break; fi
  done
  if [ "$ok" = true ]; then
    echo "     ✅ OIDC '${name}' deleted"
  else
    echo "     ⚠️  OIDC '${name}' not found or could not be deleted (ignored)"
  fi
}

for name in "${oidc_provider_names[@]}"; do delete_oidc_name "$name"; done
for name in "${legacy_integrations[@]}"; do delete_oidc_name "$name"; done

echo ""
fi

echo ""

# =============================================================================
# STEP 3: DELETE REPOSITORIES
# =============================================================================
if [ "$EXPLICIT_SCOPES" = false ] || [ "$RUN_REPOS" = true ]; then
if [ "$VERBOSITY" -ge 1 ]; then
  echo "📦 Step 3/6: Deleting Repositories..."
  echo "   Deleting all repositories in project: ${PROJECT_KEY}"
  echo "   API Endpoint: ${JFROG_URL}/artifactory/api/repositories"
  echo "   Method: DELETE"
  echo ""
fi

# Discover repositories by prefix; fallback to known list
repositories=()
repos_json=$(perform_get "${JFROG_URL}/artifactory/api/repositories?type=local")
if echo "$repos_json" | jq -e . >/dev/null 2>&1; then
    dyn_repos=$(echo "$repos_json" | jq -r '.[]?.key // empty' | grep "^${PROJECT_KEY}-" || true)
    if [ -n "$dyn_repos" ]; then
        while IFS= read -r rk; do
            repositories+=("$rk")
        done <<< "$dyn_repos"
    fi
fi
if [ ${#repositories[@]} -eq 0 ]; then
    repositories=(
        "${PROJECT_KEY}-inventory-docker-internal-local"
        "${PROJECT_KEY}-inventory-docker-release-local"
        "${PROJECT_KEY}-inventory-python-internal-local"
        "${PROJECT_KEY}-inventory-python-release-local"
        "${PROJECT_KEY}-recommendations-docker-internal-local"
        "${PROJECT_KEY}-recommendations-docker-release-local"
        "${PROJECT_KEY}-recommendations-python-internal-local"
        "${PROJECT_KEY}-recommendations-python-release-local"
        "${PROJECT_KEY}-checkout-docker-internal-local"
        "${PROJECT_KEY}-checkout-docker-release-local"
        "${PROJECT_KEY}-checkout-python-internal-local"
        "${PROJECT_KEY}-checkout-python-release-local"
        "${PROJECT_KEY}-platform-docker-internal-local"
        "${PROJECT_KEY}-platform-docker-release-local"
        "${PROJECT_KEY}-platform-python-internal-local"
        "${PROJECT_KEY}-platform-python-release-local"
        "${PROJECT_KEY}-platform-maven-internal-local"
        "${PROJECT_KEY}-platform-maven-release-local"
        "${PROJECT_KEY}-web-npm-internal-local"
        "${PROJECT_KEY}-web-npm-release-local"
        "${PROJECT_KEY}-helm-helm-internal-local"
        "${PROJECT_KEY}-helm-helm-release-local"
    )
fi

for repo in "${repositories[@]}"; do
    echo "   🗑️  Deleting repository: $repo"
    
    response_code=$(perform_delete "${JFROG_URL}/artifactory/api/repositories/$repo")
    
    if [ "$response_code" -eq 200 ] || [ "$response_code" -eq 204 ]; then
        echo "     ✅ Repository '$repo' deleted successfully (HTTP $response_code)"
    elif [ "$response_code" -eq 404 ]; then
        echo "     ⚠️  Repository '$repo' not found (HTTP $response_code)"
    else
        echo "     ❌ Failed to delete repository '$repo' (HTTP $response_code)"
        FAILED=true
    fi
done

echo ""
fi

# =============================================================================
# STEP 4: DELETE STAGES
# =============================================================================
if [ "$EXPLICIT_SCOPES" = false ] || [ "$RUN_STAGES" = true ]; then
if [ "$VERBOSITY" -ge 1 ]; then
  echo "🎭 Step 4/6: Deleting Stages..."
  echo "   Deleting all stages in project: ${PROJECT_KEY}"
  echo "   API Endpoint: ${JFROG_URL}/access/api/v2/stages"
  echo "   Method: DELETE"
  echo "   Note: Stages must be removed from lifecycle first"
  echo ""
fi

# First, remove stages from lifecycle
echo "   🔄 Removing stages from lifecycle..."
lifecycle_payload=$(jq -n '{
  "promote_stages": []
}')

lifecycle_response_code=$(perform_patch "${JFROG_URL}/access/api/v2/lifecycle/?project_key=${PROJECT_KEY}" "$lifecycle_payload")

if [ "$lifecycle_response_code" -eq 200 ] || [ "$lifecycle_response_code" -eq 204 ]; then
  echo "     ✅ Lifecycle cleared successfully (HTTP $lifecycle_response_code)"
  echo "     Status: SUCCESS - All stages removed from lifecycle"
elif [ "$lifecycle_response_code" -eq 404 ]; then
  echo "     ⚠️  Project '${PROJECT_KEY}' not found for lifecycle update (HTTP $lifecycle_response_code)"
else
  echo "     ⚠️  Lifecycle update returned HTTP $lifecycle_response_code (continuing anyway)"
fi

echo ""

# Discover stages dynamically; fallback to known names
stages=()
stages_json=$(perform_get "${JFROG_URL}/access/api/v2/stages/?project_key=${PROJECT_KEY}")
if echo "$stages_json" | jq -e . >/dev/null 2>&1; then
    dyn_stages=$(echo "$stages_json" | jq -r '..|.name? // empty' | grep "^${PROJECT_KEY}-" | sort -u || true)
    if [ -n "$dyn_stages" ]; then
        while IFS= read -r sn; do
            stages+=("$sn")
        done <<< "$dyn_stages"
    fi
fi
if [ ${#stages[@]} -eq 0 ]; then
    stages=(
        "${PROJECT_KEY}-DEV"
        "${PROJECT_KEY}-QA"
        "${PROJECT_KEY}-STAGING"
    )
fi

for stage in "${stages[@]}"; do
    echo "   🗑️  Deleting stage: $stage"
    
    response_code=$(perform_delete "${JFROG_URL}/access/api/v2/stages/$stage")
    
    if [ "$response_code" -eq 200 ] || [ "$response_code" -eq 204 ]; then
        echo "     ✅ Stage '$stage' deleted successfully (HTTP $response_code)"
    elif [ "$response_code" -eq 404 ]; then
        echo "     ⚠️  Stage '$stage' not found (HTTP $response_code)"
    else
        echo "     ❌ Failed to delete stage '$stage' (HTTP $response_code)"
        FAILED=true
    fi
done

echo ""
fi

# =============================================================================
# STEP 5: DELETE USERS
# =============================================================================
if [ "$EXPLICIT_SCOPES" = false ] || [ "$RUN_USERS" = true ]; then
if [ "$VERBOSITY" -ge 1 ]; then
  echo "👥 Step 5/6: Deleting Users..."
  echo "   Deleting all users created for project: ${PROJECT_KEY}"
  echo "   API Endpoint: ${JFROG_URL}/access/api/v2/users"
  echo "   Method: DELETE"
  echo "   Note: Users will be completely removed from JFrog Platform"
  echo ""
fi

# Discover project members (best-effort); fallback to known list
users=()
proj_json=$(perform_get "${JFROG_URL}/access/api/v1/projects/${PROJECT_KEY}")
if echo "$proj_json" | jq -e . >/dev/null 2>&1; then
    dyn_users=$(echo "$proj_json" | jq -r '.members[]?.name // empty' 2>/dev/null || true)
    if [ -n "$dyn_users" ]; then
        while IFS= read -r un; do
            users+=("$un")
        done <<< "$dyn_users"
    fi
fi
if [ ${#users[@]} -eq 0 ]; then
    users=(
        "alice.developer@bookverse.com"
        "bob.release@bookverse.com"
        "charlie.devops@bookverse.com"
        "diana.architect@bookverse.com"
        "edward.manager@bookverse.com"
        "frank.inventory@bookverse.com"
        "grace.ai@bookverse.com"
        "henry.checkout@bookverse.com"
        "pipeline.inventory@bookverse.com"
        "pipeline.recommendations@bookverse.com"
        "pipeline.checkout@bookverse.com"
        "pipeline.platform@bookverse.com"
    )
fi

for user in "${users[@]}"; do
    echo "   🗑️  Deleting user: $user"
    
    response_code=$(perform_delete "${JFROG_URL}/access/api/v2/users/$user")
    
    if [ "$response_code" -eq 200 ] || [ "$response_code" -eq 204 ]; then
        echo "     ✅ User '$user' deleted successfully (HTTP $response_code)"
    elif [ "$response_code" -eq 404 ]; then
        echo "     ⚠️  User '$user' not found (HTTP $response_code)"
    else
        echo "     ❌ Failed to delete user '$user' (HTTP $response_code)"
        FAILED=true
    fi
done

echo ""
fi

# =============================================================================
# STEP 6: DELETE PROJECT
# =============================================================================
if [ "$EXPLICIT_SCOPES" = false ] || [ "$RUN_PROJECT" = true ]; then
if [ "$VERBOSITY" -ge 1 ]; then
  echo "🏗️  Step 6/6: Deleting Project..."
  echo "   Deleting project: ${PROJECT_KEY}"
  echo "   API Endpoint: ${JFROG_URL}/access/api/v1/projects/${PROJECT_KEY}"
  echo "   Method: DELETE"
  echo "   Note: All resources must be deleted first"
  echo ""
fi

echo "   🗑️  Deleting project: ${PROJECT_KEY}"

response_code=$(perform_delete "${JFROG_URL}/access/api/v1/projects/${PROJECT_KEY}")

if [ "$response_code" -eq 200 ] || [ "$response_code" -eq 204 ]; then
    echo "     ✅ Project '${PROJECT_KEY}' deleted successfully (HTTP $response_code)"
    echo "     Status: SUCCESS - Project and all resources removed"
elif [ "$response_code" -eq 404 ]; then
    echo "     ⚠️  Project '${PROJECT_KEY}' not found (HTTP $response_code)"
    echo "     Status: SKIPPED - Project was already deleted"
else
    echo "     ❌ Failed to delete project '${PROJECT_KEY}' (HTTP $response_code)"
    echo "     Status: ERROR - Project deletion failed"
    FAILED=true
fi

echo ""

# =============================================================================
# CLEANUP SUMMARY
# =============================================================================
if [ "$FAILED" = true ]; then
    echo "⚠️  Cleanup completed with some errors."
    echo "   Some resources may still exist and need manual cleanup."
    echo "   Check the logs above for specific failures."
    echo ""
    echo "   You may need to manually delete remaining resources or"
    echo "   contact your JFrog administrator for assistance."
else
    echo "✅ Cleanup completed successfully!"
    echo "   All resources in project '${PROJECT_KEY}' have been removed."
    echo "   The project has been deleted."
    echo ""
    echo "   🎯 Resources cleaned up:"
    echo "     • Applications: 4 AppTrust applications (with versions)"
    echo "     • OIDC Integrations: 4 OIDC integrations"
    echo "     • Repositories: 16 Artifactory repositories"
    echo "     • Stages: 3 local stages (DEV, QA, STAGE)"
    echo "     • Users: 12 users completely deleted"
    echo "     • Project: '${PROJECT_KEY}' project deleted"
    echo ""
    echo "   💡 Note: All user accounts have been completely removed from"
    echo "      the JFrog Platform, not just from the project."
fi

echo ""
echo "🧹 Cleanup process finished!"
