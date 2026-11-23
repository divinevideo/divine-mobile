import 'dart:async';

import 'package:divine_video_player/divine_video_player.dart';

/// Bundles the state-stream subscriptions the feed maintains per
/// active player controller (errors, auto-advance loop detection,
/// dimensions, first-frame).
///
/// Each `subscribeTo*` call cancels any prior subscription of the same
/// kind for that index. [unsubscribe] cancels all of them for one index;
/// [disposeAll] cancels every subscription.
class ControllerSubscriptions {
  final _dimensions = <int, StreamSubscription<DivineVideoPlayerState>>{};
  final _firstFrame = <int, StreamSubscription<DivineVideoPlayerState>>{};
  final _errors = <int, StreamSubscription<DivineVideoPlayerState>>{};
  final _errorChecks = <int, void Function()>{};
  final _autoAdvance = <int, StreamSubscription<DivineVideoPlayerState>>{};

  /// Subscribes to runtime playback errors. Calls [onError] with the
  /// structured [NativePlayerErrorCode] and raw message (both nullable) the
  /// first time the controller reports `state.hasError`, unless
  /// [isAlreadyError] returns `true` (the index is already in error state).
  void subscribeToPlaybackErrors(
    int index,
    DivineVideoPlayerController controller, {
    required bool Function() isAlreadyError,
    required void Function(
      NativePlayerErrorCode? errorCode,
      String? errorMessage,
    )
    onError,
  }) {
    unawaited(_errors[index]?.cancel());
    var handlingFailure = false;
    void observe(DivineVideoPlayerState state) {
      if (!state.hasError) {
        handlingFailure = false;
        return;
      }
      if (handlingFailure || isAlreadyError()) return;
      handlingFailure = true;
      onError(state.errorCode, state.errorMessage);
    }

    // Loading may fail before the feed finishes configuring this controller.
    // Install the listener first, then consume the snapshot without handling
    // its queued broadcast event a second time.
    _errors[index] = controller.stateStream.listen(observe);
    _errorChecks[index] = () => observe(controller.state);
    recheckPlaybackErrors(index);
  }

  /// Reconsiders a current error after a temporary recovery guard clears.
  void recheckPlaybackErrors(int index) => _errorChecks[index]?.call();

  /// Subscribes to loop-completion detection. Fires [onLoopCompleted] when
  /// the playback position resets from near the reported duration back to
  /// near zero.
  ///
  /// The duration is the clip's, so a feed that caps playback with a native
  /// clip end already reports the capped length here — detection needs no
  /// separate limit.
  ///
  /// [endThreshold] / [startThreshold] define the windows for "near end"
  /// and "near start".
  void subscribeToAutoAdvance(
    int index,
    DivineVideoPlayerController controller, {
    required Duration endThreshold,
    required Duration startThreshold,
    required bool Function() isCurrent,
    required void Function() onLoopCompleted,
  }) {
    unawaited(_autoAdvance[index]?.cancel());

    final initialState = controller.state;
    var armed = false;
    var lastPosition = initialState.position;

    final initialDuration = initialState.duration;
    if (isCurrent() &&
        initialState.isPlaying &&
        initialDuration > Duration.zero &&
        lastPosition >= initialDuration - endThreshold) {
      armed = true;
    }

    _autoAdvance[index] = controller.stateStream.listen((state) {
      if (!isCurrent() || !state.isPlaying) return;

      final position = state.position;
      final duration = state.duration;

      if (duration > Duration.zero && position >= duration - endThreshold) {
        armed = true;
      }

      if (armed && position <= startThreshold && lastPosition > position) {
        armed = false;
        onLoopCompleted();
      }

      lastPosition = position;
    });
  }

  /// Subscribes to the first dimension report (videoWidth/Height > 0) and
  /// auto-cancels itself once dimensions are known. Calls
  /// [onDimensionsReady] once.
  ///
  /// If dimensions are already known on subscribe (e.g. a reused
  /// controller), [onDimensionsReady] fires synchronously and no
  /// stream subscription is created.
  void subscribeToDimensions(
    int index,
    DivineVideoPlayerController controller, {
    required void Function() onDimensionsReady,
  }) {
    final s = controller.state;
    if (s.videoWidth > 0 && s.videoHeight > 0) {
      onDimensionsReady();
      return;
    }

    unawaited(_dimensions[index]?.cancel());
    _dimensions[index] = controller.stateStream.listen((state) {
      if (state.videoWidth > 0 && state.videoHeight > 0) {
        unawaited(_dimensions.remove(index)?.cancel());
        onDimensionsReady();
      }
    });
  }

  /// Subscribes to the first-frame transition and auto-cancels itself
  /// once `state.isFirstFrameRendered` flips to `true`. Calls
  /// [onFirstFrame] exactly once.
  ///
  /// If the controller already reports a rendered first frame on
  /// subscribe (e.g. a reused controller whose surface is warm),
  /// [onFirstFrame] fires synchronously and no stream subscription is
  /// created. This is what guarantees the loader overlay drops on the
  /// same frame as the swipe when iOS has the texture ready ahead of
  /// time.
  void subscribeToFirstFrame(
    int index,
    DivineVideoPlayerController controller, {
    required void Function() onFirstFrame,
  }) {
    if (controller.state.isFirstFrameRendered) {
      onFirstFrame();
      return;
    }

    unawaited(_firstFrame[index]?.cancel());
    _firstFrame[index] = controller.stateStream.listen((state) {
      if (state.isFirstFrameRendered) {
        unawaited(_firstFrame.remove(index)?.cancel());
        onFirstFrame();
      }
    });
  }

  /// Cancels every subscription for [index].
  void unsubscribe(int index) {
    unawaited(_dimensions.remove(index)?.cancel());
    unawaited(_firstFrame.remove(index)?.cancel());
    unawaited(_errors.remove(index)?.cancel());
    _errorChecks.remove(index);
    unawaited(_autoAdvance.remove(index)?.cancel());
  }

  /// Cancels every subscription. Safe to call from `State.dispose`.
  void disposeAll() {
    for (final s in _dimensions.values) {
      unawaited(s.cancel());
    }
    _dimensions.clear();
    for (final s in _firstFrame.values) {
      unawaited(s.cancel());
    }
    _firstFrame.clear();
    for (final s in _errors.values) {
      unawaited(s.cancel());
    }
    _errors.clear();
    _errorChecks.clear();
    for (final s in _autoAdvance.values) {
      unawaited(s.cancel());
    }
    _autoAdvance.clear();
  }
}
