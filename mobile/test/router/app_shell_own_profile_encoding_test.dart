// ABOUTME: AppShell must recognise the own-profile route in every :npub
// ABOUTME: encoding — a bare-hex deep link is still your own profile.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/app_update/app_update.dart';
import 'package:openvine/blocs/dm/unread_count/dm_unread_count_cubit.dart';
import 'package:openvine/blocs/notifications/badge/notification_badge_cubit.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/environment_config.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/feed/home_feed_retap_cubit.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_pubkeys.dart';

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
  required RouteContext routeContext,
}) => [
  pageContextProvider.overrideWith((ref) => Stream.value(routeContext)),
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

// currentIndex 3 (profile tab) keeps the home/explore app-bar suppression
// rules out of play, so the app bar is governed solely by the own-profile-grid
// flag under test. Mirrors app_shell_chrome_freeze_test.
Widget _buildSubject({
  required _MockAuthService mockAuthService,
  required SharedPreferences sharedPreferences,
  required RouteContext routeContext,
}) => _wrapWithBlocs(
  ProviderScope(
    overrides: _overrides(
      mockAuthService: mockAuthService,
      sharedPreferences: sharedPreferences,
      routeContext: routeContext,
    ),
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      navigatorObservers: [routeObserver],
      home: const AppShell(currentIndex: 3, child: SizedBox.shrink()),
    ),
  ),
);

void main() {
  const selfHex = syntheticTestPubkey;
  final selfNpub = NostrKeyUtils.encodePubKey(selfHex);
  final otherNpub = NostrKeyUtils.encodePubKey(syntheticOtherTestPubkey);

  late _MockAuthService mockAuthService;
  late SharedPreferences sharedPreferences;

  setUp(() async {
    mockAuthService = _MockAuthService();
    when(() => mockAuthService.currentPublicKeyHex).thenReturn(selfHex);
    when(() => mockAuthService.currentNpub).thenReturn(selfNpub);
    when(() => mockAuthService.isAuthenticated).thenReturn(true);
    when(() => mockAuthService.authState).thenReturn(AuthState.authenticated);

    SharedPreferences.setMockInitialValues(<String, Object>{});
    sharedPreferences = await SharedPreferences.getInstance();
  });

  /// The own-profile grid renders its own scrollable header, so AppShell
  /// suppresses its app bar. A null app bar therefore means "the shell decided
  /// this route is mine".
  Future<Object?> shellAppBar(WidgetTester tester, RouteContext ctx) async {
    await tester.pumpWidget(
      _buildSubject(
        mockAuthService: mockAuthService,
        sharedPreferences: sharedPreferences,
        routeContext: ctx,
      ),
    );
    await tester.pumpAndSettle();

    return tester
        .widget<Scaffold>(
          find
              .descendant(
                of: find.byType(AppShell, skipOffstage: false),
                matching: find.byType(Scaffold, skipOffstage: false),
              )
              .first,
        )
        .appBar;
  }

  group(AppShell, () {
    testWidgets('treats a bare-hex own-profile route as mine', (tester) async {
      // The defect: `/profile/<own hex>` is a documented deep-link form
      // (DEEP_LINK_URL_REFERENCE.md), but the shell compared the raw segment
      // against the signed-in npub, so it decided the route belonged to someone
      // else and popped in the other-user app bar over your own profile.
      expect(
        await shellAppBar(
          tester,
          const RouteContext(type: RouteType.profile, npub: selfHex),
        ),
        isNull,
      );
    });

    testWidgets('treats an npub own-profile route as mine', (tester) async {
      expect(
        await shellAppBar(
          tester,
          RouteContext(type: RouteType.profile, npub: selfNpub),
        ),
        isNull,
      );
    });

    testWidgets('treats the relative "me" route as mine', (tester) async {
      expect(
        await shellAppBar(
          tester,
          const RouteContext(type: RouteType.profile, npub: 'me'),
        ),
        isNull,
      );
    });

    testWidgets("keeps the app bar on another user's profile", (tester) async {
      expect(
        await shellAppBar(
          tester,
          RouteContext(type: RouteType.profile, npub: otherNpub),
        ),
        isNotNull,
      );
    });
  });
}
