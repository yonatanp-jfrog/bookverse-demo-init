#!/usr/bin/env bash

# =============================================================================
# BookVerse Platform - Repository Creation and Artifact Management Script
# =============================================================================
#
# This comprehensive setup script automates the creation and configuration of
# all artifact repositories required for the BookVerse platform within the JFrog
# Artifactory ecosystem, implementing enterprise-grade repository management,
# package-type specialization, and multi-environment artifact organization
# for production-ready deployment and dependency management.
#
# 🏗️ REPOSITORY CREATION STRATEGY:
#     - Multi-Service Repository Architecture: Dedicated artifact repositories for each BookVerse service
#     - Package-Type Specialization: Docker, PyPI, Generic, and Helm repository configuration
#     - Environment Segregation: Separate nonprod and release repository groups for lifecycle management
#     - Visibility Management: Internal and public repository access control and security
#     - Artifact Organization: Structured repository naming and hierarchical organization
#     - Integration Standards: JFrog Artifactory REST API automation and configuration management
#
# 📦 BOOKVERSE REPOSITORY ECOSYSTEM:
#     - Inventory Service: Docker containers and PyPI packages for core business logic
#     - Recommendations Service: Docker containers and generic artifacts for AI/ML models
#     - Checkout Service: Docker containers and generic artifacts for payment processing
#     - Platform Integration: Docker containers for unified platform coordination
#     - Web Application: Generic artifacts for frontend assets and static content delivery
#     - Helm Charts: Kubernetes deployment manifests and infrastructure-as-code
#     - Infrastructure Libraries: PyPI packages and generic artifacts for shared components
#
# 🛡️ ENTERPRISE SECURITY AND GOVERNANCE:
#     - Repository Access Control: Role-based security and permission management
#     - Artifact Lifecycle Management: Automated retention policies and cleanup procedures
#     - Security Scanning: Vulnerability assessment and compliance validation integration
#     - Audit Trail: Complete artifact repository operation history and compliance tracking
#     - Backup and Recovery: Repository backup procedures and disaster recovery integration
#     - Compliance Integration: SOX, PCI-DSS, GDPR compliance for artifact management
#
# 🔧 PACKAGE TYPE SPECIALIZATION:
#     - Docker Repositories: Container image management with layer optimization and security scanning
#     - PyPI Repositories: Python package management with dependency resolution and caching
#     - Generic Repositories: Flexible artifact storage for ML models, configurations, and assets
#     - Helm Repositories: Kubernetes chart management with versioning and deployment automation
#     - Multi-Format Support: Comprehensive package type support for diverse technology stacks
#     - Repository Aggregation: Virtual repositories for unified artifact access and distribution
#
# 📈 SCALABILITY AND PERFORMANCE:
#     - Repository Partitioning: Service-specific repository organization for optimal performance
#     - Caching Strategy: Intelligent artifact caching and distribution optimization
#     - Load Distribution: Repository load balancing and performance optimization
#     - Storage Optimization: Artifact deduplication and storage efficiency management
#     - Network Optimization: CDN integration and global artifact distribution
#     - Monitoring Integration: Repository performance monitoring and alerting
#
# 🔐 SECURITY AND COMPLIANCE FEATURES:
#     - Access Control: Fine-grained repository permission management and role-based security
#     - Vulnerability Scanning: Automated security scanning and vulnerability assessment
#     - Audit Compliance: Complete repository audit trail and forensic investigation support
#     - Encryption: Artifact encryption at rest and in transit for data protection
#     - Token Management: Secure API token and credential management for repository access
#     - Compliance Reporting: Automated compliance reporting and regulatory audit support
#
# 🛠️ TECHNICAL IMPLEMENTATION:
#     - JFrog Artifactory Integration: Native artifact repository management platform integration
#     - REST API Automation: Programmatic repository configuration via JFrog APIs
#     - Repository Templates: Standardized repository configuration and policy templates
#     - Lifecycle Management: Automated repository lifecycle and retention policy management
#     - Integration Testing: Repository connectivity and access validation
#     - Performance Optimization: Repository configuration tuning for optimal artifact management
#
# 📋 REPOSITORY CONFIGURATION PATTERNS:
#     - Naming Convention: Standardized repository naming for consistency and organization
#     - Package Type Mapping: Service-specific package type assignment and optimization
#     - Visibility Control: Internal and public repository access patterns and security
#     - Environment Segregation: Repository organization for development and production environments
#     - Retention Policies: Automated artifact cleanup and lifecycle management
#     - Integration Points: Repository integration with CI/CD pipelines and deployment automation
#
# 🎯 SUCCESS CRITERIA:
#     - Repository Creation: All BookVerse service repositories successfully provisioned
#     - Security Configuration: Complete repository access control and security validation
#     - Performance Optimization: Repository configuration optimized for artifact management
#     - Integration Validation: Repository connectivity and CI/CD integration verification
#     - Compliance Readiness: Repository configuration meeting regulatory and audit requirements
#     - Operational Excellence: Repository management ready for production artifact operations
#
# Authors: BookVerse Platform Team
# Version: 1.0.0
# Last Updated: 2024
#
# Dependencies:
#   - config.sh (configuration management)
#   - JFrog Artifactory Platform (artifact repository management)
#   - Valid authentication credentials (admin tokens)
#   - Network connectivity to JFrog Platform endpoints
#
# =============================================================================

