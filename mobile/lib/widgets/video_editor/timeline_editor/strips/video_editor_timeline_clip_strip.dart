import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/constants/video_editor_timeline_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/clip_waveform.dart';
import 'package:openvine/models/video_editor/transition_geometry.dart';
import 'package:openvine/router/app_router.dart';
import 'package:openvine/services/video_editor/clip_thumbnail_manager.dart';
import 'package:openvine/services/video_editor/clip_waveform_manager.dart';
import 'package:openvine/services/video_thumbnail_service.dart';
import 'package:openvine/utils/mounted_post_frame.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_transition_sheet.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/strips/clip_waveform_overlay.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/strips/timeline_trim_handles.dart';

part 'video_editor_timeline_clip_strip_tiles.dart';

/// Callback reporting a trim change for a clip.
typedef ClipTrimCallback =
    void Function({
      required String clipId,
      required bool isStart,
      required Duration trimStart,
      required Duration trimEnd,
    });

/// Callback reporting a reorder change — from index and to index.
typedef ClipReorderCallback = void Function(int from, int to);

class VideoEditorTimelineClipStrip extends StatefulWidget {
  const VideoEditorTimelineClipStrip({
    required this.clips,
    required this.totalWidth,
    required this.pixelsPerSecond,
    this.scrollController,
    this.onReorder,
    this.onReorderChanged,
    this.isInteracting = false,
    this.onClipTapped,
    this.trimmingClipId,
    this.onTrimChanged,
    this.onTrimDragChanged,
    this.isMultiSelectMode = false,
    this.selectedClipIds = const {},
    @visibleForTesting this.thumbnailManager,
    @visibleForTesting this.waveformManager,
    super.key,
  });

  final List<DivineVideoClip> clips;
  final double totalWidth;
  final double pixelsPerSecond;
  final ScrollController? scrollController;
  final ValueChanged<List<DivineVideoClip>>? onReorder;
  final ValueChanged<bool>? onReorderChanged;

  /// Whether the timeline is in multi-select mode. Disables reorder and shows
  /// per-clip selection affordances.
  final bool isMultiSelectMode;

  /// IDs of the clips currently selected in multi-select mode.
  final Set<String> selectedClipIds;

  /// Test seam for asserting route-aware thumbnail pausing without invoking the
  /// native thumbnail extractor.
  @visibleForTesting
  final ClipThumbnailManager? thumbnailManager;

  /// Test seam for asserting the clip waveform overlay without invoking the
  /// native waveform extractor.
  @visibleForTesting
  final ClipWaveformManager? waveformManager;

  /// When `true` the user is scrolling or pinch-zooming — long press
  /// must not start a reorder drag.
  final bool isInteracting;

  /// Called when a clip tile is tapped with the clip's index.
  final ValueChanged<int>? onClipTapped;

  /// ID of the clip currently being trimmed, or `null`.
  final String? trimmingClipId;

  /// Called when a trim handle is dragged.
  final ClipTrimCallback? onTrimChanged;

  /// Called when a trim drag gesture starts (`true`) or ends (`false`).
  final ValueChanged<bool>? onTrimDragChanged;

  @override
  State<VideoEditorTimelineClipStrip> createState() =>
      _VideoEditorTimelineClipStripState();
}

