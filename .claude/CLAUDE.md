# divine-mobile assistant notes

Start with `/AGENTS.md` for repo workflow, worktree hygiene, verification, and commit expectations.

## Read before every change

**`rules/self_review_checklist.md`** is the single source of truth for
"what to double-check before planning / implementing / committing /
wrapping a PR." Every bullet there links to the detailed rule file.
Most review comments this repo sees map directly to an item in that
checklist — scan it mentally at each gate rather than waiting for a
reviewer to catch the same things.

## Standards Reference

Generic Flutter and Dart standards live in `.claude/rules/`:

- `rules/self_review_checklist.md`: consolidated pre-plan / pre-commit / pre-PR checklist
- `rules/agent_workflow.md`: worktree-from-`origin/main`, rebase-at-boundaries, no-stacked-PRs, no-tech-debt, failing-tests-are-your-fault
- `rules/pr_takeover.md`: check PR authorship *first*, takeover gates, answer every review item, never hand back before CI is green
- `rules/architecture.md`: layered flow, package boundaries, barrel files
- `rules/data_foundation.md`: storage/cache decision tree, `cache_sync` default, Drift migrations, Hive restrictions
- `rules/state_management.md`: BLoC-first UI, BlocProvider laziness, cross-route state persistence, Riverpod legacy rules, event transformers
- `rules/code_style.md`: naming, widget composition, Effective Dart guidance
- `rules/testing.md`: test structure, assertions, BLoC tests, goldens, strict-coverage packages, l10n delegates in widget tests
- `rules/routing.md`: `go_router` patterns
- `rules/ui_theming.md`: theme usage, Page/View split, spacing and typography, NestedScrollView edge-to-edge patterns
- `rules/error_handling.md`: exceptions and failure handling
- `rules/localization.md`: l10n-first UI, ARB workflow, `context.l10n` usage, l10n-pass migration procedure

## Project Rules

- Most app work happens in `mobile/`. Key entry points are `mobile/lib/main.dart` and `mobile/lib/router/app_router.dart`.
- Use current code plus focused docs as source of truth: `docs/STATE_MANAGEMENT.md`, `docs/BLOC_UI_MIGRATION_PRD.md`, `docs/NOSTR_EVENT_TYPES.md`, `mobile/docs/NOSTR_VIDEO_EVENTS.md`, `mobile/docs/FEED_LOAD_TRACES.md`, `mobile/docs/DESIGN_SYSTEM_COMPONENTS.md`, `mobile/docs/GOLDEN_TESTING_GUIDE.md`, `mobile/docs/LOCALIZATION_STYLE_GUIDE.md`, `mobile/docs/PEOPLE_SEARCH.md`, and `mobile/docs/SHOREBIRD_CODE_PUSH.md`.
- Older docs can drift. If documentation disagrees with code, trust the current implementation, targeted tests, and the newest focused doc.

## Architecture And State

- Prefer `UI -> BLoC/Cubit -> Repository -> Client` for new work.
- New UI state should use BLoC/Cubit. Riverpod is legacy and compatibility glue while the migration is ongoing.
- Keep migrations incremental, test-backed, and small enough to review.
- Prefer constructor injection and small widget classes over hidden dependencies and widget-building helper methods.

## UI And Product Constraints

- Divine ships dark and light appearances, dark by default; users choose in Settings → General → Appearance. Adaptive surfaces read `context.vineColors.<token>`; static `VineTheme.*` colors are for brand and fixed media chrome only.
- Use `VineTheme` and shared components from `mobile/packages/divine_ui` before adding one-off styling or raw `Colors.*`.
- Prefer full-screen flows over introducing new dialogs or bottom sheets unless the task explicitly asks for one or the existing UX already uses that pattern.
- For user-facing copy, follow `brand-guidelines/AGENT_QUICK_REFERENCE.md` and `brand-guidelines/TONE_OF_VOICE.md`.

## Nostr And Async Rules

- Never truncate Nostr IDs in code, logs, tests, analytics, or debug output.
- Verify protocol changes against current code and the Nostr docs in this repo. Some historical docs are stale on specific kinds and flows.
- Avoid introducing arbitrary `Future.delayed()` calls in app code; prefer explicit async coordination.

## Verification

- Run Flutter commands from `mobile/`.
- If dependencies change, run `flutter pub get`.
- If you touch generated-code inputs such as Riverpod, JSON, Mockito, or Drift, run `dart run build_runner build --delete-conflicting-outputs` and commit the generated files.
- Add or update tests with the change. For UI changes, update goldens when appropriate.
