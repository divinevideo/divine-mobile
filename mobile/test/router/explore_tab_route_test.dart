// ABOUTME: Tests for /explore/tab/:name URL route and ExploreScreen tab arg
// ABOUTME: Verifies pathForTab helper, route registration, and initial tab selection

import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_foreground_provider.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/classic_vines_provider.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:openvine/providers/for_you_provider.dart';
import 'package:openvine/providers/route_feed_providers.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/explore/explore_screen.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/widgets/classic_vines_tab.dart';
import 'package:openvine/widgets/video_thumbnail_widget.dart';
import 'package:videos_repository/videos_repository.dart';

import '../helpers/test_provider_overrides.dart';

class _MockVideoEventService extends Mock implements VideoEventService {}

class _MockVideosRepository extends Mock implements VideosRepository {}

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

class _DelayedFunnelcakeAvailable extends FunnelcakeAvailable {
  _DelayedFunnelcakeAvailable(this.recheck);

  final Future<bool> recheck;
  var _checked = false;

  @override
  Future<bool> build() async {
    if (_checked) return recheck;
    _checked = true;
    return true;
  }
}

/// Stands in for funnelcakeApiClientProvider. A new client, as after an
/// environment switch, makes Funnelcake availability reload rather than
/// refresh, and a reload drops the previous value from `asData`.
final _funnelcakeClientChanges =
    NotifierProvider<_FunnelcakeClientChanges, int>(
      _FunnelcakeClientChanges.new,
    );

class _FunnelcakeClientChanges extends Notifier<int> {
  @override
  int build() => 0;

  void replaceClient() => state++;
}

class _ReloadingFunnelcakeAvailable extends FunnelcakeAvailable {
  _ReloadingFunnelcakeAvailable(this.recheck);

  final Future<bool> recheck;

  @override
  Future<bool> build() async {
    if (ref.watch(_funnelcakeClientChanges) == 0) return true;
    return recheck;
  }
}

