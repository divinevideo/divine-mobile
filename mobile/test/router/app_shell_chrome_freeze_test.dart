// ABOUTME: Widget regression test for AppShell chrome freezing (#5925).
// ABOUTME: A full-screen route pushed above the shell must not pop the
// ABOUTME: suppressed app bar in (own-profile grid / inbox shift-down).

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/app_update/app_update.dart';
import 'package:openvine/blocs/dm/unread_count/dm_unread_count_cubit.dart';
import 'package:openvine/blocs/notifications/badge/notification_badge_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/environment_config.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/feed/home_feed_retap_cubit.dart';
import 'package:openvine/services/auth_service.dart';
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
  required Stream<RouteContext> contextStream,
}) => [
  pageContextProvider.overrideWith((ref) => contextStream),
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
// covers it, so the test app must register it on the navigator. currentIndex 3
// (profile tab) keeps the home/explore app-bar suppression rules out of play,
// so the app bar is governed solely by the own-profile-grid flag under test.
Widget _appShellMaterialApp() => MaterialApp(
  localizationsDelegates: appLocalizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  navigatorObservers: [routeObserver],
  home: const AppShell(currentIndex: 3, child: SizedBox.shrink()),
);

Widget _buildSubject({
  required _MockAuthService mockAuthService,
  required SharedPreferences sharedPreferences,
  required Stream<RouteContext> contextStream,
}) => _wrapWithBlocs(
  ProviderScope(
    overrides: _overrides(
      mockAuthService: mockAuthService,
      sharedPreferences: sharedPreferences,
      contextStream: contextStream,
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

  group(AppShell, () {
    testWidgets(
      'keeps the own-profile-grid app bar suppressed while a full-screen route '
      'covers the shell (#5925)',
      (tester) async {
        final contextController = StreamController<RouteContext>();
        addTearDown(contextController.close);

        await tester.pumpWidget(
          _buildSubject(
            mockAuthService: mockAuthService,
            sharedPreferences: sharedPreferences,
            contextStream: contextController.stream,
          ),
        );

        // Land on the own-profile grid — it renders its own scrollable header, so
        // AppShell suppresses its app bar (npub 'me' is the own-profile sentinel).
        contextController.add(
          const RouteContext(type: RouteType.profile, npub: 'me'),
        );
        await tester.pumpAndSettle();

        Scaffold shellScaffold() => tester.widget<Scaffold>(
          find
              .descendant(
                of: find.byType(AppShell, skipOffstage: false),
                matching: find.byType(Scaffold, skipOffstage: false),
              )
              .first,
        );

        expect(
          shellScaffold().appBar,
          isNull,
          reason: 'own-profile grid suppresses the shell app bar',
        );
        // Precondition: the shell is the top route, so it is not yet frozen.
        expect(shellScaffold().resizeToAvoidBottomInset, isTrue);

        // Cover the shell: any route pushed above it flips the shell's
        // ModalRoute.isCurrent to false (the same signal that gates
        // resizeToAvoidBottomInset). A modal barrier stands in for the camera
        // here — unlike a full-screen opaque route it keeps the shell onstage,
        // which is the frame the user actually sees glitch mid-transition. Then
        // the global pageContext flips to the recorder while the profile tab
        // underneath is still visible.
        final shellContext = tester.element(find.byType(AppShell));
        unawaited(
          showModalBottomSheet<void>(
            context: shellContext,
            builder: (_) => const SizedBox(height: 200),
          ),
        );
        await tester.pumpAndSettle();
        contextController.add(
          const RouteContext(type: RouteType.videoRecorder),
        );
        await tester.pumpAndSettle();

        // The shell is now covered (same isCurrent signal), so the freeze must
        // be in effect.
        expect(
          shellScaffold().resizeToAvoidBottomInset,
          isFalse,
          reason: 'the pushed route must actually cover the shell',
        );

        // Frozen to the last tab context: the recorder must not recompute the
        // chrome and pop the suppressed app bar in during the push transition.
        expect(
          shellScaffold().appBar,
          isNull,
          reason: 'chrome frozen to the covered tab; app bar must not pop in',
        );
      },
    );
  });
}
