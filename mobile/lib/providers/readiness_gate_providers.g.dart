// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'readiness_gate_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider that checks if Nostr service is fully initialized and ready for subscriptions

@ProviderFor(nostrReady)
const nostrReadyProvider = NostrReadyProvider._();

/// Provider that checks if Nostr service is fully initialized and ready for subscriptions

final class NostrReadyProvider extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Provider that checks if Nostr service is fully initialized and ready for subscriptions
  const NostrReadyProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'nostrReadyProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$nostrReadyHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return nostrReady(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$nostrReadyHash() => r'c72999d51988ebb482534cb525e67cae832d2579';

/// Provider that combines all readiness gates to determine if app is ready for subscriptions

@ProviderFor(appReady)
const appReadyProvider = AppReadyProvider._();

/// Provider that combines all readiness gates to determine if app is ready for subscriptions

final class AppReadyProvider extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Provider that combines all readiness gates to determine if app is ready for subscriptions
  const AppReadyProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appReadyProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appReadyHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return appReady(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$appReadyHash() => r'883600dbc8e138ca825a2b8ab49f079b0d4a5325';

/// Provider that checks if the discovery/explore tab is currently active

@ProviderFor(isDiscoveryTabActive)
const isDiscoveryTabActiveProvider = IsDiscoveryTabActiveProvider._();

/// Provider that checks if the discovery/explore tab is currently active

final class IsDiscoveryTabActiveProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Provider that checks if the discovery/explore tab is currently active
  const IsDiscoveryTabActiveProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'isDiscoveryTabActiveProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$isDiscoveryTabActiveHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return isDiscoveryTabActive(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$isDiscoveryTabActiveHash() =>
    r'65a27a8efdc1f02b884368872ebc4978fabf0044';