VideoEvent _classicVideo(String idDigit) => VideoEvent(
  id: idDigit * 64,
  pubkey: 'c' * 64,
  createdAt: 1400000000,
  content: '',
  timestamp: DateTime.utc(2014, 5, 13),
);

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

      await tester.pumpWidget(
        MaterialApp.router(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      );
      router.go(ExploreScreen.pathForTab('popular'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(capturedName, equals('popular'));
    });

    test('production shell.dart validates :name before threading it into '
        'ExploreScreen.initialTabName', () {
      final source = File('lib/router/routes/shell.dart').readAsStringSync();

      // The route is a typed class; its annotation names the class
      // registered at ExploreScreen.pathTabSubpath.
      final registration = RegExp(
        r'TypedGoRoute<(\w+)>\(\s*path: ExploreScreen\.pathTabSubpath\b',
      ).firstMatch(source);
      expect(
        registration,
        isNotNull,
        reason:
            'shell.dart must register a typed route at '
            'ExploreScreen.pathTabSubpath so /explore/tab/<name> is '
            'a valid URL.',
      );

      // That class's page must read and validate the :name path parameter,
      // which go_router_builder binds to its `name` field, before passing it
      // to ExploreScreen. Invalid or currently-unconfigured slugs pass null
      // so Explore falls back to the default tab instead of erroring.
      final classOffset = source.indexOf('class ${registration!.group(1)} ');
      expect(
        classOffset,
        isNonNegative,
        reason: 'shell.dart must declare the /explore/tab/:name route class.',
      );
      final classEnd = source.indexOf('\n}\n', classOffset);
      final region = source.substring(
        classOffset,
        classEnd == -1 ? source.length : classEnd,
      );
      expect(
        region.contains('final String name;'),
        isTrue,
        reason:
            'The /explore/tab/:name route must bind the :name path '
            'parameter to its `name` field.',
      );
      expect(
        region.contains('tabNameFromPathParameter(name)'),
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
          localizationsDelegates: appLocalizationsDelegates,
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
    testWidgets('pull-to-refresh stays on Classics and shows fresh videos', (
      tester,
    ) async {
      final availabilityRecheck = Completer<bool>();
      final refreshedFeed = Completer<HomeFeedResult>();
      final initialVideo = _classicVideo('a');
      final refreshedVideo = _classicVideo('b');
      final videosRepository = _MockVideosRepository();
      when(() => videosRepository.getClassicVideos(limit: 50)).thenAnswer(
        (_) async => HomeFeedResult(videos: [initialVideo], hasMore: false),
      );
      when(
        () => videosRepository.getClassicVideos(limit: 50, skipCache: true),
      ).thenAnswer((_) => refreshedFeed.future);

      await tester.pumpWidget(
        testMaterialApp(
          additionalOverrides: [
            appForegroundProvider.overrideWith(_FakeAppForeground.new),
            videoEventServiceProvider.overrideWithValue(videoEventService),
            routerLocationStreamProvider.overrideWith(
              (ref) => Stream.value(ExploreScreen.pathForTab('classics')),
            ),
            exploreTabVideosProvider.overrideWith((ref) => null),
            funnelcakeAvailableProvider.overrideWith(
              () => _DelayedFunnelcakeAvailable(availabilityRecheck.future),
            ),
            videosRepositoryProvider.overrideWithValue(videosRepository),
            forYouAvailableProvider.overrideWithValue(false),
            curatedListsStateProvider.overrideWith(_FakeCuratedListsState.new),
            isFeatureEnabledProvider(
              FeatureFlag.integratedApps,
            ).overrideWithValue(false),
          ],
          home: const Scaffold(
            body: ExploreScreen(initialTabName: 'classics'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final classicsTab = find.byType(ClassicVinesTab);
      Finder thumbnailFor(VideoEvent video) => find.byWidgetPredicate(
        (widget) => widget is VideoThumbnailWidget && widget.video == video,
      );

      expect(thumbnailFor(initialVideo), findsOneWidget);
      verify(() => videosRepository.getClassicVideos(limit: 50)).called(1);
      await tester.drag(
        find.descendant(
          of: classicsTab,
          matching: find.byType(CustomScrollView),
        ),
        const Offset(0, 500),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(classicsTab, findsOneWidget);
      verify(
        () => videosRepository.getClassicVideos(limit: 50, skipCache: true),
      ).called(1);

      final container = ProviderScope.containerOf(tester.element(classicsTab));
      container.read(funnelcakeAvailableProvider.notifier).refresh();
      await tester.pump();
      await tester.pump();
      expect(container.read(classicVinesAvailableProvider).isLoading, isTrue);
      expect(thumbnailFor(initialVideo), findsOneWidget);

      refreshedFeed.complete(
        HomeFeedResult(videos: [refreshedVideo], hasMore: false),
      );
      availabilityRecheck.complete(true);
      await tester.pumpAndSettle();

      expect(thumbnailFor(refreshedVideo), findsOneWidget);
      verifyNoMoreInteractions(videosRepository);
    });

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
              curatedListsStateProvider.overrideWith(
                _FakeCuratedListsState.new,
              ),
              isFeatureEnabledProvider(
                FeatureFlag.integratedApps,
              ).overrideWithValue(false),
            ],
            child: const MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(body: ExploreScreen(initialTabName: 'popular')),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // With Classics, ForYou, and Apps disabled, the tab order is:
        // latest(0), new(1), popular(2), categories(3), lists(4), badges(5).
        final tabBar = tester.widget<TabBar>(find.byType(TabBar));
        expect(
          tabBar.controller?.index,
          equals(2),
          reason: 'Popular tab should be selected at index 2',
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
            curatedListsStateProvider.overrideWith(_FakeCuratedListsState.new),
            isFeatureEnabledProvider(
              FeatureFlag.integratedApps,
            ).overrideWithValue(false),
          ],
          child: const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: ExploreScreen(initialTabName: 'new')),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final tabBar = tester.widget<TabBar>(find.byType(TabBar));
      expect(
        tabBar.controller?.index,
        equals(1),
        reason: 'New tab should be selected at index 1, after Latest',
      );
    });

    testWidgets(
      'keeps New Diviners selected while Funnelcake availability reloads',
      (tester) async {
        final availabilityRecheck = Completer<bool>();
        await tester.pumpWidget(
          testProviderScope(
            additionalOverrides: [
              appForegroundProvider.overrideWith(_FakeAppForeground.new),
              videoEventServiceProvider.overrideWithValue(videoEventService),
              routerLocationStreamProvider.overrideWith(
                (ref) => Stream.value(ExploreScreen.pathForTab('new')),
              ),
              exploreTabVideosProvider.overrideWith((ref) => null),
              funnelcakeAvailableProvider.overrideWith(
                () => _ReloadingFunnelcakeAvailable(availabilityRecheck.future),
              ),
              classicVinesAvailableProvider.overrideWith((ref) async => false),
              forYouAvailableProvider.overrideWithValue(false),
              curatedListsStateProvider.overrideWith(
                _FakeCuratedListsState.new,
              ),
              isFeatureEnabledProvider(
                FeatureFlag.integratedApps,
              ).overrideWithValue(false),
            ],
            child: const MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(body: ExploreScreen(initialTabName: 'new')),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        final newDivinersTab = find.descendant(
          of: find.byType(TabBar),
          matching: find.text(l10n.exploreTabNewDiviners),
        );
        int? selectedIndex() =>
            tester.widget<TabBar>(find.byType(TabBar)).controller?.index;

        expect(newDivinersTab, findsOneWidget);
        expect(selectedIndex(), equals(1));

        final container = ProviderScope.containerOf(
          tester.element(find.byType(ExploreScreen)),
        );
        container.read(_funnelcakeClientChanges.notifier).replaceClient();
        await tester.pump();
        await tester.pump();

        expect(container.read(funnelcakeAvailableProvider).isLoading, isTrue);
        expect(newDivinersTab, findsOneWidget);
        expect(selectedIndex(), equals(1));

        availabilityRecheck.complete(true);
        await tester.pumpAndSettle();

        expect(newDivinersTab, findsOneWidget);
        expect(selectedIndex(), equals(1));
      },
    );
  });
}
