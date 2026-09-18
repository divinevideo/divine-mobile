// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'relay_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Connection status service for monitoring network connectivity

@ProviderFor(connectionStatusService)
final connectionStatusServiceProvider = ConnectionStatusServiceProvider._();

/// Connection status service for monitoring network connectivity

final class ConnectionStatusServiceProvider
    extends
        $FunctionalProvider<
          ConnectionStatusService,
          ConnectionStatusService,
          ConnectionStatusService
        >
    with $Provider<ConnectionStatusService> {
  /// Connection status service for monitoring network connectivity
  ConnectionStatusServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'connectionStatusServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$connectionStatusServiceHash();

  @$internal
  @override
  $ProviderElement<ConnectionStatusService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ConnectionStatusService create(Ref ref) {
    return connectionStatusService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ConnectionStatusService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ConnectionStatusService>(value),
    );
  }
}

String _$connectionStatusServiceHash() =>
    r'30fc9602e77f81edd6e26b19f6e36e0c82a02353';

/// Feeds [ConnectionStatusService] from the client's live relay statuses.
///
/// Until #8331 nothing called into that service at all, so `isOnline` stayed
/// at its initial `true` for the life of the app. Measured on a simulator over
/// 51 samples: the client reported `connectedRelayCount` of both 0 and 1 while
/// the service reported `isOnline=true` and `totalRelayCount=0` every single
/// time. Ten gates read that flag, so the offline queue never engaged for
/// connectivity reasons and a follow made while relays were down was dropped
/// rather than queued.
///
/// This is the one writer. It republishes the whole pool on every frame, so a
/// de-configured relay leaves no stale entry behind, and it reports dialling
/// separately so `isConnecting` means something too.
///
/// keepAlive with no UI consumer: activated by `AppShellSideEffects`,
/// alongside `relaySetChangeBridge`, which reads the same stream.

@ProviderFor(relayConnectionStatusBridge)
final relayConnectionStatusBridgeProvider =
    RelayConnectionStatusBridgeProvider._();

/// Feeds [ConnectionStatusService] from the client's live relay statuses.
///
/// Until #8331 nothing called into that service at all, so `isOnline` stayed
/// at its initial `true` for the life of the app. Measured on a simulator over
/// 51 samples: the client reported `connectedRelayCount` of both 0 and 1 while
/// the service reported `isOnline=true` and `totalRelayCount=0` every single
/// time. Ten gates read that flag, so the offline queue never engaged for
/// connectivity reasons and a follow made while relays were down was dropped
/// rather than queued.
///
/// This is the one writer. It republishes the whole pool on every frame, so a
/// de-configured relay leaves no stale entry behind, and it reports dialling
/// separately so `isConnecting` means something too.
///
/// keepAlive with no UI consumer: activated by `AppShellSideEffects`,
/// alongside `relaySetChangeBridge`, which reads the same stream.

