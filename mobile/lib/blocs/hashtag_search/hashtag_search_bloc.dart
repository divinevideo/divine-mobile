// ABOUTME: BLoC for searching hashtags via HashtagRepository (Funnelcake API).
// ABOUTME: Debounces queries and delegates to server-side hashtag search.

import 'package:analytics/analytics.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hashtag_repository/hashtag_repository.dart';
import 'package:openvine/constants/search_constants.dart';
import 'package:stream_transform/stream_transform.dart';

part 'hashtag_search_event.dart';
part 'hashtag_search_state.dart';

/// Event transformer that debounces and restarts on new events
EventTransformer<E> _debounceRestartable<E>() {
  return (events, mapper) {
    return restartable<E>().call(
      events.debounce(searchDebounceDuration),
      mapper,
    );
  };
}

/// Hashtag chips are visually short, so each page needs to add enough rows to
/// stay ahead of `ScrollPaginationMixin`'s viewport-relative prefetch.
const _pageSize = 50;

/// BLoC for searching hashtags via the Funnelcake API.
///
/// Delegates search to [HashtagRepository] which handles remote search
/// with local fallback. Results are sorted by popularity/trending
/// on the server.
class HashtagSearchBloc extends Bloc<HashtagSearchEvent, HashtagSearchState> {
  HashtagSearchBloc({
    required HashtagRepository hashtagRepository,
    FeedPerformanceTracker? feedTracker,
  }) : _hashtagRepository = hashtagRepository,
       _feedTracker = feedTracker,
       super(const HashtagSearchState()) {
    on<HashtagSearchQueryChanged>(
      _onQueryChanged,
      transformer: _debounceRestartable(),
    );
    on<HashtagSearchLoadMore>(_onLoadMore, transformer: sequential());
    on<HashtagSearchCleared>(_onCleared);
    on<HashtagSearchBlocklistChanged>(
      _onBlocklistChanged,
      transformer: restartable(),
    );
  }

  final HashtagRepository _hashtagRepository;
  final FeedPerformanceTracker? _feedTracker;

  Future<void> _onQueryChanged(
    HashtagSearchQueryChanged event,
    Emitter<HashtagSearchState> emit,
  ) async {
    final query = event.query.trim().toLowerCase();

    // Empty query resets to initial state
    if (query.isEmpty || query.length < minSearchQueryLength) {
      emit(const HashtagSearchState());
      return;
    }

    if (query == state.query &&
        state.status != HashtagSearchStatus.initial &&
        state.status != HashtagSearchStatus.failure) {
      return;
    }

    await _runSearch(query, emit);
  }

  /// Re-runs the current search after a block/unblock so results pass
  /// through the repository's block filter again. Bypasses the same-query
  /// guard in [_onQueryChanged] on purpose — the query is unchanged but
  /// the result set is not.
  Future<void> _onBlocklistChanged(
    HashtagSearchBlocklistChanged event,
    Emitter<HashtagSearchState> emit,
  ) async {
    if (state.query.isEmpty) return;
    await _runSearch(state.query, emit);
  }

  Future<void> _runSearch(
    String query,
    Emitter<HashtagSearchState> emit,
  ) async {
    emit(
      state.copyWith(
        status: HashtagSearchStatus.loading,
        query: query,
        resultCount: null,
      ),
    );

    final feedLoad = _feedTracker?.startFeedLoad('hashtag_search');

    try {
      final results = await _hashtagRepository.searchHashtags(
        query: query,
        limit: _pageSize,
      );

      if (feedLoad != null) {
        _feedTracker?.markFirstVideosReceived(feedLoad, results.length);
      }

      emit(
        state.copyWith(
          status: HashtagSearchStatus.success,
          results: results,
          resultCount: results.length,
          offset: results.length,
          hasMore: results.length == _pageSize,
          isLoadingMore: false,
        ),
      );

      if (feedLoad != null) {
        _feedTracker?.markFeedDisplayed(feedLoad, results.length);
      }
    } on Exception catch (e) {
      // Defensive: repository.searchHashtags should never throw per its
      // contract, but we guard against unexpected violations to avoid
      // unhandled exceptions in the UI.
      _feedTracker?.trackFeedError(
        'hashtag_search',
        errorType: 'search_failed',
        errorMessage: e.toString(),
      );
      emit(state.copyWith(status: HashtagSearchStatus.failure));
    } finally {
      if (feedLoad != null) _feedTracker?.abandonFeedLoad(feedLoad);
    }
  }

  Future<void> _onLoadMore(
    HashtagSearchLoadMore event,
    Emitter<HashtagSearchState> emit,
  ) async {
    if (!state.hasMore || state.isLoadingMore || state.query.isEmpty) return;

    emit(state.copyWith(isLoadingMore: true));

    try {
      final moreResults = await _hashtagRepository.searchHashtags(
        query: state.query,
        limit: _pageSize,
        offset: state.offset,
      );

      final existing = state.results.toSet();
      final deduped = moreResults.where((r) => !existing.contains(r)).toList();
      final allResults = [...state.results, ...deduped];

      emit(
        state.copyWith(
          results: allResults,
          offset: allResults.length,
          hasMore: moreResults.length == _pageSize,
          isLoadingMore: false,
        ),
      );
    } on Exception catch (e, stackTrace) {
      addError(e, stackTrace);
      emit(state.copyWith(isLoadingMore: false));
    }
  }

  void _onCleared(
    HashtagSearchCleared event,
    Emitter<HashtagSearchState> emit,
  ) {
    emit(const HashtagSearchState());
  }
}
