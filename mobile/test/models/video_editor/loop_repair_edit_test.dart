import 'package:flutter_test/flutter_test.dart';
import 'package:loop_alignment_repository/loop_alignment_repository.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/loop_repair_input.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show EditorVideo;

DivineVideoClip _clip(String id) => DivineVideoClip(
  id: id,
  video: EditorVideo.file('/documents/$id.mp4'),
  duration: const Duration(seconds: 4),
  recordedAt: DateTime(2026),
  targetAspectRatio: .vertical,
  originalAspectRatio: 9 / 16,
  trimStart: const Duration(seconds: 1),
  trimEnd: const Duration(seconds: 1),
  playbackSpeed: 2,
  volume: .5,
);
const _edge = LoopBoundarySupport(agreeing: 8, retained: 8);
const _match = LoopFrameMatch(
  pose: LoopPose.identity,
  consistentCount: 30,
  retainedCount: 30,
  occupiedCells: 9,
  widthSpan: .8,
  heightSpan: .8,
  withheldCount: 10,
  withheldMedianError: 0,
  boundaryModelError: 0,
  left: _edge,
  right: _edge,
  top: _edge,
  bottom: _edge,
);
LoopRepairResult _result(List<DivineVideoClip> clips, {int trimMs = 0}) =>
    LoopRepairResult(
      status: LoopRepairStatus.repaired,
      output: LoopRenderedOutput(
        paths: {
          for (final clip in clips)
            clip.id: '/documents/${clip.id}_aligned.mp4',
        },
        metadata: const {},
      ),
      plan: LoopAlignmentPlan(
        clips: [
          for (var i = 0; i < clips.length; i++)
            LoopClipPlan(
              clipId: clips[i].id,
              sourceStart: clips[i].trimStart,
              sourceEnd:
                  clips[i].duration -
                  clips[i].trimEnd -
                  Duration(milliseconds: i == clips.length - 1 ? trimMs : 0),
              keyframes: const [],
            ),
        ],
        zoom: 1.02,
        confidence: _match,
        predictedScores: const LoopSeamScores(difference: .01, motion: 0),
        baselineScores: const LoopSeamScores(difference: .04, motion: .01),
      ),
    );
void main() {
  group('Loop repair edit application', () {
    test(
      'replacement preserves cuts, playback timing, source credits and sound',
      () {
        final clips = [_clip('first'), _clip('last')];
        final result = LoopRepairInputMapper.applyResult(
          clips,
          _result(clips),
          operationId: 'repair-1',
        );
        for (var i = 0; i < result.length; i++) {
          final clip = result[i];
          expect(clip.id, clips[i].id);
          expect(clip.playbackDuration, const Duration(seconds: 1));
          expect(clip.playbackSpeed, 2);
          expect(clip.volume, .5);
          expect(clip.trimStart, Duration.zero);
          expect(clip.duration, const Duration(seconds: 2));
          expect(clip.sourceStartOffset, const Duration(seconds: 1));
          expect(clip.loopAlignment?.sourcePath, '/documents/${clip.id}.mp4');
          expect(clip.signingSources?.single.path, '/documents/${clip.id}.mp4');
          expect(clip.ownedFilePaths, contains('/documents/${clip.id}.mp4'));
        }
        expect(clips.first.video?.file?.path, '/documents/first.mp4');
      },
    );
    test('bounded final trim does not move the preceding cut', () {
      final clips = [_clip('first'), _clip('last')];
      final result = LoopRepairInputMapper.applyResult(
        clips,
        _result(clips, trimMs: 100),
        operationId: 'repair-1',
      );
      expect(result.first.playbackDuration, const Duration(seconds: 1));
      expect(result.last.playbackDuration, const Duration(milliseconds: 950));
      expect(
        () => LoopRepairInputMapper.applyResult(
          clips,
          _result(clips, trimMs: 401),
          operationId: 'repair-1',
        ),
        throwsStateError,
      );
    });
    test('incomplete output cannot partially replace a composition', () {
      final clips = [_clip('first'), _clip('last')];
      final complete = _result(clips);
      final partial = LoopRepairResult(
        status: .repaired,
        plan: complete.plan,
        output: LoopRenderedOutput(
          paths: const {'first': '/documents/out.mp4'},
          metadata: const {},
        ),
      );
      expect(
        () => LoopRepairInputMapper.applyResult(
          clips,
          partial,
          operationId: 'repair-1',
        ),
        throwsStateError,
      );
      expect(clips.last.video?.file?.path, '/documents/last.mp4');
    });
    test(
      'clip bloc applies replacements atomically and rejects a stale snapshot',
      () async {
        final clips = [_clip('first'), _clip('last')];
        final bloc = ClipEditorBloc(
          onFinalClipInvalidated: () {},
          saveClipToLibrary: ({required clip}) async => false,
        );
        addTearDown(bloc.close);
        final initialized = bloc.stream.firstWhere((s) => s.clips.isNotEmpty);
        bloc.add(ClipEditorInitialized(clips));
        await initialized;
        final applied = bloc.stream.firstWhere((s) => s.lastLoopRepair != null);
        bloc.add(
          ClipEditorLoopRepairApplied(
            expectedClips: clips,
            result: _result(clips),
            operationId: 'first-operation',
          ),
        );
        final state = await applied;
        expect(state.lastLoopRepair, isA<ClipLoopRepairSuccess>());
        expect(state.clips.map((c) => c.video?.file?.path), [
          '/documents/first_aligned.mp4',
          '/documents/last_aligned.mp4',
        ]);
        final current = state.clips;
        final stale = bloc.stream.firstWhere(
          (s) => s.lastLoopRepair?.operationId == 'stale-operation',
        );
        bloc.add(
          ClipEditorLoopRepairApplied(
            expectedClips: clips,
            result: _result(clips),
            operationId: 'stale-operation',
          ),
        );
        expect((await stale).lastLoopRepair, isA<ClipLoopRepairDiscarded>());
        expect(bloc.state.clips, same(current));
      },
    );
  });
}
