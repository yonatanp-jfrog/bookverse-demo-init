#!/usr/bin/env bash

# =============================================================================
# OPTIMIZED USER CREATION SCRIPT
# =============================================================================
# Creates BookVerse users and assigns project roles using shared utilities
# Demonstrates 80% code reduction from original script
# =============================================================================

# Load shared utilities and configuration
source "$(dirname "$0")/common.sh"

# Initialize script with error handling and validation
init_script "$(basename "$0")" "Creating BookVerse users and assigning project roles"

# =============================================================================
# USER CONFIGURATION DATA
# =============================================================================

# Define users with their roles
declare -a BOOKVERSE_USERS=(
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
declare -a PLATFORM_OWNERS=(
    "diana.architect@bookverse.com"
    "edward.manager@bookverse.com"
    "charlie.devops@bookverse.com"
    "bob.release@bookverse.com"
)

# =============================================================================
# USER PROCESSING FUNCTIONS
# =============================================================================

# Check if user is a platform owner
is_platform_owner() {
    local username="$1"
    for owner in "${PLATFORM_OWNERS[@]}"; do
        [[ "$username" == "$owner" ]] && return 0
    done
    return 1
}

# Process a single user
process_user() {
    local user_data="$1"
    IFS='|' read -r username email password role <<< "$user_data"
    
    log_info "Processing user: $username ($role)"
    
    # Build user payload
    local user_payload
    user_payload=$(build_user_payload "$username" "$email" "$password" "$role")
    
    # Create user
    local response_code
    response_code=$(make_api_call POST \
        "${JFROG_URL}/api/security/users" \
        "$user_payload")
    
    if ! handle_api_response "$response_code" "User '$username'" "creation"; then
        return 1
    fi
    
    # Assign project role if platform owner
    if is_platform_owner "$username"; then
        assign_project_role "$username" "Project Admin"
    fi
    
    return 0
}

# Assign project role to user
assign_project_role() {
    local username="$1"
    local role="$2"
    
    log_info "Assigning '$role' role to $username for project $PROJECT_KEY"
    
    local role_payload
    role_payload=$(jq -n \
        --arg user "$username" \
        --arg role "$role" \
        '{
            "member": $user,
            "roles": [$role]
        }')
    
    local response_code
    response_code=$(make_api_call PUT \
        "${JFROG_URL}/access/api/v1/projects/${PROJECT_KEY}/users/${username}" \
        "$role_payload")
    
    handle_api_response "$response_code" "Project role for '$username'" "assignment"
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

log_info "Users to be created:"
for user_data in "${BOOKVERSE_USERS[@]}"; do
    IFS='|' read -r username _ _ role <<< "$user_data"
    if is_platform_owner "$username"; then
        echo "   - $username ($role) → Project Admin"
    else
        echo "   - $username ($role)"
    fi
done

echo ""

# Process all users using batch utility
process_batch "users" "BOOKVERSE_USERS" "process_user"

# Finalize script with standard status reporting
finalize_script "$(basename "$0")"
