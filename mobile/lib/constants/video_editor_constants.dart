import 'package:divine_camera/divine_camera.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

/// A text font with its style getter.
typedef TextFont = TextStyle Function({double? fontSize, Color? color});

/// An editor text-overlay font: the google_fonts tear-off that registers it,
/// paired with the family name it is published under ("Shadows Into Light").
///
/// The name is written out rather than read back from `GoogleFonts.asMap()`.
/// That map is a const map over the whole google_fonts catalogue, so any
/// reference to it retains all ~1700 font descriptors and defeats the
/// package's per-font tree shaking — worth 6.6 MiB of `main.dart.js`, which
/// pushed the web bundle past Cloudflare Pages' 25 MiB per-file limit (#9269).
///
/// [category] is the section the font pickers list it under.
typedef EditorTextFont = ({
  TextFont font,
  String familyName,
  EditorFontCategory category,
});

/// The sections the font pickers group the editor fonts into, declared in the
/// order the pickers show them.
enum EditorFontCategory {
  /// Neutral sans serif faces.
  sans,

  /// Heavy display faces made for a big title.
  headline,

  /// Script, brush and handwriting faces.
  script,

  /// Serif faces.
  serif,

  /// Faces with a built-in outline, shade or texture.
  effect,

  /// Monospaced, typewriter, pixel and futuristic faces.
  mono,

  /// Faces tied to a mood or occasion: horror, holiday, blackletter.
  themed,

  /// Faces built for a non-Latin script, which also carry Latin.
  otherScripts,
}

/// Constants for the video editor feature.
class VideoEditorConstants {
  /// Key used to identify autosaved drafts in storage.
  static const String autoSaveId = 'draft_autosave';

  /// Prefix key used to identify drafts being published in storage.
  static const String publishPrefixId = 'draft_publish';

  /// Unique history key for clip items.
  static const String clipsStateHistoryKey = 'clips';

  /// Unique history key for audio items.
  static const String audioStateHistoryKey = 'audio';

  /// Unique history key for timeline marker positions.
  static const String timelineMarkersStateHistoryKey = 'timelineMarkers';

  /// Unique history key for the caption track (burn-in flag, preset,
  /// language, custom style, cues).
  static const String captionsStateHistoryKey = 'captions';

  /// Unique history key for the video effects (glitch, VHS, pixelate), each
  /// stored as `EditorVideoEffect.toMap()`: the effect's own fields plus the
  /// id the timeline addresses it by.
  static const String effectsStateHistoryKey = 'effects';

  /// `Layer.meta` key marking a layer as a burned-in caption cue.
  ///
  /// Caption cue layers are real editor layers (so preview, export, undo and
  /// drafts work unchanged) but are bucketed into the timeline's captions
  /// strip instead of the layer strip, and edited through the captions editor
  /// rather than the generic text editor.
  static const String captionCueMetaKey = 'divineCaptionCue';

  /// `Layer.meta` key carrying the caption cue's stable id.
  static const String captionCueIdMetaKey = 'divineCaptionCueId';

  /// Shortest a caption cue may be trimmed; below this reading is impossible.
  static const Duration minCaptionCueDuration = Duration(milliseconds: 200);

  /// `TuneAdjustmentMatrix.meta` key grouping the adjustments produced by one
  /// tune-editor session into a single timeline "set" (one bar per set, sharing
  /// a time window).
  static const String tuneSetIdMetaKey = 'tuneSetId';

  /// `TuneAdjustmentMatrix.meta` key recording the adjustment kind
  /// (`brightness`, `contrast`, …) so its label / toMatrix can be resolved
  /// after the matrix is given a unique per-instance id.
  static const String tuneKindMetaKey = 'tuneKind';

  /// Maximum number of tags allowed per video.
  static const int tagLimit = 1 << 30; // ~1 billion

  /// Maximum number of characters allowed in a description.
  static const int descriptionLimit = 1_000;

  /// Maximum number of collaborators allowed per video.
  static const int maxCollaborators = 5;

  /// Maximum creators one video may credit as "Inspired By".
  ///
  /// Matches [maxCollaborators]: both are lists of people the author
  /// attributes, and both become p-tags on the published event.
  static const int maxInspiredByCreators = 5;

  /// Whether to enforce the tag limit in the UI.
  static const bool enableTagLimit = false;

  /// Maximum recording duration for videos.
  static const maxDuration = Duration(seconds: 6, milliseconds: 300);

  /// How far the playhead may be from a layer keyframe for the editor to
  /// treat it as on that keyframe: one frame at 30 fps.
  ///
  /// A seek lands on the frame the player delivers, a few milliseconds off the
  /// time asked for; without the slack, moving a layer right after jumping to
  /// a keyframe would add a second keyframe next to it instead of changing it.
  static const keyframeTolerance = Duration(microseconds: 33334);

  /// How often per second of output the export samples a keyframed motion
  /// that eases across a clip transition.
  ///
  /// A transition plays both clips at once, so the export's clock runs at
  /// half the editor's through it, and an easing curve cut there is none of
  /// the 13 curves any more. The export follows such a stretch through linear
  /// keyframes this close together instead, within a fraction of a pixel of
  /// the preview.
  static const exportedMotionSamplesPerSecond = 240;

