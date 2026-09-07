// ABOUTME: Tests for /explore/tab/:name URL route and ExploreScreen tab arg
// ABOUTME: Verifies pathForTab helper, route registration, and initial tab selection

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_foreground_provider.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/classic_vines_provider.dart';
import 'package:openvine/providers/for_you_provider.dart';
import 'package:openvine/providers/list_providers.dart';
import 'package:openvine/providers/route_feed_providers.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/explore/explore_screen.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/services/video_event_service.dart';

import '../helpers/test_provider_overrides.dart';

class _MockVideoEventService extends Mock implements VideoEventService {}

class _FakeAppForeground extends AppForeground {
  @override
  bool build() => true;
}

class _FakeCuratedListsState extends CuratedListsState {
  @override
  CuratedListService? get service => null;

  @override
  Future<List<CuratedList>> build() async => const [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(SubscriptionType.discovery);
    registerFallbackValue(() {});
  });

  late _MockVideoEventService videoEventService;

  setUp(() {
    videoEventService = _MockVideoEventService();

    when(
      () => videoEventService.addVideoUpdateListener(any()),
    ).thenReturn(() {});
    when(() => videoEventService.filterVideoList(any())).thenAnswer(
      (invocation) => invocation.positionalArguments.first as List<VideoEvent>,
    );
    when(() => videoEventService.discoveryVideos).thenReturn([]);
    when(() => videoEventService.popularNowVideos).thenReturn([]);
    when(() => videoEventService.isSubscribed(any())).thenReturn(false);
    // This mock exposes ChangeNotifier listener state to isolate routing.
    // ignore: invalid_use_of_protected_member
    when(() => videoEventService.hasListeners).thenReturn(false);
  });

  group('ExploreScreen.pathForTab', () {
    test('returns /explore/tab/<name>', () {
      expect(
        ExploreScreen.pathForTab('popular'),
        equals('/explore/tab/popular'),
      );
      expect(ExploreScreen.pathForTab('new'), equals('/explore/tab/new'));
      expect(
        ExploreScreen.pathForTab('categories'),
        equals('/explore/tab/categories'),
      );
      expect(
        ExploreScreen.pathForTab('for_you'),
        equals('/explore/tab/for-you'),
      );
    });

    test('pathTabSubpath constant equals /explore/tab/:name', () {
      expect(ExploreScreen.pathTabSubpath, equals('/explore/tab/:name'));
    });
  });

  group('ExploreScreen.tabNameFromPathParameter', () {
    test('maps URL slugs to internal tab names', () {
      expect(
        ExploreScreen.tabNameFromPathParameter('popular'),
        equals('popular'),
      );
      expect(
        ExploreScreen.tabNameFromPathParameter('for-you'),
        equals('for_you'),
      );
    });

    test('rejects unknown and underscore tab slugs', () {
      expect(ExploreScreen.tabNameFromPathParameter('garbage'), isNull);
      expect(ExploreScreen.tabNameFromPathParameter('for_you'), isNull);
    });
  });

  group('GoRouter /explore/tab/:name', () {
    testWidgets('captures the tab name as a path parameter', (tester) async {
      String? capturedName;

      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(path: '/', builder: (_, _) => const SizedBox.shrink()),
          GoRoute(
            path: ExploreScreen.pathTabSubpath,
            builder: (ctx, st) {
              capturedName = st.pathParameters['name'];
              return const SizedBox.shrink();
            },
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      router.go(ExploreScreen.pathForTab('popular'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(capturedName, equals('popular'));
    });

    test('production shell.dart validates :name before threading it into '
        'ExploreScreen.initialTabName', () {
      final source = File('lib/router/routes/shell.dart').readAsStringSync();

      final tabRouteOffset = source.indexOf(
        'path: ExploreScreen.pathTabSubpath',
      );
      expect(
        tabRouteOffset,
        isNonNegative,
        reason:
            'shell.dart must register a GoRoute at '
            'ExploreScreen.pathTabSubpath so /explore/tab/<name> is '
            'a valid URL.',
      );

      // The pageBuilder for this route must read and validate the :name
      // path parameter before passing it to ExploreScreen. Invalid or
      // currently-unconfigured slugs pass null so Explore falls back to the
      // default tab instead of erroring.
      final nextGoRouteAfter = source.indexOf('GoRoute(', tabRouteOffset + 1);
      final region = source.substring(
        tabRouteOffset,
        nextGoRouteAfter == -1 ? source.length : nextGoRouteAfter,
      );
      expect(
        region.contains("pathParameters['name']"),
        isTrue,
        reason:
            'The /explore/tab/:name route must read '
            "state.pathParameters['name'] in its pageBuilder.",
      );
      expect(
        region.contains('tabNameFromPathParameter'),
        isTrue,
        reason:
            'The /explore/tab/:name route must validate the slug with '
            'ExploreScreen.tabNameFromPathParameter before rendering.',
      );
      expect(
        region.contains('RouteErrorScreen'),
        isFalse,
        reason:
            'Unknown /explore/tab/:name slugs should fall back to the '
            'default Explore tab, not render an error screen.',
      );
      expect(
        region.contains('initialTabName:'),
        isTrue,
        reason:
            'The /explore/tab/:name route must thread the validated name '
            'or null into ExploreScreen(initialTabName: …).',
      );
    });

    testWidgets('invalid tab slug falls back to the default tab', (
      tester,
    ) async {
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(path: '/', builder: (_, _) => const SizedBox.shrink()),
          GoRoute(
            path: ExploreScreen.pathTabSubpath,
            pageBuilder: (_, st) {
              final tabName = ExploreScreen.tabNameFromPathParameter(
                st.pathParameters['name'],
              );
              return NoTransitionPage(child: Text(tabName ?? 'default-tab'));
            },
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      );
      router.go('/explore/tab/garbage');
      await tester.pumpAndSettle();

      expect(find.text('default-tab'), findsOneWidget);
    });
  });

  group('ExploreScreen initialTabName', () {
    testWidgets(
      'with initialTabName="popular" selects the popular tab on mount',
      (tester) async {
        await tester.pumpWidget(
          testProviderScope(
            additionalOverrides: [
              appForegroundProvider.overrideWith(_FakeAppForeground.new),
              videoEventServiceProvider.overrideWithValue(videoEventService),
              routerLocationStreamProvider.overrideWith(
                (ref) => Stream.value(ExploreScreen.pathForTab('popular')),
              ),
              exploreTabVideosProvider.overrideWith((ref) => null),
              classicVinesAvailableProvider.overrideWith((ref) async => false),
              forYouAvailableProvider.overrideWithValue(false),
              allListsProvider.overrideWith(
                (ref) async =>
                    (userLists: <UserList>[], curatedLists: <CuratedList>[]),
              ),
              curatedListsStateProvider.overrideWith(
                _FakeCuratedListsState.new,
              ),
              isFeatureEnabledProvider(
                FeatureFlag.integratedApps,
              ).overrideWithValue(false),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(body: ExploreScreen(initialTabName: 'popular')),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // With Classics, ForYou, and Apps disabled, the tab order is:
        // new(0), popular(1), categories(2), lists(3).
        final tabBar = tester.widget<TabBar>(find.byType(TabBar));
        expect(
          tabBar.controller?.index,
          equals(1),
          reason: 'Popular tab should be selected at index 1',
        );
      },
    );

    testWidgets('with initialTabName="new" selects the new tab on mount', (
      tester,
    ) async {
      await tester.pumpWidget(
        testProviderScope(
          additionalOverrides: [
            appForegroundProvider.overrideWith(_FakeAppForeground.new),
            videoEventServiceProvider.overrideWithValue(videoEventService),
            routerLocationStreamProvider.overrideWith(
              (ref) => Stream.value(ExploreScreen.pathForTab('new')),
            ),
            exploreTabVideosProvider.overrideWith((ref) => null),
            classicVinesAvailableProvider.overrideWith((ref) async => false),
            forYouAvailableProvider.overrideWithValue(false),
            allListsProvider.overrideWith(
              (ref) async =>
                  (userLists: <UserList>[], curatedLists: <CuratedList>[]),
            ),
            curatedListsStateProvider.overrideWith(_FakeCuratedListsState.new),
            isFeatureEnabledProvider(
              FeatureFlag.integratedApps,
            ).overrideWithValue(false),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: ExploreScreen(initialTabName: 'new')),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final tabBar = tester.widget<TabBar>(find.byType(TabBar));
      expect(
        tabBar.controller?.index,
        equals(0),
        reason: 'New tab should be selected at index 0',
      );
    });
  });
}
