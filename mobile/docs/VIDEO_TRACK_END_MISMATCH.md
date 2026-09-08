# Audio/video track-end mismatch

An mp4's container duration is its *longest* track. Capture and export pipelines stop the audio and video writers independently, so the two tracks routinely end tens of milliseconds apart, and the file declares the longer one. Playing or exporting to that declared length ends on a stretch where one track has already run out — picture with no sound, or a frozen last frame. On a looping player that stretch is the loop seam (#6386).

Two independent mechanisms correct for this, at two different layers. They are easy to confuse because they are named after the same idea, and issues #7787, #7788 and #7789 all conflate them. This document is the map.

| | Export / render path | Playback path |
|---|---|---|
| Mechanism | `commonTrackEnd` shortens the *recorded clip's stored length* | `VideoClip.trimToCommonTrackEnd` clamps the *clip end the native player uses* |
| Lives in | `mobile/lib/services/video_editor/clip_media_duration.dart` | `mobile/packages/divine_video_player/lib/src/video_clip.dart` |
| Applied at | recording time, once, during the recorder's metadata enrichment pass | when a `VideoClip` is loaded, per playback surface |
| Landed in | #6439 | #6430 |
| Tolerance | at most 500 ms shortfall, audio track at least `minCommonTrackEnd` | at most 500 ms and at most 10% of playable duration |

## The export path does not use `trimToCommonTrackEnd`

`VideoRenderData.trimToCommonTrackEnd` exists in `pro_video_editor` (2.11.3, `lib/core/models/video/video_render_data_model.dart:243`) and defaults to `false`. **No render task in this repo sets it.** All eleven `VideoRenderData(...)` constructions under `mobile/lib` leave it at the default, as does the `copyWith` in `renderWithEncoderFallback`.

The constructions are spread across the final-export builder and several
single-purpose direct renderers. The complete inventory is:

| Render task | Construction | Reaches |
|---|---|---|
| final export, seam preview, merge clips, and save clip to library | `lib/services/video_editor/video_editor_render_service.dart:1215` | `_concatenateSegments` |
| per-clip aspect-ratio normalization | `lib/services/video_editor/video_editor_render_service.dart:1111` | `renderWithEncoderFallback` |
| limit clip duration and crop to aspect ratio | `lib/services/video_editor/video_editor_render_service.dart:855`, `:942` | `_cancelAndRender` |
| bake chroma key | `lib/services/video_editor/chroma_key_bake_service.dart:172`, `:194` | `renderNativeVideoToFile` |
| bake playback speed | `lib/services/video_editor/clip_speed_render_service.dart:172` | `renderNativeVideoToFile` |
| reverse clip | `lib/services/video_editor/video_editor_reverse_service.dart:64` | `renderNativeVideoToFile` |
| transform clip | `lib/services/video_editor/video_editor_transform_service.dart:68` | `renderNativeVideoToFile` |
| materialize a multi-clip draft for upload | `lib/services/video_publish/draft_upload_materializer.dart:126` | `renderNativeVideoToFile` |
| add a download watermark | `lib/services/watermark_download_service.dart:417` | `renderNativeVideoToFile` |

This is deliberate, and #6439 measured both reasons for it:

- **It fixes the symptom a layer too late.** The trim happens in the native renderer, after the whole editor has already authored trims, layer windows, transitions and filter windows against the un-trimmed length. On a two-clip export with a 300 ms gap per clip, the native trim moved clip 2's start from 3.00 s to 2.70 s while an overlay anchored to clip 2 still fired at 3.00 s — 300 ms late, accumulating across clips. That drift is what #7787 describes.
- **It is Apple-only.** The shipped `pro_video_editor` 2.11.3 still says Android has no equivalent clamp and that compositions ignore the flag. On a Galaxy S25 a 300 ms gap rendered to the same 284 ms with and without it.

Correcting the recorded clip's length instead is platform-independent and keeps the editor timeline and the export in step, so the export follows from the existing per-segment `endTime` with no special-casing.

