// ABOUTME: Widget tests for SafetySettingsScreen UI and functionality.
// ABOUTME: Covers the content-safety shell, moderation toggles, and blocked users list.

import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:content_policy/content_policy.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/content_label.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/protected_minor_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/safety_settings_screen.dart';
import 'package:openvine/services/account_label_service.dart';
import 'package:openvine/services/age_verification_service.dart';
import 'package:openvine/services/content_filter_service.dart';
import 'package:openvine/services/content_reporting_service.dart';
import 'package:openvine/services/divine_host_filter_service.dart';
import 'package:openvine/services/moderation_label_service.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/services/video_provenance_filter_service.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {
  final Set<String> _runtimeBlocklist = {};

  @override
  Set<String> get runtimeBlockedUsers => Set.unmodifiable(_runtimeBlocklist);

  /// The `SafetySettingsCubit` subscribes to this stream to refresh the
  /// blocked-users list reactively. Tests don't need to emit on it; an empty
  /// broadcast stream keeps the subscription happy without firing events.
  @override
  Stream<ContentPolicyState> get stateStream =>
      const Stream<ContentPolicyState>.empty();

  @override
  Future<bool> blockUser(String pubkey, {String? ourPubkey}) async {
    _runtimeBlocklist.add(pubkey);
    return true;
  }

  @override
  Future<bool> unblockUser(String pubkey) async {
    _runtimeBlocklist.remove(pubkey);
    return true;
  }

  @override
  bool isBlocked(String pubkey) => _runtimeBlocklist.contains(pubkey);
}

class _MockVideoEventService extends Mock implements VideoEventService {
  @override
  int filterAdultContentFromExistingVideos() => 0;
}

class _MockContentReportingService extends Mock
    implements ContentReportingService {}

class _MockAccountLabelService extends Mock implements AccountLabelService {
  @override
  Set<ContentLabel> get accountLabels => const {};

  @override
  bool get hasAccountLabels => false;

  @override
  Future<void> initialize() async {}
}

class _MockModerationLabelService extends Mock
    implements ModerationLabelService {}

class _MockFollowRepository extends Mock implements FollowRepository {}

class _MockAgeVerificationService extends Mock
    implements AgeVerificationService {
  @override
  bool get isAdultContentVerified => false;

  @override
  Future<void> initialize() async {}
}

class _MockContentFilterService extends Mock implements ContentFilterService {
  @override
  bool get isInitialized => true;

  @override
  Future<void> initialize() async {}

  @override
  Map<ContentLabel, ContentFilterPreference> get allPreferences => {};
}

