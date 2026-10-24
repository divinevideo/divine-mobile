import 'loop_alignment_client.dart';
import 'loop_alignment_models.dart';

/// Owns candidate ordering and the acceptance of measured native output.
class LoopAlignmentRepository {
  LoopAlignmentRepository({
    required this.client,
    this.limits = const LoopAlignmentLimits(),
  });
  final LoopAlignmentClient client;
  final LoopAlignmentLimits limits;
  final _cancelled = <String>{};
  Future<void> cancel(String taskId) {
    _cancelled.add(taskId);
    return client.cancel(taskId);
  }

  void _check(String taskId) {
    if (_cancelled.contains(taskId)) throw const LoopAlignmentCancelled();
  }

  Future<void> discard(LoopRepairResult result) async {
    final output = result.output;
    if (output != null) await client.discard(output);
  }

  Future<LoopRepairResult> repair(
    LoopRepairInput input, {
    required String taskId,
    void Function(double)? onProgress,
  }) async {
    _cancelled.remove(taskId);
    try {
      if (input.capability != LoopRepairCapability.supported) {
        return const LoopRepairResult(status: LoopRepairStatus.unsupported);
      }
      final analysis = await client.analyze(
        input,
        limits,
        taskId,
        (p) => onProgress?.call(p * .5),
      );
      _check(taskId);
      if (analysis.isAlreadySmooth(limits))
        return const LoopRepairResult(status: LoopRepairStatus.alreadySmooth);
      // Preserve the measured endpoint order within each policy tier. A
      // trim-only fallback must never hide a later viable camera alignment.
      final candidates = [
        for (final kind in LoopAlignmentKind.values)
          for (final trimmed in [false, true])
            for (final candidate in analysis.candidates)
              if (candidate.kind == kind &&
                  (candidate.trimmedSourceEnd != null) == trimmed)
                candidate,
      ];
      for (final plan in candidates) {
        _check(taskId);
        if (!_validPlan(input, plan, analysis) ||
            !limits.acceptsScores(plan.baselineScores, plan.predictedScores))
          continue;
        LoopRenderedOutput? output;
        var accepted = false;
        try {
          output = await client.render(
            input,
            plan,
            taskId,
            (p) => onProgress?.call(.5 + p * .4),
          );
          _check(taskId);
          final inspected = await client.inspect(input, plan, output, taskId);
          _check(taskId);
          accepted =
              inspected.covered &&
              limits.acceptsScores(plan.baselineScores, inspected.scores) &&
              _validInspection(input, plan, output, inspected);
          if (accepted) {
            accepted = false;
            onProgress?.call(1);
            _check(taskId);
            accepted = true;
            return LoopRepairResult(
              status: LoopRepairStatus.repaired,
              output: output,
              plan: plan,
            );
          }
        } finally {
          if (!accepted && output != null) await client.discard(output);
        }
      }
      _check(taskId);
      return const LoopRepairResult(status: LoopRepairStatus.noMatch);
    } finally {
      _cancelled.remove(taskId);
      await client.finish(taskId);
    }
  }

  bool _validPlan(
    LoopRepairInput input,
    LoopAlignmentPlan plan,
    LoopAnalysis analysis,
  ) {
    if (input.clips.isEmpty ||
        plan.clips.length != input.clips.length ||
        !plan.zoom.isFinite ||
        plan.zoom < 1 ||
        plan.zoom > limits.maximumZoom)
      return false;
    if (plan.kind == LoopAlignmentKind.trimOnly &&
        plan.trimmedSourceEnd == null)
      return false;
    if (plan.trimmedSourceEnd != null &&
        !analysis.eligibleTrimEnds.contains(plan.trimmedSourceEnd))
      return false;
    if (analysis.endpointWidth <= 0 ||
        analysis.endpointHeight <= 0 ||
        !limits.acceptsMatch(
          plan.confidence,
          analysis.endpointWidth,
          analysis.endpointHeight,
        ))
      return false;
    var duration = Duration.zero;
    for (var i = 0; i < input.clips.length; i++) {
      final source = input.clips[i], p = plan.clips[i];
      if (source.clipId != p.clipId ||
          p.sourceStart != source.sourceStart ||
          p.sourceEnd > source.sourceEnd ||
          p.sourceEnd <= p.sourceStart)
        return false;
      if (i != input.clips.length - 1 && p.sourceEnd != source.sourceEnd)
        return false;
      final removed = source.sourceEnd - p.sourceEnd;
      if (removed.inMicroseconds / source.speed >
              limits.maximumTrim.inMicroseconds ||
          (p.sourceEnd - p.sourceStart).inMicroseconds / source.speed <
              source.minimumDuration.inMicroseconds)
        return false;
      if (removed > Duration.zero && plan.trimmedSourceEnd != p.sourceEnd)
        return false;
      duration += Duration(
        microseconds:
            ((p.sourceEnd - p.sourceStart).inMicroseconds / source.speed)
                .round(),
      );
    }
    return duration >= input.minimumCompositionDuration;
  }

  bool _validInspection(
    LoopRepairInput input,
    LoopAlignmentPlan plan,
    LoopRenderedOutput output,
    LoopInspection inspection,
  ) {
    if (inspection.frameTimes.length < 2 ||
        output.paths.length != input.clips.length ||
        output.metadata.length != input.clips.length)
      return false;
    var expected = Duration.zero;
    for (var i = 0; i < input.clips.length; i++) {
      final c = input.clips[i],
          p = plan.clips[i],
          m = inspection.metadata[c.clipId] ?? output.metadata[c.clipId];
      if (output.paths[c.clipId] == null ||
          m == null ||
          m.frameTimes.length < 2)
        return false;
      for (var j = 1; j < m.frameTimes.length; j++) {
        if (m.frameTimes[j] <= m.frameTimes[j - 1]) return false;
      }
      final tolerance =
          m.frameTimes.last - m.frameTimes[m.frameTimes.length - 2];
      final wanted = p.sourceEnd - p.sourceStart;
      if ((m.videoDuration - wanted).abs() > tolerance ||
          m.width <= 0 ||
          m.height <= 0)
        return false;
      expected += Duration(
        microseconds: (wanted.inMicroseconds / c.speed).round(),
      );
    }
    for (var i = 1; i < inspection.frameTimes.length; i++) {
      if (inspection.frameTimes[i] <= inspection.frameTimes[i - 1])
        return false;
    }
    final tolerance =
        inspection.frameTimes.last -
        inspection.frameTimes[inspection.frameTimes.length - 2];
    return (inspection.videoDuration - expected).abs() <= tolerance;
  }
}
