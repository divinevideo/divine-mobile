// Not required for test files
// ignore_for_file: prefer_const_constructors

import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:nostr_sdk/relay/client_connected.dart';
import 'package:test/test.dart';

class _MockRelayPool extends Mock implements RelayPool {}

class _MockRelay extends Mock implements Relay {}

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
}) {
  return RelayManagerConfig(
    defaultRelayUrl: defaultRelayUrl ?? testDefaultRelayUrl,
    storage: storage,
    autoReconnect: autoReconnect,
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
    when(() => mockRelayPool.add(any())).thenAnswer((_) async => true);
    when(() => mockRelayPool.remove(any())).thenReturn(null);

    manager = RelayManager(
      config: config,
      relayPool: mockRelayPool,
    );
  });

  tearDown(() {
    reset(mockRelayPool);
    reset(mockStorage);
  });

  group('RelayManager', () {
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
        when(() => mockStorage.loadRelays()).thenAnswer(
          (_) async => [testCustomRelayUrl],
        );
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
        when(() => mockStorage.loadRelays()).thenAnswer(
          (_) async => [testCustomRelayUrl],
        );
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
        verify(() => mockRelayPool.add(any())).called(1);
      });

      test('connects to all configured relays', () async {
        when(() => mockStorage.loadRelays()).thenAnswer(
          (_) async => [testCustomRelayUrl, testCustomRelayUrl2],
        );
        when(() => mockStorage.saveRelays(any())).thenAnswer((_) async {});

        final configWithStorage = _createTestConfig(storage: mockStorage);
        final managerWithStorage = RelayManager(
          config: configWithStorage,
          relayPool: mockRelayPool,
        );

        await managerWithStorage.initialize();

        // Should connect to default + 2 custom relays
        verify(() => mockRelayPool.add(any())).called(3);
      });

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

        verify(() => mockRelayPool.add(any())).called(greaterThan(1));
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

        final configWithStorage = _createTestConfig(storage: mockStorage);
        final managerWithStorage = RelayManager(
          config: configWithStorage,
          relayPool: mockRelayPool,
        );

        await managerWithStorage.initialize();
        await managerWithStorage.addRelay(testCustomRelayUrl);

        verify(() => mockStorage.saveRelays(any())).called(1);
      });

      test('updates status to connected on success', () async {
        when(() => mockRelayPool.add(any())).thenAnswer((_) async => true);

        await manager.addRelay(testCustomRelayUrl);

        final status = manager.getRelayStatus(testCustomRelayUrl);
        expect(status?.state, equals(RelayState.connected));
      });

      test('updates status to error on failure', () async {
        when(() => mockRelayPool.add(any())).thenAnswer((_) async => false);

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
        when(() => mockRelayPool.add(any())).thenAnswer((_) async => false);

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
        expect(
          lastUpdate[testCustomRelayUrl]?.state,
          equals(RelayState.error),
        );
      });
    });

    group('removeRelay', () {
      setUp(() async {
        await manager.initialize();
        await manager.addRelay(testCustomRelayUrl);
      });

      test('removes relay from configured list', () async {
        final result = await manager.removeRelay(testCustomRelayUrl);

        expect(result, isTrue);
        expect(manager.configuredRelays, isNot(contains(testCustomRelayUrl)));
      });

      test('disconnects from the relay via RelayPool', () async {
        await manager.removeRelay(testCustomRelayUrl);

        verify(() => mockRelayPool.remove(testCustomRelayUrl)).called(1);
      });

      test('returns false when removing default relay', () async {
        final result = await manager.removeRelay(testDefaultRelayUrl);

        expect(result, isFalse);
        expect(manager.configuredRelays, contains(testDefaultRelayUrl));
      });

      test('returns false for non-configured relay', () async {
        final result = await manager.removeRelay('wss://unknown.relay.com');

        expect(result, isFalse);
      });

      test('returns false for invalid URL', () async {
        final result = await manager.removeRelay('invalid-url');

        expect(result, isFalse);
      });

      test('removes status entry for relay', () async {
        await manager.removeRelay(testCustomRelayUrl);

        final status = manager.getRelayStatus(testCustomRelayUrl);
        expect(status, isNull);
      });

      test('saves configuration after removing relay', () async {
        when(() => mockStorage.loadRelays()).thenAnswer((_) async => []);
        when(() => mockStorage.saveRelays(any())).thenAnswer((_) async {});

        final configWithStorage = _createTestConfig(storage: mockStorage);
        final managerWithStorage = RelayManager(
          config: configWithStorage,
          relayPool: mockRelayPool,
        );

        await managerWithStorage.initialize();
        await managerWithStorage.addRelay(testCustomRelayUrl);
        clearInteractions(mockStorage);

        await managerWithStorage.removeRelay(testCustomRelayUrl);

        verify(() => mockStorage.saveRelays(any())).called(1);
      });

      test('emits status update when relay is removed', () async {
        final statusUpdates = <Map<String, RelayConnectionStatus>>[];
        manager.statusStream.listen(statusUpdates.add);

        await manager.removeRelay(testCustomRelayUrl);
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
        when(() => mockRelayPool.add(any())).thenAnswer((_) async => true);
        await manager.addRelay(testCustomRelayUrl);

        expect(manager.isRelayConnected(testCustomRelayUrl), isTrue);
      });

      test('returns false for disconnected relay', () async {
        when(() => mockRelayPool.add(any())).thenAnswer((_) async => false);
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

      test('returns empty list when no relays connected', () {
        when(() => mockRelayPool.activeRelays()).thenReturn([]);

        expect(manager.connectedRelays, isEmpty);
      });
    });

    group('retryDisconnectedRelays', () {
      setUp(() async {
        await manager.initialize();
      });

      test('retries connection to disconnected relays', () async {
        // First connection fails
        when(() => mockRelayPool.add(any())).thenAnswer((_) async => false);
        await manager.addRelay(testCustomRelayUrl);

        // Reset and make retry succeed
        clearInteractions(mockRelayPool);
        when(() => mockRelayPool.add(any())).thenAnswer((_) async => true);

        await manager.retryDisconnectedRelays();

        verify(() => mockRelayPool.add(any())).called(greaterThan(0));
      });

      test('updates status after successful retry', () async {
        when(() => mockRelayPool.add(any())).thenAnswer((_) async => false);
        await manager.addRelay(testCustomRelayUrl);

        when(() => mockRelayPool.add(any())).thenAnswer((_) async => true);
        await manager.retryDisconnectedRelays();

        final status = manager.getRelayStatus(testCustomRelayUrl);
        expect(status?.state, equals(RelayState.connected));
      });

      test('emits status updates during retry', () async {
        when(() => mockRelayPool.add(any())).thenAnswer((_) async => false);
        await manager.addRelay(testCustomRelayUrl);

        final statusUpdates = <Map<String, RelayConnectionStatus>>[];
        manager.statusStream.listen(statusUpdates.add);

        when(() => mockRelayPool.add(any())).thenAnswer((_) async => true);
        await manager.retryDisconnectedRelays();
        await Future<void>.delayed(Duration.zero);

        expect(statusUpdates, isNotEmpty);
      });
    });

    group('reconnectRelay', () {
      setUp(() async {
        await manager.initialize();
        await manager.addRelay(testCustomRelayUrl);
      });

      test('disconnects and reconnects to relay', () async {
        clearInteractions(mockRelayPool);
        when(() => mockRelayPool.add(any())).thenAnswer((_) async => true);

        await manager.reconnectRelay(testCustomRelayUrl);

        verify(() => mockRelayPool.remove(testCustomRelayUrl)).called(1);
        verify(() => mockRelayPool.add(any())).called(1);
      });

      test('returns true on successful reconnection', () async {
        when(() => mockRelayPool.add(any())).thenAnswer((_) async => true);

        final result = await manager.reconnectRelay(testCustomRelayUrl);

        expect(result, isTrue);
      });

      test('returns false on failed reconnection', () async {
        when(() => mockRelayPool.add(any())).thenAnswer((_) async => false);

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

        when(() => mockRelayPool.add(any())).thenAnswer((_) async => true);
        await manager.reconnectRelay(testCustomRelayUrl);
        await Future<void>.delayed(Duration.zero);

        expect(statusStates, contains(RelayState.connecting));
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
        manager.statusStream.listen(
          (_) {},
          onDone: () => streamClosed = true,
        );

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
        expect(
          () => statuses['new_key'],
          returnsNormally,
        );
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
      final config = RelayManagerConfig(
        defaultRelayUrl: testDefaultRelayUrl,
      );

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
      final original = RelayManagerConfig(
        defaultRelayUrl: testDefaultRelayUrl,
      );
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
  });
}
