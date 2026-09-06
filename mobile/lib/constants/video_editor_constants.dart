import 'package:divine_camera/divine_camera.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

/// A text font with its style getter.
typedef TextFont = TextStyle Function({double? fontSize, Color? color});

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

  /// Unique history key for the caption track (mode, preset, overlay cues).
  static const String captionsStateHistoryKey = 'captions';

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

  /// How long a single export may run before it is treated as never returning.
  ///
  /// A liveness bound, not a performance budget: a real export of the
  /// [maxDuration] ceiling finishes in seconds, so this only has to sit above
  /// "slow" and below "forever" (#8488).
  static const Duration renderWatchdogTimeout = Duration(minutes: 5);

  /// Frame grid the editor presents to the user.
  ///
  /// The timeline ruler labels sub-second positions in frames at this rate, so
  /// any control that has to line up against it — the audio in-point scrubber
  /// included — must resolve at least this finely, or it promises a precision
  /// it cannot deliver.
  static const int editorFps = 30;

  /// Minimum duration a rendered stop-motion video must reach.
  ///
  /// Very short clips (a single still ≈ 83ms) make looping players stutter and
  /// oscillate. The renderer repeats the captured sequence an integer number of
  /// times until the output is at least this long, preserving the per-frame
  /// timing and keeping the loop seamless.
  static const stopMotionMinOutputDuration = Duration(seconds: 1);

  /// Minimum spacing between playback-position updates the frames-only
  /// stop-motion playhead pushes into the editor timeline.
  ///
  /// The playhead ticker fires at the display refresh rate, but the timeline
  /// only needs a coarse position stream to chase (it animates between
  /// updates). Throttling to this interval keeps scrolling smooth without
  /// flooding the bloc with ~60 position events per second.
  static const stopMotionPlayheadEmitInterval = Duration(milliseconds: 40);

  /// Default time offset for extracting video thumbnails.
  static const defaultThumbnailExtractTime = Duration(milliseconds: 200);

  /// Maximum time to wait for the text-overlay Google Fonts to load when
  /// restoring a draft. Already-cached fonts resolve instantly, so this only
  /// guards the first, uncached load before the canvas imports the overlays.
  static const textFontLoadTimeout = Duration(seconds: 3);

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

  /// Available text fonts for text overlays, sorted by popularity.
  static const List<TextFont> textFonts = [
    GoogleFonts.inter,
    GoogleFonts.bricolageGrotesque,
    GoogleFonts.roboto,
    GoogleFonts.openSans,
    GoogleFonts.notoSans,
    GoogleFonts.montserrat,
    GoogleFonts.lato,
    GoogleFonts.poppins,
    GoogleFonts.robotoMono,
    GoogleFonts.oswald,
    GoogleFonts.raleway,
    GoogleFonts.ubuntu,
    GoogleFonts.nunito,
    GoogleFonts.rubik,
    GoogleFonts.merriweather,
    GoogleFonts.playfairDisplay,
    GoogleFonts.nunitoSans,
    GoogleFonts.lora,
    GoogleFonts.ptSans,
    GoogleFonts.workSans,
    GoogleFonts.barlow,
    GoogleFonts.quicksand,
    GoogleFonts.mulish,
    GoogleFonts.titilliumWeb,
    GoogleFonts.josefinSans,
    GoogleFonts.bebasNeue,
    GoogleFonts.comfortaa,
    GoogleFonts.lobster,
    GoogleFonts.pacifico,
    GoogleFonts.dancingScript,
    GoogleFonts.caveat,
    GoogleFonts.permanentMarker,
    GoogleFonts.crimsonText,
    GoogleFonts.ibmPlexMono,
    GoogleFonts.anonymousPro,
  ];

  /// Width of drawing tool items in the draw editor toolbar.
  static const double drawItemWidth = 48.0;

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

  /// Step size between discrete speed values on the clip speed slider.
  static const double clipSpeedStep = 0.05;

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
