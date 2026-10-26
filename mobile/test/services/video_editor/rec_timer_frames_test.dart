// ABOUTME: Tests the REC timer export: one frame per second of the video,
// ABOUTME: cut at the layer's own start and end, painted at the capture size.

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
    test('gives every second of a timer without start or end a frame', () {
      final windows = recTimerWindows(
        start: null,
        end: null,
        editorDuration: const Duration(milliseconds: 2500),
      );

      expect(windows.map((w) => w.second.inSeconds), equals([0, 1, 2]));
      expect(windows.first.start, equals(Duration.zero));
      // The last one lasts until the video ends.
      expect(windows.last.end, isNull);
    });

    test('cuts the first and last second at the layer start and end', () {
      final windows = recTimerWindows(
        start: const Duration(milliseconds: 1500),
        end: const Duration(milliseconds: 3200),
        editorDuration: const Duration(seconds: 6),
      );

      expect(
        [for (final w in windows) (w.second.inSeconds, w.start, w.end)],
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

  group('recTimerLayerFrames', () {
    test(
      'paints a frame per second at the size the layer was captured',
      () async {
        final size = ui.Size(230, 230 / recTimerDesignSize.aspectRatio);
        final timer = await _captured(_timer(), size);
        final other = await _captured(
          WidgetLayer(id: 'sticker', widget: const SizedBox()),
          const ui.Size(10, 10),
        );

        final frames = await recTimerLayerFrames(
          [timer, other],
          editorDuration: const Duration(milliseconds: 2500),
        );

        expect(frames.keys, equals(['timer']));
        final timerFrames = frames['timer']!;
        expect(timerFrames, hasLength(3));
        final descriptor = await ui.ImageDescriptor.encoded(
          await ui.ImmutableBuffer.fromUint8List(timerFrames.first.bytes),
        );
        expect(descriptor.width, equals(460));
        // Seconds show different digits, so the frames differ.
        expect(timerFrames[0].bytes, isNot(equals(timerFrames[1].bytes)));
      },
    );
  });
}
