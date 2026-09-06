// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'social_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Pending action service for offline sync of social actions
/// Returns null when not authenticated (no userPubkey available)

@ProviderFor(pendingActionService)
final pendingActionServiceProvider = PendingActionServiceProvider._();

/// Pending action service for offline sync of social actions
/// Returns null when not authenticated (no userPubkey available)

final class PendingActionServiceProvider
    extends
        $FunctionalProvider<
          PendingActionService?,
          PendingActionService?,
          PendingActionService?
        >
    with $Provider<PendingActionService?> {
  /// Pending action service for offline sync of social actions
  /// Returns null when not authenticated (no userPubkey available)
  PendingActionServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pendingActionServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pendingActionServiceHash();

  @$internal
  @override
  $ProviderElement<PendingActionService?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PendingActionService? create(Ref ref) {
    return pendingActionService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PendingActionService? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PendingActionService?>(value),
    );
  }
}

String _$pendingActionServiceHash() =>
    r'67a3a30b8cc1072263ce47f4e2bb3c34fa876fa1';

/// Auto-sweep service for the durable `outgoing_dms` queue.
///
/// Listens to app-foreground transitions and re-publishes the missing
/// self-wrap for any row in `recipient: sent / self: failed` state via
/// [DmRepository.recoverSelfWrap]. Closes the gap left by the
/// SnackBar-only manual retry from PR #4106 — see issue #4124.
///
/// The service is keepAlive but has no UI consumer, so it is read
/// eagerly at app shell startup (`main.dart`) so the foreground
/// subscription is wired up.
///
/// Returns null when the user is not authenticated or when the current Nostr
/// session is not ready — the underlying [DmRepository.recoverSelfWrap]
/// requires `setCredentials` to have run, and gating here is cleaner than
/// catching `StateError` in every sweep pass.

@ProviderFor(outgoingDmRetryService)
final outgoingDmRetryServiceProvider = OutgoingDmRetryServiceProvider._();

/// Auto-sweep service for the durable `outgoing_dms` queue.
///
/// Listens to app-foreground transitions and re-publishes the missing
/// self-wrap for any row in `recipient: sent / self: failed` state via
/// [DmRepository.recoverSelfWrap]. Closes the gap left by the
/// SnackBar-only manual retry from PR #4106 — see issue #4124.
///
/// The service is keepAlive but has no UI consumer, so it is read
/// eagerly at app shell startup (`main.dart`) so the foreground
/// subscription is wired up.
///
/// Returns null when the user is not authenticated or when the current Nostr
/// session is not ready — the underlying [DmRepository.recoverSelfWrap]
/// requires `setCredentials` to have run, and gating here is cleaner than
/// catching `StateError` in every sweep pass.

final class OutgoingDmRetryServiceProvider
    extends
        $FunctionalProvider<
          OutgoingDmRetryService?,
          OutgoingDmRetryService?,
          OutgoingDmRetryService?
        >
    with $Provider<OutgoingDmRetryService?> {
  /// Auto-sweep service for the durable `outgoing_dms` queue.
  ///
  /// Listens to app-foreground transitions and re-publishes the missing
  /// self-wrap for any row in `recipient: sent / self: failed` state via
  /// [DmRepository.recoverSelfWrap]. Closes the gap left by the
  /// SnackBar-only manual retry from PR #4106 — see issue #4124.
  ///
  /// The service is keepAlive but has no UI consumer, so it is read
  /// eagerly at app shell startup (`main.dart`) so the foreground
  /// subscription is wired up.
  ///
  /// Returns null when the user is not authenticated or when the current Nostr
  /// session is not ready — the underlying [DmRepository.recoverSelfWrap]
  /// requires `setCredentials` to have run, and gating here is cleaner than
  /// catching `StateError` in every sweep pass.
  OutgoingDmRetryServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'outgoingDmRetryServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$outgoingDmRetryServiceHash();

  @$internal
  @override
  $ProviderElement<OutgoingDmRetryService?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  OutgoingDmRetryService? create(Ref ref) {
    return outgoingDmRetryService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(OutgoingDmRetryService? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<OutgoingDmRetryService?>(value),
    );
  }
}

String _$outgoingDmRetryServiceHash() =>
    r'8be3ee6c65e8993b5892200a472a9792ca187ebf';

