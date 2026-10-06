// ABOUTME: Tests for FeatureFlag enum defining available feature flags
// ABOUTME: Validates enum properties, uniqueness, and metadata consistency

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';

void main() {
  group('FeatureFlag enum', () {
    test('livestream flag stays available', () {
      expect(FeatureFlag.livestreamingBeta.displayName, 'Livestream');
    });
    test('should have display names', () {
      expect(FeatureFlag.debugTools.displayName, equals('Debug Tools'));
    });

    test('should have descriptions', () {
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
      expect(FeatureFlag.values, contains(FeatureFlag.accountSwitching));
      expect(FeatureFlag.values, contains(FeatureFlag.enhancedAnalytics));
      expect(FeatureFlag.values, contains(FeatureFlag.debugTools));
      expect(FeatureFlag.values, contains(FeatureFlag.integratedApps));
      expect(FeatureFlag.values, contains(FeatureFlag.videoReplies));
    });

    test('integratedApps flag should have correct metadata', () {
      expect(FeatureFlag.integratedApps.displayName, equals('Integrated Apps'));
      expect(FeatureFlag.integratedApps.description, isNotEmpty);
      expect(FeatureFlag.integratedApps.description.length, greaterThan(10));
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

    test('no longer carries an appearance flag', () {
      // Light mode graduated: appearance is a plain user setting now, so
      // neither the picker nor media chrome is gated. A reintroduced flag
      // here would mean the ungating regressed.
      expect(
        FeatureFlag.values.map((flag) => flag.name),
        isNot(anyElement(anyOf('lightMode', 'adaptiveMediaChrome'))),
      );
    });

    test('should classify staged rollout flags as internal', () {
      expect(
        FeatureFlag.communityContentWarnings.audience,
        FeatureFlagAudience.internal,
      );
      expect(FeatureFlag.feedTuning.audience, FeatureFlagAudience.internal);
      expect(
        FeatureFlag.postPublishConfirmationExperiment.audience,
        FeatureFlagAudience.internal,
      );
      expect(
        FeatureFlag.postPublishConfirmationTreatment.audience,
        FeatureFlagAudience.internal,
      );
      // Sending to a group works before receiving one does (#7338), so the
      // switch stays out of the user-facing list until both halves ship.
      expect(FeatureFlag.groupMessages.audience, FeatureFlagAudience.internal);
    });

    test('should leave user-facing flags visible to users', () {
      expect(FeatureFlag.curatedLists.audience, FeatureFlagAudience.user);
      expect(FeatureFlag.blueskyPublishing.audience, FeatureFlagAudience.user);
      expect(FeatureFlag.videoReplies.audience, FeatureFlagAudience.user);
    });
  });
}
