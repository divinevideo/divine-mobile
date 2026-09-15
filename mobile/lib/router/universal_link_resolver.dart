// ABOUTME: Pure resolvers from universal-link and divine:// URIs to GoRouter paths
// ABOUTME: Shared source of truth used by the router redirect and tests

import 'package:openvine/screens/curated_list_by_author_screen.dart';
import 'package:openvine/screens/curated_list_feed_screen.dart';
import 'package:openvine/screens/hashtag_screen_router.dart';
import 'package:openvine/screens/profile_screen_router.dart';
import 'package:openvine/screens/saved_videos_screen.dart';
import 'package:openvine/screens/search_results/view/search_results_page.dart';
import 'package:openvine/screens/video_detail_screen.dart';
import 'package:openvine/services/deep_link_service.dart';

/// Converts a Divine web URL into an internal drill-down route path.
///
/// Unlike [universalLinkToRouterPath], this helper includes video links
/// because callers such as DM bubbles want to `push` the detail page on top
/// of the current stack rather than defer to the app-wide deep-link listener.
String? divineUrlToPushRoute(Uri uri) {
  if (!uri.scheme.startsWith('http')) return null;
  final host = uri.host.toLowerCase();
  if (host != 'divine.video' && host != 'www.divine.video') return null;

  final deepLink = DeepLinkService.parseDeepLink(uri.toString());
  return _pushRouteForDeepLink(deepLink);
}

String? _pushRouteForDeepLink(DeepLink deepLink) {
  switch (deepLink.type) {
    case DeepLinkType.video:
      final videoRef = deepLink.videoRef;
      if (videoRef == null || videoRef.isEmpty) return null;
      return VideoDetailScreen.pathForId(videoRef);
    case DeepLinkType.profile:
      final npub = deepLink.npub;
      if (npub == null || npub.isEmpty) return null;
      final index = deepLink.index;
      if (index != null) {
        return ProfileScreenRouter.pathForIndex(npub, index);
      }
      return ProfileScreenRouter.pathForNpub(npub);
    case DeepLinkType.hashtag:
      final tag = deepLink.hashtag;
      if (tag == null || tag.isEmpty) return null;
      return HashtagScreenRouter.pathForTag(tag);
    case DeepLinkType.search:
      final term = deepLink.searchTerm;
      if (term == null || term.isEmpty) return null;
      return SearchResultsPage.pathForQuery(term, requestFocusOnMount: false);
    case DeepLinkType.list:
      final listPubkey = deepLink.listPubkey;
      final listId = deepLink.listId;
      if (listId == null || listId.isEmpty) return null;
      if (listPubkey == null || listPubkey.isEmpty) {
        return CuratedListFeedScreen.pathForId(listId);
      }
      return CuratedListByAuthorScreen.pathFor(
        pubkey: listPubkey,
        listId: listId,
      );
    // savedVideos is unreachable here — it only arrives over divine://, which
    // both callers reject before this point. customSchemeToRouterPath owns it.
    case DeepLinkType.savedVideos:
    case DeepLinkType.signerCallback:
    case DeepLinkType.unknown:
      return null;
  }
}

/// Converts a `divine://` custom-scheme app-route link into an internal path.
///
/// Returns null for everything else, including NIP-46 signer callbacks. A
/// custom scheme can be opened by any app on the device, so only saved videos
/// and the AASA-parity route prefixes resolve to a location here.
String? customSchemeToRouterPath(Uri uri) {
  if (uri.scheme != 'divine') return null;

  final deepLink = DeepLinkService.parseDeepLink(uri.toString());
  if (deepLink.type == DeepLinkType.savedVideos) {
    return SavedVideosScreen.path;
  }

  // Only the authority-less form addresses app routes. Anything else is a
  // signer callback or untrusted input, and belongs to
  // divineSchemeRedirectTarget.
  if (uri.host.isNotEmpty) return null;

  final segments = uri.pathSegments
      .where((segment) => segment.isNotEmpty)
      .toList();
  // Every allow-listed prefix is a `/prefix/value` shape, so a bare prefix
  // names no destination and must not fall through to the matcher.
  if (segments.length < 2 ||
      !_customSchemeRoutablePrefixes.contains(segments.first)) {
    return null;
  }

  // Resolve through the https table so the two schemes cannot drift. It
  // covers both the paths DeepLinkService models (/search/* becomes
  // /search-results/:query) and deeper ones it does not (/video/:id/likers),
  // which fall through to the path verbatim.
  final canonical = Uri(
    scheme: 'https',
    host: 'divine.video',
    pathSegments: segments,
    queryParameters: uri.queryParameters.isEmpty ? null : uri.queryParameters,
  );
  final mapped = _pushRouteForDeepLink(
    DeepLinkService.parseDeepLink(canonical.toString()),
  );
  if (mapped != null) return mapped;
  return canonical.hasQuery
      ? '${canonical.path}?${canonical.query}'
      : canonical.path;
}

/// Path prefixes the `divine://` scheme may address beyond `saved-videos`.
///
/// Mirrors the universal-link claims in the served apple-app-site-association
/// files, so the custom scheme reaches exactly what a web page can already
/// reach over https — and nothing more.
const _customSchemeRoutablePrefixes = <String>{
  'video',
  'profile',
  'hashtag',
  'search',
  'list',
};

/// Converts a universal-link [uri] into an internal GoRouter path.
///
/// Returns the internal path (e.g. `/search-results/music`) when the URI is a
/// divine.video universal link that maps to an in-app destination and the
/// mapping should be applied at the router layer. Returns `null` otherwise —
/// either because the URI is not a universal link, or because its handling is
/// deferred to the [DeepLinkService] stream listener.
///
/// Resolving to a path is not the same as being allowed to reach it: the
/// returned path is a *destination*, which [appRouterRedirect] then runs
/// through the auth and minor-account-review gates like any other location.
/// Returning it from the redirect instead was terminal, and let a
/// restricted-minor account reach `/profile`, `/hashtag`, `/search` and
/// `/list` by opening the shared https link (#7146).
///
/// Video deep links (`/video/:id`) intentionally return `null`: the listener
/// uses `router.push` to keep the home feed underneath the detail page so
/// back-navigation returns to the main screen. Rewriting in the router
/// redirect would replace the stack instead of stacking on top.
///
/// Only canonical Divine web hosts are accepted here, mirroring
/// [DeepLinkService.parseDeepLink]. Paths on `login.divine.video`
/// (OAuth callbacks) already match internal GoRoutes by coincidence of path
/// (e.g. `/reset-password`, `/verify-email`) so no rewrite is needed for them.
String? universalLinkToRouterPath(Uri uri) {
  if (!uri.scheme.startsWith('http')) return null;
  final host = uri.host.toLowerCase();
  if (host != 'divine.video' && host != 'www.divine.video') return null;

  final deepLink = DeepLinkService.parseDeepLink(uri.toString());
  final route = _pushRouteForDeepLink(deepLink);
  switch (deepLink.type) {
    case DeepLinkType.video:
    case DeepLinkType.savedVideos:
    case DeepLinkType.signerCallback:
    case DeepLinkType.unknown:
      return null;
    case DeepLinkType.profile:
    case DeepLinkType.hashtag:
    case DeepLinkType.search:
    case DeepLinkType.list:
      return route;
  }
}
