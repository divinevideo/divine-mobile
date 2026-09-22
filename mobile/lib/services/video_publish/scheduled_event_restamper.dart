// ABOUTME: Rebuilds a held scheduled event's content and tags for a new
// ABOUTME: publish time, so it can be re-signed without re-running the
// ABOUTME: upload or the tag builders (#3538).

import 'package:nostr_sdk/event.dart';

/// The unsigned body of a scheduled event moved to a new publish time.
typedef RestampedScheduledEvent = ({String content, List<List<String>> tags});

/// Moves [source] to [createdAt]: same `d` tag, media, credits and proof
/// tags, with `published_at` replaced and the NIP-40 `expiration` recomputed
/// from [expireAfterSecs] (dropped when null). The caller signs the result,
/// which mints a new event id — a Nostr id is a hash over `created_at`, so
/// a reschedule is always a new event and the old one is cancelled.
RestampedScheduledEvent restampScheduledEvent(
  Event source, {
  required int createdAt,
  int? expireAfterSecs,
}) {
  final tags = <List<String>>[];
  for (final tag in source.tags) {
    if (tag.isEmpty) continue;
    switch (tag[0]) {
      case 'published_at':
      case 'expiration':
        continue;
      default:
        tags.add(List<String>.of(tag));
    }
  }
  tags.add(['published_at', createdAt.toString()]);
  if (expireAfterSecs != null) {
    tags.add(['expiration', (createdAt + expireAfterSecs).toString()]);
  }
  return (content: source.content, tags: tags);
}
