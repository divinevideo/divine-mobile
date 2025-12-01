// ABOUTME: Service for handling universal/deep links from divine.video URLs
// ABOUTME: Parses video and profile URLs and routes to appropriate screens

import 'dart:async';
import 'package:openvine/utils/unified_logger.dart';
import 'package:app_links/app_links.dart';

/// Types of deep links supported by the app
enum DeepLinkType { video, profile, hashtag, search, unknown }

/// Represents a parsed deep link
class DeepLink {
  const DeepLink({
    required this.type,
    this.videoId,
    this.npub,
    this.hashtag,
    this.searchTerm,
    this.index,
  });

  final DeepLinkType type;
  final String? videoId;
  final String? npub;
  final String? hashtag;
  final String? searchTerm;
  final int? index; // Optional video index for feed view

  @override
  String toString() {
    final indexStr = index != null ? ', index: $index' : '';
    switch (type) {
      case DeepLinkType.video:
        return 'DeepLink(type: video, videoId: $videoId)';
      case DeepLinkType.profile:
        return 'DeepLink(type: profile, npub: $npub$indexStr)';
      case DeepLinkType.hashtag:
        return 'DeepLink(type: hashtag, hashtag: $hashtag$indexStr)';
      case DeepLinkType.search:
        return 'DeepLink(type: search, searchTerm: $searchTerm$indexStr)';
      case DeepLinkType.unknown:
        return 'DeepLink(type: unknown)';
    }
  }
}

/// Service for handling universal/deep links
class DeepLinkService {
  DeepLinkService();

  final _appLinks = AppLinks();
  StreamSubscription? _subscription;
  final _controller = StreamController<DeepLink>.broadcast();

  /// Stream of parsed deep links
  Stream<DeepLink> get linkStream => _controller.stream;

  /// Initialize deep link handling
  Future<void> initialize() async {
    try {
      // Check if app was opened via deep link
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        Log.info(
          '📱 App opened with deep link: $initialUri',
          name: 'DeepLinkService',
          category: LogCategory.ui,
        );
        final deepLink = parseDeepLink(initialUri.toString());
        _controller.add(deepLink);
      }

      // Listen for deep links while app is running
      _subscription = _appLinks.uriLinkStream.listen((uri) {
        Log.info(
          '📱 Received deep link while running: $uri',
          name: 'DeepLinkService',
          category: LogCategory.ui,
        );
        final deepLink = parseDeepLink(uri.toString());
        _controller.add(deepLink);
      });
    } catch (e) {
      Log.error(
        'Error initializing deep link service: $e',
        name: 'DeepLinkService',
        category: LogCategory.ui,
      );
    }
  }

  /// Parse a divine.video URL into a DeepLink
  DeepLink parseDeepLink(String url) {
    try {
      final uri = Uri.parse(url);

      // Only handle divine.video domain
      if (uri.host != 'divine.video') {
        Log.warning(
          'Ignoring deep link from non-divine.video domain: ${uri.host}',
          name: 'DeepLinkService',
          category: LogCategory.ui,
        );
        return const DeepLink(type: DeepLinkType.unknown);
      }

      final pathSegments = uri.pathSegments;

      // Handle /video/{videoId}
      if (pathSegments.length == 2 && pathSegments[0] == 'video') {
        final videoId = pathSegments[1];
        Log.info(
          '📱 Parsed video deep link: $videoId',
          name: 'DeepLinkService',
          category: LogCategory.ui,
        );
        return DeepLink(type: DeepLinkType.video, videoId: videoId);
      }

      // Handle /profile/{npub} or /profile/{npub}/{index}
      if ((pathSegments.length == 2 || pathSegments.length == 3) &&
          pathSegments[0] == 'profile') {
        final npub = pathSegments[1];
        final index = pathSegments.length == 3
            ? int.tryParse(pathSegments[2])
            : null;
        Log.info(
          '📱 Parsed profile deep link: $npub${index != null ? " (index: $index)" : ""}',
          name: 'DeepLinkService',
          category: LogCategory.ui,
        );
        return DeepLink(type: DeepLinkType.profile, npub: npub, index: index);
      }

      // Handle /hashtag/{tag} or /hashtag/{tag}/{index}
      if ((pathSegments.length == 2 || pathSegments.length == 3) &&
          pathSegments[0] == 'hashtag') {
        final hashtag = pathSegments[1];
        final index = pathSegments.length == 3
            ? int.tryParse(pathSegments[2])
            : null;
        Log.info(
          '📱 Parsed hashtag deep link: $hashtag${index != null ? " (index: $index)" : ""}',
          name: 'DeepLinkService',
          category: LogCategory.ui,
        );
        return DeepLink(
          type: DeepLinkType.hashtag,
          hashtag: hashtag,
          index: index,
        );
      }

      // Handle /search/{term} or /search/{term}/{index}
      if ((pathSegments.length == 2 || pathSegments.length == 3) &&
          pathSegments[0] == 'search') {
        final searchTerm = pathSegments[1];
        final index = pathSegments.length == 3
            ? int.tryParse(pathSegments[2])
            : null;
        Log.info(
          '📱 Parsed search deep link: $searchTerm${index != null ? " (index: $index)" : ""}',
          name: 'DeepLinkService',
          category: LogCategory.ui,
        );
        return DeepLink(
          type: DeepLinkType.search,
          searchTerm: searchTerm,
          index: index,
        );
      }

      Log.warning(
        'Unknown deep link path: ${uri.path}',
        name: 'DeepLinkService',
        category: LogCategory.ui,
      );
      return const DeepLink(type: DeepLinkType.unknown);
    } catch (e) {
      Log.error(
        'Error parsing deep link: $e',
        name: 'DeepLinkService',
        category: LogCategory.ui,
      );
      return const DeepLink(type: DeepLinkType.unknown);
    }
  }

  /// Dispose the service
  void dispose() {
    _subscription?.cancel();
    _controller.close();
  }
}
