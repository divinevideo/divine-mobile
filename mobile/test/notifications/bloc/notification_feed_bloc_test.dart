// ABOUTME: Tests for NotificationFeedBloc — the bloc is now a thin
// ABOUTME: projection of NotificationRepository.watchSnapshot(); event
// ABOUTME: handlers forward to the repository. Per-row state / unread
// ABOUTME: rollback semantics are tested at the repository layer.

// Explicit constructor calls and defaults keep each event fixture readable.
// ignore_for_file: prefer_const_constructors, avoid_redundant_argument_values

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:notification_repository/notification_repository.dart';
import 'package:openvine/notifications/bloc/notification_feed_bloc.dart';
import 'package:openvine/notifications/bloc/reportable_sites.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:openvine/services/app_badge_service.dart';

class _MockNotificationRepository extends Mock
    implements NotificationRepository {}

class _MockFollowRepository extends Mock implements FollowRepository {}

class _MockAppBadgeClearer extends Mock implements AppBadgeClearer {}

const _alicePubkey =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _bobPubkey =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _videoEventId =
    '1111111111111111111111111111111111111111111111111111111111111111';

ActorInfo _actor({String pubkey = _alicePubkey, String displayName = 'Alice'}) {
  return ActorInfo(pubkey: pubkey, displayName: displayName);
}

VideoNotification _videoNotif({
  String id = 'v1',
  NotificationKind type = NotificationKind.like,
  List<ActorInfo>? actors,
  int totalCount = 1,
  String videoEventId = _videoEventId,
  bool isRead = false,
  DateTime? timestamp,
}) {
  return VideoNotification(
    id: id,
    type: type,
    videoEventId: videoEventId,
    actors: actors ?? [_actor()],
    totalCount: totalCount,
    timestamp: timestamp ?? DateTime(2026),
    isRead: isRead,
  );
}

ActorNotification _actorNotif({
  String id = 'a1',
  NotificationKind type = NotificationKind.follow,
  String pubkey = _alicePubkey,
  String displayName = 'Alice',
  bool isFollowingBack = false,
  bool isRead = false,
}) {
  return ActorNotification(
    id: id,
    type: type,
    actor: _actor(pubkey: pubkey, displayName: displayName),
    timestamp: DateTime(2026),
    isFollowingBack: isFollowingBack,
    isRead: isRead,
  );
}

