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
        await expectLater(
          load(feed, cursor: 'badge-following'),
          throwsA(isA<FollowingReadSuperseded>()),
        );
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
        await expectLater(pending, throwsA(isA<FollowingReadSuperseded>()));
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
    group('unknown direct follows at startup', () {
      for (final settled in [false, true]) {
        test('settled empty contact read permits badges: $settled', () async {
          direct = [];
          final feed = FollowingVideoFeedSession(
            videosRepository: videos,
            directAuthors: () => direct,
            badgeAuthors: () async => ['2' * 64],
            directAuthorsKnown: () => false,
            waitForDirectAuthors: () async {},
            confirmDirectAuthors: () async => settled,
          );
          if (settled) {
            expect((await load(feed)).paginationCursor, 'badge-following');
            expect(feed.hasBadgeAuthors, isTrue);
          } else {
            await expectLater(
              load(feed),
              throwsA(isA<FollowingAuthorsUnavailable>()),
            );
            expect(feed.hasBadgeAuthors, isFalse);
          }
        });
      }

      test('inconclusive contact read remains retryable', () async {
        direct = [];
        var settled = false;
        final feed = FollowingVideoFeedSession(
          videosRepository: videos,
          directAuthors: () => direct,
          badgeAuthors: () async => ['2' * 64],
          directAuthorsKnown: () => false,
          waitForDirectAuthors: () async {},
          confirmDirectAuthors: () async => settled,
        );
        await expectLater(
          load(feed),
          throwsA(isA<FollowingAuthorsUnavailable>()),
        );
        settled = true;
        await load(feed);
        expect(feed.hasBadgeAuthors, isTrue);
      });
      test(
        'detailed contact read is bounded without proving empty follows',
        () async {
          direct = [];
          final feed = FollowingVideoFeedSession(
            videosRepository: videos,
            directAuthors: () => direct,
            badgeAuthors: () async => ['2' * 64],
            directAuthorsKnown: () => false,
            waitForDirectAuthors: () async {},
            confirmDirectAuthors: () => Completer<bool>().future,
            directAuthorsTimeout: Duration.zero,
          );
          await expectLater(
            load(feed),
            throwsA(isA<FollowingAuthorsUnavailable>()),
          );
          expect(feed.hasBadgeAuthors, isFalse);
        },
      );
      test('superseded detailed contact read never installs a pager', () async {
        direct = [];
        final settled = Completer<bool>();
        final confirming = Completer<void>();
        final feed = FollowingVideoFeedSession(
          videosRepository: videos,
          directAuthors: () => direct,
          badgeAuthors: () async => ['2' * 64],
          directAuthorsKnown: () => false,
          waitForDirectAuthors: () async {},
          confirmDirectAuthors: () {
            confirming.complete();
            return settled.future;
          },
        );
        final pending = load(feed);
        await confirming.future;
        owns = false;
        settled.complete(true);
        await expectLater(pending, throwsA(isA<FollowingReadSuperseded>()));
        verifyNever(
          () => videos.createBadgeVideoPager(any(), prioritizeUnseen: true),
        );
      });

      test(
        'waits for initialization before merging direct and badge authors',
        () async {
          direct = [];
          var known = false;
          final initialized = Completer<void>();
          final feed = FollowingVideoFeedSession(
            videosRepository: videos,
            directAuthors: () => direct,
            badgeAuthors: () async => ['2' * 64],
            waitForDirectAuthors: () => initialized.future,
            directAuthorsKnown: () => known,
          );
          final pending = load(feed);
          await Future<void>.value();
          verifyNever(
            () => videos.createBadgeVideoPager(any(), prioritizeUnseen: true),
          );
          direct = ['1' * 64];
          known = true;
          initialized.complete();
          await pending;
          verify(
            () => videos.createBadgeVideoPager([
              '1' * 64,
              '2' * 64,
            ], prioritizeUnseen: true),
          ).called(1);
        },
      );
      for (final known in [false, true]) {
        for (final nonempty in [false, true]) {
          test(
            'server proof requires unknown follows and a nonempty page: '
            'known $known, videos $nonempty',
            () async {
              direct = [];
              final failure = Exception('holders unavailable');
              final result = HomeFeedResult(
                videos: nonempty ? [_video] : [],
                hasMore: false,
              );
              when(
                () => videos.getHomeFeedVideos(
                  authors: any(named: 'authors'),
                  userPubkey: any(named: 'userPubkey'),
                  cursor: any(named: 'cursor'),
                ),
              ).thenAnswer((_) async => result);
              final feed = FollowingVideoFeedSession(
                videosRepository: videos,
                directAuthors: () => direct,
                badgeAuthors: () async => throw failure,
                userPubkey: '3' * 64,
                directAuthorsKnown: () => known,
                waitForDirectAuthors: () async {},
              );
              if (!known && nonempty) {
                expect(await load(feed), same(result));
              } else {
                await expectLater(load(feed), throwsA(same(failure)));
              }
            },
          );
        }
      }
      test(
        'cached direct authors do not wait for relay initialization',
        () async {
          var waited = false;
          final feed = FollowingVideoFeedSession(
            videosRepository: videos,
            directAuthors: () => direct,
            badgeAuthors: () async => ['2' * 64],
            directAuthorsKnown: () => false,
            waitForDirectAuthors: () async {
              waited = true;
            },
          );
          await load(feed);
          expect(waited, isFalse);
          expect(feed.hasBadgeAuthors, isTrue);
        },
      );
      test(
        'newly confirmed empty follows reject an in-flight '
        'positive server page',
        () async {
          direct = [];
          var known = false;
          final page = Completer<HomeFeedResult>();
          final failure = Exception('badges unavailable');
          when(
            () => videos.getHomeFeedVideos(
              authors: any(named: 'authors'),
              userPubkey: any(named: 'userPubkey'),
              cursor: any(named: 'cursor'),
            ),
          ).thenAnswer((_) => page.future);
          final feed = FollowingVideoFeedSession(
            videosRepository: videos,
            directAuthors: () => direct,
            badgeAuthors: () async => throw failure,
            directAuthorsKnown: () => known,
            userPubkey: '3' * 64,
          );
          final pending = load(feed);
          await Future<void>.value();
          known = true;
          page.complete(HomeFeedResult(videos: [_video]));
          await expectLater(pending, throwsA(same(failure)));
        },
      );
      test('superseded initialization never installs a pager', () async {
        direct = [];
        final initialized = Completer<void>();
        final feed = FollowingVideoFeedSession(
          videosRepository: videos,
          directAuthors: () => direct,
          badgeAuthors: () async => ['2' * 64],
          directAuthorsKnown: () => false,
          waitForDirectAuthors: () => initialized.future,
        );
        final pending = load(feed);
        await Future<void>.value();
        owns = false;
        initialized.complete();
        await expectLater(pending, throwsA(isA<FollowingReadSuperseded>()));
        verifyNever(
          () => videos.createBadgeVideoPager(any(), prioritizeUnseen: true),
        );
      });
      test(
        'initialization that never completes is bounded without '
        'proving empty follows',
        () async {
          direct = [];
          final feed = FollowingVideoFeedSession(
            videosRepository: videos,
            directAuthors: () => direct,
            badgeAuthors: () async => ['2' * 64],
            directAuthorsKnown: () => false,
            waitForDirectAuthors: () => Completer<void>().future,
            directAuthorsTimeout: Duration.zero,
          );
          await expectLater(
            load(feed),
            throwsA(isA<FollowingAuthorsUnavailable>()),
          );
          verifyNever(
            () => videos.createBadgeVideoPager(any(), prioritizeUnseen: true),
          );
        },
      );
      test('unknown follows never install a holder-only pager', () async {
        direct = [];
        final feed = FollowingVideoFeedSession(
          videosRepository: videos,
          directAuthors: () => direct,
          badgeAuthors: () async => ['2' * 64],
          directAuthorsKnown: () => false,
          waitForDirectAuthors: () async {},
        );
        await expectLater(
          load(feed),
          throwsA(isA<FollowingAuthorsUnavailable>()),
        );
        verifyNever(
          () => videos.createBadgeVideoPager(any(), prioritizeUnseen: true),
        );
      });
    });

    test('known empty subscriptions permit server-computed startup', () async {
      direct = [];
      expect(await load(session(holders: () async => [])), same(directPage));
    });
    test('direct fallback preserves its original failure stack', () async {
      final failure = Exception('direct unavailable');
      final origin = StackTrace.fromString('direct reader original frame');
      when(
        () => videos.getHomeFeedVideos(
          authors: any(named: 'authors'),
          userPubkey: any(named: 'userPubkey'),
          cursor: any(named: 'cursor'),
        ),
      ).thenAnswer((_) => Future.error(failure, origin));
      try {
        await load(
          session(holders: () async => throw Exception('badges unavailable')),
        );
        fail('expected direct failure');
      } on Exception catch (error, stack) {
        expect(error, same(failure));
        expect(stack.toString(), origin.toString());
      }
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
    test(
      'ownership lost after direct completion checkpoint '
      'throws typed supersession',
      () async {
        final directDone = Completer<HomeFeedResult>();
        final holdersDone = Completer<Iterable<String>>();
        when(
          () => videos.getHomeFeedVideos(
            authors: any(named: 'authors'),
            userPubkey: any(named: 'userPubkey'),
            cursor: any(named: 'cursor'),
          ),
        ).thenAnswer((_) => directDone.future);
        final feed = session(holders: () => holdersDone.future);
        final pending = load(feed);
        holdersDone.complete([]);
        await Future<void>.value();
        owns = false;
        directDone.complete(directPage);
        await expectLater(pending, throwsA(isA<FollowingReadSuperseded>()));
      },
    );
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

final _video = VideoEvent(
  id: '4' * 64,
  pubkey: '5' * 64,
  createdAt: 1,
  content: '',
  timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
);
