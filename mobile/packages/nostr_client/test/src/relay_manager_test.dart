// Not required for test files
// ignore_for_file: prefer_const_constructors

import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_client/src/relay_diagnostics_adapter.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:nostr_sdk/relay/client_connected.dart';
import 'package:test/test.dart';
import 'package:unified_logger/unified_logger.dart';

class _MockRelayPool extends Mock implements RelayPool {}

class _MockRelay extends Mock implements Relay {}

class _MockRelayBase extends Mock implements RelayBase {}

class _MockRelayStatus extends Mock implements RelayStatus {}

class _MockRelayStorage extends Mock implements RelayStorage {}

class _FakeRelay extends Fake implements Relay {
  _FakeRelay(this.url);

  @override
  final String url;

  @override
  RelayStatus relayStatus = RelayStatus('wss://fake.example.com');
}

const testDefaultRelayUrl = 'wss://relay.default.com';
const testCustomRelayUrl = 'wss://relay.custom.com';
const testCustomRelayUrl2 = 'wss://relay.custom2.com';

RelayManagerConfig _createTestConfig({
  String? defaultRelayUrl,
  RelayStorage? storage,
  bool autoReconnect = true,
  String? allowedRelayHost,
}) {
  return RelayManagerConfig(
    defaultRelayUrl: defaultRelayUrl ?? testDefaultRelayUrl,
    storage: storage,
    autoReconnect: autoReconnect,
    allowedRelayHost: allowedRelayHost,
  );
}

_MockRelay _createMockRelay(
  String url, {
  bool connected = true,
  bool authed = false,
}) {
  final mockRelay = _MockRelay();
  final mockStatus = _MockRelayStatus();

  when(() => mockRelay.url).thenReturn(url);
  when(() => mockRelay.relayStatus).thenReturn(mockStatus);
  when(() => mockStatus.connected).thenReturn(
    connected ? ClientConnected.connected : ClientConnected.disconnect,
  );
  when(() => mockStatus.authed).thenReturn(authed);

  return mockRelay;
}

/// A pooled relay whose socket reports [connected] and whose idle check
/// returns [healthy].
_MockRelayBase _createPooledRelay(
  String url, {
  required int connected,
  required bool healthy,
}) {
  final relay = _MockRelayBase();
  final status = _MockRelayStatus();
  when(() => relay.url).thenReturn(url);
  when(() => relay.relayStatus).thenReturn(status);
  when(() => status.connected).thenReturn(connected);
  when(relay.checkHealth).thenReturn(healthy);
  return relay;
}

// =============================================================================
// Tests
// =============================================================================

