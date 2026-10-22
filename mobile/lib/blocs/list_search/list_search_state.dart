// ABOUTME: State class for the ListSearchBloc.
// ABOUTME: Holds status, query, curated video list results, and people list results.

part of 'list_search_bloc.dart';

/// Status of the list search.
enum ListSearchStatus {
  /// Initial state, no search performed yet.
  initial,

  /// Currently searching for lists.
  loading,

  /// Search completed successfully.
  success,

  /// An error occurred while searching.
  failure,
}

/// Outcome of one list-search source.
enum ListSearchSourceStatus { initial, loading, success, failure }

/// State class for the ListSearchBloc.
final class ListSearchState extends Equatable {
  const ListSearchState({
    this.status = ListSearchStatus.initial,
    this.query = '',
    this.requestedQuery,
    this.videoResults = const [],
    this.peopleResults = const [],
    this.videoStatus = ListSearchSourceStatus.initial,
    this.peopleStatus = ListSearchSourceStatus.initial,
  });

  /// The current status of the search.
  final ListSearchStatus status;

  /// The current search query.
  final String query;

  /// Latest requested query, including one still waiting for its debounce.
  final String? requestedQuery;

  /// Curated video lists (kind 30005) matching the search.
  final List<CuratedList> videoResults;

  /// People lists (kind 30000) matching the search, each preserving the
  /// owner pubkey alongside the decoded [UserList].
  final List<PeopleListSearchResult> peopleResults;

  /// Independent outcomes keep failed reads distinct from empty matches.
  final ListSearchSourceStatus videoStatus;
  final ListSearchSourceStatus peopleStatus;

  bool get hasSourceFailure =>
      videoStatus == ListSearchSourceStatus.failure ||
      peopleStatus == ListSearchSourceStatus.failure;

  ListSearchStatus get combinedStatus {
    if (videoResults.isNotEmpty || peopleResults.isNotEmpty) {
      return ListSearchStatus.success;
    }
    if (hasSourceFailure) return ListSearchStatus.failure;
    if (videoStatus == ListSearchSourceStatus.loading ||
        peopleStatus == ListSearchSourceStatus.loading) {
      return ListSearchStatus.loading;
    }
    return ListSearchStatus.success;
  }

  /// Create a copy with updated values.
  ListSearchState copyWith({
    ListSearchStatus? status,
    String? query,
    String? requestedQuery,
    List<CuratedList>? videoResults,
    List<PeopleListSearchResult>? peopleResults,
    ListSearchSourceStatus? videoStatus,
    ListSearchSourceStatus? peopleStatus,
  }) {
    return ListSearchState(
      status: status ?? this.status,
      query: query ?? this.query,
      requestedQuery: requestedQuery ?? this.requestedQuery,
      videoResults: videoResults ?? this.videoResults,
      peopleResults: peopleResults ?? this.peopleResults,
      videoStatus: videoStatus ?? this.videoStatus,
      peopleStatus: peopleStatus ?? this.peopleStatus,
    );
  }

  @override
  List<Object?> get props => [
    status,
    query,
    requestedQuery,
    videoResults,
    peopleResults,
    videoStatus,
    peopleStatus,
  ];
}
