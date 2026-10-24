# Automatic Loop Alignment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the existing Loop helper with one optional Fix loop action that repairs a reliable framing mismatch, plays the result, and supports one-step Undo.

**Architecture:** UI -> existing LoopSuggestionCubit -> new loop_alignment_repository workspace package -> injected native client. The package owns plain Dart contracts, confidence, correction planning, scoring, and candidate selection; the client adapts public pro_video_editor tracking libraries and native decode/render APIs. A validated file replacement enters existing editor history atomically.

**Tech Stack:** Dart, Flutter/BLoC, pro_video_editor 2.42.0 public analysis libraries and stabilization rendering, existing editor history/draft infrastructure; no new native vision library or model.

**Spec:** [Automatic loop alignment](../specs/2026-10-24-automatic-loop-alignment-design.md). Read both documents; prototype code is disposable evidence, not code to copy into the product.

## Global Constraints

- Extend the existing Loop action and label it **Fix loop**; no additional toolbar item, settings, manual controls, or Keep step.
- No automatic changes on import or export; unsuccessful operations change neither composition nor history.
- Analysis longest edge 320 pixels; preserve upright aspect ratio and decoded source timestamps. One analysis decoder runs alongside the preview player.
- At least 20 consistent matches; at least 60% agreement; four cells of a 3 by 3 grid; at least 35% width and height coverage.
- Independent opposite boundary strips: outer 8%, excluding the 8-pixel tracking border; four agreeing matches per supporting strip, 60% agreement within one analysis pixel. Withhold every third match; at least five withheld points, median error at most one pixel.
- Displacement at most 3% on each axis; rotation at most 2 degrees; scale 0.97–1.03; one constant additional zoom at most 1.08, covering every output frame.
- Displayed-join score uses 64-pixel luma frames and weights 1, 0.5, 0.25. Require at least 25% improvement, final error at most 0.03, and no increase in the motion-continuity proxy. Compare with the same crop.
- Preserve current duration first; any accepted end trim is at most 200 ms, never an extension, and respects existing clip/composition floors and anchored audio.
- Preserve human footage, audio, overlays, internal cut timing, provenance, and original files retained by drafts/history. No generated pixels, crossfade, reversal, or speed change.
- First release supports normal clips, uniform speed, and baked transforms. Decline the unsupported endpoint/composition cases listed in the spec; do not flatten them silently.
- Use the render watchdog, unique outputs, native task registry, cancellation, and post-render validation. Never edit pub cache, copy upstream tracking implementations, add path overrides, or import upstream lib/src.
- New repository code has no Flutter imports or runtime Flutter SDK dependency. Public PVE tracking adapters stay in the app's native client, supplied to pure Dart planning through an interface.
- Keep downloaded footage, creator identifiers, device identifiers, and private frame dumps out of commits. Tests generate their own scenes.

## Review Focus

1. Portrait, mirrored, rotated, or variable-frame-rate input: match displayed geometry and actual timestamps, not a square frame or fixed 30 fps assumption (Tasks 1–3).
2. A textured moving subject filling most of the view: leave the shot unchanged when the camera cannot be established independently (Tasks 1–2).
3. A very short final shot in a montage: preserve the preceding cut and motion or decline; never stretch correction into an earlier shot (Tasks 1, 4).
4. The user edits, navigates, cancels, or taps again while a decoder is finishing: do not apply a stale output, delete an owned source, or add a second history entry (Tasks 3, 5).
5. A draft is reopened after the OS changes its documents directory, then edited and undone: retain valid sources and provenance without accumulating crop (Task 4).

---

## Contract and file map

Create `mobile/packages/loop_alignment_repository/` with `pubspec.yaml`, `analysis_options.yaml`, a public `lib/loop_alignment_repository.dart` barrel, `lib/src/loop_alignment_models.dart`, `loop_alignment_planner.dart`, `loop_seam_scorer.dart`, `loop_alignment_client.dart`, and `loop_alignment_repository.dart`. Tests mirror these units under `test/`; generated scene helpers live under `test/helpers/`. Register the workspace/dependency in `mobile/pubspec.yaml` and package CI using the repository's existing package-workflow pattern.

Public contracts use immutable values, with no Flutter/plugin types:

