#!/usr/bin/env python3
"""
Execute Cleanup driver for BookVerse demo.

Steps:
- Cleanup identity mappings (OIDC) that reference the project
- Cleanup project-scoped roles created by the demo
- Delete the project
- Verify deletion and fail if project remains

The script writes sections to $GITHUB_STEP_SUMMARY and exits non-zero on failure.

Usage:
  python execute_cleanup.py --project bookverse --base-url https://<host> --token <admin-token>

Safety:
  Requires --confirm DELETE (or env CONFIRM_CLEANUP=DELETE). Use --dry-run to preview.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
import urllib.parse
import urllib.request
from typing import Any, Dict, Optional


def _env(name: str, default: Optional[str] = None) -> Optional[str]:
    v = os.environ.get(name)
    if v is None or v.strip() == "":
        return default
    return v.strip()


def write_step_summary(lines: list[str]) -> None:
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


def http(method: str, url: str, token: str, body: Optional[Dict[str, Any]] = None, timeout: int = 30) -> tuple[int, Any, Dict[str, str]]:
    data = None
    headers = {
        "Authorization": f"Bearer {token}",
        "Accept": "application/json",
        "User-Agent": "bookverse-demo/execute-cleanup",
    }
    if body is not None:
        import json as _json

        data = _json.dumps(body).encode("utf-8")
        headers["Content-Type"] = "application/json"
    req = urllib.request.Request(url=url, data=data, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            raw = resp.read()
            ct = resp.headers.get("Content-Type", "")
            parsed: Any
            if not raw:
                parsed = None
            elif "application/json" in ct:
                import json as _json

                parsed = _json.loads(raw.decode("utf-8"))
            else:
                try:
                    import json as _json

                    parsed = _json.loads(raw.decode("utf-8"))
                except Exception:
                    parsed = raw.decode("utf-8", errors="replace")
            return getattr(resp, "status", 200), parsed, dict(resp.headers)
    except Exception as e:  # includes HTTPError and URLError
        from urllib.error import HTTPError

        if isinstance(e, HTTPError):
            raw = e.read().decode("utf-8", errors="replace")
            try:
                import json as _json

                parsed = _json.loads(raw)
            except Exception:
                parsed = {"raw": raw}
            return e.code, parsed, dict(e.headers or {})
        raise


def main(argv: Optional[list[str]] = None) -> int:
    parser = argparse.ArgumentParser(description="Execute cleanup driver")
    parser.add_argument("--project", required=True, help="Project key")
    parser.add_argument("--base-url", default=_env("JFROG_URL"), help="Base JFrog URL (e.g. https://<host>)")
    parser.add_argument("--token", default=_env("JFROG_ADMIN_TOKEN"), help="Admin access token")
    parser.add_argument("--confirm", default=_env("CONFIRM_CLEANUP"), help="Type DELETE to confirm")
    parser.add_argument("--dry-run", action="store_true", help="Preview actions without mutating")
    parser.add_argument("--role-prefix", default="bookverse-", help="Only delete roles with this prefix (non-built-in)")
    args = parser.parse_args(argv)

    if not args.base_url:
        print("Missing --base-url or JFROG_URL", file=sys.stderr)
        return 2
    if not args.token:
        print("Missing --token or JFROG_ADMIN_TOKEN", file=sys.stderr)
        return 2
    if (args.confirm or "").strip().upper() != "DELETE":
        write_step_summary(["### ❌ Cleanup Aborted", "- Confirmation not provided (expected `DELETE`)"])
        print("Cleanup not confirmed (expected DELETE)", file=sys.stderr)
        return 3

    started = time.time()
    project = args.project
    access_base = args.base_url.rstrip("/") + "/access"
    token = args.token

    write_step_summary(["## 🗑️ Execute Cleanup", f"- Project: `{project}`", f"- Dry run: `{args.dry_run}`"]) 

    # 1) Identity mappings cleanup
    import subprocess

    id_args = [
        sys.executable,
        os.path.join(os.path.dirname(__file__), "identity_mappings.py"),
        "cleanup",
        "--project",
        project,
        "--base-url",
        args.base_url,
        "--token",
        token,
    ]
    if args.dry_run:
        id_args.append("--dry-run")
    r1 = subprocess.run(id_args, capture_output=False)
    if r1.returncode not in (0,):
        print(f"Identity mapping cleanup returned {r1.returncode}", file=sys.stderr)

    # 2) Project roles cleanup
    pr_args = [
        sys.executable,
        os.path.join(os.path.dirname(__file__), "project_roles.py"),
        "cleanup",
        "--project",
        project,
        "--base-url",
        args.base_url,
        "--token",
        token,
        "--role-prefix",
        args.role_prefix,
    ]
    if args.dry_run:
        pr_args.append("--dry-run")
    r2 = subprocess.run(pr_args, capture_output=False)
    if r2.returncode not in (0,):
        print(f"Project roles cleanup returned {r2.returncode}", file=sys.stderr)

    # 3) Delete project (skip on dry-run)
    del_status = 0
    if not args.dry_run:
        url = f"{access_base}/api/v1/projects/{urllib.parse.quote(project)}"
        s, body, _ = http("DELETE", url, token)
        if s not in (200, 202, 204):
            del_status = s
            write_step_summary(["### ❌ Project Deletion", f"- HTTP {s}: {json.dumps(body) if not isinstance(body, str) else body}"])
        else:
            write_step_summary(["### ✅ Project Deletion", f"- HTTP {s}"])
    else:
        write_step_summary(["### ℹ️ Project Deletion", "- Skipped due to dry-run"])

    # 4) Verify deletion (GET should return 404)
    verify_code = 0
    if not args.dry_run:
        url = f"{access_base}/api/v1/projects/{urllib.parse.quote(project)}"
        s, body, _ = http("GET", url, token)
        if s == 404:
            write_step_summary(["### ✅ Verification", "- Project no longer exists (404)"])
        else:
            verify_code = 1
            write_step_summary(["### ❌ Verification", f"- Project still exists or unexpected code: HTTP {s}"])
    else:
        write_step_summary(["### ℹ️ Verification", "- Skipped due to dry-run"])

    elapsed = time.time() - started
    write_step_summary(["### ⏱️ Timing", f"- Completed in `{elapsed:.2f}s`"])

    # Exit status: any non-zero from subtasks or verification => fail
    if any(rc not in (0,) for rc in (r1.returncode, r2.returncode)) or del_status or verify_code:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())


