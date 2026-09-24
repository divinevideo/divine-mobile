import 'package:meta/meta.dart';

/// A sound (Kind 1063 audio event) with how many videos use it, as returned
/// by the FunnelCake sound endpoints.
@immutable
class SoundStats {
  /// Creates a [SoundStats].
  const SoundStats({
    required this.id,
    required this.pubkey,
    required this.title,
    required this.createdAt,
    required this.usageCount,
  });

  /// Parses one entry of a FunnelCake sound list.
  factory SoundStats.fromJson(Map<String, dynamic> json) {
    final createdAtSeconds = (json['created_at'] as num?)?.toInt() ?? 0;
    return SoundStats(
      id: json['id'] as String? ?? '',
      pubkey: json['pubkey'] as String? ?? '',
      title: json['title'] as String? ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        createdAtSeconds * 1000,
        isUtc: true,
      ),
      usageCount: (json['usage_count'] as num?)?.toInt() ?? 0,
    );
  }

  /// The audio event id.
  final String id;

  /// The public key that published the sound.
  final String pubkey;

  /// The sound's title; empty when the event carries none.
  final String title;

  /// When the audio event was created.
  final DateTime createdAt;

  /// How many video events reference this sound as their audio, including
  /// the video an original sound was extracted from.
  final int usageCount;

  @override
  bool operator ==(Object other) =>
      other is SoundStats &&
      other.id == id &&
      other.pubkey == pubkey &&
      other.title == title &&
      other.createdAt == createdAt &&
      other.usageCount == usageCount;

  @override
  int get hashCode => Object.hash(id, pubkey, title, createdAt, usageCount);
}