- `LoopFrame({required Duration time, required int width, required int height, required Uint8List luma})`.
- `LoopPose({required double a, required double b, required double tx, required double ty})`: centered similarity transform, translations in analysis pixels; exposes `inverse()`, `then(LoopPose next)`, and identity.
- `LoopFrameMatch`: pose, consistent/retained counts, occupied cells, width/height spans, withheld count/error, and per-boundary agreeing/retained counts. No opaque pass/fail confidence flag from the adapter.
- `abstract interface class LoopFrameMatcher { LoopFrameMatch? match(LoopFrame reference, LoopFrame target); }`.
- `LoopClipInput`: stable clip id, local displayed-base path, source start/end, uniform speed, upright dimensions. `LoopRepairInput`: immutable ordered clips plus a composition revision string and supported/unsupported capability value.
- `LoopKeyframe({required Duration sourceTime, required LoopPose correction})`; `LoopClipPlan`: clip id, render range, keyframes; `LoopAlignmentPlan`: replacement plans, constant zoom, optional trimmed source end, confidence, and predicted scores.
- `LoopSeamScores({required double difference, required double motion})`; `LoopAnalysis`: baseline scores and candidate plans; `LoopRenderedOutput`: owned output paths keyed by clip id and decoded media metadata; `LoopInspection`: measured scores, frame times, audio/video durations, and coverage result.
- `LoopRepairStatus`: `repaired`, `alreadySmooth`, `noMatch`, `unsupported`; `LoopRepairResult`: status, optional output and plan. Cancellation and technical failure throw typed exceptions rather than pretending to be no-match.
- `LoopAlignmentLimits`: immutable constructor defaults to the exact global constraints above; repository policy is passed into worker planning without global mutable configuration.
- `LoopAlignmentClient`: `Future<LoopAnalysis> analyze(LoopRepairInput input, LoopAlignmentLimits limits, String taskId, void Function(double) onProgress)`, `Future<LoopRenderedOutput> render(LoopRepairInput input, LoopAlignmentPlan plan, String taskId, void Function(double) onProgress)`, `Future<LoopInspection> inspect(LoopRepairInput input, LoopAlignmentPlan plan, LoopRenderedOutput output, String taskId)`, `Future<void> cancel(String taskId)`, `Future<void> discard(LoopRenderedOutput output)`.
- `LoopAlignmentRepository({required LoopAlignmentClient client, LoopAlignmentLimits limits = const LoopAlignmentLimits()})`; `Future<LoopRepairResult> repair(LoopRepairInput input, {required String taskId, void Function(double)? onProgress})`; `Future<void> cancel(String taskId)`; `Future<void> discard(LoopRepairResult result)`.

App files created by later tasks: `services/video_editor/native_loop_alignment_client.dart`, `services/video_editor/pve_loop_frame_matcher.dart`, `models/video_editor/clip_loop_alignment.dart`, `models/video_editor/loop_repair_input.dart`, and `widgets/video_editor/timeline_editor/controls/video_editor_loop_repair_listener.dart`. Paths are relative to `mobile/lib/`.

### Task 1: Pure Dart geometry, acceptance, and scoring

**Files:** New package models/planner/scorer, barrel, generated-scene helpers and corresponding tests; workspace manifest and package CI registration.

**Interfaces:** Produce the frame, pose, matcher, limits, plan, and score types above. `LoopAlignmentPlanner.plan({required LoopRepairInput input, required List<LoopFrame> firstFrames, required List<LoopFrame> lastFrames, required LoopFrameMatcher matcher, required LoopAlignmentLimits limits}) -> LoopAlignmentPlan?`; `LoopSeamScorer.score(List<LoopFrame> start, List<LoopFrame> end) -> LoopSeamScores`. One input clip selects the periodic single-shot path; multiple clips select the final-shot correction.

- [ ] Write failing tests: known translation/rotation/scale yields maximum corner error `< 0.5` analysis pixels; identity source gives no correction; pose composition/inversion round-trips points within `1e-9`; coverage checks every keyframe and interpolated output-frame transform, rejecting `zoom > 1.08`.
- [ ] Add rejection tests for each confidence boundary (including exactly 20 / 60% / four cells / 35% / five withheld points), opposite-edge support, repeated/blank textures, dominant foreground, parallax, exposure/occlusion, unrelated cuts, and geometry limits. Parameterize portrait and landscape; generate pixels in Dart.
- [ ] Add scoring assertions: identical arrays yield zero; weighted difference matches a hand-computed fixture; a 24% improvement fails, 25% with final `0.03` passes, `0.03001` fails; increased motion proxy fails. Include short sequences with fewer than three frame pairs and reject fewer than two frames per side.
- [ ] Run `cd mobile/packages/loop_alignment_repository && flutter test`; expect failures on missing API/assertions before implementation.
- [ ] Implement primitives, confidence checks, bilinear resampling, and scoring. For one shot, fit anchors at most 400 ms apart including both endpoints, reject any unreliable anchor, interpolate pose in translation/angle/log-scale by timestamps, and apply periodic Gaussian smoothing with sigma `min(0.5 seconds, visibleDuration / 8)`.
- [ ] For multiple shots, solve a cubic Hermite correction in translation/angle/log-scale on the final shot: initial value/derivative zero; final value closes the measured join and final derivative matches the opening motion. Test a short shot needing excessive crop is rejected; first-shot and final-shot displayed velocity agree within the generated fixture's tolerance. Common crop applies to every clip, and all internal cut times stay unchanged.
- [ ] Run package tests and `flutter analyze`; expect pass. Commit only this task's files as `feat(video-editor): add loop alignment planning and scoring`.

