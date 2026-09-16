// ABOUTME: #8266 — a cross-device unfollow must survive a cold start and must
// ABOUTME: not be republished by the next follow. Drives the real
// ABOUTME: FollowRepository + NostrClient over real sockets.
// ABOUTME: Requires: NO Docker stack — the relay runs in-process.

@Tags(['service'])
library;

import 'package:cache_sync/cache_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/client_utils/keys.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/event_kind.dart';
import 'package:nostr_sdk/nip02/contact.dart';
import 'package:nostr_sdk/nip02/contact_list.dart';
import 'package:nostr_sdk/nostr.dart';
import 'package:nostr_sdk/relay/relay_base.dart';
import 'package:nostr_sdk/relay/relay_status.dart';
import 'package:nostr_sdk/relay/web_socket_connection_manager.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../helpers/fake_relay.dart';

/// Sends every socket to the in-process relay, whatever host was asked for.
class _LoopbackFactory implements WebSocketChannelFactory {
  _LoopbackFactory(this.port);

  final int port;

  @override
  WebSocketChannel create(Uri uri) =>
      WebSocketChannel.connect(Uri.parse('ws://127.0.0.1:$port${uri.path}'));
}

class _MemoryCacheDao implements CacheDao {
  final Map<String, String> _entries = {};

  @override
  Future<String?> read(String key) async => _entries[key];

  @override
  Future<void> write({
    required String key,
    required String payload,
    Duration? ttl,
  }) async => _entries[key] = payload;

  @override
  Future<void> delete(String key) async => _entries.remove(key);

  @override
  Future<void> deletePrefix(String prefix) async =>
      _entries.removeWhere((key, _) => key.startsWith(prefix));

  @override
  Future<int> totalPayloadBytes() async =>
      _entries.values.fold<int>(0, (sum, v) => sum + v.length);

  @override
  Future<void> evictOldest(int bytesToFree) async {
    // Intentional no-op: a per-test map has no size limit to enforce.
  }
}

extension on FakeRelay {
  List<Event> get publishedEvents => [
    for (final frame in receivedFrames)
      if (frame.isNotEmpty && frame[0] == 'EVENT' && frame.length >= 2)
        Event.fromJson(frame[1] as Map<String, dynamic>),
  ];

  /// The `p` tags of the newest kind 3 the relay was handed — kind 3 is
  /// replaceable, so this is what an external viewer resolves to.
  List<String>? get publicFollows {
    final contactLists = publishedEvents.where((e) => e.kind == 3).toList();
    if (contactLists.isEmpty) return null;
    contactLists.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return [
      for (final tag in contactLists.last.tags)
        if (tag.length > 1 && tag[0] == 'p') tag[1],
    ];
  }

