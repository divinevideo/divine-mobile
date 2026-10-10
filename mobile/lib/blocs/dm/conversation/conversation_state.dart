// ABOUTME: State for ConversationBloc.

part of 'conversation_bloc.dart';

enum ConversationStatus { initial, loading, loaded, error }

/// Outcome of the most recent send attempt.
///
/// [sentPartial] indicates the recipient received the message but the
/// sender's self-addressed NIP-17 gift wrap did not reach relays, so the
/// sender's other devices will not see this message on relay-only restore.
/// Distinct from [sent] (full success) and [failed] (recipient never got it).
///
/// [blocked] is a policy block (protected-minor DM restriction, #176): the send
/// was refused, not a transient failure, so the UI shows distinct copy with NO
/// retry affordance (retrying only re-hits the same policy).
///
/// [failed] leans on the red "Not delivered" bubble as its affordance, so it
/// raises no toast. [blocked] and [noRecipient] never produce a queue row and
/// therefore never produce a bubble, which is why both are toasted instead.
///
/// [resendFailed] is that same failure reached from an explicit resend, and it
/// is separate precisely because the bubble affordance does NOT work twice: the
/// row was already red before the tap, so re-emitting [failed] leaves the
/// before and after states identical and the resend is indistinguishable from
/// a tap that did nothing (#8461). It is toasted for that reason.
enum SendStatus {
  idle,
  sending,
  sent,
  sentPartial,
  failed,

  /// A user-initiated resend that failed again. See the enum doc: this is
  /// [failed] with a working affordance, not a different repository outcome.
  resendFailed,
  blocked,

  /// Dispatched with an empty recipient list (#7335). Refused before the
  /// repository, so nothing is enqueued and nothing is retriable.
  noRecipient,

  /// The rumor exceeds what NIP-44 can encrypt (#7331). Refused before the
  /// enqueue, so — unlike [failed] — there is NO queue row and therefore no
  /// bubble to carry the red "Not delivered" affordance. The UI must surface
  /// this itself, and must keep the composer's text: the message is the only
  /// copy the user has.
  tooLong,
}

/// Per-bubble delivery status, derived from the durable `outgoing_dms`
/// queue row (when present) merged with the persisted `direct_messages`
/// row (when present).
///
/// Bubbles flow through this enum: [pending] → [delivered] on full
/// success, [pending] → [deliveredSelfFailed] on a partial delivery,
/// [pending] → [failed] on a retryable recipient-side publish failure, or
/// [pending] → [blocked] on a terminal refusal whose local record is retained.
/// Persisted rows with no queue row remaining are always [delivered], which is
/// why a delivery the sender stops keeps its row: a stored group bubble with a
/// stopped sibling is [notSentToEveryone] (#8180).
enum DmDeliveryStatus {
  /// Neither wrap has landed yet. Renders as a plain sent bubble — sends are
  /// optimistic, so there is no in-flight indicator (only [failed] is shown).
  pending,

  /// Both wraps landed, or the row is persisted with no queue row
  /// remaining (the repository deletes the queue row in the same
  /// transaction that inserts the persisted message).
  delivered,

  /// Recipient gift wrap landed, self-addressed gift wrap did not.
  /// The recipient sees the message; the sender's other devices will
  /// not on relay-only restore. Renders as a plain sent bubble (the
  /// self-wrap recovery runs silently); no distinct indicator.
  deliveredSelfFailed,

  /// Recipient gift wrap failed. The bubble shows the red "Not delivered" row
  /// and is tappable to resend/cancel; the retry service replays it on
  /// reconnect.
  failed,

  /// Recipient delivery is permanently blocked. The bubble stays visible as
  /// the sender's record, shows closed-thread copy, and cannot be retried.
  blocked,

  /// At least one member of a group message was not reached and the sender
  /// stopped trying (Stop trying, or a delete for everyone that has not gone
  /// through). The bubble stays for the members who have the message and says
  /// so; there is nothing to retry.
  notSentToEveryone,
}

/// Snapshot of the rumor ids whose recipient publish landed but whose
/// self-addressed gift wrap did not, on the most recent send attempt.
///
/// Drives the self-wrap-only recovery path: tapping Retry on the
/// `sentPartial` SnackBar dispatches [ConversationSelfWrapRecoveryRequested]
/// with [rumorIds], so only the missing self-wraps are republished and
/// recipients are never re-delivered to.
class PartialSend extends Equatable {
  const PartialSend({required this.rumorIds});

  /// Rumor event ids whose self-wrap publish did not land. One id for a
  /// 1:1 partial; one or more ids for a group partial (only the
  /// per-recipient sends with `selfWrapPublished == false`).
  final List<String> rumorIds;

  @override
  List<Object?> get props => [rumorIds];
}