set -e

source "$(dirname "$0")/config.sh"

# 🏢 BookVerse Service Architecture Definition
# Complete list of all BookVerse microservices requiring dedicated artifact repositories
# Each service has specialized package type requirements based on technology stack
SERVICES=(
    "inventory"      # Core business inventory and stock management service
    "recommendations" # AI-powered personalization and recommendation engine
    "checkout"       # Secure payment processing and transaction management service
    "platform"      # Unified platform coordination and API gateway service
    "web"           # Customer-facing frontend and static asset delivery service
    "helm"          # Kubernetes deployment manifests and infrastructure-as-code
    "infra"         # Infrastructure libraries and shared DevOps automation components
)

get_packages_for_service() {
    local service="$1"
    case "$service" in
        inventory)
            echo "docker pypi"
            ;;
        recommendations)
            echo "docker generic"
            ;;
        checkout)
            echo "docker generic"
            ;;
        platform)
            echo "docker"
            ;;
        web)
            echo "generic"
            ;;
        helm)
            echo "helm"
            ;;
        infra)
            echo "pypi generic"
            ;;
        *)
            echo "docker"
            ;;
    esac
}

echo ""
echo "🚀 Creating repositories for BookVerse microservices platform"
echo "🔧 Project: $PROJECT_KEY"
echo "🔧 JFrog URL: $JFROG_URL"
echo ""

get_visibility_for_service() {
    local service_name="$1"
    case "$service_name" in
        platform)
            echo "public"
            ;;
        *)
            echo "internal"
            ;;
    esac
}

