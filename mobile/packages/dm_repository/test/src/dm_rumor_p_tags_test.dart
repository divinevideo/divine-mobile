// ABOUTME: Regression coverage for #9774 — the p tags of the wrapped rumors
// ABOUTME: Divine builds for a DM reaction, its removal, and a message deleted
// ABOUTME: for everyone, and that rumors queued in the earlier shape still go
// ABOUTME: out unchanged.

import 'dart:convert';

import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/client_utils/keys.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/event_kind.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';

class _MockNostrClient extends Mock implements NostrClient {}

final String _ownerSecret = '1' * 64;
final String _owner = getPublicKey(_ownerSecret);
final String _alice = getPublicKey('2' * 64);
final String _bob = getPublicKey('3' * 64);

const _messageCreatedAt = 1700000000;

/// The real rumor builder, with every send recorded instead of published.
class _WireRecordingMessageService extends NIP17MessageService {
  _WireRecordingMessageService(NostrClient nostrClient)
    : super(
        signer: LocalNostrSigner(_ownerSecret),
        senderPublicKey: _owner,
        nostrService: nostrClient,
      );

  final List<({Event rumor, String recipient})> wire = [];

  @override
  Future<NIP17SendResult> sendRumor({
    required Event rumorEvent,
    required String recipientPubkey,
    List<String>? targetRelays,
    List<String>? selfWrapTargetRelays,
    bool awaitRecipientOk = false,
    bool selfWrapOnSoftUnconfirmed = true,
    Duration? recipientWrapBuildTimeout,
    Duration? selfWrapBuildTimeout,
    void Function(Event? prebuiltSelfWrap)? onSelfWrapDue,
  }) async {
    wire.add((rumor: rumorEvent, recipient: recipientPubkey));
    return NIP17SendResult.success(
      rumorEventId: rumorEvent.id,
      messageEventId: 'wrap-${rumorEvent.id}-$recipientPubkey',
      recipientPubkey: recipientPubkey,
    );
  }

  /// The one rumor of [kind] that went out, whoever it was sent to.
  Event sentRumor(int kind) {
    final ids = {
      for (final send in wire)
        if (send.rumor.kind == kind) send.rumor.id,
    };
    expect(ids, hasLength(1), reason: 'exactly one kind-$kind rumor was sent');
    return wire.firstWhere((send) => send.rumor.id == ids.single).rumor;
  }

  Set<String> recipientsOf(int kind) => {
    for (final send in wire)
      if (send.rumor.kind == kind) send.recipient,
  };
}

List<String> _tagValues(Event rumor, String name) => [
  for (final tag in rumor.tags)
    if (tag.length >= 2 && tag[0] == name) tag[1],
];

