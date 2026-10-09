# Video Editor Features

Status: Current
Validated against: `main` at `ea87468a621d7e824f8feab2c1b1f5482aab0005` on 2026-10-05.

What a creator can do in the video editor today, grouped by area, with the limits that apply. Use it to answer "can the editor already do X?" before filing or building a feature, and update it in the same pull request that adds, removes, or changes an editor capability.

Numbers below come from the code. Most limits live in [`VideoEditorConstants`](../lib/constants/video_editor_constants.dart) and [`TimelineConstants`](../lib/constants/video_editor_timeline_constants.dart). A few sit next to the code that uses them: the split minimum in `VideoEditorSplitService`, and transition durations in the transition sheet. If this page and the code disagree, the code wins.

None of the editor tools sit behind a feature flag.

## Product constraints

These shape what the editor offers, and explain several things it deliberately does not do:

- **6.3 seconds maximum.** `VideoEditorConstants.maxDuration`. The timeline shades everything past it and the export truncates to it.
- **Camera-first.** There is no import from the camera roll. The recorder's Upload mode only explains why (ProofMode verification of camera-captured content). Both photo picks in the editor, a color mask backdrop and the still that fills a detached clip's gap, open the camera, not the gallery.
- **No generative or ML effects.** The color mask (shown to creators as "Color mask", formerly "Green screen") is a true chroma key, not background segmentation; the name is settled, and the decision to stay a chroma key is recorded, pending ratification, in issue [#8543](https://github.com/divinevideo/divine-mobile/issues/8543).
- **Two aspect ratios,** square and 9:16, chosen when recording. The editor has no control to change it.

## Getting into the editor

Recorder modes ([`VideoRecorderMode`](../lib/models/video_recorder/video_recorder_mode.dart)):

| Mode | Opens the editor | Notes |
|---|---|---|
| Capture | Yes | Default mode. |
| Stop Motion | Yes | Output must be at least 1 s. |
| Lip Sync | Yes | A sound is picked before recording; recorded clips are muted. |
| Color mask | Yes | The viewfinder shows the swapped background live while recording; each take is keyed right after recording. Only offered on devices whose renderer can draw the live key. |
| Classic | No | Square by default, has a recording limit, goes straight to the post screen and renders in the background. |
| Upload | No | Explainer screen only. |

The editor also opens from the drafts tab and from the in-app clip library (with one or more clips selected). Editing an already-published video opens the post details screen and its cover editor, not the timeline.

Drafts are stored in the local database. The editor saves the current session automatically into a single autosave slot and offers to restore it the next time the recorder opens. Creators can also save drafts explicitly, and a draft can be rendered for publishing without reopening the editor.

## Clips and timeline

Clip actions ([`video_editor_timeline_clip_controls.dart`](../lib/widgets/video_editor/timeline_editor/controls/video_editor_timeline_clip_controls.dart)):

- **Split** at the playhead. Minimum segment 30 ms.
- **Freeze** the frame under the playhead: the clip is cut there and a still of that frame holds for 0.5 s before the clip continues. On a clip's first or last frame the still goes in front of or after the clip instead. Its trim handles set how long it holds, up to 6.3 s. The clip's own sound pauses during the freeze; music and voice-over keep playing. The freeze counts toward the 6.3 s maximum.
- **Trim** with handles on each clip. Minimum length 60 ms.
- **Reorder** by long-press and drag.
- **Duplicate** (the copy lands right after the original) and **delete**. At least one clip always remains.
- **Merge** two or more clips into one, through multi-select.
- **Reverse**, as a toggle.
- **Speed** from 0.25× to 3.0× in 0.05 steps, on a slider, with one-tap presets for 0.25×, 0.5×, 1×, 1.5×, 2× and 3×.
- **Transform:** crop (locked to the video's aspect ratio), rotate by 90°, flip.
- **Extract audio:** moves the clip's sound to its own track and mutes the clip.
- **Save to library:** renders the trimmed clip, with the visual overlays that were over it, into a standalone clip in the library. Flashing effects and every sound track (music, voice-over, extracted audio) are left out, so a clip whose sound was extracted is saved silent.
- **Add clips** from the library or the camera.
- **Volume** per clip, up to 300 % (see [Audio](#audio)). Long-pressing any volume control mutes all clips and sound tracks, or unmutes them if everything is already muted.

Transitions between clips ([`video_editor_transition_sheet.dart`](../lib/widgets/video_editor/timeline_editor/controls/video_editor_transition_sheet.dart)):

- Dissolve, fade to black, fade to white, slide, push, wipe. Slide, push and wipe take a direction (left, right, up, down).
- Duration 10–2000 ms in 10 ms steps, further limited by how long the neighbouring clips are.
- 13 easing curves.
- A transition from the last clip back into the first, for the loop.

Detach (picture-in-picture):

- Lifts a clip off the timeline onto the canvas as a freely placed layer.
- The gap it leaves can be closed, or held with a solid color or a photo.
- A detached layer can be moved, resized and rotated on the canvas, split, duplicated, deleted, cropped to any aspect ratio, turned by 90° or flipped (Transform), made see-through (opacity 0–100 %), moved with keyframes, and color-masked. It has no enter or leave animation.
- Back to timeline puts the clip back as a timeline clip, into the color or photo slot it left if that is still there. Otherwise it goes in at the playhead: at the clip boundary under it, or right after the clip the playhead is inside. Only the part its layer showed comes back, as trim. Its placement, opacity and live color mask stay behind, a free crop fills the frame, and its length counts toward the 6.3 s maximum again.

Color mask (chroma key, formerly "Green screen"):

- Key color: auto-detect, green, blue, or a custom color. A plain white wall can be keyed too: for a neutral key the matte also weighs brightness, so a white key does not also remove black and grey. The wall has to be evenly lit: a shadow on it survives the mask.
- Controls for amount, edge softness and color spill.
- Background on a timeline clip: transparent (black in the exported video), a color, a camera photo, or a library clip. On a detached layer, transparent shows whatever is underneath, and a library clip is not offered.
- On a timeline clip the key is baked into the clip; on a detached layer it is applied live.

Timeline:

- Pinch to zoom, from 1 to 600 pixels per second (2400 for stop motion).
- Dragging the playhead past either end wraps around to the other, so the loop restart can be scrubbed across.
- Clip and overlay actions appear as labelled tiles in a bar at the bottom of the timeline.
- Markers at the playhead; they move with clip edits.
- Undo and redo.
- Overlay items snap to clip edges, markers and the playhead, with haptic feedback. Clip trims do not snap.

## Stop motion

- Each still is held for 1–300 output frames at 30 fps.
- Stills can be reordered, deleted, duplicated and cropped, rotated or flipped.
- Multi-select can delete, duplicate, reverse, or set the hold for a block of stills.
- Sound tracks play in sync with the preview.

## Overlay layers

Every overlay below sits on the timeline, where it can be moved, trimmed to show for only part of the video, split, duplicated and deleted. Text, stickers and drawings can also be made see-through (opacity 0–100 %).

- **Text:** 128 fonts (`VideoEditorConstants.textFontCatalogue`) grouped by style in the picker, left, center or right alignment, four background modes (none, solid, highlight, transparent), 11 preset colors plus a custom picker with recent colors, an outline and a drop shadow (each with its own color and a strength slider, off at the far left). Size is set by pinching the text on the canvas, and lines wrap at the visible edges of the video instead of running off them. Saved title styles keep font, colors, background, alignment, outline, shadow and animations, but not the pinch scale, position or rotation of the layer it came from (a style saved before the text size slider was removed in #9779 can still carry a font size); names are up to 40 characters.
- **Drawing:** pencil, marker, arrow and eraser, each with a fixed width. Undo and redo inside the tool. Several drawing layers can be merged into one.
- **Stickers:** 71 bundled OpenMoji stickers, searchable by keyword and by their localized names.
- **Filters:** 56 looks plus "None" (40 classic presets, 8 styled looks, 8 color tints), picked one at a time with a strength slider. Each confirmed filter is kept, so several can stack.
- **Effects:** 21 timeline effects, each with an intensity slider: glitch, block glitch, RGB split, VHS, static, old film, film grain, interference, CRT, pixelate, pixel pulse, shake, zoom pulse, mirror, kaleidoscope, split screen, wave, glow, vignette, strobe and negative flash. A new effect covers the whole video; on the timeline it is a bar that can be moved, trimmed, edited, split, duplicated and deleted, and overlapping effects combine. A flashing effect (strobe or negative flash) starts on a whole second of the exported video (an effect with no whole second before its end is left out of the export); when the video already flashes from its first frame, flashing also stops on the last whole second before the video loops, so the flashes on both sides of the loop point stay within three a second. A flashing effect cannot be duplicated, and only one of them can run at a time, because overlapping ones would pass three flashes a second. Adding one removes every other flashing effect, since a new effect covers the whole video; moving, trimming or editing one cuts the others out of its window instead, shortening or splitting them (pieces under 100 ms are dropped). A video that uses either at an intensity above zero is published with the Flashing Lights content warning, locked on in the metadata screen until the video is posted; editing the published video later treats it as an ordinary label that can be removed. Effects with a clear hit (zoom pulse, pixel pulse, RGB split, glitch, block glitch, shake, strobe and negative flash) have an **On the beat** switch: the effect then fires once on every beat of the video's music instead of playing all through its window — the first sound on the timeline that is not a voice-over, or else the clips' own sound. The beats are found on the device, when an effect first needs them, where the sound gets clearly louder in its bass, mids or highs and stays louder for a moment: drums, words and bangs fire, crackle does not, and a hit right after a much stronger one fades into it and fires nothing. They move with the sound and the clips. A flashing effect on the beat flashes once per beat, skips beats less than a third of a second apart (so it flashes on every other beat of a very fast song), and drops any beat that would put more than three flashes in one second of the looping video. The bar on the timeline says "on the beat", and saving a clip to the library leaves effects on the beat out, since the clip does not take the music along.
- **Adjustments:** brightness, contrast, saturation, exposure, hue, temperature, tint and fade. One adjustment session shares a single time window on the timeline.

Enter, leave and loop animations, per layer:

- Enter and leave: fade, slide, scale, bounce and wiggle, combinable within each phase. Text layers can also type themselves out letter by letter (typewriter) or word by word, and take themselves away the same way; spaces take no step, and the text's background grows with the revealed part.
- Loop, repeated for as long as the layer is visible: wiggle, bounce (a hop) and pulse.
- Duration 10–2000 ms in 10 ms steps, one loop cycle 200–2000 ms; the 13 easing curves. Wiggle tilts 2–30°, bounce lifts by 10–200 % of the layer's height, pulse shrinks to 0–100 % of its size.
- Slide from any edge or from a custom point tapped on the canvas. The layer moves in a straight line; a path through several points is made with keyframes.

Keyframes, per layer (text, sticker, drawing and detached clip):

- The Keyframes button in a selected layer's bar opens a sheet with a one-line explanation and a button that adds a keyframe at the playhead, holding the layer where the canvas shows it, or removes the one there. The sheet's changes show on the canvas right away and are one undo step: the check mark or swiping the sheet away keeps them, the cross takes them back. The button's diamond fills in while the playhead is on a keyframe.
- Once a layer has a keyframe, moving, resizing or rotating it on the canvas sets a keyframe at the playhead: it changes the one there, or adds one.
- On a keyframe, the sheet sets the layer's opacity there, so it fades from one keyframe to the next.
- Between two keyframes the layer moves along one of the 13 easing curves, linear by default, and can play a wiggle, a hop or a pulse on the way, with its strength; the sheet edits the stretch the playhead is in and names its two keyframes. The effect's cycle is fitted so the layer rests on both keyframes. A detached clip offers no effect, as it has no animations. Before the first keyframe and after the last one the layer holds still.
- A layer's timeline bar shows its keyframes on its bottom edge: as yellow diamonds while it is selected, the one at the playhead filled in, and tapping one moves the playhead onto it; as small marks otherwise.
- Trimming the layer's start, splitting it or duplicating it keeps the motion where it was on the video. A detached clip's footage moves along when its start is trimmed, and its motion goes with the footage. Removing the last keyframe leaves the layer where it showed at the playhead.
- Enter, leave and loop animations play on top of the keyframed motion, and the export moves the layer as the canvas does, through clip transitions too.

## Captions

- **Auto captions:** the audio is transcribed on Divine's server first, with a fallback to the platform's speech recognition: Apple's on iOS, which runs on the device when it supports the language and on Apple's servers otherwise; Android 14 or later with language packs installed, on the device. Clip audio is transcribed; music and voice-over are not. The language is the app's language.
- **Editing:** change a caption's text and timing, add and remove captions. Minimum caption length 200 ms. Captions can be typed by hand when recognition finds nothing.
- **Styles:** 21 presets, a custom style (font, text color, background, outline and shadow, animation: none, fade, pop, spring or karaoke), and saved caption styles, picked with a button that appears once "Burn into video" is on.
- **Word highlight:** the karaoke animation, also a built-in preset, lights each word in a highlight color as it is spoken. Word timings come from the recognizer; for Divine's server, which only times whole cues, they are spread by word length. The published subtitle track stays cue-level.
- **Output:** burning captions into the picture is optional. The app also publishes them as a separate subtitle track, best effort: if that upload fails or times out, the video is published without it.
- **After publishing,** the subtitle editor lets the author fix the text and timing of a published video's captions.

## Audio

- **Sound picker tabs:** Divine (bundled classic Vine sounds), Community (sounds other creators published), Featured, and My Sounds (saved sounds).
- **Import** of `aac`, `m4a`, `mp3` and `wav` files from the device.
- **Several sound tracks at once.** Adding a sound adds a track rather than replacing the previous one. Each track can be moved and trimmed, and its start point inside the sound chosen.
- **Voice-over:** records takes over the muted preview. Takes are placed one after another; the last take can be deleted.
- **Volume** per clip and per sound track, from silent to 300 %. The timeline arc turns orange above 100 % and red above 200 %. Boosted audio is limited at −1 dBFS in the export, and the Android preview limits at the same ceiling; the iOS preview plays the boost without a limiter.
- **Fade in and out** per sound track, in 100 ms steps. The envelope is linear, and the preview plays the same one the export bakes in.
- **Voice effects and noise reduction** on any sound track, not only voice-overs (a clip's own sound needs Extract audio first): one-tap presets (original, high pitch, low pitch, robot, echo) or sliders for pitch (−12 to +12 semitones), robot (0–100 %) and echo (0–100 %), plus a noise reduction toggle. Settings loop while the sheet is open and are processed offline when confirmed. Processing downmixes the track to mono. The track keeps the original, so the effect can be changed or removed later.
- **Waveforms** on clips and sound tracks, and live while recording a voice-over.
- Creators choose whether others may reuse the audio of their published video.

## Export

- 1080p at 8 Mbps. If the encoder fails, the render retries at 720p and 4 Mbps.
- ProofMode signing, which can be retried if it fails.
- One progress indicator for render, stop-motion assembly and signing, with a retry if it fails. A watchdog stops a render after 5 minutes.
- Cover image picked from a frame of the video.
- A preview of the post as it will look in the feed.
- Save the finished video to the device.

## Requested or planned

Open feature requests for things the editor does not do yet:

- Audio: loudness equalization ([#3789](https://github.com/divinevideo/divine-mobile/issues/3789)), an equalizer for bass and treble ([#9850](https://github.com/divinevideo/divine-mobile/issues/9850)), an audio visualizer overlay ([#9851](https://github.com/divinevideo/divine-mobile/issues/9851)), a larger sound library ([#8338](https://github.com/divinevideo/divine-mobile/issues/8338)).
- Text: a link in the text overlay ([#3111](https://github.com/divinevideo/divine-mobile/issues/3111)).
- Clips: a ping-pong (boomerang) loop ([#9852](https://github.com/divinevideo/divine-mobile/issues/9852)), timeline-based zoom controls ([#4951](https://github.com/divinevideo/divine-mobile/issues/4951)), ghost mode for smoother transitions and loops ([#9573](https://github.com/divinevideo/divine-mobile/issues/9573)), a smoother jump when the video loops back to its start ([#9587](https://github.com/divinevideo/divine-mobile/issues/9587)).
- Effects: an echo trail effect ([#9708](https://github.com/divinevideo/divine-mobile/issues/9708)), effects that fire on the beat of the music ([#9710](https://github.com/divinevideo/divine-mobile/issues/9710)).
- Layers: masks that show a clip or layer in a shape or gradient ([#9846](https://github.com/divinevideo/divine-mobile/issues/9846)).
- Motion analysis (touches the no-ML decision in [#8543](https://github.com/divinevideo/divine-mobile/issues/8543)): video stabilization ([#9847](https://github.com/divinevideo/divine-mobile/issues/9847)), text and stickers that follow a moving object ([#9848](https://github.com/divinevideo/divine-mobile/issues/9848)).
- Privacy: blur or pixelate part of the picture ([#9562](https://github.com/divinevideo/divine-mobile/issues/9562)).
- Stickers: NIP-30 stickers ([#2265](https://github.com/divinevideo/divine-mobile/issues/2265)).
- Frames around the video ([#7099](https://github.com/divinevideo/divine-mobile/issues/7099)).

## Deliberately not supported

- Importing videos or photos from the camera roll (camera-first, ProofMode).
- ML background removal and generative effects ([#8543](https://github.com/divinevideo/divine-mobile/issues/8543)).
- Landscape (16:9), 4K export, and a choice of frame rate or codec.
