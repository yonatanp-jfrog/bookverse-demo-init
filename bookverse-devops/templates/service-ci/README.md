# Service CI Template

Replace your service's .github/workflows/ci.yml with this:

```yaml
name: CI
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  build:
    uses: bookverse-org/bookverse-devops/.github/workflows/shared-build.yml@main
    with:
      service-name: YOUR_SERVICE_NAME  # inventory, recommendations, checkout, etc.
      python-version: "3.11"
    secrets: inherit
```

Replace your service's .github/workflows/promote.yml with this:

```yaml
name: Promote
on:
  workflow_dispatch:
    inputs:
      target-stage:
        type: choice
        options: [QA, STAGING, PROD]
      app-version:
        required: true

jobs:
  promote:
    uses: bookverse-org/bookverse-devops/.github/workflows/shared-promote.yml@main
    with:
      service-name: YOUR_SERVICE_NAME
      source-stage: DEV
      target-stage: ${{ inputs.target-stage }}
      app-version: ${{ inputs.app-version }}
    secrets: inherit
```

## Result
- Before: 1,500+ lines of CI/CD code
- After: ~150 lines of CI/CD code
- Maintenance: Centralized in bookverse-devops
