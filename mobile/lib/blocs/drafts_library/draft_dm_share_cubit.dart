// ABOUTME: Exports a saved draft and queues it for one recipient.

import 'dart:io';

import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/services/dm_video_encryption.dart';
import 'package:openvine/services/video_dm_outbox.dart';
import 'package:unified_logger/unified_logger.dart';

enum DraftDmShareState {
  idle,
  preparing,
  queued,
  failed,
  tooLarge,
  blocked,
  recipientBlockedByUs,
  retiredRecipient,
  accountChanged,
}

/// Prepares an editable project for the active account's DM outbox.
class DraftDmShareCubit extends Cubit<DraftDmShareState> {
  DraftDmShareCubit({
    required this.senderPubkey,
    required this.recipientPubkey,
    required Future<DivineVideoDraft?> Function(String) loadDraft,
    required Future<File> Function(DivineVideoDraft) exportDraft,
    required bool Function() ownsSession,
    required DmSendPolicy sendPolicy,
    required bool Function(String) isBlocked,
    required VideoDmOutbox outbox,
  }) : _loadDraft = loadDraft,
       _exportDraft = exportDraft,
       _ownsSession = ownsSession,
       _sendPolicy = sendPolicy,
       _isBlocked = isBlocked,
       _outbox = outbox,
       super(DraftDmShareState.idle);

  final String senderPubkey;
  final String recipientPubkey;
  final Future<DivineVideoDraft?> Function(String) _loadDraft;
  final Future<File> Function(DivineVideoDraft) _exportDraft;
  final bool Function() _ownsSession;
  final DmSendPolicy _sendPolicy;
  final bool Function(String) _isBlocked;
  final VideoDmOutbox _outbox;

  String get conversationId =>
      DmRepository.computeConversationId([senderPubkey, recipientPubkey]);

  Future<void> send(String draftId) async {
    if (isClosed ||
        state == DraftDmShareState.preparing ||
        state == DraftDmShareState.queued) {
      return;
    }
    emit(DraftDmShareState.preparing);

    File? bundle;
    try {
      if (!_checkSession() || !await _checkRecipient()) return;
      final draft = await _loadDraft(draftId);
      if (!_checkSession()) return;
      if (draft == null) {
        emit(DraftDmShareState.failed);
        return;
      }

      bundle = await _exportDraft(draft);

      if (!_checkSession() || !await _checkRecipient() || !_checkSession()) {
        return;
      }
      _outbox.sendDraft(
        conversationId: conversationId,
        recipientPubkey: recipientPubkey,
        file: bundle,
      );
      bundle = null;
      emit(DraftDmShareState.queued);
    } on DmVideoTooLargeException {
      if (_checkSession()) emit(DraftDmShareState.tooLarge);
    } on Object catch (error, stackTrace) {
      Log.warning(
        'Could not export an editable draft for a DM',
        name: 'DraftDmShareCubit',
        category: LogCategory.video,
        error: error,
        stackTrace: stackTrace,
      );
      if (_checkSession()) emit(DraftDmShareState.failed);
    } finally {
      if (bundle != null) {
        try {
          if (bundle.existsSync()) await bundle.delete();
        } on FileSystemException catch (error) {
          Log.warning(
            'Could not delete an abandoned draft package',
            name: 'DraftDmShareCubit',
            category: LogCategory.video,
            error: error,
          );
        }
      }
    }
  }

  bool _checkSession() {
    if (isClosed) return false;
    if (_ownsSession()) return true;
    emit(DraftDmShareState.accountChanged);
    return false;
  }

  Future<bool> _checkRecipient() async {
    final decision = await _sendPolicy(recipientPubkey);
    if (!_checkSession()) return false;
    if (_isBlocked(recipientPubkey)) {
      emit(DraftDmShareState.recipientBlockedByUs);
      return false;
    }
    switch (decision) {
      case DmSendPolicyDecision.allowed:
        return true;
      case DmSendPolicyDecision.terminallyBlockedRetain:
        emit(DraftDmShareState.retiredRecipient);
      case DmSendPolicyDecision.terminallyBlockedDiscard:
      case DmSendPolicyDecision.temporarilyBlocked:
        emit(DraftDmShareState.blocked);
    }
    return false;
  }
}
