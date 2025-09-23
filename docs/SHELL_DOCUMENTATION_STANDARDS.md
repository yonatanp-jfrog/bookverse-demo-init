# Shell Script Documentation Standards

## 📚 Overview

This document establishes comprehensive documentation standards for shell scripts in the BookVerse platform, ensuring consistent, self-served documentation that enables users to understand, execute, and maintain automation scripts effectively.

---

## 🎯 Documentation Philosophy

### **Self-Served Design Principles**
- **Assume Zero Knowledge**: Every script should be understandable without prior platform experience
- **Progressive Disclosure**: Layer complexity from basic usage to advanced scenarios
- **Rich Context**: Provide business purpose, technical details, and operational guidance
- **Visual Communication**: Use emojis, headers, and formatting for enhanced readability
- **Actionable Guidance**: Every section should provide clear, testable outcomes

### **Comprehensive Coverage Standards**
- **Purpose & Scope**: Clear explanation of what the script does and why
- **Business Context**: How the script fits into the larger platform ecosystem
- **Technical Details**: Implementation approach, dependencies, and constraints
- **Usage Patterns**: Common execution scenarios and integration points
- **Error Handling**: Failure modes, recovery procedures, and troubleshooting
- **Examples**: Real-world usage scenarios with expected outcomes

---

## 📝 Script Header Template

Every shell script must begin with a comprehensive header following this template:

