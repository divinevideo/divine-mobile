import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/constants/video_editor_timeline_constants.dart';
import 'package:openvine/extensions/video_editor_extensions.dart';
import 'package:openvine/extensions/video_editor_history_extensions.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/stop_motion/stop_motion_frame_ops.dart';
import 'package:openvine/models/timeline_overlay_item.dart';
import 'package:openvine/models/video_editor/transition_geometry.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_timeline_control_bar.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/strips/video_editor_timeline_clip_strip.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/video_editor_timeline_geometry.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/video_editor_timeline_header.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/video_editor_timeline_interactive_body.dart';
import 'package:openvine/widgets/video_editor/tune_editor/tune_set_timeline_ops.dart';

/// Interactive timeline editor for composing video clips.
///
/// Displays a scrollable ruler with time markers, clip thumbnail
/// strips, and a fixed-center playhead. Reads playback position and
/// duration from [VideoEditorMainBloc] and clip data from
/// [ClipEditorBloc].
class VideoEditorTimelineScaffold extends StatefulWidget {
  const VideoEditorTimelineScaffold({super.key});

  @override
  State<VideoEditorTimelineScaffold> createState() =>
      _VideoEditorTimelineState();
}

class _VideoEditorTimelineState extends State<VideoEditorTimelineScaffold> {
  /// Duration for the user-triggered timeline hide/show animation.
  static const _timelineToggleDuration = Duration(milliseconds: 220);

  late final ScrollController _scrollController;
  late final ScrollController _verticalScrollController;

  /// Vertical scroll for the overlay-strips area inside the timeline body.
  /// Reset to 0 on entering volume-edit mode so the strips realign with the
  /// volume arcs (which are pinned to the top) instead of staying frozen at a
  /// previously-scrolled offset.
  late final ScrollController _overlayStripsScrollController;
  bool _isUserScrolling = false;

  double _pixelsPerSecond = TimelineConstants.pixelsPerSecond;

  /// One-shot: the first time a stop-motion composition lands, the zoom is
  /// bumped so its tens-of-ms stills are actually visible (the video default
  /// renders them a couple of pixels wide). Never re-fires, so a user pinch
  /// is not overridden.
  bool _didAutoZoomStopMotion = false;

  /// Cached total duration from clip editor — used by scroll listeners
  /// that fire outside the build phase.
  Duration _totalDuration = Duration.zero;

  /// Cached loop-wrap display geometry from the last build (suspended while
  /// trimming, matching the strip) — used by the scroll/pinch mappings that
  /// fire outside build so the playhead lines up with the shortened strip.
  LoopWrapDisplay _wrapDisplay = LoopWrapDisplay.none;

  /// Playhead time derived from scroll offset — always matches the visual
  /// playhead regardless of zoom level.
  final _playheadPosition = ValueNotifier<Duration>(Duration.zero);
  final _volumePreviewNotifier = ValueNotifier<double?>(null);

  /// Scope notifier for the fine editor play time, cached in
  /// [didChangeDependencies]. Driven from the scroll offset while the user
  /// scrubs so canvas overlays (the CC caption pill) follow the scrub live.
  ValueNotifier<Duration>? _scopePlayTimeNotifier;

  /// Active pointer positions — when ≥ 2 we compute pinch scale.
  final Map<int, Offset> _pointerPositions = {};

  /// Distance between two pointers when the pinch started.
  double _pinchBaseDistance = 0;

  /// [_pixelsPerSecond] captured when the pinch started.
  double _pinchBasePps = 0;

  bool get _isPinching => _pointerPositions.length >= 2;

  /// Throttle timestamp — limits BLoC event frequency during scrubbing.
  /// The native seek backpressure is handled by the canvas.
  int _lastSeekMs = 0;
  static const _seekThrottleMs = 16;

