// ABOUTME: Coordinates cancellable loop repair and rejects late work after
// ABOUTME: composition changes, cancellation, or editor teardown.

import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:loop_alignment_repository/loop_alignment_repository.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:uuid/uuid.dart';

part 'loop_suggestion_state.dart';

class LoopSuggestionCubit extends Cubit<LoopSuggestionState>
    with CloseGuardedEmit<LoopSuggestionState> {
  LoopSuggestionCubit({
    required LoopAlignmentRepository repository,
    String Function()? newTaskId,
  }) : _repository = repository,
       _newTaskId = newTaskId ?? const Uuid().v4,
       super(const LoopSuggestionState());

  final LoopAlignmentRepository _repository;
  final String Function() _newTaskId;

  bool _owns(String taskId) => !isClosed && state.taskId == taskId;

  Future<void> fix(LoopRepairInput input) async {
    if (isClosed || state.status != LoopSuggestionStatus.idle) return;
    final taskId = 'loop_repair_${_newTaskId()}';
    emit(
      LoopSuggestionState(
        status: LoopSuggestionStatus.searching,
        taskId: taskId,
        request: input,
      ),
    );
    try {
      final result = await _repository.repair(
        input,
        taskId: taskId,
        onProgress: (progress) {
          if (_owns(taskId) && state.isSearching && progress.isFinite) {
            emit(state.withProgress(progress.clamp(0, 1)));
          }
        },
      );
      if (!_owns(taskId)) {
        await discard(result);
        return;
      }
      emitIfOpen(
        LoopSuggestionState(
          status: switch (result.status) {
            LoopRepairStatus.repaired => LoopSuggestionStatus.repaired,
            LoopRepairStatus.alreadySmooth =>
              LoopSuggestionStatus.alreadySmooth,
            LoopRepairStatus.noMatch => LoopSuggestionStatus.noMatch,
            LoopRepairStatus.unsupported => LoopSuggestionStatus.unsupported,
          },
          taskId: taskId,
          request: input,
          result: result,
          progress: 1,
        ),
      );
    } on LoopAlignmentCancelled {
      if (_owns(taskId)) emitIfOpen(const LoopSuggestionState());
    } catch (error, stack) {
      if (!_owns(taskId)) return;
      addError(error, stack);
      emitIfOpen(
        LoopSuggestionState(
          status: error is LoopAlignmentTimeout
              ? LoopSuggestionStatus.timedOut
              : LoopSuggestionStatus.failed,
          taskId: taskId,
          request: input,
        ),
      );
    }
  }

  /// Invalidates synchronously, before awaiting native cancellation. Old
  /// progress/completion and a late cancel can never change a new operation.
  Future<void> cancel() async {
    final previous = state;
    if (isClosed || previous.status == LoopSuggestionStatus.idle) return;
    emit(const LoopSuggestionState());
    try {
      if (previous.isSearching && previous.taskId != null) {
        await _repository.cancel(previous.taskId!);
      } else if (previous.result case final result?) {
        await discard(result);
      }
    } catch (error, stack) {
      if (!isClosed) addError(error, stack);
    }
  }

  void compositionChanged(String revision) {
    if (state.request == null || state.request!.revision == revision) return;
    unawaited(
      cancel().catchError((Object error, StackTrace stack) {
        if (!isClosed) addError(error, stack);
      }),
    );
  }

  /// Transfers a delivered result's ownership to the editor's application
  /// listener, which must discard it if the atomic application is rejected.
  void resultHandled() {
    if (isClosed || state.isSearching) return;
    emit(const LoopSuggestionState());
  }

  Future<void> discard(LoopRepairResult result) => _repository.discard(result);

  @override
  Future<void> close() async {
    final previous = state;
    final closing = super.close();
    try {
      if (previous.isSearching && previous.taskId != null) {
        await _repository.cancel(previous.taskId!);
      } else if (previous.result case final result?) {
        await discard(result);
      }
    } catch (error) {
      Log.warning(
        'Loop repair teardown could not finish: $error',
        name: 'LoopSuggestionCubit',
        category: LogCategory.video,
      );
    } finally {
      await closing;
    }
  }
}
