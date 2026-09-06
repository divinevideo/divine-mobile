// ABOUTME: Regression tests for NostrService consuming NostrIdentity as the
// ABOUTME: sole source of truth (per PR #2833) rather than the fallback-chain
// ABOUTME: getters on AuthService, preventing the null-signer placeholder trap.

import 'dart:async';

import 'package:db_client/db_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/models/environment_config.dart';
import 'package:openvine/models/nostr_signature_verification_policy.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/services/auth/nostr_identity.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/relay_discovery_service.dart';
import 'package:openvine/services/relay_statistics_service.dart';
import 'package:unified_logger/unified_logger.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockNostrClient extends Mock implements NostrClient {}

class _MockAppDbClient extends Mock implements AppDbClient {}

class _MockRelayStatisticsService extends Mock
    implements RelayStatisticsService {}

class _MockSecureKeyContainer extends Mock implements SecureKeyContainer {}

/// Records every factory invocation so the test can observe what signer
/// NostrService passed to each recreation.
class _RecordingFactory {
  final List<NostrSigner?> signers = [];
  final List<_MockNostrClient> clients = [];
  final Map<String?, Completer<void>> initializeCompleters = {};
  final Map<String?, List<Completer<void>>> initializeCompleterQueues = {};
  final Map<String?, Completer<void>> addRelaysCompleters = {};
  final Map<String?, List<Completer<void>>> addRelaysCompleterQueues = {};
  final List<String?> initializePubkeys = [];
  final List<String?> addRelaysPubkeys = [];

  Completer<void>? _takeCompleter(
    Map<String?, Completer<void>> singleCompleters,
    Map<String?, List<Completer<void>>> queuedCompleters,
    String? pubkey,
  ) {
    final queue = queuedCompleters[pubkey];
    if (queue != null && queue.isNotEmpty) {
      return queue.removeAt(0);
    }
    return singleCompleters[pubkey];
  }

  NostrClient call({
    NostrSigner? signer,
    RelayStatisticsService? statisticsService,
    EnvironmentConfig? environmentConfig,
    AppDbClient? dbClient,
  }) {
    signers.add(signer);
    final client = _MockNostrClient();
    // hasKeys reflects whether we got a real signer or a null placeholder.
    final hasKeys = signer != null;
    final pubkey = signer is NostrIdentity ? signer.pubkey : null;
    final initializeCompleter = _takeCompleter(
      initializeCompleters,
      initializeCompleterQueues,
      pubkey,
    );
    final addRelaysCompleter = _takeCompleter(
      addRelaysCompleters,
      addRelaysCompleterQueues,
      pubkey,
    );
    when(() => client.hasKeys).thenReturn(hasKeys);
    when(
      () => client.publicKey,
    ).thenReturn(pubkey ?? '');
    when(client.initialize).thenAnswer((_) {
      initializePubkeys.add(pubkey);
      return initializeCompleter?.future ?? Future<void>.value();
    });
    when(client.ensureUserRemovedRelaysLoaded).thenAnswer(
      (_) => Future<void>.value(),
    );
    when(() => client.addRelays(any())).thenAnswer((_) async {
      addRelaysPubkeys.add(pubkey);
      await addRelaysCompleter?.future;
      return 0;
    });
    // ignore: unnecessary_lambdas
    when(() => client.dispose()).thenAnswer((_) => Future<void>.value());
    clients.add(client);
    return client;
  }

  int get callCount => signers.length;
}

