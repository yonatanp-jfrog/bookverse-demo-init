import sys
import unittest
from pathlib import Path

# Ensure scripts directory is importable
SCRIPT_DIR = Path(__file__).resolve().parent
SCRIPTS_DIR = SCRIPT_DIR.parent
sys.path.insert(0, str(SCRIPTS_DIR))

import apptrust_rollback as ar  # noqa: E402


class FakeClient:
    def __init__(self, versions):
        # versions: list of dicts with keys: version, tag, release_status, properties (optional)
        self._versions = {v["version"]: {
            "version": v["version"],
            "tag": v.get("tag", ""),
            "release_status": v.get("release_status", "RELEASED"),
            "properties": dict(v.get("properties", {})),
        } for v in versions}
        self.patched = []

    def list_application_versions(self, app_key, limit=1000):
        return {"versions": list(self._versions.values())}

    def patch_application_version(self, app_key, version, tag=None, properties=None, delete_properties=None):
        v = self._versions[version]
        if properties is not None:
            for k, vals in properties.items():
                v["properties"][k] = list(vals)
        if delete_properties:
            for k in delete_properties:
                v["properties"].pop(k, None)
        if tag is not None:
            v["tag"] = tag
        self.patched.append({
            "app_key": app_key,
            "version": version,
            "tag": tag,
            "properties": properties,
            "delete_properties": delete_properties,
        })
        return {
            "application_key": app_key,
            "version": version,
            "tag": v["tag"],
            "properties": v["properties"],
        }


class RollbackFlowTests(unittest.TestCase):
    def test_scenario_a_rollback_latest_promotes_next(self):
        # Start: 1.4.0 latest, 1.3.2 normal
        client = FakeClient([
            {"version": "1.4.0", "tag": ar.LATEST_TAG, "release_status": ar.RELEASED},
            {"version": "1.3.2", "tag": "1.3.2", "release_status": ar.RELEASED},
        ])
        ar.rollback_in_prod(client, app_key="app", target_version="1.4.0", dry_run=False)

        v140 = client._versions["1.4.0"]
        v132 = client._versions["1.3.2"]

        # 1.4.0 backed up and quarantined
        self.assertEqual(v140["tag"], ar.QUARANTINE_TAG)
        self.assertEqual(v140["properties"].get(ar.BACKUP_BEFORE_QUARANTINE), [ar.LATEST_TAG])

        # 1.3.2 promoted to latest and backed up
        self.assertEqual(v132["tag"], ar.LATEST_TAG)
        self.assertEqual(v132["properties"].get(ar.BACKUP_BEFORE_LATEST), ["1.3.2"])

    def test_scenario_b_rollback_non_latest_does_not_change_latest(self):
        client = FakeClient([
            {"version": "1.4.0", "tag": ar.LATEST_TAG, "release_status": ar.RELEASED},
            {"version": "1.3.2", "tag": "1.3.2", "release_status": ar.RELEASED},
        ])
        ar.rollback_in_prod(client, app_key="app", target_version="1.3.2", dry_run=False)

        v140 = client._versions["1.4.0"]
        v132 = client._versions["1.3.2"]
        # 1.3.2 quarantined and backed up
        self.assertEqual(v132["tag"], ar.QUARANTINE_TAG)
        self.assertEqual(v132["properties"].get(ar.BACKUP_BEFORE_QUARANTINE), ["1.3.2"])
        # 1.4.0 remains latest
        self.assertEqual(v140["tag"], ar.LATEST_TAG)

    def test_scenario_c_only_one_version_results_in_no_latest(self):
        client = FakeClient([
            {"version": "1.4.0", "tag": ar.LATEST_TAG, "release_status": ar.RELEASED},
        ])
        ar.rollback_in_prod(client, app_key="app", target_version="1.4.0", dry_run=False)

        v140 = client._versions["1.4.0"]
        # quarantined and backed up
        self.assertEqual(v140["tag"], ar.QUARANTINE_TAG)
        self.assertEqual(v140["properties"].get(ar.BACKUP_BEFORE_QUARANTINE), [ar.LATEST_TAG])
        # No other versions to hold latest
        # Ensure no version has latest
        self.assertTrue(all(v["tag"] != ar.LATEST_TAG for v in client._versions.values()))


if __name__ == "__main__":
    unittest.main()
