// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scheduled_posts_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Client for the relay's scheduled-post endpoints.
///
/// Signs NIP-98 against the relay HTTP origin, like the events endpoint:
/// `/api/schedule` lives beside `/api/events` in the relay process.

@ProviderFor(scheduleApiClient)
final scheduleApiClientProvider = ScheduleApiClientProvider._();

/// Client for the relay's scheduled-post endpoints.
///
/// Signs NIP-98 against the relay HTTP origin, like the events endpoint:
/// `/api/schedule` lives beside `/api/events` in the relay process.

final class ScheduleApiClientProvider
    extends
        $FunctionalProvider<
          ScheduleApiClient,
          ScheduleApiClient,
          ScheduleApiClient
        >
    with $Provider<ScheduleApiClient> {
  /// Client for the relay's scheduled-post endpoints.
  ///
  /// Signs NIP-98 against the relay HTTP origin, like the events endpoint:
  /// `/api/schedule` lives beside `/api/events` in the relay process.
  ScheduleApiClientProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'scheduleApiClientProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$scheduleApiClientHash();

  @$internal
  @override
  $ProviderElement<ScheduleApiClient> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ScheduleApiClient create(Ref ref) {
    return scheduleApiClient(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ScheduleApiClient value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ScheduleApiClient>(value),
    );
  }
}

String _$scheduleApiClientHash() => r'bc2f97db7f7b2e176f6a1a767042f03cade122d7';

/// The signed-in account's scheduled-post outbox, or null before the Nostr
/// session is ready for it. Rebuilt on every account change, so a row is
/// only ever read or written under its owner.

@ProviderFor(scheduledPostsRepository)
final scheduledPostsRepositoryProvider = ScheduledPostsRepositoryProvider._();

/// The signed-in account's scheduled-post outbox, or null before the Nostr
/// session is ready for it. Rebuilt on every account change, so a row is
/// only ever read or written under its owner.

final class ScheduledPostsRepositoryProvider
    extends
        $FunctionalProvider<
          ScheduledPostsRepository?,
          ScheduledPostsRepository?,
          ScheduledPostsRepository?
        >
    with $Provider<ScheduledPostsRepository?> {
  /// The signed-in account's scheduled-post outbox, or null before the Nostr
  /// session is ready for it. Rebuilt on every account change, so a row is
  /// only ever read or written under its owner.
  ScheduledPostsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'scheduledPostsRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$scheduledPostsRepositoryHash();

  @$internal
  @override
  $ProviderElement<ScheduledPostsRepository?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ScheduledPostsRepository? create(Ref ref) {
    return scheduledPostsRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ScheduledPostsRepository? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ScheduledPostsRepository?>(value),
    );
  }
}

String _$scheduledPostsRepositoryHash() =>
    r'325aa9d574a468756663e64dd36ac3292b409247';

/// Drives the outbox: hand-off retries, relay-state sync, the client-side
/// publish of posts the relay is late on, and the confirmed-publish side
/// effects. Activated from the app root so it runs whether or not the
/// Scheduled section is on screen.

@ProviderFor(scheduledPostCoordinator)
final scheduledPostCoordinatorProvider = ScheduledPostCoordinatorProvider._();

/// Drives the outbox: hand-off retries, relay-state sync, the client-side
/// publish of posts the relay is late on, and the confirmed-publish side
/// effects. Activated from the app root so it runs whether or not the
/// Scheduled section is on screen.

final class ScheduledPostCoordinatorProvider
    extends
        $FunctionalProvider<
          ScheduledPostCoordinator?,
          ScheduledPostCoordinator?,
          ScheduledPostCoordinator?
        >
    with $Provider<ScheduledPostCoordinator?> {
  /// Drives the outbox: hand-off retries, relay-state sync, the client-side
  /// publish of posts the relay is late on, and the confirmed-publish side
  /// effects. Activated from the app root so it runs whether or not the
  /// Scheduled section is on screen.
  ScheduledPostCoordinatorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'scheduledPostCoordinatorProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$scheduledPostCoordinatorHash();

  @$internal
  @override
  $ProviderElement<ScheduledPostCoordinator?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ScheduledPostCoordinator? create(Ref ref) {
    return scheduledPostCoordinator(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ScheduledPostCoordinator? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ScheduledPostCoordinator?>(value),
    );
  }
}

String _$scheduledPostCoordinatorHash() =>
    r'206eb7f77ccc445f4a4620cf02f643049c0bb67d';
