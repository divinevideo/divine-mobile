/// Stable `site:` values for `PostLiveActivityErrorReporter` calls.
///
/// The app prefixes each with `PostLiveActivityRepository.` in its crash
/// report reason, so the dashboard groups by site.
abstract final class PostLiveActivityReportableSites {
  /// A registration the push service rejected, or a registrar that threw.
  static const register = 'register';
}
