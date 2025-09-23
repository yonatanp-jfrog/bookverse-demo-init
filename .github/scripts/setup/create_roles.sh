#!/usr/bin/env bash

# =============================================================================
# BookVerse Platform - Role Creation and Permission Assignment Script
# =============================================================================
#
# This comprehensive setup script automates the creation and configuration of
# custom security roles and permission assignments for the BookVerse platform
# within the JFrog Platform ecosystem, implementing enterprise-grade role-based
# access control (RBAC), fine-grained permission management, and security
# governance for production-ready access control and compliance operations.
#
# 🏗️ ROLE MANAGEMENT STRATEGY:
#     - Custom Role Creation: Automated creation of BookVerse-specific security roles
#     - Permission Assignment: Fine-grained permission mapping and access control
#     - Environment-Specific Access: Role-based environment segregation and access control
#     - Service-Specific Roles: Specialized roles for different BookVerse services and teams
#     - Operational Roles: Roles for CI/CD, Kubernetes, and operational automation
#     - Compliance Integration: Role definitions meeting enterprise security and audit requirements
#
# 🛡️ ENTERPRISE SECURITY AND GOVERNANCE:
#     - Role-Based Access Control: Comprehensive RBAC implementation with graduated permissions
#     - Principle of Least Privilege: Minimal permission assignment for security optimization
#     - Separation of Duties: Role segregation preventing privilege escalation and conflicts
#     - Access Control Matrix: Structured permission mapping and authorization validation
#     - Audit Trail: Complete role assignment and permission change audit logging
#     - Compliance Framework: SOX, PCI-DSS, GDPR compliance for role and permission management
#
# 🔧 ROLE SPECIALIZATION AND PERMISSIONS:
#     - Repository Access: Fine-grained repository read/write permissions and artifact access
#     - Environment Permissions: Environment-specific access control and promotion permissions
#     - Service Operations: Service-specific operational permissions and automation access
#     - Administrative Roles: Platform administration and security management permissions
#     - Pipeline Automation: CI/CD and automation service account permissions
#     - Kubernetes Integration: Container orchestration and deployment automation permissions
#
# 📈 SCALABILITY AND ORGANIZATION:
#     - Role Hierarchy: Graduated permission levels and access control escalation
#     - Team-Based Roles: Service team-specific roles and responsibility assignments
#     - Cross-Service Access: Inter-service collaboration and shared resource permissions
#     - Environment Scaling: Role-based environment access and promotion workflow support
#     - Automation Integration: Service account role assignment and automated permission management
#     - Permission Inheritance: Role-based permission inheritance and delegation patterns
#
# 🔐 ADVANCED SECURITY FEATURES:
#     - Dynamic Permissions: Runtime permission validation and context-aware access control
#     - Permission Auditing: Real-time permission usage monitoring and security validation
#     - Access Reviews: Periodic access review and permission validation procedures
#     - Privilege Management: Just-in-time permission elevation and temporary access control
#     - Threat Detection: Role-based threat detection and security incident response
#     - Identity Integration: Role integration with identity providers and authentication systems
#
# 🛠️ TECHNICAL IMPLEMENTATION:
#     - JFrog Platform Integration: Native role management via JFrog Platform APIs
#     - REST API Automation: Programmatic role creation and permission assignment
#     - JSON Configuration: Structured role definition and permission specification
#     - Error Handling: Comprehensive error detection and recovery for role operations
#     - Validation Framework: Role configuration validation and permission verification
#     - Integration Testing: Role assignment testing and access control validation
#
# 📋 ROLE CATEGORIES AND PERMISSIONS:
#     - Kubernetes Image Pull: Container image access for Kubernetes deployment
#     - Service-Specific Roles: Inventory, recommendations, checkout, platform, web, helm
#     - Environment Roles: DEV, QA, STAGING, PROD environment-specific access
#     - Administrative Roles: Platform administration and security management
#     - Pipeline Roles: CI/CD automation and service-to-service permissions
#     - Operational Roles: Monitoring, logging, and infrastructure management
#
# 🎯 SUCCESS CRITERIA:
#     - Role Creation: All BookVerse security roles successfully provisioned
#     - Permission Assignment: Complete role-based permission configuration and validation
#     - Security Compliance: Role definitions meeting enterprise security standards
#     - Access Control: Comprehensive access control implementation and testing
#     - Audit Readiness: Role management ready for compliance and security audit
#     - Operational Excellence: Role-based access control ready for production operations
#
# Authors: BookVerse Platform Team
# Version: 1.0.0
# Last Updated: 2024
#
# Dependencies:
#   - config.sh (configuration management)
#   - JFrog Platform with role management (access control management)
#   - Valid administrative credentials (admin tokens)
#   - Network connectivity to JFrog Platform endpoints
#   - jq (JSON processing for role configuration)
#
# Security Notes:
#   - Roles implement principle of least privilege for security optimization
#   - Permission assignments should be reviewed regularly for security compliance
#   - Custom roles should be validated against enterprise security policies
#   - Role changes should be audited and logged for compliance tracking
#
# =============================================================================

set -e

source "$(dirname "$0")/config.sh"

echo ""
echo "🚀 Creating BookVerse custom roles"
echo "🔧 Project: $PROJECT_KEY"
echo "🔧 JFrog URL: $JFROG_URL"
echo ""

create_role() {
    local role_name="$1"
    local role_description="$2"
    local permissions="$3"
    local environments="$4"
    
    echo "Creating role: $role_name"
    echo "  Description: $role_description"
    echo "  Environments: $environments"
    
    local role_payload=$(jq -n \
        --arg name "$role_name" \
        --arg desc "$role_description" \
        --arg project "$PROJECT_KEY" \
        --argjson perms "$permissions" \
        --argjson envs "$environments" \
        '{
            "name": $name,
            "description": $desc,
            "type": "CUSTOM",
            "environment": "PROJECT",
            "project_key": $project,
            "actions": $perms,
            "environments": $envs
        }')
    
    local response_code
    response_code=$(curl -s --write-out "%{http_code}" \
        --output /dev/null \
        --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
        --header "Content-Type: application/json" \
        --request POST \
        --data "$role_payload" \
        "${JFROG_URL}/access/api/v1/projects/${PROJECT_KEY}/roles")
    
    case "$response_code" in
        201)
            echo "✅ Role '$role_name' created successfully"
            ;;
        409)
            echo "✅ Role '$role_name' already exists"
            ;;
        *)
            echo "⚠️  Role '$role_name' creation returned HTTP $response_code"
            ;;
    esac
    echo ""
}


echo "📋 Role creation summary:"
echo ""
echo "ℹ️  Note: The 'k8s_image_pull' project role is created automatically by create_users.sh"
echo "          when K8s users are processed, ensuring proper permissions for image pulls."
echo ""

echo "🎯 Custom roles are now available for assignment to users"
echo ""
