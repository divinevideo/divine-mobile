# Brainstorm: locking ratchet shrinks that landed without a baseline regen

Date: 2026-09-06
Issue: #8323 (spun out of #6327 / #8320)
Findings: `tasks/findings_8323.md` (local-only)

## Problem Statement

Several per-file numeric ratchets record ceilings **above** the current count,
because a PR reduced the count without regenerating the baseline. The guards fail
only on growth, so nothing catches it: the win is left unlocked and the file can
silently regrow to its stale ceiling. #8323 names 6 such rows; a full sweep found
**8, across 4 baselines**.

## Constraints

- `mobile/scripts/lib/numeric_ratchet.sh` deliberately allows a decrease as slack
  ("low friction"); only NEW / GROWTH / STALE / BYPASS fail.
- The engine already implements the strict mode as an opt-in guard variable,
  `REQUIRE_BASELINE_UPDATE_ON_DECREASE`, used by exactly two scripts (#8635).
- `check_raw_icons_ceiling.sh` is the **only** numeric ceiling that does not
  source the shared engine — it carries a 115-line inline copy, so it cannot take
  the flag as-is.
- `AGENTS.md`: `check_service_god_file_ceiling.sh` has **no sanctioned raise
  path**; locking a lower ceiling there is irreversible by policy.
- Baseline regeneration must be reviewed, never blind: a "shrink" could in
  principle be a detector regression rather than a real migration.
- CI ratchets run in the `generated-files` job of `mobile_ci.yaml`, not the
  pre-push hook.

## Prior Art

- **#8635** (merged 2026-09-06) introduced `REQUIRE_BASELINE_UPDATE_ON_DECREASE`
  and applied it to both `future_delayed` guards, with the rationale "partial
  cleanup could not be locked in … a removed wait cannot return". It could adopt
  strict mode freely because it bootstrapped *fresh* baseline filenames.
- **#8320** hand-scoped its baseline diff to its own file rather than claiming
  other branches' wins — correct discipline, and precisely why leftovers accrue.
- **`📏 Report oversized files (advisory)`** in `mobile_ci.yaml` is an existing
  non-blocking pattern: always exit 0, surface a `::warning` annotation.
- `test/tools/numeric_ratchet_test.dart` and
  `test/tools/design_system_ceiling_detectors_test.dart` already pin engine and
  detector behaviour.

## Approaches Explored

### Approach A: Mechanical only

**Description:** Regenerate the 4 drifted baselines and commit. Exactly the
issue's `## Fix` block plus the 2 rows it did not know about.

**Layers affected:** none (tooling baselines only).

**Pros:** ~8 changed lines; zero friction; closes the issue as filed.

**Cons:** Demonstrably recurs — this drift re-accumulated in the ~4 weeks after
the previous regen, from ~6 unrelated PRs.

**Complexity:** Low.

### Approach B: Mechanical + blocking decrease-detection *(chosen)*

**Description:** Regenerate all 4 baselines, port `check_raw_icons_ceiling.sh`
onto `lib/numeric_ratchet.sh`, then set `REQUIRE_BASELINE_UPDATE_ON_DECREASE=1`
on the five design-system guards. A future incidental shrink fails CI with a
message naming the rows and the exact command to fix it.

**Layers affected:** tooling + CI only.

**Pros:** Follows the week-old precedent for identical reasoning; machinery
already exists and is tested; the port deletes ~115 lines of duplicated engine
and incidentally fixes the fork's `# reason`-dropping bug; friction lands only on
PRs that *incidentally* shrink a count (~2/week by the observed drift rate) and
the failure message is self-servicing.

**Cons:** Adds a per-PR failure mode to five guards at once. Requires a
behaviour-preserving refactor of a script that gates CI.

**Complexity:** Medium.

### Approach C: Mechanical + advisory drift reporter

**Description:** Regenerate, then add `check_baseline_drift.sh` sweeping every
numeric ratchet and emitting a `::warning` annotation, always exit 0 — the shape
the issue's "worth considering" proposes.

**Pros:** Zero friction; one script covers all 22 guards including the fork;
matches an existing pattern in the same CI job.

**Cons:** Nothing forces action. The repo's own advisory precedent (file-size)
shows warnings are tolerated indefinitely — it converts "someone eventually
notices" into "someone eventually notices, with an annotation".

**Complexity:** Low–Medium.

### Approach D: Invert the engine default

**Description:** Make decrease-detection the default in `numeric_ratchet.sh`,
opt-*out* per guard.

**Pros:** Conceptually cleanest; no guard can silently accumulate slack.

**Cons:** Widest blast radius — 20 guards flip at once, including
`service_god_file_sizes`, where a ceiling is a **line count** and any single
deleted line in a 4,500-line service would fail CI. Overturns a deliberately
documented design choice in one step.

**Complexity:** High.

## Recommendation

**Approach B**, staged to the design-system family, with all four baselines
regenerated.

Why B over the others:

- Over A: the recurrence is measured, not hypothetical.
- Over C: the repo already ran the advisory experiment; the file-size warning has
  not driven paydown.
- Over D: D's blast radius is dominated by one guard that must *not* be strict.
  `service_god_file_sizes` ceilings are line counts, so strict mode there fires
  on every line removed from `auth_service.dart` and its five siblings — untenable
  friction, and the reason "flip everything" is the wrong shape.

**Explicitly out of scope for the flag:** `service_god_file_sizes` (friction
above) and `ungrouped_tests` (defensible either way; a separate call). Both are
still *regenerated* so today's wins are locked.

## Open Questions for /plan

- [x] Which guards get the flag — the five design-system ceilings (#6145, #4803).
- [x] Which baselines get regenerated — all four drifted.
- [ ] Does the `raw_icons` port change its OK-line output? (Fork prints
      "N file(s) / M raw Icons.*"; engine prints "N key(s) tracked".) Cosmetic —
      confirm no test asserts on it.
- [ ] Commit split: one commit per finding, per the repo rule.

## Prerequisites

- [x] Worktree from `origin/main`.
- [x] Confirm all five design-system baselines are drift-free before flipping the
      flag (strict mode fails immediately otherwise — verified empirically).

## Next Step

`/plan 8323`
