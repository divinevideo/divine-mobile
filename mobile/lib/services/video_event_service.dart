// ABOUTME: Service for subscribing to and managing video events (NIP-71 kinds 22, 34236)
// ABOUTME: Handles real-time feed updates and local caching of video content

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/models/user_profile.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/services/connection_status_service.dart';
import 'package:openvine/services/content_blocklist_service.dart';
import 'package:openvine/services/nostr_service_interface.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/services/user_profile_service.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/utils/log_batcher.dart';
import 'package:openvine/constants/nip71_migration.dart';
import 'package:openvine/services/event_router.dart';

/// Pagination state for tracking cursor position and loading status per subscription
class PaginationState {
  int? oldestTimestamp;
  bool isLoading;
  bool hasMore;
  Set<String> seenEventIds;
  int eventsReceivedInCurrentQuery;

  PaginationState({
    this.oldestTimestamp,
    this.isLoading = false,
    this.hasMore = true,
    Set<String>? seenEventIds,
    this.eventsReceivedInCurrentQuery = 0,
  }) : seenEventIds = seenEventIds ?? <String>{};

  void updateOldestTimestamp(int timestamp) {
    if (oldestTimestamp == null || timestamp < oldestTimestamp!) {
      oldestTimestamp = timestamp;
    }
  }

  void markEventSeen(String eventId) {
    seenEventIds.add(eventId);
  }

  void startQuery() {
    eventsReceivedInCurrentQuery = 0;
    isLoading = true;
  }

  void incrementEventCount() {
    eventsReceivedInCurrentQuery++;
  }

  void completeQuery(int requestedLimit) {
    isLoading = false;
    // If we received fewer events than requested, assume no more content
    if (eventsReceivedInCurrentQuery < requestedLimit) {
      hasMore = false;
      Log.info(
          'PaginationState: No more content available - received $eventsReceivedInCurrentQuery < $requestedLimit requested',
          name: 'VideoEventService',
          category: LogCategory.video);
    }
  }

  void reset() {
    oldestTimestamp = null;
    isLoading = false;
    hasMore = true;
    seenEventIds.clear();
    eventsReceivedInCurrentQuery = 0;
  }
}

/// Subscription types for different video feed categories
enum SubscriptionType {
  homeFeed, // Videos from people you follow
  discovery, // All videos for exploration
  profile, // Videos from specific user
  editorial, // Curated/editorial content
  popularNow, // Live/trending vines
  trending, // Trending videos
  hashtag, // Videos with specific hashtags
  search, // Search results
}

/// Service for handling video events (NIP-71 kinds 22, 34236) with separate lists per subscription type
/// REFACTORED: Multiple event lists per subscription type with proper REQ filtering
class VideoEventService extends ChangeNotifier {
  VideoEventService(
    this._nostrService, {
    required SubscriptionManager subscriptionManager,
    UserProfileService? userProfileService,
    EventRouter? eventRouter,
  })  : _subscriptionManager = subscriptionManager,
        _userProfileService = userProfileService,
        _eventRouter = eventRouter {
    _initializePaginationStates();
  }
  final INostrService _nostrService;
  final UserProfileService? _userProfileService;
  final EventRouter? _eventRouter;
  final ConnectionStatusService _connectionService = ConnectionStatusService();

  // REFACTORED: Separate event lists per subscription type
  final Map<SubscriptionType, List<VideoEvent>> _eventLists = {
    SubscriptionType.homeFeed: [],
    SubscriptionType.discovery: [],
    SubscriptionType.profile: [],
    SubscriptionType.editorial: [],
    SubscriptionType.popularNow: [],
    SubscriptionType.trending: [],
    SubscriptionType.hashtag: [],
    SubscriptionType.search: [],
  };

  // Keyed event lists for hashtag and author feeds (route-aware)
  final Map<String, List<VideoEvent>> _hashtagBuckets = {};
  final Map<String, List<VideoEvent>> _authorBuckets = {};

  // Track active subscriptions per type
  final Map<SubscriptionType, String> _activeSubscriptions = {};
  final Map<String, StreamSubscription> _subscriptions = {};
  final List<String> _activeSubscriptionIds = [];

  // Global state
  bool _isLoading = false;
  String? _error;
  Timer? _retryTimer;
  int _retryAttempts = 0;

  // Track subscription parameters per type
  final Map<SubscriptionType, Map<String, dynamic>> _subscriptionParams = {};

  // Pagination state per subscription type
  final Map<SubscriptionType, PaginationState> _paginationStates = {};

  // Duplicate event aggregation for logging
  int _duplicateVideoEventCount = 0;
  DateTime? _lastDuplicateVideoLogTime;

  // Track replaceable events per subscription type
  // Key: "subscriptionType:kind:pubkey:d-tag", Value: (VideoEvent, timestamp)
  final Map<String, (VideoEvent, int)> _replaceableVideoEvents = {};

  // Hashtag and group filtering (per subscription)
  final Map<SubscriptionType, List<String>?> _activeHashtagFilters = {};
  final Map<SubscriptionType, String?> _activeGroupFilters = {};

  // Frame-based batching for progressive UI updates
  bool _hasScheduledFrameUpdate = false;

  // Metrics tracking for progressive loading performance
  int _totalEventsReceived = 0;
  int _totalUiUpdates = 0;
  DateTime? _firstEventTime;

  // Search state - TODO: These fields are maintained for future search state tracking
  // bool _isSearching = false;
  // String? _currentSearchQuery;

  // Track following feed status
  final Map<SubscriptionType, bool> _isFollowingFeed = {};
  final Map<SubscriptionType, bool> _includeReposts = {};

  // Track locally deleted videos to prevent resurrection from pagination
  final Set<String> _locallyDeletedVideoIds = {};

  static const int _maxRetryAttempts = 3;
  static const Duration _retryDelay = Duration(seconds: 10);

  // Optional services for enhanced functionality
  ContentBlocklistService? _blocklistService;
  final SubscriptionManager _subscriptionManager;

  // AUTH retry mechanism
  StreamSubscription<Map<String, bool>>? _authStateSubscription;

  /// Set the blocklist service for content filtering
  void setBlocklistService(ContentBlocklistService blocklistService) {
    _blocklistService = blocklistService;
    Log.debug('Blocklist service attached to VideoEventService',
        name: 'VideoEventService', category: LogCategory.video);
  }

  /// Initialize pagination states for all subscription types
  void _initializePaginationStates() {
    for (final subscriptionType in SubscriptionType.values) {
      _paginationStates[subscriptionType] = PaginationState();
    }
  }

  /// Schedule a frame-based UI update to batch multiple event additions
  /// This ensures notifyListeners() is called at most once per frame (~16ms at 60fps)
  void _scheduleFrameUpdate() {
    if (_hasScheduledFrameUpdate) return;
    _hasScheduledFrameUpdate = true;

    Log.debug('🔔 Scheduling frame update callback',
        name: 'VideoEventService', category: LogCategory.video);

    // Use Future.microtask instead of WidgetsBinding.addPostFrameCallback
    // This is more reliable on web and avoids "disposed view" errors
    Future.microtask(() {
      if (!_hasScheduledFrameUpdate) return; // Already processed
      _hasScheduledFrameUpdate = false;
      _totalUiUpdates++;
      Log.debug('🔔 Frame callback fired - calling notifyListeners() on instance ${hashCode} (update #$_totalUiUpdates, hasListeners=$hasListeners)',
          name: 'VideoEventService', category: LogCategory.video);
      notifyListeners();

      // Log metrics periodically (every 10 updates)
      if (_totalUiUpdates % 10 == 0) {
        final avgEventsPerUpdate = _totalEventsReceived / _totalUiUpdates;
        final timeToFirstContent = _firstEventTime != null
            ? DateTime.now().difference(_firstEventTime!).inMilliseconds
            : 0;
        Log.debug(
          'Progressive loading metrics: $_totalEventsReceived events, $_totalUiUpdates updates, ${avgEventsPerUpdate.toStringAsFixed(1)} events/update, ${timeToFirstContent}ms to first content',
          name: 'VideoEventService',
          category: LogCategory.video,
        );
      }
    });
  }

  // REFACTORED: Getters now work with subscription types

  /// Get videos for a specific subscription type
  List<VideoEvent> getVideos(SubscriptionType type) {
    return List.unmodifiable(_eventLists[type] ?? []);
  }

  /// Get home feed videos (from people you follow)
  List<VideoEvent> get homeFeedVideos => getVideos(SubscriptionType.homeFeed);

  /// Get discovery videos (all videos for exploration)
  List<VideoEvent> get discoveryVideos => getVideos(SubscriptionType.discovery);

  /// Get profile videos (from specific user)
  List<VideoEvent> get profileVideos => getVideos(SubscriptionType.profile);

  /// Get editorial videos (curated content)
  List<VideoEvent> get editorialVideos => getVideos(SubscriptionType.editorial);

  /// Get popular now videos (live/trending)
  List<VideoEvent> get popularNowVideos =>
      getVideos(SubscriptionType.popularNow);

  /// Get trending videos
  List<VideoEvent> get trendingVideos => getVideos(SubscriptionType.trending);

  /// Get hashtag videos (all)
  List<VideoEvent> get allHashtagVideos => getVideos(SubscriptionType.hashtag);

  /// Get videos for a specific hashtag (keyed for route-aware feeds)
  List<VideoEvent> hashtagVideos(String tag) => _hashtagBuckets[tag] ?? const [];

  /// DEBUG: Dump all events with cdn.divine.video thumbnails
  void debugDumpCdnDivineVideoThumbnails() {
    Log.warning('🔍 DEBUG: Searching all loaded events for cdn.divine.video thumbnails...',
        name: 'VideoEventService', category: LogCategory.video);

    int count = 0;
    for (final entry in _eventLists.entries) {
      for (final video in entry.value) {
        if (video.thumbnailUrl?.contains('cdn.divine.video') == true) {
          count++;
          Log.warning('🔍 FOUND #$count:', name: 'VideoEventService', category: LogCategory.video);
          Log.warning('  Event ID: ${video.id}', name: 'VideoEventService', category: LogCategory.video);
          Log.warning('  Video URL: ${video.videoUrl}', name: 'VideoEventService', category: LogCategory.video);
          Log.warning('  Thumbnail: ${video.thumbnailUrl}', name: 'VideoEventService', category: LogCategory.video);
          Log.warning('  Subscription Type: ${entry.key}', name: 'VideoEventService', category: LogCategory.video);
        }
      }
    }

    Log.warning('🔍 DEBUG: Found $count events with cdn.divine.video thumbnails',
        name: 'VideoEventService', category: LogCategory.video);
  }

  /// Get videos for a specific author (keyed for route-aware feeds)
  /// Always returns videos sorted in reverse chronological order (newest first)
  List<VideoEvent> authorVideos(String pubkeyHex) {
    final cached = _authorBuckets[pubkeyHex] ?? const [];
    Log.info('SVC authorVideos: hex=$pubkeyHex cached=${cached.length}',
        name: 'Service', category: LogCategory.video);
    if (cached.isEmpty) {
      return cached;
    }

    // Always sort by newest first before returning to ensure consistent ordering
    // This is critical for profile grids to display newest videos at the top
    final sorted = List<VideoEvent>.from(cached);
    sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    Log.info('SVC authorVideos: return sorted=${sorted.length} (newest first)',
        name: 'Service', category: LogCategory.video);
    return sorted;
  }

  /// Get search results
  List<VideoEvent> get searchResults => getVideos(SubscriptionType.search);

  /// DEPRECATED: Use specific getters instead
  @Deprecated(
      'Use getVideos(SubscriptionType.discovery) or discoveryVideos instead')
  List<VideoEvent> get videoEvents => discoveryVideos;

  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Get loading state for a specific subscription type
  bool isLoadingForSubscription(SubscriptionType subscriptionType) {
    final paginationState = _paginationStates[subscriptionType];
    return paginationState?.isLoading ?? false;
  }

  /// Check if a subscription type has events
  bool hasEvents(SubscriptionType type) => (_eventLists[type] ?? []).isNotEmpty;

  /// Get event count for a subscription type
  int getEventCount(SubscriptionType type) => (_eventLists[type] ?? []).length;

  /// Get a video by its event ID (searches across all subscription types)
  VideoEvent? getVideoById(String eventId) {
    for (final eventList in _eventLists.values) {
      try {
        final video = eventList.firstWhere((v) => v.id == eventId);
        return video;
      } catch (_) {
        // Not found in this list, continue searching
        continue;
      }
    }
    return null;
  }

  /// Check if subscribed to a specific type
  bool isSubscribed(SubscriptionType type) =>
      _activeSubscriptions.containsKey(type);

  String get classicVinesPubkey => AppConstants.classicVinesPubkey;

  /// Get videos by a specific author from the existing cache (searches all subscription types)
  List<VideoEvent> getVideosByAuthor(String pubkey) {
    final result = <VideoEvent>[];
    Log.debug(
        '🔍 Searching for videos by author ${pubkey.substring(0, 8)} across ${_eventLists.length} subscription types',
        name: 'VideoEventService',
        category: LogCategory.video);
    for (final entry in _eventLists.entries) {
      final subscriptionType = entry.key;
      final eventList = entry.value;
      final matchingVideos =
          eventList.where((video) => video.pubkey == pubkey).toList();
      if (matchingVideos.isNotEmpty) {
        Log.debug(
            '  📱 Found ${matchingVideos.length} videos in ${subscriptionType.name} list (total: ${eventList.length})',
            name: 'VideoEventService',
            category: LogCategory.video);
      } else {
        Log.debug(
            '  ⏭️  No videos in ${subscriptionType.name} list (total: ${eventList.length})',
            name: 'VideoEventService',
            category: LogCategory.video);
      }
      result.addAll(matchingVideos);
    }
    Log.debug(
        '✅ Total videos found for ${pubkey.substring(0, 8)}: ${result.length}',
        name: 'VideoEventService',
        category: LogCategory.video);
    return result;
  }

  /// Remove a video from an author's cached list (optimistic deletion)
  /// This is called after successfully publishing a NIP-09 delete event
  void removeVideoFromAuthorList(String authorPubkey, String videoId) {
    // Remove from author bucket
    final authorBucket = _authorBuckets[authorPubkey];
    if (authorBucket != null) {
      final initialCount = authorBucket.length;
      authorBucket.removeWhere((video) => video.id == videoId);
      final removedCount = initialCount - authorBucket.length;

      if (removedCount > 0) {
        Log.info('Removed video $videoId from author $authorPubkey bucket (${authorBucket.length} remaining)',
            name: 'VideoEventService', category: LogCategory.video);
      }
    }

    // Mark as locally deleted to prevent pagination resurrection
    _locallyDeletedVideoIds.add(videoId);
    Log.info('Marked video $videoId as locally deleted',
        name: 'VideoEventService', category: LogCategory.video);

    // Notify listeners to update UI immediately (optimistic update)
    notifyListeners();
  }

