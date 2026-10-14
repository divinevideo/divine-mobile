// ABOUTME: Recipient kind-10050 lookup against a real NostrClient query pool.
// ABOUTME: A saturated pool must not starve the indexer leg (#10004).

import 'dart:async';

import 'package:db_client/db_client.dart' hide Filter;
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' show NIP17SendResult, NIP17SendSuccess;
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:nostr_sdk/relay/client_connected.dart';
import 'package:unified_logger/unified_logger.dart';

class _MockRelayManager extends Mock implements RelayManager {}

class _MockDirectMessagesDao extends Mock implements DirectMessagesDao {}

class _MockConversationsDao extends Mock implements ConversationsDao {}

/// A relay whose every frame the test writes by hand.
class _ScriptedRelay extends Relay {
  _ScriptedRelay(String url) : super(url, RelayStatus(url));

  /// Subscription ids of the `REQ`s this relay was sent, in order.
  final List<String> reqSubIds = [];

  final _reqSent = StreamController<void>.broadcast();

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
    if (message.isNotEmpty && message[0] == 'REQ' && message.length > 1) {
      reqSubIds.add(message[1] as String);
      _reqSent.add(null);
    }
    return true;
  }

  Future<void> deliver(List<dynamic> json) async {
    final dynamic result = onMessage!(this, json);
    if (result is Future) await result;
  }

  /// Waits for the pool to send, then register, the [index]th `REQ`.
  ///
  /// The pool saves a query only once its `send` resolves, so after the frame
  /// arrives the event queue is drained until the registration lands.
  Future<String> awaitReq(
    int index, {
    Duration within = const Duration(seconds: 6),
  }) async {
    while (reqSubIds.length <= index) {
      try {
        await _reqSent.stream.first.timeout(within);
      } on TimeoutException {
        fail('$url never received REQ #$index');
      }
    }
    final subId = reqSubIds[index];
    for (var attempt = 0; attempt < 400 && !checkQuery(subId); attempt++) {
      await pumpEventQueue();
    }
    if (!checkQuery(subId)) fail('$url never registered REQ #$index');
    return subId;
  }
}

const _secretKey =
    '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';
const _poolRelayUrl = 'wss://pool.example';
const _indexerUrl = 'wss://indexer.example';
const _inboxRelayUrl = 'wss://inbox.example';
const _outboxRelayUrl = 'wss://outbox.example';
const _busyOutsideUrl = 'wss://busy-outside.example';

/// A [DmRepository] over a real [NostrClient] and relay pool: one pooled
/// relay, and a [_ScriptedRelay] for each temp relay a read dials.
Future<
  ({
    DmRepository repository,
    NostrClient client,
    Nostr nostr,
    _ScriptedRelay pooled,
    Map<String, _ScriptedRelay> tempRelays,
    Stream<_ScriptedRelay> dialled,
  })
>
_harness() async {
  final tempRelays = <String, _ScriptedRelay>{};
  final dialled = StreamController<_ScriptedRelay>.broadcast();
  addTearDown(dialled.close);
  final nostr = Nostr(
    LocalNostrSigner(_secretKey),
    [],
    (url) => tempRelays.putIfAbsent(url, () {
      final relay = _ScriptedRelay(url);
      dialled.add(relay);
      return relay;
    }),
  );
  final pooled = _ScriptedRelay(_poolRelayUrl);
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
  );
  addTearDown(client.dispose);
  return (
    repository: DmRepository(
      nostrClient: client,
      directMessagesDao: _MockDirectMessagesDao(),
      conversationsDao: _MockConversationsDao(),
      dmInboxLookupRelays: const [_indexerUrl],
    ),
    client: client,
    nostr: nostr,
    pooled: pooled,
    tempRelays: tempRelays,
    dialled: dialled.stream,
  );
}