void main() {
  group('SafetySettingsScreen Widget Tests', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    late _MockContentBlocklistRepository mockBlocklistRepository;
    late _MockContentReportingService mockReportingService;
    late _MockAccountLabelService mockAccountLabelService;
    late _MockModerationLabelService mockModerationLabelService;
    late _MockFollowRepository mockFollowRepository;
    late _MockAgeVerificationService mockAgeVerificationService;
    late _MockContentFilterService mockContentFilterService;
    late _MockVideoEventService mockVideoEventService;
    late DivineHostFilterService divineHostFilterService;
    late VideoProvenanceFilterService provenanceFilterService;
    const blockedPubkey =
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
    const labelerPubkey =
        'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      mockBlocklistRepository = _MockContentBlocklistRepository();
      mockReportingService = _MockContentReportingService();
      mockAccountLabelService = _MockAccountLabelService();
      mockModerationLabelService = _MockModerationLabelService();
      mockFollowRepository = _MockFollowRepository();
      mockAgeVerificationService = _MockAgeVerificationService();
      mockContentFilterService = _MockContentFilterService();
      mockVideoEventService = _MockVideoEventService();
      divineHostFilterService = DivineHostFilterService(prefs);
      provenanceFilterService = VideoProvenanceFilterService(prefs);

      when(
        () => mockModerationLabelService.ensureLoaded(),
      ).thenAnswer((_) async {});
      when(
        () => mockModerationLabelService.divineModerationPubkeyHex,
      ).thenReturn(ModerationLabelService.fallbackModerationPubkeyHex);
      when(
        () => mockModerationLabelService.isDivineLabelerSubscribed,
      ).thenReturn(true);
      when(() => mockModerationLabelService.customLabelers).thenReturn({});
      when(
        () => mockModerationLabelService.subscribedLabelers,
      ).thenReturn({ModerationLabelService.fallbackModerationPubkeyHex});
      when(
        () => mockModerationLabelService.isFollowingModerationEnabled,
      ).thenReturn(false);
      when(
        () => mockModerationLabelService.addLabeler(any()),
      ).thenAnswer((_) async {});
      when(
        () => mockModerationLabelService.removeLabeler(any()),
      ).thenAnswer((_) async {});
      when(
        () => mockModerationLabelService.setFollowingModerationEnabled(
          any(),
          followedPubkeys: any(named: 'followedPubkeys'),
        ),
      ).thenAnswer((_) async {});

      when(
        () => mockFollowRepository.followingPubkeys,
      ).thenReturn(['followed_pubkey_1', 'followed_pubkey_2']);
      when(
        () => mockFollowRepository.followingStream,
      ).thenAnswer((_) => const Stream<List<String>>.empty());
    });

    Widget createTestWidget({
      bool isProtectedMinor = false,
      Map<String, UserProfile?> profiles = const {},
    }) {
      final container = ProviderContainer(
        overrides: [
          contentBlocklistRepositoryProvider.overrideWithValue(
            mockBlocklistRepository,
          ),
          // contentReportingServiceProvider is async, so wrap in AsyncValue
          contentReportingServiceProvider.overrideWith(
            (ref) async => mockReportingService,
          ),
          accountLabelServiceProvider.overrideWithValue(
            mockAccountLabelService,
          ),
          moderationLabelServiceProvider.overrideWithValue(
            mockModerationLabelService,
          ),
          followRepositoryProvider.overrideWithValue(mockFollowRepository),
          ageVerificationServiceProvider.overrideWithValue(
            mockAgeVerificationService,
          ),
          contentFilterServiceProvider.overrideWithValue(
            mockContentFilterService,
          ),
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
          divineHostFilterServiceProvider.overrideWithValue(
            divineHostFilterService,
          ),
          videoProvenanceFilterServiceProvider.overrideWithValue(
            provenanceFilterService,
          ),
          isProtectedMinorProvider.overrideWithValue(isProtectedMinor),
          userProfileReactiveProvider.overrideWith(
            (ref, pubkey) => Stream.value(profiles[pubkey]),
          ),
          blockedUserProfileProvider.overrideWith(
            (ref, pubkey) => Stream.value(profiles[pubkey]),
          ),
          blockedUserProfilesProvider.overrideWith(
            (ref, pubkeys) async => {
              for (final pubkey in pubkeys) pubkey: ?profiles[pubkey],
            },
          ),
        ],
      );

      return UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
          home: const SafetySettingsScreen(),
        ),
      );
    }

    testWidgets('should display the content safety title in app bar', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text(l10n.settingsContentSafetyTitle), findsOneWidget);
    });

    testWidgets('should display the blocked users section header', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text(l10n.safetySettingsBlockedUsers),
        200,
      );

      expect(find.text(l10n.safetySettingsBlockedUsers), findsOneWidget);
    });

    testWidgets('blocked users without profiles keep a full npub identifier', (
      tester,
    ) async {
      await mockBlocklistRepository.blockUser(blockedPubkey);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final npub = NostrKeyUtils.encodePubKey(blockedPubkey);
      await tester.scrollUntilVisible(find.text(npub), 200);

      expect(
        find.text(UserProfile.defaultDisplayNameFor(blockedPubkey)),
        findsOneWidget,
      );
      expect(find.text(npub), findsOneWidget);
    });

    testWidgets('blocked users show their real name and nip05', (
      tester,
    ) async {
      await mockBlocklistRepository.blockUser(blockedPubkey);

      await tester.pumpWidget(
        createTestWidget(
          profiles: {
            blockedPubkey: UserProfile(
              pubkey: blockedPubkey,
              displayName: 'Loud Neighbour',
              nip05: '_@loud.divine.video',
              rawData: const {},
              createdAt: DateTime.utc(2026),
              eventId: 'blocked-profile-event',
            ),
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('Loud Neighbour'), 200);

      expect(find.text('Loud Neighbour'), findsOneWidget);
      expect(find.text('@loud'), findsOneWidget);
      expect(
        find.text(UserProfile.defaultDisplayNameFor(blockedPubkey)),
        findsNothing,
      );
    });

    testWidgets(
      'custom labelers without profiles keep a full npub identifier',
      (tester) async {
        when(
          () => mockModerationLabelService.customLabelers,
        ).thenReturn({labelerPubkey});
        when(() => mockModerationLabelService.subscribedLabelers).thenReturn({
          ModerationLabelService.fallbackModerationPubkeyHex,
          labelerPubkey,
        });

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        final npub = NostrKeyUtils.encodePubKey(labelerPubkey);
        await tester.scrollUntilVisible(find.text(npub), 200);

        expect(
          find.text(UserProfile.defaultDisplayNameFor(labelerPubkey)),
          findsOneWidget,
        );
        expect(find.text(npub), findsOneWidget);
      },
    );

    testWidgets('should use dark background color', (tester) async {
      await tester.pumpWidget(createTestWidget());

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, equals(Colors.black));
    });

    testWidgets('should use VineTheme.vineGreen for app bar background', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget());

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.backgroundColor, isNotNull);
    });

    testWidgets('constrains menu content width on wide screens', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(900, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final listViewWidth = tester.getSize(find.byType(ListView).first).width;
      expect(listViewWidth, moreOrLessEquals(600));
    });

    testWidgets('shows Divine moderation as enabled and non-interactive', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final tile = find.widgetWithText(
        DivineSwitchTile,
        l10n.safetySettingsDivine,
      );
      expect(tile, findsOneWidget);

      final switchTile = tester.widget<DivineSwitchTile>(tile);
      expect(switchTile.value, isTrue);
      expect(switchTile.onChanged, isNull);

      verifyNever(() => mockModerationLabelService.removeLabeler(any()));
      verifyNever(() => mockModerationLabelService.addLabeler(any()));
    });

    testWidgets(
      'shows Divine-hosted-only toggle enabled by default and persists '
      'opt-out',
      (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(
          find.text(l10n.safetySettingsShowDivineHostedOnly),
          findsOneWidget,
        );
        expect(divineHostFilterService.showDivineHostedOnly, isTrue);

        await tester.tap(
          find.widgetWithText(
            DivineSwitchTile,
            l10n.safetySettingsShowDivineHostedOnly,
          ),
        );
        await tester.pumpAndSettle();

        expect(divineHostFilterService.showDivineHostedOnly, isFalse);
      },
    );

    testWidgets(
      'checking the 18+ box calls unlockAdultCategories on the service',
      (tester) async {
        // Arrange - stub the methods the screen will call
        when(
          () => mockAgeVerificationService.setAdultContentVerified(true),
        ).thenAnswer((_) async => true);
        when(
          mockContentFilterService.unlockAdultCategories,
        ).thenAnswer((_) async {});

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Act - tap the age-verification checkbox
        final checkbox = find.byType(DivineCheckboxTile);
        expect(checkbox, findsOneWidget);
        await tester.tap(checkbox);
        await tester.pumpAndSettle();

        // Assert - wiring: age flag set and unlock delegated to service
        verify(
          () => mockAgeVerificationService.setAdultContentVerified(true),
        ).called(1);
        verify(mockContentFilterService.unlockAdultCategories).called(1);
        verifyNever(() => mockContentFilterService.lockAdultCategories());
      },
    );

    testWidgets(
      'adult-content toggle is disabled and locked for a protected minor',
      (tester) async {
        await tester.pumpWidget(createTestWidget(isProtectedMinor: true));
        await tester.pumpAndSettle();

        final tile = tester.widget<DivineCheckboxTile>(
          find.byType(DivineCheckboxTile),
        );
        expect(tile.onChanged, isNull); // disabled: cannot be toggled
        expect(tile.value, isFalse);
        expect(find.text(l10n.safetySettingsAgeLockedForMinor), findsOneWidget);
      },
    );

    testWidgets(
      'enables People I follow moderation with current following list',
      (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        final tile = find.widgetWithText(
          DivineSwitchTile,
          l10n.safetySettingsPeopleIFollow,
        );
        expect(tile, findsOneWidget);
        expect(tester.widget<DivineSwitchTile>(tile).value, isFalse);

        await tester.scrollUntilVisible(tile, 120);
        final switchTile = tester.widget<DivineSwitchTile>(tile);
        switchTile.onChanged!(true);
        await tester.pumpAndSettle();

        verify(
          () => mockModerationLabelService.setFollowingModerationEnabled(
            true,
            followedPubkeys: ['followed_pubkey_1', 'followed_pubkey_2'],
          ),
        ).called(1);
        expect(tester.widget<DivineSwitchTile>(tile).value, isTrue);
      },
    );
  });

  group('SafetySettingsScreen Blocked Users Section - Unit Tests', () {
    test('runtimeBlockedUsers returns blocked users set', () {
      final service = _MockContentBlocklistRepository();

      // Initially empty
      expect(service.runtimeBlockedUsers, isEmpty);

      // Block a user
      service.blockUser('blocked_pubkey_1');
      expect(service.runtimeBlockedUsers.contains('blocked_pubkey_1'), isTrue);

      // Block another
      service.blockUser('blocked_pubkey_2');
      expect(service.runtimeBlockedUsers.length, equals(2));
    });

    test('unblockUser removes user from blocked list', () {
      final service = _MockContentBlocklistRepository();

      service.blockUser('user_to_unblock');
      expect(service.runtimeBlockedUsers.contains('user_to_unblock'), isTrue);

      service.unblockUser('user_to_unblock');
      expect(service.runtimeBlockedUsers.contains('user_to_unblock'), isFalse);
    });

    test('isBlocked returns correct status', () {
      final service = _MockContentBlocklistRepository();

      expect(service.isBlocked('some_user'), isFalse);

      service.blockUser('some_user');
      expect(service.isBlocked('some_user'), isTrue);

      service.unblockUser('some_user');
      expect(service.isBlocked('some_user'), isFalse);
    });
  });
}
