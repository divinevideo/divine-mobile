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

/// Signs like [LocalNostrSigner], but holds its first AUTH signature until
/// [releaseFirstAuth] completes: a remote signer still working on it.
class _SlowFirstAuthSigner implements NostrSigner {
  _SlowFirstAuthSigner(String privateKey)
    : _inner = LocalNostrSigner(privateKey);

  final LocalNostrSigner _inner;
  final releaseFirstAuth = Completer<void>();
  var _authsStarted = 0;

  @override
  Future<String?> getPublicKey() => _inner.getPublicKey();

  @override
  Future<Event?> signEvent(Event event) async {
    if (event.kind == EventKind.authentication && _authsStarted++ == 0) {
      await releaseFirstAuth.future;
    }
    return _inner.signEvent(event);
  }

  @override
  Future<Map?> getRelays() => _inner.getRelays();

  @override
  Future<String?> encrypt(String pubkey, String plaintext) =>
      _inner.encrypt(pubkey, plaintext);

  @override
  Future<String?> decrypt(String pubkey, String ciphertext) =>
      _inner.decrypt(pubkey, ciphertext);

  @override
  Future<String?> nip44Encrypt(String pubkey, String plaintext) =>
      _inner.nip44Encrypt(pubkey, plaintext);

  @override
  Future<String?> nip44Decrypt(String pubkey, String ciphertext) =>
      _inner.nip44Decrypt(pubkey, ciphertext);

  @override
  void close() => _inner.close();
}

/// A signer that cannot produce a public key yet, like a remote signer that
/// is still starting.
class _NoKeySigner implements NostrSigner {
  @override
  Future<String?> getPublicKey() async => null;

  @override
  Future<Event?> signEvent(Event event) async => null;

  @override
  Future<Map?> getRelays() async => null;

  @override
  Future<String?> encrypt(String pubkey, String plaintext) async => null;

  @override
  Future<String?> decrypt(String pubkey, String ciphertext) async => null;

  @override
  Future<String?> nip44Encrypt(String pubkey, String plaintext) async => null;

  @override
  Future<String?> nip44Decrypt(String pubkey, String ciphertext) async => null;

  @override
  void close() {}
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

