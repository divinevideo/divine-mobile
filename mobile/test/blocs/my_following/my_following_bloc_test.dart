// ABOUTME: Tests for MyFollowingBloc - current user's following list
// ABOUTME: Tests CacheSync stream, follow/unfollow, and blocklist filtering

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/follow_list_sort.dart';
import 'package:openvine/blocs/my_following/my_following_bloc.dart';
import 'package:openvine/features/consumption_analytics/consumption_analytics_tracker.dart';

import '../../helpers/recording_consumption_analytics.dart';
import '../../helpers/test_user_ranking_loader.dart';

class _MockFollowRepository extends Mock implements FollowRepository {}

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

void main() {
  group(MyFollowingBloc, () {
    test('default sort is smart', () {
      expect(const MyFollowingState().sortOrder.name, 'smart');
    });

    late _MockFollowRepository mockFollowRepository;
    late _MockContentBlocklistRepository mockBlocklistRepository;
    late RecordingConsumptionAnalytics analytics;

    // Helper to create valid hex pubkeys (64 hex characters)
    String validPubkey(String suffix) {
      final hexSuffix = suffix.codeUnits
          .map((c) => c.toRadixString(16).padLeft(2, '0'))
          .join();
      return hexSuffix.padLeft(64, '0');
    }

    setUp(() async {
      mockFollowRepository = _MockFollowRepository();
      mockBlocklistRepository = _MockContentBlocklistRepository();
      analytics = RecordingConsumptionAnalytics();

      // Default: nothing is blocked
      when(() => mockBlocklistRepository.isBlocked(any())).thenReturn(false);
      when(() => mockFollowRepository.followingPubkeys).thenReturn(const []);
      when(() => mockFollowRepository.isInitialized).thenReturn(false);
      when(
        () => mockFollowRepository.followingStream,
      ).thenAnswer((_) => const Stream<List<String>>.empty());
    });

    MyFollowingBloc createBloc() => MyFollowingBloc(
      rankForList: true,
      rankingSignalsLoader: testUserRankingLoader(),
      followRepository: mockFollowRepository,
      contentBlocklistRepository: mockBlocklistRepository,
      consumptionAnalytics: ConsumptionAnalyticsTracker(
        analytics: () => analytics,
      ),
    );

    test('initial state is initial when repository cache is empty', () async {
      final bloc = createBloc();
      expect(bloc.state, const MyFollowingState());
      await bloc.close();
    });

    test(
      'initial state is seeded from repository cache when available',
      () async {
        when(
          () => mockFollowRepository.followingPubkeys,
        ).thenReturn([validPubkey('cached')]);

        final bloc = createBloc();
        expect(
          bloc.state,
          MyFollowingState(
            status: MyFollowingStatus.success,
            rawFollowingPubkeys: [validPubkey('cached')],
            followingPubkeys: [validPubkey('cached')],
          ),
        );
        await bloc.close();
      },
    );

    group('closed mid-dispatch', () {
      late StreamController<List<String>> followingStream;

      setUp(() {
        followingStream = StreamController<List<String>>.broadcast();
        when(
          () => mockFollowRepository.followingStream,
        ).thenAnswer((_) => followingStream.stream);
        when(() => mockFollowRepository.watchMyFollowingCached()).thenAnswer(
          (_) => const Stream<CacheResult<FollowingSnapshot>>.empty(),
        );
      });

      tearDown(() async {
        await followingStream.close();
      });

      test('does not subscribe when the load drains during close', () async {
        final bloc = createBloc();
        bloc.add(const MyFollowingListLoadRequested());
        // No await in between: `close()` drains the queued load, so the
        // handler runs after the event controller is already closed.
        await bloc.close();

        // A subscription created here is never cancelled — `close()` already
        // ran past its cancel — so it would outlive the bloc.
        expect(followingStream.hasListener, isFalse);
      });

      test('cancels the subscription even when close is not awaited', () async {
        final bloc = createBloc();
        addTearDown(bloc.close);
        bloc.add(const MyFollowingListLoadRequested());
        await pumpEventQueue();
        expect(followingStream.hasListener, isTrue);

        // The cancel is issued before `super.close()`, so the listener is
        // already gone by the time close() yields — nothing can be delivered
        // into the drain.
        final closing = bloc.close();
        expect(followingStream.hasListener, isFalse);
        await closing;
      });
    });

    group('MyFollowingListLoadRequested', () {
      group('stale cached snapshot', () {
        test(
          'keeps the authoritative list when an initialized repository is '
          'followed by a stale cached snapshot',
          () async {
            final followed = validPubkey('followed');
            when(
              () => mockFollowRepository.followingPubkeys,
            ).thenReturn([followed]);
            when(() => mockFollowRepository.isInitialized).thenReturn(true);
            // The 30 second cache entry survived a restart and predates the
            // follow, so it serves an empty list before revalidating.
            when(() => mockFollowRepository.watchMyFollowingCached())
                .thenAnswer(
                  (_) => Stream.value(
                    const CacheResult.cached(
                      FollowingSnapshot(pubkeys: <String>[], count: 0),
                    ),
                  ),
                );

            final bloc = createBloc();
            addTearDown(bloc.close);
            expect(bloc.state.isFollowing(followed), isTrue);

            final isFollowingStates = <bool>[];
            final sub = bloc.stream.listen(
              (state) => isFollowingStates.add(state.isFollowing(followed)),
            );
            addTearDown(sub.cancel);

            bloc.add(const MyFollowingListLoadRequested());
            await pumpEventQueue();

            expect(
              isFollowingStates,
              isNotEmpty,
              reason: 'the cached emission should reach the state',
            );
            expect(
              isFollowingStates,
              everyElement(isTrue),
              reason:
                  'a stale cached snapshot must not show Follow for someone '
                  'already followed: tapping it would publish an unfollow',
            );
            expect(bloc.state.isRefreshing, isTrue);
          },
        );

        blocTest<MyFollowingBloc, MyFollowingState>(
          'uses the cached list for first paint while the repository is not '
          'initialized',
          setUp: () {
            when(() => mockFollowRepository.watchMyFollowingCached())
                .thenAnswer(
                  (_) => Stream.value(
                    CacheResult.cached(
                      FollowingSnapshot(
                        pubkeys: [validPubkey('cached')],
                        count: 1,
                      ),
                    ),
                  ),
                );
          },
          build: createBloc,
          act: (bloc) => bloc.add(const MyFollowingListLoadRequested()),
          verify: (bloc) {
            expect(bloc.state.followingPubkeys, [validPubkey('cached')]);
            expect(bloc.state.isRefreshing, isTrue);
          },
        );

        test(
          'takes the live list even when the repository is initialized',
          () async {
            final followed = validPubkey('followed');
            when(
              () => mockFollowRepository.followingPubkeys,
            ).thenReturn(const []);
            when(() => mockFollowRepository.isInitialized).thenReturn(true);
            when(() => mockFollowRepository.watchMyFollowingCached())
                .thenAnswer(
                  (_) => Stream.value(
                    CacheResult.live(
                      FollowingSnapshot(pubkeys: [followed], count: 1),
                    ),
                  ),
                );

            final bloc = createBloc();
            addTearDown(bloc.close);
            bloc.add(const MyFollowingListLoadRequested());
            await pumpEventQueue();

            expect(bloc.state.isFollowing(followed), isTrue);
            expect(bloc.state.isRefreshing, isFalse);
          },
        );
      });

      blocTest<MyFollowingBloc, MyFollowingState>(
        'emits success with pubkeys from stream',
        setUp: () {
          when(() => mockFollowRepository.watchMyFollowingCached()).thenAnswer(
            (_) => Stream.value(
              CacheResult.live(
                FollowingSnapshot(
                  pubkeys: [
                    validPubkey('following1'),
                    validPubkey('following2'),
                  ],
                  count: 2,
                ),
              ),
            ),
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(const MyFollowingListLoadRequested()),
        verify: (bloc) {
          expect(bloc.state.status, MyFollowingStatus.success);
          // Equal scores use a deterministic full-key tiebreak.
          expect(bloc.state.followingPubkeys, [
            validPubkey('following1'),
            validPubkey('following2'),
          ]);
          // The repository's follow order is kept intact for re-sorting.
          expect(bloc.state.rawFollowingPubkeys, [
            validPubkey('following1'),
            validPubkey('following2'),
          ]);
        },
      );

      blocTest<MyFollowingBloc, MyFollowingState>(
        'emits isRefreshing=false after fresh data (no cache)',
        setUp: () {
          when(() => mockFollowRepository.watchMyFollowingCached()).thenAnswer(
            (_) => Stream.value(
              CacheResult.live(
                FollowingSnapshot(
                  pubkeys: [validPubkey('following1')],
                  count: 1,
                ),
              ),
            ),
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(const MyFollowingListLoadRequested()),
        verify: (bloc) {
          expect(bloc.state.isRefreshing, isFalse);
        },
      );

      blocTest<MyFollowingBloc, MyFollowingState>(
        'emits success with empty list when following is empty',
        setUp: () {
          when(() => mockFollowRepository.watchMyFollowingCached()).thenAnswer(
            (_) => Stream.value(
              const CacheResult.live(
                FollowingSnapshot(pubkeys: <String>[], count: 0),
              ),
            ),
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(const MyFollowingListLoadRequested()),
        verify: (bloc) {
          expect(bloc.state.status, MyFollowingStatus.success);
          expect(bloc.state.followingPubkeys, isEmpty);
        },
      );

      blocTest<MyFollowingBloc, MyFollowingState>(
        'emits failure when stream errors before any visible data exists',
        setUp: () {
          when(
            () => mockFollowRepository.followingPubkeys,
          ).thenReturn(const []);
          when(() => mockFollowRepository.watchMyFollowingCached()).thenAnswer(
            (_) => Stream<CacheResult<FollowingSnapshot>>.error(
              Exception('Network error'),
            ),
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(const MyFollowingListLoadRequested()),
        verify: (bloc) {
          expect(bloc.state.status, MyFollowingStatus.failure);
          expect(bloc.state.isRefreshing, isFalse);
        },
        errors: () => [isA<Exception>()],
      );

      blocTest<MyFollowingBloc, MyFollowingState>(
        'keeps visible data when cached refresh errors',
        setUp: () {
          when(() => mockFollowRepository.watchMyFollowingCached()).thenAnswer((
            _,
          ) async* {
            yield CacheResult.cached(
              FollowingSnapshot(pubkeys: [validPubkey('cached')], count: 1),
            );
            throw Exception('Network error');
          });
        },
        build: createBloc,
        act: (bloc) => bloc.add(const MyFollowingListLoadRequested()),
        verify: (bloc) {
          expect(bloc.state.status, MyFollowingStatus.success);
          expect(bloc.state.followingPubkeys, [validPubkey('cached')]);
          expect(bloc.state.isRefreshing, isFalse);
        },
        errors: () => [isA<Exception>()],
      );

      blocTest<MyFollowingBloc, MyFollowingState>(
        'emits multiple states as stream yields multiple values',
        setUp: () {
          when(() => mockFollowRepository.watchMyFollowingCached()).thenAnswer(
            (_) => Stream.fromIterable([
              CacheResult.live(
                FollowingSnapshot(pubkeys: [validPubkey('old')], count: 1),
              ),
              CacheResult.live(
                FollowingSnapshot(
                  pubkeys: [
                    validPubkey('following1'),
                    validPubkey('following2'),
                  ],
                  count: 2,
                ),
              ),
            ]),
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(const MyFollowingListLoadRequested()),
        verify: (bloc) {
          expect(bloc.state.status, MyFollowingStatus.success);
          expect(bloc.state.followingPubkeys, [
            validPubkey('following1'),
            validPubkey('following2'),
          ]);
        },
      );
    });

    group(MyFollowingFollowRequested, () {
      blocTest<MyFollowingBloc, MyFollowingState>(
        'records a confirmed follow with its originating video',
        setUp: () {
          when(() => mockFollowRepository.isFollowing(any())).thenReturn(true);
          when(
            () => mockFollowRepository.follow(any()),
          ).thenAnswer((_) async {});
          when(
            () => mockFollowRepository.unfollow(any()),
          ).thenAnswer((_) async {});
        },
        build: createBloc,
        act: (bloc) => bloc.add(
          MyFollowingFollowRequested(
            validPubkey('user'),
            targetVideoId: 'video-id',
          ),
        ),
        verify: (_) {
          verify(
            () => mockFollowRepository.follow(validPubkey('user')),
          ).called(1);
          verifyNever(() => mockFollowRepository.unfollow(any()));
          expect(analytics.eventNames, ['engagement_recorded']);
          expect(analytics.parameters.single, {
            'action': 'follow_added',
            'content_id': 'video-id',
          });
        },
      );

      blocTest<MyFollowingBloc, MyFollowingState>(
        'does not re-dispatch a load after a successful follow (#5144)',
        setUp: () {
          when(
            () => mockFollowRepository.follow(any()),
          ).thenAnswer((_) async {});
          when(
            () => mockFollowRepository.watchMyFollowingCached(),
          ).thenAnswer((_) => const Stream.empty());
        },
        build: createBloc,
        act: (bloc) =>
            bloc.add(MyFollowingFollowRequested(validPubkey('user'))),
        verify: (_) {
          verify(() => mockFollowRepository.follow(any())).called(1);
          // The post-follow re-load that surfaced a stale cached snapshot and
          // reverted the button (#5144) is gone — reactivity comes from
          // followingStream/_onRepositoryUpdated, not a watchMyFollowingCached
          // re-read.
          verifyNever(() => mockFollowRepository.watchMyFollowingCached());
          expect(analytics.parameters.single, {
            'action': 'follow_added',
          });
        },
      );

      blocTest<MyFollowingBloc, MyFollowingState>(
        'does not record follow_added for an already-followed account',
        setUp: () {
          when(() => mockFollowRepository.followingPubkeys)
              .thenReturn([validPubkey('user')]);
          when(() => mockFollowRepository.follow(any()))
              .thenAnswer((_) async {});
        },
        build: createBloc,
        act: (bloc) =>
            bloc.add(MyFollowingFollowRequested(validPubkey('user'))),
        verify: (_) {
          verify(() => mockFollowRepository.follow(validPubkey('user')))
              .called(1);
          expect(analytics.eventNames, isEmpty);
        },
      );

      blocTest<MyFollowingBloc, MyFollowingState>(
        'does not record follow_added on unfollow',
        setUp: () {
          when(
            () => mockFollowRepository.followingPubkeys,
          ).thenReturn([validPubkey('user')]);
          when(
            () => mockFollowRepository.unfollow(any()),
          ).thenAnswer((_) async {});
          when(
            () => mockFollowRepository.watchMyFollowingCached(),
          ).thenAnswer((_) => const Stream.empty());
        },
        build: createBloc,
        act: (bloc) =>
            bloc.add(MyFollowingUnfollowRequested(validPubkey('user'))),
        verify: (_) {
          verify(
            () => mockFollowRepository.unfollow(validPubkey('user')),
          ).called(1);
          expect(analytics.eventNames, isEmpty);
        },
      );

      blocTest<MyFollowingBloc, MyFollowingState>(
        'does not record follow_added when the follow fails',
        setUp: () {
          when(
            () => mockFollowRepository.follow(any()),
          ).thenThrow(Exception('Network error'));
        },
        build: createBloc,
        act: (bloc) =>
            bloc.add(MyFollowingFollowRequested(validPubkey('user'))),
        verify: (bloc) {
          expect(bloc.state.status, MyFollowingStatus.toggleFailure);
          expect(analytics.eventNames, isEmpty);
        },
      );

      test(
        'does not revert follow state after a successful follow (#5144)',
        () async {
          final pubkey = validPubkey('target');
          final following = <String>[];
          final followingController =
              StreamController<List<String>>.broadcast();
          addTearDown(followingController.close);

          when(
            () => mockFollowRepository.followingPubkeys,
          ).thenReturn(following);
          when(
            () => mockFollowRepository.followingStream,
          ).thenAnswer((_) => followingController.stream);
          // If the (now-removed) re-load ran, watchMyFollowingCached would
          // serve a STALE cached snapshot that does NOT contain pubkey —
          // exactly what reverted the button before the fix.
          when(() => mockFollowRepository.watchMyFollowingCached()).thenAnswer(
            (_) => Stream.value(
              const CacheResult.cached(
                FollowingSnapshot(pubkeys: [], count: 0),
              ),
            ),
          );
          when(() => mockFollowRepository.follow(pubkey)).thenAnswer((
            _,
          ) async {
            following.add(pubkey);
            followingController.add(List.of(following));
          });

          final bloc = createBloc();
          addTearDown(bloc.close);
          final isFollowingStates = <bool>[];
          final sub = bloc.stream.listen(
            (state) => isFollowingStates.add(state.isFollowing(pubkey)),
          );
          addTearDown(sub.cancel);

          bloc.add(const MyFollowingListLoadRequested());
          await pumpEventQueue();
          bloc.add(MyFollowingFollowRequested(pubkey));
          await pumpEventQueue();

          final firstFollowed = isFollowingStates.indexOf(true);
          expect(
            firstFollowed,
            isNonNegative,
            reason: 'the follow should register as Following',
          );
          expect(
            isFollowingStates.sublist(firstFollowed),
            everyElement(isTrue),
            reason:
                'follow state must never revert to not-following after a '
                'successful follow (#5144)',
          );
        },
      );

      test(
        'does not revert when an in-flight load emits stale data after a '
        'follow (#5144)',
        () async {
          final pubkey = validPubkey('target');
          final following = <String>[];
          final followingController =
              StreamController<List<String>>.broadcast();
          final loadController =
              StreamController<CacheResult<FollowingSnapshot>>();
          addTearDown(followingController.close);
          addTearDown(loadController.close);

          when(
            () => mockFollowRepository.followingPubkeys,
          ).thenReturn(following);
          when(
            () => mockFollowRepository.followingStream,
          ).thenAnswer((_) => followingController.stream);
          // The mount-time load is still in flight (no emission yet) when the
          // user taps Follow.
          when(
            () => mockFollowRepository.watchMyFollowingCached(),
          ).thenAnswer((_) => loadController.stream);
          // The repository updates its in-memory list and emits at once, then
          // waits for the contact-list publish to reach the relays.
          final publish = Completer<void>();
          when(() => mockFollowRepository.follow(pubkey)).thenAnswer((_) {
            following.add(pubkey);
            followingController.add(List.of(following));
            return publish.future;
          });

          final bloc = createBloc();
          addTearDown(() async {
            if (!publish.isCompleted) publish.complete();
            await bloc.close();
          });
          final isFollowingStates = <bool>[];
          final sub = bloc.stream.listen(
            (state) => isFollowingStates.add(state.isFollowing(pubkey)),
          );
          addTearDown(sub.cancel);

          bloc.add(const MyFollowingListLoadRequested());
          await pumpEventQueue();
          bloc.add(MyFollowingFollowRequested(pubkey));
          await pumpEventQueue();

          // While the publish is still pending, the in-flight load's network
          // revalidation resolves with the relay-lagged pre-follow (stale)
          // list — the surviving #5144 race.
          loadController.add(
            const CacheResult.live(FollowingSnapshot(pubkeys: [], count: 0)),
          );
          await pumpEventQueue();
          publish.complete();
          await pumpEventQueue();

          final firstFollowed = isFollowingStates.indexOf(true);
          expect(
            firstFollowed,
            isNonNegative,
            reason: 'the follow should register as Following',
          );
          expect(
            isFollowingStates.sublist(firstFollowed),
            everyElement(isTrue),
            reason:
                'a stale in-flight load emission must not revert the button '
                'after a successful follow (#5144)',
          );
        },
      );

      blocTest<MyFollowingBloc, MyFollowingState>(
        'emits toggleFailure and reports the error when follow throws',
        setUp: () {
          when(
            () => mockFollowRepository.follow(any()),
          ).thenThrow(Exception('Network error'));
        },
        build: createBloc,
        act: (bloc) =>
            bloc.add(MyFollowingFollowRequested(validPubkey('user'))),
        expect: () => const [
          MyFollowingState(hasLocalFollowEdit: true),
          MyFollowingState(
            status: MyFollowingStatus.toggleFailure,
            hasLocalFollowEdit: true,
          ),
        ],
        errors: () => [isA<Exception>()],
      );

      test('does not emit after close when a follow completes', () async {
        final pubkey = validPubkey('user');
        final followCompleter = Completer<void>();
        when(
          () => mockFollowRepository.follow(pubkey),
        ).thenAnswer((_) => followCompleter.future);

        final bloc = createBloc();
        addTearDown(() async {
          if (!followCompleter.isCompleted) followCompleter.complete();
          await bloc.close();
        });
        bloc.add(MyFollowingFollowRequested(pubkey));
        await untilCalled(() => mockFollowRepository.follow(pubkey));

        final closeFuture = bloc.close();
        followCompleter.complete();

        await expectLater(closeFuture, completes);
        // The local-edit flag is set before the follow is awaited, so the
        // state can only differ from this if something emitted afterwards.
        expect(bloc.state, const MyFollowingState(hasLocalFollowEdit: true));
      });
    });

    group(MyFollowingUnfollowRequested, () {
      blocTest<MyFollowingBloc, MyFollowingState>(
        'unfollows even when the repository no longer lists the account',
        setUp: () {
          // The button offered Unfollow, but the follow list lost the account
          // before the event ran; deciding again from it would follow.
          when(
            () => mockFollowRepository.isFollowing(any()),
          ).thenReturn(false);
          when(
            () => mockFollowRepository.follow(any()),
          ).thenAnswer((_) async {});
          when(
            () => mockFollowRepository.unfollow(any()),
          ).thenAnswer((_) async {});
        },
        build: createBloc,
        act: (bloc) =>
            bloc.add(MyFollowingUnfollowRequested(validPubkey('user'))),
        verify: (_) {
          verify(
            () => mockFollowRepository.unfollow(validPubkey('user')),
          ).called(1);
          verifyNever(() => mockFollowRepository.follow(any()));
        },
      );

      blocTest<MyFollowingBloc, MyFollowingState>(
        'emits toggleFailure and reports the error when unfollow throws',
        setUp: () {
          when(
            () => mockFollowRepository.unfollow(any()),
          ).thenThrow(Exception('Network error'));
        },
        build: createBloc,
        act: (bloc) =>
            bloc.add(MyFollowingUnfollowRequested(validPubkey('user'))),
        expect: () => const [
          MyFollowingState(hasLocalFollowEdit: true),
          MyFollowingState(
            status: MyFollowingStatus.toggleFailure,
            hasLocalFollowEdit: true,
          ),
        ],
        errors: () => [isA<Exception>()],
      );

      test('does not emit after close when an unfollow fails', () async {
        final pubkey = validPubkey('user');
        final unfollowCompleter = Completer<void>();
        when(
          () => mockFollowRepository.unfollow(pubkey),
        ).thenAnswer((_) => unfollowCompleter.future);

        final bloc = createBloc();
        addTearDown(() async {
          if (!unfollowCompleter.isCompleted) unfollowCompleter.complete();
          await bloc.close();
        });
        bloc.add(MyFollowingUnfollowRequested(pubkey));
        await untilCalled(() => mockFollowRepository.unfollow(pubkey));

        final closeFuture = bloc.close();
        unfollowCompleter.completeError(Exception('Network error'));

        await expectLater(closeFuture, completes);
        expect(bloc.state.status, MyFollowingStatus.initial);
      });
    });

    group(MyFollowingEditRequested, () {
      test('drops an Unfollow sent while a Follow is still publishing', () async {
        final pubkey = validPubkey('user');
        final finishFollow = Completer<void>();
        when(
          () => mockFollowRepository.follow(pubkey),
        ).thenAnswer((_) => finishFollow.future);
        when(
          () => mockFollowRepository.unfollow(pubkey),
        ).thenAnswer((_) async {});

        final bloc = createBloc();
        addTearDown(() async {
          if (!finishFollow.isCompleted) finishFollow.complete();
          await bloc.close();
        });
        bloc.add(MyFollowingFollowRequested(pubkey));
        await untilCalled(() => mockFollowRepository.follow(pubkey));
        // Keep the follow pending while the Unfollow drains, so the assertion
        // checks overlap rather than elapsed time. Separate buckets per event
        // type would run it concurrently and publish two contact lists at once.
        bloc.add(MyFollowingUnfollowRequested(pubkey));
        await pumpEventQueue();

        verifyNever(() => mockFollowRepository.unfollow(pubkey));

        finishFollow.complete();
        await pumpEventQueue();
        // A sequential transformer would run the queued Unfollow now.
        verifyNever(() => mockFollowRepository.unfollow(pubkey));
        verify(() => mockFollowRepository.follow(pubkey)).called(1);
      });
    });

    test('applies live repository updates after initial load', () async {
      final controller = StreamController<List<String>>.broadcast();
      addTearDown(controller.close);
      when(
        () => mockFollowRepository.followingStream,
      ).thenAnswer((_) => controller.stream);
      when(
        () => mockFollowRepository.watchMyFollowingCached(),
      ).thenAnswer((_) => const Stream.empty());

      final bloc = createBloc();
      addTearDown(bloc.close);
      bloc.add(const MyFollowingListLoadRequested());
      await pumpEventQueue();

      controller.add([validPubkey('live1'), validPubkey('live2')]);
      await pumpEventQueue();

      expect(bloc.state.status, MyFollowingStatus.success);
      // A follow the repository appended is the newest, so it leads.
      expect(bloc.state.followingPubkeys, [
        validPubkey('live1'),
        validPubkey('live2'),
      ]);
    });

    group('blocklist filtering', () {
      blocTest<MyFollowingBloc, MyFollowingState>(
        'filters blocked users from following list',
        setUp: () {
          when(
            () => mockBlocklistRepository.isBlocked(validPubkey('blocked')),
          ).thenReturn(true);
          when(() => mockFollowRepository.watchMyFollowingCached()).thenAnswer(
            (_) => Stream.value(
              CacheResult.live(
                FollowingSnapshot(
                  pubkeys: [
                    validPubkey('following1'),
                    validPubkey('blocked'),
                    validPubkey('following2'),
                  ],
                  count: 3,
                ),
              ),
            ),
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(const MyFollowingListLoadRequested()),
        verify: (bloc) {
          expect(
            bloc.state.followingPubkeys,
            containsAll([validPubkey('following1'), validPubkey('following2')]),
          );
          expect(
            bloc.state.followingPubkeys,
            isNot(contains(validPubkey('blocked'))),
          );
        },
      );

      blocTest<MyFollowingBloc, MyFollowingState>(
        'MyFollowingBlocklistChanged re-filters cached pubkeys',
        setUp: () {
          when(() => mockFollowRepository.watchMyFollowingCached()).thenAnswer(
            (_) => Stream.value(
              CacheResult.live(
                FollowingSnapshot(
                  pubkeys: [
                    validPubkey('following1'),
                    validPubkey('toBlock'),
                    validPubkey('following2'),
                  ],
                  count: 3,
                ),
              ),
            ),
          );
        },
        build: createBloc,
        act: (bloc) async {
          bloc.add(const MyFollowingListLoadRequested());
          await pumpEventQueue();
          when(
            () => mockBlocklistRepository.isBlocked(validPubkey('toBlock')),
          ).thenReturn(true);
          bloc.add(const MyFollowingBlocklistChanged());
        },
        verify: (bloc) {
          // Still newest first: oldestFirst is the raw contact-list order, so
          // only the default order shows whether the re-filter keeps the sort.
          expect(bloc.state.followingPubkeys, [
            validPubkey('following1'),
            validPubkey('following2'),
          ]);
        },
      );

      test('filters blocked users from a live repository update', () async {
        final controller = StreamController<List<String>>.broadcast();
        addTearDown(controller.close);
        when(
          () => mockFollowRepository.followingStream,
        ).thenAnswer((_) => controller.stream);
        when(
          () => mockFollowRepository.watchMyFollowingCached(),
        ).thenAnswer((_) => const Stream.empty());
        when(
          () => mockBlocklistRepository.isBlocked(validPubkey('blocked')),
        ).thenReturn(true);

        final bloc = createBloc();
        addTearDown(bloc.close);
        bloc.add(const MyFollowingListLoadRequested());
        await pumpEventQueue();
        expect(controller.hasListener, isTrue);

        controller.add([
          validPubkey('following1'),
          validPubkey('blocked'),
          validPubkey('following2'),
        ]);
        await pumpEventQueue();

        // Newest follow first, with the blocked pubkey filtered out.
        expect(bloc.state.followingPubkeys, [
          validPubkey('following1'),
          validPubkey('following2'),
        ]);
      });
    });

    group('MyFollowingSortOrderChanged', () {
      /// Three follows in contact-list order: `first` was followed first.
      void stubLoadedFollowing() {
        when(() => mockFollowRepository.watchMyFollowingCached()).thenAnswer(
          (_) => Stream.value(
            CacheResult.live(
              FollowingSnapshot(
                pubkeys: [
                  validPubkey('first'),
                  validPubkey('second'),
                  validPubkey('third'),
                ],
                count: 3,
              ),
            ),
          ),
        );
      }

      blocTest<MyFollowingBloc, MyFollowingState>(
        'restores contact-list order for oldestFirst',
        setUp: stubLoadedFollowing,
        build: createBloc,
        act: (bloc) async {
          bloc.add(const MyFollowingListLoadRequested());
          await pumpEventQueue();
          bloc.add(
            const MyFollowingSortOrderChanged(FollowListSort.oldestFirst),
          );
        },
        verify: (bloc) {
          expect(bloc.state.sortOrder, FollowListSort.oldestFirst);
          expect(bloc.state.followingPubkeys, [
            validPubkey('first'),
            validPubkey('second'),
            validPubkey('third'),
          ]);
        },
      );

      blocTest<MyFollowingBloc, MyFollowingState>(
        're-orders without asking the repository again',
        setUp: stubLoadedFollowing,
        build: createBloc,
        act: (bloc) async {
          bloc.add(const MyFollowingListLoadRequested());
          await pumpEventQueue();
          bloc.add(
            const MyFollowingSortOrderChanged(FollowListSort.oldestFirst),
          );
          await pumpEventQueue();
        },
        verify: (_) {
          verify(() => mockFollowRepository.watchMyFollowingCached()).called(1);
        },
      );

      blocTest<MyFollowingBloc, MyFollowingState>(
        'ignores a re-pick of the active order',
        setUp: stubLoadedFollowing,
        build: createBloc,
        act: (bloc) async {
          bloc.add(const MyFollowingListLoadRequested());
          await pumpEventQueue();
          bloc.add(
            const MyFollowingSortOrderChanged(FollowListSort.smart),
          );
        },
        skip: 1,
        expect: () => <MyFollowingState>[],
      );

      blocTest<MyFollowingBloc, MyFollowingState>(
        'remembers a sort picked before the list has loaded',
        setUp: stubLoadedFollowing,
        build: createBloc,
        act: (bloc) async {
          bloc.add(
            const MyFollowingSortOrderChanged(FollowListSort.oldestFirst),
          );
          await pumpEventQueue();
          bloc.add(const MyFollowingListLoadRequested());
        },
        verify: (bloc) {
          expect(bloc.state.followingPubkeys, [
            validPubkey('first'),
            validPubkey('second'),
            validPubkey('third'),
          ]);
        },
      );

      blocTest<MyFollowingBloc, MyFollowingState>(
        'keeps the picked order when the blocklist changes',
        setUp: stubLoadedFollowing,
        build: createBloc,
        act: (bloc) async {
          bloc.add(const MyFollowingListLoadRequested());
          await pumpEventQueue();
          bloc.add(
            const MyFollowingSortOrderChanged(FollowListSort.oldestFirst),
          );
          await pumpEventQueue();
          bloc.add(const MyFollowingBlocklistChanged());
        },
        verify: (bloc) {
          expect(bloc.state.sortOrder, FollowListSort.oldestFirst);
          expect(bloc.state.followingPubkeys, [
            validPubkey('first'),
            validPubkey('second'),
            validPubkey('third'),
          ]);
        },
      );

      test(
        'keeps the picked order when the repository pushes a live update',
        () async {
          stubLoadedFollowing();
          final controller = StreamController<List<String>>.broadcast();
          addTearDown(controller.close);
          when(
            () => mockFollowRepository.followingStream,
          ).thenAnswer((_) => controller.stream);

          final bloc = createBloc();
          addTearDown(bloc.close);
          bloc.add(const MyFollowingListLoadRequested());
          await pumpEventQueue();
          bloc.add(
            const MyFollowingSortOrderChanged(FollowListSort.oldestFirst),
          );
          await pumpEventQueue();
          expect(controller.hasListener, isTrue);

          controller.add([
            validPubkey('first'),
            validPubkey('second'),
            validPubkey('third'),
            validPubkey('fourth'),
          ]);
          await pumpEventQueue();

          expect(bloc.state.sortOrder, FollowListSort.oldestFirst);
          expect(bloc.state.followingPubkeys, [
            validPubkey('first'),
            validPubkey('second'),
            validPubkey('third'),
            validPubkey('fourth'),
          ]);
        },
      );
    });

    group('MyFollowingState', () {
      test('supports value equality', () {
        const state1 = MyFollowingState(
          status: MyFollowingStatus.success,
          followingPubkeys: ['pubkey1'],
        );
        const state2 = MyFollowingState(
          status: MyFollowingStatus.success,
          followingPubkeys: ['pubkey1'],
        );

        expect(state1, equals(state2));
      });

      test('isFollowing returns true when pubkey is in list', () {
        const state = MyFollowingState(
          status: MyFollowingStatus.success,
          followingPubkeys: ['pubkey1', 'pubkey2'],
        );

        expect(state.isFollowing('pubkey1'), isTrue);
        expect(state.isFollowing('pubkey2'), isTrue);
        expect(state.isFollowing('pubkey3'), isFalse);
      });

      test('isRefreshing included in equality check', () {
        const state1 = MyFollowingState(isRefreshing: true);
        const state2 = MyFollowingState();

        expect(state1, isNot(equals(state2)));
      });

      test('copyWith preserves values when not specified', () {
        const state = MyFollowingState(
          status: MyFollowingStatus.success,
          followingPubkeys: ['pubkey1'],
          isRefreshing: true,
        );

        final updated = state.copyWith();

        expect(updated.status, MyFollowingStatus.success);
        expect(updated.followingPubkeys, ['pubkey1']);
        expect(updated.isRefreshing, isTrue);
      });
    });
  });
}
