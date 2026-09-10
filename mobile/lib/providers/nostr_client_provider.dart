import 'dart:async';

import 'package:db_client/db_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/models/environment_config.dart';
import 'package:openvine/models/nostr_signature_verification_policy.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/preferences_providers.dart';
import 'package:openvine/providers/relay_providers.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/nostr_service_factory.dart';
import 'package:openvine/services/relay_discovery_service.dart';
import 'package:openvine/services/relay_statistics_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:unified_logger/unified_logger.dart';

part 'nostr_client_provider.g.dart';

/// Lifecycle phase for the app's Nostr publishing session.
///
/// [AuthState.authenticated] only means the user's identity is known. Consumers
/// that need to sign or publish Nostr events must wait for [nostrReady].
enum NostrSessionPhase { signedOut, identityKnown, nostrReady, tearingDown }

/// Readiness snapshot for signer-dependent Nostr side effects.
///
/// Use [isReadyForActiveClient] to confirm the phase, pubkey, and client all
/// describe the same signer-backed session before publishing.
class NostrSessionReadiness {
  const NostrSessionReadiness._({
    required this.phase,
    this.pubkey,
    this.client,
  });

  const NostrSessionReadiness.signedOut()
    : this._(phase: NostrSessionPhase.signedOut);

  const NostrSessionReadiness.identityKnown({required String pubkey})
    : this._(phase: NostrSessionPhase.identityKnown, pubkey: pubkey);

  const NostrSessionReadiness.tearingDown({required String pubkey})
    : this._(phase: NostrSessionPhase.tearingDown, pubkey: pubkey);

  const NostrSessionReadiness.nostrReady({
    required String pubkey,
    required NostrClient client,
  }) : this._(
         phase: NostrSessionPhase.nostrReady,
         pubkey: pubkey,
         client: client,
       );

  final NostrSessionPhase phase;
  final String? pubkey;
  final NostrClient? client;

  bool get isReadyForActiveClient {
    final readyClient = client;
    final readyPubkey = pubkey;
    return phase == NostrSessionPhase.nostrReady &&
        readyClient != null &&
        readyPubkey != null &&
        readyClient.hasKeys &&
        readyClient.publicKey == readyPubkey;
  }
}

/// Stores the current Nostr session readiness contract for the app.
///
/// The initial authenticated state is identity-known only. [NostrService]
/// advances this provider to [NostrSessionPhase.nostrReady] after the active
/// signer-backed [NostrClient] has initialized.
class NostrSession extends Notifier<NostrSessionReadiness> {
  @override
  NostrSessionReadiness build() {
    final identity = ref.watch(authServiceProvider).currentIdentity;
    if (identity == null) {
      return const NostrSessionReadiness.signedOut();
    }
    final previous = stateOrNull;
    if (previous?.pubkey == identity.pubkey) {
      return previous!;
    }
    return NostrSessionReadiness.identityKnown(pubkey: identity.pubkey);
  }

  void update(NostrSessionReadiness readiness) {
    state = readiness;
  }
}

/// App-wide contract for side effects that need Nostr signing or publishing.
///
/// Prefer this over raw auth state for Nostr side effects: auth only identifies
/// the user, while this provider identifies the ready signer/client pair.
final nostrSessionProvider =
    NotifierProvider<NostrSession, NostrSessionReadiness>(NostrSession.new);

final nip89ClientTagEnabledProvider = FutureProvider<bool>((ref) async {
  return Nip89ClientTag.isEnabled();
});

/// Signature for constructing a [NostrClient]. The default implementation
/// delegates to [NostrServiceFactory.create]. Tests override
/// [nostrClientFactoryProvider] to inject fake clients and observe the
/// arguments NostrService passes.
typedef NostrClientFactory = NostrClient Function({
  NostrSigner? signer,
  RelayStatisticsService? statisticsService,
  EnvironmentConfig? environmentConfig,
  AppDbClient? dbClient,
});

typedef NostrInitRetryDelay = Duration Function(int attempt);

