// ABOUTME: Action-time server decision for a selected video's audio reuse.
// ABOUTME: Models the creator takedown signal and its short validity lease.

import 'package:meta/meta.dart';

@immutable
/// The server's fresh reuse decision for one selected video.
class AudioReusePolicy {
  /// Creates an audio reuse policy response.
  const AudioReusePolicy({
    required this.allowAudioReuse,
    this.videoFound = true,
    this.audioReuseSuppressed = false,
    this.verifiedArchive = false,
  });

  /// Parses the Funnelcake response, rejecting missing or non-boolean fields.
  factory AudioReusePolicy.fromRefreshJson(
    Map<String, dynamic> json, {
    required Duration elapsed,
  }) => listFromRefreshJson(json, count: 1, elapsed: elapsed).single;

  factory AudioReusePolicy._fromJson(Object? policy) {
    if (policy is! Map<String, dynamic>) {
      throw const FormatException('Invalid audio reuse policy response');
    }
    final videoFound = policy['video_found'];
    final verifiedArchive = policy['verified_archive'];
    final archiveAudioReuseEnabled = policy['archive_audio_reuse_enabled'];
    final audioReuseSuppressed = policy['audio_reuse_suppressed'];
    final allowAudioReuse = policy['allow_audio_reuse'];
    if (videoFound is! bool ||
        verifiedArchive is! bool ||
        archiveAudioReuseEnabled is! bool ||
        audioReuseSuppressed is! bool ||
        allowAudioReuse is! bool) {
      throw const FormatException('Invalid audio reuse policy response');
    }
    return AudioReusePolicy(
      allowAudioReuse: allowAudioReuse,
      videoFound: videoFound,
      audioReuseSuppressed: audioReuseSuppressed,
      verifiedArchive: verifiedArchive,
    );
  }

  /// Parses a response asked about [count] videos, in the order asked.
  ///
  /// Rejects a response holding another number of policies, missing or
  /// non-boolean fields, or a validity interval [elapsed] has used up.
  static List<AudioReusePolicy> listFromRefreshJson(
    Map<String, dynamic> json, {
    required int count,
    required Duration elapsed,
  }) {
    final policies = json['policies'];
    final evaluatedAt = DateTime.tryParse(
      json['evaluated_at']?.toString() ?? '',
    );
    final validUntil = DateTime.tryParse(json['valid_until']?.toString() ?? '');
    if (policies is! List ||
        policies.length != count ||
        evaluatedAt == null ||
        validUntil == null) {
      throw const FormatException('Invalid audio reuse policy response');
    }
    if (validUntil.difference(evaluatedAt) - elapsed <= Duration.zero) {
      throw const FormatException('Expired audio reuse policy response');
    }
    return [for (final policy in policies) AudioReusePolicy._fromJson(policy)];
  }

  /// Whether the selected logical video exists on the policy server.
  final bool videoFound;

  /// Whether an active takedown suppresses reuse even with creator consent.
  final bool audioReuseSuppressed;

  /// Whether this source follows the separate classic-audio policy.
  final bool verifiedArchive;

  /// Final server-authoritative permission for non-owner reuse.
  final bool allowAudioReuse;
}