/// Feed reads holding every query slot until [holdFor] runs out, the way they
/// do right after a publish. `ended` completes when they end.
Future<({Future<void> ended})> _saturatePool(
  NostrClient client,
  _ScriptedRelay pooled, {
  required Duration holdFor,
}) async {
  final occupants = Future.wait([
    for (var i = 0; i < NostrClient.maxConcurrentQueries; i++)
      client.readEvents(
        [
          Filter(kinds: const [EventKind.textNote]),
        ],
        useCache: false,
        timeout: holdFor,
      ),
  ]);
  await pooled.awaitReq(NostrClient.maxConcurrentQueries - 1);
  return (ended: occupants.then((_) {}));
}

/// The temp relay the pool dialled for [url], if it dials one within
/// [within].
Future<_ScriptedRelay?> _dialled(
  Map<String, _ScriptedRelay> tempRelays,
  Stream<_ScriptedRelay> dialled,
  String url, {
  Duration within = const Duration(seconds: 1),
}) async {
  for (final entry in tempRelays.entries) {
    if (entry.key.startsWith(url)) return entry.value;
  }
  try {
    return await dialled
        .firstWhere((relay) => relay.url.startsWith(url))
        .timeout(within);
  } on TimeoutException {
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('recipient kind-10050 lookup on a saturated query pool', () {
    test(
      'a recipient whose inbox list is on the indexer resolves found while '
      'the query pool is saturated, and the invite is not held (#10004)',
      () async {
        final h = await _harness();

        // The collaborator, and the inbox list they published to the indexer.
        final recipient = await h.nostr.ensurePublicKey();
        final inboxList = (await h.nostr.nostrSigner.signEvent(
          Event(recipient, EventKind.dmRelaysList, const [
            ['relay', _inboxRelayUrl],
          ], ''),
        ))!;

        // Held past the indexer leg's 1s slot window.
        final occupants = await _saturatePool(
          h.client,
          h.pooled,
          holdFor: const Duration(milliseconds: 1500),
        );

        final lookup = h.repository.resolveDmInboxRelaysDetailed(recipient);

        // The indexer has the list, if the leg reaches it while the feed reads
        // still hold the pool. A leg queued behind them is skipped unsent, and
        // the lookup's outcome below is what shows it.
        final indexer = await _dialled(h.tempRelays, h.dialled, _indexerUrl);
        if (indexer != null) {
          final indexerSub = await indexer.awaitReq(0);
          await indexer.deliver(['EVENT', indexerSub, inboxList.toJson()]);
          await indexer.deliver(['EOSE', indexerSub]);
        }

        // The pool leg gets its slot once the feed reads end, and the pooled
        // relay has nothing.
        final poolSub = await h.pooled.awaitReq(
          NostrClient.maxConcurrentQueries,
        );
        await h.pooled.deliver(['EOSE', poolSub]);

        final inbox = await lookup;
        await occupants.ended;

        expect(inbox.state, DmInboxResolution.found);
        expect(inbox.relays, [_inboxRelayUrl]);

        // The send path scores the publish against this lookup.
        final published = NIP17SendResult.success(
          rumorEventId: 'rumor',
          messageEventId: 'wrap',
          recipientPubkey: recipient,
        );
        expect(
          downgradeFallbackPoolDelivery(published, inbox.state),
          isA<NIP17SendSuccess>(),
          reason: 'a found inbox must not hold the invite pending',
        );
      },
    );

    test(
      'a pool leg skipped for want of a query slot is logged as never leaving '
      'this device, and still holds the invite (#10004, #7317)',
      () async {
        unawaited(LogCaptureService().clearAllLogs());
        final h = await _harness();
        final recipient = await h.nostr.ensurePublicKey();

        // Held past the pool leg's own slot window: its 5s budget keeps 1s back
        // for the relays, so it waits at most 4s.
        final occupants = await _saturatePool(
          h.client,
          h.pooled,
          holdFor: const Duration(milliseconds: 4500),
        );

        final lookup = h.repository.resolveDmInboxRelaysDetailed(recipient);
        // The indexer answers, and has no list.
        final indexer = await _dialled(h.tempRelays, h.dialled, _indexerUrl);
        expect(indexer, isNotNull);
        await indexer!.deliver(['EOSE', await indexer.awaitReq(0)]);

        final inbox = await lookup;
        await occupants.ended;

        expect(
          h.pooled.reqSubIds,
          hasLength(NostrClient.maxConcurrentQueries),
          reason: 'the pool leg never reached the pooled relay',
        );
        expect(inbox.state, DmInboxResolution.unreadable);
        final published = NIP17SendResult.success(
          rumorEventId: 'rumor',
          messageEventId: 'wrap',
          recipientPubkey: recipient,
        );
        expect(
          downgradeFallbackPoolDelivery(published, inbox.state),
          isNot(isA<NIP17SendSuccess>()),
          reason: 'an unread inbox still holds the invite pending (#7317)',
        );

        final inconclusive = LogCaptureService()
            .getRecentLogs()
            .map((entry) => entry.message)
            .where((message) => message.contains('lookup for'))
            .where((message) => message.contains('was inconclusive'))
            .toList();
        expect(inconclusive, hasLength(1));
        expect(
          inconclusive.single,
          allOf(
            contains('never left this device'),
            contains('no query-pool slot arrived'),
            isNot(contains('not every relay settled')),
          ),
        );
      },
    );
    test(
      'a write-relay leg skipped for want of a query slot is logged as never '
      'leaving this device, and still holds the invite (#10004, #7317)',
      () async {
        unawaited(LogCaptureService().clearAllLogs());
        final h = await _harness();
        final recipient = await h.nostr.ensurePublicKey();
        // The recipient advertises a write relay outside the pool and the
        // indexer, and no inbox list anywhere.
        final relayList = (await h.nostr.nostrSigner.signEvent(
          Event(recipient, EventKind.relayListMetadata, const [
            ['r', _outboxRelayUrl],
          ], ''),
        ))!;

        // Reads that ask only an outside relay hold every slot of the outside
        // pool, so the indexer and write-relay legs cannot get one.
        final busy = Future.wait([
          for (var i = 0; i < NostrClient.maxConcurrentQueries; i++)
            h.client.readEvents(
              [
                Filter(kinds: const [EventKind.textNote]),
              ],
              useCache: false,
              tempRelays: const [_busyOutsideUrl],
              relayTypes: const [RelayType.temp],
              timeout: const Duration(seconds: 8),
            ),
        ]);
        final busyRelay = await _dialled(
          h.tempRelays,
          h.dialled,
          _busyOutsideUrl,
        );
        expect(busyRelay, isNotNull);
        await busyRelay!.awaitReq(NostrClient.maxConcurrentQueries - 1);

        final lookup = h.repository.resolveDmInboxRelaysDetailed(recipient);
        // The pool leg answers with the relay list and no inbox list.
        final poolSub = await h.pooled.awaitReq(0);
        await h.pooled.deliver(['EVENT', poolSub, relayList.toJson()]);
        await h.pooled.deliver(['EOSE', poolSub]);

        final inbox = await lookup;
        expect(
          h.tempRelays.keys.where((url) => url.startsWith(_outboxRelayUrl)),
          isEmpty,
          reason: 'the write-relay leg never reached the outbox relay',
        );
        expect(inbox.state, DmInboxResolution.unreadable);

        final writeLeg = LogCaptureService()
            .getRecentLogs()
            .map((entry) => entry.message)
            .where((message) => message.contains('on their write relays'))
            .toList();
        expect(writeLeg, hasLength(1));
        expect(
          writeLeg.single,
          allOf(
            contains('never left this device'),
            isNot(contains('not every relay settled')),
          ),
        );
        await busy;
      },
    );
  });
}
