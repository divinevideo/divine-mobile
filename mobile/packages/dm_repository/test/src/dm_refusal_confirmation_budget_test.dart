// ABOUTME: Regression coverage for preserving delayed NIP-04 refusal
// ABOUTME: confirmation across inbox opens, reconnects, and active drains.

import 'dart:async';

import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/relay/query_result.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockDirectMessagesDao extends Mock implements DirectMessagesDao {}

class _MockConversationsDao extends Mock implements ConversationsDao {}

class _FakeEvent extends Fake implements Event {}

const _pubkey =
    'a1b2c3d4e5f6789012345678901234567890abcdef1234567890123456789012';
const _privateKey =
    'd4e5f6789012345678901234567890abcdef1234567890123456789012ab12c3';

void main() {
  late _MockNostrClient nostrClient;
  late _MockDirectMessagesDao directMessagesDao;
  late _MockConversationsDao conversationsDao;
  late StreamController<Map<String, RelayConnectionStatus>> relayStatus;
  late DmSyncState syncState;

  setUpAll(() {
    registerFallbackValue(_FakeEvent());
    registerFallbackValue(Duration.zero);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'dm.oldestSyncedAt.$_pubkey': 100,
      'dm.historyDrainVersion.$_pubkey': DmSyncState.currentDrainVersion,
    });
    syncState = DmSyncState(await SharedPreferences.getInstance());
    nostrClient = _MockNostrClient();
    directMessagesDao = _MockDirectMessagesDao();
    conversationsDao = _MockConversationsDao();
    relayStatus =
        StreamController<Map<String, RelayConnectionStatus>>.broadcast();
    when(() => nostrClient.connectedRelayCount).thenReturn(1);
    when(() => nostrClient.configuredRelayCount).thenReturn(1);
    when(() => nostrClient.relayStatuses).thenReturn(const {});
    when(
      () => nostrClient.relayStatusStream,
    ).thenAnswer((_) => relayStatus.stream);
    when(
      () => conversationsDao.backfillCurrentUserHasSent(any()),
    ).thenAnswer((_) async => 0);
    when(
      () => conversationsDao.backfillLatestMessagePreviews(
        ownerPubkey: any(named: 'ownerPubkey'),
      ),
    ).thenAnswer((_) async => 0);
    when(
      () => conversationsDao.getAllConversations(
        ownerPubkey: any(named: 'ownerPubkey'),
      ),
    ).thenAnswer((_) async => []);
    when(
      () => conversationsDao.lastSentTimestampsByConversation(
        any(),
        ownerPubkey: any(named: 'ownerPubkey'),
      ),
    ).thenAnswer((_) async => <String, int>{});
    when(
      () => directMessagesDao.hasGiftWrap(any()),
    ).thenAnswer((_) async => false);
  });

  tearDown(() async {
    await relayStatus.close();
  });

  DmRepository makeRepository() => DmRepository(
    nostrClient: nostrClient,
    directMessagesDao: directMessagesDao,
    conversationsDao: conversationsDao,
    syncState: syncState,
    userPubkey: _pubkey,
    signer: LocalNostrSigner(_privateKey),
    verifyIsolateSpawner: () async => _InlineVerifyWorker(),
  );

  void stubAnsweredHistory() {
    when(
      () => nostrClient.queryEventsDetailed(
        any(),
        subscriptionId: any(named: 'subscriptionId'),
        useCache: any(named: 'useCache'),
        tempRelays: any(named: 'tempRelays'),
        requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
        acceptRelayClosedWhenOthersAnswered: any(
          named: 'acceptRelayClosedWhenOthersAnswered',
        ),
        timeout: any(named: 'timeout'),
      ),
    ).thenAnswer((inv) async {
      return (events: const <Event>[], timedOut: false, noRelays: false);
    });
  }

  QueryResult refusal() => const QueryResult(
    events: [],
    endedBy: QueryEnd.relayClosed,
    answeredNetworkRelayCount: 1,
    closedRelayReasons: {'wss://refusing.example': 'error'},
  );

  test('inbox opens preserve the original delayed confirmation slot', () {
    fakeAsync((async) {
      stubAnsweredHistory();
      var reads = 0;
      when(
        () => nostrClient.readEvents(
          any(),
          subscriptionId: any(named: 'subscriptionId'),
          useCache: any(named: 'useCache'),
          requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
        ),
      ).thenAnswer((_) async {
        reads++;
        return refusal();
      });
      final repository = makeRepository();

      unawaited(repository.backfillHistoryIfNeeded());
      async.flushMicrotasks();
      expect(reads, 1);
      for (var i = 0; i < 3; i++) {
        unawaited(repository.backfillHistoryIfNeeded());
        async.flushMicrotasks();
      }
      expect(reads, 4);

      async
        ..elapse(DmHistoryDrainConfig.deferredRetryDelays.first)
        ..flushMicrotasks();

      expect(reads, 5);
      expect(syncState.historyDrainComplete(_pubkey), isTrue);
    });
  });

  test('reconnect sweep does not cancel the confirming timer', () {
    fakeAsync((async) {
      stubAnsweredHistory();
      var reads = 0;
      when(
        () => nostrClient.readEvents(
          any(),
          subscriptionId: any(named: 'subscriptionId'),
          useCache: any(named: 'useCache'),
          requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
        ),
      ).thenAnswer((_) async {
        reads++;
        return refusal();
      });
      final repository = makeRepository();

      unawaited(repository.backfillHistoryIfNeeded());
      async.flushMicrotasks();
      relayStatus.add({
        'wss://new.example': RelayConnectionStatus.connected(
          'wss://new.example',
        ),
      });
      async.flushMicrotasks();
      expect(reads, 2);
      expect(syncState.historyDrainComplete(_pubkey), isFalse);

      async
        ..elapse(DmHistoryDrainConfig.deferredRetryDelays.first)
        ..flushMicrotasks();

      expect(reads, 3);
      expect(syncState.historyDrainComplete(_pubkey), isTrue);
    });
  });

  test(
    'timer firing during a non-confirming drain queues a confirming pass',
    () {
      fakeAsync((async) {
        stubAnsweredHistory();
        final activeRead = Completer<QueryResult>();
        var reads = 0;
        when(
          () => nostrClient.readEvents(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
            useCache: any(named: 'useCache'),
            requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
          ),
        ).thenAnswer((_) {
          reads++;
          return reads == 2 ? activeRead.future : Future.value(refusal());
        });
        final repository = makeRepository();

        unawaited(repository.backfillHistoryIfNeeded());
        async.flushMicrotasks();
        expect(reads, 1);
        unawaited(repository.backfillHistoryIfNeeded());
        async.flushMicrotasks();
        expect(reads, 2);
        async
          ..elapse(DmHistoryDrainConfig.deferredRetryDelays.first)
          ..flushMicrotasks();
        expect(reads, 2);

        activeRead.complete(refusal());
        async.flushMicrotasks();

        expect(reads, 3);
        expect(syncState.historyDrainComplete(_pubkey), isTrue);
      });
    },
  );

  test('stopListening clears a confirmation queued behind an active drain', () {
    fakeAsync((async) {
      stubAnsweredHistory();
      final activeRead = Completer<QueryResult>();
      var reads = 0;
      when(
        () => nostrClient.readEvents(
          any(),
          subscriptionId: any(named: 'subscriptionId'),
          useCache: any(named: 'useCache'),
          requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
        ),
      ).thenAnswer((_) {
        reads++;
        return reads == 2 ? activeRead.future : Future.value(refusal());
      });
      final repository = makeRepository();

      unawaited(repository.backfillHistoryIfNeeded());
      async.flushMicrotasks();
      unawaited(repository.backfillHistoryIfNeeded());
      async
        ..flushMicrotasks()
        ..elapse(DmHistoryDrainConfig.deferredRetryDelays.first)
        ..flushMicrotasks();
      unawaited(repository.stopListening());
      async.flushMicrotasks();
      activeRead.complete(refusal());
      async.flushMicrotasks();

      expect(reads, 2);
    });
  });
}

class _InlineVerifyWorker implements DmVerifyWorker {
  @override
  Future<bool> verifyPart(Event event) async => event.isValid && event.isSigned;

  @override
  void close() {}
}
