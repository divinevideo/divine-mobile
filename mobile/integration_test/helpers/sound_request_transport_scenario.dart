// ABOUTME: Real encrypted sound request and fulfillment over loopback sockets.
// ABOUTME: Uses the shared relay harness and durable DM storage, without mocks.
import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/client_utils/keys.dart';
import 'package:nostr_sdk/nostr.dart';
import 'package:nostr_sdk/relay/relay_base.dart';
import 'package:nostr_sdk/relay/relay_status.dart';
import 'package:nostr_sdk/relay/web_socket_connection_manager.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';
import 'package:openvine/services/sound_requests/sound_request_dm_client.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'fake_relay.dart';

class _LoopbackChannels implements WebSocketChannelFactory {
  _LoopbackChannels(this.port);
  final int port;
  @override
  WebSocketChannel create(Uri uri) =>
      WebSocketChannel.connect(Uri.parse('ws://127.0.0.1:$port${uri.path}'));
}

/// Proves sound metadata survives real encrypted DM delivery and recovery.
Future<void> runSoundRequestTransportScenario() async {
  final previousWarning = driftRuntimeOptions.dontWarnAboutMultipleDatabases;
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  addTearDown(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = previousWarning;
  });
  final relay = await FakeRelay.start(broadcast: true);
  addTearDown(relay.stop);
  Future<DmRepository> clientFor(String privateKey) async {
    final channels = _LoopbackChannels(relay.port);
    final signer = LocalNostrSigner(privateKey);
    RelayBase createRelay(String url) =>
        RelayBase(url, RelayStatus(url), channelFactory: channels);
    final nostr = Nostr(signer, [], createRelay, channelFactory: channels);
    final manager = RelayManager(
      config: RelayManagerConfig(
        defaultRelayUrl: relay.url,
        storage: InMemoryRelayStorage(),
      ),
      relayPool: nostr.relayPool,
    );
    final client = NostrClient.forTesting(
      nostr: nostr,
      relayManager: manager,
    );
    final db = AppDatabase.test(NativeDatabase.memory());
    addTearDown(db.close);
    final owner = getPublicKey(privateKey);
    final service = NIP17MessageService(
      signer: signer,
      senderPublicKey: owner,
      nostrService: client,
    );
    final repository = DmRepository(
      nostrClient: client,
      directMessagesDao: db.directMessagesDao,
      conversationsDao: db.conversationsDao,
      outgoingDmsDao: db.outgoingDmsDao,
      userPubkey: owner,
      signer: signer,
      messageService: service,
    );
    addTearDown(nostr.relayPool.removeAll);
    addTearDown(repository.stopListening);
    await client.initialize();
    await repository.startListening();
    return repository;
  }

  final creator = await clientFor('1' * 64);
  final viewer = await clientFor('2' * 64);
  final address = '34236:${creator.userPubkey}:clip:one';
  final requestClient = SoundRequestDmClient(
    repository: viewer,
    ownerPubkey: viewer.userPubkey,
  );
  final replyClient = SoundRequestDmClient(
    repository: creator,
    ownerPubkey: creator.userPubkey,
  );
  final incoming = creator.watchSoundRequestMessages().firstWhere(
    (messages) => messages.isNotEmpty,
  );
  final requestId = await requestClient.enqueue(
    SoundRequestSendIntent(
      key: 'request-transport-proof',
      recipient: creator.userPubkey,
      content: 'Please enable this sound',
      tags: soundRequestTags(videoAddress: address),
      createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      videoAddress: address,
    ),
  );
  await requestClient.retry(requestId);
  final requests = await incoming.timeout(const Duration(seconds: 15));
  final parsed = parseSoundRequestMessage(
    requests.single,
    ownerPubkey: creator.userPubkey,
    isGroup: false,
  );
  expect(parsed?.videoAddress, address);
  expect(parsed?.senderPubkey, viewer.userPubkey);
  final incomingReply = viewer.watchSoundRequestMessages().firstWhere(
    (messages) => messages.any(
      (m) =>
          parseSoundRequestMessage(
            m,
            ownerPubkey: viewer.userPubkey,
            isGroup: false,
          )?.kind ==
          SoundRequestMessageKind.ready,
    ),
  );
  final audio = 'a' * 64;
  final reply = SoundRequestSendIntent(
    key: 'ready-transport-proof',
    recipient: viewer.userPubkey,
    content: 'Your requested sound is ready',
    tags: soundReadyTags(
      videoAddress: address,
      requestId: requestId,
      audioEventId: audio,
    ),
    createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    videoAddress: address,
    requestId: requestId,
  );
  final replyId = await replyClient.enqueue(reply);
  await replyClient.retry(replyId);
  final replies = await incomingReply.timeout(const Duration(seconds: 15));
  final ready = replies
      .map(
        (m) => parseSoundRequestMessage(
          m,
          ownerPubkey: viewer.userPubkey,
          isGroup: false,
        ),
      )
      .whereType<SoundRequestMessage>()
      .singleWhere((m) => m.kind == SoundRequestMessageKind.ready);
  expect(ready.requestId, requestId);
  expect(ready.audioEventId, audio);
  expect(await replyClient.enqueue(reply), replyId);
  expect(
    relay.receivedFrames
        .where((frame) => frame[0] == 'EVENT')
        .map((frame) => (frame[1] as Map)['kind']),
    everyElement(isNot(4)),
  );
}
