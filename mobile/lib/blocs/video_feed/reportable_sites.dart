// ABOUTME: Per-feature Reportable `context:` constants for VideoFeedBloc.
// ABOUTME: See .claude/rules/error_handling.md — once a feature accumulates 2+
// ABOUTME: Reportable-wrapped call sites, the identifiers lift here.

/// Stable `context:` identifiers for `Reportable(...)` wraps inside
/// [VideoFeedBloc].
abstract class VideoFeedBlocReportableSites {
  static const String scheduleNostrEnrichment = '_scheduleNostrEnrichment';
  static const String readFollowedPeopleLists = '_readFollowedPeopleLists';
}
