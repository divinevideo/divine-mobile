# Video Editor Features

Status: Current
Validated against: `main` at `5b208c9911f347f78f82625d70036870ebbd550d` on 2026-09-26.

What a creator can do in the video editor today, grouped by area, with the limits that apply. Use it to answer "can the editor already do X?" before filing or building a feature, and update it in the same pull request that adds, removes, or changes an editor capability.

Numbers below come from the code. Most limits live in [`VideoEditorConstants`](../lib/constants/video_editor_constants.dart) and [`TimelineConstants`](../lib/constants/video_editor_timeline_constants.dart). A few sit next to the code that uses them: the split minimum in `VideoEditorSplitService`, and transition durations in the transition sheet. If this page and the code disagree, the code wins.

None of the editor tools sit behind a feature flag.

## Product constraints

These shape what the editor offers, and explain several things it deliberately does not do:

- **6.3 seconds maximum.** `VideoEditorConstants.maxDuration`. The timeline shades everything past it and the export truncates to it.
- **Camera-first.** There is no import from the camera roll. The recorder's Upload mode only explains why (ProofMode verification of camera-captured content). Both photo picks in the editor, a green-screen backdrop and the still that fills a detached clip's gap, open the camera, not the gallery.
- **No generative or ML effects.** Green screen is true chroma key by product decision; see issue [#8543](https://github.com/divinevideo/divine-mobile/issues/8543).
- **Two aspect ratios,** square and 9:16, chosen when recording. The editor has no control to change it.

## Getting into the editor

Recorder modes ([`VideoRecorderMode`](../lib/models/video_recorder/video_recorder_mode.dart)):

| Mode | Opens the editor | Notes |
|---|---|---|
| Capture | Yes | Default mode. |
| Stop Motion | Yes | Output must be at least 1 s. |
| Lip Sync | Yes | A sound is picked before recording; recorded clips are muted. |
| Classic | No | Square by default, has a recording limit, goes straight to the post screen and renders in the background. |
| Upload | No | Explainer screen only. |

The editor also opens from the drafts tab and from the in-app clip library (with one or more clips selected). Editing an already-published video opens the post details screen and its cover editor, not the timeline.

Drafts are stored in the local database. The editor saves the current session automatically into a single autosave slot and offers to restore it the next time the recorder opens. Creators can also save drafts explicitly, and a draft can be rendered for publishing without reopening the editor.

## Clips and timeline

Clip actions ([`video_editor_timeline_clip_controls.dart`](../lib/widgets/video_editor/timeline_editor/controls/video_editor_timeline_clip_controls.dart)):

- **Split** at the playhead. Minimum segment 30 ms.
- **Trim** with handles on each clip. Minimum length 60 ms.
- **Reorder** by long-press and drag.
- **Duplicate** (the copy lands right after the original) and **delete**. At least one clip always remains.
- **Merge** two or more clips into one, through multi-select.
- **Reverse**, as a toggle.
- **Speed** from 0.25× to 3.0× in 0.05 steps, on a slider.
- **Transform:** crop (locked to the video's aspect ratio), rotate by 90°, flip.
- **Extract audio:** moves the clip's sound to its own track and mutes the clip.
- **Save to library:** renders the trimmed clip, overlays included, into a standalone clip in the library.
- **Add clips** from the library or the camera.
- **Volume** per clip. Long-pressing any volume control mutes all clips and sound tracks, or unmutes them if everything is already muted.

Transitions between clips ([`video_editor_transition_sheet.dart`](../lib/widgets/video_editor/timeline_editor/controls/video_editor_transition_sheet.dart)):

- Dissolve, fade to black, fade to white, slide, push, wipe. Slide, push and wipe take a direction (left, right, up, down).
- Duration 10–2000 ms in 10 ms steps, further limited by how long the neighbouring clips are.
- 13 easing curves.
- A transition from the last clip back into the first, for the loop.

Detach (picture-in-picture):

- Lifts a clip off the timeline onto the canvas as a freely placed layer.
- The gap it leaves can be closed, or held with a solid color or a photo.
- A detached layer can be moved, resized, split, duplicated, deleted, cropped to any aspect ratio, and green-screened. It has no enter or leave animation.

Green screen (chroma key):

- Key color: auto-detect, green, blue, or a custom color.
- Controls for amount, edge softness and color spill.
- Background on a timeline clip: transparent (black in the exported video), a color, a camera photo, or a library clip. On a detached layer, transparent shows whatever is underneath, and a library clip is not offered.
- On a timeline clip the key is baked into the clip; on a detached layer it is applied live.

Timeline:

- Pinch to zoom, from 1 to 600 pixels per second (2400 for stop motion).
- Markers at the playhead; they move with clip edits.
- Undo and redo.
- Overlay items snap to clip edges, markers and the playhead, with haptic feedback. Clip trims do not snap.

## Stop motion

- Each still is held for 1–300 output frames at 30 fps.
- Stills can be reordered, deleted, duplicated and cropped, rotated or flipped.
- Multi-select can delete, duplicate, reverse, or set the hold for a block of stills.
- Sound tracks play in sync with the preview.

## Overlay layers

Every overlay below sits on the timeline, where it can be moved, trimmed to show for only part of the video, split, duplicated and deleted.

- **Text:** 79 fonts (`VideoEditorConstants.textFontCatalogue`), left, center or right alignment, four background modes (none, solid, highlight, transparent), 11 preset colors plus a custom picker with recent colors, size from 0.5× to 4×. Saved title styles keep font, colors, background, alignment, size and animations; names are up to 40 characters.
- **Drawing:** pencil, marker, arrow and eraser, each with a fixed width. Undo and redo inside the tool. Several drawing layers can be merged into one.
- **Stickers:** 71 bundled OpenMoji stickers, searchable by keyword and by their localized names.
- **Filters:** 56 looks plus "None" (40 classic presets, 8 styled looks, 8 color tints), picked one at a time with a strength slider. Each confirmed filter is kept, so several can stack.
- **Adjustments:** brightness, contrast, saturation, exposure, hue, temperature, tint and fade. One adjustment session shares a single time window on the timeline.

Enter and leave animations, per layer:

- Fade, slide and scale, combinable within each phase.
- Duration 10–2000 ms in 10 ms steps; the 13 easing curves.
- Slide from any edge or from a custom point tapped on the canvas. The layer moves in a straight line; there are no multi-point paths or keyframes.

## Captions

- **Auto captions:** the audio is transcribed on Divine's server first, with a fallback to the platform's speech recognition: Apple's on iOS, which runs on the device when it supports the language and on Apple's servers otherwise; Android 14 or later with language packs installed, on the device. Clip audio is transcribed; music and voice-over are not. The language is the app's language.
- **Editing:** change a caption's text and timing, add and remove captions. Minimum caption length 200 ms. Captions can be typed by hand when recognition finds nothing.
- **Styles:** 20 presets, a custom style (font, text color, background, animation: none, fade, pop or spring), and saved caption styles.
- **Output:** burning captions into the picture is optional. The app also publishes them as a separate subtitle track, best effort: if that upload fails or times out, the video is published without it.
- **After publishing,** the subtitle editor lets the author fix the text and timing of a published video's captions.

## Audio

- **Sound picker tabs:** Divine (bundled classic Vine sounds), Community (sounds other creators published), Featured, and My Sounds (saved sounds).
- **Import** of `aac`, `m4a`, `mp3` and `wav` files from the device.
- **Several sound tracks at once.** Adding a sound adds a track rather than replacing the previous one. Each track can be moved and trimmed, and its start point inside the sound chosen.
- **Voice-over:** records takes over the muted preview. Takes are placed one after another; the last take can be deleted.
- **Volume** per clip and per sound track, from silent to 100 %.
- **Waveforms** on clips and sound tracks, and live while recording a voice-over.
- Creators choose whether others may reuse the audio of their published video.

## Export

- 1080p at 8 Mbps. If the encoder fails, the render retries at 720p and 4 Mbps.
- ProofMode signing, which can be retried if it fails.
- One progress indicator for render, stop-motion assembly and signing, with cancel. A watchdog stops a render after 5 minutes.
- Cover image picked from a frame of the video.
- A preview of the post as it will look in the feed.
- Save the finished video to the device.

## Requested or planned

Open feature requests for things the editor does not do yet:

- Audio: fade in and out ([#9557](https://github.com/divinevideo/divine-mobile/issues/9557)), voice effects and noise reduction for voice-overs ([#9565](https://github.com/divinevideo/divine-mobile/issues/9565)), volume above 100 % ([#4906](https://github.com/divinevideo/divine-mobile/issues/4906)), loudness equalization ([#3789](https://github.com/divinevideo/divine-mobile/issues/3789)), a larger sound library ([#8338](https://github.com/divinevideo/divine-mobile/issues/8338)).
- Text and captions: outline and shadow ([#9558](https://github.com/divinevideo/divine-mobile/issues/9558)), word-by-word highlighted captions ([#9564](https://github.com/divinevideo/divine-mobile/issues/9564)), a link in the text overlay ([#3111](https://github.com/divinevideo/divine-mobile/issues/3111)).
- Clips: speed presets ([#9559](https://github.com/divinevideo/divine-mobile/issues/9559)), freeze frame ([#9561](https://github.com/divinevideo/divine-mobile/issues/9561)), zoom over time ([#4951](https://github.com/divinevideo/divine-mobile/issues/4951)).
- Detach: move a detached clip back into the timeline ([#9560](https://github.com/divinevideo/divine-mobile/issues/9560)), opacity ([#9563](https://github.com/divinevideo/divine-mobile/issues/9563)).
- Privacy: blur or pixelate part of the picture ([#9562](https://github.com/divinevideo/divine-mobile/issues/9562)).
- Stickers: NIP-30 stickers ([#2265](https://github.com/divinevideo/divine-mobile/issues/2265)).
- Frames around the video ([#7099](https://github.com/divinevideo/divine-mobile/issues/7099)).

## Deliberately not supported

- Importing videos or photos from the camera roll (camera-first, ProofMode).
- ML background removal and generative effects ([#8543](https://github.com/divinevideo/divine-mobile/issues/8543)).
- Landscape (16:9), 4K export, and a choice of frame rate or codec.
