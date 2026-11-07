// ABOUTME: Tests for EyedropperSnapshot and captureEyedropperSnapshot: which
// ABOUTME: pixels a pick averages, and that a painted boundary is captured.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/widgets/video_editor/eyedropper/eyedropper_snapshot.dart';

const _green = Color(0xFF00C000);
const _magenta = Color(0xFFC000C0);

/// Straight RGBA bytes for [pixels], row by row.
ByteData _rgba(List<(int r, int g, int b, int a)> pixels) {
  final data = ByteData(pixels.length * 4);
  for (final (index, (r, g, b, a)) in pixels.indexed) {
    data
      ..setUint8(index * 4, r)
      ..setUint8(index * 4 + 1, g)
      ..setUint8(index * 4 + 2, b)
      ..setUint8(index * 4 + 3, a);
  }
  return data;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(EyedropperSnapshot, () {
    late ui.Image image;

    setUp(() async {
      image = await createTestImage(width: 3, height: 3, cache: false);
    });

    tearDown(() => image.dispose());

    EyedropperSnapshot snapshotOf(
      List<(int, int, int, int)> pixels, {
      Size size = const Size(3, 3),
    }) => EyedropperSnapshot(image: image, pixels: _rgba(pixels), size: size);

    group('colorAt', () {
      test('averages the block around the touched pixel', () {
        // A single bright pixel in a dark block is noise, not the color.
        final snapshot = snapshotOf([
          for (var i = 0; i < 9; i++)
            if (i == 4) (90, 180, 45, 255) else (0, 0, 0, 255),
        ]);

        expect(
          snapshot.colorAt(const Offset(1.5, 1.5)),
          const Color(0xFF0A1405),
        );
      });

      test('averages only the pixels inside the image at a corner', () {
        final snapshot = snapshotOf([
          (40, 0, 0, 255), (0, 40, 0, 255), (99, 99, 99, 255), //
          (0, 0, 40, 255), (40, 40, 40, 255), (99, 99, 99, 255),
          (99, 99, 99, 255), (99, 99, 99, 255), (99, 99, 99, 255),
        ]);

        expect(snapshot.colorAt(Offset.zero), const Color(0xFF141414));
      });

      test('keeps the painted color where part of the block is empty', () {
        final snapshot = snapshotOf([
          for (var i = 0; i < 9; i++)
            if (i.isEven) (0, 192, 0, 255) else (255, 255, 255, 0),
        ]);

        expect(snapshot.colorAt(const Offset(1.5, 1.5)), _green);
      });

      test('has nothing to pick where nothing was painted', () {
        final snapshot = snapshotOf([
          for (var i = 0; i < 9; i++) (255, 0, 0, 0),
        ]);

        expect(snapshot.colorAt(const Offset(1.5, 1.5)), isNull);
      });

      test('maps logical pixels onto the image at its pixel ratio', () {
        // A 3x3 image of a 1x1 logical area: three image pixels per point.
        final snapshot = snapshotOf(
          [
            for (var i = 0; i < 9; i++) (0, 0, 0, 255),
          ],
          size: const Size(1, 1),
        );

        expect(snapshot.pixelAt(const Offset(0.9, 0.9)), (x: 2, y: 2));
        expect(snapshot.pixelAt(const Offset(5, -5)), (x: 2, y: 0));
      });
    });
  });

  group('captureEyedropperSnapshot', () {
    testWidgets('captures what the boundary shows at the pixel ratio', (
      tester,
    ) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: RepaintBoundary(
              key: key,
              child: const SizedBox(
                width: 100,
                height: 50,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: ColoredBox(color: _green)),
                    Expanded(child: ColoredBox(color: _magenta)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;

      final snapshot = await tester.runAsync(
        () => captureEyedropperSnapshot(boundary, pixelRatio: 2),
      );
      addTearDown(() => snapshot?.dispose());

      expect(snapshot, isNotNull);
      expect(snapshot!.size, const Size(100, 50));
      expect(snapshot.image.width, 200);
      expect(snapshot.colorAt(const Offset(25, 25)), _green);
      expect(snapshot.colorAt(const Offset(75, 25)), _magenta);
    });
  });
}
