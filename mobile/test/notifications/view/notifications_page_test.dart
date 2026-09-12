// ABOUTME: Tests for NotificationsPage — verifies route constants and that
// ABOUTME: the page forwards bloc construction + initial refresh to the
// ABOUTME: repository and marks notifications seen on open (#4708).

import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:notification_repository/notification_repository.dart';
import 'package:openvine/notifications/providers/notification_repository_provider.dart';
import 'package:openvine/notifications/view/notifications_page.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockNotificationRepository extends Mock
    implements NotificationRepository {}

class _MockFollowRepository extends Mock implements FollowRepository {}

void main() {
  group(NotificationsPage, () {
    group('route constants', () {
      test('routeName is notifications', () {
        expect(NotificationsPage.routeName, equals('notifications'));
      });

      test('path is /notifications', () {
        expect(NotificationsPage.path, equals('/notifications'));
      });

      test('pathWithIndex includes :index parameter', () {
        expect(
          NotificationsPage.pathWithIndex,
          equals('/notifications/:index'),
        );
      });

      test('pathForIndex with null returns base path', () {
        expect(NotificationsPage.pathForIndex(), equals('/notifications'));
      });

      test('pathForIndex with index returns indexed path', () {
        expect(NotificationsPage.pathForIndex(0), equals('/notifications/0'));
      });

      test('pathForIndex with non-zero index returns correct path', () {
        expect(NotificationsPage.pathForIndex(42), equals('/notifications/42'));
      });
    });

    group('initial load', () {
      late _MockNotificationRepository mockNotificationRepo;
      late _MockFollowRepository mockFollowRepo;

      setUp(() {
        mockNotificationRepo = _MockNotificationRepository();
        mockFollowRepo = _MockFollowRepository();

        when(
          () =>
              mockNotificationRepo.watchSnapshot(filter: any(named: 'filter')),
        ).thenAnswer((_) => const Stream<NotificationPage>.empty());
        when(
          () => mockNotificationRepo.refreshFeed(any()),
        ).thenAnswer((_) async => NotificationPage.empty);
        when(
          () => mockNotificationRepo.markAllAsRead(),
        ).thenAnswer((_) async {});
        when(() => mockFollowRepo.isFollowing(any())).thenReturn(false);
      });

      Widget buildSubject() {
        return testMaterialApp(
          mockFollowRepository: mockFollowRepo,
          additionalOverrides: [
            notificationRepositoryProvider.overrideWithValue(
              mockNotificationRepo,
            ),
          ],
          home: const NotificationsPage(),
        );
      }

      testWidgets('calls repository.refresh() once on open', (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        verify(() => mockNotificationRepo.refreshFeed(null)).called(1);
      });

      testWidgets('marks notifications seen on open', (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        // Opening advances the server read watermark so the badge clears and
        // thereafter shows "new since last seen" (#4708).
        verify(() => mockNotificationRepo.markAllAsRead()).called(1);
      });

      testWidgets(
        'marks seen on open but not again when the page is unmounted',
        (tester) async {
          await tester.pumpWidget(buildSubject());
          await tester.pumpAndSettle();
          // Marked seen exactly once on open.
          verify(() => mockNotificationRepo.markAllAsRead()).called(1);
          clearInteractions(mockNotificationRepo);

          // Leaving the notifications route (e.g. switching bottom-nav tabs;
          // the ShellRoute is not stateful, so the page unmounts) must NOT
          // mark read again on *leave* — #4758 removed mark-on-dispose;
          // #4708 added mark-on-open, and pull-to-refresh can also mark
          // while the notifications surface is deliberately open.
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();

          verifyNever(() => mockNotificationRepo.markAllAsRead());
        },
      );
    });
  });
}