class _VideoEditorTimelineClipStripState
    extends State<VideoEditorTimelineClipStrip>
    with SingleTickerProviderStateMixin, RouteAware {
  static const _animDuration = Duration(milliseconds: 250);

  /// Drives reorder shrink/grow timing so we can react to completion
  /// instead of guessing with [Future.delayed].
  late final AnimationController _reorderAnimController;

  bool _isReordering = false;
  bool _isReorderExiting = false;
  bool _dragAnimating = false;
  int? _dragIndex;
  double _rowOffset = 0;
  double _dragClipWidth = 0;
  double _dragFingerRatio = 0.5;
  double _dragStartClipCenter = 0;
  late List<DivineVideoClip> _orderedClips;

  // Finger tracking — global X is the source of truth so that auto-scroll
  // and gesture callbacks never conflict.
  double _dragGlobalX = 0;
  double _dragStartGlobalX = 0;
  double _dragStartLocalX = 0;
  double _dragStartScrollOffset = 0;

  /// Current local finger X derived from global position + scroll delta.
  double get _effectiveLocalX {
    final scrollDelta =
        (widget.scrollController?.offset ?? 0) - _dragStartScrollOffset;
    return _dragGlobalX - _dragStartGlobalX + _dragStartLocalX + scrollDelta;
  }

  /// Thumbnail data keyed by clip ID — survives reordering.
  /// Each notifier is updated independently so only the affected
  /// clip tile rebuilds, not the entire strip.
  late final ClipThumbnailManager _thumbnails;

  /// Audio waveforms keyed by clip ID, drawn over each tile's thumbnails.
  /// Independent notifiers for the same reason as [_thumbnails].
  late final ClipWaveformManager _waveforms;

  /// Identity of the last split event we already seeded thumbnails
  /// for. Used to ensure each split is processed exactly once.
  ClipSplitEvent? _lastSeededSplit;

  /// Memoized slot-timestamp result — only recomputed when [widget.clips]
  /// identity or [widget.pixelsPerSecond] changes.
  List<DivineVideoClip>? _prevSlotClips;
  double? _prevSlotPps;
  Map<String, List<Duration>> _cachedSlotTimestamps = const {};

  static const double _reorderSize = TimelineConstants.thumbnailStripHeight;

  // Auto-scroll state.
  Timer? _autoScrollTimer;
  double _autoScrollSpeed = 0;
  static const _autoScrollEdgeZone = 40.0;
  static const _maxAutoScrollPxPerFrame = 8.0;

  // Keeps animation alive for one tick after volume edit mode is turned
  // off so tiles animate back to their normal row instead of snapping.
  bool _isExitingVolumeMode = false;
  Timer? _volumeExitTimer;

  /// True between a trim handle's drag start and its release. The manager
  /// leaves the dragged clip's extraction window alone for that span instead
  /// of restarting on every committed step of the gesture.
  bool _isTrimDragging = false;
  Timer? _trimCatchUpTimer;

  /// How long the trim window has to sit still mid-drag before it is requested
  /// anyway. Without this the newly exposed footage would stay on posters for
  /// the whole gesture, which is worse than the thrash the hold prevents: the
  /// user drags a handle out precisely to see what is there. Re-armed on every
  /// committed step, so a continuous drag never fires it and a pause always
  /// does.
  static const _trimCatchUpDelay = Duration(milliseconds: 250);

  /// True until the editor's preview player reports ready, or
  /// [_playerGateTimeout] elapses. Thumbnail extraction is held meanwhile.
  bool _awaitingPlayer = true;
  Timer? _playerGateTimer;

  /// Upper bound on the startup hold. A composition that fails to load
  /// publishes `isPlayerReady: false` and never corrects itself, so without
  /// this the strip would stay on posters for the whole session.
  static const _playerGateTimeout = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _thumbnails = widget.thumbnailManager ?? ClipThumbnailManager();
    _waveforms = widget.waveformManager ?? ClipWaveformManager();
    _reorderAnimController = AnimationController(
      vsync: this,
      duration: _animDuration,
    );
    _orderedClips = List.of(widget.clips);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Pause thumbnail extraction while the editor is obscured (e.g. after
    // pushing the metadata/preview screen) so its MediaMetadataRetriever
    // frames stop competing for hardware decoders with the render/preview.
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
    _updatePlayerGate();
    _maybeSeedSplit();
    _syncThumbnails();
  }

  @override
  void didUpdateWidget(VideoEditorTimelineClipStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isReordering) {
      _orderedClips = List.of(widget.clips);
    }
    _maybeSeedSplit();
    _syncThumbnails();
  }

  @override
  void didPushNext() => _thumbnails.pauseAll();

  @override
  void didPopNext() => _thumbnails.resumeAll();

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _stopAutoScroll();
    _volumeExitTimer?.cancel();
    _playerGateTimer?.cancel();
    _trimCatchUpTimer?.cancel();
    _reorderAnimController.dispose();
    _thumbnails.dispose();
    _waveforms.dispose();
    super.dispose();
  }

  /// Holds thumbnail extraction until the editor's preview player has loaded.
  ///
  /// Both decode video, and the strip's first request starts on the same frame
  /// the canvas initialises its player. Once released the gate never re-arms:
  /// `isPlayerReady` also drops on every later reload (trim, reorder, speed),
  /// and suspending the strip for those would be a different, unwanted change.
  void _updatePlayerGate() {
    if (!_awaitingPlayer) return;
    final bloc = context.read<VideoEditorMainBloc?>();
    if (bloc == null || bloc.state.isPlayerReady) {
      _releasePlayerGate();
      return;
    }
    _thumbnails.holdForPlayerStartup();
    _playerGateTimer ??= Timer(_playerGateTimeout, _releasePlayerGate);
  }

  void _releasePlayerGate() {
    if (!_awaitingPlayer) return;
    _awaitingPlayer = false;
    _playerGateTimer?.cancel();
    _playerGateTimer = null;
    _thumbnails.releasePlayerStartupHold();
  }

  void _handleTrimDragChanged(bool isDragging) {
    _isTrimDragging = isDragging;
    widget.onTrimDragChanged?.call(isDragging);
    if (isDragging) return;
    // Request the window the drag opened up, once. Not left to the parent
    // rebuild: widget.onTrimDragChanged is nullable, so one is not guaranteed.
    _trimCatchUpTimer?.cancel();
    _syncThumbnails();
  }

  /// [ignoreTrimHold] requests the dragged clip's current window even though
  /// the gesture is still running — see [_trimCatchUpDelay].
  void _syncThumbnails({bool ignoreTrimHold = false}) {
    final clips = widget.clips;
    final pps = widget.pixelsPerSecond;
    if (!identical(_prevSlotClips, clips) || _prevSlotPps != pps) {
      _prevSlotClips = clips;
      _prevSlotPps = pps;
      _cachedSlotTimestamps = _computeSlotTimestamps();
    }
    final holdTrimOn = _isTrimDragging && !ignoreTrimHold
        ? widget.trimmingClipId
        : null;
    _thumbnails.sync(
      clips: clips,
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
      priorityTimestamps: _cachedSlotTimestamps,
      trimmingClipId: holdTrimOn,
    );
    _waveforms.sync(clips: clips);
    if (holdTrimOn == null) return;
    _trimCatchUpTimer?.cancel();
    _trimCatchUpTimer = Timer(_trimCatchUpDelay, () {
      if (mounted) _syncThumbnails(ignoreTrimHold: true);
    });
  }

  /// Seeds the new clips' thumbnail notifiers from the source clip's
  /// already-loaded thumbnails when a split has just occurred. This
  /// avoids a flash of placeholder/wrong-range frames while the
  /// trimmed segment files are being rendered — the real
  /// subscriptions kick in once the rendered file paths arrive.
  void _maybeSeedSplit() {
    final bloc = context.read<ClipEditorBloc?>();
    if (bloc == null) return;
    final split = bloc.state.lastSplit;
    if (split == null || identical(split, _lastSeededSplit)) return;

    final startClipIdx = widget.clips.indexWhere(
      (c) => c.id == split.startClipId,
    );
    final endClipIdx = widget.clips.indexWhere((c) => c.id == split.endClipId);
    if (startClipIdx == -1 || endClipIdx == -1) return;
    final startClip = widget.clips[startClipIdx];
    final endClip = widget.clips[endClipIdx];
    final sourcePath = startClip.video?.file?.path;
    if (sourcePath == null) return;

    // Mark consumed only once seeding can actually run. Committing before
    // the guards above would permanently drop the seed if a transient
    // bail hit (clips not yet rebuilt / momentarily-null source path),
    // reintroducing the black flash for that split.
    _lastSeededSplit = split;

    _thumbnails.seedFromSource(
      sourceClipId: split.sourceClipId,
      targetClipId: split.startClipId,
      sourceRange: DurationRange(
        start: split.sourceTrimStart,
        end: split.absoluteSplitPosition,
      ),
      timestampOffset: Duration.zero,
      currentSourcePath: sourcePath,
    );
    // The end half keeps the shared source file with trimStart at the split
    // point, so its seeds stay source-timed — the real subscription extracts
    // from the same file at the same source timestamps.
    _thumbnails.seedFromSource(
      sourceClipId: split.sourceClipId,
      targetClipId: split.endClipId,
      sourceRange: DurationRange(
        start: split.absoluteSplitPosition,
        end: split.sourceDuration - split.sourceTrimEnd,
      ),
      timestampOffset: Duration.zero,
      currentSourcePath: endClip.video?.file?.path ?? sourcePath,
    );
  }

  /// Computes the exact timestamps that the currently visible thumbnail
  /// slots need at the current zoom level.
  ///
  /// Each clip is divided into `ceil(clipWidth / thumbnailWidth)` slots.
  /// The center-time of every slot is returned so the generator can
  /// produce those frames first — giving instant visual coverage.
  Map<String, List<Duration>> _computeSlotTimestamps() {
    final result = <String, List<Duration>>{};
    final wrap = _wrapDisplay;

    for (final clip in widget.clips) {
      final clipPx = _clipWidth(clip, wrap);
      // The strip shows the clip's display range: the loop wrap moves the first
      // clip's head and the last clip's tail into the blend seam at the end, so
      // their thumbnails start later / end earlier by the consumed span
      // (converted into this clip's source time).
      var visibleStart = clip.trimStart;
      var visibleEnd = clip.duration - clip.trimEnd;
      if (wrap.isActive) {
        final consumedSource = clip.playbackDurationToSourceDuration(
          wrap.consumedPerSide,
        );
        if (clip.id == widget.clips.first.id) visibleStart += consumedSource;
        if (clip.id == widget.clips.last.id) visibleEnd -= consumedSource;
      }
      final visibleMs = (visibleEnd - visibleStart).inMilliseconds;
      if (clipPx <= 0 || visibleMs <= 0) continue;

      // Mirror the tile's recording-anchored slot raster (fixed pitch,
      // phase-shifted by sourceStartOffset) so the priority frames land on
      // the exact window centers the visible slots will look up.
      final speed = clip.playbackSpeed ?? 1.0;
      final spanMs =
          TimelineConstants.thumbnailWidth *
          1000 *
          (speed > 0 ? speed : 1.0) /
          widget.pixelsPerSecond;
      final phaseMs = _rasterAnchorOffset(clip).inMilliseconds % spanMs;
      final startMs = visibleStart.inMilliseconds;
      final endMs = visibleEnd.inMilliseconds;
      final firstSlot = ((startMs + phaseMs) / spanMs).floor();
      final timestamps = <Duration>[];
      for (var m = firstSlot; timestamps.length < 1000; m++) {
        final slotStartMs = m * spanMs - phaseMs;
        if (slotStartMs >= endMs) break;
        final centerMs = (slotStartMs + spanMs / 2).clamp(
          startMs.toDouble(),
          endMs.toDouble() - 1,
        );
        timestamps.add(Duration(milliseconds: centerMs.round()));
      }
      result[clip.id] = timestamps;
    }

    return result;
  }

  /// The loop-wrap display geometry for the current strip order, or
  /// [LoopWrapDisplay.none] while trimming — trim math maps pixels to durations
  /// assuming full-length strips, so the wrap shortening is suspended for the
  /// gesture (like the transition buttons are hidden) and reapplied on release.
  LoopWrapDisplay get _wrapDisplay => widget.trimmingClipId != null
      ? LoopWrapDisplay.none
      : LoopWrapDisplay.fromClips(_orderedClips);

  double _seamRegionWidth(LoopWrapDisplay wrap) =>
      wrap.seamDuration.inMicroseconds /
      Duration.microsecondsPerSecond *
      widget.pixelsPerSecond;

  double _clipWidth(DivineVideoClip clip, LoopWrapDisplay wrap) {
    if (widget.clips.length == 1) {
      // The single clip fills the strip minus the loop-blend seam region
      // appended at the end (widget.totalWidth already spans both).
      return math.max(0, widget.totalWidth - _seamRegionWidth(wrap));
    }
    final display = wrap.displayDuration(
      clip,
      isFirst: clip.id == _orderedClips.first.id,
      isLast: clip.id == _orderedClips.last.id,
    );
    return display.inMicroseconds /
        Duration.microsecondsPerSecond *
        widget.pixelsPerSecond;
  }

  int _clipIndexAtX(double localX) {
    const slotWidth = _reorderSize + TimelineConstants.clipGap;
    return (localX / slotWidth).floor().clamp(0, _orderedClips.length - 1);
  }

  /// Slot-center X for a given index in the reorder grid.
  double _slotLeft(int index) {
    return index * (_reorderSize + TimelineConstants.clipGap);
  }

  void _onLongPressStart(LongPressStartDetails details) {
    if (widget.clips.length <= 1) return;
    if (widget.isInteracting) return;

    final fingerX = details.localPosition.dx;

    // Find which clip was pressed in the normal layout.
    final wrap = _wrapDisplay;
    var accX = 0.0;
    var pressedIndex = _orderedClips.length - 1;
    for (var i = 0; i < _orderedClips.length; i++) {
      final w = _clipWidth(_orderedClips[i], wrap);
      if (fingerX < accX + w) {
        pressedIndex = i;
        break;
      }
      accX += w + TimelineConstants.clipGap;
    }

    // Where in the clip the finger landed (0.0 = left edge, 1.0 = right).
    final clipW = _clipWidth(_orderedClips[pressedIndex], wrap);
    final fingerInClip = (fingerX - accX).clamp(0.0, clipW);
    final fingerRatio = clipW > 0 ? fingerInClip / clipW : 0.5;

    // Offset so the reorder grid starts aligned with the pressed clip.
    final slotCenter = _slotLeft(pressedIndex) + _reorderSize / 2;

    HapticFeedback.mediumImpact();
    widget.onReorderChanged?.call(true);
    setState(() {
      _rowOffset = fingerX - slotCenter;
      _dragGlobalX = details.globalPosition.dx;
      _dragStartGlobalX = details.globalPosition.dx;
      _dragStartLocalX = fingerX;
      _dragStartScrollOffset = widget.scrollController?.offset ?? 0;
      _dragClipWidth = clipW;
      _dragFingerRatio = fingerRatio;
      _dragStartClipCenter = accX + clipW / 2;
      _dragAnimating = true;
      _isReordering = true;
      _dragIndex = pressedIndex;
    });

    // Trigger the width shrink in the next frame so AnimatedContainer can
    // interpolate from the full clip width to _reorderSize.
    addPostFrameCallbackIfMounted(() {
      if (_isReordering) {
        setState(() => _dragClipWidth = _reorderSize);
      }
    });

    // After the shrink animation completes, switch to finger-following mode.
    _reorderAnimController
      ..reset()
      ..forward().then((_) {
        if (mounted && _isReordering) {
          setState(() => _dragAnimating = false);
        }
      });
  }

  void _onLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    if (!_isReordering || _dragIndex == null) return;

    setState(() {
      _dragGlobalX = details.globalPosition.dx;
      final adjustedX = _effectiveLocalX - _rowOffset;
      final targetIndex = _clipIndexAtX(adjustedX);
      if (targetIndex != _dragIndex) {
        HapticFeedback.selectionClick();
        final clip = _orderedClips.removeAt(_dragIndex!);
        _orderedClips.insert(targetIndex, clip);
        _dragIndex = targetIndex;
      }
    });

    _updateAutoScroll(details.globalPosition.dx);
  }

  // --------------- Auto-scroll while dragging near screen edges -------------

  void _updateAutoScroll(double globalX) {
    if (widget.scrollController == null) return;

    final screenWidth = MediaQuery.sizeOf(context).width;

    if (globalX < _autoScrollEdgeZone) {
      final t = 1 - (globalX / _autoScrollEdgeZone);
      _autoScrollSpeed = -t * _maxAutoScrollPxPerFrame;
    } else if (globalX > screenWidth - _autoScrollEdgeZone) {
      final t = 1 - ((screenWidth - globalX) / _autoScrollEdgeZone);
      _autoScrollSpeed = t * _maxAutoScrollPxPerFrame;
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
    if (sc == null || !_isReordering || _dragIndex == null) {
      _stopAutoScroll();
      return;
    }

    final pos = sc.position;
    final newOffset = (pos.pixels + _autoScrollSpeed).clamp(
      pos.minScrollExtent,
      pos.maxScrollExtent,
    );
    final actualDelta = newOffset - pos.pixels;
    if (actualDelta == 0) return;

    sc.jumpTo(newOffset);

    // _effectiveLocalX auto-adjusts via the scroll-offset delta — no manual
    // finger-position patching needed.
    setState(() {
      final adjustedX = _effectiveLocalX - _rowOffset;
      final targetIndex = _clipIndexAtX(adjustedX);
      if (targetIndex != _dragIndex) {
        HapticFeedback.selectionClick();
        final clip = _orderedClips.removeAt(_dragIndex!);
        _orderedClips.insert(targetIndex, clip);
        _dragIndex = targetIndex;
      }
    });
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
    _autoScrollSpeed = 0;
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    _endReorder();
  }

  void _onLongPressCancel() {
    _endReorder();
  }

  /// Programmatic reorder for accessibility custom actions.
  void _reorderClip(int from, int to) {
    if (from == to) return;
    HapticFeedback.selectionClick();
    setState(() {
      final clip = _orderedClips.removeAt(from);
      _orderedClips.insert(to, clip);
    });
    widget.onReorder?.call(List.of(_orderedClips));
  }

  void _endReorder() {
    if (!_isReordering) return;

    _stopAutoScroll();

    final reordered = List<DivineVideoClip>.of(_orderedClips);
    final changed = !_sameOrder(reordered, widget.clips);

    // Phase 1: switch to exit mode — layout returns to normal widths
    // while AnimatedPositioned still has animDuration.
    setState(() {
      _isReordering = false;
      _isReorderExiting = true;
      _dragIndex = null;
      _dragAnimating = false;
    });

    widget.onReorderChanged?.call(false);

    if (changed) {
      widget.onReorder?.call(reordered);
    }

    // Phase 2: after the grow-back animation completes, clean up.
    _reorderAnimController
      ..reset()
      ..forward().then((_) {
        if (mounted) {
          setState(() {
            _isReorderExiting = false;
            _dragGlobalX = 0;
            _dragStartGlobalX = 0;
            _dragStartLocalX = 0;
            _dragStartScrollOffset = 0;
            _dragClipWidth = 0;
            _dragFingerRatio = 0.5;
            _dragStartClipCenter = 0;
            _rowOffset = 0;
          });
        }
      });
  }

  static bool _sameOrder(List<DivineVideoClip> a, List<DivineVideoClip> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  /// Compute clip widths, left offsets and total width in a single pass.
  ///
  /// With a loop transition, the total includes the blend seam region appended
  /// after the last clip (the wrap-consumed head/tail plays there instead of
  /// inside the clips), so strips, playhead, preview and export share one axis.
  ({List<double> widths, List<double> offsets, double totalWidth})
  _computeLayout(LoopWrapDisplay wrap) {
    final widths = <double>[];
    final offsets = <double>[];
    var x = 0.0;
    for (var i = 0; i < _orderedClips.length; i++) {
      final w = _clipWidth(_orderedClips[i], wrap);
      widths.add(w);
      offsets.add(x);
      x += w + TimelineConstants.clipGap;
    }
    // Subtract trailing gap, then append the loop-blend seam region.
    var total = x > 0 ? x - TimelineConstants.clipGap : 0.0;
    total += _seamRegionWidth(wrap);
    return (widths: widths, offsets: offsets, totalWidth: total);
  }

  @override
  Widget build(BuildContext context) {
    const gap = TimelineConstants.clipGap;
    const reorderSlotStep = _reorderSize + gap;
    const animDuration = _animDuration;
    const animCurve = Curves.easeInOut;

    // One wrap-display per build: [_wrapDisplay] runs [clampTransitions] on
    // every call, so compute it once and share it with the layout pass.
    final wrap = _wrapDisplay;
    final seamRegionWidth = _seamRegionWidth(wrap);
    final layout = _computeLayout(wrap);
    final totalWidth = _isReordering
        ? _orderedClips.length * reorderSlotStep - gap
        : layout.totalWidth;

    // Reserve a half-button-wide trailing slot so the loop-restart button can
    // straddle the strip's end edge (centred on the last clip's end) without the
    // outer Stack's hardEdge clipping its right half. Always reserved when there
    // are clips so entering/leaving trim/volume/reorder doesn't animate the
    // strip width.
    final loopSlotWidth = _orderedClips.isEmpty
        ? 0.0
        : _TransitionButtonsLayer._hitWidth / 2;

    final shouldAnimate = _isReordering || _isReorderExiting;

    final trimExpand = widget.trimmingClipId != null
        ? TimelineConstants.trimHitOverhang
        : 0.0;

    final isVolumeEditMode = context.select(
      (VideoEditorMainBloc b) => b.state.isVolumeEditMode,
    );
    const volumeRowStep =
        TimelineConstants.thumbnailStripHeight +
        TimelineConstants.thumbnailVerticalRowGap;
    final containerHeight = isVolumeEditMode && _orderedClips.isNotEmpty
        ? _orderedClips.length * volumeRowStep -
              TimelineConstants.thumbnailVerticalRowGap
        : TimelineConstants.thumbnailStripHeight;
    final volumeAnimating = isVolumeEditMode || _isExitingVolumeMode;

    return MultiBlocListener(
      listeners: [
        BlocListener<VideoEditorMainBloc, VideoEditorMainState>(
          listenWhen: (prev, curr) => !prev.isPlayerReady && curr.isPlayerReady,
          listener: (_, _) => _releasePlayerGate(),
        ),
        BlocListener<VideoEditorMainBloc, VideoEditorMainState>(
          listenWhen: (prev, curr) =>
              prev.isVolumeEditMode && !curr.isVolumeEditMode,
          listener: (_, _) {
            _volumeExitTimer?.cancel();
            setState(() => _isExitingVolumeMode = true);
            _volumeExitTimer = Timer(animDuration, () {
              if (mounted) setState(() => _isExitingVolumeMode = false);
            });
          },
        ),
      ],
      child: Semantics(
        label: context.l10n.videoEditorTimelineLongPressToDragHint,
        button: true,
        child: GestureDetector(
          onLongPressStart: isVolumeEditMode || widget.isMultiSelectMode
              ? null
              : _onLongPressStart,
          onLongPressMoveUpdate: _isReordering ? _onLongPressMoveUpdate : null,
          onLongPressEnd: _isReordering ? _onLongPressEnd : null,
          onLongPressCancel: _isReordering ? _onLongPressCancel : null,
          child: AnimatedContainer(
            duration: shouldAnimate || volumeAnimating ? animDuration : .zero,
            curve: animCurve,
            width: totalWidth + loopSlotWidth,
            height: containerHeight,
            child: Stack(
              clipBehavior:
                  shouldAnimate ||
                      widget.trimmingClipId != null ||
                      volumeAnimating
                  ? .none
                  : .hardEdge,
              children: [
                /// Non-dragged, non-trimming clips.
                _NonTrimmingClipPositions(
                  orderedClips: _orderedClips,
                  thumbnails: _thumbnails,
                  waveforms: _waveforms,
                  layout: layout,
                  wrap: wrap,
                  dragIndex: _dragIndex,
                  trimmingClipId: widget.trimmingClipId,
                  shouldAnimate: shouldAnimate || volumeAnimating,
                  animDuration: animDuration,
                  animCurve: animCurve,
                  isReordering: _isReordering,
                  rowOffset: _rowOffset,
                  reorderSlotStep: reorderSlotStep,
                  pixelsPerSecond: widget.pixelsPerSecond,
                  onReorder: _reorderClip,
                  onClipTapped: widget.onClipTapped,
                  rowOffsetSize: _reorderSize,
                  isVolumeEditMode: isVolumeEditMode,
                  volumeRowStep: volumeRowStep,
                  isMultiSelectMode: widget.isMultiSelectMode,
                  selectedClipIds: widget.selectedClipIds,
                ),

                /// Trimming clip — rendered last so handles stay on top.
                // AnimatedPositioned is expanded by trimExpand on each side
                // so the handle hit-areas fall within its bounds.
                _TrimmingClipPositions(
                  orderedClips: _orderedClips,
                  thumbnails: _thumbnails,
                  waveforms: _waveforms,
                  layout: layout,
                  dragIndex: _dragIndex,
                  trimmingClipId: widget.trimmingClipId,
                  shouldAnimate: shouldAnimate || volumeAnimating,
                  animDuration: animDuration,
                  animCurve: animCurve,
                  isReordering: _isReordering,
                  rowOffset: _rowOffset,
                  reorderSlotStep: reorderSlotStep,
                  trimExpand: trimExpand,
                  pixelsPerSecond: widget.pixelsPerSecond,
                  onTrimChanged: widget.onTrimChanged,
                  onTrimDragChanged: _handleTrimDragChanged,
                  onClipTapped: widget.onClipTapped,
                  reorderSize: _reorderSize,
                  isVolumeEditMode: isVolumeEditMode,
                  volumeRowStep: volumeRowStep,
                ),

                /// Dragged clip — AnimatedPositioned so left+width animate
                // together during shrink, then Duration.zero for instant
                // finger-following after the animation completes.
                if (_dragIndex != null)
                  _DraggedClipPosition(
                    orderedClips: _orderedClips,
                    thumbnails: _thumbnails,
                    layout: layout,
                    dragIndex: _dragIndex,
                    dragAnimating: _dragAnimating,
                    animDuration: animDuration,
                    animCurve: animCurve,
                    dragStartClipCenter: _dragStartClipCenter,
                    dragClipWidth: _dragClipWidth,
                    effectiveLocalX: _effectiveLocalX,
                    dragFingerRatio: _dragFingerRatio,
                    pixelsPerSecond: widget.pixelsPerSecond,
                  ),

                /// Transition buttons on each internal clip boundary, plus the
                /// loop-blend seam region and the loop-restart button at the
                /// very end (last clip's tail into the first clip's head).
                /// Hidden during reorder/trim/volume/multi-select so they never
                /// overlap those interactions.
                if (!shouldAnimate &&
                    widget.trimmingClipId == null &&
                    !isVolumeEditMode &&
                    !widget.isMultiSelectMode &&
                    _orderedClips.isNotEmpty) ...[
                  if (_orderedClips.length >= 2)
                    _TransitionButtonsLayer(
                      clips: _orderedClips,
                      layout: layout,
                    ),
                  if (seamRegionWidth > 0)
                    _LoopSeamRegion(
                      left: layout.totalWidth - seamRegionWidth,
                      width: seamRegionWidth,
                      // The same frames the transition picker previews: the
                      // last clip's tail into the first clip's head.
                      tailFramePath:
                          _orderedClips.last.ghostFramePath ??
                          _orderedClips.last.thumbnailPath,
                      headFramePath: _orderedClips.first.thumbnailPath,
                    ),
                  _LoopTransitionButton(
                    hasTransition: _orderedClips.last.transition != null,
                    layout: layout,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TrimmingClipPositions extends StatelessWidget {
  const _TrimmingClipPositions({
    required this.orderedClips,
    required this.thumbnails,
    required this.waveforms,
    required this.layout,
    required this.dragIndex,
    required this.trimmingClipId,
    required this.shouldAnimate,
    required this.animDuration,
    required this.animCurve,
    required this.isReordering,
    required this.rowOffset,
    required this.reorderSlotStep,
    required this.trimExpand,
    required this.pixelsPerSecond,
    required this.onTrimChanged,
    required this.onTrimDragChanged,
    required this.onClipTapped,
    required this.reorderSize,
    required this.isVolumeEditMode,
    required this.volumeRowStep,
  });

  final List<DivineVideoClip> orderedClips;
  final ClipThumbnailManager thumbnails;
  final ClipWaveformManager waveforms;
  final ({List<double> widths, List<double> offsets, double totalWidth}) layout;
  final int? dragIndex;
  final String? trimmingClipId;
  final bool shouldAnimate;
  final Duration animDuration;
  final Curve animCurve;
  final bool isReordering;
  final double rowOffset;
  final double reorderSlotStep;
  final double trimExpand;
  final double pixelsPerSecond;
  final ClipTrimCallback? onTrimChanged;
  final ValueChanged<bool>? onTrimDragChanged;
  final ValueChanged<int>? onClipTapped;
  final double reorderSize;
  final bool isVolumeEditMode;
  final double volumeRowStep;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: .none,
      children: [
        for (int i = 0; i < orderedClips.length; i++)
          if (i != dragIndex && orderedClips[i].id == trimmingClipId)
            AnimatedPositioned(
              key: ValueKey(orderedClips[i].id),
              duration: shouldAnimate ? animDuration : Duration.zero,
              curve: animCurve,
              left: isReordering
                  ? rowOffset + i * reorderSlotStep
                  : layout.offsets[i] - trimExpand,
              top: isVolumeEditMode ? i * volumeRowStep : 0,
              width: isReordering
                  ? reorderSize
                  : layout.widths[i] + trimExpand * 2,
              height: TimelineConstants.thumbnailStripHeight,
              child: _TrimmableClipTile(
                clip: orderedClips[i],
                clipWidth: layout.widths[i],
                pixelsPerSecond: pixelsPerSecond,
                thumbnailNotifier: thumbnails[orderedClips[i].id],
                waveformNotifier: isReordering
                    ? null
                    : waveforms[orderedClips[i].id],
                onTrimChanged: onTrimChanged,
                onTrimDragChanged: onTrimDragChanged,
                trimExpand: trimExpand,
                onTap: onClipTapped != null ? () => onClipTapped!(i) : null,
              ),
            ),
      ],
    );
  }
}

class _NonTrimmingClipPositions extends StatelessWidget {
  const _NonTrimmingClipPositions({
    required this.orderedClips,
    required this.thumbnails,
    required this.waveforms,
    required this.layout,
    required this.wrap,
    required this.dragIndex,
    required this.trimmingClipId,
    required this.shouldAnimate,
    required this.animDuration,
    required this.animCurve,
    required this.isReordering,
    required this.rowOffset,
    required this.reorderSlotStep,
    required this.pixelsPerSecond,
    required this.onReorder,
    required this.onClipTapped,
    required this.rowOffsetSize,
    required this.isVolumeEditMode,
    required this.volumeRowStep,
    required this.isMultiSelectMode,
    required this.selectedClipIds,
  });

  final List<DivineVideoClip> orderedClips;
  final ClipThumbnailManager thumbnails;
  final ClipWaveformManager waveforms;
  final ({List<double> widths, List<double> offsets, double totalWidth}) layout;

  /// Loop-wrap display geometry (or [LoopWrapDisplay.none]). The first clip's
  /// head plays inside the blend seam at the loop point, so its thumbnails start
  /// [LoopWrapDisplay.consumedPerSide] later; the last clip's tail is clipped by
  /// its shortened [layout] width.
  final LoopWrapDisplay wrap;

  final int? dragIndex;
  final String? trimmingClipId;
  final bool shouldAnimate;
  final Duration animDuration;
  final Curve animCurve;
  final bool isReordering;
  final double rowOffset;
  final double reorderSlotStep;
  final double pixelsPerSecond;
  final ClipReorderCallback onReorder;
  final ValueChanged<int>? onClipTapped;
  final double rowOffsetSize;
  final bool isVolumeEditMode;
  final double volumeRowStep;
  final bool isMultiSelectMode;
  final Set<String> selectedClipIds;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: .none,
      children: [
        for (int i = 0; i < orderedClips.length; i++)
          if (i != dragIndex && orderedClips[i].id != trimmingClipId)
            AnimatedPositioned(
              key: ValueKey(orderedClips[i].id),
              duration: shouldAnimate ? animDuration : Duration.zero,
              curve: animCurve,
              left: isReordering
                  ? rowOffset + i * reorderSlotStep
                  : layout.offsets[i],
              top: isVolumeEditMode ? i * volumeRowStep : 0,
              width: isReordering ? rowOffsetSize : layout.widths[i],
              height: TimelineConstants.thumbnailStripHeight,
              child: _AccessibleClipTile(
                clip: orderedClips[i],
                index: i,
                total: orderedClips.length,
                clipWidth: layout.widths[i],
                pixelsPerSecond: pixelsPerSecond,
                // Shift the first clip's thumbnails past its wrap-consumed head
                // so they match the shortened strip (and the playhead). Skipped
                // while reordering, where the tile is a fixed square slot.
                wrapHeadOffset: !isReordering && wrap.isActive && i == 0
                    ? wrap.consumedPerSide.inMilliseconds /
                          1000.0 *
                          pixelsPerSecond
                    : 0.0,
                thumbnailNotifier: thumbnails[orderedClips[i].id],
                // Every tile is a 64px badge mid-drag — no room for a band.
                waveformNotifier: isReordering
                    ? null
                    : waveforms[orderedClips[i].id],
                onReorder: onReorder,
                onTap: onClipTapped,
                isMultiSelectMode: isMultiSelectMode,
                isSelected: selectedClipIds.contains(orderedClips[i].id),
              ),
            ),
      ],
    );
  }
}

class _DraggedClipPosition extends StatelessWidget {
  const _DraggedClipPosition({
    required this.orderedClips,
    required this.thumbnails,
    required this.layout,
    required this.dragIndex,
    required this.dragAnimating,
    required this.animDuration,
    required this.animCurve,
    required this.dragStartClipCenter,
    required this.dragClipWidth,
    required this.effectiveLocalX,
    required this.dragFingerRatio,
    required this.pixelsPerSecond,
  });

  final List<DivineVideoClip> orderedClips;
  final ClipThumbnailManager thumbnails;
  final ({List<double> widths, List<double> offsets, double totalWidth}) layout;
  final int? dragIndex;
  final bool dragAnimating;
  final Duration animDuration;
  final Curve animCurve;
  final double dragStartClipCenter;
  final double dragClipWidth;
  final double effectiveLocalX;
  final double dragFingerRatio;
  final double pixelsPerSecond;

  @override
  Widget build(BuildContext context) {
    return AnimatedPositioned(
      key: const ValueKey('timeline-clip-dragged'),
      duration: dragAnimating ? animDuration : Duration.zero,
      curve: animCurve,
      left: dragAnimating
          ? dragStartClipCenter - dragClipWidth / 2
          : effectiveLocalX - dragClipWidth * dragFingerRatio,
      top: 0,
      width: dragClipWidth,
      height: TimelineConstants.thumbnailStripHeight,
      child: _DraggedClipTile(
        clip: orderedClips[dragIndex!],
        index: dragIndex!,
        pixelsPerSecond: pixelsPerSecond,
        thumbnailNotifier: thumbnails[orderedClips[dragIndex!].id],
      ),
    );
  }
}

/// Positions a [_TransitionButton] over every internal clip boundary, centred
/// on the gap between adjacent clips (TikTok-style).
class _TransitionButtonsLayer extends StatelessWidget {
  const _TransitionButtonsLayer({required this.clips, required this.layout});

  final List<DivineVideoClip> clips;
  final ({List<double> widths, List<double> offsets, double totalWidth}) layout;

  /// Visible glyph circle.
  static const double _visualSize = 26;

  /// Tap target around the glyph. The 1px clip gap leaves no horizontal room,
  /// so the target overlaps the neighbours and is enlarged toward the
  /// accessibility floor where the strip has room (vertically) without
  /// swallowing too much of the adjacent clips (horizontally).
  static const double _hitWidth = 36;
  static const double _hitHeight = 48;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (int i = 0; i < clips.length - 1; i++)
          Positioned(
            left:
                layout.offsets[i] +
                layout.widths[i] +
                TimelineConstants.clipGap / 2 -
                _hitWidth / 2,
            top: (TimelineConstants.thumbnailStripHeight - _hitHeight) / 2,
            width: _hitWidth,
            height: _hitHeight,
            child: _TransitionButton(
              visualSize: _visualSize,
              hasTransition: clips[i].transition != null,
              onTap: () => editClipTransition(context, i),
            ),
          ),
      ],
    );
  }
}

/// The loop-blend seam region drawn after the last clip: the span where the
/// last clip's tail dissolves into the first clip's head on restart. Its width
/// is the seam's real playback length ([LoopWrapDisplay.seamDuration]), so the
/// playhead traverses it exactly while the blend plays in the preview.
///
/// Rendered as the actual blend: the last clip's tail frame cross-fading into
/// the first clip's head frame along the region — the same frames the
/// transition picker previews. Falls back to a tinted box when neither frame
/// resolves.
class _LoopSeamRegion extends StatelessWidget {
  const _LoopSeamRegion({
    required this.left,
    required this.width,
    required this.tailFramePath,
    required this.headFramePath,
  });

  final double left;
  final double width;

  /// Last clip's tail frame (ghost frame / thumbnail), fading out.
  final String? tailFramePath;

  /// First clip's head frame (thumbnail), fading in toward the loop point.
  final String? headFramePath;

  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(
      color: VineTheme.primary.withValues(alpha: 0.18),
    );
    final tail = _frame(tailFramePath);
    final head = _frame(headFramePath);
    return Positioned(
      left: left,
      top: 0,
      width: width,
      height: TimelineConstants.thumbnailStripHeight,
      child: ClipRRect(
        borderRadius: const BorderRadius.horizontal(
          right: Radius.circular(TimelineConstants.thumbnailRadius),
        ),
        child: ExcludeSemantics(
          child: Stack(
            fit: .expand,
            children: [
              tail ?? fallback,
              if (head != null)
                ShaderMask(
                  // Only the gradient's alpha matters (dstIn masks the head
                  // frame in from transparent to opaque across the region).
                  shaderCallback: (rect) => const LinearGradient(
                    colors: [Colors.transparent, VineTheme.whiteText],
                  ).createShader(rect),
                  blendMode: BlendMode.dstIn,
                  child: head,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget? _frame(String? path) {
    if (path == null) return null;
    return Image.file(
      File(path),
      fit: .cover,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    );
  }
}

/// Positions the loop-restart button centred on the strip's end edge — the
/// "end" side of the wrap seam where the last clip's tail flows into the first
/// clip's head so a looping player restarts seamlessly. Straddles the edge like
/// the between-clip buttons straddle their seams; the strip reserves a
/// half-button trailing slot so the right half isn't clipped. Shown even for a
/// single clip, which wraps into itself.
class _LoopTransitionButton extends StatelessWidget {
  const _LoopTransitionButton({
    required this.hasTransition,
    required this.layout,
  });

  final bool hasTransition;
  final ({List<double> widths, List<double> offsets, double totalWidth}) layout;

  @override
  Widget build(BuildContext context) {
    final foreground = hasTransition
        ? context.vineColors.accentPositive
        : context.vineColors.secondaryText;
    final left = math.max(
      0.0,
      layout.totalWidth - _TransitionButtonsLayer._hitWidth / 2,
    );
    return Positioned(
      left: left,
      top:
          (TimelineConstants.thumbnailStripHeight -
              _TransitionButtonsLayer._hitHeight) /
          2,
      width: _TransitionButtonsLayer._hitWidth,
      height: _TransitionButtonsLayer._hitHeight,
      child: Semantics(
        button: true,
        label: context.l10n.videoEditorLoopTransitionButtonSemanticLabel,
        child: GestureDetector(
          onTap: () => editLoopTransition(context),
          behavior: HitTestBehavior.opaque,
          child: Center(
            child: SizedBox.square(
              dimension: _TransitionButtonsLayer._visualSize,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: context.vineColors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: foreground, width: 1.5),
                ),
                child: Center(
                  child: DivineIcon(
                    icon: DivineIconName.repeat,
                    size: 14,
                    color: foreground,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TransitionButton extends StatelessWidget {
  const _TransitionButton({
    required this.hasTransition,
    required this.onTap,
    required this.visualSize,
  });

  final bool hasTransition;
  final VoidCallback onTap;

  /// Diameter of the visible glyph circle, centred inside the larger tap target.
  final double visualSize;

  @override
  Widget build(BuildContext context) {
    final foreground = hasTransition
        ? context.vineColors.accentPositive
        : context.vineColors.secondaryText;
    return Semantics(
      button: true,
      label: context.l10n.videoEditorTransitionButtonSemanticLabel,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: SizedBox.square(
            dimension: visualSize,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: context.vineColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: foreground, width: 1.5),
              ),
              child: Center(
                child: CustomPaint(
                  size: const Size(10, 10),
                  painter: _TransitionGlyphPainter(color: foreground),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints the universal "transition" bowtie glyph — two triangles meeting at
/// the centre.
class _TransitionGlyphPainter extends CustomPainter {
  const _TransitionGlyphPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final w = size.width;
    final h = size.height;
    final left = Path()
      ..moveTo(0, 0)
      ..lineTo(w / 2, h / 2)
      ..lineTo(0, h)
      ..close();
    final right = Path()
      ..moveTo(w, 0)
      ..lineTo(w / 2, h / 2)
      ..lineTo(w, h)
      ..close();
    canvas
      ..drawPath(left, paint)
      ..drawPath(right, paint);
  }

  @override
  bool shouldRepaint(_TransitionGlyphPainter oldDelegate) =>
      oldDelegate.color != color;
}
