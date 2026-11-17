import 'dart:async';

import 'package:badge_repository/badge_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/blocs/badges/explore_badges_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/screens/badges/badge_detail_screen.dart';
import 'package:openvine/screens/explore/tabs/explore_badges_tab.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../../../helpers/test_provider_overrides.dart';
import '../../../helpers/url_launcher_test_double.dart';

class _MockExploreBadgesCubit extends MockCubit<ExploreBadgesState>
    implements ExploreBadgesCubit {}

class _MockBadgeRepository extends Mock implements BadgeRepository {}

void main() {
  setUpAll(
    () => registerFallbackValue(
      BadgeCoordinate(pubkey: _issuer, identifier: 'fallback'),
    ),
  );
  group(ExploreBadgesTab, () {
    testWidgets('loads community badges when the actual tab mounts', (
      tester,
    ) async {
      final repository = _MockBadgeRepository();
      when(() => repository.loadHolderPreview(any()))
          .thenAnswer((_) async => []);
      when(() => repository.loadPublicDefinitions())
          .thenAnswer((_) async => [_definition]);
      await tester.pumpWidget(
        testProviderScope(
          additionalOverrides: [
            badgeRepositoryProvider.overrideWithValue(repository),
          ],
          child: const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: ExploreBadgesTab()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      verify(() => repository.loadPublicDefinitions()).called(1);
      expect(find.text('Loop makers'), findsOneWidget);
    });
  });
  group(ExploreBadgesView, () {
    late _MockExploreBadgesCubit cubit;
    final l10n = lookupAppLocalizations(const Locale('en'));

    setUp(() {
      cubit = _MockExploreBadgesCubit();
    });

    Widget buildSubject() => testMaterialApp(
      home: Scaffold(
        body: BlocProvider<ExploreBadgesCubit>.value(
          value: cubit,
          child: const ExploreBadgesView(),
        ),
      ),
    );

    testWidgets(
      'explains badges and offers the badges website before any result',
      (tester) async {
        when(() => cubit.state).thenReturn(
          const ExploreBadgesState(status: ExploreBadgesStatus.loaded),
        );
        await tester.pumpWidget(buildSubject());
        expect(find.text('Badges bring people together'), findsOneWidget);
        expect(find.text('badges.divine.video'), findsOneWidget);
        expect(
          find.textContaining('Anyone can create and award badges.'),
          findsOneWidget,
        );
        expect(find.text('My badges'), findsOneWidget);
      },
    );

    testWidgets('the explainer opens the exact external badges website', (
      tester,
    ) async {
      final original = UrlLauncherPlatform.instance;
      final launcher = UrlLauncherTestDouble();
      UrlLauncherPlatform.instance = launcher;
      addTearDown(() => UrlLauncherPlatform.instance = original);
      when(() => cubit.state).thenReturn(
        const ExploreBadgesState(status: ExploreBadgesStatus.loaded),
      );
      await tester.pumpWidget(buildSubject());
      await tester.tap(find.text('badges.divine.video'));
      await tester.pumpAndSettle();
      expect(launcher.launched.single.url, 'https://badges.divine.video');
      expect(launcher.launched.single.useExternalApplication, isTrue);
    });

    for (final action in ['New badge', 'My badges']) {
      testWidgets('signed-out $action uses the existing sign-in route', (
        tester,
      ) async {
        when(() => cubit.state).thenReturn(
          const ExploreBadgesState(status: ExploreBadgesStatus.loaded),
        );
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => Scaffold(
                body: BlocProvider<ExploreBadgesCubit>.value(
                  value: cubit,
                  child: const ExploreBadgesView(),
                ),
              ),
            ),
            GoRoute(
              path: '/welcome/login-options',
              builder: (_, _) =>
                  const Scaffold(body: Text('Sign-in destination')),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          testProviderScope(
            child: MaterialApp.router(
              routerConfig: router,
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(action));
        await tester.pumpAndSettle();
        expect(find.text('Sign-in destination'), findsOneWidget);
      });
    }

    for (final brightness in Brightness.values) {
      testWidgets(
        'large text and narrow ${brightness.name} layout remains usable without artwork or previews',
        (tester) async {
          tester.view.physicalSize = const Size(320, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          when(() => cubit.state).thenReturn(
            ExploreBadgesState(
              status: ExploreBadgesStatus.loaded,
              definitions: [_definition],
            ),
          );
          await tester.pumpWidget(
            testProviderScope(
              child: MaterialApp(
                theme: ThemeData(brightness: brightness),
                localizationsDelegates: appLocalizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(2)),
                  child: child!,
                ),
                home: Scaffold(
                  body: BlocProvider<ExploreBadgesCubit>.value(
                    value: cubit,
                    child: const ExploreBadgesView(),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(find.text('Loop makers'), 200);
          expect(find.text('Loop makers'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }

    group('renders', () {
      testWidgets('the community badges', (tester) async {
        when(() => cubit.state).thenReturn(
          ExploreBadgesState(
            status: ExploreBadgesStatus.loaded,
            definitions: [_definition],
          ),
        );

        await tester.pumpWidget(buildSubject());
        await tester.pump();

        expect(find.text('Loop makers'), findsOneWidget);
        expect(find.text('Small films together'), findsOneWidget);
      });
    });

    group('interactions', () {
      testWidgets('community card opens its complete coordinate route', (
        tester,
      ) async {
        when(() => cubit.state).thenReturn(
          ExploreBadgesState(
            status: ExploreBadgesStatus.loaded,
            definitions: [_definition],
          ),
        );
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => Scaffold(
                body: BlocProvider<ExploreBadgesCubit>.value(
                  value: cubit,
                  child: const ExploreBadgesView(),
                ),
              ),
            ),
            GoRoute(
              path: BadgeDetailScreen.path,
              builder: (_, state) =>
                  Scaffold(body: Text(state.pathParameters['naddr']!)),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          testProviderScope(
            child: MaterialApp.router(
              routerConfig: router,
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Loop makers'));
        await tester.pumpAndSettle();
        expect(
          find.text(BadgeCoordinate.parse(_definition.coordinate)!.toNaddr()),
          findsOneWidget,
        );
      });

      testWidgets('refresh failure reset shows no duplicate snackbar', (
        tester,
      ) async {
        final states = StreamController<ExploreBadgesState>();
        addTearDown(states.close);
        final loaded = ExploreBadgesState(
          status: ExploreBadgesStatus.loaded,
          definitions: [_definition],
        );
        whenListen(cubit, states.stream, initialState: loaded);
        await tester.pumpWidget(buildSubject());
        states.add(loaded.copyWith(refreshFailures: 1));
        await tester.pumpAndSettle();
        expect(find.text(l10n.badgesLoadError), findsOneWidget);
        ScaffoldMessenger.of(tester.element(find.byType(ExploreBadgesView)))
            .removeCurrentSnackBar();
        await tester.pumpAndSettle();
        states.add(loaded);
        await tester.pumpAndSettle();
        expect(find.text(l10n.badgesLoadError), findsNothing);
        states.add(loaded.copyWith(refreshFailures: 1));
        await tester.pumpAndSettle();
        expect(find.text(l10n.badgesLoadError), findsOneWidget);
      });

      testWidgets('failed refresh keeps badges and shows feedback', (
        tester,
      ) async {
        final loaded = ExploreBadgesState(
          status: ExploreBadgesStatus.loaded,
          definitions: [_definition],
        );
        whenListen(
          cubit,
          Stream.value(loaded.copyWith(refreshFailures: 1)),
          initialState: loaded,
        );
        await tester.pumpWidget(buildSubject());
        await tester.pump();
        expect(find.text('Loop makers'), findsOneWidget);
        expect(find.text(l10n.badgesLoadError), findsOneWidget);
        expect(find.text(l10n.commonRetry), findsNothing);
      });

      testWidgets('retries a failed load', (tester) async {
        when(() => cubit.state).thenReturn(
          const ExploreBadgesState(status: ExploreBadgesStatus.failure),
        );
        when(() => cubit.load()).thenAnswer((_) async {});

        await tester.pumpWidget(buildSubject());
        await tester.pump();

        expect(find.text(l10n.badgesLoadError), findsOneWidget);
        await tester.tap(find.text(l10n.commonRetry));

        verify(() => cubit.load()).called(1);
      });
    });
  });
}

final _issuer = '2'.padLeft(64, '0');

final _definition = Nip58BadgeDefinition(
  event: Event.fromJson({
    'id': '1'.padLeft(64, '0'),
    'pubkey': _issuer,
    'created_at': 1000,
    'kind': EventKind.badgeDefinition,
    'tags': <List<String>>[],
    'content': '',
    'sig': '',
  }),
  coordinate: '30009:$_issuer:loop-makers',
  dTag: 'loop-makers',
  name: 'Loop makers',
  description: 'Small films together',
);
