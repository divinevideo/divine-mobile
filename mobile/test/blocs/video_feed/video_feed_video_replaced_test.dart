// ABOUTME: A video republished from this device replaces the older revision
// ABOUTME: Home holds, so the tile and a second edit both see the new one (#11250).

import 'dart:async';

import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_feed/home_feed_cache.dart';
import 'package:openvine/blocs/video_feed/video_feed_bloc.dart';
import 'package:videos_repository/videos_repository.dart';

import '../../helpers/feed_bloc_test_helper.dart';

class _MockVideosRepository extends Mock implements VideosRepository {}

class _MockFollowRepository extends Mock implements FollowRepository {}

class _MockCuratedListRepository extends Mock
    implements CuratedListRepository {}

class _MemoryHomeFeedCache extends HomeFeedCache {
  List<VideoEvent>? saved;

  @override
  Future<List<VideoEvent>?> readVideos({
    required String? pubkey,
    required String mode,
  }) async => null;

  @override
  Future<void> writeVideos({
    required String? pubkey,
    required String mode,
    required List<VideoEvent> videos,
  }) async => saved = videos;

  @override
  Future<void> clearVideos({
    required String? pubkey,
    required String mode,
  }) async => saved = null;
}

/// Revision [id] of the video at `34236:<owner>:<dTag>`.
VideoEvent _revision(
  String id, {
  String dTag = 'clip',
  int createdAt = 1700000000,
  String title = 'Title',
}) => VideoEvent(
  id: id * 64,
  pubkey: 'a' * 64,
  createdAt: createdAt,
  eventCreatedAt: createdAt,
  content: '',
  title: title,
  timestamp: DateTime.utc(2026),
  videoUrl: 'https://example.com/$dTag.mp4',
  vineId: dTag,
  addressableDTag: dTag,
  eventKind: 34236,
);

void main() {
  setUpAll(() {
    registerFallbackValue(_revision('0'));
    registerFallbackValue(<VideoEvent>[]);
  });
  group(VideoFeedVideoReplaced, () {
    late _MockVideosRepository videos;
    late StreamController<VideoEvent> replacements;
    late _MemoryHomeFeedCache cache;

    setUp(() {
      videos = _MockVideosRepository();
      replacements = StreamController<VideoEvent>.broadcast();
      cache = _MemoryHomeFeedCache();
      when(() => videos.removedVideoIds)
          .thenAnswer((_) => const Stream.empty());
      when(() => videos.replacedVideos).thenAnswer((_) => replacements.stream);
      when(() => videos.isVideoKnownDeleted(any())).thenReturn(false);
      when(() => videos.applyContentPreferences(any())).thenAnswer(
        (call) => call.positionalArguments.single as List<VideoEvent>,
      );
    });

    tearDown(() => replacements.close());

    VideoFeedBloc createBloc() => VideoFeedBloc(
      videosRepository: videos,
      replacedVideosStream: videos.replacedVideos,
      followRepository: _MockFollowRepository(),
      curatedListRepository: _MockCuratedListRepository(),
      homeFeedCache: cache,
    );

    feedBlocTest(
      'shows the newer revision in place of the one the feed holds',
      build: createBloc,
      seed: () => VideoFeedBlocState(
        status: VideoFeedStatus.success,
        videos: [
          _revision('1'),
          _revision('2', dTag: 'other'),
        ],
        videoListSources: {
          '1' * 64: {'list'},
        },
        listOnlyVideoIds: {'1' * 64},
      ),
      act: (_) => replacements.add(
        _revision('3', createdAt: 1700000500, title: 'Edited'),
      ),
      wait: Duration.zero,
      expect: () => [
        isA<VideoFeedBlocState>()
            .having(
              (state) => state.videos.map((v) => (v.id, v.title)).toList(),
              'videos',
              [('3' * 64, 'Edited'), ('2' * 64, 'Title')],
            )
            .having(
              (state) => state.videoListSources,
              'list provenance',
              {
                '3' * 64: {'list'},
              },
            )
            .having(
              (state) => state.listOnlyVideoIds,
              'list-only revisions',
              {'3' * 64},
            ),
      ],
    );

    feedBlocTest(
      'keeps the revision it holds when an older one is announced',
      build: createBloc,
      seed: () => VideoFeedBlocState(
        status: VideoFeedStatus.success,
        videos: [_revision('3', createdAt: 1700000500)],
      ),
      act: (_) => replacements.add(_revision('1')),
      wait: Duration.zero,
      expect: () => <VideoFeedBlocState>[],
    );

    feedBlocTest(
      'ignores a video the feed does not hold',
      build: createBloc,
      seed: () => VideoFeedBlocState(
        status: VideoFeedStatus.success,
        videos: [_revision('1')],
      ),
      act: (_) => replacements.add(
        _revision('4', dTag: 'elsewhere', createdAt: 1700000500),
      ),
      wait: Duration.zero,
      expect: () => <VideoFeedBlocState>[],
    );

    feedBlocTest(
      'removes a video whose edited revision is hidden by content preferences',
      build: createBloc,
      seed: () => VideoFeedBlocState(
        status: VideoFeedStatus.success,
        videos: [
          _revision('1'),
          _revision('2', dTag: 'other'),
        ],
      ),
      act: (_) {
        final edited = _revision('3', createdAt: 1700000500);
        when(() => videos.applyContentPreferences([edited])).thenReturn([]);
        replacements.add(edited);
      },
      wait: Duration.zero,
      expect: () => [
        isA<VideoFeedBlocState>().having(
          (state) => state.videos.map((video) => video.id),
          'visible revisions',
          ['2' * 64],
        ),
      ],
    );

    test('saves the updated window so a cold start shows it too', () async {
      final bloc = createBloc()
        ..emit(
          VideoFeedBlocState(
            status: VideoFeedStatus.success,
            // The resume window starts after the playing video.
            videos: [
              _revision('5', dTag: 'playing'),
              _revision('1'),
            ],
          ),
        );
      addTearDown(bloc.close);

      replacements.add(_revision('3', createdAt: 1700000500));
      await pumpEventQueue();

      expect(cache.saved?.map((video) => video.id).toList(), ['3' * 64]);
    });
  });
}