  /// Check if a video has been locally deleted
  /// Used to filter out deleted videos from pagination results
  bool isVideoLocallyDeleted(String videoId) {
    return _locallyDeletedVideoIds.contains(videoId);
  }

  /// Load cached events from database (cache-first strategy)
  ///
  /// Returns cached events matching the filter parameters for instant UI display.
  /// This is called BEFORE relay subscription to provide immediate results.
  ///
  /// Returns empty list if:
  /// - EventRouter not available (null)
  /// - No cached events matching filters
  Future<List<Event>> _loadCachedEvents({
    List<int>? kinds,
    List<String>? authors,
    List<String>? hashtags,
    int? since,
    int? until,
    int limit = 100,
  }) async {
    // Skip if EventRouter not available (backward compatibility)
    if (_eventRouter == null) {
      return [];
    }

    try {
      final cachedEvents = await _eventRouter!.db.nostrEventsDao.getVideoEventsByFilter(
        kinds: kinds,
        authors: authors,
        hashtags: hashtags,
        since: since,
        until: until,
        limit: limit,
      );

      if (cachedEvents.isNotEmpty) {
        Log.debug(
          '💾 Cache-first: Loaded ${cachedEvents.length} cached events from database',
          name: 'VideoEventService',
          category: LogCategory.video,
        );
      }

      return cachedEvents;
    } catch (e) {
      Log.error(
        'Failed to load cached events: $e',
        name: 'VideoEventService',
        category: LogCategory.video,
      );
      return [];
    }
  }

  /// Subscribe to NIP-71 video events with proper subscription type separation
  Future<void> subscribeToVideoFeed({
    required SubscriptionType subscriptionType,
    List<String>? authors,
    List<String>? hashtags,
    String? group, // Support filtering by group ('h' tag)
    int? since,
    int? until,
    int limit = 200, // Increased for more content
    bool replace =
        true, // Whether to replace existing subscription for this type
    bool includeReposts =
        false, // Whether to include kind 6 reposts (disabled by default)
  }) async {
    // NostrService now handles subscription deduplication automatically via filter hashing
    // We still track subscription types for our own state management

    // Set loading state immediately to prevent race conditions
    _isLoading = true;
    _error = null;

    if (!_nostrService.isInitialized) {
      _isLoading = false;

      Log.warning('Cannot subscribe - Nostr service not initialized (will retry when ready)',
          name: 'VideoEventService', category: LogCategory.video);
      // Defensive: Don't throw, just return early
      // The provider will retry when the service becomes initialized
      return;
    }

    // Check connection status
    if (!_connectionService.isOnline) {
      _isLoading = false;

      Log.warning('Device is offline, will retry when connection is restored',
          name: 'VideoEventService', category: LogCategory.video);
      _scheduleRetryWhenOnline();
      throw const VideoEventServiceException('Device is offline');
    }

    if (_nostrService.connectedRelayCount == 0) {
      Log.warning(
          'WARNING: No relays connected - subscription will likely fail',
          name: 'VideoEventService',
          category: LogCategory.video);
    }

    // Avoid churn: if params match existing subscription, skip re-subscribe
    if (_isDuplicateSubscription(
      subscriptionType,
      authors,
      hashtags,
      group,
      limit,
      since,
      until,
      includeReposts: includeReposts,
    )) {
      Log.info(
          '🔁 Skipping re-subscribe for $subscriptionType (parameters unchanged)',
          name: 'VideoEventService',
          category: LogCategory.video);
      _isLoading = false;
      return;
    }

    // Only close existing subscription for this type if replace=true and params changed
    if (replace && isSubscribed(subscriptionType)) {
      Log.info('🔄 Replacing existing $subscriptionType subscription',
          name: 'VideoEventService', category: LogCategory.video);
      await _cancelSubscription(subscriptionType);
    }

    try {
      Log.info(
          '🎬 Creating $subscriptionType filter for NIP-71 video events...',
          name: 'VideoEventService',
          category: LogCategory.video);
      Log.info('  - Subscription Type: $subscriptionType',
          name: 'VideoEventService', category: LogCategory.video);
      Log.info(
          '  - Authors: ${authors?.length ?? 'all'} ${authors?.isNotEmpty == true ? "(first: ${authors!.first.substring(0, 8)}...)" : ""}',
          name: 'VideoEventService',
          category: LogCategory.video);
      Log.info('  - Hashtags: ${hashtags?.join(', ') ?? 'none'}',
          name: 'VideoEventService', category: LogCategory.video);
      Log.info('  - Group: ${group ?? 'none'}',
          name: 'VideoEventService', category: LogCategory.video);
      Log.info(
          '  - Since: ${since != null ? DateTime.fromMillisecondsSinceEpoch(since * 1000) : 'none'}',
          name: 'VideoEventService',
          category: LogCategory.video);
      Log.info(
          '  - Until: ${until != null ? DateTime.fromMillisecondsSinceEpoch(until * 1000) : 'none'}',
          name: 'VideoEventService',
          category: LogCategory.video);
      Log.info('  - Limit: $limit',
          name: 'VideoEventService', category: LogCategory.video);
      Log.info('  - Replace existing: $replace',
          name: 'VideoEventService', category: LogCategory.video);
      Log.info('  - Include reposts: $includeReposts',
          name: 'VideoEventService', category: LogCategory.video);

      // Store includeReposts setting for this subscription type
      _includeReposts[subscriptionType] = includeReposts;

      // Create filter for NIP-71 video events
      // No artificial date constraints - let relays return their best content
      final effectiveSince = since;
      final effectiveUntil = until;

      if (since == null &&
          until == null &&
          _eventLists[subscriptionType]?.isEmpty == true) {
        Log.debug(
            '📱 Initial load: requesting best video content (no date constraints)',
            name: 'VideoEventService',
            category: LogCategory.video);
        // Let relays decide what content to return - they know their data best
      }

      // Create optimized filter for NIP-71 video events
      // IMPORTANT: Convert hashtags to lowercase per NIP-24 requirement
      final lowercaseHashtags =
          hashtags?.map((tag) => tag.toLowerCase()).toList();

      final videoFilter = Filter(
        kinds: NIP71VideoKinds.getAllVideoKinds(), // NIP-71 video events
        authors: authors,
        since: effectiveSince,
        until: effectiveUntil,
        limit: limit, // Use full limit for video events
        t: lowercaseHashtags, // Add hashtag filtering at relay level (lowercase per NIP-24)
      );

      // Debug: Log when subscribing to Classic Vines
      if (authors != null &&
          authors.contains(AppConstants.classicVinesPubkey)) {
        Log.debug(
            '🌟 Subscribing to Classic Vines account (${AppConstants.classicVinesPubkey})',
            name: 'VideoEventService',
            category: LogCategory.video);
      }

      if (lowercaseHashtags != null && lowercaseHashtags.isNotEmpty) {
        Log.debug(
            'Adding hashtag filter to relay query: $lowercaseHashtags (converted to lowercase per NIP-24)',
            name: 'VideoEventService',
            category: LogCategory.video);
      }

      // Store group for client-side filtering
      _activeGroupFilters[subscriptionType] = group;

      final filters = <Filter>[videoFilter];

      // Optionally add repost filter if enabled
      if (includeReposts) {
        final repostFilter = Filter(
          kinds: [6], // NIP-18 reposts only
          authors: authors,
          since: effectiveSince,
          until: effectiveUntil,
          limit: (limit * 0.2).round(), // Only 20% for reposts when enabled
        );
        filters.add(repostFilter);
        Log.debug('Using primary video filter + optional repost filter:',
            name: 'VideoEventService', category: LogCategory.video);
        Log.debug('  - Video filter ($limit limit): ${videoFilter.toJson()}',
            name: 'VideoEventService', category: LogCategory.video);
        Log.debug(
            '  - Repost filter (${(limit * 0.2).round()} limit): ${repostFilter.toJson()}',
            name: 'VideoEventService',
            category: LogCategory.video);
      } else {
        Log.debug('Using video-only filter (reposts disabled):',
            name: 'VideoEventService', category: LogCategory.video);
        Log.debug('  - Video filter ($limit limit): ${videoFilter.toJson()}',
            name: 'VideoEventService', category: LogCategory.video);
      }

      // Store hashtag filter for event processing
      _activeHashtagFilters[subscriptionType] = hashtags;

      // Verify NostrService is ready
      if (!_nostrService.isInitialized) {
        Log.error('❌ NostrService not initialized - cannot create subscription',
            name: 'VideoEventService', category: LogCategory.video);
        throw Exception('NostrService not initialized');
      }

      if (_nostrService.connectedRelayCount == 0) {
        Log.error('❌ No connected relays - cannot create subscription',
            name: 'VideoEventService', category: LogCategory.video);
        throw Exception('No connected relays');
      }

      // BYPASS SubscriptionManager for main video feed - go directly to NostrService
      try {
        // Use the filters we already created above which include authors
        Log.info(
            '🚀 Creating subscription with filters: ${filters.map((f) => f.toJson()).toList()}',
            name: 'VideoEventService',
            category: LogCategory.video);

        // Extra debug for home feed
        if (subscriptionType == SubscriptionType.homeFeed) {
          Log.info('🏠🏠🏠 HOME FEED SUBSCRIPTION DEBUG:',
              name: 'VideoEventService', category: LogCategory.video);
          Log.info('  Authors requested: ${authors?.length ?? 0}',
              name: 'VideoEventService', category: LogCategory.video);
          if (authors != null && authors.isNotEmpty) {
            Log.info('  First 3 authors: ${authors.take(3).join(", ")}',
                name: 'VideoEventService', category: LogCategory.video);
          }
          Log.info('  Filters being sent to NostrService:',
              name: 'VideoEventService', category: LogCategory.video);
          for (var i = 0; i < filters.length; i++) {
            final f = filters[i];
            Log.info(
                '    Filter $i: kinds=${f.kinds}, authors=${f.authors?.length}, limit=${f.limit}',
                name: 'VideoEventService',
                category: LogCategory.video);
          }
        }

        // Generate deterministic subscription ID based on subscription parameters
        final subscriptionId = _generateSubscriptionId(
          subscriptionType: subscriptionType,
          authors: authors,
          hashtags: hashtags,
          group: group,
          since: since,
          until: until,
          limit: limit,
          includeReposts: includeReposts,
        );

        // Check if we already have this exact subscription
        if (_subscriptions.containsKey(subscriptionId)) {
          Log.info(
              '🔄 Reusing existing subscription $subscriptionId with identical parameters',
              name: 'VideoEventService',
              category: LogCategory.video);
          // Update active subscription mapping
          _activeSubscriptions[subscriptionType] = subscriptionId;
          return; // Reuse existing subscription
        }

        // Create direct subscription using NostrService with proper filters
        final subscriptionStartTime = DateTime.now();
        int eventCount = 0;
        DateTime? firstEventTime;
        bool eoseReceived = false;

        Log.info('📡 Creating subscription for $subscriptionType at ${subscriptionStartTime.toIso8601String()}',
            name: 'VideoEventService', category: LogCategory.video);

        // Phase 3.3: Cache-first strategy - load cached events BEFORE relay subscription
        // This provides instant UI feedback while relay fetches fresh data
        final cachedEvents = await _loadCachedEvents(
          kinds: NIP71VideoKinds.getAllVideoKinds(),
          authors: authors,
          hashtags: lowercaseHashtags,
          since: effectiveSince,
          until: effectiveUntil,
          limit: limit,
        );

        // Process cached events immediately (same flow as relay events)
        for (final event in cachedEvents) {
          _handleNewVideoEvent(event, subscriptionType);
        }

        // Notify UI with cached results for instant display
        if (cachedEvents.isNotEmpty) {
          notifyListeners();
          Log.info(
            '💾 Cache-first: UI updated with ${cachedEvents.length} cached events for instant display',
            name: 'VideoEventService',
            category: LogCategory.video,
          );
        }

        final eventStream = _nostrService.subscribeToEvents(
          filters: filters,
          onEose: () {
            eoseReceived = true;
            final eoseDuration = DateTime.now().difference(subscriptionStartTime);
            Log.info('✅ EOSE received for $subscriptionType after ${eoseDuration.inMilliseconds}ms with $eventCount events',
                name: 'VideoEventService', category: LogCategory.video);

            // Warn if no events received - trigger automatic diagnostics
            if (eventCount == 0) {
              Log.warning('⚠️ EOSE received but NO EVENTS for $subscriptionType - feed will be empty!',
                  name: 'VideoEventService', category: LogCategory.video);

              // Run automatic diagnostics for debugging empty feeds
              _runAutoDiagnostics(subscriptionType, filters);
            }
          },
        );

        final streamSubscription = eventStream.listen(
          (event) {
            eventCount++;

            // Route ALL events to database immediately (Phase 3.2: Drift integration)
            _eventRouter?.handleEvent(event);

            // Track first event arrival time
            if (firstEventTime == null) {
              firstEventTime = DateTime.now();
              final firstEventLatency = firstEventTime!.difference(subscriptionStartTime);
              Log.info('🎯 First event for $subscriptionType arrived after ${firstEventLatency.inMilliseconds}ms',
                  name: 'VideoEventService', category: LogCategory.video);
            }

            if (subscriptionType == SubscriptionType.homeFeed) {
              Log.info(
                  '🏠📥 HOME FEED EVENT #$eventCount RECEIVED: kind=${event.kind}, author=${event.pubkey.substring(0, 8)}',
                  name: 'VideoEventService',
                  category: LogCategory.video);
            }
            _handleNewVideoEvent(event, subscriptionType);
          },
          onError: (error) {
            Log.error('❌ Subscription error for $subscriptionType after $eventCount events: $error',
                name: 'VideoEventService', category: LogCategory.video);
            _handleSubscriptionError(error, subscriptionType);
          },
          onDone: () {
            final totalDuration = DateTime.now().difference(subscriptionStartTime);
            Log.info('🏁 Subscription complete for $subscriptionType: $eventCount events in ${totalDuration.inMilliseconds}ms (EOSE: $eoseReceived)',
                name: 'VideoEventService', category: LogCategory.video);

            // PERSISTENT SUBSCRIPTION: onDone means relay closed connection
            // For main feeds, this should trigger reconnection attempt
            _handleSubscriptionComplete(subscriptionType);
            if (_shouldMaintainSubscription(subscriptionType)) {
              _scheduleReconnection(subscriptionType);
            }
          },
        );

        // Store the stream subscription for cleanup
        _subscriptions[subscriptionId] = streamSubscription;
        _activeSubscriptions[subscriptionType] = subscriptionId;

        // Subscription is tracked per type in _activeSubscriptions
      } catch (e, stackTrace) {
        Log.error('❌ Failed to create direct subscription: $e',
            name: 'VideoEventService', category: LogCategory.video);
        Log.error('❌ Stack trace: $stackTrace',
            name: 'VideoEventService', category: LogCategory.video);
        rethrow;
      }

      // Store current subscription parameters for duplicate detection
      _subscriptionParams[subscriptionType] = {
        'authors': authors,
        'hashtags': hashtags,
        'group': group,
        'since': since,
        'until': until,
        'limit': limit,
        'includeReposts': includeReposts,
      };

      Log.info('Video event subscription established successfully!',
          name: 'VideoEventService', category: LogCategory.video);

      // Add default video if feed is empty to ensure new users have content
      _ensureDefaultContent();

      // Progressive loading removed - let UI trigger loadMore as needed
      final totalSubs = _subscriptions.length + _activeSubscriptionIds.length;
      Log.debug(
          'Subscription status: active=$totalSubs subscriptions (${_activeSubscriptionIds.length} managed, ${_subscriptions.length} direct)',
          name: 'VideoEventService',
          category: LogCategory.video);
    } catch (e) {
      _error = e.toString();
      Log.error('Failed to subscribe to video events: $e',
          name: 'VideoEventService', category: LogCategory.video);

      // Check if it's a connection-related error
      if (_isConnectionError(e)) {
        Log.error('📱 Connection error detected, will retry when online',
            name: 'VideoEventService', category: LogCategory.video);
        _scheduleRetryWhenOnline();
      }
    } finally {
      _isLoading = false;
    }
  }

