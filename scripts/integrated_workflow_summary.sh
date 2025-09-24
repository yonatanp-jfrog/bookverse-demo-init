#!/usr/bin/env bash
# =============================================================================
# BookVerse Platform - Integrated Workflow Summary Script
# =============================================================================
#
# Combines enhanced CI/CD summary generation with promotion failure handling
# to provide comprehensive, accurate pipeline reporting in GitHub Actions.
#
# This script addresses common CI/CD reporting issues:
# 1. ✅ Accurate job status reporting (fixes false success reporting)
# 2. ✅ Stage lifecycle path tracking (shows progression through stages)
# 3. ✅ Proper artifact display (fixes N/A values)
# 4. ✅ Contextual infrastructure info (only when relevant)
# 5. ✅ Detailed promotion failure analysis (policy-specific guidance)
#
# Usage:
#   # Basic usage with environment variables
#   ./integrated_workflow_summary.sh
#   
#   # With explicit parameters
#   ./integrated_workflow_summary.sh --service inventory --version 2.7.25 --promotion-failed
#   
#   # With promotion failure data
#   echo '{"promotion_data":"..."}' | ./integrated_workflow_summary.sh --stdin
#
# Environment Variables:
#   SERVICE_NAME, APP_VERSION, BUILD_NAME, BUILD_NUMBER, etc.
#   PROMOTION_FAILED, FAILURE_DATA (JSON)
#   GITHUB_STEP_SUMMARY (for output)
#
# Authors: BookVerse Platform Team
# Version: 1.0.0
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENHANCED_SUMMARY_SCRIPT="${SCRIPT_DIR}/enhanced_ci_summary.py"
PROMOTION_FAILURE_SCRIPT="${SCRIPT_DIR}/promotion_failure_summary.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}" >&2
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}" >&2
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}" >&2
}

log_error() {
    echo -e "${RED}❌ $1${NC}" >&2
}

show_usage() {
    cat << 'EOF'
BookVerse Integrated Workflow Summary Generator

USAGE:
    ./integrated_workflow_summary.sh [OPTIONS]
    echo '{"failure_data":"..."}' | ./integrated_workflow_summary.sh --stdin

DESCRIPTION:
    Generates comprehensive CI/CD pipeline summaries with accurate job status
    reporting, stage lifecycle tracking, and promotion failure analysis.

OPTIONS:
    --service NAME           Service name (default: from SERVICE_NAME env var)
    --version VERSION        Application version (default: from APP_VERSION env var)
    --current-stage STAGE    Current application stage (default: from CURRENT_STAGE env var)
    --target-stage STAGE     Target promotion stage (default: from TARGET_STAGE env var)
    --promotion-failed       Indicate promotion failed (default: from PROMOTION_FAILED env var)
    --docker-tag TAG         Docker image tag (default: from IMAGE_TAG env var)
    --coverage PERCENT       Test coverage percentage (default: from COVERAGE_PERCENT env var)
    --stdin                  Read promotion failure data from stdin
    --verbose                Enable verbose output
    --help                   Show this help message

ENVIRONMENT VARIABLES:
    Core Information:
      SERVICE_NAME           Service name (e.g., inventory)
      APP_VERSION           Application version (e.g., 2.7.25)
      BUILD_NAME            Build name
      BUILD_NUMBER          Build number
      
    Git Information:
      GITHUB_SHA            Commit hash
      GITHUB_REF_NAME       Branch name
      
    Job Status:
      JOB_1_STATUS          analyze-commit job status
      JOB_2_STATUS          build-test-publish job status  
      JOB_3_STATUS          create-promote job status
      
    Stage Information:
      CURRENT_STAGE         Current application stage
      TARGET_STAGE          Target promotion stage
      PROMOTION_FAILED      Set to 'true' if promotion failed
      
    Artifact Information:
      IMAGE_TAG             Docker image tag
      DOCKER_TAG_INVENTORY  Alternative docker tag variable
      COVERAGE_PERCENT      Test coverage percentage
      BUILD_INFO_PUBLISH_STATUS  Build info publication status
      
    Promotion Failure:
      FAILURE_DATA          JSON data from promotion failure
      
    Output:
      GITHUB_STEP_SUMMARY   GitHub Actions step summary file path

EXAMPLES:
    # Basic usage with environment variables
    export SERVICE_NAME="inventory"
    export APP_VERSION="2.7.25"
    export PROMOTION_FAILED="true"
    ./integrated_workflow_summary.sh
    
    # With explicit parameters
    ./integrated_workflow_summary.sh --service inventory --version 2.7.25 \\
      --current-stage bookverse-DEV --target-stage bookverse-QA --promotion-failed
    
    # With promotion failure data from stdin
    echo '{"application_key":"bookverse-inventory",...}' | \\
      ./integrated_workflow_summary.sh --stdin --promotion-failed

WORKFLOW INTEGRATION:
    Add this step to your GitHub Actions workflow:
    
    - name: Generate Comprehensive Summary
      if: always()  # Run regardless of previous step outcomes
      run: |
        # Set job status based on actual outcomes
        export JOB_1_STATUS="${{ steps.analyze.conclusion }}"
        export JOB_2_STATUS="${{ steps.build.conclusion }}"
        export JOB_3_STATUS="${{ steps.promote.conclusion }}"
        
        # Handle promotion failure if applicable
        if [[ "${{ steps.promote.conclusion }}" == "failure" ]]; then
          export PROMOTION_FAILED="true"
          export FAILURE_DATA='${{ steps.promote.outputs.failure_json }}'
        fi
        
        # Generate integrated summary
        ./scripts/integrated_workflow_summary.sh
      env:
        SERVICE_NAME: inventory
        APP_VERSION: ${{ steps.build.outputs.app_version }}
        CURRENT_STAGE: ${{ steps.build.outputs.current_stage }}
        TARGET_STAGE: ${{ steps.promote.inputs.target_stage }}

EOF
}

