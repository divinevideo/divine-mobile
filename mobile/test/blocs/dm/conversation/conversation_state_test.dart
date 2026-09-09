// ABOUTME: Tests for ConversationState's pure projection getters —
// ABOUTME: displayedMessages batch collapsing/suppression, reply linkage,
// ABOUTME: and the sibling helpers that drive group-bubble status + actions.

import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/conversation/conversation_bloc.dart';

const _owner =
    '1111111111111111111111111111111111111111111111111111111111111111';
const _recipientB =
    '2222222222222222222222222222222222222222222222222222222222222222';
const _recipientC =
    '3333333333333333333333333333333333333333333333333333333333333333';

/// Group-shaped conversation id: deliberately NOT the 1:1 pair id of any
/// (owner, recipient) pair below, so default fixtures are group rows.
const _groupConversationId =
    'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';

/// The 1:1 pair id for (owner, recipient) — rows carrying this id are
/// classified as plain 1:1 sends, never batch members.
String _pairConversationId(String recipient) =>
    DmRepository.computeConversationId([_owner, recipient]);

/// Builds an [OutgoingDm] queue row for the [ConversationState] projection
/// tests. Mirrors the sibling builder in `conversation_bloc_test.dart` but
/// additionally exposes [replyToId], which the reply-linkage case needs.
OutgoingDm _outgoingDm({
  required String id,
  String? rumorId,
  String content = 'test',
  int createdAtSec = 1700000000,
  String? replyToId,
  String ownerPubkey = _owner,
  String recipientPubkey = _recipientB,
  String conversationId = _groupConversationId,
  OutgoingWrapStatus recipientWrap = OutgoingWrapStatus.pending,
  OutgoingWrapStatus selfWrap = OutgoingWrapStatus.pending,
  String? sendBatchId,
}) {
  return OutgoingDm(
    id: id,
    conversationId: conversationId,
    recipientPubkey: recipientPubkey,
    content: content,
    createdAt: createdAtSec,
    rumorEventJson: rumorId == null ? '{}' : '{"id":"$rumorId"}',
    replyToId: replyToId,
    recipientWrapStatus: recipientWrap,
    selfWrapStatus: selfWrap,
    queuedAt: DateTime.fromMillisecondsSinceEpoch(createdAtSec * 1000),
    ownerPubkey: ownerPubkey,
    sendBatchId: sendBatchId,
  );
}

/// A persisted [DmMessage] — the shape `watchMessages` delivers after the
/// repository's success transaction inserted the batch winner.
DmMessage _message({
  required String id,
  String senderPubkey = _owner,
  String content = 'test',
  int createdAtSec = 1700000000,
  String conversationId = _groupConversationId,
  String? sendBatchId,
}) {
  return DmMessage(
    id: id,
    conversationId: conversationId,
    senderPubkey: senderPubkey,
    content: content,
    createdAt: createdAtSec,
    giftWrapId: 'wrap-$id',
    sendBatchId: sendBatchId,
  );
}

