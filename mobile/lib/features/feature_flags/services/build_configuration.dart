// ABOUTME: Build configuration service providing compile-time feature flag defaults
// ABOUTME: Maps environment variables to feature flag defaults for build-time configuration

import 'package:openvine/features/feature_flags/models/feature_flag.dart';

class BuildConfiguration {
  const BuildConfiguration();

  /// Get the default value for a feature flag from environment variables
  bool getDefault(FeatureFlag flag) {
    switch (flag) {
      case FeatureFlag.newCameraUI:
        return const bool.fromEnvironment(
          'FF_NEW_CAMERA_UI',
          defaultValue: false,
        );
      case FeatureFlag.enhancedVideoPlayer:
        return const bool.fromEnvironment(
          'FF_ENHANCED_VIDEO_PLAYER',
          defaultValue: false,
        );
      case FeatureFlag.enhancedAnalytics:
        return const bool.fromEnvironment(
          'FF_ENHANCED_ANALYTICS',
          defaultValue: false,
        );
      case FeatureFlag.newProfileLayout:
        return const bool.fromEnvironment(
          'FF_NEW_PROFILE_LAYOUT',
          defaultValue: false,
        );
      case FeatureFlag.livestreamingBeta:
        return const bool.fromEnvironment(
          'FF_LIVESTREAMING_BETA',
          defaultValue: false,
        );
      case FeatureFlag.debugTools:
        return const bool.fromEnvironment('FF_DEBUG_TOOLS', defaultValue: true);
      case FeatureFlag.routerDrivenHome:
        return const bool.fromEnvironment(
          'FF_ROUTER_DRIVEN_HOME',
          defaultValue: false,
        );
      case FeatureFlag.enableVideoEditorV1:
        // Video editor now works on all platforms (uses dialog-based editor)
        return const bool.fromEnvironment(
          'FF_ENABLE_VIDEO_EDITOR_V1',
          defaultValue: true,
        );
    }
  }

  /// Check if a flag has a default value defined
  bool hasDefault(FeatureFlag flag) {
    // All flags have defaults in our implementation
    return true;
  }

  /// Get the environment variable key for a flag
  String getEnvironmentKey(FeatureFlag flag) {
    switch (flag) {
      case FeatureFlag.newCameraUI:
        return 'FF_NEW_CAMERA_UI';
      case FeatureFlag.enhancedVideoPlayer:
        return 'FF_ENHANCED_VIDEO_PLAYER';
      case FeatureFlag.enhancedAnalytics:
        return 'FF_ENHANCED_ANALYTICS';
      case FeatureFlag.newProfileLayout:
        return 'FF_NEW_PROFILE_LAYOUT';
      case FeatureFlag.livestreamingBeta:
        return 'FF_LIVESTREAMING_BETA';
      case FeatureFlag.debugTools:
        return 'FF_DEBUG_TOOLS';
      case FeatureFlag.routerDrivenHome:
        return 'FF_ROUTER_DRIVEN_HOME';
      case FeatureFlag.enableVideoEditorV1:
        return 'FF_ENABLE_VIDEO_EDITOR_V1';
    }
  }
}