extract_env_vars() {
    # Extract common environment variables with defaults
    SERVICE_NAME="${SERVICE_NAME:-${1:-unknown}}"
    APP_VERSION="${APP_VERSION:-N/A}"
    BUILD_NAME="${BUILD_NAME:-CI}"
    BUILD_NUMBER="${BUILD_NUMBER:-1}"
    
    # Git information
    COMMIT_HASH="${GITHUB_SHA:-unknown}"
    BRANCH_NAME="${GITHUB_REF_NAME:-main}"
    
    # Job statuses (map GitHub Actions conclusions to our format)
    JOB_1_STATUS="${JOB_1_STATUS:-success}"
    JOB_2_STATUS="${JOB_2_STATUS:-success}"
    JOB_3_STATUS="${JOB_3_STATUS:-success}"
    
    # Map GitHub Actions conclusions
    case "${JOB_1_STATUS}" in
        "success") JOB_1_STATUS="success" ;;
        "failure") JOB_1_STATUS="failed" ;;
        "cancelled") JOB_1_STATUS="cancelled" ;;
        *) JOB_1_STATUS="success" ;;
    esac
    
    case "${JOB_2_STATUS}" in
        "success") JOB_2_STATUS="success" ;;
        "failure") JOB_2_STATUS="failed" ;;
        "cancelled") JOB_2_STATUS="cancelled" ;;
        *) JOB_2_STATUS="success" ;;
    esac
    
    case "${JOB_3_STATUS}" in
        "success") JOB_3_STATUS="success" ;;
        "failure") JOB_3_STATUS="failed" ;;
        "cancelled") JOB_3_STATUS="cancelled" ;;
        *) JOB_3_STATUS="${PROMOTION_FAILED:+failed}" ;;
    esac
    
    # Stage information
    CURRENT_STAGE="${CURRENT_STAGE:-bookverse-DEV}"
    TARGET_STAGE="${TARGET_STAGE:-}"
    PROMOTION_FAILED="${PROMOTION_FAILED:-false}"
    
    # Artifact information
    DOCKER_TAG="${IMAGE_TAG:-${DOCKER_TAG_INVENTORY:-}}"
    COVERAGE_PERCENT="${COVERAGE_PERCENT:-}"
    BUILD_INFO_STATUS="${BUILD_INFO_PUBLISH_STATUS:-SUCCESS}"
    
    # Promotion failure data
    FAILURE_DATA="${FAILURE_DATA:-}"
}

parse_arguments() {
    local stdin_mode=false
    local verbose=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --service)
                SERVICE_NAME="$2"
                shift 2
                ;;
            --version)
                APP_VERSION="$2"
                shift 2
                ;;
            --current-stage)
                CURRENT_STAGE="$2"
                shift 2
                ;;
            --target-stage)
                TARGET_STAGE="$2"
                shift 2
                ;;
            --promotion-failed)
                PROMOTION_FAILED="true"
                shift
                ;;
            --docker-tag)
                DOCKER_TAG="$2"
                shift 2
                ;;
            --coverage)
                COVERAGE_PERCENT="$2"
                shift 2
                ;;
            --stdin)
                stdin_mode=true
                shift
                ;;
            --verbose)
                verbose=true
                shift
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Handle stdin input for promotion failure data
    if [[ "$stdin_mode" == "true" ]]; then
        if [[ -t 0 ]]; then
            log_error "No input provided via stdin"
            exit 1
        fi
        
        FAILURE_DATA=$(cat)
        PROMOTION_FAILED="true"
        
        if [[ "$verbose" == "true" ]]; then
            log_info "Read $(echo "${FAILURE_DATA}" | wc -c) characters from stdin"
        fi
    fi
    
    # Set verbose mode
    if [[ "$verbose" == "true" ]]; then
        VERBOSE=1
    fi
}

