// ABOUTME: Resolves Nostr kind 16 repost events to their original video content.
// ABOUTME: Provides clean abstraction for repost handling with caching and relay fetching.

import 'package:models/models.dart' hide NIP71VideoKinds;
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/constants/nip71_migration.dart';
import 'package:unified_logger/unified_logger.dart';

/// References extracted from repost event tags ('e' and 'a' tags)
typedef RepostTagRefs = ({String? eventId, String? addressableId});

/// Parsed components of an addressable ID (kind:pubkey:d-tag format)
typedef AddressableIdParts = ({int kind, String pubkey, String dTag});

/// Callback to lookup cached videos by addressable reference
typedef VideoByAddressableLookup = VideoEvent? Function(
  String pubkey,
  String dTag,
);

/// Callback to lookup cached videos by event ID
typedef VideoByIdLookup = VideoEvent? Function(String eventId);

/// Result of a bounded Nostr query.
typedef NostrQueryResult = ({List<Event> events, bool timedOut, bool noRelays});

/// Callback to run a bounded Nostr query.
typedef NostrQuery = Future<NostrQueryResult> Function(
  List<Filter> filters, {
  required Duration timeout,
  required bool requireAllRelaysSettled,
});

class _MissRecord {
  const _MissRecord({required this.recordedAt, required this.conclusive});

  final DateTime recordedAt;
  final bool conclusive;
}

/// Resolves kind 16 repost events to their original video content
class RepostResolver {
  RepostResolver({
    required NostrQuery queryEvents,
    required VideoByAddressableLookup findByAddressable,
    required VideoByIdLookup findById,
    DateTime Function()? now,
    Duration missTtl = const Duration(minutes: 10),
    Duration inconclusiveMissTtl = const Duration(seconds: 30),
  }) : _queryEvents = queryEvents,
       _findByAddressable = findByAddressable,
       _findById = findById,
       _now = now ?? DateTime.now,
       _missTtl = missTtl,
       _inconclusiveMissTtl = inconclusiveMissTtl;

  static const _maxMissEntries = 512;

  final NostrQuery _queryEvents;
  final VideoByAddressableLookup _findByAddressable;
  final VideoByIdLookup _findById;
  final DateTime Function() _now;
  final Duration _missTtl;
  final Duration _inconclusiveMissTtl;
  final Map<String, _MissRecord> _misses = {};
  final Map<String, Future<NostrQueryResult>> _inFlightQueries = {};

  static const _videoKeywords = [
    'video',
    'gif',
    'mp4',
    'webm',
    'mov',
    'vine',
    'clip',
    'watch',
  ];

  /// Extract 'e' and 'a' tag references from a repost event
  RepostTagRefs extractTags(Event event) {
    String? eventId;
    String? addressableId;
    for (final tag in event.tags) {
      if (tag.isNotEmpty && tag.length > 1) {
        if (tag[0] == 'e') {
          eventId = tag[1];
        } else if (tag[0] == 'a') {
          addressableId = tag[1];
        }
      }
    }
    return (eventId: eventId, addressableId: addressableId);
  }

  /// Parse addressable ID format: kind:pubkey:d-tag
  AddressableIdParts? parseAddressableId(String addressableId) {
    final parts = addressableId.split(':');
    if (parts.length < 3) return null;
    final kind = int.tryParse(parts[0]);
    if (kind == null) return null;
    return (kind: kind, pubkey: parts[1], dTag: parts.sublist(2).join(':'));
  }

  /// Check if a repost event is likely to reference video content
  bool isLikelyVideoRepost(Event repostEvent) {
    // An explicit, valid kind is authoritative. Missing or malformed kind tags
    // keep the permissive fallback used for older reposts.
    for (final tag in repostEvent.tags) {
      if (tag.length > 1 && tag[0] == 'k') {
        final referencedKind = int.tryParse(tag[1]);
        if (referencedKind != null) {
          return NIP71VideoKinds.isVideoKind(referencedKind);
        }
      }
    }

    final content = repostEvent.content.toLowerCase();

    // Check content for video-related keywords
    if (_videoKeywords.any(content.contains)) {
      return true;
    }

    // Check tags for video-related hashtags
    for (final tag in repostEvent.tags) {
      if (tag.isNotEmpty && tag[0] == 't' && tag.length > 1) {
        final hashtag = tag[1].toLowerCase();
        if (_videoKeywords.any(hashtag.contains)) {
          return true;
        }
      }
    }

    // Default to processing all reposts to avoid missing content
    return true;
  }

  /// Create a repost VideoEvent from original video and repost event
  VideoEvent createRepostVideoEvent(VideoEvent original, Event repostEvent) {
    return VideoEvent.createRepostEvent(
      originalEvent: original,
      repostEventId: repostEvent.id,
      reposterPubkey: repostEvent.pubkey,
      repostedAt: DateTime.fromMillisecondsSinceEpoch(
        repostEvent.createdAt * 1000,
      ),
    );
  }

