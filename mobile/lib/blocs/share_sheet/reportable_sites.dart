// ABOUTME: Per-feature Reportable `context:` constants for ShareSheetBloc.
// ABOUTME: See .claude/rules/error_handling.md — once a feature accumulates 2+
// ABOUTME: Reportable-wrapped call sites, the identifiers lift here.

/// Stable `context:` identifiers for `Reportable(...)` wraps inside
/// [ShareSheetBloc].
abstract class ShareSheetBlocReportableSites {
  static const String onContactsLoadRequested = '_onContactsLoadRequested';
  static const String onSendRequested = '_onSendRequested';
  static const String onCopyLinkRequested = '_onCopyLinkRequested';
  static const String onShareViaRequested = '_onShareViaRequested';
}
