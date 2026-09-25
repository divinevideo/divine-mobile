import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/services/notify_subscriptions_unfollow_cleanup.dart';
import 'package:people_lists_repository/people_lists_repository.dart';

class _MockFollowRepository extends Mock implements FollowRepository {}

class _MockNotifySubscriptionsRepository extends Mock
    implements NotifySubscriptionsRepository {}

void main() {
  const ownerPubkey =
      'a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1';
  const followedCreator =
      'b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2';
  const removedCreator =
      'c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3';

  late _MockFollowRepository followRepository;
  late _MockNotifySubscriptionsRepository notifySubscriptionsRepository;
  late StreamController<String> confirmedUnfollows;

  setUp(() {
    followRepository = _MockFollowRepository();
    notifySubscriptionsRepository = _MockNotifySubscriptionsRepository();
    confirmedUnfollows = StreamController<String>.broadcast(sync: true);

    when(
      () => followRepository.confirmedUnfollowStream,
    ).thenAnswer((_) => confirmedUnfollows.stream);
    when(() => followRepository.initialized).thenAnswer((_) async {});
    when(
      () => followRepository.followingPubkeys,
    ).thenReturn(const [followedCreator]);
    when(
      () => notifySubscriptionsRepository.readSubscriptions(
        ownerPubkey: ownerPubkey,
      ),
    ).thenAnswer((_) async => const {followedCreator});
    when(
      () => notifySubscriptionsRepository.unsubscribe(
        ownerPubkey: any(named: 'ownerPubkey'),
        creatorPubkey: any(named: 'creatorPubkey'),
      ),
    ).thenAnswer(
      (_) async => const PeopleListPublishResult.submitted(eventId: 'event'),
    );
  });

  tearDown(() async {
    await confirmedUnfollows.close();
  });

  NotifySubscriptionsUnfollowCleanup createCleanup() =>
      NotifySubscriptionsUnfollowCleanup(
        followRepository: followRepository,
        notifySubscriptionsRepository: notifySubscriptionsRepository,
        ownerPubkey: ownerPubkey,
      );

  group('start', () {
    test('removes stale subscriptions once the follow list is ready', () async {
      when(
        () => notifySubscriptionsRepository.readSubscriptions(
          ownerPubkey: ownerPubkey,
        ),
      ).thenAnswer((_) async => const {followedCreator, removedCreator});

      final cleanup = createCleanup();
      addTearDown(cleanup.dispose);

      await cleanup.start();

      verify(
        () => notifySubscriptionsRepository.unsubscribe(
          ownerPubkey: ownerPubkey,
          creatorPubkey: removedCreator,
        ),
      ).called(1);
      verifyNever(
        () => notifySubscriptionsRepository.unsubscribe(
          ownerPubkey: ownerPubkey,
          creatorPubkey: followedCreator,
        ),
      );
    });
  });

  group('confirmed unfollows', () {
    test('removes subscriptions from any route', () async {
      final removed = Completer<void>();
      when(
        () => notifySubscriptionsRepository.unsubscribe(
          ownerPubkey: ownerPubkey,
          creatorPubkey: removedCreator,
        ),
      ).thenAnswer((_) async {
        if (!removed.isCompleted) removed.complete();
        return const PeopleListPublishResult.submitted(eventId: 'event');
      });

      final cleanup = createCleanup();
      addTearDown(cleanup.dispose);
      await cleanup.start();

      confirmedUnfollows.add(removedCreator);
      await removed.future;

      verify(
        () => notifySubscriptionsRepository.unsubscribe(
          ownerPubkey: ownerPubkey,
          creatorPubkey: removedCreator,
        ),
      ).called(1);
    });
  });
}
