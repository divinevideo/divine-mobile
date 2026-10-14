// ABOUTME: Cubit for DM conversation actions (block, remove).
// ABOUTME: Constructor-injected services, no Riverpod at action time.

import 'package:bloc/bloc.dart';
import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:models/models.dart';

enum ConversationActionsStatus { idle, processing, success, failure }

/// What [ConversationActionsCubit.removeConversation] actually did.
///
/// Three-valued rather than a `bool` for the reason given on
/// `DeclineRequestOutcome`: a refusal is not a failure, and the caller must
/// not report an error for a conversation the policy protects (#8391).
enum RemoveConversationOutcome {
  /// The conversation was removed.
  removed,

  /// The repository's removal policy protects it. Nothing was deleted.
  refused,

  /// The removal threw.
  failed,
}

class ConversationActionsState extends Equatable {
  const ConversationActionsState({
    this.status = ConversationActionsStatus.idle,
  });

  final ConversationActionsStatus status;

  ConversationActionsState copyWith({ConversationActionsStatus? status}) {
    return ConversationActionsState(status: status ?? this.status);
  }

  @override
  List<Object?> get props => [status];
}

/// Handles block and remove actions for DM conversations.
///
/// Reporting is not here: it goes through the shared report form
/// (`ReportContentDialog`), like every other report surface.
///
/// Services are constructor-injected so the widget layer never reads
/// Riverpod providers at action time.
class ConversationActionsCubit extends Cubit<ConversationActionsState> {
  ConversationActionsCubit({
    required ContentBlocklistRepository contentBlocklistRepository,
    required DmRepository dmRepository,
    required String currentUserPubkey,
  }) : _blocklistRepository = contentBlocklistRepository,
       _dmRepository = dmRepository,
       _currentUserPubkey = currentUserPubkey,
       super(const ConversationActionsState());

  final ContentBlocklistRepository _blocklistRepository;
  final DmRepository _dmRepository;
  final String _currentUserPubkey;

  /// Whether [pubkey] is currently on the blocklist.
  bool isBlocked(String pubkey) => _blocklistRepository.isBlocked(pubkey);

  /// Block a user from a DM conversation.
  Future<void> blockUser(String pubkey) async {
    emit(state.copyWith(status: ConversationActionsStatus.processing));
    try {
      await _blocklistRepository.blockUser(
        pubkey,
        ourPubkey: _currentUserPubkey,
      );
      if (!isClosed) {
        emit(state.copyWith(status: ConversationActionsStatus.success));
      }
    } catch (e, stackTrace) {
      // Blocklist IO / publish failures are expected. Per
      // .claude/rules/error_handling.md they are NOT Reportable.
      addError(e, stackTrace);
      if (!isClosed) {
        emit(state.copyWith(status: ConversationActionsStatus.failure));
      }
    }
  }

  /// Unblock a previously blocked user.
  Future<void> unblockUser(String pubkey) async {
    emit(state.copyWith(status: ConversationActionsStatus.processing));
    try {
      await _blocklistRepository.unblockUser(pubkey);
      if (!isClosed) {
        emit(state.copyWith(status: ConversationActionsStatus.success));
      }
    } catch (e, stackTrace) {
      // Blocklist IO / publish failures are expected. Per
      // .claude/rules/error_handling.md they are NOT Reportable.
      addError(e, stackTrace);
      if (!isClosed) {
        emit(state.copyWith(status: ConversationActionsStatus.failure));
      }
    }
  }

  /// Whether [conversation] is one the repository refuses to remove.
  ///
  /// Synchronous, so the caller can withdraw the destructive action before
  /// offering it rather than letting the user meet a refusal. Symmetric with
  /// [isBlocked], which the same action sheet already consults.
  bool isRemovalProtected(DmConversation conversation) =>
      _dmRepository.isRemovalProtected(conversation);

  /// Remove a conversation locally.
  ///
  /// Three-valued for the same reason `declineRequest` is: a refusal is not a
  /// failure, so reporting `commonSomethingWentWrong` for a conversation the
  /// policy deliberately protects would be wrong (#8391). The repository owns
  /// the policy; this only translates its answer.
  Future<RemoveConversationOutcome> removeConversation(
    String conversationId,
  ) async {
    emit(state.copyWith(status: ConversationActionsStatus.processing));
    try {
      final outcome = await _dmRepository.removeConversation(conversationId);
      if (outcome == ConversationRemovalOutcome.refused) {
        if (!isClosed) {
          emit(state.copyWith(status: ConversationActionsStatus.idle));
        }
        return RemoveConversationOutcome.refused;
      }
      if (!isClosed) {
        emit(state.copyWith(status: ConversationActionsStatus.success));
      }
      return RemoveConversationOutcome.removed;
    } catch (e, stackTrace) {
      // Drift write failures are expected. Per
      // .claude/rules/error_handling.md they are NOT Reportable.
      addError(e, stackTrace);
      if (!isClosed) {
        emit(state.copyWith(status: ConversationActionsStatus.failure));
      }
      return RemoveConversationOutcome.failed;
    }
  }
}
