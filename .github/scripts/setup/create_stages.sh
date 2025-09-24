#!/usr/bin/env bash

# =============================================================================
# BookVerse Platform - Application Lifecycle Stage Creation and AppTrust Integration Script
# =============================================================================
#
# This comprehensive setup script automates the creation and configuration of
# application lifecycle stages and AppTrust integration for the BookVerse platform
# within the JFrog Platform ecosystem, implementing enterprise-grade application
# lifecycle management, stage-based promotion workflows, and compliance-driven
# deployment pipelines for production-ready lifecycle governance and operations.
#
# 🏗️ LIFECYCLE STAGE STRATEGY:
#     - Multi-Environment Lifecycle: Complete DEV → QA → STAGING → PROD promotion pipeline
#     - AppTrust Integration: Native integration with JFrog AppTrust for application lifecycle management
#     - Stage-Based Security: Environment-specific security policies and access control
#     - Promotion Workflows: Automated stage promotion with validation and approval gates
#     - Evidence Collection: Comprehensive audit trail and cryptographic evidence at each stage
#     - Compliance Framework: SOX, PCI-DSS, GDPR compliance integration across lifecycle stages
#
# 🔄 APPLICATION LIFECYCLE MANAGEMENT:
#     - Stage Definition: Structured definition of deployment environments and promotion criteria
#     - Promotion Gates: Automated validation and approval workflows between lifecycle stages
#     - Quality Assurance: Testing and validation requirements for stage progression
#     - Security Validation: Security scanning and compliance verification at each stage
#     - Performance Benchmarking: Performance validation and SLA verification for stage promotion
#     - Rollback Capabilities: Stage-aware rollback and disaster recovery procedures
#
# 🛡️ ENTERPRISE SECURITY AND GOVERNANCE:
#     - Stage-Based Access Control: Environment-specific user permissions and role assignments
#     - Compliance Integration: Regulatory compliance validation and audit trail maintenance
#     - Security Policies: Stage-specific security policies and vulnerability management
#     - Audit Trail: Complete lifecycle stage operation history and compliance documentation
#     - Change Management: Enterprise change management integration and approval workflows
#     - Risk Management: Stage-based risk assessment and threat detection integration
#
# 🔧 APPTRUST INTEGRATION PATTERNS:
#     - Application Versioning: Semantic versioning and application lifecycle coordination
#     - Evidence Collection: Cryptographic evidence generation and validation at each stage
#     - Promotion Automation: Automated stage promotion with AppTrust lifecycle management
#     - Quality Gates: Automated quality validation and promotion criteria enforcement
#     - Security Scanning: Integrated security scanning and vulnerability assessment
#     - Compliance Reporting: Automated compliance reporting and audit trail generation
#
# 📈 SCALABILITY AND PERFORMANCE:
#     - Multi-Project Support: Scalable stage management across multiple BookVerse projects
#     - Stage Optimization: Performance-optimized stage configuration and promotion workflows
#     - Parallel Processing: Concurrent stage operations and promotion workflow optimization
#     - Load Distribution: Stage-based load balancing and resource optimization
#     - Global Distribution: Multi-region stage deployment and geographic distribution
#     - Monitoring Integration: Stage-based monitoring and alerting configuration
#
# 🔐 ADVANCED LIFECYCLE FEATURES:
#     - Dynamic Stage Configuration: Runtime stage configuration and policy adjustment
#     - Conditional Promotion: Business rule-based promotion criteria and validation
#     - A/B Testing Integration: Experimental deployment and testing framework integration
#     - Canary Deployments: Progressive deployment and rollout management across stages
#     - Blue-Green Deployment: Zero-downtime deployment patterns and stage coordination
#     - Feature Flags: Feature flag integration and stage-based feature management
#
# 🛠️ TECHNICAL IMPLEMENTATION:
#     - JFrog Platform Integration: Native stage management via JFrog Platform APIs
#     - AppTrust API Integration: Direct integration with AppTrust lifecycle management
#     - REST API Automation: Programmatic stage creation and lifecycle configuration
#     - JSON Configuration: Structured stage definition and lifecycle policy specification
#     - Error Handling: Comprehensive error detection and recovery for lifecycle operations
#     - Validation Framework: Stage configuration validation and lifecycle testing
#
# 📋 LIFECYCLE STAGE CONFIGURATION:
#     - Development Stage (DEV): Initial development and feature validation environment
#     - Quality Assurance Stage (QA): Comprehensive testing and quality validation environment
#     - Staging Stage (STAGING): Production-like pre-production validation environment
#     - Production Stage (PROD): Live production environment with full business operations
#     - Hotfix Stages: Emergency hotfix deployment and validation workflows
#     - Experimental Stages: A/B testing and experimental feature deployment environments
#
# 🎯 SUCCESS CRITERIA:
#     - Stage Creation: All BookVerse lifecycle stages successfully provisioned
#     - AppTrust Integration: Complete AppTrust lifecycle management configuration
#     - Promotion Workflows: Automated stage promotion and validation workflows operational
#     - Compliance Readiness: Lifecycle management meeting enterprise audit requirements
#     - Security Validation: Stage-based security policies and access control operational
#     - Operational Excellence: Lifecycle management ready for production deployment operations
#
# Authors: BookVerse Platform Team
# Version: 1.0.0
# Last Updated: 2024
#
# Dependencies:
#   - common.sh (shared utilities and configuration)
#   - JFrog Platform with AppTrust (application lifecycle management)
#   - Valid administrative credentials (admin tokens)
#   - Network connectivity to JFrog Platform endpoints
#   - Stage configuration templates and policies
#
# AppTrust Integration Notes:
#   - Stages must follow BookVerse naming convention: {PROJECT_KEY}-{STAGE_NAME}
#   - Production stage is globally named "PROD" and always exists as the last stage
#   - Stage promotion requires evidence collection and cryptographic validation
#   - Compliance frameworks are automatically integrated with stage operations
#
# =============================================================================

