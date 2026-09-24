import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/constants/video_editor_timeline_constants.dart';
import 'package:openvine/l10n/l10n.dart';

/// Timeline markers — vertical guide lines set by the creator.
class VideoEditorTimelineMarkers extends StatelessWidget {
  const VideoEditorTimelineMarkers({
    required this.scrollController,
    required this.scrollPadding,
    required this.pixelsPerSecond,
    super.key,
  });

  final ScrollController scrollController;
  final double scrollPadding;
  final double pixelsPerSecond;

  @override
  Widget build(BuildContext context) {
    final markers = context.select(
      (TimelineOverlayBloc b) => b.state.timelineMarkers,
    );
    final isReordering = context.select(
      (VideoEditorMainBloc b) => b.state.isReordering,
    );
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return IgnorePointer(
      ignoring: isReordering || markers.isEmpty,
      child: AnimatedOpacity(
        opacity: isReordering || markers.isEmpty ? 0.0 : 1.0,
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 200),
        child: Stack(
          children: [
            IgnorePointer(
              child: CustomPaint(
                painter: _TimelineMarkersPainter(
                  markers: markers,
                  scrollController: scrollController,
                  scrollPadding: scrollPadding,
                  pixelsPerSecond: pixelsPerSecond,
                ),
                child: const SizedBox.expand(),
              ),
            ),
            _TimelineMarkerDeleteTargets(
              markers: markers,
              scrollController: scrollController,
              scrollPadding: scrollPadding,
              pixelsPerSecond: pixelsPerSecond,
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineMarkerDeleteTargets extends StatelessWidget {
  const _TimelineMarkerDeleteTargets({
    required this.markers,
    required this.scrollController,
    required this.scrollPadding,
    required this.pixelsPerSecond,
  });

  final List<Duration> markers;
  final ScrollController scrollController;
  final double scrollPadding;
  final double pixelsPerSecond;

  static const _tapTargetSize = 48.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return AnimatedBuilder(
          animation: scrollController,
          builder: (context, _) {
            final pos = scrollController.positions.lastOrNull;
            final scrollOffset = pos?.pixels ?? 0.0;

            return Stack(
              children: [
                for (final marker in markers)
                  _TimelineMarkerDeleteTarget(
                    marker: marker,
                    centerX:
                        scrollPadding +
                        marker.inMilliseconds / 1000.0 * pixelsPerSecond -
                        scrollOffset,
                    maxWidth: constraints.maxWidth,
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _TimelineMarkerDeleteTarget extends StatelessWidget {
  const _TimelineMarkerDeleteTarget({
    required this.marker,
    required this.centerX,
    required this.maxWidth,
  });

  final Duration marker;
  final double centerX;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    const tapTargetSize = _TimelineMarkerDeleteTargets._tapTargetSize;
    final isVisible =
        centerX >= -tapTargetSize && centerX <= maxWidth + tapTargetSize;
    if (!isVisible) return const SizedBox.shrink();

    return Positioned(
      left: centerX - tapTargetSize / 2,
      top: 0,
      width: tapTargetSize,
      height: tapTargetSize,
      child: Semantics(
        label: context.l10n.videoEditorRemoveTimelineMarkerSemanticLabel,
        button: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _confirmDelete(context),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final navigator = Navigator.of(context);
    final confirmed = await VineBottomSheetPrompt.show<bool>(
      context: context,
      sticker: .alert,
      title: context.l10n.videoEditorDeleteTimelineMarkerTitle,
      subtitle: context.l10n.videoEditorDeleteTimelineMarkerSubtitle,
      primaryButtonText: context.l10n.commonDelete,
      secondaryButtonText: context.l10n.commonCancel,
      onPrimaryPressed: () => navigator.pop(true),
      onSecondaryPressed: () => navigator.pop(false),
    );

    if (confirmed != true || !context.mounted) return;
    context.read<TimelineOverlayBloc>().add(TimelineMarkerRemoved(marker));
  }
}

class _TimelineMarkersPainter extends CustomPainter {
  _TimelineMarkersPainter({
    required this.markers,
    required this.scrollController,
    required this.scrollPadding,
    required this.pixelsPerSecond,
  }) : super(repaint: scrollController);

  final List<Duration> markers;
  final ScrollController scrollController;
  final double scrollPadding;
  final double pixelsPerSecond;

  static const _lineWidth = 1.0;
  static const _dotRadius = 4.0;

  static final Paint _linePaint = Paint()
    ..color = VineTheme.accentYellow.withValues(alpha: 0.78)
    ..strokeWidth = _lineWidth;

  static final Paint _dotPaint = Paint()
    ..color = VineTheme.accentYellow
    ..style = PaintingStyle.fill;

  @override
  void paint(Canvas canvas, Size size) {
    if (markers.isEmpty) return;

    final pos = scrollController.positions.lastOrNull;
    final scrollOffset = pos?.pixels ?? 0.0;
    const dotY = TimelineConstants.rulerHeight / 2;

    for (final marker in markers) {
      final x =
          scrollPadding +
          marker.inMilliseconds / 1000.0 * pixelsPerSecond -
          scrollOffset;

      if (x < -_dotRadius || x > size.width + _dotRadius) continue;

      canvas
        ..drawLine(Offset(x, 0), Offset(x, size.height), _linePaint)
        ..drawCircle(Offset(x, dotY), _dotRadius, _dotPaint);
    }
  }

  @override
  bool shouldRepaint(_TimelineMarkersPainter oldDelegate) =>
      !listEquals(oldDelegate.markers, markers) ||
      oldDelegate.scrollPadding != scrollPadding ||
      oldDelegate.pixelsPerSecond != pixelsPerSecond;
}
