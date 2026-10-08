// ABOUTME: Tests for freezing a frame — where the still lands relative to the
// ABOUTME: clip, and how the rendered still becomes a trimmable silent clip

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model show ClipSourceCredit;
import 'package:openvine/models/c2pa_edit_source.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/stop_motion_clip_frame.dart';
import 'package:openvine/services/video_editor/freeze_frame_render_service.dart';
import 'package:openvine/services/video_editor/stop_motion_render_service.dart';
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

/// Answers frame and metadata requests from canned values, remembering the
/// frame request so a test can check what was asked for.
class _FakeProVideoEditor extends ProVideoEditor {
  _FakeProVideoEditor({this.frame, this.probedDuration});

  final Uint8List? frame;
  final Duration? probedDuration;
  ThumbnailConfigs? request;

  @override
  Stream<dynamic> initializeStream() => const Stream.empty();

  @override
  Future<List<Uint8List>> getThumbnails(
    ThumbnailConfigs value, {
    NativeLogLevel? nativeLogLevel,
  }) async {
    request = value;
    return [?frame];
  }

  @override
  Future<VideoMetadata> getMetadata(
    EditorVideo value, {
    bool checkStreamingOptimization = false,
    NativeLogLevel? nativeLogLevel,
  }) async {
    final duration = probedDuration;
    if (duration == null) throw StateError('no metadata');
    return VideoMetadata(
      duration: duration,
      extension: 'mp4',
      fileSize: 1,
      resolution: const Size(1080, 1920),
      rotation: 0,
      bitrate: 1,
    );
  }
}

DivineVideoClip _clip({
  Duration duration = const Duration(seconds: 3),
  Duration trimStart = Duration.zero,
  Duration trimEnd = Duration.zero,
  double originalAspectRatio = 9 / 16,
  List<model.ClipSourceCredit> sourceCredits = const [],
}) => DivineVideoClip(
  id: 'footage',
  video: EditorVideo.file('/documents/footage.mp4'),
  duration: duration,
  trimStart: trimStart,
  trimEnd: trimEnd,
  recordedAt: DateTime(2026),
  targetAspectRatio: .vertical,
  originalAspectRatio: originalAspectRatio,
  sourceCredits: sourceCredits,
);

