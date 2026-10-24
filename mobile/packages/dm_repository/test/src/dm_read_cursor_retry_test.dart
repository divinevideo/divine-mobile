// ABOUTME: Regression coverage for the #4977 cross-device read-cursor retry —
// ABOUTME: a marker arriving before its conversation row must be re-applied.

import 'dart:async';
import 'dart:convert';

import 'package:account_state_repository/account_state_repository.dart';
import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/event_kind.dart';
import 'package:nostr_sdk/filter.dart' as nostr;
import 'package:nostr_sdk/relay/query_result.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';
import 'package:nostr_sdk/subscription.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _RefusingSeedState extends AccountStateRepository {
  _RefusingSeedState({
    required super.nostrClient,
    required super.sharedPreferences,
    required super.pubkey,
    required super.signer,
    required super.namespace,
  });

  bool refuseSeeds = false;

  @override
  Future<void> seed(Map<String, Object?> values) {
    if (refuseSeeds) throw const AccountStateException('storage unavailable');
    return super.seed(values);
  }
}

class _ObservedAccountSyncDao extends AccountSyncDao {
  _ObservedAccountSyncDao(super.attachedDatabase);
  bool observeNextWrite = false;
  final entered = Completer<void>();
  final committed = Completer<void>();
  final abort = Completer<void>();
  final ordering = <String>[];
  bool holdLegacyWrite = true;
  final legacyEntered = Completer<void>();
  final legacyRelease = Completer<void>();
  @override
  Future<void> writeState(
    String owner,
    String namespace,
    Map<String, Map<String, String>> sections,
  ) async {
    final legacy =
        entered.isCompleted && (sections['entries']?.isNotEmpty ?? false);
    if (legacy) ordering.add('legacy seed');
    final write = super.writeState(owner, namespace, sections);
    if (legacy && holdLegacyWrite) {
      holdLegacyWrite = false;
      legacyEntered.complete();
      await write;
      await legacyRelease.future;
      return;
    }
    if (!observeNextWrite) return write;
    observeNextWrite = false;
    entered.complete();
    ordering.add('outside issued');
    // A failed test can release the queue in finally. Success must await the
    // actual shared-Drift write; there is no elapsed-time race or fake adapter.
    await Future.any([
      write,
      abort.future.then((_) => throw StateError('test aborted')),
    ]);
    ordering.add('outside committed');
    committed.complete();
  }
}

class _ReadState extends DmSyncState {
  _ReadState(super._prefs);
  bool blockNext = false;
  final entered = Completer<void>();
  final release = Completer<void>();
  @override
  Future<void> rememberReadCursors(
    String pubkey,
    Map<String, int> cursors, {
    Map<String, Set<String>> boundaryMessageIds = const {},
  }) async {
    if (blockNext) {
      blockNext = false;
      entered.complete();
      await release.future;
    }
    await super.rememberReadCursors(
      pubkey,
      cursors,
      boundaryMessageIds: boundaryMessageIds,
    );
  }
}

class _OverlapDao extends ConversationsDao {
  _OverlapDao(super.attachedDatabase);
  static final _transactionZone = Object();
  bool holdNextDismissal = false;
  final dismissalEntered = Completer<void>();
  final dismissalRelease = Completer<void>();

  @override
  Future<void> applySyncedDismissal(
    String id, {
    required String ownerPubkey,
    required bool dismissed,
    int boundaryTimestamp = 0,
    Set<String> knownMessageIds = const {},
  }) async {
    if (holdNextDismissal) {
      holdNextDismissal = false;
      dismissalEntered.complete();
      await dismissalRelease.future;
    }
    await super.applySyncedDismissal(
      id,
      ownerPubkey: ownerPubkey,
      dismissed: dismissed,
      boundaryTimestamp: boundaryTimestamp,
      knownMessageIds: knownMessageIds,
    );
  }

  bool holdNextCapture = false;
  final captureEntered = Completer<void>();
  final captureRelease = Completer<void>();

  @override
  Future<({int timestamp, Set<String> knownMessageIds})?>
  captureDismissalBoundary(String id, {required String ownerPubkey}) async {
    final boundary = await super.captureDismissalBoundary(
      id,
      ownerPubkey: ownerPubkey,
    );
    if (holdNextCapture) {
      holdNextCapture = false;
      captureEntered.complete();
      await captureRelease.future;
    }
    return boundary;
  }

