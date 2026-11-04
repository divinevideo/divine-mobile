// ABOUTME: Tests the REC timer export: one frame per video frame, cut at the
// ABOUTME: layer's own start and end, painted at the capture size.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart' show SizedBox;
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/info_sticker.dart';
import 'package:openvine/models/video_editor/social_sticker.dart';
import 'package:openvine/models/video_editor/transition_geometry.dart';
import 'package:openvine/services/video_editor/sticker_frames.dart';
import 'package:openvine/utils/rec_timer_paint.dart';
import 'package:openvine/utils/sound_credit_paint.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show EditorVideo;

/// A capture of [size] logical pixels at a pixel ratio of two.
Future<ExportedLayer> _captured(Layer layer, ui.Size size) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder);
  final image = await recorder.endRecording().toImage(
    (size.width * 2).round(),
    (size.height * 2).round(),
  );
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return ExportedLayer(
    layer: layer,
    bytes: bytes!.buffer.asUint8List(),
    logicalSize: size,
  );
}

WidgetLayer _timer({Duration? startTime, Duration? endTime, LayerMask? mask}) {
  final meta = const InfoStickerData(
    kind: InfoStickerKind.recTimer,
    localeName: 'en',
    style: InfoStickerStyle.camcorder,
  ).toMeta();
  return WidgetLayer(
    id: 'timer',
    widget: const SizedBox(),
    startTime: startTime,
    endTime: endTime,
    mask: mask,
    meta: meta,
    exportConfigs: WidgetLayerExportConfigs(id: 'timer', meta: meta),
  );
}

WidgetLayer _soundCredit(SocialStickerSoundDesign design) {
  final meta = SocialStickerData(
    kind: SocialStickerKind.soundCredit,
    soundTitle: 'Song',
    soundArtist: 'Artist',
    soundDesign: design,
  ).toMeta();
  return WidgetLayer(
    id: design.name,
    widget: const SizedBox(),
    meta: meta,
    exportConfigs: WidgetLayerExportConfigs(id: design.name, meta: meta),
  );
}

/// A capture of the sound credit [design] at its own aspect ratio.
Future<ExportedLayer> _capturedCredit(SocialStickerSoundDesign design) {
  final layer = _soundCredit(design);
  final size = soundCreditSize(SocialStickerData.of(layer)!);
  return _captured(layer, ui.Size(200, 200 / size.aspectRatio));
}

/// The editor timeline of one clip lasting [duration].
TransitionTimelineMap _timeline(Duration duration) =>
    TransitionTimelineMap.fromClips([
      DivineVideoClip(
        id: 'clip',
        video: EditorVideo.file('/clip.mp4'),
        duration: duration,
        recordedAt: DateTime(2026),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      ),
    ]);

