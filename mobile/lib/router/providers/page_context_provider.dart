// ABOUTME: Derived provider that parses router location into structured context
// ABOUTME: Single source of truth for "what page are we on?" with route types and parsing

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nostr_sdk/nip19/pubkey_for_logs.dart';
import 'package:openvine/router/providers/router_location_provider.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/utils/npub_hex.dart';
import 'package:unified_logger/unified_logger.dart';

/// Route types supported by the app
enum RouteType {
  home,
  explore,
  notifications,
  inbox, // Inbox screen (Messages + Notifications combined)
  profile,
  likedVideos, // Current user's liked videos feed
  hashtag, // Still supported as push route within explore
  categoryGallery, // Category gallery pushed from explore categories
  videoRecorder, // Video recorder screen
  videoEditor, // Video editor screen
  videoMetadata, // Video editor meta screen
  videoEdit, // Full-screen edit flow for published videos
  subtitleEdit, // Full-screen subtitle edit flow for published videos
  importKey,
  invites, // Invite codes share/list screen
  badges, // Badge awards dashboard
  settings,
  relaySettings, // Relay configuration screen
  relayDiagnostic, // Relay connectivity diagnostics
  blossomSettings, // Blossom media server settings
  notificationSettings, // Notification preferences
  keyManagement, // Key backup/export screen
  safetySettings, // Safety and privacy settings
  contentFilters, // Content filter preferences (Show/Warn/Hide)
  editProfile, // Profile editing screen
  clips, // Clip library screen
  clipsOnly, // Clip library screen without Sounds tab
  drafts, // Draft library screen
  welcome, // Welcome/onboarding screen
  developerOptions, // Developer options (hidden, unlock by tapping version 7x)
  loginOptions, // Login options screen (choose login method)
  following, // Following list screen
  followers, // Followers list screen
  videoFeed, // Legacy route alias — resolved same as pooledVideoFeed
  profileView, // Other user's profile (fullscreen, no bottom nav)
  curatedList, // Curated video list screen (NIP-51 kind 30005)
  discoverLists, // Discover public lists screen
  peopleListCreate, // Create NIP-51 kind 30000 people list screen
  peopleListMembers, // People list members and videos screen
  peopleListAddPeople, // Full-screen picker for adding people to a list
  creatorAnalytics, // Creator analytics dashboard (profile owner)
  sound, // Sound detail screen for audio reuse
  originalSound, // Original sound detail screen (creator's own audio)
  contentPreferences, // Content preferences (language, audio, filters)
  generalSettings, // General app behavior and integration settings
  storageManagement, // Storage screen (clear caches, audit clip library)
  monetizationLinksSettings, // Creator monetization link settings
  accountStatus, // Account enforcement status (s-t-s#200)
  appLanguage, // App language picker (UI locale override)
  appearanceSettings, // Appearance picker (system/light/dark)
  supportCenter, // Support center (bug reports, logs, FAQ, legal links)
  legal, // Legal screen (ToS, Privacy, Safety, DMCA, Licenses)
  nostrSettings, // Nostr settings (relays, media servers, keys, account)
  nip05Settings, // NIP-05 management nested under Nostr settings
  blueskySettings, // Bluesky crosspost publishing settings
  crosspostingSettings, // External platform connection and posting modes
  secureAccount,
  pooledVideoFeed, // Fullscreen video feed route
  videoDetail, // Video detail screen (deep link to specific video)
  conversation, // DM conversation detail (pushed from inbox)
  messageRequests, // Message requests inbox (pushed from inbox)
  requestPreview, // Message request preview (pushed from requests)
}

/// Structured representation of a route
class RouteContext {
  const RouteContext({
    required this.type,
    this.videoIndex,
    this.appSlug,
    this.npub,
    this.hashtag,
    this.categoryName,
    this.listId,
    this.soundId,
    this.videoId,
    this.draftId,
    this.conversationId,
  });

  final RouteType type;
  final int? videoIndex;
  final String? appSlug;
  final String? npub;
  final String? hashtag;
  final String? categoryName;
  final String? listId;
  final String? soundId;
  final String? videoId;
  final String? draftId;
  final String? conversationId;

