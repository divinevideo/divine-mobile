// ABOUTME: Tests when a live subscription's onEose fires while a relay owes it
// ABOUTME: EOSE: never connected, refused with NOTICE, or mid-batch (#9007).

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:nostr_sdk/relay/client_connected.dart';

const _signerKey =
    '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';

/// A relay whose connection the test controls and whose frames the test
/// delivers by hand.
class _Relay extends Relay {
  _Relay(String url, {this.reachable = true}) : super(url, RelayStatus(url));

  bool reachable;
  String? authEventId;

  /// When set, [doConnect] waits for it, so the relay stays connecting.
  Completer<void>? connectGate;

  @override
  Future<bool> doConnect() async {
    final gate = connectGate;
    if (gate != null) await gate.future;
    relayStatus.connected = reachable
        ? ClientConnected.connected
        : ClientConnected.disconnect;
    return reachable;
  }

  @override
  Future<void> disconnect() async {
    relayStatus.connected = ClientConnected.disconnect;
  }

  @override
  Future<bool> send(
    List<dynamic> message, {
    bool queueIfFailed = true,
    bool skipReconnect = false,
    DateTime? deadline,
  }) async {
    if (message.length > 1 && message[0] == 'AUTH' && message[1] is Map) {
      authEventId = (message[1] as Map)['id'] as String?;
    }
    return reachable;
  }

  void drop() {
    relayStatus.connected = ClientConnected.disconnect;
    relayStatusCallback?.call();
  }

  Future<void> reconnect() async {
    relayStatus.connected = ClientConnected.connected;
    relayStatusCallback?.call();
    await onConnected(source: 'test-reconnect');
  }

  Future<void> deliver(List<dynamic> json) async {
    final dynamic result = onMessage!(this, json);
    if (result is Future) await result;
  }
}

/// A signed event; kind 1111 matches the test subscription's filter.
Map<String, dynamic> _comment(int createdAt, {int kind = 1111}) {
  final event = Event(
    getPublicKey(_signerKey),
    kind,
    [],
    'comment $createdAt',
    createdAt: createdAt,
  )..sign(_signerKey);
  return event.toJson();
}

class _HeldVerifyWorker implements EventVerifyWorker {
  final release = Completer<void>();

  @override
  Future<bool> verify(Map<String, dynamic> eventJson) async {
    await release.future;
    return true;
  }

  @override
  void close() {}
}

