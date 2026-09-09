// ABOUTME: Server-side audio reuse suppression decision for a video blob.
// ABOUTME: Keeps creator opt-outs separate from event-level reuse metadata.

import 'package:meta/meta.dart';

@immutable
/// The server's current decision for reuse of one content-addressed video.
class AudioReusePolicy {
  /// Creates an audio reuse policy response.
  const AudioReusePolicy({
    required this.allowAudioReuse,
    required this.audioReuseSuppressed,
  });

  /// Parses the Funnelcake response, rejecting missing or non-boolean fields.
  factory AudioReusePolicy.fromJson(Map<String, dynamic> json) {
    final allowAudioReuse = json['allow_audio_reuse'];
    final audioReuseSuppressed = json['audio_reuse_suppressed'];
    if (allowAudioReuse is! bool || audioReuseSuppressed is! bool) {
      throw const FormatException('Invalid audio reuse policy response');
    }
    return AudioReusePolicy(
      allowAudioReuse: allowAudioReuse,
      audioReuseSuppressed: audioReuseSuppressed,
    );
  }

  /// Whether the source's event terms allow audio reuse.
  final bool allowAudioReuse;

  /// Whether a creator opt-out overrides otherwise permissive event terms.
  final bool audioReuseSuppressed;
}
