// ABOUTME: Route parsing and building utilities
// ABOUTME: Converts between URLs and structured route context

/// Route types supported by the app
enum RouteType {
  home,
  explore,
  notifications,
  profile,
  hashtag, // Still supported as push route within explore
  search,
  camera,
  importKey,
  settings,
  editProfile, // Profile editing screen
  drafts, // Video drafts screen
}

/// Structured representation of a route
class RouteContext {
  const RouteContext({
    required this.type,
    this.videoIndex,
    this.npub,
    this.hashtag,
    this.searchTerm,
  });

  final RouteType type;
  final int? videoIndex;
  final String? npub;
  final String? hashtag;
  final String? searchTerm;
}

/// Parse a URL path into a structured RouteContext
/// Normalizes negative indices to 0 and decodes URL-encoded parameters
RouteContext parseRoute(String path) {
  final segments = path.split('/').where((s) => s.isNotEmpty).toList();

  if (segments.isEmpty) {
    return const RouteContext(type: RouteType.home, videoIndex: 0);
  }

  final firstSegment = segments[0];

  switch (firstSegment) {
    case 'home':
      final rawIndex = segments.length > 1 ? int.tryParse(segments[1]) ?? 0 : 0;
      final index = rawIndex < 0 ? 0 : rawIndex;
      return RouteContext(type: RouteType.home, videoIndex: index);

    case 'explore':
      if (segments.length > 1) {
        final rawIndex = int.tryParse(segments[1]);
        final index = rawIndex != null && rawIndex < 0 ? 0 : rawIndex;
        return RouteContext(type: RouteType.explore, videoIndex: index);
      }
      return const RouteContext(type: RouteType.explore);

    case 'profile':
      if (segments.length < 2) {
        return const RouteContext(type: RouteType.home);
      }
      final npub = Uri.decodeComponent(segments[1]); // Decode URL encoding
      // Grid mode (no index) vs feed mode (with index)
      if (segments.length > 2) {
        final rawIndex = int.tryParse(segments[2]) ?? 0;
        final index = rawIndex < 0 ? 0 : rawIndex;
        return RouteContext(
          type: RouteType.profile,
          npub: npub,
          videoIndex: index,
        );
      }
      // Grid mode - no videoIndex
      return RouteContext(
        type: RouteType.profile,
        npub: npub,
        videoIndex: null,
      );

    case 'notifications':
      final rawIndex = segments.length > 1 ? int.tryParse(segments[1]) ?? 0 : 0;
      final index = rawIndex < 0 ? 0 : rawIndex;
      return RouteContext(type: RouteType.notifications, videoIndex: index);

    case 'hashtag':
      if (segments.length < 2) {
        return const RouteContext(type: RouteType.home);
      }
      final tag = Uri.decodeComponent(segments[1]); // Decode URL encoding
      final rawIndex = segments.length > 2 ? int.tryParse(segments[2]) : null;
      final index = rawIndex != null && rawIndex < 0 ? 0 : rawIndex;
      return RouteContext(
        type: RouteType.hashtag,
        hashtag: tag,
        videoIndex: index,
      );

    case 'search':
      // /search - grid mode, no term
      // /search/term - grid mode with search term
      // /search/term/5 - feed mode with search term at index 5
      String? searchTerm;
      int? index;

      if (segments.length > 1) {
        // Try parsing segment 1 as index first
        final maybeIndex = int.tryParse(segments[1]);
        if (maybeIndex != null) {
          // Legacy format: /search/5 (no search term, just index)
          index = maybeIndex < 0 ? 0 : maybeIndex;
        } else {
          // segment 1 is search term
          searchTerm = Uri.decodeComponent(segments[1]);
          // Check for index in segment 2
          if (segments.length > 2) {
            final rawIndex = int.tryParse(segments[2]);
            index = rawIndex != null && rawIndex < 0 ? 0 : rawIndex;
          }
        }
      }

      return RouteContext(
        type: RouteType.search,
        searchTerm: searchTerm,
        videoIndex: index,
      );

    case 'camera':
      return const RouteContext(type: RouteType.camera);

    case 'settings':
      return const RouteContext(type: RouteType.settings);

    case 'edit-profile':
    case 'setup-profile':
      // Profile editing screens - standalone routes outside ShellRoute
      return const RouteContext(type: RouteType.editProfile);

    case 'drafts':
      // Drafts screen - standalone route outside ShellRoute
      return const RouteContext(type: RouteType.drafts);

    case 'import-key':
      return const RouteContext(type: RouteType.importKey);

    default:
      return const RouteContext(type: RouteType.home, videoIndex: 0);
  }
}

/// Build a URL path from a RouteContext
/// Encodes dynamic parameters and normalizes indices to >= 0
String buildRoute(RouteContext context) {
  switch (context.type) {
    case RouteType.home:
      final rawIndex = context.videoIndex ?? 0;
      final index = rawIndex < 0 ? 0 : rawIndex;
      return '/home/$index';

    case RouteType.explore:
      if (context.videoIndex != null) {
        final rawIndex = context.videoIndex!;
        final index = rawIndex < 0 ? 0 : rawIndex;
        return '/explore/$index';
      }
      return '/explore';

    case RouteType.notifications:
      if (context.videoIndex != null) {
        final rawIndex = context.videoIndex!;
        final index = rawIndex < 0 ? 0 : rawIndex;
        return '/notifications/$index';
      }
      return '/notifications';

    case RouteType.profile:
      final npub = Uri.encodeComponent(context.npub ?? '');
      if (context.videoIndex != null) {
        final rawIndex = context.videoIndex!;
        final index = rawIndex < 0 ? 0 : rawIndex;
        return '/profile/$npub/$index';
      }
      return '/profile/$npub';

    case RouteType.hashtag:
      final hashtag = Uri.encodeComponent(context.hashtag ?? '');
      if (context.videoIndex != null) {
        final rawIndex = context.videoIndex!;
        final index = rawIndex < 0 ? 0 : rawIndex;
        return '/hashtag/$hashtag/$index';
      }
      return '/hashtag/$hashtag';

    case RouteType.search:
      // Grid mode (null videoIndex):
      //   - With term: '/search/{term}'
      //   - Without term: '/search'
      // Feed mode (videoIndex set):
      //   - With term: '/search/{term}/{index}'
      //   - Without term (legacy): '/search/{index}'
      if (context.searchTerm != null) {
        final encodedTerm = Uri.encodeComponent(context.searchTerm!);
        if (context.videoIndex == null) {
          return '/search/$encodedTerm';
        }
        final rawIndex = context.videoIndex!;
        final index = rawIndex < 0 ? 0 : rawIndex;
        return '/search/$encodedTerm/$index';
      }

      // Legacy format without search term
      if (context.videoIndex == null) return '/search';
      final rawIndex = context.videoIndex!;
      final index = rawIndex < 0 ? 0 : rawIndex;
      return '/search/$index';

    case RouteType.camera:
      return '/camera';

    case RouteType.settings:
      return '/settings';

    case RouteType.editProfile:
      return '/edit-profile';

    case RouteType.importKey:
      return '/import-key';

    case RouteType.drafts:
      return '/drafts';
  }
}