void main() {
  group(FreezeFrameRenderService, () {
    group('plan', () {
      final clip = _clip(
        trimStart: const Duration(seconds: 1),
        trimEnd: const Duration(milliseconds: 500),
      );

      test('cuts the clip and holds the frame under the playhead', () {
        final plan = FreezeFrameRenderService.plan(
          clip,
          const Duration(milliseconds: 700),
        );

        expect(plan.placement, FreezeFramePlacement.split);
        // The playhead offset is relative to the trimmed start; the frame is
        // read from the file, so the trim-in is added back.
        expect(plan.framePosition, const Duration(milliseconds: 1700));
      });

      test('holds the first frame in front of a playhead at the start', () {
        final plan = FreezeFrameRenderService.plan(clip, Duration.zero);

        expect(plan.placement, FreezeFramePlacement.before);
        expect(plan.framePosition, const Duration(seconds: 1));
      });

      test('holds the last shown frame after a playhead at the end', () {
        final plan = FreezeFrameRenderService.plan(clip, clip.trimmedDuration);

        expect(plan.placement, FreezeFramePlacement.after);
        // Inside the last frame the trim leaves visible, never on or past the
        // trim-out point.
        expect(
          plan.framePosition,
          lessThan(const Duration(seconds: 2, milliseconds: 500)),
        );
        expect(
          plan.framePosition,
          greaterThan(const Duration(seconds: 2, milliseconds: 466)),
        );
      });
    });

    group('render', () {
      late Directory tempDir;
      late ProVideoEditor originalProVideoEditor;
      late PathProviderPlatform originalPathProvider;
      late List<StopMotionClipFrame> assembledFrames;
      late String? assembleResult;

      setUp(() {
        tempDir = Directory.systemTemp.createTempSync('freeze_frame');
        originalProVideoEditor = ProVideoEditor.instance;
        originalPathProvider = PathProviderPlatform.instance;
        PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
        assembledFrames = [];
        assembleResult = '${tempDir.path}/out.mp4';
        StopMotionRenderService.assembleOverride =
            ({
              required frames,
              required aspectRatio,
              frameRate = StopMotionRenderService.defaultFrameRate,
              taskId,
            }) async {
              assembledFrames = frames;
              return assembleResult;
            };
      });

      tearDown(() {
        StopMotionRenderService.assembleOverride = null;
        ProVideoEditor.instance = originalProVideoEditor;
        PathProviderPlatform.instance = originalPathProvider;
        tempDir.deleteSync(recursive: true);
      });

      test('renders a silent still trimmed to the default hold', () async {
        ProVideoEditor.instance = _FakeProVideoEditor(
          frame: Uint8List.fromList([1, 2, 3]),
          probedDuration: FreezeFrameRenderService.reserveDuration,
        );

        final freeze = await FreezeFrameRenderService.render(
          source: _clip(),
          framePosition: const Duration(seconds: 1),
        );

        expect(freeze, isNotNull);
        expect(freeze!.isFreezeFrame, isTrue);
        expect(freeze.volume, 0);
        expect(
          freeze.trimmedDuration,
          FreezeFrameRenderService.defaultDuration,
        );
        // Rendered longer than it plays, so the trim handle can stretch it.
        expect(freeze.duration, FreezeFrameRenderService.reserveDuration);
        expect(freeze.budgetDuration, FreezeFrameRenderService.defaultDuration);
      });

      test('holds the frame read at the requested position', () async {
        final editor = _FakeProVideoEditor(
          frame: Uint8List.fromList([7, 7, 7]),
          probedDuration: FreezeFrameRenderService.reserveDuration,
        );
        ProVideoEditor.instance = editor;

        final freeze = await FreezeFrameRenderService.render(
          source: _clip(),
          framePosition: const Duration(milliseconds: 1250),
        );

        expect(editor.request?.timestamps, [
          const Duration(milliseconds: 1250),
        ]);
        expect(assembledFrames, hasLength(1));
        expect(
          assembledFrames.single.duration,
          FreezeFrameRenderService.reserveDuration,
        );
        // The held frame doubles as the clip's poster.
        expect(freeze!.thumbnailPath, assembledFrames.single.path);
        expect(File(freeze.thumbnailPath!).readAsBytesSync(), [7, 7, 7]);
      });

      test('trims against the length the encoder actually wrote', () async {
        ProVideoEditor.instance = _FakeProVideoEditor(
          frame: Uint8List.fromList([1]),
          probedDuration: const Duration(milliseconds: 6267),
        );

        final freeze = await FreezeFrameRenderService.render(
          source: _clip(),
          framePosition: Duration.zero,
        );

        expect(freeze!.duration, const Duration(milliseconds: 6267));
        expect(
          freeze.trimmedDuration,
          FreezeFrameRenderService.defaultDuration,
        );
      });

      test('keeps the source credit and the canvas aspect ratio', () async {
        ProVideoEditor.instance = _FakeProVideoEditor(
          frame: Uint8List.fromList([1]),
          probedDuration: FreezeFrameRenderService.reserveDuration,
        );
        const credit = model.ClipSourceCredit(
          authorPubkey: 'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2',
        );

        final freeze = await FreezeFrameRenderService.render(
          source: _clip(originalAspectRatio: 1, sourceCredits: [credit]),
          framePosition: Duration.zero,
        );

        expect(freeze!.sourceCredits, [credit]);
        // Signed against the footage the frame was taken from.
        expect(freeze.derivedFrom, const [
          C2paEditSource(path: '/documents/footage.mp4'),
        ]);
        // A freeze in front of the first clip inherits the canvas coordinate
        // system, while the file itself is already cropped to the target.
        expect(freeze.originalAspectRatio, 1);
        expect(freeze.videoAspectRatio, closeTo(9 / 16, 0.001));
      });

      test('returns null and renders nothing without a frame', () async {
        var assembled = false;
        StopMotionRenderService.assembleOverride =
            ({
              required frames,
              required aspectRatio,
              frameRate = StopMotionRenderService.defaultFrameRate,
              taskId,
            }) async {
              assembled = true;
              return assembleResult;
            };
        ProVideoEditor.instance = _FakeProVideoEditor();

        final freeze = await FreezeFrameRenderService.render(
          source: _clip(),
          framePosition: Duration.zero,
        );

        expect(freeze, isNull);
        expect(assembled, isFalse);
        expect(tempDir.listSync(), isEmpty);
      });

      test('deletes the held frame when the render fails', () async {
        ProVideoEditor.instance = _FakeProVideoEditor(
          frame: Uint8List.fromList([1]),
        );
        assembleResult = null;

        final freeze = await FreezeFrameRenderService.render(
          source: _clip(),
          framePosition: Duration.zero,
        );

        expect(freeze, isNull);
        expect(assembledFrames, hasLength(1));
        expect(tempDir.listSync(), isEmpty);
      });
    });
  });
}
