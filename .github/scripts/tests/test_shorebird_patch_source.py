import subprocess
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[3]
SCRIPT = REPO_ROOT / "mobile" / "scripts" / "shorebird_patch_source.rb"


class ShorebirdPatchSourceTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp_dir = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp_dir.cleanup)
        self.root = Path(self.temp_dir.name)
        subprocess.run(["git", "init", "-q"], cwd=self.root, check=True)
        # A commit starts a detached `git maintenance run --auto` that can still be
        # writing into .git/objects when the temporary directory is removed.
        subprocess.run(
            ["git", "config", "maintenance.auto", "false"], cwd=self.root, check=True
        )
        subprocess.run(
            ["git", "config", "user.email", "shorebird-test@example.invalid"],
            cwd=self.root,
            check=True,
        )
        subprocess.run(
            ["git", "config", "user.name", "Shorebird Test"],
            cwd=self.root,
            check=True,
        )
        self._commit("lib/release.dart", "const release = true;\n", "release")
        self.baseline = self._git("rev-parse", "HEAD")
        # The validator compares the patch range against main's remote-tracking
        # ref; fixtures start with main sitting exactly on the baseline.
        self._git("update-ref", "refs/remotes/origin/main", self.baseline)

    def _git(self, *arguments: str) -> str:
        return subprocess.run(
            ["git", *arguments],
            cwd=self.root,
            check=True,
            text=True,
            capture_output=True,
        ).stdout.strip()

    def _commit(self, relative_path: str, contents: str, message: str) -> str:
        path = self.root / relative_path
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(contents)
        self._git("add", relative_path)
        self._git("commit", "-m", message)
        return self._git("rev-parse", "HEAD")

    def _run(
        self,
        *,
        baseline: str | None = None,
        platform: str = "ios",
        release_version: str = "1.2.3+456",
        branch: str = "shorebird-patch/ios/1.2.3+456",
        cwd: Path | None = None,
    ) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [
                "ruby",
                str(SCRIPT),
                "--baseline",
                baseline or self.baseline,
                "--platform",
                platform,
                "--release-version",
                release_version,
                "--branch",
                branch,
            ],
            cwd=cwd or self.root,
            check=False,
            text=True,
            capture_output=True,
        )

    def test_accepts_matching_release_branch_with_dart_fix(self) -> None:
        self._commit("lib/fix.dart", "const fixed = true;\n", "fix")

        result = self._run()

        self.assertEqual(0, result.returncode, result.stderr)
        self.assertIn("Verified patch branch", result.stdout)
        self.assertIn("lib/fix.dart", result.stdout)

    def test_rejects_main_and_another_release_or_platform(self) -> None:
        self._commit("lib/fix.dart", "const fixed = true;\n", "fix")

        for branch in (
            "main",
            "shorebird-patch/ios/1.2.3+457",
            "shorebird-patch/android/1.2.3+456",
        ):
            with self.subTest(branch=branch):
                result = self._run(branch=branch)
                self.assertNotEqual(0, result.returncode)
                self.assertIn("patch branch must be exactly", result.stderr)

    def test_rejects_release_version_that_is_unsafe_in_a_refspec(self) -> None:
        result = self._run(
            release_version="1.2.3:malicious",
            branch="shorebird-patch/ios/1.2.3:malicious",
        )

        self.assertNotEqual(0, result.returncode)
        self.assertIn("unsafe in a branch name", result.stderr)

    def test_rejects_history_not_descended_from_release(self) -> None:
        main_branch = self._git("branch", "--show-current")
        self._git("checkout", "--orphan", "unrelated-root")
        self._git("rm", "-rf", "--quiet", ".")
        self._commit("UNRELATED.md", "unrelated\n", "unrelated root")
        unrelated = self._git("rev-parse", "HEAD")
        self._git("checkout", main_branch)

        result = self._run(baseline=unrelated)

        self.assertNotEqual(0, result.returncode)
        self.assertIn("not an ancestor", result.stderr)

    def test_rejects_blocked_paths(self) -> None:
        blocked_paths = (
            "android/app/build.gradle",
            "ios/Runner/AppDelegate.swift",
            "assets/icon.png",
            "pubspec.yaml",
            "scripts/deploy.sh",
            "packages/divine_ui/ios/plugin.swift",
            "packages/divine_ui/pubspec.yaml",
        )
        for index, blocked_path in enumerate(blocked_paths):
            with self.subTest(path=blocked_path):
                self._git("reset", "--hard", self.baseline)
                self._commit(blocked_path, f"blocked {index}\n", "blocked")
                self._commit("lib/fix.dart", "const fixed = true;\n", "fix")

                result = self._run()

                self.assertNotEqual(0, result.returncode)
                self.assertIn(blocked_path, result.stderr)

    def test_rejects_native_paths_in_a_vendored_dependency_override(self) -> None:
        # overrides/ holds path-based dependency_overrides forks whose Kotlin,
        # Swift and podspec sources compile into the app exactly like a
        # first-party plugin's, but they are not reachable through packages/.
        blocked_paths = (
            "overrides/app_device_integrity-1.1.0/ios/Classes/Plugin.swift",
            "overrides/app_device_integrity-1.1.0/android/build.gradle",
            "overrides/app_device_integrity-1.1.0/pubspec.yaml",
        )
        for index, blocked_path in enumerate(blocked_paths):
            with self.subTest(path=blocked_path):
                self._git("reset", "--hard", self.baseline)
                self._commit(blocked_path, f"blocked {index}\n", "blocked")
                self._commit("lib/fix.dart", "const fixed = true;\n", "fix")

                result = self._run()

                self.assertNotEqual(0, result.returncode)
                self.assertIn(blocked_path, result.stderr)

    def test_rejects_app_root_build_scripts(self) -> None:
        # The Runner scheme runs pre_build_ios.sh as a build pre-action, so an
        # app-root shell script executes during the signed patch build even
        # though ios/ itself is blocked and cannot change.
        for index, blocked_path in enumerate(("pre_build_ios.sh", "build_native.sh")):
            with self.subTest(path=blocked_path):
                self._git("reset", "--hard", self.baseline)
                self._commit(blocked_path, f"echo blocked {index}\n", "blocked")
                self._commit("lib/fix.dart", "const fixed = true;\n", "fix")

                result = self._run()

                self.assertNotEqual(0, result.returncode)
                self.assertIn(blocked_path, result.stderr)

    def test_accepts_dart_only_change_inside_a_vendored_override(self) -> None:
        # Blocking an override's native surfaces must not block a Dart-only
        # backport inside the same vendored package.
        self._commit(
            "overrides/app_device_integrity-1.1.0/lib/plugin.dart",
            "const fixed = true;\n",
            "dart-only override fix",
        )

        result = self._run()

        self.assertEqual(0, result.returncode, result.stderr)
        self.assertIn(
            "overrides/app_device_integrity-1.1.0/lib/plugin.dart", result.stdout
        )

    def test_rejects_blocked_paths_under_mobile_directory(self) -> None:
        # Mirrors the real layout and Codemagic's working_directory: the app
        # lives under mobile/, and git diff --name-only still prints
        # repository-root-relative paths.
        mobile = self.root / "mobile"
        for index, blocked_path in enumerate(
            ("mobile/ios/Runner/AppDelegate.swift", "mobile/scripts/deploy.sh")
        ):
            with self.subTest(path=blocked_path):
                self._git("reset", "--hard", self.baseline)
                self._commit(blocked_path, f"blocked {index}\n", "blocked")
                self._commit("mobile/lib/fix.dart", "const fixed = true;\n", "fix")

                for cwd in (self.root, mobile):
                    with self.subTest(cwd=cwd):
                        result = self._run(cwd=cwd)
                        self.assertNotEqual(0, result.returncode)
                        self.assertIn(
                            blocked_path.removeprefix("mobile/"), result.stderr
                        )

    def test_accepts_dart_fix_from_mobile_working_directory(self) -> None:
        self._commit("mobile/lib/fix.dart", "const fixed = true;\n", "fix")

        result = self._run(cwd=self.root / "mobile")

        self.assertEqual(0, result.returncode, result.stderr)
        self.assertIn("lib/fix.dart", result.stdout)

    def test_rejects_branch_cut_from_advanced_main(self) -> None:
        # main advances past the baseline...
        self._commit("lib/advanced.dart", "const advanced = true;\n", "advanced main")
        self._git(
            "update-ref", "refs/remotes/origin/main", self._git("rev-parse", "HEAD")
        )
        # ...and the operator cuts the patch branch at main's tip instead of
        # branching from the baseline and cherry-picking.
        self._commit("lib/fix.dart", "const fixed = true;\n", "fix")

        result = self._run()

        self.assertNotEqual(0, result.returncode)
        self.assertIn("contains commits already on main", result.stderr)

    def test_accepts_cherry_pick_when_baseline_is_main_tip(self) -> None:
        # Branching at a baseline that is still main's tip is fine: the
        # backport arrives as a cherry-pick, a new object absent from main.
        # The fixture uses a plain commit rather than a real `git cherry-pick`
        # on purpose: a cherry-pick can bit-for-bit reproduce the source
        # commit's SHA when tree, parent, and author/committer identity and
        # second all coincide, which would (correctly) trip the on-main check
        # and make this test intermittently red.
        self._commit("lib/fix.dart", "const fixed = true;\n", "fix")

        result = self._run()

        self.assertEqual(0, result.returncode, result.stderr)

    def test_rejects_when_main_ref_is_unavailable(self) -> None:
        self._git("update-ref", "-d", "refs/remotes/origin/main")
        self._commit("lib/fix.dart", "const fixed = true;\n", "fix")

        result = self._run()

        self.assertNotEqual(0, result.returncode)
        self.assertIn("fetch main before validating", result.stderr)

    def test_rejects_empty_dart_diff(self) -> None:
        self._commit("README.md", "documentation only\n", "docs")

        result = self._run()

        self.assertNotEqual(0, result.returncode)
        self.assertIn("no Dart changes", result.stderr)

    def test_rejects_merge_commits(self) -> None:
        self._git("checkout", "-b", "side")
        self._commit("lib/side.dart", "const side = true;\n", "side")
        self._git("checkout", "-b", "patch-line", self.baseline)
        self._commit("lib/fix.dart", "const fixed = true;\n", "fix")
        self._git("merge", "--no-ff", "side", "-m", "merge side")

        result = self._run()

        self.assertNotEqual(0, result.returncode)
        self.assertIn("contains merge commits", result.stderr)

    def test_second_patch_reports_both_cumulative_fixes(self) -> None:
        self._commit("lib/first_fix.dart", "const first = true;\n", "first fix")
        self._commit("lib/second_fix.dart", "const second = true;\n", "second fix")

        result = self._run()

        self.assertEqual(0, result.returncode, result.stderr)
        self.assertIn("lib/first_fix.dart", result.stdout)
        self.assertIn("lib/second_fix.dart", result.stdout)


if __name__ == "__main__":
    unittest.main()
