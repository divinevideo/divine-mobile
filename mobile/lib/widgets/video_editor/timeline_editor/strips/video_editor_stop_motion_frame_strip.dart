import 'dart:async';
import 'dart:io';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/constants/video_editor_timeline_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/stop_motion_clip_frame.dart';

/// Timeline strip for a frames-only stop-motion clip: one tile per captured
/// still, laid out by each still's hold duration so the strip stays aligned
/// with the timeline playhead.
///
/// Tapping a tile selects it (via [onFrameTapped]); long-pressing and dragging
/// reorders the stills (via [onReorder]). In multi-select mode, long-pressing
/// a *selected* tile drags the whole selection as one block (via
/// [onBlockMove]). This widget is presentational — it owns only the drag
/// gesture state; the actual selection and reorder commit live in the caller.
class VideoEditorStopMotionFrameStrip extends StatefulWidget {
  const VideoEditorStopMotionFrameStrip({
    required this.frames,
    required this.pixelsPerSecond,
    required this.onFrameTapped,
    required this.onReorder,
    this.selectedFrameIndex,
    this.isMultiSelectMode = false,
    this.selectedFrameIndexes = const {},
    this.onBlockMove,
    this.scrollController,
    this.onReorderChanged,
    super.key,
  });

  /// The clip's captured stills, in playback order.
  final List<StopMotionClipFrame> frames;

  /// Horizontal pixels per second — the strip's tiles are sized by their hold
  /// duration times this, matching the rest of the timeline geometry.
  final double pixelsPerSecond;

  /// Index of the currently selected still, highlighted with a border.
  final int? selectedFrameIndex;

  /// Whether taps toggle membership in [selectedFrameIndexes] instead of
  /// selecting a single still. Single-tile drag reorder is disabled while
  /// active; long-pressing a selected tile block-drags the selection instead.
  final bool isMultiSelectMode;

  /// Indexes of the stills selected in multi-select mode, each highlighted
  /// like the single selection.
  final Set<int> selectedFrameIndexes;

  /// Called with the tapped still's index.
  final ValueChanged<int> onFrameTapped;

  /// Called when a drag reorder settles, with the still's original and final
  /// indices. A single-item move — [StopMotionFrameOps.reorderFrame] reproduces
  /// it on the source list.
  final void Function(int from, int to) onReorder;

  /// Called when a multi-select block drag settles, with the insertion slot
  /// within the list of *remaining* (unselected) stills —
  /// [StopMotionFrameOps.moveFrames] reproduces the move on the source list.
  final ValueChanged<int>? onBlockMove;

  /// Timeline scroll controller, used to auto-scroll while dragging near an
  /// edge.
  final ScrollController? scrollController;

  /// Reports the start (`true`) and end (`false`) of a reorder drag so the
  /// timeline can fade sibling rows out, matching the clip strip.
  final ValueChanged<bool>? onReorderChanged;

  @override
  State<VideoEditorStopMotionFrameStrip> createState() =>
      _VideoEditorStopMotionFrameStripState();
}

