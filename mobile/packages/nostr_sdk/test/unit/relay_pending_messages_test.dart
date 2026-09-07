// ABOUTME: Regression tests for Relay pending-message replay on reconnect.
// ABOUTME: Ensures failed replays are re-queued without corrupting iteration.

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

class _RequeueingRelay extends Relay {
  _RequeueingRelay(
    String url, {
    required this.failedMessage,
    this.connectionIsFresh = true,
  }) : super(url, RelayStatus(url));

  final List<dynamic> failedMessage;
  final List<List<dynamic>> sentMessages = [];

  @override
  final bool connectionIsFresh;

  @override
  Future<bool> doConnect() async => true;

  @override
  Future<void> disconnect() async {}

  @override
  Future<bool> send(
    List<dynamic> message, {
    bool queueIfFailed = true,
    bool skipReconnect = false,
    DateTime? deadline,
  }) async {
    sentMessages.add(List<dynamic>.from(message));

    if (_messagesEqual(message, failedMessage)) {
      if (queueIfFailed) {
        pendingMessages.add(message);
      }
      return false;
    }

    return true;
  }

  bool _messagesEqual(List<dynamic> a, List<dynamic> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

void main() {
  group('Relay pending-message replay', () {
    test(
      're-queues failed sends without mutating the active iteration',
      () async {
        final failedMessage = [
          'EVENT',
          {'id': 'retry'},
        ];
        final relay =
            _RequeueingRelay(
                'wss://relay.example',
                failedMessage: failedMessage,
              )
              ..pendingMessages.addAll([
                [
                  'EVENT',
                  {'id': 'sent'},
                ],
                failedMessage,
              ]);

        await expectLater(relay.onConnected(source: 'test'), completes);

        expect(relay.sentMessages, [
          [
            'EVENT',
            {'id': 'sent'},
          ],
          failedMessage,
        ]);
        expect(relay.pendingMessages, [failedMessage]);
      },
    );
  });

  group('Relay saved-REQ re-issue on reconnect', () {
    Subscription subscriptionWith(String id) => Subscription(
      [
        {
          'kinds': [34236],
        },
      ],
      (_) {},
      id: id,
    );

    test('re-issues saved subscriptions so a dropped socket does not leave the '
        'caller waiting forever', () async {
      final relay = _RequeueingRelay('wss://relay.example', failedMessage: [])
        ..saveSubscription(subscriptionWith('feed'));

      await relay.onConnected(source: 'stateStream-reconnect');

      expect(relay.sentMessages, [
        [
          'REQ',
          'feed',
          {
            'kinds': [34236],
          },
        ],
      ]);
    });

    test('re-issues pending one-shot queries too', () async {
      final relay = _RequeueingRelay('wss://relay.example', failedMessage: [])
        ..saveQuery(subscriptionWith('author-page'));

      await relay.onConnected(source: 'stateStream-reconnect');

      expect(relay.sentMessages.single[1], 'author-page');
    });

    test(
      'sends a queued REQ once when its subscription is also saved — a '
      'double REQ makes the relay replay the whole stored window twice',
      () async {
        final subscription = subscriptionWith('feed');
        final relay = _RequeueingRelay('wss://relay.example', failedMessage: [])
          ..saveSubscription(subscription)
          ..pendingMessages.add(subscription.toJson());

        await relay.onConnected(source: 'stateStream-reconnect');

        expect(relay.sentMessages, hasLength(1));
        expect(relay.pendingMessages, isEmpty);
      },
    );

    test('still replays queued frames that are not re-issued REQs', () async {
      final relay = _RequeueingRelay('wss://relay.example', failedMessage: [])
        ..saveSubscription(subscriptionWith('feed'))
        ..pendingMessages.add([
          'EVENT',
          {'id': 'queued-while-down'},
        ]);

      await relay.onConnected(source: 'stateStream-reconnect');

      expect(relay.sentMessages.map((m) => m.first), ['EVENT', 'REQ']);
    });

    test('leaves saved REQs alone when the connection was only reused — the '
        'live socket still holds them', () async {
      final subscription = subscriptionWith('feed');
      final relay =
          _RequeueingRelay(
              'wss://relay.example',
              failedMessage: [],
              connectionIsFresh: false,
            )
            ..saveSubscription(subscription)
            ..pendingMessages.add([
              'EVENT',
              {'id': 'queued-while-down'},
            ]);

      await relay.onConnected(source: 'connect()');

      expect(relay.sentMessages.map((m) => m.first), ['EVENT']);
    });

    test('replays a queued REQ when the connection was only reused — nothing '
        're-issues it otherwise', () async {
      final subscription = subscriptionWith('feed');
      final relay =
          _RequeueingRelay(
              'wss://relay.example',
              failedMessage: [],
              connectionIsFresh: false,
            )
            ..saveSubscription(subscription)
            ..pendingMessages.add(subscription.toJson());

      await relay.onConnected(source: 'connect()');

      expect(relay.sentMessages.map((m) => m.first), ['REQ']);
    });
  });

  group('Relay queued-REQ discard', () {
    Subscription subscriptionWith(String id) => Subscription(
      [
        {
          'kinds': [34236],
        },
      ],
      (_) {},
      id: id,
    );

    test('discardSubscription purges its queued REQ only', () {
      final discarded = subscriptionWith('feed');
      final deliberatelyUnsaved = subscriptionWith('discovery');
      final relay = _RequeueingRelay('wss://relay.example', failedMessage: [])
        ..saveSubscription(discarded)
        ..pendingMessages.addAll([
          discarded.toJson(),
          deliberatelyUnsaved.toJson(),
        ]);

      expect(relay.discardSubscription(discarded.id), isTrue);

      expect(relay.pendingMessages, [deliberatelyUnsaved.toJson()]);
    });

    test('discardQuery purges its queued REQ', () {
      final discarded = subscriptionWith('author-page');
      final relay = _RequeueingRelay('wss://relay.example', failedMessage: [])
        ..saveQuery(discarded)
        ..pendingMessages.add(discarded.toJson());

      expect(relay.discardQuery(discarded.id), isTrue);

      expect(relay.pendingMessages, isEmpty);
    });

    test('an unsaved queued REQ remains eligible for replay', () async {
      final deliberatelyUnsaved = subscriptionWith('discovery');
      final relay = _RequeueingRelay('wss://relay.example', failedMessage: [])
        ..pendingMessages.add(deliberatelyUnsaved.toJson());

      expect(relay.discardSubscription(deliberatelyUnsaved.id), isFalse);
      await relay.onConnected(source: 'stateStream-reconnect');

      expect(relay.sentMessages, [deliberatelyUnsaved.toJson()]);
    });
  });

  group('Relay queued-CLOSE replay', () {
    test('drops a queued CLOSE on a fresh socket — the subscription it names '
        'died with the previous connection', () async {
      final relay = _RequeueingRelay('wss://relay.example', failedMessage: [])
        ..pendingMessages.addAll([
          ['CLOSE', 'feed'],
          [
            'EVENT',
            {'id': 'queued-while-down'},
          ],
        ]);

      await relay.onConnected(source: 'stateStream-reconnect');

      expect(relay.sentMessages.map((m) => m.first), ['EVENT']);
      expect(relay.pendingMessages, isEmpty);
    });

    test('drops it even when the same id is re-issued — the replayed REQ can '
        'land first and the stale CLOSE would tear it down', () async {
      final relay = _RequeueingRelay('wss://relay.example', failedMessage: [])
        ..saveSubscription(
          Subscription(
            [
              {
                'kinds': [34236],
              },
            ],
            (_) {},
            id: 'feed',
          ),
        )
        ..pendingMessages.add(['CLOSE', 'feed']);

      await relay.onConnected(source: 'stateStream-reconnect');

      expect(relay.sentMessages.map((m) => m.first), ['REQ']);
    });

    test('replays a queued CLOSE when the connection was only reused — that '
        'socket may still be holding the subscription', () async {
      final relay = _RequeueingRelay(
        'wss://relay.example',
        failedMessage: [],
        connectionIsFresh: false,
      )..pendingMessages.add(['CLOSE', 'feed']);

      await relay.onConnected(source: 'connect()');

      expect(relay.sentMessages, [
        ['CLOSE', 'feed'],
      ]);
    });
  });
}
