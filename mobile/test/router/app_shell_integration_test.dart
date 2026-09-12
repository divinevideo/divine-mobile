// ABOUTME: Integration tests for app shell with GoRouter
// ABOUTME: Tests shell rendering, deep links, tab state preservation, back navigation

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/app_update/app_update.dart';
import 'package:openvine/blocs/background_publish/background_publish_bloc.dart';
import 'package:openvine/blocs/dm/unread_count/dm_unread_count_cubit.dart';
import 'package:openvine/blocs/notifications/badge/notification_badge_cubit.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/features/people_lists/bloc/people_lists_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/minor_account_review_status.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/relay_list_repository_provider.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/explore/explore_screen.dart';
import 'package:openvine/screens/feed/home_feed_retap_cubit.dart';
import 'package:openvine/screens/feed/video_feed_page.dart';
import 'package:openvine/screens/hashtag_feed_screen.dart';
import 'package:openvine/screens/hashtag_screen_router.dart';
import 'package:openvine/screens/profile_screen_router.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/hashtag_service.dart';
import 'package:openvine/widgets/vine_bottom_nav.dart';

import '../helpers/test_provider_overrides.dart';
import '../helpers/test_pubkeys.dart';

class _MockDmUnreadCountCubit extends MockCubit<int>
    implements DmUnreadCountCubit {}

class _MockNotificationBadgeCubit extends MockCubit<int>
    implements NotificationBadgeCubit {}

class _MockAppUpdateBloc extends MockBloc<AppUpdateEvent, AppUpdateState>
    implements AppUpdateBloc {}

class _MockBackgroundPublishBloc
    extends MockBloc<BackgroundPublishEvent, BackgroundPublishState>
    implements BackgroundPublishBloc {}

class _MockPeopleListsBloc extends MockBloc<PeopleListsEvent, PeopleListsState>
    implements PeopleListsBloc {}

