import 'dart:async';

import 'package:db_client/db_client.dart' hide Filter;
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:nostr_sdk/relay/client_connected.dart';

class _MockRelayManager extends Mock implements RelayManager {}

class _MockAppDbClient extends Mock implements AppDbClient {}

class _MockAppDatabase extends Mock implements AppDatabase {}

class _MockNostrEventsDao extends Mock implements NostrEventsDao {}

class _FakeFilter extends Fake implements Filter {}

const _key = '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';
const _otherKey =
    'a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3';

const _aUrl = 'wss://a.example';
const _bUrl = 'wss://b.example';

/// A relay outside the user's set that a replacement also goes to, as the
/// indexers a relay list is published to.
const _indexerUrl = 'wss://indexer.example';

/// How long a shared connection takes to answer, and a new one.
const _sharedAnswer = Duration(milliseconds: 100);
const _freshAnswer = Duration(milliseconds: 300);
const _timeout = Duration(seconds: 2);

/// A relay connection that answers every REQ with [events] and EOSE after
/// [answerAfter], or never when it is null. One with a [refusal] answers with
/// `CLOSED` and that reason instead. An unreachable one neither connects nor
/// takes a REQ.
class _Connection extends Relay {
  _Connection(
    String url, {
    required this.events,
    this.answerAfter,
    this.refusal,
    this.reachable = true,
  }) : super(url, RelayStatus(url));

  final List<Event> events;
  final Duration? answerAfter;
  final String? refusal;
  final bool reachable;
  final List<List<Map<String, dynamic>>> reqFilters = [];

  @override
  Future<bool> doConnect() async {
    if (!reachable) return false;
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
    if (message.length > 2 && message[0] == 'REQ') {
      if (!reachable) return false;
      final subId = message[1] as String;
      reqFilters.add([
        for (final filter in message.skip(2)) filter as Map<String, dynamic>,
      ]);
      final after = answerAfter;
      final refusal = this.refusal;
      if (after != null && refusal != null) {
        Timer(after, () => _deliver(['CLOSED', subId, refusal]));
      } else if (after != null) {
        for (final event in events) {
          Timer(after, () => _deliver(['EVENT', subId, event.toJson()]));
        }
        Timer(
          after + const Duration(milliseconds: 1),
          () => _deliver(['EOSE', subId]),
        );
      }
    }
    return true;
  }

  void _deliver(List<dynamic> frame) {
    final dynamic result = onMessage!(this, frame);
    if (result is Future) unawaited(result);
  }
}

/// A client over one pooled connection per relay in [held], each holding the
/// events listed for it. Every relay in [held] is one the user publishes to.
/// A new connection opened for a retry holds the same events.
({
  NostrClient client,
  Map<String, _Connection> pooled,
  List<_Connection> fresh,
})
_harness(
  FakeAsync async, {
  required Map<String, List<Event>> held,
  Set<String> silentShared = const {},
  Set<String> silentFresh = const {},
  Set<String> unreachable = const {},
  Map<String, String> refusing = const {},
  Map<String, List<Event>>? freshHeld,
  Map<String, List<Event>> extra = const {},
  AppDbClient? dbClient,
}) {
  final fresh = <_Connection>[];
  final nostr = Nostr(LocalNostrSigner(_key), [], (url) {
    // The pool names a temp relay with a trailing slash.
    final bare = url.replaceFirst(RegExp(r'/$'), '');
    final connection = _Connection(
      url,
      events: (freshHeld ?? held)[bare] ?? extra[bare] ?? const [],
      answerAfter: silentFresh.contains(bare) ? null : _freshAnswer,
      refusal: refusing[bare],
      reachable: !unreachable.contains(bare),
    );
    fresh.add(connection);
    return connection;
  });
  final pooled = <String, _Connection>{
    for (final MapEntry(key: url, value: events) in held.entries)
      url: _Connection(
        url,
        events: events,
        answerAfter: silentShared.contains(url) ? null : _sharedAnswer,
        refusal: refusing[url],
        reachable: !unreachable.contains(url),
      ),
  };
  for (final connection in pooled.values) {
    unawaited(nostr.relayPool.add(connection));
  }
  async.flushMicrotasks();
  final relayManager = _MockRelayManager();
  when(() => relayManager.configuredRelays).thenReturn(held.keys.toList());
  when(() => relayManager.connectedRelays).thenReturn([
    for (final url in held.keys)
      if (!unreachable.contains(url)) url,
  ]);
  when(() => relayManager.isRelayAllowed(any())).thenReturn(true);
  when(() => relayManager.diagnosticsSink).thenReturn(null);
  when(relayManager.dispose).thenAnswer((_) async {});
  when(relayManager.retryDisconnectedRelays).thenAnswer((_) async {});
  return (
    client: NostrClient.forTesting(
      nostr: nostr,
      relayManager: relayManager,
      dbClient: dbClient,
    ),
    pooled: pooled,
    fresh: fresh,
  );
}

