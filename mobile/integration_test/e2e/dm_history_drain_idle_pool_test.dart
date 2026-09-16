// ABOUTME: End-to-end proof for #8550 against a real relay pool: a DM history
// ABOUTME: drain issued into an idle-disconnected pool reconnects first instead
// ABOUTME: of failing as "no relay answered", and a drain that had to defer
// ABOUTME: resumes on its own once a relay connects — no Retry tap needed.

@Tags(['service'])
library;

import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/client_utils/keys.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/nostr.dart';
import 'package:nostr_sdk/relay/relay_base.dart';
import 'package:nostr_sdk/relay/relay_status.dart';
import 'package:nostr_sdk/relay/web_socket_connection_manager.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../helpers/fake_relay.dart';

/// Every URL the stack dials lands on the in-process relay, so the pool
/// relay and the account's advertised inbox can share one public-looking
/// hostname exactly as they do for a divine account in production.
class _RedirectFactory implements WebSocketChannelFactory {
  _RedirectFactory(this.port);

  final int port;

  @override
  WebSocketChannel create(Uri uri) => WebSocketChannel.connect(
    Uri.parse('ws://127.0.0.1:$port${uri.path}'),
  );
}

/// The one relay in the pool, and the one relay the account's kind-10050
/// advertises — the shape the drain's own-inbox temp relays take for every
/// divine account, and the shape that defeated the reconnect-first guard.
const _poolRelay = 'wss://pool.example';

const _dmInboxKind = 10050;

typedef _Stack = ({DmRepository repository, NostrClient client, Nostr nostr});

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const userKey =
      '1111111111111111111111111111111111111111111111111111111111111111';
  final userPubkey = getPublicKey(userKey);

  Map<String, dynamic> ownInbox() {
    final event = Event(
      userPubkey,
      _dmInboxKind,
      [
        ['relay', _poolRelay],
      ],
      '',
      createdAt: 1700000000,
    )..sign(userKey);
    return event.toJson();
  }

  Future<FakeRelay> startRelay({int port = 0}) => FakeRelay.start(
    reply: ownInbox(),
    replyForKinds: const {_dmInboxKind},
    port: port,
  );

  Future<_Stack> buildStack(FakeRelay relay) async {
    final factory = _RedirectFactory(relay.port);
    final signer = LocalNostrSigner(userKey);

    RelayBase gen(String url) =>
        RelayBase(url, RelayStatus(url), channelFactory: factory);
    final nostr = Nostr(signer, [], gen, channelFactory: factory);

    final relayManager = RelayManager(
      config: RelayManagerConfig(
        defaultRelayUrl: _poolRelay,
        storage: InMemoryRelayStorage(),
        // The manager dials pool relays with its own factory, so the pool's
        // public-looking URL needs the same redirect the temp relays get.
        webSocketChannelFactory: factory,
      ),
      relayPool: nostr.relayPool,
    );
    final client = NostrClient.forTesting(
      nostr: nostr,
      relayManager: relayManager,
    );

    final db = AppDatabase.test(NativeDatabase.memory());
    addTearDown(db.close);
    SharedPreferences.setMockInitialValues(const <String, Object>{});

    final repository = DmRepository(
      nostrClient: client,
      directMessagesDao: db.directMessagesDao,
      conversationsDao: db.conversationsDao,
      outgoingDmsDao: db.outgoingDmsDao,
      userPubkey: userPubkey,
      signer: signer,
      syncState: DmSyncState(await SharedPreferences.getInstance()),
      messageService: NIP17MessageService(
        signer: signer,
        senderPublicKey: userPubkey,
        nostrService: client,
      ),
    );
    addTearDown(repository.stopListening);
    addTearDown(nostr.relayPool.removeAll);

    await client.initialize();
    return (repository: repository, client: client, nostr: nostr);
  }

  /// Polls [condition] on real time; integration tests run without a fake
  /// clock, and the relay manager only re-reads pool state every few seconds.
  Future<void> waitUntil(
    bool Function() condition, {
    required String reason,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (!condition()) {
      if (DateTime.now().isAfter(deadline)) fail('timed out: $reason');
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  /// Brings the stack to the state the reporter's device was in: signed in,
  /// the account's own inbox resolved and memoized while the pool was up,
  /// and every pool socket since dropped by the SDK's idle timeout.
  Future<void> idleOutThePool(_Stack stack) async {
    await waitUntil(
      () => stack.client.connectedRelayCount == 1,
      reason: 'the pool relay never connected',
    );
    await stack.repository.startListening();
    // The idle timeout drops the socket exactly like this: state
    // disconnected, and no reconnect scheduled by anyone.
    for (final url in stack.client.configuredRelays) {
      await stack.nostr.relayPool.getRelay(url)?.disconnect();
    }
    await waitUntil(
      () => stack.client.connectedRelayCount == 0,
      reason: 'the relay manager never noticed the dropped socket',
    );
  }

  group('#8550 DM history drain against an idle pool', () {
    testWidgets(
      'a drain issued into an idle-disconnected pool reconnects first and '
      'completes instead of failing as "no relay answered"',
      (tester) async {
        final relay = await startRelay();
        addTearDown(relay.stop);
        final stack = await buildStack(relay);
        await idleOutThePool(stack);

        await stack.repository.backfillHistoryIfNeeded();

        expect(
          stack.repository.hasCompletedHistoryRecoveryBefore,
          isTrue,
          reason:
              'the page must bring the pool back before fanning out, not '
              'read a fan-out nobody took as a deferral',
        );
        expect(stack.client.connectedRelayCount, 1);
      },
    );

    testWidgets(
      'a drain deferred while the relay was unreachable resumes on its own '
      'once the relay connects, without another inbox open or Retry',
      (tester) async {
        final relay = await startRelay();
        final stack = await buildStack(relay);
        await idleOutThePool(stack);
        final port = relay.port;
        // Not merely idle: the relay is gone, so the reconnect the page
        // attempts cannot help and the drain has to defer.
        await relay.stop();

        await stack.repository.backfillHistoryIfNeeded();
        expect(
          stack.repository.hasCompletedHistoryRecoveryBefore,
          isFalse,
          reason: 'nothing could answer while the relay was down',
        );

        final revived = await startRelay(port: port);
        addTearDown(revived.stop);
        // What the app's next reconnect sweep, or a resume from background,
        // does for the pool.
        await stack.client.retryDisconnectedRelays();

        await waitUntil(
          () => stack.repository.hasCompletedHistoryRecoveryBefore,
          reason: 'the deferred drain never resumed after the relay connected',
        );
      },
    );
  });
}
