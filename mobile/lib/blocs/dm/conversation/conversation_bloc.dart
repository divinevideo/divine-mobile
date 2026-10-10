// ABOUTME: BLoC for a single DM conversation.
// ABOUTME: Manages loading messages, sending new messages,
// ABOUTME: and real-time message streaming.

import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/reportable_sites.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:rxdart/rxdart.dart';

part 'conversation_event.dart';
part 'conversation_state.dart';

/// Tuple emitted by the dual-stream subscription in [_onStarted]. Carries
/// both reactive slices through a single [emit.forEach] so the
/// `restartable()` transformer keeps lifecycle handling identical to the
/// previous single-stream shape.
class _ConversationTick extends Equatable {
  const _ConversationTick(this.messages, this.pendingOutgoing);

  final List<DmMessage> messages;
  final List<OutgoingDm> pendingOutgoing;

  @override
  List<Object?> get props => [messages, pendingOutgoing];
}

class ConversationBloc extends Bloc<ConversationEvent, ConversationState> {
  ConversationBloc({
    required DmRepository dmRepository,
    required String conversationId,
  }) : _dmRepository = dmRepository,
       _conversationId = conversationId,
       super(const ConversationState()) {
    on<ConversationStarted>(_onStarted, transformer: restartable());
    // Sends are optimistic and independent per rumor: `sequential()` made
    // one slow OK-confirm (tens of seconds on a slow relay / remote signer)
    // queue every later send BEHIND it, so the next message's bubble did
    // not even appear until the previous publish finished. The repository
    // enqueues each row before any signer round-trip, so concurrent
    // handlers stay per-rumor isolated; `sendStatus` is last-writer-wins,
    // which only drives the bubble-less toasts (blocked / partial).
    on<ConversationMessageSent>(_onMessageSent, transformer: concurrent());
    // `droppable()` here dropped a delete for message B whenever a delete
    // for message A was still in flight: bloc_concurrency's droppable
    // discards on subscription state alone and never inspects the payload,
    // so the rumor id was irrelevant. The handler awaits a signer round trip
    // (measured 215-493ms against Keycast) plus a relay publish that can
    // first await `retryDisconnectedRelays()`, so deleting a short burst of
    // messages retracted only the first — silently, since no path here
    // emits. `sequential()` queues them instead; a same-rumor repeat is
    // idempotent because `deleteMessageForEveryone` returns early on an
    // already soft-deleted row. Head-of-line blocking is the accepted cost
    // and is why this is not `concurrent()`: concurrent handlers would race
    // that same-rumor guard and publish two kind-5s for one message.
    on<ConversationMessageDeleted>(
      _onMessageDeleted,
      transformer: sequential(),
    );
    on<ConversationMessageDeletionRetryRequested>(
      _onMessageDeletionRetryRequested,
      transformer: sequential(),
    );
    on<ConversationSelfWrapRecoveryRequested>(
      _onSelfWrapRecoveryRequested,
      transformer: sequential(),
    );
    on<ConversationFullSendRecoveryRequested>(
      _onFullSendRecoveryRequested,
      transformer: sequential(),
    );
    on<ConversationOutgoingSendCancelled>(
      _onOutgoingSendCancelled,
      transformer: sequential(),
    );
  }

  final DmRepository _dmRepository;
  final String _conversationId;