  Future<void> awaitPublished(int kind, {int count = 1}) async {
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (publishedEvents.where((e) => e.kind == kind).length < count) {
      if (DateTime.now().isAfter(deadline)) {
        throw StateError(
          'relay never received $count event(s) of kind $kind; saw '
          '${publishedEvents.map((e) => e.kind).toList()}',
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const ownerKey =
      '06478cf31821ae2643888988c5ce3f31731079dbe6c544f5b4451f3c7ce8979c';
  const aliceKey =
      '50dc4b2e01ef449822e422e8c625ddf7d95dc069c414f06d2450556bf5ba7179';
  final alice = getPublicKey(aliceKey);
  const bobKey =
      '2f1a5c39b9e04d8f7c6b3a2e1d0f9876543210fedcba9876543210fedcba9871';
  final bob = getPublicKey(bobKey);
  const carolKey =
      '3e2b6d4ac8f15e907d5c4b3f2e1a8765432109fedcba8765432109fedcba9872';
  final carol = getPublicKey(carolKey);
  const daveKey =
      '4d3c7e5bd7e26fa16e4d5c2a3f0b9654321098fedcba7654321098fedcba9873';
  final dave = getPublicKey(daveKey);

  /// The real stack — Nostr -> RelayPool -> RelayManager -> NostrClient.
  ///
  /// Every socket lands on [relay]. [personalEventCache] stands in for the
  /// Hive-backed PersonalEventCache: the repository appends its own published
  /// kind 3 to it, exactly as the app wires `cacheUserEvent`, and reads it
  /// back newest-first on the next launch.
  Future<NostrClient> buildClient(FakeRelay relay) async {
    final factory = _LoopbackFactory(relay.port);
    RelayBase gen(String url) =>
        RelayBase(url, RelayStatus(url), channelFactory: factory);
    final nostr = Nostr(
      LocalNostrSigner(ownerKey),
      [],
      gen,
      channelFactory: factory,
    );
    final relayManager = RelayManager(
      config: RelayManagerConfig(
        defaultRelayUrl: relay.url,
        storage: InMemoryRelayStorage(),
      ),
      relayPool: nostr.relayPool,
    );
    final client = NostrClient.forTesting(
      nostr: nostr,
      relayManager: relayManager,
    );
    addTearDown(nostr.relayPool.removeAll);
    await client.initialize();
    return client;
  }

  Future<FollowRepository> buildRepository(
    FakeRelay relay,
    List<Event> personalEventCache,
  ) async => FollowRepository(
    nostrClient: await buildClient(relay),
    indexerRelayUrls: const [],
    isCacheInitialized: () => true,
    getCachedEventsByKind: (kind) => kind == EventKind.contactList
        ? (personalEventCache.toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt)))
        : const [],
    cacheUserEvent: personalEventCache.add,
  );

  /// A second device publishing a kind 3 for the same account.
  Future<void> publishFromOtherDevice(
    FakeRelay relay,
    List<String> follows,
  ) async {
    final client = await buildClient(relay);
    final list = ContactList();
    for (final follow in follows) {
      list.add(Contact(publicKey: follow));
    }
    final event = await client.sendContactList(list, '');
    expect(event, isNotNull, reason: 'the other device must reach the relay');
  }

  group('#8266 contact-list freshness across devices', () {
    /// Drives both devices until the divergent on-disk state exists, and
    /// returns the PersonalEventCache contents a cold start would read.
    ///
    /// Device A follows three accounts, so its own three-follow kind 3 is the
    /// newest thing in PersonalEventCache. Device B then unfollows two; that
    /// event arrives over device A's live subscription, which writes
    /// LocalStorage and never touches PersonalEventCache. So the cache is
    /// older and longer than LocalStorage — the exact shape in which counting
    /// `p` tags picks the wrong one.
    Future<List<Event>> stageCrossDeviceUnfollow(FakeRelay relay) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await CacheSync.init(dao: _MemoryCacheDao());

      final personalEventCache = <Event>[];
      final deviceA = await buildRepository(relay, personalEventCache);
      await deviceA.initialize();

      // A second apart each, so every cached kind 3 has a distinct
      // `created_at`. PersonalEventCache orders purely by that field, so
      // events sharing a second come back in an arbitrary order and the
      // staging would be non-deterministic.
      for (final target in [alice, bob, carol]) {
        await deviceA.follow(target);
        await Future<void>.delayed(const Duration(milliseconds: 1100));
      }
      await relay.awaitPublished(EventKind.contactList, count: 3);
      expect(
        deviceA.followingPubkeys,
        unorderedEquals([alice, bob, carol]),
        reason: 'positive control: device A must reach three follows first',
      );
      expect(
        personalEventCache.where((e) => e.kind == EventKind.contactList),
        isNotEmpty,
        reason: 'positive control: device A caches its own kind 3',
      );

      // A second later so the cross-device event is unambiguously newer.
      await Future<void>.delayed(const Duration(seconds: 2));
      await publishFromOtherDevice(relay, [alice]);

      final deadline = DateTime.now().add(const Duration(seconds: 10));
      while (deviceA.followingPubkeys.length != 1) {
        if (DateTime.now().isAfter(deadline)) break;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      expect(
        deviceA.followingPubkeys,
        [alice],
        reason:
            'positive control: the live subscription must apply the '
            'cross-device unfollow before the cold start is staged',
      );

      await deviceA.dispose();
      return personalEventCache;
    }

    testWidgets(
      'the cross-device unfollow survives a cold start',
      (
        tester,
      ) async {
        final relay = await FakeRelay.start(broadcast: true);
        addTearDown(relay.stop);

        final personalEventCache = await stageCrossDeviceUnfollow(relay);

        // Cold start: same SharedPreferences, same PersonalEventCache.
        final reopened = await buildRepository(relay, personalEventCache);
        addTearDown(reopened.dispose);
        await reopened.initialize();

        expect(
          reopened.followingPubkeys,
          [alice],
          reason:
              'the cached event is older and has more p tags; preferring it '
              'undoes a legitimate unfollow (#8266)',
        );
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    testWidgets(
      'the next follow does not republish the unfollowed accounts',
      (
        tester,
      ) async {
        final relay = await FakeRelay.start(broadcast: true);
        addTearDown(relay.stop);

        final personalEventCache = await stageCrossDeviceUnfollow(relay);
        final publishedBefore = relay.publishedEvents
            .where((e) => e.kind == EventKind.contactList)
            .length;

        final reopened = await buildRepository(relay, personalEventCache);
        addTearDown(reopened.dispose);
        await reopened.initialize();
        await reopened.follow(dave);
        await relay.awaitPublished(
          EventKind.contactList,
          count: publishedBefore + 1,
        );

        expect(
          relay.publicFollows,
          unorderedEquals([alice, dave]),
          reason:
              'bob and carol were unfollowed on the other device; a follow '
              'must not put them back on the relay',
        );
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });
}
