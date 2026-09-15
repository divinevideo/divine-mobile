// ABOUTME: Converts app route changes into bounded product analytics context.
// ABOUTME: Never sends raw route names, query values, or navigation arguments.

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:openvine/generated/product_analytics.dart';
import 'package:openvine/services/analytics_service.dart';

class ProductAnalyticsNavigationObserver extends NavigatorObserver {
  ProductAnalyticsNavigationObserver({
    required AnalyticsService Function() analytics,
  }) : _analytics = analytics;

  final AnalyticsService Function() _analytics;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (route is PopupRoute) return;
    _record(
      from: productAnalyticsSurfaceForRoute(previousRoute?.settings.name),
      to: productAnalyticsSurfaceForRoute(route.settings.name),
      action: ProductAnalyticsV2NavigationAction.open,
    );
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (route is PopupRoute) return;
    _record(
      from: productAnalyticsSurfaceForRoute(route.settings.name),
      to: productAnalyticsSurfaceForRoute(previousRoute?.settings.name),
      action: ProductAnalyticsV2NavigationAction.back,
    );
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute == null || newRoute is PopupRoute) return;
    _record(
      from: productAnalyticsSurfaceForRoute(oldRoute?.settings.name),
      to: productAnalyticsSurfaceForRoute(newRoute.settings.name),
      action: ProductAnalyticsV2NavigationAction.open,
    );
  }

  void _record({
    required ProductAnalyticsV2Surface from,
    required ProductAnalyticsV2Surface to,
    required ProductAnalyticsV2NavigationAction action,
  }) {
    if (from == to) return;
    try {
      unawaited(
        _analytics()
            .recordNavigationContext(
              fromSurface: from,
              toSurface: to,
              action: action,
            )
            .catchError((Object _) => null),
      );
    } catch (_) {
      // Navigation must keep working if analytics has not started yet.
    }
  }
}

@visibleForTesting
ProductAnalyticsV2Surface productAnalyticsSurfaceForRoute(String? routeName) {
  final name = routeName?.toLowerCase() ?? '';
  if (name.contains('search')) return ProductAnalyticsV2Surface.searchResults;
  if (name.contains('profile') || name.contains('user')) {
    return ProductAnalyticsV2Surface.profile;
  }
  if (name.contains('explore') ||
      name.contains('discover') ||
      name.contains('popular') ||
      name.contains('hashtag')) {
    return ProductAnalyticsV2Surface.discovery;
  }
  if (name.contains('following')) return ProductAnalyticsV2Surface.following;
  if (name.contains('home') ||
      name.contains('feed') ||
      name.contains('video')) {
    return ProductAnalyticsV2Surface.feed;
  }
  if (name.contains('create-account') || name.contains('registration')) {
    return ProductAnalyticsV2Surface.registration;
  }
  if (name.contains('welcome') || name.contains('landing')) {
    return ProductAnalyticsV2Surface.landing;
  }
  if (name.contains('onboarding')) return ProductAnalyticsV2Surface.onboarding;
  if (name.contains('notification')) {
    return ProductAnalyticsV2Surface.notifications;
  }
  if (name.contains('setting')) return ProductAnalyticsV2Surface.settings;
  return ProductAnalyticsV2Surface.unknown;
}
