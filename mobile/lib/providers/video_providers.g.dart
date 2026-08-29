// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'video_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Video filter builder for constructing relay-aware filters with server-side sorting

@ProviderFor(videoFilterBuilder)
final videoFilterBuilderProvider = VideoFilterBuilderProvider._();

/// Video filter builder for constructing relay-aware filters with server-side sorting

final class VideoFilterBuilderProvider
    extends
        $FunctionalProvider<
          VideoFilterBuilder,
          VideoFilterBuilder,
          VideoFilterBuilder
        >
    with $Provider<VideoFilterBuilder> {
  /// Video filter builder for constructing relay-aware filters with server-side sorting
  VideoFilterBuilderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'videoFilterBuilderProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$videoFilterBuilderHash();

  @$internal
  @override
  $ProviderElement<VideoFilterBuilder> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  VideoFilterBuilder create(Ref ref) {
    return videoFilterBuilder(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VideoFilterBuilder value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VideoFilterBuilder>(value),
    );
  }
}

String _$videoFilterBuilderHash() =>
    r'fa2390a9274ddcc619886531d6cfa0671b545d1a';

/// Personal event cache service for ALL user's own events

@ProviderFor(personalEventCacheService)
final personalEventCacheServiceProvider = PersonalEventCacheServiceProvider._();

/// Personal event cache service for ALL user's own events

final class PersonalEventCacheServiceProvider
    extends
        $FunctionalProvider<
          PersonalEventCacheService,
          PersonalEventCacheService,
          PersonalEventCacheService
        >
    with $Provider<PersonalEventCacheService> {
  /// Personal event cache service for ALL user's own events
  PersonalEventCacheServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'personalEventCacheServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$personalEventCacheServiceHash();

  @$internal
  @override
  $ProviderElement<PersonalEventCacheService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PersonalEventCacheService create(Ref ref) {
    return personalEventCacheService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PersonalEventCacheService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PersonalEventCacheService>(value),
    );
  }
}

String _$personalEventCacheServiceHash() =>
    r'35ba74612e96c106f5c1967d44ab2ac9cb97d4fb';

/// Seen videos service for tracking viewed content.
///
/// Split storage: seen set (id+lastSeen) in Drift `seen_videos` table
/// (unbounded, ~1yr TTL) + bounded metrics blob. DB injected when
/// available; tests get the pure-SharedPreferences fallback.

@ProviderFor(seenVideosService)
final seenVideosServiceProvider = SeenVideosServiceProvider._();

/// Seen videos service for tracking viewed content.
///
/// Split storage: seen set (id+lastSeen) in Drift `seen_videos` table
/// (unbounded, ~1yr TTL) + bounded metrics blob. DB injected when
/// available; tests get the pure-SharedPreferences fallback.

final class SeenVideosServiceProvider
    extends
        $FunctionalProvider<
          SeenVideosService,
          SeenVideosService,
          SeenVideosService
        >
    with $Provider<SeenVideosService> {
  /// Seen videos service for tracking viewed content.
  ///
  /// Split storage: seen set (id+lastSeen) in Drift `seen_videos` table
  /// (unbounded, ~1yr TTL) + bounded metrics blob. DB injected when
  /// available; tests get the pure-SharedPreferences fallback.
  SeenVideosServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'seenVideosServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$seenVideosServiceHash();

  @$internal
  @override
  $ProviderElement<SeenVideosService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SeenVideosService create(Ref ref) {
    return seenVideosService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SeenVideosService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SeenVideosService>(value),
    );
  }
}

String _$seenVideosServiceHash() => r'f591d3c80445dab2fab1d4157f1ff5b50ef7509a';

/// Subscription manager for centralized subscription management

@ProviderFor(subscriptionManager)
final subscriptionManagerProvider = SubscriptionManagerProvider._();

/// Subscription manager for centralized subscription management

final class SubscriptionManagerProvider
    extends
        $FunctionalProvider<
          SubscriptionManager,
          SubscriptionManager,
          SubscriptionManager
        >
    with $Provider<SubscriptionManager> {
  /// Subscription manager for centralized subscription management
  SubscriptionManagerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'subscriptionManagerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$subscriptionManagerHash();

  @$internal
  @override
  $ProviderElement<SubscriptionManager> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SubscriptionManager create(Ref ref) {
    return subscriptionManager(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SubscriptionManager value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SubscriptionManager>(value),
    );
  }
}

