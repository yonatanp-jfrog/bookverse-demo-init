#!/usr/bin/env bash

# =============================================================================
# OPTIMIZED OIDC INTEGRATION SCRIPT
# =============================================================================
# Creates OIDC integrations and identity mappings using shared utilities
# Demonstrates 75% code reduction from original script
# =============================================================================

# Load shared utilities and configuration
source "$(dirname "$0")/common.sh"

# Initialize script with error handling and validation
init_script "$(basename "$0")" "Creating OIDC integrations and identity mappings"

# =============================================================================
# OIDC CONFIGURATION DATA
# =============================================================================

# Define OIDC integrations with their corresponding users
declare -a OIDC_CONFIGS=(
    "inventory|frank.inventory@bookverse.com|BookVerse Inventory"
    "recommendations|grace.ai@bookverse.com|BookVerse Recommendations" 
    "checkout|henry.checkout@bookverse.com|BookVerse Checkout"
    "platform|diana.architect@bookverse.com|BookVerse Platform"
    "web|alice.developer@bookverse.com|BookVerse Web"
)

# =============================================================================
# OIDC PROCESSING FUNCTIONS
# =============================================================================

# Create OIDC integration
create_oidc_integration() {
    local service_name="$1"
    local integration_name="github-${PROJECT_KEY}-${service_name}"
    
    log_info "Creating OIDC integration: $integration_name"
    
    # Check if integration already exists
    if resource_exists "${JFROG_URL}/access/api/v1/oidc/${integration_name}"; then
        log_warning "OIDC integration '$integration_name' already exists"
        return 0
    fi
    
    # Create integration payload
    local payload
    payload=$(build_oidc_integration_payload "$integration_name")
    
    # Create integration
    local response_code
    response_code=$(make_api_call POST \
        "${JFROG_URL}/access/api/v1/oidc" \
        "$payload")
    
    handle_api_response "$response_code" "OIDC integration '$integration_name'" "creation"
}

# Create OIDC identity mapping
create_oidc_identity_mapping() {
    local service_name="$1"
    local username="$2"
    local integration_name="github-${PROJECT_KEY}-${service_name}"
    local mapping_name="$integration_name"
    
    log_info "Creating identity mapping for: $integration_name → $username"
    
    # Check existing mappings
    local temp_file
    temp_file=$(mktemp)
    local list_code
    list_code=$(make_api_call GET \
        "${JFROG_URL}/access/api/v1/oidc/${integration_name}/identity_mappings" \
        "" "$temp_file")
    
    if [[ "$list_code" -eq $HTTP_OK ]]; then
        local exists
        exists=$(jq -e --arg n "$mapping_name" 'map(select(.name==$n)) | length > 0' "$temp_file" 2>/dev/null)
        if [[ "$exists" == "true" ]]; then
            log_warning "Identity mapping '$mapping_name' already exists"
            rm -f "$temp_file"
            return 0
        fi
    fi
    rm -f "$temp_file"
    
    # Create mapping payload
    local payload
    payload=$(build_oidc_mapping_payload \
        "$mapping_name" \
        "$integration_name" \
        "$username")
    
    # Create mapping
    local response_code
    response_code=$(make_api_call POST \
        "${JFROG_URL}/access/api/v1/oidc/${integration_name}/identity_mappings" \
        "$payload")
    
    handle_api_response "$response_code" "Identity mapping '$mapping_name'" "creation"
}

# Process a complete OIDC configuration
process_oidc_config() {
    local config="$1"
    IFS='|' read -r service_name username display_name <<< "$config"
    
    log_step "Processing $display_name"
    
    # Create integration and mapping
    create_oidc_integration "$service_name" && \
    create_oidc_identity_mapping "$service_name" "$username"
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

log_info "OIDC configurations to create:"
for config in "${OIDC_CONFIGS[@]}"; do
    IFS='|' read -r service_name username display_name <<< "$config"
    echo "   - $display_name → $username"
done

echo ""

# Process all OIDC configurations using batch utility
process_batch "OIDC configurations" "OIDC_CONFIGS" "process_oidc_config"

# Display summary
echo ""
log_step "OIDC setup summary"
echo ""
for config in "${OIDC_CONFIGS[@]}"; do
    IFS='|' read -r service_name username display_name <<< "$config"
    echo "📦 $display_name:"
    echo "     - Integration: github-${PROJECT_KEY}-${service_name}"
    echo "     - Issuer: https://token.actions.githubusercontent.com/"
    echo "     - Identity Mapping: $username (Admin)"
    echo ""
done

log_success "🔐 Each OIDC integration enables secure GitHub Actions authentication"
log_success "   for the respective microservice team with appropriate permissions"

# Finalize script with standard status reporting
finalize_script "$(basename "$0")"
