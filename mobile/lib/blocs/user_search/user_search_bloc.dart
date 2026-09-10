// ABOUTME: BLoC for searching user profiles via ProfileRepository.

import 'dart:async';

import 'package:analytics/analytics.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/nip19/pubkeys_equal.dart';
import 'package:openvine/constants/search_constants.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:unified_logger/unified_logger.dart';

part 'user_search_event.dart';
part 'user_search_state.dart';

/// Number of results per page
const _pageSize = 50;
int _nextSearchCorrelationId = 0;

typedef UserSearchRunner = Stream<ProgressiveSearchResult> Function({
  required String query,
  required int limit,
  required String sortBy,
  required bool hasVideos,
  required Set<String>? boostPubkeys,
  required SearchCancellationToken cancellationToken,
});

Map<SearchSource, SearchSourceStatus> _pendingSourceOutcomes() {
  return {
    for (final source in SearchSource.values)
      source: const SearchSourcePending(),
  };
}

/// BLoC for searching user profiles.
class UserSearchBloc extends Bloc<UserSearchEvent, UserSearchState> {
  UserSearchBloc({
    required ProfileRepository profileRepository,
    FollowRepository? followRepository,
    this.hasVideos = false,
    this.searchTimeout = userSearchOuterTimeout,
    this.excludedPubkey,
    FeedPerformanceTracker? feedTracker,
    UserSearchRunner? searchRunner,
  }) : _profileRepository = profileRepository,
       _followRepository = followRepository,
       _feedTracker = feedTracker,
       _searchRunner = searchRunner,
       super(const UserSearchState()) {
    on<UserSearchQueryChanged>(
      _onQueryChanged,
      transformer: debounceRestartable(),
    );
    on<UserSearchCleared>(_onCleared);
    on<UserSearchLoadMore>(_onLoadMore, transformer: sequential());
  }

  final ProfileRepository _profileRepository;

  /// Optional follow graph used to boost followed users to the top of the
  /// initial search page. Null for consumers that want raw server ranking.
  final FollowRepository? _followRepository;

  final FeedPerformanceTracker? _feedTracker;
  final UserSearchRunner? _searchRunner;

  /// Whether to filter results to users who have uploaded videos.
  final bool hasVideos;

  /// Optional timeout for the progressive search stream.
  ///
  /// Set to `null` to disable the timeout entirely, which is useful in widget
  /// tests that rely on `pumpAndSettle()` with internally created blocs.
  final Duration? searchTimeout;

  /// A pubkey to omit from every result page, such as a recipient picker's
  /// signed-in viewer.
  final String? excludedPubkey;

  List<UserProfile> _visibleProfiles(Iterable<UserProfile> profiles) {
    final excluded = excludedPubkey;
    if (excluded == null) return profiles.toList();
    return profiles
        .where((profile) => !pubkeysEqual(profile.pubkey, excluded))
        .toList();
  }

