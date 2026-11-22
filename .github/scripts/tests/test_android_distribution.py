"""Approved Android downloads keep the original candidate identity and bytes."""
import copy
import hashlib
import json
import os
import re
import subprocess
import tempfile
import unittest
import importlib
from pathlib import Path
from unittest.mock import patch

import release_train_fakes
import publish_play_bundle
from release_train.providers import ProviderError
from release_train_fakes import MemoryLedgerStore, release_notes_bundle
from test_publish_github_release import FakeGitHub
from release_train.coordinator import plan_tick
from release_train.runner import execute_plan, reconcile_operations

ROOT = Path(__file__).resolve().parents[3]
SOURCE = "a" * 40
APK_NAMES = ("app-arm64-v8a-release.apk", "app-armeabi-v7a-release.apk")


class OriginalDownloadsTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        previous = Path.cwd()
        os.chdir(self.directory.name)
        self.addCleanup(os.chdir, previous)
        Path("build/shorebird").mkdir(parents=True)
        Path("build/shorebird/android_release.env").write_text(
            "SHOREBIRD_BUILD_NAME=1.0.1\nSHOREBIRD_BUILD_NUMBER=123\n"
            "SHOREBIRD_RELEASE_VERSION=1.0.1+123\nRELEASE_SOURCE_SHA=" + SOURCE + "\n")
        aab = Path("build/app/outputs/bundle/release")
        aab.mkdir(parents=True)
        (aab / "app.aab").write_bytes(b"original aab")
        self.apk_root = Path("build/app/outputs/apk/release")
        self.apk_root.mkdir(parents=True)
        for name in APK_NAMES:
            (self.apk_root / name).write_bytes(name.encode())
        self.ledger = MemoryLedgerStore()
        self.env = {"CM_BUILD_ID": "original-native-build", "RELEASE_TRAIN_SCHEDULED": "true",
                    "RELEASE_NOTES_BUNDLE": json.dumps(release_notes_bundle("android", SOURCE))}
        self.uploads = []
        outer = self

        class Play:
            def upload(self, path, number, digest, *, notes):
                outer.uploads.append(number)

        self.play = Play()
        mocked = patch.object(publish_play_bundle.subprocess, "check_output", return_value=SOURCE)
        mocked.start()
        self.addCleanup(mocked.stop)

    def publish(self):
        publish_play_bundle.publish_bundle(self.env, ledger=self.ledger, play=self.play)

    def test_retains_both_original_apk_hashes_and_source_bound_notes_before_upload(self):
        self.publish()
        record = self.ledger.files.get("artifacts/android-downloads/123.json")
        self.assertIsNotNone(record, "Scheduled candidates need retained direct-download evidence")
        self.assertEqual(record["number"], 123)
        self.assertEqual(record["version"], "1.0.1")
        self.assertEqual(record["sha"], SOURCE)
        self.assertEqual(record["build_id"], "original-native-build")
        self.assertEqual(record["release_notes"], json.loads(self.env["RELEASE_NOTES_BUNDLE"]))
        self.assertEqual(record["apks"], [
            {"name": name, "sha256": hashlib.sha256(name.encode()).hexdigest()}
            for name in APK_NAMES])
        self.assertLess(self.ledger.creates.index("artifacts/android-downloads/123.json"),
                        self.ledger.creates.index("uploads/android/123.json"))
        self.assertEqual(self.uploads, [123])

    def test_scheduled_candidate_missing_one_apk_stops_before_play_upload(self):
        (self.apk_root / APK_NAMES[1]).unlink()
        with self.assertRaisesRegex(ProviderError, "APK"):
            self.publish()
        self.assertEqual(self.uploads, [])

    def test_retry_cannot_replace_original_apk_bytes(self):
        self.publish()
        original = copy.deepcopy(self.ledger.files["artifacts/android-downloads/123.json"])
        (self.apk_root / APK_NAMES[0]).write_bytes(b"rebuilt bytes")
        with self.assertRaisesRegex(ProviderError, "original|different|immutable"):
            self.publish()
        self.assertEqual(self.ledger.files["artifacts/android-downloads/123.json"], original)
        self.assertEqual(self.uploads, [123])

    def test_manual_counter_difference_is_not_retained_as_an_approved_download(self):
        self.env["RELEASE_TRAIN_SCHEDULED"] = "false"
        self.env["PROJECT_BUILD_NUMBER"] = "999"
        self.publish()
        self.assertNotIn("artifacts/android-downloads/123.json", self.ledger.files)
        self.assertEqual(self.uploads, [123])

    def approved_fixture(self):
        self.publish()
        self.assertTrue((ROOT / "mobile/scripts/publish_approved_android.py").exists(),
                        "The approved-candidate publisher is not implemented")
        publisher = importlib.import_module("publish_approved_android")
        manifest = self.ledger.files["artifacts/android-downloads/123.json"]
        manifest_hash = hashlib.sha256(json.dumps(manifest, sort_keys=True,
                                     separators=(",", ":")).encode()).hexdigest()
        self.ledger.files["distributions/approvals/android/123/1-2000000000.json"] = {
            "schema": 1, "number": 123, "version": "1.0.1", "sha": SOURCE,
            "manifest_sha256": manifest_hash, "observed_at": 2000000000,
            "play_state": "PUBLISHED", "ci_verified": True}
        self.ledger.files["releases/android/1.0.1+123.json"] = {
            "platform": "android", "release_version": "1.0.1+123",
            "build_source_commit": SOURCE, "patchable": True, "record_hmac": "c" * 64}
        env = {"APPROVED_BUILD_NUMBER": "123", "DISTRIBUTION_ATTEMPT": "1",
               "APPROVAL_OBSERVED_AT": "2000000000",
               "APPROVED_VERSION": "1.0.1", "APPROVED_SOURCE_SHA": SOURCE,
               "CM_BRANCH": "main", "CM_BUILD_ID": "publication-job",
               "CM_REPO_SLUG": "owner/repo", "CM_ENV": str(Path.cwd() / "cm.env")}

        class GitHub(FakeGitHub):
            def latest_tag(self):
                return "1.0.1"

        self.github = GitHub()
        self.provider = {"id": "original-native-build", "status": "finished",
                         "commit": {"hash": SOURCE}, "artifacts": [
            {"name": name, "size_in_bytes": len(name.encode()),
             "short_lived_download_url": "https://api.codemagic.io/signed/" + name}
            for name in APK_NAMES]}

        def cm(method, path):
            self.assertEqual((method, path), ("GET", "/builds/original-native-build"))
            return {"data": self.provider}

        def download(url, path):
            path.write_bytes(path.name.encode())

        self.cm = cm
        self.download = download
        return publisher, env

    def test_approved_publisher_uses_original_apks_and_retained_notes(self):
        publisher, env = self.approved_fixture()
        publisher.publish_approved(env, self.ledger, self.cm, self.github,
                                   download=self.download, now=2000000010)
        self.assertFalse(self.github.record["draft"])
        self.assertFalse(self.github.record["prerelease"])
        self.assertEqual(self.github.commit, SOURCE)
        self.assertEqual({a["name"] for a in self.github.record["assets"]}, set(APK_NAMES))
        self.assertIn("Search for a friend.", self.github.record["body"])
        self.assertIn("Android", self.github.record["body"])
        self.assertNotIn("available on iOS", self.github.record["body"])
        self.assertIn("ANDROID_DISTRIBUTION_VERSION=1.0.1", Path(env["CM_ENV"]).read_text())
        self.assertNotIn("distributions/android/123.json", self.ledger.files)
        with self.assertRaisesRegex(ProviderError, "sign|Zapstore"):
            publisher.record_published(env, self.ledger, self.github)
        Path("build/distribution/zapstore-succeeded").write_text("1.0.1\npublication-job\n")
        publisher.record_published(env, self.ledger, self.github)
        receipt = self.ledger.files["distributions/android/123.json"]
        self.assertEqual(receipt["sha"], SOURCE)
        self.assertEqual(receipt["number"], 123)
        self.assertEqual(receipt["version"], "1.0.1")
        self.assertEqual(receipt["apks"], self.ledger.files["artifacts/android-downloads/123.json"]["apks"])

    def test_changed_download_stops_before_github_or_signing_identity_is_written(self):
        publisher, env = self.approved_fixture()
        def changed(url, path):
            path.write_bytes(b"different bytes")
        with self.assertRaisesRegex(ProviderError, "digest|hash"):
            publisher.publish_approved(env, self.ledger, self.cm, self.github,
                                       download=changed, now=2000000010)
        self.assertIsNone(self.github.record)
        self.assertFalse(Path(env["CM_ENV"]).exists())

    def test_pending_stale_or_conflicting_approval_cannot_publish(self):
        publisher, env = self.approved_fixture()
        original = copy.deepcopy(self.ledger.files["distributions/approvals/android/123/1-2000000000.json"])
        for field, value in [("play_state", "IN_REVIEW"), ("sha", "b" * 40),
                             ("ci_verified", False), ("manifest_sha256", "0" * 64),
                             ("observed_at", 1999990000)]:
            with self.subTest(field=field):
                self.ledger.files["distributions/approvals/android/123/1-2000000000.json"] = {**original, field: value}
                with self.assertRaises(ProviderError):
                    publisher.publish_approved(env, self.ledger, self.cm, self.github,
                                               download=self.download, now=2000000010)
                self.assertIsNone(self.github.record)

    def test_original_native_provider_source_must_match(self):
        publisher, env = self.approved_fixture()
        self.provider["commit"]["hash"] = "b" * 40
        with self.assertRaisesRegex(ProviderError, "source|identity"):
            publisher.publish_approved(env, self.ledger, self.cm, self.github,
                                       download=self.download, now=2000000010)
        self.assertIsNone(self.github.record)

    def test_repeated_publication_preserves_assets_and_requires_verified_receipt(self):
        publisher, env = self.approved_fixture()
        publisher.publish_approved(env, self.ledger, self.cm, self.github,
                                   download=self.download, now=2000000010)
        self.github.calls.clear()
        publisher.publish_approved(env, self.ledger, self.cm, self.github,
                                   download=self.download, now=2000000010)
        self.assertNotIn("upload", [c[0] for c in self.github.calls])
        Path("build/distribution/zapstore-succeeded").write_text("1.0.1\npublication-job\n")
        self.github.record["assets"][0]["digest"] = "sha256:" + "0" * 64
        with self.assertRaises(ProviderError):
            publisher.record_published(env, self.ledger, self.github)
        self.assertNotIn("distributions/android/123.json", self.ledger.files)

    def test_zapstore_retry_uses_verified_github_assets_after_native_artifacts_expire(self):
        publisher, env = self.approved_fixture()
        publisher.publish_approved(env, self.ledger, self.cm, self.github,
                                   download=self.download, now=2000000010)
        self.github.calls.clear()
        def unavailable(method, path):
            raise ProviderError("Original Codemagic artifacts expired")
        publisher.publish_approved(env, self.ledger, unavailable, self.github,
                                   download=self.download, now=2000000010)
        self.assertEqual(self.github.calls, [])
        self.assertIn("ANDROID_DISTRIBUTION_VERSION=1.0.1", Path(env["CM_ENV"]).read_text())

    def test_existing_stable_release_notes_are_not_overwritten(self):
        publisher, env = self.approved_fixture()
        publisher.publish_approved(env, self.ledger, self.cm, self.github,
                                   download=self.download, now=2000000010)
        self.github.record["body"] = "Previously reviewed release notes"
        self.github.calls.clear()
        with self.assertRaises(ProviderError):
            publisher.publish_approved(env, self.ledger, self.cm, self.github,
                                       download=self.download, now=2000000010)
        self.assertEqual(self.github.calls, [])
        self.assertEqual(self.github.record["body"], "Previously reviewed release notes")

    def test_conflicting_draft_or_unexpected_apk_never_reaches_stable_publication(self):
        for conflict in ("notes", "draft-apk", "stable-apk"):
            publisher, env = self.approved_fixture()
            publisher.publish_approved(env, self.ledger, self.cm, self.github,
                                       download=self.download, now=2000000010)
            self.github.record["draft"] = conflict != "stable-apk"
            if conflict == "notes":
                self.github.record["body"] = "Different reviewed draft notes"
            else:
                self.github.record["assets"].append({"name": "alternate-arm64-release.apk",
                                                     "digest": "sha256:" + "d" * 64})
            self.github.calls.clear()
            with self.subTest(conflict=conflict), self.assertRaises(ProviderError):
                publisher.publish_approved(env, self.ledger, self.cm, self.github,
                                           download=self.download, now=2000000010)
            self.assertEqual(self.github.calls, [])

    def test_matching_partial_draft_resumes_without_replacing_its_original_asset(self):
        publisher, env = self.approved_fixture()
        publisher.publish_approved(env, self.ledger, self.cm, self.github,
                                   download=self.download, now=2000000010)
        self.github.record["draft"] = True
        self.github.record["assets"] = self.github.record["assets"][:1]
        original = copy.deepcopy(self.github.record["assets"][0])
        self.github.calls.clear()
        publisher.publish_approved(env, self.ledger, self.cm, self.github,
                                   download=self.download, now=2000000010)
        self.assertFalse(self.github.record["draft"])
        self.assertEqual(self.github.record["assets"][0], original)
        self.assertEqual(len(self.github.record["assets"]), 2)

    def test_release_appearing_during_download_is_not_overwritten(self):
        publisher, env = self.approved_fixture()
        def concurrent(url, path):
            self.download(url, path)
            self.github.commit = SOURCE
            self.github.record = {"draft": False, "prerelease": False,
                "body": "Independently published notes", "assets": [], "target_commitish": SOURCE}
        with self.assertRaises((ProviderError, ValueError)):
            publisher.publish_approved(env, self.ledger, self.cm, self.github,
                                       download=concurrent, now=2000000010)
        self.assertEqual(self.github.calls, [])
        self.assertEqual(self.github.record["body"], "Independently published notes")

    def test_release_promoted_during_upload_keeps_its_independent_notes(self):
        publisher, env = self.approved_fixture()
        original = self.github.upload
        def concurrent(tag, paths):
            original(tag, paths)
            self.github.record.update(draft=False, body="Independently published notes")
        self.github.upload = concurrent
        with self.assertRaises((ProviderError, ValueError)):
            publisher.publish_approved(env, self.ledger, self.cm, self.github,
                                       download=self.download, now=2000000010)
        self.assertEqual(self.github.record["body"], "Independently published notes")
        self.assertNotIn("edit", [c[0] for c in self.github.calls])

    def test_signed_artifact_urls_require_the_provider_origin(self):
        publisher, env = self.approved_fixture()
        for url in ("http://api.codemagic.io/file", "https://other.invalid/file",
                    "https://user:secret@api.codemagic.io/file"):
            self.provider["artifacts"][0]["short_lived_download_url"] = url
            with self.subTest(url=url), self.assertRaises(ProviderError):
                publisher.publish_approved(env, self.ledger, self.cm, self.github,
                                           download=self.download, now=2000000010)
            self.assertIsNone(self.github.record)

    def test_no_manual_workflow_inputs_preserves_legacy_publication(self):
        self.assertTrue((ROOT / "mobile/scripts/publish_approved_android.py").exists(),
                        "The approved-candidate publisher is not implemented")
        publisher = importlib.import_module("publish_approved_android")
        self.assertIsNone(publisher.publish_approved({}, self.ledger, None, None))
        self.assertIsNone(publisher.record_published({}, self.ledger, None))

    def test_runtime_observes_verified_original_evidence_and_dispatches_only_signing_job(self):
        from release_train.runner import Runtime
        publisher, _ = self.approved_fixture()
        runtime = Runtime.__new__(Runtime)
        runtime.ledger = self.ledger
        runtime.env = {"PROVENANCE_TOKEN": "private-synthetic-token",
                       "PUBLIC_PEOPLE_LIST_POLICY": "[]"}
        snap = approved_snapshot()
        self.assertTrue(hasattr(runtime, "collect_distribution"), "Coordinator does not collect APK evidence")
        runtime.collect_distribution(snap, {})
        self.assertEqual(snap["distribution"]["downloads"][0]["number"], 123)
        plan = plan_tick(snap, {}, {"ios": "off", "android": "production"})
        action = plan["actions"][0]
        calls = []
        def cm(method, path, body=None):
            calls.append((method, path, body))
            return {"data": {"id": "signing-job"}}
        runtime.cm = cm
        with patch("release_train.setup.configure_build_credentials"):
            runtime.prepare_action(action, snap)
        result = runtime.execute(action, {}, snap)
        self.assertEqual(result, {"build_id": "signing-job"})
        self.assertEqual(len(calls), 1)
        method, path, payload = calls[0]
        self.assertEqual(method, "POST")
        self.assertEqual(payload["workflow_id"], "zapstore-publish")
        self.assertEqual(payload["branch"], "main")
        variables = payload["environment"]["variables"]
        self.assertEqual(variables["APPROVED_BUILD_NUMBER"], "123")
        self.assertEqual(variables["APPROVED_SOURCE_SHA"], SOURCE)
        self.assertEqual(variables["APPROVED_VERSION"], "1.0.1")
        self.assertNotIn("private-synthetic-token", json.dumps(payload))
        self.assertEqual(payload["labels"], ["release-distribution:android:123:" + SOURCE + ":1"])

    def test_missing_historical_evidence_cannot_be_invented_by_collection(self):
        from release_train.runner import Runtime
        self.assertTrue(hasattr(Runtime, "collect_distribution"), "Coordinator does not collect APK evidence")
        runtime = Runtime.__new__(Runtime)
        runtime.ledger = self.ledger
        snap = approved_snapshot()
        runtime.collect_distribution(snap, {})
        self.assertEqual(snap["distribution"]["downloads"], [])
        self.assertEqual(self.ledger.creates, [])

    def test_publication_preparation_rejects_incomplete_play_observation(self):
        from release_train.runner import Runtime
        self.approved_fixture()
        runtime = Runtime.__new__(Runtime)
        runtime.ledger = self.ledger
        runtime.env = {"PROVENANCE_TOKEN": "private-synthetic-token", "PUBLIC_PEOPLE_LIST_POLICY": "[]"}
        snap = approved_snapshot()
        snap["android"]["lifecycle_complete"] = False
        action = {"kind": "android-distribution", "platform": "android", "attempt": 1,
                  "build": snap["distribution"]["downloads"][0]}
        with self.assertRaises(ProviderError):
            runtime.prepare_action(action, snap)


