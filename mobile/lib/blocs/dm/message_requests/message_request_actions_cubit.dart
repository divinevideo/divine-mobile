// ABOUTME: Cubit for message request actions (decline, mark-all-read,
// ABOUTME: remove-all). Used by the Message Requests inbox and preview screens.

import 'package:bloc/bloc.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:models/models.dart';

enum MessageRequestActionsStatus { idle, processing, success, error }

/// What [MessageRequestActionsCubit.declineRequest] actually did.
///
/// Three-valued rather than a `bool` because a refusal is not a failure: the
/// caller must not report `commonSomethingWentWrong` for a request the policy
/// deliberately protects.
enum DeclineRequestOutcome {
  /// The conversation was removed.
  removed,

  /// The conversation belongs to a Divine moderation identity and is not
  /// removable. Nothing was deleted.
  refused,

  /// The removal threw.
  failed,
}

class MessageRequestActionsState extends Equatable {
  const MessageRequestActionsState({
    this.status = MessageRequestActionsStatus.idle,
    this.showDismissed = false,
  });

  final MessageRequestActionsStatus status;
  final bool showDismissed;

  MessageRequestActionsState copyWith({
    MessageRequestActionsStatus? status,
    bool? showDismissed,
  }) => MessageRequestActionsState(
    status: status ?? this.status,
    showDismissed: showDismissed ?? this.showDismissed,
  );

  @override
  List<Object?> get props => [status, showDismissed];
}

class MessageRequestActionsCubit extends Cubit<MessageRequestActionsState> {
  MessageRequestActionsCubit({required DmRepository dmRepository})
    : _dmRepository = dmRepository,
      super(const MessageRequestActionsState());

  final DmRepository _dmRepository;

  /// Switch between pending and dismissed requests.
  void showDismissedRequests({required bool show}) {
    emit(state.copyWith(showDismissed: show));
  }

  /// Put a request aside or restore it, keeping all messages.
  Future<void> setRequestDismissed(
    String conversationId, {
    required bool dismissed,
  }) async {
    if (state.status == MessageRequestActionsStatus.processing) return;
    emit(state.copyWith(status: MessageRequestActionsStatus.processing));
    try {
      await _dmRepository.setConversationDismissed(
        conversationId,
        dismissed: dismissed,
      );
      if (!isClosed) {
        emit(state.copyWith(status: MessageRequestActionsStatus.success));
      }
    } catch (e, stackTrace) {
      addError(e, stackTrace);
      if (!isClosed) {
        emit(state.copyWith(status: MessageRequestActionsStatus.error));
      }
    }
  }

  /// Decline and remove a single message request.
  ///
  /// Returns [DeclineRequestOutcome.removed] when the removal completed,
  /// [DeclineRequestOutcome.refused] when the conversation is protected, and
  /// [DeclineRequestOutcome.failed] when it threw. The caller must consume this
  /// result rather than reading [state] after the await: a keyed provider
  /// closing this cubit mid-operation (account switch) skips the guarded
  /// `success` emit even though the removal succeeded, so a state read would
  /// report a false failure.
  ///
  /// The refusal itself comes from the repository, which owns the policy for
  /// every removal path (#8391). This cubit only translates it: the request
  /// preview renders its decline button in states where the counterparty is
  /// not resolved yet, so the widget could not answer the question anyway.
  Future<DeclineRequestOutcome> declineRequest(String conversationId) async {
    emit(state.copyWith(status: MessageRequestActionsStatus.processing));
    try {
      final outcome = await _dmRepository.removeConversation(conversationId);
      if (outcome == ConversationRemovalOutcome.refused) {
        if (!isClosed) {
          emit(state.copyWith(status: MessageRequestActionsStatus.idle));
        }
        return DeclineRequestOutcome.refused;
      }

      if (!isClosed) {
        emit(state.copyWith(status: MessageRequestActionsStatus.success));
      }
      return DeclineRequestOutcome.removed;
    } catch (e, stackTrace) {
      // Drift IO failures are expected. Per
      // .claude/rules/error_handling.md they are NOT Reportable.
      addError(e, stackTrace);
      if (!isClosed) {
        emit(state.copyWith(status: MessageRequestActionsStatus.error));
      }
      return DeclineRequestOutcome.failed;
    }
  }

  /// Mark all provided request conversations as read.
  Future<void> markAllRequestsAsRead(List<String> conversationIds) async {
    if (conversationIds.isEmpty) return;
    emit(state.copyWith(status: MessageRequestActionsStatus.processing));
    try {
      await _dmRepository.markConversationsAsRead(conversationIds);
      if (!isClosed) {
        emit(state.copyWith(status: MessageRequestActionsStatus.success));
      }
    } catch (e, stackTrace) {
      // Drift IO failures are expected. Per
      // .claude/rules/error_handling.md they are NOT Reportable.
      addError(e, stackTrace);
      if (!isClosed) {
        emit(state.copyWith(status: MessageRequestActionsStatus.error));
      }
    }
  }

  /// Remove every removable conversation in [conversations].
  ///
  /// Takes conversations rather than ids so the caller can keep passing its
  /// whole list. The decision about what "all requests" excludes lives in the
  /// repository (#8391), so every removal path inherits it rather than each
  /// cubit re-implementing it.
  ///
  /// Protected conversations are skipped and remain in the request list.
  ///
  /// [withheld] is true when at least one row was kept back, so the caller can
  /// say why one stayed behind — without it the guard is invisible in the bulk
  /// path: a list holding nothing but a notice removes nothing, emits nothing,
  /// and reads as a broken button (#8347).
  ///
  /// [failed] is reported separately for the same reason [declineRequest] is
  /// three-valued: a refusal is not a failure, and the two must not share one
  /// flag. `removeConversations` runs in a transaction, so a throw rolls back
  /// every row — reporting only [withheld] there would blame the notice for a
  /// sweep that removed nothing.
  ///
  /// The caller must consume this result rather than reading [state] after the
  /// await, for the reason given on [declineRequest].
  Future<({bool withheld, bool failed})> removeAllRequests(
    List<DmConversation> conversations,
  ) async {
    if (conversations.isEmpty) return (withheld: false, failed: false);
    emit(state.copyWith(status: MessageRequestActionsStatus.processing));
    var withheld = false;
    try {
      final outcome = await _dmRepository.removeConversations([
        for (final conversation in conversations) conversation.id,
      ]);
      withheld = outcome.refused > 0;
      if (!isClosed) {
        emit(state.copyWith(status: MessageRequestActionsStatus.success));
      }
    } catch (e, stackTrace) {
      // Drift IO failures are expected. Per
      // .claude/rules/error_handling.md they are NOT Reportable.
      addError(e, stackTrace);
      if (!isClosed) {
        emit(state.copyWith(status: MessageRequestActionsStatus.error));
      }
      return (withheld: withheld, failed: true);
    }
    return (withheld: withheld, failed: false);
  }
}
