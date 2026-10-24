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
    test('analyzes the exported window of an 8.14-second recording', () {
      final clip = _clip('long').copyWith(
        duration: const Duration(milliseconds: 8140),
      );
      final input = LoopRepairInputMapper.fromComposition(
        [clip],
        composition: const {},
      );

      expect(input.capability, LoopRepairCapability.supported);
      expect(input.clips.single.sourceStart, Duration.zero);
      expect(input.clips.single.sourceEnd, const Duration(milliseconds: 6300));
      expect(clip.duration, const Duration(milliseconds: 8140));
      expect(clip.trimEnd, Duration.zero);
    });

    test('export window respects a source trim and uniform playback speed', () {
      final clip = _clip('long').copyWith(
        duration: const Duration(seconds: 20),
        trimStart: const Duration(seconds: 1),
        trimEnd: const Duration(seconds: 2),
        playbackSpeed: 2,
      );
      final input = LoopRepairInputMapper.fromComposition(
        [clip],
        composition: const {},
      );

      expect(input.capability, LoopRepairCapability.supported);
      expect(input.clips.single.sourceStart, const Duration(seconds: 1));
      expect(input.clips.single.sourceEnd, const Duration(milliseconds: 13600));
      expect(input.clips.single.speed, 2);
    });

    test('only clips contributing to the export enter loop analysis', () {
      final clips = [
        _clip('first').copyWith(duration: const Duration(seconds: 4)),
        _clip('last').copyWith(duration: const Duration(seconds: 4)),
        _clip('outside').copyWith(isPlaceholder: true),
      ];
      final input = LoopRepairInputMapper.fromComposition(
        clips,
        composition: const {},
      );

      expect(input.capability, LoopRepairCapability.supported);
      expect(input.clips.map((clip) => clip.clipId), ['first', 'last']);
      expect(input.clips.last.sourceEnd, const Duration(milliseconds: 2300));
      expect(clips, hasLength(3));
    });

    test(
      'a fractional-speed cutoff stays within the native analysis bound',
      () {
        final input = LoopRepairInputMapper.fromComposition(
          [
            _clip('first')
                .copyWith(duration: const Duration(microseconds: 5299997)),
            _clip('slow').copyWith(playbackSpeed: .5),
          ],
          composition: const {},
        );
        final duration = input.clips.fold(
          Duration.zero,
          (total, clip) => total + clip.visibleDuration,
        );

        expect(input.capability, LoopRepairCapability.supported);
        expect(duration, lessThanOrEqualTo(const Duration(milliseconds: 6300)));
        expect(duration, greaterThan(const Duration(milliseconds: 6299)));
      },
    );

    test(
      'a repaired prefix cannot pull hidden trailing clips into the export',
      () {
        final first = _clip('first')
            .copyWith(duration: const Duration(seconds: 4));
        final last = _clip('last')
            .copyWith(duration: const Duration(seconds: 4));
        final outside = _clip('outside');
        final original = [first, last, outside];
        final result = LoopRepairInputMapper.applyResult(
          original,
          _trimResult([
            first,
            last.copyWith(trimEnd: const Duration(milliseconds: 1700)),
          ], 100),
          operationId: 'prefix-repair',
        );

        expect(result.map((clip) => clip.id), ['first', 'last']);
        expect(result.first.playbackDuration, const Duration(seconds: 4));
        expect(
          result.last.playbackDuration,
          const Duration(milliseconds: 2200),
        );
        expect(original, [first, last, outside]);
        expect(last.trimEnd, Duration.zero);
        expect(result.last.loopAlignment?.sourceDuration, last.duration);
        expect(
          result.expand((clip) => clip.ownedFilePaths),
          contains('/documents/outside.mp4'),
        );
        final restored = result
            .map(
              (clip) => DivineVideoClip.fromJson(clip.toJson(), '/relocated'),
            )
            .toList();
        expect(
          restored.expand((clip) => clip.ownedFilePaths),
          contains('/relocated/outside.mp4'),
        );
        final transformed = restored.first.copyWith(
          id: 'split',
          clearLoopAlignment: true,
        );
        expect(transformed.ownedFilePaths, contains('/relocated/outside.mp4'));
        final repairedAgain = LoopRepairInputMapper.applyResult(
          restored,
          _trimResult(restored, 0),
          operationId: 'repeat-repair',
        );
        expect(
          repairedAgain.expand((clip) => clip.ownedFilePaths),
          contains('/relocated/outside.mp4'),
        );
      },
    );

    test(
      'applies a repair of the export window and retains the full source',
      () {
        final clip = _clip('long').copyWith(
          duration: const Duration(milliseconds: 8140),
        );
        final exportClip = clip.copyWith(
          trimEnd: const Duration(milliseconds: 1840),
        );
        final result = LoopRepairInputMapper.applyResult(
          [clip],
          _trimResult([exportClip], 0),
          operationId: 'long-repair',
        );

        expect(result.single.duration, const Duration(milliseconds: 6300));
        expect(result.single.loopAlignment?.sourceDuration, clip.duration);
        expect(result.single.ownedFilePaths, contains('/documents/long.mp4'));
        expect(clip.duration, const Duration(milliseconds: 8140));
      },
    );

    test('repair trim limits apply within the export window', () {
      final clip = _clip('long').copyWith(
        duration: const Duration(milliseconds: 8140),
      );
      final exportClip = clip.copyWith(
        trimEnd: const Duration(milliseconds: 1840),
      );
      final result = LoopRepairInputMapper.applyResult(
        [clip],
        _trimResult([exportClip], 100),
        operationId: 'long-repair',
      );

      expect(result.single.duration, const Duration(milliseconds: 6200));
      expect(
        () => LoopRepairInputMapper.applyResult(
          [clip],
          _trimResult([exportClip], 201),
          operationId: 'invalid-repair',
        ),
        throwsStateError,
      );
    });

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
