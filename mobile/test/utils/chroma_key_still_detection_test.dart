import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/utils/chroma_key_still_detection.dart';
import 'package:pro_video_editor/pro_video_editor.dart'
    show ChromaKeyDetectionException;

/// Writes a PNG of a [width] x [height] frame to a temp file.
///
/// The frame is [wall] everywhere except an opaque [subject] block in the
/// centre, plus — when [edgeBand] is set — a band of [edge] down the left and
/// right edges, standing in for what a wider still shows beyond the video.
Future<String> _writeStill(
  Directory dir, {
  required int width,
  required int height,
  required ui.Color wall,
  ui.Color subject = const ui.Color(0xFFD9A07A),
  ui.Color edge = const ui.Color(0xFF7F7F7F),
  int edgeBand = 0,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder)
    ..drawRect(
      ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      ui.Paint()..color = wall,
    )
    ..drawRect(
      ui.Rect.fromCenter(
        center: ui.Offset(width / 2, height / 2),
        width: width * 0.3,
        height: height * 0.4,
      ),
      ui.Paint()..color = subject,
    );
  if (edgeBand > 0) {
    final paint = ui.Paint()..color = edge;
    canvas
      ..drawRect(
        ui.Rect.fromLTWH(0, 0, edgeBand.toDouble(), height.toDouble()),
        paint,
      )
      ..drawRect(
        ui.Rect.fromLTWH(
          (width - edgeBand).toDouble(),
          0,
          edgeBand.toDouble(),
          height.toDouble(),
        ),
        paint,
      );
  }
  final image = await recorder.endRecording().toImage(width, height);
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  final file = File('${dir.path}/still_${width}x$height.png');
  await file.writeAsBytes(png!.buffer.asUint8List());
  return file.path;
}

void main() {
  group('centerCropRect', () {
    test('trims the sides of a still wider than the frame', () {
      final crop = centerCropRect(width: 300, height: 400, aspectRatio: 9 / 16);

      expect(crop, (left: 37, top: 0, width: 225, height: 400));
    });

    test('trims the top and bottom of a still taller than the frame', () {
      final crop = centerCropRect(width: 400, height: 400, aspectRatio: 2);

      expect(crop, (left: 0, top: 100, width: 400, height: 200));
    });
  });

  group('cropRgba', () {
    test('copies exactly the pixels inside the rectangle', () {
      // A 3x2 image whose red channel holds the pixel index.
      final rgba = Uint8List.fromList([
        for (var i = 0; i < 6; i++) ...[i, 0, 0, 255],
      ]);

      final cropped = cropRgba(
        rgba,
        sourceWidth: 3,
        crop: (left: 1, top: 0, width: 2, height: 2),
      );

      expect(
        [for (var i = 0; i < cropped.length; i += 4) cropped[i]],
        [
          1,
          2,
          4,
          5,
        ],
      );
    });
  });

  group('detectChromaKeyInStill', () {
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync('still_detect'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('measures a wall that fills the frame behind the subject', () async {
      const wall = ui.Color(0xFF2A9D37);
      final path = await _writeStill(
        dir,
        width: 180,
        height: 320,
        wall: wall,
      );

      final detection = await detectChromaKeyInStill(
        path,
        visibleAspectRatio: 9 / 16,
      );

      expect(detection.color.g, greaterThan(detection.color.r));
      expect(detection.color.g, greaterThan(detection.color.b));
      expect(detection.coverage, greaterThan(0.9));
    });

    test(
      'ignores what a wider still shows beyond the edges of the video',
      () async {
        // 3:4 still, of which a 9:16 video keeps the centre 180 px. The grey
        // bands sit entirely in the 30 px a side the video crops away, and are
        // as wide as the border ring the detector reads — measured uncropped,
        // most of that ring would be grey and the wall would not be found.
        final path = await _writeStill(
          dir,
          width: 240,
          height: 320,
          wall: const ui.Color(0xFF2A9D37),
          edgeBand: 28,
        );

        final detection = await detectChromaKeyInStill(
          path,
          visibleAspectRatio: 9 / 16,
        );

        expect(detection.coverage, greaterThan(0.9));
      },
    );

    test('reports a grey frame as having no screen', () async {
      final path = await _writeStill(
        dir,
        width: 180,
        height: 320,
        wall: const ui.Color(0xFF808080),
      );

      expect(
        detectChromaKeyInStill(path, visibleAspectRatio: 9 / 16),
        throwsA(isA<ChromaKeyDetectionException>()),
      );
    });

    test('reports a file that is not an image as having no screen', () async {
      final file = File('${dir.path}/broken.jpg')..writeAsStringSync('nope');

      expect(
        detectChromaKeyInStill(file.path, visibleAspectRatio: 9 / 16),
        throwsA(isA<ChromaKeyDetectionException>()),
      );
    });
  });
}
