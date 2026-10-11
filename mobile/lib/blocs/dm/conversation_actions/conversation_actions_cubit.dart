// ABOUTME: Cubit for DM conversation actions (report, block, remove).
// ABOUTME: Constructor-injected services, no Riverpod at action time.

import 'package:bloc/bloc.dart';
import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:models/models.dart';
import 'package:openvine/models/content_moderation.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:openvine/services/content_reporting_service.dart';

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

/// Handles report, block, and remove actions for DM conversations.
///
/// Services are constructor-injected so the widget layer never reads
/// Riverpod providers at action time.
class ConversationActionsCubit extends Cubit<ConversationActionsState> {
  ConversationActionsCubit({
    required ContentReportingService? contentReportingService,
    required ContentBlocklistRepository contentBlocklistRepository,
    required DmRepository dmRepository,
    required String currentUserPubkey,
  }) : _reportingService = contentReportingService,
       _blocklistRepository = contentBlocklistRepository,
       _dmRepository = dmRepository,
       _currentUserPubkey = currentUserPubkey,
       super(const ConversationActionsState());

  final ContentReportingService? _reportingService;
  final ContentBlocklistRepository _blocklistRepository;
  final DmRepository _dmRepository;
  final String _currentUserPubkey;

  /// Report a user from a DM conversation.
  ///
  /// Returns `true` only when the report reached a channel off this device.
  /// A report that was built and recorded locally but published nowhere
  /// returns `false`, because the caller renders a confirmation off this
  /// value.
  Future<bool> reportUser(String pubkey) async {
    final service = _reportingService;
    if (service == null) return false;

    emit(state.copyWith(status: ConversationActionsStatus.processing));
    try {
      final result = await service.reportUser(
        userPubkey: pubkey,
        reason: ContentFilterReason.other,
        details: 'Reported from DM conversation',
      );
      if (!isClosed) {
        emit(state.copyWith(status: ConversationActionsStatus.idle));
      }
      // `success` only means the report was built and recorded — it is true
      // even when the relay publish and the Zendesk ticket both failed and
      // nothing left the device. The caller shows a "Reported {name}"
      // confirmation off this bool, so require actual delivery.
      // A deliberately refused report (a self-report, #8352) is a silent
      // success: return true so the caller shows the normal confirmation
      // rather than a failure, since nothing was (or ever will be) sent.
      return result.isSilentSuccess;
    } catch (e, stackTrace) {
      // `ContentReportingService.reportUser` returns `ReportResult.failure`
      // for expected publish/auth problems. Any throw escaping here is
      // unexpected, so surface it as Reportable.
      addError(Reportable(e, context: 'reportUser'), stackTrace);
      if (!isClosed) {
        emit(state.copyWith(status: ConversationActionsStatus.idle));
      }
      return false;
    }
  }

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
