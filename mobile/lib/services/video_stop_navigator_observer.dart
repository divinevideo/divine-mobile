// ABOUTME: NavigatorObserver that stops videos when modals/dialogs are pushed
// ABOUTME: Only pauses for overlay routes that cover video content

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/utils/video_controller_cleanup.dart';
import 'package:openvine/utils/unified_logger.dart';

class VideoStopNavigatorObserver extends NavigatorObserver {
  @override
  void didStartUserGesture(
    Route<dynamic> route,
    Route<dynamic>? previousRoute,
  ) {
    super.didStartUserGesture(route, previousRoute);
    // Stop videos as soon as user starts navigation gesture
    // This fires BEFORE the new route is pushed
    _stopAllVideos('didStartUserGesture', route.settings.name);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    print(
      '🟪 NAV OBSERVER: didPush - route=${route.settings.name}, previousRoute=${previousRoute?.settings.name}',
    );
    // Also stop on push for programmatic navigation (non-gesture)
    _stopAllVideos('didPush', route.settings.name);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    print(
      '🟪 NAV OBSERVER: didPop - route=${route.settings.name}, previousRoute=${previousRoute?.settings.name}',
    );
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    print(
      '🟪 NAV OBSERVER: didRemove - route=${route.settings.name}, previousRoute=${previousRoute?.settings.name}',
    );
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    print(
      '🟪 NAV OBSERVER: didReplace - newRoute=${newRoute?.settings.name}, oldRoute=${oldRoute?.settings.name}',
    );
  }

  void _stopAllVideos(String action, String? routeName) {
    try {
      // Access container from navigator context
      if (navigator?.context != null) {
        final container = ProviderScope.containerOf(navigator!.context);

        // Stop videos immediately - no delay
        // This ensures videos stop BEFORE the new route builds
        disposeAllVideoControllers(container);
        Log.info(
          '📱 Navigation $action to route: ${routeName ?? 'unnamed'} - stopped all videos',
          name: 'VideoStopNavigatorObserver',
          category: LogCategory.system,
        );
      }
    } catch (e) {
      Log.error(
        'Failed to handle navigation: $e',
        name: 'VideoStopNavigatorObserver',
        category: LogCategory.system,
      );
    }
  }
}
