# Agent Workflow

The non-negotiables for branch hygiene, PR strategy, technical debt, and
test discipline. These rules apply to every change, every time. They
exist because the alternatives have already cost us — each one has a
specific failure history.

`AGENTS.md` is the entry-point summary; this file is the detailed
reference. When the two disagree, the stricter version wins.

---

## 1. Always start in a fresh worktree based on `origin/main`

**Every change starts in a NEW worktree branched from `origin/main`.**

```bash
git fetch origin
git worktree add .worktrees/<task-name> -b <branch-name> origin/main
cd .worktrees/<task-name>
```

Branch from `origin/main`, never from local `main`. Local `main` is often
stale — branching from it carries forward commits that have already been
superseded on the remote.

**Forbidden:**

- Editing on `main` (local or otherwise).
- Reusing an existing worktree for an unrelated task without first
  rebasing onto fresh `origin/main`.
- Branching from `main` without `git fetch origin` first.

### Shorebird release-patch exception

The only branch allowed to start somewhere other than `origin/main` is an
operational Shorebird patch line named
`shorebird-patch/<platform>/<release-version>`. It starts at the immutable
`patch_baseline_commit` recorded for that release, after the product fix and
regression test have merged normally to `main`. Only the reviewed fix is
cherry-picked onto the linear patch line. If the release already has an active
patch, extend its existing line so the next patch preserves every prior fix.

This is not a development shortcut: do not implement on the release line, open
an ordinary product PR from it, merge it back to `main`, add merge commits, or
mix cleanup with the backport. Keep the remote branch while the release remains
supported so later cumulative patches are reproducible. Never bypass the
deletion and non-fast-forward rules protecting `shorebird-patch/**`. The
complete runbook and approval requirements are in
`mobile/docs/SHOREBIRD_CODE_PUSH.md`.

One task per worktree. If the current worktree is dirty, commit, stash
intentionally, or discard intentionally before starting new work
elsewhere. Do not mix unrelated work into one worktree.

### Pruning after merge

`AGENTS.md` says to prune the worktree and branch once a branch merges or
is abandoned. Start with `scripts/prune-merged-branches.sh`, which is a
report-only classifier for likely stale local branches and worktrees. It
does not delete anything; prune the reported rows manually after reviewing
the output.

Do **not** improvise the classification. Three things that look like they
work do not:

- `git branch --merged main` reports 5 of 1185 branches here. This repo
  squash-merges, and a squash rewrites the commit, so a merged branch
  never becomes an ancestor of `main`. Ancestry is not the signal.
- "Empty diff against `main`" is symmetric — a branch that merged months
  ago still differs by everything that landed since. It reported 2445
  changed files for a long-merged branch.
- Matching branch names against an issue number deletes live work.
  `fix/7606-semantic-tokens` was destroyed exactly this way: unpushed
  local work on a parallel attempt at the same task.

The useful signals are GitHub reporting a same-repo merged PR to `main` with
that head ref, or a worktree tip that belongs to a merged PR but is not already
an ancestor of `main`. The latter identifies review worktrees whose scratch
branch name never matched the reviewed PR while excluding fresh worktrees
created at `origin/main`. Two vetoes apply on top: the local branch tip must
exist in GitHub's repository object database, and the worktree must have no
uncommitted, untracked, or non-regenerable ignored files. Ignored toolchain
output such as `build/`, `.dart_tool/`, and generated plugin registrants does
not veto because tracked inputs can recreate it. This keeps branch-name reuse,
unpushed commits, and local-only worktree files out of the prunable set.

### Optional: warn on concurrent sessions in one worktree

Two agent sessions in the same working tree is the failure this rule
prevents, and nothing in git or the permission system catches it — both
sessions are doing exactly what they were told. One session running an
authorized `git reset --hard` while another reasons from a pre-reset
snapshot is enough to lose, or wrongly "restore", a changeset.

`.claude/hooks/session-start-worktree-guard.sh` warns at session start
when another live session's launch root or active session root matches
the current git worktree. It is opt-in (registration snippet is in the
script header) and deliberately not registered in the team
`settings.json`, so anyone already running it at user scope is not warned
twice. It warns only — it never blocks a session.

