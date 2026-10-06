import 'package:bloc/bloc.dart';
import 'package:openvine/blocs/go_live/go_live_state.dart';
import 'package:openvine/models/live/live_room.dart';
import 'package:openvine/models/live/live_session.dart';
import 'package:openvine/repositories/live_repository.dart';
import 'package:openvine/services/live_api_service.dart';

export 'package:openvine/blocs/go_live/go_live_state.dart';

class GoLiveCubit extends Cubit<GoLiveState> {
  GoLiveCubit({
    required LiveApiService liveApiService,
    required LiveRepository liveRepository,
    required String currentUserPubkey,
    String initialTitle = '',
    String initialSummary = '',
    String? initialImageUrl,
    DateTime Function()? now,
    String Function()? sessionIdBuilder,
  }) : _liveApiService = liveApiService,
       _liveRepository = liveRepository,
       _currentUserPubkey = currentUserPubkey,
       _now = now ?? DateTime.now,
       _sessionIdBuilder =
           sessionIdBuilder ??
           (() => DateTime.now().microsecondsSinceEpoch.toString()),
       super(
         GoLiveState(
           title: initialTitle,
           summary: initialSummary,
           imageUrl: initialImageUrl,
         ),
       );

  final LiveApiService _liveApiService;
  final LiveRepository _liveRepository;
  final String _currentUserPubkey;
  final DateTime Function() _now;
  final String Function() _sessionIdBuilder;

  void titleChanged(String title) {
    emit(
      state.copyWith(
        title: title,
        clearTitleError: true,
        clearErrorMessage: true,
      ),
    );
  }

  void summaryChanged(String summary) {
    emit(
      state.copyWith(
        summary: summary,
        clearErrorMessage: true,
      ),
    );
  }

  void imageUrlChanged(String? imageUrl) {
    final trimmedImageUrl = imageUrl?.trim();
    emit(
      state.copyWith(
        imageUrl: trimmedImageUrl,
        clearImageUrl: trimmedImageUrl == null || trimmedImageUrl.isEmpty,
        clearErrorMessage: true,
      ),
    );
  }

  Future<void> submit() async {
    final trimmedTitle = state.title.trim();
    if (trimmedTitle.isEmpty) {
      emit(
        state.copyWith(
          titleError: 'Enter a title to go live.',
          clearErrorMessage: true,
        ),
      );
      return;
    }

    final trimmedSummary = state.summary.trim();
    final trimmedImageUrl = state.imageUrl?.trim();

    emit(
      state.copyWith(
        status: GoLiveStatus.submitting,
        clearTitleError: true,
        clearErrorMessage: true,
      ),
    );

    try {
      final roomDraft = await _liveApiService.createRoomDraft(
        title: trimmedTitle,
        summary: trimmedSummary,
        imageUrl: trimmedImageUrl == null || trimmedImageUrl.isEmpty
            ? null
            : trimmedImageUrl,
      );
      final room = _normalizeRoom(
        draftRoom: roomDraft.room,
        title: trimmedTitle,
        summary: trimmedSummary,
        imageUrl: trimmedImageUrl,
      );

      if (roomDraft.status == LiveRoomDraftStatus.existingActive) {
        final session = roomDraft.activeSession!;
        emit(
          state.copyWith(
            status: GoLiveStatus.success,
            room: room,
            session: session,
            clearTitleError: true,
            clearErrorMessage: true,
          ),
        );
        return;
      }

      final session = LiveSession(
        id: _sessionIdBuilder(),
        roomId: room.id,
        status: LiveSessionStatus.live,
        startedAt: _now(),
        endedAt: null,
        speakerPubkeys: <String>[_currentUserPubkey],
        audienceCount: 0,
      );

      final publishedRoom = await _liveRepository.publishRoom(room);
      if (publishedRoom == null) {
        throw StateError('Live room publication failed');
      }
      await _liveApiService.startSession(
        roomId: room.id,
        sessionId: session.id,
      );
      try {
        final publishedSession = await _liveRepository.publishSession(
          session: session,
          roomAddress: room.address,
          hostPubkey: _currentUserPubkey,
        );
        if (publishedSession == null) {
          throw StateError('Live session publication failed');
        }
      } catch (_) {
        await _liveApiService.endSession(
          roomId: room.id,
          sessionId: session.id,
        );
        rethrow;
      }

      emit(
        state.copyWith(
          status: GoLiveStatus.success,
          room: room,
          session: session,
          clearTitleError: true,
          clearErrorMessage: true,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: GoLiveStatus.failure,
          errorMessage: '$error',
        ),
      );
    }
  }

  LiveRoom _normalizeRoom({
    required LiveRoom draftRoom,
    required String title,
    required String summary,
    required String? imageUrl,
  }) {
    return draftRoom.copyWith(
      hostPubkey: draftRoom.hostPubkey.isEmpty
          ? _currentUserPubkey
          : draftRoom.hostPubkey,
      title: draftRoom.title.isEmpty ? title : draftRoom.title,
      summary: draftRoom.summary.isEmpty ? summary : draftRoom.summary,
      imageUrl: draftRoom.imageUrl ?? imageUrl,
    );
  }
}
