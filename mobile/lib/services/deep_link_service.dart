// ABOUTME: Service for handling universal/deep links from divine.video URLs
// ABOUTME: Parses video and profile URLs and routes to appropriate screens

import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:nostr_sdk/nip19/pubkey_for_logs.dart';
import 'package:openvine/utils/public_identifier_normalizer.dart';
import 'package:openvine/utils/relay_url_utils.dart';
import 'package:openvine/utils/sensitive_uri_for_logs.dart';
import 'package:unified_logger/unified_logger.dart';

/// Types of deep links supported by the app
enum DeepLinkType {
  video,
  profile,
  hashtag,
  search,
  list,
  savedVideos,
  signerCallback,
  unknown,
}

/// Represents a parsed deep link
class DeepLink {
  const DeepLink({
    required this.type,
    this.videoRef,
    this.npub,
    this.hashtag,
    this.searchTerm,
    this.listPubkey,
    this.listId,
    this.signerCallbackRelay,
    this.index,
    this.autoOpenComments = false,
  });

  final DeepLinkType type;

  /// Raw `/video/:id` route reference from the incoming URL.
  ///
  /// This may be a hex event ID, a first-party stable ID / d-tag, or a
  /// NIP-19 reference such as `note1`, `nevent1`, or `naddr1`.
  final String? videoRef;
  final String? npub;
  final String? hashtag;
  final String? searchTerm;

  /// Author pubkey of a `/list/:pubkey/:listId` link, normalized to
  /// lowercase hex (NIP-51 kind 30005 lists are addressed by author + d-tag).
  final String? listPubkey;

  /// The d-tag identifier of a `/list/:pubkey/:listId` link.
  final String? listId;
  final String? signerCallbackRelay;
  final int? index; // Optional video index for feed view

  /// When true the video detail screen should open the comments section
  /// automatically (e.g. navigating from a reply notification).
  final bool autoOpenComments;

  @override
  String toString() {
    final indexStr = index != null ? ', index: $index' : '';
    switch (type) {
      case DeepLinkType.video:
        final commentsStr = autoOpenComments ? ', autoOpenComments: true' : '';
        return 'DeepLink(type: video, videoRef: $videoRef$commentsStr)';
      case DeepLinkType.profile:
        return 'DeepLink(type: profile, npub: $npub$indexStr)';
      case DeepLinkType.hashtag:
        return 'DeepLink(type: hashtag, hashtag: $hashtag$indexStr)';
      case DeepLinkType.search:
        return 'DeepLink(type: search, searchTerm: $searchTerm$indexStr)';
      case DeepLinkType.list:
        return 'DeepLink(type: list, listPubkey: $listPubkey, '
            'listId: $listId)';
      case DeepLinkType.savedVideos:
        return 'DeepLink(type: savedVideos)';
      case DeepLinkType.signerCallback:
        return 'DeepLink(type: signerCallback)';
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
          '📱 App opened with deep link: ${redactUriStringForLogs(initialUri.toString())}',
          name: 'DeepLinkService',
          category: LogCategory.ui,
        );
        final deepLink = DeepLinkService.parseDeepLink(initialUri.toString());
        _controller.add(deepLink);
      } else {
        Log.debug(
          'No initial deep link present at startup',
          name: 'DeepLinkService',
          category: LogCategory.ui,
        );
      }