class ScheduledApkBuildTest(unittest.TestCase):
    def signing_script(self):
        config = json.loads(subprocess.check_output(
            ["ruby", "-ryaml", "-rjson", "-e",
             "print JSON.generate(YAML.safe_load(File.read(ARGV[0]), aliases: true))",
             str(ROOT / "codemagic.yaml")], text=True))
        return next(step["script"] for step in config["workflows"]["zapstore-publish"]["scripts"]
                    if step["name"] == "Publish to Zapstore")

    def test_signer_marker_requires_success_from_the_real_workflow_command(self):
        script = self.signing_script()
        tail = script[script.index('SIGN_WITH="$ZAPSTORE_NSEC"'):]
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            output = root / "mobile/build/distribution"
            output.mkdir(parents=True)
            executable = root / "zsp"
            executable.write_text('#!/bin/sh\nexit "$SIGNER_EXIT"\n')
            executable.chmod(0o755)
            env = {"PATH": os.environ["PATH"], "ZSP_BIN": str(executable),
                   "ZAPSTORE_NSEC": "synthetic-signing-value", "GITHUB_TOKEN": "synthetic-token",
                   "ZAPSTORE_CONFIG": str(root / "exact-tag.yaml"), "TAG": "1.0.1",
                   "CM_BUILD_ID": "signing-job", "CM_BUILD_DIR": str(root),
                   "APPROVED_BUILD_NUMBER": "123"}
            for code in (7, 0):
                result = subprocess.run(["bash", "-c", "set -euo pipefail\n" + tail],
                                        env=env | {"SIGNER_EXIT": str(code)}, capture_output=True, text=True)
                self.assertEqual(result.returncode, code, result.stderr)
                marker = output / "zapstore-succeeded"
                self.assertEqual(marker.exists(), code == 0)
                if code == 0:
                    self.assertEqual(marker.read_text(), "1.0.1\nsigning-job\n")
                self.assertNotIn("synthetic-signing-value", result.stdout + result.stderr)

    def test_signer_uses_the_approved_version_instead_of_checkout_version(self):
        script = self.signing_script().split("ZSP_VERSION=", 1)[0]
        script = script.replace("${{ inputs.PUBLISH_TO_GITHUB }}", "YES")
        script = script.replace("${{ inputs.RELEASE_CHANNEL }}", "PRODUCTION")
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "pubspec.yaml").write_text("version: 9.9.9+999\n")
            executable = root / "gh"
            executable.write_text('#!/bin/sh\nprintf "%s\\n" "$LATEST_TAG"\n')
            executable.chmod(0o755)
            env = {"PATH": str(root) + os.pathsep + os.environ["PATH"],
                   "ANDROID_DISTRIBUTION_VERSION": "1.0.1", "CM_REPO_SLUG": "owner/repo"}
            for latest in ("1.0.1", "1.0.2"):
                result = subprocess.run(["bash", "-c", script], cwd=root,
                                        env=env | {"LATEST_TAG": latest}, capture_output=True, text=True)
                self.assertEqual(result.returncode, 0 if latest == "1.0.1" else 1, result.stderr)
                if latest == "1.0.1":
                    self.assertIn("Publishing 1.0.1 to Zapstore", result.stdout)

    def test_automated_signer_matches_only_the_authorized_arm64_filename(self):
        preparation = self.signing_script().split('cd "$CM_BUILD_DIR"', 1)[1].split(
            '"$ZSP_BIN" publish --check', 1)[0]
        inspect = 'ruby -ryaml -rjson -e \'puts JSON.generate(YAML.safe_load_file(ARGV[0]))\' "$ZAPSTORE_CONFIG"'
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "zapstore.yaml").write_text('match: ".*arm64.*\\\\.apk$"\n')
            result = subprocess.run(["bash", "-c", "set -euo pipefail\n" + preparation + inspect],
                cwd=root, env={"PATH": os.environ["PATH"], "CM_BUILD_DIR": str(root),
                               "TAG": "1.0.1", "APPROVED_BUILD_NUMBER": "123"},
                capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            pattern = json.loads(result.stdout)["match"]
            self.assertIsNotNone(re.search(pattern, "app-arm64-v8a-release.apk"))
            self.assertIsNone(re.search(pattern, "alternate-arm64-release.apk"))
            self.assertIsNone(re.search(pattern, "prefix-app-arm64-v8a-release.apk"))

    def test_original_scheduled_build_produces_apks_with_allocated_number(self):
        config = json.loads(subprocess.check_output(
            ["ruby", "-ryaml", "-rjson", "-e",
             "print JSON.generate(YAML.safe_load(File.read(ARGV[0]), aliases: true))",
             str(ROOT / "codemagic.yaml")], text=True))
        script = next(step["script"] for step in config["workflows"]["android-build"]["scripts"]
                      if step["name"] == "Build Android APK")
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "build/shorebird").mkdir(parents=True)
            (root / "build/shorebird/android_release.env").write_text(
                "SHOREBIRD_BUILD_NAME=1.0.1\nSHOREBIRD_BUILD_NUMBER=123\n")
            (root / "build/shorebird/dart_defines.json").write_text("{}")
            executable = root / "flutter"
            executable.write_text('#!/bin/sh\nprintf "%s\\n" "$@" > "$CAPTURE_ARGS"\n')
            executable.chmod(0o755)
            capture = root / "args"
            result = subprocess.run(["bash", "-c", script], cwd=root, capture_output=True,
                                    text=True, env={"PATH": str(root) + os.pathsep + os.environ["PATH"],
                                    "RELEASE_TRAIN_SCHEDULED": "true", "PROJECT_BUILD_NUMBER": "999",
                                    "CAPTURE_ARGS": str(capture)})
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertTrue(capture.exists(), "Scheduled builds must retain the original APKs")
            arguments = capture.read_text().splitlines()
            self.assertIn("--build-number=123", arguments)
            self.assertIn("--build-name=1.0.1", arguments)
            self.assertIn("--split-per-abi", arguments)