The preferred signal combines the Claude process cwd with
`~/.claude/sessions/<pid>.json` (the active session root). The registry
cwd follows harness-level worktree changes but not `cd` inside an
ephemeral Bash tool call. On current macOS Claude the process cwd tracks
harness `chdir`, so the two roots usually match; the comparison still
covers lsof-unavailable sessions. Cwd is evidence of where a session
usually writes, never a boundary on where absolute paths can write, so a
launch-root match is never suppressed.

The session registry is undocumented Claude Code internal state. macOS
Claude records `procStart` as `ps -o lstart=` text; Linux Claude records
`/proc/<pid>/stat` starttime jiffies — the hook accepts both. If the
registry is absent, unreadable, incompatible, empty of live confirmed
records, or `jq` is unavailable, the hook falls back to
`$XDG_RUNTIME_DIR/cc-socks` and `/tmp/cc-socks*/<pid>.sock`. Anyone who
installed an older copy of the hook at user scope must copy the updated
repo version again to receive this detection.

### Build artifacts are purged from linked worktrees at session end

Abandoned worktrees are what actually fill the disk — a typical tree
carries ~8 GB of `build` and `.dart_tool`, and `flutter clean` leaves
roughly 3 GB of that behind: `mobile/` is a pub workspace and the tool
clears only `mobile/build` and `mobile/.dart_tool`, never recursing into
`mobile/packages/*`.

`.claude/hooks/session-end-purge-build-artifacts.sh` deletes those
directories outright when a session ends. Unlike the worktree guard
above, it **is** registered in the team `.claude/settings.json`, so it
runs for everyone — it is deliberately not opt-in, because
`settings.local.json` exists only in the main checkout, which is the one
place this hook refuses to touch.

What bounds it:

- **Linked worktrees only.** The main checkout keeps its build cache.
- **Terminal exits only** — `logout`, `prompt_input_exit`, and
  `bypass_permissions_disabled`. `/clear`, session resume, and the
  ambiguous `other` (which covers headless runs) do not purge.
- **divine-mobile checkouts only**, gated on `mobile/pubspec.yaml`.
- Nothing tracked is eligible; recovery is `cd mobile && flutter pub get`.

