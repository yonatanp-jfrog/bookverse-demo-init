#!/usr/bin/env bash

# =============================================================================
# DEMO DATA SEEDING SCRIPT
# =============================================================================
# Seeds sample services and artifacts for BookVerse demo flow
# Creates realistic demo data to showcase JFrog AppTrust capabilities
# =============================================================================

set -e

# Load configuration
source "$(dirname "$0")/../.github/scripts/setup/config.sh"

echo ""
echo "🌱 Seeding demo data for BookVerse platform"
echo "🔧 Project: $PROJECT_KEY"
echo "🔧 JFrog URL: $JFROG_URL"
echo ""

# Create temporary workspace
TEMP_DIR=$(mktemp -d)
echo "📁 Working directory: $TEMP_DIR"
cd "$TEMP_DIR"

# Service definitions for sample artifacts
SERVICES=("inventory" "recommendations" "checkout" "platform")

# Function to create sample Python package
create_sample_python_package() {
    local service="$1"
    local version="$2"
    
    echo "📦 Creating sample Python package for $service (v$version)"
    
    local package_dir="bookverse-${service}"
    mkdir -p "$package_dir/src/bookverse_${service}"
    cd "$package_dir"
    
    # Create setup.py
    cat > setup.py << EOF
from setuptools import setup, find_packages

setup(
    name="bookverse-${service}",
    version="${version}",
    description="BookVerse ${service} microservice",
    author="BookVerse Team",
    author_email="team@bookverse.com",
    packages=find_packages(where="src"),
    package_dir={"": "src"},
    python_requires=">=3.8",
    install_requires=[
        "fastapi>=0.68.0",
        "uvicorn>=0.15.0",
        "pydantic>=1.8.0",
        "requests>=2.25.0",
    ],
    classifiers=[
        "Development Status :: 4 - Beta",
        "Intended Audience :: Developers",
        "Topic :: Software Development :: Libraries :: Python Modules",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.8",
        "Programming Language :: Python :: 3.9",
        "Programming Language :: Python :: 3.10",
    ],
)
EOF

    # Create main module
    cat > "src/bookverse_${service}/__init__.py" << EOF
"""BookVerse ${service} microservice."""

__version__ = "${version}"
__author__ = "BookVerse Team"
__email__ = "team@bookverse.com"
EOF

    cat > "src/bookverse_${service}/main.py" << EOF
"""Main application for BookVerse ${service} service."""

from fastapi import FastAPI
from pydantic import BaseModel
import uvicorn

app = FastAPI(
    title="BookVerse ${service} Service",
    description="Microservice for ${service} management",
    version="${version}"
)

class HealthResponse(BaseModel):
    status: str
    service: str
    version: str

@app.get("/health", response_model=HealthResponse)
async def health_check():
    return HealthResponse(
        status="healthy",
        service="${service}",
        version="${version}"
    )

@app.get("/")
async def root():
    return {"message": "BookVerse ${service} Service", "version": "${version}"}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
EOF

    # Create requirements.txt
    cat > requirements.txt << EOF
fastapi>=0.68.0
uvicorn>=0.15.0
pydantic>=1.8.0
requests>=2.25.0
pytest>=6.0.0
pytest-asyncio>=0.15.0
httpx>=0.24.0
EOF

    # Create basic test
    mkdir -p tests
    cat > "tests/test_${service}.py" << EOF
"""Tests for BookVerse ${service} service."""

import pytest
from fastapi.testclient import TestClient
from bookverse_${service}.main import app

client = TestClient(app)

def test_health_check():
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert data["service"] == "${service}"
    assert data["version"] == "${version}"

def test_root():
    response = client.get("/")
    assert response.status_code == 200
    data = response.json()
    assert "BookVerse ${service} Service" in data["message"]
    assert data["version"] == "${version}"
EOF

    # Create Dockerfile
    cat > Dockerfile << EOF
FROM python:3.10-slim

WORKDIR /app

# Copy requirements first for better caching
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy source code
COPY src/ ./src/
COPY setup.py .

# Install the package
RUN pip install -e .

# Expose port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \\
    CMD curl -f http://localhost:8000/health || exit 1

# Run the application
CMD ["python", "-m", "bookverse_${service}.main"]
EOF

    # Create .gitignore
    cat > .gitignore << EOF
__pycache__/
*.py[cod]
*\$py.class
*.so
.Python
build/
develop-eggs/
dist/
downloads/
eggs/
.eggs/
lib/
lib64/
parts/
sdist/
var/
wheels/
*.egg-info/
.installed.cfg
*.egg
MANIFEST
.pytest_cache/
.coverage
htmlcov/
.tox/
.cache
nosetests.xml
coverage.xml
*.cover
.hypothesis/
.env
.venv/
venv/
ENV/
env/
EOF

    # Build Python wheel
    echo "🔧 Building Python package..."
    python setup.py sdist bdist_wheel > /dev/null 2>&1
    
    echo "✅ Created Python package: bookverse-${service} v${version}"
    cd ..
}

