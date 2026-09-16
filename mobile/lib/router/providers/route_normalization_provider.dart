// ABOUTME: Route normalization provider - ensures canonical URL format
// ABOUTME: Redirects to canonical URLs for negative indices and encoding

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/listenable_provider_bridge.dart';
import 'package:openvine/router/app_router.dart';
import 'package:openvine/router/providers/page_context_provider.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/services/deep_link_service.dart';
import 'package:unified_logger/unified_logger.dart';

@visibleForTesting
bool shouldSkipRouteNormalization(String loc) {
  // buildRoute cannot emit query strings or fragments for any RouteContext.
  // Normalizing these locations would drop route-owned state by construction.
  if (loc.contains('?') || loc.contains('#')) {
    return true;
  }

  // Skip GoRouter-owned flows before canonicalization. Some entries also fail
  // closed in parseKnownRoute; keeping them here documents route families that
  // must stay unnormalized if the modeled parser grows later.
  if (loc.startsWith(RoutePaths.welcome) ||
      loc.startsWith(RoutePaths.nostrConnect) ||
      loc == RoutePaths.minorAccountReview ||
      loc.startsWith('${RoutePaths.minorAccountReview}/') ||
      RegExp(r'^/apps/[^/]+/sandbox$').hasMatch(loc) ||
      RegExp(r'^/video/[^/]+/(likers|reposters)$').hasMatch(loc)) {
    return true;
  }

  final uri = Uri.tryParse(loc);
  if (uri == null) {
    return false;
  }

  final deepLinkType = DeepLinkService.parseDeepLink(loc).type;
  if (deepLinkType == DeepLinkType.signerCallback) {
    return true;
  }

  if (!uri.scheme.startsWith('http')) {
    return false;
  }

  final host = uri.host.toLowerCase();
  final isCanonicalDivineHost =
      host == 'divine.video' || host == 'www.divine.video';
  if (!isCanonicalDivineHost) {
    return false;
  }

  // Full divine.video universal links are resolved either in GoRouter's
  // redirect or in the app-wide DeepLinkService listener. They are not part
  // of the internal parseRoute/buildRoute contract, so normalizing them here
  // can rewrite a valid deep link into an unrelated internal fallback.
  return deepLinkType != DeepLinkType.unknown;
}

/// Watches router location changes and redirects to canonical URLs when needed.
/// Safe to watch at app root; contains guards to avoid loops.
final routeNormalizationProvider = Provider<void>((ref) {
  final router = ref.read(goRouterProvider);

  // Set up listener on router delegate to detect navigation changes
  void listener() {
    final uri = router.routeInformationProvider.value.uri;
    final loc = uri.toString();
    if (shouldSkipRouteNormalization(loc)) {
      Log.info(
        '🔄 RouteNormalizationProvider: skipping normalization for $loc',
        name: 'RouteNormalizationProvider',
      );
      return;
    }

    // Parse and rebuild to get canonical form. Unknown or incomplete routes
    // are left to GoRouter instead of being rewritten to home.
    // Only the *path* is normalized; query parameters are route input
    // (e.g. the library's ?type= clip filter) and must survive untouched.
    final parsed = parseKnownRoute(uri.path);
    if (parsed == null) {
      return;
    }
    final canonicalPath = buildRoute(parsed);

    // If not canonical, schedule post-frame redirect
    if (canonicalPath != uri.path) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        // Re-check before redirecting: skip when navigation moved on in the
        // meantime (redirecting then would yank the user off the new route)
        // or the location already became canonical.
        final now = router.routeInformationProvider.value.uri;
        if (now.toString() != loc || now.path == canonicalPath) return;

        final canonical = Uri(
          path: canonicalPath,
          query: now.query.isEmpty ? null : now.query,
        ).toString();
        Log.info(
          '🔄 Normalizing route from $now to $canonical',
          name: 'RouteNormalizationProvider',
        );
        router.go(canonical);
      });
    }
  }

  listenForProviderLifetime(ref, router.routerDelegate, listener);

  return;
});