  /// What this route is *about*, with [videoIndex] deliberately left out.
  ///
  /// A shell branch re-creates its provider scope when this changes and
  /// reuses it when it does not. That split matters because two feeds
  /// rewrite their own URL on every swipe — `ExploreFeedContent`'s and
  /// `ProfileVideoFeedView`'s `onPageChanged` both call `context.go` with a
  /// new index — so keying on the whole path would tear down the players and
  /// scroll position mid-swipe. Opening a different account or list is a
  /// different subject and does rebuild.
  ///
  /// Add any new subject-bearing field here. [videoIndex] is the only one
  /// that must stay out.
  Object get subjectKey => (
    type,
    appSlug,
    npub,
    hashtag,
    categoryName,
    listId,
    soundId,
    videoId,
    draftId,
    conversationId,
  );
}

/// Decodes a URL path segment, returning the raw input on malformed
/// percent-encoding instead of throwing. See #3413.
///
/// `Uri.decodeComponent` throws `ArgumentError` on malformed input
/// (e.g. a dangling `%` from a hand-crafted deep link). Treating that
/// as a recoverable boundary error rather than a programmer bug is
/// intentional here, so the lint is suppressed locally.
String _safeDecode(String segment) {
  try {
    return Uri.decodeComponent(segment);
    // ignore: avoid_catching_errors
  } on ArgumentError {
    return segment;
  }
}

/// Returns whether [segments] matches one of the route shapes modeled below.
///
/// GoRouter rejects paths with extra or unknown segments. Keep the parser's
/// normalizer contract aligned with that behavior so malformed paths are left
/// to GoRouter instead of being shortened into a different valid route.
bool _isKnownRouteShape(List<String> segments) {
  final firstSegment = segments.first;
  final length = segments.length;

  switch (firstSegment) {
    case 'home':
    case 'explore':
    case 'notifications':
    case 'liked-videos':
      return length <= 2;
    case 'profile':
      return length == 2 || length == 3;
    case 'inbox':
      return length == 1 ||
          (length == 3 &&
              (segments[1] == 'conversation' ||
                  segments[1] == 'message-requests')) ||
          (length == 2 && segments[1] == 'message-requests');
    case 'hashtag':
      return length == 2;
    case 'categories':
      return length == 2;
    case 'video-editor':
    case 'video-edit':
    case 'subtitle-edit':
      return length == 1 || length == 2;
    case 'settings':
      return length == 1 ||
          (length == 2 &&
              (segments[1] == RoutePaths.monetizationLinksSettingsSubpath ||
                  segments[1] == RoutePaths.accountStatusSubpath));
    case 'apps':
      return length == 1 || length == 2;
    case 'following':
    case 'followers':
    case 'sound':
    case 'original-sound':
    case 'profile-view':
      return length == 2;
    case 'list':
      return length == 2 || length == 3;
    case 'people-lists':
      return length == 2 || (length == 3 && segments[2] == 'add-people');
    case 'nostr-settings':
      return length == 1 ||
          (length == 2 && segments[1] == RoutePaths.nip05SettingsSubpath);
    case 'welcome':
      return length == 1 || (length == 2 && segments[1] == 'login-options');
    case 'video':
      return length == 2;
    case 'video-recorder':
    case 'video-metadata':
    case 'badges':
    case 'creator-analytics':
    case 'relay-settings':
    case 'relay-diagnostic':
    case 'blossom-settings':
    case 'notification-settings':
    case 'key-management':
    case 'safety-settings':
    case 'content-filters':
    case 'content-preferences':
    case 'general-settings':
    case 'storage-management':
    case 'invites':
    case 'app-language':
    case 'appearance-settings':
    case 'support-center':
    case 'legal':
    case 'bluesky-settings':
    case 'crossposting-settings':
    case 'edit-profile':
    case 'clips':
    case 'clips-no-sound':
    case 'clips-only':
    case 'drafts':
    case 'import-key':
    case 'developer-options':
    case 'video-feed':
    case 'discover-lists':
    case 'secure-account':
    case 'pooled-video-feed':
      return length == 1;
    default:
      return false;
  }
}

/// Parse a URL path into a structured RouteContext
/// Normalizes negative indices to 0 and decodes URL-encoded parameters
RouteContext parseRoute(String path) {
  return _parseRoute(path, knownOnly: false) ??
      const RouteContext(type: RouteType.home, videoIndex: 0);
}