      // Listen for deep links while app is running
      _subscription = _appLinks.uriLinkStream.listen(
        (uri) {
          Log.info(
            '📱 Received deep link while running: ${redactUriStringForLogs(uri.toString())}',
            name: 'DeepLinkService',
            category: LogCategory.ui,
          );
          final deepLink = DeepLinkService.parseDeepLink(uri.toString());
          _controller.add(deepLink);
        },
        onError: (Object error, StackTrace stackTrace) {
          Log.error(
            'Deep link stream error: $error',
            name: 'DeepLinkService',
            category: LogCategory.ui,
          );
        },
      );
    } catch (e) {
      Log.error(
        'Error initializing deep link service: $e',
        name: 'DeepLinkService',
        category: LogCategory.ui,
      );
    }
  }

  /// Parse a divine.video URL into a [DeepLink].
  ///
  /// Pure: no instance state is touched, safe to call from route redirects.
  static DeepLink parseDeepLink(String url) {
    try {
      final uri = Uri.parse(url);

      // The divine:// scheme splits on the authority. Every callback anyone
      // emits carries one — Divine mints `divine://nostrconnect`, and NIP-46
      // gives signers no say over the callback string beyond appending query
      // parameters — so the empty authority is free to address app routes.
      if (uri.scheme == 'divine') {
        if (uri.host.isEmpty) {
          return _parseCustomSchemeAppRoute(uri);
        }
        if (uri.host != _signerCallbackHost) {
          // Any app can open a custom scheme, so an authority we never mint
          // is untrusted input rather than a callback — classifying it as one
          // would hand a stranger the signer-callback side effects (#6733).
          Log.warning(
            'Ignoring divine:// URL with an unrecognised authority: '
            '${_describeUriForLogs(uri)}',
            name: 'DeepLinkService',
            category: LogCategory.ui,
          );
          return const DeepLink(type: DeepLinkType.unknown);
        }
        // Signer apps open this scheme to bring our app back to foreground
        // after the user approves the connection. We emit signerCallback so
        // listeners can trigger relay reconnection for the nostrconnect
        // session.
        Log.info(
          'Received NIP-46 signer callback: ${redactUriStringForLogs(url)}',
          name: 'DeepLinkService',
          category: LogCategory.auth,
        );
        return DeepLink(
          type: DeepLinkType.signerCallback,
          signerCallbackRelay: _validSignerCallbackRelay(
            uri.queryParameters['relay'],
          ),
        );
      }

      if (_isInternalAppRoute(uri, url)) {
        Log.debug(
          'Skipping internal app route during deep-link parse: '
          '${_describeUriForLogs(uri)}',
          name: 'DeepLinkService',
          category: LogCategory.ui,
        );
        return const DeepLink(type: DeepLinkType.unknown);
      }

      // Accept divine.video itself plus any subdomain
      // (login.divine.video, staging.divine.video, etc.). Sibling and
      // lookalike hosts like notdivine.video or divine.video.evil.com
      // must still be rejected.
      final host = uri.host.toLowerCase();
      final isDivineHost =
          host == 'divine.video' || host.endsWith('.divine.video');
      if (!isDivineHost) {
        final embeddedUri = _extractEmbeddedUri(uri);
        final wrappedTargetSuffix = embeddedUri == null
            ? ''
            : ', embeddedTarget=${_describeUriForLogs(embeddedUri)}';
        Log.warning(
          'Ignoring deep link from non-divine host: '
          '${_describeUriForLogs(uri)}$wrappedTargetSuffix',
          name: 'DeepLinkService',
          category: LogCategory.ui,
        );
        return const DeepLink(type: DeepLinkType.unknown);
      }

      final pathSegments = uri.pathSegments;

      // Handle /video/{videoRef}. The path segment is preserved verbatim;
      // downstream resolution accepts raw IDs, stable IDs, and NIP-19 refs.
      if (pathSegments.length == 2 && pathSegments[0] == 'video') {
        final videoRef = pathSegments[1];
        Log.info(
          '📱 Parsed video deep link ref: $videoRef',
          name: 'DeepLinkService',
          category: LogCategory.ui,
        );
        return DeepLink(type: DeepLinkType.video, videoRef: videoRef);
      }

      // Handle /profile/{npub} or /profile/{npub}/{index}
      if ((pathSegments.length == 2 || pathSegments.length == 3) &&
          pathSegments[0] == 'profile') {
        final npub = pathSegments[1];
        final index = pathSegments.length == 3
            ? int.tryParse(pathSegments[2])
            : null;
        Log.info(
          '📱 Parsed profile deep link: ${pubkeyForLogs(npub)}'
          '${index != null ? " (index: $index)" : ""}',
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

      // Handle /list/{listId} links to locally known lists.
      if (pathSegments.length == 2 && pathSegments[0] == 'list') {
        final listId = pathSegments[1];
        if (listId.isEmpty) {
          return const DeepLink(type: DeepLinkType.unknown);
        }
        Log.info(
          '📱 Parsed list deep link id: $listId',
          name: 'DeepLinkService',
          category: LogCategory.ui,
        );
        return DeepLink(type: DeepLinkType.list, listId: listId);
      }

      // Handle /list/{pubkey}/{listId} — NIP-51 kind 30005 curated video
      // lists, addressed by author + d-tag. The author segment accepts hex,
      // npub, or nprofile and is normalized to lowercase hex for relay
      // filters.
      if (pathSegments.length == 3 && pathSegments[0] == 'list') {
        final listPubkey = normalizePublicIdentifier(
          pathSegments[1],
        )?.hexPubkey.toLowerCase();
        final listId = pathSegments[2];
        if (listPubkey == null || listId.isEmpty) {
          Log.warning(
            'Ignoring list deep link with invalid author or id: '
            '${_describeUriForLogs(uri)}',
            name: 'DeepLinkService',
            category: LogCategory.ui,
          );
          return const DeepLink(type: DeepLinkType.unknown);
        }
        Log.info(
          '📱 Parsed list deep link: ${pubkeyForLogs(listPubkey)}/$listId',
          name: 'DeepLinkService',
          category: LogCategory.ui,
        );
        return DeepLink(
          type: DeepLinkType.list,
          listPubkey: listPubkey,
          listId: listId,
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

  /// Programmatically push a [DeepLink] into the stream.
  ///
  /// Use this when a navigation intent is received outside of the OS
  /// universal-link / custom-scheme channel (e.g. from an FCM payload or a
  /// local notification tap) so that the same [deepLinksProvider] listener in
  /// the widget tree can handle it uniformly.
  void pushLink(DeepLink link) {
    _controller.add(link);
  }

  /// The only authority Divine mints on its NIP-46 callback.
  ///
  /// See `NostrConnectCoordinator`, which embeds `divine://nostrconnect`.
  static const _signerCallbackHost = 'nostrconnect';

  /// Routes the authority-less `divine:///<route>` form may open.
  ///
  /// Deny-by-default: any app on the device can open a custom scheme, so a
  /// route is only reachable this way by being listed here.
  static const _customSchemeAppRoutes = <String, DeepLinkType>{
    'saved-videos': DeepLinkType.savedVideos,
  };

  static DeepLink _parseCustomSchemeAppRoute(Uri uri) {
    final segments = uri.pathSegments;
    final type = segments.length == 1
        ? _customSchemeAppRoutes[segments.single]
        : null;

    if (type == null) {
      // Not a warning, and not necessarily the end of the road: the router's
      // allow-list resolves the universal-link claim paths that carry no
      // DeepLinkType of their own. `AppRouter` logs the outcome either way.
      Log.debug(
        'No DeepLinkType for divine:// route, deferring to the router '
        'allow-list: ${_describeUriForLogs(uri)}',
        name: 'DeepLinkService',
        category: LogCategory.ui,
      );
      return const DeepLink(type: DeepLinkType.unknown);
    }

    Log.info(
      '📱 Parsed app-route deep link: /${segments.single}',
      name: 'DeepLinkService',
      category: LogCategory.ui,
    );
    return DeepLink(type: type);
  }

  static bool _isInternalAppRoute(Uri uri, String rawUrl) {
    return uri.scheme.isEmpty &&
        uri.host.isEmpty &&
        rawUrl.startsWith('/') &&
        uri.path.startsWith('/');
  }

  static Uri? _extractEmbeddedUri(Uri uri) {
    const candidateKeys = <String>[
      'url',
      'u',
      'target',
      'link',
      'redirect',
      'redirect_url',
      'redirectUrl',
      'deep_link',
      'deepLink',
    ];

    for (final key in candidateKeys) {
      final value = uri.queryParameters[key];
      if (value == null || value.isEmpty) continue;
      final parsed = Uri.tryParse(value);
      if (parsed == null) continue;
      if (parsed.hasScheme || parsed.host.isNotEmpty) {
        return parsed;
      }
    }

    return null;
  }

  /// The relay a signer named in its callback, or null when we may not dial it.
  ///
  /// Any app can open this scheme, so the hint is only as trustworthy as the
  /// caller. Dropping it leaves the callback itself intact: the pairing
  /// handoff still reconnects the relays the session advertised.
  static String? _validSignerCallbackRelay(String? relay) {
    final trimmed = relay?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    if (!isSignerCallbackRelayUrlAllowed(trimmed)) {
      Log.warning(
        'Refused signer callback relay ${redactUriStringForLogs(trimmed)}',
        name: 'DeepLinkService',
        category: LogCategory.auth,
      );
      return null;
    }
    return trimmed;
  }

  static String _describeUriForLogs(Uri uri) {
    final scheme = uri.scheme.isEmpty ? '(none)' : uri.scheme;
    final host = uri.host.isEmpty ? '(none)' : uri.host;
    final primaryRoute = uri.pathSegments.isEmpty
        ? '(root)'
        : '/${uri.pathSegments.first}${uri.pathSegments.length > 1 ? '/*' : ''}';
    final queryKeys = uri.queryParameters.keys.toList()..sort();
    return 'scheme=$scheme, host=$host, route=$primaryRoute, '
        'segments=${uri.pathSegments.length}, queryKeys=$queryKeys';
  }
}