void main() {
  group(ConversationState, () {
    group('displayedMessages', () {
      const parentId =
          '7777777777777777777777777777777777777777777777777777777777777777';

      test(
        'optimistic outgoing bubble carries its replyToId so an in-flight '
        'reply can resolve its parent',
        () {
          final replyRow = _outgoingDm(
            id: 'rumor-reply',
            content: 'replying in-flight',
            replyToId: parentId,
          );
          final state = ConversationState(pendingOutgoing: [replyRow]);

          final bubble = state.displayedMessages.firstWhere(
            (m) => m.id == 'rumor-reply',
          );
          expect(bubble.replyToId, equals(parentId));
        },
      );

      test(
        'optimistic outgoing bubble has a null replyToId when the queued '
        'row is not a reply',
        () {
          final plainRow = _outgoingDm(id: 'rumor-plain', content: 'hi');
          final state = ConversationState(pendingOutgoing: [plainRow]);

          final bubble = state.displayedMessages.firstWhere(
            (m) => m.id == 'rumor-plain',
          );
          expect(bubble.replyToId, isNull);
        },
      );

      test('a shared-rumor group batch exposes the wire id while retaining '
          'queue handles for recovery', () {
        const wireId = 'shared-wire-rumor';
        final pending = _outgoingDm(
          id: '$wireId:$_recipientB',
          rumorId: wireId,
          sendBatchId: 'batch-shared',
        );
        final failed = _outgoingDm(
          id: '$wireId:$_recipientC',
          rumorId: wireId,
          recipientPubkey: _recipientC,
          recipientWrap: OutgoingWrapStatus.failed,
          sendBatchId: 'batch-shared',
        );
        final state = ConversationState(pendingOutgoing: [pending, failed]);

        expect(state.displayedMessages.single.id, equals(wireId));
        expect(state.statusFor(wireId), equals(DmDeliveryStatus.failed));
        expect(
          state.failedSiblingRumorIdsFor(wireId),
          equals(['$wireId:$_recipientC']),
          reason: 'recovery still receives the durable queue handle',
        );
      });

      test('a retained terminal block renders as blocked, not delivered', () {
        final blocked = _outgoingDm(
          id: 'blocked-rumor',
          rumorId: 'blocked-rumor',
          recipientWrap: OutgoingWrapStatus.blocked,
        );
        final state = ConversationState(pendingOutgoing: [blocked]);

        expect(state.displayedMessages.single.id, 'blocked-rumor');
        expect(
          state.statusFor('blocked-rumor'),
          DmDeliveryStatus.blocked,
        );
        expect(state.failedSiblingRumorIdsFor('blocked-rumor'), isEmpty);
      });

      test(
        'partial group delivery renders exactly ONE bubble with the '
        'combined status — the persisted winner suppresses the surviving '
        'batch and aggregates its failure',
        () {
          // 2-recipient group send: recipient B confirmed (its queue row was
          // deleted in the persist transaction; the message is persisted
          // under B's rumor id), recipient C hard-failed (row survives).
          final failedSibling = _outgoingDm(
            id: 'rumor-c',
            content: 'group hello',
            recipientPubkey: _recipientC,
            recipientWrap: OutgoingWrapStatus.failed,
            selfWrap: OutgoingWrapStatus.failed,
          );
          final persistedWinner = _message(
            id: 'rumor-b',
            content: 'group hello',
          );
          final state = ConversationState(
            messages: [persistedWinner],
            pendingOutgoing: [failedSibling],
          );

          expect(
            state.displayedMessages,
            hasLength(1),
            reason:
                'the surviving sibling must be folded into the persisted '
                'bubble, not rendered as a duplicate',
          );
          expect(state.displayedMessages.single.id, equals('rumor-b'));
          expect(
            state.statusFor('rumor-b'),
            equals(DmDeliveryStatus.failed),
            reason:
                'the persisted bubble surfaces the remaining sibling '
                'failure as the red tap-to-resend affordance',
          );
        },
      );

      test(
        'a 3-recipient batch with one confirmed and two surviving siblings '
        'still renders one bubble',
        () {
          final pendingSibling = _outgoingDm(
            id: 'rumor-c',
            content: 'trio',
            recipientPubkey: _recipientC,
          );
          final failedSibling = _outgoingDm(
            id: 'rumor-d',
            content: 'trio',
            recipientPubkey: '4444444444444444444444444444444444444444444444444444444444444444',
            recipientWrap: OutgoingWrapStatus.failed,
          );
          final persistedWinner = _message(id: 'rumor-b', content: 'trio');
          final state = ConversationState(
            messages: [persistedWinner],
            pendingOutgoing: [pendingSibling, failedSibling],
          );

          expect(state.displayedMessages, hasLength(1));
          expect(state.displayedMessages.single.id, equals('rumor-b'));
          expect(state.statusFor('rumor-b'), equals(DmDeliveryStatus.failed));
        },
      );

      test(
        'a legacy in-flight batch renders one bubble keyed to the lowest '
        'queue handle',
        () {
          final rowB = _outgoingDm(id: 'rumor-b', content: 'live batch');
          final rowC = _outgoingDm(
            id: 'rumor-a-sorts-first',
            content: 'live batch',
            recipientPubkey: _recipientC,
          );
          final state = ConversationState(pendingOutgoing: [rowB, rowC]);

          expect(state.displayedMessages, hasLength(1));
          expect(
            state.displayedMessages.single.id,
            equals('rumor-a-sorts-first'),
          );
        },
      );

      test(
        'an INCOMING message coincidentally sharing (createdAt, content) '
        'never suppresses the in-flight batch',
        () {
          final batchRow = _outgoingDm(id: 'rumor-mine', content: '👍');
          final incoming = _message(
            id: 'rumor-theirs',
            senderPubkey: _recipientC,
            content: '👍',
          );
          final state = ConversationState(
            messages: [incoming],
            pendingOutgoing: [batchRow],
          );

          expect(
            state.displayedMessages,
            hasLength(2),
            reason:
                'suppression is scoped to OWN persisted messages — a peer '
                'sending the same text in the same second must not hide '
                'our in-flight bubble (and its failure affordance)',
          );
        },
      );

      test(
        'two identical 1:1 sends in the same second stay independent '
        'bubbles — pair rows never group',
        () {
          final first = _outgoingDm(
            id: 'rumor-1',
            content: 'same text',
            conversationId: _pairConversationId(_recipientB),
          );
          final second = _outgoingDm(
            id: 'rumor-2',
            content: 'same text',
            conversationId: _pairConversationId(_recipientB),
          );
          final state = ConversationState(pendingOutgoing: [first, second]);

          expect(state.displayedMessages, hasLength(2));
        },
      );

      test(
        '1:1 tick window: the persisted row wins on rumor-id collision',
        () {
          final row = _outgoingDm(
            id: 'rumor-1',
            content: 'hello',
            conversationId: _pairConversationId(_recipientB),
          );
          final persisted = _message(
            id: 'rumor-1',
            content: 'hello',
            conversationId: _pairConversationId(_recipientB),
          );
          final state = ConversationState(
            messages: [persisted],
            pendingOutgoing: [row],
          );

          expect(state.displayedMessages, hasLength(1));
        },
      );
    });

    group('statusFor group aggregation', () {
      test('any hard-failed sibling wins: failed', () {
        final state = ConversationState(
          messages: [_message(id: 'rumor-b')],
          pendingOutgoing: [
            _outgoingDm(id: 'rumor-c', recipientPubkey: _recipientC),
            _outgoingDm(
              id: 'rumor-d',
              recipientPubkey: '4444444444444444444444444444444444444444444444444444444444444444',
              recipientWrap: OutgoingWrapStatus.failed,
            ),
          ],
        );
        expect(state.statusFor('rumor-b'), equals(DmDeliveryStatus.failed));
      });

      test('no failure but a still-pending sibling: pending', () {
        final state = ConversationState(
          messages: [_message(id: 'rumor-b')],
          pendingOutgoing: [
            _outgoingDm(id: 'rumor-c', recipientPubkey: _recipientC),
          ],
        );
        expect(state.statusFor('rumor-b'), equals(DmDeliveryStatus.pending));
      });

      test(
        'all recipients delivered but a self-wrap missing: '
        'deliveredSelfFailed',
        () {
          final state = ConversationState(
            messages: [_message(id: 'rumor-b')],
            pendingOutgoing: [
              _outgoingDm(
                id: 'rumor-c',
                recipientPubkey: _recipientC,
                recipientWrap: OutgoingWrapStatus.sent,
                selfWrap: OutgoingWrapStatus.failed,
              ),
            ],
          );
          expect(
            state.statusFor('rumor-b'),
            equals(DmDeliveryStatus.deliveredSelfFailed),
          );
        },
      );

      test(
        'an incoming persisted id sharing the batch identity resolves to '
        'delivered — the owner guard keeps foreign bubbles out of our '
        'batch',
        () {
          final state = ConversationState(
            messages: [_message(id: 'rumor-theirs', senderPubkey: _recipientC)],
            pendingOutgoing: [
              _outgoingDm(
                id: 'rumor-mine',
                recipientWrap: OutgoingWrapStatus.failed,
              ),
            ],
          );
          expect(
            state.statusFor('rumor-theirs'),
            equals(DmDeliveryStatus.delivered),
          );
        },
      );
    });

    group('sibling id helpers', () {
      ConversationState mixedBatch() => ConversationState(
        messages: [_message(id: 'rumor-b')],
        pendingOutgoing: [
          _outgoingDm(id: 'rumor-c', recipientPubkey: _recipientC),
          _outgoingDm(
            id: 'rumor-d',
            recipientPubkey: '4444444444444444444444444444444444444444444444444444444444444444',
            recipientWrap: OutgoingWrapStatus.failed,
          ),
          _outgoingDm(
            id: 'rumor-e',
            recipientPubkey: '5555555555555555555555555555555555555555555555555555555555555555',
            recipientWrap: OutgoingWrapStatus.sent,
            selfWrap: OutgoingWrapStatus.failed,
          ),
        ],
      );

      test(
        'failedSiblingRumorIdsFor returns only hard-failed siblings — the '
        'manual Resend set',
        () {
          expect(
            mixedBatch().failedSiblingRumorIdsFor('rumor-b'),
            equals(['rumor-d']),
          );
        },
      );

      test(
        'undeliveredSiblingRumorIdsFor returns pending + failed but never '
        'a delivered-awaiting-self-wrap sibling — the cancel-send set',
        () {
          expect(
            mixedBatch().undeliveredSiblingRumorIdsFor('rumor-b'),
            unorderedEquals(['rumor-c', 'rumor-d']),
          );
        },
      );

      test('a 1:1 failed bubble resolves to exactly itself', () {
        final row = _outgoingDm(
          id: 'rumor-1',
          conversationId: _pairConversationId(_recipientB),
          recipientWrap: OutgoingWrapStatus.failed,
        );
        final state = ConversationState(pendingOutgoing: [row]);

        expect(state.failedSiblingRumorIdsFor('rumor-1'), equals(['rumor-1']));
        expect(
          state.undeliveredSiblingRumorIdsFor('rumor-1'),
          equals(['rumor-1']),
        );
      });
    });

    group('distinct sendBatchId keeps identical group sends independent', () {
      // The exact regression the durable batch key fixes: the same group,
      // same text, same second, sent twice. Both fan-outs share
      // (owner, createdAt, content) — every row relies on the builder's
      // default createdAt, so the legacy tuple key was identical across the
      // two sends and collapsed them into one bubble with cross-contaminated
      // status. Batch A stays all-pending, batch B is all-failed, so any leak
      // between them is observable in both the bubble count and the status.
      const sharedContent = 'same group text';

      ConversationState twoBatches() => ConversationState(
        pendingOutgoing: [
          _outgoingDm(
            id: 'rumor-a1',
            content: sharedContent,
            sendBatchId: 'batch-A',
          ),
          _outgoingDm(
            id: 'rumor-a2',
            content: sharedContent,
            recipientPubkey: _recipientC,
            sendBatchId: 'batch-A',
          ),
          _outgoingDm(
            id: 'rumor-b1',
            content: sharedContent,
            recipientWrap: OutgoingWrapStatus.failed,
            selfWrap: OutgoingWrapStatus.failed,
            sendBatchId: 'batch-B',
          ),
          _outgoingDm(
            id: 'rumor-b2',
            content: sharedContent,
            recipientPubkey: _recipientC,
            recipientWrap: OutgoingWrapStatus.failed,
            selfWrap: OutgoingWrapStatus.failed,
            sendBatchId: 'batch-B',
          ),
        ],
      );

      test(
        'projects two independent bubbles, not one collapsed batch',
        () {
          final displayed = twoBatches().displayedMessages;

          expect(
            displayed,
            hasLength(2),
            reason:
                'the legacy (owner, createdAt, content) tuple key folded '
                'both sends into a single bubble; the durable sendBatchId '
                'keeps them independent',
          );
          // Legacy fixtures without rumor JSON fall back to queue handles.
          expect(
            displayed.map((m) => m.id),
            unorderedEquals(['rumor-a1', 'rumor-b1']),
          );
        },
      );

      test(
        'statusFor aggregates only the addressed batch — the pending batch '
        'stays pending despite the sibling batch being entirely failed',
        () {
          final state = twoBatches();

          expect(
            state.statusFor('rumor-a1'),
            equals(DmDeliveryStatus.pending),
            reason:
                "batch A is all pending; the legacy key folded batch B's "
                'failures in and reported failed',
          );
          expect(
            state.statusFor('rumor-b1'),
            equals(DmDeliveryStatus.failed),
          );
        },
      );

      test(
        'sibling id helpers never reach across the batch boundary',
        () {
          final state = twoBatches();

          // The cancel-send set for batch A is exactly batch A's rows.
          expect(
            state.undeliveredSiblingRumorIdsFor('rumor-a1'),
            unorderedEquals(['rumor-a1', 'rumor-a2']),
          );
          // Batch A has no failures — a leak would surface batch B's ids.
          expect(state.failedSiblingRumorIdsFor('rumor-a1'), isEmpty);
          // And batch B's undelivered set is exactly batch B's rows.
          expect(
            state.undeliveredSiblingRumorIdsFor('rumor-b1'),
            unorderedEquals(['rumor-b1', 'rumor-b2']),
          );
        },
      );

      test(
        "a persisted message carrying batch A's sendBatchId suppresses only "
        "batch A's bubble, leaving batch B visible",
        () {
          final state = twoBatches().copyWith(
            messages: [
              _message(
                id: 'persisted-a',
                content: sharedContent,
                sendBatchId: 'batch-A',
              ),
            ],
          );

          final displayed = state.displayedMessages;

          expect(displayed, hasLength(2));
          expect(
            displayed.map((m) => m.id),
            unorderedEquals(['persisted-a', 'rumor-b1']),
            reason:
                'the persisted winner suppresses its own batch A pending '
                "bubble but must not swallow batch B's independent send",
          );
        },
      );
    });
  });
}
