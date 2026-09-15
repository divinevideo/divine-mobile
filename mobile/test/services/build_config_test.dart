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
        equals(
          const bool.fromEnvironment('FF_DEBUG_TOOLS', defaultValue: true),
        ),
      );
    });

    test('should provide defaults when env vars not set', () {
      const config = BuildConfiguration();

      // When the env vars are not set, these flags default to false
      expect(config.getDefault(FeatureFlag.accountSwitching), isFalse);
      expect(config.getDefault(FeatureFlag.enhancedAnalytics), isFalse);
    });

    test('should have debug tools enabled by default in debug builds', () {
      const config = BuildConfiguration();

      // Debug tools should be enabled by default for development
      expect(config.getDefault(FeatureFlag.debugTools), isTrue);
    });

    test('videoReplies should be enabled by default in debug builds', () {
      const config = BuildConfiguration();

      expect(config.getDefault(FeatureFlag.videoReplies), isTrue);
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
        config.getEnvironmentKey(FeatureFlag.debugTools),
        equals('FF_DEBUG_TOOLS'),
      );
      expect(
        config.getEnvironmentKey(FeatureFlag.videoReplies),
        equals('FF_VIDEO_REPLIES'),
      );
    });

    test('integratedApps should default to false', () {
      const config = BuildConfiguration();

      expect(config.getDefault(FeatureFlag.integratedApps), isFalse);
    });

    test('curatedLists should default to true', () {
      const config = BuildConfiguration();

      expect(config.getDefault(FeatureFlag.curatedLists), isTrue);
    });

    test('post-publish experiment has a build-time off switch', () {
      const config = BuildConfiguration();

      expect(
        config.getDefault(FeatureFlag.postPublishConfirmationExperiment),
        const bool.fromEnvironment(
          'FF_POST_PUBLISH_CONFIRMATION_EXPERIMENT',
          defaultValue: true,
        ),
      );
      expect(
        config.getEnvironmentKey(FeatureFlag.postPublishConfirmationExperiment),
        'FF_POST_PUBLISH_CONFIRMATION_EXPERIMENT',
      );
      expect(
        config.getDefault(FeatureFlag.postPublishConfirmationTreatment),
        const bool.fromEnvironment(
          'FF_POST_PUBLISH_CONFIRMATION_TREATMENT',
          defaultValue: true,
        ),
      );
      expect(
        config.getEnvironmentKey(FeatureFlag.postPublishConfirmationTreatment),
        'FF_POST_PUBLISH_CONFIRMATION_TREATMENT',
      );
    });

    test('integratedApps should map to FF_INTEGRATED_APPS env var', () {
      const config = BuildConfiguration();

      expect(
        config.getEnvironmentKey(FeatureFlag.integratedApps),
        equals('FF_INTEGRATED_APPS'),
      );
    });

    test('feed auto advance is not feature flagged', () {
      expect(
        FeatureFlag.values.map((flag) => flag.name),
        isNot(contains('feedAutoAdvance')),
      );
    });
  });
}
