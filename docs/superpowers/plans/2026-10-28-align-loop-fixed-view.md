# Align Loop Fixed View Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Hold one automatically selected, least-cropped fixed view throughout single-clip loop repairs.

**Architecture:** The pure planner already measures a confident camera path. Replace its periodically moving target with one trusted reference pose selected by minimum coverage zoom. Keep native rendering, independent output verification and repository acceptance in their existing layers.

**Tech Stack:** Dart, loop_alignment_repository, Flutter, PVE native iOS rendering.

**Spec:** docs/superpowers/specs/2026-10-28-align-loop-fixed-view-design.md

## Global Constraints

- Maximum zoom remains 1.08; confidence, coverage and seam gates remain enforced.
- No new dependencies, UI copy or storage changes.
- Preserve multi-clip and already-smooth policy, cancellation and source media.
- Real user media and identifiers remain local and uncommitted.

## Review Focus

- Interior camera drift despite matching endpoints: check every decoded fixture timestamp, not just the seam.
- Rotation and scale mixed with translation: check corrected framing and corner coverage for portrait and landscape.
- Candidate with lower crop away from the opening: assert independent, hand-derived crop bounds and deterministic selection.
- An unreliable required anchor: retain rejection rather than silently interpolate missing evidence.
- Irregular timestamps and playback speeds: preserve source-time interpolation and existing timing contracts.

---

### Task 1: Fixed target planning and real-output acceptance

**Files:**
- Modify: mobile/packages/loop_alignment_repository/lib/src/loop_alignment_planner.dart
- Create: mobile/packages/loop_alignment_repository/test/fixed_view_test.dart
- Existing regressions: mobile/packages/loop_alignment_repository/test/planner_test.dart and timestamps_test.dart
- Local-only native harness and footage: excluded work artifacts, never committed

**Interfaces:**
- Consumes: LoopAlignmentPlanner.plan, LoopFrameMatcher.match, LoopPose composition, requiredZoom and existing confidence evidence.
- Produces: the same LoopAlignmentPlan interface with a constant corrected camera target and constant coverage zoom.

- [ ] Run the complete package suite before modification and inspect the baseline.
- [ ] Add a regression named `holds the background fixed throughout a translated clip`; at every fixture time assert the corrected translation is the same as the first corrected translation within 1e-9. Observe RED on the existing periodically moving target.
- [ ] Add `chooses the least cropped trusted reference instead of the opening view`; use a hand-derived symmetric translation fixture and literal expected crop bound, with the opening reference requiring a strictly larger zoom.
- [ ] Add mixed rotation/scale tests for both orientations; assert corrected background travel under 0.05 analysis pixels and every output corner remains covered. Add irregular timestamp/speed cases and retain the unreliable-anchor rejection case.
- [ ] Replace single-clip periodic target smoothing with fixed-reference candidates built from the existing trusted camera anchors. Choose the minimum finite requiredZoom, with deterministic earliest ties. Do not relax limits or alter multi-clip correction.
- [ ] Run the new tests and the entire package suite to GREEN, then run Dart analysis for the package and affected app paths.
- [ ] Run the affected native client, PVE matcher and loop-history regression tests; resolve failures caused by the change.
- [ ] Render the exact supplied clip on the physical iPhone using real native decode/render/inspection. Record full-clip background travel, seam scores, duration, frame count and audio; count five wraps using last-quarter to first-quarter transitions and elapsed time.
- [ ] Inspect the actual output and compare the measured drift to the existing floating output. If the two-pixel target is not met, investigate the observed residual before changing tracking density.
- [ ] Obtain a fresh whole-branch review, fix in-scope findings with tests, and rerun relevant checks.
- [ ] Rebase onto fresh origin/main, commit, push and open a main-targeted PR with the mapped reviewers. Inspect all required CI checks before handoff. Merging remains a separate authorization.
