// ABOUTME: Tests for RelayDiscoveryService first-success pattern
// ABOUTME: Verifies that discoverRelays returns as soon as any indexer
// ABOUTME: succeeds, rather than waiting for all indexers to complete

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/services/relay_discovery_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Test subclass that overrides WebSocket-based queryIndexerDirect
/// with controllable futures.
class _TestableRelayDiscoveryService extends RelayDiscoveryService {
  _TestableRelayDiscoveryService({
    required List<String> indexerRelays,
    required this.queryHandler,
  }) : super(indexerRelays: indexerRelays);

  final Future<List<DiscoveredRelay>> Function(String indexerUrl) queryHandler;

  @override
  Future<List<DiscoveredRelay>> queryIndexerDirect(
    String indexerUrl,
    String pubkeyHex,
  ) {
    return queryHandler(indexerUrl);
  }
}

// Valid npub for testing (encodes to a valid hex pubkey)
const _testNpub =
    'npub1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqsutm2dy';

void main() {
  group(RelayDiscoveryService, () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    group('discoverRelays - first success pattern', () {
      test(
        'returns immediately when first indexer responds with relays',
        () async {
          final indexer1Completer = Completer<List<DiscoveredRelay>>();
          final indexer2Completer = Completer<List<DiscoveredRelay>>();
          final indexer3Completer = Completer<List<DiscoveredRelay>>();

          final completers = {
            'wss://indexer1': indexer1Completer,
            'wss://indexer2': indexer2Completer,
            'wss://indexer3': indexer3Completer,
          };

          final service = _TestableRelayDiscoveryService(
            indexerRelays: completers.keys.toList(),
            queryHandler: (url) => completers[url]!.future,
          );

          final resultFuture = service.discoverRelays(_testNpub);

          // Only first indexer responds
          indexer1Completer.complete([
            const DiscoveredRelay(url: 'wss://relay.example.com'),
          ]);

          final result = await resultFuture;

          expect(result.success, isTrue);
          expect(result.relays, hasLength(1));
          expect(result.relays.first.url, equals('wss://relay.example.com'));
          expect(result.foundOnIndexer, equals('wss://indexer1'));

          // Other indexers never completed - proves we didn't wait for them
          expect(indexer2Completer.isCompleted, isFalse);
          expect(indexer3Completer.isCompleted, isFalse);
        },
      );

      test(
        'returns result from second indexer when first returns empty',
        () async {
          final indexer1Completer = Completer<List<DiscoveredRelay>>();
          final indexer2Completer = Completer<List<DiscoveredRelay>>();
          final indexer3Completer = Completer<List<DiscoveredRelay>>();

          final completers = {
            'wss://indexer1': indexer1Completer,
            'wss://indexer2': indexer2Completer,
            'wss://indexer3': indexer3Completer,
          };

          final service = _TestableRelayDiscoveryService(
            indexerRelays: completers.keys.toList(),
            queryHandler: (url) => completers[url]!.future,
          );

          final resultFuture = service.discoverRelays(_testNpub);

          // First returns empty, second returns relays
          indexer1Completer.complete(<DiscoveredRelay>[]);
          indexer2Completer.complete([
            const DiscoveredRelay(url: 'wss://relay.from-second.com'),
          ]);

          final result = await resultFuture;

          expect(result.success, isTrue);
          expect(result.foundOnIndexer, equals('wss://indexer2'));

          // Third never needed
          expect(indexer3Completer.isCompleted, isFalse);
        },
      );

      test('returns failure when all indexers return empty', () async {
        final service = _TestableRelayDiscoveryService(
          indexerRelays: ['wss://a', 'wss://b', 'wss://c'],
          queryHandler: (_) async => <DiscoveredRelay>[],
        );

        final result = await service.discoverRelays(_testNpub);

        expect(result.success, isFalse);
        expect(result.errorMessage, equals('No relay list found'));
      });

      test('returns failure when all indexers throw', () async {
        final service = _TestableRelayDiscoveryService(
          indexerRelays: ['wss://a', 'wss://b'],
          queryHandler: (_) async => throw Exception('connection refused'),
        );

        final result = await service.discoverRelays(_testNpub);

        expect(result.success, isFalse);
        expect(result.errorMessage, equals('No relay list found'));
      });

      test(
        'returns result when one indexer succeeds and others throw',
        () async {
          final service = _TestableRelayDiscoveryService(
            indexerRelays: ['wss://bad1', 'wss://good', 'wss://bad2'],
            queryHandler: (url) async {
              if (url == 'wss://good') {
                return [const DiscoveredRelay(url: 'wss://relay.example.com')];
              }
              throw Exception('connection refused');
            },
          );

          final result = await service.discoverRelays(_testNpub);

          expect(result.success, isTrue);
          expect(result.foundOnIndexer, equals('wss://good'));
        },
      );

      test('does not wait for slow indexer when fast one succeeds', () async {
        final slowCompleter = Completer<List<DiscoveredRelay>>();

        final service = _TestableRelayDiscoveryService(
          indexerRelays: ['wss://slow', 'wss://fast'],
          queryHandler: (url) {
            if (url == 'wss://slow') return slowCompleter.future;
            return Future.value([
              const DiscoveredRelay(url: 'wss://relay.fast.com'),
            ]);
          },
        );

        final result = await service.discoverRelays(_testNpub);

        expect(result.success, isTrue);
        expect(result.foundOnIndexer, equals('wss://fast'));
        // Slow indexer still pending - we didn't block on it
        expect(slowCompleter.isCompleted, isFalse);
      });

      test('handles single indexer returning relays', () async {
        final service = _TestableRelayDiscoveryService(
          indexerRelays: ['wss://only-one'],
          queryHandler: (_) async => [
            const DiscoveredRelay(url: 'wss://relay.solo.com'),
          ],
        );

        final result = await service.discoverRelays(_testNpub);

        expect(result.success, isTrue);
        expect(result.relays, hasLength(1));
      });

      test('handles single indexer returning empty', () async {
        final service = _TestableRelayDiscoveryService(
          indexerRelays: ['wss://only-one'],
          queryHandler: (_) async => <DiscoveredRelay>[],
        );

        final result = await service.discoverRelays(_testNpub);

        expect(result.success, isFalse);
      });

      test('caches result after first success', () async {
        final service = _TestableRelayDiscoveryService(
          indexerRelays: ['wss://indexer'],
          queryHandler: (_) async => [
            const DiscoveredRelay(url: 'wss://cached-relay.com'),
          ],
        );

        // First call - queries indexer
        final result1 = await service.discoverRelays(_testNpub);
        expect(result1.foundOnIndexer, equals('wss://indexer'));

        // Second call - should come from cache
        final result2 = await service.discoverRelays(_testNpub);
        expect(result2.foundOnIndexer, equals('cache'));
        expect(result2.relays.first.url, equals('wss://cached-relay.com'));
      });

      test(
        'returns first non-empty when multiple resolve simultaneously',
        () async {
          // All indexers return immediately with results
          final service = _TestableRelayDiscoveryService(
            indexerRelays: ['wss://a', 'wss://b', 'wss://c'],
            queryHandler: (url) async => [
              DiscoveredRelay(url: 'wss://relay-from-$url'),
            ],
          );

          final result = await service.discoverRelays(_testNpub);

          expect(result.success, isTrue);
          // At least one of them should succeed
          expect(result.relays, hasLength(1));
        },
      );
    });
  });

  _authenticityTests();
  _cacheAdmissionTests();

  group('parseRelayListFromJson (#3362 insecure URL filtering)', () {
    late RelayDiscoveryService service;

    setUp(() {
      service = RelayDiscoveryService(indexerRelays: const ['wss://a']);
    });

    Map<String, dynamic> tagsJson(List<List<String>> tags) => {'tags': tags};

    test('keeps wss:// relays', () {
      final relays = service.parseRelayListFromJson(
        tagsJson([
          ['r', 'wss://relay.example.com'],
        ]),
      );
      expect(relays, hasLength(1));
      expect(relays.first.url, equals('wss://relay.example.com'));
    });

    // #6585: a kind-10002 reaches us through a third-party indexer, so it is
    // admitted on remote-supplied terms. The local-stack loopback allowance
    // does not extend to a list that arrived over the network.
    test('drops ws://localhost relays', () {
      final relays = service.parseRelayListFromJson(
        tagsJson([
          ['r', 'ws://localhost:47777'],
        ]),
      );
      expect(relays, isEmpty);
    });

    test('drops private, loopback and link-local targets (#6585)', () {
      final relays = service.parseRelayListFromJson(
        tagsJson([
          ['r', 'wss://127.0.0.1'],
          ['r', 'wss://localhost'],
          ['r', 'wss://10.0.2.2'],
          ['r', 'wss://192.168.1.10'],
          ['r', 'wss://169.254.169.254'],
          ['r', 'wss://[fe80::1]'],
          ['r', 'wss://2130706433'],
          ['r', 'wss://nas.local'],
        ]),
      );
      expect(relays, isEmpty);
    });

    test('caps how many relays one kind-10002 can inject (#6585)', () {
      final relays = service.parseRelayListFromJson(
        tagsJson([
          for (var i = 0; i < 200; i++) ['r', 'wss://flood-$i.example'],
        ]),
      );
      expect(relays, hasLength(RelayListCaps.nip65));
      expect(relays.first.url, 'wss://flood-0.example');
    });

    test('keeps merging markers for admitted relays after the cap', () {
      final relays = service.parseRelayListFromJson(
        tagsJson([
          ['r', 'wss://relay-0.example', 'read'],
          for (var i = 1; i < RelayListCaps.nip65; i++)
            ['r', 'wss://relay-$i.example'],
          ['r', 'wss://overflow.example'],
          ['r', 'wss://relay-0.example', 'write'],
        ]),
      );

      expect(relays, hasLength(RelayListCaps.nip65));
      expect(
        relays.map((relay) => relay.url),
        isNot(contains('wss://overflow.example')),
      );
      expect(relays.first.url, 'wss://relay-0.example');
      expect(relays.first.read, isTrue);
      expect(relays.first.write, isTrue);
    });

    test('drops ws:// non-loopback relays', () {
      final relays = service.parseRelayListFromJson(
        tagsJson([
          ['r', 'ws://attacker.example.com'],
        ]),
      );
      expect(relays, isEmpty);
    });

    test('drops https:// relay tags (NIP-65 advertises WS endpoints only)', () {
      // A published kind:10002 tag like `["r", "https://relay.example.com"]`
      // is not a usable relay endpoint — `normalizeRelayUrl` will
      // reject it downstream. If discovery kept it, `result.hasRelays`
      // would be true and the safe-fallback bootstrap (#2931) would be
      // suppressed, leaving the user with no relays.
      final relays = service.parseRelayListFromJson(
        tagsJson([
          ['r', 'https://relay.example.com'],
          ['r', 'https://relay.divine.video'],
        ]),
      );
      expect(relays, isEmpty);
    });

    test('drops http://localhost relay tags (NIP-65 is WS-only)', () {
      // Even loopback http:// is not a relay — relays speak WebSocket.
      final relays = service.parseRelayListFromJson(
        tagsJson([
          ['r', 'http://localhost:47777'],
          ['r', 'http://attacker.example.com'],
        ]),
      );
      expect(relays, isEmpty);
    });

    test('keeps mixed list filtered to allowed entries only', () {
      final relays = service.parseRelayListFromJson(
        tagsJson([
          ['r', 'wss://good.example.com'],
          ['r', 'ws://attacker.example.com'],
          ['r', 'ws://localhost:8080'],
          ['r', 'https://relay.example.com'],
          ['r', 'http://localhost:47777'],
        ]),
      );
      expect(relays, hasLength(1));
      expect(relays.single.url, 'wss://good.example.com');
    });

    test('drops mis-nested wss://http:// tags (#3362 review follow-up)', () {
      // `wss://http://attacker` parses with host=`http` and path=`//attacker…`.
      // Without the `path.startsWith('//')` guard in `isRelayUrlAllowed`,
      // the predicate would accept it (scheme=wss) and discovery would
      // surface a relay pointing at host `http`. `normalizeRelayUrl`
      // would also reject it downstream, but we don't want
      // discovery's `hasRelays` to flip true on a malformed tag — that
      // would suppress the safe-fallback bootstrap (#2931).
      final relays = service.parseRelayListFromJson(
        tagsJson([
          ['r', 'wss://http://attacker.example.com'],
          ['r', 'wss://https://attacker.example.com'],
          ['r', 'wss://wss://relay.example.com'],
        ]),
      );
      expect(relays, isEmpty);
    });
  });

  group(IndexerRelayConfig, () {
    test('keeps DM inbox lookup policy separate from publication targets', () {
      expect(IndexerRelayConfig.dmInboxLookupRelays, ['wss://purplepag.es']);
      expect(
        IndexerRelayConfig.dmInboxLookupRelays,
        isNot(equals(IndexerRelayConfig.dmInboxDiscoveryRelays)),
      );
    });

    group('safeFallbackRelays (#2931)', () {
      test('is non-empty so DM reachability degrades gracefully', () {
        // Regression guard for #2931: when NIP-65 discovery fails or
        // returns empty, AuthService applies this list so the client is
        // not stuck Divine-only. An empty list would silently break DM
        // delivery for imported accounts without a published kind 10002.
        expect(IndexerRelayConfig.safeFallbackRelays, isNotEmpty);
      });

      test('contains only secure WebSocket URLs', () {
        for (final url in IndexerRelayConfig.safeFallbackRelays) {
          expect(
            url,
            startsWith('wss://'),
            reason: 'fallback relay $url must use wss:// for secure transport',
          );
        }
      });

      test('contains only unique entries', () {
        const urls = IndexerRelayConfig.safeFallbackRelays;
        expect(urls.toSet().length, equals(urls.length));
      });
    });
  });
}

