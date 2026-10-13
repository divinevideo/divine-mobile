// ABOUTME: Regression coverage for #10105 — what Messages holds after the local
// ABOUTME: database was salvaged and the relays replay every gift wrap: a
// ABOUTME: removed conversation stays removed and a retracted message stays
// ABOUTME: retracted.

import 'dart:async';
import 'dart:io';

import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/event_kind.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockNip17MessageService extends Mock implements NIP17MessageService {}

const _cipherKey =
    '2dd29ca851e7b56e4697b0e1f08507293d761a05ce4d1b628663f411a8086d99';
const _owner =
    'a4f5c1b2d3e4f5061728394a5b6c7d8e9f0a1b2c3d4e5f60718293a4b5c6d7e8';
const _peer =
    'b1c2d3e4f5061728394a5b6c7d8e9f0a1b2c3d4e5f60718293a4b5c6d7e8f9a0';
const _peer2 =
    'c2d3e4f5061728394a5b6c7d8e9f0a1b2c3d4e5f60718293a4b5c6d7e8f9a0b1';
const _privateKey =
    '5426e5b8b4b0e2a1f5e8d3c7a9b2f4e6d8c0a2b4f6e8d0c2a4b6f8e0d2c4a6b8';

const _baseCreatedAt = 1700000000;

/// A 64-character hex id made of one repeated digit.
String _id(String digit) => digit * 64;

Event _message({
  required String id,
  String author = _peer,
  int createdAt = _baseCreatedAt,
}) => Event.fromJson({
  'id': id,
  'pubkey': author,
  'created_at': createdAt,
  'kind': EventKind.privateDirectMessage,
  'tags': [
    ['p', _owner],
  ],
  'content': 'message $id',
  'sig': '',
});

Event _retraction({required String id, required String target}) =>
    Event.fromJson({
      'id': id,
      'pubkey': _peer,
      'created_at': _baseCreatedAt + 2,
      'kind': EventKind.eventDeletion,
      'tags': [
        ['e', target],
        ['p', _owner],
        ['k', '14'],
      ],
      'content': '',
      'sig': '',
    });

/// One app launch: the encrypted database file opened, and a listening
/// repository on top of it.
class _Launch {
  _Launch._(this.db, this.repository, this._relay, this._rumorByWrapId);

  final AppDatabase db;
  final DmRepository repository;
  final StreamController<Event> _relay;
  final Map<String, Event> _rumorByWrapId;
  bool _stopped = false;

  static Future<_Launch> start(
    String dbPath,
    Map<String, Event> rumorByWrapId,
  ) async {
    final db = AppDatabase(
      openEncryptedConnection(rawKeyHex: _cipherKey, databasePath: dbPath),
    );
    final messagesDao = DirectMessagesDao(db);
    final conversationsDao = ConversationsDao(db);
    final nostrClient = _MockNostrClient();
    final relay = StreamController<Event>();

    when(() => nostrClient.connectedRelayCount).thenReturn(1);
    when(() => nostrClient.configuredRelayCount).thenReturn(1);
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
      (_) async => (events: const <Event>[], timedOut: false, noRelays: false),
    );
    when(() => nostrClient.unsubscribe(any())).thenAnswer((_) async {});
    when(
      () => nostrClient.subscribe(
        any(),
        subscriptionId: any(named: 'subscriptionId'),
        tempRelays: any(named: 'tempRelays'),
        targetRelays: any(named: 'targetRelays'),
      ),
    ).thenAnswer((_) => relay.stream);

    final reactions =
        DmReactionsRepository(
          reactionsDao: DmReactionsDao(db),
          conversationsDao: conversationsDao,
          directMessagesDao: messagesDao,
        )..setCredentials(
          userPubkey: _owner,
          messageService: _MockNip17MessageService(),
        );

    final repository = DmRepository(
      nostrClient: nostrClient,
      directMessagesDao: messagesDao,
      conversationsDao: conversationsDao,
      processedGiftWrapsDao: ProcessedGiftWrapsDao(db),
      removedConversationsDao: db.removedConversationsDao,
      removedMessageIdsDao: db.removedMessageIdsDao,
      reactionsRepository: reactions,
      userPubkey: _owner,
      signer: LocalNostrSigner(_privateKey),
      rumorDecryptor: (_, giftWrap) async => rumorByWrapId[giftWrap.id],
      nip04Decryptor: (_, ciphertext) async => ciphertext,
    );
    await repository.startListening();
    final launch = _Launch._(db, repository, relay, rumorByWrapId);
    addTearDown(launch.stop);
    return launch;
  }

  /// Feeds one gift wrap that decrypts to [rumor] and waits until the
  /// repository has stored its message or recorded the wrap as handled.
  ///
  /// The encrypted database runs on a background isolate, so draining this
  /// isolate's event queue does not wait for the ingest to finish.
  Future<void> deliver({required String wrapId, required Event rumor}) async {
    _rumorByWrapId[wrapId] = rumor;
    _relay.add(
      Event.fromJson({
        'id': wrapId,
        'pubkey': _peer,
        'created_at': rumor.createdAt,
        'kind': EventKind.giftWrap,
        'tags': [
          ['p', _owner],
        ],
        'content': 'wrapped-$wrapId',
        'sig': '',
      }),
    );
    for (var attempt = 0; attempt < 200; attempt += 1) {
      await pumpEventQueue();
      if (await DirectMessagesDao(db).hasGiftWrap(wrapId) ||
          await ProcessedGiftWrapsDao(db).hasGiftWrap(wrapId)) {
        return;
      }
    }
    fail('gift wrap $wrapId was never stored or recorded as handled');
  }

  Future<DirectMessageRow?> message(String id) =>
      DirectMessagesDao(db).getMessageById(id, ownerPubkey: _owner);

  Future<ConversationRow?> conversation(String id) =>
      ConversationsDao(db).getConversation(id, ownerPubkey: _owner);

  /// Ends the launch. The database must be closed before the file is salvaged.
  Future<void> stop() async {
    if (_stopped) return;
    _stopped = true;
    // stopListening() before closing the stream: onDone would otherwise arm
    // a reconnect timer that outlives this test.
    await repository.stopListening();
    await _relay.close();
    await db.close();
  }
}

