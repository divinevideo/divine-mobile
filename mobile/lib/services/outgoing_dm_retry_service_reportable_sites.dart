// ABOUTME: Stable site identifiers for swallow points in
// ABOUTME: OutgoingDmRetryService — used as Crashlytics reason suffix.

/// Stable identifiers for swallowed-failure sites inside
/// `OutgoingDmRetryService`. Forwarded as the Crashlytics `reason:`
/// suffix so the dashboard aggregates per site.
abstract class OutgoingDmRetryServiceReportableSites {
  /// Per-row throw in the sweep loop — `recoverSelfWrap` raised an
  /// unexpected exception after `incrementRetry` succeeded.
  static const String perRowUnexpectedThrow =
      'OutgoingDmRetryService.perRowUnexpectedThrow';

  /// Top-level sweep catch — the sweep loop or DAO call raised an
  /// exception before per-row dispatch completed.
  static const String sweepTopLevel = 'OutgoingDmRetryService.sweepTopLevel';

  /// A delete-for-everyone whose retries ran out could not be recorded as
  /// unconfirmed (#10012).
  static const String markMessageDeletionUnconfirmed =
      'OutgoingDmRetryService.markMessageDeletionUnconfirmed';
}
