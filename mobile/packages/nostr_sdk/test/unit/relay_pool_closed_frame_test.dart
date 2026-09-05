// ABOUTME: Regression tests for CLOSED frames terminating a pending REQ.
// ABOUTME: A relay that CLOSEs a query must not strand the caller until timeout.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:nostr_sdk/relay/client_connected.dart';

/// Relay that records the REQ it was sent and answers only when the test says
/// so — never EVENT, never EOSE.
class _ControlledQueryRelay extends Relay {
  _ControlledQueryRelay(String url, {Completer<void>? reqSendGate})
    : _reqSendGate = reqSendGate,
      super(url, RelayStatus(url));

  String? capturedSubId;
  String? capturedAuthEventId;
  final List<List<dynamic>> sentMessages = [];
  final Completer<void>? _reqSendGate;

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
    if (message.isNotEmpty && message[0] == 'REQ' && message.length > 1) {
      capturedSubId = message[1] as String;
      await _reqSendGate?.future;
    } else if (message.isNotEmpty &&
        message[0] == 'AUTH' &&
        message.length > 1 &&
        message[1] is Map) {
      capturedAuthEventId = (message[1] as Map)['id'] as String?;
    }
    return true;
  }

  Future<void> deliver(List<dynamic> json) async {
    final handler = onMessage;
    expect(handler, isNotNull, reason: 'RelayPool did not wire onMessage');
    final dynamic result = handler!(this, json);
    if (result is Future) {
      await result;
    }
  }

  Future<String> awaitPendingQuery() async {
    for (var i = 0; i < 1000; i++) {
      final subId = capturedSubId;
      if (subId != null && checkQuery(subId)) return subId;
      await Future<void>.delayed(Duration.zero);
    }
    fail('RelayPool never registered a pending query for the REQ');
  }

  Future<String> awaitPendingSubscription() async {
    for (var i = 0; i < 1000; i++) {
      final subId = capturedSubId;
      if (subId != null && hasSubscriptionById(subId)) return subId;
      await Future<void>.delayed(Duration.zero);
    }
    fail('RelayPool never registered a live subscription for the REQ');
  }

  Future<void> awaitReqCount(int count) async {
    for (var i = 0; i < 1000; i++) {
      final reqCount = sentMessages.where((m) => m.first == 'REQ').length;
      if (reqCount >= count) return;
      await Future<void>.delayed(Duration.zero);
    }
    fail('RelayPool sent fewer than $count REQ frames');
  }
}