String _$subscriptionManagerHash() =>
    r'b65a6978927d3004c6f841e0b80075f9db9645d2';

/// Video event service depends on Nostr, SeenVideos, Blocklist, AgeVerification, and SubscriptionManager

@ProviderFor(videoEventService)
final videoEventServiceProvider = VideoEventServiceProvider._();

/// Video event service depends on Nostr, SeenVideos, Blocklist, AgeVerification, and SubscriptionManager

final class VideoEventServiceProvider
    extends
        $FunctionalProvider<
          VideoEventService,
          VideoEventService,
          VideoEventService
        >
    with $Provider<VideoEventService> {
  /// Video event service depends on Nostr, SeenVideos, Blocklist, AgeVerification, and SubscriptionManager
  VideoEventServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'videoEventServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$videoEventServiceHash();

  @$internal
  @override
  $ProviderElement<VideoEventService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  VideoEventService create(Ref ref) {
    return videoEventService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VideoEventService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VideoEventService>(value),
    );
  }
}

String _$videoEventServiceHash() => r'f3c98dbdc9e213f20a7abc20ea7fd10df6f77d43';

/// Video event publisher for publishing video events to Nostr relays

@ProviderFor(videoEventPublisher)
final videoEventPublisherProvider = VideoEventPublisherProvider._();

/// Video event publisher for publishing video events to Nostr relays

final class VideoEventPublisherProvider
    extends
        $FunctionalProvider<
          VideoEventPublisher,
          VideoEventPublisher,
          VideoEventPublisher
        >
    with $Provider<VideoEventPublisher> {
  /// Video event publisher for publishing video events to Nostr relays
  VideoEventPublisherProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'videoEventPublisherProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$videoEventPublisherHash();

  @$internal
  @override
  $ProviderElement<VideoEventPublisher> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  VideoEventPublisher create(Ref ref) {
    return videoEventPublisher(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VideoEventPublisher value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VideoEventPublisher>(value),
    );
  }
}

String _$videoEventPublisherHash() =>
    r'3a40d2a3de92880b3365f735fb22d2bddf85dfe3';

/// View event publisher for kind 22236 ephemeral analytics events
///
/// Publishes video view events to track watch time, traffic sources,
/// and enable creator analytics and recommendation systems.

@ProviderFor(viewEventPublisher)
final viewEventPublisherProvider = ViewEventPublisherProvider._();

/// View event publisher for kind 22236 ephemeral analytics events
///
/// Publishes video view events to track watch time, traffic sources,
/// and enable creator analytics and recommendation systems.

final class ViewEventPublisherProvider
    extends
        $FunctionalProvider<
          ViewEventPublisher,
          ViewEventPublisher,
          ViewEventPublisher
        >
    with $Provider<ViewEventPublisher> {
  /// View event publisher for kind 22236 ephemeral analytics events
  ///
  /// Publishes video view events to track watch time, traffic sources,
  /// and enable creator analytics and recommendation systems.
  ViewEventPublisherProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'viewEventPublisherProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$viewEventPublisherHash();

  @$internal
  @override
  $ProviderElement<ViewEventPublisher> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ViewEventPublisher create(Ref ref) {
    return viewEventPublisher(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ViewEventPublisher value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ViewEventPublisher>(value),
    );
  }
}

String _$viewEventPublisherHash() =>
    r'00aaa657c3238bb3718bd1839f48febb15d82841';

/// Subscribed list video cache for merging subscribed list videos into home feed
/// Depends on CuratedListService which is async, so watch the state provider

@ProviderFor(subscribedListVideoCache)
final subscribedListVideoCacheProvider = SubscribedListVideoCacheProvider._();

/// Subscribed list video cache for merging subscribed list videos into home feed
/// Depends on CuratedListService which is async, so watch the state provider

final class SubscribedListVideoCacheProvider
    extends
        $FunctionalProvider<
          SubscribedListVideoCache?,
          SubscribedListVideoCache?,
          SubscribedListVideoCache?
        >
    with $Provider<SubscribedListVideoCache?> {
  /// Subscribed list video cache for merging subscribed list videos into home feed
  /// Depends on CuratedListService which is async, so watch the state provider
  SubscribedListVideoCacheProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'subscribedListVideoCacheProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$subscribedListVideoCacheHash();

  @$internal
  @override
  $ProviderElement<SubscribedListVideoCache?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SubscribedListVideoCache? create(Ref ref) {
    return subscribedListVideoCache(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SubscribedListVideoCache? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SubscribedListVideoCache?>(value),
    );
  }
}

