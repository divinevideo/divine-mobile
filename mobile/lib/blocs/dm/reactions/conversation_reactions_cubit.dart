// ABOUTME: Cubit for DM reactions in one conversation.
// ABOUTME: Wraps the optimistic publish flow + Drift subscription.
// ABOUTME: Per the error-handling matrix, publish failures call
// ABOUTME: addError without Reportable wrapping (network/IO class).

import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:collection/collection.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/reactions/reportable_sites.dart';

part 'conversation_reactions_event.dart';
part 'conversation_reactions_state.dart';

/// Bloc for emoji reactions on DM messages within one conversation.
///
/// Named "cubit" by convention with other DM blocs, but extends [Bloc]
/// so the optimistic publish flow can use `sequential()` to serialize
/// rapid-tap toggle events without dropping any.
class ConversationReactionsCubit
    extends Bloc<ConversationReactionsEvent, ConversationReactionsState> {
  /// Construct a cubit. [ownerPubkey] is the account viewing this
  /// conversation; it's used to detect own reactions for the toggle-off
  /// path and for the `pending` map's local-status semantics.
  ConversationReactionsCubit({
    required DmReactionsRepository reactionsRepository,
    required String ownerPubkey,
    DateTime Function()? now,
  }) : _reactionsRepository = reactionsRepository,
       _ownerPubkey = ownerPubkey,
       _now = now ?? DateTime.now,
       super(const ConversationReactionsState()) {
    on<ConversationReactionsStarted>(_onStarted, transformer: restartable());
    on<ConversationReactionToggled>(_onToggled, transformer: sequential());
    on<ConversationReactionSet>(_onSet, transformer: sequential());
    on<ConversationReactionRetryRequested>(
      _onRetryRequested,
      transformer: sequential(),
    );
    on<ConversationReactionRemovalRetryRequested>(
      _onRemovalRetryRequested,
      transformer: sequential(),
    );
    on<_ConversationReactionsSubscriptionTicked>(_onSubscriptionTicked);
  }

  final DmReactionsRepository _reactionsRepository;
  final String _ownerPubkey;

  /// Clock for the synthetic optimistic row's `created_at`. Injectable so
  /// tests stay deterministic; defaults to [DateTime.now] in production.
  final DateTime Function() _now;

  StreamSubscription<List<DmReaction>>? _subscription;
  String? _conversationId;

  /// Prefix for the synthetic optimistic row id. Never a valid Nostr event id
  /// (64-hex), so it can't collide with a real persisted row.
  static const String _optimisticIdPrefix = 'optimistic:';

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }

  Future<void> _onStarted(
    ConversationReactionsStarted event,
    Emitter<ConversationReactionsState> emit,
  ) async {
    if (_conversationId == event.conversationId &&
        state.status == ConversationReactionsStatus.loaded) {
      return;
    }
    _conversationId = event.conversationId;
    emit(state.copyWith(status: ConversationReactionsStatus.loading));
    await _subscription?.cancel();
    _subscription = _reactionsRepository
        .watchForConversation(event.conversationId)
        .listen(
          (reactions) =>
              add(_ConversationReactionsSubscriptionTicked(reactions)),
        );
  }

  Future<void> _onToggled(
    ConversationReactionToggled event,
    Emitter<ConversationReactionsState> emit,
  ) async {
    // Toggle-off: if we already have a live matching reaction, remove it.
    final existing = _ownLiveReaction(event.messageId, event.emoji);
    if (existing != null) {
      // A re-tap on a not-yet-delivered own reaction must NOT be read as
      // toggle-off: removeOwn soft-deletes it locally and emits a kind-5,
      // permanently losing a reaction the recipient may already have (the OK
      // was merely lost/late on a flaky relay). Re-drive delivery instead —
      // mirrors the detail sheet's failed → retry fork.
      if (existing.publishStatus == DmReactionPublishStatus.pending ||
          existing.publishStatus == DmReactionPublishStatus.failed) {
        add(
          ConversationReactionRetryRequested(
            rumorId: existing.id,
            messageId: event.messageId,
            messageAuthorPubkey: event.messageAuthorPubkey,
            emoji: event.emoji,
          ),
        );
        return;
      }
      if (existing.publishStatus == DmReactionPublishStatus.removalRefused) {
        add(
          ConversationReactionRemovalRetryRequested(
            rumorId: existing.id,
            messageAuthorPubkey: event.messageAuthorPubkey,
          ),
        );
        return;
      }
      final key = ReactionPublishKey(
        messageId: event.messageId,
        emoji: event.emoji,
      );
      // Hide the own chip on the same frame as the tap; reconciled away by
      // the next stream tick once the soft-delete drops the persisted row.
      emit(
        state.copyWith(
          optimistic: {
            ...state.optimistic,
            key: const OptimisticReactionRemoved(),
          },
        ),
      );
      try {
        await _reactionsRepository.removeOwn(
          rumorId: existing.id,
          targetMessageAuthor: event.messageAuthorPubkey,
        );
      } on Object catch (e, st) {
        addError(e, st);
        // Removal didn't take — restore the chip.
        final restored = Map<ReactionPublishKey, OptimisticReactionIntent>.from(
          state.optimistic,
        )..remove(key);
        emit(state.copyWith(optimistic: restored));
      }
      return;
    }

    if (await _blockWhileRemovalOutstanding(event.messageId, emit)) return;

    await _publishReaction(
      conversationId: event.conversationId,
      messageId: event.messageId,
      messageAuthorPubkey: event.messageAuthorPubkey,
      emoji: event.emoji,
      emit: emit,
    );
  }

  Future<void> _onSet(
    ConversationReactionSet event,
    Emitter<ConversationReactionsState> emit,
  ) async {
    if (await _blockWhileRemovalOutstanding(event.messageId, emit)) return;

    // Set-not-toggle: re-selecting the active emoji is a no-op (keep it);
    // a different emoji supersedes the prior one in the repository. The
    // optimistic-inclusive check also covers the pre-persist window, so a
    // rapid double-tap burst can't fan out duplicate gift-wrapped reactions
    // before the first row lands — the whole publish decision lives here, and
    // callers (double-tap-to-like, the reel reply bar) just dispatch.
    if (state.ownReactionPendingOrLive(
      messageId: event.messageId,
      emoji: event.emoji,
      ownerPubkey: _ownerPubkey,
    )) {
      return;
    }

    await _publishReaction(
      conversationId: event.conversationId,
      messageId: event.messageId,
      messageAuthorPubkey: event.messageAuthorPubkey,
      emoji: event.emoji,
      emit: emit,
    );
  }

  /// Blocks new reactions while a pending or refused removal must remain
  /// reachable for delivery or manual retry.
  Future<bool> _blockWhileRemovalOutstanding(
    String messageId,
    Emitter<ConversationReactionsState> emit,
  ) async {
    final hasRefusedRemoval = state
        .reactionsFor(messageId)
        .any(
          (reaction) =>
              reaction.isOwn &&
              reaction.publishStatus == DmReactionPublishStatus.removalRefused,
        );
    final hasOutstandingRemoval =
        hasRefusedRemoval ||
        await _reactionsRepository.hasOutstandingOwnDeletion(
          targetMessageId: messageId,
        );
    if (!hasOutstandingRemoval) return false;
    emit(
      state.copyWith(
        blockedReactionAttempts: state.blockedReactionAttempts + 1,
      ),
    );
    return true;
  }

  /// The current account's live reaction with [emoji] on [messageId], or null.
  /// Reads the persisted rows only (not the optimistic overlay) so toggle-off
  /// resolves a real rumor id for [DmReactionsRepository.removeOwn].
  DmReaction? _ownLiveReaction(String messageId, String emoji) {
    final list = state.reactionsByMessageId[messageId];
    return list?.firstWhereOrNull(
      (r) => r.reactorPubkey == _ownerPubkey && r.emoji == emoji,
    );
  }

  /// The current account's live persisted reaction on [messageId] with ANY
  /// emoji, or null. Drives the optimistic cap-at-one supersede swap.
  DmReaction? _ownLivePersistedReaction(String messageId) {
    final list = state.reactionsByMessageId[messageId];
    return list?.firstWhereOrNull((r) => r.reactorPubkey == _ownerPubkey);
  }

  /// Optimistically paint the chip, mark the publish pending, send, then
  /// settle by outcome. Shared by the toggle and set paths.
  ///
  /// The synthetic [DmReaction] is overlaid synchronously (same frame as the
  /// tap) so the chip never waits on the local Drift round-trip
  /// (`insertOwnReactionSuperseding` → watch re-emit, which crosses a
  /// background isolate and SQLCipher). It is reconciled away in
  /// [_onSubscriptionTicked] once the persisted row lands (#5389).
  Future<void> _publishReaction({
    required String conversationId,
    required String messageId,
    required String messageAuthorPubkey,
    required String emoji,
    required Emitter<ConversationReactionsState> emit,
  }) async {
    final key = ReactionPublishKey(messageId: messageId, emoji: emoji);
    final synthetic = DmReaction(
      id: '$_optimisticIdPrefix$messageId:$emoji',
      conversationId: conversationId,
      targetMessageId: messageId,
      targetMessageAuthor: messageAuthorPubkey,
      reactorPubkey: _ownerPubkey,
      emoji: emoji,
      createdAt: _now().millisecondsSinceEpoch ~/ 1000,
      ownerPubkey: _ownerPubkey,
      publishStatus: DmReactionPublishStatus.pending,
    );

    final nextOptimistic =
        Map<ReactionPublishKey, OptimisticReactionIntent>.from(
          state.optimistic,
        );
    // Cap-at-one supersede: if a different own emoji is live, hide it now so
    // the swap looks instant (the repository soft-deletes it on the wire).
    final prior = _ownLivePersistedReaction(messageId);
    if (prior != null && prior.emoji != emoji) {
      nextOptimistic[ReactionPublishKey(
            messageId: messageId,
            emoji: prior.emoji,
          )] =
          const OptimisticReactionRemoved();
    }
    nextOptimistic[key] = OptimisticReactionAdded(synthetic);

    final nextPending =
        Map<ReactionPublishKey, ReactionPublishLocalStatus>.from(state.pending)
          ..[key] = ReactionPublishLocalStatus.sending;
    emit(state.copyWith(optimistic: nextOptimistic, pending: nextPending));

    try {
      final result = await _reactionsRepository.publish(
        conversationId: conversationId,
        targetMessageId: messageId,
        targetMessageAuthor: messageAuthorPubkey,
        emoji: emoji,
      );
      final newPending =
          Map<ReactionPublishKey, ReactionPublishLocalStatus>.from(
            state.pending,
          );
      if (result.success) {
        // The DAO stream re-emits with the persisted `sent` row; the chip's
        // truth source becomes the row itself (reconciled in the next tick).
        newPending.remove(key);
        emit(state.copyWith(pending: newPending));
      } else {
        newPending[key] = ReactionPublishLocalStatus.failed;
        emit(
          state.copyWith(
            pending: newPending,
            optimistic: _withoutOrphanedAdd(
              key: key,
              emoji: emoji,
              durableRowExists: result.optimisticInsertSucceeded,
            ),
          ),
        );
      }
    } on Object catch (e, st) {
      // Network/IO class per error-handling matrix — addError without
      // Reportable wrap. Site identifier carried for log triage.
      addError(
        _ReactionPublishException(
          e,
          site: ConversationReactionsReportableSites.publishThrew,
        ),
        st,
      );
      final newPending =
          Map<ReactionPublishKey, ReactionPublishLocalStatus>.from(
            state.pending,
          )..[key] = ReactionPublishLocalStatus.failed;
      emit(
        state.copyWith(
          pending: newPending,
          optimistic: _withoutOrphanedAdd(key: key, emoji: emoji),
        ),
      );
    }
  }

  /// On a publish failure, drop the optimistic add ONLY when the optimistic
  /// insert never produced a persisted row — otherwise the chip would linger
  /// forever as a never-settling pending placeholder. When the row exists
  /// (send-failure), the overlay is left for the stream tick to reconcile and
  /// the persisted `failed`/`pending` row drives the retry chip.
  ///
  /// [durableRowExists] short-circuits the check to keep the overlay even
  /// before the DAO stream has ticked the new row into [reactionsByMessageId]:
  /// on a fast failure the synchronous overlay drop can otherwise beat the
  /// background-isolate insert tick, briefly collapsing the chip to
  /// `SizedBox.shrink` and inviting a "repair" re-tap. The publish result
  /// tells us the durable row was written, so we trust that over the tick-laggy
  /// state; [_reconcileOptimistic] collapses the overlay once the row lands.
  Map<ReactionPublishKey, OptimisticReactionIntent> _withoutOrphanedAdd({
    required ReactionPublishKey key,
    required String emoji,
    bool durableRowExists = false,
  }) {
    if (durableRowExists) return state.optimistic;
    final persisted =
        state.reactionsByMessageId[key.messageId] ?? const <DmReaction>[];
    final hasPersisted = persisted.any((r) => r.isOwn && r.emoji == emoji);
    if (hasPersisted) return state.optimistic;
    return Map<ReactionPublishKey, OptimisticReactionIntent>.from(
      state.optimistic,
    )..remove(key);
  }

  Future<void> _onRetryRequested(
    ConversationReactionRetryRequested event,
    Emitter<ConversationReactionsState> emit,
  ) async {
    final key = ReactionPublishKey(
      messageId: event.messageId,
      emoji: event.emoji,
    );
    final nextPending =
        Map<ReactionPublishKey, ReactionPublishLocalStatus>.from(state.pending)
          ..[key] = ReactionPublishLocalStatus.sending;
    emit(state.copyWith(pending: nextPending));

    try {
      final result = await _reactionsRepository.retry(
        rumorId: event.rumorId,
        targetMessageAuthor: event.messageAuthorPubkey,
      );
      final newPending =
          Map<ReactionPublishKey, ReactionPublishLocalStatus>.from(
            state.pending,
          );
      if (result.success) {
        newPending.remove(key);
      } else {
        newPending[key] = ReactionPublishLocalStatus.failed;
      }
      emit(state.copyWith(pending: newPending));
    } on Object catch (e, st) {
      addError(
        _ReactionPublishException(
          e,
          site: ConversationReactionsReportableSites.retryThrew,
        ),
        st,
      );
      final newPending =
          Map<ReactionPublishKey, ReactionPublishLocalStatus>.from(
            state.pending,
          )..[key] = ReactionPublishLocalStatus.failed;
      emit(state.copyWith(pending: newPending));
    }
  }

  Future<void> _onRemovalRetryRequested(
    ConversationReactionRemovalRetryRequested event,
    Emitter<ConversationReactionsState> emit,
  ) async {
    emit(
      state.copyWith(
        removalRetries: {
          event.rumorId: ReactionRemovalRetryLocalStatus.retrying,
        },
      ),
    );
    try {
      final outcome = await _reactionsRepository.retryDeletion(
        rumorId: event.rumorId,
        targetMessageAuthor: event.messageAuthorPubkey,
      );
      emit(
        state.copyWith(
          removalRetries: {
            event.rumorId: switch (outcome) {
              DmReactionDeletionOutcome.sent =>
                ReactionRemovalRetryLocalStatus.sent,
              DmReactionDeletionOutcome.refused =>
                ReactionRemovalRetryLocalStatus.refused,
              DmReactionDeletionOutcome.unconfirmed ||
              DmReactionDeletionOutcome.notSent =>
                ReactionRemovalRetryLocalStatus.unconfirmed,
              DmReactionDeletionOutcome.unavailable =>
                ReactionRemovalRetryLocalStatus.unavailable,
            },
          },
        ),
      );
    } on Object catch (error, stackTrace) {
      addError(error, stackTrace);
      emit(
        state.copyWith(
          removalRetries: {
            event.rumorId: ReactionRemovalRetryLocalStatus.unavailable,
          },
        ),
      );
    }
  }

  void _onSubscriptionTicked(
    _ConversationReactionsSubscriptionTicked event,
    Emitter<ConversationReactionsState> emit,
  ) {
    final grouped = <String, List<DmReaction>>{};
    for (final reaction in event.reactions) {
      grouped
          .putIfAbsent(reaction.targetMessageId, () => <DmReaction>[])
          .add(reaction);
    }
    emit(
      state.copyWith(
        status: ConversationReactionsStatus.loaded,
        reactionsByMessageId: grouped,
        optimistic: _reconcileOptimistic(grouped),
      ),
    );
  }

  /// Drop optimistic overlays the freshly-persisted set now satisfies: an
  /// `Added` whose own row is present, or a `Removed` whose own row is gone.
  /// Anything still in flight is kept so the chip stays put across the tick.
  Map<ReactionPublishKey, OptimisticReactionIntent> _reconcileOptimistic(
    Map<String, List<DmReaction>> persisted,
  ) {
    if (state.optimistic.isEmpty) return state.optimistic;
    final next = Map<ReactionPublishKey, OptimisticReactionIntent>.from(
      state.optimistic,
    );
    next.removeWhere((key, intent) {
      final rows = persisted[key.messageId] ?? const <DmReaction>[];
      final ownHasEmoji = rows.any((r) => r.isOwn && r.emoji == key.emoji);
      return switch (intent) {
        OptimisticReactionAdded() => ownHasEmoji,
        OptimisticReactionRemoved() =>
          !ownHasEmoji ||
              rows.any(
                (reaction) =>
                    reaction.isOwn &&
                    reaction.emoji == key.emoji &&
                    reaction.publishStatus ==
                        DmReactionPublishStatus.removalRefused,
              ),
      };
    });
    return next;
  }
}

/// Wraps the inner publish exception with a triage site identifier.
/// Not a [ReportableError] — Crashlytics does NOT receive these.
@immutable
class _ReactionPublishException implements Exception {
  const _ReactionPublishException(this.inner, {required this.site});

  final Object inner;
  final String site;

  @override
  String toString() => 'ReactionPublishException($site): $inner';
}
