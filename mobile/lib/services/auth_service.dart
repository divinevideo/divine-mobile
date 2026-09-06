// ABOUTME: Authentication service managing user login, key generation, and
// auth state
// ABOUTME: Handles Nostr identity creation, import, and session management
// with secure storage

import 'dart:async';

import 'package:cache_sync/cache_sync.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:nostr_client/nostr_client.dart'
    show BlockListSigner, SharedPreferencesRelayStorage;
import 'package:nostr_key_manager/nostr_key_manager.dart'
    show SecureKeyContainer, SecureKeyStorage, SecureKeyStorageException;
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/models/account_restore_failed_exception.dart';
import 'package:openvine/models/auth_result.dart';
import 'package:openvine/models/auth_rpc_capability.dart';
import 'package:openvine/models/auth_state.dart';
import 'package:openvine/models/auth_user_profile.dart';
import 'package:openvine/models/authentication_source.dart';
import 'package:openvine/models/known_account.dart';
import 'package:openvine/models/signer_readiness.dart';
import 'package:openvine/observability/crash_reporter.dart';
import 'package:openvine/services/auth/known_accounts_registry.dart';
import 'package:openvine/services/auth/nostr_connect_coordinator.dart';
import 'package:openvine/services/auth/nostr_identity.dart';
import 'package:openvine/services/auth/oauth_session_coordinator.dart';
import 'package:openvine/services/auth/relay_discovery_orchestrator.dart';
import 'package:openvine/services/auth/signer_factory.dart';
import 'package:openvine/services/auth/signer_readiness_resolver.dart';
import 'package:openvine/services/auth/signer_secure_store.dart';
import 'package:openvine/services/background_activity_manager.dart';
import 'package:openvine/services/nip07_service.dart';
import 'package:openvine/services/relay_discovery_service.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:openvine/utils/divine_login_banner_dismissal.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/utils/session_recovery_anchor.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

// AuthResult moved to its own file (#4741) so auth/ collaborators can return it
// without a facade import cycle; external consumers keep importing it here.
export 'package:openvine/models/account_restore_failed_exception.dart';
export 'package:openvine/models/auth_result.dart';
export 'package:openvine/models/auth_state.dart';
export 'package:openvine/models/auth_user_profile.dart';
export 'package:openvine/models/authentication_source.dart';
// Discovery callback contracts moved with the orchestrator (#4741); external
// consumers (NostrService wiring) keep importing them from this facade.
export 'package:openvine/services/auth/relay_discovery_orchestrator.dart'
    show BootstrapRelayListCallback, UserRelaysDiscoveredCallback;

// Key for the last-used account npub (used to restore the correct identity on restart)
const _kLastUsedNpubKey = 'last_used_npub';

// Key for the session recovery anchor: the npub that was actively signed in at
// the time of the most recent sign-out. Written at the start of signOut() so
// the welcome screen can detect cross-account cold-start restores and surface
// a confirmation banner before silently completing a switch. Cleared by
// _setupUserSession() once the user has explicitly signed back in.
const _kSessionRecoveryAnchorKey = 'session_recovery_anchor_npub';

const _accountDeletionSessionExpiryMargin = Duration(minutes: 10);

/// Whether the account-deletion flow may start.
///
/// Deletion publishes irreversible events before it can attempt the reversible
/// server-side step, so this is checked *before* anything is published. See
/// [AuthService.checkAccountDeletionReadiness].
enum AccountDeletionReadiness {
  /// Nothing blocks the flow. Either there is no server-side account to delete,
  /// or the current session can authorize deleting it.
  ready,

  /// The session cannot authorize the server-side deletion, so starting would
  /// destroy the user's content and leave their account alive. A fresh sign-in
  /// resolves it. Nothing has been published.
  requiresReauthentication,
}

/// Callback to pre-fetch following list from REST API before auth state is set.
///
/// Called during login setup to populate SharedPreferences cache so the
/// router redirect has accurate following data before it fires synchronously.
typedef PreFetchFollowingCallback = Future<void> Function(String pubkeyHex);

/// Port for launching the NIP-46 bunker auth URL in an external browser.
///
/// Returns whether the URL could be launched. Wired in the app layer to
/// url_launcher so this service carries no Flutter-plugin dependency for the
/// launch; when unset (tests), the auth URL is logged as unlaunchable instead
/// of hitting a platform channel.
typedef AuthUrlLauncher = Future<bool> Function(Uri url);

/// Callback invoked before AuthService clears the outgoing session identity.
typedef BeforeSessionTeardownCallback = Future<void> Function();

/// Factory for NIP-46 remote signers. Injected in tests so startup restore can
/// exercise unreachable signer behavior without opening relay sockets.
typedef RemoteSignerFactory =
    NostrRemoteSigner Function(int relayMode, NostrRemoteSignerInfo info);

/// Total time budget for pre-teardown callbacks during sign-out.
const _kBeforeSessionTeardownTimeout = Duration(seconds: 5);

/// Main authentication service for the Divine app
/// REFACTORED: Removed ChangeNotifier - now uses pure state management via
/// Riverpod
class AuthService implements BackgroundAwareService, BlockListSigner {
  AuthService({
    required UserDataCleanupService userDataCleanupService,
    required BackgroundActivityManager backgroundActivityManager,
    CrashReporter? crashReporter,
    SecureKeyStorage? keyStorage,
    KeycastOAuth? oauthClient,
    FlutterSecureStorage? flutterSecureStorage,
    OAuthConfig? oauthConfig,
    PreFetchFollowingCallback? preFetchFollowing,
    AuthUrlLauncher? launchAuthUrl,
    String? profileCheckIndexerUrl,
    List<String>? indexerRelays,
    String? primaryRelayUrl,
    RelayDiscoveryService? relayDiscoveryService,
    Nip07Service? nip07Service,
    RemoteSignerFactory? remoteSignerFactory,
    Duration oauthRefreshTimeout = defaultOAuthRefreshTimeout,
    Duration expiredSessionRefreshTimeout = defaultExpiredSessionRefreshTimeout,
    Duration? startupNetworkOperationTimeout,
  }) : _crashReporter = crashReporter ?? const SilentCrashReporter(),
       _keyStorage = keyStorage ?? SecureKeyStorage(),
       _userDataCleanupService = userDataCleanupService,
       _oauthClient = oauthClient,
       _flutterSecureStorage = flutterSecureStorage,
       _preFetchFollowing = preFetchFollowing,
       _launchAuthUrl = launchAuthUrl,
       _backgroundActivityManager = backgroundActivityManager,
       _profileCheckIndexerUrl = profileCheckIndexerUrl,
       _primaryRelayUrl = primaryRelayUrl ?? AppConstants.defaultRelayUrl,
       _relayDiscoveryService =
           relayDiscoveryService ??
           RelayDiscoveryService(indexerRelays: indexerRelays),
       _oauthConfig =
           oauthConfig ??
           const OAuthConfig(serverUrl: '', clientId: '', redirectUri: ''),
       _nip07Extension = nip07Service,
       _remoteSignerFactory = remoteSignerFactory ?? NostrRemoteSigner.new,
       _oauthRefreshTimeout = oauthRefreshTimeout,
       _expiredSessionRefreshTimeout = expiredSessionRefreshTimeout,
       _startupNetworkOperationTimeout =
           startupNetworkOperationTimeout ??
           defaultStartupNetworkOperationTimeout;
  final SecureKeyStorage _keyStorage;
  final UserDataCleanupService _userDataCleanupService;
  final KeycastOAuth? _oauthClient;
  final FlutterSecureStorage? _flutterSecureStorage;
  late final SignerSecureStore _signerStore = SignerSecureStore(
    _flutterSecureStorage,
  );
  // Owns the persisted known-accounts registry (CRUD, one-time legacy
  // migration, restorable-account filter); the facade keeps all session state
  // and restore orchestration, calling in for the pure storage rules.
  late final KnownAccountsRegistry _knownAccounts = KnownAccountsRegistry(
    keyStorage: _keyStorage,
    signerStore: _signerStore,
    flutterSecureStorage: _flutterSecureStorage,
  );
  // Tear-off keeps the Crashlytics `auth_source` custom key reading live
  // state at report time (see _reportAuthError).
  late final SignerFactory _signerFactory = SignerFactory(
    crashReporter: _reportAuthError,
  );
  // Tear-offs/closures read live session state at execution time; the
  // write-backs land results in the facade fields external consumers read.
  late final RelayDiscoveryOrchestrator _discoveryOrchestrator =
      RelayDiscoveryOrchestrator(
        relayDiscoveryService: _relayDiscoveryService,
        primaryRelayUrl: _primaryRelayUrl,
        profileCheckIndexerUrl: _profileCheckIndexerUrl,
        isSessionCurrent: _isRelayDiscoveryCurrent,
        currentIdentity: () => _currentIdentity,
        onUserRelays: (relays) => _userRelays = relays,
        onHasExistingProfile: (hasProfile) => _hasExistingProfile = hasProfile,
        userRelaysDiscoveredCallback: () => _onUserRelaysDiscovered,
        bootstrapRelayListCallback: () => _onBootstrapRelayListRequested,
      );
  // Owns the single-flight refresh futures + timeouts; the facade keeps the
  // _hasExpiredOAuthSession flag and all result application, reached here
  // through ports so restore orchestration stays byte-identical.
  late final OAuthSessionCoordinator _oauthCoordinator =
      OAuthSessionCoordinator(
        oauthClient: _oauthClient,
        oauthRefreshTimeout: _oauthRefreshTimeout,
        expiredSessionRefreshTimeout: _expiredSessionRefreshTimeout,
        currentPubkeyFallback: () => _currentProfile?.publicKeyHex,
        hasExpiredSession: () => _hasExpiredOAuthSession,
      );
  // Owns the client-initiated nostrconnect:// session + wait future + callback
  // handoff timers; the facade keeps _bunkerSigner and applies a successful
  // connection through the ports so behavior stays byte-identical.
  late final NostrConnectCoordinator _nostrConnect = NostrConnectCoordinator(
    onConnected: _applyNostrConnectSuccess,
    onConnectFailed: (e) {
      _bunkerSigner?.close();
      _bunkerSigner = null;
      _lastError = 'NostrConnect failed: $e';
      _setAuthState(AuthState.unauthenticated);
    },
    onWaitStarted: () => _setAuthState(AuthState.authenticating),
    onWaitFailed: () => _setAuthState(AuthState.unauthenticated),
    reportError: _reportAuthError,
  );
  final PreFetchFollowingCallback? _preFetchFollowing;
  final AuthUrlLauncher? _launchAuthUrl;
  final BackgroundActivityManager _backgroundActivityManager;
  final CrashReporter _crashReporter;
  @visibleForTesting
  CrashReporter get crashReporterForTesting => _crashReporter;
  final String? _profileCheckIndexerUrl;
  final RemoteSignerFactory _remoteSignerFactory;
  final Duration _startupNetworkOperationTimeout;

  /// Bound applied to the single-flight OAuth token refresh in
  /// [OAuthSessionCoordinator]. Injectable so tests can use a short bound.
  final Duration _oauthRefreshTimeout;

  /// Bound applied to the full expired-session refresh flow in
  /// [OAuthSessionCoordinator]. Injectable so tests can use a short bound.
  final Duration _expiredSessionRefreshTimeout;

  /// Bridge to a NIP-07 browser extension, or null when none was injected
  /// (tests off-web). Production injects the shared `nip07ServiceProvider`
  /// instance, whose [Nip07Service.isAvailable] is false off-web, so the
  /// NIP-07 paths need no [kIsWeb] guard of their own (#8618).
  final Nip07Service? _nip07Extension;

  /// Relay URL used when self-publishing the bootstrap kind:10002 event for
  /// accounts whose indexer discovery returned empty. Injected from
  /// [EnvironmentConfig.relayUrl] at the provider so non-prod builds do not
  /// advertise the production relay. Falls back to
  /// [AppConstants.defaultRelayUrl] when unset. See #3183.
  final String _primaryRelayUrl;

  AuthState _authState = AuthState.checking;
  SecureKeyContainer? _currentKeyContainer;
  UserProfile? _currentProfile;
  String? _lastError;
  bool _storageErrorOccurred = false;
  bool _hasExpiredOAuthSession = false;
  bool _isRpcUpgradeInProgress = false;
  bool _registeredWithBackgroundActivity = false;
  KeycastRpc? _keycastSigner;

  // RPC capability state — separate from AuthState so the router doesn't
  // need to know about remote signer warmup.
  AuthRpcCapability _authRpcCapability = AuthRpcCapability.unavailable;
  bool _authRpcCapabilityInitialized = false;

  // NIP-46 bunker signer state
  NostrRemoteSigner? _bunkerSigner;

  // NIP-55 Android signer (Amber) state
  AndroidNostrSigner? _amberSigner;

  // NIP-07 browser extension signer state (nullable; null when no session active)
  Nip07Service? _nip07Service;

  // NIP-46 nostrconnect:// session state is owned by [_nostrConnect]
  // (NostrConnectCoordinator); the facade delegates to it (#4741).

  // Atomic signing identity — couples pubkey with signing mechanism
  NostrIdentity? _currentIdentity;

  // Relay discovery state (NIP-65)
  List<DiscoveredRelay> _userRelays = [];
  bool _hasExistingProfile = false;
  final RelayDiscoveryService _relayDiscoveryService;

  /// Callback registered by NostrService to add discovered relays to the client
  /// when discovery completes (avoids race where client is built before discovery).
  UserRelaysDiscoveredCallback? _onUserRelaysDiscovered;

  /// Callback registered by NostrService to publish a bootstrap kind:10002
  /// event when indexer discovery returns empty for the signed-in user.
  ///
  /// See [registerBootstrapRelayListCallback].
  BootstrapRelayListCallback? _onBootstrapRelayListRequested;

  final List<BeforeSessionTeardownCallback> _beforeSessionTeardownCallbacks =
      [];

  /// The current user's atomic signing identity, or null if not authenticated.
  ///
  /// Use [requireIdentity] in code that runs only when authenticated
  /// (post-router-gate) to get a guaranteed non-null value.
  NostrIdentity? get currentIdentity => _currentIdentity;

  /// The current user's signing identity, guaranteed non-null.
  ///
  /// Throws [StateError] if called when no identity is set. This should only
  /// happen if the caller bypasses the router's authentication gate.
  /// Use this in post-authentication code instead of [currentIdentity]!.
  NostrIdentity get requireIdentity {
    final identity = _currentIdentity;
    if (identity == null) {
      throw StateError(
        'requireIdentity called with no active NostrIdentity. '
        'This code path should only execute when authenticated.',
      );
    }
    return identity;
  }

  final OAuthConfig _oauthConfig;

  // Streaming controllers for reactive auth state
  final StreamController<AuthState> _authStateController =
      StreamController<AuthState>.broadcast();
  final StreamController<UserProfile?> _profileController =
      StreamController<UserProfile?>.broadcast();
  final StreamController<AuthRpcCapability> _rpcCapabilityController =
      StreamController<AuthRpcCapability>.broadcast();

  /// Current authentication state
  AuthState get authState => _authState;

  /// Stream of authentication state changes.
  ///
  /// Identity only. `authenticated` says the pubkey is known, not that anything
  /// can be signed. Side effects that sign through the app-wide Nostr client
  /// must watch `nostrSessionProvider`; relay-free signing must watch a signer
  /// capability signal such as `currentAuthRpcCapabilityProvider`. Gating them
  /// here strands them when the signer arrives later (#6977).
  Stream<AuthState> get authStateStream => _authStateController.stream;

  /// Current user profile (null if not authenticated)
  UserProfile? get currentProfile => _currentProfile;

  /// Current public key (npub format).
  ///
  /// Reads from [currentIdentity] when available (post-authentication),
  /// falls back to [_currentKeyContainer] during the auth-screen lifecycle.
  String? get currentNpub =>
      _currentIdentity?.npub ?? _currentKeyContainer?.npub;

  /// Current public key (hex format).
  ///
  /// Reads from [currentIdentity] when available (post-authentication),
  /// falls back to [_currentKeyContainer] or [_currentProfile] during the
  /// auth-screen lifecycle.
  String? get currentPublicKeyHex =>
      _currentIdentity?.pubkey ??
      _currentKeyContainer?.publicKeyHex ??
      _currentProfile?.publicKeyHex;

  /// Check if user is authenticated
  @override
  bool get isAuthenticated => _authState == AuthState.authenticated;

  /// Authentication source used for current session
  AuthenticationSource _authSource = AuthenticationSource.none;

  /// Get the current authentication source
  AuthenticationSource get authenticationSource => _authSource;

  /// Check if user has registered with Divine (email/password)
  /// Returns true if authenticated via Divine OAuth, false for anonymous/imported keys
  bool get isRegistered => _authSource == AuthenticationSource.divineOAuth;

  /// Returns the active account's Divine OAuth access token.
  ///
  /// The token is owner-bound and refreshes through the process-wide
  /// single-flight coordinator so crossposter requests cannot race Keycast's
  /// rotating refresh token or reuse another account's stored session.
  Future<String?> getBoundDivineAccessToken() async {
    final ownerPubkey = currentPublicKeyHex;
    if (_authState != AuthState.authenticated ||
        _authSource != AuthenticationSource.divineOAuth ||
        ownerPubkey == null ||
        ownerPubkey.isEmpty) {
      return null;
    }

    final token = await _oauthCoordinator.accessTokenForOwner(
      expectedOwnerPubkey: ownerPubkey,
      storedSessionReader: () => KeycastSession.load(_flutterSecureStorage),
    );
    if (_authState != AuthState.authenticated ||
        _authSource != AuthenticationSource.divineOAuth ||
        currentPublicKeyHex != ownerPubkey) {
      return null;
    }
    return token;
  }

  /// Whether the active account has a local private key that can be exported.
  bool get canExportLocalNsec {
    if (!isAuthenticated) return false;
    if (_currentKeyContainer?.hasPrivateKey != true) return false;
    return switch (_authSource) {
      AuthenticationSource.automatic ||
      AuthenticationSource.importedKeys ||
      AuthenticationSource.divineOAuth => true,
      _ => false,
    };
  }

  /// Check if user is using an anonymous auto-generated identity
  bool get isAnonymous => _authSource == AuthenticationSource.automatic;

  /// True only on web targets where `window.nostr` (a NIP-07 extension) is
  /// reachable. Used by the welcome screen to decide whether to surface the
  /// browser-extension sign-in button.
  bool get isNip07Available => _nip07Extension?.isAvailable ?? false;

  /// Current RPC capability state.
  AuthRpcCapability get authRpcCapability => _authRpcCapability;

