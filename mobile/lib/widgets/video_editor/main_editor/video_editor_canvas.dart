// ABOUTME: Canvas widget wrapping ProImageEditor for the video editor.
// ABOUTME: Handles layer manipulation callbacks and editor configuration.

import 'dart:async';
import 'dart:math';

import 'package:divine_ui/divine_ui.dart';
import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter/foundation.dart' show kReleaseMode, listEquals;
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/blocs/video_editor/draw_editor/video_editor_draw_bloc.dart';
import 'package:openvine/blocs/video_editor/filter_editor/video_editor_filter_bloc.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/blocs/video_editor/tune_editor/video_editor_tune_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/extensions/tune_adjustment_matrix_extensions.dart';
import 'package:openvine/extensions/video_editor_extensions.dart';
import 'package:openvine/extensions/video_editor_history_extensions.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/stop_motion/stop_motion_frame_ops.dart';
import 'package:openvine/models/timeline_overlay_item.dart';
import 'package:openvine/models/video_editor/caption_layer_mapping.dart';
import 'package:openvine/models/video_editor/clip_history_direction.dart';
import 'package:openvine/models/video_editor/clip_snapshot_sync_op.dart';
import 'package:openvine/models/video_editor/detached_clip_layer.dart';
import 'package:openvine/models/video_editor/transition_geometry.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/screens/video_metadata/video_metadata_screen.dart';
import 'package:openvine/services/haptic_service.dart';
import 'package:openvine/services/video_editor/clip_speed_render_service.dart';
import 'package:openvine/services/video_editor/stop_motion_audio_preview.dart';
import 'package:openvine/services/video_editor/transition_seam_render_service.dart';
import 'package:openvine/utils/await_push_transition.dart';
import 'package:openvine/utils/mounted_post_frame.dart';
import 'package:openvine/utils/path_resolver.dart';
import 'package:openvine/utils/video_editor_playhead.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/video_editor/main_editor/hit_test_expander.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_canvas_fit.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_clip_preview.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_cut_area_overlay.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_feed_preview_overlay.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_setup_loading_indicator.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/video_editor_timeline_geometry.dart';
import 'package:openvine/widgets/video_editor/tune_editor/tune_set_timeline_ops.dart';
import 'package:openvine/widgets/video_editor/video_editor_widget_layer_loader.dart';
import 'package:pro_image_editor/pro_image_editor.dart'
    hide AudioTrack, VideoClip;
import 'package:pro_video_editor/pro_video_editor.dart' show ClipTransition;
import 'package:sound_service/sound_service.dart' show AudioSourceConfig;
import 'package:unified_logger/unified_logger.dart';

/// The main canvas area for the video editor.
///
/// Wraps [ProImageEditor] and configures it for video editing with custom
/// styling and callbacks that dispatch events to [VideoEditorMainBloc].
class VideoEditorCanvas extends StatelessWidget {
  /// Creates a [VideoEditorCanvas].
  const VideoEditorCanvas({super.key});

  /// Pushes the post-`setClips` start position back into the
  /// [VideoEditorMainBloc] and the [ProVideoController] after a trim
  /// release.
  ///
  /// Skips the bloc dispatch when [trimEndAlreadyDispatched] is `true`
  /// — the same value was already pushed pre-await — but always
  /// updates the controller's play time so the on-screen scrubber
  /// matches the native player's seek target.
  @visibleForTesting
  static void syncPositionAfterTrimRelease({
    required VideoEditorMainBloc mainBloc,
    required ProVideoController proVideoController,
    required Duration startPosition,
    required bool trimEndAlreadyDispatched,
  }) {
    if (!trimEndAlreadyDispatched) {
      mainBloc.add(VideoEditorPositionChanged(startPosition));
    }
    proVideoController.setPlayTime(startPosition);
  }

  @visibleForTesting
  static bool shouldSyncPlayerForClipStateChange({
    required ClipEditorState previous,
    required ClipEditorState current,
  }) {
    if (previous.isTrimDragging && !current.isTrimDragging) return true;

    if (previous.isSplitting && current.isSplitting) return false;
    if (previous.isSplitting && !current.isSplitting) return true;

    // A background thumbnail refresh (e.g. after a split) changes only the
    // clip's poster path, which the player composition doesn't use — skip the
    // redundant reload.
    if (_onlyThumbnailPathsChanged(previous.clips, current.clips)) return false;

    return !current.isTrimDragging &&
        !previous.isTrimDragging &&
        previous.clips != current.clips;
  }

  /// Whether this editor session needs the Android legacy texture surface.
  ///
  /// The choice is sticky once enabled: changing surface implementations more
  /// than once in a session would repeatedly tear down playback. Imported
  /// drafts start in legacy mode only when their history already owns a
  /// detached clip; ordinary sessions upgrade once, on the first detach.
  @visibleForTesting
  static bool shouldUseLegacySurface({
    required bool alreadyEnabled,
    required Map<String, dynamic> editorStateHistory,
    ClipDetachResult? detachResult,
  }) =>
      alreadyEnabled ||
      detachResult is ClipDetachSuccess ||
      DetachedClipLayerData.historyContainsDetachedClip(editorStateHistory);

  /// Whether [current] differs from [previous] *only* in clip thumbnail paths.
  ///
  /// Conservative: any difference in a composition-relevant field (video,
  /// trims, duration, volume, speed, transition, …) returns `false`, so the
  /// player still reloads for real edits.
  static bool _onlyThumbnailPathsChanged(
    List<DivineVideoClip> previous,
    List<DivineVideoClip> current,
  ) {
    if (identical(previous, current) || previous.length != current.length) {
      return false;
    }
    var anyThumbnailDiff = false;
    for (var i = 0; i < previous.length; i++) {
      final a = previous[i];
      final b = current[i];
      if (a.id != b.id ||
          a.video != b.video ||
          a.trimStart != b.trimStart ||
          a.trimEnd != b.trimEnd ||
          a.duration != b.duration ||
          a.minTrimStart != b.minTrimStart ||
          a.volume != b.volume ||
          a.playbackSpeed != b.playbackSpeed ||
          a.reversed != b.reversed ||
          a.sourceStartOffset != b.sourceStartOffset ||
          a.transition != b.transition) {
        return false;
      }
      if (a.thumbnailPath != b.thumbnailPath) anyThumbnailDiff = true;
    }
    return anyThumbnailDiff;
  }

  @visibleForTesting
  static bool shouldSeedSelectedSoundAsAudioTrack({
    required bool hasSelectedSound,
    required bool seedSelectedSoundAsAudioTrack,
  }) => hasSelectedSound && seedSelectedSoundAsAudioTrack;

  /// Tolerance within which a player position report is treated as having
  /// converged on a pending scrub / swap target. Comfortably wider than a
  /// single frame so frame-snapped reports from an exact seek are accepted, yet
  /// far narrower than the multi-second gap back to position 0 whose reset
  /// report must be rejected.
  @visibleForTesting
  static const seekSettleTolerance = Duration(milliseconds: 120);

  /// Whether a player position [report] (in editor-timeline space) may drive
  /// the play time, given a possibly-pending [seekTarget] that a scrub or a
  /// composition swap pinned the play time to.
  ///
  /// When a transition seam finishes rendering the composition is swapped to
  /// splice in the freshly rendered seam file; while the native player loads
  /// that file it briefly reports position 0, which — if accepted — snaps the
  /// timeline playhead back to the start. Rapid back-and-forth scrubbing emits
  /// the same kind of stale, superseded report. While a target is pending and
  /// playback is paused, only a report that has converged to within
  /// [seekSettleTolerance] of the target is accepted; anything else is a stale
  /// / reset report and is dropped. Playback always accepts reports — once
  /// playing, the play time follows playback, not the pinned target.
  @visibleForTesting
  static bool shouldAcceptPlayerReport({
    required Duration report,
    required Duration? seekTarget,
    required bool isPlaying,
  }) {
    if (isPlaying || seekTarget == null) return true;
    final delta = report - seekTarget;
    return (delta.isNegative ? -delta : delta) <= seekSettleTolerance;
  }

  static const _compositionErrorCode = 'COMPOSITION_ERROR';
  static const _notReadyErrorCode = 'NOT_READY';
  static const _playerErrorCode = 'PLAYER_ERROR';

  /// Runs a `setClips` [load], swallowing the native unbuildable-composition
  /// rejection.
  ///
  /// iOS rejects an unbuildable composition — zero render size, no playable
  /// video track, or a missing / partially-rendered draft clip file — with a
  /// `COMPOSITION_ERROR` `PlatformException`. That is an expected domain
  /// failure for stale draft clips on reopen, not a crash. Returns `true` when
  /// the composition built and `false` when the native player rejected it with
  /// that exact error, so callers can stay on the thumbnail fallback instead of
  /// letting the rejection escape as an unhandled async error and surface as a
  /// Crashlytics non-fatal (#3410).
  ///
  /// `NOT_READY` and `PLAYER_ERROR` are also swallowed so trim-triggered reload
  /// failures can mark the player unavailable instead of leaving a broken
  /// native player reported as ready.
  ///
  /// `PLAYER_ERROR` is left log-only here because this helper lives in the UI
  /// layer; reportability decisions belong to BLoC/Cubit or service code.
  @visibleForTesting
  static Future<bool> guardClipLoad(Future<void> Function() load) async {
    try {
      await load();
      return true;
    } on PlatformException catch (e, s) {
      if (e.code != _compositionErrorCode &&
          e.code != _notReadyErrorCode &&
          e.code != _playerErrorCode) {
        rethrow;
      }
      Log.error(
        'setClips failed with ${e.code}: $e',
        name: 'VideoEditorCanvas',
        category: LogCategory.video,
        error: e,
        stackTrace: s,
      );
      return false;
    }
  }

  @visibleForTesting
  static bool shouldPublishClipLoad({
    required int generation,
    required int currentGeneration,
  }) => generation == currentGeneration;

  /// Decides how to reconcile the clip [snapshot] read from the editor's
  /// current undo/redo history entry with the app clip state.
  ///
  /// An undo/redo can land on a state whose clips were all removed earlier in
  /// the session — [FileCleanupService] has since deleted their source files,
  /// so handing them to the native player fails the whole composition
  /// (`COMPOSITION_ERROR`) and freezes the editor. Such an *orphan-only* entry
  /// must neither sync into the app (the player would diverge from the
  /// timeline) nor be left as the resting state (app clip state and editor
  /// history would silently diverge). Instead the editor steps its own history
  /// past it: [direction] biases which way to step, falling back to the
  /// opposite direction once at a history boundary; [didReverse] records that a
  /// reversal already happened so an all-orphan history can't ping-pong
  /// forever.
  ///
  /// Returns the [ClipSnapshotSyncOp] to perform, the resolvable clips to
  /// mirror (only meaningful for [ClipSnapshotSyncOp.sync]), and whether the
  /// chosen step reverses the requested [direction].
  @visibleForTesting
  static ({
    ClipSnapshotSyncOp op,
    List<DivineVideoClip> resolvableClips,
    bool reversed,
  })
  resolveClipSnapshotSync({
    required List<DivineVideoClip> snapshot,
    required ClipHistoryDirection direction,
    required bool canUndo,
    required bool canRedo,
    required bool didReverse,
  }) {
    final resolvable = snapshot
        .where((clip) => clip.hasResolvableVideoFile)
        .toList();
    if (resolvable.isNotEmpty) {
      return (
        op: ClipSnapshotSyncOp.sync,
        resolvableClips: resolvable,
        reversed: false,
      );
    }
    if (snapshot.isEmpty) {
      return (
        op: ClipSnapshotSyncOp.skip,
        resolvableClips: resolvable,
        reversed: false,
      );
    }

    // Orphan-only entry: prefer the navigated direction, fall back to the
    // opposite direction once (at a history boundary), then give up so an
    // all-orphan history can't loop forever.
    final preferBackward = direction != ClipHistoryDirection.redo;
    if (preferBackward && canUndo) {
      return (
        op: ClipSnapshotSyncOp.stepBackward,
        resolvableClips: resolvable,
        reversed: false,
      );
    }
    if (!preferBackward && canRedo) {
      return (
        op: ClipSnapshotSyncOp.stepForward,
        resolvableClips: resolvable,
        reversed: false,
      );
    }
    if (!didReverse) {
      if (preferBackward && canRedo) {
        return (
          op: ClipSnapshotSyncOp.stepForward,
          resolvableClips: resolvable,
          reversed: true,
        );
      }
      if (!preferBackward && canUndo) {
        return (
          op: ClipSnapshotSyncOp.stepBackward,
          resolvableClips: resolvable,
          reversed: true,
        );
      }
    }
    return (
      op: ClipSnapshotSyncOp.skip,
      resolvableClips: resolvable,
      reversed: false,
    );
  }

  /// Compares two clip lists by their editable properties, deciding whether a
  /// history snapshot needs mirroring back into the app clip state.
  @visibleForTesting
  static bool clipsChanged(
    List<DivineVideoClip> current,
    List<DivineVideoClip> next,
  ) {
    if (current.length != next.length) return true;
    for (var i = 0; i < current.length; i++) {
      final a = current[i];
      final b = next[i];
      if (a.id != b.id ||
          a.video != b.video ||
          a.trimStart != b.trimStart ||
          a.trimEnd != b.trimEnd ||
          a.volume != b.volume ||
          a.playbackSpeed != b.playbackSpeed ||
          a.transition != b.transition ||
          // Frame edits (hold changes, delete, reorder) are the whole edit
          // surface of a stop-motion clip — without this the clip manager
          // (publish render, autosave, metadata preview) and undo/redo never
          // see them.
          !listEquals(a.stopMotionFrames, b.stopMotionFrames)) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final isSubEditorOpen = context.select(
      (VideoEditorMainBloc b) => b.state.isSubEditorOpen,
    );

    return PopScope(
      canPop: !isSubEditorOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          final scope = VideoEditorScope.of(context);
          scope.editor?.closeSubEditor();
          final bloc = context.read<VideoEditorMainBloc>();
          bloc.add(const VideoEditorMainSubEditorClosed());
        }
      },
      // Const child: Flutter detects identical() widget and skips the
      // rebuild cascade (_CanvasFitter → LayoutBuilder → _VideoEditorState)
      // when only isSubEditorOpen changes.
      child: const _CanvasBody(),
    );
  }
}