  bool holdNextLegacyQuery = false;
  final legacyQueryEntered = Completer<void>();
  final legacyQueryRelease = Completer<void>();
  bool holdNextTransaction = false;
  bool transactionHeld = false;
  final entered = Completer<void>();
  final release = Completer<void>();
  final outsideQueryStarted = Completer<void>();

  @override
  Future<T> runInTransaction<T>(Future<T> Function() action) => runZoned(
    () => super.runInTransaction(() async {
      if (holdNextTransaction) {
        holdNextTransaction = false;
        await super.getAllConversations(ownerPubkey: _owner);
        transactionHeld = true;
        entered.complete();
        await release.future;
      }
      return action();
    }),
    zoneValues: {_transactionZone: true},
  );

  @override
  Future<List<ConversationRow>> getAllConversations({
    int? limit,
    int? offset,
    String? ownerPubkey,
  }) {
    final result = super.getAllConversations(
      limit: limit,
      offset: offset,
      ownerPubkey: ownerPubkey,
    );
    if (holdNextLegacyQuery) {
      holdNextLegacyQuery = false;
      return () async {
        final rows = await result;
        legacyQueryEntered.complete();
        await legacyQueryRelease.future;
        return rows;
      }();
    }
    if (transactionHeld && Zone.current[_transactionZone] != true) {
      if (!outsideQueryStarted.isCompleted) outsideQueryStarted.complete();
      // Only a failed regression needs this escape hatch: the real outside
      // DB query remains blocked until the ingestion transaction commits.
      return result.timeout(const Duration(seconds: 1));
    }
    return result;
  }
}

const _owner =
    'a4f5c1b2d3e4f5061728394a5b6c7d8e9f0a1b2c3d4e5f60718293a4b5c6d7e8';
const _peer =
    'b1c2d3e4f5061728394a5b6c7d8e9f0a1b2c3d4e5f60718293a4b5c6d7e8f9a0';
const _privateKey =
    '5426e5b8b4b0e2a1f5e8d3c7a9b2f4e6d8c0a2b4f6e8d0c2a4b6f8e0d2c4a6b8';

const _readMarkerDTag = 'divine/dm-read/v1';
const _baseCreatedAt = 1700000000;