  /// Check and handle replaceable video events (NIP-01, NIP-33)
  /// Returns true if event should be added to lists (not replaceable, first version, or newer version)
  /// Returns false if event should be skipped (older version exists)
  /// Side effect: Removes old version from event lists if newer version arrived
  bool _handleReplaceableVideoEvent(
    VideoEvent videoEvent,
    SubscriptionType subscriptionType,
    Event originalEvent,
  ) {
    // Check if this is a replaceable event (kinds 34235, 34236 are parameterized replaceable)
    final isReplaceable = originalEvent.kind == 34235 || originalEvent.kind == 34236;

    if (!isReplaceable) {
      return true; // Not replaceable, allow normal processing
    }

    // For parameterized replaceable events, construct key: subscriptionType:kind:pubkey:d-tag
    String replaceKey = '$subscriptionType:${originalEvent.kind}:${originalEvent.pubkey}';

    // Extract d-tag (required for kinds 30000-39999)
    final dTag = originalEvent.tags.firstWhere(
      (tag) => tag.isNotEmpty && tag[0] == 'd',
      orElse: () => <String>[],
    );
    if (dTag.isNotEmpty && dTag.length > 1) {
      replaceKey += ':${dTag[1]}';
    } else {
      // No d-tag found - this shouldn't happen for parameterized replaceable events
      Log.warning(
        '⚠️ Parameterized replaceable event (kind ${originalEvent.kind}) missing d-tag',
        name: 'VideoEventService',
        category: LogCategory.video,
      );
      return true; // Allow normal processing without replacement logic
    }

    // Check if we've seen this replaceable event before
    if (_replaceableVideoEvents.containsKey(replaceKey)) {
      final (oldVideoEvent, oldTimestamp) = _replaceableVideoEvents[replaceKey]!;

      if (originalEvent.createdAt > oldTimestamp) {
        // New event is newer - replace the old one
        Log.info(
          '🔄 Replacing old kind ${originalEvent.kind} event (ts:$oldTimestamp) with newer (ts:${originalEvent.createdAt})',
          name: 'VideoEventService',
          category: LogCategory.video,
        );

        // Remove old event from event list
        final eventList = _eventLists[subscriptionType];
        if (eventList != null) {
          eventList.removeWhere((e) => e.id == oldVideoEvent.id);
        }

        // Update tracking with new event
        _replaceableVideoEvents[replaceKey] = (videoEvent, originalEvent.createdAt);
        return true; // Allow new event to be added
      } else {
        // Incoming event is older - drop it
        Log.info(
          '⏩ Skipping older kind ${originalEvent.kind} event (ts:${originalEvent.createdAt}) - newer version exists (ts:$oldTimestamp)',
          name: 'VideoEventService',
          category: LogCategory.video,
        );
        return false; // Skip this event
      }
    } else {
      // First time seeing this replaceable event
      _replaceableVideoEvents[replaceKey] = (videoEvent, originalEvent.createdAt);
      return true; // Allow normal processing
    }
  }

  /// Handle new video event from subscription
  void _handleNewVideoEvent(
      dynamic eventData, SubscriptionType subscriptionType) {
    try {
      // The event should already be an Event object from NostrService
      if (eventData is! Event) {
        Log.warning('Expected Event object but got ${eventData.runtimeType}',
            name: 'VideoEventService', category: LogCategory.video);
        return;
      }

      final event = eventData;

      // Route ALL events to database first (single source of truth)
      // Fire-and-forget: database writes shouldn't block event processing
      if (_eventRouter != null) {
        _eventRouter.handleEvent(event).catchError((e) {
          Log.warning('EventRouter failed (non-critical): $e',
              name: 'VideoEventService', category: LogCategory.video);
        });
      }

      // Fast-path de-duplication before logging and processing
      final paginationState = _paginationStates[subscriptionType];
      if (paginationState != null) {
        if (paginationState.seenEventIds.contains(event.id)) {
          return;
        }
        // Mark seen early to prevent repeated logs for the same event (even if later skipped)
        paginationState.markEventSeen(event.id);
      }

      // Checkpoint log for profile subscriptions
      if (subscriptionType == SubscriptionType.profile) {
        Log.info('SVC event: id=${event.id}', name: 'Service', category: LogCategory.video);
      }

      // Use batched logging for repetitive event logs
      VideoEventLogBatcher.batchVideoEvent(
        eventId: event.id,
        authorPubkey: event.pubkey,
        subscriptionType: subscriptionType.toString(),
        kind: event.kind,
      );

      if (!NIP71VideoKinds.isVideoKind(event.kind) && event.kind != 6) {
        // Cache non-video events in appropriate services instead of discarding
        if (event.kind == 0 && _userProfileService != null) {
          // Kind 0 = profile metadata - cache it for profile display
          try {
            final profile = UserProfile.fromNostrEvent(event);
            // Fire-and-forget: cache the profile asynchronously
            _userProfileService.updateCachedProfile(profile).then((_) {
              Log.verbose('✅ Cached profile event for ${event.pubkey.substring(0, 8)} from video subscription',
                  name: 'VideoEventService', category: LogCategory.video);
            }).catchError((e) {
              Log.error('Failed to cache profile event: $e',
                  name: 'VideoEventService', category: LogCategory.video);
            });
          } catch (e) {
            Log.error('Failed to parse profile event: $e',
                name: 'VideoEventService', category: LogCategory.video);
          }
        } else {
          Log.verbose('⏩ Skipping non-video/repost event (kind ${event.kind})',
              name: 'VideoEventService', category: LogCategory.video);
        }
        return;
      }

      // Skip repost events if reposts are disabled
      if (event.kind == 6 && !(_includeReposts[subscriptionType] ?? false)) {
        Log.warning(
            '⏩ Skipping repost event ${event.id.substring(0, 8)}... (reposts disabled)',
            name: 'VideoEventService',
            category: LogCategory.video);
        return;
      }

      // Check if we already have this event in this subscription type
      final eventList = _eventLists[subscriptionType] ?? [];
      if (eventList.any((e) => e.id == event.id)) {
        _duplicateVideoEventCount++;
        _logDuplicateVideoEventsAggregated();
        return;
      }

      // Check if content is blocked
      if (_blocklistService?.shouldFilterFromFeeds(event.pubkey) == true) {
        Log.verbose(
            'Filtering blocked content from ${event.pubkey.substring(0, 8)}...',
            name: 'VideoEventService',
            category: LogCategory.video);
        return;
      }

      // Handle different event kinds
      if (NIP71VideoKinds.isVideoKind(event.kind)) {
        // Direct video event
        // Use batched logging for NIP-71 events
        VideoEventLogBatcher.batchNip71Event(
          eventId: event.id,
          subscriptionType: subscriptionType.toString(),
        );

        // Debug: Check for d tag
        final hasDTag =
            event.tags.any((tag) => tag.isNotEmpty && tag[0] == 'd');
        if (!hasDTag) {
          Log.warning(
              '⚠️ Event missing "d" tag - will use event ID as fallback',
              name: 'VideoEventService',
              category: LogCategory.video);
        }

        Log.verbose('Direct event tags: ${event.tags}',
            name: 'VideoEventService', category: LogCategory.video);
        try {
          final videoEvent = VideoEvent.fromNostrEvent(event);
          Log.verbose(
              'Parsed direct video: hasVideo=${videoEvent.hasVideo}, videoUrl=${videoEvent.videoUrl}',
              name: 'VideoEventService',
              category: LogCategory.video);
          Log.verbose('Thumbnail URL: ${videoEvent.thumbnailUrl}',
              name: 'VideoEventService', category: LogCategory.video);
          Log.verbose(
              'Has thumbnail: ${videoEvent.thumbnailUrl != null && videoEvent.thumbnailUrl!.isNotEmpty}',
              name: 'VideoEventService',
              category: LogCategory.video);
          Log.verbose('Video author pubkey: ${videoEvent.pubkey}',
              name: 'VideoEventService', category: LogCategory.video);
          Log.verbose('Video title: ${videoEvent.title}',
              name: 'VideoEventService', category: LogCategory.video);
          Log.verbose('Video hashtags: ${videoEvent.hashtags}',
              name: 'VideoEventService', category: LogCategory.video);

          // Debug: Special logging for Classic Vines content
          if (videoEvent.pubkey == AppConstants.classicVinesPubkey) {
            Log.info(
                '🌟 Received Classic Vines video: ${videoEvent.title ?? videoEvent.id.substring(0, 8)}',
                name: 'VideoEventService',
                category: LogCategory.video);
          }

          // Handle replaceable events (NIP-33)
          // Returns true if we should add this event (newer or first version)
          // Returns false if we should skip this event (older than cached version)
          if (!_handleReplaceableVideoEvent(videoEvent, subscriptionType, event)) {
            return; // Skip - incoming event is older than what we already have
          }
          // If we reach here: either not replaceable, first time seeing it, or newer version
          // For newer versions, _handleReplaceableVideoEvent already removed the old event

          // Check hashtag filter if active
          if (_activeHashtagFilters[subscriptionType] != null &&
              _activeHashtagFilters[subscriptionType]!.isNotEmpty) {
            // Check if video has any of the required hashtags (case-insensitive)
            final requiredHashtagsLower = _activeHashtagFilters[subscriptionType]!
                .map((tag) => tag.toLowerCase())
                .toList();
            final videoHashtagsLower = videoEvent.hashtags
                .map((tag) => tag.toLowerCase())
                .toList();
            
            final hasRequiredHashtag = requiredHashtagsLower.any(
              videoHashtagsLower.contains,
            );

            if (!hasRequiredHashtag) {
              Log.warning(
                  '⏩ Skipping video without required hashtags: ${_activeHashtagFilters[subscriptionType]}',
                  name: 'VideoEventService',
                  category: LogCategory.video);
              return;
            }
          }

          // Check group filter if active
          if (_activeGroupFilters[subscriptionType] != null &&
              videoEvent.group != _activeGroupFilters[subscriptionType]) {
            Log.warning(
                '⏩ Skipping video from different group: ${videoEvent.group} (want: ${_activeGroupFilters[subscriptionType]})',
                name: 'VideoEventService',
                category: LogCategory.video);
            return;
          }

          // Only add events with video URLs
          if (videoEvent.hasVideo) {
            _addVideoToSubscription(videoEvent, subscriptionType,
                isHistorical: false);

            // Keep only the most recent events to prevent memory issues
            final list = _eventLists[subscriptionType] ?? [];
            if (list.length > 500) {
              list.removeRange(500, list.length);
            }
          } else {
            Log.warning(
                '🎬 FILTER: ⏩ Skipping video event without video URL (hasVideo=false)',
                name: 'VideoEventService',
                category: LogCategory.video);
            Log.warning(
                '🎬 FILTER: Event details - title: ${videoEvent.title}, content: ${event.content}, tags: ${event.tags}',
                name: 'VideoEventService',
                category: LogCategory.video);
          }
        } catch (e, stackTrace) {
          Log.error('Failed to parse video event: $e',
              name: 'VideoEventService', category: LogCategory.video);
          Log.verbose('📱 Stack trace: $stackTrace',
              name: 'VideoEventService', category: LogCategory.video);
          Log.verbose('Event details:',
              name: 'VideoEventService', category: LogCategory.video);
          Log.verbose('  - ID: ${event.id}',
              name: 'VideoEventService', category: LogCategory.video);
          Log.verbose('  - Kind: ${event.kind}',
              name: 'VideoEventService', category: LogCategory.video);
          Log.verbose('  - Pubkey: ${event.pubkey}',
              name: 'VideoEventService', category: LogCategory.video);
          Log.verbose('  - Content: ${event.content}',
              name: 'VideoEventService', category: LogCategory.video);
          Log.verbose('  - Created at: ${event.createdAt}',
              name: 'VideoEventService', category: LogCategory.video);
          Log.verbose('  - Tags: ${event.tags}',
              name: 'VideoEventService', category: LogCategory.video);
        }
      } else if (event.kind == 6) {
        // Repost event - only process if it likely references video content
        Log.verbose('Processing repost event ${event.id.substring(0, 8)}...',
            name: 'VideoEventService', category: LogCategory.video);

        String? originalEventId;
        for (final tag in event.tags) {
          if (tag.isNotEmpty && tag[0] == 'e' && tag.length > 1) {
            originalEventId = tag[1];
            break;
          }
        }

        // Smart filtering: Only process reposts that are likely video-related
        if (!_isLikelyVideoRepost(event)) {
          Log.warning(
              '⏩ Skipping non-video repost ${event.id.substring(0, 8)}... (no video indicators)',
              name: 'VideoEventService',
              category: LogCategory.video);
          return;
        }

        if (originalEventId != null) {
          Log.verbose(
              'Repost references event: ${originalEventId.substring(0, 8)}...',
              name: 'VideoEventService',
              category: LogCategory.video);

          // Check if we already have the original video in our cache
          VideoEvent? existingOriginal;
          for (final events in _eventLists.values) {
            try {
              existingOriginal =
                  events.firstWhere((v) => v.id == originalEventId);
              break;
            } catch (e) {
              // Continue searching in other lists
            }
          }

          existingOriginal ??= VideoEvent(
            id: '',
            pubkey: '',
            createdAt: 0,
            content: '',
            timestamp: DateTime.now(),
          );

          if (existingOriginal.id.isNotEmpty) {
            // Create repost version of existing video
            Log.info('Found cached original video, creating repost',
                name: 'VideoEventService', category: LogCategory.video);
            final repostEvent = VideoEvent.createRepostEvent(
              originalEvent: existingOriginal,
              repostEventId: event.id,
              reposterPubkey: event.pubkey,
              repostedAt:
                  DateTime.fromMillisecondsSinceEpoch(event.createdAt * 1000),
            );

            // Check hashtag filter for reposts too
            if (_activeHashtagFilters[subscriptionType] != null &&
                _activeHashtagFilters[subscriptionType]!.isNotEmpty) {
              final hasRequiredHashtag =
                  _activeHashtagFilters[subscriptionType]!.any(
                repostEvent.hashtags.contains,
              );

              if (!hasRequiredHashtag) {
                Log.warning(
                    '⏩ Skipping repost without required hashtags: ${_activeHashtagFilters[subscriptionType]}',
                    name: 'VideoEventService',
                    category: LogCategory.video);
                return;
              }
            }

            _addVideoToSubscription(repostEvent, subscriptionType,
                isHistorical: false);
            final totalEvents = getEventCount(subscriptionType);
            Log.verbose(
                'Added $subscriptionType repost event! Total: $totalEvents events',
                name: 'VideoEventService',
                category: LogCategory.video);
          } else {
            // Fetch original event from relays
            Log.verbose('Fetching original video event from relays...',
                name: 'VideoEventService', category: LogCategory.video);
            _fetchOriginalEventForRepost(originalEventId, event);
          }
        }
      }
    } catch (e) {
      Log.error('Error processing video event: $e',
          name: 'VideoEventService', category: LogCategory.video);
    }
  }

