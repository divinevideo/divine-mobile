// ABOUTME: E2E for #6585 — a DM is routed only to the relays admitted from
// ABOUTME: the recipient's kind-10050, and still sends. Drives a real
// ABOUTME: DmRepository + NostrClient over real sockets.
// ABOUTME: Requires: NO Docker stack — every dependency here is local.

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
import 'package:nostr_sdk/utils/relay_addr_util.dart';
import 'package:nostr_sdk/utils/relay_url_policy.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../helpers/fake_relay.dart';

/// Redirects the public hostnames a relay list advertises onto the in-process
/// relay, and records every address it was asked to open.
///
/// Both halves matter. The redirect is what makes an end-to-end test possible
/// at all: `isRemoteSuppliedRelayUrlAllowed` refuses private and loopback
/// hosts by design, so a `ws://127.0.0.1` relay can never *be* an admitted
/// target — it has to be reached through one. And the recording is the
/// assertion: "this host was never dialed" is then something the test
/// observes directly, rather than infers from a publish result.
class _RecordingRedirectFactory implements WebSocketChannelFactory {
  _RecordingRedirectFactory(this.port);

  final int port;
  final List<String> requested = [];

  @override
  WebSocketChannel create(Uri uri) {
    requested.add(uri.toString());
    return WebSocketChannel.connect(
      Uri.parse('ws://127.0.0.1:$port${uri.path}'),
    );
  }
}

/// Hosts a counterparty must never be able to point this device at.
const _hostileTargets = <String>[
  'wss://192.168.1.50',
  'wss://127.0.0.1',
  'wss://169.254.169.254',
  'wss://nas.local',
  'ws://cleartext.example',
];

const _admittedTargets = <String>[
  'wss://admitted-1.example',
  'wss://admitted-2.example',
];

