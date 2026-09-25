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
import 'package:unified_logger/unified_logger.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockDirectMessagesDao extends Mock implements DirectMessagesDao {}

class _MockConversationsDao extends Mock implements ConversationsDao {}

class _MockNip17MessageService extends Mock implements NIP17MessageService {}

class _FakeEvent extends Fake implements Event {}

const _pubkey =
    'a1b2c3d4e5f6789012345678901234567890abcdef1234567890123456789012';
const _privateKey =
    'd4e5f6789012345678901234567890abcdef1234567890123456789012ab12c3';
const _peerPubkey =
    'b1b2c3d4e5f6789012345678901234567890abcdef1234567890123456789012';

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
      'dm.oldestSyncedAt.$_peerPubkey': 100,
      'dm.historyDrainVersion.$_peerPubkey': DmSyncState.currentDrainVersion,
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

  QueryResult refusalFrom(String relay) => QueryResult(
    events: const [],
    endedBy: QueryEnd.relayClosed,
    answeredNetworkRelayCount: 1,
    closedRelayReasons: {relay: 'error'},
  );

  // A sweep no relay took: the drain defers with no refusal on record.
  QueryResult unsettled() =>
      const QueryResult(events: [], endedBy: QueryEnd.noRelay);

  QueryResult answered() => const QueryResult(
    events: [],
    endedBy: QueryEnd.complete,
    answeredNetworkRelayCount: 1,
  );

  void connectRelay(String url) {
    relayStatus.add({url: RelayConnectionStatus.connected(url)});
  }

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

    test('non-refusal deferrals resume on each relay reconnect', () {
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
          return const QueryResult(events: [], endedBy: QueryEnd.noRelay);
        });
        final repository = makeRepository();

        unawaited(repository.backfillHistoryIfNeeded());
        async.flushMicrotasks();
        expect(reads, 1);

        relayStatus.add({
          'wss://first.example': RelayConnectionStatus.connected(
            'wss://first.example',
          ),
        });
        async.flushMicrotasks();
        expect(reads, 2);

        relayStatus.add({
          'wss://first.example': RelayConnectionStatus.disconnected(
            'wss://first.example',
          ),
          'wss://second.example': RelayConnectionStatus.connected(
            'wss://second.example',
          ),
        });
        async.flushMicrotasks();
        expect(reads, 3);

        unawaited(repository.stopListening());
        async.flushMicrotasks();
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
      'a confirmation queued behind an active drain does not run after '
      'stopListening',
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
              'facefaceface0001facefaceface0001'
              'facefaceface0001facefaceface0001',
          'pubkey': _pubkey,
          'created_at': 500,
          'kind': 4,
          'tags': [
            ['p', _peerPubkey],
          ],
          'content': 'encrypted-outgoing',
          'sig': '',
        });
        // This account already stored the event, so ingesting the replay is a
        // quiet duplicate skip instead of a persist that fails on unstubbed
        // DAO calls and is swallowed.
        when(
          () => directMessagesDao.hasGiftWrap(outgoing.id),
        ).thenAnswer((_) async => true);
        when(
          () => directMessagesDao.getMessageById(
            outgoing.id,
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        ).thenAnswer(
          (_) async => DirectMessageRow(
            id: outgoing.id,
            conversationId: 'stored-outgoing',
            senderPubkey: _pubkey,
            content: 'stored',
            createdAt: 500,
            giftWrapId: outgoing.id,
            messageKind: 4,
            ownerPubkey: _pubkey,
            isDeleted: false,
            twinCollapsed: false,
          ),
        );
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
        async
          ..flushMicrotasks()
          ..elapse(DmHistoryDrainConfig.deferredRetryDelays.first)
          ..flushMicrotasks();

        // Page 0 was answered after the timer armed, so its refusal did not
        // recur across the delay. Confirming it would mark restore complete
        // without ever reading page 1.
        expect(pages.last, endsWith('_0'));
        expect(syncState.historyDrainComplete(_pubkey), isFalse);
      });
    });

    test(
      'a sweep no relay answered keeps the refusal it cannot contradict',
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
            return reads == 2 ? unsettled() : refusal();
          });
          final repository = makeRepository();

          unawaited(repository.backfillHistoryIfNeeded());
          async.flushMicrotasks();
          unawaited(repository.backfillHistoryIfNeeded());
          async
            ..flushMicrotasks()
            ..elapse(DmHistoryDrainConfig.deferredRetryDelays.first)
            ..flushMicrotasks();

          // The inbox open's sweep heard nothing about the page, so the
          // refusal the timer armed on still stands and the timer confirms it.
          expect(reads, 3);
          expect(syncState.historyDrainComplete(_pubkey), isTrue);
        });
      },
    );

    test('another relay closing the page keeps this relay refusal', () {
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
          // The refusing relay stays silent while a second relay closes.
          return reads == 2
              ? const QueryResult(
                  events: [],
                  endedBy: QueryEnd.relayClosed,
                  unansweredRelayCount: 1,
                  closedRelayReasons: {'wss://other.example': 'error'},
                )
              : refusal();
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
        expect(syncState.historyDrainComplete(_pubkey), isTrue);
      });
    });

    test('a queued confirmation that defers hands over to the next slot', () {
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
          return switch (reads) {
            2 => activeRead.future,
            3 || 4 => Future.value(refusalFrom('wss://other.example')),
            // A runaway chain of passes ends here instead of hanging.
            > 4 => Future.value(answered()),
            _ => Future.value(refusal()),
          };
        });
        final repository = makeRepository();

        unawaited(repository.backfillHistoryIfNeeded());
        async.flushMicrotasks();
        unawaited(repository.backfillHistoryIfNeeded());
        async
          ..flushMicrotasks()
          ..elapse(DmHistoryDrainConfig.deferredRetryDelays.first)
          ..flushMicrotasks();
        activeRead.complete(refusal());
        async.flushMicrotasks();

        // The queued pass saw a different refusal, so it defers once instead
        // of queueing another pass behind itself.
        expect(reads, 3);
        expect(syncState.historyDrainComplete(_pubkey), isFalse);

        async
          ..elapse(DmHistoryDrainConfig.deferredRetryDelays[1])
          ..flushMicrotasks();

        expect(reads, 4);
        expect(syncState.historyDrainComplete(_pubkey), isTrue);
      });
    });

    test('a queued confirmation leaves no retry armed once it settles', () {
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
        activeRead.complete(refusal());
        async.flushMicrotasks();

        // The active drain's deferral took no slot while the pass was queued,
        // so nothing is left armed once the pass confirms the refusal.
        expect(syncState.historyDrainComplete(_pubkey), isTrue);
        expect(async.pendingTimers, isEmpty);
      });
    });

    test('a queued confirmation announces no reconnect resume it replaces', () {
      fakeAsync((async) {
        unawaited(LogCaptureService().clearAllLogs());
        async.flushMicrotasks();
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
        activeRead.complete(refusal());
        async.flushMicrotasks();

        // Only the first deferral arms a resume. The active drain's deferral
        // hands over to the queued pass, which starts at once.
        final resumes = LogCaptureService()
            .getRecentLogs()
            .where((e) => e.message.contains('will resume when a relay'))
            .toList();
        expect(resumes, hasLength(1));
      });
    });

    test('an account switch drops a confirmation queued for the old one', () {
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
        repository.setCredentials(
          userPubkey: _peerPubkey,
          signer: LocalNostrSigner(_privateKey),
          messageService: _MockNip17MessageService(),
        );
        activeRead.complete(refusal());
        async.flushMicrotasks();

        // The new account's first sweep meets the same refusal. It must arm
        // its own delayed retry instead of confirming on the old account's
        // queued pass and armed refusal.
        unawaited(repository.backfillHistoryIfNeeded());
        async.flushMicrotasks();

        expect(reads, 3);
        expect(syncState.historyDrainComplete(_peerPubkey), isFalse);
      });
    });

    test('a spent reconnect leaves a log saying the kept retry covers it', () {
      fakeAsync((async) {
        unawaited(LogCaptureService().clearAllLogs());
        async.flushMicrotasks();
        stubAnsweredHistory();
        when(
          () => nostrClient.readEvents(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
            useCache: any(named: 'useCache'),
            requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
          ),
        ).thenAnswer((_) async => refusal());
        final repository = makeRepository();

        unawaited(repository.backfillHistoryIfNeeded());
        async.flushMicrotasks();
        connectRelay('wss://first.example');
        async.flushMicrotasks();

        // The reconnect sweep deferred inside the window with its one
        // reconnect spent: nothing is armed, and the log must say why.
        final logs = LogCaptureService()
            .getRecentLogs()
            .where((e) => e.message.contains('further reconnects wait'))
            .toList();
        expect(logs, hasLength(1));
      });
    });

    test('a later refusal window keeps its own reconnect sweep', () {
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
          return reads <= 2 ? refusal() : refusalFrom('wss://other.example');
        });
        final repository = makeRepository();

        // Window one: its reconnect sweep spends the window's one reconnect.
        unawaited(repository.backfillHistoryIfNeeded());
        async.flushMicrotasks();
        connectRelay('wss://first.example');
        async.flushMicrotasks();
        expect(reads, 2);

        // The timer meets a different refusal, so it defers into window two.
        async
          ..elapse(DmHistoryDrainConfig.deferredRetryDelays.first)
          ..flushMicrotasks();
        expect(reads, 3);

        unawaited(repository.backfillHistoryIfNeeded());
        async.flushMicrotasks();
        expect(reads, 4);

        connectRelay('wss://second.example');
        async.flushMicrotasks();
        expect(reads, 5);
      });
    });
  });

  group('DM silent-relay retries', () {
    void stubNip04Reads(Future<QueryResult> Function(int read) answer) {
      var reads = 0;
      when(
        () => nostrClient.readEvents(
          any(),
          subscriptionId: any(named: 'subscriptionId'),
          useCache: any(named: 'useCache'),
          requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
        ),
      ).thenAnswer((_) => answer(++reads));
    }

    test('a timer firing mid-drain queues no pass when no refusal awaits', () {
      fakeAsync((async) {
        stubAnsweredHistory();
        final activeRead = Completer<QueryResult>();
        var reads = 0;
        stubNip04Reads((read) {
          reads = read;
          return read == 2 ? activeRead.future : Future.value(unsettled());
        });
        final repository = makeRepository();

        unawaited(repository.backfillHistoryIfNeeded());
        async.flushMicrotasks();
        unawaited(repository.backfillHistoryIfNeeded());
        async
          ..flushMicrotasks()
          ..elapse(DmHistoryDrainConfig.deferredRetryDelays.first)
          ..flushMicrotasks();
        expect(reads, 2);

        activeRead.complete(unsettled());
        async.flushMicrotasks();

        // The timer had no refusal to confirm, so nothing is queued: the
        // active drain's own deferral arms the next slot instead.
        expect(reads, 2);

        async
          ..elapse(DmHistoryDrainConfig.deferredRetryDelays[1])
          ..flushMicrotasks();
        expect(reads, 3);

        unawaited(repository.stopListening());
        async.flushMicrotasks();
      });
    });

    test('a reconnect that resumes a silent deferral cancels its timer', () {
      fakeAsync((async) {
        stubAnsweredHistory();
        stubNip04Reads(
          (read) async => read == 1 ? unsettled() : answered(),
        );
        final repository = makeRepository();

        unawaited(repository.backfillHistoryIfNeeded());
        async.flushMicrotasks();
        expect(async.pendingTimers, hasLength(1));

        connectRelay('wss://edge.example');
        async.flushMicrotasks();

        // The reconnect completed the drain, so the retry it replaced must
        // not outlive it.
        expect(syncState.historyDrainComplete(_pubkey), isTrue);
        expect(async.pendingTimers, isEmpty);
      });
    });

    test('an inbox open that defers replaces the retry with the next slot', () {
      fakeAsync((async) {
        stubAnsweredHistory();
        var reads = 0;
        stubNip04Reads((read) async {
          reads = read;
          return unsettled();
        });
        final repository = makeRepository();

        unawaited(repository.backfillHistoryIfNeeded());
        async
          ..flushMicrotasks()
          ..elapse(const Duration(seconds: 1));
        unawaited(repository.backfillHistoryIfNeeded());
        async.flushMicrotasks();
        expect(reads, 2);

        // The first slot's deadline passes: the inbox open replaced it.
        async
          ..elapse(DmHistoryDrainConfig.deferredRetryDelays.first)
          ..flushMicrotasks();
        expect(reads, 2);

        async
          ..elapse(DmHistoryDrainConfig.deferredRetryDelays[1])
          ..flushMicrotasks();
        expect(reads, 3);

        unawaited(repository.stopListening());
        async.flushMicrotasks();
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