  /// One cycle of a looping wiggle, a hop and a pulse when first picked: a
  /// wiggle swings like a pendulum, a hop lands and takes off again, a pulse
  /// breathes slower than either.
  static const loopWiggleCycle = Duration(milliseconds: 600);
  static const loopBounceCycle = Duration(milliseconds: 700);
  static const loopPulseCycle = Duration(seconds: 1);

  /// How far a looping pulse shrinks a layer when first picked: to 80 %
  /// rather than to nothing.
  static const loopPulseScaleFrom = 0.8;

  /// Bounds of the wiggle tilt slider, in whole degrees.
  static const minWiggleDegrees = 2;
  static const maxWiggleDegrees = 30;

  /// Bounds and snap step of the bounce height slider, in percent of the
  /// layer's height.
  static const minBouncePercent = 10;
  static const maxBouncePercent = 200;
  static const bounceStepPercent = 10;

  /// How long a single export may run before it is treated as never returning.
  ///
  /// A liveness bound, not a performance budget: a real export of the
  /// [maxDuration] ceiling finishes in seconds, so this only has to sit above
  /// "slow" and below "forever" (#8488).
  static const Duration renderWatchdogTimeout = Duration(minutes: 5);

  /// How long a preview render — a transition seam or a speed body — may run
  /// before it is treated as never returning (#9347).
  ///
  /// Also a liveness bound, and one that has to clear a whole fan-out rather
  /// than one render. A seam's ≤ 6.3 s bounds only its output: first,
  /// `pro_video_editor` re-encodes each HEVC source that is 10-bit or HDR.
  /// On iOS and macOS that is only the windows its clips play when together
  /// they cover under 90% of the file, otherwise the whole *file*; on Android
  /// it is always the whole file. So on Android a seam between two
  /// minute-long 4K HDR clips pays two whole transcodes (the plugin measured
  /// a 4K re-encode at ~19 s alone).
  /// The preview asks for every seam and every retimed clip at once on each
  /// timeline change, all queued one at a time through the plugin's single
  /// encoder slot, so the last render of a six-clip HDR timeline on a
  /// throttled phone can legitimately wait well over a minute — and
  /// cancelling it there would only re-queue the same work. A render that
  /// genuinely stalls is ended by the plugin's own 20 s no-progress watchdog
  /// long before this fires; this is the outer net for one that never comes
  /// back at all. A stalled preview render costs an overlay and a retry
  /// rather than the user's export, so this sits below
  /// [renderWatchdogTimeout] but not by an order of magnitude.
  static const Duration previewRenderWatchdogTimeout = Duration(minutes: 2);

  /// How long the trim of a clip recorded past the remaining duration may run
  /// before it is treated as never returning (#8797).
  ///
  /// The trim is the only thing that settles the clip's processing signal, and
  /// proof generation, the speed render and the export all wait on that signal
  /// first. It re-encodes one clip no longer than [maxDuration], so like the
  /// others this is a liveness bound, not a budget. It sits below
  /// [renderWatchdogTimeout] so a stalled trim fails as a trim rather than
  /// spending the export's whole bound and reporting as an export timeout.
  static const Duration clipTrimWatchdogTimeout = Duration(minutes: 2);

  /// Frame grid the editor presents to the user.
  ///
  /// The timeline ruler labels sub-second positions in frames at this rate, so
  /// any control that has to line up against it — the audio in-point scrubber
  /// included — must resolve at least this finely, or it promises a precision
  /// it cannot deliver.
  static const int editorFps = 30;

  /// Minimum duration a rendered stop-motion video must reach.
  ///
  /// Very short clips (a single still ≈ 33ms) make looping players stutter and
  /// oscillate. The renderer repeats the captured sequence an integer number of
  /// times until the output is at least this long, preserving the per-frame
  /// timing and keeping the loop seamless.
  static const stopMotionMinOutputDuration = Duration(seconds: 1);

  /// Compositions shorter than this are too short a loop for the native
  /// player's position reports to describe.
  ///
  /// The player reports its position about five times a second. On a loop of
  /// a few frames those reports land at arbitrary points of the loop: a
  /// timeline gliding from one to the next twitches in place instead of
  /// sweeping, and the time label sticks wherever the reports happen to fall.
  /// Below this length the canvas feeds the timeline from its display-rate
  /// playhead interpolator instead, wrapping at the loop end, and the
  /// timeline jumps to each position rather than gliding — a glide lasts
  /// longer than such a loop does. See `isShortLoop`.
  ///
  /// Half a second gives a loop at least two reports per pass, the least a
  /// glide between reports needs to read as motion.
  static const shortLoopThreshold = Duration(milliseconds: 500);

  /// Minimum spacing between playback-position updates a display-rate
  /// playhead ticker pushes into the editor timeline.
  ///
  /// The frames-only stop-motion clock and, on a loop shorter than
  /// [shortLoopThreshold], the composition player's interpolator both tick at
  /// the display refresh rate, but the timeline only needs a coarse position
  /// stream to chase (it animates between updates). Throttling to this
  /// interval keeps scrolling smooth without flooding the bloc with ~60
  /// position events per second.
  static const playheadEmitInterval = Duration(milliseconds: 40);

  /// Default time offset for extracting video thumbnails.
  static const defaultThumbnailExtractTime = Duration(milliseconds: 200);

