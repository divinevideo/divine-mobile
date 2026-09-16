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
    r'fa2f23bc17cbd4b283c25019de5e954a2199006a';

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
    r'ecf35e2997e56553a3ea0c561efd523f869e8f63';

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
    r'b987691a076907de474383432a578a7dc117b55d';

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
    r'aacfdb0c1e7d9618e328f545de3485ef79dffb4b';

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

String _$productEventQueueHash() => r'ee915061a8faf6d1f99a21a704358925fb023500';

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

String _$analyticsServiceHash() => r'acd4e2411f0e3959ecf7109906056043d7c4dca8';

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
    r'5c776e6395f831b88ed0b6447bfe48e260816494';

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
    r'009f0bd44219aa2999a3689b78cf57c312093375';

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

String _$hashtagServiceHash() => r'2b0727a4152eee27d7a1cf595cf5fe66050ee145';

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
    r'0030c3a41a37d211afaf14a8e90ff9983bd140b1';

/// Auto-sweep service for the durable `pending_reports` queue.
///
/// Uses [ContentReportingService] for every delivery attempt after local save.

@ProviderFor(reportRetryService)
final reportRetryServiceProvider = ReportRetryServiceProvider._();

/// Auto-sweep service for the durable `pending_reports` queue.
///
/// Uses [ContentReportingService] for every delivery attempt after local save.

final class ReportRetryServiceProvider
    extends
        $FunctionalProvider<
          AsyncValue<ReportRetryService?>,
          ReportRetryService?,
          FutureOr<ReportRetryService?>
        >
    with
        $FutureModifier<ReportRetryService?>,
        $FutureProvider<ReportRetryService?> {
  /// Auto-sweep service for the durable `pending_reports` queue.
  ///
  /// Uses [ContentReportingService] for every delivery attempt after local save.
  ReportRetryServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'reportRetryServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$reportRetryServiceHash();

  @$internal
  @override
  $FutureProviderElement<ReportRetryService?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ReportRetryService?> create(Ref ref) {
    return reportRetryService(ref);
  }
}

String _$reportRetryServiceHash() =>
    r'580e5f54ac229632f4b5712952c1a2126660befb';

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
