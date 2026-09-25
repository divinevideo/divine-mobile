import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/constants/video_editor_timeline_constants.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/transition_geometry.dart';

/// Ruler markers — "0s · 10f · 20f · 1s · …"
///
/// Adapts label density based on [pixelsPerSecond]. At low zoom
/// only whole-second labels appear; at high zoom frame-based
/// sub-second markers (10f, 20f) fill the gaps — like TikTok.
///
/// Labels read the **rendered output** time, not the editor axis: an overlap
/// transition (dissolve/slide/push/wipe) blends two clips so the output is
/// shorter than the editor layout. The box keeps the editor width so it stays
/// aligned with the clip strip and scrolls together, but each tick is placed at
/// the editor pixel where its output second actually falls (via
/// [TransitionTimelineMap.outputToEditor]). The ruler therefore agrees with the
/// output-mapped header, stretching slightly across blend regions. Without an
/// overlap transition the mapping is the identity and the ruler is unchanged.
///
/// Uses [CustomPaint] with the [scrollController] as repaint
/// listenable so only the ~10–20 visible labels are drawn per frame,
/// regardless of total video length or zoom level.
class VideoEditorTimelineRulesIndicator extends StatelessWidget {
  const VideoEditorTimelineRulesIndicator({
    required this.totalDuration,
    required this.pixelsPerSecond,
    required this.scrollController,
    required this.scrollPadding,
    this.clips = const [],
    super.key,
  });

  /// Editor-axis length (clips at full length). Drives the box width so the
  /// ruler aligns with the clip strip.
  final Duration totalDuration;
  final double pixelsPerSecond;
  final ScrollController scrollController;

  /// Clips on the timeline, used to map ruler ticks onto the output axis.
  /// Empty falls back to the editor axis (identity mapping).
  final List<DivineVideoClip> clips;

  /// Empty space laid out before the ruler in the horizontal scroll content.
  /// Needed so the painter can convert scroll offset to the
  /// ruler's local coordinate space.
  final double scrollPadding;

  @override
  Widget build(BuildContext context) {
    final totalSeconds = totalDuration.inMilliseconds / 1000.0;
    final totalWidth = totalSeconds * pixelsPerSecond;
    final timelineMap = TransitionTimelineMap.fromClips(clips);

    return ExcludeSemantics(
      child: SizedBox(
        width: totalWidth,
        height: TimelineConstants.rulerHeight,
        child: CustomPaint(
          painter: _RulerPainter(
            totalDuration: totalDuration,
            pixelsPerSecond: pixelsPerSecond,
            scrollController: scrollController,
            scrollPadding: scrollPadding,
            clips: clips,
            timelineMap: timelineMap,
            labelColor: context.vineColors.onSurfaceMuted,
          ),
        ),
      ),
    );
  }
}

class _RulerPainter extends CustomPainter {
  _RulerPainter({
    required this.totalDuration,
    required this.pixelsPerSecond,
    required this.scrollController,
    required this.scrollPadding,
    required this.clips,
    required this.timelineMap,
    required this.labelColor,
  }) : super(repaint: scrollController);

  final Duration totalDuration;
  final double pixelsPerSecond;
  final ScrollController scrollController;
  final double scrollPadding;
  final List<DivineVideoClip> clips;
  final TransitionTimelineMap timelineMap;

  /// Tick-label colour for the active appearance mode.
  final Color labelColor;

  static const double _minLabelSpacing = 30;
  static const int _fps = VideoEditorConstants.editorFps;
  static const List<int> _frameSteps = [
    2,
    3,
    5,
    10,
    15,
    30,
    60,
    150,
    300,
    450,
    900,
    1800,
  ];

  TextStyle get _labelStyle => VineTheme.labelSmallFont(
    color: labelColor,
  ).copyWith(fontFeatures: [const FontFeature.tabularFigures()]);

  /// Laid-out [TextPainter] instances keyed by label *and* colour.
  ///
  /// A cached painter bakes in the style it was laid out with, so the key
  /// has to carry the colour too — otherwise switching appearance mode would
  /// keep repainting the previous mode's labels.
  /// Avoids creating and laying out a new [TextPainter] for every
  /// visible label on every scroll frame (~600–1200 allocations/sec
  /// at 60 Hz). Bounded to [_tpCacheMax] to cap native paragraph
  /// memory; oldest entries are evicted and disposed.
  static final Map<String, TextPainter> _tpCache = {};
  static const int _tpCacheMax = 256;

