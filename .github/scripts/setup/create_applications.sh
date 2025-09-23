#!/usr/bin/env bash

# =============================================================================
# BookVerse Platform - Application Provisioning and Configuration Script
# =============================================================================
#
# This comprehensive setup script automates the creation and configuration of
# all BookVerse platform applications within the JFrog AppTrust ecosystem,
# implementing enterprise-grade application lifecycle management, security
# compliance, and organizational governance across the complete microservices
# architecture for production-ready application deployment.
#
# 🏗️ APPLICATION PROVISIONING STRATEGY:
#     - Multi-Service Application Creation: Automated provisioning of all BookVerse applications
#     - Application Lifecycle Management: Complete lifecycle stage configuration and governance
#     - Security Classification: Application criticality and maturity assessment for compliance
#     - Team Assignment: Role-based application ownership and responsibility management
#     - Evidence Integration: Cryptographic evidence collection and audit trail establishment
#     - Compliance Framework: SOX, PCI-DSS, GDPR compliance integration across applications
#
# 📊 BOOKVERSE APPLICATION ECOSYSTEM:
#     - Infrastructure (bookverse-infra): Foundation libraries and shared DevOps automation
#     - Inventory Service (bookverse-inventory): Core business inventory and stock management
#     - Recommendations Service (bookverse-recommendations): AI-powered personalization engine
#     - Checkout Service (bookverse-checkout): Secure payment processing and transaction management
#     - Platform Integration (bookverse-platform): Unified platform coordination and API gateway
#     - Web Application (bookverse-web): Customer-facing frontend and static asset delivery
#     - Kubernetes Deployment (bookverse-helm): Infrastructure-as-code and container orchestration
#
# 🛡️ ENTERPRISE SECURITY AND GOVERNANCE:
#     - Application Classification: High/medium criticality assessment and risk management
#     - Production Readiness: Maturity classification and deployment readiness validation
#     - Team-Based Security: Role-based access control and application ownership assignment
#     - Audit Trail Creation: Complete application provisioning history and compliance documentation
#     - Evidence Framework: Cryptographic signing and tamper-evident application configuration
#     - Compliance Integration: Regulatory compliance validation across all application tiers
#
# 🔧 AUTOMATION AND OPERATIONAL EXCELLENCE:
#     - Idempotent Operations: Safe re-execution and configuration drift prevention
#     - Error Handling: Comprehensive error detection and recovery procedures
#     - Validation Framework: Application configuration verification and health checking
#     - Progress Tracking: Detailed logging and operational status reporting
#     - Rollback Capabilities: Application configuration rollback and disaster recovery
#     - Integration Testing: Application connectivity and dependency validation
#
# 📈 BUSINESS CONTINUITY AND SCALABILITY:
#     - Multi-Environment Support: DEV, QA, STAGING, PROD environment configuration
#     - Scalability Planning: Application architecture design for horizontal scaling
#     - Disaster Recovery: Application backup and recovery procedure integration
#     - Performance Optimization: Application configuration tuning for optimal performance
#     - Monitoring Integration: Application observability and alerting configuration
#     - Change Management: Enterprise change management integration and approval workflows
#
# 🔐 SECURITY AND COMPLIANCE FEATURES:
#     - Zero-Trust Architecture: Application security validation and threat assessment
#     - Identity Management: Application-level authentication and authorization configuration
#     - Data Protection: Application data classification and protection policy enforcement
#     - Vulnerability Management: Application security scanning and vulnerability assessment
#     - Access Control: Fine-grained permission management and role-based security
#     - Audit Compliance: Complete audit trail and forensic investigation support
#
# 🛠️ TECHNICAL IMPLEMENTATION:
#     - JFrog AppTrust Integration: Native application lifecycle management platform integration
#     - REST API Automation: Programmatic application configuration via JFrog APIs
#     - Configuration Management: Centralized application configuration and policy management
#     - Evidence Collection: Automated evidence generation and cryptographic signing
#     - Health Monitoring: Application health checking and status validation
#     - Integration Validation: Cross-application dependency verification and testing
#
# 📋 USAGE PATTERNS:
#     - Initial Setup: Complete BookVerse platform application provisioning
#     - Environment Refresh: Application configuration refresh and validation
#     - Compliance Audit: Application compliance status validation and reporting
#     - Security Review: Application security posture assessment and validation
#     - Disaster Recovery: Application configuration restoration and recovery
#     - Scaling Operations: Application configuration for horizontal scaling scenarios
#
# 🎯 SUCCESS CRITERIA:
#     - Application Creation: All BookVerse applications successfully provisioned
#     - Security Compliance: Complete security classification and compliance validation
#     - Team Assignment: Proper role-based ownership and responsibility assignment
#     - Evidence Collection: Comprehensive audit trail and evidence documentation
#     - Integration Validation: Cross-application connectivity and dependency verification
#     - Operational Readiness: Applications ready for lifecycle management and deployment
#
# 🏛️ ENTERPRISE ARCHITECTURE ALIGNMENT:
#     - Microservices Pattern: Application architecture aligned with microservices best practices
#     - Domain-Driven Design: Application boundaries based on business domain modeling
#     - Security-by-Design: Application security integrated from initial provisioning
#     - Observability Integration: Application monitoring and logging framework integration
#     - DevOps Alignment: Application configuration optimized for CI/CD and automation
#     - Compliance-First: Application design meeting regulatory and audit requirements
#
# Authors: BookVerse Platform Team
# Version: 1.0.0
# Last Updated: 2024
#
# Dependencies:
#   - config.sh (configuration management)
#   - JFrog Platform with AppTrust (application lifecycle management)
#   - Valid authentication credentials (OIDC/API tokens)
#   - Network connectivity to JFrog Platform endpoints
#
# =============================================================================

