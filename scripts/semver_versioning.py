#!/usr/bin/env python3
import argparse
import json
import os
import re
import sys
from typing import List, Optional, Tuple, Dict, Any
import urllib.request
import urllib.parse

SEMVER_RE = re.compile(r"^(\d+)\.(\d+)\.(\d+)$")


def parse_semver(v: str) -> Optional[Tuple[int, int, int]]:
    m = SEMVER_RE.match(v.strip())
    if not m:
        return None
    return int(m.group(1)), int(m.group(2)), int(m.group(3))


def bump_patch(v: str) -> str:
    p = parse_semver(v)
    if not p:
        raise ValueError(f"Not a SemVer X.Y.Z: {v}")
    return f"{p[0]}.{p[1]}.{p[2] + 1}"


def max_semver(values: List[str]) -> Optional[str]:
    parsed = [(parse_semver(v), v) for v in values]
    parsed = [(t, raw) for t, raw in parsed if t is not None]
    if not parsed:
        return None
    parsed.sort(key=lambda x: x[0])
    return parsed[-1][1]


def http_get(url: str, headers: Dict[str, str], timeout: int = 30) -> Any:
    req = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        data = resp.read().decode("utf-8")
    try:
        return json.loads(data)
    except Exception:
        return data


def http_post(url: str, headers: Dict[str, str], data: str, timeout: int = 30) -> Any:
    """HTTP POST method for AQL queries"""
    req = urllib.request.Request(url, data=data.encode('utf-8'), headers=headers, method='POST')
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        response_data = resp.read().decode("utf-8")
    try:
        return json.loads(response_data)
    except Exception:
        return response_data


def load_version_map(path: str) -> Dict[str, Any]:
    import yaml  # type: ignore
    with open(path, "r", encoding="utf-8") as f:
        return yaml.safe_load(f) or {}


def find_app_entry(vm: Dict[str, Any], app_key: str) -> Dict[str, Any]:
    for it in vm.get("applications", []) or []:
        if (it.get("key") or "").strip() == app_key:
            return it
    return {}


def compute_next_application_version(app_key: str, vm: Dict[str, Any], jfrog_url: str, token: str) -> str:
    base = jfrog_url.rstrip("/") + "/apptrust/api/v1"
    headers = {"Authorization": f"Bearer {token}", "Accept": "application/json"}

    # 1) Prefer the most recently created version and bump its patch if SemVer
    latest_url = f"{base}/applications/{urllib.parse.quote(app_key)}/versions?limit=1&order_by=created&order_asc=false"
    try:
        latest_payload = http_get(latest_url, headers)
    except Exception:
        latest_payload = {}

    def first_version(obj: Any) -> Optional[str]:
        if isinstance(obj, dict):
            arr = (
                obj.get("versions")
                or obj.get("results")
                or obj.get("items")
                or obj.get("data")
                or []
            )
            if arr:
                v = (arr[0] or {}).get("version") or (arr[0] or {}).get("name")
                return v if isinstance(v, str) else None
        return None

    latest_created = first_version(latest_payload)
    if isinstance(latest_created, str) and parse_semver(latest_created):
        return bump_patch(latest_created)

    # 2) Fallback: scan recent versions and bump the max SemVer present
    url = f"{base}/applications/{urllib.parse.quote(app_key)}/versions?limit=50&order_by=created&order_asc=false"
    try:
        payload = http_get(url, headers)
    except Exception:
        payload = {}

    def extract_versions(obj: Any) -> List[str]:
        if isinstance(obj, dict):
            arr = (
                obj.get("versions")
                or obj.get("results")
                or obj.get("items")
                or obj.get("data")
                or []
            )
            out = []
            for it in arr or []:
                v = (it or {}).get("version") or (it or {}).get("name")
                if isinstance(v, str) and parse_semver(v):
                    out.append(v)
            return out
        elif isinstance(obj, list):
            return [x for x in obj if isinstance(x, str) and parse_semver(x)]
        return []

    values = extract_versions(payload)
    latest = max_semver(values)
    if latest:
        return bump_patch(latest)

    # 3) Fallback to seed - IMPORTANT: bump the seed to avoid conflicts with promoted artifacts
    entry = find_app_entry(vm, app_key)
    seed = ((entry.get("seeds") or {}).get("application")) if entry else None
    if not seed or not parse_semver(str(seed)):
        raise SystemExit(f"No valid seed for application {app_key}")
    # Always bump the seed to prevent conflicts with existing promoted Release Bundles
    return bump_patch(str(seed))


