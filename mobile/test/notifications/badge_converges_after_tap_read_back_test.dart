// ABOUTME: Pins the "tap notification -> return -> badge converges"
// ABOUTME: contract. Tap dispatches markAsRead through the bloc; the shared
// ABOUTME: snapshot stream propagates the new unread count to both the feed
// ABOUTME: bloc and the badge cubit so the bottom-nav badge stays in lock
// ABOUTME: step with the per-row read state.

import 'dart:async';

import 'package:analytics/analytics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:notification_repository/notification_repository.dart';
import 'package:openvine/blocs/notifications/badge/notification_badge_cubit.dart';
import 'package:openvine/features/consumption_analytics/consumption_analytics_tracker.dart';
import 'package:openvine/notifications/bloc/notification_feed_bloc.dart';
import 'package:openvine/services/app_badge_service.dart';
import 'package:rxdart/rxdart.dart' hide NotificationKind;

class _MockFollowRepository extends Mock implements FollowRepository {}

class _NoopAppBadgeClearer implements AppBadgeClearer {
  const _NoopAppBadgeClearer();

  @override
  Future<void> clear() async {}
}

/// Controllable fake that mirrors the real repository's shared-source-of-truth
/// behaviour: a single [BehaviorSubject] feeds both [watchSnapshot] and
/// [watchUnreadCount], and [markAsRead] re-emits with the targeted items
/// flagged read so derived streams converge.
class _FakeNotificationRepository extends Fake
    implements NotificationRepository {
  _FakeNotificationRepository(NotificationPage initial)
    : _snapshot = BehaviorSubject<NotificationPage>.seeded(initial);

  final BehaviorSubject<NotificationPage> _snapshot;

  /// Notification ID batches passed to [markAsRead].
  final List<List<String>> markedReadCalls = [];

  @override
  Stream<NotificationPage> watchSnapshot({NotificationKind? filter}) =>
      _snapshot.stream;

  @override
  Stream<int> watchUnreadCount() => _snapshot.stream
      .map((page) => page.items.where((n) => !n.isRead).length)
      .distinct();

  @override
  Future<void> markAsRead(List<String> ids) async {
    markedReadCalls.add(List<String>.from(ids));
    final current = _snapshot.value;
    final updated = current.items.map<NotificationItem>((item) {
      if (!ids.contains(item.id)) return item;
      return switch (item) {
        VideoNotification(:final isRead) when isRead => item,
        VideoNotification() => item.copyWith(isRead: true),
        ActorNotification(:final isRead) when isRead => item,
        ActorNotification() => item.copyWith(isRead: true),
      };
    }).toList();
    _snapshot.add(current.copyWith(items: updated));
  }

  @override
  void resetPaginationDepth({NotificationKind? filter}) {}

  @override
  Future<NotificationPage> refreshFeed(NotificationKind? filter) async =>
      _snapshot.value;

  @override
  Future<NotificationPage?> loadNextPageFor(NotificationKind? filter) async =>
      _snapshot.value;

  @override
  Future<void> close() => _snapshot.close();
}

const _alicePubkey =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _bobPubkey =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

VideoNotification _unreadLike(String id) {
  return VideoNotification(
    id: id,
    type: NotificationKind.like,
    videoEventId: 'video_$id',
    actors: const [ActorInfo(pubkey: _alicePubkey, displayName: 'Alice')],
    totalCount: 1,
    timestamp: DateTime(2026),
  );
}

ActorNotification _unreadFollow(String id) {
  return ActorNotification(
    id: id,
    type: NotificationKind.follow,
    actor: const ActorInfo(pubkey: _bobPubkey, displayName: 'Bob'),
    timestamp: DateTime(2026),
  );
}