    test('generates a different id for each query', () async {
      final signer = LocalNostrSigner(
        '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12',
      );
      final firstNostr = Nostr(signer, [], dummyTempRelay);
      final firstRelay = _ControlledQueryRelay('wss://closed-1.example');
      final secondNostr = Nostr(signer, [], dummyTempRelay);
      final secondRelay = _ControlledQueryRelay('wss://closed-2.example');

      expect(await firstNostr.relayPool.add(firstRelay), isTrue);
      expect(await secondNostr.relayPool.add(secondRelay), isTrue);

      const timeout = Duration(seconds: 2);
      const ids = [
        '0739befe110ec68c28a33650b84c10b356015ec3b8401787d05a84ae285c976a',
      ];

      unawaited(
        firstNostr.queryEventsDetailed([
          {'ids': ids, 'limit': 1},
        ], timeout: timeout),
      );
      unawaited(
        secondNostr.queryEventsDetailed([
          {'ids': ids, 'limit': 1},
        ], timeout: timeout),
      );

      final firstId = await firstRelay.awaitPendingQuery();
      final secondId = await secondRelay.awaitPendingQuery();

      expect(firstId, isNot(equals(secondId)));

      await firstRelay.deliver(['CLOSED', firstId, 'error: query failed']);
      await secondRelay.deliver(['CLOSED', secondId, 'error: query failed']);
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

    test('a query refused until AUTH ends as a restricted refusal once the '
        'relay rejects AUTH', () async {
      final signer = LocalNostrSigner(
        '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12',
      );
      final nostr = Nostr(signer, [], dummyTempRelay);
      final answering = _ControlledQueryRelay('wss://answering.example');
      final gated = _ControlledQueryRelay('wss://gated.example');
      expect(await nostr.relayPool.add(answering), isTrue);
      expect(await nostr.relayPool.add(gated), isTrue);

      final pending = nostr.readEvents(
        [
          {
            'kinds': [1059],
          },
        ],
        requireAllRelaysSettled: true,
        timeout: const Duration(seconds: 30),
      );
      final answeredId = await answering.awaitPendingQuery();
      final refusedId = await gated.awaitPendingQuery();
      await answering.deliver(['EOSE', answeredId]);
      await gated.deliver(['AUTH', 'test-challenge']);
      await gated.deliver([
        'CLOSED',
        refusedId,
        'ERROR: auth-required: requested filter requires authentication',
      ]);
      final authEventId = gated.capturedAuthEventId;
      expect(authEventId, isNotNull);
      // relay.damus.io's answer to every AUTH: nothing will replay the query.
      await gated.deliver([
        'OK',
        authEventId,
        false,
        'error: relay needs serviceUrl to be configured before AUTH can work',
      ]);

      final result = await pending.timeout(
        const Duration(seconds: 2),
        onTimeout: () => fail('the query waited for a replay that cannot come'),
      );
      expect(result.endedBy, QueryEnd.relayClosed);
      expect(result.closedRelayReasons, {'wss://gated.example': 'restricted'});
      expect(gated.checkQuery(refusedId), isFalse);
    });

    for (final rejection in [
      'rate-limited: slow down',
      'invalid: created_at too far off',
    ]) {
      test('a query refused until AUTH ends as an auth-required refusal when '
          "the relay answers AUTH with '$rejection'", () async {
        final nostr = Nostr(
          LocalNostrSigner(
            '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12',
          ),
          [],
          dummyTempRelay,
        );
        final answering = _ControlledQueryRelay('wss://answering.example');
        final gated = _ControlledQueryRelay('wss://gated.example');
        expect(await nostr.relayPool.add(answering), isTrue);
        expect(await nostr.relayPool.add(gated), isTrue);

        final pending = nostr.readEvents(
          [
            {
              'kinds': [1059],
            },
          ],
          requireAllRelaysSettled: true,
          timeout: const Duration(seconds: 30),
        );
        final answeredId = await answering.awaitPendingQuery();
        final refusedId = await gated.awaitPendingQuery();
        await answering.deliver(['EOSE', answeredId]);
        await gated.deliver(['AUTH', 'test-challenge']);
        await gated.deliver([
          'CLOSED',
          refusedId,
          'auth-required: requested filter requires authentication',
        ]);
        await gated.deliver([
          'OK',
          gated.capturedAuthEventId,
          false,
          rejection,
        ]);

        final result = await pending.timeout(
          const Duration(seconds: 2),
          onTimeout: () =>
              fail('the query waited for a replay that cannot come'),
        );
        // A later AUTH may still be accepted, so the refusal is not final.
        expect(result.endedBy, QueryEnd.relayClosed);
        expect(result.closedRelayReasons, {
          'wss://gated.example': 'auth-required',
        });
      });
    }

    test('a refusal after the relay rate-limited AUTH on the connection keeps '
        'its auth-required refusal', () async {
      final nostr = Nostr(
        LocalNostrSigner(
          '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12',
        ),
        [],
        dummyTempRelay,
      );
      final answering = _ControlledQueryRelay('wss://answering.example');
      final gated = _ControlledQueryRelay('wss://gated.example');
      expect(await nostr.relayPool.add(answering), isTrue);
      expect(await nostr.relayPool.add(gated), isTrue);
      await gated.deliver(['AUTH', 'test-challenge']);
      await gated.deliver([
        'OK',
        gated.capturedAuthEventId,
        false,
        'rate-limited: slow down',
      ]);

      final pending = nostr.readEvents(
        [
          {
            'kinds': [1059],
          },
        ],
        requireAllRelaysSettled: true,
        timeout: const Duration(milliseconds: 300),
      );
      final answeredId = await answering.awaitPendingQuery();
      final refusedId = await gated.awaitPendingQuery();
      await answering.deliver(['EOSE', answeredId]);
      await gated.deliver([
        'CLOSED',
        refusedId,
        'auth-required: authentication required to read this event kind',
      ]);

      final result = await pending;
      expect(result.closedRelayReasons, {
        'wss://gated.example': 'auth-required',
      });
    });

    test('an EOSE with the auth hint holds the query for the post-AUTH '
        'replay', () async {
      final signer = LocalNostrSigner(
        '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12',
      );
      final nostr = Nostr(signer, [], dummyTempRelay);
      final relay = _ControlledQueryRelay('wss://hinting.example');
      expect(await nostr.relayPool.add(relay), isTrue);

      final pending = nostr.readEvents(
        [
          {
            'kinds': [1059],
          },
        ],
        requireAllRelaysSettled: true,
        timeout: const Duration(seconds: 30),
      );
      final subId = await relay.awaitPendingQuery();
      // NIP-42 / NIP-67: the challenge, then an EOSE saying more may follow
      // an AUTH.
      await relay.deliver(['AUTH', 'test-challenge']);
      await relay.deliver([
        'EOSE',
        subId,
        ['auth'],
      ]);
      expect(relay.checkQuery(subId), isTrue);

      await relay.deliver(['OK', relay.capturedAuthEventId, true, '']);
      await relay.awaitReqCount(2);
      await relay.deliver(['EOSE', subId]);

      final result = await pending.timeout(const Duration(seconds: 2));
      expect(result.endedBy, QueryEnd.complete);
    });

    test('an EOSE with the auth hint ends as a restricted refusal once the '
        'relay rejects AUTH', () async {
      final signer = LocalNostrSigner(
        '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12',
      );
      final nostr = Nostr(signer, [], dummyTempRelay);
      final answering = _ControlledQueryRelay('wss://answering.example');
      final hinting = _ControlledQueryRelay('wss://hinting.example');
      expect(await nostr.relayPool.add(answering), isTrue);
      expect(await nostr.relayPool.add(hinting), isTrue);

      final pending = nostr.readEvents(
        [
          {
            'kinds': [1059],
          },
        ],
        requireAllRelaysSettled: true,
        timeout: const Duration(seconds: 30),
      );
      final answeredId = await answering.awaitPendingQuery();
      final hintedId = await hinting.awaitPendingQuery();
      await answering.deliver(['EOSE', answeredId]);
      await hinting.deliver(['AUTH', 'test-challenge']);
      await hinting.deliver([
        'EOSE',
        hintedId,
        ['auth'],
      ]);
      await hinting.deliver([
        'OK',
        hinting.capturedAuthEventId,
        false,
        'restricted: not for this key',
      ]);

      final result = await pending.timeout(const Duration(seconds: 2));
      expect(result.closedRelayReasons, {
        'wss://hinting.example': 'restricted',
      });
    });

    test('a refusal after the relay already rejected AUTH on the connection '
        'ends at once as restricted', () async {
      final signer = LocalNostrSigner(
        '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12',
      );
      final nostr = Nostr(signer, [], dummyTempRelay);
      final answering = _ControlledQueryRelay('wss://answering.example');
      final gated = _ControlledQueryRelay('wss://gated.example');
      expect(await nostr.relayPool.add(answering), isTrue);
      expect(await nostr.relayPool.add(gated), isTrue);
      // AUTH rejected once on this connection.
      await gated.deliver(['AUTH', 'test-challenge']);
      await gated.deliver([
        'OK',
        gated.capturedAuthEventId,
        false,
        'error: relay needs serviceUrl to be configured before AUTH can work',
      ]);

      final pending = nostr.readEvents(
        [
          {
            'kinds': [1059],
          },
        ],
        requireAllRelaysSettled: true,
        timeout: const Duration(seconds: 30),
      );
      final answeredId = await answering.awaitPendingQuery();
      final refusedId = await gated.awaitPendingQuery();
      await answering.deliver(['EOSE', answeredId]);
      // No new challenge: the relay just refuses again.
      await gated.deliver([
        'CLOSED',
        refusedId,
        'auth-required: authentication required to read this event kind',
      ]);

      final result = await pending.timeout(
        const Duration(seconds: 2),
        onTimeout: () => fail('the query waited for an AUTH that was refused'),
      );
      expect(result.closedRelayReasons, {'wss://gated.example': 'restricted'});
    });

    group('a relay re-added under a removed URL', () {
      const url = 'wss://gated.example';
      late Nostr nostr;
      late _ControlledQueryRelay answering;
      late _ControlledQueryRelay removed;

      setUp(() async {
        nostr = Nostr(
          LocalNostrSigner(
            '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12',
          ),
          [],
          dummyTempRelay,
        );
        answering = _ControlledQueryRelay('wss://answering.example');
        removed = _ControlledQueryRelay(url);
        expect(await nostr.relayPool.add(answering), isTrue);
        expect(await nostr.relayPool.add(removed), isTrue);
        await removed.deliver(['AUTH', 'removed-challenge']);
      });

      Future<_ControlledQueryRelay> readd() async {
        nostr.relayPool.remove(url);
        final readded = _ControlledQueryRelay(url);
        expect(await nostr.relayPool.add(readded), isTrue);
        return readded;
      }

      /// Reads with [readded] refusing until AUTH, then authenticating and
      /// answering, and returns how [readded] ended the read.
      Future<String?> refusedThenAnswered(_ControlledQueryRelay readded) async {
        var completed = false;
        final pending = nostr.readEvents(
          [
            {
              'kinds': [1059],
            },
          ],
          requireAllRelaysSettled: true,
          timeout: const Duration(seconds: 30),
        )..whenComplete(() => completed = true).ignore();
        final answeredId = await answering.awaitPendingQuery();
        final refusedId = await readded.awaitPendingQuery();
        await answering.deliver(['EOSE', answeredId]);
        await readded.deliver(['CLOSED', refusedId, 'auth-required: sign in']);
        await pumpEventQueue();
        expect(
          completed,
          isFalse,
          reason: 'the new socket was judged on the removed one',
        );

        if (readded.capturedAuthEventId == null) {
          await readded.deliver(['AUTH', 'readded-challenge']);
        }
        await readded.deliver(['OK', readded.capturedAuthEventId, true, '']);
        await readded.awaitReqCount(2);
        await readded.deliver(['EOSE', refusedId]);
        final result = await pending.timeout(
          const Duration(seconds: 2),
          onTimeout: () => fail('the replayed read never ended'),
        );
        return result.closedRelayReasons[url];
      }

      test('does not inherit an AUTH rejection', () async {
        await removed.deliver([
          'OK',
          removed.capturedAuthEventId,
          false,
          'restricted: not allowed',
        ]);
        final readded = await readd();

        expect(await refusedThenAnswered(readded), isNot('restricted'));
      });

      test("is not judged on a verdict that arrives late for the removed "
          "relay's AUTH", () async {
        final readded = await readd();
        await removed.deliver([
          'OK',
          removed.capturedAuthEventId,
          false,
          'restricted: not allowed',
        ]);

        expect(await refusedThenAnswered(readded), isNot('restricted'));
      });

      test("is not judged on a late verdict for the removed relay's AUTH "
          'after its own first challenge', () async {
        final readded = await readd();
        await readded.deliver(['AUTH', 'readded-challenge']);
        await removed.deliver([
          'OK',
          removed.capturedAuthEventId,
          false,
          'restricted: not allowed',
        ]);

        expect(await refusedThenAnswered(readded), isNot('restricted'));
      });
    });

    test('a rejection of an AUTH for a superseded challenge leaves the read '
        'parked for the current one', () async {
      final nostr = Nostr(
        LocalNostrSigner(
          '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12',
        ),
        [],
        dummyTempRelay,
      );
      final relay = _ControlledQueryRelay('wss://rechallenging.example');
      expect(await nostr.relayPool.add(relay), isTrue);

      final pending = nostr.readEvents(
        [
          {
            'kinds': [1059],
          },
        ],
        requireAllRelaysSettled: true,
        timeout: const Duration(seconds: 30),
      );
      final subId = await relay.awaitPendingQuery();
      await relay.deliver(['AUTH', 'first-challenge']);
      final staleAuthId = relay.capturedAuthEventId;
      await relay.deliver(['CLOSED', subId, 'auth-required: sign in first']);
      // NIP-42 lets the relay challenge again on the same socket.
      await relay.deliver(['AUTH', 'second-challenge']);
      final currentAuthId = relay.capturedAuthEventId;
      expect(currentAuthId, isNot(staleAuthId));

      await relay.deliver([
        'OK',
        staleAuthId,
        false,
        'restricted: that challenge is gone',
      ]);
      expect(relay.checkQuery(subId), isTrue);

      await relay.deliver(['OK', currentAuthId, true, '']);
      await relay.awaitReqCount(2);
      await relay.deliver(['EOSE', subId]);

      final result = await pending.timeout(const Duration(seconds: 2));
      expect(result.endedBy, QueryEnd.complete);
      expect(result.closedRelayReasons, isEmpty);
    });

    test('an AUTH signed for the previous socket and rejected on the new one '
        'leaves the read parked for the new challenge', () async {
      final signer = _SlowFirstAuthSigner(
        '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12',
      );
      final nostr = Nostr(signer, [], dummyTempRelay);
      final relay = _ControlledQueryRelay('wss://reconnecting.example');
      expect(await nostr.relayPool.add(relay), isTrue);

      // The signer is still working on AUTH1 when the socket drops.
      final firstChallenge = relay.deliver(['AUTH', 'first-challenge']);
      await pumpEventQueue();
      relay.onError('socket dropped');
      relay.relayStatus.connected = ClientConnected.connected;
      relay.relayStatusCallback?.call();

      final pending = nostr.readEvents(
        [
          {
            'kinds': [1059],
          },
        ],
        requireAllRelaysSettled: true,
        timeout: const Duration(seconds: 30),
      );
      final subId = await relay.awaitPendingQuery();
      await relay.deliver(['AUTH', 'second-challenge']);
      final currentAuthId = relay.capturedAuthEventId;
      await relay.deliver(['CLOSED', subId, 'auth-required: sign in first']);

      // AUTH1 finally goes out on the new socket and is rejected there.
      signer.releaseFirstAuth.complete();
      await firstChallenge;
      final staleAuthId = relay.capturedAuthEventId;
      expect(staleAuthId, isNot(currentAuthId));
      await relay.deliver([
        'OK',
        staleAuthId,
        false,
        'auth-required: challenge does not match',
      ]);
      expect(relay.checkQuery(subId), isTrue);

      await relay.deliver(['OK', currentAuthId, true, '']);
      await relay.awaitReqCount(2);
      await relay.deliver(['EOSE', subId]);

      final result = await pending.timeout(const Duration(seconds: 2));
      expect(result.endedBy, QueryEnd.complete);
      expect(result.closedRelayReasons, isEmpty);
    });

    test('a read held after an auth-hinted EOSE is closed on the relay once '
        'AUTH is rejected', () async {
      final nostr = Nostr(
        LocalNostrSigner(
          '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12',
        ),
        [],
        dummyTempRelay,
      );
      final answering = _ControlledQueryRelay('wss://answering.example');
      final hinting = _ControlledQueryRelay('wss://hinting.example');
      expect(await nostr.relayPool.add(answering), isTrue);
      expect(await nostr.relayPool.add(hinting), isTrue);

      final pending = nostr.readEvents(
        [
          {
            'kinds': [1059],
          },
        ],
        requireAllRelaysSettled: true,
        timeout: const Duration(seconds: 30),
      );
      final answeredId = await answering.awaitPendingQuery();
      final hintedId = await hinting.awaitPendingQuery();
      await answering.deliver(['EOSE', answeredId]);
      await hinting.deliver(['AUTH', 'test-challenge']);
      await hinting.deliver([
        'EOSE',
        hintedId,
        ['auth'],
      ]);
      await hinting.deliver([
        'OK',
        hinting.capturedAuthEventId,
        false,
        'restricted: not for this key',
      ]);
      await pending.timeout(const Duration(seconds: 2));

      // The relay still had the subscription open after its EOSE.
      expect(hinting.sentMessages, contains(equals(['CLOSE', hintedId])));
    });

    test('a rejected AUTH does not end a later read that reuses the id of '
        'one parked before', () async {
      final nostr = Nostr(
        LocalNostrSigner(
          '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12',
        ),
        [],
        dummyTempRelay,
      );
      final relay = _ControlledQueryRelay('wss://gated.example');
      expect(await nostr.relayPool.add(relay), isTrue);
      await relay.deliver(['AUTH', 'test-challenge']);
      final authId = relay.capturedAuthEventId;

      Future<QueryResult> page({required Duration timeout}) => nostr.readEvents(
        [
          {
            'kinds': [1059],
          },
        ],
        id: 'dm_drain_page_0',
        requireAllRelaysSettled: true,
        timeout: timeout,
      );

      final first = page(timeout: const Duration(milliseconds: 300));
      final firstId = await relay.awaitPendingQuery();
      await relay.deliver(['CLOSED', firstId, 'auth-required: sign in']);
      await first;

      final second = page(timeout: const Duration(seconds: 30));
      final secondId = await relay.awaitPendingQuery();
      expect(secondId, firstId);
      await relay.deliver(['OK', authId, false, 'restricted: not allowed']);
      // Only the earlier read was refused; this one is still being answered.
      expect(relay.checkQuery(secondId), isTrue);

      await relay.deliver(['EOSE', secondId]);
      final result = await second.timeout(const Duration(seconds: 2));
      expect(result.closedRelayReasons, isEmpty);
    });

    test('a query refused while no AUTH was sent keeps its auth-required '
        'refusal', () async {
      final nostr = Nostr(_NoKeySigner(), [], dummyTempRelay);
      final answering = _ControlledQueryRelay('wss://answering.example');
      final gated = _ControlledQueryRelay('wss://gated.example');
      expect(await nostr.relayPool.add(answering), isTrue);
      expect(await nostr.relayPool.add(gated), isTrue);

      final pending = nostr.readEvents(
        [
          {
            'kinds': [1059],
          },
        ],
        requireAllRelaysSettled: true,
        timeout: const Duration(milliseconds: 300),
      );
      final answeredId = await answering.awaitPendingQuery();
      final refusedId = await gated.awaitPendingQuery();
      await answering.deliver(['EOSE', answeredId]);
      // The challenge cannot be answered yet, as with a remote signer that
      // is still starting: the gate may open later, so nothing is final.
      await gated.deliver(['AUTH', 'test-challenge']);
      await gated.deliver([
        'CLOSED',
        refusedId,
        'ERROR: auth-required: requested filter requires authentication',
      ]);

      final result = await pending;
      expect(gated.capturedAuthEventId, isNull);
      expect(result.closedRelayReasons, {
        'wss://gated.example': 'auth-required',
      });
    });

    test("strfry's 'ERROR: auth-required' CLOSED keeps the query for "
        'post-AUTH replay', () async {
      final signer = LocalNostrSigner(
        '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12',
      );
      final nostr = Nostr(signer, [], dummyTempRelay);
      final relay = _ControlledQueryRelay('wss://strfry.example');

      expect(await nostr.relayPool.add(relay), isTrue);

      final pending = nostr.queryEventsDetailed([
        {
          'kinds': [1059],
        },
      ], timeout: const Duration(seconds: 2));

      final subId = await relay.awaitPendingQuery();
      // strfry challenges and refuses in one go, prefixing its own `ERROR: `
      // to the NIP-42 reason (#9467).
      await relay.deliver(['AUTH', 'test-challenge']);
      await relay.deliver([
        'CLOSED',
        subId,
        'ERROR: auth-required: requested filter requires authentication',
      ]);

      expect(relay.checkQuery(subId), isTrue);

      final authEventId = relay.capturedAuthEventId;
      expect(authEventId, isNotNull);
      await relay.deliver(['OK', authEventId, true, '']);
      await relay.awaitReqCount(2);

      await relay.deliver(['EOSE', subId]);
      final result = await pending;
      expect(result.timedOut, isFalse);
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
