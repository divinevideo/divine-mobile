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

    group('attemptInFlight (#10044)', () {
      test('marks a removal whose own first attempt is still waiting for '
          'its OK', () async {
        stubConfirmed();
        final id = (await publish()).rumorId;
        final send = Completer<NIP17SendResult>();
        stubWaitingOn(send);

        await reactions.removeOwn(rumorId: id, targetMessageAuthor: _peer);
        await pumpEventQueue();

        final waiting = await reactions.retryableDeletions();
        expect(waiting.map((target) => target.rumorId), [id]);
        expect(waiting.single.attemptInFlight, isTrue);

        send.complete(
          const NIP17SendResult.failure('no OK', retryablePending: true),
        );
        await pumpEventQueue();

        final settled = await reactions.retryableDeletions();
        expect(settled.map((target) => target.rumorId), [id]);
        expect(settled.single.attemptInFlight, isFalse);
      });

      test(
        'marks a reaction whose publish is still waiting for its OK',
        () async {
          final send = Completer<NIP17SendResult>();
          stubWaitingOn(send);

          final publishing = publish();
          await pumpEventQueue();

          final waiting = await reactions.retryableReactions();
          expect(waiting, hasLength(1));
          expect(waiting.single.attemptInFlight, isTrue);

          send.complete(
            const NIP17SendResult.failure('no OK', retryablePending: true),
          );
          final result = await publishing;

          final settled = await reactions.retryableReactions();
          expect(settled.map((target) => target.rumorId), [result.rumorId]);
          expect(settled.single.attemptInFlight, isFalse);
        },
      );
    });
  });
}