/// #6585 — the indexer query runs on a bare `RelayBase` with its own
/// `onMessage`, so the frame never passes through `RelayPool`, which is the
/// only place inbound events are checked. Whatever survives here is adopted
/// into the persistent relay pool via `NostrClient.addRelays`, and the
/// indexers queried are third-party public relays — so "it answered our REQ"
/// is not evidence the answer is the list we asked for.
void _authenticityTests() {
  group('queryIndexerDirect authenticity (#6585)', () {
    const victimKey =
        '1111111111111111111111111111111111111111111111111111111111111111';
    final victimPubkey = getPublicKey(victimKey);
    late _HostileIndexer indexer;
    late RelayDiscoveryService service;

    Future<List<DiscoveredRelay>> query(Map<String, dynamic> reply) async {
      indexer = await _HostileIndexer.start(reply);
      addTearDown(indexer.stop);
      service = RelayDiscoveryService(indexerRelays: [indexer.url]);
      return service.queryIndexerDirect(indexer.url, victimPubkey);
    }

    /// A genuinely signed kind-10002 for [author].
    Map<String, dynamic> signedRelayList({
      required String privateKey,
      List<List<String>> tags = const [
        ['r', 'wss://legit.example'],
      ],
      int kind = 10002,
      int createdAt = 1700000000,
    }) {
      final event = Event(
        getPublicKey(privateKey),
        kind,
        tags,
        '',
        createdAt: createdAt,
      )..sign(privateKey);
      return event.toJson();
    }

    // Positive control. Without this, every rejection below could be passing
    // because the harness never delivers anything, not because the checks work.
    test(
      'accepts a correctly signed kind-10002 from the author asked for',
      () async {
        indexer = await _HostileIndexer.start(
          signedRelayList(privateKey: victimKey),
        );
        addTearDown(indexer.stop);
        service = RelayDiscoveryService(indexerRelays: [indexer.url]);

        final relays = await service.queryIndexerDirect(
          indexer.url,
          victimPubkey,
        );
        expect(relays.map((r) => r.url), ['wss://legit.example']);
      },
    );

    test('uses an opaque subscription id for the indexer request', () async {
      indexer = await _HostileIndexer.start(
        signedRelayList(privateKey: victimKey),
      );
      addTearDown(indexer.stop);
      service = RelayDiscoveryService(indexerRelays: [indexer.url]);

      await service.queryIndexerDirect(indexer.url, victimPubkey);

      expect(indexer.subscriptionIds, hasLength(1));
      expect(
        RegExp(r'^[0-9a-z]{16}$').hasMatch(indexer.subscriptionIds.single),
        isTrue,
      );
    });

    test('rejects a frame with no signature', () async {
      final unsigned = signedRelayList(privateKey: victimKey)..['sig'] = '';
      expect(await query(unsigned), isEmpty);
    });

    test('rejects a frame with an invalid signature', () async {
      final badSignature = signedRelayList(privateKey: victimKey);
      final sig = badSignature['sig'] as String;
      // BIP-340 signing draws fresh aux randomness every run, so overwriting
      // the first byte with a constant '00' is a no-op on the 1-in-256
      // signature that already starts with '00' — leaving the frame valid.
      final flipped = int.parse(sig.substring(0, 2), radix: 16) ^ 0xff;
      badSignature['sig'] =
          '${flipped.toRadixString(16).padLeft(2, '0')}${sig.substring(2)}';
      expect(await query(badSignature), isEmpty);
    });

    test('rejects a frame signed by somebody else', () async {
      const otherKey =
          '2222222222222222222222222222222222222222222222222222222222222222';
      expect(await query(signedRelayList(privateKey: otherKey)), isEmpty);
    });

    test('rejects a frame whose id does not match its contents', () async {
      final tampered = signedRelayList(privateKey: victimKey)
        ..['tags'] = [
          ['r', 'wss://attacker-controlled.example'],
        ];
      expect(await query(tampered), isEmpty);
    });

    test('rejects a frame of the wrong kind', () async {
      final wrongKind = signedRelayList(privateKey: victimKey, kind: 1);
      expect(await query(wrongKind), isEmpty);
    });

    test('rejects a bare tags blob that is not an event at all', () async {
      expect(
        await query({
          'tags': [
            ['r', 'wss://attacker-controlled.example'],
          ],
        }),
        isEmpty,
      );
    });
  });
}

