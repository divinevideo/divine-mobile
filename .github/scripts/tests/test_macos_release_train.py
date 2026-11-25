"""Tests for automated macOS release-train allocation, provenance, policy, and submission."""

from __future__ import annotations

import hashlib
import json
import subprocess
import sys
import tempfile
import unittest
from datetime import UTC, datetime
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[3]
SCRIPTS = ROOT / "mobile/scripts"
if str(SCRIPTS) not in sys.path:
    sys.path.insert(0, str(SCRIPTS))
TESTS_DIR = Path(__file__).resolve().parent
if str(TESTS_DIR) not in sys.path:
    sys.path.insert(0, str(TESTS_DIR))

from allocate_build_identity import allocate_build
from record_macos_provenance import record_provenance
from release_identity import main as release_identity_main
from release_train.coordinator import (
    DAY,
    HOUR,
    PRODUCTION_INTERVAL,
    TESTFLIGHT_INTERVAL,
    plan_tick,
)
from release_train.ledger import BOOTSTRAP_PATH
from release_train.providers import Apple, ProviderError
from release_train.release_notes import (
    ReleaseNotesError,
    _identity as notes_identity,
    ensure_bundle,
    production_build as notes_production_build,
)
from release_train.runner import Runtime, UnmappedBuild, execute_plan, reconcile_operations
from release_train_fakes import release_notes_bundle

SHA_OLD = "a" * 40
SHA_NEW = "b" * 40
PKG_DIGEST = hashlib.sha256(b"signed-mas-pkg").hexdigest()


class MemoryLedger:
    def __init__(self, files=None):
        self.files = dict(files or {})

    def paths(self):
        return frozenset(self.files)

    def refresh(self):
        return self.paths()

    def read_json(self, path):
        return json.loads(json.dumps(self.files[path]))

    def create_json(self, path, record, message):
        if path in self.files:
            return False
        self.files[path] = json.loads(json.dumps(record))
        return True