/// Auto-sweep service that re-drives undelivered DM reactions (publish failed
/// or interrupted mid-send) on app-foreground transitions via
/// [DmReactionsRepository.retry].
///
/// Gives reactions the durable delivery that DM messages already get from
/// [OutgoingDmRetryService] + the `outgoing_dms` queue: a reaction whose
/// recipient gift wrap failed to land (common on a flaky relay) is otherwise
/// lost with no automatic recovery. keepAlive with no UI consumer, so it is
/// read eagerly at app shell startup (`main.dart`) to wire the foreground
/// subscription.
///
/// Returns null until the user is authenticated and the Nostr session is
/// ready — the same readiness the reaction repository's `setCredentials`
/// needs before a retry can publish.

@ProviderFor(dmReactionRetryService)
final dmReactionRetryServiceProvider = DmReactionRetryServiceProvider._();

/// Auto-sweep service that re-drives undelivered DM reactions (publish failed
/// or interrupted mid-send) on app-foreground transitions via
/// [DmReactionsRepository.retry].
///
/// Gives reactions the durable delivery that DM messages already get from
/// [OutgoingDmRetryService] + the `outgoing_dms` queue: a reaction whose
/// recipient gift wrap failed to land (common on a flaky relay) is otherwise
/// lost with no automatic recovery. keepAlive with no UI consumer, so it is
/// read eagerly at app shell startup (`main.dart`) to wire the foreground
/// subscription.
///
/// Returns null until the user is authenticated and the Nostr session is
/// ready — the same readiness the reaction repository's `setCredentials`
/// needs before a retry can publish.

final class DmReactionRetryServiceProvider
    extends
        $FunctionalProvider<
          DmReactionRetryService?,
          DmReactionRetryService?,
          DmReactionRetryService?
        >
    with $Provider<DmReactionRetryService?> {
  /// Auto-sweep service that re-drives undelivered DM reactions (publish failed
  /// or interrupted mid-send) on app-foreground transitions via
  /// [DmReactionsRepository.retry].
  ///
  /// Gives reactions the durable delivery that DM messages already get from
  /// [OutgoingDmRetryService] + the `outgoing_dms` queue: a reaction whose
  /// recipient gift wrap failed to land (common on a flaky relay) is otherwise
  /// lost with no automatic recovery. keepAlive with no UI consumer, so it is
  /// read eagerly at app shell startup (`main.dart`) to wire the foreground
  /// subscription.
  ///
  /// Returns null until the user is authenticated and the Nostr session is
  /// ready — the same readiness the reaction repository's `setCredentials`
  /// needs before a retry can publish.
  DmReactionRetryServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dmReactionRetryServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dmReactionRetryServiceHash();

  @$internal
  @override
  $ProviderElement<DmReactionRetryService?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DmReactionRetryService? create(Ref ref) {
    return dmReactionRetryService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DmReactionRetryService? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DmReactionRetryService?>(value),
    );
  }
}

String _$dmReactionRetryServiceHash() =>
    r'3694c8f5a720cac8e3c25beea00d3852deb1c003';

/// Auto-sweep service for the durable `pending_view_events` queue.

@ProviderFor(viewEventRetryService)
final viewEventRetryServiceProvider = ViewEventRetryServiceProvider._();

/// Auto-sweep service for the durable `pending_view_events` queue.

final class ViewEventRetryServiceProvider
    extends
        $FunctionalProvider<
          ViewEventRetryService?,
          ViewEventRetryService?,
          ViewEventRetryService?
        >
    with $Provider<ViewEventRetryService?> {
  /// Auto-sweep service for the durable `pending_view_events` queue.
  ViewEventRetryServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'viewEventRetryServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$viewEventRetryServiceHash();

  @$internal
  @override
  $ProviderElement<ViewEventRetryService?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ViewEventRetryService? create(Ref ref) {
    return viewEventRetryService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ViewEventRetryService? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ViewEventRetryService?>(value),
    );
  }
}

String _$viewEventRetryServiceHash() =>
    r'3d2bf5f8def6302b9cb64d60bc35e8a792dcc15f';

/// Durable queue for first-party product analytics events.

@ProviderFor(productEventQueue)
final productEventQueueProvider = ProductEventQueueProvider._();

/// Durable queue for first-party product analytics events.

