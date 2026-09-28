import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/services/video_editor/loop_seam_bake_service.dart';
import 'package:openvine/services/video_editor/loop_seam_ramp.dart';
import 'package:openvine/services/video_editor/render_cancellation_registry.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

import 'loop_seam_test_scene.dart';

const _info = LoopSeamSourceInfo(
  resolution: Size(1080, 1920),
  duration: Duration(seconds: 6),
  frameRate: 30,
  hasAudio: true,
);

DivineVideoClip _clip(String id, {bool reversed = false, double? speed}) =>
    DivineVideoClip(
      id: id,
      video: EditorVideo.file('/clips/$id.mp4'),
      duration: const Duration(seconds: 6),
      recordedAt: DateTime(2026),
      targetAspectRatio: model.AspectRatio.vertical,
      originalAspectRatio: 9 / 16,
      reversed: reversed,
      playbackSpeed: speed,
    );

/// A bake whose frames come from [TestScene]: the file named [lastPath] ends
/// on the scene moved by ([dx], [dy]) pixels, everything else is unmoved.
class _Harness {
  _Harness({
    this.dx = 5,
    this.dy = -7,
    this.failRender = false,
    this.onRender,
  }) {
    addTearDown(() => dir.deleteSync(recursive: true));
  }

  final double dx;
  final double dy;
  final bool failRender;
  final void Function()? onRender;
  final scene = TestScene();
  final renders = <(String, VideoRenderData)>[];
  final grabs = <(String, Duration)>[];
  late final Directory dir = Directory.systemTemp.createTempSync('loop_seam');

  /// The final frame of the video is the one grabbed from the last clip.
  String? lastPath;

  LoopSeamBakeService build() => LoopSeamBakeService(
    readInfo: (_) async => _info,
    grabFrame: (path, at, size) async {
      grabs.add((path, at));
      final moved = path == lastPath && at > Duration.zero;
      return scene.frame(
        width: size.width.round(),
        height: size.height.round(),
        dx: moved ? dx : 0,
        dy: moved ? dy : 0,
      );
    },
    render: (outputPath, task) async {
      renders.add((outputPath, task));
      File(outputPath).writeAsStringSync('baked');
      onRender?.call();
      if (failRender) throw StateError('encoder down');
    },
    outputDirectory: () async => dir.path,
  );

  List<VideoSegment> segmentsOf(VideoRenderData task) =>
      task.composition!.layers.single.clips;
}

