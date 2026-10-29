part of 'mention_search_cubit.dart';

/// Suggestions for the mention currently being typed.
class MentionSearchState extends Equatable {
  const MentionSearchState({
    this.query = '',
    this.suggestions = const [],
  });

  /// Text after the `@`, or empty when no mention is being typed.
  final String query;

  /// Accounts offered for the current [query].
  final List<MentionSuggestion> suggestions;

  @override
  List<Object?> get props => [query, suggestions];
}
