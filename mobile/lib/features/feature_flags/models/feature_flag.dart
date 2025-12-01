// ABOUTME: Feature flag enum defining available feature flags for divine
// ABOUTME: Provides type-safe flag definitions with display names and descriptions

enum FeatureFlag {
  newCameraUI('New Camera UI', 'Enhanced camera interface with new controls'),
  enhancedVideoPlayer(
    'Enhanced Video Player',
    'Improved video playback engine with better performance',
  ),
  enhancedAnalytics(
    'Enhanced Analytics',
    'Detailed usage tracking and insights',
  ),
  newProfileLayout('New Profile Layout', 'Redesigned user profile screen'),
  livestreamingBeta(
    'Livestreaming Beta',
    'Live video streaming feature (beta)',
  ),
  debugTools('Debug Tools', 'Developer debugging utilities and diagnostics'),
  routerDrivenHome(
    'Router-Driven Home Screen',
    'New router-driven home screen architecture (eliminates lifecycle bugs)',
  ),
  enableVideoEditorV1(
    'Video Editor V1',
    'Enable video editing functionality (disabled on web, enabled on native platforms)',
  );

  const FeatureFlag(this.displayName, this.description);

  final String displayName;
  final String description;
}