class ConversationState extends Equatable {
  const ConversationState({
    this.status = ConversationStatus.initial,
    this.messages = const [],
    this.sendStatus = SendStatus.idle,
    this.awaitingRetraction = const <String>{},
    this.lastPartialSend,
    this.pendingOutgoing = const <OutgoingDm>[],
  });

  final ConversationStatus status;

  /// Persisted messages emitted by `DmRepository.watchMessages` — the
  /// reactive projection of `direct_messages` rows for this conversation.
  /// Replaced wholesale on every watch tick.
  final List<DmMessage> messages;
  final SendStatus sendStatus;

  /// Rumor ids this screen is actively trying to retract (#8201).
  ///
  /// An id is removed when its visible bubble transitions to failed or leaves
  /// the thread after confirmed delivery. The view checks the resulting bubble
  /// state before announcing, so confirmed retractions stay quiet while
  /// failures that predate the current screen also remain quiet.
  final Set<String> awaitingRetraction;

  /// The last send attempt that delivered to recipients but failed to
  /// publish the sender self-addressed gift wrap, paired with the rumor
  /// ids the recovery path must replay.
  ///
  /// `null` outside a [SendStatus.sentPartial] state. The retry SnackBar
  /// reads this to dispatch [ConversationSelfWrapRecoveryRequested]
  /// instead of a full [ConversationMessageSent], so recipients are
  /// never re-delivered to.
  final PartialSend? lastPartialSend;

  /// Durable in-flight queue rows for this conversation, projected from
  /// `DmRepository.watchOutgoing`. Replaces the in-memory
  /// `pendingOptimistic` slice from #4193 — the queue row IS the
  /// optimistic now, durable across app kill, and the repository
  /// enqueues it before any signer round-trip so the first watch tick
  /// fires within microseconds of dispatch.
  ///
  /// A row leaves this list when:
  /// - both wraps land → the repository deletes the queue row in the
  ///   same transaction that inserts the persisted `direct_messages`
  ///   row; the next [pendingOutgoing] tick drops it and the next
  ///   [messages] tick carries the persisted row in its place;
  /// - the retry policy gives up after exhausting retries (terminal
  ///   failure) — surfaced via [failed] status; the queue row stays
  ///   until the user explicitly cancels.
  ///
  /// One kind of row is neither in flight nor leaving: a member of a stored
  /// group message whose delivery the sender stopped. The repository keeps
  /// it, marked [OutgoingWrapStatus.cancelled], as the record behind
  /// [DmDeliveryStatus.notSentToEveryone].
  final List<OutgoingDm> pendingOutgoing;

  /// Lookup by either the durable queue handle or the wire rumor id.
  ///
  /// Group siblings share one wire rumor id, so the latter key resolves an
  /// arbitrary sibling; [_siblingRowsFor] then expands it by batch id.
  Map<String, OutgoingDm> get _outgoingByRumorId => {
    for (final row in pendingOutgoing) ...{row.id: row, row.rumorId: row},
  };

  /// Whether [q] belongs to a GROUP send — the repository's own
  /// discriminator (mirrors `_recoverFullSendLocked`): a group row's
  /// conversation id differs from the 1:1 pair id of (owner, recipient).
  ///
  /// This is deliberately per-row, not derived from how many siblings
  /// currently survive: a 2-recipient group whose first recipient confirmed
  /// (row deleted) leaves a single surviving sibling, which a
  /// count-your-siblings heuristic misclassifies as 1:1 — hiding the
  /// persisted bubble's failure aggregation exactly when it matters.
  bool _isGroupRow(OutgoingDm q) =>
      q.conversationId !=
      DmRepository.computeConversationId([q.ownerPubkey, q.recipientPubkey]);

  /// Durable batch key for a queue row: the stamped `sendBatchId` when
  /// present, else the legacy `(owner, createdAt, content)` tuple for rows
  /// enqueued before the column existed. New keys are 64-hex event ids and
  /// legacy keys are pipe-delimited tuples — disjoint string spaces, so a new
  /// batch never aggregates a legacy one and vice versa.
  static String _batchKeyOf(OutgoingDm q) =>
      q.sendBatchId ?? '${q.ownerPubkey}|${q.createdAt}|${q.content}';

  /// Batch key for a persisted message, mirroring [_batchKeyOf]. Received and
  /// legacy messages have a null `sendBatchId` and fall back to a tuple keyed
  /// on their OWN sender, which no owner-scoped group queue row shares. A 1:1
  /// send has a unique id, but topology checks still keep it out of group
  /// aggregation.
  static String _batchKeyOfMessage(DmMessage m) =>
      m.sendBatchId ?? '${m.senderPubkey}|${m.createdAt}|${m.content}';