final class RelayConnectionStatusBridgeProvider
    extends $FunctionalProvider<void, void, void>
    with $Provider<void> {
  /// Feeds [ConnectionStatusService] from the client's live relay statuses.
  ///
  /// Until #8331 nothing called into that service at all, so `isOnline` stayed
  /// at its initial `true` for the life of the app. Measured on a simulator over
  /// 51 samples: the client reported `connectedRelayCount` of both 0 and 1 while
  /// the service reported `isOnline=true` and `totalRelayCount=0` every single
  /// time. Ten gates read that flag, so the offline queue never engaged for
  /// connectivity reasons and a follow made while relays were down was dropped
  /// rather than queued.
  ///
  /// This is the one writer. It republishes the whole pool on every frame, so a
  /// de-configured relay leaves no stale entry behind, and it reports dialling
  /// separately so `isConnecting` means something too.
  ///
  /// keepAlive with no UI consumer: activated by `AppShellSideEffects`,
  /// alongside `relaySetChangeBridge`, which reads the same stream.
  RelayConnectionStatusBridgeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'relayConnectionStatusBridgeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$relayConnectionStatusBridgeHash();

  @$internal
  @override
  $ProviderElement<void> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  void create(Ref ref) {
    return relayConnectionStatusBridge(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$relayConnectionStatusBridgeHash() =>
    r'ff695eed266cadc488cd59b80cf1c53d82e5c25d';

/// Relay capability service for detecting NIP-11 Divine extensions

@ProviderFor(relayCapabilityService)
final relayCapabilityServiceProvider = RelayCapabilityServiceProvider._();

/// Relay capability service for detecting NIP-11 Divine extensions

final class RelayCapabilityServiceProvider
    extends
        $FunctionalProvider<
          RelayCapabilityService,
          RelayCapabilityService,
          RelayCapabilityService
        >
    with $Provider<RelayCapabilityService> {
  /// Relay capability service for detecting NIP-11 Divine extensions
  RelayCapabilityServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'relayCapabilityServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$relayCapabilityServiceHash();

  @$internal
  @override
  $ProviderElement<RelayCapabilityService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  RelayCapabilityService create(Ref ref) {
    return relayCapabilityService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RelayCapabilityService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RelayCapabilityService>(value),
    );
  }
}

String _$relayCapabilityServiceHash() =>
    r'ed5dd07c834c2921fe4a8d9c2f5ee42c72c446a3';

/// Relay statistics service for tracking per-relay metrics

@ProviderFor(relayStatisticsService)
final relayStatisticsServiceProvider = RelayStatisticsServiceProvider._();

/// Relay statistics service for tracking per-relay metrics

final class RelayStatisticsServiceProvider
    extends
        $FunctionalProvider<
          RelayStatisticsService,
          RelayStatisticsService,
          RelayStatisticsService
        >
    with $Provider<RelayStatisticsService> {
  /// Relay statistics service for tracking per-relay metrics
  RelayStatisticsServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'relayStatisticsServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$relayStatisticsServiceHash();

  @$internal
  @override
  $ProviderElement<RelayStatisticsService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  RelayStatisticsService create(Ref ref) {
    return relayStatisticsService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RelayStatisticsService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RelayStatisticsService>(value),
    );
  }
}

String _$relayStatisticsServiceHash() =>
    r'3343641d19897bc7431645b760b90f115afc827d';

/// Stream provider for reactive relay statistics updates
/// Use this provider when you need UI to rebuild when statistics change

@ProviderFor(relayStatisticsStream)
final relayStatisticsStreamProvider = RelayStatisticsStreamProvider._();

/// Stream provider for reactive relay statistics updates
/// Use this provider when you need UI to rebuild when statistics change

final class RelayStatisticsStreamProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, RelayStatistics>>,
          Map<String, RelayStatistics>,
          Stream<Map<String, RelayStatistics>>
        >
    with
        $FutureModifier<Map<String, RelayStatistics>>,
        $StreamProvider<Map<String, RelayStatistics>> {
  /// Stream provider for reactive relay statistics updates
  /// Use this provider when you need UI to rebuild when statistics change
  RelayStatisticsStreamProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'relayStatisticsStreamProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$relayStatisticsStreamHash();

  @$internal
  @override
  $StreamProviderElement<Map<String, RelayStatistics>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<Map<String, RelayStatistics>> create(Ref ref) {
    return relayStatisticsStream(ref);
  }
}

String _$relayStatisticsStreamHash() =>
    r'b8256f2ad21b0ca38274fbd80a93049e8bd59858';

/// Bridge provider that connects NostrClient relay status updates to
/// RelayStatisticsService.
///
/// Tracks connection/disconnection events via the relay status stream and
/// periodically syncs per-relay SDK counters (events received, queries sent,
/// errors) so each relay displays its own real statistics.
///
/// Activated by `AppShellSideEffects` — the 3s counter timer is recurring
/// work a signed-out user should not pay for.

@ProviderFor(relayStatisticsBridge)
final relayStatisticsBridgeProvider = RelayStatisticsBridgeProvider._();

/// Bridge provider that connects NostrClient relay status updates to
/// RelayStatisticsService.
///
/// Tracks connection/disconnection events via the relay status stream and
/// periodically syncs per-relay SDK counters (events received, queries sent,
/// errors) so each relay displays its own real statistics.
///
/// Activated by `AppShellSideEffects` — the 3s counter timer is recurring
/// work a signed-out user should not pay for.

final class RelayStatisticsBridgeProvider
    extends $FunctionalProvider<void, void, void>
    with $Provider<void> {
  /// Bridge provider that connects NostrClient relay status updates to
  /// RelayStatisticsService.
  ///
  /// Tracks connection/disconnection events via the relay status stream and
  /// periodically syncs per-relay SDK counters (events received, queries sent,
  /// errors) so each relay displays its own real statistics.
  ///
  /// Activated by `AppShellSideEffects` — the 3s counter timer is recurring
  /// work a signed-out user should not pay for.
  RelayStatisticsBridgeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'relayStatisticsBridgeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$relayStatisticsBridgeHash();

  @$internal
  @override
  $ProviderElement<void> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  void create(Ref ref) {
    return relayStatisticsBridge(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$relayStatisticsBridgeHash() =>
    r'4c54f742c7d5dcc916ef7a3c0e36a1d1b5d26e5a';

/// Bridge provider that detects when the configured relay set changes
/// (relays added or removed) and triggers a full feed reset+resubscribe.
/// Debounces for 2 seconds to collapse rapid add/remove operations.
/// Only reacts to set membership changes, not connection state flapping.

@ProviderFor(relaySetChangeBridge)
final relaySetChangeBridgeProvider = RelaySetChangeBridgeProvider._();

/// Bridge provider that detects when the configured relay set changes
/// (relays added or removed) and triggers a full feed reset+resubscribe.
/// Debounces for 2 seconds to collapse rapid add/remove operations.
/// Only reacts to set membership changes, not connection state flapping.

final class RelaySetChangeBridgeProvider
    extends $FunctionalProvider<void, void, void>
    with $Provider<void> {
  /// Bridge provider that detects when the configured relay set changes
  /// (relays added or removed) and triggers a full feed reset+resubscribe.
  /// Debounces for 2 seconds to collapse rapid add/remove operations.
  /// Only reacts to set membership changes, not connection state flapping.
  RelaySetChangeBridgeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'relaySetChangeBridgeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$relaySetChangeBridgeHash();

  @$internal
  @override
  $ProviderElement<void> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  void create(Ref ref) {
    return relaySetChangeBridge(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$relaySetChangeBridgeHash() =>
    r'09def62980a90972f23d5b1143b934d00b4bc091';
