// ABOUTME: Per-feature Reportable `context:` constants for InfoStickerCubit.
// ABOUTME: See .claude/rules/error_handling.md - once a feature accumulates 2+
// ABOUTME: Reportable-wrapped call sites, the identifiers lift here.

/// Stable `context:` identifiers for `Reportable(...)` wraps inside
/// [InfoStickerCubit].
abstract class InfoStickerReportableSites {
  /// Unexpected failure while reading when the clip was recorded.
  static const String loadRecordingTime = 'loadRecordingTime';

  /// Unexpected failure while reading the battery level.
  static const String loadBatteryLevel = 'loadBatteryLevel';
}
