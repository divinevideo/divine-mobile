// ABOUTME: Video & feed Riverpod providers split from app_providers.dart
// ABOUTME: VideoEventService keystone + filters, publishers, repositories, sharing

import 'dart:async';

import 'package:db_client/db_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show Provider;
import 'package:likes_repository/likes_repository.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/l10n/current_app_l10n.dart';
import 'package:openvine/models/view_event_drop_reason.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/crash_reporting_provider.dart';
import 'package:openvine/providers/creator_sync_provider.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/moderation_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/og_viner_cache_provider.dart';
import 'package:openvine/providers/preferences_providers.dart';
import 'package:openvine/providers/relay_providers.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/providers/saved_sounds_provider.dart';
import 'package:openvine/providers/service_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/social_providers.dart';
import 'package:openvine/providers/upload_media_providers.dart';
import 'package:openvine/services/audio_reuse_consent_resolver.dart';
import 'package:openvine/services/auth_service.dart' show AuthState;
import 'package:openvine/services/broken_video_tracker.dart';
import 'package:openvine/services/collaborator_invite_service.dart';
import 'package:openvine/services/content_deletion_service.dart';
import 'package:openvine/services/dead_media_feed_guard.dart';
import 'package:openvine/services/event_api_client.dart';
import 'package:openvine/services/event_router.dart';
import 'package:openvine/services/nsfw_content_filter.dart';
// ignore: unnecessary_import
import 'package:openvine/services/pending_action_service.dart';
import 'package:openvine/services/personal_event_cache_service.dart';
import 'package:openvine/services/published_event_local_echo.dart';
import 'package:openvine/services/seen_videos_service.dart';
import 'package:openvine/services/subscribed_list_video_cache.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/services/video_event_publisher.dart';
import 'package:openvine/services/video_event_resolver.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/services/video_filter_builder.dart';
import 'package:openvine/services/video_metadata_update_service.dart';
import 'package:openvine/services/video_moderation_status_service.dart';
import 'package:openvine/services/video_sharing_service.dart';
import 'package:openvine/services/video_source_visibility_policy.dart';
import 'package:openvine/services/view_event_publisher.dart';
import 'package:reposts_repository/reposts_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:videos_repository/videos_repository.dart';

part 'video_providers.g.dart';

const _maxEventRouterQueueDepth = 2000;

/// Video filter builder for constructing relay-aware filters with server-side sorting
@riverpod
VideoFilterBuilder videoFilterBuilder(Ref ref) {
  final capabilityService = ref.watch(relayCapabilityServiceProvider);
  return VideoFilterBuilder(capabilityService);
}

/// Personal event cache service for ALL user's own events
@riverpod
PersonalEventCacheService personalEventCacheService(Ref ref) {
  final authService = ref.watch(authServiceProvider);
  final service = PersonalEventCacheService(
    dao: ref.watch(databaseProvider).personalEventsDao,
  );
  ref.onDispose(service.dispose);

  String? initializingPubkey;
  void syncWithAuthState(AuthState authState) {
    if (authState == AuthState.unauthenticated) {
      initializingPubkey = null;
      service.resetCurrentUser();
      return;
    }

    final pubkey = authService.currentPublicKeyHex;
    if (!authService.isAuthenticated || pubkey == null) {
      return;
    }
    if (initializingPubkey == pubkey) {
      return;
    }

    initializingPubkey = pubkey;
    unawaited(
      service
          .initialize(pubkey)
          .catchError((e) {
            Log.warning(
              'Failed to initialize PersonalEventCacheService: $e',
              name: 'PersonalEventCacheService',
            );
          })
          .whenComplete(() {
            if (initializingPubkey == pubkey) {
              initializingPubkey = null;
            }
          }),
    );
  }

  final authSubscription = authService.authStateStream.listen(
    syncWithAuthState,
  );
  ref.onDispose(authSubscription.cancel);
  syncWithAuthState(authService.authState);

  return service;
}