  /// Stream of RPC capability changes.
  Stream<AuthRpcCapability> get authRpcCapabilityStream =>
      _rpcCapabilityController.stream;

  /// Whether signing is ready, still warming up, or permanently unavailable.
  ///
  /// This deliberately ignores [isRpcUpgradeInProgress]. That flag does not
  /// emit on every transition, while identity changes and [authRpcCapability]
  /// together provide the complete observable state.
  ///
  /// No stream carries this value, so sample it at the moment of use. A push
  /// consumer that waits for it to change must also watch a rebuild trigger
  /// such as `currentAuthRpcCapabilityProvider` (#6977).
  SignerReadiness get signerReadiness => resolveSignerReadiness(
    _currentIdentity,
    _authRpcCapability,
    rpcCapabilityInitialized: _authRpcCapabilityInitialized,
  );

  /// Whether this identity can publish Nostr writes right now.
  ///
  /// Shorthand for [signerReadiness] being ready; same sampling contract.
  bool get canPublishNostrWritesNow => signerReadiness == SignerReadiness.ready;

  /// True when a divineOAuth user's session expired and refresh failed.
  /// The user's identity is intact but remote signing is unavailable.
  /// UI should prompt re-login instead of "Secure Your Account".
  bool get hasExpiredOAuthSession => _hasExpiredOAuthSession;

  /// True while a background OAuth RPC upgrade is in progress during startup.
  /// The session-expired sheet should be suppressed until this resolves so the
  /// UI does not prompt re-login before the silent refresh has definitively failed.
  bool get isRpcUpgradeInProgress => _isRpcUpgradeInProgress;

  /// Legacy test-friendly short bound for background RPC refresh.
  @visibleForTesting
  static const rpcRefreshTimeout = Duration(seconds: 10);

  /// Default bound for the single-flight OAuth token refresh. It is longer
  /// than KeycastOAuth's own HTTP bound so production code does not abandon
  /// a slow-but-still-live request before the client has resolved it.
  @visibleForTesting
  static const defaultOAuthRefreshTimeout = Duration(seconds: 35);

  /// Default bound for the full expired-session refresh flow (token refresh
  /// plus session re-integration). This stays longer than the OAuth refresh
  /// bound so the outer flow does not detach from a live refresh.
  @visibleForTesting
  static const defaultExpiredSessionRefreshTimeout = Duration(seconds: 40);

  /// Default upper bound for one startup network operation while restoring a
  /// saved remote auth session. A bunker restore can do connect + pubkey pull,
  /// so callers that need an end-to-end budget should use
  /// [startupAuthRestoreTimeout].
  @visibleForTesting
  static const defaultStartupNetworkOperationTimeout = Duration(seconds: 10);

  /// Worst-case auth restore budget used by app startup splash handling.
  static const startupAuthRestoreTimeout = Duration(seconds: 21);

  /// Local-first Divine OAuth initialization.
  ///
  /// Loads the Keycast session and local keys. If a matching local private
  /// key exists, authenticates immediately and attempts RPC refresh in the
  /// background. If no local key exists, falls back to the previous
  /// synchronous refresh-or-fallback behavior.
  Future<void> _initializeDivineOAuth() async {
    Log.info(
      'initialize: restoring Divine OAuth session (local-first)...',
      name: 'AuthService',
      category: LogCategory.auth,
    );

    var session = await KeycastSession.load(_flutterSecureStorage);
    SecureKeyContainer? localKey;
    try {
      if (await _keyStorage.hasKeys()) {
        localKey = await _keyStorage.getKeyContainer();
      }
    } catch (e, stack) {
      _reportStorageError(e, stack, 'divineOAuth local key load');
    }

    // Detect and resolve diverged state: the global OAuth session and
    // local PRIMARY key belong to different accounts. This can happen
    // from pre-fix cross-contamination (Bug 2 corruption) OR from a
    // user adding a Keycast account originally registered on another
    // device (their local PRIMARY has a different device-only key).
    //
    // Use _kLastUsedNpubKey as the tiebreaker to decide which side is
    // authoritative. Whichever matches last-used wins. If neither
    // matches, safe default: clear the session.
    //
    // In all branches, the local nsec in secure key storage is never
    // deleted (Daniel rule: no silent key loss).
    if (session != null && localKey != null) {
      final sessionPubkey = session.userPubkey;
      final diverged =
          sessionPubkey == null || sessionPubkey != localKey.publicKeyHex;
      if (diverged) {
        final prefs = await SharedPreferences.getInstance();
        final lastUsedNpub = prefs.getString(_kLastUsedNpubKey);
        final localNpub = NostrKeyUtils.encodePubKey(localKey.publicKeyHex);
        final sessionNpub = sessionPubkey != null
            ? NostrKeyUtils.encodePubKey(sessionPubkey)
            : null;

        final sessionAuthoritative =
            sessionNpub != null && sessionNpub == lastUsedNpub;
        final localAuthoritative = localNpub == lastUsedNpub;

        if (sessionAuthoritative && !localAuthoritative) {
          // Session wins. The local PRIMARY key is stale (e.g., from
          // an older device-only account). Preserve the session,
          // force the slow path with null localKey, and archive the
          // stale local key into its per-identity slot so the user
          // can switch back to it via the welcome screen.
          Log.warning(
            'initialize: local key ${localKey.publicKeyHex} is stale — '
            'last-used=${pubkeyForLogs(lastUsedNpub)} matches session '
            'userPubkey=${pubkeyForLogs(sessionPubkey)}. Forcing slow path with '
            'session; archiving stale local key to ${pubkeyForLogs(localNpub)}.',
            name: 'AuthService',
            category: LogCategory.auth,
          );
          try {
            await _keyStorage.storeIdentityKeyContainer(localNpub, localKey);
          } catch (e) {
            Log.warning(
              'initialize: failed to archive stale local key: $e',
              name: 'AuthService',
              category: LogCategory.auth,
            );
          }
          localKey = null;
        } else if (localAuthoritative && !sessionAuthoritative) {
          // Local key wins. Clear the stale OAuth session.
          Log.warning(
            'initialize: global OAuth session pubkey='
            '${pubkeyForLogs(sessionPubkey, whenNull: "null (legacy)")} is stale — '
            'last-used=${pubkeyForLogs(lastUsedNpub)} matches local key '
            '${localKey.publicKeyHex}. Clearing stale session.',
            name: 'AuthService',
            category: LogCategory.auth,
          );
          await _clearKeycastSessionAndTokens();
          session = null;
        } else {
          // Ambiguous: neither (or both, impossible since diverged)
          // matches last-used. Safe default — clear the session. The
          // local key stays put and the fast path uses it.
          Log.warning(
            'initialize: divergence with ambiguous last-used npub — '
            'session=${pubkeyForLogs(sessionPubkey, whenNull: "null")}, '
            'local=${localKey.publicKeyHex}, last-used=${pubkeyForLogs(lastUsedNpub)}. '
            'Clearing global session (safe default).',
            name: 'AuthService',
            category: LogCategory.auth,
          );
          await _clearKeycastSessionAndTokens();
          session = null;
        }
      }
    }

    final targetPubkey = session?.userPubkey ?? localKey?.publicKeyHex;

    // Fast path: matching local key → authenticate immediately.
    if (_canUseLocalDivineIdentity(localKey, targetPubkey)) {
      _hasExpiredOAuthSession = session == null || !session.hasRpcAccess;
      _setRpcCapability(
        _hasExpiredOAuthSession
            ? AuthRpcCapability.upgrading
            : AuthRpcCapability.rpcReady,
      );

      // If we already have a valid session with RPC access, set up the
      // Keycast signer before building the identity so we get a
      // KeycastNostrIdentity instead of a LocalNostrIdentity.
      if (session != null && session.hasRpcAccess) {
        _setKeycastSigner(_newKeycastSigner(session));
      }

      await _setupUserSession(localKey!, AuthenticationSource.divineOAuth);

      Log.info(
        'initialize: local divine identity restored immediately '
        '(rpc=${_authRpcCapability.name})',
        name: 'AuthService',
        category: LogCategory.auth,
      );

      // If RPC isn't ready yet, try to upgrade in background.
      if (_authRpcCapability != AuthRpcCapability.rpcReady) {
        unawaited(_upgradeDivineRpcInBackground(session));
      }
      return;
    }

    // Slow path: no local key — try RPC refresh synchronously.
    await _restoreDivineRpcOrFallbackUnauthenticated(session);
  }

  /// Whether [localKey] can be used for immediate Divine OAuth identity.
  bool _canUseLocalDivineIdentity(
    SecureKeyContainer? localKey,
    String? targetPubkey,
  ) {
    if (localKey == null || !localKey.hasPrivateKey) return false;
    if (targetPubkey == null) return true; // No session to compare against.
    return localKey.publicKeyHex == targetPubkey;
  }

