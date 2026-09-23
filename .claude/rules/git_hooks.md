# Git Hooks

The repo has pre-commit and pre-push hooks that mirror CI checks locally. They live in `scripts/install-hooks.sh` and use `mise exec --` for the pinned Flutter version.

## Installation

```bash
cd mobile && mise run setup_hooks
```

The hooks are **generated copies**, not symlinks. Each one carries a hash of the `scripts/install-hooks.sh` that generated it; when the installer changes, the next commit or push re-installs the hooks and stops with `Hooks updated. Re-run your command.` Hooks installed before that hash existed carry none and never update themselves, so re-run the command above once. When a PR changes hook behaviour, still say so in its description.

Most recent change: the hooks carry the installer hash described above and re-install themselves when the installer changes (#9447). Re-run `mise run setup_hooks` once to get hooks that have it.

Before that: the pre-push untested-services check now invokes its Dart detector through the pinned SDK. Re-run `mise run setup_hooks` to pick up the change; a stale hook can fail with `dart: command not found` when a service or test file changes.

Earlier: the pre-push merge-conflict check moved into `scripts/check_branch_mergeable.sh`, so future fixes to it apply without re-running `mise run setup_hooks`. Re-run it once to pick up the delegation; a stale hook keeps reporting a shallow clone as a merge conflict (see below).

Earlier still: the pre-push hook skips changed files under `mobile/test/goldens/`. Without re-running `mise run setup_hooks`, a golden change is unpushable on macOS — the stale hook runs the image goldens against Ubuntu-rendered references and fails every time.

When a developer reports CI failures on format, analyze, or codegen that they didn't catch locally, FIRST check whether hooks are installed (`ls .git/hooks/pre-commit .git/hooks/pre-push`) before analyzing the failure itself. If hooks are missing, that is likely the root cause — suggest `mise run setup_hooks`. Do not skip this check.

## What the hooks check

**Both hooks**, before anything else and on every commit and push: the installer-hash staleness check described above.

**Pre-commit** (staged `.dart` files only):
- `dart format --output=none --set-exit-if-changed`
- build_runner codegen verification (if codegen inputs changed)

**Pre-push**:
- Merge conflict check against `origin/main` (`scripts/check_branch_mergeable.sh`)
- `flutter analyze lib test integration_test`
- build_runner codegen verification
- Runs tests for changed files

## The merge-conflict check cannot always answer

`git merge-tree --write-tree` reports three outcomes, not two: exit 0 clean,
exit 1 conflicts, and exit 128 a fatal error. The hook used to treat every
non-zero exit as conflicts, which mislabels the third case.

The third case is mostly **shallow clones**. With `origin/main` and the branch
grafted at different boundaries there is no common ancestor, so merge-tree
exits 128 with `refusing to merge unrelated histories`. That is not a conflict,
and the advice for one — merge or rebase — cannot fix it. Deepen instead:

```bash
git fetch --deepen=500 origin main
```

`git fetch --unshallow` also works but downloads the entire history, and on a
repo this size it can run for many minutes and die on a connection reset.
Watch its exit code rather than its output: piping it (`git fetch --unshallow |
tail`) reports the *pipe's* status, so a failed fetch looks like success.

An unanswerable check now warns and continues rather than blocking, since it is
not evidence of a conflict and GitHub reports mergeability on the pull request.
The surrounding hook already takes that stance for a failed `git fetch`.
Genuine conflicts still block.
