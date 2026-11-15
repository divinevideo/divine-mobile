// ABOUTME: Per-feature Reportable `context:` constants for RemixSettingsCubit.
// ABOUTME: See .claude/rules/error_handling.md - once a feature accumulates 2+
// ABOUTME: Reportable-wrapped call sites, the identifiers lift here.

/// Stable `context:` identifiers for `Reportable(...)` wraps inside
/// [RemixSettingsCubit].
abstract class RemixSettingsReportableSites {
  /// Unexpected failure while reading the account's kind 0.
  static const String load = 'load';

  /// Unexpected failure while publishing the account remix setting.
  static const String setAllowVideoReuse = 'setAllowVideoReuse';
}
