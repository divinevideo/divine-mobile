// ABOUTME: Verifies AppShell drives shellObscuredProvider via RouteAware.
// ABOUTME: A route directly above the shell flips it; nested routes do not.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/app_update/app_update.dart';
import 'package:openvine/blocs/dm/unread_count/dm_unread_count_cubit.dart';
import 'package:openvine/blocs/notifications/badge/notification_badge_cubit.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/environment_config.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/overlay_visibility_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/shell_obscured_provider.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/feed/home_feed_retap_cubit.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/utils/pause_aware_modals.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockDmUnreadCountCubit extends MockCubit<int>
    implements DmUnreadCountCubit {}

class _MockNotificationBadgeCubit extends MockCubit<int>
    implements NotificationBadgeCubit {}

class _MockAppUpdateBloc extends MockBloc<AppUpdateEvent, AppUpdateState>
    implements AppUpdateBloc {}

List<Override> _overrides({
  required _MockAuthService mockAuthService,
  required SharedPreferences sharedPreferences,
}) => [
  pageContextProvider.overrideWith(
    (ref) => Stream.value(const RouteContext(type: RouteType.home)),
  ),
  authServiceProvider.overrideWithValue(mockAuthService),
  sharedPreferencesProvider.overrideWithValue(sharedPreferences),
  currentEnvironmentProvider.overrideWithValue(EnvironmentConfig.production),
];

Widget _wrapWithBlocs(Widget child) {
  final dmCubit = _MockDmUnreadCountCubit();
  when(() => dmCubit.state).thenReturn(0);

  final notifBadgeCubit = _MockNotificationBadgeCubit();
  when(() => notifBadgeCubit.state).thenReturn(0);

  final appUpdateBloc = _MockAppUpdateBloc();
  when(() => appUpdateBloc.state).thenReturn(const AppUpdateState());

  return MultiBlocProvider(
    providers: [
      BlocProvider<DmUnreadCountCubit>.value(value: dmCubit),
      BlocProvider<NotificationBadgeCubit>.value(value: notifBadgeCubit),
      BlocProvider<AppUpdateBloc>.value(value: appUpdateBloc),
      BlocProvider<HomeFeedRetapCubit>(create: (_) => HomeFeedRetapCubit()),
    ],
    child: child,
  );
}

// The shell subscribes to [routeObserver] to learn when a full-screen route
// covers it, so the test app must register it on the navigator.
Widget _appShellMaterialApp({bool shellCovered = false}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  navigatorObservers: [routeObserver],
  routes: {
    '/': (_) => const AppShell(currentIndex: 0, child: SizedBox.shrink()),
  },
  onGenerateInitialRoutes: (_) => [
    MaterialPageRoute<void>(
      builder: (_) => const AppShell(currentIndex: 0, child: SizedBox.shrink()),
    ),
    if (shellCovered)
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Covering route')),
      ),
  ],
);

Widget _buildSubject({
  required _MockAuthService mockAuthService,
  required SharedPreferences sharedPreferences,
}) => _wrapWithBlocs(
  ProviderScope(
    overrides: _overrides(
      mockAuthService: mockAuthService,
      sharedPreferences: sharedPreferences,
    ),
    child: _appShellMaterialApp(),
  ),
);

