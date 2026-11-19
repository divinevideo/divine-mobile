// ABOUTME: Pins the read a video republish rebuilds from: the address it asks
// ABOUTME: for, and that an unanswered or empty read gives no revision.

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
  eventKind: eventKind,
);

void main() {
  group(newestVideoRevision, () {
    late _MockVideosRepository repository;

    setUp(() {
      repository = _MockVideosRepository();
    });

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
      ('no relay holds a revision', const LatestVideoRevisionAbsent()),
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
