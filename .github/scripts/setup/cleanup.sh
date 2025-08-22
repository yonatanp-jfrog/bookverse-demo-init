#!/usr/bin/env bash

set -e

# Source global configuration
source "$(dirname "$0")/config.sh"

# Validate environment variables
validate_environment

FAILED=false

echo "🧹 Starting cleanup of BookVerse project and all resources..."
echo "⚠️  WARNING: This will permanently delete ALL resources in the '${PROJECT_KEY}' project!"
echo "⚠️  WARNING: This action cannot be undone!"
echo ""

# Ask for confirmation
read -p "Are you sure you want to delete the entire '${PROJECT_KEY}' project? (type 'yes' to confirm): " confirmation

if [[ "$confirmation" != "yes" ]]; then
    echo "❌ Cleanup cancelled by user."
    exit 0
fi

echo ""
echo "🚨 Proceeding with cleanup of '${PROJECT_KEY}' project..."
echo ""

# =============================================================================
# STEP 1: DELETE APPLICATIONS (with version cleanup)
# =============================================================================
echo "📱 Step 1/6: Deleting Applications..."
echo "   Deleting all AppTrust applications in project '${PROJECT_KEY}'"
echo "   Note: Application versions will be deleted first if they exist"
echo ""

# List of applications to delete
applications=(
    "inventory"
    "recommendations" 
    "checkout"
    "platform"
)

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

# =============================================================================
# STEP 2: DELETE OIDC INTEGRATIONS
# =============================================================================
echo "🔐 Step 2/6: Deleting OIDC Integrations..."
echo "   Deleting all OIDC integrations in project '${PROJECT_KEY}'"
echo ""

# List of OIDC integrations to delete
oidc_integrations=(
    "inventory-team"
    "recommendations-team"
    "checkout-team"
    "platform-team"
)

for oidc in "${oidc_integrations[@]}"; do
    echo "   🗑️  Deleting OIDC integration: ${PROJECT_KEY}-${oidc}"
    
    response_code=$(curl -s -o /dev/null -w "%{http_code}" \
        --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
        --header "Content-Type: application/json" \
        -X DELETE \
        "${JFROG_URL}/access/api/v1/oidc/integrations/${PROJECT_KEY}-${oidc}")
    
    if [ "$response_code" -eq 200 ] || [ "$response_code" -eq 204 ]; then
        echo "     ✅ OIDC integration '${PROJECT_KEY}-${oidc}' deleted successfully (HTTP $response_code)"
    elif [ "$response_code" -eq 404 ]; then
        echo "     ⚠️  OIDC integration '${PROJECT_KEY}-${oidc}' not found (HTTP $response_code)"
    else
        echo "     ❌ Failed to delete OIDC integration '${PROJECT_KEY}-${oidc}' (HTTP $response_code)"
        FAILED=true
    fi
done

echo ""

# =============================================================================
# STEP 3: DELETE REPOSITORIES
# =============================================================================
echo "📦 Step 3/6: Deleting Repositories..."
echo "   Deleting all Artifactory repositories in project '${PROJECT_KEY}'"
echo ""

# List of repositories to delete
repositories=(
    # Inventory repositories
    "${PROJECT_KEY}-inventory-docker-internal-local"
    "${PROJECT_KEY}-inventory-docker-release-local"
    "${PROJECT_KEY}-inventory-python-internal-local"
    "${PROJECT_KEY}-inventory-python-release-local"
    
    # Recommendations repositories
    "${PROJECT_KEY}-recommendations-docker-internal-local"
    "${PROJECT_KEY}-recommendations-docker-release-local"
    "${PROJECT_KEY}-recommendations-python-internal-local"
    "${PROJECT_KEY}-recommendations-python-release-local"
    
    # Checkout repositories
    "${PROJECT_KEY}-checkout-docker-internal-local"
    "${PROJECT_KEY}-checkout-docker-release-local"
    "${PROJECT_KEY}-checkout-python-internal-local"
    "${PROJECT_KEY}-checkout-python-release-local"
    
    # Platform repositories
    "${PROJECT_KEY}-platform-docker-internal-local"
    "${PROJECT_KEY}-platform-docker-release-local"
    "${PROJECT_KEY}-platform-python-internal-local"
    "${PROJECT_KEY}-platform-python-release-local"
)

