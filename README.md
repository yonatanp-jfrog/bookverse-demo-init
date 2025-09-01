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
- JFrog Platform access with admin privileges
- `curl` and `jq` installed
- Bash shell

### Environment Variables
```bash
export JFROG_URL="https://your-jfrog-instance.com"
export JFROG_ADMIN_TOKEN="your-admin-token"
```

### GitHub Actions Variables (CI/CD bootstrap)

Set common variables across all BookVerse repos (requires a GitHub token with repo scope):

```bash
export GH_TOKEN=ghp_your_token
export ORG=your-org              # optional; falls back to user if unset
export PROJECT_KEY=bookverse
export JFROG_URL=https://your-jfrog-instance.com
export DOCKER_REGISTRY=registry.example.com/bookverse
bash scripts/set_actions_vars.sh
```

This will set `PROJECT_KEY`, `JFROG_URL`, and `DOCKER_REGISTRY` as Actions variables in:
`bookverse-inventory`, `bookverse-recommendations`, `bookverse-checkout`, `bookverse-platform`, `bookverse-demo-assets`.

### 📦 Provision Artifactory Repositories (Steady State)

Provision the required repositories once during initialization using the setup script (CI will not create repos dynamically):

```bash
cd bookverse-demo-init/.github/scripts/setup
export JFROG_URL="https://your-jfrog-instance.com"
export JFROG_ADMIN_TOKEN="your-admin-token"
export PROJECT_KEY=bookverse
./create_repositories.sh
```

Creates/ensures (among others):
- `${PROJECT_KEY}-generic-internal-local`
- `${PROJECT_KEY}-helm-helm-internal-local`
- `${PROJECT_KEY}-{service}-docker-internal-local` for `inventory`, `recommendations`, `checkout`, `platform`, `web`

### 🔄 Switch Platform

To switch to a different JFrog Platform instance:

#### Option 1: GitHub Actions Workflow (Recommended)
1. Go to Actions → "🔄 Switch Platform"
2. Provide new platform URL and admin token
3. Type `SWITCH` to confirm
4. All repositories updated automatically

#### Option 2: Interactive Script
```bash
./scripts/switch_jfrog_platform_interactive.sh
```

See [SWITCH_JFROG_PLATFORM.md](docs/SWITCH_JFROG_PLATFORM.md) for detailed instructions.

## 🔑 Evidence Key Management

### Replace Evidence Keys
Replace evidence keys across all BookVerse repositories with custom key pairs:

1. Generate key pair locally:
   ```bash
   # ED25519 (Recommended)
   openssl genpkey -algorithm ed25519 -out private.pem
   openssl pkey -in private.pem -pubout -out public.pem
   
   # RSA 2048-bit
   openssl genrsa -out private.pem 2048
   openssl rsa -in private.pem -pubout -out public.pem
   
   # Elliptic Curve (secp256r1)
   openssl ecparam -name secp256r1 -genkey -noout -out private.pem
   openssl ec -in private.pem -pubout > public.pem
   ```

2. Go to **Actions** → **Replace Evidence Keys**
3. Paste the private and public key contents
4. The workflow will update all repositories and JFrog Platform

See [REPLACE_EVIDENCE_KEYS.md](docs/REPLACE_EVIDENCE_KEYS.md) for detailed instructions.

### Easy Verbosity Control with Wrapper Scripts

For convenience, we've created wrapper scripts that automatically set the correct verbosity level:

#### Silent Execution (No Output)
```bash
./init_silent.sh
# Runs completely silently, only shows success/failure at the end
```

#### Normal Feedback (Default)
```bash
./init_feedback.sh
# Shows progress and results, no interaction needed
```

#### Interactive Debug
```bash
./init_debug.sh
# Shows each command, asks for confirmation, displays full output
```

### Manual Verbosity Control

You can also set verbosity manually and run the main script:

```bash
# Silent mode
export VERBOSITY=0
./init_local.sh

# Feedback mode (default)
export VERBOSITY=1
./init_local.sh

# Debug mode
export VERBOSITY=2
./init_local.sh
```

## 🎛️ Verbosity Control

All scripts now include a **verbosity control system** for flexible output management.

### Set Verbosity Level

Set the `VERBOSITY` environment variable:

```bash
# Silent mode - no output, just execute
export VERBOSITY=0

# Feedback mode - show progress and results (default)
export VERBOSITY=1

# Debug mode - show commands, confirmations, and full output
export VERBOSITY=2
```

### Verbosity Levels

#### Level 0: Silent Mode
- 🔇 **No output** will be shown
- 🚀 **Commands execute silently**
- ❌ **Only errors** will be displayed
- 🤖 **Perfect for automation** and CI/CD pipelines

#### Level 1: Feedback Mode (Default)
- 📢 **Progress and results** will be shown
- 🔧 **Commands execute automatically**
- ✅ **No user interaction** required
- 📊 **Summary information** displayed

#### Level 2: Debug Mode
- 🐛 **Each step shown** before execution
- 🔍 **Commands displayed verbosely**
- ⏸️ **User confirmation** required for each step
- 📋 **Full output** from all commands
- 🛠️ **Perfect for troubleshooting** and development

### Usage Examples

#### Silent Execution (Automation)
```bash
export VERBOSITY=0
./init_local.sh
# Runs completely silently, only shows errors
```

#### Normal Feedback (Default)
```bash
export VERBOSITY=1
./init_local.sh
# Shows progress and results, no interaction needed
```

#### Interactive Debug
```bash
export VERBOSITY=2
./init_local.sh
# Shows each command, asks for confirmation, displays full output
```

### What You'll See in Each Mode

#### Silent Mode (VERBOSITY=0)
```
🚀 BookVerse JFrog Platform Initialization - Local Runner
========================================================
🔇 SILENT MODE ENABLED
   - No output will be shown
   - Commands will execute silently
   - Only errors will be displayed

✅ Environment variables validated
📋 Configuration loaded
🔄 Starting initialization sequence...
[Silent execution - no further output until completion or error]
```

#### Feedback Mode (VERBOSITY=1)
```
🚀 BookVerse JFrog Platform Initialization - Local Runner
========================================================
📢 FEEDBACK MODE ENABLED
   - Progress and results will be shown
   - Commands will execute automatically
   - No user interaction required

✅ Environment variables validated
📋 Configuration loaded
🔄 Starting initialization sequence...

📁 Step 1/7: Creating Project...
   🔧 Creating BookVerse project...
   ✅ Creating BookVerse project completed
   📊 Step 1 Summary: Project creation process completed

🎭 Step 2/7: Creating AppTrust Stages...
   🔧 Creating bookverse-DEV stage...
   ✅ Creating bookverse-DEV stage completed
   🔧 Creating bookverse-QA stage...
   ✅ Creating bookverse-QA stage completed
   [Continues with progress updates...]
```

#### Debug Mode (VERBOSITY=2)
```
🚀 BookVerse JFrog Platform Initialization - Local Runner
========================================================
🐛 DEBUG MODE ENABLED
   - Each step will be shown before execution
   - Commands will be displayed verbosely
   - User confirmation required for each step
   - Full output will be shown

✅ Environment variables validated
📋 Configuration loaded
🔄 Starting initialization sequence...

📁 Step 1/7: Creating Project...
🔍 DEBUG MODE: Create BookVerse project
   Command to execute:
   curl -v -w 'HTTP_CODE: %{http_code}' --header 'Authorization: Bearer ***' ...

   Press Enter to execute this command, or 'q' to quit: 

   🚀 Executing command...
   =========================================
   [Full curl output with headers, request, response]
   =========================================
   ✅ Command completed.

   Press Enter to continue to next step: 
```

### Use Cases for Each Level

#### VERBOSITY=0 (Silent)
- **CI/CD Pipelines** - Automated execution
- **Background Scripts** - Non-interactive runs
- **Bulk Operations** - When you don't need feedback
- **Testing** - Focus on results, not process

#### VERBOSITY=1 (Feedback) - **Recommended for Most Users**
- **Daily Development** - See what's happening
- **Troubleshooting** - Understand progress
- **Learning** - Follow the process
- **Production** - Balanced output

#### VERBOSITY=2 (Debug)
- **Development** - Step-by-step debugging
- **Troubleshooting** - See exact commands and responses
- **Learning** - Understand every detail
- **Testing** - Verify individual steps

## 🧹 Cleanup

### Local Cleanup
```bash
# Interactive cleanup with confirmation
./cleanup_local.sh

# Debug mode cleanup
export VERBOSITY=2
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