String _$subscribedListVideoCacheHash() =>
    r'e7d9c2f15e09ab7d3848597e7d288749e3050f08';

/// Video sharing service
///
/// When a [DmRepository] is available the service sends videos via NIP-17
/// encrypted DMs (NIP-17). Otherwise falls back to NIP-04 kind 4.

@ProviderFor(videoSharingService)
final videoSharingServiceProvider = VideoSharingServiceProvider._();

/// Video sharing service
///
/// When a [DmRepository] is available the service sends videos via NIP-17
/// encrypted DMs (NIP-17). Otherwise falls back to NIP-04 kind 4.

final class VideoSharingServiceProvider
    extends
        $FunctionalProvider<
          VideoSharingService?,
          VideoSharingService?,
          VideoSharingService?
        >
    with $Provider<VideoSharingService?> {
  /// Video sharing service
  ///
  /// When a [DmRepository] is available the service sends videos via NIP-17
  /// encrypted DMs (NIP-17). Otherwise falls back to NIP-04 kind 4.
  VideoSharingServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'videoSharingServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$videoSharingServiceHash();

  @$internal
  @override
  $ProviderElement<VideoSharingService?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  VideoSharingService? create(Ref ref) {
    return videoSharingService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VideoSharingService? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VideoSharingService?>(value),
    );
  }
}

String _$videoSharingServiceHash() =>
    r'7406fd516a93ac8becbf4df73335ffa387ad25c6';

/// Unified resolver for fetching a [VideoEvent] by its event id, with
/// in-memory → personal cache → relay fallback. See [VideoEventResolver].

@ProviderFor(videoEventResolver)
final videoEventResolverProvider = VideoEventResolverProvider._();

/// Unified resolver for fetching a [VideoEvent] by its event id, with
/// in-memory → personal cache → relay fallback. See [VideoEventResolver].

final class VideoEventResolverProvider
    extends
        $FunctionalProvider<
          VideoEventResolver,
          VideoEventResolver,
          VideoEventResolver
        >
    with $Provider<VideoEventResolver> {
  /// Unified resolver for fetching a [VideoEvent] by its event id, with
  /// in-memory → personal cache → relay fallback. See [VideoEventResolver].
  VideoEventResolverProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'videoEventResolverProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$videoEventResolverHash();

  @$internal
  @override
  $ProviderElement<VideoEventResolver> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  VideoEventResolver create(Ref ref) {
    return videoEventResolver(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VideoEventResolver value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VideoEventResolver>(value),
    );
  }
}

String _$videoEventResolverHash() =>
    r'a076181f7238f6f3cb91443d714872abb5805ee0';

/// Service that orchestrates the video-metadata-edit republish flow.

@ProviderFor(videoMetadataUpdateService)
final videoMetadataUpdateServiceProvider =
    VideoMetadataUpdateServiceProvider._();

/// Service that orchestrates the video-metadata-edit republish flow.

final class VideoMetadataUpdateServiceProvider
    extends
        $FunctionalProvider<
          VideoMetadataUpdateService,
          VideoMetadataUpdateService,
          VideoMetadataUpdateService
        >
    with $Provider<VideoMetadataUpdateService> {
  /// Service that orchestrates the video-metadata-edit republish flow.
  VideoMetadataUpdateServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'videoMetadataUpdateServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$videoMetadataUpdateServiceHash();

  @$internal
  @override
  $ProviderElement<VideoMetadataUpdateService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  VideoMetadataUpdateService create(Ref ref) {
    return videoMetadataUpdateService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VideoMetadataUpdateService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VideoMetadataUpdateService>(value),
    );
  }
}

String _$videoMetadataUpdateServiceHash() =>
    r'411d6327e9cdd7e14c307357ac64d337d52dc99d';

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

@ProviderFor(brokenVideoTracker)
final brokenVideoTrackerProvider = BrokenVideoTrackerProvider._();

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