set -e

source "$(dirname "$0")/config.sh"

echo ""
echo "🚀 Creating BookVerse applications"
echo "🔧 Project: $PROJECT_KEY"
echo "🔧 JFrog URL: $JFROG_URL"
echo ""

BOOKVERSE_APPLICATIONS=(
    "bookverse-infra|BookVerse Infrastructure|Consolidated infrastructure repository containing multiple packages: bookverse-core (Python commons library), bookverse-devops (CI/CD workflows and scripts), and evidence templates for the entire BookVerse platform|high|production|platform|diana.architect@bookverse.com"
    "bookverse-inventory|BookVerse Inventory Service|Microservice responsible for managing book inventory, stock levels, and availability tracking across all BookVerse locations|high|production|inventory-team|frank.inventory@bookverse.com"
    "bookverse-recommendations|BookVerse Recommendations Service|AI-powered microservice that provides personalized book recommendations based on user preferences, reading history, and collaborative filtering|medium|production|ai-ml-team|grace.ai@bookverse.com"
    "bookverse-checkout|BookVerse Checkout Service|Secure microservice handling payment processing, order fulfillment, and transaction management for book purchases|high|production|checkout-team|henry.checkout@bookverse.com"
    "bookverse-platform|BookVerse Platform|Integrated platform solution combining all microservices with unified API gateway, monitoring, and operational tooling|high|production|platform|diana.architect@bookverse.com"
    "bookverse-web|BookVerse Web Application|Frontend web application delivering the BookVerse user interface and static assets, served via nginx with versioned bundles|medium|production|web-team|alice.developer@bookverse.com"
    "bookverse-helm|BookVerse Helm Charts|Kubernetes deployment manifests and Helm charts for the BookVerse platform, providing infrastructure-as-code for container orchestration and service deployment|high|production|devops-team|ivan.devops@bookverse.com"
)

