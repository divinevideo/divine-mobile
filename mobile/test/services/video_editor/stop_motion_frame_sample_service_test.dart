// ABOUTME: Tests for sampling a video clip into stop-motion stills —
// ABOUTME: the timestamp grid, the written frames, and the failure cleanup

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/stop_motion/stop_motion_frame_ops.dart';
import 'package:openvine/services/video_editor/stop_motion_frame_sample_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

class _FakePathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  _FakePathProviderPlatform(this.documentsPath);

  final String documentsPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;
}

/// Answers the thumbnail stream from a canned list of frames, remembering the
/// request so a test can check what was asked for.
class _FakeProVideoEditor extends ProVideoEditor {
  _FakeProVideoEditor({this.frames = const [], this.error});

  final List<ThumbnailFrame> frames;
  final Object? error;
  ThumbnailConfigs? request;

  @override
  Stream<dynamic> initializeStream() => const Stream.empty();

  @override
  Stream<ThumbnailFrame> getThumbnailStream(
    ThumbnailConfigs value, {
    NativeLogLevel? nativeLogLevel,
  }) async* {
    request = value;
    for (final frame in frames) {
      yield frame;
    }
    if (error != null) throw error!;
  }
}

DivineVideoClip _clip({
  Duration duration = const Duration(seconds: 1),
  Duration trimStart = Duration.zero,
  Duration trimEnd = Duration.zero,
}) => DivineVideoClip(
  id: 'footage',
  video: EditorVideo.file('/documents/footage.mp4'),
  duration: duration,
  trimStart: trimStart,
  trimEnd: trimEnd,
  recordedAt: DateTime(2026),
  targetAspectRatio: .vertical,
  originalAspectRatio: 9 / 16,
);

ThumbnailFrame _frame(List<int> indices, {int byte = 1}) => ThumbnailFrame(
  indices: indices,
  bytes: Uint8List.fromList([byte, byte, byte]),
  progress: 1,
);

void main() {
  group(StopMotionFrameSampleService, () {
    group('sampleTimestamps', () {
      test('grids the trimmed range one hold apart from the trim-in', () {
        final hold = StopMotionFrameOps.framesPerImageToDuration(3);
        final timestamps = StopMotionFrameSampleService.sampleTimestamps(
          _clip(
            duration: const Duration(seconds: 2),
            trimStart: const Duration(milliseconds: 500),
            trimEnd: const Duration(milliseconds: 500),
          ),
          framesPerImage: 3,
        );

        // One second of range at a tenth-of-a-second hold is ten stills, none
        // of them on the trim-out point itself.
        expect(timestamps, hasLength(10));
        expect(timestamps.first, const Duration(milliseconds: 500));
        expect(timestamps[1] - timestamps.first, hold);
        expect(timestamps.last, lessThan(const Duration(milliseconds: 1500)));
      });

      test('keeps one still for a clip shorter than a hold', () {
        final timestamps = StopMotionFrameSampleService.sampleTimestamps(
          _clip(duration: const Duration(milliseconds: 10)),
          framesPerImage: 1,
        );

        expect(timestamps, [Duration.zero]);
      });
    });

    group('sampleClip', () {
      late Directory tempDir;
      late ProVideoEditor originalProVideoEditor;
      late PathProviderPlatform originalPathProvider;

      setUp(() {
        tempDir = Directory.systemTemp.createTempSync('frame_sample');
        originalProVideoEditor = ProVideoEditor.instance;
        originalPathProvider = PathProviderPlatform.instance;
        PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
      });

      tearDown(() {
        ProVideoEditor.instance = originalProVideoEditor;
        PathProviderPlatform.instance = originalPathProvider;
        tempDir.deleteSync(recursive: true);
      });

      test('writes one still per position, each held for the hold', () async {
        final editor = _FakeProVideoEditor(
          frames: [
            _frame([0], byte: 10),
            _frame([1, 2], byte: 20),
          ],
        );
        ProVideoEditor.instance = editor;

        final frames = await StopMotionFrameSampleService.sampleClip(
          _clip(duration: const Duration(milliseconds: 120)),
          framesPerImage: 1,
          taskId: 'sample-1',
        );

        expect(frames, hasLength(3));
        expect(
          frames!.map((f) => f.duration).toSet(),
          {StopMotionFrameOps.framesPerImageToDuration(1)},
        );
        // A frame two positions resolved to is on disk twice: every still
        // owns its file.
        expect(frames.map((f) => f.path).toSet(), hasLength(3));
        for (final frame in frames) {
          expect(File(frame.path).existsSync(), isTrue);
          expect(frame.path, startsWith(tempDir.path));
        }
        expect(File(frames[1].path).readAsBytesSync(), [20, 20, 20]);
        expect(editor.request?.id, 'sample-1');
        expect(editor.request?.timestamps, hasLength(3));
      });

      test('skips a position the decoder never answered', () async {
        ProVideoEditor.instance = _FakeProVideoEditor(
          frames: [
            _frame([0]),
            _frame([2]),
          ],
        );

        final frames = await StopMotionFrameSampleService.sampleClip(
          _clip(duration: const Duration(milliseconds: 120)),
          framesPerImage: 1,
        );

        expect(frames, hasLength(2));
      });

      test('returns null when not one still came back', () async {
        ProVideoEditor.instance = _FakeProVideoEditor();

        final frames = await StopMotionFrameSampleService.sampleClip(
          _clip(),
          framesPerImage: 1,
        );

        expect(frames, isNull);
        expect(tempDir.listSync(), isEmpty);
      });

      test('deletes what it wrote when the decoder fails midway', () async {
        ProVideoEditor.instance = _FakeProVideoEditor(
          frames: [
            _frame([0]),
          ],
          error: const RenderCanceledException(),
        );

        await expectLater(
          StopMotionFrameSampleService.sampleClip(_clip(), framesPerImage: 1),
          throwsA(isA<RenderCanceledException>()),
        );

        expect(tempDir.listSync(), isEmpty);
      });

      test('refuses a frames-only clip', () async {
        ProVideoEditor.instance = _FakeProVideoEditor();
        final set = DivineVideoClip(
          id: 'set',
          stopMotionFrames: const [],
          duration: Duration.zero,
          recordedAt: DateTime(2026),
          targetAspectRatio: .vertical,
          originalAspectRatio: 9 / 16,
        );

        await expectLater(
          StopMotionFrameSampleService.sampleClip(set, framesPerImage: 1),
          throwsStateError,
        );
      });
    });

    group('cleanupSampledFrames', () {
      test('deletes the files it is given and ignores missing ones', () async {
        final tempDir = Directory.systemTemp.createTempSync('frame_cleanup');
        addTearDown(() => tempDir.deleteSync(recursive: true));
        final written = File('${tempDir.path}/a.jpg')..writeAsBytesSync([1]);

        await StopMotionFrameSampleService.cleanupSampledFrames([
          written.path,
          '${tempDir.path}/never-written.jpg',
        ]);

        expect(written.existsSync(), isFalse);
      });
    });
  });
}
