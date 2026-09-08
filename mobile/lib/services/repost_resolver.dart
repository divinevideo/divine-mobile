// ABOUTME: Resolves Nostr kind 16 repost events to their original video content.
// ABOUTME: Provides clean abstraction for repost handling with caching and relay fetching.

import 'dart:async';

import 'package:models/models.dart' hide LogCategory, NIP71VideoKinds;
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

/// Callback to subscribe to Nostr events
typedef NostrSubscribe = Stream<Event> Function(List<Filter> filters);

/// Resolves kind 16 repost events to their original video content
class RepostResolver {
  RepostResolver({
    required NostrSubscribe subscribe,
    required VideoByAddressableLookup findByAddressable,
    required VideoByIdLookup findById,
  }) : _subscribe = subscribe,
       _findByAddressable = findByAddressable,
       _findById = findById;

  final NostrSubscribe _subscribe;
  final VideoByAddressableLookup _findByAddressable;
  final VideoByIdLookup _findById;

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
    return (kind: kind, pubkey: parts[1], dTag: parts[2]);
  }

  /// Check if a repost event is likely to reference video content
  bool isLikelyVideoRepost(Event repostEvent) {
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

    // Check for 'k' tag indicating original event kind
    for (final tag in repostEvent.tags) {
      if (tag.isNotEmpty && tag[0] == 'k' && tag.length > 1) {
        final referencedKind = int.tryParse(tag[1]);
        if (referencedKind != null &&
            NIP71VideoKinds.isVideoKind(referencedKind)) {
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
  /// If fetchFromRelay is true and original not cached, fetches from relay.
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

    // Try addressable ID first (kind:pubkey:d-tag format)
    if (tags.addressableId != null) {
      final result = await _resolveByAddressable(
        tags.addressableId!,
        repostEvent,
        fetchFromRelay: fetchFromRelay,
        timeout: timeout,
      );
      if (result != null) return result;
    }

    // Try event ID
    if (tags.eventId != null) {
      final result = await _resolveByEventId(
        tags.eventId!,
        repostEvent,
        fetchFromRelay: fetchFromRelay,
        timeout: timeout,
      );
      if (result != null) return result;
    }

    Log.debug(
      '⏩ Repost has no resolvable reference: ${repostEvent.id}',
      name: 'RepostResolver',
      category: LogCategory.video,
    );
    return null;
  }

  Future<VideoEvent?> _resolveByAddressable(
    String addressableId,
    Event repostEvent, {
    required bool fetchFromRelay,
    required Duration timeout,
  }) async {
    final parsed = parseAddressableId(addressableId);
    if (parsed == null || !NIP71VideoKinds.isVideoKind(parsed.kind)) {
      return null;
    }

    // Check cache first
    final cached = _findByAddressable(parsed.pubkey, parsed.dTag);
    if (cached != null) {
      return createRepostVideoEvent(cached, repostEvent);
    }

    if (!fetchFromRelay) return null;

    // Fetch from relay
    return _fetchAddressableEvent(addressableId, repostEvent, timeout);
  }

  Future<VideoEvent?> _resolveByEventId(
    String eventId,
    Event repostEvent, {
    required bool fetchFromRelay,
    required Duration timeout,
  }) async {
    // Check cache first
    final cached = _findById(eventId);
    if (cached != null) {
      return createRepostVideoEvent(cached, repostEvent);
    }

    if (!fetchFromRelay) return null;

    // Fetch from relay
    return _fetchEventById(eventId, repostEvent, timeout);
  }

  Future<VideoEvent?> _fetchAddressableEvent(
    String addressableId,
    Event repostEvent,
    Duration timeout,
  ) async {
    final parsed = parseAddressableId(addressableId);
    if (parsed == null) return null;

    final filter = Filter(
      kinds: [parsed.kind],
      authors: [parsed.pubkey],
      d: [parsed.dTag],
      limit: 1,
    );

    return _fetchAndResolve(filter, repostEvent, timeout);
  }

  Future<VideoEvent?> _fetchEventById(
    String eventId,
    Event repostEvent,
    Duration timeout,
  ) async {
    final filter = Filter(ids: [eventId]);
    return _fetchAndResolve(filter, repostEvent, timeout);
  }

  Future<VideoEvent?> _fetchAndResolve(
    Filter filter,
    Event repostEvent,
    Duration timeout,
  ) async {
    final completer = Completer<VideoEvent?>();

    late StreamSubscription<Event> subscription;
    subscription = _subscribe([filter]).listen(
      (originalEvent) {
        if (!NIP71VideoKinds.isVideoKind(originalEvent.kind)) {
          return;
        }

        try {
          final originalVideo = VideoEvent.fromNostrEvent(originalEvent);
          if (originalVideo.hasVideo) {
            final repostVideo = createRepostVideoEvent(
              originalVideo,
              repostEvent,
            );
            if (!completer.isCompleted) {
              completer.complete(repostVideo);
            }
          }
        } catch (e) {
          Log.error(
            'Failed to parse original video for repost: $e',
            name: 'RepostResolver',
            category: LogCategory.video,
          );
        }
        subscription.cancel();
      },
      onError: (error) {
        Log.error(
          'Error fetching original for repost: $error',
          name: 'RepostResolver',
          category: LogCategory.video,
        );
        if (!completer.isCompleted) {
          completer.complete(null);
        }
        subscription.cancel();
      },
      onDone: () {
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      },
    );

    // Timeout handling
    return completer.future.timeout(
      timeout,
      onTimeout: () {
        subscription.cancel();
        Log.debug(
          'Timeout fetching original for repost ${repostEvent.id}',
          name: 'RepostResolver',
          category: LogCategory.video,
        );
        return null;
      },
    );
  }
}
