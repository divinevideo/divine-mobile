/// Stable `context:` identifiers for `Reportable(...)` wraps inside
/// [CommentReactionsBloc].
abstract class CommentReactionsBlocReportableSites {
  static const String onVoteToggled = '_onVoteToggled';
  static const String onVoteCountsFetchRequested =
      '_onVoteCountsFetchRequested';
  static const String onBlockUserRequested = '_onBlockUserRequested';
  static const String onDeleteRequested = '_onDeleteRequested';
}
