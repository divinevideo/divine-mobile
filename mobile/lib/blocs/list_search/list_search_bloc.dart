// ABOUTME: BLoC for searching curated video lists (kind 30005) and people lists (kind 30000).
// ABOUTME: Merges both streams via a tagged union and uses emit.forEach for safe lifecycle.

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart';
import 'package:openvine/constants/search_constants.dart';
import 'package:people_lists_repository/people_lists_repository.dart';
import 'package:rxdart/rxdart.dart';

part 'list_search_event.dart';
part 'list_search_state.dart';

/// Tagged union emitted by the merged search stream.
sealed class _SearchResult {
  const _SearchResult();
}

final class _VideoSearchResult extends _SearchResult {
  const _VideoSearchResult(this.lists);
  final List<CuratedList> lists;
}

final class _PeopleSearchResult extends _SearchResult {
  const _PeopleSearchResult(this.results);
  final List<PeopleListSearchResult> results;
}

/// BLoC for searching curated video lists (kind 30005) and people lists
/// (kind 30000).
///
/// Merges [CuratedListRepository.searchAllLists] and
/// [PeopleListsRepository.searchPublicLists] into a single stream via
/// [Rx.merge] and processes it with [emit.forEach] so that
/// [debounceRestartable] correctly cancels in-flight subscriptions.
///
/// The [peopleListSearchEnabled] flag controls whether the people list stream
/// is included. When `false`, only video lists are searched.
class ListSearchBloc extends Bloc<ListSearchEvent, ListSearchState> {
  ListSearchBloc({
    required CuratedListRepository curatedListRepository,
    required PeopleListsRepository peopleListsRepository,
    bool peopleListSearchEnabled = false,
    String? viewerPubkey,
  }) : _curatedListRepository = curatedListRepository,
       _peopleListsRepository = peopleListsRepository,
       _peopleListSearchEnabled = peopleListSearchEnabled,
       _viewerPubkey = viewerPubkey,
       super(const ListSearchState()) {
    on<ListSearchQueryChanged>(
      _onQueryChanged,
      transformer: debounceRestartable(),
    );
    on<ListSearchCleared>(_onCleared);
    on<ListSearchBlocklistChanged>(
      _onBlocklistChanged,
      transformer: restartable(),
    );
  }

  final CuratedListRepository _curatedListRepository;
  final PeopleListsRepository _peopleListsRepository;
  final bool _peopleListSearchEnabled;

  /// Whose own lists survive the Divine author check in people-list search.
  final String? _viewerPubkey;

  Future<void> _onQueryChanged(
    ListSearchQueryChanged event,
    Emitter<ListSearchState> emit,
  ) async {
    final query = event.query.trim();

    if (query.isEmpty || query.length < minSearchQueryLength) {
      emit(const ListSearchState());
      return;
    }

    if (query == state.query &&
        state.status != ListSearchStatus.initial &&
        state.status != ListSearchStatus.failure) {
      return;
    }

    await _runSearch(query, emit);
  }

  /// Re-runs the current search after a block/unblock so results pass
  /// through the repository's block filter again. Bypasses the same-query
  /// guard in [_onQueryChanged] on purpose — the query is unchanged but
  /// the result set is not.
  Future<void> _onBlocklistChanged(
    ListSearchBlocklistChanged event,
    Emitter<ListSearchState> emit,
  ) async {
    if (state.query.isEmpty) return;
    await _runSearch(state.query, emit);
  }

  Future<void> _runSearch(String query, Emitter<ListSearchState> emit) async {
    emit(
      state.copyWith(
        status: ListSearchStatus.loading,
        query: query,
        videoResults: const [],
        peopleResults: const [],
      ),
    );

    try {
      final videoStream = _curatedListRepository
          .searchAllLists(query)
          .map<_SearchResult>(_VideoSearchResult.new);

      final streams = [
        videoStream,
        if (_peopleListSearchEnabled)
          _peopleListsRepository
              .searchPublicLists(query, viewerPubkey: _viewerPubkey)
              .map<_SearchResult>(_PeopleSearchResult.new),
      ];

      await emit.forEach<_SearchResult>(
        Rx.merge(streams),
        onData: (result) => switch (result) {
          _VideoSearchResult(:final lists) => state.copyWith(
            status: ListSearchStatus.success,
            videoResults: lists,
          ),
          _PeopleSearchResult(:final results) => state.copyWith(
            status: ListSearchStatus.success,
            peopleResults: results,
          ),
        },
      );

      // If stream completes without emitting, still emit success.
      if (state.status == ListSearchStatus.loading) {
        emit(state.copyWith(status: ListSearchStatus.success));
      }
    } on Exception catch (e, stackTrace) {
      addError(e, stackTrace);
      emit(state.copyWith(status: ListSearchStatus.failure));
    }
  }

  void _onCleared(ListSearchCleared event, Emitter<ListSearchState> emit) {
    emit(const ListSearchState());
  }
}