const _nostrInitRetryBaseDelay = Duration(seconds: 5);
const _nostrInitRetryMaxDelay = Duration(seconds: 60);
const _nostrInitRetryExponentCap = 4;
const _nostrInitializationTimeout = Duration(seconds: 90);

/// Indirection layer over [NostrServiceFactory.create] so tests can
/// substitute a fake factory without touching the real relay/network
/// code path. Production builds use this provider transparently.
@Riverpod(keepAlive: true)
NostrClientFactory nostrClientFactory(Ref ref) => NostrServiceFactory.create;

/// Backoff policy for recovering the app-wide Nostr session after startup
/// relay or signer initialization fails.
///
/// Attempts are one-indexed. Tests override this with [Duration.zero] so the
/// recovery path can be exercised without wall-clock sleeps.
final nostrInitRetryDelayProvider = Provider<NostrInitRetryDelay>((ref) {
  return (attempt) {
    final exponent = (attempt - 1).clamp(0, _nostrInitRetryExponentCap);
    final seconds = _nostrInitRetryBaseDelay.inSeconds * (1 << exponent);
    return Duration(
      seconds: seconds.clamp(0, _nostrInitRetryMaxDelay.inSeconds),
    );
  };
});

final nostrInitializationTimeoutProvider = Provider<Duration>(
  (ref) => _nostrInitializationTimeout,
);

/// Whether one or more app-level Nostr client initialization attempts are
/// still running.
///
/// This deliberately tracks the outer [NostrService] future rather than
/// [NostrClient.isInitialized], which becomes true as soon as RelayManager
/// settles and can precede the rest of the service's startup bookkeeping.
final nostrInitializationInProgressProvider =
    NotifierProvider<NostrInitializationInProgress, bool>(
      NostrInitializationInProgress.new,
    );

class NostrInitializationInProgress extends Notifier<bool> {
  final Map<NostrClient, int> _attemptsByClient = Map.identity();

  @override
  bool build() => false;

  bool isClientInitializing(NostrClient client) {
    return _attemptsByClient.containsKey(client);
  }

  void begin(NostrClient client) {
    _attemptsByClient.update(
      client,
      (attempts) => attempts + 1,
      ifAbsent: () => 1,
    );
    state = true;
  }

  void end(NostrClient client) {
    if (!ref.mounted) return;
    final attempts = _attemptsByClient[client];
    assert(attempts != null, 'No initialization attempt for this client');
    if (attempts == null) return;
    if (attempts == 1) {
      _attemptsByClient.remove(client);
    } else {
      _attemptsByClient[client] = attempts - 1;
    }
    state = _attemptsByClient.isNotEmpty;
  }
}

/// Core Nostr service via NostrClient for relay communication
/// Uses a Notifier to react to auth state changes and recreate the client
/// when the keyContainer changes (e.g., user signs out and signs in with different keys)
@Riverpod(keepAlive: true)
class NostrService extends _$NostrService {
  StreamSubscription<AuthState>? _authSubscription;
  Timer? _initializationRetryTimer;
  String? _lastPubkey;

  /// Pubkey the current client was created to serve, recorded at creation
  /// time (before its initialization completes). Unlike [_lastPubkey] — which
  /// is only set once an init *succeeds* — this tracks the in-flight target so
  /// a same-pubkey auth re-emission (e.g. the Divine RPC-upgrade nudge) that
  /// lands while the client is still connecting relays is recognised as
  /// already-served and does not tear the connecting client down to rebuild an
  /// identical one (#5909). Cleared on init failure so failure-recovery
  /// re-emissions still recreate.
  String? _pendingPubkey;
  Future<void> _authStateChangeQueue = Future<void>.value();
  int _clientGeneration = 0;
  int _initializationFailureCount = 0;
  final Set<NostrClient> _trackedClients = {};

  int _nextClientGeneration() => ++_clientGeneration;

  void _invalidateClientGeneration() {
    _clientGeneration++;
  }