  Future<void> _onStarted(
    ConversationStarted event,
    Emitter<ConversationState> emit,
  ) async {
    emit(state.copyWith(status: ConversationStatus.loading));

    // Stay in loading until the repository knows whose messages to read.
    // Signed-out and teardown repositories have no storage owner, and since
    // #8187 owner-scoped reads correctly return nothing there rather than
    // every account's rows. Subscribing anyway would tick immediately empty
    // list and render the "new conversation" card over a thread that has
    // history — `mayBeIncomplete` fails open to false while uncredentialed,
    // so nothing would even qualify it. `ConversationPage` re-keys this bloc
    // on `(dmRepository, currentPubkey)`, so a later authenticated identity
    // rebuilds it and re-dispatches this event against an owner-scoped instance.
    if (_dmRepository.userPubkey.isEmpty) return;

    // Arm the one-time history drain here too, not just on inbox open.
    // Profile → Message reaches a thread without ever passing through
    // Messages, so on a reinstall this can be the first DM surface the user
    // touches. Until the drain arms, `hasAttemptedHistoryRecovery` is false
    // and an empty thread reports itself complete while the user's history is
    // still sitting on the relay. Idempotent, resumable and shared with the
    // inbox's call, so arriving from either entry point costs one drain.
    // See #4953.
    unawaited(_dmRepository.backfillHistoryIfNeeded());

    // Mark as read when opening
    await _dmRepository.markConversationAsRead(_conversationId);

    // Dual-stream projection (#3909). `watchMessages` carries persisted
    // truth; `watchOutgoing` carries the durable in-flight queue. The
    // repository's `sendMessage` enqueues a queue row before any signer
    // round-trip, so the in-flight bubble survives both the watch-stream
    // race that #4193 patched AND an app kill mid-send (the latter is
    // the epic #3912 acceptance criterion the previous in-memory slice
    // could not meet).
    final ticks =
        Rx.combineLatest2<List<DmMessage>, List<OutgoingDm>, _ConversationTick>(
          _dmRepository.watchMessages(_conversationId),
          _dmRepository.watchOutgoing(_conversationId),
          _ConversationTick.new,
        );

    await emit.forEach(
      ticks,
      onData: (tick) {
        // Mark as read only when this conversation's persisted message list
        // actually changed — a new (or edited/removed) message — not on ticks
        // driven solely by the outgoing-queue stream or a bare re-emit.
        //
        // Every tick previously fired markConversationAsRead, and the DAO's
        // conversations-table notification fans out to the badge cubit and the
        // list bloc even when no row changed, so each outgoing-status
        // transition (pending → sent → delivered) and re-emit forced a
        // redundant recompute. A genuinely new incoming message always changes
        // `messages`, so this never leaves an unread uncleared while the
        // conversation is open. `combineLatest2` re-emits the same `messages`
        // instance on an outgoing-only tick, so the `identical` fast-path keeps
        // that common case O(1).
        if (!_sameMessages(tick.messages, state.messages)) {
          unawaited(_dmRepository.markConversationAsRead(_conversationId));
        }
        final refused = _refusedRetractions(tick.messages);
        final confirmed = _confirmedRetractions(tick.messages);
        final completed = {...refused, ...confirmed};
        return state.copyWith(
          status: ConversationStatus.loaded,
          messages: tick.messages,
          pendingOutgoing: tick.pendingOutgoing,
          awaitingRetraction: completed.isEmpty
              ? state.awaitingRetraction
              : state.awaitingRetraction.difference(completed),
        );
      },
      onError: (error, stackTrace) {
        // Drift / rxdart stream IO failures are expected here. Per
        // .claude/rules/error_handling.md they are NOT Reportable.
        addError(error, stackTrace);
        return state.copyWith(status: ConversationStatus.error);
      },
    );
  }

