// ABOUTME: State class for the UserSearchBloc
// ABOUTME: Represents all possible states of user search results

part of 'user_search_bloc.dart';

/// Enum representing the status of the user search
enum UserSearchStatus {
  /// Initial state, no search performed yet
  initial,

  /// Currently searching for users (progressive results may be arriving)
  loading,

  /// Search completed successfully
  success,

  /// An error occurred while searching
  failure,
}

/// State class for the UserSearchBloc
final class UserSearchState extends Equatable {
  const UserSearchState({
    this.status = UserSearchStatus.initial,
    this.query = '',
    this.results = const [],
    this.resultCount,
    this.offset = 0,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.sourceOutcomes = const {},
    this.rankingSignals = const {},
  });

  /// The current status of the search
  final UserSearchStatus status;

  /// The current search query
  final String query;

  /// The list of user profiles matching the search
  final List<UserProfile> results;

  /// Lightweight count for tab badges when full results were not fetched.
  final int? resultCount;

  /// Current pagination offset
  final int offset;

  /// Whether more results are available
  final bool hasMore;

  /// Whether a "load more" request is in progress
  final bool isLoadingMore;

  /// Per-source outcome map for the current query. Populated as each
  /// phase of `searchUsersProgressive` reports its terminal status.
  /// Empty for [UserSearchStatus.initial].
  final Map<SearchSource, SearchSourceStatus> sourceOutcomes;

  /// Local signal snapshot for visible rows, retained across pagination.
  final Map<String, UserRankingSignals> rankingSignals;

  /// `true` when no results are available AND at least one source
  /// failed. UI surfaces a retry affordance in this state rather than
  /// the standard "No results found" empty state — distinguishing a
  /// true miss from a degraded search.
  bool get isDegradedEmpty =>
      results.isEmpty &&
      sourceOutcomes.values.any((s) => s is SearchSourceFailed);

  /// Create a copy with updated values
  UserSearchState copyWith({
    UserSearchStatus? status,
    String? query,
    List<UserProfile>? results,
    Object? resultCount = _unset,
    int? offset,
    bool? hasMore,
    bool? isLoadingMore,
    Map<SearchSource, SearchSourceStatus>? sourceOutcomes,
    Map<String, UserRankingSignals>? rankingSignals,
  }) {
    return UserSearchState(
      status: status ?? this.status,
      query: query ?? this.query,
      results: results ?? this.results,
      resultCount: identical(resultCount, _unset)
          ? this.resultCount
          : resultCount as int?,
      offset: offset ?? this.offset,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      sourceOutcomes: sourceOutcomes ?? this.sourceOutcomes,
      rankingSignals: rankingSignals ?? this.rankingSignals,
    );
  }

  @override
  List<Object> get props => [
    status,
    query,
    results,
    resultCount ?? -1,
    offset,
    hasMore,
    isLoadingMore,
    sourceOutcomes,
    rankingSignals,
  ];

  static const Object _unset = Object();
}
