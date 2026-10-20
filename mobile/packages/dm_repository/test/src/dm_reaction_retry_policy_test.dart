// ABOUTME: Regression coverage for the DM reaction retry policy (#8516):
// ABOUTME: what the retry sweep learns about each queued reaction and
// ABOUTME: removal, and what uses up one of their automatic retries.

import 'dart:async';

import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/event.dart';

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

  group('$DmReactionsRepository retry policy (#8516)', () {
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

    /// A send that waits on [send] instead of answering.
    void stubWaitingOn(Completer<NIP17SendResult> send) =>
        stubWire((_) => send.future);

    Future<DmReactionPublishResult> publish() => reactions.publish(
      conversationId: conversationId,
      targetMessageId: _targetMessageId,
      targetMessageAuthor: _peer,
      emoji: '🔥',
    );

    group('a send that reached no relay', () {
      const unreached = NIP17SendResult.failure(
        'Reaction not sent: no relay reached',
        reachedNoRelay: true,
      );

      test(
        'is reported by publish, which leaves the sweep un-nudged',
        () async {
          var nudges = 0;
          final subscription = reactions.retryableReactionWork.listen(
            (_) => nudges++,
          );
          addTearDown(subscription.cancel);
          stubWire((_) async => unreached);

          final result = await publish();
          await pumpEventQueue();

          expect(result.success, isFalse);
          expect(result.reachedNoRelay, isTrue);
          expect(nudges, 0);
          final row = await reactionsDao.getById(
            id: result.rumorId,
            ownerPubkey: _owner,
          );
          expect(row?.publishStatus, 'failed');
        },
      );

      test('is reported by retry, which leaves the sweep un-nudged', () async {
        stubWire((_) async => const NIP17SendResult.failure('rejected'));
        final id = (await publish()).rumorId;
        var nudges = 0;
        final subscription = reactions.retryableReactionWork.listen(
          (_) => nudges++,
        );
        addTearDown(subscription.cancel);
        stubWire((_) async => unreached);

        final result = await reactions.retry(
          rumorId: id,
          targetMessageAuthor: _peer,
        );
        await pumpEventQueue();

        expect(result.reachedNoRelay, isTrue);
        expect(nudges, 0);
      });

      test('is reported by retryDeletion as notSent, which leaves the sweep '
          'un-nudged', () async {
        stubConfirmed();
        final id = (await publish()).rumorId;
        stubWire((_) async => const NIP17SendResult.failure('rejected'));
        await reactions.removeOwn(rumorId: id, targetMessageAuthor: _peer);
        await pumpEventQueue();
        var nudges = 0;
        final subscription = reactions.retryableReactionWork.listen(
          (_) => nudges++,
        );
        addTearDown(subscription.cancel);
        stubWire((_) async => unreached);

        final outcome = await reactions.retryDeletion(
          rumorId: id,
          targetMessageAuthor: _peer,
        );
        await pumpEventQueue();

        expect(outcome, DmReactionDeletionOutcome.notSent);
        expect(nudges, 0);
        final row = await reactionsDao.getById(id: id, ownerPubkey: _owner);
        expect(row?.publishStatus, 'deletion_pending');
      });

      /// A group of the owner, [_peer] and a third member; returns its id.
      Future<String> seedGroup() async {
        const third =
            '3333333333333333333333333333333333333333333333333333333333333333';
        final groupId = DmRepository.computeConversationId([
          _owner,
          _peer,
          third,
        ]);
        await ConversationsDao(db).upsertConversation(
          id: groupId,
          participantPubkeys: '["$_owner","$_peer","$third"]',
          isGroup: true,
          createdAt: 1700000000,
          ownerPubkey: _owner,
        );
        return groupId;
      }

      Future<DmReactionPublishResult> publishIn(String groupId) =>
          reactions.publish(
            conversationId: groupId,
            targetMessageId: _targetMessageId,
            targetMessageAuthor: _peer,
            emoji: '🔥',
          );

      test('in a group is not reported when another recipient reached a '
          'relay', () async {
        final groupId = await seedGroup();
        stubWire(
          (invocation) async =>
              invocation.namedArguments[#recipientPubkey] == _peer
              ? unreached
              : const NIP17SendResult.failure('rejected by relay'),
        );

        final result = await publishIn(groupId);

        expect(result.success, isFalse);
        expect(result.reachedNoRelay, isFalse);
      });

      test('in a group is not reported when another recipient was '
          'delivered', () async {
        final groupId = await seedGroup();
        stubWire((invocation) async {
          final recipient =
              invocation.namedArguments[#recipientPubkey] as String;
          if (recipient == _peer) return unreached;
          final rumor = invocation.namedArguments[#rumorEvent] as Event;
          return NIP17SendResult.success(
            rumorEventId: rumor.id,
            messageEventId: 'wrap-${rumor.id}',
            recipientPubkey: recipient,
          );
        });

        final result = await publishIn(groupId);

        expect(result.success, isFalse);
        expect(result.reachedNoRelay, isFalse);
      });

      test('in a group is reported when no recipient reached a '
          'relay', () async {
        final groupId = await seedGroup();
        stubWire((_) async => unreached);

        final result = await publishIn(groupId);

        expect(result.reachedNoRelay, isTrue);
      });
    });

    group('markReactionUnconfirmed', () {
      Future<String> seedUnconfirmedAdd() async {
        stubWire(
          (_) async =>
              const NIP17SendResult.failure('no OK', retryablePending: true),
        );
        final id = (await publish()).rumorId;
        await reactions.markReactionUnconfirmed(rumorId: id);
        return id;
      }

      test('shows the reaction in the thread as unconfirmed', () async {
        final id = await seedUnconfirmedAdd();

        final shown = await reactions
            .watchForConversation(conversationId)
            .first;
        expect(shown.map((reaction) => reaction.id), [id]);
        expect(
          shown.single.publishStatus,
          DmReactionPublishStatus.unconfirmed,
        );
      });

      test("keeps it on the retry sweep's worklist", () async {
        final id = await seedUnconfirmedAdd();

        final targets = await reactions.retryableReactions();

        expect(targets.map((target) => target.rumorId), [id]);
        expect(targets.single.publishStatus, DmReactionsDao.unconfirmed);
      });

      test('a retry a relay confirms delivers it', () async {
        final id = await seedUnconfirmedAdd();
        stubConfirmed();

        final result = await reactions.retry(
          rumorId: id,
          targetMessageAuthor: _peer,
        );

        expect(result.success, isTrue);
        final row = await reactionsDao.getById(id: id, ownerPubkey: _owner);
        expect(row?.publishStatus, 'sent');
      });
    });

    group('a retry that reaches no relay leaves the status as it was', () {
      const unreached = NIP17SendResult.failure(
        'Reaction not sent: no relay reached',
        reachedNoRelay: true,
      );

      Future<String> seedWith(NIP17SendResult firstAnswer) async {
        stubWire((_) async => firstAnswer);
        return (await publish()).rumorId;
      }

      Future<String?> retryUnreached(String id) async {
        stubWire((_) async => unreached);
        await reactions.retry(rumorId: id, targetMessageAuthor: _peer);
        return (await reactionsDao.getById(
          id: id,
          ownerPubkey: _owner,
        ))?.publishStatus;
      }

      test(
        'for a reaction whose retries ran out, which keeps its mark',
        () async {
          final id = await seedWith(
            const NIP17SendResult.failure('no OK', retryablePending: true),
          );
          await reactions.markReactionUnconfirmed(rumorId: id);

          expect(await retryUnreached(id), DmReactionsDao.unconfirmed);
          expect(
            (await reactions.retryableReactions()).single.retriesRanOut,
            isTrue,
          );
        },
      );

      test('for a reaction whose OK was lost', () async {
        final id = await seedWith(
          const NIP17SendResult.failure('no OK', retryablePending: true),
        );

        expect(await retryUnreached(id), 'pending');
      });

      test('for a reaction a relay rejected', () async {
        final id = await seedWith(const NIP17SendResult.failure('rejected'));

        expect(await retryUnreached(id), 'failed');
      });
    });

    group('retriesRanOut', () {
      test(
        'marks a reaction whose retries ran out, and only that one',
        () async {
          stubWire(
            (_) async =>
                const NIP17SendResult.failure('no OK', retryablePending: true),
          );
          final id = (await publish()).rumorId;
          expect(
            (await reactions.retryableReactions()).single.retriesRanOut,
            isFalse,
          );

          await reactions.markReactionUnconfirmed(rumorId: id);

          expect(
            (await reactions.retryableReactions()).single.retriesRanOut,
            isTrue,
          );
        },
      );

      test(
        'marks a removal whose retries ran out, and only that one',
        () async {
          stubConfirmed();
          final id = (await publish()).rumorId;
          stubWire((_) async => const NIP17SendResult.failure('rejected'));
          await reactions.removeOwn(rumorId: id, targetMessageAuthor: _peer);
          await pumpEventQueue();
          expect(
            (await reactions.retryableDeletions()).single.retriesRanOut,
            isFalse,
          );

          await reactions.markDeletionUnconfirmed(rumorId: id);

          expect(
            (await reactions.retryableDeletions()).single.retriesRanOut,
            isTrue,
          );
        },
      );
    });

    group('isAttemptInFlight (#10044)', () {
      test('reports a removal whose own first attempt is still waiting for '
          'its OK, and not its reaction', () async {
        stubConfirmed();
        final id = (await publish()).rumorId;
        final send = Completer<NIP17SendResult>();
        stubWaitingOn(send);

        await reactions.removeOwn(rumorId: id, targetMessageAuthor: _peer);
        await pumpEventQueue();

        expect(reactions.isAttemptInFlight(id, removal: true), isTrue);
        expect(reactions.isAttemptInFlight(id, removal: false), isFalse);

        send.complete(
          const NIP17SendResult.failure('no OK', retryablePending: true),
        );
        await pumpEventQueue();

        expect(reactions.isAttemptInFlight(id, removal: true), isFalse);
      });

      test('reports a reaction whose publish is still waiting for its OK, '
          'and not a removal of it', () async {
        final send = Completer<NIP17SendResult>();
        stubWaitingOn(send);

        final publishing = publish();
        await pumpEventQueue();
        final id = (await reactions.retryableReactions()).single.rumorId;

        expect(reactions.isAttemptInFlight(id, removal: false), isTrue);
        expect(reactions.isAttemptInFlight(id, removal: true), isFalse);

        send.complete(
          const NIP17SendResult.failure('no OK', retryablePending: true),
        );
        await publishing;

        expect(reactions.isAttemptInFlight(id, removal: false), isFalse);
      });
    });
  });
}
