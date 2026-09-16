// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'nostr_client_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Indirection layer over [NostrServiceFactory.create] so tests can
/// substitute a fake factory without touching the real relay/network
/// code path. Production builds use this provider transparently.

@ProviderFor(nostrClientFactory)
final nostrClientFactoryProvider = NostrClientFactoryProvider._();

/// Indirection layer over [NostrServiceFactory.create] so tests can
/// substitute a fake factory without touching the real relay/network
/// code path. Production builds use this provider transparently.

final class NostrClientFactoryProvider
    extends
        $FunctionalProvider<
          NostrClientFactory,
          NostrClientFactory,
          NostrClientFactory
        >
    with $Provider<NostrClientFactory> {
  /// Indirection layer over [NostrServiceFactory.create] so tests can
  /// substitute a fake factory without touching the real relay/network
  /// code path. Production builds use this provider transparently.
  NostrClientFactoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'nostrClientFactoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$nostrClientFactoryHash();

  @$internal
  @override
  $ProviderElement<NostrClientFactory> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  NostrClientFactory create(Ref ref) {
    return nostrClientFactory(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NostrClientFactory value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NostrClientFactory>(value),
    );
  }
}

String _$nostrClientFactoryHash() =>
    r'd63243619eb5ca7a5bd32e56f4a50ffe09b7a175';

/// Core Nostr service via NostrClient for relay communication
/// Uses a Notifier to react to auth state changes and recreate the client
/// when the keyContainer changes (e.g., user signs out and signs in with different keys)

@ProviderFor(NostrService)
final nostrServiceProvider = NostrServiceProvider._();

/// Core Nostr service via NostrClient for relay communication
/// Uses a Notifier to react to auth state changes and recreate the client
/// when the keyContainer changes (e.g., user signs out and signs in with different keys)
final class NostrServiceProvider
    extends $NotifierProvider<NostrService, NostrClient> {
  /// Core Nostr service via NostrClient for relay communication
  /// Uses a Notifier to react to auth state changes and recreate the client
  /// when the keyContainer changes (e.g., user signs out and signs in with different keys)
  NostrServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'nostrServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$nostrServiceHash();

  @$internal
  @override
  NostrService create() => NostrService();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NostrClient value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NostrClient>(value),
    );
  }
}

String _$nostrServiceHash() => r'd78a330fc4e4ef197c923b908c43d3ae8f32b9e4';

/// Core Nostr service via NostrClient for relay communication
/// Uses a Notifier to react to auth state changes and recreate the client
/// when the keyContainer changes (e.g., user signs out and signs in with different keys)

abstract class _$NostrService extends $Notifier<NostrClient> {
  NostrClient build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<NostrClient, NostrClient>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<NostrClient, NostrClient>,
              NostrClient,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
