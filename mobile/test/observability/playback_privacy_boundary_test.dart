import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/analytics_service.dart';
import 'package:openvine/services/background_activity_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'initialized consent and every privacy boundary notify collectors',
    () async {
      SharedPreferences.setMockInitialValues({'analytics_enabled': false});
      final service = AnalyticsService(
        backgroundActivityManager: BackgroundActivityManager(),
        disableNostrPublishing: true,
      );
      addTearDown(service.dispose);
      final decisions = <bool>[];
      final subscription = service.privacyChanges.listen((_) {
        decisions.add(service.initializedAnalyticsConsent);
      });
      addTearDown(subscription.cancel);
      expect(service.initializedAnalyticsConsent, isFalse);
      await service.initialize();
      expect(decisions, [false]);
      await service.setAnalyticsEnabled(true);
      expect(decisions, [false, true]);
      await service.handleIdentityChange();
      expect(decisions, [false, true, true]);
      await service.setAnalyticsEnabled(false);
      expect(decisions.last, isFalse);
    },
  );
}
