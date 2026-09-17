"""Behavioural tests for scripts/prune-merged-branches.sh.

The classifier vetoes a worktree that holds an ignored path its regenerable
list does not name, on the principle that such a path may be work that exists
nowhere else. That list is therefore load-bearing in both directions: too
narrow and a merged worktree is reported KEEP-DIRTY forever, needing manual
triage; too broad and a scratch file becomes a delete recommendation.

Six merged worktrees were misclassified that way in one run — their only
untracked-by-git content was `mobile/ios/Podfile.lock`, Python `__pycache__`
bytecode, and Xcode's `xcshareddata/swiftpm` resolution state, each of which a
toolchain step recreates from tracked sources.
"""

import os
import stat
import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPT = (
    Path(__file__).resolve().parents[3] / "scripts" / "prune-merged-branches.sh"
)

# Answers every lookup the script makes: the branch under test is a merged head
# ref, its tip exists on GitHub, and no merged PR contains it by commit.
FAKE_GH = """#!/usr/bin/env bash
case "$1 $2" in
  "pr list")
    [ -n "${MERGED_HEAD_REF:-}" ] && printf '%s\\n' "$MERGED_HEAD_REF"
    exit 0
    ;;
esac
case "$*" in
  *"/pulls"*) echo 0; exit 0 ;;
  *"/commits/"*) exit 0 ;;
  *graphql*) echo DIVERGED; exit 0 ;;
esac
exit 0
"""


def git(repo, *args):
    return subprocess.run(
        ["git", "-C", str(repo), *args],
        check=True,
        capture_output=True,
        text=True,
    )


class PruneMergedBranchesTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        root = Path(self._tmp.name)

        self.fake_gh = root / "gh"
        self.fake_gh.write_text(FAKE_GH)
        self.fake_gh.chmod(self.fake_gh.stat().st_mode | stat.S_IEXEC)

        origin = root / "origin.git"
        origin.mkdir()
        git(origin, "init", "-q", "--bare", "-b", "main")

        self.repo = root / "repo"
        self.repo.mkdir()
        git(self.repo, "init", "-q", "-b", "main")
        git(self.repo, "config", "user.email", "t@example.com")
        git(self.repo, "config", "user.name", "T")
        git(self.repo, "remote", "add", "origin", str(origin))
        # Every path the tests plant is ignored; the veto reads ignored
        # entries, so the distinction under test is the regenerable list.
        (self.repo / ".gitignore").write_text(
            "Podfile.lock\n__pycache__/\nswiftpm/\nnotes.md\n"
        )
        git(self.repo, "add", ".gitignore")
        git(self.repo, "commit", "-qm", "base")
        git(self.repo, "push", "-q", "-u", "origin", "main")

        self.worktree = root / "wt"

    def verdict_for(self, ignored_path):
        """Classify a merged branch whose worktree holds only [ignored_path]."""
        git(self.repo, "branch", "-q", "feature")
        git(self.repo, "worktree", "add", "-q", str(self.worktree), "feature")
        planted = self.worktree / ignored_path
        planted.parent.mkdir(parents=True, exist_ok=True)
        planted.write_text("x\n")

        env = {
            **os.environ,
            "GH": str(self.fake_gh),
            "REPO": "divinevideo/divine-mobile",
            "BASE": "origin/main",
            "MERGED_HEAD_REF": "feature",
        }
        result = subprocess.run(
            ["bash", str(SCRIPT)],
            cwd=self.repo,
            capture_output=True,
            text=True,
            env=env,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        line = next(
            (l for l in result.stdout.splitlines() if " feature " in f" {l} "),
            None,
        )
        self.assertIsNotNone(line, result.stdout)
        return line.split()[0]

    def test_pod_lockfile_does_not_veto(self):
        self.assertEqual(
            self.verdict_for("mobile/ios/Podfile.lock"), "MERGED-PR"
        )

    def test_python_bytecode_does_not_veto(self):
        self.assertEqual(
            self.verdict_for("mobile/scripts/ci/__pycache__/x.cpython-314.pyc"),
            "MERGED-PR",
        )

    def test_xcode_swiftpm_state_does_not_veto(self):
        self.assertEqual(
            self.verdict_for(
                "mobile/macos/Runner.xcworkspace/xcshareddata/swiftpm/"
                "Package.resolved"
            ),
            "MERGED-PR",
        )

    def test_scratch_note_still_vetoes(self):
        self.assertEqual(self.verdict_for("notes.md"), "KEEP-DIRTY")


if __name__ == "__main__":
    unittest.main()
