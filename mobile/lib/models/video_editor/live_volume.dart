import 'package:equatable/equatable.dart';

/// A volume the user is still dragging, before it is committed to the editor.
///
/// The preview player follows it at once; the clip or track only takes it
/// when the finger lifts, so a drag is a single undo step.
class LiveVolume extends Equatable {
  /// The volume of the clip with [clipId].
  const LiveVolume.clip(String this.clipId, this.volume, {this.session})
    : trackId = null;

  /// The volume of the audio track with [trackId].
  const LiveVolume.track(String this.trackId, this.volume, {this.session})
    : clipId = null;

  /// The clip being adjusted, or null for an audio track.
  final String? clipId;

  /// The audio track being adjusted, or null for a clip.
  final String? trackId;

  /// The volume under the finger, above 1 when boosted.
  final double volume;

  /// Identity of the drag that owns this preview, including equal-valued drags.
  final Object? session;

  @override
  List<Object?> get props => [clipId, trackId, volume, session];
}
