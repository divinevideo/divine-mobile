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

  group('DM refusal confirmation retry budget', () {
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
      'a flapping relay does not re-drive the armed confirmation window',
      () {
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

          relayStatus.add({
            'wss://new.example': RelayConnectionStatus.disconnected(
              'wss://new.example',
            ),
            'wss://flap.example': RelayConnectionStatus.connected(
              'wss://flap.example',
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
      },
    );

    test('an inbox open still leaves one reconnect sweep in the window', () {
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
        unawaited(repository.backfillHistoryIfNeeded());
        async.flushMicrotasks();
        expect(reads, 2);

        relayStatus.add({
          'wss://new.example': RelayConnectionStatus.connected(
            'wss://new.example',
          ),
        });
        async.flushMicrotasks();
        expect(reads, 3);
        expect(syncState.historyDrainComplete(_pubkey), isFalse);

        async
          ..elapse(DmHistoryDrainConfig.deferredRetryDelays.first)
          ..flushMicrotasks();

        expect(reads, 4);
        expect(syncState.historyDrainComplete(_pubkey), isTrue);
      });
    });

    test(
      'a preserved timer does not confirm a refusal first seen after it armed',
      () {
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
            final relay = reads == 1
                ? 'wss://first.example'
                : 'wss://second.example';
            return QueryResult(
              events: const [],
              endedBy: QueryEnd.relayClosed,
              answeredNetworkRelayCount: 1,
              closedRelayReasons: {relay: 'error'},
            );
          });
          final repository = makeRepository();

          unawaited(repository.backfillHistoryIfNeeded());
          async.flushMicrotasks();
          unawaited(repository.backfillHistoryIfNeeded());
          async
            ..flushMicrotasks()
            ..elapse(DmHistoryDrainConfig.deferredRetryDelays.first)
            ..flushMicrotasks();

          expect(reads, 3);
          expect(syncState.historyDrainComplete(_pubkey), isFalse);

          async
            ..elapse(DmHistoryDrainConfig.deferredRetryDelays[1])
            ..flushMicrotasks();

          expect(reads, 4);
          expect(syncState.historyDrainComplete(_pubkey), isTrue);
        });
      },
    );

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

    test(
      'stopListening clears a confirmation queued behind an active drain',
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
      },
    );

    test(
      'a restart does not run a confirmation queued before stopListening',
      () {
        fakeAsync((async) {
          stubAnsweredHistory();
          when(
            () => nostrClient.subscribe(
              any(),
              subscriptionId: any(named: 'subscriptionId'),
            ),
          ).thenAnswer((_) => const Stream<Event>.empty());
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

          // The new session's first sweep defers on the same refusal. It must
          // arm its own delayed retry, not run the old session's queued pass.
          unawaited(repository.startListening());
          async.flushMicrotasks();
          unawaited(repository.backfillHistoryIfNeeded());
          async.flushMicrotasks();

          expect(reads, 3);
        });
      },
    );

    test('a page answered between sightings keeps its refusal unconfirmed', () {
      fakeAsync((async) {
        stubAnsweredHistory();
        final outgoing = Event.fromJson({
          'id':
              'facefaceface0001facefaceface0001facefaceface0001facefaceface0001',
          'pubkey': _pubkey,
          'created_at': 500,
          'kind': 4,
          'tags': [
            [
              'p',
              'b1b2c3d4e5f6789012345678901234567890abcdef1234567890123456789012',
            ],
          ],
          'content': 'encrypted-outgoing',
          'sig': '',
        });
        final pages = <String>[];
        var reads = 0;
        when(
          () => nostrClient.readEvents(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
            useCache: any(named: 'useCache'),
            requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
          ),
        ).thenAnswer((inv) async {
          reads++;
          pages.add(inv.namedArguments[#subscriptionId] as String);
          if (reads == 2) {
            return QueryResult(
              events: [outgoing],
              endedBy: QueryEnd.complete,
              answeredNetworkRelayCount: 1,
            );
          }
          return refusal();
        });
        final repository = makeRepository();

        unawaited(repository.backfillHistoryIfNeeded());
        async.flushMicrotasks();
        unawaited(repository.backfillHistoryIfNeeded());
        async.flushMicrotasks();
        async
          ..elapse(DmHistoryDrainConfig.deferredRetryDelays.first)
          ..flushMicrotasks();

        // Page 0 was answered after the timer armed, so its refusal did not
        // recur across the delay. Confirming it would mark restore complete
        // without ever reading page 1.
        expect(pages.last, endsWith('_0'));
        expect(syncState.historyDrainComplete(_pubkey), isFalse);
      });
    });
  });
}

class _InlineVerifyWorker implements DmVerifyWorker {
  @override
  Future<bool> verifyPart(Event event) async => event.isValid && event.isSigned;

  @override
  void close() {}
}
