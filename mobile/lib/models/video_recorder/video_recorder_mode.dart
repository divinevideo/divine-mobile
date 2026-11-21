import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/models/video_recorder/video_recorder_timer_duration.dart';

/// Recorder modes, declared in the mode wheel's left-to-right order.
///
/// [capture] is the leftmost entry and the default; [upload] sits at the far
/// right.
///
/// [together] and [upload] are tabs that record nothing themselves: Together
/// starts a room where up to four people each film their own part of a
/// split-screen layout, and every part is filmed in a recorder of its own.
enum VideoRecorderMode {
  capture,
  stopMotion,
  together,
  classic,
  upload;

  /// SharedPreferences key for the last-used recorder mode.
  ///
  /// Persisted by the recorder and read by surfaces that live on a separate
  /// route from the recorder's `BlocProvider` (e.g. the metadata screen), which
  /// therefore cannot read it from `VideoRecorderBloc`.
  static const persistenceKey = 'camera_last_used_recorder_mode';

  /// Parses a persisted mode [name], defaulting to [capture] for null/unknown.
  ///
  /// Lip Sync and Chroma Key were modes of their own before they became
  /// capture's sound chip and color mask, so a recorder last left in one of
  /// them reopens in [capture].
  static VideoRecorderMode fromName(String? name) =>
      values.firstWhere((m) => m.name == name, orElse: () => capture);

  /// English label for the mode wheel.
  String get label => switch (this) {
    .upload => 'Upload',
    .capture => 'Capture',
    .stopMotion => 'Stop Motion',
    .classic => 'Classic',
    .together => 'Together',
  };

  /// Whether the tab films. Upload and Together pause the camera and show a
  /// screen of their own instead, so peeking at them keeps the session's
  /// clips.
  bool get recordsVideo => switch (this) {
    .upload => false,
    .together => false,
    .capture => true,
    .stopMotion => true,
    .classic => true,
  };

  bool get hasRecordingLimit => switch (this) {
    .upload => false,
    .capture => false,
    .stopMotion => false,
    .classic => true,
    .together => false,
  };

  bool get hasVideoEditor => switch (this) {
    .upload => false,
    .capture => true,
    .stopMotion => true,
    .classic => false,
    .together => false,
  };

  bool get supportGridLines => switch (this) {
    .upload => false,
    .capture => true,
    .stopMotion => true,
    .classic => true,
    .together => false,
  };

  /// Whether the user can lay the previous take's last frame over the live
  /// preview to line up the next one.
  bool get supportsGhostFrame => switch (this) {
    .upload => false,
    .capture => true,
    .stopMotion => true,
    .classic => true,
    .together => false,
  };

  /// The settings the timer button cycles through, [TimerDuration.off] first,
  /// or an empty list when the mode has no timer.
  ///
  /// Video modes count down once and then start the take. Stop-motion counts
  /// down before every still until the shutter is tapped again, so it adds
  /// the 5 second window a nudge between two frames often takes.
  List<TimerDuration> get timerDurations => switch (this) {
    .upload => const [],
    .capture => _delayedStartDurations,
    .stopMotion => const [.off, .three, .five, .ten],
    .classic => const [],
    .together => const [],
  };

  static const List<TimerDuration> _delayedStartDurations = [
    TimerDuration.off,
    TimerDuration.three,
    TimerDuration.ten,
  ];

  /// Whether the mode shows the timer button.
  bool get supportsCountdownTimer => timerDurations.isNotEmpty;

  bool get supportsVideoStabilization => switch (this) {
    .upload => false,
    .capture => true,
    .stopMotion => false,
    .classic => false,
    .together => false,
  };

  /// Whether the mode offers dual-camera capture: every take records the
  /// front and the back camera, and the second one becomes a
  /// picture-in-picture layer in the editor.
  bool get supportsDualCamera => switch (this) {
    .upload => false,
    .capture => true,
    // Stills come from the photo output, which dual capture does not run.
    .stopMotion => false,
    // Classic renders straight to a post and never opens the editor.
    .classic => false,
    .together => false,
  };

  model.AspectRatio get defaultAspectRatio => switch (this) {
    .upload => .vertical,
    .capture => .vertical,
    .stopMotion => .vertical,
    .classic => .square,
    .together => .vertical,
  };

  /// Whether this mode captures still photos (stop-motion) instead of
  /// recording video. Drives the shutter behavior and capture UI.
  bool get capturesStills => this == stopMotion;

  /// Whether the mode offers the color mask, which keys the viewfinder live.
  ///
  /// The recording itself is the raw camera footage. The key is baked into
  /// the clip afterwards.
  bool get supportsChromaKey => this == capture;

  /// Whether the mode offers a sound to record against, played while the take
  /// runs.
  bool get supportsSound => this == capture;
}
