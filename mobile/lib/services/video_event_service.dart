// ABOUTME: Service for subscribing to and managing video events (NIP-71 kinds 22, 34236)
// ABOUTME: Handles real-time feed updates and local caching of video content

/// VideoEventService - Central service for video event management
///
/// RESPONSIBILITIES (9 distinct concerns):
/// 1. Subscription Management - Creating/cancelling subscriptions for 8 feed types
/// 2. Event Reception & Routing - Real-time event streaming from Nostr relay
/// 3. Event Processing - Converting Nostr events to VideoEvent objects
/// 4. Filtering - Blocklist, hashtags, groups, URL validation
/// 5. Caching - Managing 8 separate event lists per subscription type
/// 6. Pagination - Historical data loading, cursor tracking
/// 7. Sorting - Engagement-based, chronological, special handling
/// 8. Retry & Recovery - Connection error detection, automatic retry
/// 9. Search - NIP-50 video search implementation
// TODO(#4742): Split this god-file into focused services; it violates the
// Single Responsibility Principle.
library;

import 'dart:async';

import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:likes_repository/likes_repository.dart';
import 'package:models/models.dart' hide LogCategory, NIP71VideoKinds;
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/aid.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:nostr_sdk/nip19/pubkey_for_logs.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/constants/nip71_migration.dart';
import 'package:openvine/observability/crash_reporter.dart';
import 'package:openvine/services/author_video_buckets.dart';
import 'package:openvine/services/broken_video_tracker.dart';
import 'package:openvine/services/connection_status_service.dart';
import 'package:openvine/services/content_filter_service.dart';
import 'package:openvine/services/divine_host_filter_service.dart';
import 'package:openvine/services/effective_content_labels.dart';
import 'package:openvine/services/event_router.dart';
import 'package:openvine/services/feed_aspect_ratio_preference_service.dart';
import 'package:openvine/services/feed_load_trace.dart';
import 'package:openvine/services/feed_retry_scheduler.dart';
import 'package:openvine/services/moderation_label_service.dart';
import 'package:openvine/services/performance_monitoring_service.dart';
import 'package:openvine/services/repost_resolver.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/services/video_block_policy.dart';
import 'package:openvine/services/video_filter_builder.dart';
import 'package:openvine/services/video_provenance_filter_service.dart';
import 'package:openvine/services/video_source_visibility_policy.dart';
import 'package:openvine/utils/log_tag_sanitizer.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:video_event_cache/video_event_cache.dart';

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
    // Normalize ID to lowercase for case-insensitive deduplication
    seenEventIds.add(eventId.toLowerCase());
  }

  void startQuery() {
    eventsReceivedInCurrentQuery = 0;
    hasMore = true;
    isLoading = true;
  }

  void incrementEventCount() {
    eventsReceivedInCurrentQuery++;
  }

  /// Records a per-query tally the caller counted for itself.
  ///
  /// [incrementEventCount] only fires for events flagged `isHistorical`, which
  /// is set on the load-more path alone. An initial subscription delivers its
  /// stored backlog through the real-time handler, so its tally stays at zero
  /// and [completeQuery] would call the feed exhausted however much arrived.
  ///
  /// Takes the larger of the two counts so an externally observed tally seeds
  /// missing events without erasing events already counted on this query.
  void recordReceivedCount(int count) {
    if (count > eventsReceivedInCurrentQuery) {
      eventsReceivedInCurrentQuery = count;
    }
  }

  void completeQuery(int requestedLimit) {
    isLoading = false;
    // If we received fewer events than requested, assume no more content
    if (eventsReceivedInCurrentQuery < requestedLimit) {
      hasMore = false;
      Log.info(
        'PaginationState: No more content available - received $eventsReceivedInCurrentQuery < $requestedLimit requested',
        name: 'VideoEventService',
        category: LogCategory.video,
      );
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
class VideoEventService extends ChangeNotifier implements VideoEventCache {
  VideoEventService(
    this._nostrService, {
    required SubscriptionManager subscriptionManager,
    required CrashReporter crashReporter,
    ProfileRepository? profileRepository,
    EventRouter? eventRouter,
    VideoFilterBuilder? videoFilterBuilder,
    PerformanceTraceMonitor? performanceMonitor,
    ConnectionStatusService? connectionService,
  }) : _subscriptionManager = subscriptionManager,
       _crashReporter = crashReporter,
       _profileRepository = profileRepository,
       _eventRouter = eventRouter,
       _videoFilterBuilder = videoFilterBuilder,
       _connectionService = connectionService ?? ConnectionStatusService(),
       _ownsConnectionService = connectionService == null,
       _performanceMonitor =
           performanceMonitor ?? const NoOpPerformanceTraceMonitor() {
    _initializePaginationStates();
    _initializeRepostResolver();
  }
  final NostrClient _nostrService;
  late final RepostResolver _repostResolver;
  final ProfileRepository? _profileRepository;
  final EventRouter? _eventRouter;

  /// The ingestion router backing this service, if one was injected.
  ///
  /// Exposed so app-level memory instrumentation can read its queue depth and
  /// shed low-priority backlog under memory pressure.
  EventRouter? get eventRouter => _eventRouter;

  final VideoFilterBuilder? _videoFilterBuilder;
  final PerformanceTraceMonitor _performanceMonitor;
  final ConnectionStatusService _connectionService;
  final bool _ownsConnectionService;

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
  final AuthorVideoBuckets _authorBuckets = AuthorVideoBuckets();

  // Track active subscriptions per type
  final Map<SubscriptionType, String> _activeSubscriptions = {};
  final Map<String, StreamSubscription> _subscriptions = {};

  // Ids claimed by an in-flight subscribeToVideoFeed call — guards the
  // async gap between the duplicate-id check and registration in
  // [_subscriptions], so concurrent identical subscribes can't both
  // issue a relay REQ.
  final Set<String> _pendingSubscriptionIds = {};
  final List<String> _activeSubscriptionIds = [];

  // Global state
  bool _isLoading = false;
  String? _error;
  StreamSubscription<Map<String, RelayConnectionStatus>>?
  _relayReadyRetrySubscription;

  // Feed types whose relay subscription failed because no relay was usable
  // yet, and should be re-established once one is.
  final Set<SubscriptionType> _typesAwaitingRelayReady = {};

  late final FeedRetryScheduler _retryScheduler = FeedRetryScheduler(
    connectionService: _connectionService,
    resubscribe: _resubscribeWithStoredParams,
    onRelayNotReady: _scheduleRetryWhenRelayReady,
  );

  /// Per-type 30s feed-load fuses. Cancelled on replace/teardown so a
  /// subscription the user already left cannot fire recovery against a later
  /// live feed of the same type.
  final Map<SubscriptionType, Timer> _feedLoadTimeouts = {};

  /// Feed-load traces that have started but not yet reported, keyed by the
  /// subscription id the load belongs to. Closed when that subscription is
  /// torn down, and drained by [dispose] for loads still mid-setup.
  final Map<String, FeedLoadTrace> _pendingFeedLoadTraces = {};

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

  // Track following feed status
  final Map<SubscriptionType, bool> _isFollowingFeed = {};
  final Map<SubscriptionType, bool> _includeReposts = {};

  // Track known deleted videos to prevent resurrection from pagination.
  // Includes local user deletions and observed remote NIP-09 deletes.
  final Set<String> _knownDeletedVideoIds = {};

  /// `pubkey:stable-id` coordinate to the `created_at` of the deletion that
  /// removed it.
  ///
  /// NIP-09 scopes an `a` deletion to versions up to the deletion request's
  /// own timestamp, so a version the author republishes afterwards is not
  /// covered and must stay visible.
  final Map<String, int> _knownDeletedVideoCoordinates = {};

  // Broadcasts video ids the moment they are removed (deletion / future
  // block / mute). Subscribers — fullscreen feed bloc, profile feed
  // provider — react in real time without waiting for a route change.
  // Broadcast semantics are intentional: state.notifyListeners is the
  // canonical truth, this stream is a side-channel for "act now" hooks.
  final StreamController<String> _removedVideoIdsController =
      StreamController<String>.broadcast();

  static const int _eventDeletionKind = 5;

  // Optional services for enhanced functionality
  ContentBlocklistRepository? _blocklistRepository;
  StreamSubscription<BlocklistChange>? _blocklistChangesSubscription;
  LikesRepository? _likesRepository;
  ContentFilterService? _contentFilterService;
  ModerationLabelService? _moderationLabelService;
  DivineHostFilterService? _divineHostFilterService;
  VideoProvenanceFilterService? _provenanceFilterService;
  FeedAspectRatioPreferenceService? _feedAspectRatioPreferenceService;
  BrokenVideoTracker? _brokenVideoTracker;
  late String? Function() _currentUserPubkey = () => _nostrService.publicKey;
  final SubscriptionManager _subscriptionManager;

  final CrashReporter _crashReporter;

  /// Supplies the authenticated pubkey independently of signer readiness.
  void setCurrentUserPubkeyProvider(String? Function() provider) {
    _currentUserPubkey = provider;
  }

  // Side-channel observers that fire for every video that flows through the
  // service after filtering — both REST-loaded batches via [filterVideoList]
  // and WebSocket-driven additions via [_addVideoToSubscription], including
  // historical (paginated) ones.
  // Composition-root concerns (e.g. badge caches) wire themselves here
  // without coupling this service to any specific consumer.
  final List<void Function(Iterable<VideoEvent> videos)> _videoObservers = [];

  // Like count batching - accumulates video IDs and fetches counts in batches
  // to prevent ANR issues from too many concurrent relay requests
  final Map<String, SubscriptionType> _pendingLikeCountVideoIds = {};
  // Companion map for _pendingLikeCountVideoIds: event ID → addressable ID (kind:pubkey:d-tag).
  final Map<String, String> _pendingLikeCountAddressableIds = {};
  Timer? _likeCountBatchTimer;
  static const Duration _likeCountBatchDebounce = Duration(milliseconds: 150);
  static const int _likeCountBatchMaxSize = 50;

  // AUTH retry mechanism
  StreamSubscription<Map<String, bool>>? _authStateSubscription;

  /// Callback type for video update notifications.
  /// Called when a video's metadata is updated via updateVideoEvent().
  /// [updated] is the new video with updated metadata.
  final List<void Function(VideoEvent updated)> _onVideoUpdatedCallbacks = [];

  /// Register a callback to be notified when a video is updated.
  /// Returns a function that can be called to unregister the callback.
  VoidCallback addVideoUpdateListener(
    void Function(VideoEvent updated) callback,
  ) {
    _onVideoUpdatedCallbacks.add(callback);
    return () => _onVideoUpdatedCallbacks.remove(callback);
  }

  /// Remove a previously registered video update callback.
  void removeVideoUpdateListener(void Function(VideoEvent updated) callback) {
    _onVideoUpdatedCallbacks.remove(callback);
  }

  /// Notify all registered callbacks that a video was updated.
  void _notifyVideoUpdated(VideoEvent updated) {
    for (final callback in _onVideoUpdatedCallbacks) {
      try {
        callback(updated);
      } catch (e) {
        Log.error(
          'Error in video update callback: $e',
          name: 'VideoEventService',
          category: LogCategory.video,
        );
      }
    }
  }

  /// Register an observer that receives every batch of videos flowing
  /// through the service after filtering — both REST-loaded results from
  /// [filterVideoList] and individual WebSocket-driven additions from
  /// [_addVideoToSubscription], regardless of historical/live status.
  ///
  /// Designed for cross-cutting concerns that must learn from any video
  /// surface (e.g. the OG Viner badge cache) without coupling this service
  /// to a specific consumer.
  ///
  /// Returns a disposer that unregisters the observer.
  VoidCallback addVideoObserver(
    void Function(Iterable<VideoEvent> videos) observer,
  ) {
    _videoObservers.add(observer);
    return () => _videoObservers.remove(observer);
  }

  void _notifyVideoObservers(Iterable<VideoEvent> videos) {
    if (_videoObservers.isEmpty) return;
    for (final observer in _videoObservers) {
      try {
        observer(videos);
      } catch (e) {
        Log.error(
          'Error in video observer: $e',
          name: 'VideoEventService',
          category: LogCategory.video,
        );
      }
    }
  }

  /// Set the blocklist service for content filtering
  void setBlocklistRepository(ContentBlocklistRepository blocklistRepository) {
    _blocklistRepository = blocklistRepository;

    // Subscribe to per-pubkey blocklist changes so a block / mute
    // immediately propagates as `removedVideoIds` emissions for every
    // video by the affected author. Mirrors the deletion bus contract:
    // subscribers (FullscreenFeedBloc) drop the ids from their visible
    // state without waiting for a route change or app restart.
    //
    // Cancel any prior subscription if `setBlocklistRepository` is
    // called again — keeps the active subscription bound to the
    // currently-attached repository.
    unawaited(_blocklistChangesSubscription?.cancel());
    _blocklistChangesSubscription = blocklistRepository.changes.listen(
      (change) {
        if (!change.isAddition) return;
        _sweepAuthor(change.pubkey);
      },
      onError: (Object error, StackTrace stackTrace) {
        Log.error(
          'VideoEventService: blocklist changes stream error - $error',
          name: 'VideoEventService',
          category: LogCategory.video,
          error: error,
          stackTrace: stackTrace,
        );
      },
    );

    Log.debug(
      'Blocklist service attached to VideoEventService',
      name: 'VideoEventService',
      category: LogCategory.video,
    );
  }

  /// Emit `removedVideoIds` for every cached video authored by [pubkey].
  ///
  /// Used in response to block / mute events. Unlike
  /// [removeVideoCompletely], this does NOT add ids to
  /// [_knownDeletedVideoIds] — block / mute are reversible and the
  /// existing pagination filters (via [shouldHideVideo] /
  /// [filterVideoList]) already guarantee that an unblocked author's
  /// videos can come back on the next refresh. We only need the
  /// fullscreen surface to drop them right now.
  void _sweepAuthor(String pubkey) {
    if (_removedVideoIdsController.isClosed) return;

    // Collect ids across every cache that may hold this author's videos.
    // Fullscreen blocs may be displaying videos sourced from any of
    // these — discovery, profile, hashtag, etc. Dedupe by id since a
    // video can appear in multiple buckets simultaneously.
    final ids = <String>{};

    for (final video in _authorBuckets.videosForAuthorUnsorted(pubkey)) {
      ids.add(video.id);
    }

    for (final list in _eventLists.values) {
      for (final video in list) {
        if (video.pubkey == pubkey) ids.add(video.id);
      }
    }

    for (final list in _hashtagBuckets.values) {
      for (final video in list) {
        if (video.pubkey == pubkey) ids.add(video.id);
      }
    }

    if (ids.isEmpty) return;

    Log.info(
      'sweepAuthor: emitting ${ids.length} removal(s) for pubkey=${pubkeyForLogs(pubkey)}',
      name: 'VideoEventService',
      category: LogCategory.video,
    );

    ids.forEach(_removedVideoIdsController.add);
  }

  /// Test-only seam: pre-populate the author bucket so [_sweepAuthor]
  /// can be exercised without driving a real relay subscription.
  /// Production code must never call this — use the public subscription
  /// APIs instead.
  @visibleForTesting
  void debugSeedAuthorBucket(String pubkey, List<VideoEvent> videos) {
    _authorBuckets.seed(pubkey, videos);
  }

  /// Set the likes repository for fetching live like counts
  void setLikesRepository(LikesRepository likesRepository) {
    _likesRepository = likesRepository;
    Log.debug(
      'Likes repository attached to VideoEventService',
      name: 'VideoEventService',
      category: LogCategory.video,
    );
  }

  /// Set the content filter service for per-category Show/Warn/Hide filtering
  void setContentFilterService(ContentFilterService contentFilterService) {
    _contentFilterService = contentFilterService;
    Log.debug(
      'Content filter service attached to VideoEventService',
      name: 'VideoEventService',
      category: LogCategory.video,
    );
  }

  /// Set the trusted moderation label service for kind-1985 label lookups.
  void setModerationLabelService(
    ModerationLabelService moderationLabelService,
  ) {
    _moderationLabelService = moderationLabelService;
    Log.debug(
      'Moderation label service attached to VideoEventService',
      name: 'VideoEventService',
      category: LogCategory.video,
    );
  }

  /// Set the Divine-hosted-only filter service.
  void setDivineHostFilterService(DivineHostFilterService service) {
    _divineHostFilterService = service;
    Log.debug(
      'Divine host filter service attached to VideoEventService',
      name: 'VideoEventService',
      category: LogCategory.video,
    );
  }

  /// Set the capture-verified-only filter service.
  void setProvenanceFilterService(VideoProvenanceFilterService service) {
    _provenanceFilterService = service;
  }

  /// Set the feed aspect-ratio preference service.
  void setFeedAspectRatioPreferenceService(
    FeedAspectRatioPreferenceService service,
  ) {
    _feedAspectRatioPreferenceService = service;
    Log.debug(
      'Feed aspect-ratio preference service attached to VideoEventService',
      name: 'VideoEventService',
      category: LogCategory.video,
    );
  }

  /// Set the broken-video tracker used to filter videos confirmed unavailable.
  /// Marked entries are persisted by the tracker, so this keeps unavailable
  /// videos out of every list surface (home, profile, hashtag, grids) across
  /// app restarts. See #5237 / #6251.
  void setBrokenVideoTracker(BrokenVideoTracker tracker) {
    _brokenVideoTracker = tracker;
    Log.debug(
      'Broken video tracker attached to VideoEventService',
      name: 'VideoEventService',
      category: LogCategory.video,
    );
  }

  bool get shouldFilterNonDivineVideos =>
      _divineHostFilterService?.showDivineHostedOnly ?? false;

  bool get _shouldFilterUnverifiedVideos =>
      _provenanceFilterService?.showVerifiedOnly ?? false;

  /// Returns true when shared feed policy hides this video.
  bool shouldHideVideo(VideoEvent video) {
    if (VideoBlockPolicy.isHiddenByBlocklist(video, _blocklistRepository)) {
      return true;
    }
    if (VideoSourceVisibilityPolicy.isHiddenBySourcePreferences(
      video,
      divineHostedOnly: shouldFilterNonDivineVideos,
      verifiedOnly: _shouldFilterUnverifiedVideos,
    )) {
      return true;
    }
    return false;
  }

  bool _shouldHideForFeedShapePreference(VideoEvent video) =>
      _feedAspectRatioPreferenceService?.shouldHideVideo(video) ?? false;

  /// Returns true if adult content should be filtered from feeds
  bool get shouldFilterAdultContent =>
      _contentFilterService?.adultPlaybackPreference ==
      ContentFilterPreference.hide;

  /// Check if an event should be filtered based on adult content settings
  /// Returns true if the event should be filtered OUT (not shown)
  bool shouldFilterEvent(Event event) {
    // If not hiding adult content, don't filter anything
    if (!shouldFilterAdultContent) {
      return false;
    }

    // Check for content-warning tag (indicates adult/sensitive content)
    for (final tag in event.tags) {
      if (tag.isNotEmpty && tag[0] == 'content-warning') {
        Log.debug(
          'Filtering event with content-warning tag',
          name: 'VideoEventService',
          category: LogCategory.video,
        );
        return true;
      }
    }

    // Check for NSFW or adult hashtags
    for (final tag in event.tags) {
      if (tag.length >= 2 && tag[0] == 't') {
        final hashtag = tag[1].toLowerCase();
        if (hashtag == 'nsfw' || hashtag == 'adult') {
          Log.debug(
            'Filtering event with NSFW/adult hashtag',
            name: 'VideoEventService',
            category: LogCategory.video,
          );
          return true;
        }
      }
    }

    // Check for NIP-32 content-warning namespace tag ['L', 'content-warning']
    for (final tag in event.tags) {
      if (tag.length >= 2 && tag[0] == 'L' && tag[1] == 'content-warning') {
        Log.debug(
          'Filtering event with NIP-32 content-warning label',
          name: 'VideoEventService',
          category: LogCategory.video,
        );
        return true;
      }
    }

    return false;
  }

  /// Determine the filter action for an event based on per-category preferences.
  ///
  /// Returns:
  /// - [ContentFilterPreference.hide] → filter from feed entirely
  /// - [ContentFilterPreference.warn] → keep in feed but show blur overlay
  /// - [ContentFilterPreference.show] → display normally
  ///
  /// Also returns the list of matched label values that triggered the action.
  (ContentFilterPreference, List<String>) getFilterAction(Event event) {
    final contentFilterService = _contentFilterService;
    if (contentFilterService == null) {
      // Fall back to legacy binary filtering
      if (shouldFilterEvent(event)) {
        return (ContentFilterPreference.hide, <String>[]);
      }
      return (ContentFilterPreference.show, <String>[]);
    }

    // Collect all content warning label values from the event
    final labels = <String>[];

    // Check content-warning tags (NIP-36)
    for (final tag in event.tags) {
      if (tag.isNotEmpty && tag[0] == 'content-warning' && tag.length >= 2) {
        final value = tag[1];
        if (value.isNotEmpty && !labels.contains(value)) {
          labels.add(value);
        }
      }
    }

    // Check NIP-32 label tags with content-warning namespace
    for (final tag in event.tags) {
      if (tag.length >= 3 && tag[0] == 'l' && tag[2] == 'content-warning') {
        final value = tag[1];
        if (value.isNotEmpty && !labels.contains(value)) {
          labels.add(value);
        }
      }
    }

    // Check NSFW/adult hashtags — map to nudity category
    for (final tag in event.tags) {
      if (tag.length >= 2 && tag[0] == 't') {
        final hashtag = tag[1].toLowerCase();
        if (hashtag == 'nsfw' || hashtag == 'adult') {
          if (!labels.contains('nudity')) {
            labels.add('nudity');
          }
        }
      }
    }

    if (labels.isEmpty) {
      return (ContentFilterPreference.show, <String>[]);
    }

    final decision = resolveEffectiveContentFilterDecision(
      sources: (creator: labels, trusted: const <String>[]),
      moderationLabels: const <String>[],
      contentFilterService: contentFilterService,
      isOwner: contentOwnerMatches(event.pubkey, _currentUserPubkey()),
    );
    return (
      decision.preference,
      decision.preference == ContentFilterPreference.warn
          ? decision.warnLabels
          : labels,
    );
  }

  /// Filter a list of [VideoEvent]s based on the user's content filter
  /// preferences. Videos matching "hide" labels are removed from the list.
  /// Videos matching "warn" labels are kept (the UI shows an overlay).
  ///
  /// [contentWarningLabels] (author self-labels from NIP-32/NIP-36) trigger
  /// both "hide" and "warn" behaviour.
  ///
  /// [moderationLabels] (ML-generated from Funnelcake) only trigger "hide"
  /// filtering — never "warn" blur overlays — because ML classifiers are
  /// noisy and would otherwise block autoplay on ordinary videos.
  List<VideoEvent> filterVideoList(List<VideoEvent> videos) {
    final service = _contentFilterService;
    final tracker = _brokenVideoTracker;
    final baseVideos = videos
        .where(
          (video) =>
              !shouldHideVideo(video) &&
              !_shouldHideForFeedShapePreference(video) &&
              !(tracker?.isVideoBroken(video.id) ?? false),
        )
        .toList();
    if (service == null) {
      _notifyVideoObservers(baseVideos);
      return baseVideos;
    }

    final result = <VideoEvent>[];
    for (final video in baseVideos) {
      final sources = resolveEffectiveContentLabelSources(
        video,
        moderationLabelService: _moderationLabelService,
      );
      final decision = resolveEffectiveContentFilterDecision(
        sources: sources,
        moderationLabels: video.moderationLabels,
        contentFilterService: service,
        isOwner: contentOwnerMatches(video.pubkey, _currentUserPubkey()),
      );
      if (decision.preference == ContentFilterPreference.hide) continue;
      result.add(
        _listEquals(video.warnLabels, decision.warnLabels)
            ? video
            : video.copyWith(warnLabels: decision.warnLabels),
      );
    }

    _notifyVideoObservers(result);
    return result;
  }

  /// Check if a VideoEvent contains adult content based on hashtags and tags
  bool _isAdultContent(VideoEvent video) {
    // Check for NSFW or adult hashtags
    for (final hashtag in video.hashtags) {
      final lowerHashtag = hashtag.toLowerCase();
      if (lowerHashtag == 'nsfw' || lowerHashtag == 'adult') {
        return true;
      }
    }

    // Check for content-warning in rawTags
    if (video.rawTags.containsKey('content-warning')) {
      return true;
    }

    // Check for NIP-32 content-warning namespace tag
    if (video.rawTags['L'] == 'content-warning') {
      return true;
    }

    // Check isFlaggedContent flag
    if (video.isFlaggedContent) {
      return true;
    }

    return false;
  }

  /// Filter adult content from all existing video lists
  /// Call this when user changes preference to "Never show"
  /// Returns the count of removed videos
  int filterAdultContentFromExistingVideos() {
    // If not hiding adult content, don't filter anything
    if (!shouldFilterAdultContent) {
      return 0;
    }

    int totalRemoved = 0;

    // Iterate through all subscription types and filter each list
    for (final subscriptionType in SubscriptionType.values) {
      final eventList = _eventLists[subscriptionType];
      if (eventList == null || eventList.isEmpty) continue;

      final beforeCount = eventList.length;
      eventList.removeWhere(_isAdultContent);
      final removedFromList = beforeCount - eventList.length;

      if (removedFromList > 0) {
        Log.info(
          'Filtered $removedFromList adult content videos from ${subscriptionType.name}',
          name: 'VideoEventService',
          category: LogCategory.video,
        );
        totalRemoved += removedFromList;
      }
    }

    if (totalRemoved > 0) {
      Log.info(
        'Total adult content videos filtered: $totalRemoved',
        name: 'VideoEventService',
        category: LogCategory.video,
      );
      notifyListeners();
    }

    return totalRemoved;
  }

  /// Initialize pagination states for all subscription types
  void _initializePaginationStates() {
    for (final subscriptionType in SubscriptionType.values) {
      _paginationStates[subscriptionType] = PaginationState();
    }
  }

  /// Initialize the repost resolver with callbacks to this service
  void _initializeRepostResolver() {
    _repostResolver = RepostResolver(
      subscribe: _nostrService.subscribe,
      findByAddressable: _findCachedVideoByAddressable,
      findById: _findCachedVideoById,
    );
  }

  /// Find cached video by event ID across all subscription lists
  /// Uses case-insensitive matching for consistency with normalized IDs
  VideoEvent? _findCachedVideoById(String eventId) {
    final normalizedId = eventId.toLowerCase();
    for (final events in _eventLists.values) {
      final match = events
          .where((v) => v.id.toLowerCase() == normalizedId)
          .firstOrNull;
      if (match != null) return match;
    }
    return null;
  }

  /// Schedule a frame-based UI update to batch multiple event additions
  /// This ensures notifyListeners() is called at most once per frame (~16ms at 60fps)
  void _scheduleFrameUpdate() {
    if (_hasScheduledFrameUpdate) return;
    _hasScheduledFrameUpdate = true;

    // Use Future.microtask instead of WidgetsBinding.addPostFrameCallback
    // This is more reliable on web and avoids "disposed view" errors
    Future.microtask(() {
      if (!_hasScheduledFrameUpdate) return; // Already processed
      _hasScheduledFrameUpdate = false;
      // A load can be abandoned between scheduling and this microtask —
      // notifying then throws "used after being disposed".
      if (_isDisposed) return;
      notifyListeners();
    });
  }

  /// Get videos for a specific subscription type
  List<VideoEvent> getVideos(SubscriptionType type) {
    return List.unmodifiable(_eventLists[type] ?? []);
  }

  /// Get home feed videos (from people you follow)
  List<VideoEvent> get homeFeedVideos => getVideos(SubscriptionType.homeFeed);

  /// Get discovery videos (all videos for exploration)
  @override
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
  List<VideoEvent> hashtagVideos(String tag) =>
      _hashtagBuckets[tag] ?? const [];

  /// DEBUG: Dump all events with cdn.divine.video thumbnails
  void debugDumpCdnDivineVideoThumbnails() {
    // Log.warning('🔍 DEBUG: Searching all loaded events for cdn.divine.video thumbnails...',
    //     name: 'VideoEventService', category: LogCategory.video);

    int count = 0;
    for (final entry in _eventLists.entries) {
      for (final video in entry.value) {
        if (video.thumbnailUrl?.contains('cdn.divine.video') == true) {
          count++;
          // Log.warning('🔍 FOUND #$count:', name: 'VideoEventService', category: LogCategory.video);
          // Log.warning('  Event ID: ${video.id}', name: 'VideoEventService', category: LogCategory.video);
          // Log.warning('  Video URL: ${video.videoUrl}', name: 'VideoEventService', category: LogCategory.video);
          // Log.warning('  Thumbnail: ${video.thumbnailUrl}', name: 'VideoEventService', category: LogCategory.video);
          // Log.warning('  Subscription Type: ${entry.key}', name: 'VideoEventService', category: LogCategory.video);
        }
      }
    }

    Log.warning(
      '🔍 DEBUG: Found $count events with cdn.divine.video thumbnails',
      name: 'VideoEventService',
      category: LogCategory.video,
    );
  }

  /// Get videos for a specific author (keyed for route-aware feeds)
  /// Always returns videos sorted in reverse chronological order (newest first)
  List<VideoEvent> authorVideos(String pubkeyHex) =>
      _authorBuckets.videosFor(pubkeyHex);

  /// Get search results
  List<VideoEvent> get searchResults => getVideos(SubscriptionType.search);

  /// DEPRECATED: Use specific getters instead
  @Deprecated(
    'Use getVideos(SubscriptionType.discovery) or discoveryVideos instead',
  )
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
        if (shouldHideVideo(video)) {
          return null;
        }
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
      '🔍 Searching for videos by author ${pubkeyForLogs(pubkey)} across ${_eventLists.length} subscription types',
      name: 'VideoEventService',
      category: LogCategory.video,
    );
    for (final entry in _eventLists.entries) {
      final subscriptionType = entry.key;
      final eventList = entry.value;
      final matchingVideos = eventList
          .where((video) => video.pubkey == pubkey)
          .toList();
      if (matchingVideos.isNotEmpty) {
        Log.debug(
          '  📱 Found ${matchingVideos.length} videos in ${subscriptionType.name} list (total: ${eventList.length})',
          name: 'VideoEventService',
          category: LogCategory.video,
        );
      } else {
        Log.debug(
          '  ⏭️  No videos in ${subscriptionType.name} list (total: ${eventList.length})',
          name: 'VideoEventService',
          category: LogCategory.video,
        );
      }
      result.addAll(matchingVideos);
    }
    Log.debug(
      '✅ Total videos found for ${pubkeyForLogs(pubkey)}: ${result.length}',
      name: 'VideoEventService',
      category: LogCategory.video,
    );
    return result;
  }

  /// Remove a video from ALL data structures (comprehensive deletion)
  ///
  /// This method removes the video from:
  /// - `_eventLists` (all subscription types: homeFeed, discovery, etc.)
  /// - `_authorBuckets` (used by profile feeds)
  /// - `_hashtagBuckets` (used by hashtag feeds)
  /// - Marks as known deleted to prevent pagination resurrection
  ///
  /// This mirrors the `updateVideoEvent()` pattern for comprehensive state updates.
  /// Call this after successfully publishing a NIP-09 delete event.
  void removeVideoCompletely(String videoId) {
    _removeVideoCompletely(
      primaryEventId: videoId,
      coordinateKey: null,
      logIdentity: videoId,
    );
  }

  /// Remove every cached version of an addressable video from all feeds.
  ///
  /// Kind 34236 videos are parameterized replaceable events: edits can create
  /// new event ids while preserving the same `pubkey:d-tag` identity. Deleting
  /// by event id alone lets an older/newer replacement reappear, so user
  /// deletion paths should pass the full [VideoEvent] when available.
  void removeVideoEventCompletely(VideoEvent video) {
    _removeVideoCompletely(
      primaryEventId: video.id,
      coordinateKey: _knownDeletionCoordinateKey(video),
      logIdentity: video.addressableId ?? video.id,
    );
  }

  void _removeVideoCompletely({
    required String primaryEventId,
    required String? coordinateKey,
    required String logIdentity,
  }) {
    var removedCount = 0;
    final removedVideoIds = <String>{};

    bool shouldRemove(VideoEvent video) =>
        video.id == primaryEventId ||
        (coordinateKey != null &&
            _knownDeletionCoordinateKey(video) == coordinateKey);

    // Remove from all subscription types (mirrors updateVideoEvent pattern)
    for (final entry in _eventLists.entries) {
      final initialLength = entry.value.length;
      entry.value.removeWhere((video) {
        final remove = shouldRemove(video);
        if (remove) removedVideoIds.add(video.id);
        return remove;
      });
      final removed = initialLength - entry.value.length;
      if (removed > 0) {
        removedCount += removed;
        Log.debug(
          'Removed video $logIdentity from ${entry.key} (${entry.value.length} remaining)',
          name: 'VideoEventService',
          category: LogCategory.video,
        );
      }
    }

    // Remove from all author buckets
    _authorBuckets.removeWhere(
      (video) {
        final remove = shouldRemove(video);
        if (remove) removedVideoIds.add(video.id);
        return remove;
      },
      onBucketRemoved: (authorPubkey, removed) {
        removedCount += removed;
        Log.debug(
          'Removed video $logIdentity from author bucket ${pubkeyForLogs(authorPubkey)}',
          name: 'VideoEventService',
          category: LogCategory.video,
        );
      },
    );

    // Remove from all hashtag buckets
    for (final entry in _hashtagBuckets.entries) {
      final initialLength = entry.value.length;
      entry.value.removeWhere((video) {
        final remove = shouldRemove(video);
        if (remove) removedVideoIds.add(video.id);
        return remove;
      });
      final removed = initialLength - entry.value.length;
      if (removed > 0) {
        removedCount += removed;
        Log.debug(
          'Removed video $logIdentity from hashtag bucket ${entry.key}',
          name: 'VideoEventService',
          category: LogCategory.video,
        );
      }
    }

    // Mark as known deleted to prevent pagination resurrection.
    //
    // Semantics: removal is permanent for the lifetime of this service.
    // Even if subsequent relay queries return the same event id, or another
    // event id for the same addressable video, it will be filtered out.
    _knownDeletedVideoIds.add(primaryEventId);
    _knownDeletedVideoIds.addAll(removedVideoIds);
    if (coordinateKey != null) {
      // The NIP-09 request the caller just published carries "now", so every
      // version up to this moment is covered while a later republish is not.
      _rememberDeletedCoordinate(
        coordinateKey,
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
    }

    _purgeEventsFromLocalCache({primaryEventId, ...removedVideoIds});

    // Emit on the side-channel BEFORE notifyListeners so that subscribers
    // who react via the stream (e.g. FullscreenFeedBloc) update their
    // state in the same frame as ChangeNotifier consumers. Emit
    // concrete event ids so existing fullscreen/grid consumers remain
    // compatible. If the video was not in any active feed, still emit the
    // requested id because a fullscreen route may be holding it in BLoC state.
    if (!_removedVideoIdsController.isClosed) {
      final idsToEmit = {primaryEventId, ...removedVideoIds};
      idsToEmit.forEach(_removedVideoIdsController.add);
    }

    Log.info(
      removedCount > 0
          ? 'Removed video $logIdentity from $removedCount location(s) across all feeds'
          : 'Video $logIdentity marked as deleted (was not in any active feeds)',
      name: 'VideoEventService',
      category: LogCategory.video,
    );
    // Notify listeners to update UI immediately (optimistic update).
    notifyListeners();
  }

  /// Remove a video from an author's cached list (optimistic deletion)
  ///
  /// @Deprecated: Use [removeVideoCompletely] instead for comprehensive removal
  /// from all data structures. This method only removes from author buckets.
  @Deprecated('Use removeVideoCompletely() instead for comprehensive removal')
  void removeVideoFromAuthorList(String authorPubkey, String videoId) {
    // Delegate to comprehensive removal
    removeVideoCompletely(videoId);
  }

  /// Check if a video has a known deletion tombstone.
  /// Used to filter out deleted videos from pagination results
  bool isVideoKnownDeleted(String videoId) {
    return _knownDeletedVideoIds.contains(videoId);
  }

  /// Backwards-compatible alias for callers that have not migrated from the
  /// original local-only deletion naming.
  bool isVideoLocallyDeleted(String videoId) {
    return isVideoKnownDeleted(videoId);
  }

  /// Hydrate known deletion tombstones from persisted delete history or
  /// observed remote deletes.
  ///
  /// Keys of [addressableDeletedAt] must use the NIP-33 `kind:pubkey:d-tag`
  /// format; each value is the `created_at` of the deletion request that
  /// removed it, in seconds. The service keeps its own compact lookup key
  /// private so callers do not couple to the in-memory implementation.
  void seedKnownDeletionTombstones({
    Iterable<String> eventIds = const [],
    Map<String, int> addressableDeletedAt = const {},
  }) {
    _knownDeletedVideoIds.addAll(eventIds.where((id) => id.isNotEmpty));

    for (final entry in addressableDeletedAt.entries) {
      final parsed = AId.fromString(entry.key);
      if (parsed == null ||
          parsed.kind != NIP71VideoKinds.addressableShortVideo ||
          parsed.pubkey.isEmpty ||
          parsed.dTag.isEmpty) {
        continue;
      }
      _rememberDeletedCoordinate(
        _knownDeletionCoordinateKeyFromParts(
          pubkey: parsed.pubkey,
          stableId: parsed.dTag,
        ),
        entry.value,
      );
    }
  }

  /// Backwards-compatible alias for local delete-history hydration.
  void seedLocalDeletionTombstones({
    Iterable<String> eventIds = const [],
    Map<String, int> addressableDeletedAt = const {},
  }) {
    seedKnownDeletionTombstones(
      eventIds: eventIds,
      addressableDeletedAt: addressableDeletedAt,
    );
  }

  /// Records a coordinate tombstone, keeping the newest deletion when the
  /// same coordinate is deleted more than once.
  void _rememberDeletedCoordinate(String coordinateKey, int deletedAt) {
    final known = _knownDeletedVideoCoordinates[coordinateKey];
    if (known != null && known >= deletedAt) return;
    _knownDeletedVideoCoordinates[coordinateKey] = deletedAt;
  }

  /// Whether [coordinateKey] was deleted by a request at or after
  /// [createdAt] — a version published later is not covered by it.
  bool _isCoordinateDeleted(String coordinateKey, int createdAt) {
    final deletedUpTo = _knownDeletedVideoCoordinates[coordinateKey];
    return deletedUpTo != null && createdAt <= deletedUpTo;
  }

  /// Check whether this concrete video or its addressable identity has been
  /// deleted by a known local or remote NIP-09 delete.
  bool isVideoEventKnownDeleted(VideoEvent video) {
    return _knownDeletedVideoIds.contains(video.id) ||
        _isCoordinateDeleted(
          _knownDeletionCoordinateKey(video),
          video.nostrCreatedAt,
        );
  }

  /// Backwards-compatible alias for callers that have not migrated from the
  /// original local-only deletion naming.
  bool isVideoEventLocallyDeleted(VideoEvent video) {
    return isVideoEventKnownDeleted(video);
  }

  String _knownDeletionCoordinateKey(VideoEvent video) =>
      _knownDeletionCoordinateKeyFromParts(
        pubkey: video.pubkey,
        stableId: video.stableId,
      );

  String _knownDeletionCoordinateKeyFromParts({
    required String pubkey,
    required String stableId,
  }) => '${pubkey.toLowerCase()}:$stableId';

  /// Whether a raw relay event is already tombstoned, by id or — for
  /// addressable videos, where an edit mints a new id for the same clip — by
  /// its `pubkey:stable-id` coordinate.
  bool _isKnownDeletedRawEvent(Event event) {
    if (_knownDeletedVideoIds.contains(event.id)) return true;
    if (!NIP71VideoKinds.isVideoKind(event.kind)) return false;

    final stableId = _rawStableId(event);
    if (stableId == null) return false;

    return _isCoordinateDeleted(
      _knownDeletionCoordinateKeyFromParts(
        pubkey: event.pubkey,
        stableId: stableId,
      ),
      event.createdAt,
    );
  }

  /// The stable id a raw event will parse into, mirroring
  /// [VideoEvent.stableId]: the `d` tag, else the `vine_id` tag some clients
  /// send instead. Returns null when neither is present, where the event id
  /// is the identity and the id check above already covers it.
  String? _rawStableId(Event event) {
    String? vineId;
    for (final tag in event.tags) {
      if (tag.length < 2 || tag[1].isEmpty) continue;
      if (tag[0] == 'd') return tag[1];
      if (tag[0] == 'vine_id') vineId ??= tag[1];
    }
    return vineId;
  }

  void _handleObservedDeletionEvent(Event deletionEvent) {
    if (deletionEvent.kind != _eventDeletionKind) return;

    final deletionPubkey = deletionEvent.pubkey.toLowerCase();
    final requestedEventIds = <String>{};
    final coordinateKeys = <String>{};
    final addressableIds = <String>{};

    for (final tag in deletionEvent.tags) {
      if (tag.length < 2) continue;

      final tagName = tag[0];
      final tagValue = tag[1];
      if (tagName == 'e' && tagValue.isNotEmpty) {
        requestedEventIds.add(tagValue.toLowerCase());
      } else if (tagName == 'a' && tagValue.isNotEmpty) {
        final parsed = AId.fromString(tagValue);
        if (parsed == null ||
            parsed.kind != NIP71VideoKinds.addressableShortVideo ||
            parsed.pubkey.toLowerCase() != deletionPubkey ||
            parsed.dTag.isEmpty) {
          continue;
        }

        addressableIds.add(tagValue);
        coordinateKeys.add(
          _knownDeletionCoordinateKeyFromParts(
            pubkey: parsed.pubkey,
            stableId: parsed.dTag,
          ),
        );
      }
    }

    if (requestedEventIds.isEmpty && coordinateKeys.isEmpty) return;

    final validatedEventIds = <String>{};
    for (final video in _allCachedVideos()) {
      if (video.pubkey.toLowerCase() != deletionPubkey) continue;

      final matchesRequestedId = requestedEventIds.contains(
        video.id.toLowerCase(),
      );
      final matchesCoordinate =
          coordinateKeys.contains(_knownDeletionCoordinateKey(video)) &&
          video.nostrCreatedAt <= deletionEvent.createdAt;

      if (matchesRequestedId || matchesCoordinate) {
        validatedEventIds.add(video.id);
      }
    }

    // The store is purged from the *requested* ids, not the validated ones:
    // a row that no feed has loaded is exactly the case that survives a
    // restart and flashes on the next launch. Authorship is re-checked
    // against the stored row instead of against memory.
    _purgeDeletedVideosFromStore(
      deletionPubkey: deletionPubkey,
      deletionCreatedAt: deletionEvent.createdAt,
      deletionEventId: deletionEvent.id,
      requestedEventIds: requestedEventIds,
      addressableIds: addressableIds,
    );

    if (validatedEventIds.isEmpty && coordinateKeys.isEmpty) return;

    seedKnownDeletionTombstones(
      eventIds: validatedEventIds,
      addressableDeletedAt: {
        for (final addressableId in addressableIds)
          addressableId: deletionEvent.createdAt,
      },
    );

    _removeKnownDeletedVideos(
      eventIds: validatedEventIds,
      coordinateKeys: coordinateKeys,
      deletionCreatedAt: deletionEvent.createdAt,
      logIdentity: deletionEvent.id,
    );
  }

  Iterable<VideoEvent> _allCachedVideos() sync* {
    for (final videos in _eventLists.values) {
      yield* videos;
    }
    yield* _authorBuckets.allVideos;
    for (final videos in _hashtagBuckets.values) {
      yield* videos;
    }
  }

  /// Drops tombstoned videos from every in-memory surface.
  ///
  /// Pass `purgeStore: false` when the caller has already deleted these rows;
  /// without it the store purge runs a second time for the same ids.
  void _removeKnownDeletedVideos({
    required Set<String> eventIds,
    required Set<String> coordinateKeys,
    required int deletionCreatedAt,
    required String logIdentity,
    bool purgeStore = true,
  }) {
    var removedCount = 0;
    final removedVideoIds = <String>{};

    // A coordinate match only counts up to the deletion's own timestamp; a
    // version the author republished afterwards is not covered by it.
    bool shouldRemove(VideoEvent video) =>
        eventIds.contains(video.id) ||
        (coordinateKeys.contains(_knownDeletionCoordinateKey(video)) &&
            video.nostrCreatedAt <= deletionCreatedAt);

    for (final entry in _eventLists.entries) {
      final initialLength = entry.value.length;
      entry.value.removeWhere((video) {
        final remove = shouldRemove(video);
        if (remove) removedVideoIds.add(video.id);
        return remove;
      });
      removedCount += initialLength - entry.value.length;
    }

    removedCount += _authorBuckets.removeWhere((video) {
      final remove = shouldRemove(video);
      if (remove) removedVideoIds.add(video.id);
      return remove;
    });

    for (final entry in _hashtagBuckets.entries) {
      final initialLength = entry.value.length;
      entry.value.removeWhere((video) {
        final remove = shouldRemove(video);
        if (remove) removedVideoIds.add(video.id);
        return remove;
      });
      removedCount += initialLength - entry.value.length;
    }

    if (!_removedVideoIdsController.isClosed) {
      removedVideoIds.forEach(_removedVideoIdsController.add);
    }

    if (purgeStore) {
      _purgeEventsFromLocalCache({...eventIds, ...removedVideoIds});
    }

    Log.info(
      removedCount > 0
          ? 'Applied observed video deletion $logIdentity to $removedCount cached location(s)'
          : 'Recorded observed video deletion $logIdentity tombstone',
      name: 'VideoEventService',
      category: LogCategory.video,
    );
    notifyListeners();
  }

  /// Deletes tombstoned events from the local event store.
  ///
  /// The in-memory removal above only lasts for this service's lifetime, but
  /// the rows survive it. The cache-first startup query ([_loadCachedEvents])
  /// reads straight from those rows, so without this purge every launch
  /// re-serves deleted videos until the relay redelivers the Kind 5 event —
  /// several hundred milliseconds of deleted clips on the profile grid, once
  /// per app start.
  ///
  /// `NostrClient` purges the same rows when it sees or publishes a Kind 5,
  /// but only when it was given a database; this keeps the service correct on
  /// its own and adds the authorship check that the client-side purge lacks.
  ///
  /// Fire-and-forget: deletion handling has already succeeded in memory, so a
  /// failed purge must not break it.
  void _purgeEventsFromLocalCache(Set<String> eventIds) {
    final router = _eventRouter;
    if (router == null || eventIds.isEmpty) return;

    // Evict pending writes first. A row queued before the tombstone existed
    // passed the ingestion guard, and its flush would land after the DELETE
    // below and re-create exactly what was just removed.
    router.dropQueuedEvents(eventIds);

    unawaited(
      router.db.nostrEventsDao
          .deleteEventsByIds(eventIds.toList())
          .then((purged) {
            if (purged == 0) return;
            Log.debug(
              'Purged $purged deleted event(s) from the local cache',
              name: 'VideoEventService',
              category: LogCategory.video,
            );
          })
          .catchError((Object error) {
            Log.warning(
              'Failed to purge deleted events from local cache: $error',
              name: 'VideoEventService',
              category: LogCategory.video,
            );
          }),
    );
  }

  /// Upper bound on rows a single `a`-tag coordinate can contribute to one
  /// purge. Addressable writes upsert per coordinate, so a handful is the
  /// realistic ceiling; this only stops the DAO's implicit default from
  /// silently truncating a pathological set.
  static const int _maxCoordinateRowsPerPurge = 500;

  /// Purges the rows an observed NIP-09 deletion targets, including rows no
  /// feed has loaded — the ones that survive a restart and flash on the next
  /// launch.
  ///
  /// Every id is re-checked against the stored row's own pubkey, so a relay
  /// cannot use a forged `e` tag to delete another author's cached videos.
  /// Addressable `a` tags were already author-matched by the caller.
  void _purgeDeletedVideosFromStore({
    required String deletionPubkey,
    required int deletionCreatedAt,
    required String deletionEventId,
    required Set<String> requestedEventIds,
    required Set<String> addressableIds,
  }) {
    final router = _eventRouter;
    if (router == null) return;
    if (requestedEventIds.isEmpty && addressableIds.isEmpty) return;

    unawaited(
      _resolveAndPurgeDeletedRows(
        router: router,
        deletionPubkey: deletionPubkey,
        deletionCreatedAt: deletionCreatedAt,
        deletionEventId: deletionEventId,
        requestedEventIds: requestedEventIds,
        addressableIds: addressableIds,
      ).catchError((Object error) {
        Log.warning(
          'Failed to purge deleted events from local cache: $error',
          name: 'VideoEventService',
          category: LogCategory.video,
        );
      }),
    );
  }

  Future<void> _resolveAndPurgeDeletedRows({
    required EventRouter router,
    required String deletionPubkey,
    required int deletionCreatedAt,
    required String deletionEventId,
    required Set<String> requestedEventIds,
    required Set<String> addressableIds,
  }) async {
    final dao = router.db.nostrEventsDao;
    final idsToPurge = <String>{};

    if (requestedEventIds.isNotEmpty) {
      // One query for the whole `e` tag set — a Kind 5 may name many ids.
      // The author check stays in Dart so it tolerates pubkey casing the way
      // the rest of this class does; `pubkey IN (...)` would not.
      final stored = await dao.getEventsByFilter(
        Filter(
          ids: requestedEventIds.toList(),
          limit: requestedEventIds.length,
        ),
      );
      for (final event in stored) {
        if (event.pubkey.toLowerCase() != deletionPubkey) continue;
        idsToPurge.add(event.id);
      }
    }

    for (final addressableId in addressableIds) {
      final parsed = AId.fromString(addressableId);
      if (parsed == null) continue;
      final matches = await dao.getEventsByFilter(
        Filter(
          kinds: [parsed.kind],
          // `pubkey IN (...)` is case-sensitive, so bind the already-lowercased
          // author the caller matched this coordinate against rather than the
          // tag's own casing.
          authors: [deletionPubkey],
          d: [parsed.dTag],
          // NIP-09 scopes an `a` deletion to versions up to the request's
          // own timestamp. Without this, an old Kind 5 that a relay
          // redelivers on launch wipes a version republished after it.
          until: deletionCreatedAt,
          limit: _maxCoordinateRowsPerPurge,
        ),
      );
      idsToPurge.addAll(matches.map((event) => event.id));
    }

    if (idsToPurge.isEmpty) return;

    // Record the tombstone for rows no feed had loaded. Without it the
    // ingestion guard stays false for these ids and the next relay delivery
    // writes the row straight back, undoing the purge above.
    seedKnownDeletionTombstones(eventIds: idsToPurge);

    router.dropQueuedEvents(idsToPurge);
    final purged = await dao.deleteEventsByIds(idsToPurge.toList());

    // A copy can arrive between the Kind 5 and the awaits above: it cleared
    // the ingestion guard before the tombstone existed, so a feed may be
    // holding it even though the row is gone. Sweep those ids out of memory
    // and announce them; the store was already purged a line ago.
    if (_allCachedVideos().any((video) => idsToPurge.contains(video.id))) {
      _removeKnownDeletedVideos(
        eventIds: idsToPurge,
        coordinateKeys: const {},
        deletionCreatedAt: deletionCreatedAt,
        logIdentity: deletionEventId,
        purgeStore: false,
      );
    }

    if (purged == 0) return;
    Log.debug(
      'Purged $purged deleted event(s) from the local cache',
      name: 'VideoEventService',
      category: LogCategory.video,
    );
  }

  /// Emits a video id whenever the service has marked it removed —
  /// today this is user-initiated deletion via [removeVideoCompletely];
  /// future block / mute flows will reuse this same channel.
  ///
  /// Subscribers should treat each event as "drop this id from any open
  /// surface immediately." The stream is broadcast and does not buffer,
  /// so newcomers only receive future emissions; the canonical source of
  /// truth is still the service state plus [isVideoKnownDeleted].
  Stream<String> get removedVideoIds => _removedVideoIdsController.stream;

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
    VideoSortField? sortBy,
  }) async {
    // Skip if EventRouter not available (backward compatibility)
    if (_eventRouter == null) {
      return [];
    }

    try {
      final filter = Filter(
        kinds: kinds,
        authors: authors,
        t: hashtags,
        since: since,
        until: until,
        limit: limit,
      );
      final cachedEvents = await _eventRouter.db.nostrEventsDao
          .getEventsByFilter(filter, sortBy: sortBy?.fieldName);

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

  void _hydrateCachedProfilesInBackground(
    List<Event> cachedEvents, {
    required SubscriptionType subscriptionType,
  }) {
    final profileRepository = _profileRepository;
    if (profileRepository == null || cachedEvents.isEmpty) {
      return;
    }

    final uniquePubkeys = cachedEvents.map((e) => e.pubkey).toSet().toList();
    if (uniquePubkeys.isEmpty) {
      return;
    }

    Log.info(
      '⚡ Batch fetching profiles in background for ${cachedEvents.length} cached events',
      name: 'VideoEventService',
      category: LogCategory.video,
    );

    unawaited(
      profileRepository.fetchBatchProfiles(pubkeys: uniquePubkeys).catchError((
        Object error,
        StackTrace stackTrace,
      ) {
        Log.error(
          'Background cached profile hydration failed for $subscriptionType: $error',
          name: 'VideoEventService',
          category: LogCategory.video,
          error: error,
          stackTrace: stackTrace,
        );
        return <String, UserProfile>{};
      }),
    );
  }

  void _storeSubscriptionParams({
    required SubscriptionType subscriptionType,
    required List<String>? authors,
    required List<String>? hashtags,
    required String? group,
    required int? since,
    required int? until,
    required int limit,
    required bool includeReposts,
    required VideoSortField? sortBy,
    required NIP50SortMode? nip50Sort,
  }) {
    _subscriptionParams[subscriptionType] = {
      'authors': authors,
      'hashtags': hashtags,
      'group': group,
      'since': since,
      'until': until,
      'limit': limit,
      'includeReposts': includeReposts,
      'sortBy': sortBy,
      'nip50Sort': nip50Sort,
    };
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
    VideoSortField? sortBy, // Server-side sorting if relay supports it
    NIP50SortMode?
    nip50Sort, // NIP-50 search sorting (e.g., sort:hot, sort:top)
    bool force = false, // Force refresh even if parameters match
    bool scheduleOnlineRetry = true,
  }) async {
    // NostrService now handles subscription deduplication automatically via filter hashing
    // We still track subscription types for our own state management

    // Set loading state immediately to prevent race conditions
    _isLoading = true;
    _error = null;

    // Explicit subscribe paths re-arm the consecutive-timeout budget. The
    // auto-retry cycle passes scheduleOnlineRetry: false so it keeps counting
    // toward the give-up ceiling instead of resetting itself every attempt.
    if (scheduleOnlineRetry) {
      _retryScheduler.clearTimeoutBudget(subscriptionType);
    }

    if (!_nostrService.isInitialized) {
      _isLoading = false;

      Log.warning(
        'Cannot subscribe - Nostr service not initialized (will retry when ready)',
        name: 'VideoEventService',
        category: LogCategory.video,
      );
      // Defensive: Don't throw, just return early
      // The provider will retry when the service becomes initialized
      return;
    }

    // Check connection status
    if (!_connectionService.isOnline) {
      _isLoading = false;

      Log.warning(
        'Device is offline, will retry when connection is restored',
        name: 'VideoEventService',
        category: LogCategory.video,
      );
      if (scheduleOnlineRetry) {
        // Store retry parameters before the offline early return so a first
        // subscribe can retry the requested feed when connectivity returns.
        _storeSubscriptionParams(
          subscriptionType: subscriptionType,
          authors: authors,
          hashtags: hashtags,
          group: group,
          since: since,
          until: until,
          limit: limit,
          includeReposts: includeReposts,
          sortBy: sortBy,
          nip50Sort: nip50Sort,
        );
        _retryScheduler.scheduleWhenOnline(subscriptionType);
      }
      throw const VideoEventServiceException('Device is offline');
    }

    if (_nostrService.connectedRelayCount == 0) {
      _isLoading = false;

      Log.warning(
        'No relays connected, will retry when relay connection is restored',
        name: 'VideoEventService',
        category: LogCategory.video,
      );
      if (scheduleOnlineRetry) {
        _storeSubscriptionParams(
          subscriptionType: subscriptionType,
          authors: authors,
          hashtags: hashtags,
          group: group,
          since: since,
          until: until,
          limit: limit,
          includeReposts: includeReposts,
          sortBy: sortBy,
          nip50Sort: nip50Sort,
        );
        _scheduleRetryWhenRelayReady(subscriptionType);
      }
      throw const RelayNotReadyException('No connected relays');
    }

    // Avoid churn: if params match existing subscription, skip re-subscribe
    // UNLESS force=true (e.g., pull-to-refresh)
    if (!force &&
        _isDuplicateSubscription(
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
        category: LogCategory.video,
      );
      _isLoading = false;
      return;
    }

    if (force) {
      Log.info(
        '💪 Force refresh: creating new subscription for $subscriptionType even if params match',
        name: 'VideoEventService',
        category: LogCategory.video,
      );
    }

    // Only close existing subscription for this type if replace=true and params changed
    if (replace && isSubscribed(subscriptionType)) {
      Log.info(
        '🔄 Replacing existing $subscriptionType subscription',
        name: 'VideoEventService',
        category: LogCategory.video,
      );
      await _cancelSubscription(subscriptionType);
    }

    try {
      Log.info(
        '🎬 Creating $subscriptionType filter for NIP-71 video events...',
        name: 'VideoEventService',
        category: LogCategory.video,
      );
      Log.info(
        '  - Subscription Type: $subscriptionType',
        name: 'VideoEventService',
        category: LogCategory.video,
      );
      Log.info(
        '  - Authors: ${authors?.length ?? 'all'} ${authors?.isNotEmpty == true ? "(first: ${pubkeyForLogs(authors!.first)})" : ""}',
        name: 'VideoEventService',
        category: LogCategory.video,
      );
      Log.info(
        '  - Hashtags: ${hashtags?.join(', ') ?? 'none'}',
        name: 'VideoEventService',
        category: LogCategory.video,
      );
      Log.info(
        '  - Group: ${group ?? 'none'}',
        name: 'VideoEventService',
        category: LogCategory.video,
      );
      Log.info(
        '  - Since: ${since != null ? DateTime.fromMillisecondsSinceEpoch(since * 1000) : 'none'}',
        name: 'VideoEventService',
        category: LogCategory.video,
      );
      Log.info(
        '  - Until: ${until != null ? DateTime.fromMillisecondsSinceEpoch(until * 1000) : 'none'}',
        name: 'VideoEventService',
        category: LogCategory.video,
      );
      Log.info(
        '  - Limit: $limit',
        name: 'VideoEventService',
        category: LogCategory.video,
      );
      Log.info(
        '  - Replace existing: $replace',
        name: 'VideoEventService',
        category: LogCategory.video,
      );
      Log.info(
        '  - Include reposts: $includeReposts',
        name: 'VideoEventService',
        category: LogCategory.video,
      );

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
          category: LogCategory.video,
        );
        // Let relays decide what content to return - they know their data best
      }

      // Create optimized filter for NIP-71 video events
      // IMPORTANT: Convert hashtags to lowercase per NIP-24 requirement
      final lowercaseHashtags = hashtags
          ?.map((tag) => tag.toLowerCase())
          .toList();

      // Create base filter for NIP-71 video events
      final baseVideoFilter = Filter(
        kinds: NIP71VideoKinds.getAllVideoKinds(), // NIP-71 video events
        authors: authors,
        since: effectiveSince,
        until: effectiveUntil,
        limit: limit, // Use full limit for video events
        t: lowercaseHashtags, // Add hashtag filtering at relay level (lowercase per NIP-24)
      );

      // Use NIP-50 search or VideoFilterBuilder for server-side sorting
      Filter videoFilter = baseVideoFilter;

      // NIP-50 search takes priority over Divine extensions
      if (nip50Sort != null && _videoFilterBuilder != null) {
        videoFilter = _videoFilterBuilder.buildNIP50Filter(
          baseFilter: baseVideoFilter,
          sortMode: nip50Sort,
        );
        Log.info(
          '🔍 NIP-50: Using search query "${nip50Sort.toSearchQuery()}" for trending/popular discovery',
          name: 'VideoEventService',
          category: LogCategory.video,
        );
      } else if (sortBy != null && _videoFilterBuilder != null) {
        try {
          // Use connected relay for capability check, fallback to default
          final relayUrl = _nostrService.connectedRelays.isNotEmpty
              ? _nostrService.connectedRelays.first
              : AppConstants.defaultRelayUrl;
          videoFilter = await _videoFilterBuilder.buildFilter(
            baseFilter: baseVideoFilter,
            relayUrl: relayUrl,
            sortBy: sortBy,
          );
        } catch (e) {
          Log.warning(
            'Failed to build sorted filter: $e. Using standard filter.',
            name: 'VideoEventService',
            category: LogCategory.video,
          );
          // Fall back to base filter on error
        }
      }

      // Debug: Log when subscribing to Classic Vines
      if (authors != null &&
          authors.contains(AppConstants.classicVinesPubkey)) {
        Log.debug(
          '🌟 Subscribing to Classic Vines account (${pubkeyForLogs(AppConstants.classicVinesPubkey)})',
          name: 'VideoEventService',
          category: LogCategory.video,
        );
      }

      if (lowercaseHashtags != null && lowercaseHashtags.isNotEmpty) {
        Log.debug(
          'Adding hashtag filter to relay query: $lowercaseHashtags (converted to lowercase per NIP-24)',
          name: 'VideoEventService',
          category: LogCategory.video,
        );
      }

      // Store group for client-side filtering
      _activeGroupFilters[subscriptionType] = group;

      final filters = <Filter>[videoFilter];
      if (authors != null && authors.isNotEmpty) {
        filters.add(
          Filter(
            kinds: [_eventDeletionKind],
            authors: authors,
            since: effectiveSince,
            until: effectiveUntil,
            limit: limit,
          ),
        );
      }

      // Optionally add repost filter if enabled
      if (includeReposts) {
        final repostFilter = Filter(
          kinds: [16], // NIP-18 generic reposts only
          authors: authors,
          since: effectiveSince,
          until: effectiveUntil,
          limit: (limit * 0.2).round(), // Only 20% for reposts when enabled
        );
        filters.add(repostFilter);
        Log.debug(
          'Using primary video filter + optional repost filter:',
          name: 'VideoEventService',
          category: LogCategory.video,
        );
        Log.debug(
          '  - Video filter ($limit limit): ${videoFilter.toJson()}',
          name: 'VideoEventService',
          category: LogCategory.video,
        );
        Log.debug(
          '  - Repost filter (${(limit * 0.2).round()} limit): ${repostFilter.toJson()}',
          name: 'VideoEventService',
          category: LogCategory.video,
        );
      } else {
        Log.debug(
          'Using video-only filter (reposts disabled):',
          name: 'VideoEventService',
          category: LogCategory.video,
        );
        Log.debug(
          '  - Video filter ($limit limit): ${videoFilter.toJson()}',
          name: 'VideoEventService',
          category: LogCategory.video,
        );
      }

      // Store hashtag filter for event processing
      _activeHashtagFilters[subscriptionType] = hashtags;

      // Verify NostrService is ready
      if (!_nostrService.isInitialized) {
        Log.error(
          '❌ NostrService not initialized - cannot create subscription',
          name: 'VideoEventService',
          category: LogCategory.video,
        );
        throw Exception('NostrService not initialized');
      }

      // BYPASS SubscriptionManager for main video feed - go directly to NostrService
      // Holds the id claimed in _pendingSubscriptionIds so the catch
      // below (where subscriptionId is out of scope) can release it.
      String? pendingClaimId;
      try {
        // Use the filters we already created above which include authors
        Log.info(
          '🚀 Creating subscription with filters: ${filters.map((f) => f.toJson()).toList()}',
          name: 'VideoEventService',
          category: LogCategory.video,
        );

        // Extra debug for home feed
        if (subscriptionType == SubscriptionType.homeFeed) {
          Log.info(
            '🏠🏠🏠 HOME FEED SUBSCRIPTION DEBUG:',
            name: 'VideoEventService',
            category: LogCategory.video,
          );
          Log.info(
            '  Authors requested: ${authors?.length ?? 0}',
            name: 'VideoEventService',
            category: LogCategory.video,
          );
          if (authors != null && authors.isNotEmpty) {
            Log.info(
              '  First 3 authors: ${authors.take(3).join(", ")}',
              name: 'VideoEventService',
              category: LogCategory.video,
            );
          }
          Log.info(
            '  Filters being sent to NostrService:',
            name: 'VideoEventService',
            category: LogCategory.video,
          );
          for (var i = 0; i < filters.length; i++) {
            final f = filters[i];
            Log.info(
              '    Filter $i: kinds=${f.kinds}, authors=${f.authors?.length}, limit=${f.limit}',
              name: 'VideoEventService',
              category: LogCategory.video,
            );
          }
        }

        // Extra debug for hashtag feed
        if (subscriptionType == SubscriptionType.hashtag) {
          Log.info(
            '🏷️🏷️🏷️ HASHTAG SUBSCRIPTION DEBUG:',
            name: 'VideoEventService',
            category: LogCategory.video,
          );
          Log.info(
            '  Hashtags requested: ${hashtags?.join(", ") ?? "none"}',
            name: 'VideoEventService',
            category: LogCategory.video,
          );
          Log.info(
            '  Lowercase hashtags: ${lowercaseHashtags?.join(", ") ?? "none"}',
            name: 'VideoEventService',
            category: LogCategory.video,
          );
          Log.info(
            '  Filters being sent to NostrService:',
            name: 'VideoEventService',
            category: LogCategory.video,
          );
          for (var i = 0; i < filters.length; i++) {
            final f = filters[i];
            Log.info(
              '    Filter $i: kinds=${f.kinds}, t=${f.t}, limit=${f.limit}',
              name: 'VideoEventService',
              category: LogCategory.video,
            );
            Log.info(
              '    Full filter JSON: ${f.toJson()}',
              name: 'VideoEventService',
              category: LogCategory.video,
            );
          }
        }

        // Store current subscription parameters for duplicate detection BEFORE any early returns
        _storeSubscriptionParams(
          subscriptionType: subscriptionType,
          authors: authors,
          hashtags: hashtags,
          group: group,
          since: since,
          until: until,
          limit: limit,
          includeReposts: includeReposts,
          sortBy: sortBy,
          nip50Sort: nip50Sort,
        );

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

        // Check if we already have this exact subscription — registered
        // or still being set up by a concurrent call (the setup below
        // crosses async gaps, so the claim must happen synchronously here).
        final hasRegisteredSubscription = _subscriptions.containsKey(
          subscriptionId,
        );
        if (hasRegisteredSubscription ||
            _pendingSubscriptionIds.contains(subscriptionId)) {
          Log.info(
            '🔄 Reusing existing subscription $subscriptionId with identical parameters',
            name: 'VideoEventService',
            category: LogCategory.video,
          );
          if (hasRegisteredSubscription) {
            // Update active subscription mapping
            _activeSubscriptions[subscriptionType] = subscriptionId;
          }
          return; // Reuse existing subscription
        }
        _pendingSubscriptionIds.add(subscriptionId);
        pendingClaimId = subscriptionId;

        // Set per-subscription loading state after duplicate detection so a
        // reused in-flight subscription keeps its current query tally intact.
        final paginationState = _paginationStates[subscriptionType];
        paginationState?.startQuery();

        // Create direct subscription using NostrService with proper filters
        final subscriptionStartTime = DateTime.now();
        int eventCount = 0;
        DateTime? firstEventTime;
        bool eoseReceived = false;
        bool timeoutReported = false;

        // Operation-scoped so two loads of the same type keep independent
        // traces (#7119), and registered as pending so every teardown path
        // closes the native handle instead of leaking it (#7151).
        final pendingTrace = FeedLoadTrace(
          trace: _performanceMonitor.startOperationTrace(
            'feed_load_${subscriptionType.name}',
          ),
          eventCount: () => eventCount,
        );
        _pendingFeedLoadTraces[subscriptionId] = pendingTrace;
        void completeFeedLoadTrace(String completion, {int? eventTotal}) {
          _pendingFeedLoadTraces.remove(subscriptionId);
          pendingTrace.complete(completion, eventTotal: eventTotal);
        }

        Log.info(
          '📡 Creating subscription for $subscriptionType at ${subscriptionStartTime.toIso8601String()}',
          name: 'VideoEventService',
          category: LogCategory.video,
        );

        // Set up timeout to detect feed loading failures (30 seconds).
        // Tracked on the service so replace/cancel can kill it — a local-only
        // Timer kept firing after the user left and could unmap a later live
        // sub of the same type, then auto-retry with stale/null filters.
        _cancelFeedLoadTimeout(subscriptionType);
        late final Timer feedLoadingTimeout;
        feedLoadingTimeout = Timer(const Duration(seconds: 30), () {
          if (_isDisposed) return;
          if (!identical(
            _feedLoadTimeouts[subscriptionType],
            feedLoadingTimeout,
          )) {
            return;
          }
          _feedLoadTimeouts.remove(subscriptionType);

          // Subscription already torn down or replaced — do not recover.
          if (_activeSubscriptions[subscriptionType] != subscriptionId ||
              !_subscriptions.containsKey(subscriptionId)) {
            return;
          }

          if (!eoseReceived && eventCount == 0 && !timeoutReported) {
            timeoutReported = true;
            Log.error(
              '⏰ TIMEOUT: No events received for $subscriptionType after 30 seconds!',
              name: 'VideoEventService',
              category: LogCategory.video,
            );

            // Clean up subscription state so retry is possible.
            // The stored params are deliberately kept: they are the only
            // record of the filters this feed was built from, and the retry
            // scheduled below cannot re-issue the REQ without them. Dropping
            // them made a timed-out feed unrecoverable until the user
            // navigated away and back (#7124).
            Log.info(
              '🧹 Cleaning up timed-out subscription state for $subscriptionType',
              name: 'VideoEventService',
              category: LogCategory.video,
            );
            _activeSubscriptions.remove(subscriptionType);

            // Cancel the subscription to prevent leaks. This also releases the
            // REQ in the SDK, which force-cycles the relay if the socket
            // swallowed it — so the retry below runs on a live connection.
            final sub = _subscriptions.remove(subscriptionId);
            sub?.cancel();

            // Reset loading state
            _paginationStates[subscriptionType]?.isLoading = false;

            // Report timeout to Crashlytics
            _reportFeedLoadingTimeout(
              subscriptionType: subscriptionType,
              filters: filters,
              duration: DateTime.now().difference(subscriptionStartTime),
              relayConnected: _nostrService.connectedRelayCount > 0,
              isOnline: _connectionService.isOnline,
            );

            completeFeedLoadTrace('timeout');
            // Every other completion path notifies; without this the loading
            // state flips silently and no listener re-evaluates the feed.
            notifyListeners();

            if (_retryScheduler.recordFeedLoadTimeout(subscriptionType)) {
              _retryScheduler.scheduleWhenOnline(subscriptionType);
            }
          }
        });
        _feedLoadTimeouts[subscriptionType] = feedLoadingTimeout;

        // Phase 3.3: Cache-first strategy - load cached events BEFORE relay subscription
        // This provides instant UI feedback while relay fetches fresh data
        // Now FAST with proper database indexes on kind, created_at, and composite indexes!
        final List<Event> cachedEvents = await _loadCachedEvents(
          kinds: NIP71VideoKinds.getAllVideoKinds(),
          authors: authors,
          hashtags: lowercaseHashtags,
          since: effectiveSince,
          until: effectiveUntil,
          limit: limit,
          sortBy: sortBy,
        );

        // Disposed while the cache read was in flight, so dispose has already
        // closed this load's trace. Carrying on would notify a dead
        // ChangeNotifier and wire a relay subscription the teardown sweep has
        // already passed, leaving nothing to cancel it.
        if (_isDisposed) {
          _completeAbandonedFeedLoadTrace(subscriptionId, 'disposed');
          _pendingSubscriptionIds.remove(subscriptionId);
          return;
        }

        // Process cached events immediately (same flow as relay events, minus
        // the write-back — they were just read out of the store).
        for (final event in cachedEvents) {
          _handleNewVideoEvent(event, subscriptionType, persist: false);
        }

        // Notify UI with cached results for instant display
        if (cachedEvents.isNotEmpty) {
          notifyListeners();
          Log.info(
            '💾 Cache-first: UI updated with ${cachedEvents.length} cached events for instant display',
            name: 'VideoEventService',
            category: LogCategory.video,
          );
          completeFeedLoadTrace('cache', eventTotal: cachedEvents.length);
        }

        final eventStream = _nostrService.subscribe(
          filters,
          onEose: () {
            eoseReceived = true;
            _cancelFeedLoadTimeout(subscriptionType);
            _retryScheduler.recordFeedServed(subscriptionType);
            final eoseDuration = DateTime.now().difference(
              subscriptionStartTime,
            );
            Log.info(
              '✅ EOSE received for $subscriptionType after ${eoseDuration.inMilliseconds}ms with $eventCount events',
              name: 'VideoEventService',
              category: LogCategory.video,
            );

            // Extra logging for hashtag subscriptions
            if (subscriptionType == SubscriptionType.hashtag) {
              Log.info(
                '🏷️✅ HASHTAG EOSE: $eventCount events received, hashtag buckets count: ${_hashtagBuckets.length}',
                name: 'VideoEventService',
                category: LogCategory.video,
              );
              if (lowercaseHashtags != null) {
                for (final tag in lowercaseHashtags) {
                  final count = _hashtagBuckets[tag]?.length ?? 0;
                  Log.info(
                    '🏷️📊 Bucket "$tag" has $count videos',
                    name: 'VideoEventService',
                    category: LogCategory.video,
                  );
                }
              }
            }

            // Warn if no events received - trigger automatic diagnostics
            if (eventCount == 0) {
              Log.warning(
                '⚠️ EOSE received but NO EVENTS for $subscriptionType - feed will be empty!',
                name: 'VideoEventService',
                category: LogCategory.video,
              );

              // Run automatic diagnostics for debugging empty feeds
              _runAutoDiagnostics(subscriptionType, filters);

              // Report to Crashlytics - this is a critical user experience issue
              _reportEmptyFeedToCrashlytics(
                subscriptionType: subscriptionType,
                filters: filters,
                eoseDuration: eoseDuration,
                relayConnected: _nostrService.connectedRelayCount > 0,
                isOnline: _connectionService.isOnline,
              );
              completeFeedLoadTrace('eose_empty');
            } else {
              completeFeedLoadTrace('eose');
            }

            // Complete per-subscription loading state — historical data
            // is done. Without this, isLoadingForSubscription() stays true
            // and the UI never transitions from spinner to empty state.
            final paginationState = _paginationStates[subscriptionType];
            if (paginationState != null) {
              // On the first EOSE, the initial subscription's stored backlog
              // has routed through the real-time handler, so the per-query
              // tally never sees it. `eventCount` is this subscription's raw
              // stream count: repeat EOSE cycles can include later live
              // deliveries, and the filter set can include non-video kinds,
              // duplicates, or events filtered out below. Those all skew toward
              // keeping `hasMore` true a page longer than needed — the safe
              // direction, and the load-more path re-queries from there.
              paginationState.recordReceivedCount(eventCount);
              paginationState.completeQuery(limit);
              notifyListeners();
            }
          },
        );

        _hydrateCachedProfilesInBackground(
          cachedEvents,
          subscriptionType: subscriptionType,
        );

        // Owned by _subscriptions[subscriptionId] and cancelled in
        // _cancelExistingSubscriptions.
        // ignore: cancel_subscriptions
        final streamSubscription = eventStream.listen(
          (event) {
            eventCount++;

            // Track first event arrival time
            if (firstEventTime == null) {
              firstEventTime = DateTime.now();
              _cancelFeedLoadTimeout(subscriptionType);
              _retryScheduler.recordFeedServed(subscriptionType);
              final firstEventLatency = firstEventTime!.difference(
                subscriptionStartTime,
              );
              Log.info(
                '🎯 First event for $subscriptionType arrived after ${firstEventLatency.inMilliseconds}ms',
                name: 'VideoEventService',
                category: LogCategory.video,
              );

              // Stop performance trace on first event arrival
              completeFeedLoadTrace('first_relay_event');
            }

            if (subscriptionType == SubscriptionType.homeFeed) {
              Log.info(
                '🏠📥 HOME FEED EVENT #$eventCount RECEIVED: kind=${event.kind}, author=${pubkeyForLogs(event.pubkey)}',
                name: 'VideoEventService',
                category: LogCategory.video,
              );
            }

            if (subscriptionType == SubscriptionType.hashtag) {
              Log.info(
                '🏷️📥 HASHTAG EVENT #$eventCount RECEIVED: kind=${event.kind}, id=${event.id}',
                name: 'VideoEventService',
                category: LogCategory.video,
              );
            }

            // Normal priority: the live feed is on screen, so these rows
            // should reach the store ahead of background ingestion.
            _handleNewVideoEvent(
              event,
              subscriptionType,
              priority: EventIngestionPriority.normal,
            );
          },
          onError: (error) {
            _cancelFeedLoadTimeout(subscriptionType);
            Log.error(
              '❌ Subscription error for $subscriptionType after $eventCount events: $error',
              name: 'VideoEventService',
              category: LogCategory.video,
            );
            completeFeedLoadTrace('error');
            _handleSubscriptionError(error, subscriptionType);
          },
          onDone: () {
            _cancelFeedLoadTimeout(subscriptionType);
            final totalDuration = DateTime.now().difference(
              subscriptionStartTime,
            );
            Log.info(
              '🏁 Subscription complete for $subscriptionType: $eventCount events in ${totalDuration.inMilliseconds}ms (EOSE: $eoseReceived)',
              name: 'VideoEventService',
              category: LogCategory.video,
            );

            // PERSISTENT SUBSCRIPTION: onDone means relay closed connection
            // For main feeds, this should trigger reconnection attempt
            completeFeedLoadTrace('done');
            _handleSubscriptionComplete(subscriptionType);
            if (_shouldMaintainSubscription(subscriptionType)) {
              _scheduleReconnection(subscriptionType);
            } else {
              // NON-PERSISTENT SUBSCRIPTION: Clean up state so future subscriptions aren't skipped as duplicates
              // This fixes the bug where re-subscribing after stream completion gets skipped even though stream is dead
              Log.info(
                '🧹 Cleaning up non-persistent subscription state for $subscriptionType',
                name: 'VideoEventService',
                category: LogCategory.video,
              );
              _activeSubscriptions.remove(subscriptionType);
              _subscriptionParams.remove(subscriptionType);
              _subscriptions.remove(subscriptionId);
            }
          },
        );

        // Store the stream subscription for cleanup
        _subscriptions[subscriptionId] = streamSubscription;
        _pendingSubscriptionIds.remove(subscriptionId);
        _activeSubscriptions[subscriptionType] = subscriptionId;

        // Subscription is tracked per type in _activeSubscriptions
      } catch (e, stackTrace) {
        if (pendingClaimId != null) {
          _pendingSubscriptionIds.remove(pendingClaimId);
          // Setup threw before any completion path and leaves no subscription
          // for teardown to sweep, so only dispose would reach this handle —
          // and report the session, not the load, as its duration.
          _completeAbandonedFeedLoadTrace(pendingClaimId, 'setup_error');
        }
        Log.error(
          '❌ Failed to create direct subscription: $e',
          name: 'VideoEventService',
          category: LogCategory.video,
        );
        Log.error(
          '❌ Stack trace: $stackTrace',
          name: 'VideoEventService',
          category: LogCategory.video,
        );
        rethrow;
      }

      Log.info(
        'Video event subscription established successfully!',
        name: 'VideoEventService',
        category: LogCategory.video,
      );

      // Add default video if feed is empty to ensure new users have content
      _ensureDefaultContent();

      // Progressive loading removed - let UI trigger loadMore as needed
      final totalSubs = _subscriptions.length + _activeSubscriptionIds.length;
      Log.debug(
        'Subscription status: active=$totalSubs subscriptions (${_activeSubscriptionIds.length} managed, ${_subscriptions.length} direct)',
        name: 'VideoEventService',
        category: LogCategory.video,
      );
    } catch (e) {
      _error = e.toString();
      Log.error(
        'Failed to subscribe to video events: $e',
        name: 'VideoEventService',
        category: LogCategory.video,
      );

      // Check if it's a connection-related error
      if (_isConnectionError(e)) {
        Log.error(
          '📱 Connection error detected, will retry when online',
          name: 'VideoEventService',
          category: LogCategory.video,
        );
        if (scheduleOnlineRetry) {
          _retryScheduler.scheduleWhenOnline(subscriptionType);
        } else {
          rethrow;
        }
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
    // Check if this is a replaceable event (parameterized replaceable kinds)
    final isReplaceable =
        originalEvent.kind == NIP71VideoKinds.addressableNormalVideo ||
        originalEvent.kind == NIP71VideoKinds.addressableShortVideo;

    if (!isReplaceable) {
      return true; // Not replaceable, allow normal processing
    }

    // For parameterized replaceable events, construct key: subscriptionType:kind:pubkey:d-tag
    String replaceKey =
        '$subscriptionType:${originalEvent.kind}:${originalEvent.pubkey}';

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
      final (oldVideoEvent, oldTimestamp) =
          _replaceableVideoEvents[replaceKey]!;

      final isNewer = originalEvent.createdAt > oldTimestamp;
      final isTieBreakWinner =
          originalEvent.createdAt == oldTimestamp &&
          originalEvent.id.compareTo(oldVideoEvent.id) < 0;

      if (isNewer || isTieBreakWinner) {
        // New event is newer, or wins the NIP-01 equal-timestamp event-id
        // tie-break for replaceable events.
        final replacementReason = isNewer
            ? 'newer'
            : 'same timestamp, lower event id';
        Log.info(
          '🔄 Replacing old kind ${originalEvent.kind} event '
          '(ts:$oldTimestamp, id:${oldVideoEvent.id}) with '
          '$replacementReason version '
          '(ts:${originalEvent.createdAt}, id:${originalEvent.id})',
          name: 'VideoEventService',
          category: LogCategory.video,
        );

        // Remove old event from event list
        final eventList = _eventLists[subscriptionType];
        if (eventList != null) {
          eventList.removeWhere((e) => e.id == oldVideoEvent.id);
        }

        // Update tracking with new event
        _replaceableVideoEvents[replaceKey] = (
          videoEvent,
          originalEvent.createdAt,
        );
        return true; // Allow new event to be added
      } else {
        final skipReason = originalEvent.createdAt == oldTimestamp
            ? 'same timestamp, higher event id'
            : 'older';
        Log.info(
          '⏩ Skipping $skipReason kind ${originalEvent.kind} event '
          '(ts:${originalEvent.createdAt}, id:${originalEvent.id}) - '
          'kept version exists (ts:$oldTimestamp, id:${oldVideoEvent.id})',
          name: 'VideoEventService',
          category: LogCategory.video,
        );
        return false; // Skip this event
      }
    } else {
      // First time seeing this replaceable event
      _replaceableVideoEvents[replaceKey] = (
        videoEvent,
        originalEvent.createdAt,
      );
      return true; // Allow normal processing
    }
  }

  /// Handle new video event from subscription.
  ///
  /// This is the service's single persistence entry point: every ingestion
  /// path routes through here so the tombstone guard below cannot be bypassed.
  ///
  /// [persist] must be false for events that were just read back out of the
  /// local store. They are already persisted, and re-queueing them is not
  /// merely redundant: the router drains the background queue last, so under
  /// the startup relay burst those writes land *after* an observed deletion
  /// has purged the same rows — resurrecting deleted videos on every launch.
  ///
  /// [priority] lets an on-screen feed jump the background ingestion backlog.
  void _handleNewVideoEvent(
    dynamic eventData,
    SubscriptionType subscriptionType, {
    bool persist = true,
    EventIngestionPriority priority = EventIngestionPriority.background,
  }) {
    try {
      // The event should already be an Event object from NostrService
      if (eventData is! Event) {
        Log.warning(
          'Expected Event object but got ${eventData.runtimeType}',
          name: 'VideoEventService',
          category: LogCategory.video,
        );
        return;
      }

      final event = eventData;

      // Route ALL events to database first (single source of truth)
      // Fire-and-forget: database writes shouldn't block event processing.
      // Tombstoned events are never re-persisted — a queued write that lands
      // after the purge would put the row straight back.
      if (persist && !_isKnownDeletedRawEvent(event)) {
        _eventRouter?.handleEvent(event, priority: priority);
      }

      // Fast-path de-duplication before logging and processing
      // Use case-insensitive ID comparison for consistent deduplication
      final paginationState = _paginationStates[subscriptionType];
      if (paginationState != null) {
        if (paginationState.seenEventIds.contains(event.id.toLowerCase())) {
          return;
        }
        // Mark seen early to prevent repeated logs for the same event (even if later skipped)
        paginationState.markEventSeen(event.id);
      }

      if (event.kind == _eventDeletionKind) {
        _handleObservedDeletionEvent(event);
        return;
      }

      if (!NIP71VideoKinds.isVideoKind(event.kind) && event.kind != 16) {
        // Cache non-video events in appropriate services instead of discarding
        if (event.kind == 0 && _profileRepository != null) {
          // Kind 0 = profile metadata - cache it for profile display
          try {
            final profile = UserProfile.fromNostrEvent(event);
            // Fire-and-forget: cache the profile asynchronously
            _profileRepository
                .cacheProfile(profile)
                .then((_) {
                  Log.verbose(
                    '✅ Cached profile event for ${pubkeyForLogs(event.pubkey)} from video subscription',
                    name: 'VideoEventService',
                    category: LogCategory.video,
                  );
                })
                .catchError((e) {
                  Log.error(
                    'Failed to cache profile event: $e',
                    name: 'VideoEventService',
                    category: LogCategory.video,
                  );
                });
          } catch (e) {
            Log.error(
              'Failed to parse profile event: $e',
              name: 'VideoEventService',
              category: LogCategory.video,
            );
          }
        } else {
          Log.verbose(
            '⏩ Skipping non-video/repost event (kind ${event.kind})',
            name: 'VideoEventService',
            category: LogCategory.video,
          );
        }
        return;
      }

      // Skip repost events if reposts are disabled
      if (event.kind == 16 && !(_includeReposts[subscriptionType] ?? false)) {
        Log.warning(
          '⏩ Skipping repost event ${event.id} (reposts disabled)',
          name: 'VideoEventService',
          category: LogCategory.video,
        );
        return;
      }

      // Check if we already have this event in this subscription type
      // Use case-insensitive ID comparison for consistent deduplication
      final eventList = _eventLists[subscriptionType] ?? [];
      final eventIdLower = event.id.toLowerCase();
      if (eventList.any((e) => e.id.toLowerCase() == eventIdLower)) {
        _duplicateVideoEventCount++;
        _logDuplicateVideoEventsAggregated();
        return;
      }

      // Check if content is blocked
      if (_blocklistRepository?.shouldFilterFromFeeds(event.pubkey) == true) {
        Log.verbose(
          'Filtering blocked content from ${pubkeyForLogs(event.pubkey)}',
          name: 'VideoEventService',
          category: LogCategory.video,
        );
        return;
      }

      // Check content filter action (show/warn/hide) per user preferences
      final (filterAction, matchedLabels) = getFilterAction(event);
      if (filterAction == ContentFilterPreference.hide) {
        Log.verbose(
          'Filtering content from event ${event.id}',
          name: 'VideoEventService',
          category: LogCategory.video,
        );
        return;
      }

      // Handle different event kinds
      if (NIP71VideoKinds.isVideoKind(event.kind)) {
        // Direct video event
        // Debug: Check for d tag
        final hasDTag = event.tags.any(
          (tag) => tag.isNotEmpty && tag[0] == 'd',
        );
        if (!hasDTag) {
          Log.warning(
            '⚠️ Event missing "d" tag - will use event ID as fallback',
            name: 'VideoEventService',
            category: LogCategory.video,
          );
        }

        try {
          var videoEvent = VideoEvent.fromNostrEvent(event);

          // Apply warn labels from content filter so UI can show blur overlay
          if (filterAction == ContentFilterPreference.warn &&
              matchedLabels.isNotEmpty) {
            videoEvent = videoEvent.copyWith(warnLabels: matchedLabels);
          }

          if (shouldHideVideo(videoEvent)) {
            return;
          }

          // Debug: Special logging for Classic Vines content
          if (videoEvent.pubkey == AppConstants.classicVinesPubkey) {
            Log.info(
              '🌟 Received Classic Vines video: ${videoEvent.title ?? videoEvent.id}',
              name: 'VideoEventService',
              category: LogCategory.video,
            );
          }

          // Handle replaceable events (NIP-33)
          // Returns true if we should add this event (newer or first version)
          // Returns false if we should skip this event (older than cached version)
          if (!_handleReplaceableVideoEvent(
            videoEvent,
            subscriptionType,
            event,
          )) {
            return; // Skip - incoming event is older than what we already have
          }
          // If we reach here: either not replaceable, first time seeing it, or newer version
          // For newer versions, _handleReplaceableVideoEvent already removed the old event

          // Check hashtag filter if active
          if (!_passesHashtagFilter(videoEvent, subscriptionType)) {
            Log.warning(
              '⏩ Skipping video without required hashtags: ${_activeHashtagFilters[subscriptionType]}',
              name: 'VideoEventService',
              category: LogCategory.video,
            );
            return;
          }

          // Check group filter if active
          if (_activeGroupFilters[subscriptionType] != null &&
              videoEvent.group != _activeGroupFilters[subscriptionType]) {
            Log.warning(
              '⏩ Skipping video from different group: ${videoEvent.group} (want: ${_activeGroupFilters[subscriptionType]})',
              name: 'VideoEventService',
              category: LogCategory.video,
            );
            return;
          }

          // Only add events with video URLs
          if (videoEvent.hasVideo) {
            _addVideoToSubscription(videoEvent, subscriptionType);

            // Keep only the most recent events to prevent memory issues
            final list = _eventLists[subscriptionType] ?? [];
            if (list.length > 500) {
              list.removeRange(500, list.length);
            }
          } else {
            // Log.warning(
            //     '🎬 FILTER: ⏩ Skipping video event without video URL (hasVideo=false)',
            //     name: 'VideoEventService',
            //     category: LogCategory.video);
            // Log.warning(
            //     '🎬 FILTER: Event details - title: ${videoEvent.title}, content: ${event.content}, tags: ${event.tags}',
            //     name: 'VideoEventService',
            //     category: LogCategory.video);
          }
        } catch (e, stackTrace) {
          Log.error(
            'Failed to parse video event: $e',
            name: 'VideoEventService',
            category: LogCategory.video,
          );
          Log.verbose(
            '📱 Stack trace: $stackTrace',
            name: 'VideoEventService',
            category: LogCategory.video,
          );
          Log.verbose(
            'Event details:',
            name: 'VideoEventService',
            category: LogCategory.video,
          );
          Log.verbose(
            '  - ID: ${event.id}',
            name: 'VideoEventService',
            category: LogCategory.video,
          );
          Log.verbose(
            '  - Kind: ${event.kind}',
            name: 'VideoEventService',
            category: LogCategory.video,
          );
          Log.verbose(
            '  - Pubkey: ${pubkeyForLogs(event.pubkey)}',
            name: 'VideoEventService',
            category: LogCategory.video,
          );
          Log.verbose(
            '  - Content: ${event.content}',
            name: 'VideoEventService',
            category: LogCategory.video,
          );
          Log.verbose(
            '  - Created at: ${event.createdAt}',
            name: 'VideoEventService',
            category: LogCategory.video,
          );
          Log.verbose(
            '  - Tags: ${_formatEventTagsForLog(event.tags)}',
            name: 'VideoEventService',
            category: LogCategory.video,
          );
        }
      } else if (event.kind == 16) {
        _handleRepostEvent(event, subscriptionType, isHistorical: false);
      }
    } catch (e) {
      Log.error(
        'Error processing video event: $e',
        name: 'VideoEventService',
        category: LogCategory.video,
      );
    }
  }

  /// Handle historical video events from pagination queries (adds to bottom of feed)
  void _handleHistoricalVideoEvent(
    dynamic eventData,
    SubscriptionType subscriptionType,
  ) {
    try {
      // The event should already be an Event object from NostrService
      if (eventData is! Event) {
        Log.warning(
          'Expected Event object but got ${eventData.runtimeType}',
          name: 'VideoEventService',
          category: LogCategory.video,
        );
        return;
      }

      final event = eventData;
      // Fast-path de-duplication before logging
      // Use case-insensitive ID comparison for consistent deduplication
      final paginationState = _paginationStates[subscriptionType];
      if (paginationState != null) {
        if (paginationState.seenEventIds.contains(event.id.toLowerCase())) {
          return;
        }
        paginationState.markEventSeen(event.id);
      }

      Log.debug(
        '📥 Received historical $subscriptionType event: kind=${event.kind}, author=${pubkeyForLogs(event.pubkey)}, id=${event.id}',
        name: 'VideoEventService',
        category: LogCategory.video,
      );

      if (event.kind == _eventDeletionKind) {
        _handleObservedDeletionEvent(event);
        return;
      }

      if (!NIP71VideoKinds.isVideoKind(event.kind) && event.kind != 16) {
        Log.warning(
          '⏩ Skipping non-video/repost historical event (kind ${event.kind})',
          name: 'VideoEventService',
          category: LogCategory.video,
        );
        return;
      }

      // Skip repost events if reposts are disabled
      if (event.kind == 16 && !(_includeReposts[subscriptionType] ?? false)) {
        Log.warning(
          '⏩ Skipping historical repost event ${event.id} (reposts disabled)',
          name: 'VideoEventService',
          category: LogCategory.video,
        );
        return;
      }

      // Check if we already have this event in this subscription type
      // Use case-insensitive ID comparison for consistent deduplication
      final eventList = _eventLists[subscriptionType] ?? [];
      final historicalEventIdLower = event.id.toLowerCase();
      if (eventList.any((e) => e.id.toLowerCase() == historicalEventIdLower)) {
        _duplicateVideoEventCount++;
        _logDuplicateVideoEventsAggregated();
        return;
      }

      // Check if content is blocked
      if (_blocklistRepository?.shouldFilterFromFeeds(event.pubkey) == true) {
        Log.verbose(
          'Filtering blocked historical content from ${pubkeyForLogs(event.pubkey)}',
          name: 'VideoEventService',
          category: LogCategory.video,
        );
        return;
      }

      // Check content filter action (show/warn/hide) per user preferences
      final (histFilterAction, histMatchedLabels) = getFilterAction(event);
      if (histFilterAction == ContentFilterPreference.hide) {
        Log.verbose(
          'Filtering historical content from event ${event.id}',
          name: 'VideoEventService',
          category: LogCategory.video,
        );
        return;
      }

      // Handle different event kinds (same logic as real-time events)
      if (NIP71VideoKinds.isVideoKind(event.kind)) {
        // Direct video event
        Log.verbose(
          'Processing historical video event ${event.id}',
          name: 'VideoEventService',
          category: LogCategory.video,
        );
        try {
          var videoEvent = VideoEvent.fromNostrEvent(event);

          // Apply warn labels from content filter so UI can show blur overlay
          if (histFilterAction == ContentFilterPreference.warn &&
              histMatchedLabels.isNotEmpty) {
            videoEvent = videoEvent.copyWith(warnLabels: histMatchedLabels);
          }

          if (shouldHideVideo(videoEvent)) {
            return;
          }

          // Handle replaceable events (NIP-33)
          // Returns true if we should add this event (newer or first version)
          // Returns false if we should skip this event (older than cached version)
          if (!_handleReplaceableVideoEvent(
            videoEvent,
            subscriptionType,
            event,
          )) {
            return; // Skip - incoming event is older than what we already have
          }
          // If we reach here: either not replaceable, first time seeing it, or newer version
          // For newer versions, _handleReplaceableVideoEvent already removed the old event

          // Check hashtag filter if active
          if (!_passesHashtagFilter(videoEvent, subscriptionType)) {
            Log.warning(
              '⏩ Skipping historical video without required hashtags: ${_activeHashtagFilters[subscriptionType]}',
              name: 'VideoEventService',
              category: LogCategory.video,
            );
            return;
          }

          // Check group filter if active
          if (_activeGroupFilters[subscriptionType] != null &&
              videoEvent.group != _activeGroupFilters[subscriptionType]) {
            Log.warning(
              '⏩ Skipping historical video from different group: ${videoEvent.group} (want: ${_activeGroupFilters[subscriptionType]})',
              name: 'VideoEventService',
              category: LogCategory.video,
            );
            return;
          }

          // Only add events with video URLs
          if (videoEvent.hasVideo) {
            _addVideoToSubscription(
              videoEvent,
              subscriptionType,
              isHistorical: true,
            );

            // Keep only the most recent events to prevent memory issues
            final list = _eventLists[subscriptionType] ?? [];
            if (list.length > 500) {
              list.removeRange(500, list.length);
            }
          } else {
            Log.warning(
              '🎬 FILTER: ⏩ Skipping historical video event without video URL (hasVideo=false)',
              name: 'VideoEventService',
              category: LogCategory.video,
            );
          }
        } catch (e) {
          Log.error(
            'Failed to parse historical video event: $e',
            name: 'VideoEventService',
            category: LogCategory.video,
          );
        }
      } else if (event.kind == 16) {
        _handleRepostEvent(event, subscriptionType, isHistorical: true);
      }
    } catch (e) {
      Log.error(
        'Error processing historical video event: $e',
        name: 'VideoEventService',
        category: LogCategory.video,
      );
    }
  }

  /// Handle kind 16 repost events using RepostResolver
  Future<void> _handleRepostEvent(
    Event event,
    SubscriptionType subscriptionType, {
    required bool isHistorical,
  }) async {
    final video = await _repostResolver.resolve(event);
    if (video == null) return;

    // Check hashtag filter
    if (!_passesHashtagFilter(video, subscriptionType)) {
      Log.debug(
        '⏩ Skipping repost without required hashtags: ${_activeHashtagFilters[subscriptionType]}',
        name: 'VideoEventService',
        category: LogCategory.video,
      );
      return;
    }

    _addVideoToSubscription(
      video,
      subscriptionType,
      isHistorical: isHistorical,
    );
  }

  /// Whether [video] carries one of the hashtags [subscriptionType] filters on.
  ///
  /// The comparison is case-insensitive on both sides. `subscribeToVideoFeed`
  /// lowercases the tag before putting it in the relay REQ (NIP-24) but stores
  /// the caller's original casing in [_activeHashtagFilters], so a
  /// case-sensitive compare here rejects every event the relay returns for a
  /// capitalised hashtag.
  bool _passesHashtagFilter(
    VideoEvent video,
    SubscriptionType subscriptionType,
  ) {
    final filter = _activeHashtagFilters[subscriptionType];
    if (filter == null || filter.isEmpty) return true;

    final videoHashtags = video.hashtags
        .map((tag) => tag.toLowerCase())
        .toSet();
    return filter.any((tag) => videoHashtags.contains(tag.toLowerCase()));
  }

  /// Handle subscription error
  void _handleSubscriptionError(
    dynamic error,
    SubscriptionType subscriptionType,
  ) {
    _error = error.toString();
    Log.error(
      '$subscriptionType subscription error: $error',
      name: 'VideoEventService',
      category: LogCategory.video,
    );
    final totalSubs = _subscriptions.length + _activeSubscriptionIds.length;
    final eventCount = getEventCount(subscriptionType);
    Log.verbose(
      'Current state: $subscriptionType events=$eventCount, subscriptions=$totalSubs',
      name: 'VideoEventService',
      category: LogCategory.video,
    );

    // Check if it's a connection error and schedule retry
    if (_isConnectionError(error)) {
      Log.error(
        '📱 Subscription connection error, scheduling retry...',
        name: 'VideoEventService',
        category: LogCategory.video,
      );
      _retryScheduler.scheduleWhenOnline(subscriptionType);
    }
  }

  /// Handle subscription completion
  void _handleSubscriptionComplete(SubscriptionType subscriptionType) {
    Log.info(
      '📱 $subscriptionType subscription completed',
      name: 'VideoEventService',
      category: LogCategory.video,
    );
    final totalSubs = _subscriptions.length + _activeSubscriptionIds.length;
    final eventCount = getEventCount(subscriptionType);
    Log.verbose(
      'Final state: $subscriptionType events=$eventCount, subscriptions=$totalSubs',
      name: 'VideoEventService',
      category: LogCategory.video,
    );
  }

  /// Subscribe to specific user's video events
  Future<void> subscribeToUserVideos(String pubkey, {int limit = 50}) async {
    Log.info(
      'SVC subscribeToUser: hex=${pubkeyForLogs(pubkey)}',
      name: 'Service',
      category: LogCategory.video,
    );

    // Backfill the author bucket with videos by this author that already exist in other subscription types
    // This handles the case where the user's videos were already loaded in discovery/home feeds
    // Also includes reposts BY this user (where reposterPubkey matches)
    //
    // Membership is checked against a Set built once (O(M) total) rather than
    // a per-video `bucket.any` linear scan (O(M×N), with two toLowerCase
    // allocations per comparison). This loop runs synchronously on the main
    // thread on every subscribe call, so for an author with many videos and a
    // large cross-feed cache the quadratic form blocked the UI for seconds.
    final backfillCandidates = <VideoEvent>[];
    for (final eventList in _eventLists.values) {
      for (final video in eventList) {
        // Include original videos by this author
        final isOriginalByAuthor = video.pubkey == pubkey && !video.isRepost;
        // Include reposts made by this author
        final isRepostByAuthor =
            video.isRepost && video.reposterPubkey == pubkey;
        if (!isOriginalByAuthor && !isRepostByAuthor) continue;

        backfillCandidates.add(video);
      }
    }
    _authorBuckets.backfillUniqueById(pubkey, backfillCandidates);
    final authorVideoCount = _authorBuckets.videosFor(pubkey).length;
    if (authorVideoCount > 0) {
      Log.info(
        'SVC subscribeToUser: backfilled $authorVideoCount existing videos for ${pubkeyForLogs(pubkey)}',
        name: 'Service',
        category: LogCategory.video,
      );
    }

    return subscribeToVideoFeed(
      subscriptionType: SubscriptionType.profile,
      authors: [pubkey],
      limit: limit,
      includeReposts:
          true, // Include reposts to show what the user has reposted
    );
  }

  /// Cancels the active profile-feed subscription only if it still belongs to
  /// [pubkey]. Profile feeds are route-scoped, but the underlying subscription
  /// registry is service-global; the author guard prevents an old route disposal
  /// from cancelling a newer profile route.
  Future<void> unsubscribeFromUserVideos(String pubkey) async {
    final params = _subscriptionParams[SubscriptionType.profile];
    final authors = params?['authors'] as List<String>?;
    final isActiveAuthor =
        authors != null && authors.length == 1 && authors.single == pubkey;

    if (!isActiveAuthor) {
      Log.debug(
        'Skipping stale profile unsubscribe for ${pubkeyForLogs(pubkey)}',
        name: 'VideoEventService',
        category: LogCategory.video,
      );
      return;
    }

    await _cancelSubscription(SubscriptionType.profile);
  }

  /// Query historical videos for a specific user (for pagination)
  /// This is used by profile feed provider to load older videos beyond the initial subscription
  Future<void> queryHistoricalUserVideos(
    String pubkey, {
    int? until,
    int limit = 50,
  }) async {
    if (!_nostrService.isInitialized) {
      Log.warning(
        'Cannot query historical user videos - Nostr service not initialized',
        name: 'VideoEventService',
        category: LogCategory.video,
      );
      return;
    }

    Log.info(
      'Querying historical videos for user=${pubkeyForLogs(pubkey)} until=${until != null ? DateTime.fromMillisecondsSinceEpoch(until * 1000) : 'none'} limit=$limit',
      name: 'VideoEventService',
      category: LogCategory.video,
    );

    // Create filters for this specific user's videos and reposts
    final filters = [
      Filter(
        kinds: NIP71VideoKinds.getAllVideoKinds(),
        authors: [pubkey],
        until: until,
        limit: limit,
      ),
      Filter(
        kinds: [16], // Kind 16 reposts
        authors: [pubkey],
        until: until,
        limit: (limit * 0.2).round(), // 20% of limit for reposts
      ),
      Filter(
        kinds: [_eventDeletionKind],
        authors: [pubkey],
        until: until,
        limit: limit,
      ),
    ];

    final completer = Completer<void>();
    int receivedCount = 0;

    try {
      // Stream events from NostrService
      final eventStream = _nostrService.subscribe(filters);
      late StreamSubscription<Event> streamSubscription;

      // Set timeout for receiving events
      final timeoutTimer = Timer(const Duration(seconds: 5), () {
        Log.info(
          'Historical query timeout for user=${pubkeyForLogs(pubkey)} - received $receivedCount events',
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
              'Historical query stream completed for user=${pubkeyForLogs(pubkey)} - received $receivedCount events',
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
              'Historical query stream error for user=${pubkeyForLogs(pubkey)}: $error',
              name: 'VideoEventService',
              category: LogCategory.video,
            );
            completer.completeError(error as Object);
          }
        },
        cancelOnError: false,
      );

      await completer.future;
      await streamSubscription.cancel();

      Log.info(
        'Historical user videos query completed - received $receivedCount events for user=${pubkeyForLogs(pubkey)}',
        name: 'VideoEventService',
        category: LogCategory.video,
      );

      // Notify listeners to update UI
      notifyListeners();
    } catch (e) {
      Log.error(
        'Failed to query historical user videos for user=${pubkeyForLogs(pubkey)}: $e',
        name: 'VideoEventService',
        category: LogCategory.video,
      );
      rethrow;
    }
  }

  /// Subscribe to videos with specific hashtags
  Future<void> subscribeToHashtagVideos(
    List<String> hashtags, {
    int limit = 100,
    bool force = false,
  }) async => subscribeToVideoFeed(
    subscriptionType: SubscriptionType.hashtag,
    hashtags: hashtags,
    limit: limit,
    force: force,
    // REMOVED sortBy - client-side sorting is sufficient for hashtags
    // Server-side sorting may not work reliably with hashtag filters
  );

  /// Subscribe to home feed videos (from people you follow)
  Future<void> subscribeToHomeFeed(
    List<String> followingPubkeys, {
    int limit = 100,
    VideoSortField? sortBy,
    bool force = false,
  }) async {
    // Seed home feed with cached discovery videos for the followed authors
    // This ensures immediate availability of videos when following a new user
    seedHomeFeedFromDiscoveryCache(followingPubkeys);

    await subscribeToVideoFeed(
      subscriptionType: SubscriptionType.homeFeed,
      authors: followingPubkeys,
      limit: limit,
      includeReposts: true,
      sortBy: sortBy,
      force: force,
    );

    // After subscription, seed from relay to ensure we have ALL videos from
    // followed users, not just the most recent ones returned by the subscription.
    // This is especially important when following new users whose older videos
    // might not be in the subscription's initial result set.
    // Fire-and-forget: don't block the UI waiting for seed results.
    // Events stream in progressively via _handleNewVideoEvent.
    unawaited(seedHomeFeedFromFollowedUsers(followingPubkeys, limit: limit));
  }

  /// Seeds the home feed with videos from the discovery cache for specified authors.
  ///
  /// This is called when:
  /// 1. A user follows a new account - their videos from discovery should
  ///    immediately appear in home feed
  /// 2. Home feed is refreshed with an updated following list
  ///
  /// Videos are deduplicated by ID to prevent duplicates when the relay
  /// subscription also returns the same videos.
  void seedHomeFeedFromDiscoveryCache(List<String> followingPubkeys) {
    if (followingPubkeys.isEmpty) return;

    final followingSet = followingPubkeys.toSet();
    final homeFeedList = _eventLists[SubscriptionType.homeFeed] ?? [];
    // Use case-insensitive comparison for Nostr IDs
    final existingIds = homeFeedList.map((v) => v.id.toLowerCase()).toSet();
    final discoveryVideos = _eventLists[SubscriptionType.discovery] ?? [];

    // Find videos in discovery that belong to followed users but aren't in home feed
    final videosToSeed = discoveryVideos
        .where(
          (video) =>
              followingSet.contains(video.pubkey) &&
              !existingIds.contains(video.id.toLowerCase()),
        )
        .toList();

    if (videosToSeed.isEmpty) {
      Log.debug(
        '🏠 seedHomeFeedFromDiscoveryCache: No new videos to seed '
        '(discovery has ${discoveryVideos.length} videos, '
        'following ${followingPubkeys.length} users)',
        name: 'VideoEventService',
        category: LogCategory.video,
      );
      return;
    }

    Log.info(
      '🏠 seedHomeFeedFromDiscoveryCache: Seeding ${videosToSeed.length} videos '
      'from discovery cache into home feed',
      name: 'VideoEventService',
      category: LogCategory.video,
    );

    // Add videos to home feed list
    homeFeedList.addAll(videosToSeed);

    // Sort by creation time (newest first)
    homeFeedList.sortByCreationTime();

    // Notify listeners so UI updates
    notifyListeners();
  }

  /// Seeds the home feed by streaming videos from the relay for followed users.
  ///
  /// Unlike [seedHomeFeedFromDiscoveryCache] which only uses locally cached videos,
  /// this method actively subscribes to the relay for videos from followed users.
  /// Events are processed progressively as they arrive via [_handleNewVideoEvent],
  /// so the UI updates incrementally without blocking.
  ///
  /// The subscription is cancelled after EOSE (all stored events delivered)
  /// since we only need the backfill, not ongoing real-time updates.
  ///
  /// [followingPubkeys] - List of pubkeys the user is following
  /// [limit] - Maximum number of videos to fetch per author (default 50)
  @visibleForTesting
  Future<void> seedHomeFeedFromFollowedUsers(
    List<String> followingPubkeys, {
    int limit = 50,
  }) async {
    if (followingPubkeys.isEmpty) return;

    if (!_nostrService.isInitialized) {
      Log.warning(
        '🏠 seedHomeFeedFromFollowedUsers: NostrService not initialized',
        name: 'VideoEventService',
        category: LogCategory.video,
      );
      return;
    }

    Log.info(
      '🏠 seedHomeFeedFromFollowedUsers: Streaming videos for '
      '${followingPubkeys.length} followed users',
      name: 'VideoEventService',
      category: LogCategory.video,
    );

    try {
      final filter = Filter(
        kinds: NIP71VideoKinds.getAllVideoKinds(),
        authors: followingPubkeys,
        limit: limit,
      );

      final completer = Completer<void>();
      final subscriptionId =
          'seed_home_${DateTime.now().millisecondsSinceEpoch}';

      final eventStream = _nostrService.subscribe(
        [filter],
        subscriptionId: subscriptionId,
        onEose: () {
          // All stored events have been delivered; cancel the seed subscription
          Log.debug(
            '🏠 seedHomeFeedFromFollowedUsers: EOSE received, cancelling '
            'seed subscription',
            name: 'VideoEventService',
            category: LogCategory.video,
          );
          unawaited(_nostrService.unsubscribe(subscriptionId));
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
      );

      final subscription = eventStream.listen(
        (event) {
          _handleNewVideoEvent(event, SubscriptionType.homeFeed);
        },
        onError: (Object error) {
          Log.error(
            '🏠 seedHomeFeedFromFollowedUsers: Stream error: $error',
            name: 'VideoEventService',
            category: LogCategory.video,
          );
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
        onDone: () {
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
      );

      // Safety timeout: don't let the seed run forever
      final timeoutTimer = Timer(const Duration(seconds: 15), () {
        if (!completer.isCompleted) {
          Log.warning(
            '🏠 seedHomeFeedFromFollowedUsers: Timeout (15s), '
            'cancelling seed subscription',
            name: 'VideoEventService',
            category: LogCategory.video,
          );
          unawaited(_nostrService.unsubscribe(subscriptionId));
          completer.complete();
        }
      });

      await completer.future;
      timeoutTimer.cancel();
      await subscription.cancel();
    } catch (e) {
      Log.error(
        '🏠 seedHomeFeedFromFollowedUsers: Error streaming videos: $e',
        name: 'VideoEventService',
        category: LogCategory.video,
      );
    }
  }

  /// Subscribe to discovery videos (all videos for exploration)
  Future<void> subscribeToDiscovery({
    int limit = 100,
    VideoSortField? sortBy,
    NIP50SortMode? nip50Sort,
    bool force = false,
  }) async => subscribeToVideoFeed(
    subscriptionType: SubscriptionType.discovery,
    limit: limit,
    includeReposts: true,
    sortBy: sortBy,
    nip50Sort: nip50Sort,
    force: force,
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
      Log.warning(
        'Cannot subscribe to group - Nostr service not initialized (will retry when ready)',
        name: 'VideoEventService',
        category: LogCategory.video,
      );
      return; // Defensive: Don't throw, just return early
    }

    Log.verbose(
      'Subscribing to videos from group: $group',
      name: 'VideoEventService',
      category: LogCategory.video,
    );

    // Note: Nostr SDK Filter doesn't support custom tags directly,
    // so we'll rely on client-side filtering for group 'h' tags
    Log.verbose(
      'Subscribing to group: $group (will filter client-side)',
      name: 'VideoEventService',
      category: LogCategory.video,
    );

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
      category: LogCategory.video,
    );

    // Close existing subscriptions and create new ones with expanded timeframe
    await unsubscribeFromVideoFeed();

    Log.verbose(
      'Creating new subscription with expanded timeframe...',
      name: 'VideoEventService',
      category: LogCategory.video,
    );
    // Preserve the current reposts setting when refreshing
    return subscribeToVideoFeed(
      subscriptionType: SubscriptionType.discovery,
      force: true, // Force refresh to get fresh data from relay
    );
  }

  /// Resubscribe to persistent feeds when relay set changes.
  ///
  /// Used when the relay set changes (relays added/removed). This method
  /// cancels existing subscriptions and resubscribes, but PRESERVES existing
  /// events in memory. New events from the updated relay set will be merged
  /// in via normal deduplication.
  ///
  /// This avoids jarring UX where temporary relay changes (e.g., indexer
  /// queries for profile fallback) would wipe the user's feed.
  ///
  /// Ephemeral subscriptions (search, hashtag, profile) are cancelled but
  /// not auto-resubscribed; user navigation will trigger fresh ones.
  Future<void> resetAndResubscribeAll() async {
    if (_isDisposed) return;

    Log.info(
      'Relay set changed - resubscribing to persistent feeds (preserving existing events)',
      name: 'VideoEventService',
      category: LogCategory.video,
    );

    // Snapshot params for persistent subscription types before clearing
    final homeFeedParams =
        _subscriptionParams[SubscriptionType.homeFeed] != null
        ? Map<String, dynamic>.from(
            _subscriptionParams[SubscriptionType.homeFeed]!,
          )
        : null;
    final discoveryParams =
        _subscriptionParams[SubscriptionType.discovery] != null
        ? Map<String, dynamic>.from(
            _subscriptionParams[SubscriptionType.discovery]!,
          )
        : null;
    final profileParams = _subscriptionParams[SubscriptionType.profile] != null
        ? Map<String, dynamic>.from(
            _subscriptionParams[SubscriptionType.profile]!,
          )
        : null;

    // Cancel all subscriptions
    await unsubscribeFromVideoFeed();

    // IMPORTANT: Do NOT clear existing event lists - existing events are still
    // valid and should be preserved. New events from the updated relay set will
    // be merged in via normal deduplication. Clearing events causes jarring UX
    // when temporary relay changes (e.g., indexer queries) trigger this method.

    // Re-subscribe to discovery feed (will merge new events with existing)
    if (discoveryParams != null) {
      await subscribeToVideoFeed(
        subscriptionType: SubscriptionType.discovery,
        limit: discoveryParams['limit'] as int? ?? 200,
        sortBy: discoveryParams['sortBy'] as VideoSortField?,
        nip50Sort: discoveryParams['nip50Sort'] as NIP50SortMode?,
        force: true,
      );
    }

    // Re-subscribe to home feed with saved authors list
    if (homeFeedParams != null) {
      final authors = homeFeedParams['authors'] as List<String>?;
      if (authors != null && authors.isNotEmpty) {
        await subscribeToHomeFeed(
          authors,
          limit: homeFeedParams['limit'] as int? ?? 100,
          sortBy: homeFeedParams['sortBy'] as VideoSortField?,
          force: true,
        );
      }
    }

    // Re-subscribe to active profile feed if one was active
    if (profileParams != null) {
      final authors = profileParams['authors'] as List<String>?;
      if (authors != null && authors.isNotEmpty) {
        await subscribeToVideoFeed(
          subscriptionType: SubscriptionType.profile,
          authors: authors,
          limit: profileParams['limit'] as int? ?? 100,
          includeReposts: profileParams['includeReposts'] as bool? ?? true,
          force: true,
        );
      }
    }

    Log.info(
      'Relay set change: resubscription complete',
      name: 'VideoEventService',
      category: LogCategory.video,
    );
  }

  /// Progressive loading: load more videos after initial fast load
  Future<void> loadMoreVideos({int limit = 100}) async {
    Log.verbose(
      '📱 Loading more videos progressively...',
      name: 'VideoEventService',
      category: LogCategory.video,
    );

    // Use larger limit for progressive loading
    return subscribeToVideoFeed(
      subscriptionType: SubscriptionType.discovery,
      limit: limit,
      replace: false, // Don't replace existing subscription
    );
  }

  /// Load more historical events using one-shot query (not persistent subscription)
  Future<void> loadMoreEvents(
    SubscriptionType subscriptionType, {
    int limit = 500,
  }) async {
    final paginationState = _paginationStates[subscriptionType];
    if (paginationState == null) {
      throw VideoEventServiceException(
        'No pagination state found for $subscriptionType',
      );
    }

    if (paginationState.isLoading) {
      Log.debug(
        '📱 Skipping load more for $subscriptionType: already loading',
        name: 'VideoEventService',
        category: LogCategory.video,
      );
      return;
    }

    // If hasMore is false, always try to reset and fetch more
    // Users should be able to keep scrolling to get more content
    if (!paginationState.hasMore) {
      final currentEventCount = _eventLists[subscriptionType]?.length ?? 0;
      Log.info(
        '📱 Resetting pagination for $subscriptionType - have $currentEventCount videos, forcing retry to fetch more',
        name: 'VideoEventService',
        category: LogCategory.video,
      );
      paginationState.reset();
    }

    paginationState.startQuery();

    try {
      Log.debug(
        '📱 Loading more historical events for $subscriptionType...',
        name: 'VideoEventService',
        category: LogCategory.video,
      );

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
            category: LogCategory.video,
          );
        }
      }

      if (existingEvents.isNotEmpty &&
          paginationState.oldestTimestamp != null) {
        // Use existing oldest timestamp WITHOUT creating a gap
        until = paginationState.oldestTimestamp;
        Log.debug(
          '📱 Requesting events older than or equal to ${DateTime.fromMillisecondsSinceEpoch(until! * 1000)} for $subscriptionType',
          name: 'VideoEventService',
          category: LogCategory.video,
        );
      } else {
        // If no events yet, load without date constraints
        Log.debug(
          '📱 No existing events for $subscriptionType, loading fresh content without date constraints',
          name: 'VideoEventService',
          category: LogCategory.video,
        );
      }

      // Use subscription-aware historical query (non-blocking streaming)
      _queryHistoricalEvents(
            subscriptionType: subscriptionType,
            until: until,
            limit: limit,
          )
          .then((_) {
            // Stream completed - finalize pagination state
            Log.info(
              'Historical events streaming completed for $subscriptionType. Total events: ${_eventLists[subscriptionType]?.length ?? 0}',
              name: 'VideoEventService',
              category: LogCategory.video,
            );

            // Complete the pagination query with the requested limit for proper hasMore tracking
            paginationState.completeQuery(limit);

            // Final notification - will only fire if no frame update was scheduled
            // This ensures UI updates even if no events were received
            notifyListeners();
          })
          .catchError((error) {
            Log.error(
              'Historical query stream failed for $subscriptionType: $error',
              name: 'VideoEventService',
              category: LogCategory.video,
            );
            paginationState.isLoading = false;
            notifyListeners();
          });

      // Don't await the query - return immediately and let events stream in
      Log.debug(
        'Historical query started for $subscriptionType, events will stream in',
        name: 'VideoEventService',
        category: LogCategory.video,
      );
    } catch (e) {
      _error = e.toString();
      Log.error(
        'Failed to load more events for $subscriptionType: $e',
        name: 'VideoEventService',
        category: LogCategory.video,
      );

      if (_isConnectionError(e)) {
        Log.error(
          '📱 Load more failed due to connection error for $subscriptionType',
          name: 'VideoEventService',
          category: LogCategory.video,
        );
      }
      paginationState.isLoading = false;
      notifyListeners();
    }
  }

  /// Streaming query for historical events (processes events as they arrive)
  Future<void> _queryHistoricalEvents({
    required SubscriptionType subscriptionType,
    int? until,
    int limit = 500,
  }) async {
    if (!_nostrService.isInitialized) {
      Log.warning(
        'Cannot query historical events - Nostr service not initialized',
        name: 'VideoEventService',
        category: LogCategory.video,
      );
      return; // Defensive: Don't throw, just return early
    }

    // Get current subscription parameters to maintain consistency
    final params = _subscriptionParams[subscriptionType];
    final authors = params?['authors'] as List<String>?;
    final hashtags = params?['hashtags'] as List<String>?;
    // Note: group filtering is handled client-side, not in relay query

    // Create filter without restrictive date constraints
    final filter = Filter(
      kinds:
          NIP71VideoKinds.getAllVideoKinds(), // NIP-71 video events + legacy support
      authors: authors, // Use same authors as main subscription if available
      until: until, // Only use 'until' if we have existing events
      limit: limit,
      t: hashtags
          ?.map((tag) => tag.toLowerCase())
          .toList(), // Add hashtag filter if present
      // No 'since' filter to allow loading of all historical content
    );

    Log.debug(
      '🔍 Streaming historical query for $subscriptionType: until=${until != null ? DateTime.fromMillisecondsSinceEpoch(until * 1000) : 'none'}, limit=$limit',
      name: 'VideoEventService',
    );
    Log.debug(
      'Filter: ${filter.toJson()}',
      name: 'VideoEventService',
      category: LogCategory.video,
    );

    final completer = Completer<void>();
    int receivedCount = 0;

    try {
      // Use direct NostrService streaming approach like ProfileWebSocketService
      final eventStream = _nostrService.subscribe([filter]);
      late StreamSubscription<Event> streamSubscription;

      // Set a reasonable timeout for receiving events
      Timer? timeoutTimer = Timer(const Duration(seconds: 5), () {
        Log.info(
          '📡 Historical query timeout reached for $subscriptionType - received $receivedCount events',
          name: 'VideoEventService',
          category: LogCategory.video,
        );
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
                category: LogCategory.video,
              );
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
            completer.completeError(error as Object);
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
      Log.info(
        '📱 Resetting pagination state for $subscriptionType',
        name: 'VideoEventService',
        category: LogCategory.video,
      );
      paginationState.reset();
    }
  }

  /// Load more content without date restrictions - for when users reach end of feed
  Future<void> loadMoreContentUnlimited({
    SubscriptionType subscriptionType = SubscriptionType.discovery,
    int limit = 300,
  }) async {
    // Prevent overlapping unlimited queries and runaway streaming
    if ((_eventLists[subscriptionType]?.length ?? 0) >= 120) {
      Log.debug(
        'Skipping unlimited content: already have >=120 videos',
        name: 'VideoEventService',
        category: LogCategory.video,
      );
      return;
    }

    // Use a simple in-flight guard
    _isLoading = true;

    try {
      Log.debug(
        '📱 Loading unlimited content for end-of-feed...',
        name: 'VideoEventService',
        category: LogCategory.video,
      );

      // Create a broader query without date restrictions
      final filter = Filter(
        kinds: NIP71VideoKinds.getAllVideoKinds(), // NIP-71 video events
        limit: limit,
        // No date filters - let relays return their best content
      );

      Log.debug(
        'Unlimited content query: limit=$limit',
        name: 'VideoEventService',
        category: LogCategory.video,
      );
      Log.debug(
        'Filter: ${filter.toJson()}',
        name: 'VideoEventService',
        category: LogCategory.video,
      );

      final eventStream = _nostrService.subscribe([filter]);
      late StreamSubscription subscription;

      subscription = eventStream.listen(
        (event) {
          // Process events immediately as they arrive
          _handleNewVideoEvent(event, subscriptionType);
        },
        onError: (error) {
          Log.error(
            'Unlimited content query error: $error',
            name: 'VideoEventService',
            category: LogCategory.video,
          );
          subscription.cancel();
        },
        onDone: () {
          // Stream closed - don't wait for this to complete business logic
          Log.debug(
            'Unlimited content query stream closed',
            name: 'VideoEventService',
            category: LogCategory.video,
          );
          subscription.cancel();
        },
      );

      // Close subscription after timeout - events are processed immediately
      Timer(const Duration(seconds: 45), () {
        Log.debug(
          '⏰ Closing unlimited content query after 45s timeout',
          name: 'VideoEventService',
          category: LogCategory.video,
        );
        subscription.cancel();
      });

      // Return immediately - events will be processed as they arrive
      Log.debug(
        'Unlimited content query started, events will stream in',
        name: 'VideoEventService',
        category: LogCategory.video,
      );
    } catch (e) {
      _error = e.toString();
      Log.error(
        'Failed to load unlimited content: $e',
        name: 'VideoEventService',
        category: LogCategory.video,
      );

      if (_isConnectionError(e)) {
        Log.error(
          '📱 Unlimited content load failed due to connection error',
          name: 'VideoEventService',
          category: LogCategory.video,
        );
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
      Log.warning(
        'Cannot query video by ID - Nostr service not initialized',
        name: 'VideoEventService',
        category: LogCategory.video,
      );
      return null; // Defensive: Don't throw, just return null
    }

    Log.debug(
      'Querying for video with vine ID: $vineId',
      name: 'VideoEventService',
      category: LogCategory.video,
    );

    final completer = Completer<VideoEvent?>();
    VideoEvent? foundEvent;

    // Filter by the 'd' tag for addressable events
    final filter = Filter(
      kinds: NIP71VideoKinds.getAllVideoKinds(),
      d: [vineId], // Filter by the specific d tag value
      limit: 10, // Should only need one, but fetch a few in case
    );

    Log.debug(
      'Querying for videos, will filter for vine ID: $vineId',
      name: 'VideoEventService',
      category: LogCategory.video,
    );

    final eventStream = _nostrService.subscribe([filter]);
    late StreamSubscription subscription;
    // Held so every path that settles the completer can cancel it. A discarded
    // timer keeps its closure — and this subscription — alive for the full
    // timeout even once the query has already answered (#8457).
    Timer? timeoutTimer;

    subscription = eventStream.listen(
      (event) {
        try {
          final videoEvent = VideoEvent.fromNostrEvent(event);
          if (shouldHideVideo(videoEvent)) {
            return;
          }
          // Since we're filtering by d tag at the relay level, this should be our video
          Log.info(
            'Found video event for vine ID $vineId: ${event.id}',
            name: 'VideoEventService',
            category: LogCategory.video,
          );
          foundEvent = videoEvent;
          if (!completer.isCompleted) {
            completer.complete(foundEvent);
          }
          timeoutTimer?.cancel();
          subscription.cancel();
        } catch (e) {
          Log.error(
            'Error parsing video event: $e',
            name: 'VideoEventService',
            category: LogCategory.video,
          );
        }
      },
      onError: (error) {
        Log.error(
          'Error querying video by vine ID: $error',
          name: 'VideoEventService',
          category: LogCategory.video,
        );
        if (!completer.isCompleted) {
          completer.completeError(error as Object);
        }
        timeoutTimer?.cancel();
        subscription.cancel();
      },
      onDone: () {
        // Stream closed naturally - complete with result if not already completed
        Log.debug(
          'Vine ID query stream closed',
          name: 'VideoEventService',
          category: LogCategory.video,
        );
        if (!completer.isCompleted) {
          completer.complete(foundEvent);
        }
        timeoutTimer?.cancel();
        subscription.cancel();
      },
    );

    // Set timeout for the query - don't wait indefinitely
    timeoutTimer = Timer(const Duration(seconds: 10), () {
      if (!completer.isCompleted) {
        Log.debug(
          '⏰ Vine ID query timed out after 10 seconds',
          name: 'VideoEventService',
          category: LogCategory.video,
        );
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
      category: LogCategory.video,
    );

    // Log event list sizes for debugging
    for (final entry in _eventLists.entries) {
      Log.debug(
        '  - ${entry.key}: ${entry.value.length} videos',
        name: 'VideoEventService',
        category: LogCategory.video,
      );
    }

    // Detailed debug: show what hashtags are actually in the events
    int totalEventsChecked = 0;
    int eventsWithHashtags = 0;
    final allHashtagsSeen = <String>{};

    for (final events in _eventLists.values) {
      for (final event in events) {
        totalEventsChecked++;

        // Convert event hashtags to lowercase for comparison
        final eventHashtagsLower = event.hashtags
            .map((tag) => tag.toLowerCase())
            .toList();

        if (eventHashtagsLower.isNotEmpty) {
          eventsWithHashtags++;
          allHashtagsSeen.addAll(eventHashtagsLower);
        }

        // Check if event has any of the requested hashtags (case-insensitive)
        if (hashtagsLower.any(eventHashtagsLower.contains)) {
          // Use normalized ID for case-insensitive deduplication
          final normalizedEventId = event.id.toLowerCase();
          if (!seenIds.contains(normalizedEventId)) {
            seenIds.add(normalizedEventId);
            result.add(event);
            Log.debug(
              '  ✅ Match found: video ${event.id} has hashtags: $eventHashtagsLower',
              name: 'VideoEventService',
              category: LogCategory.video,
            );
          }
        }
      }
    }

    Log.debug(
      '📊 Hashtag search stats: checked $totalEventsChecked videos, $eventsWithHashtags had hashtags',
      name: 'VideoEventService',
      category: LogCategory.video,
    );
    Log.debug(
      '📊 All unique hashtags seen: ${allHashtagsSeen.take(20).join(", ")}${allHashtagsSeen.length > 20 ? "... (${allHashtagsSeen.length} total)" : ""}',
      name: 'VideoEventService',
      category: LogCategory.video,
    );
    Log.debug(
      '✅ Found ${result.length} videos with hashtags: $hashtagsLower',
      name: 'VideoEventService',
      category: LogCategory.video,
    );

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
        category: LogCategory.video,
      );
      for (final subscriptionId in _activeSubscriptionIds) {
        await _subscriptionManager.cancelSubscription(subscriptionId);
      }
      _activeSubscriptionIds.clear();
    }

    // Cancel direct subscriptions
    if (_subscriptions.isNotEmpty) {
      Log.debug(
        'Cancelling ${_subscriptions.length} direct subscriptions...',
        name: 'VideoEventService',
        category: LogCategory.video,
      );
      for (final entry in _subscriptions.entries) {
        _completeAbandonedFeedLoadTrace(entry.key, 'cancelled');
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

      Log.info(
        'Successfully unsubscribed from all video events',
        name: 'VideoEventService',
        category: LogCategory.video,
      );
    } catch (e) {
      Log.error(
        'Error unsubscribing from video events: $e',
        name: 'VideoEventService',
        category: LogCategory.video,
      );
    }
  }

  /// Get video events sorted by engagement (placeholder - would need reaction events)
  List<VideoEvent> getVideoEventsByEngagement() {
    // For now, just return chronologically sorted
    // In a full implementation, would sort by likes, comments, shares, etc.
    final allEvents = <VideoEvent>[];
    _eventLists.values.forEach(allEvents.addAll);
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

  /// Search all event lists for a video matching pubkey and d-tag
  VideoEvent? _findCachedVideoByAddressable(String pubkey, String dTag) {
    for (final events in _eventLists.values) {
      final match = events
          .where((v) => v.pubkey == pubkey && v.rawTags['d'] == dTag)
          .firstOrNull;
      if (match != null) return match;
    }
    return null;
  }

  /// Merges an incoming [updatedVideo] (parsed from a freshly published Nostr
  /// event) with the [existingVideo] already held in the service, carrying
  /// forward fields that are not stored in Nostr event tags and therefore
  /// cannot survive a round-trip through [VideoEvent.fromNostrEvent].
  ///
  /// **Timestamp preservation** — when neither version has a `published_at`
  /// tag (common for classic Vine imports), the original `createdAt` /
  /// `timestamp` values are kept so the video retains its chronological
  /// position in feeds.
  ///
  /// **Runtime like-count carry-forward** — [VideoEvent.nostrLikeCount] is
  /// injected at runtime after a relay batch query; it is never written into
  /// the Nostr event body.  Without this carry-forward a metadata edit (e.g.
  /// changing hashtags) drops the displayed count to zero until the next
  /// batch re-fetch completes.  The relay-fetched count will overwrite this
  /// carried value once the batch fires, so there is no risk of a stale
  /// count persisting indefinitely.
  VideoEvent _mergeUpdatedVideo(
    VideoEvent existingVideo,
    VideoEvent updatedVideo,
  ) {
    var merged =
        (existingVideo.publishedAt == null && updatedVideo.publishedAt == null)
        ? updatedVideo.copyWith(
            createdAt: existingVideo.createdAt,
            timestamp: existingVideo.timestamp,
          )
        : updatedVideo;

    if (merged.nostrLikeCount == null && existingVideo.nostrLikeCount != null) {
      merged = merged.copyWith(nostrLikeCount: existingVideo.nostrLikeCount);
    }

    return merged;
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

  bool _hasConnectedRelay(Map<String, RelayConnectionStatus> statuses) {
    return statuses.values.any((status) => status.isConnected);
  }

  /// Schedule retry of [subscriptionType] when at least one relay reconnects.
  ///
  /// This is intentionally separate from [FeedRetryScheduler.scheduleWhenOnline]: the device
  /// can have network connectivity while every Nostr relay is disconnected.
  void _scheduleRetryWhenRelayReady(SubscriptionType subscriptionType) {
    _typesAwaitingRelayReady.add(subscriptionType);

    if (_nostrService.connectedRelayCount > 0) {
      _retrySubscriptionsAwaitingRelayReady();
      return;
    }

    if (_relayReadyRetrySubscription != null) return;

    // Deliberately event-bounded rather than attempt-bounded: pending types are
    // enum-bounded, and each retry is triggered only by a relay status update.
    // A hard cap here can leave a feed dead forever after relay flapping.
    _relayReadyRetrySubscription = _nostrService.relayStatusStream.listen((
      statuses,
    ) {
      if (_hasConnectedRelay(statuses)) {
        _retrySubscriptionsAwaitingRelayReady();
      }
    });
  }

  void _retrySubscriptionsAwaitingRelayReady() {
    final pendingTypes = Set<SubscriptionType>.of(_typesAwaitingRelayReady);
    _typesAwaitingRelayReady.clear();
    _cancelRelayReadyRetrySubscription();

    if (pendingTypes.isEmpty) {
      return;
    }

    Log.warning(
      'Retrying video subscriptions after relay connection restored: '
      '${pendingTypes.map((type) => type.name).join(", ")}',
      name: 'VideoEventService',
      category: LogCategory.video,
    );

    for (final type in pendingTypes) {
      unawaited(
        _resubscribeWithStoredParams(type)
            .then((_) {
              Log.info(
                'Successfully resubscribed to ${type.name} feed after relay reconnect',
                name: 'VideoEventService',
                category: LogCategory.video,
              );
            })
            .catchError((Object e) {
              Log.error(
                'Relay-ready retry for ${type.name} failed: $e',
                name: 'VideoEventService',
                category: LogCategory.video,
              );
              if (e is RelayNotReadyException) {
                _scheduleRetryWhenRelayReady(type);
              }
            }),
      );
    }
  }

  void _cancelRelayReadyRetrySubscription() {
    unawaited(_relayReadyRetrySubscription?.cancel());
    _relayReadyRetrySubscription = null;
  }

  Future<void> _resubscribeWithStoredParams(SubscriptionType type) {
    final params = _subscriptionParams[type];
    return subscribeToVideoFeed(
      subscriptionType: type,
      authors: params?['authors'] as List<String>?,
      hashtags: params?['hashtags'] as List<String>?,
      group: params?['group'] as String?,
      since: params?['since'] as int?,
      until: params?['until'] as int?,
      limit: (params?['limit'] as int?) ?? 200,
      includeReposts: (params?['includeReposts'] as bool?) ?? false,
      sortBy: params?['sortBy'] as VideoSortField?,
      nip50Sort: params?['nip50Sort'] as NIP50SortMode?,
      force: true,
      scheduleOnlineRetry: false,
    );
  }

  /// Get connection status for debugging
  Map<String, dynamic> getConnectionStatus() => {
    'activeSubscriptions': _activeSubscriptions.keys
        .map((e) => e.name)
        .toList(),
    'subscriptionCounts': Map.fromEntries(
      SubscriptionType.values.map(
        (type) => MapEntry(type.name, getEventCount(type)),
      ),
    ),
    'isLoading': _isLoading,
    'retryAttempts': _retryScheduler.attempts,
    'hasError': _error != null,
    'lastError': _error,
    'connectionInfo': _connectionService.getConnectionInfo(),
  };

  /// Force retry subscription
  Future<void> retrySubscription() async {
    Log.warning(
      'Forcing retry of video feed subscription...',
      name: 'VideoEventService',
      category: LogCategory.video,
    );
    _retryScheduler.resetBudgets();
    _error = null;

    try {
      await subscribeToVideoFeed(subscriptionType: SubscriptionType.discovery);
    } catch (e) {
      Log.error(
        'Manual retry failed: $e',
        name: 'VideoEventService',
        category: LogCategory.video,
      );
      rethrow;
    }
  }

  /// Ensure default content is available for new users
  void _ensureDefaultContent() {
    // DISABLED: Default video system disabled due to loading issues
    // The default video was not loading properly and causing user experience issues
    Log.warning(
      'Default video system is disabled - users will see real content only',
      name: 'VideoEventService',
      category: LogCategory.video,
    );
    return;
  }

  /// Add video to specific subscription list
  void _addVideoToSubscription(
    VideoEvent videoEvent,
    SubscriptionType subscriptionType, {
    bool isHistorical = false,
  }) {
    // CRITICAL: Filter out known deleted videos to prevent pagination resurrection.
    if (isVideoEventKnownDeleted(videoEvent)) {
      Log.debug(
        'Filtering out known deleted video ${videoEvent.id} from $subscriptionType feed',
        name: 'VideoEventService',
        category: LogCategory.video,
      );
      return; // Don't resurrect deleted videos
    }

    // Filter out videos confirmed unavailable so they don't resurface on any
    // list surface after being skipped in the player. See #5237 / #6251.
    if (_brokenVideoTracker?.isVideoBroken(videoEvent.id) == true) {
      Log.debug(
        'Filtering out confirmed-unavailable video ${videoEvent.id} from $subscriptionType feed',
        name: 'VideoEventService',
        category: LogCategory.video,
      );
      return;
    }

    // NIP-40: Filter out expired events
    if (videoEvent.isExpired) {
      Log.debug(
        'Filtering out expired video ${videoEvent.id} from $subscriptionType feed (expired: ${videoEvent.expirationTimestamp})',
        name: 'VideoEventService',
        category: LogCategory.video,
      );
      return; // Don't add expired events per NIP-40
    }

    // Filter blocked users (centralized check for all subscription types)
    if (_blocklistRepository?.shouldFilterFromFeeds(videoEvent.pubkey) ==
        true) {
      Log.verbose(
        'Filtering blocked content from ${pubkeyForLogs(videoEvent.pubkey)} in $subscriptionType',
        name: 'VideoEventService',
        category: LogCategory.video,
      );
      return; // Don't show content from blocked users
    }

    if (shouldHideVideo(videoEvent)) {
      Log.verbose(
        'Filtering hidden video ${videoEvent.id} from $subscriptionType',
        name: 'VideoEventService',
        category: LogCategory.video,
      );
      return;
    }

    // CRITICAL: Validate that video has an accessible URL before adding to feed
    if (!_hasValidVideoUrl(videoEvent)) {
      Log.warning(
        'Rejecting $subscriptionType video ${videoEvent.id} - no valid video URL (url: ${videoEvent.videoUrl})',
        name: 'VideoEventService',
        category: LogCategory.video,
      );
      return; // Don't add videos without valid URLs
    }

    final eventList = _eventLists[subscriptionType];
    if (eventList == null) {
      Log.error(
        'Invalid subscription type: $subscriptionType',
        name: 'VideoEventService',
        category: LogCategory.video,
      );
      return;
    }

    // REPOST CONSOLIDATION: Check if this is a repost of an existing video
    // Use case-insensitive comparison for ID matching
    if (videoEvent.isRepost) {
      final repostNormalizedId = videoEvent.id.toLowerCase();
      final existingVideoIndex = eventList.indexWhere(
        (existing) => existing.id.toLowerCase() == repostNormalizedId,
      );

      if (existingVideoIndex != -1) {
        // Found existing video (either original or another repost of same video)
        final existingVideo = eventList[existingVideoIndex];

        // Get the new reposter's pubkey
        final newReposter = videoEvent.reposterPubkey;
        if (newReposter != null) {
          // Get existing reposters list (or create from reposterPubkey if null)
          final existingReposters =
              existingVideo.reposterPubkeys ??
              (existingVideo.reposterPubkey != null
                  ? [existingVideo.reposterPubkey!]
                  : <String>[]);

          // Check if this reposter already exists (avoid duplicates)
          if (!existingReposters.contains(newReposter)) {
            // Add new reposter to the list
            final updatedReposters = [...existingReposters, newReposter];

            // Update the video with the new consolidated reposter list
            // CRITICAL: Must set both reposterPubkey (singular, for backward compat/UI)
            // and reposterPubkeys (plural, for multiple reposters)
            // The singular reposterPubkey is used by VideoFeedItem to show the repost header
            final consolidatedVideo = existingVideo.copyWith(
              reposterPubkey:
                  updatedReposters.first, // First reposter for header display
              reposterPubkeys: updatedReposters,
              // Keep the original repost metadata (reposterId, repostedAt) from first reposter
              isRepost: true,
            );

            // Replace the existing video with consolidated version
            eventList[existingVideoIndex] = consolidatedVideo;

            Log.info(
              'Consolidated repost: ${videoEvent.id} now has ${updatedReposters.length} reposters: ${updatedReposters.join(", ")}',
              name: 'VideoEventService',
              category: LogCategory.video,
            );

            // Notify listeners of the update
            notifyListeners();
          } else {
            Log.debug(
              'Skipping duplicate repost from same user: $newReposter already reposted ${videoEvent.id}',
              name: 'VideoEventService',
              category: LogCategory.video,
            );
          }
        }

        return; // Don't add as separate video - we've consolidated it
      }
    }

    // Check for duplicates within this subscription type using case-insensitive comparison
    final normalizedId = videoEvent.id.toLowerCase();
    final existingIndex = eventList.indexWhere(
      (existing) => existing.id.toLowerCase() == normalizedId,
    );
    if (existingIndex != -1) {
      _duplicateVideoEventCount++;
      _logDuplicateVideoEventsAggregated();
      return; // Don't add duplicate events
    }

    // Fetch profile for video author if not already cached (fire-and-forget)
    if (_profileRepository != null) {
      unawaited(_fetchProfileIfMissing(videoEvent.pubkey));
    }

    // Fetch live Nostr like count for this video (fire-and-forget)
    // This enriches the video with current reaction count from relays
    if (_likesRepository != null) {
      _fetchAndUpdateLikeCount(videoEvent, subscriptionType);
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

      case SubscriptionType.popularNow:
        // Chronological feed: live → newest-first, historical → append.
        // Relay batch order alone is not trustworthy.
        if (isHistorical) {
          eventList.add(videoEvent);
        } else {
          eventList.insert(0, videoEvent);
        }

      case SubscriptionType.editorial:
      case SubscriptionType.trending:
        // Editorial/trending: maintain order from server (always append)
        eventList.add(videoEvent);
    }

    // Populate keyed buckets for route-aware feeds
    if (subscriptionType == SubscriptionType.hashtag) {
      // Add video to each of its hashtag buckets
      Log.info(
        '🏷️📦 Adding hashtag event to buckets: id=${videoEvent.id}, hashtags=${videoEvent.hashtags.join(", ")}',
        name: 'VideoEventService',
        category: LogCategory.video,
      );

      for (final tag in videoEvent.hashtags) {
        final bucket = _hashtagBuckets.putIfAbsent(tag, () => []);
        // Use case-insensitive ID matching to prevent duplicates
        final videoIdLower = videoEvent.id.toLowerCase();
        final wasAdded = !bucket.any((e) => e.id.toLowerCase() == videoIdLower);
        if (wasAdded) {
          if (isHistorical) {
            bucket.add(videoEvent);
          } else {
            bucket.insert(0, videoEvent);
          }
          Log.info(
            '🏷️✅ Added to bucket "$tag" (now has ${bucket.length} videos)',
            name: 'VideoEventService',
            category: LogCategory.video,
          );
        } else {
          Log.info(
            '🏷️⏭️ Skipped duplicate for bucket "$tag"',
            name: 'VideoEventService',
            category: LogCategory.video,
          );
        }
      }
    } else if (subscriptionType == SubscriptionType.profile) {
      // Add video to author's bucket
      // For reposts, use reposter's pubkey instead of original author's pubkey
      final authorHex = videoEvent.isRepost && videoEvent.reposterPubkey != null
          ? videoEvent.reposterPubkey!
          : videoEvent.pubkey;
      _addToAuthorBucket(videoEvent, authorHex, isHistorical: isHistorical);
    }

    if (subscriptionType != SubscriptionType.profile) {
      final currentUserPubkey = _nostrService.publicKey;
      // Determine the author for bucket assignment (reposter for reposts)
      final authorHex = videoEvent.isRepost && videoEvent.reposterPubkey != null
          ? videoEvent.reposterPubkey!
          : videoEvent.pubkey;

      // Add to current user's bucket (for own profile)
      if (currentUserPubkey.isNotEmpty && authorHex == currentUserPubkey) {
        _addToAuthorBucket(videoEvent, authorHex, isHistorical: isHistorical);
      }

      // Cross-populate author bucket for OTHER users whose profiles were viewed.
      // This ensures profile views stay up-to-date when videos arrive later
      // in discovery/home feeds (fixes stale 0-video profile state).
      if (authorHex != currentUserPubkey &&
          _authorBuckets.contains(authorHex)) {
        _addToAuthorBucket(videoEvent, authorHex, isHistorical: isHistorical);
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

    // Log.debug(
    //     '✅ Added $subscriptionType video: ${videoEvent.title ?? videoEvent.id} (total: ${eventList.length})',
    //     name: 'VideoEventService',
    //     category: LogCategory.video);

    _notifyVideoObservers([videoEvent]);

    // Schedule frame-based UI update for progressive loading
    _scheduleFrameUpdate();
  }

  /// Fetches and caches a profile only if it isn't already in the local cache.
  Future<void> _fetchProfileIfMissing(String pubkey) async {
    try {
      final cached = await _profileRepository!.getCachedProfile(pubkey: pubkey);
      if (cached != null) return;
      await _profileRepository.fetchFreshProfile(pubkey: pubkey);
    } catch (e) {
      Log.warning(
        'Failed to fetch profile for ${pubkeyForLogs(pubkey)}: $e',
        name: 'VideoEventService',
        category: LogCategory.video,
      );
    }
  }

  /// Queue a video for batched like count fetching.
  /// This is called fire-and-forget when a video is added to a subscription.
  /// Batches multiple requests to prevent ANR from too many concurrent queries.
  void _fetchAndUpdateLikeCount(
    VideoEvent videoEvent,
    SubscriptionType subscriptionType,
  ) {
    if (_likesRepository == null) return;

    // Add to pending batch
    _pendingLikeCountVideoIds[videoEvent.id] = subscriptionType;

    // Track addressable ID so the batch fetch can also query by 'a' tag.
    // This ensures reactions on any version of a replaced video (e.g. after a
    // metadata edit that changes the event ID) are included in the count.
    // Preserve the addressable identity alongside the current event ID so the
    // batch can count reactions across edited versions of the same video.
    final addressableId = videoEvent.addressableId;
    if (addressableId != null) {
      _pendingLikeCountAddressableIds[videoEvent.id] = addressableId;
    }

    // Cancel existing timer
    _likeCountBatchTimer?.cancel();

    // If batch is full, execute immediately
    if (_pendingLikeCountVideoIds.length >= _likeCountBatchMaxSize) {
      _executeLikeCountBatchFetch();
      return;
    }

    // Otherwise, debounce to accumulate more requests
    _likeCountBatchTimer = Timer(
      _likeCountBatchDebounce,
      _executeLikeCountBatchFetch,
    );
  }

  /// Execute the batched like count fetch for all pending videos.
  Future<void> _executeLikeCountBatchFetch() async {
    if (_pendingLikeCountVideoIds.isEmpty || _likesRepository == null) return;

    // Move pending to current batch
    final batch = Map<String, SubscriptionType>.from(_pendingLikeCountVideoIds);
    // Snapshot the companion addressable IDs with the same batch boundary as
    // the event IDs so the relay query stays consistent.
    final addressableIds = Map<String, String>.from(
      _pendingLikeCountAddressableIds,
    );
    _pendingLikeCountVideoIds.clear();
    _pendingLikeCountAddressableIds.clear();
    _likeCountBatchTimer?.cancel();

    final videoIds = batch.keys.toList();

    Log.verbose(
      '📊 Fetching like counts for ${videoIds.length} videos in batch',
      name: 'VideoEventService',
      category: LogCategory.video,
    );

    try {
      // Fetch like counts via both 'e' tag (event ID) and 'a' tag (addressable
      // ID). The 'a' tag query catches reactions on any previous version of the
      // video so counts stay accurate after a metadata update.
      final likeCounts = await _likesRepository!.getLikeCounts(
        videoIds,
        addressableIds: addressableIds.isEmpty ? null : addressableIds,
      );

      // Apply counts to each video
      var updatedCount = 0;
      for (final entry in likeCounts.entries) {
        final videoId = entry.key;
        final likeCount = entry.value;

        // Skip if count is 0 (no change from default)
        if (likeCount == 0) continue;

        final subscriptionType = batch[videoId];
        if (subscriptionType == null) continue;

        if (_applyLikeCountToVideo(videoId, likeCount, subscriptionType)) {
          updatedCount++;
        }
      }

      // Schedule a single frame update for all changes
      if (updatedCount > 0) {
        _scheduleFrameUpdate();
        Log.verbose(
          '📊 Updated like counts for $updatedCount videos',
          name: 'VideoEventService',
          category: LogCategory.video,
        );
      }
    } catch (e) {
      // Silently ignore errors - like count is non-critical
      Log.verbose(
        'Failed to fetch batched like counts: $e',
        name: 'VideoEventService',
        category: LogCategory.video,
      );
    }
  }

  /// Apply a like count to a video in all relevant lists.
  /// Returns true if the video was found and updated.
  bool _applyLikeCountToVideo(
    String videoId,
    int likeCount,
    SubscriptionType subscriptionType,
  ) {
    // Find and update the video in the event list
    final eventList = _eventLists[subscriptionType];
    if (eventList == null) return false;

    final index = eventList.indexWhere((v) => v.id == videoId);
    if (index == -1) return false; // Video no longer in list

    final videoEvent = eventList[index];

    // Direct-replace, not max-merge: unlike the archival originalLikes /
    // originalLoops / originalComments / originalReposts fields (fixed
    // values baked into event tags, safe to merge with #3384's
    // mergeNullableEngagementMax), nostrLikeCount is a live relay-derived
    // count that legitimately decreases — e.g. after the user's own unlike
    // decrements LikesRepository's count cache, or a reaction is deleted.
    // A max-merge here would ratchet this cache's value up across every
    // future re-application (this video re-entering another subscription
    // bucket, a later batch, etc.) and permanently block that self-
    // correction. #6022's addressable floor doesn't need protection at this
    // layer: it's already a correctly-scoped, one-time comparison in
    // VideoInteractionsBloc._onFetchRequested between the feed seed and a
    // fresh relay resolve, independent of this cache (#6102 review).
    final updatedVideo = videoEvent.copyWith(nostrLikeCount: likeCount);
    eventList[index] = updatedVideo;

    // Also update in keyed buckets if applicable
    if (subscriptionType == SubscriptionType.hashtag) {
      for (final tag in videoEvent.hashtags) {
        final bucket = _hashtagBuckets[tag];
        if (bucket != null) {
          final bucketIndex = bucket.indexWhere((v) => v.id == videoId);
          if (bucketIndex != -1) {
            bucket[bucketIndex] = updatedVideo;
          }
        }
      }
    } else if (subscriptionType == SubscriptionType.profile) {
      final authorHex = videoEvent.isRepost && videoEvent.reposterPubkey != null
          ? videoEvent.reposterPubkey!
          : videoEvent.pubkey;
      _authorBuckets.replaceById(authorHex, videoId, updatedVideo);
    }

    return true;
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
          category: LogCategory.video,
        );
      }

      _lastDuplicateVideoLogTime = now;
      _duplicateVideoEventCount = 0;
    }
  }

  /// Add a video to the author's bucket for profile feeds.
  /// Returns true if the video was added (new), false if it was a duplicate or update.
  bool _addToAuthorBucket(
    VideoEvent videoEvent,
    String authorHex, {
    required bool isHistorical,
  }) => _authorBuckets.addOrUpdateByVine(
    videoEvent,
    authorPubkey: authorHex,
    isHistorical: isHistorical,
  );

  /// Check if the given subscription parameters match the current active subscription for this type
  bool _isDuplicateSubscription(
    SubscriptionType subscriptionType,
    List<String>? authors,
    List<String>? hashtags,
    String? group,
    int limit,
    int? since,
    int? until, {
    bool includeReposts = false,
  }) {
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

  void _cancelFeedLoadTimeout(SubscriptionType subscriptionType) {
    _feedLoadTimeouts.remove(subscriptionType)?.cancel();
  }

  /// Closes the feed-load trace of a subscription that is being torn down
  /// before its load reached a completion path, reporting it as [completion].
  ///
  /// Reporting here rather than at [dispose] keeps the duration the load's
  /// own: the 30s fuse is cancelled on teardown and its handler bails out on
  /// a replaced subscription, so an abandoned load would otherwise stay open
  /// until the process ends and report a session-length sample (#7151).
  void _completeAbandonedFeedLoadTrace(
    String subscriptionId,
    String completion,
  ) {
    _pendingFeedLoadTraces.remove(subscriptionId)?.complete(completion);
  }

  /// Cancel subscription for a specific type
  Future<void> _cancelSubscription(SubscriptionType subscriptionType) async {
    // Kill the fuse before tearing down state so a later fire cannot unmap a
    // replacement subscription or schedule a retry for a feed the user left.
    _cancelFeedLoadTimeout(subscriptionType);

    final subscriptionId = _activeSubscriptions[subscriptionType];
    if (subscriptionId != null) {
      Log.info(
        '🛑 Cancelling $subscriptionType subscription: $subscriptionId',
        name: 'VideoEventService',
        category: LogCategory.video,
      );

      _completeAbandonedFeedLoadTrace(subscriptionId, 'cancelled');

      final subscription = _subscriptions[subscriptionId];
      if (subscription != null) {
        try {
          // Cancel the stream subscription - this should trigger onCancel in NostrService
          await subscription.cancel();
          Log.info(
            '✅ Successfully cancelled stream subscription for $subscriptionType',
            name: 'VideoEventService',
            category: LogCategory.video,
          );
        } catch (e) {
          Log.error(
            '❌ Error cancelling stream subscription: $e',
            name: 'VideoEventService',
            category: LogCategory.video,
          );
        }
        _subscriptions.remove(subscriptionId);
      } else {
        Log.warning(
          '⚠️ No stream subscription found for $subscriptionId',
          name: 'VideoEventService',
          category: LogCategory.video,
        );
      }

      _activeSubscriptions.remove(subscriptionType);
      _subscriptionParams.remove(subscriptionType);

      // NOTE: We intentionally DO NOT clear the event list here
      // Reason: Force refresh with same parameters should preserve existing videos
      // The deduplication system (seenEventIds) prevents duplicates automatically
      // Clearing would cause UI to show empty feed until new events arrive
      // If we truly need a fresh list (e.g., switching feeds), create a new SubscriptionType

      // Clear hashtag and group filters
      _activeHashtagFilters.remove(subscriptionType);
      _activeGroupFilters.remove(subscriptionType);

      // Proceed immediately; rely on relay/stream guarantees instead of sleeps
      Log.info(
        '✅ Finished cancelling $subscriptionType subscription',
        name: 'VideoEventService',
        category: LogCategory.video,
      );
    } else {
      Log.debug(
        'No active subscription to cancel for $subscriptionType',
        name: 'VideoEventService',
        category: LogCategory.video,
      );
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

    Log.info(
      '🔄 Scheduling reconnection for $subscriptionType subscription',
      name: 'VideoEventService',
      category: LogCategory.video,
    );

    // Wait 5 seconds before attempting reconnection
    Timer(const Duration(seconds: 5), () {
      if (!isSubscribed(subscriptionType) &&
          _subscriptionParams.containsKey(subscriptionType)) {
        Log.info(
          '🔄 Attempting to reconnect $subscriptionType subscription',
          name: 'VideoEventService',
          category: LogCategory.video,
        );

        subscribeToVideoFeed(
          subscriptionType: subscriptionType,
          authors: params['authors'] as List<String>?,
          hashtags: params['hashtags'] as List<String>?,
          group: params['group'] as String?,
          since: params['since'] as int?,
          until: params['until'] as int?,
          limit: params['limit'] as int? ?? 50,
        ).catchError((e) {
          Log.error(
            'Failed to reconnect $subscriptionType subscription: $e',
            name: 'VideoEventService',
            category: LogCategory.video,
          );
        });
      }
    });
  }

  /// Sort video list using enhanced engagement metrics
  void _sortByEngagement(
    List<VideoEvent> eventList,
    SubscriptionType subscriptionType,
  ) {
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

  /// Report empty feed condition to Crashlytics with full diagnostic context
  void _reportEmptyFeedToCrashlytics({
    required SubscriptionType subscriptionType,
    required List<Filter> filters,
    required Duration eoseDuration,
    required bool relayConnected,
    required bool isOnline,
  }) {
    try {
      // Build comprehensive error context
      final context = StringBuffer();
      context.writeln('=== EMPTY FEED DIAGNOSTIC ===');
      context.writeln('Subscription Type: ${subscriptionType.name}');
      context.writeln('EOSE Duration: ${eoseDuration.inMilliseconds}ms');
      context.writeln('Relay Connected: $relayConnected');
      context.writeln('Network Online: $isOnline');
      context.writeln(
        'Connected Relay Count: ${_nostrService.connectedRelayCount}',
      );
      context.writeln();
      context.writeln('Filters:');
      for (var i = 0; i < filters.length; i++) {
        final filter = filters[i];
        context.writeln('  Filter $i:');
        context.writeln('    Kinds: ${filter.kinds}');
        context.writeln('    Authors: ${filter.authors?.length ?? 0} authors');
        if (filter.authors != null && filter.authors!.isNotEmpty) {
          context.writeln('    First author: ${filter.authors!.first}');
        }
        context.writeln('    Tags: ${filter.t?.length ?? 0} tags');
        context.writeln('    Since: ${filter.since}');
        context.writeln('    Until: ${filter.until}');
        context.writeln('    Limit: ${filter.limit}');
      }
      context.writeln();
      context.writeln('Current State:');
      context.writeln(
        '  Total videos in feed: ${getVideos(subscriptionType).length}',
      );
      context.writeln(
        '  Is loading: ${isLoadingForSubscription(subscriptionType)}',
      );
      context.writeln('  Has subscription: ${isSubscribed(subscriptionType)}');

      // Log locally — this is a normal condition (new user, sparse relay, etc.)
      // so we log as warning instead of flooding Crashlytics with non-fatal errors.
      Log.warning(
        '⚠️ EMPTY FEED for ${subscriptionType.name}:\n$context',
        name: 'VideoEventService',
        category: LogCategory.video,
      );

      // Set custom keys for filtering if needed later
      _crashReporter.setCustomKey(
        'last_empty_feed_type',
        subscriptionType.name,
      );
      _crashReporter.setCustomKey(
        'last_empty_feed_relay_connected',
        relayConnected.toString(),
      );
      _crashReporter.setCustomKey(
        'last_empty_feed_online',
        isOnline.toString(),
      );
      _crashReporter.setCustomKey(
        'last_empty_feed_duration_ms',
        eoseDuration.inMilliseconds.toString(),
      );
    } catch (e) {
      Log.error(
        'Failed to report empty feed to Crashlytics: $e',
        name: 'VideoEventService',
        category: LogCategory.video,
      );
    }
  }

  /// Report feed loading timeout to Crashlytics with full diagnostic context
  void _reportFeedLoadingTimeout({
    required SubscriptionType subscriptionType,
    required List<Filter> filters,
    required Duration duration,
    required bool relayConnected,
    required bool isOnline,
  }) {
    try {
      // Build comprehensive error context
      final context = StringBuffer();
      context.writeln('=== FEED LOADING TIMEOUT DIAGNOSTIC ===');
      context.writeln('Subscription Type: ${subscriptionType.name}');
      context.writeln('Timeout Duration: ${duration.inMilliseconds}ms');
      context.writeln('Relay Connected: $relayConnected');
      context.writeln('Network Online: $isOnline');
      context.writeln(
        'Connected Relay Count: ${_nostrService.connectedRelayCount}',
      );
      context.writeln();
      context.writeln('Filters:');
      for (var i = 0; i < filters.length; i++) {
        final filter = filters[i];
        context.writeln('  Filter $i:');
        context.writeln('    Kinds: ${filter.kinds}');
        context.writeln('    Authors: ${filter.authors?.length ?? 0} authors');
        if (filter.authors != null && filter.authors!.isNotEmpty) {
          context.writeln('    First author: ${filter.authors!.first}');
        }
        context.writeln('    Tags: ${filter.t?.length ?? 0} tags');
        context.writeln('    Since: ${filter.since}');
        context.writeln('    Until: ${filter.until}');
        context.writeln('    Limit: ${filter.limit}');
      }
      context.writeln();
      context.writeln('Current State:');
      context.writeln(
        '  Total videos in feed: ${getVideos(subscriptionType).length}',
      );
      context.writeln(
        '  Is loading: ${isLoadingForSubscription(subscriptionType)}',
      );
      context.writeln('  Has subscription: ${isSubscribed(subscriptionType)}');
      context.writeln();
      // Add detailed relay connection diagnostics
      context.writeln('Relay Connection Details:');
      try {
        final relayStatuses = _nostrService.relayStatuses;
        for (final entry in relayStatuses.entries) {
          final status = entry.value;
          context.writeln('  ${status.url}:');
          context.writeln('    State: ${status.state.name}');
          if (status.lastConnectedAt != null) {
            final timeSinceConnect = DateTime.now().difference(
              status.lastConnectedAt!,
            );
            context.writeln(
              '    Last connected: ${timeSinceConnect.inSeconds}s ago',
            );
          }
          if (status.lastErrorAt != null) {
            final timeSinceError = DateTime.now().difference(
              status.lastErrorAt!,
            );
            context.writeln('    Last error: ${timeSinceError.inSeconds}s ago');
          }
          if (status.errorCount > 0) {
            context.writeln('    Error count: ${status.errorCount}');
          }
          if (status.errorMessage != null) {
            context.writeln('    Error message: ${status.errorMessage}');
          }
        }
      } catch (e) {
        context.writeln('  Failed to get relay statuses: $e');
      }
      context.writeln();

      context.writeln('Likely Causes:');
      if (!relayConnected) {
        context.writeln('  ❌ RELAY CONNECTION FAILURE - No relays connected!');
      }
      if (!isOnline) {
        context.writeln(
          '  ❌ NETWORK OFFLINE - Device has no internet connection',
        );
      }
      if (relayConnected && isOnline) {
        context.writeln(
          '  ⚠️ Possible stale WebSocket - relay shows connected but may be dead',
        );
        context.writeln(
          '  ⚠️ Check if app was recently resumed from background',
        );
        context.writeln('  ⚠️ Filter may match no events on this relay');
      }

      // Log locally — timeouts are expected on slow networks, backgrounded apps,
      // etc. Log as warning instead of flooding Crashlytics with non-fatal errors.
      Log.warning(
        '⏰ FEED TIMEOUT for ${subscriptionType.name}:\n$context',
        name: 'VideoEventService',
        category: LogCategory.video,
      );

      // Set custom keys for filtering if needed later
      _crashReporter.setCustomKey(
        'last_timeout_feed_type',
        subscriptionType.name,
      );
      _crashReporter.setCustomKey(
        'last_timeout_relay_connected',
        relayConnected.toString(),
      );
      _crashReporter.setCustomKey(
        'last_timeout_online',
        isOnline.toString(),
      );
      _crashReporter.setCustomKey(
        'last_timeout_duration_ms',
        duration.inMilliseconds.toString(),
      );
    } catch (e) {
      Log.error(
        'Failed to report timeout to Crashlytics: $e',
        name: 'VideoEventService',
        category: LogCategory.video,
      );
    }
  }

  // Track whether the service has been disposed
  bool _isDisposed = false;

  @override
  void dispose() {
    _isDisposed = true;

    for (final timer in _feedLoadTimeouts.values) {
      timer.cancel();
    }
    _feedLoadTimeouts.clear();

    // Loads still mid-setup have no subscription to tear down, so the sweep
    // in _cancelExistingSubscriptions below cannot reach them.
    for (final trace in _pendingFeedLoadTraces.values) {
      trace.complete('disposed');
    }
    _pendingFeedLoadTraces.clear();
    _retryScheduler.dispose();
    _cancelRelayReadyRetrySubscription();
    _likeCountBatchTimer?.cancel();
    _authStateSubscription?.cancel();
    unawaited(_blocklistChangesSubscription?.cancel());
    if (_ownsConnectionService) {
      _connectionService.dispose();
    }
    unsubscribeFromVideoFeed();
    unawaited(_removedVideoIdsController.close());
    super.dispose();
  }

  /// Sanitizes event tags for log output: redacts sensitive tag values and
  /// truncates long parts to keep log lines manageable.
  String _formatEventTagsForLog(List<List<String>> tags) {
    return tags.map(sanitizeTagForLog).toList(growable: false).toString();
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
    final parts = <String>['type:${subscriptionType.name}'];

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
      Log.debug(
        '📱 Shuffling videos for discovery mode...',
        name: 'VideoEventService',
        category: LogCategory.video,
      );

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

        Log.info(
          'Shuffled ${regularVideos.length} videos for discovery',
          name: 'VideoEventService',
          category: LogCategory.video,
        );
      }
    }
  }

  /// Add a video event to the cache (for external services like CurationRepository)
  @override
  void addVideoEvent(VideoEvent videoEvent) {
    _addVideoToSubscription(videoEvent, SubscriptionType.discovery);
  }

  /// Update a video event (for addressable events with same pubkey/d-tag).
  ///
  /// This method replaces an existing video across all data structures:
  /// - `_eventLists` (all subscription types: homeFeed, discovery, etc.)
  /// - `_authorBuckets` (used by profile feeds)
  /// - `_replaceableVideoEvents` tracking map
  ///
  /// After updating, callers should refresh any StateProviders that hold
  /// their own copies of video lists (e.g., `exploreTabVideosProvider`).
  ///
  /// Providers that watch VideoEventService (via `ref.watch()` or `addListener()`)
  /// will automatically rebuild when `notifyListeners()` is called, but those
  /// with cached state (like `profileFeedProvider`, `homeFeedProvider`) need
  /// explicit `refreshFromService()` calls.
  ///
  void updateVideoEvent(VideoEvent updatedVideo) {
    bool foundAny = false;

    // Find and replace in all subscription types
    for (final entry in _eventLists.entries) {
      final subscriptionType = entry.key;
      final eventList = entry.value;

      // Find by stable identifier and pubkey instead of event.id.
      // For addressable events, (pubkey, d-tag) is the stable identifier.
      // Note: Some relays/clients may omit the 'd' tag, in which case we fall
      // back to event.id; using stableId avoids mismatches that cause duplicates.
      final existingIndex = eventList.indexWhere(
        (existing) =>
            existing.stableId == updatedVideo.stableId &&
            existing.pubkey == updatedVideo.pubkey,
      );

      if (existingIndex != -1) {
        final existingVideo = eventList[existingIndex];

        // Merge updated video: preserve original timestamps and live counts.
        // See _mergeUpdatedVideo for details.
        final mergedVideo = _mergeUpdatedVideo(existingVideo, updatedVideo);

        eventList[existingIndex] = mergedVideo;
        foundAny = true;

        // Update replaceable tracking map
        // Use NIP71VideoKinds.addressableShortVideo since that's what Divine uses
        final replaceKey =
            '$subscriptionType:${NIP71VideoKinds.addressableShortVideo}:${mergedVideo.pubkey}:${mergedVideo.stableId}';
        _replaceableVideoEvents[replaceKey] = (
          mergedVideo,
          mergedVideo.createdAt,
        );
      }
    }

    // Also update in author buckets (used by profile feeds). Kept out of the
    // `||` so the bucket update cannot be short-circuited away once an earlier
    // cache has already matched.
    final replacedInAuthorBucket = _authorBuckets.replaceByStableId(
      updatedVideo.pubkey,
      updatedVideo,
      merge: _mergeUpdatedVideo,
    );
    foundAny = foundAny || replacedInAuthorBucket;

    if (foundAny) {
      notifyListeners();
      // Notify registered callbacks about the update
      _notifyVideoUpdated(updatedVideo);
    } else {
      // If not found anywhere, add it to discovery feed
      addVideoEvent(updatedVideo);
    }
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

    _eventLists[SubscriptionType.search]?.clear();

    try {
      Log.info(
        '🔍 Starting video search for: "$query"',
        name: 'VideoEventService',
        category: LogCategory.video,
      );

      // Create completer to track search completion
      final searchCompleter = Completer<void>();

      // Use the NostrService searchVideos method
      final searchStream = _nostrService.searchVideos(
        query,
        authors: authors,
        since: since,
        until: until,
        limit: limit ?? 50,
      );

      // Subscribe to search results
      // Owned by _subscriptions['search'] and cancelled in clearSearchResults
      // and _cancelExistingSubscriptions.
      // ignore: cancel_subscriptions
      final subscription = searchStream.listen(
        _handleSearchResult,
        onError: (error) {
          Log.error(
            'Search error: $error',
            name: 'VideoEventService',
            category: LogCategory.video,
          );
          // Search subscriptions can fail without affecting main feeds
          if (!searchCompleter.isCompleted) {
            searchCompleter.completeError(error as Object);
          }
        },
        onDone: () {
          // Search completed naturally - this is expected behavior
          Log.info(
            'Search completed. Found ${_eventLists[SubscriptionType.search]?.length ?? 0} results',
            name: 'VideoEventService',
            category: LogCategory.video,
          );
          // Search subscription clean up - remove from tracking
          _subscriptions.remove('search');
          if (!searchCompleter.isCompleted) {
            searchCompleter.complete();
          }
        },
      );

      // Store subscription for cleanup
      _subscriptions['search'] = subscription;

      // Wait for search to complete with timeout
      await searchCompleter.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          Log.warning(
            'Search timed out after 10 seconds',
            name: 'VideoEventService',
            category: LogCategory.video,
          );
          // Don't throw - return partial results
        },
      );
    } catch (e) {
      Log.error(
        'Failed to start search: $e',
        name: 'VideoEventService',
        category: LogCategory.video,
      );
      rethrow;
    }
  }

  /// Search for videos by hashtag
  Future<void> searchVideosByHashtag(String hashtag) async {
    final cleanHashtag = hashtag.startsWith('#')
        ? hashtag.substring(1)
        : hashtag;
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

    // Cancel search subscription if active
    _subscriptions['search']?.cancel();
    _subscriptions.remove('search');

    Log.debug(
      'Search results cleared',
      name: 'VideoEventService',
      category: LogCategory.video,
    );
  }

  /// Process search results from events
  List<VideoEvent> processSearchResults(List<Event> events) {
    final results = <VideoEvent>[];

    for (final event in events) {
      final videoEvent = VideoEvent.fromNostrEvent(event);
      if (_hasValidVideoUrl(videoEvent) && !shouldHideVideo(videoEvent)) {
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
      category: LogCategory.video,
    );

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

  /// Process a single search result event
  void _handleSearchResult(Event event) {
    if (!NIP71VideoKinds.isVideoKind(event.kind)) {
      Log.debug(
        '⏩ Skipping non-video event in search (kind ${event.kind})',
        name: 'VideoEventService',
        category: LogCategory.video,
      );
      return;
    }

    final videoEvent = VideoEvent.fromNostrEvent(event);

    // Use centralized method for filtering (blocklist, expiry, URL validation)
    _addVideoToSubscription(videoEvent, SubscriptionType.search);
    _scheduleFrameUpdate();
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
        Log.debug(
          'Rejecting broken apt.openvine.co URL: $videoUrl',
          name: 'VideoEventService',
          category: LogCategory.video,
        );
        return false;
      }

      return true;
    } catch (e) {
      Log.debug(
        'Invalid video URL format: $videoUrl - $e',
        name: 'VideoEventService',
        category: LogCategory.video,
      );
      return false;
    }
  }

  // TEST-ONLY METHODS - Do not use in production code

  /// Get pagination states for testing purposes only
  Map<SubscriptionType, PaginationState> getPaginationStatesForTesting() {
    return Map.unmodifiable(_paginationStates);
  }

  /// Add video event with historical flag for testing purposes only
  void addVideoEventForTesting(
    VideoEvent event,
    SubscriptionType type, {
    required bool isHistorical,
  }) {
    _addVideoToSubscription(event, type, isHistorical: isHistorical);
  }

  /// Inject multiple test videos into discovery feed for testing
  void injectTestVideos(List<VideoEvent> videos) {
    for (final video in videos) {
      addVideoEventForTesting(
        video,
        SubscriptionType.discovery,
        isHistorical: true,
      );
    }
    notifyListeners(); // Notify providers that videos have changed
  }

  /// Handle a nostr event for testing (exposes _handleNewVideoEvent)
  @visibleForTesting
  void handleEventForTesting(Event event, SubscriptionType type) {
    _handleNewVideoEvent(event, type);
  }

  /// Handle a nostr event through the pagination path for testing
  /// (exposes _handleHistoricalVideoEvent, the `loadMoreEvents` handler).
  @visibleForTesting
  void handleHistoricalEventForTesting(Event event, SubscriptionType type) {
    _handleHistoricalVideoEvent(event, type);
  }

  /// Seed the active hashtag filter for [type] the way `subscribeToVideoFeed`
  /// does, so tests can exercise filtering without opening a subscription.
  @visibleForTesting
  void setActiveHashtagFilterForTesting(
    SubscriptionType type,
    List<String> hashtags,
  ) {
    _activeHashtagFilters[type] = hashtags;
  }

  /// Flush the pending like-count batch without waiting for the debounce timer.
  @visibleForTesting
  Future<void> flushPendingLikeCountBatchForTesting() {
    return _executeLikeCountBatchFetch();
  }

  /// Apply a resolved like count to a cached video, bypassing the batch and
  /// debounce, to exercise [_applyLikeCountToVideo] directly.
  @visibleForTesting
  bool applyLikeCountForTesting(
    String videoId,
    int likeCount,
    SubscriptionType subscriptionType,
  ) => _applyLikeCountToVideo(videoId, likeCount, subscriptionType);

  List<Filter> _buildDiagnosticProbeFilters(List<Filter> filters) {
    return filters.map((filter) {
      final diagnosticFilter = Filter.fromJson(filter.toJson());
      final existingLimit = diagnosticFilter.limit;
      diagnosticFilter.limit = existingLimit == null || existingLimit > 100
          ? 100
          : existingLimit;
      return diagnosticFilter;
    }).toList();
  }

  /// Run automatic diagnostics when feed fails to load events
  /// This logs relay status, connection info, and tests direct queries to help debug
  Future<void> _runAutoDiagnostics(
    SubscriptionType subscriptionType,
    List<Filter> filters,
  ) async {
    Log.warning(
      '🔍 Running automatic diagnostics for empty $subscriptionType feed...',
      name: 'VideoEventService',
      category: LogCategory.video,
    );

    try {
      // 1. Check relay connection status
      final relays = _nostrService.configuredRelays;
      final connectedRelays = _nostrService.connectedRelays;
      final connectedCount = _nostrService.connectedRelayCount;

      Log.warning(
        '📊 Relay Status:',
        name: 'VideoEventService',
        category: LogCategory.video,
      );
      Log.warning(
        '   - Configured relays: ${relays.join(", ")}',
        name: 'VideoEventService',
        category: LogCategory.video,
      );
      Log.warning(
        '   - Connected relays: ${connectedRelays.join(", ")} ($connectedCount/${relays.length})',
        name: 'VideoEventService',
        category: LogCategory.video,
      );

      if (connectedCount == 0) {
        Log.error(
          '❌ DIAGNOSTIC: No relays connected! This is why feed is empty.',
          name: 'VideoEventService',
          category: LogCategory.video,
        );
        return;
      }

      // 2. Log the subscription filters being used
      Log.warning(
        '📋 Subscription Filters:',
        name: 'VideoEventService',
        category: LogCategory.video,
      );
      for (var i = 0; i < filters.length; i++) {
        final filter = filters[i];
        Log.warning(
          '   Filter $i:',
          name: 'VideoEventService',
          category: LogCategory.video,
        );
        Log.warning(
          '      - kinds: ${filter.kinds}',
          name: 'VideoEventService',
          category: LogCategory.video,
        );
        Log.warning(
          '      - authors: ${filter.authors?.length ?? 0} authors',
          name: 'VideoEventService',
          category: LogCategory.video,
        );

        if (filter.authors != null && filter.authors!.isEmpty) {
          Log.error(
            '❌ DIAGNOSTIC: Authors list is EMPTY! This will return 0 events for homeFeed.',
            name: 'VideoEventService',
            category: LogCategory.video,
          );
        }

        if (filter.limit != null) {
          Log.warning(
            '      - limit: ${filter.limit}',
            name: 'VideoEventService',
            category: LogCategory.video,
          );
        }
        if (filter.since != null) {
          Log.warning(
            '      - since: ${filter.since}',
            name: 'VideoEventService',
            category: LogCategory.video,
          );
        }
        if (filter.until != null) {
          Log.warning(
            '      - until: ${filter.until}',
            name: 'VideoEventService',
            category: LogCategory.video,
          );
        }
      }

      // 3. Test direct query with the same filters to see if matching events
      // exist in the database. queryEvents only consults the local cache for
      // single-filter queries, so probe each filter separately — otherwise
      // repost-enabled (multi-filter) feeds skip the cache entirely and the
      // "subscription broken" branch below can never fire.
      final diagnosticFilters = _buildDiagnosticProbeFilters(filters);
      Log.warning(
        '🔍 Testing direct database query with subscription filters (bypassing subscription)...',
        name: 'VideoEventService',
        category: LogCategory.video,
      );

      final directQueryEvents = <Event>[];
      for (final diagnosticFilter in diagnosticFilters) {
        directQueryEvents.addAll(
          await _nostrService.queryEvents([diagnosticFilter]),
        );
      }

      Log.warning(
        '✅ Filtered direct query returned ${directQueryEvents.length} matching events',
        name: 'VideoEventService',
        category: LogCategory.video,
      );

      if (directQueryEvents.isEmpty) {
        Log.info(
          '✅ DIAGNOSTIC: No cached events match the empty $subscriptionType subscription filters.',
          name: 'VideoEventService',
          category: LogCategory.video,
        );
        Log.info(
          '   Expected when the requested authors or filters have no matching cached videos.',
          name: 'VideoEventService',
          category: LogCategory.video,
        );
      } else {
        Log.warning(
          '✅ DIAGNOSTIC: Database HAS ${directQueryEvents.length} events matching the subscription filters, but subscription returned 0.',
          name: 'VideoEventService',
          category: LogCategory.video,
        );
        Log.error(
          '❌ This means subscription filtering is too restrictive OR subscription stream is broken.',
          name: 'VideoEventService',
          category: LogCategory.video,
        );

        // Log sample events to help compare with subscription filters
        Log.warning(
          '📄 Sample matching events in database:',
          name: 'VideoEventService',
          category: LogCategory.video,
        );
        for (var i = 0; i < directQueryEvents.length && i < 3; i++) {
          final event = directQueryEvents[i];
          Log.warning(
            '   Event $i:',
            name: 'VideoEventService',
            category: LogCategory.video,
          );
          Log.warning(
            '      - id: ${event.id}',
            name: 'VideoEventService',
            category: LogCategory.video,
          );
          Log.warning(
            '      - kind: ${event.kind}',
            name: 'VideoEventService',
            category: LogCategory.video,
          );
          Log.warning(
            '      - pubkey: ${pubkeyForLogs(event.pubkey)}',
            name: 'VideoEventService',
            category: LogCategory.video,
          );
          Log.warning(
            '      - createdAt: ${DateTime.fromMillisecondsSinceEpoch(event.createdAt * 1000)}',
            name: 'VideoEventService',
            category: LogCategory.video,
          );
        }
      }

      // 4. Get relay stats for additional diagnostics
      final relayStats = await _nostrService.getRelayStats();
      if (relayStats != null) {
        Log.warning(
          '📊 Relay Database Stats:',
          name: 'VideoEventService',
          category: LogCategory.video,
        );
        Log.warning(
          '   $relayStats',
          name: 'VideoEventService',
          category: LogCategory.video,
        );
      }
    } catch (e, stackTrace) {
      Log.error(
        '❌ Auto-diagnostics failed: $e',
        name: 'VideoEventService',
        category: LogCategory.video,
      );
      Log.verbose(
        'Stack trace: $stackTrace',
        name: 'VideoEventService',
        category: LogCategory.video,
      );
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

/// Exception thrown when video subscriptions must wait for relay connectivity.
class RelayNotReadyException extends VideoEventServiceException {
  const RelayNotReadyException(super.message);
}

extension _VideoEventSortingExtension on List<VideoEvent> {
  /// Sort the list by creation time
  void sortByCreationTime([bool descending = true]) {
    sort((a, b) {
      final result = a.createdAt.compareTo(b.createdAt);
      return descending ? result : -result;
    });
  }
}