  /// Handle historical video events from pagination queries (adds to bottom of feed)
  void _handleHistoricalVideoEvent(
      dynamic eventData, SubscriptionType subscriptionType) {
    try {
      // The event should already be an Event object from NostrService
      if (eventData is! Event) {
        Log.warning('Expected Event object but got ${eventData.runtimeType}',
            name: 'VideoEventService', category: LogCategory.video);
        return;
      }

      final event = eventData;
      // Fast-path de-duplication before logging
      final paginationState = _paginationStates[subscriptionType];
      if (paginationState != null) {
        if (paginationState.seenEventIds.contains(event.id)) {
          return;
        }
        paginationState.markEventSeen(event.id);
      }

      Log.debug(
          '📥 Received historical $subscriptionType event: kind=${event.kind}, author=${event.pubkey.substring(0, 8)}..., id=${event.id.substring(0, 8)}...',
          name: 'VideoEventService',
          category: LogCategory.video);

      if (!NIP71VideoKinds.isVideoKind(event.kind) && event.kind != 6) {
        Log.warning(
            '⏩ Skipping non-video/repost historical event (kind ${event.kind})',
            name: 'VideoEventService',
            category: LogCategory.video);
        return;
      }

      // Skip repost events if reposts are disabled
      if (event.kind == 6 && !(_includeReposts[subscriptionType] ?? false)) {
        Log.warning(
            '⏩ Skipping historical repost event ${event.id.substring(0, 8)}... (reposts disabled)',
            name: 'VideoEventService',
            category: LogCategory.video);
        return;
      }

      // Check if we already have this event in this subscription type
      final eventList = _eventLists[subscriptionType] ?? [];
      if (eventList.any((e) => e.id == event.id)) {
        _duplicateVideoEventCount++;
        _logDuplicateVideoEventsAggregated();
        return;
      }

      // Check if content is blocked
      if (_blocklistService?.shouldFilterFromFeeds(event.pubkey) == true) {
        Log.verbose(
            'Filtering blocked historical content from ${event.pubkey.substring(0, 8)}...',
            name: 'VideoEventService',
            category: LogCategory.video);
        return;
      }

      // Handle different event kinds (same logic as real-time events)
      if (NIP71VideoKinds.isVideoKind(event.kind)) {
        // Direct video event
        Log.verbose(
            'Processing historical video event ${event.id.substring(0, 8)}...',
            name: 'VideoEventService',
            category: LogCategory.video);
        try {
          final videoEvent = VideoEvent.fromNostrEvent(event);

          // Handle replaceable events (NIP-33)
          // Returns true if we should add this event (newer or first version)
          // Returns false if we should skip this event (older than cached version)
          if (!_handleReplaceableVideoEvent(videoEvent, subscriptionType, event)) {
            return; // Skip - incoming event is older than what we already have
          }
          // If we reach here: either not replaceable, first time seeing it, or newer version
          // For newer versions, _handleReplaceableVideoEvent already removed the old event

          // Check hashtag filter if active
          if (_activeHashtagFilters[subscriptionType] != null &&
              _activeHashtagFilters[subscriptionType]!.isNotEmpty) {
            final hasRequiredHashtag =
                _activeHashtagFilters[subscriptionType]!.any(
              videoEvent.hashtags.contains,
            );

            if (!hasRequiredHashtag) {
              Log.warning(
                  '⏩ Skipping historical video without required hashtags: ${_activeHashtagFilters[subscriptionType]}',
                  name: 'VideoEventService',
                  category: LogCategory.video);
              return;
            }
          }

          // Check group filter if active
          if (_activeGroupFilters[subscriptionType] != null &&
              videoEvent.group != _activeGroupFilters[subscriptionType]) {
            Log.warning(
                '⏩ Skipping historical video from different group: ${videoEvent.group} (want: ${_activeGroupFilters[subscriptionType]})',
                name: 'VideoEventService',
                category: LogCategory.video);
            return;
          }

          // Only add events with video URLs
          if (videoEvent.hasVideo) {
            _addVideoToSubscription(videoEvent, subscriptionType,
                isHistorical: true);

            // Keep only the most recent events to prevent memory issues
            final list = _eventLists[subscriptionType] ?? [];
            if (list.length > 500) {
              list.removeRange(500, list.length);
            }
          } else {
            Log.warning(
                '🎬 FILTER: ⏩ Skipping historical video event without video URL (hasVideo=false)',
                name: 'VideoEventService',
                category: LogCategory.video);
          }
        } catch (e) {
          Log.error('Failed to parse historical video event: $e',
              name: 'VideoEventService', category: LogCategory.video);
        }
      } else if (event.kind == 6) {
        // Repost event - same logic as real-time but marked as historical
        Log.verbose(
            'Processing historical repost event ${event.id.substring(0, 8)}...',
            name: 'VideoEventService',
            category: LogCategory.video);

        final originalEventId = event.tags
            .where((tag) => tag.length >= 2 && tag[0] == 'e')
            .map((tag) => tag[1])
            .firstOrNull;

        if (originalEventId != null) {
          VideoEvent? existingOriginal;
          for (final eventList in _eventLists.values) {
            try {
              existingOriginal =
                  eventList.firstWhere((e) => e.id == originalEventId);
              break;
            } catch (e) {
              // Continue searching in other lists
            }
          }

          if (existingOriginal != null) {
            final repostEvent = VideoEvent.createRepostEvent(
              originalEvent: existingOriginal,
              repostEventId: event.id,
              reposterPubkey: event.pubkey,
              repostedAt:
                  DateTime.fromMillisecondsSinceEpoch(event.createdAt * 1000),
            );
            _addVideoToSubscription(repostEvent, subscriptionType,
                isHistorical: true);
            final totalEvents = getEventCount(subscriptionType);
            Log.verbose(
                'Added historical $subscriptionType repost event! Total: $totalEvents events',
                name: 'VideoEventService',
                category: LogCategory.video);
          } else {
            // For historical reposts, we could fetch the original but for now skip
            Log.warning(
                '⏩ Skipping historical repost - original event not found locally',
                name: 'VideoEventService',
                category: LogCategory.video);
          }
        }
      }
    } catch (e) {
      Log.error('Error processing historical video event: $e',
          name: 'VideoEventService', category: LogCategory.video);
    }
  }

  /// Handle subscription error
  void _handleSubscriptionError(
      dynamic error, SubscriptionType subscriptionType) {
    _error = error.toString();
    Log.error('$subscriptionType subscription error: $error',
        name: 'VideoEventService', category: LogCategory.video);
    final totalSubs = _subscriptions.length + _activeSubscriptionIds.length;
    final eventCount = getEventCount(subscriptionType);
    Log.verbose(
        'Current state: $subscriptionType events=$eventCount, subscriptions=$totalSubs',
        name: 'VideoEventService',
        category: LogCategory.video);

    // Check if it's a connection error and schedule retry
    if (_isConnectionError(error)) {
      Log.error('📱 Subscription connection error, scheduling retry...',
          name: 'VideoEventService', category: LogCategory.video);
      _scheduleRetryWhenOnline();
    }
  }

  /// Handle subscription completion
  void _handleSubscriptionComplete(SubscriptionType subscriptionType) {
    Log.info('📱 $subscriptionType subscription completed',
        name: 'VideoEventService', category: LogCategory.video);
    final totalSubs = _subscriptions.length + _activeSubscriptionIds.length;
    final eventCount = getEventCount(subscriptionType);
    Log.verbose(
        'Final state: $subscriptionType events=$eventCount, subscriptions=$totalSubs',
        name: 'VideoEventService',
        category: LogCategory.video);
  }

  /// Subscribe to specific user's video events
  Future<void> subscribeToUserVideos(String pubkey, {int limit = 50}) async {
    Log.info('SVC subscribeToUser: hex=$pubkey', name: 'Service', category: LogCategory.video);

    // Backfill _authorBuckets with videos by this author that already exist in other subscription types
    // This handles the case where the user's videos were already loaded in discovery/home feeds
    final bucket = _authorBuckets.putIfAbsent(pubkey, () => []);
    for (final eventList in _eventLists.values) {
      for (final video in eventList) {
        if (video.pubkey == pubkey && !bucket.any((e) => e.id == video.id)) {
          bucket.add(video);
        }
      }
    }
    // Sort backfilled videos by newest first
    if (bucket.isNotEmpty) {
      bucket.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      Log.info('SVC subscribeToUser: backfilled ${bucket.length} existing videos for $pubkey',
          name: 'Service', category: LogCategory.video);
    }

    return subscribeToVideoFeed(
      subscriptionType: SubscriptionType.profile,
      authors: [pubkey],
      limit: limit,
    );
  }

  /// Query historical videos for a specific user (for pagination)
  /// This is used by profile feed provider to load older videos beyond the initial subscription
  Future<void> queryHistoricalUserVideos(String pubkey, {int? until, int limit = 50}) async {
    if (!_nostrService.isInitialized) {
      Log.warning('Cannot query historical user videos - Nostr service not initialized',
          name: 'VideoEventService', category: LogCategory.video);
      return;
    }

    Log.info(
      'Querying historical videos for user=${pubkey.substring(0, 8)}... until=${until != null ? DateTime.fromMillisecondsSinceEpoch(until * 1000) : 'none'} limit=$limit',
      name: 'VideoEventService',
      category: LogCategory.video,
    );

    // Create filter for this specific user's videos
    final filter = Filter(
      kinds: NIP71VideoKinds.getAllVideoKinds(),
      authors: [pubkey],
      until: until,
      limit: limit,
    );

    final completer = Completer<void>();
    int receivedCount = 0;

    try {
      // Stream events from NostrService
      final eventStream = _nostrService.subscribeToEvents(filters: [filter]);
      late StreamSubscription<Event> streamSubscription;

      // Set timeout for receiving events
      final timeoutTimer = Timer(const Duration(seconds: 5), () {
        Log.info(
          'Historical query timeout for user=${pubkey.substring(0, 8)}... - received $receivedCount events',
          name: 'VideoEventService',
          category: LogCategory.video,
        );
        if (!completer.isCompleted) {
          streamSubscription.cancel();
          completer.complete();
        }
      });

      streamSubscription = eventStream.listen(
        (event) {
          receivedCount++;
          // Process event and add to author bucket using existing handler
          _handleNewVideoEvent(event, SubscriptionType.profile);
        },
        onDone: () {
          timeoutTimer.cancel();
          if (!completer.isCompleted) {
            Log.info(
              'Historical query stream completed for user=${pubkey.substring(0, 8)}... - received $receivedCount events',
              name: 'VideoEventService',
              category: LogCategory.video,
            );
            completer.complete();
          }
        },
        onError: (error) {
          timeoutTimer.cancel();
          if (!completer.isCompleted) {
            Log.error(
              'Historical query stream error for user=${pubkey.substring(0, 8)}...: $error',
              name: 'VideoEventService',
              category: LogCategory.video,
            );
            completer.completeError(error);
          }
        },
        cancelOnError: false,
      );

      await completer.future;
      await streamSubscription.cancel();

      Log.info(
        'Historical user videos query completed - received $receivedCount events for user=${pubkey.substring(0, 8)}...',
        name: 'VideoEventService',
        category: LogCategory.video,
      );

      // Notify listeners to update UI
      notifyListeners();
    } catch (e) {
      Log.error(
        'Failed to query historical user videos for user=${pubkey.substring(0, 8)}...: $e',
        name: 'VideoEventService',
        category: LogCategory.video,
      );
      rethrow;
    }
  }

  /// Subscribe to videos with specific hashtags
  Future<void> subscribeToHashtagVideos(List<String> hashtags,
          {int limit = 100}) async =>
      subscribeToVideoFeed(
        subscriptionType: SubscriptionType.hashtag,
        hashtags: hashtags,
        limit: limit,
      );

