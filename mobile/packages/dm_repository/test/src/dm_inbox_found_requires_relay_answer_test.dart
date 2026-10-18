// ABOUTME: #8528 — a kind-10050 held only in the local event cache must not
// ABOUTME: clear a chat's nip04 latch or let history restore record itself
// ABOUTME: complete, and history restore must still find a list kept off-pool.

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
import 'package:shared_preferences/shared_preferences.dart';

class _MockRelayManager extends Mock implements RelayManager {}

class _MockMessageService extends Mock implements NIP17MessageService {}

class _FakeEvent extends Fake implements Event {}

/// How a [_ScriptedRelay] answers a REQ that reads a kind-10050.
enum _InboxReads { silent, empty, serve }

/// How a [_ScriptedRelay] answers what it is sent.
typedef _Script = ({bool answersPages, _InboxReads inboxReads, Event? list});

const _Script _silent = (
  answersPages: false,
  inboxReads: _InboxReads.silent,
  list: null,
);

/// A relay whose answers the test scripts. By default it answers no REQ: no
/// EVENT, no EOSE. It accepts every EVENT with `OK`, so a publish settles
/// inside the test that made it.
class _ScriptedRelay extends Relay {
  _ScriptedRelay(String url, this.script) : super(url, RelayStatus(url));

  final _Script script;

  /// Every frame this relay was handed.
  final List<List<dynamic>> sent = [];

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
    sent.add(message);
    _frames.add(message);
    if (message.length > 2 && message[0] == 'REQ') {
      final subId = message[1] as String;
      if (_readsKind(message, EventKind.dmRelaysList)) {
        switch (script.inboxReads) {
          case _InboxReads.silent:
            break;
          case _InboxReads.empty:
            unawaited(_answer(subId, const []));
          case _InboxReads.serve:
            unawaited(_answer(subId, [script.list!]));
        }
      } else if (script.answersPages) {
        unawaited(_answer(subId, const []));
      }
    } else if (message.length > 1 &&
        message[0] == 'EVENT' &&
        message[1] is Map) {
      unawaited(_accept((message[1] as Map)['id'] as String));
    }
    return true;
  }

  Future<void> _accept(String eventId) async {
    await pumpEventQueue();
    await _deliver(['OK', eventId, true, '']);
  }

  Future<void> _answer(String subId, List<Event> events) async {
    // The pool registers a query only once its send returns.
    for (var i = 0; i < 400 && !checkQuery(subId); i++) {
      await pumpEventQueue();
    }
    for (final event in events) {
      await _deliver(['EVENT', subId, event.toJson()]);
    }
    await _deliver(['EOSE', subId]);
  }

  Future<void> _deliver(List<dynamic> frame) async {
    final dynamic result = onMessage!(this, frame);
    if (result is Future) await result;
  }
}

bool _readsKind(List<dynamic> req, int kind) => req
    .skip(2)
    .whereType<Map<dynamic, dynamic>>()
    .any((filter) => (filter['kinds'] as List?)?.contains(kind) ?? false);

const _ownerKey =
    '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';
const _peerKey =
    '2222222222222222222222222222222222222222222222222222222222222222';
const _poolRelayUrl = 'wss://pool.example';
const _indexerUrl = 'wss://indexer.example';
const _peerInboxUrl = 'wss://peer-inbox.example';
const _ownInboxUrl = 'wss://own-inbox.example';
const _divineInboxUrl = 'wss://divine-inbox.example';
const _rumorId =
    '3333333333333333333333333333333333333333333333333333333333333333';
const _wrapId =
    '4444444444444444444444444444444444444444444444444444444444444444';

final String _owner = getPublicKey(_ownerKey);
final String _peer = getPublicKey(_peerKey);

typedef _Harness = ({
  AppDatabase db,
  NostrClient client,
  _ScriptedRelay pooled,
  Map<String, _ScriptedRelay> tempRelays,
  DmRepository repository,
  List<Map<Symbol, dynamic>> sendRumorCalls,
});

