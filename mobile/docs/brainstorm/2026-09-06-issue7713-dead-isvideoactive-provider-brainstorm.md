# Brainstorm: removing the dead `isVideoActiveProvider` API (#7713)

Date: 2026-09-06
Seeded by: `tasks/findings_7713.md` (investigation converged, all hypotheses 1.00)

## Problem Statement

`isVideoActiveProvider` — a `Provider.family<bool, String>` at
`mobile/lib/providers/active_video_provider.dart:210` — has zero production
consumers. It survives only through 11 assertions across two test files, all of
which are either never executed or tautological. The question is not *whether*
to remove it (the facts settle that) but **how far the change should reach**,
because one of the two blocking test files is also the declared scope of a
separate open issue, #7651.

## Constraints

- **No technical debt** (`.claude/rules/agent_workflow.md` §4): no deprecation
  shims, no TODO-deferred removal, no `skip:` to dodge a test edit.
- **A test must be able to fail** (`.claude/rules/testing.md`): tautological
  assertions are to be deleted, not preserved for coverage optics. The bar
  explicitly applies to pre-existing tests being edited, not just new ones.
- **Never stack PRs; combine only genuinely interdependent work**
  (`agent_workflow.md` §3).
- **Sweep all three roots when deleting a symbol** (`tasks/lessons.md:99`,
  from #4788 PR3): grep and `flutter analyze` must cover `lib`, `test` **and**
  `integration_test` — the last is a sibling, not a child.
- Riverpod here is *legacy compatibility glue*; the file is not a candidate for
  BLoC migration in this change.
- Two ratchet baselines touch these files:
  `layer_direction_imports.txt:6` (must be left alone — the file survives) and
  `skip_test_ceilings.txt:25` (only in play if the skips are removed).

## Prior Art

- **#7689** — the PR the issue was raised from. Notably does *not* contain the
  symbol; the provider was already dead before it.
- **#7651** (OPEN, assigned to NotThatKindOfDrLiz, unclaimed — no PR, no
  branch) — deletes the shadowing `lib/providers/app_lifecycle_provider.dart`
  and drops the two stale skips in `explore_active_video_test.dart`.
- **#7704** (OPEN, assigned to dcadenas) — argues the sole remaining consumer of
  the *parent* `activeVideoIdProvider` (upload backpressure) asks the wrong
  question. Confirmed non-overlapping: 0 family references in that file.
- House style for this shape of PR: **#8685** (`+0/-1`, delete an unused
  constant) and **#8493** (`+7/-128`, remove an unreachable `divine_ui`
  variant) — small, single-purpose, no deprecation period.

## Approaches Explored

### Approach A — Strict-scope deletion

**Description:** Delete the family (lines ~208–215) and the now-unused
`import 'package:flutter_riverpod/misc.dart';` (line 5). Delete the stale
comment at `video_feed_item.dart:17`, keeping the `app_providers.dart` import
that it mislabels. Delete the 11 tautological/never-run family assertions from
the two test files. Touch nothing else — the skips stay, no baseline moves.

**Layers affected:** State management (one Riverpod provider) + tests. No UI,
repository, protocol or behavior change.

**Pros:**
- Exactly the issue's stated scope; nothing to defend in review beyond it.
- Zero baseline regeneration → no ratchet argument to have.
- Leaves #7651 cleanly available for its assignee, untouched.
- Reviewable in one sitting; trivially revertible.

**Cons:**
- Leaves `explore_active_video_test.dart` in a half-tidied state: two tests
  still skipped, still importing the dead `app_lifecycle_provider.dart`. A
  reviewer may reasonably ask "you were right here — why not finish it?"
- The two skipped tests keep their `activeVideoIdProvider` assertions but
  continue to prove nothing, so the file's real coverage is unchanged.

**Risks / Unknowns:** Minor rebase friction if #7651 lands later on the same
file. Not a stack — just a textual conflict in one test file.

**Complexity:** Low.

### Approach B — Combined cleanup: absorb #7651

**Description:** Everything in A, plus #7651's declared scope: delete
`lib/providers/app_lifecycle_provider.dart`, re-point
`explore_active_video_test.dart` and `profile_me_redirect_integration_test.dart`
at the live `appForegroundProvider` (driven via
`container.read(appForegroundProvider.notifier).setForeground(...)`), drop the
two stale `skip: true` markers and their `TODO(any)` comments, and shrink
`skip_test_ceilings.txt` from 2 to 0 for that file.

**Layers affected:** Same, plus deletion of a second dead production file.

