// ABOUTME: Generic overlay strip widget for the video editor timeline.
// ABOUTME: Renders layer / filter / sound items in rows with long-press
// ABOUTME: drag to reposition (time + row) and trim handles on selection.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/constants/video_editor_timeline_constants.dart';
import 'package:openvine/models/timeline_overlay_item.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/strips/video_editor_timeline_drop_indicator_line.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/strips/video_editor_timeline_overlay_item.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/strips/video_editor_timeline_positioned_item.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/timeline_snap_controller.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/video_editor_timeline_geometry.dart';

/// Callback reporting a trim / resize change for an overlay item.
///
/// [startTime] and [duration] are non-null when the resize extends
/// beyond the original item boundary (overlays have no fixed content
/// length so they can grow in either direction).
typedef OverlayTrimCallback = void Function({
  required TimelineOverlayItem item,
  required Duration startTime,
  required Duration endTime,
  required bool isStart,
});

/// Callback reporting an item was moved to a new start time and row.
///
/// When [insertAbove] is `true`, the item should keep the target row
/// and existing overlapping items shift down.
typedef OverlayMoveCallback = void Function({
  required TimelineOverlayItem item,
  required Duration startTime,
  required int row,
  required bool insertAbove,
});

/// Called on every drag-move frame with the live (snapped) start time.
typedef OverlayMovingCallback = void Function({
  required TimelineOverlayItem item,
  required Duration startTime,
});

/// A generic strip that displays [TimelineOverlayItem]s in rows.
///
/// Supports:
/// - Long-press to start dragging
/// - Horizontal drag → change start time
/// - Vertical drag → change row / z-index (new rows created on demand)
/// - Trim handles on selected item
/// - Collapse mode (all items in a single row)
class TimelineOverlayStrip extends StatefulWidget {
  const TimelineOverlayStrip({
    required this.items,
    required this.rowCount,
    required this.totalWidth,
    required this.pixelsPerSecond,
    required this.totalDuration,
    required this.clipEdgesMs,
    required this.color,
    this.rowHeight = TimelineConstants.overlayRowHeight,
    this.isCollapsed = false,
    this.selectedItemId,
    this.isLayerMultiSelectMode = false,
    this.multiSelectedLayerIds = const {},
    this.snapPointsMs,
    this.onItemTapped,
    this.onItemMoved,
    this.onItemMoving,
    this.onTrimChanged,
    this.onTrimDragChanged,
    this.onDragStarted,
    this.onDragEnded,
    super.key,
  });

  /// Items to display, pre-filtered by type and sorted by row.
  final List<TimelineOverlayItem> items;

  /// Number of rows to display.
  final int rowCount;

  /// Total scrollable width in pixels (matches clip strip).
  final double totalWidth;

  /// Current zoom level (pixels per second of video).
  final double pixelsPerSecond;

  /// Total video duration — used to clamp item positions.
  final Duration totalDuration;

  /// Cumulative clip-boundary edges in ms (`[0, e1, …, eN]`), used to
  /// position and drag items gap-aware so they align with the clip strip.
  final List<int> clipEdgesMs;

  /// Background colour for item tiles.
  final Color color;

  /// Height of a single row in this strip.
  final double rowHeight;

  /// Whether the strip is in collapsed mode (single-row summary).
  final bool isCollapsed;

  /// ID of the currently selected item (shows trim handles).
  final String? selectedItemId;

  /// Whether the timeline is in draw-layer multi-select mode. While active,
  /// tiles show a selection overlay and long-press drag is disabled.
  final bool isLayerMultiSelectMode;

  /// Layer ids currently selected for combining, used to render the per-tile
  /// selection state while [isLayerMultiSelectMode] is active.
  final Set<String> multiSelectedLayerIds;

  /// Edge positions (in ms) from other overlay items and clip
  /// boundaries. Used for cross-layer snap during drag and trim.
  final List<int>? snapPointsMs;

  /// Called when an item tile is tapped.
  final ValueChanged<TimelineOverlayItem>? onItemTapped;

  /// Called when an item is moved via drag.
  final OverlayMoveCallback? onItemMoved;

