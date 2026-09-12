// ABOUTME: Regression tests for the BlocProvider repo-swap pattern in
// ABOUTME: NotificationsPage + InboxNotificationsPage — verifies that the
// ABOUTME: NotificationFeedBloc is recreated when its Riverpod-provided
// ABOUTME: repositories rebuild (auth flip / sign-out / account switch).
//
// Mirrors `conversation_page_repo_swap_test.dart` and the canonical
// pooled-feed repo-swap tests. The production sites are
// `mobile/lib/notifications/view/notifications_page.dart` and
// `mobile/lib/notifications/view/inbox_notifications_page.dart`, each
// carrying `BlocProvider<NotificationFeedBloc>(key: ValueKey((
// notificationRepository, followRepository)), …)`. Without the key,
// the BlocProvider element persists across rebuilds and the bloc stays
// bound to stale repositories.

import 'package:badge_repository/badge_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:invite_api_client/invite_api_client.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:notification_repository/notification_repository.dart';
import 'package:openvine/blocs/invite_status/invite_status_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/notifications/bloc/notification_feed_bloc.dart';
import 'package:openvine/notifications/providers/notification_repository_provider.dart';
import 'package:openvine/notifications/view/inbox_notifications_page.dart';
import 'package:openvine/notifications/view/notifications_page.dart';
import 'package:openvine/notifications/view/notifications_view.dart';
import 'package:openvine/providers/app_providers.dart';

import '../../helpers/badge_fixtures.dart';

class _MockNotificationRepository extends Mock
    implements NotificationRepository {}

class _MockFollowRepository extends Mock implements FollowRepository {}

/// The inbox page reads the badge repository for its Badges tab. These tests
/// only swap the notification and follow repositories, so a stub keeps the
/// real one — and its SharedPreferences dependency — out of the scope.
class _MockBadgeRepository extends Mock implements BadgeRepository {}

