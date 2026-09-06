// ABOUTME: Tests for FullscreenFeedBloc - fullscreen video playback state
// ABOUTME: Tests stream subscription, index changes, pagination, cache resolution,
// ABOUTME: and background caching

import 'dart:async';
import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:feed_tuning_repository/feed_tuning_repository.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_cache/media_cache.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/fullscreen_feed/fullscreen_feed_bloc.dart';
import 'package:openvine/services/dead_media_feed_guard.dart';

class MockFileInfo extends Mock implements FileInfo {}

class MockMediaCacheManager extends Mock implements MediaCacheManager {}

class MockBlossomAuthService extends Mock implements BlossomAuthService {}

class MockFile extends Mock implements File {}

class MockFeedTuningRepository extends Mock implements FeedTuningRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(
      VideoEvent(
        id: 'fallback',
        pubkey: '0' * 64,
        createdAt: 0,
        content: '',
        timestamp: DateTime(2020),
      ),
    );
    registerFallbackValue(FeedTuningDirection.more);
  });

  group('FullscreenFeedBloc', () {
    late StreamController<List<VideoEvent>> videosController;
    late StreamController<bool> hasMoreController;
    late MockMediaCacheManager mockMediaCache;
    late MockBlossomAuthService mockBlossomAuth;

    setUp(() {
      videosController = StreamController<List<VideoEvent>>.broadcast();
      hasMoreController = StreamController<bool>.broadcast();
      mockMediaCache = MockMediaCacheManager();
      mockBlossomAuth = MockBlossomAuthService();

      // Default: no cached files
      when(() => mockMediaCache.getCachedFileSync(any())).thenReturn(null);
    });

    tearDown(() {
      videosController.close();
      hasMoreController.close();
    });

    VideoEvent createTestVideo(
      String id, {
      String? sha256,
      String? videoUrl,
      String? pubkey,
      Map<String, String> rawTags = const {},
    }) {
      final now = DateTime.now();
      return VideoEvent(
        id: id,
        pubkey: pubkey ?? '0' * 64,
        createdAt: now.millisecondsSinceEpoch ~/ 1000,
        content: '',
        timestamp: now,
        title: 'Test Video $id',
        videoUrl: videoUrl ?? 'https://example.com/video_$id.mp4',
        thumbnailUrl: 'https://example.com/thumb_$id.jpg',
        sha256: sha256,
        rawTags: rawTags,
      );
    }

    FullscreenFeedBloc createBloc({
      int initialIndex = 0,
      String? initialVideoId,
      String? initialStableId,
      void Function()? onLoadMore,
      Stream<bool>? hasMoreStream,
      MediaCacheManager? mediaCache,
      BlossomAuthService? blossomAuthService,
      OnRemoveVideo? onRemoveVideo,
      OnVideoConfirmedUnavailable? onVideoConfirmedUnavailable,
      ConfirmVideoUnavailable? confirmVideoUnavailable,
      VideoHideFilter? hideFilter,
      UnavailableVideoFilter? unavailableFilter,
      FeedTuningRepository? feedTuningRepository,
    }) => FullscreenFeedBloc(
      videosStream: videosController.stream,
      initialIndex: initialIndex,
      initialVideoId: initialVideoId,
      initialStableId: initialStableId,
      onLoadMore: onLoadMore,
      hasMoreStream: hasMoreStream,
      mediaCache: mediaCache ?? mockMediaCache,
      blossomAuthService: blossomAuthService,
      onRemoveVideo: onRemoveVideo,
      onVideoConfirmedUnavailable: onVideoConfirmedUnavailable,
      confirmVideoUnavailable: confirmVideoUnavailable,
      hideFilter: hideFilter,
      unavailableFilter: unavailableFilter,
      feedTuningRepository: feedTuningRepository,
    );

    ConfirmVideoUnavailable confirmerWith(
      FeedUnavailability result, {
      void Function(String videoId, String? videoUrl, String? explicitSha256)?
      onCall,
    }) => ({required videoId, required videoUrl, explicitSha256}) async {
      onCall?.call(videoId, videoUrl, explicitSha256);
      return result;
    };

    ConfirmVideoUnavailable confirmerReturning(
      bool result, {
      void Function(String videoId, String? videoUrl, String? explicitSha256)?
      onCall,
    }) => confirmerWith(
      result ? FeedUnavailability.persistent : FeedUnavailability.none,
      onCall: onCall,
    );

    test('initial state has correct values', () {
      final bloc = createBloc(initialIndex: 2);
      expect(bloc.state.status, FullscreenFeedStatus.initial);
      expect(bloc.state.videos, isEmpty);
      expect(bloc.state.currentIndex, 2);
      expect(bloc.state.isLoadingMore, isFalse);
      expect(bloc.state.canLoadMore, isFalse);
      bloc.close();
    });

    test('load more stays unavailable until hasMoreStream emits true', () {
      final bloc = createBloc(
        onLoadMore: () {},
        hasMoreStream: hasMoreController.stream,
      );

      expect(bloc.state.canLoadMore, isFalse);
      bloc.close();
    });

    group('FullscreenFeedState', () {
      test('currentVideo returns video at currentIndex', () {
        final video1 = createTestVideo('video1');
        final video2 = createTestVideo('video2');
        final state = FullscreenFeedState(
          status: FullscreenFeedStatus.ready,
          videos: [video1, video2],
          currentIndex: 1,
        );

        expect(state.currentVideo, video2);
      });

      test('currentVideo returns null when index out of range', () {
        final video = createTestVideo('video1');
        final state = FullscreenFeedState(
          status: FullscreenFeedStatus.ready,
          videos: [video],
          currentIndex: 5,
        );

        expect(state.currentVideo, isNull);
      });

      test('currentVideo returns null when videos empty', () {
        final state = FullscreenFeedState(status: FullscreenFeedStatus.ready);

        expect(state.currentVideo, isNull);
      });

      test('hasVideos returns true when videos not empty', () {
        final video = createTestVideo('video1');
        final state = FullscreenFeedState(
          status: FullscreenFeedStatus.ready,
          videos: [video],
        );

        expect(state.hasVideos, isTrue);
      });

      test('hasVideos returns false when videos empty', () {
        final state = FullscreenFeedState(status: FullscreenFeedStatus.ready);

        expect(state.hasVideos, isFalse);
      });

      test('copyWith creates copy with updated values', () {
        final state = FullscreenFeedState();
        final video = createTestVideo('video1');

        final updated = state.copyWith(
          status: FullscreenFeedStatus.ready,
          videos: [video],
          currentIndex: 5,
          isLoadingMore: true,
          initialTargetResolved: true,
          userChangedIndex: true,
        );

        expect(updated.status, FullscreenFeedStatus.ready);
        expect(updated.videos, [video]);
        expect(updated.currentIndex, 5);
        expect(updated.isLoadingMore, isTrue);
        expect(updated.initialTargetResolved, isTrue);
        expect(updated.userChangedIndex, isTrue);
      });

      test('copyWith preserves values when not specified', () {
        final video = createTestVideo('video1');
        final state = FullscreenFeedState(
          status: FullscreenFeedStatus.ready,
          videos: [video],
          currentIndex: 3,
          isLoadingMore: true,
        );

        final updated = state.copyWith();

        expect(updated.status, FullscreenFeedStatus.ready);
        expect(updated.videos, [video]);
        expect(updated.currentIndex, 3);
        expect(updated.isLoadingMore, isTrue);
      });

      test('props contains all fields for Equatable', () {
        final video = createTestVideo('video1');
        final state = FullscreenFeedState(
          status: FullscreenFeedStatus.ready,
          videos: [video],
          currentIndex: 2,
          isLoadingMore: true,
        );

        expect(state.props, [
          FullscreenFeedStatus.ready,
          [video],
          [
            '${video.id}|${video.stableId}|${video.videoUrl ?? ''}|${video.thumbnailUrl ?? ''}|${video.originalLoops ?? ''}|${video.rawTags['views'] ?? ''}',
          ],
          2,
          true,
          false,
          <String>{},
          null,
          false,
          false,
          null,
        ]);
      });

      group('feed tuning', () {
        late MockFeedTuningRepository tuningRepository;

        setUp(() {
          tuningRepository = MockFeedTuningRepository();
          when(
            () => tuningRepository.tune(
              video: any(named: 'video'),
              direction: any(named: 'direction'),
            ),
          ).thenAnswer((_) async => 'published-id');
          when(() => tuningRepository.undo(any())).thenAnswer((_) async {});
        });

        blocTest<FullscreenFeedBloc, FullscreenFeedState>(
          'publishes the swiped video and records the action without removal',
          build: () => createBloc(feedTuningRepository: tuningRepository),
          act: (bloc) async {
            bloc.add(const FullscreenFeedStarted());
            await Future<void>.delayed(const Duration(milliseconds: 50));
            videosController.add([
              createTestVideo('video1'),
              createTestVideo('video2'),
            ]);
            await Future<void>.delayed(const Duration(milliseconds: 50));
            bloc.add(
              const FullscreenFeedTuningSwipeCommitted(
                videoId: 'video1',
                direction: FeedTuningDirection.less,
              ),
            );
          },
          wait: const Duration(milliseconds: 100),
          verify: (bloc) {
            final captured = verify(
              () => tuningRepository.tune(
                video: captureAny(named: 'video'),
                direction: FeedTuningDirection.less,
              ),
            ).captured;
            expect((captured.single as VideoEvent).id, 'video1');
            expect(bloc.state.lastTuningAction?.videoId, 'video1');
            expect(
              bloc.state.lastTuningAction?.direction,
              FeedTuningDirection.less,
            );
            expect(
              bloc.state.lastTuningAction?.publishedEventId,
              'published-id',
            );
            expect(bloc.state.lastTuningAction?.sequence, 1);
            expect(bloc.state.removedVideoIds, isEmpty);
          },
        );

        blocTest<FullscreenFeedBloc, FullscreenFeedState>(
          'records identical repeated swipes as distinct actions',
          build: () => createBloc(feedTuningRepository: tuningRepository),
          act: (bloc) async {
            bloc.add(const FullscreenFeedStarted());
            await Future<void>.delayed(const Duration(milliseconds: 50));
            videosController.add([createTestVideo('video1')]);
            await Future<void>.delayed(const Duration(milliseconds: 50));
            bloc
              ..add(
                const FullscreenFeedTuningSwipeCommitted(
                  videoId: 'video1',
                  direction: FeedTuningDirection.more,
                ),
              )
              ..add(
                const FullscreenFeedTuningSwipeCommitted(
                  videoId: 'video1',
                  direction: FeedTuningDirection.more,
                ),
              );
          },
          wait: const Duration(milliseconds: 150),
          verify: (bloc) {
            verify(
              () => tuningRepository.tune(
                video: any(named: 'video'),
                direction: FeedTuningDirection.more,
              ),
            ).called(2);
            expect(bloc.state.lastTuningAction?.sequence, 2);
          },
        );

        blocTest<FullscreenFeedBloc, FullscreenFeedState>(
          'is a no-op when the swiped video is not in the feed',
          build: () => createBloc(feedTuningRepository: tuningRepository),
          act: (bloc) async {
            bloc.add(const FullscreenFeedStarted());
            await Future<void>.delayed(const Duration(milliseconds: 50));
            videosController.add([createTestVideo('video1')]);
            await Future<void>.delayed(const Duration(milliseconds: 50));
            bloc.add(
              const FullscreenFeedTuningSwipeCommitted(
                videoId: 'missing',
                direction: FeedTuningDirection.more,
              ),
            );
          },
          wait: const Duration(milliseconds: 100),
          verify: (bloc) {
            verifyNever(
              () => tuningRepository.tune(
                video: any(named: 'video'),
                direction: any(named: 'direction'),
              ),
            );
            expect(bloc.state.lastTuningAction, isNull);
          },
        );

        blocTest<FullscreenFeedBloc, FullscreenFeedState>(
          'retracts the signal via the repository on undo',
          build: () => createBloc(feedTuningRepository: tuningRepository),
          act: (bloc) async {
            bloc.add(
              const FullscreenFeedTuningUndoRequested('tuning-event-id'),
            );
            await Future<void>.delayed(const Duration(milliseconds: 50));
          },
          wait: const Duration(milliseconds: 100),
          verify: (_) {
            verify(() => tuningRepository.undo('tuning-event-id')).called(1);
          },
        );
      });

      test('videoUpdateSignature changes when loop metadata changes', () {
        final now = DateTime.now();
        final baseVideo = VideoEvent(
          id: 'video1',
          pubkey: '0' * 64,
          createdAt: now.millisecondsSinceEpoch ~/ 1000,
          content: '',
          timestamp: now,
          videoUrl: 'https://example.com/video1.mp4',
          rawTags: const {'views': '0'},
        );
        final updatedVideo = baseVideo.copyWith(rawTags: const {'views': '42'});

        final baseState = FullscreenFeedState(
          status: FullscreenFeedStatus.ready,
          videos: [baseVideo],
        );
        final updatedState = FullscreenFeedState(
          status: FullscreenFeedStatus.ready,
          videos: [updatedVideo],
        );

        expect(
          baseState.videoUpdateSignature,
          isNot(updatedState.videoUpdateSignature),
        );
        expect(baseState, isNot(updatedState));
      });

      test('videoUpdateSignature is memoized and immutable', () {
        final state = FullscreenFeedState(
          videos: [createTestVideo('video1')],
        );
        final signature = state.videoUpdateSignature;

        expect(identical(signature, state.videoUpdateSignature), isTrue);
        expect(() => signature.add('changed'), throwsUnsupportedError);
      });
    });

    group('FullscreenFeedStarted', () {
      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'updates canLoadMore from hasMoreStream',
        build: () => createBloc(
          onLoadMore: () {},
          hasMoreStream: hasMoreController.stream,
        ),
        act: (bloc) async {
          bloc.add(const FullscreenFeedStarted());
          await Future<void>.delayed(const Duration(milliseconds: 50));
          hasMoreController.add(true);
          await Future<void>.delayed(const Duration(milliseconds: 50));
          hasMoreController.add(false);
        },
        wait: const Duration(milliseconds: 200),
        expect: () => [
          isA<FullscreenFeedState>().having(
            (s) => s.canLoadMore,
            'canLoadMore',
            true,
          ),
          isA<FullscreenFeedState>().having(
            (s) => s.canLoadMore,
            'canLoadMore',
            false,
          ),
        ],
      );

      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'subscribes to videos stream and emits ready when videos arrive',
        build: createBloc,
        act: (bloc) async {
          bloc.add(const FullscreenFeedStarted());
          await Future<void>.delayed(const Duration(milliseconds: 50));
          videosController.add([createTestVideo('video1')]);
        },
        wait: const Duration(milliseconds: 100),
        expect: () => [
          isA<FullscreenFeedState>()
              .having((s) => s.status, 'status', FullscreenFeedStatus.ready)
              .having((s) => s.videos.length, 'videos count', 1)
              .having((s) => s.videos.first.id, 'first video id', 'video1'),
        ],
      );

      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'emits multiple times when stream emits multiple values',
        build: createBloc,
        act: (bloc) async {
          bloc.add(const FullscreenFeedStarted());
          await Future<void>.delayed(const Duration(milliseconds: 50));
          videosController.add([createTestVideo('video1')]);
          await Future<void>.delayed(const Duration(milliseconds: 50));
          videosController.add([
            createTestVideo('video1'),
            createTestVideo('video2'),
          ]);
        },
        wait: const Duration(milliseconds: 200),
        expect: () => [
          isA<FullscreenFeedState>().having(
            (s) => s.videos.length,
            'videos count',
            1,
          ),
          isA<FullscreenFeedState>().having(
            (s) => s.videos.length,
            'videos count',
            2,
          ),
        ],
      );

      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'preserves current video when stream prepends reordered results',
        build: () => createBloc(initialIndex: 1),
        act: (bloc) async {
          final first = createTestVideo('video1');
          final second = createTestVideo('video2');
          final prepended = createTestVideo('video3');

          bloc.add(const FullscreenFeedStarted());
          await Future<void>.delayed(const Duration(milliseconds: 50));
          videosController.add([first, second]);
          await Future<void>.delayed(const Duration(milliseconds: 50));
          videosController.add([prepended, first, second]);
        },
        wait: const Duration(milliseconds: 200),
        expect: () => [
          isA<FullscreenFeedState>()
              .having((s) => s.currentIndex, 'currentIndex', 1)
              .having((s) => s.currentVideo?.id, 'currentVideo', 'video2'),
          isA<FullscreenFeedState>()
              .having((s) => s.currentIndex, 'currentIndex', 2)
              .having((s) => s.currentVideo?.id, 'currentVideo', 'video2'),
        ],
      );

      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'preserves initial index through empty-first source emissions',
        build: () => createBloc(initialIndex: 4),
        act: (bloc) async {
          bloc.add(const FullscreenFeedStarted());
          await Future<void>.delayed(const Duration(milliseconds: 50));
          videosController.add(const []);
          await Future<void>.delayed(const Duration(milliseconds: 50));
          videosController.add([
            createTestVideo('video0'),
            createTestVideo('video1'),
            createTestVideo('video2'),
            createTestVideo('video3'),
            createTestVideo('video4'),
          ]);
        },
        wait: const Duration(milliseconds: 200),
        expect: () => [
          isA<FullscreenFeedState>()
              .having((s) => s.videos, 'videos', isEmpty)
              .having((s) => s.currentIndex, 'currentIndex', 4),
          isA<FullscreenFeedState>()
              .having((s) => s.videos.length, 'videos count', 5)
              .having((s) => s.currentIndex, 'currentIndex', 4)
              .having((s) => s.currentVideo?.id, 'currentVideo', 'video4'),
        ],
      );

      // #6949. Unliking the only video in the Liked feed makes
      // ProfileLikedVideosBloc re-emit an empty list into the still-open
      // fullscreen route. Reporting that as `ready` left the screen on the
      // loading placeholder forever — no video, no action buttons, no
      // explanation — because the UI renders that placeholder for
      // `status == initial || !hasVideos`.
      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'emits empty when the source drains after having supplied videos',
        build: createBloc,
        act: (bloc) async {
          bloc.add(const FullscreenFeedStarted());
          await Future<void>.delayed(const Duration(milliseconds: 50));
          videosController.add([createTestVideo('video1')]);
          await Future<void>.delayed(const Duration(milliseconds: 50));
          videosController.add(const []);
        },
        wait: const Duration(milliseconds: 200),
        expect: () => [
          isA<FullscreenFeedState>()
              .having((s) => s.status, 'status', FullscreenFeedStatus.ready)
              .having((s) => s.videos.length, 'videos count', 1),
          isA<FullscreenFeedState>()
              .having((s) => s.status, 'status', FullscreenFeedStatus.empty)
              .having((s) => s.videos, 'videos', isEmpty),
        ],
      );

      // The status has to latch: a second empty emit must not fall back to
      // `ready`, which would put the screen back on the spinner.
      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'stays empty across repeated empty emissions',
        build: createBloc,
        act: (bloc) async {
          bloc.add(const FullscreenFeedStarted());
          await Future<void>.delayed(const Duration(milliseconds: 50));
          videosController.add([createTestVideo('video1')]);
          await Future<void>.delayed(const Duration(milliseconds: 50));
          videosController.add(const []);
          await Future<void>.delayed(const Duration(milliseconds: 50));
          videosController.add(const []);
        },
        wait: const Duration(milliseconds: 250),
        verify: (bloc) {
          expect(bloc.state.status, FullscreenFeedStatus.empty);
          expect(bloc.state.videos, isEmpty);
        },
      );

      // Draining is not a tombstone: pagination, a re-like, or an unblock can
      // refill the source, and the feed has to come back.
      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'returns to ready when the source refills after draining',
        build: createBloc,
        act: (bloc) async {
          bloc.add(const FullscreenFeedStarted());
          await Future<void>.delayed(const Duration(milliseconds: 50));
          videosController.add([createTestVideo('video1')]);
          await Future<void>.delayed(const Duration(milliseconds: 50));
          videosController.add(const []);
          await Future<void>.delayed(const Duration(milliseconds: 50));
          videosController.add([createTestVideo('video2')]);
        },
        wait: const Duration(milliseconds: 250),
        verify: (bloc) {
          expect(bloc.state.status, FullscreenFeedStatus.ready);
          expect(bloc.state.videos.single.id, 'video2');
        },
      );

      // The mirror image of the case above, and the reason `empty` cannot
      // simply be "videos.isEmpty": a source that has not warmed up yet
      // emits [] first, and that must stay a loading state. Pinned
      // alongside 'preserves initial index through empty-first source
      // emissions', which covers the index half of the same contract.
      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'an empty first emission is loading, not empty',
        build: createBloc,
        act: (bloc) async {
          bloc.add(const FullscreenFeedStarted());
          await Future<void>.delayed(const Duration(milliseconds: 50));
          videosController.add(const []);
        },
        wait: const Duration(milliseconds: 150),
        verify: (bloc) {
          expect(bloc.state.status, isNot(FullscreenFeedStatus.empty));
          expect(bloc.state.videos, isEmpty);
        },
      );

      // The unavailable/block filters run at the same boundary, so a source
      // that keeps pushing videos which all get filtered out drains the feed
      // just as effectively as one that pushes an empty list.
      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'emits empty when every video in a later emission is filtered out',
        build: () =>
            createBloc(unavailableFilter: (videoId) => videoId == 'video2'),
        act: (bloc) async {
          bloc.add(const FullscreenFeedStarted());
          await Future<void>.delayed(const Duration(milliseconds: 50));
          videosController.add([createTestVideo('video1')]);
          await Future<void>.delayed(const Duration(milliseconds: 50));
          videosController.add([createTestVideo('video2')]);
        },
        wait: const Duration(milliseconds: 250),
        verify: (bloc) {
          expect(bloc.state.status, FullscreenFeedStatus.empty);
          expect(bloc.state.videos, isEmpty);
        },
      );

      // emptyAfterRemoval carries the pop signal the screen listens on, so a
      // late empty emit from the source must not overwrite it — that would
      // both lose the pop and put the screen back on the placeholder.
      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'a later empty emission does not downgrade emptyAfterRemoval',
        build: createBloc,
        seed: () => FullscreenFeedState(
          status: FullscreenFeedStatus.emptyAfterRemoval,
        ),
        act: (bloc) async {
          bloc.add(const FullscreenFeedStarted());
          await Future<void>.delayed(const Duration(milliseconds: 50));
          videosController.add(const []);
        },
        wait: const Duration(milliseconds: 200),
        verify: (bloc) {
          expect(bloc.state.status, FullscreenFeedStatus.emptyAfterRemoval);
        },
      );

      // Single-emit sources (StaticFeedRepository's `Stream.value`, the
      // hashtag snapshot's `Stream.fromFuture`) close after one event, so an
      // empty one is terminal — nothing can arrive later to clear the
      // placeholder.
      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'emits empty when an empty source stream closes without ever '
        'delivering a video',
        build: createBloc,
        act: (bloc) async {
          bloc.add(const FullscreenFeedStarted());
          await Future<void>.delayed(const Duration(milliseconds: 50));
          videosController
            ..add(const [])
            ..close();
        },
        wait: const Duration(milliseconds: 200),
        verify: (bloc) {
          expect(bloc.state.status, FullscreenFeedStatus.empty);
          expect(bloc.state.videos, isEmpty);
        },
      );

      // A closing stream that DID deliver videos must not be reported as
      // drained — the list is still on screen and playable.
      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'stays ready when a source stream closes after delivering videos',
        build: createBloc,
        act: (bloc) async {
          bloc.add(const FullscreenFeedStarted());
          await Future<void>.delayed(const Duration(milliseconds: 50));
          videosController
            ..add([createTestVideo('video1')])
            ..close();
        },
        wait: const Duration(milliseconds: 200),
        verify: (bloc) {
          expect(bloc.state.status, FullscreenFeedStatus.ready);
          expect(bloc.state.videos.single.id, 'video1');
        },
      );

      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'resolves initial video identity when source order changes',
        build: () => createBloc(
          initialIndex: 1,
          initialVideoId: 'target-video',
          initialStableId: 'stable-target-video',
        ),
        act: (bloc) async {
          final target = createTestVideo(
            'target-video',
            rawTags: const {'d': 'stable-target-video'},
          );

          bloc.add(const FullscreenFeedStarted());
          await Future<void>.delayed(const Duration(milliseconds: 50));
          videosController.add(const []);
          await Future<void>.delayed(const Duration(milliseconds: 50));
          videosController.add([
            createTestVideo('newer-video'),
            createTestVideo('another-video'),
            target,
          ]);
        },
        wait: const Duration(milliseconds: 200),
        expect: () => [
          isA<FullscreenFeedState>()
              .having((s) => s.videos, 'videos', isEmpty)
              .having((s) => s.currentIndex, 'currentIndex', 1),
          isA<FullscreenFeedState>()
              .having((s) => s.currentIndex, 'currentIndex', 2)
              .having(
                (s) => s.currentVideo?.id,
                'currentVideo',
                'target-video',
              ),
        ],
      );

      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'opens tapped grid video when repository list filters an earlier item',
        build: () =>
            createBloc(initialIndex: 2, initialVideoId: 'tapped-video'),
        act: (bloc) async {
          final tapped = createTestVideo('tapped-video');

          bloc.add(const FullscreenFeedStarted());
          await Future<void>.delayed(const Duration(milliseconds: 50));
          videosController.add([
            createTestVideo('grid-video-after-filtered-item'),
            tapped,
            createTestVideo('later-video'),
          ]);
        },
        wait: const Duration(milliseconds: 150),
        expect: () => [
          isA<FullscreenFeedState>()
              .having((s) => s.currentIndex, 'currentIndex', 1)
              .having((s) => s.currentVideo?.id, 'currentVideo', 'tapped-video')
              .having(
                (s) => s.initialTargetResolved,
                'initialTargetResolved',
                true,
              ),
        ],
      );

      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'unresolved initial identity wins over fallback current video',
        build: () => createBloc(
          initialVideoId: 'target-video',
          initialStableId: 'stable-target-video',
        ),
        act: (bloc) async {
          final fallback = createTestVideo('fallback-video');
          final target = createTestVideo(
            'target-video',
            rawTags: const {'d': 'stable-target-video'},
          );

          bloc.add(const FullscreenFeedStarted());
          await Future<void>.delayed(const Duration(milliseconds: 50));
          videosController.add([fallback]);
          await Future<void>.delayed(const Duration(milliseconds: 50));
          videosController.add([createTestVideo('newer-video'), target]);
        },
        wait: const Duration(milliseconds: 200),
        expect: () => [
          isA<FullscreenFeedState>()
              .having((s) => s.currentIndex, 'currentIndex', 0)
              .having(
                (s) => s.currentVideo?.id,
                'currentVideo',
                'fallback-video',
              )
              .having(
                (s) => s.initialTargetResolved,
                'initialTargetResolved',
                false,
              ),
          isA<FullscreenFeedState>()
              .having((s) => s.currentIndex, 'currentIndex', 1)
              .having((s) => s.currentVideo?.id, 'currentVideo', 'target-video')
              .having(
                (s) => s.initialTargetResolved,
                'initialTargetResolved',
                true,
              ),
        ],
      );

      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'duplicate placeholder emits do not block resolving a later target',
        build: () => createBloc(
          initialVideoId: 'target-video',
          initialStableId: 'stable-target-video',
        ),
        act: (bloc) async {
          final placeholder = createTestVideo('placeholder-video');
          final target = createTestVideo(
            'target-video',
            rawTags: const {'d': 'stable-target-video'},
          );

          bloc.add(const FullscreenFeedStarted());
          await Future<void>.delayed(const Duration(milliseconds: 50));
          // Two identical placeholder emits before the target arrives. The
          // second one previously latched initialTargetResolved via the
          // preserve branch, which then blocked the real target from ever
          // being resolved (regression behind #5306's profile feed cache).
          videosController.add([placeholder]);
          await Future<void>.delayed(const Duration(milliseconds: 50));
          videosController.add([placeholder]);
          await Future<void>.delayed(const Duration(milliseconds: 50));
          videosController.add([createTestVideo('newer-video'), target]);
        },
        wait: const Duration(milliseconds: 250),
        expect: () => [
          isA<FullscreenFeedState>()
              .having(
                (s) => s.currentVideo?.id,
                'currentVideo',
                'placeholder-video',
              )
              .having(
                (s) => s.initialTargetResolved,
                'initialTargetResolved',
                false,
              ),
          isA<FullscreenFeedState>()
              .having((s) => s.currentIndex, 'currentIndex', 1)
              .having((s) => s.currentVideo?.id, 'currentVideo', 'target-video')
              .having(
                (s) => s.initialTargetResolved,
                'initialTargetResolved',
                true,
              ),
        ],
      );

      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'cancels previous subscription when started again',
        build: createBloc,
        act: (bloc) async {
          bloc.add(const FullscreenFeedStarted());
          await Future<void>.delayed(const Duration(milliseconds: 50));
          bloc.add(const FullscreenFeedStarted());
          await Future<void>.delayed(const Duration(milliseconds: 50));
          videosController.add([createTestVideo('video1')]);
        },
        wait: const Duration(milliseconds: 200),
        expect: () => [
          isA<FullscreenFeedState>().having(
            (s) => s.videos.length,
            'videos count',
            1,
          ),
        ],
      );
    });

    group('FullscreenFeedBlocklistChanged', () {
      final authorA = 'a' * 64;
      final authorB = 'b' * 64;
      final authorC = 'c' * 64;

      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'filters blocked authors from incoming stream lists at the boundary',
        build: () => createBloc(hideFilter: (video) => video.pubkey == authorB),
        act: (bloc) async {
          bloc.add(const FullscreenFeedStarted());
          await Future<void>.delayed(const Duration(milliseconds: 50));
          videosController.add([
            createTestVideo('a', pubkey: authorA),
            createTestVideo('b', pubkey: authorB),
            createTestVideo('c', pubkey: authorC),
          ]);
        },
        wait: const Duration(milliseconds: 100),
        expect: () => [
          isA<FullscreenFeedState>().having(
            (s) => s.videos.map((v) => v.id).toList(),
            'video ids',
            ['a', 'c'],
          ),
        ],
      );

      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'filters videos when a visible reposter is blocked',
        build: () => createBloc(
          hideFilter: (video) =>
              video.pubkey == authorB ||
              video.reposterPubkey == authorB ||
              (video.reposterPubkeys?.contains(authorB) ?? false),
        ),
        act: (bloc) async {
          bloc.add(const FullscreenFeedStarted());
          await Future<void>.delayed(const Duration(milliseconds: 50));
          videosController.add([
            createTestVideo('a', pubkey: authorA),
            createTestVideo('reposted', pubkey: authorC).copyWith(
              isRepost: true,
              reposterPubkey: authorB,
              reposterPubkeys: [authorB],
            ),
          ]);
        },
        wait: const Duration(milliseconds: 100),
        expect: () => [
          isA<FullscreenFeedState>().having(
            (s) => s.videos.map((v) => v.id).toList(),
            'video ids',
            ['a'],
          ),
        ],
      );

      // The boundary filter must hold across a source re-push — the
      // liked-videos like-change subscription / load-more re-emit unfiltered
      // lists (finding N1), so a blocked author must not slip back in.
      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'keeps blocked authors out across a source re-push',
        build: () => createBloc(hideFilter: (video) => video.pubkey == authorB),
        act: (bloc) async {
          bloc.add(const FullscreenFeedStarted());
          await Future<void>.delayed(const Duration(milliseconds: 50));
          videosController.add([
            createTestVideo('a', pubkey: authorA),
            createTestVideo('b', pubkey: authorB),
            createTestVideo('c', pubkey: authorC),
          ]);
          await Future<void>.delayed(const Duration(milliseconds: 50));
          // Source re-emits the same blocked author (plus a new unblocked one)
          // — 'b' must stay filtered out on the re-push.
          videosController.add([
            createTestVideo('a', pubkey: authorA),
            createTestVideo('b', pubkey: authorB),
            createTestVideo('c', pubkey: authorC),
            createTestVideo('d', pubkey: authorC),
          ]);
        },
        wait: const Duration(milliseconds: 200),
        expect: () => [
          isA<FullscreenFeedState>().having(
            (s) => s.videos.map((v) => v.id).toList(),
            'first ids',
            ['a', 'c'],
          ),
          isA<FullscreenFeedState>().having(
            (s) => s.videos.map((v) => v.id).toList(),
            're-push ids',
            ['a', 'c', 'd'],
          ),
        ],
      );

      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'preserves the playing video when an earlier author is blocked',
        build: () => createBloc(hideFilter: (video) => video.pubkey == authorB),
        seed: () => FullscreenFeedState(
          status: FullscreenFeedStatus.ready,
          videos: [
            createTestVideo('a', pubkey: authorA),
            createTestVideo('b', pubkey: authorB),
            createTestVideo('c', pubkey: authorC),
            createTestVideo('d', pubkey: authorA),
          ],
          currentIndex: 2,
        ),
        act: (bloc) => bloc.add(const FullscreenFeedBlocklistChanged()),
        expect: () => [
          isA<FullscreenFeedState>()
              .having((s) => s.videos.map((v) => v.id).toList(), 'video ids', [
                'a',
                'c',
                'd',
              ])
              .having((s) => s.currentIndex, 'currentIndex', 1)
              .having((s) => s.currentVideo?.id, 'currentVideo', 'c'),
        ],
      );

      // Seeded so the shift result (1) differs from a naive clamp of the old
      // index (clamp(3, 0, 2) == 2). Removing the cursor shift would land on
      // 'e', not 'd' — so this test fails loudly if the shift logic regresses.
      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'shifts the cursor left by the count of blocked videos before it',
        build: () => createBloc(hideFilter: (video) => video.pubkey == authorA),
        seed: () => FullscreenFeedState(
          status: FullscreenFeedStatus.ready,
          videos: [
            createTestVideo('a', pubkey: authorA),
            createTestVideo('b', pubkey: authorA),
            createTestVideo('c', pubkey: authorC),
            createTestVideo('d', pubkey: authorB),
            createTestVideo('e', pubkey: authorC),
          ],
          currentIndex: 3,
        ),
        act: (bloc) => bloc.add(const FullscreenFeedBlocklistChanged()),
        expect: () => [
          isA<FullscreenFeedState>()
              .having((s) => s.videos.map((v) => v.id).toList(), 'video ids', [
                'c',
                'd',
                'e',
              ])
              .having((s) => s.currentIndex, 'currentIndex', 1)
              .having((s) => s.currentVideo?.id, 'currentVideo', 'd'),
        ],
      );

      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'lands on the next survivor when the current video is blocked',
        build: () => createBloc(hideFilter: (video) => video.pubkey == authorB),
        seed: () => FullscreenFeedState(
          status: FullscreenFeedStatus.ready,
          videos: [
            createTestVideo('a', pubkey: authorA),
            createTestVideo('b', pubkey: authorB),
            createTestVideo('c', pubkey: authorC),
          ],
          currentIndex: 1,
        ),
        act: (bloc) => bloc.add(const FullscreenFeedBlocklistChanged()),
        expect: () => [
          isA<FullscreenFeedState>()
              .having((s) => s.videos.map((v) => v.id).toList(), 'video ids', [
                'a',
                'c',
              ])
              .having((s) => s.currentIndex, 'currentIndex', 1)
              .having((s) => s.currentVideo?.id, 'currentVideo', 'c'),
        ],
      );

      // Boundary case: cursor at 0 and the index-0 video is itself blocked.
      // `take(0)` yields 0 removed-before-cursor, so the next survivor must
      // surface at index 0.
      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'lands on the next survivor when the index-0 video is blocked',
        build: () => createBloc(hideFilter: (video) => video.pubkey == authorA),
        seed: () => FullscreenFeedState(
          status: FullscreenFeedStatus.ready,
          videos: [
            createTestVideo('a', pubkey: authorA),
            createTestVideo('b', pubkey: authorB),
            createTestVideo('c', pubkey: authorC),
          ],
        ),
        act: (bloc) => bloc.add(const FullscreenFeedBlocklistChanged()),
        expect: () => [
          isA<FullscreenFeedState>()
              .having((s) => s.videos.map((v) => v.id).toList(), 'video ids', [
                'b',
                'c',
              ])
              .having((s) => s.currentIndex, 'currentIndex', 0)
              .having((s) => s.currentVideo?.id, 'currentVideo', 'b'),
        ],
      );

      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'transitions to emptyAfterRemoval when every author is blocked',
        build: () => createBloc(hideFilter: (video) => video.pubkey == authorA),
        seed: () => FullscreenFeedState(
          status: FullscreenFeedStatus.ready,
          videos: [
            createTestVideo('a', pubkey: authorA),
            createTestVideo('b', pubkey: authorA),
          ],
        ),
        act: (bloc) => bloc.add(const FullscreenFeedBlocklistChanged()),
        expect: () => [
          isA<FullscreenFeedState>()
              .having(
                (s) => s.status,
                'status',
                FullscreenFeedStatus.emptyAfterRemoval,
              )
              .having((s) => s.videos, 'videos', isEmpty),
        ],
      );

      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'emits nothing when no author is blocked',
        build: () => createBloc(hideFilter: (video) => video.pubkey == authorB),
        seed: () => FullscreenFeedState(
          status: FullscreenFeedStatus.ready,
          videos: [
            createTestVideo('a', pubkey: authorA),
            createTestVideo('c', pubkey: authorC),
          ],
        ),
        act: (bloc) => bloc.add(const FullscreenFeedBlocklistChanged()),
        expect: () => <FullscreenFeedState>[],
      );

      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'emits nothing when no block filter is injected',
        build: createBloc,
        seed: () => FullscreenFeedState(
          status: FullscreenFeedStatus.ready,
          videos: [
            createTestVideo('a', pubkey: authorA),
            createTestVideo('b', pubkey: authorB),
          ],
        ),
        act: (bloc) => bloc.add(const FullscreenFeedBlocklistChanged()),
        expect: () => <FullscreenFeedState>[],
      );
    });

    group('FullscreenFeedLoadMoreRequested', () {
      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'sets isLoadingMore and calls onLoadMore callback',
        build: () {
          var callCount = 0;
          return createBloc(onLoadMore: () => callCount++);
        },
        act: (bloc) => bloc.add(const FullscreenFeedLoadMoreRequested()),
        expect: () => [
          isA<FullscreenFeedState>().having(
            (s) => s.isLoadingMore,
            'isLoadingMore',
            true,
          ),
        ],
      );

      test('calls onLoadMore callback when triggered', () async {
        var called = false;
        final bloc = FullscreenFeedBloc(
          videosStream: videosController.stream,
          initialIndex: 0,
          onLoadMore: () => called = true,
          mediaCache: mockMediaCache,
        );

        bloc.add(const FullscreenFeedLoadMoreRequested());
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(called, isTrue);
        await bloc.close();
      });

      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'does nothing when onLoadMore is null',
        build: createBloc,
        act: (bloc) => bloc.add(const FullscreenFeedLoadMoreRequested()),
        expect: () => <FullscreenFeedState>[],
      );

      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'does nothing when already loading more',
        build: () => createBloc(onLoadMore: () {}),
        seed: () => FullscreenFeedState(isLoadingMore: true),
        act: (bloc) => bloc.add(const FullscreenFeedLoadMoreRequested()),
        expect: () => <FullscreenFeedState>[],
      );

      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'resets isLoadingMore when onLoadMore throws synchronously',
        build: () => createBloc(
          onLoadMore: () => throw StateError('stale widget callback'),
        ),
        act: (bloc) => bloc.add(const FullscreenFeedLoadMoreRequested()),
        expect: () => [
          isA<FullscreenFeedState>().having(
            (s) => s.isLoadingMore,
            'isLoadingMore',
            true,
          ),
          isA<FullscreenFeedState>().having(
            (s) => s.isLoadingMore,
            'isLoadingMore',
            false,
          ),
        ],
      );
    });

    group('FullscreenFeedIndexChanged', () {
      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'updates currentIndex',
        build: createBloc,
        seed: () => FullscreenFeedState(
          status: FullscreenFeedStatus.ready,
          videos: [
            createTestVideo('video1'),
            createTestVideo('video2'),
            createTestVideo('video3'),
          ],
        ),
        act: (bloc) => bloc.add(const FullscreenFeedIndexChanged(2)),
        expect: () => [
          isA<FullscreenFeedState>().having(
            (s) => s.currentIndex,
            'currentIndex',
            2,
          ),
        ],
      );

      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'clamps index to valid range',
        build: createBloc,
        seed: () => FullscreenFeedState(
          status: FullscreenFeedStatus.ready,
          videos: [createTestVideo('video1'), createTestVideo('video2')],
        ),
        act: (bloc) => bloc.add(const FullscreenFeedIndexChanged(10)),
        expect: () => [
          isA<FullscreenFeedState>().having(
            (s) => s.currentIndex,
            'currentIndex',
            1,
          ),
        ],
      );

      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'clamps negative index to 0',
        build: createBloc,
        seed: () => FullscreenFeedState(
          status: FullscreenFeedStatus.ready,
          videos: [createTestVideo('video1')],
        ),
        act: (bloc) => bloc.add(const FullscreenFeedIndexChanged(-5)),
        expect: () => <FullscreenFeedState>[],
      );

      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'does nothing when index unchanged',
        build: createBloc,
        seed: () => FullscreenFeedState(
          status: FullscreenFeedStatus.ready,
          videos: [createTestVideo('video1')],
        ),
        act: (bloc) => bloc.add(const FullscreenFeedIndexChanged(0)),
        expect: () => <FullscreenFeedState>[],
      );

      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'sets index to 0 when videos are empty',
        build: createBloc,
        seed: () => FullscreenFeedState(
          status: FullscreenFeedStatus.ready,
          currentIndex: 5,
        ),
        act: (bloc) => bloc.add(const FullscreenFeedIndexChanged(10)),
        expect: () => [
          isA<FullscreenFeedState>().having(
            (s) => s.currentIndex,
            'currentIndex',
            0,
          ),
        ],
      );
    });

    group('close', () {
      test('cancels videos subscription', () async {
        final bloc = createBloc();
        bloc.add(const FullscreenFeedStarted());
        await Future<void>.delayed(const Duration(milliseconds: 50));

        await bloc.close();

        // After closing, stream events should not cause errors
        expect(
          () => videosController.add([createTestVideo('video1')]),
          returnsNormally,
        );
      });
    });

    group('FullscreenFeedEvent props', () {
      test('FullscreenFeedStarted props is empty', () {
        const event = FullscreenFeedStarted();
        expect(event.props, isEmpty);
      });

      test('FullscreenFeedLoadMoreRequested props is empty', () {
        const event = FullscreenFeedLoadMoreRequested();
        expect(event.props, isEmpty);
      });

      test('FullscreenFeedIndexChanged props contains index', () {
        const event = FullscreenFeedIndexChanged(5);
        expect(event.props, [5]);
      });

      test('FullscreenFeedVideoCacheStarted props contains index', () {
        const event = FullscreenFeedVideoCacheStarted(index: 3);
        expect(event.props, [3]);
      });
    });

    group('cache resolution', () {
      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'does not replace videoUrl with cache path when videos arrive',
        setUp: () {
          final mockFile = MockFile();
          when(() => mockFile.path).thenReturn('/cached/video1.mp4');
          when(
            () => mockMediaCache.getCachedFileSync('video1'),
          ).thenReturn(mockFile);
        },
        build: createBloc,
        act: (bloc) async {
          bloc.add(const FullscreenFeedStarted());
          await Future<void>.delayed(const Duration(milliseconds: 50));
          videosController.add([createTestVideo('video1')]);
        },
        wait: const Duration(milliseconds: 100),
        expect: () => [
          isA<FullscreenFeedState>()
              .having((s) => s.status, 'status', FullscreenFeedStatus.ready)
              .having(
                (s) => s.videos.first.videoUrl,
                'videoUrl preserved as HTTP',
                'https://example.com/video_video1.mp4',
              ),
        ],
      );

      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'keeps original URL when video is not cached',
        build: createBloc,
        act: (bloc) async {
          bloc.add(const FullscreenFeedStarted());
          await Future<void>.delayed(const Duration(milliseconds: 50));
          videosController.add([createTestVideo('video1')]);
        },
        wait: const Duration(milliseconds: 100),
        expect: () => [
          isA<FullscreenFeedState>().having(
            (s) => s.videos.first.videoUrl,
            'original video URL',
            'https://example.com/video_video1.mp4',
          ),
        ],
      );

      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'preserves HTTP videoUrl when cache hit occurs '
        '(never replaces with local file path)',
        setUp: () {
          final mockFile = MockFile();
          when(() => mockFile.path).thenReturn(
            '/data/user/0/co.openvine.app/cache/openvine_video_cache/video1.mp4',
          );
          when(
            () => mockMediaCache.getCachedFileSync('video1'),
          ).thenReturn(mockFile);
        },
        build: createBloc,
        act: (bloc) async {
          bloc.add(const FullscreenFeedStarted());
          await Future<void>.delayed(const Duration(milliseconds: 50));
          videosController.add([createTestVideo('video1')]);
        },
        wait: const Duration(milliseconds: 100),
        expect: () => [
          isA<FullscreenFeedState>()
              .having((s) => s.status, 'status', FullscreenFeedStatus.ready)
              .having(
                (s) => s.videos.first.videoUrl,
                'videoUrl must remain HTTP',
                startsWith('https://'),
              ),
        ],
      );
    });

    group('FullscreenFeedVideoCacheStarted', () {
      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'triggers background caching for uncached video',
        setUp: () {
          when(
            () => mockMediaCache.downloadFile(
              any(),
              key: any(named: 'key'),
              authHeaders: any(named: 'authHeaders'),
            ),
          ).thenAnswer((_) async => MockFileInfo());
        },
        build: createBloc,
        seed: () => FullscreenFeedState(
          status: FullscreenFeedStatus.ready,
          videos: [createTestVideo('video1')],
        ),
        act: (bloc) =>
            bloc.add(const FullscreenFeedVideoCacheStarted(index: 0)),
        wait: const Duration(milliseconds: 100),
        verify: (_) {
          verify(
            () => mockMediaCache.downloadFile(
              'https://example.com/video_video1.mp4',
              key: 'video1',
            ),
          ).called(1);
        },
      );

      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'skips caching when video is already cached',
        setUp: () {
          final mockFile = MockFile();
          when(() => mockFile.path).thenReturn('/cached/video1.mp4');
          when(
            () => mockMediaCache.getCachedFileSync('video1'),
          ).thenReturn(mockFile);
        },
        build: createBloc,
        seed: () => FullscreenFeedState(
          status: FullscreenFeedStatus.ready,
          videos: [createTestVideo('video1')],
        ),
        act: (bloc) =>
            bloc.add(const FullscreenFeedVideoCacheStarted(index: 0)),
        wait: const Duration(milliseconds: 100),
        verify: (_) {
          verifyNever(
            () => mockMediaCache.downloadFile(
              any(),
              key: any(named: 'key'),
              authHeaders: any(named: 'authHeaders'),
            ),
          );
        },
      );

      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'does nothing for invalid index',
        build: createBloc,
        seed: () => FullscreenFeedState(
          status: FullscreenFeedStatus.ready,
          videos: [createTestVideo('video1')],
        ),
        act: (bloc) =>
            bloc.add(const FullscreenFeedVideoCacheStarted(index: 5)),
        wait: const Duration(milliseconds: 50),
        verify: (_) {
          verifyNever(
            () => mockMediaCache.downloadFile(
              any(),
              key: any(named: 'key'),
              authHeaders: any(named: 'authHeaders'),
            ),
          );
        },
      );

      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'background caching uses HTTP URL '
        '(never passes local file path to downloadFile)',
        setUp: () {
          when(
            () => mockMediaCache.downloadFile(
              any(),
              key: any(named: 'key'),
              authHeaders: any(named: 'authHeaders'),
            ),
          ).thenAnswer((_) async => MockFileInfo());
        },
        build: createBloc,
        act: (bloc) async {
          bloc.add(const FullscreenFeedStarted());
          await Future<void>.delayed(const Duration(milliseconds: 50));
          videosController.add([createTestVideo('video1')]);
          await Future<void>.delayed(const Duration(milliseconds: 50));
          bloc.add(const FullscreenFeedVideoCacheStarted(index: 0));
        },
        wait: const Duration(milliseconds: 200),
        verify: (_) {
          // downloadFile must receive an HTTP URL, not a local file path
          verify(
            () => mockMediaCache.downloadFile(
              'https://example.com/video_video1.mp4',
              key: 'video1',
            ),
          ).called(1);
          // Must never be called with a file path
          verifyNever(
            () => mockMediaCache.downloadFile(
              any(that: startsWith('/')),
              key: any(named: 'key'),
              authHeaders: any(named: 'authHeaders'),
            ),
          );
        },
      );

      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'skips caching when videoUrl is a local file path',
        build: createBloc,
        seed: () => FullscreenFeedState(
          status: FullscreenFeedStatus.ready,
          videos: [
            VideoEvent(
              id: 'video1',
              pubkey: '0' * 64,
              createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
              content: '',
              timestamp: DateTime.now(),
              title: 'Test',
              videoUrl: '/data/user/0/cache/video1.mp4',
            ),
          ],
        ),
        act: (bloc) =>
            bloc.add(const FullscreenFeedVideoCacheStarted(index: 0)),
        wait: const Duration(milliseconds: 100),
        verify: (_) {
          verifyNever(
            () => mockMediaCache.downloadFile(
              any(),
              key: any(named: 'key'),
              authHeaders: any(named: 'authHeaders'),
            ),
          );
        },
      );

      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'skips caching for original Vine raw blobs with no cacheable URL',
        build: createBloc,
        seed: () => FullscreenFeedState(
          status: FullscreenFeedStatus.ready,
          videos: [
            createTestVideo(
              'vine1',
              videoUrl:
                  'https://media.divine.video/'
                  'cfb5cf3415ec4ad3f45eff478570d898ff9a660ecea63d0c058892b22468a90d',
              rawTags: const {'platform': 'vine'},
            ),
          ],
        ),
        act: (bloc) =>
            bloc.add(const FullscreenFeedVideoCacheStarted(index: 0)),
        wait: const Duration(milliseconds: 100),
        verify: (_) {
          verifyNever(
            () => mockMediaCache.downloadFile(
              any(),
              key: any(named: 'key'),
              authHeaders: any(named: 'authHeaders'),
            ),
          );
        },
      );

      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'includes auth headers when BlossomAuthService is provided',
        setUp: () {
          when(
            () => mockBlossomAuth.createGetAuthHeader(
              sha256Hash: any(named: 'sha256Hash'),
              serverUrl: any(named: 'serverUrl'),
            ),
          ).thenAnswer((_) async => 'Nostr test-token');
          when(
            () => mockMediaCache.downloadFile(
              any(),
              key: any(named: 'key'),
              authHeaders: any(named: 'authHeaders'),
            ),
          ).thenAnswer((_) async => MockFileInfo());
        },
        build: () => createBloc(blossomAuthService: mockBlossomAuth),
        seed: () => FullscreenFeedState(
          status: FullscreenFeedStatus.ready,
          videos: [createTestVideo('video1', sha256: 'abc123')],
        ),
        act: (bloc) =>
            bloc.add(const FullscreenFeedVideoCacheStarted(index: 0)),
        wait: const Duration(milliseconds: 100),
        verify: (_) {
          // Server origin extracted from videoUrl and forwarded so the
          // BUD-01 kind 24242 event includes the `server` tag.
          verify(
            () => mockBlossomAuth.createGetAuthHeader(
              sha256Hash: 'abc123',
              serverUrl: 'https://example.com',
            ),
          ).called(1);
          verify(
            () => mockMediaCache.downloadFile(
              'https://example.com/video_video1.mp4',
              key: 'video1',
              authHeaders: {'Authorization': 'Nostr test-token'},
            ),
          ).called(1);
        },
      );
    });

    group('unavailableFilter (persisted unavailable media)', () {
      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'filters known-unavailable videos from incoming stream lists',
        build: () => createBloc(unavailableFilter: (id) => id == 'broken'),
        act: (bloc) async {
          bloc.add(const FullscreenFeedStarted());
          await Future<void>.delayed(const Duration(milliseconds: 50));
          videosController.add([
            createTestVideo('a'),
            createTestVideo('broken'),
            createTestVideo('c'),
          ]);
        },
        wait: const Duration(milliseconds: 100),
        expect: () => [
          isA<FullscreenFeedState>().having(
            (s) => s.videos.map((v) => v.id).toList(),
            'video ids',
            ['a', 'c'],
          ),
        ],
      );

      // Static sources (liked / saved / reposts / curated lists) re-emit
      // unfiltered by-id lists, so a known-unavailable video must stay out
      // across a re-push — the gap this filter closes for #5237.
      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'keeps known-unavailable videos out across a source re-push',
        build: () => createBloc(unavailableFilter: (id) => id == 'broken'),
        act: (bloc) async {
          bloc.add(const FullscreenFeedStarted());
          await Future<void>.delayed(const Duration(milliseconds: 50));
          videosController.add([
            createTestVideo('a'),
            createTestVideo('broken'),
          ]);
          await Future<void>.delayed(const Duration(milliseconds: 50));
          videosController.add([
            createTestVideo('a'),
            createTestVideo('broken'),
            createTestVideo('c'),
          ]);
        },
        wait: const Duration(milliseconds: 150),
        expect: () => [
          isA<FullscreenFeedState>().having(
            (s) => s.videos.map((v) => v.id).toList(),
            'video ids',
            ['a'],
          ),
          isA<FullscreenFeedState>().having(
            (s) => s.videos.map((v) => v.id).toList(),
            'video ids',
            ['a', 'c'],
          ),
        ],
      );
    });

    group('FullscreenFeedVideoUnavailable', () {
      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'removes video and emits pending skip when confirmation allows prune',
        build: () {
          final removed = <String>[];
          return createBloc(
            onRemoveVideo: removed.add,
            confirmVideoUnavailable: confirmerReturning(true),
          );
        },
        seed: () => FullscreenFeedState(
          status: FullscreenFeedStatus.ready,
          videos: [createTestVideo('video1'), createTestVideo('video2')],
        ),
        act: (bloc) => bloc.add(const FullscreenFeedVideoUnavailable('video1')),
        wait: const Duration(milliseconds: 100),
        expect: () => [
          isA<FullscreenFeedState>()
              .having(
                (s) => s.removedVideoIds,
                'removedVideoIds',
                equals({'video1'}),
              )
              .having(
                (s) => s.videos.map((v) => v.id).toList(),
                'video ids',
                ['video2'],
              )
              .having(
                (s) => s.pendingSkipTarget,
                'pendingSkipTarget',
                equals(0),
              ),
        ],
      );

      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'calls onRemoveVideo callback when confirmation allows prune',
        build: () => createBloc(
          onRemoveVideo: expectAsync1<void, String>((id) {
            expect(id, equals('video1'));
          }),
          confirmVideoUnavailable: confirmerReturning(true),
        ),
        seed: () => FullscreenFeedState(
          status: FullscreenFeedStatus.ready,
          videos: [createTestVideo('video1')],
        ),
        act: (bloc) => bloc.add(const FullscreenFeedVideoUnavailable('video1')),
        wait: const Duration(milliseconds: 100),
      );

      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'does not remove or skip when confirmation rejects prune',
        build: () {
          return createBloc(
            onRemoveVideo: (_) => fail('should not remove on rejected prune'),
            confirmVideoUnavailable: confirmerReturning(false),
          );
        },
        seed: () => FullscreenFeedState(
          status: FullscreenFeedStatus.ready,
          videos: [createTestVideo('video1')],
        ),
        act: (bloc) => bloc.add(const FullscreenFeedVideoUnavailable('video1')),
        wait: const Duration(milliseconds: 100),
        expect: () => <FullscreenFeedState>[],
      );

      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'does not remove when confirmation is conservative after lookup failure',
        build: () {
          return createBloc(
            onRemoveVideo: (_) => fail('should not remove on failed lookup'),
            confirmVideoUnavailable: confirmerReturning(false),
          );
        },
        seed: () => FullscreenFeedState(
          status: FullscreenFeedStatus.ready,
          videos: [createTestVideo('video1')],
        ),
        act: (bloc) => bloc.add(const FullscreenFeedVideoUnavailable('video1')),
        wait: const Duration(milliseconds: 100),
        expect: () => <FullscreenFeedState>[],
      );

      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'calls onVideoConfirmedUnavailable when confirmation allows prune',
        build: () => createBloc(
          onVideoConfirmedUnavailable: expectAsync1<void, VideoEvent>((video) {
            expect(video.id, equals('video1'));
          }),
          confirmVideoUnavailable: confirmerReturning(true),
        ),
        seed: () => FullscreenFeedState(
          status: FullscreenFeedStatus.ready,
          videos: [createTestVideo('video1')],
        ),
        act: (bloc) => bloc.add(const FullscreenFeedVideoUnavailable('video1')),
        wait: const Duration(milliseconds: 100),
      );

      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'does not call onVideoConfirmedUnavailable when confirmation rejects',
        build: () => createBloc(
          onVideoConfirmedUnavailable: (_) =>
              fail('should not persist on rejected prune'),
          confirmVideoUnavailable: confirmerReturning(false),
        ),
        seed: () => FullscreenFeedState(
          status: FullscreenFeedStatus.ready,
          videos: [createTestVideo('video1')],
        ),
        act: (bloc) => bloc.add(const FullscreenFeedVideoUnavailable('video1')),
        wait: const Duration(milliseconds: 100),
        expect: () => <FullscreenFeedState>[],
      );

      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'does not call onVideoConfirmedUnavailable after lookup failure',
        build: () => createBloc(
          onVideoConfirmedUnavailable: (_) =>
              fail('should not persist after failed lookup'),
          confirmVideoUnavailable: confirmerReturning(false),
        ),
        seed: () => FullscreenFeedState(
          status: FullscreenFeedStatus.ready,
          videos: [createTestVideo('video1')],
        ),
        act: (bloc) => bloc.add(const FullscreenFeedVideoUnavailable('video1')),
        wait: const Duration(milliseconds: 100),
        expect: () => <FullscreenFeedState>[],
      );

      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'deduplicates repeated unavailable events for the same video',
        build: () {
          var callCount = 0;
          return createBloc(
            onRemoveVideo: (_) => callCount++,
            confirmVideoUnavailable: confirmerReturning(true),
          );
        },
        seed: () => FullscreenFeedState(
          status: FullscreenFeedStatus.ready,
          videos: [createTestVideo('video1'), createTestVideo('video2')],
        ),
        act: (bloc) async {
          bloc.add(const FullscreenFeedVideoUnavailable('video1'));
          await Future<void>.delayed(const Duration(milliseconds: 50));
          bloc.add(const FullscreenFeedVideoUnavailable('video1'));
          await Future<void>.delayed(const Duration(milliseconds: 50));
          bloc.add(const FullscreenFeedVideoUnavailable('video1'));
        },
        wait: const Duration(milliseconds: 200),
        expect: () => [
          isA<FullscreenFeedState>()
              .having(
                (s) => s.removedVideoIds,
                'removedVideoIds',
                equals({'video1'}),
              )
              .having(
                (s) => s.pendingSkipTarget,
                'pendingSkipTarget',
                equals(0),
              ),
        ],
      );

      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'no-ops when video id is not in the current list',
        build: () => createBloc(
          onRemoveVideo: (_) => fail('unknown video should not trigger remove'),
          confirmVideoUnavailable: confirmerReturning(true),
        ),
        seed: () => FullscreenFeedState(
          status: FullscreenFeedStatus.ready,
          videos: [createTestVideo('video1')],
        ),
        act: (bloc) =>
            bloc.add(const FullscreenFeedVideoUnavailable('unknown')),
        wait: const Duration(milliseconds: 50),
        expect: () => <FullscreenFeedState>[],
      );

      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'no-ops when video has no URL',
        build: () => createBloc(
          onRemoveVideo: (_) => fail('videos without URL cannot be confirmed'),
          confirmVideoUnavailable: confirmerReturning(true),
        ),
        seed: () => FullscreenFeedState(
          status: FullscreenFeedStatus.ready,
          videos: [
            VideoEvent(
              id: 'video1',
              pubkey: '0' * 64,
              createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
              content: '',
              timestamp: DateTime.now(),
              title: 'no url',
            ),
          ],
        ),
        act: (bloc) => bloc.add(const FullscreenFeedVideoUnavailable('video1')),
        wait: const Duration(milliseconds: 50),
        expect: () => <FullscreenFeedState>[],
      );

      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'skip target lands on the survivor now at the removed index',
        build: () => createBloc(
          onRemoveVideo: (_) {},
          confirmVideoUnavailable: confirmerReturning(true),
        ),
        seed: () => FullscreenFeedState(
          status: FullscreenFeedStatus.ready,
          videos: [
            createTestVideo('video1'),
            createTestVideo('video2'),
            createTestVideo('video3'),
          ],
          currentIndex: 1,
        ),
        act: (bloc) => bloc.add(const FullscreenFeedVideoUnavailable('video2')),
        wait: const Duration(milliseconds: 100),
        expect: () => [
          isA<FullscreenFeedState>()
              .having(
                (s) => s.videos.map((v) => v.id).toList(),
                'video ids',
                ['video1', 'video3'],
              )
              .having((s) => s.currentIndex, 'currentIndex', equals(1))
              .having(
                (s) => s.pendingSkipTarget,
                'pendingSkipTarget',
                equals(1),
              ),
        ],
      );

      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'session-only confirmation removes without persisting',
        build: () => createBloc(
          onRemoveVideo: expectAsync1<void, String>((id) {
            expect(id, equals('video1'));
          }),
          onVideoConfirmedUnavailable: (_) =>
              fail('API-missing 404 must not persist'),
          confirmVideoUnavailable: confirmerWith(
            FeedUnavailability.sessionOnly,
          ),
        ),
        seed: () => FullscreenFeedState(
          status: FullscreenFeedStatus.ready,
          videos: [createTestVideo('video1')],
        ),
        act: (bloc) => bloc.add(const FullscreenFeedVideoUnavailable('video1')),
        wait: const Duration(milliseconds: 100),
        expect: () => [
          isA<FullscreenFeedState>()
              .having(
                (s) => s.removedVideoIds,
                'removedVideoIds',
                equals({'video1'}),
              )
              .having(
                (s) => s.status,
                'status',
                FullscreenFeedStatus.emptyAfterRemoval,
              )
              .having((s) => s.videos, 'videos', isEmpty),
        ],
      );

      test('re-resolves the video after confirm if the list shifted', () async {
        final started = Completer<void>();
        final release = Completer<void>();
        final bloc = createBloc(
          confirmVideoUnavailable:
              ({
                required videoId,
                required videoUrl,
                explicitSha256,
              }) async {
                started.complete();
                await release.future;
                return FeedUnavailability.sessionOnly;
              },
        );
        addTearDown(bloc.close);
        bloc.add(const FullscreenFeedStarted());
        await Future<void>.delayed(const Duration(milliseconds: 50));
        videosController.add([
          createTestVideo('video1'),
          createTestVideo('video2'),
          createTestVideo('video3'),
        ]);
        await Future<void>.delayed(const Duration(milliseconds: 100));

        bloc.add(const FullscreenFeedVideoUnavailable('video2'));
        await started.future;
        videosController.add([
          createTestVideo('video3'),
          createTestVideo('video1'),
          createTestVideo('video2'),
        ]);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        release.complete();
        await Future<void>.delayed(const Duration(milliseconds: 100));

        expect(bloc.state.videos.map((v) => v.id), ['video3', 'video1']);
        expect(bloc.state.removedVideoIds, equals({'video2'}));
      });

      test(
        'session-only removal survives a source re-push of the same id',
        () async {
          final bloc = createBloc(
            confirmVideoUnavailable: confirmerWith(
              FeedUnavailability.sessionOnly,
            ),
          );
          addTearDown(bloc.close);
          bloc.add(const FullscreenFeedStarted());
          await Future<void>.delayed(const Duration(milliseconds: 50));
          videosController.add([
            createTestVideo('video1'),
            createTestVideo('video2'),
          ]);
          await Future<void>.delayed(const Duration(milliseconds: 100));
          expect(bloc.state.videos.map((v) => v.id), ['video1', 'video2']);

          bloc.add(const FullscreenFeedVideoUnavailable('video1'));
          await Future<void>.delayed(const Duration(milliseconds: 100));
          expect(bloc.state.videos.map((v) => v.id), ['video2']);
          expect(bloc.state.removedVideoIds, equals({'video1'}));

          videosController.add([
            createTestVideo('video1'),
            createTestVideo('video2'),
          ]);
          await Future<void>.delayed(const Duration(milliseconds: 100));
          expect(bloc.state.videos.map((v) => v.id), ['video2']);
        },
      );

      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'passes video id, URL and explicit sha256 to confirmation',
        build: () => createBloc(
          confirmVideoUnavailable: confirmerReturning(
            true,
            onCall: expectAsync3((videoId, videoUrl, explicitSha256) {
              expect(videoId, equals('video1'));
              expect(videoUrl, equals('https://example.com/video_video1.mp4'));
              expect(explicitSha256, equals('a' * 64));
            }),
          ),
        ),
        seed: () => FullscreenFeedState(
          status: FullscreenFeedStatus.ready,
          videos: [createTestVideo('video1', sha256: 'a' * 64)],
        ),
        act: (bloc) => bloc.add(const FullscreenFeedVideoUnavailable('video1')),
        wait: const Duration(milliseconds: 100),
      );
    });

    group('FullscreenFeedSkipAcknowledged', () {
      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'clears pendingSkipTarget when acknowledged',
        build: createBloc,
        seed: () => FullscreenFeedState(
          status: FullscreenFeedStatus.ready,
          pendingSkipTarget: 2,
        ),
        act: (bloc) => bloc.add(const FullscreenFeedSkipAcknowledged()),
        expect: () => [
          isA<FullscreenFeedState>().having(
            (s) => s.pendingSkipTarget,
            'pendingSkipTarget',
            isNull,
          ),
        ],
      );

      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'no-ops when no pending skip',
        build: createBloc,
        seed: () => FullscreenFeedState(status: FullscreenFeedStatus.ready),
        act: (bloc) => bloc.add(const FullscreenFeedSkipAcknowledged()),
        expect: () => <FullscreenFeedState>[],
      );

      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'allows subsequent unavailable events to emit a new skip',
        build: () => createBloc(
          onRemoveVideo: (_) {},
          confirmVideoUnavailable: confirmerReturning(true),
        ),
        seed: () => FullscreenFeedState(
          status: FullscreenFeedStatus.ready,
          videos: [
            createTestVideo('video1'),
            createTestVideo('video2'),
            createTestVideo('video3'),
          ],
        ),
        act: (bloc) async {
          bloc.add(const FullscreenFeedVideoUnavailable('video1'));
          await Future<void>.delayed(const Duration(milliseconds: 50));
          bloc.add(const FullscreenFeedSkipAcknowledged());
          await Future<void>.delayed(const Duration(milliseconds: 50));
          bloc.add(const FullscreenFeedVideoUnavailable('video2'));
        },
        wait: const Duration(milliseconds: 300),
        expect: () => [
          isA<FullscreenFeedState>().having(
            (s) => s.pendingSkipTarget,
            'pendingSkipTarget after first unavailable',
            equals(0),
          ),
          isA<FullscreenFeedState>().having(
            (s) => s.pendingSkipTarget,
            'pendingSkipTarget cleared',
            isNull,
          ),
          isA<FullscreenFeedState>().having(
            (s) => s.pendingSkipTarget,
            'pendingSkipTarget after second unavailable',
            equals(0),
          ),
        ],
      );
    });

    group('props and copyWith for new fields', () {
      test('removedVideoIds default is empty', () {
        final state = FullscreenFeedState();
        expect(state.removedVideoIds, isEmpty);
      });

      test('pendingSkipTarget default is null', () {
        final state = FullscreenFeedState();
        expect(state.pendingSkipTarget, isNull);
      });

      test('copyWith updates removedVideoIds', () {
        final state = FullscreenFeedState();
        final updated = state.copyWith(removedVideoIds: {'a', 'b'});
        expect(updated.removedVideoIds, equals({'a', 'b'}));
      });

      test('copyWith updates pendingSkipTarget', () {
        final state = FullscreenFeedState();
        final updated = state.copyWith(pendingSkipTarget: 5);
        expect(updated.pendingSkipTarget, equals(5));
      });

      test('copyWith clearPendingSkipTarget resets to null', () {
        final state = FullscreenFeedState(pendingSkipTarget: 5);
        final updated = state.copyWith(clearPendingSkipTarget: true);
        expect(updated.pendingSkipTarget, isNull);
      });

      test('FullscreenFeedVideoUnavailable props contains videoId', () {
        const event = FullscreenFeedVideoUnavailable('abc');
        expect(event.props, equals(['abc']));
      });

      test('FullscreenFeedVideoRemoved props contains videoId', () {
        const event = FullscreenFeedVideoRemoved('abc');
        expect(event.props, equals(['abc']));
      });

      test('FullscreenFeedSkipAcknowledged props is empty', () {
        const event = FullscreenFeedSkipAcknowledged();
        expect(event.props, isEmpty);
      });
    });

    group('FullscreenFeedVideoRemoved', () {
      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'removes the video from state.videos and clamps the current index',
        build: () => createBloc(initialIndex: 1),
        act: (bloc) async {
          bloc.add(const FullscreenFeedStarted());
          await Future<void>.delayed(Duration.zero);
          videosController.add([
            createTestVideo('a'),
            createTestVideo('b'),
            createTestVideo('c'),
          ]);
          await Future<void>.delayed(Duration.zero);
          bloc.add(const FullscreenFeedVideoRemoved('b'));
          await Future<void>.delayed(Duration.zero);
        },
        verify: (bloc) {
          expect(bloc.state.videos.map((v) => v.id), equals(['a', 'c']));
          expect(bloc.state.currentIndex, 1);
          expect(bloc.state.removedVideoIds, contains('b'));
          expect(
            bloc.state.status,
            isNot(FullscreenFeedStatus.emptyAfterRemoval),
          );
        },
      );

      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'transitions to emptyAfterRemoval when the last video is removed',
        build: createBloc,
        act: (bloc) async {
          bloc.add(const FullscreenFeedStarted());
          await Future<void>.delayed(Duration.zero);
          videosController.add([createTestVideo('only')]);
          await Future<void>.delayed(Duration.zero);
          bloc.add(const FullscreenFeedVideoRemoved('only'));
          await Future<void>.delayed(Duration.zero);
        },
        verify: (bloc) {
          expect(bloc.state.videos, isEmpty);
          expect(bloc.state.removedVideoIds, contains('only'));
          expect(bloc.state.status, FullscreenFeedStatus.emptyAfterRemoval);
        },
      );

      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'second removal of the same id is a no-op (dedupe)',
        build: createBloc,
        act: (bloc) async {
          bloc.add(const FullscreenFeedStarted());
          await Future<void>.delayed(Duration.zero);
          videosController.add([createTestVideo('a'), createTestVideo('b')]);
          await Future<void>.delayed(Duration.zero);
          bloc.add(const FullscreenFeedVideoRemoved('a'));
          await Future<void>.delayed(Duration.zero);
          bloc.add(const FullscreenFeedVideoRemoved('a'));
          await Future<void>.delayed(Duration.zero);
        },
        verify: (bloc) {
          expect(bloc.state.videos.map((v) => v.id), equals(['b']));
          expect(bloc.state.removedVideoIds, equals({'a'}));
        },
      );

      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'records dedupe even when video is not in the visible list',
        build: createBloc,
        act: (bloc) async {
          bloc.add(const FullscreenFeedStarted());
          await Future<void>.delayed(Duration.zero);
          videosController.add([createTestVideo('a')]);
          await Future<void>.delayed(Duration.zero);
          bloc.add(const FullscreenFeedVideoRemoved('not-present'));
          await Future<void>.delayed(Duration.zero);
        },
        verify: (bloc) {
          expect(bloc.state.videos.map((v) => v.id), equals(['a']));
          expect(bloc.state.removedVideoIds, contains('not-present'));
        },
      );

      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'shifts currentIndex left when removed item is before the cursor',
        build: createBloc,
        act: (bloc) async {
          bloc.add(const FullscreenFeedStarted());
          await Future<void>.delayed(Duration.zero);
          videosController.add([
            createTestVideo('a'),
            createTestVideo('b'),
            createTestVideo('c'),
            createTestVideo('d'),
          ]);
          await Future<void>.delayed(Duration.zero);
          // Move cursor to 'c' (index 2).
          bloc.add(const FullscreenFeedIndexChanged(2));
          await Future<void>.delayed(Duration.zero);
          // Remove 'a' (index 0, before the cursor).
          bloc.add(const FullscreenFeedVideoRemoved('a'));
          await Future<void>.delayed(Duration.zero);
        },
        verify: (bloc) {
          expect(bloc.state.videos.map((v) => v.id), equals(['b', 'c', 'd']));
          // Without the shift, currentIndex would stay at 2 → bloc would
          // surface 'd'. The cursor must follow 'c' to its new position.
          expect(bloc.state.currentIndex, 1);
          expect(bloc.state.currentVideo?.id, 'c');
          expect(bloc.state.removedVideoIds, contains('a'));
        },
      );

      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'leaves currentIndex unchanged when removed item is after the cursor',
        build: createBloc,
        act: (bloc) async {
          bloc.add(const FullscreenFeedStarted());
          await Future<void>.delayed(Duration.zero);
          videosController.add([
            createTestVideo('a'),
            createTestVideo('b'),
            createTestVideo('c'),
          ]);
          await Future<void>.delayed(Duration.zero);
          // Cursor on 'a'.
          bloc.add(const FullscreenFeedIndexChanged(0));
          await Future<void>.delayed(Duration.zero);
          bloc.add(const FullscreenFeedVideoRemoved('c'));
          await Future<void>.delayed(Duration.zero);
        },
        verify: (bloc) {
          expect(bloc.state.videos.map((v) => v.id), equals(['a', 'b']));
          expect(bloc.state.currentIndex, 0);
          expect(bloc.state.currentVideo?.id, 'a');
        },
      );

      blocTest<FullscreenFeedBloc, FullscreenFeedState>(
        'subscribes to removedIdsStream and dispatches removals',
        build: () {
          final removedController = StreamController<String>.broadcast();
          addTearDown(removedController.close);
          final bloc = FullscreenFeedBloc(
            videosStream: videosController.stream,
            initialIndex: 0,
            removedIdsStream: removedController.stream,
            mediaCache: mockMediaCache,
            blossomAuthService: mockBlossomAuth,
          );
          // Schedule the removal AFTER the bloc subscribes inside _onStarted.
          Future<void>(() async {
            await Future<void>.delayed(const Duration(milliseconds: 1));
            videosController.add([createTestVideo('a'), createTestVideo('b')]);
            await Future<void>.delayed(const Duration(milliseconds: 1));
            removedController.add('a');
          });
          return bloc;
        },
        act: (bloc) async {
          bloc.add(const FullscreenFeedStarted());
          await Future<void>.delayed(const Duration(milliseconds: 50));
        },
        verify: (bloc) {
          expect(bloc.state.videos.map((v) => v.id), equals(['b']));
          expect(bloc.state.removedVideoIds, contains('a'));
        },
      );

      test('close() cancels the removedIdsStream subscription', () async {
        final removedController = StreamController<String>.broadcast();
        addTearDown(removedController.close);

        final bloc = FullscreenFeedBloc(
          videosStream: videosController.stream,
          initialIndex: 0,
          removedIdsStream: removedController.stream,
          mediaCache: mockMediaCache,
          blossomAuthService: mockBlossomAuth,
        );
        bloc.add(const FullscreenFeedStarted());
        await Future<void>.delayed(const Duration(milliseconds: 1));
        videosController.add([createTestVideo('a'), createTestVideo('b')]);
        await Future<void>.delayed(const Duration(milliseconds: 1));

        await bloc.close();

        // Adding to the stream after close must NOT fire any further state
        // transitions — the bloc has been disposed.
        removedController.add('a');
        await Future<void>.delayed(const Duration(milliseconds: 5));
        expect(bloc.isClosed, isTrue);
      });
    });
  });
}
