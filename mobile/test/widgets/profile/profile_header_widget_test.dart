// ABOUTME: Tests for ProfileHeaderWidget
// ABOUTME: Verifies profile header displays avatar, stats, name, bio, and npub correctly

import 'dart:async';
import 'dart:convert';

import 'package:badge_repository/badge_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:cache_sync/cache_sync.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/blocs/background_publish/background_publish_bloc.dart';
import 'package:openvine/blocs/my_profile/my_profile_bloc.dart';
import 'package:openvine/blocs/others_followers/others_followers_bloc.dart';
import 'package:openvine/config/official_accounts.dart';
import 'package:openvine/config/profile_metrics.dart';
import 'package:openvine/constants/og_beta_testers.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/features/monetization/monetization_storefront_policy.dart';
import 'package:openvine/features/people_lists/bloc/people_lists_bloc.dart';
import 'package:openvine/features/people_lists/view/people_list_membership_indicator.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/providers/account_enforcement_providers.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/screens/badges/badge_editor_screen.dart';
import 'package:openvine/screens/badges/badges_screen.dart';
import 'package:openvine/screens/other_profile_screen.dart';
import 'package:openvine/services/auth_service.dart' hide UserProfile;
import 'package:openvine/services/og_viner_cache_service.dart';
import 'package:openvine/utils/divine_login_banner_dismissal.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/utils/secure_account_prompt_dismissal.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/og_beta_badge.dart';
import 'package:openvine/widgets/og_viner_badge.dart';
import 'package:openvine/widgets/profile/profile_action_buttons_widget.dart';
import 'package:openvine/widgets/profile/profile_actions_sheet/profile_actions_sheet.dart';
import 'package:openvine/widgets/profile/profile_header_widget.dart';
import 'package:openvine/widgets/profile/profile_stats_row_widget.dart';
import 'package:openvine/widgets/profile/profile_website_row.dart';
import 'package:openvine/widgets/special_profile_checkmark.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:openvine/widgets/user_profile_tile.dart';
import 'package:openvine/widgets/vine_cached_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../helpers/finders.dart';
import '../../helpers/go_router.dart';
import '../../helpers/test_provider_overrides.dart';
import '../../helpers/test_pubkeys.dart';

class _MockMyProfileBloc extends MockBloc<MyProfileEvent, MyProfileState>
    implements MyProfileBloc {}

class _MockOthersFollowersBloc
    extends MockBloc<OthersFollowersEvent, OthersFollowersState>
    implements OthersFollowersBloc {}

class _MockPeopleListsBloc extends MockBloc<PeopleListsEvent, PeopleListsState>
    implements PeopleListsBloc {}

class _MockBackgroundPublishBloc
    extends MockBloc<BackgroundPublishEvent, BackgroundPublishState>
    implements BackgroundPublishBloc {}

class _MockBadgeRepository extends Mock implements BadgeRepository {}

// Mock classes
class MockFollowRepository extends Mock implements FollowRepository {
  @override
  List<String> get followingPubkeys => [];

  @override
  Stream<List<String>> get followingStream => Stream.value([]);

  @override
  bool get isInitialized => true;

  @override
  int get followingCount => 0;

  @override
  Future<List<String>> getMyFollowers() async => [];

  @override
  Future<List<String>> getFollowers(String pubkey) async => [];

  @override
  bool isFollowing(String pubkey) => false;

  @override
  Stream<FollowersSnapshot> watchMyFollowers() {
    return Stream.value(const FollowersSnapshot(pubkeys: <String>[], count: 0));
  }

  @override
  Stream<CacheResult<FollowingSnapshot>> watchMyFollowingCached({
    bool forceRefresh = false,
  }) {
    return Stream.value(
      const CacheResult.live(FollowingSnapshot(pubkeys: <String>[], count: 0)),
    );
  }

  @override
  Future<int> getMyFollowerCount() async => 0;

  @override
  Future<int> getFollowerCount(String pubkey) async => 0;
}

class MockNostrClient extends Mock implements NostrClient {
  MockNostrClient({this.testPublicKey = testUserHex});

  final String testPublicKey;

  @override
  bool get hasKeys => true;

  @override
  String get publicKey => testPublicKey;

  @override
  bool get isInitialized => true;

  @override
  int get connectedRelayCount => 1;
}

class _FakeCacheDao implements CacheDao {
  @override
  Future<String?> read(String key) async => null;

  @override
  Future<void> write({
    required String key,
    required String payload,
    Duration? ttl,
  }) async {}

  @override
  Future<void> delete(String key) async {}

  @override
  Future<void> deletePrefix(String prefix) async {}

  @override
  Future<int> totalPayloadBytes() async => 0;

  @override
  Future<void> evictOldest(int bytesToFree) async {}
}

class MockAuthService extends Mock implements AuthService {
  MockAuthService({
    this.isAnonymousValue = false,
    this.hasExpiredOAuthSessionValue = false,
    this.isRpcUpgradeInProgressValue = false,
    this.tryRefreshResult = false,
  });

  final bool isAnonymousValue;
  final bool hasExpiredOAuthSessionValue;
  final bool isRpcUpgradeInProgressValue;
  final bool tryRefreshResult;

  /// Number of times [tryRefreshExpiredSession] was called. The override below
  /// bypasses `noSuchMethod`, so mocktail's `verify` cannot see these calls.
  int tryRefreshCallCount = 0;

  @override
  bool get isAnonymous => isAnonymousValue;

  @override
  bool get isAuthenticated => true;

  @override
  String? get currentPublicKeyHex => testUserHex;

  @override
  Stream<AuthState> get authStateStream =>
      Stream.value(AuthState.authenticated);

  @override
  bool get hasExpiredOAuthSession => hasExpiredOAuthSessionValue;

  @override
  bool get isRpcUpgradeInProgress => isRpcUpgradeInProgressValue;

  @override
  Future<bool> tryRefreshExpiredSession() async {
    tryRefreshCallCount++;
    return tryRefreshResult;
  }
}

const String testUserHex = syntheticTestPubkey;
const issuerUserHex =
    '4f071cf08328c9d9dbb21f5d9d1e51fe2ecf4e7de5a4e59ecdf356f6a6f49f22';
const recipientUserHex =
    '4ac3abe4d7c0bdfb3e5f2f904f4c7e7f60cd4b4ebe1f8b6eea9e969fbac0b7aa';
final String _dismissedDivineLoginBannerKey =
    DivineLoginBannerDismissalStore.keyFor(testUserHex);

/// Minimal fake [DivineVideoDraft] for use in [BackgroundUpload] test fixtures.
class _FakeDraft extends Fake implements DivineVideoDraft {
  @override
  String get id => 'fake-draft-id';
}

Event _badgeDefinitionEvent() {
  return Event.fromJson({
    'id': '00000000000000000000000000000000000000000000000000000000000000bb',
    'pubkey': issuerUserHex,
    'created_at': 1000,
    'kind': EventKind.badgeDefinition,
    'tags': [
      ['d', 'daily-diviner'],
      ['name', 'Diviner of the Day'],
    ],
    'content': '',
    'sig': '',
  });
}

Event _badgeAwardEvent() {
  return Event.fromJson({
    'id': '00000000000000000000000000000000000000000000000000000000000000aa',
    'pubkey': issuerUserHex,
    'created_at': 1001,
    'kind': EventKind.badgeAward,
    'tags': [
      ['a', '30009:$issuerUserHex:daily-diviner'],
      ['p', testUserHex],
      ['p', recipientUserHex],
    ],
    'content': '',
    'sig': '',
  });
}

ProfileBadgeViewData _acceptedBadge(String name, String dTag) {
  final coordinate = '30009:$issuerUserHex:$dTag';
  return ProfileBadgeViewData(
    badge: Nip58ProfileBadgeRef(
      definitionCoordinate: coordinate,
      awardEventId:
          '00000000000000000000000000000000000000000000000000000000000000aa',
    ),
    award: Nip58BadgeAward(
      event: _badgeAwardEvent(),
      definitionCoordinate: coordinate,
      recipientPubkeys: const [testUserHex],
    ),
    definition: Nip58BadgeDefinition(
      event: _badgeDefinitionEvent(),
      coordinate: coordinate,
      dTag: dTag,
      name: name,
    ),
  );
}