void main() {
  setUpAll(() {
    // queryEventsDetailed takes a `Duration timeout`, so a stub matching on
    // it needs a fallback.
    registerFallbackValue(Duration.zero);
  });

  // A salvage rebuilds the database from the tables that have no other copy
  // and leaves the rest empty; the app then clears the DM sync state, so the
  // relays hand every stored gift wrap back. Real DAOs over an encrypted file,
  // because the salvage works on the file between two launches.
  group('Messages after a database salvage', () {
    late Directory tempRoot;
    late String dbPath;
    late Map<String, Event> rumorByWrapId;

    final peerConversation = DmRepository.computeConversationId([
      _owner,
      _peer,
    ]);

    setUp(() {
      tempRoot = Directory.systemTemp.createTempSync('dm_after_salvage_test_');
      dbPath = '${tempRoot.path}/divine_db.db';
      rumorByWrapId = <String, Event>{};
    });

    tearDown(() {
      if (tempRoot.existsSync()) tempRoot.deleteSync(recursive: true);
    });

    Future<void> salvage() async {
      expect(
        await salvageCorruptEncryptedDatabase(
          rawKeyHex: _cipherKey,
          databasePath: dbPath,
        ),
        isTrue,
        reason: 'precondition: the salvage must replace the database',
      );
    }

    group('a conversation the user removed', () {
      test('stays removed when its messages are replayed', () async {
        final removed = _message(id: _id('1'));
        final kept = _message(id: _id('4'), author: _peer2);
        final before = await _Launch.start(dbPath, rumorByWrapId);
        await before.deliver(wrapId: _id('a'), rumor: removed);
        await before.deliver(wrapId: _id('d'), rumor: kept);
        expect(
          await before.repository.removeConversation(peerConversation),
          ConversationRemovalOutcome.removed,
        );
        await before.stop();

        await salvage();

        final after = await _Launch.start(dbPath, rumorByWrapId);
        await after.deliver(wrapId: _id('a'), rumor: removed);
        await after.deliver(wrapId: _id('d'), rumor: kept);

        expect(
          await after.message(_id('4')),
          isNotNull,
          reason: 'the conversation the user kept must come back',
        );
        expect(await after.message(_id('1')), isNull);
        expect(await after.conversation(peerConversation), isNull);
      });

      test(
        'stays removed when a replayed message is stamped after the removal',
        () async {
          // A sender picks `created_at`, so the removal time cannot rule this
          // message out: only its recorded id can.
          final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
          final removed = _message(id: _id('1'), createdAt: now - 1800);
          final kept = _message(id: _id('4'), author: _peer2);
          final before = await _Launch.start(dbPath, rumorByWrapId);
          await before.deliver(wrapId: _id('a'), rumor: removed);
          await before.deliver(wrapId: _id('d'), rumor: kept);
          await before.repository.removeConversation(peerConversation);
          // The removal is an hour old, so it predates the message's stamp.
          await before.db.customStatement(
            'UPDATE removed_conversations SET removed_at = removed_at - 3600',
          );
          await before.stop();

          await salvage();

          final after = await _Launch.start(dbPath, rumorByWrapId);
          await after.deliver(wrapId: _id('a'), rumor: removed);
          await after.deliver(wrapId: _id('d'), rumor: kept);

          expect(
            await after.message(_id('4')),
            isNotNull,
            reason: 'the conversation the user kept must come back',
          );
          expect(await after.message(_id('1')), isNull);
          expect(await after.conversation(peerConversation), isNull);
        },
      );
    });

    group('a message its sender deleted for everyone', () {
      test('stays deleted when it and its deletion are replayed', () async {
        final message = _message(id: _id('1'));
        final deletion = _retraction(id: _id('2'), target: _id('1'));
        final before = await _Launch.start(dbPath, rumorByWrapId);
        await before.deliver(wrapId: _id('a'), rumor: message);
        await before.deliver(wrapId: _id('b'), rumor: deletion);
        expect(
          (await before.message(_id('1')))?.isDeleted,
          isTrue,
          reason: 'precondition: the deletion applied before the salvage',
        );
        await before.stop();

        await salvage();

        final after = await _Launch.start(dbPath, rumorByWrapId);
        await after.deliver(wrapId: _id('a'), rumor: message);
        await after.deliver(wrapId: _id('b'), rumor: deletion);

        // The dedup ledger recorded the deletion's wrap as handled. Salvaged
        // without the messages it stood for, it would make the replay skip the
        // deletion and show the message again.
        final replayed = await after.message(_id('1'));
        expect(
          replayed,
          isNotNull,
          reason: 'the replay must restore the message row',
        );
        expect(replayed!.isDeleted, isTrue);
      });
    });
  });
}