### Task 2: Actual PVE matching and bounded decode adapter

**Files:** New `pve_loop_frame_matcher.dart`, `native_loop_alignment_client.dart` analysis path; tests under `mobile/test/services/video_editor/`; pure contracts from Task 1.

**Interfaces:** `PveLoopFrameMatcher implements LoopFrameMatcher`. `NativeLoopAlignmentClient implements LoopAlignmentClient`, with injected PVE/native/file wrappers following current render-service patterns; implement `analyze` here, render/inspect/discard in Task 3. Worker input/output contains only transferable/plain Dart values.

- [ ] Write failing adapter tests using generated textured frames with independently moving foreground: known camera fit error `< 0.5` pixels; a bright foreground covering most of the scene is rejected through the Task 1 policy despite a strong global fit. Assert imports compile against the installed public PVE libraries without local overrides.
- [ ] Write decode tests: 180×320 portrait stays portrait; source rotation/mirroring agrees with rendered upright output; irregular PTS drives anchors/keyframes; a 60 fps input never turns frame indices into assumed 30 fps timestamps. Restrict decoding to the displayed composition windows, even for a long imported source.
- [ ] Run affected tests; expect failures before adding the adapter.
- [ ] Adapt public corner detection, pyramids, forward/backward LK tracking, and RANSAC into `LoopFrameMatch`. Detect boundary features locally, independently of the global subject threshold. Split fitting and withheld sets before the validation fit. Keep upstream implementations in the dependency.
- [ ] Decode with `getLumaFrameStream`, longest edge 320 and `maxParallelDecoders: 1`; run matching/planning/scoring in a cancellable background isolate. Bound buffering by the 6.3-second displayed composition window; release non-anchor/interior luma once no longer needed. Emit progress, and reject malformed frame sizes, nonmonotonic times, or unsupported orientation rather than guessing.
- [ ] Run affected tests, package tests, and `flutter analyze`; expect pass. Commit as `feat(video-editor): adapt native frame analysis for loop repair`.

### Task 3: Render, inspect, and choose a verified result

**Files:** Complete native client; package `loop_alignment_client.dart`, `loop_alignment_repository.dart`; repository/client tests; existing native render/cancellation services reused without changing their semantics.

**Interfaces:** Implement the client/repository methods in the contract map. Per operation use one unique namespace with separate decode, worker, render, and verify ids; cancellation stops every child.

- [ ] Write failing repository tests: unchanged-duration candidate wins first; only a frame-timestamp-aligned end trim `<= 200 ms` is eligible; no extension; trim-only fallback uses the same score/motion gates. A blank/uncertain scene is no-match, not already-smooth. For a confident fit, displacement of every endpoint-image corner `<= 0.5` analysis pixels, baseline score `<= 0.03`, and join motion proxy within the 95th percentile of adjacent-frame acceleration near the join yield already-smooth without rendering; require at least four adjacent samples for that motion reference.
- [ ] Add native-client tests asserting `VideoSegment.stabilization` offsets use each frame's width/height, times map to source PTS, and constant crop is applied once. A multi-shot render applies the same zoom to all clips and correction only to the final clip. Preserve native audio and uniform playback timing.
- [ ] Add cancellation/failure tests at each await boundary: watchdog, late decode, disk full, partial output, inspection failure, and a second operation using the same clip. Owned temporary outputs are deleted, source/history files survive, and no unverified output is returned. Post-render rejection must delete every generated replacement.
- [ ] Run the new repository/client tests; expect failures before implementation.
- [ ] Implement repository-owned ordered candidate selection and final acceptance. Limit the existing trim finder to `[currentEnd - 200 ms, currentEnd]` and the existing minimum duration; never reuse its score as proof of displayed-output quality. Require native output inspection to pass the same common-crop seam/motion gates, frame progression, coverage, audio presence, and duration checks before returning `repaired`.
- [ ] Render unique local files with existing watchdog, native task tracking, and cancellation registries. Validate durations against actual frame/sample timing, not exact floating-point equality; fail on a dropped/duplicated displayed endpoint or unintended audio loss. Dispose progress subscriptions and isolates on every exit.
- [ ] Run package and affected app tests plus `flutter analyze`; expect pass. Commit as `feat(video-editor): render and validate automatic loop repairs`.