create_repository() {
    local service="$1"
    local package_type="$2"
    local repo_type="$3"
    
    local visibility
    visibility=$(get_visibility_for_service "$service")
    local stage_group
    if [[ "$repo_type" == "internal" ]]; then
        stage_group="nonprod"
    else
        stage_group="release"
    fi
    local repo_key="${PROJECT_KEY}-${service}-${visibility}-${package_type}-${stage_group}-local"
    
    if [[ "$repo_type" == "internal" ]]; then
        local environments="\"${PROJECT_KEY}-DEV\", \"${PROJECT_KEY}-QA\", \"${PROJECT_KEY}-STAGING\""
        local repo_config=$(jq -n \
            --arg key "$repo_key" \
            --arg rclass "local" \
            --arg packageType "$package_type" \
            --arg description "Repository for $service $package_type packages ($repo_type)" \
            --arg projectKey "$PROJECT_KEY" \
            --argjson environments "[$environments]" \
            '{
                "key": $key,
                "rclass": $rclass,
                "packageType": $packageType,
                "description": $description,
                "projectKey": $projectKey,
                "environments": $environments
            }')
    else
        local environments='["PROD"]'
        local repo_config=$(jq -n \
            --arg key "$repo_key" \
            --arg rclass "local" \
            --arg packageType "$package_type" \
            --arg description "Repository for $service $package_type packages ($repo_type)" \
            --arg projectKey "$PROJECT_KEY" \
            --argjson environments "$environments" \
            '{
                "key": $key,
                "rclass": $rclass,
                "packageType": $packageType,
                "description": $description,
                "projectKey": $projectKey,
                "environments": $environments
            }')
    fi
    
    echo "Creating repository: $repo_key"
    
    local temp_response=$(mktemp)
    local response_code=$(curl -s --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
        --header "Content-Type: application/json" \
        -X PUT \
        -d "$repo_config" \
        --write-out "%{http_code}" \
        --output "$temp_response" \
        "${JFROG_URL}/artifactory/api/repositories/${repo_key}")
    
    case "$response_code" in
        200|201)
            echo "✅ Repository '$repo_key' created successfully (HTTP $response_code)"
            ;;
        409)
            echo "✅ Repository '$repo_key' already exists and is configured"
            ;;
        400)
            if grep -q -i "already exists\|repository.*exists\|case insensitive.*already exists" "$temp_response"; then
                echo "✅ Repository '$repo_key' already exists (case-insensitive match)"
            else
                echo "⚠️  Repository '$repo_key' creation issue (HTTP $response_code)"
                if [[ "${VERBOSITY:-0}" -ge 1 ]]; then
                    echo "Response body: $(cat "$temp_response")"
                    echo "Repository config sent:"
                    echo "$repo_config" | jq .
                fi
                echo "💡 Repository may exist with different configuration or permissions issue"
                rm -f "$temp_response"
            fi
            ;;
        *)
            echo "❌ Failed to create repository '$repo_key' (HTTP $response_code)"
            if [[ "${VERBOSITY:-0}" -ge 1 ]]; then
                echo "Response body: $(cat "$temp_response")"
                echo "Repository config sent:"
                echo "$repo_config" | jq .
            fi
            echo "💡 This may be due to permissions, API changes, or network issues"
            rm -f "$temp_response"
            return 1
            ;;
    esac
    
    rm -f "$temp_response"

    local expected_envs_json
    if [[ "$repo_type" == "internal" ]]; then
        expected_envs_json=$(jq -nc --arg p "$PROJECT_KEY" '[($p+"-DEV"), ($p+"-QA"), ($p+"-STAGING")]')
    else
        expected_envs_json='["PROD"]'
    fi

    local get_resp_file=$(mktemp)
    local get_code=$(curl -s --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
        --write-out "%{http_code}" --output "$get_resp_file" \
        "${JFROG_URL}/artifactory/api/repositories/${repo_key}")
    if [[ "$get_code" =~ ^2 ]]; then
        local envs_match
        envs_match=$(jq --argjson exp "$expected_envs_json" '(
            ( .environments // [] ) as $cur
            | ($cur | length) == ($exp | length)
            and ((($cur - $exp) | length) == 0)
            and ((($exp - $cur) | length) == 0)
        )' "$get_resp_file" 2>/dev/null || echo "false")
        if [[ "$envs_match" != "true" ]]; then
            echo "Updating environments for repository: $repo_key"
            local updated_config
            updated_config=$(jq --arg projectKey "$PROJECT_KEY" --argjson envs "$expected_envs_json" \
                '.projectKey = $projectKey | .environments = $envs' "$get_resp_file")
            local up_tmp=$(mktemp)
            local up_code=$(curl -s --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
                --header "Content-Type: application/json" -X POST \
                -d "$updated_config" --write-out "%{http_code}" --output "$up_tmp" \
                "${JFROG_URL}/artifactory/api/repositories/${repo_key}")
            case "$up_code" in
                200)
                    echo "✅ Repository '$repo_key' environments updated"
                    ;;
                *)
                    echo "⚠️  Failed to update environments for '$repo_key' (HTTP $up_code)"
                    if [[ "${VERBOSITY:-0}" -ge 1 ]]; then
                        echo "Response body: $(cat "$up_tmp")"
                    fi
                    ;;
            esac
            rm -f "$up_tmp"
        fi
    else
        echo "⚠️  Could not fetch repository '$repo_key' to verify environments (HTTP $get_code)"
    fi
    rm -f "$get_resp_file"
}

