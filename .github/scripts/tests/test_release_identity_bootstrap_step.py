import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[3]
CODEMAGIC_PATH = REPO_ROOT / "codemagic.yaml"
WORKFLOW = "release-identity-bootstrap"
STEP_NAME = "Bootstrap release identity ledger"
DRY_RUN_INPUT = "${{ inputs.DRY_RUN }}"

ASC_VERSIONS = [
    {"attributes": {"versionString": "1.0.27", "appVersionState": "READY_FOR_SALE"}}
]
PLAY_TRACK = {
    "track": "production",
    "releases": [{"status": "completed", "versionCodes": ["844"]}],
}


def bootstrap_step_script() -> str:
    """Return the bootstrap step exactly as Codemagic stores it."""
    config = json.loads(
        subprocess.run(
            [
                "ruby",
                "-ryaml",
                "-rjson",
                "-e",
                "print JSON.generate(YAML.safe_load(File.read(ARGV[0]), aliases: true))",
                str(CODEMAGIC_PATH),
            ],
            check=True,
            text=True,
            capture_output=True,
        ).stdout
    )
    steps = [
        step
        for step in config["workflows"][WORKFLOW]["scripts"]
        if isinstance(step, dict) and step.get("name") == STEP_NAME
    ]
    if len(steps) != 1:
        raise AssertionError(f"expected one {STEP_NAME!r} step, found {len(steps)}")
    return steps[0]["script"]


def write_lookup_stub(path: Path, log: Path, stdout: str, exit_code: int) -> None:
    path.write_text(
        "#!/usr/bin/env python3\n"
        "import sys\n"
        f"with open({str(log)!r}, 'a') as log:\n"
        f"    log.write({path.name!r} + '\\n')\n"
        f"sys.stdout.write({stdout!r})\n"
        "if " + str(exit_code) + ":\n"
        "    sys.stderr.write('lookup failed: 401 Unauthorized\\n')\n"
        f"sys.exit({exit_code})\n"
    )
    path.chmod(0o755)


# Stands in for scripts/release_identity.py: records its argv and the
# contents of the store files it was handed, which the step deletes on exit.
RELEASE_IDENTITY_STUB = """\
import json, sys
argv = sys.argv[1:]
record = {"argv": argv}
for flag in ("--app-store-versions", "--play-production-track"):
    if flag in argv:
        with open(argv[argv.index(flag) + 1]) as handle:
            record[flag] = json.load(handle)
with open(RECORD, "w") as out:
    json.dump(record, out)
"""


class BootstrapStepTest(unittest.TestCase):
    """Runs the real bootstrap step against stub store CLIs and a stub script."""

    script: str

    @classmethod
    def setUpClass(cls) -> None:
        cls.script = bootstrap_step_script()

    def test_the_step_reads_the_dry_run_input(self) -> None:
        # Guards the substitution below: if the input name changes, every
        # other test here would silently run with a literal placeholder.
        self.assertIn(DRY_RUN_INPUT, self.script)

    def run_step(
        self,
        dry_run: str,
        *,
        branch: "str | None" = "main",
        asc_exit: int = 0,
        play_exit: int = 0,
    ):
        with tempfile.TemporaryDirectory() as tmp:
            mobile = Path(tmp) / "mobile"
            (mobile / "scripts").mkdir(parents=True)
            record = Path(tmp) / "release_identity.json"
            (mobile / "scripts" / "release_identity.py").write_text(
                f"RECORD = {str(record)!r}\n" + RELEASE_IDENTITY_STUB
            )
            bin_dir = Path(tmp) / "bin"
            bin_dir.mkdir()
            lookups = Path(tmp) / "lookups.log"
            write_lookup_stub(
                bin_dir / "app-store-connect", lookups, json.dumps(ASC_VERSIONS), asc_exit
            )
            write_lookup_stub(
                bin_dir / "google-play", lookups, json.dumps(PLAY_TRACK), play_exit
            )
            env = {
                **os.environ,
                "PATH": f"{bin_dir}{os.pathsep}{os.environ['PATH']}",
            }
            env.pop("CM_BRANCH", None)
            if branch is not None:
                env["CM_BRANCH"] = branch
            # Codemagic substitutes inputs into the script text before bash runs.
            script = self.script.replace(DRY_RUN_INPUT, dry_run)
            result = subprocess.run(
                ["bash", "-c", script],
                cwd=mobile,
                env=env,
                check=False,
                text=True,
                capture_output=True,
            )
            called = json.loads(record.read_text()) if record.exists() else None
            looked_up = lookups.read_text().split() if lookups.exists() else []
        return result, called, looked_up

    def test_yes_passes_dry_run_from_any_branch(self) -> None:
        for branch in ("main", "feat/allocator", None):
            with self.subTest(branch=branch):
                result, called, _ = self.run_step("YES", branch=branch)
                self.assertEqual(0, result.returncode, result.stdout + result.stderr)
                self.assertIsNotNone(called)
                self.assertEqual("bootstrap", called["argv"][0])
                self.assertIn("--dry-run", called["argv"])

    def test_no_on_main_writes_without_dry_run(self) -> None:
        result, called, looked_up = self.run_step("NO", branch="main")
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)
        self.assertNotIn("--dry-run", called["argv"])
        self.assertEqual("bootstrap", called["argv"][0])
        self.assertEqual(ASC_VERSIONS, called["--app-store-versions"])
        self.assertEqual(PLAY_TRACK, called["--play-production-track"])
        self.assertEqual(["app-store-connect", "google-play"], looked_up)

    def test_no_off_main_refuses_before_any_lookup(self) -> None:
        for branch in ("feat/allocator", "", None):
            with self.subTest(branch=branch):
                result, called, looked_up = self.run_step("NO", branch=branch)
                self.assertEqual(1, result.returncode)
                self.assertIn("must run from main", result.stdout)
                self.assertIsNone(called)
                self.assertEqual([], looked_up)

    def test_anything_but_yes_or_no_refuses_before_any_lookup(self) -> None:
        for value in ("", "yes", "no", "NO ", "MAYBE"):
            with self.subTest(value=value):
                result, called, looked_up = self.run_step(value)
                self.assertEqual(1, result.returncode)
                self.assertIn("DRY_RUN must be YES or NO", result.stdout)
                self.assertIsNone(called)
                self.assertEqual([], looked_up)

    def test_app_store_lookup_failure_stops_before_the_script(self) -> None:
        for dry_run in ("YES", "NO"):
            with self.subTest(dry_run=dry_run):
                result, called, looked_up = self.run_step(dry_run, asc_exit=1)
                self.assertEqual(1, result.returncode)
                self.assertIn("could not read the App Store versions", result.stdout)
                self.assertIn("401 Unauthorized", result.stdout)
                self.assertIsNone(called)
                self.assertEqual(["app-store-connect"], looked_up)

    def test_play_lookup_failure_stops_before_the_script(self) -> None:
        for dry_run in ("YES", "NO"):
            with self.subTest(dry_run=dry_run):
                result, called, _ = self.run_step(dry_run, play_exit=1)
                self.assertEqual(1, result.returncode)
                self.assertIn(
                    "could not read the Google Play production track", result.stdout
                )
                self.assertIn("401 Unauthorized", result.stdout)
                self.assertIsNone(called)


if __name__ == "__main__":
    unittest.main()
