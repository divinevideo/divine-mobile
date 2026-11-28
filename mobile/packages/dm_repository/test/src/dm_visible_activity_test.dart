// ABOUTME: Real-database coverage for DmRepository.visibleActivityExcluding:
// ABOUTME: what a group's inbox row shows once the senders a viewer hides are
// ABOUTME: set aside (#10150).

import 'dart:convert';

import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/event_kind.dart';
import 'package:nostr_sdk/filter.dart' as nostr_filter;
import 'package:nostr_sdk/signer/nostr_signer.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockNIP17MessageService extends Mock implements NIP17MessageService {}

class _MockNostrSigner extends Mock implements NostrSigner {}

class _FakeEvent extends Fake implements Event {}

const _owner =
    'a4f5c1b2d3e4f5061728394a5b6c7d8e9f0a1b2c3d4e5f60718293a4b5c6d7e8';
const _visibleMember =
    'b1c2d3e4f5061728394a5b6c7d8e9f0a1b2c3d4e5f60718293a4b5c6d7e8f9a0';
const _hiddenMember =
    'c2d3e4f5061728394a5b6c7d8e9f0a1b2c3d4e5f60718293a4b5c6d7e8f9a0b1';

const _createdAt = 1700000000;

void main() {
  group('DmRepository.visibleActivityExcluding (#10150)', () {
    late AppDatabase db;
    late ConversationsDao conversationsDao;
    late DirectMessagesDao messagesDao;
    final roomId = DmRepository.computeConversationId([
      _owner,
      _visibleMember,
      _hiddenMember,
    ]);

    setUp(() {
      db = AppDatabase.test(NativeDatabase.memory());
      conversationsDao = ConversationsDao(db);
      messagesDao = DirectMessagesDao(db);
    });

    tearDown(() async {
      await db.close();
    });

    DmRepository buildRepository({String userPubkey = _owner}) => DmRepository(
      nostrClient: _MockNostrClient(),
      directMessagesDao: messagesDao,
      conversationsDao: conversationsDao,
      userPubkey: userPubkey,
    );

    /// Stores the room for [ownerPubkey], its preview on the hidden member's
    /// newest message, as ingest leaves it.
    Future<void> seedRoom({
      String ownerPubkey = _owner,
      bool withVisibleMessage = true,
    }) async {
      await conversationsDao.upsertConversation(
        id: roomId,
        participantPubkeys: '["$_owner","$_visibleMember","$_hiddenMember"]',
        isGroup: true,
        createdAt: _createdAt,
        lastMessageContent: 'from the hidden member',
        lastMessageTimestamp: _createdAt + 200,
        lastMessageSenderPubkey: _hiddenMember,
        isRead: false,
        currentUserHasSent: true,
        ownerPubkey: ownerPubkey,
      );
      if (withVisibleMessage) {
        await messagesDao.insertMessage(
          id: 'visible-$ownerPubkey',
          conversationId: roomId,
          senderPubkey: _visibleMember,
          content: 'from the visible member',
          createdAt: _createdAt + 100,
          giftWrapId: 'wrap-visible-$ownerPubkey',
          ownerPubkey: ownerPubkey,
        );
      }
      await messagesDao.insertMessage(
        id: 'hidden-$ownerPubkey',
        conversationId: roomId,
        senderPubkey: _hiddenMember,
        content: 'from the hidden member',
        createdAt: _createdAt + 200,
        giftWrapId: 'wrap-hidden-$ownerPubkey',
        ownerPubkey: ownerPubkey,
      );
    }

    test(
      'legacy identical same-second rows do not borrow a citation',
      () async {
        final repository = buildRepository();
        await repository.getConversation(roomId);
        for (final id in ['first', 'second']) {
          await messagesDao.insertMessage(
            id: id,
            conversationId: roomId,
            senderPubkey: _visibleMember,
            content: 'ambiguous',
            createdAt: _createdAt,
            giftWrapId: 'wrap-$id',
            ownerPubkey: _owner,
            tagsJson: id == 'second'
                ? '[["q","34236:$_owner:clip","","$_owner"]]'
                : null,
          );
        }
        await conversationsDao.upsertConversation(
          id: roomId,
          participantPubkeys: '["$_owner","$_visibleMember"]',
          isGroup: false,
          createdAt: _createdAt,
          lastMessageContent: 'ambiguous',
          lastMessageTimestamp: _createdAt,
          lastMessageSenderPubkey: _visibleMember,
          ownerPubkey: _owner,
        );
        expect(
          (await repository.getConversation(roomId))?.lastMessageIsVideoShare,
          isFalse,
        );
      },
    );

    test(
      'legacy file preview cannot borrow tags from identical text',
      () async {
        final repository = buildRepository();
        await repository.getConversation(roomId);
        await messagesDao.insertMessage(
          id: 'file',
          conversationId: roomId,
          senderPubkey: _visibleMember,
          content: 'attachment',
          createdAt: _createdAt,
          giftWrapId: 'file-wrap',
          messageKind: 15,
          fileType: 'image/png',
          ownerPubkey: _owner,
        );
        await messagesDao.insertMessage(
          id: 'text',
          conversationId: roomId,
          senderPubkey: _visibleMember,
          content: 'Sent a photo',
          createdAt: _createdAt,
          giftWrapId: 'text-wrap',
          tagsJson: '[["q","34236:$_owner:clip","","$_owner"]]',
          ownerPubkey: _owner,
        );
        await conversationsDao.upsertConversation(
          id: roomId,
          participantPubkeys: '["$_owner","$_visibleMember"]',
          isGroup: false,
          createdAt: _createdAt,
          lastMessageContent: 'Sent a photo',
          lastMessageTimestamp: _createdAt,
          lastMessageSenderPubkey: _visibleMember,
          ownerPubkey: _owner,
        );
        expect(
          (await repository.getConversation(roomId))?.lastMessageIsVideoShare,
          isFalse,
        );
      },
    );

    for (final higherIdFirst in [true, false]) {
      for (final firstIsShare in [true, false]) {
        for (final sameText in [true, false]) {
          test(
            'same-second inbox keeps first message citation '
            '(share first: $firstIsShare, identical text: $sameText, '
            'higher ID first: $higherIdFirst)',
            () async {
              final repository = buildRepository();
              await repository.getConversation(roomId);
              for (final first in [true, false]) {
                final id = first == higherIdFirst ? 'z' : 'a';
                final content = first || sameText ? 'same note' : 'second note';
                await messagesDao.insertMessage(
                  id: id,
                  conversationId: roomId,
                  senderPubkey: _visibleMember,
                  content: content,
                  createdAt: _createdAt,
                  giftWrapId: 'wrap-$id',
                  ownerPubkey: _owner,
                  tagsJson: first == firstIsShare
                      ? '[["q","34236:$_owner:clip","","$_owner"]]'
                      : null,
                );
                await conversationsDao.upsertConversation(
                  id: roomId,
                  participantPubkeys: '["$_owner","$_visibleMember"]',
                  isGroup: false,
                  createdAt: _createdAt,
                  lastMessageId: id,
                  lastMessageContent: content,
                  lastMessageTimestamp: _createdAt,
                  lastMessageSenderPubkey: _visibleMember,
                  ownerPubkey: _owner,
                );
              }
              final preview = await repository.getConversation(roomId);
              expect(preview?.lastMessageContent, 'same note');
              expect(preview?.lastMessageIsVideoShare, firstIsShare);
            },
          );
        }
      }
    }

    test(
      "maps the newest visible message and the room's unread state",
      () async {
        await seedRoom();

        final activity = await buildRepository().visibleActivityExcluding({
          roomId: {_hiddenMember},
        });

        expect(
          activity,
          equals({
            roomId: (
              lastMessageContent: 'from the visible member',
              lastMessageTimestamp: _createdAt + 100,
              lastMessageSenderPubkey: _visibleMember,
              lastMessageIsVideoShare: false,
              hasUnread: true,
            ),
          }),
        );
      },
    );

    test(
      'uses the newest visible non-reply citation after deletion',
      () async {
        await seedRoom();
        final repository = buildRepository();
        const tags = '[["q","34236:$_owner:clip","","$_owner"]]';
        await messagesDao.insertMessage(
          id: 'shared-clip',
          conversationId: roomId,
          senderPubkey: _visibleMember,
          content: 'my note',
          createdAt: _createdAt + 300,
          giftWrapId: 'wrap-clip',
          ownerPubkey: _owner,
          tagsJson: tags,
        );
        await conversationsDao.backfillLatestMessagePreviews(
          ownerPubkey: _owner,
        );
        expect(
          (await repository.getConversation(roomId))?.lastMessageIsVideoShare,
          isTrue,
        );
        expect(
          (await repository.visibleActivityExcluding({
            roomId: {_hiddenMember},
          }))[roomId]?.lastMessageIsVideoShare,
          isTrue,
        );
        await messagesDao.insertMessage(
          id: 'reply',
          conversationId: roomId,
          senderPubkey: _visibleMember,
          content: 'my reply',
          createdAt: _createdAt + 400,
          giftWrapId: 'wrap-reply',
          ownerPubkey: _owner,
          tagsJson: tags,
          replyToId: 'shared-clip',
        );
        await conversationsDao.backfillLatestMessagePreviews(
          ownerPubkey: _owner,
        );
        expect(
          (await repository.getConversation(roomId))?.lastMessageIsVideoShare,
          isFalse,
        );
        await messagesDao.markMessageDeleted('reply', ownerPubkey: _owner);
        await conversationsDao.backfillLatestMessagePreviews(
          ownerPubkey: _owner,
        );
        expect(
          (await repository.getConversation(roomId))?.lastMessageIsVideoShare,
          isTrue,
        );
      },
    );

    test(
      'maps a room nobody visible wrote in to an empty, read preview',
      () async {
        await seedRoom(withVisibleMessage: false);

        final activity = await buildRepository().visibleActivityExcluding({
          roomId: {_hiddenMember},
        });

        expect(
          activity,
          equals({
            roomId: (
              lastMessageContent: null,
              lastMessageTimestamp: null,
              lastMessageSenderPubkey: null,
              lastMessageIsVideoShare: false,
              hasUnread: false,
            ),
          }),
        );
      },
    );

    test('reads nothing, not a legacy ownerless row, while no owner is '
        'known', () async {
      // A row from before multi-account support carries the empty owner, so
      // an unguarded read with the empty pubkey would serve it (#8187).
      await seedRoom(ownerPubkey: '');
      final legacy = await conversationsDao.getConversation(
        roomId,
        ownerPubkey: '',
      );
      expect(legacy, isNotNull);

      final activity =
          await buildRepository(
            userPubkey: '',
          ).visibleActivityExcluding({
            roomId: {_hiddenMember},
          });

      expect(activity, isEmpty);
    });

    group('duplicate group sibling confirmation preserves lastMessageId', () {
      const shareContent = 'See https://divine.video/video/clip';
      final videoTags = [
        ['q', '34236:$_owner:clip', '', _owner],
      ];

      setUpAll(() {
        registerFallbackValue(_FakeEvent());
        registerFallbackValue(Duration.zero);
        registerFallbackValue(<nostr_filter.Filter>[]);
      });

      (_MockNostrClient, _MockNIP17MessageService, OutgoingDmsDao, DmRepository)
      buildSendableRepository({String Function()? sendBatchIdGenerator}) {
        final client = _MockNostrClient();
        when(() => client.connectedRelayCount).thenReturn(1);
        when(() => client.configuredRelayCount).thenReturn(1);
        when(
          () => client.configuredRelays,
        ).thenReturn(const ['wss://relay.divine.video']);
        when(() => client.isRelayAllowed(any())).thenReturn(true);
        when(
          () => client.queryEventsDetailed(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
            useCache: any(named: 'useCache'),
            useQueryPool: any(named: 'useQueryPool'),
            timeout: any(named: 'timeout'),
            requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
            acceptRelayClosedWhenOthersAnswered: any(
              named: 'acceptRelayClosedWhenOthersAnswered',
            ),
            silentRelayTimeout: any(named: 'silentRelayTimeout'),
          ),
        ).thenAnswer(
          (_) async =>
              (events: const <Event>[], timedOut: false, noRelays: false),
        );

        final messageService = _MockNIP17MessageService();
        when(
          () => messageService.canSendTo(any()),
        ).thenAnswer((_) async => true);
        when(
          () => messageService.buildGroupRumor(
            recipientPubkeys: any(named: 'recipientPubkeys'),
            content: any(named: 'content'),
            eventKind: any(named: 'eventKind'),
            additionalTags: any(named: 'additionalTags'),
            createdAt: any(named: 'createdAt'),
          ),
        ).thenAnswer((inv) {
          final recipients =
              (inv.namedArguments[#recipientPubkeys] as List<String>).toList()
                ..sort();
          final content = inv.namedArguments[#content] as String;
          final kind =
              (inv.namedArguments[#eventKind] as int?) ??
              EventKind.privateDirectMessage;
          final tags =
              (inv.namedArguments[#additionalTags] as List<List<String>>?) ??
              const <List<String>>[];
          final createdAt = inv.namedArguments[#createdAt] as int?;
          return Event(
            _owner,
            kind,
            [
              for (final p in recipients) ['p', p],
              ...tags,
            ],
            content,
            createdAt: createdAt,
          );
        });

        final outgoingDao = OutgoingDmsDao(db);
        final repository = DmRepository(
          nostrClient: client,
          messageService: messageService,
          directMessagesDao: messagesDao,
          conversationsDao: conversationsDao,
          outgoingDmsDao: outgoingDao,
          signer: _MockNostrSigner(),
          userPubkey: _owner,
          sendBatchIdGenerator: sendBatchIdGenerator,
        );
        return (client, messageService, outgoingDao, repository);
      }

      test(
        'sibling recovery via recoverFullSend preserves lastMessageId and '
        'video citation',
        () async {
          final batchId = 'b1' * 32;
          final firstRumorId = '11' * 32;
          final secondQueueId = '22' * 32;
          final tagsJson = jsonEncode(videoTags);

          await messagesDao.insertMessage(
            id: firstRumorId,
            conversationId: roomId,
            senderPubkey: _owner,
            content: shareContent,
            createdAt: _createdAt,
            giftWrapId: 'wrap-sibling-1',
            sendBatchId: batchId,
            tagsJson: tagsJson,
            ownerPubkey: _owner,
          );
          await conversationsDao.upsertConversation(
            id: roomId,
            participantPubkeys:
                '["$_owner","$_visibleMember","$_hiddenMember"]',
            isGroup: true,
            createdAt: _createdAt,
            lastMessageId: firstRumorId,
            lastMessageContent: shareContent,
            lastMessageTimestamp: _createdAt,
            lastMessageSenderPubkey: _owner,
            ownerPubkey: _owner,
            dmProtocol: 'nip17',
          );

          final (_, messageService, outgoingDao, repository) =
              buildSendableRepository();
          await outgoingDao.enqueue(
            OutgoingDm(
              id: secondQueueId,
              conversationId: roomId,
              recipientPubkey: _hiddenMember,
              content: shareContent,
              createdAt: _createdAt,
              rumorEventJson: jsonEncode({
                'id': firstRumorId,
                'pubkey': _owner,
                'created_at': _createdAt,
                'kind': EventKind.privateDirectMessage,
                'tags': [
                  ['p', _visibleMember],
                  ['p', _hiddenMember],
                  ...videoTags,
                  ['batch', batchId],
                ],
                'content': shareContent,
                'sig': '',
              }),
              recipientWrapStatus: OutgoingWrapStatus.failed,
              selfWrapStatus: OutgoingWrapStatus.failed,
              queuedAt: DateTime.fromMillisecondsSinceEpoch(0),
              ownerPubkey: _owner,
              sendBatchId: batchId,
            ),
          );

          when(
            () => messageService.sendRumor(
              rumorEvent: any(named: 'rumorEvent'),
              recipientPubkey: any(named: 'recipientPubkey'),
              targetRelays: any(named: 'targetRelays'),
              selfWrapTargetRelays: any(named: 'selfWrapTargetRelays'),
              awaitRecipientOk: any(named: 'awaitRecipientOk'),
              selfWrapOnSoftUnconfirmed: any(
                named: 'selfWrapOnSoftUnconfirmed',
              ),
              recipientWrapBuildTimeout: any(
                named: 'recipientWrapBuildTimeout',
              ),
              selfWrapBuildTimeout: any(named: 'selfWrapBuildTimeout'),
              onSelfWrapDue: any(named: 'onSelfWrapDue'),
              recipientWrap: any(named: 'recipientWrap'),
              publishRefusal: any(named: 'publishRefusal'),
            ),
          ).thenAnswer(
            (inv) async => NIP17SendResult.success(
              rumorEventId: firstRumorId,
              messageEventId: 'wrap-sibling-2',
              recipientPubkey: inv.namedArguments[#recipientPubkey] as String,
            ),
          );

          final recovered = await repository.recoverFullSend(
            rumorId: secondQueueId,
          );
          expect(recovered.success, isTrue);

          final storedRow = await conversationsDao.getConversation(
            roomId,
            ownerPubkey: _owner,
          );
          expect(storedRow?.lastMessageId, firstRumorId);
          expect(storedRow?.lastMessageTimestamp, _createdAt);
          expect(
            (await repository.getConversation(roomId))?.lastMessageIsVideoShare,
            isTrue,
          );
          await repository.stopListening();
        },
      );

      test(
        'racing sendGroupMessage confirmation when already persisted preserves '
        'lastMessageId and video citation',
        () async {
          final batchId = 'c2' * 32;
          final concurrentRumorId = '33' * 32;
          final tagsJson = jsonEncode(videoTags);

          final (_, messageService, _, repository) = buildSendableRepository(
            sendBatchIdGenerator: () => batchId,
          );

          var seededConcurrentWinner = false;
          when(
            () => messageService.sendRumor(
              rumorEvent: any(named: 'rumorEvent'),
              recipientPubkey: any(named: 'recipientPubkey'),
              targetRelays: any(named: 'targetRelays'),
              selfWrapTargetRelays: any(named: 'selfWrapTargetRelays'),
              awaitRecipientOk: any(named: 'awaitRecipientOk'),
              selfWrapOnSoftUnconfirmed: any(
                named: 'selfWrapOnSoftUnconfirmed',
              ),
              recipientWrapBuildTimeout: any(
                named: 'recipientWrapBuildTimeout',
              ),
              selfWrapBuildTimeout: any(named: 'selfWrapBuildTimeout'),
              onSelfWrapDue: any(named: 'onSelfWrapDue'),
              recipientWrap: any(named: 'recipientWrap'),
              publishRefusal: any(named: 'publishRefusal'),
            ),
          ).thenAnswer((inv) async {
            if (!seededConcurrentWinner) {
              seededConcurrentWinner = true;
              await messagesDao.insertMessage(
                id: concurrentRumorId,
                conversationId: roomId,
                senderPubkey: _owner,
                content: shareContent,
                createdAt: _createdAt,
                giftWrapId: 'wrap-concurrent',
                sendBatchId: batchId,
                tagsJson: tagsJson,
                ownerPubkey: _owner,
              );
              await conversationsDao.upsertConversation(
                id: roomId,
                participantPubkeys:
                    '["$_owner","$_visibleMember","$_hiddenMember"]',
                isGroup: true,
                createdAt: _createdAt,
                lastMessageId: concurrentRumorId,
                lastMessageContent: shareContent,
                lastMessageTimestamp: _createdAt,
                lastMessageSenderPubkey: _owner,
                ownerPubkey: _owner,
                dmProtocol: 'nip17',
              );
            }
            return NIP17SendResult.success(
              rumorEventId: concurrentRumorId,
              messageEventId: 'wrap-live',
              recipientPubkey: inv.namedArguments[#recipientPubkey] as String,
            );
          });

          final results = await repository.sendGroupMessage(
            recipientPubkeys: const [_visibleMember, _hiddenMember],
            content: shareContent,
            additionalTags: videoTags,
          );
          expect(results, hasLength(2));
          expect(results.every((r) => r.success), isTrue);

          final storedRow = await conversationsDao.getConversation(
            roomId,
            ownerPubkey: _owner,
          );
          expect(storedRow?.lastMessageId, concurrentRumorId);
          expect(storedRow?.lastMessageTimestamp, _createdAt);
          expect(
            (await repository.getConversation(roomId))?.lastMessageIsVideoShare,
            isTrue,
          );
          await repository.stopListening();
        },
      );
    });
  });
}
