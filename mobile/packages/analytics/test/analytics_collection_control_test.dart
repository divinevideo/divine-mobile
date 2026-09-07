import 'package:analytics/analytics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(NoOpAnalyticsCollectionControl, () {
    test('accepts consent changes when no backend is configured', () async {
      // Builds without a gateable analytics backend still run the consent
      // path on every launch, so it has to resolve rather than hang.
      const control = NoOpAnalyticsCollectionControl();

      await expectLater(
        control.setCollectionEnabled(enabled: false),
        completes,
      );
      await expectLater(control.setCollectionEnabled(enabled: true), completes);
      await expectLater(control.resetAnalyticsData(), completes);
    });
  });
}
