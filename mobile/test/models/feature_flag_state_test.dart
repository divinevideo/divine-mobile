// ABOUTME: Tests for FeatureFlagState model managing flag values
// ABOUTME: Validates immutable state management and flag value storage

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/models/feature_flag_state.dart';

void main() {
  group('FeatureFlagState', () {
    test('should store flag values', () {
      final state = FeatureFlagState({
        FeatureFlag.newCameraUI: true,
        FeatureFlag.enhancedVideoPlayer: false,
      });

      expect(state.isEnabled(FeatureFlag.newCameraUI), isTrue);
      expect(state.isEnabled(FeatureFlag.enhancedVideoPlayer), isFalse);
    });

    test('should return false for undefined flags', () {
      final state = FeatureFlagState({});
      expect(state.isEnabled(FeatureFlag.newCameraUI), isFalse);
      expect(state.isEnabled(FeatureFlag.debugTools), isFalse);
    });

    test('should be immutable', () {
      final state1 = FeatureFlagState({});
      final state2 = state1.copyWith(FeatureFlag.newCameraUI, true);

      expect(state1.isEnabled(FeatureFlag.newCameraUI), isFalse);
      expect(state2.isEnabled(FeatureFlag.newCameraUI), isTrue);
    });

    test('should provide all flag values', () {
      final state = FeatureFlagState({
        FeatureFlag.newCameraUI: true,
        FeatureFlag.enhancedVideoPlayer: false,
        FeatureFlag.debugTools: true,
      });

      final allFlags = state.allFlags;
      expect(allFlags[FeatureFlag.newCameraUI], isTrue);
      expect(allFlags[FeatureFlag.enhancedVideoPlayer], isFalse);
      expect(allFlags[FeatureFlag.debugTools], isTrue);
    });

    test('should handle copyWith for multiple flags', () {
      final state1 = FeatureFlagState({FeatureFlag.newCameraUI: false});

      final state2 = state1.copyWith(FeatureFlag.newCameraUI, true);
      final state3 = state2.copyWith(FeatureFlag.enhancedVideoPlayer, true);

      expect(state3.isEnabled(FeatureFlag.newCameraUI), isTrue);
      expect(state3.isEnabled(FeatureFlag.enhancedVideoPlayer), isTrue);

      // Original states should remain unchanged
      expect(state1.isEnabled(FeatureFlag.newCameraUI), isFalse);
      expect(state2.isEnabled(FeatureFlag.enhancedVideoPlayer), isFalse);
    });

    test('should support equality comparison', () {
      final state1 = FeatureFlagState({
        FeatureFlag.newCameraUI: true,
        FeatureFlag.debugTools: false,
      });

      final state2 = FeatureFlagState({
        FeatureFlag.newCameraUI: true,
        FeatureFlag.debugTools: false,
      });

      final state3 = FeatureFlagState({
        FeatureFlag.newCameraUI: false,
        FeatureFlag.debugTools: false,
      });

      expect(state1, equals(state2));
      expect(state1, isNot(equals(state3)));
    });
  });
}
