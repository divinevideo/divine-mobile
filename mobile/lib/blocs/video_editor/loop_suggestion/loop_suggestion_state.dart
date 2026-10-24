part of 'loop_suggestion_cubit.dart';

enum LoopSuggestionStatus {
  idle,
  searching,
  repaired,
  alreadySmooth,
  noMatch,
  unsupported,
  failed,
  timedOut,
}

/// State owns request identity; the cubit holds only immutable dependencies.
class LoopSuggestionState extends Equatable {
  const LoopSuggestionState({
    this.status = LoopSuggestionStatus.idle,
    this.progress = 0,
    this.taskId,
    this.request,
    this.result,
  });
  final LoopSuggestionStatus status;
  final double progress;
  final String? taskId;
  final LoopRepairInput? request;
  final LoopRepairResult? result;
  bool get isSearching => status == LoopSuggestionStatus.searching;
  LoopSuggestionState withProgress(double value) => LoopSuggestionState(
    status: status,
    progress: value,
    taskId: taskId,
    request: request,
    result: result,
  );
  @override
  List<Object?> get props => [status, progress, taskId, request, result];
}