def compute_next_build_number(app_key: str, vm: Dict[str, Any], jfrog_url: str, token: str) -> str:
    # Build number comes from the last AppTrust version's sources.builds[0].number
    base = jfrog_url.rstrip("/") + "/apptrust/api/v1"
    headers = {"Authorization": f"Bearer {token}", "Accept": "application/json"}

    # Latest version first
    vlist_url = f"{base}/applications/{urllib.parse.quote(app_key)}/versions?limit=1&order_by=created&order_asc=false"
    try:
        vlist = http_get(vlist_url, headers)
    except Exception:
        vlist = {}

    def first_version(obj: Any) -> Optional[str]:
        if isinstance(obj, dict):
            arr = (
                obj.get("versions")
                or obj.get("results")
                or obj.get("items")
                or obj.get("data")
                or []
            )
            if arr:
                v = (arr[0] or {}).get("version") or (arr[0] or {}).get("name")
                return v if isinstance(v, str) else None
        return None

    latest = first_version(vlist)
    if latest:
        try:
            vinfo = http_get(
                f"{base}/applications/{urllib.parse.quote(app_key)}/versions/{urllib.parse.quote(latest)}",
                headers,
            )
        except Exception:
            vinfo = {}
        num = None
        if isinstance(vinfo, dict):
            try:
                num = (((vinfo.get("sources") or {}).get("builds") or [])[0] or {}).get("number")
            except Exception:
                num = None
        if isinstance(num, str) and parse_semver(num):
            return bump_patch(num)

    # Fallback to seed - IMPORTANT: bump the seed to avoid conflicts with promoted artifacts
    entry = find_app_entry(vm, app_key)
    seed = ((entry.get("seeds") or {}).get("build")) if entry else None
    if not seed or not parse_semver(str(seed)):
        raise SystemExit(f"No valid build seed for application {app_key}")
    # Always bump the seed to prevent conflicts with existing promoted Release Bundles
    return bump_patch(str(seed))


