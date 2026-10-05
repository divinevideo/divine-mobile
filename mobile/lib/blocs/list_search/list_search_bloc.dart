// ABOUTME: Searches video and people lists with independent source outcomes.
// ABOUTME: Cancels both sources when the query, blocklist or active view changes.

import 'dart:async';

import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart';
import 'package:openvine/constants/search_constants.dart';
import 'package:people_lists_repository/people_lists_repository.dart';
import 'package:rxdart/rxdart.dart';

part 'list_search_event.dart';
part 'list_search_state.dart';

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

final class _SourceFailed extends _SearchResult {
  const _SourceFailed({required this.people});
  final bool people;
}

/// Searches public lists without losing one source when the other fails.
///
/// All events share one cancellation boundary, including clear and blocklist
/// changes. A new event cancels both subscriptions before its debounce starts.
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
    on<ListSearchEvent>(
      _onEvent,
      transformer: (events, mapper) =>
          events.where(_shouldHandle).switchMap((event) {
            if (event is ListSearchQueryChanged) {
              _requestedQuery = event.query.trim();
            } else if (event is ListSearchCleared) {
              _requestedQuery = '';
            }
            return (event is ListSearchQueryChanged
                    ? Stream.value(event).delay(searchDebounceDuration)
                    : Stream.value(event))
                .asyncExpand(mapper);
          }),
    );
  }

  final CuratedListRepository _curatedListRepository;
  final PeopleListsRepository _peopleListsRepository;
  final bool _peopleListSearchEnabled;
  final String? _viewerPubkey;
  String? _requestedQuery;

  bool _shouldHandle(ListSearchEvent event) =>
      event is! ListSearchQueryChanged ||
      event.query.trim() != state.query ||
      _requestedQuery != state.query ||
      state.status == ListSearchStatus.initial ||
      state.status == ListSearchStatus.failure ||
      state.hasSourceFailure;

  Future<void> _onEvent(
    ListSearchEvent event,
    Emitter<ListSearchState> emit,
  ) async {
    if (event is ListSearchCleared) {
      emit(const ListSearchState());
      return;
    }
    final query = event is ListSearchQueryChanged
        ? event.query.trim()
        : _requestedQuery ?? state.query;
    if (query.length < minSearchQueryLength) {
      if (event is ListSearchBlocklistChanged && state.query.isEmpty) return;
      emit(const ListSearchState());
      return;
    }
    final retry =
        event is ListSearchRetried ||
        (event is ListSearchQueryChanged &&
            query == state.query &&
            (state.hasSourceFailure ||
                state.status == ListSearchStatus.failure));
    await _runSearch(query, emit, retainResults: retry && query == state.query);
  }

  Stream<_SearchResult> _source<T>(
    Stream<List<T>> Function() create,
    _SearchResult Function(List<T>) wrap, {
    required bool people,
  }) {
    var latest = <T>[];
    var failed = false;
    try {
      return create().transform(
        StreamTransformer<List<T>, _SearchResult>.fromHandlers(
          handleData: (lists, sink) {
            latest = List.unmodifiable(lists);
            sink.add(wrap(latest));
          },
          handleError: (Object error, StackTrace stackTrace, sink) {
            failed = true;
            addError(error, stackTrace);
            sink.add(_SourceFailed(people: people));
          },
          handleDone: (sink) {
            if (!failed) sink.add(wrap(latest));
            sink.close();
          },
        ),
      );
    } on Object catch (error, stackTrace) {
      addError(error, stackTrace);
      return Stream.value(_SourceFailed(people: people));
    }
  }

  Future<void> _runSearch(
    String query,
    Emitter<ListSearchState> emit, {
    required bool retainResults,
  }) async {
    emit(
      ListSearchState(
        status: ListSearchStatus.loading,
        query: query,
        videoResults: retainResults ? state.videoResults : const [],
        peopleResults: retainResults ? state.peopleResults : const [],
        videoStatus: ListSearchSourceStatus.loading,
        peopleStatus: _peopleListSearchEnabled
            ? ListSearchSourceStatus.loading
            : ListSearchSourceStatus.initial,
      ),
    );
    await emit.forEach<_SearchResult>(
      Rx.merge([
        _source(
          () => _curatedListRepository.searchAllLists(query),
          _VideoSearchResult.new,
          people: false,
        ),
        if (_peopleListSearchEnabled)
          _source(
            () => _peopleListsRepository.searchPublicLists(
              query,
              viewerPubkey: _viewerPubkey,
            ),
            _PeopleSearchResult.new,
            people: true,
          ),
      ]),
      onData: (result) {
        final next = switch (result) {
          _VideoSearchResult(:final lists) => state.copyWith(
            videoStatus: ListSearchSourceStatus.success,
            videoResults: lists,
          ),
          _PeopleSearchResult(:final results) => state.copyWith(
            peopleStatus: ListSearchSourceStatus.success,
            peopleResults: results,
          ),
          _SourceFailed(:final people) =>
            people
                ? state.copyWith(peopleStatus: ListSearchSourceStatus.failure)
                : state.copyWith(videoStatus: ListSearchSourceStatus.failure),
        };
        return next.copyWith(status: next.combinedStatus);
      },
    );
  }
}
