// ABOUTME: Widget test verifying settings screens use proper Vine scaffold structure
// ABOUTME: Tests that settings screens have green AppBar and black background

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:openvine/screens/settings_screen.dart';
import 'package:openvine/screens/notification_settings_screen.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/theme/vine_theme.dart';

@GenerateMocks([AuthService])
import 'settings_screen_scaffold_test.mocks.dart';

void main() {
  group('Settings Screen Scaffold Structure', () {
    late MockAuthService mockAuthService;

    setUp(() {
      mockAuthService = MockAuthService();
      when(mockAuthService.isAuthenticated).thenReturn(true);
    });

    testWidgets('SettingsScreen has Vine green AppBar', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authServiceProvider.overrideWithValue(mockAuthService)],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );

      // Find the AppBar
      final appBarFinder = find.byType(AppBar);
      expect(appBarFinder, findsOneWidget);

      // Verify AppBar color is Vine green
      final AppBar appBar = tester.widget(appBarFinder);
      expect(appBar.backgroundColor, equals(VineTheme.vineGreen));
      expect(appBar.foregroundColor, equals(VineTheme.whiteText));
    });

    testWidgets('SettingsScreen has black background', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authServiceProvider.overrideWithValue(mockAuthService)],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );

      // Find the Scaffold
      final scaffoldFinder = find.byType(Scaffold);
      expect(scaffoldFinder, findsOneWidget);

      // Verify Scaffold background is black
      final Scaffold scaffold = tester.widget(scaffoldFinder);
      expect(scaffold.backgroundColor, equals(Colors.black));
    });

    testWidgets('SettingsScreen has back button when pushed', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authServiceProvider.overrideWithValue(mockAuthService)],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
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

      // Verify back button exists
      expect(find.byType(BackButton), findsOneWidget);
    });

    testWidgets('NotificationSettingsScreen has Vine green AppBar', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authServiceProvider.overrideWithValue(mockAuthService)],
          child: const MaterialApp(home: NotificationSettingsScreen()),
        ),
      );

      // Find the AppBar
      final appBarFinder = find.byType(AppBar);
      expect(appBarFinder, findsOneWidget);

      // Verify AppBar color is Vine green
      final AppBar appBar = tester.widget(appBarFinder);
      expect(appBar.backgroundColor, equals(VineTheme.vineGreen));
      expect(appBar.foregroundColor, equals(VineTheme.whiteText));
    });

    testWidgets('NotificationSettingsScreen has black background', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authServiceProvider.overrideWithValue(mockAuthService)],
          child: const MaterialApp(home: NotificationSettingsScreen()),
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
