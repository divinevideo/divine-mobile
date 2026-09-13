// ABOUTME: Tests for featured-tab surface analytics attribution.
// ABOUTME: The real adapter must preserve the opaque config id through the tracker.

import 'package:analytics/analytics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/featured_tabs/featured_tab_surface_telemetry.dart';

class _RecordingAnalyticsEventSink implements AnalyticsEventSink {
  final events = <({String name, Map<String, Object> parameters})>[];

  @override
  Future<void> setUserId(String? userId) async {}

  @override
  Future<void> logEvent({
    required String name,
    required Map<String, Object> parameters,
  }) async {
    events.add((name: name, parameters: parameters));
  }

  @override
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
    Map<String, Object>? parameters,
  }) async {}
}

void main() {
  group(FeaturedTabSurfaceTelemetry, () {
    late _RecordingAnalyticsEventSink sink;
    late FeaturedTabSurfaceTelemetry telemetry;

    setUp(() {
      sink = _RecordingAnalyticsEventSink();
      telemetry = FeaturedTabSurfaceTelemetry(
        configId: 'ft_a1b2c3d4',
        tracker: SurfacePerformanceTracker(
          history: PageLoadHistory(),
          sink: sink,
          now: () => DateTime(2026, 6, 12, 12),
        ),
      );
    });

    test('includes config id on loaded surface events', () async {
      telemetry.start();

      await telemetry.completeLoaded(itemCount: 2, hasMore: true);

      expect(sink.events, hasLength(1));
      expect(sink.events.single.name, 'surface_load');
      expect(
        sink.events.single.parameters,
        containsPair('config_id', 'ft_a1b2c3d4'),
      );
      expect(
        sink.events.single.parameters,
        containsPair(AnalyticsParam.surfaceName, AnalyticsSurface.featuredTab),
      );
      expect(
        sink.events.single.parameters,
        containsPair(AnalyticsParam.entryPoint, 'explore_tab'),
      );
      expect(
        sink.events.single.parameters,
        containsPair(AnalyticsParam.itemCount, 2),
      );
      expect(
        sink.events.single.parameters,
        containsPair(AnalyticsParam.hasMore, 1),
      );
    });

    test('includes config id on failed surface events', () async {
      telemetry.start();

      await telemetry.completeFailure();

      expect(
        sink.events.single.parameters,
        containsPair('config_id', 'ft_a1b2c3d4'),
      );
      expect(
        sink.events.single.parameters,
        containsPair(AnalyticsParam.result, SurfaceLoadResult.failure),
      );
    });
  });
}