class _VideoEditorStopMotionFrameStripState
    extends State<VideoEditorStopMotionFrameStrip> {
  static const _animDuration = Duration(milliseconds: 200);
  static const _autoScrollEdgeZone = 40.0;
  static const _maxAutoScrollPxPerFrame = 8.0;

  /// Local, live-reordered copy of the stills while a drag is in progress.
  late List<StopMotionClipFrame> _orderedFrames;

  bool _isReordering = false;

  /// Current visual slot of the dragged tile within [_orderedFrames].
  int? _dragIndex;

  /// The dragged still's index in [widget.frames] when the drag began.
  int _dragStartIndex = 0;

  /// Whether the active drag moves the multi-select block instead of a single
  /// tile. While set, every still keeps its slot in [_orderedFrames] — the
  /// selected ones are only dimmed — and [_blockSlot] is the insertion slot in
  /// that full layout.
  bool _isBlockDrag = false;

  /// The selected stills being block-dragged, in their current order.
  List<StopMotionClipFrame> _blockFrames = const [];

  /// Insertion slot of the dragged block within [_orderedFrames]
  /// (`0.._orderedFrames.length`).
  int _blockSlot = 0;

  double _dragTargetOffsetX = 0;

  // Finger tracking (global X is the source of truth so auto-scroll and the
  // gesture callbacks never fight over the position).
  double _dragGlobalX = 0;
  double _dragStartGlobalX = 0;
  double _dragStartLocalX = 0;
  double _dragStartScrollOffset = 0;
  double _dragTileWidth = 0;
  double _dragFingerRatio = 0.5;

  Timer? _autoScrollTimer;
  double _autoScrollSpeed = 0;

  double get _effectiveLocalX {
    final scrollDelta =
        (widget.scrollController?.offset ?? 0) - _dragStartScrollOffset;
    return _dragGlobalX - _dragStartGlobalX + _dragStartLocalX + scrollDelta;
  }

  @override
  void initState() {
    super.initState();
    _orderedFrames = List.of(widget.frames);
  }

  @override
  void didUpdateWidget(VideoEditorStopMotionFrameStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isReordering) _orderedFrames = List.of(widget.frames);
  }

  @override
  void dispose() {
    _stopAutoScroll();
    super.dispose();
  }

  double _tileWidth(StopMotionClipFrame frame) =>
      frame.duration.inMicroseconds /
      Duration.microsecondsPerSecond *
      widget.pixelsPerSecond;

  ({List<double> widths, List<double> offsets, double total}) _computeLayout() {
    final widths = <double>[];
    final offsets = <double>[];
    var x = 0.0;
    for (final frame in _orderedFrames) {
      final w = _tileWidth(frame);
      widths.add(w);
      offsets.add(x);
      x += w;
    }
    return (widths: widths, offsets: offsets, total: x);
  }

  /// Drag-target index for [x]: nearest slot by tile midpoints. Only for
  /// retargeting during a drag — for pickup use [_tileIndexAtX], which is
  /// containment-based (midpoints would pick the neighbour when pressing the
  /// right half of a tile).
  int _indexAtX(double x, List<double> widths) {
    var acc = 0.0;
    for (var i = 0; i < widths.length; i++) {
      if (x < acc + widths[i] / 2) return i;
      acc += widths[i];
    }
    return widths.length - 1;
  }

  /// Index of the tile whose horizontal extent contains [x].
  int _tileIndexAtX(double x, List<double> widths) {
    var acc = 0.0;
    for (var i = 0; i < widths.length; i++) {
      acc += widths[i];
      if (x < acc) return i;
    }
    return widths.length - 1;
  }

  /// Insertion slot for [x]: the number of tiles whose midpoint lies left of
  /// it (`0..widths.length`).
  int _slotAtX(double x, List<double> widths) {
    var acc = 0.0;
    var slot = 0;
    for (final width in widths) {
      if (x < acc + width / 2) break;
      acc += width;
      slot++;
    }
    return slot;
  }

  /// Translates a block-drag insertion slot in the full N-tile layout into the
  /// slot [StopMotionFrameOps.moveFrames] expects — an index among the
  /// *unselected* stills, which is simply how many of them sit left of it.
  ///
  /// A slot anywhere inside a contiguous selected run maps back to that run's
  /// own home, which is what makes releasing without leaving the block a no-op.
  int _remainingSlotFor(int fullSlot) {
    final selection = widget.selectedFrameIndexes;
    var slot = 0;
    for (var i = 0; i < fullSlot && i < widget.frames.length; i++) {
      if (!selection.contains(i)) slot++;
    }
    return slot;
  }

  void _onLongPressStart(LongPressStartDetails details) {
    if (widget.frames.length <= 1) return;
    if (widget.isMultiSelectMode) {
      _onBlockDragStart(details);
      return;
    }

    final layout = _computeLayout();
    final fingerX = details.localPosition.dx;
    final pressedIndex = _tileIndexAtX(fingerX, layout.widths);
    final tileWidth = layout.widths[pressedIndex];
    final tileLeft = layout.offsets[pressedIndex];
    final fingerRatio = tileWidth > 0
        ? ((fingerX - tileLeft) / tileWidth).clamp(0.0, 1.0)
        : 0.5;

    HapticFeedback.mediumImpact();
    widget.onReorderChanged?.call(true);
    setState(() {
      _isReordering = true;
      _dragIndex = pressedIndex;
      _dragStartIndex = pressedIndex;
      _dragGlobalX = details.globalPosition.dx;
      _dragStartGlobalX = details.globalPosition.dx;
      _dragStartLocalX = fingerX;
      _dragStartScrollOffset = widget.scrollController?.offset ?? 0;
      _dragTileWidth = tileWidth;
      _dragFingerRatio = fingerRatio;
      _dragTargetOffsetX = fingerX - (tileLeft + tileWidth / 2);
    });
  }

  /// Starts dragging the whole multi-select block. Only a long-press on a
  /// *selected* tile picks the block up; there must be at least one
  /// unselected still left to move past.
  ///
  /// Unlike the single-tile drag, the selected stills are *not* lifted out of
  /// the layout — they stay in their slots, dimmed. Collapsing a ten-still
  /// block out of the strip would shift every remaining tile left by the
  /// block's width mid-gesture, so the insertion slot could only be tracked
  /// relative to the block's old home — the marker trailed the finger by the
  /// whole block, dropping the stills back where the first one used to sit.
  /// Against a layout that does not move, the slot is the one under the finger.
  void _onBlockDragStart(LongPressStartDetails details) {
    final selection = widget.selectedFrameIndexes;
    if (widget.onBlockMove == null ||
        selection.isEmpty ||
        selection.length >= widget.frames.length) {
      return;
    }

    final layout = _computeLayout();
    final fingerX = details.localPosition.dx;
    final pressedIndex = _tileIndexAtX(fingerX, layout.widths);
    if (!selection.contains(pressedIndex)) return;

    final tileWidth = layout.widths[pressedIndex];
    final tileLeft = layout.offsets[pressedIndex];
    final fingerRatio = tileWidth > 0
        ? ((fingerX - tileLeft) / tileWidth).clamp(0.0, 1.0)
        : 0.5;

    final blockFrames = [
      for (var i = 0; i < widget.frames.length; i++)
        if (selection.contains(i)) widget.frames[i],
    ];

    HapticFeedback.mediumImpact();
    widget.onReorderChanged?.call(true);
    setState(() {
      _isReordering = true;
      _isBlockDrag = true;
      _blockFrames = blockFrames;
      _blockSlot = _slotAtX(fingerX, layout.widths);
      _dragGlobalX = details.globalPosition.dx;
      _dragStartGlobalX = details.globalPosition.dx;
      _dragStartLocalX = fingerX;
      _dragStartScrollOffset = widget.scrollController?.offset ?? 0;
      _dragTileWidth = tileWidth;
      _dragFingerRatio = fingerRatio;
    });
  }

  void _onLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    if (!_isReordering || (!_isBlockDrag && _dragIndex == null)) return;
    setState(() {
      _dragGlobalX = details.globalPosition.dx;
      _applyDragTarget();
    });
    _updateAutoScroll(details.globalPosition.dx);
  }

  void _applyDragTarget() {
    final widths = _computeLayout().widths;
    if (_isBlockDrag) {
      final slot = _slotAtX(_effectiveLocalX, widths);
      if (slot != _blockSlot) {
        HapticFeedback.selectionClick();
        _blockSlot = slot;
      }
      return;
    }
    final target = _indexAtX(_effectiveLocalX - _dragTargetOffsetX, widths);
    if (target != _dragIndex) {
      HapticFeedback.selectionClick();
      final frame = _orderedFrames.removeAt(_dragIndex!);
      _orderedFrames.insert(target, frame);
      _dragIndex = target;
    }
  }

  void _updateAutoScroll(double globalX) {
    if (widget.scrollController == null) return;
    final screenWidth = MediaQuery.sizeOf(context).width;

    if (globalX < _autoScrollEdgeZone) {
      _autoScrollSpeed =
          -(1 - globalX / _autoScrollEdgeZone) * _maxAutoScrollPxPerFrame;
    } else if (globalX > screenWidth - _autoScrollEdgeZone) {
      _autoScrollSpeed =
          (1 - (screenWidth - globalX) / _autoScrollEdgeZone) *
          _maxAutoScrollPxPerFrame;
    } else {
      _autoScrollSpeed = 0;
    }

    if (_autoScrollSpeed != 0 && _autoScrollTimer == null) {
      _autoScrollTimer = Timer.periodic(
        const Duration(milliseconds: 16),
        (_) => _tickAutoScroll(),
      );
    } else if (_autoScrollSpeed == 0) {
      _stopAutoScroll();
    }
  }

  void _tickAutoScroll() {
    final sc = widget.scrollController;
    if (sc == null || !_isReordering) {
      _stopAutoScroll();
      return;
    }
    final pos = sc.position;
    final newOffset = (pos.pixels + _autoScrollSpeed).clamp(
      pos.minScrollExtent,
      pos.maxScrollExtent,
    );
    if (newOffset == pos.pixels) return;
    sc.jumpTo(newOffset);
    setState(_applyDragTarget);
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
    _autoScrollSpeed = 0;
  }

  void _endReorder() {
    if (!_isReordering) return;
    _stopAutoScroll();
    widget.onReorderChanged?.call(false);

    if (_isBlockDrag) {
      final slot = _remainingSlotFor(_blockSlot);
      final moved = (_effectiveLocalX - _dragStartLocalX).abs() > 0.5;
      setState(() {
        _isReordering = false;
        _isBlockDrag = false;
        _blockFrames = const [];
        _orderedFrames = List.of(widget.frames);
      });
      if (moved) widget.onBlockMove?.call(slot);
      return;
    }

    final from = _dragStartIndex;
    final to = _dragIndex ?? from;

    setState(() {
      _isReordering = false;
      _dragIndex = null;
      _dragTargetOffsetX = 0;
    });

    if (from != to) widget.onReorder(from, to);
  }

  /// Unique per-tile keys. Duplicated stills share a file path, so keying by
  /// path alone collides (Flutter requires unique sibling keys). Disambiguate
  /// by occurrence — duplicates are identical images, so the exact key→tile
  /// mapping among them is visually indistinguishable during reorder.
  List<Key> _tileKeys() {
    final seen = <String, int>{};
    return [
      for (final frame in _orderedFrames)
        ValueKey(
          '${frame.path}#${seen[frame.path] = (seen[frame.path] ?? 0) + 1}',
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final layout = _computeLayout();
    final tileKeys = _tileKeys();

    return GestureDetector(
      onLongPressStart: _onLongPressStart,
      onLongPressMoveUpdate: _isReordering ? _onLongPressMoveUpdate : null,
      onLongPressEnd: _isReordering ? (_) => _endReorder() : null,
      onLongPressCancel: _isReordering ? _endReorder : null,
      child: SizedBox(
        width: layout.total,
        height: TimelineConstants.thumbnailStripHeight,
        child: Stack(
          clipBehavior: .none,
          children: [
            for (var i = 0; i < _orderedFrames.length; i++)
              if (i != _dragIndex)
                AnimatedPositioned(
                  key: tileKeys[i],
                  duration: _isReordering ? _animDuration : Duration.zero,
                  curve: Curves.easeInOut,
                  left: layout.offsets[i],
                  top: 0,
                  width: layout.widths[i],
                  height: TimelineConstants.thumbnailStripHeight,
                  child: _FrameTile(
                    frame: _orderedFrames[i],
                    index: i,
                    total: _orderedFrames.length,
                    isSelected:
                        (_isBlockDrag || !_isReordering) &&
                        (widget.isMultiSelectMode
                            ? widget.selectedFrameIndexes.contains(i)
                            : i == widget.selectedFrameIndex),
                    // A block member stays in its slot but reads as lifted, so
                    // the strip shows what is travelling with the finger
                    // without collapsing under it.
                    isLifted:
                        _isBlockDrag && widget.selectedFrameIndexes.contains(i),
                    onTap: _isReordering ? null : () => widget.onFrameTapped(i),
                  ),
                ),
            if (_dragIndex != null)
              Positioned(
                left: _effectiveLocalX - _dragTileWidth * _dragFingerRatio,
                top: 0,
                width: _dragTileWidth,
                height: TimelineConstants.thumbnailStripHeight,
                child: _FrameTile(
                  frame: _orderedFrames[_dragIndex!],
                  index: _dragIndex!,
                  total: _orderedFrames.length,
                  isSelected: true,
                  isDragging: true,
                ),
              ),

            // Block drag: an insertion marker at the target slot plus a ghost
            // of the block (its first still with a count badge) at the finger.
            if (_isBlockDrag) ...[
              Positioned(
                left:
                    (_blockSlot < layout.offsets.length
                        ? layout.offsets[_blockSlot]
                        : layout.total) -
                    1,
                top: 0,
                width: 2,
                height: TimelineConstants.thumbnailStripHeight,
                child: const ColoredBox(color: VineTheme.accentYellow),
              ),
              Positioned(
                left: _effectiveLocalX - _dragTileWidth * _dragFingerRatio,
                top: 0,
                width: _dragTileWidth,
                height: TimelineConstants.thumbnailStripHeight,
                child: Stack(
                  clipBehavior: .none,
                  fit: StackFit.expand,
                  children: [
                    _FrameTile(
                      frame: _blockFrames.first,
                      index: 0,
                      total: _blockFrames.length,
                      isSelected: true,
                      isDragging: true,
                    ),
                    if (_blockFrames.length > 1)
                      PositionedDirectional(
                        top: -6,
                        end: -6,
                        child: _BlockCountBadge(count: _blockFrames.length),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Count badge on the block-drag ghost showing how many stills move together.
class _BlockCountBadge extends StatelessWidget {
  const _BlockCountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return MediaQuery.withNoTextScaling(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: const BoxDecoration(
          color: VineTheme.accentYellow,
          borderRadius: BorderRadius.all(Radius.circular(999)),
        ),
        child: Text(
          count.toString(),
          style: VineTheme.labelSmallFont(color: VineTheme.backgroundCamera),
        ),
      ),
    );
  }
}

class _FrameTile extends StatelessWidget {
  const _FrameTile({
    required this.frame,
    required this.index,
    required this.total,
    required this.isSelected,
    this.onTap,
    this.isDragging = false,
    this.isLifted = false,
  });

  final StopMotionClipFrame frame;
  final int index;
  final int total;
  final bool isSelected;
  final VoidCallback? onTap;
  final bool isDragging;

  /// Whether this still is part of the block currently travelling with the
  /// finger. It keeps its slot so the strip's geometry stays stable, and fades
  /// to read as picked up rather than left behind.
  final bool isLifted;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(TimelineConstants.thumbnailRadius);
    // Decode the still at strip height, not full camera resolution — a 4000px
    // portrait decoded into a 64px tile otherwise wastes ~45 MB per tile.
    final cacheHeight =
        (TimelineConstants.thumbnailStripHeight *
                MediaQuery.devicePixelRatioOf(context))
            .round();
    return Semantics(
      button: true,
      selected: isSelected,
      label: context.l10n.videoEditorStopMotionFrameSemanticLabel(
        index + 1,
        total,
      ),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Opacity(
          opacity: isLifted
              ? 0.35
              : isDragging
              ? 0.85
              : 1,
          child: DecoratedBox(
            // Foreground: the image fills the same box, so a background
            // decoration would be painted underneath it and never show.
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              borderRadius: radius,
              // Selected stills use the same accent-yellow highlight as the
              // trim handles on a video clip — just the highlight, no handles.
              border: Border.all(
                color: isSelected
                    ? VineTheme.accentYellow
                    : context.vineColors.surface,
                width: isSelected ? 2 : 0.5,
              ),
            ),
            child: ClipRRect(
              borderRadius: radius,
              child: Image.file(
                File(frame.path),
                fit: BoxFit.cover,
                gaplessPlayback: true,
                cacheHeight: cacheHeight,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
