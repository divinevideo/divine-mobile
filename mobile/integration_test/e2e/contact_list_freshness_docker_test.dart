// ABOUTME: #8266 against the real funnelcake relay in local_stack, not a fake.
// ABOUTME: Proves the cross-device unfollow survives a cold start and is not
// ABOUTME: republished, over a relay that really enforces NIP-01 replacement.
// ABOUTME: Requires: local_stack up (funnelcake-relay on localhost:47777).

@Tags(['service'])
library;

import 'dart:convert';

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
import 'package:nostr_sdk/signer/local_nostr_signer.dart';
import 'package:openvine/models/environment_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

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

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // A physical device cannot reach the Mac's loopback, so the host is
  // overridable: pass --dart-define=LOCAL_STACK_HOST=<mac LAN ip> when running
  // on a device. The simulator and macOS keep the loopback default.
  const hostOverride = String.fromEnvironment('LOCAL_STACK_HOST');
  final relayHost = hostOverride.isEmpty ? localHost : hostOverride;
  final relayUrl = 'ws://$relayHost:$localRelayPort';

  // A fresh identity per run, so a previous run's kind 3 on the relay cannot
  // decide this one. The relay really replaces kind 3 per pubkey, so reusing
  // a key would carry state across runs.
  final ownerKey = generatePrivateKey();
  final owner = getPublicKey(ownerKey);
  final alice = getPublicKey(generatePrivateKey());
  final bob = getPublicKey(generatePrivateKey());
  final carol = getPublicKey(generatePrivateKey());
  final dave = getPublicKey(generatePrivateKey());

  Future<NostrClient> buildClient() async {
    RelayBase gen(String url) => RelayBase(url, RelayStatus(url));
    final nostr = Nostr(LocalNostrSigner(ownerKey), [], gen);
    final relayManager = RelayManager(
      config: RelayManagerConfig(
        defaultRelayUrl: relayUrl,
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

  /// [startupRelayReadAnswers] false models the one condition the repository
  /// itself cannot distinguish: `_loadFromRelay` returns null for both "the
  /// relay holds nothing" and "nobody answered", logging them identically as
  /// *No kind 3 contact list found on relay*. A transient network at launch
  /// puts a session there, and it is the window in which a wrong hydration
  /// base is not corrected before the next follow republishes it.
  ///
  /// Everything else stays on the real relay — the publish, NIP-01
  /// replacement, and the read-back.
  Future<FollowRepository> buildRepository(
    List<Event> personalEventCache, {
    bool startupRelayReadAnswers = true,
  }) async => FollowRepository(
    nostrClient: await buildClient(),
    indexerRelayUrls: const [],
    isCacheInitialized: () => true,
    getCachedEventsByKind: (kind) => kind == EventKind.contactList
        ? (personalEventCache.toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt)))
        : const [],
    cacheUserEvent: personalEventCache.add,
    queryContactList: startupRelayReadAnswers
        ? null
        : ({
            required Stream<Event> eventStream,
            required String pubkey,
            int fallbackTimeoutSeconds = 5,
          }) async => null,
  );

  /// What the relay itself resolves the account's kind 3 to, read over a
  /// separate socket so nothing in the client's own caches can answer.
  Future<Event?> readRelayContactList() async {
    final channel = WebSocketChannel.connect(Uri.parse(relayUrl));
    await channel.ready;
    const subId = 'freshness-probe';
    Event? newest;
    channel.sink.add(
      jsonEncode([
        'REQ',
        subId,
        {
          'kinds': [EventKind.contactList],
          'authors': [owner],
        },
      ]),
    );
    await for (final message in channel.stream.timeout(
      const Duration(seconds: 15),
    )) {
      final frame = jsonDecode(message as String) as List<dynamic>;
      if (frame[0] == 'EVENT' && frame[1] == subId) {
        final event = Event.fromJson(frame[2] as Map<String, dynamic>);
        if (newest == null || event.createdAt > newest.createdAt) {
          newest = event;
        }
      } else if (frame[0] == 'EOSE' && frame[1] == subId) {
        break;
      }
    }
    channel.sink.add(jsonEncode(['CLOSE', subId]));
    await channel.sink.close();
    return newest;
  }

  List<String> followsOf(Event event) => [
    for (final tag in event.tags)
      if (tag.length > 1 && tag[0] == 'p') tag[1],
  ];

  /// Polls the relay until its kind 3 resolves to [expected].
  ///
  /// `sendContactList` returns once the frame is handed to the pool, and
  /// funnelcake commits through ClickHouse, so a read taken straight after a
  /// publish can still serve the previous version. That is a property of the
  /// real stack — the in-process relay in the sibling suite answers
  /// immediately and hides it.
  Future<void> awaitRelayFollows(
    List<String> expected, {
    required String reason,
  }) async {
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    List<String>? last;
    while (DateTime.now().isBefore(deadline)) {
      final event = await readRelayContactList();
      last = event == null ? null : followsOf(event);
      if (last != null &&
          last.length == expected.length &&
          last.toSet().containsAll(expected)) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    fail('$reason\nrelay still serves: $last\nexpected: $expected');
  }

  group('#8266 against the local_stack funnelcake relay', () {
    testWidgets(
      'a cross-device unfollow is not undone or republished',
      (
        tester,
      ) async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        await CacheSync.init(dao: _MemoryCacheDao());

        final personalEventCache = <Event>[];

        // ── Device A: follow three accounts ──────────────────────────────
        final deviceA = await buildRepository(personalEventCache);
        await deviceA.initialize();
        for (final target in [alice, bob, carol]) {
          await deviceA.follow(target);
          // Distinct created_at per cached event; PersonalEventCache orders on
          // that field alone.
          await Future<void>.delayed(const Duration(milliseconds: 1100));
        }
        expect(
          deviceA.followingPubkeys,
          unorderedEquals([alice, bob, carol]),
          reason: 'positive control: three follows must reach device A',
        );

        await awaitRelayFollows(
          [alice, bob, carol],
          reason: 'positive control: the relay must hold all three follows',
        );

        // ── Device B: unfollow two ───────────────────────────────────────
        await Future<void>.delayed(const Duration(seconds: 2));
        final deviceB = await buildClient();
        final remaining = ContactList()..add(Contact(publicKey: alice));
        expect(
          await deviceB.sendContactList(remaining, ''),
          isNotNull,
          reason: 'positive control: device B must reach the relay',
        );

        await awaitRelayFollows(
          [alice],
          reason: 'positive control: the relay must replace the kind 3',
        );

        // Let device A's live subscription apply it.
        final deadline = DateTime.now().add(const Duration(seconds: 15));
        while (deviceA.followingPubkeys.length != 1 &&
            DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
        expect(
          deviceA.followingPubkeys,
          [alice],
          reason:
              'positive control: device A must see the cross-device '
              'unfollow before the cold start is staged',
        );
        await deviceA.dispose();

        // ── Cold start, with the startup relay read unanswered ───────────
        final reopened = await buildRepository(
          personalEventCache,
          startupRelayReadAnswers: false,
        );
        addTearDown(reopened.dispose);
        await reopened.initialize();

        expect(
          reopened.followingPubkeys,
          [alice],
          reason:
              'the cached event is older and has more p tags; preferring it '
              'undoes a legitimate unfollow (#8266)',
        );

        // ── The next follow must not resurrect them ──────────────────────
        await reopened.follow(dave);

        await awaitRelayFollows(
          [alice, dave],
          reason:
              'bob and carol were unfollowed on device B; a follow must '
              'not put them back on the relay',
        );
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  });
}
