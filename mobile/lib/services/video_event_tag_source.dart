// ABOUTME: Shared helpers for sourcing raw Nostr tags before republishing.
// ABOUTME: Recovers tags from the personal cache when JSON rehydration omits them.

import 'package:models/models.dart' show VideoEvent;
import 'package:nostr_client/nostr_client.dart' show Nip89ClientTag;
import 'package:openvine/services/personal_event_cache_service.dart';

/// Returns the raw tags for [video], recovering them from [personalEventCache]
/// when the in-memory copy came from a JSON snapshot that omits raw tags.
///
/// Any NIP-89 `client` tag is left out: a republish is Divine's own publish,
/// and the signing path stamps attribution from the current preference, so
/// carrying the old tag forward would keep advertising a client the user has
/// since switched off, or another client entirely (#8176).
List<List<String>> sourceOriginalVideoTags({
  required VideoEvent video,
  required PersonalEventCacheService? personalEventCache,
}) => Nip89ClientTag.withoutClientTag(_rawTags(video, personalEventCache));

List<List<String>> _rawTags(
  VideoEvent video,
  PersonalEventCacheService? personalEventCache,
) {
  if (video.nostrEventTags.isNotEmpty) return video.nostrEventTags;
  final cached = personalEventCache?.getEventById(video.id);
  if (cached == null) return const [];
  return cached.tags
      .map((tag) => (tag as List).map((e) => e.toString()).toList())
      .toList();
}