  /// Maximum time to wait for the text-overlay Google Fonts to load when
  /// restoring a draft. Already-cached fonts resolve instantly, so this only
  /// guards the first, uncached load before the canvas imports the overlays.
  static const textFontLoadTimeout = Duration(seconds: 3);

  /// How long a chroma-key screen measurement may run before it is treated
  /// as never returning.
  ///
  /// A liveness bound, not a performance budget: the measurement is a metadata
  /// call and three small thumbnail decodes, which finish in well under a
  /// second. The green-screen panel keeps Done disabled while it runs —
  /// confirming earlier would bake the preset the measurement is about to
  /// replace — so without this a decode that never calls back would lock the
  /// panel for good (#8904).
  static const Duration chromaKeyDetectTimeout = Duration(seconds: 15);

  /// Maximum time to wait for a draft write to complete before treating it as
  /// failed. A draft save is a local DB write that normally finishes in
  /// milliseconds; bounding it ensures a stalled write surfaces as a failure
  /// the UI can recover from, instead of leaving the save button wedged for
  /// the rest of the session.
  static const draftSaveTimeout = Duration(seconds: 15);

  /// Maximum time to wait for the screen pushed over the editor (the metadata /
  /// export screen) to finish its entrance transition before releasing the
  /// preview decoder anyway. Bounds the wait so a missing transition signal can
  /// never stall the export — the decoder is released (and the render proceeds)
  /// at the latest after this.
  static const coverTransitionTimeout = Duration(milliseconds: 1500);

  /// Primary accent color used in the video editor UI.
  static const primaryColor = Color(0xFFFFF140);

  /// Available colors for text overlays.
  static const colors = [
    Color(0xFFF9F7F6),
    Color(0xFF000000),
    Color(0xFF27C58B),
    Color(0xFFD0FBCB),
    Color(0xFFFFF140),
    Color(0xFFD2FF40),
    Color(0xFFFF7FAF),
    Color(0xFFFF7640),
    Color(0xFFA3A9FF),
    Color(0xFF8568FF),
    Color(0xFF34BBF1),
  ];