  /// Called on every drag-move frame with the live snapped start time.
  /// Use this to update the editor layer in real-time during the drag.
  final OverlayMovingCallback? onItemMoving;

  /// Called when a trim handle is dragged.
  final OverlayTrimCallback? onTrimChanged;

  /// Called when a trim drag starts (`true`) or ends (`false`).
  final ValueChanged<bool>? onTrimDragChanged;

  /// Called when an item long-press drag starts.
  final ValueChanged<TimelineOverlayItem>? onDragStarted;

  /// Called when the drag gesture ends.
  final VoidCallback? onDragEnded;

  @override
  State<TimelineOverlayStrip> createState() => _TimelineOverlayStripState();
}

class _TimelineOverlayStripState extends State<TimelineOverlayStrip> {
  /// The item currently being dragged, or `null`.
  String? _draggingId;

  /// Live drag position — updated every gesture frame via the notifier
  /// so only the dragged item and drop indicator rebuild, not the full strip.
  final _dragPosition = ValueNotifier<_DragPos>(_DragPos.zero);

  /// The row the item was on when the drag started.
  int _dragStartRow = 0;

  /// Snap controller for the horizontal drag (tracks left edge of item).
  late TimelineSnapController _dragSnap;

  /// Previous horizontal offset-from-origin used to compute per-frame deltas.
  double _prevDragOffsetX = 0;

  /// Cumulative scroll offset added by auto-scroll during the current drag.
  double _scrollCompensationY = 0;

  /// Distance from viewport edge that triggers auto-scroll.
  static const _autoScrollEdge = 40.0;

  /// Max pixels scrolled per gesture frame when auto-scrolling.
  static const _autoScrollSpeed = 4.0;

  /// Edge distance for horizontal auto-scroll.
  static const _hAutoScrollEdge = 60.0;

  /// Max pixels scrolled per frame for horizontal auto-scroll.
  static const _hAutoScrollSpeed = 6.0;

  double get _effectiveRowHeight => widget.rowHeight;

  @override
  void initState() {
    super.initState();
    _dragSnap = TimelineSnapController(
      direction: SnapEdgeDirection.positive,
      pixelsPerSecond: widget.pixelsPerSecond,
    );
  }

