// ABOUTME: The draw editor's own freehand brushes (neon, rainbow, calligraphy)
// ABOUTME: and the custom paint modes the paint editor draws them with.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:openvine/models/video_editor/text_gradient_presets.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

/// The freehand brushes of the draw editor beyond the package's own, and the
/// custom paint modes they draw with.
///
/// Drafts store a stroke's mode by name, so a brush keeps its mode for good.
abstract final class EditorDrawBrushes {
  /// A glowing tube in the stroke's color around a lighter core.
  static const PaintMode neon = PaintMode.custom1;

  /// A stroke that runs through the colors of the rainbow.
  static const PaintMode rainbow = PaintMode.custom2;

  /// A broad pen held at a fixed angle: thick across it, thin along it.
  static const PaintMode calligraphy = PaintMode.custom3;

  /// Draws every brush; see `PaintEditorConfigs.customPathBuilders`.
  static const Map<PaintMode, CustomPathBuilderFactory> pathBuilders = {
    neon: NeonBrushPathBuilder.new,
    rainbow: RainbowBrushPathBuilder.new,
    calligraphy: CalligraphyBrushPathBuilder.new,
  };

  /// The brush modes, which record the whole stroke rather than its ends.
  static const Set<PaintMode> freeStyleModes = {neon, rainbow, calligraphy};

  /// Paint editor configs that can draw the brushes, for strokes painted
  /// outside the editor canvas.
  static const PaintEditorConfigs paintEditorConfigs = PaintEditorConfigs(
    customPathBuilders: pathBuilders,
    freeStyleCustomModes: freeStyleModes,
  );
}

/// Draws [EditorDrawBrushes.neon]: a blurred tube in the stroke's color around
/// a core in a lighter shade of it.
///
/// The glow stays within half a stroke width of the line, the margin a paint
/// layer keeps around its points, so a rastered layer does not cut it off.
class NeonBrushPathBuilder extends PathBuilderFreestyle {
  /// Creates the builder for one neon stroke.
  NeonBrushPathBuilder({
    required super.item,
    required super.scale,
    required super.paintEditorConfigs,
  });

  /// How far the core's color is blended from the stroke's toward white.
  static const double coreLightening = 0.35;

  @override
  void draw({required Canvas canvas, required Size size}) {
    if (offsets.length <= 1) return;
    build();
    final width = painter.strokeWidth;
    final color = painter.color;
    final core = Color.lerp(color, VineTheme.whiteText, coreLightening)!;

    drawInLayer(
      canvas: canvas,
      size: size,
      paintContent: () {
        canvas
          ..drawPath(path, _neonStroke(color, width * 0.56, width * 0.07))
          ..drawPath(path, _neonStroke(color, width * 0.34, width * 0.04))
          ..drawPath(path, _neonStroke(core, width * 0.16, 0));
      },
    );
  }

  Paint _neonStroke(Color color, double width, double blurSigma) {
    final paint = Paint()
      ..color = color
      ..style = .stroke
      ..strokeWidth = width
      ..strokeCap = .round
      ..strokeJoin = .round;
    if (blurSigma > 0) paint.maskFilter = MaskFilter.blur(.normal, blurSigma);
    return paint;
  }
}

/// Draws [EditorDrawBrushes.rainbow]: the stroke blends through the colors of
/// the text editor's rainbow gradient, once every [cycleLength] of stroke.
///
/// It keeps the alpha of the stroke's color but none of its hue. The colors
/// run along a band of vertices, and the stroke itself, drawn as a mask over
/// them, gives the band its round ends and smooth edges.
class RainbowBrushPathBuilder extends PathBuilderFreestyle {
  /// Creates the builder for one rainbow stroke.
  RainbowBrushPathBuilder({
    required super.item,
    required super.scale,
    required super.paintEditorConfigs,
  });

  /// How long a stroke runs, in logical pixels of the editor, to go once
  /// through every color and back to the first.
  static const double cycleLength = 480;

  /// The colors the stroke runs through.
  static final List<Color> colors = TextGradientPreset.rainbow.colors;

  /// How far the colors reach past the mask, so its smoothed edge never
  /// shows the band's hard one.
  static const double _colorMargin = 2;

  /// The cosine of the sharpest turn the band follows without a gap on its
  /// outer side; a sharper corner gets a disc in its color.
  static const double _cornerCosine = 0.9;

  /// The color the stroke has [distance] logical pixels from its start.
  Color colorAt(double distance) {
    final position = (distance / cycleLength) % 1 * colors.length;
    final index = position.floor();
    final blended = Color.lerp(
      colors[index],
      colors[(index + 1) % colors.length],
      position - index,
    )!;
    return blended.withValues(alpha: painter.color.a);
  }

  @override
  void draw({required Canvas canvas, required Size size}) {
    if (offsets.length <= 1) return;
    final strokes = _strokePoints();
    if (strokes.isEmpty) return;

    final width = painter.strokeWidth;
    final outline = Path();
    for (final stroke in strokes) {
      final first = stroke.first.point;
      outline.moveTo(first.dx, first.dy);
      for (final (:point, distance: _) in stroke.skip(1)) {
        outline.lineTo(point.dx, point.dy);
      }
      // A tap still leaves a dot.
      if (stroke.length == 1) outline.lineTo(first.dx, first.dy);
    }
    final mask = Paint()
      ..blendMode = .dstIn
      ..style = .stroke
      ..strokeWidth = width
      ..strokeCap = .round
      ..strokeJoin = .round;

    drawInLayer(
      canvas: canvas,
      size: size,
      paintContent: () {
        // Opaque inside, so where the band overlaps itself it does not
        // darken; the stroke's alpha fades the whole of it.
        canvas.saveLayer(
          outline.getBounds().inflate(width),
          Paint()
            ..color = VineTheme.whiteText.withValues(alpha: painter.color.a),
        );
        for (final stroke in strokes) {
          _paintColors(canvas, stroke, width / 2 + _colorMargin * scale);
        }
        canvas
          ..drawPath(outline, mask)
          ..restore();
      },
    );
  }

