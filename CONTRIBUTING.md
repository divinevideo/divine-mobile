# Contributing To Divine

Status: Current
Validated against: `AGENTS.md`, `.claude/rules/agent_workflow.md`,
`.claude/rules/code_style.md`, current workspace packages, and active mobile
scripts on 2026-05-13.

This guide is the source of truth for outside contributors.

## Current Contribution Status

We appreciate the time and care people put into this project. Right now,
however, we are **not accepting outside implementation PRs by default** while
we tighten our contributor guidance and clarify product ownership boundaries.

What this means in practice:

- A well-intentioned PR may still be closed if it lands in an area where
  product, UX, architecture, or sequencing is not explicitly approved.
- Large feature branches are especially likely to be closed even if they
  contain real effort and test coverage, because the review and cleanup cost is
  too high for the current team size.
- We are working toward clearer issue labels and contribution lanes. Until that
  is in place, assume implementation work needs maintainer buy-in **before**
  code is written.

If you want to help right now, the safest path is to start with issues that a
maintainer has explicitly marked as ready for outside contribution.

## Good First Contributions

These are the kinds of changes most likely to be reviewable and mergeable:

- Small bug fixes with a clear reproduction and narrow diff.
- Targeted tests that improve coverage around existing behavior.
- Documentation fixes that align docs to current code.
- Small refactors requested by a maintainer.
- Clearly scoped UI polish where the intended behavior and visual direction are
  already settled.

These are **not** good first contributions unless a maintainer has explicitly
asked for them:

- New features or feature revivals from old issues, designs, or dormant PRs.
- Broad UX or information architecture changes.
- Multi-screen flows or changes that touch many packages at once.
- New repositories, storage models, caching layers, or cross-cutting state
  management changes.
- “I implemented the whole issue” PRs opened without prior maintainer
  confirmation.

## Before You Start

Before writing code, make sure the answer to all of these is yes:

1. A maintainer has indicated the work is wanted **now**, not just eventually.
2. The intended product behavior and design direction are already clear.
3. The change can be delivered as a small, focused PR.
4. You know which package or layer owns the change.
5. You are prepared to run the relevant tests and code generation locally.

If any of those are unclear, start a discussion first instead of opening a PR.

## Templates And Agent Compliance

We enforce our repository templates and agent instructions.

Before starting work:

- Read [AGENTS.md](AGENTS.md).
- Read the repo rules under `.claude/rules/`, especially
  `.claude/rules/agent_workflow.md` and `.claude/rules/code_style.md`.
- If you use Codex, Claude, ChatGPT, Cursor, Copilot, or any other coding
  agent, make sure that agent has reviewed those files before it writes code,
  opens an issue, or opens a PR.

When opening issues and PRs:

- Use the appropriate GitHub template and fill it out completely.
- Follow the issue title prefixes from the templates, such as `fix:` for bugs
  and `feat:` for feature requests.
- Use the PR template in `.github/pull_request_template.md`.
- Use a semantic PR title that matches our checks. The repo enforces this via
  `.github/workflows/semantic_pr.yaml`.

Submissions that ignore the templates, semantic formatting, or repo
instructions may be closed or sent back for correction before review starts.

## Technical Debt Standard

In the age of agentic programming, we expect a higher bar, not a lower one.
We enforce a standard of:

- No new technical debt in submitted PRs.
- Elimination of as much relevant prior technical debt as is reasonably
  possible within the scope of the change.

That means:

- Do not add TODOs, compatibility shims, temporary hacks, commented-out code,
  partial migrations, or “we’ll fix this later” scaffolding unless a maintainer
  has explicitly approved a transitional step.
- Do not leave generated files stale, tests red, architecture half-migrated, or
  known cleanup deferred just to get the branch over the line.
- If your change touches an area with existing debt, clean up the parts you are
  already in unless doing so would turn the PR into a different project.
- If a proposed fix would require introducing new mess to ship now and repair
  later, stop and rescope the change instead.
- Issues related to eliminating prior technical debt and preventing future
  technical debt already exist in our issue backlog. Do not use a PR to create
  vague new cleanup debt. If relevant backlog tracking already exists, use it
  and address that debt directly in the work.

Using an agent is not an excuse to produce larger diffs with lower standards.
If anything, agent assistance means we expect contributors to arrive with
cleaner structure, better test coverage, stronger adherence to repo rules, and
less leftover cleanup for maintainers.

## Why PRs Get Closed

