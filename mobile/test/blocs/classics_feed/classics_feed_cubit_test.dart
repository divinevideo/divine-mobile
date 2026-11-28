import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/classics_feed/classics_feed_cubit.dart';
import 'package:videos_repository/videos_repository.dart';

VideoEvent _video(int n) => VideoEvent(
  id: n.toRadixString(16).padLeft(64, '0'),
  pubkey: (n + 100).toRadixString(16).padLeft(64, '0'),
  createdAt: n,
  content: '',
  timestamp: DateTime.fromMillisecondsSinceEpoch(n * 1000),
  videoUrl: 'https://example.com/$n.mp4',
);

void main() {
  group('ClassicsFeedCubit', () {
    test(
      'closing stops new feedback reads before stream cleanup settles',
      () async {
        final feedback = StreamController<ClassicFeedFeedback>.broadcast(
          sync: true,
        );
        addTearDown(feedback.close);
        var reads = 0;
        final session = ClassicFeedSession(
          initialVideos: [_video(1)],
          feedback: feedback.stream,
          loadPage: (_) async {
            reads++;
            return HomeFeedResult(
              videos: [_video(2)],
              hasMore: true,
              recommendationPageCount: 1,
              paginationCursor: 'next',
            );
          },
        );
        final cubit = ClassicsFeedCubit(session: session);
        await session.settled;
        final closing = cubit.close();
        feedback.add(
          ClassicFeedInteraction(
            videoId: _video(1).id,
            signal: ClassicFeedSignal.positive,
          ),
        );
        await closing;
        expect(reads, 1);
        expect(cubit.isClosed, isTrue);
      },
    );

    test(
      'revokePersonalization moves the rest of the queue to the archive',
      () async {
        final requests = <ClassicRecommendationsRequest>[];
        final session = ClassicFeedSession(
          initialVideos: [_video(1)],
          loadPage: (request) async {
            requests.add(request);
            return requests.length == 1
                ? HomeFeedResult(
                    videos: [_video(2), _video(3)],
                    hasMore: true,
                    recommendationPageCount: 1,
                    paginationCursor: 'adaptive',
                  )
                : HomeFeedResult(videos: [_video(9)], hasMore: false);
          },
        );
        final cubit = ClassicsFeedCubit(session: session);
        addTearDown(cubit.close);
        await session.settled;

        cubit.revokePersonalization();
        await session.settled;
        await pumpEventQueue();

        expect(cubit.state.videos, [_video(1), _video(9)]);
        expect(requests.last.cursor, isNull);
        expect(requests.last.anchorVideoId, isNull);
      },
    );

    test(
      'a selected classic plays before its independent recommendations arrive',
      () async {
        final pending = Completer<HomeFeedResult>();
        final session = ClassicFeedSession(
          initialVideos: [_video(1)],
          loadPage: (_) => pending.future,
        );
        final cubit = ClassicsFeedCubit(session: session);
        addTearDown(cubit.close);
        expect(await cubit.videos.first, [_video(1)]);
        pending.complete(
          HomeFeedResult(
            videos: [_video(2), _video(3)],
            paginationCursor: 'next',
            hasMore: true,
            recommendationPageCount: 1,
          ),
        );
        await session.settled;
        expect(
          (await cubit.videos.first).map((v) => v.id),
          [1, 2, 3].map((n) => n.toRadixString(16).padLeft(64, '0')),
        );
      },
    );

    test(
      'route disposal disposes its session so a pending read is ignored',
      () async {
        final pending = Completer<HomeFeedResult>();
        final session = ClassicFeedSession(
          initialVideos: [_video(1)],
          loadPage: (_) => pending.future,
        );
        final cubit = ClassicsFeedCubit(session: session);
        await cubit.close();
        pending.complete(HomeFeedResult(videos: [_video(2)]));
        await session.settled;
        expect(cubit.isClosed, isTrue);
        // The cubit's own state is frozen by close(); the session's shows
        // whether the late read still landed.
        expect(session.state.videos, [_video(1)]);
      },
    );
  });
}
