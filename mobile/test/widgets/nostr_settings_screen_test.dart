import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart'
    show SecureKeyStorageException;
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/auth/welcome_screen.dart';
import 'package:openvine/screens/settings/nostr_settings_screen.dart';
import 'package:openvine/services/account_deletion_service.dart';
import 'package:openvine/services/auth_service.dart' hide UserProfile;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../helpers/url_launcher_test_double.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockAccountDeletionService extends Mock
    implements AccountDeletionService {}

const _pubkeyHex =
    '3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d';

void main() {
  group(NostrSettingsScreen, () {
    late _MockAuthService mockAuthService;
    late SharedPreferences sharedPreferences;
    final l10n = lookupAppLocalizations(const Locale('en'));

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      sharedPreferences = await SharedPreferences.getInstance();
      mockAuthService = _MockAuthService();
      when(() => mockAuthService.authState).thenReturn(AuthState.authenticated);
      when(
        () => mockAuthService.authStateStream,
      ).thenAnswer((_) => Stream.value(AuthState.authenticated));
    });

    Widget buildSubject({
      bool advancedRelaySettingsEnabled = false,
      AuthState authState = AuthState.authenticated,
    }) {
      final router = GoRouter(
        initialLocation: NostrSettingsScreen.path,
        routes: [
          GoRoute(
            path: NostrSettingsScreen.path,
            builder: (context, state) => const NostrSettingsScreen(),
          ),
          GoRoute(
            path: WelcomeScreen.path,
            builder: (context, state) =>
                const SizedBox(key: Key('welcome-screen')),
          ),
        ],
      );

      return ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
          authServiceProvider.overrideWithValue(mockAuthService),
          currentAuthStateProvider.overrideWith((ref) => authState),
          isFeatureEnabledProvider(
            FeatureFlag.advancedRelaySettings,
          ).overrideWith((ref) => advancedRelaySettingsEnabled),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      );
    }

    Future<void> pumpSubject(
      WidgetTester tester, {
      bool advancedRelaySettingsEnabled = false,
      AuthState authState = AuthState.authenticated,
    }) async {
      await tester.binding.setSurfaceSize(const Size(900, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        buildSubject(
          advancedRelaySettingsEnabled: advancedRelaySettingsEnabled,
          authState: authState,
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('hides Relays and Relay Diagnostics tiles when '
        'advancedRelaySettings flag is off', (tester) async {
      await pumpSubject(tester);

      expect(find.text(l10n.nostrSettingsRelays), findsNothing);
      expect(find.text(l10n.nostrSettingsRelayDiagnostics), findsNothing);
    });

    testWidgets('shows Relays and Relay Diagnostics tiles when '
        'advancedRelaySettings flag is on', (tester) async {
      await pumpSubject(tester, advancedRelaySettingsEnabled: true);

      expect(find.text(l10n.nostrSettingsRelays), findsOneWidget);
      expect(find.text(l10n.nostrSettingsRelayDiagnostics), findsOneWidget);
    });

    testWidgets('shows NIP-05 address tile', (tester) async {
      await pumpSubject(tester);

      expect(find.text(l10n.nostrSettingsNip05Address), findsOneWidget);
      expect(find.text(l10n.nostrSettingsNip05AddressSubtitle), findsOneWidget);
    });

    testWidgets('shows account portability tile when authenticated', (
      tester,
    ) async {
      await pumpSubject(tester);

      expect(find.text(l10n.nostrSettingsMoveAccount), findsOneWidget);
      expect(find.text(l10n.nostrSettingsMoveAccountSubtitle), findsOneWidget);
    });

    testWidgets('exposes a stable key management row identifier', (
      tester,
    ) async {
      await pumpSubject(tester);

      expect(
        find.bySemanticsIdentifier(SemanticIds.settingsKeyManagementRow),
        findsOneWidget,
      );
    });

    testWidgets('hides account portability tile when signed out', (
      tester,
    ) async {
      await pumpSubject(tester, authState: AuthState.unauthenticated);

      expect(find.text(l10n.nostrSettingsMoveAccount), findsNothing);
      expect(find.text(l10n.nostrSettingsMoveAccountSubtitle), findsNothing);
    });

    testWidgets('opens account portability flow in external browser', (
      tester,
    ) async {
      final originalPlatform = UrlLauncherPlatform.instance;
      final launcher = UrlLauncherTestDouble();
      UrlLauncherPlatform.instance = launcher;
      addTearDown(() => UrlLauncherPlatform.instance = originalPlatform);

      await pumpSubject(tester);

      await tester.tap(find.text(l10n.nostrSettingsMoveAccount));
      await tester.pump();

      expect(launcher.launched.single.url, AppConstants.accountPortabilityUrl);
      expect(launcher.launched.single.useExternalApplication, isTrue);
      expect(find.byType(AlertDialog), findsNothing);
    });

    // #6592: the toggle used to describe only the upside. Turning attribution
    // off changes how a report is weighted, so the subtitle has to say so.
    testWidgets('client attribution subtitle states the report consequence', (
      tester,
    ) async {
      await pumpSubject(tester);

      expect(
        find.text(l10n.nostrSettingsClientAttributionSubtitle),
        findsOneWidget,
      );
      expect(
        l10n.nostrSettingsClientAttributionSubtitle,
        contains('reports you send carry less weight'),
      );
    });

    // Deletion is the one irreversible row on this screen, so it has to read
    // as destructive rather than as another settings entry.
    testWidgets('renders the delete entry as destructive', (tester) async {
      await pumpSubject(tester);

      final tile = find.ancestor(
        of: find.text(l10n.nostrSettingsDeleteAccount),
        matching: find.byType(ListTile),
      );
      expect(tile, findsOneWidget);

      final listTile = tester.widget<ListTile>(tile);
      expect((listTile.title! as Text).style?.color, VineTheme.error);
      expect((listTile.leading! as DivineIcon).color, VineTheme.error);
      expect((listTile.leading! as DivineIcon).icon, DivineIconName.trash);

      expect(
        find.text(l10n.nostrSettingsDeleteAccountSubtitle),
        findsOneWidget,
      );

      // Proves the row reads from l10n rather than a hardcoded English
      // string: the same key in another locale must not be on screen.
      expect(
        find.text(
          lookupAppLocalizations(const Locale('de')).nostrSettingsDeleteAccount,
        ),
        findsNothing,
      );
    });

    testWidgets('dismisses progress overlay after removing keys succeeds', (
      tester,
    ) async {
      final signOut = Completer<void>();
      when(
        () => mockAuthService.signOut(
          deleteKeys: true,
          abortOnKeyDeletionFailure: true,
        ),
      ).thenAnswer((_) => signOut.future);

      await pumpSubject(tester);

      await tester.tap(find.text(l10n.nostrSettingsRemoveKeys));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.deleteAccountRemoveKeysConfirm));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      signOut.complete();
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      verify(
        () => mockAuthService.signOut(
          deleteKeys: true,
          abortOnKeyDeletionFailure: true,
        ),
      ).called(1);
    });

    testWidgets('removes local account and returns to welcome', (tester) async {
      when(
        () => mockAuthService.signOut(
          deleteKeys: true,
          abortOnKeyDeletionFailure: true,
        ),
      ).thenAnswer((_) async {});

      await pumpSubject(tester);

      expect(find.text(l10n.nostrSettingsRemoveKeys), findsOneWidget);
      expect(find.text(l10n.nostrSettingsRemoveKeysSubtitle), findsOneWidget);

      await tester.tap(find.text(l10n.nostrSettingsRemoveKeys));
      await tester.pumpAndSettle();

      expect(find.text(l10n.deleteAccountRemoveKeysTitle), findsOneWidget);
      expect(find.text(l10n.deleteAccountRemoveKeysBody), findsOneWidget);

      await tester.tap(find.text(l10n.deleteAccountRemoveKeysConfirm));
      await tester.pumpAndSettle();

      verify(
        () => mockAuthService.signOut(
          deleteKeys: true,
          abortOnKeyDeletionFailure: true,
        ),
      ).called(1);
      expect(find.byKey(const Key('welcome-screen')), findsOneWidget);
    });

    // The spinner is an overlay entry rather than a route precisely so a back
    // gesture cannot take it away while a destructive sign-out is still in
    // flight — that would leave the user on an idle-looking screen with keys
    // being deleted underneath them.
    testWidgets('keeps the progress overlay through a back gesture', (
      tester,
    ) async {
      final signOut = Completer<void>();
      when(
        () => mockAuthService.signOut(
          deleteKeys: true,
          abortOnKeyDeletionFailure: true,
        ),
      ).thenAnswer((_) => signOut.future);

      await pumpSubject(tester);

      await tester.tap(find.text(l10n.nostrSettingsRemoveKeys));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.deleteAccountRemoveKeysConfirm));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      signOut.complete();
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
      verify(
        () => mockAuthService.signOut(
          deleteKeys: true,
          abortOnKeyDeletionFailure: true,
        ),
      ).called(1);
    });

    // The previous shape of this guard popped the spinner's route; the entry
    // can now outlive the screen instead, so the case worth pinning is a
    // dismiss that lands after the tree holding the overlay is gone.
    testWidgets('survives the screen being torn down mid-sign-out', (
      tester,
    ) async {
      final signOut = Completer<void>();
      when(
        () => mockAuthService.signOut(
          deleteKeys: true,
          abortOnKeyDeletionFailure: true,
        ),
      ).thenAnswer((_) => signOut.future);

      await pumpSubject(tester);

      await tester.tap(find.text(l10n.nostrSettingsRemoveKeys));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.deleteAccountRemoveKeysConfirm));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();

      signOut.complete();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('dismisses progress overlay when key deletion fails', (
      tester,
    ) async {
      when(
        () => mockAuthService.signOut(
          deleteKeys: true,
          abortOnKeyDeletionFailure: true,
        ),
      ).thenThrow(
        const SecureKeyStorageException(
          'Platform key deletion failed',
          code: 'platform_deletion_failed',
        ),
      );

      await pumpSubject(tester);

      await tester.tap(find.text(l10n.nostrSettingsRemoveKeys));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.deleteAccountRemoveKeysConfirm));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text(l10n.nostrSettingsCouldNotRemoveKeys), findsOneWidget);
    });

    testWidgets('Delete Account and Data resolves and shows the username', (
      tester,
    ) async {
      when(() => mockAuthService.currentPublicKeyHex).thenReturn(_pubkeyHex);
      final mockDeletionService = _MockAccountDeletionService();
      final profile = UserProfile(
        pubkey: _pubkeyHex,
        rawData: const {},
        createdAt: DateTime(2024),
        eventId: 'evt',
        name: 'Rabble',
        nip05: '_@rabble.divine.video',
      );

      final router = GoRouter(
        initialLocation: NostrSettingsScreen.path,
        routes: [
          GoRoute(
            path: NostrSettingsScreen.path,
            builder: (context, state) => const NostrSettingsScreen(),
          ),
          GoRoute(
            path: WelcomeScreen.path,
            builder: (context, state) =>
                const SizedBox(key: Key('welcome-screen')),
          ),
        ],
      );

      await tester.binding.setSurfaceSize(const Size(900, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(sharedPreferences),
            authServiceProvider.overrideWithValue(mockAuthService),
            currentAuthStateProvider.overrideWith(
              (ref) => AuthState.authenticated,
            ),
            isFeatureEnabledProvider(
              FeatureFlag.advancedRelaySettings,
            ).overrideWith((ref) => false),
            accountDeletionServiceProvider.overrideWithValue(
              mockDeletionService,
            ),
            fetchUserProfileProvider(
              _pubkeyHex,
            ).overrideWith((ref) async => profile),
          ],
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text(l10n.nostrSettingsDeleteAccount));
      await tester.tap(find.text(l10n.nostrSettingsDeleteAccount));
      await tester.pumpAndSettle();

      expect(find.text('Rabble'), findsOneWidget);
      expect(find.text('@rabble.divine.video'), findsWidgets);
    });

    testWidgets('Delete Account and Data degrades to DELETE with no profile', (
      tester,
    ) async {
      when(() => mockAuthService.currentPublicKeyHex).thenReturn(_pubkeyHex);
      final mockDeletionService = _MockAccountDeletionService();

      final router = GoRouter(
        initialLocation: NostrSettingsScreen.path,
        routes: [
          GoRoute(
            path: NostrSettingsScreen.path,
            builder: (context, state) => const NostrSettingsScreen(),
          ),
          GoRoute(
            path: WelcomeScreen.path,
            builder: (context, state) =>
                const SizedBox(key: Key('welcome-screen')),
          ),
        ],
      );

      await tester.binding.setSurfaceSize(const Size(900, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(sharedPreferences),
            authServiceProvider.overrideWithValue(mockAuthService),
            currentAuthStateProvider.overrideWith(
              (ref) => AuthState.authenticated,
            ),
            isFeatureEnabledProvider(
              FeatureFlag.advancedRelaySettings,
            ).overrideWith((ref) => false),
            accountDeletionServiceProvider.overrideWithValue(
              mockDeletionService,
            ),
            // No cached or fetchable profile → fallback confirmation.
            fetchUserProfileProvider(
              _pubkeyHex,
            ).overrideWith((ref) async => null),
          ],
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text(l10n.nostrSettingsDeleteAccount));
      await tester.tap(find.text(l10n.nostrSettingsDeleteAccount));
      await tester.pumpAndSettle();

      // No username → the DELETE gate, and no handle shown.
      expect(find.text('DELETE'), findsOneWidget);
      expect(find.text('@rabble.divine.video'), findsNothing);
    });
  });
}
