# BookVerse DevOps

Reusable GitHub Actions workflows for BookVerse services.

## Purpose
Consolidates 6,617+ lines of duplicated CI/CD code into reusable workflows.

## Workflows
- shared-build.yml: Build, test, publish
- shared-promote.yml: Promotion pipeline

## Usage
```yaml
jobs:
  build:
    uses: bookverse-org/bookverse-devops/.github/workflows/shared-build.yml@main
    with:
      service-name: inventory
    secrets: inherit
```

Reduces service CI/CD from 1,500+ lines to ~150 lines.
