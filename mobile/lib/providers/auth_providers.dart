// ABOUTME: Auth & identity Riverpod providers split from app_providers.dart
// ABOUTME: Secure storage, OAuth/Keycast, AuthService keystone, NIP-98/CAWG/NIP-39,
// ABOUTME: account deletion, Zendesk and analytics identity sync (eager)

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:openvine/models/auth_rpc_capability.dart';
import 'package:openvine/models/environment_config.dart';
import 'package:openvine/models/known_account.dart';
import 'package:openvine/providers/analytics_providers.dart';
import 'package:openvine/providers/app_version_provider.dart';
import 'package:openvine/providers/background_activity_provider.dart';
import 'package:openvine/providers/crash_reporting_provider.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/providers/service_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/social_providers.dart';
import 'package:openvine/services/account_deletion_service.dart';
import 'package:openvine/services/auth_service.dart' hide UserProfile;
import 'package:openvine/services/cawg_verifier_client.dart';
import 'package:openvine/services/nip98_auth_service.dart';
import 'package:openvine/services/nostr_creator_binding_service.dart';
import 'package:openvine/services/pending_verification_service.dart';
import 'package:openvine/services/secure_storage_options.dart';
import 'package:openvine/services/web_auth_service.dart';
import 'package:openvine/services/zendesk_support_service.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:url_launcher/url_launcher.dart';

part 'auth_providers.g.dart';

/// Secure key storage service (foundational service)
@Riverpod(keepAlive: true)
SecureKeyStorage secureKeyStorage(Ref ref) {
  return SecureKeyStorage();
}

/// OAuth configuration — uses local keycast when running in local environment
const _productionLoginOrigin = 'https://login.divine.video';

@Riverpod(keepAlive: true)
OAuthConfig oauthConfig(Ref ref) {
  final env = ref.watch(currentEnvironmentProvider);
  if (env.environment == AppEnvironment.local) {
    // Not const: localHost resolves per platform at runtime.
    return OAuthConfig(
      serverUrl: 'http://$localHost:$localKeycastPort',
      clientId: 'divine-mobile',
      redirectUri: 'http://$loopbackHost:$localKeycastPort/app/callback',
    );
  }
  return const OAuthConfig(
    serverUrl: _productionLoginOrigin,
    clientId: 'divine-mobile',
    redirectUri: 'https://divine.video/app/callback',
  );
}

@Riverpod(keepAlive: true)
FlutterSecureStorage flutterSecureStorage(Ref ref) => FlutterSecureStorage(
  // Do not enable AndroidOptions.resetOnError here. This storage holds
  // OAuth/Keycast and pending-verification credentials; silently deleting
  // them after a transient Android Keystore read error logs users out.
  aOptions: const AndroidOptions(encryptedSharedPreferences: true),
  // macOS debug builds can't use the data-protection keychain (#5563).
  mOptions: appMacOsSecureStorageOptions(),
);

@Riverpod(keepAlive: true)
SecureKeycastStorage secureKeycastStorage(Ref ref) =>
    SecureKeycastStorage(ref.watch(flutterSecureStorageProvider));

@Riverpod(keepAlive: true)
PendingVerificationService pendingVerificationService(Ref ref) =>
    PendingVerificationService(ref.watch(flutterSecureStorageProvider));

@Riverpod(keepAlive: true)
KeycastOAuth oauthClient(Ref ref) {
  final config = ref.watch(oauthConfigProvider);
  final storage = ref.watch(secureKeycastStorageProvider);
  // login.divine.video auth traffic (token, poll, password reset, …).
  // close() owns the injected client.
  final httpClient = ref.watch(instrumentedHttpClientFactoryProvider)();
  final oauth = KeycastOAuth(
    config: config,
    storage: storage,
    httpClient: httpClient,
  );

  ref.onDispose(oauth.close);

  return oauth;
}

/// Web authentication service (for web platform only).
///
/// Kept alive: the service holds the signed-in web session (method, pubkey,
/// signer), and the screen that signs in and the iframe sandbox that later
/// signs with it are different readers. Before #8618 the factory returned a
/// process singleton, which hid that this provider was autoDispose.
@Riverpod(keepAlive: true)
WebAuthService webAuthService(Ref ref) {
  final service = WebAuthService(nip07Service: ref.watch(nip07ServiceProvider));
  ref.onDispose(service.dispose);
  return service;
}