def compute_next_package_tag(app_key: str, package_name: str, vm: Dict[str, Any], jfrog_url: str, token: str, project_key: Optional[str]) -> str:
    # Find package configuration and seed
    entry = find_app_entry(vm, app_key)
    pkg = None
    for it in (entry.get("packages") or []):
        if (it.get("name") or "").strip() == package_name:
            pkg = it
            break
    
    if not pkg:
        raise SystemExit(f"Package {package_name} not found in version map for {app_key}")
    
    seed = pkg.get("seed")
    package_type = pkg.get("type", "")
    
    if not seed or not parse_semver(str(seed)):
        raise SystemExit(f"No valid seed for package {app_key}/{package_name}")
    
    headers = {"Authorization": f"Bearer {token}", "Accept": "application/json"}
    
    # Try to find existing versions to bump from
    existing_versions = []
    
    if package_type == "docker":
        # For Docker packages, query Docker registry API
        try:
            # Extract service name from app_key (bookverse-web -> web)
            service_name = app_key.replace("bookverse-", "")
            # Fix Docker repo pattern to match actual naming convention
            repo_key = f"{project_key or 'bookverse'}-{service_name}-internal-docker-nonprod-local"
            docker_url = f"{jfrog_url.rstrip('/')}/artifactory/api/docker/{repo_key}/v2/{package_name}/tags/list"
            
            resp = http_get(docker_url, headers)
            if isinstance(resp, dict) and "tags" in resp:
                # Filter to valid semver tags only
                for tag in resp.get("tags", []):
                    if isinstance(tag, str) and parse_semver(tag):
                        existing_versions.append(tag)
        except Exception:
            # If Docker API fails, continue with fallback logic
            pass
    
    elif package_type == "generic":
        # For generic packages, try to query via AQL to find existing versions
        try:
            # Extract service name from app_key (bookverse-web -> web)
            service_name = app_key.replace("bookverse-", "")
            # Generic repo pattern: bookverse-{service}-internal-generic-nonprod-local
            repo_key = f"{project_key or 'bookverse'}-{service_name}-internal-generic-nonprod-local"
            
            # AQL query to find artifacts in the repository with version patterns
            aql_query = f'''items.find({{"repo":"{repo_key}","type":"file"}}).include("name","path","actual_sha1")'''
            aql_url = f"{jfrog_url.rstrip('/')}/artifactory/api/search/aql"
            aql_headers = headers.copy()
            aql_headers["Content-Type"] = "text/plain"
            
            resp = http_post(aql_url, aql_headers, aql_query)
            if isinstance(resp, dict) and "results" in resp:
                # Extract version numbers from paths/names
                for item in resp.get("results", []):
                    path = item.get("path", "")
                    name = item.get("name", "")
                    
                    # Look for version patterns in path (e.g., /web/assets/1.6.14/)
                    import re
                    version_pattern = r'/(\d+\.\d+\.\d+)/'
                    match = re.search(version_pattern, path)
                    if match:
                        version = match.group(1)
                        if parse_semver(version):
                            existing_versions.append(version)
        except Exception:
            # If AQL fails, continue with fallback logic
            pass
    
    # If we found existing versions, bump the latest one
    if existing_versions:
        latest = max_semver(existing_versions)
        if latest:
            return bump_patch(latest)
    
    # Fallback: bump the seed version to avoid conflicts
    # This ensures we don't reuse the exact seed version which may already exist
    return bump_patch(str(seed))


def main():
    p = argparse.ArgumentParser(description="Compute sequential SemVer versions with fallback to seeds")
    p.add_argument("compute", nargs="?")
    p.add_argument("--application-key", required=True)
    p.add_argument("--version-map", required=True)
    p.add_argument("--jfrog-url", required=True)
    p.add_argument("--jfrog-token", required=True)
    p.add_argument("--project-key", required=False)
    p.add_argument("--packages", help="Comma-separated package names to compute tags for", required=False)
    args = p.parse_args()

    vm = load_version_map(args.version_map)
    app_key = args.application_key
    jfrog_url = args.jfrog_url
    token = args.jfrog_token

    app_version = compute_next_application_version(app_key, vm, jfrog_url, token)
    build_number = compute_next_build_number(app_key, vm, jfrog_url, token)

    pkg_tags: Dict[str, str] = {}
    if args.packages:
        for name in [x.strip() for x in args.packages.split(",") if x.strip()]:
            pkg_tags[name] = compute_next_package_tag(app_key, name, vm, jfrog_url, token, args.project_key)

    # Export to GITHUB_ENV for the calling workflow
    env_path = os.environ.get("GITHUB_ENV")
    if env_path:
        with open(env_path, "a", encoding="utf-8") as f:
            f.write(f"APP_VERSION={app_version}\n")
            f.write(f"BUILD_NUMBER={build_number}\n")
            # Default IMAGE_TAG to BUILD_NUMBER for compatibility
            f.write(f"IMAGE_TAG={build_number}\n")
            for k, v in pkg_tags.items():
                key = re.sub(r"[^A-Za-z0-9_]", "_", k.upper())
                f.write(f"DOCKER_TAG_{key}={v}\n")

    # Summary for debugging
    out = {
        "application_key": app_key,
        "app_version": app_version,
        "build_number": build_number,
        "package_tags": pkg_tags,
        "source": "latest+bump or seed fallback"
    }
    print(json.dumps(out))


if __name__ == "__main__":
    main()
