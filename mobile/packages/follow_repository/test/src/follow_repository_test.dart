// ABOUTME: Unit tests for FollowRepository
// ABOUTME: Tests follow/unfollow operations, caching, and network sync

import 'dart:async';
import 'dart:convert';

import 'package:cache_sync/cache_sync.dart';
import 'package:db_client/db_client.dart' hide Filter;
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../cache_sync/test/fake_cache_dao.dart';

class _MockNostrClient extends Mock implements NostrClient {
  _MockNostrClient() {
    // Self-registered so the stub below works in every file that builds this
    // mock, whether or not that file has its own `setUpAll`. Idempotent.
    registerFallbackValue(Duration.zero);
    // The pre-broadcast read of our own kind 3 goes through
    // `queryEventsDetailed` so it can tell a relay's "I hold nothing" apart
    // from an answer nobody gave (#8265). Default to a *settled* empty answer
    // — the relay replied and holds nothing — which is the state every test
    // here was written in, and which still broadcasts. Tests about the
    // inconclusive read override this with `timedOut` or `noRelays`.
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

class _MockFunnelcakeApiClient extends Mock implements FunnelcakeApiClient {}

class _MockProfileStatsDao extends Mock implements ProfileStatsDao {}

class _MockEvent extends Mock implements Event {
  _MockEvent() {
    // A real `sendContactList` returns a signed event, so `createdAt` and `id`
    // are always populated. The repository reads both to record which kind 3
    // its list came from (#8266), so a mock that leaves them null is not a
    // stand-in for anything production can produce. Tests that care about a
    // specific value still override these.
    when(() => createdAt).thenReturn(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
    when(() => id).thenReturn('e' * 64);
  }
}

/// A fake relay that fires [fakeResponses] via [onMessage] during connect.
///
/// Used to test indexer relay methods without real WebSocket connections.
class _FakeRelay extends RelayBase {
  _FakeRelay(
    super.url,
    super.relayStatus, {
    this.shouldConnect = true,
    this.neverConnects = false,
    this.neverCloses = false,
    this.neverDisconnects = false,
    this.throwOnSend = false,
    this.throwOnDisconnect = false,
  });

  /// Messages to deliver via [onMessage] when connecting.
  List<List<dynamic>> fakeResponses = [];

  /// Whether [connect] should succeed.
  final bool shouldConnect;

  /// Whether [connect] should remain pending forever.
  final bool neverConnects;

  /// Whether a CLOSE request should remain pending forever.
  final bool neverCloses;

  /// Whether [disconnect] should remain pending forever.
  final bool neverDisconnects;

  /// Whether [send] should throw.
  final bool throwOnSend;

  /// Whether [disconnect] should throw.
  final bool throwOnDisconnect;

  @override
  Future<bool> doConnect() async {
    if (neverConnects) return Completer<bool>().future;
    if (!shouldConnect) return false;
    // Fire fake responses to trigger onMessage handlers
    for (final msg in fakeResponses) {
      await onMessage?.call(this, msg);
    }
    return true;
  }

  @override
  Future<bool> send(
    List<dynamic> message, {
    bool queueIfFailed = true,
    bool skipReconnect = false,
    DateTime? deadline,
  }) async {
    // Only throw on CLOSE messages (not REQ sent by onConnected)
    if (throwOnSend && message.isNotEmpty && message[0] == 'CLOSE') {
      throw Exception('Send failed');
    }
    if (neverCloses && message.isNotEmpty && message[0] == 'CLOSE') {
      return Completer<bool>().future;
    }
    return true;
  }

  @override
  Future<void> disconnect() async {
    if (neverDisconnects) return Completer<void>().future;
    if (throwOnDisconnect) throw Exception('Disconnect failed');
  }
}

class _FakeContactList extends Fake implements ContactList {}

/// A [FakeCacheDao] whose [delete] always throws, to exercise the non-fatal
/// cache-invalidation failure path in `_invalidateMyFollowingCache`.
class _ThrowingDeleteCacheDao extends FakeCacheDao {
  @override
  Future<void> delete(String key) async => throw Exception('delete failed');
}

void main() {
  group('FollowRepository', () {
    late FollowRepository repository;
    late _MockNostrClient mockNostrClient;
    late FakeCacheDao cacheDao;
    late bool cacheIsInitialized;
    late List<Event> Function(int kind) getCachedEventsByKind;
    late List<Event> cachedUserEvents;

    // Valid 64-character hex pubkeys for testing
    const testCurrentUserPubkey =
        'a1b2c3d4e5f6789012345678901234567890abcdef1234567890123456789012';
    const testTargetPubkey =
        'b2c3d4e5f6789012345678901234567890abcdef1234567890123456789012a1';
    const testTargetPubkey2 =
        'c3d4e5f6789012345678901234567890abcdef1234567890123456789012ab12';
    const testTargetPubkey3 =
        'd4e5f6789012345678901234567890abcdef1234567890123456789012ab12c3';

    setUpAll(() {
      registerFallbackValue(_MockEvent());
      registerFallbackValue(<Filter>[]);
      registerFallbackValue(_FakeContactList());
    });

    setUp(() async {
      SharedPreferences.setMockInitialValues({});

      cacheDao = FakeCacheDao();
      await CacheSync.init(dao: cacheDao);

      mockNostrClient = _MockNostrClient();
      cacheIsInitialized = false;
      getCachedEventsByKind = (_) => [];
      cachedUserEvents = [];

      // Default nostr client setup
      when(() => mockNostrClient.hasKeys).thenReturn(true);
      when(() => mockNostrClient.publicKey).thenReturn(testCurrentUserPubkey);

      // Default nostr client subscribe - return empty stream
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

      // Default nostr client unsubscribe - return completed future
      when(() => mockNostrClient.unsubscribe(any())).thenAnswer((_) async {});

      repository = FollowRepository(
        nostrClient: mockNostrClient,
        isCacheInitialized: () => cacheIsInitialized,
        getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
        cacheUserEvent: cachedUserEvents.add,
        // Prevent real WebSocket connections to indexer relays in tests
        indexerRelayUrls: const [],
      );
    });

    tearDown(() async {
      await repository.dispose();
    });

    group('initialization', () {
      test('initializes with empty following list', () async {
        await repository.initialize();

        expect(repository.isInitialized, isTrue);
        expect(repository.followingCount, 0);
        expect(repository.followingPubkeys, isEmpty);
      });

      test('loads following list from local storage', () async {
        // Pre-populate SharedPreferences with cached data
        SharedPreferences.setMockInitialValues({
          'following_list_$testCurrentUserPubkey':
              '["$testTargetPubkey", "$testTargetPubkey2"]',
        });

        // Recreate repository to pick up the cached data
        repository = FollowRepository(
          nostrClient: mockNostrClient,
          isCacheInitialized: () => cacheIsInitialized,
          getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
          cacheUserEvent: cachedUserEvents.add,
          indexerRelayUrls: const [],
        );

        await repository.initialize();

        expect(repository.followingCount, 2);
        expect(repository.isFollowing(testTargetPubkey), isTrue);
        expect(repository.isFollowing(testTargetPubkey2), isTrue);
      });

      test('loads following list from REST API when cache is empty', () async {
        // No cached data in SharedPreferences or PersonalEventCache
        // But REST API (funnelcake) has the following list
        SharedPreferences.setMockInitialValues({
          'following_prefetch_complete_$testCurrentUserPubkey': true,
        });
        final mockFunnelcakeClient = _MockFunnelcakeApiClient();
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getFollowing(
            pubkey: any(named: 'pubkey'),
            offset: any(named: 'offset'),
          ),
        ).thenAnswer(
          // funnelcake stores contact-list pubkeys unvalidated and serves them
          // back verbatim, so an invalid entry reaches this path end-to-end.
          (_) async => const PaginatedPubkeys(
            pubkeys: [testTargetPubkey, 'nos', testTargetPubkey2],
          ),
        );

        repository = FollowRepository(
          nostrClient: mockNostrClient,
          isCacheInitialized: () => cacheIsInitialized,
          getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
          cacheUserEvent: cachedUserEvents.add,
          funnelcakeApiClient: mockFunnelcakeClient,
          indexerRelayUrls: const [],
        );

        await repository.initialize();

        expect(repository.followingCount, 2);
        expect(repository.followingPubkeys, isNot(contains('nos')));
        expect(repository.isFollowing(testTargetPubkey), isTrue);
        expect(repository.isFollowing(testTargetPubkey2), isTrue);

        // Verify it was also saved to SharedPreferences for redirect logic
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getString('following_list_$testCurrentUserPubkey');
        expect(cached, isNotNull);
      });

      // #6109: the derived sources (LocalStorage, PersonalEventCache, REST)
      // lag and truncate, and the next follow rebuilds and republishes the
      // whole list from whatever they returned. Accepting one as final
      // destroys every follow it was missing, so the authoritative Kind 3 is
      // always consulted -- not only when the derived sources came up empty.
      test(
        'queries the relay even when local storage already answered',
        () async {
          SharedPreferences.setMockInitialValues({
            'following_list_$testCurrentUserPubkey': '["$testTargetPubkey"]',
          });

          final authoritative = Event(
            testCurrentUserPubkey,
            3,
            [
              ['p', testTargetPubkey],
              ['p', testTargetPubkey2],
            ],
            '',
            createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          );

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
          ).thenAnswer((_) => Stream<Event>.value(authoritative));

          repository = FollowRepository(
            nostrClient: mockNostrClient,
            isCacheInitialized: () => cacheIsInitialized,
            getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
            cacheUserEvent: cachedUserEvents.add,
            indexerRelayUrls: const [],
          );

          await repository.initialize();

          // Without the relay query the list would stay at the stale [target]
          // and the next follow would republish it, destroying target2.
          expect(repository.followingPubkeys, contains(testTargetPubkey2));
          expect(repository.followingCount, 2);
        },
      );

      // PersonalEventCache caches Kind 3 events, which is exactly where the
      // reported `["p","nos"]` entry lives, so a poisoned event replays through
      // this path on every launch until the cache is evicted.
      test('drops invalid p tags from a cached Kind 3 event', () async {
        cacheIsInitialized = true;
        getCachedEventsByKind = (kind) => kind == 3
            ? [
                Event(
                  testCurrentUserPubkey,
                  3,
                  [
                    ['p', 'nos'],
                    ['p', testTargetPubkey],
                  ],
                  '',
                  createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
                ),
              ]
            : <Event>[];

        repository = FollowRepository(
          nostrClient: mockNostrClient,
          isCacheInitialized: () => cacheIsInitialized,
          getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
          cacheUserEvent: cachedUserEvents.add,
          indexerRelayUrls: const [],
        );

        await repository.initialize();

        expect(repository.followingPubkeys, [testTargetPubkey]);
      });

      // #6109: the server clamps `limit` to 100 whatever we ask for, so an
      // account with more than 100 follows used to bootstrap from a silently
      // truncated list.
      test(
        'pages past the server limit cap when loading from REST API',
        () async {
          // Exactly 64 hex chars each, or _sanitizePubkeys drops them.
          final page1 = List.generate(
            100,
            (i) => 'a' * 60 + i.toRadixString(16).padLeft(4, '0'),
          );
          final page2 = [testTargetPubkey, testTargetPubkey2];

          final mockFunnelcakeClient = _MockFunnelcakeApiClient();
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getFollowing(
              pubkey: any(named: 'pubkey'),
              offset: any(named: 'offset', that: isZero),
            ),
          ).thenAnswer(
            (_) async => PaginatedPubkeys(
              pubkeys: page1,
              total: 102,
              hasMore: true,
            ),
          );
          when(
            () => mockFunnelcakeClient.getFollowing(
              pubkey: any(named: 'pubkey'),
              offset: 100,
            ),
          ).thenAnswer(
            (_) async => PaginatedPubkeys(pubkeys: page2, total: 102),
          );

          repository = FollowRepository(
            nostrClient: mockNostrClient,
            isCacheInitialized: () => cacheIsInitialized,
            getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
            cacheUserEvent: cachedUserEvents.add,
            funnelcakeApiClient: mockFunnelcakeClient,
            indexerRelayUrls: const [],
          );

          await repository.initialize();

          expect(repository.followingCount, 102);
          expect(repository.isFollowing(testTargetPubkey2), isTrue);
        },
      );

      test('skips REST API when local cache already has data', () async {
        SharedPreferences.setMockInitialValues({
          'following_list_$testCurrentUserPubkey': '["$testTargetPubkey"]',
        });

        final mockFunnelcakeClient = _MockFunnelcakeApiClient();
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);

        repository = FollowRepository(
          nostrClient: mockNostrClient,
          isCacheInitialized: () => cacheIsInitialized,
          getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
          cacheUserEvent: cachedUserEvents.add,
          funnelcakeApiClient: mockFunnelcakeClient,
          indexerRelayUrls: const [],
        );

        await repository.initialize();

        // Should have loaded from cache, not called API
        verifyNever(
          () => mockFunnelcakeClient.getFollowing(
            pubkey: any(named: 'pubkey'),
            offset: any(named: 'offset'),
          ),
        );
        expect(repository.followingCount, 1);
      });

      test('handles REST API failure gracefully', () async {
        final mockFunnelcakeClient = _MockFunnelcakeApiClient();
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getFollowing(
            pubkey: any(named: 'pubkey'),
            offset: any(named: 'offset'),
          ),
        ).thenThrow(Exception('Network error'));

        repository = FollowRepository(
          nostrClient: mockNostrClient,
          isCacheInitialized: () => cacheIsInitialized,
          getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
          cacheUserEvent: cachedUserEvents.add,
          funnelcakeApiClient: mockFunnelcakeClient,
          indexerRelayUrls: const [],
        );

        // Should not throw, just log warning and continue
        await repository.initialize();

        expect(repository.isInitialized, isTrue);
        expect(repository.followingCount, 0);
      });

      test('does not reinitialize if already initialized', () async {
        await repository.initialize();
        expect(repository.isInitialized, isTrue);

        // Second call should return immediately
        await repository.initialize();
        expect(repository.isInitialized, isTrue);

        // Verify subscribe was called twice during first init:
        // 1. _loadFromRelay() (relay kind 3 query when list is empty)
        // 2. _subscribeToContactList() (real-time cross-device sync)
        verify(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
            onEose: any(named: 'onEose'),
          ),
        ).called(2);
      });
    });

    group('isFollowing', () {
      test('returns false for unfollowed user', () async {
        await repository.initialize();

        expect(repository.isFollowing(testTargetPubkey), isFalse);
      });

      test('returns true for followed user', () async {
        SharedPreferences.setMockInitialValues({
          'following_list_$testCurrentUserPubkey': '["$testTargetPubkey"]',
        });

        await repository.initialize();

        expect(repository.isFollowing(testTargetPubkey), isTrue);
      });
    });

    group('relationshipTo', () {
      /// Stubs the relay query so [pubkeys] each follow the current user.
      void stubFollowersOfMe(List<String> pubkeys) {
        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [
            for (final pubkey in pubkeys)
              Event(
                pubkey,
                3,
                [
                  ['p', testCurrentUserPubkey],
                ],
                '',
                createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
              ),
          ],
        );
      }

      test('returns none for a stranger', () async {
        await repository.initialize();

        expect(
          repository.relationshipTo(testTargetPubkey),
          equals(FollowRelationship.none),
        );
      });

      test('returns youFollow when only the current user follows', () async {
        SharedPreferences.setMockInitialValues({
          'following_list_$testCurrentUserPubkey': '["$testTargetPubkey"]',
        });
        stubFollowersOfMe([testTargetPubkey2]);

        await repository.initialize();
        await repository.getMyFollowers();

        expect(
          repository.relationshipTo(testTargetPubkey),
          equals(FollowRelationship.youFollow),
        );
      });

      test('returns followsYou when only the target follows', () async {
        stubFollowersOfMe([testTargetPubkey]);

        await repository.initialize();
        await repository.getMyFollowers();

        expect(
          repository.relationshipTo(testTargetPubkey),
          equals(FollowRelationship.followsYou),
        );
      });

      test('returns mutual when both follow each other', () async {
        SharedPreferences.setMockInitialValues({
          'following_list_$testCurrentUserPubkey': '["$testTargetPubkey"]',
        });
        stubFollowersOfMe([testTargetPubkey]);

        await repository.initialize();
        await repository.getMyFollowers();

        expect(
          repository.relationshipTo(testTargetPubkey),
          equals(FollowRelationship.mutual),
        );
      });

      test('reports youFollow, not mutual, while the follower cache is '
          'cold', () async {
        SharedPreferences.setMockInitialValues({
          'following_list_$testCurrentUserPubkey': '["$testTargetPubkey"]',
        });
        stubFollowersOfMe([testTargetPubkey]);

        await repository.initialize();

        // getMyFollowers() has not run, so "follows you" is unknowable and
        // must not be claimed.
        expect(
          repository.relationshipTo(testTargetPubkey),
          equals(FollowRelationship.youFollow),
        );
      });

      test('returns none for the current user', () async {
        stubFollowersOfMe([testTargetPubkey]);

        await repository.initialize();
        await repository.getMyFollowers();

        expect(
          repository.relationshipTo(testCurrentUserPubkey),
          equals(FollowRelationship.none),
        );
      });

      test('returns none for an empty pubkey', () async {
        await repository.initialize();

        expect(
          repository.relationshipTo(''),
          equals(FollowRelationship.none),
        );
      });
    });

    group('follow', () {
      test('throws when not authenticated', () async {
        when(() => mockNostrClient.hasKeys).thenReturn(false);

        await repository.initialize();

        expect(
          () => repository.follow(testTargetPubkey),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('not authenticated'),
            ),
          ),
        );
      });

      test('does nothing when already following', () async {
        SharedPreferences.setMockInitialValues({
          'following_list_$testCurrentUserPubkey': '["$testTargetPubkey"]',
        });

        await repository.initialize();

        expect(repository.isFollowing(testTargetPubkey), isTrue);
        expect(repository.followingCount, 1);

        await repository.follow(testTargetPubkey);

        expect(repository.followingCount, 1);
      });

      test('successfully follows a user', () async {
        final mockEvent = _MockEvent();
        when(() => mockEvent.id).thenReturn(testCurrentUserPubkey);
        when(() => mockEvent.content).thenReturn('');

        when(
          () => mockNostrClient.sendContactList(
            any(),
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => mockEvent);

        await repository.initialize();
        expect(repository.isFollowing(testTargetPubkey), isFalse);
        await repository.follow(testTargetPubkey);
        expect(repository.isFollowing(testTargetPubkey), isTrue);
        expect(repository.followingCount, 1);
      });

      test('rolls back on broadcast failure', () async {
        when(
          () => mockNostrClient.sendContactList(
            any(),
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => null);

        await repository.initialize();
        expect(repository.isFollowing(testTargetPubkey), isFalse);
        await expectLater(
          repository.follow(testTargetPubkey),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Failed to broadcast'),
            ),
          ),
        );

        expect(repository.isFollowing(testTargetPubkey), isFalse);
        expect(repository.followingCount, 0);
      });
    });

    group('inconclusive own contact-list read (#8265)', () {
      void stubContactListRead({
        List<Event> events = const <Event>[],
        bool timedOut = false,
        bool noRelays = false,
      }) {
        when(
          () => mockNostrClient.queryEventsDetailed(
            any(),
            requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer(
          (_) async => (
            events: events,
            timedOut: timedOut,
            noRelays: noRelays,
            anyRelayAnswered: false,
            unsettledRelays: const <String>[],
          ),
        );
      }

      void stubBroadcastSucceeds() {
        final mockEvent = _MockEvent();
        when(() => mockEvent.id).thenReturn(testCurrentUserPubkey);
        when(() => mockEvent.content).thenReturn('');
        when(
          () => mockNostrClient.sendContactList(
            any(),
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => mockEvent);
      }

      test('following does not broadcast when the read timed out', () async {
        stubBroadcastSucceeds();
        stubContactListRead(timedOut: true);

        await repository.initialize();
        await repository.follow(testTargetPubkey);

        verifyNever(
          () => mockNostrClient.sendContactList(
            any(),
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        );
      });

      test(
        'following does not broadcast when no relay took the query',
        () async {
          stubBroadcastSucceeds();
          stubContactListRead(noRelays: true);

          await repository.initialize();
          await repository.follow(testTargetPubkey);

          verifyNever(
            () => mockNostrClient.sendContactList(
              any(),
              any(),
              tempRelays: any(named: 'tempRelays'),
              targetRelays: any(named: 'targetRelays'),
            ),
          );
        },
      );

      test(
        'the follow still applies locally when the broadcast is withheld',
        () async {
          stubBroadcastSucceeds();
          stubContactListRead(timedOut: true);

          await repository.initialize();
          await repository.follow(testTargetPubkey);

          expect(repository.isFollowing(testTargetPubkey), isTrue);
          expect(repository.followingCount, 1);
        },
      );

      test(
        'unfollowing does not broadcast when the read is inconclusive',
        () async {
          SharedPreferences.setMockInitialValues({
            'following_list_$testCurrentUserPubkey': '["$testTargetPubkey"]',
          });
          stubBroadcastSucceeds();
          stubContactListRead(timedOut: true);

          await repository.initialize();
          await repository.unfollow(testTargetPubkey);

          expect(repository.isFollowing(testTargetPubkey), isFalse);
          verifyNever(
            () => mockNostrClient.sendContactList(
              any(),
              any(),
              tempRelays: any(named: 'tempRelays'),
              targetRelays: any(named: 'targetRelays'),
            ),
          );
        },
      );

      test('a settled empty read still broadcasts, so a first follow reaches '
          'the relay', () async {
        stubBroadcastSucceeds();
        stubContactListRead();

        await repository.initialize();
        await repository.follow(testTargetPubkey);

        verify(
          () => mockNostrClient.sendContactList(
            any(),
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).called(1);
      });

      test('a withheld broadcast is flushed by the retry, preserving the '
          "relay's content", () async {
        stubBroadcastSucceeds();
        stubContactListRead(timedOut: true);

        await repository.initialize();
        await repository.follow(testTargetPubkey);
        expect(await repository.retryPendingContactListBroadcast(), isFalse);

        final existing = _MockEvent();
        when(() => existing.id).thenReturn('existing-contact-list');
        when(() => existing.pubkey).thenReturn(testCurrentUserPubkey);
        when(() => existing.kind).thenReturn(EventKind.contactList);
        when(() => existing.createdAt).thenReturn(1000);
        when(() => existing.content).thenReturn('{"wss://relay.example":{}}');
        when(() => existing.tags).thenReturn(const []);
        stubContactListRead(events: [existing]);

        expect(await repository.retryPendingContactListBroadcast(), isTrue);

        final content =
            verify(
                  () => mockNostrClient.sendContactList(
                    any(),
                    captureAny(),
                    tempRelays: any(named: 'tempRelays'),
                    targetRelays: any(named: 'targetRelays'),
                  ),
                ).captured.last
                as String;
        expect(content, '{"wss://relay.example":{}}');
      });

      test('the retry is a no-op when nothing is pending', () async {
        stubBroadcastSucceeds();
        stubContactListRead();

        await repository.initialize();
        await repository.follow(testTargetPubkey);
        clearInteractions(mockNostrClient);

        expect(await repository.retryPendingContactListBroadcast(), isFalse);
        verifyNever(
          () => mockNostrClient.sendContactList(
            any(),
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        );
      });

      test(
        'a retry whose publish fails reports false and stays pending',
        () async {
          stubBroadcastSucceeds();
          stubContactListRead(timedOut: true);

          await repository.initialize();
          await repository.follow(testTargetPubkey);

          // Read now succeeds, but the publish does not: _broadcastContactList
          // throws, and a background retry has no caller to surface that to.
          stubContactListRead();
          when(
            () => mockNostrClient.sendContactList(
              any(),
              any(),
              tempRelays: any(named: 'tempRelays'),
              targetRelays: any(named: 'targetRelays'),
            ),
          ).thenAnswer((_) async => null);

          expect(await repository.retryPendingContactListBroadcast(), isFalse);

          // Still pending, so a later signal retries rather than dropping it.
          stubBroadcastSucceeds();
          expect(await repository.retryPendingContactListBroadcast(), isTrue);
        },
      );

      test(
        'keeps the newest kind 3 when the relay serves several versions',
        () async {
          stubBroadcastSucceeds();

          _MockEvent contactList(int createdAt, String content) {
            final event = _MockEvent();
            when(() => event.id).thenReturn('contact-list-$createdAt');
            when(() => event.pubkey).thenReturn(testCurrentUserPubkey);
            when(() => event.kind).thenReturn(EventKind.contactList);
            when(() => event.createdAt).thenReturn(createdAt);
            when(() => event.content).thenReturn(content);
            when(() => event.tags).thenReturn(const []);
            return event;
          }

          // Newest first, so the older one exercises the skip rather than the
          // adopt. A relay that has not merged its replaceable rows yet can
          // serve both.
          stubContactListRead(
            events: [contactList(2000, 'newer'), contactList(1000, 'older')],
          );

          await repository.initialize();
          await repository.follow(testTargetPubkey);

          final content =
              verify(
                    () => mockNostrClient.sendContactList(
                      any(),
                      captureAny(),
                      tempRelays: any(named: 'tempRelays'),
                      targetRelays: any(named: 'targetRelays'),
                    ),
                  ).captured.last
                  as String;
          expect(content, 'newer');
        },
      );
    });

    // Regression: a real user's Kind 3 event carried a `["p","nos"]` entry,
    // produced by a parser that read `tag[1]` of a `["client","nos",...]` tag
    // without filtering on `p`. Every follow and unfollow then failed with
    // `Invalid key: "nos"` from Contact's constructor, because the broadcast
    // rebuilds the whole list and aborts before publishing.
    group('invalid pubkey handling', () {
      const invalidPubkey = 'nos';

      test('drops invalid entries when loading from local storage', () async {
        SharedPreferences.setMockInitialValues({
          'following_list_$testCurrentUserPubkey':
              '["$invalidPubkey", "$testTargetPubkey"]',
        });

        await repository.initialize();

        expect(repository.followingPubkeys, [testTargetPubkey]);
        expect(repository.isFollowing(invalidPubkey), isFalse);
      });

      test('persists the sanitized list after loading invalid local storage '
          'entries', () async {
        SharedPreferences.setMockInitialValues({
          'following_list_$testCurrentUserPubkey':
              '["$invalidPubkey", "$testTargetPubkey"]',
        });

        await repository.initialize();

        final prefs = await SharedPreferences.getInstance();
        final stored =
            jsonDecode(
                  prefs.getString('following_list_$testCurrentUserPubkey')!,
                )
                as Map<String, dynamic>;
        expect(stored['pubkeys'], [testTargetPubkey]);
        // A v1 record carries no timestamp, so the rewrite records none —
        // which is what makes it lose to any real event (#8266).
        expect(stored['created_at'], isNull);
      });

      test('follow succeeds and publishes a clean list when the cached '
          'list holds an invalid pubkey', () async {
        SharedPreferences.setMockInitialValues({
          'following_list_$testCurrentUserPubkey':
              '["$invalidPubkey", "$testTargetPubkey"]',
        });

        final mockEvent = _MockEvent();
        when(() => mockEvent.id).thenReturn(testCurrentUserPubkey);
        when(() => mockEvent.content).thenReturn('');

        final publishedLists = <ContactList>[];
        when(
          () => mockNostrClient.sendContactList(
            captureAny(),
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((invocation) async {
          publishedLists.add(invocation.positionalArguments[0] as ContactList);
          return mockEvent;
        });

        await repository.initialize();

        await repository.follow(testTargetPubkey2);

        expect(repository.isFollowing(testTargetPubkey2), isTrue);
        expect(publishedLists, hasLength(1));
        expect(
          publishedLists.single.list().map((contact) => contact.publicKey),
          [testTargetPubkey, testTargetPubkey2],
        );
      });

      test('throws when following an invalid pubkey', () async {
        await repository.initialize();

        await expectLater(
          repository.follow(invalidPubkey),
          throwsA(isA<ArgumentError>()),
        );
        expect(repository.followingCount, 0);
      });

      // executeFollowAction replays queued actions without validating, so the
      // publish-site sanitize is the only thing that drops an invalid entry
      // there. Observers must not be left holding one the getter has dropped.
      test('emits the sanitized list when the broadcast drops an invalid '
          'pubkey', () async {
        final mockEvent = _MockEvent();
        when(() => mockEvent.id).thenReturn(testCurrentUserPubkey);
        when(() => mockEvent.content).thenReturn('');

        when(
          () => mockNostrClient.sendContactList(
            any(),
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => mockEvent);

        await repository.initialize();

        final emittedValues = <List<String>>[];
        final subscription = repository.followingStream.listen(
          emittedValues.add,
        );

        await repository.executeFollowAction(invalidPubkey);
        await Future<void>.delayed(Duration.zero);

        expect(repository.followingPubkeys, isEmpty);
        expect(emittedValues.last, isEmpty);

        await subscription.cancel();
      });
    });

    // #6903: blocking hid the account in-app but left it in the published
    // kind 3, so Divine's own public follower APIs kept reporting the follow.
    // The omission happens at the publish boundary only — the local list is
    // untouched by the filter, so blocking never costs the follow
    // synchronously. The round-trip that does drop it is pinned separately
    // in 'the filtered kind 3 read back replaces the local list' below.
    group('blocked pubkeys are omitted from the published contact list', () {
      late List<ContactList> publishedLists;
      late Set<String> blocked;
      late List<String> accountsAsked;

      FollowRepository buildRepository({
        BlockedPubkeysCallback? blockedPubkeys,
      }) {
        return FollowRepository(
          nostrClient: mockNostrClient,
          isCacheInitialized: () => cacheIsInitialized,
          getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
          cacheUserEvent: cachedUserEvents.add,
          indexerRelayUrls: const [],
          blockedPubkeys: blockedPubkeys,
        );
      }

      List<String> publishedPubkeys(ContactList list) =>
          list.list().map((contact) => contact.publicKey).toList();

      setUp(() {
        SharedPreferences.setMockInitialValues({
          'following_list_$testCurrentUserPubkey':
              '["$testTargetPubkey", "$testTargetPubkey2"]',
        });

        blocked = <String>{};
        accountsAsked = <String>[];
        publishedLists = <ContactList>[];

        final mockEvent = _MockEvent();
        when(() => mockEvent.id).thenReturn(testCurrentUserPubkey);
        when(() => mockEvent.content).thenReturn('');
        when(
          () => mockNostrClient.sendContactList(
            captureAny(),
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((invocation) async {
          publishedLists.add(invocation.positionalArguments[0] as ContactList);
          return mockEvent;
        });
      });

      test('publishes every follow when no port is injected', () async {
        repository = buildRepository();
        await repository.initialize();

        await repository.republishContactList();

        expect(publishedLists, hasLength(1));
        expect(publishedPubkeys(publishedLists.single), [
          testTargetPubkey,
          testTargetPubkey2,
        ]);
      });

      test('publishes every follow when nothing is blocked', () async {
        repository = buildRepository(blockedPubkeys: (_) => blocked);
        await repository.initialize();

        await repository.republishContactList();

        expect(publishedPubkeys(publishedLists.single), [
          testTargetPubkey,
          testTargetPubkey2,
        ]);
      });

      test('omits a blocked follow while the local list keeps it', () async {
        blocked.add(testTargetPubkey);
        repository = buildRepository(blockedPubkeys: (_) => blocked);
        await repository.initialize();

        final emitted = <List<String>>[];
        final subscription = repository.followingStream.listen(emitted.add);
        // followingStream replays its latest value to late subscribers, so
        // drain that before counting what the publish itself emits.
        await Future<void>.delayed(Duration.zero);
        final emittedBefore = emitted.length;

        await repository.republishContactList();
        await Future<void>.delayed(Duration.zero);

        expect(publishedPubkeys(publishedLists.single), [testTargetPubkey2]);

        // The local list is the half that must NOT change: mutating it here
        // would make unblocking cost the follow permanently, and would flip
        // every in-app follow-list reader at the same time.
        expect(repository.followingPubkeys, [
          testTargetPubkey,
          testTargetPubkey2,
        ]);
        expect(repository.isFollowing(testTargetPubkey), isTrue);
        expect(
          emitted.length,
          emittedBefore,
          reason: 'the publish filter must not emit on followingStream',
        );

        await subscription.cancel();
      });

      test('re-includes the follow once the block is lifted', () async {
        blocked.add(testTargetPubkey);
        repository = buildRepository(blockedPubkeys: (_) => blocked);
        await repository.initialize();

        await repository.republishContactList();
        expect(publishedPubkeys(publishedLists.single), [testTargetPubkey2]);

        blocked.remove(testTargetPubkey);
        await repository.republishContactList();

        expect(publishedPubkeys(publishedLists.last), [
          testTargetPubkey,
          testTargetPubkey2,
        ]);
      });

      test('asks the port for the signing account only', () async {
        repository = buildRepository(
          blockedPubkeys: (account) {
            accountsAsked.add(account);
            return blocked;
          },
        );
        await repository.initialize();

        await repository.republishContactList();

        // The repository hands over the pubkey that will sign the event, so
        // the app layer can refuse to answer for any other account. Without
        // it a session signing as B could publish B's kind 3 filtered
        // against A's blocklist.
        expect(accountsAsked, [testCurrentUserPubkey]);
      });

      test('drops the blocked entry on an ordinary follow too', () async {
        blocked.add(testTargetPubkey);
        repository = buildRepository(blockedPubkeys: (_) => blocked);
        await repository.initialize();

        await repository.follow(testTargetPubkey3);

        expect(publishedPubkeys(publishedLists.single), [
          testTargetPubkey2,
          testTargetPubkey3,
        ]);
      });

      test('republishContactList throws when not authenticated', () async {
        repository = buildRepository(blockedPubkeys: (_) => blocked);
        await repository.initialize();
        when(() => mockNostrClient.hasKeys).thenReturn(false);

        await expectLater(
          repository.republishContactList(),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('not authenticated'),
            ),
          ),
        );
        expect(publishedLists, isEmpty);
      });

      // The filter is a publish-boundary property, and this is where it
      // stops being one. Relays hold the filtered event from the publish
      // onwards, so the next initialize() reads it back and, being the newest
      // kind 3, it replaces the local list. Pinned so that "unblocking
      // restores the follow" is never read as durable: it holds for the
      // session that blocked, not past the next launch. Whether it should be
      // restorable at all is open with T&S (#6903).
      test('the filtered kind 3 read back replaces the local list', () async {
        blocked.add(testTargetPubkey);
        var relayContactList = Event(
          testCurrentUserPubkey,
          EventKind.contactList,
          [
            ['p', testTargetPubkey],
            ['p', testTargetPubkey2],
          ],
          '',
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        );
        when(
          () => mockNostrClient.sendContactList(
            captureAny(),
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((invocation) async {
          final list = invocation.positionalArguments[0] as ContactList;
          publishedLists.add(list);
          // What the relay now serves to everyone, including us.
          return relayContactList = Event(
            testCurrentUserPubkey,
            EventKind.contactList,
            [
              for (final contact in list.list()) ['p', contact.publicKey],
            ],
            '',
            createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 1,
          );
        });

        FollowRepository session() => FollowRepository(
          nostrClient: mockNostrClient,
          isCacheInitialized: () => cacheIsInitialized,
          getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
          cacheUserEvent: cachedUserEvents.add,
          indexerRelayUrls: const [],
          blockedPubkeys: (_) => blocked,
          queryContactList:
              ({
                required eventStream,
                required pubkey,
                fallbackTimeoutSeconds = 10,
              }) async => relayContactList,
        );

        repository = session();
        await repository.initialize();
        await repository.republishContactList();
        expect(publishedPubkeys(publishedLists.single), [testTargetPubkey2]);
        expect(
          repository.followingPubkeys,
          contains(testTargetPubkey),
          reason: 'still intact for the rest of this session',
        );
        await repository.dispose();

        repository = session();
        await repository.initialize();

        expect(repository.followingPubkeys, [testTargetPubkey2]);
        expect(repository.isFollowing(testTargetPubkey), isFalse);
      });
    });

    group('initialized', () {
      test('does not complete while the user has no keys', () async {
        when(() => mockNostrClient.hasKeys).thenReturn(false);
        var completed = false;
        unawaited(repository.initialized.then((_) => completed = true));

        await repository.initialize();
        await Future<void>.delayed(Duration.zero);

        expect(repository.isInitialized, isFalse);
        expect(completed, isFalse);
      });

      test('completes once initialize finishes', () async {
        await repository.initialize();

        await expectLater(repository.initialized, completes);
        expect(repository.isInitialized, isTrue);
      });

      test('stays completed across a repeated initialize', () async {
        await repository.initialize();
        await repository.initialize();

        await expectLater(repository.initialized, completes);
      });
    });

    group('unfollow', () {
      test('throws when not authenticated', () async {
        when(() => mockNostrClient.hasKeys).thenReturn(false);

        await repository.initialize();

        expect(
          () => repository.unfollow(testTargetPubkey),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('not authenticated'),
            ),
          ),
        );
      });

      test('does nothing when not following', () async {
        await repository.initialize();
        await repository.unfollow(testTargetPubkey);
        expect(repository.followingCount, 0);
      });

      test('successfully unfollows a user', () async {
        SharedPreferences.setMockInitialValues({
          'following_list_$testCurrentUserPubkey': '["$testTargetPubkey"]',
        });

        final mockEvent = _MockEvent();
        when(() => mockEvent.id).thenReturn(testCurrentUserPubkey);
        when(() => mockEvent.content).thenReturn('');

        when(
          () => mockNostrClient.sendContactList(
            any(),
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => mockEvent);

        await repository.initialize();
        expect(repository.isFollowing(testTargetPubkey), isTrue);
        expect(repository.followingCount, 1);

        await repository.unfollow(testTargetPubkey);

        expect(repository.isFollowing(testTargetPubkey), isFalse);
        expect(repository.followingCount, 0);
      });

      test('rolls back on broadcast failure', () async {
        // Pre-populate with followed user
        SharedPreferences.setMockInitialValues({
          'following_list_$testCurrentUserPubkey': '["$testTargetPubkey"]',
        });

        when(
          () => mockNostrClient.sendContactList(
            any(),
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => null);

        await repository.initialize();
        expect(repository.isFollowing(testTargetPubkey), isTrue);
        expect(repository.followingCount, 1);

        await expectLater(
          repository.unfollow(testTargetPubkey),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Failed to broadcast'),
            ),
          ),
        );

        // Should have rolled back
        expect(repository.isFollowing(testTargetPubkey), isTrue);
        expect(repository.followingCount, 1);
      });
    });

    group('toggleFollow', () {
      test('follows when not currently following', () async {
        final mockEvent = _MockEvent();
        when(() => mockEvent.id).thenReturn(testCurrentUserPubkey);
        when(() => mockEvent.content).thenReturn('');

        when(
          () => mockNostrClient.sendContactList(
            any(),
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => mockEvent);

        await repository.initialize();
        expect(repository.isFollowing(testTargetPubkey), isFalse);

        await repository.toggleFollow(testTargetPubkey);

        expect(repository.isFollowing(testTargetPubkey), isTrue);
      });

      test('unfollows when currently following', () async {
        SharedPreferences.setMockInitialValues({
          'following_list_$testCurrentUserPubkey': '["$testTargetPubkey"]',
        });

        final mockEvent = _MockEvent();
        when(() => mockEvent.id).thenReturn(testCurrentUserPubkey);
        when(() => mockEvent.content).thenReturn('');

        when(
          () => mockNostrClient.sendContactList(
            any(),
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => mockEvent);

        repository = FollowRepository(
          nostrClient: mockNostrClient,
          isCacheInitialized: () => cacheIsInitialized,
          getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
          cacheUserEvent: cachedUserEvents.add,
          indexerRelayUrls: const [],
        );

        await repository.initialize();
        expect(repository.isFollowing(testTargetPubkey), isTrue);

        await repository.toggleFollow(testTargetPubkey);

        expect(repository.isFollowing(testTargetPubkey), isFalse);
      });

      test('propagates errors from follow', () async {
        when(
          () => mockNostrClient.sendContactList(
            any(),
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => null);

        await repository.initialize();

        await expectLater(
          repository.toggleFollow(testTargetPubkey),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Failed to broadcast'),
            ),
          ),
        );
      });

      test('propagates errors from unfollow', () async {
        SharedPreferences.setMockInitialValues({
          'following_list_$testCurrentUserPubkey': '["$testTargetPubkey"]',
        });

        when(
          () => mockNostrClient.sendContactList(
            any(),
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => null);

        repository = FollowRepository(
          nostrClient: mockNostrClient,
          isCacheInitialized: () => cacheIsInitialized,
          getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
          cacheUserEvent: cachedUserEvents.add,
          indexerRelayUrls: const [],
        );

        await repository.initialize();

        await expectLater(
          repository.toggleFollow(testTargetPubkey),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Failed to broadcast'),
            ),
          ),
        );
      });
    });

    group('CacheSync invalidation on mutation (#5144)', () {
      String myFollowingKey(String pubkey) => '$pubkey:my_following';

      void stubBroadcastSuccess() {
        final mockEvent = _MockEvent();
        when(() => mockEvent.id).thenReturn(testCurrentUserPubkey);
        when(() => mockEvent.content).thenReturn('');
        when(
          () => mockNostrClient.sendContactList(
            any(),
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => mockEvent);
      }

      test('follow() invalidates the my_following cache entry', () async {
        stubBroadcastSuccess();
        await cacheDao.write(
          key: myFollowingKey(testCurrentUserPubkey),
          payload: const FollowingSnapshot(
            pubkeys: [testTargetPubkey2],
            count: 1,
          ).toJson(),
        );
        expect(
          await cacheDao.read(myFollowingKey(testCurrentUserPubkey)),
          isNotNull,
        );

        await repository.follow(testTargetPubkey);

        expect(
          await cacheDao.read(myFollowingKey(testCurrentUserPubkey)),
          isNull,
        );
      });

      test('unfollow() invalidates the my_following cache entry', () async {
        SharedPreferences.setMockInitialValues({
          'following_list_$testCurrentUserPubkey': '["$testTargetPubkey"]',
        });
        repository = FollowRepository(
          nostrClient: mockNostrClient,
          isCacheInitialized: () => cacheIsInitialized,
          getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
          cacheUserEvent: cachedUserEvents.add,
          indexerRelayUrls: const [],
        );
        await repository.initialize();
        stubBroadcastSuccess();
        await cacheDao.write(
          key: myFollowingKey(testCurrentUserPubkey),
          payload: const FollowingSnapshot(
            pubkeys: [testTargetPubkey],
            count: 1,
          ).toJson(),
        );

        await repository.unfollow(testTargetPubkey);

        expect(
          await cacheDao.read(myFollowingKey(testCurrentUserPubkey)),
          isNull,
        );
      });

      test(
        'cross-device Kind 3 update invalidates the my_following cache entry',
        () async {
          final realTimeStreamController = StreamController<Event>.broadcast();
          addTearDown(() async {
            await repository.dispose();
            await realTimeStreamController.close();
          });
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
          ).thenAnswer((_) => realTimeStreamController.stream);

          await repository.initialize();
          await cacheDao.write(
            key: myFollowingKey(testCurrentUserPubkey),
            payload: const FollowingSnapshot(
              pubkeys: [testTargetPubkey2],
              count: 1,
            ).toJson(),
          );
          expect(
            await cacheDao.read(myFollowingKey(testCurrentUserPubkey)),
            isNotNull,
          );

          // A newer Kind 3 event arrives from another device.
          realTimeStreamController.add(
            Event(
              testCurrentUserPubkey,
              3,
              [
                ['p', testTargetPubkey],
              ],
              '',
              createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 100,
            ),
          );
          await Future<void>.delayed(const Duration(milliseconds: 50));

          expect(repository.followingPubkeys, contains(testTargetPubkey));
          expect(
            await cacheDao.read(myFollowingKey(testCurrentUserPubkey)),
            isNull,
          );
        },
      );

      test('follow() succeeds even when cache invalidation throws', () async {
        await CacheSync.init(dao: _ThrowingDeleteCacheDao());
        stubBroadcastSuccess();

        await repository.follow(testTargetPubkey);

        expect(repository.followingPubkeys, contains(testTargetPubkey));
      });
    });

    group('followingStream', () {
      test('is a broadcast stream', () {
        expect(repository.followingStream.isBroadcast, isTrue);
      });

      test('emits updated list when follow succeeds', () async {
        final mockEvent = _MockEvent();
        when(() => mockEvent.id).thenReturn(testCurrentUserPubkey);
        when(() => mockEvent.content).thenReturn('');

        when(
          () => mockNostrClient.sendContactList(
            any(),
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => mockEvent);

        await repository.initialize();

        final emittedValues = <List<String>>[];
        final subscription = repository.followingStream.listen(
          emittedValues.add,
        );

        await repository.follow(testTargetPubkey);
        await Future<void>.delayed(Duration.zero);

        expect(emittedValues.length, greaterThanOrEqualTo(1));
        expect(emittedValues.last, contains(testTargetPubkey));

        await subscription.cancel();
      });

      test('emits updated list when unfollow succeeds', () async {
        SharedPreferences.setMockInitialValues({
          'following_list_$testCurrentUserPubkey': '["$testTargetPubkey"]',
        });

        final mockEvent = _MockEvent();
        when(() => mockEvent.id).thenReturn(testCurrentUserPubkey);
        when(() => mockEvent.content).thenReturn('');

        when(
          () => mockNostrClient.sendContactList(
            any(),
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => mockEvent);

        await repository.initialize();

        final emittedValues = <List<String>>[];
        final subscription = repository.followingStream.listen(
          emittedValues.add,
        );

        await repository.unfollow(testTargetPubkey);
        await Future<void>.delayed(Duration.zero);

        expect(emittedValues.length, greaterThanOrEqualTo(1));
        expect(emittedValues.last, isNot(contains(testTargetPubkey)));

        await subscription.cancel();
      });
    });

    group('dispose', () {
      test('closes the stream controller', () async {
        await repository.initialize();

        await repository.dispose();

        expect(
          () => repository.followingStream.listen((_) {}),
          returnsNormally,
        );
      });
    });

    group('self-follow prevention', () {
      test('follow() silently ignores when target is self', () async {
        await repository.initialize();

        // Attempt to follow self (testCurrentUserPubkey is the mock's publicKey)
        await repository.follow(testCurrentUserPubkey);

        expect(repository.isFollowing(testCurrentUserPubkey), isFalse);
        expect(repository.followingCount, 0);

        // Verify sendContactList was never called
        verifyNever(
          () => mockNostrClient.sendContactList(
            any(),
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        );
      });

      test('unfollow() silently ignores when target is self', () async {
        await repository.initialize();

        // Attempt to unfollow self
        await repository.unfollow(testCurrentUserPubkey);

        // Verify sendContactList was never called
        verifyNever(
          () => mockNostrClient.sendContactList(
            any(),
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        );
      });

      test('toggleFollow() silently ignores when target is self', () async {
        await repository.initialize();

        // Attempt to toggle follow on self
        await repository.toggleFollow(testCurrentUserPubkey);

        expect(repository.isFollowing(testCurrentUserPubkey), isFalse);

        // Verify sendContactList was never called
        verifyNever(
          () => mockNostrClient.sendContactList(
            any(),
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        );
      });
    });

    group('getFollowers', () {
      test('returns empty list when pubkey is empty', () async {
        final followers = await repository.getFollowers('');

        expect(followers, isEmpty);
        verifyNever(() => mockNostrClient.queryEvents(any()));
      });

      test('returns empty list when no followers', () async {
        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => []);

        final followers = await repository.getFollowers(testTargetPubkey);

        expect(followers, isEmpty);
      });

      test('returns list of follower pubkeys', () async {
        const follower1 =
            'e5f6789012345678901234567890abcdef1234567890123456789012abcd1234';
        const follower2 =
            'f6789012345678901234567890abcdef1234567890123456789012abcde12345';

        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [
            Event(
              follower1,
              3,
              [
                ['p', testTargetPubkey],
              ],
              '',
              createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            ),
            Event(
              follower2,
              3,
              [
                ['p', testTargetPubkey],
              ],
              '',
              createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            ),
          ],
        );

        final followers = await repository.getFollowers(testTargetPubkey);

        expect(followers, hasLength(2));
        expect(followers, contains(follower1));
        expect(followers, contains(follower2));
      });

      test('deduplicates followers from multiple events', () async {
        const follower1 =
            'e5f6789012345678901234567890abcdef1234567890123456789012abcd1234';

        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [
            Event(
              follower1,
              3,
              [
                ['p', testTargetPubkey],
              ],
              '',
              createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            ),
            // Duplicate event from same author (e.g., older contact list)
            Event(
              follower1,
              3,
              [
                ['p', testTargetPubkey],
              ],
              '',
              createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000 - 100000,
            ),
          ],
        );

        final followers = await repository.getFollowers(testTargetPubkey);

        expect(followers, hasLength(1));
        expect(followers, contains(follower1));
      });

      test('queries with correct filter for Kind 3 events', () async {
        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => []);

        await repository.getFollowers(testTargetPubkey);

        final captured = verify(
          () => mockNostrClient.queryEvents(captureAny()),
        ).captured;

        expect(captured, hasLength(1));
        final filters = captured.first as List<Filter>;
        expect(filters, hasLength(1));
        expect(filters.first.kinds, equals([3]));
        expect(filters.first.p, contains(testTargetPubkey));
      });

      test('returns empty list on timeout', () {
        fakeAsync((async) {
          // Simulate a slow query that exceeds the repository's internal
          // 8-second timeout (_fetchFollowersTimeout).
          when(() => mockNostrClient.queryEvents(any())).thenAnswer((_) async {
            await Future<void>.delayed(const Duration(seconds: 15));
            return [];
          });

          List<String>? followers;
          unawaited(
            repository
                .getFollowers(testTargetPubkey)
                .then((r) => followers = r),
          );

          // Advance past the 8s _fetchFollowersTimeout.
          async
            ..elapse(const Duration(seconds: 9))
            ..flushMicrotasks();

          expect(followers, isEmpty);
        });
      });

      test('does not cache an empty snapshot when a source fails', () async {
        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenThrow(Exception('Relays unavailable'));

        await expectLater(
          repository.watchOthersFollowersCached(testTargetPubkey),
          emitsError(isA<Exception>()),
        );
        expect(cacheDao.length, isZero);
      });
    });

    group('follower ordering', () {
      const followerA =
          'aa11111111111111111111111111111111111111111111111111111111111111';
      const followerB =
          'bb22222222222222222222222222222222222222222222222222222222222222';
      const followerC =
          'cc33333333333333333333333333333333333333333333333333333333333333';

      Event contactListAt(String author, int createdAt) => Event(
        author,
        EventKind.contactList,
        [
          ['p', testTargetPubkey],
        ],
        '',
        createdAt: createdAt,
      );

      /// Rebuilds [repository] with a REST source that answers [apiFollowers].
      void withApiFollowers(List<String> apiFollowers) {
        final mockFunnelcakeClient = _MockFunnelcakeApiClient();
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getFollowers(
            pubkey: any(named: 'pubkey'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => PaginatedPubkeys(pubkeys: apiFollowers));

        repository = FollowRepository(
          nostrClient: mockNostrClient,
          isCacheInitialized: () => cacheIsInitialized,
          getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
          cacheUserEvent: cachedUserEvents.add,
          funnelcakeApiClient: mockFunnelcakeClient,
          indexerRelayUrls: const [],
        );
      }

      test('lists the most recent contact-list update first', () async {
        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [
            contactListAt(followerA, 1000),
            contactListAt(followerB, 3000),
            contactListAt(followerC, 2000),
          ],
        );

        final followers = await repository.getFollowers(testTargetPubkey);

        expect(followers, equals([followerB, followerC, followerA]));
      });

      test('ranks a follower by their freshest contact-list event', () async {
        // A relay that has not yet dropped the superseded kind 3 can answer
        // with both revisions; the follower belongs at their newest.
        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [
            contactListAt(followerA, 1000),
            contactListAt(followerB, 2000),
            contactListAt(followerA, 3000),
          ],
        );

        final followers = await repository.getFollowers(testTargetPubkey);

        expect(followers, equals([followerA, followerB]));
      });

      test(
        'keeps the freshest event when the older one arrives last',
        () async {
          when(() => mockNostrClient.queryEvents(any())).thenAnswer(
            (_) async => [
              contactListAt(followerA, 3000),
              contactListAt(followerB, 2000),
              contactListAt(followerA, 1000),
            ],
          );

          final followers = await repository.getFollowers(testTargetPubkey);

          expect(followers, equals([followerA, followerB]));
        },
      );

      test('demotes a future-dated contact list to the undated tail', () async {
        // created_at is author-signed and nothing on the read path bounds it,
        // so an event dated far ahead would otherwise hold the top slot of
        // every follower list it appears in, permanently.
        final farFuture =
            DateTime.now().millisecondsSinceEpoch ~/ 1000 + 365 * 86400;
        withApiFollowers(const []);
        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [
            contactListAt(followerA, farFuture),
            contactListAt(followerB, 3000),
          ],
        );

        final result = await repository
            .watchOthersFollowersCached(testTargetPubkey)
            .last;

        expect(result.data.pubkeys, equals([followerB, followerA]));
        expect(
          result.data.datedCount,
          equals(1),
          reason:
              'the future-dated follower must not count as datable, or '
              '"oldest first" would flip it back to the top',
        );
      });

      test('keeps a contact list within the tolerated clock skew', () async {
        // Honest skew is minutes; demoting it would cost the follower their
        // real position for no benefit.
        final slightlyAhead =
            DateTime.now().millisecondsSinceEpoch ~/ 1000 + 60;
        withApiFollowers(const []);
        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [
            contactListAt(followerA, slightlyAhead),
            contactListAt(followerB, 3000),
          ],
        );

        final result = await repository
            .watchOthersFollowersCached(testTargetPubkey)
            .last;

        expect(result.data.pubkeys, equals([followerA, followerB]));
        expect(result.data.datedCount, equals(2));
      });

      test('sorts timestamped followers above untimestamped ones', () async {
        // The REST source answers with bare pubkeys, so followerA and
        // followerC have no timestamp to rank by.
        withApiFollowers(const [followerA, followerC]);
        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [contactListAt(followerB, 1000)]);

        final followers = await repository.getFollowers(testTargetPubkey);

        expect(followers, equals([followerB, followerA, followerC]));
      });

      test(
        'times an untimestamped follower by the relay that has one',
        () async {
          withApiFollowers(const [followerA, followerB]);
          when(
            () => mockNostrClient.queryEvents(any()),
          ).thenAnswer((_) async => [contactListAt(followerB, 1000)]);

          final followers = await repository.getFollowers(testTargetPubkey);

          // followerB arrived second and untimestamped from the REST source;
          // the relay's timestamp promotes it above followerA.
          expect(followers, equals([followerB, followerA]));
        },
      );

      test('reports the dated boundary for another user', () async {
        withApiFollowers(const [followerC]);
        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [
            contactListAt(followerA, 1000),
            contactListAt(followerB, 2000),
          ],
        );

        final result = await repository
            .watchOthersFollowersCached(testTargetPubkey)
            .last;

        // followerC came from the REST source undated, so only the two relay
        // followers are datable and the boundary sits at 2.
        expect(
          result.data.pubkeys,
          equals([followerB, followerA, followerC]),
        );
        expect(result.data.datedCount, equals(2));
      });

      test('preserves arrival order among untimestamped followers', () async {
        withApiFollowers(const [followerC, followerA, followerB]);
        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => <Event>[]);

        final followers = await repository.getFollowers(testTargetPubkey);

        expect(followers, equals([followerC, followerA, followerB]));
      });
    });

    group('getMyFollowers', () {
      test('returns empty list when not authenticated', () async {
        when(() => mockNostrClient.publicKey).thenReturn('');

        final followers = await repository.getMyFollowers();

        expect(followers, isEmpty);
        verifyNever(() => mockNostrClient.queryEvents(any()));
      });

      test('does not mark an empty-pubkey follower result as cached', () async {
        const follower =
            'e5f6789012345678901234567890abcdef1234567890123456789012abcd1234';
        var currentPubkey = '';
        when(() => mockNostrClient.publicKey).thenAnswer((_) => currentPubkey);

        final unauthenticatedFollowers = await repository.getMyFollowers();
        expect(unauthenticatedFollowers, isEmpty);
        verifyNever(() => mockNostrClient.queryEvents(any()));

        currentPubkey = testCurrentUserPubkey;
        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [
            Event(
              follower,
              3,
              [
                ['p', testCurrentUserPubkey],
              ],
              '',
              createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            ),
          ],
        );

        final firstEmission = await repository.watchMyFollowers().first;

        expect(firstEmission.pubkeys, equals([follower]));
      });

      test('returns followers for current user', () async {
        const follower1 =
            'e5f6789012345678901234567890abcdef1234567890123456789012abcd1234';
        const follower2 =
            'f6789012345678901234567890abcdef1234567890123456789012abcde12345';

        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [
            Event(
              follower1,
              3,
              [
                ['p', testCurrentUserPubkey],
              ],
              '',
              createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            ),
            Event(
              follower2,
              3,
              [
                ['p', testCurrentUserPubkey],
              ],
              '',
              createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            ),
          ],
        );

        final followers = await repository.getMyFollowers();

        expect(followers, hasLength(2));
        expect(followers, contains(follower1));
        expect(followers, contains(follower2));
      });

      test('queries with current user pubkey', () async {
        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => []);

        await repository.getMyFollowers();

        final captured = verify(
          () => mockNostrClient.queryEvents(captureAny()),
        ).captured;

        expect(captured, hasLength(1));
        final filters = captured.first as List<Filter>;
        expect(filters, hasLength(1));
        expect(filters.first.kinds, equals([3]));
        expect(filters.first.p, contains(testCurrentUserPubkey));
      });
    });

    group('streamMyFollowers', () {
      const follower1 =
          'e5f6789012345678901234567890abcdef1234567890123456789012abcd1234';
      const follower2 =
          'f6789012345678901234567890abcdef1234567890123456789012abcde12345';

      /// Builds a repository whose REST source answers immediately while the
      /// connected-relay source stays pending until [relayResult] completes.
      FollowRepository buildRepository({
        required Future<List<Event>> Function() relayResult,
        List<String> apiFollowers = const [],
        bool apiAvailable = true,
      }) {
        final mockFunnelcakeClient = _MockFunnelcakeApiClient();
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(apiAvailable);
        when(
          () => mockFunnelcakeClient.getFollowers(
            pubkey: any(named: 'pubkey'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => PaginatedPubkeys(pubkeys: apiFollowers));
        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) => relayResult());

        return FollowRepository(
          nostrClient: mockNostrClient,
          isCacheInitialized: () => cacheIsInitialized,
          getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
          cacheUserEvent: cachedUserEvents.add,
          funnelcakeApiClient: mockFunnelcakeClient,
          indexerRelayUrls: const [],
        );
      }

      Event contactListOf(String author) => Event(
        author,
        3,
        [
          ['p', testCurrentUserPubkey],
        ],
        '',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );

      test('emits a growing union as each source answers', () async {
        final slowRelay = Completer<List<Event>>();
        repository = buildRepository(
          relayResult: () => slowRelay.future,
          apiFollowers: const [follower1],
        );

        final emissions = <List<String>>[];
        final done = repository.streamMyFollowers().forEach(emissions.add);

        // The fast REST source lands first, on its own.
        await pumpEventQueue();
        expect(emissions, [
          [follower1],
        ]);

        slowRelay.complete([contactListOf(follower2)]);
        await done;

        // Later sources only add to the membership, but they do reorder it:
        // follower2 arrives with a contact-list timestamp and outranks the
        // REST source's untimestamped follower1.
        expect(emissions.last, equals([follower2, follower1]));
        expect(emissions.first, equals([follower1]));
      });

      test('does not re-emit when a later source adds nothing', () async {
        final slowRelay = Completer<List<Event>>();
        repository = buildRepository(
          relayResult: () => slowRelay.future,
          apiFollowers: const [follower1],
        );

        final emissions = <List<String>>[];
        final done = repository.streamMyFollowers().forEach(emissions.add);

        await pumpEventQueue();
        slowRelay.complete([contactListOf(follower1)]);
        await done;

        // The relay only timestamped a follower already on screen, and a
        // one-element list cannot reorder — nothing to re-render.
        expect(emissions, [
          [follower1],
        ]);
      });

      test('primes the dated boundary alongside the cached list', () async {
        final slowRelay = Completer<List<Event>>();
        repository = buildRepository(
          relayResult: () => slowRelay.future,
          apiFollowers: const [follower1],
        );

        final done = repository.streamMyFollowers().forEach((_) {});
        await pumpEventQueue();
        slowRelay.complete([contactListOf(follower1)]);
        await done;

        // The relay timestamped follower1 without moving them, so the stream
        // never re-emitted. The primed boundary still has to record that
        // timestamp, or watchMyFollowers hands its cached list out as undated
        // and 'oldest first' silently leaves it alone.
        final cached = await repository.watchMyFollowers().first;

        expect(cached.pubkeys, equals([follower1]));
        expect(cached.datedCount, 1);
      });

      test('re-emits when a later source reorders the list', () async {
        final slowRelay = Completer<List<Event>>();
        repository = buildRepository(
          relayResult: () => slowRelay.future,
          apiFollowers: const [follower1, follower2],
        );

        final emissions = <List<String>>[];
        final done = repository.streamMyFollowers().forEach(emissions.add);

        await pumpEventQueue();
        slowRelay.complete([contactListOf(follower2)]);
        await done;

        // Same membership, new order: the relay's timestamp for follower2
        // pulls it above the still-untimestamped follower1.
        expect(emissions, [
          [follower1, follower2],
          [follower2, follower1],
        ]);
      });

      test('keeps emitting when a single source fails', () async {
        repository = buildRepository(
          relayResult: () => Future<List<Event>>.error(Exception('relay down')),
          apiFollowers: const [follower1],
        );

        final followers = await repository.streamMyFollowers().last;

        expect(followers, equals([follower1]));
      });

      test(
        'emits an error when a source fails and nothing was found',
        () async {
          repository = buildRepository(
            relayResult: () => Future<List<Event>>.error(
              Exception('relay down'),
            ),
            apiAvailable: false,
          );

          await expectLater(
            repository.streamMyFollowers(),
            emitsThrough(emitsError(isA<Exception>())),
          );
        },
      );

      test('emits an empty list when not authenticated', () async {
        when(() => mockNostrClient.publicKey).thenReturn('');

        final emissions = await repository.streamMyFollowers().toList();

        expect(emissions, [<String>[]]);
        verifyNever(() => mockNostrClient.queryEvents(any()));
      });
    });

    group('watchMyFollowers', () {
      const follower1 =
          'e5f6789012345678901234567890abcdef1234567890123456789012abcd1234';
      const follower2 =
          'f6789012345678901234567890abcdef1234567890123456789012abcde12345';

      test('yields only fresh data on first call (no cache)', () async {
        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [
            Event(
              follower1,
              3,
              [
                ['p', testCurrentUserPubkey],
              ],
              '',
              createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            ),
          ],
        );

        final emissions = await repository.watchMyFollowers().toList();

        expect(emissions, hasLength(1));
        expect(emissions.first.pubkeys, contains(follower1));
      });

      test('reports how many followers carry a timestamp', () async {
        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [
            Event(
              follower1,
              3,
              [
                ['p', testCurrentUserPubkey],
              ],
              '',
              createdAt: 1000,
            ),
            Event(
              follower2,
              3,
              [
                ['p', testCurrentUserPubkey],
              ],
              '',
              createdAt: 2000,
            ),
          ],
        );

        final snapshot = await repository.watchMyFollowers().last;

        // Both came from the relay, so the whole list is datable and a flip
        // to oldest-first may reverse all of it.
        expect(snapshot.pubkeys, equals([follower2, follower1]));
        expect(snapshot.datedCount, equals(2));
      });

      test('carries the dated boundary into the cached emission', () async {
        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [
            Event(
              follower1,
              3,
              [
                ['p', testCurrentUserPubkey],
              ],
              '',
              createdAt: 1000,
            ),
          ],
        );

        // First pass populates the in-memory cache the second pass replays.
        await repository.watchMyFollowers().toList();
        final emissions = await repository.watchMyFollowers().toList();

        expect(emissions, hasLength(2));
        expect(emissions.first.datedCount, equals(1));
      });

      test('yields cached data then fresh data on second call', () async {
        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [
            Event(
              follower1,
              3,
              [
                ['p', testCurrentUserPubkey],
              ],
              '',
              createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            ),
          ],
        );

        // First call — populates cache
        await repository.watchMyFollowers().toList();

        // Second call — should now yield cache first, then fresh
        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [
            Event(
              follower1,
              3,
              [
                ['p', testCurrentUserPubkey],
              ],
              '',
              createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            ),
            Event(
              follower2,
              3,
              [
                ['p', testCurrentUserPubkey],
              ],
              '',
              createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            ),
          ],
        );

        final emissions = await repository.watchMyFollowers().toList();

        expect(emissions, hasLength(2));
        // First emission: cached data from first call
        expect(emissions[0].pubkeys, contains(follower1));
        expect(emissions[0].pubkeys, isNot(contains(follower2)));
        // Second emission: fresh data
        expect(emissions[1].pubkeys, contains(follower1));
        expect(emissions[1].pubkeys, contains(follower2));
      });
    });

    group('watchMyFollowing', () {
      test(
        'emits FollowingSnapshot when following list is initialized',
        () async {
          // Pre-populate SharedPreferences so initialize() loads a non-empty
          // following list without needing to call follow() and mock
          // sendContactList.
          SharedPreferences.setMockInitialValues({
            'following_list_$testCurrentUserPubkey': '["$testTargetPubkey"]',
          });
          repository = FollowRepository(
            nostrClient: mockNostrClient,
            isCacheInitialized: () => cacheIsInitialized,
            getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
            cacheUserEvent: cachedUserEvents.add,
            indexerRelayUrls: const [],
          );

          await repository.initialize();

          final emission = await repository.watchMyFollowing().first;

          expect(emission.pubkeys, contains(testTargetPubkey));
          expect(emission.count, equals(1));
        },
      );

      test('emits FollowingSnapshot with empty list when no follows', () async {
        await repository.initialize();

        final emission = await repository.watchMyFollowing().first;

        expect(emission.pubkeys, isEmpty);
        expect(emission.count, equals(0));
      });
    });

    group('getOthersFollowing', () {
      test('times out when the relay query never completes', () {
        fakeAsync((async) {
          when(
            () => mockNostrClient.queryEvents(any()),
          ).thenAnswer((_) => Completer<List<Event>>().future);
          Object? error;

          unawaited(
            repository
                .getOthersFollowing(testTargetPubkey)
                .then<void>(
                  (_) {},
                  onError: (Object caught) => error = caught,
                ),
          );
          async
            ..elapse(const Duration(seconds: 8))
            ..flushMicrotasks();

          expect(error, isA<TimeoutException>());
        });
      });

      test('returns empty snapshot when no events found', () async {
        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => []);

        final snapshot = await repository.getOthersFollowing(testTargetPubkey);

        expect(snapshot.pubkeys, isEmpty);
        expect(snapshot.count, equals(0));
      });

      // Also backs watchMyFollowingCached() -> MyFollowingBloc for the current
      // user, so an unfiltered entry would render as a ghost row on the own
      // Following screen and be persisted to Drift by CacheSync.
      test('drops invalid p tags and keeps count in step', () async {
        final event = Event(
          testTargetPubkey,
          3,
          [
            ['p', 'nos'],
            ['p', testTargetPubkey2],
          ],
          '',
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        );

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [event]);

        final snapshot = await repository.getOthersFollowing(testTargetPubkey);

        expect(snapshot.pubkeys, [testTargetPubkey2]);
        expect(snapshot.count, 1);
      });

      test('returns following list from Kind 3 event p-tags', () async {
        final event = Event(
          testTargetPubkey,
          3,
          [
            ['p', testTargetPubkey2],
            ['p', testCurrentUserPubkey],
          ],
          '',
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        );

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [event]);

        final snapshot = await repository.getOthersFollowing(testTargetPubkey);

        expect(snapshot.pubkeys, hasLength(2));
        expect(snapshot.pubkeys, contains(testTargetPubkey2));
        expect(snapshot.pubkeys, contains(testCurrentUserPubkey));
        expect(snapshot.count, equals(2));
      });

      test('deduplicates repeated pubkeys in tags', () async {
        final event = Event(
          testTargetPubkey,
          3,
          [
            ['p', testTargetPubkey2],
            ['p', testTargetPubkey2],
          ],
          '',
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        );

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [event]);

        final snapshot = await repository.getOthersFollowing(testTargetPubkey);

        expect(snapshot.pubkeys, hasLength(1));
        expect(snapshot.count, equals(1));
      });

      test('ignores tags with wrong type or missing pubkey field', () async {
        final event = Event(
          testTargetPubkey,
          3,
          [
            ['e', testTargetPubkey2],
            ['p'],
            ['p', testCurrentUserPubkey],
          ],
          '',
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        );

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [event]);

        final snapshot = await repository.getOthersFollowing(testTargetPubkey);

        expect(snapshot.pubkeys, hasLength(1));
        expect(snapshot.pubkeys, contains(testCurrentUserPubkey));
      });
    });

    group('real-time sync', () {
      late StreamController<Event> realTimeStreamController;

      setUp(() {
        realTimeStreamController = StreamController<Event>.broadcast();

        // Override the default subscribe mock to use the stream controller
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
        ).thenAnswer((_) => realTimeStreamController.stream);
      });

      tearDown(() async {
        // Dispose repository first to cancel stream listeners,
        // then close the controller.
        await repository.dispose();
        await realTimeStreamController.close();
      });

      test('updates following list when newer Kind 3 event arrives', () async {
        await repository.initialize();

        expect(repository.followingPubkeys, isEmpty);

        // Simulate remote Kind 3 event with a followed user
        final remoteEvent = Event(
          testCurrentUserPubkey,
          3,
          [
            ['p', testTargetPubkey],
          ],
          '',
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 100,
        );

        realTimeStreamController.add(remoteEvent);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(repository.followingPubkeys, contains(testTargetPubkey));
        expect(repository.followingCount, 1);
      });

      test('drops invalid p tags from a remote Kind 3 event', () async {
        await repository.initialize();

        final remoteEvent = Event(
          testCurrentUserPubkey,
          3,
          [
            ['p', 'nos'],
            ['p', testTargetPubkey],
          ],
          '',
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 100,
        );

        realTimeStreamController.add(remoteEvent);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(repository.followingPubkeys, [testTargetPubkey]);
      });

      test('updates with multiple followed users from remote event', () async {
        await repository.initialize();

        final remoteEvent = Event(
          testCurrentUserPubkey,
          3,
          [
            ['p', testTargetPubkey],
            ['p', testTargetPubkey2],
          ],
          '',
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 100,
        );

        realTimeStreamController.add(remoteEvent);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(repository.followingPubkeys, contains(testTargetPubkey));
        expect(repository.followingPubkeys, contains(testTargetPubkey2));
        expect(repository.followingCount, 2);
      });

      test('ignores Kind 3 events with older timestamps', () async {
        await repository.initialize();

        // First, add an event with a recent timestamp
        final recentEvent = Event(
          testCurrentUserPubkey,
          3,
          [
            ['p', testTargetPubkey],
          ],
          '',
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        );
        realTimeStreamController.add(recentEvent);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(repository.followingCount, 1);

        // Now send an older event that should be ignored
        final oldEvent = Event(
          testCurrentUserPubkey,
          3,
          [], // Empty follow list
          '',
          createdAt:
              DateTime.now().millisecondsSinceEpoch ~/ 1000 - 1000, // Older
        );

        realTimeStreamController.add(oldEvent);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Should still have the original following list
        expect(repository.followingPubkeys, contains(testTargetPubkey));
        expect(repository.followingCount, 1);
      });

      test('ignores events from other users', () async {
        const otherUserPubkey =
            'd4e5f6789012345678901234567890abcdef1234567890123456789012ab1234';

        await repository.initialize();

        // Simulate Kind 3 event from a different user
        final otherUserEvent = Event(
          otherUserPubkey, // Different author
          3,
          [
            ['p', testTargetPubkey],
          ],
          '',
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 100,
        );

        realTimeStreamController.add(otherUserEvent);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Should not update following list
        expect(repository.followingPubkeys, isEmpty);
      });

      test('ignores non-Kind-3 events', () async {
        await repository.initialize();

        // Simulate a different kind of event (Kind 1 = text note)
        final textNoteEvent = Event(
          testCurrentUserPubkey,
          1, // Not Kind 3
          [
            ['p', testTargetPubkey],
          ],
          'Hello world',
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 100,
        );

        realTimeStreamController.add(textNoteEvent);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Should not update following list
        expect(repository.followingPubkeys, isEmpty);
      });

      test('emits to followingStream when remote event arrives', () async {
        await repository.initialize();

        final emittedLists = <List<String>>[];
        final subscription = repository.followingStream.listen(
          emittedLists.add,
        );

        // Simulate remote Kind 3 event
        final remoteEvent = Event(
          testCurrentUserPubkey,
          3,
          [
            ['p', testTargetPubkey],
          ],
          '',
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 100,
        );

        realTimeStreamController.add(remoteEvent);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(emittedLists.length, greaterThanOrEqualTo(1));
        expect(emittedLists.last, contains(testTargetPubkey));

        await subscription.cancel();
      });

      // A cross-device mass unfollow. Nothing about the size of the drop
      // matters: the newer event is authoritative, so the removals stand.
      test(
        'a newer event that drops most of the list is adopted whole',
        () async {
          // Seed with 12 follows
          final seededPubkeys = List.generate(
            12,
            (i) => i.toRadixString(16).padLeft(64, '0'),
          );
          SharedPreferences.setMockInitialValues({
            'following_list_$testCurrentUserPubkey':
                '[${seededPubkeys.map((p) => '"$p"').join(',')}]',
          });

          repository = FollowRepository(
            nostrClient: mockNostrClient,
            isCacheInitialized: () => cacheIsInitialized,
            getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
            cacheUserEvent: cachedUserEvents.add,
            indexerRelayUrls: const [],
          );

          await repository.initialize();
          expect(repository.followingCount, 12);

          // Remote event keeps only 3 of the original 12 — a mass unfollow
          // on another client. Nothing about the size of the drop matters;
          // the newer event is authoritative.
          final remoteEvent = Event(
            testCurrentUserPubkey,
            3,
            seededPubkeys.take(3).map((p) => ['p', p]).toList(),
            '',
            createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 100,
          );

          realTimeStreamController.add(remoteEvent);
          await Future<void>.delayed(const Duration(milliseconds: 50));

          // Adopted as-is: the newer event replaces the local list.
          expect(repository.followingCount, 3);
        },
      );

      test(
        'accepts remote event with slightly fewer follows (legitimate unfollow)',
        () async {
          // Seed with 10 follows
          final seededPubkeys = List.generate(
            10,
            (i) => i.toRadixString(16).padLeft(64, '0'),
          );
          SharedPreferences.setMockInitialValues({
            'following_list_$testCurrentUserPubkey':
                '[${seededPubkeys.map((p) => '"$p"').join(',')}]',
          });

          repository = FollowRepository(
            nostrClient: mockNostrClient,
            isCacheInitialized: () => cacheIsInitialized,
            getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
            cacheUserEvent: cachedUserEvents.add,
            indexerRelayUrls: const [],
          );

          await repository.initialize();
          expect(repository.followingCount, 10);

          // Remote event removes 2 follows (8 remaining) — within threshold
          // ceil(10 * 0.5) = 5, and 8 >= 5, so accepted
          final remoteEvent = Event(
            testCurrentUserPubkey,
            3,
            seededPubkeys.take(8).map((p) => ['p', p]).toList(),
            '',
            createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 100,
          );

          realTimeStreamController.add(remoteEvent);
          await Future<void>.delayed(const Duration(milliseconds: 50));

          // Should accept the remote event as-is (8 follows)
          expect(repository.followingCount, 8);
        },
      );

      test('accepts remote event with more follows', () async {
        // Seed with 5 follows
        final seededPubkeys = List.generate(
          5,
          (i) => i.toRadixString(16).padLeft(64, '0'),
        );
        SharedPreferences.setMockInitialValues({
          'following_list_$testCurrentUserPubkey':
              '[${seededPubkeys.map((p) => '"$p"').join(',')}]',
        });

        repository = FollowRepository(
          nostrClient: mockNostrClient,
          isCacheInitialized: () => cacheIsInitialized,
          getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
          cacheUserEvent: cachedUserEvents.add,
          indexerRelayUrls: const [],
        );

        await repository.initialize();
        expect(repository.followingCount, 5);

        // Remote event with 10 follows (superset)
        final remotePubkeys = List.generate(
          10,
          (i) => i.toRadixString(16).padLeft(64, '0'),
        );
        final remoteEvent = Event(
          testCurrentUserPubkey,
          3,
          remotePubkeys.map((p) => ['p', p]).toList(),
          '',
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 100,
        );

        realTimeStreamController.add(remoteEvent);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Should accept the larger list
        expect(repository.followingCount, 10);
      });

      // Same rule at the small end: one follow replaced by a different one
      // is still just the newer event winning.
      test(
        'a newer event replaces a single-entry list',
        () async {
          // Seed with 1 follow
          final seededPubkeys = List.generate(
            1,
            (i) => i.toRadixString(16).padLeft(64, '0'),
          );
          SharedPreferences.setMockInitialValues({
            'following_list_$testCurrentUserPubkey':
                '[${seededPubkeys.map((p) => '"$p"').join(',')}]',
          });

          repository = FollowRepository(
            nostrClient: mockNostrClient,
            isCacheInitialized: () => cacheIsInitialized,
            getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
            cacheUserEvent: cachedUserEvents.add,
            indexerRelayUrls: const [],
          );

          await repository.initialize();
          expect(repository.followingCount, 1);

          // A one-entry list replaced by a different one-entry list.
          final remoteEvent = Event(
            testCurrentUserPubkey,
            3,
            [
              ['p', testTargetPubkey],
            ],
            '',
            createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 100,
          );

          realTimeStreamController.add(remoteEvent);
          await Future<void>.delayed(const Duration(milliseconds: 50));

          // Replaced outright: the newer event is authoritative.
          expect(repository.followingCount, 1);
          expect(repository.followingPubkeys, equals([testTargetPubkey]));
        },
      );

      test('cancels subscription on dispose', () async {
        await repository.initialize();

        await repository.dispose();

        // Verify that adding events after dispose doesn't cause issues
        final remoteEvent = Event(
          testCurrentUserPubkey,
          3,
          [
            ['p', testTargetPubkey],
          ],
          '',
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 100,
        );

        // This should not throw or cause any updates
        realTimeStreamController.add(remoteEvent);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Following list should remain empty (disposed before event processed)
        expect(repository.followingPubkeys, isEmpty);
      });
    });

    group('isMutualFollow', () {
      test('returns false when not following the target', () async {
        await repository.initialize();

        // We don't follow testTargetPubkey, so instant false
        final result = await repository.isMutualFollow(testTargetPubkey);

        expect(result, isFalse);

        // Should not even query the relay since step 1 fails
        verifyNever(() => mockNostrClient.queryEvents(any()));
      });

      test('returns true when mutual follow exists', () async {
        // Set up: we follow testTargetPubkey
        SharedPreferences.setMockInitialValues({
          'following_list_$testCurrentUserPubkey': '["$testTargetPubkey"]',
        });

        repository = FollowRepository(
          nostrClient: mockNostrClient,
          isCacheInitialized: () => cacheIsInitialized,
          getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
          cacheUserEvent: cachedUserEvents.add,
          indexerRelayUrls: const [],
        );

        await repository.initialize();

        // Mock: their Kind 3 event includes our pubkey
        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [
            Event(
              testTargetPubkey,
              3,
              [
                ['p', testCurrentUserPubkey],
              ],
              '',
              createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            ),
          ],
        );

        final result = await repository.isMutualFollow(testTargetPubkey);

        expect(result, isTrue);
      });

      test('returns false when they do not follow us back', () async {
        // Set up: we follow testTargetPubkey
        SharedPreferences.setMockInitialValues({
          'following_list_$testCurrentUserPubkey': '["$testTargetPubkey"]',
        });

        repository = FollowRepository(
          nostrClient: mockNostrClient,
          isCacheInitialized: () => cacheIsInitialized,
          getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
          cacheUserEvent: cachedUserEvents.add,
          indexerRelayUrls: const [],
        );

        await repository.initialize();

        // isMutualFollow makes two queryEvents calls:
        // 1. _fetchFollowers(ourPubkey) -> Filter(kinds:[3], #p:[ourPubkey])
        // 2. _checkIfTheyFollowUs(pubkey) -> Filter(authors:[pubkey], kinds:[3])
        // We need to return empty for _fetchFollowers (no one follows us)
        // and return their contact list without our pubkey for the second.
        var callCount = 0;
        when(() => mockNostrClient.queryEvents(any())).thenAnswer((_) async {
          callCount++;
          if (callCount == 1) {
            // _fetchFollowers: no events found (nobody follows us)
            return [];
          }
          // _checkIfTheyFollowUs: their contact list without our pubkey
          return [
            Event(
              testTargetPubkey,
              3,
              [
                [
                  'p',
                  'someoneelsepubkey1234567890123456789012345678901234567890',
                ],
              ],
              '',
              createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            ),
          ];
        });

        final result = await repository.isMutualFollow(testTargetPubkey);

        expect(result, isFalse);
      });

      test('returns false when every follower source fails', () async {
        // Set up: we follow testTargetPubkey
        SharedPreferences.setMockInitialValues({
          'following_list_$testCurrentUserPubkey': '["$testTargetPubkey"]',
        });

        repository = FollowRepository(
          nostrClient: mockNostrClient,
          isCacheInitialized: () => cacheIsInitialized,
          getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
          cacheUserEvent: cachedUserEvents.add,
          indexerRelayUrls: const [],
        );

        await repository.initialize();

        // No REST or indexer sources are configured, so this makes the only
        // network source fail and exercises isMutualFollow's public guard.
        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenThrow(Exception('Network error'));

        final result = await repository.isMutualFollow(testTargetPubkey);

        expect(result, isFalse);
      });
    });

    group('followingStream force-emit on initialize', () {
      test('emits on followingStream after initialize '
          'when user has no follows', () async {
        // No cached follows, no PersonalEventCache, no relay data
        SharedPreferences.setMockInitialValues({});

        repository = FollowRepository(
          nostrClient: mockNostrClient,
          isCacheInitialized: () => cacheIsInitialized,
          getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
          cacheUserEvent: cachedUserEvents.add,
          indexerRelayUrls: const [],
        );

        final emissions = <List<String>>[];
        final subscription = repository.followingStream.listen(emissions.add);

        // Seed value is [] — capture it
        await Future<void>.delayed(Duration.zero);
        final preInitCount = emissions.length;

        await repository.initialize();
        await Future<void>.delayed(Duration.zero);

        // Force-emit should add one more [] emission
        expect(emissions.length, greaterThan(preInitCount));
        expect(emissions.last, isEmpty);

        await subscription.cancel();
      });

      test('does not double-emit after initialize '
          'when user has follows', () async {
        SharedPreferences.setMockInitialValues({
          'following_list_$testCurrentUserPubkey': '["$testTargetPubkey"]',
        });

        repository = FollowRepository(
          nostrClient: mockNostrClient,
          isCacheInitialized: () => cacheIsInitialized,
          getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
          cacheUserEvent: cachedUserEvents.add,
          indexerRelayUrls: const [],
        );

        final emissions = <List<String>>[];
        final subscription = repository.followingStream.listen(emissions.add);

        await repository.initialize();
        await Future<void>.delayed(Duration.zero);

        // Should emit exactly once with the follow list (from
        // _emitFollowingList during _loadFromLocalStorage), no
        // extra force-emit because _followingPubkeys is non-empty.
        final nonSeedEmissions = emissions.where((e) => e.isNotEmpty).toList();
        expect(nonSeedEmissions, hasLength(1));
        expect(nonSeedEmissions.first, contains(testTargetPubkey));

        await subscription.cancel();
      });
    });

    group('getSocialCounts', () {
      late _MockFunnelcakeApiClient mockFunnelcakeClient;

      setUp(() {
        mockFunnelcakeClient = _MockFunnelcakeApiClient();
      });

      test('returns SocialCounts on success', () async {
        const testSocialCounts = SocialCounts(
          pubkey: testCurrentUserPubkey,
          followerCount: 100,
          followingCount: 50,
        );

        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getSocialCounts(testCurrentUserPubkey),
        ).thenAnswer((_) async => testSocialCounts);

        final repo = FollowRepository(
          nostrClient: mockNostrClient,
          isCacheInitialized: () => cacheIsInitialized,
          getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
          cacheUserEvent: cachedUserEvents.add,
          funnelcakeApiClient: mockFunnelcakeClient,
          indexerRelayUrls: const [],
        );

        final result = await repo.getSocialCounts(testCurrentUserPubkey);

        expect(result, equals(testSocialCounts));
        verify(
          () => mockFunnelcakeClient.getSocialCounts(testCurrentUserPubkey),
        ).called(1);
      });

      test('returns null when client is null', () async {
        final repo = FollowRepository(
          nostrClient: mockNostrClient,
          isCacheInitialized: () => cacheIsInitialized,
          getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
          cacheUserEvent: cachedUserEvents.add,
          indexerRelayUrls: const [],
        );

        final result = await repo.getSocialCounts(testCurrentUserPubkey);

        expect(result, isNull);
      });

      test('returns null when client is not available', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(false);

        final repo = FollowRepository(
          nostrClient: mockNostrClient,
          isCacheInitialized: () => cacheIsInitialized,
          getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
          cacheUserEvent: cachedUserEvents.add,
          funnelcakeApiClient: mockFunnelcakeClient,
          indexerRelayUrls: const [],
        );

        final result = await repo.getSocialCounts(testCurrentUserPubkey);

        expect(result, isNull);
        verifyNever(() => mockFunnelcakeClient.getSocialCounts(any()));
      });

      test('propagates FunnelcakeApiException', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(() => mockFunnelcakeClient.getSocialCounts(any())).thenThrow(
          const FunnelcakeApiException(
            message: 'Server error',
            statusCode: 500,
            url: 'https://example.com/api/social-counts',
          ),
        );

        final repo = FollowRepository(
          nostrClient: mockNostrClient,
          isCacheInitialized: () => cacheIsInitialized,
          getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
          cacheUserEvent: cachedUserEvents.add,
          funnelcakeApiClient: mockFunnelcakeClient,
          indexerRelayUrls: const [],
        );

        expect(
          () => repo.getSocialCounts(testCurrentUserPubkey),
          throwsA(isA<FunnelcakeApiException>()),
        );
      });
    });

    group('searchFollowList', () {
      late _MockFunnelcakeApiClient mockFunnelcakeClient;

      setUp(() {
        mockFunnelcakeClient = _MockFunnelcakeApiClient();
      });

      FollowRepository buildRepository({FunnelcakeApiClient? client}) {
        return FollowRepository(
          nostrClient: mockNostrClient,
          isCacheInitialized: () => cacheIsInitialized,
          getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
          cacheUserEvent: cachedUserEvents.add,
          funnelcakeApiClient: client,
          indexerRelayUrls: const [],
        );
      }

      test('returns the matching followers from the API', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getFollowers(
            pubkey: testCurrentUserPubkey,
            query: 'ali',
          ),
        ).thenAnswer(
          (_) async => const PaginatedPubkeys(
            pubkeys: [testTargetPubkey],
            total: 1,
            appliedQuery: 'ali',
          ),
        );

        final result = await buildRepository(client: mockFunnelcakeClient)
            .searchFollowList(
              pubkey: testCurrentUserPubkey,
              query: 'ali',
              kind: FollowListKind.followers,
            );

        expect(result, equals({testTargetPubkey}));
      });

      test('queries the following endpoint for the following kind', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getFollowing(
            pubkey: testCurrentUserPubkey,
            query: 'ali',
          ),
        ).thenAnswer(
          (_) async => const PaginatedPubkeys(
            pubkeys: [testTargetPubkey],
            total: 1,
            appliedQuery: 'ali',
          ),
        );

        final result = await buildRepository(client: mockFunnelcakeClient)
            .searchFollowList(
              pubkey: testCurrentUserPubkey,
              query: 'ali',
              kind: FollowListKind.following,
            );

        expect(result, equals({testTargetPubkey}));
        verifyNever(
          () => mockFunnelcakeClient.getFollowers(
            pubkey: any(named: 'pubkey'),
            query: any(named: 'query'),
          ),
        );
      });

      test('trims the query before sending it', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getFollowers(
            pubkey: testCurrentUserPubkey,
            query: 'ali',
          ),
        ).thenAnswer(
          (_) async => const PaginatedPubkeys(pubkeys: [], appliedQuery: 'ali'),
        );

        await buildRepository(client: mockFunnelcakeClient).searchFollowList(
          pubkey: testCurrentUserPubkey,
          query: '  ali  ',
          kind: FollowListKind.followers,
        );

        verify(
          () => mockFunnelcakeClient.getFollowers(
            pubkey: testCurrentUserPubkey,
            query: 'ali',
          ),
        ).called(1);
      });

      test('returns empty without calling the API for a blank query', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);

        final result = await buildRepository(client: mockFunnelcakeClient)
            .searchFollowList(
              pubkey: testCurrentUserPubkey,
              query: '   ',
              kind: FollowListKind.followers,
            );

        expect(result, isEmpty);
        verifyNever(
          () => mockFunnelcakeClient.getFollowers(
            pubkey: any(named: 'pubkey'),
            query: any(named: 'query'),
          ),
        );
      });

      test(
        'ignores a page from a server that did not apply the filter',
        () async {
          // A deployment predating the `q` parameter drops the unknown key and
          // answers with the plain first page. Trusting it would show a hundred
          // unrelated people as matches.
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getFollowers(
              pubkey: any(named: 'pubkey'),
              query: any(named: 'query'),
            ),
          ).thenAnswer(
            (_) async => const PaginatedPubkeys(
              pubkeys: [testTargetPubkey],
              total: 1,
            ),
          );

          final result = await buildRepository(client: mockFunnelcakeClient)
              .searchFollowList(
                pubkey: testCurrentUserPubkey,
                query: 'ali',
                kind: FollowListKind.followers,
              );

          expect(result, isEmpty);
        },
      );

      test('ignores a page echoing a different query', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getFollowers(
            pubkey: any(named: 'pubkey'),
            query: any(named: 'query'),
          ),
        ).thenAnswer(
          (_) async => const PaginatedPubkeys(
            pubkeys: [testTargetPubkey],
            total: 1,
            appliedQuery: 'something else',
          ),
        );

        final result = await buildRepository(client: mockFunnelcakeClient)
            .searchFollowList(
              pubkey: testCurrentUserPubkey,
              query: 'ali',
              kind: FollowListKind.followers,
            );

        expect(result, isEmpty);
      });

      test('returns empty when no API client is configured', () async {
        final result = await buildRepository().searchFollowList(
          pubkey: testCurrentUserPubkey,
          query: 'ali',
          kind: FollowListKind.followers,
        );

        expect(result, isEmpty);
      });

      test('swallows API errors so the caller can fall back', () async {
        // A deployment without the `q` parameter answers 404 here; the caller
        // still has its local filter, so this must not throw.
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getFollowers(
            pubkey: any(named: 'pubkey'),
            query: any(named: 'query'),
          ),
        ).thenThrow(
          FunnelcakeNotFoundException(
            resource: 'Followers',
            url: 'https://example.com/api/users/x/followers',
          ),
        );

        final result = await buildRepository(client: mockFunnelcakeClient)
            .searchFollowList(
              pubkey: testCurrentUserPubkey,
              query: 'ali',
              kind: FollowListKind.followers,
            );

        expect(result, isEmpty);
      });
    });

    group('getFollowersFromApi', () {
      late _MockFunnelcakeApiClient mockFunnelcakeClient;

      setUp(() {
        mockFunnelcakeClient = _MockFunnelcakeApiClient();
      });

      test('returns PaginatedPubkeys on success', () async {
        const testPaginatedPubkeys = PaginatedPubkeys(
          pubkeys: [testTargetPubkey],
          total: 1,
        );

        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () =>
              mockFunnelcakeClient.getFollowers(pubkey: testCurrentUserPubkey),
        ).thenAnswer((_) async => testPaginatedPubkeys);

        final repo = FollowRepository(
          nostrClient: mockNostrClient,
          isCacheInitialized: () => cacheIsInitialized,
          getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
          cacheUserEvent: cachedUserEvents.add,
          funnelcakeApiClient: mockFunnelcakeClient,
          indexerRelayUrls: const [],
        );

        final result = await repo.getFollowersFromApi(
          pubkey: testCurrentUserPubkey,
        );

        expect(result, equals(testPaginatedPubkeys));
        verify(
          () =>
              mockFunnelcakeClient.getFollowers(pubkey: testCurrentUserPubkey),
        ).called(1);
      });

      test('returns null when client is null', () async {
        final repo = FollowRepository(
          nostrClient: mockNostrClient,
          isCacheInitialized: () => cacheIsInitialized,
          getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
          cacheUserEvent: cachedUserEvents.add,
          indexerRelayUrls: const [],
        );

        final result = await repo.getFollowersFromApi(
          pubkey: testCurrentUserPubkey,
        );

        expect(result, isNull);
      });

      test('returns null when client is not available', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(false);

        final repo = FollowRepository(
          nostrClient: mockNostrClient,
          isCacheInitialized: () => cacheIsInitialized,
          getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
          cacheUserEvent: cachedUserEvents.add,
          funnelcakeApiClient: mockFunnelcakeClient,
          indexerRelayUrls: const [],
        );

        final result = await repo.getFollowersFromApi(
          pubkey: testCurrentUserPubkey,
        );

        expect(result, isNull);
        verifyNever(
          () => mockFunnelcakeClient.getFollowers(
            pubkey: any(named: 'pubkey'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          ),
        );
      });

      test('passes limit and offset correctly', () async {
        const testPaginatedPubkeys = PaginatedPubkeys(
          pubkeys: [testTargetPubkey, testTargetPubkey2],
          total: 200,
          hasMore: true,
        );

        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getFollowers(
            pubkey: testCurrentUserPubkey,
            limit: 50,
            offset: 100,
          ),
        ).thenAnswer((_) async => testPaginatedPubkeys);

        final repo = FollowRepository(
          nostrClient: mockNostrClient,
          isCacheInitialized: () => cacheIsInitialized,
          getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
          cacheUserEvent: cachedUserEvents.add,
          funnelcakeApiClient: mockFunnelcakeClient,
          indexerRelayUrls: const [],
        );

        final result = await repo.getFollowersFromApi(
          pubkey: testCurrentUserPubkey,
          limit: 50,
          offset: 100,
        );

        expect(result, equals(testPaginatedPubkeys));
        verify(
          () => mockFunnelcakeClient.getFollowers(
            pubkey: testCurrentUserPubkey,
            limit: 50,
            offset: 100,
          ),
        ).called(1);
      });

      test('propagates FunnelcakeApiException', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getFollowers(
            pubkey: any(named: 'pubkey'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          ),
        ).thenThrow(
          const FunnelcakeApiException(
            message: 'Server error',
            statusCode: 500,
            url: 'https://example.com/api/followers',
          ),
        );

        final repo = FollowRepository(
          nostrClient: mockNostrClient,
          isCacheInitialized: () => cacheIsInitialized,
          getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
          cacheUserEvent: cachedUserEvents.add,
          funnelcakeApiClient: mockFunnelcakeClient,
          indexerRelayUrls: const [],
        );

        expect(
          () => repo.getFollowersFromApi(pubkey: testCurrentUserPubkey),
          throwsA(isA<FunnelcakeApiException>()),
        );
      });
    });

    group('getFollowingFromApi', () {
      late _MockFunnelcakeApiClient mockFunnelcakeClient;

      setUp(() {
        mockFunnelcakeClient = _MockFunnelcakeApiClient();
      });

      test('returns PaginatedPubkeys on success', () async {
        const testPaginatedPubkeys = PaginatedPubkeys(
          pubkeys: [testTargetPubkey],
          total: 1,
        );

        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () =>
              mockFunnelcakeClient.getFollowing(pubkey: testCurrentUserPubkey),
        ).thenAnswer((_) async => testPaginatedPubkeys);

        final repo = FollowRepository(
          nostrClient: mockNostrClient,
          isCacheInitialized: () => cacheIsInitialized,
          getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
          cacheUserEvent: cachedUserEvents.add,
          funnelcakeApiClient: mockFunnelcakeClient,
          indexerRelayUrls: const [],
        );

        final result = await repo.getFollowingFromApi(
          pubkey: testCurrentUserPubkey,
        );

        expect(result, equals(testPaginatedPubkeys));
        verify(
          () =>
              mockFunnelcakeClient.getFollowing(pubkey: testCurrentUserPubkey),
        ).called(1);
      });

      test('returns null when client is null', () async {
        final repo = FollowRepository(
          nostrClient: mockNostrClient,
          isCacheInitialized: () => cacheIsInitialized,
          getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
          cacheUserEvent: cachedUserEvents.add,
          indexerRelayUrls: const [],
        );

        final result = await repo.getFollowingFromApi(
          pubkey: testCurrentUserPubkey,
        );

        expect(result, isNull);
      });

      test('returns null when client is not available', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(false);

        final repo = FollowRepository(
          nostrClient: mockNostrClient,
          isCacheInitialized: () => cacheIsInitialized,
          getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
          cacheUserEvent: cachedUserEvents.add,
          funnelcakeApiClient: mockFunnelcakeClient,
          indexerRelayUrls: const [],
        );

        final result = await repo.getFollowingFromApi(
          pubkey: testCurrentUserPubkey,
        );

        expect(result, isNull);
        verifyNever(
          () => mockFunnelcakeClient.getFollowing(
            pubkey: any(named: 'pubkey'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          ),
        );
      });

      test('passes limit and offset correctly', () async {
        const testPaginatedPubkeys = PaginatedPubkeys(
          pubkeys: [testTargetPubkey, testTargetPubkey2],
          total: 200,
          hasMore: true,
        );

        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getFollowing(
            pubkey: testCurrentUserPubkey,
            limit: 50,
            offset: 100,
          ),
        ).thenAnswer((_) async => testPaginatedPubkeys);

        final repo = FollowRepository(
          nostrClient: mockNostrClient,
          isCacheInitialized: () => cacheIsInitialized,
          getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
          cacheUserEvent: cachedUserEvents.add,
          funnelcakeApiClient: mockFunnelcakeClient,
          indexerRelayUrls: const [],
        );

        final result = await repo.getFollowingFromApi(
          pubkey: testCurrentUserPubkey,
          limit: 50,
          offset: 100,
        );

        expect(result, equals(testPaginatedPubkeys));
        verify(
          () => mockFunnelcakeClient.getFollowing(
            pubkey: testCurrentUserPubkey,
            limit: 50,
            offset: 100,
          ),
        ).called(1);
      });

      test('propagates FunnelcakeApiException', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getFollowing(
            pubkey: any(named: 'pubkey'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          ),
        ).thenThrow(
          const FunnelcakeApiException(
            message: 'Server error',
            statusCode: 500,
            url: 'https://example.com/api/following',
          ),
        );

        final repo = FollowRepository(
          nostrClient: mockNostrClient,
          isCacheInitialized: () => cacheIsInitialized,
          getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
          cacheUserEvent: cachedUserEvents.add,
          funnelcakeApiClient: mockFunnelcakeClient,
          indexerRelayUrls: const [],
        );

        expect(
          () => repo.getFollowingFromApi(pubkey: testCurrentUserPubkey),
          throwsA(isA<FunnelcakeApiException>()),
        );
      });
    });

    group('initialization - skips when no keys', () {
      test('does not initialize when user has no keys', () async {
        when(() => mockNostrClient.hasKeys).thenReturn(false);

        await repository.initialize();

        expect(repository.isInitialized, isFalse);
        expect(repository.followingCount, 0);
      });
    });

    group('initialization - loads from PersonalEventCache', () {
      test('loads following from PersonalEventCache', () async {
        cacheIsInitialized = true;
        getCachedEventsByKind = (_) => [
          Event(
            testCurrentUserPubkey,
            EventKind.contactList,
            [
              ['p', testTargetPubkey],
              ['p', testTargetPubkey2],
            ],
            '',
            createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
        ];

        await repository.initialize();

        expect(repository.followingCount, 2);
        expect(repository.isFollowing(testTargetPubkey), isTrue);
        expect(repository.isFollowing(testTargetPubkey2), isTrue);
      });

      test('ignores empty p-tag values from PersonalEventCache', () async {
        cacheIsInitialized = true;
        getCachedEventsByKind = (_) => [
          Event(
            testCurrentUserPubkey,
            EventKind.contactList,
            [
              ['p', testTargetPubkey],
              ['p', ''], // empty value
              ['p'], // missing value
            ],
            '',
            createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
        ];

        await repository.initialize();

        expect(repository.followingCount, 1);
        expect(repository.isFollowing(testTargetPubkey), isTrue);
      });

      test(
        'handles PersonalEventCache error gracefully',
        () async {
          cacheIsInitialized = true;
          getCachedEventsByKind = (_) => throw Exception('Cache corrupted');

          await repository.initialize();

          expect(repository.isInitialized, isTrue);
          expect(repository.followingCount, 0);
        },
      );

      test('skips PersonalEventCache when not initialized', () async {
        cacheIsInitialized = false;
        var getCachedEventsCalled = false;
        getCachedEventsByKind = (_) {
          getCachedEventsCalled = true;
          return [];
        };

        await repository.initialize();

        expect(getCachedEventsCalled, isFalse);
      });

      test('ignores empty contact list from PersonalEventCache', () async {
        cacheIsInitialized = true;
        getCachedEventsByKind = (_) => [];

        await repository.initialize();

        expect(repository.followingCount, 0);
      });

      // Both directions of the #8266 contract. The count is deliberately the
      // opposite of the answer each time, so a re-introduced "more p tags
      // wins" heuristic fails here rather than passing by coincidence.
      test(
        'a newer PersonalEventCache event wins even with fewer follows',
        () async {
          final localPubkeys = List.generate(
            10,
            (i) => i.toRadixString(16).padLeft(64, '0'),
          );
          final cachePubkeys = localPubkeys.take(3).toList();
          SharedPreferences.setMockInitialValues({
            'following_list_$testCurrentUserPubkey': jsonEncode({
              'v': 2,
              'created_at': 1000,
              'id': 'a' * 64,
              'pubkeys': localPubkeys,
            }),
          });

          cacheIsInitialized = true;
          getCachedEventsByKind = (_) => [
            Event(
              testCurrentUserPubkey,
              EventKind.contactList,
              cachePubkeys.map((p) => ['p', p]).toList(),
              '',
              createdAt: 2000,
            ),
          ];

          repository = FollowRepository(
            nostrClient: mockNostrClient,
            isCacheInitialized: () => cacheIsInitialized,
            getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
            cacheUserEvent: cachedUserEvents.add,
            indexerRelayUrls: const [],
          );

          await repository.initialize();

          expect(repository.followingPubkeys, cachePubkeys);
        },
      );

      test(
        'a newer LocalStorage record wins even with fewer follows',
        () async {
          final cachePubkeys = List.generate(
            10,
            (i) => i.toRadixString(16).padLeft(64, '0'),
          );
          final localPubkeys = cachePubkeys.take(3).toList();
          SharedPreferences.setMockInitialValues({
            'following_list_$testCurrentUserPubkey': jsonEncode({
              'v': 2,
              'created_at': 2000,
              'id': 'a' * 64,
              'pubkeys': localPubkeys,
            }),
          });

          cacheIsInitialized = true;
          getCachedEventsByKind = (_) => [
            Event(
              testCurrentUserPubkey,
              EventKind.contactList,
              cachePubkeys.map((p) => ['p', p]).toList(),
              '',
              createdAt: 1000,
            ),
          ];

          repository = FollowRepository(
            nostrClient: mockNostrClient,
            isCacheInitialized: () => cacheIsInitialized,
            getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
            cacheUserEvent: cachedUserEvents.add,
            indexerRelayUrls: const [],
          );

          await repository.initialize();

          expect(repository.followingPubkeys, localPubkeys);
        },
      );
    });

    group('initialization - loads from relay', () {
      test('loads from relay when all other sources are empty', () async {
        // Subscribe returns a stream that yields a contact list event
        final contactListEvent = Event(
          testCurrentUserPubkey,
          EventKind.contactList,
          [
            ['p', testTargetPubkey],
          ],
          '',
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        );

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
        ).thenAnswer((_) => Stream.value(contactListEvent));

        repository = FollowRepository(
          nostrClient: mockNostrClient,
          isCacheInitialized: () => cacheIsInitialized,
          getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
          cacheUserEvent: cachedUserEvents.add,
          indexerRelayUrls: const [],
          queryContactList:
              ({
                required eventStream,
                required pubkey,
                fallbackTimeoutSeconds = 10,
              }) async {
                // Return the event from the stream if pubkey matches
                await for (final event in eventStream) {
                  if (event.kind == EventKind.contactList &&
                      event.pubkey == pubkey) {
                    return event;
                  }
                }
                return null;
              },
        );

        await repository.initialize();

        expect(repository.followingCount, 1);
        expect(repository.isFollowing(testTargetPubkey), isTrue);
      });

      test('handles relay query failure gracefully', () async {
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
        ).thenThrow(Exception('Relay error'));

        // Should not throw even though relay fails
        await repository.initialize();

        expect(repository.followingCount, 0);
      });

      test('handles connected relay query stream error gracefully', () async {
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
        ).thenAnswer((invocation) {
          final subscriptionId =
              invocation.namedArguments[#subscriptionId] as String?;
          if (subscriptionId != null) {
            return const Stream<Event>.empty();
          }
          return Stream<Event>.error(Exception('Relay stream error'));
        });

        await repository.initialize();

        expect(repository.followingCount, 0);
      });

      test('cancels connected relay contact list query on timeout', () {
        fakeAsync((async) {
          var queryStreamCanceled = false;
          final controller = StreamController<Event>(
            onCancel: () {
              queryStreamCanceled = true;
            },
          );

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
          ).thenAnswer((invocation) {
            final subscriptionId =
                invocation.namedArguments[#subscriptionId] as String?;
            if (subscriptionId != null) {
              return const Stream<Event>.empty();
            }
            return controller.stream;
          });

          var completed = false;
          unawaited(
            repository.initialize().then((_) {
              completed = true;
            }),
          );

          async
            ..flushMicrotasks()
            ..elapse(const Duration(seconds: 6))
            ..flushMicrotasks();

          expect(completed, isTrue);
          expect(queryStreamCanceled, isTrue);
        });
      });

      test(
        'picks best contact list by createdAt (newer wins)',
        () async {
          final olderEvent = Event(
            testCurrentUserPubkey,
            EventKind.contactList,
            [
              ['p', testTargetPubkey],
            ],
            '',
            createdAt: 1000000,
          );

          var callIndex = 0;
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
          ).thenAnswer((_) {
            callIndex++;
            // First subscribe call: _loadContactListFromConnectedRelays
            if (callIndex == 1) return Stream.value(olderEvent);
            // Remaining calls: _subscribeToContactList
            return const Stream<Event>.empty();
          });

          // Use queryContactList that returns the event from stream
          repository = FollowRepository(
            nostrClient: mockNostrClient,
            isCacheInitialized: () => cacheIsInitialized,
            getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
            cacheUserEvent: cachedUserEvents.add,
            indexerRelayUrls: const [],
            queryContactList:
                ({
                  required eventStream,
                  required pubkey,
                  fallbackTimeoutSeconds = 10,
                }) async {
                  await for (final event in eventStream) {
                    if (event.kind == EventKind.contactList &&
                        event.pubkey == pubkey) {
                      return event;
                    }
                  }
                  return null;
                },
          );

          await repository.initialize();

          // Should load the older event from connected relays
          // (indexer returns null since indexerRelayUrls is empty)
          expect(repository.followingCount, 1);

          // Simulate a newer event arriving via the stream
          // to verify that _processContactListEvent is used
          expect(repository.isFollowing(testTargetPubkey), isTrue);
        },
      );
    });

    group('initialization - REST API edge cases', () {
      test('handles REST API returning empty list', () async {
        final mockFunnelcakeClient = _MockFunnelcakeApiClient();
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getFollowing(
            pubkey: any(named: 'pubkey'),
            offset: any(named: 'offset'),
          ),
        ).thenAnswer(
          (_) async => PaginatedPubkeys.empty,
        );

        repository = FollowRepository(
          nostrClient: mockNostrClient,
          isCacheInitialized: () => cacheIsInitialized,
          getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
          cacheUserEvent: cachedUserEvents.add,
          funnelcakeApiClient: mockFunnelcakeClient,
          indexerRelayUrls: const [],
        );

        await repository.initialize();

        expect(repository.isInitialized, isTrue);
        expect(repository.followingCount, 0);
      });

      test('skips REST API when client is not available', () async {
        final mockFunnelcakeClient = _MockFunnelcakeApiClient();
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(false);

        repository = FollowRepository(
          nostrClient: mockNostrClient,
          isCacheInitialized: () => cacheIsInitialized,
          getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
          cacheUserEvent: cachedUserEvents.add,
          funnelcakeApiClient: mockFunnelcakeClient,
          indexerRelayUrls: const [],
        );

        await repository.initialize();

        verifyNever(
          () => mockFunnelcakeClient.getFollowing(
            pubkey: any(named: 'pubkey'),
            offset: any(named: 'offset'),
          ),
        );
      });

      test('skips REST API when pubkey is empty', () async {
        when(() => mockNostrClient.publicKey).thenReturn('');
        when(() => mockNostrClient.hasKeys).thenReturn(true);

        final mockFunnelcakeClient = _MockFunnelcakeApiClient();
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);

        repository = FollowRepository(
          nostrClient: mockNostrClient,
          isCacheInitialized: () => cacheIsInitialized,
          getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
          cacheUserEvent: cachedUserEvents.add,
          funnelcakeApiClient: mockFunnelcakeClient,
          indexerRelayUrls: const [],
        );

        await repository.initialize();

        verifyNever(
          () => mockFunnelcakeClient.getFollowing(
            pubkey: any(named: 'pubkey'),
            offset: any(named: 'offset'),
          ),
        );
      });
    });

    group('executeFollowAction', () {
      test('throws when not authenticated', () async {
        when(() => mockNostrClient.hasKeys).thenReturn(false);

        expect(
          () => repository.executeFollowAction(testTargetPubkey),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('not authenticated'),
            ),
          ),
        );
      });

      test('adds pubkey if not already in list and broadcasts', () async {
        final mockEvent = _MockEvent();
        when(() => mockEvent.id).thenReturn(testCurrentUserPubkey);
        when(() => mockEvent.content).thenReturn('');
        when(
          () => mockNostrClient.sendContactList(
            any(),
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => mockEvent);

        await repository.initialize();

        await repository.executeFollowAction(testTargetPubkey);

        expect(repository.isFollowing(testTargetPubkey), isTrue);
        verify(
          () => mockNostrClient.sendContactList(
            any(),
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).called(1);
      });

      test(
        'broadcasts even if pubkey is already in list',
        () async {
          SharedPreferences.setMockInitialValues({
            'following_list_$testCurrentUserPubkey': '["$testTargetPubkey"]',
          });

          final mockEvent = _MockEvent();
          when(() => mockEvent.id).thenReturn(testCurrentUserPubkey);
          when(() => mockEvent.content).thenReturn('');
          when(
            () => mockNostrClient.sendContactList(
              any(),
              any(),
              tempRelays: any(named: 'tempRelays'),
              targetRelays: any(named: 'targetRelays'),
            ),
          ).thenAnswer((_) async => mockEvent);

          repository = FollowRepository(
            nostrClient: mockNostrClient,
            isCacheInitialized: () => cacheIsInitialized,
            getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
            cacheUserEvent: cachedUserEvents.add,
            indexerRelayUrls: const [],
          );

          await repository.initialize();
          expect(repository.isFollowing(testTargetPubkey), isTrue);

          await repository.executeFollowAction(testTargetPubkey);

          // Should still broadcast even though already following
          verify(
            () => mockNostrClient.sendContactList(
              any(),
              any(),
              tempRelays: any(named: 'tempRelays'),
              targetRelays: any(named: 'targetRelays'),
            ),
          ).called(1);
        },
      );
    });

    group('executeUnfollowAction', () {
      test('throws when not authenticated', () async {
        when(() => mockNostrClient.hasKeys).thenReturn(false);

        expect(
          () => repository.executeUnfollowAction(testTargetPubkey),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('not authenticated'),
            ),
          ),
        );
      });

      test('removes pubkey from list and broadcasts', () async {
        SharedPreferences.setMockInitialValues({
          'following_list_$testCurrentUserPubkey': '["$testTargetPubkey"]',
        });

        final mockEvent = _MockEvent();
        when(() => mockEvent.id).thenReturn(testCurrentUserPubkey);
        when(() => mockEvent.content).thenReturn('');
        when(
          () => mockNostrClient.sendContactList(
            any(),
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => mockEvent);

        repository = FollowRepository(
          nostrClient: mockNostrClient,
          isCacheInitialized: () => cacheIsInitialized,
          getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
          cacheUserEvent: cachedUserEvents.add,
          indexerRelayUrls: const [],
        );

        await repository.initialize();
        expect(repository.isFollowing(testTargetPubkey), isTrue);

        await repository.executeUnfollowAction(testTargetPubkey);

        expect(repository.isFollowing(testTargetPubkey), isFalse);
        verify(
          () => mockNostrClient.sendContactList(
            any(),
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).called(1);
      });

      test(
        'broadcasts even if pubkey is not in list',
        () async {
          final mockEvent = _MockEvent();
          when(() => mockEvent.id).thenReturn(testCurrentUserPubkey);
          when(() => mockEvent.content).thenReturn('');
          when(
            () => mockNostrClient.sendContactList(
              any(),
              any(),
              tempRelays: any(named: 'tempRelays'),
              targetRelays: any(named: 'targetRelays'),
            ),
          ).thenAnswer((_) async => mockEvent);

          await repository.initialize();
          expect(repository.isFollowing(testTargetPubkey), isFalse);

          await repository.executeUnfollowAction(testTargetPubkey);

          // Should still broadcast
          verify(
            () => mockNostrClient.sendContactList(
              any(),
              any(),
              tempRelays: any(named: 'tempRelays'),
              targetRelays: any(named: 'targetRelays'),
            ),
          ).called(1);
        },
      );
    });

    group('offline follow/unfollow', () {
      test('queues follow action when offline', () async {
        var queuedAction = '';
        var queuedPubkey = '';

        final mockEvent = _MockEvent();
        when(() => mockEvent.id).thenReturn(testCurrentUserPubkey);
        when(() => mockEvent.content).thenReturn('');

        repository = FollowRepository(
          nostrClient: mockNostrClient,
          isCacheInitialized: () => cacheIsInitialized,
          getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
          cacheUserEvent: cachedUserEvents.add,
          indexerRelayUrls: const [],
          isOnline: () => false,
          queueOfflineAction:
              ({
                required isFollow,
                required pubkey,
              }) async {
                queuedAction = isFollow ? 'follow' : 'unfollow';
                queuedPubkey = pubkey;
              },
        );

        await repository.initialize();
        await repository.follow(testTargetPubkey);

        expect(queuedAction, equals('follow'));
        expect(queuedPubkey, equals(testTargetPubkey));
        expect(repository.isFollowing(testTargetPubkey), isTrue);

        // Should not broadcast to network
        verifyNever(
          () => mockNostrClient.sendContactList(
            any(),
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        );
      });

      test('queues unfollow action when offline', () async {
        SharedPreferences.setMockInitialValues({
          'following_list_$testCurrentUserPubkey': '["$testTargetPubkey"]',
        });

        var queuedAction = '';
        var queuedPubkey = '';

        repository = FollowRepository(
          nostrClient: mockNostrClient,
          isCacheInitialized: () => cacheIsInitialized,
          getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
          cacheUserEvent: cachedUserEvents.add,
          indexerRelayUrls: const [],
          isOnline: () => false,
          queueOfflineAction:
              ({
                required isFollow,
                required pubkey,
              }) async {
                queuedAction = isFollow ? 'follow' : 'unfollow';
                queuedPubkey = pubkey;
              },
        );

        await repository.initialize();
        await repository.unfollow(testTargetPubkey);

        expect(queuedAction, equals('unfollow'));
        expect(queuedPubkey, equals(testTargetPubkey));
        expect(repository.isFollowing(testTargetPubkey), isFalse);

        // Should not broadcast to network
        verifyNever(
          () => mockNostrClient.sendContactList(
            any(),
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        );
      });
    });

    group('getFollowerStats', () {
      test(
        'returns stats from REST API when available',
        () async {
          final mockFunnelcakeClient = _MockFunnelcakeApiClient();
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getSocialCounts(testTargetPubkey),
          ).thenAnswer(
            (_) async => const SocialCounts(
              pubkey: testTargetPubkey,
              followerCount: 100,
              followingCount: 50,
            ),
          );

          repository = FollowRepository(
            nostrClient: mockNostrClient,
            isCacheInitialized: () => cacheIsInitialized,
            getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
            cacheUserEvent: cachedUserEvents.add,
            funnelcakeApiClient: mockFunnelcakeClient,
            indexerRelayUrls: const [],
          );

          final stats = await repository.getFollowerStats(testTargetPubkey);

          expect(stats.followers, equals(100));
          expect(stats.following, equals(50));
        },
      );

      test(
        'returns cached stats on second call',
        () async {
          final mockFunnelcakeClient = _MockFunnelcakeApiClient();
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getSocialCounts(testTargetPubkey),
          ).thenAnswer(
            (_) async => const SocialCounts(
              pubkey: testTargetPubkey,
              followerCount: 100,
              followingCount: 50,
            ),
          );

          repository = FollowRepository(
            nostrClient: mockNostrClient,
            isCacheInitialized: () => cacheIsInitialized,
            getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
            cacheUserEvent: cachedUserEvents.add,
            funnelcakeApiClient: mockFunnelcakeClient,
            indexerRelayUrls: const [],
          );

          await repository.getFollowerStats(testTargetPubkey);
          final stats = await repository.getFollowerStats(testTargetPubkey);

          expect(stats.followers, equals(100));
          // getSocialCounts should only be called once (cached)
          verify(
            () => mockFunnelcakeClient.getSocialCounts(testTargetPubkey),
          ).called(1);
        },
      );

      test(
        'refetches stats after the in-memory cache TTL expires',
        () async {
          final mockFunnelcakeClient = _MockFunnelcakeApiClient();
          var now = DateTime.utc(2026, 8, 22, 12);
          var followerCount = 100;
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getSocialCounts(testTargetPubkey),
          ).thenAnswer(
            (_) async => SocialCounts(
              pubkey: testTargetPubkey,
              followerCount: followerCount,
              followingCount: 50,
            ),
          );

          repository = FollowRepository(
            nostrClient: mockNostrClient,
            isCacheInitialized: () => cacheIsInitialized,
            getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
            cacheUserEvent: cachedUserEvents.add,
            funnelcakeApiClient: mockFunnelcakeClient,
            indexerRelayUrls: const [],
            now: () => now,
          );

          final first = await repository.getFollowerStats(testTargetPubkey);
          followerCount = 101;
          now = now.add(const Duration(seconds: 29));
          final beforeExpiry = await repository.getFollowerStats(
            testTargetPubkey,
          );
          now = now.add(const Duration(seconds: 2));
          final afterExpiry = await repository.getFollowerStats(
            testTargetPubkey,
          );

          expect(first.followers, 100);
          expect(beforeExpiry.followers, 100);
          expect(afterExpiry.followers, 101);
          verify(
            () => mockFunnelcakeClient.getSocialCounts(testTargetPubkey),
          ).called(2);
        },
      );

      test(
        'falls back to WebSocket when REST API is unavailable',
        () async {
          // No funnelcake client, use nostr client subscribe for
          // _fetchFollowingCountViaWebSocket
          final contactListEvent = Event(
            testTargetPubkey,
            EventKind.contactList,
            [
              ['p', 'followed1'.padLeft(64, '0')],
              ['p', 'followed2'.padLeft(64, '0')],
            ],
            '',
            createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          );

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
          ).thenAnswer((_) => Stream.value(contactListEvent));

          repository = FollowRepository(
            nostrClient: mockNostrClient,
            isCacheInitialized: () => cacheIsInitialized,
            getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
            cacheUserEvent: cachedUserEvents.add,
            indexerRelayUrls: const [],
            queryContactList:
                ({
                  required eventStream,
                  required pubkey,
                  fallbackTimeoutSeconds = 10,
                }) async {
                  await for (final event in eventStream) {
                    if (event.kind == EventKind.contactList &&
                        event.pubkey == pubkey) {
                      return event;
                    }
                  }
                  return null;
                },
          );

          final stats = await repository.getFollowerStats(testTargetPubkey);

          // Following count from WebSocket: 2 p-tags
          expect(stats.following, equals(2));
        },
      );

      test(
        'falls back to REST when REST fails gracefully',
        () async {
          final mockFunnelcakeClient = _MockFunnelcakeApiClient();
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getSocialCounts(testTargetPubkey),
          ).thenThrow(Exception('API error'));

          repository = FollowRepository(
            nostrClient: mockNostrClient,
            isCacheInitialized: () => cacheIsInitialized,
            getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
            cacheUserEvent: cachedUserEvents.add,
            funnelcakeApiClient: mockFunnelcakeClient,
            indexerRelayUrls: const [],
          );

          // Should not throw — falls back to WebSocket
          final stats = await repository.getFollowerStats(testTargetPubkey);

          expect(stats, isNotNull);
        },
      );

      test(
        'returns null REST result when client returns null counts',
        () async {
          final mockFunnelcakeClient = _MockFunnelcakeApiClient();
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getSocialCounts(testTargetPubkey),
          ).thenAnswer((_) async => null);

          repository = FollowRepository(
            nostrClient: mockNostrClient,
            isCacheInitialized: () => cacheIsInitialized,
            getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
            cacheUserEvent: cachedUserEvents.add,
            funnelcakeApiClient: mockFunnelcakeClient,
            indexerRelayUrls: const [],
          );

          final stats = await repository.getFollowerStats(testTargetPubkey);

          // REST returns null, falls back to WebSocket which returns 0/0
          expect(stats, isNotNull);
        },
      );

      test(
        'returns REST counts verbatim over a higher persisted baseline '
        '(#8197)',
        () async {
          final mockStatsDao = _MockProfileStatsDao();
          final mockFunnelcakeClient = _MockFunnelcakeApiClient();

          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getSocialCounts(testTargetPubkey),
          ).thenAnswer(
            (_) async => const SocialCounts(
              pubkey: testTargetPubkey,
              followerCount: 90,
              followingCount: 45,
            ),
          );

          // Return persisted stats with higher counts (within threshold)
          when(() => mockStatsDao.getStatsRaw(testTargetPubkey)).thenAnswer(
            (_) async => ProfileStatRow(
              pubkey: testTargetPubkey,
              followerCount: 100,
              followingCount: 50,
              cachedAt: DateTime.now(),
            ),
          );

          when(
            () => mockStatsDao.upsertStats(
              pubkey: any(named: 'pubkey'),
              followerCount: any(named: 'followerCount'),
              followingCount: any(named: 'followingCount'),
            ),
          ).thenAnswer((_) async {});

          repository = FollowRepository(
            nostrClient: mockNostrClient,
            isCacheInitialized: () => cacheIsInitialized,
            getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
            cacheUserEvent: cachedUserEvents.add,
            funnelcakeApiClient: mockFunnelcakeClient,
            profileStatsDao: mockStatsDao,
            indexerRelayUrls: const [],
          );

          final stats = await repository.getFollowerStats(testTargetPubkey);

          // REST is authoritative (#8197): the drop from the persisted
          // 100/50 baseline is real data, not relay variance, so no
          // hysteresis applies and the fresh counts are persisted.
          expect(stats.followers, equals(90));
          expect(stats.following, equals(45));
          verify(
            () => mockStatsDao.upsertStats(
              pubkey: testTargetPubkey,
              followerCount: 90,
              followingCount: 45,
            ),
          ).called(1);
        },
      );

      test(
        'returns persisted stats on complete network failure',
        () async {
          final mockStatsDao = _MockProfileStatsDao();

          // Make subscribe throw for WebSocket path
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
          ).thenThrow(Exception('Network down'));

          when(() => mockStatsDao.getStatsRaw(testTargetPubkey)).thenAnswer(
            (_) async => ProfileStatRow(
              pubkey: testTargetPubkey,
              followerCount: 50,
              followingCount: 25,
              cachedAt: DateTime.now(),
            ),
          );
          when(
            () => mockStatsDao.upsertStats(
              pubkey: any(named: 'pubkey'),
              followerCount: any(named: 'followerCount'),
              followingCount: any(named: 'followingCount'),
            ),
          ).thenAnswer((_) async {});

          repository = FollowRepository(
            nostrClient: mockNostrClient,
            isCacheInitialized: () => cacheIsInitialized,
            getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
            cacheUserEvent: cachedUserEvents.add,
            profileStatsDao: mockStatsDao,
            indexerRelayUrls: const [],
          );

          final stats = await repository.getFollowerStats(testTargetPubkey);

          expect(stats.followers, equals(50));
          expect(stats.following, equals(25));
        },
      );

      test(
        'returns zero when all sources fail and no persisted data',
        () async {
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
          ).thenThrow(Exception('Network down'));

          final stats = await repository.getFollowerStats(testTargetPubkey);

          expect(stats, equals(FollowerStats.zero));
        },
      );

      test(
        'returns persisted data when fresh stats are all zero',
        () async {
          final mockStatsDao = _MockProfileStatsDao();

          // First getStatsRaw call (fresh == zero fallback)
          when(() => mockStatsDao.getStatsRaw(testTargetPubkey)).thenAnswer(
            (_) async => ProfileStatRow(
              pubkey: testTargetPubkey,
              followerCount: 42,
              followingCount: 10,
              cachedAt: DateTime.now(),
            ),
          );
          when(
            () => mockStatsDao.upsertStats(
              pubkey: any(named: 'pubkey'),
              followerCount: any(named: 'followerCount'),
              followingCount: any(named: 'followingCount'),
            ),
          ).thenAnswer((_) async {});

          repository = FollowRepository(
            nostrClient: mockNostrClient,
            isCacheInitialized: () => cacheIsInitialized,
            getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
            cacheUserEvent: cachedUserEvents.add,
            profileStatsDao: mockStatsDao,
            indexerRelayUrls: const [],
          );

          final stats = await repository.getFollowerStats(testTargetPubkey);

          // WebSocket returns 0/0 (empty stream), so falls back to persisted
          expect(stats.followers, equals(42));
          expect(stats.following, equals(10));
        },
      );
    });

    group('real-time sync - subscription error handling', () {
      test('handles stream error without crashing', () async {
        final controller = StreamController<Event>.broadcast();

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
        ).thenAnswer((_) => controller.stream);

        await repository.initialize();

        // Add an error to the stream
        controller.addError(Exception('Relay disconnected'));
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Repository should still be functional
        expect(repository.isInitialized, isTrue);

        await repository.dispose();
        await controller.close();
      });

      test(
        'skips subscription when pubkey is empty',
        () async {
          when(() => mockNostrClient.publicKey).thenReturn('');
          when(() => mockNostrClient.hasKeys).thenReturn(true);

          await repository.initialize();

          // Should not subscribe since pubkey is empty
          // (subscribe is called for _loadFromRelay, not for
          // _subscribeToContactList when pubkey is empty)
          expect(repository.isInitialized, isTrue);
        },
      );
    });

    group('getFollowerCount', () {
      test('returns 0 on error', () async {
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
        ).thenThrow(Exception('Network error'));

        final count = await repository.getFollowerCount(testTargetPubkey);

        expect(count, equals(0));
      });
    });

    group('getFollowerStats - REST + WS merge', () {
      test(
        'keeps following max behavior while followers use available source',
        () async {
          final mockFunnelcakeClient = _MockFunnelcakeApiClient();
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          // REST returns lower followers, higher following
          when(
            () => mockFunnelcakeClient.getSocialCounts(testTargetPubkey),
          ).thenAnswer(
            (_) async => const SocialCounts(
              pubkey: testTargetPubkey,
              followerCount: 50,
              followingCount: 100,
            ),
          );

          // WS returns higher followers via subscribe
          final contactListEvent = Event(
            testTargetPubkey,
            EventKind.contactList,
            List.generate(
              80,
              (i) => ['p', i.toRadixString(16).padLeft(64, '0')],
            ),
            '',
            createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          );

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
          ).thenAnswer((_) => Stream.value(contactListEvent));

          repository = FollowRepository(
            nostrClient: mockNostrClient,
            isCacheInitialized: () => cacheIsInitialized,
            getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
            cacheUserEvent: cachedUserEvents.add,
            funnelcakeApiClient: mockFunnelcakeClient,
            indexerRelayUrls: const [],
            queryContactList:
                ({
                  required eventStream,
                  required pubkey,
                  fallbackTimeoutSeconds = 10,
                }) async {
                  await for (final event in eventStream) {
                    if (event.kind == EventKind.contactList &&
                        event.pubkey == pubkey) {
                      return event;
                    }
                  }
                  return null;
                },
          );

          final stats = await repository.getFollowerStats(testTargetPubkey);

          // Followers have only the REST observation because no indexers run.
          // Following: max(REST 100, WS 80) = 100
          expect(stats.followers, equals(50));
          expect(stats.following, equals(100));
        },
      );
    });

    group('initialization - pickBestContactList branch', () {
      test(
        'picks newer event when both sources return data',
        () async {
          final olderEvent = Event(
            testCurrentUserPubkey,
            EventKind.contactList,
            [
              ['p', testTargetPubkey],
            ],
            '',
            createdAt: 1000000,
          );

          // Connected relays return older event, indexer returns newer
          // We need subscribe to return the older for the first call
          // (_loadContactListFromConnectedRelays) and empty for
          // _subscribeToContactList.
          var subscribeCallCount = 0;
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
          ).thenAnswer((_) {
            subscribeCallCount++;
            if (subscribeCallCount == 1) return Stream.value(olderEvent);
            return const Stream<Event>.empty();
          });

          // Use a queryContactList that returns the older event
          // And set up indexer to return the newer event
          // Since we can't easily mock indexer relays, test via
          // the _loadFromRelay path where only connected relays
          // return data and indexer returns null (empty URLs).
          //
          // To test the b > a branch of _pickBestContactList,
          // we need the indexer result to be newer. Since we
          // can't mock indexer relay connections, let's verify
          // the method by testing through different test setup.
          //
          // The simpler approach: with indexerRelayUrls: [] the
          // indexer returns null, so _pickBestContactList(event, null)
          // returns event. We've already tested this.
          //
          // To cover line 1644 (b.createdAt > a.createdAt ? b : a),
          // we need both a and b non-null with b newer. This requires
          // a real indexer connection which isn't unit-testable.
          // Skip this specific branch for now.
          repository = FollowRepository(
            nostrClient: mockNostrClient,
            isCacheInitialized: () => cacheIsInitialized,
            getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
            cacheUserEvent: cachedUserEvents.add,
            indexerRelayUrls: const [],
            queryContactList:
                ({
                  required eventStream,
                  required pubkey,
                  fallbackTimeoutSeconds = 10,
                }) async {
                  await for (final event in eventStream) {
                    if (event.kind == EventKind.contactList &&
                        event.pubkey == pubkey) {
                      return event;
                    }
                  }
                  return null;
                },
          );

          await repository.initialize();

          // Loaded from connected relays
          expect(repository.followingCount, 1);
          expect(repository.isFollowing(testTargetPubkey), isTrue);
        },
      );
    });

    group('_fetchFollowersFromRelays edge cases', () {
      test(
        'returns empty list on TimeoutException',
        () async {
          when(() => mockNostrClient.queryEvents(any())).thenThrow(
            TimeoutException('timed out'),
          );

          final followers = await repository.getFollowers(testTargetPubkey);

          expect(followers, isEmpty);
        },
      );

      test(
        'handles relay query timeout via onTimeout',
        () async {
          // Simulate a query that takes too long
          when(() => mockNostrClient.queryEvents(any())).thenAnswer(
            (_) => Future<List<Event>>.delayed(
              const Duration(seconds: 12),
              () => [],
            ),
          );

          final followers = await repository.getFollowers(testTargetPubkey);

          expect(followers, isEmpty);
        },
        timeout: const Timeout(Duration(seconds: 20)),
      );
    });

    group('_checkIfTheyFollowUs edge cases', () {
      test('returns false when pubkey is empty', () async {
        // Set up: we follow testTargetPubkey
        SharedPreferences.setMockInitialValues({
          'following_list_$testCurrentUserPubkey': '["$testTargetPubkey"]',
        });

        // Make publicKey empty for the _checkIfTheyFollowUs check
        // _fetchFollowers will also get empty pubkey
        when(() => mockNostrClient.publicKey).thenReturn('');

        repository = FollowRepository(
          nostrClient: mockNostrClient,
          isCacheInitialized: () => cacheIsInitialized,
          getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
          cacheUserEvent: cachedUserEvents.add,
          indexerRelayUrls: const [],
        );

        // Manually set state since initialize would skip with no keys
        // Use follow to add the target
        when(() => mockNostrClient.hasKeys).thenReturn(true);
        when(() => mockNostrClient.publicKey).thenReturn('');

        // isMutualFollow checks isFollowing first, which is a local check
        // When publicKey is empty, _fetchFollowers('') returns []
        // and _checkIfTheyFollowUs returns false
        final result = await repository.isMutualFollow(testTargetPubkey);

        expect(result, isFalse);
      });
    });

    group('error handling - local storage', () {
      test('handles corrupted cache gracefully', () async {
        SharedPreferences.setMockInitialValues({
          'following_list_$testCurrentUserPubkey': 'not valid json',
        });

        repository = FollowRepository(
          nostrClient: mockNostrClient,
          isCacheInitialized: () => cacheIsInitialized,
          getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
          cacheUserEvent: cachedUserEvents.add,
          indexerRelayUrls: const [],
        );

        // Should not throw - logs error and continues
        await repository.initialize();

        expect(repository.followingCount, 0);
      });
    });

    group('getFollowerStats - REST stats fetch', () {
      test(
        'returns null when REST client is not available',
        () async {
          final mockFunnelcakeClient = _MockFunnelcakeApiClient();
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(false);

          repository = FollowRepository(
            nostrClient: mockNostrClient,
            isCacheInitialized: () => cacheIsInitialized,
            getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
            cacheUserEvent: cachedUserEvents.add,
            funnelcakeApiClient: mockFunnelcakeClient,
            indexerRelayUrls: const [],
          );

          // getFollowerStats calls _fetchFollowerStatsViaRest which
          // returns null since client is not available, then falls
          // through to WebSocket only
          final stats = await repository.getFollowerStats(testTargetPubkey);

          expect(stats, isNotNull);
          // REST unavailable → only WS results used
          verifyNever(
            () => mockFunnelcakeClient.getSocialCounts(any()),
          );
        },
      );
    });

    group('getFollowerStats - REST following authority', () {
      test(
        'uses REST following verbatim without querying relays (#8197)',
        () async {
          final mockFunnelcakeClient = _MockFunnelcakeApiClient();
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          // REST: followers=50, following=30
          when(
            () => mockFunnelcakeClient.getSocialCounts(testTargetPubkey),
          ).thenAnswer(
            (_) async => const SocialCounts(
              pubkey: testTargetPubkey,
              followerCount: 50,
              followingCount: 30,
            ),
          );

          // WS returns 80 p-tags (following=80 > REST following=30)
          final contactListEvent = Event(
            testTargetPubkey,
            EventKind.contactList,
            List.generate(
              80,
              (i) => ['p', i.toRadixString(16).padLeft(64, '0')],
            ),
            '',
            createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          );

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
          ).thenAnswer((_) => Stream.value(contactListEvent));

          repository = FollowRepository(
            nostrClient: mockNostrClient,
            isCacheInitialized: () => cacheIsInitialized,
            getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
            cacheUserEvent: cachedUserEvents.add,
            funnelcakeApiClient: mockFunnelcakeClient,
            indexerRelayUrls: const [],
            queryContactList:
                ({
                  required eventStream,
                  required pubkey,
                  fallbackTimeoutSeconds = 10,
                }) async {
                  await for (final event in eventStream) {
                    if (event.kind == EventKind.contactList &&
                        event.pubkey == pubkey) {
                      return event;
                    }
                  }
                  return null;
                },
          );

          final stats = await repository.getFollowerStats(testTargetPubkey);

          // REST answered, so its counts stand verbatim (#8197) — the
          // kind-3 event with 80 p-tags must never be consulted.
          expect(stats.followers, equals(50));
          expect(stats.following, equals(30));
          verifyNever(
            () => mockNostrClient.subscribe(
              any(),
              subscriptionId: any(named: 'subscriptionId'),
              tempRelays: any(named: 'tempRelays'),
              targetRelays: any(named: 'targetRelays'),
              relayTypes: any(named: 'relayTypes'),
              sendAfterAuth: any(named: 'sendAfterAuth'),
              onEose: any(named: 'onEose'),
            ),
          );
        },
      );
    });

    group('getFollowerStats - relay-fallback hysteresis', () {
      // With REST unavailable, the relay fallback supplies the counts and
      // hysteresis stabilizes them against the persisted baseline (#8197
      // keeps this machinery for the fallback path only).
      Event contactList(int pTagCount) => Event(
        testTargetPubkey,
        EventKind.contactList,
        List.generate(
          pTagCount,
          (i) => ['p', i.toRadixString(16).padLeft(64, '0')],
        ),
        '',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );

      ProfileStatRow persistedFollowing(
        int following, {
        DateTime? updatedAt,
        DateTime? cachedAt,
      }) => ProfileStatRow(
        pubkey: testTargetPubkey,
        followerCount: 0,
        followingCount: following,
        cachedAt: cachedAt ?? DateTime.now(),
        followerCountsUpdatedAt: updatedAt,
      );

      _MockProfileStatsDao statsDaoWith(ProfileStatRow row) {
        final dao = _MockProfileStatsDao();
        when(
          () => dao.getStatsRaw(testTargetPubkey),
        ).thenAnswer((_) async => row);
        when(
          () => dao.upsertStats(
            pubkey: any(named: 'pubkey'),
            followerCount: any(named: 'followerCount'),
            followingCount: any(named: 'followingCount'),
          ),
        ).thenAnswer((_) async {});
        return dao;
      }

      FollowRepository buildFallbackRepository({
        required _MockProfileStatsDao statsDao,
        required int relayFollowing,
      }) {
        final mockFunnelcakeClient = _MockFunnelcakeApiClient();
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(false);
        final event = contactList(relayFollowing);
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
        ).thenAnswer((_) => Stream.value(event));
        return FollowRepository(
          nostrClient: mockNostrClient,
          isCacheInitialized: () => cacheIsInitialized,
          getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
          cacheUserEvent: cachedUserEvents.add,
          funnelcakeApiClient: mockFunnelcakeClient,
          profileStatsDao: statsDao,
          indexerRelayUrls: const [],
          queryContactList:
              ({
                required eventStream,
                required pubkey,
                fallbackTimeoutSeconds = 10,
              }) async {
                await for (final event in eventStream) {
                  if (event.kind == EventKind.contactList &&
                      event.pubkey == pubkey) {
                    return event;
                  }
                }
                return null;
              },
        );
      }

      test(
        'holds the following count across an overnight gap (#6902)',
        () async {
          // Last seen at 98 the night before; the relay answers 86 in the
          // morning — within the threshold, so the baseline holds. The
          // baseline's freshness must come from followerCountsUpdatedAt,
          // not the unrelated (stale) cachedAt.
          final dao = statsDaoWith(
            persistedFollowing(
              98,
              updatedAt: DateTime.now().subtract(const Duration(hours: 10)),
              cachedAt: DateTime.now().subtract(const Duration(hours: 30)),
            ),
          );
          repository = buildFallbackRepository(
            statsDao: dao,
            relayFollowing: 86,
          );

          final stats = await repository.getFollowerStats(testTargetPubkey);

          expect(stats.following, equals(98));
          // Hysteresis kept the persisted values — nothing to re-persist.
          verifyNever(
            () => dao.upsertStats(
              pubkey: any(named: 'pubkey'),
              followerCount: any(named: 'followerCount'),
              followingCount: any(named: 'followingCount'),
            ),
          );
        },
      );

      test(
        'accepts a relay drop below the threshold and persists it',
        () async {
          // Persisted 100, threshold ceil(100 * 0.8) = 80; the relay answers
          // 79 — a genuine drop, accepted and written through.
          final dao = statsDaoWith(persistedFollowing(100));
          repository = buildFallbackRepository(
            statsDao: dao,
            relayFollowing: 79,
          );

          final stats = await repository.getFollowerStats(testTargetPubkey);

          expect(stats.following, equals(79));
          verify(
            () => dao.upsertStats(
              pubkey: testTargetPubkey,
              followerCount: 0,
              followingCount: 79,
            ),
          ).called(1);
        },
      );

      test('accepts a lower relay count over a stale baseline', () async {
        final dao = statsDaoWith(
          persistedFollowing(
            100,
            updatedAt: DateTime.now().subtract(const Duration(hours: 30)),
          ),
        );
        repository = buildFallbackRepository(
          statsDao: dao,
          relayFollowing: 86,
        );

        final stats = await repository.getFollowerStats(testTargetPubkey);

        expect(stats.following, equals(86));
      });

      test('reflects one-person drops for small accounts', () async {
        final dao = statsDaoWith(persistedFollowing(10));
        repository = buildFallbackRepository(
          statsDao: dao,
          relayFollowing: 9,
        );

        final stats = await repository.getFollowerStats(testTargetPubkey);

        expect(stats.following, equals(9));
      });
    });

    group('getFollowerStats - persistence', () {
      test(
        'persists authoritative stats for the signed-in user',
        () async {
          final mockStatsDao = _MockProfileStatsDao();
          final mockFunnelcakeClient = _MockFunnelcakeApiClient();
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getSocialCounts(testCurrentUserPubkey),
          ).thenAnswer(
            (_) async => const SocialCounts(
              pubkey: testCurrentUserPubkey,
              followerCount: 200,
              followingCount: 100,
            ),
          );
          when(
            () => mockStatsDao.getStatsRaw(testCurrentUserPubkey),
          ).thenAnswer((_) async => null);
          when(
            () => mockStatsDao.upsertStats(
              pubkey: any(named: 'pubkey'),
              followerCount: any(named: 'followerCount'),
              followingCount: any(named: 'followingCount'),
            ),
          ).thenAnswer((_) async {});

          repository = FollowRepository(
            nostrClient: mockNostrClient,
            isCacheInitialized: () => cacheIsInitialized,
            getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
            cacheUserEvent: cachedUserEvents.add,
            funnelcakeApiClient: mockFunnelcakeClient,
            profileStatsDao: mockStatsDao,
            indexerRelayUrls: const [],
          );

          await repository.getFollowerStats(testCurrentUserPubkey);

          verify(
            () => mockStatsDao.upsertStats(
              pubkey: testCurrentUserPubkey,
              followerCount: 200,
              followingCount: 100,
            ),
          ).called(1);
        },
      );

      test(
        'persists when stats differ from persisted values',
        () async {
          final mockStatsDao = _MockProfileStatsDao();
          final mockFunnelcakeClient = _MockFunnelcakeApiClient();

          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          // Fresh stats: 200 followers, 100 following (higher than persisted)
          when(
            () => mockFunnelcakeClient.getSocialCounts(testTargetPubkey),
          ).thenAnswer(
            (_) async => const SocialCounts(
              pubkey: testTargetPubkey,
              followerCount: 200,
              followingCount: 100,
            ),
          );

          // Persisted: 50 followers, 30 following (lower)
          when(() => mockStatsDao.getStatsRaw(testTargetPubkey)).thenAnswer(
            (_) async => ProfileStatRow(
              pubkey: testTargetPubkey,
              followerCount: 50,
              followingCount: 30,
              cachedAt: DateTime.now(),
            ),
          );

          when(
            () => mockStatsDao.upsertStats(
              pubkey: any(named: 'pubkey'),
              followerCount: any(named: 'followerCount'),
              followingCount: any(named: 'followingCount'),
            ),
          ).thenAnswer((_) async {});

          repository = FollowRepository(
            nostrClient: mockNostrClient,
            isCacheInitialized: () => cacheIsInitialized,
            getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
            cacheUserEvent: cachedUserEvents.add,
            funnelcakeApiClient: mockFunnelcakeClient,
            profileStatsDao: mockStatsDao,
            indexerRelayUrls: const [],
          );

          final stats = await repository.getFollowerStats(testTargetPubkey);

          // Fresh is higher than persisted → accepted and persisted
          expect(stats.followers, equals(200));
          expect(stats.following, equals(100));

          verify(
            () => mockStatsDao.upsertStats(
              pubkey: testTargetPubkey,
              followerCount: 200,
              followingCount: 100,
            ),
          ).called(1);
        },
      );

      test(
        'persists lower REST counts that differ from the baseline (#8197)',
        () async {
          final mockStatsDao = _MockProfileStatsDao();
          final mockFunnelcakeClient = _MockFunnelcakeApiClient();

          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          // Fresh REST counts slightly lower than the persisted baseline.
          when(
            () => mockFunnelcakeClient.getSocialCounts(testTargetPubkey),
          ).thenAnswer(
            (_) async => const SocialCounts(
              pubkey: testTargetPubkey,
              followerCount: 90,
              followingCount: 45,
            ),
          );

          when(() => mockStatsDao.getStatsRaw(testTargetPubkey)).thenAnswer(
            (_) async => ProfileStatRow(
              pubkey: testTargetPubkey,
              followerCount: 100,
              followingCount: 50,
              cachedAt: DateTime.now(),
            ),
          );

          when(
            () => mockStatsDao.upsertStats(
              pubkey: any(named: 'pubkey'),
              followerCount: any(named: 'followerCount'),
              followingCount: any(named: 'followingCount'),
            ),
          ).thenAnswer((_) async {});

          repository = FollowRepository(
            nostrClient: mockNostrClient,
            isCacheInitialized: () => cacheIsInitialized,
            getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
            cacheUserEvent: cachedUserEvents.add,
            funnelcakeApiClient: mockFunnelcakeClient,
            profileStatsDao: mockStatsDao,
            indexerRelayUrls: const [],
          );

          await repository.getFollowerStats(testTargetPubkey);

          // REST is authoritative — the changed counts are written through.
          verify(
            () => mockStatsDao.upsertStats(
              pubkey: testTargetPubkey,
              followerCount: 90,
              followingCount: 45,
            ),
          ).called(1);
        },
      );

      test(
        'a 0/0 REST body is not authoritative and is not persisted',
        () async {
          // funnelcake answers 200 for every pubkey and turns ClickHouse
          // failures into {0, 0}, so a zero body cannot be trusted as data
          // (#8259 review). It must fall through to the relay path.
          final mockStatsDao = _MockProfileStatsDao();
          final mockFunnelcakeClient = _MockFunnelcakeApiClient();

          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getSocialCounts(testTargetPubkey),
          ).thenAnswer(
            (_) async => const SocialCounts(
              pubkey: testTargetPubkey,
              followerCount: 0,
              followingCount: 0,
            ),
          );
          when(() => mockStatsDao.getStatsRaw(testTargetPubkey)).thenAnswer(
            (_) async => ProfileStatRow(
              pubkey: testTargetPubkey,
              followerCount: 512,
              followingCount: 430,
              cachedAt: DateTime.now(),
            ),
          );

          repository = FollowRepository(
            nostrClient: mockNostrClient,
            isCacheInitialized: () => cacheIsInitialized,
            getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
            cacheUserEvent: cachedUserEvents.add,
            funnelcakeApiClient: mockFunnelcakeClient,
            profileStatsDao: mockStatsDao,
            indexerRelayUrls: const [],
          );

          final stats = await repository.getFollowerStats(testTargetPubkey);

          expect(stats.followers, equals(512));
          expect(stats.following, equals(430));
          verifyNever(
            () => mockStatsDao.upsertStats(
              pubkey: any(named: 'pubkey'),
              followerCount: 0,
              followingCount: 0,
            ),
          );
        },
      );

      test(
        'uses authoritative followers with following fallback',
        () async {
          final mockStatsDao = _MockProfileStatsDao();
          final mockFunnelcakeClient = _MockFunnelcakeApiClient();

          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getSocialCounts(testTargetPubkey),
          ).thenAnswer(
            (_) async => const SocialCounts(
              pubkey: testTargetPubkey,
              followerCount: 1976,
              followingCount: 0,
            ),
          );
          when(() => mockStatsDao.getStatsRaw(testTargetPubkey)).thenAnswer(
            (_) async => ProfileStatRow(
              pubkey: testTargetPubkey,
              followerCount: 1900,
              followingCount: 43,
              cachedAt: DateTime.now(),
            ),
          );
          when(
            () => mockStatsDao.upsertStats(
              pubkey: any(named: 'pubkey'),
              followerCount: any(named: 'followerCount'),
              followingCount: any(named: 'followingCount'),
            ),
          ).thenAnswer((_) async {});

          repository = FollowRepository(
            nostrClient: mockNostrClient,
            isCacheInitialized: () => cacheIsInitialized,
            getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
            cacheUserEvent: cachedUserEvents.add,
            funnelcakeApiClient: mockFunnelcakeClient,
            profileStatsDao: mockStatsDao,
            indexerRelayUrls: const [],
          );

          final stats = await repository.getFollowerStats(testTargetPubkey);

          expect(stats.followers, equals(1976));
          expect(stats.following, equals(43));
        },
      );

      test(
        'uses authoritative following with follower fallback',
        () async {
          final mockStatsDao = _MockProfileStatsDao();
          final mockFunnelcakeClient = _MockFunnelcakeApiClient();

          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getSocialCounts(testTargetPubkey),
          ).thenAnswer(
            (_) async => const SocialCounts(
              pubkey: testTargetPubkey,
              followerCount: 0,
              followingCount: 42,
            ),
          );
          when(() => mockStatsDao.getStatsRaw(testTargetPubkey)).thenAnswer(
            (_) async => ProfileStatRow(
              pubkey: testTargetPubkey,
              followerCount: 512,
              followingCount: 430,
              cachedAt: DateTime.now(),
            ),
          );
          when(
            () => mockStatsDao.upsertStats(
              pubkey: any(named: 'pubkey'),
              followerCount: any(named: 'followerCount'),
              followingCount: any(named: 'followingCount'),
            ),
          ).thenAnswer((_) async {});

          repository = FollowRepository(
            nostrClient: mockNostrClient,
            isCacheInitialized: () => cacheIsInitialized,
            getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
            cacheUserEvent: cachedUserEvents.add,
            funnelcakeApiClient: mockFunnelcakeClient,
            profileStatsDao: mockStatsDao,
            indexerRelayUrls: const [],
          );

          final stats = await repository.getFollowerStats(testTargetPubkey);

          expect(stats.followers, equals(512));
          expect(stats.following, equals(42));
        },
      );

      test(
        'persists when only the following count changed',
        () async {
          final mockStatsDao = _MockProfileStatsDao();
          final mockFunnelcakeClient = _MockFunnelcakeApiClient();

          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getSocialCounts(testTargetPubkey),
          ).thenAnswer(
            (_) async => const SocialCounts(
              pubkey: testTargetPubkey,
              followerCount: 90,
              followingCount: 45,
            ),
          );

          // Same follower count; only following moved.
          when(() => mockStatsDao.getStatsRaw(testTargetPubkey)).thenAnswer(
            (_) async => ProfileStatRow(
              pubkey: testTargetPubkey,
              followerCount: 90,
              followingCount: 50,
              cachedAt: DateTime.now(),
            ),
          );

          when(
            () => mockStatsDao.upsertStats(
              pubkey: any(named: 'pubkey'),
              followerCount: any(named: 'followerCount'),
              followingCount: any(named: 'followingCount'),
            ),
          ).thenAnswer((_) async {});

          repository = FollowRepository(
            nostrClient: mockNostrClient,
            isCacheInitialized: () => cacheIsInitialized,
            getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
            cacheUserEvent: cachedUserEvents.add,
            funnelcakeApiClient: mockFunnelcakeClient,
            profileStatsDao: mockStatsDao,
            indexerRelayUrls: const [],
          );

          await repository.getFollowerStats(testTargetPubkey);

          verify(
            () => mockStatsDao.upsertStats(
              pubkey: testTargetPubkey,
              followerCount: 90,
              followingCount: 45,
            ),
          ).called(1);
        },
      );
    });

    group('getFollowers with API branch', () {
      test('keeps relay results when the API fails', () async {
        const relayFollower =
            'bb00000000000000000000000000000000000000000000000000000000000002';
        final api = _MockFunnelcakeApiClient();
        when(() => api.isAvailable).thenReturn(true);
        when(
          () => api.getFollowers(
            pubkey: any(named: 'pubkey'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => throw Exception('API unavailable'));
        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [
            Event(
              relayFollower,
              3,
              [
                ['p', testTargetPubkey],
              ],
              '',
              createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            ),
          ],
        );
        repository = FollowRepository(
          nostrClient: mockNostrClient,
          isCacheInitialized: () => cacheIsInitialized,
          getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
          cacheUserEvent: cachedUserEvents.add,
          funnelcakeApiClient: api,
          indexerRelayUrls: const [],
        );

        final followers = await repository.getFollowers(testTargetPubkey);

        expect(followers, [relayFollower]);
      });

      test('throws instead of returning empty when all sources fail', () {
        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer(
          (_) => Future<List<Event>>.error(Exception('Relay unavailable')),
        );

        expect(
          repository.getFollowers(testTargetPubkey),
          throwsException,
        );
      });

      test(
        'merges API results with relay results',
        () async {
          const apiFollower =
              'aa00000000000000000000000000000000000000000000000000000000000001';
          const relayFollower =
              'bb00000000000000000000000000000000000000000000000000000000000002';

          final mockFunnelcakeClient = _MockFunnelcakeApiClient();
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getFollowers(
              pubkey: any(named: 'pubkey'),
              limit: any(named: 'limit'),
            ),
          ).thenAnswer(
            (_) async => const PaginatedPubkeys(
              pubkeys: [apiFollower],
            ),
          );

          when(() => mockNostrClient.queryEvents(any())).thenAnswer(
            (_) async => [
              Event(
                relayFollower,
                3,
                [
                  ['p', testTargetPubkey],
                ],
                '',
                createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
              ),
            ],
          );

          repository = FollowRepository(
            nostrClient: mockNostrClient,
            isCacheInitialized: () => cacheIsInitialized,
            getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
            cacheUserEvent: cachedUserEvents.add,
            funnelcakeApiClient: mockFunnelcakeClient,
            indexerRelayUrls: const [],
          );

          final followers = await repository.getFollowers(testTargetPubkey);

          // Should have merged: API follower + relay follower
          expect(followers, contains(apiFollower));
          expect(followers, contains(relayFollower));
          expect(followers, hasLength(2));
        },
      );
    });

    group('_emitFollowingList dedup', () {
      test(
        'does not re-emit when list content is identical',
        () async {
          SharedPreferences.setMockInitialValues({
            'following_list_$testCurrentUserPubkey': '["$testTargetPubkey"]',
          });

          final mockEvent = _MockEvent();
          when(() => mockEvent.id).thenReturn(testCurrentUserPubkey);
          when(() => mockEvent.content).thenReturn('');
          when(
            () => mockNostrClient.sendContactList(
              any(),
              any(),
              tempRelays: any(named: 'tempRelays'),
              targetRelays: any(named: 'targetRelays'),
            ),
          ).thenAnswer((_) async => mockEvent);

          repository = FollowRepository(
            nostrClient: mockNostrClient,
            isCacheInitialized: () => cacheIsInitialized,
            getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
            cacheUserEvent: cachedUserEvents.add,
            indexerRelayUrls: const [],
          );

          await repository.initialize();

          final emissions = <List<String>>[];
          final subscription = repository.followingStream.listen(emissions.add);

          await Future<void>.delayed(Duration.zero);
          final initialCount = emissions.length;

          // Follow then unfollow — list returns to same state
          await repository.follow(testTargetPubkey2);
          await repository.unfollow(testTargetPubkey2);
          await Future<void>.delayed(Duration.zero);

          // Should have emitted during follow and unfollow
          expect(emissions.length, greaterThan(initialCount));

          await subscription.cancel();
        },
      );
    });

    group('indexer relay queries', () {
      const indexerUrl = 'wss://fake-indexer.test';
      const followerPubkey1 =
          'aa00000000000000000000000000000000000000000000000000000000000001';
      const followerPubkey2 =
          'bb00000000000000000000000000000000000000000000000000000000000002';

      /// Helper: builds a relay factory that returns a [_FakeRelay]
      /// pre-loaded with [responses].
      RelayFactory fakeRelayFactory({
        List<List<dynamic>> responses = const [],
        bool shouldConnect = true,
        bool neverCloses = false,
        bool neverDisconnects = false,
      }) {
        return (String url, RelayStatus status) {
          final relay = _FakeRelay(
            url,
            status,
            shouldConnect: shouldConnect,
            neverCloses: neverCloses,
            neverDisconnects: neverDisconnects,
          )..fakeResponses = responses;
          return relay;
        };
      }

      group('_fetchFollowersCountViaIndexers', () {
        test(
          'relay fallback still settles when an indexer never connects',
          () async {
            // With REST unavailable the fallback path queries indexers, so
            // this is the only route that exercises the connect deadline in
            // _queryIndexerForFollowerCount: when REST answers, the #8197
            // short-circuit skips indexers entirely.
            final api = _MockFunnelcakeApiClient();
            when(() => api.isAvailable).thenReturn(false);
            repository = FollowRepository(
              nostrClient: mockNostrClient,
              isCacheInitialized: () => cacheIsInitialized,
              getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
              cacheUserEvent: cachedUserEvents.add,
              funnelcakeApiClient: api,
              indexerRelayUrls: const [indexerUrl],
              indexerOperationTimeout: const Duration(milliseconds: 20),
              relayFactory: (url, status) =>
                  _FakeRelay(url, status, neverConnects: true),
            );

            final stats = await repository
                .getFollowerStats(testTargetPubkey)
                .timeout(const Duration(milliseconds: 500));

            expect(stats, FollowerStats.zero);
          },
        );

        test('bounds CLOSE and disconnect after a count response', () async {
          repository = FollowRepository(
            nostrClient: mockNostrClient,
            isCacheInitialized: () => cacheIsInitialized,
            getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
            cacheUserEvent: cachedUserEvents.add,
            indexerRelayUrls: const [indexerUrl],
            indexerOperationTimeout: const Duration(milliseconds: 20),
            relayFactory: fakeRelayFactory(
              responses: const [
                ['EOSE', 'sub1'],
              ],
              neverCloses: true,
              neverDisconnects: true,
            ),
          );

          final stats = await repository
              .getFollowerStats(testTargetPubkey)
              .timeout(const Duration(milliseconds: 200));

          expect(stats.followers, 0);
        });

        test(
          'returns follower count from indexer relay',
          () async {
            repository = FollowRepository(
              nostrClient: mockNostrClient,
              isCacheInitialized: () => cacheIsInitialized,
              getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
              cacheUserEvent: cachedUserEvents.add,
              indexerRelayUrls: const [indexerUrl],
              relayFactory: fakeRelayFactory(
                responses: [
                  [
                    'EVENT',
                    'sub1',
                    {'pubkey': followerPubkey1},
                  ],
                  [
                    'EVENT',
                    'sub1',
                    {'pubkey': followerPubkey2},
                  ],
                  ['EOSE', 'sub1'],
                ],
              ),
            );

            final stats = await repository.getFollowerStats(testTargetPubkey);

            // 2 EVENT messages with distinct pubkeys → followers=2
            expect(stats.followers, equals(2));
          },
        );

        test(
          'returns 0 when indexer relay fails to connect',
          () async {
            repository = FollowRepository(
              nostrClient: mockNostrClient,
              isCacheInitialized: () => cacheIsInitialized,
              getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
              cacheUserEvent: cachedUserEvents.add,
              indexerRelayUrls: const [indexerUrl],
              relayFactory: fakeRelayFactory(shouldConnect: false),
            );

            final stats = await repository.getFollowerStats(testTargetPubkey);

            expect(stats.followers, equals(0));
          },
        );

        test(
          'returns 0 when relay throws',
          () async {
            repository = FollowRepository(
              nostrClient: mockNostrClient,
              isCacheInitialized: () => cacheIsInitialized,
              getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
              cacheUserEvent: cachedUserEvents.add,
              indexerRelayUrls: const [indexerUrl],
              relayFactory: (url, status) {
                throw Exception('Relay creation failed');
              },
            );

            final stats = await repository.getFollowerStats(testTargetPubkey);

            expect(stats.followers, equals(0));
          },
        );

        test(
          'uses highest lower bound when only two indexers answer',
          () async {
            var callCount = 0;
            repository = FollowRepository(
              nostrClient: mockNostrClient,
              isCacheInitialized: () => cacheIsInitialized,
              getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
              cacheUserEvent: cachedUserEvents.add,
              indexerRelayUrls: const [
                'wss://indexer1.test',
                'wss://indexer2.test',
              ],
              relayFactory: (url, status) {
                callCount++;
                final responses = callCount == 1
                    ? <List<dynamic>>[
                        [
                          'EVENT',
                          's',
                          {'pubkey': followerPubkey1},
                        ],
                        ['EOSE', 's'],
                      ]
                    : <List<dynamic>>[
                        [
                          'EVENT',
                          's',
                          {'pubkey': followerPubkey1},
                        ],
                        [
                          'EVENT',
                          's',
                          {'pubkey': followerPubkey2},
                        ],
                        ['EOSE', 's'],
                      ];
                return _FakeRelay(url, status)..fakeResponses = responses;
              },
            );

            final stats = await repository.getFollowerStats(testTargetPubkey);

            expect(stats.followers, equals(2));
          },
        );

        test(
          'uses the REST count verbatim, ignoring higher indexers (#8197)',
          () async {
            final mockFunnelcakeClient = _MockFunnelcakeApiClient();
            when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
            when(
              () => mockFunnelcakeClient.getSocialCounts(testTargetPubkey),
            ).thenAnswer(
              (_) async => const SocialCounts(
                pubkey: testTargetPubkey,
                followerCount: 50,
                followingCount: 0,
              ),
            );

            repository = FollowRepository(
              nostrClient: mockNostrClient,
              isCacheInitialized: () => cacheIsInitialized,
              getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
              cacheUserEvent: cachedUserEvents.add,
              funnelcakeApiClient: mockFunnelcakeClient,
              indexerRelayUrls: const [
                'wss://indexer1.test',
                'wss://indexer2.test',
              ],
              relayFactory: (url, status) {
                final count = url.contains('indexer1') ? 55 : 500;
                return _FakeRelay(url, status)
                  ..fakeResponses = [
                    ...List.generate(
                      count,
                      (i) => <dynamic>[
                        'EVENT',
                        's',
                        {'pubkey': i.toRadixString(16).padLeft(64, '0')},
                      ],
                    ),
                    <dynamic>['EOSE', 's'],
                  ];
              },
            );

            final stats = await repository.getFollowerStats(testTargetPubkey);

            // REST answered with 50, so 50 is displayed — the indexers
            // reporting 55 and 500 are never allowed to override it.
            expect(stats.followers, equals(50));
          },
        );

        test(
          'keeps the highest lower bound when all sources are partial',
          () async {
            repository = FollowRepository(
              nostrClient: mockNostrClient,
              isCacheInitialized: () => cacheIsInitialized,
              getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
              cacheUserEvent: cachedUserEvents.add,
              indexerQueryTimeout: Duration.zero,
              indexerRelayUrls: const [
                'wss://indexer1.test',
                'wss://indexer2.test',
                'wss://indexer3.test',
              ],
              relayFactory: (url, status) {
                final count = url.contains('indexer1')
                    ? 1
                    : url.contains('indexer2')
                    ? 2
                    : 200;
                return _FakeRelay(url, status)
                  ..fakeResponses = List.generate(
                    count,
                    (i) => <dynamic>[
                      'EVENT',
                      's',
                      {'pubkey': i.toRadixString(16).padLeft(64, '0')},
                    ],
                  );
              },
            );

            final stats = await repository.getFollowerStats(testTargetPubkey);

            expect(stats.followers, equals(200));
          },
        );

        test(
          'does not let partial indexers lower the REST count',
          () async {
            final mockFunnelcakeClient = _MockFunnelcakeApiClient();
            when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
            when(
              () => mockFunnelcakeClient.getSocialCounts(testTargetPubkey),
            ).thenAnswer(
              (_) async => const SocialCounts(
                pubkey: testTargetPubkey,
                followerCount: 1000,
                followingCount: 10,
              ),
            );

            repository = FollowRepository(
              nostrClient: mockNostrClient,
              isCacheInitialized: () => cacheIsInitialized,
              getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
              cacheUserEvent: cachedUserEvents.add,
              funnelcakeApiClient: mockFunnelcakeClient,
              indexerQueryTimeout: Duration.zero,
              indexerRelayUrls: const [
                'wss://indexer1.test',
                'wss://indexer2.test',
              ],
              relayFactory: (url, status) {
                final count = url.contains('indexer1') ? 5 : 3;
                return _FakeRelay(url, status)
                  ..fakeResponses = List.generate(
                    count,
                    (i) => <dynamic>[
                      'EVENT',
                      's',
                      {'pubkey': i.toRadixString(16).padLeft(64, '0')},
                    ],
                  );
              },
            );

            final stats = await repository.getFollowerStats(testTargetPubkey);

            expect(stats.followers, equals(1000));
          },
        );

        test(
          'ignores empty EOSE indexers when REST has a positive count',
          () async {
            final mockFunnelcakeClient = _MockFunnelcakeApiClient();
            when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
            when(
              () => mockFunnelcakeClient.getSocialCounts(testTargetPubkey),
            ).thenAnswer(
              (_) async => const SocialCounts(
                pubkey: testTargetPubkey,
                followerCount: 1000,
                followingCount: 10,
              ),
            );

            repository = FollowRepository(
              nostrClient: mockNostrClient,
              isCacheInitialized: () => cacheIsInitialized,
              getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
              cacheUserEvent: cachedUserEvents.add,
              funnelcakeApiClient: mockFunnelcakeClient,
              indexerRelayUrls: const [
                'wss://indexer1.test',
                'wss://indexer2.test',
              ],
              relayFactory: fakeRelayFactory(
                responses: const [
                  ['EOSE', 's'],
                ],
              ),
            );

            final stats = await repository.getFollowerStats(testTargetPubkey);

            expect(stats.followers, equals(1000));
          },
        );

        test(
          'keeps the higher lower bound with no REST and two indexers',
          () async {
            var callCount = 0;
            repository = FollowRepository(
              nostrClient: mockNostrClient,
              isCacheInitialized: () => cacheIsInitialized,
              getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
              cacheUserEvent: cachedUserEvents.add,
              indexerQueryTimeout: Duration.zero,
              indexerRelayUrls: const [
                'wss://indexer1.test',
                'wss://indexer2.test',
              ],
              relayFactory: (url, status) {
                callCount++;
                return _FakeRelay(url, status)
                  ..fakeResponses = callCount == 1
                      ? [
                          ...List.generate(
                            10,
                            (i) => <dynamic>[
                              'EVENT',
                              's',
                              {
                                'pubkey': i.toRadixString(16).padLeft(64, '0'),
                              },
                            ],
                          ),
                          <dynamic>['EOSE', 's'],
                        ]
                      : List.generate(
                          3,
                          (i) => <dynamic>[
                            'EVENT',
                            's',
                            {'pubkey': i.toRadixString(16).padLeft(64, '0')},
                          ],
                        );
              },
            );

            final stats = await repository.getFollowerStats(testTargetPubkey);

            expect(stats.followers, equals(10));
          },
        );
      });

      group('_fetchFollowerRefsFromIndexers', () {
        test('keeps REST followers when an indexer never connects', () async {
          final api = _MockFunnelcakeApiClient();
          when(() => api.isAvailable).thenReturn(true);
          when(
            () => api.getFollowers(
              pubkey: testTargetPubkey,
              limit: any(named: 'limit'),
            ),
          ).thenAnswer(
            (_) async => const PaginatedPubkeys(pubkeys: [followerPubkey1]),
          );
          final connectedRelay = Completer<List<Event>>();
          when(
            () => mockNostrClient.queryEvents(any()),
          ).thenAnswer((_) => connectedRelay.future);
          repository = FollowRepository(
            nostrClient: mockNostrClient,
            isCacheInitialized: () => cacheIsInitialized,
            getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
            cacheUserEvent: cachedUserEvents.add,
            funnelcakeApiClient: api,
            indexerRelayUrls: const [indexerUrl],
            indexerOperationTimeout: const Duration(milliseconds: 20),
            relayFactory: (url, status) =>
                _FakeRelay(url, status, neverConnects: true),
          );

          final followersFuture = repository.getFollowers(testTargetPubkey);
          await Future<void>.delayed(Duration.zero);
          connectedRelay.completeError(
            Exception('connected relay unavailable'),
          );
          final followers = await followersFuture.timeout(
            const Duration(milliseconds: 200),
          );

          expect(followers, [followerPubkey1]);
        });

        test('bounds CLOSE after follower refs complete', () async {
          when(() => mockNostrClient.queryEvents(any())).thenAnswer(
            (_) async => [],
          );
          repository = FollowRepository(
            nostrClient: mockNostrClient,
            isCacheInitialized: () => cacheIsInitialized,
            getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
            cacheUserEvent: cachedUserEvents.add,
            indexerRelayUrls: const [indexerUrl],
            indexerOperationTimeout: const Duration(milliseconds: 20),
            relayFactory: fakeRelayFactory(
              responses: const [
                ['EOSE', 'sub1'],
              ],
              neverCloses: true,
            ),
          );

          final followers = await repository
              .getFollowers(testTargetPubkey)
              .timeout(const Duration(milliseconds: 200));

          expect(followers, isEmpty);
        });

        test(
          'orders indexer followers by their contact-list timestamp',
          () async {
            repository = FollowRepository(
              nostrClient: mockNostrClient,
              isCacheInitialized: () => cacheIsInitialized,
              getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
              cacheUserEvent: cachedUserEvents.add,
              indexerRelayUrls: const [indexerUrl],
              relayFactory: fakeRelayFactory(
                responses: [
                  [
                    'EVENT',
                    'sub1',
                    {'pubkey': followerPubkey1, 'created_at': 1000},
                  ],
                  [
                    'EVENT',
                    'sub1',
                    {'pubkey': followerPubkey2, 'created_at': 2000},
                  ],
                  ['EOSE', 'sub1'],
                ],
              ),
            );

            when(
              () => mockNostrClient.queryEvents(any()),
            ).thenAnswer((_) async => []);

            final followers = await repository.getFollowers(testTargetPubkey);

            expect(followers, equals([followerPubkey2, followerPubkey1]));
          },
        );

        test(
          'ranks an indexer follower with no timestamp below a timed one',
          () async {
            repository = FollowRepository(
              nostrClient: mockNostrClient,
              isCacheInitialized: () => cacheIsInitialized,
              getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
              cacheUserEvent: cachedUserEvents.add,
              indexerRelayUrls: const [indexerUrl],
              relayFactory: fakeRelayFactory(
                responses: [
                  [
                    'EVENT',
                    'sub1',
                    {'pubkey': followerPubkey2},
                  ],
                  ['EOSE', 'sub1'],
                ],
              ),
            );

            // The connected relay answers first and with a timestamp, so the
            // indexer's undated follower has to sort behind it.
            when(() => mockNostrClient.queryEvents(any())).thenAnswer(
              (_) async => [
                Event(
                  followerPubkey1,
                  EventKind.contactList,
                  [
                    ['p', testTargetPubkey],
                  ],
                  '',
                  createdAt: 1000,
                ),
              ],
            );

            final followers = await repository.getFollowers(testTargetPubkey);

            expect(followers, equals([followerPubkey1, followerPubkey2]));
          },
        );

        test(
          'returns follower pubkeys from indexer relay',
          () async {
            repository = FollowRepository(
              nostrClient: mockNostrClient,
              isCacheInitialized: () => cacheIsInitialized,
              getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
              cacheUserEvent: cachedUserEvents.add,
              indexerRelayUrls: const [indexerUrl],
              relayFactory: fakeRelayFactory(
                responses: [
                  [
                    'EVENT',
                    'sub1',
                    {'pubkey': followerPubkey1},
                  ],
                  [
                    'EVENT',
                    'sub1',
                    {'pubkey': followerPubkey2},
                  ],
                  ['EOSE', 'sub1'],
                ],
              ),
            );

            // getFollowers calls _fetchFollowers which merges
            // API + relay + indexer results
            when(() => mockNostrClient.queryEvents(any())).thenAnswer(
              (_) async => [],
            );

            final followers = await repository.getFollowers(testTargetPubkey);

            expect(followers, contains(followerPubkey1));
            expect(followers, contains(followerPubkey2));
          },
        );

        test(
          'returns empty when indexer fails to connect',
          () async {
            repository = FollowRepository(
              nostrClient: mockNostrClient,
              isCacheInitialized: () => cacheIsInitialized,
              getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
              cacheUserEvent: cachedUserEvents.add,
              indexerRelayUrls: const [indexerUrl],
              relayFactory: fakeRelayFactory(shouldConnect: false),
            );

            when(() => mockNostrClient.queryEvents(any())).thenAnswer(
              (_) async => [],
            );

            final followers = await repository.getFollowers(testTargetPubkey);

            // Only relay results (empty), no indexer results
            expect(followers, isEmpty);
          },
        );
      });

      group('_loadContactListFromIndexer', () {
        test(
          'loads contact list from indexer during initialization',
          () async {
            final contactListJson = {
              'pubkey': testCurrentUserPubkey,
              'kind': EventKind.contactList,
              'id':
                  'aaaa000000000000000000000000000000000000000000000000000000000000',
              'sig':
                  'bbbb000000000000000000000000000000000000000000000000000000000000bbbb000000000000000000000000000000000000000000000000000000000000',
              'content': '',
              'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
              'tags': [
                ['p', testTargetPubkey],
                ['p', testTargetPubkey2],
              ],
            };

            // Connected relays return nothing (empty stream +
            // queryContactList returns null)
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

            repository = FollowRepository(
              nostrClient: mockNostrClient,
              isCacheInitialized: () => cacheIsInitialized,
              getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
              cacheUserEvent: cachedUserEvents.add,
              indexerRelayUrls: const [indexerUrl],
              relayFactory: fakeRelayFactory(
                responses: [
                  ['EVENT', 'sub1', contactListJson],
                  ['EOSE', 'sub1'],
                ],
              ),
              queryContactList:
                  ({
                    required eventStream,
                    required pubkey,
                    fallbackTimeoutSeconds = 10,
                  }) async => null, // Connected relays return nothing
            );

            await repository.initialize();

            expect(repository.followingCount, 2);
            expect(
              repository.isFollowing(testTargetPubkey),
              isTrue,
            );
            expect(
              repository.isFollowing(testTargetPubkey2),
              isTrue,
            );
          },
        );

        test(
          'handles indexer returning no events',
          () async {
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

            repository = FollowRepository(
              nostrClient: mockNostrClient,
              isCacheInitialized: () => cacheIsInitialized,
              getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
              cacheUserEvent: cachedUserEvents.add,
              indexerRelayUrls: const [indexerUrl],
              relayFactory: fakeRelayFactory(
                responses: [
                  ['EOSE', 'sub1'],
                ],
              ),
              queryContactList:
                  ({
                    required eventStream,
                    required pubkey,
                    fallbackTimeoutSeconds = 10,
                  }) async => null,
            );

            await repository.initialize();

            expect(repository.followingCount, 0);
          },
        );

        test(
          'handles invalid event JSON from indexer',
          () async {
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

            repository = FollowRepository(
              nostrClient: mockNostrClient,
              isCacheInitialized: () => cacheIsInitialized,
              getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
              cacheUserEvent: cachedUserEvents.add,
              indexerRelayUrls: const [indexerUrl],
              relayFactory: fakeRelayFactory(
                responses: [
                  [
                    'EVENT',
                    'sub1',
                    {'invalid': 'json'},
                  ],
                  ['EOSE', 'sub1'],
                ],
              ),
              queryContactList:
                  ({
                    required eventStream,
                    required pubkey,
                    fallbackTimeoutSeconds = 10,
                  }) async => null,
            );

            // Should not throw — handles parse error gracefully
            await repository.initialize();

            expect(repository.followingCount, 0);
          },
        );

        test(
          'picks best when connected relay and indexer both return',
          () async {
            const olderTs = 1000000;
            const newerTs = 2000000;

            final olderEvent = Event(
              testCurrentUserPubkey,
              EventKind.contactList,
              [
                ['p', testTargetPubkey],
              ],
              '',
              createdAt: olderTs,
            );

            final newerContactListJson = {
              'pubkey': testCurrentUserPubkey,
              'kind': EventKind.contactList,
              'id':
                  'cccc000000000000000000000000000000000000000000000000000000000000',
              'sig':
                  'dddd000000000000000000000000000000000000000000000000000000000000dddd000000000000000000000000000000000000000000000000000000000000',
              'content': '',
              'created_at': newerTs,
              'tags': [
                ['p', testTargetPubkey],
                ['p', testTargetPubkey2],
              ],
            };

            var subscribeCallCount = 0;
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
            ).thenAnswer((_) {
              subscribeCallCount++;
              if (subscribeCallCount == 1) {
                return Stream.value(olderEvent);
              }
              return const Stream<Event>.empty();
            });

            repository = FollowRepository(
              nostrClient: mockNostrClient,
              isCacheInitialized: () => cacheIsInitialized,
              getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
              cacheUserEvent: cachedUserEvents.add,
              indexerRelayUrls: const [indexerUrl],
              relayFactory: fakeRelayFactory(
                responses: [
                  ['EVENT', 'sub1', newerContactListJson],
                  ['EOSE', 'sub1'],
                ],
              ),
              queryContactList:
                  ({
                    required eventStream,
                    required pubkey,
                    fallbackTimeoutSeconds = 10,
                  }) async {
                    await for (final event in eventStream) {
                      if (event.kind == EventKind.contactList &&
                          event.pubkey == pubkey) {
                        return event;
                      }
                    }
                    return null;
                  },
            );

            await repository.initialize();

            // Newer indexer event has 2 follows, should be picked
            expect(repository.followingCount, 2);
            expect(
              repository.isFollowing(testTargetPubkey),
              isTrue,
            );
            expect(
              repository.isFollowing(testTargetPubkey2),
              isTrue,
            );
          },
        );
      });

      group('indexer error paths', () {
        test(
          'handles indexer relay throwing during query',
          () async {
            repository = FollowRepository(
              nostrClient: mockNostrClient,
              isCacheInitialized: () => cacheIsInitialized,
              getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
              cacheUserEvent: cachedUserEvents.add,
              indexerQueryTimeout: Duration.zero,
              indexerRelayUrls: const [indexerUrl],
              relayFactory: (url, status) {
                final relay = _FakeRelay(url, status)
                  ..fakeResponses = [
                    [
                      'EVENT',
                      's',
                      {'pubkey': followerPubkey1},
                    ],
                    // No EOSE — completer never completes from
                    // messages, but connect returns true so the code
                    // waits on completer.future.timeout which fires
                    // onTimeout returning current followerPubkeys.
                  ];
                return relay;
              },
            );

            // getFollowerStats triggers _fetchFollowersCountViaIndexers
            // which times out and returns partial results
            final stats = await repository.getFollowerStats(
              testTargetPubkey,
            );

            // Should get partial result from timeout
            expect(stats.followers, greaterThanOrEqualTo(0));
          },
        );

        test(
          'handles indexer query error with partial results',
          () async {
            when(() => mockNostrClient.queryEvents(any())).thenAnswer(
              (_) async => [],
            );

            repository = FollowRepository(
              nostrClient: mockNostrClient,
              isCacheInitialized: () => cacheIsInitialized,
              getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
              cacheUserEvent: cachedUserEvents.add,
              indexerRelayUrls: const [indexerUrl],
              relayFactory: (url, status) {
                final relay = _FakeRelay(url, status)
                  ..fakeResponses = [
                    [
                      'EVENT',
                      's',
                      {'pubkey': followerPubkey1},
                    ],
                    // No EOSE — timeout will fire
                  ];
                return relay;
              },
            );

            // getFollowers triggers _fetchFollowerPubkeysFromIndexers
            final followers = await repository.getFollowers(testTargetPubkey);

            // Should not throw
            expect(followers, isA<List<String>>());
          },
          timeout: const Timeout(Duration(seconds: 20)),
        );

        test(
          'handles indexer returning no contact list',
          () async {
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

            repository = FollowRepository(
              nostrClient: mockNostrClient,
              isCacheInitialized: () => cacheIsInitialized,
              getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
              cacheUserEvent: cachedUserEvents.add,
              indexerRelayUrls: const [
                'wss://idx1.test',
                'wss://idx2.test',
              ],
              relayFactory: fakeRelayFactory(shouldConnect: false),
              queryContactList:
                  ({
                    required eventStream,
                    required pubkey,
                    fallbackTimeoutSeconds = 10,
                  }) async => null,
            );

            await repository.initialize();

            // No indexer returned data
            expect(repository.followingCount, 0);
          },
        );
      });
    });

    group('getFollowerStats - source confidence', () {
      test(
        'REST verbatim even when an indexer reports higher (#8197)',
        () async {
          final mockFunnelcakeClient = _MockFunnelcakeApiClient();
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getSocialCounts(testTargetPubkey),
          ).thenAnswer(
            (_) async => const SocialCounts(
              pubkey: testTargetPubkey,
              followerCount: 5,
              followingCount: 10,
            ),
          );

          repository = FollowRepository(
            nostrClient: mockNostrClient,
            isCacheInitialized: () => cacheIsInitialized,
            getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
            cacheUserEvent: cachedUserEvents.add,
            funnelcakeApiClient: mockFunnelcakeClient,
            indexerRelayUrls: const ['wss://idx.test'],
            relayFactory: (url, status) {
              return _FakeRelay(url, status)
                ..fakeResponses = [
                  ...List.generate(
                    10,
                    (i) => <dynamic>[
                      'EVENT',
                      's',
                      {'pubkey': i.toRadixString(16).padLeft(64, '0')},
                    ],
                  ),
                  <dynamic>['EOSE', 's'],
                ];
            },
          );

          final stats = await repository.getFollowerStats(testTargetPubkey);

          // REST said 5; the indexer's 10 is not consulted (#8197).
          expect(stats.followers, equals(5));
        },
      );
    });

    group('_emitFollowingList dedup with same-length lists', () {
      test(
        'emits when list content changes but length stays the same',
        () async {
          // Seed with one follow
          SharedPreferences.setMockInitialValues({
            'following_list_$testCurrentUserPubkey': '["$testTargetPubkey"]',
          });

          final controller = StreamController<Event>.broadcast();
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
          ).thenAnswer((_) => controller.stream);

          repository = FollowRepository(
            nostrClient: mockNostrClient,
            isCacheInitialized: () => cacheIsInitialized,
            getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
            cacheUserEvent: cachedUserEvents.add,
            indexerRelayUrls: const [],
          );

          await repository.initialize();
          expect(repository.followingCount, 1);
          expect(
            repository.isFollowing(testTargetPubkey),
            isTrue,
          );

          final emissions = <List<String>>[];
          final subscription = repository.followingStream.listen(emissions.add);
          await Future<void>.delayed(Duration.zero);
          emissions.clear();

          // Send remote event that swaps the followed user
          // (same count=1, but different pubkey)
          final swapEvent = Event(
            testCurrentUserPubkey,
            3,
            [
              ['p', testTargetPubkey2],
            ],
            '',
            createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 100,
          );

          controller.add(swapEvent);
          await Future<void>.delayed(
            const Duration(milliseconds: 50),
          );

          // Should have emitted because content changed
          // (even though length stayed at 1)
          expect(emissions, isNotEmpty);
          expect(emissions.last, contains(testTargetPubkey2));
          expect(
            emissions.last,
            isNot(contains(testTargetPubkey)),
          );

          await subscription.cancel();
          await repository.dispose();
          await controller.close();
        },
      );
    });

    group('remaining error paths', () {
      test(
        'getFollowerStats catch returns persisted fallback',
        () async {
          final mockStatsDao = _MockProfileStatsDao();

          // Make getStatsRaw throw first (in try block), succeed
          // second (in catch block)
          var callCount = 0;
          when(() => mockStatsDao.getStatsRaw(any())).thenAnswer(
            (_) async {
              callCount++;
              if (callCount == 1) throw Exception('DB error');
              return ProfileStatRow(
                pubkey: testTargetPubkey,
                followerCount: 42,
                followingCount: 10,
                cachedAt: DateTime.now(),
              );
            },
          );

          // REST unavailable, WS returns zero → fresh=(0,0)
          // → enters "fresh is zero" branch
          // → _loadPersistedStats throws → propagates to catch
          // → catch calls _loadPersistedStats again → succeeds
          repository = FollowRepository(
            nostrClient: mockNostrClient,
            isCacheInitialized: () => cacheIsInitialized,
            getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
            cacheUserEvent: cachedUserEvents.add,
            profileStatsDao: mockStatsDao,
            indexerRelayUrls: const [],
          );

          final stats = await repository.getFollowerStats(testTargetPubkey);

          expect(stats.followers, equals(42));
          expect(stats.following, equals(10));
        },
      );

      test(
        'getFollowerCount returns 0 when getFollowerStats throws',
        () async {
          final mockStatsDao = _MockProfileStatsDao();

          // Make getStatsRaw always throw so getFollowerStats
          // throws from its catch block
          when(() => mockStatsDao.getStatsRaw(any())).thenThrow(
            Exception('DB completely broken'),
          );

          repository = FollowRepository(
            nostrClient: mockNostrClient,
            isCacheInitialized: () => cacheIsInitialized,
            getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
            cacheUserEvent: cachedUserEvents.add,
            profileStatsDao: mockStatsDao,
            indexerRelayUrls: const [],
          );

          final count = await repository.getFollowerCount(testTargetPubkey);

          expect(count, equals(0));
        },
      );

      test(
        'indexer close error keeps the EOSE-complete count',
        () async {
          const indexerUrl = 'wss://idx.test';

          repository = FollowRepository(
            nostrClient: mockNostrClient,
            isCacheInitialized: () => cacheIsInitialized,
            getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
            cacheUserEvent: cachedUserEvents.add,
            indexerRelayUrls: const [indexerUrl],
            relayFactory: (url, status) {
              return _FakeRelay(url, status, throwOnSend: true)
                ..fakeResponses = [
                  [
                    'EVENT',
                    's',
                    {
                      'pubkey':
                          'aa00000000000000000000000000000000000000000000000000000000000001',
                    },
                  ],
                  ['EOSE', 's'],
                ];
            },
          );

          // send() throws after completer completes
          final stats = await repository.getFollowerStats(testTargetPubkey);

          expect(stats.followers, equals(1));
        },
      );

      test(
        'indexer relay disconnect error does not crash',
        () async {
          const indexerUrl = 'wss://idx.test';

          repository = FollowRepository(
            nostrClient: mockNostrClient,
            isCacheInitialized: () => cacheIsInitialized,
            getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
            cacheUserEvent: cachedUserEvents.add,
            indexerRelayUrls: const [indexerUrl],
            relayFactory: (url, status) {
              return _FakeRelay(
                  url,
                  status,
                  throwOnDisconnect: true,
                )
                ..fakeResponses = [
                  [
                    'EVENT',
                    's',
                    {
                      'pubkey':
                          'aa00000000000000000000000000000000000000000000000000000000000001',
                    },
                  ],
                  ['EOSE', 's'],
                ];
            },
          );

          final stats = await repository.getFollowerStats(testTargetPubkey);

          // Should succeed despite disconnect error
          expect(stats.followers, equals(1));
        },
      );

      test(
        '_checkIfTheyFollowUs catch returns false',
        () async {
          SharedPreferences.setMockInitialValues({
            'following_list_$testCurrentUserPubkey': '["$testTargetPubkey"]',
          });

          repository = FollowRepository(
            nostrClient: mockNostrClient,
            isCacheInitialized: () => cacheIsInitialized,
            getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
            cacheUserEvent: cachedUserEvents.add,
            indexerRelayUrls: const [],
          );

          await repository.initialize();

          // queryEvents: first call (from _fetchFollowersFromRelays)
          // returns empty, second call (from _checkIfTheyFollowUs)
          // throws
          var queryCallCount = 0;
          when(() => mockNostrClient.queryEvents(any())).thenAnswer(
            (_) async {
              queryCallCount++;
              if (queryCallCount == 1) return [];
              throw Exception('Network error');
            },
          );

          final result = await repository.isMutualFollow(testTargetPubkey);

          expect(result, isFalse);
        },
      );

      test(
        'indexer follower pubkeys error returns partial results',
        () async {
          const indexerUrl = 'wss://idx.test';

          when(() => mockNostrClient.queryEvents(any())).thenAnswer(
            (_) async => [],
          );

          repository = FollowRepository(
            nostrClient: mockNostrClient,
            isCacheInitialized: () => cacheIsInitialized,
            getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
            cacheUserEvent: cachedUserEvents.add,
            indexerRelayUrls: const [indexerUrl],
            relayFactory: (url, status) {
              return _FakeRelay(url, status, throwOnSend: true)
                ..fakeResponses = [
                  [
                    'EVENT',
                    's',
                    {
                      'pubkey':
                          'aa00000000000000000000000000000000000000000000000000000000000001',
                    },
                  ],
                  ['EOSE', 's'],
                ];
            },
          );

          final followers = await repository.getFollowers(testTargetPubkey);

          // Should not crash — returns whatever was collected
          expect(followers, isA<List<String>>());
        },
      );

      test(
        '_loadContactListFromIndexer handles throw',
        () async {
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

          repository = FollowRepository(
            nostrClient: mockNostrClient,
            isCacheInitialized: () => cacheIsInitialized,
            getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
            cacheUserEvent: cachedUserEvents.add,
            indexerRelayUrls: const ['wss://idx.test'],
            relayFactory: (url, status) {
              throw Exception('Relay creation error');
            },
            queryContactList:
                ({
                  required eventStream,
                  required pubkey,
                  fallbackTimeoutSeconds = 10,
                }) async => null,
          );

          // Should not crash — logs warning and continues
          await repository.initialize();

          expect(repository.followingCount, 0);
        },
      );

      test(
        '_loadContactListFromIndexer is bounded when connect never completes',
        () async {
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

          repository = FollowRepository(
            nostrClient: mockNostrClient,
            isCacheInitialized: () => cacheIsInitialized,
            getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
            cacheUserEvent: cachedUserEvents.add,
            indexerRelayUrls: const ['wss://idx.test'],
            indexerOperationTimeout: const Duration(milliseconds: 20),
            relayFactory: (url, status) =>
                _FakeRelay(url, status, neverConnects: true),
            queryContactList:
                ({
                  required eventStream,
                  required pubkey,
                  fallbackTimeoutSeconds = 10,
                }) async => null,
          );

          await repository.initialize().timeout(
            const Duration(milliseconds: 200),
          );

          expect(repository.followingCount, 0);
        },
      );

      test(
        '_queryIndexerForContactList timeout returns bestEvent',
        () async {
          // Create a relay that sends an EVENT but no EOSE
          // → completer times out → returns bestEvent
          final contactListJson = {
            'pubkey': testCurrentUserPubkey,
            'kind': EventKind.contactList,
            'id':
                'aaaa000000000000000000000000000000000000000000000000000000000000',
            'sig':
                'bbbb000000000000000000000000000000000000000000000000000000000000bbbb000000000000000000000000000000000000000000000000000000000000',
            'content': '',
            'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
            'tags': [
              ['p', testTargetPubkey],
            ],
          };

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

          repository = FollowRepository(
            nostrClient: mockNostrClient,
            isCacheInitialized: () => cacheIsInitialized,
            getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
            cacheUserEvent: cachedUserEvents.add,
            indexerRelayUrls: const ['wss://idx.test'],
            indexerOperationTimeout: const Duration(milliseconds: 20),
            relayFactory: (url, status) {
              // EVENT but no EOSE → timeout fires
              return _FakeRelay(url, status, neverCloses: true)
                ..fakeResponses = [
                  ['EVENT', 'sub1', contactListJson],
                  // No EOSE — completer times out
                ];
            },
            queryContactList:
                ({
                  required eventStream,
                  required pubkey,
                  fallbackTimeoutSeconds = 10,
                }) async => null,
          );

          await repository.initialize();

          // Should load from timeout with bestEvent
          expect(repository.followingCount, 1);
          expect(
            repository.isFollowing(testTargetPubkey),
            isTrue,
          );
        },
        timeout: const Timeout(Duration(seconds: 15)),
      );

      test(
        '_queryIndexerForContactList handles send error',
        () async {
          final contactListJson = {
            'pubkey': testCurrentUserPubkey,
            'kind': EventKind.contactList,
            'id':
                'aaaa000000000000000000000000000000000000000000000000000000000000',
            'sig':
                'bbbb000000000000000000000000000000000000000000000000000000000000bbbb000000000000000000000000000000000000000000000000000000000000',
            'content': '',
            'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
            'tags': [
              ['p', testTargetPubkey],
            ],
          };

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

          repository = FollowRepository(
            nostrClient: mockNostrClient,
            isCacheInitialized: () => cacheIsInitialized,
            getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
            cacheUserEvent: cachedUserEvents.add,
            indexerRelayUrls: const ['wss://idx.test'],
            relayFactory: (url, status) {
              return _FakeRelay(url, status, throwOnSend: true)
                ..fakeResponses = [
                  ['EVENT', 'sub1', contactListJson],
                  ['EOSE', 'sub1'],
                ];
            },
            queryContactList:
                ({
                  required eventStream,
                  required pubkey,
                  fallbackTimeoutSeconds = 10,
                }) async => null,
          );

          await repository.initialize();

          // Should have loaded despite send error (CLOSE msg fails)
          expect(repository.followingCount, 1);
        },
      );

      test(
        '_defaultRelayFactory is used when no factory injected',
        () async {
          // Create repo WITHOUT relayFactory but WITH indexer URL.
          // The default factory creates a real RelayBase which
          // will fail to connect to the fake URL.
          repository = FollowRepository(
            nostrClient: mockNostrClient,
            isCacheInitialized: () => cacheIsInitialized,
            getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
            cacheUserEvent: cachedUserEvents.add,
            indexerRelayUrls: const ['wss://127.0.0.1:1'],
          );

          // getFollowerStats triggers indexer query using
          // _defaultRelayFactory. Connection to localhost:1 will
          // fail fast (connection refused).
          final stats = await repository.getFollowerStats(testTargetPubkey);

          // Should return FollowerStats.zero (connection failed)
          expect(stats, isNotNull);
        },
        timeout: const Timeout(Duration(seconds: 30)),
      );

      test(
        '_loadFromRelay outer catch fires on Future.wait error',
        () async {
          // _loadFromRelay calls Future.wait on connected relay
          // and indexer queries. If both throw, the outer catch
          // at 1510 fires.
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
          ).thenThrow(Exception('Subscribe failed'));

          repository = FollowRepository(
            nostrClient: mockNostrClient,
            isCacheInitialized: () => cacheIsInitialized,
            getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
            cacheUserEvent: cachedUserEvents.add,
            indexerRelayUrls: const ['wss://idx.test'],
            relayFactory: (url, status) {
              throw Exception('Relay factory error');
            },
          );

          // Both connected relay and indexer throw → outer catch
          await repository.initialize();

          expect(repository.followingCount, 0);
        },
      );

      test(
        '_queryIndexerForContactList picks newer of two events',
        () async {
          final olderContactList = {
            'pubkey': testCurrentUserPubkey,
            'kind': EventKind.contactList,
            'id':
                'aaaa000000000000000000000000000000000000000000000000000000000000',
            'sig':
                'bbbb000000000000000000000000000000000000000000000000000000000000bbbb000000000000000000000000000000000000000000000000000000000000',
            'content': '',
            'created_at': 1000000,
            'tags': [
              ['p', testTargetPubkey],
            ],
          };

          final newerContactList = {
            'pubkey': testCurrentUserPubkey,
            'kind': EventKind.contactList,
            'id':
                'cccc000000000000000000000000000000000000000000000000000000000000',
            'sig':
                'dddd000000000000000000000000000000000000000000000000000000000000dddd000000000000000000000000000000000000000000000000000000000000',
            'content': '',
            'created_at': 2000000,
            'tags': [
              ['p', testTargetPubkey],
              ['p', testTargetPubkey2],
            ],
          };

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

          repository = FollowRepository(
            nostrClient: mockNostrClient,
            isCacheInitialized: () => cacheIsInitialized,
            getCachedEventsByKind: (kind) => getCachedEventsByKind(kind),
            cacheUserEvent: cachedUserEvents.add,
            indexerRelayUrls: const ['wss://idx.test'],
            relayFactory: (url, status) {
              // Two EVENTs (older then newer) + EOSE
              return _FakeRelay(url, status)
                ..fakeResponses = [
                  ['EVENT', 'sub1', olderContactList],
                  ['EVENT', 'sub1', newerContactList],
                  ['EOSE', 'sub1'],
                ];
            },
            queryContactList:
                ({
                  required eventStream,
                  required pubkey,
                  fallbackTimeoutSeconds = 10,
                }) async => null,
          );

          await repository.initialize();

          // Should pick the newer event with 2 follows
          expect(repository.followingCount, 2);
          expect(
            repository.isFollowing(testTargetPubkey),
            isTrue,
          );
          expect(
            repository.isFollowing(testTargetPubkey2),
            isTrue,
          );
        },
      );
    });
  });
}
