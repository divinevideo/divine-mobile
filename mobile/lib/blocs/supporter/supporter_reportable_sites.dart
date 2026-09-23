// ABOUTME: Per-feature Reportable `context:` constants for SupporterCubit.
// ABOUTME: See .claude/rules/error_handling.md - once a feature accumulates 2+
// ABOUTME: Reportable-wrapped call sites, the identifiers lift here.

/// Stable `context:` identifiers for `Reportable(...)` wraps inside
/// [SupporterCubit].
abstract class SupporterReportableSites {
  /// Unexpected failure while loading the store's supporter plans.
  static const String loadTiers = 'loadTiers';

  /// Unexpected failure while starting a supporter purchase.
  static const String subscribe = 'subscribe';

  /// Unexpected failure while restoring supporter purchases.
  static const String restore = 'restore';

  /// Unexpected failure delivered with a store or verification update.
  static const String purchaseUpdate = 'purchaseUpdate';
}
