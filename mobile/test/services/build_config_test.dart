// ABOUTME: Tests for BuildConfiguration service providing compile-time defaults
// ABOUTME: Validates environment variable reading and default flag values

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/services/build_configuration.dart';

void main() {
  group('BuildConfiguration', () {
    test('should read from environment variables', () {
      // This tests compile-time constants
      const config = BuildConfiguration();

      expect(
        config.getDefault(FeatureFlag.debugTools),
        equals(bool.fromEnvironment('FF_DEBUG_TOOLS', defaultValue: true)),
      );
    });

    test('should provide defaults when env vars not set', () {
      const config = BuildConfiguration();

      // When FF_NEW_CAMERA_UI is not set, should default to false
      expect(config.getDefault(FeatureFlag.newCameraUI), isFalse);
      expect(config.getDefault(FeatureFlag.enhancedVideoPlayer), isFalse);
      expect(config.getDefault(FeatureFlag.enhancedAnalytics), isFalse);
      expect(config.getDefault(FeatureFlag.newProfileLayout), isFalse);
      expect(config.getDefault(FeatureFlag.livestreamingBeta), isFalse);
    });

    test('should have debug tools enabled by default in debug builds', () {
      const config = BuildConfiguration();

      // Debug tools should be enabled by default for development
      expect(config.getDefault(FeatureFlag.debugTools), isTrue);
    });

    test('should provide all flags with defaults', () {
      const config = BuildConfiguration();

      // Should have a default for every flag
      for (final flag in FeatureFlag.values) {
        final hasDefault = config.hasDefault(flag);
        expect(
          hasDefault,
          isTrue,
          reason: 'Flag ${flag.name} should have a default value',
        );
      }
    });

    test('should return consistent values', () {
      const config1 = BuildConfiguration();
      const config2 = BuildConfiguration();

      // Same configuration should return same values
      for (final flag in FeatureFlag.values) {
        expect(
          config1.getDefault(flag),
          equals(config2.getDefault(flag)),
          reason: 'Flag ${flag.name} should have consistent default',
        );
      }
    });

    test('should provide environment variable key mapping', () {
      const config = BuildConfiguration();

      expect(
        config.getEnvironmentKey(FeatureFlag.newCameraUI),
        equals('FF_NEW_CAMERA_UI'),
      );
      expect(
        config.getEnvironmentKey(FeatureFlag.debugTools),
        equals('FF_DEBUG_TOOLS'),
      );
      expect(
        config.getEnvironmentKey(FeatureFlag.enhancedVideoPlayer),
        equals('FF_ENHANCED_VIDEO_PLAYER'),
      );
    });
  });
}
