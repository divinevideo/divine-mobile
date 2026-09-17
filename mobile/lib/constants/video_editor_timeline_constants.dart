import 'dart:ui';

/// Sizing and layout constants for the video editor timeline.
abstract class TimelineConstants {
  /// Height of the timeline.
  static const double height = 400;

  /// Height of the ruler bar with time labels.
  static const double rulerHeight = 32;

  /// Vertical gap between the ruler bar and the clip body below it.
  static const double rulerToBodyGap = 4;

  /// Height of each clip thumbnail strip.
  static const double thumbnailStripHeight = 64;

  /// Vertical gap between thumbnail rows when multiple clip rows are shown.
  static const double thumbnailVerticalRowGap = 8;

  /// Width of a single thumbnail image in the strip.
  static const double thumbnailWidth = 48;

  /// Corner radius for thumbnail images.
  static const double thumbnailRadius = 4;

  /// Width of the sound control panel in the left column.
  static const double soundControlWidth = 92;

  /// Gap between adjacent clip containers.
  static const double clipGap = 1;

  /// Pixels rendered per second of video at 1x zoom.
  static const double pixelsPerSecond = 52;

  /// Minimum pixels per second when zoomed out.
  static const double minPixelsPerSecond = 1;

  /// Maximum pixels per second when zoomed in.
  static const double maxPixelsPerSecond = 600;

  /// Maximum pixels per second on a stop-motion composition. Stills are held
  /// for a handful of output frames (tens of ms), so meaningful zoom levels
  /// sit far above what second-long video clips ever need.
  static const double stopMotionMaxPixelsPerSecond = 2400;

  /// Tile width the initial stop-motion zoom aims to give the average still.
  static const double stopMotionTargetTileWidth = 56;

  /// Width of the playhead indicator line.
  static const double playheadWidth = 2;

  /// Width of the fixed left column (time display / audio button).
  static const double leftColumnWidth = 60;

  /// Horizontal padding around the scrollable content.
  static const double horizontalPadding = 12;

  // --- Trim handles ---

  /// Width of each trim handle (left / right).
  static const double trimHandleWidth = 16;

  /// Width of the vertical marker inside a trim handle.
  static const double trimHandleMarkerWidth = 3;

  /// Height of the vertical marker inside a trim handle.
  static const double trimHandleMarkerHeight = 32;

  /// Colour of the vertical marker inside each trim handle.
  static const Color trimHandleMarkerColor = Color(0xF0000000);

  /// Border width around a clip in trim mode.
  static const double trimBorderWidth = 2;

  /// Extra hit-test area around each trim handle.
  static const double trimHitAreaExtra = 32;

  /// How far a trim handle's grab zone reaches past the edge of the strip it
  /// belongs to. Layout boxes along the way must expand their hit-testing by
  /// this much, or a handle sitting on a strip's boundary is unreachable.
  static const double trimHitOverhang = trimHandleWidth + trimHitAreaExtra;

  /// Minimum trimmed duration for a clip.
  static const Duration minTrimDuration = Duration(milliseconds: 60);

  // --- Overlay strips (layers / filters / sounds) ---

  /// Height of a single row in an overlay strip.
  static const double overlayRowHeight = 48;

  /// Height of a single row in the sound overlay strip.
  ///
  /// Taller than other overlays to accommodate the waveform
  /// visualisation below the label text.
  static const double soundOverlayRowHeight = 64;

  /// Vertical gap between the clip strip and the first overlay strip.
  static const double overlayStripTopGap = 8;

  /// Vertical gap between different overlay strip sections.
  static const double overlayStripGap = 4;

  /// Bar width for the compact sound-overlay waveform.
  static const double soundWaveformBarWidth = 1;

  // --- Clip waveform overlay ---

  /// Bar width of the waveform drawn over a clip's thumbnails.
  static const double clipWaveformBarWidth = 1;

  /// Gap between the bars of the waveform drawn over a clip's thumbnails.
  static const double clipWaveformBarSpacing = 1;

  /// Height of the waveform band along a clip's bottom edge. Roughly a third
  /// of the strip, so the frames above stay readable.
  static const double clipWaveformBandHeight = 22;

  /// Opacity of the waveform drawn over a clip's thumbnails — legible over
  /// both bright and dark frames without competing with them.
  static const double clipWaveformOpacity = 0.55;

  /// Headroom multiplier for clip-waveform bars, so a peak at full amplitude
  /// stops just short of the band's top edge.
  static const double clipWaveformGain = 0.9;

  /// Lower bound for the per-clip waveform normalizer. A clip whose loudest
  /// sample sits below this stays quiet on screen rather than being stretched
  /// to full scale — the difference between "quiet" and "silent" survives.
  /// Keep in lockstep with `WaveformConstants.amplitudeNormalizerFloor`.
  static const double clipWaveformNormalizerFloor = 0.2;

  /// Exponent applied to the normalized amplitude. Below 1 it lifts the quiet
  /// body of the signal toward the peaks; 1 would be a linear (near-flat) band.
  /// Keep in lockstep with `WaveformConstants.amplitudeCurve`.
  static const double clipWaveformCurve = 0.6;

  /// Baseline height of a clip-waveform bar. Keeps a continuous line visible
  /// through silence and at zero volume.
  static const double clipWaveformMinBarHeight = 1;

  /// Vertical gap between overlay rows within a strip.
  static const double overlayRowGap = 6;

  /// Horizontal padding inside overlay item tiles.
  static const double overlayItemPadding = 6;

  /// Animation duration for overlay tile state changes.
  static const Duration overlayTileAnimDuration = Duration(milliseconds: 150);

  /// Fade applied to the ruler and the overlay strips while a clip is being
  /// drag-reordered. Both rows use it, so they fade in step.
  static const Duration reorderFadeDuration = Duration(milliseconds: 200);

  /// Empty space below the last strip, on top of the bottom safe-area inset.
  /// The volume-mode scroll view and the strips' own scroll view both apply
  /// it, and they have to agree on how far past the last strip content runs.
  static const double scrollBottomPadding = 100;

  /// Border width for dragged overlay items.
  static const double dragBorderWidth = 1.5;

  /// Shadow blur radius for dragged overlay items.
  static const double dragShadowBlurRadius = 6;

  // --- Snap ---

  /// Distance in logical pixels within which a free-moving edge first
  /// snaps to a nearby snap point. Kept very small so the edge reaches
  /// the snap point naturally instead of being pulled from a distance.
  static const double snapCatchPx = 3;

  /// Logical pixels of continued finger movement absorbed while the
  /// handle is held at a snap point. After this distance the handle
  /// releases and continues smoothly from the snap position.
  static const double snapDeadZonePx = 10;
}