void main() {
  setUpAll(() {
    registerFallbackValue(Duration.zero);
    registerFallbackValue(nostr.Filter());
  });

  // Drives the real ConversationsDao against a real database. The mock suite
  // in dm_repository_test.dart stubs applyReadCursor to a constant `true` in
  // its top-level setUp, so the `!applied` retry branch never executes there
  // and _pendingReadCursors is always empty — a test written there would pass
  // whether or not the retry works (#8170).
  group(
    'read-cursor retry for a marker that arrives before its conversation',
    () {
      late AppDatabase db;
      late _OverlapDao conversationsDao;
      late AccountStateRepository accountState;
      late DirectMessagesDao messagesDao;
      late _MockNostrClient nostrClient;
      late StreamController<Event> relay;
      late DmRepository repository;
      late Map<String, Event> rumorByWrapId;
      late _ReadState syncState;
      late void Function(StoredEventsEnd) endStoredEvents;

      /// The conversation the marker names — deliberately not created yet.
      final participants = [_owner, _peer]..sort();
      late String conversationId;

      setUp(() async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        syncState = _ReadState(await SharedPreferences.getInstance());
        db = AppDatabase.test(NativeDatabase.memory());
        conversationsDao = _OverlapDao(db);
        messagesDao = DirectMessagesDao(db);
        nostrClient = _MockNostrClient();
        relay = StreamController<Event>.broadcast();
        rumorByWrapId = <String, Event>{};
        conversationId = DmRepository.computeConversationId(participants);

        when(() => nostrClient.connectedRelayCount).thenReturn(1);
        when(() => nostrClient.configuredRelayCount).thenReturn(1);
        when(
          () => nostrClient.readEvents(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
            useCache: any(named: 'useCache'),
            requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
          ),
        ).thenAnswer(
          (_) async => const QueryResult(
            events: [],
            endedBy: QueryEnd.complete,
            answeredNetworkRelayCount: 1,
          ),
        );
        when(
          () => nostrClient.queryEvents(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
            useCache: any(named: 'useCache'),
          ),
        ).thenAnswer((_) async => const <Event>[]);
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
        ).thenAnswer(
          (_) async =>
              (events: const <Event>[], timedOut: false, noRelays: false),
        );
        when(() => nostrClient.unsubscribe(any())).thenAnswer((_) async {});
        when(
          () => nostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
            onStoredEventsStart: any(named: 'onStoredEventsStart'),
            onStoredEventsEnd: any(named: 'onStoredEventsEnd'),
          ),
        ).thenAnswer((call) {
          final ended = call.namedArguments[#onStoredEventsEnd];
          if (ended is void Function(StoredEventsEnd)) endStoredEvents = ended;
          return relay.stream;
        });

        accountState = _RefusingSeedState(
          nostrClient: nostrClient,
          sharedPreferences: await SharedPreferences.getInstance(),
          pubkey: _owner,
          signer: () => LocalNostrSigner(_privateKey),
          namespace: 'divine/dm-dismissals/v1',
        );
        repository = DmRepository(
          nostrClient: nostrClient,
          directMessagesDao: messagesDao,
          conversationsDao: conversationsDao,
          userPubkey: _owner,
          syncState: syncState,
          accountStateRepository: accountState,
          signer: LocalNostrSigner(_privateKey),
          rumorDecryptor: (_, giftWrap) async => rumorByWrapId[giftWrap.id],
          nip04Decryptor: (_, ciphertext) async => ciphertext,
        );
        await repository.startListening();
        await repository.flushPendingReadState();
      });

      tearDown(() async {
        await repository.stopListening();
        await accountState.close();
        await relay.close();
        await db.close();
      });

      Future<void> settle() async {
        for (var i = 0; i < 8; i++) {
          await Future<void>.delayed(Duration.zero);
        }
      }

      /// Feeds the owner's own kind-30078 read marker, naming [conversationId]
      /// via its participant tuple and carrying [readAt] as the cursor.
      Future<void> deliverReadMarker({
        required String wrapId,
        required String rumorId,
        required int readAt,
      }) async {
        rumorByWrapId[wrapId] = Event.fromJson({
          'id': rumorId,
          'pubkey': _owner,
          'created_at': _baseCreatedAt,
          'kind': EventKind.appSpecificData,
          'tags': [
            ['d', _readMarkerDTag],
            ['p', _owner],
          ],
          'content': jsonEncode({
            'v': 1,
            'read': {participants.join(','): readAt},
          }),
          'sig': '',
        });
        relay.add(
          Event.fromJson({
            'id': wrapId,
            'pubkey': _owner,
            'created_at': _baseCreatedAt,
            'kind': EventKind.giftWrap,
            'tags': [
              ['p', _owner],
            ],
            'content': 'wrapped-$wrapId',
            'sig': '',
          }),
        );
        await settle();
      }

      /// Delivers one kind-14 message in the conversation, sent by [sender].
      Future<void> ingestMessage({
        required String wrapId,
        required String rumorId,
        required String sender,
        required int messageAt,
      }) async {
        rumorByWrapId[wrapId] = Event.fromJson({
          'id': rumorId,
          'pubkey': sender,
          'created_at': messageAt,
          'kind': EventKind.privateDirectMessage,
          'tags': [
            ['p', if (sender == _owner) _peer else _owner],
          ],
          'content': 'hello',
          'sig': '',
        });
        relay.add(
          Event.fromJson({
            'id': wrapId,
            'pubkey': _peer,
            'created_at': messageAt,
            'kind': EventKind.giftWrap,
            'tags': [
              ['p', _owner],
            ],
            'content': 'wrapped-$wrapId',
            'sig': '',
          }),
        );
        await settle();
      }

      /// Creates the conversation the marker named, with one unread inbound
      /// message at [messageAt] — the row the marker was racing.
      Future<void> ingestConversation({required int messageAt}) =>
          ingestMessage(
            wrapId: 'e' * 64,
            rumorId: 'f' * 64,
            sender: _peer,
            messageAt: messageAt,
          );

      Future<ConversationRow?> conversation() async {
        final rows = await conversationsDao.getAllConversations(
          ownerPubkey: _owner,
        );
        return rows.where((r) => r.id == conversationId).firstOrNull;
      }

      test(
        'post-commit dismissal failure keeps message sync boundaries',
        () async {
          endStoredEvents(const StoredEventsEnd(deliveredEventCount: 0));
          await pumpEventQueue();
          await conversationsDao.upsertConversation(
            id: conversationId,
            participantPubkeys: jsonEncode(participants),
            isGroup: false,
            createdAt: _baseCreatedAt,
            lastMessageTimestamp: _baseCreatedAt + 100,
            ownerPubkey: _owner,
          );
          await conversationsDao.setDismissed(
            conversationId,
            ownerPubkey: _owner,
            dismissed: true,
          );
          (accountState as _RefusingSeedState).refuseSeeds = true;
          expect(syncState.newestSyncedAt(_owner), isNull);
          await ingestMessage(
            wrapId: '4' * 64,
            rumorId: '5' * 64,
            sender: _peer,
            messageAt: _baseCreatedAt + 50,
          );
          expect(
            await messagesDao.getMessageById('5' * 64, ownerPubkey: _owner),
            isNotNull,
          );
          expect(syncState.newestSyncedAt(_owner), _baseCreatedAt + 50);
          expect(syncState.newestWireSyncedAt(_owner), _baseCreatedAt + 50);
          expect((await conversation())!.isDismissed, isTrue);
        },
      );

      for (final dismiss in [false, true]) {
        test(
          'stop fences a pending ${dismiss ? 'dismissal' : 'read'} capture',
          () async {
            await ingestConversation(messageAt: _baseCreatedAt + 100);
            conversationsDao.holdNextCapture = true;
            final action = dismiss
                ? repository.setConversationDismissed(
                    conversationId,
                    dismissed: true,
                  )
                : repository.markConversationAsRead(conversationId);
            await conversationsDao.captureEntered.future;
            await repository.stopListening();
            final prefs = await SharedPreferences.getInstance();
            for (final key in DmSyncState.readStateStorageKeys(_owner)) {
              await prefs.remove(key);
            }
            conversationsDao.captureRelease.complete();
            await action;
            await prefs.reload();
            expect(syncState.readCursors(_owner), isEmpty);
            expect(accountState.values, isEmpty);
            expect((await conversation())!.isRead, isFalse);
            await repository.startListening();
            expect(
              await repository.markConversationAsRead(conversationId),
              isTrue,
            );
            expect(syncState.readCursors(_owner), isNotEmpty);
          },
        );
      }

      test(
        'owner close drains an issued remote dismissal projection',
        () async {
          await ingestConversation(messageAt: _baseCreatedAt + 100);
          conversationsDao.holdNextDismissal = true;
          await accountState.setValue(participants.join(','), {
            'through': _baseCreatedAt + 100,
            'known': ['f' * 64],
          });
          await conversationsDao.dismissalEntered.future;
          var closed = false;
          final close = repository.closeLocalReadState().then(
            (_) => closed = true,
          );
          await settle();
          final closedBeforeWrite = closed;
          conversationsDao.dismissalRelease.complete();
          await close;
          await settle();
          expect(closedBeforeWrite, isFalse);
          expect((await conversation())!.isDismissed, isTrue);
        },
      );

      test('stop drains an issued local read write', () async {
        await ingestConversation(messageAt: _baseCreatedAt + 100);
        syncState.blockNext = true;
        final read = repository.markConversationAsRead(conversationId);
        await syncState.entered.future;
        var stopped = false;
        final stop = repository.stopListening().then((_) => stopped = true);
        await settle();
        final stoppedBeforeWrite = stopped;
        syncState.release.complete();
        await read;
        await stop;
        expect(stoppedBeforeWrite, isFalse);
      });

      test(
        'same-second arrival during durable read persistence remains unread',
        () async {
          await ingestConversation(messageAt: _baseCreatedAt + 100);
          syncState.blockNext = true;
          final read = repository.markConversationAsRead(conversationId);
          await syncState.entered.future;
          await ingestMessage(
            wrapId: '1' * 64,
            rumorId: '2' * 64,
            sender: _peer,
            messageAt: _baseCreatedAt + 100,
          );
          await messagesDao
              .watchMessagesForConversation(conversationId, ownerPubkey: _owner)
              .firstWhere((rows) => rows.length == 2)
              .timeout(const Duration(seconds: 2));
          syncState.release.complete();
          expect(await read, isTrue);
          expect((await conversation())!.isRead, isFalse);
        },
      );

      test(
        'remote timestamp-only marker keeps inherited same-second precision',
        () async {
          await ingestConversation(messageAt: _baseCreatedAt + 100);
          await ingestMessage(
            wrapId: '1' * 64,
            rumorId: '2' * 64,
            sender: _peer,
            messageAt: _baseCreatedAt + 100,
          );
          await deliverReadMarker(
            wrapId: '4' * 64,
            rumorId: '5' * 64,
            readAt: _baseCreatedAt + 100,
          );
          expect((await conversation())!.isRead, isTrue);
        },
      );

      for (final legacy in [false, true]) {
        test(
          '${legacy ? 'NIP-04' : 'NIP-17'} same-second restore stays unread',
          () async {
            await ingestConversation(messageAt: _baseCreatedAt + 100);
            await repository.setConversationDismissed(
              conversationId,
              dismissed: true,
            );
            await repository.flushPendingReadState();
            if (legacy) {
              relay.add(
                Event.fromJson({
                  'id': '3' * 64,
                  'pubkey': _peer,
                  'created_at': _baseCreatedAt + 100,
                  'kind': EventKind.directMessage,
                  'tags': [
                    ['p', _owner],
                  ],
                  'content': 'new legacy message',
                  'sig': '',
                }),
              );
            } else {
              await ingestMessage(
                wrapId: '1' * 64,
                rumorId: '2' * 64,
                sender: _peer,
                messageAt: _baseCreatedAt + 100,
              );
            }
            await messagesDao
                .watchMessagesForConversation(
                  conversationId,
                  ownerPubkey: _owner,
                )
                .firstWhere((rows) => rows.length == 2)
                .timeout(const Duration(seconds: 2));
            final row = (await conversation())!;
            expect(row.isDismissed, isFalse);
            expect(row.isRead, isFalse);
            await deliverReadMarker(
              wrapId: '4' * 64,
              rumorId: '5' * 64,
              readAt: _baseCreatedAt + 100,
            );
            expect((await conversation())!.isRead, isFalse);
            expect(
              await repository.markConversationAsRead(conversationId),
              isTrue,
            );
            expect((await conversation())!.isRead, isTrue);
          },
        );
      }

      for (final lifecycle in ['active', 'stop', 'erase']) {
        test(
          'legacy ingest never waits on a generic write blocked by its '
          'Drift transaction ($lifecycle)',
          () async {
            final signer = LocalNostrSigner(_privateKey);
            final owner = (await signer.getPublicKey())!;
            final participants = [owner, _peer]..sort();
            conversationId = DmRepository.computeConversationId(participants);
            await repository.stopListening();
            await accountState.close();
            await conversationsDao.upsertConversation(
              id: conversationId,
              participantPubkeys: jsonEncode(participants),
              isGroup: false,
              createdAt: _baseCreatedAt,
              lastMessageTimestamp: _baseCreatedAt + 100,
              ownerPubkey: owner,
            );
            await conversationsDao.applySyncedDismissal(
              conversationId,
              ownerPubkey: owner,
              dismissed: true,
              boundaryTimestamp: _baseCreatedAt + 100,
              knownMessageIds: {'1' * 64},
            );
            const namespace = 'divine/dm-dismissals/v1';
            await db.accountSyncDao.writeState(_owner, namespace, {
              'entries': {
                'other-owner': '{"value":true,"clock":1,"device":"other"}',
              },
            });
            final otherOwnerBefore = await db.accountSyncDao.readState(
              _owner,
              namespace,
            );
            final journalDao = _ObservedAccountSyncDao(db);
            final sourceClient = _MockNostrClient();
            final sources = StreamController<Event>.broadcast();
            addTearDown(sources.close);
            when(
              () => sourceClient.subscribe(any()),
            ).thenAnswer((_) => sources.stream);
            when(
              () => sourceClient.relayStatusStream,
            ).thenAnswer((_) => const Stream.empty());
            when(() => sourceClient.readAllEvents(any())).thenAnswer(
              (_) async => const PagedQueryResult(
                events: [],
                isComplete: false,
                pages: 1,
              ),
            );
            accountState = AccountStateRepository(
              nostrClient: sourceClient,
              sharedPreferences: await SharedPreferences.getInstance(),
              pubkey: owner,
              signer: () => LocalNostrSigner(_privateKey),
              namespace: 'divine/dm-dismissals/v1',
              perFieldSnapshots: true,
              storage: DriftAccountStateStorage(
                journalDao,
                owner: owner,
                namespace: 'divine/dm-dismissals/v1',
              ),
            );
            await accountState.start();
            await expectLater(
              accountState.synchronize(),
              throwsA(isA<AccountStateException>()),
            );
            await accountState.seed({});
            repository = DmRepository(
              nostrClient: nostrClient,
              directMessagesDao: messagesDao,
              conversationsDao: conversationsDao,
              userPubkey: owner,
              syncState: syncState,
              accountStateRepository: accountState,
              signer: LocalNostrSigner(_privateKey),
              rumorDecryptor: (_, wrap) async => rumorByWrapId[wrap.id],
            );
            addTearDown(() {
              if (!conversationsDao.legacyQueryRelease.isCompleted) {
                conversationsDao.legacyQueryRelease.complete();
              }
              if (!conversationsDao.release.isCompleted) {
                conversationsDao.release.complete();
              }
            });
            conversationsDao.holdNextLegacyQuery = true;
            await repository.startListening();
            await conversationsDao.legacyQueryEntered.future;
            expect(accountState.contains(participants.join(',')), isFalse);
            conversationsDao.holdNextTransaction = true;
            final wrapId = 'e' * 64;
            rumorByWrapId[wrapId] = Event.fromJson({
              'id': 'f' * 64,
              'pubkey': _peer,
              'created_at': _baseCreatedAt + 50,
              'kind': EventKind.privateDirectMessage,
              'tags': [
                ['p', owner],
              ],
              'content': 'older message',
              'sig': '',
            });
            relay.add(
              Event.fromJson({
                'id': wrapId,
                'pubkey': _peer,
                'created_at': _baseCreatedAt + 50,
                'kind': EventKind.giftWrap,
                'tags': [
                  ['p', owner],
                ],
                'content': 'wrapped',
                'sig': '',
              }),
            );
            await conversationsDao.entered.future;
            journalDao.observeNextWrite = true;
            final source = (await signer.signEvent(
              Event(
                owner,
                30078,
                [
                  ['d', 'divine/dm-dismissals/v1'],
                ],
                'opaque received source',
                createdAt: _baseCreatedAt,
              ),
            ))!;
            expect(source.isValid, isTrue);
            expect(source.isSigned, isTrue);
            sources.add(source);
            await journalDao.entered.future;
            conversationsDao.release.complete();
            final committed = messagesDao
                .watchMessagesForConversation(
                  conversationId,
                  ownerPubkey: owner,
                )
                .firstWhere((rows) => rows.isNotEmpty);
            try {
              // Only a deadlock safety bound; no performance/elapsed-time assertion.
              await committed.timeout(const Duration(seconds: 30));
              await journalDao.committed.future;
              expect(journalDao.abort.isCompleted, isFalse);
              await journalDao.legacyEntered.future;
              conversationsDao.transactionHeld = false;
              conversationsDao.legacyQueryRelease.complete();
              var drained = false;
              final drain = (switch (lifecycle) {
                'stop' => repository.stopListening(),
                'erase' => repository.closeLocalReadState(),
                _ => repository.flushPendingReadState(),
              }).then((_) => drained = true);
              await pumpEventQueue();
              expect(
                drained,
                isFalse,
                reason: 'the issued local seed is still held',
              );
              journalDao.legacyRelease.complete();
              await drain;
              expect(drained, isTrue);
            } finally {
              if (!journalDao.abort.isCompleted) journalDao.abort.complete();
              conversationsDao.transactionHeld = false;
              if (!conversationsDao.legacyQueryRelease.isCompleted) {
                conversationsDao.legacyQueryRelease.complete();
              }
              if (!journalDao.legacyRelease.isCompleted) {
                journalDao.legacyRelease.complete();
              }
              await repository.flushPendingReadState();
            }
            expect(
              journalDao.ordering,
              containsAllInOrder([
                'outside issued',
                'outside committed',
                'legacy seed',
              ]),
            );
            final row = await conversationsDao.getConversation(
              conversationId,
              ownerPubkey: owner,
            );
            expect(row!.isDismissed, isTrue);
            expect(accountState.value(participants.join(',')), {
              'through': _baseCreatedAt + 100,
              'known': ['1' * 64],
            });
            await repository.closeLocalReadState();
            await repository.stopListening();
            await accountState.close();
            final restarted = AccountStateRepository(
              nostrClient: sourceClient,
              sharedPreferences: await SharedPreferences.getInstance(),
              pubkey: owner,
              signer: () => LocalNostrSigner(_privateKey),
              namespace: 'divine/dm-dismissals/v1',
              perFieldSnapshots: true,
              storage: DriftAccountStateStorage(
                db.accountSyncDao,
                owner: owner,
                namespace: 'divine/dm-dismissals/v1',
              ),
            );
            await restarted.seed({});
            expect(
              restarted.value(participants.join(',')),
              accountState.value(participants.join(',')),
            );
            await restarted.close();
            if (lifecycle == 'erase') {
              await db.accountSyncDao.clearAccount(owner);
              await messagesDao.deleteAllForOwner(owner);
              await conversationsDao.deleteAllForOwner(owner);
              await conversationsDao.clearDismissalsForOwner(owner);
              expect(
                await db.accountSyncDao.readState(owner, namespace),
                isEmpty,
              );
              expect(
                await conversationsDao.getDismissal(
                  conversationId,
                  ownerPubkey: owner,
                ),
                isNull,
              );
            }
            expect(
              await db.accountSyncDao.readState(_owner, namespace),
              otherOwnerBefore,
            );
          },
        );
      }

      test(
        'ingest cannot wait behind outside dismissal reconciliation',
        () async {
          conversationsDao.holdNextTransaction = true;
          await ingestConversation(messageAt: _baseCreatedAt + 100);
          await conversationsDao.entered.future.timeout(
            const Duration(seconds: 2),
          );
          await accountState.setValue(participants.join(','), null);
          await conversationsDao.outsideQueryStarted.future.timeout(
            const Duration(seconds: 2),
          );
          conversationsDao.release.complete();
          final committed = messagesDao
              .watchMessagesForConversation(conversationId, ownerPubkey: _owner)
              .firstWhere((rows) => rows.isNotEmpty);
          try {
            await committed.timeout(const Duration(milliseconds: 300));
          } finally {
            // Allow the deliberately timed-out outside query to settle on RED.
            await committed.timeout(const Duration(seconds: 3));
            conversationsDao.transactionHeld = false;
            await repository.flushPendingReadState();
          }
        },
      );

      test(
        'a marker landing before its conversation applies when the '
        'conversation is ingested, without waiting for the drain',
        () async {
          // The marker names a conversation that does not exist yet, so
          // applyReadCursor matches no row and returns false.
          await deliverReadMarker(
            wrapId: 'a' * 64,
            rumorId: 'b' * 64,
            readAt: _baseCreatedAt + 100,
          );
          expect(
            await conversation(),
            isNull,
            reason:
                'precondition: the marker must arrive before its row exists',
          );

          // The live subscription then ingests the conversation it was
          // racing. The drain only starts when Messages opens, so a cursor
          // held back until then shows as an unread badge (#10275).
          await ingestConversation(messageAt: _baseCreatedAt + 50);

          final row = await conversation();
          expect(
            row!.lastReadTimestamp,
            _baseCreatedAt + 100,
            reason:
                'the queued cursor must apply to the row it was waiting for',
          );
          expect(
            row.isRead,
            isTrue,
            reason: 'the cursor covers the latest message, so it reads as read',
          );
        },
      );

      test(
        'the drain still applies a queued marker to a row created outside '
        'message ingest',
        () async {
          await deliverReadMarker(
            wrapId: 'a' * 64,
            rumorId: 'b' * 64,
            readAt: _baseCreatedAt + 100,
          );
          expect(await conversation(), isNull);

          // Other repository paths can create a row without passing through
          // either message-ingest hook. Keep the drain's fallback covered.
          await conversationsDao.upsertConversation(
            id: conversationId,
            participantPubkeys: jsonEncode(participants),
            isGroup: false,
            createdAt: _baseCreatedAt,
            lastMessageTimestamp: _baseCreatedAt + 50,
            isRead: false,
            ownerPubkey: _owner,
          );
          final beforeDrain = await conversation();
          expect(beforeDrain!.isRead, isFalse);
          expect(beforeDrain.lastReadTimestamp, isNull);

          await repository.backfillHistoryIfNeeded();
          await settle();

          final afterDrain = await conversation();
          expect(afterDrain!.lastReadTimestamp, _baseCreatedAt + 100);
          expect(afterDrain.isRead, isTrue);
        },
      );

      test(
        'a queued marker applies when a NIP-04 message creates its row',
        () async {
          await deliverReadMarker(
            wrapId: 'a' * 64,
            rumorId: 'b' * 64,
            readAt: _baseCreatedAt + 100,
          );
          expect(await conversation(), isNull);

          relay.add(
            Event.fromJson({
              'id': 'c' * 64,
              'pubkey': _peer,
              'created_at': _baseCreatedAt + 50,
              'kind': EventKind.directMessage,
              'tags': [
                ['p', _owner],
              ],
              'content': 'legacy hello',
              'sig': '',
            }),
          );
          await settle();

          final row = await conversation();
          expect(row!.dmProtocol, 'nip04');
          expect(row.lastReadTimestamp, _baseCreatedAt + 100);
          expect(row.isRead, isTrue);
        },
      );

      test(
        'an already-read conversation re-downloaded after its marker stays '
        'read through every message the cursor covers',
        () async {
          // The order seen on device after switching accounts back: the
          // newest read marker sorts above the conversation's wraps, then
          // the peer's message, the owner's reply and the peer's latest.
          await deliverReadMarker(
            wrapId: 'a' * 64,
            rumorId: 'b' * 64,
            readAt: _baseCreatedAt + 300,
          );
          await ingestMessage(
            wrapId: '1' * 64,
            rumorId: '2' * 64,
            sender: _peer,
            messageAt: _baseCreatedAt + 100,
          );
          await ingestMessage(
            wrapId: '3' * 64,
            rumorId: '4' * 64,
            sender: _owner,
            messageAt: _baseCreatedAt + 200,
          );
          await ingestMessage(
            wrapId: '5' * 64,
            rumorId: '6' * 64,
            sender: _peer,
            messageAt: _baseCreatedAt + 300,
          );

          final row = await conversation();
          expect(row!.lastMessageTimestamp, _baseCreatedAt + 300);
          expect(
            row.isRead,
            isTrue,
            reason: 'every message is at or before the restored read cursor',
          );
        },
      );

      test(
        'a marker applied to an existing row keeps it read when a newer '
        'message it covers is re-ingested',
        () async {
          // No queue here: the row exists when the marker lands, so the
          // cursor is stored on it directly. The re-download then reaches
          // the peer's newer message the user had also read.
          await ingestMessage(
            wrapId: '1' * 64,
            rumorId: '2' * 64,
            sender: _peer,
            messageAt: _baseCreatedAt + 100,
          );
          await deliverReadMarker(
            wrapId: 'a' * 64,
            rumorId: 'b' * 64,
            readAt: _baseCreatedAt + 300,
          );
          await ingestMessage(
            wrapId: '3' * 64,
            rumorId: '4' * 64,
            sender: _peer,
            messageAt: _baseCreatedAt + 300,
          );

          final row = await conversation();
          expect(row!.lastMessageTimestamp, _baseCreatedAt + 300);
          expect(row.isRead, isTrue);
        },
      );

      test(
        'a message newer than the queued cursor is still unread',
        () async {
          // Control: the cursor restores what was read, not what was not.
          await deliverReadMarker(
            wrapId: 'a' * 64,
            rumorId: 'b' * 64,
            readAt: _baseCreatedAt + 100,
          );
          await ingestMessage(
            wrapId: '1' * 64,
            rumorId: '2' * 64,
            sender: _peer,
            messageAt: _baseCreatedAt + 50,
          );
          await ingestMessage(
            wrapId: '3' * 64,
            rumorId: '4' * 64,
            sender: _peer,
            messageAt: _baseCreatedAt + 150,
          );

          final row = await conversation();
          expect(row!.lastReadTimestamp, _baseCreatedAt + 100);
          expect(row.isRead, isFalse);
        },
      );

      test(
        'a marker for an already-ingested conversation applies directly',
        () async {
          // Control: when the row exists, applyReadCursor returns true and
          // the retry queue is never involved. Keeps the test above honest —
          // it must fail for the retry, not because markers never work.
          await ingestConversation(messageAt: _baseCreatedAt + 50);
          expect(await conversation(), isNotNull);

          await deliverReadMarker(
            wrapId: 'c' * 64,
            rumorId: 'd' * 64,
            readAt: _baseCreatedAt + 100,
          );

          final row = await conversation();
          expect(row!.lastReadTimestamp, _baseCreatedAt + 100);
          expect(row.isRead, isTrue);
        },
      );
    },
  );
}
