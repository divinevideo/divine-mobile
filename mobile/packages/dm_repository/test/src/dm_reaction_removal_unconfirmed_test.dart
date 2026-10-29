// ABOUTME: Regression coverage for #8390 — a reaction removal whose automatic
// ABOUTME: retries ran out is shown in the thread as a warning, stays retryable
// ABOUTME: by hand and by a later sweep, and leaves once a relay confirms it.

import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/event_kind.dart';

class _MockNip17MessageService extends Mock implements NIP17MessageService {}

class _FakeEvent extends Fake implements Event {}

const _owner =
    '1111111111111111111111111111111111111111111111111111111111111111';
const _peer =
    '2222222222222222222222222222222222222222222222222222222222222222';
const _targetMessageId =
    '4444444444444444444444444444444444444444444444444444444444444444';

void main() {
  setUpAll(() => registerFallbackValue(_FakeEvent()));

  group('unconfirmed reaction removal (#8390)', () {
    late AppDatabase db;
    late DmReactionsDao reactionsDao;
    late _MockNip17MessageService messageService;
    late DmReactionsRepository reactions;
    late String conversationId;

    setUp(() async {
      db = AppDatabase.test(NativeDatabase.memory());
      reactionsDao = DmReactionsDao(db);
      final conversationsDao = ConversationsDao(db);
      messageService = _MockNip17MessageService();

      when(
        () => messageService.buildRumor(
          recipientPubkey: any(named: 'recipientPubkey'),
          content: any(named: 'content'),
          eventKind: any(named: 'eventKind'),
          additionalTags: any(named: 'additionalTags'),
          createdAt: any(named: 'createdAt'),
        ),
      ).thenAnswer((invocation) {
        final tags = <List<String>>[
          ['p', invocation.namedArguments[#recipientPubkey] as String],
          ...invocation.namedArguments[#additionalTags] as List<List<String>>,
        ];
        return Event(
          _owner,
          invocation.namedArguments[#eventKind] as int,
          tags,
          invocation.namedArguments[#content] as String,
        );
      });

      when(
        () => messageService.buildDeletionRumor(
          targetEventId: any(named: 'targetEventId'),
          targetKind: any(named: 'targetKind'),
        ),
      ).thenAnswer(
        (invocation) => Event(_owner, EventKind.eventDeletion, [
          ['e', invocation.namedArguments[#targetEventId] as String],
          ['k', '${invocation.namedArguments[#targetKind]}'],
        ], ''),
      );

      reactions =
          DmReactionsRepository(
            reactionsDao: reactionsDao,
            conversationsDao: conversationsDao,
            directMessagesDao: DirectMessagesDao(db),
          )..setCredentials(
            userPubkey: _owner,
            messageService: messageService,
          );

      conversationId = DmRepository.computeConversationId([_owner, _peer]);
      await conversationsDao.upsertConversation(
        id: conversationId,
        participantPubkeys: '["$_owner","$_peer"]',
        isGroup: false,
        createdAt: 1700000000,
        ownerPubkey: _owner,
      );
    });

    tearDown(() => db.close());

    void stubWire(
      Future<NIP17SendResult> Function(Invocation invocation) answer,
    ) {
      when(
        () => messageService.sendRumor(
          rumorEvent: any(named: 'rumorEvent'),
          recipientPubkey: any(named: 'recipientPubkey'),
          targetRelays: any(named: 'targetRelays'),
          awaitRecipientOk: any(named: 'awaitRecipientOk'),
          onSelfWrapDue: any(named: 'onSelfWrapDue'),
          selfWrapOnSoftUnconfirmed: any(named: 'selfWrapOnSoftUnconfirmed'),
          recipientWrapBuildTimeout: any(named: 'recipientWrapBuildTimeout'),
          selfWrapBuildTimeout: any(named: 'selfWrapBuildTimeout'),
        ),
      ).thenAnswer(answer);
    }

    void stubConfirmed() => stubWire((invocation) async {
      final rumor = invocation.namedArguments[#rumorEvent] as Event;
      return NIP17SendResult.success(
        rumorEventId: rumor.id,
        messageEventId: 'wrap-${rumor.id}',
        recipientPubkey: invocation.namedArguments[#recipientPubkey] as String,
      );
    });

    void stubRejected() => stubWire(
      (_) async => const NIP17SendResult.failure('rejected by relay'),
    );

    void stubBlocked() =>
        stubWire((_) async => const NIP17SendResult.blocked('policy'));

    /// A delivered reaction the user then removed while the relay refused
    /// the kind-5: soft-deleted, `deletion_pending`, absent from the thread.
    Future<String> seedPendingRemoval() async {
      stubConfirmed();
      final result = await reactions.publish(
        conversationId: conversationId,
        targetMessageId: _targetMessageId,
        targetMessageAuthor: _peer,
        emoji: '🔥',
      );
      expect(result.success, isTrue);
      stubRejected();
      await reactions.removeOwn(
        rumorId: result.rumorId,
        targetMessageAuthor: _peer,
      );
      await pumpEventQueue();
      return result.rumorId;
    }

    Future<List<DmReaction>> thread() =>
        reactions.watchForConversation(conversationId).first;

    Future<String?> statusOf(String id) async => (await reactionsDao.getById(
      id: id,
      ownerPubkey: _owner,
    ))?.publishStatus;

    group('markDeletionUnconfirmed', () {
      test('puts the hidden removal back in the thread as a warning', () async {
        final id = await seedPendingRemoval();
        expect(await thread(), isEmpty);

        await reactions.markDeletionUnconfirmed(rumorId: id);

        final shown = await thread();
        expect(shown.map((reaction) => reaction.id), [id]);
        expect(
          shown.single.publishStatus,
          DmReactionPublishStatus.removalRefused,
        );
      });

      test("keeps the removal on the retry sweep's worklist", () async {
        final id = await seedPendingRemoval();

        await reactions.markDeletionUnconfirmed(rumorId: id);

        final targets = await reactions.retryableDeletions();
        expect(targets.map((target) => target.rumorId), [id]);
        expect(
          targets.single.publishStatus,
          DmReactionsDao.deletionUnconfirmed,
        );
      });
    });

    group('retryDeletion of an unconfirmed removal', () {
      Future<String> seedUnconfirmedRemoval() async {
        final id = await seedPendingRemoval();
        await reactions.markDeletionUnconfirmed(rumorId: id);
        expect((await thread()).map((reaction) => reaction.id), [id]);
        return id;
      }

      test('takes it out of the thread once a relay confirms it', () async {
        final id = await seedUnconfirmedRemoval();
        stubConfirmed();

        final outcome = await reactions.retryDeletion(
          rumorId: id,
          targetMessageAuthor: _peer,
        );

        expect(outcome, DmReactionDeletionOutcome.sent);
        expect(await statusOf(id), 'deletion_sent');
        expect(await thread(), isEmpty);
      });

      test(
        'leaves it in the thread and on the worklist while the relay still '
        'refuses it',
        () async {
          final id = await seedUnconfirmedRemoval();

          final outcome = await reactions.retryDeletion(
            rumorId: id,
            targetMessageAuthor: _peer,
          );

          expect(outcome, DmReactionDeletionOutcome.unconfirmed);
          expect(await statusOf(id), DmReactionsDao.deletionUnconfirmed);
          expect((await thread()).map((reaction) => reaction.id), [id]);
          final targets = await reactions.retryableDeletions();
          expect(targets.map((target) => target.rumorId), [id]);
        },
      );

      test(
        'becomes a refused removal, off the worklist, when send policy '
        'blocks it',
        () async {
          final id = await seedUnconfirmedRemoval();
          stubBlocked();

          final outcome = await reactions.retryDeletion(
            rumorId: id,
            targetMessageAuthor: _peer,
          );

          expect(outcome, DmReactionDeletionOutcome.refused);
          expect(await statusOf(id), DmReactionsDao.deletionRefused);
          expect(await reactions.retryableDeletions(), isEmpty);
          expect((await thread()).map((reaction) => reaction.id), [id]);
        },
      );
    });
  });
}
