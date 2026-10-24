import 'package:flutter_test/flutter_test.dart';
import 'package:loop_alignment_repository/loop_alignment_repository.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/loop_repair_input.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show EditorVideo;

DivineVideoClip _clip(String id) => DivineVideoClip(
  id: id,
  video: EditorVideo.file('/documents/$id.mp4'),
  duration: const Duration(seconds: 3),
  recordedAt: DateTime(2026),
  targetAspectRatio: .vertical,
  originalAspectRatio: 9 / 16,
);
const _boundary = LoopBoundarySupport(agreeing: 8, retained: 8);
LoopRepairResult _trimResult(List<DivineVideoClip> clips, int rawTrimMs) =>
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
                  Duration(milliseconds: i == clips.length - 1 ? rawTrimMs : 0),
              keyframes: const [],
            ),
        ],
        zoom: 1.02,
        confidence: const LoopFrameMatch(
          pose: LoopPose.identity,
          consistentCount: 24,
          retainedCount: 24,
          occupiedCells: 9,
          widthSpan: .8,
          heightSpan: .8,
          withheldCount: 8,
          withheldMedianError: 0,
          boundaryModelError: 0,
          left: _boundary,
          right: _boundary,
          top: _boundary,
          bottom: _boundary,
        ),
        predictedScores: const LoopSeamScores(difference: .01, motion: 0),
        baselineScores: const LoopSeamScores(difference: .04, motion: .01),
      ),
    );
void main() {
  group('Loop repair input mapping', () {
    test('input clip floor uses displayed duration for slow playback', () {
      final clips = [
        _clip('first'),
        _clip('short').copyWith(
          duration: const Duration(milliseconds: 35),
          playbackSpeed: .5,
        ),
      ];
      expect(
        LoopRepairInputMapper.fromComposition(
          clips,
          composition: const {},
        ).capability,
        LoopRepairCapability.supported,
      );
    });
    test(
      'slow playback accepts source windows below the displayed clip floor',
      () {
        final clips = [
          _clip('first'),
          _clip('last').copyWith(
            duration: const Duration(milliseconds: 70),
            playbackSpeed: .5,
          ),
        ];
        expect(
          LoopRepairInputMapper.fromComposition(
            clips,
            composition: const {},
          ).capability,
          LoopRepairCapability.supported,
        );
        final result = LoopRepairInputMapper.applyResult(
          clips,
          _trimResult(clips, 20),
          operationId: 'slow-repair',
        );
        expect(result.last.duration, const Duration(milliseconds: 50));
        expect(result.last.playbackDuration, const Duration(milliseconds: 100));
        expect(result.first.playbackDuration, clips.first.playbackDuration);
      },
    );
    test(
      'slow playback still rejects replacements under the displayed clip floor',
      () {
        final clips = [
          _clip('first'),
          _clip('last').copyWith(
            duration: const Duration(milliseconds: 70),
            playbackSpeed: .5,
          ),
        ];
        expect(
          () => LoopRepairInputMapper.applyResult(
            clips,
            _trimResult(clips, 41),
            operationId: 'slow-repair',
          ),
          throwsStateError,
        );
        expect(clips.last.duration, const Duration(milliseconds: 70));
        expect(clips.last.video?.file?.path, '/documents/last.mp4');
      },
    );
    test('trim cap uses displayed duration at twice source speed', () {
      final clips = [_clip('first'), _clip('last').copyWith(playbackSpeed: 2)];
      final result = LoopRepairInputMapper.applyResult(
        clips,
        _trimResult(clips, 300),
        operationId: 'repair',
      );
      expect(result.first.playbackDuration, clips.first.playbackDuration);
      expect(
        result.last.playbackDuration,
        clips.last.playbackDuration - const Duration(milliseconds: 150),
      );
      expect(result.last.playbackSpeed, 2);
      expect(clips.last.video?.file?.path, '/documents/last.mp4');
    });
    test('trim beyond displayed cap rejects the complete edit atomically', () {
      final clips = [_clip('first'), _clip('last').copyWith(playbackSpeed: 2)];
      expect(
        () => LoopRepairInputMapper.applyResult(
          clips,
          _trimResult(clips, 401),
          operationId: 'repair',
        ),
        throwsStateError,
      );
      expect(clips.map((clip) => clip.video?.file?.path), [
        '/documents/first.mp4',
        '/documents/last.mp4',
      ]);
      expect(clips.last.duration, const Duration(seconds: 3));
    });
    test(
      'request names current displayed source windows and uniform speed',
      () {
        final clip = _clip('a').copyWith(
          trimStart: const Duration(milliseconds: 500),
          trimEnd: const Duration(milliseconds: 200),
          playbackSpeed: 2,
        );
        final input = LoopRepairInputMapper.fromComposition(
          [clip],
          composition: const {'layers': [], 'audio': []},
        );
        expect(input.capability, LoopRepairCapability.supported);
        expect(input.clips.single.path, '/documents/a.mp4');
        expect(
          input.clips.single.sourceStart,
          const Duration(milliseconds: 500),
        );
        expect(
          input.clips.single.sourceEnd,
          const Duration(milliseconds: 2800),
        );
        expect(input.clips.single.speed, 2);
        expect(input.clips.single.width, 180);
        expect(input.clips.single.height, 320);
      },
    );
    test(
      'every composition edit changes the revision, selection does not enter it',
      () {
        final a = _clip('a');
        final b = _clip('b');
        String revision(List<DivineVideoClip> clips, Object extra) =>
            LoopRepairInputMapper.fromComposition(
              clips,
              composition: extra,
            ).revision;
        final original = revision([a, b], {'layers': [], 'audio': []});
        for (final clips in [
          [b, a],
          [a.copyWith(volume: .5), b],
          [a.copyWith(trimEnd: const Duration(milliseconds: 20)), b],
          [a.copyWith(video: EditorVideo.file('/documents/replaced.mp4')), b],
          [a.copyWith(playbackSpeed: 2), b],
        ]) {
          expect(revision(clips, {'layers': [], 'audio': []}), isNot(original));
        }
        expect(
          revision(
            [a, b],
            {
              'layers': [
                {'x': 1},
              ],
              'audio': [],
            },
          ),
          isNot(original),
        );
        expect(
          revision(
            [a, b],
            {
              'layers': [],
              'audio': [
                {'volume': .5},
              ],
            },
          ),
          isNot(original),
        );
        expect(revision([a, b], {'audio': [], 'layers': []}), original);
      },
    );
    test(
      'unsupported endpoint geometry is declined without starting a decode',
      () {
        for (final clip in [
          _clip('a').copyWith(isFreezeFrame: true),
          _clip('a').copyWith(isPlaceholder: true),
        ]) {
          expect(
            LoopRepairInputMapper.fromComposition([
              clip,
            ], composition: const {}).capability,
            LoopRepairCapability.unsupported,
          );
        }
        expect(
          LoopRepairInputMapper.fromComposition(
            [_clip('a')],
            composition: const {},
            hasSourceTrackedLayers: true,
          ).capability,
          LoopRepairCapability.unsupported,
        );
      },
    );
  });
}
