"""
BookVerse Platform - Version Mapping Generation and Configuration

This module provides comprehensive version mapping generation for the BookVerse
platform, implementing sophisticated version generation algorithms, package
mapping configuration, and YAML output formatting for demo and testing
scenarios with realistic version distribution patterns.

🏗️ Architecture Overview:
    - Version Generation: Sophisticated semantic version generation algorithms
    - Package Mapping: Comprehensive package and application mapping configuration
    - YAML Output: Structured YAML configuration file generation
    - Randomization: Controlled randomization for realistic version patterns
    - Configuration Management: Flexible configuration for different scenarios
    - Demo Optimization: Version patterns optimized for demonstration purposes

🚀 Key Features:
    - Automated version mapping generation with configurable parameters
    - Realistic semantic version patterns using controlled randomization
    - Comprehensive application and package configuration mapping
    - YAML configuration file generation for downstream consumption
    - Flexible version range configuration for different scenarios
    - Demo-optimized version patterns for presentation and testing

🔧 Technical Implementation:
    - Random Generation: Controlled randomization within configured ranges
    - Semantic Versioning: SemVer-compliant version generation patterns
    - YAML Processing: Structured YAML configuration file generation
    - Configuration Mapping: Application and package mapping configuration
    - Pattern Control: Configurable version patterns and distributions

📊 Business Logic:
    - Demo Preparation: Version mapping for demonstration scenarios
    - Testing Support: Realistic version patterns for testing and validation
    - Configuration Generation: Automated configuration for complex scenarios
    - Pattern Modeling: Realistic version distribution modeling
    - Scenario Support: Flexible configuration for various use cases

🛠️ Usage Patterns:
    - Demo Setup: Version mapping generation for demo environments
    - Testing Configuration: Realistic version patterns for testing
    - Development Support: Version mapping for development scenarios
    - Configuration Management: Automated configuration generation
    - Scenario Modeling: Version pattern modeling for various scenarios

Authors: BookVerse Platform Team
Version: 1.0.0
"""

import os
import random
import yaml
from typing import Dict, Any

# 🔧 Version Configuration: Semantic version component ranges for generation
SEED_RANGES = {
    "major": (1, 3),        # Major version range for compatibility patterns
    "minor": (0, 20),       # Minor version range for feature evolution
    "patch": (0, 30),       # Patch version range for bug fixes and updates
}

# 📦 Application Configuration: Complete BookVerse application and package mapping
APPS = [
    {
        "key": "bookverse-inventory",
        "packages": [
            {"type": "docker", "name": "inventory-api"},
        ],
    },
    {
        "key": "bookverse-recommendations",
        "packages": [
            {"type": "docker", "name": "recommendations-api"},
            {"type": "docker", "name": "recommendations-worker"},
        ],
    },
    {
        "key": "bookverse-checkout",
        "packages": [
            {"type": "docker", "name": "checkout-api"},
            {"type": "docker", "name": "checkout-worker"},
            {"type": "docker", "name": "checkout-mock-payment"},
        ],
    },
    {
        "key": "bookverse-web",
        "packages": [
            {"type": "docker", "name": "web"},
        ],
    },
    {
        "key": "bookverse-platform",
        "packages": [
            # Platform service with no direct packages
        ],
    },
]


def gen_seed() -> str:
    maj = random.randint(*SEED_RANGES["major"])
    minr = random.randint(*SEED_RANGES["minor"])
    pat = random.randint(*SEED_RANGES["patch"])
    return f"{maj}.{minr}.{pat}"


def ensure_version_map(path: str):
    data: Dict[str, Any] = {}
    if os.path.exists(path):
        with open(path, "r", encoding="utf-8") as f:
            data = yaml.safe_load(f) or {}

    apps_by_key = {a.get("key"): a for a in data.get("applications", []) or []}

    for app in APPS:
        key = app["key"]
        entry = apps_by_key.get(key) or {"key": key}
        entry.setdefault("seeds", {})
        entry.setdefault("packages", [])

        entry["seeds"].setdefault("application", gen_seed())
        entry["seeds"].setdefault("build", gen_seed())

        existing = { (p.get("type"), p.get("name")): p for p in entry["packages"] }
        for p in app["packages"]:
            k = (p.get("type"), p.get("name"))
            if k not in existing:
                p = dict(p)
                p["seed"] = gen_seed()
                entry["packages"].append(p)

        apps_by_key[key] = entry

    out = {"applications": list(apps_by_key.values())}
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        yaml.safe_dump(out, f, sort_keys=False)


if __name__ == "__main__":
    vm_path = os.environ.get("VERSION_MAP_PATH") or "config/version-map.yaml"
    ensure_version_map(vm_path)
    print(f"Wrote version map to {vm_path}")