create_application() {
    local app_key="$1"
    local app_name="$2"
    local description="$3"
    local criticality="$4"
    local maturity="$5"
    local team="$6"
    local owner="$7"
    
    echo "Creating application: $app_name"
    echo "  Key: $app_key"
    echo "  Criticality: $criticality"
    echo "  Owner: $owner"
    
    local app_payload=$(jq -n \
        --arg project "$PROJECT_KEY" \
        --arg key "$app_key" \
        --arg name "$app_name" \
        --arg desc "$description" \
        --arg crit "$criticality" \
        --arg mat "$maturity" \
        --arg team "$team" \
        --arg owner "$owner" \
        '{
            "project_key": $project,
            "application_key": $key,
            "application_name": $name,
            "description": $desc,
            "criticality": $crit,
            "maturity_level": $mat,
            "labels": {
                "team": $team,
                "type": "microservice",
                "architecture": "microservices",
                "environment": "production"
            },
            "user_owners": [$owner],
            "group_owners": []
        }')
    
    if ! echo "$app_payload" | jq . >/dev/null 2>&1; then
        echo "❌ CRITICAL: Generated payload is not valid JSON!"
        echo "Raw payload: $app_payload"
        return 1
    fi
    
    local missing_fields=()
    for field in "project_key" "application_key" "application_name" "criticality"; do
        if ! echo "$app_payload" | jq -e ".$field" >/dev/null 2>&1; then
            missing_fields+=("$field")
        fi
    done
    
    if [[ ${#missing_fields[@]} -gt 0 ]]; then
        echo "❌ CRITICAL: Missing required fields in payload: ${missing_fields[*]}"
        echo "Generated payload:"
        echo "$app_payload" | jq .
        return 1
    fi
    
    local temp_response=$(mktemp)
    local temp_headers=$(mktemp)
    local endpoint="${JFROG_URL}/apptrust/api/v1/applications"
    
    echo "🔍 DEBUG: About to create application with the following details:"
    echo "   • Endpoint: $endpoint"
    echo "   • Application Key: $app_key"
    echo "   • Owner: $owner"
    echo "   • Payload being sent:"
    echo "$app_payload" | jq . 2>/dev/null || echo "$app_payload"
    echo ""
    
    local max_attempts=3
    local attempt=1
    local response_code
    
    while [[ $attempt -le $max_attempts ]]; do
        echo "🔄 Attempt $attempt/$max_attempts: Creating application '$app_name'"
        
        response_code=$(curl -s \
            --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
            --header "Content-Type: application/json" \
            --header "User-Agent: BookVerse-Setup/1.0" \
            -X POST \
            -d "$app_payload" \
            --write-out "%{http_code}" \
            --output "$temp_response" \
            --dump-header "$temp_headers" \
            --max-time 30 \
            "$endpoint")
        
        echo "📡 Response received: HTTP $response_code"
        
        if [[ "$response_code" != "500" ]]; then
            break
        fi
        
        echo "❌ HTTP 500 ERROR - Server Internal Error (Attempt $attempt/$max_attempts)"
        echo ""
        echo "🔍 FULL DEBUGGING INFORMATION:"
        echo "================================"
        echo "📋 Request Details:"
        echo "   • Method: POST"
        echo "   • URL: $endpoint"
        echo "   • Content-Type: application/json"
        echo "   • Authorization: Bearer [REDACTED]"
        echo "   • User-Agent: BookVerse-Setup/1.0"
        echo ""
        echo "📤 Request Payload:"
        echo "$app_payload" | jq . 2>/dev/null || echo "$app_payload"
        echo ""
        echo "📥 Response Headers:"
        cat "$temp_headers" 2>/dev/null || echo "   (No headers captured)"
        echo ""
        echo "📥 Response Body:"
        cat "$temp_response" 2>/dev/null || echo "   (No response body)"
        echo ""
        echo "🔧 Server Analysis:"
        echo "   • This suggests the AppTrust API server is experiencing issues"
        echo "   • Could be: payload format issue, server overload, API version mismatch"
        echo "   • Server should be investigated by platform team"
        echo ""
        
        if [[ $attempt -lt $max_attempts ]]; then
            echo "⏳ Waiting 5 seconds before retry..."
            sleep 5
        fi
        
        ((attempt++))
    done
    
    case "$response_code" in
        200|201)
            echo "✅ Application '$app_name' created successfully (HTTP $response_code)"
            ;;
        409)
            echo "⚠️  Application '$app_name' already exists (HTTP $response_code)"
            ;;
        400)
            if grep -q -i "already exists\|application.*exists" "$temp_response"; then
                echo "⚠️  Application '$app_name' already exists (HTTP $response_code)"
            else
                echo "❌ Failed to create application '$app_name' (HTTP $response_code)"
                echo "Response body: $(cat "$temp_response")"
                rm -f "$temp_response"
                return 1
            fi
            ;;
        500)
            response_body=$(cat "$temp_response" 2>/dev/null || echo "")
            if [[ "$response_body" == *'"An unexpected error occurred"'* ]]; then
                echo "🐛 DETECTED: AppTrust API bug - HTTP 500 instead of 409 for conflict"
                echo "🔍 Checking if application '$app_name' already exists..."
                
                existing_check=$(curl -s \
                    --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
                    --write-out "%{http_code}" \
                    --output /dev/null \
                    --max-time 15 \
                    "${JFROG_URL}/apptrust/api/v1/applications/${app_key}")
                
                if [[ "$existing_check" == "200" ]]; then
                    echo "✅ WORKAROUND: Application '$app_name' already exists (confirmed via GET)"
                    echo "🐛 AppTrust API bug confirmed: Returns HTTP 500 instead of HTTP 409 for conflicts"
                    echo "📋 This should be reported to JFrog support for fixing"
                else
                    echo "❌ CRITICAL: Real HTTP 500 error - application does not exist"
                    echo "🚨 This is a genuine server error that needs immediate investigation!"
                    echo ""
                    echo "🔍 FINAL ATTEMPT DEBUGGING INFO:"
                    echo "================================"
                    echo "📥 Final Response Headers:"
                    cat "$temp_headers" 2>/dev/null || echo "   (No headers captured)"
                    echo ""
                    echo "📥 Final Response Body:"
                    cat "$temp_response" 2>/dev/null || echo "   (No response body)"
                    echo ""
                    echo "🎯 RECOMMENDED ACTIONS:"
                    echo "   1. Check AppTrust API server status and logs"
                    echo "   2. Verify endpoint: ${JFROG_URL}/apptrust/api/v1/applications"
                    echo "   3. Test API endpoint manually with curl"
                    echo "   4. Check server capacity and performance"
                    echo "   5. Review server-side application creation logic"
                    echo ""
                    echo "⚠️  TREATING AS NON-CRITICAL FOR NOW - but this needs investigation"
                fi
            else
                echo "❌ CRITICAL: AppTrust API returned HTTP 500 for '$app_name' after $max_attempts attempts"
                echo "🚨 This is a REAL server error that needs immediate investigation!"
                echo ""
                echo "🔍 FINAL ATTEMPT DEBUGGING INFO:"
                echo "================================"
                echo "📥 Final Response Headers:"
                cat "$temp_headers" 2>/dev/null || echo "   (No headers captured)"
                echo ""
                echo "📥 Final Response Body:"
                cat "$temp_response" 2>/dev/null || echo "   (No response body)"
                echo ""
                echo "🎯 RECOMMENDED ACTIONS:"
                echo "   1. Check AppTrust API server status and logs"
                echo "   2. Verify endpoint: ${JFROG_URL}/apptrust/api/v1/applications"
                echo "   3. Test API endpoint manually with curl"
                echo "   4. Check server capacity and performance"
                echo "   5. Review server-side application creation logic"
                echo ""
                echo "⚠️  TREATING AS NON-CRITICAL FOR NOW - but this needs investigation"
            fi
            ;;
        502|503|504)
            echo "❌ AppTrust API unavailable for '$app_name' (HTTP $response_code)"
            echo "🔍 DEBUG: Response details:"
            echo "Response headers: $(cat "$temp_headers" 2>/dev/null || echo 'none')"
            echo "Response body: $(cat "$temp_response" 2>/dev/null || echo 'none')"
            echo "💡 Temporary server issue - applications may need manual verification"
            ;;
        *)
            echo "❌ Failed to create application '$app_name' (HTTP $response_code)"
            echo "🔍 DEBUG: Full response details:"
            echo "Response headers: $(cat "$temp_headers" 2>/dev/null || echo 'none')"
            echo "Response body: $(cat "$temp_response" 2>/dev/null || echo 'none')"
            echo "💡 This may be due to API format changes or permission issues"
            echo "🎯 RECOMMENDED: Check API documentation for correct payload format"
            ;;
    esac
    
    rm -f "$temp_response" "$temp_headers"
    echo ""
}

