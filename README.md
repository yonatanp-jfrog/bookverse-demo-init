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
`bookverse-inventory`, `bookverse-recommendations`, `bookverse-checkout`, `bookverse-platform`, `bookverse-demo-init`.

## 🔐 GitHub PAT for repository_dispatch (Option A)

For the platform webhook flow, the `bookverse-platform` service needs to call GitHub `repository_dispatch` on `bookverse-helm`. For the demo, we use a fine-grained Personal Access Token (PAT). Create it once, then pass it to the init so it can be validated and stored as a secret.

### 1) Create a fine‑grained PAT

Follow these steps in GitHub (first time only):

1. Sign in to GitHub with the account that owns or has access to the `bookverse-helm` repository (a bot account is ideal).
2. Go to: Profile menu → Settings → Developer settings → Personal access tokens → Fine-grained tokens → Generate new token.
3. Name: "BookVerse Helm Dispatch (platform)".
4. Expiration: pick an expiration (e.g., 90 days). For demo convenience only, you may choose "No expiration" (not recommended for production).
5. Resource owner: choose your organization or user that owns `bookverse-helm`.
6. Repository access: "Only select repositories" → select `bookverse-helm`.
7. Repository permissions: set "Contents" to "Read and write". Leave others as default. Only add "Actions: Read and write" if your workflow actually needs it.
8. Click "Generate token" and copy the token value. Store it securely.

We will refer to this value as `GH_REPO_DISPATCH_TOKEN`.

### 2) Provide the token to the init flow

Before running the init, export the token as an environment variable so scripts can read and validate it:

```bash
export GH_REPO_DISPATCH_TOKEN="<paste your fine-grained PAT here>"
```

Optionally, set it as a GitHub repository secret for the `bookverse-platform` repo to enable CI-based validation:

```bash
# Requires GitHub CLI (gh) authenticated as a user with repo admin rights
gh secret set GH_REPO_DISPATCH_TOKEN --repo yonatanp-jfrog/bookverse-platform < <(echo -n "$GH_REPO_DISPATCH_TOKEN")
```

Create a Kubernetes Secret for the platform service so it can call `repository_dispatch` at runtime:

```bash
kubectl -n bookverse create secret generic platform-repo-dispatch \
  --from-literal=GITHUB_TOKEN="$GH_REPO_DISPATCH_TOKEN"
```

If you re-run, use `kubectl -n bookverse delete secret platform-repo-dispatch` first, or add `--dry-run=client -o yaml | kubectl apply -f -` to make it idempotent.

### 3) Validate the token (dry‑run dispatch)

Run a one-shot validation to ensure the token can dispatch to `bookverse-helm`:

```bash
curl -i \
  -H "Authorization: Bearer $GH_REPO_DISPATCH_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  https://api.github.com/repos/yonatanp-jfrog/bookverse-helm/dispatches \
  -d '{
        "event_type": "release_completed",
        "client_payload": { "dry_run": true, "source": "init-validate" }
      }'
# Expect: HTTP/1.1 204 No Content
```

If you see 401/403, verify the token is fine‑grained, scoped only to `bookverse-helm`, and has "Contents: Read and write" permission.

### 4) Init and job summary behavior

- The init flow should fail fast if `GH_REPO_DISPATCH_TOKEN` is missing or empty.
- During validation, it can write a short summary to the GitHub job summary (if running in Actions):

```bash
if [[ -z "${GH_REPO_DISPATCH_TOKEN:-}" ]]; then
  echo "❌ Missing GH_REPO_DISPATCH_TOKEN"; exit 1
fi
RESP=$(curl -s -o /dev/null -w '%{http_code}' \
  -H "Authorization: Bearer ${GH_REPO_DISPATCH_TOKEN}" \
  -H "Accept: application/vnd.github+json" \
  https://api.github.com/repos/yonatanp-jfrog/bookverse-helm/dispatches \
  -d '{"event_type":"release_completed","client_payload":{"dry_run":true,"source":"init-validate"}}')
if [[ "$RESP" == "204" ]]; then
  STATUS="✅ Token validated (204)"
else
  STATUS="❌ Token validation failed ($RESP)"
fi
{
  echo '### GitHub PAT Validation';
  echo "";
  echo "- Result: $STATUS";
  echo "- Repository: yonatanp-jfrog/bookverse-helm";
  echo "- Event: repository_dispatch platform_release_completed";
} >> "$GITHUB_STEP_SUMMARY"
[[ "$RESP" == "204" ]] || exit 1
```

With the token created and validated, you can proceed to run the initialization steps. The platform webhook handler will use this token (mounted from the Kubernetes Secret) to create `repository_dispatch` events when it receives the AppTrust `release_completed` webhook.

### 📦 Provision Artifactory Repositories (Steady State)

Provision the required repositories once during initialization using the setup script (CI will not create repos dynamically):

```bash
cd bookverse-demo-init/.github/scripts/setup
export JFROG_URL="https://your-jfrog-instance.com"
export JFROG_ADMIN_TOKEN="your-admin-token"
export PROJECT_KEY=bookverse
./create_repositories.sh
# Optionally create dependency repos and pre-populate caches:
./create_dependency_repos.sh
./prepopulate_dependencies.sh
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

### Identity Mappings (OIDC) — Discovery and Cleanup

Project deletion can fail if OIDC identity mappings still reference the project (e.g., provider- or repo-scoped claims containing the project key). Use the script below to discover and remove such mappings before deleting the project.

```bash
# Discover identity mappings related to a project
export JFROG_URL="https://your-jfrog-instance.com"
export JFROG_ADMIN_TOKEN="your-admin-token"
python scripts/identity_mappings.py discover --project bookverse

# Cleanup related mappings (dry run)
python scripts/identity_mappings.py cleanup --project bookverse --dry-run

# Cleanup related mappings (execute)
python scripts/identity_mappings.py cleanup --project bookverse

# Then delete the project
curl -X DELETE "${JFROG_URL}/access/api/v1/projects/bookverse" \
  --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}"
```

In GitHub Actions, the script writes a concise section to `$GITHUB_STEP_SUMMARY` under headings:
- "Identity Mappings (Discovery)"
- "Identity Mappings (Cleanup)"

### Project Roles — Discovery and Cleanup

Project-scoped roles created by the demo should be removed before deleting the project. Built-in roles are skipped automatically.

```bash
# Discover project roles
export JFROG_URL="https://your-jfrog-instance.com"
export JFROG_ADMIN_TOKEN="your-admin-token"
python scripts/project_roles.py discover --project bookverse

# Cleanup project roles created by the demo (dry run)
python scripts/project_roles.py cleanup --project bookverse --dry-run --role-prefix bookverse-

# Cleanup project roles created by the demo (execute)
python scripts/project_roles.py cleanup --project bookverse --role-prefix bookverse-
```

The script writes a concise section to `$GITHUB_STEP_SUMMARY` under headings:
- "Project Roles (Discovery)"
- "Project Roles (Cleanup)"

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
- Delete OIDC identity mappings that reference the project (use `scripts/identity_mappings.py`)
- Delete non-built-in project roles for the project (use `scripts/project_roles.py`)

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

### 🧭 Kubernetes & Argo CD (Local, PROD-only)

For a complete clean‑slate bootstrap of a local Kubernetes cluster with Argo CD managing only the PROD environment, see `docs/K8S_ARGO_BOOTSTRAP.md`.