final class ProductEventQueueProvider
    extends
        $FunctionalProvider<
          ProductEventQueue,
          ProductEventQueue,
          ProductEventQueue
        >
    with $Provider<ProductEventQueue> {
  /// Durable queue for first-party product analytics events.
  ProductEventQueueProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'productEventQueueProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$productEventQueueHash();

  @$internal
  @override
  $ProviderElement<ProductEventQueue> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ProductEventQueue create(Ref ref) {
    return productEventQueue(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ProductEventQueue value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ProductEventQueue>(value),
    );
  }
}

String _$productEventQueueHash() => r'8c22586a5a80dc049f1ff4726288fd754bfcaaf8';

@ProviderFor(analyticsService)
final analyticsServiceProvider = AnalyticsServiceProvider._();

final class AnalyticsServiceProvider
    extends
        $FunctionalProvider<
          AnalyticsService,
          AnalyticsService,
          AnalyticsService
        >
    with $Provider<AnalyticsService> {
  AnalyticsServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'analyticsServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$analyticsServiceHash();

  @$internal
  @override
  $ProviderElement<AnalyticsService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AnalyticsService create(Ref ref) {
    return analyticsService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AnalyticsService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AnalyticsService>(value),
    );
  }
}

String _$analyticsServiceHash() => r'039150966ca30cb386cb1b25496c0233ff8dd6fc';

/// Hashtag cache service for persistent hashtag storage

@ProviderFor(hashtagCacheService)
final hashtagCacheServiceProvider = HashtagCacheServiceProvider._();

/// Hashtag cache service for persistent hashtag storage

final class HashtagCacheServiceProvider
    extends
        $FunctionalProvider<
          HashtagCacheService,
          HashtagCacheService,
          HashtagCacheService
        >
    with $Provider<HashtagCacheService> {
  /// Hashtag cache service for persistent hashtag storage
  HashtagCacheServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'hashtagCacheServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$hashtagCacheServiceHash();

  @$internal
  @override
  $ProviderElement<HashtagCacheService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  HashtagCacheService create(Ref ref) {
    return hashtagCacheService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(HashtagCacheService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<HashtagCacheService>(value),
    );
  }
}

String _$hashtagCacheServiceHash() =>
    r'9cc0bce9cded786f95dc83e7bf6dbcbc2602e907';

/// Draft storage service for persisting vine drafts

@ProviderFor(draftStorageService)
final draftStorageServiceProvider = DraftStorageServiceProvider._();

/// Draft storage service for persisting vine drafts

final class DraftStorageServiceProvider
    extends
        $FunctionalProvider<
          DraftStorageService,
          DraftStorageService,
          DraftStorageService
        >
    with $Provider<DraftStorageService> {
  /// Draft storage service for persisting vine drafts
  DraftStorageServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'draftStorageServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$draftStorageServiceHash();

  @$internal
  @override
  $ProviderElement<DraftStorageService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DraftStorageService create(Ref ref) {
    return draftStorageService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DraftStorageService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DraftStorageService>(value),
    );
  }
}

String _$draftStorageServiceHash() =>
    r'73d4186bb7ee7270b4edcb9b289e31feefd923ee';

/// Clip library service for persisting individual video clips

@ProviderFor(clipLibraryService)
final clipLibraryServiceProvider = ClipLibraryServiceProvider._();

/// Clip library service for persisting individual video clips

final class ClipLibraryServiceProvider
    extends
        $FunctionalProvider<
          ClipLibraryService,
          ClipLibraryService,
          ClipLibraryService
        >
    with $Provider<ClipLibraryService> {
  /// Clip library service for persisting individual video clips
  ClipLibraryServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'clipLibraryServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$clipLibraryServiceHash();

  @$internal
  @override
  $ProviderElement<ClipLibraryService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ClipLibraryService create(Ref ref) {
    return clipLibraryService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ClipLibraryService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ClipLibraryService>(value),
    );
  }
}

String _$clipLibraryServiceHash() =>
    r'b96264b82d1da2bdc1b06218e444f4bc6298a31e';

/// User data cleanup service for handling identity changes
/// Prevents data leakage between different Nostr accounts

@ProviderFor(userDataCleanupService)
final userDataCleanupServiceProvider = UserDataCleanupServiceProvider._();

/// User data cleanup service for handling identity changes
/// Prevents data leakage between different Nostr accounts

