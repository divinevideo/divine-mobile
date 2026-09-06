// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Secure key storage service (foundational service)

@ProviderFor(secureKeyStorage)
final secureKeyStorageProvider = SecureKeyStorageProvider._();

/// Secure key storage service (foundational service)

final class SecureKeyStorageProvider
    extends
        $FunctionalProvider<
          SecureKeyStorage,
          SecureKeyStorage,
          SecureKeyStorage
        >
    with $Provider<SecureKeyStorage> {
  /// Secure key storage service (foundational service)
  SecureKeyStorageProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'secureKeyStorageProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$secureKeyStorageHash();

  @$internal
  @override
  $ProviderElement<SecureKeyStorage> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SecureKeyStorage create(Ref ref) {
    return secureKeyStorage(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SecureKeyStorage value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SecureKeyStorage>(value),
    );
  }
}

String _$secureKeyStorageHash() => r'853547d439994307884d2f47f3d9769daa0a1e96';

@ProviderFor(oauthConfig)
final oauthConfigProvider = OauthConfigProvider._();

final class OauthConfigProvider
    extends $FunctionalProvider<OAuthConfig, OAuthConfig, OAuthConfig>
    with $Provider<OAuthConfig> {
  OauthConfigProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'oauthConfigProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$oauthConfigHash();

  @$internal
  @override
  $ProviderElement<OAuthConfig> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  OAuthConfig create(Ref ref) {
    return oauthConfig(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(OAuthConfig value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<OAuthConfig>(value),
    );
  }
}

String _$oauthConfigHash() => r'ee45ee8403f86fbb8c9051d9d3ce1c3a3e4e5921';

@ProviderFor(flutterSecureStorage)
final flutterSecureStorageProvider = FlutterSecureStorageProvider._();

final class FlutterSecureStorageProvider
    extends
        $FunctionalProvider<
          FlutterSecureStorage,
          FlutterSecureStorage,
          FlutterSecureStorage
        >
    with $Provider<FlutterSecureStorage> {
  FlutterSecureStorageProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'flutterSecureStorageProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$flutterSecureStorageHash();

  @$internal
  @override
  $ProviderElement<FlutterSecureStorage> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  FlutterSecureStorage create(Ref ref) {
    return flutterSecureStorage(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FlutterSecureStorage value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FlutterSecureStorage>(value),
    );
  }
}

String _$flutterSecureStorageHash() =>
    r'8abafc8e21f68ced2b337c0e5040ab0d6cdb9eeb';

@ProviderFor(secureKeycastStorage)
final secureKeycastStorageProvider = SecureKeycastStorageProvider._();

final class SecureKeycastStorageProvider
    extends
        $FunctionalProvider<
          SecureKeycastStorage,
          SecureKeycastStorage,
          SecureKeycastStorage
        >
    with $Provider<SecureKeycastStorage> {
  SecureKeycastStorageProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'secureKeycastStorageProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$secureKeycastStorageHash();

  @$internal
  @override
  $ProviderElement<SecureKeycastStorage> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SecureKeycastStorage create(Ref ref) {
    return secureKeycastStorage(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SecureKeycastStorage value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SecureKeycastStorage>(value),
    );
  }
}

String _$secureKeycastStorageHash() =>
    r'c57c0ec02e36cd1a0cc8b850c450af2eb4c496b3';

@ProviderFor(pendingVerificationService)
final pendingVerificationServiceProvider =
    PendingVerificationServiceProvider._();

final class PendingVerificationServiceProvider
    extends
        $FunctionalProvider<
          PendingVerificationService,
          PendingVerificationService,
          PendingVerificationService
        >
    with $Provider<PendingVerificationService> {
  PendingVerificationServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pendingVerificationServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pendingVerificationServiceHash();

  @$internal
  @override
  $ProviderElement<PendingVerificationService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PendingVerificationService create(Ref ref) {
    return pendingVerificationService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PendingVerificationService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PendingVerificationService>(value),
    );
  }
}

