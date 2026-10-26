// ABOUTME: Tests for UserSearchBloc - user search via ProfileRepository
// ABOUTME: Tests streaming states, error handling, debouncing, and pagination

import 'dart:async';

import 'package:analytics/analytics.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/user_search/user_search_bloc.dart';
import 'package:openvine/services/user_ranking/user_ranking_signals_loader.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:user_ranking/user_ranking.dart';

class _MockProfileRepository extends Mock implements ProfileRepository {}

class _MockRankingSignalsLoader extends Mock
    implements UserRankingSignalsLoader {}

class _MockFollowRepository extends Mock implements FollowRepository {}

class _MockFeedPerformanceTracker extends Mock
    implements FeedPerformanceTracker {}

const _privateKeyQuery =
    'my key nsec1vl029mgpspedva04g90vltkh6fvh240zqtv9k0t9af8935ke9laqsnlfe5';

void main() {
  setUpAll(() {
    // Required so `any(that: isA<SearchSourceSuccess>())` can be used as a
    // matcher for the `SearchSourceStatus` parameter of `trackSearchSource`.
    registerFallbackValue(const SearchSourcePending());
    registerFallbackValue(SearchSource.localCache);
    registerFallbackValue(SearchCancellationToken('test-search'));
  });

  group('UserSearchBloc', () {
    late _MockProfileRepository mockProfileRepository;

    setUp(() {
      mockProfileRepository = _MockProfileRepository();
      when(
        () =>
            mockProfileRepository.countUsersLocally(query: any(named: 'query')),
      ).thenAnswer((_) async => 0);
    });

    Stream<ProgressiveSearchResult> mockSearchRunner({
      required String query,
      required int limit,
      required String sortBy,
      required bool hasVideos,
      required Set<String>? boostPubkeys,
      required SearchCancellationToken cancellationToken,
    }) => mockProfileRepository.searchUsersProgressive(
      query: query,
      limit: limit,
      sortBy: sortBy,
      hasVideos: hasVideos,
      boostPubkeys: boostPubkeys,
    );

    UserSearchBloc createBloc({
      Duration? searchTimeout = const Duration(seconds: 20),
      String? excludedPubkey,
      UserRankingSignalsLoader? rankingSignalsLoader,
    }) => UserSearchBloc(
      profileRepository: mockProfileRepository,
      searchTimeout: searchTimeout,
      excludedPubkey: excludedPubkey,
      rankingSignalsLoader: rankingSignalsLoader,
      searchRunner: mockSearchRunner,
    );

    UserProfile createTestProfile(String pubkey, String displayName) {
      return UserProfile(
        pubkey: pubkey,
        displayName: displayName,
        createdAt: DateTime.now(),
        eventId: 'event-$pubkey',
        rawData: {'display_name': displayName},
      );
    }

    List<UserProfile> createTestProfiles(int count, {int start = 0}) {
      return List.generate(
        count,
        (i) => createTestProfile(
          '${(start + i).toString().padLeft(2, '0')}${'a' * 62}',
          'User ${start + i}',
        ),
      );
    }

    /// Wraps [profiles] in a `ProgressiveSearchResult` envelope so the
    /// mocked `searchUsersProgressive` returns the new stream shape.
    /// Optional [sources] threads source provenance for tests that
    /// assert on `state.sourceOutcomes`.
    Stream<ProgressiveSearchResult> progressive(
      List<UserProfile> profiles, {
      Map<SearchSource, SearchSourceStatus>? sources,
      bool isComplete = true,
      bool restHasMore = false,
    }) {
      return Stream.value(
        ProgressiveSearchResult(
          profiles: profiles,
          sources: sources ?? const {},
          isComplete: isComplete,
          restHasMore: restHasMore,
        ),
      );
    }

    const debounceDuration = Duration(milliseconds: 400);

    test('initial state is correct', () async {
      final bloc = createBloc();
      expect(bloc.state.status, UserSearchStatus.initial);
      expect(bloc.state.query, isEmpty);
      expect(bloc.state.results, isEmpty);
      expect(bloc.state.resultCount, isNull);
      expect(bloc.state.offset, 0);
      expect(bloc.state.hasMore, isFalse);
      expect(bloc.state.isLoadingMore, isFalse);
      await bloc.close();
    });

    test('superseding a running query cancels its repository token', () {
      fakeAsync((clock) {
        final tokens = <SearchCancellationToken>[];
        final controllers = <StreamController<ProgressiveSearchResult>>[];
        final bloc = UserSearchBloc(
          profileRepository: mockProfileRepository,
          searchRunner:
              ({
                required query,
                required limit,
                required sortBy,
                required hasVideos,
                required boostPubkeys,
                required cancellationToken,
              }) {
                tokens.add(cancellationToken);
                final controller = StreamController<ProgressiveSearchResult>();
                controllers.add(controller);
                return controller.stream;
              },
        );

        try {
          bloc.add(const UserSearchQueryChanged('first'));
          clock.elapse(const Duration(milliseconds: 300));
          clock.flushMicrotasks();
          expect(tokens, hasLength(1));
          expect(tokens.single.isCancelled, isFalse);

          bloc.add(const UserSearchQueryChanged('second'));
          clock.elapse(const Duration(milliseconds: 300));
          clock.flushMicrotasks();

          expect(tokens, hasLength(2));
          expect(tokens.first.isCancelled, isTrue);
          expect(tokens.last.isCancelled, isFalse);
        } finally {
          unawaited(bloc.close());
          clock.flushMicrotasks();
          for (final controller in controllers) {
            unawaited(controller.close());
            clock.flushMicrotasks();
          }
        }
        expect(tokens.last.isCancelled, isTrue);
      });
    });

    blocTest<UserSearchBloc, UserSearchState>(
      'passes a cancellation token to the repository by default',
      setUp: () {
        when(
          () => mockProfileRepository.searchUsersProgressive(
            query: 'alice',
            limit: 50,
            sortBy: profileSearchSortFollowers,
            cancellationToken: any(named: 'cancellationToken'),
          ),
        ).thenAnswer((_) => progressive([]));
      },
      build: () => UserSearchBloc(
        profileRepository: mockProfileRepository,
        searchTimeout: null,
      ),
      act: (bloc) => bloc.add(const UserSearchQueryChanged('alice')),
      wait: debounceDuration,
      verify: (_) {
        final token =
            verify(
                  () => mockProfileRepository.searchUsersProgressive(
                    query: 'alice',
                    limit: 50,
                    sortBy: profileSearchSortFollowers,
                    cancellationToken: captureAny(named: 'cancellationToken'),
                  ),
                ).captured.single
                as SearchCancellationToken;
        expect(token.isCancelled, isTrue);
      },
    );

    blocTest<UserSearchBloc, UserSearchState>(
      'omits the excluded pubkey case-insensitively',
      setUp: () {
        when(
          () => mockProfileRepository.searchUsersProgressive(
            query: 'alice',
            limit: 50,
            sortBy: 'followers',
          ),
        ).thenAnswer(
          (_) => progressive([
            createTestProfile('a' * 64, 'Alice'),
            createTestProfile('b' * 64, 'Bob'),
          ]),
        );
      },
      build: () => createBloc(excludedPubkey: ('a' * 64).toUpperCase()),
      act: (bloc) => bloc.add(const UserSearchQueryChanged('alice')),
      wait: debounceDuration,
      verify: (bloc) {
        expect(bloc.state.results.map((profile) => profile.pubkey), ['b' * 64]);
        expect(bloc.state.offset, 2);
      },
    );

    group('page-local ranking', () {
      late _MockRankingSignalsLoader loader;
      late List<UserProfile> profiles;

      setUp(() {
        loader = _MockRankingSignalsLoader();
        profiles = createTestProfiles(4);
        when(() => loader.isEligible(any())).thenReturn(true);
        when(() => loader.load(any())).thenAnswer(
          (invocation) async => {
            for (final key
                in invocation.positionalArguments.single as Iterable<String>)
              key: UserRankingSignals(
                pubkey: key,
                youFollow: key == profiles[1].pubkey,
              ),
          },
        );
        when(() => loader.refreshInBackground(any())).thenReturn(null);
        when(
          () => mockProfileRepository.searchUsersProgressive(
            query: any(named: 'query'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            sortBy: any(named: 'sortBy'),
          ),
        ).thenAnswer(
          (invocation) => progressive(
            invocation.namedArguments[#offset] == 0
                ? profiles.take(2).toList()
                : profiles.skip(2).toList(),
            restHasMore: invocation.namedArguments[#offset] == 0,
          ),
        );
      });

      Future<void> search(UserSearchBloc bloc) async {
        final completed = bloc.stream.firstWhere(
          (s) => s.status == UserSearchStatus.success,
        );
        bloc.add(const UserSearchQueryChanged('alice'));
        await completed;
      }

      Future<void> loadMore(UserSearchBloc bloc) async {
        final completed = bloc.stream.firstWhere((s) => !s.isLoadingMore);
        bloc.add(const UserSearchLoadMore());
        await completed;
      }

      test(
        'first page puts known users first and refreshes after emission',
        () async {
          final bloc = createBloc(rankingSignalsLoader: loader);
          addTearDown(bloc.close);
          when(() => loader.refreshInBackground(any())).thenAnswer((_) {
            expect(bloc.state.results, [profiles[1], profiles[0]]);
          });
          await search(bloc);
          expect(bloc.state.results, [profiles[1], profiles[0]]);
          expect(
            bloc.state.rankingSignals[profiles[1].pubkey]?.youFollow,
            isTrue,
          );
          verify(
            () => loader.refreshInBackground([
              profiles[1].pubkey,
              profiles[0].pubkey,
            ]),
          ).called(1);
        },
      );

      test('load more promotes only within the new page', () async {
        final bloc = createBloc(rankingSignalsLoader: loader);
        addTearDown(bloc.close);
        await search(bloc);
        expect(bloc.state.results, [profiles[1], profiles[0]]);
        when(() => loader.load(any())).thenAnswer(
          (invocation) async => {
            for (final key
                in invocation.positionalArguments.single as Iterable<String>)
              key: UserRankingSignals(
                pubkey: key,
                youFollow: key == profiles[3].pubkey,
              ),
          },
        );
        await loadMore(bloc);
        expect(bloc.state.results, [
          profiles[1],
          profiles[0],
          profiles[3],
          profiles[2],
        ]);
        expect(
          bloc.state.rankingSignals.keys,
          containsAll(profiles.map((p) => p.pubkey)),
        );
        expect(bloc.state.offset, 4);
      });

      test(
        'progressive snapshots retain visible rows and rank only new arrivals',
        () async {
          final stream = StreamController<ProgressiveSearchResult>();
          addTearDown(stream.close);
          when(
            () => mockProfileRepository.searchUsersProgressive(
              query: any(named: 'query'),
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
              sortBy: any(named: 'sortBy'),
            ),
          ).thenAnswer((_) => stream.stream);
          when(() => loader.load(any())).thenAnswer(
            (invocation) async => {
              for (final key
                  in invocation.positionalArguments.single as Iterable<String>)
                key: UserRankingSignals(
                  pubkey: key,
                  youFollow:
                      key == profiles[1].pubkey || key == profiles[3].pubkey,
                ),
            },
          );
          final bloc = createBloc(rankingSignalsLoader: loader);
          addTearDown(bloc.close);
          bloc.add(const UserSearchQueryChanged('alice'));
          final first = bloc.stream.firstWhere((s) => s.results.isNotEmpty);
          stream.add(
            ProgressiveSearchResult(
              profiles: profiles.take(2).toList(),
              sources: const {},
              isComplete: false,
            ),
          );
          await first;
          expect(bloc.state.results, [profiles[1], profiles[0]]);
          final updated = profiles[0].copyWith(displayName: 'Updated');
          final second = bloc.stream.firstWhere((s) => s.results.length == 4);
          stream.add(
            ProgressiveSearchResult(
              profiles: [profiles[2], updated, profiles[3], profiles[1]],
              sources: const {},
              isComplete: true,
            ),
          );
          await second;
          expect(bloc.state.results, [
            profiles[1],
            updated,
            profiles[3],
            profiles[2],
          ]);
          // UserProfile equality ignores the display name, so the list match
          // above cannot tell the updated row from the stale one.
          expect(bloc.state.results[1].displayName, 'Updated');
          verify(() => loader.load([profiles[2].pubkey, profiles[3].pubkey]))
              .called(1);
        },
      );

      test('load more keeps an exact match ahead of known accounts', () async {
        final exact = createTestProfile('e' * 64, 'Alice');
        when(
          () => mockProfileRepository.searchUsersProgressive(
            query: any(named: 'query'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            sortBy: any(named: 'sortBy'),
          ),
        ).thenAnswer(
          (invocation) => progressive(
            invocation.namedArguments[#offset] == 0
                ? profiles.take(2).toList()
                : [profiles[2], exact, profiles[3]],
            restHasMore: invocation.namedArguments[#offset] == 0,
          ),
        );
        final bloc = createBloc(rankingSignalsLoader: loader);
        addTearDown(bloc.close);
        await search(bloc);
        when(() => loader.load(any())).thenAnswer(
          (invocation) async => {
            for (final key
                in invocation.positionalArguments.single as Iterable<String>)
              key: UserRankingSignals(
                pubkey: key,
                youFollow: key == profiles[3].pubkey,
              ),
          },
        );
        await loadMore(bloc);
        expect(bloc.state.results, [
          profiles[1],
          profiles[0],
          exact,
          profiles[3],
          profiles[2],
        ]);
      });

      test('a retained snapshot keeps the viewer on global search', () {
        final viewer = createTestProfile('f' * 64, 'Me');
        when(() => loader.isEligible(viewer.pubkey)).thenReturn(false);
        final bloc = UserSearchBloc(
          profileRepository: mockProfileRepository,
          searchRunner: mockSearchRunner,
          rankingSignalsLoader: loader,
          viewerPubkey: viewer.pubkey,
          initialState: UserSearchState(
            status: UserSearchStatus.success,
            query: 'me',
            results: [viewer, profiles[0]],
          ),
        );
        addTearDown(bloc.close);
        expect(bloc.state.results, [viewer, profiles[0]]);
      });

      test('an exact match leads its page ahead of known accounts', () async {
        final exact = createTestProfile('e' * 64, 'Alice');
        when(
          () => mockProfileRepository.searchUsersProgressive(
            query: any(named: 'query'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            sortBy: any(named: 'sortBy'),
          ),
        ).thenAnswer((_) => progressive([exact, profiles[0], profiles[1]]));
        final bloc = createBloc(rankingSignalsLoader: loader);
        addTearDown(bloc.close);
        await search(bloc);
        expect(bloc.state.results, [exact, profiles[1], profiles[0]]);
      });

      test(
        'an exact match from a later source moves ahead of shown rows',
        () async {
          final stream = StreamController<ProgressiveSearchResult>();
          addTearDown(stream.close);
          when(
            () => mockProfileRepository.searchUsersProgressive(
              query: any(named: 'query'),
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
              sortBy: any(named: 'sortBy'),
            ),
          ).thenAnswer((_) => stream.stream);
          final exact = createTestProfile('e' * 64, 'Alice');
          final bloc = createBloc(rankingSignalsLoader: loader);
          addTearDown(bloc.close);
          bloc.add(const UserSearchQueryChanged('alice'));
          final first = bloc.stream.firstWhere((s) => s.results.isNotEmpty);
          stream.add(
            ProgressiveSearchResult(
              profiles: profiles.take(2).toList(),
              sources: const {},
              isComplete: false,
            ),
          );
          await first;
          expect(bloc.state.results, [profiles[1], profiles[0]]);
          final second = bloc.stream.firstWhere((s) => s.results.length == 3);
          stream.add(
            ProgressiveSearchResult(
              profiles: [exact, ...profiles.take(2)],
              sources: const {},
              isComplete: true,
            ),
          );
          await second;
          expect(bloc.state.results, [exact, profiles[1], profiles[0]]);
        },
      );

      test(
        'the username owner moves ahead of shown exact matches',
        () async {
          final stream = StreamController<ProgressiveSearchResult>();
          addTearDown(stream.close);
          when(
            () => mockProfileRepository.searchUsersProgressive(
              query: any(named: 'query'),
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
              sortBy: any(named: 'sortBy'),
            ),
          ).thenAnswer((_) => stream.stream);
          final impostor = createTestProfile('e' * 64, 'Alice');
          final owner = createTestProfile('f' * 64, 'AC555');
          final bloc = createBloc(rankingSignalsLoader: loader);
          addTearDown(bloc.close);
          bloc.add(const UserSearchQueryChanged('alice'));
          final first = bloc.stream.firstWhere((s) => s.results.isNotEmpty);
          stream.add(
            ProgressiveSearchResult(
              profiles: [impostor, profiles[0]],
              sources: const {},
              isComplete: false,
            ),
          );
          await first;
          expect(bloc.state.results, [impostor, profiles[0]]);
          final second = bloc.stream.firstWhere((s) => s.results.length == 3);
          stream.add(
            ProgressiveSearchResult(
              profiles: [owner, impostor, profiles[0]],
              sources: const {},
              isComplete: true,
              usernameOwnerPubkey: owner.pubkey,
            ),
          );
          await second;
          expect(bloc.state.results, [owner, impostor, profiles[0]]);
        },
      );

      test(
        'resuming the same query retains the inherited progressive prefix',
        () async {
          final prefix = profiles.take(2).toList();
          final bloc = UserSearchBloc(
            profileRepository: mockProfileRepository,
            searchRunner: mockSearchRunner,
            rankingSignalsLoader: loader,
            initialState: UserSearchState(
              status: UserSearchStatus.loading,
              query: 'alice',
              results: prefix,
              rankingSignals: {
                for (final profile in prefix)
                  profile.pubkey: UserRankingSignals(pubkey: profile.pubkey),
              },
            ),
          );
          addTearDown(bloc.close);
          await search(bloc);
          expect(bloc.state.results, prefix);
          expect(bloc.state.rankingSignals.keys, prefix.map((p) => p.pubkey));
          verifyNever(() => loader.load(any()));
        },
      );

      test(
        'inherited prefix survives incomplete cache replay until completion',
        () async {
          final stream = StreamController<ProgressiveSearchResult>();
          addTearDown(stream.close);
          when(
            () => mockProfileRepository.searchUsersProgressive(
              query: any(named: 'query'),
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
              sortBy: any(named: 'sortBy'),
            ),
          ).thenAnswer((_) => stream.stream);
          final prefix = profiles.take(2).toList();
          final bloc = UserSearchBloc(
            profileRepository: mockProfileRepository,
            searchRunner: mockSearchRunner,
            rankingSignalsLoader: loader,
            initialState: UserSearchState(
              status: UserSearchStatus.loading,
              query: 'alice',
              results: prefix,
              rankingSignals: {
                for (final profile in prefix)
                  profile.pubkey: UserRankingSignals(pubkey: profile.pubkey),
              },
            ),
          );
          addTearDown(bloc.close);
          final emitted = <UserSearchState>[];
          final subscription = bloc.stream.listen(emitted.add);
          addTearDown(subscription.cancel);
          bloc.add(const UserSearchQueryChanged('alice'));
          final cached = bloc.stream.firstWhere(
            (state) =>
                state.sourceOutcomes.containsKey(SearchSource.localCache),
          );
          stream.add(
            ProgressiveSearchResult(
              profiles: [profiles[1]],
              sources: const {
                SearchSource.localCache: SearchSourceSuccess(
                  resultCount: 1,
                  latencyMs: 1,
                ),
              },
              isComplete: false,
            ),
          );
          await cached;
          expect(bloc.state.results, prefix);
          expect(bloc.state.rankingSignals.keys, prefix.map((p) => p.pubkey));
          final completed = bloc.stream.firstWhere(
            (state) => state.status == UserSearchStatus.success,
          );
          stream.add(
            ProgressiveSearchResult(
              profiles: prefix,
              sources: const {},
              isComplete: true,
            ),
          );
          await stream.close();
          await completed;
          expect(emitted, isNotEmpty);
          for (final state in emitted) {
            expect(state.results, prefix);
            expect(state.rankingSignals.keys, prefix.map((p) => p.pubkey));
          }
          verifyNever(() => loader.load(any()));
        },
      );

      test(
        'inherited rows lose blocked signals immediately and omitted signals on completion',
        () async {
          final stream = StreamController<ProgressiveSearchResult>();
          addTearDown(stream.close);
          when(
            () => mockProfileRepository.searchUsersProgressive(
              query: any(named: 'query'),
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
            ),
          ).thenAnswer((_) => stream.stream);
          final prefix = profiles.take(2).toList();
          final bloc = UserSearchBloc(
            profileRepository: mockProfileRepository,
            searchRunner: mockSearchRunner,
            rankingSignalsLoader: loader,
            initialState: UserSearchState(
              status: UserSearchStatus.loading,
              query: 'alice',
              results: prefix,
              rankingSignals: {
                for (final profile in prefix)
                  profile.pubkey: UserRankingSignals(pubkey: profile.pubkey),
              },
            ),
          );
          addTearDown(bloc.close);
          when(() => loader.isEligible(prefix.first.pubkey)).thenReturn(false);
          bloc.add(const UserSearchQueryChanged('alice'));
          final cached = bloc.stream.firstWhere(
            (state) =>
                state.sourceOutcomes.containsKey(SearchSource.localCache),
          );
          stream.add(
            const ProgressiveSearchResult(
              profiles: [],
              isComplete: false,
              sources: {
                SearchSource.localCache: SearchSourceSuccess(
                  resultCount: 0,
                  latencyMs: 1,
                ),
              },
            ),
          );
          await cached;
          expect(bloc.state.results, [prefix.last]);
          expect(bloc.state.rankingSignals.keys, [prefix.last.pubkey]);
          final completed = bloc.stream.firstWhere(
            (state) => state.status == UserSearchStatus.success,
          );
          stream.add(
            const ProgressiveSearchResult(
              profiles: [],
              sources: {},
              isComplete: true,
            ),
          );
          await stream.close();
          await completed;
          expect(bloc.state.results, isEmpty);
          expect(bloc.state.rankingSignals, isEmpty);
        },
      );

      test('progressive prefix drops newly blocked and omitted rows', () async {
        final stream = StreamController<ProgressiveSearchResult>();
        addTearDown(stream.close);
        when(
          () => mockProfileRepository.searchUsersProgressive(
            query: any(named: 'query'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            sortBy: any(named: 'sortBy'),
          ),
        ).thenAnswer((_) => stream.stream);
        final bloc = createBloc(rankingSignalsLoader: loader);
        addTearDown(bloc.close);
        bloc.add(const UserSearchQueryChanged('alice'));
        final first = bloc.stream.firstWhere((s) => s.results.isNotEmpty);
        stream.add(
          ProgressiveSearchResult(
            profiles: profiles.take(2).toList(),
            sources: const {},
            isComplete: false,
          ),
        );
        await first;
        when(() => loader.isEligible(profiles[1].pubkey)).thenReturn(false);
        final second = bloc.stream.firstWhere(
          (s) => s.results.contains(profiles[2]),
        );
        stream.add(
          ProgressiveSearchResult(
            profiles: [profiles[1], profiles[2]],
            sources: const {},
            isComplete: true,
          ),
        );
        await second;
        expect(bloc.state.results, [profiles[2]]);
        expect(bloc.state.rankingSignals.keys, [profiles[2].pubkey]);
      });

      test('load more revalidates the complete visible prefix', () async {
        final bloc = createBloc(rankingSignalsLoader: loader);
        addTearDown(bloc.close);
        await search(bloc);
        when(() => loader.isEligible(profiles[1].pubkey)).thenReturn(false);
        await loadMore(bloc);
        expect(bloc.state.results, [profiles[0], profiles[2], profiles[3]]);
        expect(bloc.state.rankingSignals, isNot(contains(profiles[1].pubkey)));
      });

      test('null loader keeps server order', () async {
        final bloc = createBloc();
        addTearDown(bloc.close);
        await search(bloc);
        expect(bloc.state.results, profiles.take(2));
        await loadMore(bloc);
        expect(bloc.state.results, profiles);
        verifyNever(() => loader.load(any()));
      });

      test(
        'snapshot keys exclude self and blocked users on every page',
        () async {
          when(() => loader.load(any())).thenAnswer(
            (invocation) async => {
              for (final key
                  in invocation.positionalArguments.single as Iterable<String>)
                if (key == profiles[1].pubkey || key == profiles[3].pubkey)
                  key: UserRankingSignals(pubkey: key),
            },
          );
          final bloc = createBloc(rankingSignalsLoader: loader);
          addTearDown(bloc.close);
          await search(bloc);
          expect(bloc.state.results, [profiles[1]]);
          expect(bloc.state.offset, 2);
          await loadMore(bloc);
          expect(bloc.state.results, [profiles[1], profiles[3]]);
          expect(bloc.state.offset, 4);
        },
      );

      blocTest<UserSearchBloc, UserSearchState>(
        'snapshot failure keeps eligible server order and reports the error',
        setUp: () {
          when(() => loader.load(any()))
              .thenThrow(const FormatException('local snapshot'));
          when(() => loader.isEligible(profiles[0].pubkey)).thenReturn(false);
        },
        build: () => createBloc(rankingSignalsLoader: loader),
        act: search,
        verify: (bloc) {
          expect(bloc.state.status, UserSearchStatus.success);
          expect(bloc.state.results, [profiles[1]]);
          expect(bloc.state.rankingSignals, isEmpty);
        },
        errors: () => [isA<FormatException>()],
      );

      for (final fails in [false, true]) {
        test(
          'superseded signal ${fails ? 'failure' : 'success'} cannot finish the new query',
          () async {
            final stale = Completer<Map<String, UserRankingSignals>>();
            final current = Completer<Map<String, UserRankingSignals>>();
            final firstStarted = Completer<void>();
            final secondStarted = Completer<void>();
            when(() => loader.load(any())).thenAnswer((_) {
              if (!firstStarted.isCompleted) {
                firstStarted.complete();
                return stale.future;
              }
              secondStarted.complete();
              return current.future;
            });
            final bloc = createBloc(rankingSignalsLoader: loader);
            addTearDown(bloc.close);
            bloc.add(const UserSearchQueryChanged('first'));
            await firstStarted.future;
            bloc.add(const UserSearchQueryChanged('second'));
            await secondStarted.future;
            expect(bloc.state.query, 'second');
            expect(bloc.state.status, UserSearchStatus.loading);
            if (fails) {
              stale.completeError(const FormatException('stale snapshot'));
            } else {
              stale.complete({
                for (final p in profiles)
                  p.pubkey: UserRankingSignals(pubkey: p.pubkey),
              });
            }
            await pumpEventQueue();
            expect(bloc.state.query, 'second');
            expect(bloc.state.status, UserSearchStatus.loading);
            verifyNever(() => loader.refreshInBackground(any()));
            final completed = bloc.stream.firstWhere(
              (s) => s.status == UserSearchStatus.success,
            );
            current.complete({
              for (final p in profiles)
                p.pubkey: UserRankingSignals(pubkey: p.pubkey),
            });
            await completed;
            verify(() => loader.refreshInBackground(any())).called(1);
          },
        );
      }
    });

    group('UserSearchQueryChanged', () {
      blocTest<UserSearchBloc, UserSearchState>(
        'emits [searching, searching(results), success] when search succeeds',
        setUp: () {
          when(
            () => mockProfileRepository.searchUsersProgressive(
              query: 'alice',
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          ).thenAnswer(
            (_) => progressive([createTestProfile('a' * 64, 'Alice')]),
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(const UserSearchQueryChanged('alice')),
        wait: debounceDuration,
        expect: () => [
          const UserSearchState(
            status: UserSearchStatus.loading,
            query: 'alice',
          ),
          isA<UserSearchState>()
              .having((s) => s.status, 'status', UserSearchStatus.loading)
              .having((s) => s.query, 'query', 'alice')
              .having((s) => s.results.length, 'results.length', 1)
              .having(
                (s) => s.results.first.displayName,
                'first result name',
                'Alice',
              ),
          isA<UserSearchState>()
              .having((s) => s.status, 'status', UserSearchStatus.success)
              .having((s) => s.offset, 'offset', 1)
              .having((s) => s.hasMore, 'hasMore', false),
        ],
        verify: (_) {
          verify(
            () => mockProfileRepository.searchUsersProgressive(
              query: 'alice',
              limit: 50,
              sortBy: 'followers',
            ),
          ).called(1);
        },
      );

      blocTest<UserSearchBloc, UserSearchState>(
        'sets hasMore to true when results equal page size',
        setUp: () {
          when(
            () => mockProfileRepository.searchUsersProgressive(
              query: 'test',
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          ).thenAnswer(
            (_) => progressive(createTestProfiles(50), restHasMore: true),
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(const UserSearchQueryChanged('test')),
        wait: debounceDuration,
        expect: () => [
          const UserSearchState(
            status: UserSearchStatus.loading,
            query: 'test',
          ),
          isA<UserSearchState>()
              .having((s) => s.status, 'status', UserSearchStatus.loading)
              .having((s) => s.results.length, 'results.length', 50),
          isA<UserSearchState>()
              .having((s) => s.status, 'status', UserSearchStatus.success)
              .having((s) => s.offset, 'offset', 50)
              .having((s) => s.hasMore, 'hasMore', true),
        ],
      );

      blocTest<UserSearchBloc, UserSearchState>(
        'emits [searching, failure] when search fails',
        setUp: () {
          when(
            () => mockProfileRepository.searchUsersProgressive(
              query: 'error',
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          ).thenAnswer(
            (_) => Stream<ProgressiveSearchResult>.error(
              Exception('Network error'),
            ),
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(const UserSearchQueryChanged('error')),
        wait: debounceDuration,
        expect: () => [
          const UserSearchState(
            status: UserSearchStatus.loading,
            query: 'error',
          ),
          const UserSearchState(
            status: UserSearchStatus.failure,
            query: 'error',
          ),
        ],
      );

      blocTest<UserSearchBloc, UserSearchState>(
        'emits initial state when query is empty',
        build: createBloc,
        act: (bloc) => bloc.add(const UserSearchQueryChanged('')),
        wait: debounceDuration,
        expect: () => [const UserSearchState()],
        verify: (_) {
          verifyNever(
            () => mockProfileRepository.searchUsersProgressive(
              query: any(named: 'query'),
            ),
          );
        },
      );

      test(
        'private-key input clears retained results before profiles are ready',
        () {
          fakeAsync((clock) {
            final bloc = UserSearchBloc(
              profileRepository: null,
              initialState: UserSearchState(
                status: UserSearchStatus.success,
                query: 'flutter',
                results: [createTestProfile('a' * 64, 'Flutter Dev')],
              ),
            );
            try {
              bloc.add(const UserSearchQueryChanged(_privateKeyQuery));
              clock.elapse(debounceDuration);
              clock.flushMicrotasks();
              expect(bloc.state, const UserSearchState());
            } finally {
              unawaited(bloc.close());
              clock.flushMicrotasks();
            }
          });
        },
      );

      blocTest<UserSearchBloc, UserSearchState>(
        'does not search and resets when the query contains a private key',
        setUp: () {
          when(
            () => mockProfileRepository.searchUsersProgressive(
              query: any(named: 'query'),
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
              boostPubkeys: any(named: 'boostPubkeys'),
            ),
          ).thenAnswer((_) => const Stream.empty());
        },
        build: createBloc,
        seed: () => UserSearchState(
          status: UserSearchStatus.success,
          query: 'flutter',
          results: [createTestProfile('a' * 64, 'Flutter Dev')],
          offset: 1,
        ),
        act: (bloc) => bloc.add(const UserSearchQueryChanged(_privateKeyQuery)),
        wait: debounceDuration,
        expect: () => [const UserSearchState()],
        verify: (_) {
          verifyNever(
            () => mockProfileRepository.searchUsersProgressive(
              query: any(named: 'query'),
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
              boostPubkeys: any(named: 'boostPubkeys'),
            ),
          );
        },
      );

      blocTest<UserSearchBloc, UserSearchState>(
        'emits initial state when query is whitespace only',
        build: createBloc,
        act: (bloc) => bloc.add(const UserSearchQueryChanged('   ')),
        wait: debounceDuration,
        expect: () => [const UserSearchState()],
        verify: (_) {
          verifyNever(
            () => mockProfileRepository.searchUsersProgressive(
              query: any(named: 'query'),
            ),
          );
        },
      );

      blocTest<UserSearchBloc, UserSearchState>(
        'emits initial state when query is a single character',
        build: createBloc,
        act: (bloc) => bloc.add(const UserSearchQueryChanged('a')),
        wait: debounceDuration,
        expect: () => [const UserSearchState()],
        verify: (_) {
          verifyNever(
            () => mockProfileRepository.searchUsersProgressive(
              query: any(named: 'query'),
            ),
          );
        },
      );

      blocTest<UserSearchBloc, UserSearchState>(
        're-searches when same query is submitted again',
        setUp: () {
          when(
            () => mockProfileRepository.searchUsersProgressive(
              query: 'flutter',
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          ).thenAnswer(
            (_) => progressive([createTestProfile('b' * 64, 'Flutter Dev 2')]),
          );
        },
        build: createBloc,
        seed: () => UserSearchState(
          status: UserSearchStatus.success,
          query: 'flutter',
          results: [createTestProfile('a' * 64, 'Flutter Dev')],
          offset: 1,
        ),
        act: (bloc) => bloc.add(const UserSearchQueryChanged('flutter')),
        wait: debounceDuration,
        expect: () => [
          // Previous results stay visible during re-query to prevent the
          // full-screen spinner flash on autocorrect-triggered re-runs.
          isA<UserSearchState>()
              .having((s) => s.status, 'status', UserSearchStatus.loading)
              .having((s) => s.query, 'query', 'flutter')
              .having((s) => s.results, 'results preserved', hasLength(1))
              .having(
                (s) => s.results.first.displayName,
                'previous result',
                'Flutter Dev',
              )
              .having((s) => s.offset, 'offset reset', 0)
              .having((s) => s.hasMore, 'hasMore reset', false),
          isA<UserSearchState>()
              .having((s) => s.status, 'status', UserSearchStatus.loading)
              .having((s) => s.results, 'results', hasLength(1))
              .having(
                (s) => s.results.first.displayName,
                'displayName',
                'Flutter Dev 2',
              ),
          isA<UserSearchState>().having(
            (s) => s.status,
            'status',
            UserSearchStatus.success,
          ),
        ],
        verify: (_) {
          verify(
            () => mockProfileRepository.searchUsersProgressive(
              query: 'flutter',
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          ).called(1);
        },
      );

      blocTest<UserSearchBloc, UserSearchState>(
        'trims whitespace from query',
        setUp: () {
          when(
            () => mockProfileRepository.searchUsersProgressive(
              query: 'bob',
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          ).thenAnswer((_) => progressive([]));
        },
        build: createBloc,
        act: (bloc) => bloc.add(const UserSearchQueryChanged('  bob  ')),
        wait: debounceDuration,
        expect: () => [
          const UserSearchState(status: UserSearchStatus.loading, query: 'bob'),
          // Stream yields empty list → searching with resultCount: 0
          isA<UserSearchState>()
              .having((s) => s.status, 'status', UserSearchStatus.loading)
              .having((s) => s.resultCount, 'resultCount', 0),
          isA<UserSearchState>()
              .having((s) => s.status, 'status', UserSearchStatus.success)
              .having((s) => s.query, 'query', 'bob')
              .having((s) => s.results, 'results', isEmpty),
        ],
        verify: (_) {
          verify(
            () => mockProfileRepository.searchUsersProgressive(
              query: 'bob',
              limit: 50,
              sortBy: 'followers',
            ),
          ).called(1);
        },
      );

      blocTest<UserSearchBloc, UserSearchState>(
        'returns empty results when no users match',
        setUp: () {
          when(
            () => mockProfileRepository.searchUsersProgressive(
              query: 'xyz',
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          ).thenAnswer((_) => progressive([]));
        },
        build: createBloc,
        act: (bloc) => bloc.add(const UserSearchQueryChanged('xyz')),
        wait: debounceDuration,
        expect: () => [
          const UserSearchState(status: UserSearchStatus.loading, query: 'xyz'),
          isA<UserSearchState>()
              .having((s) => s.status, 'status', UserSearchStatus.loading)
              .having((s) => s.resultCount, 'resultCount', 0),
          isA<UserSearchState>()
              .having((s) => s.status, 'status', UserSearchStatus.success)
              .having((s) => s.query, 'query', 'xyz')
              .having((s) => s.results, 'results', isEmpty),
        ],
      );

      blocTest<UserSearchBloc, UserSearchState>(
        'debounces rapid query changes and only processes final query',
        setUp: () {
          when(
            () => mockProfileRepository.searchUsersProgressive(
              query: 'final',
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          ).thenAnswer((_) => progressive([]));
        },
        build: createBloc,
        act: (bloc) {
          bloc
            ..add(const UserSearchQueryChanged('f'))
            ..add(const UserSearchQueryChanged('fi'))
            ..add(const UserSearchQueryChanged('fin'))
            ..add(const UserSearchQueryChanged('fina'))
            ..add(const UserSearchQueryChanged('final'));
        },
        wait: debounceDuration,
        expect: () => [
          const UserSearchState(
            status: UserSearchStatus.loading,
            query: 'final',
          ),
          isA<UserSearchState>()
              .having((s) => s.status, 'status', UserSearchStatus.loading)
              .having((s) => s.resultCount, 'resultCount', 0),
          isA<UserSearchState>()
              .having((s) => s.status, 'status', UserSearchStatus.success)
              .having((s) => s.query, 'query', 'final'),
        ],
        verify: (_) {
          // Only the final query should be processed due to debounce
          verify(
            () => mockProfileRepository.searchUsersProgressive(
              query: 'final',
              limit: 50,
              sortBy: 'followers',
            ),
          ).called(1);
          verifyNever(
            () => mockProfileRepository.searchUsersProgressive(
              query: 'f',
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          );
          verifyNever(
            () => mockProfileRepository.searchUsersProgressive(
              query: 'fi',
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          );
          verifyNever(
            () => mockProfileRepository.searchUsersProgressive(
              query: 'fin',
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          );
          verifyNever(
            () => mockProfileRepository.searchUsersProgressive(
              query: 'fina',
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          );
        },
      );

      blocTest<UserSearchBloc, UserSearchState>(
        'emits progressive results from multi-yield stream',
        setUp: () {
          when(
            () => mockProfileRepository.searchUsersProgressive(
              query: 'alice',
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          ).thenAnswer(
            (_) => Stream.fromIterable([
              // First yield: local cached result
              ProgressiveSearchResult(
                profiles: [createTestProfile('a' * 64, 'Alice Local')],
                sources: const {},
                isComplete: false,
              ),
              // Second yield: merged with remote
              ProgressiveSearchResult(
                profiles: [
                  createTestProfile('a' * 64, 'Alice Local'),
                  createTestProfile('b' * 64, 'Alice Remote'),
                ],
                sources: const {},
                isComplete: true,
              ),
            ]),
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(const UserSearchQueryChanged('alice')),
        wait: debounceDuration,
        expect: () => [
          const UserSearchState(
            status: UserSearchStatus.loading,
            query: 'alice',
          ),
          isA<UserSearchState>()
              .having((s) => s.status, 'status', UserSearchStatus.loading)
              .having((s) => s.results.length, 'results.length', 1),
          isA<UserSearchState>()
              .having((s) => s.status, 'status', UserSearchStatus.loading)
              .having((s) => s.results.length, 'results.length', 2),
          isA<UserSearchState>()
              .having((s) => s.status, 'status', UserSearchStatus.success)
              .having((s) => s.results.length, 'results.length', 2),
        ],
      );

      blocTest<UserSearchBloc, UserSearchState>(
        'emits success with partial results when stream times out',
        setUp: () {
          final controller = StreamController<ProgressiveSearchResult>();
          when(
            () => mockProfileRepository.searchUsersProgressive(
              query: 'slow',
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          ).thenAnswer((_) {
            // Emit one batch then stall (never close the stream).
            controller.add(
              ProgressiveSearchResult(
                profiles: [createTestProfile('a' * 64, 'Slow User')],
                sources: const {},
                isComplete: false,
              ),
            );
            return controller.stream;
          });
        },
        build: () =>
            createBloc(searchTimeout: const Duration(milliseconds: 10)),
        act: (bloc) => bloc.add(const UserSearchQueryChanged('slow')),
        wait: const Duration(milliseconds: 500),
        expect: () => [
          const UserSearchState(
            status: UserSearchStatus.loading,
            query: 'slow',
          ),
          isA<UserSearchState>()
              .having((s) => s.status, 'status', UserSearchStatus.loading)
              .having((s) => s.results.length, 'results.length', 1),
          // Timeout fires → success with accumulated results AND every
          // pending source marked failed(timeout) so the UI can
          // distinguish degraded-empty from a true success.
          isA<UserSearchState>()
              .having((s) => s.status, 'status', UserSearchStatus.success)
              .having((s) => s.results.length, 'results.length', 1)
              .having((s) => s.hasMore, 'hasMore', false)
              .having(
                (s) => s.sourceOutcomes[SearchSource.localCache],
                'local source outcome',
                isA<SearchSourceFailed>().having(
                  (f) => f.reason,
                  'reason',
                  SearchSourceFailureReason.timeout,
                ),
              )
              .having(
                (s) => s.sourceOutcomes[SearchSource.funnelcakeApi],
                'api source outcome',
                isA<SearchSourceFailed>().having(
                  (f) => f.reason,
                  'reason',
                  SearchSourceFailureReason.timeout,
                ),
              )
              .having(
                (s) => s.sourceOutcomes[SearchSource.nip50Relay],
                'relay source outcome',
                isA<SearchSourceFailed>().having(
                  (f) => f.reason,
                  'reason',
                  SearchSourceFailureReason.timeout,
                ),
              ),
        ],
      );
    });

    group('UserSearchLoadMore', () {
      blocTest<UserSearchBloc, UserSearchState>(
        'appends results and updates offset when loading more',
        setUp: () {
          when(
            () => mockProfileRepository.searchUsersProgressive(
              query: 'alice',
              limit: 50,
              offset: 50,
              sortBy: 'followers',
            ),
          ).thenAnswer(
            (_) => progressive(createTestProfiles(10, start: 50)),
          );
        },
        build: createBloc,
        seed: () => UserSearchState(
          status: UserSearchStatus.success,
          query: 'alice',
          results: createTestProfiles(50),
          offset: 50,
          hasMore: true,
        ),
        act: (bloc) => bloc.add(const UserSearchLoadMore()),
        expect: () => [
          isA<UserSearchState>()
              .having((s) => s.isLoadingMore, 'isLoadingMore', true)
              .having((s) => s.results.length, 'results.length', 50),
          isA<UserSearchState>()
              .having((s) => s.isLoadingMore, 'isLoadingMore', false)
              .having((s) => s.results.length, 'results.length', 60)
              .having((s) => s.offset, 'offset', 60)
              .having((s) => s.hasMore, 'hasMore', false),
        ],
      );

      blocTest<UserSearchBloc, UserSearchState>(
        'uses last emission when stream yields multiple times',
        setUp: () {
          final partial = createTestProfiles(5, start: 50);
          final full = createTestProfiles(10, start: 50);
          when(
            () => mockProfileRepository.searchUsersProgressive(
              query: 'alice',
              limit: 50,
              offset: 50,
              sortBy: 'followers',
            ),
          ).thenAnswer(
            (_) => Stream.fromIterable([
              ProgressiveSearchResult(
                profiles: partial,
                sources: const {},
                isComplete: false,
              ),
              ProgressiveSearchResult(
                profiles: full,
                sources: const {},
                isComplete: true,
              ),
            ]),
          );
        },
        build: createBloc,
        seed: () => UserSearchState(
          status: UserSearchStatus.success,
          query: 'alice',
          results: createTestProfiles(50),
          offset: 50,
          hasMore: true,
        ),
        act: (bloc) => bloc.add(const UserSearchLoadMore()),
        expect: () => [
          isA<UserSearchState>().having(
            (s) => s.isLoadingMore,
            'isLoadingMore',
            true,
          ),
          isA<UserSearchState>()
              .having((s) => s.isLoadingMore, 'isLoadingMore', false)
              .having((s) => s.results.length, 'results.length', 60)
              .having((s) => s.offset, 'offset', 60)
              .having((s) => s.hasMore, 'hasMore', false),
        ],
      );

      blocTest<UserSearchBloc, UserSearchState>(
        'sets hasMore to true when load more returns full page',
        setUp: () {
          when(
            () => mockProfileRepository.searchUsersProgressive(
              query: 'alice',
              limit: 50,
              offset: 50,
              sortBy: 'followers',
            ),
          ).thenAnswer(
            (_) => progressive(
              createTestProfiles(50, start: 50),
              restHasMore: true,
            ),
          );
        },
        build: createBloc,
        seed: () => UserSearchState(
          status: UserSearchStatus.success,
          query: 'alice',
          results: createTestProfiles(50),
          offset: 50,
          hasMore: true,
        ),
        act: (bloc) => bloc.add(const UserSearchLoadMore()),
        expect: () => [
          isA<UserSearchState>().having(
            (s) => s.isLoadingMore,
            'isLoadingMore',
            true,
          ),
          isA<UserSearchState>()
              .having((s) => s.results.length, 'results.length', 100)
              .having((s) => s.offset, 'offset', 100)
              .having((s) => s.hasMore, 'hasMore', true),
        ],
      );

      blocTest<UserSearchBloc, UserSearchState>(
        'uses REST metadata instead of the merged result count',
        setUp: () {
          when(
            () => mockProfileRepository.searchUsersProgressive(
              query: 'alice',
              limit: 50,
              offset: 50,
              sortBy: 'followers',
            ),
          ).thenAnswer(
            (_) => Stream.value(
              ProgressiveSearchResult(
                profiles: createTestProfiles(10),
                sources: const {},
                isComplete: true,
                nextRestOffset: 100,
                restHasMore: true,
              ),
            ),
          );
        },
        build: createBloc,
        seed: () => UserSearchState(
          status: UserSearchStatus.success,
          query: 'alice',
          results: createTestProfiles(50),
          offset: 50,
          hasMore: true,
        ),
        act: (bloc) => bloc.add(const UserSearchLoadMore()),
        expect: () => [
          isA<UserSearchState>().having(
            (state) => state.isLoadingMore,
            'isLoadingMore',
            true,
          ),
          isA<UserSearchState>()
              .having((state) => state.offset, 'offset', 100)
              .having((state) => state.hasMore, 'hasMore', true),
        ],
      );

      blocTest<UserSearchBloc, UserSearchState>(
        'skips profiles that are already shown when appending a page',
        setUp: () {
          when(
            () => mockProfileRepository.searchUsersProgressive(
              query: 'alice',
              limit: 50,
              offset: 50,
              sortBy: 'followers',
            ),
          ).thenAnswer(
            (_) => progressive([
              createTestProfile('a' * 64, 'Alice Cached'),
              createTestProfile('b' * 64, 'Alice Later'),
            ]),
          );
        },
        build: createBloc,
        seed: () => UserSearchState(
          status: UserSearchStatus.success,
          query: 'alice',
          results: [createTestProfile('a' * 64, 'Alice Cached')],
          offset: 50,
          hasMore: true,
        ),
        act: (bloc) => bloc.add(const UserSearchLoadMore()),
        verify: (bloc) {
          expect(bloc.state.results.map((profile) => profile.pubkey), [
            'a' * 64,
            'b' * 64,
          ]);
        },
      );

      blocTest<UserSearchBloc, UserSearchState>(
        'does nothing when hasMore is false',
        build: createBloc,
        seed: () => UserSearchState(
          status: UserSearchStatus.success,
          query: 'alice',
          results: createTestProfiles(10),
          offset: 10,
        ),
        act: (bloc) => bloc.add(const UserSearchLoadMore()),
        expect: () => <UserSearchState>[],
      );

      blocTest<UserSearchBloc, UserSearchState>(
        'does nothing when already loading more',
        build: createBloc,
        seed: () => UserSearchState(
          status: UserSearchStatus.success,
          query: 'alice',
          results: createTestProfiles(50),
          offset: 50,
          hasMore: true,
          isLoadingMore: true,
        ),
        act: (bloc) => bloc.add(const UserSearchLoadMore()),
        expect: () => <UserSearchState>[],
      );

      blocTest<UserSearchBloc, UserSearchState>(
        'does nothing when query is empty',
        build: createBloc,
        seed: () => const UserSearchState(hasMore: true),
        act: (bloc) => bloc.add(const UserSearchLoadMore()),
        expect: () => <UserSearchState>[],
      );

      blocTest<UserSearchBloc, UserSearchState>(
        'resets isLoadingMore on failure',
        setUp: () {
          when(
            () => mockProfileRepository.searchUsersProgressive(
              query: 'alice',
              limit: 50,
              offset: 50,
              sortBy: 'followers',
            ),
          ).thenAnswer(
            (_) => Stream<ProgressiveSearchResult>.error(
              Exception('Network error'),
            ),
          );
        },
        build: createBloc,
        seed: () => UserSearchState(
          status: UserSearchStatus.success,
          query: 'alice',
          results: createTestProfiles(50),
          offset: 50,
          hasMore: true,
        ),
        act: (bloc) => bloc.add(const UserSearchLoadMore()),
        expect: () => [
          isA<UserSearchState>().having(
            (s) => s.isLoadingMore,
            'isLoadingMore',
            true,
          ),
          isA<UserSearchState>()
              .having((s) => s.isLoadingMore, 'isLoadingMore', false)
              .having((s) => s.results.length, 'results.length', 50),
        ],
      );
    });

    group('UserSearchCleared', () {
      blocTest<UserSearchBloc, UserSearchState>(
        'resets to initial state',
        build: createBloc,
        seed: () => UserSearchState(
          status: UserSearchStatus.success,
          query: 'alice',
          results: [createTestProfile('a' * 64, 'Alice')],
          offset: 1,
        ),
        act: (bloc) => bloc.add(const UserSearchCleared()),
        expect: () => [const UserSearchState()],
      );
    });

    group('follow boost', () {
      // Boost ordering itself lives in ProfileRepository — see
      // profile_repository_test.dart for the ordering behaviour. These tests
      // verify that the BLoC wires the follow graph through to the repository
      // and preserves whatever ordering the repository returns.
      const debounceDuration = Duration(milliseconds: 400);

      UserProfile profile(String idPrefix, String name) =>
          createTestProfile('${idPrefix}x${'a' * 62}'.substring(0, 64), name);

      UserSearchBloc createBoostedBloc(FollowRepository followRepository) =>
          UserSearchBloc(
            profileRepository: mockProfileRepository,
            followRepository: followRepository,
            searchRunner: mockSearchRunner,
          );

      blocTest<UserSearchBloc, UserSearchState>(
        'forwards the follow graph as boostPubkeys on the initial page',
        setUp: () {
          when(
            () => mockProfileRepository.searchUsersProgressive(
              query: 'liz',
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
              boostPubkeys: any(named: 'boostPubkeys'),
            ),
          ).thenAnswer((_) => progressive([profile('01', 'Liz Sweigart')]));
        },
        build: () {
          final follows = _MockFollowRepository();
          when(
            () => follows.followingPubkeys,
          ).thenReturn(['01x${'a' * 61}', '02x${'a' * 61}']);
          return createBoostedBloc(follows);
        },
        act: (bloc) => bloc.add(const UserSearchQueryChanged('liz')),
        wait: debounceDuration,
        verify: (_) {
          verify(
            () => mockProfileRepository.searchUsersProgressive(
              query: 'liz',
              limit: 50,
              sortBy: 'followers',
              hasVideos: any(named: 'hasVideos'),
              boostPubkeys: {'01x${'a' * 61}', '02x${'a' * 61}'},
            ),
          ).called(1);
        },
      );

      blocTest<UserSearchBloc, UserSearchState>(
        'forwards an empty set when the follow list is empty',
        setUp: () {
          when(
            () => mockProfileRepository.searchUsersProgressive(
              query: 'test',
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
              boostPubkeys: any(named: 'boostPubkeys'),
            ),
          ).thenAnswer((_) => progressive([profile('00', 'Zoe')]));
        },
        build: () {
          final follows = _MockFollowRepository();
          when(() => follows.followingPubkeys).thenReturn(const []);
          return createBoostedBloc(follows);
        },
        act: (bloc) => bloc.add(const UserSearchQueryChanged('test')),
        wait: debounceDuration,
        verify: (_) {
          verify(
            () => mockProfileRepository.searchUsersProgressive(
              query: 'test',
              limit: 50,
              sortBy: 'followers',
              hasVideos: any(named: 'hasVideos'),
              boostPubkeys: <String>{},
            ),
          ).called(1);
        },
      );

      blocTest<UserSearchBloc, UserSearchState>(
        'emits results in the order returned by the repository',
        setUp: () {
          // The repository already applied boost ordering; the BLoC must
          // preserve that order and not reorder on its own.
          final liz = profile('01', 'Liz Sweigart');
          final zoe = profile('00', 'Zoe');
          final maya = profile('02', 'Maya');
          when(
            () => mockProfileRepository.searchUsersProgressive(
              query: 'liz',
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
              boostPubkeys: any(named: 'boostPubkeys'),
            ),
          ).thenAnswer((_) => progressive([liz, zoe, maya]));
        },
        build: () {
          final follows = _MockFollowRepository();
          when(() => follows.followingPubkeys).thenReturn(['01x${'a' * 61}']);
          return createBoostedBloc(follows);
        },
        act: (bloc) => bloc.add(const UserSearchQueryChanged('liz')),
        wait: debounceDuration,
        expect: () => [
          const UserSearchState(status: UserSearchStatus.loading, query: 'liz'),
          isA<UserSearchState>()
              .having((s) => s.status, 'status', UserSearchStatus.loading)
              .having(
                (s) => s.results.map((p) => p.displayName).toList(),
                'results order',
                ['Liz Sweigart', 'Zoe', 'Maya'],
              ),
          isA<UserSearchState>()
              .having((s) => s.status, 'status', UserSearchStatus.success)
              .having(
                (s) => s.results.map((p) => p.displayName).toList(),
                'results order',
                ['Liz Sweigart', 'Zoe', 'Maya'],
              ),
        ],
      );

      blocTest<UserSearchBloc, UserSearchState>(
        'does not forward boostPubkeys on UserSearchLoadMore',
        setUp: () {
          when(
            () => mockProfileRepository.searchUsersProgressive(
              query: 'liz',
              limit: any(named: 'limit'),
              offset: 50,
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          ).thenAnswer((_) => progressive([profile('99', 'Liz From Page 2')]));
        },
        build: () {
          final follows = _MockFollowRepository();
          when(() => follows.followingPubkeys).thenReturn(['99x${'a' * 61}']);
          return createBoostedBloc(follows);
        },
        seed: () => UserSearchState(
          status: UserSearchStatus.success,
          query: 'liz',
          results: createTestProfiles(50),
          offset: 50,
          hasMore: true,
        ),
        act: (bloc) => bloc.add(const UserSearchLoadMore()),
        verify: (_) {
          verify(
            () => mockProfileRepository.searchUsersProgressive(
              query: 'liz',
              limit: 50,
              offset: 50,
              sortBy: 'followers',
              hasVideos: any(named: 'hasVideos'),
            ),
          ).called(1);
        },
      );
    });

    group('hasVideos parameter', () {
      const debounceDuration = Duration(milliseconds: 400);

      blocTest<UserSearchBloc, UserSearchState>(
        'passes hasVideos: true to profileRepository when configured',
        setUp: () {
          when(
            () => mockProfileRepository.searchUsersProgressive(
              query: 'test',
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          ).thenAnswer((_) => progressive([]));
        },
        build: () => UserSearchBloc(
          profileRepository: mockProfileRepository,
          hasVideos: true,
          searchRunner: mockSearchRunner,
        ),
        act: (bloc) => bloc.add(const UserSearchQueryChanged('test')),
        wait: debounceDuration,
        verify: (_) {
          verify(
            () => mockProfileRepository.searchUsersProgressive(
              query: 'test',
              limit: 50,
              sortBy: 'followers',
              hasVideos: true,
            ),
          ).called(1);
        },
      );

      blocTest<UserSearchBloc, UserSearchState>(
        'passes hasVideos: true to profileRepository on load more',
        setUp: () {
          when(
            () => mockProfileRepository.searchUsersProgressive(
              query: 'alice',
              limit: 50,
              offset: 50,
              sortBy: 'followers',
              hasVideos: true,
            ),
          ).thenAnswer((_) => progressive(createTestProfiles(10)));
        },
        build: () => UserSearchBloc(
          profileRepository: mockProfileRepository,
          hasVideos: true,
        ),
        seed: () => UserSearchState(
          status: UserSearchStatus.success,
          query: 'alice',
          results: createTestProfiles(50),
          offset: 50,
          hasMore: true,
        ),
        act: (bloc) => bloc.add(const UserSearchLoadMore()),
        verify: (_) {
          verify(
            () => mockProfileRepository.searchUsersProgressive(
              query: 'alice',
              limit: 50,
              offset: 50,
              sortBy: 'followers',
              hasVideos: true,
            ),
          ).called(1);
        },
      );

      blocTest<UserSearchBloc, UserSearchState>(
        'defaults hasVideos to false when not specified',
        setUp: () {
          when(
            () => mockProfileRepository.searchUsersProgressive(
              query: 'test',
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          ).thenAnswer((_) => progressive([]));
        },
        build: createBloc,
        act: (bloc) => bloc.add(const UserSearchQueryChanged('test')),
        wait: debounceDuration,
        verify: (_) {
          verifyNever(
            () => mockProfileRepository.searchUsersProgressive(
              query: 'test',
              limit: 50,
              sortBy: 'followers',
              hasVideos: true,
            ),
          );
        },
      );
    });

    group('results preservation on failure', () {
      const debounceDuration = Duration(milliseconds: 400);

      blocTest<UserSearchBloc, UserSearchState>(
        'keeps previous results while a subsequent query is loading and '
        'emits failure on error',
        setUp: () {
          when(
            () => mockProfileRepository.searchUsersProgressive(
              query: 'alice',
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          ).thenAnswer(
            (_) => progressive([createTestProfile('a' * 64, 'Alice')]),
          );
          when(
            () => mockProfileRepository.searchUsersProgressive(
              query: 'error',
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          ).thenAnswer(
            (_) => Stream<ProgressiveSearchResult>.error(
              Exception('Network error'),
            ),
          );
        },
        build: createBloc,
        act: (bloc) async {
          final first = bloc.stream.firstWhere(
            (s) => s.query == 'alice' && s.status == UserSearchStatus.success,
          );
          bloc.add(const UserSearchQueryChanged('alice'));
          await first.timeout(
            const Duration(seconds: 5),
            onTimeout: () => fail('search for alice never succeeded'),
          );
          bloc.add(const UserSearchQueryChanged('error'));
        },
        wait: debounceDuration,
        expect: () => [
          const UserSearchState(
            status: UserSearchStatus.loading,
            query: 'alice',
          ),
          isA<UserSearchState>()
              .having((s) => s.status, 'status', UserSearchStatus.loading)
              .having((s) => s.results.length, 'results.length', 1),
          isA<UserSearchState>().having(
            (s) => s.status,
            'status',
            UserSearchStatus.success,
          ),
          // New query keeps the prior 'alice' results visible while loading.
          isA<UserSearchState>()
              .having((s) => s.status, 'status', UserSearchStatus.loading)
              .having((s) => s.query, 'query', 'error')
              .having(
                (s) => s.results,
                'stale results preserved',
                hasLength(1),
              ),
          // On failure, status flips to failure but the stale results are
          // retained in state — the UI decides whether to show them.
          isA<UserSearchState>()
              .having((s) => s.status, 'status', UserSearchStatus.failure)
              .having(
                (s) => s.results,
                'stale results still in state',
                hasLength(1),
              ),
        ],
      );
    });

    group('multiple sequential results', () {
      const debounceDuration = Duration(milliseconds: 400);

      blocTest<UserSearchBloc, UserSearchState>(
        'replaces previous results when a new query succeeds',
        setUp: () {
          when(
            () => mockProfileRepository.searchUsersProgressive(
              query: 'alice',
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          ).thenAnswer(
            (_) => progressive([createTestProfile('a' * 64, 'Alice')]),
          );
          when(
            () => mockProfileRepository.searchUsersProgressive(
              query: 'bob',
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          ).thenAnswer(
            (_) => progressive([
              createTestProfile('b' * 64, 'Bob'),
              createTestProfile('c' * 64, 'Bobby'),
            ]),
          );
        },
        build: createBloc,
        act: (bloc) async {
          final first = bloc.stream.firstWhere(
            (s) => s.query == 'alice' && s.status == UserSearchStatus.success,
          );
          bloc.add(const UserSearchQueryChanged('alice'));
          await first.timeout(
            const Duration(seconds: 5),
            onTimeout: () => fail('search for alice never succeeded'),
          );
          bloc.add(const UserSearchQueryChanged('bob'));
        },
        wait: debounceDuration,
        expect: () => [
          const UserSearchState(
            status: UserSearchStatus.loading,
            query: 'alice',
          ),
          isA<UserSearchState>()
              .having((s) => s.status, 'status', UserSearchStatus.loading)
              .having((s) => s.results.length, 'results.length', 1)
              .having(
                (s) => s.results.first.displayName,
                'first result',
                'Alice',
              ),
          isA<UserSearchState>().having(
            (s) => s.status,
            'status',
            UserSearchStatus.success,
          ),
          isA<UserSearchState>()
              .having((s) => s.status, 'status', UserSearchStatus.loading)
              .having((s) => s.query, 'query', 'bob'),
          isA<UserSearchState>()
              .having((s) => s.status, 'status', UserSearchStatus.loading)
              .having((s) => s.results.length, 'results.length', 2)
              .having(
                (s) => s.results.first.displayName,
                'first result',
                'Bob',
              ),
          isA<UserSearchState>().having(
            (s) => s.status,
            'status',
            UserSearchStatus.success,
          ),
        ],
      );
    });

    group('null feed tracker', () {
      const debounceDuration = Duration(milliseconds: 400);

      blocTest<UserSearchBloc, UserSearchState>(
        'succeeds without errors when feedTracker is null',
        setUp: () {
          when(
            () => mockProfileRepository.searchUsersProgressive(
              query: 'alice',
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          ).thenAnswer(
            (_) => progressive([createTestProfile('a' * 64, 'Alice')]),
          );
        },
        build: () => UserSearchBloc(
          profileRepository: mockProfileRepository,
          searchRunner: mockSearchRunner,
        ),
        act: (bloc) => bloc.add(const UserSearchQueryChanged('alice')),
        wait: debounceDuration,
        expect: () => [
          const UserSearchState(
            status: UserSearchStatus.loading,
            query: 'alice',
          ),
          isA<UserSearchState>()
              .having((s) => s.status, 'status', UserSearchStatus.loading)
              .having((s) => s.results.length, 'results.length', 1),
          isA<UserSearchState>().having(
            (s) => s.status,
            'status',
            UserSearchStatus.success,
          ),
        ],
      );
    });

    group('UserSearchState', () {
      test('copyWith creates copy with updated values', () {
        const state = UserSearchState();

        final updated = state.copyWith(
          status: UserSearchStatus.success,
          query: 'test',
          offset: 10,
          hasMore: true,
          isLoadingMore: true,
        );

        expect(updated.status, UserSearchStatus.success);
        expect(updated.query, 'test');
        expect(updated.results, isEmpty);
        expect(updated.offset, 10);
        expect(updated.hasMore, isTrue);
        expect(updated.isLoadingMore, isTrue);
      });

      test('copyWith preserves existing values when not specified', () {
        final state = UserSearchState(
          status: UserSearchStatus.success,
          query: 'test',
          results: [createTestProfile('a' * 64, 'Alice')],
          offset: 10,
          hasMore: true,
          isLoadingMore: true,
        );

        final updated = state.copyWith(status: UserSearchStatus.loading);

        expect(updated.status, UserSearchStatus.loading);
        expect(updated.query, 'test');
        expect(updated.results, hasLength(1));
        expect(updated.resultCount, isNull);
        expect(updated.offset, 10);
        expect(updated.hasMore, isTrue);
        expect(updated.isLoadingMore, isTrue);
      });

      test('props includes all fields', () {
        final profile = createTestProfile('a' * 64, 'Alice');
        final state = UserSearchState(
          status: UserSearchStatus.success,
          query: 'alice',
          results: [profile],
          offset: 1,
          hasMore: true,
        );

        expect(state.props, [
          UserSearchStatus.success,
          'alice',
          [profile],
          -1,
          1,
          true,
          false,
          <SearchSource, SearchSourceStatus>{},
          <String, UserRankingSignals>{},
        ]);
      });
    });

    group('feed performance tracking', () {
      late _MockProfileRepository mockRepo;
      late _MockFeedPerformanceTracker mockTracker;
      late FeedLoadHandle feedLoad;

      // Debounce duration used in the BLoC + buffer
      const debounceDuration = Duration(milliseconds: 400);

      setUp(() {
        mockRepo = _MockProfileRepository();
        mockTracker = _MockFeedPerformanceTracker();
        feedLoad = FeedPerformanceTracker(
          sink: const NoOpAnalyticsEventSink(),
        ).startFeedLoad('test');
        when(() => mockTracker.startFeedLoad(any())).thenReturn(feedLoad);
      });

      UserSearchBloc createBlocWithTracker() => UserSearchBloc(
        profileRepository: mockRepo,
        feedTracker: mockTracker,
        searchRunner:
            ({
              required query,
              required limit,
              required sortBy,
              required hasVideos,
              required boostPubkeys,
              required cancellationToken,
            }) => mockRepo.searchUsersProgressive(
              query: query,
              limit: limit,
              sortBy: sortBy,
              hasVideos: hasVideos,
              boostPubkeys: boostPubkeys,
            ),
      );

      blocTest<UserSearchBloc, UserSearchState>(
        'calls startFeedLoad, markFirstVideosReceived, and '
        'markFeedDisplayed on success',
        setUp: () {
          when(
            () => mockRepo.searchUsersProgressive(
              query: 'alice',
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          ).thenAnswer(
            (_) => progressive([createTestProfile('a' * 64, 'Alice')]),
          );
        },
        build: createBlocWithTracker,
        act: (bloc) => bloc.add(const UserSearchQueryChanged('alice')),
        wait: debounceDuration,
        verify: (_) {
          verify(() => mockTracker.startFeedLoad('user_search')).called(1);
          verify(
            () => mockTracker.markFirstVideosReceived(feedLoad, 1),
          ).called(1);
          verify(
            () => mockTracker.markFeedDisplayed(feedLoad, 1),
          ).called(1);
        },
      );

      blocTest<UserSearchBloc, UserSearchState>(
        'calls trackFeedError on failure',
        setUp: () {
          when(
            () => mockRepo.searchUsersProgressive(
              query: 'error',
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          ).thenAnswer(
            (_) => Stream<ProgressiveSearchResult>.error(
              Exception('Network error'),
            ),
          );
        },
        build: createBlocWithTracker,
        act: (bloc) => bloc.add(const UserSearchQueryChanged('error')),
        wait: debounceDuration,
        verify: (_) {
          verify(() => mockTracker.startFeedLoad('user_search')).called(1);
          verify(
            () => mockTracker.trackFeedError(
              'user_search',
              errorType: 'search_failed',
              errorMessage: any(named: 'errorMessage'),
            ),
          ).called(1);
          verifyNever(
            () => mockTracker.markFirstVideosReceived(feedLoad, any()),
          );
          verifyNever(() => mockTracker.markFeedDisplayed(feedLoad, any()));
        },
      );

      blocTest<UserSearchBloc, UserSearchState>(
        'does not call tracker for empty query',
        build: createBlocWithTracker,
        act: (bloc) => bloc.add(const UserSearchQueryChanged('')),
        wait: debounceDuration,
        verify: (_) {
          verifyNever(() => mockTracker.startFeedLoad(any()));
        },
      );

      blocTest<UserSearchBloc, UserSearchState>(
        'forwards each terminal source outcome to trackSearchSource',
        setUp: () {
          when(
            () => mockRepo.searchUsersProgressive(
              query: 'alice',
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          ).thenAnswer(
            (_) => Stream.value(
              ProgressiveSearchResult(
                profiles: [createTestProfile('a' * 64, 'Alice')],
                sources: const {
                  SearchSource.localCache: SearchSourceSuccess(
                    resultCount: 1,
                    latencyMs: 1,
                  ),
                  SearchSource.funnelcakeApi: SearchSourceFailed(
                    reason: SearchSourceFailureReason.network,
                    latencyMs: 200,
                  ),
                  SearchSource.nip50Relay: SearchSourceSkipped(),
                },
                isComplete: true,
              ),
            ),
          );
        },
        build: createBlocWithTracker,
        act: (bloc) => bloc.add(const UserSearchQueryChanged('alice')),
        wait: debounceDuration,
        verify: (_) {
          verify(
            () => mockTracker.trackSearchSource(
              SearchSource.localCache,
              any(that: isA<SearchSourceSuccess>()),
            ),
          ).called(1);
          verify(
            () => mockTracker.trackSearchSource(
              SearchSource.funnelcakeApi,
              any(that: isA<SearchSourceFailed>()),
            ),
          ).called(1);
          verify(
            () => mockTracker.trackSearchSource(
              SearchSource.nip50Relay,
              any(that: isA<SearchSourceSkipped>()),
            ),
          ).called(1);
        },
      );
    });

    group('source provenance', () {
      const debounceDuration = Duration(milliseconds: 400);

      blocTest<UserSearchBloc, UserSearchState>(
        'round-trips sourceOutcomes from repository envelope into state',
        setUp: () {
          when(
            () => mockProfileRepository.searchUsersProgressive(
              query: 'alice',
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          ).thenAnswer(
            (_) => Stream.value(
              ProgressiveSearchResult(
                profiles: [createTestProfile('a' * 64, 'Alice')],
                sources: const {
                  SearchSource.localCache: SearchSourceSuccess(
                    resultCount: 1,
                    latencyMs: 1,
                  ),
                  SearchSource.funnelcakeApi: SearchSourceSuccess(
                    resultCount: 0,
                    latencyMs: 50,
                  ),
                  SearchSource.nip50Relay: SearchSourceFailed(
                    reason: SearchSourceFailureReason.timeout,
                    latencyMs: 5000,
                  ),
                },
                isComplete: true,
              ),
            ),
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(const UserSearchQueryChanged('alice')),
        wait: debounceDuration,
        verify: (bloc) {
          final relay = bloc.state.sourceOutcomes[SearchSource.nip50Relay];
          expect(relay, isA<SearchSourceFailed>());
          expect(
            (relay! as SearchSourceFailed).reason,
            SearchSourceFailureReason.timeout,
          );
          expect(
            bloc.state.sourceOutcomes[SearchSource.localCache],
            isA<SearchSourceSuccess>(),
          );
          expect(bloc.state.isDegradedEmpty, isFalse); // results non-empty
        },
      );

      blocTest<UserSearchBloc, UserSearchState>(
        'resets prior source outcomes before timing out a new query',
        setUp: () {
          final controller = StreamController<ProgressiveSearchResult>();
          addTearDown(controller.close);
          when(
            () => mockProfileRepository.searchUsersProgressive(
              query: 'fresh-query',
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          ).thenAnswer((_) => controller.stream);
        },
        build: () =>
            createBloc(searchTimeout: const Duration(milliseconds: 10)),
        seed: () => const UserSearchState(
          status: UserSearchStatus.success,
          query: 'stale-query',
          sourceOutcomes: {
            SearchSource.localCache: SearchSourceSuccess(
              resultCount: 0,
              latencyMs: 1,
            ),
            SearchSource.funnelcakeApi: SearchSourceSkipped(),
            SearchSource.nip50Relay: SearchSourceSuccess(
              resultCount: 0,
              latencyMs: 5,
            ),
          },
        ),
        act: (bloc) async {
          final finished = bloc.stream.firstWhere(
            (state) =>
                state.query == 'fresh-query' &&
                state.status == UserSearchStatus.success,
          );
          bloc.add(const UserSearchQueryChanged('fresh-query'));
          // The timeout starts after the debounce callback actually runs.
          // Await its state transition, not a competing wall-clock test wait.
          await finished;
        },
        verify: (bloc) {
          expect(bloc.state.status, UserSearchStatus.success);
          expect(bloc.state.query, 'fresh-query');
          for (final source in SearchSource.values) {
            expect(
              bloc.state.sourceOutcomes[source],
              isA<SearchSourceFailed>().having(
                (f) => f.reason,
                'reason',
                SearchSourceFailureReason.timeout,
              ),
            );
          }
        },
      );

      blocTest<UserSearchBloc, UserSearchState>(
        'isDegradedEmpty becomes true when outer timeout fires on empty '
        'accumulated results',
        setUp: () {
          // Never-completing stream that emits no envelope at all.
          final controller = StreamController<ProgressiveSearchResult>();
          when(
            () => mockProfileRepository.searchUsersProgressive(
              query: 'unreachable',
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          ).thenAnswer((_) => controller.stream);
        },
        build: () =>
            createBloc(searchTimeout: const Duration(milliseconds: 10)),
        act: (bloc) => bloc.add(const UserSearchQueryChanged('unreachable')),
        wait: const Duration(milliseconds: 500),
        verify: (bloc) {
          expect(bloc.state.status, UserSearchStatus.success);
          expect(bloc.state.results, isEmpty);
          expect(bloc.state.isDegradedEmpty, isTrue);
          for (final source in SearchSource.values) {
            expect(
              bloc.state.sourceOutcomes[source],
              isA<SearchSourceFailed>().having(
                (f) => f.reason,
                'reason',
                SearchSourceFailureReason.timeout,
              ),
            );
          }
        },
      );

      test('isDegradedEmpty getter: false on initial state', () {
        const state = UserSearchState();
        expect(state.isDegradedEmpty, isFalse);
      });

      test('isDegradedEmpty getter: false with non-empty results even when '
          'a source failed', () {
        final profile = UserProfile(
          pubkey: 'a' * 64,
          displayName: 'Alice',
          createdAt: DateTime.now(),
          eventId: 'e1',
          rawData: const {'display_name': 'Alice'},
        );
        final state = UserSearchState(
          status: UserSearchStatus.success,
          results: [profile],
          sourceOutcomes: const {
            SearchSource.nip50Relay: SearchSourceFailed(
              reason: SearchSourceFailureReason.timeout,
              latencyMs: 5000,
            ),
          },
        );
        expect(state.isDegradedEmpty, isFalse);
      });

      test('isDegradedEmpty getter: true with empty results and a failed '
          'source', () {
        const state = UserSearchState(
          status: UserSearchStatus.success,
          sourceOutcomes: {
            SearchSource.nip50Relay: SearchSourceFailed(
              reason: SearchSourceFailureReason.timeout,
              latencyMs: 5000,
            ),
          },
        );
        expect(state.isDegradedEmpty, isTrue);
      });

      test('isDegradedEmpty getter: false with empty results but all sources '
          'succeeded (true empty)', () {
        const state = UserSearchState(
          status: UserSearchStatus.success,
          sourceOutcomes: {
            SearchSource.localCache: SearchSourceSuccess(
              resultCount: 0,
              latencyMs: 1,
            ),
            SearchSource.funnelcakeApi: SearchSourceSuccess(
              resultCount: 0,
              latencyMs: 50,
            ),
            SearchSource.nip50Relay: SearchSourceSuccess(
              resultCount: 0,
              latencyMs: 500,
            ),
          },
        );
        expect(state.isDegradedEmpty, isFalse);
      });
    });
  });
}
