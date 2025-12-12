// ABOUTME: Tests for the tabbed settings screen with Profile, Network, and Notifications tabs
// ABOUTME: Verifies tab navigation and inline content display for each settings section

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/settings_screen.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/blossom_upload_service.dart';
import 'package:openvine/services/bug_report_service.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/services/notification_service_enhanced.dart';

import 'tabbed_settings_screen_test.mocks.dart';

@GenerateMocks([
  AuthService,
  NostrClient,
  BlossomUploadService,
  NotificationServiceEnhanced,
  BugReportService,
])
void main() {
  late MockAuthService mockAuthService;
  late MockNostrClient mockNostrService;
  late MockBlossomUploadService mockBlossomService;
  late MockNotificationServiceEnhanced mockNotificationService;
  late MockBugReportService mockBugReportService;

  setUp(() {
    mockAuthService = MockAuthService();
    mockNostrService = MockNostrClient();
    mockBlossomService = MockBlossomUploadService();
    mockNotificationService = MockNotificationServiceEnhanced();
    mockBugReportService = MockBugReportService();

    // Default mock behaviors
    when(mockAuthService.isAuthenticated).thenReturn(true);
    when(mockAuthService.currentPublicKeyHex).thenReturn('test_pubkey');
    when(mockNostrService.configuredRelays).thenReturn([]);
    when(mockBlossomService.isBlossomEnabled()).thenAnswer((_) async => false);
    when(mockBlossomService.getBlossomServer()).thenAnswer((_) async => null);
  });

  Widget createTestWidget() {
    return ProviderScope(
      overrides: [
        authServiceProvider.overrideWithValue(mockAuthService),
        nostrServiceProvider.overrideWithValue(mockNostrService),
        blossomUploadServiceProvider.overrideWithValue(mockBlossomService),
        notificationServiceEnhancedProvider.overrideWithValue(
          mockNotificationService,
        ),
        bugReportServiceProvider.overrideWithValue(mockBugReportService),
      ],
      child: const MaterialApp(home: SettingsScreen()),
    );
  }

  group('Tabbed Settings Screen -', () {
    testWidgets('should display TabBar with three tabs', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Should have a TabBar
      expect(find.byType(TabBar), findsOneWidget);

      // Should have exactly 3 tabs
      expect(find.byType(Tab), findsNWidgets(3));

      // Verify tab labels
      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('Network'), findsOneWidget);
      expect(find.text('Notifications'), findsOneWidget);
    });

    testWidgets('should switch between tabs when tapped', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Initially on Profile tab
      expect(find.text('Profile'), findsOneWidget);

      // Tap Network tab
      await tester.tap(find.text('Network'));
      await tester.pumpAndSettle();

      // Verify Network tab is selected
      final TabBar tabBar = tester.widget(find.byType(TabBar));
      final TabController? controller = tabBar.controller;
      expect(controller?.index, 1);

      // Tap Notifications tab
      await tester.tap(find.text('Notifications'));
      await tester.pumpAndSettle();

      expect(controller?.index, 2);
    });

    testWidgets('should display Account section before tabs', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Account section should be visible before tabs
      expect(find.text('ACCOUNT'), findsOneWidget);
      expect(find.text('Log Out'), findsOneWidget);
      expect(find.text('Remove Keys from Device'), findsOneWidget);
      expect(find.text('Delete All Content from Relays'), findsOneWidget);
    });

    testWidgets('should display Support section after tabs', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Scroll to bottom to see Support section
      await tester.drag(find.byType(ListView).first, const Offset(0, -500));
      await tester.pumpAndSettle();

      // Support section should be visible after tabs
      expect(find.text('SUPPORT'), findsOneWidget);
      expect(find.text('ProofMode Info'), findsOneWidget);
      expect(find.text('Report a Bug'), findsOneWidget);
      expect(find.text('Save Logs'), findsOneWidget);
    });
  });

  group('Profile Tab -', () {
    testWidgets('should display profile editing fields inline', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Should be on Profile tab by default
      // Verify profile editing controls are visible
      expect(find.text('Display Name'), findsOneWidget);
      expect(find.text('Bio'), findsOneWidget);
      expect(find.byType(TextField), findsAtLeastNWidgets(2));
    });

    testWidgets('should have avatar upload section', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Should show avatar section
      expect(find.text('Profile Picture'), findsOneWidget);
      expect(find.byIcon(Icons.camera_alt), findsOneWidget);
    });

    testWidgets('should have NIP-05 username field', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Should show NIP-05 section
      expect(find.text('Username'), findsOneWidget);
      expect(find.textContaining('@openvine.co'), findsOneWidget);
    });

    testWidgets('should have Save Profile button', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Should have save button
      expect(find.text('Save Profile'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsAtLeastNWidgets(1));
    });

    testWidgets('should navigate to Key Management screen', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Should have Key Management button that navigates
      expect(find.text('Key Management'), findsOneWidget);
      expect(
        find.text('Export, backup, and restore your Nostr keys'),
        findsOneWidget,
      );
    });
  });

  group('Network Tab -', () {
    testWidgets('should display relay list inline', (tester) async {
      when(
        mockNostrService.configuredRelays,
      ).thenReturn(['wss://relay1.example.com', 'wss://relay2.example.com']);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Switch to Network tab
      await tester.tap(find.text('Network'));
      await tester.pumpAndSettle();

      // Should show relay section
      expect(find.text('RELAYS'), findsOneWidget);
      expect(find.text('wss://relay1.example.com'), findsOneWidget);
      expect(find.text('wss://relay2.example.com'), findsOneWidget);
    });

    testWidgets('should have Add Relay button', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Switch to Network tab
      await tester.tap(find.text('Network'));
      await tester.pumpAndSettle();

      // Should have add relay button
      expect(find.text('Add Relay'), findsOneWidget);
    });

    testWidgets('should display Blossom server settings inline', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Switch to Network tab
      await tester.tap(find.text('Network'));
      await tester.pumpAndSettle();

      // Should show Blossom section
      expect(find.text('MEDIA SERVERS'), findsOneWidget);
      expect(find.text('Use Blossom Upload'), findsOneWidget);
      expect(find.byType(Switch), findsAtLeastNWidgets(1));
    });

    testWidgets('should show Blossom server URL field when enabled', (
      tester,
    ) async {
      when(mockBlossomService.isBlossomEnabled()).thenAnswer((_) async => true);
      when(
        mockBlossomService.getBlossomServer(),
      ).thenAnswer((_) async => 'https://blossom.band');

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Switch to Network tab
      await tester.tap(find.text('Network'));
      await tester.pumpAndSettle();

      // Should show server URL field
      expect(find.text('Blossom Server URL'), findsOneWidget);
      expect(find.text('https://blossom.band'), findsOneWidget);
    });

    testWidgets('should have Relay Diagnostics navigation button', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Switch to Network tab
      await tester.tap(find.text('Network'));
      await tester.pumpAndSettle();

      // Should have diagnostics button
      expect(find.text('Relay Diagnostics'), findsOneWidget);
    });
  });

  group('Notifications Tab -', () {
    testWidgets('should display notification type toggles', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Switch to Notifications tab
      await tester.tap(find.text('Notifications'));
      await tester.pumpAndSettle();

      // Should show all notification types
      expect(find.text('NOTIFICATION TYPES'), findsOneWidget);
      expect(find.text('Likes'), findsOneWidget);
      expect(find.text('Comments'), findsOneWidget);
      expect(find.text('Follows'), findsOneWidget);
      expect(find.text('Mentions'), findsOneWidget);
      expect(find.text('Reposts'), findsOneWidget);
      expect(find.text('System'), findsOneWidget);

      // Should have switches for each
      expect(find.byType(Switch), findsAtLeastNWidgets(6));
    });

    testWidgets('should display push notification settings', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Switch to Notifications tab
      await tester.tap(find.text('Notifications'));
      await tester.pumpAndSettle();

      // Should show push settings
      expect(find.text('PUSH NOTIFICATIONS'), findsOneWidget);
      expect(find.text('Push Notifications'), findsOneWidget);
      expect(find.text('Sound'), findsOneWidget);
      expect(find.text('Vibration'), findsOneWidget);
    });

    testWidgets('should have notification actions inline', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Switch to Notifications tab
      await tester.tap(find.text('Notifications'));
      await tester.pumpAndSettle();

      // Should show action buttons
      expect(find.text('ACTIONS'), findsOneWidget);
      expect(find.text('Mark All as Read'), findsOneWidget);
      expect(find.text('Clear Old Notifications'), findsOneWidget);
    });

    testWidgets('should trigger mark all as read action', (tester) async {
      when(mockNotificationService.markAllAsRead()).thenAnswer((_) async => {});

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Switch to Notifications tab
      await tester.tap(find.text('Notifications'));
      await tester.pumpAndSettle();

      // Tap mark all as read
      await tester.tap(find.text('Mark All as Read'));
      await tester.pumpAndSettle();

      // Verify service was called
      verify(mockNotificationService.markAllAsRead()).called(1);
    });
  });
}
