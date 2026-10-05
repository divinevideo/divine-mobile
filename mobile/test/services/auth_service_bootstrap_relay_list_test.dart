// ABOUTME: Tests that AuthService self-publishes a bootstrap kind:10002
// ABOUTME: relay list when indexer discovery returns empty, so
// ABOUTME: Keycast-provisioned accounts become discoverable. #3174 / keycast#94.

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/services/auth/nostr_identity.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/background_activity_manager.dart';
import 'package:openvine/services/relay_discovery_service.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test_setup.dart';

class _MockUserDataCleanupService extends Mock
    implements UserDataCleanupService {}

class _MockNostrSigner extends Mock implements NostrSigner {}

/// Test double for [RelayDiscoveryService] that lets each test control the
/// discovery outcome without hitting real WebSockets.
class _ControllableRelayDiscoveryService extends RelayDiscoveryService {
  _ControllableRelayDiscoveryService({required this.outcome})
    : super(indexerRelays: const ['wss://test.invalid']);

  final RelayDiscoveryResult Function() outcome;

  @override
  Future<RelayDiscoveryResult> discoverRelays(String npub) async {
    return outcome();
  }
}

/// Records every bootstrap callback invocation so tests can assert on
/// payload, targets, and invocation count.
class _BootstrapCallbackRecorder {
  _BootstrapCallbackRecorder({required this.publishResult});

  final bool publishResult;
  final List<_BootstrapInvocation> invocations = [];

  Future<bool> call(Event event, List<String> targetRelays) async {
    invocations.add(
      _BootstrapInvocation(event: event, targetRelays: targetRelays),
    );
    return publishResult;
  }
}

class _BootstrapInvocation {
  _BootstrapInvocation({required this.event, required this.targetRelays});

  final Event event;
  final List<String> targetRelays;
}