  @override
  NostrClient build() {
    final authService = ref.watch(authServiceProvider);
    ref.watch(relayStatisticsServiceProvider);
    ref.watch(currentEnvironmentProvider);
    ref.watch(appDbClientProvider);
    ref.watch(nostrClientFactoryProvider);
    ref.listen<NostrSignatureVerificationPolicy>(
      nostrSignatureVerificationPolicyProvider,
      (_, next) {
        state.signatureVerificationPolicy = next.toSdkPolicy();
      },
    );

    final initialPubkey = authService.currentIdentity?.pubkey;

    _authSubscription?.cancel();
    _authSubscription = authService.authStateStream.listen(
      _enqueueAuthStateChanged,
    );

    // Get user relay URLs from discovered relays (NIP-65)
    // Include all relays - NostrClient needs both read and write capable relays
    // for subscribing to events and publishing events respectively
    final userRelayUrls = authService.userRelays
        .map((relay) => relay.url)
        .toList();

    // Create the initial NostrClient using the atomic identity as signer.
    // currentIdentity is nullable; signed-out startup still exposes a placeholder
    // client for consumers, but the placeholder must not initialize relays.
    final client = _createClient(authService.currentIdentity);
    final clientGeneration = _nextClientGeneration();
    _pendingPubkey = initialPubkey;

    if (initialPubkey != null) {
      // NIP-65 discovered-relays callback — see _userRelaysDiscoveredCallbackFor.
      _registerClientCallbacks(
        authService: authService,
        client: client,
        pubkey: initialPubkey,
        clientGeneration: clientGeneration,
      );

      // Schedule initialization after build completes.
      // Add user relays BEFORE initialize() to avoid race condition.
      Future.microtask(
        () => _initializeClient(
          client: client,
          pubkey: initialPubkey,
          clientGeneration: clientGeneration,
          userRelayUrls: userRelayUrls,
          source: 'build',
        ),
      );
    }

    ref.onDispose(() {
      _initializationRetryTimer?.cancel();
      _initializationRetryTimer = null;
      authService.registerUserRelaysDiscoveredCallback(null);
      authService.registerBootstrapRelayListCallback(null);
      _authSubscription?.cancel();
      _invalidateClientGeneration();
      for (final trackedClient in _trackedClients.toList()) {
        trackedClient.dispose();
      }
      _trackedClients.clear();
    });

    return client;
  }

  NostrClient _createClient(NostrSigner? signer) {
    final client = ref.read(nostrClientFactoryProvider)(
      signer: signer,
      statisticsService: ref.read(relayStatisticsServiceProvider),
      environmentConfig: ref.read(currentEnvironmentProvider),
      dbClient: ref.read(appDbClientProvider),
    );
    client.signatureVerificationPolicy = ref
        .read(nostrSignatureVerificationPolicyProvider)
        .toSdkPolicy();
    _trackedClients.add(client);
    return client;
  }

  void _disposeClient(NostrClient client) {
    if (_trackedClients.remove(client)) {
      client.dispose();
    }
  }

  void _registerClientCallbacks({
    required AuthService authService,
    required NostrClient client,
    required String? pubkey,
    required int clientGeneration,
  }) {
    authService.registerUserRelaysDiscoveredCallback(
      _userRelaysDiscoveredCallbackFor(client, pubkey, clientGeneration),
    );
    authService.registerBootstrapRelayListCallback(
      bootstrapCallbackFor(client),
    );
  }