void main() {
  late _MockAuthService mockAuthService;
  late SharedPreferences sharedPreferences;

  setUp(() async {
    mockAuthService = _MockAuthService();
    when(() => mockAuthService.currentPublicKeyHex).thenReturn(null);
    when(() => mockAuthService.currentNpub).thenReturn(null);
    when(() => mockAuthService.isAuthenticated).thenReturn(false);
    when(() => mockAuthService.authState).thenReturn(AuthState.unauthenticated);

    SharedPreferences.setMockInitialValues(<String, Object>{});
    sharedPreferences = await SharedPreferences.getInstance();
  });

  testWidgets(
    'shellObscuredProvider only flips for the route directly above the '
    'shell',
    (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          mockAuthService: mockAuthService,
          sharedPreferences: sharedPreferences,
        ),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(AppShell)),
      );
      final navigator = Navigator.of(tester.element(find.byType(AppShell)));

      // Nothing pushed yet.
      expect(container.read(shellObscuredProvider), isFalse);

      // Push a profile over the shell → obscured.
      navigator.push(
        MaterialPageRoute<void>(builder: (_) => const SizedBox.shrink()),
      );
      await tester.pumpAndSettle();
      expect(container.read(shellObscuredProvider), isTrue);

      // Push a fullscreen video over the profile → still obscured (the shell's
      // RouteAware does not fire for a push above the profile).
      navigator.push(
        MaterialPageRoute<void>(builder: (_) => const SizedBox.shrink()),
      );
      await tester.pumpAndSettle();
      expect(container.read(shellObscuredProvider), isTrue);

      // Close the video → back to the profile. The shell is still covered.
      navigator.pop();
      await tester.pumpAndSettle();
      expect(container.read(shellObscuredProvider), isTrue);

      // Close the profile → shell revealed.
      navigator.pop();
      await tester.pumpAndSettle();
      expect(container.read(shellObscuredProvider), isFalse);
    },
  );

  group('fresh shell mount page-owner recovery', () {
    testWidgets('clears stale owners when the shell is current', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: _overrides(
          mockAuthService: mockAuthService,
          sharedPreferences: sharedPreferences,
        ),
      );
      addTearDown(container.dispose);

      // Residue of a shell torn down while a route still covered it: sign-out
      // navigates away (e.g. to /welcome) without a pop event reaching the
      // shell, so didPopNext never fires and the flag stays true.
      container
          .read(shellObscuredProvider.notifier)
          .setObscured(obscured: true);
      final overlayVisibility = container.read(
        overlayVisibilityProvider.notifier,
      );
      overlayVisibility.setPageOpenForOwner(Object(), isOpen: true);
      expect(container.read(shellObscuredProvider), isTrue);

      await tester.pumpWidget(
        _wrapWithBlocs(
          UncontrolledProviderScope(
            container: container,
            child: _appShellMaterialApp(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // didPush fires once as the fresh shell subscribes, clearing the stale
      // obscured flag and any owner left behind by the removed shell.
      expect(container.read(shellObscuredProvider), isFalse);
      expect(container.read(overlayVisibilityProvider).isPageOpen, isFalse);
    });

    testWidgets('preserves live owners when the shell is not current', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: _overrides(
          mockAuthService: mockAuthService,
          sharedPreferences: sharedPreferences,
        ),
      );
      addTearDown(container.dispose);

      container
          .read(shellObscuredProvider.notifier)
          .setObscured(obscured: true);
      final overlayVisibility = container.read(
        overlayVisibilityProvider.notifier,
      );
      final liveOwner = Object();
      overlayVisibility.setPageOpenForOwner(liveOwner, isOpen: true);

      await tester.pumpWidget(
        _wrapWithBlocs(
          UncontrolledProviderScope(
            container: container,
            child: _appShellMaterialApp(shellCovered: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Covering route'), findsOneWidget);
      expect(container.read(shellObscuredProvider), isFalse);
      expect(container.read(overlayVisibilityProvider).isPageOpen, isTrue);

      overlayVisibility.setPageOpenForOwner(liveOwner, isOpen: false);
      expect(container.read(overlayVisibilityProvider).isPageOpen, isFalse);
    });
  });

  group('didPopNext recovery is page-scoped', () {
    testWidgets('a live bottom-sheet owner survives an unrelated root pop', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: _overrides(
          mockAuthService: mockAuthService,
          sharedPreferences: sharedPreferences,
        ),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _wrapWithBlocs(
          UncontrolledProviderScope(
            container: container,
            child: _appShellMaterialApp(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // A pause-aware sheet opened with `useRootNavigator: false` lives on a
      // branch navigator, so the shell stays the top *root* route while that
      // sheet is on screen — community_suggest_sheet.dart is the shipped
      // example. Model that still-visible hold.
      final sheetOwner = Object();
      container
          .read(overlayVisibilityProvider.notifier)
          .setBottomSheetOpenForOwner(sheetOwner, isOpen: true);
      expect(
        container.read(overlayVisibilityProvider).isBottomSheetOpen,
        isTrue,
      );

      // An unrelated root route opens over the shell and closes again — e.g.
      // the background upload-failure sheet, which needs no user tap. It takes
      // no overlay token of its own, so it must not disturb the sheet's.
      final shellContext = tester.element(find.byType(AppShell));
      Navigator.of(shellContext, rootNavigator: true).push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Unrelated modal')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Unrelated modal'), findsOneWidget);
      expect(container.read(shellObscuredProvider), isTrue);

      Navigator.of(shellContext, rootNavigator: true).pop();
      await tester.pumpAndSettle();

      expect(container.read(shellObscuredProvider), isFalse);
      expect(
        container.read(overlayVisibilityProvider).isBottomSheetOpen,
        isTrue,
        reason:
            'didPopNext force-clears page owners for #6239; clearing sheet '
            'owners too destroyed this live hold and resumed playback behind '
            'the still-visible sheet',
      );
    });
  });

  testWidgets(
    'router.go() uncovering the shell clears a page overlay stranded by '
    'pushWithVideoPause (#6239)',
    (tester) async {
      final rootNavigatorKey = GlobalKey<NavigatorState>();
      final container = ProviderContainer(
        overrides: _overrides(
          mockAuthService: mockAuthService,
          sharedPreferences: sharedPreferences,
        ),
      );
      addTearDown(container.dispose);

      late final GoRouter router;
      router = GoRouter(
        navigatorKey: rootNavigatorKey,
        initialLocation: '/',
        observers: [routeObserver],
        routes: [
          ShellRoute(
            pageBuilder: (context, state, child) => NoTransitionPage<void>(
              key: state.pageKey,
              child: AppShell(
                currentIndex: state.uri.path == '/explore' ? 1 : 0,
                child: child,
              ),
            ),
            routes: [
              GoRoute(
                path: '/',
                pageBuilder: (_, state) => NoTransitionPage<void>(
                  key: state.pageKey,
                  child: Center(
                    child: Builder(
                      builder: (context) => TextButton(
                        onPressed: () => unawaited(
                          context.pushWithVideoPause<void>('/hashtag'),
                        ),
                        child: const Text('Open hashtag'),
                      ),
                    ),
                  ),
                ),
              ),
              GoRoute(
                path: '/explore',
                pageBuilder: (_, state) => NoTransitionPage<void>(
                  key: state.pageKey,
                  child: const Center(child: Text('Explore')),
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/hashtag',
            parentNavigatorKey: rootNavigatorKey,
            pageBuilder: (_, state) => MaterialPage<void>(
              key: state.pageKey,
              child: const Scaffold(body: Center(child: Text('Hashtag'))),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        _wrapWithBlocs(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              routerConfig: router,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open hashtag'));
      await tester.pumpAndSettle();
      expect(find.text('Hashtag'), findsOneWidget);
      expect(container.read(shellObscuredProvider), isTrue);
      expect(container.read(overlayVisibilityProvider).isPageOpen, isTrue);

      // Model a recorder hold whose ordinary release was skipped. Uncovering
      // the shell is the final recovery path and must clear every page owner.
      container
          .read(overlayVisibilityProvider.notifier)
          .setPageOpenForOwner(Object(), isOpen: true);
      // A sheet owner alongside it, to prove the recovery is scoped to pages.
      container
          .read(overlayVisibilityProvider.notifier)
          .setBottomSheetOpenForOwner(Object(), isOpen: true);

      // A go()-style back removes the pushed route declaratively, so
      // pushWithVideoPause's future never completes. AppShell must still notice
      // that the shell is uncovered and clear the stranded page flag.
      router.go('/explore');
      await tester.pumpAndSettle();

      expect(find.text('Explore'), findsOneWidget);
      expect(container.read(shellObscuredProvider), isFalse);
      expect(
        container.read(overlayVisibilityProvider).isPageOpen,
        isFalse,
        reason: 'a stranded page flag keeps the home feed from autoplaying',
      );
      expect(
        container.read(overlayVisibilityProvider).isBottomSheetOpen,
        isTrue,
        reason:
            'the shell recovery is page-scoped: a sheet token is released by '
            'its own route dismiss callback and cannot strand the way a '
            'go()-removed page token does, so clearing it here would only ever '
            'destroy a live hold',
      );
    },
  );

  testWidgets(
    'shell stops resizing for the keyboard while a modal (e.g. the share '
    'sheet) is on top, so the home feed does not re-layout (#5758)',
    (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          mockAuthService: mockAuthService,
          sharedPreferences: sharedPreferences,
        ),
      );
      await tester.pumpAndSettle();

      Scaffold shellScaffold() => tester.widget<Scaffold>(
        find
            .descendant(
              of: find.byType(AppShell),
              matching: find.byType(Scaffold),
            )
            .first,
      );

      // Shell is the topmost route: keep resizing so keyboard-driven UI on the
      // active tab still lifts above the keyboard.
      expect(shellScaffold().resizeToAvoidBottomInset, isTrue);

      // Open a modal over the shell — the share sheet is one of these. Its own
      // keyboard avoidance lifts it above the keyboard; the shell must NOT also
      // shrink, which would re-layout the full-screen feed video + overlay
      // (the Galaxy S10 lag reported on #5758).
      final shellContext = tester.element(find.byType(AppShell));
      unawaited(
        showModalBottomSheet<void>(
          context: shellContext,
          isScrollControlled: true,
          builder: (_) => const SizedBox(height: 200),
        ),
      );
      await tester.pumpAndSettle();
      expect(shellScaffold().resizeToAvoidBottomInset, isFalse);

      // Restored once the modal closes.
      Navigator.of(shellContext).pop();
      await tester.pumpAndSettle();
      expect(shellScaffold().resizeToAvoidBottomInset, isTrue);
    },
  );
}
