// ABOUTME: Pins every route location string that moved into RoutePaths
// ABOUTME: These are a deep-link contract — a silent change breaks live links

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/router/route_paths.dart';

void main() {
  group(RoutePaths, () {
    // Expected values were read off the screen classes before the locations
    // moved here, so drift in either direction fails these tests.
    test('constants keep the exact locations the screens declared', () {
      expect(RoutePaths.appLanguage, equals('/app-language'));
      expect(RoutePaths.appearanceSettings, equals('/appearance-settings'));
      expect(RoutePaths.appsDirectory, equals('/apps'));
      expect(RoutePaths.badges, equals('/badges'));
      expect(RoutePaths.blossomSettings, equals('/blossom-settings'));
      expect(RoutePaths.blueskySettings, equals('/bluesky-settings'));
      expect(RoutePaths.contentFilters, equals('/content-filters'));
      expect(RoutePaths.contentPreferences, equals('/content-preferences'));
      expect(RoutePaths.createPeopleList, equals('/people-lists/new'));
      expect(RoutePaths.creatorAnalytics, equals('/creator-analytics'));
      expect(RoutePaths.crosspostingSettings, equals('/crossposting-settings'));
      expect(RoutePaths.curatedListFeedBase, equals('/list'));
      expect(RoutePaths.developerOptions, equals('/developer-options'));
      expect(RoutePaths.discoverLists, equals('/discover-lists'));
      expect(RoutePaths.emailVerification, equals('/verify-email'));
      expect(RoutePaths.explore, equals('/explore'));
      expect(RoutePaths.followersBase, equals('/followers'));
      expect(RoutePaths.followingBase, equals('/following'));
      expect(RoutePaths.followingNew, equals('/following/new'));
      expect(RoutePaths.generalSettings, equals('/general-settings'));
      expect(RoutePaths.hashtagBase, equals('/hashtag'));
      expect(RoutePaths.inbox, equals('/inbox'));
      expect(RoutePaths.invites, equals('/invites'));
      expect(RoutePaths.keyImport, equals('/import-key'));
      expect(RoutePaths.keyManagement, equals('/key-management'));
      expect(RoutePaths.legal, equals('/legal'));
      expect(RoutePaths.libraryClips, equals('/clips'));
      expect(RoutePaths.libraryClipsOnly, equals('/clips-only'));
      expect(RoutePaths.libraryDrafts, equals('/drafts'));
      expect(RoutePaths.likedVideos, equals('/liked-videos'));
      expect(RoutePaths.messageRequests, equals('/inbox/message-requests'));
      expect(RoutePaths.minorAccountReview, equals('/account-review'));
      expect(
        RoutePaths.monetizationLinksSettings,
        equals('/settings/monetization-links'),
      );
      expect(
        RoutePaths.monetizationLinksSettingsSubpath,
        equals('monetization-links'),
      );
      expect(RoutePaths.nip05Settings, equals('/nostr-settings/nip05'));
      expect(RoutePaths.nip05SettingsSubpath, equals('nip05'));
      expect(RoutePaths.nostrConnect, equals('/nostr-connect'));
      expect(RoutePaths.nostrSettings, equals('/nostr-settings'));
      expect(RoutePaths.notificationSettings, equals('/notification-settings'));
      expect(RoutePaths.notifications, equals('/notifications'));
      expect(RoutePaths.originalSoundDetailBase, equals('/original-sound'));
      expect(RoutePaths.otherProfile, equals('/profile-view'));
      expect(
        RoutePaths.pooledFullscreenVideoFeed,
        equals('/pooled-video-feed'),
      );
      expect(RoutePaths.privacySettings, equals('/settings/privacy'));
      expect(RoutePaths.profile, equals('/profile'));
      expect(RoutePaths.profileSetupEdit, equals('/edit-profile'));
      expect(RoutePaths.relayDiagnostic, equals('/relay-diagnostic'));
      expect(RoutePaths.relaySettings, equals('/relay-settings'));
      expect(RoutePaths.resetPassword, equals('/reset-password'));
      expect(RoutePaths.safetySettings, equals('/safety-settings'));
      expect(RoutePaths.secureAccount, equals('/secure-account'));
      expect(RoutePaths.settings, equals('/settings'));
      expect(RoutePaths.soundDetailBase, equals('/sound'));
      expect(RoutePaths.storageManagement, equals('/storage-management'));
      expect(RoutePaths.subtitleEditor, equals('/subtitle-edit'));
      expect(RoutePaths.supportCenter, equals('/support-center'));
      expect(RoutePaths.videoDetailBase, equals('/video'));
      expect(RoutePaths.videoEditor, equals('/video-editor'));
      expect(RoutePaths.videoMetadata, equals('/video-metadata'));
      expect(RoutePaths.videoMetadataEdit, equals('/video-edit'));
      expect(RoutePaths.videoRecorder, equals('/video-recorder'));
      expect(RoutePaths.welcome, equals('/welcome'));
      expect(RoutePaths.welcomeLoginOptions, equals('/welcome/login-options'));
      expect(
        RoutePaths.welcomeResetPassword,
        equals('/welcome/login-options/reset-password'),
      );
    });

    test('builders compose the same locations they did on the screens', () {
      expect(RoutePaths.appDetailForSlug('divine'), equals('/apps/divine'));
      expect(
        RoutePaths.categoryGalleryFor('Wild Life'),
        equals('/categories/Wild%20Life'),
      );
      expect(
        RoutePaths.conversationForId('abc'),
        equals('/inbox/conversation/abc'),
      );
      expect(
        RoutePaths.curatedListByAuthorFor(pubkey: 'pk', listId: 'my list'),
        equals('/list/pk/my%20list'),
      );
      expect(RoutePaths.curatedListFeedForId('a/b'), equals('/list/a%2Fb'));
      expect(RoutePaths.exploreForIndex(null), equals('/explore'));
      expect(RoutePaths.exploreForIndex(3), equals('/explore/3'));
      expect(RoutePaths.followersForPubkey('pk'), equals('/followers/pk'));
      expect(RoutePaths.followingForPubkey('pk'), equals('/following/pk'));
      expect(RoutePaths.hashtagForTag('a b'), equals('/hashtag/a%20b'));
      expect(RoutePaths.likedVideosForIndex(null), equals('/liked-videos'));
      expect(RoutePaths.likedVideosForIndex(2), equals('/liked-videos/2'));
      expect(RoutePaths.notificationsForIndex(), equals('/notifications'));
      expect(RoutePaths.notificationsForIndex(1), equals('/notifications/1'));
      expect(
        RoutePaths.originalSoundDetailForPubkey('pk'),
        equals('/original-sound/pk'),
      );
      expect(
        RoutePaths.otherProfileForNpub('npub1x'),
        equals('/profile-view/npub1x'),
      );
      expect(
        RoutePaths.profileForIndex('npub1x', 4),
        equals('/profile/npub1x/4'),
      );
      expect(RoutePaths.profileForNpub('npub1x'), equals('/profile/npub1x'));
      expect(RoutePaths.soundDetailForId('s1'), equals('/sound/s1'));
      expect(
        RoutePaths.subtitleEditorFor('v 1'),
        equals('/subtitle-edit/v%201'),
      );
      expect(RoutePaths.videoDetailForId('v1'), equals('/video/v1'));
      expect(RoutePaths.videoFeedForIndex(7), equals('/home/7'));
      expect(
        RoutePaths.videoMetadataEditFor('v 1'),
        equals('/video-edit/v%201'),
      );
    });
  });
}
