// ABOUTME: E2E for #7328 — the sender's own gift-wrap copy reaches the relays
// ABOUTME: their own kind-10050 advertises, not just the connected pool.
// ABOUTME: Drives a real DmRepository + NostrClient over real sockets.
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
import 'package:web_socket_channel/web_socket_channel.dart';

import '../helpers/fake_relay.dart';

/// Redirects every advertised hostname onto the in-process relay and records
/// the address it was asked for.
///
/// The recording is the assertion. `isRemoteSuppliedRelayUrlAllowed` refuses
/// loopback hosts, so a `ws://127.0.0.1` entry could never *be* an admitted
/// inbox target — it has to be reached through a public-looking name, and
/// "this host was dialed" is then observed rather than inferred from a
/// publish result.
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

/// A DM inbox relay the SENDER advertises and the pool does not contain.
///
/// This models divine's own shape since #8378: every account's kind-10050
/// names `nos.lol` and `relay.primal.net` on top of the divine relay, and
/// neither joins the pool unless NIP-65 discovery came back empty.
const _senderOnlyInbox = 'wss://sender-inbox.example';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const senderKey =
      '3333333333333333333333333333333333333333333333333333333333333333';
  const recipientKey =
      '4444444444444444444444444444444444444444444444444444444444444444';
  final senderPubkey = getPublicKey(senderKey);
  final recipientPubkey = getPublicKey(recipientKey);

  /// A kind-10050 signed by the SENDER.
  ///
  /// [FakeRelay] serves one reply for every `REQ` regardless of filter, and
  /// that is exactly what makes this test able to attribute a dial. The
  /// repository only accepts a relay list whose `event.pubkey` matches the
  /// author it asked about, so this same event resolves `found` for the
  /// sender's own lookup and is discarded as off-filter for the recipient's.
  /// The recipient therefore has no advertised inbox, their wrap goes to the
  /// plain pool, and any connection to [_senderOnlyInbox] can only have come
  /// from the self-addressed wrap.
  Map<String, dynamic> senderInbox() {
    final event = Event(
      senderPubkey,
      10050,
      [
        ['relay', _senderOnlyInbox],
      ],
      '',
      createdAt: 1700000000,
    )..sign(senderKey);
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
    // `addTearDown` is LIFO and `relay.stop` was registered first, so this
    // closes every socket ahead of it — otherwise in-flight connects fail
    // after the test completes and get attributed to it.
    addTearDown(nostr.relayPool.removeAll);

    // Through the manager, not RelayPool.add: a publish with no explicit
    // targets checks `connectedRelays`, which only the manager populates.
    await client.initialize();

    return (repository: repository, nostr: nostr, factory: factory);
  }

  group('#7328 self-wrap inbox relays', () {
    testWidgets('dials the sender own advertised inbox on a send', (
      tester,
    ) async {
      final relay = await FakeRelay.start(reply: senderInbox());
      addTearDown(relay.stop);
      final stack = await buildStack(relay);

      // The discriminator, asserted rather than assumed: the recipient has no
      // admitted inbox, so their wrap goes to the plain pool and cannot be
      // what reaches _senderOnlyInbox.
      expect(
        (await stack.repository.resolveDmInboxRelaysDetailed(
          recipientPubkey,
        )).relays,
        isNull,
        reason:
            'the served kind-10050 is authored by the sender, so it must be '
            'discarded as off-filter for the recipient',
      );

      final result = await stack.repository.sendMessage(
        recipientPubkey: recipientPubkey,
        content: 'self-wrap destination probe',
      );

      // Positive control. Without it every "was dialed" assertion below could
      // pass on a harness that never sent anything.
      expect(result.success, isTrue, reason: result.toString());
      expect(result.selfWrapPublished, isTrue, reason: result.toString());

      final host = Uri.parse(_senderOnlyInbox).host;
      expect(
        stack.factory.requested.where((u) => u.contains(host)),
        isNotEmpty,
        reason:
            'the sender advertises $_senderOnlyInbox as a DM inbox, so their '
            'own copy of an outgoing message has to reach it — publishing to '
            'the connected pool alone leaves their replies missing from the '
            'relay their own kind-10050 points every other client at',
      );
    });

    testWidgets('still delivers when the sender advertises no inbox', (
      tester,
    ) async {
      // The `absent` fallback. An account with no kind-10050 keeps the plain
      // pool publish, and nothing outside the pool is contacted.
      final relay = await FakeRelay.start();
      addTearDown(relay.stop);
      final stack = await buildStack(relay);

      final result = await stack.repository.sendMessage(
        recipientPubkey: recipientPubkey,
        content: 'no-inbox fallback probe',
      );

      expect(result.success, isTrue, reason: result.toString());
      expect(result.selfWrapPublished, isTrue, reason: result.toString());
      expect(relay.publishedEventIds, isNotEmpty);

      final host = Uri.parse(_senderOnlyInbox).host;
      expect(
        stack.factory.requested.where((u) => u.contains(host)),
        isEmpty,
        reason: 'nothing advertised this host, so nothing may dial it',
      );
    });
  });
}