The cost to know about: **there is no mid-run interlock.** A second
session or a plain terminal building in the same worktree loses its
build cache when the first session exits. The concurrent-session guard
above warns at session *start* only (#7272); nothing watches for a build
in flight. If you are mid-build in a worktree someone else is also
sitting in, expect to re-run `flutter pub get`.

A purged worktree would otherwise make the analyzer report every package
as missing, so `.claude/hooks/post-edit-analyze.sh` skips analysis with
an explanatory message when `mobile/.dart_tool/package_config.json` is
gone, rather than blocking on ~1000 phantom errors.

---

## 2. Rebase when publishing, finalizing, or resolving conflicts

Before publishing a branch, before final handoff, and whenever GitHub
reports merge conflicts, fetch the latest `origin/main` and rebase your
branch onto it:

```bash
git fetch origin
git rebase origin/main
# resolve any conflicts, re-run tests, then:
git push --force-with-lease
```

Rebasing before those boundary moments surfaces conflicts and broken
assumptions while you still have full context — instead of after CI fails
on the PR or after a reviewer has already started reading.

During PR review, if GitHub reports no merge conflicts and your update
only addresses review feedback, do not rebase just to refresh history.
Push the review fix normally. The PR is squash-merged anyway, so a
history-refresh rebase adds force-push risk without meaningful review
value.

**Forbidden:**

- Publishing a new branch, making a final handoff push, or pushing a
  branch with GitHub-reported merge conflicts without first running
  `git fetch origin && git rebase origin/main`.
- `git push --force` without `--lease`. `--force-with-lease` is
  mandatory on rebased feature branches so a concurrent push from a
  different machine isn't silently overwritten.
- Merging `main` into a feature branch instead of rebasing — produces
  noisy "Merge branch 'main' into..." commits and a non-linear history.

The PR-review exception only applies when GitHub reports no merge
conflicts and the push is narrowly for review feedback. If either stops
being true, rebase onto fresh `origin/main`.

---

## 3. Never stack PRs — combine dependent features into one bigger PR

**Every PR targets `main`.** Never `gh pr create --base <other-branch>`.

Shorebird patch lines do not create a second product PR. Their commits are
mechanical backports of a fix already reviewed and merged through a `main` PR;
promotion receives a separate operational approval under the Shorebird
runbook. A backport that needs code adaptation goes back through `main` review
before it is placed on the patch line.

If features depend on each other, ship them as **one combined PR** on a
single branch. Use clearly delineated commits and a PR description with
separate sections for each feature. Reviewers handle one PR; the merge
story is one click; CI runs against the right base.

```bash
# One branch, both features, one PR
git checkout -b feature-a-and-b origin/main
# ... commit Feature A ...
# ... commit Feature B ...
git push --force-with-lease
gh pr create --base main
```

**Why stacking is forbidden:** every prior attempt has cost more than it
saved — cascading rebases when the parent changes, fragmented review
context, merge order becoming load-bearing, CI running against the
wrong base, and "fix on parent" forcing a re-review of the child. The
diff-cleanliness benefit isn't worth the operational cost.

**Forbidden:**

- `gh pr create --base <other-pr-branch>`. Always `--base main` (or
  omit, since `main` is the default).
- Branching a feature off another feature branch with the intent to PR
  it before the parent merges.
- Splitting truly interdependent work into multiple PRs.

If you catch yourself thinking *"B is based on A,"* that's the signal
to combine, not to stack.

If A and B are **truly independent**, each gets its own PR targeting
`main`, in any merge order — that's not stacking, that's parallel.

---

## 4. Do not accumulate technical debt

Fix it now, in the PR that introduces or touches it. No deferral, no
"we'll clean this up later," no follow-up issue as cover for shipping
half-finished work.

**Forbidden in any PR:**

- `// TODO`, `// FIXME`, `// XXX` comments deferring real work — the
  only TODO that is acceptable is the **transitional-code TODO** with a
  tracking issue link, as `code_style.md` documents (`// TODO(#1234):
  Remove after migration X ships`).
- Commented-out code blocks ("might need this later").
- `skip:` / `@Skip` / `xtest` on tests without a tracked issue and a
  hard removal date.
- `// ignore: <lint>` or `// ignore_for_file:` without an inline
  explanation of *why* the rule cannot be satisfied.
- Failing tests "we'll fix in a follow-up."
- Generated files left out of sync with their inputs.
- Dead code, unused imports, unused variables — fix them, don't
  suppress them.
- Half-finished refactors that leave both old and new code paths live.

**If a problem is bigger than the PR, scope-cut the PR — don't ship
partial work and a TODO.** Open a focused PR for just the fix you can
finish.

If you discover unrelated rot while working, leave it alone (don't
scope-creep) — but never make it worse.

Every merged PR should leave the codebase in a state you'd be happy to
inherit cold.

---

## 5. Failing tests are never acceptable, and always your fault

**`origin/main` is supposed to always pass.** So your default
assumption is that any failing test on a feature branch is caused by
something in that branch's diff — start there every time.

That default is a starting point, not an axiom. Required checks can
pass and still be **stale**: a PR tested days ago can merge into a
`main` that has since gained a semantically conflicting change — no
textual conflict, no re-run, green badge, broken `main`. When that
happens every open PR behind it inherits the failure. Assume the
failure is yours until you have positively proven otherwise, and prove
it the specific way described in "When the failure is not yours"
below. Never assert it from vibes.

When an agent says *"this test is flaky"* or *"this was already broken
on main"* or *"we'll fix it in a follow-up,"* it is almost always
wrong. The real explanations, in order of frequency:

1. The change broke the behavior the test asserts (most common).
2. The change broke a test setup invariant — mocks, fixtures, or
   generated files (Riverpod, Freezed, JSON, Mockito, Drift) out of
   sync with their inputs.
3. The change reveals a real race or order-dependence the test
   correctly catches.
4. A genuinely flaky test — extremely rare. If you find one, fix it;
   don't tolerate it.

*"It passed locally"* is not evidence the test is flaky. It's evidence
the local environment differs from CI. Investigate the difference.

### When a test fails on your branch

1. **Assume it's your fault.** Read the failure carefully. Trace from
   the assertion back through the production code your branch changed.
2. **Compare against `origin/main`.** Run the same test on
   `origin/main`. If it passes there, the cause is in your diff:
   `git diff origin/main -- <file>`.
3. **If you touched generated-code inputs**, run
   `dart run build_runner build --delete-conflicting-outputs` from
   `mobile/` and commit the regenerated files.
4. **If the test seems unrelated**, look harder. You probably changed a
   shared dependency, a constant, a default, or a public API consumed
   by that test.
5. **Fix the underlying cause.** Do not modify the test to make it
   pass unless the test was genuinely wrong (rare — be suspicious of
   yourself when you reach for this).

### When the failure is not yours

Rare, but real. The usual cause is a **stale-check merge**: PR A
removes an API, PR B adds a caller, both go green independently, and
whichever merges second lands without re-running against the other.
Nothing conflicts textually, so `main` breaks and every open PR behind
it inherits the failure.

`origin/main` broke exactly this way on 2026-08-07: #6731 removed
`diagnosticTag` / `eventKind` from `nostr_sdk` and merged with checks
that had last run 46 hours earlier, by which point #6721 and #6617 had
added callers.

Before you may claim this, prove it. Two checks, both required:

1. **The failing symbol is outside your diff.** Confirm the files and
   identifiers in the failure do not appear in
   `git diff origin/main... --stat`.
2. **`main` itself is red, at its own HEAD.** Not inferred — read it:

   ```bash
   gh run list --branch main --workflow "Mobile CI" --limit 5 \
     --json conclusion,headSha,createdAt
   gh run view <failing-run-id> --log-failed | grep -iE "error •"
   ```

   The errors on `main`'s run must be the *same* errors as on your
   branch. Different errors mean you have two problems, one of them
   yours.

Then find what unblocks it — usually an open PR already fixing it. Do
not trust PR prose search by itself: GitHub tokenizes terms and can
return noisy matches. Start from the code history, then verify any
candidate PR by reading its diff:

```bash
git log --oneline -S"<failing symbol>" origin/main
gh pr list --state open --search "<failing symbol>"   # hint only
```

Having proven it, **stop and report**. Do not patch around a broken
`main` inside an unrelated PR: you would be shipping someone else's
fix in a diff nobody expects it in, and it collides with the real fix
when that merges. Name the breaking commit, name the fixing PR, and
say the PR is blocked until it lands.

If `main` is green and your branch is red, it is yours. Go back to
step 1.

### Forbidden

- *"Flaky, will retry"* — find the race or order-dependence and fix it.
- `skip:` / `@Skip` / `xtest` to silence a failing test.
- *"Already broken on main"* without running both proof checks above
  and naming the breaking commit.
- Patching an unrelated broken-`main` failure inside your own PR
  instead of reporting it.
- Pushing with red local tests "to see what CI says."
- Claiming "tests pass" without having actually run them — see
  `superpowers:verification-before-completion`.

### Before every push

- Run the affected test suites locally.
- Run `flutter analyze lib test integration_test`.
- If this push requires a rebase under the workflow rules above, verify
  the rebase onto `origin/main` did not break anything.
- If this is a PR-review fix without a rebase, verify GitHub reports no
  merge conflicts before relying on that exception.
- If anything is red, do not push. Fix it.

### After every push

Local green does not end the task — CI green does.

- `gh pr checks <number> --watch`, then read the result.
- Red → fix and push again, until green.
- Only after checks have *finished* do you post the handback comment
  or report the task complete. See `pr_takeover.md` §3.
