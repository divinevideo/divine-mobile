import contextlib
import io
import json
import subprocess
import sys
import tempfile
import os
import unittest
from unittest import mock
from datetime import datetime, timezone
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO_ROOT / "mobile" / "scripts"))

from release_train_fakes import MemoryLedgerStore  # noqa: E402

from release_train.ledger import BOOTSTRAP_PATH, reservation_path  # noqa: E402
import release_identity  # noqa: E402

# Play production code 300 maps to 1.2.7 through this provenance record.
PLAY_PROVENANCE = "releases/android/1.2.7+300.json"
SCRIPT = REPO_ROOT / "mobile" / "scripts" / "release_identity.py"
NOW = datetime(2026, 11, 5, tzinfo=timezone.utc)
SHA = "a" * 40


class CliTest(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.addCleanup(__import__("shutil").rmtree, self.tmp)
        self.pubspec = self.write("pubspec.yaml", "name: x\nversion: 1.2.3+9\n")
        self.shorebird = self.write(
            "sb.json",
            json.dumps({"status": "success", "data": {"releases": []}}),
        )
        self.tags = self.write("tags.txt", "refs/tags/1.2.3\n\nrefs/tags/v9\n")
        self.ios = self.write(
            "ios.json",
            json.dumps(
                [
                    {
                        "attributes": {
                            "versionString": "1.2.5",
                            "appVersionState": "READY_FOR_SALE",
                        }
                    }
                ]
            ),
        )
        self.play = self.write(
            "play.json",
            json.dumps(
                {
                    "track": "production",
                    "releases": [{"status": "completed", "versionCodes": ["300"]}],
                }
            ),
        )
        self.out = self.tmp / "out.env"

    def write(self, name, text):
        path = self.tmp / name
        path.write_text(text)
        return str(path)

    def run_main(self, argv, store):
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            code = release_identity.main(
                argv, ledger_factory=lambda repo: store, now=NOW
            )
        return code, buf.getvalue()

    def allocate_argv(self, platform="ios", key="manual/abc", extra=None):
        argv = [
            "allocate",
            "--platform", platform,
            "--pubspec", self.pubspec,
            "--source-sha", SHA,
            "--reservation-key", key,
            "--codemagic-build-id", "cm1",
            "--store-latest-build", "5",
            "--shorebird-releases", self.shorebird,
            "--stable-tags", self.tags,
            "--output", str(self.out),
        ]
        if extra is None:
            extra = (
                ["--app-store-versions", self.ios]
                if platform == "ios"
                else ["--play-production-track", self.play]
            )
        return argv + extra

    def bootstrapped(self):
        return MemoryLedgerStore(
            {BOOTSTRAP_PATH: {"schema": 1}, PLAY_PROVENANCE: {}}
        )

    def env(self):
        return dict(
            line.split("=", 1) for line in self.out.read_text().splitlines()
        )

    def test_allocate_writes_the_release_env(self):
        store = self.bootstrapped()
        code, _ = self.run_main(self.allocate_argv(), store)
        self.assertEqual(0, code)
        # The App Store's 1.2.5 is above the 1.2.3 tag, so it sets the train.
        self.assertEqual(
            "SHOREBIRD_BUILD_NAME=1.2.6\n"
            "SHOREBIRD_BUILD_NUMBER=6\n"
            "SHOREBIRD_RELEASE_VERSION=1.2.6+6\n"
            "RELEASE_TRAIN_RESERVATION_KEY=manual/abc\n"
            "RELEASE_TRAIN_RESERVATION_REUSED=false\n",
            self.out.read_text(),
        )
        self.assertIn("allocations/claims/1.2.5/app-store.json", store.creates)
        record = store.files[reservation_path("ios", 6)]
        self.assertEqual("cm1", record["codemagic_build_id"])
        self.assertEqual(SHA, record["source_sha"])

    def test_allocate_android_follows_the_play_production_version(self):
        store = self.bootstrapped()
        code, out = self.run_main(self.allocate_argv("android"), store)
        self.assertEqual(0, code, out)
        # Play production code 300 is 1.2.7, above the tag and the pubspec.
        self.assertEqual("1.2.8", self.env()["SHOREBIRD_BUILD_NAME"])
        self.assertIn("allocations/claims/1.2.7/play-production.json", store.creates)

    def test_allocate_android_and_reuse(self):
        store = self.bootstrapped()
        argv = self.allocate_argv("android")
        self.assertEqual(0, self.run_main(argv, store)[0])
        self.assertEqual(0, self.run_main(argv, store)[0])
        self.assertIn(
            "RELEASE_TRAIN_RESERVATION_REUSED=true\n", self.out.read_text()
        )

    def test_android_retry_after_its_shorebird_release_takes_a_new_number(self):
        store = self.bootstrapped()
        argv = self.allocate_argv("android")
        self.assertEqual(0, self.run_main(argv, store)[0])
        first = self.env()
        released = first["SHOREBIRD_RELEASE_VERSION"]
        # The same identity released for iOS only must not count as spent.
        Path(self.shorebird).write_text(
            json.dumps(
                {
                    "status": "success",
                    "data": {
                        "releases": [
                            {"version": released, "platform_statuses": {"ios": "active"}}
                        ]
                    },
                }
            )
        )
        self.assertEqual(0, self.run_main(argv, store)[0])
        self.assertEqual("true", self.env()["RELEASE_TRAIN_RESERVATION_REUSED"])
        Path(self.shorebird).write_text(
            json.dumps(
                {
                    "status": "success",
                    "data": {
                        "releases": [
                            {
                                "version": released,
                                "platform_statuses": {"android": "active"},
                            }
                        ]
                    },
                }
            )
        )
        self.assertEqual(0, self.run_main(argv, store)[0])
        second = self.env()
        self.assertEqual("false", second["RELEASE_TRAIN_RESERVATION_REUSED"])
        self.assertEqual(
            int(first["SHOREBIRD_BUILD_NUMBER"]) + 1,
            int(second["SHOREBIRD_BUILD_NUMBER"]),
        )

    def test_build_floor_does_not_treat_a_retry_as_uploaded(self):
        store = self.bootstrapped()
        argv = self.allocate_argv("android") + ["--build-number-floor", "950"]
        self.assertEqual(0, self.run_main(argv, store)[0])
        self.assertEqual("950", self.env()["SHOREBIRD_BUILD_NUMBER"])
        self.assertEqual(0, self.run_main(argv, store)[0])
        self.assertEqual("true", self.env()["RELEASE_TRAIN_RESERVATION_REUSED"])

    def test_bootstrap_ignores_an_unmapped_draft_code(self):
        Path(self.play).write_text(json.dumps({"track": "production", "releases": [
            {"status": "completed", "versionCodes": ["300"]},
            {"status": "draft", "versionCodes": ["999"]}]}))
        store = self.unbootstrapped()
        code, out = self.run_main(self.bootstrap_argv(), store)
        self.assertEqual(0, code, out)
        self.assertIn("allocations/claims/1.2.7/play-production.json", store.creates)
        self.assertEqual(BOOTSTRAP_PATH, store.creates[-1])

    def test_allocate_fails_closed_with_a_clear_error(self):
        code, out = self.run_main(self.allocate_argv(), MemoryLedgerStore())
        self.assertEqual(1, code)
        self.assertTrue(out.startswith("ERROR:"))
        self.assertFalse(self.out.exists())

    def test_malformed_input_is_an_error_not_a_traceback(self):
        bad = self.write("bad.json", "{not json")
        argv = self.allocate_argv(extra=["--app-store-versions", bad])
        code, out = self.run_main(argv, self.bootstrapped())
        self.assertEqual(1, code)
        self.assertTrue(out.startswith("ERROR:"))
        self.assertFalse(self.out.exists())

    def test_mistyped_store_value_is_an_error_not_a_traceback(self):
        bad = self.write(
            "typed.json",
            json.dumps(
                [{"attributes": {"versionString": 120,
                                 "appVersionState": "READY_FOR_SALE"}}]
            ),
        )
        argv = self.allocate_argv(extra=["--app-store-versions", bad])
        code, out = self.run_main(argv, self.bootstrapped())
        self.assertEqual(1, code)
        self.assertTrue(out.startswith("ERROR:"))
        self.assertNotIn("Traceback", out)
        self.assertFalse(self.out.exists())

    def test_store_latest_build_must_be_plain_digits(self):
        for bad in ("-1", "abc", "1_000", "+5", " 5 "):
            with self.subTest(value=bad):
                argv = self.allocate_argv()
                argv[argv.index("--store-latest-build") + 1] = bad
                with contextlib.redirect_stderr(io.StringIO()):
                    with self.assertRaises(SystemExit) as raised:
                        self.run_main(argv, self.bootstrapped())
                self.assertEqual(2, raised.exception.code)
                self.assertFalse(self.out.exists())

    def repo_used(self, prefix, env):
        seen = []

        def factory(repo):
            seen.append(repo)
            return self.bootstrapped()

        with mock.patch.dict(os.environ, env):
            if "SHOREBIRD_PROVENANCE_REPOSITORY" not in env:
                os.environ.pop("SHOREBIRD_PROVENANCE_REPOSITORY", None)
            with contextlib.redirect_stdout(io.StringIO()):
                release_identity.main(
                    prefix + self.allocate_argv(), ledger_factory=factory, now=NOW
                )
        return seen

    def test_ledger_repository_default(self):
        self.assertEqual(
            ["divinevideo/divine-release-provenance"], self.repo_used([], {})
        )

    def test_ledger_repository_env_override(self):
        env = {"SHOREBIRD_PROVENANCE_REPOSITORY": "org/from-env"}
        self.assertEqual(["org/from-env"], self.repo_used([], env))

    def test_ledger_repository_flag_wins(self):
        env = {"SHOREBIRD_PROVENANCE_REPOSITORY": "org/from-env"}
        self.assertEqual(
            ["org/flag"],
            self.repo_used(["--ledger-repository", "org/flag"], env),
        )

    def test_invalid_store_payload_is_an_error(self):
        empty = self.write("empty.json", "[]")
        argv = self.allocate_argv(extra=["--app-store-versions", empty])
        code, out = self.run_main(argv, self.bootstrapped())
        self.assertEqual(1, code)
        self.assertTrue(out.startswith("ERROR:"))

    def test_missing_input_file_is_an_error(self):
        argv = self.allocate_argv(extra=["--app-store-versions", "/nope.json"])
        code, out = self.run_main(argv, self.bootstrapped())
        self.assertEqual(1, code)
        self.assertTrue(out.startswith("ERROR:"))

    def test_platform_specific_input_is_required(self):
        for platform, wrong in (
            ("ios", ["--play-production-track", self.play]),
            ("android", ["--app-store-versions", self.ios]),
        ):
            for extra in ([], wrong):
                with self.subTest(platform=platform, extra=extra):
                    with contextlib.redirect_stderr(io.StringIO()):
                        with self.assertRaises(SystemExit) as raised:
                            self.run_main(
                                self.allocate_argv(platform, extra=extra),
                                self.bootstrapped(),
                            )
                    self.assertEqual(2, raised.exception.code)

    def unbootstrapped(self):
        return MemoryLedgerStore({PLAY_PROVENANCE: {}})

    def bootstrap_argv(self, play=None):
        return [
            "bootstrap",
            "--app-store-versions", self.ios,
            "--play-production-track", play or self.play,
        ]

    def test_bootstrap_dry_run_prints_paths_without_writing(self):
        store = self.unbootstrapped()
        code, out = self.run_main(
            [
                "bootstrap",
                "--app-store-versions", self.ios,
                "--play-production-track", self.play,
                "--dry-run",
            ],
            store,
        )
        self.assertEqual(0, code)
        self.assertEqual([], store.creates)
        self.assertIn(BOOTSTRAP_PATH, out.splitlines())
        self.assertIn("allocations/claims/1.2.5/app-store.json", out.splitlines())
        self.assertIn(
            "allocations/claims/1.2.7/play-production.json", out.splitlines()
        )
        self.assertEqual("would create:", out.splitlines()[0])

    def test_bootstrap_real_run_claims_both_stores_then_writes_the_marker(self):
        store = self.unbootstrapped()
        code, out = self.run_main(self.bootstrap_argv(), store)
        self.assertEqual(0, code, out)
        self.assertEqual("created:", out.splitlines()[0])
        self.assertEqual(
            [
                "allocations/claims/1.2.5/app-store.json",
                "allocations/claims/1.2.7/play-production.json",
                BOOTSTRAP_PATH,
            ],
            store.creates,
        )
        self.assertEqual(store.creates, out.splitlines()[1:])

    def test_bootstrap_unmapped_play_code_writes_nothing(self):
        store = MemoryLedgerStore()
        for extra in ([], ["--dry-run"]):
            with self.subTest(extra=extra):
                code, out = self.run_main(self.bootstrap_argv() + extra, store)
                self.assertEqual(1, code)
                self.assertTrue(out.startswith("ERROR:"), out)
                self.assertIn("300", out)
                self.assertEqual([], store.creates)

    def test_bootstrap_empty_play_production_view_writes_nothing(self):
        empty = self.write(
            "empty-play.json", json.dumps({"track": "production", "releases": []})
        )
        store = self.unbootstrapped()
        code, out = self.run_main(self.bootstrap_argv(play=empty), store)
        self.assertEqual(1, code)
        self.assertTrue(out.startswith("ERROR:"), out)
        self.assertEqual([], store.creates)

    def test_bootstrap_with_nothing_to_create_says_so(self):
        store = MemoryLedgerStore(
            {
                BOOTSTRAP_PATH: {"schema": 1},
                PLAY_PROVENANCE: {},
                "allocations/claims/1.2.5/app-store.json": {},
                "allocations/claims/1.2.7/play-production.json": {},
            }
        )
        for extra in ([], ["--dry-run"]):
            code, out = self.run_main(
                [
                    "bootstrap",
                    "--app-store-versions", self.ios,
                    "--play-production-track", self.play,
                ]
                + extra,
                store,
            )
            self.assertEqual(0, code)
            self.assertEqual(
                ["ledger already bootstrapped; nothing to create"], out.splitlines()
            )
        self.assertEqual([], store.creates)

    def test_script_runs_as_a_file(self):
        result = subprocess.run(
            [sys.executable, str(SCRIPT), "--help"],
            cwd=REPO_ROOT / "mobile",
            capture_output=True,
            text=True,
        )
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertIn("allocate", result.stdout)


if __name__ == "__main__":
    unittest.main()