String _$pendingVerificationServiceHash() =>
    r'9b524b7d7fd20c98b2e0942e9ea6358419dc9dd4';

@ProviderFor(oauthClient)
final oauthClientProvider = OauthClientProvider._();

final class OauthClientProvider
    extends $FunctionalProvider<KeycastOAuth, KeycastOAuth, KeycastOAuth>
    with $Provider<KeycastOAuth> {
  OauthClientProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'oauthClientProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$oauthClientHash();

  @$internal
  @override
  $ProviderElement<KeycastOAuth> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  KeycastOAuth create(Ref ref) {
    return oauthClient(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(KeycastOAuth value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<KeycastOAuth>(value),
    );
  }
}

String _$oauthClientHash() => r'217c3c01dd4f147990ee0f189f5d4fe5bcd89d45';

/// Web authentication service (for web platform only).
///
/// Kept alive: the service holds the signed-in web session (method, pubkey,
/// signer), and the screen that signs in and the iframe sandbox that later
/// signs with it are different readers. Before #8618 the factory returned a
/// process singleton, which hid that this provider was autoDispose.

@ProviderFor(webAuthService)
final webAuthServiceProvider = WebAuthServiceProvider._();

/// Web authentication service (for web platform only).
///
/// Kept alive: the service holds the signed-in web session (method, pubkey,
/// signer), and the screen that signs in and the iframe sandbox that later
/// signs with it are different readers. Before #8618 the factory returned a
/// process singleton, which hid that this provider was autoDispose.

final class WebAuthServiceProvider
    extends $FunctionalProvider<WebAuthService, WebAuthService, WebAuthService>
    with $Provider<WebAuthService> {
  /// Web authentication service (for web platform only).
  ///
  /// Kept alive: the service holds the signed-in web session (method, pubkey,
  /// signer), and the screen that signs in and the iframe sandbox that later
  /// signs with it are different readers. Before #8618 the factory returned a
  /// process singleton, which hid that this provider was autoDispose.
  WebAuthServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'webAuthServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$webAuthServiceHash();

  @$internal
  @override
  $ProviderElement<WebAuthService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  WebAuthService create(Ref ref) {
    return webAuthService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WebAuthService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WebAuthService>(value),
    );
  }
}

String _$webAuthServiceHash() => r'13e5f97f515b68acad668d522d80adef878f25fc';

/// Authentication service

@ProviderFor(authService)
final authServiceProvider = AuthServiceProvider._();

/// Authentication service

final class AuthServiceProvider
    extends $FunctionalProvider<AuthService, AuthService, AuthService>
    with $Provider<AuthService> {
  /// Authentication service
  AuthServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authServiceHash();

  @$internal
  @override
  $ProviderElement<AuthService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AuthService create(Ref ref) {
    return authService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AuthService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AuthService>(value),
    );
  }
}

String _$authServiceHash() => r'4d41662a5c96389841d71ae4eb5737eab9ab8712';

/// Provider that returns current auth state and rebuilds when it changes.
/// Widgets should watch this instead of authService.authState directly
/// to get automatic rebuilds when authentication state changes.

@ProviderFor(currentAuthState)
final currentAuthStateProvider = CurrentAuthStateProvider._();

/// Provider that returns current auth state and rebuilds when it changes.
/// Widgets should watch this instead of authService.authState directly
/// to get automatic rebuilds when authentication state changes.

final class CurrentAuthStateProvider
    extends $FunctionalProvider<AuthState, AuthState, AuthState>
    with $Provider<AuthState> {
  /// Provider that returns current auth state and rebuilds when it changes.
  /// Widgets should watch this instead of authService.authState directly
  /// to get automatic rebuilds when authentication state changes.
  CurrentAuthStateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentAuthStateProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentAuthStateHash();

  @$internal
  @override
  $ProviderElement<AuthState> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AuthState create(Ref ref) {
    return currentAuthState(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AuthState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AuthState>(value),
    );
  }
}

