// ABOUTME: Tests for the draw editor's own brushes: what neon, rainbow and
// ABOUTME: calligraphy strokes paint, and that the eraser clears each of them.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/utils/editor_draw_brushes.dart';
import 'package:pro_image_editor/features/paint_editor/models/eraser_model.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

const Size _canvas = Size(220, 100);
const Color _ground = Color(0xFF000000);
const Color _green = Color(0xFF00FF00);
const double _width = 20;

/// The points of a stroke from [from] to [to], recorded every two pixels as
/// a drag records them.
List<Offset?> _strokeBetween(Offset from, Offset to) {
  final steps = ((to - from).distance / 2).ceil();
  return [for (var i = 0; i <= steps; i++) Offset.lerp(from, to, i / steps)];
}

PaintedModel _stroke(
  PaintMode mode,
  List<Offset?> offsets, {
  double width = _width,
  List<ErasedOffset> erased = const [],
}) => PaintedModel(
  mode: mode,
  offsets: offsets,
  erasedOffsets: [...erased],
  color: _green,
  strokeWidth: width,
  opacity: 1,
);

/// Paints [item] on a black canvas and returns a reader for its pixels.
Future<Color Function(Offset)> _render(
  WidgetTester tester,
  PaintedModel item,
) async {
  late final ByteData bytes;
  await tester.runAsync(() async {
    final bounds = Offset.zero & _canvas;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, bounds)
      ..drawRect(bounds, Paint()..color = _ground);
    DrawPaintItem(
      item: item,
      paintEditorConfigs: EditorDrawBrushes.paintEditorConfigs,
    ).paint(canvas, _canvas);
    final image = await recorder.endRecording().toImage(
      _canvas.width.toInt(),
      _canvas.height.toInt(),
    );
    bytes = (await image.toByteData())!;
    image.dispose();
  });
  return (Offset point) {
    final i = (point.dy.round() * _canvas.width.toInt() + point.dx.round()) * 4;
    return Color.fromARGB(
      bytes.getUint8(i + 3),
      bytes.getUint8(i),
      bytes.getUint8(i + 1),
      bytes.getUint8(i + 2),
    );
  };
}

Matcher _closeToColor(Color expected, {double tolerance = 0.1}) => isA<Color>()
    .having((c) => c.r, 'r', closeTo(expected.r, tolerance))
    .having((c) => c.g, 'g', closeTo(expected.g, tolerance))
    .having((c) => c.b, 'b', closeTo(expected.b, tolerance));