### Task 4: Persistent replacement and one complete undo transaction

**Files:** New `clip_loop_alignment.dart`, `loop_repair_input.dart`; modify `models/divine_video_clip.dart`, `blocs/video_editor/clip_editor/clip_editor_{bloc,event,state}.dart`, `extensions/video_editor_extensions.dart`; matching model, history, draft, and clip-editor tests.

**Interfaces:** `ClipLoopAlignment` records original displayed-base path, rendered window start, source duration/trim floor/start offset, source provenance, and operation identity; provide `fromJson`/`toJson` with existing path reanchoring. `LoopRepairInputMapper.fromComposition(...)` produces the plain request from clips and capability flags. Add `ClipEditorLoopRepairApplied({required List<DivineVideoClip> expectedClips, required LoopRepairResult result})` and a one-shot success result carrying before/after clips. No direct repository dependency on DivineVideoClip.

- [ ] Write failing tests: successful replacements preserve clip ids, audio, speed, overlay positions, duration, and all internal cut timestamps; a trim reanchors existing audio/markers correctly; one history undo and redo restore the entire edit, including a multi-clip crop.
- [ ] Test JSON round-trip after documents-directory relocation and missing/corrupt optional alignment records. Retained-file enumeration includes original and current outputs/provenance; history cleanup never removes either while referenced. Draft reload reproduces the actual output. Subsequent crop/trim/split/reverse and stabilization undo must not silently restore a pre-alignment file; add explicit provenance invalidation/composition tests for these interactions.
- [ ] Run targeted model/clip/history tests; expect failures before implementation.
- [ ] Implement source mapping and retention using the existing stabilization/derived-source patterns without reusing its toggle. Treat alignment as a new bake: preserve earlier provenance in its source record/history and clear active stabilization-toggle metadata so toggling it cannot swap past the alignment. Later transforms consume the current aligned file; a new logical clip clears alignment metadata under the existing copyWith rules while preserving signing sources. Applying a result checks the original clip snapshot again. Commit replacements, bounded trim, anchored audio, markers, and provenance through one history operation; use existing `setLengthenedClipState`/`setClipState` semantics and avoid two writes. A repeat operation analyzes current displayed footage; it does not blindly add another crop.
- [ ] Run affected tests and `flutter analyze`; expect pass. Commit as `feat(video-editor): persist undoable loop alignment edits`.

### Task 5: Cancellable operation state and stale-result protection

**Files:** Existing `loop_suggestion_cubit.dart` and state; screen dependency wiring; clip pending-operation guard; new `loop_repair_input.dart` revision value; cubit and guard tests.

**Interfaces:** Inject `LoopAlignmentRepository` into `LoopSuggestionCubit`; replace trim audition with `Future<void> fix(LoopRepairInput input)`, `Future<void> cancel()`, `void compositionChanged(String revision)`, and `void resultHandled()`. State holds immutable request/task identity, revision, progress, status, and optional result. Keep exceptions out of state and report errors through `addError`.

- [ ] Write failing tests: repaired, already-smooth, unsupported, no-match, technical error, and timeout each produce distinct outcomes. Repeated taps during an operation start exactly one job. A second tap on a corrected input can return already-smooth without output/history. Cancel/close suppress later progress and completion.
- [ ] Parameterize stale-result tests for trim, reorder, source replacement, speed, transition, overlay/layer/audio changes, opening another editor, and navigation. A completed stale candidate is discarded and never applied. A new operation cannot accept an old operation's progress or cancellation completion.
- [ ] Run cubit/guard tests; expect failures before implementation.
- [ ] Implement the state machine using state-owned request identity and immutable injected dependencies. Build a revision from complete relevant serialized composition data in the mapper; presentation listeners forward updates, not selection/fallback logic. Include repair in the editor pending-operation guard and cancel on invalidation or close. Remove the temporary trim-audition state and prevent overlapping existing auditions.
- [ ] Run affected tests and `flutter analyze`; expect pass. Commit as `feat(video-editor): coordinate cancellable loop repair`.

