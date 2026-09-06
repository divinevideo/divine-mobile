// ABOUTME: Regression tests for RelayPool concurrent modification hazards.
// ABOUTME: Ensures autoSubscribe tolerates subscription changes during resend.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:nostr_sdk/relay/client_connected.dart';

class _MutatingRelay extends Relay {
  _MutatingRelay(String url, {required this.onFirstSend})
    : super(url, RelayStatus(url));

  final Future<void> Function() onFirstSend;
  final List<List<dynamic>> sentMessages = [];
  bool _didMutate = false;

  @override
  Future<bool> doConnect() async {
    relayStatus.connected = ClientConnected.connected;
    return true;
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
    sentMessages.add(message);

    if (!_didMutate) {
      _didMutate = true;
      await onFirstSend();
    }

    return true;
  }
}

class _DisconnectingAutoSubscribeRelay extends Relay {
  _DisconnectingAutoSubscribeRelay(String url) : super(url, RelayStatus(url));

  bool? receivedSkipReconnect;

  @override
  Future<bool> doConnect() async {
    relayStatus.connected = ClientConnected.connected;
    return true;
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
    relayStatus.connected = ClientConnected.disconnect;
    receivedSkipReconnect = skipReconnect;
    if (!skipReconnect) return Completer<bool>().future;
    return false;
  }
}

/// A relay that succeeds on send and immediately responds with EOSE.
class _SucceedingRelay extends Relay {
  _SucceedingRelay(String url) : super(url, RelayStatus(url));

  final List<List<dynamic>> sentMessages = [];

  @override
  Future<bool> doConnect() async {
    relayStatus.connected = ClientConnected.connected;
    return true;
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
    sentMessages.add(message);
    // Simulate EOSE after a short delay so saveQuery runs first
    if (message.isNotEmpty && message.first == 'REQ') {
      final subId = message[1] as String;
      Future.delayed(const Duration(milliseconds: 10), () {
        if (onMessage != null) {
          onMessage!(this, ['EOSE', subId]);
        }
      });
    }
    return true;
  }
}

/// A relay that responds to COUNT queries with a configurable count.
class _CountRelay extends Relay {
  _CountRelay(String url, {required this.countValue})
    : super(url, RelayStatus(url));

  final int countValue;
  final List<List<dynamic>> sentMessages = [];

  @override
  Future<bool> doConnect() async {
    relayStatus.connected = ClientConnected.connected;
    return true;
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
    sentMessages.add(message);
    if (message.isNotEmpty && message.first == 'COUNT') {
      final subId = message[1] as String;
      Future.delayed(const Duration(milliseconds: 10), () {
        if (onMessage != null) {
          onMessage!(this, [
            'COUNT',
            subId,
            {'count': countValue, 'approximate': false},
          ]);
        }
      });
    }
    return true;
  }
}

/// A relay that always fails to send, used to test that failed sends
/// do not block EOSE completion for other relays.
class _FailingSendRelay extends Relay {
  _FailingSendRelay(String url) : super(url, RelayStatus(url));

  final List<List<dynamic>> sentMessages = [];

  @override
  Future<bool> doConnect() async {
    relayStatus.connected = ClientConnected.connected;
    return true;
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
    sentMessages.add(message);
    return false; // Always fail
  }
}

/// A relay that simulates the worst-case reconnect-backoff hang on the
/// publish path. When `skipReconnect: true` is honoured, returns `false`
/// in microseconds (the real `RelayBase.send` short-circuits the
/// `_tryReconnect` loop). When `skipReconnect: false`, hangs for
/// [stallDuration] to simulate the SDK's exponential-backoff reconnect
/// dance that previously blocked the publish flow indefinitely.
class _StallingReconnectRelay extends Relay {
  _StallingReconnectRelay(
    String url, {
    this.stallDuration = const Duration(seconds: 30),
  }) : super(url, RelayStatus(url));

  final Duration stallDuration;
  final List<List<dynamic>> sentMessages = [];
  bool wasInvokedWithoutSkipReconnect = false;

  @override
  Future<bool> doConnect() async {
    // Stay in disconnected state to force the reconnect path.
    relayStatus.connected = ClientConnected.disconnect;
    return false;
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
    sentMessages.add(message);
    if (skipReconnect) {
      // Fast-fail path: this is what the publish loop must hit.
      return false;
    }
    // Reconnect path: simulate the multi-minute exponential-backoff
    // hang that motivated this regression test.
    wasInvokedWithoutSkipReconnect = true;
    await Future<void>.delayed(stallDuration);
    return false;
  }
}

