// ABOUTME: Unit tests for relaySetChangeBridge provider
// ABOUTME: Verifies that relay set membership changes trigger feed reset,
// while connection state flapping does not.

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/services/video_event_service.dart';

class MockNostrClient extends Mock implements NostrClient {}

class MockVideoEventService extends Mock implements VideoEventService {}

class SwappableNostrService extends NostrService {
  SwappableNostrService(this.initialClient);

  final NostrClient initialClient;

  @override
  NostrClient build() => initialClient;

  void replaceWith(NostrClient client) {
    state = client;
  }
}

class TestNostrSession extends NostrSession {
  TestNostrSession(this.initialReadiness);

  final NostrSessionReadiness initialReadiness;

  @override
  NostrSessionReadiness build() => initialReadiness;
}

void stubUserRemovedRelays(
  MockNostrClient client, {
  Set<String> relays = const {},
}) {
  when(() => client.isUserRemovedRelay(any())).thenAnswer((call) async {
    final relay = call.positionalArguments.single as String;
    return relays.contains(relay);
  });
}

void main() {
  setUpAll(() {
    registerFallbackValue(<String>[]);
    registerFallbackValue(RelayRemoveSource.user);
  });

  group('relaySetChangeBridge', () {
    const defaultRelay = 'wss://relay.divine.video';
    const pubkeyA =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    const pubkeyB =
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
    late MockNostrClient mockNostrClient;
    late MockVideoEventService mockVideoEventService;
    late StreamController<Map<String, RelayConnectionStatus>> statusController;
    late TestNostrSession testNostrSession;
    late String clientPublicKey;

    setUp(() {
      mockNostrClient = MockNostrClient();
      mockVideoEventService = MockVideoEventService();
      statusController =
          StreamController<Map<String, RelayConnectionStatus>>.broadcast();
      testNostrSession = TestNostrSession(
        const NostrSessionReadiness.identityKnown(pubkey: pubkeyA),
      );
      clientPublicKey = '';

      when(
        () => mockVideoEventService.resetAndResubscribeAll(),
      ).thenAnswer((_) async {});
      when(() => mockNostrClient.isInitialized).thenReturn(true);
      when(() => mockNostrClient.forceReconnectAll()).thenAnswer(
        (_) async => ForceReconnectOutcome.completed,
      );
      when(() => mockNostrClient.defaultRelayUrl).thenReturn(defaultRelay);
      when(() => mockNostrClient.publicKey).thenAnswer((_) => clientPublicKey);
      stubUserRemovedRelays(mockNostrClient);
    });

    tearDown(() {
      statusController.close();
    });

    ProviderContainer createContainer({
      required Map<String, RelayConnectionStatus> initialStatuses,
    }) {
      when(() => mockNostrClient.relayStatuses).thenReturn(initialStatuses);
      when(
        () => mockNostrClient.relayStatusStream,
      ).thenAnswer((_) => statusController.stream);

      final container = ProviderContainer(
        overrides: [
          nostrServiceProvider.overrideWithValue(mockNostrClient),
          nostrSessionProvider.overrideWith(() => testNostrSession),
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
        ],
      );

      // Activate the provider
      container.read(relaySetChangeBridgeProvider);
      return container;
    }

    void stubClientScope(
      MockNostrClient client, {
      String pubkey = '',
      String relay = defaultRelay,
    }) {
      when(() => client.publicKey).thenReturn(pubkey);
      when(() => client.defaultRelayUrl).thenReturn(relay);
      stubUserRemovedRelays(client);
    }

    test('does not trigger reset on initial activation', () {
      fakeAsync((async) {
        final container = createContainer(
          initialStatuses: {
            'wss://relay1.example.com': RelayConnectionStatus.connected(
              'wss://relay1.example.com',
            ),
          },
        );

        // Elapse well past debounce to confirm nothing fires
        async.elapse(const Duration(seconds: 3));

        verifyNever(() => mockVideoEventService.resetAndResubscribeAll());
        container.dispose();
      });
    });

    test('triggers reset when a new relay is added', () {
      fakeAsync((async) {
        final container = createContainer(
          initialStatuses: {
            'wss://relay1.example.com': RelayConnectionStatus.connected(
              'wss://relay1.example.com',
            ),
          },
        );

        // Simulate adding a new relay
        statusController.add({
          'wss://relay1.example.com': RelayConnectionStatus.connected(
            'wss://relay1.example.com',
          ),
          'wss://relay2.example.com': RelayConnectionStatus.connected(
            'wss://relay2.example.com',
          ),
        });

        async.flushMicrotasks();
        // Elapse past the 2s debounce timer
        async.elapse(const Duration(seconds: 2));
        async.flushMicrotasks();

        verify(() => mockNostrClient.forceReconnectAll()).called(1);
        verify(() => mockVideoEventService.resetAndResubscribeAll()).called(1);
        container.dispose();
      });
    });

    test('triggers reset when a relay is removed', () {
      fakeAsync((async) {
        final container = createContainer(
          initialStatuses: {
            'wss://relay1.example.com': RelayConnectionStatus.connected(
              'wss://relay1.example.com',
            ),
            'wss://relay2.example.com': RelayConnectionStatus.connected(
              'wss://relay2.example.com',
            ),
          },
        );

        // Simulate removing a relay
        statusController.add({
          'wss://relay1.example.com': RelayConnectionStatus.connected(
            'wss://relay1.example.com',
          ),
        });

        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 2));
        async.flushMicrotasks();

        verify(() => mockVideoEventService.resetAndResubscribeAll()).called(1);
        container.dispose();
      });
    });

    test('does not trigger reset on connection state flapping', () {
      fakeAsync((async) {
        final container = createContainer(
          initialStatuses: {
            'wss://relay1.example.com': RelayConnectionStatus.connected(
              'wss://relay1.example.com',
            ),
          },
        );

        // Simulate connection state change (same URLs, different status)
        statusController.add({
          'wss://relay1.example.com': RelayConnectionStatus.disconnected(
            'wss://relay1.example.com',
          ),
        });

        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 2));
        async.flushMicrotasks();

        verifyNever(() => mockVideoEventService.resetAndResubscribeAll());
        container.dispose();
      });
    });

    test('debounces rapid relay set changes into single reset', () {
      fakeAsync((async) {
        final container = createContainer(
          initialStatuses: {
            'wss://relay1.example.com': RelayConnectionStatus.connected(
              'wss://relay1.example.com',
            ),
          },
        );

        // Rapid changes: add relay2, then add relay3 (within 2s window)
        statusController.add({
          'wss://relay1.example.com': RelayConnectionStatus.connected(
            'wss://relay1.example.com',
          ),
          'wss://relay2.example.com': RelayConnectionStatus.connected(
            'wss://relay2.example.com',
          ),
        });

        async.flushMicrotasks();
        async.elapse(const Duration(milliseconds: 500));

        statusController.add({
          'wss://relay1.example.com': RelayConnectionStatus.connected(
            'wss://relay1.example.com',
          ),
          'wss://relay2.example.com': RelayConnectionStatus.connected(
            'wss://relay2.example.com',
          ),
          'wss://relay3.example.com': RelayConnectionStatus.connected(
            'wss://relay3.example.com',
          ),
        });

        async.flushMicrotasks();
        // 2s from last change fires the debounce
        async.elapse(const Duration(seconds: 2));
        async.flushMicrotasks();

        // Should only have fired once despite two set changes
        verify(() => mockVideoEventService.resetAndResubscribeAll()).called(1);
        container.dispose();
      });
    });

    test('handles empty initial relay set', () {
      fakeAsync((async) {
        final container = createContainer(initialStatuses: {});

        // Add first relay
        statusController.add({
          'wss://relay1.example.com': RelayConnectionStatus.connected(
            'wss://relay1.example.com',
          ),
        });

        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 2));
        async.flushMicrotasks();

        verify(() => mockVideoEventService.resetAndResubscribeAll()).called(1);
        container.dispose();
      });
    });

    test('does not reconnect for a change observed during initialization', () {
      fakeAsync((async) {
        var isInitialized = false;
        when(
          () => mockNostrClient.isInitialized,
        ).thenAnswer((_) => isInitialized);
        final container = createContainer(initialStatuses: {});

        statusController.add({
          'wss://relay1.example.com': RelayConnectionStatus.connecting(
            'wss://relay1.example.com',
          ),
        });

        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 1));
        isInitialized = true;
        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();

        verifyNever(() => mockNostrClient.forceReconnectAll());
        verifyNever(() => mockVideoEventService.resetAndResubscribeAll());
        container.dispose();
      });
    });

    test(
      'does not reconnect when client settles before service initialization',
      () {
        fakeAsync((async) {
          final container = createContainer(initialStatuses: {});
          container
              .read(nostrInitializationInProgressProvider.notifier)
              .begin(mockNostrClient);

          statusController.add({
            'wss://relay1.example.com': RelayConnectionStatus.connecting(
              'wss://relay1.example.com',
            ),
          });

          async.flushMicrotasks();
          async.elapse(const Duration(seconds: 1));
          container
              .read(nostrInitializationInProgressProvider.notifier)
              .end(mockNostrClient);
          async.elapse(const Duration(seconds: 1));
          async.flushMicrotasks();

          verifyNever(() => mockNostrClient.forceReconnectAll());
          verifyNever(() => mockVideoEventService.resetAndResubscribeAll());
          container.dispose();
        });
      },
    );

    test('defers a healthy relay change while initialization overlaps', () {
      fakeAsync((async) {
        final container = createContainer(initialStatuses: {});

        statusController.add({
          'wss://relay1.example.com': RelayConnectionStatus.connected(
            'wss://relay1.example.com',
          ),
        });

        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 1));
        container
            .read(nostrInitializationInProgressProvider.notifier)
            .begin(mockNostrClient);
        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();

        verifyNever(() => mockNostrClient.forceReconnectAll());
        verifyNever(() => mockVideoEventService.resetAndResubscribeAll());

        container
            .read(nostrInitializationInProgressProvider.notifier)
            .end(mockNostrClient);
        async.elapse(const Duration(seconds: 2));
        async.flushMicrotasks();

        verify(() => mockNostrClient.forceReconnectAll()).called(1);
        verify(() => mockVideoEventService.resetAndResubscribeAll()).called(1);
        container.dispose();
      });
    });

    test(
      'resets for an active-client edit while a replacement initializes',
      () {
        fakeAsync((async) {
          final replacementClient = MockNostrClient();
          final container = createContainer(initialStatuses: {});
          container
              .read(nostrInitializationInProgressProvider.notifier)
              .begin(replacementClient);

          statusController.add({
            'wss://relay1.example.com': RelayConnectionStatus.connected(
              'wss://relay1.example.com',
            ),
          });

          async.flushMicrotasks();
          async.elapse(const Duration(seconds: 2));
          async.flushMicrotasks();

          verify(() => mockNostrClient.forceReconnectAll()).called(1);
          verify(
            () => mockVideoEventService.resetAndResubscribeAll(),
          ).called(1);
          container
              .read(nostrInitializationInProgressProvider.notifier)
              .end(replacementClient);
          container.dispose();
        });
      },
    );

    test('keeps reset intent when a startup change joins the debounce', () {
      fakeAsync((async) {
        final container = createContainer(initialStatuses: {});

        statusController.add({
          'wss://relay1.example.com': RelayConnectionStatus.connected(
            'wss://relay1.example.com',
          ),
        });
        async.flushMicrotasks();
        async.elapse(const Duration(milliseconds: 500));

        container
            .read(nostrInitializationInProgressProvider.notifier)
            .begin(mockNostrClient);
        statusController.add({
          'wss://relay1.example.com': RelayConnectionStatus.connected(
            'wss://relay1.example.com',
          ),
          'wss://relay2.example.com': RelayConnectionStatus.connecting(
            'wss://relay2.example.com',
          ),
        });
        async.flushMicrotasks();
        container
            .read(nostrInitializationInProgressProvider.notifier)
            .end(mockNostrClient);

        async.elapse(const Duration(seconds: 2));
        async.flushMicrotasks();

        verify(() => mockNostrClient.forceReconnectAll()).called(1);
        verify(() => mockVideoEventService.resetAndResubscribeAll()).called(1);
        container.dispose();
      });
    });

    test('keeps a pending relay edit for a same-account retry client', () {
      fakeAsync((async) {
        final replacementClient = MockNostrClient();
        final replacementStatuses =
            StreamController<Map<String, RelayConnectionStatus>>.broadcast();
        const removedRelay = 'wss://relay-old.example.com';
        const addedRelay = 'wss://relay1.example.com';
        final replacementRelays = <String>{defaultRelay, removedRelay};
        var replacementPublicKey = '';

        when(() => mockNostrClient.relayStatuses).thenReturn({
          defaultRelay: RelayConnectionStatus.connected(defaultRelay),
          removedRelay: RelayConnectionStatus.connected(removedRelay),
        });
        when(
          () => mockNostrClient.relayStatusStream,
        ).thenAnswer((_) => statusController.stream);
        when(() => replacementClient.isInitialized).thenReturn(true);
        when(
          () => replacementClient.publicKey,
        ).thenAnswer((_) => replacementPublicKey);
        when(() => replacementClient.defaultRelayUrl).thenReturn(defaultRelay);
        stubUserRemovedRelays(replacementClient);
        when(() => replacementClient.relayStatuses).thenAnswer(
          (_) => {
            for (final relay in replacementRelays)
              relay: RelayConnectionStatus.connected(relay),
          },
        );
        when(
          () => replacementClient.relayStatusStream,
        ).thenAnswer((_) => replacementStatuses.stream);
        when(
          () => replacementClient.configuredRelays,
        ).thenAnswer((_) => replacementRelays.toList());
        when(() => replacementClient.addRelays(any())).thenAnswer((call) async {
          final relays = call.positionalArguments.single as List<String>;
          replacementRelays.addAll(relays);
          return relays.length;
        });
        when(
          () => replacementClient.removeRelay(
            any(),
            source: any(named: 'source'),
          ),
        ).thenAnswer((call) async {
          final relay = call.positionalArguments.single as String;
          return replacementRelays.remove(relay);
        });
        when(replacementClient.forceReconnectAll).thenAnswer(
          (_) async => ForceReconnectOutcome.completed,
        );

        final swappableService = SwappableNostrService(mockNostrClient);
        final container = ProviderContainer(
          overrides: [
            nostrServiceProvider.overrideWith(() => swappableService),
            nostrSessionProvider.overrideWith(() => testNostrSession),
            videoEventServiceProvider.overrideWithValue(mockVideoEventService),
          ],
        );
        final bridgeSubscription = container.listen<void>(
          relaySetChangeBridgeProvider,
          (_, _) {},
          fireImmediately: true,
        );

        expect(mockNostrClient.publicKey, isEmpty);
        clientPublicKey = pubkeyA;
        testNostrSession.update(
          NostrSessionReadiness.nostrReady(
            pubkey: pubkeyA,
            client: mockNostrClient,
          ),
        );
        async.flushMicrotasks();

        statusController.add({
          defaultRelay: RelayConnectionStatus.connected(defaultRelay),
          addedRelay: RelayConnectionStatus.connected(addedRelay),
        });
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 1));

        swappableService.replaceWith(replacementClient);
        async.flushMicrotasks();
        expect(replacementClient.publicKey, isEmpty);
        verifyNever(() => replacementClient.addRelays(any()));
        verifyNever(replacementClient.forceReconnectAll);

        replacementPublicKey = pubkeyA;
        testNostrSession.update(
          NostrSessionReadiness.nostrReady(
            pubkey: pubkeyA,
            client: replacementClient,
          ),
        );
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 2));
        async.flushMicrotasks();

        expect(replacementRelays, contains(addedRelay));
        expect(replacementRelays, contains(defaultRelay));
        expect(replacementRelays, isNot(contains(removedRelay)));
        verify(() => replacementClient.addRelays([addedRelay])).called(1);
        verify(
          () => replacementClient.removeRelay(
            removedRelay,
            source: RelayRemoveSource.automatic,
          ),
        ).called(1);
        verifyNever(
          () => replacementClient.removeRelay(
            defaultRelay,
            source: any(named: 'source'),
          ),
        );
        verify(replacementClient.forceReconnectAll).called(1);
        verify(() => mockVideoEventService.resetAndResubscribeAll()).called(1);
        verifyNever(() => mockNostrClient.forceReconnectAll());

        bridgeSubscription.close();
        container.dispose();
        replacementStatuses.close();
      });
    });

    test(
      'reconciles a replacement client to a target without default relay',
      () {
        fakeAsync((async) {
          final replacementClient = MockNostrClient();
          final replacementStatuses =
              StreamController<Map<String, RelayConnectionStatus>>.broadcast();
          const removedRelay = 'wss://relay-old.example.com';
          const addedRelay = 'wss://relay1.example.com';
          final replacementRelays = <String>{defaultRelay, removedRelay};
          var replacementPublicKey = '';

          when(() => mockNostrClient.relayStatuses).thenReturn({
            defaultRelay: RelayConnectionStatus.connected(defaultRelay),
            removedRelay: RelayConnectionStatus.connected(removedRelay),
          });
          when(
            () => mockNostrClient.relayStatusStream,
          ).thenAnswer((_) => statusController.stream);
          when(() => replacementClient.isInitialized).thenReturn(true);
          when(
            () => replacementClient.publicKey,
          ).thenAnswer((_) => replacementPublicKey);
          when(
            () => replacementClient.defaultRelayUrl,
          ).thenReturn(defaultRelay);
          stubUserRemovedRelays(replacementClient);
          when(() => replacementClient.relayStatuses).thenAnswer(
            (_) => {
              for (final relay in replacementRelays)
                relay: RelayConnectionStatus.connected(relay),
            },
          );
          when(
            () => replacementClient.relayStatusStream,
          ).thenAnswer((_) => replacementStatuses.stream);
          when(
            () => replacementClient.configuredRelays,
          ).thenAnswer((_) => replacementRelays.toList());
          when(() => replacementClient.addRelays(any())).thenAnswer((
            call,
          ) async {
            final relays = call.positionalArguments.single as List<String>;
            replacementRelays.addAll(relays);
            return relays.length;
          });
          when(
            () => replacementClient.removeRelay(
              any(),
              source: any(named: 'source'),
            ),
          ).thenAnswer((call) async {
            final relay = call.positionalArguments.single as String;
            return replacementRelays.remove(relay);
          });
          when(replacementClient.forceReconnectAll).thenAnswer(
            (_) async => ForceReconnectOutcome.completed,
          );

          final swappableService = SwappableNostrService(mockNostrClient);
          final container = ProviderContainer(
            overrides: [
              nostrServiceProvider.overrideWith(() => swappableService),
              nostrSessionProvider.overrideWith(() => testNostrSession),
              videoEventServiceProvider.overrideWithValue(
                mockVideoEventService,
              ),
            ],
          );
          final bridgeSubscription = container.listen<void>(
            relaySetChangeBridgeProvider,
            (_, _) {},
            fireImmediately: true,
          );

          expect(mockNostrClient.publicKey, isEmpty);
          clientPublicKey = pubkeyA;
          testNostrSession.update(
            NostrSessionReadiness.nostrReady(
              pubkey: pubkeyA,
              client: mockNostrClient,
            ),
          );
          async.flushMicrotasks();

          statusController.add({
            addedRelay: RelayConnectionStatus.connected(addedRelay),
          });
          async.flushMicrotasks();
          async.elapse(const Duration(seconds: 1));

          swappableService.replaceWith(replacementClient);
          async.flushMicrotasks();
          expect(replacementClient.publicKey, isEmpty);
          verifyNever(() => replacementClient.addRelays(any()));
          verifyNever(replacementClient.forceReconnectAll);

          replacementPublicKey = pubkeyA;
          testNostrSession.update(
            NostrSessionReadiness.nostrReady(
              pubkey: pubkeyA,
              client: replacementClient,
            ),
          );
          async.flushMicrotasks();
          async.elapse(const Duration(seconds: 2));
          async.flushMicrotasks();

          expect(replacementRelays, equals({addedRelay}));
          verify(() => replacementClient.addRelays([addedRelay])).called(1);
          verify(
            () => replacementClient.removeRelay(
              removedRelay,
              source: RelayRemoveSource.automatic,
            ),
          ).called(1);
          verify(
            () => replacementClient.removeRelay(
              defaultRelay,
              source: RelayRemoveSource.automatic,
            ),
          ).called(1);
          verify(replacementClient.forceReconnectAll).called(1);
          verify(
            () => mockVideoEventService.resetAndResubscribeAll(),
          ).called(1);
          verifyNever(() => mockNostrClient.forceReconnectAll());

          bridgeSubscription.close();
          container.dispose();
          replacementStatuses.close();
        });
      },
    );

    test('discards a pending relay edit when the environment changes', () {
      fakeAsync((async) {
        final replacementClient = MockNostrClient();
        final replacementStatuses =
            StreamController<Map<String, RelayConnectionStatus>>.broadcast();
        const stagingDefault = 'wss://relay.staging.divine.video';
        const editedRelay = 'wss://user-relay.example.com';
        final replacementRelays = <String>{stagingDefault};

        when(() => mockNostrClient.relayStatuses).thenReturn({
          defaultRelay: RelayConnectionStatus.connected(defaultRelay),
        });
        when(
          () => mockNostrClient.relayStatusStream,
        ).thenAnswer((_) => statusController.stream);
        when(() => replacementClient.isInitialized).thenReturn(true);
        stubClientScope(replacementClient, relay: stagingDefault);
        when(() => replacementClient.relayStatuses).thenAnswer(
          (_) => {
            for (final relay in replacementRelays)
              relay: RelayConnectionStatus.connected(relay),
          },
        );
        when(
          () => replacementClient.relayStatusStream,
        ).thenAnswer((_) => replacementStatuses.stream);
        when(
          () => replacementClient.configuredRelays,
        ).thenAnswer((_) => replacementRelays.toList());
        when(
          () => replacementClient.addRelays(any()),
        ).thenAnswer((_) async => 1);
        when(
          () => replacementClient.removeRelay(
            any(),
            source: any(named: 'source'),
          ),
        ).thenAnswer((_) async => true);
        when(replacementClient.forceReconnectAll).thenAnswer(
          (_) async => ForceReconnectOutcome.completed,
        );

        final swappableService = SwappableNostrService(mockNostrClient);
        final container = ProviderContainer(
          overrides: [
            nostrServiceProvider.overrideWith(() => swappableService),
            nostrSessionProvider.overrideWith(() => testNostrSession),
            videoEventServiceProvider.overrideWithValue(mockVideoEventService),
          ],
        );
        final bridgeSubscription = container.listen<void>(
          relaySetChangeBridgeProvider,
          (_, _) {},
          fireImmediately: true,
        );

        statusController.add({
          defaultRelay: RelayConnectionStatus.connected(defaultRelay),
          editedRelay: RelayConnectionStatus.connected(editedRelay),
        });
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 1));
        swappableService.replaceWith(replacementClient);
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 2));
        async.flushMicrotasks();

        expect(replacementRelays, equals({stagingDefault}));
        verifyNever(() => replacementClient.addRelays(any()));
        verifyNever(
          () => replacementClient.removeRelay(
            any(),
            source: any(named: 'source'),
          ),
        );
        verifyNever(replacementClient.forceReconnectAll);
        verifyNever(() => mockVideoEventService.resetAndResubscribeAll());

        bridgeSubscription.close();
        container.dispose();
        replacementStatuses.close();
      });
    });

    test('discards a pending relay edit when the identity changes', () {
      fakeAsync((async) {
        final replacementClient = MockNostrClient();
        final replacementStatuses =
            StreamController<Map<String, RelayConnectionStatus>>.broadcast();
        const editedRelay = 'wss://user-relay.example.com';
        final replacementRelays = <String>{defaultRelay};
        var replacementPublicKey = '';

        when(() => mockNostrClient.relayStatuses).thenReturn({
          defaultRelay: RelayConnectionStatus.connected(defaultRelay),
        });
        when(
          () => mockNostrClient.relayStatusStream,
        ).thenAnswer((_) => statusController.stream);
        when(() => replacementClient.isInitialized).thenReturn(true);
        when(
          () => replacementClient.publicKey,
        ).thenAnswer((_) => replacementPublicKey);
        when(() => replacementClient.defaultRelayUrl).thenReturn(defaultRelay);
        stubUserRemovedRelays(replacementClient);
        when(() => replacementClient.relayStatuses).thenAnswer(
          (_) => {
            for (final relay in replacementRelays)
              relay: RelayConnectionStatus.connected(relay),
          },
        );
        when(
          () => replacementClient.relayStatusStream,
        ).thenAnswer((_) => replacementStatuses.stream);
        when(
          () => replacementClient.configuredRelays,
        ).thenAnswer((_) => replacementRelays.toList());
        when(
          () => replacementClient.addRelays(any()),
        ).thenAnswer((_) async => 1);
        when(
          () => replacementClient.removeRelay(
            any(),
            source: any(named: 'source'),
          ),
        ).thenAnswer((_) async => true);
        when(replacementClient.forceReconnectAll).thenAnswer(
          (_) async => ForceReconnectOutcome.completed,
        );

        final swappableService = SwappableNostrService(mockNostrClient);
        final container = ProviderContainer(
          overrides: [
            nostrServiceProvider.overrideWith(() => swappableService),
            nostrSessionProvider.overrideWith(() => testNostrSession),
            videoEventServiceProvider.overrideWithValue(mockVideoEventService),
          ],
        );
        final bridgeSubscription = container.listen<void>(
          relaySetChangeBridgeProvider,
          (_, _) {},
          fireImmediately: true,
        );

        expect(mockNostrClient.publicKey, isEmpty);
        clientPublicKey = pubkeyA;
        testNostrSession.update(
          NostrSessionReadiness.nostrReady(
            pubkey: pubkeyA,
            client: mockNostrClient,
          ),
        );
        async.flushMicrotasks();

        statusController.add({
          defaultRelay: RelayConnectionStatus.connected(defaultRelay),
          editedRelay: RelayConnectionStatus.connected(editedRelay),
        });
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 1));

        testNostrSession.update(
          const NostrSessionReadiness.tearingDown(pubkey: pubkeyA),
        );
        async.flushMicrotasks();
        swappableService.replaceWith(replacementClient);
        async.flushMicrotasks();
        expect(replacementClient.publicKey, isEmpty);

        replacementPublicKey = pubkeyB;
        testNostrSession.update(
          const NostrSessionReadiness.identityKnown(pubkey: pubkeyB),
        );
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 2));
        async.flushMicrotasks();

        expect(replacementRelays, equals({defaultRelay}));
        verifyNever(() => replacementClient.addRelays(any()));
        verifyNever(
          () => replacementClient.removeRelay(
            any(),
            source: any(named: 'source'),
          ),
        );
        verifyNever(replacementClient.forceReconnectAll);
        verifyNever(() => mockVideoEventService.resetAndResubscribeAll());

        bridgeSubscription.close();
        container.dispose();
        replacementStatuses.close();
      });
    });

    test('retries a partial replacement reconciliation before reset', () {
      fakeAsync((async) {
        final replacementClient = MockNostrClient();
        final replacementStatuses =
            StreamController<Map<String, RelayConnectionStatus>>.broadcast();
        const editedRelay = 'wss://user-relay.example.com';
        final replacementRelays = <String>{defaultRelay};
        var addAttempts = 0;

        when(() => mockNostrClient.relayStatuses).thenReturn({
          defaultRelay: RelayConnectionStatus.connected(defaultRelay),
        });
        when(
          () => mockNostrClient.relayStatusStream,
        ).thenAnswer((_) => statusController.stream);
        when(() => replacementClient.isInitialized).thenReturn(true);
        stubClientScope(replacementClient);
        when(() => replacementClient.relayStatuses).thenAnswer(
          (_) => {
            for (final relay in replacementRelays)
              relay: RelayConnectionStatus.connected(relay),
          },
        );
        when(
          () => replacementClient.relayStatusStream,
        ).thenAnswer((_) => replacementStatuses.stream);
        when(
          () => replacementClient.configuredRelays,
        ).thenAnswer((_) => replacementRelays.toList());
        when(() => replacementClient.addRelays(any())).thenAnswer((call) async {
          addAttempts++;
          if (addAttempts == 1) return 0;
          replacementRelays.addAll(
            call.positionalArguments.single as List<String>,
          );
          return 1;
        });
        when(replacementClient.forceReconnectAll).thenAnswer(
          (_) async => ForceReconnectOutcome.completed,
        );

        final swappableService = SwappableNostrService(mockNostrClient);
        final container = ProviderContainer(
          overrides: [
            nostrServiceProvider.overrideWith(() => swappableService),
            nostrSessionProvider.overrideWith(() => testNostrSession),
            videoEventServiceProvider.overrideWithValue(mockVideoEventService),
          ],
        );
        final bridgeSubscription = container.listen<void>(
          relaySetChangeBridgeProvider,
          (_, _) {},
          fireImmediately: true,
        );

        statusController.add({
          defaultRelay: RelayConnectionStatus.connected(defaultRelay),
          editedRelay: RelayConnectionStatus.connected(editedRelay),
        });
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 1));
        swappableService.replaceWith(replacementClient);
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();

        verifyNever(replacementClient.forceReconnectAll);
        verifyNever(() => mockVideoEventService.resetAndResubscribeAll());

        async.elapse(const Duration(seconds: 2));
        async.flushMicrotasks();

        expect(replacementRelays, contains(editedRelay));
        verify(() => replacementClient.addRelays([editedRelay])).called(2);
        verify(replacementClient.forceReconnectAll).called(1);
        verify(() => mockVideoEventService.resetAndResubscribeAll()).called(1);

        bridgeSubscription.close();
        container.dispose();
        replacementStatuses.close();
      });
    });

    test(
      'skips user-suppressed additions while reconciling a replacement client',
      () {
        fakeAsync((async) {
          final replacementClient = MockNostrClient();
          final replacementStatuses =
              StreamController<Map<String, RelayConnectionStatus>>.broadcast();
          const suppressedRelay = 'wss://removed.example.com';
          const retainedRelay = 'wss://retained.example.com';
          final replacementRelays = <String>{defaultRelay};

          when(() => mockNostrClient.relayStatuses).thenReturn({
            defaultRelay: RelayConnectionStatus.connected(defaultRelay),
          });
          when(
            () => mockNostrClient.relayStatusStream,
          ).thenAnswer((_) => statusController.stream);
          when(() => replacementClient.isInitialized).thenReturn(true);
          stubClientScope(replacementClient);
          stubUserRemovedRelays(replacementClient, relays: {suppressedRelay});
          when(() => replacementClient.relayStatuses).thenAnswer(
            (_) => {
              for (final relay in replacementRelays)
                relay: RelayConnectionStatus.connected(relay),
            },
          );
          when(
            () => replacementClient.relayStatusStream,
          ).thenAnswer((_) => replacementStatuses.stream);
          when(
            () => replacementClient.configuredRelays,
          ).thenAnswer((_) => replacementRelays.toList());
          when(() => replacementClient.addRelays(any())).thenAnswer((
            call,
          ) async {
            final relays = call.positionalArguments.single as List<String>;
            replacementRelays.addAll(relays);
            return relays.length;
          });
          when(
            () => replacementClient.removeRelay(
              any(),
              source: any(named: 'source'),
            ),
          ).thenAnswer((call) async {
            final relay = call.positionalArguments.single as String;
            return replacementRelays.remove(relay);
          });
          when(replacementClient.forceReconnectAll).thenAnswer(
            (_) async => ForceReconnectOutcome.completed,
          );

          final swappableService = SwappableNostrService(mockNostrClient);
          final container = ProviderContainer(
            overrides: [
              nostrServiceProvider.overrideWith(() => swappableService),
              nostrSessionProvider.overrideWith(() => testNostrSession),
              videoEventServiceProvider.overrideWithValue(
                mockVideoEventService,
              ),
            ],
          );
          final bridgeSubscription = container.listen<void>(
            relaySetChangeBridgeProvider,
            (_, _) {},
            fireImmediately: true,
          );

          statusController.add({
            defaultRelay: RelayConnectionStatus.connected(defaultRelay),
            retainedRelay: RelayConnectionStatus.connected(retainedRelay),
            suppressedRelay: RelayConnectionStatus.connected(suppressedRelay),
          });
          async.flushMicrotasks();
          async.elapse(const Duration(seconds: 1));
          swappableService.replaceWith(replacementClient);
          async.flushMicrotasks();
          async.elapse(const Duration(seconds: 2));
          async.flushMicrotasks();

          expect(replacementRelays, contains(retainedRelay));
          expect(replacementRelays, isNot(contains(suppressedRelay)));
          verify(
            () => replacementClient.isUserRemovedRelay(suppressedRelay),
          ).called(1);
          verify(() => replacementClient.addRelays([retainedRelay])).called(1);
          verify(replacementClient.forceReconnectAll).called(1);
          verify(
            () => mockVideoEventService.resetAndResubscribeAll(),
          ).called(1);

          bridgeSubscription.close();
          container.dispose();
          replacementStatuses.close();
        });
      },
    );

    test('retries a thrown replacement reconciliation before reset', () {
      fakeAsync((async) {
        final replacementClient = MockNostrClient();
        final replacementStatuses =
            StreamController<Map<String, RelayConnectionStatus>>.broadcast();
        const editedRelay = 'wss://user-relay.example.com';
        final replacementRelays = <String>{defaultRelay};
        var addAttempts = 0;

        when(() => mockNostrClient.relayStatuses).thenReturn({
          defaultRelay: RelayConnectionStatus.connected(defaultRelay),
        });
        when(
          () => mockNostrClient.relayStatusStream,
        ).thenAnswer((_) => statusController.stream);
        when(() => replacementClient.isInitialized).thenReturn(true);
        stubClientScope(replacementClient);
        when(() => replacementClient.relayStatuses).thenAnswer(
          (_) => {
            for (final relay in replacementRelays)
              relay: RelayConnectionStatus.connected(relay),
          },
        );
        when(
          () => replacementClient.relayStatusStream,
        ).thenAnswer((_) => replacementStatuses.stream);
        when(
          () => replacementClient.configuredRelays,
        ).thenAnswer((_) => replacementRelays.toList());
        when(() => replacementClient.addRelays(any())).thenAnswer((call) async {
          addAttempts++;
          if (addAttempts == 1) throw StateError('storage unavailable');
          replacementRelays.addAll(
            call.positionalArguments.single as List<String>,
          );
          return 1;
        });
        when(replacementClient.forceReconnectAll).thenAnswer(
          (_) async => ForceReconnectOutcome.completed,
        );

        final swappableService = SwappableNostrService(mockNostrClient);
        final container = ProviderContainer(
          overrides: [
            nostrServiceProvider.overrideWith(() => swappableService),
            nostrSessionProvider.overrideWith(() => testNostrSession),
            videoEventServiceProvider.overrideWithValue(mockVideoEventService),
          ],
        );
        final bridgeSubscription = container.listen<void>(
          relaySetChangeBridgeProvider,
          (_, _) {},
          fireImmediately: true,
        );

        statusController.add({
          defaultRelay: RelayConnectionStatus.connected(defaultRelay),
          editedRelay: RelayConnectionStatus.connected(editedRelay),
        });
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 1));
        swappableService.replaceWith(replacementClient);
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();

        verifyNever(replacementClient.forceReconnectAll);
        async.elapse(const Duration(seconds: 2));
        async.flushMicrotasks();

        verify(() => replacementClient.addRelays([editedRelay])).called(2);
        verify(replacementClient.forceReconnectAll).called(1);
        verify(() => mockVideoEventService.resetAndResubscribeAll()).called(1);

        bridgeSubscription.close();
        container.dispose();
        replacementStatuses.close();
      });
    });

    test('retries a failed relay removal before reset', () {
      fakeAsync((async) {
        final replacementClient = MockNostrClient();
        final replacementStatuses =
            StreamController<Map<String, RelayConnectionStatus>>.broadcast();
        const removedRelay = 'wss://relay-old.example.com';
        const editedRelay = 'wss://user-relay.example.com';
        final replacementRelays = <String>{defaultRelay, removedRelay};
        var removeAttempts = 0;

        when(() => mockNostrClient.relayStatuses).thenReturn({
          defaultRelay: RelayConnectionStatus.connected(defaultRelay),
          removedRelay: RelayConnectionStatus.connected(removedRelay),
        });
        when(
          () => mockNostrClient.relayStatusStream,
        ).thenAnswer((_) => statusController.stream);
        when(() => replacementClient.isInitialized).thenReturn(true);
        stubClientScope(replacementClient);
        when(() => replacementClient.relayStatuses).thenAnswer(
          (_) => {
            for (final relay in replacementRelays)
              relay: RelayConnectionStatus.connected(relay),
          },
        );
        when(
          () => replacementClient.relayStatusStream,
        ).thenAnswer((_) => replacementStatuses.stream);
        when(
          () => replacementClient.configuredRelays,
        ).thenAnswer((_) => replacementRelays.toList());
        when(() => replacementClient.addRelays(any())).thenAnswer((call) async {
          replacementRelays.addAll(
            call.positionalArguments.single as List<String>,
          );
          return 1;
        });
        when(
          () => replacementClient.removeRelay(
            removedRelay,
            source: any(named: 'source'),
          ),
        ).thenAnswer((_) async {
          removeAttempts++;
          if (removeAttempts == 1) return false;
          return replacementRelays.remove(removedRelay);
        });
        when(replacementClient.forceReconnectAll).thenAnswer(
          (_) async => ForceReconnectOutcome.completed,
        );

        final swappableService = SwappableNostrService(mockNostrClient);
        final container = ProviderContainer(
          overrides: [
            nostrServiceProvider.overrideWith(() => swappableService),
            nostrSessionProvider.overrideWith(() => testNostrSession),
            videoEventServiceProvider.overrideWithValue(mockVideoEventService),
          ],
        );
        final bridgeSubscription = container.listen<void>(
          relaySetChangeBridgeProvider,
          (_, _) {},
          fireImmediately: true,
        );

        statusController.add({
          defaultRelay: RelayConnectionStatus.connected(defaultRelay),
          editedRelay: RelayConnectionStatus.connected(editedRelay),
        });
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 1));
        swappableService.replaceWith(replacementClient);
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();

        verifyNever(replacementClient.forceReconnectAll);
        async.elapse(const Duration(seconds: 2));
        async.flushMicrotasks();

        expect(replacementRelays, containsAll({defaultRelay, editedRelay}));
        expect(replacementRelays, isNot(contains(removedRelay)));
        verify(() => replacementClient.addRelays([editedRelay])).called(1);
        verify(
          () => replacementClient.removeRelay(
            removedRelay,
            source: RelayRemoveSource.automatic,
          ),
        ).called(2);
        verify(replacementClient.forceReconnectAll).called(1);
        verify(() => mockVideoEventService.resetAndResubscribeAll()).called(1);

        bridgeSubscription.close();
        container.dispose();
        replacementStatuses.close();
      });
    });

    test('does not retry an ordinary reconnect failure', () {
      fakeAsync((async) {
        final replacementClient = MockNostrClient();
        final replacementStatuses =
            StreamController<Map<String, RelayConnectionStatus>>.broadcast();
        const editedRelay = 'wss://user-relay.example.com';
        final replacementRelays = <String>{defaultRelay};

        when(() => mockNostrClient.relayStatuses).thenReturn({
          defaultRelay: RelayConnectionStatus.connected(defaultRelay),
        });
        when(
          () => mockNostrClient.relayStatusStream,
        ).thenAnswer((_) => statusController.stream);
        when(() => replacementClient.isInitialized).thenReturn(true);
        stubClientScope(replacementClient);
        when(() => replacementClient.relayStatuses).thenAnswer(
          (_) => {
            for (final relay in replacementRelays)
              relay: RelayConnectionStatus.connected(relay),
          },
        );
        when(
          () => replacementClient.relayStatusStream,
        ).thenAnswer((_) => replacementStatuses.stream);
        when(
          () => replacementClient.configuredRelays,
        ).thenAnswer((_) => replacementRelays.toList());
        when(() => replacementClient.addRelays(any())).thenAnswer((call) async {
          replacementRelays.addAll(
            call.positionalArguments.single as List<String>,
          );
          return 1;
        });
        when(
          replacementClient.forceReconnectAll,
        ).thenThrow(StateError('socket unavailable'));

        final swappableService = SwappableNostrService(mockNostrClient);
        final container = ProviderContainer(
          overrides: [
            nostrServiceProvider.overrideWith(() => swappableService),
            nostrSessionProvider.overrideWith(() => testNostrSession),
            videoEventServiceProvider.overrideWithValue(mockVideoEventService),
          ],
        );
        final bridgeSubscription = container.listen<void>(
          relaySetChangeBridgeProvider,
          (_, _) {},
          fireImmediately: true,
        );

        statusController.add({
          defaultRelay: RelayConnectionStatus.connected(defaultRelay),
          editedRelay: RelayConnectionStatus.connected(editedRelay),
        });
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 1));
        swappableService.replaceWith(replacementClient);
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 6));
        async.flushMicrotasks();

        verify(replacementClient.forceReconnectAll).called(1);
        verify(() => mockVideoEventService.resetAndResubscribeAll()).called(1);

        bridgeSubscription.close();
        container.dispose();
        replacementStatuses.close();
      });
    });

    test('bounds retries for a persistently invalid relay target', () {
      fakeAsync((async) {
        final replacementClient = MockNostrClient();
        final replacementStatuses =
            StreamController<Map<String, RelayConnectionStatus>>.broadcast();
        const editedRelay = 'wss://invalid-relay.example.com';
        final replacementRelays = <String>{defaultRelay};

        when(() => mockNostrClient.relayStatuses).thenReturn({
          defaultRelay: RelayConnectionStatus.connected(defaultRelay),
        });
        when(
          () => mockNostrClient.relayStatusStream,
        ).thenAnswer((_) => statusController.stream);
        when(() => replacementClient.isInitialized).thenReturn(true);
        stubClientScope(replacementClient);
        when(() => replacementClient.relayStatuses).thenAnswer(
          (_) => {
            for (final relay in replacementRelays)
              relay: RelayConnectionStatus.connected(relay),
          },
        );
        when(
          () => replacementClient.relayStatusStream,
        ).thenAnswer((_) => replacementStatuses.stream);
        when(
          () => replacementClient.configuredRelays,
        ).thenAnswer((_) => replacementRelays.toList());
        when(
          () => replacementClient.addRelays(any()),
        ).thenAnswer((_) async => 0);

        final swappableService = SwappableNostrService(mockNostrClient);
        final container = ProviderContainer(
          overrides: [
            nostrServiceProvider.overrideWith(() => swappableService),
            nostrSessionProvider.overrideWith(() => testNostrSession),
            videoEventServiceProvider.overrideWithValue(mockVideoEventService),
          ],
        );
        final bridgeSubscription = container.listen<void>(
          relaySetChangeBridgeProvider,
          (_, _) {},
          fireImmediately: true,
        );

        statusController.add({
          defaultRelay: RelayConnectionStatus.connected(defaultRelay),
          editedRelay: RelayConnectionStatus.connected(editedRelay),
        });
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 1));
        swappableService.replaceWith(replacementClient);
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 7));
        async.flushMicrotasks();

        verify(() => replacementClient.addRelays([editedRelay])).called(2);
        verifyNever(replacementClient.forceReconnectAll);
        verifyNever(() => mockVideoEventService.resetAndResubscribeAll());

        bridgeSubscription.close();
        container.dispose();
        replacementStatuses.close();
      });
    });

    test('moves an in-flight transaction to a newer same-scope client', () {
      fakeAsync((async) {
        final firstReplacement = MockNostrClient();
        final secondReplacement = MockNostrClient();
        final firstStatuses =
            StreamController<Map<String, RelayConnectionStatus>>.broadcast();
        final secondStatuses =
            StreamController<Map<String, RelayConnectionStatus>>.broadcast();
        final firstAddGate = Completer<void>();
        const editedRelay = 'wss://user-relay.example.com';
        final firstRelays = <String>{defaultRelay};
        final secondRelays = <String>{defaultRelay};

        when(() => mockNostrClient.relayStatuses).thenReturn({
          defaultRelay: RelayConnectionStatus.connected(defaultRelay),
        });
        when(
          () => mockNostrClient.relayStatusStream,
        ).thenAnswer((_) => statusController.stream);

        for (final client in [firstReplacement, secondReplacement]) {
          when(() => client.isInitialized).thenReturn(true);
          stubClientScope(client);
          when(client.forceReconnectAll).thenAnswer(
            (_) async => ForceReconnectOutcome.completed,
          );
        }
        when(() => firstReplacement.relayStatuses).thenAnswer(
          (_) => {
            for (final relay in firstRelays)
              relay: RelayConnectionStatus.connected(relay),
          },
        );
        when(
          () => firstReplacement.relayStatusStream,
        ).thenAnswer((_) => firstStatuses.stream);
        when(
          () => firstReplacement.configuredRelays,
        ).thenAnswer((_) => firstRelays.toList());
        when(() => firstReplacement.addRelays(any())).thenAnswer((call) async {
          await firstAddGate.future;
          firstRelays.addAll(call.positionalArguments.single as List<String>);
          return 1;
        });
        when(() => secondReplacement.relayStatuses).thenAnswer(
          (_) => {
            for (final relay in secondRelays)
              relay: RelayConnectionStatus.connected(relay),
          },
        );
        when(
          () => secondReplacement.relayStatusStream,
        ).thenAnswer((_) => secondStatuses.stream);
        when(
          () => secondReplacement.configuredRelays,
        ).thenAnswer((_) => secondRelays.toList());
        when(() => secondReplacement.addRelays(any())).thenAnswer((call) async {
          secondRelays.addAll(call.positionalArguments.single as List<String>);
          return 1;
        });

        final swappableService = SwappableNostrService(mockNostrClient);
        final container = ProviderContainer(
          overrides: [
            nostrServiceProvider.overrideWith(() => swappableService),
            nostrSessionProvider.overrideWith(() => testNostrSession),
            videoEventServiceProvider.overrideWithValue(mockVideoEventService),
          ],
        );
        final bridgeSubscription = container.listen<void>(
          relaySetChangeBridgeProvider,
          (_, _) {},
          fireImmediately: true,
        );

        statusController.add({
          defaultRelay: RelayConnectionStatus.connected(defaultRelay),
          editedRelay: RelayConnectionStatus.connected(editedRelay),
        });
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 1));
        swappableService.replaceWith(firstReplacement);
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();

        verify(() => firstReplacement.addRelays([editedRelay])).called(1);
        swappableService.replaceWith(secondReplacement);
        async.flushMicrotasks();
        async.elapse(Duration.zero);
        firstAddGate.complete();
        async.flushMicrotasks();

        verifyNever(firstReplacement.forceReconnectAll);
        verifyNever(secondReplacement.forceReconnectAll);
        verifyNever(() => mockVideoEventService.resetAndResubscribeAll());

        async.elapse(const Duration(seconds: 2));
        async.flushMicrotasks();

        expect(secondRelays, contains(editedRelay));
        verify(() => secondReplacement.addRelays([editedRelay])).called(1);
        verifyNever(firstReplacement.forceReconnectAll);
        verify(secondReplacement.forceReconnectAll).called(1);
        verify(() => mockVideoEventService.resetAndResubscribeAll()).called(1);

        bridgeSubscription.close();
        container.dispose();
        firstStatuses.close();
        secondStatuses.close();
      });
    });
  });
}