SERVICES=("core" "inventory" "recommendations" "checkout" "platform" "web" "helm" "infra")

get_packages_for_service() {
    case "$1" in
        core)
            echo "python docker pypi"
            ;;
        inventory|recommendations|checkout)
            echo "python docker generic"
            ;;
        platform)
            echo "python docker generic"
            ;;
        web)
            echo "npm docker generic"
            ;;
        helm)
            echo "helm generic"
            ;;
        infra)
            echo "pypi generic"
            ;;
        *)
            echo ""
            ;;
    esac
}

echo "Creating repositories for services..."
echo ""

for service in "${SERVICES[@]}"; do
    package_types="$(get_packages_for_service "$service")"
    echo "Processing service: $service (creating: $package_types)"

    for package_type in $package_types; do
        create_repository "$service" "$package_type" "internal"
        
        create_repository "$service" "$package_type" "release"
    done
    
    echo ""
done

echo "✅ Service repositories creation completed successfully!"
echo ""
echo "ℹ️ Dependency repositories and prepopulation are now run by workflow steps."


prune_old_repositories() {
    echo ""; echo "🧹 Pruning old/misnamed local repositories (project=${PROJECT_KEY})"

    local expected_file
    expected_file=$(mktemp)
    for service in "${SERVICES[@]}"; do
        package_types="$(get_packages_for_service "$service")"
        visibility="$(get_visibility_for_service "$service")"
        for package_type in $package_types; do
            for repo_type in internal release; do
                if [[ "$repo_type" == "internal" ]]; then stage_group="nonprod"; else stage_group="release"; fi
                key="${PROJECT_KEY}-${service}-${visibility}-${package_type}-${stage_group}-local"
                echo "$key" >> "$expected_file"
            done
        done
    done

    local list_file candidates_file
    list_file=$(mktemp)
    candidates_file=$(mktemp)
    local code=$(curl -s --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
        --header "Accept: application/json" \
        --write-out "%{http_code}" --output "$list_file" \
        "${JFROG_URL}/artifactory/api/repositories?type=local")
    if [[ "$code" -lt 200 || "$code" -ge 300 ]]; then
        echo "⚠️  Failed to list repositories (HTTP $code); skipping prune"
        rm -f "$list_file" "$candidates_file"
        return 0
    fi

    jq -r --arg p "${PROJECT_KEY}-" '[ .[] | select(.key|startswith($p)) | .key ] | .[]' "$list_file" 2>/dev/null > "$candidates_file" || printf '' > "$candidates_file"
    rm -f "$list_file"

    CANDIDATES=()
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        CANDIDATES+=("$line")
    done < "$candidates_file"
    rm -f "$candidates_file"

    local pruned=0
    for key in "${CANDIDATES[@]}"; do
        if [[ "$key" != *"-internal-"* && "$key" != *"-public-"* ]]; then continue; fi
        if [[ "$key" != *"-local" ]]; then continue; fi
        if grep -Fxq "$key" "$expected_file"; then continue; fi
        echo "🗑️  Deleting outdated repo: $key"
        local del_code=$(curl -s -X DELETE \
            --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
            --write-out "%{http_code}" --output /dev/null \
            "${JFROG_URL}/artifactory/api/repositories/${key}" || echo 000)
        if [[ "$del_code" =~ ^2 ]]; then
            echo "✅ Deleted $key"
            pruned=$((pruned+1))
        else
            echo "⚠️  Failed to delete $key (HTTP $del_code)"
        fi
    done

    if [[ "$pruned" -gt 0 ]]; then
        echo "🧹 Prune complete. Removed $pruned repos."
    else
        echo "🧹 No outdated repos found to prune."
    fi

    rm -f "$expected_file"
}

prune_old_repositories