void main() {
  group('badge converges after tap -> read -> back', () {
    late _FakeNotificationRepository repository;
    late _MockFollowRepository followRepository;

    setUp(() {
      repository = _FakeNotificationRepository(
        NotificationPage(
          items: [_unreadLike('n1'), _unreadLike('n2'), _unreadFollow('n3')],
          unreadCount: 3,
        ),
      );
      followRepository = _MockFollowRepository();
      when(() => followRepository.isFollowing(any())).thenReturn(false);
    });

    tearDown(() async {
      await repository.close();
    });

    test(
      'tapping one item drops both bloc-projected unread and badge by 1',
      () async {
        final bloc = NotificationFeedBloc(
          notificationRepository: repository,
          followRepository: followRepository,
          appBadgeClearer: const _NoopAppBadgeClearer(),
          consumptionAnalytics: ConsumptionAnalyticsTracker(
            analytics: const NoOpAnalyticsEventSink(),
          ),
        );
        addTearDown(bloc.close);
        final badge = NotificationBadgeCubit(repository: repository);
        addTearDown(badge.close);
        final badgeCounts = <int>[];
        final subscription = badge.stream.listen(badgeCounts.add);
        addTearDown(subscription.cancel);

        // Wait for the initial snapshot to flow into both consumers.
        await pumpEventQueue();
        expect(badge.state, equals(3));
        expect(bloc.state.notifications, hasLength(3));
        expect(
          bloc.state.notifications.where((n) => !n.isRead).length,
          equals(3),
        );

        bloc.add(const NotificationFeedItemTapped('n1'));
        await pumpEventQueue();

        expect(
          repository.markedReadCalls,
          equals([
            ['n1'],
          ]),
        );
        expect(badge.state, equals(2));
        expect(
          bloc.state.notifications.where((n) => !n.isRead).length,
          equals(2),
        );
        expect(badgeCounts, [3, 2]);
        // Row identity is preserved — same id, just flagged read.
        expect(
          bloc.state.notifications.singleWhere((n) => n.id == 'n1').isRead,
          isTrue,
        );
      },
    );

    test(
      'tapping the already-read row leaves badge unchanged (no double-decrement)',
      () async {
        await repository.markAsRead(['n2']);

        final bloc = NotificationFeedBloc(
          notificationRepository: repository,
          followRepository: followRepository,
          appBadgeClearer: const _NoopAppBadgeClearer(),
          consumptionAnalytics: ConsumptionAnalyticsTracker(
            analytics: const NoOpAnalyticsEventSink(),
          ),
        );
        addTearDown(bloc.close);
        final badge = NotificationBadgeCubit(repository: repository);
        addTearDown(badge.close);
        final badgeCounts = <int>[];
        final subscription = badge.stream.listen(badgeCounts.add);
        addTearDown(subscription.cancel);

        await pumpEventQueue();
        expect(badge.state, equals(2));

        bloc.add(const NotificationFeedItemTapped('n2'));
        await pumpEventQueue();

        expect(badge.state, equals(2));
        expect(badgeCounts, [2]);
        expect(
          repository.markedReadCalls,
          equals([
            ['n2'],
            ['n2'],
          ]),
        );
      },
    );

    test('tapping every unread item converges badge to 0', () async {
      final bloc = NotificationFeedBloc(
        notificationRepository: repository,
        followRepository: followRepository,
        appBadgeClearer: const _NoopAppBadgeClearer(),
        consumptionAnalytics: ConsumptionAnalyticsTracker(
          analytics: const NoOpAnalyticsEventSink(),
        ),
      );
      addTearDown(bloc.close);
      final badge = NotificationBadgeCubit(repository: repository);
      addTearDown(badge.close);
      final badgeCounts = <int>[];
      final subscription = badge.stream.listen(badgeCounts.add);
      addTearDown(subscription.cancel);

      await pumpEventQueue();
      expect(badge.state, equals(3));

      bloc.add(const NotificationFeedItemTapped('n1'));
      await pumpEventQueue();
      expect(badgeCounts, [3, 2]);
      bloc.add(const NotificationFeedItemTapped('n2'));
      await pumpEventQueue();
      expect(badgeCounts, [3, 2, 1]);
      bloc.add(const NotificationFeedItemTapped('n3'));
      await pumpEventQueue();

      expect(badge.state, equals(0));
      expect(badgeCounts, [3, 2, 1, 0]);
      expect(
        repository.markedReadCalls,
        equals([
          ['n1'],
          ['n2'],
          ['n3'],
        ]),
      );
      expect(bloc.state.notifications.every((n) => n.isRead), isTrue);
    });
  });
}