We want to be direct about this because it saves everyone time.

A PR may be closed without merge if any of the following are true:

- The work was started without maintainer alignment.
- The feature direction is still unsettled across product, design, or
  architecture.
- The branch is too large or spans too many concerns to review safely.
- The implementation solves the wrong problem, even if the code quality is
  solid.
- The branch mixes feature work with unrelated cleanup, dependency churn, or
  architecture experiments.
- The branch introduces new technical debt or avoids cleanup that should have
  been handled in the touched area.
- The change creates more review, rework, or coordination cost than the team
  can absorb right now.

Closure in those cases is usually a sequencing decision, not a judgment on
effort or intent.

## Repository Setup

Prerequisites:

- Flutter `^3.44.0`
- Dart `^3.12.0`
- Xcode for iOS work
- Android Studio and Android SDK for Android work
- CocoaPods for Apple platform dependencies

Initial setup:

```bash
git clone https://github.com/divinevideo/divine-mobile.git
cd divine-mobile
cd mobile
flutter pub get
flutter doctor
```

Building or debugging the **Android** app needs a JDK and an Android SDK on top
of that — see [mobile/docs/ANDROID_LOCAL_SETUP.md](mobile/docs/ANDROID_LOCAL_SETUP.md).
Flutter tests, analysis and the web build do not.

## Worktree-First Workflow

Start every task from a fresh branch created from `origin/main`:

```bash
git fetch origin
git worktree add .worktrees/<task-name> -b <branch-name> origin/main
```

Rules:

- Never start new work in a dirty checkout.
- Keep one task per worktree.
- Rebase onto fresh `origin/main` before publishing or final handoff, and
  whenever GitHub reports merge conflicts. During PR review with no
  reported conflicts, push review fixes without a history-refresh rebase.
- Never merge `main` into a feature branch. Always rebase.
- Never stack PRs. Every PR targets `main`.

## Where To Work

- Run Flutter commands from `mobile/`.
- Put reusable logic in the owning package under `mobile/packages/`.
- Trust current implementation and focused tests over stale historical docs.
- Start with:
  - [docs/STATE_MANAGEMENT.md](docs/STATE_MANAGEMENT.md)
  - [docs/BLOC_UI_MIGRATION_PRD.md](docs/BLOC_UI_MIGRATION_PRD.md)
  - [docs/NOSTR_EVENT_TYPES.md](docs/NOSTR_EVENT_TYPES.md)
  - [mobile/docs/NOSTR_VIDEO_EVENTS.md](mobile/docs/NOSTR_VIDEO_EVENTS.md)
  - [mobile/docs/DESIGN_SYSTEM_COMPONENTS.md](mobile/docs/DESIGN_SYSTEM_COMPONENTS.md)
  - [mobile/docs/GOLDEN_TESTING_GUIDE.md](mobile/docs/GOLDEN_TESTING_GUIDE.md)
  - [mobile/docs/ERROR_HANDLING.md](mobile/docs/ERROR_HANDLING.md) (per-layer failure contract, Reportable matrix)
  - [mobile/docs/LOCALIZATION_STYLE_GUIDE.md](mobile/docs/LOCALIZATION_STYLE_GUIDE.md) (per-locale register and dialect decisions, translation review tiers)

## Architecture Expectations

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the layer map, the allowed
dependency direction, the repository-owns-fallback rule, and how CI enforces the
boundaries.

- Prefer `UI -> BLoC/Cubit -> Repository -> Client` for new work.
- Repositories and blocs should not depend on Flutter UI types.
- Prefer constructor injection over hidden singletons.
- New UI state should use BLoC/Cubit.
- Riverpod is legacy compatibility glue during migration, not the preferred
  direction for new feature state.
- Prefer small widget classes over helper methods that return `Widget`.
- Reuse shared `divine_ui` components and `VineTheme` instead of one-off UI.

## Product And Design Boundaries

Do not assume that an old issue, Figma, comment thread, or dormant branch is
enough authorization to implement a feature. For contribution purposes, the
source of truth is current maintainer direction.

If the change affects any of the following, get explicit maintainer confirmation
first:

- Navigation model or feed structure
- Saved/followed content behavior
- Search behavior or discovery surfaces
- New storage or persistence semantics
- New package boundaries
- Overlay behavior or interaction models
- Any UI that needs design fidelity rather than engineering approximation

If design direction is unresolved, stop and ask first. Do not fill in the
blanks yourself and hope review will sort it out later.