String _$currentAuthStateHash() => r'41c987ffc8f661555bab3ebec9078180411f66eb';

/// Provider that returns current RPC capability and rebuilds on changes.
///
/// Widgets and repositories should watch this instead of polling
/// [AuthService.authRpcCapability] directly.

@ProviderFor(currentAuthRpcCapability)
final currentAuthRpcCapabilityProvider = CurrentAuthRpcCapabilityProvider._();

/// Provider that returns current RPC capability and rebuilds on changes.
///
/// Widgets and repositories should watch this instead of polling
/// [AuthService.authRpcCapability] directly.

final class CurrentAuthRpcCapabilityProvider
    extends
        $FunctionalProvider<
          AuthRpcCapability,
          AuthRpcCapability,
          AuthRpcCapability
        >
    with $Provider<AuthRpcCapability> {
  /// Provider that returns current RPC capability and rebuilds on changes.
  ///
  /// Widgets and repositories should watch this instead of polling
  /// [AuthService.authRpcCapability] directly.
  CurrentAuthRpcCapabilityProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentAuthRpcCapabilityProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentAuthRpcCapabilityHash();

  @$internal
  @override
  $ProviderElement<AuthRpcCapability> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AuthRpcCapability create(Ref ref) {
    return currentAuthRpcCapability(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AuthRpcCapability value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AuthRpcCapability>(value),
    );
  }
}

String _$currentAuthRpcCapabilityHash() =>
    r'cb273f3377e25d0c88104df14a38d2b502c3f7de';

/// Provider that fetches the list of known accounts from the auth service.
///
/// Invalidate this provider after sign-in or sign-out to refresh the list.

@ProviderFor(knownAccounts)
final knownAccountsProvider = KnownAccountsProvider._();

/// Provider that fetches the list of known accounts from the auth service.
///
/// Invalidate this provider after sign-in or sign-out to refresh the list.

final class KnownAccountsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<KnownAccount>>,
          List<KnownAccount>,
          FutureOr<List<KnownAccount>>
        >
    with
        $FutureModifier<List<KnownAccount>>,
        $FutureProvider<List<KnownAccount>> {
  /// Provider that fetches the list of known accounts from the auth service.
  ///
  /// Invalidate this provider after sign-in or sign-out to refresh the list.
  KnownAccountsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'knownAccountsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$knownAccountsHash();

  @$internal
  @override
  $FutureProviderElement<List<KnownAccount>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<KnownAccount>> create(Ref ref) {
    return knownAccounts(ref);
  }
}

String _$knownAccountsHash() => r'8e9753265420cf092af04aa07686c98cdaa8eb1e';

/// Provider that sets Zendesk user identity when auth state changes.
///
/// Activated by `AppRootSideEffects`, above `MaterialApp.router`, so the
/// identity is mirrored for the whole process rather than from the moment the
/// bottom-nav shell mounts.

@ProviderFor(zendeskIdentitySync)
final zendeskIdentitySyncProvider = ZendeskIdentitySyncProvider._();

/// Provider that sets Zendesk user identity when auth state changes.
///
/// Activated by `AppRootSideEffects`, above `MaterialApp.router`, so the
/// identity is mirrored for the whole process rather than from the moment the
/// bottom-nav shell mounts.

