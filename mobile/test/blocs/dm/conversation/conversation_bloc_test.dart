// ABOUTME: Tests for ConversationBloc - loading messages, sending 1:1 and
// ABOUTME: group messages, error handling, event transformer behavior,
// ABOUTME: and state/event equality.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/conversation/conversation_bloc.dart';
import 'package:openvine/observability/reportable_error.dart';

class _MockDmRepository extends Mock implements DmRepository {}

/// Builds an [OutgoingDm] queue row for tests that exercise the
/// [ConversationState.pendingOutgoing] projection slice. Defaults to a
/// `pending:pending` row freshly queued at epoch — caller overrides any
/// field that the specific test cares about.
OutgoingDm _outgoingDm({
  required String id,
  String content = 'test',
  int createdAtSec = 1700000000,
  DateTime? queuedAt,
  String ownerPubkey =
      '1111111111111111111111111111111111111111111111111111111111111111',
  String recipientPubkey =
      '2222222222222222222222222222222222222222222222222222222222222222',
  String conversationId =
      'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2',
  OutgoingWrapStatus recipientWrap = OutgoingWrapStatus.pending,
  OutgoingWrapStatus selfWrap = OutgoingWrapStatus.pending,
  int retryCount = 0,
  DateTime? lastAttemptAt,
}) {
  return OutgoingDm(
    id: id,
    conversationId: conversationId,
    recipientPubkey: recipientPubkey,
    content: content,
    createdAt: createdAtSec,
    rumorEventJson: '{}',
    recipientWrapStatus: recipientWrap,
    selfWrapStatus: selfWrap,
    queuedAt:
        queuedAt ?? DateTime.fromMillisecondsSinceEpoch(createdAtSec * 1000),
    ownerPubkey: ownerPubkey,
    retryCount: retryCount,
    lastAttemptAt: lastAttemptAt,
  );
}

Future<void> _waitForConversationState(
  ConversationBloc bloc,
  bool Function(ConversationState state) matches,
) async {
  if (matches(bloc.state)) return;
  // Bounded so a regression fails the test instead of hanging the suite.
  await bloc.stream.firstWhere(matches).timeout(const Duration(seconds: 10));
}