  /// Available text fonts for text overlays, with the family name each one is
  /// published under.
  ///
  /// The first 35 are sorted by popularity; every later addition is appended.
  /// **Append only, never reorder or remove**: a caption track and a saved
  /// title style persist their font as an index into this list
  /// (`CaptionCustomStyle.fontIndex`, `TitleStyle.fontIndex`), so a moved
  /// entry silently changes the font of every saved draft and style. The font
  /// pickers do not show this order: they group the fonts by `category`, see
  /// `editorFontSections`.
  ///
  /// `familyName` is the name google_fonts publishes the family under, spaces
  /// and capitalisation included ('Press Start 2P', not 'PressStart2p'); it is
  /// also the label the font picker shows. `editorTextFontIndexFor` derives the
  /// serialized `fontFamily` identifier from it with the spaces stripped, so
  /// tests in `test/utils/editor_text_fonts_test.dart` pin both its serialized
  /// identifier and its exact published spelling, capitalisation and spacing.
  ///
  /// Every entry ships under the SIL Open Font License 1.1, Apache 2.0 or the
  /// Ubuntu Font License, all of which permit commercial use and leave text
  /// burned into an exported video unrestricted. Before adding a font, confirm
  /// it lives under `ofl/`, `apache/` or `ufl/` in
  /// https://github.com/google/fonts — nothing else is acceptable here — and
  /// add its copyright notice under that license to
  /// `assets/licenses/editor_fonts.json`, which credits it on the in-app
  /// license page. For OFL fonts the notice is the header of the family's
  /// `OFL.txt`; for the others it is the `copyright` field of its
  /// `METADATA.pb`.
  ///
  /// google_fonts downloads the whole font file on first use, so keep an
  /// addition's regular face well under a megabyte: that rules out the CJK
  /// families, which weigh several.
  static const List<EditorTextFont> textFontCatalogue = [
    (font: GoogleFonts.inter, familyName: 'Inter', category: .sans),
    (
      font: GoogleFonts.bricolageGrotesque,
      familyName: 'Bricolage Grotesque',
      category: .sans,
    ),
    (font: GoogleFonts.roboto, familyName: 'Roboto', category: .sans),
    (font: GoogleFonts.openSans, familyName: 'Open Sans', category: .sans),
    (font: GoogleFonts.notoSans, familyName: 'Noto Sans', category: .sans),
    (font: GoogleFonts.montserrat, familyName: 'Montserrat', category: .sans),
    (font: GoogleFonts.lato, familyName: 'Lato', category: .sans),
    (font: GoogleFonts.poppins, familyName: 'Poppins', category: .sans),
    (font: GoogleFonts.robotoMono, familyName: 'Roboto Mono', category: .mono),
    (font: GoogleFonts.oswald, familyName: 'Oswald', category: .sans),
    (font: GoogleFonts.raleway, familyName: 'Raleway', category: .sans),
    (font: GoogleFonts.ubuntu, familyName: 'Ubuntu', category: .sans),
    (font: GoogleFonts.nunito, familyName: 'Nunito', category: .sans),
    (font: GoogleFonts.rubik, familyName: 'Rubik', category: .sans),
    (
      font: GoogleFonts.merriweather,
      familyName: 'Merriweather',
      category: .serif,
    ),
    (
      font: GoogleFonts.playfairDisplay,
      familyName: 'Playfair Display',
      category: .serif,
    ),
    (font: GoogleFonts.nunitoSans, familyName: 'Nunito Sans', category: .sans),
    (font: GoogleFonts.lora, familyName: 'Lora', category: .serif),
    (font: GoogleFonts.ptSans, familyName: 'PT Sans', category: .sans),
    (font: GoogleFonts.workSans, familyName: 'Work Sans', category: .sans),
    (font: GoogleFonts.barlow, familyName: 'Barlow', category: .sans),
    (font: GoogleFonts.quicksand, familyName: 'Quicksand', category: .sans),
    (font: GoogleFonts.mulish, familyName: 'Mulish', category: .sans),
    (
      font: GoogleFonts.titilliumWeb,
      familyName: 'Titillium Web',
      category: .sans,
    ),
    (
      font: GoogleFonts.josefinSans,
      familyName: 'Josefin Sans',
      category: .sans,
    ),
    (
      font: GoogleFonts.bebasNeue,
      familyName: 'Bebas Neue',
      category: .headline,
    ),
    (font: GoogleFonts.comfortaa, familyName: 'Comfortaa', category: .sans),
    (font: GoogleFonts.lobster, familyName: 'Lobster', category: .script),
    (font: GoogleFonts.pacifico, familyName: 'Pacifico', category: .script),
    (
      font: GoogleFonts.dancingScript,
      familyName: 'Dancing Script',
      category: .script,
    ),
    (font: GoogleFonts.caveat, familyName: 'Caveat', category: .script),
    (
      font: GoogleFonts.permanentMarker,
      familyName: 'Permanent Marker',
      category: .script,
    ),
    (
      font: GoogleFonts.crimsonText,
      familyName: 'Crimson Text',
      category: .serif,
    ),
    (
      font: GoogleFonts.ibmPlexMono,
      familyName: 'IBM Plex Mono',
      category: .mono,
    ),
    (
      font: GoogleFonts.anonymousPro,
      familyName: 'Anonymous Pro',
      category: .mono,
    ),
    (font: GoogleFonts.anton, familyName: 'Anton', category: .headline),
    (font: GoogleFonts.bangers, familyName: 'Bangers', category: .headline),
    (
      font: GoogleFonts.archivoBlack,
      familyName: 'Archivo Black',
      category: .headline,
    ),
    (
      font: GoogleFonts.alfaSlabOne,
      familyName: 'Alfa Slab One',
      category: .headline,
    ),
    (
      font: GoogleFonts.luckiestGuy,
      familyName: 'Luckiest Guy',
      category: .headline,
    ),
    (
      font: GoogleFonts.lilitaOne,
      familyName: 'Lilita One',
      category: .headline,
    ),
    (font: GoogleFonts.righteous, familyName: 'Righteous', category: .headline),
    (font: GoogleFonts.russoOne, familyName: 'Russo One', category: .headline),
    (
      font: GoogleFonts.blackOpsOne,
      familyName: 'Black Ops One',
      category: .headline,
    ),
    (font: GoogleFonts.bungee, familyName: 'Bungee', category: .headline),
    (font: GoogleFonts.fredoka, familyName: 'Fredoka', category: .headline),
    (
      font: GoogleFonts.abrilFatface,
      familyName: 'Abril Fatface',
      category: .headline,
    ),
    (font: GoogleFonts.satisfy, familyName: 'Satisfy', category: .script),
    (
      font: GoogleFonts.greatVibes,
      familyName: 'Great Vibes',
      category: .script,
    ),
    (font: GoogleFonts.sacramento, familyName: 'Sacramento', category: .script),
    (font: GoogleFonts.amaticSc, familyName: 'Amatic SC', category: .script),
    (
      font: GoogleFonts.shadowsIntoLight,
      familyName: 'Shadows Into Light',
      category: .script,
    ),
    (
      font: GoogleFonts.indieFlower,
      familyName: 'Indie Flower',
      category: .script,
    ),
    (
      font: GoogleFonts.patrickHand,
      familyName: 'Patrick Hand',
      category: .script,
    ),
    (font: GoogleFonts.kalam, familyName: 'Kalam', category: .script),
    (font: GoogleFonts.courgette, familyName: 'Courgette', category: .script),
    (font: GoogleFonts.rockSalt, familyName: 'Rock Salt', category: .script),
    (
      font: GoogleFonts.cormorantGaramond,
      familyName: 'Cormorant Garamond',
      category: .serif,
    ),
    (font: GoogleFonts.ebGaramond, familyName: 'EB Garamond', category: .serif),
    (
      font: GoogleFonts.libreBaskerville,
      familyName: 'Libre Baskerville',
      category: .serif,
    ),
    (
      font: GoogleFonts.dmSerifDisplay,
      familyName: 'DM Serif Display',
      category: .serif,
    ),
    (font: GoogleFonts.cinzel, familyName: 'Cinzel', category: .serif),
    (font: GoogleFonts.robotoSlab, familyName: 'Roboto Slab', category: .serif),
    (font: GoogleFonts.dmSans, familyName: 'DM Sans', category: .sans),
    (font: GoogleFonts.manrope, familyName: 'Manrope', category: .sans),
    (
      font: GoogleFonts.plusJakartaSans,
      familyName: 'Plus Jakarta Sans',
      category: .sans,
    ),
    (font: GoogleFonts.figtree, familyName: 'Figtree', category: .sans),
    (
      font: GoogleFonts.spaceGrotesk,
      familyName: 'Space Grotesk',
      category: .sans,
    ),
    (font: GoogleFonts.outfit, familyName: 'Outfit', category: .sans),
    (font: GoogleFonts.spaceMono, familyName: 'Space Mono', category: .mono),
    (
      font: GoogleFonts.courierPrime,
      familyName: 'Courier Prime',
      category: .mono,
    ),
    (
      font: GoogleFonts.specialElite,
      familyName: 'Special Elite',
      category: .mono,
    ),
    (font: GoogleFonts.vt323, familyName: 'VT323', category: .mono),
    (
      font: GoogleFonts.pressStart2p,
      familyName: 'Press Start 2P',
      category: .mono,
    ),
    (font: GoogleFonts.orbitron, familyName: 'Orbitron', category: .mono),
    (font: GoogleFonts.creepster, familyName: 'Creepster', category: .themed),
    (font: GoogleFonts.monoton, familyName: 'Monoton', category: .effect),
    (font: GoogleFonts.pirataOne, familyName: 'Pirata One', category: .themed),
    (
      font: GoogleFonts.unifrakturMaguntia,
      familyName: 'UnifrakturMaguntia',
      category: .themed,
    ),
    (font: GoogleFonts.titanOne, familyName: 'Titan One', category: .headline),
    (
      font: GoogleFonts.paytoneOne,
      familyName: 'Paytone One',
      category: .headline,
    ),
    (
      font: GoogleFonts.passionOne,
      familyName: 'Passion One',
      category: .headline,
    ),
    (
      font: GoogleFonts.staatliches,
      familyName: 'Staatliches',
      category: .headline,
    ),
    (font: GoogleFonts.teko, familyName: 'Teko', category: .headline),
    (
      font: GoogleFonts.rubikMonoOne,
      familyName: 'Rubik Mono One',
      category: .headline,
    ),
    (font: GoogleFonts.unbounded, familyName: 'Unbounded', category: .headline),
    (font: GoogleFonts.chewy, familyName: 'Chewy', category: .headline),
    (font: GoogleFonts.shrikhand, familyName: 'Shrikhand', category: .headline),
    (font: GoogleFonts.knewave, familyName: 'Knewave', category: .headline),
    (
      font: GoogleFonts.bungeeShade,
      familyName: 'Bungee Shade',
      category: .effect,
    ),
    (
      font: GoogleFonts.bungeeInline,
      familyName: 'Bungee Inline',
      category: .effect,
    ),
    (
      font: GoogleFonts.bungeeOutline,
      familyName: 'Bungee Outline',
      category: .effect,
    ),
    (
      font: GoogleFonts.rubikGlitch,
      familyName: 'Rubik Glitch',
      category: .effect,
    ),
    (
      font: GoogleFonts.rubikWetPaint,
      familyName: 'Rubik Wet Paint',
      category: .effect,
    ),
    (
      font: GoogleFonts.kaushanScript,
      familyName: 'Kaushan Script',
      category: .script,
    ),
    (font: GoogleFonts.yellowtail, familyName: 'Yellowtail', category: .script),
    (font: GoogleFonts.allura, familyName: 'Allura', category: .script),
    (font: GoogleFonts.parisienne, familyName: 'Parisienne', category: .script),
    (font: GoogleFonts.cookie, familyName: 'Cookie', category: .script),
    (
      font: GoogleFonts.homemadeApple,
      familyName: 'Homemade Apple',
      category: .script,
    ),
    (font: GoogleFonts.gochiHand, familyName: 'Gochi Hand', category: .script),
    (
      font: GoogleFonts.architectsDaughter,
      familyName: 'Architects Daughter',
      category: .script,
    ),
    (
      font: GoogleFonts.gloriaHallelujah,
      familyName: 'Gloria Hallelujah',
      category: .script,
    ),
    (
      font: GoogleFonts.sedgwickAve,
      familyName: 'Sedgwick Ave',
      category: .script,
    ),
    (font: GoogleFonts.bodoniModa, familyName: 'Bodoni Moda', category: .serif),
    (font: GoogleFonts.fraunces, familyName: 'Fraunces', category: .serif),
    (
      font: GoogleFonts.instrumentSerif,
      familyName: 'Instrument Serif',
      category: .serif,
    ),
    (font: GoogleFonts.yesevaOne, familyName: 'Yeseva One', category: .serif),
    (font: GoogleFonts.prata, familyName: 'Prata', category: .serif),
    (
      font: GoogleFonts.instrumentSans,
      familyName: 'Instrument Sans',
      category: .sans,
    ),
    (font: GoogleFonts.sora, familyName: 'Sora', category: .sans),
    (font: GoogleFonts.lexend, familyName: 'Lexend', category: .sans),
    (font: GoogleFonts.kanit, familyName: 'Kanit', category: .sans),
    (font: GoogleFonts.exo2, familyName: 'Exo 2', category: .sans),
    (font: GoogleFonts.urbanist, familyName: 'Urbanist', category: .sans),
    (
      font: GoogleFonts.jetBrainsMono,
      familyName: 'JetBrains Mono',
      category: .mono,
    ),
    (font: GoogleFonts.silkscreen, familyName: 'Silkscreen', category: .mono),
    (
      font: GoogleFonts.pixelifySans,
      familyName: 'Pixelify Sans',
      category: .mono,
    ),
    (font: GoogleFonts.audiowide, familyName: 'Audiowide', category: .mono),
    (font: GoogleFonts.michroma, familyName: 'Michroma', category: .mono),
    (font: GoogleFonts.nosifer, familyName: 'Nosifer', category: .themed),
    (
      font: GoogleFonts.mountainsOfChristmas,
      familyName: 'Mountains of Christmas',
      category: .themed,
    ),
    (
      font: GoogleFonts.metalMania,
      familyName: 'Metal Mania',
      category: .themed,
    ),
    (font: GoogleFonts.cairo, familyName: 'Cairo', category: .otherScripts),
    (font: GoogleFonts.lalezar, familyName: 'Lalezar', category: .otherScripts),
    (
      font: GoogleFonts.reemKufi,
      familyName: 'Reem Kufi',
      category: .otherScripts,
    ),
    (
      font: GoogleFonts.blackHanSans,
      familyName: 'Black Han Sans',
      category: .otherScripts,
    ),
    (
      font: GoogleFonts.doHyeon,
      familyName: 'Do Hyeon',
      category: .otherScripts,
    ),
  ];

