// ABOUTME: Cubit for muting DM conversation notifications.
// ABOUTME: Persists muted conversation IDs to SharedPreferences.

import 'dart:convert';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

/// SharedPreferences key for muted conversations.
///
/// Public so `UserDataCleanupService` can clear it by reference (#8314).
const mutedConversationsStorageKey = 'muted_conversations';

enum ConversationMuteStatus { idle, success, error }

class ConversationMuteState extends Equatable {
  const ConversationMuteState({
    this.status = ConversationMuteStatus.idle,
    this.mutedIds = const {},
  });

  final ConversationMuteStatus status;
  final Set<String> mutedIds;

  bool isMuted(String conversationId) => mutedIds.contains(conversationId);

  ConversationMuteState copyWith({
    ConversationMuteStatus? status,
    Set<String>? mutedIds,
  }) {
    return ConversationMuteState(
      status: status ?? this.status,
      mutedIds: mutedIds ?? this.mutedIds,
    );
  }

  @override
  List<Object?> get props => [status, mutedIds];
}

/// Manages muted DM conversations.
///
/// Muting silences push notifications for a conversation. The conversation
/// remains visible in the inbox. Mute state is local-only (not published
/// to Nostr).
class ConversationMuteCubit extends Cubit<ConversationMuteState> {
  ConversationMuteCubit({required SharedPreferences prefs})
    : _prefs = prefs,
      super(const ConversationMuteState()) {
    _load();
  }

  final SharedPreferences _prefs;

  /// Toggle mute state for a conversation.
  ///
  /// Returns `true` if the conversation is now muted, `false` if unmuted.
  Future<bool> toggleMute(String conversationId) async {
    final previousIds = Set<String>.from(state.mutedIds);
    final muted = Set<String>.from(state.mutedIds);
    final nowMuted = !muted.contains(conversationId);
    if (nowMuted) {
      muted.add(conversationId);
    } else {
      muted.remove(conversationId);
    }

    emit(
      state.copyWith(status: ConversationMuteStatus.success, mutedIds: muted),
    );

    try {
      await _save(muted);
    } catch (e, stackTrace) {
      // SharedPreferences IO failures are expected. Per
      // .claude/rules/error_handling.md they are NOT Reportable.
      addError(e, stackTrace);
      if (!isClosed) {
        emit(
          state.copyWith(
            status: ConversationMuteStatus.error,
            mutedIds: previousIds,
          ),
        );
      }
    }

    Log.debug(
      '${nowMuted ? "Muted" : "Unmuted"} conversation: $conversationId',
      name: 'ConversationMuteCubit',
      category: LogCategory.system,
    );
    return nowMuted;
  }

  void _load() {
    final stored = _prefs.getString(mutedConversationsStorageKey);
    if (stored == null || stored.isEmpty) return;

    try {
      final list = (jsonDecode(stored) as List<dynamic>).cast<String>();
      emit(state.copyWith(mutedIds: list.toSet()));
    } on FormatException catch (e, stackTrace) {
      // Corrupted prefs JSON — matrix-NO (API/domain). Recover with
      // empty set.
      addError(e, stackTrace);
      Log.error(
        'Failed to load muted conversations: $e',
        name: 'ConversationMuteCubit',
        category: LogCategory.system,
      );
    } catch (e, stackTrace) {
      // `cast<String>()` / `as List<dynamic>` lazy `TypeError` means
      // the stored shape is unexpected — matrix-YES (Invariant).
      addError(Reportable(e, context: '_load'), stackTrace);
      Log.error(
        'Failed to load muted conversations: $e',
        name: 'ConversationMuteCubit',
        category: LogCategory.system,
      );
    }
  }

  Future<void> _save(Set<String> ids) async {
    final json = jsonEncode(ids.toList());
    await _prefs.setString(mutedConversationsStorageKey, json);
  }
}
