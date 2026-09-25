import 'dart:async';

import 'package:cache_sync/cache_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../cache_sync/test/fake_cache_dao.dart';

class _MockNostrClient extends Mock implements NostrClient {
  _MockNostrClient() {
    registerFallbackValue(Duration.zero);
    when(
      () => queryEventsDetailed(
        any(),
        requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
        timeout: any(named: 'timeout'),
      ),
    ).thenAnswer(
      (_) async => (events: <Event>[], timedOut: false, noRelays: false),
    );
  }
}

class _MockEvent extends Mock implements Event {
  _MockEvent() {
    when(
      () => createdAt,
    ).thenReturn(DateTime.now().millisecondsSinceEpoch ~/ 1000);
    when(() => id).thenReturn('e' * 64);
    when(() => content).thenReturn('');
  }
}

class _FakeContactList extends Fake implements ContactList {}

void main() {
  const ownerPubkey =
      'a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1';
  const creatorPubkey =
      'b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2';

  late _MockNostrClient nostrClient;
  late FollowRepository repository;
  late FakeCacheDao cacheDao;
  late StreamController<Event> contactListEvents;
  var subscribeCalls = 0;

  setUpAll(() {
    registerFallbackValue(<Filter>[]);
    registerFallbackValue(_FakeContactList());
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'following_list_$ownerPubkey': '["$creatorPubkey"]',
    });
    cacheDao = FakeCacheDao();
    await CacheSync.init(dao: cacheDao);
    nostrClient = _MockNostrClient();
    contactListEvents = StreamController<Event>.broadcast(sync: true);
    subscribeCalls = 0;

    when(() => nostrClient.hasKeys).thenReturn(true);
    when(() => nostrClient.publicKey).thenReturn(ownerPubkey);
    when(() => nostrClient.unsubscribe(any())).thenAnswer((_) async {});
    when(
      () => nostrClient.subscribe(
        any(),
        subscriptionId: any(named: 'subscriptionId'),
        tempRelays: any(named: 'tempRelays'),
        targetRelays: any(named: 'targetRelays'),
        relayTypes: any(named: 'relayTypes'),
        sendAfterAuth: any(named: 'sendAfterAuth'),
        onEose: any(named: 'onEose'),
      ),
    ).thenAnswer((_) {
      subscribeCalls++;
      return subscribeCalls == 1
          ? const Stream<Event>.empty()
          : contactListEvents.stream;
    });

    repository = FollowRepository(
      nostrClient: nostrClient,
      isCacheInitialized: () => false,
      getCachedEventsByKind: (_) => const <Event>[],
      cacheUserEvent: (_) {},
      indexerRelayUrls: const [],
      queryContactList:
          ({
            required eventStream,
            required pubkey,
            fallbackTimeoutSeconds = 10,
          }) async => null,
    );
  });

  tearDown(() async {
    await repository.dispose();
    await contactListEvents.close();
  });

  group('unfollow', () {
    test('emits only after a local unfollow succeeds', () async {
      final published = _MockEvent();
      when(
        () => nostrClient.sendContactList(
          any(),
          any(),
          tempRelays: any(named: 'tempRelays'),
          targetRelays: any(named: 'targetRelays'),
        ),
      ).thenAnswer((_) async => published);

      final removals = <String>[];
      final subscription = repository.confirmedUnfollowStream.listen(
        removals.add,
      );
      addTearDown(subscription.cancel);

      await repository.initialize();
      await repository.unfollow(creatorPubkey);

      expect(removals, [creatorPubkey]);
    });

    test('does not emit when an optimistic unfollow rolls back', () async {
      when(
        () => nostrClient.sendContactList(
          any(),
          any(),
          tempRelays: any(named: 'tempRelays'),
          targetRelays: any(named: 'targetRelays'),
        ),
      ).thenAnswer((_) async => null);

      await repository.initialize();
      final removals = <String>[];
      final subscription = repository.confirmedUnfollowStream.listen(
        removals.add,
      );
      addTearDown(subscription.cancel);

      await expectLater(repository.unfollow(creatorPubkey), throwsException);

      expect(repository.isFollowing(creatorPubkey), isTrue);
      expect(removals, isEmpty);
    });
  });

  group('isFollowingConfirmedByRelay', () {
    test('is false when the relay returned no contact list', () async {
      await repository.initialize();

      expect(repository.isFollowing(creatorPubkey), isTrue);
      expect(repository.isFollowingConfirmedByRelay, isFalse);
    });

    test('is true once a relay contact list is processed', () async {
      await repository.initialize();
      contactListEvents.add(
        Event(
          ownerPubkey,
          EventKind.contactList,
          const [
            ['p', creatorPubkey],
          ],
          '',
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 1,
        ),
      );

      expect(repository.isFollowingConfirmedByRelay, isTrue);
    });
  });

  group('contact list adoption', () {
    test(
      'emits when a newer contact list removes a followed creator',
      () async {
        final removal = Completer<String>();
        final subscription = repository.confirmedUnfollowStream.listen((
          pubkey,
        ) {
          if (!removal.isCompleted) removal.complete(pubkey);
        });
        addTearDown(subscription.cancel);

        await repository.initialize();
        contactListEvents.add(
          Event(
            ownerPubkey,
            EventKind.contactList,
            const <List<String>>[],
            '',
            createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 1,
          ),
        );

        expect(await removal.future, creatorPubkey);
      },
    );
  });
}
