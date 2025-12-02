// ABOUTME: Widget test for unified settings screen
// ABOUTME: Verifies settings navigation and UI structure

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:openvine/screens/settings_screen.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/providers/app_providers.dart';

@GenerateMocks([AuthService])
import 'settings_screen_test.mocks.dart';

void main() {
  group('SettingsScreen Tests', () {
    late MockAuthService mockAuthService;

    setUp(() {
      mockAuthService = MockAuthService();
      when(mockAuthService.isAuthenticated).thenReturn(true);
    });

    testWidgets('Settings screen displays all sections', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authServiceProvider.overrideWithValue(mockAuthService)],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );

      // Verify section headers (displayed as uppercase)
      expect(find.text('PROFILE'), findsOneWidget);
      expect(find.text('NETWORK'), findsOneWidget);
      expect(find.text('PREFERENCES'), findsOneWidget);
    });

    testWidgets('Settings tiles display correctly', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authServiceProvider.overrideWithValue(mockAuthService)],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );

      // Verify profile settings
      expect(find.text('Edit Profile'), findsOneWidget);
      expect(find.text('Key Management'), findsOneWidget);

      // Verify network settings
      expect(find.text('Relays'), findsOneWidget);
      expect(find.text('Relay Diagnostics'), findsOneWidget);
      expect(find.text('Media Servers'), findsOneWidget);

      // CRITICAL: P2P Sync should be hidden for release
      expect(find.text('P2P Sync'), findsNothing);
      expect(find.text('Peer-to-peer synchronization settings'), findsNothing);
    });

    testWidgets('Settings tiles have proper icons', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authServiceProvider.overrideWithValue(mockAuthService)],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );

      // Verify icons exist
      expect(find.byIcon(Icons.person), findsWidgets); // Edit Profile
      expect(find.byIcon(Icons.key), findsWidgets); // Key Management
      expect(find.byIcon(Icons.hub), findsWidgets); // Relays
      expect(
        find.byIcon(Icons.troubleshoot),
        findsWidgets,
      ); // Relay Diagnostics
      expect(find.byIcon(Icons.cloud_upload), findsWidgets); // Media Servers

      // CRITICAL: P2P Sync icon (Icons.sync) should be hidden for release
      expect(find.byIcon(Icons.sync), findsNothing);
    });

    testWidgets('App bar displays correctly', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authServiceProvider.overrideWithValue(mockAuthService)],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );

      expect(find.text('Settings'), findsOneWidget);
      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.backgroundColor, isNotNull);
    });
  });
}