void main() {
  group('RelayPool CLOSED frame handling', () {
    Relay dummyTempRelay(String url) => RelayBase(url, RelayStatus(url));

    test('CLOSED on a pending REQ completes the query without waiting for '
        'the full timeout', () async {
      final signer = LocalNostrSigner(
        '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12',
      );
      final nostr = Nostr(signer, [], dummyTempRelay);
      final relay = _ControlledQueryRelay('wss://closed.example');

      expect(await nostr.relayPool.add(relay), isTrue);

      const timeout = Duration(seconds: 2);
      final pending = nostr.queryEventsDetailed([
        {
          'ids': [
            '0739befe110ec68c28a33650b84c10b356015ec3b8401787d05a84ae285c976a',
          ],
          'limit': 1,
        },
      ], timeout: timeout);

      final subId = await relay.awaitPendingQuery();
      expect(subId, hasLength(16));
      expect(RegExp(r'^[0-9a-z]{16}$').hasMatch(subId), isTrue);
      await relay.deliver(['CLOSED', subId, 'error: query failed']);

      final result = await pending;

      expect(result.events, isEmpty);
      expect(
        result.timedOut,
        isFalse,
        reason: 'a relay-refused query is not a timeout',
      );
      expect(
        relay.checkQuery(subId),
        isFalse,
        reason: 'the refused query must not stay pending on the relay',
      );
    });

    test('EOSE still completes a pending REQ', () async {
      final signer = LocalNostrSigner(
        '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12',
      );
      final nostr = Nostr(signer, [], dummyTempRelay);
      final relay = _ControlledQueryRelay('wss://eose.example');

      expect(await nostr.relayPool.add(relay), isTrue);

      const timeout = Duration(seconds: 2);
      final pending = nostr.queryEventsDetailed([
        {
          'kinds': [1],
        },
      ], timeout: timeout);

      final subId = await relay.awaitPendingQuery();
      await relay.deliver(['EOSE', subId]);

      final result = await pending;
      expect(result.timedOut, isFalse);
      expect(result.events, isEmpty);
    });

    test(
      'CLOSED releases the last live subscription and prevents replay',
      () async {
        final signer = LocalNostrSigner(
          '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12',
        );
        final nostr = Nostr(signer, [], dummyTempRelay);
        final refusedRelay = _ControlledQueryRelay(
          'wss://refused-live.example',
        );
        expect(await nostr.relayPool.add(refusedRelay), isTrue);

        String? closedReason;
        nostr.subscribe(
          [
            {
              'kinds': [1],
            },
          ],
          (_) {},
          onClosed: (reason) => closedReason = reason,
        );

        final subId = await refusedRelay.awaitPendingSubscription();
        await refusedRelay.deliver([
          'CLOSED',
          subId,
          'error: too many subscriptions',
        ]);

        expect(closedReason, 'error: too many subscriptions');
        expect(refusedRelay.hasSubscriptionById(subId), isFalse);

        final replacementRelay = _ControlledQueryRelay(
          'wss://replacement.example',
        );
        expect(
          await nostr.relayPool.add(replacementRelay, autoSubscribe: true),
          isTrue,
        );
        expect(
          replacementRelay.sentMessages.where((m) => m.first == 'REQ'),
          isEmpty,
          reason: 'a refused subscription must not replay on a new socket',
        );
      },
    );

    test(
      'CLOSED from one relay preserves a subscription served by another',
      () async {
        final signer = LocalNostrSigner(
          '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12',
        );
        final nostr = Nostr(signer, [], dummyTempRelay);
        final refusedRelay = _ControlledQueryRelay(
          'wss://refused-peer.example',
        );
        final servingRelay = _ControlledQueryRelay(
          'wss://serving-peer.example',
        );
        expect(await nostr.relayPool.add(refusedRelay), isTrue);
        expect(await nostr.relayPool.add(servingRelay), isTrue);

        var closed = false;
        nostr.subscribe(
          [
            {
              'kinds': [1],
            },
          ],
          (_) {},
          onClosed: (_) => closed = true,
        );

        final subId = await refusedRelay.awaitPendingSubscription();
        expect(await servingRelay.awaitPendingSubscription(), subId);
        await refusedRelay.deliver(['CLOSED', subId, 'error: refused']);

        expect(closed, isFalse);
        expect(refusedRelay.hasSubscriptionById(subId), isFalse);
        expect(servingRelay.hasSubscriptionById(subId), isTrue);
      },
    );

    test('CLOSED lets EOSE from every remaining relay complete', () async {
      final signer = LocalNostrSigner(
        '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12',
      );
      final nostr = Nostr(signer, [], dummyTempRelay);
      final completedRelay = _ControlledQueryRelay('wss://completed.example');
      final refusedRelay = _ControlledQueryRelay('wss://refused-after.example');
      expect(await nostr.relayPool.add(completedRelay), isTrue);
      expect(await nostr.relayPool.add(refusedRelay), isTrue);

      var eoseCount = 0;
      nostr.subscribe(
        [
          {
            'kinds': [1],
          },
        ],
        (_) {},
        onEose: () => eoseCount++,
      );

      final subId = await completedRelay.awaitPendingSubscription();
      expect(await refusedRelay.awaitPendingSubscription(), subId);
      await completedRelay.deliver(['EOSE', subId]);
      expect(eoseCount, 0);

      await refusedRelay.deliver(['CLOSED', subId, 'error: refused']);

      expect(eoseCount, 1);
    });

    test(
      'EOSE then CLOSED from one relay does not complete the rest',
      () async {
        final signer = LocalNostrSigner(
          '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12',
        );
        final nostr = Nostr(signer, [], dummyTempRelay);
        final earlyRelay = _ControlledQueryRelay('wss://early.example');
        final slowRelay = _ControlledQueryRelay('wss://slow.example');
        expect(await nostr.relayPool.add(earlyRelay), isTrue);
        expect(await nostr.relayPool.add(slowRelay), isTrue);

        var eoseCount = 0;
        nostr.subscribe(
          [
            {
              'kinds': [1],
            },
          ],
          (_) {},
          onEose: () => eoseCount++,
        );

        final subId = await earlyRelay.awaitPendingSubscription();
        expect(await slowRelay.awaitPendingSubscription(), subId);

        await earlyRelay.deliver(['EOSE', subId]);
        await earlyRelay.deliver(['CLOSED', subId, 'error: refused']);

        expect(eoseCount, 0, reason: 'slow.example has not reported EOSE yet');

        await slowRelay.deliver(['EOSE', subId]);
        expect(eoseCount, 1);
      },
    );

    test('auth-required CLOSED keeps a live subscription for replay', () async {
      final signer = LocalNostrSigner(
        '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12',
      );
      final nostr = Nostr(signer, [], dummyTempRelay);
      final relay = _ControlledQueryRelay('wss://auth-live.example');
      expect(await nostr.relayPool.add(relay), isTrue);

      var closed = false;
      nostr.subscribe(
        [
          {
            'kinds': [1],
          },
        ],
        (_) {},
        sendAfterAuth: true,
        onClosed: (_) => closed = true,
      );

      final subId = await relay.awaitPendingSubscription();
      await relay.deliver(['CLOSED', subId, 'auth-required: sign in']);

      expect(closed, isFalse);
      expect(relay.hasSubscriptionById(subId), isTrue);
    });

    test('auth-required CLOSED keeps the query for post-AUTH replay', () async {
      final signer = LocalNostrSigner(
        '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12',
      );
      final nostr = Nostr(signer, [], dummyTempRelay);
      final relay = _ControlledQueryRelay('wss://auth-required.example');

      expect(await nostr.relayPool.add(relay), isTrue);

      var completedEarly = false;
      final pending = nostr.queryEventsDetailed(
        [
          {
            'kinds': [1],
          },
        ],
        sendAfterAuth: true,
        timeout: const Duration(seconds: 2),
      );
      unawaited(
        pending.whenComplete(() {
          completedEarly = true;
        }),
      );

      final subId = await relay.awaitPendingQuery();
      await relay.deliver(['AUTH', 'test-challenge']);
      await relay.deliver(['CLOSED', subId, 'auth-required: sign in']);

      await Future<void>.delayed(Duration.zero);
      expect(completedEarly, isFalse);
      expect(relay.checkQuery(subId), isTrue);

      final authEventId = relay.capturedAuthEventId;
      expect(authEventId, isNotNull);

      await relay.deliver(['OK', authEventId, true, '']);
      await relay.awaitReqCount(2);
      expect(relay.checkQuery(subId), isTrue);

      await relay.deliver(['EOSE', subId]);

      final result = await pending;
      expect(result.timedOut, isFalse);
      expect(result.events, isEmpty);
      expect(relay.checkQuery(subId), isFalse);
    });

    test(
      'CLOSED does not complete before query fan-out is registered',
      () async {
        final signer = LocalNostrSigner(
          '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12',
        );
        final nostr = Nostr(signer, [], dummyTempRelay);
        final slowSend = Completer<void>();
        final refusedRelay = _ControlledQueryRelay('wss://refused.example');
        final slowRelay = _ControlledQueryRelay(
          'wss://slow.example',
          reqSendGate: slowSend,
        );

        expect(await nostr.relayPool.add(refusedRelay), isTrue);
        expect(await nostr.relayPool.add(slowRelay), isTrue);

        var completedEarly = false;
        final pending = nostr.queryEventsDetailed([
          {
            'kinds': [1],
          },
        ], timeout: const Duration(seconds: 2));
        unawaited(
          pending.whenComplete(() {
            completedEarly = true;
          }),
        );

        final refusedSubId = await refusedRelay.awaitPendingQuery();
        await refusedRelay.deliver([
          'CLOSED',
          refusedSubId,
          'error: query failed',
        ]);

        slowSend.complete();
        final slowSubId = await slowRelay.awaitPendingQuery();
        await Future<void>.delayed(Duration.zero);
        expect(completedEarly, isFalse);

        await slowRelay.deliver(['EOSE', slowSubId]);

        final result = await pending;
        expect(result.timedOut, isFalse);
        expect(result.events, isEmpty);
      },
    );
  });
}
