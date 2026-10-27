// ABOUTME: Checks every RoutePaths location against the app's real route table
// ABOUTME: A location that drifts from its route pattern otherwise fails silently

import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/auth/welcome_screen.dart';
import 'package:openvine/utils/nostr_key_utils.dart';

import '../helpers/test_provider_overrides.dart';

const _eventId =
    '1111111111111111111111111111111111111111111111111111111111111111';
const _pubkeyHex =
    '2222222222222222222222222222222222222222222222222222222222222222';
const _conversationId =
    '3333333333333333333333333333333333333333333333333333333333333333';
const _listId = 'weekend-picks';
const _announcementId = 'cc3897b7-a83f-4d9f-9ce4-a7daa7c07a63';
final String _npub = NostrKeyUtils.encodePubKey(_pubkeyHex);

/// Every location a [RoutePaths] member produces, keyed by the member's name.
final _locations = <String, List<String>>{
  'accountDeletionRecovery': [RoutePaths.accountDeletionRecovery],
  'accountStatus': [RoutePaths.accountStatus],
  'addSound': [RoutePaths.addSound],
  'appLanguage': [RoutePaths.appLanguage],
  'appearanceSettings': [RoutePaths.appearanceSettings],
  'appsDirectory': [RoutePaths.appsDirectory],
  'badges': [RoutePaths.badges],
  'blossomSettings': [RoutePaths.blossomSettings],
  'blueskySettings': [RoutePaths.blueskySettings],
  'chat': [RoutePaths.chat],
  'clipRecovery': [RoutePaths.clipRecovery],
  'contentFilters': [RoutePaths.contentFilters],
  'contentPreferences': [RoutePaths.contentPreferences],
  'createPeopleList': [RoutePaths.createPeopleList],
  'creatorAnalytics': [RoutePaths.creatorAnalytics],
  'crosspostingSettings': [RoutePaths.crosspostingSettings],
  'developerOptions': [RoutePaths.developerOptions],
  'discoverLists': [RoutePaths.discoverLists],
  'emailVerification': [RoutePaths.emailVerification],
  'explore': [RoutePaths.explore],
  'followedHashtags': [RoutePaths.followedHashtags],
  'followingNew': [RoutePaths.followingNew],
  'generalSettings': [RoutePaths.generalSettings],
  'inbox': [RoutePaths.inbox],
  'keyImport': [RoutePaths.keyImport],
  'keyManagement': [RoutePaths.keyManagement],
  'legal': [RoutePaths.legal],
  'libraryClips': [RoutePaths.libraryClips],
  'libraryClipsOnly': [RoutePaths.libraryClipsOnly],
  'libraryDrafts': [RoutePaths.libraryDrafts],
  'librarySounds': [RoutePaths.librarySounds],
  'likedVideos': [RoutePaths.likedVideos],
  'messageRequests': [RoutePaths.messageRequests],
  'minorAccountReview': [RoutePaths.minorAccountReview],
  'monetizationLinksSettings': [RoutePaths.monetizationLinksSettings],
  'nip05Settings': [RoutePaths.nip05Settings],
  'nostrConnect': [RoutePaths.nostrConnect],
  'nostrSettings': [RoutePaths.nostrSettings],
  'notificationSettings': [RoutePaths.notificationSettings],
  'pooledFullscreenVideoFeed': [RoutePaths.pooledFullscreenVideoFeed],
  'privacySettings': [RoutePaths.privacySettings],
  'profile': [RoutePaths.profile],
  'profileSetupEdit': [RoutePaths.profileSetupEdit],
  'relayDiagnostic': [RoutePaths.relayDiagnostic],
  'relaySettings': [RoutePaths.relaySettings],
  'resetPassword': [RoutePaths.resetPassword],
  'safetySettings': [RoutePaths.safetySettings],
  'secureAccount': [RoutePaths.secureAccount],
  'settings': [RoutePaths.settings],
  'settingsAccount': [RoutePaths.settingsAccount],
  'settingsAppPreferences': [RoutePaths.settingsAppPreferences],
  'settingsConnections': [RoutePaths.settingsConnections],
  'settingsCreating': [RoutePaths.settingsCreating],
  'settingsHelpAbout': [RoutePaths.settingsHelpAbout],
  'settingsNostrNetwork': [RoutePaths.settingsNostrNetwork],
  'settingsViewing': [RoutePaths.settingsViewing],
  'storageManagement': [RoutePaths.storageManagement],
  'supportCenter': [RoutePaths.supportCenter],
  'supportReportBug': [RoutePaths.supportReportBug],
  'videoEditor': [RoutePaths.videoEditor],
  'videoMetadata': [RoutePaths.videoMetadata],
  'videoRecorder': [RoutePaths.videoRecorder],
  'welcome': [RoutePaths.welcome],
  'welcomeLoginOptions': [RoutePaths.welcomeLoginOptions],
  'welcomeResetPassword': [RoutePaths.welcomeResetPassword],
  'announcementDetailForId': [
    RoutePaths.announcementDetailForId(_announcementId),
  ],
  'appDetailForSlug': [RoutePaths.appDetailForSlug('sample-app')],
  'categoryGalleryFor': [RoutePaths.categoryGalleryFor('Wild Life')],
  'conversationForId': [RoutePaths.conversationForId(_conversationId)],
  'curatedListByAuthorFor': [
    RoutePaths.curatedListByAuthorFor(pubkey: _pubkeyHex, listId: _listId),
  ],
  'curatedListFeedForId': [RoutePaths.curatedListFeedForId(_listId)],
  'exploreForIndex': [
    RoutePaths.exploreForIndex(null),
    RoutePaths.exploreForIndex(3),
  ],
  'followersForPubkey': [RoutePaths.followersForPubkey(_pubkeyHex)],
  'followingForPubkey': [RoutePaths.followingForPubkey(_pubkeyHex)],
  'hashtagForTag': [RoutePaths.hashtagForTag('music')],
  'likedVideosForIndex': [
    RoutePaths.likedVideosForIndex(null),
    RoutePaths.likedVideosForIndex(2),
  ],
  // Without an index this returns `notifications`, excluded below.
  'notificationsForIndex': [RoutePaths.notificationsForIndex(1)],
  'originalSoundDetailForPubkey': [
    RoutePaths.originalSoundDetailForPubkey(_pubkeyHex),
  ],
  'otherProfileForNpub': [RoutePaths.otherProfileForNpub(_npub)],
  'peopleListAddPeopleForId': [RoutePaths.peopleListAddPeopleForId(_listId)],
  'peopleListEditForId': [RoutePaths.peopleListEditForId(_listId)],
  'peopleListForId': [
    RoutePaths.peopleListForId(_listId),
    RoutePaths.peopleListForId(_listId, ownerPubkey: _pubkeyHex),
  ],
  'peopleListMembersForId': [
    RoutePaths.peopleListMembersForId(_listId),
    RoutePaths.peopleListMembersForId(_listId, ownerPubkey: _pubkeyHex),
  ],
  'profileForIndex': [RoutePaths.profileForIndex(_npub, 4)],
  'profileForNpub': [RoutePaths.profileForNpub(_npub)],
  'profileUnavailablePinsForNpub': [
    RoutePaths.profileUnavailablePinsForNpub(_npub),
  ],
  'shortLinkForCode': [RoutePaths.shortLinkForCode('Abc12345')],
  'soundDetailForId': [RoutePaths.soundDetailForId(_eventId)],
  'subtitleEditorFor': [RoutePaths.subtitleEditorFor(_eventId)],
  'videoDetailForId': [RoutePaths.videoDetailForId(_eventId)],
  'videoFeedForIndex': [RoutePaths.videoFeedForIndex(0)],
  'videoMetadataEditFor': [RoutePaths.videoMetadataEditFor(_eventId)],
};