void main() {
  group(NotificationFeedBloc, () {
    late _MockNotificationRepository mockNotificationRepo;
    late _MockFollowRepository mockFollowRepo;
    late _MockAppBadgeClearer mockAppBadgeClearer;
    late StreamController<NotificationPage> snapshotController;

    setUp(() {
      mockNotificationRepo = _MockNotificationRepository();
      mockFollowRepo = _MockFollowRepository();
      mockAppBadgeClearer = _MockAppBadgeClearer();
      snapshotController = StreamController<NotificationPage>.broadcast();

      when(() => mockFollowRepo.isFollowing(any())).thenReturn(false);
      when(() => mockAppBadgeClearer.clear()).thenAnswer((_) async {});
      when(
        () => mockNotificationRepo.watchSnapshot(filter: any(named: 'filter')),
      ).thenAnswer((_) => snapshotController.stream);
      when(
        () => mockNotificationRepo.refreshFeed(any()),
      ).thenAnswer((_) async => NotificationPage.empty);
      when(
        () => mockNotificationRepo.loadNextPageFor(any()),
      ).thenAnswer((_) async => NotificationPage.empty);
      when(
        () => mockNotificationRepo.markAsRead(any()),
      ).thenAnswer((_) async {});
      when(() => mockNotificationRepo.markAllAsRead()).thenAnswer((_) async {});
      when(
        () => mockNotificationRepo.resetPaginationDepth(
          filter: any(named: 'filter'),
        ),
      ).thenReturn(null);
    });

    tearDown(() async {
      await snapshotController.close();
    });

    NotificationFeedBloc createBloc({AppBadgeClearer? appBadgeClearer}) =>
        NotificationFeedBloc(
          notificationRepository: mockNotificationRepo,
          followRepository: mockFollowRepo,
          appBadgeClearer: appBadgeClearer ?? mockAppBadgeClearer,
        );

    NotificationFeedBloc createFollowBloc({AppBadgeClearer? appBadgeClearer}) =>
        NotificationFeedBloc(
          notificationRepository: mockNotificationRepo,
          followRepository: mockFollowRepo,
          appBadgeClearer: appBadgeClearer ?? mockAppBadgeClearer,
          filter: NotificationKind.follow,
        );

    test('resets pagination depth when the feed closes', () async {
      final bloc = createBloc();

      await bloc.close();

      verify(
        () => mockNotificationRepo.resetPaginationDepth(filter: null),
      ).called(1);
    });

    test('subscribes to the filtered snapshot for tab feeds', () async {
      final bloc = createFollowBloc();

      await bloc.close();

      verify(
        () =>
            mockNotificationRepo.watchSnapshot(filter: NotificationKind.follow),
      ).called(1);
      verify(
        () => mockNotificationRepo.resetPaginationDepth(
          filter: NotificationKind.follow,
        ),
      ).called(1);
    });

    group('snapshot projection', () {
      blocTest<NotificationFeedBloc, NotificationFeedState>(
        'projects watchSnapshot emissions into state',
        build: createBloc,
        act: (_) async {
          snapshotController.add(
            NotificationPage(
              items: [_videoNotif()],
              unreadCount: 1,
              hasMore: true,
            ),
          );
          await Future<void>.delayed(Duration.zero);
        },
        expect: () => [
          NotificationFeedState(
            notifications: [_videoNotif()],
            unreadCount: 1,
            hasMore: true,
          ),
        ],
      );

      blocTest<NotificationFeedBloc, NotificationFeedState>(
        'overrides isFollowingBack from FollowRepository on each emission',
        setUp: () {
          when(() => mockFollowRepo.isFollowing(_alicePubkey)).thenReturn(true);
        },
        build: createBloc,
        act: (_) async {
          snapshotController.add(
            NotificationPage(items: [_actorNotif()], unreadCount: 1),
          );
          await Future<void>.delayed(Duration.zero);
        },
        expect: () => [
          NotificationFeedState(
            notifications: [_actorNotif(isFollowingBack: true)],
            unreadCount: 1,
            hasMore: false,
          ),
        ],
      );

      blocTest<NotificationFeedBloc, NotificationFeedState>(
        'leaves non-follow ActorNotifications untouched',
        setUp: () {
          when(() => mockFollowRepo.isFollowing(any())).thenReturn(true);
        },
        build: createBloc,
        act: (_) async {
          snapshotController.add(
            NotificationPage(
              items: [_actorNotif(type: NotificationKind.mention)],
              unreadCount: 1,
            ),
          );
          await Future<void>.delayed(Duration.zero);
        },
        expect: () => [
          NotificationFeedState(
            notifications: [_actorNotif(type: NotificationKind.mention)],
            unreadCount: 1,
            hasMore: false,
          ),
        ],
      );
    });

    group('NotificationFeedStarted', () {
      blocTest<NotificationFeedBloc, NotificationFeedState>(
        'emits refreshing then loaded; refreshes then marks seen on open '
        '(#4708)',
        build: createBloc,
        act: (bloc) => bloc.add(NotificationFeedStarted()),
        expect: () => [
          NotificationFeedState(isRefreshing: true),
          // `loaded` lands with the data, before the mark-all write, so the
          // cold-start spinner is not held open across the POST.
          NotificationFeedState(
            isRefreshing: true,
            status: NotificationFeedStatus.loaded,
          ),
          NotificationFeedState(status: NotificationFeedStatus.loaded),
        ],
        verify: (_) {
          // Seen-on-open sends the server mark-all write AFTER the refresh so
          // the badge clears and thereafter shows "new since last seen".
          verifyInOrder([
            () => mockNotificationRepo.refreshFeed(null),
            () => mockNotificationRepo.markAllAsRead(),
          ]);
        },
      );

      test('drops the cold-start spinner before the mark-all write '
          'settles', () async {
        final markCompleter = Completer<void>();
        when(
          () => mockNotificationRepo.markAllAsRead(),
        ).thenAnswer((_) => markCompleter.future);

        final bloc = createBloc();
        addTearDown(bloc.close);

        bloc.add(NotificationFeedStarted());
        await Future<void>.delayed(Duration.zero);
        // Empty inbox: the repository emits an empty page from inside
        // `refreshFeed`, so `notifications` stays empty. This is the case
        // that would fall through to the full-screen spinner branch if
        // `loaded` were held across the mark-all write.
        snapshotController.add(NotificationPage.empty);
        await Future<void>.delayed(Duration.zero);

        expect(bloc.state.notifications, isEmpty);
        expect(
          bloc.state.status,
          NotificationFeedStatus.loaded,
          reason:
              'empty state renders instead of a spinner held open for the '
              'duration of the mark-all POST',
        );
        expect(bloc.state.isRefreshing, isTrue);

        markCompleter.complete();
        await Future<void>.delayed(Duration.zero);

        expect(bloc.state.isRefreshing, isFalse);
      });

      test(
        'drops refresh events while the initial mark-all is pending',
        () async {
          final markCompleter = Completer<void>();
          when(
            () => mockNotificationRepo.markAllAsRead(),
          ).thenAnswer((_) => markCompleter.future);

          final bloc = createBloc();
          addTearDown(bloc.close);

          bloc.add(NotificationFeedStarted());
          await Future<void>.delayed(Duration.zero);

          bloc.add(NotificationFeedRefreshed());
          await Future<void>.delayed(Duration.zero);

          verify(() => mockNotificationRepo.refreshFeed(null)).called(1);
          verify(() => mockNotificationRepo.markAllAsRead()).called(1);
          expect(bloc.state.isRefreshing, isTrue);

          markCompleter.complete();
          await Future<void>.delayed(Duration.zero);

          when(
            () => mockNotificationRepo.markAllAsRead(),
          ).thenAnswer((_) async {});
          bloc.add(NotificationFeedRefreshed());
          await Future<void>.delayed(Duration.zero);

          verify(() => mockNotificationRepo.refreshFeed(null)).called(1);
          verify(() => mockNotificationRepo.markAllAsRead()).called(1);
          expect(bloc.state.isRefreshing, isFalse);
        },
      );

      blocTest<NotificationFeedBloc, NotificationFeedState>(
        'clears the platform app badge after successful unfiltered open',
        build: () => createBloc(appBadgeClearer: mockAppBadgeClearer),
        act: (bloc) => bloc.add(NotificationFeedStarted()),
        wait: const Duration(milliseconds: 1),
        expect: () => [
          NotificationFeedState(isRefreshing: true),
          NotificationFeedState(
            isRefreshing: true,
            status: NotificationFeedStatus.loaded,
          ),
          NotificationFeedState(status: NotificationFeedStatus.loaded),
        ],
        verify: (_) {
          verifyInOrder([
            () => mockNotificationRepo.refreshFeed(null),
            () => mockNotificationRepo.markAllAsRead(),
            () => mockAppBadgeClearer.clear(),
          ]);
        },
      );

      blocTest<NotificationFeedBloc, NotificationFeedState>(
        'does not clear the platform app badge for filtered opens',
        build: () => createFollowBloc(appBadgeClearer: mockAppBadgeClearer),
        act: (bloc) => bloc.add(NotificationFeedStarted()),
        wait: const Duration(milliseconds: 1),
        expect: () => [
          NotificationFeedState(isRefreshing: true),
          NotificationFeedState(status: NotificationFeedStatus.loaded),
        ],
        verify: (_) {
          verify(
            () => mockNotificationRepo.refreshFeed(NotificationKind.follow),
          ).called(1);
          verifyNever(() => mockNotificationRepo.markAllAsRead());
          verifyNever(() => mockAppBadgeClearer.clear());
        },
      );

      blocTest<NotificationFeedBloc, NotificationFeedState>(
        'surfaces platform app badge clear failures without affecting feed state',
        setUp: () {
          when(
            () => mockAppBadgeClearer.clear(),
          ).thenThrow(Exception('badge clear failed'));
        },
        build: () => createBloc(appBadgeClearer: mockAppBadgeClearer),
        act: (bloc) => bloc.add(NotificationFeedStarted()),
        wait: const Duration(milliseconds: 1),
        expect: () => [
          NotificationFeedState(isRefreshing: true),
          NotificationFeedState(
            isRefreshing: true,
            status: NotificationFeedStatus.loaded,
          ),
          NotificationFeedState(status: NotificationFeedStatus.loaded),
        ],
        errors: () => [allOf(isA<Exception>(), isNot(isA<ReportableError>()))],
        verify: (_) {
          verify(() => mockAppBadgeClearer.clear()).called(1);
        },
      );

      blocTest<NotificationFeedBloc, NotificationFeedState>(
        'wraps unexpected Error from the app badge clear as Reportable '
        'without blackening the feed',
        setUp: () {
          when(
            () => mockAppBadgeClearer.clear(),
          ).thenThrow(StateError('badge invariant'));
        },
        build: () => createBloc(appBadgeClearer: mockAppBadgeClearer),
        act: (bloc) => bloc.add(NotificationFeedStarted()),
        wait: const Duration(milliseconds: 1),
        expect: () => [
          NotificationFeedState(isRefreshing: true),
          NotificationFeedState(
            isRefreshing: true,
            status: NotificationFeedStatus.loaded,
          ),
          NotificationFeedState(status: NotificationFeedStatus.loaded),
        ],
        errors: () => [
          isA<Reportable<Object>>()
              .having(
                (r) => r.context,
                'context',
                NotificationFeedBlocReportableSites.clearAppBadge,
              )
              .having((r) => r.unwrap(), 'unwrap', isA<StateError>()),
        ],
        verify: (_) {
          verify(() => mockAppBadgeClearer.clear()).called(1);
        },
      );

      blocTest<NotificationFeedBloc, NotificationFeedState>(
        'stays loaded when the seen-on-open mark-all fails (does not blacken '
        'the feed)',
        setUp: () {
          when(
            () => mockNotificationRepo.markAllAsRead(),
          ).thenThrow(Exception('mark-all boom'));
        },
        build: createBloc,
        act: (bloc) => bloc.add(NotificationFeedStarted()),
        expect: () => [
          NotificationFeedState(isRefreshing: true),
          NotificationFeedState(
            isRefreshing: true,
            status: NotificationFeedStatus.loaded,
          ),
          NotificationFeedState(status: NotificationFeedStatus.loaded),
        ],
        errors: () => [isA<Exception>()],
        verify: (_) {
          verify(() => mockNotificationRepo.refreshFeed(null)).called(1);
          verify(() => mockNotificationRepo.markAllAsRead()).called(1);
          // The seen watermark did not advance, so the OS badge must stay put
          // — clearing it here would hide notifications the server still
          // considers unread.
          verifyNever(() => mockAppBadgeClearer.clear());
        },
      );

      blocTest<NotificationFeedBloc, NotificationFeedState>(
        'wraps unexpected Error from seen-on-open mark-all as Reportable '
        'without blackening the feed',
        setUp: () {
          when(
            () => mockNotificationRepo.markAllAsRead(),
          ).thenThrow(StateError('invariant'));
        },
        build: createBloc,
        act: (bloc) => bloc.add(NotificationFeedStarted()),
        expect: () => [
          NotificationFeedState(isRefreshing: true),
          NotificationFeedState(
            isRefreshing: true,
            status: NotificationFeedStatus.loaded,
          ),
          NotificationFeedState(status: NotificationFeedStatus.loaded),
        ],
        errors: () => [
          isA<Reportable<Object>>()
              .having(
                (r) => r.context,
                'context',
                NotificationFeedBlocReportableSites.markSeenOnOpen,
              )
              .having((r) => r.unwrap(), 'unwrap', isA<StateError>()),
        ],
        verify: (_) {
          verify(() => mockNotificationRepo.refreshFeed(null)).called(1);
          verify(() => mockNotificationRepo.markAllAsRead()).called(1);
          // The seen watermark did not advance, so the OS badge must stay put
          // — clearing it here would hide notifications the server still
          // considers unread.
          verifyNever(() => mockAppBadgeClearer.clear());
        },
      );

      blocTest<NotificationFeedBloc, NotificationFeedState>(
        'emits failure with refreshError when refresh throws and cache is empty',
        setUp: () {
          when(
            () => mockNotificationRepo.refreshFeed(null),
          ).thenThrow(Exception('boom'));
        },
        build: createBloc,
        act: (bloc) => bloc.add(NotificationFeedStarted()),
        expect: () => [
          NotificationFeedState(isRefreshing: true),
          NotificationFeedState(
            status: NotificationFeedStatus.failure,
            refreshError: true,
          ),
        ],
        errors: () => [isA<Exception>()],
      );

      blocTest<NotificationFeedBloc, NotificationFeedState>(
        'stays loaded with refreshError when refresh throws but cache has '
        'items',
        setUp: () {
          when(
            () => mockNotificationRepo.refreshFeed(null),
          ).thenThrow(Exception('boom'));
        },
        build: createBloc,
        seed: () => NotificationFeedState(
          isRefreshing: true,
          notifications: [
            ActorNotification(
              id: 'cached_1',
              type: NotificationKind.follow,
              actor: const ActorInfo(
                pubkey: 'pubkey_cached',
                displayName: 'Loading…',
              ),
              timestamp: DateTime(2026),
            ),
          ],
        ),
        act: (bloc) => bloc.add(NotificationFeedStarted()),
        expect: () => [
          // The bloc's first emit (isRefreshing: true) deduplicates against
          // the seed (already refreshing), so only the post-catch `loaded`
          // state is surfaced. The cached row is preserved and `refreshError`
          // flips so the view renders the inline banner instead of the full
          // failure screen.
          NotificationFeedState(
            status: NotificationFeedStatus.loaded,
            notifications: [
              ActorNotification(
                id: 'cached_1',
                type: NotificationKind.follow,
                actor: const ActorInfo(
                  pubkey: 'pubkey_cached',
                  displayName: 'Loading…',
                ),
                timestamp: DateTime(2026),
              ),
            ],
            refreshError: true,
          ),
        ],
        errors: () => [isA<Exception>()],
      );

      blocTest<NotificationFeedBloc, NotificationFeedState>(
        'wraps unexpected Error from refresh as Reportable and emits '
        'failure with refreshError',
        setUp: () {
          when(
            () => mockNotificationRepo.refreshFeed(null),
          ).thenThrow(StateError('invariant'));
        },
        build: createBloc,
        act: (bloc) => bloc.add(NotificationFeedStarted()),
        expect: () => [
          NotificationFeedState(isRefreshing: true),
          NotificationFeedState(
            status: NotificationFeedStatus.failure,
            refreshError: true,
          ),
        ],
        errors: () => [
          isA<Reportable<Object>>().having(
            (r) => r.unwrap(),
            'unwrap',
            isA<StateError>(),
          ),
        ],
      );
    });

    group('NotificationFeedLoadMore', () {
      blocTest<NotificationFeedBloc, NotificationFeedState>(
        'continues past an empty page from the bloc',
        build: createBloc,
        seed: () => NotificationFeedState(
          status: NotificationFeedStatus.loaded,
          hasMore: false,
        ),
        act: (_) async {
          snapshotController.add(
            NotificationPage(items: const [], unreadCount: 0, hasMore: true),
          );
          await Future<void>.delayed(Duration.zero);
        },
        expect: () => [
          NotificationFeedState(
            status: NotificationFeedStatus.loaded,
            hasMore: true,
          ),
          NotificationFeedState(
            status: NotificationFeedStatus.loaded,
            hasMore: true,
            isLoadingMore: true,
          ),
          NotificationFeedState(
            status: NotificationFeedStatus.loaded,
            hasMore: true,
          ),
        ],
        verify: (_) {
          verify(() => mockNotificationRepo.loadNextPageFor(null)).called(1);
        },
      );

      test('continues past an empty page when the snapshot lands during '
          '_onStarted', () async {
        final emptyWithMore = NotificationPage(
          items: const [],
          unreadCount: 0,
          hasMore: true,
        );
        // Mirrors the repository: `_getNotificationsResult` emits the
        // snapshot before `refreshFeed` completes, so `_onSnapshotChanged`
        // runs while `_onStarted` still holds `isRefreshing: true` and
        // `status: initial`. Nothing emits afterwards, so unless the
        // continuation is re-checked at the tail of `_onStarted` the tab
        // settles empty with `hasMore: true` and never paginates.
        when(
          () => mockNotificationRepo.refreshFeed(NotificationKind.follow),
        ).thenAnswer((_) async {
          snapshotController.add(emptyWithMore);
          await Future<void>.value();
          await Future<void>.value();
          return emptyWithMore;
        });

        final bloc = createFollowBloc()..add(NotificationFeedStarted());
        addTearDown(bloc.close);
        await Future<void>.delayed(const Duration(milliseconds: 10));

        verify(
          () => mockNotificationRepo.loadNextPageFor(NotificationKind.follow),
        ).called(1);
      });

      test('runs the documented number of empty-page continuations', () async {
        final emptyWithMore = NotificationPage(
          items: const [],
          unreadCount: 0,
          hasMore: true,
        );
        when(
          () => mockNotificationRepo.refreshFeed(NotificationKind.follow),
        ).thenAnswer((_) async {
          snapshotController.add(emptyWithMore);
          await Future<void>.value();
          await Future<void>.value();
          return emptyWithMore;
        });
        // Each continuation's page also filters down to nothing, and its
        // snapshot lands while `isLoadingMore` is still true — so the next
        // continuation is deferred and only fires if `_onLoadMore` flushes
        // it. Without that flush the cap is effectively 1.
        when(
          () => mockNotificationRepo.loadNextPageFor(NotificationKind.follow),
        ).thenAnswer((_) async {
          snapshotController.add(emptyWithMore);
          await Future<void>.value();
          await Future<void>.value();
          return emptyWithMore;
        });

        final bloc = createFollowBloc()..add(NotificationFeedStarted());
        addTearDown(bloc.close);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        verify(
          () => mockNotificationRepo.loadNextPageFor(NotificationKind.follow),
        ).called(3);
      });

      blocTest<NotificationFeedBloc, NotificationFeedState>(
        'no-op when hasMore is false',
        build: createBloc,
        seed: () => NotificationFeedState(
          status: NotificationFeedStatus.loaded,
          hasMore: false,
        ),
        act: (bloc) => bloc.add(NotificationFeedLoadMore()),
        expect: () => <NotificationFeedState>[],
        verify: (_) {
          verifyNever(() => mockNotificationRepo.loadNextPageFor(null));
        },
      );

      blocTest<NotificationFeedBloc, NotificationFeedState>(
        'flips isLoadingMore on/off and forwards to loadNextPage',
        build: createBloc,
        seed: () => NotificationFeedState(
          status: NotificationFeedStatus.loaded,
          hasMore: true,
        ),
        act: (bloc) => bloc.add(NotificationFeedLoadMore()),
        expect: () => [
          NotificationFeedState(
            status: NotificationFeedStatus.loaded,
            hasMore: true,
            isLoadingMore: true,
          ),
          NotificationFeedState(
            status: NotificationFeedStatus.loaded,
            hasMore: true,
          ),
        ],
        verify: (_) {
          verify(() => mockNotificationRepo.loadNextPageFor(null)).called(1);
        },
      );

      blocTest<NotificationFeedBloc, NotificationFeedState>(
        'recovers isLoadingMore on loadNextPage failure and still retries '
        'when the user scrolls again',
        setUp: () {
          when(
            () => mockNotificationRepo.loadNextPageFor(null),
          ).thenThrow(Exception('boom'));
        },
        build: createBloc,
        seed: () => NotificationFeedState(
          status: NotificationFeedStatus.loaded,
          hasMore: true,
        ),
        act: (bloc) async {
          bloc.add(NotificationFeedLoadMore());
          await Future<void>.delayed(Duration.zero);
          bloc.add(NotificationFeedLoadMore());
        },
        expect: () => [
          NotificationFeedState(
            status: NotificationFeedStatus.loaded,
            hasMore: true,
            isLoadingMore: true,
          ),
          NotificationFeedState(
            status: NotificationFeedStatus.loaded,
            hasMore: true,
          ),
          NotificationFeedState(
            status: NotificationFeedStatus.loaded,
            hasMore: true,
            isLoadingMore: true,
          ),
          NotificationFeedState(
            status: NotificationFeedStatus.loaded,
            hasMore: true,
          ),
        ],
        errors: () => [isA<Exception>(), isA<Exception>()],
        // A load-more failure emits no snapshot and shows no error
        // affordance, so latching it would strand the user with a list
        // that silently refuses to paginate for the rest of the session.
        verify: (_) {
          verify(() => mockNotificationRepo.loadNextPageFor(null)).called(2);
        },
      );

      blocTest<NotificationFeedBloc, NotificationFeedState>(
        'wraps unexpected Error from loadNextPage as Reportable and '
        'recovers isLoadingMore',
        setUp: () {
          when(
            () => mockNotificationRepo.loadNextPageFor(null),
          ).thenThrow(StateError('invariant'));
        },
        build: createBloc,
        seed: () => NotificationFeedState(
          status: NotificationFeedStatus.loaded,
          hasMore: true,
        ),
        act: (bloc) => bloc.add(NotificationFeedLoadMore()),
        expect: () => [
          NotificationFeedState(
            status: NotificationFeedStatus.loaded,
            hasMore: true,
            isLoadingMore: true,
          ),
          NotificationFeedState(
            status: NotificationFeedStatus.loaded,
            hasMore: true,
          ),
        ],
        errors: () => [
          isA<Reportable<Object>>().having(
            (r) => r.unwrap(),
            'unwrap',
            isA<StateError>(),
          ),
        ],
      );
    });

    group('NotificationFeedBecameVisible', () {
      blocTest<NotificationFeedBloc, NotificationFeedState>(
        'marks seen without refreshing when the kept-alive inbox becomes '
        'visible again',
        build: () => createBloc(appBadgeClearer: mockAppBadgeClearer),
        act: (bloc) => bloc.add(NotificationFeedBecameVisible()),
        wait: const Duration(milliseconds: 1),
        expect: () => <NotificationFeedState>[],
        verify: (_) {
          verifyNever(() => mockNotificationRepo.refreshFeed(any()));
          verify(() => mockNotificationRepo.markAllAsRead()).called(1);
          verify(() => mockAppBadgeClearer.clear()).called(1);
        },
      );

      blocTest<NotificationFeedBloc, NotificationFeedState>(
        'does not mark seen for filtered tab visibility',
        build: createFollowBloc,
        act: (bloc) => bloc.add(NotificationFeedBecameVisible()),
        wait: const Duration(milliseconds: 1),
        expect: () => <NotificationFeedState>[],
        verify: (_) {
          verifyNever(() => mockNotificationRepo.refreshFeed(any()));
          verifyNever(() => mockNotificationRepo.markAllAsRead());
          verifyNever(() => mockAppBadgeClearer.clear());
        },
      );

      test(
        'drops overlapping visible events while mark-all is pending',
        () async {
          final markCompleter = Completer<void>();
          when(
            () => mockNotificationRepo.markAllAsRead(),
          ).thenAnswer((_) => markCompleter.future);

          final bloc = createBloc(appBadgeClearer: mockAppBadgeClearer);
          addTearDown(bloc.close);

          bloc.add(NotificationFeedBecameVisible());
          await Future<void>.delayed(Duration.zero);
          bloc.add(NotificationFeedBecameVisible());
          await Future<void>.delayed(Duration.zero);

          verify(() => mockNotificationRepo.markAllAsRead()).called(1);
          verifyNever(() => mockAppBadgeClearer.clear());

          markCompleter.complete();
          await Future<void>.delayed(Duration.zero);

          verify(() => mockAppBadgeClearer.clear()).called(1);
        },
      );

      test(
        'drops the visible mark while the initial open mark is in flight',
        () async {
          final markCompleter = Completer<void>();
          when(
            () => mockNotificationRepo.markAllAsRead(),
          ).thenAnswer((_) => markCompleter.future);

          final bloc = createBloc(appBadgeClearer: mockAppBadgeClearer);
          addTearDown(bloc.close);

          // _onStarted marks seen after refreshFeed; hold that write in
          // flight so a became-visible mark would overlap it.
          bloc.add(NotificationFeedStarted());
          await Future<void>.delayed(Duration.zero);

          // Different event type from Started, so droppable() cannot drop
          // it. Only _markSeenInFlight prevents the second mark-all POST.
          bloc.add(NotificationFeedBecameVisible());
          await Future<void>.delayed(Duration.zero);

          verify(() => mockNotificationRepo.markAllAsRead()).called(1);
          verifyNever(() => mockAppBadgeClearer.clear());

          markCompleter.complete();
          await Future<void>.delayed(Duration.zero);

          verify(() => mockAppBadgeClearer.clear()).called(1);
        },
      );
    });

    group('NotificationFeedRefreshed', () {
      blocTest<NotificationFeedBloc, NotificationFeedState>(
        'emits refreshing then loaded',
        build: createBloc,
        seed: () =>
            NotificationFeedState(status: NotificationFeedStatus.failure),
        act: (bloc) => bloc.add(NotificationFeedRefreshed()),
        expect: () => [
          NotificationFeedState(
            status: NotificationFeedStatus.failure,
            isRefreshing: true,
          ),
          // A retry dispatched from `_FailureBody` leaves `failure` as soon as
          // the refresh succeeds, rather than holding the error screen up
          // across the mark-all write.
          NotificationFeedState(
            status: NotificationFeedStatus.loaded,
            isRefreshing: true,
          ),
          NotificationFeedState(status: NotificationFeedStatus.loaded),
        ],
        verify: (_) {
          verifyInOrder([
            () => mockNotificationRepo.refreshFeed(null),
            () => mockNotificationRepo.markAllAsRead(),
          ]);
        },
      );

      test('keeps refresh visible while mark seen is pending', () async {
        final markCompleter = Completer<void>();
        when(
          () => mockNotificationRepo.markAllAsRead(),
        ).thenAnswer((_) => markCompleter.future);

        final bloc = createBloc();
        addTearDown(bloc.close);
        final states = <NotificationFeedState>[];
        final subscription = bloc.stream.listen(states.add);
        addTearDown(subscription.cancel);

        bloc.add(NotificationFeedRefreshed());
        await Future<void>.delayed(Duration.zero);

        // Refresh resolved, mark-all still pending: content is renderable
        // (`loaded` dismisses the cold-start spinner) but the revalidation bar
        // is still up, because this is the droppable handler's drop window.
        expect(states, [
          NotificationFeedState(isRefreshing: true),
          NotificationFeedState(
            status: NotificationFeedStatus.loaded,
            isRefreshing: true,
          ),
        ]);

        bloc.add(NotificationFeedRefreshed());
        await Future<void>.delayed(Duration.zero);
        verify(() => mockNotificationRepo.refreshFeed(null)).called(1);

        markCompleter.complete();
        await Future<void>.delayed(Duration.zero);

        expect(states, [
          NotificationFeedState(isRefreshing: true),
          NotificationFeedState(
            status: NotificationFeedStatus.loaded,
            isRefreshing: true,
          ),
          NotificationFeedState(status: NotificationFeedStatus.loaded),
        ]);
        verify(() => mockNotificationRepo.markAllAsRead()).called(1);
      });

      blocTest<NotificationFeedBloc, NotificationFeedState>(
        'does not mark seen after filtered refresh',
        build: createFollowBloc,
        act: (bloc) => bloc.add(NotificationFeedRefreshed()),
        expect: () => [
          NotificationFeedState(isRefreshing: true),
          NotificationFeedState(status: NotificationFeedStatus.loaded),
        ],
        verify: (_) {
          verify(
            () => mockNotificationRepo.refreshFeed(NotificationKind.follow),
          ).called(1);
          verifyNever(() => mockNotificationRepo.markAllAsRead());
        },
      );

      blocTest<NotificationFeedBloc, NotificationFeedState>(
        'emits failure with refreshError when refresh throws and cache is '
        'empty',
        setUp: () {
          when(
            () => mockNotificationRepo.refreshFeed(null),
          ).thenThrow(Exception('boom'));
        },
        build: createBloc,
        act: (bloc) => bloc.add(NotificationFeedRefreshed()),
        expect: () => [
          NotificationFeedState(isRefreshing: true),
          NotificationFeedState(
            status: NotificationFeedStatus.failure,
            refreshError: true,
          ),
        ],
        errors: () => [isA<Exception>()],
        verify: (_) {
          verify(() => mockNotificationRepo.refreshFeed(null)).called(1);
          verifyNever(() => mockNotificationRepo.markAllAsRead());
        },
      );

      blocTest<NotificationFeedBloc, NotificationFeedState>(
        'stays loaded with refreshError when refresh throws but cache has '
        'items',
        setUp: () {
          when(
            () => mockNotificationRepo.refreshFeed(null),
          ).thenThrow(Exception('boom'));
        },
        build: createBloc,
        seed: () => NotificationFeedState(
          status: NotificationFeedStatus.loaded,
          notifications: [
            ActorNotification(
              id: 'cached_1',
              type: NotificationKind.follow,
              actor: const ActorInfo(
                pubkey: 'pubkey_cached',
                displayName: 'Loading…',
              ),
              timestamp: DateTime(2026),
            ),
          ],
        ),
        act: (bloc) => bloc.add(NotificationFeedRefreshed()),
        expect: () => [
          // Cached row stays on screen while the refresh runs (the thin
          // revalidation bar shows in the view), then `refreshError` flips
          // so the inline banner replaces the bar on the terminal emit.
          NotificationFeedState(
            status: NotificationFeedStatus.loaded,
            notifications: [
              ActorNotification(
                id: 'cached_1',
                type: NotificationKind.follow,
                actor: const ActorInfo(
                  pubkey: 'pubkey_cached',
                  displayName: 'Loading…',
                ),
                timestamp: DateTime(2026),
              ),
            ],
            isRefreshing: true,
          ),
          NotificationFeedState(
            status: NotificationFeedStatus.loaded,
            notifications: [
              ActorNotification(
                id: 'cached_1',
                type: NotificationKind.follow,
                actor: const ActorInfo(
                  pubkey: 'pubkey_cached',
                  displayName: 'Loading…',
                ),
                timestamp: DateTime(2026),
              ),
            ],
            refreshError: true,
          ),
        ],
        errors: () => [isA<Exception>()],
      );

      blocTest<NotificationFeedBloc, NotificationFeedState>(
        'wraps unexpected Error from refresh as Reportable and emits '
        'failure with refreshError',
        setUp: () {
          when(
            () => mockNotificationRepo.refreshFeed(null),
          ).thenThrow(StateError('invariant'));
        },
        build: createBloc,
        act: (bloc) => bloc.add(NotificationFeedRefreshed()),
        expect: () => [
          NotificationFeedState(isRefreshing: true),
          NotificationFeedState(
            status: NotificationFeedStatus.failure,
            refreshError: true,
          ),
        ],
        errors: () => [
          isA<Reportable<Object>>().having(
            (r) => r.unwrap(),
            'unwrap',
            isA<StateError>(),
          ),
        ],
      );
    });

    group('NotificationFeedItemTapped', () {
      blocTest<NotificationFeedBloc, NotificationFeedState>(
        'forwards to repository.markAsRead',
        build: createBloc,
        act: (bloc) => bloc.add(NotificationFeedItemTapped('v1')),
        verify: (_) {
          verify(() => mockNotificationRepo.markAsRead(['v1'])).called(1);
        },
      );

      blocTest<NotificationFeedBloc, NotificationFeedState>(
        'forwards repository errors via addError',
        setUp: () {
          when(
            () => mockNotificationRepo.markAsRead(any()),
          ).thenThrow(Exception('boom'));
        },
        build: createBloc,
        act: (bloc) => bloc.add(NotificationFeedItemTapped('v1')),
        errors: () => [isA<Exception>()],
      );

      blocTest<NotificationFeedBloc, NotificationFeedState>(
        'wraps unexpected Error from markAsRead as Reportable',
        setUp: () {
          when(
            () => mockNotificationRepo.markAsRead(any()),
          ).thenThrow(StateError('invariant'));
        },
        build: createBloc,
        act: (bloc) => bloc.add(NotificationFeedItemTapped('v1')),
        errors: () => [
          isA<Reportable<Object>>().having(
            (r) => r.unwrap(),
            'unwrap',
            isA<StateError>(),
          ),
        ],
      );
    });

    group('NotificationFeedFollowBack', () {
      blocTest<NotificationFeedBloc, NotificationFeedState>(
        'follows the user and re-derives follow state on existing items',
        setUp: () {
          when(
            () => mockFollowRepo.follow(_bobPubkey),
          ).thenAnswer((_) async {});
          when(() => mockFollowRepo.isFollowing(_bobPubkey)).thenReturn(true);
        },
        build: createBloc,
        seed: () => NotificationFeedState(
          notifications: [
            _actorNotif(id: 'f1', pubkey: _bobPubkey, displayName: 'Bob'),
          ],
        ),
        act: (bloc) => bloc.add(NotificationFeedFollowBack(_bobPubkey)),
        expect: () => [
          NotificationFeedState(
            notifications: [
              _actorNotif(
                id: 'f1',
                pubkey: _bobPubkey,
                displayName: 'Bob',
                isFollowingBack: true,
              ),
            ],
          ),
        ],
      );

      blocTest<NotificationFeedBloc, NotificationFeedState>(
        'forwards follow errors via addError',
        setUp: () {
          when(
            () => mockFollowRepo.follow(_bobPubkey),
          ).thenThrow(Exception('boom'));
        },
        build: createBloc,
        act: (bloc) => bloc.add(NotificationFeedFollowBack(_bobPubkey)),
        errors: () => [isA<Exception>()],
      );

      blocTest<NotificationFeedBloc, NotificationFeedState>(
        'forwards an invalid-pubkey ArgumentError without wrapping it',
        setUp: () {
          when(() => mockFollowRepo.follow(_bobPubkey)).thenThrow(
            ArgumentError.value(_bobPubkey, 'pubkey', 'Invalid key'),
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(NotificationFeedFollowBack(_bobPubkey)),
        errors: () => [
          isA<ArgumentError>().having(
            (e) => e.invalidValue,
            'invalidValue',
            _bobPubkey,
          ),
        ],
      );

      blocTest<NotificationFeedBloc, NotificationFeedState>(
        'wraps a RangeError from follow as Reportable',
        setUp: () {
          when(
            () => mockFollowRepo.follow(_bobPubkey),
          ).thenThrow(RangeError.range(5, 0, 1));
        },
        build: createBloc,
        act: (bloc) => bloc.add(NotificationFeedFollowBack(_bobPubkey)),
        errors: () => [
          isA<Reportable<Object>>().having(
            (r) => r.unwrap(),
            'unwrap',
            isA<RangeError>(),
          ),
        ],
      );

      blocTest<NotificationFeedBloc, NotificationFeedState>(
        'wraps an ArgumentError carrying our own pubkey as Reportable',
        setUp: () {
          when(() => mockFollowRepo.follow(_bobPubkey)).thenThrow(
            ArgumentError.value(_alicePubkey, 'pubkey', 'Invalid key'),
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(NotificationFeedFollowBack(_bobPubkey)),
        errors: () => [
          isA<Reportable<Object>>().having(
            (r) => r.unwrap(),
            'unwrap',
            isA<ArgumentError>(),
          ),
        ],
      );

      blocTest<NotificationFeedBloc, NotificationFeedState>(
        'wraps unexpected Error from follow as Reportable',
        setUp: () {
          when(
            () => mockFollowRepo.follow(_bobPubkey),
          ).thenThrow(StateError('invariant'));
        },
        build: createBloc,
        act: (bloc) => bloc.add(NotificationFeedFollowBack(_bobPubkey)),
        errors: () => [
          isA<Reportable<Object>>().having(
            (r) => r.unwrap(),
            'unwrap',
            isA<StateError>(),
          ),
        ],
      );
    });
  });
}