final class BrokenVideoTrackerProvider
    extends
        $FunctionalProvider<
          AsyncValue<BrokenVideoTracker>,
          BrokenVideoTracker,
          FutureOr<BrokenVideoTracker>
        >
    with
        $FutureModifier<BrokenVideoTracker>,
        $FutureProvider<BrokenVideoTracker> {
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
  BrokenVideoTrackerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'brokenVideoTrackerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$brokenVideoTrackerHash();

  @$internal
  @override
  $FutureProviderElement<BrokenVideoTracker> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<BrokenVideoTracker> create(Ref ref) {
    return brokenVideoTracker(ref);
  }
}

String _$brokenVideoTrackerHash() =>
    r'a0b2af154496e50f633f49069986b3c0ee1f5585';

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

@ProviderFor(deadMediaFeedGuard)
final deadMediaFeedGuardProvider = DeadMediaFeedGuardProvider._();

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

final class DeadMediaFeedGuardProvider
    extends
        $FunctionalProvider<
          AsyncValue<DeadMediaFeedGuard>,
          DeadMediaFeedGuard,
          FutureOr<DeadMediaFeedGuard>
        >
    with
        $FutureModifier<DeadMediaFeedGuard>,
        $FutureProvider<DeadMediaFeedGuard> {
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
  DeadMediaFeedGuardProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'deadMediaFeedGuardProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$deadMediaFeedGuardHash();

  @$internal
  @override
  $FutureProviderElement<DeadMediaFeedGuard> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<DeadMediaFeedGuard> create(Ref ref) {
    return deadMediaFeedGuard(ref);
  }
}

String _$deadMediaFeedGuardHash() =>
    r'7b590e30c5cc2dc5bdf1d136b7d671dd66c4c18c';

/// Provider for VideoLocalStorage instance (SQLite-backed)
///
/// Creates a DbVideoLocalStorage for caching video events locally.
/// Used by VideosRepository for cache-first lookups.
///
/// Uses:
/// - NostrEventsDao from databaseProvider (for SQLite storage)

@ProviderFor(videoLocalStorage)
final videoLocalStorageProvider = VideoLocalStorageProvider._();

/// Provider for VideoLocalStorage instance (SQLite-backed)
///
/// Creates a DbVideoLocalStorage for caching video events locally.
/// Used by VideosRepository for cache-first lookups.
///
/// Uses:
/// - NostrEventsDao from databaseProvider (for SQLite storage)

final class VideoLocalStorageProvider
    extends
        $FunctionalProvider<
          VideoLocalStorage,
          VideoLocalStorage,
          VideoLocalStorage
        >
    with $Provider<VideoLocalStorage> {
  /// Provider for VideoLocalStorage instance (SQLite-backed)
  ///
  /// Creates a DbVideoLocalStorage for caching video events locally.
  /// Used by VideosRepository for cache-first lookups.
  ///
  /// Uses:
  /// - NostrEventsDao from databaseProvider (for SQLite storage)
  VideoLocalStorageProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'videoLocalStorageProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$videoLocalStorageHash();

  @$internal
  @override
  $ProviderElement<VideoLocalStorage> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  VideoLocalStorage create(Ref ref) {
    return videoLocalStorage(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VideoLocalStorage value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VideoLocalStorage>(value),
    );
  }
}

String _$videoLocalStorageHash() => r'0be44203ec8edf59105a013aae374c07637a3ba0';

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

@ProviderFor(videosRepository)
final videosRepositoryProvider = VideosRepositoryProvider._();

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

final class VideosRepositoryProvider
    extends
        $FunctionalProvider<
          VideosRepository,
          VideosRepository,
          VideosRepository
        >
    with $Provider<VideosRepository> {
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
  VideosRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'videosRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$videosRepositoryHash();

  @$internal
  @override
  $ProviderElement<VideosRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  VideosRepository create(Ref ref) {
    return videosRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VideosRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VideosRepository>(value),
    );
  }
}

String _$videosRepositoryHash() => r'ed76873b99e97dac7980173e4b0cefdc79a03aae';

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

@ProviderFor(likesRepository)
final likesRepositoryProvider = LikesRepositoryProvider._();

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

final class LikesRepositoryProvider
    extends
        $FunctionalProvider<LikesRepository, LikesRepository, LikesRepository>
    with $Provider<LikesRepository> {
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
  LikesRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'likesRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$likesRepositoryHash();

  @$internal
  @override
  $ProviderElement<LikesRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  LikesRepository create(Ref ref) {
    return likesRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LikesRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LikesRepository>(value),
    );
  }
}

String _$likesRepositoryHash() => r'8fde317eb74b77ef2ab6e5f985753b53c666c622';
