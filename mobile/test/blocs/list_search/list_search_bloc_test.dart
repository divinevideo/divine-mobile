import 'dart:async';

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

Matcher _searchState({required ListSearchStatus status, String query = ''}) =>
    isA<ListSearchState>()
        .having((state) => state.status, 'status', status)
        .having((state) => state.query, 'query', query);

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
          isA<ListSearchState>().having(
            (s) => s.requestedQuery,
            'requestedQuery',
            'videos',
          ),
          _searchState(
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
          isA<ListSearchState>().having(
            (s) => s.requestedQuery,
            'requestedQuery',
            'people',
          ),
          _searchState(
            status: ListSearchStatus.loading,
            query: 'people',
          ),
          _searchState(status: ListSearchStatus.loading, query: 'people'),
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
          isA<ListSearchState>().having(
            (s) => s.requestedQuery,
            'requestedQuery',
            'mixed',
          ),
          _searchState(
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
          isA<ListSearchState>().having(
            (s) => s.requestedQuery,
            'requestedQuery',
            'xyz',
          ),
          _searchState(status: ListSearchStatus.loading, query: 'xyz'),
          _searchState(status: ListSearchStatus.success, query: 'xyz'),
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
        expect: () => [
          isA<ListSearchState>().having(
            (s) => s.requestedQuery,
            'requestedQuery',
            '',
          ),
          const ListSearchState(),
        ],
      );

      blocTest<ListSearchBloc, ListSearchState>(
        'resets to initial state for short query',
        build: buildBloc,
        act: (bloc) => bloc.add(const ListSearchQueryChanged('a')),
        wait: const Duration(milliseconds: 400),
        expect: () => [
          isA<ListSearchState>().having(
            (s) => s.requestedQuery,
            'requestedQuery',
            'a',
          ),
          const ListSearchState(),
        ],
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
          isA<ListSearchState>().having(
            (s) => s.requestedQuery,
            'requestedQuery',
            'test',
          ),
          _searchState(
            status: ListSearchStatus.loading,
            query: 'test',
          ),
          _searchState(
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
          isA<ListSearchState>().having(
            (s) => s.requestedQuery,
            'requestedQuery',
            'test',
          ),
          _searchState(
            status: ListSearchStatus.loading,
            query: 'test',
          ),
          _searchState(status: ListSearchStatus.loading, query: 'test'),
          _searchState(
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
          isA<ListSearchState>().having(
            (s) => s.requestedQuery,
            'requestedQuery',
            'test',
          ),
          _searchState(
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
          isA<ListSearchState>().having(
            (s) => s.requestedQuery,
            'requestedQuery',
            'vid',
          ),
          _searchState(status: ListSearchStatus.loading, query: 'vid'),
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

    group('independent source failures', () {
      for (final peopleFailsFirst in [true, false]) {
        test('keeps video results when people fails '
            '${peopleFailsFirst ? "before" : "after"} video results', () async {
          final videos = StreamController<List<CuratedList>>();
          final people = StreamController<List<PeopleListSearchResult>>();
          when(() => curatedListRepository.searchAllLists('mixed'))
              .thenAnswer((_) => videos.stream);
          when(() => peopleListsRepository.searchPublicLists('mixed'))
              .thenAnswer((_) => people.stream);
          final bloc = buildBloc(peopleEnabled: true);
          addTearDown(() async {
            await bloc.close();
            await videos.close();
            await people.close();
          });
          bloc.add(const ListSearchQueryChanged('mixed'));
          await bloc.stream.firstWhere((state) => state.status == .loading);
          if (peopleFailsFirst) {
            final failed = bloc.stream.firstWhere(
              (state) => state.peopleStatus == ListSearchSourceStatus.failure,
            );
            people.addError(const PublicPeopleListReadUnavailableException());
            await failed;
            final arrived = bloc.stream.firstWhere(
              (state) => state.videoResults.isNotEmpty,
            );
            videos.add([testCuratedList]);
            await arrived;
          } else {
            final arrived = bloc.stream.firstWhere(
              (state) => state.videoResults.isNotEmpty,
            );
            videos.add([testCuratedList]);
            await arrived;
            final failed = bloc.stream.firstWhere(
              (state) => state.peopleStatus == ListSearchSourceStatus.failure,
            );
            people.addError(const PublicPeopleListReadUnavailableException());
            await failed;
          }
          expect(bloc.state.status, ListSearchStatus.success);
          expect(bloc.state.videoResults, [testCuratedList]);
          expect(bloc.state.peopleStatus, ListSearchSourceStatus.failure);
          // The healthy source keeps streaming after the other fails.
          final updated = bloc.stream.firstWhere(
            (state) => state.videoResults.isEmpty,
          );
          videos.add([]);
          await updated;
          expect(bloc.state.status, ListSearchStatus.failure);
          expect(bloc.state.hasSourceFailure, isTrue);
        });
      }

      for (final failure in ['people', 'video', 'both']) {
        test('distinguishes $failure unavailability from no matches', () async {
          when(() => curatedListRepository.searchAllLists('mixed')).thenAnswer(
            (_) => failure == 'people'
                ? const Stream.empty()
                : Stream.error(Exception('video source unavailable')),
          );
          when(() => peopleListsRepository.searchPublicLists('mixed'))
              .thenAnswer(
                (_) => failure == 'video'
                    ? const Stream.empty()
                    : Stream.error(
                        const PublicPeopleListReadUnavailableException(),
                      ),
              );
          final bloc = buildBloc(peopleEnabled: true);
          addTearDown(bloc.close);
          bloc.add(const ListSearchQueryChanged('mixed'));
          await bloc.stream.firstWhere(
            (state) =>
                state.videoStatus != ListSearchSourceStatus.loading &&
                state.peopleStatus != ListSearchSourceStatus.loading &&
                state.query == 'mixed',
          );
          expect(bloc.state.status, ListSearchStatus.failure);
          expect(
            bloc.state.videoStatus,
            failure == 'people'
                ? ListSearchSourceStatus.success
                : ListSearchSourceStatus.failure,
          );
          expect(
            bloc.state.peopleStatus,
            failure == 'video'
                ? ListSearchSourceStatus.success
                : ListSearchSourceStatus.failure,
          );
        });
      }

      test(
        'retains healthy results during retry and clears recovered error',
        () async {
          when(() => curatedListRepository.searchAllLists('mixed'))
              .thenAnswer((_) => Stream.value([testCuratedList]));
          var peopleCalls = 0;
          when(
            () => peopleListsRepository.searchPublicLists('mixed'),
          ).thenAnswer(
            (_) => peopleCalls++ == 0
                ? Stream.error(const PublicPeopleListReadUnavailableException())
                : Stream.value([testPeopleResult]),
          );
          final bloc = buildBloc(peopleEnabled: true);
          addTearDown(bloc.close);
          bloc.add(const ListSearchQueryChanged('mixed'));
          await bloc.stream.firstWhere((state) => state.hasSourceFailure);
          final retrying = bloc.stream.firstWhere(
            (state) =>
                state.status == .loading && state.videoResults.isNotEmpty,
          );
          final recovered = bloc.stream.firstWhere(
            (state) =>
                state.peopleResults.isNotEmpty && !state.hasSourceFailure,
          );
          bloc.add(const ListSearchRetried());
          expect((await retrying).videoResults, [testCuratedList]);
          expect((await recovered).peopleResults, [testPeopleResult]);
        },
      );

      test('keeps people results when video source fails', () async {
        when(() => curatedListRepository.searchAllLists('mixed'))
            .thenAnswer((_) => Stream.error(Exception('video unavailable')));
        when(() => peopleListsRepository.searchPublicLists('mixed'))
            .thenAnswer((_) => Stream.value([testPeopleResult]));
        final bloc = buildBloc(peopleEnabled: true);
        addTearDown(bloc.close);
        bloc.add(const ListSearchQueryChanged('mixed'));
        await bloc.stream.firstWhere((state) => state.peopleResults.isNotEmpty);
        expect(bloc.state.status, ListSearchStatus.success);
        expect(bloc.state.videoStatus, ListSearchSourceStatus.failure);
      });
    });

    group('source cancellation', () {
      test(
        'block changes use the pending query without losing visible results',
        () async {
          when(() => curatedListRepository.searchAllLists('old'))
              .thenAnswer((_) => Stream.value([testCuratedList]));
          final bloc = buildBloc();
          addTearDown(bloc.close);
          final ready = bloc.stream.firstWhere(
            (s) => s.query == 'old' && s.status == ListSearchStatus.success,
          );
          bloc.add(const ListSearchQueryChanged('old'));
          await ready;

          bloc.add(const ListSearchQueryChanged('fresh'));
          await pumpEventQueue();
          expect(bloc.state.requestedQuery, 'fresh');
          expect(bloc.state.query, 'old');
          expect(bloc.state.videoResults, [testCuratedList]);
          verifyNever(() => curatedListRepository.searchAllLists('fresh'));

          final refreshed = bloc.stream.firstWhere(
            (s) => s.query == 'fresh' && s.status == ListSearchStatus.success,
          );
          bloc.add(const ListSearchBlocklistChanged());
          await refreshed;
          expect(bloc.state.videoResults, isEmpty);
          verify(() => curatedListRepository.searchAllLists('fresh')).called(1);
        },
      );

      test('returning to the visible query cancels an intervening debounce', () async {
        when(() => curatedListRepository.searchAllLists('old'))
            .thenAnswer((_) => Stream.value([testCuratedList]));
        final bloc = buildBloc();
        addTearDown(bloc.close);
        final ready = bloc.stream.firstWhere(
          (s) => s.query == 'old' && s.status == ListSearchStatus.success,
        );
        bloc.add(const ListSearchQueryChanged('old'));
        await ready;
        verify(() => curatedListRepository.searchAllLists('old')).called(1);

        bloc.add(const ListSearchQueryChanged('fresh'));
        await pumpEventQueue();
        final reloaded = bloc.stream
            .skipWhile((s) => s.status != ListSearchStatus.loading)
            .firstWhere(
              (s) => s.query == 'old' && s.status == ListSearchStatus.success,
            );
        bloc.add(const ListSearchQueryChanged('old'));
        await reloaded;
        verify(() => curatedListRepository.searchAllLists('old')).called(1);
        // Closing also proves the cancelled debounce cannot start a late read.
        await bloc.close();
        verifyNever(() => curatedListRepository.searchAllLists('fresh'));
      });

      test('closing cancels both active repository subscriptions', () async {
        var videoCancelled = false;
        var peopleCancelled = false;
        final videos = StreamController<List<CuratedList>>(
          onCancel: () => videoCancelled = true,
        );
        final people = StreamController<List<PeopleListSearchResult>>(
          onCancel: () => peopleCancelled = true,
        );
        when(() => curatedListRepository.searchAllLists('active'))
            .thenAnswer((_) => videos.stream);
        when(() => peopleListsRepository.searchPublicLists('active'))
            .thenAnswer((_) => people.stream);
        final bloc = buildBloc(peopleEnabled: true);
        final subscribed = bloc.stream.firstWhere(
          (s) =>
              s.query == 'active' &&
              s.peopleStatus == ListSearchSourceStatus.loading,
        );
        bloc.add(const ListSearchQueryChanged('active'));
        await subscribed;
        await pumpEventQueue();
        await bloc.close();
        expect(videoCancelled, isTrue);
        expect(peopleCancelled, isTrue);
        await videos.close();
        await people.close();
      });

      test(
        'duplicate query preserves the active source subscription',
        () async {
          var canceled = false;
          final videos = StreamController<List<CuratedList>>(
            onCancel: () => canceled = true,
          );
          when(() => curatedListRepository.searchAllLists('active'))
              .thenAnswer((_) => videos.stream);
          final bloc = buildBloc();
          addTearDown(() async {
            await bloc.close();
            await videos.close();
          });
          bloc.add(const ListSearchQueryChanged('active'));
          await bloc.stream.firstWhere((state) => state.status == .loading);
          await pumpEventQueue();
          bloc.add(const ListSearchQueryChanged('active'));
          await pumpEventQueue();
          final arrived = bloc.stream.firstWhere(
            (state) => state.videoResults.isNotEmpty,
          );
          videos.add([testCuratedList]);
          await arrived;
          expect(canceled, isFalse);
          verify(() => curatedListRepository.searchAllLists('active'))
              .called(1);
        },
      );

      test(
        'block change clears previously healthy results beside a source error',
        () async {
          var calls = 0;
          when(() => curatedListRepository.searchAllLists('mixed')).thenAnswer(
            (_) => calls++ == 0
                ? Stream.value([testCuratedList])
                : const Stream.empty(),
          );
          when(
            () => peopleListsRepository.searchPublicLists('mixed'),
          ).thenAnswer(
            (_) =>
                Stream.error(const PublicPeopleListReadUnavailableException()),
          );
          final bloc = buildBloc(peopleEnabled: true);
          addTearDown(bloc.close);
          bloc.add(const ListSearchQueryChanged('mixed'));
          await bloc.stream.firstWhere((state) => state.hasSourceFailure);
          expect(bloc.state.videoResults, [testCuratedList]);
          final cleared = bloc.stream.firstWhere(
            (state) => state.status == .loading,
          );
          bloc.add(const ListSearchBlocklistChanged());
          expect((await cleared).videoResults, isEmpty);
        },
      );

      for (final event in <ListSearchEvent>[
        const ListSearchCleared(),
        const ListSearchQueryChanged('fresh'),
        const ListSearchBlocklistChanged(),
      ]) {
        test(
          '$event cancels both sources and rejects late old results',
          () async {
            final videoCanceled = Completer<void>();
            final peopleCanceled = Completer<void>();
            final videos = StreamController<List<CuratedList>>(
              onCancel: videoCanceled.complete,
            );
            final people = StreamController<List<PeopleListSearchResult>>(
              onCancel: peopleCanceled.complete,
            );
            var videoCalls = 0;
            var peopleCalls = 0;
            when(() => curatedListRepository.searchAllLists(any())).thenAnswer(
              (_) => videoCalls++ == 0 ? videos.stream : const Stream.empty(),
            );
            when(() => peopleListsRepository.searchPublicLists(any()))
                .thenAnswer(
                  (_) =>
                      peopleCalls++ == 0 ? people.stream : const Stream.empty(),
                );
            final bloc = buildBloc(peopleEnabled: true);
            addTearDown(() async {
              await bloc.close();
              await videos.close();
              await people.close();
            });
            bloc.add(const ListSearchQueryChanged('old'));
            await bloc.stream.firstWhere((state) => state.status == .loading);
            // Subscriptions become active after loading is emitted.
            await pumpEventQueue();
            final refreshed = event is ListSearchCleared
                ? null
                : bloc.stream.firstWhere((state) => state.status == .success);
            bloc.add(event);
            await Future.wait([videoCanceled.future, peopleCanceled.future]);
            videos.add([testCuratedList]);
            people.add([testPeopleResult]);
            await pumpEventQueue();
            expect(bloc.state.videoResults, isEmpty);
            expect(bloc.state.peopleResults, isEmpty);
            if (event is ListSearchCleared) {
              expect(bloc.state, const ListSearchState());
            } else {
              await refreshed;
              expect(
                bloc.state.query,
                event is ListSearchQueryChanged ? 'fresh' : 'old',
              );
            }
          },
        );
      }

      test('clear also cancels a query still in its debounce', () async {
        final bloc = buildBloc(peopleEnabled: true);
        addTearDown(bloc.close);
        bloc.add(const ListSearchQueryChanged('pending'));
        bloc.add(const ListSearchCleared());
        await pumpEventQueue();
        await bloc.close();
        verifyNever(() => curatedListRepository.searchAllLists(any()));
        verifyNever(() => peopleListsRepository.searchPublicLists(any()));
      });
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
