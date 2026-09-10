// ABOUTME: Widget tests for AppShell inbox badge semantics and visibility
// ABOUTME: Verifies the inbox tab exposes unread count on the button semantics

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
import 'package:openvine/widgets/notification_badge.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockDmUnreadCountCubit extends MockCubit<int>
    implements DmUnreadCountCubit {}

class _MockNotificationBadgeCubit extends MockCubit<int>
    implements NotificationBadgeCubit {}

class _MockAppUpdateBloc extends MockBloc<AppUpdateEvent, AppUpdateState>
    implements AppUpdateBloc {}

Widget _buildSubject({
  required _MockAuthService mockAuthService,
  required SharedPreferences sharedPreferences,
  required int unreadCount,
  int dmUnreadCount = 0,
}) {
  final dmCubit = _MockDmUnreadCountCubit();
  when(() => dmCubit.state).thenReturn(dmUnreadCount);

  final notifBadgeCubit = _MockNotificationBadgeCubit();
  when(() => notifBadgeCubit.state).thenReturn(unreadCount);

  final appUpdateBloc = _MockAppUpdateBloc();
  when(() => appUpdateBloc.state).thenReturn(const AppUpdateState());

  return MultiBlocProvider(
    providers: [
      BlocProvider<DmUnreadCountCubit>.value(value: dmCubit),
      BlocProvider<NotificationBadgeCubit>.value(value: notifBadgeCubit),
      BlocProvider<AppUpdateBloc>.value(value: appUpdateBloc),
      BlocProvider<HomeFeedRetapCubit>(create: (_) => HomeFeedRetapCubit()),
    ],
    child: ProviderScope(
      overrides: [
        pageContextProvider.overrideWith(
          (ref) => Stream.value(const RouteContext(type: RouteType.home)),
        ),
        authServiceProvider.overrideWithValue(mockAuthService),
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        currentEnvironmentProvider.overrideWithValue(
          EnvironmentConfig.production,
        ),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AppShell(currentIndex: 0, child: SizedBox.shrink()),
      ),
    ),
  );
}

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

  group('$AppShell notification badge', () {
    testWidgets(
      'renders $NotificationBadge on bell tab when unread count > 0',
      (tester) async {
        final semantics = tester.ensureSemantics();

        await tester.pumpWidget(
          _buildSubject(
            mockAuthService: mockAuthService,
            sharedPreferences: sharedPreferences,
            unreadCount: 3,
          ),
        );
        await tester.pump();

        expect(find.byType(NotificationBadge), findsOneWidget);
        expect(find.text('3'), findsOneWidget);
        expect(
          find.bySemanticsLabel(
            lookupAppLocalizations(
              const Locale('en'),
            ).notificationsBadgeUnread(3),
          ),
          findsNothing,
        );
        expect(
          tester.getSemantics(find.bySemanticsLabel('Inbox')),
          matchesSemantics(
            label: 'Inbox',
            value: lookupAppLocalizations(
              const Locale('en'),
            ).notificationsBadgeUnread(3),
            isButton: true,
            isImage: true,
            hasTapAction: true,
          ),
        );
        semantics.dispose();
      },
    );

    testWidgets('renders no badge when unread count is 0', (tester) async {
      final semantics = tester.ensureSemantics();

      await tester.pumpWidget(
        _buildSubject(
          mockAuthService: mockAuthService,
          sharedPreferences: sharedPreferences,
          unreadCount: 0,
        ),
      );
      await tester.pump();

      expect(find.byType(NotificationBadge), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(NotificationBadge),
          matching: find.byType(Positioned),
        ),
        findsNothing,
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Inbox')),
        matchesSemantics(
          label: 'Inbox',
          isButton: true,
          isImage: true,
          hasTapAction: true,
        ),
      );
      semantics.dispose();
    });
  });
}