/// Seen videos service for tracking viewed content.
///
/// Split storage: seen set (id+lastSeen) in Drift `seen_videos` table
/// (unbounded, ~1yr TTL) + bounded metrics blob. DB injected when
/// available; tests get the pure-SharedPreferences fallback.
@Riverpod(keepAlive: true)
SeenVideosService seenVideosService(Ref ref) {
  AppDatabase? db;
  try {
    db = ref.watch(databaseProvider);
  } catch (_) {
    db = null;
  }
  final service = SeenVideosService(database: db);
  unawaited(service.initialize());
  ref.onDispose(() => unawaited(service.dispose()));
  return service;
}

/// Subscription manager for centralized subscription management
@Riverpod(keepAlive: true)
SubscriptionManager subscriptionManager(Ref ref) {
  final nostrService = ref.watch(nostrServiceProvider);
  return SubscriptionManager(nostrService);
}

/// Video event service depends on Nostr, SeenVideos, Blocklist, AgeVerification, and SubscriptionManager
@Riverpod(keepAlive: true)
VideoEventService videoEventService(Ref ref) {
  final nostrService = ref.watch(nostrServiceProvider);
  final subscriptionManager = ref.watch(subscriptionManagerProvider);
  final blocklistRepository = ref.watch(contentBlocklistRepositoryProvider);
  final profileRepository = ref.watch(profileRepositoryProvider);
  final videoFilterBuilder = ref.watch(videoFilterBuilderProvider);
  final db = ref.watch(databaseProvider);
  // Bound the ingestion backlog so a burst of relay events can't grow the
  // queues without limit (a Phase-2 OOM source). 2000 sits well above
  // steady-state depth; tune from the Phase-1 `ingest_queue_depth` telemetry.
  final eventRouter = EventRouter(
    db,
    config: const EventRouterConfig(maxQueueDepth: _maxEventRouterQueueDepth),
  );
  ref.onDispose(eventRouter.dispose);

  final likesRepository = ref.watch(likesRepositoryProvider);
  final moderationLabelService = ref.watch(moderationLabelServiceProvider);
  final divineHostFilterService = ref.read(divineHostFilterServiceProvider);
  final provenanceFilterService = ref.read(
    videoProvenanceFilterServiceProvider,
  );
  final feedAspectRatioPreference = ref.watch(
    feedAspectRatioPreferenceServiceProvider,
  );
  final prefs = ref.watch(sharedPreferencesProvider);
  final authService = ref.watch(authServiceProvider);

  final service = VideoEventService(
    nostrService,
    subscriptionManager: subscriptionManager,
    crashReporter: ref.read(crashReportingServiceProvider),
    profileRepository: profileRepository,
    eventRouter: eventRouter,
    videoFilterBuilder: videoFilterBuilder,
    performanceMonitor: ref.watch(performanceMonitoringServiceProvider),
  );
  // Without this, every NostrService client swap (auth cold start, account
  // switch) orphans a service whose periodic timers and auth subscription
  // keep running against the disposed EventRouter above (#6174).
  ref.onDispose(service.dispose);
  var persistedDeletions = const <ContentDeletion>[];
  try {
    persistedDeletions = ContentDeletionService.parseDeletionHistory(
      prefs.getString(ContentDeletionService.deletionsStorageKey),
    );
  } on Object catch (error, stackTrace) {
    Log.error(
      'Failed to hydrate video deletion tombstones: $error',
      name: 'VideoEventService',
      category: LogCategory.system,
      error: error,
      stackTrace: stackTrace,
    );
  }
  service.seedKnownDeletionTombstones(
    eventIds: persistedDeletions.map((deletion) => deletion.originalEventId),
    addressableDeletedAt: {
      for (final deletion in persistedDeletions)
        ?deletion.addressableId:
            deletion.deletedAt.millisecondsSinceEpoch ~/ 1000,
    },
  );
  service.setBlocklistRepository(blocklistRepository);
  service.setLikesRepository(likesRepository);
  service.setContentFilterService(ref.watch(contentFilterServiceProvider));
  service.setCurrentUserPubkeyProvider(
    () => authService.currentPublicKeyHex ?? nostrService.publicKey,
  );
  service.setModerationLabelService(moderationLabelService);
  service.setDivineHostFilterService(divineHostFilterService);
  service.setProvenanceFilterService(provenanceFilterService);
  service.setFeedAspectRatioPreferenceService(feedAspectRatioPreference);

  // Attach the scoped broken-video tracker so videos confirmed unavailable stay
  // filtered out of every list surface across restarts. `fireImmediately`
  // attaches the initial async tracker once it hydrates; later auth transitions
  // rebuild the tracker under a different pubkey scope and reattach it here.
  // See #5237 / #6251.
  ref.listen(brokenVideoTrackerProvider, (_, next) {
    next.whenData(service.setBrokenVideoTracker);
    if (next.hasError) {
      Log.error(
        'Failed to attach broken video tracker to VideoEventService: '
        '${next.error}',
        name: 'VideoEventService',
        category: LogCategory.system,
        error: next.error,
        stackTrace: next.stackTrace,
      );
    }
  }, fireImmediately: true);

  // Teach the OG Viner badge cache from every video that flows through the
  // service. The cache filters internally (only `isOriginalVine` videos
  // contribute pubkeys), so it's safe to feed it every batch — popular,
  // new, classics, profile, hashtag, search, anything.
  final ogVinerCache = ref.read(ogVinerCacheServiceProvider);
  final disposeObserver = service.addVideoObserver(
    (videos) => unawaited(ogVinerCache.learnFromVideos(videos)),
  );
  ref.onDispose(disposeObserver);

  return service;
}

