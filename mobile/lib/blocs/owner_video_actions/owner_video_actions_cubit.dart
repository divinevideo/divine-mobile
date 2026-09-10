// ABOUTME: Cubit for owner-only video actions such as deleting own videos.
// ABOUTME: Keeps service-layer calls out of feed UI widgets.

import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:openvine/repositories/creator_delete_enforcement_repository.dart';
import 'package:openvine/services/content_deletion_service.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:unified_logger/unified_logger.dart';

enum OwnerVideoDeleteStatus { idle, deleting, success, failure }

enum OwnerVideoCleanupStatus {
  idle,
  inProgress,
  confirmed,
  delayed,
  failed,
  unavailable,
}

enum OwnerVideoDeleteStart { started, busy }

class OwnerVideoOperationState extends Equatable {
  const OwnerVideoOperationState({
    this.deleteStatus = OwnerVideoDeleteStatus.idle,
    this.cleanupStatus = OwnerVideoCleanupStatus.idle,
    this.deleteResult,
  });

  final OwnerVideoDeleteStatus deleteStatus;
  final OwnerVideoCleanupStatus cleanupStatus;
  final DeleteResult? deleteResult;

  @override
  List<Object?> get props => [
    deleteStatus,
    cleanupStatus,
    deleteResult?.success,
    deleteResult?.failureKind,
    deleteResult?.acceptance,
    deleteResult?.deleteEventId,
    deleteResult?.error,
  ];
}

class OwnerVideoActionsState extends Equatable {
  const OwnerVideoActionsState({this.operations = const {}});

  final Map<String, OwnerVideoOperationState> operations;

  OwnerVideoOperationState forVideo(String videoId) =>
      operations[videoId] ?? const OwnerVideoOperationState();

  OwnerVideoActionsState withVideo(
    String videoId,
    OwnerVideoOperationState operation,
  ) => OwnerVideoActionsState(operations: {...operations, videoId: operation});

  @override
  List<Object?> get props => [operations];
}

class OwnerVideoActionsCubit extends Cubit<OwnerVideoActionsState>
    with CloseGuardedEmit<OwnerVideoActionsState> {
  OwnerVideoActionsCubit({
    required Future<ContentDeletionService> Function() contentDeletionService,
    required VideoEventService Function() videoEventService,
    required CreatorDeleteEnforcementRepository Function()
    enforcementRepository,
  }) : _contentDeletionService = contentDeletionService,
       _videoEventService = videoEventService,
       _enforcementRepository = enforcementRepository,
       super(const OwnerVideoActionsState());

  final Future<ContentDeletionService> Function() _contentDeletionService;
  final VideoEventService Function() _videoEventService;
  final CreatorDeleteEnforcementRepository Function() _enforcementRepository;
  final Map<String, Completer<OwnerVideoOperationState>> _cleanupCompleters =
      {};

  Future<OwnerVideoOperationState>? cleanupCompletionFor(String videoId) =>
      _cleanupCompleters[videoId]?.future;

  bool isDeleteInProgress(String videoId) {
    final operation = state.forVideo(videoId);
    return operation.deleteStatus == OwnerVideoDeleteStatus.deleting ||
        operation.cleanupStatus == OwnerVideoCleanupStatus.inProgress;
  }

  Future<OwnerVideoDeleteStart> deleteVideo(VideoEvent video) async {
    if (isDeleteInProgress(video.id)) {
      return OwnerVideoDeleteStart.busy;
    }

    emit(
      state.withVideo(
        video.id,
        const OwnerVideoOperationState(
          deleteStatus: OwnerVideoDeleteStatus.deleting,
        ),
      ),
    );

    try {
      // Resolve widget-owned provider reads before the first suspension point.
      // The returned services outlive the initiating surface, so relay success
      // can still update local state and trigger cleanup after that surface
      // closes.
      final deletionServiceFuture = _contentDeletionService();
      final videoEventService = _videoEventService();
      final enforcementRepository = _enforcementRepository();
      final deletionService = await deletionServiceFuture;
      final result = await deletionService.quickDelete(
        video: video,
        reason: DeleteReason.personalChoice,
      );

      if (result.success) {
        videoEventService.removeVideoEventCompletely(video);
        _cleanupCompleters[video.id] = Completer<OwnerVideoOperationState>();
        emitIfOpen(
          state.withVideo(
            video.id,
            OwnerVideoOperationState(
              deleteStatus: OwnerVideoDeleteStatus.success,
              cleanupStatus: OwnerVideoCleanupStatus.inProgress,
              deleteResult: result,
            ),
          ),
        );
        unawaited(_confirmCleanup(video.id, result, enforcementRepository));
      } else {
        emitIfOpen(
          state.withVideo(
            video.id,
            OwnerVideoOperationState(
              deleteStatus: OwnerVideoDeleteStatus.failure,
              deleteResult: result,
            ),
          ),
        );
      }
    } catch (e, stackTrace) {
      Log.error(
        'Failed to delete video: $e',
        name: 'OwnerVideoActionsCubit',
        category: LogCategory.ui,
      );
      addError(Reportable(e, context: 'deleteVideo'), stackTrace);
      emitIfOpen(
        state.withVideo(
          video.id,
          OwnerVideoOperationState(
            deleteStatus: OwnerVideoDeleteStatus.failure,
            deleteResult: DeleteResult.failure(
              'Failed to delete video',
              DeleteFailureKind.unknown,
            ),
          ),
        ),
      );
    }
    return OwnerVideoDeleteStart.started;
  }

  Future<void> _confirmCleanup(
    String videoId,
    DeleteResult deleteResult,
    CreatorDeleteEnforcementRepository enforcementRepository,
  ) async {
    var cleanupStatus = OwnerVideoCleanupStatus.delayed;
    try {
      final deleteEventId = deleteResult.deleteEventId;
      if (deleteEventId == null) {
        throw StateError('Successful delete result has no delete event ID');
      }
      final result = await enforcementRepository.enforce(deleteEventId);
      cleanupStatus = switch (result.status) {
        CreatorDeleteEnforcementStatus.confirmed =>
          OwnerVideoCleanupStatus.confirmed,
        CreatorDeleteEnforcementStatus.delayed =>
          OwnerVideoCleanupStatus.delayed,
        CreatorDeleteEnforcementStatus.failed => OwnerVideoCleanupStatus.failed,
        CreatorDeleteEnforcementStatus.unavailable =>
          OwnerVideoCleanupStatus.unavailable,
      };
    } on Object catch (error, stackTrace) {
      Log.error(
        'Failed to confirm creator-delete cleanup: $error',
        name: 'OwnerVideoActionsCubit',
        category: LogCategory.ui,
      );
      addError(Reportable(error, context: 'confirmCleanup'), stackTrace);
    }
    final terminalState = OwnerVideoOperationState(
      deleteStatus: OwnerVideoDeleteStatus.success,
      cleanupStatus: cleanupStatus,
      deleteResult: deleteResult,
    );
    _cleanupCompleters.remove(videoId)?.complete(terminalState);
    emitIfOpen(state.withVideo(videoId, terminalState));
  }
}
