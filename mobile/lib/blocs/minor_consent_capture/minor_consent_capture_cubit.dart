// ABOUTME: Cubit driving the in-app parent-consent capture screen: record,
// ABOUTME: review, retake, and the denied/error states that gate the flow.

import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:openvine/services/consent_operation_queue.dart';
import 'package:openvine/services/minor_consent_recorder_port.dart';
import 'package:unified_logger/unified_logger.dart';

/// Best-effort deletion of a discarded consent clip.
typedef MinorConsentClipDeleter = Future<void> Function(String path);

/// State of the parent-consent capture flow.
sealed class MinorConsentCaptureState {
  const MinorConsentCaptureState({
    this.disposed = false,
    this.starting = false,
    this.stopping = false,
    this.wakelockEnabled = false,
  });

  final bool disposed;
  final bool starting;
  final bool stopping;
  final bool wakelockEnabled;

  MinorConsentCaptureState withOperations({
    bool? disposed,
    bool? starting,
    bool? stopping,
    bool? wakelockEnabled,
  }) {
    final next = (
      disposed: disposed ?? this.disposed,
      starting: starting ?? this.starting,
      stopping: stopping ?? this.stopping,
      wakelockEnabled: wakelockEnabled ?? this.wakelockEnabled,
    );
    return switch (this) {
      MinorConsentCaptureIdle() => MinorConsentCaptureIdle(
        disposed: next.disposed,
        starting: next.starting,
        stopping: next.stopping,
        wakelockEnabled: next.wakelockEnabled,
      ),
      MinorConsentCaptureRecording() => MinorConsentCaptureRecording(
        disposed: next.disposed,
        starting: next.starting,
        stopping: next.stopping,
        wakelockEnabled: next.wakelockEnabled,
      ),
      MinorConsentCaptureReview(:final filePath) => MinorConsentCaptureReview(
        filePath,
        disposed: next.disposed,
        starting: next.starting,
        stopping: next.stopping,
        wakelockEnabled: next.wakelockEnabled,
      ),
      MinorConsentCaptureDenied() => MinorConsentCaptureDenied(
        disposed: next.disposed,
        starting: next.starting,
        stopping: next.stopping,
        wakelockEnabled: next.wakelockEnabled,
      ),
      MinorConsentCaptureError(:final awaitingAutoStop) =>
        MinorConsentCaptureError(
          awaitingAutoStop: awaitingAutoStop,
          disposed: next.disposed,
          starting: next.starting,
          stopping: next.stopping,
          wakelockEnabled: next.wakelockEnabled,
        ),
    };
  }
}

/// Nothing recorded yet; the preview and record control are shown.
class MinorConsentCaptureIdle extends MinorConsentCaptureState {
  const MinorConsentCaptureIdle({
    super.disposed,
    super.starting,
    super.stopping,
    super.wakelockEnabled,
  });
}

/// The camera is recording.
class MinorConsentCaptureRecording extends MinorConsentCaptureState {
  const MinorConsentCaptureRecording({
    super.disposed,
    super.starting,
    super.stopping,
    super.wakelockEnabled,
  });
}

/// A clip is ready to review at [filePath].
class MinorConsentCaptureReview extends MinorConsentCaptureState {
  const MinorConsentCaptureReview(
    this.filePath, {
    super.disposed,
    super.starting,
    super.stopping,
    super.wakelockEnabled,
  });

  /// Path of the recorded clip, in the app's temporary storage.
  final String filePath;
}

/// The camera refused to start; the parent must use the email fallback.
class MinorConsentCaptureDenied extends MinorConsentCaptureState {
  const MinorConsentCaptureDenied({
    super.disposed,
    super.starting,
    super.stopping,
    super.wakelockEnabled,
  });
}

/// Recording stopped without producing a file.
class MinorConsentCaptureError extends MinorConsentCaptureState {
  const MinorConsentCaptureError({
    this.awaitingAutoStop = false,
    super.disposed,
    super.starting,
    super.stopping,
    super.wakelockEnabled,
  });

  final bool awaitingAutoStop;
}

