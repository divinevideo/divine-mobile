// ABOUTME: Tests for ProfilePinsRepository — kind-10001 parsing, cached and
// ABOUTME: relay reads, and the pin/unpin read-modify-write against relays.

import 'package:cache_sync/cache_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/repositories/profile_pins_repository.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockSigner extends Mock implements ProfilePinsSigner {}

class _FakeEvent extends Fake implements Event {}

class _InMemoryCacheDao implements CacheDao {
  final Map<String, String> store = {};

  @override
  Future<String?> read(String key) async => store[key];

  @override
  Future<void> write({
    required String key,
    required String payload,
    Duration? ttl,
  }) async {
    store[key] = payload;
  }

  @override
  Future<void> delete(String key) async => store.remove(key);

  @override
  Future<void> deletePrefix(String prefix) async =>
      store.removeWhere((key, _) => key.startsWith(prefix));

  @override
  Future<int> totalPayloadBytes() async =>
      store.values.fold<int>(0, (sum, v) => sum + v.length);

  @override
  Future<void> evictOldest(int bytesToFree) async {}
}

const _owner =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _other =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

String _coordinate(String dTag, {String pubkey = _owner}) =>
    '34236:$pubkey:$dTag';

/// A kind-10001 as a relay would return it: unsigned is fine, the repository
/// only reads `tags`, `content`, `created_at`, `id` and `pubkey`.
Event _pinList(
  List<List<String>> tags, {
  String pubkey = _owner,
  int createdAt = 1000,
  String content = '',
}) => Event(pubkey, EventKind.pinList, tags, content, createdAt: createdAt);

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeEvent());
    registerFallbackValue(<Filter>[]);
  });

  group(ProfilePinsRepository, () {
    late _MockNostrClient nostrClient;
    late _MockSigner signer;
    late _InMemoryCacheDao cacheDao;
    late ProfilePinsRepository repository;

    /// The tags/content/created_at of the last kind-10001 handed to the
    /// signer, which is the whole observable output of a mutation.
    List<List<String>>? signedTags;
    String? signedContent;
    int? signedCreatedAt;

    final now = DateTime.fromMillisecondsSinceEpoch(2_000_000 * 1000);

    void stubRelayAnswer(
      List<Event> events, {
      bool timedOut = false,
      bool noRelays = false,
    }) {
      when(
        () => nostrClient.queryEventsDetailed(
          any(),
          useCache: any(named: 'useCache'),
          requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
        ),
      ).thenAnswer(
        (_) async => (events: events, timedOut: timedOut, noRelays: noRelays),
      );
    }

    void stubPublish({required bool accepted}) {
      when(
        () => nostrClient.publishEventAwaitOk(any()),
      ).thenAnswer((invocation) async {
        final event = invocation.positionalArguments.first as Event;
        return PublishOutcome(
          eventId: event.id,
          acceptedBy: accepted ? const ['wss://relay.example'] : const [],
          rejectedBy: accepted ? const {} : const {'wss://relay.example': 'no'},
          noResponseFrom: const [],
        );
      });
    }

    setUp(() async {
      nostrClient = _MockNostrClient();
      signer = _MockSigner();
      cacheDao = _InMemoryCacheDao();
      await CacheSync.init(dao: cacheDao);
      signedTags = null;
      signedContent = null;
      signedCreatedAt = null;

      when(() => signer.currentPublicKeyHex).thenReturn(_owner);
      when(
        () => signer.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
          createdAt: any(named: 'createdAt'),
        ),
      ).thenAnswer((invocation) async {
        final named = invocation.namedArguments;
        signedTags = named[#tags] as List<List<String>>?;
        signedContent = named[#content] as String;
        signedCreatedAt = named[#createdAt] as int?;
        return Event(
          _owner,
          named[#kind] as int,
          signedTags ?? const [],
          signedContent!,
          createdAt: signedCreatedAt,
        );
      });
      stubPublish(accepted: true);

      repository = ProfilePinsRepository(
        nostrClient: nostrClient,
        signer: signer,
        now: () => now,
      );
    });

    group('managedCoordinates', () {
      test('keeps only owner-authored kind-34236 coordinates, in stored '
          'order, first occurrence wins', () {
        final event = _pinList([
          ['a', _coordinate('one')],
          ['e', 'f' * 64],
          ['a', _coordinate('foreign', pubkey: _other)],
          ['a', '34235:$_owner:normal-video'],
          ['a', '34236:$_owner:'],
          ['a', _coordinate('two')],
          ['a', _coordinate('one')],
          ['t', 'hashtag'],
        ]);

        expect(ProfilePinsRepository.managedCoordinates(event), [
          _coordinate('one'),
          _coordinate('two'),
        ]);
      });

      test('preserves a colon-containing d value byte-for-byte', () {
        final event = _pinList([
          ['a', _coordinate('vine:2014:abc')],
        ]);

        expect(ProfilePinsRepository.managedCoordinates(event), [
          _coordinate('vine:2014:abc'),
        ]);
      });
    });

    group('fetch', () {
      test(
        'returns the newest list, caches it, and readCached serves it',
        () async {
          stubRelayAnswer([
            _pinList([
              ['a', _coordinate('stale')],
            ]),
            _pinList([
              ['a', _coordinate('fresh')],
            ], createdAt: 2000),
          ]);

          final coordinates = await repository.fetch(_owner);

          expect(coordinates, [_coordinate('fresh')]);
          expect(await repository.readCached(_owner), [_coordinate('fresh')]);
          expect(
            cacheDao.store.keys,
            contains(ProfilePinsRepository.cacheKeyFor(_owner)),
          );
        },
      );

      test('breaks a created_at tie on the lower event id', () async {
        final first = _pinList([
          ['a', _coordinate('first')],
        ]);
        final second = _pinList([
          ['a', _coordinate('second')],
        ]);
        stubRelayAnswer([first, second]);

        final coordinates = await repository.fetch(_owner);

        final lower = first.id.compareTo(second.id) < 0 ? 'first' : 'second';
        expect(coordinates, [_coordinate(lower)]);
      });

      test('a settled empty answer is an empty list and is cached', () async {
        stubRelayAnswer(const []);

        expect(await repository.fetch(_owner), isEmpty);
        expect(await repository.readCached(_owner), isEmpty);
      });

      test(
        'an inconclusive empty answer is null and leaves the cache alone',
        () async {
          stubRelayAnswer(const [], timedOut: true);

          expect(await repository.fetch(_owner), isNull);
          expect(await repository.readCached(_owner), isNull);
        },
      );

      test('readCached is null before any fetch', () async {
        expect(await repository.readCached(_owner), isNull);
      });
    });

    group('pin', () {
      test('prepends the coordinate and preserves every other tag and the '
          'content verbatim', () async {
        stubRelayAnswer([
          _pinList([
            ['a', _coordinate('older')],
            ['e', 'f' * 64, 'wss://relay.example', 'extra'],
            ['a', _coordinate('foreign', pubkey: _other)],
          ], content: 'ciphertext-from-another-client'),
        ]);

        final result = await repository.pin(_coordinate('newest'));

        expect(result.succeeded, isTrue);
        expect(result.coordinates, [
          _coordinate('newest'),
          _coordinate('older'),
        ]);
        expect(signedTags, [
          ['a', _coordinate('newest')],
          ['a', _coordinate('older')],
          ['e', 'f' * 64, 'wss://relay.example', 'extra'],
          ['a', _coordinate('foreign', pubkey: _other)],
        ]);
        expect(signedContent, 'ciphertext-from-another-client');
        verify(
          () => signer.createAndSignEvent(
            kind: EventKind.pinList,
            content: any(named: 'content'),
            tags: any(named: 'tags'),
            createdAt: any(named: 'createdAt'),
          ),
        ).called(1);
      });

      test('creates the first list from a settled empty answer', () async {
        stubRelayAnswer(const []);

        final result = await repository.pin(_coordinate('first'));

        expect(result.coordinates, [_coordinate('first')]);
        expect(signedTags, [
          ['a', _coordinate('first')],
        ]);
        expect(signedContent, isEmpty);
      });

      test(
        'is a no-op success when the relay already holds the coordinate',
        () async {
          stubRelayAnswer([
            _pinList([
              ['a', _coordinate('already')],
            ]),
          ]);

          final result = await repository.pin(_coordinate('already'));

          expect(result.coordinates, [_coordinate('already')]);
          verifyNever(() => nostrClient.publishEventAwaitOk(any()));
        },
      );

      test('refuses past the cap, counting stored coordinates whether or '
          'not they resolve', () async {
        stubRelayAnswer([
          _pinList([
            for (var i = 0; i < ProfilePinsRepository.maxPins; i++)
              ['a', _coordinate('stored-$i')],
          ]),
        ]);

        final result = await repository.pin(_coordinate('one-too-many'));

        expect(result.failure, ProfilePinFailure.limitReached);
        verifyNever(() => nostrClient.publishEventAwaitOk(any()));
      });

      test('refuses to write over an inconclusive read', () async {
        stubRelayAnswer(const [], noRelays: true, timedOut: true);

        final result = await repository.pin(_coordinate('v'));

        expect(result.failure, ProfilePinFailure.couldNotReachRelays);
        verifyNever(() => nostrClient.publishEventAwaitOk(any()));
      });

      test('reports a timeout separately from no relays', () async {
        stubRelayAnswer(const [], timedOut: true);

        final result = await repository.pin(_coordinate('v'));

        expect(result.failure, ProfilePinFailure.timedOut);
      });

      test('fails when no relay accepts the replacement', () async {
        stubRelayAnswer(const []);
        stubPublish(accepted: false);

        final result = await repository.pin(_coordinate('v'));

        expect(result.failure, ProfilePinFailure.publishDidNotComplete);
        expect(await repository.readCached(_owner), isNull);
      });

      test('fails when signing does not produce an event', () async {
        stubRelayAnswer(const []);
        when(
          () => signer.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
            createdAt: any(named: 'createdAt'),
          ),
        ).thenAnswer((_) async => null);

        final result = await repository.pin(_coordinate('v'));

        expect(result.failure, ProfilePinFailure.publishDidNotComplete);
      });

      test('fails when signed out', () async {
        when(() => signer.currentPublicKeyHex).thenReturn(null);

        final result = await repository.pin(_coordinate('v'));

        expect(result.failure, ProfilePinFailure.notAuthenticated);
        verifyNever(
          () => nostrClient.queryEventsDetailed(
            any(),
            useCache: any(named: 'useCache'),
            requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
          ),
        );
      });

      test("rejects a coordinate that is not one of the signer's own "
          'kind-34236 videos', () async {
        await expectLater(
          repository.pin(_coordinate('theirs', pubkey: _other)),
          throwsArgumentError,
        );
        await expectLater(
          repository.pin('34235:$_owner:normal'),
          throwsArgumentError,
        );
      });

      test('stamps the replacement past a base whose created_at is ahead of '
          'the clock', () async {
        final aheadOfClock = now.millisecondsSinceEpoch ~/ 1000 + 5;
        stubRelayAnswer([
          _pinList(const [], createdAt: aheadOfClock),
        ]);

        await repository.pin(_coordinate('v'));

        expect(signedCreatedAt, aheadOfClock + 1);
      });

      test(
        'a second mutation builds on the revision the relay just '
        'accepted, even when the relay still answers with the old one',
        () async {
          final oldRevision = _pinList([
            ['a', _coordinate('older')],
          ]);
          stubRelayAnswer([oldRevision]);
          await repository.pin(_coordinate('first'));

          // The relay lags: it still returns the pre-mutation revision.
          stubRelayAnswer([oldRevision]);
          final result = await repository.pin(_coordinate('second'));

          expect(result.coordinates, [
            _coordinate('second'),
            _coordinate('first'),
            _coordinate('older'),
          ]);
        },
      );
    });

    group('unpin', () {
      test('removes every copy of the coordinate and nothing else', () async {
        stubRelayAnswer([
          _pinList([
            ['a', _coordinate('keep')],
            ['a', _coordinate('drop')],
            ['e', 'f' * 64],
            ['a', _coordinate('drop')],
            ['a', _coordinate('drop', pubkey: _other)],
          ], content: 'private'),
        ]);

        final result = await repository.unpin(_coordinate('drop'));

        expect(result.coordinates, [_coordinate('keep')]);
        expect(signedTags, [
          ['a', _coordinate('keep')],
          ['e', 'f' * 64],
          ['a', _coordinate('drop', pubkey: _other)],
        ]);
        expect(signedContent, 'private');
      });

      test(
        'is a no-op success when the coordinate is already absent',
        () async {
          stubRelayAnswer([
            _pinList([
              ['a', _coordinate('other')],
            ]),
          ]);

          final result = await repository.unpin(_coordinate('absent'));

          expect(result.coordinates, [_coordinate('other')]);
          verifyNever(() => nostrClient.publishEventAwaitOk(any()));
        },
      );

      test('mutations run one at a time', () async {
        stubRelayAnswer(const []);
        final order = <String>[];
        when(() => nostrClient.publishEventAwaitOk(any())).thenAnswer((
          invocation,
        ) async {
          final event = invocation.positionalArguments.first as Event;
          order.add('publish:${event.tags.length}');
          return PublishOutcome(
            eventId: event.id,
            acceptedBy: const ['wss://relay.example'],
            rejectedBy: const {},
            noResponseFrom: const [],
          );
        });

        await Future.wait([
          repository.pin(_coordinate('one')),
          repository.pin(_coordinate('two')),
        ]);

        // The second pin read the list the first one published (via the
        // last-accepted revision), so it published two tags, not one.
        expect(order, ['publish:1', 'publish:2']);
      });
    });
  });
}