class _CanvasBody extends StatelessWidget {
  const _CanvasBody();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: .only(top: MediaQuery.viewPaddingOf(context).top),
      child: _CanvasFitter(
        builder: (bodySize, renderSize) =>
            _VideoEditor(renderSize: renderSize, bodySize: bodySize),
      ),
    );
  }
}

class _VideoEditor extends ConsumerStatefulWidget {
  const _VideoEditor({required this.renderSize, required this.bodySize});

  final Size renderSize;
  final Size bodySize;

  @override
  ConsumerState<_VideoEditor> createState() => _VideoEditorState();
}

class _VideoEditorState extends ConsumerState<_VideoEditor>
    with TickerProviderStateMixin {
  late final ProVideoController _proVideoController;

  /// The scope's fine-grained play-time notifier, cached from
  /// [didChangeDependencies]. Published alongside every [_setLayerPlayTime] so
  /// canvas overlays (the CC pill) track playback at the layer cadence.
  ValueNotifier<Duration>? _playTimeNotifier;
  ValueNotifier<bool>? _playheadAdvancingNotifier;

  final _isPlayerReadyNotifier = ValueNotifier<bool>(false);

  /// Claimed by [_beginClipLoad] so a superseded `setClips` cannot publish its
  /// stale readiness in [_endClipLoad].
  int _clipLoadGeneration = 0;
  DivineVideoPlayerController? _videoPlayer;
  StreamSubscription<DivineVideoPlayerState>? _videoPlayerSubscription;

  /// Completed by [_handleDone] once the preview decoder has been released, so
  /// [_handleEditorComplete] can hold the export encoder back until then — the
  /// two must never contend for the device's scarce hardware codecs (see
  /// #5522). pro_image_editor invokes `onDone` before `onCompleteWithParameters`,
  /// so this is always created (in [_handleDone]) before it is awaited.
  Completer<void>? _decoderReleaseGate;
  bool _isMetadataRouteActive = false;

  bool _isInitialized = false;
  bool _isImportingHistory = false;
  late bool _useLegacySurface;

  bool get _isLayerBeingTransformed => _selectedLayer != null;

  Layer? _selectedLayer;

  /// Tracks whether pointer was over remove area in the previous frame.
  /// Used to deduplicate haptic feedback so it only fires once on entry.
  bool _wasOverRemoveArea = false;

  /// Tracks last playback state to detect changes.
  bool _lastIsPlaying = false;

  /// Drives the layer-overlay play time at display refresh rate during
  /// playback. The native player reports position only ~5×/s
  /// (`addPeriodicTimeObserver`, 0.2 s), and the overlay's enter/leave
  /// animations are driven solely by [ProVideoController.setPlayTime] — so at
  /// the raw report rate they visibly step. This ticker interpolates the play
  /// time between reports; each report re-anchors it (and corrects drift) in
  /// [_onPlayerStateChanged]. It runs only while playing and never while a
  /// seek / trim / drag owns the play time.
  Ticker? _playheadTicker;

  /// Composite (player-space) position captured at the last anchor.
  Duration _playheadAnchorPlayer = Duration.zero;

  /// Player playback-speed multiplier captured at the last anchor.
  double _playheadAnchorSpeed = 1;

  /// Wall-clock elapsed since the last anchor, used to interpolate forward.
  final _playheadStopwatch = Stopwatch();

  /// Composite (player-space) duration, kept fresh to clamp interpolation.
  Duration _lastPlayerDuration = Duration.zero;

  /// Drives playback of a frames-only stop-motion clip, which has no native
  /// player (`_videoPlayer` stays null). Advances the bloc's currentPosition —
  /// and, through it, the timeline playhead — while playing, so the same
  /// play/pause + scrub controls that drive video also drive stop-motion.
  Ticker? _stopMotionTicker;

  /// Position the stop-motion clock resumes from; re-anchored on play / seek.
  Duration _stopMotionAnchor = Duration.zero;

  /// Wall-clock elapsed since [_stopMotionAnchor] was captured.
  final _stopMotionStopwatch = Stopwatch();

  /// Last position the stop-motion clock pushed to the bloc, used to throttle
  /// emits to [VideoEditorConstants.stopMotionPlayheadEmitInterval].
  Duration _lastStopMotionEmit = Duration.zero;

  /// Plays timeline sounds against the stop-motion clock. A frames-only
  /// composition has no native video player, so `setAudioTracks` (the normal
  /// audio path) has nothing to attach to — this engine follows
  /// [_stopMotionTicker] instead. Created lazily by [_syncStopMotionAudio].
  StopMotionAudioPreview? _stopMotionAudio;

  /// Last position dispatched to BLoC — avoids flooding with duplicates.
  Duration _lastReportedPosition = Duration.zero;

  /// Last duration dispatched to BLoC — avoids flooding with duplicates.
  Duration _lastReportedDuration = Duration.zero;

  /// Whether a native seekTo is currently in flight.
  bool _isSeeking = false;

  /// The most recent seek position received while a seek was in progress.
  /// Processed as a trailing seek once the current seek completes.
  Duration? _pendingSeekPosition;

  /// Monotonically increasing seek generation. Bumped on every composition
  /// swap so in-flight seeks from the previous composition are discarded.
  int _seekEpoch = 0;

  /// Editor-timeline position the play time is currently pinned to by a scrub
  /// seek or a composition swap. While set (and playback is paused) any player
  /// position report that deviates from it is dropped — the short-lived
  /// position 0 the native player emits while loading a freshly rendered
  /// transition seam file in [_swapComposition] (which can arrive hundreds of
  /// ms after the swap completes), and out-of-order reports from a superseded
  /// scrub seek. Without it such a report drives the play time and snaps the
  /// timeline playhead back to position 0 (or a previously scrubbed spot).
  ///
  /// The pin is intentionally *not* released on the first converged report —
  /// that report arrives well before the delayed reset report, so clearing
  /// early would let the reset report through. It is released only when
  /// playback resumes (it then owns the play time) or when a new scrub / swap
  /// re-pins it (see [VideoEditorCanvas.shouldAcceptPlayerReport]).
  Duration? _pendingSeekTarget;

  /// Cached documents directory path — resolved once in [initState].
  late final Future<String> _documentsPath;

  bool _isTrimmingLayer = false;
  bool _isTrimmingClip = false;
  bool _isDraggingLayer = false;

  /// One-shot guard set by the reverse-success [BlocListener] before it
  /// imperatively rebuilds the player with the reversed clip list. The next
  /// [ClipEditorState] clip-snapshot diff would otherwise re-trigger the
  /// generic clip-sync path and overwrite the just-applied reversed source.
  /// Consumed (cleared) by the clip-snapshot listener on its next pass.
  bool _skipNextClipSnapshotSync = false;

  /// Set while stepping the editor history past an orphan-only undo/redo state
  /// (see [VideoEditorCanvas.resolveClipSnapshotSync]). Permits reversing the
  /// step direction exactly once at a history boundary so the search can't
  /// ping-pong forever when every neighbour is also orphaned. Cleared once a
  /// state with resolvable media (or a genuinely clip-less entry) is reached.
  bool _orphanStepDidReverse = false;

  /// Guards against duplicate [addHistory] calls when both
  /// [ClipEditorBloc.clipsVolumeRevision] and
  /// [TimelineOverlayBloc.audioTracksRevision] change in the same frame
  /// (e.g. mute-all toggle). When both revision counters fire, only one
  /// combined undo point is written instead of two separate ones.
  bool _isVolumeSavePending = false;

  /// Most recent live-preview seek target captured while a layer trim
  /// handle is being dragged. Used at gesture end to sync the
  /// VideoEditorMainBloc's currentPosition (and thus the UI timeline
  /// scrubber) to the release point in a single dispatch — doing it
  /// inside the seek loop would let the scrubber jump mid-drag.
  Duration? _lastLayerTrimPosition;

  /// Same as [_lastLayerTrimPosition] but for layer item drag
  /// (move-along-timeline) gestures. Captures the dragged item's
  /// startTime during the drag and is dispatched once on release.
  Duration? _lastLayerDragPosition;

  /// Most recent in-progress clip trim. Captured while the gesture is
  /// active so that, once it ends and the multi-clip composite is
  /// restored, we can seek to the composite-timeline position that
  /// matches where the user released the trim handle.
  String? _lastTrimClipId;
  Duration? _lastTrimPositionInClip;

  bool get _isPlayerInitialized => _videoPlayer?.isInitialized == true;

  @override
  void initState() {
    super.initState();
    Log.info(
      '🎬 Canvas initialized',
      name: 'VideoEditorCanvas',
      category: LogCategory.video,
    );
    _initializeController();
    _documentsPath = getDocumentsPath();
    _useLegacySurface = VideoEditorCanvas.shouldUseLegacySurface(
      alreadyEnabled: false,
      editorStateHistory: ref.read(videoEditorProvider).editorStateHistory,
    );

    // Initialize the player with the current clips.
    if (_clipPaths.isNotEmpty) {
      _initializePlayer(_clipPaths);
    }

    // A stop-motion composition never runs _initializePlayer (no mp4), so its
    // audio engine needs its own initial sync for sounds restored from a
    // draft. Post-frame: _isStopMotionComposition reads providers/blocs.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_isStopMotionComposition) return;
      unawaited(_syncAudioTracks());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = VideoEditorScope.of(context);
    _playTimeNotifier = scope.playTimeNotifier;
    _playheadAdvancingNotifier = scope.playheadAdvancingNotifier;
  }

  /// Renders and caches transition seams so the preview can splice them in
  /// between the trimmed neighbour clips (instead of compositing live).
  final _seamService = TransitionSeamRenderService();

  /// Number of transition seams currently rendering. Drives the preview's
  /// "rendering transition" overlay so the wait isn't silent.
  final _pendingSeamRenders = ValueNotifier<int>(0);

  /// Renders and caches per-clip normal-rate speed bodies so a non-1× clip can
  /// play its pre-rendered file at 1× instead of retiming live — smoother on
  /// both platforms. Rendered in the background; the preview shows the instant
  /// live-retimed clip until the render swaps in (no overlay, no wait).
  final _speedRenderService = ClipSpeedRenderService();

  /// Set when a finished speed render's composition swap was deferred because
  /// the player was playing; applied on the next pause (see
  /// [_onPlayerStateChanged]). A `setClips` reload mid-playback is inherently
  /// disruptive (Android setMediaItems + prepare, iOS AVQueuePlayer reload) and
  /// restarts the current clip instead of advancing, so the swap must wait for
  /// an idle player.
  bool _speedResyncPendingWhilePlaying = false;

  @override
  void dispose() {
    Log.info(
      '🎬 Canvas disposed',
      name: 'VideoEditorCanvas',
      category: LogCategory.video,
    );
    _playheadTicker?.dispose();
    _stopMotionTicker?.dispose();
    _stopMotionAudio?.dispose();
    _stopMotionAudio = null;
    _videoPlayerSubscription?.cancel();
    _videoPlayer?.dispose();
    // Null it so a release/init still awaiting bails instead of double-disposing
    // or writing to the disposed notifier below.
    _videoPlayer = null;
    _isPlayerReadyNotifier.dispose();
    _seamService.clear();
    _speedRenderService.clear();
    _pendingSeamRenders.dispose();
    super.dispose();
  }

  /// Renders any not-yet-cached transition seam and re-syncs the player when it
  /// finishes, so the seam splices into the preview. Idempotent — cached seams
  /// are skipped, so it is safe to call on every clip change.
  ///
  /// Renders the no-overlap-clamped transition ([clampTransitions]) so the
  /// preview consumes exactly what the export will, and a clip touched by
  /// transitions on both sides is split between them rather than over-consumed.
  void _ensureSeamsRendered(List<DivineVideoClip> clips) {
    final clamped = clampTransitions(clips);
    for (var i = 0; i < clips.length - 1; i++) {
      final transition = clamped[clips[i].id];
      if (transition == null) continue;
      _renderSeam(clips[i], clips[i + 1], transition);
    }

    // Loop-restart wrap: the last clip's transition blends its tail into the
    // first clip's head (the same clip on a single-clip timeline) so the looping
    // preview restarts through the blend instead of a hard cut.
    if (clips.isNotEmpty) {
      final wrap = clamped[clips.last.id];
      if (wrap != null) _renderSeam(clips.last, clips.first, wrap);
    }
  }

  /// Renders (once) the transition seam blending [clipA]'s tail into [clipB]'s
  /// head, resyncing the preview when it lands. Idempotent — cached / in-flight
  /// seams are skipped so the pending counter isn't double-incremented.
  void _renderSeam(
    DivineVideoClip clipA,
    DivineVideoClip clipB,
    ClipTransition transition,
  ) {
    if (_seamService.cached(clipA, clipB, transition) != null) return;
    if (_seamService.isRendering(clipA, clipB, transition)) return;
    _pendingSeamRenders.value++;
    _seamService
        .render(clipA: clipA, clipB: clipB, transition: transition)
        .then((seam) {
          if (!mounted) return;
          _pendingSeamRenders.value--;
          if (seam != null) _resyncPlayerClips();
        });
  }

  /// Kicks off background renders of the normal-rate body for any non-1× clip,
  /// then swaps the player onto the rendered file when each finishes. Idempotent
  /// — cached / in-flight clips are skipped — so it is safe to call on every
  /// clip, trim or speed change. The preview keeps playing the instant
  /// live-retimed clip until the swap lands.
  void _ensureSpeedClipsRendered(List<DivineVideoClip> clips) {
    final clamped = clampTransitions(clips);
    // The loop-restart wrap consumes the first clip's head and the last clip's
    // tail eagerly (see buildSeamAwarePlayerClips); those clips stay on live
    // retiming like interior seam-consumed clips.
    final wrapActive =
        clips.isNotEmpty &&
        LoopWrapDisplay.fromClamped(clips, clamped[clips.last.id]).isActive;
    for (var i = 0; i < clips.length; i++) {
      final clip = clips[i];
      // Skip a clip whose body is consumed by a rendered seam on either side:
      // it stays on live retiming (the seam already bakes its speed), so its
      // whole-body speed render would never be spliced in — matching the gate
      // in [buildSeamAwarePlayerClips]. Avoids a native encode the player can't
      // use. Until the seam lands the clip isn't consumed, so it still renders.
      final incoming = i > 0 ? clamped[clips[i - 1].id] : null;
      final consumedByIncoming =
          incoming != null &&
          _seamService.cached(clips[i - 1], clip, incoming) != null;
      final outgoing = clamped[clip.id];
      final consumedByOutgoing =
          i + 1 < clips.length &&
          outgoing != null &&
          _seamService.cached(clip, clips[i + 1], outgoing) != null;
      final consumedByWrap = wrapActive && (i == 0 || i == clips.length - 1);
      if (consumedByIncoming || consumedByOutgoing || consumedByWrap) continue;

      if (_speedRenderService.cached(clip) != null) continue;
      if (_speedRenderService.isRendering(clip)) continue;
      _speedRenderService.render(clip).then((rendered) {
        if (!mounted) return;
        if (rendered != null) _resyncSpeedClipsWhenIdle();
      });
    }
  }

  /// Swaps the composition onto a finished speed render — but only while the
  /// player is idle. A `setClips` reload mid-playback restarts the current clip
  /// instead of advancing to the next, so if playback is running the swap is
  /// deferred to the next pause ([_onPlayerStateChanged]); the preview keeps
  /// playing the live-retimed clip until then.
  void _resyncSpeedClipsWhenIdle() {
    if (_videoPlayer?.state.isPlaying ?? false) {
      _speedResyncPendingWhilePlaying = true;
      return;
    }
    _resyncPlayerClips();
  }

  /// Reloads the player with the current clips, splicing in rendered seams,
  /// preserving the current playback position.
  void _resyncPlayerClips() {
    if (!_isPlayerInitialized) return;
    final clips = ref.read(clipManagerProvider).clips;
    if (clips.isEmpty) return;
    final currentPosition = context
        .read<VideoEditorMainBloc>()
        .state
        .currentPosition;
    unawaited(_swapComposition(clips, timelineStartPosition: currentPosition));
  }

  /// Reloads the player composition while suppressing the stale position
  /// reports the outgoing composition emits mid-swap. Without this guard those
  /// reports — positions in the *old* composite — get mapped through the *new*
  /// seam timeline and yank the playhead to a wrong spot (e.g. 3s jumps to 5s
  /// right after a transition seam finishes rendering).
  ///
  /// Mirrors the reverse / trim-release swap guard: bumps [_seekEpoch] to
  /// discard in-flight seeks from the previous composition, holds [_isSeeking]
  /// across the reload so [_onPlayerStateChanged] skips emission, then pins
  /// [_lastReportedPosition] to the restored position before releasing
  /// ownership (only if no newer swap took over).
  ///
  /// [_isSeeking] only covers reports emitted *during* the reload. Loading the
  /// freshly rendered seam file makes the native player emit a reset report
  /// (position 0) hundreds of ms *after* the reload completes; pinning
  /// [_pendingSeekTarget] keeps that delayed report from snapping the playhead
  /// back to the start while playback stays paused.
  Future<void> _swapComposition(
    List<DivineVideoClip> clips, {
    required Duration timelineStartPosition,
  }) async {
    _seekEpoch++;
    _pendingSeekPosition = null;
    _isSeeking = true;
    final ownerEpoch = _seekEpoch;
    try {
      final loaded = await _setClipsSafely(_videoPlayer, [
        ..._buildPlayerClips(clips),
      ], startPosition: _timelineToPlayer(timelineStartPosition));
      if (!loaded) return;
      // Only pin the restored position if no newer swap took over during the
      // await — matching the epoch-guarded [_isSeeking] release below. Without
      // this a stale swap would write its old composite position over the one a
      // newer swap (e.g. a trim-start) already set.
      if (mounted && _seekEpoch == ownerEpoch) {
        _lastReportedPosition = timelineStartPosition;
        _pendingSeekTarget = timelineStartPosition;
        _setLayerPlayTime(timelineStartPosition);
      }
    } finally {
      if (_seekEpoch == ownerEpoch) _isSeeking = false;
    }
  }

  /// Memoized [SeamTimeline] for the current clips + seam-cache state, so the
  /// per-tick position mappings don't rebuild it on every player update.
  SeamTimeline? _cachedSeamTimeline;
  int? _cachedSeamTimelineClipsHash;
  int? _cachedSeamTimelineVersion;

  /// Returns the current [SeamTimeline], rebuilding when the clips change
  /// identity or the seam cache mutates ([TransitionSeamRenderService.version]).
  ///
  /// Deliberately **not** keyed on the speed render cache: a landed speed body
  /// must only shift the mapping once its file is actually spliced into the
  /// player composition. Because a speed swap can be deferred while playback
  /// runs (see [_resyncSpeedClipsWhenIdle]), keying on the speed cache would
  /// move the mapping ahead of the still-live-retimed player and drift the
  /// playhead. Instead [_buildPlayerClips] refreshes this timeline from the
  /// same snapshot it hands the player, so mapping and composition always
  /// agree.
  SeamTimeline get _seamTimeline {
    final clips = ref.read(clipManagerProvider).clips;
    final clipsHash = Object.hashAll(clips);
    final version = _seamService.version;
    final cached = _cachedSeamTimeline;
    if (cached != null &&
        _cachedSeamTimelineClipsHash == clipsHash &&
        _cachedSeamTimelineVersion == version) {
      return cached;
    }
    return _refreshSeamTimeline(clips);
  }

  /// Builds the preview player's clip list for [clips] (rendered seams + speed
  /// bodies spliced in) and refreshes the memoized [SeamTimeline] from the same
  /// cache snapshot, so the player↔editor position mapping always matches the
  /// composition that was actually loaded — including a speed body that landed
  /// while playing whose swap was deferred to the next pause.
  List<VideoClip> _buildPlayerClips(List<DivineVideoClip> clips) {
    final playerClips = buildSeamAwarePlayerClips(
      clips,
      _seamService,
      speedRenders: _speedRenderService,
    );
    _refreshSeamTimeline(clips);
    return playerClips;
  }

  SeamTimeline _refreshSeamTimeline(List<DivineVideoClip> clips) {
    final timeline = SeamTimeline(
      clips,
      _seamService,
      speedRenders: _speedRenderService,
    );
    _cachedSeamTimeline = timeline;
    _cachedSeamTimelineClipsHash = Object.hashAll(clips);
    _cachedSeamTimelineVersion = _seamService.version;
    return timeline;
  }

  /// Converts a player (composite) position into editor-timeline space. The
  /// player plays trimmed clip bodies with spliced seams (a shorter timeline);
  /// the editor draws clips at full length. A no-op when no seam is spliced.
  Duration _playerToTimeline(Duration playerPosition) =>
      _seamTimeline.compositeToTimeline(playerPosition);

  /// Converts an editor-timeline position into player (composite) space.
  Duration _timelineToPlayer(Duration timelinePosition) =>
      _seamTimeline.timelineToComposite(timelinePosition);

  /// Extracts playable file paths from the current clip state.
  List<String> get _clipPaths => ref
      .read(clipManagerProvider)
      .clips
      .map((c) => c.video?.file?.path)
      .whereType<String>()
      .toList();

  void _setPlayerReady(bool isReady) {
    if (!mounted) return;
    _isPlayerReadyNotifier.value = isReady;
    context.read<VideoEditorMainBloc>().add(
      VideoEditorPlayerReady(isReady: isReady),
    );
  }

  /// Marks the player unusable and claims the clip-load generation this reload
  /// owns.
  ///
  /// The native side answers a superseded `setClips` with `CANCELLED`, which
  /// [DivineVideoPlayerController.setClips] resolves as success — so without a
  /// generation the *older* load reports ready while the newer one is still
  /// buffering, re-opening the exact window this gating closes.
  int _beginClipLoad() {
    _setPlayerReady(false);
    return ++_clipLoadGeneration;
  }

  /// Publishes the outcome of the clip load that claimed [generation], unless a
  /// newer load has superseded it.
  void _endClipLoad(int generation, {required bool isReady}) {
    if (!VideoEditorCanvas.shouldPublishClipLoad(
      generation: generation,
      currentGeneration: _clipLoadGeneration,
    )) {
      return;
    }
    _setPlayerReady(isReady);
  }

  bool _canUseVideoPlayerForUserAction(String action) {
    if (!_isPlayerReadyNotifier.value) {
      Log.debug(
        'Ignoring $action: player is not ready',
        name: 'VideoEditorCanvas',
        category: LogCategory.video,
      );
      return false;
    }
    if (!_isPlayerInitialized) {
      Log.debug(
        'Ignoring $action: player is not initialized',
        name: 'VideoEditorCanvas',
        category: LogCategory.video,
      );
      return false;
    }
    return true;
  }

  /// Handles playback restart requests from BLoC.
  void _onPlaybackRestartRequested() {
    if (_isStopMotionComposition) {
      _playStopMotion(from: Duration.zero);
      return;
    }
    if (!_canUseVideoPlayerForUserAction('playback restart')) return;

    // Stop the interpolator on the user action so it can't advance the play
    // time from the stale anchor before the next native report re-anchors it;
    // the report with isPlaying == true restarts it.
    _setPlayheadTickerActive(false);
    // Restart jumps to the start, so re-pin the play time to zero: a stale
    // pre-restart report is rejected while the player seeks, and a position-0
    // report (the restart target) is accepted. _onPlayerStateChanged releases
    // the pin once playback is actually reported.
    _pendingSeekTarget = Duration.zero;
    _videoPlayer?.seekTo(Duration.zero);
    _videoPlayer?.play();
  }

  /// Handles playback toggle requests from BLoC.
  void _onPlaybackToggleRequested() {
    if (_isStopMotionComposition) {
      _toggleStopMotionPlayback();
      return;
    }
    if (!_canUseVideoPlayerForUserAction('playback toggle')) return;

    final isPlaying = _videoPlayer?.state.isPlaying ?? false;
    if (isPlaying) {
      // Stop the interpolator on pause so it doesn't keep advancing the play
      // time for up to one report interval before the next report stops it.
      _setPlayheadTickerActive(false);
      _videoPlayer?.pause();
    } else {
      // Keep any scrub / swap pin until the player actually reports isPlaying
      // (released in _onPlayerStateChanged). Clearing it here, before the first
      // isPlaying report, would reopen the window where a delayed reset report
      // (seekTarget == null) is accepted and snaps the playhead to the start.
      _videoPlayer?.play();
    }
  }

  /// Handles external pause requests from BLoC.
  void _onExternalPauseChanged({required bool isPaused}) {
    if (_isStopMotionComposition) {
      if (isPaused) {
        _pauseStopMotion();
      } else {
        _playStopMotion(
          from: context.read<VideoEditorMainBloc>().state.currentPosition,
        );
      }
      return;
    }
    if (!_canUseVideoPlayerForUserAction('external pause change')) return;

    if (isPaused) {
      // Stop the interpolator on pause so it doesn't keep advancing the play
      // time for up to one report interval before the next report stops it.
      _setPlayheadTickerActive(false);
      _videoPlayer?.pause();
    } else {
      // Keep any scrub / swap pin until the player reports isPlaying; see
      // _onPlaybackToggleRequested for why clearing it here would reopen the
      // delayed-reset-report window.
      _videoPlayer?.play();
    }
  }

  // -- Frames-only stop-motion playhead --------------------------------------

  /// Whether the current composition is a frames-only stop-motion clip. Such a
  /// clip has no mp4, so [_clipPaths] is empty and the native [_videoPlayer] is
  /// never created — playback is driven by [_stopMotionTicker] against the bloc
  /// instead.
  bool get _isStopMotionComposition =>
      isStopMotionComposition(ref.read(clipManagerProvider).clips);

  /// Wall-clock length of the stop-motion loop (sum of clip playback
  /// durations), read from the [ClipEditorBloc] the timeline also scales to.
  Duration get _stopMotionTotalDuration =>
      context.read<ClipEditorBloc>().state.totalDuration;

  void _toggleStopMotionPlayback() {
    if (context.read<VideoEditorMainBloc>().state.isPlaying) {
      _pauseStopMotion();
    } else {
      _playStopMotion(
        from: context.read<VideoEditorMainBloc>().state.currentPosition,
      );
    }
  }

  void _playStopMotion({required Duration from}) {
    final total = _stopMotionTotalDuration;
    if (total <= Duration.zero) return;

    _stopMotionAnchor = from >= total ? Duration.zero : from;
    _lastStopMotionEmit = _stopMotionAnchor;
    _stopMotionStopwatch
      ..reset()
      ..start();
    // Ticker.start() asserts the ticker is idle; re-anchoring while already
    // playing (e.g. external unpause) must not double-start it.
    final ticker = _stopMotionTicker ??= createTicker(_onStopMotionTick);
    if (!ticker.isActive) ticker.start();
    _setPlayheadAdvancing(advancing: true);

    // Timed layers follow the overlay play time, not the bloc position.
    _setLayerPlayTime(_stopMotionAnchor);
    final audio = _stopMotionAudio;
    if (audio != null) {
      // Re-anchoring is a clock set, not a tick: a resume that lands mid-window
      // must re-seek even when it re-anchors only slightly ahead.
      unawaited(
        audio.syncTo(_stopMotionAnchor, isPlaying: true, isSeek: true),
      );
    }

    context.read<VideoEditorMainBloc>()
      ..add(VideoEditorPositionChanged(_stopMotionAnchor))
      ..add(const VideoEditorPlaybackChanged(isPlaying: true));
  }

  void _pauseStopMotion() {
    _stopMotionStopwatch.stop();
    if (_stopMotionTicker?.isActive ?? false) _stopMotionTicker!.stop();
    _setPlayheadAdvancing(advancing: false);
    final audio = _stopMotionAudio;
    if (audio != null) unawaited(audio.pauseAll());
    if (!context.read<VideoEditorMainBloc>().state.isPlaying) return;
    context.read<VideoEditorMainBloc>().add(
      const VideoEditorPlaybackChanged(isPlaying: false),
    );
  }

  /// Jumps the stop-motion playhead to [position] (timeline scrubbing),
  /// re-anchoring the clock so playback continues from there if it was running.
  void _seekStopMotion(Duration position) {
    final total = _stopMotionTotalDuration;
    final clamped = total <= Duration.zero
        ? Duration.zero
        : Duration(
            microseconds: position.inMicroseconds.clamp(
              0,
              total.inMicroseconds,
            ),
          );

    _stopMotionAnchor = clamped;
    _lastStopMotionEmit = clamped;
    if (_stopMotionStopwatch.isRunning) {
      _stopMotionStopwatch
        ..reset()
        ..start();
    }
    _setLayerPlayTime(clamped);
    final audio = _stopMotionAudio;
    if (audio != null) {
      unawaited(
        audio.syncTo(
          clamped,
          isPlaying: _stopMotionStopwatch.isRunning,
          isSeek: true,
        ),
      );
    }
    context.read<VideoEditorMainBloc>().add(
      VideoEditorPositionChanged(clamped),
    );
  }

  void _onStopMotionTick(Duration _) {
    if (!mounted) return;
    final total = _stopMotionTotalDuration;
    if (total <= Duration.zero) {
      _pauseStopMotion();
      return;
    }

    final looped = stopMotionLoopPosition(
      anchor: _stopMotionAnchor,
      elapsed: _stopMotionStopwatch.elapsed,
      total: total,
    );

    // Frame-rate consumers first: timed layers follow the overlay play time
    // (the normal path drives it per frame from the playhead interpolator),
    // and the audio engine needs the wrap/window transitions the throttled
    // bloc emit below would swallow.
    _setLayerPlayTime(looped);
    final audio = _stopMotionAudio;
    if (audio != null) unawaited(audio.syncTo(looped, isPlaying: true));

    // Throttle emits: the timeline animates between updates, so a frame-rate
    // stream would only flood the bloc. A wrap back to the start (looped <
    // last) always passes so the loop reset isn't swallowed.
    final advanced = looped - _lastStopMotionEmit;
    if (advanced >= Duration.zero &&
        advanced < VideoEditorConstants.stopMotionPlayheadEmitInterval) {
      return;
    }
    _lastStopMotionEmit = looped;
    context.read<VideoEditorMainBloc>().add(VideoEditorPositionChanged(looped));
  }

  /// Coalesces volume-history writes from clip and audio revision changes.
  ///
  /// Both the [ClipEditorBloc] (clipsVolumeRevision) and
  /// [TimelineOverlayBloc] (audioTracksRevision) BlocListeners call this
  /// helper. If both revision counters fire in the same frame — as happens
  /// during a mute-all toggle — the [addPostFrameCallback] runs only once,
  /// writing a single combined undo point that covers clips + audio rather
  /// than two separate entries.
  void _scheduleVolumeHistoryWrite() {
    if (_isVolumeSavePending) return;
    _isVolumeSavePending = true;
    addPostFrameCallbackIfMounted(() {
      _isVolumeSavePending = false;
      VideoEditorScope.of(context).editor?.setVolumeState(
        clips: context.read<ClipEditorBloc>().state.clips,
        audioTracks: context.read<TimelineOverlayBloc>().state.audioTracks,
      );
    });
  }

  /// Handles seek requests from BLoC (e.g. timeline scrubbing).
  ///
  /// Uses a leading + trailing pattern with async backpressure:
  /// - The first request (leading) is executed immediately via await.
  /// - While the native seekTo is in flight, intermediate requests are
  ///   dropped; only the latest position is kept.
  /// - Once the seek completes, the last received position is fired as
  ///   a trailing seek so the video always lands on the final frame.
  ///
  /// This relies on both Android and iOS returning from seekTo only
  /// after the frame is actually decoded and rendered.
  ///
  /// Returns the composite-timeline position of the most recent
  /// in-progress clip trim (and clears the captured values), so that
  /// after a trim drag ends and the multi-clip composite is restored,
  /// playback stays on the frame the user released. Returns `null`
  /// when no trim was in progress, the trimmed clip is no longer in
  /// the list, or the captured position falls outside the clip's
  /// trimmed range.
  Duration? _consumeTrimEndStartPosition(List<DivineVideoClip> clips) {
    final clipId = _lastTrimClipId;
    final positionInClip = _lastTrimPositionInClip;
    _lastTrimClipId = null;
    _lastTrimPositionInClip = null;
    if (clipId == null || positionInClip == null) return null;

    return clipSourcePositionToTimelinePosition(
      clips,
      clipId: clipId,
      sourcePosition: positionInClip,
    );
  }

  Future<void> _onSeekRequested(
    Duration position, {
    Duration? playTimePosition,
  }) async {
    if (_isStopMotionComposition) {
      _seekStopMotion(position);
      return;
    }
    if (!_isPlayerReadyNotifier.value || !_isPlayerInitialized) return;

    // A scrub owns the play time now; stop the playback interpolator so it
    // can't overwrite the seek target before the next player report stops it.
    _setPlayheadTickerActive(false);
    final playTime = playTimePosition ?? position;
    _setLayerPlayTime(playTime);
    // Pin the play time to this scrub so late reports from a superseded seek
    // are dropped until the player converges here (see [_onPlayerStateChanged]
    // / [VideoEditorCanvas.shouldAcceptPlayerReport]).
    _pendingSeekTarget = playTime;

    if (_isSeeking) {
      _pendingSeekPosition = position;
      return;
    }

    _isSeeking = true;
    final epoch = _seekEpoch;
    try {
      await _videoPlayer?.seekTo(_timelineToPlayer(position));
      if (_seekEpoch != epoch) {
        _pendingSeekPosition = null;
        return;
      }

      // Process trailing seek if one arrived while we were busy.
      while (_pendingSeekPosition != null && mounted) {
        final pending = _pendingSeekPosition!;
        _pendingSeekPosition = null;
        if (_seekEpoch != epoch) {
          _pendingSeekPosition = null;
          break;
        }
        await _videoPlayer?.seekTo(_timelineToPlayer(pending));
      }
    } finally {
      // Only reset under the current epoch; a composition swap takes over ownership.
      if (_seekEpoch == epoch) {
        _isSeeking = false;
      }
    }
  }

  /// Dispatches playback state changes to the BLoC.
  ///
  /// Reports play/pause state, current position, and duration so the
  /// timeline can stay in sync with the real player.
  /// Only dispatches when values actually change to avoid flooding.
  void _onPlayerStateChanged(DivineVideoPlayerState playerState) {
    final bloc = context.read<VideoEditorMainBloc>();

    final isPlaying = playerState.isPlaying;
    if (isPlaying != _lastIsPlaying) {
      _lastIsPlaying = isPlaying;
      bloc.add(VideoEditorPlaybackChanged(isPlaying: isPlaying));
      // Playback just stopped: apply any speed-render swap deferred while
      // playing, now that the reload can happen without restarting a clip.
      if (!isPlaying && _speedResyncPendingWhilePlaying) {
        _speedResyncPendingWhilePlaying = false;
        _resyncPlayerClips();
      }
    }

    // Once playback resumes it owns the play time, so release any scrub / swap
    // pin. While paused the pin is kept (not cleared on the first converged
    // report) so a reset report arriving hundreds of ms after a seam swap
    // finishes loading is still rejected instead of snapping the playhead back
    // to the start.
    if (isPlaying) _pendingSeekTarget = null;

    _lastPlayerDuration = playerState.duration;

    final timelinePosition = _playerToTimeline(playerState.position);

    // Drop the delayed reset report a composition swap emits while loading the
    // new seam file (and late reports from a superseded scrub seek) so the
    // playhead doesn't snap back to the start.
    final reportAccepted = VideoEditorCanvas.shouldAcceptPlayerReport(
      report: timelinePosition,
      seekTarget: _pendingSeekTarget,
      isPlaying: isPlaying,
    );

    // The play time may only be driven by playback while no seek / trim / drag
    // gesture owns it (those paths call setPlayTime directly).
    final canDrivePlayTime =
        !_isTrimmingLayer &&
        !_isTrimmingClip &&
        !_isDraggingLayer &&
        !_isSeeking &&
        _pendingSeekPosition == null &&
        reportAccepted;

    if (canDrivePlayTime && timelinePosition != _lastReportedPosition) {
      _lastReportedPosition = timelinePosition;
      bloc.add(VideoEditorPositionChanged(timelinePosition));
      _setLayerPlayTime(timelinePosition);
    }

    // Smoothly interpolate the layer overlay between the coarse native reports
    // while playing; re-anchor on every report to correct drift. Stop the
    // moment playback ends or a gesture takes over the play time.
    if (isPlaying && canDrivePlayTime) {
      _anchorPlayhead(playerState);
      _setPlayheadTickerActive(true);
    } else {
      _setPlayheadTickerActive(false);
    }

    final timelineDuration = _playerToTimeline(playerState.duration);
    if (timelineDuration != _lastReportedDuration) {
      _lastReportedDuration = timelineDuration;
      bloc.add(VideoEditorDurationChanged(timelineDuration));
    }
  }

  /// Captures the authoritative player position/speed as the interpolation
  /// anchor and restarts the wall-clock used to advance from it.
  void _anchorPlayhead(DivineVideoPlayerState playerState) {
    _playheadAnchorPlayer = playerState.position;
    _playheadAnchorSpeed = playerState.playbackSpeed > 0
        ? playerState.playbackSpeed
        : 1;
    _playheadStopwatch
      ..reset()
      ..start();
  }

  void _setPlayheadTickerActive(bool active) {
    if (active) {
      final ticker = _playheadTicker ??= createTicker(_onPlayheadTick);
      if (!ticker.isActive) ticker.start();
    } else {
      _playheadStopwatch.stop();
      if (_playheadTicker?.isActive ?? false) _playheadTicker!.stop();
    }
    _setPlayheadAdvancing(advancing: active);
  }

  /// Publishes whether the playhead is being advanced by playback.
  ///
  /// Both tickers report through here — the composition player's and the
  /// stop-motion clock's — so anything following the playhead (a detached
  /// clip's companion player) stops the moment the editor does, instead of
  /// inferring a pause from ticks going quiet.
  void _setPlayheadAdvancing({required bool advancing}) {
    // Captured in didChangeDependencies, not read here: this runs from ticker
    // and teardown paths, and an inherited-widget lookup outside build takes a
    // dependency (and asserts once the element is defunct).
    _playheadAdvancingNotifier?.value = advancing;
  }

  /// Advances the overlay play time from the anchor by the wall-clock elapsed
  /// (scaled by playback speed), mapped back into editor-timeline space.
  void _onPlayheadTick(Duration _) {
    if (!mounted) return;
    final position = interpolatePlayheadPosition(
      anchor: _playheadAnchorPlayer,
      elapsed: _playheadStopwatch.elapsed,
      speed: _playheadAnchorSpeed,
      maxDuration: _lastPlayerDuration,
    );
    _setLayerPlayTime(_playerToTimeline(position));
  }

  /// Drives the burned-in layers' play time and publishes the same timeline
  /// position to the scope so canvas overlays (the CC caption pill) track
  /// playback at the layer cadence instead of the coarse bloc position.
  void _setLayerPlayTime(Duration timelinePosition) {
    _proVideoController.setPlayTime(timelinePosition);
    _playTimeNotifier?.value = timelinePosition;
  }

  /// Called when clip paths change. Updates the player with the new clips
  /// or pauses when no clips are available.
  void _onClipPathsChanged(List<String> clipPaths) {
    if (!_isPlayerInitialized) return;

    if (clipPaths.isEmpty) {
      _videoPlayer?.pause();
      _beginClipLoad();
      context.read<VideoEditorMainBloc>().add(
        const VideoEditorPlaybackChanged(isPlaying: false),
      );
      return;
    }

    final clips = ref.read(clipManagerProvider).clips;
    final currentPosition = context
        .read<VideoEditorMainBloc>()
        .state
        .currentPosition;
    // Pin so a reset report from loading the (seam-aware) composition doesn't
    // snap the playhead back while paused.
    _pendingSeekTarget = currentPosition;
    final generation = _beginClipLoad();
    unawaited(
      _setClipsForGeneration(generation, _videoPlayer, [
        ..._buildPlayerClips(clips),
      ], startPosition: _timelineToPlayer(currentPosition)),
    );
    _ensureSeamsRendered(clips);
    _ensureSpeedClipsRendered(clips);
  }

  /// Creates the [ProVideoController] (only once, not tied to a file).
  void _initializeController() {
    _proVideoController =
        ProVideoController(
          videoPlayer: ValueListenableBuilder(
            valueListenable: _isPlayerReadyNotifier,
            builder: (_, isPlayerReady, _) {
              return Consumer(
                builder: (context, ref, _) {
                  final clip = ref.watch(
                    clipManagerProvider.select((s) => s.firstClipOrNull),
                  );
                  if (clip == null) return const SizedBox.shrink();

                  return Stack(
                    fit: StackFit.passthrough,
                    children: [
                      VideoEditorClipPreview(
                        clip: clip,
                        controller: _videoPlayer,
                        bodySize: widget.bodySize,
                        renderSize: widget.renderSize,
                      ),
                      Positioned.fill(
                        child: ValueListenableBuilder<int>(
                          valueListenable: _pendingSeamRenders,
                          builder: (_, count, _) => AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: count == 0
                                ? const SizedBox.shrink()
                                : const ColoredBox(
                                    color: Color.fromARGB(140, 0, 0, 0),
                                    child: Center(
                                      child: BrandedLoadingIndicator(size: 44),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
          initialResolution: widget.renderSize,
          // These values are not used since we provide a custom-UI.
          fileSize: 0,
          videoDuration: .zero,
        )..initialize(
          callbacksAudioFunction: () => const AudioEditorCallbacks(),
          callbacksFunction: VideoEditorCallbacks.new,
          configsFunction: () => const VideoEditorConfigs(),
        );
  }

  /// Loads [clips] into [player], returning whether the composition built.
  ///
  /// Thin instance wrapper over [VideoEditorCanvas.guardClipLoad] so callers
  /// don't repeat the null-player guard; see that method for the failure
  /// contract.
  Future<bool> _setClipsSafely(
    DivineVideoPlayerController? player,
    List<VideoClip> clips, {
    Duration? startPosition,
  }) {
    return VideoEditorCanvas.guardClipLoad(
      () =>
          player?.setClips(clips, startPosition: startPosition) ??
          Future<void>.value(),
    );
  }

  Future<bool> _setClipsForGeneration(
    int generation,
    DivineVideoPlayerController? player,
    List<VideoClip> clips, {
    Duration? startPosition,
  }) async {
    try {
      final loaded = await _setClipsSafely(
        player,
        clips,
        startPosition: startPosition,
      );
      _endClipLoad(generation, isReady: loaded);
      return loaded;
    } catch (_) {
      _endClipLoad(generation, isReady: false);
      rethrow;
    }
  }

  /// Initializes (or reinitializes) the native video player with [clipPaths].
  Future<void> _initializePlayer(
    List<String> clipPaths, {
    Duration? startPosition,
  }) async {
    // Dispose old player if it exists.
    await _videoPlayerSubscription?.cancel();
    await _videoPlayer?.dispose();
    final generation = _beginClipLoad();

    final clips = ref.read(clipManagerProvider).clips;

    // The clip list is named, not just counted: when the preview shows footage
    // the timeline no longer contains — a clip detached onto the canvas, say —
    // the question is always *which* files the player was handed, and a bare
    // count cannot answer it.
    Log.debug(
      '🎬 Initializing video player with ${clipPaths.length} clip(s): '
      '${clips.map((c) => '${c.id}->'
          '${(c.video?.file?.path ?? '?').split('/').last}').join(', ')}',
      name: 'VideoEditorCanvas',
      category: LogCategory.video,
    );

    // Hold the controller locally and re-check identity after every await: a
    // fast Done-tap (release) or a newer init can replace/null `_videoPlayer`
    // mid-flight. Whoever supersedes us owns disposing this controller, so we
    // just abandon it rather than resurrecting a released player.
    final player = DivineVideoPlayerController(
      useTexture: true,
      // A detached clip puts a second texture-backed player on this screen.
      // The SurfaceProducer backend shares an ImageReader pool across players,
      // and that is how the detached clip's frames surfaced inside this
      // player's area — the composition briefly showing footage its own clip
      // list does not contain. The legacy SurfaceTexture has no shared pool.
      //
      // The trade-off is deliberate: the legacy backend has no surface-recreate
      // callback, so it cannot transparently survive an OEM compositor event
      // (a permission dialog, for instance) and the player is re-initialised
      // instead.
      useLegacySurface: _useLegacySurface,
      debugLabel: 'editor_canvas',
    );
    _videoPlayer = player;

    await player.initialize();
    if (!mounted || !identical(_videoPlayer, player)) return;
    late final bool loaded;
    try {
      loaded = await _setClipsSafely(
        player,
        [
          ..._buildPlayerClips(clips),
        ],
        startPosition: startPosition != null && startPosition > Duration.zero
            ? _timelineToPlayer(startPosition)
            : null,
      );
    } catch (_) {
      _endClipLoad(generation, isReady: false);
      rethrow;
    }
    if (!mounted || !identical(_videoPlayer, player)) return;
    // Composition failed to build (stale/corrupt draft clip): leave the canvas
    // on its thumbnail fallback rather than marking a broken player ready.
    if (!loaded) {
      _endClipLoad(generation, isReady: false);
      return;
    }

    if (clips.isEmpty) return;
    _ensureSeamsRendered(clips);
    _ensureSpeedClipsRendered(clips);
    await player.setLooping(looping: true);
    if (!mounted || !identical(_videoPlayer, player)) return;

    _endClipLoad(generation, isReady: true);

    // Setup state stream listener
    _videoPlayerSubscription = player.stateStream.listen(_onPlayerStateChanged);

    // Initialize audio if selected
    await _syncAudioTracks();
    Log.info(
      '🎬 Video player ready',
      name: 'VideoEditorCanvas',
      category: LogCategory.video,
    );
  }

  /// Tears down the native preview player so a codec-heavy export can claim the
  /// device's scarce hardware codecs.
  ///
  /// The exporter encodes via `ProVideoEditor` (MediaCodec / AVFoundation); on
  /// codec-limited devices a still-alive — even paused — preview decoder
  /// contends with it (the encoder `RENDER_ERROR` class #5522 released the
  /// background feed for, one layer up). `_videoPlayer` is nulled before the
  /// dispose so the canvas drops to its thumbnail placeholder, and the player
  /// is rebuilt via [_initializePlayer] when the editor regains focus.
  Future<void> _releasePlayer() async {
    final player = _videoPlayer;
    if (player == null) return;
    // Claim ownership immediately so a concurrent init / dispose sees null and
    // bails instead of racing us on the same controller.
    _videoPlayer = null;
    await _videoPlayerSubscription?.cancel();
    _videoPlayerSubscription = null;
    // The wait before this can outlive the widget (dispose() disposes the
    // notifier/ticker); only touch them while still mounted.
    if (mounted) {
      _setPlayheadTickerActive(false);
    }
    // Also invalidates any in-flight load, so a `setClips` that resolves after
    // the release cannot re-enable the play button for a disposed player.
    _beginClipLoad();
    await player.dispose();
  }

  /// Syncs native audio overlay tracks from the [TimelineOverlayBloc]
  /// sound items.
  ///
  /// Reads timeline positions (`startTime` / `endTime`) from the BLoC
  /// state and combines them with the source [AudioEvent] from the
  /// Riverpod provider (URL, asset path, start offset).
  /// Schedules the timeline sounds on the stop-motion audio engine, mirroring
  /// the native `setAudioTracks` mapping: each sound's window comes from its
  /// timeline item, and the source is clipped to the sound's own start offset
  /// plus the window length.
  Future<void> _syncStopMotionAudio() async {
    final overlayState = context.read<TimelineOverlayBloc>().state;
    final audioById = {for (final e in overlayState.audioTracks) e.id: e};

    final tracks = <StopMotionAudioPreviewTrack>[];
    for (final item in overlayState.items) {
      if (item.type != TimelineOverlayType.sound) continue;
      final sound = audioById[item.id];
      if (sound == null) continue;

      final trackStart = sound.startOffset;
      final trackEnd = trackStart + (item.endTime - item.startTime);
      final AudioSourceConfig source;
      if (sound.isBundled && sound.assetPath != null) {
        source = AudioSourceConfig.asset(
          sound.assetPath!,
          start: trackStart,
          end: trackEnd,
        );
      } else if (sound.isLocalImport && sound.localFilePath != null) {
        source = AudioSourceConfig.file(
          sound.localFilePath!,
          start: trackStart,
          end: trackEnd,
        );
      } else if (sound.url != null) {
        source = AudioSourceConfig.network(
          sound.url!,
          start: trackStart,
          end: trackEnd,
        );
      } else {
        continue;
      }

      tracks.add(
        StopMotionAudioPreviewTrack(
          id: item.id,
          source: source,
          volume: sound.volume,
          windowStart: item.startTime,
          windowEnd: item.endTime,
        ),
      );
    }

    final preview = _stopMotionAudio ??= StopMotionAudioPreview();
    await preview.setTracks(tracks);
    Log.info(
      '🎵 Stop-motion audio synced: ${tracks.length} track(s)',
      name: 'VideoEditorCanvas',
      category: LogCategory.video,
    );
  }

  Future<void> _syncAudioTracks() async {
    // Frames-only composition: no native player exists to carry the tracks —
    // schedule them on the stop-motion audio engine instead.
    if (_isStopMotionComposition) {
      await _syncStopMotionAudio();
      return;
    }
    if (!_isPlayerInitialized) return;

    final overlayState = context.read<TimelineOverlayBloc>().state;
    final audioEvents = overlayState.audioTracks;

    final soundItems = overlayState.items
        .where((item) => item.type == TimelineOverlayType.sound)
        .toList();

    if (soundItems.isEmpty || audioEvents.isEmpty) {
      await _videoPlayer!.removeAllAudioTracks();
      Log.info(
        '🎵 Audio cleared',
        name: 'VideoEditorCanvas',
        category: LogCategory.video,
      );
      return;
    }

    // Index audio events by ID for fast lookup.
    final audioById = {for (final e in audioEvents) e.id: e};

    final tracks = <AudioTrack>[];
    for (final item in soundItems) {
      final sound = audioById[item.id];
      if (sound == null || sound.url == null) continue;

      try {
        final AudioTrack track;
        if (sound.isBundled && sound.assetPath != null) {
          track = await AudioTrack.asset(
            sound.assetPath!,
            volume: sound.volume,
            videoStartTime: item.startTime,
            videoEndTime: item.endTime,
            trackStart: sound.startOffset,
          );
        } else if (sound.isLocalImport && sound.localFilePath != null) {
          track = AudioTrack.file(
            sound.localFilePath!,
            volume: sound.volume,
            videoStartTime: item.startTime,
            videoEndTime: item.endTime,
            trackStart: sound.startOffset,
          );
        } else {
          track = AudioTrack.network(
            sound.url!,
            volume: sound.volume,
            videoStartTime: item.startTime,
            videoEndTime: item.endTime,
            trackStart: sound.startOffset,
          );
        }
        tracks.add(track);
      } catch (e, stackTrace) {
        Log.error(
          '🎵 Failed to build audio track ${item.id}: $e',
          name: 'VideoEditorCanvas',
          category: LogCategory.video,
          error: e,
          stackTrace: stackTrace,
        );
      }
    }

    if (tracks.isEmpty) {
      await _videoPlayer!.removeAllAudioTracks();
      return;
    }

    try {
      await _videoPlayer!.setAudioTracks(tracks);
    } catch (e, stackTrace) {
      Log.error(
        '🎵 Failed to load audio: $e',
        name: 'VideoEditorCanvas',
        category: LogCategory.video,
        error: e,
        stackTrace: stackTrace,
      );
      return;
    }

    Log.info(
      '🎵 Audio synced: ${tracks.length} track(s)',
      name: 'VideoEditorCanvas',
      category: LogCategory.video,
    );
  }

  /// Syncs the main-editor capabilities from the main editor to the bloc.
  /// Timeline end position for a lip-sync sound seeded on editor init.
  ///
  /// Spans from zero up to the sound's own length, capped at the editor's hard
  /// duration ceiling. The editor re-clamps it to the real video duration once
  /// that is measured.
  Duration _lipSyncAudioEndTime(double? durationSecs) {
    final soundMs = durationSecs != null
        ? (durationSecs * 1000).round()
        : VideoEditorConstants.maxDuration.inMilliseconds;
    return Duration(
      milliseconds: min(
        soundMs,
        VideoEditorConstants.maxDuration.inMilliseconds,
      ),
    );
  }

  /// Mirrors the main editor's capabilities, overlay items and clip snapshot
  /// into the BLoCs / providers after an editor change.
  ///
  /// [direction] tells the orphan-only reconciliation which way an undo/redo
  /// navigated (see [VideoEditorCanvas.resolveClipSnapshotSync]); it defaults
  /// to [ClipHistoryDirection.none] for non-navigation calls.
  ///
  /// [allowOrphanStep] gates whether this pass may step the editor history
  /// past an orphan-only entry. The directional `onUndo`/`onRedo` callbacks
  /// and the post-import sync own the step. The generic `onStateHistoryChange`
  /// reconcile must pass `false`: `undoAction()`/`redoAction()` fire
  /// `onStateHistoryChange` (with no direction) *before* `onUndo`/`onRedo`, so
  /// every navigation schedules this method twice. If the directionless pass
  /// also stepped, its backward bias would preempt a forward (redo) recovery
  /// and both passes would race the shared [_orphanStepDidReverse] flag.
  void _syncMainCapabilities(
    VideoEditorScope scope,
    VideoEditorMainBloc bloc, {
    ClipHistoryDirection direction = ClipHistoryDirection.none,
    bool allowOrphanStep = true,
  }) {
    final editor = scope.editor;
    if (editor == null) return;

    // The frame can land after the editor is torn down; the guard bails before
    // touching context or providers so we never read State.context post-unmount.
    addPostFrameCallbackIfMounted(() async {
      bloc.add(
        VideoEditorMainCapabilitiesChanged(
          canUndo: editor.canUndo,
          canRedo: editor.canRedo,
          layers: editor.activeLayers,
        ),
      );

      final videoDuration = context.read<ClipEditorBloc>().state.totalDuration;

      context.read<TimelineOverlayBloc>().add(
        TimelineOverlayItemsUpdate(
          layers: editor.activeLayers,
          filters: editor.stateManager.activeFilters,
          tuneAdjustments: editor.stateManager.activeTuneAdjustments,
          totalVideoDuration: videoDuration,
          audioTracks: editor.stateManager.audioTracks,
          timelineMarkers: editor.stateManager.timelineMarkers,
          captionTrack: editor.stateManager.captionTrack,
        ),
      );

      // Reconcile the editor's current history entry with the app clip state.
      // Undo/redo can resurrect a clip removed earlier in the session — its
      // media was already deleted by FileCleanupService, and handing that dead
      // path to the player fails the whole composition (COMPOSITION_ERROR) and
      // freezes the editor. Orphaned clips are filtered out, and an entry whose
      // clips are *all* orphaned is stepped over (rather than left to diverge
      // from, or empty the, native player).
      final snapshot = editor.stateManager.clipSnapshots(await _documentsPath);
      if (!mounted || _isImportingHistory) return;

      final decision = VideoEditorCanvas.resolveClipSnapshotSync(
        snapshot: snapshot,
        direction: direction,
        canUndo: editor.canUndo,
        canRedo: editor.canRedo,
        didReverse: _orphanStepDidReverse,
      );

      if (!allowOrphanStep) {
        // Generic history-change reconcile: it fires alongside the directional
        // onUndo/onRedo on every navigation, so it neither steps nor touches
        // the walk's reverse-once flag — the directional pass (scheduled in the
        // same frame) owns resolving an orphan-only entry. We only mirror a
        // resolvable entry; an orphan-only or empty one is left to that pass.
        if (decision.op != ClipSnapshotSyncOp.sync) return;
      } else {
        switch (decision.op) {
          case ClipSnapshotSyncOp.skip:
            _orphanStepDidReverse = false;
            return;
          case ClipSnapshotSyncOp.stepBackward:
            _orphanStepDidReverse = _orphanStepDidReverse || decision.reversed;
            editor.undoAction();
            return;
          case ClipSnapshotSyncOp.stepForward:
            _orphanStepDidReverse = _orphanStepDidReverse || decision.reversed;
            editor.redoAction();
            return;
          case ClipSnapshotSyncOp.sync:
            _orphanStepDidReverse = false;
        }
      }

      final clips = decision.resolvableClips;

      if (_skipNextClipSnapshotSync) {
        _skipNextClipSnapshotSync = false;
        return;
      }

      // A split (and any split still queued behind it) drives the clip list
      // optimistically in ClipEditorBloc, one step ahead of the editor
      // history. This snapshot reflects the *previous* split's committed
      // state; mirroring it back now would overwrite the just-applied split —
      // a queued split then silently vanishes and never appears. Skip while a
      // split is in flight; the reconcile that runs once isSplitting clears
      // mirrors the settled clip list to both the clip manager and the bloc.
      if (context.read<ClipEditorBloc>().state.isSplitting) return;

      // Only update if clips actually changed to avoid unnecessary rebuilds
      // and autosave triggers. DivineVideoClip uses reference equality, so
      // we compare the editable properties explicitly.
      final currentClips = ref.read(clipManagerProvider).clips;
      if (VideoEditorCanvas.clipsChanged(currentClips, clips)) {
        ref.read(clipManagerProvider.notifier).replaceClips(clips);
      }
      if (VideoEditorCanvas.clipsChanged(
        context.read<ClipEditorBloc>().state.clips,
        clips,
      )) {
        context.read<ClipEditorBloc>().add(ClipEditorInitialized(clips));
      }
    });
  }

  /// Syncs the draw capabilities from the paint editor to the bloc.
  void _syncDrawCapabilities(VideoEditorScope scope, VideoEditorDrawBloc bloc) {
    final paintEditor = scope.paintEditor;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      bloc.add(
        VideoEditorDrawCapabilitiesChanged(
          canUndo: paintEditor?.canUndo ?? false,
          canRedo: paintEditor?.canRedo ?? false,
        ),
      );
    });
  }

  /// Seeds the tune editor's live preview with the edited set's values via its
  /// public `onChanged` API. The editor seeds itself neutral because set
  /// members carry unique per-instance ids rather than preset ids.
  void _seedTuneEditorPreview(VideoEditorScope scope, String? setId) {
    if (setId == null) return;
    final tuneEditor = scope.tuneEditor;
    final active = scope.editor?.stateManager.activeTuneAdjustments;
    if (tuneEditor == null || active == null) return;
    seedTuneEditorPreview(
      tuneEditor: tuneEditor,
      active: active,
      setId: setId,
    );
  }

  /// Handles state history changes and exports the history to the provider.
  Future<void> _onStateHistoryChange(
    VideoEditorScope scope,
    VideoEditorMainBloc bloc,
  ) async {
    if (_isImportingHistory || !_isInitialized) return;

    // Directionless: the directional onUndo/onRedo pass owns stepping past an
    // orphan-only entry (this callback fires first, before onUndo/onRedo).
    _syncMainCapabilities(scope, bloc, allowOrphanStep: false);
    final result = await scope.requireEditor.exportStateHistory(
      configs: const ExportEditorConfigs(
        historySpan: .currentAndBackward,
        // We don't minify the state history so it remains readable for
        // ProofMode.
        enableMinify: false,
      ),
    );
    final history = await result.toMap();

    ref.read(videoEditorProvider.notifier).updateEditorStateHistory(history);
  }

  /// Handles the completion of the image editor with parameters.
  ///
  /// Precaches the generated image overlay and triggers video rendering.
  Future<void> _handleEditorComplete(CompleteParameters parameters) async {
    Log.info(
      '🎬 Editor complete - starting render (image size: ${parameters.image.length} bytes)',
      name: 'VideoEditorCanvas',
      category: LogCategory.video,
    );
    final notifier = ref.read(videoEditorProvider.notifier);
    if (parameters.layers.isNotEmpty && parameters.image.isNotEmpty) {
      try {
        // We only precache the image for the preview on the metadata screen,
        // which is not relevant for rendering.
        await precacheImage(MemoryImage(parameters.image), context);
      } catch (e) {
        Log.warning(
          '🎬 Precache failed, continuing anyway: $e',
          name: 'VideoEditorCanvas',
          category: LogCategory.video,
        );
      }
    }
    notifier.updateEditorEditingParameters(parameters);
    // Hold the export encoder back until [_handleDone] has released the preview
    // decoder (after the metadata screen covers the editor), so the two never
    // contend for the device's scarce hardware codecs (see #5522). The gate is
    // created by [_handleDone], which always runs first.
    await (_decoderReleaseGate?.future ?? Future<void>.value());
    if (!_isMetadataRouteActive) {
      notifier.setProcessing(false);
      return;
    }
    notifier.startRenderVideo();
  }

  /// Handles the done action from the main editor.
  ///
  /// Navigates to the metadata screen and, once it has finished covering the
  /// editor ([awaitPushTransition]), releases the preview decoder off-screen and
  /// opens [_decoderReleaseGate] so [_handleEditorComplete] only then starts the
  /// export encoder — the two must never contend (see #5522). Rebuilds the
  /// player at the same position on return, resuming playback only if it was
  /// playing before. Mirrors `openVideoEditorFromRecorder`; audio sync handled
  /// by listener.
  Future<void> _handleDone() async {
    Log.info(
      '🎬 Done pressed - navigating to metadata screen',
      name: 'VideoEditorCanvas',
      category: LogCategory.video,
    );
    // A stop-motion composition has no native player — its playback is the
    // widget-driven ticker, whose playing state lives in the bloc. Read before
    // _pauseStopMotion() below clears it.
    final wasPlaying = _isStopMotionComposition
        ? context.read<VideoEditorMainBloc>().state.isPlaying
        : (_videoPlayer?.state.isPlaying ?? false);
    final resumePosition = context
        .read<VideoEditorMainBloc>()
        .state
        .currentPosition;
    // The stop-motion clock (and its audio engine) is widget-driven, not part
    // of the native player teardown below — without this the sounds keep
    // playing under the metadata screen.
    if (_isStopMotionComposition) _pauseStopMotion();
    ref.read(videoEditorProvider.notifier).setProcessing(true);

    // Delegate the cover-transition wait to the screen: its context sits above
    // this canvas's nested `Navigator`, so the editor route's secondaryAnimation
    // is actually driven by the push (the canvas context resolves to the inner
    // route, which the outer push never animates). Falls back to the canvas
    // context — timeout-bounded — when the scope didn't provide it.
    final awaitCover = VideoEditorScope.of(context).awaitPushCoverTransition;
    final gate = _decoderReleaseGate = Completer<void>();
    _isMetadataRouteActive = true;
    final navigation = context.push(
      VideoMetadataScreen.pathForDraft(
        isStopMotion: _isStopMotionComposition,
      ),
    );
    try {
      await (awaitCover?.call() ??
          awaitPushTransition(
            context,
            timeout: VideoEditorConstants.coverTransitionTimeout,
          ));
      await _releasePlayer();
    } finally {
      // Always open the gate so the render can never wedge, even if the release
      // throws.
      if (!gate.isCompleted) gate.complete();
    }

    try {
      await navigation;
    } finally {
      _isMetadataRouteActive = false;
    }
    if (!mounted) return;
    // Stop-motion has no player to rebuild (_clipPaths is empty, which the
    // guard below would take as "nothing to resume"); restarting its ticker is
    // the whole resume.
    if (_isStopMotionComposition) {
      if (wasPlaying) _playStopMotion(from: resumePosition);
      return;
    }
    if (_clipPaths.isEmpty) return;
    await ref.read(videoEditorProvider.notifier).waitForRenderIdle();
    if (!mounted || _clipPaths.isEmpty) return;
    await _initializePlayer(_clipPaths, startPosition: resumePosition);
    if (mounted && wasPlaying) {
      _videoPlayer?.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = VideoEditorScope.of(context);

    // BLOCs
    final bloc = context.read<VideoEditorMainBloc>();
    final drawBloc = context.read<VideoEditorDrawBloc>();

    // Riverpod
    final clip = ref.watch(
      clipManagerProvider.select((s) => s.firstClipOrNull),
    );
    if (clip == null) return const SizedBox.shrink();

    final editorStateHistory = ref.read(
      videoEditorProvider.select((s) => s.editorStateHistory),
    );
    final targetAspectRatio = clip.targetAspectRatio;

    // Reinitialize the player when clip paths change.
    // Uses a custom equality check because List uses reference equality by
    // default, which would cause the listener to fire on every provider
    // rebuild even when the paths haven't actually changed.
    ref.listen<List<String>>(
      clipManagerProvider.select(
        (s) => s.clips
            .map((c) => c.video?.file?.path)
            .whereType<String>()
            .toList(),
      ),
      (previous, clipPaths) {
        if (listEquals(previous, clipPaths)) return;

        // If only the order changed (reorder), the BlocListener below
        // calls setClips with startPosition — no full reinit needed.
        final prevSorted = previous != null
            ? ([...previous]..sort())
            : <String>[];
        final currSorted = [...clipPaths]..sort();
        if (listEquals(prevSorted, currSorted)) return;

        _onClipPathsChanged(clipPaths);
      },
    );

    // Update native player clip boundaries when trim times change.
    ref.listen<List<(Duration, Duration)>>(
      clipManagerProvider.select(
        (s) => s.clips.map((c) => (c.trimStart, c.trimEnd)).toList(),
      ),
      (previous, current) {
        if (listEquals(previous, current)) return;

        final clips = ref.read(clipManagerProvider).clips;
        // Skip when there are no clips left (e.g. clearAll during
        // teardown). Sending `setClips([])` to the native player
        // builds a composition with `renderSize == .zero` on iOS,
        // which crashes `AVPlayerItem.setVideoComposition:`.
        if (clips.isEmpty || !_isPlayerInitialized) return;
        final currentPosition = context
            .read<VideoEditorMainBloc>()
            .state
            .currentPosition;

        // Pin so a reset report from loading the seam-aware composition
        // doesn't snap the playhead back while paused.
        _pendingSeekTarget = currentPosition;
        final generation = _beginClipLoad();
        unawaited(
          _setClipsForGeneration(
            generation,
            _videoPlayer,
            [
              ..._buildPlayerClips(clips),
            ],
            startPosition: _timelineToPlayer(currentPosition),
          ),
        );
        _ensureSeamsRendered(clips);
        _ensureSpeedClipsRendered(clips);
      },
    );

    // Update native player speeds when any clip's playback speed changes.
    ref.listen<List<double?>>(
      clipManagerProvider.select(
        (s) => s.clips.map((c) => c.playbackSpeed).toList(),
      ),
      (previous, current) {
        if (listEquals(previous, current)) return;

        final clips = ref.read(clipManagerProvider).clips;
        if (clips.isEmpty || !_isPlayerInitialized) return;
        final currentPosition = context
            .read<VideoEditorMainBloc>()
            .state
            .currentPosition;

        // Pin so a reset report from loading the seam-aware composition
        // doesn't snap the playhead back while paused.
        _pendingSeekTarget = currentPosition;
        final generation = _beginClipLoad();
        unawaited(
          _setClipsForGeneration(
            generation,
            _videoPlayer,
            [
              ..._buildPlayerClips(clips),
            ],
            startPosition: _timelineToPlayer(currentPosition),
          ),
        );
        _ensureSeamsRendered(clips);
        _ensureSpeedClipsRendered(clips);
      },
    );

    // Rebuild the native composition when any clip's transition changes so the
    // preview reflects the chosen dissolve/fade/slide. ClipTransition overrides
    // `==`, so the Object? element comparison detects real changes.
    ref.listen<List<Object?>>(
      clipManagerProvider.select(
        (s) => s.clips.map((c) => c.transition).toList(),
      ),
      (previous, current) {
        if (listEquals(previous, current)) return;

        final clips = ref.read(clipManagerProvider).clips;
        if (clips.isEmpty || !_isPlayerInitialized) return;
        final currentPosition = context
            .read<VideoEditorMainBloc>()
            .state
            .currentPosition;

        unawaited(
          _swapComposition(clips, timelineStartPosition: currentPosition),
        );
        _ensureSeamsRendered(clips);
        _ensureSpeedClipsRendered(clips);
      },
    );

    // Listen for playback control requests from BLoC
    return MultiBlocListener(
      listeners: [
        BlocListener<TimelineOverlayBloc, TimelineOverlayState>(
          listenWhen: (previous, current) {
            _isTrimmingLayer = previous.trimmingItemId != null;
            return previous.trimPosition != current.trimPosition &&
                _isTrimmingLayer;
          },
          listener: (context, state) {
            // trimPosition is null on the release emit — skip to preserve
            // _lastLayerTrimPosition for the end-listener below.
            final position = state.trimPosition;
            if (position == null) return;
            _lastLayerTrimPosition = position;
            _onSeekRequested(position);
          },
        ),
        // Sync scrubber once at gesture end (not mid-drag) to avoid
        // premature scrubber jumps while the seek is still in flight.
        BlocListener<TimelineOverlayBloc, TimelineOverlayState>(
          listenWhen: (previous, current) =>
              previous.trimmingItemId != null && current.trimmingItemId == null,
          listener: (context, _) {
            final position = _lastLayerTrimPosition;
            _lastLayerTrimPosition = null;
            if (position == null) return;
            _lastReportedPosition = position;
            context.read<VideoEditorMainBloc>().add(
              VideoEditorPositionChanged(position),
            );
          },
        ),
        // Live seek while a layer item is dragged: follow its startTime.
        BlocListener<TimelineOverlayBloc, TimelineOverlayState>(
          listenWhen: (previous, current) {
            _isDraggingLayer = current.draggingItemId != null;
            return previous.dragPosition != current.dragPosition &&
                current.dragPosition != null;
          },
          listener: (context, state) {
            final position = state.dragPosition;
            if (position == null) return;
            _lastLayerDragPosition = position;
            _onSeekRequested(position);
          },
        ),
        // Sync scrubber once at drag end (not mid-drag).
        BlocListener<TimelineOverlayBloc, TimelineOverlayState>(
          listenWhen: (previous, current) =>
              previous.draggingItemId != null && current.draggingItemId == null,
          listener: (context, _) {
            final position = _lastLayerDragPosition;
            _lastLayerDragPosition = null;
            if (position == null) return;
            _lastReportedPosition = position;
            context.read<VideoEditorMainBloc>().add(
              VideoEditorPositionChanged(position),
            );
          },
        ),
        BlocListener<ClipEditorBloc, ClipEditorState>(
          // Swap to single-clip (untrimmed) view on trim start so
          // trimPosition seeks the correct frame.
          listenWhen: (previous, current) =>
              previous.trimmingClipId != current.trimmingClipId,
          listener: (context, state) {
            _isTrimmingClip = state.trimmingClipId != null;
            if (state.trimmingClipId == null || !_isPlayerInitialized) return;
            final clip = state.clips.firstWhere(
              (c) => c.id == state.trimmingClipId,
            );
            final path = clip.video?.file?.path;
            if (path == null) return;
            // Composition swap: invalidate in-flight seeks and release _isSeeking.
            _seekEpoch++;
            _pendingSeekPosition = null;
            _isSeeking = false;
            unawaited(
              _setClipsSafely(_videoPlayer, [
                VideoClip(
                  uri: path,
                  end: clip.duration,
                  volume: clip.volume,
                  playbackSpeed: clip.playbackSpeed ?? 1.0,
                ),
              ]),
            );
          },
        ),
        BlocListener<ClipEditorBloc, ClipEditorState>(
          // Live preview seek while a clip trim handle is dragged.
          listenWhen: (previous, current) =>
              current.trimmingClipId != null &&
              previous.trimPosition != current.trimPosition &&
              current.trimPosition != null,
          listener: (context, state) {
            final clipId = state.trimmingClipId;
            final sourcePosition = state.trimPosition;
            if (clipId == null || sourcePosition == null) return;

            _lastTrimClipId = clipId;
            _lastTrimPositionInClip = sourcePosition;
            final playTimePosition = clipSourcePositionToTimelinePosition(
              state.clips,
              clipId: clipId,
              sourcePosition: sourcePosition,
            );
            _onSeekRequested(
              sourcePosition,
              playTimePosition: playTimePosition,
            );
          },
        ),
        // Re-export state history when an overlay item drag or trim
        // ends so the updated positions are persisted for ProofMode.
        BlocListener<TimelineOverlayBloc, TimelineOverlayState>(
          listenWhen: (previous, current) =>
              (previous.draggingItemId != null &&
                  current.draggingItemId == null) ||
              (previous.trimmingItemId != null &&
                  current.trimmingItemId == null),
          listener: (context, state) {
            _onStateHistoryChange(scope, bloc);
          },
        ),
        // Sync native audio tracks when audio sources change
        // (sound added/removed/volume-changed) or a sound item is
        // dragged/trimmed.
        BlocListener<TimelineOverlayBloc, TimelineOverlayState>(
          listenWhen: (previous, current) {
            // Audio sources changed (add / remove / replace).
            if (previous.audioTracks != current.audioTracks) return true;

            // Audio track volume changed (user action).
            //
            // AudioEvent equality is identity-based (excludes volume), so
            // Equatable cannot detect a volume-only change via the
            // audioTracks list. audioTracksRevision is incremented by
            // user-driven audio volume change events to make the state
            // distinct and force the listener to fire here.
            if (previous.audioTracksRevision != current.audioTracksRevision) {
              return true;
            }

            // Audio track volume restored by undo/redo.
            //
            // audioTracksPlayerRevision is incremented in _onUpdateItems
            // when volumes differ from the current state (undo/redo path).
            // It is intentionally separate from audioTracksRevision so the
            // write-to-history listener does NOT fire and create a spurious
            // history entry.
            if (previous.audioTracksPlayerRevision !=
                current.audioTracksPlayerRevision) {
              return true;
            }

            // Sound item drag/trim ended.
            final dragEnded =
                previous.draggingItemId != null &&
                current.draggingItemId == null;
            final trimEnded =
                previous.trimmingItemId != null &&
                current.trimmingItemId == null;
            if (!dragEnded && !trimEnded) return false;

            final changedId =
                previous.draggingItemId ?? previous.trimmingItemId;
            final item = current.items
                .where((i) => i.id == changedId)
                .firstOrNull;
            return item?.type == TimelineOverlayType.sound;
          },
          listener: (context, state) {
            _syncAudioTracks();
          },
        ),
        // Persist audio track volume changes to the ProImageEditor undo
        // history. Both this listener and the clipsVolumeRevision listener
        // below call _scheduleVolumeHistoryWrite, which coalesces concurrent
        // revision bumps (e.g. mute-all toggle) into a single combined undo
        // point instead of two separate entries.
        BlocListener<TimelineOverlayBloc, TimelineOverlayState>(
          listenWhen: (previous, current) =>
              previous.audioTracksRevision != current.audioTracksRevision,
          listener: (context, state) {
            _scheduleVolumeHistoryWrite();
          },
        ),
        BlocListener<TimelineOverlayBloc, TimelineOverlayState>(
          listenWhen: (previous, current) =>
              previous.timelineMarkersRevision !=
              current.timelineMarkersRevision,
          listener: (context, state) {
            scope.requireEditor.setTimelineMarkers(state.timelineMarkers);
          },
        ),
        BlocListener<ClipEditorBloc, ClipEditorState>(
          listenWhen: (previous, current) {
            return !identical(
                  previous.lastReverseResult,
                  current.lastReverseResult,
                ) &&
                current.lastReverseResult is ClipReverseSuccess;
          },
          listener: (context, state) async {
            if (state.clips.isEmpty || !_isPlayerInitialized) return;

            _skipNextClipSnapshotSync = true;
            ref.read(clipManagerProvider.notifier).replaceClips(state.clips);

            final currentPosition = context
                .read<VideoEditorMainBloc>()
                .state
                .currentPosition;

            _seekEpoch++;
            _pendingSeekPosition = null;
            final generation = _beginClipLoad();
            _isSeeking = true;
            final ownerEpoch = _seekEpoch;

            try {
              final loaded = await _setClipsForGeneration(
                generation,
                _videoPlayer,
                [
                  ..._buildPlayerClips(state.clips),
                ],
                startPosition: _timelineToPlayer(currentPosition),
              );
              if (!loaded) return;

              if (!mounted) return;
              _lastReportedPosition = currentPosition;
              _pendingSeekTarget = currentPosition;
              _setLayerPlayTime(currentPosition);
            } finally {
              if (_seekEpoch == ownerEpoch) {
                _isSeeking = false;
              }
            }
          },
        ),
        // Update native player clip boundaries when trim handle is
        // released or for non-trim clip changes (reorder, add, remove).
        // Reverse completion is handled by the dedicated listener above.
        BlocListener<ClipEditorBloc, ClipEditorState>(
          listenWhen: (previous, current) {
            // Reverse completion is handled by the dedicated listener above.
            if (!identical(
                  previous.lastReverseResult,
                  current.lastReverseResult,
                ) &&
                current.lastReverseResult is ClipReverseSuccess) {
              return false;
            }
            return VideoEditorCanvas.shouldSyncPlayerForClipStateChange(
              previous: previous,
              current: current,
            );
          },
          listener: (context, state) async {
            // See note on the trim-times listener above: skip empty
            // clip lists to avoid crashing the iOS native player.
            if (state.clips.isEmpty || !_isPlayerInitialized) return;

            // Seek to the trim handle's release point when restoring the composite.
            final trimEndPosition = _consumeTrimEndStartPosition(state.clips);
            final startPosition = trimEndPosition ?? bloc.state.currentPosition;
            // Sync so subsequent re-emits read the post-seek position.
            if (trimEndPosition != null) {
              bloc.add(VideoEditorPositionChanged(trimEndPosition));
            }

            final needsLegacyUpgrade =
                !_useLegacySurface &&
                VideoEditorCanvas.shouldUseLegacySurface(
                  alreadyEnabled: _useLegacySurface,
                  editorStateHistory: const {},
                  detachResult: state.lastDetachResult,
                );
            if (needsLegacyUpgrade) {
              _useLegacySurface = true;
              _seekEpoch++;
              _pendingSeekPosition = null;
              _isSeeking = true;
              final ownerEpoch = _seekEpoch;
              try {
                await _initializePlayer(
                  state.clips
                      .map((clip) => clip.video?.file?.path)
                      .whereType<String>()
                      .toList(),
                  startPosition: startPosition,
                );
                if (!mounted) return;
                _lastReportedPosition = startPosition;
                _pendingSeekTarget = startPosition;
                _setLayerPlayTime(startPosition);
              } finally {
                if (_seekEpoch == ownerEpoch) _isSeeking = false;
              }
              return;
            }
            // Composition swap back — invalidate in-flight single-clip seeks.
            _seekEpoch++;
            _pendingSeekPosition = null;
            final generation = _beginClipLoad();
            // Claim _isSeeking under the new epoch; try/finally ensures
            // release even if setClips throws.
            _isSeeking = true;
            final ownerEpoch = _seekEpoch;

            try {
              final loaded = await _setClipsForGeneration(
                generation,
                _videoPlayer,
                [
                  ..._buildPlayerClips(state.clips),
                ],
                startPosition: _timelineToPlayer(startPosition),
              );
              if (!loaded) return;
              if (mounted) {
                VideoEditorCanvas.syncPositionAfterTrimRelease(
                  mainBloc: bloc,
                  proVideoController: _proVideoController,
                  startPosition: startPosition,
                  trimEndAlreadyDispatched: trimEndPosition != null,
                );
              }
            } finally {
              _lastReportedPosition = startPosition;
              _pendingSeekTarget = startPosition;
              if (_seekEpoch == ownerEpoch) {
                _isSeeking = false;
              }
            }
          },
        ),
        // Persist clip volume changes to the ProImageEditor undo history.
        // Both this listener and the audioTracksRevision listener above
        // call _scheduleVolumeHistoryWrite, which coalesces concurrent
        // revision bumps (e.g. mute-all toggle) into a single combined undo
        // point instead of two separate entries.
        BlocListener<ClipEditorBloc, ClipEditorState>(
          listenWhen: (previous, current) =>
              previous.clipsVolumeRevision != current.clipsVolumeRevision,
          listener: (context, state) {
            _scheduleVolumeHistoryWrite();
          },
        ),
        BlocListener<VideoEditorMainBloc, VideoEditorMainState>(
          listenWhen: (previous, current) =>
              previous.isExternalPauseRequested !=
              current.isExternalPauseRequested,
          listener: (context, state) {
            _onExternalPauseChanged(isPaused: state.isExternalPauseRequested);
          },
        ),
        BlocListener<VideoEditorMainBloc, VideoEditorMainState>(
          listenWhen: (previous, current) =>
              previous.playbackRestartCounter != current.playbackRestartCounter,
          listener: (context, state) {
            _onPlaybackRestartRequested();
          },
        ),
        BlocListener<VideoEditorMainBloc, VideoEditorMainState>(
          listenWhen: (previous, current) =>
              previous.playbackToggleCounter != current.playbackToggleCounter,
          listener: (context, state) {
            _onPlaybackToggleRequested();
          },
        ),
        BlocListener<VideoEditorMainBloc, VideoEditorMainState>(
          listenWhen: (previous, current) =>
              previous.seekCounter != current.seekCounter,
          listener: (context, state) {
            _onSeekRequested(state.seekPosition);
          },
        ),
      ],
      // The interactive affordances live in our own overlays, which are
      // scaffold siblings of this canvas, so excluding this subtree costs a
      // screen reader nothing it cannot reach elsewhere. Two things inside it
      // are labelled, and both have an equivalent outside:
      //
      //  - Sticker layers. addLayer puts our own VideoEditorSticker in here
      //    (video_editor_screen.dart), and it carries a Semantics label; the
      //    stickerWidgetLoader rebuilds it on draft reopen. The timeline strip
      //    announces the same description, pinned by
      //    video_editor_timeline_positioned_item_test.dart.
      //  - The package's own Tooltip-labelled layer buttons, on desktop web
      //    only: layerInteraction.selectable defaults to `auto`, which resolves
      //    to `isDesktop`, so they never build on iOS or Android. Where they do,
      //    the timeline controls carry the same delete action.
      //
      // Re-check that before enabling videoEditor.showControls, returning a real
      // widget from any appBar / bottomBar slot, pinning selectable to enabled,
      // or putting a labelled widget in bodyItems or a layer — each can add a
      // control here with no equivalent outside. No test can catch it for you:
      // mounting the editor needs a live video pipeline.
      child: ExcludeSemantics(
        child: ProImageEditor.video(
          _proVideoController,
          key: scope.editorKey,
          configs: ProImageEditorConfigs(
            theme: Theme.of(context),
            stateHistory: StateHistoryConfigs(
              initStateHistory: editorStateHistory.isNotEmpty
                  ? .fromMap(
                      editorStateHistory,
                      configs: const ImportEditorConfigs(
                        widgetLoader: videoEditorWidgetLayerLoader,
                      ),
                    )
                  : null,
            ),
            imageGeneration: ImageGenerationConfigs(
              captureImageByteFormat: .rawStraightRgba,
              outputFormat: .png,
              enableBackgroundGeneration: false,
              enableUseOriginalBytes: false,
              // Disabled in debug mode: combined RAM usage from the editor
              // and MediaKit (background) causes crashes on hot-reload.
              // Release builds are unaffected.
              enableIsolateGeneration: kReleaseMode,
              processorConfigs: const ProcessorConfigs(
                numberOfBackgroundProcessors: 3,
                processorMode: .limit,
                initializationDelay:
                    VideoEditorConstants.isolatesInitialisationDelay,
              ),
              customPixelRatio: max(
                1,
                max(
                  VideoEditorConstants.quality.resolution.height /
                      widget.renderSize.height,
                  VideoEditorConstants.quality.resolution.width /
                      widget.renderSize.width,
                ),
              ),
            ),
            mainEditor: MainEditorConfigs(
              enableZoom: true,
              interactiveViewerClipBehavior: .none,
              safeArea: const EditorSafeArea.none(),
              style: MainEditorStyle(
                uiOverlayStyle: VideoEditorConstants.uiOverlayStyleFor(
                  context.vineColors,
                ),
                background: context.vineColors.surfaceContainerHigh,
              ),
              captureLayersOnDone: true,
              captureImageOnDone: false,
              widgets: MainEditorWidgets(
                appBar: (_, _) => null,
                bottomBar: (_, _, key) => null,
                removeLayerArea: (key, _, _, _) => SizedBox.shrink(key: key),
                bodyItems: (editor, rebuildStream) {
                  return [
                    ReactiveWidget(
                      builder: (context) =>
                          BlocSelector<
                            VideoEditorMainBloc,
                            VideoEditorMainState,
                            ({
                              bool isOver,
                              bool isReordering,
                              bool isSubEditorOpen,
                            })
                          >(
                            selector: (state) => (
                              isOver:
                                  state.currentPosition.inMilliseconds >
                                  VideoEditorConstants
                                      .maxDuration
                                      .inMilliseconds,
                              isReordering: state.isReordering,
                              isSubEditorOpen: state.isSubEditorOpen,
                            ),
                            builder: (context, record) {
                              if (!record.isOver ||
                                  record.isReordering ||
                                  record.isSubEditorOpen) {
                                return const SizedBox.shrink();
                              }
                              return IgnorePointer(
                                child: ColoredBox(
                                  color: context.vineColors.background
                                      .withAlpha(
                                        128,
                                      ),
                                  child: const SizedBox.expand(),
                                ),
                              );
                            },
                          ),
                      stream: rebuildStream,
                    ),
                    ReactiveWidget(
                      builder: (context) => VideoEditorFeedPreviewOverlay(
                        targetAspectRatio: targetAspectRatio.value,
                        isFeedPreviewVisible: editor.isLayerBeingTransformed,
                      ),
                      stream: rebuildStream,
                    ),
                  ];
                },
              ),
            ),
            paintEditor: PaintEditorConfigs(
              eraserSize:
                  DrawToolType.eraser.config.strokeWidth /
                  scope.fittedBoxScale /
                  2,
              safeArea: const EditorSafeArea.none(),
              enableEdit: false,
              style: PaintEditorStyle(
                background: context.vineColors.surfaceContainerHigh,
              ),
              widgets: PaintEditorWidgets(
                appBar: (_, _) => null,
                bottomBar: (_, _) => null,
                colorPicker: (_, _, _, _) => null,
              ),
            ),
            filterEditor: FilterEditorConfigs(
              safeArea: const EditorSafeArea.none(),
              enableMultiSelection: false,
              style: FilterEditorStyle(
                background: context.vineColors.surfaceContainerHigh,
              ),
              widgets: FilterEditorWidgets(
                appBar: (_, _) => null,
                bottomBar: (_, _) => null,
              ),
            ),
            tuneEditor: TuneEditorConfigs(
              safeArea: const EditorSafeArea.none(),
              tuneAdjustmentOptions: VideoEditorConstants.tuneAdjustments,
              style: TuneEditorStyle(
                background: context.vineColors.surfaceContainerHigh,
              ),
              widgets: TuneEditorWidgets(
                appBar: (_, _) => null,
                bottomBar: (_, _) => null,
              ),
            ),
            helperLines: HelperLineConfigs(
              style: HelperLineStyle(
                // 1.25 is the pro_image_editor default; we divide by fittedBoxScale
                // to compensate for the FittedBox transformation.
                strokeWidth: 1.25 / scope.fittedBoxScale,
                horizontalColor: VideoEditorConstants.primaryColor,
                verticalColor: VideoEditorConstants.primaryColor,
                rotateColor: VideoEditorConstants.primaryColor,
                layerAlignColor: VideoEditorConstants.primaryColor,
              ),
            ),
            dialogConfigs: DialogConfigs(
              widgets: DialogWidgets(
                loadingDialog: (message, configs) => const SizedBox.shrink(),
              ),
            ),
            videoEditor: VideoEditorConfigs(
              showControls: false,
              widgets: VideoEditorWidgets(
                videoSetupLoadingIndicator: VideoEditorSetupLoadingIndicator(
                  renderSize: widget.renderSize,
                  bodySize: widget.bodySize,
                  targetAspectRatio: targetAspectRatio,
                ),
              ),
            ),
          ),
          callbacks: ProImageEditorCallbacks(
            onCompleteWithParameters: _handleEditorComplete,
            mainEditorCallbacks: MainEditorCallbacks(
              onEditorZoomMatrix4Change: (matrix) =>
                  scope.zoomMatrixNotifier.value = matrix,
              onAfterViewInit: () {
                _isInitialized = true;

                if (editorStateHistory.isEmpty) {
                  final clips = ref.read(clipManagerProvider).clips;
                  final editorState = ref.read(videoEditorProvider);
                  final selectedSound = editorState.selectedSound;
                  final shouldSeedSelectedSound =
                      VideoEditorCanvas.shouldSeedSelectedSoundAsAudioTrack(
                        hasSelectedSound: selectedSound != null,
                        seedSelectedSoundAsAudioTrack:
                            editorState.seedSelectedSoundAsAudioTrack,
                      );

                  scope.requireEditor.stateManager.replaceHistory(
                    scope.requireEditor.stateHistory.first.copyWith(
                      meta: {
                        ...scope.requireEditor.stateManager.activeMeta,
                        VideoEditorConstants.clipsStateHistoryKey: clips
                            .map((e) => e.toJson())
                            .toList(),
                        // Lip-sync: the recorder picked a sound the clips were
                        // recorded against (and muted on handoff). Seed it as the
                        // timeline's audio track only when the recorder marked
                        // this as a handoff, not for every selected editor/draft
                        // sound. The editor re-clamps the window to the real
                        // video duration on the next
                        // TimelineOverlayTotalDurationChanged.
                        if (shouldSeedSelectedSound)
                          VideoEditorConstants.audioStateHistoryKey: [
                            selectedSound!
                                .copyWith(
                                  id:
                                      '${selectedSound.id}-'
                                      '${DateTime.now().millisecondsSinceEpoch}',
                                  startTime: Duration.zero,
                                  endTime: _lipSyncAudioEndTime(
                                    selectedSound.duration,
                                  ),
                                )
                                .toJson(),
                          ],
                      },
                    ),
                    index: 0,
                  );
                }

                _syncMainCapabilities(scope, bloc);
              },
              onDone: _handleDone,
              onImportHistoryStart: (state, import) {
                Log.debug(
                  '🎬 Importing history started',
                  name: 'VideoEditorCanvas',
                  category: LogCategory.video,
                );
                _isImportingHistory = true;
              },
              onImportHistoryEnd: (state, import) {
                Log.debug(
                  '🎬 Importing history completed',
                  name: 'VideoEditorCanvas',
                  category: LogCategory.video,
                );
                _isImportingHistory = false;
                _syncMainCapabilities(scope, bloc);
              },
              onStateHistoryChange: (_, _) =>
                  _onStateHistoryChange(scope, bloc),
              onOpenSubEditor: (editorMode) {
                Log.debug(
                  '🎬 Opening sub-editor: $editorMode',
                  name: 'VideoEditorCanvas',
                  category: LogCategory.video,
                );
                final SubEditorType? subEditorType = switch (editorMode) {
                  .paint => .draw,
                  .text => .text,
                  .filter => .filter,
                  .tune => .tune,
                  .sticker => .stickers,
                  _ => null,
                };
                if (subEditorType != null) {
                  bloc.add(VideoEditorMainOpenSubEditor(subEditorType));
                }
              },
              onStartCloseSubEditor: (_) {
                Log.debug(
                  '🎬 Closing sub-editor',
                  name: 'VideoEditorCanvas',
                  category: LogCategory.video,
                );
                bloc.add(const VideoEditorMainSubEditorClosed());
              },
              onScaleStart: (_) {
                Log.debug(
                  '🎬 Layer interaction started',
                  name: 'VideoEditorCanvas',
                  category: LogCategory.video,
                );
                bloc.add(const VideoEditorLayerInteractionStarted());
                _selectedLayer = scope.editor?.selectedLayer;
              },
              onScaleUpdate: (details) {
                if (!_isLayerBeingTransformed) return;
                final isOverRemoveArea = scope.isOverRemoveArea(
                  details.focalPoint,
                );

                // Trigger haptic feedback when entering the remove area
                if (isOverRemoveArea && !_wasOverRemoveArea) {
                  unawaited(HapticService.destructiveZoneFeedback());
                }
                _wasOverRemoveArea = isOverRemoveArea;

                bloc.add(
                  VideoEditorLayerOverRemoveAreaChanged(
                    isOver: isOverRemoveArea,
                  ),
                );
              },
              onScaleEnd: (_) {
                if (_isLayerBeingTransformed) {
                  final removed = _selectedLayer;
                  final captionCueId =
                      bloc.state.isLayerOverRemoveArea && removed != null
                      ? captionCueIdOf(removed)
                      : null;

                  if (captionCueId != null) {
                    // Burn-in caption: drop the cue and its layer together in one
                    // history step, so the track meta and the exported video stay
                    // consistent (never leave an orphaned cue behind).
                    Log.debug(
                      '🎬 Caption layer removed via drag',
                      name: 'VideoEditorCanvas',
                      category: LogCategory.video,
                    );
                    scope.editor?.removeCaptionCue(captionCueId);
                  } else {
                    if (bloc.state.isLayerOverRemoveArea) {
                      Log.debug(
                        '🎬 Layer removed via drag',
                        name: 'VideoEditorCanvas',
                        category: LogCategory.video,
                      );
                      scope.editor?.activeLayers.remove(removed);
                    }
                    _onStateHistoryChange(scope, bloc);
                  }
                  _selectedLayer = null;
                }

                _wasOverRemoveArea = false;
                bloc.add(const VideoEditorLayerInteractionEnded());
              },
              onAddLayer: (layer) {
                Log.debug(
                  '🎬 Layer added: ${layer.runtimeType}',
                  name: 'VideoEditorCanvas',
                  category: LogCategory.video,
                );
                _syncMainCapabilities(scope, bloc);
              },
              onRemoveLayer: (layer) {
                Log.debug(
                  '🎬 Layer removed: ${layer.runtimeType}',
                  name: 'VideoEditorCanvas',
                  category: LogCategory.video,
                );
                _syncMainCapabilities(scope, bloc);
              },
              onRedo: () => _syncMainCapabilities(
                scope,
                bloc,
                direction: ClipHistoryDirection.redo,
              ),
              onUndo: () => _syncMainCapabilities(
                scope,
                bloc,
                direction: ClipHistoryDirection.undo,
              ),
              onCreateTextLayer: scope.onAddEditTextLayer,
              // Burned-in caption layers are edited through the captions sheet,
              // not the text editor: tapping one on the canvas must not reopen
              // it as a plain text layer.
              onEditTextLayer: (layer) async => isCaptionCueLayer(layer)
                  ? null
                  : scope.onAddEditTextLayer(layer),
              helperLines: HelperLinesCallbacks(
                onLineHit: () => unawaited(HapticService.snapFeedback()),
              ),
            ),
            paintEditorCallbacks: PaintEditorCallbacks(
              onInit: () {
                drawBloc.add(const VideoEditorDrawReset());

                final paintEditor = scope.paintEditor;
                final drawState = context.read<VideoEditorDrawBloc>().state;
                final toolConfig = drawState.selectedTool.config;
                // Sync editor with current BLoC state - use tool config for
                // strokeWidth/opacity/mode to ensure consistency with tool switch
                paintEditor
                  ?..setColor(drawState.selectedColor)
                  ..setStrokeWidth(
                    toolConfig.strokeWidth / scope.fittedBoxScale,
                  )
                  ..setOpacity(toolConfig.opacity)
                  ..setMode(toolConfig.mode);
              },
              onDrawingDone: () => _syncDrawCapabilities(scope, drawBloc),
              onRedo: () => _syncDrawCapabilities(scope, drawBloc),
              onUndo: () => _syncDrawCapabilities(scope, drawBloc),
            ),
            filterEditorCallbacks: FilterEditorCallbacks(
              onInit: () {
                final filterBloc = context.read<VideoEditorFilterBloc>();
                filterBloc.add(const VideoEditorFilterEditorInitialized());
              },
            ),
            tuneEditorCallbacks: TuneEditorCallbacks(
              // A new session starts neutral; an edit session seeds the bottom-bar
              // sliders from the set being edited. See TuneSet.sessionSeed and
              // VideoEditorTuneOverlayControls._commit.
              onInit: () {
                final tuneBloc = context.read<VideoEditorTuneBloc>();
                tuneBloc.add(
                  VideoEditorTuneEditorInitialized(
                    TuneSet.sessionSeed(
                      scope.editor?.stateManager.activeTuneAdjustments ??
                          const [],
                      tuneBloc.state.editingSetId,
                    ),
                  ),
                );
              },
              // The editor seeds its own preview neutral (set members carry unique
              // ids, not preset ids), so seed the live preview from the edited set
              // once the view is up.
              onAfterViewInit: () => _seedTuneEditorPreview(
                scope,
                context.read<VideoEditorTuneBloc>().state.editingSetId,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CanvasFitter extends ConsumerWidget {
  const _CanvasFitter({required this.builder});

  final Widget Function(Size bodySize, Size renderSize) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clip = ref.watch(
      clipManagerProvider.select((s) => s.firstClipOrNull),
    );
    if (clip == null) return const SizedBox.shrink();
    final scope = VideoEditorScope.of(context);

    return LayoutBuilder(
      builder: (_, constraints) {
        final bodySize = constraints.biggest;

        // The one model of the canvas mapping. Layer compensation reads the
        // same geometry through VideoEditorScope.calculateFittedBoxScale.
        final geometry = VideoEditorCanvasGeometry(
          bodySize: bodySize,
          originalAspectRatio: clip.originalAspectRatio,
          targetAspectRatio: clip.targetAspectRatio.value,
        );

        // Notify parent about body size
        scope.bodySizeNotifier.value = bodySize;

        // [VideoEditorCanvasFit] owns the aspect-ratio mapping: cover-fit
        // the render surface into the visible target area, centered in
        // [bodySize].
        //
        // [HitTestExpander] wraps it so that taps in the scrim /
        // letterbox zone (outside the target area) are clamped to the
        // nearest point inside it and re-dispatched into the chain.
        // Without this, `Center.hitTestChildren` drops every pointer event
        // that falls outside its child rect, so the editor's top-level
        // GestureDetector never opens an arena and [onScaleStart] /
        // [onScaleUpdate] never fire.
        return KeyedSubtree(
          // Marks this box — the canvas body — so a tool laid over the editor
          // can map a touch back into layer coordinates.
          key: scope.canvasBodyKey,
          child: VideoEditorCutAreaOverlay(
            child: HitTestExpander(
              visibleSize: geometry.targetSize,
              child: VideoEditorCanvasFit(
                geometry: geometry,
                child: Navigator(
                  clipBehavior: Clip.none,
                  onGenerateRoute: (_) => PageRouteBuilder(
                    pageBuilder: (_, _, _) =>
                        builder(bodySize, geometry.renderSize),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
