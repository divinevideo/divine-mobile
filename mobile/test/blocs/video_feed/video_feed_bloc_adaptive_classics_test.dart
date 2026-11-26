// ABOUTME: Pins how Home's VideoFeedBloc follows the Adaptive Classics gate:
// ABOUTME: an archive slice stays on the archive until the user refreshes.

import 'dart:async';

import 'package:cache_sync/cache_sync.dart';
import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_feed/video_feed_bloc.dart';
import 'package:videos_repository/videos_repository.dart';

import '../../helpers/test_pubkeys.dart';

class _MockVideosRepository extends Mock implements VideosRepository {
  @override
  Future<List<VideoEvent>> applyHomeFeedPreferences(
    List<VideoEvent> videos,
  ) async => applyContentPreferences(videos);

  @override
  bool isVideoKnownDeleted(VideoEvent video) => false;
}

class _MockFollowRepository extends Mock implements FollowRepository {}

class _MockCuratedListRepository extends Mock
    implements CuratedListRepository {}

/// Keeps the cold-start serve path off the shared on-disk cache.
class _FakeCacheDao implements CacheDao {
  @override
  Future<CacheEntry?> readEntry(String key) async => null;

  @override
  Future<void> write({
    required String key,
    required String payload,
    Duration? ttl,
  }) async {}

  @override
  Future<void> delete(String key) async {}

  @override
  Future<void> deletePrefix(String prefix) async {}

  @override
  Future<int> totalPayloadBytes() async => 0;

  @override
  Future<void> evictOldest(int bytesToFree) async {}
}

VideoEvent _video(int n) {
  final timestamp = 1700000000 - n;
  return VideoEvent(
    id: n.toRadixString(16).padLeft(64, '0'),
    pubkey: testPubkeyFromSeed(n),
    createdAt: timestamp,
    content: '',
    timestamp: DateTime.fromMillisecondsSinceEpoch(timestamp * 1000),
    title: 'Classic $n',
    videoUrl: 'https://example.com/$n.mp4',
    thumbnailUrl: 'https://example.com/$n.jpg',
  );
}

void main() {
  group('$VideoFeedBloc adaptive Classics gate', () {
    late _MockVideosRepository videosRepository;
    late _MockFollowRepository followRepository;
    late _MockCuratedListRepository curatedListRepository;
    late StreamController<bool> gate;
    late Completer<HomeFeedResult> firstArchivePage;
    final archiveCursors = <String?>[];
    var sessionReads = 0;

    setUp(() async {
      await CacheSync.init(dao: _FakeCacheDao());
      videosRepository = _MockVideosRepository();
      followRepository = _MockFollowRepository();
      curatedListRepository = _MockCuratedListRepository();
      gate = StreamController<bool>();
      firstArchivePage = Completer<HomeFeedResult>();
      archiveCursors.clear();
      sessionReads = 0;
      when(
        () => followRepository.followingStream,
      ).thenAnswer((_) => const Stream.empty());
      when(() => followRepository.followingPubkeys).thenReturn([]);
      when(
        () => curatedListRepository.subscribedListsStream,
      ).thenAnswer((_) => const Stream.empty());
      when(() => curatedListRepository.subscriptionSnapshot).thenReturn(
        CuratedListSubscriptionSnapshot(lists: const [], isComplete: true),
      );
      when(
        () => curatedListRepository.subscriptionSnapshots,
      ).thenAnswer((_) => const Stream.empty());
      when(() => curatedListRepository.getSubscribedLists()).thenReturn([]);
      when(
        () => curatedListRepository.hasCompleteSubscriptionSnapshot,
      ).thenReturn(true);
      when(
        () => videosRepository.applyContentPreferences(any()),
      ).thenAnswer((i) => i.positionalArguments.single as List<VideoEvent>);
      when(
        () => videosRepository.getClassicVideos(
          cursor: any(named: 'cursor'),
          skipCache: any(named: 'skipCache'),
        ),
      ).thenAnswer((call) {
        final cursor = call.namedArguments[#cursor] as String?;
        archiveCursors.add(cursor);
        if (cursor == null) return firstArchivePage.future;
        return Future.value(HomeFeedResult(videos: [_video(4)]));
      });
    });

    tearDown(() => gate.close());

    VideoFeedBloc buildBloc() => VideoFeedBloc(
      videosRepository: videosRepository,
      followRepository: followRepository,
      curatedListRepository: curatedListRepository,
      createClassicSession: () => ClassicFeedSession(
        loadPage: (_) async {
          sessionReads++;
          return HomeFeedResult(videos: [_video(20)], hasMore: true);
        },
      ),
      adaptiveClassicsEnabledStream: gate.stream,
    );

    Future<VideoFeedBloc> startOnClassics() async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      // The seeded value at cold start, before Keycast has answered.
      gate.add(false);
      bloc.add(const VideoFeedStarted(mode: FeedMode.classic, forceMode: true));
      await pumpEventQueue();
      expect(archiveCursors, [null], reason: 'first archive page in flight');
      return bloc;
    }

    void completeFirstArchivePage() => firstArchivePage.complete(
      HomeFeedResult(
        videos: [_video(1), _video(2), _video(3)],
        paginationCursor: 'archive-2',
        hasMore: true,
      ),
    );

    group('$VideoFeedStarted', () {
      test(
        'keeps paging the archive when the gate opens during the first load',
        () async {
          final bloc = await startOnClassics();

          gate.add(true);
          await pumpEventQueue();
          completeFirstArchivePage();
          await pumpEventQueue();

          expect(bloc.state.status, VideoFeedStatus.success);
          expect(bloc.state.videos.map((v) => v.title), [
            'Classic 1',
            'Classic 2',
            'Classic 3',
          ]);

          bloc.add(const VideoFeedLoadMoreRequested());
          await pumpEventQueue();

          expect(archiveCursors, [null, 'archive-2']);
          expect(sessionReads, isZero);
          expect(bloc.state.videos.last.title, 'Classic 4');
        },
      );
    });

    group('$VideoFeedSourceChanged', () {
      test(
        're-selecting Classics keeps the archive slice and its pagination',
        () async {
          final bloc = await startOnClassics();
          completeFirstArchivePage();
          await pumpEventQueue();
          gate.add(true);
          await pumpEventQueue();

          bloc.add(const VideoFeedSourceChanged(VideoFeedSource.classic()));
          await pumpEventQueue();

          expect(bloc.state.videos, hasLength(3));
          bloc.add(const VideoFeedLoadMoreRequested());
          await pumpEventQueue();

          expect(archiveCursors, [null, 'archive-2']);
          expect(sessionReads, isZero);
          expect(bloc.state.videos, hasLength(4));
        },
      );
    });
  });
}
