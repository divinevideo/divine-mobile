// ABOUTME: Pins how RelayPool.subscribe and .query route a REQ when
// ABOUTME: tempRelays and targetRelays are supplied, over real sockets
// ABOUTME: rather than mocks.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

import '../support/fake_web_socket.dart';

/// Waits for the fake socket to observe a specific REQ without relying on
/// wall-clock settling.
Future<void> _waitForReq(FakeWebSocketChannelFactory factory, String id) async {
  for (var i = 0; i < 100; i++) {
    if (_reqIds(factory).contains(id)) return;
    await Future<void>.delayed(Duration.zero);
  }
  fail('REQ $id was not written');
}

/// Subscription ids of every `REQ` frame [factory]'s sockets were asked to send.
List<String> _reqIds(FakeWebSocketChannelFactory factory) {
  return [
    for (final channel in factory.createdChannels)
      for (final message in channel.sentMessages)
        if ((jsonDecode(message as String) as List<dynamic>).first == 'REQ')
          (jsonDecode(message) as List<dynamic>)[1] as String,
  ];
}

void main() {
  group('RelayPool relay routing', () {
    // The production shape this guards: divine's own relay plus one of the
    // IndexerRelayConfig.safeFallbackRelays that #2931 connects so DMs
    // written to other relays stay visible.
    const pooledPrimary = 'wss://relay.divine.video';
    const pooledFallback = 'wss://relay.nos.social';
    final filters = [
      {
        'kinds': [1059],
        '#p': ['a' * 64],
      },
    ];

    late FakeWebSocketChannelFactory primaryFactory;
    late FakeWebSocketChannelFactory fallbackFactory;
    late FakeWebSocketChannelFactory tempFactory;
    late List<String> tempRelaysGenerated;
    late Nostr nostr;

    setUp(() async {
      primaryFactory = FakeWebSocketChannelFactory();
      fallbackFactory = FakeWebSocketChannelFactory();
      tempFactory = FakeWebSocketChannelFactory();
      tempRelaysGenerated = <String>[];

      nostr = Nostr(
        LocalNostrSigner(
          '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12',
        ),
        [],
        (url) {
          tempRelaysGenerated.add(url);
          return RelayBase(url, RelayStatus(url), channelFactory: tempFactory);
        },
      );
      await nostr.refreshPublicKey();

      await nostr.relayPool.add(
        RelayBase(
          pooledPrimary,
          RelayStatus(pooledPrimary),
          channelFactory: primaryFactory,
        ),
      );
      await nostr.relayPool.add(
        RelayBase(
          pooledFallback,
          RelayStatus(pooledFallback),
          channelFactory: fallbackFactory,
        ),
      );
    });

    test('untargeted subscribe reaches every pooled relay', () async {
      nostr.relayPool.subscribe(filters, (_) {}, id: 'untargeted');
      await _waitForReq(primaryFactory, 'untargeted');
      await _waitForReq(fallbackFactory, 'untargeted');

      expect(_reqIds(primaryFactory), contains('untargeted'));
      expect(_reqIds(fallbackFactory), contains('untargeted'));
    });

    test(
      'tempRelays ADDS the named relay and leaves the pool subscribed',
      () async {
        // The shape DmRepository.startListening uses for the live gift-wrap
        // read once the user advertises a kind-10050 (#4974, #7320).
        nostr.relayPool.subscribe(
          filters,
          (_) {},
          id: 'temp-only',
          tempRelays: const ['wss://inbox.example'],
        );
        await _waitForReq(primaryFactory, 'temp-only');
        await _waitForReq(fallbackFactory, 'temp-only');
        await _waitForReq(tempFactory, 'temp-only');

        expect(_reqIds(primaryFactory), contains('temp-only'));
        expect(_reqIds(fallbackFactory), contains('temp-only'));
        expect(tempRelaysGenerated, contains('wss://inbox.example/'));
        expect(_reqIds(tempFactory), contains('temp-only'));
      },
    );

    test(
      'targetRelays keeps the pooled relay it names and skips the rest',
      () async {
        // #8377: the membership test compares a `handleAddrList`-normalized
        // target (trailing slash ADDED) against a pool key from
        // `normalizeRelayUrl` (trailing slash STRIPPED). Before the fix those
        // never match, so `targetRelays` is a universal exclusion and NOTHING
        // is subscribed. No tempRelays here — a temp entry would reach the
        // pooled socket by the other path and mask the bug.
        nostr.relayPool.subscribe(
          filters,
          (_) {},
          id: 'target-only',
          targetRelays: const [pooledPrimary],
        );
        await _waitForReq(primaryFactory, 'target-only');

        expect(_reqIds(primaryFactory), contains('target-only'));
        expect(_reqIds(fallbackFactory), isNot(contains('target-only')));
        expect(tempRelaysGenerated, isEmpty);
      },
    );

    test(
      'targetRelays matches a pooled relay given with a trailing slash',
      () async {
        // The identity must hold from both directions: a caller that already
        // supplies the slashed form names the same pooled relay.
        nostr.relayPool.subscribe(
          filters,
          (_) {},
          id: 'target-slashed',
          targetRelays: const ['$pooledPrimary/'],
        );
        await _waitForReq(primaryFactory, 'target-slashed');

        expect(_reqIds(primaryFactory), contains('target-slashed'));
        expect(_reqIds(fallbackFactory), isNot(contains('target-slashed')));
        expect(tempRelaysGenerated, isEmpty);
      },
    );

    test('query targetRelays asks only the pooled relay it names', () async {
      // The same membership test guards `query` (#8377). `sentTo` names the
      // relays that took the REQ, so an empty result is the universal
      // exclusion this fixes — not "every relay had nothing".
      final result = await nostr.relayPool.query(
        filters,
        (_) {},
        id: 'query-target',
        targetRelays: const [pooledPrimary],
      );

      expect(result.sentTo, contains(pooledPrimary));
      expect(result.sentTo, isNot(contains(pooledFallback)));
    });

    test('query targetRelays accepts the trailing-slash form', () async {
      final result = await nostr.relayPool.query(
        filters,
        (_) {},
        id: 'query-target-slashed',
        targetRelays: const ['$pooledPrimary/'],
      );

      expect(result.sentTo, [pooledPrimary]);
      expect(_reqIds(fallbackFactory), isNot(contains('query-target-slashed')));
    });

    test(
      'targetRelays and tempRelays naming one pooled relay share its socket',
      () async {
        // `targetRelays` filters the pool down to the named relay, so the
        // fallback is skipped. Naming that same relay through tempRelays as
        // well must reuse the pooled socket rather than dialing a duplicate.
        nostr.relayPool.subscribe(
          filters,
          (_) {},
          id: 'targeted',
          tempRelays: const [pooledPrimary],
          targetRelays: const [pooledPrimary],
        );
        await _waitForReq(primaryFactory, 'targeted');

        expect(
          _reqIds(primaryFactory).where((id) => id == 'targeted'),
          hasLength(1),
        );
        expect(_reqIds(fallbackFactory), isNot(contains('targeted')));
        expect(tempRelaysGenerated, isEmpty);
      },
    );

    test(
      'query sends one REQ when targetRelays and tempRelays name one pool relay',
      () async {
        final result = await nostr.relayPool.query(
          filters,
          (_) {},
          id: 'query-targeted',
          tempRelays: const [pooledPrimary],
          targetRelays: const [pooledPrimary],
        );

        expect(
          _reqIds(primaryFactory).where((id) => id == 'query-targeted'),
          hasLength(1),
        );
        expect(result.sentTo, [pooledPrimary]);
        expect(_reqIds(fallbackFactory), isNot(contains('query-targeted')));
        expect(tempRelaysGenerated, isEmpty);
      },
    );
  });
}
