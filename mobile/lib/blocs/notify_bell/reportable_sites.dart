// ABOUTME: Per-feature Reportable `context:` constants for NotifyBellCubit.
// ABOUTME: See .claude/rules/error_handling.md — 2+ wrapped sites lift here.

/// Stable `context:` identifiers for `Reportable(...)` wraps inside
/// `NotifyBellCubit`.
abstract class NotifyBellReportableSites {
  /// `toggle` generic-catch arm. `NotifySubscriptionsRepository` reports
  /// publish failures as a `failed` status rather than throwing, so anything
  /// reaching this arm is an invariant violation — realistically a `TypeError`
  /// from a malformed relay event, not a network fault.
  static const String toggle = 'toggle';

  /// `load` generic-catch arm around the outstanding-teardown retry. Same
  /// coverage as [toggle]; a publish failure here is reported as a `failed`
  /// status, not a throw.
  static const String reconcile = 'reconcile';
}