  /// Subscribe to home feed videos (from people you follow)
  Future<void> subscribeToHomeFeed(List<String> followingPubkeys,
          {int limit = 100}) async =>
      subscribeToVideoFeed(
        subscriptionType: SubscriptionType.homeFeed,
        authors: followingPubkeys,
        limit: limit,
        includeReposts: true,
      );

  /// Subscribe to discovery videos (all videos for exploration)
  Future<void> subscribeToDiscovery({int limit = 100}) async =>
      subscribeToVideoFeed(
        subscriptionType: SubscriptionType.discovery,
        authors: null, // No author filter
        limit: limit,
        includeReposts: true,
      );

  /// Subscribe to videos from a specific group (using 'h' tag)
  Future<void> subscribeToGroupVideos(
    String group, {
    List<String>? authors,
    int? since,
    int? until,
    int limit = 200,
  }) async {
    if (!_nostrService.isInitialized) {
      Log.warning('Cannot subscribe to group - Nostr service not initialized (will retry when ready)',
          name: 'VideoEventService', category: LogCategory.video);
      return; // Defensive: Don't throw, just return early
    }

    Log.verbose('Subscribing to videos from group: $group',
        name: 'VideoEventService', category: LogCategory.video);

    // Note: Nostr SDK Filter doesn't support custom tags directly,
    // so we'll rely on client-side filtering for group 'h' tags
    Log.verbose('Subscribing to group: $group (will filter client-side)',
        name: 'VideoEventService', category: LogCategory.video);

    // Use existing subscription infrastructure with group parameter
    return subscribeToVideoFeed(
      subscriptionType: SubscriptionType.hashtag,
      authors: authors,
      group: group,
      since: since,
      until: until,
      limit: limit,
    );
  }

  /// Get video events by group from cache
  List<VideoEvent> getVideoEventsByGroup(String group) {
    final allEvents = <VideoEvent>[];
    for (final events in _eventLists.values) {
      allEvents.addAll(events.where((event) => event.group == group));
    }
    return allEvents;
  }

  /// Refresh video feed by fetching recent events with expanded timeframe
  Future<void> refreshVideoFeed() async {
    Log.verbose(
        'Refresh requested - restarting subscription with expanded timeframe',
        name: 'VideoEventService',
        category: LogCategory.video);

    // Close existing subscriptions and create new ones with expanded timeframe
    await unsubscribeFromVideoFeed();

    Log.verbose('Creating new subscription with expanded timeframe...',
        name: 'VideoEventService', category: LogCategory.video);
    // Preserve the current reposts setting when refreshing
    return subscribeToVideoFeed(
      subscriptionType: SubscriptionType.discovery,
      includeReposts: false,
    );
  }

  /// Progressive loading: load more videos after initial fast load
  Future<void> loadMoreVideos({int limit = 100}) async {
    Log.verbose('📱 Loading more videos progressively...',
        name: 'VideoEventService', category: LogCategory.video);

    // Use larger limit for progressive loading
    return subscribeToVideoFeed(
      subscriptionType: SubscriptionType.discovery,
      limit: limit,
      replace: false, // Don't replace existing subscription
    );
  }

  /// Load more historical events using one-shot query (not persistent subscription)
  Future<void> loadMoreEvents(SubscriptionType subscriptionType,
      {int limit = 500}) async {
    final paginationState = _paginationStates[subscriptionType];
    if (paginationState == null) {
      throw VideoEventServiceException(
          'No pagination state found for $subscriptionType');
    }

    if (paginationState.isLoading) {
      Log.debug('📱 Skipping load more for $subscriptionType: already loading',
          name: 'VideoEventService', category: LogCategory.video);
      return;
    }

    // If hasMore is false, always try to reset and fetch more
    // Users should be able to keep scrolling to get more content
    if (!paginationState.hasMore) {
      final currentEventCount = _eventLists[subscriptionType]?.length ?? 0;
      Log.info(
          '📱 Resetting pagination for $subscriptionType - have $currentEventCount videos, forcing retry to fetch more',
          name: 'VideoEventService',
          category: LogCategory.video);
      paginationState.reset();
    }

    paginationState.startQuery();

    try {
      Log.debug('📱 Loading more historical events for $subscriptionType...',
          name: 'VideoEventService', category: LogCategory.video);

      int? until;
      final existingEvents = _eventLists[subscriptionType] ?? [];

      // If pagination state doesn't have oldest timestamp but we have events,
      // recalculate it from existing events (happens after pagination reset)
      if (existingEvents.isNotEmpty &&
          paginationState.oldestTimestamp == null) {
        // Find the oldest event timestamp from existing events
        int? oldestFromEvents;
        for (final event in existingEvents) {
          if (oldestFromEvents == null || event.createdAt < oldestFromEvents) {
            oldestFromEvents = event.createdAt;
          }
        }
        if (oldestFromEvents != null) {
          paginationState.updateOldestTimestamp(oldestFromEvents);
          Log.debug(
              '📱 Recalculated oldest timestamp from existing events: ${DateTime.fromMillisecondsSinceEpoch(oldestFromEvents * 1000)}',
              name: 'VideoEventService',
              category: LogCategory.video);
        }
      }

      if (existingEvents.isNotEmpty &&
          paginationState.oldestTimestamp != null) {
        // Use existing oldest timestamp WITHOUT creating a gap
        until = paginationState.oldestTimestamp;
        Log.debug(
            '📱 Requesting events older than or equal to ${DateTime.fromMillisecondsSinceEpoch(until! * 1000)} for $subscriptionType',
            name: 'VideoEventService',
            category: LogCategory.video);
      } else {
        // If no events yet, load without date constraints
        Log.debug(
            '📱 No existing events for $subscriptionType, loading fresh content without date constraints',
            name: 'VideoEventService',
            category: LogCategory.video);
      }

      // Use subscription-aware historical query (non-blocking streaming)
      _queryHistoricalEvents(
              subscriptionType: subscriptionType, until: until, limit: limit)
          .then((_) {
        // Stream completed - finalize pagination state
        Log.info(
            'Historical events streaming completed for $subscriptionType. Total events: ${_eventLists[subscriptionType]?.length ?? 0}',
            name: 'VideoEventService',
            category: LogCategory.video);

        // Complete the pagination query with the requested limit for proper hasMore tracking
        paginationState.completeQuery(limit);

        // Final notification - will only fire if no frame update was scheduled
        // This ensures UI updates even if no events were received
        notifyListeners();
      }).catchError((error) {
        Log.error(
            'Historical query stream failed for $subscriptionType: $error',
            name: 'VideoEventService',
            category: LogCategory.video);
        paginationState.isLoading = false;
      });

      // Don't await the query - return immediately and let events stream in
      Log.debug(
          'Historical query started for $subscriptionType, events will stream in',
          name: 'VideoEventService',
          category: LogCategory.video);
    } catch (e) {
      _error = e.toString();
      Log.error('Failed to load more events for $subscriptionType: $e',
          name: 'VideoEventService', category: LogCategory.video);

      if (_isConnectionError(e)) {
        Log.error(
            '📱 Load more failed due to connection error for $subscriptionType',
            name: 'VideoEventService',
            category: LogCategory.video);
      }
      paginationState.isLoading = false;
    }
  }

  /// Streaming query for historical events (processes events as they arrive)
  Future<void> _queryHistoricalEvents(
      {required SubscriptionType subscriptionType,
      int? until,
      int limit = 500}) async {
    if (!_nostrService.isInitialized) {
      Log.warning('Cannot query historical events - Nostr service not initialized',
          name: 'VideoEventService', category: LogCategory.video);
      return; // Defensive: Don't throw, just return early
    }

    // Get current subscription parameters to maintain consistency
    final params = _subscriptionParams[subscriptionType];
    final authors = params?['authors'] as List<String>?;
    final hashtags = params?['hashtags'] as List<String>?;
    // Note: group filtering is handled client-side, not in relay query

    // Create filter without restrictive date constraints
    final filter = Filter(
      kinds: NIP71VideoKinds.getAllVideoKinds(), // NIP-71 video events + legacy support
      authors: authors, // Use same authors as main subscription if available
      until: until, // Only use 'until' if we have existing events
      limit: limit,
      t: hashtags
          ?.map((tag) => tag.toLowerCase())
          .toList(), // Add hashtag filter if present
      // No 'since' filter to allow loading of all historical content
    );

    debugPrint(
        '🔍 Streaming historical query for $subscriptionType: until=${until != null ? DateTime.fromMillisecondsSinceEpoch(until * 1000) : 'none'}, limit=$limit');
    Log.debug('Filter: ${filter.toJson()}',
        name: 'VideoEventService', category: LogCategory.video);

    final completer = Completer<void>();
    int receivedCount = 0;

    try {
      // Use direct NostrService streaming approach like ProfileWebSocketService
      final eventStream = _nostrService.subscribeToEvents(filters: [filter]);
      late StreamSubscription<Event> streamSubscription;

      // Set a reasonable timeout for receiving events
      Timer? timeoutTimer = Timer(const Duration(seconds: 5), () {
        Log.info(
            '📡 Historical query timeout reached for $subscriptionType - received $receivedCount events',
            name: 'VideoEventService',
            category: LogCategory.video);
        if (!completer.isCompleted) {
          streamSubscription.cancel();
          completer.complete();
        }
      });

      // Process events immediately as they arrive from the stream
      streamSubscription = eventStream.listen(
        (event) {
          // Handle video events immediately as they arrive
          if (NIP71VideoKinds.isVideoKind(event.kind)) {
            receivedCount++;
            _handleHistoricalVideoEvent(event, subscriptionType);

            // Reset timeout on each event received
            timeoutTimer?.cancel();
            timeoutTimer = Timer(const Duration(seconds: 2), () {
              Log.info(
                  '📡 No more events for 2 seconds - completing query for $subscriptionType',
                  name: 'VideoEventService',
                  category: LogCategory.video);
              if (!completer.isCompleted) {
                streamSubscription.cancel();
                completer.complete();
              }
            });
          }
        },
        onError: (error) {
          Log.error(
            'Historical query stream error for $subscriptionType: $error',
            name: 'VideoEventService',
            category: LogCategory.video,
          );
          timeoutTimer?.cancel();
          if (!completer.isCompleted) {
            streamSubscription.cancel();
            completer.completeError(error);
          }
        },
        onDone: () {
          // Stream closed - this is fine, we got what we could
          Log.debug(
            '📡 Historical query stream closed for $subscriptionType - received $receivedCount events',
            name: 'VideoEventService',
            category: LogCategory.video,
          );
          timeoutTimer?.cancel();
          if (!completer.isCompleted) {
            streamSubscription.cancel();
            completer.complete();
          }
        },
      );

      // Wait for completion
      await completer.future;
    } catch (e) {
      Log.error(
        'Failed to execute historical query for $subscriptionType: $e',
        name: 'VideoEventService',
        category: LogCategory.video,
      );
      rethrow;
    }
  }

  /// Reset pagination state for a subscription type to allow fresh loading
  void resetPaginationState(SubscriptionType subscriptionType) {
    final paginationState = _paginationStates[subscriptionType];
    if (paginationState != null) {
      Log.info('📱 Resetting pagination state for $subscriptionType',
          name: 'VideoEventService', category: LogCategory.video);
      paginationState.reset();
    }
  }

  /// Load more content without date restrictions - for when users reach end of feed
  Future<void> loadMoreContentUnlimited(
      {SubscriptionType subscriptionType = SubscriptionType.discovery,
      int limit = 300}) async {
    // Prevent overlapping unlimited queries and runaway streaming
    if ((_eventLists[subscriptionType]?.length ?? 0) >= 120) {
      Log.debug('Skipping unlimited content: already have >=120 videos',
          name: 'VideoEventService', category: LogCategory.video);
      return;
    }

    // Use a simple in-flight guard
    _isLoading = true;

    try {
      Log.debug('📱 Loading unlimited content for end-of-feed...',
          name: 'VideoEventService', category: LogCategory.video);

      // Create a broader query without date restrictions
      final filter = Filter(
        kinds: NIP71VideoKinds.getAllVideoKinds(), // NIP-71 video events
        limit: limit,
        // No date filters - let relays return their best content
      );

      Log.debug('Unlimited content query: limit=$limit',
          name: 'VideoEventService', category: LogCategory.video);
      Log.debug('Filter: ${filter.toJson()}',
          name: 'VideoEventService', category: LogCategory.video);

      final eventStream = _nostrService.subscribeToEvents(filters: [filter]);
      late StreamSubscription subscription;

      subscription = eventStream.listen(
        (event) {
          // Process events immediately as they arrive
          _handleNewVideoEvent(event, subscriptionType);
        },
        onError: (error) {
          Log.error('Unlimited content query error: $error',
              name: 'VideoEventService', category: LogCategory.video);
          subscription.cancel();
        },
        onDone: () {
          // Stream closed - don't wait for this to complete business logic
          Log.debug('Unlimited content query stream closed',
              name: 'VideoEventService', category: LogCategory.video);
          subscription.cancel();
        },
      );

      // Close subscription after timeout - events are processed immediately
      Timer(const Duration(seconds: 45), () {
        Log.debug('⏰ Closing unlimited content query after 45s timeout',
            name: 'VideoEventService', category: LogCategory.video);
        subscription.cancel();
      });

      // Return immediately - events will be processed as they arrive
      Log.debug('Unlimited content query started, events will stream in',
          name: 'VideoEventService', category: LogCategory.video);
    } catch (e) {
      _error = e.toString();
      Log.error('Failed to load unlimited content: $e',
          name: 'VideoEventService', category: LogCategory.video);

      if (_isConnectionError(e)) {
        Log.error('📱 Unlimited content load failed due to connection error',
            name: 'VideoEventService', category: LogCategory.video);
      }
    } finally {
      _isLoading = false;
    }
  }

  /// Get video event by ID
  VideoEvent? getVideoEventById(String eventId) {
    for (final events in _eventLists.values) {
      try {
        return events.firstWhere((event) => event.id == eventId);
      } catch (e) {
        // Continue searching in other lists
      }
    }
    return null;
  }

  /// Get video event by vine ID (using 'd' tag)
  VideoEvent? getVideoEventByVineId(String vineId) {
    for (final events in _eventLists.values) {
      try {
        return events.firstWhere((event) => event.vineId == vineId);
      } catch (e) {
        // Continue searching in other lists
      }
    }
    return null;
  }

