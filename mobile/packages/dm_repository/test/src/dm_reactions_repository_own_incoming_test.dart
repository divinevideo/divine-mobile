// ABOUTME: An own reaction that arrives from relays (sent from another device,
// ABOUTME: or re-synced after a reinstall) is stored as own and `received`,
// ABOUTME: so own-reaction UI has to handle `received`, not only peer rows
// ABOUTME: (#8697).

import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/event_kind.dart';

class _MockNip17MessageService extends Mock implements NIP17MessageService {}

const _owner =
    '1111111111111111111111111111111111111111111111111111111111111111';
const _peer =
    '2222222222222222222222222222222222222222222222222222222222222222';
const _messageId =
    '4444444444444444444444444444444444444444444444444444444444444444';

void main() {
  group(DmReactionsRepository, () {
    late AppDatabase db;
    late DmReactionsRepository reactions;

    setUp(() {
      db = AppDatabase.test(NativeDatabase.memory());
      reactions =
          DmReactionsRepository(
            reactionsDao: DmReactionsDao(db),
            conversationsDao: ConversationsDao(db),
            directMessagesDao: DirectMessagesDao(db),
          )..setCredentials(
            userPubkey: _owner,
            messageService: _MockNip17MessageService(),
          );
    });

    tearDown(() => db.close());

    /// Each side reacts to a message the other one wrote.
    Future<DmReaction> ingestReactionBy(String reactorPubkey) async {
      final messageAuthor = reactorPubkey == _owner ? _peer : _owner;
      final rumor = Event(reactorPubkey, EventKind.reaction, [
        ['e', _messageId],
        ['p', messageAuthor],
      ], '🔥');

      final outcome = await reactions.persistIncoming(
        rumorEvent: rumor,
        giftWrapId: 'wrap-${rumor.id}',
      );
      expect(outcome, equals(DmWrapOutcome.processed));

      final stored = await reactions
          .watchForConversation(
            DmRepository.computeConversationId([_owner, _peer]),
          )
          .first;
      return stored.single;
    }

    group('persistIncoming', () {
      test('stores an own reaction delivered from relays as own and '
          'received', () async {
        final reaction = await ingestReactionBy(_owner);

        expect(reaction.isOwn, isTrue);
        expect(
          reaction.publishStatus,
          equals(DmReactionPublishStatus.received),
        );
      });

      test("stores a peer's reaction as received too", () async {
        final reaction = await ingestReactionBy(_peer);

        expect(reaction.isOwn, isFalse);
        expect(
          reaction.publishStatus,
          equals(DmReactionPublishStatus.received),
        );
      });
    });
  });
}