# Function to create sample Docker image
create_sample_docker_image() {
    local service="$1"
    local version="$2"
    
    echo "🐳 Creating sample Docker image for $service (v$version)"
    
    cd "bookverse-${service}"
    
    # Build Docker image
    local image_tag="bookverse-${service}:${version}"
    echo "🔧 Building Docker image: $image_tag"
    
    if command -v docker &> /dev/null; then
        docker build -t "$image_tag" . > /dev/null 2>&1
        echo "✅ Created Docker image: $image_tag"
        
        # Save image as tar for upload
        docker save "$image_tag" | gzip > "../${service}-${version}.tar.gz"
        echo "💾 Saved image archive: ${service}-${version}.tar.gz"
    else
        echo "⚠️  Docker not available, skipping image creation"
    fi
    
    cd ..
}

# Function to create sample SBOM
create_sample_sbom() {
    local service="$1"
    local version="$2"
    
    echo "📋 Creating sample SBOM for $service (v$version)"
    
    cat > "${service}-sbom-${version}.json" << EOF
{
  "bomFormat": "CycloneDX",
  "specVersion": "1.4",
  "serialNumber": "urn:uuid:$(uuidgen)",
  "version": 1,
  "metadata": {
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "tools": [
      {
        "vendor": "JFrog",
        "name": "AppTrust",
        "version": "1.0.0"
      }
    ],
    "component": {
      "type": "application",
      "bom-ref": "bookverse-${service}@${version}",
      "name": "bookverse-${service}",
      "version": "${version}",
      "description": "BookVerse ${service} microservice"
    }
  },
  "components": [
    {
      "type": "library",
      "bom-ref": "fastapi@0.68.0",
      "name": "fastapi",
      "version": "0.68.0",
      "description": "FastAPI framework, high performance, easy to learn, fast to code, ready for production",
      "licenses": [
        {
          "license": {
            "id": "MIT"
          }
        }
      ]
    },
    {
      "type": "library", 
      "bom-ref": "uvicorn@0.15.0",
      "name": "uvicorn",
      "version": "0.15.0",
      "description": "The lightning-fast ASGI server",
      "licenses": [
        {
          "license": {
            "id": "BSD-3-Clause"
          }
        }
      ]
    },
    {
      "type": "library",
      "bom-ref": "pydantic@1.8.0", 
      "name": "pydantic",
      "version": "1.8.0",
      "description": "Data validation and settings management using python type hints",
      "licenses": [
        {
          "license": {
            "id": "MIT"
          }
        }
      ]
    }
  ],
  "dependencies": [
    {
      "ref": "bookverse-${service}@${version}",
      "dependsOn": [
        "fastapi@0.68.0",
        "uvicorn@0.15.0", 
        "pydantic@1.8.0"
      ]
    }
  ]
}
EOF

    echo "✅ Created SBOM: ${service}-sbom-${version}.json"
}

# Function to create sample build info
create_sample_build_info() {
    local service="$1"
    local version="$2"
    local build_number="$3"
    
    echo "🔨 Creating sample build info for $service (v$version, build #$build_number)"
    
    cat > "${service}-buildinfo-${version}-${build_number}.json" << EOF
{
  "version": "1.0.1",
  "name": "bookverse-${service}",
  "number": "${build_number}",
  "type": "GENERIC",
  "buildAgent": {
    "name": "GitHub Actions",
    "version": "1.0.0"
  },
  "agent": {
    "name": "jfrog-cli",
    "version": "2.30.0"
  },
  "started": "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)",
  "durationMillis": 125000,
  "principal": "github-actions[bot]",
  "artifactoryPrincipal": "pipeline.${service}@bookverse.com",
  "url": "https://github.com/yonatanp-jfrog/bookverse-${service}/actions/runs/${build_number}",
  "vcs": [
    {
      "revision": "$(openssl rand -hex 20)",
      "url": "https://github.com/yonatanp-jfrog/bookverse-${service}.git",
      "branch": "main"
    }
  ],
  "modules": [
    {
      "id": "bookverse-${service}:${version}",
      "artifacts": [
        {
          "type": "wheel",
          "sha1": "$(echo -n "bookverse-${service}-${version}" | openssl dgst -sha1 | cut -d' ' -f2)",
          "sha256": "$(echo -n "bookverse-${service}-${version}" | openssl dgst -sha256 | cut -d' ' -f2)",
          "md5": "$(echo -n "bookverse-${service}-${version}" | openssl dgst -md5 | cut -d' ' -f2)",
          "name": "bookverse_${service}-${version}-py3-none-any.whl"
        },
        {
          "type": "docker",
          "sha1": "$(echo -n "bookverse-${service}:${version}" | openssl dgst -sha1 | cut -d' ' -f2)", 
          "sha256": "$(echo -n "bookverse-${service}:${version}" | openssl dgst -sha256 | cut -d' ' -f2)",
          "name": "bookverse-${service}:${version}"
        }
      ]
    }
  ],
  "governance": {
    "blackDuckProperties": {
      "runChecks": false
    }
  },
  "buildRetention": {
    "count": -1,
    "deleteBuildArtifacts": true,
    "buildNumbersNotToBeDiscarded": []
  }
}
EOF

    echo "✅ Created build info: ${service}-buildinfo-${version}-${build_number}.json"
}

