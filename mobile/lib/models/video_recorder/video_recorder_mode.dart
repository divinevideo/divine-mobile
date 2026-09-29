import 'package:models/models.dart' as model show AspectRatio;

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
    // The key is baked into the clip in the editor, never at capture.
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

  bool get supportsCountdownTimer => switch (this) {
    .upload => false,
    .capture => true,
    .stopMotion => false,
    .lipSync => true,
    // Stepping into frame in front of the backdrop needs a hands-free start.
    .chromaKey => true,
    .classic => false,
  };

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
  /// Preview only: the recording is the raw camera footage, and the key is
  /// baked into the clip once the editor opens.
  bool get needsLiveChromaKey => this == chromaKey;
}
