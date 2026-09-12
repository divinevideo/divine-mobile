import 'dart:async';

import 'package:clock/clock.dart';
import 'package:divine_video_player/divine_video_player.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_feed_item/center_playback_control.dart';
import 'package:openvine/widgets/video_feed_item/feed_playback_toggles_pill.dart';

class PausedVideoOverlay extends StatefulWidget {
  const PausedVideoOverlay({
    required this.controller,
    required this.videoId,
    this.isVisible = true,
    super.key,
  });

  final DivineVideoPlayerController controller;
  final String videoId;
  final bool isVisible;

  @override
  State<PausedVideoOverlay> createState() => _PausedVideoOverlayState();
}

class _PausedVideoOverlayState extends State<PausedVideoOverlay>
    with SingleTickerProviderStateMixin {
  StreamSubscription<DivineVideoPlayerState>? _subscription;

  /// Latching flag: set once this player emits a [PlaybackStatus.playing]
  /// state while [PausedVideoOverlay.isVisible] is true.  Reset when
  /// [DivineVideoPlayerState.isFirstFrameRendered] becomes false (new
  /// clips loaded), so a swipe to a fresh video never inherits the
  /// latch from the previous playback session.
  bool _hasStartedPlaying = false;

  /// Previous paused state used to detect paused -> playing transitions.
  bool _previouslyPaused = false;

  /// Pause edge timestamp used to filter short loop-restart blips.
  DateTime? _pausedAt;

  /// Whether the transient unpause pause-icon is currently visible.
  bool _showUnpauseFeedback = false;

  /// Pending promotion of a stable visible-paused state to "started".
  /// Used to suppress the brief paused-frame flash that can be emitted
  /// during a swipe to the next video.
  Timer? _stablePauseTimer;

  late final AnimationController _unpauseFeedbackController;
  late final Animation<double> _unpauseFeedbackOpacity;

  static const _unpauseFadeStartDelay = Duration(milliseconds: 50);
  static const _unpauseHideDelay = Duration(milliseconds: 550);
  static const _minPauseForFeedback = Duration(milliseconds: 150);
  static const _stablePauseDelay = Duration(milliseconds: 300);

  @override
  void initState() {
    super.initState();
    _unpauseFeedbackController =
        AnimationController(vsync: this, duration: _unpauseHideDelay)
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed && mounted) {
              setState(() {
                _showUnpauseFeedback = false;
              });
            }
          });
    _unpauseFeedbackOpacity = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(
        parent: _unpauseFeedbackController,
        curve: Interval(
          _unpauseFadeStartDelay.inMilliseconds /
              _unpauseHideDelay.inMilliseconds,
          1,
        ),
      ),
    );
    _subscribe();
  }

  @override
  void didUpdateWidget(covariant PausedVideoOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      unawaited(_subscription?.cancel());
      _cancelUnpauseFeedbackTimers();
      _stablePauseTimer?.cancel();
      _stablePauseTimer = null;
      _hasStartedPlaying = false;
      _previouslyPaused = false;
      _pausedAt = null;
      _showUnpauseFeedback = false;
      _unpauseFeedbackController.stop();
      _unpauseFeedbackController.value = 0;
      _subscribe();
      return;
    }
    // Reset the latch on visibility transitions so the overlay doesn't
    // flash when swiping back to an already-loaded video that is briefly
    // paused before playback resumes.
    if (oldWidget.isVisible != widget.isVisible) {
      _stablePauseTimer?.cancel();
      _stablePauseTimer = null;
      if (_hasStartedPlaying) {
        setState(() => _hasStartedPlaying = false);
      }
    }
  }

  void _subscribe() {
    _subscription = widget.controller.stateStream.listen(_onState);
  }

  void _onState(DivineVideoPlayerState state) {
    if (!mounted) return;

    final isPaused = state.isPaused;
    final wasPaused = _previouslyPaused;
    _previouslyPaused = isPaused;

    if (!state.isFirstFrameRendered) {
      // New video loading — reset so the latch must be re-earned.
      if (_hasStartedPlaying || _showUnpauseFeedback) {
        _cancelUnpauseFeedbackTimers();
        setState(() {
          _hasStartedPlaying = false;
          _showUnpauseFeedback = false;
        });
      }
      _pausedAt = null;
      _stablePauseTimer?.cancel();
      _stablePauseTimer = null;
      return;
    }

    if (state.status == PlaybackStatus.playing &&
        widget.isVisible &&
        !_hasStartedPlaying) {
      _stablePauseTimer?.cancel();
      _stablePauseTimer = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _hasStartedPlaying = true;
      });
    }

    // Suppress the brief paused-frame flash emitted when a new video
    // becomes visible: only promote a
    // visible-paused state to "showable" after it has been stable for
    // [_stablePauseDelay]. A real user-paused video sits in this state
    // long enough to be promoted; a swipe transition resolves to
    // playing before the timer fires.
    if (isPaused && widget.isVisible && !_hasStartedPlaying) {
      _stablePauseTimer ??= Timer(_stablePauseDelay, () {
        _stablePauseTimer = null;
        if (!mounted) return;
        final current = widget.controller.state;
        if (!widget.isVisible ||
            !current.isPaused ||
            !current.isFirstFrameRendered) {
          return;
        }
        setState(() => _hasStartedPlaying = true);
      });
    } else if (!isPaused) {
      _stablePauseTimer?.cancel();
      _stablePauseTimer = null;
    }

    if (isPaused && !wasPaused) {
      _pausedAt = clock.now();
      return;
    }

    if (!isPaused && wasPaused && _hasStartedPlaying && widget.isVisible) {
      final pauseDuration = _pausedAt != null
          ? clock.now().difference(_pausedAt!)
          : Duration.zero;
      _pausedAt = null;
      if (pauseDuration >= _minPauseForFeedback) {
        _triggerUnpauseFeedback();
      }
    }
  }

  void _triggerUnpauseFeedback() {
    _cancelUnpauseFeedbackTimers();
    setState(() {
      _showUnpauseFeedback = true;
    });
    _unpauseFeedbackController
      ..stop()
      ..value = 0
      ..forward();
  }

  void _cancelUnpauseFeedbackTimers() {
    _unpauseFeedbackController.stop();
    _unpauseFeedbackController.value = 0;
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    _cancelUnpauseFeedbackTimers();
    _stablePauseTimer?.cancel();
    _stablePauseTimer = null;
    _unpauseFeedbackController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<
      ({
        bool isBuffering,
        bool isFirstFrameRendered,
        bool isPaused,
        bool isPlaying,
      })
    >(
      stream: widget.controller.stateStream
          .map(
            (s) => (
              isBuffering: s.isBuffering,
              isPaused: s.isPaused,
              isPlaying: s.isPlaying,
              isFirstFrameRendered: s.isFirstFrameRendered,
            ),
          )
          .distinct(),
      builder: (context, snapshot) {
        final isBuffering = snapshot.data?.isBuffering ?? false;
        final isFirstFrameRendered =
            snapshot.data?.isFirstFrameRendered ?? false;
        final isPaused = snapshot.data?.isPaused ?? false;
        final isPlaying = snapshot.data?.isPlaying ?? false;

        final shouldShow =
            widget.isVisible &&
            _hasStartedPlaying &&
            isPaused &&
            !isBuffering &&
            isFirstFrameRendered;
        final shouldShowUnpauseFeedback =
            widget.isVisible &&
            _showUnpauseFeedback &&
            isPlaying &&
            !shouldShow;

        final Widget child;
        if (shouldShow) {
          child = Center(
            key: const ValueKey('paused-playback-controls'),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FeedPlaybackTogglesPill(videoId: widget.videoId),
                const SizedBox(height: 16),
                IgnorePointer(
                  child: CenterPlaybackControl(
                    state: CenterPlaybackControlState.play,
                    semanticsLabel: context.l10n.videoPlayerPlayVideo,
                  ),
                ),
              ],
            ),
          );
        } else if (shouldShowUnpauseFeedback) {
          child = IgnorePointer(
            child: FadeTransition(
              opacity: _unpauseFeedbackOpacity,
              child: const CenterPlaybackControl(
                state: CenterPlaybackControlState.pause,
              ),
            ),
          );
        } else {
          child = const SizedBox.shrink();
        }

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.92, end: 1).animate(animation),
                child: child,
              ),
            );
          },
          child: child,
        );
      },
    );
  }
}
