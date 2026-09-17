// ABOUTME: Tests for ProfileRepository's NIP-39 identity-tags source API —
// ABOUTME: kind-10011 consult order, kind-0 fallback, and caching (#3936).

import 'package:db_client/db_client.dart' hide Filter, ProfileStats;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:profile_repository/profile_repository.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockUserProfilesDao extends Mock implements UserProfilesDao {}

class _MockIdentityEventsDao extends Mock implements IdentityEventsDao {}

class _MockHttpClient extends Mock implements Client {}

const _pubkey =
    'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';

const _kind0Tags = [
  ['i', 'github:legacy', 'legacy-proof'],
  ['p', 'not-an-i-tag'],
];

Event _identityEvent({
  int createdAt = 1000,
  int kind = ProfileRepository.identityEventKind,
  List<List<String>> tags = const [
    ['i', 'github:modern', 'modern-proof'],
    ['alt', 'External Identities'],
  ],
}) {
  return Event(_pubkey, kind, tags, '', createdAt: createdAt);
}

IdentityEventRow _row({
  required String tagsJson,
  int sourceKind = ProfileRepository.identityEventKind,
  int? sourceCreatedAt,
  String? sourceEventId,
}) {
  return IdentityEventRow(
    pubkey: _pubkey,
    tagsJson: tagsJson,
    sourceKind: sourceKind,
    sourceCreatedAt: sourceCreatedAt,
    sourceEventId: sourceEventId,
  );
}

