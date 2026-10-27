// ABOUTME: Cubit for the in-player reel reply composer (text replies that
// ABOUTME: thread under a reel shared into a DM). Reactions use the reactions
// ABOUTME: cubit; this owns only the text-reply publish lifecycle.

import 'dart:async';

import 'package:dm_repository/dm_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/dm/inline_reel_reply/reportable_sites.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:openvine/screens/feed/dm_reply_context.dart';
import 'package:unified_logger/unified_logger.dart';

part 'inline_reel_reply_state.dart';

/// Owns the publish flow for a text reply sent from the in-player reel reply
/// bar. The reply is an ordinary kind-14 DM threaded under the shared-reel
/// message (1:1 or group). Holds only a lifecycle status — the composed text
/// lives in the View's [TextEditingController].
class InlineReelReplyCubit extends Cubit<InlineReelReplyState> {
  /// Construct the cubit bound to [replyContext] (the DM the reel came from).
  InlineReelReplyCubit({
    required DmRepository dmRepository,
    required DmReplyContext replyContext,
  }) : _dmRepository = dmRepository,
       _replyContext = replyContext,
       super(const InlineReelReplyState());

  final DmRepository _dmRepository;
  final DmReplyContext _replyContext;

  /// Send [content] as a reply threaded under the shared reel.
  ///
  /// Trims/validates locally; empty submissions are a no-op. A send already
  /// in flight is dropped (double-send guard). Failures surface via a status
  /// enum + [addError]; the durable outgoing-DM queue owns the actual retry.
  ///
  /// A failure records the rows this send left parked in
  /// [InlineReelReplyState.queuedRumorIds], so [retry] can re-drive them.
  /// Calling this method again is a *new message*, never a retry — see
  /// [retry] for why that distinction matters.
  Future<void> submit(String content) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return;
    if (state.status == InlineReelReplyStatus.sending) return;

    emit(state.copyWith(status: InlineReelReplyStatus.sending));

