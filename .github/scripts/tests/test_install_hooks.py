"""Behavioural tests for scripts/install-hooks.sh and the hooks it installs.

The installer puts a thin shim in the hooks directory every worktree shares.
At run time the shim execs the tracked scripts/hooks/<name> of the worktree git
invoked it from, so each worktree runs the checks its own branch carries and
no worktree rewrites the hooks another is using.
"""

import os
import shutil
import stat
import subprocess
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
INSTALLER = REPO_ROOT / "scripts" / "install-hooks.sh"
TRACKED_HOOKS = REPO_ROOT / "scripts" / "hooks"
HOOKS = ("pre-commit", "pre-push")

COMMIT = ("-c", "user.name=Test", "-c", "user.email=test@example.invalid")


def run(cmd, cwd, env, **kwargs):
    return subprocess.run(cmd, cwd=cwd, env=env, capture_output=True, text=True, **kwargs)


def fake_hook(marker, status=0):
    # Records what the shim handed it: its own path, argv, stdin, cwd.
    return (
        "#!/bin/bash\n"
        f'echo "ran {marker} from $0 args=$* cwd=$PWD"\n'
        'if [ ! -t 0 ]; then echo "stdin=$(cat)"; fi\n'
        f"exit {status}\n"
    )


class InstallHooksTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.root = Path(self._tmp.name) / "repo"
        (self.root / "scripts" / "hooks").mkdir(parents=True)
        (self.root / "mobile").mkdir()
        (self.root / "mobile" / ".gitkeep").touch()
        shutil.copy(INSTALLER, self.root / "scripts" / "install-hooks.sh")
        for name in HOOKS:
            self.write_tracked_hook(name, fake_hook(f"main-{name}"))

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
        self.commit_all("init")

    def git(self, *args, cwd=None):
        return subprocess.run(
            ["git", *args],
            cwd=cwd or self.root,
            env=self.env,
            check=True,
            capture_output=True,
            text=True,
        )

    def commit_all(self, message, cwd=None):
        self.git("add", "-A", cwd=cwd)
        self.git(*COMMIT, "commit", "-q", "--allow-empty", "-m", message, cwd=cwd)

    def write_tracked_hook(self, name, body, root=None):
        path = (root or self.root) / "scripts" / "hooks" / name
        path.write_text(body)
        return path

    def hooks_dir(self):
        return self.root / ".git" / "hooks"

    def install(self, cwd=None, env=None):
        result = run(["bash", "scripts/install-hooks.sh"], cwd or self.root, env or self.env)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return result

    def add_worktree(self, branch="feature"):
        linked = Path(self._tmp.name) / branch
        self.git("worktree", "add", "-q", "-b", branch, str(linked))
        return linked

    def run_hook(self, name, cwd=None, stdin=None):
        # Executed the way git runs it, so a hook that lost its executable bit
        # fails here rather than passing under an explicit `bash`.
        argv = [str(self.hooks_dir() / name)]
        if name == "pre-push":
            argv += ["origin", "https://example.invalid"]
        return subprocess.run(
            argv,
            cwd=cwd or self.root,
            env=self.env,
            input=stdin,
            stdin=None if stdin is not None else subprocess.DEVNULL,
            capture_output=True,
            text=True,
        )

    def test_installed_hooks_run_the_worktrees_tracked_script(self):
        self.install()

        for name in HOOKS:
            with self.subTest(hook=name):
                result = self.run_hook(name)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertIn(f"ran main-{name}", result.stdout)
                self.assertIn(str(self.root / "scripts" / "hooks" / name), result.stdout)

    def test_each_worktree_runs_its_own_branchs_hooks(self):
        self.install()
        linked = self.add_worktree()
        for name in HOOKS:
            self.write_tracked_hook(name, fake_hook(f"feature-{name}"), root=linked)
        self.commit_all("feature hooks", cwd=linked)

        for name in HOOKS:
            with self.subTest(hook=name):
                self.assertIn(f"ran main-{name}", self.run_hook(name).stdout)
                self.assertIn(f"ran feature-{name}", self.run_hook(name, cwd=linked).stdout)

    def test_an_edit_to_a_tracked_hook_applies_without_reinstalling(self):
        self.install()
        self.write_tracked_hook("pre-commit", fake_hook("edited"))

        self.assertIn("ran edited", self.run_hook("pre-commit").stdout)

    def test_hook_exit_status_reaches_git(self):
        self.install()
        for name in HOOKS:
            self.write_tracked_hook(name, fake_hook(name, status=7))

        for name in HOOKS:
            with self.subTest(hook=name):
                self.assertEqual(self.run_hook(name).returncode, 7)

    def test_arguments_and_stdin_reach_the_tracked_script(self):
        # git feeds pre-push the refs being pushed on stdin.
        self.install()

        result = self.run_hook("pre-push", stdin="refs/heads/x abc refs/heads/x def\n")

        self.assertIn("args=origin https://example.invalid", result.stdout)
        self.assertIn("stdin=refs/heads/x abc refs/heads/x def", result.stdout)

    def test_missing_tracked_script_warns_and_lets_git_continue(self):
        # A branch older than scripts/hooks/ has nothing to run.
        self.install()
        shutil.rmtree(self.root / "scripts" / "hooks")

        for name in HOOKS:
            with self.subTest(hook=name):
                result = self.run_hook(name)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertIn(f"no scripts/hooks/{name}", result.stderr)

    def test_installing_from_any_worktree_writes_identical_shims(self):
        # Worktrees on different branches must not keep re-writing each
        # other's hooks, so the shim may not depend on the installing tree.
        self.install()
        first = {name: (self.hooks_dir() / name).read_bytes() for name in HOOKS}
        linked = self.add_worktree()
        with (linked / "scripts" / "install-hooks.sh").open("a") as installer:
            installer.write("\n# a comment only this branch has\n")

        self.install(cwd=linked)

        for name in HOOKS:
            with self.subTest(hook=name):
                self.assertEqual((self.hooks_dir() / name).read_bytes(), first[name])

    def test_shims_carry_no_checks_of_their_own(self):
        self.install()

        for name in HOOKS:
            with self.subTest(hook=name):
                body = (self.hooks_dir() / name).read_text()
                self.assertIn(f'HOOK_SCRIPT="$REPO_ROOT/scripts/hooks/{name}"', body)
                self.assertIn('exec bash "$HOOK_SCRIPT" "$@"', body)
                self.assertNotIn("mise", body)
                self.assertNotIn("@HOOK_NAME@", body)

    def test_reinstall_leaves_a_running_hook_its_original_script(self):
        (self.hooks_dir() / "pre-push").write_text("#!/bin/bash\n# pre-shim hook\n")
        hook = self.hooks_dir() / "pre-push"

        # bash reads a hook it is running through an open descriptor like this.
        with hook.open("rb") as running:
            original = hook.read_bytes()
            self.install()

            self.assertNotEqual(hook.read_bytes(), original)
            self.assertEqual(running.read(), original)

    def test_installs_into_the_right_hooks_dir_under_an_exported_cdpath(self):
        # With CDPATH set, `cd .git` can land in a same-named directory
        # elsewhere and print where it went.
        decoy = Path(self._tmp.name) / "decoy"
        (decoy / ".git" / "hooks").mkdir(parents=True)
        linked = self.add_worktree()
        env = {**self.env, "CDPATH": str(decoy)}

        self.install(cwd=linked, env=env)

        self.assertEqual(list((decoy / ".git" / "hooks").iterdir()), [])
        self.assertIn("ran main-pre-commit", self.run_hook("pre-commit").stdout)

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

    def test_real_tracked_hooks_pass_when_there_is_nothing_to_check(self):
        # The repo's actual hooks, through the shim: pre-commit with nothing
        # staged and pre-push with no Dart changes both finish cleanly.
        for name in HOOKS:
            shutil.copy(TRACKED_HOOKS / name, self.root / "scripts" / "hooks" / name)
        self.commit_all("real hooks")
        self.install()

        for name in HOOKS:
            with self.subTest(hook=name):
                result = self.run_hook(name)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
