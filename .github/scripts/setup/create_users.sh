#!/usr/bin/env bash

# =============================================================================
# SIMPLIFIED USER CREATION SCRIPT
# =============================================================================
# Creates BookVerse users and assigns project roles without shared utility dependencies
# =============================================================================

set -e

# Load configuration
source "$(dirname "$0")/config.sh"

echo ""
echo "🚀 Creating BookVerse users and assigning project roles"
echo "🔧 Project: $PROJECT_KEY"
echo "🔧 JFrog URL: $JFROG_URL"
echo ""

# User definitions: username|email|password|role
BOOKVERSE_USERS=(
    "alice.developer@bookverse.com|alice.developer@bookverse.com|BookVerse2024!|Developer"
    "bob.release@bookverse.com|bob.release@bookverse.com|BookVerse2024!|Release Manager"
    "charlie.devops@bookverse.com|charlie.devops@bookverse.com|BookVerse2024!|Project Manager"
    "diana.architect@bookverse.com|diana.architect@bookverse.com|BookVerse2024!|AppTrust Admin"
    "edward.manager@bookverse.com|edward.manager@bookverse.com|BookVerse2024!|AppTrust Admin"
    "frank.inventory@bookverse.com|frank.inventory@bookverse.com|BookVerse2024!|Inventory Manager"
    "grace.ai@bookverse.com|grace.ai@bookverse.com|BookVerse2024!|AI/ML Manager"
    "henry.checkout@bookverse.com|henry.checkout@bookverse.com|BookVerse2024!|Checkout Manager"
    "pipeline.inventory@bookverse.com|pipeline.inventory@bookverse.com|Pipeline2024!|Pipeline User"
    "pipeline.recommendations@bookverse.com|pipeline.recommendations@bookverse.com|Pipeline2024!|Pipeline User"
    "pipeline.checkout@bookverse.com|pipeline.checkout@bookverse.com|Pipeline2024!|Pipeline User"
    "pipeline.web@bookverse.com|pipeline.web@bookverse.com|Pipeline2024!|Pipeline User"
    "pipeline.platform@bookverse.com|pipeline.platform@bookverse.com|Pipeline2024!|Pipeline User"
)

# Platform owners get Project Admin privileges
PLATFORM_OWNERS=(
    "diana.architect@bookverse.com"
    "edward.manager@bookverse.com"
    "charlie.devops@bookverse.com"
    "bob.release@bookverse.com"
    "frank.inventory@bookverse.com"
    "grace.ai@bookverse.com"
    "henry.checkout@bookverse.com"
)

# Function to check if user is a platform owner
is_platform_owner() {
    local username="$1"
    for owner in "${PLATFORM_OWNERS[@]}"; do
        [[ "$username" == "$owner" ]] && return 0
    done
    return 1
}

# Function to check if user is a pipeline automation user
is_pipeline_user() {
    local username="$1"
    [[ "$username" == pipeline.*@* ]]
}

# Map human-friendly titles to valid JFrog Project roles
# Allowed roles: Developer, Contributor, Viewer, Release Manager, Security Manager, Application Admin, Project Admin
map_role_to_project_role() {
    local title="$1"
    case "$title" in
        "Developer") echo "Developer" ;;
        "Release Manager") echo "Release Manager" ;;
        "Project Manager") echo "Project Admin" ;;
        # Application Admin is NOT a valid JFrog Project role. Map to Release Manager
        "AppTrust Admin") echo "Release Manager" ;;
        # Service managers should be members with elevated release capabilities
        "Inventory Manager"|"AI/ML Manager"|"Checkout Manager") echo "Release Manager" ;;
        "Pipeline User") echo "Developer" ;;
        *) echo "Viewer" ;;
    esac
}

