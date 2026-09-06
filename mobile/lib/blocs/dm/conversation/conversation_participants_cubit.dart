// ABOUTME: Resolves a conversation's counterparties from the route hint or
// ABOUTME: the local DB, applying the #176 DM-restriction gate first.

import 'package:dm_repository/dm_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/blocs/dm/dm_peer_name.dart';
import 'package:openvine/blocs/dm/minor_dm_approval.dart';

/// Resolution status for a conversation's counterparties.
enum ConversationParticipantsStatus {
  /// The counterparties are being read from the database.
  loading,

  /// The counterparties are known — see
  /// [ConversationParticipantsState.participantPubkeys].
  ready,

  /// A DM-restricted user (#176) may not open this conversation.
  denied,
}

/// The counterparties of a single conversation.
class ConversationParticipantsState extends Equatable {
  /// Creates a [ConversationParticipantsState].
  const ConversationParticipantsState({
    this.status = ConversationParticipantsStatus.loading,
    this.participantPubkeys = const [],
  });

  /// How far resolution has progressed.
  final ConversationParticipantsStatus status;

  /// Pubkeys of the other participants, excluding the current user.
  ///
  /// Empty on [ConversationParticipantsStatus.ready] means no counterparty
  /// could be resolved — the conversation has no stored row yet, or the read
  /// failed. The thread still renders its (empty) history; it just cannot be
  /// addressed. This is the pre-existing behaviour for a conversation opened
  /// without a route hint, so the resolution never makes a thread worse.
  final List<String> participantPubkeys;

  /// Copies this state with the given fields replaced.
  ConversationParticipantsState copyWith({
    ConversationParticipantsStatus? status,
    List<String>? participantPubkeys,
  }) {
    return ConversationParticipantsState(
      status: status ?? this.status,
      participantPubkeys: participantPubkeys ?? this.participantPubkeys,
    );
  }

  @override
  List<Object?> get props => [status, participantPubkeys];
}

/// Resolves the counterparties for `/inbox/conversation/:id`.
///
/// In-app navigation passes them through `GoRouterState.extra`, which is
/// process-local and gone after a browser refresh, a deep link or a restored
/// session (#3335). Without them the thread renders but has no identity in its
/// header and no recipient to send to, so fall back to the conversation row
/// keyed by [conversationId].
///
/// Mirrors `RequestPreviewCubit`, deliberately including its #176 ordering.
class ConversationParticipantsCubit extends Cubit<ConversationParticipantsState>
    with CloseGuardedEmit<ConversationParticipantsState> {
  /// Creates a [ConversationParticipantsCubit].
  ConversationParticipantsCubit({
    required DmRepository dmRepository,
    required this.conversationId,
    required bool Function() isDmRestricted,
    required bool Function(String) isApprovedRecipient,
    List<String> initialParticipantPubkeys = const [],
  }) : _dmRepository = dmRepository,
       _isDmRestricted = isDmRestricted,
       _isApprovedRecipient = isApprovedRecipient,
       _initialParticipantPubkeys = initialParticipantPubkeys,
       super(const ConversationParticipantsState());

  final DmRepository _dmRepository;

  /// Whether the current user is DM-restricted (#176), read at load time.
  final bool Function() _isDmRestricted;

  /// Whether a counterparty is an approved official recipient (#176).
  final bool Function(String) _isApprovedRecipient;

  /// Counterparties supplied by the route, when it had them.
  final List<String> _initialParticipantPubkeys;

  /// The conversation this cubit resolves participants for.
  final String conversationId;

  /// Resolves the counterparties, preferring the route-provided hint.
  ///
  /// The #176 gate runs BEFORE any repository read and checks only the
  /// route-provided pubkeys: resolving counterparties from the DB is itself a
  /// read of conversation data a restricted user may not access, so a
  /// DM-restricted user arriving without route extras (a direct or stale
  /// `/inbox/conversation/:id` URL) fails closed via the predicate's
  /// empty-list branch instead of being looked up. In-app navigation always
  /// passes extras, so only direct links are denied this way.
  ///
  /// Both the gate and the hint path emit before the first `await`, so a
  /// conversation opened from the inbox renders without a loading frame and a
  /// restricted user never sees the thread. Keep them ahead of any suspension
  /// point.
  Future<void> load() async {
    if (_isDmRestricted() &&
        !allParticipantsApprovedForMinor(
          _initialParticipantPubkeys,
          _isApprovedRecipient,
        )) {
      emitIfOpen(
        state.copyWith(status: ConversationParticipantsStatus.denied),
      );
      return;
    }

    if (_initialParticipantPubkeys.isNotEmpty) {
      emitIfOpen(
        state.copyWith(
          status: ConversationParticipantsStatus.ready,
          participantPubkeys: _initialParticipantPubkeys,
        ),
      );
      return;
    }

    var resolved = const <String>[];
    try {
      resolved = await _resolveParticipants();
    } catch (error, stackTrace) {
      // Drift read failures are expected and, per
      // .claude/rules/error_handling.md, not Reportable. An unresolved thread
      // is the documented empty-list case rather than a separate failure UI.
      addError(error, stackTrace);
    }
    emitIfOpen(
      state.copyWith(
        status: ConversationParticipantsStatus.ready,
        participantPubkeys: resolved,
      ),
    );
  }

  Future<List<String>> _resolveParticipants() async {
    final conversation = await _dmRepository.getConversation(conversationId);
    if (conversation == null) return const [];
    final userPubkey = _dmRepository.userPubkey;
    return dmConversationPeerPubkeys(
      participantPubkeys: conversation.participantPubkeys,
      currentUserPubkey: userPubkey,
    );
  }
}
