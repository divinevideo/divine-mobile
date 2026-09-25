// ABOUTME: Rebuilds a held scheduled event's content and tags for a new
// ABOUTME: publish time, so it can be re-signed without re-running the
// ABOUTME: upload or the tag builders (#3538).

import 'package:nostr_sdk/event.dart';

/// The unsigned body of a scheduled event moved to a new publish time.
typedef RestampedScheduledEvent = ({String content, List<List<String>> tags});

/// Moves [source] to [createdAt]: same `d` tag, media, credits and proof
/// tags, with `published_at` replaced and the NIP-40 `expiration` recomputed
/// from [expireAfterSecs] (dropped when null). Both are rewritten where they
/// stand, because tag order is part of the event id: a restamp to the time
/// [source] already has rebuilds it exactly, so the caller can tell that
/// no-op from a real move by the signed id. Any other time mints a new id.
RestampedScheduledEvent restampScheduledEvent(
  Event source, {
  required int createdAt,
  int? expireAfterSecs,
}) {
  final publishedAt = ['published_at', createdAt.toString()];
  final expiration = expireAfterSecs == null
      ? null
      : ['expiration', (createdAt + expireAfterSecs).toString()];
  var wrotePublishedAt = false;
  var wroteExpiration = false;
  final tags = <List<String>>[];
  for (final tag in source.tags) {
    if (tag.isEmpty) continue;
    switch (tag[0]) {
      case 'published_at':
        if (wrotePublishedAt) continue;
        tags.add(publishedAt);
        wrotePublishedAt = true;
      case 'expiration':
        if (expiration == null || wroteExpiration) continue;
        tags.add(expiration);
        wroteExpiration = true;
      default:
        tags.add(List<String>.of(tag));
    }
  }
  if (!wrotePublishedAt) tags.add(publishedAt);
  if (expiration != null && !wroteExpiration) tags.add(expiration);
  return (content: source.content, tags: tags);
}