## Where `trimToCommonTrackEnd` is actually set

Every site below is playback. Sites not listed take the constructor default, `false`.

| Site | Value | Intended? |
|---|---|---|
| `packages/infinite_video_feed/lib/src/utils/source_loader.dart` (`setSourceWithFallbacks` required parameter) | caller-selected | Yes. The feed passes `true`; the subtitle editor passes `false`. Requiring the choice prevents a new caller from inheriting playback policy silently. |
| `packages/infinite_video_feed/lib/src/widgets/infinite_video_feed.dart:1185` (cached file), `:1447` (failover source), `:1543` (retry after processing) | `true` | Yes. Looping single-clip feed playback is exactly the case the flag is documented for, and hiding the loop seam on already-published video is why #6430 exists. |
| `lib/widgets/subtitle_editor/subtitle_editor_stage.dart:62` | `false` | Yes, and the rationale is inline: the caption timeline is drawn from the container duration, so a clamp would put the last half-second of the axis out of the preview's reach. |
| `lib/extensions/divine_video_clip_player_mapping.dart:16` (`toPlayerVideoClip`, editor preview) and `lib/services/video_editor/transition_seam_render_service.dart:747-760` (seam preview clips) | default `false` | Yes. These are segments of a multi-clip timeline, where the field's own dartdoc says the clamp would cut content rather than a seam. |
| `lib/screens/comments/widgets/video_comment_player.dart` and `lib/widgets/video_clip/video_clip_preview.dart` | `true` | Yes. Both loop one finished clip without a duration axis, so hiding a short track-end seam matches feed playback. |
| `lib/screens/video_editor/video_clip_chroma_key_screen.dart`, `lib/screens/video_editor/video_clip_transform_screen.dart`, `lib/widgets/video_editor/main_editor/video_editor_canvas.dart` (single-clip trim-drag preview) | default `false` | Yes. All three already pass an explicit `end` derived from `clip.duration`; recorded clips store their corrected common track end there. A second native clamp could shorten playback again and make the timeline endpoint unreachable. |
| `lib/screens/video_metadata/video_metadata_preview_screen.dart` and `lib/widgets/video_metadata/modes/classic/video_metadata_classic_preview_thumbnail.dart` | `true` | Yes. These loop the finished render without a duration axis and should use the same loop boundary as the feed that will play that file after publication. |
| `lib/widgets/video_editor/chroma_key/chroma_key_backdrop.dart` | default `false` | Yes. `ChromaKeyBakeService.backdropSegments` tiles the export using the backdrop's container duration. Clamping only the preview would move its loop boundary away from the exported result; the backdrop is muted, so an audio-shorter seam is inaudible. |
| `lib/screens/video_metadata/video_metadata_cover_screen.dart:124` | default `false` | Yes. The cover picker scrubs against the container duration returned by `getMetadata`, so clamping the player would make the end of that axis unreachable. |
| `lib/blocs/video_recorder/video_recorder_bloc.dart:1118`, `:1123` | default `false` | Yes. These calls only preload metadata and initial buffer data into the native cache; they do not create a looping playback surface. |

Platform support is per-backend and documented on the field: Apple and Android honour it for local and remote sources, web and Linux ignore it, and Android skips the probe entirely for HLS.

## What the record says, and what the code says

PR #6439's description frames its first, abandoned revision — which did pass `trimToCommonTrackEnd` into the native renderer — and then explains under "Why not fix this at export time" that the merged version does not. The merged diff touches five files (`video_recorder_bloc.dart`, `clip_manager_provider.dart`, `clip_media_duration.dart`, and their two tests) and contains no occurrence of `trimToCommonTrackEnd`.

So the premise shared by #7787, #7788 and #7789 — that `_concatenateSegments` passes the flag to its render callers — does not hold against `main`. `_concatenateSegments` has never passed it, and the flag those issues name belongs to the player, from #6430.