/// A [DmRepository] over a real [NostrClient] whose event cache is a real
/// in-memory database. Each relay answers as [script] says for its URL;
/// by default every relay is silent.
Future<_Harness> _harness({
  _Script Function(String url)? script,
  DmSyncState? syncState,
  bool Function(String url)? allowRelay,
  String? dmInboxRelayUrl,
}) async {
  final scriptFor = script ?? (_) => _silent;
  final db = AppDatabase.test(NativeDatabase.memory());
  addTearDown(db.close);
  final tempRelays = <String, _ScriptedRelay>{};
  final nostr = Nostr(
    LocalNostrSigner(_ownerKey),
    [],
    (url) =>
        tempRelays.putIfAbsent(url, () => _ScriptedRelay(url, scriptFor(url))),
  );
  final pooled = _ScriptedRelay(_poolRelayUrl, scriptFor(_poolRelayUrl));
  expect(await nostr.relayPool.add(pooled), isTrue);
  final relayManager = _MockRelayManager();
  when(() => relayManager.connectedRelays).thenReturn([_poolRelayUrl]);
  when(() => relayManager.configuredRelays).thenReturn([_poolRelayUrl]);
  when(() => relayManager.connectedRelayCount).thenReturn(1);
  when(() => relayManager.configuredRelayCount).thenReturn(1);
  when(
    () => relayManager.currentStatuses,
  ).thenReturn(<String, RelayConnectionStatus>{});
  when(
    () => relayManager.statusStream,
  ).thenAnswer((_) => const Stream.empty());
  when(() => relayManager.isRelayAllowed(any())).thenAnswer(
    (inv) => allowRelay?.call(inv.positionalArguments.single as String) ?? true,
  );
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
    dmInboxRelayUrl: dmInboxRelayUrl,
    syncState: syncState,
  );
  addTearDown(repository.stopListening);
  return (
    db: db,
    client: client,
    pooled: pooled,
    tempRelays: tempRelays,
    repository: repository,
    sendRumorCalls: sendRumorCalls,
  );
}

/// A kind-10050 signed with [privateKey], naming [relay].
Event _inboxList(
  String privateKey,
  String relay, {
  int createdAt = 1700000000,
}) => Event(
  getPublicKey(privateKey),
  EventKind.dmRelaysList,
  [
    ['relay', relay],
  ],
  '',
  createdAt: createdAt,
)..sign(privateKey);

