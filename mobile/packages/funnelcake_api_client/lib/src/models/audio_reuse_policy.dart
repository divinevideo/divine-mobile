// ABOUTME: Action-time server decision for a selected video's audio reuse.
// ABOUTME: Models the creator takedown signal and its short validity lease.

import 'package:meta/meta.dart';

@immutable
/// The server's fresh reuse decision for one selected video.
class AudioReusePolicy {
  /// Creates an audio reuse policy response.
  const AudioReusePolicy({
    required this.videoFound,
    required this.verifiedArchive,
    required this.archiveAudioReuseEnabled,
    required this.audioReuseSuppressed,
    required this.allowAudioReuse,
    required this.validFor,
  });

  /// Parses the Funnelcake response, rejecting missing or non-boolean fields.
  factory AudioReusePolicy.fromRefreshJson(
    Map<String, dynamic> json, {
    required Duration elapsed,
  }) {
    final policies = json['policies'];
    final evaluatedAt = DateTime.tryParse(
      json['evaluated_at']?.toString() ?? '',
    );
    final validUntil = DateTime.tryParse(json['valid_until']?.toString() ?? '');
    if (policies is! List ||
        policies.length != 1 ||
        policies.single is! Map<String, dynamic> ||
        evaluatedAt == null ||
        validUntil == null) {
      throw const FormatException('Invalid audio reuse policy response');
    }
    final policy = policies.single as Map<String, dynamic>;
    final videoFound = policy['video_found'];
    final verifiedArchive = policy['verified_archive'];
    final archiveAudioReuseEnabled = policy['archive_audio_reuse_enabled'];
    final audioReuseSuppressed = policy['audio_reuse_suppressed'];
    final allowAudioReuse = policy['allow_audio_reuse'];
    final validFor = validUntil.difference(evaluatedAt) - elapsed;
    if (videoFound is! bool ||
        verifiedArchive is! bool ||
        archiveAudioReuseEnabled is! bool ||
        audioReuseSuppressed is! bool ||
        allowAudioReuse is! bool) {
      throw const FormatException('Invalid audio reuse policy response');
    }
    if (validFor <= Duration.zero) {
      throw const FormatException('Expired audio reuse policy response');
    }
    return AudioReusePolicy(
      videoFound: videoFound,
      verifiedArchive: verifiedArchive,
      archiveAudioReuseEnabled: archiveAudioReuseEnabled,
      audioReuseSuppressed: audioReuseSuppressed,
      allowAudioReuse: allowAudioReuse,
      validFor: validFor,
    );
  }

  /// Whether the logical video coordinate currently resolves.
  final bool videoFound;

  /// Whether Funnelcake authoritatively verified this as an archive video.
  final bool verifiedArchive;

  /// Whether server-side archive audio reuse rollout is enabled.
  final bool archiveAudioReuseEnabled;

  /// Whether an explicit creator takedown blocks new reuse.
  final bool audioReuseSuppressed;

  /// Final server-authoritative permission for non-owner reuse.
  final bool allowAudioReuse;

  /// Remaining server-issued lease after request time is subtracted.
  final Duration validFor;
}
