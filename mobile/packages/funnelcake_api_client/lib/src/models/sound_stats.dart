import 'package:meta/meta.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

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
    this.event,
    this.sourceEventKnown = false,
    this.sourceEvent,
  });

  /// Parses one entry of a FunnelCake sound list.
  factory SoundStats.fromJson(Map<String, dynamic> json) {
    final createdAtSeconds = (json['created_at'] as num?)?.toInt() ?? 0;
    final rawSource = json['source_event'];
    final sourceEvent = _signedEvent(rawSource);
    return SoundStats(
      id: json['id'] as String? ?? '',
      pubkey: json['pubkey'] as String? ?? '',
      title: json['title'] as String? ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        createdAtSeconds * 1000,
        isUtc: true,
      ),
      usageCount: (json['usage_count'] as num?)?.toInt() ?? 0,
      event: _signedEvent(json['event']),
      // A source the server sent but this client cannot read is as unknown
      // as one it did not send, not a video that is gone.
      sourceEventKnown:
          json.containsKey('source_event') &&
          (rawSource == null || sourceEvent != null),
      sourceEvent: sourceEvent,
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

  /// How many video events referencing this sound as their audio FunnelCake
  /// has stored, including the video an original sound was extracted from.
  ///
  /// Every stored version of a republished video counts again, and a deleted
  /// video is never subtracted, so this can exceed the videos still using
  /// the sound. Treat it as an upper bound, not a figure to show.
  final int usageCount;

  /// The sound's own event as the relay stores it, with its tags, content
  /// and signature; `null` when the server sent none, as older ones do.
  final Event? event;

  /// Whether the server said which video the sound came from: [sourceEvent],
  /// or that there is no visible one.
  ///
  /// `false` when it did not say, because it is older or its lookup failed;
  /// the video is then unknown, not gone.
  final bool sourceEventKnown;

  /// The current version of the video the first video `a` tag of [event]
  /// names, as the relay stores it.
  ///
  /// When [sourceEventKnown], `null` means the sound names no video, or the
  /// server does not show the video's current version to the public:
  /// deleted, moderated, unplayable, or by an author who is not public.
  final Event? sourceEvent;

  @override
  bool operator ==(Object other) =>
      other is SoundStats &&
      other.id == id &&
      other.pubkey == pubkey &&
      other.title == title &&
      other.createdAt == createdAt &&
      other.usageCount == usageCount &&
      other.event?.id == event?.id &&
      other.sourceEventKnown == sourceEventKnown &&
      other.sourceEvent?.id == sourceEvent?.id;

  @override
  int get hashCode => Object.hash(
    id,
    pubkey,
    title,
    createdAt,
    usageCount,
    event?.id,
    sourceEventKnown,
    sourceEvent?.id,
  );
}

/// [json] as a signed event, or `null` when it is not one: missing, or with
/// a field of the wrong type, which [Event.fromJson] would throw on.
Event? _signedEvent(Object? json) {
  if (json is! Map<String, dynamic>) return null;
  final tags = json['tags'];
  final wellFormed =
      json['id'] is String &&
      json['pubkey'] is String &&
      json['created_at'] is int &&
      json['kind'] is int &&
      json['content'] is String &&
      json['sig'] is String &&
      tags is List &&
      tags.every((tag) => tag is List && tag.every((value) => value is String));
  return wellFormed ? Event.fromJson(json) : null;
}
