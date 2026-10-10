import 'package:divine_video_player/divine_video_player.dart' as player;
import 'package:openvine/extensions/equalizer_settings_mapping.dart';
import 'package:openvine/models/divine_video_clip.dart';

/// Maps an editor [DivineVideoClip] onto the native preview player's
/// [player.VideoClip], carrying the clip's trim, volume, equalizer and speed.
///
/// Transitions are not passed to the player: the preview composites them by
/// playing a pre-rendered seam clip between the (trimmed) neighbours rather
/// than blending live. See `TransitionSeamRenderService`.
extension DivineVideoClipPlayerMapping on DivineVideoClip {
  /// Returns the preview-player clip for this editor clip, or `null` when the
  /// clip has no resolvable file path (skipped by the timeline).
  player.VideoClip? toPlayerVideoClip({Duration? start, Duration? end}) {
    final path = video?.file?.path;
    if (path == null) return null;
    return player.VideoClip(
      uri: path,
      start: start ?? trimStart,
      end: end ?? (duration - trimEnd),
      volume: volume,
      equalizer: equalizer.toPlayerEqualizer(),
      playbackSpeed: playbackSpeed ?? 1.0,
    );
  }
}
