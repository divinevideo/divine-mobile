import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/services/build_configuration.dart';
import 'package:openvine/features/feature_flags/services/feature_flag_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Consent release gate', () {
    test(
      'a saved preference and explicit toggle cannot bypass delivery gate',
      () async {
        SharedPreferences.setMockInitialValues({
          'ff_minorConsentInAppRecording': true,
        });
        final preferences = await SharedPreferences.getInstance();
        final service = FeatureFlagService(
          preferences,
          const BuildConfiguration(),
        );
        addTearDown(service.dispose);
        await service.initialize();
        await service.setFlag(FeatureFlag.minorConsentInAppRecording, true);
        expect(
          service.isEnabled(FeatureFlag.minorConsentInAppRecording),
          isFalse,
        );
        expect(
          service.currentState.isEnabled(
            FeatureFlag.minorConsentInAppRecording,
          ),
          isFalse,
        );
      },
    );

    test('verified-deployment builds allow explicit opt-in', () async {
      SharedPreferences.setMockInitialValues({});
      final service = FeatureFlagService(
        await SharedPreferences.getInstance(),
        const BuildConfiguration(consentDeliveryVerified: true),
      );
      addTearDown(service.dispose);
      await service.initialize();
      await service.setFlag(FeatureFlag.minorConsentInAppRecording, true);
      expect(service.isEnabled(FeatureFlag.minorConsentInAppRecording), isTrue);
    });
  });
}
