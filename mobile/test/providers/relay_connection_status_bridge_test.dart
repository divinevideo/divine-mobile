// ABOUTME: Tests that relayConnectionStatusBridge feeds ConnectionStatusService
// ABOUTME: from the client's relay statuses, so isOnline can reach false (#8331).

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/relay_providers.dart';
import 'package:openvine/services/connection_status_service.dart';

class _MockNostrClient extends Mock implements NostrClient {}

const _grace = Duration(seconds: 3);
const _one = 'wss://relay.one';
const _two = 'wss://relay.two';

RelayConnectionStatus _status(String url, RelayState state) =>
    RelayConnectionStatus(url: url, state: state);

void main() {
  group('relayConnectionStatusBridge', () {
    late _MockNostrClient client;
    late StreamController<Map<String, RelayConnectionStatus>> statuses;
    late ConnectionStatusService service;

    setUp(() {
      client = _MockNostrClient();
      statuses =
          StreamController<Map<String, RelayConnectionStatus>>.broadcast();
      service = ConnectionStatusService(offlineGrace: _grace);
      when(() => client.relayStatusStream).thenAnswer((_) => statuses.stream);
    });

    tearDown(() async {
      service.dispose();
      await statuses.close();
    });

    ProviderContainer createContainer({
      Map<String, RelayConnectionStatus> seed = const {},
    }) {
      when(() => client.relayStatuses).thenReturn(seed);
      final container = ProviderContainer(
        overrides: [
          nostrServiceProvider.overrideWithValue(client),
          connectionStatusServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);
      container.read(relayConnectionStatusBridgeProvider);
      return container;
    }

    test('seeds from the statuses the client already holds', () {
      createContainer(seed: {_one: _status(_one, RelayState.connected)});

      expect(service.totalRelayCount, equals(1));
      expect(service.connectedRelayCount, equals(1));
      expect(service.isOnline, isTrue);
    });

    test('drives isOnline to false once every relay drops', () {
      fakeAsync((async) {
        createContainer(seed: {_one: _status(_one, RelayState.connected)});
        expect(service.isOnline, isTrue, reason: 'seeded connected');

        statuses.add({_one: _status(_one, RelayState.disconnected)});
        async
          ..flushMicrotasks()
          ..elapse(_grace);

        expect(
          service.isOnline,
          isFalse,
          reason: 'this is the transition #8331 could never reach',
        );
      });
    });

    test('recovers as soon as a relay reconnects', () {
      fakeAsync((async) {
        createContainer(seed: {_one: _status(_one, RelayState.connected)});

        statuses.add({_one: _status(_one, RelayState.disconnected)});
        async
          ..flushMicrotasks()
          ..elapse(_grace);
        expect(service.isOnline, isFalse);

        statuses.add({_one: _status(_one, RelayState.connected)});
        async.flushMicrotasks();

        expect(service.isOnline, isTrue);
      });
    });

    test('counts an authenticated relay as reachable', () {
      fakeAsync((async) {
        createContainer(seed: {_one: _status(_one, RelayState.connected)});

        statuses.add({_one: _status(_one, RelayState.authenticated)});
        async
          ..flushMicrotasks()
          ..elapse(_grace);

        expect(service.isOnline, isTrue);
      });
    });

    test('a dialling relay does not count as reachable', () {
      fakeAsync((async) {
        createContainer(seed: {_one: _status(_one, RelayState.connected)});

        statuses.add({_one: _status(_one, RelayState.connecting)});
        async.flushMicrotasks();
        expect(service.isConnecting, isTrue);
        expect(service.isOnline, isTrue, reason: 'still inside the grace');

        async.elapse(_grace);
        expect(service.isOnline, isFalse);
      });
    });

    test('one relay staying up keeps the app online', () {
      fakeAsync((async) {
        createContainer(
          seed: {
            _one: _status(_one, RelayState.connected),
            _two: _status(_two, RelayState.connected),
          },
        );

        statuses.add({
          _one: _status(_one, RelayState.error),
          _two: _status(_two, RelayState.connected),
        });
        async
          ..flushMicrotasks()
          ..elapse(_grace);

        expect(service.isOnline, isTrue);
        expect(service.connectedRelayCount, equals(1));
      });
    });

    test('a relay leaving the pool is dropped, not remembered as up', () {
      fakeAsync((async) {
        createContainer(
          seed: {
            _one: _status(_one, RelayState.connected),
            _two: _status(_two, RelayState.disconnected),
          },
        );
        expect(service.totalRelayCount, equals(2));

        // The user removes relay.one, which was the only reachable relay.
        statuses.add({_two: _status(_two, RelayState.disconnected)});
        async
          ..flushMicrotasks()
          ..elapse(_grace);

        expect(service.totalRelayCount, equals(1));
        expect(service.isOnline, isFalse);
      });
    });
  });
}
