import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/stop_motion_clip_frame.dart';
import 'package:openvine/services/video_editor/clip_placeholder_render_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show EditorVideo;

/// Decodes [bytes] into an image, so the encoded PNG can be inspected.
Future<Image> _decode(Uint8List bytes) async {
  final codec = await instantiateImageCodec(bytes);
  try {
    return (await codec.getNextFrame()).image;
  } finally {
    codec.dispose();
  }
}

DivineVideoClip _source({
  Duration duration = const Duration(seconds: 6),
  Duration trimStart = Duration.zero,
  Duration trimEnd = Duration.zero,
  double? playbackSpeed,
  model.AspectRatio aspectRatio = model.AspectRatio.square,
}) => DivineVideoClip(
  id: 'clip-1',
  video: EditorVideo.file('/docs/clip-1.mp4'),
  duration: duration,
  recordedAt: DateTime(2026),
  targetAspectRatio: aspectRatio,
  originalAspectRatio: 1,
  trimStart: trimStart,
  trimEnd: trimEnd,
  playbackSpeed: playbackSpeed,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late File imageFile;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('placeholder_test');
    imageFile = File('${tempDir.path}/still.png')
      ..writeAsBytesSync(const [1, 2, 3]);
  });

  tearDown(() {
    ClipPlaceholderRenderService.assembleOverride = null;
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group(ClipPlaceholderRenderService, () {
    group('render', () {
      test('holds the image for as long as the clip occupied', () async {
        List<StopMotionClipFrame>? seen;
        ClipPlaceholderRenderService.assembleOverride =
            ({required frames, required aspectRatio, taskId}) async {
              seen = frames;
              return '${tempDir.path}/out.mp4';
            };

        final placeholder = await ClipPlaceholderRenderService.render(
          fill: ClipPlaceholderImageFill(imageFile.path),
          source: _source(
            trimStart: const Duration(seconds: 1),
            trimEnd: const Duration(seconds: 1),
          ),
        );

        expect(placeholder, isNotNull);
        expect(seen, hasLength(1));
        // The slot has to keep its length or every later clip shifts, so the
        // hold is the trimmed span, not the raw file duration.
        expect(seen!.single.duration, const Duration(seconds: 4));
        expect(placeholder!.duration, const Duration(seconds: 4));
      });

      test('scales the hold by the clip playback speed', () async {
        ClipPlaceholderRenderService.assembleOverride =
            ({required frames, required aspectRatio, taskId}) async =>
                '${tempDir.path}/out.mp4';

        final placeholder = await ClipPlaceholderRenderService.render(
          fill: ClipPlaceholderImageFill(imageFile.path),
          source: _source(playbackSpeed: 2),
        );

        // A 6 s clip at 2× occupies 3 s of the timeline.
        expect(placeholder!.duration, const Duration(seconds: 3));
      });

      test('renders at the clip aspect ratio and mutes the still', () async {
        model.AspectRatio? seenRatio;
        ClipPlaceholderRenderService.assembleOverride =
            ({required frames, required aspectRatio, taskId}) async {
              seenRatio = aspectRatio;
              return '${tempDir.path}/out.mp4';
            };

        final placeholder = await ClipPlaceholderRenderService.render(
          fill: ClipPlaceholderImageFill(imageFile.path),
          source: _source(aspectRatio: model.AspectRatio.vertical),
        );

        expect(seenRatio, model.AspectRatio.vertical);
        expect(placeholder!.targetAspectRatio, model.AspectRatio.vertical);
        // Marked so the action bar keeps Detach off it — detaching a still
        // would only ask for a second still to fill the slot it vacated.
        expect(placeholder.isPlaceholder, isTrue);
        // A still carries no sound; leaving it at full volume would add a
        // silent-but-present track to the mix.
        expect(placeholder.volume, 0);
      });

      test('gives the placeholder its own id, not the detached clip', () async {
        ClipPlaceholderRenderService.assembleOverride =
            ({required frames, required aspectRatio, taskId}) async =>
                '${tempDir.path}/out.mp4';

        final placeholder = await ClipPlaceholderRenderService.render(
          fill: ClipPlaceholderImageFill(imageFile.path),
          source: _source(),
        );

        // The detached clip keeps its id on the canvas layer; reusing it here
        // would put the same id on the timeline and the layer at once.
        expect(placeholder!.id, isNot('clip-1'));
        expect(placeholder.video?.file?.path, '${tempDir.path}/out.mp4');
      });

      test('returns null when the source image is gone', () async {
        var called = false;
        ClipPlaceholderRenderService.assembleOverride =
            ({required frames, required aspectRatio, taskId}) async {
              called = true;
              return '${tempDir.path}/out.mp4';
            };

        final placeholder = await ClipPlaceholderRenderService.render(
          fill: const ClipPlaceholderImageFill('/does/not/exist.png'),
          source: _source(),
        );

        expect(placeholder, isNull);
        expect(called, isFalse);
      });

      test('returns null when the render produces no file', () async {
        ClipPlaceholderRenderService.assembleOverride =
            ({required frames, required aspectRatio, taskId}) async => null;

        final placeholder = await ClipPlaceholderRenderService.render(
          fill: ClipPlaceholderImageFill(imageFile.path),
          source: _source(),
        );

        // The caller turns this into "couldn't detach"; a null slot would
        // silently shorten the composition instead.
        expect(placeholder, isNull);
      });

      test('refuses a clip that occupies no time', () async {
        var called = false;
        ClipPlaceholderRenderService.assembleOverride =
            ({required frames, required aspectRatio, taskId}) async {
              called = true;
              return '${tempDir.path}/out.mp4';
            };

        final placeholder = await ClipPlaceholderRenderService.render(
          fill: ClipPlaceholderImageFill(imageFile.path),
          source: _source(
            duration: const Duration(seconds: 2),
            trimEnd: const Duration(seconds: 2),
          ),
        );

        expect(placeholder, isNull);
        // StopMotionFrame asserts a positive duration, so reaching the render
        // with a zero hold is a crash, not a bad-looking clip.
        expect(called, isFalse);
      });
    });

    group('encodeSolidColorPng', () {
      test('encodes a square PNG of the requested colour', () async {
        final bytes = await ClipPlaceholderRenderService.encodeSolidColorPng(
          const Color(0xFF3366CC),
        );

        expect(bytes, isNotNull);
        expect(bytes, isNotEmpty);
        // PNG magic — proof it is the format the renderer can open, not just
        // some bytes.
        expect(bytes!.take(4), [0x89, 0x50, 0x4E, 0x47]);

        final decoded = await _decode(bytes);
        addTearDown(decoded.dispose);
        expect(decoded.width, ClipPlaceholderRenderService.colorSourceSize);
        expect(decoded.height, ClipPlaceholderRenderService.colorSourceSize);
      });

      test('forces the fill opaque', () async {
        final bytes = await ClipPlaceholderRenderService.encodeSolidColorPng(
          const Color(0x203366CC),
        );

        final decoded = await _decode(bytes!);
        addTearDown(decoded.dispose);
        final pixels = await decoded.toByteData();
        // mp4 carries no alpha, so a translucent pick would be flattened
        // against black and come out darker than the swatch the user tapped.
        expect(pixels!.getUint8(3), 0xFF);
      });
    });
  });
}
