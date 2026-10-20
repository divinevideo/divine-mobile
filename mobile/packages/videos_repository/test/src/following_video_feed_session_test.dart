import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:videos_repository/videos_repository.dart';

class _Videos extends Mock implements VideosRepository {}

class _Pager extends Mock implements BadgeVideoPager {}

void main() {
  late _Videos videos;
  late _Pager pager;
  late List<String> direct;
  var owns = true;
  var active = true;
  const directPage = HomeFeedResult(
    videos: [],
    hasMore: true,
    paginationCursor: '25',
  );
  setUp(() {
    videos = _Videos();
    pager = _Pager();
    direct = ['1' * 64];
    owns = true;
    active = true;
    when(
      () => videos.getHomeFeedVideos(
        authors: any(named: 'authors'),
        userPubkey: any(named: 'userPubkey'),
        cursor: any(named: 'cursor'),
      ),
    ).thenAnswer((_) async => directPage);
    when(
      () => videos.createBadgeVideoPager(any(), prioritizeUnseen: true),
    ).thenReturn(pager);
    when(pager.loadMore).thenAnswer((_) async => <VideoEvent>[]);
    when(() => pager.hasMore).thenReturn(true);
  });
  FollowingVideoFeedSession session({
    Future<Iterable<String>> Function()? holders,
  }) => FollowingVideoFeedSession(
    videosRepository: videos,
    directAuthors: () => direct,
    badgeAuthors: holders,
  );
  Future<HomeFeedResult> load(
    FollowingVideoFeedSession feed, {
    String? cursor,
  }) => feed.loadPage(
    cursor: cursor,
    ownsRequest: () => owns,
    isActive: () => active,
  );

  group('loadPage', () {
    test('direct cursor and absent badge reader use home pagination', () async {
      final feed = session();
      expect(await load(feed), same(directPage));
      expect(await load(feed, cursor: '25'), same(directPage));
      expect(feed.hasBadgeAuthors, isFalse);
    });
    test('missing badge snapshot is terminal without calling home', () async {
      final result = await load(session(), cursor: 'badge-following');
      expect(result.hasMore, isFalse);
      verifyZeroInteractions(videos);
    });
    for (final more in [false, true]) {
      test('badge snapshot owns continuation, has more $more', () async {
        final feed = session(holders: () async => ['2' * 64]);
        when(() => pager.hasMore).thenReturn(more);
        final first = await load(feed);
        expect(feed.hasBadgeAuthors, isTrue);
        expect(first.paginationCursor, more ? 'badge-following' : null);
        final next = await load(feed, cursor: 'badge-following');
        expect(next.hasMore, more);
        expect(next.paginationCursor, more ? 'badge-following' : null);
        active = false;
        expect((await load(feed, cursor: 'badge-following')).hasMore, isFalse);
      });
    }
    test(
      'old cursor completion cannot return after snapshot replacement',
      () async {
        final feed = session(holders: () async => ['2' * 64]);
        await load(feed);
        final old = Completer<List<VideoEvent>>();
        when(pager.loadMore).thenAnswer((_) => old.future);
        final pending = load(feed, cursor: 'badge-following');
        final replacement = _Pager();
        when(replacement.loadMore).thenAnswer((_) async => []);
        when(() => replacement.hasMore).thenReturn(false);
        when(
          () => videos.createBadgeVideoPager(any(), prioritizeUnseen: true),
        ).thenReturn(replacement);
        await load(feed);
        old.complete([]);
        expect((await pending).hasMore, isFalse);
      },
    );
    for (final directPresent in [false, true]) {
      for (final errorAt in ['holders', 'pager']) {
        test(
          '$errorAt failure falls back only with direct authors $directPresent',
          () async {
            if (!directPresent) direct = [];
            final failure = Exception('read unavailable');
            final feed = session(
              holders: () async {
                if (errorAt == 'holders') throw failure;
                return ['2' * 64];
              },
            );
            if (errorAt == 'pager') when(pager.loadMore).thenThrow(failure);
            if (directPresent) {
              expect(await load(feed), same(directPage));
              expect(feed.hasBadgeAuthors, isFalse);
            } else {
              await expectLater(load(feed), throwsA(same(failure)));
              verifyNever(
                () => videos.getHomeFeedVideos(
                  authors: any(named: 'authors'),
                  userPubkey: any(named: 'userPubkey'),
                  cursor: any(named: 'cursor'),
                ),
              );
            }
          },
        );
      }
    }
    test('known empty subscriptions permit server-computed startup', () async {
      direct = [];
      expect(await load(session(holders: () async => [])), same(directPage));
    });
    test('failed direct prefetch is preserved after badge fallback', () async {
      final failure = Exception('direct unavailable');
      when(
        () => videos.getHomeFeedVideos(
          authors: any(named: 'authors'),
          userPubkey: any(named: 'userPubkey'),
          cursor: any(named: 'cursor'),
        ),
      ).thenThrow(failure);
      await expectLater(
        load(session(holders: () async => [])),
        throwsA(same(failure)),
      );
    });
    for (final stage in ['holders', 'pager', 'direct']) {
      test(
        'supersession after $stage never commits a false terminal page',
        () async {
          final feed = session(
            holders: () async {
              if (stage == 'holders') owns = false;
              return stage == 'direct' ? [] : ['2' * 64];
            },
          );
          if (stage == 'pager') {
            when(pager.loadMore).thenAnswer((_) async {
              owns = false;
              return [];
            });
          }
          if (stage == 'direct') {
            when(
              () => videos.getHomeFeedVideos(
                authors: any(named: 'authors'),
                userPubkey: any(named: 'userPubkey'),
                cursor: any(named: 'cursor'),
              ),
            ).thenAnswer((_) async {
              owns = false;
              return directPage;
            });
          }
          await expectLater(
            load(feed),
            throwsA(isA<FollowingReadSuperseded>()),
          );
          expect(feed.hasBadgeAuthors, isFalse);
        },
      );
    }
    test(
      'successful empty recheck clears the committed badge snapshot',
      () async {
        var first = true;
        final feed = session(
          holders: () async {
            if (!first) return [];
            first = false;
            return ['2' * 64];
          },
        );
        await load(feed);
        expect(feed.hasBadgeAuthors, isTrue);
        await load(feed);
        expect(feed.hasBadgeAuthors, isFalse);
      },
    );
  });
}