void main() {
  group(EditorDrawBrushes, () {
    test('every brush mode records its whole stroke and has a builder', () {
      expect(
        EditorDrawBrushes.freeStyleModes,
        EditorDrawBrushes.pathBuilders.keys.toSet(),
      );
      for (final mode in EditorDrawBrushes.freeStyleModes) {
        expect(
          EditorDrawBrushes.paintEditorConfigs.isFreeStyleMode(mode),
          isTrue,
          reason: mode.name,
        );
      }
    });
  });

  group(NeonBrushPathBuilder, () {
    final line = _strokeBetween(const Offset(10, 50), const Offset(110, 50));

    testWidgets('draws a lighter core of the stroke color inside its glow', (
      tester,
    ) async {
      final pixelAt = await _render(
        tester,
        _stroke(EditorDrawBrushes.neon, line),
      );

      expect(
        pixelAt(const Offset(60, 50)),
        _closeToColor(
          Color.lerp(
            _green,
            const Color(0xFFFFFFFF),
            NeonBrushPathBuilder.coreLightening,
          )!,
          tolerance: 0.05,
        ),
      );

      final glow = pixelAt(const Offset(60, 54));
      expect(glow.g, greaterThan(0.5), reason: 'the glow is green');
      expect(glow.r, lessThan(0.2), reason: 'the glow is not lightened');
    });

    testWidgets('keeps its glow within half a stroke width of the line', (
      tester,
    ) async {
      final pixelAt = await _render(
        tester,
        _stroke(EditorDrawBrushes.neon, line),
      );

      expect(
        pixelAt(const Offset(60, 50 + _width / 2 + 1)).g,
        lessThan(0.05),
      );
    });
  });

  group(RainbowBrushPathBuilder, () {
    final builder = RainbowBrushPathBuilder(
      item: _stroke(EditorDrawBrushes.rainbow, const []),
      scale: 1,
      paintEditorConfigs: EditorDrawBrushes.paintEditorConfigs,
    );
    final colors = RainbowBrushPathBuilder.colors;
    const cycle = RainbowBrushPathBuilder.cycleLength;

    test('runs through every color once per cycle', () {
      expect(builder.colorAt(0), colors.first);
      expect(builder.colorAt(cycle / colors.length), colors[1]);
      expect(builder.colorAt(cycle), colors.first);
      expect(
        builder.colorAt(cycle * (colors.length - 0.5) / colors.length),
        Color.lerp(colors.last, colors.first, 0.5),
      );
    });

    testWidgets('paints each part of the stroke in its color', (tester) async {
      final pixelAt = await _render(
        tester,
        _stroke(
          EditorDrawBrushes.rainbow,
          _strokeBetween(const Offset(10, 50), const Offset(210, 50)),
          width: 10,
        ),
      );

      final second = cycle / colors.length;
      expect(pixelAt(const Offset(13, 50)), _closeToColor(builder.colorAt(3)));
      expect(
        pixelAt(Offset(10 + second, 50)),
        _closeToColor(builder.colorAt(second)),
      );
    });

    testWidgets('is the same color across a wide stroke', (tester) async {
      final pixelAt = await _render(
        tester,
        _stroke(
          EditorDrawBrushes.rainbow,
          _strokeBetween(const Offset(10, 50), const Offset(210, 50)),
          width: 60,
        ),
      );

      for (final x in [60.0, 110.0, 160.0]) {
        final center = pixelAt(Offset(x, 50));
        expect(pixelAt(Offset(x, 26)), _closeToColor(center, tolerance: 0.02));
        expect(pixelAt(Offset(x, 74)), _closeToColor(center, tolerance: 0.02));
      }
    });
  });

  group(CalligraphyBrushPathBuilder, () {
    testWidgets('is thick across the nib', (tester) async {
      // Down to the right: across a nib held rising to the right.
      final pixelAt = await _render(
        tester,
        _stroke(
          EditorDrawBrushes.calligraphy,
          _strokeBetween(const Offset(70, 20), const Offset(130, 80)),
        ),
      );

      // 0.35 stroke widths off the line, on its upper right side.
      expect(pixelAt(const Offset(105, 45)).g, greaterThan(0.9));
    });

    testWidgets('is a hairline along the nib', (tester) async {
      // Up to the right: along the nib.
      final pixelAt = await _render(
        tester,
        _stroke(
          EditorDrawBrushes.calligraphy,
          _strokeBetween(const Offset(70, 80), const Offset(130, 20)),
        ),
      );

      expect(pixelAt(const Offset(100, 50)).g, greaterThan(0.9));
      expect(pixelAt(const Offset(105, 55)).g, lessThan(0.05));
    });
  });

  group('erasing', () {
    for (final mode in EditorDrawBrushes.freeStyleModes) {
      testWidgets('clears the erased part of a ${mode.name} stroke', (
        tester,
      ) async {
        final pixelAt = await _render(
          tester,
          _stroke(
            mode,
            _strokeBetween(const Offset(10, 50), const Offset(110, 50)),
            erased: const [ErasedOffset(offset: Offset(60, 50), radius: 14)],
          ),
        );

        expect(pixelAt(const Offset(60, 50)), _ground);
        expect(pixelAt(const Offset(20, 50)), isNot(_ground));
      });
    }
  });
}