void main() {
  group('stickerFrameWindows', () {
    test('gives every frame of a timer without start or end a window', () {
      final windows = stickerFrameWindows(
        start: null,
        end: null,
        editorDuration: const Duration(milliseconds: 90),
      );

      expect(
        windows.map((w) => w.shown),
        equals(const [
          Duration.zero,
          Duration(microseconds: 33333),
          Duration(microseconds: 66667),
        ]),
      );
      expect(windows.first.start, equals(Duration.zero));
      // The last one lasts until the video ends.
      expect(windows.last.end, isNull);
    });

    test('shows a whole second on the frame at that second', () {
      final windows = stickerFrameWindows(
        start: null,
        end: null,
        editorDuration: const Duration(seconds: 2),
      );

      final atOneSecond = windows.firstWhere(
        (w) => w.start == const Duration(seconds: 1),
      );
      expect(recTimerText(atOneSecond.shown), equals('01:00'));
    });

    test('cuts the first and last window at the layer start and end', () {
      final windows = stickerFrameWindows(
        start: const Duration(milliseconds: 1500),
        end: const Duration(milliseconds: 3200),
        editorDuration: const Duration(seconds: 6),
        framesPerSecond: 1,
      );

      expect(
        [for (final w in windows) (w.shown.inSeconds, w.start, w.end)],
        equals([
          (1, const Duration(milliseconds: 1500), const Duration(seconds: 2)),
          (2, const Duration(seconds: 2), const Duration(seconds: 3)),
          (
            3,
            const Duration(seconds: 3),
            const Duration(milliseconds: 3200),
          ),
        ]),
      );
    });
  });

  group('stickerFramesPerSecondFor', () {
    const span = Duration(milliseconds: 6300);

    test('changes a timer of the size it is added at every frame', () {
      expect(
        stickerFramesPerSecondFor(frame: const ui.Size(360, 94), span: span),
        equals(stickerFramesPerSecond),
      );
    });

    test('changes a timer scaled across the video less often', () {
      const frame = ui.Size(2000, 520);

      final framesPerSecond = stickerFramesPerSecondFor(
        frame: frame,
        span: span,
      );

      expect(framesPerSecond, lessThan(stickerFramesPerSecond));
      final frames = framesPerSecond * span.inMicroseconds / 1e6;
      expect(
        frames * frame.width * frame.height,
        lessThanOrEqualTo(stickerFramePixelBudget + 1),
      );
    });
  });

  group('stickerLayerFrames', () {
    test(
      'paints a frame per video frame at the size the layer was captured',
      () async {
        final size = ui.Size(230, 230 / recTimerDesignSize.aspectRatio);
        final timer = await _captured(_timer(), size);
        final other = await _captured(
          WidgetLayer(id: 'sticker', widget: const SizedBox()),
          const ui.Size(10, 10),
        );

        final frames = await stickerLayerFrames([
          timer,
          other,
        ], _timeline(const Duration(milliseconds: 90)));

        expect(frames.keys, equals(['timer']));
        final timerFrames = frames['timer']!;
        expect(timerFrames, hasLength(3));
        final descriptor = await ui.ImageDescriptor.encoded(
          await ui.ImmutableBuffer.fromUint8List(timerFrames.first.bytes),
        );
        expect(descriptor.width, equals(460));
        // Each frame shows other hundredths, so the frames differ.
        expect(timerFrames[0].bytes, isNot(equals(timerFrames[1].bytes)));
      },
    );

    group('mask', () {
      const halfBox = LayerMask(shape: LayerMaskShape.rectangle);
      final size = ui.Size(230, 230 / recTimerDesignSize.aspectRatio);
      final timeline = _timeline(const Duration(milliseconds: 30));

      Future<List<int>> firstFrame(LayerMask? mask) async {
        final timer = await _captured(_timer(mask: mask), size);
        final frames = await stickerLayerFrames([timer], timeline);
        return frames['timer']!.first.bytes;
      }

      test('bakes a mask that does not change into every frame', () async {
        expect(
          await firstFrame(halfBox),
          isNot(equals(await firstFrame(null))),
        );
      });

      test('leaves a mask with keyframes to the renderer', () async {
        // Baked in, the half-size start would cut away what the full-size
        // keyframe shows.
        final growing = halfBox.withKeyframes(const [
          LayerMaskKeyframe(time: Duration.zero, size: ui.Size(1, 1)),
        ]);

        expect(await firstFrame(growing), equals(await firstFrame(null)));
      });
    });

    test('swaps only the timer for one that brings its frames', () async {
      final timer = await _captured(
        _timer(),
        ui.Size(230, 230 / recTimerDesignSize.aspectRatio),
      );
      final other = await _captured(
        WidgetLayer(id: 'sticker', widget: const SizedBox()),
        const ui.Size(10, 10),
      );

      final layers = await withStickerFrames([
        timer,
        other,
      ], _timeline(const Duration(milliseconds: 90)));

      expect(layers.first, isA<StickerFramesExportedLayer>());
      expect(layers.first.layer, same(timer.layer));
      expect(layers.first.frames, hasLength(3));
      expect(layers.last, same(other));
    });
    group('sound credits', () {
      test('paint a frame per video frame for a turning record', () async {
        final record = await _capturedCredit(SocialStickerSoundDesign.vinyl);

        final frames = await stickerLayerFrames([
          record,
        ], _timeline(const Duration(milliseconds: 300)));

        final recordFrames = frames['vinyl']!;
        expect(recordFrames, hasLength(9));
        expect(recordFrames[0].bytes, isNot(equals(recordFrames[4].bytes)));
      });

      test('leave a note as the still the capture took', () async {
        final note = await _capturedCredit(SocialStickerSoundDesign.note);

        final layers = await withStickerFrames([
          note,
        ], _timeline(const Duration(milliseconds: 90)));

        expect(layers.single, same(note));
      });

      test('move an equalizer only with the sound to follow', () async {
        final equalizer = await _capturedCredit(
          SocialStickerSoundDesign.equalizer,
        );
        final timeline = _timeline(const Duration(milliseconds: 90));

        final withoutSound = await stickerLayerFrames([equalizer], timeline);
        final withSound = await stickerLayerFrames(
          [equalizer],
          timeline,
          Float32List(6 * 48)..fillRange(0, 6 * 48, 1),
        );

        expect(withoutSound, isEmpty);
        expect(withSound['equalizer'], hasLength(3));
      });
    });
  });
}
