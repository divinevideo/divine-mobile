import 'dart:async';

import 'package:analytics/analytics.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/features/monetization/monetization_storefront_policy.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/analytics_providers.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/screens/settings/monetization_links_settings_screen.dart';
import 'package:openvine/services/auth_service.dart'
    show AuthService, AuthState;
import 'package:profile_repository/profile_repository.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockProfileRepository extends Mock implements ProfileRepository {}

void main() {
  const pubkey =
      'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';

  setUpAll(() {
    registerFallbackValue(
      UserProfile(
        pubkey: pubkey,
        displayName: 'Fallback User',
        rawData: const {'display_name': 'Fallback User'},
        createdAt: DateTime(2024),
        eventId:
            'fallback123456789012345678901234567890123456789012345678901234',
      ),
    );
    registerFallbackValue(<MonetizationLink>[]);
  });

  tearDown(() {
    debugUsesAppleAppStoreTipPolicyOverride = null;
  });

  group(MonetizationLinksSettingsScreen, () {
    testWidgets('does not save monetization links before a profile is cached', (
      tester,
    ) async {
      final authService = _MockAuthService();
      final repository = _MockProfileRepository();
      final profileStream = StreamController<UserProfile?>();
      final l10n = lookupAppLocalizations(const Locale('en'));

      when(() => authService.authState).thenReturn(AuthState.authenticated);
      when(
        () => authService.authStateStream,
      ).thenAnswer((_) => Stream.value(AuthState.authenticated));
      when(() => authService.currentPublicKeyHex).thenReturn(pubkey);
      when(() => authService.hasExistingProfile).thenReturn(false);

      when(
        () => repository.getCachedProfile(pubkey: pubkey),
      ).thenAnswer((_) async => null);
      when(
        () => repository.fetchFreshProfile(pubkey: pubkey),
      ).thenAnswer((_) async => null);
      when(
        () => repository.watchProfile(pubkey: pubkey),
      ).thenAnswer((_) => profileStream.stream);
      addTearDown(profileStream.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(authService),
            currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
            profileRepositoryProvider.overrideWithValue(repository),
            profileReadRepositoryProvider.overrideWithValue(repository),
            analyticsEventSinkProvider.overrideWithValue(
              const NoOpAnalyticsEventSink(),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: VineTheme.theme,
            home: const MonetizationLinksSettingsScreen(),
          ),
        ),
      );
      await tester.pump();

      profileStream.add(null);
      await tester.pump();

      await tester.tap(find.byType(Switch).first);
      await tester.pump();
      await tester.enterText(find.byType(TextFormField).first, r'$creator');
      await tester.ensureVisible(find.text(l10n.monetizationSettingsSave));
      await tester.tap(find.text(l10n.monetizationSettingsSave));
      await tester.pump();
      await tester.pump();

      verifyNever(
        () => repository.saveProfileEvent(
          displayName: any(named: 'displayName'),
          about: any(named: 'about'),
          website: any(named: 'website'),
          picture: any(named: 'picture'),
          banner: any(named: 'banner'),
          monetizationLinks: any(named: 'monetizationLinks'),
          currentProfile: any(named: 'currentProfile'),
        ),
      );
      expect(find.text(l10n.monetizationSettingsSaved), findsNothing);
    });

    testWidgets('starts new monetization link toggles off', (tester) async {
      final authService = _MockAuthService();
      final repository = _MockProfileRepository();
      final profileStream = StreamController<UserProfile?>();

      when(() => authService.authState).thenReturn(AuthState.authenticated);
      when(
        () => authService.authStateStream,
      ).thenAnswer((_) => Stream.value(AuthState.authenticated));
      when(() => authService.currentPublicKeyHex).thenReturn(pubkey);
      when(() => authService.hasExistingProfile).thenReturn(false);

      when(
        () => repository.getCachedProfile(pubkey: pubkey),
      ).thenAnswer((_) async => null);
      when(
        () => repository.fetchFreshProfile(pubkey: pubkey),
      ).thenAnswer((_) async => null);
      when(
        () => repository.watchProfile(pubkey: pubkey),
      ).thenAnswer((_) => profileStream.stream);

      addTearDown(profileStream.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(authService),
            currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
            profileRepositoryProvider.overrideWithValue(repository),
            profileReadRepositoryProvider.overrideWithValue(repository),
            analyticsEventSinkProvider.overrideWithValue(
              const NoOpAnalyticsEventSink(),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: VineTheme.theme,
            home: const MonetizationLinksSettingsScreen(),
          ),
        ),
      );
      await tester.pump();

      profileStream.add(null);
      await tester.pump();

      final switches = tester.widgetList<Switch>(find.byType(Switch));
      expect(switches, isNotEmpty);
      expect(switches.every((toggle) => !toggle.value), isTrue);
      expect(
        tester.widget<TextFormField>(find.byType(TextFormField).first).enabled,
        isFalse,
      );
    });

    testWidgets('limits settings to tip providers on iOS storefronts', (
      tester,
    ) async {
      debugUsesAppleAppStoreTipPolicyOverride = true;

      final authService = _MockAuthService();
      final repository = _MockProfileRepository();
      final profileStream = StreamController<UserProfile?>();
      final l10n = lookupAppLocalizations(const Locale('en'));

      when(() => authService.authState).thenReturn(AuthState.authenticated);
      when(
        () => authService.authStateStream,
      ).thenAnswer((_) => Stream.value(AuthState.authenticated));
      when(() => authService.currentPublicKeyHex).thenReturn(pubkey);
      when(() => authService.hasExistingProfile).thenReturn(false);

      when(
        () => repository.getCachedProfile(pubkey: pubkey),
      ).thenAnswer((_) async => null);
      when(
        () => repository.fetchFreshProfile(pubkey: pubkey),
      ).thenAnswer((_) async => null);
      when(
        () => repository.watchProfile(pubkey: pubkey),
      ).thenAnswer((_) => profileStream.stream);

      addTearDown(profileStream.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(authService),
            currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
            profileRepositoryProvider.overrideWithValue(repository),
            profileReadRepositoryProvider.overrideWithValue(repository),
            analyticsEventSinkProvider.overrideWithValue(
              const NoOpAnalyticsEventSink(),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: VineTheme.theme,
            home: const MonetizationLinksSettingsScreen(),
          ),
        ),
      );
      await tester.pump();

      profileStream.add(null);
      await tester.pump();

      expect(find.text(l10n.monetizationTipsSettingsTitle), findsOneWidget);
      expect(find.text('Cash App', skipOffstage: false), findsOneWidget);
      expect(find.text('PayPal', skipOffstage: false), findsOneWidget);
      expect(find.text('Venmo', skipOffstage: false), findsOneWidget);
      expect(find.text('Patreon', skipOffstage: false), findsNothing);
      expect(find.text('Substack', skipOffstage: false), findsNothing);
      expect(find.text('Medium', skipOffstage: false), findsNothing);
      expect(find.text('Open Collective', skipOffstage: false), findsNothing);
      expect(
        find.text(l10n.monetizationSettingsSubscriptionSection),
        findsNothing,
      );
    });

    testWidgets('preserves hidden subscription links on iOS storefront save', (
      tester,
    ) async {
      debugUsesAppleAppStoreTipPolicyOverride = true;

      final authService = _MockAuthService();
      final repository = _MockProfileRepository();
      final profileStream = StreamController<UserProfile?>();
      final l10n = lookupAppLocalizations(const Locale('en'));
      List<MonetizationLink>? capturedLinks;

      final currentProfile = UserProfile(
        pubkey: pubkey,
        displayName: 'Creator',
        rawData: {
          'display_name': 'Creator',
          divineMonetizationLinksKey: [
            const MonetizationLink(
              provider: MonetizationLinkProvider.cashApp,
              category: MonetizationLinkCategory.tip,
              url: r'https://cash.app/$old',
              enabled: true,
            ).toJson(),
            const MonetizationLink(
              provider: MonetizationLinkProvider.patreon,
              category: MonetizationLinkCategory.subscription,
              url: 'https://www.patreon.com/creator',
              enabled: true,
            ).toJson(),
          ],
        },
        createdAt: DateTime(2026),
        eventId:
            'current123456789012345678901234567890123456789012345678901234567',
      );

      when(() => authService.authState).thenReturn(AuthState.authenticated);
      when(
        () => authService.authStateStream,
      ).thenAnswer((_) => Stream.value(AuthState.authenticated));
      when(() => authService.currentPublicKeyHex).thenReturn(pubkey);
      when(() => authService.hasExistingProfile).thenReturn(true);

      when(
        () => repository.getCachedProfile(pubkey: pubkey),
      ).thenAnswer((_) async => currentProfile);
      when(
        () => repository.fetchFreshProfile(pubkey: pubkey),
      ).thenAnswer((_) async => currentProfile);
      when(
        () => repository.watchProfile(pubkey: pubkey),
      ).thenAnswer((_) => profileStream.stream);
      when(
        () => repository.saveProfileEvent(
          displayName: any(named: 'displayName'),
          about: any(named: 'about'),
          website: any(named: 'website'),
          picture: any(named: 'picture'),
          banner: any(named: 'banner'),
          monetizationLinks: any(named: 'monetizationLinks'),
          currentProfile: any(named: 'currentProfile'),
        ),
      ).thenAnswer((invocation) async {
        capturedLinks =
            (invocation.namedArguments[#monetizationLinks]
                    as Iterable<MonetizationLink>)
                .toList();
        return currentProfile.copyWith(
          rawData: {
            ...currentProfile.rawData,
            divineMonetizationLinksKey: capturedLinks!
                .map((link) => link.toJson())
                .toList(growable: false),
          },
        );
      });

      addTearDown(profileStream.close);
      profileStream.add(currentProfile);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(authService),
            currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
            profileRepositoryProvider.overrideWithValue(repository),
            profileReadRepositoryProvider.overrideWithValue(repository),
            analyticsEventSinkProvider.overrideWithValue(
              const NoOpAnalyticsEventSink(),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: VineTheme.theme,
            home: const MonetizationLinksSettingsScreen(),
          ),
        ),
      );
      await tester.pump();

      await tester.pump();

      await tester.ensureVisible(find.text(l10n.monetizationTipsSettingsSave));
      await tester.tap(find.text(l10n.monetizationTipsSettingsSave));
      await tester.pump();
      await tester.pump();

      expect(capturedLinks, hasLength(2));
      final byProvider = {
        for (final link in capturedLinks!) link.provider: link,
      };
      expect(
        byProvider[MonetizationLinkProvider.cashApp]?.url,
        r'https://cash.app/$old',
      );
      expect(byProvider[MonetizationLinkProvider.cashApp]?.enabled, isTrue);
      expect(
        byProvider[MonetizationLinkProvider.patreon]?.url,
        'https://www.patreon.com/creator',
      );
      expect(byProvider[MonetizationLinkProvider.patreon]?.enabled, isTrue);
    });
  });
}