/// Drives the capture screen against a [MinorConsentRecorder].
///
/// Owns no camera itself: every platform call goes through the recorder port
/// so the flow is testable without native hardware.
class MinorConsentCaptureCubit extends Cubit<MinorConsentCaptureState> {
  MinorConsentCaptureCubit({
    required MinorConsentRecorder recorder,
    required Future<void> Function(bool enabled) setWakelock,
    required MinorConsentClipDeleter deleteClip,
  }) : _recorder = recorder,
       _deleteClip = deleteClip,
       _toggleWakelock = setWakelock,
       super(const MinorConsentCaptureIdle()) {
    _recorder.onAutoStopped = _handleAutoStopped;
  }

  /// Hard cap on the consent clip, enforced by the recorder.
  static const Duration maxDuration = Duration(seconds: 60);

  final MinorConsentRecorder _recorder;
  final MinorConsentClipDeleter _deleteClip;
  final Future<void> Function(bool enabled) _toggleWakelock;
  final _wakelockOperations = ConsentOperationQueue();
  final _lifecycleOperations = ConsentOperationQueue();

  void _phase(MinorConsentCaptureState next) {
    if (isClosed) return;
    emit(
      next.withOperations(
        disposed: state.disposed,
        starting: state.starting,
        stopping: state.stopping,
        wakelockEnabled: state.wakelockEnabled,
      ),
    );
  }

  void _operations({
    bool? disposed,
    bool? starting,
    bool? stopping,
    bool? wakelockEnabled,
  }) {
    if (!isClosed) {
      emit(
        state.withOperations(
          disposed: disposed,
          starting: starting,
          stopping: stopping,
          wakelockEnabled: wakelockEnabled,
        ),
      );
    }
  }

  /// Prepares the camera behind the recorder for a live preview.
  Future<void> initialize() async {
    if (state.disposed || isClosed) return;
    await _recorder.initialize();
  }

  /// Starts recording under [outputDirectory], capping at [maxDuration].
  ///
  /// Emits [MinorConsentCaptureDenied] when the camera refuses to start, so the
  /// screen can route the parent to the email fallback. Only starts from idle,
  /// and ignores a call while a start is already in flight.
  Future<void> start({required String outputDirectory}) async {
    if (state.disposed || isClosed) return;
    if (state.starting || state is! MinorConsentCaptureIdle) return;
    _operations(starting: true);
    final bool started;
    try {
      started = await _recorder.start(
        maxDuration: maxDuration,
        outputDirectory: outputDirectory,
      );
    } finally {
      _operations(starting: false);
    }
    if (isClosed || state.disposed) {
      // The screen was left while the camera was starting. Discard the clip
      // rather than leaving a recording running with no owner.
      if (started) await _discardClip(await _safeStop());
      return;
    }
    if (!started) {
      _phase(const MinorConsentCaptureDenied());
      return;
    }
    _phase(const MinorConsentCaptureRecording());
    await _setWakelock(true);
  }

  /// Stops recording and moves to review, or to error when no file was written.
  ///
  /// An auto-stop that already produced a clip wins: the review state is left
  /// untouched rather than overwritten by an error from a second stop.
  Future<void> stop() async {
    if (state.disposed || isClosed) return;
    if (state.stopping || state is MinorConsentCaptureReview) return;
    _operations(stopping: true);
    final String? path;
    try {
      path = await _recorder.stop();
    } finally {
      await _setWakelock(false);
      _operations(stopping: false);
    }
    if (isClosed || state.disposed) {
      // Left mid-stop: nothing will surface this clip, so do not strand it.
      await _discardClip(path);
      return;
    }
    if (state is MinorConsentCaptureReview) {
      // The auto-stop landed while this stop was awaiting; its clip wins.
      unawaited(_discardClip(path));
      return;
    }
    if (path == null) {
      _phase(const MinorConsentCaptureError(awaitingAutoStop: true));
      return;
    }
    _phase(MinorConsentCaptureReview(path));
  }

  /// Discards the recorded clip and returns to the idle preview.
  void retake() {
    if (state.disposed || isClosed) return;
    final current = state;
    if (current is MinorConsentCaptureReview) {
      unawaited(_deleteClip(current.filePath));
    }
    _phase(const MinorConsentCaptureIdle());
  }

  /// Surfaces [MinorConsentCaptureError] when starting the camera throws before
  /// the recorder can report a denial, so the retry pane stays reachable.
  void fail() {
    if (state.disposed || isClosed) return;
    _phase(const MinorConsentCaptureError());
  }

