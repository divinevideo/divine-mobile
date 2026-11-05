import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/models/video_recorder/video_recorder_timer_duration.dart';

/// Recorder modes, declared in the mode wheel's left-to-right order.
///
/// [capture] is the leftmost entry and the default; [upload] sits at the far
/// right.
enum VideoRecorderMode {
  capture,
  stopMotion,
  lipSync,
  chromaKey,
  classic,
  upload;

  /// SharedPreferences key for the last-used recorder mode.
  ///
  /// Persisted by the recorder and read by surfaces that live on a separate
  /// route from the recorder's `BlocProvider` (e.g. the metadata screen), which
  /// therefore cannot read it from `VideoRecorderBloc`.
  static const persistenceKey = 'camera_last_used_recorder_mode';

  /// Parses a persisted mode [name], defaulting to [capture] for null/unknown.
  static VideoRecorderMode fromName(String? name) =>
      values.firstWhere((m) => m.name == name, orElse: () => capture);

  /// The modes this device can offer, in wheel order.
  ///
  /// [chromaKey] needs a live keyed viewfinder, which only a renderer with a
  /// shader image filter can draw. The editor degrades to an unkeyed preview
  /// and still exports the key, but at capture there is nothing to fall back
  /// to — the keyed viewfinder *is* the mode — so it is left out instead.
  static List<VideoRecorderMode> available({
    required bool liveChromaKeySupported,
  }) => [
    for (final mode in values)
      if (liveChromaKeySupported || !mode.needsLiveChromaKey) mode,
  ];

  /// English label for the mode wheel, which shows [chromaKey] under its
  /// localized name instead.
  String get label => switch (this) {
    .upload => 'Upload',
    .capture => 'Capture',
    .stopMotion => 'Stop Motion',
    .lipSync => 'Lip Sync',
    .chromaKey => 'Chroma Key',
    .classic => 'Classic',
  };

  bool get hasRecordingLimit => switch (this) {
    .upload => false,
    .capture => false,
    .stopMotion => false,
    .lipSync => false,
    .chromaKey => false,
    .classic => true,
  };

  bool get hasVideoEditor => switch (this) {
    .upload => false,
    .capture => true,
    .stopMotion => true,
    .lipSync => true,
    // The camera records raw footage; the key is baked in afterwards.
    .chromaKey => true,
    .classic => false,
  };

  bool get supportGridLines => switch (this) {
    .upload => false,
    .capture => false,
    .stopMotion => true,
    .lipSync => false,
    .chromaKey => false,
    .classic => true,
  };

  /// Whether the user can lay the previous take's last frame over the live
  /// preview to line up the next one.
  bool get supportsGhostFrame => switch (this) {
    .upload => false,
    .capture => true,
    .stopMotion => true,
    .lipSync => true,
    // The ghost comes from the raw take, so it would lay the bare backdrop
    // over the keyed viewfinder.
    .chromaKey => false,
    .classic => true,
  };

  /// The settings the timer button cycles through, [TimerDuration.off] first,
  /// or an empty list when the mode has no timer.
  ///
  /// Video modes count down once and then start the take. Stop-motion counts
  /// down before every still until the shutter is tapped again, so it offers
  /// the short windows a nudge between two frames takes.
  List<TimerDuration> get timerDurations => switch (this) {
    .upload => const [],
    .capture => _delayedStartDurations,
    .stopMotion => const [.off, .two, .three, .five],
    .lipSync => _delayedStartDurations,
    // Stepping into frame in front of the backdrop needs a hands-free start.
    .chromaKey => _delayedStartDurations,
    .classic => const [],
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
    .lipSync => true,
    // Look-ahead stabilization delays the preview behind the file, and the
    // backdrop is composited live against that preview.
    .chromaKey => false,
    .classic => false,
  };

  model.AspectRatio get defaultAspectRatio => switch (this) {
    .upload => .vertical,
    .capture => .vertical,
    .stopMotion => .vertical,
    .lipSync => .vertical,
    .chromaKey => .vertical,
    .classic => .square,
  };

  /// Whether this mode captures still photos (stop-motion) instead of
  /// recording video. Drives the shutter behavior and capture UI.
  bool get capturesStills => this == stopMotion;

  /// Whether the viewfinder shows the chroma-key composite live.
  ///
  /// The recording itself is the raw camera footage. The key is baked into
  /// the clip afterwards.
  bool get needsLiveChromaKey => this == chromaKey;
}