/// Whether [location] is [currentUserHex]'s own profile, in grid or feed mode.
///
/// Takes the raw router location (query string and all) so callers can pass
/// `routeInformationProvider.value.uri` straight through, with or without
/// its query.
///
/// Compares through [routeIdentifiesUser] rather than string-matching the
/// segment: a `:npub` segment may be npub, nprofile, bare hex, or the
/// relative `me`, so a deep link carrying any encoding but bech32 would
/// otherwise read as somebody else's profile.
bool isOwnProfileLocation(String location, String currentUserHex) {
  final route = parseRoute(location);
  return route.type == RouteType.profile &&
      routeIdentifiesUser(route.npub, currentUserHex);
}

/// Whether [context] is [currentUserHex]'s own profile *grid*.
///
/// Video mode keeps the shell's app bar even on your own profile, so a
/// non-null `videoIndex` is deliberately not an own-profile grid.
///
/// One owner for a decision two layers make: the profile screen wraps the
/// grid in its own scaffold, and the shell suppresses its app bar for it.
/// When those two disagree, your own profile renders inside a stranger's
/// chrome in the same frame — which is what `routeIdentifiesUser` exists to
/// prevent, and why this predicate is not inlined at either site.
bool isOwnProfileGridRoute(RouteContext? context, String? currentUserHex) =>
    context != null &&
    context.type == RouteType.profile &&
    context.videoIndex == null &&
    routeIdentifiesUser(context.npub, currentUserHex);

/// Parse a URL path only when its route family is explicitly modeled.
///
/// This is the route normalizer's fail-closed entry point: unknown or
/// incomplete paths return null so GoRouter can handle them instead of being
/// rewritten to home.
RouteContext? parseKnownRoute(String path) {
  return _parseRoute(path, knownOnly: true);
}

