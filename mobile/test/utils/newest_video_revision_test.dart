// ABOUTME: Pins the read a video republish rebuilds from: the address, the
// ABOUTME: opened revision as its floor and fallback, and none when deleted.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' show VideoEvent;
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/nostr_sdk.dart' show generatePrivateKey, getPublicKey;
import 'package:openvine/utils/newest_video_revision.dart';
import 'package:videos_repository/videos_repository.dart'
    show
        LatestVideoRevision,
        LatestVideoRevisionAbsent,
        LatestVideoRevisionFound,
        LatestVideoRevisionUnknown,
        VideosRepository;

class _MockVideosRepository extends Mock implements VideosRepository {}

const _owner =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

VideoEvent _video({int? eventKind}) => VideoEvent(
  id: 'opened-id',
  pubkey: _owner,
  createdAt: 1700000000,
  content: '',
  timestamp: DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000),
  vineId: 'my-video',
  addressableDTag: 'my-video',
  eventKind: eventKind,
);

void main() {
  group(newestVideoRevision, () {
    late _MockVideosRepository repository;

    setUp(() {
      repository = _MockVideosRepository();
    });

    test(
      'does not use a display-only vine ID to look up another video',
      () async {
        final opened = VideoEvent.fromNostrEvent(
          Event(
            _owner,
            34236,
            [
              ['vine_id', 'my-video'],
              ['url', 'https://example.com/original.mp4'],
            ],
            'Addressless video',
            createdAt: 1700000000,
          ),
        );
        final different = Event(
          _owner,
          34236,
          [
            ['d', 'my-video'],
            ['url', 'https://example.com/different.mp4'],
          ],
          'Different video',
          createdAt: 1700000001,
        );
        expect(opened.addressableId, isNull);
        expect(opened.stableId, 'my-video');
        when(
          () => repository.fetchLatestVideoRevision(any()),
        ).thenAnswer((_) async => LatestVideoRevisionFound(different));

        expect(
          await newestVideoRevision(
            repository.fetchLatestVideoRevision,
            opened,
            logName: 'test',
          ),
          isNull,
        );
        verifyNever(() => repository.fetchLatestVideoRevision(any()));
      },
    );

    test('asks for the address of the video', () async {
      when(
        () => repository.fetchLatestVideoRevision(any()),
      ).thenAnswer((_) async => const LatestVideoRevisionAbsent());

      await newestVideoRevision(
        repository.fetchLatestVideoRevision,
        _video(eventKind: 34235),
        logName: 'test',
      );

      verify(
        () => repository.fetchLatestVideoRevision('34235:$_owner:my-video'),
      ).called(1);
    });

    test('refuses an opened event with conflicting d tags', () async {
      final opened = VideoEvent.fromNostrEvent(
        Event(
          _owner,
          34236,
          [
            ['d', 'other-video'],
            ['d', 'my-video'],
            ['url', 'https://example.com/original.mp4'],
          ],
          'Ambiguous video',
          createdAt: 1700000000,
        ),
      );
      final different = Event(
        _owner,
        34236,
        [
          ['d', 'my-video'],
        ],
        'Different video',
        createdAt: 1700000001,
      );
      when(
        () => repository.fetchLatestVideoRevision(any()),
      ).thenAnswer((_) async => LatestVideoRevisionFound(different));

      expect(
        await newestVideoRevision(
          repository.fetchLatestVideoRevision,
          opened,
          logName: 'test',
        ),
        isNull,
      );
      verifyNever(() => repository.fetchLatestVideoRevision(any()));
    });

    test('refuses a relay revision with conflicting d tags', () async {
      final ambiguous = Event(
        _owner,
        34236,
        [
          ['d', 'my-video'],
          ['d', 'other-video'],
        ],
        'Ambiguous relay revision',
        createdAt: 1700000001,
      );
      when(
        () => repository.fetchLatestVideoRevision(any()),
      ).thenAnswer((_) async => LatestVideoRevisionFound(ambiguous));

      expect(
        await newestVideoRevision(
          repository.fetchLatestVideoRevision,
          _video(),
          logName: 'test',
        ),
        isNull,
      );
    });

    test('treats a video with no kind as a short video', () async {
      when(
        () => repository.fetchLatestVideoRevision(any()),
      ).thenAnswer((_) async => const LatestVideoRevisionAbsent());

      await newestVideoRevision(
        repository.fetchLatestVideoRevision,
        _video(),
        logName: 'test',
      );

      verify(
        () => repository.fetchLatestVideoRevision('34236:$_owner:my-video'),
      ).called(1);
    });

    test('returns the newest revision the relays hold', () async {
      final newest = Event(_owner, 34236, [
        ['d', 'my-video'],
      ], 'newest');
      when(
        () => repository.fetchLatestVideoRevision(any()),
      ).thenAnswer((_) async => LatestVideoRevisionFound(newest));

      final result = await newestVideoRevision(
        repository.fetchLatestVideoRevision,
        _video(),
        logName: 'test',
      );

      expect(result, same(newest));
    });

    test('refuses a relay revision older than the opened event', () async {
      final older = Event(
        _owner,
        34236,
        [
          ['d', 'my-video'],
        ],
        'older relay revision',
        createdAt: 1700000000,
      );
      when(
        () => repository.fetchLatestVideoRevision(any()),
      ).thenAnswer((_) async => LatestVideoRevisionFound(older));

      final opened = _video().copyWith(eventCreatedAt: 1700000001);
      final result = await newestVideoRevision(
        repository.fetchLatestVideoRevision,
        opened,
        logName: 'test',
      );

      expect(result, isNull);
    });

    group('when the relay revision has the opened timestamp', () {
      final sameSecond = Event(
        _owner,
        34236,
        [
          ['d', 'my-video'],
        ],
        'same-second relay revision',
        createdAt: 1700000000,
      );

      setUp(() {
        when(
          () => repository.fetchLatestVideoRevision(any()),
        ).thenAnswer((_) async => LatestVideoRevisionFound(sameSecond));
      });

      Future<Event?> readFrom(String openedId) => newestVideoRevision(
        repository.fetchLatestVideoRevision,
        _video().copyWith(id: openedId, eventCreatedAt: 1700000000),
        logName: 'test',
      );

      test('returns it when it is the opened event', () async {
        expect(await readFrom(sameSecond.id), same(sameSecond));
      });

      test('returns it when its ID wins the NIP-01 tie', () async {
        expect(await readFrom('f' * 64), same(sameSecond));
      });

      test('refuses it when the opened event wins the tie', () async {
        expect(await readFrom('0' * 64), isNull);
      });
    });

    test('returns null when there is no repository to ask', () async {
      final result = await newestVideoRevision(
        null,
        _video(),
        logName: 'test',
      );

      expect(result, isNull);
    });

    test(
      'returns null when no relay answered in full and no copy is held',
      () async {
        when(
          () => repository.fetchLatestVideoRevision(any()),
        ).thenAnswer((_) async => const LatestVideoRevisionUnknown());

        final result = await newestVideoRevision(
          repository.fetchLatestVideoRevision,
          _video(),
          logName: 'test',
        );

        expect(result, isNull);
      },
    );

    test('returns null when no signed revision is held', () async {
      when(
        () => repository.fetchLatestVideoRevision(any()),
      ).thenAnswer((_) async => const LatestVideoRevisionAbsent());

      final result = await newestVideoRevision(
        repository.fetchLatestVideoRevision,
        _video(),
        logName: 'test',
      );

      expect(result, isNull);
    });

    group('with the signed copy of the opened video in hand', () {
      late String privateKey;
      late Event held;
      late VideoEvent opened;

      Event signedAt(String dTag, {int createdAt = 1700000000}) => Event(
        getPublicKey(privateKey),
        34236,
        [
          ['d', dTag],
          ['url', 'https://example.com/held.mp4'],
        ],
        'held copy',
        createdAt: createdAt,
      )..sign(privateKey);

      VideoEvent openedFrom(Event event) => VideoEvent.fromNostrEvent(event);

      Future<Event?> read(
        VideoEvent video, {
        required Event? Function(String eventId) cachedEvent,
      }) => newestVideoRevision(
        repository.fetchLatestVideoRevision,
        video,
        logName: 'test',
        cachedEvent: cachedEvent,
      );

      void stubRevision(LatestVideoRevision revision) {
        when(
          () => repository.fetchLatestVideoRevision(any()),
        ).thenAnswer((_) async => revision);
      }

      setUp(() {
        privateKey = generatePrivateKey();
        held = signedAt('my-video');
        opened = openedFrom(held);
      });

      test('uses it when no relay answered in full', () async {
        stubRevision(const LatestVideoRevisionUnknown());
        final asked = <String>[];

        final result = await read(
          opened,
          cachedEvent: (id) {
            asked.add(id);
            return held;
          },
        );

        expect(result, same(held));
        expect(asked, [held.id]);
      });

      test('uses it when the revision found predates it', () async {
        stubRevision(
          LatestVideoRevisionFound(
            signedAt('my-video', createdAt: 1699999999),
          ),
        );

        expect(await read(opened, cachedEvent: (_) => held), same(held));
      });

      test('prefers a newer revision found over it', () async {
        final newer = signedAt('my-video', createdAt: 1700000001);
        stubRevision(LatestVideoRevisionFound(newer));
        var asked = false;

        final result = await read(
          opened,
          cachedEvent: (_) {
            asked = true;
            return held;
          },
        );

        expect(result, same(newer));
        expect(asked, isFalse);
      });

      test('does not resurrect a video no revision is held for', () async {
        stubRevision(const LatestVideoRevisionAbsent());

        expect(await read(opened, cachedEvent: (_) => held), isNull);
      });

      group('refuses it when no relay answered in full and it', () {
        setUp(() => stubRevision(const LatestVideoRevisionUnknown()));

        test('is not held', () async {
          expect(await read(opened, cachedEvent: (_) => null), isNull);
        });

        test('is another event', () async {
          final other = signedAt('my-video', createdAt: 1700000005);

          expect(await read(opened, cachedEvent: (_) => other), isNull);
        });

        // The signature covers the id, so only the id check sees a body
        // changed after signing.
        test('has content its id does not cover', () async {
          final altered = Event.fromJson({
            ...held.toJson(),
            'content': 'changed after signing',
          });
          expect(altered.id, held.id);

          expect(await read(opened, cachedEvent: (_) => altered), isNull);
        });

        test('has a signature by another key', () async {
          final forged = Event(
            held.pubkey,
            held.kind,
            held.tags,
            held.content,
            createdAt: held.createdAt,
          )..sign(generatePrivateKey());

          expect(
            await read(
              opened.copyWith(id: forged.id),
              cachedEvent: (_) => forged,
            ),
            isNull,
          );
        });

        test('is at another address', () async {
          final elsewhere = signedAt('other-video');

          expect(
            await read(
              opened.copyWith(id: elsewhere.id),
              cachedEvent: (_) => elsewhere,
            ),
            isNull,
          );
        });

        test('has conflicting d tags', () async {
          final ambiguous = Event(
            getPublicKey(privateKey),
            34236,
            [
              ['d', 'my-video'],
              ['d', 'other-video'],
            ],
            'ambiguous held copy',
            createdAt: 1700000000,
          )..sign(privateKey);

          expect(
            await read(
              opened.copyWith(id: ambiguous.id),
              cachedEvent: (_) => ambiguous,
            ),
            isNull,
          );
        });
      });
    });
  });
}
