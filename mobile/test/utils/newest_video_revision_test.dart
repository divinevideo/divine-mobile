// ABOUTME: Pins the read a video republish rebuilds from: the address, the
// ABOUTME: opened revision as its floor, and none when unanswered or empty.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' show VideoEvent;
import 'package:nostr_sdk/event.dart';
import 'package:openvine/utils/newest_video_revision.dart';
import 'package:videos_repository/videos_repository.dart'
    show
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
          await newestVideoRevision(repository, opened, logName: 'test'),
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
        repository,
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
        await newestVideoRevision(repository, opened, logName: 'test'),
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
        await newestVideoRevision(repository, _video(), logName: 'test'),
        isNull,
      );
    });

    test('treats a video with no kind as a short video', () async {
      when(
        () => repository.fetchLatestVideoRevision(any()),
      ).thenAnswer((_) async => const LatestVideoRevisionAbsent());

      await newestVideoRevision(repository, _video(), logName: 'test');

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
        repository,
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
        repository,
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
        repository,
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

    for (final (name, revision) in [
      ('no relay answered in full', const LatestVideoRevisionUnknown()),
      (
        'the relays return no signed revision',
        const LatestVideoRevisionAbsent(),
      ),
    ]) {
      test('returns null when $name', () async {
        when(
          () => repository.fetchLatestVideoRevision(any()),
        ).thenAnswer((_) async => revision);

        final result = await newestVideoRevision(
          repository,
          _video(),
          logName: 'test',
        );

        expect(result, isNull);
      });
    }
  });
}
