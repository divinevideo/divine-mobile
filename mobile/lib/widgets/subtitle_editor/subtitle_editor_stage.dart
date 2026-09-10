// ABOUTME: Video preview plus cue timeline for the subtitle editor, owning the
// ABOUTME: player and filmstrip both of them read from.

import 'dart:async';
import 'dart:io';

import 'package:divine_ui/divine_ui.dart';
import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:infinite_video_feed/infinite_video_feed.dart';
import 'package:openvine/blocs/subtitle_editor/subtitle_editor_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/subtitle_editor/timeline_frame.dart';
import 'package:openvine/widgets/caption_pill.dart';
import 'package:openvine/widgets/subtitle_editor/subtitle_cue_timeline.dart';
import 'package:unified_logger/unified_logger.dart';

/// Loads the preview player's candidate sources into [controller].
@visibleForTesting
typedef SubtitlePreviewSourceLoader = Future<void> Function({
  required DivineVideoPlayerController controller,
  required List<String> sources,
  required void Function(String message) log,
  required bool Function() isLoadCurrent,
});

/// Initializes the preview player controller before source loading.
@visibleForTesting
typedef SubtitlePreviewControllerInitializer = Future<void> Function(
  DivineVideoPlayerController controller,
);

Future<void> _initializeSubtitlePreviewController(
  DivineVideoPlayerController controller,
) async {
  await controller.initialize();
}

/// The preview's own [SubtitlePreviewSourceLoader], used when none is injected.
@visibleForTesting
Future<void> loadSubtitlePreviewSources({
  required DivineVideoPlayerController controller,
  required List<String> sources,
  required void Function(String message) log,
  required bool Function() isLoadCurrent,
}) async {
  await setSourceWithFallbacks(
    index: 0,
    controller: controller,
    sources: sources,
    log: log,
    isLoadCurrent: isLoadCurrent,
    // Preserve the editor's pre-feed-policy behavior: an alternate rendition
    // may still decode even when the first candidate does not.
    applyTypedFailoverPolicy: false,
    // The feed trims the loop seam; the editor cannot. Its timeline is drawn
    // from the container duration, so a clamp to the shorter of the two tracks
    // would put the last half-second of the axis out of the preview's reach —
    // and a cue timed into it could never be watched against the picture.
    trimToCommonTrackEnd: false,
  );
}

/// The video being captioned, with its cues laid out on a timeline beneath it.
///
/// Owns the player: the timeline scrubs it, playback moves the timeline, and
/// the preview shows the cue that is live at the current position — so a
/// caption is timed against the picture instead of against numbers.
class SubtitleEditorStage extends StatefulWidget {
  /// Creates the stage.
  const SubtitleEditorStage({
    required this.videoUrl,
    required this.videoId,
    required this.cues,
    required this.totalDuration,
    required this.selectedCue,
    required this.loadFrames,
    required this.playbackUrls,
    this.initializePreviewController,
    this.loadPreviewSources,
    super.key,
  });

  /// Playable URL of the published video.
  ///
  /// Addresses the video itself — the filmstrip reads frames from it. The
  /// preview player uses [playbackUrls] instead, which may resolve to a
  /// different rendition of the same video.
  final String videoUrl;

  /// Ordered playback candidates for the preview player, tried in order.
  ///
  /// Build these with `VideoEvent.previewPlaybackSources` so the editor and
  /// the feed pick renditions the same way. The preview runs them through the
  /// feed's source loader, minus its loop-seam trim: playback has to reach the
  /// end of the timeline the cues are laid out on.
  final List<String> playbackUrls;

  /// Loads [playbackUrls] into the preview player.
  @visibleForTesting
  final SubtitlePreviewSourceLoader? loadPreviewSources;

  /// Initializes the preview player controller.
  @visibleForTesting
  final SubtitlePreviewControllerInitializer? initializePreviewController;

  /// Full event id of the video, used as the media-cache key.
  final String videoId;

  /// Cues to lay out, in list order.
  final List<EditableCue> cues;

  /// Length of the time axis.
  final Duration totalDuration;

