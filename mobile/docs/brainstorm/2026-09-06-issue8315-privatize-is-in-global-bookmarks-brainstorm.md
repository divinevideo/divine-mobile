# Brainstorm: privatising `isInGlobalBookmarks` (#8315)

Date: 2026-09-06

Seeded with `tasks/findings_8315.md` (5 investigation rounds, all load-bearing
hypotheses at 1.0, three verified by execution).

## Problem Statement

`BookmarksRepository.isInGlobalBookmarks(String itemId, String type)` is a
public member of the `bookmarks_repository` package with **zero references
anywhere** except the one line below it. Since #6969 extracted the class into
a package whose barrel re-exports the whole source file, it is now part of the
package's exported API contract without a single consumer. It is not dead code
— it is the implementation of `isVideoBookmarkedGlobally` — so the question is
one of visibility, not deletion.

## Constraints

- **Layered architecture** — `UI → BLoC → Repository → Client`. Tag-form
  selection is repository policy; it must not leak upward.
- **100 % coverage gate** — `bookmarks_repository.yaml` pins
  `min_coverage: 100` explicitly. Any change must keep every line reachable.
- **NIP-51 fidelity** — kind 10003 is a *shared* document. The repository must
  round-trip `a`/`t`/`r` items written by other clients, so the generic `type`
  dimension cannot be removed from the model.
- **One finding, one commit** — the repo's review rule; resist bundling.
- **The dartdoc is load-bearing** — it records #7136 (consulting only public
  tags made a privately-bookmarked video read as unsaved, then let a save
  republish it in the clear). It must survive any restructuring.

## Prior Art

- `tasks/findings_6969.md` and
  `docs/superpowers/specs/2026-08-29-bookmarks-repository-extraction-design.md`
  both record #8315 as a **deliberate deferral** from the extraction, with the
  correct framing ("needlessly public", explicitly *not* dead code).
- The class already contains four public-entry-point / `_private`-implementation
  pairs (`syncGlobalBookmarks`, `toggleVideoInGlobalBookmarks`,
  `addToGlobalBookmarks`, `removeFromGlobalBookmarks`).
- `#1847` migrated the repo off Mockito to mocktail. A generated Mockito mock
  (visible in `f0caff995`) once contained this method — which is very likely
  *why* it is public. That constraint no longer exists: zero `.mocks.dart`
  files remain in any source tree.

## Approaches Explored

### Approach A: Rename to `_isInGlobalBookmarks`

**Description:** Prefix the member with `_` and update its single call site
inside `isVideoBookmarkedGlobally`. Nothing else moves; the body, the dartdoc
and the tests are untouched.

**Layers affected:** Repository only (one file, two lines).

**Pros:**
- Matches the four existing public/`_private` pairs in the same class — reads
  as a fifth instance of an established shape, not a new idea.
- Keeps the general `(itemId, type)` form that #7135 will need as its second
  internal caller (matching `('a', coordinate)` alongside `('e', eventId)`).
- Preserves the #7136 dartdoc verbatim.
- **Verified empirically**: format clean, package analyze clean, 88/88 package
  tests pass, app analyze clean across `lib test integration_test`, 116/116
  consumer tests pass, and the generated `lcov.info` is *byte-identical*
  (293/293 = 100.00 %).

**Cons:**
- If Divine ever bookmarks articles/hashtags/URLs from the UI, the member has
  to come back. Reversal is a one-line, migration-free edit.

**Risks / Unknowns:** None remaining. All resolved in investigation.

**Complexity:** Low.

### Approach B: Inline the helper and delete the member

**Description:** Fold the two-line body directly into
`isVideoBookmarkedGlobally` and remove `isInGlobalBookmarks` entirely, leaving
one public method with no helper at all.

**Layers affected:** Repository only.

**Pros:**
- Removes a member rather than hiding one — the smallest possible API surface.
- No naming question at all.

**Cons:**
- **Throws away the abstraction #7135 needs.** Its fix must match a video by
  *both* `('e', eventId)` and `('a', coordinate)`; with the helper inlined,
  #7135 would have to re-extract it, making this change churn that gets
  reverted within one issue.
- The #7136 dartdoc explains the *public-and-private* matching rule, which is
  the helper's job. Merged into `isVideoBookmarkedGlobally`'s doc it becomes
  a paragraph about two different concerns.
- Loses the symmetry with the four sibling `_private` implementations.

**Risks / Unknowns:** Guaranteed rework once #7135 is picked up.

**Complexity:** Low, but negative value.

### Approach C: Narrow the barrel export instead of the member

**Description:** Attack the root cause the issue actually names — the barrel
re-exports `src/bookmarks_repository.dart` wholesale — by exporting a curated
surface with `show`/`hide` so that unused members simply are not exported.