```bash
#!/usr/bin/env bash
# =============================================================================
# BookVerse Platform - [Script Category] - [Script Name]
# =============================================================================
#
# [Brief one-line description of script purpose]
#
# 🎯 PURPOSE:
#     [Detailed explanation of what this script accomplishes and why it exists]
#     [Business context and importance within the platform ecosystem]
#     [Integration points with other scripts and services]
#
# 🏗️ ARCHITECTURE:
#     [Technical approach and implementation strategy]
#     [Key algorithms or logic patterns used]
#     [Dependencies and external service integration]
#
# 🚀 KEY FEATURES:
#     [Major capabilities and functionality provided]
#     [Performance characteristics and scalability considerations]
#     [Security and reliability features]
#
# 📊 BUSINESS LOGIC:
#     [How this script supports business objectives]
#     [Impact on user experience or operational efficiency]
#     [Integration with CI/CD or operational workflows]
#
# 🔧 USAGE PATTERNS:
#     [Common execution scenarios and use cases]
#     [Integration with other scripts or automation]
#     [Manual vs automated execution contexts]
#
# ⚙️ PARAMETERS:
#     [Required Parameters]
#     --required-param    : Description of required parameter
#     
#     [Optional Parameters]
#     --optional-param    : Description with default value [default: value]
#     --flag             : Boolean flag description
#
# 🌍 ENVIRONMENT VARIABLES:
#     [Required Environment Variables]
#     REQUIRED_VAR       : Description and expected format
#     
#     [Optional Environment Variables]  
#     OPTIONAL_VAR       : Description [default: value]
#
# 📋 PREREQUISITES:
#     [System Requirements]
#     - Tool 1 (version): Installation method
#     - Tool 2 (version): Installation method
#     
#     [Access Requirements]
#     - Platform access: Description of required permissions
#     - Network access: Description of network requirements
#
# 🎛️ CONFIGURATION:
#     [Configuration Files]
#     - config.yml: Description of configuration file
#     
#     [Default Settings]
#     - Setting 1: Default value and meaning
#     - Setting 2: Default value and meaning
#
# 📤 OUTPUTS:
#     [Return Codes]
#     0: Success - Description of successful completion
#     1: Error - Description of general failure
#     2: Config Error - Description of configuration issues
#     
#     [Generated Files]
#     - output.log: Description of log file
#     - result.json: Description of result file
#
# 💡 EXAMPLES:
#     [Basic Usage]
#     ./script.sh --required-param value
#     
#     [Advanced Usage]
#     OPTIONAL_VAR=custom ./script.sh --required-param value --optional-param custom
#     
#     [CI/CD Integration]
#     name: Run Script
#     run: |
#       ./script.sh --required-param ${{ env.PARAM_VALUE }}
#
# ⚠️ ERROR HANDLING:
#     [Common Failure Modes]
#     - Failure Type 1: Cause and resolution
#     - Failure Type 2: Cause and resolution
#     
#     [Recovery Procedures]
#     - Manual Recovery: Steps to manually resolve issues
#     - Automatic Retry: When and how retries occur
#
# 🔍 DEBUGGING:
#     [Debug Mode]
#     DEBUG=1 ./script.sh --params    # Enable debug output
#     
#     [Log Analysis]
#     tail -f /path/to/logfile        # Monitor execution
#     
#     [Common Issues]
#     - Issue 1: Diagnostic steps and solution
#     - Issue 2: Diagnostic steps and solution
#
# 🔗 INTEGRATION POINTS:
#     [Related Scripts]
#     - dependent-script.sh: Dependency relationship
#     - related-script.sh: Integration pattern
#     
#     [External Services]
#     - Service API: Integration method and requirements
#     - Database: Connection and access patterns
#
# 📊 PERFORMANCE:
#     [Execution Time]
#     - Typical Runtime: X minutes for Y operations
#     - Large Scale: Performance characteristics at scale
#     
#     [Resource Usage]
#     - CPU Usage: Expected CPU consumption
#     - Memory Usage: Expected memory requirements
#     - Network Usage: Expected network traffic
#
# 🛡️ SECURITY CONSIDERATIONS:
#     [Sensitive Data]
#     - Credential Handling: How secrets are managed
#     - Output Sanitization: What data is logged/exposed
#     
#     [Access Control]
#     - Required Permissions: System-level permissions needed
#     - Network Security: Security implications of network calls
#
# 📚 REFERENCES:
#     [Documentation]
#     - Related Guide: docs/RELATED_GUIDE.md
#     - API Documentation: Link to API docs
#     
#     [External Resources]
#     - Tool Documentation: Link to external tool docs
#     - Standards: Link to relevant standards or RFCs
#
# Authors: BookVerse Platform Team
# Version: 1.0.0
# Last Updated: $(date +%Y-%m-%d)
# =============================================================================

# Exit on any error for safety
set -euo pipefail

# Script metadata for operational use
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_VERSION="1.0.0"
readonly LOG_FILE="${LOG_FILE:-${SCRIPT_DIR}/${SCRIPT_NAME%.sh}.log}"

# Logging configuration
readonly LOG_LEVEL="${LOG_LEVEL:-INFO}"  # DEBUG, INFO, WARN, ERROR
readonly DEBUG="${DEBUG:-false}"

# Script-specific configuration
readonly DEFAULT_TIMEOUT="${TIMEOUT:-300}"
readonly DEFAULT_RETRIES="${RETRIES:-3}"
```

---

## 🔧 Function Documentation Template

Every function within a script should be documented using this template:

```bash
#######################################
# [Brief one-line description of function purpose]
#
# This function [detailed description of functionality and business purpose].
# [Context about when and why this function is used].
# [Integration points with other functions or external systems].
#
# 🎯 Purpose:
#   [Detailed explanation of function's role in the larger workflow]
#   [Business logic and decision-making responsibilities]
#   [Error handling and validation responsibilities]
#
# 🔧 Implementation:
#   [Technical approach and algorithms used]
#   [Key dependencies and external service interactions]
#   [Performance considerations and optimization techniques]
#
# Globals:
#   GLOBAL_VAR - Description of global variable usage
#   READ_ONLY_VAR - Description of read-only global access
#
# Arguments:
#   $1 - Parameter name: Detailed description and expected format
#   $2 - Parameter name: Detailed description with examples [optional]
#   $3 - Parameter name: Detailed description [default: value]
#
# Outputs:
#   Writes [description] to stdout
#   Writes [error description] to stderr
#   Creates [file description] at [path]
#
# Returns:
#   0 - Success: Description of successful completion state
#   1 - Error: Description of general failure conditions
#   2 - Validation Error: Description of input validation failures
#   3 - External Error: Description of external service failures
#
# Examples:
#   # Basic usage
#   my_function "param1" "param2"
#   
#   # Advanced usage with error handling
#   if my_function "param1" "param2" "optional_param"; then
#     echo "Success: Function completed successfully"
#   else
#     echo "Error: Function failed with code $?"
#   fi
#   
#   # Usage in pipeline
#   my_function "input" | process_output | handle_results
#
# Error Handling:
#   - Input validation with clear error messages
#   - External service failure detection and reporting
#   - Resource cleanup in failure scenarios
#   - Logging of all error conditions for debugging
#
# Performance:
#   - Typical execution time: X seconds for Y operations
#   - Memory usage: Expected memory consumption
#   - Network calls: Number and type of external requests
#
# Security:
#   - Input sanitization for security vulnerabilities
#   - Credential handling and protection measures
#   - Output sanitization to prevent information disclosure
#######################################
my_function() {
    # Function implementation with comprehensive error handling
    local param1="${1:?ERROR: Parameter 1 is required}"
    local param2="${2:?ERROR: Parameter 2 is required}"  
    local param3="${3:-default_value}"
    
    # Input validation
    if [[ -z "$param1" ]]; then
        log_error "Invalid input: param1 cannot be empty"
        return 1
    fi
    
    # Implementation logic with logging
    log_info "Executing function with params: $param1, $param2"
    
    # Error handling example
    if ! external_command "$param1" "$param2"; then
        log_error "External command failed for params: $param1, $param2"
        return 2
    fi
    
    log_info "Function completed successfully"
    return 0
}
```

---

## 📊 Script Categories and Standards

### **🚀 Setup and Initialization Scripts**
**Purpose**: Platform provisioning, environment setup, and initial configuration

**Additional Documentation Requirements**:
- **Idempotency**: How the script handles repeated execution
- **State Management**: What state is tracked and how
- **Rollback Procedures**: How to undo changes if setup fails
- **Validation**: How to verify successful setup

**Example Categories**:
- `create_project.sh` - JFrog project and repository creation
- `setup_oidc.sh` - OIDC trust relationship configuration
- `validate_environment.sh` - Environment validation and verification

### **🔧 Operational and Maintenance Scripts**
**Purpose**: Ongoing platform management, monitoring, and maintenance

**Additional Documentation Requirements**:
- **Scheduling**: When and how often the script should run
- **Monitoring**: What metrics and logs are generated
- **Alerting**: What conditions trigger alerts or notifications
- **Cleanup**: What temporary resources are cleaned up

**Example Categories**:
- `bookverse-demo.sh` - Primary demo execution interface
- `cleanup-*.sh` - Resource cleanup and maintenance
- `monitor-*.sh` - Health checking and validation

### **🧪 Testing and Validation Scripts**
**Purpose**: Quality assurance, testing, and system validation

**Additional Documentation Requirements**:
- **Test Coverage**: What aspects of the system are tested
- **Pass/Fail Criteria**: Clear success and failure definitions
- **Test Data**: What test data is used and how it's managed
- **Reporting**: How test results are captured and reported

**Example Categories**:
- `test-bulletproof-setup.sh` - End-to-end validation testing
- `validate-*.sh` - Component and integration validation
- `integration-test-*.sh` - Cross-service integration testing

### **🔄 CI/CD and Automation Scripts**
**Purpose**: Continuous integration, deployment, and automation workflows

**Additional Documentation Requirements**:
- **Trigger Conditions**: What events trigger script execution
- **Pipeline Integration**: How the script fits into CI/CD workflows
- **Artifact Management**: What artifacts are produced or consumed
- **Environment Promotion**: How artifacts move between environments