/// Video event publisher for publishing video events to Nostr relays
@Riverpod(keepAlive: true)
VideoEventPublisher videoEventPublisher(Ref ref) {
  final uploadManager = ref.watch(uploadManagerProvider);
  final nostrService = ref.watch(nostrServiceProvider);
  final authService = ref.watch(authServiceProvider);
  final personalEventCache = ref.watch(personalEventCacheServiceProvider);
  final videoEventService = ref.watch(videoEventServiceProvider);
  final blossomUploadService = ref.watch(blossomUploadServiceProvider);
  final profileRepository = ref.watch(profileRepositoryProvider);
  final profileStatsDao = ref.watch(databaseProvider).profileStatsDao;
  final savedSoundsService = ref.watch(savedSoundsServiceProvider);
  final consentResolver = AudioReuseConsentResolver(
    videosRepository: ref.watch(videosRepositoryProvider),
  );

  // REST-first publish: POST the signed event to {eventPublishBaseUrl}/api/events with
  // NIP-98 auth, falling back to the WebSocket relay pool on transient
  // failures. NIP-98 validates the exact URL, so event publish uses the relay
  // HTTP origin rather than production's FunnelCake API host.
  final environmentConfig = ref.watch(currentEnvironmentProvider);
  final nip98AuthService = ref.watch(nip98AuthServiceProvider);
  final eventApiHttpClient = ref.watch(instrumentedHttpClientFactoryProvider)();
  ref.onDispose(eventApiHttpClient.close);
  final eventApiClient = EventApiClient(
    httpClient: eventApiHttpClient,
    nip98AuthService: nip98AuthService,
    apiBaseUrl: () => environmentConfig.eventPublishBaseUrl,
  );

  return VideoEventPublisher(
    uploadManager: uploadManager,
    nostrService: nostrService,
    authService: authService,
    personalEventCache: personalEventCache,
    videoEventService: videoEventService,
    blossomUploadService: blossomUploadService,
    profileRepository: profileRepository,
    profileStatsDao: profileStatsDao,
    savedSoundsService: savedSoundsService,
    // ref.read, not watch: watching soundSyncRepositoryValueProvider here
    // would rebuild this keepAlive provider (and discard its in-flight
    // publish coalescer) every time the vault key resolves. Reading inside
    // the getter instead makes the publisher check the current value at
    // call time without subscribing to it.
    soundSyncRepositoryGetter: () => ref.read(soundSyncRepositoryValueProvider),
    eventApiClient: eventApiClient,
    trustedRelayUrl: environmentConfig.relayUrl,
    audioReuseConsentChecker: consentResolver.verify,
    // ref.read at call time, not watch: this keepAlive provider must not
    // rebuild (and drop its in-flight publish coalescer) when storage is
    // rebuilt, same reasoning as soundSyncRepositoryGetter above.
    publishedEventLocalEcho: PublishedEventLocalEcho(
      (event) => ref.read(videoLocalStorageProvider).saveEventsBatch([event]),
    ),
  );
}