_MockBadgeRepository _stubBadgeRepository({int pendingAwards = 0}) {
  final repository = _MockBadgeRepository();
  when(repository.loadDashboard).thenAnswer(
    (_) async => BadgeDashboardData(
      awarded: [
        for (var i = 0; i < pendingAwards; i++)
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
  return repository;
}

class _MockInviteStatusCubit extends MockCubit<InviteStatusState>
    implements InviteStatusCubit {}

final _notificationRepoSwap = StateProvider<int>((ref) => 0);
final _followRepoSwap = StateProvider<int>((ref) => 0);
final _badgeRepoSwap = StateProvider<int>((ref) => 0);

void main() {
  group('NotificationsPage — BlocProvider repo-swap', () {
    late _MockNotificationRepository mockNotificationRepoA;
    late _MockNotificationRepository mockNotificationRepoB;
    late _MockFollowRepository mockFollowRepoA;
    late _MockFollowRepository mockFollowRepoB;

    setUp(() {
      mockNotificationRepoA = _MockNotificationRepository();
      mockNotificationRepoB = _MockNotificationRepository();
      mockFollowRepoA = _MockFollowRepository();
      mockFollowRepoB = _MockFollowRepository();

      for (final repo in [mockNotificationRepoA, mockNotificationRepoB]) {
        when(
          () => repo.watchSnapshot(filter: any(named: 'filter')),
        ).thenAnswer((_) => const Stream<NotificationPage>.empty());
        when(
          () => repo.refreshFeed(any()),
        ).thenAnswer((_) async => NotificationPage.empty);
        when(repo.markAllAsRead).thenAnswer((_) async {});
      }

      for (final repo in [mockFollowRepoA, mockFollowRepoB]) {
        when(() => repo.isFollowing(any())).thenReturn(false);
      }
    });

    testWidgets(
      'recreates NotificationFeedBloc when notificationRepositoryProvider '
      'rebuilds with a new repository instance',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            badgeRepositoryProvider.overrideWithValue(_stubBadgeRepository()),
            notificationRepositoryProvider.overrideWith((ref) {
              final v = ref.watch(_notificationRepoSwap);
              return v == 0 ? mockNotificationRepoA : mockNotificationRepoB;
            }),
            followRepositoryProvider.overrideWithValue(mockFollowRepoA),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          _TestApp(container: container, home: const NotificationsPage()),
        );
        await tester.pump();

        final blocBefore = _notificationFeedBlocFor(tester);
        expect(blocBefore.isClosed, isFalse);

        container.read(_notificationRepoSwap.notifier).state = 1;
        await tester.pump();

        final blocAfter = _notificationFeedBlocFor(tester);
        expect(
          blocAfter,
          isNot(same(blocBefore)),
          reason:
              'The page captures notificationRepository in BlocProvider.create. '
              'When the provider identity flips, the ValueKey must recreate '
              'NotificationFeedBloc so the page does not keep a stale repo.',
        );
      },
    );

    testWidgets(
      'recreates NotificationFeedBloc when followRepositoryProvider rebuilds '
      'with a new repository instance',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            badgeRepositoryProvider.overrideWithValue(_stubBadgeRepository()),
            notificationRepositoryProvider.overrideWithValue(
              mockNotificationRepoA,
            ),
            followRepositoryProvider.overrideWith((ref) {
              final v = ref.watch(_followRepoSwap);
              return v == 0 ? mockFollowRepoA : mockFollowRepoB;
            }),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          _TestApp(container: container, home: const NotificationsPage()),
        );
        await tester.pump();

        final blocBefore = _notificationFeedBlocFor(tester);
        expect(blocBefore.isClosed, isFalse);

        container.read(_followRepoSwap.notifier).state = 1;
        await tester.pump();

        final blocAfter = _notificationFeedBlocFor(tester);
        expect(
          blocAfter,
          isNot(same(blocBefore)),
          reason:
              'The page also captures followRepository in BlocProvider.create. '
              'The record ValueKey must include it so follow-back state uses '
              'the active repository after auth-driven rebuilds.',
        );
      },
    );

    testWidgets(
      'preserves the same NotificationFeedBloc when neither dependency '
      'identity changes across rebuilds',
      (tester) async {
        final rebuildKey = GlobalKey<_RebuildHostState>();
        final container = ProviderContainer(
          overrides: [
            badgeRepositoryProvider.overrideWithValue(_stubBadgeRepository()),
            notificationRepositoryProvider.overrideWithValue(
              mockNotificationRepoA,
            ),
            followRepositoryProvider.overrideWithValue(mockFollowRepoA),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          _TestApp(
            container: container,
            home: RebuildHost(
              key: rebuildKey,
              child: const NotificationsPage(),
            ),
          ),
        );
        await tester.pump();

        final blocBefore = _notificationFeedBlocFor(tester);

        rebuildKey.currentState!.rebuild();
        await tester.pump();

        final blocAfter = _notificationFeedBlocFor(tester);
        expect(
          blocAfter,
          same(blocBefore),
          reason:
              'Rebuilding with the same dependency identities should keep the '
              'same bloc. The record key must avoid unnecessary churn.',
        );
      },
    );

    testWidgets(
      'drops prior bloc state when notificationRepositoryProvider rebuilds '
      '(intentional)',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            badgeRepositoryProvider.overrideWithValue(_stubBadgeRepository()),
            notificationRepositoryProvider.overrideWith((ref) {
              final v = ref.watch(_notificationRepoSwap);
              return v == 0 ? mockNotificationRepoA : mockNotificationRepoB;
            }),
            followRepositoryProvider.overrideWithValue(mockFollowRepoA),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          _TestApp(container: container, home: const NotificationsPage()),
        );
        await tester.pump();

        final blocBefore = _notificationFeedBlocFor(tester);
        blocBefore.emit(
          const NotificationFeedState(
            status: NotificationFeedStatus.loaded,
            unreadCount: 9,
            hasMore: false,
            isLoadingMore: true,
            refreshError: true,
          ),
        );
        await tester.pump();
        expect(blocBefore.state.unreadCount, equals(9));
        expect(blocBefore.state.hasMore, isFalse);
        expect(blocBefore.state.refreshError, isTrue);

        container.read(_notificationRepoSwap.notifier).state = 1;
        await tester.pump();

        final blocAfter = _notificationFeedBlocFor(tester);
        expect(blocAfter, isNot(same(blocBefore)));
        expect(
          blocAfter.state.unreadCount,
          equals(0),
          reason: 'A recreated bloc must not inherit the old unread count.',
        );
        expect(
          blocAfter.state.hasMore,
          isTrue,
          reason: 'A recreated bloc must restart with fresh pagination state.',
        );
        expect(
          blocAfter.state.refreshError,
          isFalse,
          reason: 'A recreated bloc must not inherit the old refresh error.',
        );
      },
    );
  });

  group('InboxNotificationsPage — BlocProvider repo-swap', () {
    late _MockNotificationRepository mockNotificationRepoA;
    late _MockNotificationRepository mockNotificationRepoB;
    late _MockFollowRepository mockFollowRepoA;
    late _MockFollowRepository mockFollowRepoB;
    late _MockInviteStatusCubit mockInviteCubit;

    setUp(() {
      mockNotificationRepoA = _MockNotificationRepository();
      mockNotificationRepoB = _MockNotificationRepository();
      mockFollowRepoA = _MockFollowRepository();
      mockFollowRepoB = _MockFollowRepository();
      mockInviteCubit = _MockInviteStatusCubit();

      for (final repo in [mockNotificationRepoA, mockNotificationRepoB]) {
        when(
          () => repo.watchSnapshot(filter: any(named: 'filter')),
        ).thenAnswer((_) => const Stream<NotificationPage>.empty());
        when(
          () => repo.refreshFeed(any()),
        ).thenAnswer((_) async => NotificationPage.empty);
        when(repo.markAllAsRead).thenAnswer((_) async {});
      }

      for (final repo in [mockFollowRepoA, mockFollowRepoB]) {
        when(() => repo.isFollowing(any())).thenReturn(false);
      }

      when(() => mockInviteCubit.state).thenReturn(
        const InviteStatusState(
          status: InviteStatusLoadingStatus.loaded,
          inviteStatus: InviteStatus(
            canInvite: false,
            remaining: 0,
            total: 0,
            codes: [],
          ),
        ),
      );
      when(mockInviteCubit.load).thenAnswer((_) async {});
    });

    testWidgets(
      'recreates NotificationFeedBloc when notificationRepositoryProvider '
      'rebuilds with a new repository instance',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            badgeRepositoryProvider.overrideWithValue(_stubBadgeRepository()),
            notificationRepositoryProvider.overrideWith((ref) {
              final v = ref.watch(_notificationRepoSwap);
              return v == 0 ? mockNotificationRepoA : mockNotificationRepoB;
            }),
            followRepositoryProvider.overrideWithValue(mockFollowRepoA),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          _TestApp(
            container: container,
            home: BlocProvider<InviteStatusCubit>.value(
              value: mockInviteCubit,
              child: const Scaffold(body: InboxNotificationsPage()),
            ),
          ),
        );
        await tester.pump();

        final blocBefore = _notificationFeedBlocFor(tester);
        expect(blocBefore.isClosed, isFalse);

        container.read(_notificationRepoSwap.notifier).state = 1;
        await tester.pump();

        final blocAfter = _notificationFeedBlocFor(tester);
        expect(
          blocAfter,
          isNot(same(blocBefore)),
          reason:
              'The inbox page captures notificationRepository in '
              'BlocProvider.create, so a repo identity flip must recreate the '
              'feed bloc.',
        );
      },
    );

    testWidgets(
      'recreates NotificationFeedBloc when followRepositoryProvider rebuilds '
      'with a new repository instance',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            badgeRepositoryProvider.overrideWithValue(_stubBadgeRepository()),
            notificationRepositoryProvider.overrideWithValue(
              mockNotificationRepoA,
            ),
            followRepositoryProvider.overrideWith((ref) {
              final v = ref.watch(_followRepoSwap);
              return v == 0 ? mockFollowRepoA : mockFollowRepoB;
            }),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          _TestApp(
            container: container,
            home: BlocProvider<InviteStatusCubit>.value(
              value: mockInviteCubit,
              child: const Scaffold(body: InboxNotificationsPage()),
            ),
          ),
        );
        await tester.pump();

        final blocBefore = _notificationFeedBlocFor(tester);
        expect(blocBefore.isClosed, isFalse);

        container.read(_followRepoSwap.notifier).state = 1;
        await tester.pump();

        final blocAfter = _notificationFeedBlocFor(tester);
        expect(
          blocAfter,
          isNot(same(blocBefore)),
          reason:
              'The inbox page also captures followRepository in '
              'BlocProvider.create, so its record key must recreate the bloc '
              'when that dependency identity changes.',
        );
      },
    );

    testWidgets(
      'preserves the same NotificationFeedBloc when neither dependency '
      'identity changes across rebuilds',
      (tester) async {
        final rebuildKey = GlobalKey<_RebuildHostState>();
        final container = ProviderContainer(
          overrides: [
            badgeRepositoryProvider.overrideWithValue(_stubBadgeRepository()),
            notificationRepositoryProvider.overrideWithValue(
              mockNotificationRepoA,
            ),
            followRepositoryProvider.overrideWithValue(mockFollowRepoA),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          _TestApp(
            container: container,
            home: RebuildHost(
              key: rebuildKey,
              child: BlocProvider<InviteStatusCubit>.value(
                value: mockInviteCubit,
                child: const Scaffold(body: InboxNotificationsPage()),
              ),
            ),
          ),
        );
        await tester.pump();

        final blocBefore = _notificationFeedBlocFor(tester);

        rebuildKey.currentState!.rebuild();
        await tester.pump();

        final blocAfter = _notificationFeedBlocFor(tester);
        expect(blocAfter, same(blocBefore));
      },
    );

    testWidgets(
      'drops prior bloc state when notificationRepositoryProvider rebuilds '
      '(intentional)',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            badgeRepositoryProvider.overrideWithValue(_stubBadgeRepository()),
            notificationRepositoryProvider.overrideWith((ref) {
              final v = ref.watch(_notificationRepoSwap);
              return v == 0 ? mockNotificationRepoA : mockNotificationRepoB;
            }),
            followRepositoryProvider.overrideWithValue(mockFollowRepoA),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          _TestApp(
            container: container,
            home: BlocProvider<InviteStatusCubit>.value(
              value: mockInviteCubit,
              child: const Scaffold(body: InboxNotificationsPage()),
            ),
          ),
        );
        await tester.pump();

        final blocBefore = _notificationFeedBlocFor(tester);
        blocBefore.emit(
          const NotificationFeedState(
            status: NotificationFeedStatus.loaded,
            unreadCount: 4,
            hasMore: false,
            isLoadingMore: true,
            refreshError: true,
          ),
        );
        await tester.pump();
        expect(blocBefore.state.unreadCount, equals(4));
        expect(blocBefore.state.hasMore, isFalse);
        expect(blocBefore.state.refreshError, isTrue);

        container.read(_notificationRepoSwap.notifier).state = 1;
        await tester.pump();

        final blocAfter = _notificationFeedBlocFor(tester);
        expect(blocAfter, isNot(same(blocBefore)));
        expect(blocAfter.state.unreadCount, equals(0));
        expect(blocAfter.state.hasMore, isTrue);
        expect(blocAfter.state.refreshError, isFalse);
      },
    );

    testWidgets(
      'rebinds the badges cubit when badgeRepositoryProvider rebuilds with a '
      'new repository instance',
      (tester) async {
        final l10n = lookupAppLocalizations(const Locale('en'));
        final badgeRepoA = _stubBadgeRepository();
        final badgeRepoB = _stubBadgeRepository(pendingAwards: 2);

        final container = ProviderContainer(
          overrides: [
            badgeRepositoryProvider.overrideWith((ref) {
              final v = ref.watch(_badgeRepoSwap);
              return v == 0 ? badgeRepoA : badgeRepoB;
            }),
            notificationRepositoryProvider.overrideWithValue(
              mockNotificationRepoA,
            ),
            followRepositoryProvider.overrideWithValue(mockFollowRepoA),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          _TestApp(
            container: container,
            home: BlocProvider<InviteStatusCubit>.value(
              value: mockInviteCubit,
              child: const Scaffold(body: InboxNotificationsPage()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(l10n.notificationsTabBadges(0)), findsOneWidget);

        final feedBefore = _notificationFeedBlocFor(tester);

        container.read(_badgeRepoSwap.notifier).state = 1;
        await tester.pumpAndSettle();

        // The new repository's awards drive the label...
        expect(find.text(l10n.notificationsTabBadges(2)), findsOneWidget);
        // ...and the notification feeds are untouched by a badge-only swap.
        expect(_notificationFeedBlocFor(tester), same(feedBefore));
      },
    );
  });
}

class _TestApp extends StatelessWidget {
  const _TestApp({required this.container, required this.home});

  final ProviderContainer container;
  final Widget home;

  @override
  Widget build(BuildContext context) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    );
  }
}

class RebuildHost extends StatefulWidget {
  const RebuildHost({required this.child, super.key});

  final Widget child;

  @override
  State<RebuildHost> createState() => _RebuildHostState();
}

class _RebuildHostState extends State<RebuildHost> {
  void rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) => widget.child;
}

NotificationFeedBloc _notificationFeedBlocFor(WidgetTester tester) {
  final context = tester.element(find.byType(NotificationsView).first);
  return BlocProvider.of<NotificationFeedBloc>(context);
}