**Example Categories**:
- `promote-*.sh` - Artifact promotion between stages
- `deploy-*.sh` - Deployment automation scripts
- `release-*.sh` - Release management automation

### **⚙️ Configuration and Setup Scripts**
**Purpose**: System configuration, credential management, and environment setup

**Additional Documentation Requirements**:
- **Configuration Sources**: Where configuration is read from
- **Secret Management**: How sensitive data is handled
- **Environment Variables**: What environment variables are used
- **Validation**: How configuration is validated

**Example Categories**:
- `configure-*.sh` - System and service configuration
- `setup-secrets.sh` - Credential and secret management
- `update-config.sh` - Configuration updates and changes

---

## 🛠️ Logging and Error Handling Standards

### **Logging Functions**
Every script should include comprehensive logging functions:

```bash
#######################################
# Logging functions for consistent output formatting and debugging
#######################################

# Color constants for output formatting
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Logging function that writes to both stdout and log file
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local log_entry="[$timestamp] [$level] $message"
    
    # Write to log file if configured
    if [[ -n "${LOG_FILE:-}" ]]; then
        echo "$log_entry" >> "$LOG_FILE"
    fi
    
    # Write to stdout with color formatting
    case "$level" in
        "ERROR")   echo -e "${RED}❌ $message${NC}" >&2 ;;
        "WARN")    echo -e "${YELLOW}⚠️  $message${NC}" ;;
        "INFO")    echo -e "${GREEN}ℹ️  $message${NC}" ;;
        "DEBUG")   [[ "$DEBUG" == "true" ]] && echo -e "${PURPLE}🔍 $message${NC}" ;;
        "SUCCESS") echo -e "${GREEN}✅ $message${NC}" ;;
        *)         echo -e "${BLUE}📝 $message${NC}" ;;
    esac
}

# Convenience logging functions
log_error() { log_message "ERROR" "$1"; }
log_warn() { log_message "WARN" "$1"; }
log_info() { log_message "INFO" "$1"; }
log_debug() { log_message "DEBUG" "$1"; }
log_success() { log_message "SUCCESS" "$1"; }

# Error handling with cleanup
handle_error() {
    local exit_code="$1"
    local line_number="$2"
    local command="$3"
    
    log_error "Script failed at line $line_number with exit code $exit_code"
    log_error "Failed command: $command"
    
    # Perform cleanup if cleanup function exists
    if declare -f cleanup_on_error >/dev/null; then
        log_info "Performing cleanup operations..."
        cleanup_on_error
    fi
    
    exit "$exit_code"
}

# Set up error handling
trap 'handle_error $? $LINENO "$BASH_COMMAND"' ERR
```

### **Error Handling Patterns**

```bash
#######################################
# Comprehensive error handling patterns for robust script execution
#######################################

# Parameter validation
validate_parameters() {
    if [[ $# -lt 2 ]]; then
        log_error "Usage: $SCRIPT_NAME <required_param1> <required_param2> [optional_param3]"
        log_error "Example: $SCRIPT_NAME 'value1' 'value2'"
        return 1
    fi
    
    # Validate parameter formats
    if [[ ! "$1" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        log_error "Invalid parameter format: $1 (must contain only alphanumeric characters, underscores, and hyphens)"
        return 1
    fi
}

# External command execution with retry logic
execute_with_retry() {
    local command="$1"
    local max_attempts="${2:-$DEFAULT_RETRIES}"
    local delay="${3:-5}"
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        log_debug "Executing command (attempt $attempt/$max_attempts): $command"
        
        if eval "$command"; then
            log_success "Command executed successfully: $command"
            return 0
        else
            local exit_code=$?
            log_warn "Command failed (attempt $attempt/$max_attempts): $command (exit code: $exit_code)"
            
            if [[ $attempt -lt $max_attempts ]]; then
                log_info "Retrying in $delay seconds..."
                sleep "$delay"
                ((attempt++))
                delay=$((delay * 2))  # Exponential backoff
            else
                log_error "Command failed after $max_attempts attempts: $command"
                return $exit_code
            fi
        fi
    done
}

# Resource cleanup function
cleanup_on_error() {
    log_info "Cleaning up temporary resources..."
    
    # Remove temporary files
    if [[ -n "${TEMP_DIR:-}" && -d "$TEMP_DIR" ]]; then
        log_debug "Removing temporary directory: $TEMP_DIR"
        rm -rf "$TEMP_DIR"
    fi
    
    # Kill background processes
    if [[ -n "${BACKGROUND_PID:-}" ]]; then
        log_debug "Terminating background process: $BACKGROUND_PID"
        kill "$BACKGROUND_PID" 2>/dev/null || true
    fi
    
    log_info "Cleanup completed"
}

# Graceful shutdown handler
graceful_shutdown() {
    log_info "Received shutdown signal, performing graceful shutdown..."
    cleanup_on_error
    log_info "Shutdown completed"
    exit 0
}

# Set up signal handlers
trap graceful_shutdown SIGTERM SIGINT
```

