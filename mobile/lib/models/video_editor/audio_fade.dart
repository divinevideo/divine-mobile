import 'dart:math' as math;

/// The gain of a sound track [position] into a track that sounds for
/// [length], faded in over [fadeIn] and out over [fadeOut].
///
/// Linear ramps from and to silence, the quieter one winning where they
/// overlap — the same envelope `pro_video_editor` bakes into the export and
/// `divine_video_player` plays in the preview, so the timeline draws what the
/// creator will hear.
double audioFadeGain({
  required Duration position,
  required Duration length,
  required Duration fadeIn,
  required Duration fadeOut,
}) {
  final inGain = fadeIn > Duration.zero
      ? position.inMicroseconds / fadeIn.inMicroseconds
      : 1.0;
  final outGain = fadeOut > Duration.zero
      ? (length - position).inMicroseconds / fadeOut.inMicroseconds
      : 1.0;
  return math.min(inGain, outGain).clamp(0.0, 1.0);
}
