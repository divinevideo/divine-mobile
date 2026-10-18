// ABOUTME: #8528 — a counterparty's kind-10050 held only in the local event
// ABOUTME: cache must not read `found` while no relay answers: `found` clears a
// ABOUTME: thread's nip04 latch for good, on a copy no relay confirmed.

import 'dart:async';

import 'package:db_client/db_client.dart' hide Filter;
import 'package:dm_repository/dm_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' show NIP17SendResult;
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:nostr_sdk/relay/client_connected.dart';

class _MockRelayManager extends Mock implements RelayManager {}

class _MockMessageService extends Mock implements NIP17MessageService {}

class _FakeEvent extends Fake implements Event {}

/// A relay that answers no REQ: no EVENT, no EOSE. It accepts every EVENT
/// with `OK`, so a publish settles inside the test that made it.
class _SilentRelay extends Relay {
  _SilentRelay(String url) : super(url, RelayStatus(url));

  final _frames = StreamController<List<dynamic>>.broadcast();

  /// Frames handed to this relay after a listener subscribes; nothing is
  /// replayed.
  Stream<List<dynamic>> get frames => _frames.stream;

  @override
  Future<bool> doConnect() async {
    relayStatus.connected = ClientConnected.connected;
    return true;
  }

  @override
  Future<void> disconnect() async {
    relayStatus.connected = ClientConnected.disconnect;
  }

  @override
  Future<bool> send(
    List<dynamic> message, {
    bool queueIfFailed = true,
    bool skipReconnect = false,
    DateTime? deadline,
  }) async {
    _frames.add(message);
    if (message.length > 1 && message[0] == 'EVENT' && message[1] is Map) {
      unawaited(_accept((message[1] as Map)['id'] as String));
    }
    return true;
  }

  Future<void> _accept(String eventId) async {
    await pumpEventQueue();
    final dynamic result = onMessage!(this, ['OK', eventId, true, '']);
    if (result is Future) await result;
  }
}

const _ownerKey =
    '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';
const _peerKey =
    '2222222222222222222222222222222222222222222222222222222222222222';
const _poolRelayUrl = 'wss://pool.example';
const _indexerUrl = 'wss://indexer.example';
const _peerInboxUrl = 'wss://peer-inbox.example';
const _rumorId =
    '3333333333333333333333333333333333333333333333333333333333333333';
const _wrapId =
    '4444444444444444444444444444444444444444444444444444444444444444';

final String _owner = getPublicKey(_ownerKey);
final String _peer = getPublicKey(_peerKey);

typedef _Harness = ({
  AppDatabase db,
  NostrClient client,
  _SilentRelay pooled,
  DmRepository repository,
  List<Map<Symbol, dynamic>> sendRumorCalls,
});