/// View event publisher for kind 22236 ephemeral analytics events
///
/// Publishes video view events to track watch time, traffic sources,
/// and enable creator analytics and recommendation systems.
@riverpod
ViewEventPublisher viewEventPublisher(Ref ref) {
  final nostrService = ref.watch(nostrServiceProvider);
  final authService = ref.watch(authServiceProvider);

  return ViewEventPublisher(
    nostrService: nostrService,
    authService: authService,
    onDrop: (reason, {required String videoId, required String method}) {
      if (!reason.isStructural) return;
      ref
          .read(crashReportingServiceProvider)
          .recordError(
            Reportable(
              ViewEventInvariantException(reason),
              context: 'ViewEventPublisher.$method',
            ),
            StackTrace.current,
            reason:
                'ViewEventPublisher.$method.${reason.name}.videoId=$videoId',
          );
    },
  );
}

/// Subscribed list video cache for merging subscribed list videos into home feed
/// Depends on CuratedListService which is async, so watch the state provider
@Riverpod(keepAlive: true)
SubscribedListVideoCache? subscribedListVideoCache(Ref ref) {
  final nostrService = ref.watch(nostrServiceProvider);
  final videoEventService = ref.watch(videoEventServiceProvider);

  // Watch the curated lists state to get the service when ready
  final curatedListState = ref.watch(curatedListsStateProvider);

  // Only create cache when CuratedListService is available
  final curatedListService = curatedListState.whenOrNull(
    data: (_) => ref.read(curatedListsStateProvider.notifier).service,
  );

  // Return null if CuratedListService isn't ready yet
  if (curatedListService == null) {
    return null;
  }

  final cache = SubscribedListVideoCache(
    nostrService: nostrService,
    videoEventService: videoEventService,
    curatedListService: curatedListService,
  );

  // Wire up the sync triggers: when lists are subscribed/unsubscribed,
  // sync/remove videos from the cache automatically
  curatedListService.setOnListSubscribed((listId, videoIds) async {
    Log.debug(
      'Syncing subscribed list videos: $listId (${videoIds.length} videos)',
      name: 'SubscribedListVideoCache',
      category: LogCategory.video,
    );
    await cache.syncList(listId, videoIds);
  });

  curatedListService.setOnListUnsubscribed((listId) {
    Log.debug(
      'Removing unsubscribed list from cache: $listId',
      name: 'SubscribedListVideoCache',
      category: LogCategory.video,
    );
    cache.removeList(listId);
  });

  // Sync all subscribed lists on initialization
  Future.microtask(() async {
    await cache.syncAllSubscribedLists();
  });

  ref.onDispose(() {
    // Clear callbacks when cache is disposed
    curatedListService.setOnListSubscribed(null);
    curatedListService.setOnListUnsubscribed(null);
    cache.dispose();
  });

  return cache;
}

/// Video sharing service
///
/// When a [DmRepository] is available the service sends videos via NIP-17
/// encrypted DMs (NIP-17). Otherwise falls back to NIP-04 kind 4.
@riverpod
VideoSharingService? videoSharingService(Ref ref) {
  final nostrService = ref.watch(nostrServiceProvider);
  final authService = ref.watch(authServiceProvider);
  // Read-only handle: the service only reads profiles, and gating it on the
  // relay-ready client made Share a dead tap during cold start (#6423). The
  // send path gates itself on `canPublishNostrWritesNow`.
  final profileRepository = ref.watch(profileReadRepositoryProvider);
  final dmRepository = ref.watch(dmRepositoryProvider);

  if (profileRepository == null) {
    return null;
  }

  return VideoSharingService(
    nostrService: nostrService,
    authService: authService,
    profileRepository: profileRepository,
    dmRepository: dmRepository,
  );
}

