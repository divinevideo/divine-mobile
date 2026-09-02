// ABOUTME: Tab selection under late availability changes on Explore.
// ABOUTME: Launch intent must land once, then stop overriding the user.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;
import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/explore_tabs/explore_tabs_cubit.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_foreground_provider.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/classic_vines_provider.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:openvine/providers/featured_tabs_providers.dart';
import 'package:openvine/providers/for_you_provider.dart';
import 'package:openvine/providers/route_feed_providers.dart';
import 'package:openvine/repositories/featured_tabs_repository.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/explore/explore_screen.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:people_lists_repository/people_lists_repository.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockVideoEventService extends Mock implements VideoEventService {}

class _FakeAppForeground extends AppForeground {
  @override
  bool build() => true;
}

class _FakeFunnelcakeAvailable extends FunnelcakeAvailable {
  @override
  Future<bool> build() async => false;
}

class _MockCuratedListService extends Mock implements CuratedListService {}

class _MockPeopleListsRepository extends Mock
    implements PeopleListsRepository {}

class _FakeCuratedListsState extends CuratedListsState {
  _FakeCuratedListsState(this._service);

  final CuratedListService _service;

  @override
  CuratedListService? get service => _service;

  @override
  Future<List<CuratedList>> build() async => const [];
}

/// The Lists tab renders the discovery gallery; empty stubs settle it on
/// the static empty message instead of an endlessly-animating loader,
/// which is what pumpAndSettle needs.
CuratedListService _stubbedListService() {
  final service = _MockCuratedListService();
  when(
    () => service.streamPublicListsFromRelays(limit: any(named: 'limit')),
  ).thenAnswer((_) => Stream.value(const <CuratedList>[]));
  return service;
}

PeopleListsRepository _stubbedPeopleRepository() {
  final repository = _MockPeopleListsRepository();
  when(
    () => repository.discoverPublicLists(
      limit: any(named: 'limit'),
      excludeAuthor: any(named: 'excludeAuthor'),
    ),
  ).thenAnswer((_) async => const []);
  return repository;
}

const _pollInterval = Duration(seconds: 30);

/// English copy the tab bar renders through `context.l10n`.
///
/// The tap targets below are matched by their rendered label, so spelling
/// them as literals would break this suite on a copy change rather than on
/// the selection behaviour it exists to guard.
final AppLocalizations _l10n = lookupAppLocalizations(const Locale('en'));

final _testFeaturedTabAgeGateProvider = StateProvider<bool>((ref) => true);

const _featuredConfig = FeaturedTabConfig(
  id: 'ft_a1b2c3d4',
  slug: 'featured-slug',
  label: {'default': 'Featured'},
  // The tab itself reads the compiled "Featured"; the pill is what makes
  // this particular collection identifiable on screen.
  pillLabel: {'default': 'Spotlight'},
  startsAt: null,
  endsAt: null,
  enabled: true,
  hasContent: true,
);

/// Serves no tab on the first refresh and the configured tab on every later
/// one, standing in for a configuration seeded mid-session.
class _StagedFeaturedTabsRepository implements FeaturedTabsRepository {
  int refreshCount = 0;

  @override
  Future<FeaturedTabsSnapshot> refresh({
    required bool gateAgeRestrictedContent,
  }) async {
    refreshCount++;
    return refreshCount == 1
        ? const FeaturedTabsSnapshot(pollInterval: _pollInterval)
        : const FeaturedTabsSnapshot(
            tab: _featuredConfig,
            pollInterval: _pollInterval,
          );
  }

  @override
  Duration get cacheTtl => FeaturedTabsRepository.defaultCacheTtl;

  @override
  void clearCache() {}

  @override
  Future<FeaturedTabVideosPage> loadVideos({
    required String tabId,
    String? cursor,
  }) async => const FeaturedTabVideosPage(videos: []);
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

