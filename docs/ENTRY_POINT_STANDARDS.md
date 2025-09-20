# BookVerse Service Entry Point Standards

## Overview

This document establishes standardized entry point patterns for all BookVerse services to ensure consistency, maintainability, and ease of deployment.

## ✅ Current Implementation Status

All BookVerse services now follow standardized entry point patterns:

- ✅ **bookverse-recommendations**: Complete with main() and console script
- ✅ **bookverse-inventory**: Complete with main() and console script  
- ✅ **bookverse-checkout**: Complete with main() and console script
- ✅ **bookverse-platform**: Hybrid service with multiple entry points

## 📋 Standard Entry Point Pattern

### 1. Python Module Entry Point

Every service MUST have a `main()` function in its primary module:

```python
def main():
    """Main entry point for the service"""
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)


if __name__ == "__main__":
    main()
```

### 2. Package Entry Points (Console Scripts)

Every service MUST define console script entry points in `pyproject.toml`:

```toml
[project.scripts]
bookverse-{service-name} = "app.main:main"
```

### 3. Service Structure Requirements

```
bookverse-{service}/
├── app/
│   ├── __init__.py
│   ├── main.py          # REQUIRED: Contains main() function
│   ├── api.py           # API routes
│   └── ...              # Other modules
├── pyproject.toml       # REQUIRED: Package configuration with console scripts
├── requirements.txt     # Runtime dependencies
├── Dockerfile          # Container configuration
└── README.md           # Service documentation
```

## 🔧 Service-Specific Patterns

### Standard Web Services

**Examples**: `bookverse-recommendations`, `bookverse-inventory`, `bookverse-checkout`

- Single `main()` entry point in `app/main.py`
- One console script: `bookverse-{service-name}`
- FastAPI application with uvicorn server

### Hybrid Services

**Example**: `bookverse-platform`

- Multiple entry points for different modes:
  - CLI tools: `app.main:main`, `scripts.{tool}:main`
- Multiple console scripts for different functions
- `entrypoint.sh` for container orchestration

## 📦 Installation and Usage

### Development Installation

```bash
cd bookverse-{service}
pip install -e .
```

### Running Services

After installation, services can be started using their console scripts:

```bash
# Web services
bookverse-recommendations
bookverse-inventory  
bookverse-checkout

# Platform service (web mode)
bookverse-platform-tagging

# Platform service (CLI tools)
bookverse-platform-aggregator --help
bookverse-platform-rollback --help
bookverse-platform-semver --help
```

### Container Usage

Services maintain their existing Docker entry points, but now also support direct Python execution:

```bash
# Traditional container execution
docker run bookverse-recommendations

# Direct Python execution  
python -m app.main

# Console script execution (if installed)
bookverse-recommendations
```

## 🎯 Benefits of Standardization

### 1. **Consistency**
- Uniform entry point patterns across all services
- Predictable service startup and deployment
- Standardized development and testing workflows

### 2. **Developer Experience**
- Easy to install and run services locally
- Clear entry points for debugging and development
- Consistent command-line interface

### 3. **Operations & DevOps**
- Simplified deployment automation
- Consistent health check and monitoring patterns
- Uniform container orchestration

### 4. **Package Management**
- Services can be installed as Python packages
- Version management through standard Python packaging
- Easy dependency resolution and virtual environment support

## 🚀 Migration Guide

### For New Services

1. Create `app/main.py` with standardized `main()` function
2. Add `pyproject.toml` with console script entry points
3. Follow the standard project structure
4. Include proper FastAPI application setup using bookverse-core

### For Existing Services

All existing services have been migrated to follow these standards. Future modifications should maintain:

1. The `main()` function pattern in `app/main.py`
2. Console script definitions in `pyproject.toml`
3. Compatibility with existing Docker/Kubernetes deployments

## 🔍 Validation

### Entry Point Testing

All services should include tests that validate entry points:

```python
def test_main_entry_point():
    """Test that main() function is properly defined and importable"""
    from app.main import main
    assert callable(main)

def test_console_script_installation():
    """Test that console scripts are properly installed"""
    # Verify that pip install creates the expected console scripts
    pass
```

### CI/CD Integration

- Build processes should verify console script installation
- Integration tests should use both direct Python execution and console scripts
- Container builds should maintain backwards compatibility

## 📚 Additional Resources

- [Python Packaging User Guide - Entry Points](https://packaging.python.org/en/latest/specifications/entry-points/)
- [FastAPI Deployment Guide](https://fastapi.tiangolo.com/deployment/)
- [BookVerse Development Guide](./DEVELOPMENT.md)

## 🔄 Version History

- **v1.0** (2025-09-18): Initial standardization across all BookVerse services
  - Added main() functions to all services
  - Created pyproject.toml configurations
  - Established console script entry points
  - Documented hybrid service patterns (platform service)
