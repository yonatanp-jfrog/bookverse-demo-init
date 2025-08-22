# BookVerse Demo - JFrog Platform Initialization

This repository contains scripts to automatically set up a complete JFrog Platform environment for the BookVerse demo, which is a SaaS solution comprising three microservices (Inventory, Recommendation, Checkout) and a combined Platform solution.

## 🏗️ Architecture Overview

### Microservices
- **Inventory Service**: Manages book inventory and availability
- **Recommendations Service**: AI-powered book recommendations
- **Checkout Service**: Handles purchase transactions
- **Platform Solution**: Combined solution for enterprise customers

### JFrog Platform Components
- **Artifactory**: 16 repositories (4 services × 2 package types × 2 stages)
- **AppTrust**: 4 applications with lifecycle management
- **Access Control**: 12 users with role-based permissions
- **OIDC Integration**: Secure GitHub Actions authentication

## 🚀 Quick Start

### Prerequisites
- JFrog Platform access with admin privileges
- JFrog admin token
- Bash shell environment

### Environment Variables
```bash
export JFROG_URL="https://your-instance.jfrog.io/"
export JFROG_ADMIN_TOKEN="your-admin-token"
```

### Local Setup
```bash
# Run the complete initialization locally
./init_local.sh

# Or run individual steps
source .github/scripts/setup/config.sh
./.github/scripts/setup/create_project.sh
./.github/scripts/setup/create_repositories.sh
./.github/scripts/setup/create_stages.sh
./.github/scripts/setup/create_users.sh
./.github/scripts/setup/create_applications.sh
./.github/scripts/setup/create_oidc.sh
```

### GitHub Actions Setup
1. Set repository variables:
   - `JFROG_URL`: Your JFrog Platform URL
2. Set repository secrets:
   - `JFROG_ADMIN_TOKEN`: Your JFrog admin token
3. Run the workflow manually with `action: setup`

## 🧹 Cleanup

### Local Cleanup
```bash
# Clean up the entire BookVerse project
./cleanup_local.sh
```

### GitHub Actions Cleanup
1. Run the workflow manually with `action: cleanup`
2. This will remove all resources and delete the project

### Manual Cleanup
```bash
# Run the cleanup script from the setup directory
./.github/scripts/setup/cleanup.sh
```

## 📋 What Gets Created

### Projects
- **bookverse**: Main project containing all resources

### Repositories (16 total)
- **Internal repositories** (DEV/QA/STAGE stages):
  - `bookverse-{service}-{package}-internal-local`
- **Release repositories** (PROD stage):
  - `bookverse-{service}-{package}-release-local`

### Stages
- **bookverse-DEV**: Development stage
- **bookverse-QA**: Quality assurance stage  
- **bookverse-STAGE**: Staging stage
- **PROD**: Global production stage (always present)

### Users (12 total)
- **Human Users**: 8 users with specific roles
- **Pipeline Users**: 4 users for CI/CD automation

### Applications
- **bookverse-inventory**: Inventory service application
- **bookverse-recommendations**: Recommendations service application
- **bookverse-checkout**: Checkout service application
- **bookverse-platform**: Platform solution application

### OIDC Integrations
- **bookverse-inventory-team**: Inventory team OIDC
- **bookverse-recommendations-team**: Recommendations team OIDC
- **bookverse-checkout-team**: Checkout team OIDC
- **bookverse-platform-team**: Platform team OIDC

## 🔐 Role Mapping

| Business Role | JFrog Role | Access Level |
|---------------|------------|--------------|
| Developer | Developer | Basic project access |
| Release Manager | Release Manager | Release management |
| Project Manager | Project Admin | Project administration |
| AppTrust Admin | Application Admin | Full application admin |
| Pipeline User | Developer | CI/CD automation |

## 🎯 Repository Naming Convention

```
{project-key}-{service_name}-{package}-{stage}-local
```

**Examples:**
- `bookverse-inventory-docker-internal-local`
- `bookverse-recommendations-python-release-local`
- `bookverse-platform-docker-internal-local`

## ⚠️ Important Notes

- **PROD Stage**: The `PROD` stage is global and always exists - it cannot be created or deleted
- **User Accounts**: Users are not deleted during cleanup, only removed from the project
- **Global Resources**: Some resources may persist if cleanup fails
- **Confirmation Required**: Cleanup scripts require explicit confirmation

## 🔧 Troubleshooting

### Common Issues
1. **Permission Denied**: Ensure you have admin privileges
2. **Resource Not Found**: Some resources may already be deleted
3. **Network Issues**: Check JFrog URL and network connectivity

### Manual Cleanup
If automated cleanup fails, you may need to manually remove resources through the JFrog UI or contact your administrator.

## 📚 Additional Resources

- [JFrog REST API Documentation](https://jfrog.com/help/r/jfrog-rest-apis)
- [JFrog AppTrust Documentation](https://jfrog.com/help/r/jfrog-apptrust)
- [JFrog Projects Documentation](https://jfrog.com/help/r/jfrog-projects)

## 🤝 Contributing

This is a demo setup - feel free to modify and adapt for your own JFrog Platform environments.

## 📄 License

This project is provided as-is for demonstration purposes.
