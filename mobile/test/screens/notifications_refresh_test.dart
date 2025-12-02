// ABOUTME: Test for notifications screen pull-to-refresh functionality
// ABOUTME: Ensures RefreshIndicator correctly triggers NotificationServiceEnhanced refresh

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:openvine/models/notification_model.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/notifications_screen.dart';
import 'package:openvine/services/notification_service_enhanced.dart';

import 'notifications_refresh_test.mocks.dart';

@GenerateMocks([NotificationServiceEnhanced])
void main() {
  Widget shell(ProviderContainer c) => UncontrolledProviderScope(
    container: c,
    child: const MaterialApp(home: Scaffold(body: NotificationsScreen())),
  );

  group('NotificationsScreen Refresh', () {
    late MockNotificationServiceEnhanced mockNotificationService;
    late List<NotificationModel> testNotifications;

    setUp(() {
      mockNotificationService = MockNotificationServiceEnhanced();

      testNotifications = [
        NotificationModel(
          id: 'notif1',
          type: NotificationType.like,
          actorPubkey: 'user123',
          actorName: 'Test User',
          message: 'liked your video',
          timestamp: DateTime.now(),
        ),
      ];

      when(mockNotificationService.notifications).thenReturn(testNotifications);
      when(mockNotificationService.getNotificationsByType(any)).thenReturn([]);
      when(mockNotificationService.markAsRead(any)).thenAnswer((_) async {});
    });

    testWidgets('pull-to-refresh calls refreshNotifications on service', (
      WidgetTester tester,
    ) async {
      // Arrange
      when(
        mockNotificationService.refreshNotifications(),
      ).thenAnswer((_) async {});

      final c = ProviderContainer(
        overrides: [
          notificationServiceEnhancedProvider.overrideWith(
            (ref) => mockNotificationService,
          ),
        ],
      );
      addTearDown(c.dispose);

      await tester.pumpWidget(shell(c));
      await tester.pump();

      // Act: Trigger pull-to-refresh
      await tester.drag(
        find.byType(RefreshIndicator),
        const Offset(0, 300), // Drag down to trigger refresh
      );
      await tester.pump(); // Start refresh
      await tester.pump(const Duration(seconds: 1)); // Wait for refresh
      await tester.pumpAndSettle(); // Complete refresh

      // Assert: Verify refreshNotifications was called
      verify(mockNotificationService.refreshNotifications()).called(1);
    });

    testWidgets('refresh indicator is present when there are notifications', (
      WidgetTester tester,
    ) async {
      // Arrange
      when(
        mockNotificationService.refreshNotifications(),
      ).thenAnswer((_) async {});

      final c = ProviderContainer(
        overrides: [
          notificationServiceEnhancedProvider.overrideWith(
            (ref) => mockNotificationService,
          ),
        ],
      );
      addTearDown(c.dispose);

      await tester.pumpWidget(shell(c));
      await tester.pump();

      // Assert: RefreshIndicator should be present when there are notifications
      expect(find.byType(RefreshIndicator), findsOneWidget);
    });
  });
}
