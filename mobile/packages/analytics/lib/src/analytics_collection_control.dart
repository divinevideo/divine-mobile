// ABOUTME: SDK-level consent control for an analytics backend.
// ABOUTME: Kept separate from AnalyticsEventSink so trackers cannot bypass it.

/// Turns an analytics backend's collection on or off, and clears the identity
/// it has accumulated.
///
/// Deliberately **not** part of `AnalyticsEventSink`. A tracker holds a sink to
/// log events and knows nothing about consent; the consent decision has a
/// single owner (`AnalyticsService`). Gating at the SDK rather than at each
/// call site is what makes the guarantee hold — while collection is off the
/// backend records and sends nothing, so a tracker that logs anyway, or one
/// added later that never heard of this switch, still cannot leak past it.
abstract interface class AnalyticsCollectionControl {
  /// Enables or disables collection for the whole backend.
  Future<void> setCollectionEnabled({required bool enabled});

  /// Clears the identity and attribution the backend has accumulated.
  ///
  /// Called on withdrawal so the pseudonymous id an opted-out person carries
  /// cannot be joined to their activity after a later opt-in.
  Future<void> resetAnalyticsData();
}

/// Collection control that does nothing, for tests and unconfigured builds.
class NoOpAnalyticsCollectionControl implements AnalyticsCollectionControl {
  const NoOpAnalyticsCollectionControl();

  @override
  Future<void> setCollectionEnabled({required bool enabled}) async {}

  @override
  Future<void> resetAnalyticsData() async {}
}
