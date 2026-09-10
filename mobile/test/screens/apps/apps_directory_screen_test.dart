import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_app_bridge_repository/nostr_app_bridge_repository.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/apps/apps_directory_screen.dart';
import 'package:openvine/screens/apps/nostr_app_sandbox_screen.dart';
import 'package:openvine/widgets/vine_cached_image.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../../helpers/go_router.dart';
import '../../helpers/url_launcher_test_double.dart';

class _MockNostrAppDirectoryService extends Mock
    implements NostrAppDirectoryService {}

void main() {
  group('AppsDirectoryScreen', () {
    late _MockNostrAppDirectoryService mockDirectoryService;

    setUp(() {
      mockDirectoryService = _MockNostrAppDirectoryService();
    });

    Widget buildSubject({MockGoRouter? goRouter}) {
      const app = MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AppsDirectoryScreen(),
      );
      return ProviderScope(
        overrides: [
          nostrAppDirectoryServiceProvider.overrideWithValue(
            mockDirectoryService,
          ),
        ],
        child: goRouter == null
            ? app
            : MockGoRouterProvider(goRouter: goRouter, child: app),
      );
    }

    Widget buildEmbeddedSubject() {
      const app = MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AppsDirectoryScreen(embedded: true),
      );
      return ProviderScope(
        overrides: [
          nostrAppDirectoryServiceProvider.overrideWithValue(
            mockDirectoryService,
          ),
        ],
        child: app,
      );
    }

    testWidgets('announces an app row as one button, not three text stops', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      when(
        () => mockDirectoryService.fetchApprovedApps(),
      ).thenAnswer((_) async => [_fixture()]);

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(
        tester.getSemantics(find.text('Primal')),
        isSemantics(
          label:
              'Primal\nFast Nostr feeds and messages\n'
              'A vetted Nostr client for timelines and DMs.',
          isButton: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('loads approved apps from the directory service', (
      tester,
    ) async {
      when(
        () => mockDirectoryService.fetchApprovedApps(),
      ).thenAnswer((_) async => [_fixture()]);

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.appsDirectoryTitle), findsOneWidget);
      expect(find.text(l10n.appsDirectoryIntroBody), findsOneWidget);
      expect(find.text('Primal'), findsOneWidget);
      expect(find.text('Fast Nostr feeds and messages'), findsOneWidget);
      expect(
        find.text('A vetted Nostr client for timelines and DMs.'),
        findsOneWidget,
      );
      final image = tester.widget<VineCachedImage>(
        find.byType(VineCachedImage),
      );
      expect(image.imageUrl, 'https://cdn.divine.video/primal.png');
    });

    testWidgets('embedded mode omits its own app bar', (tester) async {
      when(
        () => mockDirectoryService.fetchApprovedApps(),
      ).thenAnswer((_) async => [_fixture()]);

      await tester.pumpWidget(buildEmbeddedSubject());
      await tester.pumpAndSettle();

      expect(find.byType(DiVineAppBar), findsNothing);
      expect(
        find.text(
          lookupAppLocalizations(const Locale('en')).appsDirectoryIntroBody,
        ),
        findsOneWidget,
      );
      expect(find.text('Primal'), findsOneWidget);
    });

    testWidgets('embedded drops the status-bar inset above the first card', (
      tester,
    ) async {
      // 120 physical px / 3.0 test devicePixelRatio = 40 logical px of status
      // bar. Embedded in Explore nothing above this list consumes the top
      // inset, so a null padding would push the intro card down by exactly
      // that much — the gap reported in #6797.
      tester.view.padding = const FakeViewPadding(top: 120);
      addTearDown(tester.view.resetPadding);

      when(
        () => mockDirectoryService.fetchApprovedApps(),
      ).thenAnswer((_) async => [_fixture()]);

      await tester.pumpWidget(buildEmbeddedSubject());
      await tester.pumpAndSettle();

      // _AppsDirectoryIntro's own EdgeInsets.fromLTRB(16, 16, 16, 8) is the
      // only offset that may sit between the viewport top and the card.
      expect(
        tester.getRect(find.byType(DivineInfoCard)).top -
            tester.getRect(find.byType(ListView)).top,
        moreOrLessEquals(16, epsilon: 0.5),
      );
    });

    testWidgets('standalone keeps the last card clear of the bottom inset', (
      tester,
    ) async {
      // 102 physical px / 3.0 test devicePixelRatio = 34 logical px, i.e. a
      // home indicator or gesture bar. The standalone route has no bottom
      // nav, so Scaffold leaves this inset in the body's MediaQuery and the
      // list has to reserve it itself.
      tester.view.padding = const FakeViewPadding(bottom: 102);
      addTearDown(tester.view.resetPadding);

      when(
        () => mockDirectoryService.fetchApprovedApps(),
      ).thenAnswer((_) async => List.generate(12, _numberedFixture));

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // A lazily-built list only reports its true extent once the last item
      // has been laid out, so jump until the extent stops moving.
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position;
      double previousExtent;
      do {
        previousExtent = position.maxScrollExtent;
        position.jumpTo(previousExtent);
        await tester.pumpAndSettle();
      } while (position.maxScrollExtent != previousExtent);

      final lastCard = find.ancestor(
        of: find.text('App 11'),
        matching: find.byType(Ink),
      );
      expect(
        tester.getRect(lastCard).bottom,
        lessThanOrEqualTo(tester.getRect(find.byType(ListView)).bottom - 34),
      );
    });

    testWidgets('tapping an app opens its integration route', (tester) async {
      final mockGoRouter = MockGoRouter();
      when(
        () => mockGoRouter.push(any(), extra: any(named: 'extra')),
      ).thenAnswer((_) async => null);
      when(
        () => mockDirectoryService.fetchApprovedApps(),
      ).thenAnswer((_) async => [_fixture()]);

      await tester.pumpWidget(buildSubject(goRouter: mockGoRouter));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Primal'));
      await tester.pumpAndSettle();

      verify(
        () => mockGoRouter.push(
          NostrAppSandboxScreen.pathForAppId('app-primal'),
          extra: any(named: 'extra'),
        ),
      ).called(1);
    });

    testWidgets(
      'tapping the verifier opens the system browser, not the sandbox',
      (tester) async {
        final originalPlatform = UrlLauncherPlatform.instance;
        final launcher = UrlLauncherTestDouble();
        UrlLauncherPlatform.instance = launcher;
        addTearDown(() => UrlLauncherPlatform.instance = originalPlatform);

        final mockGoRouter = MockGoRouter();
        when(
          () => mockGoRouter.push(any(), extra: any(named: 'extra')),
        ).thenAnswer((_) async => null);
        when(
          () => mockDirectoryService.fetchApprovedApps(),
        ).thenAnswer((_) async => [_verifierFixture()]);

        await tester.pumpWidget(buildSubject(goRouter: mockGoRouter));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Divine Verifier'));
        await tester.pumpAndSettle();

        expect(launcher.launched, hasLength(1));
        expect(
          launcher.launched.single.url,
          'https://verifier.divine.video/',
        );
        expect(launcher.launched.single.useExternalApplication, isTrue);
        verifyNever(() => mockGoRouter.push(any(), extra: any(named: 'extra')));
      },
    );

    testWidgets(
      'shows an error snackbar when the verifier browser launch throws',
      (tester) async {
        final originalPlatform = UrlLauncherPlatform.instance;
        final launcher = UrlLauncherTestDouble(launchError: Exception('boom'));
        UrlLauncherPlatform.instance = launcher;
        addTearDown(() => UrlLauncherPlatform.instance = originalPlatform);

        when(
          () => mockDirectoryService.fetchApprovedApps(),
        ).thenAnswer((_) async => [_verifierFixture()]);

        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Divine Verifier'));
        await tester.pumpAndSettle();

        expect(launcher.launched, hasLength(1));
        expect(
          find.text(
            lookupAppLocalizations(
              const Locale('en'),
            ).relaySettingsCouldNotOpenBrowser,
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'does not launch a system-browser app with an off-host launch_url',
      (tester) async {
        final originalPlatform = UrlLauncherPlatform.instance;
        final launcher = UrlLauncherTestDouble();
        UrlLauncherPlatform.instance = launcher;
        addTearDown(() => UrlLauncherPlatform.instance = originalPlatform);

        when(
          () => mockDirectoryService.fetchApprovedApps(),
        ).thenAnswer(
          (_) async => [_verifierFixtureWithUrl('https://evil.test/')],
        );

        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Divine Verifier'));
        await tester.pumpAndSettle();

        expect(launcher.launched, isEmpty);
        expect(
          find.text(
            lookupAppLocalizations(
              const Locale('en'),
            ).relaySettingsCouldNotOpenBrowser,
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('shows an empty state when there are no approved apps', (
      tester,
    ) async {
      when(
        () => mockDirectoryService.fetchApprovedApps(),
      ).thenAnswer((_) async => const []);

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.appsDirectoryEmptyTitle), findsOneWidget);
      expect(find.text(l10n.appsDirectoryEmptySubtitle), findsOneWidget);
    });
  });
}

NostrAppDirectoryEntry _verifierFixture() {
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

NostrAppDirectoryEntry _verifierFixtureWithUrl(String launchUrl) {
  return NostrAppDirectoryEntry(
    id: 'bundled-verifier',
    slug: 'verifier',
    name: 'Divine Verifier',
    tagline: 'Link your social accounts.',
    description: 'Verify ownership of external accounts.',
    iconUrl: 'https://verifier.divine.video/favicon.ico',
    launchUrl: launchUrl,
    allowedOrigins: const ['https://verifier.divine.video'],
    allowedMethods: const ['getPublicKey', 'signEvent'],
    allowedSignEventKinds: const [0],
    promptRequiredFor: const [],
    status: 'approved',
    sortOrder: 16,
    createdAt: null,
    updatedAt: null,
  );
}

NostrAppDirectoryEntry _numberedFixture(int index) {
  return NostrAppDirectoryEntry(
    id: 'app-$index',
    slug: 'app-$index',
    name: 'App $index',
    tagline: 'Tagline $index',
    description: 'Description $index',
    iconUrl: '',
    launchUrl: 'https://app$index.example',
    allowedOrigins: ['https://app$index.example'],
    allowedMethods: const ['getPublicKey'],
    allowedSignEventKinds: const [1],
    promptRequiredFor: const [],
    status: 'approved',
    sortOrder: index,
    createdAt: null,
    updatedAt: null,
  );
}

NostrAppDirectoryEntry _fixture() {
  return NostrAppDirectoryEntry(
    id: 'app-primal',
    slug: 'primal',
    name: 'Primal',
    tagline: 'Fast Nostr feeds and messages',
    description: 'A vetted Nostr client for timelines and DMs.',
    iconUrl: 'https://cdn.divine.video/primal.png',
    launchUrl: 'https://primal.net',
    allowedOrigins: const ['https://primal.net'],
    allowedMethods: const ['getPublicKey', 'signEvent'],
    allowedSignEventKinds: const [1, 7],
    promptRequiredFor: const ['signEvent'],
    status: 'approved',
    sortOrder: 1,
    createdAt: DateTime.parse('2026-03-24T08:00:00Z'),
    updatedAt: DateTime.parse('2026-03-25T08:00:00Z'),
  );
}
