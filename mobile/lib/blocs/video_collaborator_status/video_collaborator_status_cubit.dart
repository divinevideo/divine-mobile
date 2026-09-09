// ABOUTME: Cubit that exposes per-video collaborator confirmation status.
// ABOUTME: Keyed by videoAddress; wraps CollaboratorConfirmationRepository.

import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:collaborator_repository/collaborator_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:models/models.dart';
import 'package:unified_logger/unified_logger.dart';

part 'video_collaborator_status_state.dart';

/// One cubit per video address. Constructed inside a `BlocProvider`
/// scoped to the rendering surface; closes the underlying repository
/// reference on dispose.
class VideoCollaboratorStatusCubit extends Cubit<VideoCollaboratorStatusState> {
  VideoCollaboratorStatusCubit({
    required CollaboratorConfirmationRepository repository,
    required String videoAddress,
    required String creatorPubkey,
    required List<String> taggedPubkeys,
  }) : _repository = repository,
       _videoAddress = videoAddress,
       _creatorPubkey = creatorPubkey,
       _taggedPubkeys = taggedPubkeys,
       super(const VideoCollaboratorStatusState()) {
    _subscribe();
  }

  final CollaboratorConfirmationRepository _repository;
  final String _videoAddress;
  final String _creatorPubkey;
  final List<String> _taggedPubkeys;

  StreamSubscription<VideoCollaboratorStatus>? _subscription;

  void _subscribe() {
    _subscription = _repository
        .watch(
          _videoAddress,
          creatorPubkey: _creatorPubkey,
          taggedPubkeys: _taggedPubkeys,
        )
        .listen(
          (snapshot) {
            if (isClosed) return;
            emit(
              state.copyWith(
                load: VideoCollaboratorStatusLoad.ready,
                statusByPubkey: snapshot.statusByPubkey,
                isResolved: snapshot.isResolved,
              ),
            );
          },
          onError: (Object error, StackTrace stackTrace) {
            Log.warning(
              'VideoCollaboratorStatusCubit stream error for $_videoAddress: '
              '$error',
              name: 'VideoCollaboratorStatusCubit',
              category: LogCategory.system,
            );
            if (isClosed) return;
            addError(error, stackTrace);
            emit(state.copyWith(load: VideoCollaboratorStatusLoad.failure));
          },
        );
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    _repository.release(_videoAddress);
    return super.close();
  }
}
