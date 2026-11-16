// ABOUTME: Writes the glyph atlas the video editor's ASCII effect draws its
// ABOUTME: characters from, into assets/effects/ascii_glyphs.png.
//
// Run from mobile/:
//
//   dart tools/generate_ascii_glyphs.dart
//
// The PNG is 240x24: ten glyphs of 24x24 side by side, white on black, from
// the emptiest to the fullest, so the renderers (`AsciiVideoEffect` on
// Android, iOS and macOS, and `shaders/ascii.frag` for the picker tile) pick
// glyph `floor(brightness * 10)`. Each glyph is drawn from strokes and rings
// in a unit square with y down, antialiased by sampling every pixel 8x8
// times, so it stays smooth when the renderers scale it to their cells with
// bilinear filtering. The glyphs are drawn here rather than taken from a
// font, so they look the same on every platform.

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

/// Pixels per side of a glyph.
const glyphSize = 24;

/// Half the width of every stroke, as a share of a glyph's side.
const _halfWidth = 0.065;

/// A part of a glyph: everything within [halfWidth] of the segment from
/// ([ax], [ay]) to ([bx], [by]), or of the circle around ([ax], [ay]) of
/// [radius] when it is set.
typedef Shape = ({
  double ax,
  double ay,
  double bx,
  double by,
  double? radius,
  double halfWidth,
});

Shape line(double ax, double ay, double bx, double by) =>
    (ax: ax, ay: ay, bx: bx, by: by, radius: null, halfWidth: _halfWidth);

Shape dot(double x, double y, double radius) =>
    (ax: x, ay: y, bx: x, by: y, radius: null, halfWidth: radius);

Shape ring(double x, double y, double radius) =>
    (ax: x, ay: y, bx: x, by: y, radius: radius, halfWidth: _halfWidth);

/// The glyphs, emptiest first: each covers more of its square than the one
/// before, which [main] checks.
final Map<String, List<Shape>> glyphs = {
  ' ': const [],
  '.': [dot(0.5, 0.78, 0.09)],
  ':': [dot(0.5, 0.38, 0.09), dot(0.5, 0.78, 0.09)],
  '-': [line(0.24, 0.56, 0.76, 0.56)],
  '+': [line(0.2, 0.56, 0.8, 0.56), line(0.5, 0.26, 0.5, 0.86)],
  '=': [line(0.2, 0.42, 0.8, 0.42), line(0.2, 0.7, 0.8, 0.7)],
  '*': [
    line(0.5, 0.2, 0.5, 0.84),
    line(0.22, 0.36, 0.78, 0.68),
    line(0.22, 0.68, 0.78, 0.36),
  ],
  '%': [
    ring(0.3, 0.28, 0.14),
    ring(0.7, 0.74, 0.14),
    line(0.8, 0.12, 0.2, 0.9),
  ],
  '#': [
    line(0.38, 0.12, 0.38, 0.9),
    line(0.62, 0.12, 0.62, 0.9),
    line(0.14, 0.37, 0.86, 0.37),
    line(0.14, 0.65, 0.86, 0.65),
  ],
  '@': [
    ring(0.5, 0.5, 0.37),
    ring(0.52, 0.5, 0.14),
    line(0.66, 0.36, 0.66, 0.64),
    line(0.66, 0.64, 0.82, 0.64),
  ],
};

void main() {
  final width = glyphSize * glyphs.length;
  final pixels = Uint8List(width * glyphSize * 3);
  var previous = -1.0;
  var index = 0;
  for (final MapEntry(key: name, value: shapes) in glyphs.entries) {
    final coverage = drawGlyph(shapes);
    final total = coverage.fold(0.0, (sum, value) => sum + value);
    if (total <= previous) {
      stderr.writeln('"$name" covers no more than the glyph before it');
      exit(1);
    }
    previous = total;
    for (var y = 0; y < glyphSize; y++) {
      for (var x = 0; x < glyphSize; x++) {
        final value = (coverage[y * glyphSize + x] * 255).round();
        final i = (y * width + index * glyphSize + x) * 3;
        pixels
          ..[i] = value
          ..[i + 1] = value
          ..[i + 2] = value;
      }
    }
    stdout.writeln(
      '"$name" covers ${(100 * total / (glyphSize * glyphSize)).toStringAsFixed(1)}%',
    );
    index++;
  }
  final out = File('assets/effects/ascii_glyphs.png')
    ..parent.createSync(recursive: true)
    ..writeAsBytesSync(encodePng(pixels, width, glyphSize));
  stdout.writeln('Wrote ${out.path}');
}

/// How much of each pixel of a glyph made of [shapes] is inked, row by row
/// from the top.
List<double> drawGlyph(List<Shape> shapes) {
  const samples = 8;
  return [
    for (var y = 0; y < glyphSize; y++)
      for (var x = 0; x < glyphSize; x++)
        () {
          var inked = 0;
          for (var j = 0; j < samples; j++) {
            for (var i = 0; i < samples; i++) {
              final px = (x + (i + 0.5) / samples) / glyphSize;
              final py = (y + (j + 0.5) / samples) / glyphSize;
              if (shapes.any((shape) => _covers(shape, px, py))) inked++;
            }
          }
          return inked / (samples * samples);
        }(),
  ];
}

bool _covers(Shape shape, double px, double py) {
  final radius = shape.radius;
  if (radius != null) {
    final d = math.sqrt(
      (px - shape.ax) * (px - shape.ax) + (py - shape.ay) * (py - shape.ay),
    );
    return (d - radius).abs() <= shape.halfWidth;
  }
  final dx = shape.bx - shape.ax;
  final dy = shape.by - shape.ay;
  final length = dx * dx + dy * dy;
  final t = length == 0
      ? 0.0
      : (((px - shape.ax) * dx + (py - shape.ay) * dy) / length).clamp(
          0.0,
          1.0,
        );
  final ex = px - shape.ax - dx * t;
  final ey = py - shape.ay - dy * t;
  return math.sqrt(ex * ex + ey * ey) <= shape.halfWidth;
}

/// [pixels], 8-bit RGB rows from the top, as a PNG without a colour profile,
/// so every renderer reads exactly these values.
Uint8List encodePng(Uint8List pixels, int width, int height) {
  final raw = BytesBuilder();
  for (var y = 0; y < height; y++) {
    raw
      ..addByte(0)
      ..add(Uint8List.sublistView(pixels, y * width * 3, (y + 1) * width * 3));
  }
  final header = ByteData(13)
    ..setUint32(0, width)
    ..setUint32(4, height)
    ..setUint8(8, 8)
    ..setUint8(9, 2);
  return (BytesBuilder()
        ..add(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        ..add(_chunk('IHDR', header.buffer.asUint8List()))
        ..add(_chunk('IDAT', ZLibEncoder(level: 9).convert(raw.takeBytes())))
        ..add(_chunk('IEND', const [])))
      .takeBytes();
}

List<int> _chunk(String type, List<int> data) {
  final typed = [...type.codeUnits, ...data];
  final length = ByteData(4)..setUint32(0, data.length);
  final crc = ByteData(4)..setUint32(0, _crc32(typed));
  return [
    ...length.buffer.asUint8List(),
    ...typed,
    ...crc.buffer.asUint8List(),
  ];
}

int _crc32(List<int> bytes) {
  var crc = 0xFFFFFFFF;
  for (final byte in bytes) {
    crc ^= byte;
    for (var k = 0; k < 8; k++) {
      crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xEDB88320 : crc >> 1;
    }
  }
  return crc ^ 0xFFFFFFFF;
}
