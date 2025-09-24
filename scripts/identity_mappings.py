





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
from typing import Any, Dict, Iterable, List, Optional, Tuple




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
    def __init__(self, base_url: str, token: str, timeout_seconds: int = 300) -> None:
        self.base_url = base_url.rstrip("/")
        self.token = token
        self.timeout_seconds = timeout_seconds

    def _request(
        self,
        method: str,
        path: str,
        *,
        query: Optional[Dict[str, Any]] = None,
        body: Optional[Any] = None,
        accept: str = "application/json",
    ) -> HttpResponse:
        url = f"{self.base_url}{path}"
        if query:
            q = urllib.parse.urlencode({k: v for k, v in query.items() if v is not None})
            url = f"{url}?{q}"
        data = None
        headers = {
            "Authorization": f"Bearer {self.token}",
            "Accept": accept,
            "User-Agent": "bookverse-demo/identity-mappings",
        }
        if body is not None:
            if not isinstance(body, (bytes, bytearray)):
                body = json.dumps(body).encode("utf-8")
                headers["Content-Type"] = "application/json"
            data = body
        req = urllib.request.Request(url=url, data=data, method=method, headers=headers)
        try:
            with urllib.request.urlopen(req, timeout=self.timeout_seconds) as resp:
                raw = resp.read()
                content_type = resp.headers.get("Content-Type", "")
                parsed: Any
                if not raw:
                    parsed = None
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

    def list_oidc_providers(self) -> Tuple[int, Any]:
        resp = self._request("GET", "/access/api/v1/oidc")
        return resp.status, resp.body




def _flatten_strings(value: Any) -> Iterable[str]:
    if isinstance(value, str):
        yield value
        return
    if isinstance(value, dict):
        for v in value.values():
            yield from _flatten_strings(v)
        return
    if isinstance(value, list):
        for v in value:
            yield from _flatten_strings(v)
        return


def _contains_project_reference(obj: Any, project_key: str) -> bool:
    target = project_key.lower()
    for s in _flatten_strings(obj):
        if target in s.lower():
            return True
    return False


def _probe_mapping_list_endpoints(client: AccessClient, provider_name: str) -> List[Dict[str, Any]]:
    candidate_paths = [
        f"/access/api/v1/oidc/{urllib.parse.quote(provider_name)}/mappings",
        f"/access/api/v1/oidc/{urllib.parse.quote(provider_name)}/identity-mappings",
        f"/access/api/v1/identity-mappings",
        f"/access/api/v1/identity_mappings",
    ]
    for path in candidate_paths[:2]:
        resp = client._request("GET", path)
        if 200 <= resp.status < 300 and isinstance(resp.body, list):
            return list(resp.body)
        if resp.status == 404:
            continue
    for path in candidate_paths[2:]:
        resp = client._request("GET", path, query={"provider": provider_name})
        if 200 <= resp.status < 300:
            if isinstance(resp.body, list):
                return list(resp.body)
            if isinstance(resp.body, dict) and isinstance(resp.body.get("mappings"), list):
                return list(resp.body["mappings"])
        if resp.status == 404:
            continue
    return []


def _delete_mapping(client: AccessClient, provider_name: str, mapping: Dict[str, Any]) -> Tuple[bool, str]:
    mapping_id = str(mapping.get("id") or mapping.get("_id") or mapping.get("name") or "").strip()
    if not mapping_id:
        return False, "No mapping identifier found (id/name)"

    delete_candidates = [
        ("/access/api/v1/oidc/{provider}/mappings/{id}", True),
        ("/access/api/v1/oidc/{provider}/identity-mappings/{id}", True),
        ("/access/api/v1/identity-mappings/{id}", False),
        ("/access/api/v1/identity_mappings/{id}", False),
    ]
    for template, provider_scoped in delete_candidates:
        path = template.replace("{provider}", urllib.parse.quote(provider_name)).replace("{id}", urllib.parse.quote(mapping_id))
        resp = client._request("DELETE", path)
        if 200 <= resp.status < 300 or resp.status == 204:
            return True, f"Deleted via {path}"
        if resp.status in (404, 405):
            continue
        return False, f"HTTP {resp.status} deleting {path}: {json.dumps(resp.body) if not isinstance(resp.body, str) else resp.body}"
    return False, "No supported DELETE endpoint found"




def write_step_summary(lines: List[str]) -> None:
    summary_path = os.environ.get("GITHUB_STEP_SUMMARY")
    if not summary_path:
        return
    try:
        with open(summary_path, "a", encoding="utf-8") as fh:
            for line in lines:
                fh.write(line)
                if not line.endswith("\n"):
                    fh.write("\n")
    except Exception:
        pass