def approved_snapshot():
    build = {"number": 123, "version": "1.0.1", "sha": SOURCE, "ci_verified": True}
    return {"now": 2000000000, "candidate": SOURCE, "ci_passed": True,
            "changes": {"ios": False, "android": False}, "cm": [],
            "android": {"internal": [build], "production": [build],
                        "managed_publishing": False, "lifecycle_complete": True},
            "distribution": {"downloads": [build | {"manifest_sha256": "c" * 64}], "receipts": {}}}


class DistributionPolicyTest(unittest.TestCase):
    def test_only_published_production_candidate_gets_a_distribution_action(self):
        result = plan_tick(approved_snapshot(), {}, {"ios": "off", "android": "production"})
        self.assertEqual([(a["kind"], a["build"]["number"]) for a in result["actions"]],
                         [("android-distribution", 123)])
        for invalid in ("pending", "partial", "rejected", "no-ci", "no-evidence"):
            snap = approved_snapshot()
            if invalid == "pending":
                snap["android"]["production"] = []
            elif invalid == "partial":
                snap["android"]["lifecycle_complete"] = False
            elif invalid == "rejected":
                snap["android"]["error"] = "Google Play release rejected"
            elif invalid == "no-ci":
                snap["android"]["production"][0]["ci_verified"] = False
            else:
                snap["distribution"]["downloads"] = []
            with self.subTest(invalid=invalid):
                result = plan_tick(snap, {}, {"ios": "off", "android": "production"})
                self.assertNotIn("android-distribution", [a["kind"] for a in result["actions"]])

    def test_dry_run_proposes_without_publishing_and_preserves_store_hold(self):
        result = plan_tick(approved_snapshot(), {}, {"ios": "off", "android": "dry-run"})
        self.assertEqual(result["actions"], [])
        self.assertEqual([a["kind"] for a in result["proposed"]], ["android-distribution"])
        state = {"holds": {"android": "android-upload:885"}}
        result = plan_tick(approved_snapshot(), state, {"ios": "off", "android": "production"})
        self.assertEqual(state["holds"], {"android": "android-upload:885"})
        self.assertNotIn("android-distribution", [a["kind"] for a in result["actions"]])

    def test_newer_internal_candidate_cannot_replace_the_approved_identity(self):
        snap = approved_snapshot()
        snap["android"]["internal"] = [{"number": 124, "version": "1.0.2", "sha": "b" * 40,
                                        "ci_verified": True}]
        snap["distribution"]["downloads"].append(snap["android"]["internal"][0] | {"manifest_sha256": "d" * 64})
        result = plan_tick(snap, {}, {"ios": "off", "android": "production"})
        actions = [a for a in result["actions"] if a["kind"] == "android-distribution"]
        self.assertEqual(len(actions), 1)
        self.assertEqual(actions[0]["build"]["number"], 123)
        self.assertEqual(actions[0]["build"]["sha"], SOURCE)