/// Caches a kind-10050 signed with [privateKey] and shows the cache would
/// serve it: a single-filter read returns it although no relay answers. The
/// contact lookup sends two filters, which `NostrClient` never serves from the
/// cache, so the contact tests guard that request shape and the lookup's own
/// `useCache: false` together.
Future<void> _seedCachedInbox(
  _Harness h, {
  String privateKey = _peerKey,
  String relay = _peerInboxUrl,
}) async {
  final cached = _inboxList(privateKey, relay);
  await h.db.nostrEventsDao.upsertEvent(cached);

  final read = await h.client.queryEventsDetailed(
    [
      Filter(
        authors: [getPublicKey(privateKey)],
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

/// Whether [relay] was sent a REQ reading [kind].
bool _asked(_ScriptedRelay? relay, int kind) =>
    relay?.sent.any((frame) => _readsKind(frame, kind)) ?? false;

/// The temp relay the pool dialled for [url], if any.
_ScriptedRelay? _dialled(_Harness h, String url) {
  for (final entry in h.tempRelays.entries) {
    if (entry.key.startsWith(url)) return entry.value;
  }
  return null;
}

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

  group('backfillHistoryIfNeeded', () {
    late DmSyncState syncState;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      syncState = DmSyncState(await SharedPreferences.getInstance());
    });

    test(
      'does not record history complete from a cached own kind-10050 that no '
      'relay returns',
      () async {
        final h = await _harness(
          syncState: syncState,
          script: (_) => (
            answersPages: true,
            inboxReads: _InboxReads.silent,
            list: null,
          ),
        );
        await _seedCachedInbox(h, privateKey: _ownerKey, relay: _ownInboxUrl);

        await h.repository.backfillHistoryIfNeeded();

        expect(syncState.historyDrainComplete(_owner), isFalse);
        expect(syncState.drainCoveredOwnInbox(_owner), isFalse);
      },
      timeout: const Timeout(Duration(seconds: 90)),
    );

    test(
      'reads the own kind-10050 from the relays it names and pages them when '
      'the pool holds no list',
      () async {
        final served = _inboxList(
          _ownerKey,
          _ownInboxUrl,
          createdAt: 1700000100,
        );
        final h = await _harness(
          syncState: syncState,
          script: (url) => (
            answersPages: true,
            inboxReads: url.startsWith(_ownInboxUrl)
                ? _InboxReads.serve
                : _InboxReads.empty,
            list: served,
          ),
        );
        await _seedCachedInbox(h, privateKey: _ownerKey, relay: _ownInboxUrl);

        await h.repository.backfillHistoryIfNeeded();

        expect(syncState.historyDrainComplete(_owner), isTrue);
        expect(syncState.drainCoveredOwnInbox(_owner), isTrue);
        final ownInbox = _dialled(h, _ownInboxUrl);
        expect(
          ownInbox?.sent.where((f) => _readsKind(f, EventKind.giftWrap)),
          isNotEmpty,
          reason: 'history restore pages the relays the list names',
        );
      },
      timeout: const Timeout(Duration(seconds: 90)),
    );

    test(
      'keeps routing the self-copy to the cached own kind-10050 when every '
      'relay answers without it',
      () async {
        final h = await _harness(
          syncState: syncState,
          script: (_) => (
            answersPages: true,
            inboxReads: _InboxReads.empty,
            list: null,
          ),
        );
        await _seedCachedInbox(h, privateKey: _ownerKey, relay: _ownInboxUrl);

        await h.repository.backfillHistoryIfNeeded();
        final _ = await h.repository.sendMessage(
          recipientPubkey: _peer,
          content: 'hi',
        );

        // The memo routes the live subscription and the self-copy by the
        // list it found; history restore's read must not take that away.
        expect(
          h.sendRumorCalls.single[#selfWrapTargetRelays],
          contains(_ownInboxUrl),
        );
      },
      timeout: const Timeout(Duration(seconds: 90)),
    );

    test(
      "pages the cached list's relays once before recording when every relay "
      'answers without the list',
      () async {
        final h = await _harness(
          syncState: syncState,
          script: (_) => (
            answersPages: true,
            inboxReads: _InboxReads.empty,
            list: null,
          ),
        );
        await _seedCachedInbox(h, privateKey: _ownerKey, relay: _ownInboxUrl);

        await h.repository.backfillHistoryIfNeeded();

        expect(syncState.historyDrainComplete(_owner), isTrue);
        expect(
          _asked(_dialled(h, _ownInboxUrl), EventKind.giftWrap),
          isTrue,
          reason: 'older history may still sit on the relays the list named',
        );
      },
      timeout: const Timeout(Duration(seconds: 90)),
    );

    test(
      "leaves out the listed relays this build's relay lock refuses, and "
      'still completes',
      () async {
        final h = await _harness(
          syncState: syncState,
          allowRelay: (url) => !url.startsWith(_ownInboxUrl),
          script: (_) => (
            answersPages: true,
            inboxReads: _InboxReads.empty,
            list: null,
          ),
        );
        await _seedCachedInbox(h, privateKey: _ownerKey, relay: _ownInboxUrl);

        await h.repository.backfillHistoryIfNeeded();

        // A leg whose every relay is refused never leaves this device; read
        // as unanswered it would stop history restore completing (#10148).
        expect(syncState.historyDrainComplete(_owner), isTrue);
        expect(_dialled(h, _ownInboxUrl), isNull);
      },
      timeout: const Timeout(Duration(seconds: 90)),
    );

    test(
      'does not ask a pool relay the list names a second time',
      () async {
        final h = await _harness(
          syncState: syncState,
          script: (_) => (
            answersPages: true,
            inboxReads: _InboxReads.empty,
            list: null,
          ),
        );
        await _seedCachedInbox(h, privateKey: _ownerKey, relay: _poolRelayUrl);
        final beforeRestore = h.pooled.sent.length;

        await h.repository.backfillHistoryIfNeeded();

        // The memo's read and history restore's pool leg; the listed leg
        // skips a relay the pool leg already asked.
        expect(
          h.pooled.sent
              .skip(beforeRestore)
              .where((f) => _readsKind(f, EventKind.dmRelaysList)),
          hasLength(2),
        );
      },
      timeout: const Timeout(Duration(seconds: 90)),
    );

    test(
      "asks Divine's inbox relay outside the pool and pages it when it holds "
      'the list',
      () async {
        final served = _inboxList(_ownerKey, _divineInboxUrl);
        final h = await _harness(
          syncState: syncState,
          dmInboxRelayUrl: _divineInboxUrl,
          script: (url) => (
            answersPages: true,
            inboxReads: url.startsWith(_divineInboxUrl)
                ? _InboxReads.serve
                : _InboxReads.empty,
            list: served,
          ),
        );

        await h.repository.backfillHistoryIfNeeded();

        final divine = _dialled(h, _divineInboxUrl);
        expect(_asked(divine, EventKind.dmRelaysList), isTrue);
        expect(_asked(divine, EventKind.giftWrap), isTrue);
        expect(syncState.drainCoveredOwnInbox(_owner), isTrue);
      },
      timeout: const Timeout(Duration(seconds: 90)),
    );
  });
}