void main() {
  const pubkeyA =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const pubkeyB =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
  const pubkeyC =
      'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
  const discoveredRelay = DiscoveredRelay(url: 'wss://relay.example');

  setUpAll(() {
    registerFallbackValue(<String>[]);
  });

  late _MockAuthService mockAuth;
  late _MockAppDbClient mockDbClient;
  late _MockRelayStatisticsService mockStats;
  late StreamController<AuthState> authStream;
  late _RecordingFactory factory;
  late NostrIdentity identityA;
  late NostrIdentity identityB;
  late NostrIdentity identityC;

  NostrIdentity buildIdentity(String pubkey) {
    final keyContainer = _MockSecureKeyContainer();
    when(() => keyContainer.publicKeyHex).thenReturn(pubkey);
    when(() => keyContainer.isDisposed).thenReturn(false);
    return LocalNostrIdentity(keyContainer: keyContainer);
  }

  setUp(() async {
    await LogCaptureService().clearAllLogs();
    mockAuth = _MockAuthService();
    mockDbClient = _MockAppDbClient();
    mockStats = _MockRelayStatisticsService();
    authStream = StreamController<AuthState>.broadcast();
    factory = _RecordingFactory();
    identityA = buildIdentity(pubkeyA);
    identityB = buildIdentity(pubkeyB);
    identityC = buildIdentity(pubkeyC);

    // Baseline: unauthenticated state. Tests override currentIdentity
    // per scenario.
    when(() => mockAuth.currentIdentity).thenReturn(null);
    when(() => mockAuth.currentPublicKeyHex).thenReturn(null);
    when(() => mockAuth.currentNpub).thenReturn(null);
    when(() => mockAuth.userRelays).thenReturn([]);
    when(() => mockAuth.authStateStream).thenAnswer((_) => authStream.stream);
    when(
      () => mockAuth.registerUserRelaysDiscoveredCallback(any()),
    ).thenReturn(null);
  });

  tearDown(() async {
    await authStream.close();
  });

  ProviderContainer createContainer() {
    return ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(mockAuth),
        relayStatisticsServiceProvider.overrideWithValue(mockStats),
        currentEnvironmentProvider.overrideWithValue(
          EnvironmentConfig.production,
        ),
        appDbClientProvider.overrideWithValue(mockDbClient),
        nostrClientFactoryProvider.overrideWithValue(factory.call),
        nostrSignatureVerificationPolicyProvider.overrideWithValue(
          NostrSignatureVerificationPolicy.nonDivineRelays,
        ),
      ],
    );
  }

  ProviderContainer createRetryContainer({
    Duration Function(int attempt)? retryDelay,
    Duration initializationTimeout = const Duration(seconds: 90),
  }) {
    return ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(mockAuth),
        relayStatisticsServiceProvider.overrideWithValue(mockStats),
        currentEnvironmentProvider.overrideWithValue(
          EnvironmentConfig.production,
        ),
        appDbClientProvider.overrideWithValue(mockDbClient),
        nostrClientFactoryProvider.overrideWithValue(factory.call),
        nostrSignatureVerificationPolicyProvider.overrideWithValue(
          NostrSignatureVerificationPolicy.nonDivineRelays,
        ),
        nostrInitRetryDelayProvider.overrideWithValue(
          retryDelay ?? (_) => Duration.zero,
        ),
        nostrInitializationTimeoutProvider.overrideWithValue(
          initializationTimeout,
        ),
      ],
    );
  }

  group('NostrService uses NostrIdentity as source of truth', () {
    test('tracks the full outer initialization attempt', () async {
      final initialize = Completer<void>();
      factory.initializeCompleters[pubkeyA] = initialize;
      when(() => mockAuth.currentIdentity).thenReturn(identityA);
      when(() => mockAuth.currentPublicKeyHex).thenReturn(pubkeyA);

      final container = createContainer();
      addTearDown(container.dispose);

      container.read(nostrServiceProvider);
      await pumpEventQueue(times: 1);

      expect(container.read(nostrInitializationInProgressProvider), isTrue);

      initialize.complete();
      await pumpEventQueue(times: 1);
      await pumpEventQueue(times: 1);

      expect(container.read(nostrInitializationInProgressProvider), isFalse);
    });

    test('initialization retry backoff is bounded exponential policy', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final retryDelay = container.read(nostrInitRetryDelayProvider);

      expect(
        [for (var attempt = 1; attempt <= 6; attempt++) retryDelay(attempt)],
        const [
          Duration(seconds: 5),
          Duration(seconds: 10),
          Duration(seconds: 20),
          Duration(seconds: 40),
          Duration(seconds: 60),
          Duration(seconds: 60),
        ],
      );
    });

    test('does not recreate with null-signer placeholder when authenticating '
        'emits while currentIdentity is still null', () async {
      // Simulate the auth-screen transient state described in PR #2833:
      // the fallback-chain getter reports a pubkey (from _currentProfile or
      // _currentKeyContainer) but the atomic NostrIdentity has not yet
      // been assembled. NostrService must read the identity, not the
      // fallback getter, so it derives newPubkey=null from a null
      // identity and takes the NO-OP branch.
      final container = createContainer();
      addTearDown(container.dispose);

      // Trigger NostrService.build() — initial state with no identity.
      container.read(nostrServiceProvider);
      expect(
        factory.callCount,
        equals(1),
        reason: 'build() calls factory once for initial placeholder',
      );
      expect(factory.signers.single, isNull);

      // Move AuthService into the 'authenticating' trap state:
      // currentPublicKeyHex returns a real pubkey via the fallback chain
      // but currentIdentity is still null.
      when(() => mockAuth.currentPublicKeyHex).thenReturn(pubkeyA);
      when(() => mockAuth.currentNpub).thenReturn('npub1aaa');
      // currentIdentity intentionally remains null.

      authStream.add(AuthState.authenticating);
      // Let the async listener run.
      await pumpEventQueue(times: 1);

      expect(
        factory.callCount,
        equals(1),
        reason:
            'Must NOT recreate with a null signer while currentIdentity '
            'is null — the placeholder client would report hasKeys=false '
            'permanently and trap downstream providers.',
      );

      // Now the atomic identity finishes assembling. The authenticated
      // emit should trigger a single recreation with the real signer.
      when(() => mockAuth.currentIdentity).thenReturn(identityA);

      authStream.add(AuthState.authenticated);
      await pumpEventQueue(times: 1);

      expect(
        factory.callCount,
        equals(2),
        reason:
            'authenticated emit with real identity must recreate the '
            'client with a real signer',
      );
      expect(factory.signers.last, same(identityA));
      expect(factory.clients.last.hasKeys, isTrue);
      expect(factory.clients.last.publicKey, equals(pubkeyA));
    });

    test('does not initialize the signed-out placeholder client', () async {
      final container = createContainer();
      addTearDown(container.dispose);

      container.read(nostrServiceProvider);
      await pumpEventQueue(times: 1);
      await pumpEventQueue(times: 1);

      expect(factory.callCount, equals(1));
      expect(factory.signers.single, isNull);
      expect(
        factory.initializePubkeys,
        isEmpty,
        reason:
            'signed-out startup should expose a placeholder client without '
            'connecting relays or completing stale build-path initialization',
      );
      expect(container.read(nostrInitializationInProgressProvider), isFalse);
    });

    test('recreates with null-signer placeholder on signOut '
        '(identity → null transition)', () async {
      // Start authenticated as A.
      when(() => mockAuth.currentIdentity).thenReturn(identityA);
      when(() => mockAuth.currentPublicKeyHex).thenReturn(pubkeyA);

      final container = createContainer();
      addTearDown(container.dispose);

      container.read(nostrServiceProvider);
      expect(factory.callCount, equals(1));
      expect(factory.signers.single, same(identityA));
      expect(factory.clients.single.hasKeys, isTrue);

      // Sign out: clear identity and pubkey, emit unauthenticated.
      when(() => mockAuth.currentIdentity).thenReturn(null);
      when(() => mockAuth.currentPublicKeyHex).thenReturn(null);
      authStream.add(AuthState.unauthenticated);
      await pumpEventQueue(times: 1);

      expect(
        factory.callCount,
        equals(2),
        reason: 'signOut must dispose the A client and recreate a new one',
      );
      expect(factory.signers.last, isNull);
      expect(factory.clients.last.hasKeys, isFalse);
    });

    test(
      'full account switch A → unauth → B installs real signer for B',
      () async {
        // Reproduces the device-log scenario verbatim: start authenticated
        // as A, signOut through unauthenticated, transition through
        // authenticating with currentIdentity still null, then authenticated
        // with the real identity for B.
        when(() => mockAuth.currentIdentity).thenReturn(identityA);
        when(() => mockAuth.currentPublicKeyHex).thenReturn(pubkeyA);

        final container = createContainer();
        addTearDown(container.dispose);

        container.read(nostrServiceProvider);
        expect(factory.callCount, equals(1));
        expect(factory.clients.last.hasKeys, isTrue);

        // Step 1: signOut — unauthenticated, clear identity.
        when(() => mockAuth.currentIdentity).thenReturn(null);
        when(() => mockAuth.currentPublicKeyHex).thenReturn(null);
        authStream.add(AuthState.unauthenticated);
        await pumpEventQueue(times: 1);
        expect(factory.callCount, equals(2));
        expect(factory.clients.last.hasKeys, isFalse);

        // Step 2: authenticating for B — fallback chain reports B's pubkey
        // (from _currentProfile or _currentKeyContainer set in partial
        // _setupUserSession state) but currentIdentity is still null.
        when(() => mockAuth.currentPublicKeyHex).thenReturn(pubkeyB);
        // currentIdentity stays null intentionally.
        authStream.add(AuthState.authenticating);
        await pumpEventQueue(times: 1);

        expect(
          factory.callCount,
          equals(2),
          reason:
              'authenticating emit with null currentIdentity must NOT '
              'recreate — that would install a placeholder that masks '
              'the subsequent authenticated emit',
        );

        // Step 3: authenticated with real identity for B.
        when(() => mockAuth.currentIdentity).thenReturn(identityB);
        authStream.add(AuthState.authenticated);
        await pumpEventQueue(times: 1);

        expect(factory.callCount, equals(3));
        expect(factory.signers.last, same(identityB));
        expect(factory.clients.last.hasKeys, isTrue);
        expect(factory.clients.last.publicKey, equals(pubkeyB));
      },
    );

    test(
      'serializes auth transitions so older initialization cannot replace newer client',
      () async {
        when(() => mockAuth.currentIdentity).thenReturn(identityA);
        when(() => mockAuth.currentPublicKeyHex).thenReturn(pubkeyA);

        final container = createContainer();
        addTearDown(container.dispose);

        container.read(nostrServiceProvider);
        expect(factory.callCount, equals(1));
        expect(factory.clients.single.publicKey, equals(pubkeyA));

        final bInitialize = Completer<void>();
        factory.initializeCompleters[pubkeyB] = bInitialize;

        when(() => mockAuth.currentIdentity).thenReturn(identityB);
        when(() => mockAuth.currentPublicKeyHex).thenReturn(pubkeyB);
        authStream.add(AuthState.authenticated);
        await pumpEventQueue(times: 1);

        expect(factory.callCount, equals(2));
        expect(
          container.read(nostrSessionProvider).phase,
          equals(NostrSessionPhase.identityKnown),
          reason:
              'B should be known but not ready while initialize is blocked.',
        );

        when(() => mockAuth.currentIdentity).thenReturn(identityC);
        when(() => mockAuth.currentPublicKeyHex).thenReturn(pubkeyC);
        authStream.add(AuthState.authenticated);
        await pumpEventQueue(times: 1);

        expect(
          factory.callCount,
          equals(2),
          reason:
              'C must wait for the in-flight B transition instead of interleaving.',
        );

        bInitialize.complete();
        await pumpEventQueue(times: 1);
        await pumpEventQueue(times: 1);

        expect(factory.callCount, equals(3));
        expect(factory.clients.last.publicKey, equals(pubkeyC));
        expect(
          container.read(nostrServiceProvider),
          same(factory.clients.last),
        );
        expect(container.read(nostrSessionProvider).pubkey, equals(pubkeyC));
        expect(
          container.read(nostrSessionProvider).phase,
          equals(NostrSessionPhase.nostrReady),
        );
      },
    );

    test(
      'does not expose disposed old client while replacement initializes',
      () async {
        when(() => mockAuth.currentIdentity).thenReturn(identityA);
        when(() => mockAuth.currentPublicKeyHex).thenReturn(pubkeyA);

        final container = createContainer();
        addTearDown(container.dispose);

        final oldClient = container.read(nostrServiceProvider);
        await pumpEventQueue(times: 1);
        await pumpEventQueue(times: 1);

        final bInitialize = Completer<void>();
        factory.initializeCompleters[pubkeyB] = bInitialize;

        when(() => mockAuth.currentIdentity).thenReturn(identityB);
        when(() => mockAuth.currentPublicKeyHex).thenReturn(pubkeyB);
        authStream.add(AuthState.authenticated);
        await pumpEventQueue(times: 1);
        await pumpEventQueue(times: 1);

        expect(factory.callCount, equals(2));
        expect(
          container.read(nostrServiceProvider),
          isNot(same(oldClient)),
          reason:
              'Once the old client is disposed, provider state must stop '
              'exposing it even while the replacement is still initializing.',
        );
        expect(
          container.read(nostrSessionProvider),
          isA<NostrSessionReadiness>()
              .having(
                (readiness) => readiness.phase,
                'phase',
                NostrSessionPhase.identityKnown,
              )
              .having((readiness) => readiness.pubkey, 'pubkey', pubkeyB),
          reason:
              'The replacement client is not ready until initialize passes.',
        );

        bInitialize.complete();
        await pumpEventQueue(times: 1);
        await pumpEventQueue(times: 1);

        expect(
          container.read(nostrServiceProvider),
          same(factory.clients.last),
        );
        expect(
          container.read(nostrSessionProvider).phase,
          equals(NostrSessionPhase.nostrReady),
        );
      },
    );

    test(
      'drives session readiness from identity known to ready to signed out',
      () async {
        final bInitialize = Completer<void>();
        final signOutInitialize = Completer<void>();
        factory.initializeCompleters[pubkeyB] = bInitialize;
        factory.initializeCompleters[null] = signOutInitialize;

        final container = createContainer();
        addTearDown(container.dispose);

        final observedReadiness = <NostrSessionReadiness>[];
        final subscription = container.listen<NostrSessionReadiness>(
          nostrSessionProvider,
          (_, next) => observedReadiness.add(next),
          fireImmediately: true,
        );
        addTearDown(subscription.close);

        container.read(nostrServiceProvider);

        when(() => mockAuth.currentIdentity).thenReturn(identityB);
        when(() => mockAuth.currentPublicKeyHex).thenReturn(pubkeyB);
        authStream.add(AuthState.authenticated);
        await pumpEventQueue(times: 1);
        await pumpEventQueue(times: 1);

        expect(
          container.read(nostrSessionProvider),
          isA<NostrSessionReadiness>()
              .having(
                (readiness) => readiness.phase,
                'phase',
                NostrSessionPhase.identityKnown,
              )
              .having((readiness) => readiness.pubkey, 'pubkey', pubkeyB),
          reason:
              'AuthState.authenticated identifies the user before the Nostr '
              'client can sign or publish.',
        );

        bInitialize.complete();
        await pumpEventQueue(times: 1);
        await pumpEventQueue(times: 1);

        final readyClient = container.read(nostrServiceProvider);
        expect(
          container.read(nostrSessionProvider),
          isA<NostrSessionReadiness>()
              .having(
                (readiness) => readiness.phase,
                'phase',
                NostrSessionPhase.nostrReady,
              )
              .having((readiness) => readiness.pubkey, 'pubkey', pubkeyB)
              .having(
                (readiness) => readiness.client,
                'client',
                same(readyClient),
              ),
        );

        when(() => mockAuth.currentIdentity).thenReturn(null);
        when(() => mockAuth.currentPublicKeyHex).thenReturn(null);
        authStream.add(AuthState.unauthenticated);
        await pumpEventQueue(times: 1);
        await pumpEventQueue(times: 1);

        expect(
          observedReadiness.map((readiness) => readiness.phase),
          containsAllInOrder([
            NostrSessionPhase.identityKnown,
            NostrSessionPhase.nostrReady,
            NostrSessionPhase.tearingDown,
            NostrSessionPhase.signedOut,
          ]),
        );
        expect(
          container.read(nostrSessionProvider).phase,
          NostrSessionPhase.signedOut,
        );
      },
    );

    test(
      'failed auth transition does not block later auth transitions',
      () async {
        when(() => mockAuth.currentIdentity).thenReturn(identityA);
        when(() => mockAuth.currentPublicKeyHex).thenReturn(pubkeyA);

        final container = createContainer();
        addTearDown(container.dispose);

        container.read(nostrServiceProvider);
        await pumpEventQueue(times: 1);
        await pumpEventQueue(times: 1);

        final bInitialize = Completer<void>();
        factory.initializeCompleters[pubkeyB] = bInitialize;

        when(() => mockAuth.currentIdentity).thenReturn(identityB);
        when(() => mockAuth.currentPublicKeyHex).thenReturn(pubkeyB);
        authStream.add(AuthState.authenticated);
        await pumpEventQueue(times: 1);

        when(() => mockAuth.currentIdentity).thenReturn(identityC);
        when(() => mockAuth.currentPublicKeyHex).thenReturn(pubkeyC);
        authStream.add(AuthState.authenticated);
        bInitialize.completeError(StateError('B initialize failed'));
        await pumpEventQueue(times: 1);
        await pumpEventQueue(times: 1);
        await pumpEventQueue(times: 1);

        expect(factory.callCount, equals(3));
        expect(factory.clients.last.publicKey, equals(pubkeyC));
        expect(
          container.read(nostrServiceProvider),
          same(factory.clients.last),
        );
        expect(
          container.read(nostrSessionProvider),
          isA<NostrSessionReadiness>()
              .having(
                (readiness) => readiness.phase,
                'phase',
                NostrSessionPhase.nostrReady,
              )
              .having((readiness) => readiness.pubkey, 'pubkey', pubkeyC)
              .having(
                (readiness) => readiness.client,
                'client',
                same(factory.clients.last),
              ),
        );
      },
    );

    test('failed same-pubkey transition can retry client creation', () async {
      when(() => mockAuth.currentIdentity).thenReturn(identityA);
      when(() => mockAuth.currentPublicKeyHex).thenReturn(pubkeyA);

      final container = createContainer();
      addTearDown(container.dispose);

      container.read(nostrServiceProvider);
      await pumpEventQueue(times: 1);
      await pumpEventQueue(times: 1);
      expect(factory.callCount, equals(1));

      final failedBInitialize = Completer<void>();
      factory.initializeCompleters[pubkeyB] = failedBInitialize;

      when(() => mockAuth.currentIdentity).thenReturn(identityB);
      when(() => mockAuth.currentPublicKeyHex).thenReturn(pubkeyB);
      authStream.add(AuthState.authenticated);
      await pumpEventQueue(times: 1);

      expect(factory.callCount, equals(2));

      failedBInitialize.completeError(StateError('B initialize failed'));
      await pumpEventQueue(times: 1);
      await pumpEventQueue(times: 1);

      factory.initializeCompleters.remove(pubkeyB);
      authStream.add(AuthState.authenticated);
      await pumpEventQueue(times: 1);
      await pumpEventQueue(times: 1);
      await pumpEventQueue(times: 1);

      expect(
        factory.callCount,
        equals(3),
        reason:
            'A failed transition must not mark pubkey B complete; a later '
            'auth emission for B should recreate and initialize a new client.',
      );
      expect(factory.clients.last.publicKey, equals(pubkeyB));
      expect(container.read(nostrServiceProvider), same(factory.clients.last));
      expect(
        container.read(nostrSessionProvider),
        isA<NostrSessionReadiness>()
            .having(
              (readiness) => readiness.phase,
              'phase',
              NostrSessionPhase.nostrReady,
            )
            .having((readiness) => readiness.pubkey, 'pubkey', pubkeyB)
            .having(
              (readiness) => readiness.client,
              'client',
              same(factory.clients.last),
            ),
      );
    });

    test('failed initial same-pubkey build can retry client creation', () async {
      final failedInitialAInitialize = Completer<void>();
      factory.initializeCompleters[pubkeyA] = failedInitialAInitialize;
      when(() => mockAuth.currentIdentity).thenReturn(identityA);
      when(() => mockAuth.currentPublicKeyHex).thenReturn(pubkeyA);

      final container = createContainer();
      addTearDown(container.dispose);

      container.read(nostrServiceProvider);
      await pumpEventQueue(times: 1);
      expect(factory.callCount, equals(1));

      failedInitialAInitialize.completeError(
        StateError('initial A initialize failed'),
      );
      await pumpEventQueue(times: 1);
      await pumpEventQueue(times: 1);

      expect(
        container.read(nostrSessionProvider),
        isA<NostrSessionReadiness>()
            .having(
              (readiness) => readiness.phase,
              'phase',
              NostrSessionPhase.identityKnown,
            )
            .having((readiness) => readiness.pubkey, 'pubkey', pubkeyA),
        reason:
            'A failed initial client must leave readiness non-ready for the '
            'known identity.',
      );

      factory.initializeCompleters.remove(pubkeyA);
      authStream.add(AuthState.authenticated);
      await pumpEventQueue(times: 1);
      await pumpEventQueue(times: 1);
      await pumpEventQueue(times: 1);

      expect(
        factory.callCount,
        equals(2),
        reason:
            'A failed initial build must not mark pubkey A complete; a later '
            'auth emission for A should recreate and initialize a new client.',
      );
      expect(factory.clients.last.publicKey, equals(pubkeyA));
      expect(container.read(nostrServiceProvider), same(factory.clients.last));
      expect(
        container.read(nostrSessionProvider),
        isA<NostrSessionReadiness>()
            .having(
              (readiness) => readiness.phase,
              'phase',
              NostrSessionPhase.nostrReady,
            )
            .having((readiness) => readiness.pubkey, 'pubkey', pubkeyA)
            .having(
              (readiness) => readiness.client,
              'client',
              same(factory.clients.last),
            ),
      );
    });

    test(
      'same-pubkey RPC-upgrade nudge after a successful restore is deduped '
      '(no spurious NostrClient rebuild) — #5909',
      () async {
        // Reproduces the production Divine-OAuth cold-start sequence that
        // issue #5909 flags. On every production launch NostrService.build()
        // runs BEFORE AuthService restores the identity (Case B: the
        // corrupted-video-repair microtask forces the provider ahead of the
        // MethodChannel-gated key-storage restore), so build() sees a null
        // identity and creates a placeholder client. The `authenticated`
        // restore then recreates the client once (placeholder -> real) and,
        // on success, records _lastPubkey. The RPC-upgrade path later re-emits
        // the SAME auth state unconditionally (auth_service.dart:733) once the
        // background Keycast refresh resolves; because it is serialized behind
        // the restore on _authStateChangeQueue and carries the same pubkey, it
        // must be deduped — NOT trigger a second full client rebuild.
        //
        // Guards the WAI conclusion of #5909: if the queue serialization or
        // the `newPubkey != _lastPubkey` dedup ever regressed, this nudge
        // would rebuild the whole client mid-startup and this test would fail
        // (callCount 3 instead of 2).

        // Case B: currentIdentity is null at build() (baseline from setUp).
        final container = createContainer();
        addTearDown(container.dispose);

        container.read(nostrServiceProvider);
        await pumpEventQueue(times: 1);
        expect(
          factory.callCount,
          equals(1),
          reason:
              'build() creates the placeholder client before restore (Case B).',
        );
        expect(factory.signers.single, isNull);

        // Identity restore: the authenticated emission carries the real
        // identity, recreating the placeholder into a real client exactly once.
        when(() => mockAuth.currentIdentity).thenReturn(identityA);
        when(() => mockAuth.currentPublicKeyHex).thenReturn(pubkeyA);
        authStream.add(AuthState.authenticated);
        await pumpEventQueue(times: 1);
        await pumpEventQueue(times: 1);

        expect(
          factory.callCount,
          equals(2),
          reason:
              'the authenticated restore recreates once (placeholder -> real).',
        );
        expect(factory.signers.last, same(identityA));
        expect(
          container.read(nostrSessionProvider).phase,
          equals(NostrSessionPhase.nostrReady),
          reason:
              'the successful restore init records _lastPubkey and marks ready.',
        );

        // RPC-upgrade nudge: same pubkey re-emitted after the background
        // Keycast upgrade resolves (auth_service.dart:733, unconditional add).
        authStream.add(AuthState.authenticated);
        await pumpEventQueue(times: 1);
        await pumpEventQueue(times: 1);

        expect(
          factory.callCount,
          equals(2),
          reason:
              'a same-pubkey RPC-upgrade nudge must be deduped '
              '(newPubkey == _lastPubkey) — no spurious NostrClient rebuild '
              'during startup (#5909).',
        );
        expect(
          container.read(nostrServiceProvider),
          same(factory.clients.last),
          reason: 'the client identity is unchanged by the deduped nudge.',
        );
      },
    );

    test(
      'does not rebuild the connecting client when a same-pubkey nudge '
      'arrives while the build-path init is still in flight (#5909)',
      () async {
        // Case A hardening: if NostrService.build() runs AFTER the identity is
        // restored (e.g. a future change removes the incidental pre-restore
        // read that currently forces build() early), the build-path init is in
        // flight for the real pubkey with _lastPubkey still null. Without the
        // in-flight-target guard, the same-pubkey RPC-upgrade nudge
        // (auth_service.dart:733) would satisfy `newPubkey != _lastPubkey` and
        // tear down the connecting client to rebuild an identical one. This
        // test FAILS on pre-fix code (callCount 2) and passes with the
        // _pendingPubkey guard (callCount 1).
        final gate = Completer<void>();
        factory.initializeCompleters[pubkeyA] = gate;
        when(() => mockAuth.currentIdentity).thenReturn(identityA);
        when(() => mockAuth.currentPublicKeyHex).thenReturn(pubkeyA);

        final container = createContainer();
        addTearDown(container.dispose);

        container.read(nostrServiceProvider);
        await pumpEventQueue(times: 1);
        expect(
          factory.callCount,
          equals(1),
          reason: 'build() creates one client for the known identity (Case A).',
        );
        expect(
          factory.initializePubkeys,
          contains(pubkeyA),
          reason: 'the build-path init is parked in flight (_lastPubkey null).',
        );

        // RPC-upgrade nudge: same pubkey re-emitted while relay connect is
        // still running.
        authStream.add(AuthState.authenticated);
        await pumpEventQueue(times: 1);
        await pumpEventQueue(times: 1);

        expect(
          factory.callCount,
          equals(1),
          reason:
              'a same-pubkey nudge during the in-flight init must NOT tear '
              'down and rebuild the connecting client (#5909).',
        );

        // Completing the gated init lets the ORIGINAL client reach ready.
        gate.complete();
        await pumpEventQueue(times: 1);
        await pumpEventQueue(times: 1);
        expect(factory.callCount, equals(1));
        expect(
          container.read(nostrSessionProvider).phase,
          equals(NostrSessionPhase.nostrReady),
        );
        expect(container.read(nostrSessionProvider).pubkey, equals(pubkeyA));
      },
    );

    test(
      'still recreates for a DIFFERENT pubkey that arrives while the '
      'build-path init is in flight (#5909 suppression is pubkey-scoped)',
      () async {
        final gate = Completer<void>();
        factory.initializeCompleters[pubkeyA] = gate;
        when(() => mockAuth.currentIdentity).thenReturn(identityA);
        when(() => mockAuth.currentPublicKeyHex).thenReturn(pubkeyA);

        final container = createContainer();
        addTearDown(container.dispose);

        container.read(nostrServiceProvider);
        await pumpEventQueue(times: 1);
        expect(factory.callCount, equals(1));

        // A genuine account switch to B while A's build init is in flight must
        // still recreate — the in-flight guard is scoped to the SAME pubkey.
        when(() => mockAuth.currentIdentity).thenReturn(identityB);
        when(() => mockAuth.currentPublicKeyHex).thenReturn(pubkeyB);
        authStream.add(AuthState.authenticated);
        await pumpEventQueue(times: 1);
        await pumpEventQueue(times: 1);

        expect(
          factory.callCount,
          equals(2),
          reason:
              'a different-pubkey emission must recreate even mid-init — the '
              '#5909 suppression is pubkey-scoped, not blanket.',
        );
        expect(factory.signers.last, same(identityB));

        // Drain the abandoned A init cleanly.
        gate.complete();
        await pumpEventQueue(times: 1);
      },
    );

    test(
      'failed initial build retries automatically for same identity',
      () async {
        final failedInitialAInitialize = Completer<void>();
        factory.initializeCompleters[pubkeyA] = failedInitialAInitialize;
        when(() => mockAuth.currentIdentity).thenReturn(identityA);
        when(() => mockAuth.currentPublicKeyHex).thenReturn(pubkeyA);

        final container = createRetryContainer();
        addTearDown(container.dispose);

        final failedClient = container.read(nostrServiceProvider);
        await pumpEventQueue(times: 1);
        expect(factory.callCount, equals(1));

        failedInitialAInitialize.completeError(
          StateError('initial A initialize failed'),
        );
        factory.initializeCompleters.remove(pubkeyA);
        await pumpEventQueue(times: 1);
        await pumpEventQueue(times: 1);
        await pumpEventQueue(times: 1);

        expect(
          factory.callCount,
          equals(2),
          reason:
              'The same authenticated identity should get a fresh NostrClient '
              'after the first startup initialize fails.',
        );
        expect(factory.signers.last, same(identityA));
        expect(factory.clients.last, isNot(same(failedClient)));
        verify(failedClient.dispose).called(1);
        expect(
          container.read(nostrServiceProvider),
          same(factory.clients.last),
        );
        expect(
          container.read(nostrSessionProvider),
          isA<NostrSessionReadiness>()
              .having(
                (readiness) => readiness.phase,
                'phase',
                NostrSessionPhase.nostrReady,
              )
              .having((readiness) => readiness.pubkey, 'pubkey', pubkeyA)
              .having(
                (readiness) => readiness.client,
                'client',
                same(factory.clients.last),
              ),
          reason:
              'Profile and publish providers gated on nostrReady must recover '
              'without requiring an app restart.',
        );
      },
    );

    test(
      'timed out startup relay setup retries automatically for same identity',
      () async {
        final stalledAddRelays = Completer<void>();
        factory.addRelaysCompleters[pubkeyA] = stalledAddRelays;
        when(() => mockAuth.currentIdentity).thenReturn(identityA);
        when(() => mockAuth.currentPublicKeyHex).thenReturn(pubkeyA);
        when(() => mockAuth.userRelays).thenReturn([discoveredRelay]);

        final container = createRetryContainer(
          initializationTimeout: Duration.zero,
        );
        addTearDown(container.dispose);

        final timedOutClient = container.read(nostrServiceProvider);
        factory.addRelaysCompleters.remove(pubkeyA);
        await pumpEventQueue(times: 1);
        await pumpEventQueue(times: 1);
        await pumpEventQueue(times: 1);

        expect(factory.callCount, equals(2));
        expect(factory.addRelaysPubkeys, equals([pubkeyA, pubkeyA]));
        expect(factory.initializePubkeys, equals([pubkeyA]));
        final testLogs = LogCaptureService().getRecentLogs();
        expect(
          testLogs.any(
            (entry) =>
                entry.message.contains('Failed to initialize client') &&
                entry.message.contains('stage=addingUserRelays'),
          ),
          isTrue,
          reason:
              'A remote log export must identify addRelays as the stalled '
              'startup stage.',
        );
        verify(timedOutClient.dispose).called(1);
        expect(
          container.read(nostrServiceProvider),
          same(factory.clients.last),
        );
        expect(
          container.read(nostrSessionProvider),
          isA<NostrSessionReadiness>()
              .having(
                (readiness) => readiness.phase,
                'phase',
                NostrSessionPhase.nostrReady,
              )
              .having((readiness) => readiness.pubkey, 'pubkey', pubkeyA)
              .having(
                (readiness) => readiness.client,
                'client',
                same(factory.clients.last),
              ),
        );
      },
    );

    test(
      'repeated initial failures preserve active client until retry succeeds',
      () async {
        final firstFailure = Completer<void>();
        final secondFailure = Completer<void>();
        factory.initializeCompleterQueues[pubkeyA] = [
          firstFailure,
          secondFailure,
        ];
        final retryAttempts = <int>[];
        when(() => mockAuth.currentIdentity).thenReturn(identityA);
        when(() => mockAuth.currentPublicKeyHex).thenReturn(pubkeyA);

        final container = createRetryContainer(
          retryDelay: (attempt) {
            retryAttempts.add(attempt);
            return Duration.zero;
          },
        );
        addTearDown(container.dispose);

        final initialClient = container.read(nostrServiceProvider);
        await pumpEventQueue(times: 1);
        expect(factory.callCount, equals(1));

        firstFailure.completeError(StateError('first initialize failed'));
        await pumpEventQueue(times: 1);
        await pumpEventQueue(times: 1);
        await pumpEventQueue(times: 1);

        expect(factory.callCount, equals(2));
        expect(
          container.read(nostrServiceProvider),
          same(initialClient),
          reason:
              'A retry candidate should not rebuild consumers until it is ready.',
        );

        secondFailure.completeError(StateError('second initialize failed'));
        await pumpEventQueue(times: 1);
        await pumpEventQueue(times: 1);
        await pumpEventQueue(times: 1);

        expect(factory.callCount, equals(3));
        expect(retryAttempts, equals([1, 2]));
        verify(initialClient.dispose).called(1);
        verify(factory.clients[1].dispose).called(1);
        expect(
          container.read(nostrServiceProvider),
          same(factory.clients.last),
        );
        expect(
          container.read(nostrSessionProvider).phase,
          equals(NostrSessionPhase.nostrReady),
        );
      },
    );

    test('auth change cancels pending initialization retry', () async {
      final failedInitialAInitialize = Completer<void>();
      factory.initializeCompleters[pubkeyA] = failedInitialAInitialize;
      when(() => mockAuth.currentIdentity).thenReturn(identityA);
      when(() => mockAuth.currentPublicKeyHex).thenReturn(pubkeyA);

      final container = createRetryContainer(
        retryDelay: (_) => const Duration(hours: 1),
      );
      addTearDown(container.dispose);

      container.read(nostrServiceProvider);
      await pumpEventQueue(times: 1);
      failedInitialAInitialize.completeError(
        StateError('initial A initialize failed'),
      );
      await pumpEventQueue(times: 1);
      await pumpEventQueue(times: 1);

      factory.initializeCompleters.remove(pubkeyA);
      when(() => mockAuth.currentIdentity).thenReturn(identityB);
      when(() => mockAuth.currentPublicKeyHex).thenReturn(pubkeyB);
      authStream.add(AuthState.authenticated);
      await pumpEventQueue(times: 1);
      await pumpEventQueue(times: 1);
      await pumpEventQueue(times: 1);

      expect(factory.callCount, equals(2));
      expect(factory.signers.last, same(identityB));
      expect(container.read(nostrServiceProvider), same(factory.clients.last));
      expect(
        container.read(nostrSessionProvider).pubkey,
        equals(pubkeyB),
      );
      expect(
        container.read(nostrSessionProvider).phase,
        equals(NostrSessionPhase.nostrReady),
      );
    });

    test('dispose cancels pending initialization retry', () async {
      final failedInitialAInitialize = Completer<void>();
      factory.initializeCompleters[pubkeyA] = failedInitialAInitialize;
      when(() => mockAuth.currentIdentity).thenReturn(identityA);
      when(() => mockAuth.currentPublicKeyHex).thenReturn(pubkeyA);

      final container = createRetryContainer(
        retryDelay: (_) => const Duration(hours: 1),
      );

      final failedClient = container.read(nostrServiceProvider);
      await pumpEventQueue(times: 1);
      failedInitialAInitialize.completeError(
        StateError('initial A initialize failed'),
      );
      await pumpEventQueue(times: 1);
      await pumpEventQueue(times: 1);

      container.dispose();
      await pumpEventQueue(times: 1);

      expect(factory.callCount, equals(1));
      verify(failedClient.dispose).called(1);
    });

    test(
      'stale build initialization cannot mark a disposed client ready',
      () async {
        final firstAInitialize = Completer<void>();
        factory.initializeCompleters[pubkeyA] = firstAInitialize;
        when(() => mockAuth.currentIdentity).thenReturn(identityA);
        when(() => mockAuth.currentPublicKeyHex).thenReturn(pubkeyA);

        final container = createContainer();
        addTearDown(container.dispose);

        final firstAClient = container.read(nostrServiceProvider);
        await pumpEventQueue(times: 1);

        when(() => mockAuth.currentIdentity).thenReturn(null);
        when(() => mockAuth.currentPublicKeyHex).thenReturn(null);
        authStream.add(AuthState.unauthenticated);
        await pumpEventQueue(times: 1);
        await pumpEventQueue(times: 1);

        factory.initializeCompleters.remove(pubkeyA);
        when(() => mockAuth.currentIdentity).thenReturn(identityA);
        when(() => mockAuth.currentPublicKeyHex).thenReturn(pubkeyA);
        authStream.add(AuthState.authenticated);
        await pumpEventQueue(times: 1);
        await pumpEventQueue(times: 1);
        await pumpEventQueue(times: 1);

        final currentAClient = container.read(nostrServiceProvider);
        expect(currentAClient, isNot(same(firstAClient)));
        expect(
          container.read(nostrSessionProvider).client,
          same(currentAClient),
        );

        firstAInitialize.complete();
        await pumpEventQueue(times: 1);
        await pumpEventQueue(times: 1);

        expect(
          container.read(nostrSessionProvider),
          isA<NostrSessionReadiness>()
              .having(
                (readiness) => readiness.phase,
                'phase',
                NostrSessionPhase.nostrReady,
              )
              .having((readiness) => readiness.pubkey, 'pubkey', pubkeyA)
              .having(
                (readiness) => readiness.client,
                'client',
                same(currentAClient),
              ),
          reason:
              'A disposed build client must not be able to overwrite readiness '
              'after a later client for the same pubkey is current.',
        );
      },
    );

    test(
      'stale initial placeholder completion cannot sign out a ready session',
      () async {
        final initialPlaceholderInitialize = Completer<void>();
        factory.initializeCompleters[null] = initialPlaceholderInitialize;

        final container = createContainer();
        addTearDown(container.dispose);

        container.read(nostrServiceProvider);
        await pumpEventQueue(times: 1);
        expect(factory.callCount, equals(1));
        expect(factory.signers.single, isNull);

        factory.initializeCompleters.remove(null);
        when(() => mockAuth.currentIdentity).thenReturn(identityA);
        when(() => mockAuth.currentPublicKeyHex).thenReturn(pubkeyA);
        authStream.add(AuthState.authenticated);
        await pumpEventQueue(times: 1);
        await pumpEventQueue(times: 1);
        await pumpEventQueue(times: 1);

        final readyClient = container.read(nostrServiceProvider);
        expect(
          container.read(nostrSessionProvider),
          isA<NostrSessionReadiness>()
              .having(
                (readiness) => readiness.phase,
                'phase',
                NostrSessionPhase.nostrReady,
              )
              .having((readiness) => readiness.pubkey, 'pubkey', pubkeyA)
              .having(
                (readiness) => readiness.client,
                'client',
                same(readyClient),
              ),
        );

        initialPlaceholderInitialize.complete();
        await pumpEventQueue(times: 1);
        await pumpEventQueue(times: 1);

        expect(
          container.read(nostrSessionProvider),
          isA<NostrSessionReadiness>()
              .having(
                (readiness) => readiness.phase,
                'phase',
                NostrSessionPhase.nostrReady,
              )
              .having((readiness) => readiness.pubkey, 'pubkey', pubkeyA)
              .having(
                (readiness) => readiness.client,
                'client',
                same(readyClient),
              ),
          reason:
              'A stale initial placeholder client must not overwrite a later '
              'ready authenticated session with signedOut.',
        );
      },
    );

    test(
      'stale relay discovery callback cannot add relays to old client',
      () async {
        UserRelaysDiscoveredCallback? latestRelayCallback;
        when(
          () => mockAuth.registerUserRelaysDiscoveredCallback(any()),
        ).thenAnswer((invocation) {
          latestRelayCallback =
              invocation.positionalArguments.single
                  as UserRelaysDiscoveredCallback?;
        });

        when(() => mockAuth.currentIdentity).thenReturn(identityA);
        when(() => mockAuth.currentPublicKeyHex).thenReturn(pubkeyA);

        final container = createContainer();
        addTearDown(container.dispose);

        final oldClient = container.read(nostrServiceProvider);
        await pumpEventQueue(times: 1);
        await pumpEventQueue(times: 1);
        final staleRelayCallback = latestRelayCallback!;

        when(() => mockAuth.currentIdentity).thenReturn(identityB);
        when(() => mockAuth.currentPublicKeyHex).thenReturn(pubkeyB);
        authStream.add(AuthState.authenticated);
        await pumpEventQueue(times: 1);
        await pumpEventQueue(times: 1);

        expect(container.read(nostrServiceProvider), isNot(same(oldClient)));

        const staleRelays = ['wss://stale-relay.example'];
        staleRelayCallback(pubkeyA, staleRelays);
        await pumpEventQueue(times: 1);
        await pumpEventQueue(times: 1);

        verifyNever(() => oldClient.addRelays(staleRelays));
      },
    );

    test(
      'session rebuild preserves ready state for the same identity',
      () async {
        when(() => mockAuth.currentIdentity).thenReturn(identityA);
        when(() => mockAuth.currentPublicKeyHex).thenReturn(pubkeyA);

        final container = createContainer();
        addTearDown(container.dispose);

        final client = container.read(nostrServiceProvider);
        await pumpEventQueue(times: 1);
        await pumpEventQueue(times: 1);

        expect(
          container.read(nostrSessionProvider),
          isA<NostrSessionReadiness>()
              .having(
                (readiness) => readiness.phase,
                'phase',
                NostrSessionPhase.nostrReady,
              )
              .having((readiness) => readiness.pubkey, 'pubkey', pubkeyA)
              .having((readiness) => readiness.client, 'client', same(client)),
        );

        container.invalidate(nostrSessionProvider);
        await pumpEventQueue(times: 1);

        expect(
          container.read(nostrSessionProvider),
          isA<NostrSessionReadiness>()
              .having(
                (readiness) => readiness.phase,
                'phase',
                NostrSessionPhase.nostrReady,
              )
              .having((readiness) => readiness.pubkey, 'pubkey', pubkeyA)
              .having((readiness) => readiness.client, 'client', same(client)),
          reason:
              'Rebuilding the session provider for the same identity must not '
              'downgrade the ready client back to identityKnown.',
        );
      },
    );
  });

  group('disposed-ref guard (#5602 / #5600 regression)', () {
    test(
      'does not touch ref when disposed before init microtask runs',
      () async {
        when(() => mockAuth.currentIdentity).thenReturn(identityA);

        final errors = <Object>[];
        await runZonedGuarded(
          () async {
            final container = createContainer();
            container.read(nostrServiceProvider);
            container.dispose();

            await pumpEventQueue(times: 1);
            await pumpEventQueue(times: 1);
          },
          (error, _) => errors.add(error),
        );

        expect(
          errors,
          isEmpty,
          reason:
              'a disposed-ref read leaked before the init try block: $errors',
        );
      },
    );

    test('does not touch ref after the container is disposed mid-init '
        '(success path)', () async {
      when(() => mockAuth.currentIdentity).thenReturn(identityA);

      // The leak under test is the fire-and-forgotten `Future.microtask` that
      // build() schedules for _initializeClient. An uncaught async error is
      // reported to the zone that was current when the future was *created*,
      // so container.read() (and the gating completer) must run inside this
      // guarded zone for the leak to land in [errors]. Without the ref.mounted
      // guard, the resumed _isCurrentClientForPubkey reads a disposed ref and
      // throws ("Cannot use the Ref ... after it has been disposed").
      final errors = <Object>[];
      await runZonedGuarded(
        () async {
          // Gate initialize() so _initializeClient parks on the await.
          factory.initializeCompleters[pubkeyA] = Completer<void>();

          final container = createContainer();
          container.read(nostrServiceProvider); // schedules _initializeClient

          // Let the scheduled microtask reach `await client.initialize()`.
          await pumpEventQueue(times: 1);
          expect(
            factory.initializePubkeys,
            contains(pubkeyA),
            reason:
                '_initializeClient must be parked on the gated initialize()',
          );

          // Dispose mid-init, then let init resume past the await.
          container.dispose();
          factory.initializeCompleters[pubkeyA]!.complete();
          await pumpEventQueue(times: 1);
          await pumpEventQueue(times: 1);
        },
        (error, _) => errors.add(error),
      );

      expect(
        errors,
        isEmpty,
        reason: 'a disposed-ref read leaked past the guard: $errors',
      );
    });

    test('does not touch ref after the container is disposed mid-init '
        '(error path)', () async {
      when(() => mockAuth.currentIdentity).thenReturn(identityA);

      // Same zone rule as the success path: container.read() runs inside the
      // guarded zone so the fire-and-forgotten init microtask reports any
      // leaked error into [errors]. The gating completer is created inside the
      // zone too, so the StateError used to fail init is owned by this zone and
      // not the outer flutter_test zone. Failing init mid-disposal drives
      // _initializeClient into its catch block; without the guard the catch
      // path's ref reads throw on the disposed provider.
      final errors = <Object>[];
      await runZonedGuarded(
        () async {
          factory.initializeCompleters[pubkeyA] = Completer<void>();

          final container = createContainer();
          container.read(nostrServiceProvider);

          await pumpEventQueue(times: 1);
          expect(factory.initializePubkeys, contains(pubkeyA));

          container.dispose();
          factory.initializeCompleters[pubkeyA]!.completeError(
            StateError('init failed'),
          );
          await pumpEventQueue(times: 1);
          await pumpEventQueue(times: 1);
        },
        (error, _) => errors.add(error),
      );

      expect(
        errors,
        isEmpty,
        reason: 'a disposed-ref read leaked past the guard: $errors',
      );
    });
  });
}