  /// The points of each part of the stroke, with how far along the whole
  /// stroke each lies, in logical pixels of the editor.
  List<List<({Offset point, double distance})>> _strokePoints() {
    final strokes = <List<({Offset point, double distance})>>[];
    List<({Offset point, double distance})>? current;
    var distance = 0.0;
    for (final raw in offsets) {
      if (raw == null) {
        current = null;
        continue;
      }
      final point = raw * scale;
      if (current == null) {
        current = [(point: point, distance: distance)];
        strokes.add(current);
        continue;
      }
      final step = (point - current.last.point).distance;
      // A repeated point has no direction to lay the band across.
      if (step < 0.5) continue;
      distance += step / scale;
      current.add((point: point, distance: distance));
    }
    return strokes;
  }

  /// Paints the colors of one part of the stroke: a band [halfWidth] to each
  /// side of it, over discs that fill its ends and sharp corners.
  void _paintColors(
    Canvas canvas,
    List<({Offset point, double distance})> stroke,
    double halfWidth,
  ) {
    final disc = Paint();
    void paintDisc(int i) => canvas.drawCircle(
      stroke[i].point,
      halfWidth,
      disc..color = _opaqueColorAt(stroke[i].distance),
    );

    paintDisc(0);
    paintDisc(stroke.length - 1);
    if (stroke.length < 2) return;
    for (var i = 1; i < stroke.length - 1; i++) {
      final before = _direction(stroke[i - 1].point, stroke[i].point);
      final after = _direction(stroke[i].point, stroke[i + 1].point);
      if (before.dx * after.dx + before.dy * after.dy < _cornerCosine) {
        paintDisc(i);
      }
    }

    final positions = <Offset>[];
    final vertexColors = <Color>[];
    for (var i = 0; i < stroke.length; i++) {
      final from = stroke[i == 0 ? 0 : i - 1].point;
      final to = stroke[i == stroke.length - 1 ? i : i + 1].point;
      var along = to - from;
      // A hairpin turns back onto the point before it.
      if (along.distance < 0.5) along = stroke[i].point - stroke[i - 1].point;
      final side = Offset(-along.dy, along.dx) / along.distance * halfWidth;
      final color = _opaqueColorAt(stroke[i].distance);
      positions
        ..add(stroke[i].point + side)
        ..add(stroke[i].point - side);
      vertexColors
        ..add(color)
        ..add(color);
    }
    canvas.drawVertices(
      ui.Vertices(.triangleStrip, positions, colors: vertexColors),
      .dst,
      Paint(),
    );
  }

  Color _opaqueColorAt(double distance) =>
      colorAt(distance).withValues(alpha: 1);

  static Offset _direction(Offset from, Offset to) {
    final along = to - from;
    return along / along.distance;
  }
}

/// Draws [EditorDrawBrushes.calligraphy]: a broad nib, as wide as the stroke,
/// held at [nibAngle].
///
/// Every move sweeps the nib across a parallelogram; a hairline along the
/// path keeps a stroke drawn along the nib from vanishing.
class CalligraphyBrushPathBuilder extends PathBuilderFreestyle {
  /// Creates the builder for one calligraphy stroke.
  CalligraphyBrushPathBuilder({
    required super.item,
    required super.scale,
    required super.paintEditorConfigs,
  });

  /// The angle the nib is held at: rising to the right, as a right-handed
  /// pen is.
  static const double nibAngle = -math.pi / 4;

  /// How thick the thinnest line is, as a share of the stroke width.
  static const double _hairlineFactor = 0.14;

  @override
  void draw({required Canvas canvas, required Size size}) {
    if (offsets.length <= 1) return;
    final width = painter.strokeWidth;
    final nib = Offset.fromDirection(nibAngle, width / 2);
    final ink = Path();
    final hairline = Path();
    Offset? previous;

    for (final raw in offsets) {
      if (raw == null) {
        previous = null;
        continue;
      }
      final point = raw * scale;
      if (previous == null) {
        hairline.moveTo(point.dx, point.dy);
      } else {
        _addSweep(ink, previous, point, nib);
        hairline.lineTo(point.dx, point.dy);
      }
      previous = point;
    }

    final fill = Paint()
      ..color = painter.color
      ..style = .fill;
    final line = Paint()
      ..color = painter.color
      ..style = .stroke
      ..strokeWidth = width * _hairlineFactor
      ..strokeCap = .round
      ..strokeJoin = .round;

    drawInLayer(
      canvas: canvas,
      size: size,
      paintContent: () {
        canvas
          ..drawPath(ink, fill)
          ..drawPath(hairline, line);
      },
    );
  }

  /// Adds the area the nib sweeps moving from [from] to [to].
  ///
  /// Every piece winds the same way, so the non-zero fill covers where they
  /// overlap instead of cutting holes there.
  void _addSweep(Path ink, Offset from, Offset to, Offset nib) {
    final move = to - from;
    final corners = [from - nib, to - nib, to + nib, from + nib];
    final windsClockwise = move.dx * nib.dy - move.dy * nib.dx > 0;
    ink.addPolygon(windsClockwise ? corners : corners.reversed.toList(), true);
  }
}