/// A relay whose `send` hangs no matter what flags are passed — models
/// pathological cases where `skipReconnect: true` is honoured but the
/// underlying send still wedges (TCP backpressure, slow peer post-
/// handshake, or a future SDK regression that drops the skipReconnect
/// short-circuit). Used to verify the per-relay timeout backstop in
/// `_sendCollect`.
class _AlwaysHangingRelay extends Relay {
  _AlwaysHangingRelay(String url) : super(url, RelayStatus(url));

  final List<List<dynamic>> sentMessages = [];

  @override
  Future<bool> doConnect() async {
    relayStatus.connected = ClientConnected.connected;
    return true;
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
    sentMessages.add(message);
    // Hang far longer than any reasonable per-relay timeout. The pool's
    // `.timeout(...)` wrap must surface this as `false` and move on.
    await Future<void>.delayed(const Duration(minutes: 1));
    return true;
  }
}

class _DeferredSendRelay extends Relay {
  _DeferredSendRelay(String url) : super(url, RelayStatus(url));

  final releaseSend = Completer<void>();
  final List<List<dynamic>> sentMessages = [];

  @override
  Future<bool> doConnect() async {
    relayStatus.connected = ClientConnected.connected;
    return true;
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
    await releaseSend.future;

    if (deadline != null && !DateTime.now().isBefore(deadline)) {
      if (queueIfFailed) {
        pendingMessages.add(message);
      }
      return false;
    }

    sentMessages.add(message);
    return true;
  }
}

class _TrackingTempRelay extends _SucceedingRelay {
  _TrackingTempRelay(super.url, {required this.onCreated});

  final void Function(String url) onCreated;

  @override
  Future<bool> doConnect() async {
    onCreated(url);
    return super.doConnect();
  }
}

class _ConnectionAwareTempRelay extends Relay {
  _ConnectionAwareTempRelay(String url, {required this.onCreated})
    : super(url, RelayStatus(url));

  final void Function(_ConnectionAwareTempRelay relay) onCreated;
  final List<List<dynamic>> sentMessages = [];

  @override
  Future<bool> doConnect() async {
    relayStatus.connected = ClientConnected.connected;
    onCreated(this);
    return true;
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
    sentMessages.add(message);
    return relayStatus.connected == ClientConnected.connected;
  }
}

class _HangingSendRelay extends Relay {
  _HangingSendRelay(String url) : super(url, RelayStatus(url));

  final List<List<dynamic>> sentMessages = [];

  @override
  Future<bool> doConnect() async {
    relayStatus.connected = ClientConnected.connected;
    return true;
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
  }) {
    sentMessages.add(message);
    return Completer<bool>().future;
  }
}

