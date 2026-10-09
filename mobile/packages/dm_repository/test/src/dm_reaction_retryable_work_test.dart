// ABOUTME: Regression coverage for #7327 — every publish or removal that
// ABOUTME: leaves a row on the retry sweep's worklist must signal it through
// ABOUTME: `retryableReactionWork`, and terminal outcomes must stay silent.

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
const _orphanTarget =
    '5555555555555555555555555555555555555555555555555555555555555555';

void main() {
  setUpAll(() => registerFallbackValue(_FakeEvent()));

  group('retryableReactionWork (#7327)', () {
    late AppDatabase db;
    late DmReactionsDao reactionsDao;
    late ConversationsDao conversationsDao;
    late DirectMessagesDao messagesDao;
    late _MockNip17MessageService messageService;
    late DmReactionsRepository reactions;
    late StreamSubscription<void> nudgeSubscription;
    late String conversationId;
    var nudges = 0;

    setUp(() async {
      nudges = 0;
      db = AppDatabase.test(NativeDatabase.memory());
      reactionsDao = DmReactionsDao(db);
      conversationsDao = ConversationsDao(db);
      messagesDao = DirectMessagesDao(db);
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
            directMessagesDao: messagesDao,
          )..setCredentials(
            userPubkey: _owner,
            messageService: messageService,
          );
      nudgeSubscription = reactions.retryableReactionWork.listen((_) {
        nudges++;
      });

      conversationId = DmRepository.computeConversationId([_owner, _peer]);
      await conversationsDao.upsertConversation(
        id: conversationId,
        participantPubkeys: '["$_owner","$_peer"]',
        isGroup: false,
        createdAt: 1700000000,
        ownerPubkey: _owner,
      );
    });

    tearDown(() async {
      await nudgeSubscription.cancel();
      await db.close();
    });

    void stubWire(
      Future<NIP17SendResult> Function(Invocation invocation) answer,
    ) {
      when(
        () => messageService.sendRumor(
          rumorEvent: any(named: 'rumorEvent'),
          recipientPubkey: any(named: 'recipientPubkey'),
          targetRelays: any(named: 'targetRelays'),
          awaitRecipientOk: any(named: 'awaitRecipientOk'),
          selfWrapOnSoftUnconfirmed: any(named: 'selfWrapOnSoftUnconfirmed'),
          recipientWrapBuildTimeout: any(named: 'recipientWrapBuildTimeout'),
          selfWrapBuildTimeout: any(named: 'selfWrapBuildTimeout'),
        ),
      ).thenAnswer(answer);
    }

    void stubLanding() => stubWire((invocation) async {
      final rumor = invocation.namedArguments[#rumorEvent] as Event;
      return NIP17SendResult.success(
        rumorEventId: rumor.id,
        messageEventId: 'wrap-${rumor.id}',
        recipientPubkey: invocation.namedArguments[#recipientPubkey] as String,
      );
    });

    void stubSoftUnconfirmed() => stubWire(
      (_) async => const NIP17SendResult.failure(
        'no relay responded',
        retryablePending: true,
      ),
    );

    void stubHardFailure() =>
        stubWire((_) async => const NIP17SendResult.failure('offline'));

    void stubBlocked() =>
        stubWire((_) async => const NIP17SendResult.blocked('policy'));

    void stubThrowing() => stubWire(
      (_) => Future<NIP17SendResult>.error(StateError('socket')),
    );

    Future<DmReactionPublishResult> publish() => reactions.publish(
      conversationId: conversationId,
      targetMessageId: _targetMessageId,
      targetMessageAuthor: _peer,
      emoji: '🔥',
    );

    Future<int> settledNudges() async {
      await pumpEventQueue();
      return nudges;
    }

    group('publish', () {
      for (final succeeds in [false, true]) {
        test(
          'retry joins a publish that ${succeeds ? 'succeeds' : 'fails'}',
          () async {
            final started = Completer<String>();
            final wireResult = Completer<NIP17SendResult>();
            var sends = 0;
            stubWire((invocation) {
              sends++;
              started.complete(
                (invocation.namedArguments[#rumorEvent] as Event).id,
              );
              return wireResult.future;
            });
            final original = publish();
            final id = await started.future;
            final joined = reactions.retry(
              rumorId: id,
              targetMessageAuthor: _peer,
            );
            await pumpEventQueue();
            expect(sends, 1);

            wireResult.complete(
              succeeds
                  ? NIP17SendResult.success(
                      rumorEventId: id,
                      messageEventId: 'confirmed-wrap',
                      recipientPubkey: _peer,
                    )
                  : const NIP17SendResult.failure('relay rejected'),
            );
            expect((await original).success, succeeds);
            expect((await joined).success, succeeds);
            expect(sends, 1);
            final row = await reactionsDao.getById(id: id, ownerPubkey: _owner);
            expect(row?.publishStatus, succeeds ? 'sent' : 'failed');

            if (!succeeds) {
              stubLanding();
              expect(
                (await reactions.retry(
                  rumorId: id,
                  targetMessageAuthor: _peer,
                )).success,
                isTrue,
              );
            }
          },
        );
      }

      test(
        'nudges when the relay OK is lost and the row stays pending',
        () async {
          stubSoftUnconfirmed();

          final result = await publish();

          final row = await reactionsDao.getById(
            id: result.rumorId,
            ownerPubkey: _owner,
          );
          expect(row?.publishStatus, 'pending');
          expect(await settledNudges(), 1);
        },
      );

      test(
        'nudges on a confirmed rejection, which the sweep re-drives',
        () async {
          stubHardFailure();

          final result = await publish();

          final row = await reactionsDao.getById(
            id: result.rumorId,
            ownerPubkey: _owner,
          );
          expect(row?.publishStatus, 'failed');
          expect(await settledNudges(), 1);
        },
      );

      test(
        'nudges when the send throws and the row is marked failed',
        () async {
          stubThrowing();

          final result = await publish();

          final row = await reactionsDao.getById(
            id: result.rumorId,
            ownerPubkey: _owner,
          );
          expect(row?.publishStatus, 'failed');
          expect(await settledNudges(), 1);
        },
      );

      test('stays silent when the reaction is delivered', () async {
        stubLanding();

        final result = await publish();

        expect(result.success, isTrue);
        expect(await settledNudges(), 0);
      });

      test('stays silent when send policy refuses it for good', () async {
        stubBlocked();

        final result = await publish();

        final row = await reactionsDao.getById(
          id: result.rumorId,
          ownerPubkey: _owner,
        );
        expect(row?.publishStatus, 'blocked');
        expect(await settledNudges(), 0);
      });
    });

    group('retry', () {
      Future<String> seedFailedReaction() async {
        stubHardFailure();
        final result = await publish();
        await pumpEventQueue();
        nudges = 0;
        return result.rumorId;
      }

      test('nudges when the replay is still unconfirmed', () async {
        final id = await seedFailedReaction();
        stubSoftUnconfirmed();

        await reactions.retry(rumorId: id, targetMessageAuthor: _peer);

        final row = await reactionsDao.getById(id: id, ownerPubkey: _owner);
        expect(row?.publishStatus, 'pending');
        expect(await settledNudges(), 1);
      });

      test('nudges when the replay is rejected again', () async {
        final id = await seedFailedReaction();
        stubHardFailure();

        await reactions.retry(rumorId: id, targetMessageAuthor: _peer);

        expect(await settledNudges(), 1);
      });

      test('nudges when the replay throws', () async {
        final id = await seedFailedReaction();
        stubThrowing();

        await reactions.retry(rumorId: id, targetMessageAuthor: _peer);

        expect(await settledNudges(), 1);
      });

      test('stays silent when the replay is delivered', () async {
        final id = await seedFailedReaction();
        stubLanding();

        final result = await reactions.retry(
          rumorId: id,
          targetMessageAuthor: _peer,
        );

        expect(result.success, isTrue);
        expect(await settledNudges(), 0);
      });

      test('stays silent when send policy refuses the replay', () async {
        final id = await seedFailedReaction();
        stubBlocked();

        await reactions.retry(rumorId: id, targetMessageAuthor: _peer);

        expect(await settledNudges(), 0);
      });
    });

    group('removeOwn', () {
      Future<String> seedDeliveredReaction() async {
        stubLanding();
        final result = await publish();
        expect(result.success, isTrue);
        await pumpEventQueue();
        nudges = 0;
        return result.rumorId;
      }

      test(
        'nudges when the first kind-5 attempt does not confirm, and the row '
        'waits as deletion_pending',
        () async {
          final id = await seedDeliveredReaction();
          stubSoftUnconfirmed();

          await reactions.removeOwn(rumorId: id, targetMessageAuthor: _peer);

          expect(await settledNudges(), 1);
          final row = await reactionsDao.getById(id: id, ownerPubkey: _owner);
          expect(row?.publishStatus, 'deletion_pending');
          expect(row?.isDeleted, isTrue);
        },
      );

      test('nudges when the first kind-5 attempt throws', () async {
        final id = await seedDeliveredReaction();
        stubThrowing();

        await reactions.removeOwn(rumorId: id, targetMessageAuthor: _peer);

        expect(await settledNudges(), 1);
      });

      test('stays silent when the kind-5 is confirmed', () async {
        final id = await seedDeliveredReaction();
        stubLanding();

        await reactions.removeOwn(rumorId: id, targetMessageAuthor: _peer);

        expect(await settledNudges(), 0);
        final row = await reactionsDao.getById(id: id, ownerPubkey: _owner);
        expect(row?.publishStatus, 'deletion_sent');
      });

      test('stays silent when send policy refuses the kind-5', () async {
        final id = await seedDeliveredReaction();
        stubBlocked();

        await reactions.removeOwn(rumorId: id, targetMessageAuthor: _peer);

        expect(await settledNudges(), 0);
      });

      test(
        'nudges when the recipients are not known yet: the removal is '
        'recorded, no attempt is made, and nothing else would wake the sweep',
        () async {
          // No conversation row and no stored message for this reaction, so
          // its recipients cannot be proven and the removal is held.
          final rumor = Event(
            _owner,
            7,
            [
              ['e', _orphanTarget],
              ['p', _peer],
              ['k', '14'],
            ],
            '🔥',
            createdAt: 1700000100,
          );
          await reactionsDao.insertOwnReactionSuperseding(
            placeholderId: rumor.id,
            conversationId: 'conversation-that-was-removed',
            targetMessageId: _orphanTarget,
            targetMessageAuthor: _peer,
            reactorPubkey: _owner,
            emoji: '🔥',
            createdAt: 1700000100,
            ownerPubkey: _owner,
            rumorEventJson: rumor.toJson().toString(),
          );
          await reactionsDao.swapPlaceholderId(
            placeholderId: rumor.id,
            realRumorId: rumor.id,
            ownerPubkey: _owner,
          );
          stubLanding();

          await reactions.removeOwn(
            rumorId: rumor.id,
            targetMessageAuthor: _peer,
          );

          verifyNever(
            () => messageService.sendRumor(
              rumorEvent: any(named: 'rumorEvent'),
              recipientPubkey: any(named: 'recipientPubkey'),
              targetRelays: any(named: 'targetRelays'),
              awaitRecipientOk: any(named: 'awaitRecipientOk'),
              selfWrapOnSoftUnconfirmed: any(
                named: 'selfWrapOnSoftUnconfirmed',
              ),
              recipientWrapBuildTimeout: any(
                named: 'recipientWrapBuildTimeout',
              ),
              selfWrapBuildTimeout: any(named: 'selfWrapBuildTimeout'),
            ),
          );
          final row = await reactionsDao.getById(
            id: rumor.id,
            ownerPubkey: _owner,
          );
          expect(row?.publishStatus, 'deletion_pending');
          expect(await settledNudges(), 1);
        },
      );
    });

    group('retryDeletion', () {
      Future<String> seedPendingRemoval() async {
        stubLanding();
        final result = await publish();
        stubSoftUnconfirmed();
        await reactions.removeOwn(
          rumorId: result.rumorId,
          targetMessageAuthor: _peer,
        );
        await pumpEventQueue();
        nudges = 0;
        return result.rumorId;
      }

      test('nudges when the replayed kind-5 is still unconfirmed', () async {
        final id = await seedPendingRemoval();
        stubSoftUnconfirmed();

        final outcome = await reactions.retryDeletion(
          rumorId: id,
          targetMessageAuthor: _peer,
        );

        expect(outcome, DmReactionDeletionOutcome.unconfirmed);
        expect(await settledNudges(), 1);
      });

      test('nudges when the replayed kind-5 throws', () async {
        final id = await seedPendingRemoval();
        stubThrowing();

        final outcome = await reactions.retryDeletion(
          rumorId: id,
          targetMessageAuthor: _peer,
        );

        expect(outcome, DmReactionDeletionOutcome.unconfirmed);
        expect(await settledNudges(), 1);
      });

      test('stays silent when the replayed kind-5 is confirmed', () async {
        final id = await seedPendingRemoval();
        stubLanding();

        final outcome = await reactions.retryDeletion(
          rumorId: id,
          targetMessageAuthor: _peer,
        );

        expect(outcome, DmReactionDeletionOutcome.sent);
        expect(await settledNudges(), 0);
      });

      test('stays silent when send policy refuses the kind-5', () async {
        final id = await seedPendingRemoval();
        stubBlocked();

        final outcome = await reactions.retryDeletion(
          rumorId: id,
          targetMessageAuthor: _peer,
        );

        expect(outcome, DmReactionDeletionOutcome.refused);
        expect(await settledNudges(), 0);
      });
    });
  });
}
