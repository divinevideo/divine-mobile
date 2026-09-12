// ABOUTME: Tests for MyFollowingBloc - current user's following list
// ABOUTME: Tests CacheSync stream, toggle operations, and blocklist filtering

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/my_following/my_following_bloc.dart';

class _MockFollowRepository extends Mock implements FollowRepository {}

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

void main() {
  group(MyFollowingBloc, () {
    late _MockFollowRepository mockFollowRepository;
    late _MockContentBlocklistRepository mockBlocklistRepository;

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
    );

    test('initial state is initial when repository cache is empty', () {
      final bloc = createBloc();
      expect(bloc.state, const MyFollowingState());
      bloc.close();
    });

    test('initial state is seeded from repository cache when available', () {
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
      bloc.close();
    });

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
        bloc.add(const MyFollowingListLoadRequested());
        await Future<void>.delayed(Duration.zero);
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
        act: (bloc) =>
            bloc.add(MyFollowingToggleRequested(validPubkey('user'))),
        verify: (_) {
          verify(
            () => mockFollowRepository.toggleFollow(validPubkey('user')),
          ).called(1);
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
          final isFollowingStates = <bool>[];
          final sub = bloc.stream.listen(
            (state) => isFollowingStates.add(state.isFollowing(pubkey)),
          );

          bloc.add(const MyFollowingListLoadRequested());
          await Future<void>.delayed(Duration.zero);
          bloc.add(MyFollowingToggleRequested(pubkey));
          await Future<void>.delayed(const Duration(milliseconds: 50));

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

          await sub.cancel();
          await bloc.close();
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
          when(() => mockFollowRepository.toggleFollow(pubkey)).thenAnswer((
            _,
          ) async {
            following.add(pubkey);
            followingController.add(List.of(following));
          });

          final bloc = createBloc();
          final isFollowingStates = <bool>[];
          final sub = bloc.stream.listen(
            (state) => isFollowingStates.add(state.isFollowing(pubkey)),
          );

          bloc.add(const MyFollowingListLoadRequested());
          await Future<void>.delayed(Duration.zero);
          bloc.add(MyFollowingToggleRequested(pubkey));
          await Future<void>.delayed(const Duration(milliseconds: 10));

          // The in-flight load's network revalidation now resolves with the
          // relay-lagged pre-follow (stale) list — the surviving #5144 race.
          loadController.add(
            const CacheResult.live(FollowingSnapshot(pubkeys: [], count: 0)),
          );
          await Future<void>.delayed(const Duration(milliseconds: 10));

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

          await sub.cancel();
          await bloc.close();
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
          bloc.add(MyFollowingToggleRequested(pubkey));
          await Future<void>.delayed(Duration.zero);

          final closeFuture = bloc.close();
          toggleCompleter.complete();

          await expectLater(closeFuture, completes);
          // The local-edit flag is set before the toggle is awaited, so it is
          // already true here; what must not happen is an emit after close.
          expect(bloc.state.hasLocalFollowEdit, isTrue);
        },
      );

      test('does not emit after close when a toggle fails', () async {
        final pubkey = validPubkey('user');
        final toggleCompleter = Completer<void>();
        when(
          () => mockFollowRepository.toggleFollow(pubkey),
        ).thenAnswer((_) => toggleCompleter.future);

        final bloc = createBloc();
        bloc.add(MyFollowingToggleRequested(pubkey));
        await Future<void>.delayed(Duration.zero);

        final closeFuture = bloc.close();
        toggleCompleter.completeError(Exception('Network error'));

        await expectLater(closeFuture, completes);
        expect(bloc.state.status, MyFollowingStatus.initial);
      });

      blocTest<MyFollowingBloc, MyFollowingState>(
        'uses droppable transformer — second rapid toggle is dropped',
        setUp: () {
          var callCount = 0;
          when(() => mockFollowRepository.toggleFollow(any())).thenAnswer((
            _,
          ) async {
            callCount++;
            if (callCount == 1) {
              await Future<void>.delayed(const Duration(milliseconds: 50));
            }
          });
          when(
            () => mockFollowRepository.watchMyFollowingCached(),
          ).thenAnswer((_) => const Stream.empty());
        },
        build: createBloc,
        act: (bloc) async {
          bloc
            ..add(MyFollowingToggleRequested(validPubkey('user')))
            ..add(MyFollowingToggleRequested(validPubkey('user')));
          await Future<void>.delayed(const Duration(milliseconds: 100));
        },
        verify: (_) {
          verify(
            () => mockFollowRepository.toggleFollow(validPubkey('user')),
          ).called(1);
        },
      );
    });

    test('applies live repository updates after initial load', () async {
      final controller = StreamController<List<String>>.broadcast();
      when(
        () => mockFollowRepository.followingStream,
      ).thenAnswer((_) => controller.stream);
      when(
        () => mockFollowRepository.watchMyFollowingCached(),
      ).thenAnswer((_) => const Stream.empty());

      final bloc = createBloc();
      bloc.add(const MyFollowingListLoadRequested());
      await Future<void>.delayed(Duration.zero);

      controller.add([validPubkey('live1'), validPubkey('live2')]);
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.status, MyFollowingStatus.success);
      // A follow the repository appended is the newest, so it leads.
      expect(bloc.state.followingPubkeys, [
        validPubkey('live2'),
        validPubkey('live1'),
      ]);

      await bloc.close();
      await controller.close();
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
                  pubkeys: [validPubkey('following1'), validPubkey('toBlock')],
                  count: 2,
                ),
              ),
            ),
          );
        },
        build: createBloc,
        act: (bloc) async {
          bloc.add(const MyFollowingListLoadRequested());
          await Future<void>.delayed(Duration.zero);
          when(
            () => mockBlocklistRepository.isBlocked(validPubkey('toBlock')),
          ).thenReturn(true);
          bloc.add(const MyFollowingBlocklistChanged());
        },
        verify: (bloc) {
          expect(
            bloc.state.followingPubkeys,
            isNot(contains(validPubkey('toBlock'))),
          );
          expect(
            bloc.state.followingPubkeys,
            contains(validPubkey('following1')),
          );
        },
      );
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
          await Future<void>.delayed(Duration.zero);
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
          await Future<void>.delayed(Duration.zero);
          bloc.add(
            const MyFollowingSortOrderChanged(FollowSortOrder.oldestFirst),
          );
          await Future<void>.delayed(Duration.zero);
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
          await Future<void>.delayed(Duration.zero);
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
          await Future<void>.delayed(Duration.zero);
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
        'keeps the picked order when the repository pushes a live update',
        setUp: stubLoadedFollowing,
        build: createBloc,
        act: (bloc) async {
          bloc.add(const MyFollowingListLoadRequested());
          await Future<void>.delayed(Duration.zero);
          bloc.add(
            const MyFollowingSortOrderChanged(FollowSortOrder.oldestFirst),
          );
          await Future<void>.delayed(Duration.zero);
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
