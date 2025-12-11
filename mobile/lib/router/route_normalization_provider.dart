// ABOUTME: Route normalization provider - ensures canonical URL format
// ABOUTME: Redirects to canonical URLs for negative indices, encoding, unknown paths

import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/router/app_router.dart';
import 'package:openvine/router/route_utils.dart';

/// Watches router location changes and redirects to canonical URLs when needed.
/// Safe to watch at app root; contains guards to avoid loops.
final routeNormalizationProvider = Provider<void>((ref) {
  final router = ref.read(goRouterProvider);

  // Set up listener on router delegate to detect navigation changes
  void listener() {
    final loc = router.routeInformationProvider.value.uri.toString();

    // Parse and rebuild to get canonical form
    final parsed = parseRoute(loc);
    final canonical = buildRoute(parsed);

    // If not canonical, schedule post-frame redirect
    if (canonical != loc) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        // Check again before redirecting to avoid loops if location changed
        final now = router.routeInformationProvider.value.uri.toString();
        if (now != canonical) {
          router.go(canonical);
        }
      });
    }
  }

  // Attach listener and ensure cleanup on dispose
  router.routerDelegate.addListener(listener);
  ref.onDispose(() => router.routerDelegate.removeListener(listener));
});
