// ABOUTME: Tests bounded route-to-surface product analytics navigation.
// ABOUTME: Guards against sending raw route names or parameters.

import 'package:flutter/scheduler.dart';
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
  final occurredAts = <DateTime?>[];

  @override
  Future<String?> recordNavigationContext({
    required ProductAnalyticsV2Surface fromSurface,
    required ProductAnalyticsV2Surface toSurface,
    required ProductAnalyticsV2NavigationAction action,
    String? contentId,
    String? recommendationId,
    DateTime? occurredAt,
  }) async {
    records.add((from: fromSurface, to: toSurface, action: action));
    occurredAts.add(occurredAt);
    return 'navigation-id';
  }
}

/// A pages-API [Navigator], which notifies its observers while the widget
/// tree is building, the way GoRouter's does.
class _DeclarativeNavigator extends StatelessWidget {
  const _DeclarativeNavigator({required this.pages, required this.observer});

  final List<Page<void>> pages;
  final NavigatorObserver observer;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Navigator(
        pages: pages,
        observers: [observer],
        onDidRemovePage: (_) {},
      ),
    );
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
      await pumpEventQueue();

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

    test(
      'stamps a navigation with the time it happened, not when analytics '
      'is read',
      () async {
        final analytics = _RecordingAnalyticsService();
        final navigatedAt = DateTime.utc(2026, 9, 29, 12);
        var now = navigatedAt;
        final observer = ProductAnalyticsNavigationObserver(
          analytics: () {
            now = now.add(const Duration(milliseconds: 16));
            return analytics;
          },
          now: () => now,
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
        await pumpEventQueue();

        expect(analytics.occurredAts, equals([navigatedAt]));
      },
    );

    testWidgets(
      'reads analytics outside the build phase when a declarative '
      'navigator pushes',
      (tester) async {
        final analytics = _RecordingAnalyticsService();
        final readPhases = <SchedulerPhase>[];
        final observer = ProductAnalyticsNavigationObserver(
          analytics: () {
            readPhases.add(SchedulerBinding.instance.schedulerPhase);
            return analytics;
          },
        );
        const feed = MaterialPage<void>(
          name: 'home-feed',
          child: SizedBox.shrink(),
        );
        const profile = MaterialPage<void>(
          name: 'user-profile/secret-value',
          child: SizedBox.shrink(),
        );

        await tester.pumpWidget(
          _DeclarativeNavigator(pages: const [feed], observer: observer),
        );
        await tester.pumpWidget(
          _DeclarativeNavigator(
            pages: const [feed, profile],
            observer: observer,
          ),
        );
        await tester.pumpAndSettle();

        expect(readPhases, hasLength(2));
        expect(
          readPhases,
          everyElement(isNot(SchedulerPhase.persistentCallbacks)),
        );
        expect(
          analytics.records,
          equals([
            (
              from: ProductAnalyticsV2Surface.unknown,
              to: ProductAnalyticsV2Surface.feed,
              action: ProductAnalyticsV2NavigationAction.open,
            ),
            (
              from: ProductAnalyticsV2Surface.feed,
              to: ProductAnalyticsV2Surface.profile,
              action: ProductAnalyticsV2NavigationAction.open,
            ),
          ]),
        );
      },
    );
  });
}
