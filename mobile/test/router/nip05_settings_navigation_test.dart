import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/minor_account_review_status.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/settings/nip05_settings_screen.dart';
import 'package:openvine/screens/settings/nostr_settings_screen.dart';
import 'package:openvine/services/auth_service.dart'
    show AuthService, AuthState;
import 'package:profile_repository/profile_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/scroll.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockProfileRepository extends Mock implements ProfileRepository {}

class _MockBlossomUploadService extends Mock implements BlossomUploadService {}

void main() {
  setUpAll(() {
    registerFallbackValue(
      UserProfile(
        pubkey: 'fallback-pubkey',
        displayName: 'Fallback User',
        rawData: const {'display_name': 'Fallback User'},
        createdAt: DateTime(2024),
        eventId:
            'fallback123456789012345678901234567890123456789012345678901234',
      ),
    );
  });

  group('NIP-05 settings navigation', () {
    late _MockAuthService authService;
    late _MockProfileRepository profileRepository;
    late _MockBlossomUploadService blossomUploadService;
    late SharedPreferences sharedPreferences;

    const pubkey =
        'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';

    final profile = UserProfile(
      pubkey: pubkey,
      displayName: 'Test User',
      rawData: const {'display_name': 'Test User'},
      createdAt: DateTime(2024),
      eventId:
          'event123456789012345678901234567890123456789012345678901234567890',
    );

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      sharedPreferences = await SharedPreferences.getInstance();

      authService = _MockAuthService();
      profileRepository = _MockProfileRepository();
      blossomUploadService = _MockBlossomUploadService();

      when(() => authService.authState).thenReturn(AuthState.authenticated);
      when(
        () => authService.authStateStream,
      ).thenAnswer((_) => Stream.value(AuthState.authenticated));
      when(() => authService.currentPublicKeyHex).thenReturn(pubkey);
      when(() => authService.hasExistingProfile).thenReturn(true);

      when(() => profileRepository.getCachedProfile(pubkey: pubkey)).thenAnswer(
        (_) async => profile,
      );
      when(
        () => profileRepository.fetchFreshProfile(pubkey: pubkey),
      ).thenAnswer((_) async => profile);
      when(
        () => profileRepository.checkUsernameAvailability(
          username: any(named: 'username'),
          currentUserPubkey: any(named: 'currentUserPubkey'),
        ),
      ).thenAnswer((_) async => const UsernameAvailable());
      when(
        () => profileRepository.claimUsername(
          username: any(named: 'username'),
        ),
      ).thenAnswer((_) async => const UsernameClaimSuccess());
      when(
        () => profileRepository.cacheProfile(any()),
      ).thenAnswer((_) async {});
    });

    Future<void> tapNip05Tile(WidgetTester tester) async {
      final nip05Tile = find.text(
        lookupAppLocalizations(const Locale('en')).nostrSettingsNip05Address,
      );
      await scrollUntilTappable(
        tester,
        nip05Tile,
        250,
        scrollable: find.byType(Scrollable),
      );
      await tester.tap(nip05Tile);
      await tester.pumpAndSettle();
    }

    ProviderContainer buildContainer() {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
          authServiceProvider.overrideWithValue(authService),
          currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
          isDeveloperModeEnabledProvider.overrideWithValue(false),
          isFeatureEnabledProvider(
            FeatureFlag.advancedRelaySettings,
          ).overrideWith((ref) => false),
          currentMinorAccountReviewStatusProvider.overrideWith(
            (ref) async => MinorAccountReviewStatus.active(),
          ),
          currentAccountDeletionAttemptProvider.overrideWith(
            (ref) async => null,
          ),
          profileRepositoryProvider.overrideWithValue(profileRepository),
          profileReadRepositoryProvider.overrideWithValue(profileRepository),
          blossomUploadServiceProvider.overrideWithValue(blossomUploadService),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    testWidgets('tapping the NIP-05 tile opens the NIP-05 settings route', (
      tester,
    ) async {
      final container = buildContainer();
      final l10n = lookupAppLocalizations(const Locale('en'));
      await container.read(currentMinorAccountReviewStatusProvider.future);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final router = container.read(goRouterProvider);
      router.go(NostrSettingsScreen.path);
      await tester.pumpAndSettle();

      await tapNip05Tile(tester);

      expect(find.text(l10n.nostrSettingsNip05Address), findsWidgets);
      expect(find.byType(Nip05SettingsView), findsOneWidget);
    });

    testWidgets('the nested NIP-05 route still resolves directly by path', (
      tester,
    ) async {
      final container = buildContainer();
      await container.read(currentMinorAccountReviewStatusProvider.future);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final router = container.read(goRouterProvider);
      router.go(Nip05SettingsScreen.path);
      await tester.pumpAndSettle();

      expect(
        router.routeInformationProvider.value.uri.toString(),
        Nip05SettingsScreen.path,
      );
      expect(find.byType(Nip05SettingsView), findsOneWidget);
    });

    testWidgets(
      'popping NIP-05 settings returns to Nostr settings without trapping navigation',
      (tester) async {
        final container = buildContainer();
        final l10n = lookupAppLocalizations(const Locale('en'));
        await container.read(currentMinorAccountReviewStatusProvider.future);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              routerConfig: container.read(goRouterProvider),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final router = container.read(goRouterProvider);
        router.go(NostrSettingsScreen.path);
        await tester.pumpAndSettle();

        await tapNip05Tile(tester);

        expect(find.byType(Nip05SettingsView), findsOneWidget);
        expect(router.canPop(), isTrue);

        router.pop();
        await tester.pumpAndSettle();

        expect(
          router.routeInformationProvider.value.uri.toString(),
          NostrSettingsScreen.path,
        );
        expect(find.byType(Nip05SettingsView), findsNothing);
        expect(find.text(l10n.nostrSettingsNip05Address), findsOneWidget);
      },
    );
  });
}
