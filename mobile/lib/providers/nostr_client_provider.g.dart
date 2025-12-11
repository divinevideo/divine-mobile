// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'nostr_client_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider to allow overriding AuthService in tests

@ProviderFor(authServiceOverride)
const authServiceOverrideProvider = AuthServiceOverrideProvider._();

/// Provider to allow overriding AuthService in tests

final class AuthServiceOverrideProvider
    extends $FunctionalProvider<AuthService?, AuthService?, AuthService?>
    with $Provider<AuthService?> {
  /// Provider to allow overriding AuthService in tests
  const AuthServiceOverrideProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authServiceOverrideProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authServiceOverrideHash();

  @$internal
  @override
  $ProviderElement<AuthService?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AuthService? create(Ref ref) {
    return authServiceOverride(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AuthService? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AuthService?>(value),
    );
  }
}

String _$authServiceOverrideHash() =>
    r'394a02c9684d199be39d13df8c5174b5007adf1f';

/// Provider that manages NostrClient lifecycle based on auth state
///
/// Returns null when:
/// - User is not authenticated
/// - User is in authenticating/checking state
/// - No key container is available
///
/// Creates a new NostrClient when:
/// - User becomes authenticated with a valid key container
///
/// Disposes the old client when:
/// - User signs out
/// - Auth state changes to unauthenticated

@ProviderFor(nostrClient)
const nostrClientProvider = NostrClientProvider._();

/// Provider that manages NostrClient lifecycle based on auth state
///
/// Returns null when:
/// - User is not authenticated
/// - User is in authenticating/checking state
/// - No key container is available
///
/// Creates a new NostrClient when:
/// - User becomes authenticated with a valid key container
///
/// Disposes the old client when:
/// - User signs out
/// - Auth state changes to unauthenticated

final class NostrClientProvider
    extends $FunctionalProvider<NostrClient?, NostrClient?, NostrClient?>
    with $Provider<NostrClient?> {
  /// Provider that manages NostrClient lifecycle based on auth state
  ///
  /// Returns null when:
  /// - User is not authenticated
  /// - User is in authenticating/checking state
  /// - No key container is available
  ///
  /// Creates a new NostrClient when:
  /// - User becomes authenticated with a valid key container
  ///
  /// Disposes the old client when:
  /// - User signs out
  /// - Auth state changes to unauthenticated
  const NostrClientProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'nostrClientProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$nostrClientHash();

  @$internal
  @override
  $ProviderElement<NostrClient?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  NostrClient? create(Ref ref) {
    return nostrClient(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NostrClient? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NostrClient?>(value),
    );
  }
}

String _$nostrClientHash() => r'c714f6a99df9a94c6e214d9157cabda2241ff146';