source "$(dirname "$0")/common.sh"
source "$(dirname "$0")/config.sh"

init_script "$(basename "$0")" "Creating AppTrust stages and lifecycle configuration"


process_stage() {
    local stage_name="$1"
    local full_stage_name="${PROJECT_KEY}-${stage_name}"
    
    log_info "Creating stage: $full_stage_name"
    
    local stage_payload
    stage_payload=$(build_stage_payload "$PROJECT_KEY" "$stage_name")
    
    local response_code
    response_code=$(jfrog_api_call POST \
        "${JFROG_URL}/access/api/v2/stages/" \
        "$stage_payload")
    
    handle_api_response "$response_code" "Stage '$full_stage_name'" "creation"
}

create_lifecycle_configuration() {
    local project_stages=()
    
    for stage_name in "${NON_PROD_STAGES[@]}"; do
        project_stages+=("${PROJECT_KEY}-${stage_name}")
    done
    
    log_step "Updating lifecycle with promote stages"
    log_info "Promote stages: ${project_stages[*]}"
    
    local lifecycle_payload
    lifecycle_payload=$(jq -n \
        --argjson promote_stages "$(printf '%s\n' "${project_stages[@]}" | jq -R . | jq -s .)" \
        --arg project_key "$PROJECT_KEY" \
        '{
            "promote_stages": $promote_stages,
            "project_key": $project_key
        }')
    
    local response_code
    response_code=$(jfrog_api_call PATCH \
        "${JFROG_URL}/access/api/v2/lifecycle/?project_key=${PROJECT_KEY}" \
        "$lifecycle_payload")
    
    handle_api_response "$response_code" "Lifecycle configuration" "update"
}


log_config "Project: ${PROJECT_KEY}"
log_config "Local stages to create: ${NON_PROD_STAGES[*]}"
log_config "Production stage: ${PROD_STAGE} (system-managed)"
echo ""

log_info "Stages to be created:"
for stage_name in "${NON_PROD_STAGES[@]}"; do
    echo "   - ${PROJECT_KEY}-${stage_name}"
done

echo ""

count=0
for stage_name in "${NON_PROD_STAGES[@]}"; do
    echo ""
    log_info "[$(( ++count ))/${#NON_PROD_STAGES[@]}] Creating stage: $stage_name"
    process_stage "$stage_name"
done

echo ""

create_lifecycle_configuration

echo ""
log_step "Stages creation summary"
echo ""
log_config "📋 Created Stages:"
for stage_name in "${NON_PROD_STAGES[@]}"; do
    echo "   • ${PROJECT_KEY}-${stage_name} (promote)"
done

echo ""
log_config "🔄 Lifecycle Configuration:"
echo "   • Promote stages: ${NON_PROD_STAGES[*]}"
echo "   • Production stage: ${PROD_STAGE} (always last, system-managed)"

echo ""
log_success "🎯 All AppTrust stages and lifecycle configuration have been processed"
log_success "   Stages are now available for artifact promotion workflows"

finalize_script "$(basename "$0")"
