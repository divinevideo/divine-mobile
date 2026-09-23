"""Behavioural tests for scripts/install-hooks.sh.

The installer stamps a content hash of itself into every generated hook. A hook
whose stamp no longer matches the installer re-installs itself and aborts
instead of running, so a checkout cannot keep executing a hook built by an
older contract — for example one that called `flutter`/`dart` directly rather
than through `mise exec` and so used whatever toolchain happened to be on PATH
instead of the version mobile/mise.toml pins.
"""

import hashlib
import os
import shutil
import stat
import subprocess
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
INSTALLER = REPO_ROOT / "scripts" / "install-hooks.sh"
HOOKS = ("pre-commit", "pre-push")


def run(cmd, cwd, env):
    return subprocess.run(cmd, cwd=cwd, env=env, capture_output=True, text=True)


class InstallHooksTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.root = Path(self._tmp.name) / "repo"
        (self.root / "scripts").mkdir(parents=True)
        # The generated hooks cd into mobile/ before their staleness check.
        (self.root / "mobile").mkdir()
        (self.root / "mobile" / ".gitkeep").touch()
        shutil.copy(INSTALLER, self.root / "scripts" / "install-hooks.sh")
        self.installer = self.root / "scripts" / "install-hooks.sh"

        # The installer only checks that `mise` is on PATH; it never calls it.
        # A stub keeps this test runnable on runners that do not install mise.
        self.bin = Path(self._tmp.name) / "bin"
        self.bin.mkdir()
        mise = self.bin / "mise"
        mise.write_text("#!/bin/sh\nexit 0\n")
        mise.chmod(mise.stat().st_mode | stat.S_IEXEC)

        # Git exports GIT_DIR and friends to hooks, `git rebase -x` and
        # `git bisect run`. Inherited, they point `git init` and the installer
        # at the enclosing repository, which then gets its real hooks
        # overwritten, so drop them along with the caller's git config.
        env = {k: v for k, v in os.environ.items() if not k.startswith("GIT_")}
        env["PATH"] = f"{self.bin}{os.pathsep}{env['PATH']}"
        env["GIT_CONFIG_GLOBAL"] = os.devnull
        env["GIT_CONFIG_NOSYSTEM"] = "1"
        self.env = env

        self.git("init", "-q", "-b", "main")
        # pre-push reads HEAD, and a linked worktree needs a commit to check out.
        self.git("add", "-A")
        self.git(
            "-c", "user.name=Test", "-c", "user.email=test@example.invalid",
            "commit", "-q", "-m", "init",
        )

    def git(self, *args):
        return subprocess.run(
            ["git", *args],
            cwd=self.root,
            env=self.env,
            check=True,
            capture_output=True,
            text=True,
        )

    def hooks_dir(self):
        return self.root / ".git" / "hooks"

    def installer_hash(self):
        return hashlib.sha256(self.installer.read_bytes()).hexdigest()

    def install(self):
        result = run(["bash", "scripts/install-hooks.sh"], self.root, self.env)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return result

    def change_installer(self):
        self.installer.write_text(
            self.installer.read_text() + "\n# installer changed\n"
        )

    def run_hook(self, name, cwd=None):
        # Executed the way git runs it, so a hook that lost its executable bit
        # fails here rather than passing under an explicit `bash`.
        argv = [str(self.hooks_dir() / name)]
        if name == "pre-push":
            argv += ["origin", "https://example.invalid"]
        return subprocess.run(
            argv,
            cwd=cwd or self.root,
            env=self.env,
            stdin=subprocess.DEVNULL,
            capture_output=True,
            text=True,
        )

    def assert_runs_clean(self, result):
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertNotIn("stale", result.stdout.lower())

    def assert_stale_hook_heals(self, name):
        self.install()
        self.change_installer()

        stale = self.run_hook(name)

        self.assertEqual(stale.returncode, 1, stale.stdout + stale.stderr)
        self.assertIn("stale", stale.stdout.lower())
        # The re-install stamped the current installer, so the next run is clean.
        self.assert_runs_clean(self.run_hook(name))

    def test_installs_both_hooks_with_a_matching_stamp(self):
        self.install()

        expected = self.installer_hash()
        for name in HOOKS:
            body = (self.hooks_dir() / name).read_text()
            self.assertNotIn("@GENERATOR_HASH@", body)
            self.assertIn(f'HOOKS_GENERATOR_HASH="{expected}"', body)

    def test_freshly_installed_hooks_pass_their_staleness_check(self):
        self.install()

        for name in HOOKS:
            with self.subTest(hook=name):
                self.assert_runs_clean(self.run_hook(name))

    def test_stale_pre_commit_reinstalls_itself_and_aborts(self):
        self.assert_stale_hook_heals("pre-commit")

    def test_stale_pre_push_reinstalls_itself_and_aborts(self):
        self.assert_stale_hook_heals("pre-push")

    def test_reinstall_leaves_a_running_hook_its_original_script(self):
        self.install()
        hook = self.hooks_dir() / "pre-push"

        # bash reads a hook it is running through an open descriptor like this.
        with hook.open("rb") as running:
            original = hook.read_bytes()
            self.change_installer()
            self.install()

            self.assertNotEqual(hook.read_bytes(), original)
            self.assertEqual(running.read(), original)

    def test_hooks_run_clean_from_a_linked_worktree(self):
        self.install()
        linked = Path(self._tmp.name) / "linked"
        self.git("worktree", "add", "-q", "-b", "feature", str(linked))

        for name in HOOKS:
            with self.subTest(hook=name):
                self.assert_runs_clean(self.run_hook(name, cwd=linked))

    def test_installed_hooks_are_readable_and_runnable_by_everyone(self):
        previous = os.umask(0o022)
        self.addCleanup(os.umask, previous)

        self.install()

        for name in HOOKS:
            with self.subTest(hook=name):
                mode = stat.S_IMODE((self.hooks_dir() / name).stat().st_mode)
                self.assertEqual(mode, 0o755, oct(mode))

    def test_install_leaves_nothing_behind_but_the_hooks(self):
        self.install()

        installed = sorted(
            p.name
            for p in self.hooks_dir().iterdir()
            if not p.name.endswith(".sample")
        )
        self.assertEqual(installed, sorted(HOOKS))

    def test_failed_install_leaves_no_staging_files(self):
        # A chmod that fails stops the install after staging has started.
        broken = Path(self._tmp.name) / "broken-bin"
        broken.mkdir()
        (broken / "chmod").write_text("#!/bin/sh\nexit 1\n")
        (broken / "chmod").chmod(0o755)
        env = {**self.env, "PATH": f"{broken}{os.pathsep}{self.env['PATH']}"}

        result = run(["bash", "scripts/install-hooks.sh"], self.root, env)

        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        staged = [
            p.name
            for p in self.hooks_dir().iterdir()
            if p.name.startswith(".install-hooks.")
        ]
        self.assertEqual(staged, [])


if __name__ == "__main__":
    unittest.main()
