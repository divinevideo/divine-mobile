// ABOUTME: Events for the ListSearchBloc.
// ABOUTME: Defines actions for searching lists and clearing results.

part of 'list_search_bloc.dart';

/// Base class for all list search events.
sealed class ListSearchEvent extends Equatable {
  const ListSearchEvent();

  @override
  List<Object?> get props => [];
}

/// Request to search for lists with a query.
final class ListSearchQueryChanged extends ListSearchEvent {
  const ListSearchQueryChanged(this.query);

  /// The search query string.
  final String query;

  @override
  List<Object?> get props => [query];
}

/// The blocklist changed — re-run the current search so blocked authors
/// disappear from (or reappear in) still-open results.
final class ListSearchBlocklistChanged extends ListSearchEvent {
  const ListSearchBlocklistChanged();
}

/// Request to clear search results and reset to initial state.
final class ListSearchCleared extends ListSearchEvent {
  const ListSearchCleared();
}

/// Retry list search while keeping useful results on screen.
final class ListSearchRetried extends ListSearchEvent {
  const ListSearchRetried();
}
