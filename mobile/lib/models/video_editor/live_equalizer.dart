import 'package:equatable/equatable.dart';
import 'package:models/models.dart' show EqualizerSettings;

/// An equalizer the user is still changing, before it is committed to the
/// editor.
///
/// The preview player follows it at once; the clip or track only takes it
/// when the equalizer sheet is confirmed, so a session of changes is a single
/// undo step.
class LiveEqualizer extends Equatable {
  /// The equalizer of the clip with [clipId].
  const LiveEqualizer.clip(String this.clipId, this.settings) : trackId = null;

  /// The equalizer of the audio track with [trackId].
  const LiveEqualizer.track(String this.trackId, this.settings) : clipId = null;

  /// The clip being adjusted, or null for an audio track.
  final String? clipId;

  /// The audio track being adjusted, or null for a clip.
  final String? trackId;

  /// The settings to play.
  final EqualizerSettings settings;

  @override
  List<Object?> get props => [clipId, trackId, settings];
}
