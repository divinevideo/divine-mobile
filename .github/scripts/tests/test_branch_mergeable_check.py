"""Behavioural tests for scripts/check_branch_mergeable.sh.

The script exists because `git merge-tree --write-tree` reports three outcomes
through its exit code — clean, conflicted, and could-not-compute — and the
pre-push hook used to collapse the last two into "Branch has merge conflicts
with main!". On a shallow clone that message is wrong and its advice (merge or
rebase) cannot help, so the third case is covered here explicitly.
"""

import os
import shutil
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

    def run_check(self, base="base", pushed_from=None, tip=None, env=None):
        return subprocess.run(
            ["bash", str(SCRIPT), base]
            + ([pushed_from] if pushed_from else [])
            + ([tip] if tip else []),
            cwd=self.repo,
            env=env,
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

    def make_conflict(self, name="shared.txt"):
        if name != "shared.txt":
            commit(self.repo, name, "base\n")
            git(self.repo, "branch", "-f", "base")
        git(self.repo, "checkout", "-q", "-b", "feature")
        commit(self.repo, name, "feature edit\n")
        baseline = git(self.repo, "rev-parse", "HEAD").stdout.strip()
        git(self.repo, "checkout", "-q", "base")
        commit(self.repo, name, "base edit\n")
        git(self.repo, "checkout", "-q", "feature")
        return baseline

    def test_unrelated_push_warns_and_passes(self):
        baseline = self.make_conflict()
        commit(self.repo, "unrelated.txt", "review fix\n")
        result = self.run_check(pushed_from=baseline)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("shared.txt", result.stdout)
        self.assertIn("before merging", result.stdout)

    def test_push_touching_conflict_blocks(self):
        baseline = self.make_conflict()
        commit(self.repo, "shared.txt", "another feature edit\n")
        self.assertEqual(self.run_check(pushed_from=baseline).returncode, 1)

    def test_missing_push_baseline_blocks(self):
        self.make_conflict()
        self.assertEqual(self.run_check(pushed_from="missing").returncode, 1)

    def test_rename_of_conflicted_path_blocks(self):
        baseline = self.make_conflict()
        git(self.repo, "mv", "shared.txt", "renamed.txt")
        git(self.repo, "commit", "-qm", "rename file")
        self.assertEqual(self.run_check(pushed_from=baseline).returncode, 1)

    def test_unusual_conflict_paths_block_only_when_the_push_touches_them(self):
        for name in ("space name.txt", "tab\tname.txt", "line\nname.txt", "quote\"name.txt"):
            with self.subTest(name=name):
                # Each subcase needs independent history.
                git(self.repo, "checkout", "-q", "main")
                if git(self.repo, "branch", "--list", "feature").stdout.strip():
                    git(self.repo, "branch", "-D", "feature")
                baseline = self.make_conflict(name)
                # Blocking alone cannot tell a match from a listing that came
                # back empty, which blocks too; the push that avoids the path
                # has to get through.
                commit(self.repo, "unrelated.txt", "review fix\n")
                allowed = self.run_check(pushed_from=baseline)
                self.assertEqual(allowed.returncode, 0, allowed.stdout + allowed.stderr)
                self.assertIn("outside the pushed changes", allowed.stdout)
                commit(self.repo, name, "changed again\n")
                self.assertEqual(self.run_check(pushed_from=baseline).returncode, 1)

    def test_explicit_tip_is_checked_instead_of_head(self):
        baseline = self.make_conflict()
        commit(self.repo, "unrelated.txt", "review fix\n")
        tip = git(self.repo, "rev-parse", "HEAD").stdout.strip()
        git(self.repo, "checkout", "-q", "main")
        result = self.run_check(pushed_from=baseline, tip=tip)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("before merging", result.stdout)

    def rename_on_base(self, branch_edits_first):
        # Base renames old.txt to new.txt and edits line 5, so a conflict over
        # that line is reported as new.txt while the branch still edits old.txt.
        lines = "".join(f"line {n}\n" for n in range(1, 11))
        commit(self.repo, "old.txt", lines)
        git(self.repo, "branch", "-f", "base")
        baseline = self.make_conflict()
        if branch_edits_first:
            commit(self.repo, "old.txt", lines.replace("line 5\n", "feature 5\n"))
            baseline = git(self.repo, "rev-parse", "HEAD").stdout.strip()
        git(self.repo, "checkout", "-q", "base")
        git(self.repo, "mv", "old.txt", "new.txt")
        commit(self.repo, "new.txt", lines.replace("line 5\n", "base 5\n"))
        git(self.repo, "checkout", "-q", "feature")
        commit(self.repo, "old.txt", lines.replace("line 5\n", "review 5\n"))
        return baseline

    def test_push_editing_a_conflict_the_base_renamed_blocks(self):
        baseline = self.rename_on_base(branch_edits_first=True)
        result = self.run_check(pushed_from=baseline)
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)

    def test_push_creating_a_conflict_under_a_name_the_base_renamed_blocks(self):
        # Before the push only shared.txt conflicts; the push adds new.txt.
        baseline = self.rename_on_base(branch_edits_first=False)
        result = self.run_check(pushed_from=baseline)
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)

    def test_merge_listing_failures_keep_conflicts_blocking(self):
        baseline = self.make_conflict()
        commit(self.repo, "unrelated.txt", "review fix\n")
        bindir = Path(self._tmp.name) / "bin"
        bindir.mkdir()
        real_git = shutil.which("git")
        wrapper = bindir / "git"
        # --no-messages fails every entry listing; --name-only only the names.
        for operation in ("--no-messages", "--name-only"):
            with self.subTest(operation=operation):
                wrapper.write_text(
                    "#!/bin/bash\n"
                    f'for arg in "$@"; do if [ "$arg" = "{operation}" ]; then exit 128; fi; done\n'
                    f'exec "{real_git}" "$@"\n'
                )
                wrapper.chmod(0o755)
                env = dict(os.environ, PATH=f"{bindir}:{os.environ['PATH']}")
                result = self.run_check(pushed_from=baseline, env=env)
                self.assertEqual(result.returncode, 1, result.stdout + result.stderr)

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


    def test_missing_base_ref_warns_but_does_not_report_a_conflict(self):
        # origin/main renamed, deleted, or never fetched: merge-tree exits 1
        # here ("not something we can merge"), the same code as a real
        # conflict, so an unchecked ref would be misreported as one.
        result = self.run_check(base="origin/does-not-exist-ref")

        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("does not resolve to a", result.stdout)
        self.assertIn("Continuing", result.stdout)
        self.assertNotIn("Branch has merge conflicts", result.stdout)