  /// Query video events by vine ID from relays
  Future<VideoEvent?> queryVideoByVineId(String vineId) async {
    if (!_nostrService.isInitialized) {
      Log.warning('Cannot query video by ID - Nostr service not initialized',
          name: 'VideoEventService', category: LogCategory.video);
      return null; // Defensive: Don't throw, just return null
    }

    Log.debug('Querying for video with vine ID: $vineId',
        name: 'VideoEventService', category: LogCategory.video);

    final completer = Completer<VideoEvent?>();
    VideoEvent? foundEvent;

    // Filter by the 'd' tag for addressable events
    final filter = Filter(
      kinds: NIP71VideoKinds.getAllVideoKinds(),
      d: [vineId], // Filter by the specific d tag value
      limit: 10, // Should only need one, but fetch a few in case
    );

    Log.debug('Querying for videos, will filter for vine ID: $vineId',
        name: 'VideoEventService', category: LogCategory.video);

    final eventStream = _nostrService.subscribeToEvents(filters: [filter]);
    late StreamSubscription subscription;

    subscription = eventStream.listen(
      (event) {
        try {
          final videoEvent = VideoEvent.fromNostrEvent(event);
          // Since we're filtering by d tag at the relay level, this should be our video
          Log.info(
              'Found video event for vine ID $vineId: ${event.id.substring(0, 8)}...',
              name: 'VideoEventService',
              category: LogCategory.video);
          foundEvent = videoEvent;
          if (!completer.isCompleted) {
            completer.complete(foundEvent);
          }
          subscription.cancel();
        } catch (e) {
          Log.error('Error parsing video event: $e',
              name: 'VideoEventService', category: LogCategory.video);
        }
      },
      onError: (error) {
        Log.error('Error querying video by vine ID: $error',
            name: 'VideoEventService', category: LogCategory.video);
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
        subscription.cancel();
      },
      onDone: () {
        // Stream closed naturally - complete with result if not already completed
        Log.debug('Vine ID query stream closed',
            name: 'VideoEventService', category: LogCategory.video);
        if (!completer.isCompleted) {
          completer.complete(foundEvent);
        }
        subscription.cancel();
      },
    );

    // Set timeout for the query - don't wait indefinitely
    Timer(const Duration(seconds: 10), () {
      if (!completer.isCompleted) {
        Log.debug('⏰ Vine ID query timed out after 10 seconds',
            name: 'VideoEventService', category: LogCategory.video);
        subscription.cancel();
        completer.complete(null);
      }
    });

    return completer.future;
  }

  /// Get video events by author
  List<VideoEvent> getVideoEventsByAuthor(String pubkey) {
    final result = <VideoEvent>[];
    for (final events in _eventLists.values) {
      result.addAll(events.where((event) => event.pubkey == pubkey));
    }
    return result;
  }

  /// Get video events with specific hashtags
  List<VideoEvent> getVideoEventsByHashtags(List<String> hashtags) {
    final result = <VideoEvent>[];
    final seenIds = <String>{};

    // Convert requested hashtags to lowercase for case-insensitive comparison
    final hashtagsLower = hashtags.map((tag) => tag.toLowerCase()).toList();

    Log.debug(
        '🔍 Searching for videos with hashtags: $hashtagsLower',
        name: 'VideoEventService',
        category: LogCategory.video);

    // Log event list sizes for debugging
    for (final entry in _eventLists.entries) {
      Log.debug(
          '  - ${entry.key}: ${entry.value.length} videos',
          name: 'VideoEventService',
          category: LogCategory.video);
    }

    for (final events in _eventLists.values) {
      for (final event in events) {
        // Convert event hashtags to lowercase for comparison
        final eventHashtagsLower =
            event.hashtags.map((tag) => tag.toLowerCase()).toList();

        // Check if event has any of the requested hashtags (case-insensitive)
        if (hashtagsLower.any(eventHashtagsLower.contains)) {
          if (!seenIds.contains(event.id)) {
            seenIds.add(event.id);
            result.add(event);
          }
        }
      }
    }

    Log.debug(
        '✅ Found ${result.length} videos with hashtags: $hashtagsLower',
        name: 'VideoEventService',
        category: LogCategory.video);

    // Apply loops-first sort for any assembled set
    result.sort(VideoEvent.compareByLoopsThenTime);
    return result;
  }

  /// Clear all video events
  void clearVideoEvents() {
    for (final events in _eventLists.values) {
      events.clear();
    }
  }

  /// Cancel all existing subscriptions
  Future<void> _cancelExistingSubscriptions() async {
    // Cancel managed subscriptions
    if (_activeSubscriptionIds.isNotEmpty) {
      Log.debug(
          'Cancelling ${_activeSubscriptionIds.length} managed subscriptions...',
          name: 'VideoEventService',
          category: LogCategory.video);
      for (final subscriptionId in _activeSubscriptionIds) {
        await _subscriptionManager.cancelSubscription(subscriptionId);
      }
      _activeSubscriptionIds.clear();
    }

    // Cancel direct subscriptions
    if (_subscriptions.isNotEmpty) {
      Log.debug('Cancelling ${_subscriptions.length} direct subscriptions...',
          name: 'VideoEventService', category: LogCategory.video);
      for (final entry in _subscriptions.entries) {
        await entry.value.cancel();
      }
      _subscriptions.clear();
    }
  }

  /// Unsubscribe from all video event subscriptions
  Future<void> unsubscribeFromVideoFeed() async {
    try {
      await _cancelExistingSubscriptions();
      // Clear all subscription tracking
      _subscriptionParams.clear();
      _activeSubscriptions.clear();

      Log.info('Successfully unsubscribed from all video events',
          name: 'VideoEventService', category: LogCategory.video);
    } catch (e) {
      Log.error('Error unsubscribing from video events: $e',
          name: 'VideoEventService', category: LogCategory.video);
    }
  }

  /// Get video events sorted by engagement (placeholder - would need reaction events)
  List<VideoEvent> getVideoEventsByEngagement() {
    // For now, just return chronologically sorted
    // In a full implementation, would sort by likes, comments, shares, etc.
    final allEvents = <VideoEvent>[];
    for (final events in _eventLists.values) {
      allEvents.addAll(events);
    }
    return List.from(allEvents)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Get video events from last N hours
  List<VideoEvent> getRecentVideoEvents({int hours = 24}) {
    final cutoff = DateTime.now().subtract(Duration(hours: hours));
    final result = <VideoEvent>[];
    for (final events in _eventLists.values) {
      result.addAll(events.where((event) => event.timestamp.isAfter(cutoff)));
    }
    return result;
  }

  /// Get unique authors from video events
  Set<String> getUniqueAuthors() {
    final result = <String>{};
    for (final events in _eventLists.values) {
      result.addAll(events.map((event) => event.pubkey));
    }
    return result;
  }

  /// Get all hashtags from video events
  Set<String> getAllHashtags() {
    final allTags = <String>{};
    for (final events in _eventLists.values) {
      for (final event in events) {
        allTags.addAll(event.hashtags);
      }
    }
    return allTags;
  }

  /// Get video events count by author
  Map<String, int> getVideoCountByAuthor() {
    final counts = <String, int>{};
    for (final events in _eventLists.values) {
      for (final event in events) {
        counts[event.pubkey] = (counts[event.pubkey] ?? 0) + 1;
      }
    }
    return counts;
  }

  /// Fetch original event for a repost from relays
  Future<void> _fetchOriginalEventForRepost(
      String originalEventId, Event repostEvent) async {
    try {
      Log.debug(
          'Fetching original event $originalEventId for repost ${repostEvent.id.substring(0, 8)}...',
          name: 'VideoEventService',
          category: LogCategory.video);

      // Create a one-shot subscription to fetch the specific event
      final eventStream = _nostrService.subscribeToEvents(
        filters: [
          Filter(
            ids: [originalEventId],
          ),
        ],
      );

      // Listen for the original event
      late StreamSubscription subscription;
      subscription = eventStream.listen(
        (originalEvent) {
          Log.debug(
              'Retrieved original event ${originalEvent.id.substring(0, 8)}...',
              name: 'VideoEventService',
              category: LogCategory.video);
          Log.debug('Event tags: ${originalEvent.tags}',
              name: 'VideoEventService', category: LogCategory.video);

          // Check if it's a valid video event
          if (NIP71VideoKinds.isVideoKind(originalEvent.kind)) {
            try {
              final originalVideoEvent =
                  VideoEvent.fromNostrEvent(originalEvent);
              Log.debug(
                  'Parsed video event: hasVideo=${originalVideoEvent.hasVideo}, videoUrl=${originalVideoEvent.videoUrl}',
                  name: 'VideoEventService',
                  category: LogCategory.video);

              // Only process if it has video content
              if (originalVideoEvent.hasVideo) {
                // Create the repost version
                final repostVideoEvent = VideoEvent.createRepostEvent(
                  originalEvent: originalVideoEvent,
                  repostEventId: repostEvent.id,
                  reposterPubkey: repostEvent.pubkey,
                  repostedAt: DateTime.fromMillisecondsSinceEpoch(
                      repostEvent.createdAt * 1000),
                );

                // Check hashtag filter for fetched reposts too
                final activeHashtagFilter =
                    _activeHashtagFilters[SubscriptionType.discovery];
                if (activeHashtagFilter != null &&
                    activeHashtagFilter.isNotEmpty) {
                  final hasRequiredHashtag = activeHashtagFilter.any(
                    repostVideoEvent.hashtags.contains,
                  );

                  if (!hasRequiredHashtag) {
                    Log.warning(
                        '⏩ Skipping fetched repost without required hashtags: $activeHashtagFilter',
                        name: 'VideoEventService',
                        category: LogCategory.video);
                    return;
                  }
                }

                // Add to video events (use discovery subscription type for fetched reposts)
                _addVideoToSubscription(
                    repostVideoEvent, SubscriptionType.discovery,
                    isHistorical: false);

                // Keep list size manageable
                final discoveryEvents =
                    _eventLists[SubscriptionType.discovery]!;
                if (discoveryEvents.length > 500) {
                  discoveryEvents.removeRange(500, discoveryEvents.length);
                }

                Log.debug(
                    'Added fetched repost event! Total: ${discoveryEvents.length} events',
                    name: 'VideoEventService',
                    category: LogCategory.video);
              } else {
                Log.warning('⏩ Skipping repost of video without URL',
                    name: 'VideoEventService', category: LogCategory.video);
              }
            } catch (e) {
              Log.error('Failed to parse original video event for repost: $e',
                  name: 'VideoEventService', category: LogCategory.video);
            }
          }

          // Clean up subscription
          subscription.cancel();
        },
        onError: (error) {
          Log.error('Error fetching original event for repost: $error',
              name: 'VideoEventService', category: LogCategory.video);
          subscription.cancel();
        },
        onDone: () {
          Log.debug('📱 Finished fetching original event for repost',
              name: 'VideoEventService', category: LogCategory.video);
          subscription.cancel();
        },
      );

      // KEEP SUBSCRIPTION OPEN: Remove timeout for persistent repost event fetching
      // Original events may take time to arrive from relays
      // Let subscription complete naturally on onDone or when event is found
    } catch (e) {
      Log.error('Error in _fetchOriginalEventForRepost: $e',
          name: 'VideoEventService', category: LogCategory.video);
    }
  }

  /// Check if an error is connection-related
  bool _isConnectionError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('connection') ||
        errorString.contains('network') ||
        errorString.contains('socket') ||
        errorString.contains('timeout') ||
        errorString.contains('offline') ||
        errorString.contains('unreachable');
  }

  /// Schedule retry when device comes back online
  void _scheduleRetryWhenOnline() {
    _retryTimer?.cancel();

    _retryTimer = Timer.periodic(_retryDelay, (timer) {
      if (_connectionService.isOnline && _retryAttempts < _maxRetryAttempts) {
        _retryAttempts++;
        Log.warning(
            'Attempting to resubscribe to video feed (attempt $_retryAttempts/$_maxRetryAttempts)',
            name: 'VideoEventService',
            category: LogCategory.video);

        subscribeToVideoFeed(subscriptionType: SubscriptionType.discovery)
            .then((_) {
          // Success - cancel retry timer
          timer.cancel();
          _retryAttempts = 0;
          Log.info('Successfully resubscribed to video feed',
              name: 'VideoEventService', category: LogCategory.video);
        }).catchError((e) {
          Log.error('Retry attempt $_retryAttempts failed: $e',
              name: 'VideoEventService', category: LogCategory.video);

          if (_retryAttempts >= _maxRetryAttempts) {
            timer.cancel();
            Log.warning(
                'Max retry attempts reached for video feed subscription',
                name: 'VideoEventService',
                category: LogCategory.video);
          }
        });
      } else if (!_connectionService.isOnline) {
        Log.debug('⏳ Still offline, waiting for connection...',
            name: 'VideoEventService', category: LogCategory.video);
      } else {
        // Max retries reached
        timer.cancel();
      }
    });
  }

  /// Get connection status for debugging
  Map<String, dynamic> getConnectionStatus() => {
        'activeSubscriptions':
            _activeSubscriptions.keys.map((e) => e.name).toList(),
        'subscriptionCounts': Map.fromEntries(SubscriptionType.values
            .map((type) => MapEntry(type.name, getEventCount(type)))),
        'isLoading': _isLoading,
        'retryAttempts': _retryAttempts,
        'hasError': _error != null,
        'lastError': _error,
        'connectionInfo': _connectionService.getConnectionInfo(),
      };

  /// Force retry subscription
  Future<void> retrySubscription() async {
    Log.warning('Forcing retry of video feed subscription...',
        name: 'VideoEventService', category: LogCategory.video);
    _retryAttempts = 0;
    _error = null;

    try {
      await subscribeToVideoFeed(subscriptionType: SubscriptionType.discovery);
    } catch (e) {
      Log.error('Manual retry failed: $e',
          name: 'VideoEventService', category: LogCategory.video);
      rethrow;
    }
  }

  /// Check if a repost event is likely to reference video content
  bool _isLikelyVideoRepost(Event repostEvent) {
    // Check content for video-related keywords
    final content = repostEvent.content.toLowerCase();
    final videoKeywords = [
      'video',
      'gif',
      'mp4',
      'webm',
      'mov',
      'vine',
      'clip',
      'watch'
    ];

    // Check for video file extensions or video-related terms
    if (videoKeywords.any(content.contains)) {
      return true;
    }

    // Check tags for video-related hashtags
    for (final tag in repostEvent.tags) {
      if (tag.isNotEmpty && tag[0] == 't' && tag.length > 1) {
        final hashtag = tag[1].toLowerCase();
        if (videoKeywords.any(hashtag.contains)) {
          return true;
        }
      }
    }

    // Check for presence of 'k' tag indicating original event kind
    for (final tag in repostEvent.tags) {
      if (tag.isNotEmpty && tag[0] == 'k' && tag.length > 1) {
        // If the repost explicitly indicates it's reposting a video event
        final referencedKind = int.tryParse(tag[1]);
        if (referencedKind != null && NIP71VideoKinds.isVideoKind(referencedKind)) {
          return true;
        }
      }
    }

    // For now, default to processing all reposts to avoid missing content
    // This can be made more strict as we gather data on repost patterns
    return true;
  }

