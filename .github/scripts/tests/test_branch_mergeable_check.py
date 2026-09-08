"""Behavioural tests for scripts/check_branch_mergeable.sh.

The script exists because `git merge-tree --write-tree` reports three outcomes
through its exit code — clean, conflicted, and could-not-compute — and the
pre-push hook used to collapse the last two into "Branch has merge conflicts
with main!". On a shallow clone that message is wrong and its advice (merge or
rebase) cannot help, so the third case is covered here explicitly.
"""

import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPT = (
    Path(__file__).resolve().parents[3] / "scripts" / "check_branch_mergeable.sh"
)


def git(repo, *args):
    return subprocess.run(
        ["git", "-C", str(repo), *args],
        check=True,
        capture_output=True,
        text=True,
    )


def commit(repo, name, body):
    (repo / name).write_text(body)
    git(repo, "add", name)
    git(repo, "commit", "-m", f"add {name}")


class CheckBranchMergeableTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.repo = Path(self._tmp.name) / "repo"
        self.repo.mkdir()
        git(self.repo, "init", "-q", "-b", "main")
        git(self.repo, "config", "user.email", "t@example.com")
        git(self.repo, "config", "user.name", "T")
        commit(self.repo, "shared.txt", "base\n")
        git(self.repo, "branch", "base")
        self.addCleanup(self._tmp.cleanup)

    def run_check(self, base="base"):
        return subprocess.run(
            ["bash", str(SCRIPT), base],
            cwd=self.repo,
            capture_output=True,
            text=True,
        )

    def test_clean_merge_passes(self):
        git(self.repo, "checkout", "-q", "-b", "feature")
        commit(self.repo, "feature.txt", "new file, no overlap\n")

        result = self.run_check()

        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("No merge conflicts", result.stdout)

    def test_real_conflict_blocks(self):
        git(self.repo, "checkout", "-q", "-b", "feature")
        commit(self.repo, "shared.txt", "feature edit\n")
        git(self.repo, "checkout", "-q", "base")
        commit(self.repo, "shared.txt", "base edit\n")
        git(self.repo, "checkout", "-q", "feature")

        result = self.run_check()

        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("merge conflicts", result.stdout)
        self.assertIn("git rebase", result.stdout)

    def test_unrelated_histories_warn_but_do_not_report_a_conflict(self):
        # An orphan branch shares no ancestor with base, which is the shape a
        # shallow clone produces once the graft boundaries differ. merge-tree
        # exits 128 here rather than 0 or 1.
        git(self.repo, "checkout", "-q", "--orphan", "detached-history")
        git(self.repo, "rm", "-q", "-rf", ".")
        commit(self.repo, "other.txt", "unrelated root\n")

        result = self.run_check()

        combined = result.stdout + result.stderr
        self.assertEqual(result.returncode, 0, combined)
        self.assertIn("Could not check for merge conflicts", result.stdout)
        self.assertIn("Continuing", result.stdout)
        # The old hook's wording is what this script exists to avoid.
        self.assertNotIn("Branch has merge conflicts", result.stdout)

    def test_shallow_clone_is_named_as_the_likely_cause(self):
        commit(self.repo, "second.txt", "second\n")
        commit(self.repo, "third.txt", "third\n")
        shallow = Path(self._tmp.name) / "shallow"
        subprocess.run(
            ["git", "clone", "-q", "--depth", "1", f"file://{self.repo}", str(shallow)],
            check=True,
            capture_output=True,
        )
        git(shallow, "config", "user.email", "t@example.com")
        git(shallow, "config", "user.name", "T")
        git(shallow, "checkout", "-q", "--orphan", "detached-history")
        git(shallow, "rm", "-q", "-rf", ".")
        commit(shallow, "other.txt", "unrelated root\n")

        result = subprocess.run(
            ["bash", str(SCRIPT), "origin/main"],
            cwd=shallow,
            capture_output=True,
            text=True,
        )

        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("clone is shallow", result.stdout)
        self.assertIn("--deepen", result.stdout)


class InstallHooksWiringTest(unittest.TestCase):
    def test_pre_push_delegates_to_the_script(self):
        source = (
            Path(__file__).resolve().parents[3] / "scripts" / "install-hooks.sh"
        ).read_text()

        self.assertIn("check_branch_mergeable.sh", source)
        # Collapsing every non-zero exit into "conflicts" is the bug; make sure
        # the inline form does not come back.
        self.assertNotIn(
            'if ! git -C "$REPO_ROOT" merge-tree --write-tree "$BASE_BRANCH" HEAD',
            source,
        )

    def test_pre_push_delegation_does_not_gate_on_the_execute_bit(self):
        source = (
            Path(__file__).resolve().parents[3] / "scripts" / "install-hooks.sh"
        ).read_text()

        # The check is run through `bash "$MERGEABLE_CHECK"`, which needs the
        # file readable, not executable. Gating on `-x` skips the whole
        # merge-conflict check on any checkout that lost the +x bit (Windows, a
        # mode-stripped copy), so a genuine conflict stops blocking the push —
        # a safety gate failing open. Guard on presence instead.
        self.assertIn('bash "$MERGEABLE_CHECK"', source)
        self.assertNotIn('[ -x "$MERGEABLE_CHECK" ]', source)


if __name__ == "__main__":
    unittest.main()