void main() {
  group('RelayPool live-subscription onEose', () {
    Relay tempRelay(String url) => RelayBase(url, RelayStatus(url));

    late Nostr nostr;
    late int eoseCalls;
    late FakeAsync async;
    late Duration window;

    setUp(() {
      nostr = Nostr(LocalNostrSigner(_signerKey), [], tempRelay);
      eoseCalls = 0;
      window = nostr.relayPool.subscriptionEoseSettleWindow;
    });

    void settle(Future<void> work) {
      unawaited(work);
      async.flushMicrotasks();
    }

    /// Pools [relays] and opens a live subscription on all of them.
    String subscribe(List<_Relay> relays, {void Function(Event)? onEvent}) {
      for (final relay in relays) {
        settle(nostr.relayPool.add(relay));
      }
      final subId = nostr.subscribe(
        [
          {
            'kinds': [1111],
            'limit': 50,
          },
        ],
        onEvent ?? (Event _) {},
        onEose: () => eoseCalls++,
      );
      async.flushMicrotasks();
      return subId;
    }

    test('does not settle before a received event finishes verifying', () {
      fakeAsync((fake) {
        async = fake;
        final worker = _HeldVerifyWorker();
        nostr.relayPool.eventVerifyWorker = worker;
        final live = _Relay('wss://live.example');
        final owing = _Relay('wss://owing.example');
        var delivered = 0;
        final subId = subscribe([live, owing], onEvent: (_) => delivered++);

        settle(live.deliver(['EOSE', subId]));
        final halfWindow = window ~/ 2;
        async.elapse(halfWindow);
        settle(owing.deliver(['EVENT', subId, _comment(1)]));
        async.elapse(halfWindow);
        expect(eoseCalls, 0);

        worker.release.complete();
        async.flushMicrotasks();
        expect(delivered, 1);
        expect(eoseCalls, 0);
        settle(owing.deliver(['EOSE', subId]));
        expect(eoseCalls, 1);
        nostr.relayPool.unsubscribe(subId);
      });
    });

    test('control: fires on the EOSE of the only relay holding the REQ', () {
      fakeAsync((fake) {
        async = fake;
        final live = _Relay('wss://live.example');
        final subId = subscribe([live]);

        settle(live.deliver(['EOSE', subId]));

        expect(eoseCalls, equals(1));
      });
    });

    test('does not start settling on EOSE from a relay without the REQ', () {
      fakeAsync((fake) {
        async = fake;
        final live = _Relay('wss://live.example');
        final subId = subscribe([live]);
        final other = _Relay('wss://other.example');
        settle(nostr.relayPool.add(other));
        expect(other.hasSubscriptionById(subId), isFalse);

        settle(other.deliver(['EOSE', subId]));
        async.elapse(window);
        expect(eoseCalls, 0);

        settle(live.deliver(['EOSE', subId]));
        expect(eoseCalls, 1);
      });
    });

    group('when a relay replays its REQ after AUTH', () {
      void authenticate(_Relay relay) {
        settle(relay.deliver(['AUTH', 'test-challenge']));
        expect(relay.authEventId, isNotNull);
        settle(relay.deliver(['OK', relay.authEventId, true, '']));
        expect(relay.relayStatus.authed, isTrue);
      }

      test('continues waiting while the relay sends its replay', () {
        fakeAsync((fake) {
          async = fake;
          final replaying = _Relay('wss://replaying.example');
          final silent = _Relay('wss://silent.example');
          final subId = subscribe([replaying, silent]);
          settle(replaying.deliver(['EOSE', subId]));
          final halfWindow = window ~/ 2;
          async.elapse(halfWindow);

          authenticate(replaying);
          settle(replaying.deliver(['EVENT', subId, _comment(1)]));
          async.elapse(halfWindow);
          expect(eoseCalls, 0);

          settle(replaying.deliver(['EOSE', subId]));
          async.elapse(halfWindow);
          expect(eoseCalls, 1);
        });
      });

      test('does not treat a queued EOSE as an answer to the replay', () {
        fakeAsync((fake) {
          async = fake;
          final worker = _HeldVerifyWorker();
          nostr.relayPool.eventVerifyWorker = worker;
          final relay = _Relay('wss://relay.example');
          final subId = subscribe([relay]);
          settle(relay.deliver(['EVENT', subId, _comment(1)]));
          settle(relay.deliver(['EOSE', subId]));

          authenticate(relay);
          worker.release.complete();
          async.flushMicrotasks();
          expect(eoseCalls, 0);

          settle(relay.deliver(['EOSE', subId]));
          expect(eoseCalls, 1);
        });
      });
    });

    group('with a relay that never connected', () {
      test('fires once the settle window passes without it', () {
        fakeAsync((fake) {
          async = fake;
          final live = _Relay('wss://live.example');
          final dead = _Relay('wss://dead.example', reachable: false);
          final subId = subscribe([live, dead]);
          expect(dead.hasSubscriptionById(subId), isTrue);

          settle(live.deliver(['EOSE', subId]));
          async.elapse(window - const Duration(milliseconds: 1));
          expect(eoseCalls, equals(0), reason: 'still inside the window');

          async.elapse(const Duration(milliseconds: 1));
          expect(eoseCalls, equals(1));
        });
      });
    });

    group('with a connected relay that refused the REQ with NOTICE', () {
      late _Relay live;
      late _Relay refuser;

      /// Has [live] send EOSE and [refuser] send the NOTICE that names no
      /// subscription, and returns the subscription id.
      String refusedSubscription() {
        live = _Relay('wss://live.example');
        refuser = _Relay('wss://refuser.example');
        final subId = subscribe([live, refuser]);
        settle(live.deliver(['EOSE', subId]));
        settle(refuser.deliver(['NOTICE', 'ERROR: too many concurrent REQs']));
        return subId;
      }

      test('fires once the settle window passes', () {
        fakeAsync((fake) {
          async = fake;
          refusedSubscription();

          async.elapse(window - const Duration(milliseconds: 1));
          expect(eoseCalls, equals(0), reason: 'still inside the window');

          async.elapse(const Duration(milliseconds: 1));
          expect(eoseCalls, equals(1));
        });
      });

      test('fires at the window while the answering relay keeps sending '
          'live events', () {
        fakeAsync((fake) {
          async = fake;
          final subId = refusedSubscription();

          for (var i = 1; i <= 3; i++) {
            async.elapse(window * 0.3);
            settle(live.deliver(['EVENT', subId, _comment(1700000000 + i)]));
          }
          async.elapse(window * 0.1);

          expect(eoseCalls, equals(1));
        });
      });

      test('control: the same refusal as CLOSED fires it at once', () {
        fakeAsync((fake) {
          async = fake;
          final live = _Relay('wss://live.example');
          final closer = _Relay('wss://refuser.example');
          final subId = subscribe([live, closer]);
          settle(live.deliver(['EOSE', subId]));
          expect(eoseCalls, equals(0));

          settle(
            closer.deliver([
              'CLOSED',
              subId,
              'error: too many concurrent REQs',
            ]),
          );

          expect(eoseCalls, equals(1));
        });
      });

      test('starts a fresh window after the sole EOSE relay refuses', () {
        fakeAsync((fake) {
          async = fake;
          final first = _Relay('wss://first.example');
          final second = _Relay('wss://second.example');
          final silent = _Relay('wss://silent.example');
          final subId = subscribe([first, second, silent]);
          settle(first.deliver(['EOSE', subId]));
          final halfWindow = window ~/ 2;
          async.elapse(halfWindow);

          settle(first.deliver(['CLOSED', subId, 'error: shutting down']));
          settle(second.deliver(['EOSE', subId]));
          async.elapse(halfWindow);
          expect(eoseCalls, 0);

          async.elapse(halfWindow);
          expect(eoseCalls, 1);
        });
      });

      test('disarms the settle window when the subscription is torn '
          'down', () {
        fakeAsync((fake) {
          async = fake;
          window = const Duration(seconds: 13);
          nostr.relayPool.subscriptionEoseSettleWindow = window;
          final subId = refusedSubscription();
          bool isSettleTimer(FakeTimer timer) => timer.duration == window;
          expect(async.pendingTimers.where(isSettleTimer), hasLength(1));

          nostr.unsubscribe(subId);

          expect(async.pendingTimers.where(isSettleTimer), isEmpty);
        });
      });

      test('disarms the settle window when the last holder refuses the REQ', () {
        fakeAsync((fake) {
          async = fake;
          window = const Duration(seconds: 13);
          nostr.relayPool.subscriptionEoseSettleWindow = window;
          final subId = refusedSubscription();
          bool isSettleTimer(FakeTimer timer) => timer.duration == window;

          // Removing the answering relay from the pool leaves its timer armed.
          nostr.relayPool.remove(live.url);
          expect(async.pendingTimers.where(isSettleTimer), hasLength(1));

          settle(refuser.deliver(['CLOSED', subId, 'error: shutting down']));

          expect(async.pendingTimers.where(isSettleTimer), isEmpty);
        });
      });

      test('arms no settle window once the pool is closing', () {
        fakeAsync((fake) {
          async = fake;
          window = const Duration(seconds: 13);
          nostr.relayPool.subscriptionEoseSettleWindow = window;
          live = _Relay('wss://live.example');
          refuser = _Relay('wss://refuser.example');
          final subId = subscribe([live, refuser]);

          nostr.relayPool.beginClose();
          settle(live.deliver(['EOSE', subId]));

          expect(
            async.pendingTimers.where((timer) => timer.duration == window),
            isEmpty,
          );
        });
      });
    });

    group('with a relay part-way through its stored events', () {
      late _Relay slow;
      late String subId;

      void startBatch() {
        final live = _Relay('wss://live.example');
        slow = _Relay('wss://slow.example');
        subId = subscribe([live, slow]);
        settle(live.deliver(['EOSE', subId]));
        settle(slow.deliver(['EVENT', subId, _comment(1700000001)]));
      }

      test('holds it past the window while the relay keeps sending them', () {
        fakeAsync((fake) {
          async = fake;
          startBatch();
          async.elapse(window * 0.6);
          settle(slow.deliver(['EVENT', subId, _comment(1700000002)]));
          async.elapse(window * 0.6);
          settle(slow.deliver(['EVENT', subId, _comment(1700000003)]));
          async.elapse(window * 0.6);
          expect(eoseCalls, equals(0), reason: 'the relay is still sending');

          async.elapse(window * 0.4);
          expect(eoseCalls, equals(1));
        });
      });

      test('holds it past the window while the relay sends events outside '
          'the filter', () {
        fakeAsync((fake) {
          async = fake;
          startBatch();
          for (var i = 2; i <= 3; i++) {
            async.elapse(window * 0.6);
            settle(
              slow.deliver(['EVENT', subId, _comment(1700000000 + i, kind: 1)]),
            );
          }
          async.elapse(window * 0.6);
          expect(eoseCalls, equals(0), reason: 'the relay is still answering');

          async.elapse(window * 0.4);
          expect(eoseCalls, equals(1));
        });
      });

      test('is not held by a relay that was never sent the REQ', () {
        fakeAsync((fake) {
          async = fake;
          startBatch();
          final stranger = _Relay('wss://stranger.example');
          settle(nostr.relayPool.add(stranger));
          expect(stranger.hasSubscriptionById(subId), isFalse);

          for (var i = 2; i <= 3; i++) {
            async.elapse(window * 0.6);
            settle(
              stranger.deliver(['EVENT', subId, _comment(1700000000 + i)]),
            );
          }

          expect(eoseCalls, equals(1));
        });
      });

      test('waits for the relay to replay them after it drops', () {
        fakeAsync((fake) {
          async = fake;
          startBatch();

          slow.drop();
          async.elapse(window * 0.5);
          expect(eoseCalls, equals(0), reason: 'the reconnect replays them');

          settle(slow.reconnect());
          settle(slow.deliver(['EVENT', subId, _comment(1700000001)]));
          expect(eoseCalls, equals(0));
          settle(slow.deliver(['EOSE', subId]));
          expect(eoseCalls, equals(1));
        });
      });

      test('waits for a reconnecting EOSE relay to finish its replay', () {
        fakeAsync((fake) {
          async = fake;
          final worker = _HeldVerifyWorker();
          nostr.relayPool.eventVerifyWorker = worker;
          final replaying = _Relay('wss://replaying.example');
          final silent = _Relay('wss://silent.example');
          var delivered = 0;
          final subId = subscribe(
            [replaying, silent],
            onEvent: (_) {
              delivered++;
            },
          );
          settle(replaying.deliver(['EOSE', subId]));
          final halfWindow = window ~/ 2;
          async.elapse(halfWindow);

          replaying.drop();
          settle(replaying.reconnect());
          settle(replaying.deliver(['EVENT', subId, _comment(1)]));
          async.elapse(halfWindow);
          expect(eoseCalls, 0, reason: 'the replay is still verifying');

          worker.release.complete();
          async.flushMicrotasks();
          expect(delivered, 1);
          async.elapse(halfWindow);
          settle(replaying.deliver(['EVENT', subId, _comment(2)]));
          async.elapse(halfWindow);
          expect(eoseCalls, 0, reason: 'the replay restarted the window');

          settle(replaying.deliver(['EOSE', subId]));
          async.elapse(halfWindow);
          expect(delivered, 2);
          expect(eoseCalls, 1);
        });
      });
    });

    group('when a refusal leaves only a relay still replaying', () {
      test('waits for that relay to answer instead of firing', () {
        fakeAsync((fake) {
          async = fake;
          final refuser = _Relay('wss://refuser.example');
          final redialled = _Relay('wss://redialled.example');
          final subId = subscribe([refuser, redialled]);
          settle(redialled.deliver(['EOSE', subId]));

          nostr.relayPool.remove(redialled.url);
          final replacement = _Relay('wss://redialled.example')
            ..connectGate = Completer<void>();
          settle(nostr.relayPool.add(replacement, autoSubscribe: true));
          expect(replacement.hasSubscriptionById(subId), isFalse);

          settle(
            refuser.deliver(['CLOSED', subId, 'error: could not complete']),
          );
          expect(eoseCalls, equals(0), reason: 'the REQ is not replayed yet');

          replacement.connectGate!.complete();
          async.flushMicrotasks();
          expect(replacement.hasSubscriptionById(subId), isTrue);
          async.elapse(window);
          expect(eoseCalls, 0, reason: 'the replacement has not sent EOSE');
          settle(replacement.deliver(['EOSE', subId]));

          expect(eoseCalls, equals(1));
        });
      });
    });

    group('after it has fired', () {
      late _Relay first;
      late _Relay second;
      late String subId;

      void fireOnce() {
        first = _Relay('wss://first.example');
        second = _Relay('wss://second.example');
        subId = subscribe([first, second]);
        settle(first.deliver(['EOSE', subId]));
        settle(second.deliver(['EOSE', subId]));
        expect(eoseCalls, equals(1));
      }

      test('fires again when every relay replays its stored events', () {
        fakeAsync((fake) {
          async = fake;
          fireOnce();

          for (final relay in [first, second]) {
            relay.drop();
            settle(relay.reconnect());
            settle(relay.deliver(['EOSE', subId]));
          }

          expect(eoseCalls, equals(2));
        });
      });

      test('does not fire again when one relay replays alone', () {
        fakeAsync((fake) {
          async = fake;
          fireOnce();

          second.drop();
          settle(second.reconnect());
          settle(second.deliver(['EOSE', subId]));
          async.elapse(window * 2);

          expect(eoseCalls, equals(1));
        });
      });

      test('does not fire again when a relay answers after the window', () {
        fakeAsync((fake) {
          async = fake;
          final live = _Relay('wss://live.example');
          final straggler = _Relay('wss://straggler.example');
          subId = subscribe([live, straggler]);
          settle(live.deliver(['EOSE', subId]));
          async.elapse(window);
          expect(eoseCalls, equals(1));

          settle(straggler.deliver(['EOSE', subId]));
          async.elapse(window * 2);

          expect(eoseCalls, equals(1));
        });
      });
    });
  });
}