  Future<void> _initializeClient({
    required NostrClient client,
    required String? pubkey,
    required int clientGeneration,
    required List<String> userRelayUrls,
    required String source,
  }) async {
    NostrInitializationInProgress? initialization;
    try {
      final initializationTracker = ref.read(
        nostrInitializationInProgressProvider.notifier,
      );
      initializationTracker.begin(client);
      initialization = initializationTracker;
      await _runClientInitialization(client, userRelayUrls, source: source);
      // The provider can be disposed during the await (e.g. a rapid identity
      // switch rebuilds it, or a test container is torn down mid-init). Reading
      // `ref` after disposal throws, so bail before the ref-backed checks below.
      if (!ref.mounted) return;
      if (!_isCurrentClientForPubkey(client, pubkey, clientGeneration)) return;
      _lastPubkey = pubkey;
      _initializationFailureCount = 0;
      _initializationRetryTimer?.cancel();
      _initializationRetryTimer = null;
      _markClientReadyIfCurrent(client, pubkey, clientGeneration);
      Log.info(
        '[NostrService] Client initialized via $source()',
        name: 'NostrService',
        category: LogCategory.system,
      );
    } catch (e) {
      // Same disposal hazard as the success path: a provider torn down mid-init
      // makes the ref-backed recovery below throw. Bail before touching `ref`.
      if (!ref.mounted) return;
      Log.error(
        '[NostrService] Failed to initialize client in $source(): $e',
        name: 'NostrService',
        category: LogCategory.system,
      );
      if (!_isCurrentClientForPubkey(client, pubkey, clientGeneration)) {
        return;
      }
      if (_lastPubkey == pubkey) {
        _lastPubkey = null;
      }
      // Init settled (failed) for this in-flight target, so a later
      // same-pubkey re-emission must be free to recreate for recovery.
      if (_pendingPubkey == pubkey) {
        _pendingPubkey = null;
      }
      _setSessionIdentityState(pubkey);
      _scheduleInitializationRetry(pubkey);
    } finally {
      initialization?.end(client);
    }
  }

  Future<void> _runClientInitialization(
    NostrClient client,
    List<String> userRelayUrls, {
    required String source,
  }) async {
    final timeout = ref.read(nostrInitializationTimeoutProvider);
    final stopwatch = Stopwatch()..start();
    var stage = 'addingUserRelays';
    Log.info(
      '[NostrService] Initialization started: source=$source, '
      'userRelayCount=${userRelayUrls.length}, timeout=$timeout',
      name: 'NostrService',
      category: LogCategory.system,
    );

    try {
      await (() async {
        if (userRelayUrls.isNotEmpty) {
          // Loads the user-removal ledger up front. addRelays() awaits the
          // same idempotent load on its first relay, so this moves when the
          // storage read happens, not whether removed relays are suppressed.
          await client.ensureUserRemovedRelaysLoaded();
          final addedRelayCount = await client.addRelays(userRelayUrls);
          Log.info(
            '[NostrService] Initialization stage completed: source=$source, '
            'stage=$stage, addedRelayCount=$addedRelayCount, '
            'elapsedMs=${stopwatch.elapsedMilliseconds}',
            name: 'NostrService',
            category: LogCategory.system,
          );
        }
        stage = 'client.initialize';
        client.initializationObserver = (clientStage) {
          stage = 'client.${clientStage.name}';
          Log.debug(
            '[NostrService] Initialization stage started: source=$source, '
            'stage=$stage, elapsedMs=${stopwatch.elapsedMilliseconds}',
            name: 'NostrService',
            category: LogCategory.system,
          );
        };
        await client.initialize();
        Log.info(
          '[NostrService] Initialization completed: source=$source, '
          'elapsedMs=${stopwatch.elapsedMilliseconds}',
          name: 'NostrService',
          category: LogCategory.system,
        );
      })().timeout(
        timeout,
        onTimeout: () {
          throw TimeoutException(
            'Nostr client initialization timed out: source=$source, '
            'stage=$stage, userRelayCount=${userRelayUrls.length}, '
            'elapsedMs=${stopwatch.elapsedMilliseconds}',
            timeout,
          );
        },
      );
    } finally {
      client.initializationObserver = null;
    }
  }

  void _scheduleInitializationRetry(String? pubkey) {
    if (pubkey == null) return;
    if (_initializationRetryTimer?.isActive ?? false) return;

    final attempt = ++_initializationFailureCount;
    final delay = ref.read(nostrInitRetryDelayProvider)(attempt);
    Log.warning(
      '[NostrService] Scheduling initialization retry $attempt in $delay',
      name: 'NostrService',
      category: LogCategory.system,
    );
    _initializationRetryTimer = Timer(delay, () {
      _initializationRetryTimer = null;
      _enqueueClientLifecycleMutation(
        () => _retryInitializeCurrentIdentity(pubkey),
      );
    });
  }

