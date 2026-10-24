import 'dart:async';

import 'package:loop_alignment_repository/loop_alignment_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_editor/loop_suggestion/loop_suggestion_cubit.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/loop_repair_input.dart';

class MockLoopAlignmentRepository extends Mock
    implements LoopAlignmentRepository {}

LoopAlignmentRepository noMatchLoopRepository() {
  final repository = MockLoopAlignmentRepository();
  return repository;
}

LoopSuggestionCubit pendingLoopCubit() {
  registerFallbackValue(LoopRepairInput(clips: const [], revision: 'fallback'));
  final repository = MockLoopAlignmentRepository();
  final result = Completer<LoopRepairResult>();
  when(
    () => repository.repair(
      any(),
      taskId: any(named: 'taskId'),
      onProgress: any(named: 'onProgress'),
    ),
  ).thenAnswer((_) => result.future);
  when(() => repository.cancel(any())).thenAnswer((_) async {
    if (!result.isCompleted) {
      result.completeError(const LoopAlignmentCancelled());
    }
  });
  return LoopSuggestionCubit(repository: repository);
}

void beginPendingLoop(LoopSuggestionCubit cubit, List<DivineVideoClip> clips) {
  unawaited(
    cubit.fix(
      LoopRepairInputMapper.fromComposition(clips, composition: const {}),
    ),
  );
}

LoopRepairResult repairedLoopResult(List<DivineVideoClip> clips) {
  const edge = LoopBoundarySupport(agreeing: 8, retained: 8);
  const match = LoopFrameMatch(
    pose: LoopPose.identity,
    consistentCount: 30,
    retainedCount: 30,
    occupiedCells: 9,
    widthSpan: .8,
    heightSpan: .8,
    withheldCount: 10,
    withheldMedianError: 0,
    boundaryModelError: 0,
    left: edge,
    right: edge,
    top: edge,
    bottom: edge,
  );
  return LoopRepairResult(
    status: .repaired,
    output: LoopRenderedOutput(
      paths: {for (final c in clips) c.id: '/documents/${c.id}_aligned.mp4'},
      metadata: const {},
    ),
    plan: LoopAlignmentPlan(
      clips: [
        for (final c in clips)
          LoopClipPlan(
            clipId: c.id,
            sourceStart: c.trimStart,
            sourceEnd: c.duration - c.trimEnd,
            keyframes: const [],
          ),
      ],
      zoom: 1.02,
      confidence: match,
      baselineScores: const LoopSeamScores(difference: .04, motion: .01),
      predictedScores: const LoopSeamScores(difference: .01, motion: 0),
    ),
  );
}
