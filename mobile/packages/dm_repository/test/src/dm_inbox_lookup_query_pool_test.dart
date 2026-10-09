// ABOUTME: Recipient kind-10050 lookup against a real NostrClient query pool.
// ABOUTME: A saturated pool must not starve the indexer leg (#10004).

import 'package:db_client/db_client.dart' hide Filter;
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' show NIP17SendResult, NIP17SendSuccess;
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:nostr_sdk/relay/client_connected.dart';

class _MockRelayManager extends Mock implements RelayManager {}

class _MockDirectMessagesDao extends Mock implements DirectMessagesDao {}

class _MockConversationsDao extends Mock implements ConversationsDao {}

/// A relay whose every frame the test writes by hand.
class _ScriptedRelay extends Relay {
  _ScriptedRelay(String url) : super(url, RelayStatus(url));

  /// Subscription ids of the `REQ`s this relay was sent, in order.
  final List<String> reqSubIds = [];

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
    }
    return true;
  }

  Future<void> deliver(List<dynamic> json) async {
    final dynamic result = onMessage!(this, json);
    if (result is Future) await result;
  }

  /// Waits, in real time, for the pool to register the [index]th `REQ`.
  Future<String> awaitReq(
    int index, {
    Duration within = const Duration(seconds: 6),
  }) async {
    final giveUp = DateTime.now().add(within);
    while (DateTime.now().isBefore(giveUp)) {
      if (reqSubIds.length > index && checkQuery(reqSubIds[index])) {
        return reqSubIds[index];
      }
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    fail('$url never received REQ #$index');
  }
}

const _secretKey =
    '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';
const _poolRelayUrl = 'wss://pool.example';
const _indexerUrl = 'wss://indexer.example';
const _inboxRelayUrl = 'wss://inbox.example';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'a recipient whose inbox list is on the indexer resolves found while '
    'the query pool is saturated, and the invite is not held (#10004)',
    () async {
      final tempRelays = <String, _ScriptedRelay>{};
      final nostr = Nostr(
        LocalNostrSigner(_secretKey),
        [],
        (url) => tempRelays.putIfAbsent(url, () => _ScriptedRelay(url)),
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

      final repository = DmRepository(
        nostrClient: client,
        directMessagesDao: _MockDirectMessagesDao(),
        conversationsDao: _MockConversationsDao(),
        dmInboxLookupRelays: const [_indexerUrl],
      );

      // The collaborator, and the inbox list they published to the indexer.
      final recipient = await nostr.ensurePublicKey();
      final inboxList = (await nostr.nostrSigner.signEvent(
        Event(recipient, EventKind.dmRelaysList, const [
          ['relay', _inboxRelayUrl],
        ], ''),
      ))!;

      // Feed reads hold every query slot past the indexer leg's 1s slot
      // window, the way they do right after a publish.
      final occupants = Future.wait([
        for (var i = 0; i < NostrClient.maxConcurrentQueries; i++)
          client.readEvents(
            [
              Filter(kinds: const [EventKind.textNote]),
            ],
            useCache: false,
            timeout: const Duration(milliseconds: 1500),
          ),
      ]);
      await pooled.awaitReq(NostrClient.maxConcurrentQueries - 1);

      final lookup = repository.resolveDmInboxRelaysDetailed(recipient);

      // The indexer has the list, if the leg reaches it while the feed reads
      // still hold the pool. A leg queued behind them is skipped unsent, and
      // the lookup's outcome below is what shows it.
      final indexer = await () async {
        final giveUp = DateTime.now().add(const Duration(seconds: 1));
        while (DateTime.now().isBefore(giveUp)) {
          for (final entry in tempRelays.entries) {
            if (entry.key.startsWith(_indexerUrl)) return entry.value;
          }
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
        return null;
      }();
      if (indexer != null) {
        final indexerSub = await indexer.awaitReq(0);
        await indexer.deliver(['EVENT', indexerSub, inboxList.toJson()]);
        await indexer.deliver(['EOSE', indexerSub]);
      }

      // The pool leg gets its slot once the feed reads end, and the pooled
      // relay has nothing.
      final poolSub = await pooled.awaitReq(
        NostrClient.maxConcurrentQueries,
      );
      await pooled.deliver(['EOSE', poolSub]);

      final inbox = await lookup;
      await occupants;

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
}
