import 'package:bloc_test/bloc_test.dart';
import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/list_search/list_search_bloc.dart';
import 'package:people_lists_repository/people_lists_repository.dart';

class _MockCuratedListRepository extends Mock
    implements CuratedListRepository {}

class _MockPeopleListsRepository extends Mock
    implements PeopleListsRepository {}

// Full-length 64-char Nostr pubkeys — never truncate.
const String _ownerA =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const String _ownerB =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const String _authorOne =
    '1111111111111111111111111111111111111111111111111111111111111111';
const String _memberOne =
    '2222222222222222222222222222222222222222222222222222222222222222';
const String _memberTwo =
    '3333333333333333333333333333333333333333333333333333333333333333';

void main() {
  group(ListSearchBloc, () {
    late _MockCuratedListRepository curatedListRepository;
    late _MockPeopleListsRepository peopleListsRepository;

    final now = DateTime(2024, 6, 15);
    final testCuratedList = CuratedList(
      id: 'cl1',
      name: 'Top Videos',
      pubkey: _authorOne,
      videoEventIds: const ['vid1'],
      createdAt: now,
      updatedAt: now,
    );

    final testUserList = UserList(
      id: 'ul1',
      name: 'Cool People',
      pubkeys: const [_memberOne, _memberTwo],
      createdAt: now,
      updatedAt: now,
    );

    final testPeopleResult = PeopleListSearchResult(
      ownerPubkey: _ownerA,
      list: testUserList,
    );

    setUp(() {
      curatedListRepository = _MockCuratedListRepository();
      peopleListsRepository = _MockPeopleListsRepository();

      when(
        () => curatedListRepository.searchAllLists(any()),
      ).thenAnswer((_) => const Stream.empty());

      when(
        () => peopleListsRepository.searchPublicLists(
          any(),
          viewerPubkey: any(named: 'viewerPubkey'),
        ),
      ).thenAnswer((_) => const Stream.empty());
    });

    ListSearchBloc buildBloc({
      bool peopleEnabled = false,
      String? viewerPubkey,
    }) => ListSearchBloc(
      curatedListRepository: curatedListRepository,
      peopleListsRepository: peopleListsRepository,
      peopleListSearchEnabled: peopleEnabled,
      viewerPubkey: viewerPubkey,
    );

    test('initial state is $ListSearchState', () {
      expect(buildBloc().state, equals(const ListSearchState()));
    });

    group(ListSearchQueryChanged, () {
      blocTest<ListSearchBloc, ListSearchState>(
        'emits loading then success when video query matches',
        setUp: () {
          when(
            () => curatedListRepository.searchAllLists('videos'),
          ).thenAnswer((_) => Stream.value([testCuratedList]));
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const ListSearchQueryChanged('videos')),
        wait: const Duration(milliseconds: 400),
        expect: () => [
          const ListSearchState(
            status: ListSearchStatus.loading,
            query: 'videos',
          ),
          isA<ListSearchState>()
              .having((s) => s.status, 'status', ListSearchStatus.success)
              .having((s) => s.query, 'query', 'videos')
              .having((s) => s.videoResults, 'videoResults', [testCuratedList]),
        ],
      );

      blocTest<ListSearchBloc, ListSearchState>(
        'searches people lists as the viewer',
        setUp: () {
          when(
            () => peopleListsRepository.searchPublicLists(
              'people',
              viewerPubkey: 'a' * 64,
            ),
          ).thenAnswer((_) => Stream.value([testPeopleResult]));
        },
        build: () => buildBloc(peopleEnabled: true, viewerPubkey: 'a' * 64),
        act: (bloc) => bloc.add(const ListSearchQueryChanged('people')),
        wait: const Duration(milliseconds: 400),
        verify: (_) {
          verify(
            () => peopleListsRepository.searchPublicLists(
              'people',
              viewerPubkey: 'a' * 64,
            ),
          ).called(1);
        },
      );

      blocTest<ListSearchBloc, ListSearchState>(
        'emits people results when people list search is enabled',
        setUp: () {
          when(
            () => peopleListsRepository.searchPublicLists('people'),
          ).thenAnswer((_) => Stream.value([testPeopleResult]));
        },
        build: () => buildBloc(peopleEnabled: true),
        act: (bloc) => bloc.add(const ListSearchQueryChanged('people')),
        wait: const Duration(milliseconds: 400),
        expect: () => [
          const ListSearchState(
            status: ListSearchStatus.loading,
            query: 'people',
          ),
          isA<ListSearchState>()
              .having((s) => s.status, 'status', ListSearchStatus.success)
              .having(
                (s) => s.peopleResults,
                'peopleResults',
                [testPeopleResult],
              ),
        ],
      );

      blocTest<ListSearchBloc, ListSearchState>(
        'does not search people lists when flag is disabled',
        setUp: () {
          when(
            () => curatedListRepository.searchAllLists('mixed'),
          ).thenAnswer((_) => Stream.value([testCuratedList]));
        },
        build: buildBloc, // peopleEnabled: false by default
        act: (bloc) => bloc.add(const ListSearchQueryChanged('mixed')),
        wait: const Duration(milliseconds: 400),
        verify: (bloc) {
          verifyNever(
            () => peopleListsRepository.searchPublicLists(any()),
          );
          expect(bloc.state.peopleResults, isEmpty);
        },
      );

      blocTest<ListSearchBloc, ListSearchState>(
        'merges video and people results when both enabled',
        setUp: () {
          when(
            () => curatedListRepository.searchAllLists('mixed'),
          ).thenAnswer((_) => Stream.value([testCuratedList]));
          when(
            () => peopleListsRepository.searchPublicLists('mixed'),
          ).thenAnswer((_) => Stream.value([testPeopleResult]));
        },
        build: () => buildBloc(peopleEnabled: true),
        act: (bloc) => bloc.add(const ListSearchQueryChanged('mixed')),
        wait: const Duration(milliseconds: 400),
        expect: () => [
          const ListSearchState(
            status: ListSearchStatus.loading,
            query: 'mixed',
          ),
          // Two success states: one per stream emission.
          isA<ListSearchState>().having(
            (s) => s.status,
            'status',
            ListSearchStatus.success,
          ),
          isA<ListSearchState>().having(
            (s) => s.status,
            'status',
            ListSearchStatus.success,
          ),
        ],
        verify: (bloc) {
          expect(bloc.state.videoResults, contains(testCuratedList));
          expect(bloc.state.peopleResults, contains(testPeopleResult));
        },
      );

      blocTest<ListSearchBloc, ListSearchState>(
        'emits success with empty results when no matches',
        build: buildBloc,
        act: (bloc) => bloc.add(const ListSearchQueryChanged('xyz')),
        wait: const Duration(milliseconds: 400),
        expect: () => [
          const ListSearchState(status: ListSearchStatus.loading, query: 'xyz'),
          const ListSearchState(status: ListSearchStatus.success, query: 'xyz'),
        ],
      );

      blocTest<ListSearchBloc, ListSearchState>(
        'resets to initial state for empty query',
        seed: () => ListSearchState(
          status: ListSearchStatus.success,
          query: 'old',
          videoResults: [testCuratedList],
          peopleResults: [testPeopleResult],
        ),
        build: buildBloc,
        act: (bloc) => bloc.add(const ListSearchQueryChanged('')),
        wait: const Duration(milliseconds: 400),
        expect: () => [const ListSearchState()],
      );

      blocTest<ListSearchBloc, ListSearchState>(
        'resets to initial state for short query',
        build: buildBloc,
        act: (bloc) => bloc.add(const ListSearchQueryChanged('a')),
        wait: const Duration(milliseconds: 400),
        expect: () => [const ListSearchState()],
      );

      blocTest<ListSearchBloc, ListSearchState>(
        'emits failure on exception from video stream',
        setUp: () {
          when(
            () => curatedListRepository.searchAllLists(any()),
          ).thenAnswer((_) => Stream.error(Exception('relay down')));
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const ListSearchQueryChanged('test')),
        wait: const Duration(milliseconds: 400),
        expect: () => [
          const ListSearchState(
            status: ListSearchStatus.loading,
            query: 'test',
          ),
          const ListSearchState(
            status: ListSearchStatus.failure,
            query: 'test',
          ),
        ],
        errors: () => [isA<Exception>()],
      );

      blocTest<ListSearchBloc, ListSearchState>(
        'emits failure on exception from people stream',
        setUp: () {
          when(
            () => curatedListRepository.searchAllLists(any()),
          ).thenAnswer((_) => const Stream.empty());
          when(
            () => peopleListsRepository.searchPublicLists(any()),
          ).thenAnswer((_) => Stream.error(Exception('relay down')));
        },
        build: () => buildBloc(peopleEnabled: true),
        act: (bloc) => bloc.add(const ListSearchQueryChanged('test')),
        wait: const Duration(milliseconds: 400),
        expect: () => [
          const ListSearchState(
            status: ListSearchStatus.loading,
            query: 'test',
          ),
          const ListSearchState(
            status: ListSearchStatus.failure,
            query: 'test',
          ),
        ],
        errors: () => [isA<Exception>()],
      );

      blocTest<ListSearchBloc, ListSearchState>(
        're-searches when same query is dispatched in failure state',
        setUp: () {
          when(
            () => curatedListRepository.searchAllLists('test'),
          ).thenAnswer((_) => Stream.value([testCuratedList]));
        },
        build: buildBloc,
        seed: () => const ListSearchState(
          status: ListSearchStatus.failure,
          query: 'test',
        ),
        act: (bloc) => bloc.add(const ListSearchQueryChanged('test')),
        wait: const Duration(milliseconds: 400),
        expect: () => [
          const ListSearchState(
            status: ListSearchStatus.loading,
            query: 'test',
          ),
          isA<ListSearchState>()
              .having((s) => s.status, 'status', ListSearchStatus.success)
              .having((s) => s.videoResults, 'videoResults', [testCuratedList]),
        ],
      );

      blocTest<ListSearchBloc, ListSearchState>(
        'yields progressive video results as relay stream emits',
        setUp: () {
          final list2 = CuratedList(
            id: 'cl2',
            name: 'More Videos',
            pubkey: _ownerB,
            videoEventIds: const ['vid2'],
            createdAt: now,
            updatedAt: now,
          );
          when(() => curatedListRepository.searchAllLists('vid')).thenAnswer(
            (_) => Stream.fromIterable([
              [testCuratedList],
              [testCuratedList, list2],
            ]),
          );
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const ListSearchQueryChanged('vid')),
        wait: const Duration(milliseconds: 400),
        expect: () => [
          const ListSearchState(status: ListSearchStatus.loading, query: 'vid'),
          isA<ListSearchState>().having(
            (s) => s.videoResults.length,
            'videoResults.length',
            1,
          ),
          isA<ListSearchState>().having(
            (s) => s.videoResults.length,
            'videoResults.length',
            2,
          ),
        ],
      );
    });

    group(ListSearchBlocklistChanged, () {
      blocTest<ListSearchBloc, ListSearchState>(
        're-runs the current search, bypassing the same-query guard',
        build: buildBloc,
        seed: () => const ListSearchState(
          status: ListSearchStatus.success,
          query: 'videos',
        ),
        act: (bloc) => bloc.add(const ListSearchBlocklistChanged()),
        expect: () => [
          isA<ListSearchState>().having(
            (s) => s.status,
            'status',
            ListSearchStatus.loading,
          ),
          isA<ListSearchState>().having(
            (s) => s.status,
            'status',
            ListSearchStatus.success,
          ),
        ],
        verify: (_) {
          verify(
            () => curatedListRepository.searchAllLists('videos'),
          ).called(1);
        },
      );

      blocTest<ListSearchBloc, ListSearchState>(
        'does nothing when no search is active',
        build: buildBloc,
        act: (bloc) => bloc.add(const ListSearchBlocklistChanged()),
        expect: () => <ListSearchState>[],
      );
    });

    group(ListSearchCleared, () {
      blocTest<ListSearchBloc, ListSearchState>(
        'resets to initial state',
        seed: () => ListSearchState(
          status: ListSearchStatus.success,
          query: 'test',
          videoResults: [testCuratedList],
          peopleResults: [testPeopleResult],
        ),
        build: buildBloc,
        act: (bloc) => bloc.add(const ListSearchCleared()),
        expect: () => [const ListSearchState()],
      );
    });

    group('ListSearchState', () {
      test('copyWith preserves peopleResults when not specified', () {
        final state = ListSearchState(
          status: ListSearchStatus.success,
          query: 'q',
          videoResults: [testCuratedList],
          peopleResults: [testPeopleResult],
        );
        final updated = state.copyWith(query: 'q2');
        expect(updated.peopleResults, equals([testPeopleResult]));
      });

      test('props includes videoResults and peopleResults', () {
        final state1 = ListSearchState(
          videoResults: [testCuratedList],
          peopleResults: [testPeopleResult],
        );
        final state2 = ListSearchState(
          videoResults: [testCuratedList],
          peopleResults: [testPeopleResult],
        );
        const state3 = ListSearchState();
        expect(state1, equals(state2));
        expect(state1, isNot(equals(state3)));
      });
    });
  });
}
