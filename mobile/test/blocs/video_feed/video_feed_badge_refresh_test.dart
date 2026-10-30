// ABOUTME: Keeps real badge-pager continuation intact when a refresh fails.
// ABOUTME: Covers both completion orders and unavailable direct-feed fallback.

import 'dart:async';

import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_feed/video_feed_bloc.dart';
import 'package:videos_repository/videos_repository.dart';

class _VideosRepository extends Mock implements VideosRepository {}

class _ApiClient extends Mock implements FunnelcakeApiClient {}

class _FollowRepository extends Mock implements FollowRepository {}

class _ListRepository extends Mock implements CuratedListRepository {}

enum _RefreshTrigger { subscriptions, directFollows, explicit }

void main() {
  for (final trigger in _RefreshTrigger.values) {
    for (final pageBeforeFailure in [true, false]) {
      for (final directFollows in [false, true]) {
        test(
          'failed ${trigger.name} refresh keeps badge pagination consistent: '
          'page finishes first $pageBeforeFailure, direct follows $directFollows',
          () async {
            final videos = _VideosRepository();
            final client = _ApiClient();
            final follows = _FollowRepository();
            final lists = _ListRepository();
            final pendingPage = Completer<RecentVideosResponse>();
            final pageRequested = Completer<void>();
            final badgeRefresh = Completer<Iterable<String>>();
            final refreshRequested = Completer<void>();
            final offsets = <int>[];
            when(
              () => client.getVideosByAuthors(
                authors: any(named: 'authors'),
                limit: any(named: 'limit'),
                offset: any(named: 'offset'),
                before: any(named: 'before'),
              ),
            ).thenAnswer((call) {
              final offset = call.namedArguments[#offset] as int;
              offsets.add(offset);
              if (offset == 25) {
                pageRequested.complete();
                return pendingPage.future;
              }
              return Future.value(_page(offset + 1));
            });
            final pager = BadgeVideoPager(
              client: client,
              authors: ['a' * 64],
              transform: (stats) =>
                  stats.map((video) => video.toVideoEvent()).toList(),
            );
            when(
              () => videos.createBadgeVideoPager(
                any(),
                prioritizeUnseen: true,
              ),
            ).thenReturn(pager);
            var directReads = 0;
            when(
              () => videos.getHomeFeedVideos(
                authors: any(named: 'authors'),
                userPubkey: any(named: 'userPubkey'),
                cursor: any(named: 'cursor'),
              ),
            ).thenAnswer((_) async {
              if (directReads++ > 0) throw Exception('direct feed unavailable');
              return const HomeFeedResult(videos: [], hasMore: false);
            });
            when(() => follows.followingPubkeys).thenReturn(
              directFollows ? ['b' * 64] : [],
            );
            when(() => follows.followingStream).thenAnswer(
              (_) => const Stream.empty(),
            );
            when(() => follows.isFollowingConfirmedByRelay).thenReturn(true);
            when(lists.getSubscribedLists).thenReturn([]);
            when(() => lists.subscribedListsStream).thenAnswer(
              (_) => const Stream.empty(),
            );
            when(() => lists.subscriptionSnapshots).thenAnswer(
              (_) => const Stream.empty(),
            );
            when(() => lists.subscriptionSnapshot).thenReturn(
              CuratedListSubscriptionSnapshot(
                lists: const [],
                isComplete: true,
              ),
            );
            when(() => lists.hasCompleteSubscriptionSnapshot).thenReturn(true);
            var badgeLoads = 0;
            final bloc = VideoFeedBloc(
              videosRepository: videos,
              followRepository: follows,
              curatedListRepository: lists,
              serveCachedHomeFeed: false,
              badgeAuthors: () {
                if (badgeLoads++ == 0) return Future.value(['a' * 64]);
                refreshRequested.complete();
                return badgeRefresh.future;
              },
            );
            addTearDown(bloc.close);
            final firstPage = bloc.stream.firstWhere(
              (state) => state.videos.length == 25,
            );
            bloc.add(const VideoFeedStarted(mode: FeedMode.following));
            await firstPage;
            bloc.add(const VideoFeedActiveIndexChanged(10));
            await pumpEventQueue();
            final watching = bloc.state.videos[bloc.state.currentIndex].id;

            bloc.add(const VideoFeedLoadMoreRequested());
            await pageRequested.future;
            bloc.add(switch (trigger) {
              _RefreshTrigger.subscriptions =>
                const VideoFeedBadgeSubscriptionsChanged(),
              _RefreshTrigger.directFollows => VideoFeedFollowingListChanged(
                directFollows ? ['b' * 64] : [],
              ),
              _RefreshTrigger.explicit => const VideoFeedRefreshRequested(),
            });
            await refreshRequested.future;
            expect(
              bloc.state.isLoadingMore,
              trigger != _RefreshTrigger.explicit,
            );
            if (pageBeforeFailure) {
              pendingPage.complete(_page(26));
              await pumpEventQueue();
            }
            badgeRefresh.completeError(Exception('badge holders unavailable'));
            await pumpEventQueue();
            if (!pageBeforeFailure) {
              pendingPage.complete(_page(26));
              await pumpEventQueue();
            }

            if (trigger == _RefreshTrigger.explicit) {
              expect(bloc.state.status, VideoFeedStatus.failure);
              expect(bloc.state.videos, isEmpty);
              expect(bloc.state.isLoadingMore, isFalse);
              expect(bloc.state.paginationCursor, isNull);
              expect(bloc.state.currentIndex, 0);
              expect(offsets, [0, 25]);
              expect(directReads, directFollows ? 2 : 0);
              return;
            }
            expect(bloc.state.videos.map((video) => video.id), [
              for (var id = 1; id <= 50; id++) _video(id).id,
            ]);
            expect(bloc.state.isLoadingMore, isFalse);
            expect(bloc.state.currentIndex, 10);
            expect(bloc.state.videos[bloc.state.currentIndex].id, watching);
            final thirdPage = bloc.stream.firstWhere(
              (state) => state.videos.length == 75,
            );
            bloc.add(const VideoFeedLoadMoreRequested());
            await thirdPage;
            expect(bloc.state.videos.map((video) => video.id), [
              for (var id = 1; id <= 75; id++) _video(id).id,
            ]);
            expect(offsets, [0, 25, 50]);
            expect(directReads, directFollows ? 2 : 0);
          },
        );
      }
    }
  }
}

RecentVideosResponse _page(int start) => RecentVideosResponse(
  videos: [for (var id = start; id < start + 25; id++) _video(id)],
  serverItemCount: 25,
  hasMore: start < 51,
);

VideoStats _video(int id) => VideoStats(
  id: id.toRadixString(16).padLeft(64, '0'),
  pubkey: 'a' * 64,
  createdAt: DateTime.fromMillisecondsSinceEpoch(
    (10000 - id) * 1000,
    isUtc: true,
  ),
  kind: 34236,
  dTag: 'badge-video-$id',
  title: 'Video $id',
  thumbnail: '',
  videoUrl: 'https://example.com/$id.mp4',
  reactions: 0,
  comments: 0,
  reposts: 0,
  engagementScore: 0,
);