/// [RoutePaths] members that are not a whole location on their own.
const _notLocations = {
  // Prefixes the builders extend. No route is registered at the bare prefix.
  'announcementDetailBase',
  'curatedListFeedBase',
  'followersBase',
  'followingBase',
  'hashtagBase',
  'originalSoundDetailBase',
  'otherProfile',
  'soundDetailBase',
  'subtitleEditor',
  'videoDetailBase',
  'videoMetadataEdit',
  // Child-route segments, registered relative to their parent route.
  'accountStatusSubpath',
  'addSoundSubpath',
  'monetizationLinksSettingsSubpath',
  'nip05SettingsSubpath',
  // The literal subject segment of followingNew, which is checked itself.
  'followingNewSubject',
  // A route pattern with an :npub placeholder; its builder is checked instead.
  'profileUnavailablePins',
  // Alias route pattern; the complete shortLinkForCode location is checked above.
  'shortLink',
  // Web and Share addresses. No route is registered at them: the deep-link
  // service maps them onto an in-app location (peopleListForId with an
  // owner query), which is checked itself.
  'peopleListByAuthorFor',
  // Not registered. The redirect and route normalizer rewrite them: `root`
  // to welcome or the home feed, `notifications` to /notifications/0.
  'notifications',
  'root',
};

void main() {
  group('registered route locations', () {
    late RouteConfiguration routes;

    setUp(() {
      final container = ProviderContainer(
        overrides: getStandardTestOverrides(),
      );
      addTearDown(container.dispose);
      routes = container.read(goRouterProvider).configuration;
    });

    bool isRegistered(String location) =>
        !routes.findMatch(Uri.parse(location)).isError;

    test('classifies every $RoutePaths member exactly once', () {
      final members = _routePathsMembers();
      final classified = {..._locations.keys, ..._notLocations};

      expect(
        members.difference(classified),
        isEmpty,
        reason:
            'Add each new member to _locations, or to _notLocations with the '
            'reason it is not a whole location.',
      );
      expect(
        classified.difference(members),
        isEmpty,
        reason: 'These names are no longer $RoutePaths members.',
      );
      expect(_locations.keys.toSet().intersection(_notLocations), isEmpty);
    });

    test('every $RoutePaths location matches a registered route', () {
      final unmatched = [
        for (final MapEntry(key: member, value: locations)
            in _locations.entries)
          for (final location in locations)
            if (!isRegistered(location)) '$member: $location',
      ];

      expect(unmatched, isEmpty);
    });

    // A screen that still declares its own location outside RoutePaths is
    // migration debt (#3572): nothing else ties it to a registered route.
    test('$WelcomeScreen.createAccountPath matches a registered route', () {
      expect(isRegistered(WelcomeScreen.createAccountPath), isTrue);
    });
  });
}

/// The name of every static member [RoutePaths] declares, read from its
/// source so a new constant or builder cannot skip the tables above.
Set<String> _routePathsMembers() {
  final unit = parseString(
    content: File('lib/router/route_paths.dart').readAsStringSync(),
    featureSet: FeatureSet.latestLanguageVersion(),
  ).unit;
  final routePaths = unit.declarations
      .whereType<ClassDeclaration>()
      .singleWhere(
        (declaration) => declaration.namePart.typeName.lexeme == '$RoutePaths',
      );
  return {
    for (final member in routePaths.body.members)
      if (member is FieldDeclaration && member.isStatic)
        for (final variable in member.fields.variables) variable.name.lexeme
      else if (member is MethodDeclaration && member.isStatic)
        member.name.lexeme,
  };
}
