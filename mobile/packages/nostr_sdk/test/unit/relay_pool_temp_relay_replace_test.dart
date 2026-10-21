// ABOUTME: Pins that callers sharing a temp relay that is still dialing all
// ABOUTME: reach it, and that a temp relay whose dial failed is replaced.

import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

import '../support/fake_web_socket.dart';

const _relayUrl = 'wss://inbox.example';

/// Every frame of [type] written to any socket [factory] opened.
List<List<dynamic>> _framesOfType(
  FakeWebSocketChannelFactory factory,
  String type,
) => [
  for (final channel in factory.createdChannels)
    for (final raw in channel.sentMessages)
      if ((jsonDecode(raw as String) as List<dynamic>).first == type)
        jsonDecode(raw) as List<dynamic>,
];

RelayPool _buildPool(FakeWebSocketChannelFactory factory) {
  final signer = LocalNostrSigner(
    '0000000000000000000000000000000000000000000000000000000000000001',
  );
  Relay gener(String url) =>
      RelayBase(url, RelayStatus(url), channelFactory: factory);
  final pool = RelayPool(Nostr(signer, [], gener), [], gener);
  addTearDown(pool.removeAll);
  return pool;
}

void main() {
  group('RelayPool temp relay replacement', () {
    group('while the first dial is still in its handshake', () {
      late Completer<void> handshake;
      late FakeWebSocketChannelFactory factory;
      late RelayPool pool;

      setUp(() {
        handshake = Completer<void>();
        factory = FakeWebSocketChannelFactory(
          readyFutureFactory: () => handshake.future,
        );
        pool = _buildPool(factory);
      });

      test('two publishes started together both reach the relay', () async {
        const firstId = 'first-wrap-event-id';
        const secondId = 'second-wrap-event-id';
        Future<PublishOutcome> publish(String id) => pool.sendEventAwaitOk(
          [
            'EVENT',
            {'id': id, 'kind': 1059},
          ],
          eventId: id,
          tempRelays: const [_relayUrl],
          targetRelays: const [_relayUrl],
          timeout: const Duration(milliseconds: 500),
        );

        fakeAsync((time) {
          // Construct the handshake and socket callbacks in this clock zone.
          handshake = Completer<void>();
          factory = FakeWebSocketChannelFactory(
            readyFutureFactory: () => handshake.future,
          );
          pool = _buildPool(factory);
          try {
            PublishOutcome? firstOutcome;
            PublishOutcome? secondOutcome;
            unawaited(publish(firstId).then((value) => firstOutcome = value));
            unawaited(publish(secondId).then((value) => secondOutcome = value));
            handshake.complete();
            time.flushMicrotasks();
            for (final channel in factory.createdChannels) {
              channel
                ..simulateMessage(jsonEncode(['OK', firstId, true, '']))
                ..simulateMessage(jsonEncode(['OK', secondId, true, '']));
            }
            time.flushMicrotasks();

            expect(
              _framesOfType(factory, 'EVENT').map((frame) => frame[1]['id']),
              unorderedEquals([firstId, secondId]),
              reason:
                  'the first publish must not be lost when the second one '
                  'asks for the same relay mid-handshake',
            );
            expect(firstOutcome?.acceptedBy, equals([_relayUrl]));
            expect(secondOutcome?.acceptedBy, equals([_relayUrl]));
            expect(factory.createdChannels, hasLength(1));
          } finally {
            pool.removeAll();
            time.flushMicrotasks();
          }
        });
      });

      test('two queries started together both send their REQ', () async {
        final firstQuery = pool.query(
          [
            {
              'kinds': [10050],
              'authors': ['a' * 64],
            },
          ],
          (_) {},
          id: 'first-lookup',
          tempRelays: const [_relayUrl],
          relayTypes: const [RelayType.temp],
        );
        final secondQuery = pool.query(
          [
            {
              'kinds': [10050],
              'authors': ['b' * 64],
            },
          ],
          (_) {},
          id: 'second-lookup',
          tempRelays: const [_relayUrl],
          relayTypes: const [RelayType.temp],
        );
        handshake.complete();
        await pumpEventQueue();

        expect(
          _framesOfType(factory, 'REQ').map((frame) => frame[1]),
          unorderedEquals(['first-lookup', 'second-lookup']),
          reason:
              'a lookup started first must still be asked when a second '
              'one names the same relay mid-handshake',
        );
        expect(factory.createdChannels, hasLength(1));
        expect((await firstQuery).sentTo, hasLength(1));
        expect((await secondQuery).sentTo, hasLength(1));
      });
    });

    group('after the dial failed', () {
      test('the dead temp relay is replaced', () async {
        final factory = FakeWebSocketChannelFactory(
          readyError: StateError('unreachable'),
        );
        final pool = _buildPool(factory);
        final dead = pool.checkAndGenTempRelay(_relayUrl);
        await pumpEventQueue();
        expect(dead.isSocketConnecting, isFalse);

        final replacement = pool.checkAndGenTempRelay(_relayUrl);

        expect(replacement, isNot(same(dead)));
        expect(factory.createdChannels, hasLength(2));
      });
    });
  });
}