final class UserDataCleanupServiceProvider
    extends
        $FunctionalProvider<
          UserDataCleanupService,
          UserDataCleanupService,
          UserDataCleanupService
        >
    with $Provider<UserDataCleanupService> {
  /// User data cleanup service for handling identity changes
  /// Prevents data leakage between different Nostr accounts
  UserDataCleanupServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'userDataCleanupServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$userDataCleanupServiceHash();

  @$internal
  @override
  $ProviderElement<UserDataCleanupService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  UserDataCleanupService create(Ref ref) {
    return userDataCleanupService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UserDataCleanupService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UserDataCleanupService>(value),
    );
  }
}

String _$userDataCleanupServiceHash() =>
    r'278eb10d802973eb4e950969d4cde155ddedc822';

/// Hashtag service depends on Video event service and cache service

@ProviderFor(hashtagService)
final hashtagServiceProvider = HashtagServiceProvider._();

/// Hashtag service depends on Video event service and cache service

final class HashtagServiceProvider
    extends $FunctionalProvider<HashtagService, HashtagService, HashtagService>
    with $Provider<HashtagService> {
  /// Hashtag service depends on Video event service and cache service
  HashtagServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'hashtagServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$hashtagServiceHash();

  @$internal
  @override
  $ProviderElement<HashtagService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  HashtagService create(Ref ref) {
    return hashtagService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(HashtagService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<HashtagService>(value),
    );
  }
}

String _$hashtagServiceHash() => r'5cd38d3c2e8d78a6f7b74a72b650d79e28938fe4';

/// Social service for follow sets (NIP-51 Kind 30000).
///
/// Follower count stats have moved to [FollowRepository].

@ProviderFor(socialService)
final socialServiceProvider = SocialServiceProvider._();

/// Social service for follow sets (NIP-51 Kind 30000).
///
/// Follower count stats have moved to [FollowRepository].

final class SocialServiceProvider
    extends $FunctionalProvider<SocialService, SocialService, SocialService>
    with $Provider<SocialService> {
  /// Social service for follow sets (NIP-51 Kind 30000).
  ///
  /// Follower count stats have moved to [FollowRepository].
  SocialServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'socialServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$socialServiceHash();

  @$internal
  @override
  $ProviderElement<SocialService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SocialService create(Ref ref) {
    return socialService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SocialService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SocialService>(value),
    );
  }
}

String _$socialServiceHash() => r'025a0d7f80743f11d040e4867c012397282404b3';

/// Content reporting service for NIP-56 compliance

@ProviderFor(contentReportingService)
final contentReportingServiceProvider = ContentReportingServiceProvider._();

/// Content reporting service for NIP-56 compliance

final class ContentReportingServiceProvider
    extends
        $FunctionalProvider<
          AsyncValue<ContentReportingService>,
          ContentReportingService,
          FutureOr<ContentReportingService>
        >
    with
        $FutureModifier<ContentReportingService>,
        $FutureProvider<ContentReportingService> {
  /// Content reporting service for NIP-56 compliance
  ContentReportingServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'contentReportingServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$contentReportingServiceHash();

  @$internal
  @override
  $FutureProviderElement<ContentReportingService> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ContentReportingService> create(Ref ref) {
    return contentReportingService(ref);
  }
}

String _$contentReportingServiceHash() =>
    r'5f32ae82aae7471e3e3dd008a011607def6bc149';

/// Content deletion service for NIP-09 delete events

@ProviderFor(contentDeletionService)
final contentDeletionServiceProvider = ContentDeletionServiceProvider._();

/// Content deletion service for NIP-09 delete events

final class ContentDeletionServiceProvider
    extends
        $FunctionalProvider<
          AsyncValue<ContentDeletionService>,
          ContentDeletionService,
          FutureOr<ContentDeletionService>
        >
    with
        $FutureModifier<ContentDeletionService>,
        $FutureProvider<ContentDeletionService> {
  /// Content deletion service for NIP-09 delete events
  ContentDeletionServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'contentDeletionServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$contentDeletionServiceHash();

  @$internal
  @override
  $FutureProviderElement<ContentDeletionService> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ContentDeletionService> create(Ref ref) {
    return contentDeletionService(ref);
  }
}

String _$contentDeletionServiceHash() =>
    r'de8df8e0106036b306b61ef2970e6b43ce1be68f';
