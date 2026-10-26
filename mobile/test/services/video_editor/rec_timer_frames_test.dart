// ABOUTME: Tests the REC timer export: one frame per video frame, cut at the
// ABOUTME: layer's own start and end, painted at the capture size.

import 'dart:ui' as ui;

import 'package:flutter/widgets.dart' show SizedBox;
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_editor/info_sticker.dart';
import 'package:openvine/services/video_editor/rec_timer_frames.dart';
import 'package:openvine/utils/rec_timer_paint.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

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

WidgetLayer _timer({Duration? startTime, Duration? endTime}) {
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
    meta: meta,
    exportConfigs: WidgetLayerExportConfigs(id: 'timer', meta: meta),
  );
}

void main() {
  group('recTimerWindows', () {
    test('gives every frame of a timer without start or end a window', () {
      final windows = recTimerWindows(
        start: null,
        end: null,
        editorDuration: recTimerFrameStep * 2.5,
      );

      expect(
        windows.map((w) => w.shown),
        equals([Duration.zero, recTimerFrameStep, recTimerFrameStep * 2]),
      );
      expect(windows.first.start, equals(Duration.zero));
      // The last one lasts until the video ends.
      expect(windows.last.end, isNull);
    });

    test('cuts the first and last window at the layer start and end', () {
      final windows = recTimerWindows(
        start: const Duration(milliseconds: 1500),
        end: const Duration(milliseconds: 3200),
        editorDuration: const Duration(seconds: 6),
        step: const Duration(seconds: 1),
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

  group('recTimerFrameStepFor', () {
    const span = Duration(milliseconds: 6300);

    test('changes a timer of the size it is added at every frame', () {
      expect(
        recTimerFrameStepFor(frame: const ui.Size(360, 94), span: span),
        equals(recTimerFrameStep),
      );
    });

    test('changes a timer scaled across the video less often', () {
      const frame = ui.Size(2000, 520);

      final step = recTimerFrameStepFor(frame: frame, span: span);

      expect(step, greaterThan(recTimerFrameStep));
      final frames = span.inMicroseconds / step.inMicroseconds;
      expect(
        frames * frame.width * frame.height,
        lessThanOrEqualTo(recTimerPixelBudget),
      );
    });
  });

  group('recTimerLayerFrames', () {
    test(
      'paints a frame per video frame at the size the layer was captured',
      () async {
        final size = ui.Size(230, 230 / recTimerDesignSize.aspectRatio);
        final timer = await _captured(_timer(), size);
        final other = await _captured(
          WidgetLayer(id: 'sticker', widget: const SizedBox()),
          const ui.Size(10, 10),
        );

        final frames = await recTimerLayerFrames(
          [timer, other],
          editorDuration: recTimerFrameStep * 2.5,
        );

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
  });
}
