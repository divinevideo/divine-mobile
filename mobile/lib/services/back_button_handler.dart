// ABOUTME: Platform channel handler for Android back button interception
// ABOUTME: Routes back button presses from native Android to GoRouter navigation

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/router/page_context_provider.dart';
import 'package:openvine/router/route_utils.dart';

class BackButtonHandler {
  static const MethodChannel _channel = MethodChannel(
    'org.openvine/navigation',
  );
  static GoRouter? _router;
  static dynamic _ref;

  static void initialize(GoRouter router, dynamic ref) {
    _router = router;
    _ref = ref;

    // Only set up platform channel on Android
    if (!kIsWeb && Platform.isAndroid) {
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'onBackPressed') {
          return await _handleBackButton();
        }
        return false;
      });
    }
  }

  static Future<bool> _handleBackButton() async {
    if (_router == null || _ref == null) {
      return false;
    }

    // Get current route context
    final ctxAsync = _ref.read(pageContextProvider);
    final ctx = ctxAsync.value;
    if (ctx == null) {
      return false;
    }

    // Handle back navigation based on context
    if (ctx.videoIndex != null) {
      // In feed mode - go to grid mode (remove videoIndex)
      final gridCtx = RouteContext(
        type: ctx.type,
        hashtag: ctx.hashtag,
        searchTerm: ctx.searchTerm,
        npub: ctx.npub,
        videoIndex: null,
      );
      final newRoute = buildRoute(gridCtx);
      _router!.go(newRoute);
      return true; // Handled
    }

    // In grid mode or other contexts
    switch (ctx.type) {
      case RouteType.hashtag:
      case RouteType.search:
        // Go back to explore
        _router!.go('/explore');
        return true; // Handled

      case RouteType.profile:
        if (ctx.npub != 'me') {
          // From other user's profile, go back to home
          _router!.go('/home/0');
          return true; // Handled
        }
        // From own profile, fall through to default (stay in app)
        break;

      case RouteType.explore:
      case RouteType.notifications:
        // From explore or notifications, go to home
        _router!.go('/home/0');
        return true; // Handled

      case RouteType.home:
        // Already at home - stay in app (don't exit)
        return true; // Handled (don't exit)

      default:
        break;
    }

    // Default: stay in app (don't let Android close it)
    return true; // Handled
  }
}