/// Unified resolver for fetching a [VideoEvent] by its event id, with
/// in-memory → personal cache → relay fallback. See [VideoEventResolver].
@Riverpod(keepAlive: true)
VideoEventResolver videoEventResolver(Ref ref) {
  final nostrService = ref.watch(nostrServiceProvider);
  final videoEventService = ref.watch(videoEventServiceProvider);
  final personalEventCache = ref.watch(personalEventCacheServiceProvider);
  final authService = ref.watch(authServiceProvider);

  return VideoEventResolver(
    videoEventService: videoEventService,
    personalEventCache: personalEventCache,
    subscribe: nostrService.subscribe,
    viewerPubkeyHex: () => authService.currentPublicKeyHex,
  );
}

/// Service that orchestrates the video-metadata-edit republish flow.
@riverpod
VideoMetadataUpdateService videoMetadataUpdateService(Ref ref) {
  return VideoMetadataUpdateService(
    authService: ref.watch(authServiceProvider),
    blossomService: ref.watch(blossomUploadServiceProvider),
    nostrService: ref.watch(nostrServiceProvider),
    personalEventCache: ref.watch(personalEventCacheServiceProvider),
    videoEventService: ref.watch(videoEventServiceProvider),
    collaboratorInviteService: CollaboratorInviteService(
      dmRepository: ref.watch(dmRepositoryProvider),
      l10n: currentAppL10n(ref.read(sharedPreferencesProvider)),
    ),
  );
}

/// Broken video tracker service for filtering non-functional videos.
///
/// `keepAlive: true` so this stays the single instance per identity —
/// [videoEventServiceProvider] attaches it to `VideoEventService` for
/// `filterVideoList`, and [deadMediaFeedGuardProvider] must mark broken
/// videos on that *same* instance. Without `keepAlive`, this autodisposes
/// once its initial watchers drop, so a later read can rebuild a fresh
/// tracker that `VideoEventService` never sees — the home feed would then
/// mark an item broken without it ever being filtered. See #5953 review.
///
/// It does rebuild on every auth transition, by design: the marks are stored
/// per pubkey so one account's prunes cannot hide videos from another. That is
/// safe only because [videoEventServiceProvider] reattaches the new tracker
/// through a `ref.listen` rather than capturing one at build time.
@Riverpod(keepAlive: true)
Future<BrokenVideoTracker> brokenVideoTracker(Ref ref) async {
  ref.watch(currentAuthStateProvider);
  final ownerPubkey = ref.watch(authServiceProvider).currentPublicKeyHex;
  final tracker = BrokenVideoTracker(ownerPubkey: ownerPubkey);
  await tracker.initialize();
  return tracker;
}

/// Guard that HEAD-confirms a feed item's media is 404 and verifies moderation
/// says the blob is `blocked` before marking it broken. A canonical API 404
/// is session-only and does not persist. Reuses the singleton
/// [brokenVideoTrackerProvider] so a mark here is visible to every surface's
/// `filterVideoList`. See #5953 / #6251.
///
/// `keepAlive: true` for the same reason as [brokenVideoTrackerProvider]: the
/// fullscreen feed reads this imperatively from a BLoC callback, and an
/// autoDispose future provider that nothing listens to is disposed right after
/// each `ref.read`, so `asData` is always null and the prune never fires. It
/// worked only while an unrelated widget happened to be watching it.
@Riverpod(keepAlive: true)
Future<DeadMediaFeedGuard> deadMediaFeedGuard(Ref ref) async {
  // Watched before the await. A dispose *or* a rebuild during the suspension
  // replaces the element's `ref`, and any `ref` use after that throws
  // UnmountedRefException — which lands in an orphaned future, so the guard
  // silently never resolves and the prune stops firing.
  final moderationStatusService = ref.watch(
    videoModerationStatusServiceProvider,
  );
  final funnelcakeClient = ref.watch(funnelcakeApiClientProvider);
  final tracker = await ref.watch(brokenVideoTrackerProvider.future);
  return DeadMediaFeedGuard(
    brokenVideoTracker: tracker,
    moderationStatusService: moderationStatusService,
    eventMissingChecker: (videoId) async =>
        await funnelcakeClient.getVideoEvent(videoId) == null,
  );
}

