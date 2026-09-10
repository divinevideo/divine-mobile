// ABOUTME: Unit tests for NIP-45 COUNT functionality in RelayPool.
// ABOUTME: Tests the count method and countEvents on Nostr class.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:nostr_sdk/relay/client_connected.dart';

import '../support/fake_web_socket.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RelayPool.count delivery', () {
    const relayUrl = 'wss://relay.test';
    const countId = 'count-8710';
    const filterSentinel = 'filter-sentinel-must-not-reach-diagnostics';
    final filters = [
      {
        'kinds': [16],
        '#a': [
          '34236:82341f882b6eabcd2ba7f1ef90aad961cf074af15b9ef44a09f9d2a8fbfbe6a2'
              ':$filterSentinel',
        ],
      },
    ];

    late List<RelayDiagnostic> diagnostics;
    late FakeWebSocketChannelFactory factory;
    late Nostr nostr;
    late RelayBase relay;

    setUp(() async {
      diagnostics = [];
      factory = FakeWebSocketChannelFactory();
      nostr = Nostr(
        LocalNostrSigner(
          '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12',
        ),
        [],
        (url) => RelayBase(url, RelayStatus(url), channelFactory: factory),
        diagnosticsSink: diagnostics.add,
      );
      relay = RelayBase(
        relayUrl,
        RelayStatus(relayUrl),
        channelFactory: factory,
      );
      expect(await nostr.relayPool.add(relay), isTrue);
    });

    tearDown(() => nostr.close());

    Future<void> dropSocket() async {
      await factory.lastChannel!.closeFromRemote();
      await pumpEventQueue();
      expect(relay.relayStatus.connected, ClientConnected.disconnect);
    }

    Iterable<String> countFramesOn(FakeWebSocketChannel channel) => channel
        .sentMessages
        .cast<String>()
        .where((frame) => frame.startsWith('["COUNT"'));

    Iterable<(RelayDiagnosticSite, RelayDiagnosticLevel)> countDiagnostics() =>
        diagnostics
            .where((entry) => entry.message.contains(countId))
            .map((entry) => (entry.site, entry.level));

    test('does not replay a COUNT the dropped socket could not take once the '
        'socket is back', () async {
      await dropSocket();
      await expectLater(
        nostr.relayPool.count(filters, id: countId),
        throwsA(isA<CountNotSupportedException>()),
      );

      expect(await relay.connect(), isTrue);
      await pumpEventQueue();

      expect(factory.createdChannels, hasLength(2));
      expect(countFramesOn(factory.lastChannel!), isEmpty);
    });

    test('reports a COUNT no relay could take as not sent', () async {
      await dropSocket();

      await expectLater(
        nostr.relayPool.count(filters, id: countId),
        throwsA(isA<CountNotSentException>()),
      );
    });

    test('reports a COUNT a relay took but never answered as unanswered, '
        'not as not sent', () async {
      await expectLater(
        nostr.relayPool.count(
          filters,
          id: countId,
          timeout: const Duration(milliseconds: 50),
        ),
        throwsA(
          allOf(
            isA<CountNotSupportedException>(),
            isNot(isA<CountNotSentException>()),
          ),
        ),
      );

      expect(countFramesOn(factory.lastChannel!), hasLength(1));
    });

    test('does not let a relay that is still connecting hold the COUNT past '
        'its timeout', () async {
      await dropSocket();
      final handshake = Completer<void>();
      addTearDown(() {
        if (!handshake.isCompleted) handshake.complete();
      });
      factory.readyFutureFactory = () => handshake.future;
      unawaited(relay.connect());
      await pumpEventQueue();

      await expectLater(
        nostr.relayPool.count(
          filters,
          id: countId,
          timeout: const Duration(milliseconds: 100),
        ),
        throwsA(isA<CountNotSentException>()),
      );
    }, timeout: const Timeout(Duration(seconds: 3)));

    test('records a COUNT no relay could take as a dispatch diagnostic, '
        'without the filter', () async {
      await dropSocket();
      await expectLater(
        nostr.relayPool.count(filters, id: countId),
        throwsA(isA<CountNotSupportedException>()),
      );

      expect(
        countDiagnostics(),
        contains((
          RelayDiagnosticSite.queryDispatch,
          RelayDiagnosticLevel.info,
        )),
      );
      expect(
        diagnostics.map((entry) => entry.message).join('\n'),
        isNot(contains(filterSentinel)),
      );
    });

    test('records a COUNT a relay never answered as a settlement warning, '
        'without the filter', () async {
      await expectLater(
        nostr.relayPool.count(
          filters,
          id: countId,
          timeout: const Duration(milliseconds: 50),
        ),
        throwsA(isA<CountNotSupportedException>()),
      );

      expect(
        countDiagnostics(),
        contains((
          RelayDiagnosticSite.requestSettlement,
          RelayDiagnosticLevel.warning,
        )),
      );
      expect(
        diagnostics.map((entry) => entry.message).join('\n'),
        isNot(contains(filterSentinel)),
      );
    });
  });

  group('RelayPool count Tests', () {
    late Nostr nostr;
    late LocalNostrSigner signer;
    late String testPrivateKey;

    setUp(() async {
      testPrivateKey =
          '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';
      signer = LocalNostrSigner(testPrivateKey);

      nostr = Nostr(signer, [], (url) => RelayBase(url, RelayStatus(url)));
      await nostr.refreshPublicKey();
    });

    test('count method throws ArgumentError for empty filters', () async {
      await expectLater(
        nostr.relayPool.count([]),
        throwsA(isA<ArgumentError>()),
      );
    });

    test(
      'count method throws CountNotSupportedException when no relays connected',
      () async {
        // No relays are connected in this test setup
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

    test('countEvents method exists and delegates to pool', () async {
      // This test verifies the method signature exists
      await expectLater(
        nostr.countEvents([
          {
            'kinds': [1],
          },
        ]),
        throwsA(isA<CountNotSupportedException>()),
      );
    });

    test('countEvents accepts timeout parameter', () async {
      await expectLater(
        nostr.countEvents([
          {
            'kinds': [1],
          },
        ], timeout: const Duration(milliseconds: 100)),
        throwsA(isA<CountNotSupportedException>()),
      );
    });

    test('countEvents accepts relayTypes parameter', () async {
      await expectLater(
        nostr.countEvents(
          [
            {
              'kinds': [1],
            },
          ],
          relayTypes: [RelayType.normal],
          timeout: const Duration(milliseconds: 100),
        ),
        throwsA(isA<CountNotSupportedException>()),
      );
    });
  });

  group('COUNT message format', () {
    test('COUNT request format is correct', () {
      // Verify the expected message format
      const subscriptionId = 'test_sub';
      final filters = [
        {
          'kinds': [1],
          'authors': ['pubkey123'],
        },
      ];

      final message = ['COUNT', subscriptionId, ...filters];

      expect(message[0], equals('COUNT'));
      expect(message[1], equals('test_sub'));
      expect(message[2], isA<Map<String, dynamic>>());
      expect((message[2] as Map)['kinds'], equals([1]));
    });

    test('multiple filters are included in message', () {
      const subscriptionId = 'test_sub';
      final filters = [
        {
          'kinds': [1],
        },
        {
          'kinds': [7],
          'e': ['event123'],
        },
      ];

      final message = ['COUNT', subscriptionId, ...filters];

      expect(message.length, equals(4)); // COUNT, id, filter1, filter2
      expect(
        message[2],
        equals({
          'kinds': [1],
        }),
      );
      expect(
        message[3],
        equals({
          'kinds': [7],
          'e': ['event123'],
        }),
      );
    });
  });
}