## Day-To-Day Commands

```bash
cd mobile
flutter pub get
flutter analyze
flutter test test/path/to/foo_test.dart     # one file or directory
mise run test           # non-golden suite, matching CI's Tests job
```

Use `flutter test test/path/to/foo_test.dart` while iterating on a specific
file, and `mise run test` for the full suite. `mise run test` wraps `very_good test
--optimization`, matching Mobile CI's sharded `Tests` job: it bundles untagged,
non-golden test files into a single isolate instead of compiling and spinning
one per file. Golden tests run separately through the `Goldens` job and
`mobile/scripts/golden.sh`.
Measured on an identical 31-file / 277-test subset, same machine, back to
back: **60s for `flutter test`, 17s for the optimized run**.

Useful app entry paths from `mobile/`:

- `./run_dev.sh ios debug`
- `./run_dev.sh android debug`
- `./run_dev.sh macos debug`
- `mise run local_android` - Android emulator against the default local stack
- `flutter run -d macos`
- `./build_ios.sh release`
- `./build_android.sh release`

macOS debug builds are ad-hoc code signed so the native camera and
microphone prompts work without Apple Developer team setup. See
[mobile/docs/MACOS_DEBUG_SIGNING.md](mobile/docs/MACOS_DEBUG_SIGNING.md)
if a fresh checkout fails to sign, or if macOS keeps asking for your
login keychain password on every debug launch.

If generated code changes:

```bash
cd mobile
dart run build_runner build --delete-conflicting-outputs
```

Commit the relevant generated outputs with the source change.

## Testing Expectations

Start with the smallest relevant verification, then broaden when the diff is
cross-cutting.

Core checks:

```bash
cd mobile
flutter analyze
flutter test test/path/to/foo_test.dart     # while iterating
mise run test           # before pushing — CI's non-golden Tests job locally
```

Additional expectations:

- Run `mobile/scripts/golden.sh verify` for visual changes. Golden
  references are regenerated on the CI runner, not locally — see
  `mobile/docs/GOLDEN_TESTING_GUIDE.md`.
- If you touch `mobile/packages/videos_repository`, run
  `flutter test --coverage` from that package.
- Add or update tests next to the changed feature or package.
- If you touch generated-code inputs, regenerate and commit the outputs.
- Do not push red tests “to see what CI says.”

## Scope Discipline

Keep PRs focused and reviewable.

Do:

- Change only what is required for the agreed task.
- Stage only task-related files.
- Keep dependency changes justified and narrow.
- Split truly independent work into separate PRs targeting `main`.

Do not:

- Mix feature work with unrelated cleanup or version bumps.
- Add speculative architecture while solving a smaller problem.
- Land partial work with TODOs instead of finishing or scoping down.
- Introduce new technical debt with the expectation that maintainers will clean
  it up later.
- Leave generated files stale.
- Leave the branch dirty at handoff.

## Pull Requests

Requirements:

- Use a Conventional Commit PR title such as
  `feat(settings): split settings into sub-screens`.
- Make sure the PR title is semantic when the PR is opened. Editing the title
  later does not reliably retrigger all checks.
- Target `main`.
- Fill out `.github/pull_request_template.md` completely, including the
  description, related issue, out-of-scope notes, verification details, and
  type-of-change checklist.
- End with a clean `git status`.
- Rebase on `origin/main` before publishing or final handoff, and whenever
  GitHub reports merge conflicts; skip the rebase for review-only pushes
  when GitHub reports no conflicts.
- Each PR should address a single GitHub issue whenever possible. Assign that
  issue to yourself before starting work when you have permission to do so. If
  you do not, ask a maintainer to assign or confirm ownership before you begin
  and keep that ownership clear throughout the review cycle. This prevents
  duplicate work and makes it clear who is driving the fix.

Before opening a PR, ask yourself:

1. Is this branch small enough for a maintainer to review without
   reconstructing product intent?
2. Does it stay inside a clearly approved scope?
3. Did I avoid mixing in unrelated files or concerns?
4. Did I run the relevant tests locally?

If the answer to any of those is no, the PR is not ready yet.

## Documentation Rules

- Current docs belong in `docs/` or `mobile/docs/`.
- Historical plans and completed investigations should be preserved but clearly
  marked historical.
- Before adding a new doc, check
  [docs/DOCUMENTATION_GUIDELINES.md](docs/DOCUMENTATION_GUIDELINES.md).
