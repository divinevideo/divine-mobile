// ABOUTME: Regression tests for the OK-timeout zombie-socket remediation in
// ABOUTME: RelayPool.sendEventAwaitOk (silent relay is force-reconnected).

import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

import '../support/fake_web_socket.dart';

void main() {
  group('RelayPool zombie-socket remediation on OK timeout', () {
    const relayUrl = 'wss://relay.divine.video';
    late LocalNostrSigner signer;
    late Nostr nostr;
    late FakeWebSocketChannelFactory factory;
    late RelayBase relay;

    setUp(() async {
      signer = LocalNostrSigner(
        '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12',
      );
      nostr = Nostr(signer, [], (url) => RelayBase(url, RelayStatus(url)));
      await nostr.refreshPublicKey();
      factory = FakeWebSocketChannelFactory();
      relay = RelayBase(
        relayUrl,
        RelayStatus(relayUrl),
        channelFactory: factory,
      );
      await nostr.relayPool.add(relay);
      addTearDown(nostr.relayPool.removeAll);
    });

    void withControlledRelayClock(void Function(FakeAsync time) body) {
      nostr.relayPool.removeAll();
      fakeAsync((time) {
        // The socket streams and every callback belong to this clock zone.
        signer = LocalNostrSigner(
          '0000000000000000000000000000000000000000000000000000000000000001',
        );
        nostr = Nostr(signer, [], (url) => RelayBase(url, RelayStatus(url)));
        unawaited(nostr.refreshPublicKey());
        factory = FakeWebSocketChannelFactory();
        relay = RelayBase(
          relayUrl,
          RelayStatus(relayUrl),
          channelFactory: factory,
        );
        unawaited(nostr.relayPool.add(relay));
        time.flushMicrotasks();
        try {
          body(time);
        } finally {
          nostr.relayPool.removeAll();
          time.flushMicrotasks();
        }
      });
    }

    Future<PublishOutcome> publishAwaitOk() {
      return nostr.relayPool.sendEventAwaitOk(
        [
          'EVENT',
          {'id': 'zombie-event-id', 'kind': 14},
        ],
        eventId: 'zombie-event-id',
        targetRelays: [relayUrl],
        timeout: const Duration(milliseconds: 100),
      );
    }

    test('a relay that accepts the frame but stays silent for the whole OK '
        'window is force-reconnected and its subscriptions re-sent', () async {
      withControlledRelayClock((time) {
        // Live subscription established before the socket goes zombie.
        nostr.relayPool.subscribe([
          Filter(kinds: const [1059], limit: 1).toJson(),
        ], (_) {});
        expect(factory.createdChannels, hasLength(1));
        final zombieChannel = factory.createdChannels.single;
        final reqFrames = zombieChannel.sentMessages
            .map((m) => jsonDecode(m as String) as List<dynamic>)
            .where((m) => m.first == 'REQ')
            .toList();
        expect(reqFrames, hasLength(1));

        PublishOutcome? outcome;
        unawaited(publishAwaitOk().then((value) => outcome = value));
        time.flushMicrotasks();
        // The EVENT is written before the test advances the OK deadline.
        expect(
          zombieChannel.sentMessages
              .map((m) => jsonDecode(m as String) as List<dynamic>)
              .where((frame) => frame.first == 'EVENT'),
          hasLength(1),
        );
        time.elapse(const Duration(milliseconds: 100));

        expect(outcome?.confirmed, isFalse);
        expect(outcome?.noResponseFrom, contains(relayUrl));
        time.elapse(const Duration(milliseconds: 50));
        expect(
          factory.createdChannels,
          hasLength(2),
          reason: 'the silent zombie connection must be force-reconnected',
        );
        final freshChannel = factory.createdChannels.last;
        final replayedReqs = freshChannel.sentMessages
            .map((m) => jsonDecode(m as String) as List<dynamic>)
            .where((m) => m.first == 'REQ')
            .toList();
        expect(
          replayedReqs,
          hasLength(1),
          reason: 'live subscriptions must survive the forced reconnect',
        );
        expect(replayedReqs.single[1], equals(reqFrames.single[1]));
      });
    });

    test('a relay that stays inbound-active during the OK window is left '
        'alone — silence discriminates zombie from slow', () async {
      final channel = factory.createdChannels.single;
      // Inbound traffic (an unrelated NOTICE) arrives right after the frame
      // is written — before the OK window can close, deterministically even
      // on a loaded test runner: the connection is alive, the relay just
      // did not OK this publish.
      final outcomeFuture = publishAwaitOk();
      await Future<void>.delayed(Duration.zero);
      channel.simulateMessage(jsonEncode(['NOTICE', 'busy']));

      final outcome = await outcomeFuture;
      expect(outcome.confirmed, isFalse);
      expect(outcome.noResponseFrom, contains(relayUrl));

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(
        factory.createdChannels,
        hasLength(1),
        reason: 'an inbound-active connection must not be cycled',
      );
    });

    test('an OK true within the window confirms the publish and triggers no '
        'reconnect', () async {
      withControlledRelayClock((time) {
        final channel = factory.createdChannels.single;
        PublishOutcome? outcome;
        unawaited(publishAwaitOk().then((value) => outcome = value));
        time.flushMicrotasks();
        expect(
          channel.sentMessages
              .map((raw) => jsonDecode(raw as String) as List<dynamic>)
              .where((frame) => frame.first == 'EVENT'),
          hasLength(1),
          reason: 'the relay must receive the publication before its OK',
        );
        expect(outcome, isNull);

        time.elapse(const Duration(milliseconds: 20));
        channel.simulateMessage(
          jsonEncode(['OK', 'zombie-event-id', true, '']),
        );
        time.flushMicrotasks();
        expect(outcome?.confirmed, isTrue);
        expect(outcome?.acceptedBy, equals([relayUrl]));

        // Passing the original deadline must not repair an accepted publish.
        time.elapse(const Duration(milliseconds: 100));
        expect(factory.createdChannels, hasLength(1));
      });
    });

    test('on a multi-relay publish, a sibling that stayed silent for the whole '
        'window is force-cycled even though another relay accepted', () async {
      // The tracker no longer resolves on the first OK-true, so a sibling in
      // noResponseFrom has genuinely had the full publish window to answer
      // and said nothing. That is the wedged-socket signal repair exists for,
      // and a confirmed publish no longer hides it.
      const siblingUrl = 'wss://inbox.example.com';
      final siblingFactory = FakeWebSocketChannelFactory();
      final sibling = RelayBase(
        siblingUrl,
        RelayStatus(siblingUrl),
        channelFactory: siblingFactory,
      );
      await nostr.relayPool.add(sibling);
      expect(siblingFactory.createdChannels, hasLength(1));

      final fastChannel = factory.createdChannels.single;
      final outcomeFuture = nostr.relayPool.sendEventAwaitOk(
        [
          'EVENT',
          {'id': 'zombie-event-id', 'kind': 14},
        ],
        eventId: 'zombie-event-id',
        targetRelays: [relayUrl, siblingUrl],
        timeout: const Duration(milliseconds: 100),
      );
      await Future<void>.delayed(Duration.zero);
      fastChannel.simulateMessage(
        jsonEncode(['OK', 'zombie-event-id', true, '']),
      );

      final outcome = await outcomeFuture;
      expect(outcome.confirmed, isTrue);
      expect(outcome.noResponseFrom, contains(siblingUrl));

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(
        siblingFactory.createdChannels,
        hasLength(2),
        reason:
            'a relay that received the frame and never answered is a zombie '
            'socket, whether or not a sibling accepted',
      );
      expect(factory.createdChannels, hasLength(1));
    });

    test('a sibling that is still receiving traffic is not force-cycled, even '
        'when it does not answer the publish', () async {
      // `isSilentSince` is the guard that keeps the broadened repair from
      // churning healthy connections: any inbound frame since the publish
      // proves the socket is alive, so the relay is left alone.
      const siblingUrl = 'wss://busy.example.com';
      final siblingFactory = FakeWebSocketChannelFactory();
      final sibling = RelayBase(
        siblingUrl,
        RelayStatus(siblingUrl),
        channelFactory: siblingFactory,
      );
      await nostr.relayPool.add(sibling);
      expect(siblingFactory.createdChannels, hasLength(1));

      final fastChannel = factory.createdChannels.single;
      final siblingChannel = siblingFactory.createdChannels.single;
      final outcomeFuture = nostr.relayPool.sendEventAwaitOk(
        [
          'EVENT',
          {'id': 'busy-event-id', 'kind': 14},
        ],
        eventId: 'busy-event-id',
        targetRelays: [relayUrl, siblingUrl],
        timeout: const Duration(milliseconds: 100),
      );
      await Future<void>.delayed(Duration.zero);
      // The sibling stays quiet about this publish but is plainly alive.
      siblingChannel.simulateMessage(jsonEncode(['NOTICE', 'still here']));
      fastChannel.simulateMessage(
        jsonEncode(['OK', 'busy-event-id', true, '']),
      );

      final outcome = await outcomeFuture;
      expect(outcome.noResponseFrom, contains(siblingUrl));

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(
        siblingFactory.createdChannels,
        hasLength(1),
        reason: 'inbound traffic proves the socket is not wedged',
      );
    });

    Future<PublishOutcome> publishWithId(String id) {
      return nostr.relayPool.sendEventAwaitOk(
        [
          'EVENT',
          {'id': id, 'kind': 14},
        ],
        eventId: id,
        targetRelays: [relayUrl],
        timeout: const Duration(milliseconds: 100),
      );
    }

    test('two consecutive silent OK timeouts within the cooldown trigger '
        'exactly one repair', () async {
      // A brownout relay — alive but answering slower than the OK window —
      // times out in silence on every publish and reads as silent each time.
      // The default per-relay cooldown must collapse the second timeout into
      // a no-op instead of force-cycling the connection again.
      final first = await publishWithId('brownout-1');
      expect(first.confirmed, isFalse);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(
        factory.createdChannels,
        hasLength(2),
        reason: 'the first silent timeout must repair the zombie socket',
      );

      final second = await publishWithId('brownout-2');
      expect(second.confirmed, isFalse);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(
        factory.createdChannels,
        hasLength(2),
        reason:
            'a second silent timeout inside the cooldown must not re-cycle '
            'the same relay',
      );
    });

    test(
      'a silent OK timeout after the cooldown elapses repairs again',
      () async {
        // Injecting a tiny cooldown lets the second timeout land after the
        // window has elapsed, so a genuinely still-zombie socket is repaired
        // again rather than being suppressed forever.
        nostr.relayPool.silentRepairCooldown = const Duration(milliseconds: 1);

        final first = await publishWithId('brownout-1');
        expect(first.confirmed, isFalse);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(factory.createdChannels, hasLength(2));

        final second = await publishWithId('brownout-2');
        expect(second.confirmed, isFalse);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(
          factory.createdChannels,
          hasLength(3),
          reason:
              'once the cooldown elapses a subsequent silent timeout must '
              'repair the relay again',
        );
      },
    );

    test('a pending one-shot query on a silent zombie relay is replayed on '
        'the fresh socket after force-reconnect', () async {
      // A one-shot query still awaiting EOSE when the socket goes zombie must
      // be re-issued on the fresh socket. Force-reconnect previously replayed
      // only long-running subscriptions, stranding the query until the
      // caller's own timeout instead of letting a fresh EOSE complete it.
      await nostr.relayPool.query(
        [
          Filter(kinds: const [0], authors: const ['abc'], limit: 1).toJson(),
        ],
        (_) {},
        id: 'pending-query-id',
      );
      final zombieChannel = factory.createdChannels.single;
      final queryReqs = zombieChannel.sentMessages
          .map((m) => jsonDecode(m as String) as List<dynamic>)
          .where((m) => m.first == 'REQ' && m[1] == 'pending-query-id')
          .toList();
      expect(queryReqs, hasLength(1));

      final outcome = await publishWithId('zombie-event-id');
      expect(outcome.confirmed, isFalse);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(factory.createdChannels, hasLength(2));
      final freshChannel = factory.createdChannels.last;
      final replayedReqs = freshChannel.sentMessages
          .map((m) => jsonDecode(m as String) as List<dynamic>)
          .where((m) => m.first == 'REQ' && m[1] == 'pending-query-id')
          .toList();
      expect(
        replayedReqs,
        hasLength(1),
        reason:
            'a pending one-shot query must be replayed on the fresh socket '
            'so it can still EOSE',
      );
    });
  });
}
