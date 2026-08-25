// ABOUTME: Tests for MyFollowingBloc - current user's following list
// ABOUTME: Tests CacheSync stream, toggle operations, and blocklist filtering

import 'dart:async';

import 'package:analytics/analytics.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/my_following/my_following_bloc.dart';
import 'package:openvine/features/consumption_analytics/consumption_analytics_tracker.dart';

class _MockFollowRepository extends Mock implements FollowRepository {}

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

void main() {
  group(MyFollowingBloc, () {
    late _MockFollowRepository mockFollowRepository;
    late _MockContentBlocklistRepository mockBlocklistRepository;
    late _RecordingAnalytics analytics;

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
      analytics = _RecordingAnalytics();

      // Default: nothing is blocked
      when(() => mockBlocklistRepository.isBlocked(any())).thenReturn(false);
      when(() => mockFollowRepository.followingPubkeys).thenReturn(const []);
      when(
        () => mockFollowRepository.followingStream,
      ).thenAnswer((_) => const Stream<List<String>>.empty());
    });

    MyFollowingBloc createBloc() => MyFollowingBloc(
      followRepository: mockFollowRepository,
      contentBlocklistRepository: mockBlocklistRepository,
      consumptionAnalytics: ConsumptionAnalyticsTracker(analytics: analytics),
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
          // Newest first by default, so the last `p` tag leads.
          expect(bloc.state.followingPubkeys, [
            validPubkey('following2'),
            validPubkey('following1'),
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
            validPubkey('following2'),
            validPubkey('following1'),
          ]);
        },
      );
    });

    group('MyFollowingToggleRequested', () {
      blocTest<MyFollowingBloc, MyFollowingState>(
        'calls toggleFollow on repository',
        setUp: () {
          when(
            () => mockFollowRepository.toggleFollow(any()),
          ).thenAnswer((_) async {});
          when(
            () => mockFollowRepository.watchMyFollowingCached(),
          ).thenAnswer((_) => const Stream.empty());
        },
        build: createBloc,
        act: (bloc) => bloc.add(
          MyFollowingToggleRequested(
            validPubkey('user'),
            targetVideoId: 'video-id',
          ),
        ),
        verify: (_) {
          verify(
            () => mockFollowRepository.toggleFollow(validPubkey('user')),
          ).called(1);
          expect(analytics.eventNames, ['follow_added']);
          expect(analytics.parameters.single, {
            'target_pubkey': validPubkey('user'),
            'target_video_id': 'video-id',
          });
        },
      );

      blocTest<MyFollowingBloc, MyFollowingState>(
        'does not re-dispatch a load after a successful toggle (#5144)',
        setUp: () {
          when(
            () => mockFollowRepository.toggleFollow(any()),
          ).thenAnswer((_) async {});
          when(
            () => mockFollowRepository.watchMyFollowingCached(),
          ).thenAnswer((_) => const Stream.empty());
        },
        build: createBloc,
        act: (bloc) =>
            bloc.add(MyFollowingToggleRequested(validPubkey('user'))),
        verify: (_) {
          verify(() => mockFollowRepository.toggleFollow(any())).called(1);
          // The post-toggle re-load that surfaced a stale cached snapshot and
          // reverted the button (#5144) is gone — reactivity comes from
          // followingStream/_onRepositoryUpdated, not a watchMyFollowingCached
          // re-read.
          verifyNever(() => mockFollowRepository.watchMyFollowingCached());
          expect(analytics.parameters.single, {
            'target_pubkey': validPubkey('user'),
          });
        },
      );

      blocTest<MyFollowingBloc, MyFollowingState>(
        'does not record follow_added when the toggle is an unfollow',
        setUp: () {
          when(
            () => mockFollowRepository.followingPubkeys,
          ).thenReturn([validPubkey('user')]);
          when(
            () => mockFollowRepository.toggleFollow(any()),
          ).thenAnswer((_) async {});
          when(
            () => mockFollowRepository.watchMyFollowingCached(),
          ).thenAnswer((_) => const Stream.empty());
        },
        build: createBloc,
        act: (bloc) =>
            bloc.add(MyFollowingToggleRequested(validPubkey('user'))),
        verify: (_) {
          verify(
            () => mockFollowRepository.toggleFollow(validPubkey('user')),
          ).called(1);
          expect(analytics.eventNames, isEmpty);
        },
      );

      blocTest<MyFollowingBloc, MyFollowingState>(
        'does not record follow_added when the follow fails',
        setUp: () {
          when(
            () => mockFollowRepository.toggleFollow(any()),
          ).thenThrow(Exception('Network error'));
        },
        build: createBloc,
        act: (bloc) =>
            bloc.add(MyFollowingToggleRequested(validPubkey('user'))),
        verify: (bloc) {
          expect(bloc.state.status, MyFollowingStatus.toggleFailure);
          expect(analytics.eventNames, isEmpty);
        },
      );

      test(
        'does not revert follow state after a successful toggle (#5144)',
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
          when(() => mockFollowRepository.toggleFollow(pubkey)).thenAnswer((
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
          bloc.add(MyFollowingToggleRequested(pubkey));
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
                'successful toggle (#5144)',
          );
        },
      );

      test(
        'does not revert when an in-flight load emits stale data after a '
        'toggle (#5144)',
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
          when(() => mockFollowRepository.toggleFollow(pubkey)).thenAnswer((
            _,
          ) {
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
          bloc.add(MyFollowingToggleRequested(pubkey));
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
                'after a successful toggle (#5144)',
          );
        },
      );

      blocTest<MyFollowingBloc, MyFollowingState>(
        'emits toggleFailure when toggleFollow throws',
        setUp: () {
          when(
            () => mockFollowRepository.toggleFollow(any()),
          ).thenThrow(Exception('Network error'));
        },
        build: createBloc,
        act: (bloc) =>
            bloc.add(MyFollowingToggleRequested(validPubkey('user'))),
        verify: (bloc) {
          expect(bloc.state.status, MyFollowingStatus.toggleFailure);
        },
      );

      test(
        'does not emit after close when a successful toggle completes',
        () async {
          final pubkey = validPubkey('user');
          final toggleCompleter = Completer<void>();
          when(
            () => mockFollowRepository.toggleFollow(pubkey),
          ).thenAnswer((_) => toggleCompleter.future);

          final bloc = createBloc();
          addTearDown(() async {
            if (!toggleCompleter.isCompleted) toggleCompleter.complete();
            await bloc.close();
          });
          bloc.add(MyFollowingToggleRequested(pubkey));
          await untilCalled(() => mockFollowRepository.toggleFollow(pubkey));

          final closeFuture = bloc.close();
          toggleCompleter.complete();

          await expectLater(closeFuture, completes);
          // The local-edit flag is set before the toggle is awaited, so the
          // state can only differ from this if something emitted afterwards.
          expect(bloc.state, const MyFollowingState(hasLocalFollowEdit: true));
        },
      );

      test('does not emit after close when a toggle fails', () async {
        final pubkey = validPubkey('user');
        final toggleCompleter = Completer<void>();
        when(
          () => mockFollowRepository.toggleFollow(pubkey),
        ).thenAnswer((_) => toggleCompleter.future);

        final bloc = createBloc();
        addTearDown(() async {
          if (!toggleCompleter.isCompleted) toggleCompleter.complete();
          await bloc.close();
        });
        bloc.add(MyFollowingToggleRequested(pubkey));
        await untilCalled(() => mockFollowRepository.toggleFollow(pubkey));

        final closeFuture = bloc.close();
        toggleCompleter.completeError(Exception('Network error'));

        await expectLater(closeFuture, completes);
        expect(bloc.state.status, MyFollowingStatus.initial);
      });

      test(
        'uses droppable transformer — second rapid toggle is dropped',
        () async {
          final pubkey = validPubkey('user');
          final finishToggle = Completer<void>();
          when(
            () => mockFollowRepository.toggleFollow(pubkey),
          ).thenAnswer((_) => finishToggle.future);

          final bloc = createBloc();
          addTearDown(() async {
            if (!finishToggle.isCompleted) finishToggle.complete();
            await bloc.close();
          });
          bloc.add(MyFollowingToggleRequested(pubkey));
          await untilCalled(() => mockFollowRepository.toggleFollow(pubkey));
          // Keep the first repository write pending while the second event
          // drains, so the assertion checks overlap rather than elapsed time.
          bloc.add(MyFollowingToggleRequested(pubkey));
          await pumpEventQueue();

          verify(() => mockFollowRepository.toggleFollow(pubkey)).called(1);

          finishToggle.complete();
          await pumpEventQueue();
          // A sequential transformer would defer the second write until now.
          verifyNever(() => mockFollowRepository.toggleFollow(pubkey));
        },
      );
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
        validPubkey('live2'),
        validPubkey('live1'),
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
            validPubkey('following2'),
            validPubkey('following1'),
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
          validPubkey('following2'),
          validPubkey('following1'),
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
            const MyFollowingSortOrderChanged(FollowSortOrder.oldestFirst),
          );
        },
        verify: (bloc) {
          expect(bloc.state.sortOrder, FollowSortOrder.oldestFirst);
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
            const MyFollowingSortOrderChanged(FollowSortOrder.oldestFirst),
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
            const MyFollowingSortOrderChanged(FollowSortOrder.newestFirst),
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
            const MyFollowingSortOrderChanged(FollowSortOrder.oldestFirst),
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
            const MyFollowingSortOrderChanged(FollowSortOrder.oldestFirst),
          );
          await pumpEventQueue();
          bloc.add(const MyFollowingBlocklistChanged());
        },
        verify: (bloc) {
          expect(bloc.state.sortOrder, FollowSortOrder.oldestFirst);
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
            const MyFollowingSortOrderChanged(FollowSortOrder.oldestFirst),
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

          expect(bloc.state.sortOrder, FollowSortOrder.oldestFirst);
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

class _RecordingAnalytics extends NoOpAnalyticsEventSink {
  final eventNames = <String>[];
  final parameters = <Map<String, Object>>[];

  @override
  Future<void> logEvent({
    required String name,
    required Map<String, Object> parameters,
  }) async {
    eventNames.add(name);
    this.parameters.add(parameters);
  }
}
