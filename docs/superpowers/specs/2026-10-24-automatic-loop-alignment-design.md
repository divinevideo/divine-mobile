# Automatic loop alignment

Status: Product direction accepted; phone feasibility validated in a disposable
prototype. Editor implementation awaits implementation-plan review.

## Intent

A nearly stationary recording can visibly jump when it repeats because its
ending is framed slightly differently from its beginning. Creators should be
able to tap one action and get a smoother loop when the footage supports it.
They should not have to understand stabilization, set alignment points, or
work through more editor options.

This is an optional operation. A close match makes a video a candidate; it
does not give the editor permission to change it automatically. Similar
scenery alone also does not establish compatible subject motion.

Success means a smaller visible discontinuity in both framing and motion,
with a modest crop, one undo operation, and identical preview and export.
Declining to change unsuitable footage is a successful outcome.

## User experience

Extend the existing Loop action and label it **Fix loop**. Make it operate
on the whole edit, without requiring selection of the last clip. Keep its
existing editor placement; add no toolbar item, settings page, or parameter
picker. Match detection runs after a tap, not on every import or export.

The action analyzes the join and, when it finds a reliable improvement,
applies it and starts repeated playback across the join. Show **Loop
smoothed** with **Undo**. If a trim was necessary, also state the amount
removed. The normal editor undo and redo controls cover the complete change.
There is no additional Keep step. A second tap analyzes the current result
and must not repeatedly add crop or produce duplicate history entries.

Use **This already loops smoothly** when no material improvement is needed,
and **Couldn't improve this loop** when no reliable, modest correction is
available. Neither result changes the edit or its history. A decoding or
rendering failure uses a distinct retryable error. Progress and cancellation
use the editor's existing operation treatment.

Only report already-smooth when registration is confident, every endpoint
corner moves at most 0.5 analysis pixels, the displayed-join score is at most
0.03, and its motion proxy is within the 95th percentile of nearby ordinary
adjacent-frame acceleration (at least four samples). Blank or uncertain
scenery is not evidence of an already-smooth loop.

Manual alignment is outside this change. The automatic operation should be
useful on its own before adding another editing surface.

## Approach and alternatives

Use loop-specific image registration and a smooth framing correction.
Estimate the small shift, rotation, and scale between matching scenery near
the end and beginning, then render a correction that joins the framing and
its motion continuously. This directly addresses the mismatch.

Trim-only search is already available. It remains useful for choosing a
better moment, but cannot by itself correct persistent camera drift.
Ordinary stabilization is also available; its smoothed camera path does not
require the ending to meet the beginning. A dissolve is an intentional
transition, and should remain a separate creative choice.

## Candidate selection and acceptance

Compare short sequences on both sides of the join, not just two stills.
Preserve the current start and duration when alignment alone works. A
combined candidate may remove at most 200 ms from the end, using decoded
frame timestamps and the existing minimum clip and composition durations.
Never extend the ending or change playback speed as part of this action.

Use upright, equally sized analysis frames with a longest edge of 320 pixels.
Estimate a similarity transform with the package's existing corner tracking,
forward/backward consistency checks, and robust transform fitting. Match
stationary scenery rather than a locally moving foreground subject. Check
that agreeing features are distributed across the picture; a cluster on a
single moving object is insufficient evidence of camera motion.

Initial conservative acceptance limits are:

- At least 20 consistent feature matches, with at least 60% of retained
  matches agreeing with the transform.
- Matches occupy at least four cells of a 3 by 3 image grid and span at least
  35% of the image width and height.
- Require independent support from opposite boundary strips: left and right,
  or top and bottom. Detect corners locally in the outer 8% of the full image,
  outside the corner detector's 8-pixel border. Each supporting strip needs
  at least four forward/backward-consistent matches and 60% agreement within
  one analysis pixel. The independent background fit uses these same bands.
  Do not widen support into possible foreground to rescue a plain margin,
  because a wider band can reach a subject. This does not establish semantic
  background identity, and it has known limits. Coherent foreground obscuring
  the boundaries stays ambiguous: a rigid subject filling nearly the whole
  frame can be accepted as camera drift. Measured: one reaching the left and
  right edges was accepted when inset 5% from the top and bottom and rejected
  at 10%; one reaching the top and bottom was already rejected at 5%. On
  encoded footage a plain margin within a few pixels of the band can still gain
  support from resampling ringing. Once ringing gives a band corners, a subject moving less than the
  one-pixel agreement tolerance can pass as camera drift: on one-off synthetic
  encodes with a 10% plain margin, a fitted displacement of about 0.6 analysis
  pixels was repaired and about 1.3 was declined.
- Withhold every third consistent match from a separate fit. Require at
  least five withheld points and median prediction error at most one
  analysis pixel.
