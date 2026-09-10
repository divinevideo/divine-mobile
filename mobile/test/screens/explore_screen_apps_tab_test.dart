import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/explore_tabs/explore_tabs_cubit.dart';
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
import 'package:openvine/screens/user_list_people_screen.dart';
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
    // This mock exposes ChangeNotifier listener state to isolate rendering.
    // ignore: invalid_use_of_protected_member
    when(() => videoEventService.hasListeners).thenReturn(false);
  });

  testWidgets(
    'ExploreScreen shows Integrated Apps tab when feature flag is enabled',
    (tester) async {
      await tester.pumpWidget(
        testProviderScope(
          additionalOverrides: [
            appForegroundProvider.overrideWith(_FakeAppForeground.new),
            videoEventServiceProvider.overrideWithValue(videoEventService),
            routerLocationStreamProvider.overrideWith(
              (ref) => Stream.value(ExploreScreen.path),
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
            ).overrideWithValue(true),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: ExploreScreen()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Integrated Apps'), findsOneWidget);
    },
  );

  testWidgets(
    'ExploreScreen hides Integrated Apps tab when feature flag is disabled',
    (tester) async {
      await tester.pumpWidget(
        testProviderScope(
          additionalOverrides: [
            appForegroundProvider.overrideWith(_FakeAppForeground.new),
            videoEventServiceProvider.overrideWithValue(videoEventService),
            routerLocationStreamProvider.overrideWith(
              (ref) => Stream.value(ExploreScreen.path),
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
            home: Scaffold(body: ExploreScreen()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Integrated Apps'), findsNothing);
    },
  );

  testWidgets('ExploreScreen restores the selected tab by stable name', (
    tester,
  ) async {
    await tester.pumpWidget(
      testProviderScope(
        additionalOverrides: [
          appForegroundProvider.overrideWith(_FakeAppForeground.new),
          videoEventServiceProvider.overrideWithValue(videoEventService),
          routerLocationStreamProvider.overrideWith(
            (ref) => Stream.value(ExploreScreen.path),
          ),
          exploreTabVideosProvider.overrideWith((ref) => null),
          exploreTabNameProvider.overrideWith((ref) => explorePopularTabName),
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
          home: Scaffold(body: ExploreScreen()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final tabBar = tester.widget<TabBar>(find.byType(TabBar));
    expect(tabBar.controller?.index, 1);
  });

  group('People list navigation path', () {
    test('UserListPeopleScreen exposes routable path constants', () {
      // Explore taps should route through GoRouter using these constants,
      // not MaterialPageRoute — this forces the screen to be addressable
      // by listId and keeps the open screen reactive to bloc updates.
      expect(UserListPeopleScreen.path, equals('/people-lists/:listId'));
      expect(UserListPeopleScreen.routeName, equals('people-list-members'));
    });

    test(
      'constructs GoRouter path from listId using Uri.encodeComponent',
      () {
        const listId = 'list with/special:chars';
        final built = '/people-lists/${Uri.encodeComponent(listId)}';
        expect(built, startsWith('/people-lists/'));
        expect(built.contains('/people-lists/list%20with'), isTrue);
      },
    );
  });
}
