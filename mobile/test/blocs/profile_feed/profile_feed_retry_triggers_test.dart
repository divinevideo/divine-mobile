import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/blocs/profile_feed/profile_feed_retry_triggers.dart';
import 'package:openvine/services/connectivity_transition_monitor.dart';

const _relay = 'wss://relay.example.com';

Map<String, RelayConnectionStatus> _snapshot(RelayState state) => {
  _relay: RelayConnectionStatus(url: _relay, state: state),
};

void main() {
  group('profileFeedRetryTriggers', () {
    late StreamController<Map<String, RelayConnectionStatus>> relayStatuses;
    late StreamController<ConnectivityTransition> connectivity;
    late StreamController<void> foregroundResumes;
    late int signals;

    setUp(() {
      // Broadcast, like the sources the scope passes in.
      relayStatuses =
          StreamController<Map<String, RelayConnectionStatus>>.broadcast();
      connectivity = StreamController<ConnectivityTransition>.broadcast();
      foregroundResumes = StreamController<void>.broadcast();
      signals = 0;
      final subscription = profileFeedRetryTriggers(
        relayStatuses: relayStatuses.stream,
        initialRelayStatuses: _snapshot(RelayState.disconnected),
        connectivity: connectivity.stream,
        foregroundResumes: foregroundResumes.stream,
      ).listen((_) => signals++);
      addTearDown(subscription.cancel);
      addTearDown(relayStatuses.close);
      addTearDown(connectivity.close);
      addTearDown(foregroundResumes.close);
    });

    test('signals when a relay connects', () async {
      relayStatuses.add(_snapshot(RelayState.connected));
      await pumpEventQueue();

      expect(signals, equals(1));
    });

    test('signals when the network comes back', () async {
      connectivity.add(ConnectivityTransition.online);
      await pumpEventQueue();

      expect(signals, equals(1));
    });

    test('stays quiet when the network goes away', () async {
      connectivity.add(ConnectivityTransition.offline);
      relayStatuses.add(_snapshot(RelayState.disconnected));
      await pumpEventQueue();

      expect(signals, isZero);
    });

    test('signals when the app returns to the foreground', () async {
      foregroundResumes.add(null);
      await pumpEventQueue();

      expect(signals, equals(1));
    });

    test('serves profiles that come and go, several at a time', () async {
      final triggers = profileFeedRetryTriggers(
        relayStatuses: relayStatuses.stream,
        initialRelayStatuses: _snapshot(RelayState.disconnected),
        connectivity: connectivity.stream,
        foregroundResumes: foregroundResumes.stream,
      );
      var first = 0;
      var second = 0;
      var later = 0;
      final a = triggers.listen((_) => first++);
      final b = triggers.listen((_) => second++);
      foregroundResumes.add(null);
      await pumpEventQueue();
      await a.cancel();
      await b.cancel();

      final c = triggers.listen((_) => later++);
      addTearDown(c.cancel);
      foregroundResumes.add(null);
      await pumpEventQueue();

      expect((first, second, later), equals((1, 1, 1)));
    });
  });
}
