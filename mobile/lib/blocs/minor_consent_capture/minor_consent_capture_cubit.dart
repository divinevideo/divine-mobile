// ABOUTME: Cubit driving the in-app parent-consent capture screen: record,
// ABOUTME: review, retake, and the denied/error states that gate the flow.

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/services/minor_consent_recorder.dart';

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
  MinorConsentCaptureCubit({required MinorConsentRecorder recorder})
    : _recorder = recorder,
      super(const MinorConsentCaptureIdle());

  /// Hard cap on the consent clip, enforced by the recorder.
  static const Duration maxDuration = Duration(seconds: 60);

  final MinorConsentRecorder _recorder;

  /// Starts recording under [outputDirectory], capping at [maxDuration].
  ///
  /// Emits [MinorConsentCaptureDenied] when the camera refuses to start, so the
  /// screen can route the parent to the email fallback.
  Future<void> start({required String outputDirectory}) async {
    final started = await _recorder.start(
      maxDuration: maxDuration,
      outputDirectory: outputDirectory,
    );
    if (isClosed) return;
    if (!started) {
      emit(const MinorConsentCaptureDenied());
      return;
    }
    emit(const MinorConsentCaptureRecording());
  }

  /// Stops recording and moves to review, or to error when no file was written.
  Future<void> stop() async {
    final path = await _recorder.stop();
    if (isClosed) return;
    if (path == null) {
      emit(const MinorConsentCaptureError());
      return;
    }
    emit(MinorConsentCaptureReview(path));
  }

  /// Discards the recorded clip and returns to the idle preview.
  void retake() {
    if (isClosed) return;
    emit(const MinorConsentCaptureIdle());
  }
}