void main() {
  late _MockNostrClient nostrClient;
  late _MockIdentityEventsDao identityEventsDao;
  late ProfileRepository repository;

  setUpAll(() {
    registerFallbackValue(<Filter>[]);
  });

  ProfileRepository buildRepository({bool withDao = true}) {
    return ProfileRepository(
      nostrClient: nostrClient,
      userProfilesDao: _MockUserProfilesDao(),
      httpClient: _MockHttpClient(),
      identityEventsDao: withDao ? identityEventsDao : null,
    );
  }

  setUp(() {
    nostrClient = _MockNostrClient();
    identityEventsDao = _MockIdentityEventsDao();
    repository = buildRepository();

    when(
      () => identityEventsDao.upsertEvent(
        pubkey: any(named: 'pubkey'),
        tagsJson: any(named: 'tagsJson'),
        sourceKind: any(named: 'sourceKind'),
        sourceCreatedAt: any(named: 'sourceCreatedAt'),
        sourceEventId: any(named: 'sourceEventId'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => identityEventsDao.getEvent(any()),
    ).thenAnswer((_) async => null);
  });

  void stubQuery(
    List<Event> events, {
    bool timedOut = false,
    bool noRelays = false,
  }) {
    when(
      () => nostrClient.queryEventsDetailed(
        any(),
        useCache: false,
        requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
      ),
    ).thenAnswer(
      (_) async => (events: events, timedOut: timedOut, noRelays: noRelays),
    );
  }

  group('ProfileRepository.cachedIdentityTags', () {
    test('returns null when no DAO is wired', () async {
      final bare = buildRepository(withDao: false);
      expect(await bare.cachedIdentityTags(_pubkey), isNull);
    });

    test('returns null when no row is cached', () async {
      when(
        () => identityEventsDao.getEvent(_pubkey),
      ).thenAnswer((_) async => null);
      expect(await repository.cachedIdentityTags(_pubkey), isNull);
    });

    test('returns the decoded cached tags', () async {
      when(() => identityEventsDao.getEvent(_pubkey)).thenAnswer(
        (_) async => _row(tagsJson: '[["i","github:modern","modern-proof"]]'),
      );
      expect(
        await repository.cachedIdentityTags(_pubkey),
        equals([
          ['i', 'github:modern', 'modern-proof'],
        ]),
      );
    });

    test('returns null when the cached row is corrupt', () async {
      when(
        () => identityEventsDao.getEvent(_pubkey),
      ).thenAnswer((_) async => _row(tagsJson: 'not json'));
      expect(await repository.cachedIdentityTags(_pubkey), isNull);
    });

    test(
      'returns null when the cached row is valid JSON of the wrong shape '
      '(TypeError, not just Exception)',
      () async {
        // Valid JSON whose shape breaks the decode casts throws a TypeError
        // (an Error, not an Exception); the decoder must still degrade to
        // null rather than let it escape to a reportable crash.
        for (final malformed in const ['{"not":"a list"}', '[1,2,3]']) {
          when(
            () => identityEventsDao.getEvent(_pubkey),
          ).thenAnswer((_) async => _row(tagsJson: malformed));
          expect(
            await repository.cachedIdentityTags(_pubkey),
            isNull,
            reason: 'wrong-shape "$malformed" should decode to null',
          );
        }
      },
    );
  });

  group('ProfileRepository.freshIdentityTags', () {
    test(
      'returns the live kind-10011 i tags and caches them, picking the '
      'newest event',
      () async {
        final newest = _identityEvent(
          createdAt: 200,
          tags: const [
            ['i', 'github:newest', 'newest-proof'],
          ],
        );
        stubQuery([_identityEvent(createdAt: 100), newest]);

        final tags = await repository.freshIdentityTags(
          pubkey: _pubkey,
          kind0Tags: _kind0Tags,
        );

        expect(
          tags,
          equals([
            ['i', 'github:newest', 'newest-proof'],
          ]),
        );
        verify(
          () => identityEventsDao.upsertEvent(
            pubkey: _pubkey,
            tagsJson: '[["i","github:newest","newest-proof"]]',
            sourceKind: ProfileRepository.identityEventKind,
            sourceCreatedAt: 200,
            sourceEventId: newest.id,
          ),
        ).called(1);
      },
    );

    test(
      'keeps the cached claims when the live event is superseded by the '
      'cached one',
      () async {
        final stale = _identityEvent(
          createdAt: 100,
          tags: const [
            ['i', 'github:modern', 'modern-proof'],
          ],
        );
        stubQuery([stale]);
        when(() => identityEventsDao.getEvent(_pubkey)).thenAnswer(
          (_) async => _row(
            tagsJson:
                '[["i","github:modern","modern-proof"],'
                '["i","twitter:jack","oauth"]]',
            sourceCreatedAt: 200,
            sourceEventId: 'f' * 64,
          ),
        );

        final tags = await repository.freshIdentityTags(
          pubkey: _pubkey,
          kind0Tags: _kind0Tags,
        );

        expect(
          tags,
          equals([
            ['i', 'github:modern', 'modern-proof'],
            ['i', 'twitter:jack', 'oauth'],
          ]),
        );
        // Overwriting here would flip the chips back and erase the newer
        // event the write path checks a publish base against.
        verifyNever(
          () => identityEventsDao.upsertEvent(
            pubkey: any(named: 'pubkey'),
            tagsJson: any(named: 'tagsJson'),
            sourceKind: any(named: 'sourceKind'),
            sourceCreatedAt: any(named: 'sourceCreatedAt'),
            sourceEventId: any(named: 'sourceEventId'),
          ),
        );
      },
    );

    test('caches a live event newer than the cached one', () async {
      final live = _identityEvent(createdAt: 300);
      stubQuery([live]);
      when(() => identityEventsDao.getEvent(_pubkey)).thenAnswer(
        (_) async => _row(
          tagsJson: '[["i","twitter:jack","oauth"]]',
          sourceCreatedAt: 200,
          sourceEventId: 'f' * 64,
        ),
      );

      final tags = await repository.freshIdentityTags(
        pubkey: _pubkey,
        kind0Tags: _kind0Tags,
      );

      // An unlink from another device arrives as a newer event, so the
      // guard must never hold it back.
      expect(
        tags,
        equals([
          ['i', 'github:modern', 'modern-proof'],
        ]),
      );
      verify(
        () => identityEventsDao.upsertEvent(
          pubkey: _pubkey,
          tagsJson: '[["i","github:modern","modern-proof"]]',
          sourceKind: ProfileRepository.identityEventKind,
          sourceCreatedAt: 300,
          sourceEventId: live.id,
        ),
      ).called(1);
    });

    test(
      'caches a live event over a cached row that carries no source event',
      () async {
        stubQuery([_identityEvent(createdAt: 100)]);
        when(() => identityEventsDao.getEvent(_pubkey)).thenAnswer(
          (_) async => _row(tagsJson: '[["i","twitter:jack","oauth"]]'),
        );

        final tags = await repository.freshIdentityTags(
          pubkey: _pubkey,
          kind0Tags: _kind0Tags,
        );

        // Rows written before the source columns existed have nothing to
        // compare against, so the live event wins and stamps them.
        expect(
          tags,
          equals([
            ['i', 'github:modern', 'modern-proof'],
          ]),
        );
        verify(
          () => identityEventsDao.upsertEvent(
            pubkey: _pubkey,
            tagsJson: any(named: 'tagsJson'),
            sourceKind: ProfileRepository.identityEventKind,
            sourceCreatedAt: 100,
            sourceEventId: any(named: 'sourceEventId'),
          ),
        ).called(1);
      },
    );

    test(
      'keeps the live event when the superseding cached row is corrupt',
      () async {
        stubQuery([_identityEvent(createdAt: 100)]);
        when(() => identityEventsDao.getEvent(_pubkey)).thenAnswer(
          (_) async => _row(
            tagsJson: 'not json',
            sourceCreatedAt: 200,
            sourceEventId: 'f' * 64,
          ),
        );

        final tags = await repository.freshIdentityTags(
          pubkey: _pubkey,
          kind0Tags: _kind0Tags,
        );

        expect(
          tags,
          equals([
            ['i', 'github:modern', 'modern-proof'],
          ]),
        );
      },
    );

    test(
      'breaks a same-second tie by lowest event id (deterministic across '
      'relay return order)',
      () async {
        final eventA = _identityEvent(
          createdAt: 500,
          tags: const [
            ['i', 'github:aaa', 'proof-a'],
          ],
        );
        final eventB = _identityEvent(
          createdAt: 500,
          tags: const [
            ['i', 'github:bbb', 'proof-b'],
          ],
        );
        // Both share created_at, so NIP-01 picks the lowest event id.
        final winner = eventA.id.compareTo(eventB.id) < 0 ? eventA : eventB;
        final expectedTags = [
          for (final tag in winner.tags)
            if (tag.length >= 3 && tag[0] == 'i') tag,
        ];

        stubQuery([eventA, eventB]);
        expect(
          await repository.freshIdentityTags(
            pubkey: _pubkey,
            kind0Tags: _kind0Tags,
          ),
          equals(expectedTags),
        );

        stubQuery([eventB, eventA]);
        expect(
          await repository.freshIdentityTags(
            pubkey: _pubkey,
            kind0Tags: _kind0Tags,
          ),
          equals(expectedTags),
          reason: 'winner must not depend on relay return order',
        );
      },
    );

    test('strips non-i tags from the live event', () async {
      stubQuery([_identityEvent()]);

      final tags = await repository.freshIdentityTags(
        pubkey: _pubkey,
        kind0Tags: _kind0Tags,
      );

      expect(
        tags,
        equals([
          ['i', 'github:modern', 'modern-proof'],
        ]),
      );
    });

    test('works without a DAO (no persistence)', () async {
      stubQuery([_identityEvent()]);
      final bare = buildRepository(withDao: false);

      final tags = await bare.freshIdentityTags(
        pubkey: _pubkey,
        kind0Tags: _kind0Tags,
      );

      expect(tags, hasLength(1));
      verifyNever(
        () => identityEventsDao.upsertEvent(
          pubkey: any(named: 'pubkey'),
          tagsJson: any(named: 'tagsJson'),
          sourceKind: any(named: 'sourceKind'),
          sourceCreatedAt: any(named: 'sourceCreatedAt'),
          sourceEventId: any(named: 'sourceEventId'),
        ),
      );
    });

    test(
      'keeps a cached kind-10011 row when the live query finds nothing '
      '(transient relay miss must not downgrade the source)',
      () async {
        stubQuery(const []);
        when(() => identityEventsDao.getEvent(_pubkey)).thenAnswer(
          (_) async => _row(tagsJson: '[["i","github:modern","modern-proof"]]'),
        );

        final tags = await repository.freshIdentityTags(
          pubkey: _pubkey,
          kind0Tags: _kind0Tags,
        );

        expect(
          tags,
          equals([
            ['i', 'github:modern', 'modern-proof'],
          ]),
        );
        verifyNever(
          () => identityEventsDao.upsertEvent(
            pubkey: any(named: 'pubkey'),
            tagsJson: any(named: 'tagsJson'),
            sourceKind: any(named: 'sourceKind'),
            sourceCreatedAt: any(named: 'sourceCreatedAt'),
            sourceEventId: any(named: 'sourceEventId'),
          ),
        );
      },
    );

    test(
      'falls back to kind-0 i tags when a cached kind-10011 row is corrupt, '
      'and caches the fallback',
      () async {
        stubQuery(const []);
        when(
          () => identityEventsDao.getEvent(_pubkey),
        ).thenAnswer((_) async => _row(tagsJson: 'not json'));

        final tags = await repository.freshIdentityTags(
          pubkey: _pubkey,
          kind0Tags: _kind0Tags,
        );

        expect(
          tags,
          equals([
            ['i', 'github:legacy', 'legacy-proof'],
          ]),
        );
        verify(
          () => identityEventsDao.upsertEvent(
            pubkey: _pubkey,
            tagsJson: '[["i","github:legacy","legacy-proof"]]',
            sourceKind: 0,
          ),
        ).called(1);
      },
    );

    test(
      'falls back to kind-0 i tags when nothing is cached, and does not '
      'treat a kind-0-sourced row as authoritative',
      () async {
        stubQuery(const []);
        when(() => identityEventsDao.getEvent(_pubkey)).thenAnswer(
          (_) async => _row(
            tagsJson: '[["i","github:stale","stale-proof"]]',
            sourceKind: 0,
          ),
        );

        final tags = await repository.freshIdentityTags(
          pubkey: _pubkey,
          kind0Tags: _kind0Tags,
        );

        expect(
          tags,
          equals([
            ['i', 'github:legacy', 'legacy-proof'],
          ]),
        );
      },
    );

    test('falls back to kind-0 i tags when the relay query throws', () async {
      when(
        () => nostrClient.queryEventsDetailed(
          any(),
          useCache: false,
          requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
        ),
      ).thenThrow(Exception('relay down'));
      when(
        () => identityEventsDao.getEvent(_pubkey),
      ).thenAnswer((_) async => null);

      final tags = await repository.freshIdentityTags(
        pubkey: _pubkey,
        kind0Tags: _kind0Tags,
      );

      expect(
        tags,
        equals([
          ['i', 'github:legacy', 'legacy-proof'],
        ]),
      );
    });

    test('ignores non-kind-10011 events in the relay response', () async {
      stubQuery([_identityEvent(kind: 0)]);
      when(
        () => identityEventsDao.getEvent(_pubkey),
      ).thenAnswer((_) async => null);

      final tags = await repository.freshIdentityTags(
        pubkey: _pubkey,
        kind0Tags: _kind0Tags,
      );

      expect(
        tags,
        equals([
          ['i', 'github:legacy', 'legacy-proof'],
        ]),
      );
    });

    test(
      'still returns the live kind-10011 tags when the cache write fails',
      () async {
        stubQuery([_identityEvent()]);
        when(
          () => identityEventsDao.upsertEvent(
            pubkey: any(named: 'pubkey'),
            tagsJson: any(named: 'tagsJson'),
            sourceKind: any(named: 'sourceKind'),
            sourceCreatedAt: any(named: 'sourceCreatedAt'),
            sourceEventId: any(named: 'sourceEventId'),
          ),
        ).thenThrow(Exception('disk full'));

        final tags = await repository.freshIdentityTags(
          pubkey: _pubkey,
          kind0Tags: _kind0Tags,
        );

        // Persistence is best-effort — a failed cache write must not
        // discard tags already fetched from the relay.
        expect(
          tags,
          equals([
            ['i', 'github:modern', 'modern-proof'],
          ]),
        );
      },
    );

    test(
      'keeps the live kind-10011 tags when the cache read throws',
      () async {
        final live = _identityEvent(createdAt: 100);
        stubQuery([live]);
        when(
          () => identityEventsDao.getEvent(_pubkey),
        ).thenThrow(Exception('db closed'));

        final tags = await repository.freshIdentityTags(
          pubkey: _pubkey,
          kind0Tags: _kind0Tags,
        );

        // Nothing can say the live event is superseded, and it is still the
        // freshest source in hand — so it wins and gets stamped.
        expect(
          tags,
          equals([
            ['i', 'github:modern', 'modern-proof'],
          ]),
        );
        verify(
          () => identityEventsDao.upsertEvent(
            pubkey: _pubkey,
            tagsJson: '[["i","github:modern","modern-proof"]]',
            sourceKind: ProfileRepository.identityEventKind,
            sourceCreatedAt: 100,
            sourceEventId: live.id,
          ),
        ).called(1);
      },
    );

    test(
      'falls back to kind-0 i tags when the cache read throws, without '
      'writing the fallback over the unreadable row',
      () async {
        stubQuery(const []);
        when(
          () => identityEventsDao.getEvent(_pubkey),
        ).thenThrow(Exception('db closed'));

        final tags = await repository.freshIdentityTags(
          pubkey: _pubkey,
          kind0Tags: _kind0Tags,
        );

        expect(
          tags,
          equals([
            ['i', 'github:legacy', 'legacy-proof'],
          ]),
        );
        // A blind upsert here could downgrade a valid but
        // unreadable-this-tick kind-10011 row to a kind-0 source.
        verifyNever(
          () => identityEventsDao.upsertEvent(
            pubkey: any(named: 'pubkey'),
            tagsJson: any(named: 'tagsJson'),
            sourceKind: any(named: 'sourceKind'),
            sourceCreatedAt: any(named: 'sourceCreatedAt'),
            sourceEventId: any(named: 'sourceEventId'),
          ),
        );
      },
    );
    group('when the identity read does not settle (#6154)', () {
      // Divine's identity events live on relay.divine.video. A general-purpose
      // relay in the pool answering EOSE with nothing used to end the read
      // early, and the empty result read as "this profile has no linked
      // accounts" — blanking the verified-account chips on a device with no
      // cached row to fall back on.
      test(
        'asks every relay to settle before trusting an empty answer',
        () async {
          stubQuery([]);

          await repository.freshIdentityTags(
            pubkey: _pubkey,
            kind0Tags: const [],
          );

          final captured = verify(
            () => nostrClient.queryEventsDetailed(
              any(),
              useCache: false,
              requireAllRelaysSettled: captureAny(
                named: 'requireAllRelaysSettled',
              ),
            ),
          ).captured;
          expect(captured, isNotEmpty);
          expect(captured.every((v) => v == true), isTrue);
        },
      );

      test(
        'still uses an event that arrived before the read ran out of time',
        () async {
          // A partial read is not a failed one. Discarding what arrived would
          // throw away a genuinely newer identity event; _cachedTagsSuperseding
          // (#7081) owns the "is this actually newer" question, not this path.
          stubQuery(
            [
              _identityEvent(
                tags: [
                  ['i', 'twitter:arrived', '123'],
                ],
              ),
            ],
            timedOut: true,
          );

          final tags = await repository.freshIdentityTags(
            pubkey: _pubkey,
            kind0Tags: const [],
          );

          expect(
            tags,
            equals([
              ['i', 'twitter:arrived', '123'],
            ]),
          );
        },
      );
    });
  });
}
