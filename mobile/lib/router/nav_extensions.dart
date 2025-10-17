// ABOUTME: Navigation extension helpers for clean GoRouter call-sites
// ABOUTME: Provides goHome/goExplore/goNotifications/goProfile/pushCamera/pushSettings (hashtag available via goHashtag)

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/utils/public_identifier_normalizer.dart';
import 'route_utils.dart';

extension NavX on BuildContext {
  // Tab bases
  void goHome([int index = 0]) => go(buildRoute(
        RouteContext(type: RouteType.home, videoIndex: index),
      ));

  void goExplore([int? index]) => go(buildRoute(
        RouteContext(type: RouteType.explore, videoIndex: index),
      ));

  void goNotifications([int index = 0]) => go(buildRoute(
        RouteContext(type: RouteType.notifications, videoIndex: index),
      ));

  void goHashtag(String tag, [int? index]) => go(buildRoute(
        RouteContext(
          type: RouteType.hashtag,
          hashtag: tag,
          videoIndex: index,
        ),
      ));

  void goProfile(String identifier, [int index = 0]) {
    // Handle 'me' special case - need to get current user's hex
    String? currentUserHex;
    if (identifier == 'me') {
      // Access container to get auth service
      final container = ProviderScope.containerOf(this, listen: false);
      final authService = container.read(authServiceProvider);
      currentUserHex = authService.currentPublicKeyHex;
    }

    // Normalize any format (npub/nprofile/hex/me) to npub for URL
    final npub = normalizeToNpub(identifier, currentUserHex: currentUserHex);
    if (npub == null) {
      // Invalid identifier - log warning and don't navigate
      debugPrint('⚠️ Invalid public identifier: $identifier');
      return;
    }

    go(buildRoute(
      RouteContext(
        type: RouteType.profile,
        npub: npub,
        videoIndex: index,
      ),
    ));
  }

  void pushProfile(String identifier, [int index = 0]) {
    // Handle 'me' special case - need to get current user's hex
    String? currentUserHex;
    if (identifier == 'me') {
      // Access container to get auth service
      final container = ProviderScope.containerOf(this, listen: false);
      final authService = container.read(authServiceProvider);
      currentUserHex = authService.currentPublicKeyHex;
    }

    // Normalize any format (npub/nprofile/hex/me) to npub for URL
    final npub = normalizeToNpub(identifier, currentUserHex: currentUserHex);
    if (npub == null) {
      // Invalid identifier - log warning and don't push
      debugPrint('⚠️ Invalid public identifier: $identifier');
      return;
    }

    push(buildRoute(
      RouteContext(
        type: RouteType.profile,
        npub: npub,
        videoIndex: index,
      ),
    ));
  }

  void goSearch([String? searchTerm, int? index]) => go(buildRoute(
        RouteContext(type: RouteType.search, searchTerm: searchTerm, videoIndex: index),
      ));

  // Optional pushes (non-tab routes)
  Future<void> pushCamera() => push('/camera');
  Future<void> pushSettings() => push('/settings');
}
