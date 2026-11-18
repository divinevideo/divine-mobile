// ABOUTME: Stable semantic names and safe parameter helpers for analytics.

abstract final class AnalyticsSurface {
  static const homeFeed = 'home_feed';
  static const explore = 'explore';
  static const notifications = 'notifications';
  static const inbox = 'inbox';
  static const profile = 'profile';
  static const videoDetail = 'video_detail';
  static const commentsSheet = 'comments_sheet';

  /// A server-configured featured collection tab.
  ///
  /// Deliberately generic and shared by every such tab: the editorial theme
  /// travels as [AnalyticsParam.configId], so dashboards and exports never
  /// inherit a schema per campaign.
  static const featuredTab = 'featured_tab';

  /// The video editor's sound picker sheet.
  ///
  /// One surface for all of its list tabs; which tab loaded travels as
  /// [AnalyticsParam.tab].
  static const soundPicker = 'sound_picker';
  static const settings = 'settings';
  static const searchResults = 'search_results';
  static const videoRecorder = 'video_recorder';
  static const videoEditor = 'video_editor';
  static const unknownRoute = 'unknown_route';

  static String slowBucket(int totalMs) {
    if (totalMs < 1000) return 'under_1s';
    if (totalMs < 3000) return '1_3s';
    if (totalMs < 5000) return '3_5s';
    if (totalMs < 10000) return '5_10s';
    return 'over_10s';
  }

  static String sanitizeName(String value) {
    final camelSeparated = value.trim().replaceAllMapped(
      RegExp('([a-z0-9])([A-Z])'),
      (match) => '${match.group(1)}_${match.group(2)}',
    );
    final normalized = camelSeparated
        .trim()
        .replaceAll(RegExp('[^A-Za-z0-9_]+'), '_')
        .replaceAll(RegExp('_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '')
        .toLowerCase();
    return normalized.isEmpty ? unknownRoute : normalized;
  }

  static String routeSurfaceName(String? routeName) {
    if (routeName == null || routeName.trim().isEmpty) {
      return unknownRoute;
    }
    if (routeName.trim() == '/') {
      return homeFeed;
    }

    final sanitized = sanitizeName(routeName);
    return switch (sanitized) {
      'home' => homeFeed,
      'video' => videoDetail,
      'video_recorder' => videoRecorder,
      'video_editor' => videoEditor,
      _ => sanitized,
    };
  }
}

abstract final class AnalyticsParam {
  static const screenName = 'screen_name';
  static const surfaceName = 'surface_name';
  static const routeName = 'route_name';
  static const entryPoint = 'entry_point';
  static const result = 'result';
  static const visibleMs = 'visible_ms';
  static const dataMs = 'data_ms';
  static const totalMs = 'total_ms';
  static const slowBucket = 'slow_bucket';
  static const itemCount = 'item_count';
  static const initialCount = 'initial_count';
  static const hasMore = 'has_more';
  static const featureFlag = 'feature_flag';
  static const sortMode = 'sort_mode';

  /// Opaque server configuration id (e.g. a featured tab's `ft_…`).
  ///
  /// Safe to export: it identifies a configuration, not a person, and carries
  /// no editorial name.
  static const configId = 'config_id';

  /// Which tab of a tabbed surface loaded, from that surface's own fixed
  /// vocabulary (e.g. the sound picker's `for_you` or `newest`).
  static const tab = 'tab';
}

abstract final class SurfaceLoadResult {
  static const success = 'success';
  static const empty = 'empty';
  static const failure = 'failure';
  static const dismissed = 'dismissed';
}