  /// Labels count output seconds; the box and clip strip span the editor axis.
  /// With no overlap transition the two axes coincide.
  double get _outputSeconds {
    final output = clips.isEmpty ? totalDuration : timelineMap.outputDuration;
    return output.inMilliseconds / 1000.0;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final frameStep = _frameStepForZoom(pixelsPerSecond);
    final stepSeconds = frameStep / _fps;
    final totalCount = (_outputSeconds / stepSeconds).floor();
    final centerY = size.height / 2;

    // Convert scroll offset to the ruler's local (editor-pixel) coordinate
    // space. The ruler starts at [scrollPadding] within the scroll view, so
    // subtract it to get the visible range in ruler-local pixels.
    //
    // Use [positions] instead of [position] to avoid the assertion
    // "ScrollController attached to multiple scroll views" that can
    // trigger during rebuilds when old and new Scrollable briefly
    // coexist.
    final pos = scrollController.positions.lastOrNull;
    final scrollOffset = pos?.pixels ?? 0.0;
    final viewportWidth = pos?.viewportDimension ?? size.width;

    final rulerStart = scrollOffset - scrollPadding;

    // The visible window is in editor pixels; map its edges to output seconds
    // to pick which output ticks to draw, then place each one back on the
    // editor axis. A one-step buffer on each side keeps edge labels from
    // popping in.
    final visibleStartOutput = _editorPxToOutputSeconds(rulerStart);
    final visibleEndOutput = _editorPxToOutputSeconds(
      rulerStart + viewportWidth,
    );

    final firstIndex = ((visibleStartOutput / stepSeconds).floor() - 1).clamp(
      0,
      totalCount,
    );
    final lastIndex = ((visibleEndOutput / stepSeconds).ceil() + 1).clamp(
      0,
      totalCount,
    );

    for (var i = firstIndex; i <= lastIndex; i++) {
      final x = _outputSecondsToEditorPx(i * stepSeconds);
      final label = _formatLabel(i * frameStep);

      final tp = _tpCache.putIfAbsent(
        '$label@${labelColor.toARGB32()}',
        () {
          if (_tpCache.length >= _tpCacheMax) {
            final oldestKey = _tpCache.keys.first;
            _tpCache.remove(oldestKey)?.dispose();
          }
          return TextPainter(
            text: TextSpan(text: label, style: _labelStyle),
            textDirection: TextDirection.ltr,
          )..layout();
        },
      );

      tp.paint(canvas, Offset(x, centerY - tp.height / 2));
    }
  }

  double _editorPxToOutputSeconds(double editorPx) {
    if (clips.isEmpty) return editorPx / pixelsPerSecond;
    final editor = Duration(
      microseconds: (editorPx / pixelsPerSecond * 1e6).round(),
    );
    return timelineMap.editorToOutput(editor).inMicroseconds / 1e6;
  }

  double _outputSecondsToEditorPx(double outputSeconds) {
    if (clips.isEmpty) return outputSeconds * pixelsPerSecond;
    final output = Duration(microseconds: (outputSeconds * 1e6).round());
    return timelineMap.outputToEditor(output).inMicroseconds /
        1e6 *
        pixelsPerSecond;
  }

  int _frameStepForZoom(double pps) {
    for (final step in _frameSteps) {
      final stepSeconds = step / _fps;
      if (stepSeconds * pps >= _minLabelSpacing) return step;
    }
    return _frameSteps.last;
  }

  String _formatLabel(int totalFrames) {
    if (totalFrames % _fps == 0) {
      return '${totalFrames ~/ _fps}s';
    }
    return '${totalFrames % _fps}f';
  }

  @override
  bool shouldRepaint(_RulerPainter oldDelegate) =>
      oldDelegate.totalDuration != totalDuration ||
      oldDelegate.pixelsPerSecond != pixelsPerSecond ||
      oldDelegate.scrollPadding != scrollPadding ||
      oldDelegate.labelColor != labelColor ||
      !identical(oldDelegate.clips, clips);
}
