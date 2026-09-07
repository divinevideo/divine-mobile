# Audio/video track-end mismatch

An mp4's container duration is its *longest* track. Capture and export pipelines stop the audio and video writers independently, so the two tracks routinely end tens of milliseconds apart, and the file declares the longer one. Playing or exporting to that declared length ends on a stretch where one track has already run out — picture with no sound, or a frozen last frame. On a looping player that stretch is the loop seam (#6386).

Two independent mechanisms correct for this, at two different layers. They are easy to confuse because they are named after the same idea, and issues #7787, #7788 and #7789 all conflate them. This document is the map.

| | Export / render path | Playback path |
|---|---|---|
| Mechanism | `commonTrackEnd` shortens the *recorded clip's stored length* | `VideoClip.trimToCommonTrackEnd` clamps the *clip end the native player uses* |
| Lives in | `mobile/lib/services/video_editor/clip_media_duration.dart` | `mobile/packages/divine_video_player/lib/src/video_clip.dart` |
| Applied at | recording time, once, during the recorder's metadata enrichment pass | every `setSource`, per playback surface |
| Landed in | #6439 | #6430 |
| Tolerance | at most 500 ms shortfall, audio track at least `minCommonTrackEnd` | at most 500 ms and at most 10% of playable duration |

## The export path does not use `trimToCommonTrackEnd`

`VideoRenderData.trimToCommonTrackEnd` exists in `pro_video_editor` (2.11.3, `lib/core/models/video/video_render_data_model.dart:243`) and defaults to `false`. **No render task in this repo sets it.** All eleven `VideoRenderData(...)` constructions under `mobile/lib` leave it at the default, as does the `copyWith` in `renderWithEncoderFallback`.

That covers every render entry point, since they all funnel through the same builder:

| Entry point | Caller | Reaches |
|---|---|---|
| `renderVideoToClip` (final export) | `lib/providers/video_editor_provider.dart:1254`, `lib/providers/video_publish_provider.dart:494` | `_concatenateSegments` |
| `renderVideo` (seam preview) | `lib/services/video_editor/transition_seam_render_service.dart:163` | `_concatenateSegments` |
| `renderVideo` (merge clips) | `lib/services/video_editor/video_editor_merge_service.dart:35` | `_concatenateSegments` |
| `renderVideo` (save clip to library) | `lib/services/video_editor/video_editor_clip_library_save_service.dart:68` | `_concatenateSegments` |
| per-clip aspect-ratio normalization | `_normalizeClipsToAspectRatio` → `_renderNormalizedClip` | its own `VideoRenderData` |

This is deliberate, and #6439 measured both reasons for it:

- **It fixes the symptom a layer too late.** The trim happens in the native renderer, after the whole editor has already authored trims, layer windows, transitions and filter windows against the un-trimmed length. On a two-clip export with a 300 ms gap per clip, the native trim moved clip 2's start from 3.00 s to 2.70 s while an overlay anchored to clip 2 still fired at 3.00 s — 300 ms late, accumulating across clips. That drift is what #7787 describes.
- **It was Apple-only.** The flag had no Android counterpart in `pro_video_editor` 2.10.0; on a Galaxy S25 a 300 ms gap rendered to the same 284 ms with and without it.

Correcting the recorded clip's length instead is platform-independent and keeps the editor timeline and the export in step, so the export follows from the existing per-segment `endTime` with no special-casing.

## Where `trimToCommonTrackEnd` is actually set

Every site below is playback. Sites not listed take the constructor default, `false`.

| Site | Value | Intended? |
|---|---|---|
| `packages/infinite_video_feed/lib/src/utils/source_loader.dart:58` (`setSourceWithFallbacks` parameter default), forwarded at `:82` and `:133` | `true` | Yes. Its two callers are the feed, which wants it, and the subtitle editor, which opts out explicitly. Note the sharp edge: a *new* caller of this helper opts in silently. |
| `packages/infinite_video_feed/lib/src/widgets/infinite_video_feed.dart:1185` (cached file), `:1447` (failover source), `:1543` (retry after processing) | `true` | Yes. Looping single-clip feed playback is exactly the case the flag is documented for, and hiding the loop seam on already-published video is why #6430 exists. |
| `lib/widgets/subtitle_editor/subtitle_editor_stage.dart:62` | `false` | Yes, and the rationale is inline: the caption timeline is drawn from the container duration, so a clamp would put the last half-second of the axis out of the preview's reach. |
| `lib/extensions/divine_video_clip_player_mapping.dart:16` (`toPlayerVideoClip`, editor preview) and `lib/services/video_editor/transition_seam_render_service.dart:747-760` (seam preview clips) | default `false` | Yes. These are segments of a multi-clip timeline, where the field's own dartdoc says the clamp would cut content rather than a seam. |
| `lib/screens/comments/widgets/video_comment_player.dart:99` and `lib/widgets/video_clip/video_clip_preview.dart:87` | default `false` | **Unclear.** Both are looping single-clip playback of a finished video, which is the shape the flag was written for, yet neither opts in. Whether #6430 scoped itself to the feed on purpose is not answerable from the code. |
| `lib/screens/video_editor/video_clip_chroma_key_screen.dart:128`, `lib/screens/video_editor/video_clip_transform_screen.dart:73`, `lib/widgets/video_editor/main_editor/video_editor_canvas.dart:2268` (single-clip trim-drag preview) | default `false` | **Unclear.** Looping single-clip editor previews. The subtitle editor's reasoning plausibly applies — the canvas one sets `end: clip.duration`, so its axis really is the container duration — but unlike the subtitle editor none of them says so. |

Platform support is per-backend and documented on the field: Apple and Android honour it for local and remote sources, web and Linux ignore it, and Android skips the probe entirely for HLS.

## What the record says, and what the code says

PR #6439's description frames its first, abandoned revision — which did pass `trimToCommonTrackEnd` into the native renderer — and then explains under "Why not fix this at export time" that the merged version does not. The merged diff touches five files (`video_recorder_bloc.dart`, `clip_manager_provider.dart`, `clip_media_duration.dart`, and their two tests) and contains no occurrence of `trimToCommonTrackEnd`.

So the premise shared by #7787, #7788 and #7789 — that `_concatenateSegments` passes the flag to its render callers — does not hold against `main`. `_concatenateSegments` has never passed it, and the flag those issues name belongs to the player, from #6430.