RouteContext? _parseRoute(String path, {required bool knownOnly}) {
  // Callers pass full router locations, which may carry query parameters
  // (e.g. /clips-only?type=video). Segment matching below must only ever see
  // the path portion — otherwise the last segment becomes
  // "clips-only?type=video", matches nothing, and the route falls through to
  // the RouteType.home fallback (which the normalizer then "corrects" by
  // yanking the user to /home/0).
  final pathOnly = Uri.tryParse(path)?.path ?? path;
  final segments = pathOnly.split('/').where((s) => s.isNotEmpty).toList();

  if (segments.isEmpty) {
    return const RouteContext(type: RouteType.home, videoIndex: 0);
  }

  if (knownOnly && !_isKnownRouteShape(segments)) {
    return null;
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
        return knownOnly ? null : const RouteContext(type: RouteType.home);
      }
      final npub = _safeDecode(segments[1]); // Decode URL encoding
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
      return RouteContext(type: RouteType.profile, npub: npub);

    case 'notifications':
      final rawIndex = segments.length > 1 ? int.tryParse(segments[1]) ?? 0 : 0;
      final index = rawIndex < 0 ? 0 : rawIndex;
      return RouteContext(type: RouteType.notifications, videoIndex: index);

    case 'inbox':
      // /inbox - inbox screen
      // /inbox/conversation/:id - conversation detail
      // /inbox/message-requests - message requests inbox
      // /inbox/message-requests/:id - request preview
      if (segments.length > 2 && segments[1] == 'conversation') {
        final conversationId = _safeDecode(segments[2]);
        return RouteContext(
          type: RouteType.conversation,
          conversationId: conversationId,
        );
      }
      if (segments.length > 1 && segments[1] == 'message-requests') {
        if (segments.length > 2) {
          final conversationId = _safeDecode(segments[2]);
          return RouteContext(
            type: RouteType.requestPreview,
            conversationId: conversationId,
          );
        }
        return const RouteContext(type: RouteType.messageRequests);
      }
      return const RouteContext(type: RouteType.inbox);

    case 'liked-videos':
      // /liked-videos - grid mode
      // /liked-videos/5 - feed mode at index 5
      if (segments.length > 1) {
        final rawIndex = int.tryParse(segments[1]);
        final index = rawIndex != null && rawIndex < 0 ? 0 : rawIndex;
        return RouteContext(type: RouteType.likedVideos, videoIndex: index);
      }
      return const RouteContext(type: RouteType.likedVideos);

    case 'hashtag':
      if (segments.length < 2) {
        return knownOnly ? null : const RouteContext(type: RouteType.home);
      }
      final tag = _safeDecode(segments[1]); // Decode URL encoding
      final rawIndex = segments.length > 2 ? int.tryParse(segments[2]) : null;
      final index = rawIndex != null && rawIndex < 0 ? 0 : rawIndex;
      return RouteContext(
        type: RouteType.hashtag,
        hashtag: tag,
        videoIndex: index,
      );

    case 'categories':
      if (segments.length < 2) {
        return knownOnly ? null : const RouteContext(type: RouteType.home);
      }
      final categoryName = _safeDecode(segments[1]);
      return RouteContext(
        type: RouteType.categoryGallery,
        categoryName: categoryName,
      );

    case 'video-recorder':
      return const RouteContext(type: RouteType.videoRecorder);

    case 'video-editor':
      if (segments.length > 1) {
        final draftId = _safeDecode(segments[1]);
        return RouteContext(type: RouteType.videoEditor, draftId: draftId);
      }
      return const RouteContext(type: RouteType.videoEditor);

    case 'video-metadata':
      return const RouteContext(type: RouteType.videoMetadata);

    case 'video-edit':
      if (segments.length > 1) {
        final videoId = _safeDecode(segments[1]);
        return RouteContext(type: RouteType.videoEdit, videoId: videoId);
      }
      return const RouteContext(type: RouteType.videoEdit);

    case 'subtitle-edit':
      if (segments.length > 1) {
        final videoId = _safeDecode(segments[1]);
        return RouteContext(type: RouteType.subtitleEdit, videoId: videoId);
      }
      return const RouteContext(type: RouteType.subtitleEdit);

    case 'settings':
      if (segments.length > 1 &&
          segments[1] == RoutePaths.accountStatusSubpath) {
        return const RouteContext(type: RouteType.accountStatus);
      }
      if (segments.length > 1 &&
          segments[1] == RoutePaths.monetizationLinksSettingsSubpath) {
        return const RouteContext(type: RouteType.monetizationLinksSettings);
      }
      return const RouteContext(type: RouteType.settings);

    case 'badges':
      return const RouteContext(type: RouteType.badges);

    case 'apps':
      if (segments.length > 1) {
        return RouteContext(
          type: RouteType.settings,
          appSlug: _safeDecode(segments[1]),
        );
      }
      return const RouteContext(type: RouteType.settings, appSlug: '');

    case 'creator-analytics':
      return const RouteContext(type: RouteType.creatorAnalytics);

    case 'relay-settings':
      return const RouteContext(type: RouteType.relaySettings);

    case 'relay-diagnostic':
      return const RouteContext(type: RouteType.relayDiagnostic);

    case 'blossom-settings':
      return const RouteContext(type: RouteType.blossomSettings);

    case 'notification-settings':
      return const RouteContext(type: RouteType.notificationSettings);

    case 'key-management':
      return const RouteContext(type: RouteType.keyManagement);

    case 'safety-settings':
      return const RouteContext(type: RouteType.safetySettings);

    case 'content-filters':
      return const RouteContext(type: RouteType.contentFilters);

    case 'content-preferences':
      return const RouteContext(type: RouteType.contentPreferences);

    case 'general-settings':
      return const RouteContext(type: RouteType.generalSettings);

    case 'storage-management':
      return const RouteContext(type: RouteType.storageManagement);

    case 'invites':
      return const RouteContext(type: RouteType.invites);

    case 'app-language':
      return const RouteContext(type: RouteType.appLanguage);

    case 'appearance-settings':
      return const RouteContext(type: RouteType.appearanceSettings);

    case 'support-center':
      return const RouteContext(type: RouteType.supportCenter);

    case 'legal':
      return const RouteContext(type: RouteType.legal);

    case 'nostr-settings':
      if (segments.length > 1 &&
          segments[1] == RoutePaths.nip05SettingsSubpath) {
        return const RouteContext(type: RouteType.nip05Settings);
      }
      return const RouteContext(type: RouteType.nostrSettings);

    case 'bluesky-settings':
      return const RouteContext(type: RouteType.blueskySettings);

    case 'crossposting-settings':
      return const RouteContext(type: RouteType.crosspostingSettings);

    case 'edit-profile':
    case 'setup-profile':
      // Profile editing screens - standalone routes outside ShellRoute
      return const RouteContext(type: RouteType.editProfile);

    case 'clips':
      // Clip library screen - standalone route outside ShellRoute
      return const RouteContext(type: RouteType.clips);

    case 'clips-no-sound':
    case 'clips-only':
      // Clip library screen without Sounds tab
      return const RouteContext(type: RouteType.clipsOnly);

    case 'drafts':
      // Draft library screen - standalone route outside ShellRoute
      return const RouteContext(type: RouteType.drafts);

    case 'import-key':
      return const RouteContext(type: RouteType.importKey);

    case 'welcome':
      // /welcome/login-options → loginOptions
      if (segments.length > 1 && segments[1] == 'login-options') {
        return const RouteContext(type: RouteType.loginOptions);
      }
      return const RouteContext(type: RouteType.welcome);

    case 'developer-options':
      return const RouteContext(type: RouteType.developerOptions);
    case 'following':
      if (segments.length < 2) {
        return knownOnly ? null : const RouteContext(type: RouteType.home);
      }
      final followingPubkey = _safeDecode(segments[1]);
      return RouteContext(type: RouteType.following, npub: followingPubkey);

    case 'followers':
      if (segments.length < 2) {
        return knownOnly ? null : const RouteContext(type: RouteType.home);
      }
      final followersPubkey = _safeDecode(segments[1]);
      return RouteContext(type: RouteType.followers, npub: followersPubkey);

    case 'video-feed':
      return const RouteContext(type: RouteType.videoFeed);
    case 'list':
      if (segments.length < 2) {
        return knownOnly ? null : const RouteContext(type: RouteType.explore);
      }
      // Web-canonical deep-link shape /list/:pubkey/:listId — the author
      // key rides in [RouteContext.npub] so buildRoute can reconstruct the
      // by-author path instead of collapsing it to /list/:listId.
      if (segments.length >= 3) {
        return RouteContext(
          type: RouteType.curatedList,
          npub: _safeDecode(segments[1]),
          listId: _safeDecode(segments[2]),
        );
      }
      final listId = _safeDecode(segments[1]);
      return RouteContext(type: RouteType.curatedList, listId: listId);

    case 'discover-lists':
      return const RouteContext(type: RouteType.discoverLists);

    case 'people-lists':
      if (segments.length > 1 && segments[1] == 'new') {
        return const RouteContext(type: RouteType.peopleListCreate);
      }
      if (segments.length < 2) {
        return knownOnly ? null : const RouteContext(type: RouteType.home);
      }
      final peopleListId = _safeDecode(segments[1]);
      if (segments.length > 2 && segments[2] == 'add-people') {
        return RouteContext(
          type: RouteType.peopleListAddPeople,
          listId: peopleListId,
        );
      }
      return RouteContext(
        type: RouteType.peopleListMembers,
        listId: peopleListId,
      );

    case 'sound':
      if (segments.length < 2) {
        return knownOnly ? null : const RouteContext(type: RouteType.home);
      }
      final soundId = _safeDecode(segments[1]);
      return RouteContext(type: RouteType.sound, soundId: soundId);

    case 'original-sound':
      if (segments.length < 2) {
        return knownOnly ? null : const RouteContext(type: RouteType.home);
      }
      final originalSoundPubkey = _safeDecode(segments[1]);
      return RouteContext(
        type: RouteType.originalSound,
        npub: originalSoundPubkey,
      );

    case 'profile-view':
      if (segments.length < 2) {
        return knownOnly ? null : const RouteContext(type: RouteType.home);
      }
      final profileViewNpub = _safeDecode(segments[1]);
      return RouteContext(type: RouteType.profileView, npub: profileViewNpub);

    case 'secure-account':
      return const RouteContext(type: RouteType.secureAccount);

    case 'pooled-video-feed':
      return const RouteContext(type: RouteType.pooledVideoFeed);

    case 'video':
      if (segments.length < 2) {
        return knownOnly ? null : const RouteContext(type: RouteType.home);
      }
      final videoId = _safeDecode(segments[1]);
      return RouteContext(type: RouteType.videoDetail, videoId: videoId);

    default:
      return null;
  }
}