  @override
  void didUpdateWidget(TimelineOverlayStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pixelsPerSecond != widget.pixelsPerSecond) {
      _dragSnap.pixelsPerSecond = widget.pixelsPerSecond;
    }
  }

  @override
  void dispose() {
    _dragPosition.dispose();
    super.dispose();
  }

  double get _trimExpansion => widget.selectedItemId != null
      ? TimelineConstants.trimHandleWidth + 12.0
      : 0.0;

  /// Returns items sorted so the dragged or selected item is last
  /// (painted on top in the [Stack]).
  List<TimelineOverlayItem> _sortedItems() {
    final topId = _draggingId ?? widget.selectedItemId;
    // No active item → original order is fine.
    if (topId == null) return widget.items;
    final items = List<TimelineOverlayItem>.of(widget.items);
    final idx = items.indexWhere((item) => item.id == topId);
    // Not found or already last → nothing to move.
    if (idx == -1 || idx == items.length - 1) return items;
    // Move item to end so it paints on top in the Stack.
    items.add(items.removeAt(idx));
    return items;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();

    final displayRowCount = widget.isCollapsed ? 1 : widget.rowCount;
    final sortedItems = _sortedItems();

    return SizedBox(
      width: widget.totalWidth,
      height: displayRowCount * _effectiveRowHeight,
      child: Stack(
        clipBehavior: .none,
        children: [
          // Drop indicator — rebuilt only when drag position changes,
          // not on every parent setState (drag start / end only).
          ValueListenableBuilder<_DragPos>(
            valueListenable: _dragPosition,
            builder: (context, _, _) {
              final y = _dropIndicatorLineY();
              if (y == null) return const SizedBox.shrink();
              return TimelineDropIndicatorLine(lineY: y);
            },
          ),
          // Stable ValueKey + child: keeps elements mounted across
          // drag-state changes and reuses non-dragged subtrees.
          for (final item in sortedItems)
            ValueListenableBuilder<_DragPos>(
              key: ValueKey(item.id),
              valueListenable: _dragPosition,
              builder: (context, pos, child) {
                if (_draggingId == item.id) {
                  return TimelineOverlayPositionedItem(
                    item: item,
                    isDragging: true,
                    isSelected: widget.selectedItemId == item.id,
                    snappedStartMs: pos.startMs,
                    dragDeltaY: pos.deltaY,
                    rowHeight: _effectiveRowHeight,
                    pixelsPerSecond: widget.pixelsPerSecond,
                    totalDuration: widget.totalDuration,
                    clipEdgesMs: widget.clipEdgesMs,
                    color: widget.color,
                    isCollapsed: widget.isCollapsed,
                    trimExpansion: _trimExpansion,
                    snapPointsMs: widget.snapPointsMs,
                    onTrimChanged: widget.onTrimChanged,
                    onTrimDragChanged: widget.onTrimDragChanged,
                    onTap: () => widget.onItemTapped?.call(item),
                    onLongPressStart: () => _onLongPressStart(item),
                    onLongPressMoveUpdate: (details) =>
                        _onLongPressMoveUpdate(details, item, displayRowCount),
                    onLongPressEnd: () => _onLongPressEnd(item),
                  );
                }
                return child!;
              },
              child: TimelineOverlayPositionedItem(
                item: item,
                isDragging: false,
                isSelected: widget.selectedItemId == item.id,
                multiSelectState: _multiSelectStateFor(item),
                snappedStartMs: 0,
                dragDeltaY: 0,
                rowHeight: _effectiveRowHeight,
                pixelsPerSecond: widget.pixelsPerSecond,
                totalDuration: widget.totalDuration,
                clipEdgesMs: widget.clipEdgesMs,
                color: widget.color,
                isCollapsed: widget.isCollapsed,
                trimExpansion: _trimExpansion,
                snapPointsMs: widget.snapPointsMs,
                onTrimChanged: widget.onTrimChanged,
                onTrimDragChanged: widget.onTrimDragChanged,
                onTap: () => widget.onItemTapped?.call(item),
                onLongPressStart: () => _onLongPressStart(item),
                onLongPressMoveUpdate: (details) =>
                    _onLongPressMoveUpdate(details, item, displayRowCount),
                onLongPressEnd: () => _onLongPressEnd(item),
              ),
            ),
        ],
      ),
    );
  }

  /// Computes the drag target info: new start time, target row, and
  /// whether the cursor is in the upper half of the row cell.
  ({int newStartMs, int targetRow, bool insertAbove})? _dragTargetInfo() {
    final draggedItem = widget.items.where((i) => i.id == _draggingId);
    if (draggedItem.isEmpty) return null;

    final item = draggedItem.first;
    final pos = _dragPosition.value;

    final maxStartMs = (widget.totalDuration - item.duration).inMilliseconds;
    final newStartMs = pos.startMs.clamp(0, maxStartMs);

    final rowDelta = (pos.deltaY / _effectiveRowHeight).round();
    final unclampedRow = _dragStartRow + rowDelta;
    final targetRow = math.max(0, unclampedRow);

    // When the unclamped row is out of bounds the user is dragging
    // far beyond the existing rows → lock insertAbove accordingly
    // so the indicator doesn't oscillate.
    final bool insertAbove;
    if (unclampedRow < 0) {
      insertAbove = true;
    } else {
      final subRowOffset = pos.deltaY / _effectiveRowHeight - rowDelta;
      insertAbove = subRowOffset < 0;
    }
    return (
      newStartMs: newStartMs,
      targetRow: targetRow,
      insertAbove: insertAbove,
    );
  }

  /// Returns `true` when `item` at `newStartMs` would overlap another
  /// item on `targetRow`.
  bool _wouldOverlapAt(
    TimelineOverlayItem item,
    int newStartMs,
    int targetRow,
  ) {
    final newEndMs = newStartMs + item.duration.inMilliseconds;
    return widget.items.any((other) {
      if (other.id == item.id) return false;
      if (other.row != targetRow) return false;
      final otherStartMs = other.startTime.inMilliseconds;
      final otherEndMs = otherStartMs + other.duration.inMilliseconds;
      return newStartMs < otherEndMs && otherStartMs < newEndMs;
    });
  }

  double? _dropIndicatorLineY() {
    final info = _dragTargetInfo();
    if (info == null) return null;
    if (_draggingId == null) return null;

    final matchingItems = widget.items.where((i) => i.id == _draggingId);
    if (matchingItems.isEmpty) return null;

    final item = matchingItems.first;
    if (!_wouldOverlapAt(item, info.newStartMs, info.targetRow)) {
      return null;
    }

    // Above: line at the top of the target row.
    // Below: line at the bottom of the target row.
    return info.insertAbove
        ? info.targetRow * _effectiveRowHeight
        : (info.targetRow + 1) * _effectiveRowHeight;
  }

  // -- Long-press drag callbacks -------------------------------------------

  /// Resolves the per-tile multi-select visual state for [item].
  OverlayMultiSelectState _multiSelectStateFor(TimelineOverlayItem item) {
    if (!widget.isLayerMultiSelectMode) return OverlayMultiSelectState.none;
    if (!isMergeableDrawLayer(item.layer)) {
      return OverlayMultiSelectState.disabled;
    }
    return widget.multiSelectedLayerIds.contains(item.id)
        ? OverlayMultiSelectState.selected
        : OverlayMultiSelectState.unselected;
  }

  void _onLongPressStart(TimelineOverlayItem item) {
    // In multi-select mode a tile only toggles on tap; dragging is disabled.
    if (widget.isLayerMultiSelectMode) return;
    final mainBloc = context.read<VideoEditorMainBloc?>();
    if (mainBloc?.state.isVolumeEditMode == true) return;
    HapticFeedback.mediumImpact();
    _dragSnap.reset();
    _dragSnap.begin(
      item.startTime.inMilliseconds,
      initialExcludeMs: item.startTime.inMilliseconds,
    );
    _dragPosition.value = _DragPos(
      startMs: item.startTime.inMilliseconds,
      deltaY: 0,
    );
    setState(() {
      _draggingId = item.id;
      _prevDragOffsetX = 0;
      _scrollCompensationY = 0;
      _dragStartRow = item.row;
    });

    final bloc = context.read<TimelineOverlayBloc>();
    bloc.add(const TimelineOverlayItemSelected(null));

    widget.onDragStarted?.call(item);
  }

  void _onLongPressMoveUpdate(
    LongPressMoveUpdateDetails details,
    TimelineOverlayItem item,
    int displayRowCount,
  ) {
    final pps = widget.pixelsPerSecond;
    final itemDurationMs = item.duration.inMilliseconds;
    final totalMs = widget.totalDuration.inMilliseconds;
    final maxStartMs = totalMs - itemDurationMs;

    // Compute per-frame delta from the previous absolute offset.
    final currentOffsetX = details.offsetFromOrigin.dx;
    final dx = currentOffsetX - _prevDragOffsetX;
    _prevDragOffsetX = currentOffsetX;

    _dragSnap.accumulate(dx);

    // Gap-aware px→ms: convert the drag origin to pixels, add the
    // accumulated drag pixels, then map back so the dragged item tracks
    // the clip strip across clip gaps.
    final originPx = timelineMsToOverlayOffset(
      widget.clipEdgesMs,
      _dragSnap.originMs,
      pps,
    );
    final rawStartMs = timelineOverlayOffsetToMs(
      widget.clipEdgesMs,
      originPx + _dragSnap.effectiveAccPx,
      pps,
      totalMs,
    ).clamp(0, maxStartMs);

    // Auto-scroll when dragging near viewport edges.
    final isAutoScrollingV = _handleAutoScroll(details.globalPosition);
    final isAutoScrollingH = _handleHorizontalAutoScroll(
      details.globalPosition,
    );
    final isAutoScrolling = isAutoScrollingV || isAutoScrollingH;

    // Expose both left and right edge as snap candidates.
    // Disable snapping while auto-scrolling to avoid jarring jumps.
    Set<int>? snapPoints;
    if (!isAutoScrolling &&
        widget.snapPointsMs != null &&
        widget.snapPointsMs!.isNotEmpty) {
      snapPoints = {
        ...widget.snapPointsMs!,
        ...widget.snapPointsMs!.map((sp) => sp - itemDurationMs),
      };
    }

    final snappedStartMs = _dragSnap.update(rawStartMs, snapPoints);

    final clampedStartMs = snappedStartMs.clamp(0, maxStartMs);
    widget.onItemMoving?.call(
      item: item,
      startTime: Duration(milliseconds: clampedStartMs),
    );

    _dragPosition.value = _DragPos(
      startMs: clampedStartMs,
      deltaY: details.offsetFromOrigin.dy + _scrollCompensationY,
    );
  }

  void _onLongPressEnd(TimelineOverlayItem item) {
    if (_draggingId == null) return;

    final info = _dragTargetInfo();
    if (info == null) return;

    widget.onItemMoved?.call(
      item: item,
      startTime: Duration(milliseconds: info.newStartMs),
      row: info.targetRow,
      insertAbove: info.insertAbove,
    );

    _dragSnap.reset();
    setState(() {
      _draggingId = null;
      _prevDragOffsetX = 0;
      _scrollCompensationY = 0;
    });
    _dragPosition.value = _DragPos.zero;
    widget.onDragEnded?.call();
  }

  // -- Auto-scroll near viewport edges during drag --------------------------

  /// Returns `true` when auto-scrolling was applied this frame.
  bool _handleAutoScroll(Offset globalPosition) {
    final scrollable = Scrollable.maybeOf(context);
    if (scrollable == null) return false;

    final renderBox = scrollable.context.findRenderObject()! as RenderBox;
    final localY = renderBox.globalToLocal(globalPosition).dy;
    final viewportHeight = renderBox.size.height;
    // Shrink the bottom edge by the system safe-area so the trigger zone
    // sits above the home-indicator / navigation bar.
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final effectiveBottom = viewportHeight - bottomInset;

    double delta = 0;
    if (localY < _autoScrollEdge) {
      delta = -_autoScrollSpeed * (1 - localY / _autoScrollEdge);
    } else if (localY > effectiveBottom - _autoScrollEdge) {
      delta =
          _autoScrollSpeed * (1 - (effectiveBottom - localY) / _autoScrollEdge);
    }

    if (delta == 0) return false;

    final pos = scrollable.position;
    final before = pos.pixels;
    final target = (before + delta).clamp(
      pos.minScrollExtent,
      pos.maxScrollExtent,
    );
    if (target == before) return false;
    pos.jumpTo(target);

    // Accumulate scroll compensation so the next setState keeps the
    // item under the finger.
    _scrollCompensationY += target - before;
    return true;
  }

  /// Horizontal auto-scroll when the finger is near the left/right edge.
  ///
  /// Returns `true` when scrolling was applied this frame.
  bool _handleHorizontalAutoScroll(Offset globalPosition) {
    final scrollable = Scrollable.maybeOf(context, axis: Axis.horizontal);
    if (scrollable == null) return false;

    final renderBox = scrollable.context.findRenderObject()! as RenderBox;
    final localX = renderBox.globalToLocal(globalPosition).dx;
    final viewportWidth = renderBox.size.width;

    double delta = 0;
    if (localX < _hAutoScrollEdge) {
      delta = -_hAutoScrollSpeed * (1 - localX / _hAutoScrollEdge);
    } else if (localX > viewportWidth - _hAutoScrollEdge) {
      delta =
          _hAutoScrollSpeed * (1 - (viewportWidth - localX) / _hAutoScrollEdge);
    }

    if (delta == 0) return false;

    final pos = scrollable.position;
    final before = pos.pixels;
    final target = (before + delta).clamp(
      pos.minScrollExtent,
      pos.maxScrollExtent,
    );
    if (target == before) return false;
    pos.jumpTo(target);

    // Compensate the snap controller so the item tracks the finger.
    _dragSnap.compensateScroll(target - before);
    return true;
  }
}

/// Immutable drag position used by [_TimelineOverlayStripState._dragPosition].
class _DragPos {
  const _DragPos({required this.startMs, required this.deltaY});

  static const zero = _DragPos(startMs: 0, deltaY: 0);

  /// Horizontal position: snapped item start in milliseconds.
  final int startMs;

  /// Vertical position: cumulative drag delta in pixels.
  final double deltaY;
}
