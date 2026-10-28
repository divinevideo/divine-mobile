# Video Editor Features

Status: Current
Validated against: `main` at `afaab2772768496353b2cc93d1d08a11cf1d369e` on 2026-10-28.

What a creator can do in the video editor today, grouped by area, with the limits that apply. Use it to answer "can the editor already do X?" before filing or building a feature, and update it in the same pull request that adds, removes, or changes an editor capability.

Numbers below come from the code. Most limits live in [`VideoEditorConstants`](../lib/constants/video_editor_constants.dart) and [`TimelineConstants`](../lib/constants/video_editor_timeline_constants.dart). A few sit next to the code that uses them: the split minimum in `VideoEditorSplitService`, and transition durations in the transition sheet. If this page and the code disagree, the code wins.

None of the editor tools sit behind a feature flag.

## Product constraints

These shape what the editor offers, and explain several things it deliberately does not do:

- **6.3 seconds maximum.** `VideoEditorConstants.maxDuration`. The timeline shades everything past it and the export truncates to it.
- **Camera-first.** Only footage recorded with the Divine camera gets in. The clip library can bring clips back from the device gallery (Android and iOS) and add clips friends send in direct messages, but each one first passes an on-device C2PA check that its history leads back to Divine camera recordings; any other video or photo from the camera roll stays out. The recorder's Upload mode only explains why (ProofMode verification of camera-captured content). Both photo picks in the editor, a color mask backdrop and the still that fills a detached clip's gap, open the camera, not the gallery.
- **No generative or ML effects.** The color mask (shown to creators as "Color mask", formerly "Green screen") is a true chroma key, not background segmentation; the name is settled, and the decision to stay a chroma key was confirmed when issue [#8543](https://github.com/divinevideo/divine-mobile/issues/8543) closed on 2026-10-19. Stabilize measures camera shake with classical motion analysis, not an ML model.
- **Two aspect ratios,** square and 9:16, chosen when recording. The editor has no control to change it.

## Getting into the editor

Recorder modes ([`VideoRecorderMode`](../lib/models/video_recorder/video_recorder_mode.dart)):

| Mode | Opens the editor | Notes |
|---|---|---|
| Capture | Yes | Default mode. |
| Stop Motion | Yes | Output must be at least 1 s. |
| Lip Sync | Yes | Opens on the sound list; the camera appears once a sound is picked. Recorded clips are muted. |
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
- **Merge** two or more clips into one, through multi-select, which can also turn neighbouring clips into one boomerang, paste a copied style onto the selected clips or delete them.
- **Reverse**, as a toggle. Not offered on a boomerang.
- **Boomerang**, as a toggle: the clip plays forward and then backward; tapping again puts the original back. Footage that plays longer than half of 6.3 s is refused, since the way back would be cut off.
- **Stabilize**, as a toggle: one tap measures the camera shake and bakes the steadied footage into the clip; tapping again restores the original. If the original footage is no longer on the device, the clip stays stabilized and the editor says so rather than offering a retry. It hides the borders only by zooming in, at most 1.15× (`VideoEditorConstants.stabilizationMaxZoom`), so where a clip would need more, some shake stays. A clip with a color mask is steadied from the footage under the key and keyed again.
- **Speed** from 0.25× to 3.0× in 0.05 steps, on a slider, with one-tap presets for 0.25×, 0.5×, 1×, 1.5×, 2× and 3×. A **Curve** mode lets the clip speed up and slow down while it plays: the presets Montage, Hero, Bullet, Flash in and Flash out, or a custom curve with five points, each from 0.25× to 3×. Under a curve the clip's sound follows the speed like a tape, so its pitch rises and falls with it.
- **Keyframes:** pan, zoom and turn the clip over time (also on freeze frames). Dragging, pinching and turning the picture sets a keyframe at the playhead, and each stretch between two keyframes takes one of the 13 easing curves. The zoom stays at 1× or more, and a picture that is not turned cannot be moved off the frame; a turned one shows black where it leaves the frame uncovered. The motion stays on its frames through trimming, splitting, duplicating, speed changes, reverse and boomerang. Detaching the clip drops these keyframes; a detached clip has its own (see Keyframes under Overlay layers).
- **Transform:** crop (locked to the video's aspect ratio), rotate by 90°, flip.
- **Shape mask:** show the clip only inside a shape (see Shape mask below). Freeze frames take one too.
- **Extract audio:** moves the clip's sound to its own track and mutes the clip.
- **Save to library:** renders the trimmed clip, with the visual overlays that were over it, into a standalone clip in the library. Flashing effects and every sound track (music, voice-over, extracted audio) are left out, so a clip whose sound was extracted is saved silent.
- **Add clips** from the library or the camera.
- **Volume** per clip, up to 300 % (see [Audio](#audio)). Long-pressing any volume control mutes all clips and sound tracks, or unmutes them if everything is already muted.
- **EQ:** ten octave bands of the clip's own sound (see [Audio](#audio)). Extract audio carries the setting over to the new sound track.
- **Copy style / Paste style:** Copy style takes a clip's volume, EQ, speed (a constant speed or a speed curve), color mask and shape mask with its background color; Paste style puts them on the selected clip or, through multi-select, on several clips at once, as one undo step. Pasting makes the target match, so a style copied from a clip without a color mask takes the target's away. A color mask is rendered into each target in turn behind a progress overlay; a clip whose color mask cannot be changed keeps its own, takes the rest, and a message says so. Filters and adjustments are not part of it: they are timeline bars that can span several clips. Copy style is not offered on a freeze frame, a color or photo slot or a stop-motion clip, and a freeze frame takes only the shape mask. The copied style lasts while the editor is open.

Transitions between clips ([`video_editor_transition_sheet.dart`](../lib/widgets/video_editor/timeline_editor/controls/video_editor_transition_sheet.dart)):

- Dissolve, fade to black, fade to white, slide, push, wipe, zoom in, zoom out, spin, whip pan, blur, glitch, flash, iris, stretch, light leak, clock wipe, diagonal wipe, flip, cube. Slide, push, wipe, whip pan, stretch, flip and cube take a direction (left, right, up, down); a diagonal wipe takes the corner it travels toward (up and left, up and right, down and left, down and right).
- Duration 10–2000 ms in 10 ms steps, further limited by how long the neighbouring clips are.
- 13 easing curves.
- A transition from the last clip back into the first, for the loop.
- A flash or light leak less than a second from another one on the looping video plays as a dissolve, and the picker says so. Flashing effects on the beat skip the beats next to a flash, so the video never flashes more than three times a second.
- Across every transition but the fades to black and white the two clips' sounds cross-fade, each at its own volume and EQ.

Detach (picture-in-picture):

- Lifts a clip off the timeline onto the canvas as a freely placed layer.
- The gap it leaves can be closed, or held with a solid color or a photo.
- A detached layer can be moved, resized and rotated on the canvas, split, duplicated, deleted, cropped to any aspect ratio, turned by 90° or flipped (Transform), made see-through (opacity 0–100 %), given a blend mode (see Blend modes under Overlay layers), moved with keyframes, color-masked and shape-masked. It has no enter or leave animation. A clip detached with a shape mask takes the mask onto its layer.
- Back to timeline puts the clip back as a timeline clip, into the color or photo slot it left if that is still there. Otherwise it goes in at the playhead: at the clip boundary under it, or right after the clip the playhead is inside. Only the part its layer showed comes back, as trim. Its placement, opacity, live color mask and shape mask stay behind, a free crop fills the frame, and its length counts toward the 6.3 s maximum again.
- There is no fixed limit on detached clips, but the export decodes all of them at once, so a device runs out of video decoders at some number. When Android reports this decoder limit, the post screen asks to put a few back on the timeline; the retry button remains available.

Color mask (chroma key, formerly "Green screen"):

- Key color: auto-detect, green, blue, or a custom color. A plain white wall can be keyed too: for a neutral key the matte also weighs brightness, so a white key does not also remove black and grey. The wall has to be evenly lit: a shadow on it survives the mask.
- Controls for amount, edge softness and color spill.
- Background on a timeline clip: transparent (black in the exported video), a color, a camera photo, or a library clip. On a detached layer, transparent shows whatever is underneath, and a library clip is not offered.
- On a timeline clip the key is baked into the clip; on a detached layer it is applied live.

Shape mask:

- Shows a timeline clip, a detached clip, a text, a sticker or a drawing only inside a circle (stretchable into an oval), a rectangle with rounded corners, a heart, a star, a triangle, a diamond, a hexagon or a speech bubble, or on one side of a straight line (linear). Not offered for a blurred or pixelated area or an audio visualizer, which the export draws from their own settings.
- The mask is shaped in a full-screen editor over the paused video: one finger moves it, two resize and turn it, and the handles on its right and bottom sides stretch it. None of these can take it off its item: a move stops at the item's edge, a pinch that grows it against an edge pushes it away from that edge, and a handle stops where the shape touches one. Softness fades its edge over up to half the item's shorter side, so a soft linear mask fades the item out; corners round the rectangle; invert shows the item outside the shape instead. The change is one undo step, and cancelling leaves the item as it was.
- It moves, scales and turns with its item, keyframes included.
- Keyframes of its own (the diamond in the mask editor's top bar) move, resize, turn and soften the shape over time, independent of its item, so it can open up on a face, wipe across to reveal a second clip or drift like a spotlight. A keyframe holds the shape as it is at the playhead; once the mask has keyframes, changing the shape at another playhead position adds or changes the keyframe there, and the change from one keyframe to the next eases along any of the 13 curves. The shape, its corners and the inversion stay the same throughout. Mask keyframes show as diamonds along the top edge of the item's timeline bar, the item's own along the bottom, and they keep the motion where it is on the item through trimming its start, splitting, duplicating and pasting its style; a freeze frame holds the mask as it was at that frame. The export draws a moving mask on every frame, with the same shapes as the preview.
- On a timeline clip, what the mask hides is covered with a color, black unless the mask editor's Background row picks another one, the same in the preview and the export; across every transition but the fades to black and white the cover fades with the clip. On a detached clip or an overlay, it shows what lies underneath.
- A masked sticker or drawing is not combined with others, since the combined layer would carry one mask at most.

Layout (split screen), from the editing tools (not for stop motion):

- 14 layouts with two to four cells: two side by side, two stacked, three columns, three rows, one over two, two over one, one beside two, two beside one, a 2×2 grid, one over three, and picture-in-picture with the small window in any of the four corners.
- Each cell is filled from the library or the camera, which show the cell's crop while picking. Inside its cell a clip can be dragged to pick the part that shows and zoomed in up to 4×. A gap between the cells and a border color are optional.
- Done renders the layout into one clip on the timeline, right after the clip under the playhead, or at the seam when the playhead is on one. A cell shorter than the longest holds its last frame until the layout ends. As one clip, the layout trims, splits, reorders and takes transitions like any other; it cannot be rearranged cell by cell afterwards.

Align loop, from the editing tools (loop repair supports Android, iOS and macOS):

- Measures the jump between the video's last frame and its first, and when it finds a clear mismatch, corrects the framing so the loop joins smoothly, zooming in at most 1.08×; only where that cannot help does it trim instead, by up to 200 ms. It then plays the join and offers Undo; a scene it is not sure about stays unchanged.
- The Loop button remains visible for unsupported compositions and platforms; tapping it leaves the video unchanged and says "Couldn't improve this loop". Repair declines clips with a transition, a speed curve, a shape mask, keyframes, an applied or pending color mask, a freeze frame, stop-motion frames, a color or photo slot, or less than the minimum trim duration of playable footage. It also declines a composition with a keyframed or detached layer on the canvas.

Timeline:

- Pinch to zoom, from 1 to 600 pixels per second (2400 for stop motion).
- Dragging the playhead past either end wraps around to the other, so the loop restart can be scrubbed across.
- Clip and overlay actions appear as labelled tiles in a bar at the bottom of the timeline.
- Markers at the playhead; they move with clip edits.
- Undo and redo.
- Overlay items snap to clip edges, markers, the playhead and the start and end of other overlay items, with haptic feedback. Clip trims snap to the playhead.

## Stop motion

- Each still is held for 1–300 output frames at 30 fps.
- Stills can be reordered, deleted, duplicated and cropped, rotated or flipped.
- Multi-select can delete, duplicate, reverse, or set the hold for a block of stills.
- Sound tracks play in sync with the preview.

## Overlay layers

Every overlay below sits on the timeline, where it can be moved, trimmed to show for only part of the video, split, duplicated and deleted. Text, stickers, drawings and audio visualizers can also be made see-through (opacity 0–100 %).

Blend modes: text, stickers, drawings, audio visualizers and detached clips can blend with what lies beneath them instead of covering it, through normal, multiply, screen, overlay, soft light, darken, lighten, add or difference. A hidden area takes none.

Copy style and Paste style work on texts, stickers, drawings and audio visualizers. Copy style takes a layer's opacity, its blend mode, its enter, leave and loop animations and its shape mask, and for a text also its look: font, colors or gradient, background, alignment, size, outline and shadow. Paste style puts it on the selected layer or, through multi-select, on several at once, as one undo step, and makes the target match. Each layer takes what fits: a sticker takes a text's animations but not its look or its letter-by-letter and word-by-word typing, an audio visualizer takes no mask, and a layer with keyframes keeps the opacity its keyframes set. A shape mask keeps its proportions on a differently shaped layer. Hidden areas and detached clips take no style. Multi-select selects any of these layers to paste a style onto or delete; Combine is offered when the selection is two or more drawings, or two or more stickers, none of them animated, keyframed, masked, blended or trimmed. The copied style lasts while the editor is open.

- **Text:** 128 fonts (`VideoEditorConstants.textFontCatalogue`) grouped by style in the picker, left, center or right alignment, four background modes (none, solid, highlight, transparent), 11 preset colors plus a custom picker with recent colors, or a gradient fill of 2 to 6 colors (six ready-made gradients, eight directions), an outline and a drop shadow (each with its own color and a strength slider, off at the far left). Size is set by pinching the text on the canvas, and lines wrap at the visible edges of the video instead of running off them; a "Don't wrap" chip, shown while the edges wrap a text or it runs past them, lets a large title run past the edges instead. Saved title styles keep font, colors or gradient, background, alignment, outline, shadow and animations, but not the pinch scale, position or rotation of the layer it came from (a style saved before the text size slider was removed in #9779 can still carry a font size); names are up to 40 characters.
- **Drawing:** pencil, marker, arrow and eraser. A slider sets the brush size from 2 to 40 logical pixels, and each tool keeps its own size; while the slider is dragged, a dot in the middle of the video shows how thick the next stroke will be. Undo and redo inside the tool. Several drawing layers can be merged into one.
- **Censor (blur or pixelate):** the Censor action opens the drawing tools with blur and pixelate; dragging over the video hides that area, and a slider sets how strongly each area hides it, from a quarter to four times the default. Pixelate is only offered where the renderer supports shader image filters (Impeller, not Skia). Each area is its own layer. It cannot be made see-through, animated or keyframed, since any of these could show for a moment what it hides, and it takes no shape mask. The export blurs or pixelates what lies beneath the area, so layers above it, such as text, stay sharp.
- **Stickers:** 68 bundled OpenMoji stickers, shown under "Divine Originals". The picker has no search. Several stickers can be merged into one layer that keeps where each sticker sat, how large it was and how it was turned.
- **Filters:** 56 looks plus "None" (40 classic presets, 8 styled looks, 8 color tints), picked one at a time with a strength slider. Each confirmed filter is kept, so several can stack.
- **Effects:** 32 timeline effects, each with an intensity slider: glitch, block glitch, RGB split, VHS, static, old film, film grain, interference, CRT, pixelate, pixel pulse, shake, zoom pulse, mirror, kaleidoscope, split screen, wave, glow, vignette, strobe and negative flash, plus Divine's own echo, fisheye, drops, light leak, snow, confetti, hearts, sparkles, tilt-shift, zoom blur and comic. Drops also sets how many drops show (1 to 5), their size, speed, frost and fringes. Echo leaves fading copies of moving subjects where they were 100 ms, 200 ms and so on before, one to seven copies as the intensity rises; Divine renders it natively, through the same code in the preview and the export. A new effect covers the whole video; on the timeline it is a bar that can be moved, trimmed, edited, split, duplicated and deleted, and overlapping effects combine. A flashing effect (strobe or negative flash) starts on a whole second of the exported video (an effect with no whole second before its end is left out of the export); when the video already flashes from its first frame, flashing also stops on the last whole second before the video loops, so the flashes on both sides of the loop point stay within three a second. A flashing effect cannot be duplicated, and only one of them can run at a time, because overlapping ones would pass three flashes a second. Adding one removes every other flashing effect, since a new effect covers the whole video; moving, trimming or editing one cuts the others out of its window instead, shortening or splitting them (pieces under 100 ms are dropped). A video that uses either at an intensity above zero is published with the Flashing Lights content warning, locked on in the metadata screen until the video is posted; editing the published video later treats it as an ordinary label that can be removed. Effects with a clear hit (zoom pulse, pixel pulse, RGB split, glitch, block glitch, shake, strobe, negative flash and zoom blur) have an **On the beat** switch: the effect then fires once on every beat of the video's music instead of playing all through its window — the first sound on the timeline that is not a voice-over, or else the clips' own sound. The beats are found on the device, when an effect first needs them, where the sound gets clearly louder in its bass, mids or highs and stays louder for a moment: drums, words and bangs fire, crackle does not, and a hit right after a much stronger one fades into it and fires nothing. They move with the sound and the clips. A flashing effect on the beat flashes once per beat, skips beats less than a third of a second apart (so it flashes on every other beat of a very fast song), and drops any beat that would put more than three flashes in one second of the looping video. The bar on the timeline says "on the beat", and saving a clip to the library leaves effects on the beat out, since the clip does not take the music along.
- **Adjustments:** brightness, contrast, highlights, shadows, saturation, vibrance, exposure, hue, temperature, tint, fade and sharpen. One adjustment session shares a single time window on the timeline.
- **Audio visualizer:** bars, mirrored bars, a wave or a ring of bars that move with everything that plays in the video: the clips' own sound, clips detached onto the canvas, music and voice-over, each as it plays in the export, with its volume, fades and equalizer. Across an overlap transition and the loop-restart blend the two clips fade into each other along the transition's curve, and a muted clip leaves the other to fade against silence. The Visualizer tile opens a sheet with the four styles, the 11 preset colors or a custom one, and three sliders: how many bands it shows (6 to 48, one at a time; each style starts at its own number), how it reacts (calm swings less and rises and falls slowly, lively swings wide and falls fast) and how wide its bars are (30–95 % of their slot; not for the wave). A preview at the top of the sheet plays the picked look in a loop with the video's own sound, or with a sample beat while the sound is read or when the video has none, and holds still with reduced motion. Edit on its timeline bar changes all of it later. It is a layer like a sticker: it can be moved, resized, rotated, trimmed, split, duplicated, made see-through, animated and keyframed. The sound is read on the device once the sheet opens or a visualizer is on the canvas, into 48 pitch-spaced bands 60 times a second; each visualizer merges them into its own number of bands (by default 24 for bars, 32 for mirrored bars, 16 for the wave and 24 for the ring, drawn on both sides), and each band follows its loudness against the loudest moment of the video, so a quiet video moves as much as a loud one. By default a bar rises at once and falls within a third of a second. The preview and the export draw the same shapes from the same levels (pro_video_editor `ImageLayer.audioVisualizer`). Saving a clip to the library leaves visualizers out, since the clip does not take the music along.

Enter, leave and loop animations, per layer:

- Enter and leave: fade, slide, scale, bounce and wiggle, combinable within each phase. Text layers can also type themselves out letter by letter (typewriter) or word by word, and take themselves away the same way; spaces take no step, and the text's background grows with the revealed part.
- Loop, repeated for as long as the layer is visible: wiggle, bounce (a hop) and pulse.
- Duration 10–2000 ms in 10 ms steps, one loop cycle 200–2000 ms; the 13 easing curves. Wiggle tilts 2–30°, bounce lifts by 10–200 % of the layer's height, pulse shrinks to 0–100 % of its size.
- Slide from any edge or from a custom point tapped on the canvas. The layer moves in a straight line; a path through several points is made with keyframes.

Keyframes, per layer (text, sticker, drawing, audio visualizer and detached clip; timeline clips have their own, see Keyframes under Clips and timeline):

- The Keyframes button in a selected layer's bar opens a sheet with a one-line explanation and a button that adds a keyframe at the playhead, holding the layer where the canvas shows it, or removes the one there. The sheet's changes show on the canvas right away and are one undo step: the check mark or swiping the sheet away keeps them, the cross takes them back. The button's diamond fills in while the playhead is on a keyframe.
- Once a layer has a keyframe, moving, resizing or rotating it on the canvas sets a keyframe at the playhead: it changes the one there, or adds one.
- On a keyframe, the sheet sets the layer's opacity there, so it fades from one keyframe to the next.
- Between two keyframes the layer moves along one of the 13 easing curves, linear by default, and can play a wiggle, a hop or a pulse on the way, with its strength; the sheet edits the stretch the playhead is in and names its two keyframes. The effect's cycle is fitted so the layer rests on both keyframes. A detached clip offers no effect, as it has no animations. Before the first keyframe and after the last one the layer holds still.
- A layer's timeline bar shows its keyframes on its bottom edge: as yellow diamonds while it is selected, the one at the playhead filled in, and tapping one moves the playhead onto it; as small marks otherwise.
- Trimming the layer's start, splitting it or duplicating it keeps the motion where it was on the video. A detached clip's footage moves along when its start is trimmed, and its motion goes with the footage. Removing the last keyframe leaves the layer where it showed at the playhead.
- Enter, leave and loop animations play on top of the keyframed motion, and the export moves the layer as the canvas does, through clip transitions too.

Tracking, per layer that keyframes can move (text, sticker, drawing, audio visualizer and detached clip; not a hidden area, which would uncover what it hides if the track drifted):

- The Track button in a selected layer's bar hands the screen to the canvas and puts a box over the frame at the playhead, centred on the layer. Dragging moves the box, a pinch or a corner handle resizes it, and the check mark starts tracking. A playhead outside the layer is moved onto its start first.
- The object in the box is followed through the clip under the playhead, forward to where the layer or the clip ends and back to where either starts, with classical motion analysis and no ML model (pro_video_editor `VideoObjectTracker`): corners in the box are tracked from frame to frame, and only those that move against the rest of the scene count as the object, so a box drawn loosely around a moving subject follows the subject rather than the background. Their motion moves and scales the box; anything in the box that drifts away from it, like a swinging arm, is dropped. A blocking overlay shows the progress and can cancel it.
- The path becomes the layer's keyframes in that stretch, as one undo step: the layer keeps where it sat against the object, so a label above someone's head stays above it, and it grows and shrinks with the object. Its turn and opacity stay as its keyframes had them. The path is cut down to as few linear keyframes as keep the layer within a pixel of it; keyframes outside the stretch stay, and the layer holds still before and after it.
- When the object leaves the frame or gets covered, the layer follows it as far as it was seen and a message says so. A box with too little detail, a freeze frame, a stop-motion clip, the still in a detached clip's slot and a clip still rendering cannot be tracked, which a message says too.

## Captions

- **Auto captions:** the audio is transcribed on Divine's server first, with a fallback to the platform's speech recognition: Apple's on iOS, which runs on the device when it supports the language and on Apple's servers otherwise; Android 14 or later with language packs installed, on the device. Clip audio is transcribed; music and voice-over are not. Captions are first made in the app's language, and a caption track that is opened again keeps the language it was made in. When the device's recognizer does not accept that language, it falls back to the device's default.
- **Editing:** change a caption's text and timing, add and remove captions. Minimum caption length 200 ms. Captions can be typed by hand when recognition finds nothing.
- **Styles:** 21 presets, a custom style (font, text color, background, outline and shadow, animation: none, fade, pop, spring or karaoke), and saved caption styles, picked with a button that appears once "Burn into video" is on.
- **Word highlight:** the karaoke animation, also a built-in preset, lights each word in a highlight color as it is spoken. Word timings come from the recognizer; for Divine's server, which only times whole cues, they are spread by word length. The published subtitle track stays cue-level.
- **Output:** burning captions into the picture is optional. The app also publishes them as a separate subtitle track, best effort: if that upload fails or times out, the video is published without it.
- **After publishing,** the subtitle editor lets the author fix the text and timing of a published video's captions.

## Audio

- **Sound picker tabs:** Divine (bundled classic Vine sounds), Community (sounds other creators published), Featured, and My Sounds (saved sounds).
- **Import** of `aac`, `m4a`, `mp3` and `wav` files from the device.
- **Several sound tracks at once.** Adding a sound adds a track rather than replacing the previous one. Each track can be moved, trimmed, split and duplicated, and its start point inside the sound chosen.
- **Speed** per sound track, from 0.25× to 3× with the same slider and presets as a clip, one constant speed, with the pitch kept as recorded. A speed change keeps the stretch of the sound it plays, so 2× halves its bar on the timeline. Extracted clip audio given its own speed is no longer held in sync with its clip.
- **Ducking** on every sound track but a voice-over: with "Lower while someone talks" on, the sound drops wherever a voice-over take talks and comes back up after it, by 10–100 % in 5 % steps (75 % by default). The dips come from the loudness of the takes, not from speech recognition. Off by default.
- **Voice-over:** records takes over the muted preview. Takes are placed one after another; the last take can be deleted.
- **Volume** per clip and per sound track, from silent to 300 %. The timeline arc turns orange above 100 % and red above 200 %. Boosted audio is limited at −1 dBFS in the export, and the Android preview limits at the same ceiling. The iOS preview limits a boost only while an equalized clip timeline plays from its prepared loop (see Equalizer below); otherwise it plays the boost without a limiter.
- **Equalizer (EQ)** per clip and per sound track: ten octave bands whose points are dragged up or down, each from −18 to +18 dB in 1 dB steps: a low shelf at 31 Hz, octave-wide peaks at 62, 125, 250 and 500 Hz and 1, 2, 4 and 8 kHz, and a high shelf at 16 kHz, with one-tap presets (original, clear voice, bassy, bright). The line behind the points draws what the bands add up to, which is what the preview and the export play: neighbouring bands add up where they overlap, and a shelf gives half its gain at its own frequency. The point being moved shows its frequency and gain above the curve, and a double tap puts it back to zero. While the sheet is open the preview loops the clip or sound being changed and plays every change, through the same filters the export renders with, and a boost is limited at −1 dBFS in both. On iOS an equalized clip timeline plays its sound from a prepared loop instead of the player, so clips are equalized while the preview loops at normal speed, and a sound track plays an equalized copy of the stretch of its file it plays, so its change is heard once the curve has rested for half a second and that stretch is rendered. The stop-motion preview plays sound tracks without their equalizer.
- **Fade in and out** per sound track, in 100 ms steps. The envelope is linear, and the preview plays the same one the export bakes in.
- **Voice effects and noise reduction** on any sound track, not only voice-overs (a clip's own sound needs Extract audio first): one-tap presets (original, chipmunk, deep, robot, echo, reverb, phone, megaphone, underwater, slowed + reverb) or sliders for pitch (−12 to +12 semitones), robot (0–100 %), echo (0–100 %) and reverb (0–100 %, a small room up to a large hall), plus a noise reduction toggle. Phone, megaphone and underwater have no slider; one of them stays marked while the sliders add to it. Slowed + reverb lowers the pitch by 4 semitones, adds reverb and plays the sound at 0.8×, like a tape run slow; the preview loops it at that speed, Done applies the speed with the effect as one undo step, and picking another preset puts the speed back. Settings loop while the sheet is open and are processed offline when confirmed. A stereo sound stays stereo, with a wide reverb tail; a voice-over stays mono. The track keeps the original, so the effect can be changed or removed later.
- **Waveforms** on clips and sound tracks, and live while recording a voice-over.
- Creators choose whether others may reuse the audio of their published video.

## Export

- 1080p at 8 Mbps. If the encoder fails, the render tries 1080p once more after a 0.8 s pause, then 720p at 4 Mbps.
- ProofMode signing, which can be retried if it fails.
- One progress indicator for render, stop-motion assembly and signing, with a retry if it fails. A watchdog stops a render after 5 minutes.
- Cover image picked from a frame of the video.
- A preview of the post as it will look in the feed.
- Save the finished video to the device.

## Requested or planned

Open feature requests for things the editor does not do yet:

- Audio: loudness equalization ([#3789](https://github.com/divinevideo/divine-mobile/issues/3789)), a larger sound library ([#8338](https://github.com/divinevideo/divine-mobile/issues/8338)).
- Text: a link in the text overlay ([#3111](https://github.com/divinevideo/divine-mobile/issues/3111)).
- Clips: ghost mode for smoother transitions and loops ([#9573](https://github.com/divinevideo/divine-mobile/issues/9573)), a smoother jump when the video loops back to its start ([#9587](https://github.com/divinevideo/divine-mobile/issues/9587); Align loop covers part of it).
- Stickers: NIP-30 stickers ([#2265](https://github.com/divinevideo/divine-mobile/issues/2265)).
- Frames around the video ([#7099](https://github.com/divinevideo/divine-mobile/issues/7099)).

## Deliberately not supported

- Importing videos or photos from the camera roll (camera-first, ProofMode), apart from Divine camera clips that pass the C2PA check. Clips signed by other cameras are not accepted yet ([`C2PA_EXTERNAL_CAPTURE_SIGNERS.md`](C2PA_EXTERNAL_CAPTURE_SIGNERS.md)).
- ML background removal and generative effects ([#8543](https://github.com/divinevideo/divine-mobile/issues/8543)).
- Landscape (16:9), 4K export, and a choice of frame rate or codec.