class PrePushBehaviourTest(unittest.TestCase):
    setUp = CheckBranchMergeableTest.setUp
    make_conflict = CheckBranchMergeableTest.make_conflict

    def prepare_hook(self):
        root = SCRIPT.parents[1]
        (self.repo / "mobile").mkdir(exist_ok=True)
        (self.repo / "scripts").mkdir(exist_ok=True)
        shutil.copyfile(SCRIPT, self.repo / "scripts/check_branch_mergeable.sh")
        git(self.repo, "update-ref", "refs/remotes/origin/main", "base")
        return root / "scripts/hooks/pre-push"

    def update(self, remote_sha, local_sha="HEAD", remote_ref="refs/heads/feature"):
        local_sha = git(self.repo, "rev-parse", local_sha).stdout.strip()
        return f"refs/heads/feature {local_sha} {remote_ref} {remote_sha}\n"

    def run_hook(self, updates):
        return subprocess.run(
            ["bash", str(self.prepare_hook()), "origin", "unused"],
            cwd=self.repo, input=updates, capture_output=True, text=True,
        )

    def test_remote_sha_baseline_allows_unrelated_fix_without_upstream(self):
        baseline = self.make_conflict()
        commit(self.repo, "unrelated.txt", "review fix\n")
        result = self.run_hook(self.update(baseline))
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("before merging", result.stdout)

    def test_multiple_updates_check_every_tip_even_when_head_is_main(self):
        baseline = self.make_conflict()
        commit(self.repo, "unrelated.txt", "review fix\n")
        allowed = self.update(baseline)
        commit(self.repo, "shared.txt", "conflicting fix\n")
        blocked = self.update(baseline, remote_ref="refs/heads/other")
        git(self.repo, "checkout", "-q", "main")
        result = self.run_hook(allowed + blocked)
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("before merging", result.stdout)
        self.assertIn("Resolve conflicts before pushing", result.stdout)

    def test_new_or_unavailable_remote_baseline_blocks(self):
        self.make_conflict()
        commit(self.repo, "unrelated.txt", "review fix\n")
        for baseline in ("0" * 40, "f" * 40):
            with self.subTest(baseline=baseline):
                self.assertEqual(self.run_hook(self.update(baseline)).returncode, 1)

    def test_deletions_and_tags_do_not_check_conflicted_head(self):
        baseline = self.make_conflict()
        updates = f"(delete) {'0' * 40} refs/heads/old {baseline}\n"
        updates += self.update("0" * 40, remote_ref="refs/tags/v1")
        result = self.run_hook(updates)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_empty_stdin_keeps_strict_check(self):
        self.make_conflict()
        self.assertEqual(self.run_hook("").returncode, 1)


class InstallHooksWiringTest(unittest.TestCase):
    def test_pre_push_delegates_to_the_script(self):
        source = (
            Path(__file__).resolve().parents[3] / "scripts" / "hooks" / "pre-push"
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
            Path(__file__).resolve().parents[3] / "scripts" / "hooks" / "pre-push"
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
