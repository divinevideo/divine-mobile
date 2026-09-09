// ABOUTME: Service for caching videos from subscribed curated lists
// ABOUTME: Provides reactive updates via ChangeNotifier for home feed integration

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:unified_logger/unified_logger.dart';

/// Caches videos from curated lists the user has subscribed to
/// Used to merge subscribed list videos into the home feed
class SubscribedListVideoCache extends ChangeNotifier {
  SubscribedListVideoCache({
    required NostrClient nostrService,
    required VideoEventService videoEventService,
    required CuratedListService curatedListService,
  }) : _nostrService = nostrService,
       _videoEventService = videoEventService,
       _curatedListService = curatedListService;

  final NostrClient _nostrService;
  final VideoEventService _videoEventService;
  final CuratedListService _curatedListService;

  /// Maps video ID to the set of list IDs that contain this video
  final Map<String, Set<String>> _videoToLists = {};

  /// Cached video events by video ID
  final Map<String, VideoEvent> _cachedVideos = {};

  /// Regex for validating 64-character hex event IDs
  static final _hexIdRegex = RegExp(r'^[a-fA-F0-9]{64}$');

  /// Timer for debouncing notifications when videos stream in
  Timer? _notifyDebounceTimer;

  /// Track if we've notified at least once for immediate first-video response
  bool _hasNotifiedOnce = false;

  @override
  void dispose() {
    _notifyDebounceTimer?.cancel();
    super.dispose();
  }

  /// Returns all cached videos from subscribed lists
  List<VideoEvent> getVideos() {
    return _cachedVideos.values.toList();
  }

  /// Returns the set of list IDs that contain the given video
  Set<String> getListsForVideo(String videoId) {
    return _videoToLists[videoId] ?? {};
  }

  /// Syncs a single list's videos into the cache
  ///
  /// Separates event IDs (64-char hex) from addressable coordinates (kind:pubkey:d-tag)
  /// Checks VideoEventService cache first, then fetches missing videos from relays
  Future<void> syncList(String listId, List<String> videoIds) async {
    Log.info(
      'Syncing list $listId with ${videoIds.length} video IDs',
      name: 'SubscribedListVideoCache',
      category: LogCategory.video,
    );

    // Separate event IDs from addressable coordinates
    final eventIds = <String>[];
    final addressableCoords = <String>[]; // Format: kind:pubkey:d-tag

    for (final id in videoIds) {
      if (id.contains(':')) {
        addressableCoords.add(id);
      } else if (_hexIdRegex.hasMatch(id)) {
        eventIds.add(id);
      }
    }

    Log.debug(
      'IDs breakdown: ${eventIds.length} event IDs, '
      '${addressableCoords.length} addressable coords',
      name: 'SubscribedListVideoCache',
      category: LogCategory.video,
    );

    // Check cache for regular event IDs
    final missingIds = <String>[];
    for (final eventId in eventIds) {
      final cached = _videoEventService.getVideoById(eventId);
      if (cached != null) {
        _addVideoToCache(cached, listId);
      } else {
        missingIds.add(eventId);
      }
    }

    // Check cache for addressable coordinates
    final missingCoords = <String>[];
    for (final coord in addressableCoords) {
      final video = _findVideoByCoordinate(coord);
      if (video != null) {
        _addVideoToCache(video, listId);
      } else {
        missingCoords.add(coord);
      }
    }

    // Fetch missing videos from relays
    if (missingIds.isNotEmpty || missingCoords.isNotEmpty) {
      await _fetchMissingVideos(listId, missingIds, missingCoords);
    }

    notifyListeners();
  }

  /// Syncs all subscribed lists from CuratedListService
  Future<void> syncAllSubscribedLists() async {
    final subscribedLists = _curatedListService.subscribedLists;
    final subscribedIds = _curatedListService.subscribedListIds;

    Log.info(
      '🔄 syncAllSubscribedLists called - '
      '${subscribedLists.length} lists from service, '
      '${subscribedIds.length} subscribed IDs',
      name: 'SubscribedListVideoCache',
      category: LogCategory.video,
    );

    // Log each list for debugging
    for (final list in subscribedLists) {
      Log.debug(
        '  📋 List "${list.name}" (${list.id}): '
        '${list.videoEventIds.length} video IDs',
        name: 'SubscribedListVideoCache',
        category: LogCategory.video,
      );
    }

    if (subscribedLists.isEmpty && subscribedIds.isNotEmpty) {
      final sampleIds = subscribedIds.take(3).join(', ');
      Log.warning(
        '⚠️ Have ${subscribedIds.length} subscribed IDs but 0 lists loaded! '
        'IDs: $sampleIds',
        name: 'SubscribedListVideoCache',
        category: LogCategory.video,
      );
    }

    // Sync all lists in parallel for faster loading
    await Future.wait(
      subscribedLists.map((list) => syncList(list.id, list.videoEventIds)),
    );

    Log.info(
      '✅ syncAllSubscribedLists complete - cache now has ${_cachedVideos.length} videos',
      name: 'SubscribedListVideoCache',
      category: LogCategory.video,
    );
  }

