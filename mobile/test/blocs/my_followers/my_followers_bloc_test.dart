// ABOUTME: Tests for MyFollowersBloc - current user's followers list
// ABOUTME: Tests loading from repository stream and blocklist filtering

import 'package:bloc_test/bloc_test.dart';
import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/follow_list_sort.dart';
import 'package:openvine/blocs/my_followers/my_followers_bloc.dart';
import 'package:user_ranking/user_ranking.dart';

import '../../helpers/test_user_ranking_loader.dart';

class _MockFollowRepository extends Mock implements FollowRepository {}

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

void main() {
  group(MyFollowersBloc, () {
    test('default sort is smart', () {
      expect(const MyFollowersState().sortOrder.name, 'smart');
    });

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
      when(
        () => mockBlocklistRepository.isFollowSevered(any()),
      ).thenReturn(false);
    });

    MyFollowersBloc createBloc() => MyFollowersBloc(
      rankForList: true,
      rankingSignalsLoader: testUserRankingLoader(),
      followRepository: mockFollowRepository,
      contentBlocklistRepository: mockBlocklistRepository,
    );

    test('initial state is initial with empty list', () async {
      final bloc = createBloc();
      expect(bloc.state, const MyFollowersState());
      await bloc.close();
    });

    group('MyFollowersListLoadRequested', () {
      blocTest<MyFollowersBloc, MyFollowersState>(
        'emits [loading, success] when no cache exists',
        setUp: () {
          when(() => mockFollowRepository.watchMyFollowersCached()).thenAnswer(
            (_) => Stream.value(
              CacheResult.live(
                FollowersSnapshot(
                  pubkeys: [validPubkey('follower1'), validPubkey('follower2')],
                  count: 2,
                ),
              ),
            ),
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(const MyFollowersListLoadRequested()),
        expect: () => [
          const MyFollowersState(status: MyFollowersStatus.loading),
          MyFollowersState(
            isSmartOrderReady: true,
            smartOrder: ([
              validPubkey('follower1'),
              validPubkey('follower2'),
            ]..sort()),
            rankingSignals: {
              for (final key in [
                validPubkey('follower1'),
                validPubkey('follower2'),
              ])
                key: UserRankingSignals(pubkey: key),
            },

            status: MyFollowersStatus.success,
            followersPubkeys: [
              validPubkey('follower1'),
              validPubkey('follower2'),
            ],
            rawFollowersPubkeys: [
              validPubkey('follower1'),
              validPubkey('follower2'),
            ],
            authoritativeFollowerCount: 2,
          ),
        ],
      );

      blocTest<MyFollowersBloc, MyFollowersState>(
        'emits [loading, cached, fresh] when cache yields then fresh data',
        setUp: () {
          when(() => mockFollowRepository.watchMyFollowersCached()).thenAnswer(
            (_) => Stream.fromIterable([
              CacheResult.live(
                FollowersSnapshot(pubkeys: [validPubkey('old')], count: 1),
              ),
              CacheResult.live(
                FollowersSnapshot(
                  pubkeys: [validPubkey('follower1'), validPubkey('follower2')],
                  count: 2,
                ),
              ),
            ]),
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(const MyFollowersListLoadRequested()),
        expect: () => [
          const MyFollowersState(status: MyFollowersStatus.loading),
          MyFollowersState(
            isSmartOrderReady: true,
            smartOrder: ([validPubkey('old')]..sort()),
            rankingSignals: {
              for (final key in [validPubkey('old')])
                key: UserRankingSignals(pubkey: key),
            },

            status: MyFollowersStatus.success,
            followersPubkeys: [validPubkey('old')],
            rawFollowersPubkeys: [validPubkey('old')],
            authoritativeFollowerCount: 1,
          ),
          MyFollowersState(
            isSmartOrderReady: true,
            smartOrder: ([
              validPubkey('follower1'),
              validPubkey('follower2'),
            ]..sort()),
            rankingSignals: {
              for (final key in [
                validPubkey('follower1'),
                validPubkey('follower2'),
              ])
                key: UserRankingSignals(pubkey: key),
            },

            status: MyFollowersStatus.success,
            followersPubkeys: [
              validPubkey('follower1'),
              validPubkey('follower2'),
            ],
            rawFollowersPubkeys: [
              validPubkey('follower1'),
              validPubkey('follower2'),
            ],
            authoritativeFollowerCount: 2,
          ),
        ],
      );

      blocTest<MyFollowersBloc, MyFollowersState>(
        'uses higher count from service when list is incomplete',
        setUp: () {
          when(() => mockFollowRepository.watchMyFollowersCached()).thenAnswer(
            (_) => Stream.value(
              CacheResult.live(
                FollowersSnapshot(
                  pubkeys: [validPubkey('follower1')],
                  count: 500,
                ),
              ),
            ),
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(const MyFollowersListLoadRequested()),
        expect: () => [
          const MyFollowersState(status: MyFollowersStatus.loading),
          MyFollowersState(
            isSmartOrderReady: true,
            smartOrder: ([validPubkey('follower1')]..sort()),
            rankingSignals: {
              for (final key in [validPubkey('follower1')])
                key: UserRankingSignals(pubkey: key),
            },

            status: MyFollowersStatus.success,
            followersPubkeys: [validPubkey('follower1')],
            rawFollowersPubkeys: [validPubkey('follower1')],
            authoritativeFollowerCount: 500,
          ),
        ],
      );

      blocTest<MyFollowersBloc, MyFollowersState>(
        'emits [loading, success] with empty list when no followers',
        setUp: () {
          when(
            () => mockFollowRepository.watchMyFollowersCached(),
          ).thenAnswer(
            (_) => Stream.value(
              const CacheResult.live(
                FollowersSnapshot(pubkeys: <String>[], count: 0),
              ),
            ),
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(const MyFollowersListLoadRequested()),
        expect: () => [
          const MyFollowersState(status: MyFollowersStatus.loading),
          MyFollowersState(
            isSmartOrderReady: true,
            smartOrder: (<String>[]..sort()),
            rankingSignals: {
              for (final key in <String>[])
                key: UserRankingSignals(pubkey: key),
            },
            status: MyFollowersStatus.success,
          ),
        ],
      );

      blocTest<MyFollowersBloc, MyFollowersState>(
        'emits [loading, failure] when stream throws and no data',
        setUp: () {
          when(
            () => mockFollowRepository.watchMyFollowersCached(),
          ).thenAnswer(
            (_) => Stream<CacheResult<FollowersSnapshot>>.error(
              Exception('Network error'),
            ),
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(const MyFollowersListLoadRequested()),
        expect: () => [
          const MyFollowersState(status: MyFollowersStatus.loading),
          const MyFollowersState(status: MyFollowersStatus.failure),
        ],
      );

      blocTest<MyFollowersBloc, MyFollowersState>(
        'keeps cached data when stream errors after first yield',
        setUp: () {
          when(() => mockFollowRepository.watchMyFollowersCached()).thenAnswer((
            _,
          ) async* {
            yield CacheResult.live(
              FollowersSnapshot(pubkeys: [validPubkey('cached')], count: 1),
            );
            throw Exception('Network error');
          });
        },
        build: createBloc,
        act: (bloc) => bloc.add(const MyFollowersListLoadRequested()),
        expect: () => [
          const MyFollowersState(status: MyFollowersStatus.loading),
          MyFollowersState(
            isSmartOrderReady: true,
            smartOrder: ([validPubkey('cached')]..sort()),
            rankingSignals: {
              for (final key in [validPubkey('cached')])
                key: UserRankingSignals(pubkey: key),
            },

            status: MyFollowersStatus.success,
            followersPubkeys: [validPubkey('cached')],
            rawFollowersPubkeys: [validPubkey('cached')],
            authoritativeFollowerCount: 1,
          ),
        ],
      );

      blocTest<MyFollowersBloc, MyFollowersState>(
        'filters blocked users from stream results',
        setUp: () {
          final blocked = validPubkey('blocked');
          when(
            () => mockBlocklistRepository.isBlocked(blocked),
          ).thenReturn(true);

          when(() => mockFollowRepository.watchMyFollowersCached()).thenAnswer(
            (_) => Stream.value(
              CacheResult.live(
                FollowersSnapshot(
                  pubkeys: [blocked, validPubkey('ok')],
                  count: 2,
                ),
              ),
            ),
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(const MyFollowersListLoadRequested()),
        expect: () => [
          const MyFollowersState(status: MyFollowersStatus.loading),
          MyFollowersState(
            isSmartOrderReady: true,
            smartOrder: ([validPubkey('blocked'), validPubkey('ok')]..sort()),
            rankingSignals: {
              for (final key in [validPubkey('blocked'), validPubkey('ok')])
                key: UserRankingSignals(pubkey: key),
            },

            status: MyFollowersStatus.success,
            followersPubkeys: [validPubkey('ok')],
            rawFollowersPubkeys: [validPubkey('blocked'), validPubkey('ok')],
            authoritativeFollowerCount: 2,
          ),
        ],
      );
    });

    group('MyFollowersBlocklistChanged', () {
      blocTest<MyFollowersBloc, MyFollowersState>(
        're-filters followers when blocklist changes',
        setUp: () {
          when(() => mockFollowRepository.watchMyFollowersCached()).thenAnswer(
            (_) => Stream.value(
              CacheResult.live(
                FollowersSnapshot(
                  pubkeys: [validPubkey('a'), validPubkey('b')],
                  count: 2,
                ),
              ),
            ),
          );
        },
        build: createBloc,
        act: (bloc) async {
          bloc.add(const MyFollowersListLoadRequested());
          await pumpEventQueue();
          // Now block user 'a'
          when(
            () => mockBlocklistRepository.isBlocked(validPubkey('a')),
          ).thenReturn(true);
          bloc.add(const MyFollowersBlocklistChanged());
        },
        skip: 2, // skip loading + initial success
        expect: () => [
          MyFollowersState(
            eligibilityRevision: 1,
            isSmartOrderReady: true,
            smartOrder: ([validPubkey('a'), validPubkey('b')]..sort()),
            rankingSignals: {
              for (final key in [validPubkey('a'), validPubkey('b')])
                key: UserRankingSignals(pubkey: key),
            },

            status: MyFollowersStatus.success,
            followersPubkeys: [validPubkey('b')],
            rawFollowersPubkeys: [validPubkey('a'), validPubkey('b')],
            authoritativeFollowerCount: 2,
          ),
        ],
      );

      blocTest<MyFollowersBloc, MyFollowersState>(
        'invalidates a pending ranking before the list reaches success',
        build: createBloc,
        act: (bloc) => bloc.add(const MyFollowersBlocklistChanged()),
        expect: () => [const MyFollowersState(eligibilityRevision: 1)],
      );
    });

    group('MyFollowersSortOrderChanged', () {
      /// Two dated followers ahead of one the REST source reported undated.
      void stubLoadedFollowers() {
        when(() => mockFollowRepository.watchMyFollowersCached()).thenAnswer(
          (_) => Stream.value(
            CacheResult.live(
              FollowersSnapshot(
                pubkeys: [
                  validPubkey('newest'),
                  validPubkey('oldest'),
                  validPubkey('undated'),
                ],
                count: 3,
                datedCount: 2,
              ),
            ),
          ),
        );
      }

      blocTest<MyFollowersBloc, MyFollowersState>(
        'flips the dated followers and leaves the undated one last',
        setUp: stubLoadedFollowers,
        build: createBloc,
        act: (bloc) async {
          bloc.add(const MyFollowersListLoadRequested());
          await pumpEventQueue();
          bloc.add(
            const MyFollowersSortOrderChanged(FollowListSort.oldestFirst),
          );
        },
        skip: 2,
        expect: () => [
          MyFollowersState(
            isSmartOrderReady: true,
            smartOrder: ([
              validPubkey('newest'),
              validPubkey('oldest'),
              validPubkey('undated'),
            ]..sort()),
            rankingSignals: {
              for (final key in [
                validPubkey('newest'),
                validPubkey('oldest'),
                validPubkey('undated'),
              ])
                key: UserRankingSignals(pubkey: key),
            },

            status: MyFollowersStatus.success,
            sortOrder: FollowListSort.oldestFirst,
            followersPubkeys: [
              validPubkey('oldest'),
              validPubkey('newest'),
              validPubkey('undated'),
            ],
            rawFollowersPubkeys: [
              validPubkey('newest'),
              validPubkey('oldest'),
              validPubkey('undated'),
            ],
            rawDatedCount: 2,
            authoritativeFollowerCount: 3,
          ),
        ],
      );

      blocTest<MyFollowersBloc, MyFollowersState>(
        're-orders without asking the repository again',
        setUp: stubLoadedFollowers,
        build: createBloc,
        act: (bloc) async {
          bloc.add(const MyFollowersListLoadRequested());
          await pumpEventQueue();
          bloc.add(
            const MyFollowersSortOrderChanged(FollowListSort.oldestFirst),
          );
          await pumpEventQueue();
        },
        verify: (_) {
          verify(() => mockFollowRepository.watchMyFollowersCached()).called(1);
        },
      );

      blocTest<MyFollowersBloc, MyFollowersState>(
        'ignores a re-pick of the active order',
        setUp: stubLoadedFollowers,
        build: createBloc,
        act: (bloc) async {
          bloc.add(const MyFollowersListLoadRequested());
          await pumpEventQueue();
          bloc.add(
            const MyFollowersSortOrderChanged(FollowListSort.smart),
          );
        },
        skip: 2,
        expect: () => <MyFollowersState>[],
      );

      blocTest<MyFollowersBloc, MyFollowersState>(
        'remembers a sort picked before the list has loaded',
        setUp: stubLoadedFollowers,
        build: createBloc,
        act: (bloc) async {
          bloc.add(
            const MyFollowersSortOrderChanged(FollowListSort.oldestFirst),
          );
          await pumpEventQueue();
          bloc.add(const MyFollowersListLoadRequested());
        },
        skip: 2,
        expect: () => [
          MyFollowersState(
            isSmartOrderReady: true,
            smartOrder: ([
              validPubkey('newest'),
              validPubkey('oldest'),
              validPubkey('undated'),
            ]..sort()),
            rankingSignals: {
              for (final key in [
                validPubkey('newest'),
                validPubkey('oldest'),
                validPubkey('undated'),
              ])
                key: UserRankingSignals(pubkey: key),
            },

            status: MyFollowersStatus.success,
            sortOrder: FollowListSort.oldestFirst,
            followersPubkeys: [
              validPubkey('oldest'),
              validPubkey('newest'),
              validPubkey('undated'),
            ],
            rawFollowersPubkeys: [
              validPubkey('newest'),
              validPubkey('oldest'),
              validPubkey('undated'),
            ],
            rawDatedCount: 2,
            authoritativeFollowerCount: 3,
          ),
        ],
      );

      blocTest<MyFollowersBloc, MyFollowersState>(
        'keeps blocked followers out of the flipped list',
        setUp: () {
          stubLoadedFollowers();
          when(
            () => mockBlocklistRepository.isBlocked(validPubkey('newest')),
          ).thenReturn(true);
        },
        build: createBloc,
        act: (bloc) async {
          bloc.add(const MyFollowersListLoadRequested());
          await pumpEventQueue();
          bloc.add(
            const MyFollowersSortOrderChanged(FollowListSort.oldestFirst),
          );
        },
        skip: 2,
        expect: () => [
          MyFollowersState(
            isSmartOrderReady: true,
            smartOrder: ([
              validPubkey('newest'),
              validPubkey('oldest'),
              validPubkey('undated'),
            ]..sort()),
            rankingSignals: {
              for (final key in [
                validPubkey('newest'),
                validPubkey('oldest'),
                validPubkey('undated'),
              ])
                key: UserRankingSignals(pubkey: key),
            },

            status: MyFollowersStatus.success,
            sortOrder: FollowListSort.oldestFirst,
            followersPubkeys: [
              validPubkey('oldest'),
              validPubkey('undated'),
            ],
            rawFollowersPubkeys: [
              validPubkey('newest'),
              validPubkey('oldest'),
              validPubkey('undated'),
            ],
            rawDatedCount: 2,
            authoritativeFollowerCount: 3,
          ),
        ],
      );
    });
  });

  group(MyFollowersState, () {
    test('supports value equality', () {
      const state1 = MyFollowersState(
        status: MyFollowersStatus.success,
        followersPubkeys: ['pubkey1'],
      );
      const state2 = MyFollowersState(
        status: MyFollowersStatus.success,
        followersPubkeys: ['pubkey1'],
      );

      expect(state1, equals(state2));
    });

    test('copyWith creates copy with updated values', () {
      const state = MyFollowersState();

      final updated = state.copyWith(
        status: MyFollowersStatus.success,
        followersPubkeys: ['pubkey1'],
      );

      expect(updated.status, MyFollowersStatus.success);
      expect(updated.followersPubkeys, ['pubkey1']);
    });

    test('copyWith preserves values when not specified', () {
      const state = MyFollowersState(
        status: MyFollowersStatus.success,
        followersPubkeys: ['pubkey1'],
      );

      final updated = state.copyWith();

      expect(updated.status, MyFollowersStatus.success);
      expect(updated.followersPubkeys, ['pubkey1']);
    });

    test('props includes all fields', () {
      const state = MyFollowersState(
        status: MyFollowersStatus.success,
        followersPubkeys: ['pubkey1'],
        authoritativeFollowerCount: 10,
      );

      expect(state.props, [
        MyFollowersStatus.success,
        ['pubkey1'],
        <String>[], // rawFollowersPubkeys
        0, // rawDatedCount
        FollowListSort.smart,
        10,
        false,
        <String>[],
        <String, UserRankingSignals>{},
        false,
        0, // isRefreshing
      ]);
    });
  });
}