---

## 📋 Configuration Management Standards

### **Environment Variable Documentation**
All environment variables should be documented with this format:

```bash
#######################################
# Environment variable configuration and validation
#######################################

# Required environment variables with validation
declare -r REQUIRED_VARS=(
    "JFROG_URL:JFrog Platform URL (e.g., https://company.jfrog.io)"
    "JFROG_ADMIN_TOKEN:JFrog admin token for API access"
    "GITHUB_ORG:GitHub organization name for repository operations"
)

# Optional environment variables with defaults
declare -r OPTIONAL_VARS=(
    "PROJECT_KEY:Project identifier [default: bookverse]"
    "LOG_LEVEL:Logging verbosity level [default: INFO]"
    "TIMEOUT:Operation timeout in seconds [default: 300]"
    "RETRIES:Number of retry attempts [default: 3]"
)

# Validate required environment variables
validate_environment() {
    local missing_vars=()
    
    for var_def in "${REQUIRED_VARS[@]}"; do
        local var_name="${var_def%%:*}"
        local var_desc="${var_def#*:}"
        
        if [[ -z "${!var_name:-}" ]]; then
            missing_vars+=("$var_name - $var_desc")
        fi
    done
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        log_error "Missing required environment variables:"
        for var in "${missing_vars[@]}"; do
            log_error "  - $var"
        done
        return 1
    fi
    
    log_success "All required environment variables are set"
    return 0
}

# Load configuration with defaults
load_configuration() {
    # Set defaults for optional variables
    export PROJECT_KEY="${PROJECT_KEY:-bookverse}"
    export LOG_LEVEL="${LOG_LEVEL:-INFO}"
    export TIMEOUT="${TIMEOUT:-300}"
    export RETRIES="${RETRIES:-3}"
    export DEBUG="${DEBUG:-false}"
    
    # Validate configuration
    validate_environment || return 1
    
    # Log configuration (without sensitive values)
    log_info "Configuration loaded:"
    log_info "  - Project Key: $PROJECT_KEY"
    log_info "  - Log Level: $LOG_LEVEL"
    log_info "  - Timeout: ${TIMEOUT}s"
    log_info "  - Retries: $RETRIES"
    log_info "  - Debug Mode: $DEBUG"
    
    return 0
}
```

---

## 🧪 Testing and Validation Standards

### **Testing Framework Integration**
Scripts should include testing capabilities:

```bash
#######################################
# Testing and validation framework for script verification
#######################################

# Test execution framework
run_tests() {
    local test_count=0
    local passed_count=0
    local failed_tests=()
    
    log_info "Starting test execution..."
    
    # Discover and run all test functions
    for func in $(declare -F | grep "test_" | awk '{print $3}'); do
        ((test_count++))
        log_info "Running test: $func"
        
        if "$func"; then
            ((passed_count++))
            log_success "✅ Test passed: $func"
        else
            failed_tests+=("$func")
            log_error "❌ Test failed: $func"
        fi
    done
    
    # Report test results
    log_info "Test execution completed:"
    log_info "  - Total tests: $test_count"
    log_info "  - Passed: $passed_count"
    log_info "  - Failed: $((test_count - passed_count))"
    
    if [[ ${#failed_tests[@]} -gt 0 ]]; then
        log_error "Failed tests:"
        for test in "${failed_tests[@]}"; do
            log_error "  - $test"
        done
        return 1
    fi
    
    log_success "All tests passed successfully!"
    return 0
}

# Example test function
test_environment_validation() {
    log_debug "Testing environment validation..."
    
    # Save current environment
    local original_jfrog_url="${JFROG_URL:-}"
    
    # Test missing required variable
    unset JFROG_URL
    if validate_environment; then
        log_error "Expected validation to fail with missing JFROG_URL"
        return 1
    fi
    
    # Restore environment
    export JFROG_URL="$original_jfrog_url"
    
    # Test successful validation
    if ! validate_environment; then
        log_error "Expected validation to pass with all variables set"
        return 1
    fi
    
    log_debug "Environment validation test passed"
    return 0
}

# Performance testing
test_performance() {
    log_debug "Testing script performance..."
    
    local start_time=$(date +%s.%N)
    
    # Execute performance-critical function
    critical_function_under_test
    
    local end_time=$(date +%s.%N)
    local execution_time=$(echo "$end_time - $start_time" | bc)
    
    # Validate performance within acceptable limits
    if (( $(echo "$execution_time > 30.0" | bc -l) )); then
        log_error "Performance test failed: execution time $execution_time seconds exceeds 30 second limit"
        return 1
    fi
    
    log_debug "Performance test passed: execution time $execution_time seconds"
    return 0
}
```

---

## 📊 Examples and Templates

### **Complete Script Example**

```bash
#!/usr/bin/env bash
# =============================================================================
# BookVerse Platform - Setup Automation - Project Creation Script
# =============================================================================
#
# Creates and configures a new JFrog project with repositories and lifecycle stages
#
# 🎯 PURPOSE:
#     This script automates the creation of JFrog projects for the BookVerse platform,
#     including repository setup, lifecycle stage configuration, and permission management.
#     It serves as the foundation for all subsequent platform provisioning activities.
#
# 🏗️ ARCHITECTURE:
#     - REST API integration with JFrog Platform
#     - Idempotent operations with conflict detection and resolution
#     - Comprehensive validation and error recovery mechanisms
#     - JSON payload construction with template-based configuration
#
# [... rest of comprehensive header ...]

set -euo pipefail

# Script configuration
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly CONFIG_FILE="${SCRIPT_DIR}/config.sh"

# Source common utilities
if [[ -f "${SCRIPT_DIR}/common.sh" ]]; then
    # shellcheck source=common.sh
    source "${SCRIPT_DIR}/common.sh"
else
    echo "ERROR: Required file common.sh not found in $SCRIPT_DIR" >&2
    exit 1
fi

# Main execution function
main() {
    log_info "Starting project creation: $PROJECT_KEY"
    
    # Validate environment and parameters
    load_configuration || exit 1
    validate_parameters "$@" || exit 1
    
    # Execute main workflow
    create_jfrog_project || exit 1
    configure_project_settings || exit 1
    validate_project_creation || exit 1
    
    log_success "Project creation completed successfully: $PROJECT_KEY"
    return 0
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
```

This comprehensive documentation standard ensures that every shell script in the BookVerse platform is self-documenting, maintainable, and provides the rich context needed for effective platform operations.

---

## 📚 References

- **Shell Style Guide**: Follow Google Shell Style Guide for code formatting
- **Documentation Standards**: Align with BookVerse documentation principles
- **Security Guidelines**: Follow OWASP security best practices for scripts
- **Testing Standards**: Integrate with platform testing and validation frameworks

Authors: BookVerse Platform Team  
Version: 1.0.0  
Last Updated: 2024-01-01
