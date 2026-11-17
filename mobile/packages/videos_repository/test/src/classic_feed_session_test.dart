import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:videos_repository/videos_repository.dart';

String _id(int value) => value.toRadixString(16).padLeft(64, '0');

VideoEvent _video(int value) => VideoEvent(
  id: _id(value),
  pubkey: _id(1000 + value),
  createdAt: 1,
  content: '',
  timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
  videoUrl: 'https://example.com/$value.mp4',
  rawTags: const {'platform': 'vine'},
);

HomeFeedResult _page(List<int> ids, {String? cursor = 'next'}) =>
    HomeFeedResult(
      videos: ids.map(_video).toList(),
      recommendationPageCount: 1,
      paginationCursor: cursor,
      hasMore: cursor != null,
    );

void main() {
  group('ClassicFeedSession', () {
    test(
      'one-shot sweep filters preserve identity and allow later recovery',
      () async {
        final session = ClassicFeedSession(
          loadPage: (_) async => _page([1, 2, 3, 4]),
        );
        addTearDown(session.dispose);
        await session.loadInitial();
        session.activate(2);
        await session.settled;
        session.reapplyFilters(keep: (video) => video.id != _id(1));
        expect(
          session.state.videos.map((video) => video.id),
          [2, 3, 4].map(_id),
        );
        expect(session.state.currentIndex, 1);
        await session.loadInitial(refresh: true);
        expect(
          session.state.videos.map((video) => video.id),
          [1, 2, 3, 4].map(_id),
        );
      },
    );

    test(
      'resuming a retained queue reapplies the current live filter',
      () async {
        var hidden = false;
        var reads = 0;
        final session = ClassicFeedSession(
          filter: (items) =>
              items.where((v) => !hidden || v.id != _id(1)).toList(),
          loadPage: (_) async {
            reads++;
            return _page([1, 2, 3]);
          },
        );
        addTearDown(session.dispose);
        await session.loadInitial();
        session.setActive(active: false);
        hidden = true;
        final resumed = await session.loadInitial();
        expect(resumed.videos.map((video) => video.id), [2, 3].map(_id));
        expect(session.state.videos, resumed.videos);
        expect(reads, 1);
      },
    );

    test(
      'pagination appends and publishes loading without replacing the queue',
      () async {
        final requests = <ClassicRecommendationsRequest>[];
        final session = ClassicFeedSession(
          loadPage: (request) async {
            requests.add(request);
            return requests.length == 1
                ? _page([1, 2])
                : _page([3], cursor: null);
          },
        );
        addTearDown(session.dispose);
        final states = <ClassicFeedSessionState>[];
        final subscription = session.stream.distinct().listen(states.add);
        addTearDown(subscription.cancel);
        await session.loadMore();
        await pumpEventQueue();
        await session.loadMore();
        await pumpEventQueue();
        expect(session.state.videos.map((v) => v.id), [1, 2, 3].map(_id));
        expect(states.any((s) => s.isLoading && s.videos.length == 2), isTrue);
        expect(states.last.isLoading, isFalse);
        expect(states.last.hasMore, isFalse);
        expect(requests.last.cursor, 'next');
        expect(requests.last.seed, requests.first.seed);
        expect((await session.loadMore()).videos, isEmpty);
        expect(requests, hasLength(2));
      },
    );

    test(
      'manual refresh supersedes pending adaptation and resets reached history',
      () async {
        final pending = Completer<HomeFeedResult>();
        final requests = <ClassicRecommendationsRequest>[];
        final session = ClassicFeedSession(
          loadPage: (request) async {
            requests.add(request);
            return switch (requests.length) {
              1 => _page([1, 2, 3, 4, 5]),
              2 => pending.future,
              3 => _page([8, 9, 10, 11]),
              _ => _page([12]),
            };
          },
        );
        addTearDown(session.dispose);
        await session.loadInitial();
        session
          ..recordInteraction(
            ClassicFeedInteraction(
              videoId: _id(1),
              signal: ClassicFeedSignal.positive,
            ),
          )
          ..activate(3);
        final refresh = session.loadInitial(refresh: true);
        pending.complete(_page([6, 7]));
        await refresh;
        expect(requests, hasLength(3));
        expect(requests.last.seed, isNot(requests.first.seed));
        expect(requests.last.cursor, isNull);
        expect(requests.last.recentInteractions, isEmpty);
        expect(requests.last.recentVideoIds, isEmpty);
        expect(session.state.videos.map((v) => v.id), [8, 9, 10, 11].map(_id));
        expect(session.state.currentIndex, 0);
        session.activate(1);
        await session.settled;
        expect(session.state.videos.map((v) => v.id), [8, 9, 10, 12].map(_id));
      },
    );

    test('confirmed feedback and undo flow through the local stream', () async {
      final feedback = StreamController<ClassicFeedFeedback>.broadcast(
        sync: true,
      );
      addTearDown(feedback.close);
      final requests = <ClassicRecommendationsRequest>[];
      final session = ClassicFeedSession(
        feedback: feedback.stream,
        loadPage: (request) async {
          requests.add(request);
          return _page([1, 2, 3]);
        },
      );
      addTearDown(session.dispose);
      await session.loadInitial();
      feedback.add(
        ClassicFeedInteraction(
          videoId: _id(1),
          signal: ClassicFeedSignal.positive,
        ),
      );
      await session.settled;
      expect(
        requests.last.recentInteractions.single.signal,
        ClassicFeedSignal.positive,
      );
      feedback.add(ClassicFeedInteractionRetracted(videoId: _id(1)));
      await session.settled;
      expect(requests, hasLength(3));
      expect(requests.last.recentInteractions, isEmpty);
    });

    test(
      'partial playback cannot erase a replay or deliberate action',
      () async {
        final requests = <ClassicRecommendationsRequest>[];
        final session = ClassicFeedSession(
          loadPage: (request) async {
            requests.add(request);
            return _page([1, 2, 3]);
          },
        );
        addTearDown(session.dispose);
        await session.loadInitial();
        for (final signal in [
          ClassicFeedSignal.completed,
          ClassicFeedSignal.skip,
          ClassicFeedSignal.replay,
          ClassicFeedSignal.completed,
          ClassicFeedSignal.positive,
          ClassicFeedSignal.replay,
          ClassicFeedSignal.less,
          ClassicFeedSignal.completed,
        ]) {
          session.recordInteraction(
            ClassicFeedInteraction(videoId: _id(1), signal: signal),
          );
          await session.settled;
        }
        expect(
          requests.skip(1).map((r) => r.recentInteractions.single.signal),
          [
            ClassicFeedSignal.completed,
            ClassicFeedSignal.replay,
            ClassicFeedSignal.positive,
            ClassicFeedSignal.less,
          ],
        );
      },
    );

    test(
      'removing the active video clamps identity and permits an empty queue',
      () async {
        final removed = StreamController<String>.broadcast(sync: true);
        addTearDown(removed.close);
        final session = ClassicFeedSession(
          removedVideoIds: removed.stream,
          loadPage: (_) async => _page([1, 2, 3]),
        );
        addTearDown(session.dispose);
        await session.loadInitial();
        session.activate(2);
        await session.settled;
        removed.add(_id(3));
        expect(session.state.videos.map((v) => v.id), [1, 2].map(_id));
        expect(session.state.videos[session.state.currentIndex].id, _id(2));
        removed
          ..add(_id(1))
          ..add(_id(2));
        expect(session.state.videos, isEmpty);
        expect(session.state.currentIndex, 0);
      },
    );

    test(
      'adapts the tail without moving history, current or prepared next',
      () async {
        final requests = <ClassicRecommendationsRequest>[];
        final session = ClassicFeedSession(
          loadPage: (request) async {
            requests.add(request);
            return requests.length == 1
                ? _page([1, 2, 3, 4, 5])
                : _page([6, 7]);
          },
        );
        addTearDown(session.dispose);
        await session.loadInitial();
        session.activate(1);
        await session.settled;

        expect(session.state.videos.map((v) => v.id), [1, 2, 3, 6, 7].map(_id));
        expect(session.state.currentIndex, 1);
        expect(requests.last.cursor, 'next');
        expect(requests.last.recentVideoIds, [_id(1), _id(2)]);
      },
    );

    test(
      'a backwards swipe cannot replace previously reached videos',
      () async {
        final pending = Completer<HomeFeedResult>();
        var calls = 0;
        final session = ClassicFeedSession(
          loadPage: (_) async =>
              ++calls == 1 ? _page([1, 2, 3, 4, 5, 6]) : pending.future,
        );
        addTearDown(session.dispose);
        await session.loadInitial();
        session
          ..activate(3)
          ..activate(1);
        pending.complete(_page([7, 8]));
        await session.settled;

        expect(
          session.state.videos.take(5).map((v) => v.id),
          [1, 2, 3, 4, 5].map(_id),
        );
        expect(session.state.currentIndex, 1);
      },
    );

    test('coalesces feedback while one request is in flight', () async {
      final pending = Completer<HomeFeedResult>();
      final requests = <ClassicRecommendationsRequest>[];
      final session = ClassicFeedSession(
        loadPage: (request) async {
          requests.add(request);
          return switch (requests.length) {
            1 => _page([1, 2, 3, 4]),
            2 => pending.future,
            _ => _page([7, 8]),
          };
        },
      );
      addTearDown(session.dispose);
      await session.loadInitial();
      session
        ..recordInteraction(
          ClassicFeedInteraction(
            videoId: _id(1),
            signal: ClassicFeedSignal.completed,
          ),
        )
        ..recordInteraction(
          ClassicFeedInteraction(
            videoId: _id(1),
            signal: ClassicFeedSignal.positive,
          ),
        )
        ..recordInteraction(
          ClassicFeedInteraction(
            videoId: _id(2),
            signal: ClassicFeedSignal.skip,
          ),
        );
      expect(requests, hasLength(2));
      pending.complete(_page([5, 6]));
      await session.settled;

      expect(requests, hasLength(3));
      expect(requests.last.recentInteractions.map((v) => v.signal), [
        ClassicFeedSignal.positive,
        ClassicFeedSignal.skip,
      ]);
    });

    test(
      'failed or empty adaptation preserves the playable tail and retries',
      () async {
        var calls = 0;
        final session = ClassicFeedSession(
          loadPage: (_) async {
            calls++;
            if (calls == 1) return _page([1, 2, 3, 4]);
            if (calls == 2) throw StateError('offline');
            return _page([]);
          },
        );
        addTearDown(session.dispose);
        await session.loadInitial();
        session.activate(1);
        await session.settled;
        expect(session.state.videos, hasLength(4));
        session.recordInteraction(
          ClassicFeedInteraction(
            videoId: _id(2),
            signal: ClassicFeedSignal.positive,
          ),
        );
        await session.settled;
        expect(calls, 3);
        expect(session.state.videos, hasLength(4));
      },
    );

    test(
      'privacy boundary clears context and discards an old response',
      () async {
        final privacy = StreamController<void>.broadcast(sync: true);
        addTearDown(privacy.close);
        var allowed = true;
        final pending = Completer<HomeFeedResult>();
        final requests = <ClassicRecommendationsRequest>[];
        final session = ClassicFeedSession(
          canPersonalize: () => allowed,
          privacyChanges: privacy.stream,
          loadPage: (request) async {
            requests.add(request);
            return switch (requests.length) {
              1 => _page([1, 2, 3, 4]),
              2 => pending.future,
              _ => _page([7, 8]),
            };
          },
        );
        addTearDown(session.dispose);
        await session.loadInitial();
        final oldSeed = requests.single.seed;
        session.recordInteraction(
          ClassicFeedInteraction(
            videoId: _id(1),
            signal: ClassicFeedSignal.positive,
          ),
        );
        allowed = false;
        privacy.add(null);
        pending.complete(_page([5, 6]));
        await session.settled;

        expect(session.state.videos.map((v) => v.id), isNot(contains(_id(5))));
        expect(requests.last.seed, isNot(oldSeed));
        expect(requests.last.recentInteractions, isEmpty);
        expect(requests.last.recentVideoIds, isEmpty);
        expect(requests.last.anchorVideoId, isNull);
      },
    );

    test(
      'separate sessions do not share queues, cursors or selected anchors',
      () async {
        final first = ClassicFeedSession(
          initialVideos: [_video(1)],
          loadPage: (_) async => _page([3, 4]),
        );
        final second = ClassicFeedSession(
          initialVideos: [_video(2)],
          loadPage: (request) async {
            expect(request.anchorVideoId, _id(2));
            expect(request.cursor, isNull);
            return _page([5, 6]);
          },
        );
        addTearDown(first.dispose);
        addTearDown(second.dispose);
        await first.loadInitial();
        await second.loadInitial();
        expect(first.state.videos.map((v) => v.id), [1, 3, 4].map(_id));
        expect(second.state.videos.map((v) => v.id), [2, 5, 6].map(_id));
      },
    );

    test('disposal suppresses late results and further feedback', () async {
      final pending = Completer<HomeFeedResult>();
      final session = ClassicFeedSession(loadPage: (_) => pending.future);
      final initial = session.loadInitial();
      await session.dispose();
      pending.complete(_page([1, 2]));
      await initial;
      expect(session.state.videos, isEmpty);
    });
    test(
      'a hidden initial request is retried when the session becomes visible',
      () async {
        final pending = Completer<HomeFeedResult>();
        var calls = 0;
        final session = ClassicFeedSession(
          loadPage: (_) async => ++calls == 1 ? pending.future : _page([3, 4]),
        );
        addTearDown(session.dispose);
        final initial = session.loadInitial();
        session.setActive(active: false);
        pending.complete(_page([1, 2]));
        await initial;
        expect(session.state.videos, isEmpty);
        session.setActive(active: true);
        await session.settled;
        expect(calls, 2);
        expect(session.state.videos.map((v) => v.id), [3, 4].map(_id));
      },
    );

    test(
      'player-side removal preserves actual active '
      'and prepared next identities',
      () async {
        final removed = StreamController<String>.broadcast(sync: true);
        addTearDown(removed.close);
        final pending = Completer<HomeFeedResult>();
        var calls = 0;
        final requests = <ClassicRecommendationsRequest>[];
        final session = ClassicFeedSession(
          removedVideoIds: removed.stream,
          loadPage: (request) async {
            requests.add(request);
            return ++calls == 1 ? _page([1, 2, 3, 4, 5]) : pending.future;
          },
        );
        addTearDown(session.dispose);
        await session.loadInitial();
        removed.add(_id(2));
        session.activateVideo(_video(3));
        expect(requests.last.anchorVideoId, _id(3));
        pending.complete(_page([6, 7]));
        await session.settled;
        expect(session.state.videos.map((v) => v.id), [1, 3, 4, 6, 7].map(_id));
        expect(session.state.currentIndex, 1);
      },
    );

    test(
      'legacy archive fallback does not trigger network reads on each swipe',
      () async {
        var calls = 0;
        final session = ClassicFeedSession(
          loadPage: (_) async {
            calls++;
            return HomeFeedResult(
              videos: [1, 2, 3, 4].map(_video).toList(),
              paginationCursor: 'classic-offset:50',
              hasMore: true,
            );
          },
        );
        addTearDown(session.dispose);
        await session.loadInitial();
        session
          ..activate(1)
          ..recordInteraction(
            ClassicFeedInteraction(
              videoId: _id(2),
              signal: ClassicFeedSignal.positive,
            ),
          );
        await session.settled;
        expect(calls, 1);
        expect(session.state.videos, hasLength(4));
      },
    );

    test(
      'bounds request context while coalescing rapid navigation and feedback',
      () async {
        final pending = Completer<HomeFeedResult>();
        final requests = <ClassicRecommendationsRequest>[];
        final session = ClassicFeedSession(
          loadPage: (request) async {
            requests.add(request);
            return requests.length == 1
                ? _page(List.generate(30, (i) => i + 1))
                : pending.future;
          },
        );
        addTearDown(session.dispose);
        await session.loadInitial();
        for (var i = 0; i < 25; i++) {
          session
            ..activate(i)
            ..recordInteraction(
              ClassicFeedInteraction(
                videoId: _id(i + 1),
                signal: ClassicFeedSignal.completed,
              ),
            );
        }
        pending.complete(_page([100, 101]));
        await session.settled;
        expect(
          requests.last.recentInteractions.map((v) => v.videoId),
          List.generate(20, (i) => _id(i + 6)),
        );
        expect(
          requests.last.recentVideoIds,
          List.generate(10, (i) => _id(i + 16)),
        );
      },
    );

    group('resetContext', () {
      test('does not send the previous context continuation cursor', () async {
        final requests = <ClassicRecommendationsRequest>[];
        final session = ClassicFeedSession(
          loadPage: (request) async {
            requests.add(request);
            return _page([1, 2, 3], cursor: 'old-context-next');
          },
        );
        addTearDown(session.dispose);
        await session.loadInitial();
        expect(session.state.cursor, 'old-context-next');

        session.resetContext();
        await session.settled;

        expect(requests, hasLength(2));
        expect(requests.last.cursor, isNull);
      });
    });

    group('recordInteraction', () {
      test(
        'ignores an interaction recorded without personalization consent',
        () async {
          var allowed = false;
          final requests = <ClassicRecommendationsRequest>[];
          final session = ClassicFeedSession(
            canPersonalize: () => allowed,
            loadPage: (request) async {
              requests.add(request);
              return _page([1, 2, 3]);
            },
          );
          addTearDown(session.dispose);
          await session.loadInitial();

          session.recordInteraction(
            ClassicFeedInteraction(
              videoId: _id(1),
              signal: ClassicFeedSignal.positive,
            ),
          );
          await session.settled;
          expect(requests, hasLength(1));

          allowed = true;
          session.recordInteraction(
            ClassicFeedInteraction(
              videoId: _id(2),
              signal: ClassicFeedSignal.completed,
            ),
          );
          await session.settled;
          expect(requests, hasLength(2));
          expect(
            requests.last.recentInteractions.map((i) => i.videoId),
            [_id(2)],
          );
        },
      );
    });
  });
}
