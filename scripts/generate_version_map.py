#!/usr/bin/env python3
import os
import random
import yaml
from typing import Dict, Any

# Note: Per requirements, we DO NOT enforce seed uniqueness.
# Seeds are generated once in the range 1.0.0 to 3.20.30 and remain static.

SEED_RANGES = {
    "major": (1, 3),   # inclusive
    "minor": (0, 20),  # inclusive
    "patch": (0, 30),  # inclusive
}

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

        # Only set seeds if missing; never overwrite existing
        entry["seeds"].setdefault("application", gen_seed())
        entry["seeds"].setdefault("build", gen_seed())

        # Merge packages: add missing, keep existing seeds
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
