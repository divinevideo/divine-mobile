// ABOUTME: A group bubble that reached some members keeps saying it did not
// ABOUTME: reach everyone after Stop trying or a delete for everyone (#8180).

import 'dart:async';

import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/event_kind.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';
import 'package:openvine/blocs/dm/conversation/conversation_bloc.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockMessageService extends Mock implements NIP17MessageService {}

class _FakeEvent extends Fake implements Event {}

const _owner =
    'a4f5c1b2d3e4f5061728394a5b6c7d8e9f0a1b2c3d4e5f60718293a4b5c6d7e8';
const _memberA =
    'b1c2d3e4f5061728394a5b6c7d8e9f0a1b2c3d4e5f60718293a4b5c6d7e8f9a0';
const _memberB =
    'c2d3e4f5061728394a5b6c7d8e9f0a1b2c3d4e5f60718293a4b5c6d7e8f9a0b1';
const _privateKey =
    '5426e5b8b4b0e2a1f5e8d3c7a9b2f4e6d8c0a2b4f6e8d0c2a4b6f8e0d2c4a6b8';

const _wait = Duration(seconds: 5);

String _hex(int n) => n.toRadixString(16).padLeft(64, '0');

typedef _WrapOutcome = FutureOr<NIP17SendResult> Function(
  Event rumor,
  String recipient,
);

