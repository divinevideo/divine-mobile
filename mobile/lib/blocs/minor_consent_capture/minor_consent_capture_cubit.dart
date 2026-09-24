// ABOUTME: Cubit driving the in-app parent-consent capture screen: record,
// ABOUTME: review, retake, and the denied/error states that gate the flow.

import 'dart:async';
import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/services/minor_consent_recorder.dart';

/// Best-effort deletion of a discarded consent clip.
typedef MinorConsentClipDeleter = Future<void> Function(String path);

/// State of the parent-consent capture flow.
sealed class MinorConsentCaptureState {
  const MinorConsentCaptureState();
}

/// Nothing recorded yet; the preview and record control are shown.
class MinorConsentCaptureIdle extends MinorConsentCaptureState {
  const MinorConsentCaptureIdle();
}

/// The camera is recording.
class MinorConsentCaptureRecording extends MinorConsentCaptureState {
  const MinorConsentCaptureRecording();
}

/// A clip is ready to review at [filePath].
class MinorConsentCaptureReview extends MinorConsentCaptureState {
  const MinorConsentCaptureReview(this.filePath);

  /// Path of the recorded clip, in the app's temporary storage.
  final String filePath;
}

/// The camera refused to start; the parent must use the email fallback.
class MinorConsentCaptureDenied extends MinorConsentCaptureState {
  const MinorConsentCaptureDenied();
}

/// Recording stopped without producing a file.
class MinorConsentCaptureError extends MinorConsentCaptureState {
  const MinorConsentCaptureError();
}

/// Drives the capture screen against a [MinorConsentRecorder].
///
/// Owns no camera itself: every platform call goes through the recorder port
/// so the flow is testable without native hardware.
class MinorConsentCaptureCubit extends Cubit<MinorConsentCaptureState> {
  MinorConsentCaptureCubit({
    required MinorConsentRecorder recorder,
    MinorConsentClipDeleter? deleteClip,
  }) : _recorder = recorder,
       _deleteClip = deleteClip ?? _deleteClipFile,
       super(const MinorConsentCaptureIdle()) {
    _recorder.onAutoStopped = _handleAutoStopped;
  }

  /// Hard cap on the consent clip, enforced by the recorder.
  static const Duration maxDuration = Duration(seconds: 60);

  final MinorConsentRecorder _recorder;
  final MinorConsentClipDeleter _deleteClip;
  bool _disposed = false;

  /// Path of the clip the parent can still act on — the one in review, or the
  /// one they accepted for upload. [_discardClip] never deletes this one.
  String? _retainedPath;

  /// Prepares the camera behind the recorder for a live preview.
  Future<void> initialize() async {
    if (_disposed || isClosed) return;
    await _recorder.initialize();
  }

  /// Starts recording under [outputDirectory], capping at [maxDuration].
  ///
  /// Emits [MinorConsentCaptureDenied] when the camera refuses to start, so the
  /// screen can route the parent to the email fallback.
  Future<void> start({required String outputDirectory}) async {
    if (_disposed || isClosed) return;
    final started = await _recorder.start(
      maxDuration: maxDuration,
      outputDirectory: outputDirectory,
    );
    if (isClosed || _disposed) {
      // The screen was left while the camera was starting. Discard the clip
      // rather than leaving a recording running with no owner.
      if (started) await _discardClip(await _safeStop());
      return;
    }
    if (!started) {
      emit(const MinorConsentCaptureDenied());
      return;
    }
    emit(const MinorConsentCaptureRecording());
  }

  /// Stops recording and moves to review, or to error when no file was written.
  ///
  /// An auto-stop that already produced a clip wins: the review state is left
  /// untouched rather than overwritten by an error from a second stop.
  Future<void> stop() async {
    if (_disposed || isClosed) return;
    if (state is MinorConsentCaptureReview) return;
    final path = await _recorder.stop();
    if (isClosed || _disposed) {
      // Left mid-stop: nothing will surface this clip, so do not strand it.
      await _discardClip(path);
      return;
    }
    if (path == null) {
      emit(const MinorConsentCaptureError());
      return;
    }
    _retainedPath = path;
    emit(MinorConsentCaptureReview(path));
  }

  /// Discards the recorded clip and returns to the idle preview.
  void retake() {
    if (_disposed || isClosed) return;
    final current = state;
    if (current is MinorConsentCaptureReview) {
      _retainedPath = null;
      unawaited(_deleteClip(current.filePath));
    }
    emit(const MinorConsentCaptureIdle());
  }

  /// Surfaces [MinorConsentCaptureError] when starting the camera throws before
  /// the recorder can report a denial, so the retry pane stays reachable.
  void fail() {
    if (_disposed || isClosed) return;
    emit(const MinorConsentCaptureError());
  }

  /// Transitions to review when the platform camera stops on its own.
  ///
  /// A late callback — after the cubit is closed, or after the recording was
  /// already finalised — cannot emit past [close], so the clip it carries has
  /// no owner and is deleted instead of being left in temporary storage. The
  /// clip already in review, or already accepted, is retained.
  void _handleAutoStopped(String? path) {
    if (_disposed || isClosed || state is! MinorConsentCaptureRecording) {
      unawaited(_discardClip(path));
      return;
    }
    if (path == null) {
      emit(const MinorConsentCaptureError());
      return;
    }
    _retainedPath = path;
    emit(MinorConsentCaptureReview(path));
  }

  /// Releases the camera once a clip has been accepted for submission.
  ///
  /// The captured file stays on disk and remains usable for upload; only the
  /// live camera session and the recorder are torn down. Idempotent, and
  /// [close] tolerates a recorder that was already released here.
  Future<void> releaseRecorder() async {
    if (_disposed || isClosed) return;
    _disposed = true;
    _recorder.onAutoStopped = null;
    if (state is MinorConsentCaptureRecording) {
      await _discardClip(await _safeStop());
    }
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
    if (_disposed) return super.close();
    _disposed = true;
    _recorder.onAutoStopped = null;
    if (state is MinorConsentCaptureRecording) {
      await _discardClip(await _safeStop());
    }
    await _safeDispose();
    return super.close();
  }

  /// Deletes a clip no part of the flow owns.
  ///
  /// The retained clip — on screen in review, or accepted for upload — is left
  /// alone, so a late auto-stop callback carrying the same path cannot delete
  /// a file the parent is still about to submit.
  Future<void> _discardClip(String? path) async {
    if (path == null || path == _retainedPath) return;
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

/// Deletes [path], ignoring an already-missing file.
Future<void> _deleteClipFile(String path) async {
  try {
    await File(path).delete();
  } on FileSystemException {
    // The clip was already discarded or removed by the OS; best-effort delete.
  }
}
