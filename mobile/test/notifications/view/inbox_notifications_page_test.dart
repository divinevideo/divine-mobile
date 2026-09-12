// ABOUTME: Widget tests for InboxNotificationsPage — verifies that opening
// ABOUTME: the inbox marks notifications seen once (advances the read
// ABOUTME: watermark, #4708) and that each tab opens its own filtered feed.

// Fresh widget instances make per-pump fixture ownership explicit.
import 'package:badge_repository/badge_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:notification_repository/notification_repository.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/notifications/providers/notification_repository_provider.dart';
import 'package:openvine/notifications/view/inbox_notifications_page.dart';
import 'package:openvine/notifications/view/pending_badge_awards_view.dart';
import 'package:openvine/providers/app_providers.dart';

import '../../helpers/badge_fixtures.dart';
import '../../helpers/test_provider_overrides.dart';

class _MockNotificationRepository extends Mock
    implements NotificationRepository {}

class _MockFollowRepository extends Mock implements FollowRepository {}

class _MockBadgeRepository extends Mock implements BadgeRepository {}

void main() {
  group(InboxNotificationsPage, () {
    late _MockNotificationRepository mockNotificationRepo;
    late _MockFollowRepository mockFollowRepo;
    late _MockBadgeRepository mockBadgeRepo;

    setUp(() {
      mockNotificationRepo = _MockNotificationRepository();
      mockFollowRepo = _MockFollowRepository();
      mockBadgeRepo = _MockBadgeRepository();

      when(mockBadgeRepo.loadDashboard).thenAnswer(
        (_) async =>
            const BadgeDashboardData(awarded: [], issued: [], created: []),
      );

      when(
        () => mockNotificationRepo.watchSnapshot(filter: any(named: 'filter')),
      ).thenAnswer((_) => const Stream<NotificationPage>.empty());
      when(
        () => mockNotificationRepo.refreshFeed(any()),
      ).thenAnswer((_) async => NotificationPage.empty);
      when(() => mockNotificationRepo.markAllAsRead()).thenAnswer((_) async {});
      when(() => mockFollowRepo.isFollowing(any())).thenReturn(false);
    });

    Widget buildSubject({
      bool reduceMotion = false,
      bool isVisible = true,
    }) {
      return testMaterialApp(
        mockFollowRepository: mockFollowRepo,
        additionalOverrides: [
          notificationRepositoryProvider.overrideWithValue(
            mockNotificationRepo,
          ),
          badgeRepositoryProvider.overrideWithValue(mockBadgeRepo),
        ],
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: reduceMotion),
            child: Scaffold(
              body: InboxNotificationsPage(isVisible: isVisible),
            ),
          ),
        ),
      );
    }

    testWidgets('opens the bloc via NotificationFeedStarted on first build', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Opening the inbox refreshes and marks notifications seen (advances the
      // server read watermark) so the badge reflects "new since last seen"
      // (#4708).
      verify(() => mockNotificationRepo.refreshFeed(null)).called(1);
      verify(() => mockNotificationRepo.markAllAsRead()).called(1);
    });

    testWidgets(
      'marks seen on open but not again when the inbox page is unmounted',
      (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();
        // Marked seen exactly once on open.
        verify(() => mockNotificationRepo.markAllAsRead()).called(1);
        clearInteractions(mockNotificationRepo);

        // Leaving the inbox (toggling to the Messages segment so the
        // notifications KeyedSubtree is swapped out, or leaving the inbox tab
        // so the ShellRoute unmounts the subtree) must NOT mark read again on
        // *leave* — #4758 removed the old mark-on-dispose. #4708 added
        // mark-on-open, and pull-to-refresh can also mark while the
        // notifications surface is deliberately open.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();

        verifyNever(() => mockNotificationRepo.markAllAsRead());
      },
    );

    testWidgets('marks seen again when a kept-alive inbox becomes visible', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(isVisible: false));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      verify(() => mockNotificationRepo.markAllAsRead()).called(1);
      clearInteractions(mockNotificationRepo);

      await tester.pumpWidget(buildSubject());
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));

      verifyNever(() => mockNotificationRepo.refreshFeed(null));
      verify(() => mockNotificationRepo.markAllAsRead()).called(1);
    });

    testWidgets(
      'opens each tab against its own server-filtered feed and marks seen '
      'only on the All tab',
      (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        // Tab order is load-bearing: each index must open the feed its label
        // promises, or a transposed entry silently shows e.g. reposts under
        // Comments.
        const tabFilters = <NotificationKind>[
          NotificationKind.like,
          NotificationKind.comment,
          NotificationKind.follow,
          NotificationKind.repost,
        ];

        verify(() => mockNotificationRepo.refreshFeed(null)).called(1);

        for (var i = 0; i < tabFilters.length; i++) {
          await tester.tap(find.byType(Tab).at(i + 1));
          await tester.pumpAndSettle();

          // Asserted per tap, not as a set at the end — a set assertion
          // passes even when two tabs are swapped.
          verify(
            () => mockNotificationRepo.refreshFeed(tabFilters[i]),
          ).called(1);
        }

        // The seen watermark advances for the unfiltered feed (#4708) —
        // never once per filter tab.
        verify(() => mockNotificationRepo.markAllAsRead()).called(1);
      },
    );

    testWidgets('keeps visited tab blocs alive across tab switches', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      verify(() => mockNotificationRepo.refreshFeed(null)).called(1);
      verify(() => mockNotificationRepo.markAllAsRead()).called(1);
      clearInteractions(mockNotificationRepo);

      await tester.tap(find.byType(Tab).at(1));
      await tester.pumpAndSettle();

      verify(
        () => mockNotificationRepo.refreshFeed(NotificationKind.like),
      ).called(1);
      verifyNever(() => mockNotificationRepo.markAllAsRead());
      clearInteractions(mockNotificationRepo);

      await tester.tap(find.byType(Tab).at(0));
      await tester.pumpAndSettle();

      verifyNever(() => mockNotificationRepo.refreshFeed(null));
      verifyNever(() => mockNotificationRepo.markAllAsRead());
    });

    group('reduced motion', () {
      TabController controller(WidgetTester tester) =>
          tester.widget<TabBar>(find.byType(TabBar)).controller!;

      testWidgets('switches tabs without sliding the indicator or the page', (
        tester,
      ) async {
        await tester.pumpWidget(buildSubject(reduceMotion: true));
        await tester.pumpAndSettle();

        await tester.tap(find.byType(Tab).at(3));
        await tester.pump();

        // The controller's animation drives both the indicator slide and the
        // TabBarView page offset, so landing on the target in the first frame
        // is the whole transition resolving instantly.
        expect(controller(tester).animation!.value, equals(3.0));
        expect(controller(tester).indexIsChanging, isFalse);
      });

      testWidgets('still animates when reduced motion is off', (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        await tester.tap(find.byType(Tab).at(3));
        await tester.pump();

        expect(controller(tester).animation!.value, lessThan(3.0));
        await tester.pumpAndSettle();
        expect(controller(tester).animation!.value, equals(3.0));
      });

      testWidgets('keeps the open tab when the setting is toggled', (
        tester,
      ) async {
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();
        await tester.tap(find.byType(Tab).at(2));
        await tester.pumpAndSettle();

        // The controller is rebuilt to pick up the new duration; the tab the
        // user was reading must survive that swap.
        await tester.pumpWidget(buildSubject(reduceMotion: true));
        await tester.pumpAndSettle();

        expect(controller(tester).index, equals(2));
        expect(controller(tester).animationDuration, equals(Duration.zero));
      });
    });

    group('badges tab', () {
      final l10n = lookupAppLocalizations(const Locale('en'));

      void stubPending(int count) {
        when(mockBadgeRepo.loadDashboard).thenAnswer(
          (_) async => BadgeDashboardData(
            awarded: [
              for (var i = 0; i < count; i++)
                badgeAwardFixture(
                  isAccepted: false,
                  name: 'Badge $i',
                  dTag: 'badge-$i',
                  seed: i + 1,
                ),
            ],
            issued: const [],
            created: const [],
          ),
        );
      }

      testWidgets('counts awards waiting on a decision in the tab label', (
        tester,
      ) async {
        stubPending(2);

        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        expect(find.text(l10n.notificationsTabBadges(2)), findsOneWidget);
      });

      testWidgets('drops the count once nothing is waiting', (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        expect(find.text(l10n.notificationsTabBadges(0)), findsOneWidget);
        expect(find.textContaining('Badges ('), findsNothing);
      });

      testWidgets('banner on the All tab opens the badges queue', (
        tester,
      ) async {
        stubPending(1);

        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        expect(find.text(l10n.notificationsPendingBadges(1)), findsOneWidget);

        await tester.tap(find.text(l10n.notificationsPendingBadges(1)));
        await tester.pumpAndSettle();

        expect(find.byType(PendingBadgeAwardsView), findsOneWidget);
        expect(find.text('Badge 0'), findsOneWidget);
      });

      testWidgets('hides the banner when no award is waiting', (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        expect(find.text(l10n.notificationsPendingBadges(1)), findsNothing);
      });

      testWidgets('reloads pending awards when the inbox becomes visible', (
        tester,
      ) async {
        await tester.pumpWidget(buildSubject(isVisible: false));
        await tester.pumpAndSettle();

        verify(mockBadgeRepo.loadDashboard).called(1);
        clearInteractions(mockBadgeRepo);

        await tester.pumpWidget(buildSubject());
        await tester.pump();
        await tester.pump();

        verify(mockBadgeRepo.loadDashboard).called(1);
      });
    });
  });
}
