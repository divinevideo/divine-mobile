// ABOUTME: NavigatorObserver that tracks page load performance via ScreenAnalyticsService
// ABOUTME: Records screen load start on push, content visible after frame render, and cleanup on pop

import 'package:analytics/src/analytics_surface.dart';
import 'package:analytics/src/screen_analytics_service.dart';
import 'package:flutter/widgets.dart';
import 'package:unified_logger/unified_logger.dart';

class PageLoadObserver extends NavigatorObserver {
  /// Construct the observer over the app's shared [ScreenAnalyticsService].
  ///
  /// [analytics] is required because the sessions this observer starts are
  /// completed by screens reading the same instance — a private default would
  /// silently strand every `markDataLoaded` call on a different service.
  PageLoadObserver({required ScreenAnalyticsService analytics})
    : _analytics = analytics;

  final ScreenAnalyticsService _analytics;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);

    if (route is PopupRoute) {
      return;
    }

    final routeName = _routeName(route);
    final screenName = AnalyticsSurface.routeSurfaceName(route.settings.name);
    _analytics.startScreenLoad(screenName);
    _analytics.trackScreenView(
      screenName,
      params: {
        AnalyticsParam.routeName: routeName,
        AnalyticsParam.entryPoint: 'navigation',
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _analytics.markContentVisible(screenName);
    });

    Log.debug(
      'Page push tracked: $screenName',
      name: 'PageLoadObserver',
      category: LogCategory.ui,
    );
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);

    if (route is PopupRoute) {
      return;
    }

    final screenName = AnalyticsSurface.routeSurfaceName(route.settings.name);
    _analytics.endScreen(screenName);

    Log.debug(
      'Page pop tracked: $screenName',
      name: 'PageLoadObserver',
      category: LogCategory.ui,
    );
  }

  String _routeName(Route<dynamic> route) {
    final routeName = route.settings.name;
    if (routeName == null || routeName.isEmpty) {
      return AnalyticsSurface.unknownRoute;
    }
    if (routeName.trim() == '/') {
      return 'root';
    }
    return AnalyticsSurface.sanitizeName(routeName);
  }
}
