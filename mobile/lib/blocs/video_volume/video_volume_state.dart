part of 'video_volume_cubit.dart';

/// State for [VideoVolumeCubit].
///
/// Volume is binary: `1.0` (unmuted) or `0.0` (muted). The actual loudness
/// is controlled by the device's hardware volume.
class VideoVolumeState extends Equatable {
  const VideoVolumeState({this.volume = 1.0, this.mutedBySystem = false});

  /// Desired playback volume (0.0 = muted, 1.0 = full).
  final double volume;

  /// Whether hardware volume may restore sound after a system-driven mute.
  final bool mutedBySystem;

  /// Whether playback is currently muted.
  bool get isMuted => volume == 0;

  @override
  List<Object?> get props => [volume, mutedBySystem];
}