void main() {
  // Full 64-char hex IDs per project rules
  const conversationId =
      'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';
  const senderPubkey =
      '1111111111111111111111111111111111111111111111111111111111111111';
  const recipientPubkey =
      '2222222222222222222222222222222222222222222222222222222222222222';
  const recipientPubkey2 =
      '3333333333333333333333333333333333333333333333333333333333333333';
  const messageId =
      '4444444444444444444444444444444444444444444444444444444444444444';
  // A second, distinct rumor id — #7322's concurrent-delete regression.
  const otherMessageId =
      '7777777777777777777777777777777777777777777777777777777777777777';
  const giftWrapId =
      '5555555555555555555555555555555555555555555555555555555555555555';
  const sentEventId =
      '6666666666666666666666666666666666666666666666666666666666666666';

  const testMessage = DmMessage(
    id: messageId,
    conversationId: conversationId,
    senderPubkey: senderPubkey,
    content: 'Hello there',
    createdAt: 1700000000,
    giftWrapId: giftWrapId,
  );

  group(ConversationBloc, () {
    late _MockDmRepository mockDmRepository;

    setUp(() {
      mockDmRepository = _MockDmRepository();
      // Safe default for the post-send repaint re-read; failure tests that
      // care override it with the actual rows.
      when(
        () => mockDmRepository.getOutgoing(any()),
      ).thenAnswer((_) async => const <OutgoingDm>[]);
      // Delete now drops the bubble's whole durable batch before the kind-5
      // publish; default to "no rows existed" so persisted-delete tests keep
      // their original semantics.
      when(
        () => mockDmRepository.cancelOutgoingBatch(
          rumorId: any(named: 'rumorId'),
        ),
      ).thenAnswer((_) async => 0);
      // Opening a conversation arms the one-time history drain, same as the
      // inbox does.
      when(
        () => mockDmRepository.backfillHistoryIfNeeded(),
      ).thenAnswer((_) async {});
      // A credentialed repository is the ordinary fixture; the owner-unknown
      // window has its own group below.
      when(() => mockDmRepository.userPubkey).thenReturn(senderPubkey);
    });

    ConversationBloc buildBloc() => ConversationBloc(
      dmRepository: mockDmRepository,
      conversationId: conversationId,
    );

    test('initial state is correct', () {
      when(
        () => mockDmRepository.markConversationAsRead(any()),
      ).thenAnswer((_) async {});
      when(
        () => mockDmRepository.watchMessages(any()),
      ).thenAnswer((_) => const Stream.empty());

      final bloc = buildBloc();

      expect(bloc.state, equals(const ConversationState()));
      expect(bloc.state.status, equals(ConversationStatus.initial));
      expect(bloc.state.messages, isEmpty);
      expect(bloc.state.sendStatus, equals(SendStatus.idle));
    });

    group('ConversationStarted', () {
      blocTest<ConversationBloc, ConversationState>(
        'stays loading while the repository owner is unknown, rather than '
        'reporting the thread as empty',
        setUp: () {
          // #8187: signed-out and teardown repositories have no storage owner,
          // so owner-scoped reads return nothing. Emitting `loaded` there would
          // render the "new conversation" card over a thread that has history.
          when(() => mockDmRepository.userPubkey).thenReturn('');
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const ConversationStarted()),
        expect: () => [
          const ConversationState(status: ConversationStatus.loading),
        ],
        verify: (_) {
          verifyNever(() => mockDmRepository.watchMessages(any()));
          verifyNever(() => mockDmRepository.markConversationAsRead(any()));
        },
      );

      blocTest<ConversationBloc, ConversationState>(
        'emits [loading, loaded] when messages stream emits successfully',
        setUp: () {
          when(
            () => mockDmRepository.markConversationAsRead(conversationId),
          ).thenAnswer((_) async {});
          when(
            () => mockDmRepository.watchMessages(conversationId),
          ).thenAnswer((_) => Stream.value([testMessage]));
          when(
            () => mockDmRepository.watchOutgoing(any()),
          ).thenAnswer((_) => Stream.value(const <OutgoingDm>[]));
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const ConversationStarted()),
        expect: () => [
          const ConversationState(status: ConversationStatus.loading),
          const ConversationState(
            status: ConversationStatus.loaded,
            messages: [testMessage],
          ),
        ],
        verify: (_) {
          // Called once on initial open + once per stream emission
          verify(
            () => mockDmRepository.markConversationAsRead(conversationId),
          ).called(2);
          verify(
            () => mockDmRepository.watchMessages(conversationId),
          ).called(1);
        },
      );

      blocTest<ConversationBloc, ConversationState>(
        'arms the one-time history drain, so profile -> Message on a '
        'reinstall does not report an empty thread as complete',
        setUp: () {
          when(
            () => mockDmRepository.markConversationAsRead(conversationId),
          ).thenAnswer((_) async {});
          when(
            () => mockDmRepository.watchMessages(conversationId),
          ).thenAnswer((_) => const Stream.empty());
          when(
            () => mockDmRepository.watchOutgoing(any()),
          ).thenAnswer((_) => Stream.value(const <OutgoingDm>[]));
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const ConversationStarted()),
        verify: (_) {
          // Reaching a thread without passing through Messages must still
          // stamp hasAttemptedHistoryRecovery, or an empty conversation
          // claims completeness while history is still on the relay (#4953).
          verify(() => mockDmRepository.backfillHistoryIfNeeded()).called(1);
        },
      );

      blocTest<ConversationBloc, ConversationState>(
        'calls markConversationAsRead with the correct conversation ID',
        setUp: () {
          when(
            () => mockDmRepository.markConversationAsRead(conversationId),
          ).thenAnswer((_) async {});
          when(
            () => mockDmRepository.watchMessages(conversationId),
          ).thenAnswer((_) => const Stream.empty());
          when(
            () => mockDmRepository.watchOutgoing(any()),
          ).thenAnswer((_) => Stream.value(const <OutgoingDm>[]));
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const ConversationStarted()),
        verify: (_) {
          verify(
            () => mockDmRepository.markConversationAsRead(conversationId),
          ).called(1);
        },
      );

      blocTest<ConversationBloc, ConversationState>(
        'emits [loading, error] when messages stream errors',
        setUp: () {
          when(
            () => mockDmRepository.markConversationAsRead(conversationId),
          ).thenAnswer((_) async {});
          when(
            () => mockDmRepository.watchMessages(conversationId),
          ).thenAnswer((_) => Stream.error(Exception('stream failed')));
          when(
            () => mockDmRepository.watchOutgoing(any()),
          ).thenAnswer((_) => Stream.value(const <OutgoingDm>[]));
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const ConversationStarted()),
        expect: () => [
          const ConversationState(status: ConversationStatus.loading),
          const ConversationState(status: ConversationStatus.error),
        ],
        errors: () => [isA<Exception>()],
      );

      // #8201. The bubble remains visible throughout the attempt, changing
      // from ordinary to pending to failed.
      group('refused retraction', () {
        late StreamController<List<DmMessage>> thread;

        setUp(() {
          thread = StreamController<List<DmMessage>>();
          addTearDown(() async {
            if (!thread.isClosed) await thread.close();
          });
          when(
            () => mockDmRepository.markConversationAsRead(conversationId),
          ).thenAnswer((_) async {});
          when(
            () => mockDmRepository.watchMessages(conversationId),
          ).thenAnswer((_) => thread.stream);
          when(
            () => mockDmRepository.watchOutgoing(any()),
          ).thenAnswer((_) => Stream.value(const <OutgoingDm>[]));
          when(
            () => mockDmRepository.deleteMessageForEveryone(messageId),
          ).thenAnswer((_) async {});
          when(
            () => mockDmRepository.retryMessageDeletion(rumorId: messageId),
          ).thenAnswer((_) async => DmMessageDeletionOutcome.blocked);
        });

        Future<void> tick(List<DmMessage> next) async {
          thread.add(next);
          await Future<void>.delayed(Duration.zero);
        }

        Future<void> tapDelete(ConversationBloc bloc) async {
          bloc.add(const ConversationMessageDeleted(rumorId: messageId));
          await untilCalled(
            () => mockDmRepository.deleteMessageForEveryone(messageId),
          );
          await Future<void>.delayed(Duration.zero);
        }

        blocTest<ConversationBloc, ConversationState>(
          'reports a refusal when a pending bubble becomes failed',
          build: buildBloc,
          act: (bloc) async {
            bloc.add(const ConversationStarted());
            await Future<void>.delayed(Duration.zero);
            await tick([testMessage]);
            await tapDelete(bloc);
            await tick([_pending(testMessage)]);
            await tick([_blocked(testMessage)]);
          },
          verify: (bloc) {
            expect(bloc.state.awaitingRetraction, isEmpty);
          },
        );

        blocTest<ConversationBloc, ConversationState>(
          'releases a retraction after the confirmed bubble leaves the thread',
          build: buildBloc,
          act: (bloc) async {
            bloc.add(const ConversationStarted());
            await Future<void>.delayed(Duration.zero);
            await tick([testMessage]);
            await tapDelete(bloc);
            await tick([_pending(testMessage)]);
            await tick(const []);
          },
          verify: (bloc) {
            expect(bloc.state.awaitingRetraction, isEmpty);
          },
        );

        // Retrying a refused delete: the bubble is ALREADY on screen carrying
        // failed retraction state from the previous attempt, and arming happens at
        // tap time, before the repository hides anything. Matching presence
        // alone would fire the toast for an attempt that has not been made
        // and consume the id — so the real outcome then passes in silence.
        blocTest<ConversationBloc, ConversationState>(
          'stays quiet until a retried refusal actually comes back',
          build: buildBloc,
          act: (bloc) async {
            bloc.add(const ConversationStarted());
            await Future<void>.delayed(Duration.zero);
            // Opening on an already-refused bubble, as after a first refusal.
            await tick([_blocked(testMessage)]);
            bloc.add(
              const ConversationMessageDeletionRetryRequested(
                rumorId: messageId,
              ),
            );
            await untilCalled(
              () => mockDmRepository.retryMessageDeletion(
                rumorId: messageId,
              ),
            );
            // A tick arrives while the row is still visible and still stale-
            // blocked — this is the window the bug fired in.
            await tick([_blocked(testMessage)]);
          },
          verify: (bloc) {
            expect(bloc.state.awaitingRetraction, contains(messageId));
          },
        );

        // ...and once the retry genuinely resolves, the toast still fires.
        blocTest<ConversationBloc, ConversationState>(
          'reports the retried refusal once the row has actually cycled',
          build: buildBloc,
          act: (bloc) async {
            bloc.add(const ConversationStarted());
            await Future<void>.delayed(Duration.zero);
            await tick([_blocked(testMessage)]);
            bloc.add(
              const ConversationMessageDeletionRetryRequested(
                rumorId: messageId,
              ),
            );
            await untilCalled(
              () => mockDmRepository.retryMessageDeletion(
                rumorId: messageId,
              ),
            );
            await tick([_pending(testMessage)]);
            await tick([_blocked(testMessage)]);
          },
          verify: (bloc) {
            expect(bloc.state.awaitingRetraction, isEmpty);
          },
        );

        // `unavailable` moves no row, so no bubble transition follows and the
        // tick-driven release never runs. Leaving the id armed makes the tap
        // silent AND permanent: releasing it here is the shrink the view
        // listens for to toast.
        blocTest<ConversationBloc, ConversationState>(
          'releases the armed id when the retry could not be driven at all',
          build: () {
            when(
              () => mockDmRepository.retryMessageDeletion(rumorId: messageId),
            ).thenAnswer((_) async => DmMessageDeletionOutcome.unavailable);
            return buildBloc();
          },
          act: (bloc) async {
            bloc.add(const ConversationStarted());
            await Future<void>.delayed(Duration.zero);
            await tick([_blocked(testMessage)]);
            bloc.add(
              const ConversationMessageDeletionRetryRequested(
                rumorId: messageId,
              ),
            );
            await untilCalled(
              () => mockDmRepository.retryMessageDeletion(
                rumorId: messageId,
              ),
            );
            // Deliberately NO further tick: the point is that nothing else
            // arrives to clear it.
            await Future<void>.delayed(Duration.zero);
          },
          verify: (bloc) {
            expect(bloc.state.awaitingRetraction, isEmpty);
          },
        );

        blocTest<ConversationBloc, ConversationState>(
          'releases the armed id and reports when the retry throws',
          build: () {
            when(
              () => mockDmRepository.retryMessageDeletion(rumorId: messageId),
            ).thenThrow(StateError('signer unavailable'));
            return buildBloc();
          },
          act: (bloc) async {
            bloc.add(const ConversationStarted());
            await Future<void>.delayed(Duration.zero);
            await tick([_blocked(testMessage)]);
            bloc.add(
              const ConversationMessageDeletionRetryRequested(
                rumorId: messageId,
              ),
            );
            await Future<void>.delayed(Duration.zero);
          },
          errors: () => [isA<StateError>()],
          verify: (bloc) {
            expect(bloc.state.awaitingRetraction, isEmpty);
          },
        );

        // The flag is the gate: a row that returns to the thread without it
        // was not refused, whatever un-hid it. The disappearance still
        // completes this screen's tracking, so the id does not leak.
        blocTest<ConversationBloc, ConversationState>(
          'ignores a message that comes back without the refusal flag',
          build: buildBloc,
          act: (bloc) async {
            bloc.add(const ConversationStarted());
            await Future<void>.delayed(Duration.zero);
            await tick([testMessage]);
            await tapDelete(bloc);
            await tick(const []);
            await tick([testMessage]);
          },
          verify: (bloc) {
            expect(bloc.state.awaitingRetraction, isEmpty);
          },
        );

        // A refusal from an earlier session is already on the row when the
        // thread opens. Nothing was asked for on this open, so nothing may be
        // armed by it — announcing it would toast on every cold open of any
        // thread that ever had one.
        blocTest<ConversationBloc, ConversationState>(
          'stays quiet about a refusal that predates the thread opening',
          build: buildBloc,
          act: (bloc) async {
            bloc.add(const ConversationStarted());
            await Future<void>.delayed(Duration.zero);
            await tick([_blocked(testMessage)]);
          },
          verify: (bloc) {
            expect(bloc.state.messages, [_blocked(testMessage)]);
            expect(bloc.state.awaitingRetraction, isEmpty);
          },
        );
      });

      blocTest<ConversationBloc, ConversationState>(
        'emits updated messages when stream emits multiple times',
        setUp: () {
          final controller = StreamController<List<DmMessage>>();
          when(
            () => mockDmRepository.markConversationAsRead(conversationId),
          ).thenAnswer((_) async {});
          when(
            () => mockDmRepository.watchMessages(conversationId),
          ).thenAnswer((_) => controller.stream);
          when(
            () => mockDmRepository.watchOutgoing(any()),
          ).thenAnswer((_) => Stream.value(const <OutgoingDm>[]));

          // Schedule emissions after bloc subscribes
          Future<void>.delayed(Duration.zero).then((_) {
            controller.add([testMessage]);
            const secondMessage = DmMessage(
              id: '7777777777777777777777777777777777777777777777777777777777777777',
              conversationId: conversationId,
              senderPubkey: recipientPubkey,
              content: 'Reply message',
              createdAt: 1700000100,
              giftWrapId: '8888888888888888888888888888888888888888888888888888888888888888',
            );
            controller.add([testMessage, secondMessage]);
            controller.close();
          });
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const ConversationStarted()),
        expect: () => [
          const ConversationState(status: ConversationStatus.loading),
          const ConversationState(
            status: ConversationStatus.loaded,
            messages: [testMessage],
          ),
          isA<ConversationState>()
              .having(
                (s) => s.status,
                'status',
                equals(ConversationStatus.loaded),
              )
              .having((s) => s.messages.length, 'messages.length', equals(2)),
        ],
      );

      late StreamController<List<DmMessage>> messagesController;
      late StreamController<List<OutgoingDm>> outgoingController;

      blocTest<ConversationBloc, ConversationState>(
        'does not re-mark read on an outgoing-queue-only tick, but does on a '
        'genuinely new message',
        setUp: () {
          messagesController = StreamController<List<DmMessage>>();
          outgoingController = StreamController<List<OutgoingDm>>();
          when(
            () => mockDmRepository.markConversationAsRead(conversationId),
          ).thenAnswer((_) async {});
          when(
            () => mockDmRepository.watchMessages(conversationId),
          ).thenAnswer((_) => messagesController.stream);
          when(
            () => mockDmRepository.watchOutgoing(any()),
          ).thenAnswer((_) => outgoingController.stream);

          addTearDown(() async {
            if (!messagesController.isClosed) {
              await messagesController.close();
            }
            if (!outgoingController.isClosed) {
              await outgoingController.close();
            }
          });
        },
        build: buildBloc,
        act: (bloc) async {
          bloc.add(const ConversationStarted());
          await untilCalled(
            () => mockDmRepository.watchMessages(conversationId),
          );

          // First message arrives: messages change -> marks read.
          messagesController.add([testMessage]);
          outgoingController.add(const <OutgoingDm>[]);
          await _waitForConversationState(
            bloc,
            (state) =>
                state.status == ConversationStatus.loaded &&
                state.messages.length == 1 &&
                state.pendingOutgoing.isEmpty,
          );

          // Outgoing-queue status change only (e.g. pending -> delivered):
          // combineLatest2 re-emits the SAME messages instance, so this tick
          // must NOT re-mark the conversation read.
          outgoingController.add([_outgoingDm(id: 'pending-rumor')]);
          await _waitForConversationState(
            bloc,
            (state) =>
                state.messages.length == 1 && state.pendingOutgoing.length == 1,
          );

          // A genuinely new incoming message: marks read again.
          const secondMessage = DmMessage(
            id: '7777777777777777777777777777777777777777777777777777777777777777',
            conversationId: conversationId,
            senderPubkey: recipientPubkey,
            content: 'Reply message',
            createdAt: 1700000100,
            giftWrapId: '8888888888888888888888888888888888888888888888888888888888888888',
          );
          messagesController.add([testMessage, secondMessage]);
          await _waitForConversationState(
            bloc,
            (state) =>
                state.messages.length == 2 && state.pendingOutgoing.length == 1,
          );

          await messagesController.close();
          await outgoingController.close();
        },
        verify: (bloc) {
          // The outgoing-only tick was processed (its row reached state)...
          expect(bloc.state.pendingOutgoing, hasLength(1));
          // ...but mark-read fired only on open + the two message-list changes,
          // NOT on the outgoing-only tick in between.
          verify(
            () => mockDmRepository.markConversationAsRead(conversationId),
          ).called(3);
        },
      );
    });

    group('ConversationMessageSent', () {
      group('1:1 message', () {
        blocTest<ConversationBloc, ConversationState>(
          'emits [sending with optimistic message, sent] '
          'on successful sendMessage',
          setUp: () {
            when(
              () => mockDmRepository.sendMessage(
                recipientPubkey: recipientPubkey,
                content: 'Hello',
              ),
            ).thenAnswer(
              (_) async => NIP17SendResult.success(
                rumorEventId: sentEventId,
                messageEventId: sentEventId,
                recipientPubkey: recipientPubkey,
              ),
            );
          },
          build: buildBloc,
          act: (bloc) => bloc.add(
            const ConversationMessageSent(
              recipientPubkeys: [recipientPubkey],
              content: 'Hello',
            ),
          ),
          expect: () => [
            isA<ConversationState>().having(
              (s) => s.sendStatus,
              'sendStatus',
              SendStatus.sending,
            ),
            isA<ConversationState>().having(
              (s) => s.sendStatus,
              'sendStatus',
              SendStatus.sent,
            ),
          ],
        );

        blocTest<ConversationBloc, ConversationState>(
          'emits [sending, tooLong] on an oversized rumor, never failed (#7331)',
          setUp: () {
            when(
              () => mockDmRepository.sendMessage(
                recipientPubkey: recipientPubkey,
                content: 'Hello',
              ),
            ).thenAnswer(
              (_) async => const NIP17SendResult.tooLong(
                'message is too large to send',
              ),
            );
          },
          build: buildBloc,
          act: (bloc) => bloc.add(
            const ConversationMessageSent(
              recipientPubkeys: [recipientPubkey],
              content: 'Hello',
            ),
          ),
          expect: () => [
            isA<ConversationState>().having(
              (s) => s.sendStatus,
              'sendStatus',
              SendStatus.sending,
            ),
            // Must NOT be `failed`: that status relies on the queue row's red
            // "Not delivered" bubble as its only visual affordance, and an
            // oversized send is refused before the enqueue so no row exists.
            isA<ConversationState>().having(
              (s) => s.sendStatus,
              'sendStatus',
              SendStatus.tooLong,
            ),
          ],
        );

        blocTest<ConversationBloc, ConversationState>(
          'emits [sending, blocked] with no retry payload on a policy-blocked send (#176)',
          setUp: () {
            when(
              () => mockDmRepository.sendMessage(
                recipientPubkey: recipientPubkey,
                content: 'Hello',
              ),
            ).thenAnswer(
              (_) async =>
                  const NIP17SendResult.blocked('blocked: not permitted'),
            );
          },
          build: buildBloc,
          act: (bloc) => bloc.add(
            const ConversationMessageSent(
              recipientPubkeys: [recipientPubkey],
              content: 'Hello',
            ),
          ),
          expect: () => [
            isA<ConversationState>().having(
              (s) => s.sendStatus,
              'sendStatus',
              SendStatus.sending,
            ),
            // Blocked, not failed: no toast retry — the send was refused.
            isA<ConversationState>().having(
              (s) => s.sendStatus,
              'sendStatus',
              SendStatus.blocked,
            ),
          ],
        );

        // #7335. An empty recipient list failed the single-recipient test and
        // took the group branch, where `sendGroupMessage` throws ArgumentError
        // before enqueuing anything. The generic catch emitted `failed`, whose
        // only affordance is the red "Not delivered" bubble — and with no
        // queue row, `statusFor` short-circuits to `delivered` and no bubble
        // exists. The composer had already cleared the text field, so the send
        // was silent in every channel a sighted user has.
        blocTest<ConversationBloc, ConversationState>(
          'emits [sending, noRecipient] and touches no repository send path '
          'when the recipient list is empty',
          build: buildBloc,
          act: (bloc) => bloc.add(
            const ConversationMessageSent(
              recipientPubkeys: [],
              content: 'Hello',
            ),
          ),
          expect: () => [
            isA<ConversationState>().having(
              (s) => s.sendStatus,
              'sendStatus',
              SendStatus.sending,
            ),
            isA<ConversationState>().having(
              (s) => s.sendStatus,
              'sendStatus',
              SendStatus.noRecipient,
            ),
          ],
          verify: (_) {
            verifyNever(
              () => mockDmRepository.sendMessage(
                recipientPubkey: any(named: 'recipientPubkey'),
                content: any(named: 'content'),
              ),
            );
            verifyNever(
              () => mockDmRepository.sendGroupMessage(
                recipientPubkeys: any(named: 'recipientPubkeys'),
                content: any(named: 'content'),
              ),
            );
          },
        );

        blocTest<ConversationBloc, ConversationState>(
          'emits [sending, sent] on a soft-unconfirmed send '
          '(retryablePending) — surfaced as sent, no red failure',
          setUp: () {
            when(
              () => mockDmRepository.sendMessage(
                recipientPubkey: recipientPubkey,
                content: 'Hello',
              ),
            ).thenAnswer(
              (_) async => const NIP17SendResult.failure(
                'Message recipient OK unconfirmed',
                retryablePending: true,
              ),
            );
          },
          build: buildBloc,
          act: (bloc) => bloc.add(
            const ConversationMessageSent(
              recipientPubkeys: [recipientPubkey],
              content: 'Hello',
            ),
          ),
          expect: () => [
            isA<ConversationState>().having(
              (s) => s.sendStatus,
              'sendStatus',
              SendStatus.sending,
            ),
            // Soft-unconfirmed: the durable queue keeps the pending bubble and
            // the retry sweep re-drives it, so surface no failure — treated as
            // optimistically sent with no retry payload.
            isA<ConversationState>().having(
              (s) => s.sendStatus,
              'sendStatus',
              SendStatus.sent,
            ),
          ],
        );

        blocTest<ConversationBloc, ConversationState>(
          'emits [sending, failed] on a hard-failed sendMessage — the failure '
          'is surfaced on the bubble (statusFor), not a toast',
          setUp: () {
            when(
              () => mockDmRepository.sendMessage(
                recipientPubkey: recipientPubkey,
                content: 'Hello',
              ),
            ).thenAnswer(
              (_) async =>
                  const NIP17SendResult.failure('Failed to publish message'),
            );
          },
          build: buildBloc,
          act: (bloc) => bloc.add(
            const ConversationMessageSent(
              recipientPubkeys: [recipientPubkey],
              content: 'Hello',
            ),
          ),
          expect: () => [
            isA<ConversationState>().having(
              (s) => s.sendStatus,
              'sendStatus',
              SendStatus.sending,
            ),
            // The durable queue row (pendingOutgoing) carries the failed
            // bubble; there is no toast state to populate.
            isA<ConversationState>()
                .having((s) => s.sendStatus, 'sendStatus', SendStatus.failed)
                .having((s) => s.messages, 'messages untouched', isEmpty),
          ],
          errors: () => [isA<Exception>()],
        );

        blocTest<ConversationBloc, ConversationState>(
          'emits [sending, tooLong] when every group recipient refuses the '
          'oversized rumor (#7331)',
          setUp: () {
            when(
              () => mockDmRepository.sendGroupMessage(
                recipientPubkeys: [recipientPubkey, recipientPubkey2],
                content: 'Group hello',
              ),
            ).thenAnswer(
              (_) async => const [
                NIP17SendResult.tooLong('message is too large to send'),
                NIP17SendResult.tooLong('message is too large to send'),
              ],
            );
          },
          build: buildBloc,
          act: (bloc) => bloc.add(
            const ConversationMessageSent(
              recipientPubkeys: [recipientPubkey, recipientPubkey2],
              content: 'Group hello',
            ),
          ),
          expect: () => [
            isA<ConversationState>().having(
              (s) => s.sendStatus,
              'sendStatus',
              SendStatus.sending,
            ),
            isA<ConversationState>().having(
              (s) => s.sendStatus,
              'sendStatus',
              SendStatus.tooLong,
            ),
          ],
        );

        late StreamController<List<DmMessage>> failMsgCtrl;
        late StreamController<List<OutgoingDm>> failOutCtrl;
        blocTest<ConversationBloc, ConversationState>(
          'reactively surfaces the failed bubble (statusFor) when '
          'watchOutgoing emits the failed row after a hard-failed send',
          setUp: () {
            failMsgCtrl = StreamController<List<DmMessage>>();
            failOutCtrl = StreamController<List<OutgoingDm>>();
            when(
              () => mockDmRepository.markConversationAsRead(any()),
            ).thenAnswer((_) async {});
            when(
              () => mockDmRepository.watchMessages(conversationId),
            ).thenAnswer((_) => failMsgCtrl.stream);
            when(
              () => mockDmRepository.watchOutgoing(any()),
            ).thenAnswer((_) => failOutCtrl.stream);
            when(
              () => mockDmRepository.sendMessage(
                recipientPubkey: recipientPubkey,
                content: 'Hello',
              ),
            ).thenAnswer((_) async {
              // Mirror the real repository: enqueue (pending) then, on a hard
              // failure (e.g. offline), mark the row failed — both surface via
              // watchOutgoing while _onMessageSent is in flight.
              failOutCtrl.add([_outgoingDm(id: messageId)]);
              await Future<void>.delayed(Duration.zero);
              failOutCtrl.add([
                _outgoingDm(
                  id: messageId,
                  recipientWrap: OutgoingWrapStatus.failed,
                  selfWrap: OutgoingWrapStatus.failed,
                ),
              ]);
              return const NIP17SendResult.failure(
                'Message not sent: device offline',
              );
            });
            // The repository has marked the row failed by the time the bloc
            // re-reads (the one-shot read the bloc uses to repaint immediately
            // instead of waiting on a watchOutgoing tick that can be dropped
            // mid-handler).
            when(() => mockDmRepository.getOutgoing(any())).thenAnswer(
              (_) async => [
                _outgoingDm(
                  id: messageId,
                  recipientWrap: OutgoingWrapStatus.failed,
                  selfWrap: OutgoingWrapStatus.failed,
                ),
              ],
            );
            addTearDown(() async {
              if (!failMsgCtrl.isClosed) await failMsgCtrl.close();
              if (!failOutCtrl.isClosed) await failOutCtrl.close();
            });
          },
          build: buildBloc,
          act: (bloc) async {
            bloc.add(const ConversationStarted());
            await untilCalled(() => mockDmRepository.watchOutgoing(any()));
            failMsgCtrl.add(const <DmMessage>[]);
            bloc.add(
              const ConversationMessageSent(
                recipientPubkeys: [recipientPubkey],
                content: 'Hello',
              ),
            );
            await _waitForConversationState(
              bloc,
              (s) => s.statusFor(messageId) == DmDeliveryStatus.failed,
            );
          },
          verify: (bloc) {
            expect(
              bloc.state.statusFor(messageId),
              DmDeliveryStatus.failed,
            );
          },
          errors: () => [isA<Exception>()],
        );

        // Regression for #4193 — sent DM does not appear until app restart.
        //
        // Pre-fix the optimistic lived in `state.messages`, which the
        // `_onStarted.emit.forEach.onData` callback replaced wholesale on
        // every watchMessages tick. For a freshly-searched conversation
        // the watch's first tick is `[]`, so the optimistic was wiped the
        // moment the watch subscription took effect — exactly when the
        // user looks at the conversation right after tapping send.
        //
        // The bug-scoped patch (#4234) split the optimistic into a
        // separate in-memory `pendingOptimistic` slice. The principled
        // architecture this file pins now is dual-stream: the durable
        // `outgoing_dms` queue row IS the optimistic. `sendMessage`
        // enqueues it before any signer round-trip, and
        // `DmRepository.watchOutgoing` projects it into
        // `state.pendingOutgoing`. The watch-messages path is unchanged;
        // a `[]` tick on that stream cannot wipe the bubble because the
        // bubble lives in the parallel `pendingOutgoing` slice now.
        //
        // Stated as a state-shape pin (the bloc-level flow is implicitly
        // covered by the sendMessage tests in this group that all stub
        // both streams): when messages-stream emits empty AND
        // pendingOutgoing carries a queue row, displayedMessages MUST
        // carry the bubble. Pre-#4193 this invariant did not hold.
        test(
          'displayedMessages survives an empty watchMessages tick while '
          'pendingOutgoing carries a queue row (regression for #4193)',
          () {
            final pendingRow = _outgoingDm(
              id: sentEventId,
              content: 'Hello',
            );
            // Composite: loaded + sending + empty persisted + queue row.
            final state = ConversationState(
              status: ConversationStatus.loaded,
              sendStatus: SendStatus.sending,
              pendingOutgoing: [pendingRow],
            );
            expect(state.messages, isEmpty);
            expect(state.displayedMessages, hasLength(1));
            expect(state.displayedMessages.first.content, equals('Hello'));
            expect(state.statusFor(sentEventId), DmDeliveryStatus.pending);
          },
        );

        blocTest<ConversationBloc, ConversationState>(
          'a fresh send from a previously-failed conversation transitions '
          'through [sending, sent]',
          seed: () => const ConversationState(sendStatus: SendStatus.failed),
          setUp: () {
            when(
              () => mockDmRepository.sendMessage(
                recipientPubkey: recipientPubkey,
                content: 'Hello',
              ),
            ).thenAnswer(
              (_) async => NIP17SendResult.success(
                rumorEventId: sentEventId,
                messageEventId: sentEventId,
                recipientPubkey: recipientPubkey,
              ),
            );
          },
          build: buildBloc,
          act: (bloc) => bloc.add(
            const ConversationMessageSent(
              recipientPubkeys: [recipientPubkey],
              content: 'Hello',
            ),
          ),
          expect: () => [
            isA<ConversationState>().having(
              (s) => s.sendStatus,
              'sendStatus',
              SendStatus.sending,
            ),
            isA<ConversationState>().having(
              (s) => s.sendStatus,
              'sendStatus',
              SendStatus.sent,
            ),
          ],
        );

        blocTest<ConversationBloc, ConversationState>(
          'emits [sending with optimistic, sentPartial with lastPartialSend] '
          'when sendMessage succeeds but the self-wrap was not published',
          setUp: () {
            when(
              () => mockDmRepository.sendMessage(
                recipientPubkey: recipientPubkey,
                content: 'Hello',
              ),
            ).thenAnswer(
              (_) async => NIP17SendResult.success(
                rumorEventId: sentEventId,
                messageEventId: sentEventId,
                recipientPubkey: recipientPubkey,
                selfWrapPublished: false,
              ),
            );
          },
          build: buildBloc,
          act: (bloc) => bloc.add(
            const ConversationMessageSent(
              recipientPubkeys: [recipientPubkey],
              content: 'Hello',
            ),
          ),
          // Partial-delivery: the recipient got the message and the local
          // DB persist already happened inside DmRepository.sendMessage.
          // The pendingOptimistic entry is stripped on sentPartial (same
          // as sent) — the watch tick brings the persisted row, so the
          // user-visible bubble is sourced from `messages`, not from the
          // pending. lastPartialSend records the rumor id whose self-wrap
          // failed, so the SnackBar's Retry can recover via the
          // self-wrap-only path without redelivering to the recipient
          // (#4102).
          expect: () => [
            isA<ConversationState>().having(
              (s) => s.sendStatus,
              'sendStatus',
              SendStatus.sending,
            ),
            isA<ConversationState>()
                .having(
                  (s) => s.sendStatus,
                  'sendStatus',
                  SendStatus.sentPartial,
                )
                .having(
                  (s) => s.lastPartialSend,
                  'lastPartialSend',
                  equals(const PartialSend(rumorIds: [sentEventId])),
                ),
          ],
        );
      });

      group('group message', () {
        blocTest<ConversationBloc, ConversationState>(
          'emits [sending with optimistic message, sent] '
          'when at least one sendGroupMessage succeeds',
          setUp: () {
            when(
              () => mockDmRepository.sendGroupMessage(
                recipientPubkeys: [recipientPubkey, recipientPubkey2],
                content: 'Group hello',
              ),
            ).thenAnswer(
              (_) async => [
                NIP17SendResult.success(
                  rumorEventId: sentEventId,
                  messageEventId: sentEventId,
                  recipientPubkey: recipientPubkey,
                ),
                const NIP17SendResult.failure('Failed for second recipient'),
              ],
            );
          },
          build: buildBloc,
          act: (bloc) => bloc.add(
            const ConversationMessageSent(
              recipientPubkeys: [recipientPubkey, recipientPubkey2],
              content: 'Group hello',
            ),
          ),
          expect: () => [
            isA<ConversationState>().having(
              (s) => s.sendStatus,
              'sendStatus',
              SendStatus.sending,
            ),
            isA<ConversationState>().having(
              (s) => s.sendStatus,
              'sendStatus',
              SendStatus.sent,
            ),
          ],
        );

        blocTest<ConversationBloc, ConversationState>(
          'emits [sending with optimistic message, failed without '
          'failed] when all recipients of a group send fail',
          setUp: () {
            when(
              () => mockDmRepository.sendGroupMessage(
                recipientPubkeys: [recipientPubkey, recipientPubkey2],
                content: 'Group hello',
              ),
            ).thenAnswer(
              (_) async => [
                const NIP17SendResult.failure('Relay timeout'),
                const NIP17SendResult.failure('Connection refused'),
              ],
            );
          },
          build: buildBloc,
          act: (bloc) => bloc.add(
            const ConversationMessageSent(
              recipientPubkeys: [recipientPubkey, recipientPubkey2],
              content: 'Group hello',
            ),
          ),
          expect: () => [
            isA<ConversationState>().having(
              (s) => s.sendStatus,
              'sendStatus',
              SendStatus.sending,
            ),
            isA<ConversationState>()
                .having((s) => s.sendStatus, 'sendStatus', SendStatus.failed)
                .having((s) => s.messages, 'messages untouched', isEmpty),
          ],
          errors: () => [isA<Exception>()],
        );

        blocTest<ConversationBloc, ConversationState>(
          'emits [sending, sentPartial with the partial queue handle] '
          'when one per-recipient sendGroupMessage has self-wrap unpublished',
          setUp: () {
            // Both recipients share one wire rumor, but partial self-wrap
            // recovery must retain the affected recipient's queue handle.
            const sharedRumorId =
                '7777777777777777777777777777777777777777777777777777777777777777';
            const partialQueueId = '$sharedRumorId:$recipientPubkey2';
            when(
              () => mockDmRepository.sendGroupMessage(
                recipientPubkeys: [recipientPubkey, recipientPubkey2],
                content: 'Group hello',
              ),
            ).thenAnswer(
              (_) async => [
                NIP17SendResult.success(
                  rumorEventId: sharedRumorId,
                  messageEventId: 'wrap-1',
                  recipientPubkey: recipientPubkey,
                ),
                NIP17SendResult.success(
                  rumorEventId: sharedRumorId,
                  messageEventId: 'wrap-2',
                  recipientPubkey: recipientPubkey2,
                  selfWrapPublished: false,
                  queuedRumorId: partialQueueId,
                ),
              ],
            );
          },
          build: buildBloc,
          act: (bloc) => bloc.add(
            const ConversationMessageSent(
              recipientPubkeys: [recipientPubkey, recipientPubkey2],
              content: 'Group hello',
            ),
          ),
          expect: () => [
            isA<ConversationState>().having(
              (s) => s.sendStatus,
              'sendStatus',
              SendStatus.sending,
            ),
            isA<ConversationState>()
                .having(
                  (s) => s.sendStatus,
                  'sendStatus',
                  SendStatus.sentPartial,
                )
                .having(
                  (s) => s.lastPartialSend,
                  'lastPartialSend',
                  equals(
                    const PartialSend(
                      rumorIds: [
                        '7777777777777777777777777777777777777777777777777777777777777777:$recipientPubkey2',
                      ],
                    ),
                  ),
                ),
          ],
        );

        blocTest<ConversationBloc, ConversationState>(
          'emits [sending, sent] when every group recipient is '
          'soft-unconfirmed (retryablePending) with no hard failure — the '
          'durable queue re-drives each pending row, no red SnackBar',
          setUp: () {
            when(
              () => mockDmRepository.sendGroupMessage(
                recipientPubkeys: [recipientPubkey, recipientPubkey2],
                content: 'Group hello',
              ),
            ).thenAnswer(
              (_) async => [
                const NIP17SendResult.failure(
                  'Message recipient OK unconfirmed',
                  retryablePending: true,
                ),
                const NIP17SendResult.failure(
                  'Message recipient OK unconfirmed',
                  retryablePending: true,
                ),
              ],
            );
          },
          build: buildBloc,
          act: (bloc) => bloc.add(
            const ConversationMessageSent(
              recipientPubkeys: [recipientPubkey, recipientPubkey2],
              content: 'Group hello',
            ),
          ),
          expect: () => [
            isA<ConversationState>().having(
              (s) => s.sendStatus,
              'sendStatus',
              SendStatus.sending,
            ),
            isA<ConversationState>().having(
              (s) => s.sendStatus,
              'sendStatus',
              SendStatus.sent,
            ),
          ],
        );
      });

      group('overlapping partial sends', () {
        const firstRumorId =
            '7777777777777777777777777777777777777777777777777777777777777777';
        const secondRumorId =
            '8888888888888888888888888888888888888888888888888888888888888888';
        late Completer<NIP17SendResult> slowFirstPartial;

        blocTest<ConversationBloc, ConversationState>(
          'two concurrent sends that both end sentPartial accumulate their '
          'rumor ids — the second partial must not orphan the first',
          setUp: () {
            slowFirstPartial = Completer<NIP17SendResult>();
            when(
              () => mockDmRepository.sendMessage(
                recipientPubkey: recipientPubkey,
                content: 'First partial',
              ),
            ).thenAnswer((_) => slowFirstPartial.future);
            when(
              () => mockDmRepository.sendMessage(
                recipientPubkey: recipientPubkey,
                content: 'Second partial',
              ),
            ).thenAnswer(
              (_) async => NIP17SendResult.success(
                rumorEventId: secondRumorId,
                messageEventId: secondRumorId,
                recipientPubkey: recipientPubkey,
                selfWrapPublished: false,
              ),
            );
          },
          build: buildBloc,
          act: (bloc) async {
            bloc.add(
              const ConversationMessageSent(
                recipientPubkeys: [recipientPubkey],
                content: 'First partial',
              ),
            );
            await Future<void>.delayed(Duration.zero);
            bloc.add(
              const ConversationMessageSent(
                recipientPubkeys: [recipientPubkey],
                content: 'Second partial',
              ),
            );
            await Future<void>.delayed(Duration.zero);
            // The slower FIRST send resolves partial after the second one
            // already emitted its sentPartial.
            slowFirstPartial.complete(
              NIP17SendResult.success(
                rumorEventId: firstRumorId,
                messageEventId: firstRumorId,
                recipientPubkey: recipientPubkey,
                selfWrapPublished: false,
              ),
            );
          },
          expect: () => [
            // The second send's `sending` emit is state-identical and
            // therefore suppressed by Equatable.
            isA<ConversationState>().having(
              (s) => s.sendStatus,
              'sendStatus',
              SendStatus.sending,
            ),
            isA<ConversationState>().having(
              (s) => s.lastPartialSend?.rumorIds,
              'lastPartialSend',
              equals([secondRumorId]),
            ),
            // The union: a plain overwrite here silently dropped the
            // second send's self-wrap recovery set (or vice versa).
            isA<ConversationState>().having(
              (s) => s.lastPartialSend?.rumorIds,
              'lastPartialSend',
              unorderedEquals([firstRumorId, secondRumorId]),
            ),
          ],
        );
      });

      group('exception handling', () {
        blocTest<ConversationBloc, ConversationState>(
          'strips optimistic and marks failed '
          'when sendMessage throws an exception',
          setUp: () {
            when(
              () => mockDmRepository.sendMessage(
                recipientPubkey: recipientPubkey,
                content: 'Hello',
              ),
            ).thenThrow(Exception('Network error'));
          },
          build: buildBloc,
          act: (bloc) => bloc.add(
            const ConversationMessageSent(
              recipientPubkeys: [recipientPubkey],
              content: 'Hello',
            ),
          ),
          expect: () => [
            isA<ConversationState>().having(
              (s) => s.sendStatus,
              'sendStatus',
              SendStatus.sending,
            ),
            isA<ConversationState>()
                .having((s) => s.sendStatus, 'sendStatus', SendStatus.failed)
                .having((s) => s.messages, 'messages untouched', isEmpty),
          ],
          errors: () => [isA<Exception>()],
        );

        blocTest<ConversationBloc, ConversationState>(
          'strips optimistic and marks failed '
          'when sendGroupMessage throws an exception',
          setUp: () {
            when(
              () => mockDmRepository.sendGroupMessage(
                recipientPubkeys: [recipientPubkey, recipientPubkey2],
                content: 'Group hello',
              ),
            ).thenThrow(Exception('Network error'));
          },
          build: buildBloc,
          act: (bloc) => bloc.add(
            const ConversationMessageSent(
              recipientPubkeys: [recipientPubkey, recipientPubkey2],
              content: 'Group hello',
            ),
          ),
          expect: () => [
            isA<ConversationState>().having(
              (s) => s.sendStatus,
              'sendStatus',
              SendStatus.sending,
            ),
            isA<ConversationState>()
                .having((s) => s.sendStatus, 'sendStatus', SendStatus.failed)
                .having((s) => s.messages, 'messages untouched', isEmpty),
          ],
          errors: () => [isA<Exception>()],
        );

        blocTest<ConversationBloc, ConversationState>(
          'strips only the optimistic for the failed attempt — '
          'preserves persisted messages already in state',
          seed: () => const ConversationState(
            status: ConversationStatus.loaded,
            messages: [testMessage],
          ),
          setUp: () {
            when(
              () => mockDmRepository.sendMessage(
                recipientPubkey: recipientPubkey,
                content: 'Hello',
              ),
            ).thenThrow(Exception('Network error'));
          },
          build: buildBloc,
          act: (bloc) => bloc.add(
            const ConversationMessageSent(
              recipientPubkeys: [recipientPubkey],
              content: 'Hello',
            ),
          ),
          expect: () => [
            // Sending: optimistic on top of the seeded persisted message.
            isA<ConversationState>()
                .having((s) => s.sendStatus, 'sendStatus', SendStatus.sending)
                .having(
                  (s) => s.messages,
                  'messages slice untouched (still just the seeded row)',
                  equals(const [testMessage]),
                ),
            isA<ConversationState>()
                .having((s) => s.sendStatus, 'sendStatus', SendStatus.failed)
                .having(
                  (s) => s.messages,
                  'messages preserves existing testMessage',
                  equals(const [testMessage]),
                ),
          ],
          errors: () => [isA<Exception>()],
        );
      });
    });

    group('event transformers', () {
      group('concurrent() on $ConversationMessageSent', () {
        late Completer<NIP17SendResult> slowFirstSend;

        blocTest<ConversationBloc, ConversationState>(
          'a slow first send does not block the second — the second send '
          'dispatches and completes while the first is still in flight',
          setUp: () {
            // First send parks on a completer that is only released after
            // the second send has already finished. Under the previous
            // sequential() transformer the second sendMessage call could not
            // even START until the first completed — so `called(2)` before
            // the release, and a `sent` emission driven by the second send,
            // both pin the concurrent behavior.
            slowFirstSend = Completer<NIP17SendResult>();
            var callCount = 0;
            when(
              () => mockDmRepository.sendMessage(
                recipientPubkey: recipientPubkey,
                content: any(named: 'content'),
              ),
            ).thenAnswer((_) {
              callCount++;
              if (callCount == 1) return slowFirstSend.future;
              return Future.value(
                NIP17SendResult.success(
                  rumorEventId: sentEventId,
                  messageEventId: sentEventId,
                  recipientPubkey: recipientPubkey,
                ),
              );
            });
          },
          build: buildBloc,
          act: (bloc) async {
            bloc.add(
              const ConversationMessageSent(
                recipientPubkeys: [recipientPubkey],
                content: 'First message',
              ),
            );
            await Future<void>.delayed(Duration.zero);
            bloc.add(
              const ConversationMessageSent(
                recipientPubkeys: [recipientPubkey],
                content: 'Second message',
              ),
            );
            // Both sends must be in flight BEFORE the first completes.
            await Future<void>.delayed(const Duration(milliseconds: 20));
            verify(
              () => mockDmRepository.sendMessage(
                recipientPubkey: recipientPubkey,
                content: any(named: 'content'),
              ),
            ).called(2);
            slowFirstSend.complete(
              NIP17SendResult.success(
                rumorEventId: sentEventId,
                messageEventId: sentEventId,
                recipientPubkey: recipientPubkey,
              ),
            );
          },
          wait: const Duration(milliseconds: 100),
          expect: () => [
            // First send starts; the second's identical `sending` emit is
            // suppressed by state equality.
            isA<ConversationState>().having(
              (s) => s.sendStatus,
              'sendStatus',
              SendStatus.sending,
            ),
            // The SECOND send completes while the first is still parked —
            // this emission proves the second never waited.
            isA<ConversationState>().having(
              (s) => s.sendStatus,
              'sendStatus',
              SendStatus.sent,
            ),
          ],
        );

        blocTest<ConversationBloc, ConversationState>(
          'does not drop the second event when first is still processing',
          setUp: () {
            final completer1 = Completer<NIP17SendResult>();
            final completer2 = Completer<NIP17SendResult>();
            var callCount = 0;
            when(
              () => mockDmRepository.sendMessage(
                recipientPubkey: recipientPubkey,
                content: any(named: 'content'),
              ),
            ).thenAnswer((_) {
              callCount++;
              if (callCount == 1) return completer1.future;
              return completer2.future;
            });

            // Complete both after a short delay; with concurrent() both
            // handlers are already in flight when the first resolves.
            Future<void>.delayed(const Duration(milliseconds: 30)).then((_) {
              completer1.complete(
                NIP17SendResult.success(
                  rumorEventId: sentEventId,
                  messageEventId: sentEventId,
                  recipientPubkey: recipientPubkey,
                ),
              );
            });
            Future<void>.delayed(const Duration(milliseconds: 60)).then((_) {
              completer2.complete(
                NIP17SendResult.success(
                  rumorEventId: sentEventId,
                  messageEventId: sentEventId,
                  recipientPubkey: recipientPubkey,
                ),
              );
            });
          },
          build: buildBloc,
          act: (bloc) {
            bloc
              ..add(
                const ConversationMessageSent(
                  recipientPubkeys: [recipientPubkey],
                  content: 'First',
                ),
              )
              ..add(
                const ConversationMessageSent(
                  recipientPubkeys: [recipientPubkey],
                  content: 'Second',
                ),
              );
          },
          wait: const Duration(milliseconds: 150),
          expect: () => [
            // Both handlers start together; the second's identical `sending`
            // emit is suppressed by state equality, as is the second `sent`.
            // The two repository calls verified below prove the second event
            // was processed, not dropped.
            isA<ConversationState>().having(
              (s) => s.sendStatus,
              'sendStatus',
              SendStatus.sending,
            ),
            isA<ConversationState>().having(
              (s) => s.sendStatus,
              'sendStatus',
              SendStatus.sent,
            ),
          ],
          verify: (_) {
            verify(
              () => mockDmRepository.sendMessage(
                recipientPubkey: recipientPubkey,
                content: any(named: 'content'),
              ),
            ).called(2);
          },
        );
      });

      group('restartable() on $ConversationStarted', () {
        blocTest<ConversationBloc, ConversationState>(
          'cancels the previous subscription and starts a new one '
          'when $ConversationStarted is re-added',
          setUp: () {
            final controller1 = StreamController<List<DmMessage>>();
            final controller2 = StreamController<List<DmMessage>>();
            var watchCallCount = 0;

            when(
              () => mockDmRepository.markConversationAsRead(conversationId),
            ).thenAnswer((_) async {});

            when(
              () => mockDmRepository.watchMessages(conversationId),
            ).thenAnswer((_) {
              watchCallCount++;
              if (watchCallCount == 1) return controller1.stream;
              return controller2.stream;
            });

            when(
              () => mockDmRepository.watchOutgoing(any()),
            ).thenAnswer((_) => Stream.value(const <OutgoingDm>[]));

            // Emit on first stream, then trigger re-add, then emit on second
            // stream. The first stream's later emission should be ignored
            // because restartable() cancels it.
            Future<void>.delayed(const Duration(milliseconds: 10)).then((_) {
              controller1.add([testMessage]);
            });
            Future<void>.delayed(const Duration(milliseconds: 60)).then((_) {
              // This emission on the old stream should be ignored
              controller1.add([
                testMessage,
                const DmMessage(
                  id: '9999999999999999999999999999999999999999999999999999999999999999',
                  conversationId: conversationId,
                  senderPubkey: senderPubkey,
                  content: 'Should be ignored',
                  createdAt: 1700000200,
                  giftWrapId: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
                ),
              ]);
              controller1.close();
            });
            Future<void>.delayed(const Duration(milliseconds: 70)).then((_) {
              controller2.add([
                const DmMessage(
                  id: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
                  conversationId: conversationId,
                  senderPubkey: recipientPubkey,
                  content: 'New subscription message',
                  createdAt: 1700000300,
                  giftWrapId: 'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
                ),
              ]);
              controller2.close();
            });
          },
          build: buildBloc,
          act: (bloc) async {
            bloc.add(const ConversationStarted());
            // Wait for first stream to emit, then re-add
            await Future<void>.delayed(const Duration(milliseconds: 30));
            bloc.add(const ConversationStarted());
          },
          wait: const Duration(milliseconds: 200),
          expect: () => [
            // First subscription starts
            const ConversationState(status: ConversationStatus.loading),
            // First stream emits messages
            const ConversationState(
              status: ConversationStatus.loaded,
              messages: [testMessage],
            ),
            // Second ConversationStarted restarts: emits loading.
            // copyWith preserves messages from previous state.
            const ConversationState(
              status: ConversationStatus.loading,
              messages: [testMessage],
            ),
            // Second stream emits its message (first stream's late emit
            // is ignored because restartable() cancelled it)
            isA<ConversationState>()
                .having(
                  (s) => s.status,
                  'status',
                  equals(ConversationStatus.loaded),
                )
                .having((s) => s.messages.length, 'messages.length', equals(1))
                .having(
                  (s) => s.messages.first.content,
                  'messages.first.content',
                  equals('New subscription message'),
                ),
          ],
          verify: (_) {
            verify(
              () => mockDmRepository.watchMessages(conversationId),
            ).called(2);
            // Called once per ConversationStarted (×2) + once per onData
            // emission (×2: one from controller1 before restart, one from
            // controller2 after restart) = 4 total.
            verify(
              () => mockDmRepository.markConversationAsRead(conversationId),
            ).called(4);
          },
        );
      });
    });

    group(ConversationSelfWrapRecoveryRequested, () {
      // The principled recovery path for #4102: tapping Retry on a
      // sentPartial SnackBar must republish only the missing self-wrap
      // — never the recipient wrap, which would double-deliver.
      const rumorId1 =
          '7777777777777777777777777777777777777777777777777777777777777777';
      const rumorId2 =
          '8888888888888888888888888888888888888888888888888888888888888888';

      blocTest<ConversationBloc, ConversationState>(
        'emits [sending, sent] and clears lastPartialSend when every '
        'recoverSelfWrap returns success',
        setUp: () {
          when(
            () => mockDmRepository.recoverSelfWrap(
              rumorId: any(named: 'rumorId'),
            ),
          ).thenAnswer(
            (inv) async => NIP17SendResult.success(
              rumorEventId: inv.namedArguments[#rumorId] as String,
              messageEventId: inv.namedArguments[#rumorId] as String,
              recipientPubkey: senderPubkey,
            ),
          );
        },
        seed: () => const ConversationState(
          status: ConversationStatus.loaded,
          sendStatus: SendStatus.sentPartial,
          lastPartialSend: PartialSend(rumorIds: [rumorId1, rumorId2]),
        ),
        build: buildBloc,
        act: (bloc) => bloc.add(
          const ConversationSelfWrapRecoveryRequested(
            rumorIds: [rumorId1, rumorId2],
          ),
        ),
        expect: () => [
          isA<ConversationState>().having(
            (s) => s.sendStatus,
            'sendStatus',
            SendStatus.sending,
          ),
          isA<ConversationState>()
              .having((s) => s.sendStatus, 'sendStatus', SendStatus.sent)
              .having(
                (s) => s.lastPartialSend,
                'lastPartialSend cleared on full recovery',
                isNull,
              ),
        ],
        verify: (_) {
          // Every rumor in the event payload was passed to
          // recoverSelfWrap (with no recipient publish in sight).
          verify(
            () => mockDmRepository.recoverSelfWrap(rumorId: rumorId1),
          ).called(1);
          verify(
            () => mockDmRepository.recoverSelfWrap(rumorId: rumorId2),
          ).called(1);
          // Pin the no-duplicate-recipient-publish contract from #4102.
          verifyNever(
            () => mockDmRepository.sendMessage(
              recipientPubkey: any(named: 'recipientPubkey'),
              content: any(named: 'content'),
            ),
          );
          verifyNever(
            () => mockDmRepository.sendGroupMessage(
              recipientPubkeys: any(named: 'recipientPubkeys'),
              content: any(named: 'content'),
            ),
          );
        },
      );

      blocTest<ConversationBloc, ConversationState>(
        'reduces lastPartialSend.rumorIds to the still-failing rumors '
        'when one of two recoveries fails',
        setUp: () {
          when(
            () => mockDmRepository.recoverSelfWrap(rumorId: rumorId1),
          ).thenAnswer(
            (_) async => NIP17SendResult.success(
              rumorEventId: rumorId1,
              messageEventId: rumorId1,
              recipientPubkey: senderPubkey,
            ),
          );
          when(
            () => mockDmRepository.recoverSelfWrap(rumorId: rumorId2),
          ).thenAnswer(
            (_) async => const NIP17SendResult.failure('relay timeout'),
          );
        },
        seed: () => const ConversationState(
          status: ConversationStatus.loaded,
          sendStatus: SendStatus.sentPartial,
          lastPartialSend: PartialSend(rumorIds: [rumorId1, rumorId2]),
        ),
        build: buildBloc,
        act: (bloc) => bloc.add(
          const ConversationSelfWrapRecoveryRequested(
            rumorIds: [rumorId1, rumorId2],
          ),
        ),
        expect: () => [
          isA<ConversationState>().having(
            (s) => s.sendStatus,
            'sendStatus',
            SendStatus.sending,
          ),
          isA<ConversationState>()
              .having(
                (s) => s.sendStatus,
                'sendStatus',
                SendStatus.sentPartial,
              )
              .having(
                (s) => s.lastPartialSend,
                'lastPartialSend reduced to still-failing ids only',
                equals(const PartialSend(rumorIds: [rumorId2])),
              ),
        ],
      );

      blocTest<ConversationBloc, ConversationState>(
        'reports thrown errors via addError and treats the rumor as '
        'still-failing',
        setUp: () {
          when(
            () => mockDmRepository.recoverSelfWrap(rumorId: rumorId1),
          ).thenThrow(StateError('queue DAO not wired'));
        },
        seed: () => const ConversationState(
          status: ConversationStatus.loaded,
          sendStatus: SendStatus.sentPartial,
          lastPartialSend: PartialSend(rumorIds: [rumorId1]),
        ),
        build: buildBloc,
        act: (bloc) => bloc.add(
          const ConversationSelfWrapRecoveryRequested(rumorIds: [rumorId1]),
        ),
        expect: () => [
          isA<ConversationState>().having(
            (s) => s.sendStatus,
            'sendStatus',
            SendStatus.sending,
          ),
          isA<ConversationState>()
              .having(
                (s) => s.sendStatus,
                'sendStatus',
                SendStatus.sentPartial,
              )
              .having(
                (s) => s.lastPartialSend?.rumorIds,
                'still-failing rumor preserved on throw',
                equals([rumorId1]),
              ),
        ],
        errors: () => [
          isA<Reportable<Object>>().having(
            (r) => r.unwrap(),
            'unwrap',
            isA<StateError>(),
          ),
        ],
      );

      blocTest<ConversationBloc, ConversationState>(
        'treats missing queue rows as terminal and clears them from the '
        'retry set without reporting',
        setUp: () {
          when(
            () => mockDmRepository.recoverSelfWrap(rumorId: rumorId1),
          ).thenThrow(
            ArgumentError.value(
              rumorId1,
              'rumorId',
              'no queued outgoing DM with this id',
            ),
          );
        },
        seed: () => const ConversationState(
          status: ConversationStatus.loaded,
          sendStatus: SendStatus.sentPartial,
          lastPartialSend: PartialSend(rumorIds: [rumorId1]),
        ),
        build: buildBloc,
        act: (bloc) => bloc.add(
          const ConversationSelfWrapRecoveryRequested(rumorIds: [rumorId1]),
        ),
        expect: () => [
          isA<ConversationState>().having(
            (s) => s.sendStatus,
            'sendStatus',
            SendStatus.sending,
          ),
          isA<ConversationState>()
              .having((s) => s.sendStatus, 'sendStatus', SendStatus.sent)
              .having(
                (s) => s.lastPartialSend,
                'clears terminal retry payload',
                isNull,
              ),
        ],
        errors: () => const <Object>[],
      );

      blocTest<ConversationBloc, ConversationState>(
        'is a no-op when rumorIds is empty',
        seed: () => const ConversationState(
          status: ConversationStatus.loaded,
          sendStatus: SendStatus.sentPartial,
          lastPartialSend: PartialSend(rumorIds: []),
        ),
        build: buildBloc,
        act: (bloc) => bloc.add(
          const ConversationSelfWrapRecoveryRequested(rumorIds: []),
        ),
        expect: () => const <ConversationState>[],
        verify: (_) {
          verifyNever(
            () => mockDmRepository.recoverSelfWrap(
              rumorId: any(named: 'rumorId'),
            ),
          );
        },
      );
    });

    group('ConversationMessageDeleted', () {
      late Completer<void> firstDeleteStarted;
      late Completer<void> releaseFirstDelete;

      blocTest<ConversationBloc, ConversationState>(
        'calls deleteMessageForEveryone on the repository',
        setUp: () {
          when(
            () => mockDmRepository.deleteMessageForEveryone(messageId),
          ).thenAnswer((_) async {});
        },
        build: buildBloc,
        act: (bloc) =>
            bloc.add(const ConversationMessageDeleted(rumorId: messageId)),
        verify: (_) {
          verify(
            () => mockDmRepository.deleteMessageForEveryone(messageId),
          ).called(1);
        },
      );

      blocTest<ConversationBloc, ConversationState>(
        'forwards `ArgumentError` (rumor gone / not ours) raw to addError '
        '— matrix-NO, recoverable',
        setUp: () {
          when(
            () => mockDmRepository.deleteMessageForEveryone(messageId),
          ).thenThrow(ArgumentError('message not found'));
        },
        build: buildBloc,
        act: (bloc) =>
            bloc.add(const ConversationMessageDeleted(rumorId: messageId)),
        errors: () => [isA<ArgumentError>()],
      );

      blocTest<ConversationBloc, ConversationState>(
        'wraps non-`ArgumentError` throws in Reportable — matrix-YES, '
        'invariant (e.g. an uninitialized repository `StateError`)',
        setUp: () {
          when(
            () => mockDmRepository.deleteMessageForEveryone(messageId),
          ).thenThrow(StateError('DmRepository not initialized'));
        },
        build: buildBloc,
        act: (bloc) =>
            bloc.add(const ConversationMessageDeleted(rumorId: messageId)),
        errors: () => [
          isA<Reportable<Object>>().having(
            (r) => r.unwrap(),
            'unwrap',
            isA<StateError>(),
          ),
        ],
      );

      blocTest<ConversationBloc, ConversationState>(
        'deletes a queue-only bubble by cancelling its durable row; the '
        'persisted-delete ArgumentError is expected and silent',
        setUp: () {
          // Queue-only optimistic/failed bubble: a row exists, no persisted
          // direct_messages row — deleteMessageForEveryone throws.
          when(
            () => mockDmRepository.cancelOutgoingBatch(
              rumorId: any(named: 'rumorId'),
            ),
          ).thenAnswer((_) async => 1);
          when(
            () => mockDmRepository.deleteMessageForEveryone(messageId),
          ).thenThrow(ArgumentError('message not found'));
        },
        build: buildBloc,
        act: (bloc) =>
            bloc.add(const ConversationMessageDeleted(rumorId: messageId)),
        errors: () => const <Object>[],
        verify: (_) {
          verify(
            () => mockDmRepository.cancelOutgoingBatch(rumorId: messageId),
          ).called(1);
        },
      );

      // Regression for #7322. The handler was registered with `droppable()`,
      // which discards on subscription state alone and never inspects the
      // payload — so a delete for a DIFFERENT message dispatched while the
      // first was still awaiting its signer round trip never reached the
      // repository at all: no kind 5, no local soft-delete, and (since no
      // path here emits) no feedback. Reproduced on a physical iPhone:
      // three deletes for three distinct rumor ids produced exactly one
      // handler entry.
      blocTest<ConversationBloc, ConversationState>(
        'deleting a second message while the first is still in flight still '
        'reaches the repository for both',
        setUp: () {
          firstDeleteStarted = Completer<void>();
          releaseFirstDelete = Completer<void>();
          when(
            () => mockDmRepository.deleteMessageForEveryone(messageId),
          ).thenAnswer((_) async {
            firstDeleteStarted.complete();
            await releaseFirstDelete.future;
          });
          when(
            () => mockDmRepository.deleteMessageForEveryone(otherMessageId),
          ).thenAnswer((_) async {});
        },
        build: buildBloc,
        act: (bloc) async {
          bloc.add(const ConversationMessageDeleted(rumorId: messageId));
          await firstDeleteStarted.future;
          bloc.add(const ConversationMessageDeleted(rumorId: otherMessageId));
          // Let the second event enter the transformer while the first handler
          // is still suspended, then allow the sequential queue to advance.
          await Future<void>.delayed(Duration.zero);
          releaseFirstDelete.complete();
        },
        verify: (_) {
          verify(
            () => mockDmRepository.deleteMessageForEveryone(messageId),
          ).called(1);
          verify(
            () => mockDmRepository.deleteMessageForEveryone(otherMessageId),
          ).called(1);
        },
      );
    });
    group(ConversationFullSendRecoveryRequested, () {
      // Queue-aware manual retry (gap 3): replay the EXISTING failed rows via
      // recoverFullSend — never a fresh ConversationMessageSent, which would
      // mint a new rumor id and risk a duplicate at the recipient.
      const rumorId1 =
          '7777777777777777777777777777777777777777777777777777777777777777';
      const rumorId2 =
          '8888888888888888888888888888888888888888888888888888888888888888';

      blocTest<ConversationBloc, ConversationState>(
        'replays each failed row via recoverFullSend (never a fresh send) '
        'and emits [sending, sent] on full recovery',
        setUp: () {
          when(
            () => mockDmRepository.recoverFullSend(
              rumorId: any(named: 'rumorId'),
              resetRetryBudget: any(named: 'resetRetryBudget'),
            ),
          ).thenAnswer(
            (inv) async => NIP17SendResult.success(
              rumorEventId: inv.namedArguments[#rumorId] as String,
              messageEventId: inv.namedArguments[#rumorId] as String,
              recipientPubkey: recipientPubkey,
            ),
          );
        },
        seed: () => const ConversationState(
          status: ConversationStatus.loaded,
          sendStatus: SendStatus.failed,
        ),
        build: buildBloc,
        act: (bloc) => bloc.add(
          const ConversationFullSendRecoveryRequested(
            rumorIds: [rumorId1, rumorId2],
          ),
        ),
        expect: () => [
          isA<ConversationState>().having(
            (s) => s.sendStatus,
            'sendStatus',
            SendStatus.sending,
          ),
          isA<ConversationState>().having(
            (s) => s.sendStatus,
            'sendStatus',
            SendStatus.sent,
          ),
        ],
        verify: (_) {
          verify(
            () => mockDmRepository.recoverFullSend(
              rumorId: rumorId1,
              resetRetryBudget: true,
            ),
          ).called(1);
          verify(
            () => mockDmRepository.recoverFullSend(
              rumorId: rumorId2,
              resetRetryBudget: true,
            ),
          ).called(1);
          // The anti-duplication contract: no fresh rumor is ever minted.
          verifyNever(
            () => mockDmRepository.sendMessage(
              recipientPubkey: any(named: 'recipientPubkey'),
              content: any(named: 'content'),
            ),
          );
          verifyNever(
            () => mockDmRepository.sendGroupMessage(
              recipientPubkeys: any(named: 'recipientPubkeys'),
              content: any(named: 'content'),
            ),
          );
        },
      );

      blocTest<ConversationBloc, ConversationState>(
        'treats a soft-unconfirmed replay as STILL FAILING — the targeted '
        'row is failed and the soft finalize never rewrites its status, so '
        'claiming sent would swallow the red bubble without a delivery',
        setUp: () {
          when(
            () => mockDmRepository.recoverFullSend(
              rumorId: any(named: 'rumorId'),
              resetRetryBudget: any(named: 'resetRetryBudget'),
            ),
          ).thenAnswer(
            (_) async => const NIP17SendResult.failure(
              'Message recipient OK unconfirmed',
              retryablePending: true,
            ),
          );
        },
        seed: () => const ConversationState(
          status: ConversationStatus.loaded,
          sendStatus: SendStatus.failed,
        ),
        build: buildBloc,
        act: (bloc) => bloc.add(
          const ConversationFullSendRecoveryRequested(rumorIds: [rumorId1]),
        ),
        expect: () => [
          isA<ConversationState>().having(
            (s) => s.sendStatus,
            'sendStatus',
            SendStatus.sending,
          ),
          isA<ConversationState>().having(
            (s) => s.sendStatus,
            'sendStatus',
            SendStatus.resendFailed,
          ),
        ],
      );

      blocTest<ConversationBloc, ConversationState>(
        'raises resendFailed, not failed, when a hard-failed row still '
        'cannot be recovered — the bubble was already red, so re-raising '
        'failed would leave the resend with no visible outcome (#8461)',
        setUp: () {
          when(
            () => mockDmRepository.recoverFullSend(
              rumorId: rumorId1,
              resetRetryBudget: true,
            ),
          ).thenAnswer(
            (_) async => const NIP17SendResult.failure('relay still down'),
          );
        },
        seed: () => const ConversationState(
          status: ConversationStatus.loaded,
          sendStatus: SendStatus.failed,
        ),
        build: buildBloc,
        act: (bloc) => bloc.add(
          const ConversationFullSendRecoveryRequested(rumorIds: [rumorId1]),
        ),
        expect: () => [
          isA<ConversationState>().having(
            (s) => s.sendStatus,
            'sendStatus',
            SendStatus.sending,
          ),
          isA<ConversationState>().having(
            (s) => s.sendStatus,
            'sendStatus',
            SendStatus.resendFailed,
          ),
        ],
      );
    });

    group(ConversationOutgoingSendCancelled, () {
      const rumorId =
          '9999999999999999999999999999999999999999999999999999999999999999';

      blocTest<ConversationBloc, ConversationState>(
        'drops the queued row via cancelOutgoingSend with no state emit — '
        'the bubble leaves on the next pendingOutgoing tick',
        setUp: () {
          when(
            () => mockDmRepository.cancelOutgoingSend(
              rumorId: any(named: 'rumorId'),
            ),
          ).thenAnswer((_) async => true);
        },
        seed: () => const ConversationState(
          status: ConversationStatus.loaded,
          sendStatus: SendStatus.failed,
        ),
        build: buildBloc,
        act: (bloc) => bloc.add(
          const ConversationOutgoingSendCancelled(rumorId: rumorId),
        ),
        expect: () => const <ConversationState>[],
        verify: (_) {
          verify(
            () => mockDmRepository.cancelOutgoingSend(rumorId: rumorId),
          ).called(1);
        },
      );

      blocTest<ConversationBloc, ConversationState>(
        'swallows an ArgumentError (foreign/already-gone row) with no error '
        'emit',
        setUp: () {
          when(
            () => mockDmRepository.cancelOutgoingSend(
              rumorId: any(named: 'rumorId'),
            ),
          ).thenThrow(ArgumentError('foreign owner'));
        },
        seed: () => const ConversationState(status: ConversationStatus.loaded),
        build: buildBloc,
        act: (bloc) => bloc.add(
          const ConversationOutgoingSendCancelled(rumorId: rumorId),
        ),
        expect: () => const <ConversationState>[],
        errors: () => const <Object>[],
      );
    });
  });

  group(ConversationState, () {
    test('supports value equality', () {
      expect(const ConversationState(), equals(const ConversationState()));
    });

    test('props are correct', () {
      expect(
        const ConversationState().props,
        equals([
          ConversationStatus.initial,
          <DmMessage>[],
          SendStatus.idle,
          <String>{},
          null,
          <OutgoingDm>[],
        ]),
      );
    });

    test(
      'pendingOutgoing defaults to empty and participates in equality',
      () {
        expect(
          const ConversationState().pendingOutgoing,
          equals(const <OutgoingDm>[]),
        );
        final row = _outgoingDm(id: 'rumor-test', content: 'Hi');
        expect(
          ConversationState(pendingOutgoing: [row]),
          equals(ConversationState(pendingOutgoing: [row])),
        );
        expect(
          const ConversationState(),
          isNot(equals(ConversationState(pendingOutgoing: [row]))),
        );
      },
    );

    group('displayedMessages projection', () {
      const persisted1 = DmMessage(
        id: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        conversationId: conversationId,
        senderPubkey: senderPubkey,
        content: 'persisted-1',
        // Newer than the optimistic below.
        createdAt: 1700000010,
        giftWrapId:
            'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      );
      const persisted0 = DmMessage(
        id: 'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
        conversationId: conversationId,
        senderPubkey: senderPubkey,
        content: 'persisted-0',
        // Older than the optimistic below.
        createdAt: 1699999990,
        giftWrapId:
            'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
      );
      final inFlightRow = _outgoingDm(
        id: 'rumor-inflight',
        content: 'in-flight',
      );

      test('returns messages identity when pendingOutgoing is empty', () {
        const state = ConversationState(messages: [persisted1, persisted0]);
        expect(state.displayedMessages, same(state.messages));
      });

      test('puts in-flight pending above older persisted, below newer', () {
        final state = ConversationState(
          messages: const [persisted1, persisted0],
          pendingOutgoing: [inFlightRow],
        );
        // Newest first: persisted1 (1700000010) > inFlightRow (1700000000)
        // > persisted0 (1699999990).
        expect(state.displayedMessages, hasLength(3));
        expect(state.displayedMessages.first.id, equals(persisted1.id));
        expect(state.displayedMessages[1].id, equals(inFlightRow.id));
        expect(state.displayedMessages[1].content, equals('in-flight'));
        expect(state.displayedMessages.last.id, equals(persisted0.id));
      });

      test(
        'drops pending whose rumor id collides with a persisted row',
        () {
          // Window between sendMessage's persistence-transaction commit
          // and the next watchOutgoing tick: both streams briefly carry
          // the row. Persisted wins on id collision.
          final colliding = _outgoingDm(
            id: persisted1.id,
            content: 'in-flight duplicate',
            createdAtSec: 1700000010,
          );
          final state = ConversationState(
            messages: const [persisted1],
            pendingOutgoing: [colliding],
          );
          expect(state.displayedMessages, equals(const [persisted1]));
        },
      );

      test('returns an unmodifiable view when merge runs', () {
        final state = ConversationState(
          messages: const [persisted1],
          pendingOutgoing: [inFlightRow],
        );
        final view = state.displayedMessages;
        expect(() => view.add(persisted0), throwsUnsupportedError);
      });
    });

    group('statusFor', () {
      test('returns delivered when no queue row exists', () {
        const state = ConversationState();
        expect(
          state.statusFor('not-in-queue'),
          equals(DmDeliveryStatus.delivered),
        );
      });

      test(
        'returns delivered for an id absent from a non-empty queue '
        '(past the empty-queue short-circuit)',
        () {
          final row = _outgoingDm(id: 'rumor-present');
          final state = ConversationState(pendingOutgoing: [row]);
          expect(
            state.statusFor('rumor-absent'),
            equals(DmDeliveryStatus.delivered),
          );
        },
      );

      test('returns pending while recipient wrap is pending', () {
        final row = _outgoingDm(id: 'rumor-pending');
        final state = ConversationState(pendingOutgoing: [row]);
        expect(
          state.statusFor('rumor-pending'),
          equals(DmDeliveryStatus.pending),
        );
      });

      test('returns failed when recipient wrap failed', () {
        final row = _outgoingDm(
          id: 'rumor-recipient-failed',
          recipientWrap: OutgoingWrapStatus.failed,
        );
        final state = ConversationState(pendingOutgoing: [row]);
        expect(
          state.statusFor('rumor-recipient-failed'),
          equals(DmDeliveryStatus.failed),
        );
      });

      test(
        'returns deliveredSelfFailed when recipient sent but self failed',
        () {
          final row = _outgoingDm(
            id: 'rumor-self-failed',
            recipientWrap: OutgoingWrapStatus.sent,
            selfWrap: OutgoingWrapStatus.failed,
          );
          final state = ConversationState(pendingOutgoing: [row]);
          expect(
            state.statusFor('rumor-self-failed'),
            equals(DmDeliveryStatus.deliveredSelfFailed),
          );
        },
      );

      test(
        'returns delivered when recipient sent and self still pending '
        '(brief transitional state)',
        () {
          final row = _outgoingDm(
            id: 'rumor-self-pending',
            recipientWrap: OutgoingWrapStatus.sent,
          );
          final state = ConversationState(pendingOutgoing: [row]);
          expect(
            state.statusFor('rumor-self-pending'),
            equals(DmDeliveryStatus.delivered),
          );
        },
      );
    });

    test('states with different lastPartialSend are not equal', () {
      expect(
        const ConversationState(),
        isNot(
          equals(
            const ConversationState(
              lastPartialSend: PartialSend(rumorIds: [messageId]),
            ),
          ),
        ),
      );
    });

    test(
      'copyWith carries lastPartialSend forward when not overridden',
      () {
        const partial = PartialSend(rumorIds: [messageId]);
        const seeded = ConversationState(lastPartialSend: partial);

        expect(
          seeded.copyWith(sendStatus: SendStatus.sending).lastPartialSend,
          equals(partial),
        );
      },
    );

    test(
      'copyWith(clearLastPartialSend: true) wipes lastPartialSend',
      () {
        const partial = PartialSend(rumorIds: [messageId]);
        const seeded = ConversationState(lastPartialSend: partial);

        expect(
          seeded.copyWith(clearLastPartialSend: true).lastPartialSend,
          isNull,
        );
      },
    );

    test('states with different status are not equal', () {
      expect(
        const ConversationState(),
        isNot(
          equals(const ConversationState(status: ConversationStatus.loading)),
        ),
      );
    });

    test('states with different messages are not equal', () {
      const message = DmMessage(
        id: messageId,
        conversationId: conversationId,
        senderPubkey: senderPubkey,
        content: 'Hello',
        createdAt: 1700000000,
        giftWrapId: giftWrapId,
      );

      expect(
        const ConversationState(),
        isNot(equals(const ConversationState(messages: [message]))),
      );
    });

    test('states with different sendStatus are not equal', () {
      expect(
        const ConversationState(),
        isNot(equals(const ConversationState(sendStatus: SendStatus.sending))),
      );
    });

    test('copyWith returns same object when no parameters are provided', () {
      const state = ConversationState();

      expect(state.copyWith(), equals(state));
    });

    test('copyWith replaces every value', () {
      const message = DmMessage(
        id: messageId,
        conversationId: conversationId,
        senderPubkey: senderPubkey,
        content: 'Hello',
        createdAt: 1700000000,
        giftWrapId: giftWrapId,
      );

      const state = ConversationState();

      final copied = state.copyWith(
        status: ConversationStatus.loaded,
        messages: [message],
        sendStatus: SendStatus.sent,
      );

      expect(copied.status, equals(ConversationStatus.loaded));
      expect(copied.messages, equals([message]));
      expect(copied.sendStatus, equals(SendStatus.sent));
    });
  });

  group(ConversationEvent, () {
    group(ConversationStarted, () {
      test('supports value equality', () {
        expect(
          const ConversationStarted(),
          equals(const ConversationStarted()),
        );
      });

      test('props are correct', () {
        expect(const ConversationStarted().props, equals(<Object?>[]));
      });
    });

    group(ConversationMessageSent, () {
      test('supports value equality', () {
        expect(
          const ConversationMessageSent(
            recipientPubkeys: [recipientPubkey],
            content: 'Hello',
          ),
          equals(
            const ConversationMessageSent(
              recipientPubkeys: [recipientPubkey],
              content: 'Hello',
            ),
          ),
        );
      });

      test('events with different recipientPubkeys are not equal', () {
        expect(
          const ConversationMessageSent(
            recipientPubkeys: [recipientPubkey],
            content: 'Hello',
          ),
          isNot(
            equals(
              const ConversationMessageSent(
                recipientPubkeys: [recipientPubkey2],
                content: 'Hello',
              ),
            ),
          ),
        );
      });

      test('events with different content are not equal', () {
        expect(
          const ConversationMessageSent(
            recipientPubkeys: [recipientPubkey],
            content: 'Hello',
          ),
          isNot(
            equals(
              const ConversationMessageSent(
                recipientPubkeys: [recipientPubkey],
                content: 'Goodbye',
              ),
            ),
          ),
        );
      });

      test('props are correct', () {
        expect(
          const ConversationMessageSent(
            recipientPubkeys: [recipientPubkey],
            content: 'Hello',
          ).props,
          equals([
            [recipientPubkey],
            'Hello',
          ]),
        );
      });
    });

    group(ConversationMessageDeleted, () {
      test('supports value equality', () {
        expect(
          const ConversationMessageDeleted(rumorId: messageId),
          equals(const ConversationMessageDeleted(rumorId: messageId)),
        );
      });

      test('props are correct', () {
        expect(
          const ConversationMessageDeleted(rumorId: messageId).props,
          equals([messageId]),
        );
      });
    });

    group(ConversationSelfWrapRecoveryRequested, () {
      test('supports value equality', () {
        expect(
          const ConversationSelfWrapRecoveryRequested(rumorIds: [messageId]),
          equals(
            const ConversationSelfWrapRecoveryRequested(rumorIds: [messageId]),
          ),
        );
      });

      test('events with different rumorIds are not equal', () {
        expect(
          const ConversationSelfWrapRecoveryRequested(rumorIds: [messageId]),
          isNot(
            equals(
              const ConversationSelfWrapRecoveryRequested(
                rumorIds: [giftWrapId],
              ),
            ),
          ),
        );
      });

      test('props are correct', () {
        expect(
          const ConversationSelfWrapRecoveryRequested(
            rumorIds: [messageId, giftWrapId],
          ).props,
          equals([
            const [messageId, giftWrapId],
          ]),
        );
      });
    });
  });
}

DmMessage _blocked(DmMessage m) => DmMessage(
  id: m.id,
  conversationId: m.conversationId,
  senderPubkey: m.senderPubkey,
  content: m.content,
  createdAt: m.createdAt,
  giftWrapId: m.giftWrapId,
  messageKind: m.messageKind,
  replyToId: m.replyToId,
  subject: m.subject,
  tags: m.tags,
  fileMetadata: m.fileMetadata,
  sharedVideoRef: m.sharedVideoRef,
  sendBatchId: m.sendBatchId,
  retractionStatus: DmRetractionStatus.failed,
);

DmMessage _pending(DmMessage m) => DmMessage(
  id: m.id,
  conversationId: m.conversationId,
  senderPubkey: m.senderPubkey,
  content: m.content,
  createdAt: m.createdAt,
  giftWrapId: m.giftWrapId,
  messageKind: m.messageKind,
  replyToId: m.replyToId,
  subject: m.subject,
  tags: m.tags,
  fileMetadata: m.fileMetadata,
  sharedVideoRef: m.sharedVideoRef,
  sendBatchId: m.sendBatchId,
  retractionStatus: DmRetractionStatus.pending,
);
