import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/constants/video_editor_timeline_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/timeline_overlay_item.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/strips/timeline_trim_handles.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/strips/video_editor_timeline_overlay_item.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/strips/video_editor_timeline_overlay_strip.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/timeline_snap_controller.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/video_editor_timeline_geometry.dart';

class TimelineOverlayPositionedItem extends StatelessWidget {
  const TimelineOverlayPositionedItem({
    required this.item,
    required this.isDragging,
    required this.isSelected,
    required this.snappedStartMs,
    required this.dragDeltaY,
    required this.rowHeight,
    required this.pixelsPerSecond,
    required this.totalDuration,
    required this.clipEdgesMs,
    required this.color,
    required this.isCollapsed,
    required this.trimExpansion,
    required this.onTap,
    required this.onLongPressStart,
    required this.onLongPressMoveUpdate,
    required this.onLongPressEnd,
    super.key,
    this.multiSelectState = OverlayMultiSelectState.none,
    this.onTrimChanged,
    this.onTrimDragChanged,
    this.snapPointsMs,
  });

  final TimelineOverlayItem item;
  final bool isDragging;
  final bool isSelected;

  /// Selection state while the timeline is in draw-layer multi-select mode.
  final OverlayMultiSelectState multiSelectState;
  final int snappedStartMs;
  final double dragDeltaY;
  final double rowHeight;
  final double pixelsPerSecond;
  final Duration totalDuration;

  /// Cumulative clip-boundary edges in ms (`[0, e1, …, eN]`), used to
  /// position items gap-aware so they align with the clip strip.
  final List<int> clipEdgesMs;
  final Color color;
  final bool isCollapsed;
  final double trimExpansion;
  final VoidCallback onTap;
  final VoidCallback onLongPressStart;
  final ValueChanged<LongPressMoveUpdateDetails> onLongPressMoveUpdate;
  final VoidCallback onLongPressEnd;
  final OverlayTrimCallback? onTrimChanged;
  final ValueChanged<bool>? onTrimDragChanged;
  final List<int>? snapPointsMs;

  @override
  Widget build(BuildContext context) {
    // Layout is gap-aware: the clip strip inserts a [clipGap]-wide gap
    // between adjacent clips, so an item's left edge and width must
    // include the accumulated gap pixels of every boundary it passes or
    // spans — otherwise items drift left of the matching clip end by
    // `(clipsPassed × clipGap)` px on a busy timeline.
    final startMs = isDragging ? snappedStartMs : item.startTime.inMilliseconds;
    final endMs = startMs + item.duration.inMilliseconds;
    final x = timelineMsToOverlayOffset(clipEdgesMs, startMs, pixelsPerSecond);
    final itemWidth =
        timelineMsToOverlayOffset(clipEdgesMs, endMs, pixelsPerSecond) - x;

    // Don't render if the item has zero width.
    if (itemWidth <= 0) return const SizedBox.shrink();

    final row = isCollapsed ? 0 : item.row;
    final baseY = row * rowHeight + TimelineConstants.overlayRowGap / 2;

    final y = isDragging ? baseY + dragDeltaY : baseY;

    if (isSelected && !isDragging) {
      return Positioned(
        left: x - trimExpansion,
        top: y,
        width: itemWidth + trimExpansion * 2,
        child: _OverlayItemGestureWrapper(
          semanticLabel: item.label,
          // Unreachable while multi-selecting: entering the mode clears the
          // single selection, so the trim-handle variant never coexists with a
          // multi-select overlay.
          multiSelectState: OverlayMultiSelectState.none,
          onTap: onTap,
          onLongPressStart: onLongPressStart,
          onLongPressMoveUpdate: onLongPressMoveUpdate,
          onLongPressEnd: onLongPressEnd,
          child: _TrimmableOverlayTile(
            item: item,
            width: itemWidth,
            height: rowHeight,
            color: color,
            pixelsPerSecond: pixelsPerSecond,
            totalDuration: totalDuration,
            clipEdgesMs: clipEdgesMs,
            onTrimChanged: onTrimChanged,
            onTrimDragChanged: onTrimDragChanged,
            trimExpansion: trimExpansion,
            snapPointsMs: snapPointsMs,
          ),
        ),
      );
    }

    return Positioned(
      left: x,
      top: y,
      child: _OverlayItemGestureWrapper(
        semanticLabel: item.label,
        multiSelectState: multiSelectState,
        onTap: onTap,
        onLongPressStart: onLongPressStart,
        onLongPressMoveUpdate: onLongPressMoveUpdate,
        onLongPressEnd: onLongPressEnd,
        child: TimelineOverlayItemTile(
          item: item,
          width: itemWidth,
          height: rowHeight,
          color: color,
          isDragging: isDragging,
          multiSelectState: multiSelectState,
        ),
      ),
    );
  }
}

