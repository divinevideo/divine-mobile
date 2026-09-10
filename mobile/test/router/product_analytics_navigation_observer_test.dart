// ABOUTME: Tests bounded route-to-surface product analytics navigation.
// ABOUTME: Guards against sending raw route names or parameters.

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/generated/product_analytics.dart';
import 'package:openvine/router/product_analytics_navigation_observer.dart';
import 'package:openvine/services/analytics_service.dart';
import 'package:openvine/services/background_activity_manager.dart';

class _RecordingAnalyticsService extends AnalyticsService {
  _RecordingAnalyticsService()
    : super(backgroundActivityManager: BackgroundActivityManager());

  final records =
      <
        ({
          ProductAnalyticsV2Surface from,
          ProductAnalyticsV2Surface to,
          ProductAnalyticsV2NavigationAction action,
        })
      >[];

  @override
  Future<String?> recordNavigationContext({
    required ProductAnalyticsV2Surface fromSurface,
    required ProductAnalyticsV2Surface toSurface,
    required ProductAnalyticsV2NavigationAction action,
    String? contentId,
    String? recommendationId,
  }) async {
    records.add((from: fromSurface, to: toSurface, action: action));
    return 'navigation-id';
  }
}

void main() {
  group('productAnalyticsSurfaceForRoute', () {
    test('maps route names to the fixed contract surfaces', () {
      expect(
        productAnalyticsSurfaceForRoute('search-results-personal-data'),
        ProductAnalyticsV2Surface.searchResults,
      );
      expect(
        productAnalyticsSurfaceForRoute('other-user-profile'),
        ProductAnalyticsV2Surface.profile,
      );
      expect(
        productAnalyticsSurfaceForRoute('anything-private-and-new'),
        ProductAnalyticsV2Surface.unknown,
      );
    });
  });

  group(ProductAnalyticsNavigationObserver, () {
    test('records bounded open and back navigation', () async {
      final analytics = _RecordingAnalyticsService();
      final observer = ProductAnalyticsNavigationObserver(
        analytics: () => analytics,
      );
      final feed = MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'home-feed'),
        builder: (_) => const SizedBox.shrink(),
      );
      final profile = MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'user-profile/secret-value'),
        builder: (_) => const SizedBox.shrink(),
      );

      observer.didPush(profile, feed);
      observer.didPop(profile, feed);
      await Future<void>.delayed(Duration.zero);

      expect(analytics.records, [
        (
          from: ProductAnalyticsV2Surface.feed,
          to: ProductAnalyticsV2Surface.profile,
          action: ProductAnalyticsV2NavigationAction.open,
        ),
        (
          from: ProductAnalyticsV2Surface.profile,
          to: ProductAnalyticsV2Surface.feed,
          action: ProductAnalyticsV2NavigationAction.back,
        ),
      ]);
    });
  });
}