  /// The fonts of [textFontCatalogue], in catalogue order.
  ///
  /// Indices line up with [textFontCatalogue], which is what
  /// `CaptionCustomStyle.fontIndex` persists, so the list is unmodifiable: a
  /// runtime insert or removal would silently repoint saved drafts.
  static final List<TextFont> textFonts = List.unmodifiable([
    for (final entry in textFontCatalogue) entry.font,
  ]);

  /// Width of drawing tool items in the draw editor toolbar.
  static const double drawItemWidth = 48.0;

  /// Thinnest stroke the draw editor's brush size slider reaches, in logical
  /// pixels of the editor body.
  static const double drawMinStrokeWidth = 2.0;

  /// Thickest stroke the draw editor's brush size slider reaches; see
  /// [drawMinStrokeWidth].
  static const double drawMaxStrokeWidth = 40.0;

  /// How long the brush preview takes to fade out after the brush size
  /// slider is released.
  static const Duration drawBrushPreviewFadeDuration = Duration(
    milliseconds: 250,
  );

  /// Standard deviation of the blur that hides an area, in logical pixels of
  /// the editor canvas. The preview blurs with it, and the export scales it
  /// to the video's pixels like the area itself.
  static const double censorBlurSigma = 14.0;

  /// Edge length of a pixelate block that hides an area, in logical pixels
  /// of the editor canvas; see [censorBlurSigma].
  static const double censorPixelBlockSize = 12.0;

