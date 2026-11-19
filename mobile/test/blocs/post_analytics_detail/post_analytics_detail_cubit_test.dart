// ABOUTME: Tests the post stats cubit: resolving a post by id or address,
// ABOUTME: the honest states around the settle point, and Stop.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/post_analytics_detail/post_analytics_detail_cubit.dart';
import 'package:openvine/features/creator_analytics/creator_analytics_repository.dart';
import 'package:openvine/features/creator_analytics/video_performance.dart';
import 'package:post_live_activity_repository/post_live_activity_repository.dart';

class _MockCreatorAnalyticsRepository extends Mock
    implements CreatorAnalyticsRepository {}

class _MockPostLiveActivityRepository extends Mock
    implements PostLiveActivityRepository {}

const _owner =
    '385c3a6ec0b9d57a4330dbd6284989be5bd00e41c535f9ca39b6ae7c521b81cd';
const _otherOwner =
    '0f0a6ec0b9d57a4330dbd6284989be5bd00e41c535f9ca39b6ae7c521b81cd0';
const _videoId =
    'b1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2';
const _editedId =
    'c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3';
const _dTag = 'post-d-tag';
const _coordinate = '34236:$_owner:$_dTag';

final _postedAt = DateTime.utc(2026, 11, 19, 12);

VideoEvent _video({
  String id = _videoId,
  String pubkey = _owner,
  String? vineId = _dTag,
  DateTime? createdAt,
  int? views,
  int? likes,
  int? comments,
  int? reposts,
}) {
  final created = createdAt ?? _postedAt;
  return VideoEvent(
    id: id,
    pubkey: pubkey,
    createdAt: created.millisecondsSinceEpoch ~/ 1000,
    content: '',
    timestamp: created,
    title: 'My post',
    vineId: vineId,
    rawTags: {if (views != null) 'views': '$views'},
    nostrLikeCount: likes,
    nostrCommentCount: comments,
    nostrRepostCount: reposts,
  );
}

CreatorAnalyticsSnapshot _snapshot(
  List<VideoEvent> videos, {
  Set<AnalyticsDataSource> failedSources = const {},
}) => CreatorAnalyticsSnapshot(
  videos: videos,
  socialCounts: null,
  diagnostics: CreatorAnalyticsDiagnostics(
    totalVideos: videos.length,
    videosWithAnyViews: 0,
    videosMissingViews: videos.length,
    videosHydratedByBulkStats: 0,
    videosHydratedByViewsEndpoint: 0,
    sourcesUsed: const {AnalyticsDataSource.authorVideos},
    failedSources: failedSources,
    fetchedAt: _postedAt,
  ),
);

TypeMatcher<PostAnalyticsDetailState> _state({
  required PostAnalyticsDetailStatus status,
  Object? videoId = anything,
  Object? counts = anything,
  Object? liveActivityRunning = anything,
  Object? postedAt = anything,
}) => isA<PostAnalyticsDetailState>()
    .having((s) => s.status, 'status', status)
    .having((s) => s.performance?.video.id, 'performance video id', videoId)
    .having((s) => s.counts, 'counts', counts)
    .having(
      (s) => s.liveActivityRunning,
      'liveActivityRunning',
      liveActivityRunning,
    )
    .having((s) => s.postedAt, 'postedAt', postedAt);