**Pros:**
- Converts two permanently-skipped tests into live coverage — verified green:
  `flutter test --run-skipped` gives 4/4 on today's main.
- Removes a *shadowing* dead symbol, which is strictly more dangerous than an
  unused one: #7651 documents a test that overrode the dead `StreamProvider`
  believing it gated playback and therefore asserted nothing.
- One ratchet win banked (`skip_test_ceilings.txt` 2 → 0).
- Both issues closed by one PR; no future conflict on the shared file.

**Cons:**
- **Takes work assigned to someone else.** #7651 is assigned to
  NotThatKindOfDrLiz under epic #4836, which is her workstream.
- Roughly triples the diff and mixes two rationales in one review.
- The two issues are *adjacent*, not *interdependent* — `agent_workflow.md` §3
  only mandates combining when work is genuinely dependent, which this is not.

**Risks / Unknowns:** `profile_me_redirect_integration_test.dart` is a second
file I have not analysed; re-pointing it is #7651's problem, not #7713's, and
would need its own verification.

**Complexity:** Medium.

### Approach C — Keep the family; give it a production consumer

**Description:** Read the deadness as a missing feature rather than dead code —
re-wire `video_feed_item.dart` (whose stale comment claims it once did) to
consume `isVideoActiveProvider` for its playback gating.

**Pros:** Would make the comment true and restore a per-video reactive signal.

**Cons / why rejected:**
- Directly contradicts the shipped architecture. `activeVideoIdProvider`
  returns `null` for **every** fullscreen video route — `home`, `profile`,
  `hashtag`, `likedVideos`, `pooledVideoFeed`, `videoDetail` — because those
  screens own playback. A consumer would read `false` for every video, always.
- `video_feed_item.dart`'s own header restricts it to "Non-feed detail use
  cases only (e.g. debug screens)".
- This is a behavior change dressed as a cleanup, and #7704 is already the
  right venue for the "what signal should playback-awareness read?" question.

**Complexity:** High. **Rejected.**

### Approach D — Delete the whole active-video mechanism

**Description:** Go further and remove `active_video_provider.dart` entirely,
plus the `uploadBackpressureActiveProvider` call site that reads it.

**Cons / why rejected:**
- `activeVideoIdProvider` still has a live production consumer
  (`upload_media_providers.dart:234`), so this is a **behavior change** to
  upload backpressure, not a refactor.
- That call site is the explicit subject of open issue #7704, assigned to
  someone else, which states the replacement signal is an open design question.
- Would require shrinking `layer_direction_imports.txt` and would collide with
  #7704's eventual fix.

**Complexity:** High. **Rejected — out of scope, and someone else's call.**

### Approach E — Deprecate rather than delete

**Description:** Annotate `@Deprecated('unused; remove after <date>')` and
remove in a follow-up.

**Cons / why rejected:** `agent_workflow.md` §4 forbids deferral, and
deprecation exists to protect *external* consumers. This is an app, not a
published package: there are none. It would add debt to remove debt.

**Complexity:** Low. **Rejected on the no-tech-debt rule.**

## Recommendation

**Approach A — strict-scope deletion**, with one narrow addition: leave a
one-line note in the PR description pointing at #7651 as the natural follow-up
on the same file, so the connection is not lost.

Why A over B, specifically:

1. **#7651 is already assigned.** Absorbing its scope here would quietly
   supersede an issue that remains open on another contributor's workstream.
   Keeping the scopes separate preserves clear ownership and issue state.
2. The two issues are adjacent, not interdependent. §3's "combine" rule is
   about work that *cannot* land separately; these can, in either order.
3. A keeps the review to a single claim — "this symbol is dead, here is the
   proof" — which is exactly the shape of the repo's comparable PRs (#8685,
   #8493).

The cost of A is real but small: the shared test file gets touched twice. That
is a rebase, not a stack.

## Open Questions for /plan

- [x] Which lines exactly? — family at 208–215 **and** the `misc.dart` import at
      line 5 (else `unused_import` fails analyze). Settled in findings H8.
- [x] Delete or rewrite the test assertions? — delete; they are tautologies or
      never run (findings H6).
- [x] Any baseline regeneration? — none for Approach A.
- [ ] Commit granularity: one commit per finding (production deletion / stale
      comment / test assertions) or a single atomic commit?
- [ ] Should the PR body carry the #7689 framing correction (findings H3)?

## Prerequisites

None. No design input, no protocol decision, no new package.

## Next Step

`/plan 7713` on Approach A.
