// ABOUTME: Tab selection under late availability changes on Explore.
// ABOUTME: Launch intent must land once, then stop overriding the user.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;
import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/explore_tabs/explore_tabs_cubit.dart';
import 'package:openvine/blocs/featured_tabs/featured_tabs_cubit.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/notifications/notification_tap_router.dart';
import 'package:openvine/notifications/routing/notification_tap_target.dart';
import 'package:openvine/observability/screen_frame_trace.dart';
import 'package:openvine/providers/app_foreground_provider.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/classic_vines_provider.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:openvine/providers/featured_tabs_providers.dart';
import 'package:openvine/providers/for_you_provider.dart';
import 'package:openvine/providers/route_feed_providers.dart';
import 'package:openvine/repositories/featured_tabs_repository.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/router/routes/shell.dart';
import 'package:openvine/screens/explore/explore_screen.dart';
import 'package:openvine/screens/explore/explore_view.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/services/notification_helpers.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/widgets/screen_frame_trace_scope.dart';
import 'package:people_lists_repository/people_lists_repository.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockVideoEventService extends Mock implements VideoEventService {
  @override
  Stream<void> get deletionTombstonesChanged => const Stream<void>.empty();
}

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
  when(() => service.isCurrentSession).thenReturn(true);
  when(() => service.isInitialized).thenReturn(true);
  when(() => service.initializationError).thenReturn(null);
  when(() => service.hasLoadedSubscriptionIds).thenReturn(true);
  when(() => service.subscribedLists).thenReturn(const []);
  when(() => service.subscribedListIds).thenReturn(const <String>{});
  when(() => service.lists).thenReturn(const []);
  when(() => service.myLists).thenReturn(const []);
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

final _testFeaturedTabAgeGateProvider = StateProvider<FeaturedTabAudience>(
  (ref) => FeaturedTabAudience.unverified,
);

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
  visibleToMinors: true,
);

