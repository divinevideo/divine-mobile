import 'dart:math' as math;
import 'dart:typed_data';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/constants/video_editor_timeline_constants.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/stop_motion/stop_motion_frame_ops.dart';
import 'package:openvine/models/timeline_overlay_item.dart';
import 'package:openvine/widgets/video_editor/stop_motion/stop_motion_frame_commands.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/strips/video_editor_stop_motion_frame_strip.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/strips/video_editor_timeline_clip_strip.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/strips/video_editor_timeline_overlay_strip.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/strips/video_editor_timeline_overlay_strips.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/utils/hit_expanded_box.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/utils/vertical_only_clipper.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/video_editor_timeline_rules_indicator.dart';

/// Scrollable content of the timeline: ruler, clip strip and the vertically
/// scrolling overlay strips.
///
/// Lays out [scrollPadding] of empty space on both sides of the composition
/// itself, rather than leaving that to the horizontal scroll view, so the
/// overlay strips' vertical scroll view spans it too. A vertical drag that
/// starts beside a composition narrower than the screen therefore reaches the
/// strips instead of only the horizontal scroll view.
class VideoEditorTimelineBody extends StatelessWidget {
  const VideoEditorTimelineBody({
    required this.totalDuration,
    required this.pixelsPerSecond,
    required this.scrollController,
    required this.overlayStripsScrollController,
    required this.scrollPadding,
    required this.clips,
    required this.totalWidth,
    required this.isInteracting,
    required this.onReorder,
    required this.onReorderChanged,
    required this.playheadPosition,
    super.key,
    this.trimmingClipId,
    this.onTrimChanged,
    this.onTrimDragChanged,
    this.onClipTapped,
    this.isMultiSelectMode = false,
    this.selectedClipIds = const {},
    this.onOverlayItemMoved,
    this.onOverlayItemMoving,
    this.onOverlayItemTrimmed,
    this.onOverlayTrimDragChanged,
    this.onOverlayItemTapped,
    this.onOverlayDragStarted,
    this.onOverlayDragEnded,
  });

  final Duration totalDuration;
  final double pixelsPerSecond;
  final ScrollController scrollController;

  /// Vertical scroll controller for the overlay-strips area. Owned by the
  /// timeline state so it can be reset to the top when volume-edit mode is
  /// entered (the strips are frozen there and must align with the arcs).
  final ScrollController overlayStripsScrollController;

  /// Empty space laid out on each side of the composition — half the screen,
  /// so the composition's ends can sit under the centred playhead. The ruler
  /// subtracts it from the scroll position to find its own first tick.
  final double scrollPadding;
  final List<DivineVideoClip> clips;
  final double totalWidth;
  final bool isInteracting;

  final ValueChanged<List<DivineVideoClip>>? onReorder;
  final ValueChanged<bool>? onReorderChanged;
  final String? trimmingClipId;
  final ClipTrimCallback? onTrimChanged;
  final ValueChanged<bool>? onTrimDragChanged;
  final ValueChanged<int>? onClipTapped;
  final bool isMultiSelectMode;
  final Set<String> selectedClipIds;
  final OverlayMoveCallback? onOverlayItemMoved;
  final OverlayMovingCallback? onOverlayItemMoving;
  final OverlayTrimCallback? onOverlayItemTrimmed;
  final ValueChanged<bool>? onOverlayTrimDragChanged;
  final ValueChanged<TimelineOverlayItem>? onOverlayItemTapped;
  final ValueChanged<TimelineOverlayItem>? onOverlayDragStarted;
  final VoidCallback? onOverlayDragEnded;
  final ValueNotifier<Duration> playheadPosition;