void main() {
  // The real bloc over the real repository and real DAOs. The label under
  // test is derived from which queue rows survive a cancel, so a mocked
  // repository would only replay whatever rows the test typed.
  group(ConversationBloc, () {
    late AppDatabase db;
    late DirectMessagesDao messagesDao;
    late OutgoingDmsDao outgoingDao;
    late _MockNostrClient nostrClient;
    late _MockMessageService messageService;
    late DmRepository repository;

    /// What the relay side answers for a message wrap and a deletion wrap.
    late _WrapOutcome messageWrap;
    late _WrapOutcome deletionWrap;
    var wrapCounter = 0;

    NIP17SendResult delivered(
      Event rumor,
      String recipient, {
      bool selfWrap = true,
    }) => NIP17SendResult.success(
      rumorEventId: rumor.id,
      messageEventId: _hex(++wrapCounter),
      recipientPubkey: recipient,
      selfWrapPublished: selfWrap,
    );

    NIP17SendResult refusedByPolicy(Event rumor, String recipient) =>
        const NIP17SendResult.blocked(
          'blocked: recipient not permitted by send policy',
        );

    NIP17SendResult unconfirmed(Event rumor, String recipient) =>
        const NIP17SendResult.failure('no relay confirmed the wrap');

    setUpAll(() {
      registerFallbackValue(_FakeEvent());
      // queryEventsDetailed takes a `Duration timeout`.
      registerFallbackValue(Duration.zero);
    });

    setUp(() {
      db = AppDatabase.test(NativeDatabase.memory());
      messagesDao = DirectMessagesDao(db);
      outgoingDao = db.outgoingDmsDao;
      nostrClient = _MockNostrClient();
      messageService = _MockMessageService();
      messageWrap = delivered;
      deletionWrap = delivered;

      // The relays answer and nobody advertises a kind 10050, so a wrap the
      // default pool confirms is scored delivered rather than held (#7317).
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
      when(() => messageService.canSendTo(any())).thenAnswer((_) async => true);
      // Mirrors NIP17MessageService.buildRumor and buildGroupRumor, which are
      // pure construction.
      when(
        () => messageService.buildRumor(
          recipientPubkey: any(named: 'recipientPubkey'),
          content: any(named: 'content'),
          eventKind: any(named: 'eventKind'),
          additionalTags: any(named: 'additionalTags'),
          createdAt: any(named: 'createdAt'),
        ),
      ).thenAnswer((invocation) {
        final named = invocation.namedArguments;
        return Event(
          _owner,
          (named[#eventKind] as int?) ?? EventKind.privateDirectMessage,
          [
            ['p', named[#recipientPubkey] as String],
            ...(named[#additionalTags] as List<List<String>>?) ?? const [],
          ],
          named[#content] as String,
          createdAt: named[#createdAt] as int?,
        );
      });
      when(
        () => messageService.buildGroupRumor(
          recipientPubkeys: any(named: 'recipientPubkeys'),
          content: any(named: 'content'),
          eventKind: any(named: 'eventKind'),
          additionalTags: any(named: 'additionalTags'),
          createdAt: any(named: 'createdAt'),
        ),
      ).thenAnswer((invocation) {
        final named = invocation.namedArguments;
        final ordered = [...named[#recipientPubkeys] as List<String>]..sort();
        return Event(
          _owner,
          (named[#eventKind] as int?) ?? EventKind.privateDirectMessage,
          [
            for (final pubkey in ordered) ['p', pubkey],
            ...(named[#additionalTags] as List<List<String>>?) ?? const [],
          ],
          named[#content] as String,
          createdAt: named[#createdAt] as int?,
        );
      });
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
        final rumor = invocation.namedArguments[#rumorEvent] as Event;
        final recipient = invocation.namedArguments[#recipientPubkey] as String;
        return rumor.kind == EventKind.eventDeletion
            ? deletionWrap(rumor, recipient)
            : messageWrap(rumor, recipient);
      });

      repository = DmRepository(
        nostrClient: nostrClient,
        messageService: messageService,
        directMessagesDao: messagesDao,
        conversationsDao: ConversationsDao(db),
        outgoingDmsDao: outgoingDao,
        userPubkey: _owner,
        signer: LocalNostrSigner(_privateKey),
        // Opening a thread marks it read, which schedules a relay publish.
        // Kept out of the test's lifetime; tearDown cancels it.
        readMarkerDebounceDelay: const Duration(hours: 1),
      );
    });

    tearDown(() async {
      await repository.stopListening();
      await db.close();
    });

    Future<ConversationBloc> openThread(String conversationId) async {
      final bloc = ConversationBloc(
        dmRepository: repository,
        conversationId: conversationId,
      );
      addTearDown(bloc.close);
      bloc.add(const ConversationStarted());
      await bloc.stream
          .firstWhere((s) => s.status == ConversationStatus.loaded)
          .timeout(_wait);
      return bloc;
    }

    Future<void> until(
      ConversationBloc bloc,
      bool Function(ConversationState) test, {
      required String what,
    }) async {
      if (test(bloc.state)) return;
      await bloc.stream
          .firstWhere(test)
          .timeout(
            _wait,
            onTimeout: () => fail('never reached: $what (${bloc.state})'),
          );
    }

    bool retractionIs(
      ConversationState state,
      String messageId,
      DmRetractionStatus status,
    ) => state.messages.any(
      (m) => m.id == messageId && m.retractionStatus == status,
    );

    /// A group message that reached A and that the relay refused for B, with
    /// its thread open and showing the failed bubble.
    Future<({ConversationBloc bloc, String messageId, String conversationId})>
    openGroupThatReachedOnlyA() async {
      messageWrap = (rumor, recipient) => recipient == _memberB
          ? const NIP17SendResult.failure('relay refused the wrap')
          : delivered(rumor, recipient);
      final results = await repository.sendGroupMessage(
        recipientPubkeys: [_memberA, _memberB],
        content: 'dinner at eight',
      );
      expect(results.map((r) => r.success), equals([true, false]));
      final messageId = results.first.rumorEventId!;
      final conversationId = DmRepository.computeConversationId([
        _owner,
        _memberA,
        _memberB,
      ]);
      final bloc = await openThread(conversationId);
      await until(
        bloc,
        (s) => s.messages.length == 1 && s.pendingOutgoing.length == 1,
        what: 'the group thread with its message and the failed sibling',
      );
      expect(
        bloc.state.statusFor(messageId),
        equals(DmDeliveryStatus.failed),
        reason: 'before the user acts the bubble says it failed for someone',
      );
      return (bloc: bloc, messageId: messageId, conversationId: conversationId);
    }

    group('a group bubble that reached one member and failed for another', () {
      test('still says it did not reach everyone after Stop trying', () async {
        final thread = await openGroupThatReachedOnlyA();
        final bloc = thread.bloc;

        // What the failed bubble's "Stop trying" action dispatches.
        for (final id in bloc.state.undeliveredSiblingRumorIdsFor(
          thread.messageId,
        )) {
          bloc.add(ConversationOutgoingSendCancelled(rumorId: id));
        }
        await until(
          bloc,
          (s) =>
              s.statusFor(thread.messageId) ==
              DmDeliveryStatus.notSentToEveryone,
          what: 'the bubble to settle on notSentToEveryone',
        );
        await pumpEventQueue();

        expect(
          bloc.state.statusFor(thread.messageId),
          equals(DmDeliveryStatus.notSentToEveryone),
          reason:
              'B never got the message; a bubble that looks delivered would '
              'tell the sender otherwise',
        );
        expect(
          bloc.state.failedSiblingRumorIdsFor(thread.messageId),
          isEmpty,
          reason: 'the sender stopped: nothing is left to resend',
        );
        expect(
          await outgoingDao.getRetryableForOwner(
            ownerPubkey: _owner,
            maxRetries: 5,
          ),
          isEmpty,
          reason: 'and the sweep must not pick the stopped delivery up again',
        );
      });

      test('still says so when a delete for everyone that is not confirmed '
          'follows Stop trying', () async {
        final thread = await openGroupThatReachedOnlyA();
        final bloc = thread.bloc;
        for (final id in bloc.state.undeliveredSiblingRumorIdsFor(
          thread.messageId,
        )) {
          bloc.add(ConversationOutgoingSendCancelled(rumorId: id));
        }
        await until(
          bloc,
          (s) =>
              s.statusFor(thread.messageId) ==
              DmDeliveryStatus.notSentToEveryone,
          what: 'the stop to show on the bubble',
        );
        deletionWrap = unconfirmed;

        bloc.add(ConversationMessageDeleted(rumorId: thread.messageId));
        await until(
          bloc,
          (s) => retractionIs(s, thread.messageId, DmRetractionStatus.pending),
          what: 'the pending retraction on the bubble',
        );
        await pumpEventQueue();

        expect(
          bloc.state.statusFor(thread.messageId),
          equals(DmDeliveryStatus.notSentToEveryone),
          reason: 'the delete must not take the record of the stop with it',
        );
      });

      test('still says so when a resend already on the wire is refused '
          'after Stop trying', () async {
        final thread = await openGroupThatReachedOnlyA();
        final bloc = thread.bloc;
        final failed = bloc.state.failedSiblingRumorIdsFor(thread.messageId);
        expect(failed, hasLength(1));
        // The resend stays on the wire until the test lets the relay answer.
        final onTheWire = Completer<void>();
        final relayAnswers = Completer<void>();
        messageWrap = (rumor, recipient) async {
          onTheWire.complete();
          await relayAnswers.future;
          return const NIP17SendResult.failure('relay refused the wrap');
        };
        bloc.add(ConversationFullSendRecoveryRequested(rumorIds: failed));
        await onTheWire.future.timeout(_wait);

        bloc.add(ConversationOutgoingSendCancelled(rumorId: failed.single));
        await until(
          bloc,
          (s) =>
              s.statusFor(thread.messageId) ==
              DmDeliveryStatus.notSentToEveryone,
          what: 'the stop to show while the resend is on the wire',
        );
        relayAnswers.complete();
        await until(
          bloc,
          (s) => s.sendStatus == SendStatus.resendFailed,
          what: 'the refused resend to be reported',
        );
        await pumpEventQueue();

        expect(
          bloc.state.statusFor(thread.messageId),
          equals(DmDeliveryStatus.notSentToEveryone),
          reason: 'the refusal answers an attempt the sender had stopped',
        );
        expect(
          await outgoingDao.getRetryableForOwner(
            ownerPubkey: _owner,
            maxRetries: 5,
          ),
          isEmpty,
          reason: 'and the sweep must not pick the member up again',
        );
      });

      for (final (name, outcome, retraction)
          in <(String, _WrapOutcome Function(), DmRetractionStatus)>[
            ('refused', () => refusedByPolicy, DmRetractionStatus.failed),
            ('not confirmed', () => unconfirmed, DmRetractionStatus.pending),
          ]) {
        test('still says it did not reach everyone while a delete for '
            'everyone is $name', () async {
          final thread = await openGroupThatReachedOnlyA();
          final bloc = thread.bloc;
          deletionWrap = outcome();

          bloc.add(ConversationMessageDeleted(rumorId: thread.messageId));
          await until(
            bloc,
            (s) => retractionIs(s, thread.messageId, retraction),
            what: 'the retraction to show as $name on the bubble',
          );
          await pumpEventQueue();

          expect(
            bloc.state.statusFor(thread.messageId),
            equals(DmDeliveryStatus.notSentToEveryone),
          );
          expect(
            bloc.state.displayedMessages.where((m) => m.id == thread.messageId),
            hasLength(1),
            reason: 'one bubble: the stopped row must not add a second',
          );
        });
      }

      test('leaves nothing behind once a delete for everyone is '
          'confirmed', () async {
        final thread = await openGroupThatReachedOnlyA();
        final bloc = thread.bloc;
        deletionWrap = delivered;

        bloc.add(ConversationMessageDeleted(rumorId: thread.messageId));
        await until(
          bloc,
          (s) => s.messages.isEmpty && s.pendingOutgoing.isEmpty,
          what: 'the bubble and its queue rows to leave the thread',
        );
        await pumpEventQueue();

        expect(bloc.state.displayedMessages, isEmpty);
        expect(
          await outgoingDao.getForConversation(
            conversationId: thread.conversationId,
            ownerPubkey: _owner,
          ),
          isEmpty,
        );
      });
    });

    group('a 1:1 bubble the recipient has', () {
      test('is unchanged by a refused delete for everyone', () async {
        // The recipient has the message and only the sender's own copy is
        // outstanding, so nobody is unreached and nothing is put on record.
        messageWrap = (rumor, recipient) =>
            delivered(rumor, recipient, selfWrap: false);
        final sent = await repository.sendMessage(
          recipientPubkey: _memberA,
          content: 'see you at eight',
        );
        final messageId = sent.rumorEventId!;
        final conversationId = DmRepository.computeConversationId([
          _owner,
          _memberA,
        ]);
        deletionWrap = refusedByPolicy;
        final bloc = await openThread(conversationId);
        await until(
          bloc,
          (s) => s.messages.length == 1 && s.pendingOutgoing.length == 1,
          what: 'the 1:1 thread with its message and self-copy row',
        );

        bloc.add(ConversationMessageDeleted(rumorId: messageId));
        await until(
          bloc,
          (s) => retractionIs(s, messageId, DmRetractionStatus.failed),
          what: 'the refused retraction on the bubble',
        );
        await pumpEventQueue();

        expect(
          bloc.state.statusFor(messageId),
          equals(DmDeliveryStatus.delivered),
        );
        expect(
          await outgoingDao.getForConversation(
            conversationId: conversationId,
            ownerPubkey: _owner,
          ),
          isEmpty,
        );
      });
    });
  });
}
