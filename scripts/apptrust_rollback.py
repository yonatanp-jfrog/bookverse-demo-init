#!/usr/bin/env python3
"""
AppTrust PROD rollback utility.

Implements:
- Minimal AppTrust API client (list versions, patch version)
- SemVer parsing and comparison
- Stateless rollback flow per plan:
  - Backup current tag to `original_tag_before_quarantine`
  - Set target tag to `quarantine`
  - If target had `latest`, select next SemVer-max non-quarantined and set its tag to `latest`,
    backing up its current tag to `original_tag_before_latest`.

CLI usage:
  python apptrust_rollback.py --app APP_KEY --version 1.2.3 [--dry-run]

Exit codes:
  0 on success; non-zero on error.

Note: Uses only Python standard library for portability.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from typing import Any, Dict, List, Optional, Tuple
import shutil
import subprocess


# ------------------------- SemVer helpers -------------------------

SEMVER_RE = re.compile(
    r"^\s*v?(?P<major>0|[1-9]\d*)\.(?P<minor>0|[1-9]\d*)\.(?P<patch>0|[1-9]\d*)"
    r"(?:-(?P<prerelease>(?:0|[1-9]\d*|[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|[a-zA-Z-][0-9a-zA-Z-]*))*))?"
    r"(?:\+(?P<build>[0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?\s*$"
)


@dataclass(frozen=True)
class SemVer:
    """Semantic version value object for ordering and comparisons."""

    major: int
    minor: int
    patch: int
    prerelease: Tuple[str, ...]  # tokens; empty for GA
    original: str

    @staticmethod
    def parse(version: str) -> Optional["SemVer"]:
        match = SEMVER_RE.match(version)
        if not match:
            return None
        groups = match.groupdict()
        major = int(groups["major"])  # type: ignore[arg-type]
        minor = int(groups["minor"])  # type: ignore[arg-type]
        patch = int(groups["patch"])  # type: ignore[arg-type]
        prerelease_raw = groups.get("prerelease") or ""
        prerelease = tuple(prerelease_raw.split(".")) if prerelease_raw else tuple()
        return SemVer(major, minor, patch, prerelease, version)

    def __lt__(self, other: "SemVer") -> bool:  # pragma: no cover - delegating to comparator
        return compare_semver(self, other) < 0


def compare_semver(a: SemVer, b: SemVer) -> int:
    """Compare two SemVer instances according to semver precedence rules."""
    if a.major != b.major:
        return -1 if a.major < b.major else 1
    if a.minor != b.minor:
        return -1 if a.minor < b.minor else 1
    if a.patch != b.patch:
        return -1 if a.patch < b.patch else 1
    # GA (no prerelease) > prerelease
    if not a.prerelease and b.prerelease:
        return 1
    if a.prerelease and not b.prerelease:
        return -1
    # Both prerelease: compare identifiers
    for at, bt in zip(a.prerelease, b.prerelease):
        if at == bt:
            continue
        a_is_num = at.isdigit()
        b_is_num = bt.isdigit()
        if a_is_num and b_is_num:
            ai = int(at)
            bi = int(bt)
            if ai != bi:
                return -1 if ai < bi else 1
        elif a_is_num and not b_is_num:
            return -1  # numerics have lower precedence than non-numerics
        elif not a_is_num and b_is_num:
            return 1
        else:
            if at < bt:
                return -1
            return 1
    # All equal so far; shorter prerelease list has lower precedence
    if len(a.prerelease) != len(b.prerelease):
        return -1 if len(a.prerelease) < len(b.prerelease) else 1
    return 0


def sort_versions_by_semver_desc(version_strings: List[str]) -> List[str]:
    parsed: List[Tuple[SemVer, str]] = []
    for v in version_strings:
        sv = SemVer.parse(v)
        if sv is not None:
            parsed.append((sv, v))
    parsed.sort(key=lambda t: (
        t[0].major,
        t[0].minor,
        t[0].patch,
        # GA > prerelease, so negate a boolean
        0 if not t[0].prerelease else -1,
        # prerelease needs custom compare; using tuple as tie-breaker is insufficient but acceptable since GA outranks prerelease already; detailed compare happens in compare_semver when needed
    ), reverse=True)
    # For truly correct ordering including prerelease identifiers, we fallback to repeated stable sort using comparator
    parsed.sort(key=lambda t: t[0], reverse=True)  # type: ignore[arg-type]
    return [v for _, v in parsed]


# ------------------------- AppTrust client -------------------------

class AppTrustClient:
    """Minimal HTTP client for AppTrust API using urllib.

    - base_url: like "https://{host}/apptrust/api/v1"
    - token: JFrog access token (Bearer)
    """

    def __init__(self, base_url: str, token: str, timeout_seconds: int = 30) -> None:
        self.base_url = base_url.rstrip("/")
        self.token = token
        self.timeout_seconds = timeout_seconds

    def _request(self, method: str, path: str, query: Optional[Dict[str, Any]] = None, body: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        url = f"{self.base_url}{path}"
        if query:
            q = urllib.parse.urlencode({k: v for k, v in query.items() if v is not None})
            url = f"{url}?{q}"
        data = None
        headers = {
            "Authorization": f"Bearer {self.token}",
            "Accept": "application/json",
        }
        if body is not None:
            data = json.dumps(body).encode("utf-8")
            headers["Content-Type"] = "application/json"
        req = urllib.request.Request(url=url, data=data, method=method, headers=headers)
        try:
            with urllib.request.urlopen(req, timeout=self.timeout_seconds) as resp:
                content_type = resp.headers.get("Content-Type", "")
                raw = resp.read()
                if not raw:
                    return {}
                if "application/json" in content_type:
                    return json.loads(raw.decode("utf-8"))
                # fallback: try json
                try:
                    return json.loads(raw.decode("utf-8"))
                except Exception:
                    return {"raw": raw.decode("utf-8", errors="replace")}
        except urllib.error.HTTPError as e:
            err_body = e.read().decode("utf-8", errors="replace")
            raise RuntimeError(f"HTTP {e.code} {e.reason} for {method} {url}: {err_body}") from None
        except urllib.error.URLError as e:
            raise RuntimeError(f"Network error for {method} {url}: {e}") from None

    # API surfaces
    def list_application_versions(self, app_key: str, limit: int = 1000) -> Dict[str, Any]:
        """Return response from Get Application Versions; caller filters by release_status client-side.

        Response shape contains `versions: [ { version, tag, release_status, ...}, ... ]`.
        """
        path = f"/applications/{urllib.parse.quote(app_key)}/versions"
        # Avoid relying on release_status filter (not yet implemented); sort by created desc
        return self._request("GET", path, query={"limit": limit, "order_by": "created", "order_asc": "false"})

    def patch_application_version(self, app_key: str, version: str, tag: Optional[str] = None, properties: Optional[Dict[str, List[str]]] = None, delete_properties: Optional[List[str]] = None) -> Dict[str, Any]:
        """PATCH application version: replace tag and/or properties.

        - tag: string or empty string to clear
        - properties: dict of key -> list of string values; replaces key values
        - delete_properties: list of keys to remove entirely
        """
        path = f"/applications/{urllib.parse.quote(app_key)}/versions/{urllib.parse.quote(version)}"
        body: Dict[str, Any] = {}
        if tag is not None:
            body["tag"] = tag
        if properties is not None:
            body["properties"] = properties
        if delete_properties is not None:
            body["delete_properties"] = delete_properties
        return self._request("PATCH", path, body=body)


class AppTrustClientCLI:
    """AppTrust client backed by JFrog CLI (OIDC-enabled).

    Requires `jf` on PATH and a configured server context (e.g., via
    `jf c add --interactive=false --url "$JFROG_URL" --access-token ""`).
    """

    def __init__(self, timeout_seconds: int = 30) -> None:
        self.timeout_seconds = timeout_seconds

    @staticmethod
    def _ensure_cli_available() -> None:
        if shutil.which("jf") is None:
            raise RuntimeError("JFrog CLI (jf) not found on PATH. Install/configure it for OIDC.")

    @staticmethod
    def _run_jf(method: str, path: str, body: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        AppTrustClientCLI._ensure_cli_available()
        args: List[str] = ["jf", "curl", "-X", method.upper(), path]
        if body is not None:
            args += ["-H", "Content-Type: application/json", "-d", json.dumps(body)]
        try:
            proc = subprocess.run(args, check=True, capture_output=True, text=True)
        except subprocess.CalledProcessError as e:
            raise RuntimeError(f"jf curl failed: {e.stderr.strip() or e}")
        raw = (proc.stdout or "").strip()
        if not raw:
            return {}
        try:
            return json.loads(raw)
        except Exception:
            return {"raw": raw}

    def list_application_versions(self, app_key: str, limit: int = 1000) -> Dict[str, Any]:
        path = f"/apptrust/api/v1/applications/{urllib.parse.quote(app_key)}/versions"
        return self._run_jf("GET", path + f"?limit={limit}&order_by=created&order_asc=false")

    def patch_application_version(self, app_key: str, version: str, tag: Optional[str] = None, properties: Optional[Dict[str, List[str]]] = None, delete_properties: Optional[List[str]] = None) -> Dict[str, Any]:
        path = f"/apptrust/api/v1/applications/{urllib.parse.quote(app_key)}/versions/{urllib.parse.quote(version)}"
        body: Dict[str, Any] = {}
        if tag is not None:
            body["tag"] = tag
        if properties is not None:
            body["properties"] = properties
        if delete_properties is not None:
            body["delete_properties"] = delete_properties
        return self._run_jf("PATCH", path, body=body)

    def get_version_content(self, app_key: str, version: str) -> Dict[str, Any]:
        path = f"/apptrust/api/v1/applications/{urllib.parse.quote(app_key)}/versions/{urllib.parse.quote(version)}/content"
        return self._run_jf("GET", path)


# ------------------------- Rollback logic -------------------------

TRUSTED = "TRUSTED_RELEASE"
RELEASED = "RELEASED"
QUARANTINE_TAG = "quarantine"
LATEST_TAG = "latest"
BACKUP_BEFORE_LATEST = "original_tag_before_latest"
BACKUP_BEFORE_QUARANTINE = "original_tag_before_quarantine"


def get_prod_versions(client: AppTrustClient, app_key: str) -> List[Dict[str, Any]]:
    """Fetch versions for app_key, filter to PROD (`RELEASED`/`TRUSTED_RELEASE`).

    Returns list of dicts at least containing: version, tag, release_status.
    Sorted by SemVer desc client-side for determinism.
    """
    resp = client.list_application_versions(app_key)
    versions = resp.get("versions", [])
    # Normalize missing fields
    norm: List[Dict[str, Any]] = []
    for v in versions:
        ver = str(v.get("version", ""))
        tag = v.get("tag")
        tag_str = "" if tag is None else str(tag)
        rs = str(v.get("release_status", "")).upper()
        if rs in (TRUSTED, RELEASED):
            norm.append({"version": ver, "tag": tag_str, "release_status": rs})
    # Sort by semver desc
    order = sort_versions_by_semver_desc([v["version"] for v in norm])
    index = {ver: i for i, ver in enumerate(order)}
    norm.sort(key=lambda x: index.get(x["version"], 10**9))
    return norm


def pick_next_latest(sorted_prod_versions: List[Dict[str, Any]], exclude_version: str) -> Optional[Dict[str, Any]]:
    """Pick next latest: first non-quarantined, excluding target version.

    If there are exact SemVer duplicates, prefer TRUSTED over RELEASED.
    Input must be semver-desc sorted.
    """
    # Group by version string to apply TRUSTED preference for duplicates
    dup_map: Dict[str, List[Dict[str, Any]]] = {}
    for v in sorted_prod_versions:
        if v["version"] == exclude_version:
            continue
        if v.get("tag", "") == QUARANTINE_TAG:
            continue
        dup_map.setdefault(v["version"], []).append(v)
    if not dup_map:
        return None
    # Order by the existing order in sorted list
    seen: set[str] = set()
    ordered_unique: List[str] = []
    for v in sorted_prod_versions:
        vv = v["version"]
        if vv == exclude_version:
            continue
        if vv in dup_map and vv not in seen:
            ordered_unique.append(vv)
            seen.add(vv)
    # choose first unique version; within duplicates, prefer TRUSTED
    for ver in ordered_unique:
        cands = dup_map[ver]
        trusted = [c for c in cands if c.get("release_status") == TRUSTED]
        if trusted:
            return trusted[0]
        return cands[0]
    return None


def backup_tag_then_patch(client: AppTrustClient, app_key: str, version: str, backup_prop_key: str, new_tag: str, current_tag: str, dry_run: bool) -> None:
    """Back up current tag into properties under backup_prop_key, then patch new tag.

    Properties API expects arrays of strings.
    """
    props = {backup_prop_key: [current_tag]}
    if dry_run:
        print(f"[DRY-RUN] PATCH backup+tag: app={app_key} version={version} props={props} tag={new_tag}")
        return
    client.patch_application_version(app_key, version, tag=new_tag, properties=props)


def set_tag_only(client: AppTrustClient, app_key: str, version: str, tag: str, dry_run: bool) -> None:
    """Patch tag only. Idempotent; server will update if different."""
    if dry_run:
        print(f"[DRY-RUN] PATCH tag: app={app_key} version={version} tag={tag}")
        return
    client.patch_application_version(app_key, version, tag=tag)


def rollback_in_prod(client: AppTrustClient, app_key: str, target_version: str, dry_run: bool = False) -> None:
    """Perform rollback flow for `target_version` in PROD for `app_key`.

    Steps:
    1) Backup current tag to `original_tag_before_quarantine`, set tag to `quarantine`.
    2) If target had `latest`, select next SemVer-max non-quarantined and set its tag to `latest` backing up its tag to `original_tag_before_latest`.
    """
    prod_versions = get_prod_versions(client, app_key)
    by_version = {v["version"]: v for v in prod_versions}
    target = by_version.get(target_version)
    if target is None:
        raise RuntimeError(f"Target version not found in PROD set: {target_version}")

    current_tag = target.get("tag", "")
    had_latest = current_tag == LATEST_TAG

    # Step 1: quarantine target with backup
    backup_tag_then_patch(
        client,
        app_key,
        target_version,
        BACKUP_BEFORE_QUARANTINE,
        QUARANTINE_TAG,
        current_tag,
        dry_run,
    )

    # Step 2: if it had latest, reassign latest
    if had_latest:
        # Compute next candidate from existing list excluding target and quarantines
        next_candidate = pick_next_latest(prod_versions, exclude_version=target_version)
        if next_candidate is None:
            print("No successor found for latest; system will have no 'latest' until next promote.")
            return
        cand_ver = next_candidate["version"]
        cand_tag = next_candidate.get("tag", "")
        # Backup candidate's current tag then set latest
        backup_tag_then_patch(
            client,
            app_key,
            cand_ver,
            BACKUP_BEFORE_LATEST,
            LATEST_TAG,
            cand_tag,
            dry_run,
        )
        print(f"Reassigned latest to {cand_ver}")
    else:
        print("Rolled back non-latest version; 'latest' unchanged.")


# ------------------------- CLI -------------------------


def _env(name: str, default: Optional[str] = None) -> Optional[str]:
    v = os.environ.get(name)
    if v is None or v.strip() == "":
        return default
    return v.strip()


def main() -> int:
    parser = argparse.ArgumentParser(description="AppTrust PROD rollback utility")
    parser.add_argument("--app", required=True, help="Application key")
    parser.add_argument("--version", required=True, help="Target version to rollback (SemVer)")
    # OIDC-only path: no base-url or token arguments
    parser.add_argument("--dry-run", action="store_true", help="Log intended changes without mutating")
    args = parser.parse_args()

    try:
        client = AppTrustClientCLI()
    except Exception as e:
        print(f"OIDC (CLI) auth not available: {e}", file=sys.stderr)
        return 2

    try:
        start = time.time()
        rollback_in_prod(client, args.app, args.version, dry_run=args.dry_run)
        elapsed = time.time() - start
        print(f"Done in {elapsed:.2f}s")
        return 0
    except Exception as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
