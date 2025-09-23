

import json
import os
import sys
import urllib.request


def main() -> int:
    token = os.environ.get("GH_REPO_DISPATCH_TOKEN") or ""
    if not token:
        print("Missing GH_REPO_DISPATCH_TOKEN", file=sys.stderr)
        return 2
    owner = os.environ.get("GITHUB_OWNER", "yonatanp-jfrog")
    repo = os.environ.get("GITHUB_REPO", "bookverse-helm")
    event_type = os.environ.get("REPO_DISPATCH_EVENT", "release_completed")
    body = {"event_type": event_type, "client_payload": {"dry_run": True, "source": "validate-script"}}
    req = urllib.request.Request(
        url=f"https://api.github.com/repos/{owner}/{repo}/dispatches",
        data=json.dumps(body).encode("utf-8"),
        method="POST",
        headers={
            "Authorization": f"Bearer {token}",
            "Accept": "application/vnd.github+json",
            "Content-Type": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            code = resp.getcode()
    except Exception as e:
        print(f"Dispatch failed: {e}", file=sys.stderr)
        return 1
    print(f"Dispatch HTTP {code}")
    return 0 if code == 204 else 1


if __name__ == "__main__":
    raise SystemExit(main())