const _adultConfig = FeaturedTabConfig(
  id: 'ft_abcdefgh',
  slug: 'adult-featured-slug',
  label: {'default': 'Featured'},
  pillLabel: {'default': 'Adult spotlight'},
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
    String? requiredFeaturedFeedId,
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

class _ControlledFeaturedTabsRepository extends _StagedFeaturedTabsRepository {
  final requests =
      <
        ({
          bool gated,
          String? feedId,
          Completer<FeaturedTabsSnapshot> result,
        })
      >[];

  @override
  Future<FeaturedTabsSnapshot> refresh({
    required bool gateAgeRestrictedContent,
    String? requiredFeaturedFeedId,
  }) {
    final result = Completer<FeaturedTabsSnapshot>();
    requests.add((
      gated: gateAgeRestrictedContent,
      feedId: requiredFeaturedFeedId,
      result: result,
    ));
    return result.future;
  }
}

void main() {
  setUpAll(() {
    registerFallbackValue(SubscriptionType.discovery);
    registerFallbackValue(() {});
  });

  late _MockVideoEventService videoEventService;

  setUp(() {
    videoEventService = _MockVideoEventService();
    when(() => videoEventService.removedVideoIds).thenAnswer(
      (_) => const Stream<String>.empty(),
    );
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
    String? requiredFeaturedFeedId,
    GoRouter? router,
    bool classicsAvailable = false,
    bool settle = true,
    FeaturedTabAudience audience = FeaturedTabAudience.unverified,
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
          _testFeaturedTabAgeGateProvider.overrideWith((ref) => audience),
          featuredTabAgeGateProvider.overrideWith(
            (ref) => ref.watch(_testFeaturedTabAgeGateProvider),
          ),
        ],
        child: router == null
            ? MaterialApp(
                localizationsDelegates: appLocalizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(
                  body: ExploreScreen(
                    initialTabName: initialTabName,
                    initialTabSlug: initialTabSlug,
                    requiredFeaturedFeedId: requiredFeaturedFeedId,
                  ),
                ),
              )
            : MaterialApp.router(
                localizationsDelegates: appLocalizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                routerConfig: router,
              ),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  TabController controllerOf(WidgetTester tester) =>
      tester.widget<TabBar>(find.byType(TabBar)).controller!;

  String selectedTabName(WidgetTester tester) {
    final cubit = tester.element(find.byType(TabBar)).read<ExploreTabsCubit>();
    return cubit.state.nameForIndex(controllerOf(tester).index);
  }

  group('ExploreView tab selection', () {
    testWidgets('keeps Explore mounted for a missing campaign and retries on '
        'foreground', (tester) async {
      final repository = _StagedFeaturedTabsRepository();
      await pumpExplore(
        tester,
        repository: repository,
        requiredFeaturedFeedId: _featuredConfig.id,
      );
      expect(find.byType(ExploreView), findsOneWidget);
      expect(find.text(_l10n.featuredFeedUnavailable), findsOneWidget);
      expect(find.text(_l10n.exploreTabCategories), findsOneWidget);

      tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(repository.refreshCount, 2);
      expect(find.text(_l10n.featuredFeedUnavailable), findsNothing);
      expect(find.text('Spotlight'), findsOneWidget);
    });

    testWidgets('a cold campaign waits for verification and hides adult '
        'content immediately during the next account check', (tester) async {
      final repository = _ControlledFeaturedTabsRepository();
      final tap = pushNotificationTapTarget(
        referencedAddress: null,
        referencedEventId: null,
        eventId: null,
        notificationType: NotificationWireValues.campaign,
        senderPubkey: null,
        tapTargetType: NotificationWireValues.featuredFeed,
        tapTargetValue: _adultConfig.id,
      );
      expect(tap.target, isA<OpenAppRouteTarget>());
      final shell = shellRoutes().single as StatefulShellRoute;
      final exploreTabRoute = shell.branches
          .expand((branch) => branch.routes)
          .whereType<GoRoute>()
          .singleWhere((route) => route.path == ExploreScreen.pathTabSubpath);
      final router = GoRouter(
        initialLocation: (tap.target as OpenAppRouteTarget).location,
        routes: [exploreTabRoute],
      );
      addTearDown(router.dispose);
      await pumpExplore(
        tester,
        repository: repository,
        router: router,
        audience: FeaturedTabAudience.loading,
        settle: false,
      );
      final view = tester.state(find.byType(ExploreView));
      final gate = ProviderScope.containerOf(
        tester.element(find.byType(ExploreScreen)),
      ).read(_testFeaturedTabAgeGateProvider.notifier);
      expect(selectedTabName(tester), exploreFeaturedTabName);
      expect(repository.requests.single.gated, isTrue);
      expect(repository.requests.single.feedId, _adultConfig.id);

      repository.requests.single.result.complete(
        const FeaturedTabsSnapshot(hiddenByAudience: true),
      );
      await tester.pump();
      expect(find.byType(DivineCircularProgressIndicator), findsOneWidget);
      expect(find.text(_l10n.commonSomethingWentWrong), findsNothing);
      expect(find.text(_l10n.featuredFeedUnavailable), findsNothing);
      expect(find.text('Adult spotlight'), findsNothing);

      gate.state = FeaturedTabAudience.adult;
      await tester.pump();
      expect(repository.requests, hasLength(2));
      expect(repository.requests.last.gated, isFalse);
      repository.requests.last.result.complete(
        const FeaturedTabsSnapshot(tab: _adultConfig),
      );
      await tester.pumpAndSettle();
      expect(find.text('Adult spotlight'), findsOneWidget);

      gate.state = FeaturedTabAudience.loading;
      await tester.pump();
      expect(repository.requests, hasLength(3));
      expect(repository.requests.last.gated, isTrue);
      expect(find.text('Adult spotlight'), findsNothing);
      expect(find.text(_l10n.featuredFeedUnavailable), findsNothing);
      expect(tester.state(find.byType(ExploreView)), same(view));

      gate.state = FeaturedTabAudience.unverified;
      await tester.pump();
      expect(repository.requests, hasLength(4));
      repository.requests[2].result.complete(const FeaturedTabsSnapshot());
      repository.requests[3].result.complete(const FeaturedTabsSnapshot());
      await tester.pumpAndSettle();
      expect(find.text(_l10n.featuredFeedUnavailable), findsOneWidget);
    });

    testWidgets('shows a lookup error before absence is confirmed and keeps '
        'confirmed absence visible during a later foreground retry', (
      tester,
    ) async {
      final repository = _ControlledFeaturedTabsRepository();
      await pumpExplore(
        tester,
        repository: repository,
        requiredFeaturedFeedId: _featuredConfig.id,
        settle: false,
      );
      expect(find.text(_l10n.featuredFeedUnavailable), findsNothing);
      repository.requests.single.result.complete(
        const FeaturedTabsSnapshot(hasResolvedCatalog: false),
      );
      await tester.pumpAndSettle();
      expect(find.text(_l10n.commonSomethingWentWrong), findsOneWidget);
      expect(find.text(_l10n.featuredFeedUnavailable), findsNothing);

      tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(repository.requests, hasLength(2));
      repository.requests.last.result.complete(const FeaturedTabsSnapshot());
      await tester.pumpAndSettle();
      expect(find.text(_l10n.featuredFeedUnavailable), findsOneWidget);

      tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      // The retry's emit reaches the gate in a microtask, too late for the
      // first pump to draw; the second renders it.
      await tester.pump();
      expect(repository.requests, hasLength(3));
      expect(find.text(_l10n.featuredFeedUnavailable), findsOneWidget);
      repository.requests.last.result.complete(
        const FeaturedTabsSnapshot(hasResolvedCatalog: false),
      );
      await tester.pumpAndSettle();
      expect(find.text(_l10n.featuredFeedUnavailable), findsOneWidget);
    });

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
      container.read(_testFeaturedTabAgeGateProvider.notifier).state =
          FeaturedTabAudience.adult;
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

  group('ExploreView frame trace', () {
    testWidgets('traces the grid as explore', (tester) async {
      await pumpExplore(tester, repository: _StagedFeaturedTabsRepository());

      expect(
        tester
            .widget<ScreenFrameTraceScope>(find.byType(ScreenFrameTraceScope))
            .screen,
        TracedScreen.explore,
      );
    });
  });
}
