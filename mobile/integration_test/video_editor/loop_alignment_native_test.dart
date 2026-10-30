// ABOUTME: Runs the production loop repair through real native video plugins.
// ABOUTME: Measures decoded exported frames and retains MP4s for visual review.
// Generate fixtures with integration_test/fixtures/generate_loop_drift.py, then:
// flutter test -d macos integration_test/video_editor/loop_alignment_native_test.dart
//   --dart-define=LOOP_ALIGNMENT_FIXTURE_DIR=/absolute/fixture/directory

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:loop_alignment_repository/loop_alignment_repository.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/loop_repair_input.dart';
import 'package:openvine/services/video_editor/native_loop_alignment_client.dart';
import 'package:openvine/services/video_editor/pve_loop_frame_matcher.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:unified_logger/unified_logger.dart';

/// Redirects only `outputPath`; every other call goes to the production
/// `PveLoopNativeBackend`, with no channel mocks or overrides.
class _ArtifactBackend implements LoopNativeBackend {
  _ArtifactBackend(this.directory);
  final Directory directory;
  final PveLoopNativeBackend _native = const PveLoopNativeBackend();

  @override
  Stream<LumaFrame> decode(LumaFrameConfigs config) => _native.decode(config);
  @override
  Future<VideoMetadata> metadata(String path) => _native.metadata(path);
  @override
  Future<void> render(String path, VideoRenderData data) =>
      _native.render(path, data);
  @override
  Future<void> cancel(String id) => _native.cancel(id);
  @override
  Future<void> delete(String path) => _native.delete(path);
  @override
  Future<String> outputPath(String namespace, int index) async =>
      '${directory.path}/${namespace}_$index.mp4';
}