    try {
      final bool ok;
      final bool tooLong;
      final List<String> parked;
      // When the reel has a structured video ref, the reply self-carries the
      // NIP-18 `q` citation so it stays linked to the video across devices and
      // other Nostr clients; otherwise it threads as a plain reply.
      final videoRef = _replyContext.sharedVideoRef;
      if (_replyContext.isGroup) {
        final results = videoRef != null
            ? await _dmRepository.sendSharedVideoGroup(
                backgroundDelivery: true,
                recipientPubkeys: _replyContext.participantPubkeys,
                baseContent: trimmed,
                videoKind: videoRef.videoKind.kind,
                videoAuthorPubkey: videoRef.authorPubkey ?? '',
                videoDTag: videoRef.dTag,
                videoEventId: videoRef.eventId,
                relayHint: videoRef.relayHint,
                replyToId: _replyContext.sharedReelMessageId,
              )
            : await _dmRepository.sendGroupMessage(
                backgroundDelivery: true,
                recipientPubkeys: _replyContext.participantPubkeys,
                content: trimmed,
                replyToId: _replyContext.sharedReelMessageId,
              );
        ok =
            results.any((r) => r.success) ||
            (results.isNotEmpty && results.every((r) => r.retryablePending));
        tooLong =
            results.isNotEmpty && results.every((result) => result.tooLong);
        parked = [for (final r in results) ?r.queuedRumorId];
      } else {
        final result = videoRef != null
            ? await _dmRepository.sendSharedVideo(
                backgroundDelivery: true,
                recipientPubkey: _replyContext.participantPubkeys.single,
                baseContent: trimmed,
                videoKind: videoRef.videoKind.kind,
                videoAuthorPubkey: videoRef.authorPubkey ?? '',
                videoDTag: videoRef.dTag,
                videoEventId: videoRef.eventId,
                relayHint: videoRef.relayHint,
                replyToId: _replyContext.sharedReelMessageId,
              )
            : await _dmRepository.sendMessage(
                backgroundDelivery: true,
                recipientPubkey: _replyContext.participantPubkeys.single,
                content: trimmed,
                replyToId: _replyContext.sharedReelMessageId,
              );
        ok = result.success || result.retryablePending;
        tooLong = result.tooLong;
        parked = [?result.queuedRumorId];
      }
      if (!isClosed) {
        emit(
          state.copyWith(
            status: tooLong
                ? InlineReelReplyStatus.tooLong
                : ok
                ? InlineReelReplyStatus.success
                : InlineReelReplyStatus.failure,
            // Nothing left to re-drive on success: a fully delivered send
            // consumes its row, and a partially delivered group's surviving
            // siblings belong to the sweep, not to a user-facing retry.
            queuedRumorIds: ok || tooLong ? const [] : parked,
          ),
        );
      }
    } catch (error, stackTrace) {
      Log.error(
        'Reel reply send failed',
        name: 'InlineReelReplyCubit',
        category: LogCategory.ui,
        error: error,
        stackTrace: stackTrace,
      );
      // Programming-invariant violations (StateError/TypeError — e.g. the
      // repository wasn't initialized) are Reportable; network / IO /
      // validation failures are expected domain errors and are NOT.
      if (error is Error) {
        addError(
          Reportable(error, context: InlineReelReplyReportableSites.submit),
          stackTrace,
        );
      } else {
        addError(error, stackTrace);
      }
      if (!isClosed) {
        // No handle to offer, and none is being dropped: the repository's
        // throwing paths (uninitialized repo, invalid pubkey, empty content,
        // the send-policy gate) all run *before* the enqueue, the 1:1 enqueue
        // is a single write with nothing parked ahead of it, and the group
        // enqueue loop catches per sibling rather than escaping with rows
        // already parked. So a throw leaves no row behind and [retry]'s
        // fresh-send fallback cannot duplicate anything.
        emit(
          state.copyWith(
            status: InlineReelReplyStatus.failure,
            queuedRumorIds: const [],
          ),
        );
      }
    }
  }

  /// Re-drive the rows the last failed send left parked, rather than sending
  /// again.
  ///
  /// This is the whole point of the distinction from [submit]. A NIP-17 send
  /// is identified by its kind-14 rumor id, and that id is a hash over the
  /// rumor's `created_at` — so calling [submit] a second time mints a *new*
  /// rumor for the same text. The original row is still parked and the
  /// background sweep re-publishes it under its original id, so the recipient
  /// receives two events it has no way to collapse: gift-wrap ids are freshly
  /// randomised per wrap, NIP-44 ciphertext is nonce-randomised, and the
  /// receiver's only stable dedup key is the rumor id. Re-driving the same row
  /// through `recoverFullSend` replays the *same* rumor, which the receiver
  /// does collapse. See #7316.
  ///
  /// Every parked row is attempted, and the outcome is the worst one seen:
  /// [InlineReelReplyStatus.failure] while any row is still outstanding (the
  /// retry affordance stays up and narrows to those rows), otherwise
  /// [InlineReelReplyStatus.unverifiable] if any row had already gone, and
  /// [InlineReelReplyStatus.success] only when every row was delivered.
  ///
  /// [queuedRumorIds] is the set the *failing send this retry belongs to*
  /// parked, captured by the caller when it offered the affordance — not read
  /// back off the live state. A retry affordance can outlive its own send (a
  /// snackbar queued behind another one is never dismissed by the success
  /// path, which can only close a visible one), and by then the state has
  /// moved on: a later successful send clears `queuedRumorIds` because *it*
  /// left nothing parked. Reading the live value there would find it empty,
  /// fall through to [submit], and mint a second rumor for a row the sweep is
  /// still re-driving — this bug, through a different door.
  ///
  /// [content] is used only for the fallback when nothing was parked — see
  /// [InlineReelReplyState.queuedRumorIds].
  Future<void> retry({
    required List<String> queuedRumorIds,
    required String content,
  }) async {
    if (state.status == InlineReelReplyStatus.sending) return;
    final parked = queuedRumorIds;
    if (parked.isEmpty) return submit(content);

    emit(state.copyWith(status: InlineReelReplyStatus.sending));

    final stillParked = <String>[];
    var unverifiable = 0;
    Object? lastError;
    StackTrace? lastStackTrace;

    for (final rumorId in parked) {
      try {
        // `resetRetryBudget` re-arms a row whose soft-unconfirmed attempts
        // already spent the sweep's budget: an explicit user retry is the
        // signal to hand it back, matching ConversationBloc's resend.
        final result = await _dmRepository.recoverFullSend(
          rumorId: rumorId,
          resetRetryBudget: true,
        );
        if (!result.success) stillParked.add(rumorId);
      } on Object catch (error, stackTrace) {
        if (error is ArgumentError) {
          // The row is gone — delivered by the sweep, cancelled by the user,
          // or owned by another account. Terminal for this id either way, and
          // deliberately NOT retried as a fresh send: we cannot prove the
          // original did not land, so minting a replacement risks the exact
          // duplicate this method exists to prevent. Nor is it a delivery we
          // may claim, so it downgrades the whole retry to `unverifiable`.
          unverifiable++;
          continue;
        }
        // Per-sibling, like ConversationBloc's recovery loop: one bad row
        // must not skip the siblings after it, each of which owns a separate
        // parked copy the sweep would otherwise be left to re-drive alone.
        stillParked.add(rumorId);
        lastError = error;
        lastStackTrace = stackTrace;
      }
    }

    if (lastError != null) {
      Log.error(
        'Reel reply retry failed',
        name: 'InlineReelReplyCubit',
        category: LogCategory.ui,
        error: lastError,
        stackTrace: lastStackTrace,
      );
      // Same split as submit: a StateError here means the queue DAO was never
      // wired into the repository, which is a programming invariant.
      if (lastError is Error) {
        addError(
          Reportable(lastError, context: InlineReelReplyReportableSites.retry),
          lastStackTrace,
        );
      } else {
        addError(lastError, lastStackTrace);
      }
    }

    if (isClosed) return;
    emit(
      state.copyWith(
        // All-succeeded, matching ConversationBloc: any sibling still parked
        // keeps the retry affordance up, and it targets exactly those rows.
        // Reporting success off one lucky sibling would retire the affordance
        // while the rest were still undelivered.
        status: stillParked.isNotEmpty
            ? InlineReelReplyStatus.failure
            : unverifiable > 0
            ? InlineReelReplyStatus.unverifiable
            : InlineReelReplyStatus.success,
        // A further retry targets exactly the rows still outstanding.
        queuedRumorIds: stillParked,
      ),
    );
  }

  /// Reset to [InlineReelReplyStatus.initial] after the View shows the
  /// success/failure confirmation, so the next send starts clean.
  ///
  /// Deliberately preserves [InlineReelReplyState.queuedRumorIds]: the View
  /// acknowledges as soon as it has shown the failure snackbar, and the retry
  /// action on that snackbar fires afterwards.
  void acknowledge() {
    if (state.status == InlineReelReplyStatus.initial) return;
    emit(state.copyWith(status: InlineReelReplyStatus.initial));
  }
}