  Future<void> _retryInitializeCurrentIdentity(String pubkey) async {
    final authService = ref.read(authServiceProvider);
    final identity = authService.currentIdentity;
    if (identity == null || identity.pubkey != pubkey) {
      return;
    }

    final oldClient = state;
    _invalidateClientGeneration();

    final userRelayUrls = authService.userRelays
        .map((relay) => relay.url)
        .toList();
    final client = _createClient(identity);
    final clientGeneration = _nextClientGeneration();
    _pendingPubkey = pubkey;
    NostrInitializationInProgress? initialization;
    try {
      final initializationTracker = ref.read(
        nostrInitializationInProgressProvider.notifier,
      );
      initializationTracker.begin(client);
      initialization = initializationTracker;
      await _runClientInitialization(client, userRelayUrls, source: 'retry');
      if (!_isActiveIdentity(pubkey, clientGeneration)) {
        _disposeClient(client);
        return;
      }
      authService.registerUserRelaysDiscoveredCallback(null);
      authService.registerBootstrapRelayListCallback(null);
      _disposeClient(oldClient);
      state = client;
      _lastPubkey = pubkey;
      _initializationFailureCount = 0;
      _initializationRetryTimer?.cancel();
      _initializationRetryTimer = null;
      _registerClientCallbacks(
        authService: authService,
        client: client,
        pubkey: pubkey,
        clientGeneration: clientGeneration,
      );
      _markClientReadyIfCurrent(client, pubkey, clientGeneration);
      Log.info(
        '[NostrService] Client initialized via retry()',
        name: 'NostrService',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        '[NostrService] Failed to initialize client in retry(): $e',
        name: 'NostrService',
        category: LogCategory.system,
      );
      _disposeClient(client);
      if (!ref.mounted) return;
      if (!_isActiveIdentity(pubkey, clientGeneration)) {
        return;
      }
      if (_lastPubkey == pubkey) {
        _lastPubkey = null;
      }
      if (_pendingPubkey == pubkey) {
        _pendingPubkey = null;
      }
      _setSessionIdentityState(pubkey);
      _scheduleInitializationRetry(pubkey);
    } finally {
      initialization?.end(client);
    }
  }

  void _enqueueAuthStateChanged(AuthState newState) {
    _enqueueClientLifecycleMutation(() => _onAuthStateChanged(newState));
  }

  void _enqueueClientLifecycleMutation(Future<void> Function() mutation) {
    _authStateChangeQueue = _authStateChangeQueue
        .catchError(_logAuthTransitionFailure)
        .then((_) async {
          try {
            await mutation();
          } catch (e, st) {
            _logAuthTransitionFailure(e, st);
          }
        });
  }

  void _logAuthTransitionFailure(Object error, StackTrace stackTrace) {
    Log.warning(
      '[NostrService] Auth state transition failed: $error',
      name: 'NostrService',
      category: LogCategory.system,
    );
  }