- Horizontal and vertical displacement each stay within 3% of their
  respective frame dimension; rotation within 2 degrees; relative scale
  within 0.97 to 1.03.
- The total additional zoom needed to hide all exposed edges is at most
  1.08. Use one constant crop across the affected footage.
- A candidate must reduce the normalized join error by at least 25%, and
  must not increase the discontinuity of subject motion across neighboring
  frames. Validate alignment on features withheld from fitting as well as
  the displayed image, so fitting a subset is not proof of improvement.

Use a displayed-join score, distinct from `VideoLoopPointFinder`'s
motion-predicted trim-search score:
mean absolute luma difference divided by 255 on its 64-pixel analysis grid,
with up to two neighboring frame pairs on each side weighted 1, 0.5, and
0.25 by distance from the cut, then divided by the sum of included weights.
Score the original and corrected candidates with the same available frame
pairs and common crop. The accepted score must also be at most 0.03, the
current app's close-match threshold. A percentage improvement alone must not
turn a bad match into an accepted correction.

The limits are conservative product policy, not a measured general accuracy
claim. A disposable implementation passed 20 synthetic acceptance/rejection
cases after an observed moving-foreground false positive was fixed with the
independent boundary check. Before shipping, extend that validation to the
cases below. Tighten limits when needed; do not relax them just to make every
clip produce a result.

The analysis must separate background registration error from motion continuity.
Evaluate temporal changes against ordinary adjacent-frame changes near the
join, after accounting for the candidate warp and normalizing luminance.
Repeated textures need an unambiguous fit. A low error on a blank image is
not confidence. Keep the final cut on normal frame progression: duplicating
an identical opening frame at the end can create a pause of its own.

If no aligned candidate passes, the same bounded search may accept a
trim-only improvement with compatible motion. Otherwise keep the edit as it
was. Do not introduce a dissolve, reverse playback, or change intentional
cuts as a fallback.

## Framing correction

For one continuous clip, estimate the camera path and solve for a correction
whose displayed framing and frame-to-frame motion join smoothly around the
repeat. Distribute the adjustment over the shot, rather than moving only its
last frames. Endpoint position constraints alone are insufficient: verify
the motion on both sides of the join too.

For multiple clips, compare the last clip with the first. The alignment
correction acts only on the last clip and starts at identity with zero
correction velocity. Apply the same constant coverage crop to the entire
composition, including its first clip; otherwise cropping only the last shot
would itself change the preceding cut. Relative to that common crop, the
beginning of the last clip and its incoming motion stay unchanged. Internal
cuts stay at their existing times. If the available shot length cannot
support a smooth correction within the limits, decline the correction.
Matching unrelated shots throughout a montage is outside this operation.

Calculate the constant crop from the entire correction path, including
intermediate rotations and scales, not just its endpoints. Revalidate the
join using the actual planned output transforms. Cap failures reject the
candidate instead of weakening the correction and claiming it closes.

Analyze the displayed base footage, with its baked crop, flip, and rotation
and its current playback timing. Screen-space text and stickers remain in
their canvas positions. The first release supports normal video clips with
uniform speed and baked transforms. Reject an existing loop transition,
unmaterialized stop-motion frames, placeholder or held-frame endpoint, speed
ramp, detached composition, source-tracked layer, or keyed/masked endpoint
whose displayed geometry cannot yet be reproduced by this analysis. Report
that the loop could not be improved without changing those features.

## Ownership and integration

