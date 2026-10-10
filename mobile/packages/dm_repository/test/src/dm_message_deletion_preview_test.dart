// ABOUTME: Regression coverage for the inbox preview after a delete for
// ABOUTME: everyone. Once a relay confirms the retraction, the conversation
// ABOUTME: row shows the newest message that is still in the thread.

import 'dart:convert';

import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockMessageService extends Mock implements NIP17MessageService {}

class _FakeEvent extends Fake implements Event {}

/// A real [DirectMessagesDao] that can be told to throw from the read a
/// preview refresh starts with.
///
/// The override delegates to `super` unless [failNewestMessageRead] is set, so
/// every other test in this file runs the production query.
class _InstrumentedDirectMessagesDao extends DirectMessagesDao {
  _InstrumentedDirectMessagesDao(super.attachedDatabase);

  bool failNewestMessageRead = false;

  /// How many reads were refused, so a test can prove the refresh was tried.
  int refusedReads = 0;

  @override
  Future<List<DirectMessageRow>> getMessagesForConversation(
    String conversationId, {
    int? limit,
    int? offset,
    String? ownerPubkey,
  }) async {
    if (failNewestMessageRead) {
      refusedReads++;
      throw StateError('injected newest-message read failure');
    }
    return super.getMessagesForConversation(
      conversationId,
      limit: limit,
      offset: offset,
      ownerPubkey: ownerPubkey,
    );
  }
}

const _owner =
    'a4f5c1b2d3e4f5061728394a5b6c7d8e9f0a1b2c3d4e5f60718293a4b5c6d7e8';
const _peer =
    'b1c2d3e4f5061728394a5b6c7d8e9f0a1b2c3d4e5f60718293a4b5c6d7e8f9a0';
const _secondPeer =
    'c2d3e4f5061728394a5b6c7d8e9f0a1b2c3d4e5f60718293a4b5c6d7e8f9a0b1';
const _privateKey =
    '5426e5b8b4b0e2a1f5e8d3c7a9b2f4e6d8c0a2b4f6e8d0c2a4b6f8e0d2c4a6b8';

const List<String> _oneToOne = [_owner, _peer];
const List<String> _groupChat = [_owner, _peer, _secondPeer];

const _baseCreatedAt = 1700000000;

/// The terminal status of a confirmed retraction. The DAO keeps the constant
/// private because nothing outside it writes the value.
const _deletionSent = 'deletion_sent';

/// A 64-character hex id made of one repeated digit.
String _id(String digit) => digit * 64;

/// One stored message, with the fields this file seeds and compares.
typedef _StoredMessage = ({
  String id,
  String giftWrapId,
  String sender,
  String content,
  int createdAt,
});

/// The three denormalized columns an inbox row renders its preview from.
typedef _Preview = ({String? content, int? timestamp, String? sender});

final _StoredMessage _fromPeer = (
  id: _id('1'),
  giftWrapId: _id('a'),
  sender: _peer,
  content: 'see you at eight',
  createdAt: _baseCreatedAt,
);

final _StoredMessage _fromOwner = (
  id: _id('2'),
  giftWrapId: _id('b'),
  sender: _owner,
  content: 'sent to the wrong chat',
  createdAt: _baseCreatedAt + 60,
);

const _Preview _noPreview = (content: null, timestamp: null, sender: null);

_Preview _previewOf(_StoredMessage message) => (
  content: message.content,
  timestamp: message.createdAt,
  sender: message.sender,
);