class MacosReleaseTrainTest(unittest.TestCase):
    def test_allocate_build_identity_for_macos_uses_mac_os_platform_and_skips_shorebird(self):
        seen_commands = []

        def fake_run(cmd, capture_output=False, text=False, check=False):
            seen_commands.append(cmd)
            if cmd[:2] == ["app-store-connect", "get-latest-testflight-build-number"]:
                return subprocess.CompletedProcess(cmd, 0, stdout="", stderr="No build")
            if cmd[:3] == ["app-store-connect", "apps", "app-store-versions"]:
                return subprocess.CompletedProcess(cmd, 0, stdout="[]", stderr="")
            if cmd[:3] == ["git", "ls-remote", "--tags"]:
                return subprocess.CompletedProcess(cmd, 0, stdout="", stderr="")
            if cmd[:2] == ["git", "rev-parse"]:
                return subprocess.CompletedProcess(cmd, 0, stdout=SHA_NEW + "\n", stderr="")
            raise AssertionError(f"Unexpected command: {cmd}")

        captured_args = []

        def fake_identity_main(args):
            captured_args.extend(args)
            return 0

        with tempfile.TemporaryDirectory() as directory:
            old_cwd = Path.cwd()
            try:
                import os

                os.chdir(directory)
                with patch("allocate_build_identity.identity_main", side_effect=fake_identity_main):
                    rc = allocate_build(
                        "macos",
                        env={
                            "CM_BUILD_ID": "1" * 24,
                            "PROJECT_BUILD_NUMBER": "912",
                            "RELEASE_TRAIN_RESERVATION_KEY": f"scheduled/macos/{SHA_NEW}",
                        },
                        run=fake_run,
                    )
            finally:
                os.chdir(old_cwd)

        self.assertEqual(rc, 0)
        self.assertFalse(any(cmd[0] == "shorebird" for cmd in seen_commands))
        self.assertIn(
            ["app-store-connect", "get-latest-testflight-build-number", "--platform", "MAC_OS", "6747959501"],
            seen_commands,
        )
        self.assertIn(
            ["app-store-connect", "apps", "app-store-versions", "6747959501", "--platform", "MAC_OS", "--json"],
            seen_commands,
        )
        self.assertIn("--platform", captured_args)
        self.assertEqual(captured_args[captured_args.index("--platform") + 1], "macos")
        self.assertEqual(captured_args[captured_args.index("--store-latest-build") + 1], "0")
        self.assertEqual(captured_args[captured_args.index("--build-number-floor") + 1], "912")
        self.assertNotIn("--shorebird-releases", captured_args)

    def test_record_macos_provenance_creates_immutable_pkg_record(self):
        ledger = MemoryLedger()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            env_file = root / "macos_release.env"
            env_file.write_text(
                f"SHOREBIRD_BUILD_NAME=1.0.37\n"
                f"SHOREBIRD_BUILD_NUMBER=912\n"
                f"SHOREBIRD_RELEASE_VERSION=1.0.37+912\n"
                f"RELEASE_SOURCE_SHA={SHA_NEW}\n",
                encoding="utf-8",
            )
            pkg_dir = root / "pkg"
            pkg_dir.mkdir()
            (pkg_dir / "Divine.pkg").write_bytes(b"signed-mas-pkg")
            out_file = root / "macos_provenance.json"

            record = record_provenance(
                release_env_path=env_file,
                pkg_dir=pkg_dir,
                output_path=out_file,
                env={
                    "CM_BUILD_ID": "2" * 24,
                    "CM_WORKFLOW_ID": "macos-scheduled-build",
                    "DEFAULT_ENV": "PRODUCTION",
                },
                ledger=ledger,
                source_sha=SHA_NEW,
                now=datetime(2026, 11, 25, tzinfo=UTC),
            )
            self.assertEqual(record["platform"], "macos")
            self.assertEqual(record["release_version"], "1.0.37+912")
            self.assertEqual(record["default_env"], "PRODUCTION")
            self.assertEqual(record["pkg_sha256"], PKG_DIGEST)
            self.assertIs(record["patchable"], False)
            self.assertIn("releases/macos/1.0.37+912.json", ledger.files)
            self.assertTrue(out_file.is_file())

            with self.assertRaisesRegex(ValueError, "already exists"):
                record_provenance(
                    release_env_path=env_file,
                    pkg_dir=pkg_dir,
                    output_path=out_file,
                    env={
                        "CM_BUILD_ID": "2" * 24,
                        "CM_WORKFLOW_ID": "macos-scheduled-build",
                        "DEFAULT_ENV": "PRODUCTION",
                    },
                    ledger=ledger,
                    source_sha=SHA_NEW,
                )

            with self.assertRaisesRegex(ValueError, "DEFAULT_ENV"):
                record_provenance(
                    release_env_path=env_file,
                    pkg_dir=pkg_dir,
                    output_path=out_file,
                    env={"CM_BUILD_ID": "2" * 24, "CM_WORKFLOW_ID": "macos-build"},
                    ledger=MemoryLedger(),
                    source_sha=SHA_NEW,
                )

            staging_env = root / "macos_staging.env"
            staging_env.write_text(
                f"SHOREBIRD_BUILD_NAME=1.0.37\n"
                f"SHOREBIRD_BUILD_NUMBER=913\n"
                f"SHOREBIRD_RELEASE_VERSION=1.0.37+913\n"
                f"RELEASE_SOURCE_SHA={SHA_NEW}\n",
                encoding="utf-8",
            )
            staging_record = record_provenance(
                release_env_path=staging_env,
                pkg_dir=pkg_dir,
                output_path=out_file,
                env={
                    "CM_BUILD_ID": "3" * 24,
                    "CM_WORKFLOW_ID": "macos-build",
                    "DEFAULT_ENV": "STAGING",
                },
                ledger=ledger,
                source_sha=SHA_NEW,
            )
            self.assertEqual(staging_record["default_env"], "STAGING")

    def test_coordinator_plans_macos_build_beta_and_app_store_independently_of_ios(self):
        now = 2_000_000
        snapshot = {
            "now": now,
            "ci_passed": True,
            "candidate": SHA_NEW,
            "changes": {"ios": False, "macos": True, "android": False},
            "cm": [],
            "ios": {},
            "macos": {
                "group_valid": True,
                "builds": [
                    {
                        "id": "mb1",
                        "number": 912,
                        "version": "1.0.37",
                        "sha": SHA_OLD,
                        "default_env": "PRODUCTION",
                        "valid": True,
                        "ci_verified": True,
                        "public": False,
                        "public_complete": False,
                        "groups": [],
                        "external": "READY_FOR_BETA_SUBMISSION",
                    }
                ],
                "versions": [
                    {"id": "mv1", "version": "1.0.0", "state": "PREPARE_FOR_SUBMISSION", "build_id": None}
                ],
                "submissions": [],
                "review_submissions": [],
            },
            "android": {},
        }
        plan = plan_tick(snapshot, {}, {"ios": "off", "macos": "app-store", "android": "off"})
        kinds = {(a["platform"], a["kind"]) for a in plan["actions"]}
        self.assertEqual(
            kinds,
            {("macos", "build"), ("macos", "public-beta"), ("macos", "app-store")},
        )

    def test_apple_submit_store_omits_whats_new_on_first_macos_release_and_sends_after_live(self):
        notes = [{"language": "en-US", "text": "Faster startup and smoother playback on Mac."}]

        def run_submit(versions):
            calls = []

            class StubApple(Apple):
                def __init__(self):
                    self.headers = {}
                    self.group = "g1"
                    self.groups = ["g1"]

                def pages(self, path):
                    if path.endswith("/appInfos"):
                        return [{"id": "ai1"}]
                    if path.endswith("/appInfoLocalizations"):
                        return [{"attributes": {"locale": "en-US"}}]
                    if path.endswith("/appStoreVersionLocalizations"):
                        return [{"id": "loc1", "attributes": {"locale": "en-US"}}]
                    return []

                def call(self, method, path, body=None):
                    calls.append((method, path, body))
                    if method == "POST" and path == "/appStoreVersions":
                        return {"data": {"id": "mv-new"}}
                    if method == "POST" and path == "/reviewSubmissions":
                        return {"data": {"id": "rs-new"}}
                    if method == "GET" and path.endswith("/appStoreVersionPhasedRelease"):
                        return {"data": None}
                    return {"data": {"id": "ok"}}

            apple = StubApple()
            build = {"id": "mb1", "number": 912, "version": "1.0.37"}
            apple.submit_store(build, versions, [], notes=notes, reviews=[], platform="macos")
            return calls

        first_calls = run_submit(
            [{"id": "mv1", "version": "1.0", "state": "PREPARE_FOR_SUBMISSION", "build_id": None}]
        )
        self.assertFalse(
            any(path.startswith("/appStoreVersionLocalizations/") for _, path, _ in first_calls),
            "First macOS App Store submission must omit whatsNew",
        )
        review_post = next(body for m, p, body in first_calls if m == "POST" and p == "/reviewSubmissions")
        self.assertEqual(review_post["data"]["attributes"]["platform"], "MAC_OS")

        update_calls = run_submit(
            [{"id": "mv1", "version": "1.0.37", "state": "READY_FOR_SALE", "build_id": "mb0"}]
        )
        version_post = next(body for m, p, body in update_calls if m == "POST" and p == "/appStoreVersions")
        self.assertEqual(version_post["data"]["attributes"]["platform"], "MAC_OS")
        self.assertTrue(
            any(
                m == "PATCH" and p == "/appStoreVersionLocalizations/loc1" and "whatsNew" in b["data"]["attributes"]
                for m, p, b in update_calls
            ),
            "Subsequent macOS App Store releases must populate whatsNew",
        )

    def test_runner_macos_snapshot_filters_platform_and_handles_historical_pre_train_build(self):
        requested_urls = []

        class FakeApple:
            def __init__(self):
                self.group = "g1"
                self.groups = ["g1"]

            def call(self, method, path, body=None):
                requested_urls.append(path)
                if path.startswith("/betaGroups/"):
                    return {"data": {"attributes": {"isInternalGroup": False, "publicLinkEnabled": True, "publicLink": "https://testflight.apple.com/join/x"}}}
                if path.endswith("/build"):
                    return {"data": None}
                return {"data": {}}

            def pages(self, path):
                requested_urls.append(path)
                return []

            def pages_including(self, path):
                requested_urls.append(path)
                return (
                    [
                        {
                            "id": "mb911",
                            "attributes": {"version": "911", "processingState": "VALID", "expired": False},
                            "relationships": {
                                "preReleaseVersion": {"data": {"type": "preReleaseVersions", "id": "prv1"}}
                            },
                        }
                    ],
                    {("preReleaseVersions", "prv1"): {"attributes": {"version": "1.0.37"}}},
                )

        runtime = Runtime.__new__(Runtime)
        runtime.apple = FakeApple()
        runtime.ledger = MemoryLedger()

        snap = runtime.apple_snapshot("macos")
        self.assertTrue(any("filter%5BpreReleaseVersion.platform%5D=MAC_OS" in u for u in requested_urls))
        self.assertTrue(any("/reviewSubmissions?filter[platform]=MAC_OS" in u for u in requested_urls))
        self.assertTrue(any("/appStoreVersions?filter[platform]=MAC_OS" in u for u in requested_urls))
        self.assertEqual(len(snap["builds"]), 1)
        self.assertTrue(snap["builds"][0]["legacy"])
        self.assertFalse(snap["builds"][0]["valid"])

    def test_runner_macos_snapshot_fails_when_ios_rejected_testflight_groups(self):
        snapshotted = []

        class FakeApple:
            def __init__(self, token, group):
                self.group = group
                self.groups = []

        runtime = Runtime.__new__(Runtime)
        runtime.env = {"TESTFLIGHT_GROUP_IDS": json.dumps(["unexpected-group"])}
        runtime.apple = None
        runtime.play = None
        runtime.list_builds = lambda: []
        runtime.candidate = lambda: None
        runtime.apple_snapshot = lambda platform: snapshotted.append(platform) or {}

        with (
            patch("release_train.runner.apple_token", return_value="token"),
            patch("release_train.runner.Apple", FakeApple),
        ):
            snap = runtime.snapshot({}, {"ios": "testflight", "macos": "testflight"})

        self.assertEqual(snapshotted, [])
        for platform in ("ios", "macos"):
            self.assertIn("four existing external audiences", snap[platform]["error"])

    def test_runner_identity_verifies_macos_pkg_provenance(self):
        ledger = MemoryLedger(
            {
                "allocations/builds/macos/912.json": {
                    "platform": "macos",
                    "version": "1.0.37",
                    "source_sha": SHA_NEW,
                    "reservation_key": f"scheduled/macos/{SHA_NEW}",
                },
                "releases/macos/1.0.37+912.json": {
                    "platform": "macos",
                    "release_version": "1.0.37+912",
                    "build_source_commit": SHA_NEW,
                    "default_env": "PRODUCTION",
                    "patchable": False,
                    "pkg_sha256": PKG_DIGEST,
                },
            }
        )
        runtime = Runtime.__new__(Runtime)
        runtime.ledger = ledger
        identity = runtime.identity("macos", 912, "1.0.37")
        self.assertEqual(
            identity,
            {
                "number": 912,
                "version": "1.0.37",
                "sha": SHA_NEW,
                "default_env": "PRODUCTION",
            },
        )

    def test_runner_execute_dispatches_macos_scheduled_build_with_macos_inputs(self):
        cm_calls = []

        class FakeTags:
            def call(self, method, path, body=None):
                return {"object": {"type": "commit", "sha": SHA_NEW}}

        runtime = Runtime.__new__(Runtime)
        runtime.tags = FakeTags()
        runtime.cm = lambda method, path, body=None: (cm_calls.append((method, path, body)) or {"data": {"id": "3" * 24}})
        bundle = release_notes_bundle("macos", SHA_NEW) | {"baseline": {"version": "1.0.36", "sha": SHA_OLD}}
        action = {
            "kind": "build",
            "platform": "macos",
            "sha": SHA_NEW,
            "attempt": 1,
            "release_notes": bundle,
        }
        result = runtime.execute(action, {}, {"now": 2_000_000})
        self.assertEqual(result, {"build_id": "3" * 24})
        self.assertEqual(len(cm_calls), 1)
        payload = cm_calls[0][2]
        self.assertEqual(payload["workflow_id"], "macos-scheduled-build")
        self.assertEqual(payload["inputs"], {"DEFAULT_ENV": "PRODUCTION"})
        self.assertEqual(payload["labels"], [f"release-train:macos:{SHA_NEW}:1"])

    def test_release_notes_macos_falls_back_to_ios_baseline_before_first_live_macos_release(self):
        ledger = MemoryLedger()
        ios_data = {
            "versions": [{"id": "iv1", "version": "1.0.36", "state": "READY_FOR_SALE", "build_id": "ib1"}],
            "builds": [{"id": "ib1", "version": "1.0.36", "sha": SHA_OLD}],
        }
        generated = release_notes_bundle("macos", SHA_NEW) | {"baseline": {"version": "1.0.36", "sha": SHA_OLD}}
        with (
            patch("release_train.release_notes._production_data", return_value=ios_data) as mock_prod,
            patch("release_train.release_notes._check_ancestry"),
            patch("release_train.release_notes._apple_locales", return_value=["en-US"]),
            patch("release_train.release_notes._generate", return_value=generated),
        ):
            bundle = ensure_bundle(
                "macos",
                SHA_NEW,
                data={"versions": [], "builds": []},
                env={},
                ledger=ledger,
            )
        mock_prod.assert_called_once_with("ios", {}, ledger)
        self.assertEqual(bundle["platform"], "macos")
        self.assertEqual(bundle["baseline"], {"version": "1.0.36", "sha": SHA_OLD})
        self.assertTrue(
            any(p.startswith(f"release-notes/macos-prelaunch/{SHA_NEW}/") for p in ledger.files)
        )
        self.assertFalse(
            any(p.startswith(f"release-notes/macos/{SHA_NEW}/") for p in ledger.files)
        )

    def test_release_notes_macos_live_legacy_version_without_provenance_does_not_fall_back(self):
        live_legacy = {
            "versions": [{"id": "mv1", "version": "1.0.37", "state": "READY_FOR_SALE", "build_id": "mb911"}],
            "builds": [{"id": "mb911", "version": "1.0.37", "sha": None, "legacy": True}],
        }
        with (
            patch("release_train.release_notes._production_data") as mock_prod,
            patch("release_train.release_notes._check_ancestry"),
            patch("release_train.release_notes._generate") as mock_generate,
        ):
            with self.assertRaisesRegex(ReleaseNotesError, "missing verified source provenance"):
                ensure_bundle("macos", SHA_NEW, data=live_legacy, env={}, ledger=MemoryLedger())
        mock_prod.assert_not_called()
        mock_generate.assert_not_called()

    def test_release_train_workflow_wires_release_train_macos_variable(self):
        workflow_text = (ROOT / ".github/workflows/release_train.yml").read_text(encoding="utf-8")
        self.assertIn("vars.RELEASE_TRAIN_MACOS != '' && vars.RELEASE_TRAIN_MACOS != 'off'", workflow_text)
        self.assertIn("RELEASE_TRAIN_MACOS: ${{ vars.RELEASE_TRAIN_MACOS }}", workflow_text)

    def test_macos_obeys_12h_build_and_testflight_cadence_and_48h_app_store_spacing_independently_of_ios(self):
        now = 3_000_000
        macos_build = {
            "id": "mb1",
            "number": 912,
            "version": "1.0.37",
            "sha": SHA_OLD,
            "default_env": "PRODUCTION",
            "valid": True,
            "ci_verified": True,
            "public": False,
            "public_complete": False,
            "groups": [],
            "external": "READY_FOR_BETA_SUBMISSION",
        }
        snapshot = {
            "now": now,
            "ci_passed": True,
            "candidate": SHA_NEW,
            "changes": {"ios": False, "macos": True, "android": False},
            "cm": [],
            "ios": {},
            "macos": {
                "group_valid": True,
                "builds": [macos_build],
                "versions": [
                    {"id": "mv1", "version": "1.0.0", "state": "PREPARE_FOR_SUBMISSION", "build_id": None}
                ],
                "submissions": [],
                "review_submissions": [],
            },
            "android": {},
        }
        # Recent iOS build/public-beta/app-store operations must NOT throttle macOS.
        ios_only_state = {
            "last_build_started": {"ios": now - 60},
            "app_store_submissions": [now - 60],
            "operations": {
                "public-beta:ios:10": {
                    "action": {"kind": "public-beta", "platform": "ios", "build": {"id": "ib10", "number": 10}},
                    "started_at": now - 60,
                    "cadence_at": now - 60,
                    "status": "done",
                },
                "app-store:ios:10": {
                    "action": {"kind": "app-store", "platform": "ios", "build": {"id": "ib10", "number": 10}},
                    "started_at": now - 60,
                    "status": "done",
                },
            },
        }
        plan = plan_tick(snapshot, ios_only_state, {"ios": "off", "macos": "app-store", "android": "off"})
        self.assertEqual(
            {(a["platform"], a["kind"]) for a in plan["actions"]},
            {("macos", "build"), ("macos", "public-beta"), ("macos", "app-store")},
        )

        # macOS itself respects 12h build + TestFlight cadence and 48h App Store spacing.
        macos_recent_state = {
            "last_build_started": {"macos": now - (TESTFLIGHT_INTERVAL - 1)},
            "macos_app_store_submissions": [now - (PRODUCTION_INTERVAL - 1)],
            "operations": {
                "public-beta:macos:911": {
                    "action": {"kind": "public-beta", "platform": "macos", "build": {"id": "mb911", "number": 911}},
                    "started_at": now - (TESTFLIGHT_INTERVAL - 1),
                    "cadence_at": now - (TESTFLIGHT_INTERVAL - 1),
                    "status": "done",
                },
            },
        }
        throttled = plan_tick(snapshot, macos_recent_state, {"ios": "off", "macos": "app-store", "android": "off"})
        self.assertEqual(throttled["actions"], [])
        self.assertTrue(any("macos public: wait twelve hours" in r for r in throttled["reasons"]))
        self.assertTrue(any("macos app-store: wait 48 hours" in r for r in throttled["reasons"]))

        # Once 12h elapses, build & public-beta unlock while app-store waits for 48h.
        macos_recent_state["last_build_started"]["macos"] = now - TESTFLIGHT_INTERVAL
        macos_recent_state["operations"]["public-beta:macos:911"]["cadence_at"] = now - TESTFLIGHT_INTERVAL
        macos_recent_state["operations"]["public-beta:macos:911"]["started_at"] = now - TESTFLIGHT_INTERVAL
        halfway = plan_tick(snapshot, macos_recent_state, {"ios": "off", "macos": "app-store", "android": "off"})
        self.assertEqual(
            {(a["platform"], a["kind"]) for a in halfway["actions"]},
            {("macos", "build"), ("macos", "public-beta")},
        )

    def test_macos_reconcile_and_execute_record_per_platform_cadence_and_rejection_prompt(self):
        now = 4_000_000
        # reconcile_operations uses snapshot["macos"]["observed_at"] for macOS public-beta cadence.
        state = {
            "operations": {
                "public-beta:macos:912": {
                    "action": {"kind": "public-beta", "platform": "macos", "build": {"id": "mb1", "number": 912}},
                    "started_at": now - 100,
                    "status": "started",
                }
            }
        }
        snap = {
            "now": now,
            "ios": {},
            "macos": {
                "group_valid": True,
                "observed_at": now + 5,
                "builds": [
                    {
                        "id": "mb1",
                        "number": 912,
                        "public": True,
                        "public_complete": True,
                        "external": "READY_FOR_BETA_TESTING",
                    }
                ],
                "versions": [
                    {"id": "mv1", "version": "1.0.37", "state": "REJECTED", "build_id": "mb1"}
                ],
                "submissions": [],
                "review_submissions": [],
            },
        }
        reconcile_operations(state, snap)
        self.assertEqual(state["operations"]["public-beta:macos:912"]["status"], "done")
        self.assertEqual(state["operations"]["public-beta:macos:912"]["cadence_at"], now + 5)

        # App Review rejection hold names macos-version:<id> and links APPLE_REVIEW_RESPONSE.md.
        rej_plan = plan_tick(snap, state, {"ios": "off", "macos": "app-store", "android": "off"})
        self.assertTrue(
            any(
                "macos app-store: rejection hold for 1.0.37" in r
                and "macos-version:mv1" in r
                and "APPLE_REVIEW_RESPONSE.md#replying-to-a-rejection" in r
                for r in rej_plan["reasons"]
            )
        )

        # Runtime.execute records macos_app_store_submissions using math.ceil(time.time()).
        class FakeApple:
            def submit_store(self, *args, **kwargs):
                return "mv-sub"

        class FakeStore:
            def save(self, s):
                pass

        runtime = Runtime.__new__(Runtime)
        runtime.env = {}
        runtime.ledger = MemoryLedger()
        runtime.apple = FakeApple()
        runtime.refresh_store_authorization = lambda platform: None
        runtime.claim = lambda build, channel: None
        runtime.deploy = lambda env, build, status, s: None
        exec_state = {}
        exec_plan = {
            "actions": [
                {
                    "kind": "app-store",
                    "platform": "macos",
                    "build": {"id": "mb1", "number": 912, "version": "1.0.37", "sha": SHA_NEW},
                    "release_notes": release_notes_bundle("macos", SHA_NEW),
                }
            ]
        }
        with patch("release_train.runner.time.time", return_value=now + 10.2):
            execute_plan(exec_plan, exec_state, snap, FakeStore(), runtime)
        self.assertEqual(exec_plan.get("errors", []), [])
        self.assertEqual(exec_state["macos_app_store_submissions"], [now + 11])
        self.assertNotIn("app_store_submissions", exec_state)

    def test_non_production_macos_build_does_not_suppress_build_or_promote(self):
        for env_value in ("STAGING", "POC", None):
            with self.subTest(default_env=env_value):
                build_entry = {
                    "id": "mb-nonprod",
                    "number": 912,
                    "version": "1.0.37",
                    "sha": SHA_NEW,
                    "valid": True,
                    "ci_verified": True,
                    "public": False,
                    "public_complete": False,
                    "groups": ["g1"],
                    "external": "READY_FOR_BETA_SUBMISSION",
                }
                if env_value is not None:
                    build_entry["default_env"] = env_value
                snapshot = {
                    "now": 3_000_000,
                    "ci_passed": True,
                    "candidate": SHA_NEW,
                    "changes": {"ios": False, "macos": True, "android": False},
                    "cm": [],
                    "ios": {},
                    "macos": {
                        "group_valid": True,
                        "builds": [build_entry],
                        "versions": [
                            {"id": "mv1", "version": "1.0.0", "state": "PREPARE_FOR_SUBMISSION", "build_id": None}
                        ],
                        "submissions": [],
                        "review_submissions": [],
                    },
                    "android": {},
                }
                state = {
                    "operations": {
                        "public-beta:macos:912": {
                            "action": {"kind": "public-beta", "platform": "macos", "build": {"id": "mb-nonprod", "number": 912}},
                            "started_at": 2_900_000,
                            "status": "started",
                        }
                    }
                }
                plan = plan_tick(snapshot, state, {"ios": "off", "macos": "app-store", "android": "off"})
                self.assertEqual(
                    [(a["platform"], a["kind"]) for a in plan["actions"]],
                    [("macos", "build")],
                )

    def test_backfilled_live_macos_build_preserves_legacy_betas_until_first_allocation(self):
        class FakeApple:
            def __init__(self):
                self.group = "g1"
                self.groups = ["g1"]

            def call(self, method, path, body=None):
                if path.startswith("/betaGroups/"):
                    return {"data": {"attributes": {"isInternalGroup": False, "publicLinkEnabled": True, "publicLink": "https://testflight.apple.com/join/x"}}}
                if path.endswith("/build"):
                    return {"data": None}
                return {"data": {}}

            def pages(self, path):
                return []

            def beta_detail(self, build_id, current):
                return current or {
                    "id": "bd-" + build_id,
                    "attributes": {
                        "internalBuildState": "IN_BETA_TESTING",
                        "externalBuildState": "IN_BETA_TESTING",
                    },
                }

            def pages_including(self, path):
                return (
                    [
                        {
                            "id": "mb911",
                            "attributes": {"version": "911", "processingState": "VALID", "expired": False},
                            "relationships": {
                                "preReleaseVersion": {"data": {"type": "preReleaseVersions", "id": "prv1"}}
                            },
                        },
                        {
                            "id": "mb912",
                            "attributes": {"version": "912", "processingState": "VALID", "expired": False},
                            "relationships": {
                                "preReleaseVersion": {"data": {"type": "preReleaseVersions", "id": "prv1"}}
                            },
                        },
                    ],
                    {("preReleaseVersions", "prv1"): {"attributes": {"version": "1.0.37"}}},
                )

        ledger = MemoryLedger(
            {
                "releases/macos/1.0.37+911.json": {
                    "platform": "macos",
                    "release_version": "1.0.37+911",
                    "build_source_commit": SHA_OLD,
                    "default_env": "PRODUCTION",
                    "patchable": False,
                    "pkg_sha256": PKG_DIGEST,
                }
            }
        )
        runtime = Runtime.__new__(Runtime)
        runtime.apple = FakeApple()
        runtime.ledger = ledger

        snap = runtime.apple_snapshot("macos")
        by_num = {b["number"]: b for b in snap["builds"]}
        self.assertEqual(by_num[911]["sha"], SHA_OLD)
        self.assertEqual(by_num[911]["default_env"], "PRODUCTION")
        self.assertTrue(by_num[911]["valid"])
        self.assertTrue(by_num[912]["legacy"])
        self.assertIsNone(by_num[912]["sha"])
        self.assertFalse(by_num[912]["valid"])

        ledger.files["allocations/builds/macos/913.json"] = {
            "platform": "macos",
            "version": "1.0.37",
            "source_sha": SHA_NEW,
            "reservation_key": f"scheduled/macos/{SHA_NEW}",
        }
        ledger.files["releases/macos/1.0.37+913.json"] = {
            "platform": "macos",
            "release_version": "1.0.37+913",
            "build_source_commit": SHA_NEW,
            "default_env": "PRODUCTION",
            "patchable": False,
            "pkg_sha256": PKG_DIGEST,
        }
        self.assertTrue(runtime.identity("macos", 912, "1.0.37", allow_historical=True)["legacy"])
        with self.assertRaises(UnmappedBuild):
            runtime.identity("macos", 914, "1.0.37", allow_historical=True)

    def test_backfilled_macos_provenance_and_release_notes_enforce_complete_fields(self):
        base_record = {
            "platform": "macos",
            "release_version": "1.0.37+911",
            "build_source_commit": SHA_OLD,
            "default_env": "PRODUCTION",
            "patchable": False,
            "pkg_sha256": PKG_DIGEST,
        }
        for mutation in (
            {"pkg_sha256": ""},
            {"patchable": True},
            {"default_env": ""},
        ):
            with self.subTest(mutation=mutation):
                record = dict(base_record) | mutation
                ledger = MemoryLedger({"releases/macos/1.0.37+911.json": record})
                runtime = Runtime.__new__(Runtime)
                runtime.ledger = ledger
                with self.assertRaises(ProviderError):
                    runtime.identity("macos", 911, "1.0.37")
                with self.assertRaises(ReleaseNotesError):
                    notes_identity(ledger, "macos", 911, "1.0.37")

        staging_record = dict(base_record) | {"default_env": "STAGING"}
        staging_ledger = MemoryLedger({"releases/macos/1.0.37+911.json": staging_record})
        runtime = Runtime.__new__(Runtime)
        runtime.ledger = staging_ledger
        self.assertEqual(runtime.identity("macos", 911, "1.0.37")["default_env"], "STAGING")
        with self.assertRaises(ReleaseNotesError):
            notes_identity(staging_ledger, "macos", 911, "1.0.37")
        with self.assertRaisesRegex(ReleaseNotesError, "PRODUCTION environment provenance"):
            notes_production_build(
                "macos",
                {
                    "versions": [{"id": "mv1", "version": "1.0.37", "state": "READY_FOR_SALE", "build_id": "mb911"}],
                    "builds": [{"id": "mb911", "version": "1.0.37", "sha": SHA_OLD, "default_env": "STAGING"}],
                },
            )

    def test_runner_snapshot_skips_macos_builds_when_off_and_isolates_macos_lookup_error(self):
        queried_workflows = []

        def fake_cm(method, path, body=None):
            import urllib.parse

            workflow = urllib.parse.parse_qs(urllib.parse.urlsplit(path).query)["workflow_id"][0]
            queried_workflows.append(workflow)
            if workflow == "macos-scheduled-build":
                raise ProviderError("macos workflow disabled")
            return {"data": []}

        class FakeApple:
            def __init__(self, token, group):
                self.group = group
                self.groups = []

        def make_runtime():
            rt = Runtime.__new__(Runtime)
            rt.env = {"CODEMAGIC_API_TOKEN": "tok", "GITHUB_REPOSITORY": "divinevideo/divine-mobile"}
            rt.cm = fake_cm
            rt.candidate = lambda: None
            rt.apple = None
            rt.play = None
            rt.apple_snapshot = lambda platform: {"builds": [], "versions": [], "submissions": [], "review_submissions": [], "group_valid": True}
            return rt

        queried_workflows.clear()
        off_runtime = make_runtime()
        with (
            patch("release_train.runner.apple_token", return_value="token"),
            patch("release_train.runner.Apple", FakeApple),
            patch("release_train.runner.DEFAULT_GROUPS", ["g1", "g2", "g3", "g4"]),
        ):
            off_runtime.env["TESTFLIGHT_PUBLIC_GROUP_ID"] = "g1"
            off_runtime.env["TESTFLIGHT_GROUP_IDS"] = json.dumps(["g1", "g2", "g3", "g4"])
            snap_off = off_runtime.snapshot({}, {"ios": "testflight", "macos": "off", "android": "off"})
        self.assertNotIn("macos-build", queried_workflows)
        self.assertNotIn("macos-scheduled-build", queried_workflows)
        self.assertNotIn("error", snap_off["ios"])
        self.assertEqual(snap_off["macos"], {})

        queried_workflows.clear()
        on_runtime = make_runtime()
        on_runtime.env["TESTFLIGHT_PUBLIC_GROUP_ID"] = "g1"
        on_runtime.env["TESTFLIGHT_GROUP_IDS"] = json.dumps(["g1", "g2", "g3", "g4"])
        with (
            patch("release_train.runner.apple_token", return_value="token"),
            patch("release_train.runner.Apple", FakeApple),
            patch("release_train.runner.DEFAULT_GROUPS", ["g1", "g2", "g3", "g4"]),
        ):
            snap_on = on_runtime.snapshot({}, {"ios": "testflight", "macos": "testflight", "android": "off"})
        self.assertIn("macos-build", queried_workflows)
        self.assertIn("macos-scheduled-build", queried_workflows)
        self.assertNotIn("error", snap_on["ios"])
        self.assertIn("macos workflow disabled", snap_on["macos"]["error"])
        self.assertEqual(snap_on["android"], {})

    def test_release_identity_allows_verified_empty_macos_versions_list(self):
        ledger = MemoryLedger({BOOTSTRAP_PATH: {"schema": 1}})
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            pubspec = root / "pubspec.yaml"
            pubspec.write_text("name: divine\nversion: 1.0.37+911\n", encoding="utf-8")
            tags = root / "stable_tags.txt"
            tags.write_text("", encoding="utf-8")
            versions = root / "store_versions.json"
            versions.write_text("[]", encoding="utf-8")
            shorebird = root / "shorebird.json"
            shorebird.write_text('{"status": "success", "data": {"releases": []}}', encoding="utf-8")
            out = root / "release.env"

            rc = release_identity_main(
                [
                    "allocate",
                    "--platform",
                    "macos",
                    "--pubspec",
                    str(pubspec),
                    "--source-sha",
                    SHA_NEW,
                    "--reservation-key",
                    "manual/1",
                    "--codemagic-build-id",
                    "1" * 24,
                    "--store-latest-build",
                    "0",
                    "--stable-tags",
                    str(tags),
                    "--app-store-versions",
                    str(versions),
                    "--output",
                    str(out),
                ],
                ledger_factory=lambda _repo: ledger,
                now=datetime(2026, 11, 25, tzinfo=UTC),
            )
            self.assertEqual(rc, 0)
            env_text = out.read_text(encoding="utf-8")
            self.assertIn("SHOREBIRD_BUILD_NAME=1.0.37", env_text)
            self.assertIn("SHOREBIRD_BUILD_NUMBER=1", env_text)

            ios_rc = release_identity_main(
                [
                    "allocate",
                    "--platform",
                    "ios",
                    "--pubspec",
                    str(pubspec),
                    "--source-sha",
                    SHA_NEW,
                    "--reservation-key",
                    "manual/2",
                    "--codemagic-build-id",
                    "2" * 24,
                    "--store-latest-build",
                    "0",
                    "--shorebird-releases",
                    str(shorebird),
                    "--stable-tags",
                    str(tags),
                    "--app-store-versions",
                    str(versions),
                    "--output",
                    str(out),
                ],
                ledger_factory=lambda _repo: ledger,
                now=datetime(2026, 11, 25, tzinfo=UTC),
            )
            self.assertEqual(ios_rc, 1)

    def test_release_notes_macos_prelaunch_cache_switches_to_mac_baseline_once_live(self):
        sha_mac_40 = "c" * 40
        sha_ios_41 = "d" * 40
        sha_cand = "e" * 40
        ledger = MemoryLedger()
        ios_data = {
            "versions": [{"id": "iv1", "version": "1.0.41", "state": "READY_FOR_SALE", "build_id": "ib41"}],
            "builds": [{"id": "ib41", "version": "1.0.41", "sha": sha_ios_41}],
        }
        prelaunch_snap = {
            "versions": [{"id": "mv40", "version": "1.0.40", "state": "WAITING_FOR_REVIEW", "build_id": "mb40"}],
            "builds": [{"id": "mb40", "version": "1.0.40", "sha": sha_mac_40, "default_env": "PRODUCTION"}],
        }
        live_snap = {
            "versions": [{"id": "mv40", "version": "1.0.40", "state": "READY_FOR_SALE", "build_id": "mb40"}],
            "builds": [{"id": "mb40", "version": "1.0.40", "sha": sha_mac_40, "default_env": "PRODUCTION"}],
        }
        seen_baselines = []

        def fake_generate(platform, source, baseline, locales, env):
            seen_baselines.append(dict(baseline))
            return release_notes_bundle(platform, source) | {"baseline": baseline}

        runtime = Runtime.__new__(Runtime)
        runtime.env = {"PROVENANCE_TOKEN": "tok", "PUBLIC_PEOPLE_LIST_POLICY": "pol"}
        runtime.ledger = ledger
        runtime.cm = lambda *a, **kw: None

        with (
            patch("release_train.release_notes._production_data", return_value=ios_data) as mock_prod,
            patch("release_train.release_notes._check_ancestry"),
            patch("release_train.release_notes._apple_locales", return_value=["en-US"]),
            patch("release_train.release_notes._generate", side_effect=fake_generate) as mock_gen,
            patch("release_train.setup.configure_build_credentials"),
        ):
            runtime.prepare_action(
                {"kind": "build", "platform": "macos", "sha": sha_cand, "attempt": 1},
                {"macos": prelaunch_snap},
            )
            mock_prod.assert_called_once_with("ios", runtime.env, ledger)
            self.assertEqual(len(seen_baselines), 1)
            self.assertEqual(seen_baselines[0], {"version": "1.0.41", "sha": sha_ios_41})

            # Second prelaunch pass reuses release-notes/macos-prelaunch/ without regenerating.
            prelaunch_retry = ensure_bundle(
                "macos", sha_cand, data=prelaunch_snap, env=runtime.env, ledger=ledger
            )
            self.assertEqual(prelaunch_retry["baseline"], {"version": "1.0.41", "sha": sha_ios_41})
            self.assertEqual(mock_gen.call_count, 1)

            # Once Mac 1.0.40 goes live, app-store promotion for the SAME candidate generates Mac-baselined notes.
            app_store_action = {
                "kind": "app-store",
                "platform": "macos",
                "build": {"id": "mb42", "number": 915, "version": "1.0.42", "sha": sha_cand},
            }
            runtime.prepare_action(app_store_action, {"macos": live_snap})

        self.assertEqual(app_store_action["release_notes"]["baseline"], {"version": "1.0.40", "sha": sha_mac_40})
        self.assertEqual(len(seen_baselines), 2)
        self.assertEqual(seen_baselines[1], {"version": "1.0.40", "sha": sha_mac_40})
        prelaunch_paths = [p for p in ledger.files if p.startswith(f"release-notes/macos-prelaunch/{sha_cand}/")]
        live_paths = [p for p in ledger.files if p.startswith(f"release-notes/macos/{sha_cand}/")]
        self.assertEqual(len(prelaunch_paths), 1)
        self.assertEqual(len(live_paths), 1)

        # Post-launch retries reuse the live Mac-baselined cache without calling _production_data or _generate.
        with (
            patch("release_train.release_notes._production_data", side_effect=AssertionError("must reuse live Mac cache")),
            patch("release_train.release_notes._generate", side_effect=AssertionError("must reuse live Mac cache")),
        ):
            reused = ensure_bundle("macos", sha_cand, env={}, ledger=ledger)
        self.assertEqual(reused["baseline"], {"version": "1.0.40", "sha": sha_mac_40})


if __name__ == "__main__":
    unittest.main()
