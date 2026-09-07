// ABOUTME: Compile-time flag for the App Store screenshot pipeline.
// ABOUTME: True only in debug builds launched with SCREENSHOT_MODE=true.

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Parsed per-launch screenshot configuration.
class ScreenshotLaunchConfig {
  const ScreenshotLaunchConfig({
    required this.initialRoute,
    required this.seedClips,
  });

  final String? initialRoute;
  final bool seedClips;
}

/// Compile-time switch and launch config for the App Store screenshot
/// pipeline.
///
/// Enabled only when the build passes `--dart-define=SCREENSHOT_MODE=true`
/// AND the build is a debug build. The `kDebugMode` factor makes this a
/// compile-time `false` in profile and release builds, so every screenshot
/// affordance is tree-shaken out of shipping binaries.
///
/// Per-launch values (which screen to open, whether to seed editor clips)
/// come from the XCUITest launch environment. Dart's `Platform.environment`
/// is empty on iOS, so the native `AppDelegate` reads them from `ProcessInfo`
/// and writes them into `SharedPreferences` at launch; [loadLaunchConfig]
/// reads them back here.
abstract class ScreenshotMode {
  static const bool enabled =
      kDebugMode && bool.fromEnvironment('SCREENSHOT_MODE');

  /// Bundled frame shown instead of a live camera viewfinder during captures.
  static const String viewfinderFixture =
      'assets/seed_media/thumbnails/'
      '606486ed7079b4b2614e9ca3e0f46c1c9a4a39d52c90dd25a9e51d1b7cf96b33.jpg';

  /// SharedPreferences keys the native `AppDelegate` writes the launch env
  /// into (see `exportScreenshotLaunchConfig`).
  static const String _routeKey = 'screenshot_initial_route';
  static const String _seedClipsKey = 'screenshot_seed_clips';

  /// go_router location the current launch should open, or null for the
  /// default. Populated by [loadLaunchConfig].
  static String? initialRoute;

  /// Whether this launch should seed editor fixture clips. Populated by
  /// [loadLaunchConfig].
  static bool seedClips = false;

  /// Reads the launch config the native side wrote into [prefs]. No-op (and
  /// safe) outside screenshot builds. Call once during startup before
  /// navigating to the capture route.
  static void loadLaunchConfig(SharedPreferences prefs) {
    if (!enabled) return;
    final config = parseLaunchConfig(
      route: prefs.getString(_routeKey),
      seedClips: prefs.getString(_seedClipsKey),
    );
    initialRoute = config.initialRoute;
    seedClips = config.seedClips;
  }

  /// Parses raw launch values exported by the native side.
  static ScreenshotLaunchConfig parseLaunchConfig({
    required String? route,
    required String? seedClips,
  }) {
    return ScreenshotLaunchConfig(
      initialRoute: route == null || route.isEmpty ? null : route,
      seedClips: seedClips == '1',
    );
  }
}
