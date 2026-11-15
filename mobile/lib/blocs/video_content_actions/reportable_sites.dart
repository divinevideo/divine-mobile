// ABOUTME: Per-feature Reportable `context:` constants for
// ABOUTME: VideoContentActionsBloc, per .claude/rules/error_handling.md.

/// Stable `context:` identifiers for `Reportable(...)` wraps inside
/// [VideoContentActionsBloc].
abstract class VideoContentActionsReportableSites {
  static const String onBookmarkStatusRequested = '_onBookmarkStatusRequested';
  static const String onSaveRequested = '_onSaveRequested';
  static const String onAddToClipsRequested = '_onAddToClipsRequested';
  static const String remixConsent = '_remixConsent';
  static const String onCopyEventJsonRequested = '_onCopyEventJsonRequested';
  static const String onCopyEventIdRequested = '_onCopyEventIdRequested';
}