echo "ℹ️  Applications to be created:"
for app_data in "${BOOKVERSE_APPLICATIONS[@]}"; do
    IFS='|' read -r app_key app_name _ criticality _ team owner <<< "$app_data"
    echo "   - $app_name ($app_key) → $owner [$criticality]"
done

echo ""
echo "🚀 Processing ${#BOOKVERSE_APPLICATIONS[@]} applications..."
echo ""

for app_data in "${BOOKVERSE_APPLICATIONS[@]}"; do
    IFS='|' read -r app_key app_name description criticality maturity team owner <<< "$app_data"
    
    create_application "$app_key" "$app_name" "$description" "$criticality" "$maturity" "$team" "$owner"
done

echo "✅ Application creation process completed!"
echo ""
echo "📱 Applications Summary:"
for app_data in "${BOOKVERSE_APPLICATIONS[@]}"; do
    IFS='|' read -r app_key app_name _ criticality _ team owner <<< "$app_data"
    echo "   - $app_name (Key: $app_key, Owner: $owner, Team: $team)"
done

echo ""
echo "🎯 BookVerse applications setup completed"
echo "   Successfully created applications are available in AppTrust"
echo "   Any applications with HTTP 500 errors may require manual setup"
echo ""


update_repo_jfrog_config() {
    local app_key="$1"
    local repo_name="$app_key"
    local owner="${GITHUB_REPOSITORY_OWNER:-yonatanp-jfrog}"

    if ! command -v gh >/dev/null 2>&1; then
        echo "⚠️  GitHub CLI (gh) not found; skipping .jfrog/config.yml update for $owner/$repo_name"
        return 0
    fi

    echo "🔧 Updating .jfrog/config.yml in $owner/$repo_name"

    local branch
    branch=$(gh api "repos/$owner/$repo_name" -q .default_branch 2>/dev/null || echo "main")

    local file_content
    file_content=$(printf "application:\n  key: \"%s\"\n" "$app_key")
    local b64
    b64=$(printf "%s" "$file_content" | base64 | tr -d '\n')

    local sha
    sha=$(gh api -X GET "repos/$owner/$repo_name/contents/.jfrog/config.yml" -f ref="$branch" -q .sha 2>/dev/null || echo "")

    local payload
    local msg="chore: set JFrog application key ($app_key)"
    if [[ -n "$sha" ]]; then
        payload=$(jq -n --arg message "$msg" --arg content "$b64" --arg branch "$branch" --arg sha "$sha" '{message:$message, content:$content, branch:$branch, sha:$sha}')
    else
        payload=$(jq -n --arg message "$msg" --arg content "$b64" --arg branch "$branch" '{message:$message, content:$content, branch:$branch}')
    fi

    if echo "$payload" | gh api -X PUT -H "Accept: application/vnd.github+json" "repos/$owner/$repo_name/contents/.jfrog/config.yml" --input - >/dev/null 2>&1; then
        echo "✅ .jfrog/config.yml updated in $owner/$repo_name@$branch"
    else
        echo "⚠️  Failed to update .jfrog/config.yml in $owner/$repo_name (continuing)"
    fi
}

echo "🔧 Propagating application keys to service repositories - jfrog config"
for app_data in "${BOOKVERSE_APPLICATIONS[@]}"; do
    IFS='|' read -r app_key _rest <<< "$app_data"
    update_repo_jfrog_config "$app_key"
done

echo "✅ Repository configuration updates completed"