  /// Intensity a censor tool starts at, on its 0 to 1 slider: the strength of
  /// [censorBlurSigma] and [censorPixelBlockSize].
  static const double censorDefaultIntensity = 0.5;

  /// How many times stronger the strongest censor intensity is than the
  /// default, and weaker the weakest.
  static const double censorIntensityRange = 4.0;

  /// Border radius applied to the video editor canvas.
  static const double canvasRadius = 8.0;

  /// Base font size in pixels for text overlays.
  static const double baseFontSize = 24.0;

  /// Minimum font scale multiplier for text overlays.
  static const double minFontScale = 0.5;

  /// Maximum font scale multiplier for text overlays.
  static const double maxFontScale = 4.0;

  /// Minimum playback speed multiplier for clips.
  static const double clipSpeedMin = 0.25;

  /// Maximum playback speed multiplier for clips.
  static const double clipSpeedMax = 3.0;

  /// Maximum volume multiplier for clips and audio tracks (300 %).
  static const double volumeMax = 3.0;

  /// Step size between discrete speed values on the clip speed slider.
  static const double clipSpeedStep = 0.05;

  /// One-tap speeds offered next to the clip speed slider.
  ///
  /// Each value must lie within [clipSpeedMin]..[clipSpeedMax] and on the
  /// [clipSpeedStep] grid, so the slider can land on it exactly.
  static const List<double> clipSpeedPresets = [0.25, 0.5, 1, 1.5, 2, 3];

  /// Step size between discrete values on the sound fade sliders.
  static const Duration audioFadeStep = Duration(milliseconds: 100);

  /// Background color for the text editor overlay.
  static const Color textEditorBackground = Color(0x9B000000);

  /// System overlay style for the full-screen media surfaces — recorder,
  /// editor, metadata preview and the camera permission gate.
  ///
  /// Both bars follow the palette. The camera preview and the editor canvas
  /// are inset behind a [SafeArea], so the status bar sits on the screen's own
  /// background rather than on content — light icons there would be invisible
  /// once that background goes light. The Android system navigation bar sits
  /// under the screen's chrome for the same reason.
  static SystemUiOverlayStyle uiOverlayStyleFor(VineThemeColors colors) {
    final isLight = colors.isLight;
    return SystemUiOverlayStyle(
      statusBarColor: VineTheme.transparent,
      statusBarIconBrightness: isLight ? Brightness.dark : Brightness.light,
      statusBarBrightness: isLight ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: colors.surfaceContainerHigh,
      systemNavigationBarIconBrightness: isLight
          ? Brightness.dark
          : Brightness.light,
    );
  }

