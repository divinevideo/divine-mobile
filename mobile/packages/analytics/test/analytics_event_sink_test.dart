import 'package:analytics/analytics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(NoOpAnalyticsEventSink, () {
    test('accepts event and screen view calls without side effects', () async {
      const sink = NoOpAnalyticsEventSink();

      await sink.setUserId(
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
      );
      await sink.setUserId(null);
      await sink.setUserProperty(
        name: 'experiment_variant',
        value: 'variant-a',
      );
      await sink.setUserProperty(name: 'experiment_variant', value: null);
      await sink.logEvent(
        name: 'surface_load',
        parameters: const {'surface_name': 'comments_sheet'},
      );
      await sink.logScreenView(
        screenName: 'video_detail',
        screenClass: 'Route',
        parameters: const {'route_name': 'video'},
      );
    });
  });
}
