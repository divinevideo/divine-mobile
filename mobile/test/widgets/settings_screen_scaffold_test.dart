// ABOUTME: Widget test verifying settings screens use proper Vine scaffold structure
// ABOUTME: Tests that settings screens have green AppBar and black background

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/locale/locale_cubit.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/notification_preferences.dart';
import 'package:openvine/notifications/providers/notification_repository_provider.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/screens/notification_settings_screen.dart';
import 'package:openvine/screens/settings/settings_screen.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/notification_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockLocaleCubit extends MockCubit<LocaleState> implements LocaleCubit {}

class _MockNotificationPreferencesService extends Mock
    implements NotificationPreferencesService {}

void main() {
  group('Settings Screen Scaffold Structure', () {
    late _MockAuthService mockAuthService;
    late _MockLocaleCubit mockLocaleCubit;
    late _MockNotificationPreferencesService mockPrefsService;
    late SharedPreferences sharedPreferences;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      sharedPreferences = await SharedPreferences.getInstance();
      mockAuthService = _MockAuthService();
      mockLocaleCubit = _MockLocaleCubit();
      mockPrefsService = _MockNotificationPreferencesService();
      when(
        mockPrefsService.loadPreferences,
      ).thenAnswer((_) async => const NotificationPreferences());
      when(() => mockLocaleCubit.state).thenReturn(const LocaleState());
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(() => mockAuthService.isAnonymous).thenReturn(false);
      when(() => mockAuthService.hasExpiredOAuthSession).thenReturn(false);
    });

    testWidgets('SettingsScreen has nav green AppBar', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(sharedPreferences),
            authServiceProvider.overrideWithValue(mockAuthService),
            currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: BlocProvider<LocaleCubit>.value(
              value: mockLocaleCubit,
              child: const SettingsScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the AppBar
      final appBarFinder = find.byType(AppBar);
      expect(appBarFinder, findsOneWidget);

      // Verify AppBar color is nav green
      final AppBar appBar = tester.widget(appBarFinder);
      expect(appBar.backgroundColor, equals(VineTheme.navGreen));

      // Dispose and pump to clear any pending timers from overlay visibility
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('SettingsScreen takes its background from the palette', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(sharedPreferences),
            authServiceProvider.overrideWithValue(mockAuthService),
            currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: BlocProvider<LocaleCubit>.value(
              value: mockLocaleCubit,
              child: const SettingsScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the Scaffold
      final scaffoldFinder = find.byType(Scaffold);
      expect(scaffoldFinder, findsOneWidget);

      // Follows the appearance mode; the fallback palette is the dark one.
      final Scaffold scaffold = tester.widget(scaffoldFinder);
      expect(scaffold.backgroundColor, equals(VineTheme.darkColors.surface));

      // Dispose and pump to clear any pending timers from overlay visibility
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('SettingsScreen has back button when pushed', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(sharedPreferences),
            authServiceProvider.overrideWithValue(mockAuthService),
            currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => BlocProvider<LocaleCubit>.value(
                        value: mockLocaleCubit,
                        child: const SettingsScreen(),
                      ),
                    ),
                  ),
                  child: const Text('Open Settings'),
                ),
              ),
            ),
          ),
        ),
      );

      // Tap to navigate to settings
      await tester.tap(find.text('Open Settings'));
      await tester.pumpAndSettle();

      // The design-system app bar owns the navigation control.
      expect(find.byType(DivineAppBarIconButton), findsOneWidget);
    });

    testWidgets('NotificationSettingsScreen has nav green AppBar', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(sharedPreferences),
            authServiceProvider.overrideWithValue(mockAuthService),
            notificationRepositoryProvider.overrideWithValue(null),
            // The real store starts an `openBox('notifications')` this test
            // never pumps to completion, stranding it for the whole isolate.
            notificationPreferencesServiceProvider.overrideWithValue(
              mockPrefsService,
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: NotificationSettingsScreen(),
          ),
        ),
      );

      // Find the AppBar
      final appBarFinder = find.byType(AppBar);
      expect(appBarFinder, findsOneWidget);

      // Verify AppBar color is nav green
      final AppBar appBar = tester.widget(appBarFinder);
      expect(appBar.backgroundColor, equals(VineTheme.navGreen));
    });

    testWidgets('NotificationSettingsScreen has black background', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(sharedPreferences),
            authServiceProvider.overrideWithValue(mockAuthService),
            notificationRepositoryProvider.overrideWithValue(null),
            // The real store starts an `openBox('notifications')` this test
            // never pumps to completion, stranding it for the whole isolate.
            notificationPreferencesServiceProvider.overrideWithValue(
              mockPrefsService,
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: NotificationSettingsScreen(),
          ),
        ),
      );

      // Find the Scaffold
      final scaffoldFinder = find.byType(Scaffold);
      expect(scaffoldFinder, findsOneWidget);

      // Verify Scaffold background is black
      final Scaffold scaffold = tester.widget(scaffoldFinder);
      expect(scaffold.backgroundColor, equals(VineTheme.backgroundColor));
    });
  });
}
