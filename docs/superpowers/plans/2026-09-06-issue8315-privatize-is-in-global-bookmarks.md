# Plan: privatise `isInGlobalBookmarks` (#8315)

Date: 2026-09-06
Type: **Task** (GitHub issue type: Task)
Complexity: **Low** — single layer, one file, two lines
Sources: `tasks/findings_8315.md`,
`mobile/docs/brainstorm/2026-09-06-issue8315-privatize-is-in-global-bookmarks-brainstorm.md`

## Hypothesis this fixes

**H1 — `isInGlobalBookmarks` is public with zero references outside its own
class. Confidence 1.0** (grep-verified repo-wide across `*.dart`, `*.md`,
`*.yaml`, `*.yml`; plus a per-member consumer audit in which it is the only
member at 0 app-lib / 0 app-test / 0 package-test).

Supporting hypotheses, all at 1.0:

| | Claim | How verified |
|---|---|---|
| H2 | Rename is behaviour-preserving and breaks no build or test | Executed: analyze + 88/88 pkg + 116/116 app tests |
| H3 | The package's 100 % coverage gate is unaffected | Executed: `lcov.info` byte-identical, 293/293 |
| H4 | #7135 does not need the two-arg form public | Consumer + protocol analysis (Rounds 4-5) |
| H5 | `_`-prefixed twin is the house convention here | 4 existing pairs in the same class |

Chosen direction: **Approach A** from the brainstorm (rename). B (inline) is
rework #7135 would undo, C (narrow the barrel) is infeasible in Dart at member
granularity, D (won't-fix) declines a correct finding, E (also fix the saved-
videos filter) is scope creep into #7135.

## Issue summary

Since #6969 extracted this class into a package whose barrel re-exports the
whole source file, every public member is package API. `isInGlobalBookmarks` is
in that contract with no consumer — reachable only from the line directly below
it. It is not dead code and must not be deleted; it is the general form that
`isVideoBookmarkedGlobally` specialises to `type: 'e'`, and the form #7135 will
need a second caller for.

