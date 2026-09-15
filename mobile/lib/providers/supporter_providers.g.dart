// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'supporter_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Whether this build can talk to the supporter Worker at all.
///
/// Equivalent to `supporterApiClientProvider != null`, because an empty base
/// URL is the only thing that makes that provider null — but it answers the
/// question without *building* the client, which pulls in the NIP-98 and
/// secure-auth services and the work they start. A settings tile deciding
/// whether to render, and a route guard evaluating a redirect, should not pay
/// that cost or leave those services running behind them.

@ProviderFor(supporterApiConfigured)
final supporterApiConfiguredProvider = SupporterApiConfiguredProvider._();

/// Whether this build can talk to the supporter Worker at all.
///
/// Equivalent to `supporterApiClientProvider != null`, because an empty base
/// URL is the only thing that makes that provider null — but it answers the
/// question without *building* the client, which pulls in the NIP-98 and
/// secure-auth services and the work they start. A settings tile deciding
/// whether to render, and a route guard evaluating a redirect, should not pay
/// that cost or leave those services running behind them.

final class SupporterApiConfiguredProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Whether this build can talk to the supporter Worker at all.
  ///
  /// Equivalent to `supporterApiClientProvider != null`, because an empty base
  /// URL is the only thing that makes that provider null — but it answers the
  /// question without *building* the client, which pulls in the NIP-98 and
  /// secure-auth services and the work they start. A settings tile deciding
  /// whether to render, and a route guard evaluating a redirect, should not pay
  /// that cost or leave those services running behind them.
  SupporterApiConfiguredProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'supporterApiConfiguredProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$supporterApiConfiguredHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return supporterApiConfigured(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$supporterApiConfiguredHash() =>
    r'ee4d0338dca7a117c44516d34a75073fe89331c8';

/// The NIP-98 authenticated supporter Worker client, when configured.

@ProviderFor(supporterApiClient)
final supporterApiClientProvider = SupporterApiClientProvider._();

/// The NIP-98 authenticated supporter Worker client, when configured.

final class SupporterApiClientProvider
    extends
        $FunctionalProvider<
          SupporterApiClient?,
          SupporterApiClient?,
          SupporterApiClient?
        >
    with $Provider<SupporterApiClient?> {
  /// The NIP-98 authenticated supporter Worker client, when configured.
  SupporterApiClientProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'supporterApiClientProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$supporterApiClientHash();

  @$internal
  @override
  $ProviderElement<SupporterApiClient?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SupporterApiClient? create(Ref ref) {
    return supporterApiClient(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SupporterApiClient? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SupporterApiClient?>(value),
    );
  }
}

String _$supporterApiClientHash() =>
    r'b2fccc742b9187925bc86a96aab4bba3294894de';

/// The store-backed [EntitlementValidator] for the current platform.
///
/// Returns an [InAppPurchaseValidator] on iOS/Android and a
/// [StubEntitlementValidator] elsewhere so the rest of the app can treat the
/// supporter feature uniformly.

@ProviderFor(entitlementValidator)
final entitlementValidatorProvider = EntitlementValidatorProvider._();

/// The store-backed [EntitlementValidator] for the current platform.
///
/// Returns an [InAppPurchaseValidator] on iOS/Android and a
/// [StubEntitlementValidator] elsewhere so the rest of the app can treat the
/// supporter feature uniformly.

final class EntitlementValidatorProvider
    extends
        $FunctionalProvider<
          EntitlementValidator,
          EntitlementValidator,
          EntitlementValidator
        >
    with $Provider<EntitlementValidator> {
  /// The store-backed [EntitlementValidator] for the current platform.
  ///
  /// Returns an [InAppPurchaseValidator] on iOS/Android and a
  /// [StubEntitlementValidator] elsewhere so the rest of the app can treat the
  /// supporter feature uniformly.
  EntitlementValidatorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'entitlementValidatorProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$entitlementValidatorHash();

  @$internal
  @override
  $ProviderElement<EntitlementValidator> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  EntitlementValidator create(Ref ref) {
    return entitlementValidator(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(EntitlementValidator value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<EntitlementValidator>(value),
    );
  }
}

String _$entitlementValidatorHash() =>
    r'8e01226ddfb565538f6d0e1512371490b1ce85ac';

/// The account-scoped [SupporterRepository] that owns the cached entitlement.

@ProviderFor(supporterRepository)
final supporterRepositoryProvider = SupporterRepositoryProvider._();

/// The account-scoped [SupporterRepository] that owns the cached entitlement.

final class SupporterRepositoryProvider
    extends
        $FunctionalProvider<
          SupporterRepository,
          SupporterRepository,
          SupporterRepository
        >
    with $Provider<SupporterRepository> {
  /// The account-scoped [SupporterRepository] that owns the cached entitlement.
  SupporterRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'supporterRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$supporterRepositoryHash();

  @$internal
  @override
  $ProviderElement<SupporterRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SupporterRepository create(Ref ref) {
    return supporterRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SupporterRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SupporterRepository>(value),
    );
  }
}

String _$supporterRepositoryHash() =>
    r'3e2f3f1fa5ec502364222a5bf658af9ffee4f48b';
