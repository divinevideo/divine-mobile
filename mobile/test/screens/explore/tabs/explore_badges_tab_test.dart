import 'dart:async';

import 'package:badge_repository/badge_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/blocs/badges/explore_badges_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/moderation_providers.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/screens/badges/badge_detail_screen.dart';
import 'package:openvine/screens/explore/tabs/explore_badges_tab.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/widgets/badges/badge_community_card.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:unified_logger/unified_logger.dart';
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
    for (final changeAccount in [false, true]) {
      testWidgets(
        '${changeAccount ? 'account' : 'policy'} change discards an outstanding old discovery',
        (tester) async {
          final repository = _MockBadgeRepository();
          final auth = createMockAuthService();
          final authChanges = StreamController<AuthState>();
          addTearDown(authChanges.close);
          when(() => auth.authStateStream)
              .thenAnswer((_) => authChanges.stream);
          final old = Completer<List<Nip58BadgeDefinition>>();
          var loads = 0;
          when(repository.loadPublicDefinitions)
              .thenAnswer((_) => loads++ == 0 ? old.future : Future.value([]));
          await tester.pumpWidget(
            testProviderScope(
              additionalOverrides: [
                badgeRepositoryProvider.overrideWithValue(repository),
                vanishedProfilePubkeysProvider.overrideWith(
                  (_) => Stream.value(const {}),
                ),
                authServiceProvider.overrideWithValue(auth),
              ],
              child: const MaterialApp(
                localizationsDelegates: appLocalizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(body: ExploreBadgesTab()),
              ),
            ),
          );
          await tester.pump();
          if (changeAccount) {
            when(() => auth.currentPublicKeyHex)
                .thenReturn('3'.padLeft(64, '0'));
            authChanges.add(AuthState.authenticated);
          } else {
            final container = ProviderScope.containerOf(
              tester.element(find.byType(ExploreBadgesTab)),
            );
            container.read(blocklistVersionProvider.notifier).increment();
          }
          await tester.pumpAndSettle();
          old.complete([_definition]);
          await tester.pumpAndSettle();
          expect(find.text('Loop makers'), findsNothing);
          expect(
            find.text(
              lookupAppLocalizations(const Locale('en')).badgeDiscoveryEmpty,
            ),
            findsOneWidget,
          );
          verify(repository.loadPublicDefinitions).called(2);
        },
      );
    }

    testWidgets('waits for local visibility when discovery finishes first', (
      tester,
    ) async {
      final repository = _MockBadgeRepository();
      final vanishes = StreamController<Set<String>>();
      addTearDown(vanishes.close);
      when(repository.loadPublicDefinitions)
          .thenAnswer((_) async => [_definition]);
      when(() => repository.loadHolderPreview(any()))
          .thenAnswer((_) async => []);

      await tester.pumpWidget(
        testMaterialApp(
          additionalOverrides: [
            badgeRepositoryProvider.overrideWithValue(repository),
            vanishedProfilePubkeysProvider.overrideWith((_) => vanishes.stream),
          ],
          home: const Scaffold(body: ExploreBadgesTab()),
        ),
      );
      await tester.pumpAndSettle();
      final cubit = tester
          .element(find.byType(ExploreBadgesView))
          .read<ExploreBadgesCubit>();
      expect(cubit.state.status, ExploreBadgesStatus.loaded);
      expect(find.byType(BadgeCommunityCard), findsNothing);
      verifyNever(() => repository.loadHolderPreview(any()));

      vanishes.add({_issuer});
      await tester.pumpAndSettle();
      expect(find.byType(BadgeCommunityCard), findsNothing);
      verifyNever(() => repository.loadHolderPreview(any()));

      vanishes.add({});
      await tester.pumpAndSettle();
      expect(find.text('Loop makers'), findsOneWidget);
      expect(
        tester
            .element(find.byType(ExploreBadgesView))
            .read<ExploreBadgesCubit>(),
        same(cubit),
      );
      verify(
        () => repository.loadHolderPreview(
          BadgeCoordinate.parse(_definition.coordinate)!,
        ),
      ).called(1);
      verify(repository.loadPublicDefinitions).called(1);
    });

    for (final failBeforeMount in [false, true]) {
      testWidgets(
        'a ${failBeforeMount ? 'cached' : 'live'} visibility error is logged '
        'and offers retry',
        (tester) async {
          final repository = _MockBadgeRepository();
          final vanishes = StreamController<Set<String>>();
          final showGallery = ValueNotifier(!failBeforeMount);
          addTearDown(vanishes.close);
          addTearDown(showGallery.dispose);
          var lookups = 0;
          when(repository.loadPublicDefinitions)
              .thenAnswer((_) async => [_definition]);
          when(() => repository.loadHolderPreview(any()))
              .thenAnswer((_) async => []);
          final l10n = lookupAppLocalizations(const Locale('en'));

          await tester.pumpWidget(
            testMaterialApp(
              additionalOverrides: [
                badgeRepositoryProvider.overrideWithValue(repository),
                vanishedProfilePubkeysProvider.overrideWith(
                  (_) =>
                      lookups++ == 0 ? vanishes.stream : Stream.value(const {}),
                ),
              ],
              home: Scaffold(
                body: Consumer(
                  builder: (context, ref, _) {
                    ref.watch(vanishedProfilePubkeysProvider);
                    return ValueListenableBuilder(
                      valueListenable: showGallery,
                      builder: (context, visible, _) =>
                          visible ? const ExploreBadgesTab() : const SizedBox(),
                    );
                  },
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final error = Exception(
            'badge visibility unavailable ($failBeforeMount)',
          );
          final stack = StackTrace.fromString('badge visibility test stack');
          vanishes.addError(error, stack);
          await tester.pump();
          await tester.pump();
          if (failBeforeMount) {
            showGallery.value = true;
            await tester.pump();
          }
          expect(find.text(l10n.badgesLoadError), findsOneWidget);
          final visibilityLog = LogCaptureService().getRecentLogs().singleWhere(
            (entry) =>
                entry.name == 'ExploreBadgesTab' &&
                entry.error == error.toString(),
          );
          expect(visibilityLog.stackTrace, stack.toString());
          expect(find.byType(BadgeCommunityCard), findsNothing);
          verifyNever(() => repository.loadHolderPreview(any()));

          await tester.tap(find.text(l10n.commonRetry));
          await tester.pumpAndSettle();
          expect(find.text('Loop makers'), findsOneWidget);
          await tester.pump(const Duration(seconds: 1));
          expect(lookups, 2);
          verify(repository.loadPublicDefinitions).called(1);
        },
      );
    }

    testWidgets('filters vanished issuers before laying out the first page', (
      tester,
    ) async {
      final repository = _MockBadgeRepository();
      final vanishes = StreamController<Set<String>>();
      addTearDown(vanishes.close);
      final pendingDefinitions = Completer<List<Nip58BadgeDefinition>>();
      final otherIssuer = '7'.padLeft(64, '0');
      final otherDefinitions = [
        for (var i = 0; i < ExploreBadgesState.pageSize; i++)
          Nip58BadgeDefinition(
            event: Event(otherIssuer, EventKind.badgeDefinition, const [], ''),
            coordinate: '30009:$otherIssuer:group-$i',
            dTag: 'group-$i',
            name: 'Group $i',
          ),
      ];
      when(repository.loadPublicDefinitions)
          .thenAnswer((_) => pendingDefinitions.future);
      when(() => repository.loadHolderPreview(any()))
          .thenAnswer((_) async => []);

      await tester.pumpWidget(
        testMaterialApp(
          additionalOverrides: [
            badgeRepositoryProvider.overrideWithValue(repository),
            vanishedProfilePubkeysProvider.overrideWith((_) => vanishes.stream),
          ],
          home: const Scaffold(body: ExploreBadgesTab()),
        ),
      );
      vanishes.add({_issuer});
      await tester.pump();
      pendingDefinitions.complete([_definition, ...otherDefinitions]);
      await tester.pumpAndSettle();

      final cards = find.byType(BadgeCommunityCard);
      expect(find.text('Loop makers'), findsNothing);
      expect(
        tester.widget<BadgeCommunityCard>(cards.first).definition,
        otherDefinitions.first,
      );
      final cubit = tester
          .element(find.byType(ExploreBadgesView))
          .read<ExploreBadgesCubit>();
      expect(cubit.state.visibleDefinitions, otherDefinitions);
      verify(
        () => repository.loadHolderPreview(
          BadgeCoordinate.parse(otherDefinitions.first.coordinate)!,
        ),
      ).called(1);
      verifyNever(
        () => repository.loadHolderPreview(
          BadgeCoordinate.parse(_definition.coordinate)!,
        ),
      );

      vanishes.add({otherIssuer});
      await tester.pumpAndSettle();
      expect(find.text('Loop makers'), findsOneWidget);
      expect(find.text('Group 0'), findsNothing);
      expect(
        tester
            .element(find.byType(ExploreBadgesView))
            .read<ExploreBadgesCubit>(),
        same(cubit),
      );
      verify(repository.loadPublicDefinitions).called(1);
    });

    testWidgets('loads community badges when the actual tab mounts', (
      tester,
    ) async {
      final repository = _MockBadgeRepository();
      when(() => repository.loadHolderPreview(any()))
          .thenAnswer((_) async => []);
      when(repository.loadPublicDefinitions)
          .thenAnswer((_) async => [_definition]);
      await tester.pumpWidget(
        testProviderScope(
          additionalOverrides: [
            badgeRepositoryProvider.overrideWithValue(repository),
            vanishedProfilePubkeysProvider.overrideWith(
              (_) => Stream.value(const {}),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: ExploreBadgesTab()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      verify(repository.loadPublicDefinitions).called(1);
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
        expect(find.text(l10n.badgeDiscoveryTitle), findsOneWidget);
        expect(find.text('badges.divine.video'), findsOneWidget);
        final semantics = tester.ensureSemantics();
        await tester.pump();
        expect(
          find.bySemanticsLabel(
            l10n.badgeDiscoveryWebsiteLabel('badges.divine.video'),
          ),
          findsOneWidget,
        );
        semantics.dispose();
        expect(find.text(l10n.badgeDiscoveryBody), findsOneWidget);
        expect(find.text(l10n.badgeDiscoveryMyBadges), findsOneWidget);
      },
    );

    testWidgets('an empty gallery offers a mouse-accessible retry', (
      tester,
    ) async {
      when(() => cubit.state).thenReturn(
        const ExploreBadgesState(status: ExploreBadgesStatus.loaded),
      );
      when(cubit.load).thenAnswer((_) async {});
      await tester.pumpWidget(buildSubject());
      expect(find.text(l10n.commonRetry), findsOneWidget);
      await tester.tap(find.text(l10n.commonRetry));
      verify(cubit.load).called(1);
    });

    testWidgets('loading announces once for the entire gallery', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      when(() => cubit.state).thenReturn(
        const ExploreBadgesState(status: ExploreBadgesStatus.loading),
      );
      await tester.pumpWidget(buildSubject());
      expect(find.bySemanticsLabel(l10n.commonLoading), findsOneWidget);
      semantics.dispose();
    });

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

    for (final action in [
      l10n.badgesCreateAction,
      l10n.badgeDiscoveryMyBadges,
    ]) {
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
          final second = Nip58BadgeDefinition(
            event: _definition.event,
            coordinate: '30009:$_issuer:second-group',
            dTag: 'second-group',
            name: 'Second group',
          );
          when(() => cubit.state).thenReturn(
            ExploreBadgesState(
              status: ExploreBadgesStatus.loaded,
              definitions: [_definition, second],
            ),
          );
          final fallbacks = VineThemeColors.debugFallbackCount;
          await tester.pumpWidget(
            testProviderScope(
              child: MaterialApp(
                theme: brightness == Brightness.light
                    ? VineTheme.lightTheme
                    : VineTheme.theme,
                localizationsDelegates: appLocalizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: const TextScaler.linear(2)),
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
          await tester.pump();
          expect(find.text('Loop makers'), findsOneWidget);
          expect(
            tester.getTopLeft(find.byType(BadgeCommunityCard).first).dx,
            tester
                .getTopLeft(
                  find.byType(BadgeCommunityCard, skipOffstage: false).last,
                )
                .dx,
            reason: 'narrow width and large text stack cards in one column',
          );
          expect(VineThemeColors.debugFallbackCount, fallbacks);
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

      testWidgets('requests previews for built cards and shows their faces', (
        tester,
      ) async {
        final holder = '3'.padLeft(64, '0');
        when(() => cubit.state).thenReturn(
          ExploreBadgesState(
            status: ExploreBadgesStatus.loaded,
            definitions: [_definition],
            previews: {
              _definition.coordinate: [holder],
            },
          ),
        );

        await tester.pumpWidget(buildSubject());
        await tester.pump();

        verify(
          () => cubit.loadPreview(_definition.coordinate),
        ).called(greaterThanOrEqualTo(1));
        expect(
          tester
              .widgetList<UserAvatar>(
                find.byWidgetPredicate((w) => w is UserAvatar && w.size == 28),
              )
              .map((face) => face.placeholderSeed),
          [holder],
        );
      });

      testWidgets('preview updates rebuild only the matching card', (
        tester,
      ) async {
        final updates = StreamController<ExploreBadgesState>();
        addTearDown(updates.close);
        final otherDefinition = Nip58BadgeDefinition(
          event: _definition.event,
          coordinate: '30009:$_issuer:other',
          dTag: 'other',
          name: 'Other group',
        );
        final initial = ExploreBadgesState(
          status: ExploreBadgesStatus.loaded,
          definitions: [_definition, otherDefinition],
        );
        whenListen(cubit, updates.stream, initialState: initial);

        await tester.pumpWidget(buildSubject());
        await tester.pump();
        final unchangedCard = find.byWidgetPredicate(
          (w) => w is BadgeCommunityCard && w.definition == otherDefinition,
        );
        final before = tester.widget<BadgeCommunityCard>(unchangedCard);
        verify(() => cubit.loadPreview(_definition.coordinate)).called(1);
        verify(() => cubit.loadPreview(otherDefinition.coordinate)).called(1);

        final holder = '3'.padLeft(64, '0');
        updates.add(
          initial.copyWith(
            previews: {
              _definition.coordinate: [holder],
            },
            activePreviews: 1,
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.widget<BadgeCommunityCard>(unchangedCard), same(before));
        expect(
          tester
              .widget<BadgeCommunityCard>(
                find.byWidgetPredicate(
                  (w) => w is BadgeCommunityCard && w.definition == _definition,
                ),
              )
              .memberPubkeys,
          [holder],
        );
        verifyNever(() => cubit.loadPreview(_definition.coordinate));
        verifyNever(() => cubit.loadPreview(otherDefinition.coordinate));
      });

      testWidgets('does not request previews for cards that are not built', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final definitions = [
          for (var i = 0; i < 24; i++)
            Nip58BadgeDefinition(
              event: _definition.event,
              coordinate: '30009:$_issuer:group-$i',
              dTag: 'group-$i',
              name: 'Group $i',
            ),
        ];
        when(() => cubit.state).thenReturn(
          ExploreBadgesState(
            status: ExploreBadgesStatus.loaded,
            definitions: definitions,
          ),
        );

        await tester.pumpWidget(buildSubject());
        await tester.pump();

        verify(
          () => cubit.loadPreview(definitions.first.coordinate),
        ).called(greaterThanOrEqualTo(1));
        verifyNever(() => cubit.loadPreview(definitions.last.coordinate));
      });

      testWidgets(
        'builds the next row below the fold so VoiceOver can scroll to it',
        (tester) async {
          tester.view.physicalSize = const Size(400, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          when(() => cubit.state).thenReturn(
            ExploreBadgesState(
              status: ExploreBadgesStatus.loaded,
              definitions: [
                for (var i = 0; i < 12; i++)
                  Nip58BadgeDefinition(
                    event: _definition.event,
                    coordinate: '30009:$_issuer:group-$i',
                    dTag: 'group-$i',
                    name: 'Group $i',
                  ),
              ],
            ),
          );

          await tester.pumpWidget(buildSubject());
          await tester.pump();

          final viewportBottom = tester
              .getBottomLeft(find.byType(CustomScrollView))
              .dy;
          final builtBelowFold = tester
              .widgetList<BadgeCommunityCard>(
                find.byType(BadgeCommunityCard, skipOffstage: false),
              )
              .where(
                (card) =>
                    tester
                        .getTopLeft(find.byWidget(card, skipOffstage: false))
                        .dy >=
                    viewportBottom,
              );
          expect(builtBelowFold, isNotEmpty);
        },
      );
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

final String _issuer = '2'.padLeft(64, '0');

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
