// ABOUTME: Tests for OthersFollowingBloc - another user's following list
// ABOUTME: Tests loading from repository with CacheResult, error handling, and blocklist filtering

import 'package:bloc_test/bloc_test.dart';
import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/others_following/others_following_bloc.dart';

class _MockFollowRepository extends Mock implements FollowRepository {}

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

void main() {
  group(OthersFollowingBloc, () {
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

      // Default: nothing is blocked or severed
      when(() => mockBlocklistRepository.isBlocked(any())).thenReturn(false);
      when(
        () => mockBlocklistRepository.isFollowSevered(any()),
      ).thenReturn(false);
    });

    OthersFollowingBloc createBloc() => OthersFollowingBloc(
      followRepository: mockFollowRepository,
      contentBlocklistRepository: mockBlocklistRepository,
      currentUserPubkey: validPubkey('currentUser'),
    );

    test('initial state is initial with empty list', () async {
      final bloc = createBloc();
      expect(bloc.state, const OthersFollowingState());
      await bloc.close();
    });

    group('OthersFollowingListLoadRequested', () {
      blocTest<OthersFollowingBloc, OthersFollowingState>(
        'emits success with following pubkeys from repository',
        setUp: () {
          when(
            () => mockFollowRepository.watchOthersFollowingCached(
              any(),
              forceRefresh: any(named: 'forceRefresh'),
            ),
          ).thenAnswer(
            (_) => Stream<CacheResult<FollowingSnapshot>>.value(
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
        act: (bloc) =>
            bloc.add(OthersFollowingListLoadRequested(validPubkey('target'))),
        verify: (bloc) {
          expect(bloc.state.status, OthersFollowingStatus.success);
          // Newest follow first: the repository hands over the contact list's
          // `p` tags in follow order, which NIP-02 says runs oldest to newest.
          expect(bloc.state.followingPubkeys, [
            validPubkey('following2'),
            validPubkey('following1'),
          ]);
          expect(bloc.state.targetPubkey, validPubkey('target'));
        },
      );

      blocTest<OthersFollowingBloc, OthersFollowingState>(
        'orders newest follow first, matching the own-following screen',
        setUp: () {
          when(
            () => mockFollowRepository.watchOthersFollowingCached(
              any(),
              forceRefresh: any(named: 'forceRefresh'),
            ),
          ).thenAnswer(
            (_) => Stream<CacheResult<FollowingSnapshot>>.value(
              CacheResult.live(
                FollowingSnapshot(
                  pubkeys: [
                    validPubkey('oldest'),
                    validPubkey('middle'),
                    validPubkey('newest'),
                  ],
                  count: 3,
                ),
              ),
            ),
          );
        },
        build: createBloc,
        act: (bloc) =>
            bloc.add(OthersFollowingListLoadRequested(validPubkey('target'))),
        verify: (bloc) {
          // This screen has no sort control, but it still has to agree with
          // MyFollowingBloc's default — otherwise the same list reads
          // oldest-first for someone else and newest-first for yourself.
          expect(bloc.state.followingPubkeys, [
            validPubkey('newest'),
            validPubkey('middle'),
            validPubkey('oldest'),
          ]);
        },
      );

      blocTest<OthersFollowingBloc, OthersFollowingState>(
        'emits isRefreshing=false when data is fresh (no cache)',
        setUp: () {
          when(
            () => mockFollowRepository.watchOthersFollowingCached(
              any(),
              forceRefresh: any(named: 'forceRefresh'),
            ),
          ).thenAnswer(
            (_) => Stream<CacheResult<FollowingSnapshot>>.value(
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
        act: (bloc) =>
            bloc.add(OthersFollowingListLoadRequested(validPubkey('target'))),
        verify: (bloc) {
          expect(bloc.state.isRefreshing, isFalse);
        },
      );

      blocTest<OthersFollowingBloc, OthersFollowingState>(
        'emits success with empty list when following is empty',
        setUp: () {
          when(
            () => mockFollowRepository.watchOthersFollowingCached(
              any(),
              forceRefresh: any(named: 'forceRefresh'),
            ),
          ).thenAnswer(
            (_) => Stream<CacheResult<FollowingSnapshot>>.value(
              const CacheResult.live(
                FollowingSnapshot(pubkeys: <String>[], count: 0),
              ),
            ),
          );
        },
        build: createBloc,
        act: (bloc) =>
            bloc.add(OthersFollowingListLoadRequested(validPubkey('target'))),
        verify: (bloc) {
          expect(bloc.state.status, OthersFollowingStatus.success);
          expect(bloc.state.followingPubkeys, isEmpty);
        },
      );

      blocTest<OthersFollowingBloc, OthersFollowingState>(
        'emits failure when repository throws',
        setUp: () {
          when(
            () => mockFollowRepository.watchOthersFollowingCached(
              any(),
              forceRefresh: any(named: 'forceRefresh'),
            ),
          ).thenThrow(Exception('Network error'));
        },
        build: createBloc,
        act: (bloc) =>
            bloc.add(OthersFollowingListLoadRequested(validPubkey('target'))),
        verify: (bloc) {
          expect(bloc.state.status, OthersFollowingStatus.failure);
          expect(bloc.state.isRefreshing, isFalse);
        },
        errors: () => [isA<Exception>()],
      );

      blocTest<OthersFollowingBloc, OthersFollowingState>(
        'keeps cached data when refresh errors after cached emission',
        setUp: () {
          when(
            () => mockFollowRepository.watchOthersFollowingCached(
              any(),
              forceRefresh: any(named: 'forceRefresh'),
            ),
          ).thenAnswer((_) async* {
            yield CacheResult.cached(
              FollowingSnapshot(pubkeys: [validPubkey('cached')], count: 1),
            );
            throw Exception('Network error');
          });
        },
        build: createBloc,
        act: (bloc) =>
            bloc.add(OthersFollowingListLoadRequested(validPubkey('target'))),
        verify: (bloc) {
          expect(bloc.state.status, OthersFollowingStatus.success);
          expect(bloc.state.followingPubkeys, [validPubkey('cached')]);
          expect(bloc.state.isRefreshing, isFalse);
        },
        errors: () => [isA<Exception>()],
      );

      blocTest<OthersFollowingBloc, OthersFollowingState>(
        'stores targetPubkey in state',
        setUp: () {
          when(
            () => mockFollowRepository.watchOthersFollowingCached(
              any(),
              forceRefresh: any(named: 'forceRefresh'),
            ),
          ).thenAnswer(
            (_) => Stream<CacheResult<FollowingSnapshot>>.value(
              const CacheResult.live(
                FollowingSnapshot(pubkeys: <String>[], count: 0),
              ),
            ),
          );
        },
        build: createBloc,
        act: (bloc) =>
            bloc.add(OthersFollowingListLoadRequested(validPubkey('target'))),
        verify: (bloc) {
          expect(bloc.state.targetPubkey, validPubkey('target'));
        },
      );

      blocTest<OthersFollowingBloc, OthersFollowingState>(
        'forceRefresh still emits success',
        setUp: () {
          when(
            () => mockFollowRepository.watchOthersFollowingCached(
              any(),
              forceRefresh: any(named: 'forceRefresh'),
            ),
          ).thenAnswer(
            (_) => Stream<CacheResult<FollowingSnapshot>>.value(
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
        act: (bloc) => bloc.add(
          OthersFollowingListLoadRequested(
            validPubkey('target'),
            forceRefresh: true,
          ),
        ),
        verify: (bloc) {
          expect(bloc.state.status, OthersFollowingStatus.success);
          expect(bloc.state.followingPubkeys, [validPubkey('following1')]);
        },
      );

      blocTest<OthersFollowingBloc, OthersFollowingState>(
        'second load for different target updates targetPubkey',
        setUp: () {
          when(
            () => mockFollowRepository.watchOthersFollowingCached(
              any(),
              forceRefresh: any(named: 'forceRefresh'),
            ),
          ).thenAnswer(
            (_) => Stream<CacheResult<FollowingSnapshot>>.value(
              const CacheResult.live(
                FollowingSnapshot(pubkeys: <String>[], count: 0),
              ),
            ),
          );
        },
        build: createBloc,
        act: (bloc) async {
          bloc.add(OthersFollowingListLoadRequested(validPubkey('target1')));
          await pumpEventQueue();
          bloc.add(OthersFollowingListLoadRequested(validPubkey('target2')));
        },
        verify: (bloc) {
          expect(bloc.state.targetPubkey, validPubkey('target2'));
        },
      );
    });

    group('blocklist filtering', () {
      blocTest<OthersFollowingBloc, OthersFollowingState>(
        'filters blocked users from following list',
        setUp: () {
          when(
            () => mockBlocklistRepository.isBlocked(validPubkey('blocked')),
          ).thenReturn(true);
          when(
            () => mockFollowRepository.watchOthersFollowingCached(
              any(),
              forceRefresh: any(named: 'forceRefresh'),
            ),
          ).thenAnswer(
            (_) => Stream<CacheResult<FollowingSnapshot>>.value(
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
        act: (bloc) =>
            bloc.add(OthersFollowingListLoadRequested(validPubkey('target'))),
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

      blocTest<OthersFollowingBloc, OthersFollowingState>(
        'hides current user when target is blocked',
        setUp: () {
          when(
            () => mockBlocklistRepository.isBlocked(validPubkey('target')),
          ).thenReturn(true);
          when(
            () => mockFollowRepository.watchOthersFollowingCached(
              any(),
              forceRefresh: any(named: 'forceRefresh'),
            ),
          ).thenAnswer(
            (_) => Stream<CacheResult<FollowingSnapshot>>.value(
              CacheResult.live(
                FollowingSnapshot(
                  pubkeys: [
                    validPubkey('following1'),
                    validPubkey('currentUser'),
                  ],
                  count: 2,
                ),
              ),
            ),
          );
        },
        build: createBloc,
        act: (bloc) =>
            bloc.add(OthersFollowingListLoadRequested(validPubkey('target'))),
        verify: (bloc) {
          expect(
            bloc.state.followingPubkeys,
            isNot(contains(validPubkey('currentUser'))),
          );
          expect(
            bloc.state.followingPubkeys,
            contains(validPubkey('following1')),
          );
        },
      );

      blocTest<OthersFollowingBloc, OthersFollowingState>(
        'OthersFollowingBlocklistChanged re-filters cached pubkeys',
        setUp: () {
          when(
            () => mockFollowRepository.watchOthersFollowingCached(
              any(),
              forceRefresh: any(named: 'forceRefresh'),
            ),
          ).thenAnswer(
            (_) => Stream<CacheResult<FollowingSnapshot>>.value(
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
          bloc.add(OthersFollowingListLoadRequested(validPubkey('target')));
          await pumpEventQueue();
          when(
            () => mockBlocklistRepository.isBlocked(validPubkey('toBlock')),
          ).thenReturn(true);
          bloc.add(const OthersFollowingBlocklistChanged());
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

    group('OthersFollowingState', () {
      test('supports value equality', () {
        const state1 = OthersFollowingState(
          status: OthersFollowingStatus.success,
          followingPubkeys: ['pubkey1'],
          targetPubkey: 'target',
        );
        const state2 = OthersFollowingState(
          status: OthersFollowingStatus.success,
          followingPubkeys: ['pubkey1'],
          targetPubkey: 'target',
        );

        expect(state1, equals(state2));
      });

      test('copyWith preserves values when not specified', () {
        const state = OthersFollowingState(
          status: OthersFollowingStatus.success,
          followingPubkeys: ['pubkey1'],
          targetPubkey: 'target',
        );

        final updated = state.copyWith();

        expect(updated.status, OthersFollowingStatus.success);
        expect(updated.followingPubkeys, ['pubkey1']);
        expect(updated.targetPubkey, 'target');
      });

      test('isRefreshing included in props', () {
        const state1 = OthersFollowingState(isRefreshing: true);
        const state2 = OthersFollowingState();

        expect(state1, isNot(equals(state2)));
      });
    });
  });
}