void main() {
  late _MockRelayPool mockRelayPool;
  late _MockRelayStorage mockStorage;
  late RelayManagerConfig config;
  late RelayManager manager;

  setUpAll(() {
    registerFallbackValue(_FakeRelay('wss://fake.example.com'));
  });

  setUp(() {
    mockRelayPool = _MockRelayPool();
    mockStorage = _MockRelayStorage();
    config = _createTestConfig();

    // Set up default mock behavior
    when(() => mockRelayPool.activeRelays()).thenReturn([]);
    when(() => mockRelayPool.getRelay(any())).thenReturn(null);
    when(
      () =>
          mockRelayPool.add(any(), autoSubscribe: any(named: 'autoSubscribe')),
    ).thenAnswer((_) async => true);
    when(() => mockRelayPool.remove(any())).thenReturn(null);
    when(() => mockStorage.loadRemovedRelays()).thenAnswer((_) async => []);
    when(() => mockStorage.saveRemovedRelays(any())).thenAnswer((_) async {});

    manager = RelayManager(config: config, relayPool: mockRelayPool);
  });

  tearDown(() {
    reset(mockRelayPool);
    reset(mockStorage);
  });

  group('RelayManager', () {
    group('diagnostics', () {
      test(
        'reports a throwing connection without exporting its message',
        () async {
          final diagnostics = <RelayDiagnostic>[];
          when(
            () => mockRelayPool.add(
              any(),
              autoSubscribe: any(named: 'autoSubscribe'),
            ),
          ).thenThrow(FormatException('private relay failure detail'));
          final diagnosticManager = RelayManager(
            config: config,
            relayPool: mockRelayPool,
            diagnosticsSink: diagnostics.add,
          );

          await diagnosticManager.initialize();

          final failure = diagnostics.singleWhere(
            (entry) => entry.level == RelayDiagnosticLevel.error,
          );
          expect(failure.relayUrl, testDefaultRelayUrl);
          expect(failure.message, 'Relay connection threw');
          expect(
            failure.message,
            isNot(contains('private relay failure detail')),
          );
          expect(failure.error, isA<FormatException>());
        },
      );

      test('pool chatter cannot suppress a per-relay failure', () async {
        final capture = LogCaptureService();
        await capture.clearAllLogs();
        addTearDown(capture.clearAllLogs);
        final adapter = RelayDiagnosticsAdapter(maxEventsPerWindow: 1);
        when(
          () => mockRelayPool.add(
            any(),
            autoSubscribe: any(named: 'autoSubscribe'),
          ),
        ).thenAnswer((_) async => false);
        final diagnosticManager = RelayManager(
          config: config,
          relayPool: mockRelayPool,
          diagnosticsSink: adapter.call,
        );

        await diagnosticManager.initialize();

        final entries = capture.getRecentLogs();
        expect(
          entries.where(
            (entry) =>
                entry.message.contains(testDefaultRelayUrl) &&
                entry.message.contains('Connect failed'),
          ),
          hasLength(1),
        );
        expect(
          entries
              .singleWhere(
                (entry) => entry.message.contains('Connect failed'),
              )
              .level,
          LogLevel.warning,
        );
      });
    });

    group('constructor and properties', () {
      test('defaultRelayUrl returns configured default relay', () {
        expect(manager.defaultRelayUrl, equals(testDefaultRelayUrl));
      });

      test('isInitialized returns false before initialization', () {
        expect(manager.isInitialized, isFalse);
      });

      test('configuredRelays is empty before initialization', () {
        expect(manager.configuredRelays, isEmpty);
      });

      test('connectedRelays is empty before initialization', () {
        expect(manager.connectedRelays, isEmpty);
      });

      test('configuredRelayCount is 0 before initialization', () {
        expect(manager.configuredRelayCount, equals(0));
      });

      test('connectedRelayCount is 0 before initialization', () {
        expect(manager.connectedRelayCount, equals(0));
      });

      test('hasConnectedRelay is false before initialization', () {
        expect(manager.hasConnectedRelay, isFalse);
      });

      test('currentStatuses is empty before initialization', () {
        expect(manager.currentStatuses, isEmpty);
      });
    });

    group('initialize', () {
      test('initializes with default relay when no storage', () async {
        await manager.initialize();

        expect(manager.isInitialized, isTrue);
        expect(manager.configuredRelays, contains(testDefaultRelayUrl));
        expect(manager.configuredRelayCount, equals(1));
      });

      test('loads relays from storage during initialization', () async {
        when(
          () => mockStorage.loadRelays(),
        ).thenAnswer((_) async => [testCustomRelayUrl]);
        when(() => mockStorage.saveRelays(any())).thenAnswer((_) async {});

        final configWithStorage = _createTestConfig(storage: mockStorage);
        final managerWithStorage = RelayManager(
          config: configWithStorage,
          relayPool: mockRelayPool,
        );

        await managerWithStorage.initialize();

        expect(
          managerWithStorage.configuredRelays,
          contains(testCustomRelayUrl),
        );
        expect(
          managerWithStorage.configuredRelays,
          contains(testDefaultRelayUrl),
        );
        verify(() => mockStorage.loadRelays()).called(1);
      });

      test('ensures default relay is always included', () async {
        when(
          () => mockStorage.loadRelays(),
        ).thenAnswer((_) async => [testCustomRelayUrl]);
        when(() => mockStorage.saveRelays(any())).thenAnswer((_) async {});

        final configWithStorage = _createTestConfig(storage: mockStorage);
        final managerWithStorage = RelayManager(
          config: configWithStorage,
          relayPool: mockRelayPool,
        );

        await managerWithStorage.initialize();

        expect(
          managerWithStorage.configuredRelays.first,
          equals(testDefaultRelayUrl),
        );
      });

      test('does not reinitialize if already initialized', () async {
        await manager.initialize();
        await manager.initialize();

        // Should only add relay once
        verify(
          () => mockRelayPool.add(
            any(),
            autoSubscribe: any(named: 'autoSubscribe'),
          ),
        ).called(1);
      });

      test('connects to all configured relays', () async {
        when(
          () => mockStorage.loadRelays(),
        ).thenAnswer((_) async => [testCustomRelayUrl, testCustomRelayUrl2]);
        when(() => mockStorage.saveRelays(any())).thenAnswer((_) async {});

        final configWithStorage = _createTestConfig(storage: mockStorage);
        final managerWithStorage = RelayManager(
          config: configWithStorage,
          relayPool: mockRelayPool,
        );

        await managerWithStorage.initialize();

        // Should connect to default + 2 custom relays
        verify(
          () => mockRelayPool.add(
            any(),
            autoSubscribe: any(named: 'autoSubscribe'),
          ),
        ).called(3);
      });

      test(
        'persists filtered list when storage contains insecure URLs (#3362)',
        () async {
          when(() => mockStorage.loadRelays()).thenAnswer(
            (_) async => [testCustomRelayUrl, 'ws://attacker.example.com'],
          );
          when(() => mockStorage.saveRelays(any())).thenAnswer((_) async {});

          final managerWithStorage = RelayManager(
            config: _createTestConfig(storage: mockStorage),
            relayPool: mockRelayPool,
          );

          await managerWithStorage.initialize();

          // The insecure URL must be dropped from the in-memory list AND
          // re-saved to storage so it does not reappear on the next launch.
          expect(
            managerWithStorage.configuredRelays,
            contains(testCustomRelayUrl),
          );
          expect(
            managerWithStorage.configuredRelays,
            isNot(contains('ws://attacker.example.com')),
          );

          final captured =
              verify(() => mockStorage.saveRelays(captureAny())).captured.last
                  as List<String>;
          expect(captured, contains(testCustomRelayUrl));
          expect(captured, isNot(contains('ws://attacker.example.com')));
        },
      );

      test('initializes status for all configured relays', () async {
        await manager.initialize();

        final status = manager.getRelayStatus(testDefaultRelayUrl);
        expect(status, isNotNull);
        expect(status!.url, equals(testDefaultRelayUrl));
        expect(status.isDefault, isTrue);
      });

      test('emits status update after initialization', () async {
        final statusUpdates = <Map<String, RelayConnectionStatus>>[];
        manager.statusStream.listen(statusUpdates.add);

        await manager.initialize();
        await Future<void>.delayed(Duration.zero);

        expect(statusUpdates, isNotEmpty);
      });
    });

    group('addRelay', () {
      setUp(() async {
        await manager.initialize();
      });

      test('adds relay to configured list', () async {
        final result = await manager.addRelay(testCustomRelayUrl);

        expect(result, isTrue);
        expect(manager.configuredRelays, contains(testCustomRelayUrl));
      });

      test('connects to the relay via RelayPool', () async {
        await manager.addRelay(testCustomRelayUrl);

        verify(
          () => mockRelayPool.add(
            any(),
            autoSubscribe: any(named: 'autoSubscribe'),
          ),
        ).called(greaterThan(1));
      });

      test('returns false for empty URL', () async {
        final result = await manager.addRelay('');

        expect(result, isFalse);
      });

      test('returns false for URL with only spaces', () async {
        final result = await manager.addRelay('   ');

        expect(result, isFalse);
      });

      test('returns false for already configured relay', () async {
        await manager.addRelay(testCustomRelayUrl);
        final result = await manager.addRelay(testCustomRelayUrl);

        expect(result, isFalse);
      });

      test('normalizes URL by adding wss:// prefix', () async {
        await manager.addRelay('relay.example.com');

        expect(manager.configuredRelays, contains('wss://relay.example.com'));
      });

      test('normalizes URL by removing trailing slash', () async {
        await manager.addRelay('wss://relay.example.com/');

        expect(manager.configuredRelays, contains('wss://relay.example.com'));
      });

      test('saves configuration after adding relay', () async {
        when(() => mockStorage.loadRelays()).thenAnswer((_) async => []);
        when(() => mockStorage.saveRelays(any())).thenAnswer((_) async {});
        when(() => mockStorage.loadRemovedRelays()).thenAnswer((_) async => []);
        when(
          () => mockStorage.saveRemovedRelays(any()),
        ).thenAnswer((_) async {});

        final configWithStorage = _createTestConfig(storage: mockStorage);
        final managerWithStorage = RelayManager(
          config: configWithStorage,
          relayPool: mockRelayPool,
        );

        await managerWithStorage.initialize();
        await managerWithStorage.addRelay(testCustomRelayUrl);

        verify(() => mockStorage.saveRelays(any())).called(1);
      });

      test('skips automatic add for a user-removed relay', () async {
        final storage = InMemoryRelayStorage([], [testCustomRelayUrl]);
        final managerWithStorage = RelayManager(
          config: _createTestConfig(storage: storage),
          relayPool: mockRelayPool,
        );

        await managerWithStorage.initialize();
        clearInteractions(mockRelayPool);
        final result = await managerWithStorage.addRelay(testCustomRelayUrl);

        expect(result, isFalse);
        expect(
          managerWithStorage.configuredRelays,
          isNot(contains(testCustomRelayUrl)),
        );
        verifyNever(
          () => mockRelayPool.add(
            any(),
            autoSubscribe: any(named: 'autoSubscribe'),
          ),
        );
      });

      test('reports whether a relay is user-removed', () async {
        final storage = InMemoryRelayStorage([], [testCustomRelayUrl]);
        final managerWithStorage = RelayManager(
          config: _createTestConfig(storage: storage),
          relayPool: mockRelayPool,
        );

        expect(
          await managerWithStorage.isUserRemovedRelay(testCustomRelayUrl),
          isTrue,
        );
        expect(
          await managerWithStorage.isUserRemovedRelay(testCustomRelayUrl2),
          isFalse,
        );
      });

      test('user add clears removed relay ledger and succeeds', () async {
        final storage = InMemoryRelayStorage([], [testCustomRelayUrl]);
        final managerWithStorage = RelayManager(
          config: _createTestConfig(storage: storage),
          relayPool: mockRelayPool,
        );

        await managerWithStorage.initialize();
        final result = await managerWithStorage.addRelay(
          testCustomRelayUrl,
          source: RelayAddSource.user,
        );

        expect(result, isTrue);
        expect(
          managerWithStorage.configuredRelays,
          contains(testCustomRelayUrl),
        );
        expect(await storage.loadRemovedRelays(), isEmpty);
      });

      test('updates status to connected on success', () async {
        when(
          () => mockRelayPool.add(
            any(),
            autoSubscribe: any(named: 'autoSubscribe'),
          ),
        ).thenAnswer((_) async => true);

        await manager.addRelay(testCustomRelayUrl);

        final status = manager.getRelayStatus(testCustomRelayUrl);
        expect(status?.state, equals(RelayState.connected));
      });

      test('updates status to error on failure', () async {
        when(
          () => mockRelayPool.add(
            any(),
            autoSubscribe: any(named: 'autoSubscribe'),
          ),
        ).thenAnswer((_) async => false);

        await manager.addRelay(testCustomRelayUrl);

        final status = manager.getRelayStatus(testCustomRelayUrl);
        expect(status?.state, equals(RelayState.error));
      });

      test('emits status update when relay is added', () async {
        final statusUpdates = <Map<String, RelayConnectionStatus>>[];
        manager.statusStream.listen(statusUpdates.add);

        await manager.addRelay(testCustomRelayUrl);
        await Future<void>.delayed(Duration.zero);

        expect(statusUpdates.length, greaterThan(0));
      });

      // Insecure URL gating (#3362)
      test('rejects ws:// to non-loopback host', () async {
        final result = await manager.addRelay('ws://attacker.example.com');

        expect(result, isFalse);
        expect(
          manager.configuredRelays,
          isNot(contains('ws://attacker.example.com')),
        );
        // The attacker URL must never hit the relay pool, even though
        // initialize() legitimately added the default relay.
        verifyNever(
          () => mockRelayPool.add(
            any(
              that: predicate<Relay>(
                (r) => r.url.contains('attacker.example.com'),
              ),
            ),
            autoSubscribe: any(named: 'autoSubscribe'),
          ),
        );
      });

      test('rejects ws:// suffix-match attack on localhost', () async {
        final result = await manager.addRelay('ws://localhost.attacker.com');

        expect(result, isFalse);
      });

      test('accepts ws://localhost', () async {
        final result = await manager.addRelay('ws://localhost:47777');

        expect(result, isTrue);
        expect(manager.configuredRelays, contains('ws://localhost:47777'));
      });

      test('accepts ws://10.0.2.2 (Android emulator host)', () async {
        final result = await manager.addRelay('ws://10.0.2.2:47777');

        expect(result, isTrue);
        expect(manager.configuredRelays, contains('ws://10.0.2.2:47777'));
      });

      test('canonical loopback set (#3362 drift sentinel)', () async {
        // Mirrored in:
        //  - mobile/test/utils/relay_url_utils_test.dart
        //  - mobile/packages/nostr_sdk/test/unit/nostr_remote_signer_info_test.dart
        // and `mobile/android/app/src/main/res/xml/network_security_config.xml`.
        // Diverging this set without updating the others is a security
        // regression.
        const loopbackUrls = [
          'ws://localhost:1',
          'ws://127.0.0.1:2',
          'ws://10.0.2.2:3',
          'ws://[::1]:4',
        ];
        for (final url in loopbackUrls) {
          final result = await manager.addRelay(url);
          expect(result, isTrue, reason: '$url should be accepted');
          expect(manager.configuredRelays, contains(url));
        }
      });

      // Scheme validation before bare-host upgrade (#3362 review follow-up).
      // Without this gate, `normalizeRelayUrl` would string-prefix `wss://` onto
      // any input not already starting with `wss://`/`ws://`, turning
      // `http://attacker.example.com` into `wss://http://attacker.example.com`
      // (host=`http`, path=`//attacker…` — the wrong target).
      test('rejects http:// even with a non-loopback host', () async {
        final result = await manager.addRelay('http://attacker.example.com');

        expect(result, isFalse);
        expect(
          manager.configuredRelays,
          isNot(
            contains(
              anyOf(
                'http://attacker.example.com',
                'wss://http://attacker.example.com',
              ),
            ),
          ),
        );
        verifyNever(
          () => mockRelayPool.add(
            any(
              that: predicate<Relay>(
                (r) => r.url.contains('attacker.example.com'),
              ),
            ),
            autoSubscribe: any(named: 'autoSubscribe'),
          ),
        );
      });

      test(
        'rejects https:// even when pointed at a relay-shaped host',
        () async {
          final result = await manager.addRelay('https://relay.example.com');

          expect(result, isFalse);
        },
      );

      test('rejects http:// pointed at a loopback host', () async {
        // Relays speak WebSocket only; cleartext HTTP to localhost is still
        // not a relay endpoint.
        final result = await manager.addRelay('http://localhost:47777');

        expect(result, isFalse);
      });

      test('rejects ftp:// and other unknown schemes', () async {
        expect(await manager.addRelay('ftp://relay.example.com'), isFalse);
        expect(await manager.addRelay('file:///etc/hosts'), isFalse);
      });

      test('rejects mis-nested wss://http:// (smuggled cleartext)', () async {
        // Without the `path.startsWith('//')` guard, this URL parses with
        // host=`http` and path=`//attacker…` and would be accepted as
        // scheme=`wss` — routing the connection to host `http` rather
        // than rejecting the malformed input.
        final result = await manager.addRelay(
          'wss://http://attacker.example.com',
        );

        expect(result, isFalse);
        verifyNever(
          () => mockRelayPool.add(
            any(
              that: predicate<Relay>(
                (r) => r.url.contains('attacker.example.com'),
              ),
            ),
            autoSubscribe: any(named: 'autoSubscribe'),
          ),
        );
      });

      test('rejects mis-nested wss://wss:// (double scheme prefix)', () async {
        final result = await manager.addRelay('wss://wss://relay.example.com');

        expect(result, isFalse);
      });

      test('case-folds uppercase scheme to canonical lowercase', () async {
        // Discovery accepts `WSS://relay.example.com` because Dart's Uri
        // canonicalises the scheme to lowercase. `normalizeRelayUrl` must do
        // the same so the URL is stored in canonical form and string-based
        // dedup / persistence checks compare equal across casings.
        final result = await manager.addRelay('WSS://relay.example.com');

        expect(result, isTrue);
        expect(manager.configuredRelays, contains('wss://relay.example.com'));
        expect(
          manager.configuredRelays,
          isNot(contains('WSS://relay.example.com')),
        );
      });

      test('case-folds uppercase ws:// scheme for loopback hosts', () async {
        final result = await manager.addRelay('WS://localhost:8080');

        expect(result, isTrue);
        expect(manager.configuredRelays, contains('ws://localhost:8080'));
      });

      test('emits both connecting and final connected state', () async {
        final statusUpdates = <Map<String, RelayConnectionStatus>>[];
        manager.statusStream.listen(statusUpdates.add);

        await manager.addRelay(testCustomRelayUrl);
        await Future<void>.delayed(Duration.zero);

        // Should have at least 2 emissions: connecting and connected
        expect(statusUpdates.length, greaterThanOrEqualTo(2));

        // First emission should show connecting state
        final firstUpdate = statusUpdates.first;
        expect(
          firstUpdate[testCustomRelayUrl]?.state,
          equals(RelayState.connecting),
        );

        // Last emission should show connected state
        final lastUpdate = statusUpdates.last;
        expect(
          lastUpdate[testCustomRelayUrl]?.state,
          equals(RelayState.connected),
        );
      });

      test('emits both connecting and final error state on failure', () async {
        when(
          () => mockRelayPool.add(
            any(),
            autoSubscribe: any(named: 'autoSubscribe'),
          ),
        ).thenAnswer((_) async => false);

        final statusUpdates = <Map<String, RelayConnectionStatus>>[];
        manager.statusStream.listen(statusUpdates.add);

        await manager.addRelay(testCustomRelayUrl);
        await Future<void>.delayed(Duration.zero);

        // Should have at least 2 emissions: connecting and error
        expect(statusUpdates.length, greaterThanOrEqualTo(2));

        // First emission should show connecting state
        final firstUpdate = statusUpdates.first;
        expect(
          firstUpdate[testCustomRelayUrl]?.state,
          equals(RelayState.connecting),
        );

        // Last emission should show error state
        final lastUpdate = statusUpdates.last;
        expect(lastUpdate[testCustomRelayUrl]?.state, equals(RelayState.error));
      });
    });

    group('removeRelay', () {
      setUp(() async {
        await manager.initialize();
        await manager.addRelay(testCustomRelayUrl);
      });

      test('removes relay from configured list', () async {
        final result = await manager.removeRelay(
          testCustomRelayUrl,
          source: RelayRemoveSource.user,
        );

        expect(result, isTrue);
        expect(manager.configuredRelays, isNot(contains(testCustomRelayUrl)));
      });

      test('disconnects from the relay via RelayPool', () async {
        clearInteractions(mockRelayPool);
        await manager.removeRelay(
          testCustomRelayUrl,
          source: RelayRemoveSource.user,
        );

        verify(() => mockRelayPool.remove(testCustomRelayUrl)).called(1);
      });

      test('allows removing default relay', () async {
        final result = await manager.removeRelay(
          testDefaultRelayUrl,
          source: RelayRemoveSource.user,
        );

        expect(result, isTrue);
        expect(manager.configuredRelays, isNot(contains(testDefaultRelayUrl)));
      });

      test('returns false for non-configured relay', () async {
        final result = await manager.removeRelay(
          'wss://unknown.relay.com',
          source: RelayRemoveSource.user,
        );

        expect(result, isFalse);
      });

      test('returns false for invalid URL', () async {
        final result = await manager.removeRelay(
          'invalid-url',
          source: RelayRemoveSource.user,
        );

        expect(result, isFalse);
      });

      test('removes status entry for relay', () async {
        await manager.removeRelay(
          testCustomRelayUrl,
          source: RelayRemoveSource.user,
        );

        final status = manager.getRelayStatus(testCustomRelayUrl);
        expect(status, isNull);
      });

      test('saves configuration after removing relay', () async {
        when(() => mockStorage.loadRelays()).thenAnswer((_) async => []);
        when(() => mockStorage.saveRelays(any())).thenAnswer((_) async {});
        when(() => mockStorage.loadRemovedRelays()).thenAnswer((_) async => []);
        when(
          () => mockStorage.saveRemovedRelays(any()),
        ).thenAnswer((_) async {});

        final configWithStorage = _createTestConfig(storage: mockStorage);
        final managerWithStorage = RelayManager(
          config: configWithStorage,
          relayPool: mockRelayPool,
        );

        await managerWithStorage.initialize();
        await managerWithStorage.addRelay(testCustomRelayUrl);
        clearInteractions(mockStorage);

        await managerWithStorage.removeRelay(
          testCustomRelayUrl,
          source: RelayRemoveSource.user,
        );

        verify(() => mockStorage.saveRelays(any())).called(1);
      });

      test('persists removed relay ledger after removing relay', () async {
        final storage = InMemoryRelayStorage([testCustomRelayUrl]);
        final managerWithStorage = RelayManager(
          config: _createTestConfig(storage: storage),
          relayPool: mockRelayPool,
        );

        await managerWithStorage.initialize();
        await managerWithStorage.removeRelay(
          testCustomRelayUrl,
          source: RelayRemoveSource.user,
        );

        expect(await storage.loadRemovedRelays(), equals([testCustomRelayUrl]));
      });

      test(
        'initialize filters user-removed relays from polluted storage',
        () async {
          final storage = InMemoryRelayStorage(
            [testCustomRelayUrl, testCustomRelayUrl2],
            [testCustomRelayUrl],
          );
          final managerWithStorage = RelayManager(
            config: _createTestConfig(storage: storage),
            relayPool: mockRelayPool,
          );

          await managerWithStorage.initialize();

          expect(
            managerWithStorage.configuredRelays,
            isNot(contains(testCustomRelayUrl)),
          );
          expect(
            managerWithStorage.configuredRelays,
            contains(testCustomRelayUrl2),
          );
          expect(
            await storage.loadRelays(),
            isNot(contains(testCustomRelayUrl)),
          );
        },
      );

      test(
        'initialize filters user-removed default relay from polluted storage',
        () async {
          final storage = InMemoryRelayStorage(
            [testDefaultRelayUrl, testCustomRelayUrl],
            [testDefaultRelayUrl],
          );
          final managerWithStorage = RelayManager(
            config: _createTestConfig(storage: storage),
            relayPool: mockRelayPool,
          );

          await managerWithStorage.initialize();

          expect(
            managerWithStorage.configuredRelays,
            isNot(contains(testDefaultRelayUrl)),
          );
          expect(
            managerWithStorage.configuredRelays,
            contains(testCustomRelayUrl),
          );
          expect(
            await storage.loadRelays(),
            isNot(contains(testDefaultRelayUrl)),
          );
        },
      );

      test(
        'automatic add before initialize honors persisted removal ledger',
        () async {
          final storage = InMemoryRelayStorage(const [], [testCustomRelayUrl]);
          final managerWithStorage = RelayManager(
            config: _createTestConfig(storage: storage),
            relayPool: mockRelayPool,
          );

          final result = await managerWithStorage.addRelay(testCustomRelayUrl);

          expect(result, isFalse);
          expect(
            managerWithStorage.configuredRelays,
            isNot(contains(testCustomRelayUrl)),
          );
          expect(await storage.loadRelays(), isEmpty);
        },
      );

      test('concurrent ledger loads share one storage read', () async {
        final removedRelaysCompleter = Completer<List<String>>();
        var removedRelaysLoadCount = 0;
        when(() => mockStorage.loadRemovedRelays()).thenAnswer((_) {
          removedRelaysLoadCount++;
          return removedRelaysCompleter.future;
        });
        when(() => mockStorage.loadRelays()).thenAnswer((_) async => []);
        when(() => mockStorage.saveRelays(any())).thenAnswer((_) async {});
        when(
          () => mockStorage.saveRemovedRelays(any()),
        ).thenAnswer((_) async {});

        final managerWithStorage = RelayManager(
          config: _createTestConfig(storage: mockStorage),
          relayPool: mockRelayPool,
        );

        final initializeFuture = managerWithStorage.initialize();
        await Future<void>.delayed(Duration.zero);
        final restoreFuture = managerWithStorage.addRelay(
          testCustomRelayUrl,
          source: RelayAddSource.user,
        );
        await Future<void>.delayed(Duration.zero);

        expect(removedRelaysLoadCount, equals(1));

        removedRelaysCompleter.complete([testCustomRelayUrl]);
        await initializeFuture;

        expect(await restoreFuture, isTrue);
        expect(
          managerWithStorage.configuredRelays,
          contains(testCustomRelayUrl),
        );
        verify(() => mockStorage.saveRemovedRelays([])).called(1);
      });

      test(
        'ensureUserRemovedRelaysLoaded warms the ledger for later callers',
        () async {
          var removedRelaysLoadCount = 0;
          when(() => mockStorage.loadRemovedRelays()).thenAnswer((_) async {
            removedRelaysLoadCount++;
            return [testCustomRelayUrl];
          });
          when(() => mockStorage.loadRelays()).thenAnswer((_) async => []);
          when(() => mockStorage.saveRelays(any())).thenAnswer((_) async {});
          when(
            () => mockStorage.saveRemovedRelays(any()),
          ).thenAnswer((_) async {});

          final managerWithStorage = RelayManager(
            config: _createTestConfig(storage: mockStorage),
            relayPool: mockRelayPool,
          );

          await managerWithStorage.ensureUserRemovedRelaysLoaded();
          await managerWithStorage.ensureUserRemovedRelaysLoaded();

          expect(removedRelaysLoadCount, equals(1));

          // A later automatic add reuses the warmed ledger rather than
          // re-reading storage, and is still suppressed by it.
          expect(
            await managerWithStorage.addRelay(testCustomRelayUrl),
            isFalse,
          );
          expect(removedRelaysLoadCount, equals(1));
        },
      );

      test('automatic removal does not persist user removal intent', () async {
        final storage = InMemoryRelayStorage([testCustomRelayUrl]);
        final managerWithStorage = RelayManager(
          config: _createTestConfig(storage: storage),
          relayPool: mockRelayPool,
        );

        await managerWithStorage.initialize();
        await managerWithStorage.removeRelay(
          testCustomRelayUrl,
          source: RelayRemoveSource.automatic,
        );

        expect(await storage.loadRemovedRelays(), isEmpty);
      });

      test('emits status update when relay is removed', () async {
        final statusUpdates = <Map<String, RelayConnectionStatus>>[];
        manager.statusStream.listen(statusUpdates.add);

        await manager.removeRelay(
          testCustomRelayUrl,
          source: RelayRemoveSource.user,
        );
        await Future<void>.delayed(Duration.zero);

        expect(statusUpdates, isNotEmpty);
      });
    });

    group('isRelayConfigured', () {
      setUp(() async {
        await manager.initialize();
      });

      test('returns true for configured relay', () {
        expect(manager.isRelayConfigured(testDefaultRelayUrl), isTrue);
      });

      test('returns false for non-configured relay', () {
        expect(manager.isRelayConfigured(testCustomRelayUrl), isFalse);
      });

      test('returns false for invalid URL', () {
        expect(manager.isRelayConfigured('invalid'), isFalse);
      });

      test('normalizes URL before checking', () async {
        await manager.addRelay(testCustomRelayUrl);

        expect(manager.isRelayConfigured('relay.custom.com'), isTrue);
      });
    });

    group('isRelayConnected', () {
      setUp(() async {
        await manager.initialize();
      });

      test('returns true for connected relay', () async {
        when(
          () => mockRelayPool.add(
            any(),
            autoSubscribe: any(named: 'autoSubscribe'),
          ),
        ).thenAnswer((_) async => true);
        await manager.addRelay(testCustomRelayUrl);

        expect(manager.isRelayConnected(testCustomRelayUrl), isTrue);
      });

      test('returns false for disconnected relay', () async {
        when(
          () => mockRelayPool.add(
            any(),
            autoSubscribe: any(named: 'autoSubscribe'),
          ),
        ).thenAnswer((_) async => false);
        await manager.addRelay(testCustomRelayUrl);

        expect(manager.isRelayConnected(testCustomRelayUrl), isFalse);
      });

      test('returns false for non-configured relay', () {
        expect(manager.isRelayConnected(testCustomRelayUrl), isFalse);
      });

      test('returns false for invalid URL', () {
        expect(manager.isRelayConnected('invalid'), isFalse);
      });
    });

    group('getRelayStatus', () {
      setUp(() async {
        await manager.initialize();
      });

      test('returns status for configured relay', () {
        final status = manager.getRelayStatus(testDefaultRelayUrl);

        expect(status, isNotNull);
        expect(status!.url, equals(testDefaultRelayUrl));
      });

      test('returns null for non-configured relay', () {
        final status = manager.getRelayStatus(testCustomRelayUrl);

        expect(status, isNull);
      });

      test('returns null for invalid URL', () {
        final status = manager.getRelayStatus('invalid');

        expect(status, isNull);
      });

      test('status reflects isDefault correctly', () {
        final defaultStatus = manager.getRelayStatus(testDefaultRelayUrl);

        expect(defaultStatus?.isDefault, isTrue);
      });
    });

    group('connectedRelays', () {
      setUp(() async {
        await manager.initialize();
      });

      test('returns list of connected relay URLs', () async {
        final mockRelay = _createMockRelay(testDefaultRelayUrl);
        when(() => mockRelayPool.activeRelays()).thenReturn([mockRelay]);

        expect(manager.connectedRelays, contains(testDefaultRelayUrl));
      });

      test('only includes configured relays', () async {
        final mockRelay1 = _createMockRelay(testDefaultRelayUrl);
        final mockRelay2 = _createMockRelay('wss://unconfigured.relay.com');
        when(
          () => mockRelayPool.activeRelays(),
        ).thenReturn([mockRelay1, mockRelay2]);

        expect(manager.connectedRelays, contains(testDefaultRelayUrl));
        expect(
          manager.connectedRelays,
          isNot(contains('wss://unconfigured.relay.com')),
        );
      });

      test('returns empty list when no relays connected', () async {
        // Create a fresh manager without initializing to test empty state
        final uninitializedManager = RelayManager(
          config: config,
          relayPool: mockRelayPool,
        );

        expect(uninitializedManager.connectedRelays, isEmpty);
      });

      test('returns empty when all relays fail to connect', () async {
        // Create manager where connection fails
        when(
          () => mockRelayPool.add(
            any(),
            autoSubscribe: any(named: 'autoSubscribe'),
          ),
        ).thenAnswer((_) async => false);

        final failingManager = RelayManager(
          config: config,
          relayPool: mockRelayPool,
        );
        await failingManager.initialize();

        expect(failingManager.connectedRelays, isEmpty);
      });
    });

    group('retryDisconnectedRelays', () {
      setUp(() async {
        await manager.initialize();
      });

      test(
        'reconnects disconnected relays in parallel, not in series',
        () async {
          // Each connect is bounded at 10s + a 2s orphan close, so a serial
          // loop costs 12s x N. On device that was 48s for four unreachable
          // relays (#7091). The startup path already does this with Future.wait
          // -- "reduces startup from O(n * timeout) to O(max timeout)".
          final pendingConnects = <Completer<bool>>[];
          when(
            () => mockRelayPool.add(
              any(),
              autoSubscribe: any(named: 'autoSubscribe'),
            ),
          ).thenAnswer((_) async => false);
          for (final url in const [
            'wss://a.example.com',
            'wss://b.example.com',
            'wss://c.example.com',
          ]) {
            await manager.addRelay(url);
          }
          when(
            () => mockRelayPool.add(
              any(),
              autoSubscribe: any(named: 'autoSubscribe'),
            ),
          ).thenAnswer((_) {
            final pending = Completer<bool>();
            pendingConnects.add(pending);
            return pending.future;
          });

          final retry = manager.retryDisconnectedRelays();

          expect(
            pendingConnects,
            hasLength(3),
            reason:
                'every disconnected relay must begin dialling before any '
                'single dial completes',
          );
          for (final pending in pendingConnects) {
            pending.complete(false);
          }
          await retry;
        },
      );

      test('concurrent callers join one sweep instead of stacking', () async {
        // Nothing deduplicated in-flight sweeps, and one call site fires this
        // unawaited, so a subscribe racing a send at cold start stacked whole
        // sweeps: seven were observed overlapping on device (#7091). Each
        // rebuilds a fresh relay object and disposes the previous one, so the
        // connection-state guard one layer down cannot collapse them.
        var connectAttempts = 0;
        when(
          () => mockRelayPool.add(
            any(),
            autoSubscribe: any(named: 'autoSubscribe'),
          ),
        ).thenAnswer((_) async => false);
        await manager.addRelay('wss://solo.example.com');

        final connectGate = Completer<bool>();
        when(
          () => mockRelayPool.add(
            any(),
            autoSubscribe: any(named: 'autoSubscribe'),
          ),
        ).thenAnswer((_) {
          connectAttempts++;
          return connectGate.future;
        });

        final callers = Future.wait([
          manager.retryDisconnectedRelays(),
          manager.retryDisconnectedRelays(),
          manager.retryDisconnectedRelays(),
        ]);

        expect(
          connectAttempts,
          1,
          reason:
              'three overlapping callers should share one sweep, not dial '
              'the same relay three times',
        );
        connectGate.complete(false);
        await callers;
      });

      test('a wedged connect cannot outlive the sweep budget', () async {
        // Parallelising bounds the sweep at one connect, but only while every
        // connect honours its own timeout. Nothing above them enforces that,
        // and one awaited path below the socket layer can retry for minutes.
        final original = RelayManager.reconnectSweepBudget;
        RelayManager.reconnectSweepBudget = Duration.zero;
        addTearDown(() => RelayManager.reconnectSweepBudget = original);

        // Register the relay while connects still resolve, then wedge: the
        // add path awaits the same seam, so wedging first would hang setup
        // rather than the sweep under test.
        when(
          () => mockRelayPool.add(
            any(),
            autoSubscribe: any(named: 'autoSubscribe'),
          ),
        ).thenAnswer((_) async => false);
        await manager.addRelay('wss://wedged.example.com');
        clearInteractions(mockRelayPool);

        final wedged = Completer<bool>();
        addTearDown(() {
          if (!wedged.isCompleted) wedged.complete(false);
        });
        when(
          () => mockRelayPool.add(
            any(),
            autoSubscribe: any(named: 'autoSubscribe'),
          ),
        ).thenAnswer((_) => wedged.future);

        await manager.retryDisconnectedRelays();
        expect(
          manager.getRelayStatus('wss://wedged.example.com')?.state,
          RelayState.connecting,
          reason: 'an unresolved dial is not a failed dial',
        );

        final joined = manager.retryDisconnectedRelays();
        verify(
          () => mockRelayPool.add(
            any(),
            autoSubscribe: any(named: 'autoSubscribe'),
          ),
        ).called(1);

        wedged.complete(true);
        await joined;
        await Future<void>.delayed(Duration.zero);
        expect(
          manager.getRelayStatus('wss://wedged.example.com')?.state,
          RelayState.connected,
          reason: 'a dial that succeeds after the caller budget is still live',
        );
      });

      test('retries connection to disconnected relays', () async {
        // First connection fails
        when(
          () => mockRelayPool.add(
            any(),
            autoSubscribe: any(named: 'autoSubscribe'),
          ),
        ).thenAnswer((_) async => false);
        await manager.addRelay(testCustomRelayUrl);

        // Reset and make retry succeed
        clearInteractions(mockRelayPool);
        when(
          () => mockRelayPool.add(
            any(),
            autoSubscribe: any(named: 'autoSubscribe'),
          ),
        ).thenAnswer((_) async => true);

        await manager.retryDisconnectedRelays();

        verify(
          () => mockRelayPool.add(
            any(),
            autoSubscribe: any(named: 'autoSubscribe'),
          ),
        ).called(greaterThan(0));
      });

      test('updates status after successful retry', () async {
        when(
          () => mockRelayPool.add(
            any(),
            autoSubscribe: any(named: 'autoSubscribe'),
          ),
        ).thenAnswer((_) async => false);
        await manager.addRelay(testCustomRelayUrl);

        when(
          () => mockRelayPool.add(
            any(),
            autoSubscribe: any(named: 'autoSubscribe'),
          ),
        ).thenAnswer((_) async => true);
        await manager.retryDisconnectedRelays();

        final status = manager.getRelayStatus(testCustomRelayUrl);
        expect(status?.state, equals(RelayState.connected));
      });

      test('emits status updates during retry', () async {
        when(
          () => mockRelayPool.add(
            any(),
            autoSubscribe: any(named: 'autoSubscribe'),
          ),
        ).thenAnswer((_) async => false);
        await manager.addRelay(testCustomRelayUrl);

        final statusUpdates = <Map<String, RelayConnectionStatus>>[];
        manager.statusStream.listen(statusUpdates.add);

        when(
          () => mockRelayPool.add(
            any(),
            autoSubscribe: any(named: 'autoSubscribe'),
          ),
        ).thenAnswer((_) async => true);
        await manager.retryDisconnectedRelays();
        await Future<void>.delayed(Duration.zero);

        expect(statusUpdates, isNotEmpty);
      });
    });

    group('one dial per relay', () {
      test('a sweep while the startup connect is pending dials once', () async {
        // The sweep used to tear down the startup socket mid-handshake and
        // open a second one to the same relay (#8991).
        final dials = <Completer<bool>>[];
        when(
          () => mockRelayPool.add(
            any(),
            autoSubscribe: any(named: 'autoSubscribe'),
          ),
        ).thenAnswer((_) {
          final dial = Completer<bool>();
          dials.add(dial);
          return dial.future;
        });

        final startup = manager.initialize();
        final sweep = manager.retryDisconnectedRelays();
        await pumpEventQueue();

        expect(
          dials,
          hasLength(1),
          reason: 'the sweep must join the startup dial',
        );
        verify(() => mockRelayPool.remove(testDefaultRelayUrl)).called(1);

        for (final dial in dials) {
          dial.complete(true);
        }
        await Future.wait([startup, sweep]);
        expect(
          manager.getRelayStatus(testDefaultRelayUrl)?.state,
          RelayState.connected,
        );
      });

      test('a sweep joins the dial addRelay started', () async {
        await manager.initialize();
        final dial = Completer<bool>();
        var dialCount = 0;
        when(
          () => mockRelayPool.add(
            any(),
            autoSubscribe: any(named: 'autoSubscribe'),
          ),
        ).thenAnswer((_) {
          dialCount++;
          return dial.future;
        });

        final adding = manager.addRelay(testCustomRelayUrl);
        await pumpEventQueue();
        var swept = false;
        final sweep = manager.retryDisconnectedRelays().then(
          (_) => swept = true,
        );
        await pumpEventQueue();

        expect(
          dialCount,
          equals(1),
          reason: 'the sweep must join the dial in flight',
        );
        expect(
          swept,
          isFalse,
          reason: 'a caller must not proceed while the relay is still dialling',
        );

        dial.complete(true);
        await Future.wait([adding, sweep]);
        expect(swept, isTrue);
      });

      test('an error thrown while dialling reaches the caller', () async {
        // A shared dial that swallowed this would leave every caller waiting
        // on it forever.
        when(
          () => mockRelayPool.add(
            any(),
            autoSubscribe: any(named: 'autoSubscribe'),
          ),
        ).thenThrow(StateError('dial failed'));

        await expectLater(manager.initialize(), throwsStateError);
      });

      test(
        'removing a relay releases the callers waiting on its dial',
        () async {
          await manager.initialize();
          when(
            () => mockRelayPool.add(
              any(),
              autoSubscribe: any(named: 'autoSubscribe'),
            ),
          ).thenAnswer((_) => Completer<bool>().future);

          bool? added;
          unawaited(
            manager.addRelay(testCustomRelayUrl).then((ok) => added = ok),
          );
          await pumpEventQueue();
          await manager.removeRelay(
            testCustomRelayUrl,
            source: RelayRemoveSource.automatic,
          );
          await pumpEventQueue();

          expect(added, isFalse);
        },
      );

      test(
        'a re-added relay dials afresh and ignores the old dial settling late',
        () async {
          await manager.initialize();
          final dials = <Completer<bool>>[];
          when(
            () => mockRelayPool.add(
              any(),
              autoSubscribe: any(named: 'autoSubscribe'),
            ),
          ).thenAnswer((_) {
            final dial = Completer<bool>();
            dials.add(dial);
            return dial.future;
          });

          unawaited(manager.addRelay(testCustomRelayUrl));
          await pumpEventQueue();
          await manager.removeRelay(
            testCustomRelayUrl,
            source: RelayRemoveSource.automatic,
          );
          unawaited(manager.addRelay(testCustomRelayUrl));
          await pumpEventQueue();
          expect(
            dials,
            hasLength(2),
            reason: "the re-added relay must not join the removed relay's dial",
          );

          dials.first.complete(false);
          await pumpEventQueue();
          expect(
            manager.getRelayStatus(testCustomRelayUrl)?.state,
            RelayState.connecting,
            reason:
                "the removed relay's late result must not reach its "
                'successor',
          );
        },
      );

      test('dispose releases the callers waiting on a dial', () async {
        await manager.initialize();
        when(
          () => mockRelayPool.add(
            any(),
            autoSubscribe: any(named: 'autoSubscribe'),
          ),
        ).thenAnswer((_) => Completer<bool>().future);

        bool? added;
        unawaited(
          manager.addRelay(testCustomRelayUrl).then((ok) => added = ok),
        );
        await pumpEventQueue();
        await manager.dispose();
        await pumpEventQueue();

        expect(added, isFalse);
      });

      test('reconnectRelay replaces a dial in flight', () async {
        await manager.initialize();
        final dials = <Completer<bool>>[];
        when(
          () => mockRelayPool.add(
            any(),
            autoSubscribe: any(named: 'autoSubscribe'),
          ),
        ).thenAnswer((_) {
          final dial = Completer<bool>();
          dials.add(dial);
          return dial.future;
        });

        final adding = manager.addRelay(testCustomRelayUrl);
        await pumpEventQueue();
        final reconnecting = manager.reconnectRelay(testCustomRelayUrl);
        await pumpEventQueue();
        expect(dials, hasLength(2));

        dials.last.complete(true);
        expect(await reconnecting, isTrue);
        dials.first.complete(false);
        await pumpEventQueue();
        expect(
          manager.getRelayStatus(testCustomRelayUrl)?.state,
          RelayState.connected,
          reason: 'the replaced dial cannot overwrite its replacement',
        );
        expect(
          await adding,
          isTrue,
          reason: "a caller of the replaced dial gets the replacement's result",
        );
      });

      test('forceReconnectAll replaces a dial in flight', () async {
        final dials = <Completer<bool>>[];
        when(
          () => mockRelayPool.add(
            any(),
            autoSubscribe: any(named: 'autoSubscribe'),
          ),
        ).thenAnswer((_) {
          final dial = Completer<bool>();
          dials.add(dial);
          return dial.future;
        });

        final startup = manager.initialize();
        await pumpEventQueue();
        final cycle = manager.forceReconnectAll();
        await pumpEventQueue();
        expect(dials, hasLength(2));

        dials.last.complete(true);
        await cycle;
        dials.first.complete(false);
        await startup;
        expect(
          manager.getRelayStatus(testDefaultRelayUrl)?.state,
          RelayState.connected,
          reason: 'the replaced dial cannot overwrite the cycle',
        );
      });

      test(
        'a replaced attempt that throws cannot fail its replacement',
        () async {
          final diagnostics = <RelayDiagnostic>[];
          final dialManager = RelayManager(
            config: config,
            relayPool: mockRelayPool,
            diagnosticsSink: diagnostics.add,
          );
          await dialManager.initialize();
          final dials = <Completer<bool>>[];
          when(
            () => mockRelayPool.add(
              any(),
              autoSubscribe: any(named: 'autoSubscribe'),
            ),
          ).thenAnswer((_) {
            final dial = Completer<bool>();
            dials.add(dial);
            return dial.future;
          });

          final adding = dialManager.addRelay(testCustomRelayUrl);
          await pumpEventQueue();
          final reconnecting = dialManager.reconnectRelay(testCustomRelayUrl);
          await pumpEventQueue();
          expect(dials, hasLength(2));

          dials.first.completeError(StateError('replaced attempt failed'));
          await pumpEventQueue();
          dials.last.complete(true);

          expect(await reconnecting, isTrue);
          expect(await adding, isTrue);
          expect(
            diagnostics
                .where((entry) => entry.level == RelayDiagnosticLevel.error)
                .map((entry) => entry.error),
            contains(isA<StateError>()),
            reason: "the replaced attempt's error is still reported",
          );
        },
      );
    });

    group('health check', () {
      test('leaves a relay whose dial is still in flight', () async {
        // The pooled socket can still read as disconnected before its
        // handshake starts; a dial in flight is not a failed health check.
        final dial = Completer<bool>();
        when(
          () => mockRelayPool.add(
            any(),
            autoSubscribe: any(named: 'autoSubscribe'),
          ),
        ).thenAnswer((_) => dial.future);
        final relay = _createPooledRelay(
          testDefaultRelayUrl,
          connected: ClientConnected.disconnect,
          healthy: false,
        );
        when(
          () => mockRelayPool.getRelay(testDefaultRelayUrl),
        ).thenReturn(relay);

        final startup = manager.initialize();
        final sweep = manager.retryDisconnectedRelays();
        await pumpEventQueue();

        expect(
          manager.getRelayStatus(testDefaultRelayUrl)?.state,
          RelayState.connecting,
        );

        dial.complete(true);
        await Future.wait([startup, sweep]);
      });

      test('leaves a relay whose socket is still connecting', () async {
        // Demoting it made the sweep tear the socket down mid-handshake and
        // dial again (#8991).
        await manager.initialize();
        final relay = _createPooledRelay(
          testDefaultRelayUrl,
          connected: ClientConnected.connecting,
          healthy: false,
        );
        when(
          () => mockRelayPool.getRelay(testDefaultRelayUrl),
        ).thenReturn(relay);
        clearInteractions(mockRelayPool);

        await manager.retryDisconnectedRelays();

        expect(
          manager.getRelayStatus(testDefaultRelayUrl)?.state,
          RelayState.connected,
        );
        verifyNever(() => mockRelayPool.remove(testDefaultRelayUrl));
      });

      test('a sweep leaves a relay the SDK is still connecting', () async {
        when(
          () => mockRelayPool.add(
            any(),
            autoSubscribe: any(named: 'autoSubscribe'),
          ),
        ).thenAnswer((_) async => false);
        await manager.initialize();
        final relay = _createPooledRelay(
          testDefaultRelayUrl,
          connected: ClientConnected.connecting,
          healthy: false,
        );
        when(
          () => mockRelayPool.getRelay(testDefaultRelayUrl),
        ).thenReturn(relay);
        clearInteractions(mockRelayPool);

        await manager.retryDisconnectedRelays();

        verifyNever(() => mockRelayPool.remove(testDefaultRelayUrl));
        verifyNever(
          () => mockRelayPool.add(
            any(),
            autoSubscribe: any(named: 'autoSubscribe'),
          ),
        );
      });

      for (final (name, connected) in [
        ('a connected', ClientConnected.connected),
        ('a disconnected', ClientConnected.disconnect),
      ]) {
        test('still redials $name socket that fails its check', () async {
          await manager.initialize();
          final relay = _createPooledRelay(
            testDefaultRelayUrl,
            connected: connected,
            healthy: false,
          );
          when(
            () => mockRelayPool.getRelay(testDefaultRelayUrl),
          ).thenReturn(relay);
          clearInteractions(mockRelayPool);

          await manager.retryDisconnectedRelays();

          verify(() => mockRelayPool.remove(testDefaultRelayUrl)).called(1);
          verify(
            () => mockRelayPool.add(
              any(),
              autoSubscribe: any(named: 'autoSubscribe'),
            ),
          ).called(1);
        });
      }
    });

    group('reconnectRelay', () {
      setUp(() async {
        await manager.initialize();
        await manager.addRelay(testCustomRelayUrl);
      });

      test('disconnects and reconnects to relay', () async {
        clearInteractions(mockRelayPool);
        when(
          () => mockRelayPool.add(
            any(),
            autoSubscribe: any(named: 'autoSubscribe'),
          ),
        ).thenAnswer((_) async => true);

        await manager.reconnectRelay(testCustomRelayUrl);

        // The old socket is replaced once, as part of the new dial.
        verify(() => mockRelayPool.remove(testCustomRelayUrl)).called(1);
        verify(
          () => mockRelayPool.add(
            any(),
            autoSubscribe: any(named: 'autoSubscribe'),
          ),
        ).called(1);
      });

      test('returns true on successful reconnection', () async {
        when(
          () => mockRelayPool.add(
            any(),
            autoSubscribe: any(named: 'autoSubscribe'),
          ),
        ).thenAnswer((_) async => true);

        final result = await manager.reconnectRelay(testCustomRelayUrl);

        expect(result, isTrue);
      });

      test('returns false on failed reconnection', () async {
        when(
          () => mockRelayPool.add(
            any(),
            autoSubscribe: any(named: 'autoSubscribe'),
          ),
        ).thenAnswer((_) async => false);

        final result = await manager.reconnectRelay(testCustomRelayUrl);

        expect(result, isFalse);
      });

      test('returns false for non-configured relay', () async {
        final result = await manager.reconnectRelay('wss://unknown.relay.com');

        expect(result, isFalse);
      });

      test('returns false for invalid URL', () async {
        final result = await manager.reconnectRelay('invalid');

        expect(result, isFalse);
      });

      test('updates status during reconnection', () async {
        final statusStates = <RelayState>[];
        manager.statusStream.listen((statuses) {
          final status = statuses[testCustomRelayUrl];
          if (status != null) {
            statusStates.add(status.state);
          }
        });

        when(
          () => mockRelayPool.add(
            any(),
            autoSubscribe: any(named: 'autoSubscribe'),
          ),
        ).thenAnswer((_) async => true);
        await manager.reconnectRelay(testCustomRelayUrl);
        await Future<void>.delayed(Duration.zero);

        expect(statusStates, contains(RelayState.connecting));
      });
    });

    group('forceReconnectAll', () {
      setUp(() async {
        await manager.initialize();
        await manager.addRelay(testCustomRelayUrl);
        await manager.addRelay(testCustomRelayUrl2);
      });

      test('replaces every relay once', () async {
        clearInteractions(mockRelayPool);
        when(
          () => mockRelayPool.add(
            any(),
            autoSubscribe: any(named: 'autoSubscribe'),
          ),
        ).thenAnswer((_) async => true);

        await manager.forceReconnectAll();

        // Each old socket is replaced once, as part of its relay's new dial.
        verify(() => mockRelayPool.remove(testDefaultRelayUrl)).called(1);
        verify(() => mockRelayPool.remove(testCustomRelayUrl)).called(1);
        verify(() => mockRelayPool.remove(testCustomRelayUrl2)).called(1);
      });

      test('two concurrent calls run one cycle', () async {
        clearInteractions(mockRelayPool);

        await Future.wait([
          manager.forceReconnectAll(),
          manager.forceReconnectAll(),
        ]);

        verify(
          () => mockRelayPool.add(
            any(),
            autoSubscribe: any(named: 'autoSubscribe'),
          ),
        ).called(3);
      });

      test(
        'a completed cycle reports completed',
        () async {
          when(
            () => mockRelayPool.add(
              any(),
              autoSubscribe: any(named: 'autoSubscribe'),
            ),
          ).thenAnswer((_) async => true);

          expect(
            await manager.forceReconnectAll(),
            ForceReconnectOutcome.completed,
          );
        },
      );

      test(
        'a caller joining shortly before the shared deadline is told the '
        'cycle is still dialling, not that it finished',
        () async {
          // The bug this pins: the joiner used to get a normal completion
          // when the shared deadline expired, indistinguishable from a
          // finished cycle. The Relays screen then read connectedRelayCount
          // as zero and told the user the retry had failed, while the
          // reconnect was still running.
          final dials = <Completer<bool>>[];
          when(
            () => mockRelayPool.add(
              any(),
              autoSubscribe: any(named: 'autoSubscribe'),
            ),
          ).thenAnswer((_) {
            final dial = Completer<bool>();
            dials.add(dial);
            return dial.future;
          });

          final original = RelayManager.reconnectSweepBudget;
          RelayManager.reconnectSweepBudget = const Duration(milliseconds: 60);
          addTearDown(() => RelayManager.reconnectSweepBudget = original);

          final first = manager.forceReconnectAll();
          await pumpEventQueue();
          // Joins the running cycle with only part of its budget left.
          final joiner = manager.forceReconnectAll();

          expect(await joiner, ForceReconnectOutcome.stillDialling);
          expect(await first, ForceReconnectOutcome.stillDialling);
          expect(
            dials.every((dial) => !dial.isCompleted),
            isTrue,
            reason: 'the dials are still open; the cycle really did not finish',
          );

          for (final dial in dials) {
            dial.complete(true);
          }
          await pumpEventQueue();
        },
      );

      test('starts every dial before any completes', () async {
        final dials = <Completer<bool>>[];
        when(
          () => mockRelayPool.add(
            any(),
            autoSubscribe: any(named: 'autoSubscribe'),
          ),
        ).thenAnswer((_) {
          final dial = Completer<bool>();
          dials.add(dial);
          return dial.future;
        });

        final cycle = manager.forceReconnectAll();
        await pumpEventQueue();

        expect(dials, hasLength(3));
        for (final dial in dials) {
          dial.complete(true);
        }
        await cycle;
      });

      test('a sweep during the cycle joins it instead of redialling', () async {
        final dials = <Completer<bool>>[];
        when(
          () => mockRelayPool.add(
            any(),
            autoSubscribe: any(named: 'autoSubscribe'),
          ),
        ).thenAnswer((_) {
          final dial = Completer<bool>();
          dials.add(dial);
          return dial.future;
        });

        final cycle = manager.forceReconnectAll();
        await pumpEventQueue();
        final sweep = manager.retryDisconnectedRelays();
        await pumpEventQueue();

        expect(dials, hasLength(3), reason: 'the sweep must join the cycle');
        for (final dial in dials) {
          dial.complete(true);
        }
        await Future.wait([cycle, sweep]);
      });

      test('a relay removed mid-cycle is not dialled again', () async {
        final pending = <Completer<bool>>[];
        final dialledAfterRemoval = <String>[];
        var removed = false;
        when(
          () => mockRelayPool.add(
            any(),
            autoSubscribe: any(named: 'autoSubscribe'),
          ),
        ).thenAnswer((invocation) {
          if (removed) {
            dialledAfterRemoval.add(
              (invocation.positionalArguments.first as Relay).url,
            );
          }
          final dial = Completer<bool>();
          pending.add(dial);
          return dial.future;
        });

        var done = false;
        final cycle = manager.forceReconnectAll().whenComplete(
          () => done = true,
        );
        await pumpEventQueue();
        await manager.removeRelay(
          testCustomRelayUrl,
          source: RelayRemoveSource.automatic,
        );
        removed = true;
        for (var round = 0; round < 5 && !done; round++) {
          for (final dial in pending.where((d) => !d.isCompleted).toList()) {
            dial.complete(true);
          }
          await pumpEventQueue();
        }
        await cycle;

        expect(dialledAfterRemoval, isNot(contains(testCustomRelayUrl)));
      });

      test(
        'a hung dial releases callers at the budget and a later call '
        'replaces it',
        () async {
          final original = RelayManager.reconnectSweepBudget;
          RelayManager.reconnectSweepBudget = Duration.zero;
          addTearDown(() => RelayManager.reconnectSweepBudget = original);
          final hung = Completer<bool>();
          addTearDown(() {
            if (!hung.isCompleted) hung.complete(false);
          });
          var dials = 0;
          when(
            () => mockRelayPool.add(
              any(),
              autoSubscribe: any(named: 'autoSubscribe'),
            ),
          ).thenAnswer((_) {
            dials++;
            return hung.future;
          });

          var released = false;
          unawaited(manager.forceReconnectAll().then((_) => released = true));
          await pumpEventQueue();
          expect(
            released,
            isTrue,
            reason: 'a caller stops waiting at the budget',
          );

          unawaited(manager.forceReconnectAll());
          await pumpEventQueue();
          expect(
            dials,
            equals(6),
            reason: 'a call after the deadline replaces the hung dials',
          );
        },
      );

      test('a cycle cut short by dispose reports no failure', () async {
        final diagnostics = <RelayDiagnostic>[];
        final cycleManager = RelayManager(
          config: config,
          relayPool: mockRelayPool,
          diagnosticsSink: diagnostics.add,
        );
        await cycleManager.initialize();
        when(
          () => mockRelayPool.add(
            any(),
            autoSubscribe: any(named: 'autoSubscribe'),
          ),
        ).thenAnswer((_) => Completer<bool>().future);

        unawaited(cycleManager.forceReconnectAll());
        await pumpEventQueue();
        await cycleManager.dispose();
        await pumpEventQueue();

        final messages = diagnostics.map((entry) => entry.message);
        expect(messages, contains('Force reconnecting all relays'));
        expect(messages, isNot(contains('Force reconnection failed')));
      });

      test('a replaced cycle does not report its relay twice', () async {
        final original = RelayManager.reconnectSweepBudget;
        RelayManager.reconnectSweepBudget = Duration.zero;
        addTearDown(() => RelayManager.reconnectSweepBudget = original);
        final diagnostics = <RelayDiagnostic>[];
        final cycleManager = RelayManager(
          config: config,
          relayPool: mockRelayPool,
          diagnosticsSink: diagnostics.add,
        );
        await cycleManager.initialize();
        final dials = <Completer<bool>>[];
        when(
          () => mockRelayPool.add(
            any(),
            autoSubscribe: any(named: 'autoSubscribe'),
          ),
        ).thenAnswer((_) {
          final dial = Completer<bool>();
          dials.add(dial);
          return dial.future;
        });

        await cycleManager.forceReconnectAll();
        await cycleManager.forceReconnectAll();
        for (final dial in dials) {
          dial.complete(true);
        }
        await pumpEventQueue();

        expect(
          diagnostics.where(
            (entry) =>
                entry.message == 'Force reconnected' &&
                entry.relayUrl == testDefaultRelayUrl,
          ),
          hasLength(1),
        );
      });

      test('reconnects all relays after disconnecting', () async {
        clearInteractions(mockRelayPool);
        when(
          () => mockRelayPool.add(
            any(),
            autoSubscribe: any(named: 'autoSubscribe'),
          ),
        ).thenAnswer((_) async => true);

        await manager.forceReconnectAll();

        // Should reconnect all 3 relays
        verify(
          () => mockRelayPool.add(
            any(),
            autoSubscribe: any(named: 'autoSubscribe'),
          ),
        ).called(3);
      });

      test('updates status to connected on successful reconnection', () async {
        when(
          () => mockRelayPool.add(
            any(),
            autoSubscribe: any(named: 'autoSubscribe'),
          ),
        ).thenAnswer((_) async => true);

        await manager.forceReconnectAll();

        expect(
          manager.getRelayStatus(testDefaultRelayUrl)?.state,
          equals(RelayState.connected),
        );
        expect(
          manager.getRelayStatus(testCustomRelayUrl)?.state,
          equals(RelayState.connected),
        );
        expect(
          manager.getRelayStatus(testCustomRelayUrl2)?.state,
          equals(RelayState.connected),
        );
      });

      test('updates status to error on failed reconnection', () async {
        when(
          () => mockRelayPool.add(
            any(),
            autoSubscribe: any(named: 'autoSubscribe'),
          ),
        ).thenAnswer((_) async => false);

        await manager.forceReconnectAll();

        expect(
          manager.getRelayStatus(testDefaultRelayUrl)?.state,
          equals(RelayState.error),
        );
        expect(
          manager.getRelayStatus(testCustomRelayUrl)?.state,
          equals(RelayState.error),
        );
      });

      test('emits connecting status during reconnection', () async {
        final statusStates = <RelayState>[];
        manager.statusStream.listen((statuses) {
          final status = statuses[testCustomRelayUrl];
          if (status != null) {
            statusStates.add(status.state);
          }
        });

        when(
          () => mockRelayPool.add(
            any(),
            autoSubscribe: any(named: 'autoSubscribe'),
          ),
        ).thenAnswer((_) async => true);
        await manager.forceReconnectAll();
        await Future<void>.delayed(Duration.zero);

        expect(statusStates, contains(RelayState.connecting));
        expect(statusStates, contains(RelayState.connected));
      });

      test('handles mixed success and failure', () async {
        // First relay succeeds, second fails
        var callCount = 0;
        when(
          () => mockRelayPool.add(
            any(),
            autoSubscribe: any(named: 'autoSubscribe'),
          ),
        ).thenAnswer((_) async {
          callCount++;
          return callCount != 2; // Fail on second call
        });

        await manager.forceReconnectAll();

        // At least one should be connected, one errored
        final states = manager.currentStatuses.values.map((s) => s.state);
        expect(states, contains(RelayState.connected));
        expect(states, contains(RelayState.error));
      });
    });

    group('dispose', () {
      test('stops status polling', () async {
        await manager.initialize();
        await manager.dispose();

        expect(manager.isInitialized, isFalse);
      });

      test('closes status stream', () async {
        await manager.initialize();

        var streamClosed = false;
        manager.statusStream.listen((_) {}, onDone: () => streamClosed = true);

        await manager.dispose();

        expect(streamClosed, isTrue);
      });

      test('can be called multiple times safely', () async {
        await manager.initialize();
        await manager.dispose();
        await manager.dispose();

        expect(manager.isInitialized, isFalse);
      });
    });

    group('statusStream', () {
      test('emits updates when relay status changes', () async {
        final statusUpdates = <Map<String, RelayConnectionStatus>>[];
        manager.statusStream.listen(statusUpdates.add);

        await manager.initialize();
        await manager.addRelay(testCustomRelayUrl);
        await Future<void>.delayed(Duration.zero);

        expect(statusUpdates.length, greaterThan(1));
      });

      test('is a broadcast stream', () async {
        final updates1 = <Map<String, RelayConnectionStatus>>[];
        final updates2 = <Map<String, RelayConnectionStatus>>[];

        manager.statusStream.listen(updates1.add);
        manager.statusStream.listen(updates2.add);

        await manager.initialize();
        await Future<void>.delayed(Duration.zero);

        expect(updates1, isNotEmpty);
        expect(updates2, isNotEmpty);
      });
    });

    group('currentStatuses', () {
      setUp(() async {
        await manager.initialize();
      });

      test('returns snapshot of all relay statuses', () {
        final statuses = manager.currentStatuses;

        expect(statuses, isNotEmpty);
        expect(statuses.containsKey(testDefaultRelayUrl), isTrue);
      });

      test('returns unmodifiable map', () {
        final statuses = manager.currentStatuses;

        // Map.unmodifiable throws UnsupportedError on modification
        expect(() => statuses['new_key'], returnsNormally);
        // Verify it's actually unmodifiable by checking the runtime type
        expect(statuses.runtimeType.toString(), contains('Unmodifiable'));
      });
    });
  });

  group('RelayConnectionStatus', () {
    test('disconnected factory creates correct status', () {
      final status = RelayConnectionStatus.disconnected(
        testDefaultRelayUrl,
        isDefault: true,
      );

      expect(status.url, equals(testDefaultRelayUrl));
      expect(status.state, equals(RelayState.disconnected));
      expect(status.isDefault, isTrue);
      expect(status.isConnected, isFalse);
    });

    test('connecting factory creates correct status', () {
      final status = RelayConnectionStatus.connecting(testDefaultRelayUrl);

      expect(status.state, equals(RelayState.connecting));
      expect(status.isConnected, isFalse);
    });

    test('connected factory creates correct status', () {
      final status = RelayConnectionStatus.connected(testDefaultRelayUrl);

      expect(status.state, equals(RelayState.connected));
      expect(status.isConnected, isTrue);
      expect(status.lastConnectedAt, isNotNull);
    });

    test('isConnected returns true for connected state', () {
      final status = RelayConnectionStatus(
        url: testDefaultRelayUrl,
        state: RelayState.connected,
      );

      expect(status.isConnected, isTrue);
    });

    test('isConnected returns true for authenticated state', () {
      final status = RelayConnectionStatus(
        url: testDefaultRelayUrl,
        state: RelayState.authenticated,
      );

      expect(status.isConnected, isTrue);
    });

    test('hasError returns true for error state', () {
      final status = RelayConnectionStatus(
        url: testDefaultRelayUrl,
        state: RelayState.error,
      );

      expect(status.hasError, isTrue);
    });

    test('copyWith creates new instance with updated fields', () {
      final original = RelayConnectionStatus.disconnected(testDefaultRelayUrl);
      final copied = original.copyWith(state: RelayState.connected);

      expect(copied.state, equals(RelayState.connected));
      expect(copied.url, equals(original.url));
      expect(original.state, equals(RelayState.disconnected));
    });

    test('equality works correctly', () {
      final status1 = RelayConnectionStatus(
        url: testDefaultRelayUrl,
        state: RelayState.connected,
      );
      final status2 = RelayConnectionStatus(
        url: testDefaultRelayUrl,
        state: RelayState.connected,
      );
      final status3 = RelayConnectionStatus(
        url: testDefaultRelayUrl,
        state: RelayState.disconnected,
      );

      expect(status1, equals(status2));
      expect(status1, isNot(equals(status3)));
    });

    test('hashCode is consistent with equality', () {
      final status1 = RelayConnectionStatus(
        url: testDefaultRelayUrl,
        state: RelayState.connected,
      );
      final status2 = RelayConnectionStatus(
        url: testDefaultRelayUrl,
        state: RelayState.connected,
      );

      expect(status1.hashCode, equals(status2.hashCode));
    });

    test('toString returns readable representation', () {
      final status = RelayConnectionStatus(
        url: testDefaultRelayUrl,
        state: RelayState.connected,
        isDefault: true,
      );

      final str = status.toString();
      expect(str, contains('RelayConnectionStatus'));
      expect(str, contains(testDefaultRelayUrl));
      expect(str, contains('connected'));
    });
  });

  group('RelayManagerConfig', () {
    test('creates config with required fields', () {
      final config = RelayManagerConfig(defaultRelayUrl: testDefaultRelayUrl);

      expect(config.defaultRelayUrl, equals(testDefaultRelayUrl));
      expect(config.storage, isNull);
      expect(config.autoReconnect, isTrue);
    });

    test('creates config with all fields', () {
      final storage = InMemoryRelayStorage();
      final config = RelayManagerConfig(
        defaultRelayUrl: testDefaultRelayUrl,
        storage: storage,
        autoReconnect: false,
        maxReconnectAttempts: 10,
        reconnectDelayMs: 5000,
      );

      expect(config.storage, equals(storage));
      expect(config.autoReconnect, isFalse);
      expect(config.maxReconnectAttempts, equals(10));
      expect(config.reconnectDelayMs, equals(5000));
    });

    test('copyWith creates new instance with updated fields', () {
      final original = RelayManagerConfig(defaultRelayUrl: testDefaultRelayUrl);
      final copied = original.copyWith(autoReconnect: false);

      expect(copied.autoReconnect, isFalse);
      expect(copied.defaultRelayUrl, equals(original.defaultRelayUrl));
    });
  });

  group('InMemoryRelayStorage', () {
    test('loadRelays returns empty list initially', () async {
      final storage = InMemoryRelayStorage();

      final relays = await storage.loadRelays();

      expect(relays, isEmpty);
    });

    test('loadRelays returns initial relays if provided', () async {
      final storage = InMemoryRelayStorage([
        testDefaultRelayUrl,
        testCustomRelayUrl,
      ]);

      final relays = await storage.loadRelays();

      expect(relays, contains(testDefaultRelayUrl));
      expect(relays, contains(testCustomRelayUrl));
    });

    test('saveRelays persists relay list', () async {
      final storage = InMemoryRelayStorage();

      await storage.saveRelays([testDefaultRelayUrl, testCustomRelayUrl]);
      final relays = await storage.loadRelays();

      expect(relays, contains(testDefaultRelayUrl));
      expect(relays, contains(testCustomRelayUrl));
    });

    test('saveRelays replaces previous list', () async {
      final storage = InMemoryRelayStorage([testDefaultRelayUrl]);

      await storage.saveRelays([testCustomRelayUrl]);
      final relays = await storage.loadRelays();

      expect(relays, isNot(contains(testDefaultRelayUrl)));
      expect(relays, contains(testCustomRelayUrl));
    });

    test(
      'removed relays persist independently from configured relays',
      () async {
        final storage = InMemoryRelayStorage([testDefaultRelayUrl]);

        await storage.saveRemovedRelays([testCustomRelayUrl]);

        expect(await storage.loadRelays(), equals([testDefaultRelayUrl]));
        expect(await storage.loadRemovedRelays(), equals([testCustomRelayUrl]));
      },
    );
  });

  group('Blocked Relays', () {
    late _MockRelayPool mockRelayPool;

    setUp(() {
      mockRelayPool = _MockRelayPool();
      when(() => mockRelayPool.activeRelays()).thenReturn([]);
      when(() => mockRelayPool.getRelay(any())).thenReturn(null);
      when(
        () => mockRelayPool.add(
          any(),
          autoSubscribe: any(named: 'autoSubscribe'),
        ),
      ).thenAnswer((_) async => true);
      when(() => mockRelayPool.remove(any())).thenReturn(null);
    });

    test('addRelay rejects blocked relay hosts', () async {
      final manager = RelayManager(
        config: _createTestConfig(),
        relayPool: mockRelayPool,
        relayFactory: _FakeRelay.new,
      );
      await manager.initialize();

      // Try to add the blocked relay
      final result = await manager.addRelay('wss://index.coracle.social');

      expect(result, isFalse);
      expect(
        manager.configuredRelays,
        isNot(contains('wss://index.coracle.social')),
      );
    });

    test('addRelay accepts non-blocked relays', () async {
      final manager = RelayManager(
        config: _createTestConfig(),
        relayPool: mockRelayPool,
        relayFactory: _FakeRelay.new,
      );
      await manager.initialize();

      // Add a non-blocked relay
      final result = await manager.addRelay('wss://relay.damus.io');

      expect(result, isTrue);
      expect(manager.configuredRelays, contains('wss://relay.damus.io'));
    });

    test('initialize filters out blocked relays from storage', () async {
      final storage = InMemoryRelayStorage([
        testDefaultRelayUrl,
        'wss://index.coracle.social', // blocked
        testCustomRelayUrl,
      ]);
      final manager = RelayManager(
        config: _createTestConfig(storage: storage),
        relayPool: mockRelayPool,
        relayFactory: _FakeRelay.new,
      );

      await manager.initialize();

      // Blocked relay should not be in configured relays
      expect(
        manager.configuredRelays,
        isNot(contains('wss://index.coracle.social')),
      );
      // Other relays should be present
      expect(manager.configuredRelays, contains(testDefaultRelayUrl));
      expect(manager.configuredRelays, contains(testCustomRelayUrl));

      // Verify storage was updated to remove blocked relay
      final savedRelays = await storage.loadRelays();
      expect(savedRelays, isNot(contains('wss://index.coracle.social')));
      expect(savedRelays, contains(testDefaultRelayUrl));
      expect(savedRelays, contains(testCustomRelayUrl));
    });

    group('environment host lock (allowedRelayHost)', () {
      const envRelayUrl = 'wss://relay.staging.divine.video';
      const envHost = 'relay.staging.divine.video';
      const productionRelayUrl = 'wss://relay.divine.video';

      test('isRelayAllowed allows any valid relay when host is null', () {
        expect(manager.isRelayAllowed(productionRelayUrl), isTrue);
        expect(manager.isRelayAllowed(envRelayUrl), isTrue);
      });

      test('isRelayAllowed rejects non-relay URLs', () {
        expect(manager.isRelayAllowed('http://example.com'), isFalse);
      });

      test('isRelayAllowed allows only the locked host', () {
        final locked = RelayManager(
          config: _createTestConfig(
            defaultRelayUrl: envRelayUrl,
            allowedRelayHost: envHost,
          ),
          relayPool: mockRelayPool,
        );

        expect(locked.isRelayAllowed(envRelayUrl), isTrue);
        expect(locked.isRelayAllowed(productionRelayUrl), isFalse);
      });

      test('addRelay rejects a host other than the locked host', () async {
        final locked = RelayManager(
          config: _createTestConfig(
            defaultRelayUrl: envRelayUrl,
            allowedRelayHost: envHost,
          ),
          relayPool: mockRelayPool,
        );
        await locked.initialize();

        final added = await locked.addRelay(productionRelayUrl);

        expect(added, isFalse);
        expect(locked.configuredRelays, isNot(contains(productionRelayUrl)));
        expect(locked.configuredRelays, contains(envRelayUrl));
      });

      test(
        'initialize filters a persisted disallowed relay and re-saves',
        () async {
          when(
            () => mockStorage.loadRelays(),
          ).thenAnswer((_) async => [productionRelayUrl, envRelayUrl]);
          when(() => mockStorage.saveRelays(any())).thenAnswer((_) async {});

          final locked = RelayManager(
            config: _createTestConfig(
              defaultRelayUrl: envRelayUrl,
              storage: mockStorage,
              allowedRelayHost: envHost,
            ),
            relayPool: mockRelayPool,
          );
          await locked.initialize();

          expect(locked.configuredRelays, contains(envRelayUrl));
          expect(locked.configuredRelays, isNot(contains(productionRelayUrl)));
          final saved =
              verify(() => mockStorage.saveRelays(captureAny())).captured.last
                  as List<String>;
          expect(saved, isNot(contains(productionRelayUrl)));
        },
      );
    });
  });
}