/// Build a URL path from a RouteContext
/// Encodes dynamic parameters and normalizes indices to >= 0
String buildRoute(RouteContext context) {
  switch (context.type) {
    case RouteType.home:
      final rawIndex = context.videoIndex ?? 0;
      final index = rawIndex < 0 ? 0 : rawIndex;
      return RoutePaths.videoFeedForIndex(index);

    case RouteType.explore:
      if (context.videoIndex != null) {
        final rawIndex = context.videoIndex!;
        final index = rawIndex < 0 ? 0 : rawIndex;
        return RoutePaths.exploreForIndex(index);
      }
      return RoutePaths.explore;

    case RouteType.notifications:
      if (context.videoIndex != null) {
        final rawIndex = context.videoIndex!;
        final index = rawIndex < 0 ? 0 : rawIndex;
        return RoutePaths.notificationsForIndex(index);
      }
      return RoutePaths.notifications;

    case RouteType.conversation:
      return RoutePaths.conversationForId(context.conversationId ?? '');

    case RouteType.inbox:
      return RoutePaths.inbox;

    case RouteType.messageRequests:
      return RoutePaths.messageRequests;

    case RouteType.requestPreview:
      final id = Uri.encodeComponent(context.conversationId ?? '');
      return '/inbox/message-requests/$id';

    case RouteType.profile:
      final npub = Uri.encodeComponent(context.npub ?? '');
      if (context.videoIndex != null) {
        final rawIndex = context.videoIndex!;
        final index = rawIndex < 0 ? 0 : rawIndex;
        return RoutePaths.profileForIndex(npub, index);
      }
      return RoutePaths.profileForNpub(npub);

    case RouteType.likedVideos:
      if (context.videoIndex != null) {
        final rawIndex = context.videoIndex!;
        final index = rawIndex < 0 ? 0 : rawIndex;
        return RoutePaths.likedVideosForIndex(index);
      }
      return RoutePaths.likedVideos;

    case RouteType.hashtag:
      final hashtag = context.hashtag ?? '';
      return RoutePaths.hashtagForTag(hashtag);

    case RouteType.categoryGallery:
      final categoryName = context.categoryName;
      if (categoryName == null || categoryName.isEmpty) {
        return RoutePaths.explore;
      }
      return RoutePaths.categoryGalleryFor(categoryName);

    case RouteType.videoRecorder:
      return RoutePaths.videoRecorder;

    case RouteType.videoEditor:
      if (context.draftId != null) {
        return '${RoutePaths.videoEditor}/${Uri.encodeComponent(context.draftId!)}';
      }
      return RoutePaths.videoEditor;

    case RouteType.videoMetadata:
      return RoutePaths.videoMetadata;

    case RouteType.videoEdit:
      if (context.videoId != null) {
        return RoutePaths.videoMetadataEditFor(context.videoId!);
      }
      return RoutePaths.videoMetadataEdit;

    case RouteType.subtitleEdit:
      if (context.videoId != null) {
        return RoutePaths.subtitleEditorFor(context.videoId!);
      }
      return RoutePaths.subtitleEditor;

    case RouteType.settings:
      if (context.appSlug != null) {
        if (context.appSlug!.isEmpty) {
          return RoutePaths.appsDirectory;
        }
        return RoutePaths.appDetailForSlug(
          Uri.encodeComponent(context.appSlug!),
        );
      }
      return RoutePaths.settings;

    case RouteType.badges:
      return RoutePaths.badges;

    case RouteType.relaySettings:
      return RoutePaths.relaySettings;

    case RouteType.relayDiagnostic:
      return RoutePaths.relayDiagnostic;

    case RouteType.blossomSettings:
      return RoutePaths.blossomSettings;

    case RouteType.notificationSettings:
      return RoutePaths.notificationSettings;

    case RouteType.keyManagement:
      return RoutePaths.keyManagement;

    case RouteType.safetySettings:
      return RoutePaths.safetySettings;

    case RouteType.contentFilters:
      return RoutePaths.contentFilters;

    case RouteType.contentPreferences:
      return RoutePaths.contentPreferences;

    case RouteType.generalSettings:
      return RoutePaths.generalSettings;

    case RouteType.storageManagement:
      return RoutePaths.storageManagement;

    case RouteType.monetizationLinksSettings:
      return RoutePaths.monetizationLinksSettings;

    case RouteType.invites:
      return RoutePaths.invites;

    case RouteType.appLanguage:
      return RoutePaths.appLanguage;

    case RouteType.appearanceSettings:
      return RoutePaths.appearanceSettings;

    case RouteType.supportCenter:
      return RoutePaths.supportCenter;

    case RouteType.legal:
      return RoutePaths.legal;

    case RouteType.accountStatus:
      return RoutePaths.accountStatus;

    case RouteType.nostrSettings:
      return RoutePaths.nostrSettings;

    case RouteType.nip05Settings:
      return RoutePaths.nip05Settings;

    case RouteType.blueskySettings:
      return RoutePaths.blueskySettings;

    case RouteType.crosspostingSettings:
      return RoutePaths.crosspostingSettings;

    case RouteType.editProfile:
      return RoutePaths.profileSetupEdit;

    case RouteType.importKey:
      return RoutePaths.keyImport;

    case RouteType.clips:
      return RoutePaths.libraryClips;

    case RouteType.clipsOnly:
      return RoutePaths.libraryClipsOnly;

    case RouteType.drafts:
      return RoutePaths.libraryDrafts;

    case RouteType.welcome:
      return RoutePaths.welcome;

    case RouteType.developerOptions:
      return RoutePaths.developerOptions;

    case RouteType.loginOptions:
      return RoutePaths.welcomeLoginOptions;

    case RouteType.following:
      return RoutePaths.followingForPubkey(context.npub ?? '');

    case RouteType.followers:
      return RoutePaths.followersForPubkey(context.npub ?? '');

    case RouteType.videoFeed:
      return RoutePaths.pooledFullscreenVideoFeed;

    case RouteType.profileView:
      final npub = Uri.encodeComponent(context.npub ?? '');
      return RoutePaths.otherProfileForNpub(npub);

    case RouteType.curatedList:
      final listAuthor = context.npub;
      if (listAuthor != null && listAuthor.isNotEmpty) {
        return RoutePaths.curatedListByAuthorFor(
          pubkey: listAuthor,
          listId: context.listId ?? '',
        );
      }
      return RoutePaths.curatedListFeedForId(context.listId ?? '');

    case RouteType.discoverLists:
      return RoutePaths.discoverLists;

    case RouteType.peopleListCreate:
      return RoutePaths.createPeopleList;

    case RouteType.peopleListMembers:
      final listId = Uri.encodeComponent(context.listId ?? '');
      return '/people-lists/$listId';

    case RouteType.peopleListAddPeople:
      final listId = Uri.encodeComponent(context.listId ?? '');
      return '/people-lists/$listId/add-people';

    case RouteType.creatorAnalytics:
      return RoutePaths.creatorAnalytics;

    case RouteType.sound:
      return RoutePaths.soundDetailForId(context.soundId ?? '');

    case RouteType.originalSound:
      return RoutePaths.originalSoundDetailForPubkey(context.npub ?? '');

    case RouteType.secureAccount:
      return RoutePaths.secureAccount;

    case RouteType.pooledVideoFeed:
      return RoutePaths.pooledFullscreenVideoFeed;

    case RouteType.videoDetail:
      return RoutePaths.videoDetailForId(context.videoId ?? '');
  }
}

