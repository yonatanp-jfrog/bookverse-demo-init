#!/usr/bin/env python3
"""
Project roles discovery and cleanup utility for JFrog Access.

Functions:
- List project roles for a given project key
- Delete project-scoped roles created by the demo (optionally filter by prefix)
- Emit GitHub step summary for visibility in CI logs

Requirements:
- JFROG_URL (base), JFROG_ADMIN_TOKEN

Usage:
  python project_roles.py discover --project bookverse
  python project_roles.py cleanup --project bookverse --dry-run
  python project_roles.py cleanup --project bookverse --role-prefix bookverse-
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from typing import Any, Dict, List, Optional


def _env(name: str, default: Optional[str] = None) -> Optional[str]:
    v = os.environ.get(name)
    if v is None or v.strip() == "":
        return default
    return v.strip()


@dataclass
class HttpResponse:
    status: int
    headers: Dict[str, str]
    body: Any


class AccessClient:
    def __init__(self, base_url: str, token: str, timeout_seconds: int = 30) -> None:
        self.base_url = base_url.rstrip("/")
        self.token = token
        self.timeout_seconds = timeout_seconds

    def _request(self, method: str, path: str, *, query: Optional[Dict[str, Any]] = None, body: Optional[Any] = None) -> HttpResponse:
        url = f"{self.base_url}{path}"
        if query:
            q = urllib.parse.urlencode({k: v for k, v in query.items() if v is not None})
            url = f"{url}?{q}"
        data = None
        headers = {
            "Authorization": f"Bearer {self.token}",
            "Accept": "application/json",
            "User-Agent": "bookverse-demo/project-roles",
        }
        if body is not None:
            data = json.dumps(body).encode("utf-8")
            headers["Content-Type"] = "application/json"
        req = urllib.request.Request(url=url, data=data, method=method, headers=headers)
        try:
            with urllib.request.urlopen(req, timeout=self.timeout_seconds) as resp:
                raw = resp.read()
                content_type = resp.headers.get("Content-Type", "")
                if not raw:
                    parsed: Any = None
                elif "application/json" in content_type:
                    parsed = json.loads(raw.decode("utf-8"))
                else:
                    try:
                        parsed = json.loads(raw.decode("utf-8"))
                    except Exception:
                        parsed = raw.decode("utf-8", errors="replace")
                return HttpResponse(status=getattr(resp, "status", 200), headers=dict(resp.headers), body=parsed)
        except urllib.error.HTTPError as e:
            err_body = e.read().decode("utf-8", errors="replace")
            try:
                parsed = json.loads(err_body)
            except Exception:
                parsed = {"raw": err_body}
            return HttpResponse(status=e.code, headers=dict(e.headers or {}), body=parsed)
        except urllib.error.URLError as e:
            raise RuntimeError(f"Network error for {method} {url}: {e}") from None

    # API methods
    def list_project_roles(self, project_key: str) -> HttpResponse:
        return self._request("GET", f"/access/api/v1/projects/{urllib.parse.quote(project_key)}/roles")

    def delete_project_role(self, project_key: str, role_name: str) -> HttpResponse:
        return self._request("DELETE", f"/access/api/v1/projects/{urllib.parse.quote(project_key)}/roles/{urllib.parse.quote(role_name)}")


def write_step_summary(lines: List[str]) -> None:
    path = os.environ.get("GITHUB_STEP_SUMMARY")
    if not path:
        return
    try:
        with open(path, "a", encoding="utf-8") as fh:
            for line in lines:
                fh.write(line)
                if not line.endswith("\n"):
                    fh.write("\n")
    except Exception:
        pass


def op_discover(client: AccessClient, project: str) -> int:
    started = time.time()
    resp = client.list_project_roles(project)
    if not (200 <= resp.status < 300) or not isinstance(resp.body, list):
        print(f"ERROR: Failed to list project roles (HTTP {resp.status}): {resp.body}", file=sys.stderr)
        write_step_summary(["### ❌ Project Roles (Discovery)", f"- Failed to list roles for `{project}` (HTTP {resp.status})"])
        return 1
    roles: List[Dict[str, Any]] = list(resp.body)
    print(json.dumps({"project": project, "role_count": len(roles), "roles": roles}, indent=2))
    write_step_summary([
        "### 🔎 Project Roles (Discovery)",
        f"- Project: `{project}`",
        f"- Roles found: `{len(roles)}`",
        *[f"- `{r.get('name')}`" for r in roles if isinstance(r, dict)],
    ])
    return 0


def op_cleanup(client: AccessClient, project: str, dry_run: bool, role_prefix: Optional[str]) -> int:
    started = time.time()
    resp = client.list_project_roles(project)
    if not (200 <= resp.status < 300) or not isinstance(resp.body, list):
        print(f"ERROR: Failed to list project roles (HTTP {resp.status}): {resp.body}", file=sys.stderr)
        write_step_summary(["### ❌ Project Roles (Cleanup)", f"- Failed to list roles for `{project}` (HTTP {resp.status})"])
        return 1
    roles: List[Dict[str, Any]] = list(resp.body)
    targets: List[str] = []
    for r in roles:
        name = str(r.get("name") or "").strip()
        if not name:
            continue
        if role_prefix and not name.startswith(role_prefix):
            continue
        # Skip built-in roles by convention (common names); adjust as needed
        builtin = {"Developer", "Contributor", "Viewer", "Release Manager", "Security Manager", "Application Admin", "Project Admin"}
        if name in builtin:
            continue
        targets.append(name)

    attempted = 0
    deleted = 0
    errors: List[str] = []
    details: List[str] = []

    for name in targets:
        attempted += 1
        if dry_run:
            details.append(f"- [DRY-RUN] Would delete project role `{name}`")
            continue
        d = client.delete_project_role(project, name)
        if 200 <= d.status < 300 or d.status == 204:
            deleted += 1
            details.append(f"- ✅ Deleted `{name}`")
        else:
            msg = json.dumps(d.body) if not isinstance(d.body, str) else d.body
            err = f"- ❌ Failed to delete `{name}` (HTTP {d.status}): {msg}"
            errors.append(err)
            details.append(err)

    duration = time.time() - started
    print(f"Attempted: {attempted} | Deleted: {deleted} | Errors: {len(errors)} | {duration:.2f}s")
    write_step_summary(["### 🧹 Project Roles (Cleanup)", f"- Attempted: `{attempted}`", f"- Deleted: `{deleted}`", f"- Errors: `{len(errors)}`", *details])
    return 2 if errors else 0


def parse_args(argv: Optional[List[str]] = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Project roles discovery and cleanup")
    sub = parser.add_subparsers(dest="command", required=True)

    common = argparse.ArgumentParser(add_help=False)
    common.add_argument("--base-url", default=_env("JFROG_URL"), help="Base JFrog URL, e.g. https://<host>")
    common.add_argument("--token", default=_env("JFROG_ADMIN_TOKEN"), help="JFrog admin token")
    common.add_argument("--project", required=True, help="Project key (e.g. bookverse)")

    sub.add_parser("discover", parents=[common], help="List project roles for a project")
    p_cleanup = sub.add_parser("cleanup", parents=[common], help="Delete non-built-in project roles")
    p_cleanup.add_argument("--dry-run", action="store_true", help="Show actions without deleting")
    p_cleanup.add_argument("--role-prefix", help="Only delete roles starting with this prefix")

    return parser.parse_args(argv)


def main(argv: Optional[List[str]] = None) -> int:
    args = parse_args(argv)
    if not args.base_url:
        print("Missing --base-url or JFROG_URL", file=sys.stderr)
        return 2
    if not args.token:
        print("Missing --token or JFROG_ADMIN_TOKEN", file=sys.stderr)
        return 2
    base = args.base_url.rstrip("/")
    base_url = f"{base}/access" if not base.endswith("/access") else base
    client = AccessClient(base_url, args.token)
    try:
        if args.command == "discover":
            return op_discover(client, args.project)
        if args.command == "cleanup":
            return op_cleanup(client, args.project, bool(args.dry_run), args.role_prefix)
        print(f"Unknown command: {args.command}", file=sys.stderr)
        return 2
    except Exception as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())


