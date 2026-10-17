part of 'nostr_id_search_cubit.dart';

/// The search query [NostrIdSearchCubit] last saw, and what it names.
class NostrIdSearchState extends Equatable {
  const NostrIdSearchState({this.query = '', this.action});

  /// The trimmed search text.
  final String query;

  /// What to open for [query]: null while its lookup runs, or when it names
  /// nothing to open.
  final NostrIdOpenAction? action;

  @override
  List<Object?> get props => [query, action];
}
