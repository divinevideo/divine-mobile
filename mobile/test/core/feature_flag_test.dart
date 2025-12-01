// ABOUTME: Tests for FeatureFlag enum defining available feature flags
// ABOUTME: Validates enum properties, uniqueness, and metadata consistency

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';

void main() {
  group('FeatureFlag enum', () {
    test('should have display names', () {
      expect(FeatureFlag.newCameraUI.displayName, equals('New Camera UI'));
      expect(
        FeatureFlag.enhancedVideoPlayer.displayName,
        equals('Enhanced Video Player'),
      );
      expect(FeatureFlag.debugTools.displayName, equals('Debug Tools'));
    });

    test('should have descriptions', () {
      expect(FeatureFlag.newCameraUI.description, isNotEmpty);
      expect(FeatureFlag.enhancedVideoPlayer.description, isNotEmpty);
      expect(FeatureFlag.debugTools.description, isNotEmpty);
    });

    test('should have unique names', () {
      final names = FeatureFlag.values.map((f) => f.name).toSet();
      expect(names.length, equals(FeatureFlag.values.length));
    });

    test('should have unique display names', () {
      final displayNames = FeatureFlag.values.map((f) => f.displayName).toSet();
      expect(displayNames.length, equals(FeatureFlag.values.length));
    });

    test('should include expected flags for OpenVine', () {
      expect(FeatureFlag.values, contains(FeatureFlag.newCameraUI));
      expect(FeatureFlag.values, contains(FeatureFlag.enhancedVideoPlayer));
      expect(FeatureFlag.values, contains(FeatureFlag.enhancedAnalytics));
      expect(FeatureFlag.values, contains(FeatureFlag.newProfileLayout));
      expect(FeatureFlag.values, contains(FeatureFlag.livestreamingBeta));
      expect(FeatureFlag.values, contains(FeatureFlag.debugTools));
    });

    test('should provide meaningful descriptions', () {
      for (final flag in FeatureFlag.values) {
        expect(
          flag.description.length,
          greaterThan(10),
          reason: 'Flag ${flag.name} should have meaningful description',
        );
      }
    });
  });
}
