/// Stable `context:` identifiers for `Reportable(...)` wraps inside
/// [CommentsListBloc].
abstract class CommentsListBlocReportableSites {
  static const String onLoadRequested = '_onLoadRequested';
  static const String onLoadMoreRequested = '_onLoadMoreRequested';
  static const String startWatchingComments = '_startWatchingComments';
  static const String removeAuthorDeletedComments =
      '_removeAuthorDeletedComments';
}