for repo in "${repositories[@]}"; do
    echo "   🗑️  Deleting repository: $repo"
    
    response_code=$(curl -s -o /dev/null -w "%{http_code}" \
        --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
        --header "Content-Type: application/json" \
        -X DELETE \
        "${JFROG_URL}/artifactory/api/repositories/$repo")
    
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

# =============================================================================
# STEP 4: DELETE STAGES (with lifecycle removal first)
# =============================================================================
echo "🎭 Step 4/6: Deleting Stages..."
echo "   Removing stages from lifecycle, then deleting local stages in project '${PROJECT_KEY}'"
echo "   Note: PROD stage is global and cannot be deleted"
echo ""

# First, remove stages from lifecycle
echo "   🔄 Removing stages from lifecycle..."
lifecycle_payload=$(jq -n '{
  "promote_stages": []
}')

lifecycle_response_code=$(curl -s -o /dev/null -w "%{http_code}" \
  --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
  --header "Content-Type: application/json" \
  -X PATCH \
  -d "$lifecycle_payload" \
  "${JFROG_URL}/access/api/v2/lifecycle/?project_key=${PROJECT_KEY}")

if [ "$lifecycle_response_code" -eq 200 ] || [ "$lifecycle_response_code" -eq 204 ]; then
  echo "     ✅ Lifecycle cleared successfully (HTTP $lifecycle_response_code)"
  echo "     Status: SUCCESS - All stages removed from lifecycle"
elif [ "$lifecycle_response_code" -eq 404 ]; then
  echo "     ⚠️  Project '${PROJECT_KEY}' not found for lifecycle update (HTTP $lifecycle_response_code)"
else
  echo "     ⚠️  Lifecycle update returned HTTP $lifecycle_response_code (continuing anyway)"
fi

echo ""

# List of stages to delete (only local stages, not PROD)
stages=(
    "${PROJECT_KEY}-DEV"
    "${PROJECT_KEY}-QA"
    "${PROJECT_KEY}-STAGING"
)

for stage in "${stages[@]}"; do
    echo "   🗑️  Deleting stage: $stage"
    
    response_code=$(curl -s -o /dev/null -w "%{http_code}" \
        --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
        --header "Content-Type: application/json" \
        -X DELETE \
        "${JFROG_URL}/access/api/v2/stages/$stage")
    
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

# =============================================================================
# STEP 5: DELETE USERS
# =============================================================================
echo "👥 Step 5/6: Deleting Users..."
echo "   Deleting all users created for the BookVerse project"
echo "   Note: Users will be completely removed from JFrog Platform"
echo ""

# List of users to delete
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

for user in "${users[@]}"; do
    echo "   🗑️  Deleting user: $user"
    
    response_code=$(curl -s -o /dev/null -w "%{http_code}" \
        --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
        --header "Content-Type: application/json" \
        -X DELETE \
        "${JFROG_URL}/access/api/v2/users/$user")
    
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

# =============================================================================
# STEP 6: DELETE PROJECT
# =============================================================================
echo "🏗️  Step 6/6: Deleting Project..."
echo "   Deleting project '${PROJECT_KEY}' and all remaining resources"
echo ""

echo "   🗑️  Deleting project: ${PROJECT_KEY}"
echo "   🔗 API: DELETE ${JFROG_URL}/access/api/v1/projects/${PROJECT_KEY}"

response_code=$(curl -s -o /dev/null -w "%{http_code}" \
    --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
    --header "Content-Type: application/json" \
    -X DELETE \
    "${JFROG_URL}/access/api/v1/projects/${PROJECT_KEY}")

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