/// Provider for VideoLocalStorage instance (SQLite-backed)
///
/// Creates a DbVideoLocalStorage for caching video events locally.
/// Used by VideosRepository for cache-first lookups.
///
/// Uses:
/// - NostrEventsDao from databaseProvider (for SQLite storage)
@Riverpod(keepAlive: true)
VideoLocalStorage videoLocalStorage(Ref ref) {
  final db = ref.watch(databaseProvider);
  return DbVideoLocalStorage(dao: db.nostrEventsDao);
}

/// Provider for VideosRepository instance
///
/// Creates a VideosRepository for loading video feeds with pagination.
/// Works without authentication for public feeds.
///
/// Rebuilds (yielding a fresh in-memory cache) when content filter, aspect
/// ratio, or Divine-host filter preferences change. The version providers
/// act as rebuild triggers since the underlying services are long-lived
/// ChangeNotifiers that don't themselves cause provider invalidation.
///
/// Uses:
/// - NostrClient from nostrServiceProvider (for relay communication)
/// - VideoLocalStorage for cache-first lookups and caching results
/// - ContentBlocklistRepository for filtering blocked/muted users
/// - ContentFilterService for filtering NSFW content based on user preferences
/// - FunnelcakeApiClient for trending/popular video sorting
@Riverpod(keepAlive: true)
VideosRepository videosRepository(Ref ref) {
  // Watch version providers to trigger rebuild on preference changes.
  // These increment when ContentFilterService or FeedAspectRatioPreference
  // notifies, ensuring a fresh repository (with empty InMemoryFeedCache)
  // is created after any filter toggle.
  ref.watch(contentFilterVersionProvider);
  ref.watch(divineHostFilterVersionProvider);

  final nostrClient = ref.watch(nostrServiceProvider);
  final authService = ref.watch(authServiceProvider);
  final localStorage = ref.watch(videoLocalStorageProvider);
  final contentFilterService = ref.watch(contentFilterServiceProvider);
  final moderationLabelService = ref.watch(moderationLabelServiceProvider);
  final funnelcakeClient = ref.watch(funnelcakeApiClientProvider);
  final seenVideosService = ref.watch(seenVideosServiceProvider);
  final clientSeenFilteringEnabled = () {
    try {
      final flagService = ref.watch(featureFlagServiceProvider);
      return flagService.isEnabled(FeatureFlag.clientSeenFiltering);
    } catch (_) {
      return true;
    }
  }();
  final divineHostFilterService = ref.read(divineHostFilterServiceProvider);
  final provenanceFilterService = ref.read(
    videoProvenanceFilterServiceProvider,
  );
  final feedAspectRatioPreference = ref.watch(
    feedAspectRatioPreferenceServiceProvider,
  );
  final videoEventService = ref.watch(videoEventServiceProvider);

  final nsfwFilter = createNsfwFilter(
    contentFilterService,
    moderationLabelService: moderationLabelService,
    viewerPubkey: () =>
        authService.currentPublicKeyHex ?? nostrClient.publicKey,
  );

  final repository = VideosRepository(
    nostrClient: nostrClient,
    localStorage: localStorage,
    blockFilter: createBlockedAuthorFilter(ref),
    deletedFilter: videoEventService.isVideoEventKnownDeleted,
    removedVideoIds: videoEventService.removedVideoIds,
    contentFilter: (video) =>
        nsfwFilter(video) ||
        VideoSourceVisibilityPolicy.isHiddenBySourcePreferences(
          video,
          divineHostedOnly: divineHostFilterService.showDivineHostedOnly,
          verifiedOnly: provenanceFilterService.showVerifiedOnly,
        ) ||
        feedAspectRatioPreference.shouldHideVideo(video),
    warningLabelsResolver: createNsfwWarnLabels(
      contentFilterService,
      moderationLabelService: moderationLabelService,
      viewerPubkey: () =>
          authService.currentPublicKeyHex ?? nostrClient.publicKey,
    ),
    funnelcakeApiClient: funnelcakeClient,
    inMemoryFeedCache: InMemoryFeedCache(),
    seenVideoLookup: clientSeenFilteringEnabled
        ? SeenVideoLookup(
            wasSeenRecently: seenVideosService.wasSeenRecently,
            initialize: seenVideosService.initialize,
          )
        : null,
  );

  // Clear the in-memory feed cache (home + per-author) on logout/account
  // switch — the repository owns its cache. Replaces the deleted
  // profile_feed_session_cache auth-flip clear. Filter toggles already rebuild
  // this provider with a fresh cache, so this listener covers only the auth path.
  ref.listen<AuthState>(currentAuthStateProvider, (previous, next) {
    if (next == AuthState.unauthenticated) {
      repository.clearInMemoryFeedCache();
    }
  });

  return repository;
}

