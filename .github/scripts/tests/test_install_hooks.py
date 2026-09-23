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


def run(cmd, cwd, env):
    return subprocess.run(cmd, cwd=cwd, env=env, capture_output=True, text=True)


class InstallHooksTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.root = Path(self._tmp.name) / "repo"
        (self.root / "scripts").mkdir(parents=True)
        # The generated hooks cd into mobile/ before their staleness check.
        (self.root / "mobile").mkdir()
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

        subprocess.run(
            ["git", "init", "-q", "-b", "main"],
            cwd=self.root,
            env=self.env,
            check=True,
            capture_output=True,
        )
        self.addCleanup(self._tmp.cleanup)

    def hooks_dir(self):
        return self.root / ".git" / "hooks"

    def installer_hash(self):
        return hashlib.sha256(self.installer.read_bytes()).hexdigest()

    def install(self):
        result = run(["bash", "scripts/install-hooks.sh"], self.root, self.env)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return result

    def test_installs_both_hooks_with_a_matching_stamp(self):
        self.install()

        expected = self.installer_hash()
        for name in ("pre-commit", "pre-push"):
            body = (self.hooks_dir() / name).read_text()
            self.assertNotIn("@GENERATOR_HASH@", body)
            self.assertIn(f'HOOKS_GENERATOR_HASH="{expected}"', body)

    def test_stale_hook_reinstalls_itself_and_aborts(self):
        self.install()
        self.installer.write_text(
            self.installer.read_text() + "\n# installer changed\n"
        )

        result = run(
            ["bash", ".git/hooks/pre-push", "origin", "https://example.invalid"],
            self.root,
            self.env,
        )

        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("stale", result.stdout.lower())
        # The re-install stamped the current installer, so the next run is clean.
        body = (self.hooks_dir() / "pre-push").read_text()
        self.assertIn(f'HOOKS_GENERATOR_HASH="{self.installer_hash()}"', body)


if __name__ == "__main__":
    unittest.main()