class DistributionJournalTest(unittest.TestCase):
    def action(self):
        return {"kind": "android-distribution", "platform": "android", "attempt": 1,
                "build": approved_snapshot()["distribution"]["downloads"][0]}

    def state(self, status="deferred"):
        return {"operations": {"android-distribution:android:123": {
            "action": self.action(), "status": status, "started_at": 2000000000}}}

    def test_dispatch_intent_is_saved_and_dispatch_is_not_completion(self):
        from test_release_train_runner import Store
        store = Store()
        state = {}
        outer = self
        class Provider:
            def execute(self, action, current, snapshot):
                outer.assertEqual(store.saves[-1]["operations"][action["key"]]["status"], "started")
                return {"build_id": "signing-job"}
        execute_plan({"actions": [self.action()]}, state, approved_snapshot(), store, Provider())
        operation = state["operations"]["android-distribution:android:123"]
        self.assertEqual(operation["status"], "deferred")
        self.assertEqual(operation["result"]["build_id"], "signing-job")
        self.assertNotIn("last_build_started", state)
        self.assertNotIn("app_store_submissions", state)

    def test_play_failure_in_the_same_tick_stops_later_distribution(self):
        from test_release_train_runner import Store
        snap = approved_snapshot()
        snap["android"]["internal"] = [{"number": 124, "version": "1.0.2",
                                        "sha": "b" * 40, "ci_verified": True}]
        state = {"play_publication": {"version": 1, "internal_periods": {"124": {"completed": True}}}}
        plan = plan_tick(snap, state, {"ios": "off", "android": "production"})
        self.assertEqual([a["kind"] for a in plan["actions"]], ["play-production", "android-distribution"])
        executed = []
        class Provider:
            def execute(self, action, current, snapshot):
                executed.append(action["kind"])
                if action["kind"] == "play-production":
                    raise ProviderError("Promotion failed")
                return {"build_id": "signing-job"}
        execute_plan(plan, state, snap, Store(), Provider())
        self.assertEqual(executed, ["play-production"])
        self.assertEqual(state["holds"]["android"], "play-production:android:124")

    def test_hold_raised_during_preparation_stops_dispatch_too(self):
        from test_release_train_runner import Store
        state, executed = {}, []
        class Provider:
            def prepare_action(self, action, snapshot):
                state.setdefault("holds", {})["android"] = "observed-store-hold"
            def execute(self, action, current, snapshot):
                executed.append(action["kind"])
                return {"build_id": "signing-job"}
        execute_plan({"actions": [self.action()]}, state, approved_snapshot(), Store(), Provider())
        self.assertEqual(executed, [])
        self.assertFalse(state.get("operations"))

    def test_unknown_dispatch_is_held_separately_and_never_blindly_retried(self):
        state = self.state("ambiguous")
        reconcile_operations(state, approved_snapshot())
        self.assertEqual(state.get("holds", {}).get("android-distribution"),
                         "android-distribution:android:123")
        self.assertNotIn("android", state["holds"])
        result = plan_tick(approved_snapshot(), state, {"ios": "off", "android": "production"})
        self.assertNotIn("android-distribution", [a["kind"] for a in result["actions"]])

    def test_lost_dispatch_result_is_reconciled_by_label_and_exact_receipt(self):
        state = self.state("ambiguous")
        snap = approved_snapshot()
        snap["cm"] = [{"id": "signing-job", "platform": "android-distribution", "number": 123,
                       "sha": SOURCE, "attempt": 1, "status": "finished"}]
        reconcile_operations(state, snap)
        self.assertNotEqual(state["operations"]["android-distribution:android:123"]["status"], "done")
        snap["distribution"]["receipts"]["123"] = {
            "schema": 1, "number": 123, "version": "1.0.1", "sha": SOURCE,
            "manifest_sha256": "c" * 64, "zapstore_cli_succeeded": True}
        reconcile_operations(state, snap)
        self.assertEqual(state["operations"]["android-distribution:android:123"]["status"], "done")
        self.assertNotIn("android-distribution", state.get("holds", {}))

    def test_confirmed_failed_job_can_retry_original_identity_with_a_bounded_attempt(self):
        state = self.state()
        snap = approved_snapshot()
        snap["cm"] = [{"id": "failed-job", "platform": "android-distribution", "number": 123,
                       "sha": SOURCE, "attempt": 1, "status": "failed"}]
        reconcile_operations(state, snap)
        result = plan_tick(snap, state, {"ios": "off", "android": "production"})
        actions = [a for a in result["actions"] if a["kind"] == "android-distribution"]
        self.assertEqual(len(actions), 1)
        self.assertEqual(actions[0]["attempt"], 2)
        self.assertEqual(actions[0]["build"]["sha"], SOURCE)
        self.assertEqual(actions[0]["build"]["number"], 123)

    def test_third_confirmed_failure_holds_only_distribution(self):
        state = self.state()
        state["operations"]["android-distribution:android:123"]["action"]["attempt"] = 3
        snap = approved_snapshot()
        snap["cm"] = [{"id": "failed-job", "platform": "android-distribution", "number": 123,
                       "sha": SOURCE, "attempt": 3, "status": "failed"}]
        reconcile_operations(state, snap)
        self.assertEqual(state.get("holds"), {"android-distribution": "android-distribution:android:123"})
        result = plan_tick(snap, state, {"ios": "off", "android": "production"})
        self.assertNotIn("android-distribution", [a["kind"] for a in result["actions"]])


class DistributionInventoryTest(unittest.TestCase):
    def test_signing_jobs_are_not_native_builds_and_keep_the_original_artifact_source(self):
        from release_train.runner import Runtime, CM_APP_ID
        import urllib.parse
        runtime = Runtime.__new__(Runtime)
        def cm(method, path):
            workflow = urllib.parse.parse_qs(urllib.parse.urlsplit(path).query)["workflow_id"][0]
            if workflow != "zapstore-publish":
                return {"data": []}
            return {"data": [{"id": "signing-job", "app_id": CM_APP_ID,
                "workflow": {"id": "zapstore-publish"}, "status": "building",
                "commit": {"hash": "b" * 40},
                "labels": ["release-distribution:android:123:" + SOURCE + ":1"]}]}
        runtime.cm = cm
        entries = runtime.list_builds()
        self.assertEqual(len(entries), 1)
        self.assertEqual(entries[0]["platform"], "android-distribution")
        self.assertEqual(entries[0]["sha"], SOURCE)
        self.assertEqual(entries[0]["number"], 123)