  @override
  Widget build(BuildContext context) {
    final (isReordering) = context.select(
      (VideoEditorMainBloc b) => b.state.isReordering,
    );
    final isVolumeEditMode = context.select(
      (VideoEditorMainBloc b) => b.state.isVolumeEditMode,
    );

    final clipTrimExpand = trimmingClipId != null
        ? TimelineConstants.trimHitOverhang
        : 0.0;

    // Also expand for overlay trim handles when an overlay item is selected.
    final overlaySelectedId = context.select(
      (TimelineOverlayBloc b) => b.state.selectedItemId,
    );
    final overlayTrimExpand = overlaySelectedId != null
        ? TimelineConstants.trimHitOverhang
        : 0.0;

    final showMaxDurationOverlays =
        !isReordering && totalDuration > VideoEditorConstants.maxDuration;
    final compositionPadding = EdgeInsets.symmetric(horizontal: scrollPadding);

    // Where the composition stops being usable. Deliberately not
    // timelinePositionToScrollOffset: that adds a clipGap per clip boundary,
    // which totalWidth does not, so it would shift this edge.
    final maxDurationEdge =
        scrollPadding +
        VideoEditorConstants.maxDuration.inMilliseconds /
            1000 *
            pixelsPerSecond;

    // Every row below carries compositionPadding, so the Stack is exactly as
    // wide as the horizontal scroll content and the overlays' `right: 0`
    // lands on its far end. A row added without that padding narrows the
    // Stack and leaves an un-banded strip past the last one that has it.
    return Stack(
      fit: .passthrough,
      clipBehavior: .none,
      children: [
        // Keep stack slots stable during drag-reorder to avoid gesture drops.
        _TimelineOutsideAreaOverlay(
          left: maxDurationEdge,
          visible: showMaxDurationOverlays,
          child: CustomPaint(
            painter: _TimelineOutsideAreaPainter(
              stripeColor: context.vineColors.disabled,
            ),
            child: const SizedBox.expand(),
          ),
        ),

        Column(
          crossAxisAlignment: .start,
          mainAxisSize: .min,
          children: [
            /// Rules Indicator
            Padding(
              padding: compositionPadding,
              child: _ReorderFade(
                isReordering: isReordering,
                child: RepaintBoundary(
                  child: VideoEditorTimelineRulesIndicator(
                    totalDuration: totalDuration,
                    pixelsPerSecond: pixelsPerSecond,
                    scrollController: scrollController,
                    scrollPadding: scrollPadding,
                    clips: clips,
                  ),
                ),
              ),
            ),
            const SizedBox(height: TimelineConstants.rulerToBodyGap),

            /// Video clips, or per-frame stills for a stop-motion clip.
            Padding(
              padding: compositionPadding,
              // The trimming clip's handles reach past the strip's edges, and
              // the boxes on the way down hit-test against their own bounds,
              // so the touch has to be let through here.
              child: HitExpandedBox(
                expandLeft: clipTrimExpand,
                expandRight: clipTrimExpand,
                child: RepaintBoundary(
                  child: isStopMotionComposition(clips)
                      ? _StopMotionFrameStrip(
                          clip: clips.first,
                          pixelsPerSecond: pixelsPerSecond,
                          scrollController: scrollController,
                          onReorderChanged: onReorderChanged,
                        )
                      : VideoEditorTimelineClipStrip(
                          clips: clips,
                          totalWidth: totalWidth,
                          pixelsPerSecond: pixelsPerSecond,
                          scrollController: scrollController,
                          isInteracting: isInteracting,
                          onReorder: onReorder,
                          onReorderChanged: onReorderChanged,
                          trimmingClipId: trimmingClipId,
                          onTrimChanged: onTrimChanged,
                          onTrimDragChanged: onTrimDragChanged,
                          onClipTapped: onClipTapped,
                          isMultiSelectMode: isMultiSelectMode,
                          selectedClipIds: selectedClipIds,
                        ),
                ),
              ),
            ),

            /// Layers, Filters and Audio-Tracks
            Expanded(
              // Above the scroll view, not inside it: a Scrollable hit-tests
              // opaquely, so a lower IgnorePointer still leaves a drag in the
              // padding scrolling strips the reorder has faded out.
              child: IgnorePointer(
                ignoring: isReordering,
                // Clipped only vertically, so a selected item's trim handle
                // stays visible past the composition's last pixel.
                child: ClipRect(
                  clipper: const VerticalOnlyClipper(),
                  // Carries the composition padding itself so a vertical drag
                  // beside a short composition still scrolls the strips.
                  child: SingleChildScrollView(
                    controller: overlayStripsScrollController,
                    clipBehavior: Clip.none,
                    physics: isVolumeEditMode
                        ? const NeverScrollableScrollPhysics()
                        : null,
                    padding: compositionPadding.copyWith(
                      top: 4,
                      bottom:
                          TimelineConstants.scrollBottomPadding +
                          MediaQuery.paddingOf(context).bottom,
                    ),
                    // The strips are exactly totalWidth wide, so a handle on
                    // an item ending at the composition's end sits outside
                    // every box below here — let the touch through to it.
                    // It stays above the fade: the expanded margin reaches
                    // past the fade's own bounds, and only _hitTestDeep
                    // below this box bypasses the size check.
                    child: HitExpandedBox(
                      expandLeft: overlayTrimExpand,
                      expandRight: overlayTrimExpand,
                      // Inside the scroll view, so the reorder fade's
                      // saveLayer covers the strips rather than the padding.
                      child: _ReorderFade(
                        isReordering: isReordering,
                        child: RepaintBoundary(
                          child: _CachedOverlayStrips(
                            clips: clips,
                            totalWidth: totalWidth,
                            pixelsPerSecond: pixelsPerSecond,
                            totalDuration: totalDuration,
                            playheadPosition: playheadPosition,
                            onItemTapped: onOverlayItemTapped,
                            onItemMoved: onOverlayItemMoved,
                            onItemMoving: onOverlayItemMoving,
                            onItemTrimmed: onOverlayItemTrimmed,
                            onTrimDragChanged: onOverlayTrimDragChanged,
                            onDragStarted: onOverlayDragStarted,
                            onDragEnded: onOverlayDragEnded,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        _TimelineOutsideAreaOverlay(
          left: maxDurationEdge,
          visible: showMaxDurationOverlays,
          child: ColoredBox(
            color: context.vineColors.surfaceContainerHigh.withValues(
              alpha: 0.3,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ],
    );
  }
}

/// Bridges the presentational [VideoEditorStopMotionFrameStrip] to the clip
/// editor: reads the selected frame from the bloc and commits frame selection
/// and drag reorders (via [commitStopMotionFrames]).
class _StopMotionFrameStrip extends StatelessWidget {
  const _StopMotionFrameStrip({
    required this.clip,
    required this.pixelsPerSecond,
    required this.scrollController,
    this.onReorderChanged,
  });

  final DivineVideoClip clip;
  final double pixelsPerSecond;
  final ScrollController scrollController;
  final ValueChanged<bool>? onReorderChanged;

  @override
  Widget build(BuildContext context) {
    final frames = clip.stopMotionFrames ?? const [];
    final (
      selectedFrameIndex,
      isMultiSelectMode,
      selectedFrameIndexes,
    ) = context.select(
      (ClipEditorBloc b) => (
        b.state.selectedFrameIndex,
        b.state.isMultiSelectMode,
        b.state.selectedFrameIndexes,
      ),
    );

    return VideoEditorStopMotionFrameStrip(
      frames: frames,
      pixelsPerSecond: pixelsPerSecond,
      selectedFrameIndex: selectedFrameIndex,
      isMultiSelectMode: isMultiSelectMode,
      selectedFrameIndexes: selectedFrameIndexes,
      scrollController: scrollController,
      onReorderChanged: onReorderChanged,
      onFrameTapped: (index) => context.read<ClipEditorBloc>().add(
        isMultiSelectMode
            ? ClipEditorFrameMultiSelectToggled(index)
            : ClipEditorFrameSelected(index),
      ),
      onReorder: (from, to) => commitStopMotionFrames(
        context,
        clipId: clip.id,
        frames: StopMotionFrameOps.reorderFrame(frames, from, to),
      ),
      onBlockMove: (slot) {
        final bloc = context.read<ClipEditorBloc>();
        final selection = bloc.state.selectedFrameIndexes;
        final moved = StopMotionFrameOps.moveFrames(frames, selection, slot);
        // No-op moves return the same instance; skip commit and selection
        // shuffle so the history stays clean.
        if (identical(moved, frames)) return;
        final committed = commitStopMotionFrames(
          context,
          clipId: clip.id,
          frames: moved,
        );
        if (!committed) return;
        // The block now occupies slot..slot+n-1 — keep it selected.
        bloc.add(
          ClipEditorFrameMultiSelectionSet({
            for (var i = 0; i < selection.length; i++) slot + i,
          }),
        );
      },
    );
  }
}

/// Wraps [TimelineOverlayStrips] and memoizes the clip-edge snap-point list
/// so the same [List<int>] reference is passed on every parent rebuild,
/// avoiding redundant bucket-split and snap-set recomputation downstream.
class _CachedOverlayStrips extends StatefulWidget {
  const _CachedOverlayStrips({
    required this.clips,
    required this.totalWidth,
    required this.pixelsPerSecond,
    required this.totalDuration,
    required this.playheadPosition,
    this.onItemTapped,
    this.onItemMoved,
    this.onItemMoving,
    this.onItemTrimmed,
    this.onTrimDragChanged,
    this.onDragStarted,
    this.onDragEnded,
  });

  final List<DivineVideoClip> clips;
  final double totalWidth;
  final double pixelsPerSecond;
  final Duration totalDuration;
  final ValueNotifier<Duration> playheadPosition;
  final ValueChanged<TimelineOverlayItem>? onItemTapped;
  final OverlayMoveCallback? onItemMoved;
  final OverlayMovingCallback? onItemMoving;
  final OverlayTrimCallback? onItemTrimmed;
  final ValueChanged<bool>? onTrimDragChanged;
  final ValueChanged<TimelineOverlayItem>? onDragStarted;
  final VoidCallback? onDragEnded;

  @override
  State<_CachedOverlayStrips> createState() => _CachedOverlayStripsState();
}

class _CachedOverlayStripsState extends State<_CachedOverlayStrips> {
  late List<int> _clipEdgesMs;

  @override
  void initState() {
    super.initState();
    _clipEdgesMs = _computeEdges(widget.clips);
  }

  @override
  void didUpdateWidget(_CachedOverlayStrips old) {
    super.didUpdateWidget(old);
    if (!identical(old.clips, widget.clips) &&
        !_sameEdges(old.clips, widget.clips)) {
      _clipEdgesMs = _computeEdges(widget.clips);
    }
  }

  static List<int> _computeEdges(List<DivineVideoClip> clips) {
    final edges = <int>[0];
    var ms = 0;
    for (final clip in clips) {
      ms += clip.playbackDuration.inMilliseconds;
      edges.add(ms);
    }
    return edges;
  }

  static bool _sameEdges(List<DivineVideoClip> a, List<DivineVideoClip> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].playbackDuration != b[i].playbackDuration) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return TimelineOverlayStrips(
      totalWidth: widget.totalWidth,
      pixelsPerSecond: widget.pixelsPerSecond,
      totalDuration: widget.totalDuration,
      clipEdgesMs: _clipEdgesMs,
      playheadPosition: widget.playheadPosition,
      onItemTapped: widget.onItemTapped,
      onItemMoved: widget.onItemMoved,
      onItemMoving: widget.onItemMoving,
      onItemTrimmed: widget.onItemTrimmed,
      onTrimDragChanged: widget.onTrimDragChanged,
      onDragStarted: widget.onDragStarted,
      onDragEnded: widget.onDragEnded,
    );
  }
}

/// Fades a timeline row out while a clip is being drag-reordered.
///
/// The ruler and the overlay strips both use it so they fade in step.
class _ReorderFade extends StatelessWidget {
  const _ReorderFade({required this.isReordering, required this.child});

  final bool isReordering;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: isReordering ? 0.0 : 1.0,
      duration: TimelineConstants.reorderFadeDuration,
      child: child,
    );
  }
}

/// Bands the stretch of timeline past the maximum clip duration, from [left]
/// to the end of the body.
///
/// Two of these stack up: the striped hatch and the dim wash over it.
class _TimelineOutsideAreaOverlay extends StatelessWidget {
  const _TimelineOutsideAreaOverlay({
    required this.left,
    required this.visible,
    required this.child,
  });

  final double left;
  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // The body's trailing padding already reaches to the far end of the
    // horizontal scroll extent, so the overlay ends with the body.
    return Positioned(
      left: left,
      top: 0,
      bottom: 0,
      right: 0,
      child: IgnorePointer(
        child: Visibility(visible: visible, child: child),
      ),
    );
  }
}

class _TimelineOutsideAreaPainter extends CustomPainter {
  const _TimelineOutsideAreaPainter({required this.stripeColor});

  static const _stripeRotationRadians = 1.05;
  static const double _stripeWidth = 5;
  static const double _stripeGap = 10;
  static final Float64List _stripeTransformStorage =
      (Matrix4.identity()..rotateZ(_stripeRotationRadians)).storage;

  final Color stripeColor;

  @override
  void paint(Canvas canvas, Size size) {
    final stripePaint = Paint()
      ..color = stripeColor
      ..strokeWidth = _stripeWidth
      ..strokeCap = StrokeCap.butt
      ..isAntiAlias = false;

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.transform(_stripeTransformStorage);

    // Diagonal covers the rotated bounding box for any aspect ratio.
    final extent = math
        .sqrt(size.width * size.width + size.height * size.height)
        .ceilToDouble();
    final startX = -extent - ((-extent) % _stripeGap);
    for (var x = startX; x <= extent; x += _stripeGap) {
      canvas.drawLine(Offset(x, -extent), Offset(x, extent), stripePaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TimelineOutsideAreaPainter oldDelegate) {
    return oldDelegate.stripeColor != stripeColor;
  }
}
