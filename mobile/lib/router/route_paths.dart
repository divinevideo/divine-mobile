// ABOUTME: Canonical route path constants and builders for every named route
// ABOUTME: Leaf module with no imports, so non-UI layers can read paths without pulling in screens

/// Canonical location strings for the app's named routes.
///
/// These used to live as `static const path` members on the screen widgets
/// themselves, which forced anything that needed a path — including the route
/// parser in `page_context_provider.dart` — to import 57 screens, and through
/// them the `app_providers` barrel. Keeping the strings here instead lets the
/// parser, and the providers that watch it, stay free of UI imports.
///
/// Screens still expose their own `path` members as thin delegates to these
/// values, so existing `SomeScreen.path` call sites are unaffected.
abstract final class RoutePaths {
  static const accountDeletionRecovery = '/account-deletion-recovery';
  static const appLanguage = '/app-language';
  static const appearanceSettings = '/appearance-settings';
  static const appsDirectory = '/apps';
  static const badges = '/badges';
  static const blossomSettings = '/blossom-settings';
  static const blueskySettings = '/bluesky-settings';
  static const clipRecovery = '/clip-recovery';
  static const contentFilters = '/content-filters';
  static const contentPreferences = '/content-preferences';
  static const createPeopleList = '/people-lists/new';
  static const creatorAnalytics = '/creator-analytics';
  static const crosspostingSettings = '/crossposting-settings';
  static const curatedListFeedBase = '/list';
  static const developerOptions = '/developer-options';
  static const discoverLists = '/discover-lists';
  static const emailVerification = '/verify-email';
  static const explore = '/explore';
  static const followersBase = '/followers';
  static const followingBase = '/following';
  static const followingNew = '/following/new';
  static const generalSettings = '/general-settings';
  static const hashtagBase = '/hashtag';
  static const inbox = '/inbox';
  static const invites = '/invites';
  static const keyImport = '/import-key';
  static const keyManagement = '/key-management';
  static const legal = '/legal';
  static const libraryClips = '/clips';
  static const libraryClipsOnly = '/clips-only';
  static const libraryDrafts = '/drafts';
  static const likedVideos = '/liked-videos';
  static const messageRequests = '/inbox/message-requests';
  static const minorAccountReview = '/account-review';
  static const monetizationLinksSettings = '/settings/monetization-links';
  static const monetizationLinksSettingsSubpath = 'monetization-links';
  static const nip05Settings = '/nostr-settings/$nip05SettingsSubpath';
  static const nip05SettingsSubpath = 'nip05';
  static const nostrConnect = '/nostr-connect';
  static const nostrSettings = '/nostr-settings';
  static const notificationSettings = '/notification-settings';
  static const notifications = '/notifications';
  static const originalSoundDetailBase = '/original-sound';
  static const otherProfile = '/profile-view';
  static const pooledFullscreenVideoFeed = '/pooled-video-feed';
  static const privacySettings = '/settings/privacy';
  static const profile = '/profile';
  static const profileSetupEdit = '/edit-profile';
  static const relayDiagnostic = '/relay-diagnostic';
  static const relaySettings = '/relay-settings';
  static const resetPassword = '/reset-password';
  static const safetySettings = '/safety-settings';
  static const secureAccount = '/secure-account';
  static const settings = '/settings';
  static const soundDetailBase = '/sound';
  static const storageManagement = '/storage-management';
  static const subtitleEditor = '/subtitle-edit';
  static const accountStatus = '/settings/account-status';
  static const accountStatusSubpath = 'account-status';
  static const supportCenter = '/support-center';
  static const supportReportBug = '/support-center/report-bug';
  static const videoDetailBase = '/video';
  static const videoEditor = '/video-editor';
  static const videoMetadata = '/video-metadata';
  static const videoMetadataEdit = '/video-edit';
  static const videoRecorder = '/video-recorder';
  static const welcome = '/welcome';
  static const welcomeLoginOptions = '/welcome/login-options';
  static const welcomeResetPassword = '$welcomeLoginOptions/reset-password';

  static String appDetailForSlug(String slug) => '$appsDirectory/$slug';
  static String categoryGalleryFor(String categoryName) {
    return '/categories/${Uri.encodeComponent(categoryName)}';
  }

  static String conversationForId(String id) => '$inbox/conversation/$id';
  static String curatedListByAuthorFor({
    required String pubkey,
    required String listId,
  }) {
    return '$curatedListFeedBase/${Uri.encodeComponent(pubkey)}'
        '/${Uri.encodeComponent(listId)}';
  }

  static String curatedListFeedForId(String listId) {
    final encodedId = Uri.encodeComponent(listId);
    return '$curatedListFeedBase/$encodedId';
  }

  static String exploreForIndex(int? index) =>
      index == null ? explore : '$explore/$index';
  static String followersForPubkey(String pubkey) => '$followersBase/$pubkey';
  static String followingForPubkey(String pubkey) => '$followingBase/$pubkey';
  static String hashtagForTag(String tag) {
    final encodedTag = Uri.encodeComponent(tag);
    return '$hashtagBase/$encodedTag';
  }

  static String likedVideosForIndex(int? index) =>
      index == null ? likedVideos : '$likedVideos/$index';
  static String notificationsForIndex([int? index]) =>
      index == null ? notifications : '$notifications/$index';
  static String originalSoundDetailForPubkey(String pubkey) =>
      '$originalSoundDetailBase/$pubkey';
  static String otherProfileForNpub(String npub) => '$otherProfile/$npub';
  static String profileForIndex(String npub, int index) =>
      '$profile/$npub/$index';
  static String profileForNpub(String npub) => '$profile/$npub';
  static String soundDetailForId(String id) => '$soundDetailBase/$id';
  static String subtitleEditorFor(String videoId) =>
      '$subtitleEditor/${Uri.encodeComponent(videoId)}';
  static String videoDetailForId(String id) => '$videoDetailBase/$id';
  static String videoFeedForIndex(int index) => '/home/$index';
  static String videoMetadataEditFor(String videoId) =>
      '$videoMetadataEdit/${Uri.encodeComponent(videoId)}';
}