/// Authentication service
@Riverpod(keepAlive: true)
AuthService authService(Ref ref) {
  final keyStorage = ref.watch(secureKeyStorageProvider);
  final userDataCleanupService = ref.watch(userDataCleanupServiceProvider);
  final oauthClient = ref.watch(oauthClientProvider);
  final flutterSecureStorage = ref.watch(flutterSecureStorageProvider);
  final oauthConfig = ref.watch(oauthConfigProvider);
  // NOTE: We construct FunnelcakeApiClient directly here instead of using
  // funnelcakeApiClientProvider to avoid a circular dependency:
  //   authService → funnelcakeApiClient → nostrService → authService
  // Using currentEnvironmentProvider is safe (no auth/nostr dependency).
  final authEnv = ref.read(currentEnvironmentProvider);
  final authService = AuthService(
    backgroundActivityManager: ref.read(backgroundActivityManagerProvider),
    crashReporter: ref.read(crashReportingServiceProvider),
    nip07Service: ref.watch(nip07ServiceProvider),
    userDataCleanupService: userDataCleanupService,
    keyStorage: keyStorage,
    oauthClient: oauthClient,
    flutterSecureStorage: flutterSecureStorage,
    oauthConfig: oauthConfig,
    profileCheckIndexerUrl: authEnv.indexerRelays.first,
    indexerRelays: authEnv.indexerRelays,
    primaryRelayUrl: authEnv.relayUrl,
    launchAuthUrl: (uri) async {
      // Preserves the pre-port behavior exactly: only the canLaunchUrl gate
      // decides launchability; launchUrl's own result stays ignored.
      if (!await canLaunchUrl(uri)) return false;
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return true;
    },
    preFetchFollowing: (pubkeyHex) async {
      // Pre-fetch following list from funnelcake REST API during login
      // setup. This populates SharedPreferences BEFORE auth state is
      // set, so the router redirect has accurate cache data and sends
      // user to /home not /explore.
      final environmentConfig = ref.read(currentEnvironmentProvider);
      // Instrumented and closed here: this one-shot client blocks the login
      // redirect, so its latency is worth reporting, and nothing reuses it.
      final httpClient = ref.read(instrumentedHttpClientFactoryProvider)();
      final client = FunnelcakeApiClient(
        baseUrl: environmentConfig.apiBaseUrl,
        httpClient: httpClient,
        appVersion: ref.watch(appVersionProvider),
      );
      final prefs = ref.read(sharedPreferencesProvider);
      try {
        final result = await client.getFollowing(
          pubkey: pubkeyHex,
          limit: 5000,
        );
        await persistFollowingCacheForAuthRedirect(
          prefs: prefs,
          pubkeyHex: pubkeyHex,
          pubkeys: result.pubkeys,
        );
        Log.info(
          'Pre-fetched ${result.pubkeys.length} following for '
          'router redirect cache',
          name: 'AuthService',
          category: LogCategory.auth,
        );
      } finally {
        httpClient.close();
      }
    },
  );
  ref.onDispose(() => unawaited(authService.dispose()));
  return authService;
}

/// Persists a successful following response for synchronous route decisions.
///
/// An empty list is meaningful: it distinguishes "fetched and follows nobody"
/// from "not fetched yet", preventing every later login from repeating the
/// same blocking request.
@visibleForTesting
Future<void> persistFollowingCacheForAuthRedirect({
  required SharedPreferences prefs,
  required String pubkeyHex,
  required List<String> pubkeys,
}) async {
  await prefs.setString(
    FollowingCacheRecord.storageKey(pubkeyHex),
    FollowingCacheRecord(pubkeys: pubkeys).encode(),
  );
}

/// Provider that returns current auth state and rebuilds when it changes.
/// Widgets should watch this instead of authService.authState directly
/// to get automatic rebuilds when authentication state changes.
@Riverpod(keepAlive: true)
AuthState currentAuthState(Ref ref) {
  final authService = ref.watch(authServiceProvider);

  // Listen to auth state changes and invalidate this provider when they occur
  final subscription = authService.authStateStream.listen((_) {
    // Invalidate to trigger rebuild with new state
    ref.invalidateSelf();
  });

  // Clean up subscription when provider is disposed
  ref.onDispose(subscription.cancel);

  // Return current state
  return authService.authState;
}

/// Boundary-safe auth helper for recorder exits.
///
/// UI callers need to know whether auth restore has reached an authenticated
/// state, but they should not import service-layer auth types directly.
final recorderExitAuthGateProvider = Provider<RecorderExitAuthGate>((ref) {
  return RecorderExitAuthGate(ref.watch(authServiceProvider));
});

class RecorderExitAuthGate {
  RecorderExitAuthGate(this._authService);

  final AuthService _authService;

  Duration get restoreTimeout => AuthService.startupAuthRestoreTimeout;

  bool get isRestoring => _isStartupAuthRestoreState(_authService.authState);

