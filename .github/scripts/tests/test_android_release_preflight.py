import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[3]
CODEMAGIC_PATH = REPO_ROOT / "codemagic.yaml"
SHOREBIRD_RELEASE_PREFLIGHT_PATH = (
    REPO_ROOT / "mobile" / "scripts" / "shorebird_release_preflight.rb"
)
STEP_NAME = "Preflight Android Shorebird release"


def android_preflight_script() -> str:
    """Return the preflight step exactly as android-build runs it."""
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
        for step in config["workflows"]["android-build"]["scripts"]
        if isinstance(step, dict) and step.get("name") == STEP_NAME
    ]
    if len(steps) != 1:
        raise AssertionError(
            f"expected one {STEP_NAME!r} step in android-build, found {len(steps)}"
        )
    return steps[0]["script"]


def write_stub(path: Path, stdout: str, stderr: str, exit_code: int) -> None:
    path.write_text(
        "#!/usr/bin/env python3\n"
        "import sys\n"
        f"sys.stdout.write({stdout!r})\n"
        f"sys.stderr.write({stderr!r})\n"
        f"sys.exit({exit_code})\n"
    )
    path.chmod(0o755)


class AndroidReleasePreflightTest(unittest.TestCase):
    """Runs the real preflight step against stub store and Shorebird CLIs."""

    script: str

    @classmethod
    def setUpClass(cls) -> None:
        cls.script = android_preflight_script()

    def run_preflight(
        self,
        *,
        play_stdout: str = "",
        play_stderr: str = "",
        play_exit: int = 0,
        project_build_number: str = "900",
    ) -> tuple[subprocess.CompletedProcess[str], str | None]:
        with tempfile.TemporaryDirectory() as tmp:
            mobile = Path(tmp) / "mobile"
            (mobile / "build" / "shorebird").mkdir(parents=True)
            (mobile / "scripts").mkdir()
            (mobile / "scripts" / "shorebird_release_preflight.rb").symlink_to(
                SHOREBIRD_RELEASE_PREFLIGHT_PATH
            )
            (mobile / "pubspec.yaml").write_text(
                "name: openvine\nversion: 1.0.28+820\n"
            )
            bin_dir = Path(tmp) / "bin"
            bin_dir.mkdir()
            write_stub(bin_dir / "google-play", play_stdout, play_stderr, play_exit)
            write_stub(
                bin_dir / "shorebird",
                json.dumps({"status": "success", "data": {"releases": []}}),
                "",
                0,
            )
            env = {
                **os.environ,
                "PATH": f"{bin_dir}{os.pathsep}{os.environ['PATH']}",
                "PROJECT_BUILD_NUMBER": project_build_number,
            }
            result = subprocess.run(
                ["bash", "-c", self.script],
                cwd=mobile,
                env=env,
                check=False,
                text=True,
                capture_output=True,
            )
            release_env_path = mobile / "build" / "shorebird" / "android_release.env"
            release_env = (
                release_env_path.read_text() if release_env_path.exists() else None
            )
        return result, release_env

    def test_play_lookup_failure_stops_before_a_build_number_is_chosen(self) -> None:
        result, release_env = self.run_preflight(
            play_stderr="Google Play API: 401 Unauthorized\n",
            play_exit=1,
        )

        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn(
            "could not read the latest Google Play build number", result.stdout
        )
        self.assertIn("401 Unauthorized", result.stdout)
        self.assertIsNone(release_env)

    def test_unreadable_play_lookup_stops_before_a_build_number_is_chosen(
        self,
    ) -> None:
        result, release_env = self.run_preflight(play_stdout="No builds found\n")

        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn(
            "could not read the latest Google Play build number", result.stdout
        )
        self.assertIn("No builds found", result.stdout)
        self.assertIsNone(release_env)

    def test_next_play_build_number_wins_over_a_lower_codemagic_counter(
        self,
    ) -> None:
        result, release_env = self.run_preflight(
            play_stdout="1000\n", project_build_number="900"
        )

        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIsNotNone(release_env)
        self.assertIn("SHOREBIRD_BUILD_NUMBER=1001\n", release_env)
        self.assertIn("SHOREBIRD_RELEASE_VERSION=1.0.28+1001\n", release_env)

    def test_codemagic_counter_wins_over_a_lower_play_build_number(self) -> None:
        result, release_env = self.run_preflight(
            play_stdout="500\n", project_build_number="900"
        )

        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIsNotNone(release_env)
        self.assertIn("SHOREBIRD_BUILD_NUMBER=900\n", release_env)
        self.assertIn("SHOREBIRD_RELEASE_VERSION=1.0.28+900\n", release_env)


if __name__ == "__main__":
    unittest.main()
