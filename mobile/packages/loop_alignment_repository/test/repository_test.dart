import 'package:loop_alignment_repository/loop_alignment_repository.dart';
import 'package:test/test.dart';

import 'helpers/generated_scene.dart';

void main() {
  test('uncertain blank scene is no match and always finishes', () async {
    final client = FakeClient();
    final result = await run(client);
    expect(result.status, LoopRepairStatus.noMatch);
    expect(client.finished, ['a']);
  });
  test(
    'unchanged duration wins before a trim, even if supplied last',
    () async {
      final client = FakeClient()
        ..candidates = [plan(trim: const Duration(milliseconds: 900)), plan()];
      final result = await run(client);
      expect(result.status, LoopRepairStatus.repaired);
      expect(result.plan!.trimmedSourceEnd, isNull);
      expect(client.rendered.length, 1);
    },
  );
  test(
    'non-frame trim and excessive trim and extension never render',
    () async {
      final client = FakeClient()
        ..candidates = [
          plan(trim: const Duration(milliseconds: 899)),
          plan(trim: const Duration(milliseconds: 700)),
          plan(trim: const Duration(milliseconds: 1100)),
        ];
      expect((await run(client)).status, LoopRepairStatus.noMatch);
      expect(client.rendered, isEmpty);
    },
  );
  test('trim-only candidate passes the same score gates', () async {
    final client = FakeClient()
      ..candidates = [plan(trim: const Duration(milliseconds: 900))];
    expect((await run(client)).status, LoopRepairStatus.repaired);
  });
  test('post-render bad seam deletes replacement', () async {
    final client = FakeClient()
      ..candidates = [plan()]
      ..inspectionScores = const LoopSeamScores(difference: .04, motion: 0);
    expect((await run(client)).status, LoopRepairStatus.noMatch);
    expect(client.discarded.length, 1);
  });
  test('inspection exception deletes replacement and finishes', () async {
    final client = FakeClient()
      ..candidates = [plan()]
      ..inspectionFails = true;
    await expectLater(run(client), throwsA(isA<LoopAlignmentFailure>()));
    expect(client.discarded.length, 1);
    expect(client.finished, ['a']);
  });
  test('output wrong duration is rejected', () async {
    final client = FakeClient()
      ..candidates = [plan()]
      ..badDuration = true;
    expect((await run(client)).status, LoopRepairStatus.noMatch);
    expect(client.discarded.length, 1);
  });
  test(
    'already smooth requires confident registration and four ordinary samples',
    () async {
      final client = FakeClient()..smooth = true;
      expect((await run(client)).status, LoopRepairStatus.alreadySmooth);
      expect(client.rendered, isEmpty);
    },
  );
  test('only three ordinary samples cannot claim already smooth', () async {
    final client = FakeClient()
      ..smooth = true
      ..samples = 3;
    expect((await run(client)).status, LoopRepairStatus.noMatch);
  });
  test(
    'cancellation during inspection cannot return a repaired output',
    () async {
      final client = FakeClient()..candidates = [plan()];
      final repository = LoopAlignmentRepository(client: client);
      client.duringInspection = () => repository.cancel('a');
      await expectLater(
        repository.repair(
          LoopRepairInput(
            clips: [clip('a', end: const Duration(seconds: 1))],
            revision: 'a',
          ),
          taskId: 'a',
        ),
        throwsA(isA<LoopAlignmentCancelled>()),
      );
      expect(client.discarded.length, 1);
      expect(client.finished, ['a']);
    },
  );
}

Future<LoopRepairResult> run(FakeClient c) =>
    LoopAlignmentRepository(client: c).repair(
      LoopRepairInput(
        clips: [clip('a', end: const Duration(seconds: 1))],
        revision: 'a',
      ),
      taskId: 'a',
    );
LoopAlignmentPlan plan({Duration? trim}) => LoopAlignmentPlan(
  clips: [
    LoopClipPlan(
      clipId: 'a',
      sourceStart: Duration.zero,
      sourceEnd: trim ?? const Duration(seconds: 1),
      keyframes: const [],
    ),
  ],
  zoom: 1,
  confidence: evidence(LoopPose.identity),
  predictedScores: const LoopSeamScores(difference: .01, motion: 0),
  baselineScores: const LoopSeamScores(difference: .05, motion: .1),
  trimmedSourceEnd: trim,
);

class FakeClient implements LoopAlignmentClient {
  final finished = <String>[];
  final rendered = <LoopAlignmentPlan>[];
  final discarded = <LoopRenderedOutput>[];
  List<LoopAlignmentPlan> candidates = [];
  bool smooth = false, inspectionFails = false, badDuration = false;
  int samples = 4;
  Future<void> Function()? duringInspection;
  LoopSeamScores inspectionScores = const LoopSeamScores(
    difference: .01,
    motion: 0,
  );
  @override
  Future<LoopAnalysis> analyze(
    LoopRepairInput i,
    LoopAlignmentLimits l,
    String id,
    void Function(double) p,
  ) async => LoopAnalysis(
    baselineScores: LoopSeamScores(difference: smooth ? 0 : .05, motion: 0),
    candidates: candidates,
    endpointRegistration: smooth ? evidence(LoopPose.identity) : null,
    endpointWidth: 320,
    endpointHeight: 192,
    ordinaryMotionSamples: samples,
    eligibleTrimEnds: const [Duration(milliseconds: 900)],
  );
  @override
  Future<void> finish(String id) async {
    finished.add(id);
  }

  @override
  Future<void> cancel(String id) async {}
  @override
  Future<void> discard(LoopRenderedOutput o) async {
    discarded.add(o);
  }

  @override
  Future<LoopRenderedOutput> render(
    LoopRepairInput i,
    LoopAlignmentPlan p,
    String id,
    void Function(double) progress,
  ) async {
    rendered.add(p);
    return LoopRenderedOutput(
      paths: {'a': '/output/a.mp4'},
      metadata: {
        'a': LoopMediaMetadata(
          videoDuration: badDuration
              ? const Duration(seconds: 2)
              : p.clips.single.sourceEnd,
          audioDuration: null,
          frameTimes: const [
            Duration.zero,
            Duration(milliseconds: 100),
            Duration(milliseconds: 200),
          ],
          width: 160,
          height: 96,
        ),
      },
    );
  }

  @override
  Future<LoopInspection> inspect(
    LoopRepairInput i,
    LoopAlignmentPlan p,
    LoopRenderedOutput o,
    String id,
  ) async {
    if (inspectionFails) throw const LoopAlignmentFailure('inspection');
    await duringInspection?.call();
    return LoopInspection(
      scores: inspectionScores,
      frameTimes: const [
        Duration.zero,
        Duration(milliseconds: 100),
        Duration(milliseconds: 200),
      ],
      audioDuration: null,
      videoDuration: p.clips.single.sourceEnd,
      covered: true,
    );
  }
}