void main() {
  // Real DAOs against a real database. The mock suite in
  // dm_repository_test.dart answers the preview's newest-message read with a
  // row the test typed, so it cannot see that the thread query keeps showing
  // the sender's own retraction until a relay confirms it.
  group('the inbox preview after a delete for everyone', () {
    late AppDatabase db;
    late _InstrumentedDirectMessagesDao messagesDao;
    late ConversationsDao conversationsDao;
    late _MockNostrClient nostrClient;
    late _MockMessageService messageService;
    late DmRepository repository;

    /// Whether a relay confirms each deletion wrap. Tests flip it.
    late bool relayConfirms;

    setUpAll(() {
      registerFallbackValue(_FakeEvent());
      // queryEventsDetailed takes a `Duration timeout`.
      registerFallbackValue(Duration.zero);
    });

    setUp(() {
      db = AppDatabase.test(NativeDatabase.memory());
      messagesDao = _InstrumentedDirectMessagesDao(db);
      conversationsDao = ConversationsDao(db);
      nostrClient = _MockNostrClient();
      messageService = _MockMessageService();
      relayConfirms = true;

      // The relays answer and nobody advertises a kind-10050, so a wrap the
      // default pool confirms is scored as delivered rather than downgraded
      // for an inbox that could not be read (#8515).
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
      // Mirrors NIP17MessageService.buildRumor, which is pure construction.
      when(
        () => messageService.buildRumor(
          recipientPubkey: any(named: 'recipientPubkey'),
          content: any(named: 'content'),
          eventKind: any(named: 'eventKind'),
          additionalTags: any(named: 'additionalTags'),
          createdAt: any(named: 'createdAt'),
        ),
      ).thenAnswer(
        (invocation) => Event(
          _owner,
          invocation.namedArguments[#eventKind] as int,
          [
            ['p', invocation.namedArguments[#recipientPubkey] as String],
            ...invocation.namedArguments[#additionalTags] as List<List<String>>,
          ],
          invocation.namedArguments[#content] as String,
          createdAt: invocation.namedArguments[#createdAt] as int?,
        ),
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
        ),
      ).thenAnswer((invocation) async {
        if (!relayConfirms) {
          return const NIP17SendResult.failure('no relay confirmed the wrap');
        }
        final rumor = invocation.namedArguments[#rumorEvent] as Event;
        return NIP17SendResult.success(
          rumorEventId: rumor.id,
          messageEventId: _id('f'),
          recipientPubkey:
              invocation.namedArguments[#recipientPubkey] as String,
        );
      });

      repository = DmRepository(
        nostrClient: nostrClient,
        messageService: messageService,
        directMessagesDao: messagesDao,
        conversationsDao: conversationsDao,
        userPubkey: _owner,
        signer: LocalNostrSigner(_privateKey),
      );
    });

    tearDown(() async {
      await db.close();
    });

    /// Stores [message] in the conversation of [participants] and lets the
    /// conversation row take it as the preview, as persisting it does.
    Future<void> seed(
      _StoredMessage message, {
      List<String> participants = _oneToOne,
    }) async {
      final sorted = [...participants]..sort();
      final conversationId = DmRepository.computeConversationId(sorted);
      await messagesDao.insertMessage(
        id: message.id,
        conversationId: conversationId,
        senderPubkey: message.sender,
        content: message.content,
        createdAt: message.createdAt,
        giftWrapId: message.giftWrapId,
        ownerPubkey: _owner,
      );
      await conversationsDao.upsertConversation(
        id: conversationId,
        participantPubkeys: jsonEncode(sorted),
        isGroup: sorted.length > 2,
        createdAt: message.createdAt,
        lastMessageContent: message.content,
        lastMessageTimestamp: message.createdAt,
        lastMessageSenderPubkey: message.sender,
        currentUserHasSent: message.sender == _owner,
        ownerPubkey: _owner,
      );
    }

    /// Deletes [id] and waits out the delivery attempt, which the delete
    /// starts without awaiting.
    Future<void> deleteForEveryone(String id) async {
      await repository.deleteMessageForEveryone(id);
      await pumpEventQueue();
    }

    Future<String?> retractionStatus(String id) async {
      final row = await messagesDao.getMessageById(id, ownerPubkey: _owner);
      expect(row, isNotNull, reason: 'a retracted message keeps its row');
      return row!.deletionPublishStatus;
    }

    Future<_Preview> inboxPreview({
      List<String> participants = _oneToOne,
    }) async {
      final row = await conversationsDao.getConversation(
        DmRepository.computeConversationId(participants),
        ownerPubkey: _owner,
      );
      expect(row, isNotNull, reason: 'the conversation must still be listed');
      return (
        content: row!.lastMessageContent,
        timestamp: row.lastMessageTimestamp,
        sender: row.lastMessageSenderPubkey,
      );
    }

    test('shows the previous message once the delete is confirmed', () async {
      await seed(_fromPeer);
      await seed(_fromOwner);

      await deleteForEveryone(_fromOwner.id);

      expect(
        await retractionStatus(_fromOwner.id),
        equals(_deletionSent),
        reason: 'the relay confirmed the wrap, so the retraction is settled',
      );
      expect(
        await inboxPreview(),
        equals(_previewOf(_fromPeer)),
        reason:
            'the deleted message left the thread on confirmation, so the '
            'inbox row must stop quoting it',
      );
    });

    test('is cleared once the only message is confirmed deleted', () async {
      await seed(_fromOwner);

      await deleteForEveryone(_fromOwner.id);

      expect(await retractionStatus(_fromOwner.id), equals(_deletionSent));
      expect(
        await inboxPreview(),
        equals(_noPreview),
        reason: 'nothing is left in the thread to quote',
      );
    });

    test(
      'shows the previous message of a group once every member confirmed',
      () async {
        await seed(_fromPeer, participants: _groupChat);
        await seed(_fromOwner, participants: _groupChat);

        await deleteForEveryone(_fromOwner.id);

        expect(await retractionStatus(_fromOwner.id), equals(_deletionSent));
        expect(
          await inboxPreview(participants: _groupChat),
          equals(_previewOf(_fromPeer)),
        );
      },
    );

    test(
      'shows the previous message when a retry is what confirms the delete',
      () async {
        await seed(_fromPeer);
        await seed(_fromOwner);
        relayConfirms = false;
        await deleteForEveryone(_fromOwner.id);
        expect(
          await retractionStatus(_fromOwner.id),
          equals(DirectMessagesDao.deletionPending),
          reason: 'nothing confirmed the wrap, so the sweep must retry it',
        );
        expect(
          await inboxPreview(),
          equals(_previewOf(_fromOwner)),
          reason:
              'an unconfirmed retraction is still shown in the thread, so it '
              'is still the newest message',
        );

        relayConfirms = true;
        final outcome = await repository.retryMessageDeletion(
          rumorId: _fromOwner.id,
        );

        expect(outcome, equals(DmMessageDeletionOutcome.sent));
        expect(await inboxPreview(), equals(_previewOf(_fromPeer)));
      },
    );

    test(
      'keeps a confirmed delete confirmed when the preview cannot be refreshed',
      () async {
        await seed(_fromPeer);
        await seed(_fromOwner);
        relayConfirms = false;
        await deleteForEveryone(_fromOwner.id);
        expect(
          await retractionStatus(_fromOwner.id),
          equals(DirectMessagesDao.deletionPending),
        );

        relayConfirms = true;
        messagesDao.failNewestMessageRead = true;
        final outcome = await repository.retryMessageDeletion(
          rumorId: _fromOwner.id,
        );

        expect(
          messagesDao.refusedReads,
          equals(1),
          reason: 'the confirmed retraction must have tried the refresh',
        );
        // The row is already settled and off the sweep's worklist, so
        // reporting the attempt unconfirmed would describe a retry that can
        // never happen.
        expect(outcome, equals(DmMessageDeletionOutcome.sent));
        expect(await retractionStatus(_fromOwner.id), equals(_deletionSent));
      },
    );
  });
}