/// Runs a read to its end on the fake clock.
CurrentVersionRead _read(
  FakeAsync async,
  NostrClient client, {
  required int kind,
  String? dTag,
  List<String> extraRelays = const [],
}) {
  CurrentVersionRead? result;
  unawaited(
    client
        .readCurrentVersion(
          kind: kind,
          pubkey: getPublicKey(_key),
          dTag: dTag,
          extraRelays: extraRelays,
          timeout: _timeout,
        )
        .then((read) => result = read),
  );
  async.elapse(const Duration(seconds: 60));
  return result!;
}

Event _version(
  int kind, {
  required int createdAt,
  List<List<String>> tags = const [],
  String key = _key,
}) => Event(getPublicKey(key), kind, tags, '', createdAt: createdAt)..sign(key);

String? _foundId(CurrentVersionRead read) =>
    read is CurrentVersionFound ? read.event.id : null;

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeFilter());
    registerFallbackValue(<Event>[]);
  });

  group('NostrClient.readCurrentVersion', () {
    group('arguments', () {
      late NostrClient client;

      setUp(() {
        final relayManager = _MockRelayManager();
        when(() => relayManager.configuredRelays).thenReturn(const []);
        when(() => relayManager.connectedRelays).thenReturn(const []);
        client = NostrClient.forTesting(
          nostr: Nostr(
            LocalNostrSigner(_key),
            [],
            (url) => RelayBase(url, RelayStatus(url)),
          ),
          relayManager: relayManager,
        );
      });

      test('rejects a kind that is neither replaceable nor addressable', () {
        expect(
          client.readCurrentVersion(kind: 1, pubkey: getPublicKey(_key)),
          throwsArgumentError,
        );
        expect(
          client.readCurrentVersion(kind: 20000, pubkey: getPublicKey(_key)),
          throwsArgumentError,
        );
      });

      test('needs a d tag to read an addressable kind', () {
        expect(
          client.readCurrentVersion(kind: 30000, pubkey: getPublicKey(_key)),
          throwsArgumentError,
        );
      });

      test('refuses a d tag for a replaceable kind', () {
        expect(
          client.readCurrentVersion(
            kind: 10000,
            pubkey: getPublicKey(_key),
            dTag: 'block',
          ),
          throwsArgumentError,
        );
      });

      // A version with no d tag sits at the empty address too, and no `#d`
      // filter can match it, so an empty read would always come back absent.
      test('refuses an empty d tag', () {
        expect(
          client.readCurrentVersion(
            kind: 30000,
            pubkey: getPublicKey(_key),
            dTag: '',
          ),
          throwsArgumentError,
        );
      });

      // A key that matches no event would read as absent and invite a
      // replacement built from nothing.
      test('rejects a pubkey that is not a lowercase hex key', () {
        final hex = getPublicKey(_key);
        for (final pubkey in [
          hex.toUpperCase(),
          Nip19.encodePubKey(hex),
          '${hex}0',
        ]) {
          expect(
            client.readCurrentVersion(kind: 10000, pubkey: pubkey),
            throwsArgumentError,
            reason: pubkey,
          );
        }
      });
    });

    group('found', () {
      test('returns the newest version any relay holds', () {
        fakeAsync((async) {
          final older = _version(
            10000,
            createdAt: 1000,
            tags: [
              ['p', getPublicKey(_otherKey)],
            ],
          );
          final newer = _version(10000, createdAt: 2000);
          final h = _harness(
            async,
            held: {
              _aUrl: [older],
              _bUrl: [newer],
            },
          );

          final read = _read(async, h.client, kind: 10000);

          expect(_foundId(read), newer.id);
        });
      });

      for (final swapped in [false, true]) {
        test('breaks a same-second tie by the lowest id '
            '(lowest ${swapped ? 'second' : 'first'})', () {
          fakeAsync((async) {
            final one = _version(
              10000,
              createdAt: 1000,
              tags: [
                ['p', getPublicKey(_otherKey)],
              ],
            );
            final two = _version(10000, createdAt: 1000);
            final ids = [one.id, two.id]..sort();
            // Whichever relay is asked first, the lowest id must win.
            final (first, second) = (one.id == ids.first) != swapped
                ? (one, two)
                : (two, one);
            final h = _harness(
              async,
              held: {
                _aUrl: [first],
                _bUrl: [second],
              },
            );

            final read = _read(async, h.client, kind: 10000);

            expect(_foundId(read), ids.first);
          });
        });
      }

      test('asks every relay for the address, d tag included', () {
        fakeAsync((async) {
          final list = _version(
            30000,
            createdAt: 1000,
            tags: [
              ['d', 'block'],
            ],
          );
          final h = _harness(
            async,
            held: {
              _aUrl: [list],
            },
          );

          final read = _read(async, h.client, kind: 30000, dTag: 'block');

          expect(_foundId(read), list.id);
          expect(h.pooled[_aUrl]!.reqFilters.single.single['#d'], ['block']);
        });
      });
    });

    group('absent', () {
      test('reports absent when every relay answers with nothing', () {
        fakeAsync((async) {
          final h = _harness(async, held: {_aUrl: const [], _bUrl: const []});

          final read = _read(async, h.client, kind: 10000);

          expect(read, isA<CurrentVersionAbsent>());
        });
      });

      test('does not answer from the local cache', () {
        fakeAsync((async) {
          final cached = _version(10000, createdAt: 1000);
          final dbClient = _MockAppDbClient();
          final database = _MockAppDatabase();
          final dao = _MockNostrEventsDao();
          when(() => dbClient.database).thenReturn(database);
          when(() => database.nostrEventsDao).thenReturn(dao);
          when(
            () => dao.getEventsByFilter(any()),
          ).thenAnswer((_) async => [cached]);
          when(() => dao.upsertEventsBatch(any())).thenAnswer((_) async {});
          final h = _harness(
            async,
            held: {_aUrl: const []},
            dbClient: dbClient,
          );

          final read = _read(async, h.client, kind: 10000);

          expect(read, isA<CurrentVersionAbsent>());
        });
      });

      // The pool admits an event when any of its `d` tags matches the filter,
      // but an addressable event's address is its first `d` tag.
      test('ignores a version whose first d tag names another address', () {
        fakeAsync((async) {
          final elsewhere = _version(
            30000,
            createdAt: 1000,
            tags: [
              ['d', 'mute'],
              ['d', 'block'],
            ],
          );
          final h = _harness(
            async,
            held: {
              _aUrl: [elsewhere],
            },
          );

          final read = _read(async, h.client, kind: 30000, dTag: 'block');

          expect(read, isA<CurrentVersionAbsent>());
        });
      });
    });

    group('failed', () {
      test('fails when a relay never answers, though another returned a '
          'version', () {
        fakeAsync((async) {
          final older = _version(10000, createdAt: 1000);
          final h = _harness(
            async,
            held: {
              _aUrl: [older],
              _bUrl: const [],
            },
            silentShared: {_bUrl},
            silentFresh: {_bUrl},
          );

          final read = _read(async, h.client, kind: 10000);

          expect(read, isA<CurrentVersionFailed>());
          expect((read as CurrentVersionFailed).noRelay, isFalse);
        });
      });

      // A terminal refusal, the kind a read passing
      // acceptRelayClosedWhenOthersAnswered would settle on.
      test('fails when a relay refuses the read, though another returned a '
          'version', () {
        fakeAsync((async) {
          final older = _version(10000, createdAt: 1000);
          final h = _harness(
            async,
            held: {
              _aUrl: [older],
              _bUrl: const [],
            },
            refusing: {_bUrl: 'blocked: reads are closed to this key'},
          );

          final read = _read(async, h.client, kind: 10000);

          expect(read, isA<CurrentVersionFailed>());
          expect((read as CurrentVersionFailed).noRelay, isFalse);
        });
      });

      test('fails when a relay the user publishes to cannot be reached', () {
        fakeAsync((async) {
          final older = _version(10000, createdAt: 1000);
          final h = _harness(
            async,
            held: {
              _aUrl: [older],
              _bUrl: const [],
            },
            unreachable: {_bUrl},
          );

          final read = _read(async, h.client, kind: 10000);

          expect(read, isA<CurrentVersionFailed>());
        });
      });

      test('fails without a relay to ask', () {
        fakeAsync((async) {
          final h = _harness(async, held: const {});

          final read = _read(async, h.client, kind: 10000);

          expect(read, isA<CurrentVersionFailed>());
          expect((read as CurrentVersionFailed).noRelay, isTrue);
        });
      });
    });

    group('extra relays', () {
      test('returns a newer version only an extra relay holds', () {
        fakeAsync((async) {
          final older = _version(10002, createdAt: 1000);
          final newer = _version(10002, createdAt: 2000);
          final h = _harness(
            async,
            held: {
              _aUrl: [older],
            },
            extra: {
              _indexerUrl: [newer],
            },
          );

          final read = _read(
            async,
            h.client,
            kind: 10002,
            extraRelays: const [_indexerUrl],
          );

          expect(_foundId(read), newer.id);
        });
      });

      test('asks the extra relays in the first read, without a retry', () {
        fakeAsync((async) {
          final h = _harness(
            async,
            held: {
              _aUrl: [_version(10002, createdAt: 1000)],
            },
            extra: {_indexerUrl: const []},
          );

          _read(async, h.client, kind: 10002, extraRelays: const [_indexerUrl]);

          final opened = [
            for (final connection in h.fresh)
              connection.url.replaceFirst(RegExp(r'/$'), ''),
          ];
          expect(opened, contains(_indexerUrl));
          // A retry would open a new connection to the user's relay too.
          expect(opened, isNot(contains(_aUrl)));
        });
      });

      test('fails when an extra relay never answers', () {
        fakeAsync((async) {
          final h = _harness(
            async,
            held: {
              _aUrl: [_version(10002, createdAt: 1000)],
            },
            extra: {_indexerUrl: const []},
            silentFresh: {_indexerUrl},
          );

          final read = _read(
            async,
            h.client,
            kind: 10002,
            extraRelays: const [_indexerUrl],
          );

          expect(read, isA<CurrentVersionFailed>());
        });
      });
    });

    group('retry over fresh connections', () {
      // A relay behind a load balancer can answer a new connection from a
      // replica that has not caught up.
      test('keeps a newer version the first read saw', () {
        fakeAsync((async) {
          final older = _version(10000, createdAt: 1000);
          final newer = _version(10000, createdAt: 2000);
          final h = _harness(
            async,
            held: {
              _aUrl: [newer],
              _bUrl: const [],
            },
            freshHeld: {
              _aUrl: [older],
              _bUrl: const [],
            },
            silentShared: {_bUrl},
          );

          final read = _read(async, h.client, kind: 10000);

          expect(_foundId(read), newer.id);
        });
      });

      test('answers when the shared connection never does', () {
        fakeAsync((async) {
          final list = _version(10000, createdAt: 1000);
          final h = _harness(
            async,
            held: {
              _aUrl: [list],
            },
            silentShared: {_aUrl},
          );

          final read = _read(async, h.client, kind: 10000);

          expect(_foundId(read), list.id);
          expect(h.fresh, isNotEmpty);
        });
      });

      test('ignores an event for another address', () {
        fakeAsync((async) {
          final block = _version(
            30000,
            createdAt: 1000,
            tags: [
              ['d', 'block'],
            ],
          );
          final topEight = _version(
            30000,
            createdAt: 2000,
            tags: [
              ['d', 'top8'],
            ],
          );
          final h = _harness(
            async,
            held: {
              _aUrl: [topEight, block],
            },
            silentShared: {_aUrl},
          );

          final read = _read(async, h.client, kind: 30000, dTag: 'block');

          expect(_foundId(read), block.id);
        });
      });

      test('ignores an event by another author', () {
        fakeAsync((async) {
          final ours = _version(10000, createdAt: 1000);
          final theirs = _version(10000, createdAt: 2000, key: _otherKey);
          final h = _harness(
            async,
            held: {
              _aUrl: [theirs, ours],
            },
            silentShared: {_aUrl},
          );

          final read = _read(async, h.client, kind: 10000);

          expect(_foundId(read), ours.id);
        });
      });
    });

    test('never returns a version whose signature does not verify', () {
      fakeAsync((async) {
        final valid = _version(10000, createdAt: 1000);
        final forged = Event(
          getPublicKey(_key),
          10000,
          const [],
          'forged',
          createdAt: 2000,
        )..sig = valid.sig;
        final h = _harness(
          async,
          held: {
            _aUrl: [forged, valid],
          },
        );
        // Divine's own relays may be exempt from the pool's check.
        h.client.signatureVerificationPolicy =
            SignatureVerificationPolicy.untrustedRelays;

        final read = _read(async, h.client, kind: 10000);

        expect(read, isA<CurrentVersionFound>());
        expect(_foundId(read), valid.id);
      });
    });
  });
}
