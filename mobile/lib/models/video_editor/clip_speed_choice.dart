// ABOUTME: The speed a clip plays at — one constant speed or a speed ramp —
// ABOUTME: and the one-tap ramp presets the clip speed sheet offers.

import 'package:openvine/constants/video_editor_constants.dart';
import 'package:pro_video_editor/pro_video_editor.dart'
    show VideoSpeedRamp, VideoSpeedRampPoint;

/// What the clip speed sheet hands back: a constant speed or a speed ramp.
sealed class ClipSpeedChoice {
  const ClipSpeedChoice();
}

/// The clip plays at one [speed] throughout.
final class ConstantClipSpeed extends ClipSpeedChoice {
  const ConstantClipSpeed(this.speed);

  final double speed;
}

/// The clip speeds up and slows down along [ramp].
final class RampClipSpeed extends ClipSpeedChoice {
  const RampClipSpeed(this.ramp);

  final VideoSpeedRamp ramp;
}

/// A speed ramp with one point per speed in [speeds], spread evenly from the
/// clip's first frame to its last.
VideoSpeedRamp evenlySpacedSpeedRamp(List<double> speeds) {
  final last = speeds.length - 1;
  return VideoSpeedRamp([
    for (var i = 0; i <= last; i++)
      VideoSpeedRampPoint(
        position: last == 0 ? 0 : i / last,
        speed: speeds[i],
      ),
  ]);
}

/// The ramp a custom curve starts from: every point at normal speed.
VideoSpeedRamp get flatSpeedRamp => evenlySpacedSpeedRamp(
  List.filled(VideoEditorConstants.clipSpeedRampPointCount, 1),
);

/// One-tap speed ramps, each with [VideoEditorConstants.clipSpeedRampPointCount]
/// evenly spaced points so a preset can be fine-tuned point by point.
enum ClipSpeedRampPreset {
  /// Speeds up, slows right down and speeds up again.
  montage([1, 2.5, 0.4, 2.5, 1]),

  /// Fast, a short deep slow-motion on the peak, fast again.
  hero([2.5, 2.5, 0.3, 2.5, 2.5]),

  /// A long slow-motion between two fast ends.
  bullet([2, 0.3, 0.3, 0.3, 2]),

  /// Starts fast and settles into normal speed.
  flashIn([3, 1.5, 1, 1, 1]),

  /// Plays at normal speed and rushes out at the end.
  flashOut([1, 1, 1, 1.5, 3]);

  const ClipSpeedRampPreset(this.speeds);

  /// The speed at each point, from the clip's first frame to its last.
  final List<double> speeds;

  /// This preset as a speed ramp.
  VideoSpeedRamp get ramp => evenlySpacedSpeedRamp(speeds);

  /// The preset [ramp] is, or `null` for a custom curve.
  static ClipSpeedRampPreset? of(VideoSpeedRamp ramp) {
    for (final preset in values) {
      if (preset.ramp == ramp) return preset;
    }
    return null;
  }
}