void main() {
  group('RelayPool concurrency', () {
    late Nostr nostr;
    late LocalNostrSigner signer;

    setUp(() async {
      signer = LocalNostrSigner(
        '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12',
      );
      nostr = Nostr(signer, [], (url) => RelayBase(url, RelayStatus(url)));
      await nostr.refreshPublicKey();
    });

    test('failed relay send does not block query EOSE completion', () async {
      // Add a relay that always fails to send
      final failingRelay = _FailingSendRelay('wss://failing.relay');
      await nostr.relayPool.add(failingRelay);

      // Query should complete quickly (not hang for 10s timeout)
      // because the failing relay's query is never registered
      final stopwatch = Stopwatch()..start();
      final events = await nostr.queryEvents([
        {
          'kinds': [1],
          'limit': 1,
        },
      ], timeout: const Duration(seconds: 5));
      stopwatch.stop();

      // Should complete well under the 5s timeout since the only relay
      // fails to send and is not registered in the EOSE tracking
      expect(stopwatch.elapsedMilliseconds, lessThan(2000));
      expect(events, isEmpty);
    });

    test('hung relay send does not outlive queryEvents timeout', () async {
      final hangingRelay = _HangingSendRelay('wss://hanging.relay');
      await nostr.relayPool.add(hangingRelay);

      final stopwatch = Stopwatch()..start();
      final events = await nostr.queryEvents([
        {
          'kinds': [1],
          'limit': 1,
        },
      ], timeout: const Duration(seconds: 1));
      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(2000));
      expect(events, isEmpty);
      expect(
        hangingRelay.sentMessages.where((m) => m.first == 'REQ'),
        hasLength(1),
      );
    });

    test(
      'query completes via EOSE when some relays succeed and some fail',
      () async {
        // Add one succeeding and one failing relay
        final succeedingRelay = _SucceedingRelay('wss://good.relay');
        final failingRelay = _FailingSendRelay('wss://failing.relay');
        await nostr.relayPool.add(succeedingRelay);
        await nostr.relayPool.add(failingRelay);

        final stopwatch = Stopwatch()..start();
        final events = await nostr.queryEvents([
          {
            'kinds': [1],
            'limit': 1,
          },
        ], timeout: const Duration(seconds: 5));
        stopwatch.stop();

        // Should complete quickly via EOSE from the succeeding relay,
        // not hang until the 5s timeout waiting for the failing one.
        expect(stopwatch.elapsedMilliseconds, lessThan(2000));
        expect(events, isA<List<Event>>());
        // The succeeding relay should have received the REQ
        expect(
          succeedingRelay.sentMessages.where((m) => m.first == 'REQ').length,
          equals(1),
        );
      },
    );

    test(
      'add(autoSubscribe: true) tolerates subscriptions added during resend',
      () async {
        nostr.relayPool.subscribe([
          Filter(kinds: const [1], limit: 1).toJson(),
        ], (_) {});

        final relay = _MutatingRelay(
          'wss://test.relay',
          onFirstSend: () async {
            nostr.relayPool.subscribe([
              Filter(kinds: const [7], limit: 1).toJson(),
            ], (_) {});
          },
        );

        await expectLater(
          nostr.relayPool.add(relay, autoSubscribe: true),
          completes,
        );
        expect(
          relay.sentMessages.where((message) => message.first == 'REQ').length,
          greaterThanOrEqualTo(1),
        );
      },
    );

    test(
      'add(autoSubscribe: true) does not reconnect a socket lost after connect',
      () async {
        nostr.relayPool.subscribe([
          Filter(kinds: const [1], limit: 1).toJson(),
        ], (_) {});
        final relay = _DisconnectingAutoSubscribeRelay(
          'wss://disconnected-auto-subscribe.relay',
        );

        final add = nostr.relayPool.add(relay, autoSubscribe: true);
        await pumpEventQueue();
        expect(relay.receivedSkipReconnect, isTrue);
        expect(await add, isTrue);
        expect(relay.getSubscriptions(), hasLength(1));
      },
    );

    test('failed send does not register query on relay', () async {
      final failingRelay = _FailingSendRelay('wss://failing.relay');
      await nostr.relayPool.add(failingRelay);

      var completeCalled = false;
      await nostr.relayPool.query(
        [
          {
            'kinds': [1],
            'limit': 1,
          },
        ],
        (event) {},
        onComplete: () => completeCalled = true,
      );

      // onComplete should have been called immediately since no relay
      // accepted the query (saveQuery was never called)
      expect(completeCalled, isTrue);
    });

    test(
      'pool.send does not block on a relay stuck in reconnect backoff',
      () async {
        // One healthy relay + one relay that would hang for 30s if
        // _sendCollect forwarded the publish without `skipReconnect: true`.
        // Regression test for the multi-minute publish hang where a
        // single configured-but-disconnected relay (e.g. relay.ditto.pub)
        // blocked the entire fan-out via WebSocketConnectionManager's
        // exponential-backoff reconnect.
        final healthy = _SucceedingRelay('wss://healthy.relay');
        final stalling = _StallingReconnectRelay(
          'wss://stalling.relay',
          stallDuration: const Duration(seconds: 30),
        );
        await nostr.relayPool.add(healthy);
        await nostr.relayPool.add(stalling);

        final event = Event(await signer.getPublicKey() ?? '', 1, [], 'test');
        await signer.signEvent(event);

        final stopwatch = Stopwatch()..start();
        final ok = await nostr.relayPool.send(['EVENT', event.toJson()]);
        stopwatch.stop();

        // If the bug regresses, this would take 30+ seconds.
        expect(stopwatch.elapsedMilliseconds, lessThan(2000));
        // At least one relay accepted the WebSocket frame.
        expect(ok, isTrue);
        // The healthy relay actually received the EVENT.
        expect(
          healthy.sentMessages
              .where((m) => m.isNotEmpty && m.first == 'EVENT')
              .length,
          equals(1),
        );
        // The stalling relay's send was invoked with skipReconnect: true,
        // so it short-circuited instead of hanging.
        expect(stalling.wasInvokedWithoutSkipReconnect, isFalse);
      },
    );

    test('pool.send respects the per-relay timeout when a relay hangs even '
        'with skipReconnect honoured', () async {
      // Belt-and-suspenders: skipReconnect: true short-circuits the
      // disconnected-state reconnect dance, but does NOT bypass the
      // `connecting` state's _waitForConnection() nor protect against
      // a wedged-after-handshake socket. The [RelayPool.perRelaySendTimeout]
      // backstop in _sendCollect catches these residual cases so a single
      // pathological relay cannot stall the sequential fan-out.
      final healthy = _SucceedingRelay('wss://healthy.relay');
      final hanging = _AlwaysHangingRelay('wss://hanging.relay');
      await nostr.relayPool.add(healthy);
      await nostr.relayPool.add(hanging);

      final event = Event(await signer.getPublicKey() ?? '', 1, [], 'test');
      await signer.signEvent(event);

      final stopwatch = Stopwatch()..start();
      final ok = await nostr.relayPool.send(['EVENT', event.toJson()]);
      stopwatch.stop();

      // With one hanging relay, total elapsed should sit comfortably
      // under perRelaySendTimeout + 2s of setup overhead. If the
      // timeout is removed, this test would hang for 60s+.
      final expectedCeiling =
          RelayPool.perRelaySendTimeout + const Duration(seconds: 2);
      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(expectedCeiling.inMilliseconds),
      );
      // The healthy relay still accepted the EVENT.
      expect(ok, isTrue);
      expect(
        healthy.sentMessages
            .where((m) => m.isNotEmpty && m.first == 'EVENT')
            .length,
        equals(1),
      );
      // The hanging relay's send was invoked but did not contribute
      // to sentTo because its future timed out.
      expect(hanging.sentMessages, isNotEmpty);
    });

    test('sendEventAwaitOk bounds target sends with the requested timeout and '
        'does not retry the same URL as a temp relay', () async {
      final relayUrl = 'wss://relay.divine.video';
      final hanging = _AlwaysHangingRelay(relayUrl);
      final tempRelaysCreated = <String>[];
      final tempNostr = Nostr(
        signer,
        [],
        (url) => _TrackingTempRelay(url, onCreated: tempRelaysCreated.add),
      );
      await tempNostr.refreshPublicKey();
      await tempNostr.relayPool.add(hanging);

      final stopwatch = Stopwatch()..start();
      final outcome = await tempNostr.relayPool.sendEventAwaitOk(
        [
          'EVENT',
          {'id': 'deadline-event-id', 'kind': 1},
        ],
        eventId: 'deadline-event-id',
        targetRelays: [relayUrl],
        tempRelays: [relayUrl],
        timeout: const Duration(milliseconds: 50),
      );
      stopwatch.stop();

      expect(outcome.failed, isTrue);
      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(1000),
        reason: 'requested timeout must bound _sendCollect plus OK waiting',
      );
      expect(hanging.sentMessages, hasLength(1));
      expect(
        tempRelaysCreated,
        isEmpty,
        reason: 'same target URL must not be attempted again as a temp relay',
      );
    });

    test('sendEventAwaitOk falls back to a same-URL temp relay when the normal '
        'target send fails immediately', () async {
      final relayUrl = 'wss://relay.divine.video';
      final failing = _FailingSendRelay(relayUrl);
      final tempRelaysCreated = <String>[];
      final tempNostr = Nostr(
        signer,
        [],
        (url) => _TrackingTempRelay(url, onCreated: tempRelaysCreated.add),
      );
      await tempNostr.refreshPublicKey();
      await tempNostr.relayPool.add(failing);

      final stopwatch = Stopwatch()..start();
      final outcome = await tempNostr.relayPool.sendEventAwaitOk(
        [
          'EVENT',
          {'id': 'fallback-event-id', 'kind': 1},
        ],
        eventId: 'fallback-event-id',
        targetRelays: [relayUrl],
        tempRelays: [relayUrl],
        timeout: const Duration(milliseconds: 50),
      );
      stopwatch.stop();

      expect(outcome.failed, isTrue);
      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(1000),
        reason: 'same-URL temp fallback must use the shared publish timeout',
      );
      expect(failing.sentMessages, hasLength(1));
      expect(
        tempRelaysCreated,
        contains(relayUrl),
        reason: 'a failed normal send should not suppress temp relay fallback',
      );
    });

    test('sendEventAwaitOk recreates a disconnected cached temp relay before '
        'deadline-bound fallback send', () async {
      final relayUrl = 'wss://relay.divine.video';
      final failing = _FailingSendRelay(relayUrl);
      final tempRelaysCreated = <_ConnectionAwareTempRelay>[];
      final tempNostr = Nostr(
        signer,
        [],
        (url) =>
            _ConnectionAwareTempRelay(url, onCreated: tempRelaysCreated.add),
      );
      await tempNostr.refreshPublicKey();

      final staleTempRelay = tempNostr.relayPool.checkAndGenTempRelay(relayUrl);
      await staleTempRelay.disconnect();
      await tempNostr.relayPool.add(failing);

      final outcome = await tempNostr.relayPool.sendEventAwaitOk(
        [
          'EVENT',
          {'id': 'recreated-temp-event-id', 'kind': 1},
        ],
        eventId: 'recreated-temp-event-id',
        targetRelays: [relayUrl],
        tempRelays: [relayUrl],
        timeout: const Duration(milliseconds: 50),
      );

      expect(outcome.failed, isTrue);
      expect(
        tempRelaysCreated,
        hasLength(2),
        reason: 'disconnected cached temp relay must be replaced before send',
      );
      expect(
        tempRelaysCreated.first.sentMessages,
        isEmpty,
        reason: 'stale disconnected temp relay must not be reused for send',
      );
      expect(tempRelaysCreated.last.sentMessages, hasLength(1));
    });

    test(
      'sendEventAwaitOk does not write or queue an event after the deadline',
      () async {
        final relayUrl = 'wss://relay.divine.video';
        final deferred = _DeferredSendRelay(relayUrl);
        await nostr.relayPool.add(deferred);

        final outcome = await nostr.relayPool.sendEventAwaitOk(
          [
            'EVENT',
            {'id': 'deferred-event-id', 'kind': 1},
          ],
          eventId: 'deferred-event-id',
          targetRelays: [relayUrl],
          timeout: const Duration(milliseconds: 10),
        );

        expect(outcome.failed, isTrue);

        await Future<void>.delayed(const Duration(milliseconds: 20));
        deferred.releaseSend.complete();
        await Future<void>.delayed(Duration.zero);

        expect(
          deferred.sentMessages,
          isEmpty,
          reason: 'the EVENT must not be written after the publish deadline',
        );
        expect(
          deferred.pendingMessages,
          isEmpty,
          reason: 'deadline-bound await-OK sends must not queue stale EVENTs',
        );
      },
    );

    test(
      'RelayPool.perRelaySendTimeout is exposed as a stable public contract',
      () {
        // Pin: the public constant is the SDK's contract with callers
        // that need to size their own outer guards (e.g.
        // `outerPublishTimeoutFor` in mobile/lib/services/
        // video_event_publisher.dart). Bumping this value is a SDK-
        // public-API change — callers depending on the worst-case
        // sequential fan-out math need to be revisited.
        expect(
          RelayPool.perRelaySendTimeout,
          equals(const Duration(seconds: 5)),
        );
      },
    );
  });

  group('RelayPool COUNT concurrency', () {
    late Nostr nostr;
    late LocalNostrSigner signer;

    setUp(() async {
      signer = LocalNostrSigner(
        '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12',
      );
      nostr = Nostr(signer, [], (url) => RelayBase(url, RelayStatus(url)));
      await nostr.refreshPublicKey();
    });

    test('count returns highest count from multiple relays', () async {
      final relay1 = _CountRelay('wss://relay1.test', countValue: 10);
      final relay2 = _CountRelay('wss://relay2.test', countValue: 42);
      await nostr.relayPool.add(relay1);
      await nostr.relayPool.add(relay2);

      final result = await nostr.relayPool.count([
        {
          'kinds': [1],
        },
      ]);

      expect(result.count, equals(42));
    });

    test('count succeeds when some relays fail and some succeed', () async {
      final countRelay = _CountRelay('wss://good.relay', countValue: 7);
      final failingRelay = _FailingSendRelay('wss://failing.relay');
      await nostr.relayPool.add(countRelay);
      await nostr.relayPool.add(failingRelay);

      final result = await nostr.relayPool.count([
        {
          'kinds': [1],
        },
      ]);

      expect(result.count, equals(7));
    });

    test(
      'count throws CountNotSupportedException when all relays fail',
      () async {
        final failingRelay = _FailingSendRelay('wss://failing.relay');
        await nostr.relayPool.add(failingRelay);

        await expectLater(
          nostr.relayPool.count([
            {
              'kinds': [1],
            },
          ]),
          throwsA(isA<CountNotSupportedException>()),
        );
      },
    );
  });
}
