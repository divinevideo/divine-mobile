// ABOUTME: Reproduction for #8266 — contact-list selection must follow NIP-01
// ABOUTME: (newest created_at wins), not "whichever list has more p tags".

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
      (_) async => (
        events: <Event>[],
        timedOut: false,
        noRelays: false,
        anyRelayAnswered: false,
        unsettledRelays: const <String>[],
      ),
    );
  }
}

class _MockEvent extends Mock implements Event {}

class _FakeContactList extends Fake implements ContactList {}

void main() {
  group('FollowRepository contact-list freshness (#8266)', () {
    late _MockNostrClient mockNostrClient;
    late FakeCacheDao cacheDao;
    late List<Event> Function(int kind) getCachedEventsByKind;

    const owner =
        'a1b2c3d4e5f6789012345678901234567890abcdef1234567890123456789012';
    const alice =
        'b2c3d4e5f6789012345678901234567890abcdef1234567890123456789012a1';
    const bob =
        'c3d4e5f6789012345678901234567890abcdef1234567890123456789012ab12';
    const carol =
        'd4e5f6789012345678901234567890abcdef1234567890123456789012ab12c3';
    const dave =
        'e5f6789012345678901234567890abcdef1234567890123456789012ab12c3d4';

    Event contactList({
      required int createdAt,
      required List<String> follows,
      String content = '',
    }) => Event(
      owner,
      EventKind.contactList,
      follows.map((p) => ['p', p]).toList(),
      content,
      createdAt: createdAt,
    );

    FollowRepository buildRepository() => FollowRepository(
      nostrClient: mockNostrClient,
      isCacheInitialized: () => true,
      getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
      cacheUserEvent: (_) {},
      indexerRelayUrls: const [],
    );

    setUpAll(() {
      registerFallbackValue(_MockEvent());
      registerFallbackValue(<Filter>[]);
      registerFallbackValue(_FakeContactList());
    });

    setUp(() async {
      cacheDao = FakeCacheDao();
      await CacheSync.init(dao: cacheDao);

      mockNostrClient = _MockNostrClient();
      getCachedEventsByKind = (_) => [];

      when(() => mockNostrClient.hasKeys).thenReturn(true);
      when(() => mockNostrClient.publicKey).thenReturn(owner);
      when(
        () => mockNostrClient.subscribe(
          any(),
          subscriptionId: any(named: 'subscriptionId'),
          tempRelays: any(named: 'tempRelays'),
          targetRelays: any(named: 'targetRelays'),
          relayTypes: any(named: 'relayTypes'),
          sendAfterAuth: any(named: 'sendAfterAuth'),
          onEose: any(named: 'onEose'),
        ),
      ).thenAnswer((_) => const Stream<Event>.empty());
      when(() => mockNostrClient.unsubscribe(any())).thenAnswer((_) async {});
    });

    // The live shape. `cacheUserEvent` is called only from
    // `_broadcastContactList`, so PersonalEventCache holds the last event THIS
    // device published. A cross-device unfollow arrives over the subscription,
    // which writes LocalStorage only. So on the next cold start PEC is
    // older-and-longer while LocalStorage is newer-and-shorter, and a p-tag
    // count comparison picks the wrong one.
    test('a newer, shorter LocalStorage list survives an older, longer '
        'PersonalEventCache event', () async {
      SharedPreferences.setMockInitialValues({
        'following_list_$owner':
            '{"v":2,"created_at":2000,'
            '"id":"${'b' * 64}","pubkeys":["$alice"]}',
      });
      // Older event this device published before the unfollow happened.
      getCachedEventsByKind = (kind) => kind == EventKind.contactList
          ? [
              contactList(createdAt: 1000, follows: [alice, bob, carol]),
            ]
          : [];

      final repository = buildRepository();
      addTearDown(repository.dispose);
      await repository.initialize();

      expect(
        repository.followingPubkeys,
        [alice],
        reason: 'created_at 2000 beats created_at 1000, regardless of length',
      );
    });

    // The direction the issue describes.
    test('a newer, shorter PersonalEventCache event replaces an older '
        'LocalStorage list', () async {
      SharedPreferences.setMockInitialValues({
        'following_list_$owner':
            '{"v":2,"created_at":1000,'
            '"id":"${'a' * 64}","pubkeys":["$alice","$bob","$carol"]}',
      });
      getCachedEventsByKind = (kind) => kind == EventKind.contactList
          ? [
              contactList(createdAt: 2000, follows: [alice]),
            ]
          : [];

      final repository = buildRepository();
      addTearDown(repository.dispose);
      await repository.initialize();

      expect(
        repository.followingPubkeys,
        [alice],
        reason: 'a legitimate unfollow must not be undone by p-tag counting',
      );
    });

    // Chardot: "include backward-compatible migration from the existing bare
    // pubkey-array cache". A v1 record carries no timestamp, so its freshness
    // is unknowable and any timestamped event outranks it.
    test('a legacy bare-array cache loses to any timestamped event', () async {
      SharedPreferences.setMockInitialValues({
        'following_list_$owner': '["$alice","$bob","$carol"]',
      });
      getCachedEventsByKind = (kind) => kind == EventKind.contactList
          ? [
              contactList(createdAt: 1000, follows: [alice]),
            ]
          : [];

      final repository = buildRepository();
      addTearDown(repository.dispose);
      await repository.initialize();

      expect(repository.followingPubkeys, [alice]);
    });

    // The chain that turns a wrong hydration base into published data loss.
    // #8267 made `_broadcastContactList` read the authoritative kind 3 before
    // publishing, but that read only fills `_currentUserContactListEvent`
    // (which supplies `content`). The `p` tags still come from
    // `_publishableFollows()` -> `_followingPubkeys`. So a stale-but-longer
    // hydration is what gets republished, and the unfollows come back.
    test('a follow does not republish follows the newest known event '
        'had already dropped', () async {
      SharedPreferences.setMockInitialValues({
        'following_list_$owner':
            '{"v":2,"created_at":2000,'
            '"id":"${'b' * 64}","pubkeys":["$alice"]}',
      });
      getCachedEventsByKind = (kind) => kind == EventKind.contactList
          ? [
              contactList(createdAt: 1000, follows: [alice, bob, carol]),
            ]
          : [];

      // The relay holds the authoritative post-unfollow list.
      final authoritative = contactList(createdAt: 2000, follows: [alice]);
      when(
        () => mockNostrClient.queryEventsDetailed(
          any(),
          requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
          timeout: any(named: 'timeout'),
        ),
      ).thenAnswer(
        (_) async => (
          events: <Event>[authoritative],
          timedOut: false,
          noRelays: false,
          anyRelayAnswered: false,
          unsettledRelays: const <String>[],
        ),
      );

      final published = <List<String>>[];
      when(
        () => mockNostrClient.sendContactList(
          any(),
          any(),
          tempRelays: any(named: 'tempRelays'),
          targetRelays: any(named: 'targetRelays'),
        ),
      ).thenAnswer((invocation) async {
        final list = invocation.positionalArguments[0] as ContactList;
        published.add(
          list
              .toJson()
              .where((t) => t.isNotEmpty && t[0] == 'p')
              .map((t) => t[1])
              .toList(),
        );
        return contactList(
          createdAt: 3000,
          follows: published.last,
        );
      });

      final repository = buildRepository();
      addTearDown(repository.dispose);
      await repository.initialize();
      await repository.follow(dave);

      expect(published, hasLength(1));
      expect(
        published.single..sort(),
        [alice, dave]..sort(),
        reason:
            'bob and carol were unfollowed on another device; a follow '
            'must not resurrect them on the relay',
      );
    });

    test('an unreadable cached record is ignored rather than parsed', () async {
      SharedPreferences.setMockInitialValues({
        'following_list_$owner': '42',
      });

      final repository = buildRepository();
      addTearDown(repository.dispose);
      await repository.initialize();

      expect(repository.followingPubkeys, isEmpty);
    });

    // The other device made the same follow first. Re-applying the pending
    // change must not double-add it, and must not claim in the log that it
    // changed anything.
    test('a pending follow the newest event already has is a no-op', () async {
      SharedPreferences.setMockInitialValues({
        'following_list_$owner':
            '{"v":2,"created_at":1000,'
            '"id":"${'a' * 64}","pubkeys":["$alice"]}',
      });

      when(
        () => mockNostrClient.queryEventsDetailed(
          any(),
          requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
          timeout: any(named: 'timeout'),
        ),
      ).thenAnswer(
        (_) async => (
          events: <Event>[
            contactList(createdAt: 2000, follows: [alice, bob]),
          ],
          timedOut: false,
          noRelays: false,
          anyRelayAnswered: false,
          unsettledRelays: const <String>[],
        ),
      );

      final published = <List<String>>[];
      when(
        () => mockNostrClient.sendContactList(
          any(),
          any(),
          tempRelays: any(named: 'tempRelays'),
          targetRelays: any(named: 'targetRelays'),
        ),
      ).thenAnswer((invocation) async {
        final list = invocation.positionalArguments[0] as ContactList;
        published.add(
          list
              .toJson()
              .where((t) => t.isNotEmpty && t[0] == 'p')
              .map((t) => t[1])
              .toList(),
        );
        return contactList(createdAt: 3000, follows: published.last);
      });

      final repository = buildRepository();
      addTearDown(repository.dispose);
      await repository.initialize();
      await repository.follow(bob);

      expect(repository.followingPubkeys, [alice, bob]);
      expect(published.single, [alice, bob]);
    });

    // The pre-publish read has two jobs: decide whose list wins, and supply
    // `content` for the event about to be published. They are different
    // questions. When LocalStorage already names the very event the relay
    // returns, the list is not adopted — correctly, it is the same list — but
    // `content` must still come from that event, or the publish sends `''`
    // over the user's NIP-02 relay list. That is #8265's data loss, through a
    // different door.
    test('content survives when the read returns the event LocalStorage '
        'already names', () async {
      final existing = Event(
        owner,
        EventKind.contactList,
        [
          ['p', alice],
        ],
        '{"wss://relay.example":{"read":true,"write":true}}',
        createdAt: 2000,
      );

      SharedPreferences.setMockInitialValues({
        'following_list_$owner':
            '{"v":2,"created_at":2000,'
            '"id":"${existing.id}","pubkeys":["$alice"]}',
      });

      when(
        () => mockNostrClient.queryEventsDetailed(
          any(),
          requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
          timeout: any(named: 'timeout'),
        ),
      ).thenAnswer(
        (_) async => (
          events: <Event>[existing],
          timedOut: false,
          noRelays: false,
          anyRelayAnswered: false,
          unsettledRelays: const <String>[],
        ),
      );

      final publishedContent = <String>[];
      when(
        () => mockNostrClient.sendContactList(
          any(),
          any(),
          tempRelays: any(named: 'tempRelays'),
          targetRelays: any(named: 'targetRelays'),
        ),
      ).thenAnswer((invocation) async {
        publishedContent.add(invocation.positionalArguments[1] as String);
        return contactList(createdAt: 3000, follows: [alice, bob]);
      });

      final repository = buildRepository();
      addTearDown(repository.dispose);
      await repository.initialize();
      await repository.follow(bob);

      expect(
        publishedContent.single,
        existing.content,
        reason:
            'NIP-02 kind 3 content carries the relay list; publishing an '
            'empty string over it is the #8265 wipe',
      );
    });

    // An offline follow persists the list *plus* the provenance of the base it
    // was applied to, so the record names an event whose tags it no longer
    // matches. That is deliberate: the record means "at least as fresh as this
    // event", which is what ordering needs. The queued follow must therefore
    // survive a restart rather than being overwritten by the very event it was
    // built on.
    test(
      'an offline follow survives a restart against its own base event',
      () async {
        final base = contactList(createdAt: 2000, follows: [alice]);
        SharedPreferences.setMockInitialValues({
          'following_list_$owner':
              '{"v":2,"created_at":2000,'
              '"id":"${base.id}","pubkeys":["$alice","$bob"]}',
        });
        getCachedEventsByKind = (kind) =>
            kind == EventKind.contactList ? [base] : [];

        final repository = buildRepository();
        addTearDown(repository.dispose);
        await repository.initialize();

        expect(
          repository.followingPubkeys,
          [alice, bob],
          reason:
              'the cached event ties on created_at and id, so it must not '
              'displace the list that already carries the queued follow',
        );
      },
    );
  });
}
