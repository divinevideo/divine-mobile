import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_app_bridge_repository/nostr_app_bridge_repository.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/apps/app_detail_screen.dart';
import 'package:openvine/screens/apps/nostr_app_sandbox_screen.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../../helpers/go_router.dart';
import '../../helpers/url_launcher_test_double.dart';

class _MockNostrAppDirectoryService extends Mock
    implements NostrAppDirectoryService {}

void main() {
  group('AppDetailScreen', () {
    late _MockNostrAppDirectoryService mockDirectoryService;

    setUp(() {
      mockDirectoryService = _MockNostrAppDirectoryService();
    });

    testWidgets(
      'shows approved integration messaging and opens the launch action',
      (tester) async {
        final mockGoRouter = MockGoRouter();
        when(
          () => mockGoRouter.push(any(), extra: any(named: 'extra')),
        ).thenAnswer((_) async => null);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              nostrAppDirectoryServiceProvider.overrideWithValue(
                mockDirectoryService,
              ),
            ],
            child: MockGoRouterProvider(
              goRouter: mockGoRouter,
              child: MaterialApp(
                localizationsDelegates: appLocalizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: AppDetailScreen(
                  slug: 'primal',
                  initialEntry: _fixtureApp(),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.text(l10n.appsDetailHowItWorksTitle), findsOneWidget);
        expect(find.text(l10n.appsDetailHowItWorksBody), findsOneWidget);
        expect(find.text(l10n.appsDetailPrimaryOriginTitle), findsOneWidget);
        expect(find.text('https://primal.net'), findsWidgets);
        expect(find.text('https://primal.net/app'), findsNothing);
        await tester.scrollUntilVisible(
          find.text(l10n.appsDetailApprovedOriginsTitle),
          300,
        );
        expect(find.text(l10n.appsDetailApprovedOriginsTitle), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text(l10n.appsDetailCapabilitiesTitle),
          300,
        );
        expect(find.text(l10n.appsDetailCapabilitiesTitle), findsOneWidget);
        expect(find.text(l10n.appsDetailAskBeforeTitle), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text(l10n.appsDetailOpenButton),
          300,
        );
        expect(find.text(l10n.appsDetailOpenButton), findsOneWidget);
        await tester.ensureVisible(find.byType(DivineButton));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(DivineButton));
        await tester.pumpAndSettle();

        final captured = verify(
          () => mockGoRouter.push(
            NostrAppSandboxScreen.pathForAppId('primal-app'),
            extra: captureAny(named: 'extra'),
          ),
        ).captured;
        final pushedApp = captured.single as NostrAppDirectoryEntry;
        expect(pushedApp.id, 'primal-app');
        expect(pushedApp.slug, 'primal');
      },
    );

    testWidgets(
      'opens the verifier in the system browser instead of the sandbox',
      (tester) async {
        final originalPlatform = UrlLauncherPlatform.instance;
        final launcher = UrlLauncherTestDouble();
        UrlLauncherPlatform.instance = launcher;
        addTearDown(() => UrlLauncherPlatform.instance = originalPlatform);

        final mockGoRouter = MockGoRouter();
        when(
          () => mockGoRouter.push(any(), extra: any(named: 'extra')),
        ).thenAnswer((_) async => null);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              nostrAppDirectoryServiceProvider.overrideWithValue(
                mockDirectoryService,
              ),
            ],
            child: MockGoRouterProvider(
              goRouter: mockGoRouter,
              child: MaterialApp(
                localizationsDelegates: appLocalizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: AppDetailScreen(
                  slug: 'verifier',
                  initialEntry: _verifierFixtureApp(),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.scrollUntilVisible(
          find.text(l10n.appsDetailOpenButton),
          300,
        );
        await tester.ensureVisible(find.byType(DivineButton));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(DivineButton));
        await tester.pumpAndSettle();

        expect(launcher.launched, hasLength(1));
        expect(launcher.launched.single.url, 'https://verifier.divine.video/');
        expect(launcher.launched.single.useExternalApplication, isTrue);
        verifyNever(() => mockGoRouter.push(any(), extra: any(named: 'extra')));
      },
    );
  });
}

NostrAppDirectoryEntry _verifierFixtureApp() {
  return const NostrAppDirectoryEntry(
    id: 'bundled-verifier',
    slug: 'verifier',
    name: 'Divine Verifier',
    tagline: 'Link your social accounts.',
    description: 'Verify ownership of external accounts.',
    iconUrl: 'https://verifier.divine.video/favicon.ico',
    launchUrl: 'https://verifier.divine.video/',
    allowedOrigins: ['https://verifier.divine.video'],
    allowedMethods: ['getPublicKey', 'signEvent'],
    allowedSignEventKinds: [0],
    promptRequiredFor: [],
    status: 'approved',
    sortOrder: 16,
    createdAt: null,
    updatedAt: null,
  );
}

NostrAppDirectoryEntry _fixtureApp() {
  return NostrAppDirectoryEntry(
    id: 'primal-app',
    slug: 'primal',
    name: 'Primal',
    tagline: 'Fast Nostr feeds and messages',
    description: 'A vetted Nostr client for timelines and DMs.',
    iconUrl: 'https://cdn.divine.video/primal.png',
    launchUrl: 'https://primal.net/app',
    allowedOrigins: const ['https://primal.net'],
    allowedMethods: const ['getPublicKey', 'signEvent'],
    allowedSignEventKinds: const [1],
    promptRequiredFor: const ['signEvent'],
    status: 'approved',
    sortOrder: 1,
    createdAt: DateTime.parse('2026-03-24T08:00:00Z'),
    updatedAt: DateTime.parse('2026-03-25T08:00:00Z'),
  );
}