### Task 6: One existing action, corrected playback, localized Undo

**Files:** Existing timeline clip controls/control bar/timeline, video editor scaffold and main overlay action guards; replace old loop-suggestion controls/listener with `video_editor_loop_repair_listener.dart`; screen wiring; all locale ARBs and generated localizations; widget tests for these surfaces.

**Interfaces:** Widgets dispatch Task 5 methods and show statuses. The result listener applies Task 4's verified replacement, commits one history entry, then starts seam playback only after the replacement player reports ready. Snackbar Undo invokes normal history Undo.

- [ ] Write failing widget tests: exactly one Fix loop action at the existing Loop location, available for the whole composition without selecting the final clip; existing platform capability handling; progress/cancel semantics; no Keep step. Unsupported compositions leave history unchanged and report the appropriate result.
- [ ] Test player-not-ready then ready, Undo, no-match/already-smooth/error messages, live composition invalidation, and navigation after completion but before playback readiness. Check accessible labels/announcements and both appearances. Do not use fixed delays to make playback tests pass.
- [ ] Run affected widgets tests; expect failures before implementation.
- [ ] Implement **Fix loop**, **Loop smoothed**, **Undo**, **This already loops smoothly**, **Couldn't improve this loop**, a localized removed-duration message when needed, and the existing retryable error treatment. Reuse existing components and colors; remove superseded Keep/Cancel audition behavior and dead localization keys only when no longer referenced.
- [ ] Follow localization style and l10n skills, regenerate with `flutter gen-l10n`, and run their required parity checks; test both appearances and accessible controls. Run widgets/cubit/clip tests and `flutter analyze`; expect pass. Commit as `feat(video-editor): add one-tap Fix loop with Undo`.

### Task 7: Actual editor/device and export acceptance

**Files:** Generated-fixture integration tests under `mobile/integration_test/`; a safe aggregate validation record under `docs/superpowers/validation/`; no downloaded footage or unique device identifiers.

**Interfaces:** Exercise the shipped Task 6 action through the actual editor and normal export/draft pathways, not the disposable test app.

- [ ] Add and run an integration test with generated camera drift and moving foreground: tap Fix loop, await readiness, verify repeated playback, Undo/redo, save/reopen draft, export and decode. Assert frame/source timing, audio retention, common crop, and no border pixels. Include multi-shot and portrait/rotation fixtures and a rejected dominant-foreground fixture.
- [ ] Measure release tap-to-corrected-playback with preview playing on physical iOS and Android, including an older/lower-performance device. Record decode/analysis/render/verification/player-ready time, peak buffer memory, thermal state, and UI frame timings; test repeated activation and cancellation. The prototype's 1.7–1.9 seconds on one iPhone is evidence, not a cross-device promise. If required hardware is unavailable, keep the PR draft and name the missing evidence.
- [ ] Visually inspect normal-speed editor and exported joins, including compatible moving subjects and a montage's preceding cut. Inspect VFR, uniform speed, HDR/color, and imported long-source windows. A lower metric alone does not pass this step; reject/revise any visible jerk, pause, brightness change, unexpected crop, or audio discontinuity.
- [ ] Run affected package/app/integration tests, full `flutter analyze`, localization checks, and relevant guard scripts. Fetch and rebase onto fresh `origin/main` before publishing; run impacted checks again after any conflict resolution.
- [ ] Commit the safe validation record as `test(video-editor): verify loop repair in playback and export`; push the combined branch/PR targeting main, update its title/description to the final feature scope, inspect required CI to completion, and request the mapped review team when ready. Obtain fresh-context complete-diff review per the shared runbook. Do not merge without the governing authorization.

## Plan self-review

The seven tasks cover the spec's confidence, sampled path, real-output validation, single/multi-shot geometry, bounded trim fallback, persistence/provenance, pending-operation/stale guards, UI/copy, and physical-device/export gates. Each Review Focus item has explicit tests above. Contracts use plain Dart values across the repository/client boundary; Flutter geometry is confined to native adaptation. Unsupported footage remains unchanged. The initial package-API assumption is corrected in the spec; no upstream release is a prerequisite.

Recommended execution: **Native**. The seven tasks share the analysis/output/history contracts closely, and one implementation context avoids repeated rediscovery; request a fresh-context whole-branch review after the end-to-end checks.