void main() {
  setupTestEnvironment();

  const testNpub =
      'npub1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqsutm2dy';
  const testPubkeyHex =
      '0000000000000000000000000000000000000000000000000000000000000001';
  const flagKey =
      'bootstrap_kind10002_published_'
      '0000000000000000000000000000000000000000000000000000000000000001';

  setUpAll(() {
    registerFallbackValue(Event(testPubkeyHex, 0, const [], ''));
  });

  group('AuthService bootstrap kind:10002 (#3174)', () {
    late _MockUserDataCleanupService mockCleanupService;
    late _MockNostrSigner mockSigner;

    AuthService buildAuthService(
      _ControllableRelayDiscoveryService discovery, {
      NostrIdentity? identity,
      _BootstrapCallbackRecorder? recorder,
      String? primaryRelayUrl,
    }) {
      final authService = AuthService(
        backgroundActivityManager: BackgroundActivityManager(),
        userDataCleanupService: mockCleanupService,
        relayDiscoveryService: discovery,
        primaryRelayUrl: primaryRelayUrl,
      );
      if (identity != null) {
        authService.debugSetIdentity(identity);
      }
      if (recorder != null) {
        authService.registerBootstrapRelayListCallback(recorder.call);
      }
      return authService;
    }

    KeycastNostrIdentity buildIdentity() {
      // KeycastNostrIdentity is a concrete subtype of the sealed
      // NostrIdentity class, so tests can construct one directly while
      // controlling signing behavior via the mock rpcSigner.
      return KeycastNostrIdentity(pubkey: testPubkeyHex, rpcSigner: mockSigner);
    }

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockCleanupService = _MockUserDataCleanupService();
      mockSigner = _MockNostrSigner();
      // Default: signer succeeds by attaching a non-empty signature.
      when(() => mockSigner.signEvent(any())).thenAnswer((invocation) async {
        final event = invocation.positionalArguments[0] as Event;
        event.sig = 'a' * 128;
        return event;
      });
    });

    test(
      'publishes bootstrap kind:10002 when discovery returns empty',
      () async {
        final discovery = _ControllableRelayDiscoveryService(
          outcome: () => RelayDiscoveryResult.failure('No relay list found'),
        );
        final recorder = _BootstrapCallbackRecorder(publishResult: true);
        final authService = buildAuthService(
          discovery,
          identity: buildIdentity(),
          recorder: recorder,
        );

        final beforeCall = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        await authService.debugDiscoverUserRelays(testNpub);
        final afterCall = DateTime.now().millisecondsSinceEpoch ~/ 1000;

        expect(recorder.invocations, hasLength(1));
        final invocation = recorder.invocations.single;

        // Event payload is a valid NIP-65 kind:10002 pointing at Divine relay.
        expect(invocation.event.kind, equals(EventKind.relayListMetadata));
        expect(invocation.event.pubkey, equals(testPubkeyHex));
        expect(
          invocation.event.tags,
          equals([
            ['r', AppConstants.defaultRelayUrl],
          ]),
        );
        expect(invocation.event.sig, isNotEmpty);
        // NIP-65 consumers replace strictly by created_at, so a stale or
        // zero timestamp would let a later real publish be silently ignored.
        expect(invocation.event.createdAt, greaterThanOrEqualTo(beforeCall));
        expect(invocation.event.createdAt, lessThanOrEqualTo(afterCall));

        // Target relays include Divine relay + the three indexers.
        expect(
          invocation.targetRelays,
          equals([
            AppConstants.defaultRelayUrl,
            ...IndexerRelayConfig.defaultIndexers,
          ]),
        );

        // Flag is set so subsequent logins skip the bootstrap.
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool(flagKey), isTrue);
      },
    );

    test('also publishes when discovery throws (catch branch)', () async {
      final discovery = _ControllableRelayDiscoveryService(
        outcome: () => throw Exception('connection refused'),
      );
      final recorder = _BootstrapCallbackRecorder(publishResult: true);
      final authService = buildAuthService(
        discovery,
        identity: buildIdentity(),
        recorder: recorder,
      );

      await authService.debugDiscoverUserRelays(testNpub);

      expect(recorder.invocations, hasLength(1));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(flagKey), isTrue);
    });

    test(
      "does NOT publish when discovery returns the user's real relay list",
      () async {
        final discovery = _ControllableRelayDiscoveryService(
          outcome: () => RelayDiscoveryResult.success([
            const DiscoveredRelay(url: 'wss://relay.example.com'),
          ], 'wss://test-indexer'),
        );
        final recorder = _BootstrapCallbackRecorder(publishResult: true);
        final authService = buildAuthService(
          discovery,
          identity: buildIdentity(),
          recorder: recorder,
        );

        await authService.debugDiscoverUserRelays(testNpub);

        expect(recorder.invocations, isEmpty);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool(flagKey) ?? false, isFalse);
      },
    );

    test('does NOT publish twice when flag is already set', () async {
      SharedPreferences.setMockInitialValues({flagKey: true});

      final discovery = _ControllableRelayDiscoveryService(
        outcome: () => RelayDiscoveryResult.failure('No relay list found'),
      );
      final recorder = _BootstrapCallbackRecorder(publishResult: true);
      final authService = buildAuthService(
        discovery,
        identity: buildIdentity(),
        recorder: recorder,
      );

      await authService.debugDiscoverUserRelays(testNpub);

      expect(recorder.invocations, isEmpty);
    });

    test('does NOT publish when no identity is set', () async {
      final discovery = _ControllableRelayDiscoveryService(
        outcome: () => RelayDiscoveryResult.failure('No relay list found'),
      );
      final recorder = _BootstrapCallbackRecorder(publishResult: true);
      // No identity passed — simulates unauthenticated / read-only session.
      final authService = buildAuthService(discovery, recorder: recorder);

      await authService.debugDiscoverUserRelays(testNpub);

      expect(recorder.invocations, isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(flagKey) ?? false, isFalse);
    });

    test('does NOT publish when no callback is registered', () async {
      final discovery = _ControllableRelayDiscoveryService(
        outcome: () => RelayDiscoveryResult.failure('No relay list found'),
      );
      // No recorder passed — simulates window where AuthService runs
      // discovery before NostrService registers the callback.
      final authService = buildAuthService(
        discovery,
        identity: buildIdentity(),
      );

      await authService.debugDiscoverUserRelays(testNpub);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(flagKey) ?? false, isFalse);
    });

    test(
      'flag is NOT set when signer returns null (retriable next login)',
      () async {
        when(() => mockSigner.signEvent(any())).thenAnswer((_) async => null);

        final discovery = _ControllableRelayDiscoveryService(
          outcome: () => RelayDiscoveryResult.failure('No relay list found'),
        );
        final recorder = _BootstrapCallbackRecorder(publishResult: true);
        final authService = buildAuthService(
          discovery,
          identity: buildIdentity(),
          recorder: recorder,
        );

        await authService.debugDiscoverUserRelays(testNpub);

        // Signer failed → callback never invoked → flag not set.
        expect(recorder.invocations, isEmpty);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool(flagKey) ?? false, isFalse);
      },
    );

    test('flag is NOT set when callback reports publish failure', () async {
      final discovery = _ControllableRelayDiscoveryService(
        outcome: () => RelayDiscoveryResult.failure('No relay list found'),
      );
      final recorder = _BootstrapCallbackRecorder(publishResult: false);
      final authService = buildAuthService(
        discovery,
        identity: buildIdentity(),
        recorder: recorder,
      );

      await authService.debugDiscoverUserRelays(testNpub);

      // Callback was invoked (we tried), but publish returned false so
      // the flag stays unset and the next login will retry.
      expect(recorder.invocations, hasLength(1));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(flagKey) ?? false, isFalse);
    });

    test('flag is NOT set when callback throws', () async {
      final discovery = _ControllableRelayDiscoveryService(
        outcome: () => RelayDiscoveryResult.failure('No relay list found'),
      );
      Future<bool> throwingCallback(Event _, List<String> _) async =>
          throw Exception('publish broke');

      final authService = AuthService(
        backgroundActivityManager: BackgroundActivityManager(),
        userDataCleanupService: mockCleanupService,
        relayDiscoveryService: discovery,
      );
      authService.debugSetIdentity(buildIdentity());
      authService.registerBootstrapRelayListCallback(throwingCallback);

      // Should not throw — AuthService swallows the exception.
      await authService.debugDiscoverUserRelays(testNpub);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(flagKey) ?? false, isFalse);
    });

    test(
      'flag is NOT set when signer hangs past timeout (retriable next login)',
      () {
        // Simulate a hung Keycast/Amber signer that never completes.
        when(
          () => mockSigner.signEvent(any()),
        ).thenAnswer((_) => Completer<Event?>().future);

        fakeAsync((async) {
          final discovery = _ControllableRelayDiscoveryService(
            outcome: () => RelayDiscoveryResult.failure('No relay list found'),
          );
          final recorder = _BootstrapCallbackRecorder(publishResult: true);
          final authService = buildAuthService(
            discovery,
            identity: buildIdentity(),
            recorder: recorder,
          );

          // Launch the operation (signer hangs forever). Only the sign
          // timeout can complete it, so completion is asserted below.
          var discoveryCompleted = false;
          unawaited(
            authService
                .debugDiscoverUserRelays(testNpub)
                .then((_) => discoveryCompleted = true),
          );

          // Just short of the 10s bootstrap sign timeout, the hung signer
          // still holds discovery open.
          async.elapse(const Duration(seconds: 9));
          expect(discoveryCompleted, isFalse);

          // Drive just past the 10s bootstrap sign timeout.
          async.elapse(const Duration(seconds: 2));
          async.flushMicrotasks();

          // Signer timed out → discovery finished without invoking the
          // callback → flag not set.
          verify(() => mockSigner.signEvent(any())).called(1);
          expect(discoveryCompleted, isTrue);
          expect(recorder.invocations, isEmpty);

          late bool flagValue;
          unawaited(
            SharedPreferences.getInstance().then((prefs) {
              flagValue = prefs.getBool(flagKey) ?? false;
            }),
          );
          async.flushMicrotasks();
          expect(flagValue, isFalse);
        });
      },
    );

    test(
      'uses injected primaryRelayUrl in r tag and target relay list (#3183)',
      () async {
        const stagingRelayUrl = 'wss://relay.staging.divine.video';

        final discovery = _ControllableRelayDiscoveryService(
          outcome: () => RelayDiscoveryResult.failure('No relay list found'),
        );
        final recorder = _BootstrapCallbackRecorder(publishResult: true);
        final authService = buildAuthService(
          discovery,
          identity: buildIdentity(),
          recorder: recorder,
          primaryRelayUrl: stagingRelayUrl,
        );

        await authService.debugDiscoverUserRelays(testNpub);

        expect(recorder.invocations, hasLength(1));
        final invocation = recorder.invocations.single;

        // Event r tag points at the injected (non-prod) relay.
        expect(
          invocation.event.tags,
          equals([
            ['r', stagingRelayUrl],
          ]),
        );
        // Target-relay list leads with the injected relay, not the prod
        // default — prevents non-prod builds from advertising prod relay to
        // public indexers. See #3183.
        expect(
          invocation.targetRelays,
          equals([stagingRelayUrl, ...IndexerRelayConfig.defaultIndexers]),
        );
        expect(
          invocation.targetRelays,
          isNot(contains(AppConstants.defaultRelayUrl)),
        );
      },
    );
  });
}