  /// Whether a trim handle drag is in progress — disables scroll physics.
  bool _isTrimming = false;
  List<DivineVideoClip>? _clipTrimStartClips;
  List<Duration>? _clipTrimStartMarkers;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_updatePlayheadTime);
    _verticalScrollController = ScrollController();
    _overlayStripsScrollController = ScrollController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scopePlayTimeNotifier = VideoEditorScope.of(context).playTimeNotifier;
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_updatePlayheadTime)
      ..dispose();
    _verticalScrollController.dispose();
    _overlayStripsScrollController.dispose();
    _playheadPosition.dispose();
    _volumePreviewNotifier.dispose();
    super.dispose();
  }

  double _contentWidth(Duration totalDuration) =>
      totalDuration.inMilliseconds / 1000.0 * _pixelsPerSecond;

  @override
  Widget build(BuildContext context) {
    final (
      :clips,
      :totalDuration,
      :isEditing,
      :currentClipIndex,
      :isMultiSelectMode,
      :selectedClipIds,
    ) = context.select(
      (ClipEditorBloc b) => (
        clips: b.state.clips,
        totalDuration: b.state.totalDuration,
        isEditing: b.state.isEditing,
        currentClipIndex: b.state.currentClipIndex,
        isMultiSelectMode: b.state.isMultiSelectMode,
        selectedClipIds: b.state.selectedClipIds,
      ),
    );
    // Kept mounted even while [clips] is empty so it catches the transition
    // into the first (async-loaded) stop-motion composition — see
    // [_autoZoomForFirstStopMotion]. The root of both the empty and non-empty
    // branches is this same [BlocListener] type, so its subscription survives
    // the empty→populated rebuild.
    if (clips.isEmpty) {
      return BlocListener<ClipEditorBloc, ClipEditorState>(
        listenWhen: _shouldAutoZoomForStopMotion,
        listener: _autoZoomForFirstStopMotion,
        child: const SizedBox.shrink(),
      );
    }

    final trimmingClipId =
        isEditing && currentClipIndex >= 0 && currentClipIndex < clips.length
        ? clips[currentClipIndex].id
        : null;

    // With a loop transition, the display axis differs from the raw clip sum:
    // the wrap-consumed head/tail plays inside the blend seam region appended
    // at the end (see [LoopWrapDisplay]). Suspended while trimming, matching
    // the clip strip. `displayDuration` equals `totalDuration` without a wrap.
    final wrapDisplay = trimmingClipId != null
        ? LoopWrapDisplay.none
        : LoopWrapDisplay.fromClips(clips);
    final displayDuration = wrapDisplay.displayTotal(clips);
    _totalDuration = displayDuration;
    _wrapDisplay = wrapDisplay;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final halfScreen = screenWidth / 2;
    final totalWidth = _contentWidth(displayDuration);

    final hasSelectedOverlay = context.select(
      (TimelineOverlayBloc b) => b.state.selectedItemId != null,
    );

    final isTimelineHiddenByUser = context.select(
      (VideoEditorMainBloc b) => b.state.isTimelineHiddenByUser,
    );
    final isMarkerMode = context.select(
      (VideoEditorMainBloc b) => b.state.isMarkerMode,
    );
    // Sync layers from main editor to timeline overlay bloc, and
    // sync scroll to playback position while not user-scrolling.
    final Widget body = MultiBlocListener(
      listeners: [
        BlocListener<ClipEditorBloc, ClipEditorState>(
          listenWhen: (prev, curr) => prev.totalDuration != curr.totalDuration,
          listener: (context, state) {
            // _totalDuration is not updated here: build recomputes it on every
            // rebuild (all its inputs are in the context.select record above)
            // and, unlike this listener, correctly suspends the loop-wrap
            // shortening while a trim gesture is active.
            final overlayBloc = context.read<TimelineOverlayBloc>();
            overlayBloc.add(
              TimelineOverlayTotalDurationChanged(
                state.totalDuration,
                isClipTrimDragging: state.isTrimDragging,
              ),
            );
            final rebasedMarkers = _rebasedClipTrimMarkers(state.clips);
            if (rebasedMarkers != null) {
              overlayBloc.add(TimelineMarkersRebased(rebasedMarkers));
            }
          },
        ),
        // Live J-Cut: while a clip trim is in progress, move anchored audio
        // bars to follow the clip every frame. The final positions are
        // committed to history + the native player on release (setClipState).
        BlocListener<ClipEditorBloc, ClipEditorState>(
          listenWhen: (prev, curr) =>
              curr.isTrimDragging && prev.clips != curr.clips,
          listener: (context, state) {
            final overlayBloc = context.read<TimelineOverlayBloc>();
            final rebased = rebaseAnchoredAudioForClipState(
              state.clips,
              overlayBloc.state.audioTracks,
            );
            if (!identical(rebased, overlayBloc.state.audioTracks)) {
              overlayBloc.add(TimelineOverlayAnchoredAudioRebased(rebased));
            }
          },
        ),
        BlocListener<VideoEditorMainBloc, VideoEditorMainState>(
          listenWhen: (prev, curr) =>
              !_isUserScrolling && prev.currentPosition != curr.currentPosition,
          listener: (context, state) =>
              _syncScrollToPosition(state.currentPosition, totalDuration),
        ),
        BlocListener<VideoEditorMainBloc, VideoEditorMainState>(
          listenWhen: (prev, curr) =>
              !prev.isVolumeEditMode && curr.isVolumeEditMode,
          listener: (context, state) {
            // The overlay-strips scroll is frozen while in volume mode, so
            // reset it to the top first — otherwise it stays stuck at the
            // previously-scrolled offset and hides the upper strips/arcs.
            if (_overlayStripsScrollController.hasClients) {
              _overlayStripsScrollController.jumpTo(0);
            }
            final clipBloc = context.read<ClipEditorBloc>();
            if (clipBloc.state.isEditing) {
              clipBloc.add(const ClipEditorEditingToggled());
            }
            context.read<TimelineOverlayBloc>().add(
              const TimelineOverlayItemSelected(null),
            );
            _exitMarkerMode(context);
          },
        ),
        BlocListener<VideoEditorMainBloc, VideoEditorMainState>(
          listenWhen: (prev, curr) =>
              prev.isVolumeEditMode && !curr.isVolumeEditMode,
          listener: (context, state) {
            if (_verticalScrollController.hasClients) {
              _verticalScrollController.jumpTo(0);
            }
            _volumePreviewNotifier.value = null;
          },
        ),
        BlocListener<VideoEditorMainBloc, VideoEditorMainState>(
          listenWhen: (prev, curr) =>
              prev.isTimelineHiddenByUser != curr.isTimelineHiddenByUser,
          listener: (context, state) {
            final clipBloc = context.read<ClipEditorBloc>();
            if (clipBloc.state.isEditing) {
              clipBloc.add(const ClipEditorEditingToggled());
            }

            final bloc = context.read<TimelineOverlayBloc>();
            bloc.add(const TimelineOverlayItemSelected(null));
            _exitMarkerMode(context);
          },
        ),
        // Marker mode owns the bottom controls bar exclusively, so entering it
        // clears any clip edit / overlay selection / volume mode. Reordering
        // needs no clearing here even though it isn't in the FAB's hide
        // condition: it's an active single-pointer drag holding the touch that
        // would otherwise tap the FAB, so entry can't race an ongoing reorder.
        BlocListener<VideoEditorMainBloc, VideoEditorMainState>(
          listenWhen: (prev, curr) => !prev.isMarkerMode && curr.isMarkerMode,
          listener: (context, state) {
            final clipBloc = context.read<ClipEditorBloc>();
            if (clipBloc.state.isEditing) {
              clipBloc.add(const ClipEditorEditingToggled());
            }
            context.read<TimelineOverlayBloc>().add(
              const TimelineOverlayItemSelected(null),
            );
            final mainBloc = context.read<VideoEditorMainBloc>();
            if (mainBloc.state.isVolumeEditMode) {
              mainBloc.add(const VideoEditorVolumeEditModeToggled());
            }
          },
        ),
        // Selecting an overlay item leaves marker mode.
        BlocListener<TimelineOverlayBloc, TimelineOverlayState>(
          listenWhen: (prev, curr) =>
              prev.selectedItemId == null && curr.selectedItemId != null,
          listener: (context, state) => _exitMarkerMode(context),
        ),
        // Starting clip editing or multi-select leaves marker mode.
        BlocListener<ClipEditorBloc, ClipEditorState>(
          listenWhen: (prev, curr) =>
              (!prev.isEditing && curr.isEditing) ||
              (!prev.isMultiSelectMode && curr.isMultiSelectMode),
          listener: (context, state) => _exitMarkerMode(context),
        ),
      ],
      child: GestureDetector(
        onTap: isEditing || hasSelectedOverlay ? _onBackgroundTapped : null,
        behavior: HitTestBehavior.translucent,
        child: Stack(
          alignment: .bottomCenter,
          children: [
            Column(
              crossAxisAlignment: .stretch,
              children: [
                VideoEditorTimelineHeader(
                  playheadPosition: _playheadPosition,
                  volumePreviewNotifier: _volumePreviewNotifier,
                ),
                Padding(
                  padding: const .only(top: 12),
                  child: Divider(
                    height: 1,
                    thickness: 1,
                    color: context.vineColors.surfaceContainer,
                  ),
                ),

                AnimatedContainer(
                  duration: _timelineToggleDuration,
                  height: isTimelineHiddenByUser
                      ? MediaQuery.viewPaddingOf(context).bottom
                      : TimelineConstants.height,
                  child: OverflowBox(
                    alignment: .topCenter,
                    minHeight: TimelineConstants.height,
                    maxHeight: TimelineConstants.height,
                    child: VideoEditorTimelineInteractiveBody(
                      playheadPosition: _playheadPosition,
                      totalDuration: displayDuration,
                      formatPosition: (pos) {
                        final totalSeconds = pos.inMilliseconds / 1000.0;
                        final minutes = totalSeconds ~/ 60;
                        final seconds = (totalSeconds % 60).toStringAsFixed(1);
                        return context.l10n.videoEditorTimelinePositionFormat(
                          minutes,
                          seconds,
                        );
                      },
                      onStepPosition: _stepPosition,
                      onPointerDown: _onPointerDown,
                      onPointerMove: _onPointerMove,
                      onPointerUp: _onPointerUp,
                      onPointerCancel: _onPointerCancel,
                      onScrollNotification: _handleScrollNotification,
                      scrollController: _scrollController,
                      isPinching: _isPinching,
                      isTrimming: _isTrimming,
                      halfScreen: halfScreen,
                      pixelsPerSecond: _pixelsPerSecond,
                      clips: clips,
                      totalWidth: totalWidth,
                      isInteracting: _isUserScrolling || _isPinching,
                      onReorder: _onClipsReordered,
                      onReorderChanged: _onReorderChanged,
                      trimmingClipId: trimmingClipId,
                      onTrimChanged: _onClipTrimChange,
                      onTrimDragChanged: _onTrimDragChanged,
                      onClipTapped: _onClipTapped,
                      isMultiSelectMode: isMultiSelectMode,
                      selectedClipIds: selectedClipIds,
                      onOverlayItemMoved: _onOverlayItemMoved,
                      onOverlayItemMoving: _onOverlayItemMoving,
                      onOverlayItemTrimmed: _onOverlayItemTrimmed,
                      onOverlayTrimDragChanged: _onOverlayTrimDragChanged,
                      onOverlayItemTapped: _onOverlayItemTapped,
                      onOverlayDragStarted: _onOverlayDragStarted,
                      onOverlayDragEnded: _onOverlayDragEnded,
                      verticalScrollController: _verticalScrollController,
                      overlayStripsScrollController:
                          _overlayStripsScrollController,
                      volumePreviewNotifier: _volumePreviewNotifier,
                    ),
                  ),
                ),
              ],
            ),

            TimelineControlsBar(
              isEditing: isEditing,
              isMarkerMode: isMarkerMode,
              playheadPosition: _playheadPosition,
            ),
          ],
        ),
      ),
    );

    return BlocListener<ClipEditorBloc, ClipEditorState>(
      listenWhen: _shouldAutoZoomForStopMotion,
      listener: _autoZoomForFirstStopMotion,
      child: Semantics(identifier: SemanticIds.editorTimeline, child: body),
    );
  }

  /// One-shot: the first time a stop-motion composition lands, the zoom is
  /// bumped so its tens-of-ms stills are actually visible (the video default
  /// renders them a couple of pixels wide). Guarded by
  /// [_didAutoZoomStopMotion] so it never re-fires — a user pinch is not
  /// overridden.
  bool _shouldAutoZoomForStopMotion(
    ClipEditorState prev,
    ClipEditorState curr,
  ) =>
      !_didAutoZoomStopMotion &&
      !isStopMotionComposition(prev.clips) &&
      isStopMotionComposition(curr.clips);

  void _autoZoomForFirstStopMotion(
    BuildContext context,
    ClipEditorState state,
  ) {
    setState(() {
      _didAutoZoomStopMotion = true;
      _pixelsPerSecond = stopMotionInitialPixelsPerSecond(
        state.clips.first.stopMotionFrames ?? const [],
      );
    });
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    // A drag that grabs the timeline during playback can start without a
    // ScrollStartNotification: when a playback-sync animateTo restarts
    // between touch-down and drag-start, the framework sees a
    // scrolling→scrolling activity transition and skips didStartScroll.
    // Drag-driven updates always carry dragDetails, so they detect the
    // scrub too.
    final isUserDrag = switch (notification) {
      ScrollStartNotification(:final dragDetails) => dragDetails != null,
      ScrollUpdateNotification(:final dragDetails) => dragDetails != null,
      _ => false,
    };
    if (isUserDrag && !_isUserScrolling) {
      _isUserScrolling = true;
      // Explicitly pause video while scrubbing so seekTo shows each frame.
      context.read<VideoEditorMainBloc>().add(
        const VideoEditorExternalPauseRequested(isPaused: true),
      );
    }
    if (notification is ScrollUpdateNotification && _isUserScrolling) {
      _syncPositionFromScroll();
    } else if (notification is ScrollEndNotification && _isUserScrolling) {
      _isUserScrolling = false;
      _syncPositionFromScroll(force: true);
    }
    return false;
  }

  // -- Reorder callbacks ----------------------------------------------------

  void _onClipsReordered(List<DivineVideoClip> reorderedClips) {
    final clipBloc = context.read<ClipEditorBloc>();
    final overlayBloc = context.read<TimelineOverlayBloc>();
    final rebasedMarkers = rebaseTimelineMarkersForClipState(
      oldClips: clipBloc.state.clips,
      newClips: reorderedClips,
      markers: overlayBloc.state.timelineMarkers,
    );

    clipBloc.add(ClipEditorInitialized(reorderedClips));
    overlayBloc.add(TimelineMarkersRebased(rebasedMarkers));
    context.read<VideoEditorMainBloc>().add(
      const VideoEditorExternalPauseRequested(isPaused: true),
    );
    // Persist reorder and marker rebasing as one history entry so undo
    // restores a consistent timeline.
    final editor = VideoEditorScope.of(context).editor;
    editor?.setClipState(reorderedClips, timelineMarkers: rebasedMarkers);
  }

  void _onReorderChanged(bool isReordering) {
    final bloc = context.read<VideoEditorMainBloc>();
    bloc.add(VideoEditorReorderingChanged(isReordering: isReordering));
    if (isReordering) {
      bloc.add(const VideoEditorExternalPauseRequested(isPaused: true));
      // Exit clip trim mode so handles disappear during reorder.
      final clipEditorBloc = context.read<ClipEditorBloc>();
      if (clipEditorBloc.state.isEditing) {
        clipEditorBloc.add(const ClipEditorEditingToggled());
      }
      // Deselect overlay item so trim handles disappear during reorder.
      context.read<TimelineOverlayBloc>().add(
        const TimelineOverlayItemSelected(null),
      );
      _exitMarkerMode(context);
    }
  }

  /// Leaves marker-placement mode if it is active.
  void _exitMarkerMode(BuildContext context) {
    final bloc = context.read<VideoEditorMainBloc>();
    if (bloc.state.isMarkerMode) {
      bloc.add(const VideoEditorMarkerModeChanged(isActive: false));
    }
  }

  // -- Trim callbacks -------------------------------------------------------

  void _onClipTrimChange({
    required String clipId,
    required bool isStart,
    required Duration trimStart,
    required Duration trimEnd,
  }) {
    context.read<ClipEditorBloc>().add(
      ClipEditorTrimUpdated(
        clipId: clipId,
        isStart: isStart,
        trimStart: trimStart,
        trimEnd: trimEnd,
      ),
    );
  }

  void _onTrimDragChanged(bool isTrimming) {
    setState(() => _isTrimming = isTrimming);
    final editor = VideoEditorScope.of(context).requireEditor;
    final clipEditorBloc = context.read<ClipEditorBloc>();
    final overlayBloc = context.read<TimelineOverlayBloc>();

    if (isTrimming) {
      _clipTrimStartClips = List<DivineVideoClip>.of(
        clipEditorBloc.state.clips,
      );
      _clipTrimStartMarkers = List<Duration>.of(
        overlayBloc.state.timelineMarkers,
      );
      clipEditorBloc.add(const ClipEditorTrimDragStarted());

      context.read<VideoEditorMainBloc>().add(
        const VideoEditorExternalPauseRequested(isPaused: true),
      );
    } else {
      final rebasedMarkers =
          _rebasedClipTrimMarkers(clipEditorBloc.state.clips) ??
          overlayBloc.state.timelineMarkers;
      overlayBloc.add(TimelineMarkersRebased(rebasedMarkers));
      clipEditorBloc.add(const ClipEditorTrimDragEnded());

      // Dragging a trim handle back out lengthens the composition, so a sound
      // that covered the old end has to grow with it (#6401); a trim that
      // only shortened the clip passes through unchanged.
      editor.setLengthenedClipState(
        previousClips: _clipTrimStartClips ?? clipEditorBloc.state.clips,
        clips: clipEditorBloc.state.clips,
        timelineMarkers: rebasedMarkers,
      );
      _clipTrimStartClips = null;
      _clipTrimStartMarkers = null;
    }
  }

  List<Duration>? _rebasedClipTrimMarkers(List<DivineVideoClip> clips) {
    final oldClips = _clipTrimStartClips;
    final markers = _clipTrimStartMarkers;
    if (oldClips == null || markers == null) return null;

    return rebaseTimelineMarkersForClipState(
      oldClips: oldClips,
      newClips: clips,
      markers: markers,
    );
  }

  // -- Clip tap callback ----------------------------------------------------

  void _onClipTapped(int index) {
    final bloc = context.read<ClipEditorBloc>();
    final state = bloc.state;

    // In multi-select mode a tap toggles the clip's membership instead of
    // entering single-clip editing.
    if (state.isMultiSelectMode) {
      if (index < 0 || index >= state.clips.length) return;
      bloc.add(ClipEditorMultiSelectClipToggled(state.clips[index].id));
      return;
    }

    // Deselect any overlay item when a clip is tapped.
    context.read<TimelineOverlayBloc>().add(
      const TimelineOverlayItemSelected(null),
    );

    if (index == state.currentClipIndex) {
      // Same clip: toggle editing on/off.
      bloc.add(const ClipEditorEditingToggled());
    } else {
      // Different clip: select it and enter editing if not already active.
      bloc.add(ClipEditorClipSelected(index));
      if (!state.isEditing) {
        bloc.add(const ClipEditorEditingStarted());
      }
    }
  }

  void _onBackgroundTapped() {
    final bloc = context.read<ClipEditorBloc>();
    if (bloc.state.isEditing) {
      bloc.add(const ClipEditorEditingToggled());
    }
    // Deselect any overlay item.
    context.read<TimelineOverlayBloc>().add(
      const TimelineOverlayItemSelected(null),
    );
  }

  // -- Overlay callbacks ----------------------------------------------------

  void _onOverlayItemMoved({
    required TimelineOverlayItem item,
    required Duration startTime,
    required int row,
    required bool insertAbove,
  }) {
    // Sync the new time position to the editor before updating BLoC state so
    // the canvas reflects the move immediately.
    final editor = VideoEditorScope.of(context).requireEditor;
    final duration = item.duration;

    // Compute the correct list insertion index from current BLoC row
    // assignments. targetRow is a visual row number, but the editor
    // list may have multiple items per row (non-overlapping items
    // share rows). Using targetRow directly as a list index would
    // misplace the item.
    final targetIdx = _targetListIndex(
      type: item.type,
      draggedItemId: item.id,
      targetRow: row,
      insertAbove: insertAbove,
    );

    switch (item.type) {
      case .layer:
        final layers = editor.activeLayers;
        final layerIdx = layers.indexWhere((l) => l.id == item.id);

        editor.setLayerTimeline(
          index: layerIdx,
          startTime: startTime,
          endTime: startTime + duration,
          skipUpdateHistory: true,
        );

        // Reorder layers so the editor array matches the row order.
        // _assignRows derives rows from list position, so moving a
        // layer earlier/later in the list determines its row.
        _reorderEditorList(layers, layerIdx, targetIdx);

      case .filter:
        final filters = editor.stateManager.activeFilters;
        final filterIdx = filters.indexWhere((e) => e.id == item.id);

        editor.setFilterTimeline(
          index: filterIdx,
          startTime: startTime,
          endTime: startTime + duration,
          skipUpdateHistory: true,
        );

        _reorderEditorList(filters, filterIdx, targetIdx);

      case .tune:
        // A tune bar is a *set* of adjustments sharing one window; retime every
        // member. Order is irrelevant for non-overlapping color filters, so no
        // reorder.
        retimeTuneSet(
          editor,
          setId: item.id,
          startTime: startTime,
          endTime: startTime + duration,
        );

      case .sound:
        final audioTracks = editor.stateManager.audioTracks;
        final audioIdx = audioTracks.indexWhere((e) => e.id == item.id);

        editor.setSoundTimeline(
          index: audioIdx,
          startTime: startTime,
          endTime: startTime + duration,
          skipUpdateHistory: true,
          // Manually moving the track detaches it from its source clip so it
          // stops following clip trims and becomes an independent track.
          clearAnchor: true,
        );

        _reorderEditorList(audioTracks, audioIdx, targetIdx);

      case .captions:
        // Overlapping cues stack rows via the bloc's generic lane packing;
        // there is no editor list to reorder for captions. The cue timeline
        // write also syncs the burned-in layer when present.
        editor.setCaptionCueTimeline(
          cueId: item.id,
          startTime: startTime,
          endTime: startTime + duration,
          skipUpdateHistory: true,
        );
    }

    context.read<TimelineOverlayBloc>().add(
      TimelineOverlayItemMoved(
        itemId: item.id,
        startTime: startTime,
        row: row,
        insertAbove: insertAbove,
      ),
    );
  }

  /// Returns the list index at which the dragged item should be
  /// inserted so that [_assignRows] places it on [targetRow].
  ///
  /// The BLoC items of the same [type] are in the same order as the
  /// editor list. By looking at their current row assignments we can
  /// map a visual row number to the correct list position — even when
  /// multiple non-overlapping items share a single row.
  ///
  /// The returned index is relative to the list *without* the dragged
  /// item (matching what [_reorderEditorList] has after `removeAt`).
  int _targetListIndex({
    required TimelineOverlayType type,
    required String draggedItemId,
    required int targetRow,
    required bool insertAbove,
  }) {
    final blocItems = context
        .read<TimelineOverlayBloc>()
        .state
        .items
        .where((i) => i.type == type && i.id != draggedItemId)
        .toList();

    if (insertAbove) {
      // Insert before the first item on or after targetRow.
      final idx = blocItems.indexWhere((i) => i.row >= targetRow);
      return idx == -1 ? blocItems.length : idx;
    } else {
      // Insert after the last item on or before targetRow.
      final idx = blocItems.lastIndexWhere((i) => i.row <= targetRow);
      return idx + 1;
    }
  }

  /// Reorders an editor list (layers, filters, audioTracks) so that the
  /// dragged element at [currentIdx] moves to [targetIdx].
  ///
  /// [targetIdx] is the insertion position in the list *after* removing
  /// the dragged element (computed by [_targetListIndex]).
  void _reorderEditorList<T>(List<T> list, int currentIdx, int targetIdx) {
    if (currentIdx < 0) return;

    final element = list.removeAt(currentIdx);
    list.insert(targetIdx.clamp(0, list.length), element);
  }

  void _onOverlayItemTrimmed({
    required TimelineOverlayItem item,
    required Duration startTime,
    required Duration endTime,
    required bool isStart,
  }) {
    final editor = VideoEditorScope.of(context).requireEditor;

    // For sound items, the new source offset computed alongside the timeline
    // move is forwarded to the BLoC so the live waveform scrolls the
    // trimmed-away head out of view during the drag — the full item refresh
    // that would otherwise carry it does not run mid-trim.
    Duration? newStartOffset;

    switch (item.type) {
      case .layer:
        final layers = editor.activeLayers;
        final layerIdx = layers.indexWhere((l) => l.id == item.id);

        editor.setLayerTimeline(
          index: layerIdx,
          startTime: startTime,
          endTime: endTime,
          skipUpdateHistory: true,
        );
      case .filter:
        final filters = editor.stateManager.activeFilters;
        final filterIdx = filters.indexWhere((e) => e.id == item.id);

        editor.setFilterTimeline(
          index: filterIdx,
          startTime: startTime,
          endTime: endTime,
          skipUpdateHistory: true,
        );
      case .tune:
        retimeTuneSet(
          editor,
          setId: item.id,
          startTime: startTime,
          endTime: endTime,
        );
      case .sound:
        final audioTracks = editor.stateManager.audioTracks;
        final audioIdx = audioTracks.indexWhere((e) => e.id == item.id);
        final trimResult = isStart && audioIdx != -1
            ? audioLeftTrimResult(
                audioTracks[audioIdx],
                newStartTime: startTime,
              )
            : null;
        newStartOffset = trimResult?.startOffset;

        editor.setSoundTimeline(
          index: audioIdx,
          startTime: startTime,
          endTime: endTime,
          startOffset: trimResult?.startOffset,
          clearAnchor: trimResult?.anchorStillValid == false,
          skipUpdateHistory: true,
        );

      case .captions:
        editor.setCaptionCueTimeline(
          cueId: item.id,
          startTime: startTime,
          endTime: endTime,
          skipUpdateHistory: true,
        );
    }

    context.read<TimelineOverlayBloc>().add(
      TimelineOverlayItemTrimmed(
        itemId: item.id,
        isStart: isStart,
        startTime: startTime,
        endTime: endTime,
        startOffset: newStartOffset,
      ),
    );
  }

  void _onOverlayTrimDragChanged(bool isTrimming) {
    setState(() => _isTrimming = isTrimming);
    final overlayBloc = context.read<TimelineOverlayBloc>();
    if (isTrimming) {
      // Snapshot history before the trim so undo restores the original
      // position — matches the pattern used by clip trim and overlay drag.
      VideoEditorScope.of(context).requireEditor.addHistory();
      context.read<VideoEditorMainBloc>().add(
        const VideoEditorExternalPauseRequested(isPaused: true),
      );
      final selectedId = overlayBloc.state.selectedItemId;
      if (selectedId != null) {
        overlayBloc.add(TimelineOverlayTrimStarted(selectedId));
      }
    } else {
      overlayBloc.add(const TimelineOverlayTrimEnded());
    }
  }

  void _onOverlayItemTapped(TimelineOverlayItem item) {
    final bloc = context.read<TimelineOverlayBloc>();

    // In draw-layer multi-select mode a tap toggles the layer's membership in
    // the selection instead of single-selecting it. Non-mergeable items are
    // ignored by the bloc handler.
    if (bloc.state.isLayerMultiSelectMode) {
      bloc.add(TimelineOverlayLayerMultiSelectToggled(item.id));
      return;
    }

    // Exit clip editing when an overlay item is tapped.
    final clipBloc = context.read<ClipEditorBloc>();
    if (clipBloc.state.isEditing) {
      clipBloc.add(const ClipEditorEditingToggled());
    }

    if (bloc.state.selectedItemId == item.id) {
      bloc.add(const TimelineOverlayItemSelected(null));
    } else {
      bloc.add(TimelineOverlayItemSelected(item.id));
    }
  }

  void _onOverlayDragStarted(TimelineOverlayItem item) {
    // Snapshot history before the move so undo restores the original position.
    VideoEditorScope.of(context).requireEditor.addHistory();
    context.read<TimelineOverlayBloc>().add(
      TimelineOverlayDragStarted(item.id),
    );
    context.read<VideoEditorMainBloc>().add(
      const VideoEditorExternalPauseRequested(isPaused: true),
    );
  }

  void _onOverlayItemMoving({
    required TimelineOverlayItem item,
    required Duration startTime,
  }) {
    // Mirror the position live during drag so the canvas updates every frame,
    // just like trim does via setLayerTimeline/setFilterTimeline.
    final editor = VideoEditorScope.of(context).requireEditor;

    // Publish the live drag position to the BLoC so the canvas can
    // seek the player preview to the new startTime on every frame
    // (parallel to trimPosition for trim gestures).
    context.read<TimelineOverlayBloc>().add(
      TimelineOverlayDragMoved(startTime),
    );

    switch (item.type) {
      case .layer:
        final layers = editor.activeLayers;
        final layerIdx = layers.indexWhere((l) => l.id == item.id);

        editor.setLayerTimeline(
          index: layerIdx,
          startTime: startTime,
          endTime: startTime + item.duration,
          skipUpdateHistory: true,
        );
      case .filter:
        final filters = editor.stateManager.activeFilters;
        final filterIdx = filters.indexWhere((e) => e.id == item.id);

        editor.setFilterTimeline(
          index: filterIdx,
          startTime: startTime,
          endTime: startTime + item.duration,
          skipUpdateHistory: true,
        );
      case .tune:
        retimeTuneSet(
          editor,
          setId: item.id,
          startTime: startTime,
          endTime: startTime + item.duration,
        );
      case .sound:
        final audioTracks = editor.stateManager.audioTracks;
        final audioIdx = audioTracks.indexWhere((e) => e.id == item.id);

        editor.setSoundTimeline(
          index: audioIdx,
          startTime: startTime,
          endTime: startTime + item.duration,
          skipUpdateHistory: true,
        );

      case .captions:
        editor.setCaptionCueTimeline(
          cueId: item.id,
          startTime: startTime,
          endTime: startTime + item.duration,
          skipUpdateHistory: true,
        );
    }
  }

  void _onOverlayDragEnded() {
    context.read<TimelineOverlayBloc>().add(const TimelineOverlayDragEnded());
  }

  // -- Pointer tracking + manual pinch-to-zoom ------------------------------

  void _stepPosition(Duration current, Duration total, Duration step) {
    final ms = (current + step).inMilliseconds.clamp(0, total.inMilliseconds);
    final position = Duration(milliseconds: ms);
    context.read<VideoEditorMainBloc>().add(VideoEditorSeekRequested(position));
  }

  void _onPointerDown(PointerDownEvent event) {
    _pointerPositions[event.pointer] = event.position;
    if (_pointerPositions.length == 2) {
      _pinchBaseDistance = _currentPointerDistance();
      _pinchBasePps = _pixelsPerSecond;
      setState(() {});
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_pointerPositions.containsKey(event.pointer)) return;
    _pointerPositions[event.pointer] = event.position;
    if (_pointerPositions.length >= 2 && _pinchBaseDistance > 0) {
      _updatePinchZoom();
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    final wasPinching = _isPinching;
    _pointerPositions.remove(event.pointer);
    _pinchBaseDistance = 0;
    if (wasPinching && !_isPinching) setState(() {});
  }

  void _onPointerCancel(PointerCancelEvent event) {
    final wasPinching = _isPinching;
    _pointerPositions.remove(event.pointer);
    _pinchBaseDistance = 0;
    if (wasPinching && !_isPinching) setState(() {});
  }

  double _currentPointerDistance() {
    final positions = _pointerPositions.values.toList();
    return (positions[0] - positions[1]).distance;
  }

  void _updatePinchZoom() {
    final currentDistance = _currentPointerDistance();
    final scale = currentDistance / _pinchBaseDistance;

    // Stop-motion stills need a far higher ceiling than second-long video
    // clips to be workable.
    final maxPps =
        isStopMotionComposition(
          context.read<ClipEditorBloc>().state.clips,
        )
        ? TimelineConstants.stopMotionMaxPixelsPerSecond
        : TimelineConstants.maxPixelsPerSecond;
    final newPps = (_pinchBasePps * scale).clamp(
      TimelineConstants.minPixelsPerSecond,
      maxPps,
    );
    if (newPps == _pixelsPerSecond) return;

    // Anchor the zoom on the current playback position so inter-clip gaps
    // (which stay 1 px regardless of pixelsPerSecond) don't drift the
    // viewport off the playhead. Multiplying the raw scroll offset by the
    // zoom ratio would over-shoot by `clipsPassed × clipGap × (ratio - 1)`
    // px once the playhead is past clip 0.
    final clips = context.read<ClipEditorBloc>().state.clips;
    final anchorPosition = _scrollController.hasClients
        ? timelineScrollOffsetToPosition(
            clips,
            _scrollController.offset,
            _pixelsPerSecond,
            _totalDuration,
            wrap: _wrapDisplay,
          )
        : Duration.zero;

    setState(() => _pixelsPerSecond = newPps);

    if (_scrollController.hasClients) {
      final newOffset = timelinePositionToScrollOffset(
        clips,
        anchorPosition,
        newPps,
        wrap: _wrapDisplay,
      );
      _scrollController.jumpTo(
        newOffset.clamp(0, _scrollController.position.maxScrollExtent),
      );
    }
  }

  // -- Scroll ↔ position sync ------------------------------------------------

  /// Derives the time at the playhead from scroll offset.
  void _updatePlayheadTime() {
    if (!_scrollController.hasClients) return;
    final position = _scrollOffsetToPosition(_scrollController.offset);
    _playheadPosition.value = position;

    // While scrubbing (video paused) the scroll offset is the source of truth
    // for the play time, so drive the scope notifier straight from it —
    // unthrottled — and canvas overlays like the CC caption pill follow the
    // scrub live instead of waiting on the throttled seek round-trip (which a
    // paused/seeking player can stall). During playback the canvas playhead
    // ticker owns this notifier, so leave it untouched.
    if (!context.read<VideoEditorMainBloc>().state.isPlaying) {
      _scopePlayTimeNotifier?.value = position;
    }
  }

  /// Converts a composite playback [position] to the corresponding scroll
  /// offset in the timeline content, accounting for the 1-px gap that
  /// [VideoEditorTimelineClipStrip] inserts between adjacent clips.
  ///
  /// Without this correction, the scroll target is up to
  /// `(clipIndex × clipGap)` pixels short of the trim-handle marker's
  /// actual visual position — noticeable at high zoom levels.
  double _positionToScrollOffset(Duration position) =>
      timelinePositionToScrollOffset(
        context.read<ClipEditorBloc>().state.clips,
        position,
        _pixelsPerSecond,
        wrap: _wrapDisplay,
      );

  /// Inverse of [_positionToScrollOffset]: maps a [scrollOffset] back to a
  /// composite playback position, clamped to the current total duration.
  Duration _scrollOffsetToPosition(double scrollOffset) =>
      timelineScrollOffsetToPosition(
        context.read<ClipEditorBloc>().state.clips,
        scrollOffset,
        _pixelsPerSecond,
        _totalDuration,
        wrap: _wrapDisplay,
      );

  void _syncScrollToPosition(Duration position, Duration totalDuration) {
    if (!_scrollController.hasClients) return;
    if (totalDuration == Duration.zero) return;

    final target = _positionToScrollOffset(position);
    final maxExtent = _scrollController.position.maxScrollExtent;
    _scrollController.animateTo(
      target.clamp(0, maxExtent),
      duration: const Duration(milliseconds: 200),
      curve: Curves.linear,
    );
  }

  void _syncPositionFromScroll({bool force = false}) {
    if (!_scrollController.hasClients) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (!force && now - _lastSeekMs < _seekThrottleMs) return;
    _lastSeekMs = now;

    final position = _scrollOffsetToPosition(_scrollController.offset);
    context.read<VideoEditorMainBloc>().add(VideoEditorSeekRequested(position));
  }
}
