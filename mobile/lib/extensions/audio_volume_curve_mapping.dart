import 'package:divine_video_player/divine_video_player.dart' as player;
import 'package:pro_video_editor/pro_video_editor.dart' show AudioVolumeCurve;

/// Hands a sound's [AudioVolumeCurve] to the preview player as the same
/// points the export bakes in, so the preview dips where the posted video
/// does.
extension AudioVolumeCurveMapping on AudioVolumeCurve {
  /// The preview player's volume curve.
  List<player.AudioTrackVolumePoint> toPlayerVolumeCurve() => [
    for (final point in points)
      player.AudioTrackVolumePoint(time: point.time, volume: point.volume),
  ];
}