// =============================================================================
// LIKES REPOSITORY
// =============================================================================

/// Provider for LikesRepository instance
///
/// Creates a LikesRepository. Local storage is attached when the user is
/// authenticated; signed-out relay queries are guarded by the repository.
///
/// Uses:
/// - NostrClient from nostrServiceProvider (for relay communication)
/// - PersonalReactionsDao from databaseProvider (for local storage)
/// - FunnelcakeApiClient for the "Liked by" list, which resolves the whole
///   addressable coordinate rather than one revision id (#6021)
@Riverpod(keepAlive: true)
LikesRepository likesRepository(Ref ref) {
  final authService = ref.watch(authServiceProvider);

  // Watch auth state to react to auth changes (login/logout)
  // This ensures the provider rebuilds when authentication completes
  ref.watch(currentAuthStateProvider);

  final userPubkey = authService.currentPublicKeyHex;

  final nostrClient = ref.watch(nostrServiceProvider);

  // Only create localStorage if we have a valid user pubkey
  // The provider will rebuild when auth state changes
  DbLikesLocalStorage? localStorage;
  if (userPubkey != null) {
    final db = ref.watch(databaseProvider);
    localStorage = DbLikesLocalStorage(
      dao: db.personalReactionsDao,
      userPubkey: userPubkey,
    );
  }

  // Get connection status and pending action service for offline support
  final connectionStatus = ref.watch(connectionStatusServiceProvider);
  final pendingActionService = ref.watch(pendingActionServiceProvider);

  final repository = LikesRepository(
    nostrClient: nostrClient,
    localStorage: localStorage,
    blockFilter: createBlockedAuthorFilter(ref),
    funnelcakeApiClient: ref.watch(funnelcakeApiClientProvider),
    errorReporter: (error, stackTrace, {required site}) {
      unawaited(
        ref
            .read(crashReportingServiceProvider)
            .recordError(
              error,
              stackTrace,
              reason: 'LikesRepository.$site',
            ),
      );
    },
    isOnline: () =>
        connectionStatus.isOnline && authService.canPublishNostrWritesNow,
    queueOfflineAction: pendingActionService != null
        ? ({
            required bool isLike,
            required String eventId,
            required String authorPubkey,
            String? addressableId,
            int? targetKind,
          }) async {
            await pendingActionService.queueAction(
              type: isLike ? PendingActionType.like : PendingActionType.unlike,
              targetId: eventId,
              authorPubkey: authorPubkey,
              addressableId: addressableId,
              targetKind: targetKind,
            );
          }
        : null,
  );

  // Register executors with pending action service for sync
  if (pendingActionService != null) {
    pendingActionService.registerExecutor(
      PendingActionType.like,
      (action) => repository.executeLikeAction(
        eventId: action.targetId,
        authorPubkey: action.authorPubkey ?? '',
        addressableId: action.addressableId,
        targetKind: action.targetKind,
      ),
    );
    pendingActionService.registerExecutor(
      PendingActionType.unlike,
      (action) => repository.executeUnlikeAction(
        action.targetId,
        addressableId: action.addressableId,
      ),
    );
  }

  // Initialize: load from local storage + set up persistent subscription
  repository.initialize().catchError((Object e) {
    Log.warning(
      'Failed to initialize LikesRepository: $e',
      name: 'LikesRepository',
    );
  });

  ref.onDispose(repository.dispose);

  return repository;
}