  /// The fan-out batch containing [id] — a durable queue handle, wire rumor
  /// id, or persisted message id.
  ///
  /// A group send enqueues one queue row PER RECIPIENT for one logical
  /// message; every sibling carries the same durable `sendBatchId`
  /// ([_batchKeyOf]). Batch membership additionally requires a group-shaped
  /// conversation id (`_isGroupRow`), so an incoming persisted message can
  /// never aggregate someone else's bubble, and two distinct group sends of
  /// identical text — even in the same second — stay independent because
  /// their batch ids differ.
  List<OutgoingDm> _siblingRowsFor(String id) {
    if (pendingOutgoing.isEmpty) return const [];
    final row = _outgoingByRumorId[id];
    if (row != null && !_isGroupRow(row)) return [row];
    final String key;
    if (row != null) {
      key = _batchKeyOf(row);
    } else {
      DmMessage? match;
      for (final m in messages) {
        if (m.id == id) {
          match = m;
          break;
        }
      }
      if (match == null) return const [];
      key = _batchKeyOfMessage(match);
    }
    return [
      for (final q in pendingOutgoing)
        if (_isGroupRow(q) && _batchKeyOf(q) == key) q,
    ];
  }

  /// Durable handles of the hard-failed queue rows in [id]'s fan-out batch —
  /// the exact set a manual Resend must replay. For a 1:1 failed bubble
  /// this is just `[id]`.
  List<String> failedSiblingRumorIdsFor(String id) => [
    for (final q in _siblingRowsFor(id))
      if (q.recipientWrapStatus == OutgoingWrapStatus.failed) q.id,
  ];

  /// Durable handles of every sibling in [id]'s fan-out batch whose recipient
  /// has NOT received the message (pending + failed) — the set a snackbar
  /// "cancel send" must drop. Deliberately EXCLUDES delivered-awaiting-
  /// self-wrap rows: those recipients already have the message, and
  /// cancelling their rows would only break the sender's own cross-device
  /// sync for a message that is being kept. (Deleting the message for
  /// everyone goes through `DmRepository.cancelOutgoingBatch` instead,
  /// which stops the whole batch.) A sibling that was already stopped is not
  /// in the set either: there is nothing left to cancel.
  List<String> undeliveredSiblingRumorIdsFor(String id) => [
    for (final q in _siblingRowsFor(id))
      if (q.recipientWrapStatus != OutgoingWrapStatus.sent &&
          q.recipientWrapStatus != OutgoingWrapStatus.cancelled)
        q.id,
  ];

  /// Delivery status for the bubble with rumor id (or persisted message
  /// id) [id]. A persisted row with no queue rows remaining is always
  /// [DmDeliveryStatus.delivered] (the repository transactionally couples
  /// queue-row deletion with persisted-row insertion).
  ///
  /// Group bubbles aggregate their whole fan-out batch, worst first:
  /// any sibling blocked → [DmDeliveryStatus.blocked]; else any sibling
  /// hard-failed → [DmDeliveryStatus.failed]; else any sibling the sender
  /// stopped → [DmDeliveryStatus.notSentToEveryone]; else any still pending →
  /// [DmDeliveryStatus.pending]; else any self-wrap failure →
  /// [DmDeliveryStatus.deliveredSelfFailed]. Failed outranks stopped because
  /// it is the one status the user can still act on, and stopped outranks
  /// pending because one member is already known not to get the message
  /// whatever the pending one does. This also lets the PERSISTED
  /// group bubble (inserted when the first recipient confirmed) surface a
  /// remaining sibling's failure as the red tap-to-resend affordance.
  DmDeliveryStatus statusFor(String id) {
    // Hot path: with no in-flight queue rows every bubble is delivered, so
    // short-circuit before building any lookup (statusFor is called per
    // bubble via a BlocSelector).
    if (pendingOutgoing.isEmpty) return DmDeliveryStatus.delivered;
    final rows = _siblingRowsFor(id);
    if (rows.isEmpty) return DmDeliveryStatus.delivered;
    var anyPending = false;
    var anySelfFailed = false;
    var anyStopped = false;
    for (final q in rows) {
      if (q.recipientWrapStatus == OutgoingWrapStatus.blocked) {
        return DmDeliveryStatus.blocked;
      }
      if (q.recipientWrapStatus == OutgoingWrapStatus.failed) {
        return DmDeliveryStatus.failed;
      }
      if (q.recipientWrapStatus == OutgoingWrapStatus.cancelled) {
        anyStopped = true;
      } else if (q.recipientWrapStatus == OutgoingWrapStatus.pending) {
        anyPending = true;
      } else if (q.selfWrapStatus == OutgoingWrapStatus.failed) {
        // recipient sent; self-wrap drives the rest of the truth table.
        anySelfFailed = true;
      }
    }
    if (anyStopped) return DmDeliveryStatus.notSentToEveryone;
    if (anyPending) return DmDeliveryStatus.pending;
    if (anySelfFailed) return DmDeliveryStatus.deliveredSelfFailed;
    return DmDeliveryStatus.delivered;
  }