/// An "indexer" that answers any REQ with whatever it was constructed with.
class _HostileIndexer {
  _HostileIndexer(this._server, this._reply);

  final HttpServer _server;
  final Map<String, dynamic> _reply;
  final List<String> subscriptionIds = [];

  String get url => 'ws://127.0.0.1:${_server.port}';

  static Future<_HostileIndexer> start(Map<String, dynamic> reply) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final indexer = _HostileIndexer(server, reply);
    server.listen((req) async {
      final socket = await WebSocketTransformer.upgrade(req);
      socket.listen((raw) {
        final frame = jsonDecode(raw as String) as List<dynamic>;
        if (frame.isEmpty || frame[0] != 'REQ') return;
        final subId = frame[1] as String;
        indexer.subscriptionIds.add(subId);
        socket
          ..add(jsonEncode(<dynamic>['EVENT', subId, indexer._reply]))
          ..add(jsonEncode(<dynamic>['EOSE', subId]));
      });
    });
    return indexer;
  }

  Future<void> stop() => _server.close(force: true);
}

/// #6585 — the discovery cache holds a list that arrived over the network and
/// survives for 24h, so it is re-admitted on read. Filtering only on write
/// would leave a day-long window in which an entry persisted by an older
/// build is adopted unchecked.
void _cacheAdmissionTests() {
  group('cached relay admission (#6585)', () {
    const npub = 'npub1cachetest';

    Future<List<DiscoveredRelay>> discoverFromCache(
      List<String> cachedUrls,
    ) async {
      SharedPreferences.setMockInitialValues({
        'relay_discovery_$npub': jsonEncode({
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'relays': [
            for (final url in cachedUrls)
              {'url': url, 'read': true, 'write': true},
          ],
        }),
      });
      final service = RelayDiscoveryService(indexerRelays: const ['wss://a']);
      final result = await service.discoverRelays(npub);
      return result.relays;
    }

    test(
      'drops a cached private or loopback relay written by an old build',
      () async {
        final relays = await discoverFromCache([
          'wss://good.example',
          'wss://192.168.1.10',
          'ws://localhost:47777',
          'wss://169.254.169.254',
        ]);
        expect(relays.map((r) => r.url), ['wss://good.example']);
      },
    );

    test('caps an oversized cached list', () async {
      final relays = await discoverFromCache([
        for (var i = 0; i < 100; i++) 'wss://cached-$i.example',
      ]);
      expect(relays, hasLength(RelayListCaps.nip65));
    });

    test('merges a host cached twice into one read-and-write relay', () async {
      // NIP-65 marks a relay per `r` tag, so a host carrying a `read` row and
      // a `write` row is both. Keeping the pair is lossy downstream anyway:
      // `RelayListRepository._markerFor` takes the first match and would
      // republish this host as `read`-only.
      SharedPreferences.setMockInitialValues({
        'relay_discovery_$npub': jsonEncode({
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'relays': [
            {'url': 'wss://both.example', 'read': true, 'write': false},
            {'url': 'wss://both.example', 'read': false, 'write': true},
          ],
        }),
      });
      final service = RelayDiscoveryService(indexerRelays: const ['wss://a']);

      final result = await service.discoverRelays(npub);

      expect(result.relays.map((r) => r.url), ['wss://both.example']);
      expect(result.relays.single.read, isTrue);
      expect(result.relays.single.write, isTrue);
    });

    test('a repeated host does not spend the whole cap', () async {
      // Duplicates used to be counted against the cap, so a list naming one
      // host RelayListCaps.nip65 times dropped every genuine relay after it.
      SharedPreferences.setMockInitialValues({
        'relay_discovery_$npub': jsonEncode({
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'relays': [
            for (var i = 0; i < RelayListCaps.nip65; i++)
              {'url': 'wss://loud.example', 'read': true, 'write': true},
            {'url': 'wss://genuine-one.example', 'read': true, 'write': true},
            {'url': 'wss://genuine-two.example', 'read': true, 'write': true},
          ],
        }),
      });
      final service = RelayDiscoveryService(indexerRelays: const ['wss://a']);

      final result = await service.discoverRelays(npub);

      expect(result.relays.map((r) => r.url), [
        'wss://loud.example',
        'wss://genuine-one.example',
        'wss://genuine-two.example',
      ]);
    });

    test('collapses hosts that differ only by trailing slash', () async {
      SharedPreferences.setMockInitialValues({
        'relay_discovery_$npub': jsonEncode({
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'relays': [
            {'url': 'wss://same.example', 'read': true, 'write': false},
            {'url': 'wss://same.example/', 'read': false, 'write': true},
          ],
        }),
      });
      final service = RelayDiscoveryService(indexerRelays: const ['wss://a']);

      final result = await service.discoverRelays(npub);

      expect(result.relays, hasLength(1));
      expect(result.relays.single.read, isTrue);
      expect(result.relays.single.write, isTrue);
    });
  });
}
