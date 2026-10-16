import 'dart:async';

import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:hashtag_subscription_repository/hashtag_subscription_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_feed/video_feed_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:videos_repository/videos_repository.dart';

import '../../helpers/hashtag_subscription_store.dart';
import '../../test_data/video_test_data.dart';

class Videos extends Mock implements VideosRepository {}

class Follows extends Mock implements FollowRepository {}

class Lists extends Mock implements CuratedListRepository {}

class DelayedPreferences extends Mock implements SharedPreferences {}

void main() {
  group('hashtag_source_test', () {
    late Videos videos;
    late Follows follows;
    late Lists lists;
    late HashtagSubscriptionRepository tags;
    late VideoFeedBloc bloc;
    late SharedPreferences prefs;
    final key = 'a' * 64;
    const source = VideoFeedSource.subscribedHashtag(
      hashtag: 'lnic',
      displayTag: 'LNIC',
    );
    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'selected_feed_mode_$key': 'hashtag:lnic',
      });
      prefs = await SharedPreferences.getInstance();
      tags = HashtagSubscriptionRepository(store: TestStore());
      await tags.follow('LNIC');
      videos = Videos();
      follows = Follows();
      lists = Lists();
      when(() => follows.followingPubkeys).thenReturn([]);
      when(() => follows.followingStream)
          .thenAnswer((_) => const Stream.empty());
      when(lists.getSubscribedLists).thenReturn([]);
      when(() => lists.subscribedListsStream)
          .thenAnswer((_) => const Stream.empty());
      when(() => videos.getHashtagFeedVideos(hashtag: any(named: 'hashtag')))
          .thenAnswer((_) async => const HashtagFeedVideosResult.success([]));
      when(
        () => videos.getRecommendedVideos(
          userPubkey: any(named: 'userPubkey'),
          until: any(named: 'until'),
          skipCache: any(named: 'skipCache'),
          revalidate: any(named: 'revalidate'),
        ),
      ).thenAnswer(
        (_) async => const HomeFeedResult(videos: [], hasMore: false),
      );
      bloc = VideoFeedBloc(
        videosRepository: videos,
        followRepository: follows,
        curatedListRepository: lists,
        hashtagSubscriptionRepository: tags,
        sharedPreferences: prefs,
        userPubkey: key,
        serveCachedHomeFeed: false,
      );
    });
    tearDown(() async {
      await bloc.close();
      await tags.dispose();
    });

    Future<void> start() async {
      final loaded = bloc.stream.firstWhere(
        (s) => s.status != VideoFeedStatus.loading,
      );
      bloc.add(const VideoFeedStarted());
      await loaded;
      // Let onStarted install its repository observers before a mutation.
      await pumpEventQueue();
    }

    test('restores followed hashtag and marks first page exhausted', () async {
      await start();
      expect(bloc.state.source, source);
      expect(bloc.state.followedHashtags.single.displayTag, 'LNIC');
      expect(bloc.state.hasMore, isFalse);
      bloc.add(const VideoFeedLoadMoreRequested());
      await pumpEventQueue();
      verify(() => videos.getHashtagFeedVideos(hashtag: 'lnic')).called(1);
    });
    test('unfollow active tag falls back and persists For You', () async {
      await start();
      final fallback = bloc.stream.firstWhere(
        (s) =>
            s.source.type == VideoFeedSourceType.forYou &&
            s.status == VideoFeedStatus.success,
      );
      await tags.unfollow('lnic');
      await fallback;
      expect(prefs.getString('selected_feed_mode_$key'), 'forYou');
    });
    test('removing another tag does not replace selected source', () async {
      await tags.follow('other');
      await start();
      final changed = bloc.stream.firstWhere(
        (s) => s.followedHashtags.length == 1,
      );
      await tags.unfollow('other');
      await changed;
      expect(bloc.state.source, source);
    });
    test('refresh waits for network and retains videos on failure', () async {
      final video = createTestVideoEvent();
      when(() => videos.getHashtagFeedVideos(hashtag: 'lnic'))
          .thenAnswer((_) async => HashtagFeedVideosResult.success([video]));
      await start();
      final response = Completer<HashtagFeedVideosResult>();
      when(() => videos.getHashtagFeedVideos(hashtag: 'lnic'))
          .thenAnswer((_) => response.future);
      final refreshing = bloc.stream.firstWhere(
        (s) => s.status == VideoFeedStatus.loading,
      );
      bloc.add(const VideoFeedRefreshRequested());
      final pending = await refreshing.timeout(const Duration(seconds: 2));
      expect(pending.videos.single.id, video.id);
      final failed = bloc.stream.firstWhere(
        (s) => s.status == VideoFeedStatus.failure,
      );
      response.complete(const HashtagFeedVideosResult.failure());
      final failure = await failed;
      expect(failure.videos.single.id, video.id);
      expect(failure.error, VideoFeedError.loadFailed);
      verify(() => videos.clearInMemoryFeedCache(key: 'hashtag:lnic'))
          .called(1);
    });

    test(
      'unfollow while source persistence waits cancels that selection',
      () async {
        await bloc.close();
        final preferences = DelayedPreferences();
        var saved = 'forYou';
        final writing = Completer<void>();
        final release = Completer<void>();
        when(() => preferences.getString(any())).thenAnswer((_) => saved);
        when(() => preferences.remove(any())).thenAnswer((_) async => true);
        when(() => preferences.setString(any(), any()))
            .thenAnswer((call) async {
              final value = call.positionalArguments[1] as String;
              if (value == 'hashtag:lnic') {
                writing.complete();
                await release.future;
              }
              saved = value;
              return true;
            });
        bloc = VideoFeedBloc(
          videosRepository: videos,
          followRepository: follows,
          curatedListRepository: lists,
          hashtagSubscriptionRepository: tags,
          sharedPreferences: preferences,
          userPubkey: key,
          serveCachedHomeFeed: false,
        );
        await start();
        bloc.add(const VideoFeedSourceChanged(source));
        await writing.future;
        final removed = bloc.stream.firstWhere(
          (s) => s.followedHashtags.isEmpty,
        );
        await tags.unfollow('lnic');
        await removed;
        release.complete();
        await pumpEventQueue();
        expect(bloc.state.source.type, VideoFeedSourceType.forYou);
        expect(saved, 'forYou');
      },
    );

    test('failed hashtag fetch is failure, not an empty success', () async {
      when(() => videos.getHashtagFeedVideos(hashtag: 'lnic'))
          .thenAnswer((_) async => const HashtagFeedVideosResult.failure());
      await start();
      expect(bloc.state.status, VideoFeedStatus.failure);
    });
    test('unfollow during initial fetch invalidates its completion', () async {
      final response = Completer<HashtagFeedVideosResult>();
      when(() => videos.getHashtagFeedVideos(hashtag: 'lnic'))
          .thenAnswer((_) => response.future);
      bloc.add(const VideoFeedStarted());
      await bloc.stream.firstWhere((s) => s.source == source);
      final fallback = bloc.stream.firstWhere(
        (s) =>
            s.source.type == VideoFeedSourceType.forYou &&
            s.status == VideoFeedStatus.success,
      );
      await tags.unfollow('lnic');
      await fallback;
      response.complete(const HashtagFeedVideosResult.success([]));
      await pumpEventQueue();
      expect(bloc.state.source.type, VideoFeedSourceType.forYou);
    });

    test(
      'cancelled selection does not discard the current hashtag load',
      () async {
        await bloc.close();
        await tags.follow('other');
        final preferences = DelayedPreferences();
        var saved = 'hashtag:lnic';
        final writing = Completer<void>();
        final release = Completer<void>();
        when(() => preferences.getString(any())).thenAnswer((_) => saved);
        when(() => preferences.remove(any())).thenAnswer((_) async => true);
        when(() => preferences.setString(any(), any()))
            .thenAnswer((call) async {
              final value = call.positionalArguments[1] as String;
              if (value == 'hashtag:other') {
                writing.complete();
                await release.future;
              }
              saved = value;
              return true;
            });
        final requested = Completer<void>();
        final response = Completer<HashtagFeedVideosResult>();
        when(() => videos.getHashtagFeedVideos(hashtag: 'lnic'))
            .thenAnswer((_) {
              requested.complete();
              return response.future;
            });
        bloc = VideoFeedBloc(
          videosRepository: videos,
          followRepository: follows,
          curatedListRepository: lists,
          hashtagSubscriptionRepository: tags,
          sharedPreferences: preferences,
          userPubkey: key,
          serveCachedHomeFeed: false,
        );
        bloc.add(const VideoFeedStarted());
        await requested.future;
        bloc.add(
          const VideoFeedSourceChanged(
            VideoFeedSource.subscribedHashtag(
              hashtag: 'other',
              displayTag: 'other',
            ),
          ),
        );
        await writing.future;
        final removed = bloc.stream.firstWhere(
          (s) => s.followedHashtags.length == 1,
        );
        await tags.unfollow('other');
        await removed;
        release.complete();
        await pumpEventQueue();
        expect(bloc.state.source, source);
        final video = createTestVideoEvent(id: '3' * 64);
        response.complete(HashtagFeedVideosResult.success([video]));
        await pumpEventQueue();
        expect(bloc.state.status, VideoFeedStatus.success);
        expect(bloc.state.videos.single.id, video.id);
      },
    );

    for (final staleResultFails in [false, true]) {
      test(
        'revisiting a hashtag ignores an earlier ${staleResultFails ? 'failed' : 'successful'} load',
        () async {
          final firstResponse = Completer<HashtagFeedVideosResult>();
          final firstRequested = Completer<void>();
          final oldVideo = createTestVideoEvent(id: '1' * 64);
          final freshVideo = createTestVideoEvent(id: '2' * 64);
          var requests = 0;
          when(() => videos.getHashtagFeedVideos(hashtag: 'lnic')).thenAnswer((
            _,
          ) {
            if (requests++ == 0) {
              firstRequested.complete();
              return firstResponse.future;
            }
            return Future.value(HashtagFeedVideosResult.success([freshVideo]));
          });
          bloc.add(const VideoFeedStarted());
          await firstRequested.future;
          final switched = bloc.stream.firstWhere(
            (s) =>
                s.source.type == VideoFeedSourceType.forYou &&
                s.status == VideoFeedStatus.success,
          );
          bloc.add(const VideoFeedSourceChanged(VideoFeedSource.forYou()));
          await switched;
          final revisited = bloc.stream.firstWhere(
            (s) => s.source == source && s.status == VideoFeedStatus.success,
          );
          bloc.add(const VideoFeedSourceChanged(source));
          await revisited;
          expect(bloc.state.videos.single.id, freshVideo.id);

          firstResponse.complete(
            staleResultFails
                ? const HashtagFeedVideosResult.failure()
                : HashtagFeedVideosResult.success([oldVideo]),
          );
          await pumpEventQueue();
          expect(bloc.state.videos.single.id, freshVideo.id);
          expect(bloc.state.status, VideoFeedStatus.success);
        },
      );
    }
  });
}