  /// The cue the creator is working on, or `null`.
  ///
  /// Selecting one jumps the preview to where it starts, so the frame the
  /// caption lands on is on screen while its timing is edited.
  final EditableCue? selectedCue;

  /// Supplies the timeline's filmstrip.
  final TimelineFrameLoader loadFrames;

  /// Player reports this close to a pending seek have converged on the target.
  @visibleForTesting
  static const seekSettleTolerance = Duration(milliseconds: 120);

  /// Whether a player position [report] may move the subtitle playhead.
  ///
  /// Native position reports can arrive after a newer scrub has already pinned
  /// the UI to its target. While playback is paused and a seek is pending, only
  /// accept reports that have settled near that target.
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

  @override
  State<SubtitleEditorStage> createState() => _SubtitleEditorStageState();
}

class _SubtitleEditorStageState extends State<SubtitleEditorStage>
    with SingleTickerProviderStateMixin {
  final ValueNotifier<Duration> _position = ValueNotifier(Duration.zero);
  final ValueNotifier<List<TimelineFrame>> _thumbnails = ValueNotifier(
    const [],
  );

  DivineVideoPlayerController? _controller;
  StreamSubscription<DivineVideoPlayerState>? _playerStates;
  StreamSubscription<List<TimelineFrame>>? _thumbnailBatches;

  /// Drives the playhead between position events.
  ///
  /// The player reports its position a few times a second, which is far too
  /// coarse to scroll a timeline with — following it directly makes the film
  /// stutter. The ticker advances the last reported position by real elapsed
  /// time every frame, and each new report re-anchors it.
  late final Ticker _playhead;
  Duration _reportedPosition = Duration.zero;
  Duration _reportedAt = Duration.zero;
  Duration _tickerElapsed = Duration.zero;

  bool _isPlaying = false;
  bool _failed = false;
  double _aspectRatio = 9 / 16;
  Duration? _pendingSeekTarget;

  @override
  void initState() {
    super.initState();
    // Built here rather than lazily: a `late` ticker first touched in dispose
    // would be created against a deactivated element.
    _playhead = createTicker(_onPlayheadTick);
    unawaited(_openPlayer());
  }

  @override
  void didUpdateWidget(SubtitleEditorStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final selected = widget.selectedCue;
    if (selected == null || selected.start == oldWidget.selectedCue?.start) {
      return;
    }
    _seekTo(Duration(milliseconds: selected.start));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _thumbnailBatches ??= widget
        .loadFrames(
          videoUrl: widget.videoUrl,
          videoId: widget.videoId,
          duration: widget.totalDuration,
          devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
        )
        .listen(
          _replaceThumbnails,
          // The loader is injected, so its no-error contract cannot be
          // enforced from here. Frames are decoration: keep the ones that
          // arrived rather than letting the failure reach the zone handler.
          onError: (Object error, StackTrace _) => Log.warning(
            'Could not load frames for the subtitle timeline: $error',
            name: 'SubtitleEditorStage',
            category: LogCategory.video,
          ),
        );
  }

  void _onPlayheadTick(Duration elapsed) {
    _tickerElapsed = elapsed;
    final projected = _reportedPosition + (elapsed - _reportedAt);
    _position.value = projected < widget.totalDuration
        ? projected
        : widget.totalDuration;
  }

  void _anchorPlayhead(Duration position) {
    _reportedPosition = position;
    _reportedAt = _tickerElapsed;
    _position.value = position;
  }

  void _replaceThumbnails(List<TimelineFrame> batch) {
    final nextPaths = {for (final frame in batch) frame.path};
    _deleteFrames([
      for (final frame in _thumbnails.value)
        if (!nextPaths.contains(frame.path)) frame,
    ]);
    _thumbnails.value = batch;
  }

  static void _deleteFrames(List<TimelineFrame> frames) {
    for (final frame in frames) {
      try {
        final file = File(frame.path);
        if (file.existsSync()) file.deleteSync();
      } catch (error) {
        Log.debug(
          'Could not delete subtitle timeline frame ${frame.path}: $error',
          name: 'SubtitleEditorStage',
          category: LogCategory.video,
        );
      }
    }
  }

  @override
  void dispose() {
    _playhead.dispose();
    unawaited(_playerStates?.cancel());
    unawaited(_thumbnailBatches?.cancel());
    unawaited(_controller?.dispose());
    _deleteFrames(_thumbnails.value);
    _position.dispose();
    _thumbnails.dispose();
    super.dispose();
  }

  Future<void> _openPlayer() async {
    // Handed to the player as-is: an HLS master playlist is a source it takes
    // natively on both platforms, so resolving one to an MP4 first would only
    // buy a round-trip and a downgrade to the lowest-bandwidth variant.
    final urls = orderedUniqueSources(widget.playbackUrls);
    if (urls.isEmpty) {
      // Reached synchronously from initState, before the first build, so the
      // flag is picked up without a setState that would mark a building
      // element dirty.
      _failed = true;
      return;
    }

    final controller = DivineVideoPlayerController(
      useTexture: true,
      debugLabel: 'subtitle_editor',
    );
    try {
      final initializePreviewController =
          widget.initializePreviewController ??
          _initializeSubtitlePreviewController;
      await initializePreviewController(controller);
      final loadPreviewSources =
          widget.loadPreviewSources ?? loadSubtitlePreviewSources;
      await loadPreviewSources(
        controller: controller,
        sources: urls,
        isLoadCurrent: () => mounted,
        log: (message) => Log.debug(
          message,
          name: 'SubtitleEditorStage',
          category: LogCategory.video,
        ),
      );
      if (!mounted) {
        await controller.dispose();
        return;
      }
      await controller.setLooping(looping: true);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      _playerStates = controller.stateStream.listen(_onPlayerState);
      setState(() => _controller = controller);
      // Started only once the surface is mounted, so the first decoded frame
      // has somewhere to land. A player that never plays never decodes one,
      // and the preview would sit on its placeholder forever.
      await controller.play();
    } on SourceLoadAborted catch (error) {
      Log.debug(
        'Subtitle editor preview source load cancelled: $error',
        name: 'SubtitleEditorStage',
        category: LogCategory.video,
      );
      unawaited(_playerStates?.cancel());
      _playerStates = null;
      unawaited(controller.dispose());
    } on Object catch (error) {
      // Without this the failure would be an unhandled async error and the
      // preview would show an unexplained black box.
      Log.warning(
        'Could not play the video being captioned: $error',
        name: 'SubtitleEditorStage',
        category: LogCategory.video,
      );
      unawaited(_playerStates?.cancel());
      _playerStates = null;
      unawaited(controller.dispose());
      if (!mounted) return;
      setState(() {
        _controller = null;
        _failed = true;
      });
    }
  }

  void _onPlayerState(DivineVideoPlayerState state) {
    final isPlaying = state.status == PlaybackStatus.playing;
    final reportAccepted = SubtitleEditorStage.shouldAcceptPlayerReport(
      report: state.position,
      seekTarget: _pendingSeekTarget,
      isPlaying: isPlaying,
    );
    if (isPlaying) {
      _pendingSeekTarget = null;
    } else if (reportAccepted) {
      _pendingSeekTarget = null;
    }
    if (reportAccepted) _anchorPlayhead(state.position);
    if (state.status == PlaybackStatus.error && !_failed) {
      Log.warning(
        'Video playback failed while captioning: ${state.errorMessage}',
        name: 'SubtitleEditorStage',
        category: LogCategory.video,
      );
      if (mounted) setState(() => _failed = true);
      return;
    }
    final ratio = state.videoHeight > 0
        ? state.videoWidth / state.videoHeight
        : _aspectRatio;
    if (isPlaying == _isPlaying && ratio == _aspectRatio) return;
    if (!mounted) return;
    // Only interpolate while the picture is actually moving; a paused playhead
    // must stay exactly where the last report put it.
    if (isPlaying && !_playhead.isActive) {
      _playhead.start();
    } else if (!isPlaying && _playhead.isActive) {
      _playhead.stop();
      _tickerElapsed = Duration.zero;
      _reportedAt = Duration.zero;
    }
    setState(() {
      _isPlaying = isPlaying;
      _aspectRatio = ratio;
    });
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;
    if (controller == null) return;
    await (_isPlaying ? controller.pause() : controller.play());
  }

  /// Moves the picture to [position] and holds it there.
  ///
  /// Both scrubbing and picking a cue land here: a moving picture under a
  /// dragged playhead makes the frame you are aiming at impossible to land on.
  void _seekTo(Duration position) {
    final controller = _controller;
    if (controller == null) return;
    if (_isPlaying) unawaited(controller.pause());
    _anchorPlayhead(position);
    _pendingSeekTarget = position;
    unawaited(controller.seekTo(position));
  }

  @override
  Widget build(BuildContext context) {
    // The timeline takes the height it needs; the preview lives on whatever
    // the enclosing screen left over, so a keyboard or a short screen shrinks
    // the picture rather than overflowing.
    return Column(
      children: [
        Expanded(
          child: _Preview(
            controller: _controller,
            hasFailed: _failed,
            aspectRatio: _aspectRatio,
            isPlaying: _isPlaying,
            position: _position,
            cues: widget.cues,
            onTogglePlayback: _togglePlayback,
          ),
        ),
        const SizedBox(height: 8),
        SubtitleCueTimeline(
          totalDuration: widget.totalDuration,
          playbackPosition: _position,
          thumbnails: _thumbnails,
          onScrubbed: _seekTo,
        ),
      ],
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({
    required this.controller,
    required this.hasFailed,
    required this.aspectRatio,
    required this.isPlaying,
    required this.position,
    required this.cues,
    required this.onTogglePlayback,
  });

  final DivineVideoPlayerController? controller;

  /// Whether the video could not be played at all.
  final bool hasFailed;

  final double aspectRatio;
  final bool isPlaying;
  final ValueListenable<Duration> position;
  final List<EditableCue> cues;
  final VoidCallback onTogglePlayback;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (hasFailed) {
      return ColoredBox(
        color: context.vineColors.surfaceContainerHigh,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              l10n.subtitleEditorPreviewUnavailable,
              textAlign: TextAlign.center,
              style: VineTheme.bodyMediumFont(
                color: context.vineColors.secondaryText,
              ),
            ),
          ),
        ),
      );
    }
    return Semantics(
      label: isPlaying
          ? l10n.subtitleEditorPausePreview
          : l10n.subtitleEditorPlayPreview,
      button: true,
      child: GestureDetector(
        onTap: onTogglePlayback,
        child: ColoredBox(
          color: context.vineColors.surfaceContainerHigh,
          child: Center(
            child: AspectRatio(
              aspectRatio: aspectRatio,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DivineVideoPlayer(
                    controller: controller,
                    placeholder: ColoredBox(
                      color: context.vineColors.surfaceContainerHigh,
                    ),
                  ),
                  _LiveCue(position: position, cues: cues),
                  if (!isPlaying)
                    Center(
                      // Duplicates the surrounding tap target on purpose: the
                      // whole picture toggles playback, this is what says so.
                      child: ExcludeSemantics(
                        child: DivineIconButton(
                          icon: .play,
                          type: .ghost,
                          semanticLabel: l10n.subtitleEditorPlayPreview,
                          onPressed: onTogglePlayback,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The cue that is live at the current position, drawn over the picture.
///
/// Reads the cues being edited rather than the published track, so a timing
/// change shows up here the moment it is made.
class _LiveCue extends StatelessWidget {
  const _LiveCue({required this.position, required this.cues});

  final ValueListenable<Duration> position;
  final List<EditableCue> cues;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Duration>(
      valueListenable: position,
      builder: (context, value, _) {
        final ms = value.inMilliseconds;
        final live = cues
            .where((cue) => ms >= cue.start && ms < cue.end)
            .where((cue) => cue.text.trim().isNotEmpty)
            .firstOrNull;
        if (live == null) return const SizedBox.shrink();
        return Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.all(16),
            // Silent to screen readers: the same text is announced by the
            // cue's own row below, and merging it here would garble the
            // preview's play/pause label.
            child: ExcludeSemantics(child: CaptionPill(text: live.text)),
          ),
        );
      },
    );
  }
}