  /// Height of the bottom action bar in the video editor.
  static const double bottomBarHeight = 90;

  /// Delay before background isolates start processing to avoid
  /// contention with the main isolate during editor initialisation.
  static const isolatesInitialisationDelay = Duration(milliseconds: 500);

  /// Video quality for recording and editing
  static const DivineVideoQuality quality = DivineVideoQuality.fhd;

  /// Fallback export quality used after the device rejects the primary
  /// [quality] with a `RenderEncoderException`.
  ///
  /// A 720p canvas needs far fewer encoder resources than 1080p, so a
  /// codec-limited device that cannot allocate an [quality] encoder can still
  /// finish the export at this reduced tier instead of losing the edit.
  static const DivineVideoQuality encoderFallbackQuality =
      DivineVideoQuality.hd;

  /// Settle delay between export encoder attempts after a
  /// `RenderEncoderException`.
  ///
  /// Encoder-init failures on codec-limited devices are usually transient
  /// contention: the preview decoder the editor just released (the #5522
  /// decoder-release gate) — or another app codec — has not been reclaimed by
  /// the OS media server yet. The plugin's own in-process fallback chain runs
  /// every attempt within a few hundred ms, so it cannot outlast that window;
  /// waiting before the Dart-level retry lets the codec free up.
  static const encoderRetrySettleDelay = Duration(milliseconds: 800);

  /// Hero animation tag for the back button in the video editor.
  static const heroBackButtonId = 'Video-Editor-Back-Button';

  /// Hero animation tag for the final clip-preview in the video editor.
  static const heroMetaPreviewId = 'Video-metadata-clip-preview-video';

  /// Corner radius of the clip-preview thumbnails that carry
  /// [heroMetaPreviewId]. The preview screen morphs its flight out of this
  /// shape into the stage's rounded bottom, so the thumbnails and the flight
  /// cannot drift apart. The cover screen is the other destination on that
  /// tag and keeps its own rounding.
  static const clipPreviewCornerRadius = 16.0;

  /// Hero animation tag for the audio-chip in the video editor.
  static const heroAudioChipId = 'Video-Editor-Audio-Chip';

  /// Hero animation tag for the toolbar leading (close) button.
  static const heroToolbarLeadingId = 'Video-Editor-Toolbar-Leading';

  /// Hero animation tag for the toolbar trailing (done) button.
  static const heroToolbarTrailingId = 'Video-Editor-Toolbar-Trailing';

  /// List of filter presets sorted by popularity
  static final List<FilterModel> filters = [
    PresetFilters.none,

    // Tier 1: Most popular filters
    PresetFilters.clarendon,
    PresetFilters.juno,
    PresetFilters.ludwig,
    PresetFilters.lark,
    PresetFilters.gingham,

    // Tier 2: Very popular
    PresetFilters.valencia,
    PresetFilters.xProII,
    PresetFilters.loFi,
    PresetFilters.amaro,
    PresetFilters.hudson,

    // Tier 3: Popular
    PresetFilters.nashville,
    PresetFilters.mayfair,
    PresetFilters.rise,
    PresetFilters.perpetua,
    PresetFilters.aden,

    // Tier 4: Vintage & artistic
    PresetFilters.earlybird,
    PresetFilters.f1977,
    PresetFilters.kelvin,
    PresetFilters.walden,
    PresetFilters.toaster,

    // Tier 5: Mood filters
    PresetFilters.moon,
    PresetFilters.inkwell,
    PresetFilters.willow,
    PresetFilters.slumber,
    PresetFilters.reyes,

    // Tier 6: Color boost
    PresetFilters.hefe,
    PresetFilters.sierra,
    PresetFilters.sutro,
    PresetFilters.brannan,
    PresetFilters.maven,

    // Tier 7: Specialty
    PresetFilters.crema,
    PresetFilters.ashby,
    PresetFilters.charmes,
    PresetFilters.helena,
    PresetFilters.brooklyn,
    PresetFilters.ginza,
    PresetFilters.skyline,
    PresetFilters.dogpatch,
    PresetFilters.stinson,
    PresetFilters.vesper,

    // Essential filters
    FilterModel(
      name: 'Cinematic',
      filters: [
        ColorFilterAddons.colorOverlay(0, 140, 140, 0.08),
        ColorFilterAddons.colorOverlay(255, 140, 50, 0.05),
        ColorFilterAddons.contrast(0.1),
        ColorFilterAddons.saturation(-0.1),
      ],
    ),
    FilterModel(
      name: 'Faded',
      filters: [
        ColorFilterAddons.contrast(-0.1),
        ColorFilterAddons.brightness(0.08),
        ColorFilterAddons.saturation(-0.15),
      ],
    ),
    FilterModel(
      name: 'Dramatic',
      filters: [
        ColorFilterAddons.contrast(0.25),
        ColorFilterAddons.brightness(-0.05),
        ColorFilterAddons.saturation(0.1),
      ],
    ),
    FilterModel(
      name: 'Dreamy',
      filters: [
        ColorFilterAddons.brightness(0.1),
        ColorFilterAddons.saturation(-0.1),
        ColorFilterAddons.contrast(-0.08),
        ColorFilterAddons.colorOverlay(255, 220, 255, 0.05),
      ],
    ),
    FilterModel(
      name: 'Glow',
      filters: [
        ColorFilterAddons.brightness(0.12),
        ColorFilterAddons.contrast(-0.05),
        ColorFilterAddons.saturation(-0.05),
      ],
    ),
    FilterModel(
      name: 'Noir',
      filters: [
        ColorFilterAddons.grayscale(),
        ColorFilterAddons.contrast(0.2),
        ColorFilterAddons.brightness(-0.05),
      ],
    ),
    FilterModel(
      name: 'Vivid',
      filters: [
        ColorFilterAddons.saturation(0.4),
        ColorFilterAddons.contrast(0.1),
      ],
    ),
    FilterModel(
      name: 'Muted',
      filters: [
        ColorFilterAddons.saturation(-0.3),
        ColorFilterAddons.brightness(0.05),
      ],
    ),

    // Simple color tints
    FilterModel(
      name: 'Ruby',
      filters: [ColorFilterAddons.addictiveColor(50, 0, 0)],
    ),
    FilterModel(
      name: 'Ocean',
      filters: [ColorFilterAddons.addictiveColor(0, 0, 50)],
    ),
    FilterModel(
      name: 'Forest',
      filters: [ColorFilterAddons.addictiveColor(0, 40, 0)],
    ),
    FilterModel(
      name: 'Sunset',
      filters: [ColorFilterAddons.addictiveColor(60, 30, 0)],
    ),
    FilterModel(
      name: 'Violet',
      filters: [ColorFilterAddons.addictiveColor(40, 0, 50)],
    ),
    FilterModel(
      name: 'Mint',
      filters: [ColorFilterAddons.addictiveColor(0, 50, 40)],
    ),
    FilterModel(
      name: 'Coral',
      filters: [ColorFilterAddons.addictiveColor(50, 20, 10)],
    ),
    FilterModel(
      name: 'Arctic',
      filters: [ColorFilterAddons.addictiveColor(0, 30, 60)],
    ),
  ];