**The issue body is stale on two points** (it predates #6969 by ~3 hours):
- Path is now `mobile/packages/bookmarks_repository/lib/src/bookmarks_repository.dart`,
  not `mobile/lib/services/bookmark_service.dart`.
- Class is now `BookmarksRepository`, not `BookmarkService`.
- Lines are `:918` / `:925`, not `:898` / `:905`.

## Affected layers and files

**Layer: Repository only.** No Client, BLoC, UI, router, l10n, theme, codegen,
ARB or golden involvement.

| File | Action | Change |
|---|---|---|
| `mobile/packages/bookmarks_repository/lib/src/bookmarks_repository.dart` | Modify | `:918` declaration → `_isInGlobalBookmarks`; `:925` call site updated |

**No other file changes.** Explicitly *not* touched:

- `lib/bookmarks_repository.dart` (barrel) — nothing to change; Dart cannot
  hide a class member from an export.
- Any test file — no test references the symbol.
- Any `.mocks.dart` — none exist; all three `BookmarksRepository` mocks are
  mocktail (`extends Mock implements …`), which is runtime `noSuchMethod`.
- `mobile/scripts/baseline/*` — no ratchet counts this shape.

## Implementation steps

1. **Repository: rename the member and its one call site.**
   - File: `mobile/packages/bookmarks_repository/lib/src/bookmarks_repository.dart`
   - `:918` `bool isInGlobalBookmarks(` → `bool _isInGlobalBookmarks(`
   - `:925` `return isInGlobalBookmarks(videoEventId, 'e');`
        → `return _isInGlobalBookmarks(videoEventId, 'e');`
   - **Keep the dartdoc verbatim.** It records #7136 — consulting only the
     public tags made a privately-bookmarked video read as unsaved and then let
     a save republish it in the clear. That rationale is why the method reads
     both `_globalBookmarks` and `_privateBookmarks`, and it stays true when
     the member is private.
   - Why: the class already pairs a public entry point with a `_`-prefixed
     implementation four times (`syncGlobalBookmarks`,
     `toggleVideoInGlobalBookmarks`, `addToGlobalBookmarks`,
     `removeFromGlobalBookmarks`). This is the fifth.

That is the whole change. There is no step 2.

## Testing strategy

**No new test.** This is deliberate and defensible under
`.claude/rules/testing.md`'s "a test must be able to fail" bar: privacy is a
compile-time property, so a test asserting it could only assert the compiler's
own behaviour. The change's correctness is proven by the *existing* suites
continuing to pass with an unchanged coverage profile.

| Layer | Command | Expected (already measured on `origin/main` + this diff) |
|---|---|---|
| Format | `dart format --set-exit-if-changed lib/src/bookmarks_repository.dart` | clean, 0 changed |
| Package analyze | `flutter analyze` in `mobile/packages/bookmarks_repository` | No issues found |
| Package tests | `flutter test --coverage` in that package | **88/88 pass**, `293/293 = 100.00 %` |
| Coverage gate | `diff` new `lcov.info` against baseline | **byte-identical** |
| App analyze | `flutter analyze lib test integration_test` from `mobile/` | No issues found |
| Consumer tests | `flutter test test/blocs/share_sheet/share_sheet_bloc_test.dart test/widgets/share_video_menu_comprehensive_test.dart test/blocs/profile_saved_videos/profile_saved_videos_bloc_test.dart` | **116/116 pass** |

The five package tests that call `isVideoBookmarkedGlobally`
(`bookmarks_repository_test.dart:933,1469,1556,1614,1651`) are what keep the
renamed body covered — including `:1469`/`:1556`/`:1651`, which exercise the
private-items path the #7136 dartdoc describes. They are the regression net.

## Risks and considerations

| Risk | Severity | Mitigation |
|---|---|---|
| An external caller exists that grep missed | **None** | Grep covered `*.dart`/`*.md`/`*.yaml`/`*.yml` repo-wide; app analyze over `lib test integration_test` is clean with the rename applied — a missed caller would be a compile error |
| Coverage drops below the 100 % gate | **None** | `lcov.info` measured byte-identical |
| Mock regeneration needed | **None** | Zero `.mocks.dart` in any source tree; mocktail is runtime |
| #7135 later needs the two-arg form publicly | **Low** | Its dual `('e', id)` / `('a', coord)` read belongs inside `isVideoBookmarkedGlobally`; keeping `type` private is what stops tag-form policy leaking into BLoCs |
| Divine later bookmarks articles/hashtags/URLs from the UI | **Low, reversible** | NIP-51 admits `a`/`t`/`r` and the repo parses all four — but only for round-trip fidelity to a shared document. Nothing in `mobile/lib` constructs a `BookmarkItem`. Re-widening is a one-line, migration-free edit |
| CI job not triggered | **None** | `bookmarks_repository.yaml` triggers on `mobile/packages/bookmarks_repository/**` — this path matches |

## Delivery

- **Worktree**: `.worktrees/8315-privatize-isinglobalbookmarks`
  **Branch**: `refactor/8315-privatize-is-in-global-bookmarks`, off `origin/main`
  (`d061eccaf`). Already created and clean; verification was run there and reverted.
- **Separate commits** for the repository change, its supporting documentation,
  and any review cleanup; one finding overall.
- **PR title** (Conventional Commit, effect in plain language rather than the
  symbol — per `AGENTS.md`):
  `refactor(bookmarks): stop exporting a bookmark-lookup helper nothing outside the package calls`
- **PR body**: lead with the problem (a package API member with no consumer
  since the #6969 extraction), then why privatising is right rather than
  deleting (it is the implementation of the method that *is* used, and the
  general form #7135 needs), then what it deliberately leaves alone
  (the saved-videos `type == 'e'` filter → #7135; the stale strict-coverage
  list in `.claude/rules/testing.md` → already tracked by #6269), then
  verification.
  Include `Closes #8315` outside backticks.
  Add one sentence noting the four existing `_private` twins are `_serialized`
  wrappers whereas this one narrows the type — same shape, different motive.
- **Reviewers**: `divinevideo/reviewers` once checks are green.
- **Watch checks to completion** (`gh pr checks <n> --watch`) before handback.

## Out of scope, with homes

| Observation | Home |
|---|---|
| `profile_saved_videos_bloc.dart:173` filters `type == 'e'`, so `a`-tagged bookmarks would silently drop from Saved | Already named in **#7135** |
| `.claude/rules/testing.md` names only `divine_ui` as strict-coverage, but **30 of 58** package workflows effectively gate at 100 (3 explicit, 27 relying on the VeryGood default) | Already tracked by **#6269** |
