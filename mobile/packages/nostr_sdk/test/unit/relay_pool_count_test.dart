// ABOUTME: Unit tests for NIP-45 COUNT functionality in RelayPool.
// ABOUTME: Tests the count method and countEvents on Nostr class.

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:nostr_sdk/relay/client_connected.dart';
import 'package:nostr_sdk/relay/relay_info.dart';

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

  group('RelayPool.count beside a relay that does not support COUNT', () {
    const countingUrl = 'wss://counting.test';
    const legacyUrl = 'wss://legacy.test';
    const countId = 'count-9009';
    // strfry before 1.1 answers a COUNT with this NOTICE, which carries no
    // subscription id.
    const unknownCommandNotice = 'ERROR: bad msg: unknown cmd';
    final filters = [
      {
        'kinds': [7],
        '#e': [
          '2e6763e2f81be92707635a221f4e27ad8740df553b1b5058cf5a8cb125a7cbd3',
        ],
      },
    ];

    late FakeWebSocketChannelFactory countingFactory;
    late FakeWebSocketChannelFactory legacyFactory;
    late RelayBase countingRelay;
    late RelayBase legacyRelay;
    late Nostr nostr;

    setUp(() {
      countingFactory = FakeWebSocketChannelFactory();
      legacyFactory = FakeWebSocketChannelFactory();
      nostr = Nostr(
        LocalNostrSigner(
          '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12',
        ),
        [],
        (url) =>
            RelayBase(url, RelayStatus(url), channelFactory: countingFactory),
      );
      countingRelay = RelayBase(
        countingUrl,
        RelayStatus(countingUrl),
        channelFactory: countingFactory,
      );
      legacyRelay = RelayBase(
        legacyUrl,
        RelayStatus(legacyUrl),
        channelFactory: legacyFactory,
      );
    });

    tearDown(() => nostr.close());

    // A relay reads its NIP-11 document only when it has none, on connect,
    // so a test that supplies one sets it before adding the relay.
    Future<void> addRelays() async {
      expect(await nostr.relayPool.add(countingRelay), isTrue);
      expect(await nostr.relayPool.add(legacyRelay), isTrue);
    }

    RelayInfo nip11Listing(List<int> nips) =>
        RelayInfo('', '', '', '', nips, '', '');

    Future<CountResponse> count({String id = countId}) => nostr.relayPool.count(
      filters,
      id: id,
      timeout: const Duration(seconds: 3),
    );

    Iterable<String> countFramesOn(FakeWebSocketChannel channel) => channel
        .sentMessages
        .cast<String>()
        .where((frame) => frame.startsWith('["COUNT"'));

    void answerCount(FakeWebSocketChannel channel, int count) {
      final frame = jsonDecode(countFramesOn(channel).last) as List<dynamic>;
      channel.simulateMessage(
        jsonEncode([
          'COUNT',
          frame[1],
          {'count': count},
        ]),
      );
    }

    void sendNotice(FakeWebSocketChannel channel, String message) =>
        channel.simulateMessage(jsonEncode(['NOTICE', message]));

    test('answers once the counting relay has, when the other relay replies '
        'that it does not know COUNT', () async {
      await addRelays();
      var settled = false;
      final result = count();
      unawaited(result.whenComplete(() => settled = true));
      await pumpEventQueue();

      answerCount(countingFactory.lastChannel!, 42);
      sendNotice(legacyFactory.lastChannel!, unknownCommandNotice);
      await pumpEventQueue();

      expect(settled, isTrue);
      expect((await result).count, equals(42));
    });

    test('stops asking a relay that replied it does not know COUNT', () async {
      await addRelays();
      final first = count();
      await pumpEventQueue();
      answerCount(countingFactory.lastChannel!, 42);
      sendNotice(legacyFactory.lastChannel!, unknownCommandNotice);
      expect((await first).count, equals(42));

      final second = count(id: 'count-9009-again');
      await pumpEventQueue();

      expect(countFramesOn(legacyFactory.lastChannel!), hasLength(1));
      answerCount(countingFactory.lastChannel!, 43);
      expect((await second).count, equals(43));
    });

    test('keeps waiting on a relay whose NOTICE is not about COUNT', () async {
      await addRelays();
      final result = count();
      await pumpEventQueue();

      answerCount(countingFactory.lastChannel!, 42);
      sendNotice(legacyFactory.lastChannel!, 'rate-limited: slow down');
      await pumpEventQueue();
      answerCount(legacyFactory.lastChannel!, 99);

      expect((await result).count, equals(99));
    });

    test('keeps asking a relay that said it does not know a command while no '
        'COUNT was waiting on it', () async {
      await addRelays();
      sendNotice(legacyFactory.lastChannel!, unknownCommandNotice);
      await pumpEventQueue();

      final result = count();
      await pumpEventQueue();

      expect(countFramesOn(legacyFactory.lastChannel!), hasLength(1));
      answerCount(countingFactory.lastChannel!, 42);
      answerCount(legacyFactory.lastChannel!, 7);
      expect((await result).count, equals(42));
    });

    for (final (description, nips) in [
      ('lists NIP-45', [1, 11, 45]),
      ('omits NIP-45', [1, 11]),
      ('lists no NIPs', <int>[]),
    ]) {
      test('still asks a relay whose NIP-11 document $description', () async {
        legacyRelay.info = nip11Listing(nips);
        await addRelays();

        final result = count();
        await pumpEventQueue();

        expect(countFramesOn(legacyFactory.lastChannel!), hasLength(1));
        answerCount(countingFactory.lastChannel!, 42);
        answerCount(legacyFactory.lastChannel!, 99);
        expect((await result).count, equals(99));
      });
    }

    test('skips every relay after each has rejected COUNT', () async {
      await addRelays();

      final isUnsupported = throwsA(
        allOf(
          isA<CountNotSupportedException>(),
          isNot(isA<CountNotSentException>()),
        ),
      );

      final first = expectLater(count(), isUnsupported);
      await pumpEventQueue();
      sendNotice(countingFactory.lastChannel!, unknownCommandNotice);
      sendNotice(legacyFactory.lastChannel!, unknownCommandNotice);
      await first;

      await expectLater(count(id: 'count-9009-again'), isUnsupported);
      expect(countFramesOn(countingFactory.lastChannel!), hasLength(1));
      expect(countFramesOn(legacyFactory.lastChannel!), hasLength(1));
    });

    test('answers once both relays have, when both support COUNT', () async {
      await addRelays();
      var settled = false;
      final result = count();
      unawaited(result.whenComplete(() => settled = true));
      await pumpEventQueue();

      answerCount(countingFactory.lastChannel!, 42);
      answerCount(legacyFactory.lastChannel!, 7);
      await pumpEventQueue();

      expect(settled, isTrue);
      expect((await result).count, equals(42));
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