  Future<void> _onAuthStateChanged(AuthState newState) async {
    final authService = ref.read(authServiceProvider);
    // Read the atomic NostrIdentity as the sole source of truth for both
    // the recreation trigger and the signer we pass into the new client.
    // The currentPublicKeyHex / currentNpub getters on AuthService use a
    // fallback chain (identity → keyContainer → profile) intended for UI
    // consumers that just need a display pubkey during the auth-screen
    // lifecycle. Reading from those getters here can report a non-null
    // pubkey during a window where _currentIdentity is still null, which
    // would install an UnauthenticatedSigner whose getPublicKey() returns ''
    // and whose hasKeys is therefore permanently false — trapping every
    // downstream consumer. PR #2833 established
    // NostrIdentity as the atomic pubkey+signer contract; honour it here
    // so the signer and the trigger cannot disagree.
    final newIdentity = authService.currentIdentity;
    final newPubkey = newIdentity?.pubkey;

    final activeClientPubkey = state.hasKeys ? state.publicKey : null;
    // #5909: a client for newPubkey may already be in flight (created but not
    // yet initialized — _lastPubkey is only set on success). A same-pubkey
    // re-emission (the Divine RPC-upgrade nudge landing during startup relay
    // connect) must not tear that connecting client down to rebuild an
    // identical one. Recreate only when the current/in-flight client is NOT
    // already serving newPubkey. Cleared-on-failure semantics keep recovery
    // re-emissions (see the failure path) free to recreate.
    final alreadyServingNewPubkey =
        newPubkey != null && newPubkey == _pendingPubkey;
    if (!alreadyServingNewPubkey &&
        (newPubkey != _lastPubkey ||
            (newPubkey == null && activeClientPubkey != null))) {
      _invalidateClientGeneration();
      Log.info(
        '[NostrService] Public key changed from ${pubkeyForLogs(_lastPubkey)} to ${pubkeyForLogs(newPubkey)}, '
        'recreating NostrClient',
        name: 'NostrService',
        category: LogCategory.system,
      );

      final oldPubkey = _lastPubkey;
      if (oldPubkey != null) {
        ref
            .read(nostrSessionProvider.notifier)
            .update(NostrSessionReadiness.tearingDown(pubkey: oldPubkey));
      }

      // Unregister callback for old client before disposing it
      authService.registerUserRelaysDiscoveredCallback(null);
      authService.registerBootstrapRelayListCallback(null);
      _initializationRetryTimer?.cancel();
      _initializationRetryTimer = null;
      _initializationFailureCount = 0;
      _disposeClient(state);
      _invalidateClientGeneration();

      // Get user relay URLs from discovered relays (NIP-65)
      // Include all relays - NostrClient needs both read and write capable relays
      // for subscribing to events and publishing events respectively
      final userRelayUrls = authService.userRelays
          .map((relay) => relay.url)
          .toList();

      final newClient = _createClient(newIdentity);
      final clientGeneration = _nextClientGeneration();
      _pendingPubkey = newPubkey;

      state = newClient;
      _setSessionIdentityState(newPubkey);

      if (newPubkey == null) {
        _lastPubkey = null;
        _pendingPubkey = null;
        return;
      }

      // NIP-65 discovered-relays callback — see _userRelaysDiscoveredCallbackFor.
      _registerClientCallbacks(
        authService: authService,
        client: newClient,
        pubkey: newPubkey,
        clientGeneration: clientGeneration,
      );

      await _initializeClient(
        client: newClient,
        pubkey: newPubkey,
        clientGeneration: clientGeneration,
        userRelayUrls: userRelayUrls,
        source: 'authStateChanged',
      );
    }
  }

  void _setSessionIdentityState(String? pubkey) {
    ref
        .read(nostrSessionProvider.notifier)
        .update(
          pubkey == null
              ? const NostrSessionReadiness.signedOut()
              : NostrSessionReadiness.identityKnown(pubkey: pubkey),
        );
  }

  void _markClientReadyIfCurrent(
    NostrClient client,
    String? pubkey,
    int clientGeneration,
  ) {
    if (pubkey == null) {
      if (_isCurrentClientForPubkey(client, null, clientGeneration)) {
        ref
            .read(nostrSessionProvider.notifier)
            .update(const NostrSessionReadiness.signedOut());
      }
      return;
    }

    if (_isCurrentClientForPubkey(client, pubkey, clientGeneration) &&
        client.hasKeys &&
        client.publicKey == pubkey) {
      ref
          .read(nostrSessionProvider.notifier)
          .update(
            NostrSessionReadiness.nostrReady(pubkey: pubkey, client: client),
          );
    }
  }

  bool _isCurrentClientForPubkey(
    NostrClient client,
    String? pubkey,
    int clientGeneration,
  ) {
    final currentPubkey = ref.read(authServiceProvider).currentIdentity?.pubkey;
    return clientGeneration == _clientGeneration &&
        identical(state, client) &&
        currentPubkey == pubkey;
  }

