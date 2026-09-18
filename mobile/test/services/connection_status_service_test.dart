// ABOUTME: Unit tests for ConnectionStatusService.
// ABOUTME: Pins the graced offline edge, the immediate online edge, and that
// ABOUTME: a whole-map update drops relays that left the pool (#8331).

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/connection_status_service.dart';

const _grace = Duration(seconds: 3);

ConnectionStatusService _service() =>
    ConnectionStatusService(offlineGrace: _grace);

void main() {
  group(ConnectionStatusService, () {
    group('lifecycle', () {
      test('notifies nothing on its own once constructed', () {
        fakeAsync((async) {
          final service = _service();
          addTearDown(service.dispose);

          var notifications = 0;
          service.addListener(() => notifications++);

          async.elapse(const Duration(minutes: 5));

          expect(notifications, isZero);
          expect(service.isConnecting, isFalse);
        });
      });

      test('completes its status stream on dispose', () async {
        final service = _service();
        final closed = expectLater(service.statusStream, emitsDone);

        service.dispose();

        await closed;
      });

      test('a pending offline edge cannot fire after dispose', () {
        fakeAsync((async) {
          final service = _service()
            ..updateRelayStatuses({'wss://relay.one': false});
          expect(service.isOnline, isTrue, reason: 'still inside the grace');

          service.dispose();
          async.elapse(_grace * 2);

          expect(service.isOnline, isTrue);
        });
      });
    });

    group('updateRelayStatuses', () {
      test('stays online until the grace window elapses', () {
        fakeAsync((async) {
          final service = _service();
          addTearDown(service.dispose);

          service.updateRelayStatuses({'wss://relay.one': false});
          expect(service.totalRelayCount, equals(1));
          expect(service.isOnline, isTrue, reason: 'grace has not elapsed');

          async.elapse(_grace - const Duration(milliseconds: 1));
          expect(service.isOnline, isTrue);

          async.elapse(const Duration(milliseconds: 1));
          expect(service.isOnline, isFalse);
          expect(service.connectedRelayCount, isZero);
        });
      });

      test('a reconnect inside the grace window cancels going offline', () {
        fakeAsync((async) {
          final service = _service();
          addTearDown(service.dispose);

          var notifications = 0;
          service.addListener(() => notifications++);

          service.updateRelayStatuses({'wss://relay.one': false});
          async.elapse(_grace ~/ 2);
          service.updateRelayStatuses({'wss://relay.one': true});
          async.elapse(_grace * 2);

          expect(service.isOnline, isTrue);
          expect(
            notifications,
            isZero,
            reason: 'never left online, so there was no edge to publish',
          );
        });
      });

      test('comes back online immediately, without waiting out a grace', () {
        fakeAsync((async) {
          final service = _service();
          addTearDown(service.dispose);

          service.updateRelayStatuses({'wss://relay.one': false});
          async.elapse(_grace);
          expect(service.isOnline, isFalse, reason: 'offline edge landed');

          service.updateRelayStatuses({'wss://relay.one': true});

          expect(service.isOnline, isTrue);
          expect(service.connectionHealth, equals(1.0));
        });
      });

      test('drops relays that are no longer in the pool', () {
        fakeAsync((async) {
          final service = _service();
          addTearDown(service.dispose);

          service.updateRelayStatuses({
            'wss://relay.one': true,
            'wss://relay.two': false,
          });
          expect(service.totalRelayCount, equals(2));

          // relay.one leaves the configured set while it was the only one up.
          service.updateRelayStatuses({'wss://relay.two': false});
          async.elapse(_grace);

          expect(service.totalRelayCount, equals(1));
          expect(
            service.isOnline,
            isFalse,
            reason: 'a departed relay must not keep the app online',
          );
        });
      });

      test('treats an empty pool as nothing known, not as offline', () {
        fakeAsync((async) {
          final service = _service();
          addTearDown(service.dispose);

          service.updateRelayStatuses(const {});
          async.elapse(_grace * 2);

          expect(service.isOnline, isTrue);
          expect(service.totalRelayCount, isZero);
        });
      });

      test('an armed offline edge is abandoned if the pool empties', () {
        fakeAsync((async) {
          final service = _service();
          addTearDown(service.dispose);

          service.updateRelayStatuses({'wss://relay.one': false});
          // The user clears their relay list mid-grace.
          service.updateRelayStatuses(const {});
          async.elapse(_grace * 2);

          expect(
            service.isOnline,
            isTrue,
            reason: 'an empty pool is not evidence of being offline',
          );
        });
      });

      test('publishes exactly one status event per edge', () {
        fakeAsync((async) {
          final service = _service();
          addTearDown(service.dispose);

          final emitted = <bool>[];
          service.statusStream.listen(emitted.add);

          service.updateRelayStatuses({
            'wss://relay.one': false,
            'wss://relay.two': false,
          });
          async.elapse(_grace);
          // Both relays return; only the first should be an edge.
          service.updateRelayStatuses({'wss://relay.one': true});
          service.updateRelayStatuses({
            'wss://relay.one': true,
            'wss://relay.two': true,
          });
          async
            ..flushMicrotasks()
            ..elapse(_grace);

          expect(emitted, equals([false, true]));
        });
      });

      test('fires reconnect callbacks only on the offline to online edge', () {
        fakeAsync((async) {
          final service = _service();
          addTearDown(service.dispose);

          var reconnects = 0;
          service.registerOnReconnectCallback(() => reconnects++);

          service.updateRelayStatuses({'wss://relay.one': false});
          async.elapse(_grace);
          expect(
            reconnects,
            isZero,
            reason: 'going offline is not a reconnect',
          );

          service.updateRelayStatuses({'wss://relay.one': true});
          expect(reconnects, equals(1));

          service.updateRelayStatuses({
            'wss://relay.one': true,
            'wss://relay.two': true,
          });
          expect(
            reconnects,
            equals(1),
            reason: 'a second relay joining is not another reconnect',
          );
        });
      });

      test('keeps firing later callbacks when one throws', () {
        fakeAsync((async) {
          final service = _service();
          addTearDown(service.dispose);

          var survived = 0;
          service
            ..registerOnReconnectCallback(() => throw StateError('boom'))
            ..registerOnReconnectCallback(() => survived++)
            ..updateRelayStatuses({'wss://relay.one': false});
          async.elapse(_grace);
          service.updateRelayStatuses({'wss://relay.one': true});

          expect(survived, equals(1));
        });
      });

      test('stops calling a callback once it is unregistered', () {
        fakeAsync((async) {
          final service = _service();
          addTearDown(service.dispose);

          var reconnects = 0;
          final unregister = service.registerOnReconnectCallback(
            () => reconnects++,
          );

          service.updateRelayStatuses({'wss://relay.one': false});
          async.elapse(_grace);
          unregister();
          service.updateRelayStatuses({'wss://relay.one': true});

          expect(reconnects, isZero);
        });
      });
    });

    group('setConnecting', () {
      test('notifies only when the dialling state actually changes', () {
        final service = _service();
        addTearDown(service.dispose);

        var notifications = 0;
        service.addListener(() => notifications++);

        service.setConnecting(true);
        expect(service.isConnecting, isTrue);
        expect(notifications, equals(1));

        service.setConnecting(true);
        expect(notifications, equals(1), reason: 'no change, no notification');

        service.setConnecting(false);
        expect(service.isConnecting, isFalse);
        expect(notifications, equals(2));
      });
    });
  });
}
