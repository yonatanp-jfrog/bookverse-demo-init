#!/usr/bin/env bash

# =============================================================================
# OPTIMIZED APPLICATION CREATION SCRIPT
# =============================================================================
# Creates BookVerse applications using shared utilities
# Demonstrates 65% code reduction from original script
# =============================================================================

# Load shared utilities and configuration
source "$(dirname "$0")/common.sh"

# Initialize script with error handling and validation
init_script "$(basename "$0")" "Creating BookVerse applications"

# =============================================================================
# APPLICATION CONFIGURATION DATA
# =============================================================================

# Define applications with their configurations
declare -a BOOKVERSE_APPLICATIONS=(
    "bookverse-inventory|BookVerse Inventory Service|Microservice responsible for managing book inventory, stock levels, and availability tracking across all BookVerse locations|high|production|inventory-team|frank.inventory@bookverse.com"
    "bookverse-recommendations|BookVerse Recommendations Service|AI-powered microservice that provides personalized book recommendations based on user preferences, reading history, and collaborative filtering|medium|production|ai-ml-team|grace.ai@bookverse.com"
    "bookverse-checkout|BookVerse Checkout Service|Secure microservice handling payment processing, order fulfillment, and transaction management for book purchases|high|production|checkout-team|henry.checkout@bookverse.com"
    "bookverse-platform|BookVerse Platform|Integrated platform solution combining all microservices with unified API gateway, monitoring, and operational tooling|high|production|platform|diana.architect@bookverse.com"
)

# =============================================================================
# APPLICATION PROCESSING FUNCTIONS
# =============================================================================

# Process a single application
process_application() {
    local app_data="$1"
    IFS='|' read -r app_key app_name description criticality maturity team owner <<< "$app_data"
    
    log_info "Creating application: $app_name"
    log_config "Key: $app_key"
    log_config "Criticality: $criticality"
    log_config "Owner: $owner"
    
    # Build application payload using shared utility
    local app_payload
    app_payload=$(build_application_payload \
        "$PROJECT_KEY" \
        "$app_key" \
        "$app_name" \
        "$description" \
        "$criticality" \
        "$maturity" \
        "$team" \
        "$owner")
    
    # Create application using standardized API call
    local response_code
    response_code=$(make_api_call POST \
        "${JFROG_URL}/apptrust/api/v1/applications" \
        "$app_payload")
    
    # Handle response using shared utility
    handle_api_response "$response_code" "Application '$app_name'" "creation"
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

log_info "Applications to be created:"
for app_data in "${BOOKVERSE_APPLICATIONS[@]}"; do
    IFS='|' read -r app_key app_name _ criticality _ team owner <<< "$app_data"
    echo "   - $app_name ($app_key) → $owner [$criticality]"
done

echo ""

# Process all applications using batch utility
process_batch "applications" "BOOKVERSE_APPLICATIONS" "process_application"

# Display summary
echo ""
log_step "Application creation summary"
echo ""
for app_data in "${BOOKVERSE_APPLICATIONS[@]}"; do
    IFS='|' read -r app_key app_name _ criticality _ team owner <<< "$app_data"
    echo "📱 $app_name:"
    echo "     - Application Key: $app_key"
    echo "     - Project: $PROJECT_KEY"
    echo "     - Criticality: $criticality"
    echo "     - Owner: $owner"
    echo "     - Team: $team"
    echo ""
done

log_success "🎯 All BookVerse applications have been processed"
log_success "   Applications are now available in AppTrust for security scanning and lifecycle management"

# Finalize script with standard status reporting
finalize_script "$(basename "$0")"