Put reusable confidence measurements, motion scoring, transform planning,
plain Dart contracts, and orchestration in the owning workspace package
`mobile/packages/loop_alignment_repository`. Native clients bridge decoding,
tracking, and rendering without exposing Flutter geometry to that package.
Reuse `pro_video_editor` 2.42.0's public Dart libraries under
`package:pro_video_editor/core/analysis/` for corner tracking and fitting.
They are outside `lib/src` and contain no `@internal` restriction; omission
from the top-level barrel does not make them private. Cover their actual
signatures with adapter tests. Do not copy their implementations, edit the
pub cache, add a local dependency override, or import `lib/src`.
See [Dart's package library guidance](https://dart.dev/tools/pub/create-packages#organizing-a-package).

This corrects the initial assumption that shipping required an upstream
release. The installed version already supplies the necessary public
libraries and native rendering API. A future upstream API can replace the
adapter without changing editor or repository contracts.

In this repository, use the layered flow UI -> Cubit -> Repository -> Client.
Extend `LoopSuggestionCubit`'s existing role for busy and result presentation.
The repository owns acceptance limits and candidate selection through injected
analysis and render clients. Its request and result types contain plain Dart
values; Flutter and plugin-specific video or geometry objects stay in the
client bridge. The UI dispatches the action and reads operation state.

The render client reuses `VideoSegment.stabilization`, the render watchdog,
native task tracking, cancellation, and unique local output paths. Render
corrected base footage to a new file, then reuse that file in both preview
and export. Preserve audio and source-time mappings; a trim uses the existing
timeline reanchoring behavior. Revalidate the actual rendered join before
applying it. The original source remains available to undo and draft recovery.

Apply the replacement clip, any trim, and affected timeline anchors as one
history transaction only after successful rendering and validation. Do not
modify the composition to preview an unfinished suggestion. New render
provenance records the source as an edit in the existing C2PA flow.

## Concurrency, persistence, and failure

Capture the complete relevant composition revision before analysis. A trim,
reorder, source replacement, speed change, transition change, overlay change,
or navigation away invalidates the result. Cancel the work and discard its
output instead of applying a stale result. Include this operation in the
existing pending-operation guard, and do not replace another audition.

Cancel both analysis and render under their own task ids. Cancellation,
timeout, no match, and render failure leave the composition, history, and
audio intact and remove partial output. Reuse the established cleanup rules
for files retained by undo history and saved drafts. Persist enough source
provenance for draft reload and undo/redo; do not overload the existing
stabilization toggle with a different operation.

Run bounded frame decoding and analysis in a background worker,
with one analysis decoder while the preview retains its player. Apply the
existing render watchdog timeout. Unsupported platforms expose the current
capability treatment rather than starting an operation that cannot finish.

## Verification before shipping

Use synthetic scenes and footage approved for a local visual check. Do not
commit real creator identifiers, downloaded user footage, or private frame
dumps as fixtures.

- A textured scene with known translation, rotation, or scale and an
  independently moving foreground is corrected within subpixel tolerance at
  analysis resolution, without tracking the foreground as the camera.
- Already smooth footage is a no-op. Unrelated shots, blank or repeated
  textures, dominant moving foreground, large pans, parallax, occlusion, and
  excessive required crop are rejected.
- The displayed framing and neighboring motion are continuous at the repeat;
  a multi-clip correction preserves the previous internal cut. Every output
  frame stays covered, including intermediate transforms.
- Bounded trimming respects decoded frame times, speed, clip floors,
  composition limits, and anchored audio. The output has no duplicated
  endpoint frame or extra pause.
- Cubit/repository tests cover apply, repeat tap, no-op, low confidence,
  cancellation, timeout, stale composition, navigation, and rendering errors.
  One undo/redo restores the complete edit, and draft reload reproduces it.
- Widget tests verify one existing action, automatic playback after the
  replacement player is ready, Undo, accessible progress and messages, and
  localized copy in both appearances. No manual setup is required.
- Inspect rendered playback on iOS and Android, both in the editor and after
  export. Compare the real join repeatedly at normal speed; still-frame
  metrics alone do not establish perceptual smoothness.

The maintainer subsequently approved proceeding to Android beta testing without
waiting for a connected Android phone (2026-10-24). The implementation PR must
state which production playback/export checks were actually performed; prototype
inspection does not establish those results.

## Pre-implementation references

- `mobile/lib/services/video_editor/clip_loop_point_service.dart`: the
  existing package-backed trim-only search.
- `mobile/lib/models/video_editor/loop_point_search.dart`: source-time search
  windows, duration floors, and current unsupported endpoint cases.
- `mobile/lib/blocs/video_editor/loop_suggestion/`: current search state and
  suggested trim handling.
- `mobile/lib/widgets/video_editor/timeline_editor/controls/video_editor_timeline_loop_suggestion_controls.dart`:
  existing player-ready audition and composition guards.
- `mobile/lib/services/video_editor/clip_stabilization_service.dart`: native
  keyframe rendering, watchdog, cancellation, and source retention patterns.

## Feasibility evidence

The release prototype processed a 6.3-second, 1080-square, 189-frame clip on a
physical iPhone 15 Pro. It decoded every frame but ran expensive motion
estimation on 17 anchors. Three direct processing trials took 1.396–1.574
seconds for the entire clip. With source playback active, the operation took
1.710–1.887 seconds from activation to corrected playback in the latest two
trials, including player replacement. The prototype restored the original
through Undo and reapplied successfully. These are measurements on one phone,
not a latency guarantee for the app or for other devices.

Native output retained 189 frames and 6.3 seconds of audio and video. The
additional zoom was 1.0224; the displayed-join difference proxy fell 67.8%.
The creator also inspected the smoothed playback and found it looked good.
The metrics support that visual check; they do not prove arbitrary footage
will become seamless. Android, older phones, portrait orientation, multi-shot
edits, HDR, and the actual editor integration still need validation.

Related prior trim-search work is issue #10249 (Brain document
`49CD880BD16BE5B99F5D41ACA9`); the current checkout defines its actual behavior.

This document defines intended behavior. No editor behavior has changed yet.
