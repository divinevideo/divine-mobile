// ABOUTME: Unified async resolver for fetching a VideoEvent by event id.
// ABOUTME: Tries in-memory VideoEventService, then personal event cache, then relay.

import 'dart:async';

import 'package:models/models.dart' hide LogCategory, NIP71VideoKinds;
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/constants/nip71_migration.dart';
import 'package:openvine/services/personal_event_cache_service.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:unified_logger/unified_logger.dart';

/// Callback to subscribe to Nostr events.
typedef NostrSubscribeById = Stream<Event> Function(List<Filter> filters);

/// Resolves a [VideoEvent] for a given event id, with a layered fallback:
///
/// 1. In-memory feeds via [VideoEventService.getVideoEventById]
/// 2. Personal event cache via [PersonalEventCacheService.getEventById]
/// 3. Relay fetch via [Filter.ids]
///
/// When [allowOwnContentBypass] is true and the resolved video's author
/// matches [viewerPubkeyHex], the Divine-hosted-only hide filter is bypassed
/// so the owner can always reach their own content (e.g. for editing).
///
/// See `tasks/issues/4390-unified-video-resolver.md` and issue #4390.
class VideoEventResolver {
  VideoEventResolver({
    required VideoEventService videoEventService,
    required PersonalEventCacheService personalEventCache,
    required NostrSubscribeById subscribe,
    required String? Function() viewerPubkeyHex,
  }) : _videoEventService = videoEventService,
       _personalEventCache = personalEventCache,
       _subscribe = subscribe,
       _viewerPubkeyHex = viewerPubkeyHex;

  final VideoEventService _videoEventService;
  final PersonalEventCacheService _personalEventCache;
  final NostrSubscribeById _subscribe;
  final String? Function() _viewerPubkeyHex;

  static const _logName = 'VideoEventResolver';

  /// Resolve a [VideoEvent] by its event id.
  ///
  /// Returns null if the id cannot be resolved within [timeout].
  Future<VideoEvent?> resolveById(
    String eventId, {
    bool allowOwnContentBypass = false,
    bool requireRawTags = false,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (eventId.isEmpty) return null;

    // 1) In-memory feeds.
    final cached = _videoEventService.getVideoEventById(eventId);
    if (cached != null &&
        _hasRequiredRawTags(cached, requireRawTags) &&
        _passesFilter(cached, allowOwnContentBypass)) {
      return cached;
    }

    // 2) Personal event cache.
    final cachedEvent = _personalEventCache.getEventById(eventId);
    if (cachedEvent != null) {
      final parsed = _tryParse(cachedEvent);
      if (parsed != null &&
          _hasRequiredRawTags(parsed, requireRawTags) &&
          _passesFilter(parsed, allowOwnContentBypass)) {
        return parsed;
      }
    }

    // 3) Relay fetch.
    try {
      final fetched = await _fetchFromRelay(eventId, timeout);
      if (fetched != null &&
          _hasRequiredRawTags(fetched, requireRawTags) &&
          _passesFilter(fetched, allowOwnContentBypass)) {
        return fetched;
      }
    } catch (e, st) {
      Log.error(
        'Relay fetch failed for $eventId: $e',
        name: _logName,
        category: LogCategory.video,
        error: e,
        stackTrace: st,
      );
    }

    return null;
  }

  bool _hasRequiredRawTags(VideoEvent video, bool requireRawTags) =>
      !requireRawTags || video.nostrEventTags.isNotEmpty;

  bool _passesFilter(VideoEvent video, bool allowOwnContentBypass) {
    if (allowOwnContentBypass) {
      final viewer = _viewerPubkeyHex();
      if (viewer != null && viewer == video.pubkey) {
        return true;
      }
    }
    return !_videoEventService.shouldHideVideo(video);
  }

  VideoEvent? _tryParse(Event event) {
    if (!NIP71VideoKinds.isAcceptableVideoKind(event.kind)) {
      return null;
    }
    try {
      return VideoEvent.fromNostrEvent(event, permissive: true);
    } catch (e) {
      Log.warning(
        'Failed to parse cached event ${event.id} as VideoEvent: $e',
        name: _logName,
        category: LogCategory.video,
      );
      return null;
    }
  }

  Future<VideoEvent?> _fetchFromRelay(String eventId, Duration timeout) async {
    final filter = Filter(ids: [eventId]);
    final completer = Completer<VideoEvent?>();

    late StreamSubscription<Event> subscription;
    subscription = _subscribe([filter]).listen(
      (event) {
        final parsed = _tryParse(event);
        if (parsed == null) return;
        if (!completer.isCompleted) {
          completer.complete(parsed);
        }
        unawaited(subscription.cancel());
      },
      onError: (Object error) {
        Log.error(
          'Relay error fetching $eventId: $error',
          name: _logName,
          category: LogCategory.video,
        );
        if (!completer.isCompleted) {
          completer.complete(null);
        }
        unawaited(subscription.cancel());
      },
      onDone: () {
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      },
    );

    return completer.future.timeout(
      timeout,
      onTimeout: () {
        Log.warning(
          'Timed out resolving event $eventId after ${timeout.inSeconds}s',
          name: _logName,
          category: LogCategory.video,
        );
        unawaited(subscription.cancel());
        return null;
      },
    );
  }
}