/// Provider for RepostsRepository instance
///
/// Creates a RepostsRepository for managing user reposts (Kind 16 generic
/// reposts).
///
/// Uses:
/// - NostrClient from nostrServiceProvider (for relay communication)
/// - PersonalRepostsDao from databaseProvider (for local storage)
final repostsRepositoryProvider = Provider<RepostsRepository>(
  repostsRepository,
  name: 'repostsRepositoryProvider',
);

RepostsRepository repostsRepository(Ref ref) {
  final authService = ref.watch(authServiceProvider);

  // Watch auth state to react to auth changes (login/logout)
  ref.watch(currentAuthStateProvider);

  final userPubkey = authService.currentPublicKeyHex;

  final nostrClient = ref.watch(nostrServiceProvider);

  // Only create localStorage if we have a valid user pubkey
  // The provider will rebuild when auth state changes
  DbRepostsLocalStorage? localStorage;
  if (userPubkey != null) {
    final db = ref.watch(databaseProvider);
    localStorage = DbRepostsLocalStorage(
      dao: db.personalRepostsDao,
      userPubkey: userPubkey,
    );
  }

  // Get connection status and pending action service for offline support
  final connectionStatus = ref.watch(connectionStatusServiceProvider);
  final pendingActionService = ref.watch(pendingActionServiceProvider);

  final repository = RepostsRepository(
    nostrClient: nostrClient,
    localStorage: localStorage,
    blockFilter: createBlockedAuthorFilter(ref),
    errorReporter: (error, stackTrace, {required site}) {
      unawaited(
        ref
            .read(crashReportingServiceProvider)
            .recordError(
              error,
              stackTrace,
              reason: 'RepostsRepository.$site',
            ),
      );
    },
    isOnline: () =>
        connectionStatus.isOnline && authService.canPublishNostrWritesNow,
    queueOfflineAction: pendingActionService != null
        ? ({
            required bool isRepost,
            required String addressableId,
            required String originalAuthorPubkey,
            String? eventId,
          }) async {
            await pendingActionService.queueAction(
              type: isRepost
                  ? PendingActionType.repost
                  : PendingActionType.unrepost,
              targetId: addressableId,
              authorPubkey: originalAuthorPubkey,
              addressableId: addressableId,
            );
          }
        : null,
  );

  // Register executors with pending action service for sync
  if (pendingActionService != null) {
    pendingActionService.registerExecutor(
      PendingActionType.repost,
      (action) => repository.executeRepostAction(
        addressableId: action.addressableId ?? action.targetId,
        originalAuthorPubkey: action.authorPubkey ?? '',
      ),
    );
    pendingActionService.registerExecutor(
      PendingActionType.unrepost,
      (action) => repository.executeUnrepostAction(
        action.addressableId ?? action.targetId,
      ),
    );
  }

  // Initialize: load from local storage + set up persistent subscription
  repository.initialize().catchError((Object e) {
    Log.warning(
      'Failed to initialize RepostsRepository: $e',
      name: 'RepostsRepository',
    );
  });

  ref.onDispose(repository.dispose);

  return repository;
}