class _OverlayItemGestureWrapper extends StatelessWidget {
  const _OverlayItemGestureWrapper({
    required this.semanticLabel,
    required this.multiSelectState,
    required this.onTap,
    required this.onLongPressStart,
    required this.onLongPressMoveUpdate,
    required this.onLongPressEnd,
    required this.child,
  });

  final String semanticLabel;
  final OverlayMultiSelectState multiSelectState;
  final VoidCallback onTap;
  final VoidCallback onLongPressStart;
  final ValueChanged<LongPressMoveUpdateDetails> onLongPressMoveUpdate;
  final VoidCallback onLongPressEnd;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isMultiSelecting = multiSelectState != OverlayMultiSelectState.none;
    return Semantics(
      label: semanticLabel,
      // Long-press drag is disabled while multi-selecting, so drop that hint.
      hint: isMultiSelecting
          ? null
          : context.l10n.videoEditorTimelineLongPressToDragHint,
      button: true,
      // Announce non-mergeable tiles as disabled — their tap is a no-op while
      // multi-selecting — and only report a selected state on tiles that can
      // actually be toggled.
      enabled: multiSelectState == OverlayMultiSelectState.disabled
          ? false
          : null,
      selected: switch (multiSelectState) {
        OverlayMultiSelectState.none ||
        OverlayMultiSelectState.disabled => null,
        OverlayMultiSelectState.selected => true,
        OverlayMultiSelectState.unselected => false,
      },
      child: GestureDetector(
        onTap: onTap,
        onLongPressStart: (_) => onLongPressStart(),
        onLongPressMoveUpdate: onLongPressMoveUpdate,
        onLongPressEnd: (_) => onLongPressEnd(),
        child: child,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tile widgets
// ---------------------------------------------------------------------------

/// Overlay item tile wrapped with trim handles for duration adjustment.
class _TrimmableOverlayTile extends StatefulWidget {
  const _TrimmableOverlayTile({
    required this.item,
    required this.width,
    required this.height,
    required this.color,
    required this.pixelsPerSecond,
    required this.totalDuration,
    required this.clipEdgesMs,
    this.onTrimChanged,
    this.onTrimDragChanged,
    this.trimExpansion = 0,
    this.snapPointsMs,
  });

  final TimelineOverlayItem item;
  final double width;
  final double height;
  final Color color;
  final double pixelsPerSecond;
  final Duration totalDuration;

  /// Cumulative clip-boundary edges in ms (`[0, e1, …, eN]`), used to
  /// convert trim-handle pixel deltas gap-aware.
  final List<int> clipEdgesMs;
  final OverlayTrimCallback? onTrimChanged;
  final ValueChanged<bool>? onTrimDragChanged;
  final double trimExpansion;
  final List<int>? snapPointsMs;

  @override
  State<_TrimmableOverlayTile> createState() => _TrimmableOverlayTileState();
}

class _TrimmableOverlayTileState extends State<_TrimmableOverlayTile> {
  static const _autoScrollEdge = 60.0;
  static const _autoScrollSpeed = 6.0;

  /// Whether haptic feedback has already fired for the current boundary hit.
  bool _hitBoundary = false;

  /// Whether auto-scroll fired on the last drag frame.
  /// When `true`, snap points and boundary haptics are suppressed.
  bool _isAutoScrolling = false;

  /// Snap controllers for the left and right trim handles.
  late TimelineSnapController _leftSnap;
  late TimelineSnapController _rightSnap;

  /// Which snap controller is active during this gesture.
  TimelineSnapController? _activeSnap;

  @override
  void initState() {
    super.initState();
    _leftSnap = TimelineSnapController(
      direction: SnapEdgeDirection.positive,
      pixelsPerSecond: widget.pixelsPerSecond,
    );
    _rightSnap = TimelineSnapController(
      direction: SnapEdgeDirection.negative,
      pixelsPerSecond: widget.pixelsPerSecond,
    );
  }

  @override
  void didUpdateWidget(_TrimmableOverlayTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pixelsPerSecond != widget.pixelsPerSecond) {
      _leftSnap.pixelsPerSecond = widget.pixelsPerSecond;
      _rightSnap.pixelsPerSecond = widget.pixelsPerSecond;
    }
  }

  void _onDragStart() {
    _hitBoundary = false;
    _isAutoScrolling = false;
    _activeSnap = null;
    _leftSnap.reset();
    _rightSnap.reset();
    final item = widget.item;
    _leftSnap.begin(
      item.startTime.inMilliseconds,
      initialExcludeMs: item.startTime.inMilliseconds,
    );
    _rightSnap.begin(
      item.endTime.inMilliseconds,
      initialExcludeMs: item.endTime.inMilliseconds,
    );
    widget.onTrimDragChanged?.call(true);
  }

  void _onDragEnd() {
    _hitBoundary = false;
    _isAutoScrolling = false;
    _activeSnap = null;
    _leftSnap.reset();
    _rightSnap.reset();
    widget.onTrimDragChanged?.call(false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: widget.trimExpansion),
      child: TimelineTrimHandles(
        height: widget.height - TimelineConstants.overlayRowGap,
        width: widget.width,
        onDragStart: _onDragStart,
        onDragEnd: _onDragEnd,
        onLeftDragUpdate: _onLeftTrim,
        onRightDragUpdate: _onRightTrim,
        onDragPositionUpdate: _handleTrimAutoScroll,
        child: TimelineOverlayItemTile(
          item: widget.item,
          width: widget.width,
          height: widget.height,
          color: widget.color,
          isSelected: true,
        ),
      ),
    );
  }

  void _handleTrimAutoScroll(Offset globalPosition) {
    final scrollable = Scrollable.maybeOf(context, axis: Axis.horizontal);
    if (scrollable == null) {
      _isAutoScrolling = false;
      return;
    }

    final renderBox = scrollable.context.findRenderObject()! as RenderBox;
    final localX = renderBox.globalToLocal(globalPosition).dx;
    final viewportWidth = renderBox.size.width;

    double delta = 0;
    if (localX < _autoScrollEdge) {
      delta = -_autoScrollSpeed * (1 - localX / _autoScrollEdge);
    } else if (localX > viewportWidth - _autoScrollEdge) {
      delta =
          _autoScrollSpeed * (1 - (viewportWidth - localX) / _autoScrollEdge);
    }

    if (delta == 0) {
      _isAutoScrolling = false;
      return;
    }

    final pos = scrollable.position;
    final before = pos.pixels;
    final target = (before + delta).clamp(
      pos.minScrollExtent,
      pos.maxScrollExtent,
    );
    if (target == before) {
      _isAutoScrolling = false;
      return;
    }
    pos.jumpTo(target);
    _isAutoScrolling = true;

    // Sync video position to match the new scroll offset.
    final seekMs = (target / widget.pixelsPerSecond * 1000).round();
    context.read<VideoEditorMainBloc>().add(
      VideoEditorSeekRequested(Duration(milliseconds: seekMs)),
    );

    // Compensate the active snap controller so the handle tracks the finger.
    final scrolled = target - before;
    _activeSnap?.compensateScroll(scrolled);
  }

  void _onLeftTrim(double dx) {
    _activeSnap ??= _leftSnap;
    _leftSnap.accumulate(dx);

    final pps = widget.pixelsPerSecond;
    // Gap-aware px→ms: convert the handle origin to pixels, add the
    // accumulated drag pixels, then map back so the result tracks the
    // clip strip across clip gaps.
    final originPx = timelineMsToOverlayOffset(
      widget.clipEdgesMs,
      _leftSnap.originMs,
      pps,
    );
    final rawStartMs = timelineOverlayOffsetToMs(
      widget.clipEdgesMs,
      originPx + _leftSnap.effectiveAccPx,
      pps,
      widget.totalDuration.inMilliseconds,
    );

    // Disable snap points while auto-scrolling to avoid jarring jumps.
    final snapPoints = !_isAutoScrolling && widget.snapPointsMs != null
        ? Set<int>.of(widget.snapPointsMs!)
        : null;
    final posMs = _leftSnap.update(rawStartMs, snapPoints);

    final clampedMs = posMs.clamp(
      0,
      math.max(
        widget.totalDuration.inMilliseconds,
        _rightSnap.originMs,
      ),
    ) as int;

    final atMinTrim =
        (_rightSnap.originMs - clampedMs) <
        TimelineConstants.minTrimDuration.inMilliseconds;
    final atBoundary = clampedMs != posMs || atMinTrim;

    // Suppress boundary haptics during auto-scroll.
    if (atBoundary && !_hitBoundary && !_isAutoScrolling) {
      HapticFeedback.heavyImpact();
    }
    _hitBoundary = atBoundary;

    if (atMinTrim) return;

    var newStartMs = clampedMs;
    var newEndMs = _rightSnap.originMs;

    // When maxDuration is set (e.g. sound items), the item cannot grow
    // beyond that limit. Convert the excess into a move instead.
    final maxMs = widget.item.maxDuration?.inMilliseconds;
    if (maxMs != null && (newEndMs - newStartMs) > maxMs) {
      newEndMs = newStartMs + maxMs;
      // Clamp the end within the timeline.
      if (newEndMs > widget.totalDuration.inMilliseconds) {
        newEndMs = widget.totalDuration.inMilliseconds;
        newStartMs = newEndMs - maxMs;
      }
    }

    widget.onTrimChanged?.call(
      item: widget.item,
      isStart: true,
      startTime: Duration(milliseconds: newStartMs),
      endTime: Duration(milliseconds: newEndMs),
    );
  }

  void _onRightTrim(double dx) {
    _activeSnap ??= _rightSnap;
    _rightSnap.accumulate(-dx);

    final pps = widget.pixelsPerSecond;
    // Gap-aware px→ms for the right handle. The right snap accumulates
    // negated drag pixels, so subtract them from the origin offset.
    final originPx = timelineMsToOverlayOffset(
      widget.clipEdgesMs,
      _rightSnap.originMs,
      pps,
    );
    final rawEndMs = timelineOverlayOffsetToMs(
      widget.clipEdgesMs,
      originPx - _rightSnap.effectiveAccPx,
      pps,
      widget.totalDuration.inMilliseconds,
    );

    // Disable snap points while auto-scrolling to avoid jarring jumps.
    final snapPoints = !_isAutoScrolling && widget.snapPointsMs != null
        ? Set<int>.of(widget.snapPointsMs!)
        : null;
    final posMs = _rightSnap.update(rawEndMs, snapPoints);

    final clampedMs = posMs.clamp(
      _leftSnap.originMs,
      widget.totalDuration.inMilliseconds,
    );

    final atMinTrim =
        (clampedMs - _leftSnap.originMs) <
        TimelineConstants.minTrimDuration.inMilliseconds;
    final atBoundary = clampedMs != posMs || atMinTrim;

    // Suppress boundary haptics during auto-scroll.
    if (atBoundary && !_hitBoundary && !_isAutoScrolling) {
      HapticFeedback.heavyImpact();
    }
    _hitBoundary = atBoundary;

    if (atMinTrim) return;

    var newStartMs = _leftSnap.originMs;
    var newEndMs = clampedMs;

    // When maxDuration is set (e.g. sound items), the item cannot grow
    // beyond that limit. Convert the excess into a move instead.
    final maxMs = widget.item.maxDuration?.inMilliseconds;
    if (maxMs != null && (newEndMs - newStartMs) > maxMs) {
      newStartMs = newEndMs - maxMs;
      // Clamp the start within the timeline.
      if (newStartMs < 0) {
        newStartMs = 0;
        newEndMs = maxMs;
      }
    }

    widget.onTrimChanged?.call(
      item: widget.item,
      isStart: false,
      startTime: Duration(milliseconds: newStartMs),
      endTime: Duration(milliseconds: newEndMs),
    );
  }
}