/// StreamProvider that derives structured page context from router location
///
/// Uses async* to emit immediately when the raw location stream has a value.
/// This ensures tests using Stream.value() get synchronous first emission.
///
/// Example:
/// ```dart
/// final context = ref.watch(pageContextProvider);
/// context.when(
///   data: (ctx) {
///     if (ctx.type == RouteType.home) {
///       // Show home feed videos
///     }
///   },
///   loading: () => CircularProgressIndicator(),
///   error: (e, s) => ErrorWidget(e),
/// );
/// ```
final pageContextProvider = StreamProvider<RouteContext>((ref) async* {
  // Get the raw location stream (overridable in tests)
  final locations = ref.watch(routerLocationStreamProvider);

  // Emit a context immediately if the stream is a single-value Stream.value(...)
  // (In tests we often use Stream.value('/profile/npub...'))
  await for (final loc in locations) {
    final ctx = parseRoute(loc);
    Log.info(
      'CTX derive: type=${ctx.type} npub=${pubkeyForLogs(ctx.npub)} index=${ctx.videoIndex}',
      name: 'Route',
      category: LogCategory.system,
    );
    yield ctx;
  }
});

/// The globally-active route type — the tab actually on screen — independent
/// of the per-branch [pageContextProvider] scope.
///
/// Inside a `StatefulShellRoute` branch, [pageContextProvider] is scoped to
/// that branch's own route (so a kept-alive inactive branch keeps rendering
/// its real content). A branch screen that must instead know "is *my* tab the
/// active one?" — e.g. the home feed pausing playback when backgrounded —
/// reads this provider, which derives from the un-scoped router location and
/// therefore always reflects the real active tab.
