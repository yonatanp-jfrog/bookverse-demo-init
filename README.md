# BookVerse JFrog Platform Demo

A comprehensive demo setup for the BookVerse microservices platform using JFrog Platform (Artifactory + AppTrust).

## 🏗️ Architecture

BookVerse is a SaaS solution comprising three microservices and a combined Platform solution:

- **Inventory Service** - Manages book inventory and availability
- **Recommendations Service** - Provides personalized book recommendations  
- **Checkout Service** - Handles purchase transactions and order processing
- **Platform Solution** - Combined solution integrating all microservices

## 🚀 Quick Start

### Prerequisites

- JFrog Platform instance (Artifactory + AppTrust)
- JFrog Admin token with full permissions
- `jq` command-line tool installed
- `curl` command-line tool installed

### Environment Variables

Set these environment variables before running the scripts:

```bash
export JFROG_URL="https://your-instance.jfrog.io"
export JFROG_ADMIN_TOKEN="your-admin-token"
```

### Setup Options

#### Option 1: Local Setup (Recommended for Development)
```bash
# Run the local initialization script
./init_local.sh

# Run the local cleanup script
./cleanup_local.sh
```

#### Option 2: GitHub Actions
- Push to main branch to trigger automatic setup
- Use GitHub Actions UI to manually trigger setup/cleanup workflows

## 🐛 Debug Mode

All scripts now include a **debug mode** for step-by-step execution and troubleshooting.

### Enable Debug Mode

Set the `DEBUG_MODE` environment variable:

```bash
# Enable debug mode
export DEBUG_MODE=true

# Run any script with debug mode
./init_local.sh
./cleanup_local.sh
```

### Debug Mode Features

When `DEBUG_MODE=true` is set:

- ✅ **Step-by-step execution** - One command at a time
- ✅ **Verbose output** - Show exact commands being run  
- ✅ **User confirmation** - Ask before each step
- ✅ **Command preview** - Show what will be executed
- ✅ **Output display** - Show full response from each command
- ✅ **Interactive control** - Press Enter to continue, 'q' to quit

### Debug Mode Example

```bash
export DEBUG_MODE=true
./init_local.sh
```

**Output:**
```
🐛 DEBUG MODE ENABLED
   - Each step will be shown before execution
   - Commands will be displayed verbosely
   - User confirmation required for each step
   - Full output will be shown

🔍 DEBUG MODE: Create BookVerse project
   Command to execute:
   curl -v -w 'HTTP_CODE: %{http_code}' --header 'Authorization: Bearer [TOKEN]' ...

   Press Enter to execute this command, or 'q' to quit: 

   🚀 Executing command...
   =========================================
   [Full curl output with headers, request, response]
   =========================================
   ✅ Command completed.

   Press Enter to continue to next step: 
```

### Use Cases for Debug Mode

- **Troubleshooting** - See exactly what's failing and why
- **Learning** - Understand each step of the process
- **Testing** - Verify individual commands before full execution
- **Development** - Debug script logic and API responses

## 🧹 Cleanup

### Local Cleanup
```bash
# Interactive cleanup with confirmation
./cleanup_local.sh

# Debug mode cleanup
export DEBUG_MODE=true
./cleanup_local.sh
```

### GitHub Actions Cleanup
- Use the cleanup workflow in GitHub Actions
- Requires typing "DELETE" to confirm

### Manual Cleanup
```bash
# Delete specific resources manually
curl -X DELETE "${JFROG_URL}/access/api/v1/projects/bookverse"
```

## 📋 What Gets Created

### Projects
- 1 JFrog Project: `bookverse`

### Stages  
- 3 Local Stages: `bookverse-DEV`, `bookverse-QA`, `bookverse-STAGING`
- 1 Global Stage: `PROD` (always present)

### Repositories
- 16 Artifactory repositories (4 services × 2 package types × 2 stages)
- Naming: `{project}-{service}-{package}-{stage}-local`

### Users
- 8 Human users with different roles
- 4 Pipeline automation users

### Applications
- 4 Microservice applications (inventory, recommendations, checkout, platform)
- Each with proper ownership and lifecycle management

### OIDC Integrations
- Secure authentication for GitHub Actions pipelines
- Team-based access control

## 🔐 Role Mapping

| Business Role | JFrog Role | Description |
|---------------|------------|-------------|
| Developer | Developer | Code development and testing |
| Release Manager | Release Manager | Release management and deployment |
| Project Manager | Project Admin | Project administration |
| AppTrust Admin | Application Admin | Application lifecycle management |

## 📝 Naming Conventions

- **Project**: `bookverse`
- **Stages**: `bookverse-{STAGE}` (DEV, QA, STAGING)
- **Repositories**: `{project}-{service}-{package}-{stage}-local`
- **Applications**: `BookVerse {Service} Service`
- **Users**: `{firstname}.{lastname}@bookverse.com`

## ⚠️ Important Notes

- **PROD stage** is system-managed and cannot be deleted
- **Cleanup is irreversible** - all data will be permanently deleted
- **Admin token required** - ensure proper permissions before running
- **Stages must be removed from lifecycle** before deletion

## 🔧 Troubleshooting

### Common Issues

#### HTTP 401 (Unauthorized)
- Check if `JFROG_ADMIN_TOKEN` is valid and not expired
- Verify token has admin permissions

#### HTTP 409 (Conflict)
- Resource already exists - this is normal for re-runs
- Scripts handle this gracefully

#### Project Deletion Fails
- Ensure all stages are removed from lifecycle first
- Delete applications, repositories, and users before project

### Debug Commands

```bash
# Check lifecycle status
curl "${JFROG_URL}/access/api/v2/lifecycle/?project_key=bookverse"

# Check project stages
curl "${JFROG_URL}/access/api/v2/stages/?project_key=bookverse"

# Check project details
curl "${JFROG_URL}/access/api/v1/projects/bookverse"
```

## 📚 Additional Resources

- [JFrog REST API Documentation](https://jfrog.com/help/r/jfrog-rest-apis)
- [JFrog CLI Documentation](https://jfrog.com/help/r/jfrog-cli)
- [AppTrust Lifecycle Management](https://jfrog.com/help/r/jfrog-apptrust-lifecycle-management)