/// Surplus legitimate hosts, so the total exceeds [RelayListCaps.dmInbox].
final List<String> _surplusTargets = [
  for (var i = 0; i < 10; i++) 'wss://surplus-$i.example',
];

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const senderKey =
      '1111111111111111111111111111111111111111111111111111111111111111';
  const recipientKey =
      '2222222222222222222222222222222222222222222222222222222222222222';
  final senderPubkey = getPublicKey(senderKey);
  final recipientPubkey = getPublicKey(recipientKey);

  /// The recipient's kind-10050, signed by them, ordered so the admitted
  /// hosts come first and the cap is provably first-N in tag order.
  Map<String, dynamic> recipientInbox() {
    final event = Event(
      recipientPubkey,
      10050,
      [
        for (final url in [
          ..._admittedTargets,
          ..._hostileTargets,
          ..._surplusTargets,
        ])
          ['relay', url],
      ],
      '',
      createdAt: 1700000000,
    )..sign(recipientKey);
    return event.toJson();
  }

  /// Builds the real stack: Nostr → RelayPool → RelayManager → NostrClient →
  /// NIP17MessageService → DmRepository, with every socket landing on [relay].
  Future<
    ({DmRepository repository, Nostr nostr, _RecordingRedirectFactory factory})
  >
  buildStack(FakeRelay relay) async {
    final factory = _RecordingRedirectFactory(relay.port);
    final signer = LocalNostrSigner(senderKey);

    RelayBase gen(String url) =>
        RelayBase(url, RelayStatus(url), channelFactory: factory);
    final nostr = Nostr(signer, [], gen, channelFactory: factory);

    final relayManager = RelayManager(
      config: RelayManagerConfig(
        defaultRelayUrl: relay.url,
        storage: InMemoryRelayStorage(),
        // Deliberately unset: this is the production shape, and setting it
        // would filter every `*.example` target away — `_allowedRelays`
        // collapses an all-filtered list to null, which falls back to the
        // whole pool and would quietly hide what this test is measuring.
      ),
      relayPool: nostr.relayPool,
    );
    final client = NostrClient.forTesting(
      nostr: nostr,
      relayManager: relayManager,
    );

    final db = AppDatabase.test(NativeDatabase.memory());
    addTearDown(db.close);

    final repository = DmRepository(
      nostrClient: client,
      directMessagesDao: db.directMessagesDao,
      conversationsDao: db.conversationsDao,
      outgoingDmsDao: db.outgoingDmsDao,
      userPubkey: senderPubkey,
      signer: signer,
      messageService: NIP17MessageService(
        signer: signer,
        senderPublicKey: senderPubkey,
        nostrService: client,
      ),
    );
    addTearDown(repository.stopListening);
    // Close every socket before the fake relay goes away. `addTearDown` is
    // LIFO and `relay.stop` was registered first, so this runs ahead of it —
    // otherwise in-flight connects fail after the test has completed and get
    // attributed to it.
    addTearDown(nostr.relayPool.removeAll);

    // Through the manager, not RelayPool.add: a publish with no explicit
    // targets checks `connectedRelays`, which only the manager populates.
    await client.initialize();

    return (repository: repository, nostr: nostr, factory: factory);
  }

  group('#6585 DM inbox relay admission', () {
    testWidgets('resolves only the admitted subset of a kind-10050', (
      tester,
    ) async {
      final relay = await FakeRelay.start(reply: recipientInbox());
      addTearDown(relay.stop);
      final stack = await buildStack(relay);

      final resolved = (await stack.repository.resolveDmInboxRelaysDetailed(
        recipientPubkey,
      )).relays;

      expect(resolved, hasLength(RelayListCaps.dmInbox));
      // First-N in tag order: the two admitted hosts, then surplus.
      expect(resolved!.take(2), _admittedTargets);
      for (final hostile in _hostileTargets) {
        expect(resolved, isNot(contains(hostile)), reason: hostile);
      }
    });

    testWidgets('never dials a host the recipient should not reach', (
      tester,
    ) async {
      final relay = await FakeRelay.start(reply: recipientInbox());
      addTearDown(relay.stop);
      final stack = await buildStack(relay);

      final result = await stack.repository.sendMessage(
        recipientPubkey: recipientPubkey,
        content: 'admission probe',
      );

      // Positive control. If the send did not succeed the harness is wrong,
      // and every "was not dialed" assertion below would pass for that reason
      // rather than because the filter worked.
      expect(result.success, isTrue, reason: result.toString());

      for (final hostile in _hostileTargets) {
        final host = Uri.parse(hostile).host;
        expect(
          stack.factory.requested.where((u) => u.contains(host)),
          isEmpty,
          reason: 'dialed $hostile',
        );
      }

      // Connection-level witness. Temp relays are keyed by the normalised
      // address, so comparing raw URLs here would silently match nothing.
      // `_sendCollect` does not normalise `tempRelays` while `subscribe`
      // does, so the same host can be keyed either way. Accept both rather
      // than pinning the inconsistency.
      final admitted = {
        for (final url in [..._admittedTargets, ..._surplusTargets]) ...[
          url,
          RelayAddrUtil.handle(url),
        ],
      };
      for (final dialed in stack.nostr.relayPool.tempRelayUrls) {
        expect(admitted, contains(dialed), reason: dialed);
      }
    });

    testWidgets('still delivers when the recipient advertises no inbox', (
      tester,
    ) async {
      // The `absent` fallback predates #6585 and must survive it: a recipient
      // with no kind-10050 is still reachable via the default pool.
      final relay = await FakeRelay.start();
      addTearDown(relay.stop);
      final stack = await buildStack(relay);

      expect(
        (await stack.repository.resolveDmInboxRelaysDetailed(
          recipientPubkey,
        )).relays,
        isNull,
      );

      final result = await stack.repository.sendMessage(
        recipientPubkey: recipientPubkey,
        content: 'fallback probe',
      );

      expect(result.success, isTrue, reason: result.toString());
      expect(relay.publishedEventIds, isNotEmpty);
    });
  });
}