Future<List<LoopFrame>> _frames(String path) async => [
  await for (final frame in ProVideoEditor.instance.getLumaFrameStream(
    LumaFrameConfigs(
      video: EditorVideo.file(path),
      outputSize: const Size(320, 320),
      maxParallelDecoders: 1,
    ),
  ))
    LoopFrame(
      time: frame.time,
      width: frame.width,
      height: frame.height,
      luma: frame.bytes,
    ),
];

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const fixtureRoot = String.fromEnvironment('LOOP_ALIGNMENT_FIXTURE_DIR');
  if (fixtureRoot.isEmpty || !Platform.isMacOS) {
    throw StateError('Run on macOS with LOOP_ALIGNMENT_FIXTURE_DIR set.');
  }
  const inputVideo = String.fromEnvironment('LOOP_ALIGNMENT_INPUT_VIDEO');
  final directory = Directory('$fixtureRoot/native-output');

  group('Native loop alignment', () {
    if (inputVideo.isEmpty) {
      for (final name in [
        'portrait-subject',
        'landscape-subject',
        'portrait-ambiguous',
        'landscape-ambiguous',
      ]) {
        testWidgets(
          'declines encoded $name without independent camera evidence',
          (
            tester,
          ) async {
            await directory.create(recursive: true);
            await LogCaptureService().clearAllLogs();
            final source = '$fixtureRoot/$name-drift.mp4';
            final backend = _ArtifactBackend(directory);
            final metadata = await backend.metadata(source);
            final clips = [
              DivineVideoClip(
                id: 'synthetic-$name',
                video: EditorVideo.file(source),
                duration: metadata.duration,
                recordedAt: DateTime.utc(2026),
                targetAspectRatio: .vertical,
                originalAspectRatio:
                    metadata.resolution.width / metadata.resolution.height,
              ),
            ];
            final repository = LoopAlignmentRepository(
              client: NativeLoopAlignmentClient(backend: backend),
            );
            final result = await repository.repair(
              LoopRepairInputMapper.fromComposition(
                clips,
                composition: const {},
              ),
              taskId: 'native-$name',
            );
            addTearDown(() => repository.discard(result));
            final diagnostics = (await LogCaptureService().getAllLogsAsText())
                .join('\n');
            await File('${directory.path}/$name-diagnostics.txt')
                .writeAsString(diagnostics);
            expect(
              result.status,
              LoopRepairStatus.noMatch,
              reason: diagnostics,
            );
            expect(result.output, isNull);
          },
          timeout: const Timeout(Duration(minutes: 3)),
        );
      }
    }

    for (final name
        in inputVideo.isEmpty
            ? [
                'portrait',
                'landscape',
                'portrait-rotation',
                'landscape-rotation',
              ]
            : ['recording']) {
      testWidgets('repairs encoded $name drift with real native rendering', (
        tester,
      ) async {
        await directory.create(recursive: true);
        for (final suffix in [
          'aligned.mp4',
          'report.json',
          'diagnostics.txt',
        ]) {
          final previous = File('${directory.path}/$name-$suffix');
          if (previous.existsSync()) await previous.delete();
        }
        await LogCaptureService().clearAllLogs();
        final source = inputVideo.isEmpty
            ? '$fixtureRoot/$name-drift.mp4'
            : inputVideo;
        expect(File(source).existsSync(), isTrue);
        final backend = _ArtifactBackend(directory);
        final metadata = await backend.metadata(source);
        final before = await _frames(source);
        if (inputVideo.isEmpty) {
          expect(before, hasLength(90));
        } else {
          expect(before.length, greaterThanOrEqualTo(4));
        }
        final width = before.first.width;
        final height = before.first.height;
        final repository = LoopAlignmentRepository(
          client: NativeLoopAlignmentClient(backend: backend),
        );
        final clips = [
          DivineVideoClip(
            id: 'synthetic-$name',
            video: EditorVideo.file(source),
            duration: metadata.duration,
            recordedAt: DateTime.utc(2026),
            targetAspectRatio: .vertical,
            originalAspectRatio:
                metadata.resolution.width / metadata.resolution.height,
          ),
        ];
        final input = LoopRepairInputMapper.fromComposition(
          clips,
          composition: const {},
        );
        expect(input.capability, LoopRepairCapability.supported);
        final result = await repository.repair(input, taskId: 'native-$name');
        final diagnostics = (await LogCaptureService().getAllLogsAsText()).join(
          '\n',
        );
        await File('${directory.path}/$name-diagnostics.txt').writeAsString(
          diagnostics,
        );
        expect(result.status, LoopRepairStatus.repaired, reason: diagnostics);
        addTearDown(() => repository.discard(result));
        expect(result.plan!.trimmedSourceEnd, isNull);
        final output = result.output!.paths.values.single;
        final applied = LoopRepairInputMapper.applyResult(
          clips,
          result,
          operationId: 'native-$name',
        );
        expect(applied.single.video!.file!.path, output);
        expect(clips.single.video!.file!.path, source);
        final artifact = '${directory.path}/$name-aligned.mp4';
        await File(output).copy(artifact);
        final after = await _frames(artifact);
        final renderedMetadata = await backend.metadata(artifact);
        expect(after, hasLength(before.length));
        expect(renderedMetadata.audioDuration, isNotNull);
        expect(
          (renderedMetadata.duration - metadata.duration).abs(),
          lessThan(const Duration(milliseconds: 34)),
        );
        final croppedBefore = [
          for (final frame in before)
            const LoopFrameResampler().warp(
              frame,
              LoopPose.identity,
              result.plan!.zoom,
              longestEdge: 320,
            ),
        ];
        LoopSeamScores score(List<LoopFrame> frames, Duration duration) =>
            const LoopSeamScorer().score(
              frames.take(3).toList(),
              frames.skip(math.max(0, frames.length - 3)).toList(),
              seamInterval: duration - frames.last.time,
            );
        final originalScores = score(croppedBefore, metadata.duration);
        final outputScores = score(after, renderedMetadata.duration);
        final seam = PveLoopFrameMatcher().match(after.first, after.last);
        expect(seam, isNotNull);
        final displacement = seam!.pose.maximumCornerDisplacement(
          width,
          height,
        );
        final report = {
          'platform': Platform.operatingSystem,
          'nativeBackend': 'PveLoopNativeBackend',
          // A replayed recording's path can carry a person's name or ticket.
          'input': inputVideo.isEmpty
              ? '$name-drift.mp4'
              : 'LOOP_ALIGNMENT_INPUT_VIDEO',
          'output': '$name-aligned.mp4',
          'framesBefore': before.length,
          'framesAfter': after.length,
          'durationUsBefore': metadata.duration.inMicroseconds,
          'durationUsAfter': renderedMetadata.duration.inMicroseconds,
          'audioDurationUs': renderedMetadata.audioDuration!.inMicroseconds,
          'zoom': result.plan!.zoom,
          'differenceBefore': originalScores.difference,
          'differenceAfter': outputScores.difference,
          'motionBefore': originalScores.motion,
          'motionAfter': outputScores.motion,
          'seamDisplacementAnalysisPixels': displacement,
        };
        // Written before the checks so a failing run keeps its measurements.
        await File('${directory.path}/$name-report.json').writeAsString(
          const JsonEncoder.withIndent('  ').convert(report),
        );
        expect(
          outputScores.difference,
          lessThan(originalScores.difference * .75),
        );
        expect(outputScores.difference, lessThanOrEqualTo(.03));
        expect(outputScores.motion, lessThanOrEqualTo(originalScores.motion));
        expect(displacement, lessThan(.5));
      }, timeout: const Timeout(Duration(minutes: 3)));
    }
  });
}
