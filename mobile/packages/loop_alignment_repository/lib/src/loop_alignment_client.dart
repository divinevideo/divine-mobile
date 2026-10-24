import 'loop_alignment_models.dart';

abstract interface class LoopAlignmentClient {
  Future<LoopAnalysis> analyze(
    LoopRepairInput input,
    LoopAlignmentLimits limits,
    String taskId,
    void Function(double) onProgress,
  );
  Future<LoopRenderedOutput> render(
    LoopRepairInput input,
    LoopAlignmentPlan plan,
    String taskId,
    void Function(double) onProgress,
  );
  Future<LoopInspection> inspect(
    LoopRepairInput input,
    LoopAlignmentPlan plan,
    LoopRenderedOutput output,
    String taskId,
  );
  Future<void> cancel(String taskId);
  Future<void> discard(LoopRenderedOutput output);

  /// Releases operation bookkeeping after every terminal path.
  Future<void> finish(String taskId);
}