  /// Whether two persisted-message lists carry the same messages in the same
  /// order. `DmMessage` is `Equatable`, so element comparison is by value.
  /// The `identical` fast-path keeps the common outgoing-only tick O(1).
  static bool _sameMessages(List<DmMessage> a, List<DmMessage> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Retractions that came back refused on this tick (#8201): messages in
  /// [next] that changed from an ordinary/pending bubble to a failed
  /// retraction. Restricting them to what this screen asked for is the set
  /// difference at the call site, so a pre-existing failure stays quiet when
  /// a thread opens.
  Set<String> _refusedRetractions(List<DmMessage> next) {
    if (state.awaitingRetraction.isEmpty) return const {};
    final previousById = {for (final m in state.messages) m.id: m};
    return {
      for (final message in next)
        if (message.retractionStatus == DmRetractionStatus.failed &&
            previousById[message.id]?.retractionStatus !=
                DmRetractionStatus.failed)
          message.id,
    };
  }

  /// Retractions confirmed by the bubble leaving the visible projection.
  /// Pending rows remain visible, so absence after a visible/pending tick is
  /// the terminal sent transition rather than the old optimistic hide.
  Set<String> _confirmedRetractions(List<DmMessage> next) {
    if (state.awaitingRetraction.isEmpty) return const {};
    final previousIds = {for (final message in state.messages) message.id};
    final nextIds = {for (final message in next) message.id};
    return state.awaitingRetraction
        .where(previousIds.contains)
        .where((id) => !nextIds.contains(id))
        .toSet();
  }

  Future<void> _onMessageDeletionRetryRequested(
    ConversationMessageDeletionRetryRequested event,
    Emitter<ConversationState> emit,
  ) async {
    emit(
      state.copyWith(
        awaitingRetraction: {...state.awaitingRetraction, event.rumorId},
      ),
    );

    DmMessageDeletionOutcome outcome;
    try {
      outcome = await _dmRepository.retryMessageDeletion(
        rumorId: event.rumorId,
      );
    } on Object catch (e, stackTrace) {
      addError(e, stackTrace);
      outcome = DmMessageDeletionOutcome.unavailable;
    }

    // Every other outcome moves the row, so the bubble's own pending-to-failed
    // transition both tells the user and releases the armed id. `unavailable`
    // moves nothing — no signer, no row, no recipient — so without this the
    // tap produces no spinner, no toast and no error, and the id stays armed
    // for the life of the bloc.
    if (outcome == DmMessageDeletionOutcome.unavailable) {
      emit(
        state.copyWith(
          awaitingRetraction: {...state.awaitingRetraction}
            ..remove(event.rumorId),
        ),
      );
    }
  }

  Future<void> _onMessageDeleted(
    ConversationMessageDeleted event,
    Emitter<ConversationState> emit,
  ) async {
    // Remember what we asked for before the repository starts the attempt, so
    // the pending-to-failed transition can announce this user action (#8201).
    emit(
      state.copyWith(
        awaitingRetraction: {...state.awaitingRetraction, event.rumorId},
      ),
    );

    // Drop every durable queue row of the bubble's batch first, whether the
    // bubble is queue-only (optimistic/failed — no persisted row yet, so the
    // kind-5 path below would no-op and the "deleted" bubble would keep
    // re-sending via the sweep) or persisted with sibling retry rows still
    // alive. A group bubble carries the persisted winner's rumor id whose
    // own row is already gone — cancelling just that id would leave the
    // pending and failed siblings for the sweep to re-publish, so the
    // repository resolves and cancels the WHOLE batch.
    var cancelledQueueRow = false;
    try {
      cancelledQueueRow =
          await _dmRepository.cancelOutgoingBatch(rumorId: event.rumorId) > 0;
    } on Object catch (e, stackTrace) {
      // StateError = queue DAO not wired (legacy fixtures); ArgumentError =
      // foreign-owner row. Neither blocks the kind-5 delete below.
      if (e is! StateError && e is! ArgumentError) {
        addError(e, stackTrace);
      }
    }

    try {
      await _dmRepository.deleteMessageForEveryone(event.rumorId);
      // The watchMessages stream automatically excludes deleted messages,
      // so the UI updates reactively — no manual state mutation needed.
    } on Object catch (e, stackTrace) {
      if (e is ArgumentError) {
        // No persisted row. For a queue-only bubble whose row we just
        // cancelled this is the EXPECTED outcome, not an error.
        if (cancelledQueueRow) {
          _releaseAwaitingRetraction(emit, event.rumorId);
          return;
        }
        // Rumor gone or not ours — recoverable; matrix-NO.
        addError(e, stackTrace);
        _releaseAwaitingRetraction(emit, event.rumorId);
        return;
      }
      // Anything else (e.g. the uninitialized-repository `StateError`) is
      // an invariant violation — matrix-YES. Signing no longer throws here:
      // the wrap is built and published on the repository's retry-backed
      // drive, so a signer failure leaves a pending row instead.
      addError(
        Reportable(
          e,
          context: ConversationBlocReportableSites.onMessageDeleted,
        ),
        stackTrace,
      );
      _releaseAwaitingRetraction(emit, event.rumorId);
    }
  }

  void _releaseAwaitingRetraction(
    Emitter<ConversationState> emit,
    String rumorId,
  ) {
    if (!state.awaitingRetraction.contains(rumorId)) return;
    emit(
      state.copyWith(
        awaitingRetraction: {...state.awaitingRetraction}..remove(rumorId),
      ),
    );
  }

  Future<void> _onMessageSent(
    ConversationMessageSent event,
    Emitter<ConversationState> emit,
  ) async {
    // The in-flight bubble lives in `state.pendingOutgoing`, sourced
    // from `DmRepository.watchOutgoing`. `sendMessage` enqueues the row
    // before any signer round-trip, so the watch tick that carries the
    // optimistic lands within microseconds of dispatch — without any
    // bloc-side in-memory tracking. This handler is responsible only
    // for transient `sendStatus` transitions and the partial-delivery
    // SnackBar affordance state (`lastPartialSend`).
    // Deliberately does NOT clear lastPartialSend: with the concurrent()
    // transformer, send B's `sending` emit can land between send A's
    // sentPartial and B's own — an eager clear here wiped A's rumor ids
    // before the partial union below could fold them in. Outstanding ids
    // self-heal: recovery drops recovered/removed rows (ArgumentError →
    // skipped), and a full recovery success clears the whole snapshot.
    emit(state.copyWith(sendStatus: SendStatus.sending));

    // #7335. An empty list fails the single-recipient test below and takes the
    // group branch, where `sendGroupMessage` throws ArgumentError before
    // enqueuing anything. The catch turned that into `failed`, whose only
    // affordance is the red "Not delivered" bubble — but with no queue row
    // `statusFor` short-circuits to `delivered` and no bubble is ever built,
    // so the send failed in complete silence. Refuse it here instead, with a
    // status the view can toast — a backstop rather than a reachable path:
    // `_SendBarBody`, the only dispatcher of `ConversationMessageSent`, is
    // built only for `DmThreadWritability.writable`, which requires
    // participants.
    if (event.recipientPubkeys.isEmpty) {
      emit(state.copyWith(sendStatus: SendStatus.noRecipient));
      return;
    }

    try {
      // Partial-delivery: recipient got the message and DmRepository
      // persisted it locally, but the self-addressed gift wrap did not
      // reach relays. The sender's other devices will not see this
      // message on relay-only restore. Surface as a distinct status so
      // the UI can offer a self-wrap-only retry without re-delivering
      // to the recipient. [lastPartialSend.rumorIds] carries the durable queue
      // handles whose self-wrap publish failed, so
      // retrying republishes only those self-wraps via
      // [recoverSelfWrap].
      final partialRumorIds = <String>[];
      if (event.recipientPubkeys.length == 1) {
        final result = await _dmRepository.sendMessage(
          recipientPubkey: event.recipientPubkeys.first,
          content: event.content,
        );
        if (!result.success) {
          if (result.blocked) {
            // Protected-minor DM restriction (#176): refused, not retriable.
            emit(state.copyWith(sendStatus: SendStatus.blocked));
            return;
          }
          if (result.retryablePending) {
            // Soft-unconfirmed: the recipient frame was written but no NIP-20
            // OK arrived yet. The durable queue keeps the plain optimistic
            // bubble and the retry sweep re-drives it — a lost OK is not proof
            // of loss, so surface no red failure. Treat as optimistically
            // sent.
            emit(state.copyWith(sendStatus: SendStatus.sent));
            return;
          }
          if (result.tooLong) {
            // Refused before the enqueue, so no queue row and no bubble will
            // exist to show the failure. Emit a distinct status the view can
            // turn into a visible message and a preserved draft (#7331).
            emit(state.copyWith(sendStatus: SendStatus.tooLong));
            return;
          }
          throw Exception(result.error ?? 'Failed to send message');
        }
        if (result.selfWrapPublished == false) {
          partialRumorIds.add(result.queuedRumorId ?? result.rumorEventId!);
        }
      } else {
        final results = await _dmRepository.sendGroupMessage(
          recipientPubkeys: event.recipientPubkeys,
          content: event.content,
        );
        if (!results.any((r) => r.success)) {
          if (results.isNotEmpty && results.every((r) => r.blocked)) {
            // Group all-or-nothing block (#176): refused, not retriable.
            emit(state.copyWith(sendStatus: SendStatus.blocked));
            return;
          }
          if (results.isNotEmpty && results.every((r) => r.tooLong)) {
            // Every sibling was refused before enqueueing the shared rumor.
            // No queue row or failure bubble exists, so preserve the draft
            // through the same terminal outcome as the 1:1 path (#7331).
            emit(state.copyWith(sendStatus: SendStatus.tooLong));
            return;
          }
          // No recipient confirmed. If every unconfirmed recipient is soft
          // (frame written, OK pending) with no hard failure, treat the group
          // send as optimistically sent — the durable queue re-drives each
          // pending row. Only a genuine hard failure raises the red SnackBar.
          final anyHard = results.any(
            (r) => !r.success && !r.blocked && !r.retryablePending,
          );
          if (!anyHard && results.any((r) => r.retryablePending)) {
            emit(state.copyWith(sendStatus: SendStatus.sent));
            return;
          }
          throw Exception(
            results.first.error ?? 'Failed to send group message',
          );
        }
        // For groups, "self-wrap" is per-recipient. Recovery needs each
        // surviving durable queue handle, not the shared wire rumor id.
        for (final result in results) {
          if (result.success && result.selfWrapPublished == false) {
            partialRumorIds.add(result.queuedRumorId ?? result.rumorEventId!);
          }
        }
      }
      if (partialRumorIds.isNotEmpty) {
        // Union with any outstanding partial: two concurrent sends that
        // both end sentPartial must accumulate their queue handles — the
        // second overwrite silently orphaned the first send's self-wrap
        // recovery set. Stale ids (already recovered by the sweep) are
        // dropped by the recovery handler's ArgumentError-skip.
        final unioned = <String>{
          ...?state.lastPartialSend?.rumorIds,
          ...partialRumorIds,
        };
        emit(
          state.copyWith(
            sendStatus: SendStatus.sentPartial,
            lastPartialSend: PartialSend(rumorIds: unioned.toList()),
          ),
        );
        return;
      }
      emit(state.copyWith(sendStatus: SendStatus.sent));
    } catch (e, stackTrace) {
      // Dominated by the explicit `throw Exception(result.error)` above
      // and repo IO — per .claude/rules/error_handling.md, matrix-NO.
      addError(e, stackTrace);
      emit(state.copyWith(sendStatus: SendStatus.failed));
      // The repository has just marked the queue row `failed`, but the
      // watchOutgoing tick that carries that transition back can be dropped
      // when it fires while this handler is still in flight — so the red
      // "Not delivered" bubble would not repaint until the conversation is
      // re-opened. Re-read the rows and emit them directly so the failed
      // bubble surfaces immediately.
      await _refreshPendingOutgoing(emit);
    }
    // The in-flight queue row remains in `state.pendingOutgoing` on
    // failure/partial. The retry service (`OutgoingDmRetryService`) sweeps it
    // independently, and the failed bubble is tappable (resend/delete) — so
    // there is no failed toast; a partial self-wrap recovery is offered via
    // `lastPartialSend`.
  }

  /// Re-read the durable queue rows and emit them straight into
  /// [ConversationState.pendingOutgoing].
  ///
  /// The repository writes a send's terminal status (row → `failed`, or the
  /// row's removal on success) to `outgoing_dms`, and `watchOutgoing` normally
  /// carries it back reactively. But when that write lands while a send event
  /// handler is still in flight, the bloc's dual-stream subscription can miss
  /// the resulting tick, leaving the bubble showing its stale (pre-failure)
  /// status until the conversation is re-opened. Re-reading here, from the
  /// handler's own emitter, repaints it immediately and idempotently — a later
  /// watch tick simply re-emits the same rows.
  Future<void> _refreshPendingOutgoing(Emitter<ConversationState> emit) async {
    try {
      final rows = await _dmRepository.getOutgoing(_conversationId);
      emit(state.copyWith(pendingOutgoing: rows));
    } on Object catch (e, stackTrace) {
      // A refresh miss just defers the repaint to the next watch tick or the
      // conversation re-open; it is never itself a send failure. Matrix-NO.
      addError(e, stackTrace);
    }
  }

  Future<void> _onSelfWrapRecoveryRequested(
    ConversationSelfWrapRecoveryRequested event,
    Emitter<ConversationState> emit,
  ) async {
    if (event.rumorIds.isEmpty) return;

    emit(state.copyWith(sendStatus: SendStatus.sending));

    final stillFailing = <String>[];
    Object? lastError;
    StackTrace? lastStackTrace;

    for (final rumorId in event.rumorIds) {
      try {
        final result = await _dmRepository.recoverSelfWrap(rumorId: rumorId);
        if (!result.success) {
          stillFailing.add(rumorId);
        }
      } on Object catch (e, stackTrace) {
        if (e is ArgumentError) {
          // The row was already removed or is no longer valid for this
          // account. Treat it as terminal and drop it from the retry set.
          continue;
        }

        // Missing DAO wiring is an invariant failure; any other throw
        // is unexpected. Preserve retryability and surface it for
        // telemetry.
        stillFailing.add(rumorId);
        lastError = e;
        lastStackTrace = stackTrace;
      }
    }

    if (lastError != null) {
      addError(
        Reportable(
          lastError,
          context: ConversationBlocReportableSites.onSelfWrapRecoveryRequested,
        ),
        lastStackTrace,
      );
    }

    // Reduce lastPartialSend by this recovery's outcome while PRESERVING
    // ids a concurrent partial send unioned in mid-recovery: remove the
    // ids this pass attempted, re-add the ones still failing. A plain
    // `PartialSend(stillFailing)` overwrite clobbered the concurrent set.
    final remaining = <String>{...?state.lastPartialSend?.rumorIds}
      ..removeAll(event.rumorIds)
      ..addAll(stillFailing);

    if (remaining.isEmpty) {
      emit(
        state.copyWith(sendStatus: SendStatus.sent, clearLastPartialSend: true),
      );
    } else {
      // A second Retry tap targets exactly the outstanding rumors —
      // never the ones that already recovered.
      emit(
        state.copyWith(
          sendStatus: SendStatus.sentPartial,
          lastPartialSend: PartialSend(rumorIds: remaining.toList()),
        ),
      );
    }
  }

  Future<void> _onFullSendRecoveryRequested(
    ConversationFullSendRecoveryRequested event,
    Emitter<ConversationState> emit,
  ) async {
    if (event.rumorIds.isEmpty) return;

    emit(state.copyWith(sendStatus: SendStatus.sending));

    final stillFailing = <String>[];
    Object? lastError;
    StackTrace? lastStackTrace;

    for (final rumorId in event.rumorIds) {
      try {
        // Replay the SAME rumor from the durable row — never a fresh send —
        // so the receiver dedups on the stable rumor id. A soft-unconfirmed
        // replay (retryablePending) counts as STILL FAILING: manual-resend
        // targets are `failed` queue rows, and the soft finalize only bumps
        // the retry counter without rewriting wrap statuses, so the row —
        // and its red bubble — remain failed. Reporting `sent` for it
        // claimed a delivery nothing confirmed while the bubble stayed red
        // (the "resend swallows the failed message" report on #6046). The
        // sweep keeps re-driving the row either way; resetRetryBudget hands
        // it back with a fresh budget when soft attempts already exhausted
        // the sweep's cap — an explicit resend must re-arm the sweep, not
        // get one last manual-only attempt.
        final result = await _dmRepository.recoverFullSend(
          rumorId: rumorId,
          resetRetryBudget: true,
        );
        if (!result.success) {
          stillFailing.add(rumorId);
        }
      } on Object catch (e, stackTrace) {
        if (e is ArgumentError) {
          // Row already recovered/removed or belongs to another account —
          // terminal for this id, drop it from the retry set.
          continue;
        }
        stillFailing.add(rumorId);
        lastError = e;
        lastStackTrace = stackTrace;
      }
    }

    if (lastError != null) {
      addError(
        Reportable(
          lastError,
          context: ConversationBlocReportableSites.onFullSendRecoveryRequested,
        ),
        lastStackTrace,
      );
    }

    if (stillFailing.isEmpty) {
      emit(state.copyWith(sendStatus: SendStatus.sent));
    } else {
      // Some rows are still hard-failing. They remain `failed` in the queue
      // (red bubbles) and are re-tappable to resend. Re-raising `failed` here
      // would leave the UI byte-identical to before the tap — the bubble was
      // already red — so the resend reads as a tap that did nothing (#8461).
      // `resendFailed` carries that the attempt happened and lost, which is
      // the part the red bubble cannot express a second time.
      emit(state.copyWith(sendStatus: SendStatus.resendFailed));
    }
    // Reflect the recovery's queue-row transitions (a row re-marked `failed`,
    // or deleted on success) immediately — a watch tick fired mid-handler can
    // be dropped, same as the initial send path.
    await _refreshPendingOutgoing(emit);
  }

  Future<void> _onOutgoingSendCancelled(
    ConversationOutgoingSendCancelled event,
    Emitter<ConversationState> emit,
  ) async {
    try {
      // Stop the durable row. The next watch tick either drops the failed
      // bubble or, for a stored group message, re-labels it as not sent to
      // everyone. No status emit — the bubble's own change speaks for itself.
      await _dmRepository.cancelOutgoingSend(rumorId: event.rumorId);
    } on Object catch (e, stackTrace) {
      // A foreign-owner row surfaces as ArgumentError — terminal and expected,
      // so it is not Reportable (matrix-NO). Anything else is unexpected.
      if (e is ArgumentError) return;
      addError(
        Reportable(
          e,
          context: ConversationBlocReportableSites.onOutgoingSendCancelled,
        ),
        stackTrace,
      );
    }
  }
}