# Function to create a user
create_user() {
    local username="$1"
    local email="$2"
    local password="$3"
    local role="$4"
    
    echo "Creating user: $username ($role)"
    
    # Build user JSON payload
    local user_payload=$(jq -n \
        --arg name "$username" \
        --arg email "$email" \
        --arg password "$password" \
        '{
            "name": $name,
            "email": $email,
            "password": $password,
            "admin": false,
            "profileUpdatable": true,
            "disableUIAccess": false,
            "groups": ["readers"]
        }')
    
    # Create user
    local temp_response=$(mktemp)
    local response_code=$(curl -s --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
        --header "Content-Type: application/json" \
        -X PUT \
        -d "$user_payload" \
        --write-out "%{http_code}" \
        --output "$temp_response" \
        "${JFROG_URL}/artifactory/api/security/users/${username}")
    
    case "$response_code" in
        200|201)
            echo "✅ User '$username' created successfully (HTTP $response_code)"
            ;;
        409)
            echo "⚠️  User '$username' already exists (HTTP $response_code)"
            ;;
        400)
            # Check if it's the "already exists" error
            if grep -q -i "already exists\|user.*exists" "$temp_response"; then
                echo "⚠️  User '$username' already exists (HTTP $response_code)"
            else
                echo "❌ Failed to create user '$username' (HTTP $response_code)"
                echo "Response body: $(cat "$temp_response")"
                rm -f "$temp_response"
                return 1
            fi
            ;;
        *)
            echo "❌ Failed to create user '$username' (HTTP $response_code)"
            echo "Response body: $(cat "$temp_response")"
            rm -f "$temp_response"
            return 1
            ;;
    esac
    
    rm -f "$temp_response"
}

# Assign multiple project roles to a user in a single request (idempotent)
assign_project_roles() {
    local username="$1"; shift
    local roles=("$@")

    # Join roles with a sentinel to preserve spaces in names
    local joined
    joined=$(printf "%s:::" "${roles[@]}")
    joined="${joined%:::}"

    echo "Assigning project roles to $username for project $PROJECT_KEY: ${roles[*]}"

    # Build JSON payload with roles array (username provided in path)
    local role_payload=$(jq -n \
        --arg roles_str "$joined" \
        '{
            "roles": ( $roles_str | split(":::") )
        }')

    local temp_response=$(mktemp)
    local response_code=$(curl -s --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
        --header "Content-Type: application/json" \
        -X PUT \
        -d "$role_payload" \
        --write-out "%{http_code}" \
        --output "$temp_response" \
        "${JFROG_URL}/access/api/v1/projects/${PROJECT_KEY}/users/${username}")

    case "$response_code" in
        200|201|204)
            echo "✅ Roles assigned to '$username' successfully (HTTP $response_code)"
            ;;
        409)
            echo "⚠️  Roles already assigned to '$username' (HTTP $response_code)"
            ;;
        400)
            if grep -q -i "already.*assign\|role.*exists" "$temp_response"; then
                echo "⚠️  Roles already assigned to '$username' (HTTP $response_code)"
            else
                echo "❌ Failed to assign roles to '$username' (HTTP $response_code)"
                echo "Response body: $(cat "$temp_response")"
                rm -f "$temp_response"
                return 1
            fi
            ;;
        *)
            echo "❌ Failed to assign roles to '$username' (HTTP $response_code)"
            echo "Response body: $(cat "$temp_response")"
            rm -f "$temp_response"
            return 1
            ;;
    esac

    rm -f "$temp_response"
}

echo "ℹ️  Users to be created:"
for user_data in "${BOOKVERSE_USERS[@]}"; do
    IFS='|' read -r username email password role <<< "$user_data"
    mapped=$(map_role_to_project_role "$role")
    if is_platform_owner "$username"; then
        echo "   - $username ($role → $mapped) + Project Admin"
    else
        echo "   - $username ($role → $mapped)"
    fi
done

echo ""
echo "🔧 Ensuring project role 'cicd_pipeline' exists..."

# Global flag set by ensure_cicd_pipeline_role to indicate availability
CICD_PIPELINE_ROLE_AVAILABLE=false

