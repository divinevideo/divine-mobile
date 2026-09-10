part of 'caption_mentions_cubit.dart';

/// Suggestions for the mention currently being typed in a caption.
class CaptionMentionsState extends Equatable {
  const CaptionMentionsState({
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
