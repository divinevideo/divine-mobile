// ABOUTME: Regression test for the Explore→Search transition contract (#3801).
// ABOUTME: Pins that the Explore search bar is read-only (no typed-input
// ABOUTME: auto-navigation) and that tapping it opens the empty search route
// ABOUTME: with mount-focus requested (the contract established by #4901/#4413).

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_foreground_provider.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/classic_vines_provider.dart';
import 'package:openvine/providers/for_you_provider.dart';
import 'package:openvine/providers/list_providers.dart';
import 'package:openvine/providers/route_feed_providers.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/explore/explore_screen.dart';
import 'package:openvine/screens/search_results/view/search_results_page.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:riverpod/misc.dart' show Override;

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
  setUpAll(() {
    registerFallbackValue(SubscriptionType.discovery);
    registerFallbackValue(() {});
  });

  group('Explore → Search transition contract (#3801)', () {
    late _MockVideoEventService videoEventService;

    setUp(() {
      videoEventService = _MockVideoEventService();

      when(
        () => videoEventService.addVideoUpdateListener(any()),
      ).thenReturn(() {});
      when(() => videoEventService.filterVideoList(any())).thenAnswer(
        (invocation) =>
            invocation.positionalArguments.first as List<VideoEvent>,
      );
      when(() => videoEventService.discoveryVideos).thenReturn([]);
      when(() => videoEventService.popularNowVideos).thenReturn([]);
      when(() => videoEventService.isSubscribed(any())).thenReturn(false);
      // This mock exposes ChangeNotifier listener state to isolate rendering.
      // ignore: invalid_use_of_protected_member
      when(() => videoEventService.hasListeners).thenReturn(false);
    });

    List<Override> exploreOverrides() => [
      appForegroundProvider.overrideWith(_FakeAppForeground.new),
      videoEventServiceProvider.overrideWithValue(videoEventService),
      routerLocationStreamProvider.overrideWith(
        (ref) => Stream.value(ExploreScreen.path),
      ),
      exploreTabVideosProvider.overrideWith((ref) => null),
      classicVinesAvailableProvider.overrideWith((ref) async => false),
      forYouAvailableProvider.overrideWithValue(false),
      allListsProvider.overrideWith(
        (ref) async => (userLists: <UserList>[], curatedLists: <CuratedList>[]),
      ),
      curatedListsStateProvider.overrideWith(_FakeCuratedListsState.new),
      isFeatureEnabledProvider(
        FeatureFlag.integratedApps,
      ).overrideWithValue(false),
    ];

    testWidgets(
      'Explore search bar is read-only so typed input cannot auto-navigate',
      (tester) async {
        await tester.pumpWidget(
          testProviderScope(
            additionalOverrides: exploreOverrides(),
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(body: ExploreScreen()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final searchBar = tester.widget<DivineSearchBar>(
          find.byType(DivineSearchBar).first,
        );
        expect(
          searchBar.readOnly,
          isTrue,
          reason:
              'A typeable Explore search bar would reintroduce the '
              'partial-input auto-navigation regression (#3020/#3802).',
        );
        expect(
          searchBar.onTap,
          isNotNull,
          reason: 'The read-only bar must route via onTap.',
        );
        expect(
          find.bySemanticsIdentifier(SemanticIds.exploreSearchBar),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'tapping the Explore search bar opens the empty search route with '
      'mount focus requested',
      (tester) async {
        final router = GoRouter(
          initialLocation: '/',
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) =>
                  const Scaffold(body: ExploreScreen()),
            ),
            GoRoute(
              path: SearchResultsPage.emptyPath,
              builder: (context, state) => Scaffold(
                body: Text(
                  'search-probe '
                  'focus=${state.uri.queryParameters['focus'] ?? 'none'} '
                  'query=${state.uri.queryParameters['query'] ?? 'none'}',
                ),
              ),
            ),
          ],
        );
        addTearDown(router.dispose);

        await tester.pumpWidget(
          testProviderScope(
            additionalOverrides: exploreOverrides(),
            child: MaterialApp.router(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byType(DivineSearchBar).first);
        await tester.pumpAndSettle();

        // The probe route reflects the pushed location: the empty search
        // route (no prefilled query) with the mount-focus flag set — i.e.
        // pathForEmptyQuery(requestFocusOnMount: true). This is the exact
        // contract #4901 shipped and #5131 could silently regress. (The probe
        // reads its query params from the routed GoRouterState.uri, so a
        // match here proves the pushed URI was '/search-results?focus=1'.)
        expect(find.text('search-probe focus=1 query=none'), findsOneWidget);
      },
    );
  });
}