  Future<bool> waitForAuthenticatedOrTerminal() async {
    var authState = _authService.authState;
    if (_isStartupAuthRestoreState(authState)) {
      try {
        authState = await _authService.authStateStream
            .firstWhere((state) => !_isStartupAuthRestoreState(state))
            .timeout(restoreTimeout);
      } on TimeoutException {
        authState = _authService.authState;
      }
    }

    return authState == AuthState.authenticated;
  }

  bool _isStartupAuthRestoreState(AuthState state) {
    return state == AuthState.checking || state == AuthState.authenticating;
  }
}

/// Provider that returns current RPC capability and rebuilds on changes.
///
/// Widgets and repositories should watch this instead of polling
/// [AuthService.authRpcCapability] directly.
@Riverpod(keepAlive: true)
AuthRpcCapability currentAuthRpcCapability(Ref ref) {
  final authService = ref.watch(authServiceProvider);

  final subscription = authService.authRpcCapabilityStream.listen((_) {
    ref.invalidateSelf();
  });

  ref.onDispose(subscription.cancel);

  return authService.authRpcCapability;
}

/// Provider that fetches the list of known accounts from the auth service.
///
/// Invalidate this provider after sign-in or sign-out to refresh the list.
@riverpod
Future<List<KnownAccount>> knownAccounts(Ref ref) {
  final authService = ref.watch(authServiceProvider);
  // Rebuild when auth state changes so the list stays current.
  ref.watch(currentAuthStateProvider);
  return authService.getKnownAccounts();
}

/// Provider for user-signed creator-binding assertions.
final nostrCreatorBindingServiceProvider = Provider<NostrCreatorBindingService>(
  (ref) {
    ref.watch(currentAuthStateProvider);
    final authService = ref.watch(authServiceProvider);
    return NostrCreatorBindingService(identity: authService.currentIdentity);
  },
);

/// Provider for the CAWG verifier base URI.
final cawgVerifierBaseUriProvider = Provider<Uri>((ref) {
  return Uri.parse(
    const String.fromEnvironment(
      'CAWG_VERIFIER_BASE_URL',
      defaultValue: 'https://verifyer.divine.video',
    ),
  );
});

/// Provider for the optional CAWG identity verifier client.
final cawgVerifierClientProvider = Provider<CawgVerifierClient>((ref) {
  final baseUri = ref.watch(cawgVerifierBaseUriProvider);
  // The client's own dispose() only closes a client it created, so the
  // injected one is closed here.
  final httpClient = ref.watch(instrumentedHttpClientFactoryProvider)();
  final client = CawgVerifierClient(baseUri: baseUri, httpClient: httpClient);
  ref.onDispose(client.dispose);
  ref.onDispose(httpClient.close);
  return client;
});

/// Provider that sets Zendesk user identity when auth state changes.
///
/// Activated by `AppRootSideEffects`, above `MaterialApp.router`, so the
/// identity is mirrored for the whole process rather than from the moment the
/// bottom-nav shell mounts.
@Riverpod(keepAlive: true)
void zendeskIdentitySync(Ref ref) {
  final authService = ref.watch(authServiceProvider);
  final profileRepository = ref.watch(profileRepositoryProvider);

  // Set initial identity if already authenticated
  if (authService.isAuthenticated && authService.currentPublicKeyHex != null) {
    _setZendeskIdentity(
      authService.currentPublicKeyHex!,
      profileRepository,
      ref,
    );
  }

  // Listen to auth state changes
  final subscription = authService.authStateStream.listen((authState) async {
    if (authState == AuthState.authenticated) {
      final pubkeyHex = authService.currentPublicKeyHex;
      if (pubkeyHex != null) {
        await _setZendeskIdentity(pubkeyHex, profileRepository, ref);
      }
    } else if (authState == AuthState.unauthenticated) {
      await ZendeskSupportService.clearUserIdentity();
      Log.info(
        'Zendesk identity cleared on logout',
        name: 'ZendeskIdentitySync',
        category: LogCategory.system,
      );
    }
  });

  ref.onDispose(subscription.cancel);
}

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
@Riverpod(keepAlive: true)
void analyticsIdentitySync(Ref ref) {
  final authService = ref.watch(authServiceProvider);
  final coordinator = ref.read(analyticsIdentityCoordinatorProvider);

  final restoredPubkeyHex = authService.currentPublicKeyHex;
  if (authService.isAuthenticated && restoredPubkeyHex != null) {
    unawaited(coordinator.setUserId(restoredPubkeyHex));
  }

  final subscription = authService.authStateStream.listen((authState) async {
    if (authState == AuthState.authenticated) {
      await coordinator.setUserId(authService.currentPublicKeyHex);
    } else if (authState == AuthState.unauthenticated) {
      await coordinator.setUserId(null);
    }
  });

  ref.onDispose(subscription.cancel);
}