final class ZendeskIdentitySyncProvider
    extends $FunctionalProvider<void, void, void>
    with $Provider<void> {
  /// Provider that sets Zendesk user identity when auth state changes.
  ///
  /// Activated by `AppRootSideEffects`, above `MaterialApp.router`, so the
  /// identity is mirrored for the whole process rather than from the moment the
  /// bottom-nav shell mounts.
  ZendeskIdentitySyncProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'zendeskIdentitySyncProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$zendeskIdentitySyncHash();

  @$internal
  @override
  $ProviderElement<void> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  void create(Ref ref) {
    return zendeskIdentitySync(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$zendeskIdentitySyncHash() =>
    r'e49d4f9cedf56ec4131b30a6f1d9d45dada68bed';

/// Provider that mirrors the authenticated identity into Firebase Analytics
/// and Crashlytics.
///
/// Deliberately independent of [zendeskIdentitySync]: campaign attribution
/// joins BigQuery `user_id` against the ClickHouse pubkey, so it must not be
/// coupled to the lifetime of the support-desk integration.
///
/// Activated by `AppRootSideEffects`. It used to be activated from
/// `AppShell.build()`, which left every crash report and analytics event
/// before the first bottom-nav tab — splash, auth restore, sign-up, e-mail
/// verification, onboarding — without a `user_id`.

@ProviderFor(analyticsIdentitySync)
final analyticsIdentitySyncProvider = AnalyticsIdentitySyncProvider._();

/// Provider that mirrors the authenticated identity into Firebase Analytics
/// and Crashlytics.
///
/// Deliberately independent of [zendeskIdentitySync]: campaign attribution
/// joins BigQuery `user_id` against the ClickHouse pubkey, so it must not be
/// coupled to the lifetime of the support-desk integration.
///
/// Activated by `AppRootSideEffects`. It used to be activated from
/// `AppShell.build()`, which left every crash report and analytics event
/// before the first bottom-nav tab — splash, auth restore, sign-up, e-mail
/// verification, onboarding — without a `user_id`.

final class AnalyticsIdentitySyncProvider
    extends $FunctionalProvider<void, void, void>
    with $Provider<void> {
  /// Provider that mirrors the authenticated identity into Firebase Analytics
  /// and Crashlytics.
  ///
  /// Deliberately independent of [zendeskIdentitySync]: campaign attribution
  /// joins BigQuery `user_id` against the ClickHouse pubkey, so it must not be
  /// coupled to the lifetime of the support-desk integration.
  ///
  /// Activated by `AppRootSideEffects`. It used to be activated from
  /// `AppShell.build()`, which left every crash report and analytics event
  /// before the first bottom-nav tab — splash, auth restore, sign-up, e-mail
  /// verification, onboarding — without a `user_id`.
  AnalyticsIdentitySyncProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'analyticsIdentitySyncProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$analyticsIdentitySyncHash();

  @$internal
  @override
  $ProviderElement<void> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  void create(Ref ref) {
    return analyticsIdentitySync(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$analyticsIdentitySyncHash() =>
    r'18eadd08461e9c7074095cc74e7c05f606566374';

/// Provider for [VerifierClient] pointed at the current environment's
/// verifier base URL. Stateless — every call hits the network.

@ProviderFor(verifierClient)
final verifierClientProvider = VerifierClientProvider._();

/// Provider for [VerifierClient] pointed at the current environment's
/// verifier base URL. Stateless — every call hits the network.

final class VerifierClientProvider
    extends $FunctionalProvider<VerifierClient, VerifierClient, VerifierClient>
    with $Provider<VerifierClient> {
  /// Provider for [VerifierClient] pointed at the current environment's
  /// verifier base URL. Stateless — every call hits the network.
  VerifierClientProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'verifierClientProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$verifierClientHash();

  @$internal
  @override
  $ProviderElement<VerifierClient> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  VerifierClient create(Ref ref) {
    return verifierClient(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VerifierClient value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VerifierClient>(value),
    );
  }
}

String _$verifierClientHash() => r'0cb119940e69355f90bd4532588ed27ba302c416';

/// Provider for [IdentityClaimsRepository] composing the verifier client
/// with NIP-39 i tag parsing, the persistent verdict cache (#3936) and the
/// kind-10011 write path behind the in-app verify flow.
///
/// The write dependencies are wired unconditionally even though most
/// consumers only render someone else's chips: the signer scopes every write
/// to the current user, so a read-only consumer holding this instance cannot
/// write with it. Consumers already re-key their blocs on this repository's
/// identity, which is what keeps a post-auth-flip client from being captured.

@ProviderFor(identityClaimsRepository)
final identityClaimsRepositoryProvider = IdentityClaimsRepositoryProvider._();

/// Provider for [IdentityClaimsRepository] composing the verifier client
/// with NIP-39 i tag parsing, the persistent verdict cache (#3936) and the
/// kind-10011 write path behind the in-app verify flow.
///
/// The write dependencies are wired unconditionally even though most
/// consumers only render someone else's chips: the signer scopes every write
/// to the current user, so a read-only consumer holding this instance cannot
/// write with it. Consumers already re-key their blocs on this repository's
/// identity, which is what keeps a post-auth-flip client from being captured.

final class IdentityClaimsRepositoryProvider
    extends
        $FunctionalProvider<
          IdentityClaimsRepository,
          IdentityClaimsRepository,
          IdentityClaimsRepository
        >
    with $Provider<IdentityClaimsRepository> {
  /// Provider for [IdentityClaimsRepository] composing the verifier client
  /// with NIP-39 i tag parsing, the persistent verdict cache (#3936) and the
  /// kind-10011 write path behind the in-app verify flow.
  ///
  /// The write dependencies are wired unconditionally even though most
  /// consumers only render someone else's chips: the signer scopes every write
  /// to the current user, so a read-only consumer holding this instance cannot
  /// write with it. Consumers already re-key their blocs on this repository's
  /// identity, which is what keeps a post-auth-flip client from being captured.
  IdentityClaimsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'identityClaimsRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$identityClaimsRepositoryHash();

  @$internal
  @override
  $ProviderElement<IdentityClaimsRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  IdentityClaimsRepository create(Ref ref) {
    return identityClaimsRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(IdentityClaimsRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<IdentityClaimsRepository>(value),
    );
  }
}

String _$identityClaimsRepositoryHash() =>
    r'be740fe386e60c1253fa0ceeaa7966e510171019';

/// NIP-98 authentication service

@ProviderFor(nip98AuthService)
final nip98AuthServiceProvider = Nip98AuthServiceProvider._();

/// NIP-98 authentication service

final class Nip98AuthServiceProvider
    extends
        $FunctionalProvider<
          Nip98AuthService,
          Nip98AuthService,
          Nip98AuthService
        >
    with $Provider<Nip98AuthService> {
  /// NIP-98 authentication service
  Nip98AuthServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'nip98AuthServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$nip98AuthServiceHash();

  @$internal
  @override
  $ProviderElement<Nip98AuthService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Nip98AuthService create(Ref ref) {
    return nip98AuthService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Nip98AuthService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Nip98AuthService>(value),
    );
  }
}

String _$nip98AuthServiceHash() => r'2e5b190deac613283e316aadf81bc99d8d1778f2';

/// Account Deletion Service for NIP-62 Request to Vanish

@ProviderFor(accountDeletionService)
final accountDeletionServiceProvider = AccountDeletionServiceProvider._();

/// Account Deletion Service for NIP-62 Request to Vanish

final class AccountDeletionServiceProvider
    extends
        $FunctionalProvider<
          AccountDeletionService,
          AccountDeletionService,
          AccountDeletionService
        >
    with $Provider<AccountDeletionService> {
  /// Account Deletion Service for NIP-62 Request to Vanish
  AccountDeletionServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'accountDeletionServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$accountDeletionServiceHash();

  @$internal
  @override
  $ProviderElement<AccountDeletionService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AccountDeletionService create(Ref ref) {
    return accountDeletionService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AccountDeletionService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AccountDeletionService>(value),
    );
  }
}

String _$accountDeletionServiceHash() =>
    r'659c0ee712559ba34e462dc9b236c40c80651240';