void main() {
  group(PostAnalyticsDetailCubit, () {
    late _MockCreatorAnalyticsRepository repository;
    late _MockPostLiveActivityRepository liveActivity;
    late DateTime now;

    setUp(() {
      repository = _MockCreatorAnalyticsRepository();
      liveActivity = _MockPostLiveActivityRepository();
      now = _postedAt.add(const Duration(minutes: 30));
    });

    void stubActivity({DateTime? postedAt, bool running = false}) {
      when(
        () => liveActivity.postedAtFor(any()),
      ).thenAnswer((_) async => postedAt);
      when(
        () => liveActivity.isRunningFor(any()),
      ).thenAnswer((_) async => running);
    }

    void stubFetch(
      List<VideoEvent> videos, {
      Set<AnalyticsDataSource>? failed,
    }) {
      when(() => repository.fetchCreatorAnalytics(_owner)).thenAnswer(
        (_) async => _snapshot(videos, failedSources: failed ?? const {}),
      );
    }

    PostAnalyticsDetailCubit buildCubit({
      String? ownerPubkey = _owner,
      String videoId = _videoId,
      String? coordinate = _coordinate,
      VideoPerformance? initialPerformance,
      bool withLiveActivity = true,
    }) => PostAnalyticsDetailCubit(
      repository: repository,
      ownerPubkey: ownerPubkey,
      videoId: videoId,
      coordinate: coordinate,
      initialPerformance: initialPerformance,
      liveActivity: withLiveActivity ? liveActivity : null,
      now: () => now,
    );

    test('starts loading', () {
      expect(
        buildCubit().state.status,
        equals(PostAnalyticsDetailStatus.loading),
      );
    });

    group('warm path', () {
      final warm = VideoPerformance.fromVideo(_video(views: 5, likes: 1));

      blocTest<PostAnalyticsDetailCubit, PostAnalyticsDetailState>(
        'resolves without a fetch and reads the address off the video',
        setUp: () => stubActivity(running: true),
        build: () => buildCubit(coordinate: null, initialPerformance: warm),
        act: (cubit) => cubit.load(),
        expect: () => [
          _state(
            status: PostAnalyticsDetailStatus.ready,
            videoId: _videoId,
            liveActivityRunning: isTrue,
          ).having((s) => s.coordinate, 'coordinate', _coordinate),
        ],
        verify: (_) {
          verifyNever(() => repository.fetchCreatorAnalytics(any()));
          verify(() => liveActivity.isRunningFor(_coordinate)).called(1);
        },
      );

      blocTest<PostAnalyticsDetailCubit, PostAnalyticsDetailState>(
        'stops the activity from the address it read off the video',
        setUp: () {
          stubActivity(running: true);
          when(
            () => liveActivity.stopForPost(any()),
          ).thenAnswer((_) async {});
        },
        build: () => buildCubit(coordinate: null, initialPerformance: warm),
        act: (cubit) async {
          await cubit.load();
          await cubit.stop();
        },
        skip: 1,
        expect: () => [
          _state(
            status: PostAnalyticsDetailStatus.ready,
            liveActivityRunning: isFalse,
          ),
        ],
        verify: (_) {
          verify(() => liveActivity.stopForPost(_coordinate)).called(1);
          verifyNever(() => repository.fetchCreatorAnalytics(any()));
        },
      );
      test(
        'is ready with the performance before the Live Activity answers',
        () async {
          final postedAt = Completer<DateTime?>();
          final running = Completer<bool>();
          when(
            () => liveActivity.postedAtFor(any()),
          ).thenAnswer((_) => postedAt.future);
          when(
            () => liveActivity.isRunningFor(any()),
          ).thenAnswer((_) => running.future);
          final cubit = buildCubit(coordinate: null, initialPerformance: warm);
          addTearDown(cubit.close);
          final emitted = <PostAnalyticsDetailState>[];
          final subscription = cubit.stream.listen(emitted.add);
          addTearDown(subscription.cancel);

          final loading = cubit.load();
          await pumpEventQueue();

          expect(cubit.state.status, PostAnalyticsDetailStatus.ready);
          expect(cubit.state.performance, same(warm));
          expect(cubit.state.liveActivityRunning, isFalse);
          expect(emitted, isEmpty);

          postedAt.complete(null);
          running.complete(true);
          await loading;
          await pumpEventQueue();

          expect(emitted, [
            _state(
              status: PostAnalyticsDetailStatus.ready,
              liveActivityRunning: isTrue,
            ),
          ]);
          verifyNever(() => repository.fetchCreatorAnalytics(any()));
        },
      );
    });

    group('finding the post', () {
      blocTest<PostAnalyticsDetailCubit, PostAnalyticsDetailState>(
        'finds it by id',
        setUp: () {
          stubActivity();
          stubFetch([
            _video(id: _editedId, vineId: 'another', views: 9),
            _video(views: 3),
          ]);
        },
        build: buildCubit,
        act: (cubit) => cubit.load(),
        expect: () => [
          _state(status: PostAnalyticsDetailStatus.ready, videoId: _videoId),
        ],
      );

      blocTest<PostAnalyticsDetailCubit, PostAnalyticsDetailState>(
        'finds an edited post by its address',
        setUp: () {
          stubActivity();
          stubFetch([_video(id: _editedId, views: 3)]);
        },
        build: buildCubit,
        act: (cubit) => cubit.load(),
        expect: () => [
          _state(status: PostAnalyticsDetailStatus.ready, videoId: _editedId),
        ],
      );

      blocTest<PostAnalyticsDetailCubit, PostAnalyticsDetailState>(
        'does not take an address that names another account',
        setUp: () {
          stubActivity();
          stubFetch([_video(id: _editedId, views: 3)]);
        },
        build: () => buildCubit(coordinate: '34236:$_otherOwner:$_dTag'),
        act: (cubit) => cubit.load(),
        expect: () => [
          _state(status: PostAnalyticsDetailStatus.cantFind, videoId: isNull),
        ],
      );

      blocTest<PostAnalyticsDetailCubit, PostAnalyticsDetailState>(
        "takes postedAt from the activity over the video's created_at",
        setUp: () {
          final activityPostedAt = _postedAt.add(const Duration(minutes: 2));
          stubActivity(postedAt: activityPostedAt);
          stubFetch([
            _video(
              views: 3,
              createdAt: _postedAt.subtract(const Duration(hours: 5)),
            ),
          ]);
        },
        build: buildCubit,
        act: (cubit) => cubit.load(),
        expect: () => [
          _state(
            status: PostAnalyticsDetailStatus.ready,
            postedAt: _postedAt.add(const Duration(minutes: 2)),
          ),
        ],
      );

      blocTest<PostAnalyticsDetailCubit, PostAnalyticsDetailState>(
        "falls back to the video's created_at without an activity",
        setUp: () => stubFetch([_video(views: 3)]),
        build: () => buildCubit(withLiveActivity: false),
        act: (cubit) => cubit.load(),
        expect: () => [
          _state(
            status: PostAnalyticsDetailStatus.ready,
            postedAt: _postedAt,
            liveActivityRunning: isFalse,
          ),
        ],
      );
    });

    group('status', () {
      blocTest<PostAnalyticsDetailCubit, PostAnalyticsDetailState>(
        'is onTheirWay when the post is missing before the settle point',
        setUp: () {
          now = _postedAt.add(const Duration(minutes: 3));
          stubActivity(postedAt: _postedAt);
          stubFetch(const []);
        },
        build: buildCubit,
        act: (cubit) => cubit.load(),
        expect: () => [_state(status: PostAnalyticsDetailStatus.onTheirWay)],
      );

      blocTest<PostAnalyticsDetailCubit, PostAnalyticsDetailState>(
        'is cantFind when the post is missing after the settle point',
        setUp: () {
          now = _postedAt.add(const Duration(minutes: 10));
          stubActivity(postedAt: _postedAt);
          stubFetch(const []);
        },
        build: buildCubit,
        act: (cubit) => cubit.load(),
        expect: () => [_state(status: PostAnalyticsDetailStatus.cantFind)],
      );

      blocTest<PostAnalyticsDetailCubit, PostAnalyticsDetailState>(
        'is cantFind when the post is missing and nothing says when it '
        'was posted',
        setUp: () => stubFetch(const []),
        build: () => buildCubit(withLiveActivity: false),
        act: (cubit) => cubit.load(),
        expect: () => [
          _state(status: PostAnalyticsDetailStatus.cantFind, postedAt: isNull),
        ],
      );

      blocTest<PostAnalyticsDetailCubit, PostAnalyticsDetailState>(
        'is nothingYet when every count is a confirmed zero after the settle '
        'point, inside the first hour',
        setUp: () {
          now = _postedAt.add(const Duration(minutes: 14, seconds: 30));
          stubActivity(postedAt: _postedAt);
          stubFetch([_video(views: 0, likes: 0, comments: 0)]);
        },
        build: buildCubit,
        act: (cubit) => cubit.load(),
        expect: () => [
          _state(
            status: PostAnalyticsDetailStatus.nothingYet,
            counts: const PostCounts(views: 0, likes: 0, comments: 0),
          ).having((s) => s.liveMinutes, 'liveMinutes', 14),
        ],
      );

      blocTest<PostAnalyticsDetailCubit, PostAnalyticsDetailState>(
        'is ready with its zeros once the first hour is over',
        setUp: () {
          now = _postedAt.add(const Duration(minutes: 61));
          stubActivity(postedAt: _postedAt);
          stubFetch([_video(views: 0, likes: 0, comments: 0)]);
        },
        build: buildCubit,
        act: (cubit) => cubit.load(),
        expect: () => [
          _state(
            status: PostAnalyticsDetailStatus.ready,
            counts: const PostCounts(views: 0, likes: 0, comments: 0),
          ),
        ],
      );

      blocTest<PostAnalyticsDetailCubit, PostAnalyticsDetailState>(
        'is onTheirWay when the post is found before the settle point with no '
        'count above zero',
        setUp: () {
          now = _postedAt.add(const Duration(minutes: 4));
          stubActivity(postedAt: _postedAt);
          stubFetch([_video(views: 0, likes: 0, comments: 0)]);
        },
        build: buildCubit,
        act: (cubit) => cubit.load(),
        expect: () => [
          _state(
            status: PostAnalyticsDetailStatus.onTheirWay,
            videoId: _videoId,
            counts: const PostCounts(),
          ),
        ],
      );

      blocTest<PostAnalyticsDetailCubit, PostAnalyticsDetailState>(
        'is ready when a count is known and above zero',
        setUp: () {
          stubActivity(postedAt: _postedAt);
          stubFetch([_video(views: 12, likes: 2, comments: 1, reposts: 0)]);
        },
        build: buildCubit,
        act: (cubit) => cubit.load(),
        expect: () => [
          _state(
            status: PostAnalyticsDetailStatus.ready,
            counts: const PostCounts(
              views: 12,
              likes: 2,
              comments: 1,
              reposts: 0,
            ),
          ),
        ],
      );

      blocTest<PostAnalyticsDetailCubit, PostAnalyticsDetailState>(
        'is couldNotLoad when the fetch throws, never cantFind',
        setUp: () {
          stubActivity(postedAt: _postedAt);
          when(() => repository.fetchCreatorAnalytics(_owner)).thenThrow(
            const CreatorAnalyticsLoadException(
              CreatorAnalyticsFailureKind.connectionIssue,
            ),
          );
        },
        build: buildCubit,
        act: (cubit) => cubit.load(),
        expect: () => [_state(status: PostAnalyticsDetailStatus.couldNotLoad)],
        errors: () => [isA<CreatorAnalyticsLoadException>()],
      );

      blocTest<PostAnalyticsDetailCubit, PostAnalyticsDetailState>(
        'is couldNotLoad when an unexpected error escapes the fetch',
        setUp: () {
          stubActivity(postedAt: _postedAt);
          when(
            () => repository.fetchCreatorAnalytics(_owner),
          ).thenThrow(StateError('boom'));
        },
        build: buildCubit,
        act: (cubit) => cubit.load(),
        expect: () => [_state(status: PostAnalyticsDetailStatus.couldNotLoad)],
        errors: () => [isA<Exception>()],
      );

      blocTest<PostAnalyticsDetailCubit, PostAnalyticsDetailState>(
        'is couldNotLoad with no signed-in owner to load for',
        build: () => buildCubit(ownerPubkey: null),
        act: (cubit) => cubit.load(),
        expect: () => [_state(status: PostAnalyticsDetailStatus.couldNotLoad)],
        verify: (_) {
          verifyNever(() => repository.fetchCreatorAnalytics(any()));
        },
      );
    });

    group('counts', () {
      blocTest<PostAnalyticsDetailCubit, PostAnalyticsDetailState>(
        'leave an unknown count unknown instead of reading it as zero',
        setUp: () {
          stubActivity(postedAt: _postedAt);
          stubFetch([_video(views: 0, comments: 0)]);
        },
        build: buildCubit,
        act: (cubit) => cubit.load(),
        expect: () => [
          _state(
            status: PostAnalyticsDetailStatus.ready,
            counts: const PostCounts(views: 0, comments: 0),
          ),
        ],
      );

      blocTest<PostAnalyticsDetailCubit, PostAnalyticsDetailState>(
        'leave engagement unknown when bulk stats failed',
        setUp: () {
          stubActivity(postedAt: _postedAt);
          stubFetch(
            [_video(views: 7, likes: 3, comments: 2, reposts: 1)],
            failed: {AnalyticsDataSource.bulkVideoStats},
          );
        },
        build: buildCubit,
        act: (cubit) => cubit.load(),
        expect: () => [
          _state(
            status: PostAnalyticsDetailStatus.ready,
            counts: const PostCounts(views: 7),
          ),
        ],
      );

      blocTest<PostAnalyticsDetailCubit, PostAnalyticsDetailState>(
        'read a zero before the settle point as unknown',
        setUp: () {
          now = _postedAt.add(const Duration(minutes: 5));
          stubActivity(postedAt: _postedAt);
          stubFetch([_video(views: 4, likes: 0, comments: 0, reposts: 0)]);
        },
        build: buildCubit,
        act: (cubit) => cubit.load(),
        expect: () => [
          _state(
            status: PostAnalyticsDetailStatus.ready,
            counts: const PostCounts(views: 4),
          ),
        ],
      );
    });

    group('settle point', () {
      test('reloads once at the settle point', () {
        fakeAsync((async) {
          final start = _postedAt.add(const Duration(minutes: 3));
          now = start;
          final cubit = PostAnalyticsDetailCubit(
            repository: repository,
            ownerPubkey: _owner,
            videoId: _videoId,
            coordinate: _coordinate,
            liveActivity: liveActivity,
            now: () => start.add(async.elapsed),
          );
          stubActivity(postedAt: _postedAt);
          stubFetch(const []);

          unawaited(cubit.load());
          async.flushMicrotasks();
          expect(cubit.state.status, PostAnalyticsDetailStatus.onTheirWay);
          verify(() => repository.fetchCreatorAnalytics(_owner)).called(1);

          stubFetch([_video(views: 2)]);
          async
            ..elapse(const Duration(minutes: 7) - const Duration(seconds: 1))
            ..flushMicrotasks();
          verifyNever(() => repository.fetchCreatorAnalytics(_owner));

          async
            ..elapse(const Duration(seconds: 1))
            ..flushMicrotasks();
          verify(() => repository.fetchCreatorAnalytics(_owner)).called(1);
          expect(cubit.state.status, PostAnalyticsDetailStatus.ready);
          expect(cubit.state.performance?.video.id, _videoId);

          async
            ..elapse(const Duration(hours: 1))
            ..flushMicrotasks();
          verifyNever(() => repository.fetchCreatorAnalytics(_owner));

          unawaited(cubit.close());
          async.flushMicrotasks();
        });
      });

      test('cancels the reload when closed', () {
        fakeAsync((async) {
          final start = _postedAt.add(const Duration(minutes: 3));
          final cubit = PostAnalyticsDetailCubit(
            repository: repository,
            ownerPubkey: _owner,
            videoId: _videoId,
            coordinate: _coordinate,
            liveActivity: liveActivity,
            now: () => start.add(async.elapsed),
          );
          stubActivity(postedAt: _postedAt);
          stubFetch(const []);

          unawaited(cubit.load());
          async.flushMicrotasks();
          expect(cubit.state.status, PostAnalyticsDetailStatus.onTheirWay);
          verify(() => repository.fetchCreatorAnalytics(_owner)).called(1);

          unawaited(cubit.close());
          async
            ..flushMicrotasks()
            ..elapse(const Duration(minutes: 10))
            ..flushMicrotasks();

          verifyNever(() => repository.fetchCreatorAnalytics(_owner));
          expect(async.pendingTimers, isEmpty);
        });
      });
    });

    group('retry', () {
      blocTest<PostAnalyticsDetailCubit, PostAnalyticsDetailState>(
        'reloads after a failure',
        setUp: () {
          stubActivity(postedAt: _postedAt);
          var calls = 0;
          when(() => repository.fetchCreatorAnalytics(_owner)).thenAnswer((
            _,
          ) async {
            calls++;
            if (calls == 1) {
              throw const CreatorAnalyticsLoadException(
                CreatorAnalyticsFailureKind.serverUnavailable,
              );
            }
            return _snapshot([_video(views: 3)]);
          });
        },
        build: buildCubit,
        act: (cubit) async {
          await cubit.load();
          await cubit.retry();
        },
        expect: () => [
          _state(status: PostAnalyticsDetailStatus.couldNotLoad),
          _state(status: PostAnalyticsDetailStatus.loading),
          _state(status: PostAnalyticsDetailStatus.ready, videoId: _videoId),
        ],
        errors: () => [isA<CreatorAnalyticsLoadException>()],
      );
    });

    group('stop', () {
      blocTest<PostAnalyticsDetailCubit, PostAnalyticsDetailState>(
        'ends the activity for the post and hides itself',
        setUp: () {
          stubActivity(postedAt: _postedAt, running: true);
          stubFetch(const []);
          when(
            () => liveActivity.stopForPost(any()),
          ).thenAnswer((_) async {});
        },
        build: buildCubit,
        act: (cubit) async {
          await cubit.load();
          await cubit.stop();
        },
        expect: () => [
          _state(
            status: PostAnalyticsDetailStatus.cantFind,
            liveActivityRunning: isTrue,
          ),
          _state(
            status: PostAnalyticsDetailStatus.cantFind,
            liveActivityRunning: isFalse,
          ),
        ],
        verify: (_) {
          verify(() => liveActivity.stopForPost(_coordinate)).called(1);
        },
      );

      blocTest<PostAnalyticsDetailCubit, PostAnalyticsDetailState>(
        'keeps the control when ending the activity fails',
        setUp: () {
          stubActivity(postedAt: _postedAt, running: true);
          stubFetch(const []);
          when(
            () => liveActivity.stopForPost(any()),
          ).thenThrow(Exception('platform'));
        },
        build: buildCubit,
        act: (cubit) async {
          await cubit.load();
          await cubit.stop();
        },
        expect: () => [
          _state(
            status: PostAnalyticsDetailStatus.cantFind,
            liveActivityRunning: isTrue,
          ),
        ],
        errors: () => [isA<Exception>()],
      );
    });
  });
}