def op_discover(client: AccessClient, project_key: str) -> int:
    started = time.time()
    status, providers = client.list_oidc_providers()
    if not (200 <= status < 300) or not isinstance(providers, list):
        print(f"ERROR: Failed to list OIDC providers (HTTP {status}): {providers}", file=sys.stderr)
        write_step_summary([
            "### ❌ Identity Mappings (Discovery)",
            f"- Failed to list OIDC providers (HTTP {status})",
        ])
        return 1

    total_mappings = 0
    project_related: List[Tuple[str, Dict[str, Any]]] = []
    providers_summaries: List[str] = []

    for p in providers:
        name = str(p.get("name") or p.get("provider_name") or "").strip()
        if not name:
            continue
        mappings = _probe_mapping_list_endpoints(client, name)
        total_mappings += len(mappings)
        related = [m for m in mappings if _contains_project_reference(m, project_key)]
        for m in related:
            project_related.append((name, m))
        providers_summaries.append(f"- Provider `{name}`: {len(mappings)} mappings, {len(related)} related to `{project_key}`")

    duration = time.time() - started
    print(f"Providers: {len(providers)} | Mappings: {total_mappings} | Related to {project_key}: {len(project_related)} | {duration:.2f}s")
    write_step_summary([
        "### 🔎 Identity Mappings (Discovery)",
        f"- Providers: `{len(providers)}`",
        f"- Total mappings: `{total_mappings}`",
        f"- Related to `{project_key}`: `{len(project_related)}`",
        *providers_summaries,
    ])
    return 0


def op_cleanup(client: AccessClient, project_key: str, dry_run: bool) -> int:
    started = time.time()
    status, providers = client.list_oidc_providers()
    if not (200 <= status < 300) or not isinstance(providers, list):
        print(f"ERROR: Failed to list OIDC providers (HTTP {status}): {providers}", file=sys.stderr)
        write_step_summary([
            "### ❌ Identity Mappings (Cleanup)",
            f"- Failed to list OIDC providers (HTTP {status})",
        ])
        return 1

    attempted = 0
    deleted = 0
    errors: List[str] = []
    details: List[str] = []

    for p in providers:
        name = str(p.get("name") or p.get("provider_name") or "").strip()
        if not name:
            continue
        mappings = _probe_mapping_list_endpoints(client, name)
        related = [m for m in mappings if _contains_project_reference(m, project_key)]
        for m in related:
            attempted += 1
            if dry_run:
                ident = str(m.get("id") or m.get("name") or "<unknown>")
                details.append(f"- [DRY-RUN] Would delete mapping `{ident}` under provider `{name}`")
                continue
            ok, msg = _delete_mapping(client, name, m)
            if ok:
                deleted += 1
                ident = str(m.get("id") or m.get("name") or "<unknown>")
                details.append(f"- ✅ Deleted `{ident}` under provider `{name}`")
            else:
                ident = str(m.get("id") or m.get("name") or "<unknown>")
                err = f"- ❌ Failed to delete `{ident}` under provider `{name}`: {msg}"
                errors.append(err)
                details.append(err)

    duration = time.time() - started
    print(f"Attempted: {attempted} | Deleted: {deleted} | Errors: {len(errors)} | {duration:.2f}s")
    header = "### 🧹 Identity Mappings (Cleanup)"
    lines = [
        header,
        f"- Attempted: `{attempted}`",
        f"- Deleted: `{deleted}`",
        f"- Errors: `{len(errors)}`",
    ] + details
    write_step_summary(lines)

    if errors:
        return 2
    return 0


def parse_args(argv: Optional[List[str]] = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Identity mappings discovery and cleanup")
    sub = parser.add_subparsers(dest="command", required=True)

    common = argparse.ArgumentParser(add_help=False)
    common.add_argument("--base-url", default=_env("JFROG_URL"), help="Base JFrog URL, e.g. https://<host>")
    common.add_argument("--token", default=_env("JFROG_ADMIN_TOKEN"), help="JFrog admin token")
    common.add_argument("--project", required=True, help="Project key to search for in mappings (e.g. bookverse)")

    p_discover = sub.add_parser("discover", parents=[common], help="Discover identity mappings related to a project")
    p_cleanup = sub.add_parser("cleanup", parents=[common], help="Delete identity mappings related to a project")
    p_cleanup.add_argument("--dry-run", action="store_true", help="Show actions without deleting")

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
    if base.endswith("/access"):
        base_url = base
    else:
        base_url = f"{base}/access"

    client = AccessClient(base_url=base_url, token=args.token)

    try:
        if args.command == "discover":
            return op_discover(client, project_key=args.project)
        if args.command == "cleanup":
            return op_cleanup(client, project_key=args.project, dry_run=bool(args.dry_run))
        print(f"Unknown command: {args.command}", file=sys.stderr)
        return 2
    except Exception as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())