class _MockHashtagService extends Mock implements HashtagService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(resetNavigationState);

  // No overrides needed after home feed migration to VideoFeedPage.
  // Previously overrode homeFeedPollIntervalProvider to disable timer.
  // Using const [] to match ProviderContainer overrides type.

  // Signed in: the router sends an unauthenticated session to /welcome, so
  // every assertion below would read that instead of a tab route.
  MockAuthService authenticatedAuth() {
    final mockAuth = createMockAuthService();
    when(() => mockAuth.isAuthenticated).thenReturn(true);
    when(() => mockAuth.currentPublicKeyHex).thenReturn(syntheticTestPubkey);
    when(() => mockAuth.authState).thenReturn(AuthState.authenticated);
    when(
      () => mockAuth.authStateStream,
    ).thenAnswer((_) => Stream.value(AuthState.authenticated));
    when(() => mockAuth.hasExpiredOAuthSession).thenReturn(false);
    // authenticatedRedirectsFromAuthEntry consults this before bouncing an
    // authenticated session off /welcome, which is where the router starts.
    when(() => mockAuth.isAnonymous).thenReturn(false);
    when(() => mockAuth.isRpcUpgradeInProgress).thenReturn(false);
    when(() => mockAuth.userRelays).thenReturn(const []);
    return mockAuth;
  }

  // What HashtagFeedScreen calls on open: the cached bucket for the tag and a
  // live subscription to it.
  HashtagService hashtagServiceWithoutHive() {
    final service = _MockHashtagService();
    when(() => service.getVideosByHashtags(any())).thenReturn(const []);
    when(
      () => service.subscribeToHashtagVideos(any()),
    ).thenAnswer((_) async {});
    return service;
  }

  // The shell reads SharedPreferences, the app version and the relay-status
  // surface through Riverpod. A bare ProviderContainer throws inside
  // AppShellSideEffects before anything renders.
  ProviderContainer container() => ProviderContainer(
    overrides: [
      ...getStandardTestOverrides(
        mockAuthService: authenticatedAuth(),
        mockNostrService: createMockNostrServiceWithRelayStatus(),
      ),
      currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
      // Both gates redirect off the tab routes while unresolved.
      currentMinorAccountReviewStatusProvider.overrideWith(
        (ref) async => MinorAccountReviewStatus.active(),
      ),
      currentAccountDeletionAttemptProvider.overrideWith((ref) async => null),
      // relayStatisticsBridge owns a 3s periodic timer that outlives the tree
      // and trips the pending-timer check.
      relayStatisticsBridgeProvider.overrideWith((ref) {}),
      relaySetChangeBridgeProvider.overrideWith((ref) {}),
      relayListDirtyPublishBridgeProvider.overrideWith((ref) {}),
      contactListDirtyBroadcastBridgeProvider.overrideWith((ref) {}),
      blocklistSyncBridgeProvider.overrideWith((ref) {}),
      // The real provider builds HashtagCacheService, whose initialize()
      // opens the hashtag_stats Hive box. Under fake async that open never
      // completes, and Hive keeps it pending by name for the rest of the
      // isolate, so every later suite that opens the box hangs (#9022).
      hashtagServiceProvider.overrideWithValue(hashtagServiceWithoutHive()),
    ],
  );

  Widget shell(ProviderContainer c) {
    final dmUnreadCubit = _MockDmUnreadCountCubit();
    whenListen(dmUnreadCubit, const Stream<int>.empty(), initialState: 0);
    final notifBadgeCubit = _MockNotificationBadgeCubit();
    whenListen(notifBadgeCubit, const Stream<int>.empty(), initialState: 0);
    final appUpdateBloc = _MockAppUpdateBloc();
    when(() => appUpdateBloc.state).thenReturn(const AppUpdateState());
    final backgroundPublishBloc = _MockBackgroundPublishBloc();
    whenListen(
      backgroundPublishBloc,
      const Stream<BackgroundPublishState>.empty(),
      initialState: const BackgroundPublishState(),
    );
    final peopleListsBloc = _MockPeopleListsBloc();
    whenListen(
      peopleListsBloc,
      const Stream<PeopleListsState>.empty(),
      initialState: const PeopleListsState(),
    );

    return MultiBlocProvider(
      providers: [
        BlocProvider<DmUnreadCountCubit>.value(value: dmUnreadCubit),
        BlocProvider<NotificationBadgeCubit>.value(value: notifBadgeCubit),
        BlocProvider<AppUpdateBloc>.value(value: appUpdateBloc),
        BlocProvider<BackgroundPublishBloc>.value(value: backgroundPublishBloc),
        BlocProvider<PeopleListsBloc>.value(value: peopleListsBloc),
        BlocProvider<HomeFeedRetapCubit>(create: (_) => HomeFeedRetapCubit()),
      ],
      child: UncontrolledProviderScope(
        container: c,
        child: MaterialApp.router(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          routerConfig: c.read(goRouterProvider),
        ),
      ),
    );
  }

  /// Pumps the shell with both async route gates already resolved.
  ///
  /// The router starts at /welcome and only redirects a signed-in user to a
  /// tab once those futures settle, so a bare pumpWidget leaves every
  /// assertion reading /welcome. Bounded pumps rather than pumpAndSettle: the
  /// tree never reaches quiescence while the shell's tickers run.
  Future<void> pumpShell(WidgetTester tester, ProviderContainer c) async {
    await c.read(currentMinorAccountReviewStatusProvider.future);
    await c.read(currentAccountDeletionAttemptProvider.future);
    await tester.pumpWidget(shell(c));
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }
  }

  /// Unmounts the shell and disposes [c] so provider-owned timers stop.
  ///
  /// Has to run inside the test body rather than in addTearDown: the
  /// pending-timer check fires first, and pumping never drains a periodic
  /// timer that a provider owns.
  Future<void> unmount(WidgetTester tester, ProviderContainer c) async {
    await tester.pumpWidget(const SizedBox.shrink());
    c.dispose();
    await tester.pump(const Duration(milliseconds: 1));
  }

  /// Index the shell's bottom nav marks as selected.
  ///
  /// The shell renders [VineBottomNav] inside a Column rather than through
  /// Scaffold.bottomNavigationBar, so there is no BottomNavigationBar to read.
  int selectedTab(WidgetTester tester) =>
      tester.widget<VineBottomNav>(find.byType(VineBottomNav)).currentIndex;

  String currentLocation(ProviderContainer c) {
    final router = c.read(goRouterProvider);
    return router.routeInformationProvider.value.uri.toString();
  }

  group('A) App shell renders & normalizes', () {
    testWidgets('renders with goRouterProvider and normalization active', (
      tester,
    ) async {
      final c = container();

      await pumpShell(tester, c);

      // Activate normalization provider
      c.read(routeNormalizationProvider);

      // Navigate explicitly rather than asserting the cold-start landing
      // route: the router starts at /welcome and the route it settles on is
      // decided by redirects and restored tab state, not by a fixed default.
      c.read(goRouterProvider).go(VideoFeedPage.pathForIndex(0));
      await tester.pump();
      await tester.pump();

      expect(currentLocation(c), VideoFeedPage.pathForIndex(0));

      // Find AppShell widget to verify shell is rendered
      expect(find.byType(AppShell), findsOneWidget);

      await unmount(tester, c);
    });

    testWidgets(
      'normalizes /home/-3 to /home/0 with correct bottom nav index',
      (tester) async {
        final c = container();

        await pumpShell(tester, c);

        // Activate normalization provider
        c.read(routeNormalizationProvider);

        c.read(goRouterProvider).go(VideoFeedPage.pathForIndex(-3));
        await tester.pump(); // Process the navigation
        await tester.pump(); // Process the post-frame callback redirect

        // After normalization, router location should be canonical
        expect(currentLocation(c), VideoFeedPage.pathForIndex(0));

        // Bottom nav should show Home tab (index 0) as selected
        expect(selectedTab(tester), equals(0));

        await unmount(tester, c);
      },
    );
  });

  group('B) Deep links land in correct tab', () {
    testWidgets('navigating to /profile/npubXYZ/2 selects Profile tab', (
      tester,
    ) async {
      final c = container();

      await pumpShell(tester, c);

      c.read(routeNormalizationProvider);

      c
          .read(goRouterProvider)
          .go(ProfileScreenRouter.pathForIndex('npubXYZ', 2));
      await tester.pump(); // Process the navigation
      await tester.pump(); // Process the post-frame callback

      // Should be at profile route
      expect(
        currentLocation(c),
        ProfileScreenRouter.pathForIndex('npubXYZ', 2),
      );

      // Bottom nav should show Profile tab (index 3) as selected
      expect(selectedTab(tester), equals(3));

      await unmount(tester, c);
    });

    testWidgets('navigating to /explore/5 selects Explore tab', (tester) async {
      final c = container();

      await pumpShell(tester, c);

      c.read(routeNormalizationProvider);

      c.read(goRouterProvider).go(ExploreScreen.pathForIndex(5));
      await tester.pump(); // Process the navigation
      await tester.pump(); // Process the post-frame callback

      // Should be at explore route
      expect(currentLocation(c), ExploreScreen.pathForIndex(5));

      // Bottom nav should show Explore tab (index 1) as selected
      expect(selectedTab(tester), equals(1));

      await unmount(tester, c);
    });

    testWidgets('navigating to /hashtag/rust leaves the shell entirely', (
      tester,
    ) async {
      final c = container();

      await pumpShell(tester, c);

      c.read(routeNormalizationProvider);

      c.read(goRouterProvider).go(HashtagScreenRouter.pathForTag('rust'));
      await tester.pump(); // Process the navigation
      await tester.pump(); // Process the post-frame callback

      // Should be at hashtag route
      expect(currentLocation(c), HashtagScreenRouter.pathForTag('rust'));

      // A hashtag feed is registered on the root navigator, not in a shell
      // branch (search_routes.dart: "standalone screen (no bottom nav)"), so
      // it is presented above the shell rather than selecting a tab. The old
      // expectation here was a "Tags tab" at index 2; there is no such tab,
      // and index 2 is the inbox.
      expect(find.byType(HashtagFeedScreen), findsOneWidget);

      await unmount(tester, c);
    });
  });

  group('C) Tab switching preserves state', () {
    testWidgets('switching tabs preserves route within each tab', (
      tester,
    ) async {
      final c = container();

      await pumpShell(tester, c);

      c.read(routeNormalizationProvider);

      // Start at home/2
      c.read(goRouterProvider).go(VideoFeedPage.pathForIndex(2));
      await tester.pump();
      await tester.pump();

      expect(currentLocation(c), VideoFeedPage.pathForIndex(2));

      // Navigate within home tab to home/3
      c.read(goRouterProvider).go(VideoFeedPage.pathForIndex(3));
      await tester.pump();
      await tester.pump();

      expect(currentLocation(c), VideoFeedPage.pathForIndex(3));

      // Switch to Explore tab
      c.read(goRouterProvider).go(ExploreScreen.pathForIndex(0));
      await tester.pump();
      await tester.pump();

      expect(currentLocation(c), ExploreScreen.pathForIndex(0));

      // Switch back to Home tab via bottom nav
      await tester.tap(find.bySemanticsIdentifier('home_tab'));
      await tester.pump();
      await tester.pump();

      // Should return to canonical /home/0 (basePathForTab behavior)
      // This is expected because onTap navigates to canonical paths
      expect(currentLocation(c), VideoFeedPage.pathForIndex(0));

      await unmount(tester, c);
    });

    testWidgets(
      'per-tab navigators maintain separate state across tab switches',
      (tester) async {
        final c = container();

        await pumpShell(tester, c);

        c.read(routeNormalizationProvider);

        // Navigate to /explore/7
        c.read(goRouterProvider).go(ExploreScreen.pathForIndex(7));
        await tester.pump();
        await tester.pump();

        expect(currentLocation(c), ExploreScreen.pathForIndex(7));

        // Switch to Profile tab
        c.read(goRouterProvider).go(ProfileScreenRouter.pathForIndex('me', 5));
        await tester.pump();
        await tester.pump();

        // /profile/me is a placeholder the profile route resolves to the
        // signed-in user's npub, so the location does not stay on 'me'.
        // Literal rather than encodePubKey(syntheticTestPubkey): asserting
        // through the encoder would pass for any encoder, including one that
        // returns the raw hex.
        expect(
          currentLocation(c),
          equals(
            '/profile/npub1m6kmam774klwlh4dhmhaatd7al02m0h0m6kmam774klwlh4dhmhslezuz0/5',
          ),
        );

        // Navigate directly back to explore (not via bottom nav tap)
        c.read(goRouterProvider).go(ExploreScreen.pathForIndex(7));
        await tester.pump();
        await tester.pump();

        // Should be back at /explore/7
        expect(currentLocation(c), ExploreScreen.pathForIndex(7));

        await unmount(tester, c);
      },
    );
  });

  group('D) Back behavior', () {
    testWidgets('bottom nav tap navigates to canonical tab path', (
      tester,
    ) async {
      final c = container();

      await pumpShell(tester, c);

      c.read(routeNormalizationProvider);

      // Start at /home/7
      c.read(goRouterProvider).go(VideoFeedPage.pathForIndex(7));
      await tester.pump();
      await tester.pump();

      expect(currentLocation(c), VideoFeedPage.pathForIndex(7));

      // Tap Explore via bottom nav
      await tester.tap(find.bySemanticsIdentifier(SemanticIds.exploreTab));
      await tester.pump();
      await tester.pump();

      // Explore opens in grid mode, not at a feed index — the contract
      // explore_tab_navigation_test guards. This file previously asserted
      // /explore/0, which is the bug that test exists to prevent.
      expect(currentLocation(c), ExploreScreen.path);

      // Tap Home via bottom nav
      await tester.tap(find.bySemanticsIdentifier('home_tab'));
      await tester.pump();
      await tester.pump();

      // Should navigate to canonical home path, not back to /home/7
      expect(currentLocation(c), VideoFeedPage.pathForIndex(0));

      await unmount(tester, c);
    });
  });
}