# Idempotently create or update the cicd_pipeline project role with broad permissions
ensure_cicd_pipeline_role() {
    local role_name="cicd_pipeline"
    local tmp=$(mktemp)

    # Best-effort existence check
    local list_code=$(curl -s \
        --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
        --header "Accept: application/json" \
        -w "%{http_code}" -o "$tmp" \
        "${JFROG_URL}/access/api/v1/projects/${PROJECT_KEY}/roles")
    if [[ "$list_code" -ge 200 && "$list_code" -lt 300 ]] && grep -q '"name"\s*:\s*"'"$role_name"'"' "$tmp" 2>/dev/null; then
        echo "✅ Project role '$role_name' already exists"
        CICD_PIPELINE_ROLE_AVAILABLE=true
        rm -f "$tmp"
        return 0
    fi
    rm -f "$tmp"

    echo "🛠️  Creating project role '$role_name' with validated CUSTOM schema"

    # Build validated payload based on working example
    local payload=$(jq -n \
        --arg name "$role_name" \
        --arg desc "Role for QA and testing activities, allowing read access to dev repositories." \
        --arg proj "$PROJECT_KEY" \
        '{
            name: $name,
            description: $desc,
            type: "CUSTOM",
            actions: [
                "ANNOTATE_BUILD",
                "ANNOTATE_RELEASE_BUNDLE",
                "ANNOTATE_REPOSITORY",
                "MANAGE_XRAY_MD_BUILD",
                "MANAGE_XRAY_MD_RELEASE_BUNDLE",
                "MANAGE_XRAY_MD_REPOSITORY",
                "BIND_APPLICATION",
                "CREATE_APPLICATION",
                "CREATE_RELEASE_BUNDLE",
                "DELETE_APPLICATION",
                "DELETE_BUILD",
                "DELETE_OVERWRITE_REPOSITORY",
                "DELETE_RELEASE_BUNDLE",
                "DEPLOY_BUILD",
                "DEPLOY_CACHE_REPOSITORY",
                "PROMOTE_APPLICATION",
                "READ_APPLICATION",
                "READ_BUILD",
                "READ_RELEASE_BUNDLE",
                "READ_REPOSITORY"
            ],
            environments: [
                ($proj + "-DEV"),
                ($proj + "-QA"),
                ($proj + "-STAGING"),
                "PROD",
                "DEV"
            ]
        }')

    local resp=$(mktemp)
    local code=$(curl -s \
        --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
        --header "Content-Type: application/json" \
        --write-out "%{http_code}" -o "$resp" \
        -X POST \
        -d "$payload" \
        "${JFROG_URL}/access/api/v1/projects/${PROJECT_KEY}/roles")
    if [[ "$code" == "409" || "$code" =~ ^20 ]]; then
        echo "✅ Project role '$role_name' ensured (HTTP $code)"
        CICD_PIPELINE_ROLE_AVAILABLE=true
    else
        echo "⚠️  Role creation returned HTTP $code; response: $(cat "$resp")"
    fi
    rm -f "$resp"
}

ensure_cicd_pipeline_role

if [[ "$CICD_PIPELINE_ROLE_AVAILABLE" != true ]]; then
    echo "⚠️  Proceeding without custom role 'cicd_pipeline' (fallback will assign 'Project Admin' to pipeline users)"
fi

echo "🚀 Processing ${#BOOKVERSE_USERS[@]} users..."

# Process each user
for user_data in "${BOOKVERSE_USERS[@]}"; do
    IFS='|' read -r username email password role <<< "$user_data"

    echo ""
    echo "Processing user: $username ($role)"

    # Create user
    create_user "$username" "$email" "$password" "$role"

    # Determine project roles for this user (avoid duplicates in bash 3)
    project_roles=("$(map_role_to_project_role "$role")")
    if is_platform_owner "$username"; then
        needs_admin=true
        for r in "${project_roles[@]}"; do
            if [[ "$r" == "Project Admin" ]]; then
                needs_admin=false
                break
            fi
        done
        if [[ "$needs_admin" == true ]]; then
            project_roles+=("Project Admin")
        fi
    fi

    # Ensure all pipeline users receive the right role membership
    if is_pipeline_user "$username"; then
        # Remove Developer role for pipeline users (not needed)
        cleaned_roles=()
        for r in "${project_roles[@]}"; do
            if [[ "$r" != "Developer" && -n "$r" ]]; then
                cleaned_roles+=("$r")
            fi
        done
        project_roles=("${cleaned_roles[@]}")

        if [[ "$CICD_PIPELINE_ROLE_AVAILABLE" == true ]]; then
            already=false
            for r in "${project_roles[@]}"; do
                if [[ "$r" == "cicd_pipeline" ]]; then already=true; break; fi
            done
            if [[ "$already" == false ]]; then
                project_roles+=("cicd_pipeline")
            fi
        else
            # Fallback to Project Admin to unblock CI while custom role is unavailable
            has_admin=false
            for r in "${project_roles[@]}"; do
                if [[ "$r" == "Project Admin" ]]; then has_admin=true; break; fi
            done
            if [[ "$has_admin" == false ]]; then
                project_roles+=("Project Admin")
            fi
        fi
    fi

    # Assign roles as project membership
    assign_project_roles "$username" "${project_roles[@]}"
done

echo ""
echo "✅ User creation completed successfully!"
echo ""