/// Helper to set Zendesk identity from pubkey
Future<void> _setZendeskIdentity(
  String pubkeyHex,
  ProfileRepository? profileRepository,
  Ref ref,
) async {
  try {
    final npub = NostrKeyUtils.encodePubKey(pubkeyHex);
    final profile = await profileRepository?.getCachedProfile(
      pubkey: pubkeyHex,
    );

    // 1. Store user info locally (for REST API fallback)
    ZendeskSupportService.setUserIdentity(
      displayName: profile?.bestDisplayName,
      nip05: profile?.nip05,
      npub: npub,
    );

    // 2. Set anonymous identity on native SDK immediately (no network call)
    // This ensures createTicket() works for content reports right away
    await ZendeskSupportService.setAnonymousIdentityWithUserInfo();

    // 3. Upgrade to JWT identity asynchronously (network call)
    // If this fails, anonymous identity remains and tickets still work
    try {
      final nip98Service = ref.read(nip98AuthServiceProvider);
      final relayManagerUrl = ref
          .read(currentEnvironmentProvider)
          .relayManagerApiUrl;

      // Store auth context so the service can refresh JWT before each SDK action.
      // The pre-auth token has a 5-minute TTL, so any delay between login and
      // ticket creation would fail without a refresh.
      ZendeskSupportService.storeAuthContext(
        nip98Service: nip98Service,
        relayManagerUrl: relayManagerUrl,
      );

      final jwtSet = await ZendeskSupportService.setJwtIdentity(
        nip98Service: nip98Service,
        relayManagerUrl: relayManagerUrl,
      );

      if (jwtSet) {
        Log.info(
          'Zendesk JWT identity set for user',
          name: 'ZendeskIdentitySync',
          category: LogCategory.system,
        );
      } else {
        Log.warning(
          'Zendesk JWT upgrade failed, anonymous identity active',
          name: 'ZendeskIdentitySync',
          category: LogCategory.system,
        );
      }
    } catch (e) {
      Log.warning(
        'Zendesk JWT upgrade failed ($e), anonymous identity active',
        name: 'ZendeskIdentitySync',
        category: LogCategory.system,
      );
    }

    Log.info(
      'Zendesk identity set for authenticated user',
      name: 'ZendeskIdentitySync',
      category: LogCategory.system,
    );
  } catch (e) {
    Log.warning(
      'Failed to set Zendesk identity: $e',
      name: 'ZendeskIdentitySync',
      category: LogCategory.system,
    );
  }
}

/// Provider for [VerifierClient] pointed at the current environment's
/// verifier base URL. Stateless — every call hits the network.
@Riverpod(keepAlive: true)
VerifierClient verifierClient(Ref ref) {
  final env = ref.watch(currentEnvironmentProvider);
  final httpClient = ref.watch(instrumentedHttpClientFactoryProvider)();
  ref.onDispose(httpClient.close);
  return VerifierClient(baseUrl: env.verifierBaseUrl, httpClient: httpClient);
}

/// Provider for [IdentityClaimsRepository] composing the verifier client
/// with NIP-39 i tag parsing, the persistent verdict cache (#3936) and the
/// kind-10011 write path behind the in-app verify flow.
///
/// The write dependencies are wired unconditionally even though most
/// consumers only render someone else's chips: the signer scopes every write
/// to the current user, so a read-only consumer holding this instance cannot
/// write with it. Consumers already re-key their blocs on this repository's
/// identity, which is what keeps a post-auth-flip client from being captured.
@Riverpod(keepAlive: true)
IdentityClaimsRepository identityClaimsRepository(Ref ref) {
  final authService = ref.watch(authServiceProvider);
  final database = ref.watch(databaseProvider);
  return IdentityClaimsRepository(
    verifierClient: ref.watch(verifierClientProvider),
    identityVerificationsDao: database.identityVerificationsDao,
    nostrClient: ref.watch(nostrServiceProvider),
    signEvent: authService.createAndSignEvent,
    identityEventsDao: database.identityEventsDao,
  );
}

/// NIP-98 authentication service
@riverpod
Nip98AuthService nip98AuthService(Ref ref) {
  final authService = ref.watch(authServiceProvider);
  final service = Nip98AuthService(authService: authService);
  ref.onDispose(service.dispose);
  return service;
}

/// Account Deletion Service for NIP-62 Request to Vanish
@riverpod
AccountDeletionService accountDeletionService(Ref ref) {
  final nostrService = ref.watch(nostrServiceProvider);
  final authService = ref.watch(authServiceProvider);
  return AccountDeletionService(
    nostrService: nostrService,
    authService: authService,
  );
}
