// ABOUTME: Regression coverage for #7334: removing a DM reaction whose
// ABOUTME: deletion cannot be saved must put the reaction back on screen.

import 'dart:convert';

import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/event_kind.dart';
import 'package:openvine/blocs/dm/reactions/conversation_reactions_cubit.dart';

class _MockNip17MessageService extends Mock implements NIP17MessageService {}

const _owner =
    '1111111111111111111111111111111111111111111111111111111111111111';
const _peer =
    '2222222222222222222222222222222222222222222222222222222222222222';
const _messageId =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _reactionId =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _deletionId =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

void main() {
  group(ConversationReactionsCubit, () {
    late AppDatabase db;
    late List<String> reportedSites;
    late ConversationReactionsCubit cubit;
    final conversationId = DmRepository.computeConversationId([
      _owner,
      _peer,
    ]);

    setUp(() async {
      db = AppDatabase.test(NativeDatabase.memory());
      reportedSites = <String>[];
      final messageService = _MockNip17MessageService();
      when(
        () => messageService.buildRumor(
          recipientPubkey: any(named: 'recipientPubkey'),
          content: '',
          eventKind: EventKind.eventDeletion,
          additionalTags: any(named: 'additionalTags'),
        ),
      ).thenReturn(
        Event.fromJson({
          'id': _deletionId,
          'pubkey': _owner,
          'created_at': 1700000001,
          'kind': EventKind.eventDeletion,
          'tags': [
            ['e', _reactionId],
            ['k', EventKind.reaction.toString()],
          ],
          'content': '',
          'sig': '',
        }),
      );
      final repository =
          DmReactionsRepository(
            reactionsDao: db.dmReactionsDao,
            errorReporter: (_, _, {required site}) => reportedSites.add(site),
          )..setCredentials(
            userPubkey: _owner,
            messageService: messageService,
          );

      // A ❤️ the peer already received: published, then marked sent.
      await db.dmReactionsDao.insertOwnReactionSuperseding(
        placeholderId: _reactionId,
        conversationId: conversationId,
        targetMessageId: _messageId,
        targetMessageAuthor: _peer,
        reactorPubkey: _owner,
        emoji: '❤️',
        createdAt: 1700000000,
        ownerPubkey: _owner,
        rumorEventJson: '{}',
        recipientPubkeys: jsonEncode([_peer]),
      );
      await db.dmReactionsDao.swapPlaceholderId(
        placeholderId: _reactionId,
        realRumorId: _reactionId,
        ownerPubkey: _owner,
      );

      cubit = ConversationReactionsCubit(
        reactionsRepository: repository,
        ownerPubkey: _owner,
      );
    });

    tearDown(() async {
      await cubit.close();
      await db.close();
    });

    group('ConversationReactionToggled', () {
      test('puts the chip back when removing a delivered reaction fails '
          'to save', () async {
        final states = <ConversationReactionsState>[];
        final subscription = cubit.stream.listen(states.add);
        addTearDown(subscription.cancel);

        cubit.add(ConversationReactionsStarted(conversationId: conversationId));
        await pumpEventQueue();
        expect(
          cubit.state.reactionsFor(_messageId).where((r) => r.isOwn),
          hasLength(1),
        );

        await db.customStatement('''
          CREATE TRIGGER reject_reaction_removal
          BEFORE UPDATE ON dm_message_reactions
          WHEN NEW.publish_status = 'deletion_pending'
          BEGIN SELECT RAISE(ABORT, 'disk I/O error'); END
        ''');

        cubit.add(
          ConversationReactionToggled(
            conversationId: conversationId,
            messageId: _messageId,
            messageAuthorPubkey: _peer,
            emoji: '❤️',
          ),
        );
        await pumpEventQueue();

        // The removal really ran and really failed to save.
        expect(
          reportedSites,
          equals([DmReactionsRepositoryReportableSites.removeOwnSoftDelete]),
        );
        final row = await db.dmReactionsDao.getById(
          id: _reactionId,
          ownerPubkey: _owner,
        );
        expect(row?.isDeleted, isFalse);
        expect(row?.publishStatus, equals('sent'));
        // The chip was hidden on tap, then put back.
        expect(
          states.any(
            (s) => s.optimistic.values
                .whereType<OptimisticReactionRemoved>()
                .isNotEmpty,
          ),
          isTrue,
        );
        expect(cubit.state.optimistic, isEmpty);
        expect(
          cubit.state.reactionsFor(_messageId).where((r) => r.isOwn),
          hasLength(1),
        );
      });
    });
  });
}
