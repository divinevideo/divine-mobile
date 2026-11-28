// ABOUTME: Times a main screen from its first load until its content, empty
// ABOUTME: state or error shows, as one Analytics `surface_load` event.

import 'dart:async';

import 'package:analytics/analytics.dart';

/// Where a measured screen load started, sent as `entry_point`.
///
/// A fixed vocabulary: dashboards group by it, so a value never carries an
/// id, a name or search text.
abstract final class ScreenLoadEntryPoint {
  /// The signed-in account's own profile, in the profile tab.
  static const ownProfile = 'own_profile';

  /// Another account's profile.
  static const otherProfile = 'other_profile';

  /// The notifications list the inbox tab opens on.
  static const inboxTab = 'inbox_tab';

  /// The standalone notifications route.
  static const notificationsRoute = 'notifications_route';

  /// The inbox's Messages pane, the first time it opens.
  static const messagesTab = 'messages_tab';

  /// A search query, once typing pauses.
  static const query = 'query';

  /// A different sort order for the current search.
  static const sortChange = 'sort_change';

  /// The Explore tab of the bottom navigation.
  static const exploreTab = 'explore_tab';

  /// A link that names a video: a deep link, a share, a notification or a
  /// message.
  static const link = 'link';

  /// The retry a failed load offers.
  static const retry = 'retry';
}

/// Reports `surface_load` for one screen whose content a bloc loads.
///
/// The bloc calls [start] when it begins its first load, then [completeLoaded]
/// or [completeFailure] for the first state the screen renders as content, an
/// empty state or an error. That state is the boundary, not the request
/// returning: a screen that shows cached content first completes on the
/// cache. [dismiss] reports a load the user left before it showed anything;
/// blocs call it from `close`.
///
/// Each [start] reports once. Calls while nothing is timed do nothing, so a
/// bloc may call [completeLoaded] for every state that qualifies.
///
/// [SurfacePerformanceTracker] keeps one session per surface name, so two
/// instances of a screen would otherwise complete each other's session — a
/// profile still loading when the user opens another one. The newest [start]
/// owns the surface. The load it replaces is reported dismissed, because the
/// user moved on before it showed, and that instance's later calls do nothing.
class ScreenLoadTelemetry {
  /// Creates telemetry for one instance of [surface], an [AnalyticsSurface]
  /// name. [entryPoint] is the [ScreenLoadEntryPoint] that [start] reports
  /// unless it is given another.
  ScreenLoadTelemetry({
    required SurfacePerformanceTracker tracker,
    required String surface,
    required String entryPoint,
  }) : _tracker = tracker,
       _surface = surface,
       _entryPoint = entryPoint;

  /// The instance timing each surface, per tracker.
  ///
  /// Attached to the tracker rather than held in a static map, so that tests,
  /// which each build their own tracker, never share an owner.
  static final _owners = Expando<Map<String, ScreenLoadTelemetry>>(
    'ScreenLoadTelemetry owners',
  );

  final SurfacePerformanceTracker _tracker;
  final String _surface;
  final String _entryPoint;
  String? _tab;

  Map<String, ScreenLoadTelemetry> get _ownerBySurface =>
      _owners[_tracker] ??= {};

  /// Whether a load this instance started is still being timed.
  bool get isTiming => identical(_ownerBySurface[_surface], this);

  /// The tab of the load being timed, or null when none is timed or it was
  /// started without one.
  String? get timedTab => isTiming ? _tab : null;

  /// Starts timing a load of the screen, of [tab] when it has tabs.
  ///
  /// A load still being timed for the same surface, by this instance or
  /// another, is reported dismissed first. [params] may carry the other safe
  /// optional `surface_load` parameters, such as [AnalyticsParam.sortMode].
  void start({
    String? entryPoint,
    String? tab,
    Map<String, Object> params = const {},
  }) {
    _ownerBySurface[_surface]?.dismiss();
    _ownerBySurface[_surface] = this;
    _tab = tab;
    _tracker.startSurfaceLoad(
      _surface,
      params: {
        AnalyticsParam.entryPoint: entryPoint ?? _entryPoint,
        AnalyticsParam.tab: ?tab,
        ...params,
      },
    );
  }

  /// Reports that the screen shows [itemCount] items, or its empty state
  /// when [itemCount] is zero.
  void completeLoaded({required int itemCount, bool? hasMore}) {
    _finish(
      itemCount == 0 ? SurfaceLoadResult.empty : SurfaceLoadResult.success,
      metrics: {
        AnalyticsParam.itemCount: itemCount,
        AnalyticsParam.hasMore: ?hasMore,
      },
    );
  }

  /// Reports that the screen shows its load error.
  void completeFailure() => _finish(SurfaceLoadResult.failure);

  /// Reports that the user left the screen before it showed anything.
  void dismiss() => _finish(SurfaceLoadResult.dismissed);

  void _finish(String result, {Map<String, Object>? metrics}) {
    if (!isTiming) return;
    _ownerBySurface.remove(_surface);
    unawaited(
      _tracker.completeSurfaceLoad(_surface, result: result, metrics: metrics),
    );
  }
}