  /// Background RPC upgrade with bounded timeout.
  ///
  /// On success: rebuilds identity to [KeycastNostrIdentity] and sets
  /// [AuthRpcCapability.rpcReady]. On failure: preserves the local identity
  /// and sets capability back to [AuthRpcCapability.unavailable].
  Future<void> _upgradeDivineRpcInBackground(
    KeycastSession? session, {
    String? expectedOwnerPubkey,
    bool notifyAuthStateOnFailure = true,
  }) async {
    Log.info(
      'OAuth RPC upgrade: starting background refresh...',
      name: 'AuthService',
      category: LogCategory.auth,
    );

    // The refresh below runs unawaited across an async gap. If the user
    // signs out or switches accounts while it is in flight, applying the
    // result would attach the previous account's RPC signer to whichever
    // identity is active by then.
    final upgradeOwnerPubkey =
        expectedOwnerPubkey ?? session?.userPubkey ?? currentPublicKeyHex;
    bool upgradeContextStillCurrent() =>
        _authState == AuthState.authenticated &&
        currentPublicKeyHex == upgradeOwnerPubkey;

    _isRpcUpgradeInProgress = true;
    var didUpgrade = false;
    try {
      if (_oauthClient == null) {
        _setRpcCapability(AuthRpcCapability.unavailable);
        return;
      }

      final storedSession = await KeycastSession.load(_flutterSecureStorage);
      final storedOwnerPubkey = storedSession?.userPubkey;
      if (upgradeOwnerPubkey != null &&
          storedSession != null &&
          storedOwnerPubkey != upgradeOwnerPubkey) {
        Log.warning(
          'OAuth RPC upgrade: refusing refresh for owner ${pubkeyForLogs(upgradeOwnerPubkey)} '
          'because stored session belongs to ${pubkeyForLogs(storedOwnerPubkey)}',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        _setRpcCapability(AuthRpcCapability.unavailable);
        return;
      }

      // The shared refresh future is internally bounded by
      // [_oauthRefreshTimeout] (see [OAuthSessionCoordinator]), so this await
      // cannot block startup indefinitely.
      final refreshed = await _oauthCoordinator.refreshSession(
        expectedOwnerPubkey: expectedOwnerPubkey ?? session?.userPubkey,
      );

      if (!upgradeContextStillCurrent()) {
        Log.warning(
          'OAuth RPC upgrade: discarding stale background refresh — '
          'signed out or switched accounts while it was in flight',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        return;
      }

      if (refreshed != null) {
        if (upgradeOwnerPubkey != null &&
            refreshed.userPubkey != upgradeOwnerPubkey) {
          Log.warning(
            'OAuth RPC upgrade: refusing refreshed session for owner '
            '${pubkeyForLogs(upgradeOwnerPubkey)}; got ${pubkeyForLogs(refreshed.userPubkey)}',
            name: 'AuthService',
            category: LogCategory.auth,
          );
          return;
        }
        Log.info(
          'OAuth RPC upgrade: background refresh succeeded',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        await clearDismissedDivineLoginBannerForCurrentUser();
        if (!upgradeContextStillCurrent()) {
          Log.warning(
            'OAuth RPC upgrade: discarding refreshed signer after banner clear '
            'because the signed-in account changed',
            name: 'AuthService',
            category: LogCategory.auth,
          );
          return;
        }
        // Same-pubkey re-emission: retain the live client's signer (#5909).
        _setKeycastSigner(_newKeycastSigner(refreshed), closePrevious: false);
        _currentIdentity = _buildIdentity();
        _hasExpiredOAuthSession = false;
        _setRpcCapability(AuthRpcCapability.rpcReady);
        didUpgrade = true;
        return;
      }
    } on OAuthNetworkException catch (e) {
      Log.warning(
        'OAuth RPC upgrade: background refresh failed due to network: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
    } catch (e) {
      Log.error(
        'OAuth RPC upgrade: background refresh failed: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
    } finally {
      _isRpcUpgradeInProgress = false;
      // Nudge the auth stream so widgets re-evaluate after successful upgrades
      // and after startup failures. Resume failures leave degraded state
      // unchanged and should not re-present the session-expired sheet.
      if (didUpgrade || notifyAuthStateOnFailure) {
        _authStateController.add(_authState);
      }
    }

    // A late failure must not downgrade whichever account is active now.
    if (!upgradeContextStillCurrent()) {
      return;
    }

    _setRpcCapability(AuthRpcCapability.unavailable);
  }

  /// Synchronous fallback for Divine OAuth when no local key is available.
  ///
  /// Attempts RPC refresh, then falls back to unauthenticated.
  Future<void> _restoreDivineRpcOrFallbackUnauthenticated(
    KeycastSession? session,
  ) async {
    // Read the session recovery anchor once. Both the direct-restore and the
    // refresh paths below use it to detect cross-account cold-start restores.
    final prefs = await SharedPreferences.getInstance();
    final anchorNpub = prefs.getString(_kSessionRecoveryAnchorKey);

    // If session is valid with RPC access, check whether it belongs to the
    // same account the user was signed into when they last signed out.
    //
    // If a session-recovery anchor exists and the session belongs to a
    // DIFFERENT account (cross-account cold-start restore), do NOT silently
    // complete the sign-in. Instead route to unauthenticated so the welcome
    // screen can surface a confirmation banner — the user gets to decide
    // explicitly which account they want. If no anchor exists (fresh install,
    // or first sign-out after the fix) we fall through to the original
    // behaviour to avoid breaking the normal single-account flow.
    if (session != null && session.hasRpcAccess) {
      if (isCrossAccountSessionRestore(
        candidatePubkey: session.userPubkey,
        anchorNpub: anchorNpub,
      )) {
        _setAuthState(AuthState.unauthenticated);
        return;
      }

      Log.info(
        'initialize: Divine OAuth session found with RPC access '
        '(no local key)',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      await signInWithDivineOAuth(session);
      return;
    }

    // Try refresh.
    Log.info(
      'initialize: no local key, attempting synchronous refresh...',
      name: 'AuthService',
      category: LogCategory.auth,
    );
    if (_oauthClient != null) {
      final KeycastSession? refreshed;
      try {
        refreshed = await _oauthCoordinator
            .refreshSession(expectedOwnerPubkey: session?.userPubkey)
            .timeout(
              _startupNetworkOperationTimeout,
              onTimeout: () => throw OAuthNetworkException(
                'OAuth startup refresh timed out',
              ),
            );
      } on OAuthNetworkException catch (e) {
        Log.warning(
          'initialize: synchronous refresh failed due to network: $e',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        await _restoreDegradedDivineOAuthSession(
          session,
          anchorNpub: anchorNpub,
        );
        return;
      }

      if (refreshed != null) {
        // Apply the same cross-account guard to the refreshed session.
        // The OAuth server is authoritative about which account a token
        // belongs to, but we must not silently complete a sign-in as a
        // different account than the one the user was on at sign-out.
        if (isCrossAccountSessionRestore(
          candidatePubkey: refreshed.userPubkey,
          anchorNpub: anchorNpub,
        )) {
          // Do NOT consume the refresh or set _hasExpiredOAuthSession=false
          // here — leave the user unauthenticated and let the welcome screen
          // handle the confirmation. The refreshed token is discarded; the
          // user will go through a full re-auth for whichever account they
          // confirm.
          _setAuthState(AuthState.unauthenticated);
          return;
        }

        Log.info(
          'initialize: refresh succeeded',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        await clearDismissedDivineLoginBannerForCurrentUser();
        await signInWithDivineOAuth(refreshed);
        return;
      }
    }

    // Refresh failed, no local keys — unauthenticated.
    _hasExpiredOAuthSession = true;
    Log.info(
      'initialize: refresh failed, no local keys — '
      'unauthenticated with expired session flag',
      name: 'AuthService',
      category: LogCategory.auth,
    );
    _setAuthState(AuthState.unauthenticated);
  }

  Future<void> _restoreDegradedDivineOAuthSession(
    KeycastSession? session, {
    required String? anchorNpub,
  }) async {
    final hasOwnerPubkey = session?.userPubkey?.isNotEmpty ?? false;
    final hasRefreshToken = session?.refreshToken?.isNotEmpty ?? false;
    if (session == null || !hasOwnerPubkey || !hasRefreshToken) {
      _hasExpiredOAuthSession = true;
      _setAuthState(AuthState.unauthenticated);
      return;
    }

    if (isCrossAccountSessionRestore(
      candidatePubkey: session.userPubkey,
      anchorNpub: anchorNpub,
    )) {
      _setAuthState(AuthState.unauthenticated);
      return;
    }

    Log.info(
      'initialize: keeping Divine OAuth session authenticated while RPC '
      'refresh waits for connectivity',
      name: 'AuthService',
      category: LogCategory.auth,
    );
    await signInWithDivineOAuth(
      session,
      rpcCapability: AuthRpcCapability.upgrading,
      allowPubkeyOnlyIdentity: true,
    );
    _hasExpiredOAuthSession = true;
    unawaited(
      _upgradeDivineRpcInBackground(
        session,
        expectedOwnerPubkey: session.userPubkey,
      ),
    );
  }

  /// Attempt to silently refresh an expired OAuth session.
  ///
  /// Returns true if the refresh succeeded and the user is now fully
  /// authenticated. Returns false if no expired session exists or if
  /// the refresh fails (caller should navigate to login).
  ///
  /// Concurrent callers share a single in-flight refresh to avoid
  /// consuming one-time-use refresh tokens in a race. The shared future is
  /// bounded by [_expiredSessionRefreshTimeout] so a hung attempt always
  /// releases the slot and the next call starts a fresh refresh (#4942).
  Future<bool> tryRefreshExpiredSession() => _oauthCoordinator
      .refreshExpiredSession(attempt: _doRefreshExpiredSession);

  Future<bool> _doRefreshExpiredSession() {
    Log.info(
      'tryRefreshExpiredSession: attempting silent refresh',
      name: 'AuthService',
      category: LogCategory.auth,
    );
    return _tryRefreshOAuthSession(
      caller: 'tryRefreshExpiredSession',
      expectedOwnerPubkey: currentPublicKeyHex,
    );
  }

  /// Returns the npub that was actively signed in at the time of the most
  /// recent sign-out, or null if no anchor has been recorded.
  ///
  /// The welcome screen uses this to detect when a cold-start session restore
  /// would land on a different account than the one the user was just using,
  /// and surfaces a confirmation banner before the switch completes silently.
  ///
  /// The anchor is written at the start of [signOut] and cleared by
  /// [_setupUserSession] once the user has explicitly signed back in.
  Future<String?> getSessionRecoveryAnchorNpub() async =>
      (await SharedPreferences.getInstance()).getString(
        _kSessionRecoveryAnchorKey,
      );

  /// Shared OAuth session refresh logic used by both [initialize] and
  /// [tryRefreshExpiredSession]. Returns true if refresh succeeded.
  Future<bool> _tryRefreshOAuthSession({
    required String caller,
    String? expectedOwnerPubkey,
  }) async {
    final KeycastSession? refreshed;
    try {
      refreshed = await _oauthCoordinator.refreshSession(
        expectedOwnerPubkey: expectedOwnerPubkey,
        storedSessionReader: () => KeycastSession.load(_flutterSecureStorage),
        caller: caller,
      );
    } on OAuthNetworkException catch (e) {
      Log.warning(
        '$caller: refresh failed due to network: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      return false;
    }
    if (refreshed != null) {
      if (expectedOwnerPubkey != null &&
          refreshed.userPubkey != expectedOwnerPubkey) {
        return false;
      }
      Log.info(
        '$caller: refresh succeeded',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      await clearDismissedDivineLoginBannerForCurrentUser(expectedOwnerPubkey);
      if (expectedOwnerPubkey != null &&
          currentPublicKeyHex != expectedOwnerPubkey) {
        return false;
      }
      await signInWithDivineOAuth(refreshed);
      return true;
    }
    return false;
  }

  /// [TokenRefreshCallback] passed to [KeycastRpc] so it can recover
  /// from mid-session 401s without caller involvement.
  ///
  /// Delegates to [OAuthSessionCoordinator.refreshAccessToken] which
  /// deduplicates concurrent callers — multiple in-flight RPC 401s and
  /// app-resume refresh all share a single refresh token exchange.
  Future<String?> _refreshAccessToken() =>
      _oauthCoordinator.refreshAccessToken();

  KeycastRpc _newKeycastSigner(KeycastSession session) =>
      KeycastRpc.fromSession(
        _oauthConfig,
        session,
        onTokenRefresh: _refreshAccessToken,
      );

  void _setKeycastSigner(KeycastRpc? signer, {bool closePrevious = true}) {
    if (identical(_keycastSigner, signer)) return;
    final previous = _keycastSigner;
    _keycastSigner = signer;
    if (closePrevious) previous?.close();
  }

  /// Get discovered user relays (NIP-65)
  List<DiscoveredRelay> get userRelays => List.unmodifiable(_userRelays);

  /// Register a callback to be invoked when NIP-65 relay discovery completes
  /// with a non-empty list. Pass [null] to unregister.
  /// NostrService uses this to add discovered relays to the current client
  /// without blocking app startup.
  void registerUserRelaysDiscoveredCallback(
    UserRelaysDiscoveredCallback? callback,
  ) {
    _onUserRelaysDiscovered = callback;
  }

  /// Register a callback to publish a bootstrap kind:10002 on behalf of the
  /// signed-in user when indexer discovery returns empty. Pass [null] to
  /// unregister.
  ///
  /// AuthService builds + signs the event; the callback owner is expected to
  /// broadcast it via the current [NostrClient]. See
  /// [RelayDiscoveryOrchestrator.publishBootstrapRelayList] and #3174.
  void registerBootstrapRelayListCallback(
    BootstrapRelayListCallback? callback,
  ) {
    _onBootstrapRelayListRequested = callback;
  }

  /// Register work that must run with the outgoing session still available.
  ///
  /// The returned disposer unregisters [callback]. AuthService runs remaining
  /// callbacks sequentially at sign-out before clearing [currentIdentity],
  /// signers, or Nostr callbacks.
  ///
  /// All callbacks share a single 5 second sign-out budget. A timeout is
  /// warning-only: sign-out continues and later callbacks still get a chance to
  /// run if budget remains. Dart [Future.timeout] does not cancel the
  /// underlying future, so callbacks must tolerate late completion after the
  /// outgoing identity/signers have been cleared.
  VoidCallback registerBeforeSessionTeardownCallback(
    BeforeSessionTeardownCallback callback,
  ) {
    _beforeSessionTeardownCallbacks.add(callback);
    var registered = true;
    return () {
      if (!registered) return;
      registered = false;
      _beforeSessionTeardownCallbacks.remove(callback);
    };
  }

  /// Check if user has an existing profile (kind 0)
  bool get hasExistingProfile => _hasExistingProfile;

  /// Last authentication error
  String? get lastError => _lastError;

  /// Clear the last authentication error
  ///
  /// Call this when navigating away from screens that displayed the error,
  /// to prevent stale errors from being shown on other screens.
  void clearError() {
    _lastError = null;
  }

  /// Report a secure storage error to Crashlytics with auth context.
  void _reportStorageError(Object error, StackTrace stack, String reason) {
    _reportAuthError(
      error,
      stack,
      reason: reason,
      logMessage: 'Storage error during auth: $reason',
    );
  }

  void _reportAuthError(
    Object error,
    StackTrace stack, {
    required String reason,
    required String logMessage,
  }) {
    final crashlytics = _crashReporter;
    crashlytics.log(logMessage);
    unawaited(crashlytics.setCustomKey('auth_source', _authSource.code));
    unawaited(crashlytics.recordError(error, stack, reason: reason));
  }

  void _reportNonFatalAuthCleanupError(
    Object error,
    StackTrace stack,
    String reason,
  ) {
    _reportAuthError(error, stack, reason: reason, logMessage: reason);
  }

  /// Clears any persisted Divine OAuth session that was created before an
  /// invite consume completed.
  ///
  /// Invite flows can exchange OAuth tokens before invite activation runs.
  /// If activation then fails, startup must not restore that partial session
  /// and bypass the invite gate on the next launch.
  Future<void> clearPendingDivineOAuthSession() async {
    try {
      await _clearKeycastSessionAndTokens();
    } catch (e) {
      Log.warning(
        'Failed to clear pending Divine OAuth session: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      // Invite activation failures can legitimately leave no session to clear.
      // Keep local visibility without sending expected cleanup noise upstream.
    }
  }

  /// Initialize the authentication service
  Future<void> initialize() async {
    Log.debug(
      'Initializing SecureAuthService',
      name: 'AuthService',
      category: LogCategory.auth,
    );

    // Set checking state immediately - we're starting the auth check now
    _setAuthState(AuthState.checking);

    await _prepareRuntime();

    try {
      // Decide restore path based on persisted authentication source
      final authSource = await _loadAuthSource();
      Log.info(
        'authSource: $authSource',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      switch (authSource) {
        case AuthenticationSource.none:
          // Explicit logout or fresh install — show welcome
          Log.info(
            'initialize: authSource=none — fresh install or explicit logout',
            name: 'AuthService',
            category: LogCategory.auth,
          );
          _setAuthState(AuthState.unauthenticated);
          return;

        case AuthenticationSource.divineOAuth:
          await _initializeDivineOAuth();
          return;

        case AuthenticationSource.importedKeys:
          await _restoreLastUsedAccountOrFallback(
            AuthenticationSource.importedKeys,
          );

        case AuthenticationSource.automatic:
          await _restoreLastUsedAccountOrFallback(
            AuthenticationSource.automatic,
          );

        case AuthenticationSource.bunker:
          // Try to restore bunker connection from secure storage
          Log.info(
            'initialize: restoring bunker connection...',
            name: 'AuthService',
            category: LogCategory.auth,
          );
          final bunkerInfo = await _loadBunkerInfo();
          if (bunkerInfo != null) {
            await _reconnectBunker(bunkerInfo, boundedByStartupTimeout: true);
            return;
          }
          // Bunker info not found — fall back to unauthenticated
          Log.warning(
            'initialize: bunker info not found in secure storage',
            name: 'AuthService',
            category: LogCategory.auth,
          );
          _setAuthState(AuthState.unauthenticated);
          return;

        case AuthenticationSource.amber:
          // Try to restore Amber (NIP-55) connection from secure storage
          Log.info(
            'initialize: restoring Amber connection...',
            name: 'AuthService',
            category: LogCategory.auth,
          );
          final amberInfo = await _loadAmberInfo();
          if (amberInfo != null) {
            Log.info(
              'initialize: Amber info found — pubkey=${pubkeyForLogs(amberInfo.pubkey)}',
              name: 'AuthService',
              category: LogCategory.auth,
            );
            await _reconnectAmber(amberInfo.pubkey, amberInfo.package);
            return;
          }
          // Amber info not found — fall back to unauthenticated
          Log.warning(
            'initialize: Amber info not found in secure storage',
            name: 'AuthService',
            category: LogCategory.auth,
          );
          _setAuthState(AuthState.unauthenticated);
          return;

        case AuthenticationSource.nip07:
          Log.info(
            'initialize: restoring NIP-07 session...',
            name: 'AuthService',
            category: LogCategory.auth,
          );
          if (kIsWeb) {
            await _reconnectNip07();
            return;
          }
          Log.warning(
            'initialize: persisted nip07 source on non-web platform — '
            'falling back to unauthenticated',
            name: 'AuthService',
            category: LogCategory.auth,
          );
          _setAuthState(AuthState.unauthenticated);
          return;
      }

      Log.info(
        'SecureAuthService initialized',
        name: 'AuthService',
        category: LogCategory.auth,
      );
    } catch (e) {
      Log.error(
        'SecureAuthService initialization failed: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      _lastError = 'Failed to initialize auth: $e';

      // Set state synchronously to prevent loading screen deadlock
      _setAuthState(AuthState.unauthenticated);
    }
  }

  /// Prepares this service for an explicit account switch.
  ///
  /// Unlike [initialize], this does not restore whichever identity is currently
  /// in PRIMARY. The target account is selected immediately afterwards by
  /// [signInForAccount], so restoring first would mutate the new container to
  /// the leaving account and run legacy-row claiming under the wrong boundary.
  Future<void> initializeForAccountSwitch() async {
    Log.debug(
      'Preparing SecureAuthService for account switch',
      name: 'AuthService',
      category: LogCategory.auth,
    );
    await _prepareRuntime();
    _setAuthState(AuthState.unauthenticated);
  }

  Future<void> _prepareRuntime() async {
    if (!_registeredWithBackgroundActivity) {
      _backgroundActivityManager.registerService(this);
      _registeredWithBackgroundActivity = true;
    }
    await _keyStorage.initialize();
  }

  /// Create a new Nostr identity
  Future<AuthResult> createNewIdentity({String? biometricPrompt}) async {
    Log.debug(
      '📱 Creating new secure Nostr identity',
      name: 'AuthService',
      category: LogCategory.auth,
    );

    _setAuthState(AuthState.authenticating);
    _lastError = null;

    try {
      // Generate new secure key container
      final keyContainer = await _keyStorage.generateAndStoreKeys(
        biometricPrompt: biometricPrompt,
      );

      // Set up user session
      await _setupUserSession(
        keyContainer,
        AuthenticationSource.automatic,
        seedEmptyFollowingCache: true,
      );

      Log.info(
        'New secure identity created successfully',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      Log.debug(
        '📱 Public key: ${pubkeyForLogs(keyContainer.npub)}',
        name: 'AuthService',
        category: LogCategory.auth,
      );

      return AuthResult.success(keyContainer);
    } catch (e) {
      Log.error(
        'Failed to create secure identity: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      _lastError = 'Failed to create identity: $e';
      _setAuthState(AuthState.unauthenticated);

      return AuthResult.failure(_lastError!);
    }
  }

  /// Create a new anonymous account with a fresh identity.
  ///
  /// Always generates a brand-new keypair. Used by the "Skip for now" flow
  /// on the create-account screen so that each skip produces a distinct
  /// anonymous identity.
  ///
  /// The previous identity (if any) remains archived in per-account storage
  /// and in the known-accounts registry, so the user can switch back to it.
  ///
  /// Throws if identity creation fails.
  Future<void> createAnonymousAccount() async {
    Log.info(
      'createAnonymousAccount: starting — clearing primary key slot',
      name: 'AuthService',
      category: LogCategory.auth,
    );

    // Clear the primary key slot so createNewIdentity() writes fresh keys
    // instead of _checkExistingAuth() finding and reusing old ones.
    await _keyStorage.deleteKeys();

    final result = await createNewIdentity();
    if (!result.success) {
      Log.error(
        'createAnonymousAccount: identity creation failed — '
        '${result.errorMessage}',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      throw Exception(result.errorMessage ?? 'Failed to create identity');
    }

    Log.info(
      'createAnonymousAccount: identity created, accepting terms — '
      'pubkey=${result.keyContainer?.publicKeyHex}',
      name: 'AuthService',
      category: LogCategory.auth,
    );

    await acceptTerms();

    Log.info(
      'createAnonymousAccount: complete',
      name: 'AuthService',
      category: LogCategory.auth,
    );
  }

  /// Create a new anonymous account from a pre-generated key container.
  ///
  /// Used by invite-gated signup so the app can consume the invite with the
  /// new key before persisting it to secure storage.
  Future<void> createAnonymousAccountFromKeyContainer(
    SecureKeyContainer keyContainer,
  ) async {
    String? privateKeyHex;
    keyContainer.withPrivateKey<void>((privateKey) {
      privateKeyHex = privateKey;
    });

    if (privateKeyHex == null || privateKeyHex!.isEmpty) {
      throw Exception('Failed to read generated identity key');
    }

    await createAnonymousAccountFromPrivateKeyHex(privateKeyHex!);
  }

  /// Create a new anonymous account from a known private key.
  Future<void> createAnonymousAccountFromPrivateKeyHex(
    String privateKeyHex,
  ) async {
    Log.info(
      'createAnonymousAccountFromPrivateKeyHex: starting — '
      'clearing primary key slot',
      name: 'AuthService',
      category: LogCategory.auth,
    );

    _setAuthState(AuthState.authenticating);
    _lastError = null;

    try {
      await _keyStorage.deleteKeys();
      final keyContainer = await _keyStorage.importFromHex(privateKeyHex);
      await _setupUserSession(
        keyContainer,
        AuthenticationSource.automatic,
        seedEmptyFollowingCache: true,
      );
      await acceptTerms();

      Log.info(
        'createAnonymousAccountFromPrivateKeyHex: complete',
        name: 'AuthService',
        category: LogCategory.auth,
      );
    } catch (e) {
      Log.error(
        'createAnonymousAccountFromPrivateKeyHex failed: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      _lastError = 'Failed to create identity: $e';
      _setAuthState(AuthState.unauthenticated);
      rethrow;
    }
  }

  Future<AuthenticationSource> _loadAuthSource() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(kAuthenticationSourceKey);
      final authSource = AuthenticationSource.fromCode(raw);
      Log.info(
        'Loaded $kAuthenticationSourceKey as $authSource',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      return authSource;
    } catch (e) {
      return AuthenticationSource.automatic;
    }
  }

  /// Reads the list of known accounts from SharedPreferences.
  Future<List<KnownAccount>> getKnownAccounts() =>
      _knownAccounts.getKnownAccounts();

  /// Removes a known account and its archived signer info.
  Future<void> removeKnownAccount(String pubkeyHex) async {
    await _knownAccounts.remove(pubkeyHex);
    await _clearArchivedSignerInfo(pubkeyHex);
  }

  /// Deletes one local account without disturbing another active account.
  Future<void> deleteLocalAccount(String pubkeyHex) async {
    final npub = NostrKeyUtils.encodePubKey(pubkeyHex);
    final prefs = await SharedPreferences.getInstance();
    Object? keyDeletionError;
    Object? cleanupError;
    try {
      await _userDataCleanupService.deleteAccountData(
        pubkeyHex,
        userNpub: npub,
        preserveActiveSession: _currentKeyContainer != null,
      );
    } catch (error) {
      cleanupError = error;
    }
    try {
      await CacheSync.invalidatePrefix(pubkeyHex);
    } catch (error, stackTrace) {
      cleanupError ??= error;
      _reportStorageError(error, stackTrace, 'deleteLocalAccount invalidation');
    }
    try {
      await _knownAccounts.removeStrict(pubkeyHex);
    } catch (error) {
      cleanupError ??= error;
    }
    try {
      await _signerStore.clearAccount(pubkeyHex);
    } catch (error) {
      keyDeletionError = error;
    }
    try {
      await _deleteStoredLoginForAccount(npub);
    } catch (error) {
      keyDeletionError ??= error;
    }
    if (keyDeletionError != null) {
      throw SecureKeyStorageException(
        'Local account deletion failed: $keyDeletionError',
      );
    }
    if (cleanupError != null) {
      throw UserDataCleanupException(
        'Local account data cleanup failed',
        cleanupError,
      );
    }
    if (_currentKeyContainer == null) {
      try {
        if (prefs.getString(_kSessionRecoveryAnchorKey) == npub &&
            !await prefs.remove(_kSessionRecoveryAnchorKey)) {
          throw StateError('Could not clear the session recovery anchor');
        }
        await _resetRecoveryAfterLocalAccountRemoval(prefs, strict: true);
      } catch (error) {
        throw UserDataCleanupException(
          'Local account recovery cleanup failed',
          error,
        );
      }
    }
  }

  /// Pubkey to pre-select on the welcome screen after the next sign-out.
  ///
  /// Set this before calling [signOut] when the user picks a different account
  /// from the account-switcher. [WelcomeBloc] reads and clears this on start.
  String? pendingAccountSwitchPubkey;

  /// Copies active-session signer keys to per-account archive keys.
  ///
  /// Called during non-destructive sign-out so the signer info can be
  /// restored when the user picks this account from the welcome screen.
  Future<void> _archiveSignerInfo(String pubkeyHex) =>
      _signerStore.archive(pubkeyHex);

  /// Archives the active signer keys under the currently signed-in account.
  ///
  /// The in-place account switch swaps the container instead of signing out,
  /// so the sign-out archival above never runs for the leaving account. Signing
  /// the incoming account in then overwrites the shared signer slots — for a
  /// local-key account [SignerSecureStore.restoreActiveKeys] even clears the
  /// OAuth session outright — and the leaving account is left with no session
  /// and no refresh token to recover from. Call this before the incoming
  /// account's sign-in.
  ///
  /// Throws when the archive write fails, unlike the sign-out path that
  /// swallows it. The swap has no second chance: the incoming sign-in wipes the
  /// shared slots this copies from, so carrying on after a failed write
  /// destroys the leaving account's session for a log line. Aborting is safe
  /// because this runs before the swap mutates anything.
  Future<void> archiveCurrentSignerInfo() async {
    final pubkeyHex = currentPublicKeyHex;
    if (pubkeyHex == null) {
      Log.warning(
        'archiveCurrentSignerInfo: no signed-in account to archive',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      return;
    }
    await _signerStore.archive(pubkeyHex, throwOnFailure: true);
  }

  /// Restores the currently signed-in account's archived signer keys back into
  /// the shared slots, undoing a different account's restore.
  ///
  /// The counterpart to [archiveCurrentSignerInfo]: a failed in-place switch
  /// has already run the target account's [_restoreSignerInfo], which
  /// overwrote the shared signer slots and the persisted auth source. Rolling
  /// the container back does not undo either — this account keeps working from
  /// memory but reads the wrong signer at the next launch. Call this on the
  /// swap's rollback path.
  Future<void> restoreSignerInfoForCurrentAccount() async {
    final pubkeyHex = currentPublicKeyHex;
    if (pubkeyHex == null) {
      Log.warning(
        'restoreSignerInfoForCurrentAccount: no signed-in account to restore',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      return;
    }
    await _restoreSignerInfo(pubkeyHex, _authSource);
  }

  /// Restores per-account signer keys to the active-session keys.
  ///
  /// Called before sign-in when switching to a previously used account.
  /// Delegates the secure-storage swap to [SignerSecureStore] and keeps the
  /// auth-source SharedPreferences write here so `initialize()` picks the
  /// right path.
  Future<void> _restoreSignerInfo(
    String pubkeyHex,
    AuthenticationSource source,
  ) async {
    if (_flutterSecureStorage == null) return;
    try {
      await _signerStore.restoreActiveKeys(pubkeyHex, source);

      // Set the auth source so initialize() picks the right path
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(kAuthenticationSourceKey, source.code);

      Log.info(
        'Restored signer info for ${pubkeyForLogs(pubkeyHex)} (source=${source.name})',
        name: 'AuthService',
        category: LogCategory.auth,
      );
    } catch (e) {
      Log.warning(
        'Failed to restore signer info for ${pubkeyForLogs(pubkeyHex)}: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
    }
  }

  /// Deletes all per-account archived signer keys for a given pubkey.
  Future<void> _clearArchivedSignerInfo(String pubkeyHex) =>
      _signerStore.clearArchive(pubkeyHex);

  /// Signs in with a previously used account.
  ///
  /// Restores the signer info for the given [pubkeyHex] based on its
  /// [authSource], then calls the appropriate sign-in path.
  Future<void> signInForAccount(
    String pubkeyHex,
    AuthenticationSource authSource, {
    bool claimLegacyRows = true,
  }) async {
    Log.info(
      'signInForAccount: pubkey=${pubkeyForLogs(pubkeyHex)}, source=${authSource.name}',
      name: 'AuthService',
      category: LogCategory.auth,
    );

    Log.info(
      'signInForAccount: restoring signer info...',
      name: 'AuthService',
      category: LogCategory.auth,
    );
    await _restoreSignerInfo(pubkeyHex, authSource);

    switch (authSource) {
      case AuthenticationSource.amber:
        Log.info(
          'signInForAccount: loading Amber info for reconnect...',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        final amberInfo = await _loadAmberInfo();
        if (amberInfo != null) {
          await _reconnectAmber(amberInfo.pubkey, amberInfo.package);
        } else {
          Log.error(
            'signInForAccount: no archived Amber info for ${pubkeyForLogs(pubkeyHex)}',
            name: 'AuthService',
            category: LogCategory.auth,
          );
          throw Exception('No archived Amber info found for $pubkeyHex');
        }

      case AuthenticationSource.bunker:
        Log.info(
          'signInForAccount: loading bunker info for reconnect...',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        final bunkerInfo = await _loadBunkerInfo();
        if (bunkerInfo != null) {
          await _reconnectBunker(bunkerInfo);
        } else {
          Log.error(
            'signInForAccount: no archived bunker info for ${pubkeyForLogs(pubkeyHex)}',
            name: 'AuthService',
            category: LogCategory.auth,
          );
          throw Exception('No archived Bunker info found for $pubkeyHex');
        }

      case AuthenticationSource.nip07:
        Log.info(
          'signInForAccount: restoring NIP-07 session...',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        if (kIsWeb) {
          await _reconnectNip07();
        } else {
          Log.error(
            'signInForAccount: persisted nip07 source on non-web platform',
            name: 'AuthService',
            category: LogCategory.auth,
          );
          throw Exception('NIP-07 sign-in is only available on the web.');
        }

      case AuthenticationSource.divineOAuth:
        Log.info(
          'signInForAccount: loading OAuth session for reconnect...',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        final session = await KeycastSession.load(_flutterSecureStorage);
        // Verify the loaded session belongs to the requested account.
        // After sign-out, the global slot may still hold a different
        // account's session if _restoreSignerInfo found no archive.
        final sessionMatchesAccount =
            session != null &&
            session.hasRpcAccess &&
            session.userPubkey == pubkeyHex;
        if (sessionMatchesAccount) {
          await signInWithDivineOAuth(session);
        } else {
          // Session is expired, missing, wrong account, or has no
          // RPC access. Try to refresh, then fall back to local
          // keys — same recovery strategy as _initializeDivineOAuth.
          Log.info(
            'signInForAccount: OAuth session not usable for ${pubkeyForLogs(pubkeyHex)} '
            '(session=${session != null}, '
            'hasRpcAccess=${session?.hasRpcAccess}, '
            'isExpired=${session?.isExpired}, '
            'sessionPubkey=${pubkeyForLogs(session?.userPubkey)}, '
            'requestedPubkey=${pubkeyForLogs(pubkeyHex)}), attempting refresh...',
            name: 'AuthService',
            category: LogCategory.auth,
          );
          // Only attempt refresh if the global slot belongs to the
          // requested account — refreshing a different account's token
          // would sign in as the wrong identity.
          final canRefresh =
              _oauthClient != null && session?.userPubkey == pubkeyHex;
          if (canRefresh) {
            final refreshed = await _tryRefreshOAuthSession(
              caller: 'signInForAccount',
              expectedOwnerPubkey: pubkeyHex,
            );
            if (refreshed) break;
          }

          // Refresh failed — try local keys so the user can at least
          // read their feed while RPC catches up in the background.
          final npub = NostrKeyUtils.encodePubKey(pubkeyHex);
          SecureKeyContainer? localKey;
          try {
            localKey = await _keyStorage.getIdentityKeyContainer(npub);
            if (localKey == null && await _keyStorage.hasKeys()) {
              final primary = await _keyStorage.getKeyContainer();
              if (primary?.publicKeyHex == pubkeyHex) {
                localKey = primary;
              }
            }
          } catch (e) {
            Log.warning(
              'signInForAccount: local key lookup failed: $e',
              name: 'AuthService',
              category: LogCategory.auth,
            );
          }

          if (localKey != null) {
            Log.info(
              'signInForAccount: using local keys for ${pubkeyForLogs(pubkeyHex)} '
              'with expired OAuth session flag',
              name: 'AuthService',
              category: LogCategory.auth,
            );
            _hasExpiredOAuthSession = true;
            _setRpcCapability(AuthRpcCapability.upgrading);
            await _setupUserSession(
              localKey,
              AuthenticationSource.divineOAuth,
              claimLegacyRows: claimLegacyRows,
            );
            unawaited(
              _upgradeDivineRpcInBackground(
                session,
                expectedOwnerPubkey: pubkeyHex,
              ),
            );
          } else {
            Log.warning(
              'signInForAccount: no refresh, no local keys for '
              '${pubkeyForLogs(pubkeyHex)} — session expired',
              name: 'AuthService',
              category: LogCategory.auth,
            );
            throw SessionExpiredException();
          }
        }

      case AuthenticationSource.importedKeys:
      case AuthenticationSource.automatic:
        // Try to switch to saved identity keys
        final npub = NostrKeyUtils.encodePubKey(pubkeyHex);
        Log.info(
          'signInForAccount: loading identity keys for ${pubkeyForLogs(npub)}',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        final container = await _keyStorage.getIdentityKeyContainer(npub);
        if (container != null) {
          Log.info(
            'signInForAccount: identity keys found — '
            'pubkey=${container.publicKeyHex}',
            name: 'AuthService',
            category: LogCategory.auth,
          );
          await _keyStorage.switchToIdentity(npub);
          await _setupUserSession(
            container,
            authSource,
            claimLegacyRows: claimLegacyRows,
          );
        } else {
          // Fall back to current PRIMARY keys only when they belong to the
          // requested account. `_checkExistingAuth` intentionally restores
          // whatever PRIMARY account is present, which is correct for app
          // startup but unsafe for an explicit account-switch request.
          Log.warning(
            'signInForAccount: no saved identity keys for ${pubkeyForLogs(npub)} — '
            'checking PRIMARY key for same-account fallback',
            name: 'AuthService',
            category: LogCategory.auth,
          );
          SecureKeyContainer? primary;
          try {
            if (await _keyStorage.hasKeys()) {
              primary = await _keyStorage.getKeyContainer();
            }
          } catch (e, stack) {
            Log.error(
              'signInForAccount: failed to inspect PRIMARY key fallback: $e',
              name: 'AuthService',
              category: LogCategory.auth,
            );
            _reportStorageError(e, stack, 'signInForAccount primary fallback');
          }

          if (primary?.publicKeyHex == pubkeyHex) {
            Log.info(
              'signInForAccount: PRIMARY key matches requested account — '
              'using same-account fallback',
              name: 'AuthService',
              category: LogCategory.auth,
            );
            await _setupUserSession(
              primary!,
              authSource,
              claimLegacyRows: claimLegacyRows,
            );
          } else {
            Log.warning(
              'signInForAccount: no restorable local keys for ${pubkeyForLogs(pubkeyHex)} '
              '(primaryPubkey=${primary?.publicKeyHex})',
              name: 'AuthService',
              category: LogCategory.auth,
            );
            _setAuthState(AuthState.unauthenticated);
          }
        }

      case AuthenticationSource.none:
        Log.error(
          'signInForAccount: cannot sign in with authSource=none',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        throw Exception('Cannot sign in with auth source "none"');
    }

    // Guard against silent restore failures. Several branches above can resolve
    // normally without restoring the requested account:
    //   - importedKeys/automatic whose identity keys are missing and no
    //     matching PRIMARY key exists resolve unauthenticated.
    //   - `_setupUserSession` swallows internal failures into
    //     `awaitingTosAcceptance`.
    // These previously left the caller believing the sign-in succeeded while
    // the router kept the user on `/welcome`, or worse, authenticated the wrong
    // local account. Surface the failure so the caller can route to the full
    // login flow instead. See #5195.
    final resolvedPubkeyHex = currentPublicKeyHex;
    if (_authState != AuthState.authenticated ||
        resolvedPubkeyHex != pubkeyHex) {
      Log.warning(
        'signInForAccount: resolved to $_authState '
        '(resolvedPubkey=${pubkeyForLogs(resolvedPubkeyHex)}) for '
        '${pubkeyForLogs(pubkeyHex)} — surfacing AccountRestoreFailedException',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      throw AccountRestoreFailedException(
        pubkeyHex,
        _authState,
        resolvedPubkeyHex: resolvedPubkeyHex,
      );
    }
  }

  /// Save bunker connection info to secure storage
  Future<void> _saveBunkerInfo(NostrRemoteSignerInfo info) =>
      _signerStore.saveBunker(info);

  Future<NostrRemoteSignerInfo?> _loadBunkerInfo() => _signerStore.loadBunker();

  Future<void> _clearBunkerInfo() => _signerStore.clearBunker();

  /// Clears the global Keycast session, refresh token, and auth handle.
  ///
  /// Used when a stale or ambiguous OAuth session must be discarded
  /// (e.g., during initialization tiebreaker branches).
  Future<void> _clearKeycastSessionAndTokens() =>
      _signerStore.clearKeycastSessionAndTokens();

  Future<void> _runSignOutCleanupWithRetry(
    String operation,
    Future<void> Function() cleanup,
  ) async {
    try {
      await cleanup();
      return;
    } catch (e, stack) {
      Log.warning(
        'signOut: $operation failed; retrying once: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      _reportNonFatalAuthCleanupError(
        e,
        stack,
        'signOut $operation failed before retry',
      );
    }

    try {
      await cleanup();
    } catch (e, stack) {
      Log.error(
        'signOut: $operation failed after retry: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      _reportNonFatalAuthCleanupError(
        e,
        stack,
        'signOut $operation failed after retry',
      );
    }
  }

  Future<void> _clearOAuthSessionForSignOut() async {
    if (_oauthClient != null) {
      await _runSignOutCleanupWithRetry('OAuth logout', _oauthClient.logout);
    }

    await _runSignOutCleanupWithRetry(
      'Keycast OAuth token cleanup',
      _clearKeycastSessionAndTokens,
    );
  }

  /// Sets up the auth URL callback for bunker operations that require user
  /// approval.
  /// This must be called after creating a NostrRemoteSigner instance.
  void _setupBunkerAuthCallback() {
    if (_bunkerSigner == null) return;

    _bunkerSigner!.onAuthUrlReceived = (authUrl) async {
      Log.info(
        'Bunker requires authentication; opening URL',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      final uri = Uri.parse(authUrl);
      final launched = await _launchAuthUrl?.call(uri) ?? false;
      if (!launched) {
        Log.error(
          'Could not launch bunker authentication URL',
          name: 'AuthService',
          category: LogCategory.auth,
        );
      }
    };
  }

  /// Reconnect to a bunker using saved connection info
  Future<void> _reconnectBunker(
    NostrRemoteSignerInfo info, {
    bool boundedByStartupTimeout = false,
  }) async {
    Log.info(
      'Reconnecting to bunker...',
      name: 'AuthService',
      category: LogCategory.auth,
    );

    _setAuthState(AuthState.authenticating);

    try {
      // Create and connect the remote signer
      // Don't send a new connect request - the bunker already authorized us
      // during the initial connection. We just need to reconnect to the relay.
      _bunkerSigner = _remoteSignerFactory(RelayMode.baseMode, info);
      _setupBunkerAuthCallback();
      final connect = _bunkerSigner!.connect(sendConnectRequest: false);
      if (boundedByStartupTimeout) {
        await connect.timeout(_startupNetworkOperationTimeout);
      } else {
        await connect;
      }

      // Use saved public key if available, otherwise request it from bunker
      var userPubkey = info.userPubkey;
      if (userPubkey == null || userPubkey.isEmpty) {
        Log.info(
          'No saved userPubkey, requesting from bunker...',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        final pullPubkey = _bunkerSigner!.pullPubkey();
        userPubkey = boundedByStartupTimeout
            ? await pullPubkey.timeout(_startupNetworkOperationTimeout)
            : await pullPubkey;
      } else {
        Log.info(
          'Using saved userPubkey: ${pubkeyForLogs(userPubkey)}',
          name: 'AuthService',
          category: LogCategory.auth,
        );
      }
      if (userPubkey == null || userPubkey.isEmpty) {
        throw Exception('Failed to get public key from bunker');
      }

      _currentKeyContainer = SecureKeyContainer.fromPublicKey(userPubkey);
      _authSource = AuthenticationSource.bunker;
      _currentIdentity = _buildIdentity();

      // Create a minimal profile for the bunker user
      final npub = NostrKeyUtils.encodePubKey(userPubkey);
      _currentProfile = UserProfile(
        npub: npub,
        publicKeyHex: userPubkey,
        displayName: npub,
      );

      _setAuthState(AuthState.authenticated);
      _profileController.add(_currentProfile);

      // Register in known accounts
      await _knownAccounts.upsert(userPubkey, AuthenticationSource.bunker);

      // Run discovery in background - not needed for home feed
      unawaited(_performDiscovery());

      Log.info(
        'Bunker reconnection successful for user: ${pubkeyForLogs(userPubkey)}',
        name: 'AuthService',
        category: LogCategory.auth,
      );
    } catch (e) {
      Log.error(
        'Bunker reconnection failed: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      _bunkerSigner?.close();
      _bunkerSigner = null;
      _setAuthState(AuthState.unauthenticated);
    }
  }

  /// Connect using NIP-55 Android signer (Amber) for local signing
  ///
  /// This establishes a connection with an external Android signer app
  /// (e.g., Amber) that holds the user's private keys. All signing operations
  /// will be delegated to the signer app via Android intents.
  ///
  /// Only available on Android. Throws [UnsupportedError] on other platforms.
  Future<AuthResult> connectWithAmber() async {
    Log.info(
      'Connecting with Android signer (Amber)...',
      name: 'AuthService',
      category: LogCategory.auth,
    );

    _setAuthState(AuthState.authenticating);
    _lastError = null;

    try {
      // Check platform
      if (!_isAndroid()) {
        throw UnsupportedError(
          'NIP-55 Android signer only supported on Android',
        );
      }

      // Check if a signer app is installed
      final exists = await AndroidPlugin.existAndroidNostrSigner();
      if (exists != true) {
        throw Exception(
          'No Android signer app (e.g., Amber) installed. '
          'Please install a NIP-55 compatible signer app.',
        );
      }

      // Create the signer and get public key
      _amberSigner = AndroidNostrSigner();
      final pubkey = await _amberSigner!.getPublicKey();

      if (pubkey == null || pubkey.isEmpty) {
        throw Exception(
          'Failed to get public key from signer. '
          'The user may have denied the permission request.',
        );
      }

      // Log what's already in _keyStorage for debugging identity issues
      final existingContainer = await _keyStorage.getKeyContainer();
      Log.debug(
        'connectWithAmber: amberPubkey=${pubkeyForLogs(pubkey)}, '
        'existingStoredPubkey=${existingContainer?.publicKeyHex ?? "null"}',
        name: 'AuthService',
        category: LogCategory.auth,
      );

      // Save connection info for session restoration
      await _saveAmberInfo(pubkey, _amberSigner!.getPackage());

      // Set up user session
      await _setupUserSession(
        SecureKeyContainer.fromPublicKey(pubkey),
        AuthenticationSource.amber,
      );

      Log.info(
        'Amber connection successful for user: ${pubkeyForLogs(pubkey)}',
        name: 'AuthService',
        category: LogCategory.auth,
      );

      return const AuthResult(success: true);
    } catch (e) {
      Log.error(
        'Amber connection failed: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      _amberSigner = null;
      _lastError = 'Amber connection failed: $e';
      _setAuthState(AuthState.unauthenticated);

      return AuthResult.failure(_lastError!);
    }
  }

  /// Connect using a NIP-07 browser extension (Alby, nos2x, Nostore, etc.)
  ///
  /// When the injected bridge is missing or no browser extension is available,
  /// returns an [AuthResult.failure] without touching auth state. This covers
  /// non-web targets and web sessions without a NIP-07 extension.
  Future<AuthResult> connectWithNip07() async {
    Log.info(
      'Connecting with NIP-07 browser extension...',
      name: 'AuthService',
      category: LogCategory.auth,
    );

    final service = _nip07Extension;
    if (service == null || !service.isAvailable) {
      return AuthResult.failure(
        'No NIP-07 extension found. '
        'Please install Alby, nos2x, or another compatible extension.',
      );
    }

    _setAuthState(AuthState.authenticating);
    _lastError = null;

    try {
      final result = await service.connect();
      if (!result.success || result.publicKey == null) {
        throw Exception(result.errorMessage ?? 'NIP-07 authentication failed.');
      }

      final pubkey = result.publicKey!;
      _nip07Service = service;

      await _setupUserSession(
        SecureKeyContainer.fromPublicKey(pubkey),
        AuthenticationSource.nip07,
      );

      Log.info(
        'NIP-07 connection successful for user: ${pubkeyForLogs(pubkey)}',
        name: 'AuthService',
        category: LogCategory.auth,
      );

      return const AuthResult(success: true);
    } catch (e) {
      Log.error(
        'NIP-07 connection failed: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      _nip07Service = null;
      _lastError = 'NIP-07 connection failed: $e';
      _setAuthState(AuthState.unauthenticated);

      return AuthResult.failure(_lastError!);
    }
  }

  /// Helper to check if running on Android
  bool _isAndroid() {
    try {
      // This import is available at the top of the file
      return !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    } catch (_) {
      return false;
    }
  }

  /// Save Amber connection info to secure storage
  Future<void> _saveAmberInfo(String pubkey, String? package) =>
      _signerStore.saveAmber(pubkey, package);

  Future<({String pubkey, String? package})?> _loadAmberInfo() =>
      _signerStore.loadAmber();

  Future<void> _clearAmberInfo() => _signerStore.clearAmber();

  /// Silent NIP-07 reconnect at startup.
  ///
  /// Browser extensions remember per-origin grants, so we can hydrate the
  /// session by calling getPublicKey() again. If the extension is no
  /// longer present or refuses, fall back to unauthenticated.
  Future<void> _reconnectNip07() async {
    final service = _nip07Extension;
    if (service == null || !service.isAvailable) {
      Log.info(
        'NIP-07 extension no longer available — falling back to '
        'unauthenticated',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      _setAuthState(AuthState.unauthenticated);
      return;
    }
    try {
      final result = await service.connect();
      if (!result.success || result.publicKey == null) {
        Log.info(
          'NIP-07 silent reconnect failed — falling back to '
          'unauthenticated: ${result.errorMessage}',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        _setAuthState(AuthState.unauthenticated);
        return;
      }
      _nip07Service = service;
      await _setupUserSession(
        SecureKeyContainer.fromPublicKey(result.publicKey!),
        AuthenticationSource.nip07,
      );
    } catch (e, stackTrace) {
      Log.error(
        'NIP-07 reconnect failed: $e',
        name: 'AuthService',
        category: LogCategory.auth,
        stackTrace: stackTrace,
      );
      _nip07Service = null;
      _setAuthState(AuthState.unauthenticated);
    }
  }

  /// Reconnect to Amber using saved connection info
  Future<void> _reconnectAmber(String pubkey, String? package) async {
    Log.info(
      'Reconnecting to Amber...',
      name: 'AuthService',
      category: LogCategory.auth,
    );

    _setAuthState(AuthState.authenticating);

    try {
      // Check platform
      if (!_isAndroid()) {
        throw UnsupportedError(
          'NIP-55 Android signer only supported on Android',
        );
      }

      // Check if a signer app is still installed
      final exists = await AndroidPlugin.existAndroidNostrSigner();
      if (exists != true) {
        throw Exception('Android signer app no longer installed');
      }

      // Recreate signer with saved pubkey and package
      _amberSigner = AndroidNostrSigner(pubkey: pubkey, package: package);

      _currentKeyContainer = SecureKeyContainer.fromPublicKey(pubkey);
      _authSource = AuthenticationSource.amber;
      _currentIdentity = _buildIdentity();

      // Create a minimal profile for the Amber user
      final npub = NostrKeyUtils.encodePubKey(pubkey);
      _currentProfile = UserProfile(
        npub: npub,
        publicKeyHex: pubkey,
        displayName: npub,
      );

      _setAuthState(AuthState.authenticated);
      _profileController.add(_currentProfile);

      // Register in known accounts
      await _knownAccounts.upsert(pubkey, AuthenticationSource.amber);

      // Run discovery in background - not needed for home feed
      unawaited(_performDiscovery());

      Log.info(
        'Amber reconnection successful for user: ${pubkeyForLogs(pubkey)}',
        name: 'AuthService',
        category: LogCategory.auth,
      );
    } catch (e) {
      Log.error(
        'Amber reconnection failed: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      _amberSigner = null;
      _setAuthState(AuthState.unauthenticated);
    }
  }

  /// Import identity from nsec (bech32 private key)
  Future<AuthResult> importFromNsec(
    String nsec, {
    String? biometricPrompt,
  }) async {
    Log.debug(
      'Importing identity from nsec to secure storage',
      name: 'AuthService',
      category: LogCategory.auth,
    );

    _setAuthState(AuthState.authenticating);
    _lastError = null;

    try {
      // Validate nsec format
      if (!NostrKeyUtils.isValidNsec(nsec)) {
        throw Exception('Invalid nsec format');
      }

      // Import keys into secure storage
      final keyContainer = await _keyStorage.importFromNsec(
        nsec,
        biometricPrompt: biometricPrompt,
      );

      // Set up user session
      await _setupUserSession(keyContainer, AuthenticationSource.importedKeys);

      Log.info(
        'Identity imported to secure storage successfully',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      Log.debug(
        '📱 Public key: ${pubkeyForLogs(keyContainer.npub)}',
        name: 'AuthService',
        category: LogCategory.auth,
      );

      return AuthResult.success(keyContainer);
    } catch (e) {
      Log.error(
        'Failed to import identity: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      _lastError = 'Failed to import identity: $e';
      _setAuthState(AuthState.unauthenticated);

      return AuthResult.failure(_lastError!);
    }
  }

  /// Import identity from an ncryptsec1 encrypted private key (NIP-49).
  ///
  /// Decrypts [ncryptsec] with [password] using scrypt + XChaCha20-Poly1305,
  /// then imports the recovered private key via [importFromHex].
  ///
  /// Returns [AuthResult.failure] with message 'Incorrect password' if the
  /// password is wrong or the ciphertext is corrupted.
  Future<AuthResult> importFromNcryptsec(
    String ncryptsec,
    String password,
  ) async {
    Log.debug(
      'Importing identity from ncryptsec1 (NIP-49)',
      name: 'AuthService',
      category: LogCategory.auth,
    );

    try {
      final privateKeyHex = await Nip49.decode(ncryptsec, password);
      return importFromHex(privateKeyHex);
    } on Nip49Exception {
      _setAuthState(AuthState.unauthenticated);
      return AuthResult.incorrectPassword();
    }
  }

  /// Import identity from hex private key
  Future<AuthResult> importFromHex(
    String privateKeyHex, {
    String? biometricPrompt,
  }) async {
    Log.debug(
      'Importing identity from hex to secure storage',
      name: 'AuthService',
      category: LogCategory.auth,
    );

    _setAuthState(AuthState.authenticating);
    _lastError = null;

    try {
      // Validate hex format
      if (!NostrKeyUtils.isValidKey(privateKeyHex)) {
        throw Exception('Invalid private key format');
      }

      // Import keys into secure storage
      final keyContainer = await _keyStorage.importFromHex(
        privateKeyHex,
        biometricPrompt: biometricPrompt,
      );

      // Set up user session
      await _setupUserSession(keyContainer, AuthenticationSource.importedKeys);

      Log.info(
        'Identity imported from hex to secure storage successfully',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      Log.debug(
        '📱 Public key: ${pubkeyForLogs(keyContainer.npub)}',
        name: 'AuthService',
        category: LogCategory.auth,
      );

      return AuthResult.success(keyContainer);
    } catch (e) {
      Log.error(
        'Failed to import from hex: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      _lastError = 'Failed to import from hex: $e';
      _setAuthState(AuthState.unauthenticated);

      return AuthResult.failure(_lastError!);
    }
  }

  /// Connect using a NIP-46 bunker URL for remote signing
  ///
  /// The bunker URL format is:
  /// `bunker://<remote-signer-pubkey>?relay=<wss://relay>&secret=<optional>`
  ///
  /// This establishes a connection with a remote signer (bunker) that holds
  /// the user's private keys. All signing operations will be delegated to
  /// the bunker via Nostr relay messages.
  Future<AuthResult> connectWithBunker(String bunkerUrl) async {
    Log.info(
      'Connecting with bunker URL...',
      name: 'AuthService',
      category: LogCategory.auth,
    );

    _setAuthState(AuthState.authenticating);
    _lastError = null;

    try {
      // Parse the bunker URL
      final bunkerInfo = NostrRemoteSignerInfo.parseBunkerUrl(bunkerUrl);

      const authTimeout = Duration(seconds: 120);

      Log.debug(
        'Creating NostrRemoteSigner for '
        'bunker: ${pubkeyForLogs(bunkerInfo.remoteSignerPubkey)}',
        name: 'AuthService',
        category: LogCategory.auth,
      );

      _bunkerSigner = _remoteSignerFactory(RelayMode.baseMode, bunkerInfo);
      _setupBunkerAuthCallback();

      String? connectResult;
      try {
        Log.debug(
          'Sending connect request to bunker...',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        connectResult = await _bunkerSigner!.connect().timeout(
          authTimeout,
          onTimeout: () {
            throw TimeoutException(
              'Bunker connection timed out. If an approval page opened, '
              'please approve the connection and try again.',
            );
          },
        );
      } on TimeoutException {
        rethrow;
      }

      // Check if connect was acknowledged
      if (connectResult == null) {
        Log.warning(
          'Connect returned null - bunker may not have acknowledged',
          name: 'AuthService',
          category: LogCategory.auth,
        );
      } else {
        Log.info(
          'Connected to bunker successfully',
          name: 'AuthService',
          category: LogCategory.auth,
        );
      }

      // Get user's public key from the bunker
      final String? userPubkey;
      try {
        Log.debug(
          'Requesting public key from bunker...',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        // Verify bunker signer is properly initialized
        final signer = _bunkerSigner;
        if (signer == null) {
          throw StateError('Bunker signer is null before pullPubkey');
        }
        Log.debug(
          'Bunker signer info: remoteSignerPubkey=${pubkeyForLogs(signer.info.remoteSignerPubkey)}, '
          'relays=${signer.info.relays.length}, nsec=${signer.info.nsec != null}',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        userPubkey = await signer.pullPubkey().timeout(
          authTimeout,
          onTimeout: () {
            throw TimeoutException(
              'Timed out waiting for public key from bunker. '
              'The remote signer may be offline or unresponsive.',
            );
          },
        );
        Log.debug(
          'pullPubkey result: ${pubkeyForLogs(userPubkey)}',
          name: 'AuthService',
          category: LogCategory.auth,
        );
      } on TimeoutException {
        rethrow;
      } catch (e, stackTrace) {
        Log.error(
          'pullPubkey failed: $e\n$stackTrace',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        rethrow;
      }

      if (userPubkey == null || userPubkey.isEmpty) {
        throw Exception(
          'Failed to get public key from bunker. '
          'The remote signer did not respond with a valid key.',
        );
      }

      await _saveBunkerInfo(bunkerInfo);

      await _setupUserSession(
        SecureKeyContainer.fromPublicKey(userPubkey),
        AuthenticationSource.bunker,
      );

      Log.info(
        'Bunker connection successful for user: ${pubkeyForLogs(userPubkey)}',
        name: 'AuthService',
        category: LogCategory.auth,
      );

      return const AuthResult(success: true);
    } catch (e) {
      Log.error(
        'Bunker connection failed: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      // Clean up bunker signer connections before nulling
      _bunkerSigner?.close();
      _bunkerSigner = null;
      _lastError = 'Bunker connection failed: $e';
      _setAuthState(AuthState.unauthenticated);

      return AuthResult.failure(_lastError!);
    }
  }

  /// Initiate a client-side NIP-46 connection using nostrconnect:// URL.
  ///
  /// This generates a nostrconnect:// URL that the user can display as a QR
  /// code or copy/paste into their signer app (Amber, nsecBunker, etc.).
  ///
  /// Returns a [NostrConnectSession] that can be used to:
  /// - Get the URL via [session.connectUrl]
  /// - Wait for connection via [waitForNostrConnectResponse]
  /// - Cancel via [cancelNostrConnect]
  ///
  /// The session will listen on relays for the bunker's response.
  Future<NostrConnectSession> initiateNostrConnect({
    List<String>? customRelays,
  }) => _nostrConnect.initiate(customRelays: customRelays);

  /// Wait for the bunker to respond to a nostrconnect:// URL.
  ///
  /// Must be called after [initiateNostrConnect].
  ///
  /// Returns [AuthResult.success] if the bunker connects and we can
  /// authenticate, or [AuthResult.failure] on timeout/error.
  Future<AuthResult> waitForNostrConnectResponse({
    Duration timeout = const Duration(minutes: 2),
  }) => _nostrConnect.waitForResponse(timeout: timeout);

  /// Applies a successful nostrconnect connection: builds and connects the
  /// bunker signer, persists its info, and sets up the user session. Wired into
  /// [NostrConnectCoordinator] as its `onConnected` port — it stays on the
  /// facade because it mutates [_bunkerSigner] and drives the user session.
  Future<AuthResult> _applyNostrConnectSuccess(
    NostrConnectResult result,
  ) async {
    // Create and connect the NostrRemoteSigner
    // Note: Don't send connect request since we're already connected via
    // nostrconnect://
    _bunkerSigner = _remoteSignerFactory(RelayMode.baseMode, result.info);
    _setupBunkerAuthCallback();
    await _bunkerSigner!.connect(sendConnectRequest: false);

    // Get user's public key from the bunker
    final userPubkey = await _bunkerSigner!.pullPubkey();
    if (userPubkey == null || userPubkey.isEmpty) {
      throw Exception('Failed to get public key from bunker');
    }

    // Update info with user pubkey for persistence
    final updatedInfo = NostrRemoteSignerInfo(
      remoteSignerPubkey: result.remoteSignerPubkey,
      relays: result.info.relays,
      optionalSecret: result.info.optionalSecret,
      nsec: result.info.nsec,
      userPubkey: userPubkey,
      isClientInitiated: true,
      clientPubkey: result.info.clientPubkey,
    );

    // Save bunker info for reconnection
    await _saveBunkerInfo(updatedInfo);

    // Set up user session
    await _setupUserSession(
      SecureKeyContainer.fromPublicKey(userPubkey),
      AuthenticationSource.bunker,
    );

    Log.info(
      'NostrConnect authentication complete for user: ${pubkeyForLogs(userPubkey)}',
      name: 'AuthService',
      category: LogCategory.auth,
    );

    return const AuthResult(success: true);
  }

  /// Cancel an active nostrconnect:// session.
  ///
  /// Safe to call even if no session is active.
  void cancelNostrConnect() => _nostrConnect.cancel();

  /// Get the current nostrconnect:// URL if a session is active.
  ///
  /// Returns null if no session is active.
  String? get nostrConnectUrl => _nostrConnect.connectUrl;

  /// Get the current nostrconnect session state.
  NostrConnectState? get nostrConnectState => _nostrConnect.state;

  /// Stream of nostrconnect session state changes.
  Stream<NostrConnectState>? get nostrConnectStateStream =>
      _nostrConnect.stateStream;

  /// True while Android/iOS custom-scheme routing is handing control back
  /// from a NIP-46 signer app to Divine.
  bool get isNostrConnectCallbackHandoffActive =>
      _nostrConnect.isCallbackHandoffActive;

  /// Preserve the active session for the replacement NostrConnect screen.
  ///
  /// If no replacement screen claims the handoff quickly, cancel the session so
  /// backing out during the callback route handoff cannot orphan relay sockets.
  void preserveNostrConnectForCallbackHandoff() =>
      _nostrConnect.preserveForCallbackHandoff();

  /// Marks the callback handoff as claimed by a mounted NostrConnect screen.
  ///
  /// The short handoff flag is left to expire on its own so an old route that
  /// disposes after the replacement screen mounts still preserves the session.
  void claimNostrConnectCallbackHandoff() =>
      _nostrConnect.claimCallbackHandoff();

  /// Called when a divine:// signer callback deep link is received.
  ///
  /// Ensures the nostrconnect session relay connections are alive so we
  /// don't miss the bunker's response event after being brought back
  /// from background.
  void onSignerCallbackReceived({String? relayUrl}) =>
      _nostrConnect.onSignerCallbackReceived(relayUrl: relayUrl);

  /// Sign in using OAuth 2.0 flow
  Future<void> signInWithDivineOAuth(
    KeycastSession session, {
    AuthRpcCapability? rpcCapability,
    bool allowPubkeyOnlyIdentity = false,
  }) async {
    Log.debug(
      'Signing in with Divine OAuth session',
      name: 'AuthService',
      category: LogCategory.auth,
    );

    _setAuthState(AuthState.authenticating);
    _lastError = null;
    _hasExpiredOAuthSession = false;
    _authRpcCapabilityInitialized = false;

    try {
      // Unbound session: pubkey unknown here, treat as same — a wrong close
      // strands the live client; a wrong retain leaks one HTTP client (#5909).
      final closePrevious =
          (session.userPubkey?.isNotEmpty ?? false) &&
          session.userPubkey != currentPublicKeyHex;
      if (session.hasRpcAccess) {
        _setKeycastSigner(
          _newKeycastSigner(session),
          closePrevious: closePrevious,
        );
      } else {
        _setKeycastSigner(null, closePrevious: closePrevious);
      }

      // Prefer the pubkey stored in the session over an RPC call:
      // userPubkey is ground truth once bound at first sign-in, so
      // subsequent reads cannot mismatch the token.
      String? publicKeyHex = session.userPubkey;
      if (publicKeyHex == null || publicKeyHex.isEmpty) {
        publicKeyHex = await _keycastSigner?.getPublicKey();
      }
      if (publicKeyHex == null) {
        throw Exception('Could not retrieve public key from server');
      }

      // If userPubkey was never populated (legacy or fresh from
      // fromTokenResponse), bind the resolved pubkey now and re-save so
      // archive/restore can validate ownership.
      if (session.userPubkey == null || session.userPubkey!.isEmpty) {
        final boundSession = session.copyWith(userPubkey: publicKeyHex);
        await boundSession.save(_flutterSecureStorage);
        Log.debug(
          'signInWithDivineOAuth: bound userPubkey=$publicKeyHex to '
          'session and re-saved',
          name: 'AuthService',
          category: LogCategory.auth,
        );
      }

      _currentProfile = UserProfile(
        npub: NostrKeyUtils.encodePubKey(publicKeyHex),
        publicKeyHex: publicKeyHex,
        displayName: 'Divine User',
      );

      // Do not pre-write current_user_pubkey_hex here: _setupUserSession
      // calls shouldClearDataForUser which compares the stored pubkey
      // against the incoming one. Writing the new value first would
      // mask identity changes. _setupUserSession writes it after the
      // check.
      await clearDismissedDivineLoginBannerForCurrentUser(publicKeyHex);

      Log.info(
        '✅ Divine oauth listener setting auth state to authenticated.',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      _profileController.add(_currentProfile);

      // Load the locally-stored nsec matching publicKeyHex so
      // _buildIdentity can attach a LocalKeySigner to the KeycastNostrIdentity.
      // Without this, every signEvent / nip44Decrypt round-trips through
      // Keycast RPC (200-500ms) even though the nsec is on device. Mirrors
      // the local-first restore path used during cold start.
      final npub = NostrKeyUtils.encodePubKey(publicKeyHex);
      SecureKeyContainer? localKey;
      try {
        localKey = await _keyStorage.getIdentityKeyContainer(npub);
        if (localKey == null && await _keyStorage.hasKeys()) {
          final primary = await _keyStorage.getKeyContainer();
          if (primary != null &&
              primary.hasPrivateKey &&
              primary.publicKeyHex == publicKeyHex) {
            localKey = primary;
          }
        }
      } catch (e) {
        Log.warning(
          'signInWithDivineOAuth: local key lookup failed: $e',
          name: 'AuthService',
          category: LogCategory.auth,
        );
      }

      final SecureKeyContainer keyContainer;
      if (localKey != null && localKey.hasPrivateKey) {
        keyContainer = localKey;
        Log.info(
          'signInWithDivineOAuth: using local nsec for fast signing '
          '(pubkey=$publicKeyHex)',
          name: 'AuthService',
          category: LogCategory.auth,
        );
      } else {
        keyContainer = SecureKeyContainer.fromPublicKey(publicKeyHex);
        if (_keycastSigner != null) {
          Log.info(
            'signInWithDivineOAuth: no matching local nsec — '
            'signing via RPC (pubkey=$publicKeyHex)',
            name: 'AuthService',
            category: LogCategory.auth,
          );
        } else {
          Log.info(
            'signInWithDivineOAuth: no matching local nsec and RPC is not '
            'ready — restored pubkey-only identity (pubkey=$publicKeyHex)',
            name: 'AuthService',
            category: LogCategory.auth,
          );
        }
      }
      await _setupUserSession(
        keyContainer,
        AuthenticationSource.divineOAuth,
        allowPubkeyOnlyIdentity: allowPubkeyOnlyIdentity,
      );
      _setRpcCapability(
        rpcCapability ??
            (session.hasRpcAccess
                ? AuthRpcCapability.rpcReady
                : AuthRpcCapability.upgrading),
      );

      Log.info(
        '✅ Divine oauth session successfully integrated for $publicKeyHex',
        name: 'AuthService',
        category: LogCategory.auth,
      );
    } catch (e) {
      Log.error(
        'Failed to integrate oauth session: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      _lastError = 'oauth integration failed: $e';
      _setAuthState(AuthState.unauthenticated);
    }
  }

  /// Delete the user's Keycast account if one exists.
  ///
  /// This permanently deletes the account from the Keycast server.
  /// Should be called AFTER sending NIP-62 deletion request (which requires
  /// the signer to still be functional) but BEFORE [signOut].
  ///
  /// Returns a tuple of (success, errorMessage).
  /// Returns (true, null) if:
  /// - Account was successfully deleted
  /// - No Keycast session exists (nothing to delete)
  /// - OAuth client is not configured (local-only auth)
  ///
  /// Returns (false, errorMessage) if deletion failed.
  /// Whether account deletion can start without destroying content it may then
  /// be unable to finish deleting.
  ///
  /// The deletion flow publishes an irreversible NIP-62 request to vanish and a
  /// kind-5 sweep *before* it can attempt the server-side account deletion, and
  /// the server-side step is only authorized while the access token still
  /// carries the first-party fact it was minted with. Refreshing the token drops
  /// that fact, so a returning user is refused — after their content has already
  /// been broadcast for deletion. See #6335 / #4881.
  ///
  /// Refresh-minted sessions are unexpired and can still sign Nostr RPCs, but
  /// cannot authorize the server-side Keycast account deletion. Legacy sessions
  /// with no grant marker are ambiguous, so this fails closed and asks the user
  /// to sign in again before any irreversible publish.
  ///
  /// Only divineOAuth accounts are gated. Anonymous, imported-nsec, amber and
  /// bunker users have no Keycast account to delete, so gating them would block
  /// them from deleting their own content for no reason.
  Future<AccountDeletionReadiness> checkAccountDeletionReadiness() async {
    if (!isRegistered) {
      return AccountDeletionReadiness.ready;
    }

    final client = _oauthClient;
    if (client == null) {
      return AccountDeletionReadiness.ready;
    }

    try {
      final session = await client.getSession();
      final now = DateTime.now();
      final expiresAt = session?.expiresAt;
      final blockedReason = switch (session) {
        null => 'no current session',
        _ when !session.hasRpcAccess => 'no active RPC access',
        _ when session.grantType != KeycastSession.authorizationCodeGrant =>
          'session grant cannot authorize deletion',
        _ when expiresAt == null => 'session has no expiry',
        _
            when expiresAt.difference(now) <
                _accountDeletionSessionExpiryMargin =>
          'session expires too soon',
        _ => null,
      };
      if (blockedReason != null) {
        Log.warning(
          'Account deletion blocked before publishing: $blockedReason, '
          're-authentication required',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        return AccountDeletionReadiness.requiresReauthentication;
      }
      return AccountDeletionReadiness.ready;
    } catch (e) {
      // Fail closed: a readiness check we cannot complete must not green-light
      // publishing irreversible events.
      Log.error(
        'Account deletion readiness check failed: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      return AccountDeletionReadiness.requiresReauthentication;
    }
  }

  /// The bearer token for the account that is signed in right now, for the
  /// `/api/user/*` routes Keycast authorizes with it.
  ///
  /// Every such call must take its token from here rather than from
  /// `getSessionOrRefresh()`, which guarantees neither of the two things this
  /// does:
  ///
  /// - Refresh runs through [OAuthSessionCoordinator], so concurrent callers
  ///   share one exchange of a single-use refresh token, and the refreshed
  ///   session is persisted **bound** to its owner. An unbound session is
  ///   skipped by `SignerSecureStore.archive` and deleted as corrupt by the
  ///   next `restoreActiveKeys`, which costs the account its restore path.
  /// - The session is proven to belong to the active account before its token
  ///   is used. Storage keeps one global session slot, so a session left
  ///   behind by another account would otherwise authorize a call made on this
  ///   account's behalf.
  ///
  /// Returns null when there is no OAuth client, no signed-in account, no
  /// session after a refresh, or the session is not bound to the signed-in
  /// account. Each caller maps that to its own re-authentication outcome.
  ///
  /// Throws [OAuthNetworkException] when the refresh cannot reach Keycast.
  Future<String?> activeAccountKeycastToken() async {
    final client = _oauthClient;
    if (client == null) return null;

    final ownerPubkey = currentPublicKeyHex;
    if (ownerPubkey == null) return null;

    // getSession() answers null for an expired session, so this refreshes on
    // exactly the same condition getSessionOrRefresh() would.
    var session = await client.getSession();
    session ??= await _oauthCoordinator.refreshSession(
      expectedOwnerPubkey: ownerPubkey,
    );
    if (session == null) return null;

    // Strict equality also rejects a session that never carried an owner:
    // it cannot be attributed to this account, and a token whose account we
    // cannot name must not be spent on that account's behalf.
    if (session.userPubkey != ownerPubkey) {
      Log.warning(
        'Refusing a Keycast session that is not bound to the signed-in '
        'account: session owner ${pubkeyForLogs(session.userPubkey, whenNull: "unbound")}, '
        'signed-in account ${pubkeyForLogs(ownerPubkey)}',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      return null;
    }

    return session.accessToken;
  }

  /// Fetch the signing key Keycast holds for the signed-in Divine Login
  /// account, so it can be handed to the user who owns it.
  ///
  /// Only for an account whose key is not on the device: [canExportLocalNsec]
  /// accounts already have [exportNsec] and must keep using it, because that
  /// path never leaves the device. This one costs a round trip and the
  /// account [password], which Keycast verifies itself.
  ///
  /// Returns [ExportKeyFailure.needsSignIn] when no OAuth client is configured
  /// or [activeAccountKeycastToken] has no token for the signed-in account —
  /// all of those mean the credential this needs is unavailable, and only
  /// signing in again produces one.
  ///
  /// The returned key is raw key material. It is deliberately not stored,
  /// cached, or logged here; the caller owns it from the moment it returns.
  Future<ExportKeyResult> exportKeycastNsec(String password) async {
    final client = _oauthClient;
    if (client == null) {
      Log.debug(
        'No OAuth client configured - cannot export a Keycast-held key',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      return ExportKeyResult.failure(ExportKeyFailure.needsSignIn);
    }

    try {
      // Refreshes when the access token expired while the screen was open, so
      // a refreshable session does not surface to the user as a sign-in
      // prompt, and refuses a session this account cannot claim.
      final accessToken = await activeAccountKeycastToken();
      if (accessToken == null) {
        Log.warning(
          'Cannot export Keycast key: no session bound to the signed-in '
          'account',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        return ExportKeyResult.failure(ExportKeyFailure.needsSignIn);
      }

      final result = await client.exportKey(accessToken, password);
      if (!result.success) {
        // The failure enum is safe to log; `error` may quote server prose and
        // `key` is never logged at any level.
        Log.warning(
          'Keycast key export refused: ${result.failure}',
          name: 'AuthService',
          category: LogCategory.auth,
        );
      }
      return result;
    } catch (e) {
      Log.error(
        'Keycast key export failed: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      return ExportKeyResult.failure(ExportKeyFailure.network);
    }
  }

  /// Signs out the current user.
  ///
  /// [abortOnKeyDeletionFailure] keeps the session active if key deletion
  /// fails. Otherwise destructive cleanup finishes before throwing
  /// [SecureKeyStorageException] or [UserDataCleanupException].
  Future<void> signOut({
    bool deleteKeys = false,
    bool abortOnKeyDeletionFailure = false,
    bool deleteLocalUserData = false,
  }) async {
    final pubkeyAtSignOutStart = _currentKeyContainer?.publicKeyHex;
    final npubAtSignOutStart = _currentKeyContainer?.npub;
    Log.info(
      'signOut: starting — '
      'authSource=${_authSource.name}, '
      'deleteKeys=$deleteKeys, '
      'abortOnKeyDeletionFailure=$abortOnKeyDeletionFailure, '
      'deleteLocalUserData=$deleteLocalUserData, '
      'currentPubkey=${_currentKeyContainer?.publicKeyHex ?? "null"}',
      name: 'AuthService',
      category: LogCategory.auth,
    );

    if (deleteKeys && abortOnKeyDeletionFailure) {
      await _deleteStoredLoginForAccount(npubAtSignOutStart);
    }

    Object? keyDeletionError;
    Object? userDataCleanupError;

    await _runBeforeSessionTeardownCallbacks();

    try {
      // Clear TOS acceptance on any logout - user must re-accept when logging
      // back in
      final prefs = await SharedPreferences.getInstance();
      final currentPubkey = _currentKeyContainer?.publicKeyHex;

      final leavingNpub = _currentKeyContainer?.npub;
      if (!deleteKeys && leavingNpub != null) {
        await prefs.setString(_kSessionRecoveryAnchorKey, leavingNpub);
        Log.debug(
          'signOut: recorded session recovery anchor=${pubkeyForLogs(leavingNpub)}',
          name: 'AuthService',
          category: LogCategory.auth,
        );
      } else {
        // Destructive sign-out: clear any stale anchor so the remaining
        // account's automatic restore is not blocked by the guard in
        // _restoreDivineRpcOrFallbackUnauthenticated.
        await prefs.remove(_kSessionRecoveryAnchorKey);
        Log.debug(
          'signOut: cleared session recovery anchor '
          '(deleteKeys=$deleteKeys)',
          name: 'AuthService',
          category: LogCategory.auth,
        );
      }

      await prefs.remove('age_verified_16_plus');
      await prefs.remove('terms_accepted_at');

      if (deleteKeys && !deleteLocalUserData && currentPubkey != null) {
        await _userDataCleanupService.markOwnerScopedLegacyDataForUser(
          currentPubkey,
        );
      }
      try {
        await _userDataCleanupService.clearUserSpecificData(
          reason: 'explicit_logout',
          userPubkey: currentPubkey,
          deleteUserData: deleteLocalUserData,
        );
      } catch (e) {
        userDataCleanupError = e;
        Log.error(
          'User data cleanup failed during signOut: $e',
          name: 'AuthService',
          category: LogCategory.auth,
        );
      }

      await prefs.remove(SharedPreferencesRelayStorage.defaultKey);
      await prefs.remove(SharedPreferencesRelayStorage.defaultRemovedRelaysKey);

      await _relayDiscoveryService.clearCache(_currentKeyContainer?.npub ?? '');

      await prefs.remove('current_user_pubkey_hex');

      if (currentPubkey != null) {
        try {
          await CacheSync.invalidatePrefix(currentPubkey);
        } catch (e, stack) {
          if (deleteLocalUserData) userDataCleanupError ??= e;
          Log.error(
            'CacheSync.invalidatePrefix failed during signOut: $e',
            name: 'AuthService',
            category: LogCategory.auth,
          );
          _reportStorageError(e, stack, 'signOut cache invalidation');
        }
      }

      if (deleteKeys) {
        if (currentPubkey != null) {
          if (deleteLocalUserData) {
            try {
              await _knownAccounts.removeStrict(currentPubkey);
            } catch (e) {
              userDataCleanupError ??= e;
            }
          } else {
            await _knownAccounts.remove(currentPubkey);
          }
          try {
            if (deleteLocalUserData) {
              await _signerStore.clearAccount(currentPubkey);
            } else {
              await _clearArchivedSignerInfo(currentPubkey);
            }
          } catch (e) {
            keyDeletionError ??= e;
          }
        }

        Log.debug(
          '📱️ Deleting local login material',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        // Isolate key deletion so that a failure does not short-circuit
        // the remaining cleanup (session, signers, auth state). The error
        // is rethrown after cleanup completes so callers can warn the user.
        // Skip if already handled by the pre-flight check above.
        if (!abortOnKeyDeletionFailure) {
          try {
            await _deleteStoredLoginForAccount(leavingNpub);
          } catch (e) {
            keyDeletionError = e;
            Log.error(
              'Local login deletion failed during signOut: $e',
              name: 'AuthService',
              category: LogCategory.auth,
            );
          }
        }
      } else {
        if (currentPubkey != null) {
          await _archiveSignerInfo(currentPubkey);
        }
        // When the current session used an external signer (Amber/Bunker),
        // local key storage may contain stale keys from a previous identity
        // (e.g., auto-created keys before the user connected Amber).
        // Delete these stale keys to prevent _checkExistingAuth() from
        // auto-signing in with the wrong identity.
        if (_authSource == AuthenticationSource.amber ||
            _authSource == AuthenticationSource.bunker) {
          final storedContainer = await _keyStorage.getKeyContainer();
          Log.debug(
            'signOut: external signer check — '
            'storedKeyPubkey=${storedContainer?.publicKeyHex ?? "null"}, '
            'currentPubkey=${_currentKeyContainer?.publicKeyHex ?? "null"}, '
            'match=${storedContainer?.publicKeyHex == _currentKeyContainer?.publicKeyHex}',
            name: 'AuthService',
            category: LogCategory.auth,
          );
          if (storedContainer != null &&
              storedContainer.publicKeyHex !=
                  _currentKeyContainer?.publicKeyHex) {
            Log.debug(
              'signOut: deleting stale local keys from previous identity',
              name: 'AuthService',
              category: LogCategory.auth,
            );
            await _keyStorage.deleteKeys();
          } else {
            Log.debug(
              'signOut: no stale keys detected, clearing cache only',
              name: 'AuthService',
              category: LogCategory.auth,
            );
            _keyStorage.clearCache();
          }
        } else {
          Log.debug(
            'signOut: authSource=${_authSource.name}, clearing cache only',
            name: 'AuthService',
            category: LogCategory.auth,
          );
          _keyStorage.clearCache();
        }
      }

      _currentIdentity = null;
      _currentKeyContainer?.dispose();
      _currentKeyContainer = null;
      _currentProfile = null;
      _lastError = null;

      _onUserRelaysDiscovered = null;
      _onBootstrapRelayListRequested = null;
      _userRelays = [];

      if (_bunkerSigner != null) {
        _bunkerSigner!.close();
        _bunkerSigner = null;
        // Only clear persisted connection info on destructive sign-out.
        // Non-destructive sign-out (switch account) preserves it so
        // "Log back in" can reconnect.
        if (deleteKeys) {
          await _clearBunkerInfo();
        }
      }

      if (_amberSigner != null) {
        _amberSigner!.close();
        _amberSigner = null;
        // Only clear persisted connection info on destructive sign-out.
        // Non-destructive sign-out (switch account) preserves it so
        // "Log back in" can reconnect.
        if (deleteKeys) {
          await _clearAmberInfo();
        }
      }

      _setKeycastSigner(null);
      _setRpcCapability(AuthRpcCapability.unavailable);

      // Detach any in-flight token refresh so post-signout logins start a
      // fresh attempt instead of joining one issued for the outgoing session.
      // Deliberately leaves _hasExpiredOAuthSession untouched.
      _oauthCoordinator.detach();

      await _clearOAuthSessionForSignOut();

      // Reset recovery prefs AFTER all signer cleanup so removed accounts
      // cannot silently recover. Any remaining restorable accounts stay in the
      // known-account picker instead of being auto-restored.
      if (deleteKeys &&
          (!deleteLocalUserData || userDataCleanupError == null)) {
        try {
          await _resetRecoveryAfterLocalAccountRemoval(
            prefs,
            strict: deleteLocalUserData,
          );
        } catch (e) {
          userDataCleanupError ??= e;
        }
      }

      _setAuthState(AuthState.unauthenticated);

      try {
        final postSignOutHasKeys = await _keyStorage.hasKeys();
        Log.info(
          'signOut complete — '
          'keyStorageHasKeys=$postSignOutHasKeys, '
          'authSource=${_authSource.name}',
          name: 'AuthService',
          category: LogCategory.auth,
        );
      } catch (_) {
        Log.info(
          'signOut complete',
          name: 'AuthService',
          category: LogCategory.auth,
        );
      }
    } catch (e) {
      Log.error(
        'Error during sign out: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      _lastError = 'Sign out failed: $e';

      // In the Remove Keys flow, key deletion has already succeeded before
      // cleanup starts. Do not leave the app in an authenticated in-memory
      // state with no keys on disk if a secondary cleanup step fails.
      if (deleteKeys && abortOnKeyDeletionFailure) {
        await _completeDestructiveSignOutAfterDeletedKeys(
          removedPubkey: pubkeyAtSignOutStart,
          failure: e,
        );
      }
    }

    // After all cleanup, propagate key deletion failure so callers can
    // warn the user that keys may still be on the device.
    if (keyDeletionError != null) {
      throw SecureKeyStorageException(
        'Signed out but key deletion failed: $keyDeletionError',
      );
    }
    if (userDataCleanupError != null && deleteLocalUserData) {
      throw UserDataCleanupException(
        'Signed out but local user data cleanup failed',
        userDataCleanupError,
      );
    }
  }

  Future<void> _deleteStoredLoginForAccount(String? npub) async {
    if (npub == null) {
      await _keyStorage.deleteKeys();
      return;
    }

    await _keyStorage.deleteIdentityKeyContainer(npub);

    final primaryContainer = await _keyStorage.getKeyContainer();
    if (primaryContainer == null || primaryContainer.npub == npub) {
      await _keyStorage.deleteKeys();
      return;
    }

    Log.info(
      'Preserving PRIMARY key while removing account-local login material: '
      'removed=${pubkeyForLogs(npub)} primary=${pubkeyForLogs(primaryContainer.npub)}',
      name: 'AuthService',
      category: LogCategory.auth,
    );
  }

  Future<void> _runBeforeSessionTeardownCallbacks() async {
    if (_beforeSessionTeardownCallbacks.isEmpty) return;

    final callbacks = List<BeforeSessionTeardownCallback>.of(
      _beforeSessionTeardownCallbacks,
    );
    final deadline = DateTime.now().add(_kBeforeSessionTeardownTimeout);

    for (final callback in callbacks) {
      final remaining = deadline.difference(DateTime.now());
      if (remaining <= Duration.zero) {
        Log.warning(
          'Before-session teardown callbacks timed out',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        return;
      }

      try {
        await callback().timeout(remaining);
      } on TimeoutException catch (e) {
        Log.warning(
          'Before-session teardown callback timed out: $e',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        continue;
      } catch (e) {
        Log.warning(
          'Before-session teardown callback failed: $e',
          name: 'AuthService',
          category: LogCategory.auth,
        );
      }
    }
  }

  Future<void> _completeDestructiveSignOutAfterDeletedKeys({
    required String? removedPubkey,
    required Object failure,
  }) async {
    Log.warning(
      'signOut: completing destructive sign-out after cleanup failure: $failure',
      name: 'AuthService',
      category: LogCategory.auth,
    );

    final prefs = await SharedPreferences.getInstance();

    if (removedPubkey != null) {
      try {
        await _knownAccounts.remove(removedPubkey);
        await _clearArchivedSignerInfo(removedPubkey);
      } catch (e) {
        Log.warning(
          'signOut: failed to remove deleted account from known accounts: $e',
          name: 'AuthService',
          category: LogCategory.auth,
        );
      }
    }

    _currentIdentity = null;
    _currentKeyContainer?.dispose();
    _currentKeyContainer = null;
    _currentProfile = null;
    _lastError = null;
    _onUserRelaysDiscovered = null;
    _onBootstrapRelayListRequested = null;
    _userRelays = [];
    _bunkerSigner?.close();
    _bunkerSigner = null;
    await _clearBunkerInfo();
    _amberSigner?.close();
    _amberSigner = null;
    await _clearAmberInfo();
    _setKeycastSigner(null);
    _setRpcCapability(AuthRpcCapability.unavailable);
    _keyStorage.clearCache();

    await _clearOAuthSessionForSignOut();

    await prefs.remove(_kSessionRecoveryAnchorKey);
    await prefs.remove('age_verified_16_plus');
    await prefs.remove('terms_accepted_at');
    await prefs.remove(SharedPreferencesRelayStorage.defaultKey);
    await prefs.remove(SharedPreferencesRelayStorage.defaultRemovedRelaysKey);
    await prefs.remove('current_user_pubkey_hex');
    await _resetRecoveryAfterLocalAccountRemoval(prefs);

    _setAuthState(AuthState.unauthenticated);
  }

  /// After removing the active account from this device, keep only known
  /// accounts that still have restorable local login material and reset
  /// automatic recovery. This returns the app to the welcome screen:
  /// fresh-login when no accounts remain, or the returning-user picker when
  /// other local accounts are still available.
  Future<void> _resetRecoveryAfterLocalAccountRemoval(
    SharedPreferences prefs, {
    bool strict = false,
  }) async {
    try {
      final restorableCount = await _knownAccounts.resetRecoveryPreferences(
        lastUsedNpubKey: _kLastUsedNpubKey,
      );
      _authSource = AuthenticationSource.none;

      if (restorableCount == 0) {
        Log.info(
          'signOut: no restorable local accounts — reset to fresh welcome',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        return;
      }

      Log.info(
        'signOut: kept $restorableCount restorable local '
        'account(s) for the welcome picker',
        name: 'AuthService',
        category: LogCategory.auth,
      );
    } catch (e) {
      if (strict) rethrow;
      // Best-effort: if this fails, the fallback scan in
      // _restoreLastUsedAccountOrFallback will still find the account.
      Log.warning(
        'signOut: failed to reset local-account recovery prefs: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      _authSource = AuthenticationSource.none;
      await prefs.setString(
        kAuthenticationSourceKey,
        AuthenticationSource.none.code,
      );
      await prefs.remove(_kLastUsedNpubKey);
    }
  }

  /// Export nsec for backup purposes
  Future<String?> exportNsec({String? biometricPrompt}) async {
    if (!isAuthenticated) return null;

    if (authenticationSource != AuthenticationSource.automatic &&
        authenticationSource != AuthenticationSource.importedKeys &&
        authenticationSource != AuthenticationSource.divineOAuth) {
      Log.warning(
        'Exporting nsec for $authenticationSource not supported',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      return null;
    }

    try {
      Log.warning(
        'Exporting nsec - ensure secure handling',
        name: 'AuthService',
        category: LogCategory.auth,
      );

      // Use the in-memory key container when available to avoid re-reading
      // from platform storage. iOS keychain can fail transiently, causing
      // "Unable to access your keys" errors even though the key is in RAM.
      // Falls back to storage read if the container isn't loaded yet.
      final container = _currentKeyContainer;
      if (container != null && container.hasPrivateKey) {
        return container.withNsec((nsec) => nsec);
      }

      if (authenticationSource == AuthenticationSource.divineOAuth) {
        Log.warning(
          'Exporting nsec for divineOAuth requires a local private key',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        return null;
      }

      return await _keyStorage.exportNsec(biometricPrompt: biometricPrompt);
    } catch (e) {
      Log.error(
        'Failed to export nsec: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      return null;
    }
  }

  /// Create and sign a Nostr event
  /// Handles both local SecureKeyStorage and remote KeycastRpc signing
  ///
  /// Delegates to [SignerFactory.createAndSignEvent]; this facade keeps the
  /// authenticated/identity guard and the public signature ([biometricPrompt]
  /// is retained for the 29 existing call sites but unused by the core).
  @override
  Future<Event?> createAndSignEvent({
    required int kind,
    required String content,
    List<List<String>>? tags,
    String? biometricPrompt,
    int? createdAt,
  }) async {
    final identity = _currentIdentity;
    if (!isAuthenticated || identity == null) {
      Log.error(
        'Cannot sign event - user not authenticated',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      return null;
    }

    return _signerFactory.createAndSignEvent(
      identity: identity,
      authSource: _authSource,
      kind: kind,
      content: content,
      tags: tags,
      createdAt: createdAt,
    );
  }

  /// Restores the last-used account's per-identity key, falling back to
  /// [_checkExistingAuth] when the pref is absent or the key is missing.
  Future<void> _restoreLastUsedAccountOrFallback(
    AuthenticationSource source,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastNpub = prefs.getString(_kLastUsedNpubKey);

      if (lastNpub != null && lastNpub.isNotEmpty) {
        Log.info(
          '_restoreLastUsedAccountOrFallback: '
          'found last-used npub, loading identity key...',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        final cachedPrimaryIdentity = await _restoreFromLoadedPrimaryIdentity(
          lastNpub,
        );
        if (cachedPrimaryIdentity != null) {
          Log.info(
            '_restoreLastUsedAccountOrFallback: '
            'reused already-loaded primary identity — '
            'pubkey=${cachedPrimaryIdentity.publicKeyHex}',
            name: 'AuthService',
            category: LogCategory.auth,
          );
          await _setupUserSession(cachedPrimaryIdentity, source);
          return;
        }
        final container = await _keyStorage.getIdentityKeyContainer(lastNpub);
        if (container != null) {
          Log.info(
            '_restoreLastUsedAccountOrFallback: '
            'identity key found — pubkey=${container.publicKeyHex}',
            name: 'AuthService',
            category: LogCategory.auth,
          );
          await _setupUserSession(container, source);
          return;
        }
        Log.warning(
          '_restoreLastUsedAccountOrFallback: '
          'identity key absent for last-used npub — falling back',
          name: 'AuthService',
          category: LogCategory.auth,
        );
      } else {
        Log.info(
          '_restoreLastUsedAccountOrFallback: '
          'no last-used npub stored — falling back to _checkExistingAuth',
          name: 'AuthService',
          category: LogCategory.auth,
        );
      }
    } catch (e, stack) {
      Log.warning(
        '_restoreLastUsedAccountOrFallback: error reading last-used npub: $e '
        '— falling back to _checkExistingAuth',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      _reportStorageError(e, stack, '_restoreLastUsedAccountOrFallback');
    }

    // Before falling through to _checkExistingAuth (which only checks
    // PRIMARY storage), scan known accounts for per-identity keys.
    // This covers the case where signOut(deleteKeys:true) wiped PRIMARY
    // but another account's keys still exist in per-identity storage.
    if (await _tryRestoreFromKnownAccounts(source)) return;

    // Fall back to the original behaviour (load primary key, or create new).
    await _checkExistingAuth();
  }

  /// Scans known accounts and attempts to restore the first one that has
  /// restorable credentials.  For local-key accounts this checks per-identity
  /// key containers; for OAuth/bunker/amber it delegates to [signInForAccount]
  /// which restores archived signer info and triggers the appropriate flow.
  /// Returns true if an account was restored, false otherwise.
  Future<bool> _tryRestoreFromKnownAccounts(AuthenticationSource source) async {
    try {
      final accounts = await getKnownAccounts();
      if (accounts.isEmpty) return false;

      // Try most recently used first.
      accounts.sort((a, b) => b.lastUsedAt.compareTo(a.lastUsedAt));
      for (final account in accounts) {
        // OAuth, bunker, and amber accounts don't store per-identity local
        // keys — they rely on archived signer info.  Use signInForAccount
        // which handles _restoreSignerInfo + the source-specific sign-in.
        if (account.authSource == AuthenticationSource.divineOAuth ||
            account.authSource == AuthenticationSource.bunker ||
            account.authSource == AuthenticationSource.amber) {
          try {
            Log.info(
              '_tryRestoreFromKnownAccounts: '
              'trying signInForAccount for ${pubkeyForLogs(account.pubkeyHex)} '
              '(source=${account.authSource.name})',
              name: 'AuthService',
              category: LogCategory.auth,
            );
            await signInForAccount(account.pubkeyHex, account.authSource);
            return true;
          } catch (e) {
            Log.warning(
              '_tryRestoreFromKnownAccounts: '
              'signInForAccount failed for ${pubkeyForLogs(account.pubkeyHex)}: $e',
              name: 'AuthService',
              category: LogCategory.auth,
            );
            continue;
          }
        }

        // Local-key accounts: look for per-identity key containers.
        final npub = NostrKeyUtils.encodePubKey(account.pubkeyHex);
        final container = await _keyStorage.getIdentityKeyContainer(npub);
        if (container != null) {
          Log.info(
            '_tryRestoreFromKnownAccounts: '
            'found keys for ${pubkeyForLogs(account.pubkeyHex)} '
            '(source=${account.authSource.name})',
            name: 'AuthService',
            category: LogCategory.auth,
          );
          await _keyStorage.switchToIdentity(npub);
          await _setupUserSession(container, account.authSource);
          return true;
        }
      }
      Log.info(
        '_tryRestoreFromKnownAccounts: '
        'no restorable account found among known accounts',
        name: 'AuthService',
        category: LogCategory.auth,
      );
    } catch (e) {
      Log.warning(
        '_tryRestoreFromKnownAccounts: scan failed: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
    }
    return false;
  }

  /// Fast path: reuse the PRIMARY key when it matches the last-used npub,
  /// avoiding a redundant per-identity storage read.
  ///
  /// Reads the primary container from [SecureKeyStorage] — a cache hit when it
  /// was already loaded during init, otherwise a single platform read. The
  /// npub guard keeps the reuse correct.
  Future<SecureKeyContainer?> _restoreFromLoadedPrimaryIdentity(
    String lastNpub,
  ) async {
    final SecureKeyContainer? primary;
    try {
      primary = await _keyStorage.getKeyContainer();
    } catch (e) {
      Log.warning(
        '_restoreFromLoadedPrimaryIdentity: failed to load primary identity: '
        '$e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      return null;
    }

    if (primary == null || !primary.hasPrivateKey) {
      return null;
    }

    final primaryNpub = NostrKeyUtils.encodePubKey(primary.publicKeyHex);
    if (primaryNpub != lastNpub) {
      return null;
    }

    String? privateKeyHex;
    primary.withPrivateKey<void>((hex) => privateKeyHex = hex);
    if (privateKeyHex == null || privateKeyHex!.isEmpty) {
      return null;
    }

    try {
      return SecureKeyContainer.fromPrivateKeyHex(privateKeyHex!);
    } catch (e) {
      Log.warning(
        '_restoreFromLoadedPrimaryIdentity: failed to reuse loaded identity: '
        '$e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      return null;
    }
  }

  /// Check for existing authentication
  Future<void> _checkExistingAuth() async {
    // If storage already failed once, the user saw the error and chose to
    // continue anyway. Skip the storage check and continue as
    // unauthenticated (same as a fresh install).
    if (_storageErrorOccurred) {
      Log.info(
        'Storage previously failed — user chose to continue. '
        'Proceeding unauthenticated as fresh install.',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      _storageErrorOccurred = false;
      _lastError = null;
      _setAuthState(AuthState.unauthenticated);
      return;
    } else {
      // Step 1: Check if keys exist in storage.
      // Keep this separate so storage errors don't silently fall through
      // to creating a new identity (which would overwrite the existing key).
      bool hasKeys;
      try {
        hasKeys = await _keyStorage.hasKeys();
      } catch (e, stack) {
        Log.error(
          'Secure storage error while checking for keys: $e. '
          'NOT creating a new identity to avoid overwriting existing keys. '
          'User will need to re-import their key.',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        _reportStorageError(e, stack, '_checkExistingAuth hasKeys()');
        _storageErrorOccurred = true;
        _lastError =
            "Couldn't load your saved identity from this device. "
            'Sign in with your existing account, or continue '
            'to create a new one.';
        _setAuthState(AuthState.unauthenticated);
        return;
      }

      Log.debug(
        '_checkExistingAuth: hasKeys=$hasKeys',
        name: 'AuthService',
        category: LogCategory.auth,
      );

      // Step 2: If keys exist, try to load them
      if (hasKeys) {
        Log.info(
          'Found existing secure keys, loading saved identity...',
          name: 'AuthService',
          category: LogCategory.auth,
        );

        try {
          final keyContainer = await _keyStorage.getKeyContainer();
          if (keyContainer != null) {
            Log.info(
              '_checkExistingAuth: loading identity '
              'pubkey=${keyContainer.publicKeyHex}',
              name: 'AuthService',
              category: LogCategory.auth,
            );
            await _setupUserSession(
              keyContainer,
              AuthenticationSource.automatic,
            );
            return;
          }
        } catch (e, stack) {
          Log.error(
            'Failed to load key container from storage: $e. '
            'NOT creating a new identity to avoid overwriting existing keys.',
            name: 'AuthService',
            category: LogCategory.auth,
          );
          _reportStorageError(e, stack, '_checkExistingAuth getKeyContainer()');
          _storageErrorOccurred = true;
          _lastError =
              "Couldn't load your saved identity from this device. "
              'Sign in with your existing account, or continue '
              'to create a new one.';
          _setAuthState(AuthState.unauthenticated);
          return;
        }

        // hasKeys() true but getKeyContainer() returned null — storage
        // inconsistency. Don't overwrite, let user re-import.
        Log.error(
          'Has keys flag set but could not load secure key container. '
          'NOT creating a new identity to avoid overwriting existing keys.',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        _reportStorageError(
          StateError('hasKeys() true but getKeyContainer() returned null'),
          StackTrace.current,
          '_checkExistingAuth storage inconsistency',
        );
        _storageErrorOccurred = true;
        _lastError =
            "Couldn't load your saved identity from this device. "
            'Sign in with your existing account, or continue '
            'to create a new one.';
        _setAuthState(AuthState.unauthenticated);
        return;
      }
    } // end else (no prior storage error)

    // Step 3: Genuinely no keys — fresh install, wait for onboarding
    Log.info(
      'No existing secure keys found, staying unauthenticated for onboarding.',
      name: 'AuthService',
      category: LogCategory.auth,
    );
    _setAuthState(AuthState.unauthenticated);
  }

  Future<void> acceptTerms() async {
    Log.debug(
      'acceptTerms: marking terms accepted and age verified',
      name: 'AuthService',
      category: LogCategory.auth,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'terms_accepted_at',
      DateTime.now().toIso8601String(),
    );
    await prefs.setBool('age_verified_16_plus', true);
  }

  /// Builds a [NostrIdentity] from the current mutable signer fields.
  ///
  /// Must be called AFTER signer fields (_keycastSigner, _bunkerSigner,
  /// _amberSigner) and _currentKeyContainer have been set for the session.
  ///
  /// Delegates to [SignerFactory.buildIdentity] with a per-call snapshot of
  /// the session fields, so the factory never holds a stale signer reference.
  ///
  /// Throws [StateError] if no valid identity can be constructed — this
  /// indicates a programming error in the auth flow, not a user-facing
  /// condition.
  NostrIdentity _buildIdentity({bool allowPubkeyOnlyIdentity = false}) {
    return _signerFactory.buildIdentity(
      keyContainer: _currentKeyContainer,
      authSource: _authSource,
      amberSigner: _amberSigner,
      nip07Service: _nip07Service,
      bunkerSigner: _bunkerSigner,
      keycastSigner: _keycastSigner,
      allowPubkeyOnlyIdentity: allowPubkeyOnlyIdentity,
    );
  }

  /// Claims legacy ownerless rows for the active session.
  ///
  /// Explicit account switching calls this only after the new container is
  /// committed, so a failed switch cannot permanently reassign shared legacy
  /// database rows to the target account.
  Future<void> claimLegacyRowsForCurrentUser() async {
    final pubkeyHex = _currentKeyContainer?.publicKeyHex;
    if (pubkeyHex == null || pubkeyHex.isEmpty) return;
    await _userDataCleanupService.claimLegacyRows(pubkeyHex);
  }

  /// Set up user session after successful authentication
  Future<void> _setupUserSession(
    SecureKeyContainer keyContainer,
    AuthenticationSource source, {
    bool allowPubkeyOnlyIdentity = false,
    bool claimLegacyRows = true,
    bool seedEmptyFollowingCache = false,
  }) async {
    Log.info(
      '_setupUserSession: starting — '
      'pubkey=${keyContainer.publicKeyHex}, source=${source.name}',
      name: 'AuthService',
      category: LogCategory.auth,
    );

    _currentKeyContainer = keyContainer;
    _authSource = source;

    // Clear any stale remote signers that don't match the new auth source.
    // This prevents a Keycast RPC signer from a previous Divine OAuth session
    // from being used when signing events for an anonymous/imported-key account.
    if (source != AuthenticationSource.divineOAuth) {
      _hasExpiredOAuthSession = false;
      _setRpcCapability(AuthRpcCapability.unavailable);
      if (_keycastSigner != null) {
        Log.info(
          '_setupUserSession: clearing stale Keycast signer '
          '(new source=${source.name})',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        // Never close: same-pubkey swaps (importing your own nsec) keep the live client's RPC open (#5909).
        _setKeycastSigner(null, closePrevious: false);
      }
    }
    if (source != AuthenticationSource.bunker && _bunkerSigner != null) {
      Log.info(
        '_setupUserSession: clearing stale bunker signer '
        '(new source=${source.name})',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      _bunkerSigner!.close();
      _bunkerSigner = null;
    }
    if (source != AuthenticationSource.amber && _amberSigner != null) {
      Log.info(
        '_setupUserSession: clearing stale amber signer '
        '(new source=${source.name})',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      _amberSigner!.close();
      _amberSigner = null;
    }
    if (source != AuthenticationSource.nip07 && _nip07Service != null) {
      Log.info(
        '_setupUserSession: clearing stale NIP-07 service '
        '(new source=${source.name})',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      _nip07Service = null;
    }

    // Build atomic identity AFTER stale signers are cleared.
    _currentIdentity = _buildIdentity(
      allowPubkeyOnlyIdentity: allowPubkeyOnlyIdentity,
    );

    // Create user profile
    _currentProfile = UserProfile(
      npub: keyContainer.npub,
      publicKeyHex: keyContainer.publicKeyHex,
      displayName: keyContainer.npub,
    );

    // Store current user pubkey in SharedPreferences for router redirect checks
    // This allows the router to know which user's following list to check
    try {
      final prefs = await SharedPreferences.getInstance();

      // Check if we need to clear user-specific data due to identity change
      final shouldClean = _userDataCleanupService.shouldClearDataForUser(
        keyContainer.publicKeyHex,
      );

      if (shouldClean) {
        final oldPubkey = prefs.getString('current_user_pubkey_hex');
        Log.info(
          '_setupUserSession: identity change detected — '
          'clearing shared caches for old pubkey '
          '${pubkeyForLogs(oldPubkey, whenNull: "unknown")} '
          '(owner-scoped drafts/clips/uploads preserved)',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        // Do NOT pass deleteUserData: true here. Owner-scoped rows (drafts,
        // clips, pending uploads) are already invisible to the incoming account
        // because every query filters by ownerPubkey. Deleting them here would
        // cause permanent data loss on account switch and mismatched re-login.
        // Destructive per-user DAO deletion is reserved for account deletion
        // (signOut(deleteKeys: true, deleteLocalUserData: true)).
        await _userDataCleanupService.clearUserSpecificData(
          reason: 'identity_change',
          isIdentityChange: true,
          userPubkey: oldPubkey,
          // deleteUserData omitted — defaults to false. Owner-scoped rows
          // (drafts, clips, uploads) are already invisible to the incoming
          // account via ownerPubkey filtering; no deletion is needed here.
        );
        // restore the TOS acceptance since we wouldn't be here otherwise
        await acceptTerms();
      } else {
        Log.debug(
          '_setupUserSession: same identity — no data cleanup needed',
          name: 'AuthService',
          category: LogCategory.auth,
        );
      }
      await prefs.setString(
        'current_user_pubkey_hex',
        keyContainer.publicKeyHex,
      );

      if (claimLegacyRows) {
        await claimLegacyRowsForCurrentUser();
      }

      await prefs.setString(kAuthenticationSourceKey, source.code);

      await prefs.setString(_kLastUsedNpubKey, keyContainer.npub);

      // Clear the session recovery anchor now that the user has explicitly
      // signed in. A stale anchor must not persist to interfere with future
      // welcome-screen mismatch detection after the next sign-out.
      await prefs.remove(_kSessionRecoveryAnchorKey);

      final followingCacheKey = FollowingCacheRecord.storageKey(
        keyContainer.publicKeyHex,
      );
      if (seedEmptyFollowingCache) {
        await prefs.setString(
          followingCacheKey,
          FollowingCacheRecord(pubkeys: const []).encode(),
        );
      }
      final hasFollowingCache = prefs.containsKey(followingCacheKey);

      // Pre-fetch following list from REST API BEFORE setting auth state.
      // The router redirect fires synchronously on auth state change and reads
      // following_list_{pubkey} from SharedPreferences. If the cache is empty
      // (identity change cleared it, or first login), the redirect sends the
      // user to /explore instead of /home. By fetching here, we ensure the
      // cache is populated before the redirect fires.
      if (_preFetchFollowing != null && !hasFollowingCache) {
        Log.debug(
          '_setupUserSession: pre-fetching following list...',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        try {
          await _preFetchFollowing(keyContainer.publicKeyHex);
          Log.debug(
            '_setupUserSession: following list pre-fetched',
            name: 'AuthService',
            category: LogCategory.auth,
          );
        } catch (e) {
          Log.warning(
            'Pre-fetch following list failed (will rely on '
            'FollowRepository): $e',
            name: 'AuthService',
            category: LogCategory.auth,
          );
        }
      } else if (hasFollowingCache) {
        Log.debug(
          '_setupUserSession: following list already cached — '
          'skipping pre-fetch',
          name: 'AuthService',
          category: LogCategory.auth,
        );
      }

      Log.info(
        '_setupUserSession: setting auth state to authenticated',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      _setAuthState(AuthState.authenticated);

      // Register this account in the known accounts list
      await _knownAccounts.upsert(keyContainer.publicKeyHex, source);

      // Store identity keys for multi-account switching
      try {
        await _keyStorage.storeIdentityKeyContainer(
          keyContainer.npub,
          keyContainer,
        );
        Log.debug(
          '_setupUserSession: identity keys stored for multi-account',
          name: 'AuthService',
          category: LogCategory.auth,
        );
      } catch (e) {
        // Best-effort — external signers may not have local keys to store
        Log.debug(
          '_setupUserSession: could not store identity keys '
          '(expected for external signers): $e',
          name: 'AuthService',
          category: LogCategory.auth,
        );
      }

      // Run discovery in background - it's not needed for the home feed to start
      // loading. Discovery results (relay list, blossom servers) are only used
      // when editing profile or publishing content.
      unawaited(_performDiscovery());
    } catch (e) {
      Log.warning(
        'error in _setupUserSession: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      // Default to awaiting TOS if we can't check
      _setAuthState(AuthState.awaitingTosAcceptance);
    }

    _profileController.add(_currentProfile);

    Log.info(
      'Secure user session established',
      name: 'AuthService',
      category: LogCategory.auth,
    );
    Log.verbose(
      'Profile: ${_currentProfile!.displayName}',
      name: 'AuthService',
      category: LogCategory.auth,
    );
    Log.debug(
      '📱 Security: Hardware-backed storage active',
      name: 'AuthService',
      category: LogCategory.auth,
    );
  }

  /// Perform all discovery operations using direct WebSocket connections.
  ///
  /// Discovery services (relay + blossom) open their own WebSocket connections
  /// to indexer relays - no temporary NostrClient is needed. This eliminates
  /// the fragile temp client that previously caused silent failures when
  /// relay.divine.video was slow to connect or interfered with storage.
  ///
  /// For the profile check, we query indexer relays directly since they also
  /// index kind 0 events.
  ///
  /// For returning users, this runs in background via unawaited().
  ///
  /// Delegates to [RelayDiscoveryOrchestrator]; results land back in
  /// [_userRelays]/[_hasExistingProfile] via its write-back callbacks.
  Future<void> _performDiscovery() async {
    if (_currentKeyContainer == null) return;

    final npub = _currentKeyContainer!.npub;

    Log.info(
      '🔍 Starting user discovery (relays + profile)...',
      name: 'AuthService',
      category: LogCategory.auth,
    );

    try {
      // Run discoveries in parallel - each service manages its own WebSocket
      // connections to indexer relays. No temp NostrClient needed.
      final targetPubkey =
          _currentIdentity?.pubkey ?? _currentKeyContainer?.publicKeyHex;
      await Future.wait([
        _discoveryOrchestrator.discoverUserRelays(npub, targetPubkey),
        _discoveryOrchestrator.checkExistingProfile(
          _currentKeyContainer?.publicKeyHex,
        ),
      ]);
    } catch (e) {
      Log.warning(
        '⚠️ Discovery failed: $e - using default fallbacks',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      _userRelays = [];
      _hasExistingProfile = false;
    }

    Log.info(
      '📊 Discovery complete: relays=${_userRelays.length}, '
      'hasExistingProfile=$_hasExistingProfile',
      name: 'AuthService',
      category: LogCategory.auth,
    );
  }

  bool _isRelayDiscoveryCurrent(String? targetPubkey) =>
      targetPubkey == null || _currentIdentity?.pubkey == targetPubkey;

  /// Test seam exposing the private NIP-65 discovery routine so unit
  /// tests can drive the fallback path with a mocked discovery service.
  /// Production callers should not invoke this — discovery runs as part
  /// of the normal sign-in flow via [_setupUserSession].
  @visibleForTesting
  Future<void> debugDiscoverUserRelays(String npub) =>
      _discoveryOrchestrator.discoverUserRelays(npub, _currentIdentity?.pubkey);

  /// Test seam that lets unit tests install a [NostrIdentity] without
  /// going through the full sign-in pipeline. Used by tests that exercise
  /// code paths (e.g. the bootstrap kind:10002 publish) which depend on
  /// [currentIdentity] being set.
  @visibleForTesting
  void debugSetIdentity(NostrIdentity? identity) {
    _currentIdentity = identity;
  }

  /// Test seam that installs a [KeycastRpc] signer without a real OAuth flow.
  ///
  /// Arrange the *starting* signer here and drive the real code path for the
  /// transition under test: a test that supplies [closePrevious] itself pins
  /// this seam's parameter rather than the production call site's choice, so
  /// it cannot fail when that call site stops passing it.
  @visibleForTesting
  void debugSetKeycastSigner(KeycastRpc? signer, {bool closePrevious = true}) =>
      _setKeycastSigner(signer, closePrevious: closePrevious);

  /// Test seam that lets unit tests install a [SecureKeyContainer] so
  /// `signOut`'s account-scoped invalidation (and any other code path
  /// keyed on the current pubkey) can be exercised without driving the
  /// full sign-in pipeline.
  ///
  /// **Scope warning**: this only sets `_currentKeyContainer`. It does
  /// not touch `_authSource`, `_currentIdentity`, signer wiring, auth
  /// state, or any other field that real sign-in initialises. Safe for
  /// tests that exercise branches keyed solely on `_currentKeyContainer`
  /// (e.g. the pubkey-capture step in `signOut`); using it as a general
  /// "pretend to be signed in" shim will produce inconsistent state.
  @visibleForTesting
  void debugSetCurrentKeyContainer(SecureKeyContainer? container) {
    _currentKeyContainer = container;
  }

  /// Update authentication state and notify listeners
  void _setAuthState(AuthState newState) {
    if (_authState != newState) {
      final previousState = _authState;
      _authState = newState;
      _authStateController.add(newState);

      Log.info(
        'Auth state: ${previousState.name} -> ${newState.name}',
        name: 'AuthService',
        category: LogCategory.auth,
      );
    }
  }

  void _setRpcCapability(AuthRpcCapability capability) {
    _authRpcCapabilityInitialized = true;
    if (_authRpcCapability != capability) {
      final previous = _authRpcCapability;
      _authRpcCapability = capability;
      _rpcCapabilityController.add(capability);

      Log.info(
        'RPC capability: ${previous.name} -> ${capability.name}',
        name: 'AuthService',
        category: LogCategory.auth,
      );
    }
  }

  /// Get user statistics
  Map<String, dynamic> get userStats => {
    'is_authenticated': isAuthenticated,
    'auth_state': authState.name,
    'npub': currentNpub,
    'key_created_at': _currentProfile?.keyCreatedAt?.toIso8601String(),
    'last_access_at': _currentProfile?.lastAccessAt?.toIso8601String(),
    'has_error': _lastError != null,
    'last_error': _lastError,
  };

  // ============================================================
  // BackgroundAwareService implementation
  // ============================================================

  @override
  String get serviceName => 'AuthService';

  @override
  void onAppBackgrounded() {
    // Pause bunker signer reconnection attempts when app goes to background
    if (_bunkerSigner != null) {
      Log.info(
        '📱 App backgrounded - pausing bunker signer',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      _bunkerSigner!.pause();
    }
  }

  @override
  void onAppResumed() {
    // Resume bunker signer reconnection attempts when app returns
    if (_bunkerSigner != null) {
      Log.info(
        '📱 App resumed - resuming bunker signer',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      _bunkerSigner!.resume();
    }

    // Reconnect nostrconnect:// session relays that may have dropped
    // while the app was in the background (e.g. user switched to Primal
    // to approve the connection on Android).
    _nostrConnect.reconnectListeningRelays();

    unawaited(_refreshOAuthTokenOnResume());
  }

  Future<void> _refreshOAuthTokenOnResume() async {
    try {
      if (_oauthClient == null) return;
      final isDegradedOAuth =
          _authSource == AuthenticationSource.divineOAuth &&
          _hasExpiredOAuthSession;
      if (_keycastSigner == null && !isDegradedOAuth) return;

      final resumeOwnerPubkey = currentPublicKeyHex;
      if (resumeOwnerPubkey == null) return;
      bool resumeContextStillCurrent() =>
          _authState == AuthState.authenticated &&
          currentPublicKeyHex == resumeOwnerPubkey;

      final session = await _oauthClient.getSession();
      if (!resumeContextStillCurrent()) return;

      if (session != null &&
          session.hasRpcAccess &&
          session.userPubkey == resumeOwnerPubkey) {
        if (_keycastSigner == null) {
          Log.info(
            '📱 App resumed - rebuilding OAuth RPC signer from stored session',
            name: 'AuthService',
            category: LogCategory.auth,
          );
          await clearDismissedDivineLoginBannerForCurrentUser();
          if (!resumeContextStillCurrent()) return;
          _setKeycastSigner(_newKeycastSigner(session));
          _currentIdentity = _buildIdentity();
          _hasExpiredOAuthSession = false;
          _setRpcCapability(AuthRpcCapability.rpcReady);
          _authStateController.add(_authState);
        }
        return;
      }

      Log.info(
        '📱 App resumed - OAuth RPC session unavailable, refreshing',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      await _upgradeDivineRpcInBackground(
        session,
        expectedOwnerPubkey: resumeOwnerPubkey,
        notifyAuthStateOnFailure: false,
      );
    } catch (e) {
      Log.error(
        '📱 App resumed - OAuth refresh failed: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
    }
  }

  @override
  void onExtendedBackground() {
    // For extended background, we keep the signer paused
    // No additional action needed - pause() already stops reconnection attempts
    Log.debug(
      '📱 Extended background - bunker signer remains paused',
      name: 'AuthService',
      category: LogCategory.auth,
    );
  }

  Future<void> dispose() async {
    Log.debug(
      '📱️ Disposing SecureAuthService',
      name: 'AuthService',
      category: LogCategory.auth,
    );

    // Unregister from BackgroundActivityManager
    if (_registeredWithBackgroundActivity) {
      _backgroundActivityManager.unregisterService(this);
      _registeredWithBackgroundActivity = false;
    }

    // Close bunker signer if active
    _bunkerSigner?.close();
    _bunkerSigner = null;

    // Close Amber signer if active
    _amberSigner?.close();
    _amberSigner = null;

    _setKeycastSigner(null);

    _nostrConnect.dispose();

    // Securely dispose of key container
    _currentKeyContainer?.dispose();
    _currentKeyContainer = null;

    await _authStateController.close();
    await _profileController.close();
    await _rpcCapabilityController.close();
    _keyStorage.dispose();
  }
}