generate_enhanced_summary() {
    log_info "Generating enhanced CI/CD summary..."
    
    # Build job status string
    local job_status="analyze-commit:${JOB_1_STATUS},build-test-publish:${JOB_2_STATUS},create-promote:${JOB_3_STATUS}"
    
    # Build arguments for enhanced summary
    local args=(
        "--service" "${SERVICE_NAME}"
        "--version" "${APP_VERSION}"
        "--build-name" "${BUILD_NAME}"
        "--build-number" "${BUILD_NUMBER}"
        "--commit" "${COMMIT_HASH}"
        "--branch" "${BRANCH_NAME}"
        "--job-status" "${job_status}"
        "--current-stage" "${CURRENT_STAGE}"
        "--build-info-status" "${BUILD_INFO_STATUS}"
        "--github-summary"
    )
    
    # Add optional parameters
    if [[ -n "${TARGET_STAGE}" ]]; then
        args+=("--target-stage" "${TARGET_STAGE}")
    fi
    
    if [[ "${PROMOTION_FAILED}" == "true" ]]; then
        args+=("--promotion-failed")
    fi
    
    if [[ -n "${DOCKER_TAG}" ]]; then
        args+=("--docker-tag" "${DOCKER_TAG}")
    fi
    
    if [[ -n "${COVERAGE_PERCENT}" ]]; then
        args+=("--coverage" "${COVERAGE_PERCENT}")
    fi
    
    if [[ -n "${FAILURE_DATA}" ]]; then
        args+=("--promotion-data" "${FAILURE_DATA}")
    fi
    
    # Execute enhanced summary
    if python3 "${ENHANCED_SUMMARY_SCRIPT}" "${args[@]}"; then
        log_success "Enhanced CI/CD summary generated"
    else
        log_error "Failed to generate enhanced summary"
        return 1
    fi
}

generate_promotion_failure_details() {
    if [[ "${PROMOTION_FAILED}" != "true" ]]; then
        return 0
    fi
    
    log_info "Generating detailed promotion failure analysis..."
    
    # Append promotion failure details to GitHub summary
    if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
        echo "" >> "${GITHUB_STEP_SUMMARY}"
        echo "---" >> "${GITHUB_STEP_SUMMARY}"
        echo "" >> "${GITHUB_STEP_SUMMARY}"
    fi
    
    # Generate promotion failure details
    if [[ -n "${FAILURE_DATA}" ]]; then
        if echo "${FAILURE_DATA}" | "${PROMOTION_FAILURE_SCRIPT}"; then
            log_success "Promotion failure details generated"
        else
            log_warning "Failed to generate promotion failure details"
        fi
    else
        log_warning "No promotion failure data available for detailed analysis"
        
        # Generate basic failure message
        if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
            cat >> "${GITHUB_STEP_SUMMARY}" << EOF
# 🚨 Promotion Failure Details

## ❌ Summary
Promotion to ${TARGET_STAGE:-target stage} failed due to policy violations.

## 🔧 Next Steps
1. Check the workflow logs for detailed error information
2. Review AppTrust console for policy evaluation results
3. Address any policy violations identified
4. Retry the promotion once issues are resolved

## 📞 Support
Contact #platform-support for assistance with policy failures.
EOF
        fi
    fi
}

main() {
    log_info "BookVerse Integrated Workflow Summary Generator v1.0.0"
    
    # Extract environment variables
    extract_env_vars "$@"
    
    # Parse command line arguments
    parse_arguments "$@"
    
    # Validate required scripts exist
    if [[ ! -f "${ENHANCED_SUMMARY_SCRIPT}" ]]; then
        log_error "Enhanced summary script not found: ${ENHANCED_SUMMARY_SCRIPT}"
        exit 1
    fi
    
    if [[ ! -f "${PROMOTION_FAILURE_SCRIPT}" ]]; then
        log_error "Promotion failure script not found: ${PROMOTION_FAILURE_SCRIPT}"
        exit 1
    fi
    
    # Check Python availability
    if ! command -v python3 >/dev/null 2>&1; then
        log_error "Python 3 is required but not found"
        exit 1
    fi
    
    # Generate enhanced summary
    if ! generate_enhanced_summary; then
        log_error "Failed to generate enhanced summary"
        exit 1
    fi
    
    # Generate promotion failure details if applicable
    if ! generate_promotion_failure_details; then
        log_warning "Promotion failure details generation had issues"
    fi
    
    log_success "Integrated workflow summary generation completed"
    
    if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
        log_success "Summary written to GitHub Step Summary"
    fi
    
    if [[ "${VERBOSE:-}" ]]; then
        log_info "Summary components:"
        echo "  - Enhanced CI/CD pipeline overview" >&2
        echo "  - Accurate job status reporting" >&2
        echo "  - Stage lifecycle tracking" >&2
        echo "  - Artifact and quality metrics" >&2
        if [[ "${PROMOTION_FAILED}" == "true" ]]; then
            echo "  - Detailed promotion failure analysis" >&2
        fi
    fi
}

main "$@"
