// ABOUTME: Tests for UserSearchBloc - user search via ProfileRepository
// ABOUTME: Tests streaming states, error handling, debouncing, and pagination

import 'dart:async';

import 'package:analytics/analytics.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/user_search/user_search_bloc.dart';
import 'package:profile_repository/profile_repository.dart';

class _MockProfileRepository extends Mock implements ProfileRepository {}

class _MockFollowRepository extends Mock implements FollowRepository {}

class _MockFeedPerformanceTracker extends Mock
    implements FeedPerformanceTracker {}

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
    }) => UserSearchBloc(
      profileRepository: mockProfileRepository,
      searchTimeout: searchTimeout,
      excludedPubkey: excludedPubkey,
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

    List<UserProfile> createTestProfiles(int count) {
      return List.generate(
        count,
        (i) => createTestProfile(
          '${i.toString().padLeft(2, '0')}${'a' * 62}',
          'User $i',
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

    test('initial state is correct', () {
      final bloc = createBloc();
      expect(bloc.state.status, UserSearchStatus.initial);
      expect(bloc.state.query, isEmpty);
      expect(bloc.state.results, isEmpty);
      expect(bloc.state.resultCount, isNull);
      expect(bloc.state.offset, 0);
      expect(bloc.state.hasMore, isFalse);
      expect(bloc.state.isLoadingMore, isFalse);
      bloc.close();
    });

    test('superseding a running query cancels its repository token', () async {
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

      bloc.add(const UserSearchQueryChanged('first'));
      await Future<void>.delayed(const Duration(milliseconds: 450));
      bloc.add(const UserSearchQueryChanged('second'));
      await Future<void>.delayed(const Duration(milliseconds: 450));

      expect(tokens, hasLength(2));
      expect(tokens.first.isCancelled, isTrue);
      expect(tokens.last.isCancelled, isFalse);
      await bloc.close();
      expect(tokens.last.isCancelled, isTrue);
      for (final controller in controllers) {
        await controller.close();
      }
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
          ).thenAnswer((_) => progressive(createTestProfiles(10)));
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
          final partial = createTestProfiles(5);
          final full = createTestProfiles(10);
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
            (_) => progressive(createTestProfiles(50), restHasMore: true),
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
          bloc.add(const UserSearchQueryChanged('alice'));
          await Future<void>.delayed(debounceDuration);
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
          bloc.add(const UserSearchQueryChanged('alice'));
          await Future<void>.delayed(debounceDuration);
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
        act: (bloc) => bloc.add(const UserSearchQueryChanged('fresh-query')),
        wait: const Duration(milliseconds: 500),
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
