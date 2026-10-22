// ABOUTME: Microphone capture service for the video editor's voice-over flow.
// ABOUTME: Wraps the `record` package and normalizes amplitude for the waveform.

import 'dart:async';

import 'package:record/record.dart';

/// Thrown when the microphone recorder fails to start, stop, or release.
///
/// The client layer translates the `record` package's untyped failures into
/// this single type (carrying the original in [cause]) so callers can catch one
/// documented exception instead of reaching into package internals.
class VoiceOverRecorderException implements Exception {
  /// Creates a [VoiceOverRecorderException] describing [message], optionally
  /// wrapping the underlying [cause].
  VoiceOverRecorderException(this.message, {this.cause});

  /// Human-readable description of the failure.
  final String message;

  /// The original error thrown by the `record` package, if any.
  final Object? cause;

  @override
  String toString() => cause == null
      ? 'VoiceOverRecorderException: $message'
      : 'VoiceOverRecorderException: $message ($cause)';
}

/// Captures microphone audio for the voice-over recorder.
///
/// Kept free of permission and UI concerns: the caller (the
/// `VoiceOverCubit`) gates recording behind a microphone permission check
/// and owns the recorded files. This abstraction exists so the cubit can be
/// unit-tested with a fake recorder instead of hitting native audio APIs.
abstract class VoiceOverRecorderService {
  /// Interval between amplitude samples emitted by [amplitudeStream].
  ///
  /// Single source of truth for the sampling cadence: the cubit advances the
  /// elapsed recording time by this amount per sample and the live waveform
  /// glides one bar per interval, so both read this constant instead of
  /// redefining the value (which would silently desync if any copy drifted).
  static const amplitudeInterval = Duration(milliseconds: 100);

  /// Starts recording to [path], which should be an `.m4a` file path.
  ///
  /// Throws a [VoiceOverRecorderException] if the recorder cannot start — for
  /// example when the microphone is unavailable or permission was not granted.
  Future<void> start(String path);

  /// Stops the current recording.
  ///
  /// Returns the path of the written file, or `null` when nothing was
  /// recorded. Throws a [VoiceOverRecorderException] if the recorder fails to
  /// stop.
  Future<String?> stop();

  /// Normalized (`0.0`–`1.0`) amplitude updates emitted while recording.
  ///
  /// `0.0` is silence and `1.0` is the loudest level the meter represents.
  Stream<double> get amplitudeStream;

  /// Emits each time the system pauses capture on its own — a phone call,
  /// Siri, or another app taking audio focus.
  ///
  /// Capture does not resume by itself afterwards, so a caller still showing
  /// a running recording would be wrong.
  Stream<void> get systemPauses;

  /// Releases native recorder resources.
  ///
  /// Throws a [VoiceOverRecorderException] if the recorder fails to release.
  Future<void> dispose();
}

/// [VoiceOverRecorderService] backed by the `record` package.
class RecordVoiceOverRecorderService implements VoiceOverRecorderService {
  /// Creates the service. An [AudioRecorder] can be injected for testing.
  RecordVoiceOverRecorderService({AudioRecorder? recorder})
    : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;

  /// Mono AAC (the package default encoder) in an MP4 container — broadly
  /// supported on iOS and Android and renderable through the editor's
  /// [EditorAudio.file] path.
  static const _config = RecordConfig(numChannels: 1);

  /// Floor of the dBFS range we map onto the `0.0`–`1.0` waveform. Levels
  /// quieter than this are treated as silence.
  static const _minDb = -45.0;

  @override
  Stream<double> get amplitudeStream => _recorder
      .onAmplitudeChanged(VoiceOverRecorderService.amplitudeInterval)
      .map(_normalize);

  // Nothing here pauses the recorder, so every pause comes from the system.
  @override
  Stream<void> get systemPauses => _recorder
      .onStateChanged()
      .where((state) => state == RecordState.pause)
      .map((_) {});

  @override
  Future<void> start(String path) async {
    try {
      await _recorder.start(_config, path: path);
    } catch (e, s) {
      Error.throwWithStackTrace(
        VoiceOverRecorderException('Failed to start recording', cause: e),
        s,
      );
    }
  }

  @override
  Future<String?> stop() async {
    try {
      return await _recorder.stop();
    } catch (e, s) {
      Error.throwWithStackTrace(
        VoiceOverRecorderException('Failed to stop recording', cause: e),
        s,
      );
    }
  }

  @override
  Future<void> dispose() async {
    try {
      await _recorder.dispose();
    } catch (e, s) {
      Error.throwWithStackTrace(
        VoiceOverRecorderException('Failed to release recorder', cause: e),
        s,
      );
    }
  }

  static double _normalize(Amplitude amplitude) {
    final db = amplitude.current;
    if (db.isNaN || db.isInfinite) return 0;
    final clamped = db.clamp(_minDb, 0.0);
    return ((clamped - _minDb) / -_minDb).clamp(0.0, 1.0);
  }
}