  /// Placeholder for [TuneAdjustmentItem.icon].
  ///
  /// The tune editor's built-in chrome (app bar + bottom bar) is fully replaced
  /// by our custom text-chip bar, so the required `icon` field is never
  /// rendered. A single placeholder satisfies it without adding raw Material
  /// `Icons.*` — the DivineIcon ratchet forbids them here and DivineIcon
  /// exposes no `IconData`.
  static const IconData _unusedTuneIcon = IconData(0);

  /// Tune adjustment options exposed by the tune sub-editor.
  ///
  /// Mirrors pro_image_editor's `tunePresets` (which is not part of the
  /// package's public API) so the same list can be passed to both the editor
  /// config and the custom bottom bar, guaranteeing the `TuneEditorState`'s
  /// `selectedIndex` maps to the same adjustment our UI shows. The `icon` /
  /// `label` fields are never rendered — the custom bar draws its own
  /// localized text chips (see [_unusedTuneIcon]).
  static const List<TuneAdjustmentItem> tuneAdjustments = [
    TuneAdjustmentItem(
      id: 'brightness',
      icon: _unusedTuneIcon,
      label: 'Brightness',
      min: -0.5,
      max: 0.5,
      labelMultiplier: 200,
      toMatrix: ColorFilterAddons.brightness,
    ),
    TuneAdjustmentItem(
      id: 'contrast',
      icon: _unusedTuneIcon,
      label: 'Contrast',
      min: -0.5,
      max: 0.5,
      labelMultiplier: 200,
      toMatrix: ColorFilterAddons.contrast,
    ),
    TuneAdjustmentItem(
      id: 'saturation',
      icon: _unusedTuneIcon,
      label: 'Saturation',
      min: -0.5,
      max: 0.5,
      labelMultiplier: 200,
      toMatrix: ColorFilterAddons.saturation,
    ),
    TuneAdjustmentItem(
      id: 'exposure',
      icon: _unusedTuneIcon,
      label: 'Exposure',
      min: -1,
      max: 1,
      toMatrix: ColorFilterAddons.exposure,
    ),
    TuneAdjustmentItem(
      id: 'hue',
      icon: _unusedTuneIcon,
      label: 'Hue',
      min: -0.25,
      max: 0.25,
      divisions: 400,
      labelMultiplier: 400,
      toMatrix: ColorFilterAddons.hue,
    ),
    TuneAdjustmentItem(
      id: 'temperature',
      icon: _unusedTuneIcon,
      label: 'Temperature',
      min: -0.5,
      max: 0.5,
      labelMultiplier: 200,
      toMatrix: ColorFilterAddons.temperature,
    ),
    TuneAdjustmentItem(
      id: 'tint',
      icon: _unusedTuneIcon,
      label: 'Tint',
      min: -0.5,
      max: 0.5,
      labelMultiplier: 200,
      toMatrix: ColorFilterAddons.tint,
    ),
    TuneAdjustmentItem(
      id: 'fade',
      icon: _unusedTuneIcon,
      label: 'Fade',
      min: -1,
      max: 1,
      toMatrix: ColorFilterAddons.fade,
    ),
  ];
}
