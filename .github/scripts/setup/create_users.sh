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
    "pipeline.platform@bookverse.com|pipeline.platform@bookverse.com|Pipeline2024!|Pipeline User"
)

# Platform owners get Project Admin privileges
PLATFORM_OWNERS=(
    "diana.architect@bookverse.com"
    "edward.manager@bookverse.com"
    "charlie.devops@bookverse.com"
    "bob.release@bookverse.com"
)

# Function to check if user is a platform owner
is_platform_owner() {
    local username="$1"
    for owner in "${PLATFORM_OWNERS[@]}"; do
        [[ "$username" == "$owner" ]] && return 0
    done
    return 1
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

# Function to assign project role
assign_project_role() {
    local username="$1"
    local role_name="$2"
    
    echo "Assigning '$role_name' role to $username for project $PROJECT_KEY"
    
    # Build role assignment payload
    local role_payload=$(jq -n \
        --arg user "$username" \
        --arg role "$role_name" \
        '{
            "member": $user,
            "roles": [$role]
        }')
    
    # Assign role
    local temp_response=$(mktemp)
    local response_code=$(curl -s --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
        --header "Content-Type: application/json" \
        -X PUT \
        -d "$role_payload" \
        --write-out "%{http_code}" \
        --output "$temp_response" \
        "${JFROG_URL}/access/api/v1/projects/${PROJECT_KEY}/users/${username}")
    
    case "$response_code" in
        200|201)
            echo "✅ Role '$role_name' assigned to '$username' successfully (HTTP $response_code)"
            ;;
        409)
            echo "⚠️  Role '$role_name' already assigned to '$username' (HTTP $response_code)"
            ;;
        400)
            # Check if it's the "already assigned" error
            if grep -q -i "already.*assign\|role.*exists" "$temp_response"; then
                echo "⚠️  Role '$role_name' already assigned to '$username' (HTTP $response_code)"
            else
                echo "❌ Failed to assign role '$role_name' to '$username' (HTTP $response_code)"
                echo "Response body: $(cat "$temp_response")"
                rm -f "$temp_response"
                return 1
            fi
            ;;
        *)
            echo "❌ Failed to assign role '$role_name' to '$username' (HTTP $response_code)"
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
    if is_platform_owner "$username"; then
        echo "   - $username ($role) → Project Admin"
    else
        echo "   - $username ($role)"
    fi
done

echo ""
echo "🚀 Processing ${#BOOKVERSE_USERS[@]} users..."

# Process each user
for user_data in "${BOOKVERSE_USERS[@]}"; do
    IFS='|' read -r username email password role <<< "$user_data"
    
    echo ""
    echo "Processing user: $username ($role)"
    
    # Create user
    create_user "$username" "$email" "$password" "$role"
    
    # Assign project role if platform owner
    if is_platform_owner "$username"; then
        assign_project_role "$username" "Project Admin"
    fi
done

echo ""
echo "✅ User creation completed successfully!"
echo ""