  /// Ensure default content is available for new users
  void _ensureDefaultContent() {
    // DISABLED: Default video system disabled due to loading issues
    // The default video was not loading properly and causing user experience issues
    Log.warning(
        'Default video system is disabled - users will see real content only',
        name: 'VideoEventService',
        category: LogCategory.video);
    return;
  }

  /// Add video to specific subscription list
  void _addVideoToSubscription(
      VideoEvent videoEvent, SubscriptionType subscriptionType,
      {bool isHistorical = false}) {
    // CRITICAL: Filter out locally deleted videos to prevent pagination resurrection
    if (isVideoLocallyDeleted(videoEvent.id)) {
      Log.debug(
          'Filtering out locally deleted video ${videoEvent.id.substring(0, 8)} from $subscriptionType feed',
          name: 'VideoEventService',
          category: LogCategory.video);
      return; // Don't resurrect deleted videos
    }

    // CRITICAL: Validate that video has an accessible URL before adding to feed
    if (!_hasValidVideoUrl(videoEvent)) {
      Log.warning(
          'Rejecting $subscriptionType video ${videoEvent.id.substring(0, 8)} - no valid video URL (url: ${videoEvent.videoUrl})',
          name: 'VideoEventService',
          category: LogCategory.video);
      return; // Don't add videos without valid URLs
    }

    final eventList = _eventLists[subscriptionType];
    if (eventList == null) {
      Log.error('Invalid subscription type: $subscriptionType',
          name: 'VideoEventService', category: LogCategory.video);
      return;
    }

    // Check for duplicates within this subscription type
    final existingIndex =
        eventList.indexWhere((existing) => existing.id == videoEvent.id);
    if (existingIndex != -1) {
      _duplicateVideoEventCount++;
      _logDuplicateVideoEventsAggregated();
      return; // Don't add duplicate events
    }

    // Fetch profile for video author if not already cached
    // This uses existing WebSocket connection with REQ command
    if (_userProfileService != null && !_userProfileService.hasProfile(videoEvent.pubkey)) {
      _userProfileService.fetchProfile(videoEvent.pubkey).catchError((error) {
        Log.warning(
          'Failed to fetch profile for ${videoEvent.pubkey.substring(0, 8)}: $error',
          name: 'VideoEventService',
          category: LogCategory.video,
        );
        return null;
      });
    }

    // REMOVED: Eager caching here was causing 100+ simultaneous downloads
    // Instead, video caching is handled on-demand by individual video controllers
    // This prevents bandwidth saturation that slows first video load

    // Different insertion strategies based on subscription type and event context
    switch (subscriptionType) {
      case SubscriptionType.homeFeed:
        if (isHistorical) {
          // Historical events: add to bottom (older content)
          eventList.add(videoEvent);
        } else {
          // Real-time events: add to top (newer content)
          eventList.insert(0, videoEvent);
        }
        break;

      case SubscriptionType.discovery:
        final isClassicVine =
            videoEvent.pubkey == AppConstants.classicVinesPubkey;
        if (isHistorical) {
          // Historical events: add to bottom regardless of classic vine status
          eventList.add(videoEvent);
        } else if (isClassicVine) {
          // Real-time classic vines go to the front
          eventList.insert(0, videoEvent);
        } else {
          // Real-time regular content added chronologically at top
          eventList.insert(0, videoEvent);
        }
        break;

      case SubscriptionType.profile:
      case SubscriptionType.hashtag:
      case SubscriptionType.search:
        if (isHistorical) {
          // Historical events: add to bottom
          eventList.add(videoEvent);
        } else {
          // Real-time events: add to top
          eventList.insert(0, videoEvent);
        }
        break;

      case SubscriptionType.editorial:
      case SubscriptionType.popularNow:
      case SubscriptionType.trending:
        // Editorial/trending: maintain order from server (always append)
        eventList.add(videoEvent);
        break;
    }

    // Populate keyed buckets for route-aware feeds
    if (subscriptionType == SubscriptionType.hashtag) {
      // Add video to each of its hashtag buckets
      for (final tag in videoEvent.hashtags) {
        final bucket = _hashtagBuckets.putIfAbsent(tag, () => []);
        if (!bucket.any((e) => e.id == videoEvent.id)) {
          if (isHistorical) {
            bucket.add(videoEvent);
          } else {
            bucket.insert(0, videoEvent);
          }
        }
      }
    } else if (subscriptionType == SubscriptionType.profile) {
      // Add video to author's bucket
      final authorHex = videoEvent.pubkey;
      final bucket = _authorBuckets.putIfAbsent(authorHex, () => []);
      if (!bucket.any((e) => e.id == videoEvent.id)) {
        if (isHistorical) {
          bucket.add(videoEvent);
        } else {
          bucket.insert(0, videoEvent);
        }
      }
    }

    // Sort lists using enhanced engagement-based scoring:
    // - Combines loops, comments, likes, and reposts
    // - Gives higher weight to meaningful engagement (comments > likes > reposts > loops)
    // - Includes time decay factor for freshness
    _sortByEngagement(eventList, subscriptionType);

    // Update pagination state for this subscription type
    final paginationState = _paginationStates[subscriptionType];
    if (paginationState != null) {
      paginationState.updateOldestTimestamp(videoEvent.createdAt);
      paginationState.markEventSeen(videoEvent.id);

      // Increment event counter if this is from a historical query
      if (isHistorical && paginationState.isLoading) {
        paginationState.incrementEventCount();
      }
    }

    // VideoManager integration removed - using pure Riverpod architecture

    Log.debug(
        '✅ Added $subscriptionType video: ${videoEvent.title ?? videoEvent.id.substring(0, 8)} (total: ${eventList.length})',
        name: 'VideoEventService',
        category: LogCategory.video);

    // Track metrics for progressive loading
    _totalEventsReceived++;
    _firstEventTime ??= DateTime.now();

    // Schedule frame-based UI update for progressive loading
    _scheduleFrameUpdate();
  }

  /// Log duplicate video events in an aggregated manner to reduce noise
  void _logDuplicateVideoEventsAggregated() {
    final now = DateTime.now();

    // Log aggregated duplicates every 30 seconds or every 25 duplicates
    if (_lastDuplicateVideoLogTime == null ||
        now.difference(_lastDuplicateVideoLogTime!).inSeconds >= 30 ||
        _duplicateVideoEventCount % 25 == 0) {
      if (_duplicateVideoEventCount > 0) {
        Log.verbose(
            '⏩ Skipped $_duplicateVideoEventCount duplicate video events in last ${_lastDuplicateVideoLogTime != null ? now.difference(_lastDuplicateVideoLogTime!).inSeconds : 0}s',
            name: 'VideoEventService',
            category: LogCategory.video);
      }

      _lastDuplicateVideoLogTime = now;
      _duplicateVideoEventCount = 0;
    }
  }

  /// Check if the given subscription parameters match the current active subscription for this type
  bool _isDuplicateSubscription(
      SubscriptionType subscriptionType,
      List<String>? authors,
      List<String>? hashtags,
      String? group,
      int limit,
      int? since,
      int? until,
      {bool includeReposts = false}) {
    // If no active subscription for this type, it's not a duplicate
    if (!isSubscribed(subscriptionType)) {
      return false;
    }

    // Compare with stored subscription parameters for this type
    final params = _subscriptionParams[subscriptionType];
    if (params == null) return false;

    final currentAuthors = params['authors'] as List<String>?;
    final currentHashtags = params['hashtags'] as List<String>?;
    final currentGroup = params['group'] as String?;
    final currentSince = params['since'] as int?;
    final currentUntil = params['until'] as int?;
    final currentLimit = params['limit'] as int?;
    final currentIncludeReposts = params['includeReposts'] as bool? ?? false;

    // Check if parameters match
    return _listEquals(authors, currentAuthors) &&
        _listEquals(hashtags, currentHashtags) &&
        group == currentGroup &&
        since == currentSince &&
        until == currentUntil &&
        limit == currentLimit &&
        includeReposts == currentIncludeReposts;
  }

  /// Cancel subscription for a specific type
  Future<void> _cancelSubscription(SubscriptionType subscriptionType) async {
    final subscriptionId = _activeSubscriptions[subscriptionType];
    if (subscriptionId != null) {
      Log.info('🛑 Cancelling $subscriptionType subscription: $subscriptionId',
          name: 'VideoEventService', category: LogCategory.video);

      final subscription = _subscriptions[subscriptionId];
      if (subscription != null) {
        try {
          // Cancel the stream subscription - this should trigger onCancel in NostrService
          await subscription.cancel();
          Log.info(
              '✅ Successfully cancelled stream subscription for $subscriptionType',
              name: 'VideoEventService',
              category: LogCategory.video);
        } catch (e) {
          Log.error('❌ Error cancelling stream subscription: $e',
              name: 'VideoEventService', category: LogCategory.video);
        }
        _subscriptions.remove(subscriptionId);
      } else {
        Log.warning('⚠️ No stream subscription found for $subscriptionId',
            name: 'VideoEventService', category: LogCategory.video);
      }

      _activeSubscriptions.remove(subscriptionType);
      _subscriptionParams.remove(subscriptionType);

      // Clear the event list for this subscription type when cancelling
      if (_eventLists.containsKey(subscriptionType)) {
        Log.info(
            '🧹 Clearing ${_eventLists[subscriptionType]?.length ?? 0} events from $subscriptionType list',
            name: 'VideoEventService',
            category: LogCategory.video);
        _eventLists[subscriptionType]?.clear();
      }

      // Clear hashtag and group filters
      _activeHashtagFilters.remove(subscriptionType);
      _activeGroupFilters.remove(subscriptionType);

      // Proceed immediately; rely on relay/stream guarantees instead of sleeps
      Log.info('✅ Finished cancelling $subscriptionType subscription',
          name: 'VideoEventService', category: LogCategory.video);
    } else {
      Log.debug('No active subscription to cancel for $subscriptionType',
          name: 'VideoEventService', category: LogCategory.video);
    }
  }