  /// Removes a list from the cache (called on unsubscribe)
  ///
  /// Removes the list from video-to-list mappings and cleans up
  /// videos that are no longer in any list
  void removeList(String listId) {
    Log.info(
      'Removing list $listId from cache',
      name: 'SubscribedListVideoCache',
      category: LogCategory.video,
    );

    // Remove list from all video mappings
    final videosToRemove = <String>[];

    for (final entry in _videoToLists.entries) {
      entry.value.remove(listId);
      // If video is no longer in any list, mark for removal
      if (entry.value.isEmpty) {
        videosToRemove.add(entry.key);
      }
    }

    // Remove videos that are no longer in any list
    for (final videoId in videosToRemove) {
      _videoToLists.remove(videoId);
      _cachedVideos.remove(videoId);
    }

    notifyListeners();
  }

  /// Adds a video to the cache and associates it with a list
  /// Triggers a debounced notification so UI updates as videos stream in
  void _addVideoToCache(VideoEvent video, String listId) {
    _cachedVideos[video.id] = video;
    _videoToLists.putIfAbsent(video.id, () => {}).add(listId);
    _scheduleNotify();
  }

  /// Smart notification strategy:
  /// - First video: notify immediately so UI shows content ASAP
  /// - Subsequent videos: debounce 100ms to batch updates and reduce rebuilds
  void _scheduleNotify() {
    if (!_hasNotifiedOnce) {
      // First video - notify immediately for fast initial display
      _hasNotifiedOnce = true;
      Log.debug(
        'First video arrived - notifying immediately',
        name: 'SubscribedListVideoCache',
        category: LogCategory.video,
      );
      notifyListeners();
      return;
    }

    // Subsequent videos - debounce to batch updates
    _notifyDebounceTimer?.cancel();
    _notifyDebounceTimer = Timer(
      const Duration(milliseconds: 100),
      notifyListeners,
    );
  }

  /// Finds a video by addressable coordinate (kind:pubkey:d-tag)
  VideoEvent? _findVideoByCoordinate(String coord) {
    final parts = coord.split(':');
    if (parts.length < 3) return null;

    final pubkey = parts[1];
    final dTag = parts[2];

    // Search in VideoEventService caches
    final allVideos = <VideoEvent>{
      ..._videoEventService.discoveryVideos,
      ..._videoEventService.homeFeedVideos,
      ..._videoEventService.profileVideos,
    };

    return allVideos.where((v) {
      if (v.pubkey != pubkey) return false;
      final videoDTag = v.rawTags['d'] ?? v.vineId ?? v.id;
      return videoDTag == dTag;
    }).firstOrNull;
  }

  /// Fetches missing videos from relays with a 5 second timeout
  Future<void> _fetchMissingVideos(
    String listId,
    List<String> missingIds,
    List<String> missingCoords,
  ) async {
    Log.info(
      'Fetching ${missingIds.length} missing IDs + '
      '${missingCoords.length} missing coords from relays',
      name: 'SubscribedListVideoCache',
      category: LogCategory.video,
    );

    final filters = <Filter>[];

    // Filter for regular event IDs
    if (missingIds.isNotEmpty) {
      filters.add(Filter(ids: missingIds));
    }

    // Filters for addressable events
    for (final coord in missingCoords) {
      final parts = coord.split(':');
      if (parts.length >= 3) {
        final kind = int.tryParse(parts[0]);
        final pubkey = parts[1];
        final dTag = parts[2];
        if (kind != null) {
          filters.add(Filter(kinds: [kind], authors: [pubkey], d: [dTag]));
        }
      }
    }

    if (filters.isEmpty) return;

    final eventStream = _nostrService.subscribe(filters, closeOnEose: true);
    final seenIds = <String>{};

    // Use 3 second timeout for relay fetches (faster initial load)
    try {
      await for (final event in eventStream.timeout(
        const Duration(seconds: 3),
      )) {
        if (seenIds.contains(event.id)) continue;
        seenIds.add(event.id);

        try {
          // Use permissive mode to accept all NIP-71 video kinds
          final video = VideoEvent.fromNostrEvent(event, permissive: true);
          _addVideoToCache(video, listId);
          _videoEventService.addVideoEvent(video);

          Log.debug(
            'Fetched video (kind ${event.kind}): ${video.title ?? video.id}',
            name: 'SubscribedListVideoCache',
            category: LogCategory.video,
          );
        } catch (e) {
          Log.warning(
            'Failed to parse event ${event.id} (kind ${event.kind}): $e',
            name: 'SubscribedListVideoCache',
            category: LogCategory.video,
          );
        }
      }
    } on TimeoutException {
      Log.info(
        'Relay fetch timeout - processed ${seenIds.length} events',
        name: 'SubscribedListVideoCache',
        category: LogCategory.video,
      );
    } on RelaySubscriptionRefusedException catch (e) {
      // Every relay refused the REQ. Keep whatever arrived before that; the
      // caller runs from an unawaited microtask, so rethrowing here would
      // reach the zone as an uncaught async error.
      Log.warning(
        'Relay refused list video fetch (${e.reason}) - '
        'processed ${seenIds.length} events',
        name: 'SubscribedListVideoCache',
        category: LogCategory.video,
      );
    }
  }
}