echo "🚀 Starting demo data generation..."
echo ""

# Generate artifacts for each service
for service in "${SERVICES[@]}"; do
    echo "========================================"
    echo "📦 Generating artifacts for: $service"
    echo "========================================"
    
    # Create multiple versions to show progression
    versions=("1.0.0" "1.0.1" "1.1.0")
    
    for version in "${versions[@]}"; do
        echo ""
        echo "🔄 Processing version: $version"
        
        # Create Python package
        create_sample_python_package "$service" "$version"
        
        # Create Docker image (if Docker available)
        create_sample_docker_image "$service" "$version"
        
        # Create SBOM
        create_sample_sbom "$service" "$version"
        
        # Create build info
        build_number=$((1000 + RANDOM % 1000))
        create_sample_build_info "$service" "$version" "$build_number"
        
        echo "✅ Completed artifacts for $service v$version"
    done
    
    echo ""
done

# Create demo dataset summary
echo "📊 Creating demo dataset summary..."
cat > demo-dataset-summary.md << EOF
# BookVerse Demo Dataset

Generated on: $(date)

## Artifacts Created

### Services
$(for service in "${SERVICES[@]}"; do
    echo "- **$service**: Inventory, recommendations, checkout, and platform services"
done)

### Versions
- 1.0.0 (initial release)
- 1.0.1 (patch release)  
- 1.1.0 (minor release)

### Artifact Types
- **Python Packages**: Installable wheels and source distributions
- **Docker Images**: Containerized applications 
- **SBOMs**: Software Bill of Materials (CycloneDX format)
- **Build Info**: Comprehensive build metadata and provenance

### File Structure
\`\`\`
$(find . -type f -name "*.whl" -o -name "*.tar.gz" -o -name "*.json" | sort)
\`\`\`

## Usage Instructions

1. **Upload Python Packages**: Use \`pip install\` or direct upload to PyPI repositories
2. **Deploy Docker Images**: Push to Docker registries and deploy to Kubernetes
3. **Import SBOMs**: Upload to security scanning tools for vulnerability analysis
4. **Build Info**: Import into JFrog Build Info for traceability

## Demo Scenarios

### Scenario 1: Development Workflow
1. Show Python package development and testing
2. Demonstrate Docker image building and scanning
3. Display SBOM generation and vulnerability analysis

### Scenario 2: Release Management
1. Progress artifacts through DEV → QA → STAGING → PROD
2. Show promotion workflows and approvals
3. Demonstrate audit trails and compliance reporting

### Scenario 3: Security and Compliance
1. Display vulnerability scanning results
2. Show license compliance checking
3. Demonstrate policy enforcement and gates

## Next Steps

1. Upload artifacts to appropriate JFrog repositories
2. Configure promotion workflows
3. Set up security policies and gates
4. Run end-to-end demo scenarios
EOF

echo "✅ Demo dataset summary created"
echo ""

# Final summary
echo "🎉 DEMO DATA GENERATION COMPLETE!"
echo ""
echo "📊 Generated artifacts:"
echo "   • Python packages: $(find . -name "*.whl" | wc -l) wheels"
echo "   • Docker images: $(find . -name "*.tar.gz" | wc -l) archives"
echo "   • SBOMs: $(find . -name "*-sbom-*.json" | wc -l) files"
echo "   • Build info: $(find . -name "*-buildinfo-*.json" | wc -l) files"
echo ""
echo "📁 All artifacts available in: $TEMP_DIR"
echo ""
echo "🚀 Next steps:"
echo "   1. Review generated artifacts in $TEMP_DIR"
echo "   2. Upload artifacts to JFrog repositories"
echo "   3. Configure promotion workflows"
echo "   4. Run demo scenarios from docs/DEMO_RUNBOOK.md"
echo ""

# Keep the temp directory for user review
echo "💡 Note: Temporary directory preserved for review"
echo "   To clean up later: rm -rf $TEMP_DIR"
echo ""