/// A [DmRepository] over a real [NostrClient] whose event cache is a real
/// in-memory database, and whose every relay is silent.
Future<_Harness> _harness() async {
  final db = AppDatabase.test(NativeDatabase.memory());
  addTearDown(db.close);
  final tempRelays = <String, _SilentRelay>{};
  final nostr = Nostr(
    LocalNostrSigner(_ownerKey),
    [],
    (url) => tempRelays.putIfAbsent(url, () => _SilentRelay(url)),
  );
  final pooled = _SilentRelay(_poolRelayUrl);
  expect(await nostr.relayPool.add(pooled), isTrue);
  final relayManager = _MockRelayManager();
  when(() => relayManager.connectedRelays).thenReturn([_poolRelayUrl]);
  when(() => relayManager.configuredRelays).thenReturn([_poolRelayUrl]);
  when(() => relayManager.isRelayAllowed(any())).thenReturn(true);
  when(() => relayManager.diagnosticsSink).thenReturn(null);
  when(relayManager.dispose).thenAnswer((_) async {});
  final client = NostrClient.forTesting(
    nostr: nostr,
    relayManager: relayManager,
    dbClient: AppDbClient(DbClient(generatedDatabase: db), db),
  );
  addTearDown(client.dispose);

  final sendRumorCalls = <Map<Symbol, dynamic>>[];
  final messageService = _MockMessageService();
  when(() => messageService.canSendTo(any())).thenAnswer((_) async => true);
  when(
    () => messageService.buildRumor(
      recipientPubkey: any(named: 'recipientPubkey'),
      content: any(named: 'content'),
      eventKind: any(named: 'eventKind'),
      additionalTags: any(named: 'additionalTags'),
      createdAt: any(named: 'createdAt'),
    ),
  ).thenAnswer(
    (inv) => Event(_owner, EventKind.privateDirectMessage, [
      ['p', _peer],
    ], inv.namedArguments[#content] as String),
  );
  when(
    () => messageService.sendRumor(
      rumorEvent: any(named: 'rumorEvent'),
      recipientPubkey: any(named: 'recipientPubkey'),
      targetRelays: any(named: 'targetRelays'),
      selfWrapTargetRelays: any(named: 'selfWrapTargetRelays'),
      awaitRecipientOk: any(named: 'awaitRecipientOk'),
      selfWrapOnSoftUnconfirmed: any(named: 'selfWrapOnSoftUnconfirmed'),
      recipientWrapBuildTimeout: any(named: 'recipientWrapBuildTimeout'),
      selfWrapBuildTimeout: any(named: 'selfWrapBuildTimeout'),
      onSelfWrapDue: any(named: 'onSelfWrapDue'),
    ),
  ).thenAnswer((inv) async {
    sendRumorCalls.add(inv.namedArguments);
    return NIP17SendResult.success(
      rumorEventId: _rumorId,
      messageEventId: _wrapId,
      recipientPubkey: _peer,
    );
  });

  final repository = DmRepository(
    nostrClient: client,
    messageService: messageService,
    directMessagesDao: DirectMessagesDao(db),
    conversationsDao: ConversationsDao(db),
    processedGiftWrapsDao: ProcessedGiftWrapsDao(db),
    userPubkey: _owner,
    signer: LocalNostrSigner(_ownerKey),
    dmInboxLookupRelays: const [_indexerUrl],
  );
  addTearDown(repository.stopListening);
  return (
    db: db,
    client: client,
    pooled: pooled,
    repository: repository,
    sendRumorCalls: sendRumorCalls,
  );
}

/// Caches the peer's kind-10050 and shows the cache would serve it: a
/// single-filter read returns it although no relay answers. The recipient
/// lookup sends two filters, which `NostrClient` never serves from the cache,
/// so these tests guard that request shape and the lookup's own
/// `useCache: false` together.
Future<void> _seedCachedInbox(_Harness h) async {
  final cached = Event(
    _peer,
    EventKind.dmRelaysList,
    [
      ['relay', _peerInboxUrl],
    ],
    '',
    createdAt: 1700000000,
  )..sign(_peerKey);
  await h.db.nostrEventsDao.upsertEvent(cached);

  final read = await h.client.queryEventsDetailed(
    [
      Filter(
        authors: [_peer],
        kinds: const [EventKind.dmRelaysList],
        limit: 1,
      ),
    ],
    timeout: const Duration(seconds: 1),
  );
  expect(read.events.map((e) => e.id), contains(cached.id));
}

bool _isKind4Event(List<dynamic> frame) =>
    frame.length > 1 &&
    frame[0] == 'EVENT' &&
    frame[1] is Map &&
    (frame[1] as Map)['kind'] == EventKind.directMessage;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(_FakeEvent());
    registerFallbackValue(Duration.zero);
  });

  group('resolveDmInboxRelaysDetailed', () {
    late _Harness h;

    setUp(() async {
      h = await _harness();
    });

    test(
      'reads a cached kind-10050 as unreadable, not found, while no relay '
      'answers',
      () async {
        await _seedCachedInbox(h);

        final lookup = await h.repository.resolveDmInboxRelaysDetailed(_peer);

        expect(lookup.state, DmInboxResolution.unreadable);
        expect(lookup.relays, isNull);
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );
  });

  group('sendMessage', () {
    late _Harness h;

    setUp(() async {
      h = await _harness();
    });

    test(
      'keeps a latched thread on nip04 and still sends its kind 4 when the '
      "peer's kind-10050 is only cached",
      () async {
        await _seedCachedInbox(h);
        final conversationId = DmRepository.computeConversationId([
          _owner,
          _peer,
        ]);
        await ConversationsDao(h.db).upsertConversation(
          id: conversationId,
          participantPubkeys: ([_owner, _peer]..sort()).join(','),
          isGroup: false,
          createdAt: 1700000000,
          lastMessageTimestamp: 1700000000,
          ownerPubkey: _owner,
          dmProtocol: 'nip04',
        );
        final kind4 = h.pooled.frames.firstWhere(_isKind4Event);

        final _ = await h.repository.sendMessage(
          recipientPubkey: _peer,
          content: 'hi',
        );
        final kind4Sent = await kind4
            .then((_) => true)
            .timeout(const Duration(seconds: 25), onTimeout: () => false);

        final stored = await ConversationsDao(
          h.db,
        ).getConversation(conversationId, ownerPubkey: _owner);
        expect(stored?.dmProtocol, 'nip04');
        expect(kind4Sent, isTrue);
        expect(h.sendRumorCalls.single[#targetRelays], isNull);
      },
      timeout: const Timeout(Duration(seconds: 90)),
    );
  });
}