  /// Helper to compare two lists for equality
  bool _listEquals<T>(List<T>? a, List<T>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Check if subscription type should be maintained persistently
  bool _shouldMaintainSubscription(SubscriptionType subscriptionType) {
    switch (subscriptionType) {
      case SubscriptionType.homeFeed:
      case SubscriptionType.discovery:
        return true; // Main feeds should stay open
      case SubscriptionType.profile:
      case SubscriptionType.hashtag:
        return true; // Profile and hashtag feeds should stay open for real-time updates
      case SubscriptionType.search:
        return false; // Search queries can close after completion
      case SubscriptionType.editorial:
      case SubscriptionType.popularNow:
      case SubscriptionType.trending:
        return false; // Editorial/trending content queries can close
    }
  }

  /// Schedule reconnection attempt for persistent subscriptions
  void _scheduleReconnection(SubscriptionType subscriptionType) {
    // Only reconnect if we still have parameters for this subscription
    final params = _subscriptionParams[subscriptionType];
    if (params == null) return;

    Log.info('🔄 Scheduling reconnection for $subscriptionType subscription',
        name: 'VideoEventService', category: LogCategory.video);

    // Wait 5 seconds before attempting reconnection
    Timer(const Duration(seconds: 5), () {
      if (!isSubscribed(subscriptionType) &&
          _subscriptionParams.containsKey(subscriptionType)) {
        Log.info('🔄 Attempting to reconnect $subscriptionType subscription',
            name: 'VideoEventService', category: LogCategory.video);

        subscribeToVideoFeed(
          subscriptionType: subscriptionType,
          authors: params['authors'] as List<String>?,
          hashtags: params['hashtags'] as List<String>?,
          group: params['group'] as String?,
          since: params['since'] as int?,
          until: params['until'] as int?,
          limit: params['limit'] as int? ?? 50,
          replace: true,
        ).catchError((e) {
          Log.error('Failed to reconnect $subscriptionType subscription: $e',
              name: 'VideoEventService', category: LogCategory.video);
        });
      }
    });
  }

  /// Sort video list using enhanced engagement metrics
  void _sortByEngagement(
      List<VideoEvent> eventList, SubscriptionType subscriptionType) {
    // Don't sort editorial/trending feeds - maintain server order
    if (subscriptionType == SubscriptionType.editorial ||
        subscriptionType == SubscriptionType.popularNow ||
        subscriptionType == SubscriptionType.trending) {
      return;
    }

    // Profile feeds: sort by newest first (reverse chronological)
    if (subscriptionType == SubscriptionType.profile) {
      eventList.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return;
    }

    // Sort using embedded engagement metrics from imported vine data
    // This combines loops, comments, likes, and reposts with weighted scoring
    eventList.sort(VideoEvent.compareByEngagementScore);
  }

  @override
  void dispose() {
    // Flush any remaining batched logs
    LogBatcher.flush();

    _retryTimer?.cancel();
    _authStateSubscription?.cancel();
    _connectionService.dispose();
    unsubscribeFromVideoFeed();
    super.dispose();
  }

  /// Generate deterministic subscription ID based on subscription parameters
  String _generateSubscriptionId({
    required SubscriptionType subscriptionType,
    List<String>? authors,
    List<String>? hashtags,
    String? group,
    int? since,
    int? until,
    int? limit,
    bool includeReposts = false,
  }) {
    // Create a unique string representation of the subscription parameters
    final parts = <String>[
      'type:${subscriptionType.name}',
    ];

    // Add sorted authors to ensure consistent ordering
    if (authors != null && authors.isNotEmpty) {
      final sortedAuthors = List<String>.from(authors)..sort();
      parts.add('authors:${sortedAuthors.join(",")}');
    }

    // Add sorted hashtags to ensure consistent ordering
    if (hashtags != null && hashtags.isNotEmpty) {
      final sortedHashtags = List<String>.from(hashtags)..sort();
      parts.add('hashtags:${sortedHashtags.join(",")}');
    }

    // Add other parameters
    if (group != null) parts.add('group:$group');
    if (since != null) parts.add('since:$since');
    if (until != null) parts.add('until:$until');
    if (limit != null) parts.add('limit:$limit');
    parts.add('reposts:$includeReposts');

    // Create a hash of the combined parameters
    final paramString = parts.join('|');
    var hash = 0;
    for (var i = 0; i < paramString.length; i++) {
      hash = ((hash << 5) - hash) + paramString.codeUnitAt(i);
      hash = hash & 0xFFFFFFFF; // Keep it 32-bit
    }

    // Return subscription ID with type prefix for readability
    final hashStr = hash.abs().toString();
    return '${subscriptionType.name}_$hashStr';
  }

  /// Shuffle regular videos for users not following anyone (preserves classic vines at top)
  void shuffleForDiscovery() {
    final discoveryEvents = _eventLists[SubscriptionType.discovery] ?? [];
    if (!(_isFollowingFeed[SubscriptionType.discovery] ?? false) &&
        discoveryEvents.isNotEmpty) {
      Log.debug('📱 Shuffling videos for discovery mode...',
          name: 'VideoEventService', category: LogCategory.video);

      // Find where classic vines end (they should stay at top)
      var classicVineCount = 0;
      for (var i = 0; i < discoveryEvents.length; i++) {
        if (discoveryEvents[i].pubkey == AppConstants.classicVinesPubkey) {
          classicVineCount = i + 1;
        } else {
          break;
        }
      }

      // Extract regular videos (everything after classic vines)
      if (classicVineCount < discoveryEvents.length) {
        final regularVideos = discoveryEvents.sublist(classicVineCount);

        // Shuffle them
        regularVideos.shuffle();

        // Remove old regular videos
        discoveryEvents.removeRange(classicVineCount, discoveryEvents.length);

        // Add shuffled videos back
        discoveryEvents.addAll(regularVideos);

        Log.info('Shuffled ${regularVideos.length} videos for discovery',
            name: 'VideoEventService', category: LogCategory.video);
      }
    }
  }

  /// Add a video event to the cache (for external services like CurationService)
  void addVideoEvent(VideoEvent videoEvent) {
    _addVideoToSubscription(videoEvent, SubscriptionType.discovery,
        isHistorical: false);
  }

  // NIP-50 Search Methods

  /// Search for videos using NIP-50 search capability
  Future<void> searchVideos(
    String query, {
    List<String>? authors,
    DateTime? since,
    DateTime? until,
    int? limit,
  }) async {
    if (query.trim().isEmpty) {
      throw ArgumentError('Search query cannot be empty');
    }

    // _isSearching = true;
    // _currentSearchQuery = query.trim();
    _eventLists[SubscriptionType.search]?.clear();

    try {
      Log.info('🔍 Starting video search for: "$query"',
          name: 'VideoEventService', category: LogCategory.video);

      // Use the NostrService searchVideos method
      final searchStream = _nostrService.searchVideos(
        query,
        authors: authors,
        since: since,
        until: until,
        limit: limit ?? 50,
      );

      // Subscribe to search results
      final subscription = searchStream.listen(
        (event) {
          Log.debug('🔍 Received search event: ${event.id} kind=${event.kind}',
              name: 'VideoEventService', category: LogCategory.video);

          // Parse video event (filter guarantees video kinds + reposts only)
          final videoEvent = VideoEvent.fromNostrEvent(event);
          if (_hasValidVideoUrl(videoEvent)) {
            _eventLists[SubscriptionType.search]?.add(videoEvent);
            _totalEventsReceived++;
            _firstEventTime ??= DateTime.now();
            _scheduleFrameUpdate(); // Progressive loading for search results
            Log.debug('✅ Added valid search result: ${videoEvent.id}',
                name: 'VideoEventService', category: LogCategory.video);
          } else {
            Log.debug(
                '❌ Rejected search result (invalid URL): ${videoEvent.id} url=${videoEvent.videoUrl}',
                name: 'VideoEventService',
                category: LogCategory.video);
          }
        },
        onError: (error) {
          Log.error('Search error: $error',
              name: 'VideoEventService', category: LogCategory.video);
          // Search subscriptions can fail without affecting main feeds
        },
        onDone: () {
          // Search completed naturally - this is expected behavior
          Log.info(
              'Search completed. Found ${_eventLists[SubscriptionType.search]?.length ?? 0} results',
              name: 'VideoEventService',
              category: LogCategory.video);
          // Search subscription clean up - remove from tracking
          _subscriptions.remove('search');
        },
      );

      // Store subscription for cleanup
      _subscriptions['search'] = subscription;
    } catch (e) {
      // _isSearching = false;
      Log.error('Failed to start search: $e',
          name: 'VideoEventService', category: LogCategory.video);
      rethrow;
    }
  }

  /// Search for videos by hashtag
  Future<void> searchVideosByHashtag(String hashtag) async {
    final cleanHashtag =
        hashtag.startsWith('#') ? hashtag.substring(1) : hashtag;
    return searchVideos('#$cleanHashtag');
  }

  /// Search for videos with additional filters
  Future<void> searchVideosWithFilters({
    required String query,
    List<String>? authors,
    DateTime? since,
    DateTime? until,
    int? limit,
  }) async {
    return searchVideos(
      query,
      authors: authors,
      since: since,
      until: until,
      limit: limit,
    );
  }

  /// Clear search results and reset search state
  void clearSearchResults() {
    _eventLists[SubscriptionType.search]?.clear();
    // _currentSearchQuery = null;
    // _isSearching = false;

    // Cancel search subscription if active
    _subscriptions['search']?.cancel();
    _subscriptions.remove('search');

    Log.debug('Search results cleared',
        name: 'VideoEventService', category: LogCategory.video);
  }

  /// Process search results from events
  List<VideoEvent> processSearchResults(List<Event> events) {
    final results = <VideoEvent>[];

    for (final event in events) {
      final videoEvent = VideoEvent.fromNostrEvent(event);
      if (_hasValidVideoUrl(videoEvent)) {
        results.add(videoEvent);
      }
    }

    return deduplicateSearchResults(results);
  }

  /// Remove duplicate search results based on video URL and event ID
  List<VideoEvent> deduplicateSearchResults(List<VideoEvent> results) {
    final seen = <String>{};
    final deduplicated = <VideoEvent>[];

    for (final result in results) {
      final key = '${result.videoUrl}:${result.id}';
      if (!seen.contains(key)) {
        seen.add(key);
        deduplicated.add(result);
      }
    }

    Log.debug(
        'Deduplicated ${results.length} results to ${deduplicated.length}',
        name: 'VideoEventService',
        category: LogCategory.video);

    return deduplicated;
  }

  /// Search videos within a specific time range
  Future<void> searchVideosWithTimeRange({
    required String query,
    required DateTime since,
    required DateTime until,
    List<String>? authors,
    int? limit,
  }) async {
    return searchVideos(
      query,
      authors: authors,
      since: since,
      until: until,
      limit: limit,
    );
  }

  /// Search videos with NIP-50 extensions support
  Future<void> searchVideosWithExtensions(String queryWithExtensions) async {
    return searchVideos(queryWithExtensions);
  }

  /// Validate that a video event has a valid, accessible URL
  bool _hasValidVideoUrl(VideoEvent videoEvent) {
    final videoUrl = videoEvent.videoUrl;

    // Must have a video URL
    if (videoUrl == null || videoUrl.isEmpty) {
      return false;
    }

    // Must be a valid HTTP/HTTPS URL
    try {
      final uri = Uri.parse(videoUrl);
      if (!['http', 'https'].contains(uri.scheme.toLowerCase())) {
        return false;
      }

      // Must have a valid host
      if (uri.host.isEmpty) {
        return false;
      }

      // Reject known broken domains
      if (videoUrl.contains('apt.openvine.co')) {
        Log.debug('Rejecting broken apt.openvine.co URL: $videoUrl',
            name: 'VideoEventService', category: LogCategory.video);
        return false;
      }

      return true;
    } catch (e) {
      Log.debug('Invalid video URL format: $videoUrl - $e',
          name: 'VideoEventService', category: LogCategory.video);
      return false;
    }
  }

  // TEST-ONLY METHODS - Do not use in production code

  /// Get pagination states for testing purposes only
  Map<SubscriptionType, PaginationState> getPaginationStatesForTesting() {
    return Map.unmodifiable(_paginationStates);
  }

  /// Add video event with historical flag for testing purposes only
  void addVideoEventForTesting(VideoEvent event, SubscriptionType type,
      {required bool isHistorical}) {
    _addVideoToSubscription(event, type, isHistorical: isHistorical);
  }

  /// Inject multiple test videos into discovery feed for testing
  void injectTestVideos(List<VideoEvent> videos) {
    for (final video in videos) {
      addVideoEventForTesting(video, SubscriptionType.discovery, isHistorical: true);
    }
    notifyListeners(); // Notify providers that videos have changed
  }

  /// Handle a nostr event for testing (exposes _handleNewVideoEvent)
  @visibleForTesting
  void handleEventForTesting(Event event, SubscriptionType type) {
    _handleNewVideoEvent(event, type);
  }

  /// Run automatic diagnostics when feed fails to load events
  /// This logs relay status, connection info, and tests direct queries to help debug
  Future<void> _runAutoDiagnostics(
      SubscriptionType subscriptionType, List<Filter> filters) async {
    Log.warning(
        '🔍 Running automatic diagnostics for empty $subscriptionType feed...',
        name: 'VideoEventService',
        category: LogCategory.video);

    try {
      // 1. Check relay connection status
      final relays = _nostrService.relays;
      final connectedRelays = _nostrService.connectedRelays;
      final connectedCount = _nostrService.connectedRelayCount;

      Log.warning('📊 Relay Status:',
          name: 'VideoEventService', category: LogCategory.video);
      Log.warning('   - Configured relays: ${relays.join(", ")}',
          name: 'VideoEventService', category: LogCategory.video);
      Log.warning(
          '   - Connected relays: ${connectedRelays.join(", ")} ($connectedCount/${relays.length})',
          name: 'VideoEventService',
          category: LogCategory.video);

      if (connectedCount == 0) {
        Log.error(
            '❌ DIAGNOSTIC: No relays connected! This is why feed is empty.',
            name: 'VideoEventService',
            category: LogCategory.video);
        return;
      }

      // 2. Log the subscription filters being used
      Log.warning('📋 Subscription Filters:',
          name: 'VideoEventService', category: LogCategory.video);
      for (var i = 0; i < filters.length; i++) {
        final filter = filters[i];
        Log.warning('   Filter $i:',
            name: 'VideoEventService', category: LogCategory.video);
        Log.warning('      - kinds: ${filter.kinds}',
            name: 'VideoEventService', category: LogCategory.video);
        Log.warning('      - authors: ${filter.authors?.length ?? 0} authors',
            name: 'VideoEventService', category: LogCategory.video);

        if (filter.authors != null && filter.authors!.isEmpty) {
          Log.error(
              '❌ DIAGNOSTIC: Authors list is EMPTY! This will return 0 events for homeFeed.',
              name: 'VideoEventService',
              category: LogCategory.video);
        }

        if (filter.limit != null) {
          Log.warning('      - limit: ${filter.limit}',
              name: 'VideoEventService', category: LogCategory.video);
        }
        if (filter.since != null) {
          Log.warning('      - since: ${filter.since}',
              name: 'VideoEventService', category: LogCategory.video);
        }
        if (filter.until != null) {
          Log.warning('      - until: ${filter.until}',
              name: 'VideoEventService', category: LogCategory.video);
        }
      }

      // 3. Test direct query to see if events exist in database
      Log.warning('🔍 Testing direct database query (bypassing subscription)...',
          name: 'VideoEventService', category: LogCategory.video);

      final directQueryEvents = await _nostrService.getEvents(
        filters: [Filter(kinds: [34236, 34235, 22, 21], limit: 100)],
        limit: 100,
      );

      Log.warning(
          '✅ Direct query returned ${directQueryEvents.length} video events',
          name: 'VideoEventService',
          category: LogCategory.video);

      if (directQueryEvents.isEmpty) {
        Log.error(
            '❌ DIAGNOSTIC: Embedded relay database has NO video events!',
            name: 'VideoEventService',
            category: LogCategory.video);
        Log.error(
            '   This means external relay → embedded relay sync is not working.',
            name: 'VideoEventService',
            category: LogCategory.video);
      } else {
        Log.warning(
            '✅ DIAGNOSTIC: Database HAS ${directQueryEvents.length} events, but subscription returned 0.',
            name: 'VideoEventService',
            category: LogCategory.video);
        Log.error(
            '❌ This means subscription filtering is too restrictive OR subscription stream is broken.',
            name: 'VideoEventService',
            category: LogCategory.video);

        // Log sample events to help compare with subscription filters
        Log.warning('📄 Sample events in database:',
            name: 'VideoEventService', category: LogCategory.video);
        for (var i = 0; i < directQueryEvents.length && i < 3; i++) {
          final event = directQueryEvents[i];
          Log.warning('   Event $i:',
              name: 'VideoEventService', category: LogCategory.video);
          Log.warning('      - id: ${event.id}',
              name: 'VideoEventService', category: LogCategory.video);
          Log.warning('      - kind: ${event.kind}',
              name: 'VideoEventService', category: LogCategory.video);
          Log.warning('      - pubkey: ${event.pubkey}',
              name: 'VideoEventService', category: LogCategory.video);
          Log.warning(
              '      - createdAt: ${DateTime.fromMillisecondsSinceEpoch(event.createdAt * 1000)}',
              name: 'VideoEventService',
              category: LogCategory.video);
        }
      }

      // 4. Get relay stats for additional diagnostics
      final relayStats = await _nostrService.getRelayStats();
      if (relayStats != null) {
        Log.warning('📊 Relay Database Stats:',
            name: 'VideoEventService', category: LogCategory.video);
        Log.warning('   ${relayStats.toString()}',
            name: 'VideoEventService', category: LogCategory.video);
      }
    } catch (e, stackTrace) {
      Log.error('❌ Auto-diagnostics failed: $e',
          name: 'VideoEventService', category: LogCategory.video);
      Log.verbose('Stack trace: $stackTrace',
          name: 'VideoEventService', category: LogCategory.video);
    }
  }

}

/// Exception thrown by video event service operations
/// REFACTORED: Removed ChangeNotifier - now uses pure state management via Riverpod
class VideoEventServiceException implements Exception {
  const VideoEventServiceException(this.message);
  final String message;

  @override
  String toString() => 'VideoEventServiceException: $message';
}