void main() {
  setUpAll(() {
    // queryEventsDetailed takes a `Duration timeout`, so a stub matching on
    // it needs a fallback (#8212).
    registerFallbackValue(Duration.zero);
  });

  group('DM reaction rumors (#9774)', () {
    late AppDatabase db;
    late DmReactionsDao reactionsDao;
    late ConversationsDao conversationsDao;
    late DirectMessagesDao messagesDao;
    late _WireRecordingMessageService messageService;
    late DmReactionsRepository reactions;

    void openFreshDatabase() {
      db = AppDatabase.test(NativeDatabase.memory());
      reactionsDao = DmReactionsDao(db);
      conversationsDao = ConversationsDao(db);
      messagesDao = DirectMessagesDao(db);
      messageService = _WireRecordingMessageService(_MockNostrClient());
      reactions =
          DmReactionsRepository(
            reactionsDao: reactionsDao,
            conversationsDao: conversationsDao,
            directMessagesDao: messagesDao,
          )..setCredentials(
            userPubkey: _owner,
            messageService: messageService,
          );
    }

    setUp(openFreshDatabase);

    tearDown(() => db.close());

    /// Stores the conversation with its participants in exactly this order.
    Future<String> seedConversation(List<String> participants) async {
      final id = DmRepository.computeConversationId(participants);
      await conversationsDao.upsertConversation(
        id: id,
        participantPubkeys: jsonEncode(participants),
        isGroup: participants.length > 2,
        createdAt: _messageCreatedAt,
        ownerPubkey: _owner,
      );
      return id;
    }

    Future<void> seedMessage({
      required String id,
      required String conversationId,
      required String sender,
      int kind = EventKind.privateDirectMessage,
    }) async {
      await messagesDao.insertMessage(
        id: id,
        conversationId: conversationId,
        senderPubkey: sender,
        content: 'hello',
        createdAt: _messageCreatedAt,
        giftWrapId: '0' * 64,
        messageKind: kind,
        ownerPubkey: _owner,
      );
    }

    Future<String> react({
      required String conversationId,
      required String targetMessageId,
      required String targetMessageAuthor,
    }) async {
      final result = await reactions.publish(
        conversationId: conversationId,
        targetMessageId: targetMessageId,
        targetMessageAuthor: targetMessageAuthor,
        emoji: '❤️',
      );
      expect(result.success, isTrue);
      return result.rumorId;
    }

    group('publish', () {
      test('names the reacted author in a single p tag', () async {
        final room = await seedConversation([_owner, _alice]);
        final message = 'a' * 64;
        await seedMessage(id: message, conversationId: room, sender: _alice);

        await react(
          conversationId: room,
          targetMessageId: message,
          targetMessageAuthor: _alice,
        );

        final rumor = messageService.sentRumor(EventKind.reaction);
        expect(_tagValues(rumor, 'p'), equals([_alice]));
        expect(_tagValues(rumor, 'e'), equals([message]));
      });

      test('names you once when you react to your own message', () async {
        final room = await seedConversation([_owner, _alice, _bob]);
        final message = 'b' * 64;
        await seedMessage(id: message, conversationId: room, sender: _owner);

        await react(
          conversationId: room,
          targetMessageId: message,
          targetMessageAuthor: _owner,
        );

        final rumor = messageService.sentRumor(EventKind.reaction);
        expect(_tagValues(rumor, 'p'), equals([_owner]));
        expect(
          messageService.recipientsOf(EventKind.reaction),
          equals({_alice, _bob}),
        );
      });
    });

    group('removeOwn', () {
      test('sends a removal that names no one', () async {
        final room = await seedConversation([_owner, _alice, _bob]);
        final message = 'e' * 64;
        await seedMessage(id: message, conversationId: room, sender: _alice);
        final reaction = await react(
          conversationId: room,
          targetMessageId: message,
          targetMessageAuthor: _alice,
        );

        await reactions.removeOwn(
          rumorId: reaction,
          targetMessageAuthor: _alice,
        );
        await pumpEventQueue();

        final removal = messageService.sentRumor(EventKind.eventDeletion);
        expect(_tagValues(removal, 'p'), isEmpty);
        expect(_tagValues(removal, 'e'), equals([reaction]));
        expect(_tagValues(removal, 'k'), equals(['${EventKind.reaction}']));
        expect(
          messageService.recipientsOf(EventKind.eventDeletion),
          equals({_alice, _bob}),
        );
      });

      test('stores a removal that names no one when it is held', () async {
        // No conversation row and no stored message: nothing proves the room,
        // so the removal is recorded and left for the retry sweep.
        final reactionId = '9' * 64;
        await reactionsDao.insertOwnReactionSuperseding(
          placeholderId: reactionId,
          conversationId: DmRepository.computeConversationId([
            _owner,
            _alice,
            _bob,
          ]),
          targetMessageId: 'b' * 64,
          targetMessageAuthor: _owner,
          reactorPubkey: _owner,
          emoji: '❤️',
          createdAt: _messageCreatedAt + 1,
          ownerPubkey: _owner,
          rumorEventJson: '{}',
        );

        await reactions.removeOwn(
          rumorId: reactionId,
          targetMessageAuthor: _owner,
        );

        expect(messageService.wire, isEmpty, reason: 'the removal is held');
        final row = await reactionsDao.getById(
          id: reactionId,
          ownerPubkey: _owner,
        );
        final stored = Event.fromJson(
          jsonDecode(row!.rumorEventJson!) as Map<String, dynamic>,
        );
        expect(stored.kind, equals(EventKind.eventDeletion));
        expect(_tagValues(stored, 'e'), equals([reactionId]));
        expect(_tagValues(stored, 'p'), isEmpty);
      });
    });

    group('rumors queued before #9774', () {
      test('retry sends a queued reaction exactly as stored', () async {
        final room = await seedConversation([_owner, _alice]);
        final message = 'a' * 64;
        await seedMessage(id: message, conversationId: room, sender: _alice);
        final queued = Event(
          _owner,
          EventKind.reaction,
          [
            ['p', _alice],
            ['e', message],
            ['p', _alice],
            ['k', '${EventKind.privateDirectMessage}'],
          ],
          '❤️',
          createdAt: _messageCreatedAt + 1,
        );
        await reactionsDao.insertOwnReactionSuperseding(
          placeholderId: queued.id,
          conversationId: room,
          targetMessageId: message,
          targetMessageAuthor: _alice,
          reactorPubkey: _owner,
          emoji: '❤️',
          createdAt: queued.createdAt,
          ownerPubkey: _owner,
          rumorEventJson: jsonEncode(queued.toJson()),
          recipientPubkeys: jsonEncode([_alice]),
        );

        final result = await reactions.retry(
          rumorId: queued.id,
          targetMessageAuthor: _alice,
        );

        expect(result.success, isTrue);
        final sent = messageService.sentRumor(EventKind.reaction);
        expect(sent.id, equals(queued.id));
        expect(sent.tags, equals(queued.tags));
      });

      test('retryDeletion sends a queued removal exactly as stored', () async {
        final room = await seedConversation([_owner, _alice, _bob]);
        final reactionId = '7' * 64;
        await reactionsDao.insertOwnReactionSuperseding(
          placeholderId: reactionId,
          conversationId: room,
          targetMessageId: 'a' * 64,
          targetMessageAuthor: _alice,
          reactorPubkey: _owner,
          emoji: '❤️',
          createdAt: _messageCreatedAt + 1,
          ownerPubkey: _owner,
          rumorEventJson: '{}',
          recipientPubkeys: jsonEncode([_alice, _bob]),
        );
        final queued = Event(
          _owner,
          EventKind.eventDeletion,
          [
            ['p', _alice],
            ['e', reactionId],
            ['k', '${EventKind.reaction}'],
          ],
          '',
          createdAt: _messageCreatedAt + 2,
        );
        await reactionsDao.markOwnDeletionPending(
          id: reactionId,
          ownerPubkey: _owner,
          deletionRumorJson: jsonEncode(queued.toJson()),
        );

        await reactions.retryDeletion(
          rumorId: reactionId,
          targetMessageAuthor: _alice,
        );

        final sent = messageService.sentRumor(EventKind.eventDeletion);
        expect(sent.id, equals(queued.id));
        expect(sent.tags, equals(queued.tags));
        expect(
          messageService.recipientsOf(EventKind.eventDeletion),
          equals({_alice, _bob}),
        );
      });

      test(
        'persistIncoming binds a doubled-p reaction to its author',
        () async {
          final room = await seedConversation([_owner, _alice]);
          final message = 'a' * 64;
          await seedMessage(id: message, conversationId: room, sender: _owner);
          final received = Event(
            _alice,
            EventKind.reaction,
            [
              ['p', _owner],
              ['e', message],
              ['p', _owner],
              ['k', '${EventKind.privateDirectMessage}'],
            ],
            '🔥',
            createdAt: _messageCreatedAt + 1,
          );

          final outcome = await reactions.persistIncoming(
            rumorEvent: received,
            giftWrapId: '6' * 64,
          );

          expect(outcome, equals(DmWrapOutcome.processed));
          final row = await reactionsDao.getById(
            id: received.id,
            ownerPubkey: _owner,
          );
          expect(row?.targetMessageAuthor, equals(_owner));
          expect(row?.conversationId, equals(room));
        },
      );
    });
  });
}