  /// Transitions to review when the platform camera stops on its own, or when
  /// its clip arrives just after a manual stop at the cap returned nothing.
  ///
  /// A late callback — after the cubit is closed, or after the recording was
  /// already finalised — cannot emit past [close], so the clip it carries has
  /// no owner and is deleted instead of being left in temporary storage. The
  /// clip already in review, or already accepted, is retained.
  void _handleAutoStopped(String? path) {
    final awaitingClip =
        state is MinorConsentCaptureRecording ||
        (state is MinorConsentCaptureError &&
            (state as MinorConsentCaptureError).awaitingAutoStop);
    if (state.disposed || isClosed || !awaitingClip) {
      unawaited(_discardClip(path));
      return;
    }
    if (path == null && state is MinorConsentCaptureError) return;
    unawaited(_setWakelock(false));
    if (path == null) {
      _phase(const MinorConsentCaptureError());
      return;
    }
    _phase(MinorConsentCaptureReview(path));
  }

  /// Releases the camera once a clip has been accepted for submission.
  ///
  /// The captured file stays on disk and remains usable for upload; only the
  /// live camera session and the recorder are torn down. Idempotent, and
  /// [close] tolerates a recorder that was already released here.
  Future<void> releaseRecorder() async {
    if (state.disposed || isClosed) return;
    _operations(disposed: true);
    // The auto-stop listener stays attached: a clip the platform delivers
    // after this point is deleted by [_handleAutoStopped], not dropped.
    if (state is MinorConsentCaptureRecording) {
      await _discardClip(await _safeStop());
    }
    await _lifecycleOperations.settled;
    await _setWakelock(false);
    await _safeDispose();
  }

  /// Stops an in-flight recording and releases the camera.
  ///
  /// A clip stopped here is never emitted, so a parent who leaves mid-recording
  /// cannot have it submitted — and nothing downstream will ever learn its
  /// path, so it is deleted here rather than left in temporary storage.
  /// Idempotent: the recorder and its provider both call it, and
  /// [releaseRecorder] may have disposed it already.
  @override
  Future<void> close() async {
    if (state.disposed) return super.close();
    _operations(disposed: true);
    // See [releaseRecorder]: the listener stays attached so a late clip is
    // deleted rather than left in temporary storage.
    if (state is MinorConsentCaptureRecording) {
      await _discardClip(await _safeStop());
    }
    await _lifecycleOperations.settled;
    await _setWakelock(false);
    await _safeDispose();
    return super.close();
  }

  /// Serializes preview pause/resume with teardown without changing the clip.
  Future<void> handleAppLifecycleState(ConsentCameraLifecycle appState) {
    return _lifecycleOperations.run(() async {
      if (state.disposed || isClosed) return;
      try {
        await _recorder.handleAppLifecycleState(appState);
      } catch (error) {
        Log.warning(
          'Consent camera lifecycle update failed: $error',
          name: 'MinorConsentCaptureCubit',
          category: LogCategory.video,
        );
      }
    });
  }

  Future<void> _setWakelock(bool enabled) {
    return _wakelockOperations.run(() async {
      if (enabled &&
          (state.disposed ||
              isClosed ||
              state is! MinorConsentCaptureRecording)) {
        return;
      }
      if (state.wakelockEnabled == enabled) return;
      try {
        await _toggleWakelock(enabled);
        _operations(wakelockEnabled: enabled);
      } catch (error) {
        Log.warning(
          'Consent recording wakelock update failed: $error',
          name: 'MinorConsentCaptureCubit',
          category: LogCategory.video,
        );
      }
    });
  }

  /// Deletes a clip no part of the flow owns.
  ///
  /// The clip in review, including after acceptance for upload, is left
  /// alone, so a late auto-stop callback carrying the same path cannot delete
  /// a file the parent is still about to submit.
  Future<void> _discardClip(String? path) async {
    if (path == null ||
        (state is MinorConsentCaptureReview &&
            path == (state as MinorConsentCaptureReview).filePath)) {
      return;
    }
    await _deleteClip(path);
  }

  Future<String?> _safeStop() async {
    try {
      return await _recorder.stop();
    } catch (_) {
      // The camera already stopped (auto-stop, or a released session); a failed
      // stop must not reject close() or releaseRecorder().
      return null;
    }
  }

  Future<void> _safeDispose() async {
    try {
      await _recorder.dispose();
    } catch (_) {
      // Disposal is best-effort and idempotent for the camera; a second
      // release must not reject the caller.
    }
  }
}
