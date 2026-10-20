import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/utils/relay_connected_transitions.dart';

const _relayA = 'wss://a.example.com';
const _relayB = 'wss://b.example.com';

Map<String, RelayConnectionStatus> _snapshot(Map<String, RelayState> states) =>
    {
      for (final MapEntry(key: url, value: state) in states.entries)
        url: RelayConnectionStatus(url: url, state: state),
    };

void main() {
  group('relayConnectedTransitions', () {
    late StreamController<Map<String, RelayConnectionStatus>> statuses;
    late int emissions;

    void listen({
      Map<String, RelayState> initial = const {_relayA: RelayState.connected},
    }) {
      emissions = 0;
      final subscription = relayConnectedTransitions(
        statuses.stream,
        initial: _snapshot(initial),
      ).listen((_) => emissions++);
      addTearDown(subscription.cancel);
    }

    Future<void> push(Map<String, RelayState> states) async {
      statuses.add(_snapshot(states));
      await pumpEventQueue();
    }

    setUp(() {
      // Broadcast, like the pool's own status stream: a single-subscription
      // controller's close() never completes once its listener has cancelled.
      statuses =
          StreamController<Map<String, RelayConnectionStatus>>.broadcast();
      addTearDown(statuses.close);
    });

    test('emits when a disconnected relay connects', () async {
      listen(initial: const {_relayA: RelayState.disconnected});

      await push(const {_relayA: RelayState.connected});

      expect(emissions, 1);
    });

    test('stays quiet while the same relays stay connected', () async {
      listen();

      await push(const {_relayA: RelayState.connected});
      await push(const {_relayA: RelayState.authenticated});

      expect(emissions, 0);
    });

    test('stays quiet when a relay disconnects', () async {
      listen();

      await push(const {_relayA: RelayState.disconnected});
      await push(const {_relayA: RelayState.connecting});

      expect(emissions, 0);
    });

    test('emits again when a dropped relay reconnects', () async {
      listen();

      await push(const {_relayA: RelayState.disconnected});
      await push(const {_relayA: RelayState.connected});
      await push(const {_relayA: RelayState.error});
      await push(const {_relayA: RelayState.connected});

      expect(emissions, 2);
    });

    test('emits once for a snapshot in which several relays connect', () async {
      listen(
        initial: const {
          _relayA: RelayState.disconnected,
          _relayB: RelayState.disconnected,
        },
      );

      await push(const {
        _relayA: RelayState.connected,
        _relayB: RelayState.connected,
      });

      expect(emissions, 1);
    });

    test('emits when a relay added to the pool connects', () async {
      listen();

      await push(const {
        _relayA: RelayState.connected,
        _relayB: RelayState.connected,
      });

      expect(emissions, 1);
    });
  });
}
