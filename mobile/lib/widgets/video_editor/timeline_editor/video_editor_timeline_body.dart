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
  final double scrollPadding;
  final List<DivineVideoClip> clips;
  final double totalWidth;
  final bool isInteracting;

  static const _scrollBottomPadding = 100;

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

    final trimExpand = clipTrimExpand > overlayTrimExpand
        ? clipTrimExpand
        : overlayTrimExpand;
    final showMaxDurationOverlays =
        !isReordering && totalDuration > VideoEditorConstants.maxDuration;
    final outsideExtendWidth = MediaQuery.sizeOf(context).width / 2;

    return HitExpandedBox(
      expandLeft: trimExpand,
      expandRight: trimExpand,
      child: Stack(
        fit: .passthrough,
        clipBehavior: .none,
        children: [
          // Keep stack slots stable during drag-reorder to avoid gesture drops.
          _TimelineMaxDurationStripeOverlay(
            pixelsPerSecond: pixelsPerSecond,
            visible: showMaxDurationOverlays,
            outsideExtendWidth: outsideExtendWidth,
          ),

          Column(
            crossAxisAlignment: .start,
            mainAxisSize: .min,
            children: [
              /// Rules Indicator
              AnimatedOpacity(
                opacity: isReordering ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 200),
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
              const SizedBox(height: TimelineConstants.rulerToBodyGap),

              /// Video clips, or per-frame stills for a stop-motion clip.
              RepaintBoundary(
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

              /// Layers, Filters and Audio-Tracks
              Expanded(
                // The strips are only clipped vertically, so a selected item's
                // trim handle stays visible past the composition's last pixel.
                // The strip itself is exactly totalWidth wide, and every box
                // between here and it hit-tests against its own edge, so the
                // touch was rejected all the way up and the horizontal scroll
                // view took it instead.
                child: HitExpandedBox(
                  expandLeft: overlayTrimExpand,
                  expandRight: overlayTrimExpand,
                  child: AnimatedOpacity(
                    opacity: isReordering ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: ClipRect(
                      clipper: const VerticalOnlyClipper(),
                      child: SingleChildScrollView(
                        controller: overlayStripsScrollController,
                        clipBehavior: Clip.none,
                        physics: isVolumeEditMode
                            ? const NeverScrollableScrollPhysics()
                            : null,
                        padding: EdgeInsets.only(
                          top: 4,
                          bottom:
                              _scrollBottomPadding +
                              MediaQuery.paddingOf(context).bottom,
                        ),
                        child: IgnorePointer(
                          ignoring: isReordering,
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
          _TimelineMaxDurationDimOverlay(
            pixelsPerSecond: pixelsPerSecond,
            visible: showMaxDurationOverlays,
            outsideExtendWidth: outsideExtendWidth,
          ),
        ],
      ),
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

class _TimelineMaxDurationStripeOverlay extends StatelessWidget {
  const _TimelineMaxDurationStripeOverlay({
    required this.pixelsPerSecond,
    required this.visible,
    required this.outsideExtendWidth,
  });

  final double pixelsPerSecond;
  final bool visible;
  final double outsideExtendWidth;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left:
          VideoEditorConstants.maxDuration.inMilliseconds /
          1000 *
          pixelsPerSecond,
      top: 0,
      bottom: 0,
      right: -outsideExtendWidth,
      child: IgnorePointer(
        child: Visibility(
          visible: visible,
          child: CustomPaint(
            painter: _TimelineOutsideAreaPainter(
              stripeColor: context.vineColors.disabled,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class _TimelineMaxDurationDimOverlay extends StatelessWidget {
  const _TimelineMaxDurationDimOverlay({
    required this.pixelsPerSecond,
    required this.visible,
    required this.outsideExtendWidth,
  });

  final double pixelsPerSecond;
  final bool visible;
  final double outsideExtendWidth;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left:
          VideoEditorConstants.maxDuration.inMilliseconds /
          1000 *
          pixelsPerSecond,
      top: 0,
      bottom: 0,
      right: -outsideExtendWidth,
      child: IgnorePointer(
        child: Visibility(
          visible: visible,
          child: ColoredBox(
            color: context.vineColors.surfaceContainerHigh.withValues(
              alpha: 0.3,
            ),
            child: const SizedBox.expand(),
          ),
        ),
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
