part of 'sound_recorder_cubit.dart';

const _unset = Object();

/// Lifecycle of the Add sound screen's microphone recorder.
enum SoundRecorderStatus {
  /// Not recording.
  idle,

  /// Microphone access was refused; the user has to allow it in settings.
  permissionDenied,

  /// The microphone is recording.
  recording,

  /// Recording was stopped and the recorder is closing its file.
  stopping,

  /// Starting or stopping the recorder failed. Transient: the next start
  /// clears it.
  failed,
}

/// State of the Add sound screen's microphone recorder.
///
/// Holds the live level meter and elapsed time while recording, and the
/// finished file in [recordingPath] until the screen takes it over. Failures
/// surface as [SoundRecorderStatus.failed] and are reported via `addError`.
class SoundRecorderState extends Equatable {
  const SoundRecorderState({
    this.status = SoundRecorderStatus.idle,
    this.elapsed = Duration.zero,
    this.waveformBars = const [],
    this.maxDuration = SoundRecorderCubit.defaultMaxDuration,
    this.recordingPath,
  });

  final SoundRecorderStatus status;

  /// How long the recording in progress has been running.
  final Duration elapsed;

  /// Rolling buffer of normalized (`0.0`–`1.0`) levels for the live
  /// waveform, oldest first. Empty while not recording.
  final List<double> waveformBars;

  /// Length at which a recording stops on its own.
  final Duration maxDuration;

  /// The last finished recording, a scratch file the screen takes over.
  ///
  /// Each recording gets its own path, so a change here is a new recording.
  final String? recordingPath;

  bool get isRecording => status == SoundRecorderStatus.recording;

  /// Whether a recording is running or still being finished.
  bool get isActive =>
      status == SoundRecorderStatus.recording ||
      status == SoundRecorderStatus.stopping;

  SoundRecorderState copyWith({
    SoundRecorderStatus? status,
    Duration? elapsed,
    List<double>? waveformBars,
    Object? recordingPath = _unset,
  }) {
    return SoundRecorderState(
      status: status ?? this.status,
      elapsed: elapsed ?? this.elapsed,
      waveformBars: waveformBars ?? this.waveformBars,
      maxDuration: maxDuration,
      recordingPath: identical(recordingPath, _unset)
          ? this.recordingPath
          : recordingPath as String?,
    );
  }

  @override
  List<Object?> get props => [
    status,
    elapsed,
    waveformBars,
    maxDuration,
    recordingPath,
  ];
}