  Future<void> _onQueryChanged(
    UserSearchQueryChanged event,
    Emitter<UserSearchState> emit,
  ) async {
    final query = event.query.trim();

    // Empty query resets to initial state
    if (query.isEmpty || query.length < minSearchQueryLength) {
      emit(const UserSearchState());
      return;
    }

    // No dedup guard here — the restartable() transformer already cancels the
    // previous in-flight handler via switchMap. Adding a same-query skip caused
    // the search to get stuck in loading/empty-success states with no recovery
    // path (the user could never re-trigger the same query).

    emit(
      state.copyWith(
        status: UserSearchStatus.loading,
        query: query,
        offset: 0,
        hasMore: false,
        isLoadingMore: false,
        sourceOutcomes: const {},
      ),
    );

    final feedLoad = _feedTracker?.startFeedLoad('user_search');
    var trackedFirst = false;
    var latestUnfilteredCount = 0;
    int? nextRestOffset;
    var restHasMore = false;
    var latestSourceOutcomes = _pendingSourceOutcomes();
    // Snapshot of sources whose terminal status has already been
    // forwarded to feedTracker — prevents duplicate events when a
    // source's outcome is repeated across yields.
    final trackedSources = <SearchSource>{};

    // Snapshot the follow graph once for this query so every progressive
    // yield uses the same boost set. Boost ordering is applied inside the
    // repository (see ProfileRepository.searchUsersProgressive), keeping
    // ranking logic out of the BLoC.
    final followedPubkeys = _followRepository?.followingPubkeys.toSet();
    final cancellationToken = SearchCancellationToken(
      'user-search-${++_nextSearchCorrelationId}',
    );
    var reachedTerminalState = false;
    Log.debug(
      '${cancellationToken.correlationId} started; queryLength=${query.length}',
      name: 'UserSearchBloc',
      category: LogCategory.api,
    );

    try {
      final searchStream =
          _searchRunner?.call(
            query: query,
            limit: _pageSize,
            sortBy: profileSearchSortFollowers,
            hasVideos: hasVideos,
            boostPubkeys: followedPubkeys,
            cancellationToken: cancellationToken,
          ) ??
          _profileRepository.searchUsersProgressive(
            query: query,
            limit: _pageSize,
            sortBy: profileSearchSortFollowers,
            hasVideos: hasVideos,
            boostPubkeys: followedPubkeys,
            cancellationToken: cancellationToken,
          );

      await emit.forEach<ProgressiveSearchResult>(
        searchTimeout == null
            ? searchStream
            : searchStream.timeout(searchTimeout!),
        onData: (result) {
          latestUnfilteredCount = result.profiles.length;
          nextRestOffset = result.nextRestOffset;
          restHasMore = result.restHasMore;
          final visibleProfiles = _visibleProfiles(result.profiles);
          if (!trackedFirst && visibleProfiles.isNotEmpty) {
            trackedFirst = true;
            if (feedLoad != null) {
              _feedTracker?.markFirstVideosReceived(
                feedLoad,
                visibleProfiles.length,
              );
            }
          }
          for (final entry in result.sources.entries) {
            if (entry.value is! SearchSourcePending &&
                trackedSources.add(entry.key)) {
              _feedTracker?.trackSearchSource(entry.key, entry.value);
              Log.debug(
                '${cancellationToken.correlationId} source=${entry.key.name} '
                'outcome=${entry.value.runtimeType}',
                name: 'UserSearchBloc',
                category: LogCategory.api,
              );
            }
          }
          latestSourceOutcomes = result.sources;
          return state.copyWith(
            status: UserSearchStatus.loading,
            results: visibleProfiles,
            resultCount: visibleProfiles.length,
            sourceOutcomes: result.sources,
          );
        },
      );

      emit(
        state.copyWith(
          status: UserSearchStatus.success,
          offset: nextRestOffset ?? latestUnfilteredCount,
          hasMore: restHasMore,
          isLoadingMore: false,
        ),
      );

      if (feedLoad != null) {
        _feedTracker?.markFeedDisplayed(feedLoad, state.results.length);
      }
      reachedTerminalState = true;
    } on TimeoutException {
      // Outer stream timed out. Promote every source still in pending
      // (or absent from the latest snapshot) to failed(timeout) so the
      // UI's isDegradedEmpty getter can distinguish this from a true
      // empty result.
      final outerTimeoutMs = searchTimeout!.inMilliseconds;
      final updatedOutcomes =
          <SearchSource, SearchSourceStatus>{
            for (final source in SearchSource.values)
              source: switch (latestSourceOutcomes[source]) {
                null || SearchSourcePending() => SearchSourceFailed(
                  reason: SearchSourceFailureReason.timeout,
                  latencyMs: outerTimeoutMs,
                ),
                final SearchSourceStatus s => s,
              },
          }..forEach((source, status) {
            if (status is SearchSourceFailed &&
                latestSourceOutcomes[source] is! SearchSourceFailed &&
                trackedSources.add(source)) {
              _feedTracker?.trackSearchSource(source, status);
            }
          });

      emit(
        state.copyWith(
          status: UserSearchStatus.success,
          offset: state.results.length,
          hasMore: false,
          isLoadingMore: false,
          sourceOutcomes: updatedOutcomes,
        ),
      );
      reachedTerminalState = true;
    } on Exception catch (e, stackTrace) {
      _feedTracker?.trackFeedError(
        'user_search',
        errorType: 'search_failed',
        errorMessage: e.toString(),
      );
      // Wrap with Reportable so unexpected non-network/non-timeout
      // failures surface in Crashlytics. Per error_handling.md, the
      // expected network/timeout exceptions are matrix-non-reportable
      // — those land in the TimeoutException branch above.
      addError(Reportable(e, context: '_onQueryChanged'), stackTrace);
      emit(state.copyWith(status: UserSearchStatus.failure));
      reachedTerminalState = true;
    } finally {
      if (feedLoad != null) _feedTracker?.abandonFeedLoad(feedLoad);
      cancellationToken.cancel();
      Log.debug(
        '${cancellationToken.correlationId} '
        '${reachedTerminalState ? "completed" : "cancelled"}; '
        'resultCount=${state.results.length}',
        name: 'UserSearchBloc',
        category: LogCategory.api,
      );
    }
  }

  Future<void> _onLoadMore(
    UserSearchLoadMore event,
    Emitter<UserSearchState> emit,
  ) async {
    if (!state.hasMore || state.isLoadingMore || state.query.isEmpty) return;

    emit(state.copyWith(isLoadingMore: true));

    try {
      final result = await _profileRepository
          .searchUsersProgressive(
            query: state.query,
            limit: _pageSize,
            offset: state.offset,
            sortBy: profileSearchSortFollowers,
            hasVideos: hasVideos,
          )
          .last; // Stream always emits at least once for non-empty queries.

      // Pagination yields contain only the new page; we observe by
      // counting the profiles in the terminal envelope (filter+boost
      // applied) against pagination state. The new page is the slice
      // that the repository computed for offset > 0.
      final unfilteredPageCount = result.profiles.length;
      final newPage = _visibleProfiles(result.profiles);
      final allResults = [...state.results, ...newPage];

      emit(
        state.copyWith(
          results: allResults,
          offset: result.nextRestOffset ?? state.offset + unfilteredPageCount,
          hasMore: result.restHasMore,
          isLoadingMore: false,
        ),
      );
    } on Exception {
      emit(state.copyWith(isLoadingMore: false));
    }
  }

  void _onCleared(UserSearchCleared event, Emitter<UserSearchState> emit) {
    emit(const UserSearchState());
  }
}