  Future<void> pumpExplore(
    WidgetTester tester, {
    required FeaturedTabsRepository repository,
    String? initialTabName,
    String? initialTabSlug,
    bool classicsAvailable = false,
  }) async {
    await tester.pumpWidget(
      testProviderScope(
        additionalOverrides: [
          appForegroundProvider.overrideWith(_FakeAppForeground.new),
          videoEventServiceProvider.overrideWithValue(videoEventService),
          routerLocationStreamProvider.overrideWith(
            (ref) => Stream.value(ExploreScreen.path),
          ),
          exploreTabVideosProvider.overrideWith((ref) => null),
          classicVinesAvailableProvider.overrideWith(
            (ref) async => classicsAvailable,
          ),
          forYouAvailableProvider.overrideWithValue(false),
          curatedListsStateProvider.overrideWith(
            () => _FakeCuratedListsState(_stubbedListService()),
          ),
          peopleListsRepositoryProvider.overrideWith(
            (ref) => _stubbedPeopleRepository(),
          ),
          funnelcakeAvailableProvider.overrideWith(
            _FakeFunnelcakeAvailable.new,
          ),
          isFeatureEnabledProvider(
            FeatureFlag.integratedApps,
          ).overrideWithValue(false),
          featuredTabsRepositoryProvider.overrideWithValue(repository),
          featuredTabAgeGateProvider.overrideWith(
            (ref) => ref.watch(_testFeaturedTabAgeGateProvider),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ExploreScreen(
              initialTabName: initialTabName,
              initialTabSlug: initialTabSlug,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  TabController controllerOf(WidgetTester tester) =>
      tester.widget<TabBar>(find.byType(TabBar)).controller!;

  String selectedTabName(WidgetTester tester) {
    final cubit = tester.element(find.byType(TabBar)).read<ExploreTabsCubit>();
    return cubit.state.nameForIndex(controllerOf(tester).index);
  }

  group('ExploreView tab selection', () {
    testWidgets('refreshes featured tabs when 18+ verification resolves', (
      tester,
    ) async {
      final repository = _StagedFeaturedTabsRepository();
      await pumpExplore(tester, repository: repository);
      expect(repository.refreshCount, 1);
      expect(find.text('Spotlight'), findsNothing);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(ExploreScreen)),
      );
      container.read(_testFeaturedTabAgeGateProvider.notifier).state = false;
      await tester.pumpAndSettle();

      expect(repository.refreshCount, 2);
      expect(find.text('Spotlight'), findsOneWidget);
    });

    testWidgets('a later availability change keeps the user on their tab', (
      tester,
    ) async {
      // Explore stays mounted for the session and the featured configuration
      // keeps polling, so a launch tab that still wins on the tenth
      // availability change drags the user off whatever they since chose.
      final repository = _StagedFeaturedTabsRepository();
      await pumpExplore(
        tester,
        repository: repository,
        // Matches the in-app redirects that land on /explore/tab/popular.
        initialTabName: explorePopularTabName,
        initialTabSlug: explorePopularTabName,
      );

      const chosenIndex = 3;
      controllerOf(tester).index = chosenIndex;
      await tester.pumpAndSettle();
      final chosen = selectedTabName(tester);
      expect(chosen, isNot(explorePopularTabName));

      await tester.pump(_pollInterval + const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(repository.refreshCount, greaterThan(1));
      expect(find.text('Spotlight'), findsOneWidget);
      // Featured slots in above the chosen tab, so staying on it means
      // following it to a new index. Without this the test also passes when
      // featured is appended last and no remap happens at all.
      expect(controllerOf(tester).index, greaterThan(chosenIndex));
      expect(selectedTabName(tester), equals(chosen));
    });

    testWidgets('a tab tap writes the choice to the persisted tab name', (
      tester,
    ) async {
      // Explore is torn down and rebuilt on every grid -> feed -> grid trip,
      // so the choice has to outlive the widget. This covers the write half;
      // the read half — a fresh mount restoring the stored name — is
      // `ExploreScreen restores the selected tab by stable name` in
      // test/screens/explore_screen_apps_tab_test.dart. Nothing in this
      // group remounts.
      final repository = _StagedFeaturedTabsRepository();
      await pumpExplore(tester, repository: repository);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(ExploreScreen)),
      );
      expect(
        container.read(exploreTabNameProvider),
        isNot(exploreCategoriesTabName),
      );

      await tester.tap(find.text(_l10n.exploreTabCategories));
      await tester.pumpAndSettle();

      expect(
        container.read(exploreTabNameProvider),
        equals(exploreCategoriesTabName),
      );
    });

    testWidgets('a deep link still lands on a tab that arrives late', (
      tester,
    ) async {
      // Launch intent must outlive the first frame: an optional tab may not
      // exist yet when the controller is first built.
      final repository = _StagedFeaturedTabsRepository();
      await pumpExplore(
        tester,
        repository: repository,
        initialTabName: exploreClassicsTabName,
        initialTabSlug: exploreClassicsTabName,
        classicsAvailable: true,
      );

      expect(selectedTabName(tester), equals(exploreClassicsTabName));
    });

    testWidgets('a deep link to the featured slug lands once it resolves', (
      tester,
    ) async {
      final repository = _StagedFeaturedTabsRepository();
      await pumpExplore(
        tester,
        repository: repository,
        initialTabSlug: _featuredConfig.slug,
      );

      expect(selectedTabName(tester), isNot(exploreFeaturedTabName));

      await tester.pump(_pollInterval + const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(selectedTabName(tester), equals(exploreFeaturedTabName));
    });

    testWidgets('a tap before the featured config resolves wins', (
      tester,
    ) async {
      // The featured slug is the worse of the two launch targets to leave
      // pending: its configuration can arrive a whole poll interval later, or
      // whenever starts_at opens.
      final repository = _StagedFeaturedTabsRepository();
      await pumpExplore(
        tester,
        repository: repository,
        initialTabSlug: _featuredConfig.slug,
      );

      await tester.tap(find.text(_l10n.exploreTabCategories));
      await tester.pumpAndSettle();
      expect(selectedTabName(tester), equals(exploreCategoriesTabName));

      await tester.pump(_pollInterval + const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(find.text('Spotlight'), findsOneWidget);
      expect(selectedTabName(tester), equals(exploreCategoriesTabName));
    });

    testWidgets('a swipe before the featured config resolves wins', (
      tester,
    ) async {
      // A swipe never reaches TabBar.onTap, only the controller listener.
      final repository = _StagedFeaturedTabsRepository();
      await pumpExplore(
        tester,
        repository: repository,
        initialTabSlug: _featuredConfig.slug,
      );

      await tester.drag(find.byType(TabBarView), const Offset(-500, 0));
      await tester.pumpAndSettle();
      final chosen = selectedTabName(tester);
      expect(chosen, isNot(exploreFeaturedTabName));

      await tester.pump(_pollInterval + const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(selectedTabName(tester), equals(chosen));
    });
  });
}