  /// Merged user-visible message list: in-flight queue rows projected
  /// as [DmMessage] bubbles on top of persisted ones from [messages],
  /// sorted newest first.
  ///
  /// Returns [messages] unchanged when [pendingOutgoing] is empty (the
  /// hot path — every conversation that isn't actively mid-send).
  /// Defends against the brief tick window where a queue row and its
  /// matching persisted row appear together by letting the persisted
  /// row win on rumor-id collision. A fan-out batch (group send: one row
  /// per recipient, same content + batch timestamp) projects ONE bubble,
  /// not N — and none at all once the batch's message is persisted.
  /// Because the persisted winner is keyed to a sibling whose queue row
  /// was deleted on confirm, suppression matches the durable batch id
  /// ([_batchKeyOf]) against persisted messages, not surviving queue-row
  /// ids; [statusFor] then surfaces remaining sibling failures on the
  /// persisted bubble.
  List<DmMessage> get displayedMessages {
    if (pendingOutgoing.isEmpty) return messages;
    final persistedIds = messages.map((m) => m.id).toSet();
    final persistedBatchKeys = <String>{
      for (final m in messages) _batchKeyOfMessage(m),
    };

    final grouped = <String, List<OutgoingDm>>{};
    final pendingBubbles = <DmMessage>[];
    for (final q in pendingOutgoing) {
      // A stopped row is a record for a stored bubble, never a bubble of its
      // own: once that bubble has left the thread (a confirmed delete for
      // everyone) projecting the row would put the message back on screen.
      if (q.recipientWrapStatus == OutgoingWrapStatus.cancelled) continue;
      if (persistedIds.contains(q.rumorId)) continue;
      if (_isGroupRow(q)) {
        grouped.putIfAbsent(_batchKeyOf(q), () => []).add(q);
      } else {
        pendingBubbles.add(_outgoingToBubble(q));
      }
    }
    for (final batch in grouped.values) {
      if (persistedBatchKeys.contains(_batchKeyOf(batch.first))) {
        continue;
      }
      // Legacy rows have no wire rumor JSON and therefore expose their queue
      // handle as the bubble id; keep their representative deterministic.
      batch.sort((a, b) => a.id.compareTo(b.id));
      pendingBubbles.add(_outgoingToBubble(batch.first));
    }

    final merged = <DmMessage>[...pendingBubbles, ...messages]
      ..sort((a, b) {
        final byTime = b.createdAt.compareTo(a.createdAt);
        if (byTime != 0) return byTime;
        // Stable tiebreak when two rows share `createdAt` (second
        // resolution collides on rapid sends): lex-sort by id so the
        // pending row and the persisted row land deterministically next
        // to each other.
        return a.id.compareTo(b.id);
      });
    return List.unmodifiable(merged);
  }

  ConversationState copyWith({
    ConversationStatus? status,
    List<DmMessage>? messages,
    SendStatus? sendStatus,
    Set<String>? awaitingRetraction,
    PartialSend? lastPartialSend,
    List<OutgoingDm>? pendingOutgoing,
    bool clearLastPartialSend = false,
  }) {
    return ConversationState(
      status: status ?? this.status,
      messages: messages ?? this.messages,
      sendStatus: sendStatus ?? this.sendStatus,
      awaitingRetraction: awaitingRetraction ?? this.awaitingRetraction,
      lastPartialSend: clearLastPartialSend
          ? null
          : (lastPartialSend ?? this.lastPartialSend),
      pendingOutgoing: pendingOutgoing ?? this.pendingOutgoing,
    );
  }

  @override
  List<Object?> get props => [
    status,
    messages,
    sendStatus,
    awaitingRetraction,
    lastPartialSend,
    pendingOutgoing,
  ];
}

DmMessage _outgoingToBubble(OutgoingDm row) {
  return DmMessage(
    // Message actions (reaction, reply, delete) must address the wire rumor,
    // never the per-recipient durable queue handle used by group sends.
    id: row.rumorId,
    conversationId: row.conversationId,
    senderPubkey: row.ownerPubkey,
    content: row.content,
    createdAt: row.createdAt,
    giftWrapId: row.rumorId,
    // Carry the reply linkage so an optimistic reply bubble can resolve its
    // parent's shared video and render the quoted preview immediately, before
    // the persisted `watchMessages` tick replaces this row.
    replyToId: row.replyToId,
    // Keep the projected group bubble's own batch key well-formed.
    sendBatchId: row.sendBatchId,
  );
}
