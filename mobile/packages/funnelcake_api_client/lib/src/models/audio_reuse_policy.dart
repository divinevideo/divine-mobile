// ABOUTME: Action-time server decision for a selected video's audio reuse.
// ABOUTME: Models the creator takedown signal and its short validity lease.

import 'package:meta/meta.dart';

@immutable
/// The server's fresh suppression decision for one selected video.
class AudioReusePolicy {
  /// Creates an audio reuse policy response.
  const AudioReusePolicy({
    required this.audioReuseSuppressed,
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
    final audioReuseSuppressed =
        (policies.single as Map<String, dynamic>)['audio_reuse_suppressed'];
    final validFor = validUntil.difference(evaluatedAt) - elapsed;
    if (audioReuseSuppressed is! bool || validFor <= Duration.zero) {
      throw const FormatException('Expired audio reuse policy response');
    }
    return AudioReusePolicy(
      audioReuseSuppressed: audioReuseSuppressed,
      validFor: validFor,
    );
  }

  /// Whether an explicit creator takedown blocks new reuse.
  final bool audioReuseSuppressed;

  /// Remaining server-issued lease after request time is subtracted.
  final Duration validFor;
}