**Layers affected:** Package barrel.

**Verdict: technically infeasible.** Dart's `export … show/hide` operates on
**top-level declaration** names, not on class members. The only thing the
barrel could hide here is the entire `BookmarksRepository` class. Nor can
`part`/`part of` help: privacy in Dart is library-scoped, and parts share the
library, so splitting the file changes nothing about member visibility.

Worth recording precisely *because* it is the intuitive fix — the only lever
Dart gives you at member granularity is the `_` prefix, which is Approach A.

**Complexity:** N/A — does not exist.

### Approach D: Close as won't-fix; keep it public for multi-type bookmarking

**Description:** NIP-51 kind 10003 admits four item types (`e`, `a`, `t`, `r`)
and the repository already parses all four. Argue the type-general predicate is
legitimate forward-looking API and leave it exported.

**Layers affected:** None.

**Pros:**
- Zero work; zero risk of reversal churn if Divine adds article or hashtag
  bookmarking.

**Cons:**
- **Fails YAGNI.** No app code constructs a `BookmarkItem` at all, so nothing
  chooses a `type` today, and nothing on the backlog does either.
- Misreads why the four types exist: the repository parses `a`/`t`/`r` so it
  can *faithfully round-trip other clients' items* in a shared NIP-51
  document — protocol fidelity, not a Divine product capability. That makes
  `type` repository-internal state, which is exactly what a private helper is
  for.
- Leaves a package API member that no consumer has ever called, which is the
  precise thing #6969's design doc flagged.

**Complexity:** Zero, but it declines a correct finding.

### Approach E: Privatise, and also add a repository accessor for saved videos

**Description:** Approach A plus fixing the one place tag-form knowledge leaked
upward — `profile_saved_videos_bloc.dart:173` does
`.where((item) => item.type == 'e')` — by moving that filter behind a new
repository accessor.

**Layers affected:** Repository + BLoC + tests.

**Pros:**
- Genuinely related: both are "the app should not know about tag forms".

**Cons:**
- **Scope creep on a one-line issue.** It adds a new public member to the very
  package whose surface this issue is trimming.
- That filter is already named in #7135's body as something its fix must
  change. Doing it here would collide with #7135 and pre-empt a decision that
  belongs with the coordinate-migration design.
- Breaks "one finding, one commit".

**Complexity:** Medium.

## Recommendation

**Approach A** — rename to `_isInGlobalBookmarks`, nothing else.

It is what the issue proposes, and every independent line of evidence converged
on it:

- **Convention** (Round 1): the class already has four public/`_private` pairs;
  this becomes the fifth.
- **History** (Round 3): the member is public because a *generated Mockito mock*
  needed it to be, and that mock has not existed since #1847. Public by
  accident, not by design.
- **Consumers** (Round 4): the app never constructs a `BookmarkItem`, so no
  caller can want a `(id, type)` predicate.
- **Protocol** (Round 5): the `type` dimension exists for NIP-51 round-trip
  fidelity — repository-internal by nature. This also kills B, because #7135
  needs exactly this helper's general form.
- **Measurement** (Round 2): the change is provably inert — identical coverage
  profile, all suites green.

B is rework, C does not exist in Dart, D declines a correct finding, and E is
scope creep into #7135's territory.

## Open Questions for /plan

- [x] Path and class name — the issue body is stale on both (#6969 moved and
      renamed them). Plan must use
      `mobile/packages/bookmarks_repository/lib/src/bookmarks_repository.dart`
      and `BookmarksRepository`.
- [x] Does codegen need re-running? No — mocktail only, zero `.mocks.dart`.
- [x] Does the 100 % coverage gate move? No — lcov byte-identical.
- [x] Commit/PR wording: note that the existing four `_private` twins are
      `_serialized` wrappers whereas this one narrows the type — same shape,
      different motive. One sentence in the PR body.

## Prerequisites

None. No design input, no protocol decision, no new package, no dependency.

## Deliberately out of scope (each with its home)

| Observation | Where it belongs |
|---|---|
| `profile_saved_videos_bloc.dart:173` filters `type == 'e'` and will drop `a`-tagged bookmarks | Already named in **#7135** |
| `.claude/rules/testing.md` lists only `divine_ui` as strict-coverage, but **30 of 58** package workflows effectively gate at 100 | Already tracked by **#6269** |
| `addToGlobalBookmarks` / `removeFromGlobalBookmarks` have no *app* caller | Not comparable — both are directly exercised by package tests; only `isInGlobalBookmarks` is at 0/0/0 |

## Next Step

`/plan 8315` — Approach A.
