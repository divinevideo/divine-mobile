import contextlib
import io
import json
import subprocess
import sys
import tempfile
import unittest
from datetime import datetime, timezone
from pathlib import Path

from release_train_fakes import MemoryLedgerStore

from release_train.ledger import BOOTSTRAP_PATH
import release_identity

REPO_ROOT = Path(__file__).resolve().parents[3]
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
                            "versionString": "1.2.0",
                            "appVersionState": "READY_FOR_SALE",
                        }
                    }
                ]
            ),
        )
        self.play = self.write(
            "play.json",
            json.dumps(
                {"track": "production", "releases": [{"versionCodes": []}]}
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
        return MemoryLedgerStore({BOOTSTRAP_PATH: {"schema": 1}})

    def test_allocate_writes_the_release_env(self):
        code, _ = self.run_main(self.allocate_argv(), self.bootstrapped())
        self.assertEqual(0, code)
        # 1.2.3 is a stable tag, so the version bumps to 1.2.4.
        self.assertEqual(
            "SHOREBIRD_BUILD_NAME=1.2.4\n"
            "SHOREBIRD_BUILD_NUMBER=6\n"
            "SHOREBIRD_RELEASE_VERSION=1.2.4+6\n"
            "RELEASE_TRAIN_RESERVATION_KEY=manual/abc\n"
            "RELEASE_TRAIN_RESERVATION_REUSED=false\n",
            self.out.read_text(),
        )

    def test_allocate_android_and_reuse(self):
        store = self.bootstrapped()
        argv = self.allocate_argv("android")
        self.assertEqual(0, self.run_main(argv, store)[0])
        self.assertEqual(0, self.run_main(argv, store)[0])
        self.assertIn(
            "RELEASE_TRAIN_RESERVATION_REUSED=true\n", self.out.read_text()
        )

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

    def test_bootstrap_dry_run_prints_paths_without_writing(self):
        store = MemoryLedgerStore()
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
        self.assertIn("allocations/claims/1.2.0/app-store.json", out.splitlines())

    def test_bootstrap_writes(self):
        store = MemoryLedgerStore()
        code, out = self.run_main(
            [
                "bootstrap",
                "--app-store-versions", self.ios,
                "--play-production-track", self.play,
            ],
            store,
        )
        self.assertEqual(0, code)
        self.assertIn(BOOTSTRAP_PATH, store.creates)

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
