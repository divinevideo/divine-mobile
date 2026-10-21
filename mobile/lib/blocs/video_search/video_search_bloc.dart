// ABOUTME: BLoC for searching videos via VideosRepository.
// ABOUTME: Delegates search to the repository layer via a progressive stream.
// ABOUTME: Supports pagination via VideoSearchLoadMore for infinite scroll.

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart';
import 'package:openvine/constants/search_constants.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:stream_transform/stream_transform.dart';
import 'package:videos_repository/videos_repository.dart';

part 'video_search_event.dart';
part 'video_search_state.dart';

/// Page size for API pagination.
const _pageSize = 50;

/// Event transformer that debounces and restarts on new events
EventTransformer<E> _debounceRestartable<E>() {
  return (events, mapper) {
    return restartable<E>().call(
      events.debounce(searchDebounceDuration),
      mapper,
    );
  };
}

/// BLoC for searching videos via [VideosRepository].
///
/// Delegates all search logic (local cache, REST API, NIP-50 relays)
/// to the repository layer, keeping the BLoC focused on state management.
///
/// Search is progressive — the repository stream yields accumulated
/// results as each source completes:
/// 1. Local cache results (instant)
/// 2. API or relay results (whichever finishes first)
/// 3. Remaining source results (all done)
///
/// After the initial search, [VideoSearchLoadMore] fetches additional
/// pages from the API for infinite scroll.
class VideoSearchBloc extends Bloc<VideoSearchEvent, VideoSearchState> {
  VideoSearchBloc({required VideosRepository videosRepository})
    : _videosRepository = videosRepository,
      super(const VideoSearchState()) {
    on<VideoSearchQueryChanged>(
      _onQueryChanged,
      transformer: _debounceRestartable(),
    );
    on<VideoSearchCleared>(_onCleared);
    on<VideoSearchSortChanged>(_onSortChanged, transformer: restartable());
    on<VideoSearchLoadMore>(_onLoadMore, transformer: sequential());
    on<VideoSearchBlocklistChanged>(
      _onBlocklistChanged,
      transformer: restartable(),
    );
  }

  final VideosRepository _videosRepository;
  int _searchSessionId = 0;

  Future<void> _onQueryChanged(
    VideoSearchQueryChanged event,
    Emitter<VideoSearchState> emit,
  ) async {
    final query = event.query.trim();

    if (query.isEmpty ||
        query.length < minSearchQueryLength ||
        NostrKeyUtils.containsPrivateKey(query)) {
      _invalidateSearchSession();
      emit(const VideoSearchState());
      return;
    }

    if (query == state.query &&
        state.status != VideoSearchStatus.initial &&
        state.status != VideoSearchStatus.failure) {
      return;
    }

    await _search(
      query: query,
      sort: state.sort,
      emit: emit,
      sessionId: _beginSearchSession(),
    );
  }

  /// Re-runs the current search after a block/unblock so results pass
  /// through the repository's block filter again. Bypasses the same-query
  /// guard in [_onQueryChanged] on purpose — the query is unchanged but
  /// the result set is not.
  Future<void> _onBlocklistChanged(
    VideoSearchBlocklistChanged event,
    Emitter<VideoSearchState> emit,
  ) async {
    if (state.query.isEmpty) return;
    await _search(
      query: state.query,
      sort: state.sort,
      emit: emit,
      sessionId: _beginSearchSession(),
    );
  }

  Future<void> _search({
    required String query,
    required VideoSearchSort sort,
    required Emitter<VideoSearchState> emit,
    required int sessionId,
  }) async {
    emit(
      state.copyWith(
        status: VideoSearchStatus.searching,
        query: query,
        sort: sort,
        resultCount: null,
        apiOffset: 0,
        totalApiCount: null,
        hasMore: false,
        isLoadingMore: false,
      ),
    );

    try {
      await emit.forEach<List<VideoEvent>>(
        _videosRepository.searchVideos(query: query, sort: sort),
        onData: (videos) {
          if (!_isActiveSession(sessionId)) {
            return state;
          }

          return state.copyWith(
            status: VideoSearchStatus.searching,
            videos: videos,
            resultCount: videos.length,
          );
        },
      );
      if (!_isActiveSession(sessionId)) return;
      // Progressive stream complete — set pagination state.
      // One API page was consumed during the stream; assume more exist
      // only if we actually received results.
      emit(
        state.copyWith(
          status: VideoSearchStatus.success,
          apiOffset: _pageSize,
          hasMore: state.videos.isNotEmpty,
        ),
      );
    } on Exception catch (e, stackTrace) {
      if (!_isActiveSession(sessionId)) return;
      // Matrix-NO: searchVideos stream surfaces API / relay / network
      // failures (Network/IO category).
      addError(e, stackTrace);
      emit(state.copyWith(status: VideoSearchStatus.failure));
    }
  }

  Future<void> _onSortChanged(
    VideoSearchSortChanged event,
    Emitter<VideoSearchState> emit,
  ) async {
    if (event.sort == state.sort) return;
    final query = state.query;

    emit(
      state.copyWith(
        sort: event.sort,
        videos: const [],
        resultCount: null,
        apiOffset: 0,
        totalApiCount: null,
        hasMore: false,
        isLoadingMore: false,
      ),
    );

    if (query.isEmpty) return;
    await _search(
      query: query,
      sort: event.sort,
      emit: emit,
      sessionId: _beginSearchSession(),
    );
  }

  Future<void> _onLoadMore(
    VideoSearchLoadMore event,
    Emitter<VideoSearchState> emit,
  ) async {
    if (!state.hasMore || state.isLoadingMore || state.query.isEmpty) return;

    final sessionId = _searchSessionId;
    final query = state.query;
    final sort = state.sort;
    final apiOffset = state.apiOffset;
    final currentVideos = state.videos;

    emit(state.copyWith(isLoadingMore: true));

    try {
      final result = await _videosRepository.searchVideosViaApi(
        query: query,
        offset: apiOffset,
        sort: sort,
      );
      if (!_isActiveSession(sessionId)) return;

      final merged = _videosRepository.deduplicateVideosPreservingOrder([
        ...currentVideos,
        ...result.videos,
      ]);
      final newOffset = apiOffset + _pageSize;

      emit(
        state.copyWith(
          videos: merged,
          resultCount: merged.length,
          apiOffset: newOffset,
          totalApiCount: result.totalCount,
          hasMore: result.hasMore,
          isLoadingMore: false,
        ),
      );
    } on Exception catch (e, stackTrace) {
      if (!_isActiveSession(sessionId)) return;
      // Matrix-NO: searchVideosViaApi surfaces API / network failures
      // (Network/IO category).
      addError(e, stackTrace);
      emit(state.copyWith(isLoadingMore: false));
    }
  }

  void _onCleared(VideoSearchCleared event, Emitter<VideoSearchState> emit) {
    _invalidateSearchSession();
    emit(const VideoSearchState());
  }

  int _beginSearchSession() => ++_searchSessionId;

  void _invalidateSearchSession() {
    _searchSessionId++;
  }

  bool _isActiveSession(int sessionId) => sessionId == _searchSessionId;
}
