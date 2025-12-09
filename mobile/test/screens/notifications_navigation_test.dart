// ABOUTME: Test for notifications screen navigation to videos and profiles
// ABOUTME: Ensures tapping notifications navigates to correct video or profile

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:openvine/models/notification_model.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/video_events_providers.dart';
import 'package:openvine/router/app_router.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/screens/pure/explore_video_screen_pure.dart';
import 'package:openvine/services/notification_service_enhanced.dart';
import 'package:openvine/widgets/notification_list_item.dart';

import 'notifications_navigation_test.mocks.dart';

// Mock VideoEvents without timers
class MockVideoEventsNoTimers extends VideoEvents {
  @override
  Stream<List<VideoEvent>> build() async* {
    yield [];
  }
}

@GenerateMocks([NotificationServiceEnhanced])
void main() {
  Widget shell(ProviderContainer c) => UncontrolledProviderScope(
    container: c,
    child: MaterialApp.router(routerConfig: c.read(goRouterProvider)),
  );

  String currentLocation(ProviderContainer c) {
    final router = c.read(goRouterProvider);
    return router.routeInformationProvider.value.uri.toString();
  }

  group('NotificationsScreen Navigation', () {
    late MockNotificationServiceEnhanced mockNotificationService;
    late List<NotificationModel> testNotifications;

    setUp(() {
      mockNotificationService = MockNotificationServiceEnhanced();

      testNotifications = [
        NotificationModel(
          id: 'notif1',
          type: NotificationType.like,
          actorPubkey: 'user123abcdef',
          actorName: 'Test User',
          message: 'liked your video',
          timestamp: DateTime.now(),
          targetEventId: 'video123',
        ),
        NotificationModel(
          id: 'notif2',
          type: NotificationType.follow,
          actorPubkey: 'user456abcdef',
          actorName: 'Another User',
          message: 'started following you',
          timestamp: DateTime.now(),
        ),
      ];

      when(mockNotificationService.notifications).thenReturn(testNotifications);
      when(mockNotificationService.getNotificationsByType(any)).thenReturn([]);
      when(mockNotificationService.markAsRead(any)).thenAnswer((_) async {});
    });

    testWidgets(
      'tapping notification with video shows error when video not found',
      (WidgetTester tester) async {
        // Arrange - No video event service override, so video won't be found
        final c = ProviderContainer(
          overrides: [
            notificationServiceEnhancedProvider.overrideWith(
              (ref) => mockNotificationService,
            ),
            // Override videoEventsProvider to prevent timer issues in tests
            videoEventsProvider.overrideWith(() => MockVideoEventsNoTimers()),
          ],
        );
        addTearDown(c.dispose);

        await tester.pumpWidget(shell(c));

        // Navigate to notifications
        c.read(goRouterProvider).go('/notifications/0');
        await tester.pump();
        await tester.pump();

        await tester.pumpAndSettle();

        // Act: Tap on first notification (with video ID that doesn't exist)
        final firstNotification = find.byType(NotificationListItem).first;
        await tester.tap(firstNotification);
        await tester.pump(); // Trigger tap
        await tester.pump(); // Process tap and show snackbar

        // Assert: Should show "Video not found" snackbar instead of navigating
        expect(find.text('Video not found'), findsOneWidget);
        expect(find.byType(ExploreVideoScreenPure), findsNothing);

        // Verify markAsRead was called
        verify(mockNotificationService.markAsRead('notif1')).called(1);
      },
    );

    testWidgets('tapping notification without video navigates to profile', (
      WidgetTester tester,
    ) async {
      final user456Npub = NostrKeyUtils.encodePubKey('user456abcdef');

      // Arrange
      final c = ProviderContainer(
        overrides: [
          notificationServiceEnhancedProvider.overrideWith(
            (ref) => mockNotificationService,
          ),
          // Override videoEventsProvider to prevent timer issues in tests
          videoEventsProvider.overrideWith(() => MockVideoEventsNoTimers()),
        ],
      );
      addTearDown(c.dispose);

      await tester.pumpWidget(shell(c));

      // Navigate to notifications
      c.read(goRouterProvider).go('/notifications/0');
      await tester.pump();
      await tester.pump();

      await tester.pumpAndSettle();

      // Act: Tap on second notification (follow, no video)
      final secondNotification = find.byType(NotificationListItem).at(1);
      await tester.tap(secondNotification);

      // Pump frames to allow navigation and ProfileScreen initialization
      await tester.pump(); // Start navigation
      await tester.pump(); // Complete navigation animation
      await tester.pump(); // PostFrameCallback execution
      await tester.pump(); // State update from _initializeProfile

      // Assert: Should navigate to profile screen
      expect(currentLocation(c), contains('/profile/$user456Npub'));

      // Verify markAsRead was called
      verify(mockNotificationService.markAsRead('notif2')).called(1);
    });
  });
}