  /// Resolve a kind 16 repost to a VideoEvent
  ///
  /// Returns the resolved video event, or null if:
  /// - Not a likely video repost
  /// - Original video not found in cache and fetchFromRelay is false
  ///
  /// If [fetchFromRelay] is true and the original is not cached, performs one
  /// bounded query for every unresolved reference. Relay misses are cached for
  /// a short period when settlement is inconclusive and longer when every
  /// serving relay settles the query.
  Future<VideoEvent?> resolve(
    Event repostEvent, {
    bool fetchFromRelay = true,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (!isLikelyVideoRepost(repostEvent)) {
      Log.debug(
        '⏩ Skipping non-video repost: ${repostEvent.id}',
        name: 'RepostResolver',
        category: LogCategory.video,
      );
      return null;
    }

    final tags = extractTags(repostEvent);

    final addressableId = tags.addressableId;
    final addressable = addressableId == null
        ? null
        : parseAddressableId(addressableId);
    final hasUsableAddressable =
        addressable != null && NIP71VideoKinds.isVideoKind(addressable.kind);

    if (hasUsableAddressable) {
      final cached = _findByAddressable(addressable.pubkey, addressable.dTag);
      if (cached != null) {
        return createRepostVideoEvent(cached, repostEvent);
      }
    }

    final eventId = tags.eventId;
    if (eventId != null) {
      final cached = _findById(eventId);
      if (cached != null) {
        return createRepostVideoEvent(cached, repostEvent);
      }
    }

    if (!fetchFromRelay) return null;

    final filters = <Filter>[];
    final missKeys = <String>[];
    if (hasUsableAddressable &&
        !_hasActiveMiss(_addressableMissKey(addressableId!))) {
      filters.add(
        Filter(
          kinds: [addressable.kind],
          authors: [addressable.pubkey],
          d: [addressable.dTag],
          limit: 1,
        ),
      );
      missKeys.add(_addressableMissKey(addressableId));
    }
    if (eventId != null && !_hasActiveMiss(_eventMissKey(eventId))) {
      filters.add(
        Filter(
          ids: [eventId],
          kinds: NIP71VideoKinds.getAllVideoKinds(),
          limit: 1,
        ),
      );
      missKeys.add(_eventMissKey(eventId));
    }

    if (filters.isEmpty) return null;

    NostrQueryResult queryResult;
    try {
      queryResult = await _runCoalescedQuery(filters, missKeys, timeout);
    } catch (error) {
      Log.error(
        'Error fetching original for repost: $error',
        name: 'RepostResolver',
        category: LogCategory.video,
      );
      _recordMisses(missKeys, conclusive: false);
      return null;
    }

    final resolved = _resolveQueryEvents(
      queryResult.events,
      repostEvent,
      addressable: hasUsableAddressable ? addressable : null,
      eventId: eventId,
    );
    if (resolved != null) {
      missKeys.forEach(_misses.remove);
      return resolved;
    }

    _recordMisses(
      missKeys,
      conclusive: !queryResult.timedOut && !queryResult.noRelays,
    );

    Log.debug(
      '⏩ Repost has no resolvable reference: ${repostEvent.id}',
      name: 'RepostResolver',
      category: LogCategory.video,
    );
    return null;
  }

  Future<NostrQueryResult> _runCoalescedQuery(
    List<Filter> filters,
    List<String> missKeys,
    Duration timeout,
  ) async {
    final sortedKeys = [...missKeys]..sort();
    final encodedKeys = sortedKeys.map((key) => '${key.length}:$key').join();
    final queryKey = '${timeout.inMicroseconds}:$encodedKeys';
    final existing = _inFlightQueries[queryKey];
    if (existing != null) return existing;

    final query = _queryEvents(
      filters,
      timeout: timeout,
      requireAllRelaysSettled: true,
    );
    _inFlightQueries[queryKey] = query;
    try {
      return await query;
    } finally {
      if (identical(_inFlightQueries[queryKey], query)) {
        _inFlightQueries.remove(queryKey);
      }
    }
  }

  VideoEvent? _resolveQueryEvents(
    List<Event> events,
    Event repostEvent, {
    required AddressableIdParts? addressable,
    required String? eventId,
  }) {
    final candidates = <Event>[
      if (addressable != null)
        ...events.where((event) => _matchesAddressable(event, addressable)),
      if (eventId != null) ...events.where((event) => event.id == eventId),
    ];

    for (final event in candidates) {
      if (!NIP71VideoKinds.isVideoKind(event.kind)) continue;
      try {
        final original = VideoEvent.fromNostrEvent(event);
        if (original.hasVideo) {
          return createRepostVideoEvent(original, repostEvent);
        }
      } catch (error) {
        Log.error(
          'Failed to parse original video for repost: $error',
          name: 'RepostResolver',
          category: LogCategory.video,
        );
      }
    }
    return null;
  }

  bool _matchesAddressable(Event event, AddressableIdParts addressable) {
    if (event.kind != addressable.kind || event.pubkey != addressable.pubkey) {
      return false;
    }
    return event.tags.any(
      (tag) => tag.length > 1 && tag[0] == 'd' && tag[1] == addressable.dTag,
    );
  }

  bool _hasActiveMiss(String key) {
    final miss = _misses[key];
    if (miss == null) return false;
    final ttl = miss.conclusive ? _missTtl : _inconclusiveMissTtl;
    if (_now().isBefore(miss.recordedAt.add(ttl))) return true;
    _misses.remove(key);
    return false;
  }

  void _recordMisses(List<String> keys, {required bool conclusive}) {
    final recordedAt = _now();
    for (final key in keys) {
      _misses
        ..remove(key)
        ..[key] = _MissRecord(recordedAt: recordedAt, conclusive: conclusive);
    }
    while (_misses.length > _maxMissEntries) {
      _misses.remove(_misses.keys.first);
    }
  }

  String _addressableMissKey(String addressableId) => 'a:$addressableId';

  String _eventMissKey(String eventId) => 'e:$eventId';
}
