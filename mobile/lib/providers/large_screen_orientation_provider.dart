// ABOUTME: Whether the platform ignores the app's orientation lock on large
// ABOUTME: displays, resolved once at startup and shared by every container

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the platform ignores this app's portrait lock on large displays.
///
/// Android 16 ignores the orientation, resizability and aspect-ratio
/// restrictions of apps that target API 36 on displays at least 600 dp
/// across, so a tablet shows the app in whichever orientation it is held.
/// Resolved once at startup by `resolveIgnoresOrientationLockOnLargeScreens`
/// and injected into every account container via `DeviceScope.overrides`.
///
/// Defaults to false, which is what every other platform reports: a container
/// built without the override lays out as if the lock holds.
final ignoresOrientationLockOnLargeScreensProvider = Provider<bool>(
  (ref) => false,
);
