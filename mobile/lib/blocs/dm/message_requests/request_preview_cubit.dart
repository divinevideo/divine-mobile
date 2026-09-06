// ABOUTME: Cubit for the request preview screen data.
// ABOUTME: Loads message count and resolves participant pubkeys from the DB.

import 'package:bloc/bloc.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/dm_peer_name.dart';
import 'package:openvine/blocs/dm/minor_dm_approval.dart';

enum RequestPreviewStatus { loading, loaded, error, denied }

class RequestPreviewState extends Equatable {
  const RequestPreviewState({
    this.status = RequestPreviewStatus.loading,
    this.messageCount = 0,
    this.participantPubkeys = const [],
    this.messages = const [],
  });

  final RequestPreviewStatus status;
  final int messageCount;
  final List<String> participantPubkeys;
  final List<DmMessage> messages;

  RequestPreviewState copyWith({
    RequestPreviewStatus? status,
    int? messageCount,
    List<String>? participantPubkeys,
    List<DmMessage>? messages,
  }) {
    return RequestPreviewState(
      status: status ?? this.status,
      messageCount: messageCount ?? this.messageCount,
      participantPubkeys: participantPubkeys ?? this.participantPubkeys,
      messages: messages ?? this.messages,
    );
  }

  @override
  List<Object?> get props => [
    status,
    messageCount,
    participantPubkeys,
    messages,
  ];
}

class RequestPreviewCubit extends Cubit<RequestPreviewState> {
  RequestPreviewCubit({
    required DmRepository dmRepository,
    required this.conversationId,
    required bool Function() isDmRestricted,
    required bool Function(String) isApprovedRecipient,
    List<String> initialParticipantPubkeys = const [],
  }) : _dmRepository = dmRepository,
       _isDmRestricted = isDmRestricted,
       _isApprovedRecipient = isApprovedRecipient,
       _initialParticipantPubkeys = initialParticipantPubkeys,
       super(const RequestPreviewState());

  final DmRepository _dmRepository;

  /// Whether the current user is DM-restricted (#176), read at load time.
  final bool Function() _isDmRestricted;

  /// Whether a counterparty is an approved official recipient (#176).
  final bool Function(String) _isApprovedRecipient;

  final List<String> _initialParticipantPubkeys;

  /// The conversation ID this preview is for.
  final String conversationId;

  /// Loads message count and resolves participant pubkeys if needed.
  ///
  /// The #176 gate runs BEFORE any repository read and checks only the
  /// route-provided pubkeys: resolving counterparties from the DB is itself
  /// a read of hidden request data, so a DM-restricted user arriving without
  /// route extras (a stale or direct `/inbox/message-requests/:id` URL)
  /// fails closed via the predicate's empty-list branch instead of being
  /// looked up. In-app navigation always passes extras, so only direct
  /// links are denied this way — the view bounces them to the inbox, where
  /// the filtered request list still reaches anything they may access.
  ///
  /// Re-entrant: the failure state's retry calls straight back in, which is
  /// why the first thing it does is go back to [RequestPreviewStatus.loading].
  /// Without that, a second failure emits an `error` state equal to the one
  /// already showing, Cubit suppresses it, and the retry produces no spinner
  /// and no signal that it failed again (#7443 review). Guarded on the current
  /// status rather than emitted unconditionally, because Cubit lets the very
  /// first emit through even when it equals the initial state — the cold-start
  /// call would otherwise cost every entry an extra rebuild.
  Future<void> load() async {
    if (isClosed) return;
    if (state.status != RequestPreviewStatus.loading) {
      emit(state.copyWith(status: RequestPreviewStatus.loading));
    }

    try {
      if (_isDmRestricted() &&
          !allParticipantsApprovedForMinor(
            _initialParticipantPubkeys,
            _isApprovedRecipient,
          )) {
        if (!isClosed) {
          emit(state.copyWith(status: RequestPreviewStatus.denied));
        }
        return;
      }

      // Use provided pubkeys if available, otherwise load from DB. Only
      // non-restricted users reach the DB fallback: a restricted user with
      // empty extras was already denied above.
      final pubkeys = _initialParticipantPubkeys.isNotEmpty
          ? _initialParticipantPubkeys
          : await _resolveParticipants();

      final messageCount = await _dmRepository.countMessagesInConversation(
        conversationId,
      );
      final messages = await _dmRepository.getMessages(
        conversationId,
        limit: 10,
      );

      if (!isClosed) {
        emit(
          state.copyWith(
            status: RequestPreviewStatus.loaded,
            messageCount: messageCount,
            participantPubkeys: pubkeys,
            messages: messages,
          ),
        );
      }
    } catch (e, stackTrace) {
      // Drift read failures are expected. Per
      // .claude/rules/error_handling.md they are NOT Reportable.
      addError(e, stackTrace);
      if (!isClosed) {
        emit(state.copyWith(status: RequestPreviewStatus.error));
      }
    }
  }

  Future<List<String>> _resolveParticipants() async {
    final conversation = await _dmRepository.getConversation(conversationId);
    if (conversation == null) return [];
    final userPubkey = _dmRepository.userPubkey;
    return dmConversationPeerPubkeys(
      participantPubkeys: conversation.participantPubkeys,
      currentUserPubkey: userPubkey,
    );
  }
}