void main() {
  group(LoopSeamBakeService, () {
    group('isEligible', () {
      test('accepts a plain video clip', () {
        expect(LoopSeamBakeService.isEligible(_clip('a')), isTrue);
      });

      test('rejects a reversed clip', () {
        expect(
          LoopSeamBakeService.isEligible(_clip('a', reversed: true)),
          isFalse,
        );
      });

      test('rejects a re-timed clip', () {
        expect(LoopSeamBakeService.isEligible(_clip('a', speed: 2)), isFalse);
      });
    });

    group('alignClips', () {
      test('re-renders a single clip with both ends moving', () async {
        final harness = _Harness()..lastPath = '/clips/only.mp4';
        final clip = _clip('only');

        final result = await harness.build().alignClips([
          clip,
        ], taskId: 'task');

        expect(harness.renders, hasLength(1));
        final segments = harness.segmentsOf(harness.renders.single.$2);
        expect(segments.first.transform, isNotNull);
        expect(segments.last.transform, isNotNull);
        expect(result.clips.single.id, clip.id);
        expect(
          result.clips.single.video!.file!.path,
          harness.renders.single.$1,
        );
        expect(result.bakedPaths, [harness.renders.single.$1]);
      });

      test('moves the head of the first clip and the tail of the last, '
          'leaving the clips between them alone', () async {
        final harness = _Harness()..lastPath = '/clips/c.mp4';
        final clips = [_clip('a'), _clip('b'), _clip('c')];

        final result = await harness.build().alignClips(
          clips,
          taskId: 'task',
        );

        expect(harness.renders, hasLength(2));
        final head = harness.segmentsOf(harness.renders[0].$2);
        final tail = harness.segmentsOf(harness.renders[1].$2);
        expect(head.first.transform, isNotNull);
        expect(head.last.transform, isNull);
        expect(tail.first.transform, isNull);
        expect(tail.last.transform, isNotNull);
        expect(result.clips[1], same(clips[1]));
        expect(result.clips.first.video!.file!.path, harness.renders[0].$1);
        expect(result.clips.last.video!.file!.path, harness.renders[1].$1);
      });

      test('reads the seam frames at the visible ends of the trim', () async {
        final harness = _Harness()..lastPath = '/clips/b.mp4';
        final first = _clip(
          'a',
        ).copyWith(trimStart: const Duration(seconds: 1));
        final last = _clip('b').copyWith(trimEnd: const Duration(seconds: 2));

        await harness.build().alignClips([first, last], taskId: 'task');

        expect(harness.grabs, [
          ('/clips/a.mp4', const Duration(seconds: 1)),
          // One 30 fps frame before the visible end at 4 s.
          ('/clips/b.mp4', const Duration(microseconds: 3966667)),
        ]);
      });

      test('leaves a video whose ends already match untouched', () async {
        final harness = _Harness(dx: 0, dy: 0)..lastPath = '/clips/a.mp4';
        final clips = [_clip('a')];

        final result = await harness.build().alignClips(clips, taskId: 't');

        expect(harness.renders, isEmpty);
        expect(result.clips, same(clips));
        expect(result.bakedPaths, isEmpty);
      });

      test('skips a video that ends on a reversed clip', () async {
        final harness = _Harness()..lastPath = '/clips/b.mp4';
        final clips = [_clip('a'), _clip('b', reversed: true)];

        final result = await harness.build().alignClips(clips, taskId: 't');

        expect(harness.grabs, isEmpty);
        expect(result.clips, same(clips));
      });

      test(
        'does not measure or bake when the export is already cancelled',
        () async {
          RenderCancellationRegistry.start('task');
          RenderCancellationRegistry.cancel('task');
          addTearDown(RenderCancellationRegistry.reset);
          final harness = _Harness()..lastPath = '/clips/a.mp4';

          await expectLater(
            harness.build().alignClips([_clip('a')], taskId: 'task'),
            throwsA(isA<RenderCanceledException>()),
          );

          expect(harness.grabs, isEmpty);
          expect(harness.renders, isEmpty);
        },
      );

      test(
        'does not start the second bake after a cancel during the first',
        () async {
          RenderCancellationRegistry.start('task');
          addTearDown(RenderCancellationRegistry.reset);
          final harness = _Harness(
            onRender: () {
              RenderCancellationRegistry.cancel('task');
            },
          )..lastPath = '/clips/c.mp4';

          await expectLater(
            harness.build().alignClips([
              _clip('a'),
              _clip('b'),
              _clip('c'),
            ], taskId: 'task'),
            throwsA(isA<RenderCanceledException>()),
          );

          expect(harness.renders, hasLength(1));
          expect(File(harness.renders.single.$1).existsSync(), isFalse);
        },
      );

      test('falls back to the original clips and deletes its output when the '
          'bake fails', () async {
        final harness = _Harness(failRender: true)..lastPath = '/clips/a.mp4';
        final clips = [_clip('a')];

        final result = await harness.build().alignClips(clips, taskId: 't');

        expect(harness.renders, hasLength(1));
        expect(result.clips, same(clips));
        expect(result.bakedPaths, isEmpty);
        expect(File(harness.renders.single.$1).existsSync(), isFalse);
      });
    });

    group('buildTask', () {
      final pieces = [
        const LoopSeamPiece(
          start: Duration.zero,
          end: Duration(milliseconds: 33),
          placement: Rect.fromLTWH(-10, -20, 1100, 1960),
        ),
        const LoopSeamPiece(
          start: Duration(milliseconds: 33),
          end: Duration(seconds: 6),
        ),
      ];

      test('draws each piece of the one source at its own placement', () {
        final task = LoopSeamBakeService.buildTask(
          renderId: 'r',
          inputPath: '/clips/a.mp4',
          info: _info,
          pieces: pieces,
        );

        expect(task.composition!.canvasSize, _info.resolution);
        final segments = task.composition!.layers.single.clips;
        expect(segments, hasLength(2));
        expect(segments[0].transform!.offset, const Offset(-10, -20));
        expect(segments[0].transform!.size, const Size(1100, 1960));
        expect(segments[0].transform!.fit, SegmentFit.fill);
        expect(segments[1].transform, isNull);
        expect(segments[1].startTime, const Duration(milliseconds: 33));
        expect(segments[1].endTime, const Duration(seconds: 6));
      });

      test('carries the sound as one track instead of per piece', () {
        final task = LoopSeamBakeService.buildTask(
          renderId: 'r',
          inputPath: '/clips/a.mp4',
          info: _info,
          pieces: pieces,
        );

        expect(
          task.composition!.layers.single.clips.map((s) => s.volume),
          everyElement(0),
        );
        expect(task.audioTracks.single.path, '/clips/a.mp4');
      });

      test('adds no audio track for a silent source', () {
        final task = LoopSeamBakeService.buildTask(
          renderId: 'r',
          inputPath: '/clips/a.mp4',
          info: const LoopSeamSourceInfo(
            resolution: Size(1080, 1920),
            duration: Duration(seconds: 6),
            frameRate: 30,
            hasAudio: false,
          ),
          pieces: pieces,
        );

        expect(task.audioTracks, isEmpty);
      });
    });

    group('analysisSizeFor', () {
      test('keeps the aspect and caps the long side', () {
        expect(
          LoopSeamBakeService.analysisSizeFor(const Size(1080, 1920)),
          const Size(108, 192),
        );
        expect(
          LoopSeamBakeService.analysisSizeFor(const Size(1920, 1080)),
          const Size(192, 108),
        );
      });
    });
  });
}