void main() {
  group('ProfileHeaderWidget', () {
    late MockFollowRepository mockFollowRepository;
    late MockNostrClient mockNostrClient;

    UserProfile createTestProfile({
      String? displayName,
      String? name,
      String? about,
      String? picture,
      String? nip05,
      String? website,
      Map<String, dynamic> rawData = const {},
      DateTime? createdAt,
      String eventId = 'test-event',
      String pubkey = testUserHex,
    }) {
      return UserProfile(
        pubkey: pubkey,
        rawData: {
          'display_name': ?displayName,
          'name': ?name,
          'about': ?about,
          'picture': ?picture,
          'nip05': ?nip05,
          'website': ?website,
          ...rawData,
        },
        displayName: displayName,
        name: name,
        about: about,
        picture: picture,
        nip05: nip05,
        website: website,
        createdAt: createdAt ?? DateTime.now(),
        eventId: eventId,
      );
    }

    setUp(() async {
      mockFollowRepository = MockFollowRepository();
      mockNostrClient = MockNostrClient();
      await CacheSync.init(dao: _FakeCacheDao());
    });

    tearDown(() {
      debugUsesAppleAppStoreTipPolicyOverride = null;
    });

    setUpAll(() async {
      SharedPreferences.setMockInitialValues({});
    });

    final enL10n = lookupAppLocalizations(const Locale('en'));

    Widget buildTestWidget({
      required String userIdHex,
      required bool isOwnProfile,
      int videoCount = 10,
      UserProfile? profile,
      UserProfile? suppliedProfile,
      ProfileStats? profileStats,
      bool profileIsLoading = false,
      bool isAnonymous = false,
      bool isAccountEnforced = false,
      VoidCallback? onEnforcementRead,
      bool hasExpiredSession = false,
      bool isRpcUpgradeInProgress = false,
      bool tryRefreshResult = false,
      SharedPreferences? sharedPreferences,
      String? displayNameHint,
      String? avatarUrlHint,
      MyProfileState? myProfileState,
      bool provideMyProfileBloc = true,
      bool curatedListsEnabled = false,
      PeopleListsState? peopleListsState,
      BackgroundPublishState? backgroundPublishState,
      Stream<BackgroundPublishState>? backgroundPublishStream,
      List<ProfileBadgeViewData> acceptedProfileBadges = const [],
      MockGoRouter? goRouter,
      bool monetizationLinksEnabled = false,
      ThemeData? theme,
      bool disableAnimations = false,
      TextScaler? textScaler,
      Locale locale = const Locale('en'),
      bool renderHeader = true,
      MockAuthService? authService,
      bool isVanished = false,
    }) {
      // Pass authService when the test needs the same instance across pumps —
      // e.g. to read tryRefreshCallCount after the header has been unmounted.
      final effectiveAuthService =
          authService ??
          MockAuthService(
            isAnonymousValue: isAnonymous,
            hasExpiredOAuthSessionValue: hasExpiredSession,
            isRpcUpgradeInProgressValue: isRpcUpgradeInProgress,
            tryRefreshResult: tryRefreshResult,
          );

      final mockPublishBloc = _MockBackgroundPublishBloc();
      final publishState =
          backgroundPublishState ?? const BackgroundPublishState();
      when(() => mockPublishBloc.state).thenReturn(publishState);
      whenListen(
        mockPublishBloc,
        backgroundPublishStream ?? const Stream<BackgroundPublishState>.empty(),
        initialState: publishState,
      );
      final badgeRepository = _MockBadgeRepository();
      when(
        () => badgeRepository.loadAcceptedBadgesForProfile(any()),
      ).thenAnswer((_) async => acceptedProfileBadges);

      // renderHeader: false keeps the surrounding tree (and any route already
      // pushed on the navigator) intact while the header itself unmounts.
      Widget header = renderHeader
          ? ProfileHeaderWidget(
              userIdHex: userIdHex,
              isOwnProfile: isOwnProfile,
              videoCount: videoCount,
              profile: suppliedProfile,
              profileStats: profileStats,
              displayNameHint: displayNameHint,
              avatarUrlHint: avatarUrlHint,
            )
          : const SizedBox.shrink();

      if (isOwnProfile) {
        if (provideMyProfileBloc) {
          final mockMyProfileBloc = _MockMyProfileBloc();
          final state =
              myProfileState ??
              (profile != null
                  ? MyProfileUpdated(profile: profile)
                  : const MyProfileInitial());
          when(() => mockMyProfileBloc.state).thenReturn(state);
          header = BlocProvider<MyProfileBloc>.value(
            value: mockMyProfileBloc,
            child: header,
          );
        }
        // When provideMyProfileBloc is false, the header is rendered without a
        // MyProfileBloc ancestor — the cold-start pre-scope window where
        // profileRepository isn't ready yet.
      } else {
        final mockOthersFollowersBloc = _MockOthersFollowersBloc();
        when(
          () => mockOthersFollowersBloc.state,
        ).thenReturn(const OthersFollowersState());
        final mockPeopleListsBloc = _MockPeopleListsBloc();
        whenListen(
          mockPeopleListsBloc,
          const Stream<PeopleListsState>.empty(),
          initialState: peopleListsState ?? const PeopleListsState(),
        );
        header = MultiBlocProvider(
          providers: [
            BlocProvider<OthersFollowersBloc>.value(
              value: mockOthersFollowersBloc,
            ),
            BlocProvider<PeopleListsBloc>.value(value: mockPeopleListsBloc),
          ],
          child: header,
        );
      }

      // Wrap with BackgroundPublishBloc — available everywhere in the real app
      // tree and required by the session-expired nav deferral logic.
      header = BlocProvider<BackgroundPublishBloc>.value(
        value: mockPublishBloc,
        child: header,
      );

      final scoped = ProviderScope(
        overrides: [
          ...getStandardTestOverrides(
            mockNostrService: mockNostrClient,
            mockSharedPreferences: sharedPreferences,
            mockNip05VerificationService: createMockNip05VerificationService(),
            mockFollowRepository: mockFollowRepository,
          ),
          profileVanishedProvider(userIdHex).overrideWith((ref) => isVanished),
          fetchUserProfileProvider(userIdHex).overrideWith(
            profileIsLoading
                ? (ref) => Completer<UserProfile?>().future
                : (ref) async => profile,
          ),
          userProfileStatsReactiveProvider(userIdHex).overrideWith(
            (ref) => profileStats != null
                ? Stream.value(profileStats)
                : const Stream<ProfileStats?>.empty(),
          ),
          authServiceProvider.overrideWithValue(effectiveAuthService),
          isAccountEnforcedProvider.overrideWith((ref) {
            onEnforcementRead?.call();
            return isAccountEnforced;
          }),
          badgeRepositoryProvider.overrideWithValue(badgeRepository),
          currentAuthStateProvider.overrideWith(
            (ref) => AuthState.authenticated,
          ),
          isFeatureEnabledProvider(
            FeatureFlag.curatedLists,
          ).overrideWith((ref) => curatedListsEnabled),
          isFeatureEnabledProvider(
            FeatureFlag.profileMonetizationLinks,
          ).overrideWith((ref) => monetizationLinksEnabled),
        ],
        child: MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: locale,
          theme: theme,
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                disableAnimations: disableAnimations,
                textScaler: textScaler ?? MediaQuery.textScalerOf(context),
              ),
              child: Scaffold(body: SingleChildScrollView(child: header)),
            ),
          ),
        ),
      );

      return goRouter == null
          ? scoped
          : MockGoRouterProvider(goRouter: goRouter, child: scoped);
    }

    testWidgets('opens accepted NIP-58 badge details from profile header', (
      tester,
    ) async {
      final testProfile = createTestProfile(displayName: 'Badged User');
      final mockGoRouter = MockGoRouter();
      when(() => mockGoRouter.push(any())).thenAnswer((_) async => null);

      await tester.pumpWidget(
        buildTestWidget(
          userIdHex: testUserHex,
          isOwnProfile: false,
          suppliedProfile: testProfile,
          goRouter: mockGoRouter,
          acceptedProfileBadges: [
            ProfileBadgeViewData(
              badge: const Nip58ProfileBadgeRef(
                definitionCoordinate: '30009:$issuerUserHex:daily-diviner',
                awardEventId: '00000000000000000000000000000000000000000000000000000000000000aa',
              ),
              award: Nip58BadgeAward(
                event: _badgeAwardEvent(),
                definitionCoordinate: '30009:$issuerUserHex:daily-diviner',
                recipientPubkeys: const [testUserHex, recipientUserHex],
              ),
              definition: Nip58BadgeDefinition(
                event: _badgeDefinitionEvent(),
                coordinate: '30009:$issuerUserHex:daily-diviner',
                dTag: 'daily-diviner',
                name: 'Diviner of the Day',
                description:
                    'A daily badge for people who keep the network weird.',
                thumbnails: const [
                  'https://example.com/daily-diviner-thumb.png',
                ],
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Diviner of the Day'), findsOneWidget);
      expect(
        tester
            .widget<VineCachedImage>(find.byType(VineCachedImage).first)
            .imageUrl,
        'https://example.com/daily-diviner-thumb.png',
      );

      await tester.tap(find.text('Diviner of the Day'));
      await tester.pumpAndSettle();

      expect(
        find.text('A daily badge for people who keep the network weird.'),
        findsOneWidget,
      );
      expect(find.text('Awarded by'), findsOneWidget);
      expect(find.text('Recipients'), findsOneWidget);
      expect(find.byType(UserProfileTile), findsNWidgets(3));

      await tester.tap(find.byType(UserProfileTile).first);
      await tester.pumpAndSettle();

      verify(
        () => mockGoRouter.push(
          OtherProfileScreen.pathForNpub(
            NostrKeyUtils.encodePubKey(issuerUserHex),
          ),
        ),
      ).called(1);
    });

    testWidgets('opens OG Viner explainer from profile header target', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        ogVinerPubkeysCacheKey: jsonEncode([testUserHex]),
      });
      final prefs = await SharedPreferences.getInstance();
      final l10n = lookupAppLocalizations(const Locale('en'));

      await tester.pumpWidget(
        buildTestWidget(
          userIdHex: testUserHex,
          isOwnProfile: false,
          suppliedProfile: createTestProfile(displayName: 'OG User'),
          sharedPreferences: prefs,
        ),
      );
      await tester.pumpAndSettle();

      final button = findByTooltip(l10n.ogVinerBadgeLabel);
      expect(button, findsOneWidget);
      // The header shows the same badge as the feed, glyph and all.
      expect(find.byType(OgVinerBadge), findsOneWidget);
      // The badge must stay a real tap target; the exact box is the design
      // system's to decide, so assert the 48dp floor rather than a number.
      final buttonSize = tester.getSize(button);
      expect(buttonSize.width, greaterThanOrEqualTo(48));
      expect(buttonSize.height, greaterThanOrEqualTo(48));

      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(find.text(l10n.ogVinerBadgeLabel), findsWidgets);
      expect(find.text(l10n.profileBadgeOgVinerBody), findsOneWidget);
      expect(find.text(l10n.commonClose), findsOneWidget);
    });

    testWidgets('opens OG Beta Tester explainer from profile header target', (
      tester,
    ) async {
      final l10n = lookupAppLocalizations(const Locale('en'));
      final rosterPubkey = ogBetaTesterPubkeys.first;

      await tester.pumpWidget(
        buildTestWidget(
          userIdHex: rosterPubkey,
          isOwnProfile: false,
          suppliedProfile: createTestProfile(
            displayName: 'Beta User',
            pubkey: rosterPubkey,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final button = findByTooltip(l10n.ogBetaTesterBadgeLabel);
      expect(button, findsOneWidget);
      expect(find.byType(OgBetaBadge), findsOneWidget);
      // The header is the 48dp-compliant affordance; the inline chit takes a
      // documented exception, so the floor has to hold here.
      final buttonSize = tester.getSize(button);
      expect(buttonSize.width, greaterThanOrEqualTo(48));
      expect(buttonSize.height, greaterThanOrEqualTo(48));

      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(find.text(l10n.profileBadgeOgBetaTesterBody), findsOneWidget);
      expect(find.text(l10n.commonClose), findsOneWidget);
    });

    testWidgets('shows OG Beta Tester for a non-team roster member', (
      tester,
    ) async {
      final pubkey = ogBetaTesterPubkeys.firstWhere(
        (candidate) => !kDivineTeamPubkeys.contains(candidate),
      );
      await tester.pumpWidget(
        buildTestWidget(
          userIdHex: pubkey,
          isOwnProfile: false,
          suppliedProfile: createTestProfile(
            displayName: 'Beta User',
            pubkey: pubkey,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SpecialProfileCheckmark), findsNothing);
      expect(find.byType(OgBetaBadge), findsOneWidget);
    });

    testWidgets('hides the OG Beta Tester chit behind the team checkmark', (
      tester,
    ) async {
      // Many team accounts also appear on the beta roster, so this is the
      // default state rather than an edge case. Without the guard the header
      // renders two explainer buttons side by side.
      final dualPubkey = kDivineTeamPubkeys.firstWhere(isOgBetaTesterPubkey);

      await tester.pumpWidget(
        buildTestWidget(
          userIdHex: dualPubkey,
          isOwnProfile: false,
          suppliedProfile: createTestProfile(
            displayName: 'Team Member',
            pubkey: dualPubkey,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SpecialProfileCheckmark), findsOneWidget);
      expect(find.byType(OgBetaBadge), findsNothing);
    });

    testWidgets('hides the OG Beta Tester chit on a vanished account', (
      tester,
    ) async {
      final rosterPubkey = ogBetaTesterPubkeys.first;

      await tester.pumpWidget(
        buildTestWidget(
          userIdHex: rosterPubkey,
          isOwnProfile: false,
          suppliedProfile: createTestProfile(
            displayName: 'Beta User',
            pubkey: rosterPubkey,
          ),
          isVanished: true,
        ),
      );
      await tester.pumpAndSettle();

      // A vanished account renders profileDeletedAccountName; a chit beside
      // that is incoherent, and the compiled-in roster cannot drop someone
      // who vanishes after release.
      expect(find.byType(OgBetaBadge), findsNothing);
    });

    testWidgets('hides the verified checkmark on a vanished account', (
      tester,
    ) async {
      final teamPubkey = kDivineTeamPubkeys.first;

      await tester.pumpWidget(
        buildTestWidget(
          userIdHex: teamPubkey,
          isOwnProfile: false,
          suppliedProfile: createTestProfile(
            displayName: 'Team Member',
            pubkey: teamPubkey,
          ),
          isVanished: true,
        ),
      );
      await tester.pumpAndSettle();

      // Same reasoning as the OG Beta chit above, and the same kind of
      // roster: `kDivineTeamPubkeys` is compiled in, so it cannot drop a
      // member who vanishes after release.
      expect(find.byType(SpecialProfileCheckmark), findsNothing);
    });

    testWidgets('hides the OG Viner chit on a vanished account', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        ogVinerPubkeysCacheKey: jsonEncode([testUserHex]),
      });
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        buildTestWidget(
          userIdHex: testUserHex,
          isOwnProfile: false,
          suppliedProfile: createTestProfile(displayName: 'OG User'),
          sharedPreferences: prefs,
          isVanished: true,
        ),
      );
      await tester.pumpAndSettle();

      // Same reasoning as the OG Beta chit and the checkmark above: a vanished
      // account renders profileDeletedAccountName, and the OG Viner roster is a
      // cached set that cannot drop someone who vanishes after release.
      expect(find.byType(OgVinerBadge), findsNothing);
    });

    testWidgets('opens checkmark explainer from profile header target', (
      tester,
    ) async {
      final l10n = lookupAppLocalizations(const Locale('en'));

      await tester.pumpWidget(
        buildTestWidget(
          userIdHex: kDivineTeamPubkeys.first,
          isOwnProfile: false,
          suppliedProfile: createTestProfile(
            displayName: 'Checked User',
            pubkey: kDivineTeamPubkeys.first,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final button = findByTooltip(l10n.profileBadgeCheckmarkTitle);
      expect(button, findsOneWidget);
      // The header shows the same blue checkmark badge as the feed.
      expect(find.byType(SpecialProfileCheckmark), findsOneWidget);
      // The badge widget carries its own label; announcing the meaning once,
      // as the tappable node, is the contract the header has to keep.
      final semantics = tester.getSemantics(button);
      expect(semantics.label, equals(l10n.profileBadgeCheckmarkTitle));
      expect(semantics.value, equals(l10n.profileBadgeCheckmarkBody));
      // The badge must stay a real tap target; the exact box is the design
      // system's to decide, so assert the 48dp floor rather than a number.
      final buttonSize = tester.getSize(button);
      expect(buttonSize.width, greaterThanOrEqualTo(48));
      expect(buttonSize.height, greaterThanOrEqualTo(48));

      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(find.text(l10n.profileBadgeCheckmarkTitle), findsWidgets);
      expect(find.text(l10n.profileBadgeCheckmarkBody), findsOneWidget);
      expect(find.text(l10n.commonClose), findsOneWidget);
    });

    testWidgets('header badges keep matching diameters at capped text scale', (
      tester,
    ) async {
      final teamPubkey = kDivineTeamPubkeys.first;
      SharedPreferences.setMockInitialValues({
        ogVinerPubkeysCacheKey: jsonEncode([teamPubkey]),
      });
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        buildTestWidget(
          userIdHex: teamPubkey,
          isOwnProfile: false,
          suppliedProfile: createTestProfile(
            displayName: 'Checked OG User',
            pubkey: teamPubkey,
          ),
          sharedPreferences: prefs,
          textScaler: const TextScaler.linear(2),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SpecialProfileCheckmark), findsOneWidget);
      expect(find.byType(OgVinerBadge), findsOneWidget);
      expect(
        tester.getSize(find.byType(SpecialProfileCheckmark)),
        equals(tester.getSize(find.byType(OgVinerBadge))),
      );
    });

    testWidgets('badge detail sheet opens the in-app badge editor', (
      tester,
    ) async {
      final testProfile = createTestProfile(displayName: 'Badged User');
      final mockGoRouter = MockGoRouter();
      when(
        () => mockGoRouter.push<Object?>(any()),
      ).thenAnswer((_) async => null);

      await tester.pumpWidget(
        buildTestWidget(
          userIdHex: testUserHex,
          isOwnProfile: false,
          suppliedProfile: testProfile,
          goRouter: mockGoRouter,
          acceptedProfileBadges: [
            ProfileBadgeViewData(
              badge: const Nip58ProfileBadgeRef(
                definitionCoordinate: '30009:$issuerUserHex:daily-diviner',
                awardEventId: '00000000000000000000000000000000000000000000000000000000000000aa',
              ),
              award: Nip58BadgeAward(
                event: _badgeAwardEvent(),
                definitionCoordinate: '30009:$issuerUserHex:daily-diviner',
                recipientPubkeys: const [testUserHex, recipientUserHex],
              ),
              definition: Nip58BadgeDefinition(
                event: _badgeDefinitionEvent(),
                coordinate: '30009:$issuerUserHex:daily-diviner',
                dTag: 'daily-diviner',
                name: 'Diviner of the Day',
              ),
            ),
          ],
        ),
      );
      // Let the badge row's reveal animation finish; the chip does not hit
      // test while it is still fading in.
      await tester.pumpAndSettle();

      await tester.tap(find.text('Diviner of the Day'));
      await tester.pumpAndSettle();

      final l10n = lookupAppLocalizations(const Locale('en'));
      final link = find.text(l10n.profileBadgeFooterLink);
      expect(find.text(l10n.profileBadgeFooterBody), findsOneWidget);
      expect(link, findsOneWidget);

      await tester.ensureVisible(link);
      await tester.pumpAndSettle();
      await tester.tap(link);
      await tester.pumpAndSettle();

      // Order matters: the dashboard has to sit under the editor, so that
      // publishing pops onto the badge list rather than back to the profile.
      verifyInOrder([
        () => mockGoRouter.push<Object?>(BadgesScreen.path),
        () => mockGoRouter.push<Object?>(BadgeEditorScreen.createPath),
      ]);
    });

    testWidgets('caps accepted badge recipients in detail sheet', (
      tester,
    ) async {
      final testProfile = createTestProfile(displayName: 'Badged User');
      final recipients = List<String>.generate(
        14,
        (index) => (index + 1).toRadixString(16).padLeft(64, '0'),
      );

      await tester.pumpWidget(
        buildTestWidget(
          userIdHex: testUserHex,
          isOwnProfile: false,
          suppliedProfile: testProfile,
          acceptedProfileBadges: [
            ProfileBadgeViewData(
              badge: const Nip58ProfileBadgeRef(
                definitionCoordinate: '30009:$issuerUserHex:daily-diviner',
                awardEventId: '00000000000000000000000000000000000000000000000000000000000000aa',
              ),
              award: Nip58BadgeAward(
                event: _badgeAwardEvent(),
                definitionCoordinate: '30009:$issuerUserHex:daily-diviner',
                recipientPubkeys: recipients,
              ),
              definition: Nip58BadgeDefinition(
                event: _badgeDefinitionEvent(),
                coordinate: '30009:$issuerUserHex:daily-diviner',
                dTag: 'daily-diviner',
                name: 'Diviner of the Day',
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Diviner of the Day'));
      await tester.pumpAndSettle();

      expect(find.byType(UserProfileTile), findsNWidgets(13));
      expect(find.text('+2 more'), findsOneWidget);
    });

    testWidgets('lays accepted badges out in a single horizontal scroll row', (
      tester,
    ) async {
      final testProfile = createTestProfile(displayName: 'Badged User');

      await tester.pumpWidget(
        buildTestWidget(
          userIdHex: testUserHex,
          isOwnProfile: false,
          suppliedProfile: testProfile,
          acceptedProfileBadges: [
            _acceptedBadge('Badge One', 'badge-one'),
            _acceptedBadge('Badge Two', 'badge-two'),
            _acceptedBadge('Badge Three', 'badge-three'),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // All badges render — they are not truncated to a single row.
      expect(find.text('Badge One'), findsOneWidget);
      expect(find.text('Badge Two'), findsOneWidget);
      expect(find.text('Badge Three'), findsOneWidget);

      // The row scrolls horizontally instead of wrapping, so each chip lives
      // inside a horizontal SingleChildScrollView rather than a Wrap.
      Finder horizontalScrollAbove(String badgeName) => find.ancestor(
        of: find.text(badgeName),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is SingleChildScrollView &&
              widget.scrollDirection == Axis.horizontal,
        ),
      );
      expect(horizontalScrollAbove('Badge One'), findsOneWidget);
      expect(horizontalScrollAbove('Badge Three'), findsOneWidget);
    });

    testWidgets('grows the badge row in instead of snapping the layout', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(
          userIdHex: testUserHex,
          isOwnProfile: false,
          suppliedProfile: createTestProfile(displayName: 'Badged User'),
          acceptedProfileBadges: [_acceptedBadge('Badge One', 'badge-one')],
        ),
      );
      // Two frames: the badge future resolves, then the row is built for the
      // first time — the reveal has only just started at that point.
      await tester.pump();
      await tester.pump();

      final block = find.ancestor(
        of: find.text('Badge One'),
        matching: find.byType(AnimatedSize),
      );
      final revealingHeight = tester.getSize(block).height;

      await tester.pumpAndSettle();
      final settledHeight = tester.getSize(block).height;

      expect(settledHeight, greaterThan(0));
      expect(revealingHeight, lessThan(settledHeight));
    });

    testWidgets('lands the badge row at once under reduce motion', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(
          userIdHex: testUserHex,
          isOwnProfile: false,
          suppliedProfile: createTestProfile(displayName: 'Badged User'),
          acceptedProfileBadges: [_acceptedBadge('Badge One', 'badge-one')],
          disableAnimations: true,
        ),
      );
      await tester.pump();
      await tester.pump();

      // A zero-duration AnimatedSize would assert here instead of rendering.
      expect(find.text('Badge One'), findsOneWidget);
      expect(find.byType(AnimatedSize), findsNothing);
    });

    testWidgets('displays user avatar when profile is loaded', (tester) async {
      final testProfile = createTestProfile(
        displayName: 'Test User',
        name: 'testuser',
        about: 'This is my bio',
        picture: 'https://example.com/avatar.jpg',
        nip05: 'test@example.com',
      );

      await tester.pumpWidget(
        buildTestWidget(
          userIdHex: testUserHex,
          isOwnProfile: true,

          profile: testProfile,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(UserAvatar), findsOneWidget);
    });

    testWidgets('nav glyphs follow the palette on light', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          userIdHex: testUserHex,
          isOwnProfile: true,
          profile: createTestProfile(displayName: 'Test User'),
          theme: VineTheme.lightTheme,
        ),
      );
      await tester.pumpAndSettle();

      // A profile with no banner image and no profileColor — the default —
      // gets ProfileBanner's palette gradient (containerLow -> surface), and
      // the banner scrim is fully transparent at this height. A fixed light
      // glyph on the 15% scrim over #EDF3EF is ~1.5:1.
      final gear = tester.widget<DivineIcon>(
        find.descendant(
          of: find.byWidgetPredicate(
            (w) => w is DivineIconButton && w.icon == DivineIconName.gear,
          ),
          matching: find.byType(DivineIcon),
        ),
      );
      expect(gear.color, VineTheme.lightColors.onSurface);
      expect(gear.color, isNot(VineTheme.onSurface));
    });

    testWidgets('settings gear carries a test anchor and an accessible name', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(
          userIdHex: testUserHex,
          isOwnProfile: true,
          profile: createTestProfile(displayName: 'Test User'),
        ),
      );
      await tester.pumpAndSettle();

      final gear = find.byWidgetPredicate(
        (w) => w is DivineIconButton && w.icon == DivineIconName.gear,
      );
      final semantics = tester.getSemantics(gear);

      // This is the only entry point to Settings, and removeKeys — the
      // teardown of every smoke flow — reaches it through here.
      expect(semantics.identifier, equals(SemanticIds.profileSettingsButton));
      expect(
        semantics.label,
        equals(lookupAppLocalizations(const Locale('en')).settingsTitle),
      );
    });

    testWidgets('avatar lightbox seeds placeholder with the pubkey so the '
        'fallback colour matches the rest of the app when the image fails', (
      tester,
    ) async {
      final testProfile = createTestProfile(
        displayName: 'Test User',
        picture: 'https://example.com/broken.jpg',
      );

      await tester.pumpWidget(
        buildTestWidget(
          userIdHex: testUserHex,
          isOwnProfile: true,
          profile: testProfile,
        ),
      );
      await tester.pumpAndSettle();

      // Only the header avatar is in the tree before the lightbox opens.
      expect(find.byType(UserAvatar), findsOneWidget);

      await tester.tap(find.byType(UserAvatar));
      await tester.pumpAndSettle();

      // After opening, the lightbox adds a second UserAvatar at size 288.
      final lightboxAvatar = tester
          .widgetList<UserAvatar>(find.byType(UserAvatar))
          .firstWhere((avatar) => avatar.size == 288);
      expect(lightboxAvatar.placeholderSeed, equals(testUserHex));
    });

    testWidgets(
      'header avatar default corner radius matches the Hero flight ratio',
      (tester) async {
        final testProfile = createTestProfile(
          displayName: 'Test User',
          picture: 'https://example.com/avatar.jpg',
        );

        await tester.pumpWidget(
          buildTestWidget(
            userIdHex: testUserHex,
            isOwnProfile: true,
            profile: testProfile,
          ),
        );
        await tester.pumpAndSettle();

        final headerAvatar = tester.widget<UserAvatar>(find.byType(UserAvatar));
        expect(headerAvatar.cornerRadius, isNull);

        final avatarClip = tester.widget<ClipRRect>(
          find.descendant(
            of: find.byType(UserAvatar),
            matching: find.byType(ClipRRect),
          ),
        );
        final borderRadius = avatarClip.borderRadius as BorderRadius;

        // Mirrors the lightbox constants in profile_header_media.dart:
        // _lightboxAvatarCornerRadius / _lightboxAvatarSize == 112 / 288.
        // If the header size or UserAvatar's default radius formula changes,
        // this catches the resulting jump at the start of the Hero flight.
        final expectedRadius = headerAvatar.size * (112 / 288);
        expect(borderRadius.topLeft.x, closeTo(expectedRadius, 0.001));
        expect(borderRadius.topLeft.y, closeTo(expectedRadius, 0.001));
      },
    );

    testWidgets(
      'avatar Hero flight scales the shuttle from the header size so the '
      'corner radius stays proportional instead of clamping to a circle '
      'mid-flight',
      (tester) async {
        final testProfile = createTestProfile(
          displayName: 'Test User',
          picture: 'https://example.com/avatar.jpg',
        );

        await tester.pumpWidget(
          buildTestWidget(
            userIdHex: testUserHex,
            isOwnProfile: true,
            profile: testProfile,
          ),
        );
        await tester.pumpAndSettle();

        // Open the lightbox — this starts the Hero flight.
        await tester.tap(find.byType(UserAvatar));
        await tester.pump(); // push the route, start the flight at t=0
        await tester.pump(const Duration(milliseconds: 150)); // mid-flight

        // During the flight both the header (144px) and lightbox (288px)
        // Heroes render size-preserving placeholders, so the only UserAvatar
        // in the tree is the flight shuttle. The fix drives the shuttle's size
        // and corner radius from the live flight box, so mid-flight the size
        // sits strictly between the two ends. The old default shuttle painted
        // the fixed 288px/112px destination avatar, whose 112px radius clamped
        // to a full circle while the flight box was below 224px.
        final shuttles = tester
            .widgetList<UserAvatar>(find.byType(UserAvatar))
            .where((a) => a.size > 144 && a.size < 288)
            .toList();
        expect(
          shuttles,
          hasLength(1),
          reason: 'mid-flight the only avatar is the scaling Hero shuttle',
        );

        final shuttle = shuttles.single;
        expect(shuttle.cornerRadius, isNotNull);
        // Radius never exceeds half the box → never renders as a full circle.
        expect(shuttle.cornerRadius! * 2, lessThan(shuttle.size));
        // Radius tracks the 112/288 ratio shared by both ends of the flight.
        expect(
          shuttle.cornerRadius,
          closeTo(shuttle.size * (112 / 288), 0.001),
        );

        // Let the flight finish so teardown is clean.
        await tester.pumpAndSettle();
      },
    );

    testWidgets('tapping the opened avatar lightbox pops the route', (
      tester,
    ) async {
      final testProfile = createTestProfile(
        displayName: 'Test User',
        picture: 'https://example.com/avatar.jpg',
      );

      await tester.pumpWidget(
        buildTestWidget(
          userIdHex: testUserHex,
          isOwnProfile: true,
          profile: testProfile,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(UserAvatar));
      await tester.pumpAndSettle();

      // Lightbox is open: the 288px avatar is present.
      expect(
        tester
            .widgetList<UserAvatar>(find.byType(UserAvatar))
            .where((a) => a.size == 288),
        hasLength(1),
      );

      // Tapping the lightbox dismisses it via Navigator.pop.
      await tester.tap(
        find.byWidgetPredicate((w) => w is UserAvatar && w.size == 288),
      );
      await tester.pumpAndSettle();

      // Route popped: only the 144px header avatar remains.
      expect(
        tester
            .widgetList<UserAvatar>(find.byType(UserAvatar))
            .where((a) => a.size == 288),
        isEmpty,
      );
    });

    testWidgets(
      'uses parent-supplied profile for other users while fallback provider is unresolved',
      (tester) async {
        final suppliedProfile = createTestProfile(
          displayName: 'Cached Classic',
          about: 'Seeded bio',
        );

        await tester.pumpWidget(
          buildTestWidget(
            userIdHex: testUserHex,
            isOwnProfile: false,
            suppliedProfile: suppliedProfile,
            profileIsLoading: true,
          ),
        );
        await tester.pump();

        expect(find.text('Cached Classic'), findsOneWidget);
        expect(find.text('Seeded bio'), findsOneWidget);
      },
    );

    testWidgets(
      'shows support affordance from a newer supplied own-profile profile',
      (tester) async {
        final staleProfile = createTestProfile(
          displayName: 'Creator',
          createdAt: DateTime.utc(2026),
          eventId: 'old-kind0',
        );
        final savedProfile = createTestProfile(
          displayName: 'Creator',
          createdAt: DateTime.utc(2026, 1, 1, 0, 1),
          eventId: 'new-kind0',
          rawData: {
            divineMonetizationLinksKey: [
              const MonetizationLink(
                provider: MonetizationLinkProvider.cashApp,
                category: MonetizationLinkCategory.tip,
                url: r'https://cash.app/$creator',
                enabled: true,
              ).toJson(),
            ],
          },
        );

        await tester.pumpWidget(
          buildTestWidget(
            userIdHex: testUserHex,
            isOwnProfile: true,
            profile: staleProfile,
            suppliedProfile: savedProfile,
            monetizationLinksEnabled: true,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('profile-support-button')), findsOneWidget);
      },
    );

    testWidgets('shows the profile website row when the profile has one', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(
          userIdHex: testUserHex,
          isOwnProfile: false,
          suppliedProfile: createTestProfile(
            displayName: 'Creator',
            website: 'https://creator.example/shop',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ProfileWebsiteRow), findsOneWidget);
    });

    testWidgets('shows support affordance for other profiles with links', (
      tester,
    ) async {
      final creatorProfile = createTestProfile(
        displayName: 'Creator',
        about: 'Creator bio',
        rawData: {
          divineMonetizationLinksKey: [
            const MonetizationLink(
              provider: MonetizationLinkProvider.patreon,
              category: MonetizationLinkCategory.subscription,
              url: 'https://www.patreon.com/creator',
              enabled: true,
            ).toJson(),
          ],
        },
      );

      await tester.pumpWidget(
        buildTestWidget(
          userIdHex: testUserHex,
          isOwnProfile: false,
          suppliedProfile: creatorProfile,
          monetizationLinksEnabled: true,
        ),
      );
      await tester.pumpAndSettle();

      final supportButton = find.byKey(const Key('profile-support-button'));
      expect(supportButton, findsOneWidget);
      // Label-only support pill: a bolt glyph reads as Lightning-Network
      // payment, so the affordance carries copy and no icon.
      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.profileSupportButtonLabel), findsOneWidget);
      expect(tester.widget<DivineButton>(supportButton).leadingIcon, isNull);

      // Centered in the identity block, between the bio and the stats.
      final supportRect = tester.getRect(supportButton);
      expect(
        supportRect.top,
        greaterThan(tester.getBottomLeft(find.text('Creator bio')).dy),
      );
      expect(
        supportRect.top,
        lessThan(tester.getTopLeft(find.text('Likes')).dy),
      );
      final screenWidth =
          tester.view.physicalSize.width / tester.view.devicePixelRatio;
      expect(supportRect.center.dx, closeTo(screenWidth / 2, 1));
    });

    testWidgets('shows the support button in the frame the links arrive', (
      tester,
    ) async {
      // The REST profile projection cannot carry Divine's custom Kind 0
      // fields, so monetization links land after the header first renders.
      final withoutLinks = createTestProfile(displayName: 'Creator');
      final withLinks = createTestProfile(
        displayName: 'Creator',
        rawData: {
          divineMonetizationLinksKey: [
            const MonetizationLink(
              provider: MonetizationLinkProvider.cashApp,
              category: MonetizationLinkCategory.tip,
              url: r'https://cash.app/$creator',
              enabled: true,
            ).toJson(),
          ],
        },
      );

      await tester.pumpWidget(
        buildTestWidget(
          userIdHex: testUserHex,
          isOwnProfile: false,
          suppliedProfile: withoutLinks,
          monetizationLinksEnabled: true,
        ),
      );
      await tester.pumpAndSettle();

      final supportButton = find.byKey(const Key('profile-support-button'));
      expect(supportButton, findsNothing);

      await tester.pumpWidget(
        buildTestWidget(
          userIdHex: testUserHex,
          isOwnProfile: false,
          suppliedProfile: withLinks,
          monetizationLinksEnabled: true,
        ),
      );
      await tester.pump();

      // Visible in the frame the links land — no implicit animation may gate
      // it. AnimatedSize never completes while its subtree's tickers are
      // muted (inactive PageView / TabBarView page, route transition), which
      // stranded this button at zero width.
      expect(supportButton, findsOneWidget);
      expect(tester.getRect(supportButton).width, greaterThan(0));
    });

    testWidgets('hides support affordance when monetization flag is off', (
      tester,
    ) async {
      final creatorProfile = createTestProfile(
        displayName: 'Creator',
        rawData: {
          divineMonetizationLinksKey: [
            const MonetizationLink(
              provider: MonetizationLinkProvider.cashApp,
              category: MonetizationLinkCategory.tip,
              url: r'https://cash.app/$creator',
              enabled: true,
            ).toJson(),
          ],
        },
      );

      await tester.pumpWidget(
        buildTestWidget(
          userIdHex: testUserHex,
          isOwnProfile: false,
          suppliedProfile: creatorProfile,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('profile-support-button')), findsNothing);
    });

    testWidgets('hides subscription-only support links on iOS storefronts', (
      tester,
    ) async {
      debugUsesAppleAppStoreTipPolicyOverride = true;

      final creatorProfile = createTestProfile(
        displayName: 'Creator',
        about: 'Creator bio',
        rawData: {
          divineMonetizationLinksKey: [
            const MonetizationLink(
              provider: MonetizationLinkProvider.patreon,
              category: MonetizationLinkCategory.subscription,
              url: 'https://www.patreon.com/creator',
              enabled: true,
            ).toJson(),
          ],
        },
      );

      await tester.pumpWidget(
        buildTestWidget(
          userIdHex: testUserHex,
          isOwnProfile: false,
          suppliedProfile: creatorProfile,
          monetizationLinksEnabled: true,
        ),
      );
      await tester.pumpAndSettle();

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.byKey(const Key('profile-support-button')), findsNothing);
      expect(find.text(l10n.profileSupportButtonLabel), findsNothing);
    });

    testWidgets('uses tip affordance copy on iOS storefronts', (tester) async {
      debugUsesAppleAppStoreTipPolicyOverride = true;

      final creatorProfile = createTestProfile(
        displayName: 'Creator',
        rawData: {
          divineMonetizationLinksKey: [
            const MonetizationLink(
              provider: MonetizationLinkProvider.cashApp,
              category: MonetizationLinkCategory.tip,
              url: r'https://cash.app/$creator',
              enabled: true,
            ).toJson(),
          ],
        },
      );

      await tester.pumpWidget(
        buildTestWidget(
          userIdHex: testUserHex,
          isOwnProfile: false,
          suppliedProfile: creatorProfile,
          monetizationLinksEnabled: true,
        ),
      );
      await tester.pumpAndSettle();

      final supportButton = find.byKey(const Key('profile-support-button'));
      expect(supportButton, findsOneWidget);
      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.profileTipButtonLabel), findsOneWidget);
      expect(find.text(l10n.profileSupportButtonLabel), findsNothing);
      // Copy alone carries the tip framing — no bolt, which would read as a
      // Lightning-Network payment rather than an optional creator tip.
      expect(tester.widget<DivineButton>(supportButton).leadingIcon, isNull);
    });

    testWidgets('displays stats from ProfileStats when provided', (
      tester,
    ) async {
      final testProfile = createTestProfile(displayName: 'Counted User');
      // Above profileLoopsVisibilityFloor so a visitor still sees Loops.
      const profileStats = ProfileStats(
        pubkey: testUserHex,
        videoCount: 42,
        totalLikes: 100,
        totalViews: 50000,
      );

      await tester.pumpWidget(
        buildTestWidget(
          userIdHex: testUserHex,
          isOwnProfile: false,
          suppliedProfile: testProfile,
          profileStats: profileStats,
          videoCount: 3,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Likes'), findsOneWidget);
      expect(find.text('Loops'), findsOneWidget);
    });

    testWidgets('hides Loops from a visitor when the total is small', (
      tester,
    ) async {
      final testProfile = createTestProfile(displayName: 'New Creator');
      const profileStats = ProfileStats(
        pubkey: testUserHex,
        videoCount: 2,
        totalLikes: 3,
        totalViews: 7,
      );

      await tester.pumpWidget(
        buildTestWidget(
          userIdHex: testUserHex,
          isOwnProfile: false,
          suppliedProfile: testProfile,
          profileStats: profileStats,
          videoCount: 2,
        ),
      );
      await tester.pumpAndSettle();

      // The rest of the row still renders; only the discouraging headline
      // number is withheld.
      expect(find.text('Loops'), findsNothing);
      expect(find.text('Likes'), findsOneWidget);
    });

    testWidgets('shows an owner their own small Loops total', (tester) async {
      final testProfile = createTestProfile(displayName: 'New Creator');
      const profileStats = ProfileStats(
        pubkey: testUserHex,
        videoCount: 2,
        totalLikes: 3,
        totalViews: 7,
      );

      await tester.pumpWidget(
        buildTestWidget(
          userIdHex: testUserHex,
          isOwnProfile: true,
          suppliedProfile: testProfile,
          profileStats: profileStats,
          videoCount: 2,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Loops'), findsOneWidget);
    });

    testWidgets('shows a visitor a total exactly at the floor', (tester) async {
      final testProfile = createTestProfile(displayName: 'Counted User');
      const profileStats = ProfileStats(
        pubkey: testUserHex,
        videoCount: 42,
        totalLikes: 100,
        totalViews: profileLoopsVisibilityFloor,
      );

      await tester.pumpWidget(
        buildTestWidget(
          userIdHex: testUserHex,
          isOwnProfile: false,
          suppliedProfile: testProfile,
          profileStats: profileStats,
          videoCount: 3,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Loops'), findsOneWidget);
    });

    testWidgets('displays all four stat columns when stats are available', (
      tester,
    ) async {
      final testProfile = createTestProfile(displayName: 'Test User');
      const profileStats = ProfileStats(pubkey: testUserHex);

      await tester.pumpWidget(
        buildTestWidget(
          userIdHex: testUserHex,
          isOwnProfile: true,
          profile: testProfile,
          profileStats: profileStats,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Followers'), findsOneWidget);
      expect(find.text('Following'), findsOneWidget);
      expect(find.text('Likes'), findsOneWidget);
      expect(find.text('Loops'), findsOneWidget);
    });

    testWidgets(
      'shows a placeholder, not "0", when no follower count has been cached '
      'and the followers BLoC has not loaded yet',
      (tester) async {
        // A profile row exists for the video/engagement stats, but
        // FollowRepository has not written follower counts for this pubkey
        // yet, so they arrive as null. Rendering that as "0" is the bug in
        // #6764: a settled, wrong count that never shimmers, and that sticks
        // permanently if the followers fetch fails.
        const profileStats = ProfileStats(
          pubkey: testUserHex,
          totalLikes: 10,
          totalViews: 20,
        );

        await tester.pumpWidget(
          buildTestWidget(
            userIdHex: testUserHex,
            isOwnProfile: false,
            suppliedProfile: createTestProfile(displayName: 'Unknown Counts'),
            profileStats: profileStats,
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.descendant(
            of: find
                .ancestor(
                  of: find.text('Followers'),
                  matching: find.byType(ProfileStatColumn),
                )
                .first,
            matching: find.text('—'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find
                .ancestor(
                  of: find.text('Followers'),
                  matching: find.byType(ProfileStatColumn),
                )
                .first,
            matching: find.text('0'),
          ),
          findsNothing,
        );
      },
    );

    testWidgets(
      'shows the cached follower count while the followers BLoC loads',
      (tester) async {
        const profileStats = ProfileStats(
          pubkey: testUserHex,
          followers: 7,
          following: 3,
          totalLikes: 10,
          totalViews: 20,
        );

        await tester.pumpWidget(
          buildTestWidget(
            userIdHex: testUserHex,
            isOwnProfile: false,
            suppliedProfile: createTestProfile(displayName: 'Cached Counts'),
            profileStats: profileStats,
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.descendant(
            of: find
                .ancestor(
                  of: find.text('Followers'),
                  matching: find.byType(ProfileStatColumn),
                )
                .first,
            matching: find.text('7'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'keeps all stat columns visible with em-dash placeholders once the '
      'skeleton timeout expires and profileStats is still null',
      (tester) async {
        final testProfile = createTestProfile(displayName: 'Test User');

        await tester.pumpWidget(
          buildTestWidget(
            userIdHex: testUserHex,
            isOwnProfile: true,
            profile: testProfile,
          ),
        );
        // Advance past the 7-second skeleton timeout, then settle any
        // remaining switch animations.
        await tester.pump(const Duration(seconds: 8));
        await tester.pumpAndSettle();

        // All four labels stay in the tree; counts fall back to '—'.
        expect(find.text('Followers'), findsOneWidget);
        expect(find.text('Following'), findsOneWidget);
        expect(find.text('Likes'), findsOneWidget);
        expect(find.text('Loops'), findsOneWidget);
        expect(find.text('—'), findsNWidgets(4));

        // Stats Skeletonizer (the closest one above a stat label) must
        // be disabled after timeout — data is shown as-is.
        // bySubtype is required because Skeletonizer is abstract; the
        // concrete widget in the tree is the private _Skeletonizer subclass.
        final s = tester.widget<Skeletonizer>(
          find
              .ancestor(
                of: find.text('Followers'),
                matching: find.bySubtype<Skeletonizer>(),
              )
              .first,
        );
        expect(s.enabled, isFalse);
      },
    );

    group('Stats row skeleton timeout', () {
      testWidgets(
        'shows placeholder columns as skeleton while profileStats is null before timeout',
        (tester) async {
          final testProfile = createTestProfile(displayName: 'Test User');

          await tester.pumpWidget(
            buildTestWidget(
              userIdHex: testUserHex,
              isOwnProfile: true,
              profile: testProfile,
              // profileStats deliberately omitted (null)
            ),
          );
          // One frame only — the 7-second skeleton timer has not fired yet.
          await tester.pump();

          // All four column labels are in the tree, rendered as skeletons.
          expect(find.text('Followers'), findsOneWidget);
          expect(find.text('Following'), findsOneWidget);
          expect(find.text('Likes'), findsOneWidget);
          expect(find.text('Loops'), findsOneWidget);

          // Stats Skeletonizer (the closest one above a stat label) must
          // be active — not just present in the tree.
          // bySubtype is required because Skeletonizer is abstract; the
          // concrete widget in the tree is the private _Skeletonizer subclass.
          final s = tester.widget<Skeletonizer>(
            find
                .ancestor(
                  of: find.text('Followers'),
                  matching: find.bySubtype<Skeletonizer>(),
                )
                .first,
          );
          expect(s.enabled, isTrue);
        },
      );

      testWidgets(
        'stat columns remain visible once profileStats arrives before timeout',
        (tester) async {
          const stats = ProfileStats(
            pubkey: testUserHex,
            totalLikes: 10,
            totalViews: 20,
          );

          await tester.pumpWidget(
            buildTestWidget(
              userIdHex: testUserHex,
              isOwnProfile: true,
              profile: createTestProfile(displayName: 'Test User'),
              profileStats: stats,
            ),
          );
          await tester.pumpAndSettle();

          // Actual data shown — no timeout was needed.
          expect(find.text('Loops'), findsOneWidget);
          expect(find.text('Likes'), findsOneWidget);
        },
      );
    });

    testWidgets('displays user bio when present', (tester) async {
      final testProfile = createTestProfile(
        displayName: 'Test User',
        about: 'This is my bio',
      );

      await tester.pumpWidget(
        buildTestWidget(
          userIdHex: testUserHex,
          isOwnProfile: true,

          profile: testProfile,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('This is my bio'), findsOneWidget);
    });

    testWidgets('displays NIP-05 when present', (tester) async {
      final testProfile = createTestProfile(
        displayName: 'Test User',
        nip05: 'test@example.com',
      );

      await tester.pumpWidget(
        buildTestWidget(
          userIdHex: testUserHex,
          isOwnProfile: true,

          profile: testProfile,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('test@example.com'), findsOneWidget);
    });

    testWidgets(
      'shows Complete Your Profile label for own profile without custom name',
      (tester) async {
        final profileWithDefaultName = createTestProfile();

        await tester.pumpWidget(
          buildTestWidget(
            userIdHex: testUserHex,
            isOwnProfile: true,
            profile: profileWithDefaultName,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(enL10n.profileCompleteYourProfile), findsOneWidget);
      },
    );

    testWidgets('hides action label while profile is still loading', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(
          userIdHex: testUserHex,
          isOwnProfile: true,
          profileIsLoading: true,
        ),
      );
      // Do not pumpAndSettle — provider never resolves
      await tester.pump();

      // Action label is replaced with SizedBox.shrink() during the loading
      // window so the prompt doesn't flicker between states (#4183 review).
      expect(find.text(enL10n.profileCompleteYourProfile), findsNothing);
    });

    testWidgets('hides action label when profile has custom name', (
      tester,
    ) async {
      final testProfile = createTestProfile(displayName: 'Test User');

      await tester.pumpWidget(
        buildTestWidget(
          userIdHex: testUserHex,
          isOwnProfile: true,
          profile: testProfile,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(enL10n.profileCompleteYourProfile), findsNothing);
    });

    testWidgets('hides action label for other profiles', (tester) async {
      final profileWithDefaultName = createTestProfile();

      await tester.pumpWidget(
        buildTestWidget(
          userIdHex: testUserHex,
          isOwnProfile: false,
          profile: profileWithDefaultName,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(enL10n.profileCompleteYourProfile), findsNothing);
    });

    testWidgets('renders PeopleListMembershipIndicator for other users', (
      tester,
    ) async {
      final testProfile = createTestProfile(displayName: 'Other User');

      await tester.pumpWidget(
        buildTestWidget(
          userIdHex: testUserHex,
          isOwnProfile: false,
          suppliedProfile: testProfile,
          curatedListsEnabled: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PeopleListMembershipIndicator), findsOneWidget);
    });

    testWidgets(
      'does not render PeopleListMembershipIndicator for own profile',
      (tester) async {
        final testProfile = createTestProfile(displayName: 'Self');

        await tester.pumpWidget(
          buildTestWidget(
            userIdHex: testUserHex,
            isOwnProfile: true,
            profile: testProfile,
            curatedListsEnabled: true,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(PeopleListMembershipIndicator), findsNothing);
      },
    );

    testWidgets(
      'renders fallback content for others profile with null profile',
      (tester) async {
        // With the classic Viners feature, profiles without Kind 0 events
        // can still be displayed using hint values as fallbacks
        await tester.pumpWidget(
          buildTestWidget(
            userIdHex: testUserHex,
            isOwnProfile: false,

            displayNameHint: 'Unknown',
            avatarUrlHint: 'https://example.com/fallback.png',
          ),
        );
        await tester.pumpAndSettle();

        // Should render with fallback/default avatar (not empty)
        expect(find.byType(ProfileHeaderWidget), findsOneWidget);
        expect(find.byType(UserAvatar), findsOneWidget);
      },
    );

    group('Expandable Bio', () {
      // Create a bio that will definitely exceed 3 lines on a phone screen
      // Using many short words to ensure wrapping at narrow widths
      final longBio = List.generate(
        20,
        (i) => 'This is line $i of the bio.',
      ).join(' ');

      testWidgets('short bio does not show "Show more" button', (tester) async {
        final testProfile = createTestProfile(
          displayName: 'Test User',
          about: 'Short bio',
        );

        await tester.pumpWidget(
          buildTestWidget(
            userIdHex: testUserHex,
            isOwnProfile: true,

            profile: testProfile,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Short bio'), findsOneWidget);
        expect(find.text('Show more'), findsNothing);
        expect(find.text('Show less'), findsNothing);
      });

      testWidgets('long bio shows "Show more" button and truncates', (
        tester,
      ) async {
        // Set a phone-like screen size to ensure text wraps
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final testProfile = createTestProfile(
          displayName: 'Test User',
          about: longBio,
        );

        await tester.pumpWidget(
          buildTestWidget(
            userIdHex: testUserHex,
            isOwnProfile: true,

            profile: testProfile,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Show more'), findsOneWidget);
        expect(find.text('Show less'), findsNothing);
      });

      testWidgets('tapping "Show more" expands bio and shows "Show less"', (
        tester,
      ) async {
        // Set a phone-like screen size to ensure text wraps
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final testProfile = createTestProfile(
          displayName: 'Test User',
          about: longBio,
        );

        await tester.pumpWidget(
          buildTestWidget(
            userIdHex: testUserHex,
            isOwnProfile: true,

            profile: testProfile,
          ),
        );
        await tester.pumpAndSettle();

        // Tap "Show more"
        await tester.tap(find.text('Show more'));
        await tester.pumpAndSettle();

        // Should now show "Show less"
        expect(find.text('Show less'), findsOneWidget);
        expect(find.text('Show more'), findsNothing);
      });

      testWidgets('expanding the bio grows it instead of snapping open', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          buildTestWidget(
            userIdHex: testUserHex,
            isOwnProfile: true,
            profile: createTestProfile(
              displayName: 'Test User',
              about: longBio,
            ),
          ),
        );
        await tester.pumpAndSettle();

        Finder bioBlock(String toggleLabel) => find.ancestor(
          of: find.text(toggleLabel),
          matching: find.byType(AnimatedSize),
        );
        final collapsedHeight = tester.getSize(bioBlock('Show more')).height;

        await tester.tap(find.text('Show more'));
        // The expanded text is laid out on this frame, but the block is still
        // at its collapsed height — it grows from there rather than snapping.
        await tester.pump();
        expect(tester.getSize(bioBlock('Show less')).height, collapsedHeight);

        await tester.pumpAndSettle();
        expect(
          tester.getSize(bioBlock('Show less')).height,
          greaterThan(collapsedHeight),
        );
      });

      testWidgets('tapping "Show less" collapses bio and shows "Show more"', (
        tester,
      ) async {
        // Use a taller viewport so expanded bio content stays in bounds
        tester.view.physicalSize = const Size(400, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final testProfile = createTestProfile(
          displayName: 'Test User',
          about: longBio,
        );

        await tester.pumpWidget(
          buildTestWidget(
            userIdHex: testUserHex,
            isOwnProfile: true,
            profile: testProfile,
          ),
        );
        await tester.pumpAndSettle();

        // First expand
        await tester.tap(find.text('Show more'));
        await tester.pumpAndSettle();

        // Scroll down to reveal "Show less" if needed
        await tester.ensureVisible(find.text('Show less'));
        await tester.pumpAndSettle();

        // Then collapse
        await tester.tap(find.text('Show less'));
        await tester.pumpAndSettle();

        // Should be back to "Show more"
        expect(find.text('Show more'), findsOneWidget);
        expect(find.text('Show less'), findsNothing);
      });
    });

    group('Action Label', () {
      testWidgets('keeps localized label inside a narrow scaled viewport', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        const locale = Locale('it');
        final l10n = lookupAppLocalizations(locale);

        await tester.pumpWidget(
          buildTestWidget(
            userIdHex: testUserHex,
            isOwnProfile: true,
            profile: createTestProfile(displayName: 'Test User'),
            isAnonymous: true,
            textScaler: const TextScaler.linear(2),
            locale: locale,
          ),
        );
        await tester.pumpAndSettle();

        final label = find.text(l10n.profileSecureYourAccount);
        final labelRect = tester.getRect(label);
        expect(labelRect.left, greaterThanOrEqualTo(0));
        expect(
          labelRect.right,
          lessThanOrEqualTo(tester.view.physicalSize.width),
        );
      });

      testWidgets('shows Secure label when anonymous with custom name', (
        tester,
      ) async {
        final testProfile = createTestProfile(displayName: 'Test User');

        await tester.pumpWidget(
          buildTestWidget(
            userIdHex: testUserHex,
            isOwnProfile: true,
            profile: testProfile,
            isAnonymous: true,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(enL10n.profileSecureYourAccount), findsOneWidget);
        // 1 action — badge shows "1"
        expect(find.text('1'), findsOneWidget);
      });

      testWidgets(
        'shows Secure label with count badge when anonymous and no name',
        (tester) async {
          final profileWithDefaultName = createTestProfile();

          await tester.pumpWidget(
            buildTestWidget(
              userIdHex: testUserHex,
              isOwnProfile: true,
              profile: profileWithDefaultName,
              isAnonymous: true,
            ),
          );
          await tester.pumpAndSettle();

          // Secure takes precedence
          expect(find.text(enL10n.profileSecureYourAccount), findsOneWidget);
          // 2 actions — red badge with "2"
          expect(find.text('2'), findsOneWidget);
        },
      );

      testWidgets('hides label when not anonymous and has custom name', (
        tester,
      ) async {
        final testProfile = createTestProfile(displayName: 'Test User');

        await tester.pumpWidget(
          buildTestWidget(
            userIdHex: testUserHex,
            isOwnProfile: true,
            profile: testProfile,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(enL10n.profileSecureYourAccount), findsNothing);
        expect(find.text(enL10n.profileCompleteYourProfile), findsNothing);
      });

      testWidgets('hides label for other profiles even when anonymous', (
        tester,
      ) async {
        final testProfile = createTestProfile(displayName: 'Test User');

        await tester.pumpWidget(
          buildTestWidget(
            userIdHex: testUserHex,
            isOwnProfile: false,
            profile: testProfile,
            isAnonymous: true,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(enL10n.profileSecureYourAccount), findsNothing);
      });

      testWidgets('shows a persistent restriction before setup actions', (
        tester,
      ) async {
        final mockGoRouter = MockGoRouter();
        when(() => mockGoRouter.push(any())).thenAnswer((_) async => null);

        await tester.pumpWidget(
          buildTestWidget(
            userIdHex: testUserHex,
            isOwnProfile: true,
            profile: createTestProfile(),
            isAnonymous: true,
            isAccountEnforced: true,
            goRouter: mockGoRouter,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(enL10n.profileAccountRestricted), findsOneWidget);
        expect(find.text('2'), findsNothing);
        expect(find.text('3'), findsOneWidget);

        await tester.tap(find.text(enL10n.profileAccountRestricted));
        await tester.pumpAndSettle();

        verify(() => mockGoRouter.push(RoutePaths.accountStatus)).called(1);
        expect(find.byType(ProfileActionsSheetContent), findsNothing);
      });

      testWidgets('healthy own profile has no restriction action', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(
            userIdHex: testUserHex,
            isOwnProfile: true,
            profile: createTestProfile(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(enL10n.profileAccountRestricted), findsNothing);
      });

      testWidgets('secure-account dismissal does not hide a restriction', (
        tester,
      ) async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(
          SecureAccountPromptDismissalStore.keyFor(testUserHex),
          true,
        );

        await tester.pumpWidget(
          buildTestWidget(
            userIdHex: testUserHex,
            isOwnProfile: true,
            profile: createTestProfile(),
            isAnonymous: true,
            isAccountEnforced: true,
            sharedPreferences: prefs,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(enL10n.profileAccountRestricted), findsOneWidget);
      });

      testWidgets('never shows the restriction action on another profile', (
        tester,
      ) async {
        var enforcementReads = 0;
        await tester.pumpWidget(
          buildTestWidget(
            userIdHex: testUserHex,
            isOwnProfile: false,
            profile: createTestProfile(displayName: 'Test User'),
            isAccountEnforced: true,
            onEnforcementRead: () => enforcementReads++,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(enL10n.profileAccountRestricted), findsNothing);
        expect(enforcementReads, 0);
      });

      testWidgets('tapping label opens actions bottom sheet', (tester) async {
        final profileWithDefaultName = createTestProfile();

        await tester.pumpWidget(
          buildTestWidget(
            userIdHex: testUserHex,
            isOwnProfile: true,
            profile: profileWithDefaultName,
            isAnonymous: true,
          ),
        );
        await tester.pumpAndSettle();

        // Tap on the action label
        await tester.tap(find.text(enL10n.profileSecureYourAccount));
        await tester.pumpAndSettle();

        // The pill and the sheet title share one ARB key, so scope the
        // title to the sheet rather than counting matches.
        expect(
          find.descendant(
            of: find.byType(ProfileActionsSheetContent),
            matching: find.text(enL10n.profileSecureYourAccount),
          ),
          findsOneWidget,
        );
        expect(find.text(enL10n.profileSecurePrimaryButton), findsOneWidget);
        expect(find.text(enL10n.profileMaybeLaterLabel), findsOneWidget);
      });

      testWidgets('Maybe Later permanently hides the secure-account action', (
        tester,
      ) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final testProfile = createTestProfile(displayName: 'Test User');

        Widget buildHeader() => buildTestWidget(
          userIdHex: testUserHex,
          isOwnProfile: true,
          profile: testProfile,
          isAnonymous: true,
          sharedPreferences: prefs,
        );

        await tester.pumpWidget(buildHeader());
        await tester.pumpAndSettle();
        await tester.tap(find.text(enL10n.profileSecureYourAccount));
        await tester.pumpAndSettle();
        await tester.tap(find.text(enL10n.profileMaybeLaterLabel));
        await tester.pumpAndSettle();

        expect(find.text(enL10n.profileSecureYourAccount), findsNothing);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(buildHeader());
        await tester.pumpAndSettle();

        expect(find.text(enL10n.profileSecureYourAccount), findsNothing);
      });

      testWidgets('Maybe Later leaves the complete-profile action pending', (
        tester,
      ) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();

        await tester.pumpWidget(
          buildTestWidget(
            userIdHex: testUserHex,
            isOwnProfile: true,
            // Default name and no picture/bio/NIP-05, so both actions pend.
            profile: createTestProfile(),
            isAnonymous: true,
            sharedPreferences: prefs,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('2'), findsOneWidget);

        await tester.tap(find.text(enL10n.profileSecureYourAccount));
        await tester.pumpAndSettle();

        // Dismiss secure-account, then the complete-profile prompt behind it.
        await tester.tap(find.text(enL10n.profileMaybeLaterLabel));
        await tester.pump(const Duration(milliseconds: 700));
        await tester.pumpAndSettle();
        await tester.tap(find.text(enL10n.profileMaybeLaterLabel));
        await tester.pumpAndSettle();

        expect(find.text(enL10n.profileSecureYourAccount), findsNothing);
        expect(find.text(enL10n.profileCompleteYourProfile), findsOneWidget);
        expect(find.text('1'), findsOneWidget);
      });
    });

    group('Session Expired', () {
      testWidgets(
        'shows session expired bottom sheet when session is expired',
        (tester) async {
          final testProfile = createTestProfile(displayName: 'Test User');
          SharedPreferences.setMockInitialValues({});
          final prefs = await SharedPreferences.getInstance();

          await tester.pumpWidget(
            buildTestWidget(
              userIdHex: testUserHex,
              isOwnProfile: true,
              profile: testProfile,
              hasExpiredSession: true,
              sharedPreferences: prefs,
            ),
          );
          await tester.pumpAndSettle();

          // Bottom sheet shows session expired prompt (button copy sourced
          // from the existing profileSignInButton ARB key, which is "Sign in").
          // The action-button pill in the header also surfaces "Session
          // Expired" / "Sign in" / "Maybe Later" via the actions list, so
          // assert at least one of each — finding all three at the same time
          // confirms the sheet itself opened.
          final l10n = lookupAppLocalizations(const Locale('en'));
          expect(find.text(l10n.profileSessionExpired), findsWidgets);
          expect(find.text(l10n.profileSignInButton), findsWidgets);
          expect(find.text(l10n.profileMaybeLaterLabel), findsWidgets);
        },
      );

      testWidgets(
        'presents the session expired sheet once while the session stays '
        'expired',
        (tester) async {
          // Regression for #7308: the sheet was scheduled from build(), and
          // the condition stays true for as long as the session is expired,
          // so every qualifying rebuild pushed another identical sheet route
          // and the user had to dismiss the same prompt repeatedly.
          final testProfile = createTestProfile(displayName: 'Test User');
          SharedPreferences.setMockInitialValues({});
          final prefs = await SharedPreferences.getInstance();

          await tester.pumpWidget(
            buildTestWidget(
              userIdHex: testUserHex,
              isOwnProfile: true,
              profile: testProfile,
              hasExpiredSession: true,
              sharedPreferences: prefs,
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byType(VineBottomSheetPrompt), findsOneWidget);

          // Rebuild the header with the session still expired. That is the
          // same expiry, not a new one, so no second sheet may be pushed.
          await tester.pumpWidget(
            buildTestWidget(
              userIdHex: testUserHex,
              isOwnProfile: true,
              profile: testProfile,
              hasExpiredSession: true,
              sharedPreferences: prefs,
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byType(VineBottomSheetPrompt), findsOneWidget);
        },
      );

      testWidgets(
        'does not stack a second sheet when the RPC upgrade flag flickers',
        (tester) async {
          // Regression for #7308: `isRpcUpgradeInProgress` goes true then
          // false on every app resume while the session is expired, so the
          // condition genuinely transitions false -> true again while the
          // first sheet is still on screen. Edge detection alone would push a
          // second sheet on top of it.
          final testProfile = createTestProfile(displayName: 'Test User');
          SharedPreferences.setMockInitialValues({});
          final prefs = await SharedPreferences.getInstance();

          Widget build({required bool isRpcUpgradeInProgress}) =>
              buildTestWidget(
                userIdHex: testUserHex,
                isOwnProfile: true,
                profile: testProfile,
                hasExpiredSession: true,
                isRpcUpgradeInProgress: isRpcUpgradeInProgress,
                sharedPreferences: prefs,
              );

          await tester.pumpWidget(build(isRpcUpgradeInProgress: false));
          await tester.pumpAndSettle();
          expect(find.byType(VineBottomSheetPrompt), findsOneWidget);

          // App resumes: the background RPC upgrade starts, then fails.
          await tester.pumpWidget(build(isRpcUpgradeInProgress: true));
          await tester.pumpAndSettle();
          await tester.pumpWidget(build(isRpcUpgradeInProgress: false));
          await tester.pumpAndSettle();

          expect(find.byType(VineBottomSheetPrompt), findsOneWidget);
        },
      );

      testWidgets('presents the session expired sheet when it expires while '
          'the profile is open', (tester) async {
        // Covers the didUpdateWidget arm: the header mounted on a live
        // session, so initState did not present.
        final testProfile = createTestProfile(displayName: 'Test User');
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();

        await tester.pumpWidget(
          buildTestWidget(
            userIdHex: testUserHex,
            isOwnProfile: true,
            profile: testProfile,
            sharedPreferences: prefs,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(VineBottomSheetPrompt), findsNothing);

        await tester.pumpWidget(
          buildTestWidget(
            userIdHex: testUserHex,
            isOwnProfile: true,
            profile: testProfile,
            hasExpiredSession: true,
            sharedPreferences: prefs,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(VineBottomSheetPrompt), findsOneWidget);
      });

      testWidgets(
        'does not show session expired sheet when dismissed within 30 days',
        (tester) async {
          final testProfile = createTestProfile(displayName: 'Test User');
          final dismissedAt = DateTime.now()
              .subtract(const Duration(days: 29))
              .millisecondsSinceEpoch;

          SharedPreferences.setMockInitialValues({
            _dismissedDivineLoginBannerKey: dismissedAt,
          });
          final prefs = await SharedPreferences.getInstance();

          await tester.pumpWidget(
            buildTestWidget(
              userIdHex: testUserHex,
              isOwnProfile: true,
              profile: testProfile,
              hasExpiredSession: true,
              sharedPreferences: prefs,
            ),
          );
          await tester.pumpAndSettle();

          expect(
            find.text(
              lookupAppLocalizations(const Locale('en')).profileSessionExpired,
            ),
            findsNothing,
          );
        },
      );

      testWidgets(
        'shows secure account label for anonymous users with expired session',
        (tester) async {
          final testProfile = createTestProfile(displayName: 'Test User');
          SharedPreferences.setMockInitialValues({});
          final prefs = await SharedPreferences.getInstance();

          await tester.pumpWidget(
            buildTestWidget(
              userIdHex: testUserHex,
              isOwnProfile: true,
              profile: testProfile,
              isAnonymous: true,
              hasExpiredSession: true,
              sharedPreferences: prefs,
            ),
          );
          await tester.pumpAndSettle();

          // Anonymous users see the action label pill, not session expired
          expect(find.text(enL10n.profileSecureYourAccount), findsOneWidget);
          expect(find.text(enL10n.profileSessionExpired), findsNothing);
        },
      );

      testWidgets(
        'does not show session expired sheet while RPC upgrade is in progress',
        (tester) async {
          // Regression for #4626: the sheet must be suppressed while a
          // background OAuth upgrade is still in flight to avoid routing the
          // user to /welcome/login-options before the silent refresh has had a
          // chance to complete.
          final testProfile = createTestProfile(displayName: 'Test User');
          SharedPreferences.setMockInitialValues({});
          final prefs = await SharedPreferences.getInstance();

          await tester.pumpWidget(
            buildTestWidget(
              userIdHex: testUserHex,
              isOwnProfile: true,
              profile: testProfile,
              hasExpiredSession: true,
              isRpcUpgradeInProgress: true,
              sharedPreferences: prefs,
            ),
          );
          await tester.pumpAndSettle();

          // Sheet must NOT appear while upgrade is running.
          final l10n = lookupAppLocalizations(const Locale('en'));
          expect(find.text(l10n.profileSessionExpired), findsNothing);
          expect(find.text(l10n.profileSignInButton), findsNothing);
          expect(find.text(l10n.profileMaybeLaterLabel), findsNothing);
        },
      );

      testWidgets('sheet does not appear after successful RPC upgrade clears the '
          'expired-session flag', (tester) async {
        // Regression for #4626: when the background upgrade succeeds the
        // session-expired flag is cleared. The widget must not show the sheet
        // at any point — neither while the upgrade is running (suppressed by
        // isRpcUpgradeInProgress) nor after it succeeds (hasExpiredOAuthSession
        // is false).
        final testProfile = createTestProfile(displayName: 'Test User');
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();

        // Phase 1: session expired, upgrade in progress → sheet suppressed.
        await tester.pumpWidget(
          buildTestWidget(
            userIdHex: testUserHex,
            isOwnProfile: true,
            profile: testProfile,
            hasExpiredSession: true,
            isRpcUpgradeInProgress: true,
            sharedPreferences: prefs,
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(
            lookupAppLocalizations(const Locale('en')).profileSessionExpired,
          ),
          findsNothing,
        );

        // Phase 2: upgrade succeeds — session flag cleared.
        // Rebuild with hasExpiredSession: false to simulate what happens
        // after a successful upgrade nudges the widget to re-evaluate.
        await tester.pumpWidget(
          buildTestWidget(
            userIdHex: testUserHex,
            isOwnProfile: true,
            profile: testProfile,
            sharedPreferences: prefs,
          ),
        );
        await tester.pumpAndSettle();

        // Sheet must not appear — session is no longer expired.
        expect(
          find.text(
            lookupAppLocalizations(const Locale('en')).profileSessionExpired,
          ),
          findsNothing,
        );
      });

      testWidgets(
        'defers nav to login-options until background upload finishes '
        'when refresh fails and upload is in progress',
        (tester) async {
          // Regression for #4626: tapping "Sign in" when an upload is active
          // must not navigate immediately. Navigation is deferred until the
          // BackgroundPublishBloc's hasUploadInProgress becomes false.
          final testProfile = createTestProfile(displayName: 'Test User');
          SharedPreferences.setMockInitialValues({});
          final prefs = await SharedPreferences.getInstance();

          // Simulate an in-flight upload followed by completion.
          final publishStreamController =
              StreamController<BackgroundPublishState>();
          addTearDown(publishStreamController.close);

          final mockPublishBloc = _MockBackgroundPublishBloc();
          // Upload is in progress initially.
          final inProgressState = BackgroundPublishState(
            uploads: [
              BackgroundUpload(
                draft: _FakeDraft(),
                result: null,
                progress: 0.5,
              ),
            ],
          );
          when(() => mockPublishBloc.state).thenReturn(inProgressState);
          whenListen(
            mockPublishBloc,
            publishStreamController.stream,
            initialState: inProgressState,
          );

          final authService = MockAuthService(
            hasExpiredOAuthSessionValue: true,
            // tryRefreshResult defaults to false — refresh will fail
          );

          // Use a mock GoRouter so go() calls are verifiable, not errors.
          final mockGoRouter = MockGoRouter();
          when(() => mockGoRouter.go(any())).thenReturn(null);
          final badgeRepository = _MockBadgeRepository();
          when(
            () => badgeRepository.loadAcceptedBadgesForProfile(any()),
          ).thenAnswer((_) async => const []);

          await tester.pumpWidget(
            MockGoRouterProvider(
              goRouter: mockGoRouter,
              child: ProviderScope(
                overrides: [
                  ...getStandardTestOverrides(
                    mockNostrService: mockNostrClient,
                    mockSharedPreferences: prefs,
                    mockNip05VerificationService:
                        createMockNip05VerificationService(),
                    mockFollowRepository: mockFollowRepository,
                  ),
                  fetchUserProfileProvider(
                    testUserHex,
                  ).overrideWith((ref) async => testProfile),
                  userProfileStatsReactiveProvider(
                    testUserHex,
                  ).overrideWith((ref) => const Stream.empty()),
                  authServiceProvider.overrideWithValue(authService),
                  badgeRepositoryProvider.overrideWithValue(badgeRepository),
                  currentAuthStateProvider.overrideWith(
                    (ref) => AuthState.authenticated,
                  ),
                  isFeatureEnabledProvider(
                    FeatureFlag.curatedLists,
                  ).overrideWith((ref) => false),
                ],
                child: MaterialApp(
                  localizationsDelegates: appLocalizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  home: BlocProvider<BackgroundPublishBloc>.value(
                    value: mockPublishBloc,
                    child: BlocProvider<MyProfileBloc>(
                      create: (_) {
                        final bloc = _MockMyProfileBloc();
                        when(
                          () => bloc.state,
                        ).thenReturn(MyProfileUpdated(profile: testProfile));
                        return bloc;
                      },
                      child: const Scaffold(
                        body: SingleChildScrollView(
                          child: ProfileHeaderWidget(
                            userIdHex: testUserHex,
                            isOwnProfile: true,
                            videoCount: 0,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Session expired sheet should be visible.
          final l10n = lookupAppLocalizations(const Locale('en'));
          expect(find.text(l10n.profileSessionExpired), findsWidgets);

          // Tap "Sign in" — triggers tryRefreshExpiredSession (returns false)
          // and the upload-in-progress guard should subscribe for deferred nav.
          await tester.tap(find.text(l10n.profileSignInButton).last);
          await tester.pumpAndSettle();

          // Navigation must NOT have fired yet — upload is still active.
          verifyNever(() => mockGoRouter.go(any()));

          // Simulate upload completing.
          publishStreamController.add(const BackgroundPublishState());
          await tester.pump();

          // Navigation must now have fired exactly once to login-options.
          verify(
            () => mockGoRouter.go(any(that: contains('login-options'))),
          ).called(1);
        },
      );

      testWidgets(
        'navigates immediately when upload finishes before stream listener '
        'attaches — regression for check/listen race',
        (tester) async {
          // Regression: the upload completes between the state read and the
          // stream.listen() call. With the old code (check-then-listen), no
          // further emission would arrive and navigation would be silently lost.
          // With the fix (listen-then-recheck), the recheck fires navigation.
          final testProfile = createTestProfile(displayName: 'Test User');
          SharedPreferences.setMockInitialValues({});
          final prefs = await SharedPreferences.getInstance();

          // Bloc already has no upload in progress — simulates upload having
          // finished just before _navigateToLoginOptionsAfterUpload attaches.
          final mockPublishBloc = _MockBackgroundPublishBloc();
          when(
            () => mockPublishBloc.state,
          ).thenReturn(const BackgroundPublishState());
          // Stream produces no further emissions — the critical race condition.
          whenListen(
            mockPublishBloc,
            const Stream<BackgroundPublishState>.empty(),
            initialState: const BackgroundPublishState(),
          );

          final authService = MockAuthService(
            hasExpiredOAuthSessionValue: true,
            // tryRefreshResult defaults to false — refresh will fail.
          );

          final mockGoRouter = MockGoRouter();
          when(() => mockGoRouter.go(any())).thenReturn(null);
          final badgeRepository = _MockBadgeRepository();
          when(
            () => badgeRepository.loadAcceptedBadgesForProfile(any()),
          ).thenAnswer((_) async => const []);

          await tester.pumpWidget(
            MockGoRouterProvider(
              goRouter: mockGoRouter,
              child: ProviderScope(
                overrides: [
                  ...getStandardTestOverrides(
                    mockNostrService: mockNostrClient,
                    mockSharedPreferences: prefs,
                    mockNip05VerificationService:
                        createMockNip05VerificationService(),
                    mockFollowRepository: mockFollowRepository,
                  ),
                  fetchUserProfileProvider(
                    testUserHex,
                  ).overrideWith((ref) async => testProfile),
                  userProfileStatsReactiveProvider(
                    testUserHex,
                  ).overrideWith((ref) => const Stream.empty()),
                  authServiceProvider.overrideWithValue(authService),
                  badgeRepositoryProvider.overrideWithValue(badgeRepository),
                  currentAuthStateProvider.overrideWith(
                    (ref) => AuthState.authenticated,
                  ),
                  isFeatureEnabledProvider(
                    FeatureFlag.curatedLists,
                  ).overrideWith((ref) => false),
                ],
                child: MaterialApp(
                  localizationsDelegates: appLocalizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  home: BlocProvider<BackgroundPublishBloc>.value(
                    value: mockPublishBloc,
                    child: BlocProvider<MyProfileBloc>(
                      create: (_) {
                        final bloc = _MockMyProfileBloc();
                        when(
                          () => bloc.state,
                        ).thenReturn(MyProfileUpdated(profile: testProfile));
                        return bloc;
                      },
                      child: const Scaffold(
                        body: SingleChildScrollView(
                          child: ProfileHeaderWidget(
                            userIdHex: testUserHex,
                            isOwnProfile: true,
                            videoCount: 0,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final l10n = lookupAppLocalizations(const Locale('en'));
          expect(find.text(l10n.profileSessionExpired), findsWidgets);

          // Tap "Sign in" — triggers the deferred-nav helper.
          await tester.tap(find.text(l10n.profileSignInButton).last);
          await tester.pumpAndSettle();

          // Navigation must have fired immediately — re-check after subscribe
          // detected no upload in progress (no stream emission needed).
          verify(
            () => mockGoRouter.go(any(that: contains('login-options'))),
          ).called(1);
        },
      );

      testWidgets('"Maybe later" closes the sheet and persists the dismissal', (
        tester,
      ) async {
        // The ordinary, still-mounted path. Nothing asserted the outcome of
        // this tap before #7297 reworked the callback.
        final testProfile = createTestProfile(displayName: 'Test User');
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();

        await tester.pumpWidget(
          buildTestWidget(
            userIdHex: testUserHex,
            isOwnProfile: true,
            profile: testProfile,
            hasExpiredSession: true,
            sharedPreferences: prefs,
          ),
        );
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.byType(VineBottomSheetPrompt), findsOneWidget);

        await tester.tap(find.text(l10n.profileMaybeLaterLabel).last);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(prefs.getInt(_dismissedDivineLoginBannerKey), isNotNull);
        expect(find.byType(VineBottomSheetPrompt), findsNothing);
      });

      testWidgets('dismisses via "Maybe later" after the header unmounts', (
        tester,
      ) async {
        // Regression for #7297: the sheet is a route, so it stays on screen
        // and tappable after the header unmounts (the profile shell route
        // collapses its content as soon as the URL moves on). The buttons
        // resolved `ref` at tap time, so the tap threw `Using "ref" when a
        // widget is about to or has been unmounted is unsafe` and the
        // dismissal was silently dropped.
        final testProfile = createTestProfile(displayName: 'Test User');
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();

        await tester.pumpWidget(
          buildTestWidget(
            userIdHex: testUserHex,
            isOwnProfile: true,
            profile: testProfile,
            hasExpiredSession: true,
            sharedPreferences: prefs,
          ),
        );
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.text(l10n.profileSessionExpired), findsWidgets);

        // Unmount the header, leaving the sheet route standing.
        await tester.pumpWidget(
          buildTestWidget(
            userIdHex: testUserHex,
            isOwnProfile: true,
            profile: testProfile,
            hasExpiredSession: true,
            sharedPreferences: prefs,
            renderHeader: false,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ProfileHeaderWidget), findsNothing);
        expect(find.byType(VineBottomSheetPrompt), findsOneWidget);

        await tester.tap(find.text(l10n.profileMaybeLaterLabel).last);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(prefs.getInt(_dismissedDivineLoginBannerKey), isNotNull);
        expect(find.byType(VineBottomSheetPrompt), findsNothing);
      });

      testWidgets('signs in from the sheet after the header unmounts', (
        tester,
      ) async {
        // Regression for #7297, primary action: the tap ran
        // `Navigator.of(context)` on the unmounted header's context. The sheet
        // must close and the refresh must run; navigation to login-options is
        // deliberately abandoned, because the deferred navigator is disposed
        // with the header and the user has already moved on to another screen.
        final testProfile = createTestProfile(displayName: 'Test User');
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final mockGoRouter = MockGoRouter();
        when(() => mockGoRouter.go(any())).thenReturn(null);
        final authService = MockAuthService(hasExpiredOAuthSessionValue: true);

        await tester.pumpWidget(
          buildTestWidget(
            userIdHex: testUserHex,
            isOwnProfile: true,
            profile: testProfile,
            hasExpiredSession: true,
            sharedPreferences: prefs,
            goRouter: mockGoRouter,
            authService: authService,
          ),
        );
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.text(l10n.profileSessionExpired), findsWidgets);

        await tester.pumpWidget(
          buildTestWidget(
            userIdHex: testUserHex,
            isOwnProfile: true,
            profile: testProfile,
            hasExpiredSession: true,
            sharedPreferences: prefs,
            goRouter: mockGoRouter,
            authService: authService,
            renderHeader: false,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ProfileHeaderWidget), findsNothing);
        expect(find.byType(VineBottomSheetPrompt), findsOneWidget);

        await tester.tap(find.text(l10n.profileSignInButton).last);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(VineBottomSheetPrompt), findsNothing);
        expect(authService.tryRefreshCallCount, 1);
        verifyNever(() => mockGoRouter.go(any()));
      });
    });

    group('MyProfile state fallbacks (own profile)', () {
      testWidgets('reads profile from MyProfileLoaded', (tester) async {
        final loadedProfile = createTestProfile(
          displayName: 'Loaded User',
          about: 'Bio from MyProfileLoaded',
        );

        await tester.pumpWidget(
          buildTestWidget(
            userIdHex: testUserHex,
            isOwnProfile: true,
            myProfileState: MyProfileLoaded(
              profile: loadedProfile,
              isFresh: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Loaded User'), findsOneWidget);
        expect(find.text('Bio from MyProfileLoaded'), findsOneWidget);
      });

      testWidgets('reads cached profile from MyProfileLoading', (tester) async {
        final cachedProfile = createTestProfile(
          displayName: 'Cached While Loading',
          about: 'Cached bio',
        );

        await tester.pumpWidget(
          buildTestWidget(
            userIdHex: testUserHex,
            isOwnProfile: true,
            myProfileState: MyProfileLoading(profile: cachedProfile),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Cached While Loading'), findsOneWidget);
        expect(find.text('Cached bio'), findsOneWidget);
      });

      testWidgets(
        'falls back to widget.profile when MyProfile state has no profile',
        (tester) async {
          // Bug fix: previously only MyProfileUpdated was read; with
          // MyProfileLoading(profile: null) the header rendered an empty
          // shell even though the parent already had a cached profile.
          final fallbackProfile = createTestProfile(
            displayName: 'From Widget Param',
            about: 'Parent-supplied bio',
          );

          await tester.pumpWidget(
            buildTestWidget(
              userIdHex: testUserHex,
              isOwnProfile: true,
              suppliedProfile: fallbackProfile,
              myProfileState: const MyProfileLoading(),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('From Widget Param'), findsOneWidget);
          expect(find.text('Parent-supplied bio'), findsOneWidget);
        },
      );
    });

    group('Identity skeleton (#4163)', () {
      // Asserts the wiring contract from `_ProfileHeaderWidgetState.build`:
      // when the profile is still loading and there is no cached fallback,
      // the avatar + name/bio block is wrapped in an enabled Skeletonizer.
      // Static chrome (stats row, action buttons, people-list pill) sits
      // OUTSIDE the identity Skeletonizer so it stays both visible and
      // interactive during the loading window — pinned at the end of this
      // group.
      //
      // The header subtree always contains 2 Skeletonizers at runtime: the
      // identity one (over avatar + name/bio) and the stats one (inside
      // _ProfileStatsRow, gated on profileStats == null). The identity
      // Skeletonizer is the first one encountered in widget order.

      Skeletonizer findIdentitySkeletonizer(WidgetTester tester) {
        final matches = tester
            .widgetList<Skeletonizer>(
              find.descendant(
                of: find.byType(ProfileHeaderWidget),
                matching: find.bySubtype<Skeletonizer>(),
              ),
            )
            .toList();
        expect(
          matches,
          isNotEmpty,
          reason: 'Expected at least one Skeletonizer in the header subtree',
        );
        return matches.first;
      }

      testWidgets(
        'own profile + MyProfileInitial → Skeletonizer.enabled = true',
        (tester) async {
          await tester.pumpWidget(
            buildTestWidget(
              userIdHex: testUserHex,
              isOwnProfile: true,
              myProfileState: const MyProfileInitial(),
            ),
          );
          await tester.pump();

          expect(findIdentitySkeletonizer(tester).enabled, isTrue);
        },
      );

      testWidgets(
        'own profile with no MyProfileBloc ancestor → renders the identity '
        'skeleton instead of throwing (cold-start pre-scope window where '
        'profileRepository is not ready yet)',
        (tester) async {
          await tester.pumpWidget(
            buildTestWidget(
              userIdHex: testUserHex,
              isOwnProfile: true,
              provideMyProfileBloc: false,
            ),
          );
          await tester.pump();

          expect(tester.takeException(), isNull);
          expect(findIdentitySkeletonizer(tester).enabled, isTrue);
        },
      );

      testWidgets('own profile + MyProfileLoading(profile: null) → '
          'Skeletonizer.enabled = true', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            userIdHex: testUserHex,
            isOwnProfile: true,
            myProfileState: const MyProfileLoading(),
          ),
        );
        await tester.pump();

        expect(findIdentitySkeletonizer(tester).enabled, isTrue);
      });

      testWidgets(
        'own profile + MyProfileLoading(profile: cached) → '
        'Skeletonizer.enabled = false (we have data to show, do not skeleton)',
        (tester) async {
          final cached = createTestProfile(displayName: 'Cached Display Name');

          await tester.pumpWidget(
            buildTestWidget(
              userIdHex: testUserHex,
              isOwnProfile: true,
              myProfileState: MyProfileLoading(profile: cached),
            ),
          );
          await tester.pump();

          expect(findIdentitySkeletonizer(tester).enabled, isFalse);
        },
      );

      testWidgets(
        'own profile + MyProfileError(notFound) → Skeletonizer.enabled = false '
        '(steady-state generated fallback path is preserved)',
        (tester) async {
          await tester.pumpWidget(
            buildTestWidget(
              userIdHex: testUserHex,
              isOwnProfile: true,
              myProfileState: const MyProfileError(
                errorType: MyProfileErrorType.notFound,
              ),
            ),
          );
          await tester.pump();

          expect(findIdentitySkeletonizer(tester).enabled, isFalse);
        },
      );

      testWidgets(
        'own profile + MyProfileLoaded(profile) → Skeletonizer.enabled = false',
        (tester) async {
          final loaded = createTestProfile(displayName: 'Loaded Display Name');

          await tester.pumpWidget(
            buildTestWidget(
              userIdHex: testUserHex,
              isOwnProfile: true,
              myProfileState: MyProfileLoaded(profile: loaded, isFresh: true),
            ),
          );
          await tester.pump();

          expect(findIdentitySkeletonizer(tester).enabled, isFalse);
        },
      );

      testWidgets('other profile + suppliedProfile non-null → '
          'Skeletonizer.enabled = false (caller already has data)', (
        tester,
      ) async {
        final supplied = createTestProfile(displayName: 'Bob');

        await tester.pumpWidget(
          buildTestWidget(
            userIdHex: testUserHex,
            isOwnProfile: false,
            suppliedProfile: supplied,
          ),
        );
        await tester.pump();

        expect(findIdentitySkeletonizer(tester).enabled, isFalse);
      });

      testWidgets(
        'skeleton dissolves to fallback after the 7s timeout — even when '
        'the parent still says loading',
        (tester) async {
          await tester.pumpWidget(
            buildTestWidget(
              userIdHex: testUserHex,
              isOwnProfile: true,
              myProfileState: const MyProfileInitial(),
            ),
          );
          await tester.pump();

          // Before timeout — Skeletonizer is enabled.
          expect(findIdentitySkeletonizer(tester).enabled, isTrue);

          // Advance past the 7-second skeleton timeout (mirrors the
          // pattern used by _ProfileStatsRow's existing test).
          await tester.pump(const Duration(seconds: 8));
          await tester.pumpAndSettle();

          // After timeout — Skeletonizer flips back to disabled even
          // though the bloc is still in an initial state. This is what
          // lets users who genuinely have no Kind 0 still see the
          // generated-name fallback rather than an infinite shimmer.
          expect(findIdentitySkeletonizer(tester).enabled, isFalse);
        },
      );

      testWidgets('stats row and action buttons sit outside the identity '
          'Skeletonizer so they stay tappable during the loading window', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(
            userIdHex: testUserHex,
            isOwnProfile: true,
            myProfileState: const MyProfileInitial(),
          ),
        );
        await tester.pump();

        // The identity Skeletonizer is the first descendant of the
        // header. Anything that should stay interactive during the
        // loading window must NOT be a descendant of it.
        final identitySkeletonizer = find
            .descendant(
              of: find.byType(ProfileHeaderWidget),
              matching: find.bySubtype<Skeletonizer>(),
            )
            .first;

        expect(
          find.descendant(
            of: identitySkeletonizer,
            matching: find.byType(ProfileActionButtons),
          ),
          findsNothing,
          reason:
              'ProfileActionButtons (Library/edit/share) must live outside '
              'the identity Skeletonizer so the buttons remain tappable '
              'during the loading window (#4183 review).',
        );

        // _ProfileStatsRow is private; the stat columns it renders are
        // the proxy. Their location relative to the identity skeleton
        // is what matters.
        expect(
          find.descendant(
            of: identitySkeletonizer,
            matching: find.byType(ProfileStatColumn),
          ),
          findsNothing,
          reason:
              'Stats columns must live outside the identity Skeletonizer '
              'so the followers/following/likes/loops counts remain '
              'tappable during the loading window (#4183 review).',
        );
      });

      testWidgets('avatar is swapped for a flat bone while the identity '
          'skeleton is enabled', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            userIdHex: testUserHex,
            isOwnProfile: true,
            myProfileState: const MyProfileInitial(),
          ),
        );
        await tester.pump();

        expect(findIdentitySkeletonizer(tester).enabled, isTrue);
        expect(
          find.byType(UserAvatar),
          findsNothing,
          reason:
              'Skeletonizer keeps the decoration of containers that have '
              'children, so leaving the real UserAvatar in the tree shimmers '
              'its generated placeholder art (gradient tile + person '
              'silhouette) instead of a plain bone.',
        );
        expect(find.byType(BrandedLoadingIndicator), findsOneWidget);
      });

      testWidgets('avatar comes back once the identity skeleton is disabled', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(
            userIdHex: testUserHex,
            isOwnProfile: true,
            myProfileState: MyProfileLoaded(
              profile: createTestProfile(displayName: 'Loaded'),
              isFresh: true,
            ),
          ),
        );
        await tester.pump();

        expect(findIdentitySkeletonizer(tester).enabled, isFalse);
        expect(find.byType(UserAvatar), findsOneWidget);
      });

      testWidgets(
        'never mounts two avatar Heroes while the skeleton cross-fades out',
        (tester) async {
          // The hint carries the avatar URL through the loading window (the
          // feed → profile path), so the Hero is already mounted while the
          // skeleton is on. Without it there is no Hero to double.
          const avatarUrl = 'https://example.com/avatar.png';

          await tester.pumpWidget(
            buildTestWidget(
              userIdHex: testUserHex,
              isOwnProfile: true,
              avatarUrlHint: avatarUrl,
              myProfileState: const MyProfileInitial(),
            ),
          );
          await tester.pump();
          expect(findIdentitySkeletonizer(tester).enabled, isTrue);

          await tester.pumpWidget(
            buildTestWidget(
              userIdHex: testUserHex,
              isOwnProfile: true,
              avatarUrlHint: avatarUrl,
              myProfileState: MyProfileLoaded(
                profile: createTestProfile(
                  displayName: 'Loaded',
                  picture: avatarUrl,
                ),
                isFresh: true,
              ),
            ),
          );

          // enableSwitchAnimation keeps both halves of the AnimatedSwitcher
          // mounted for the length of the cross-fade. Selecting the bone off
          // Skeletonizer's own scope (as Skeleton.replace does) rebuilds the
          // outgoing half into the real avatar too, and two Heroes sharing a
          // tag in one subtree trip Hero's duplicate-tag assert on the next
          // route push.
          final heroFinder = find.byWidgetPredicate(
            (widget) =>
                widget is Hero &&
                widget.tag == 'profile_avatar_hero_$testUserHex',
          );
          for (final step in const [
            Duration.zero,
            Duration(milliseconds: 50),
            Duration(milliseconds: 100),
            Duration(milliseconds: 100),
            Duration(milliseconds: 200),
          ]) {
            await tester.pump(step);
            expect(
              heroFinder.evaluate().length,
              lessThanOrEqualTo(1),
              reason:
                  'Two avatar Heroes sharing '
                  'profile_avatar_hero_$testUserHex were mounted at once '
                  'during the skeleton cross-fade.',
            );
          }

          expect(heroFinder, findsOneWidget);
        },
      );
    });
  });

  group('buildProfileUrl', () {
    const testNpub =
        'npub10z98cqe5kehs5wfnax59vqzuyd7puhr2dyy0g5ha5kxc83h38yts0z3mgg';

    test('returns subdomain URL for divine.video NIP-05', () {
      expect(
        buildProfileUrl('_@thomassanders.divine.video', testNpub),
        equals('https://thomassanders.divine.video'),
      );
    });

    test('returns subdomain URL for user@subdomain.divine.video NIP-05', () {
      expect(
        buildProfileUrl('user@rabble.divine.video', testNpub),
        equals('https://rabble.divine.video'),
      );
    });

    test('returns npub profile URL for non-divine.video NIP-05', () {
      expect(
        buildProfileUrl('alice@example.com', testNpub),
        equals('https://divine.video/profile/$testNpub'),
      );
    });

    test('returns npub profile URL when NIP-05 is null', () {
      expect(
        buildProfileUrl(null, testNpub),
        equals('https://divine.video/profile/$testNpub'),
      );
    });

    test('returns npub profile URL when NIP-05 is empty', () {
      expect(
        buildProfileUrl('', testNpub),
        equals('https://divine.video/profile/$testNpub'),
      );
    });
  });
}