  bool _isActiveIdentity(String pubkey, int clientGeneration) {
    final currentPubkey = ref.read(authServiceProvider).currentIdentity?.pubkey;
    return clientGeneration == _clientGeneration && currentPubkey == pubkey;
  }

  /// Builds the NIP-65 discovered-relays callback bound to [client].
  ///
  /// Registered with AuthService so when NIP-65 discovery completes later,
  /// the discovered relays are added to [client] — this fixes the race
  /// where discovery finishes after the client has been built. Used at
  /// both initial-build and account-switch sites so the
  /// add-relays-on-discovery flow stays in one place.
  UserRelaysDiscoveredCallback _userRelaysDiscoveredCallbackFor(
    NostrClient client,
    String? targetPubkey,
    int clientGeneration,
  ) {
    return (pubkey, relayUrls) {
      if (targetPubkey == null || pubkey != targetPubkey || relayUrls.isEmpty) {
        return;
      }
      // Last gate before this callback's discovered relays become permanent
      // pool members. Discovery already applies the same rule; keeping it
      // here protects the late-add path if a future caller hands the callback
      // a list that did not come straight from discovery (#6585).
      final admitted = admitRemoteSuppliedRelays(
        relayUrls,
        cap: RelayListCaps.nip65,
        onRejected: (url) => Log.warning(
          '[NostrService] Refusing discovered relay: $url',
          name: 'NostrService',
          category: LogCategory.system,
        ),
        onTruncated: (kept, total) => Log.warning(
          '[NostrService] Discovery returned $total relays; adding $kept',
          name: 'NostrService',
          category: LogCategory.system,
        ),
      );
      if (admitted.isEmpty) return;
      Future.microtask(() async {
        try {
          if (!_isCurrentClientForPubkey(
            client,
            targetPubkey,
            clientGeneration,
          )) {
            return;
          }
          final added = await client.addRelays(admitted);
          if (added > 0) {
            Log.info(
              '[NostrService] Added $added discovered relay(s) after NIP-65 discovery',
              name: 'NostrService',
              category: LogCategory.system,
            );
          }
        } catch (e) {
          Log.warning(
            '[NostrService] Failed to add discovered relays: $e',
            name: 'NostrService',
            category: LogCategory.system,
          );
        }
      });
    };
  }

  /// Builds the bootstrap kind:10002 publisher closure bound to [client].
  ///
  /// AuthService invokes this when indexer NIP-65 discovery returns empty,
  /// so we self-publish a minimal relay list on the user's behalf. Used at
  /// both initial-build and account-switch sites so the publish path stays
  /// in one place. See divine-mobile#3174 / keycast#94.
  /// Awaits a real relay acceptance rather than a socket write.
  ///
  /// The caller records a one-shot "already bootstrapped" flag when this
  /// returns true and otherwise retries on the next login, so reporting a
  /// frame-accept as published permanently strands a user whose relay list
  /// every indexer silently dropped: discovery keeps missing, and the device
  /// stays pinned to the fallback relay set forever.
  ///
  /// One indexer is enough — discovery queries them all and merges the
  /// results, so the list only has to be findable somewhere. It does have to
  /// be an *indexer*: the Divine relay is in the target set but
  /// [RelayDiscoveryService] never queries it, so its acceptance says nothing
  /// about whether the user became discoverable.
  @visibleForTesting
  static BootstrapRelayListCallback bootstrapCallbackFor(NostrClient client) {
    return (event, targetRelays) async {
      final outcome = await client.publishEventAwaitOk(
        event,
        targetRelays: targetRelays,
      );
      final acceptedByIndexer = outcome.acceptedBy.any(
        IndexerRelayConfig.defaultIndexers.contains,
      );
      if (!acceptedByIndexer) {
        Log.warning(
          '[NostrService] Bootstrap kind:10002 accepted by no indexer: '
          '${outcome.summary}',
          name: 'NostrService',
          category: LogCategory.system,
        );
      }
      return acceptedByIndexer;
    };
  }
}
