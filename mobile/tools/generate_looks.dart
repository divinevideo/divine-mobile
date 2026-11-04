// ABOUTME: Writes the video editor's colour-graded looks as 33x33x33 lookup
// ABOUTME: tables, one PNG strip per look, into assets/looks.
//
// Run from mobile/:
//
//   dart tools/generate_looks.dart
//       writes every look below.
//   dart tools/generate_looks.dart --cube <file.cube> <name>
//       turns a 33-point .cube file, as Resolve, Lightroom or Photoshop export
//       it, into assets/looks/<name>.png instead.
//
// Each PNG is 1089x33: 33 slices of 33x33 side by side, one per blue level,
// with red growing to the right within a slice and green growing downwards.
// Pixel (b * 33 + r, g) holds the colour the input (r, g, b) / 32 turns into.
// The renderers (`LookVideoEffect` on Android, iOS and macOS, and
// `shaders/look.frag` for the picker tile) interpolate between the grid
// points, all on the sRGB-encoded values the frames carry.
//
// The looks work on those encoded values too, and every step is smooth, so
// the 33-point grid holds them without banding.

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

/// Points per side of a lookup table.
const lutSize = 33;

/// A colour with channels from 0 to 1, sRGB-encoded.
typedef Rgb = ({double r, double g, double b});

/// Every look, by the asset name the renderers load it under.
final Map<String, Rgb Function(Rgb)> looks = {
  'teal_orange': tealOrange,
  'warm_film': warmFilm,
  'slide_film': slideFilm,
  'cool_film': coolFilm,
  'matte': matte,
  'bleach_bypass': bleachBypass,
  'cross_process': crossProcess,
  'golden_hour': goldenHour,
  'moonlight': moonlight,
  'silver': silver,
};

void main(List<String> args) {
  final out = Directory('assets/looks')..createSync(recursive: true);
  if (args.length == 3 && args.first == '--cube') {
    final table = readCube(File(args[1]).readAsStringSync());
    File('${out.path}/${args[2]}.png').writeAsBytesSync(encodePng(table));
    stdout.writeln('Wrote ${out.path}/${args[2]}.png');
    return;
  }
  if (args.isNotEmpty) {
    stderr.writeln(
      'Usage: dart tools/generate_looks.dart [--cube <file> <name>]',
    );
    exit(64);
  }
  for (final MapEntry(key: name, value: look) in looks.entries) {
    File('${out.path}/$name.png').writeAsBytesSync(encodePng(tableOf(look)));
    stdout.writeln('Wrote ${out.path}/$name.png');
  }
}

/// Teal and orange: the blockbuster grade. Skin and warm colours lean
/// orange, everything from green to blue leans teal, shadows go teal and
/// highlights warm, over a gentle S-curve.
Rgb tealOrange(Rgb c) {
  var x = curve(c, const [
    (0, 0.02),
    (0.25, 0.21),
    (0.5, 0.5),
    (0.75, 0.8),
    (1, 0.98),
  ]);
  x = hueShift(x, [
    (center: 30, width: 35, toward: 28, amount: 0.4, saturation: 1.1),
    (center: 150, width: 60, toward: 185, amount: 0.7, saturation: 1.1),
    (center: 225, width: 35, toward: 195, amount: 0.5, saturation: 1.1),
    (center: 300, width: 40, toward: 345, amount: 0.3, saturation: 0.85),
  ]);
  x = splitTone(
    x,
    shadows: (r: -0.08, g: 0.02, b: 0.06),
    highlights: (r: 0.07, g: 0.015, b: -0.07),
  );
  return saturate(x, 1.1);
}

/// Warm film: a portrait colour negative. Soft contrast with lifted blacks
/// and a gentle shoulder, warm and creamy, greens muted towards olive and
/// blues towards cyan, skin left warm and natural.
Rgb warmFilm(Rgb c) {
  var x = curve(c, const [
    (0, 0.045),
    (0.2, 0.2),
    (0.5, 0.52),
    (0.8, 0.82),
    (1, 0.955),
  ]);
  x = hueShift(x, [
    (center: 25, width: 25, toward: 27, amount: 0.3, saturation: 1.0),
    (center: 115, width: 45, toward: 90, amount: 0.35, saturation: 0.75),
    (center: 215, width: 40, toward: 200, amount: 0.3, saturation: 0.85),
  ]);
  x = splitTone(
    x,
    shadows: (r: 0.01, g: 0.0, b: -0.01),
    highlights: (r: 0.035, g: 0.02, b: -0.03),
  );
  return saturate(x, 0.92);
}

/// Slide film: a vivid reversal stock. Hard contrast, rich colours that
/// stop short of clipping, deep blue skies, lush greens, a touch of magenta
/// in the shadows, skin kept from turning red.
Rgb slideFilm(Rgb c) {
  var x = curve(c, const [
    (0, 0),
    (0.25, 0.18),
    (0.5, 0.5),
    (0.75, 0.83),
    (1, 1),
  ]);
  x = hueShift(x, [
    (center: 25, width: 25, toward: 30, amount: 0.3, saturation: 0.85),
    (center: 115, width: 40, toward: 118, amount: 0.2, saturation: 1.15),
    (center: 220, width: 35, toward: 225, amount: 0.2, saturation: 1.2),
  ]);
  x = splitTone(
    x,
    shadows: (r: 0.015, g: -0.015, b: 0.02),
    highlights: (r: 0.0, g: 0.0, b: 0.0),
  );
  return saturate(x, 1.35);
}

/// Cool film: a crisp everyday colour negative. Clean and cool, greens
/// towards emerald, reds towards crimson, yellows and skin a little calmer,
/// cyan in the shadows.
Rgb coolFilm(Rgb c) {
  var x = curve(c, const [
    (0, 0.025),
    (0.25, 0.22),
    (0.5, 0.5),
    (0.75, 0.79),
    (1, 0.975),
  ]);
  x = hueShift(x, [
    (center: 5, width: 25, toward: 350, amount: 0.4, saturation: 1.05),
    (center: 50, width: 20, toward: 45, amount: 0.2, saturation: 0.8),
    (center: 110, width: 45, toward: 150, amount: 0.55, saturation: 1.1),
    (center: 210, width: 40, toward: 200, amount: 0.3, saturation: 1.1),
  ]);
  x = splitTone(
    x,
    shadows: (r: -0.035, g: 0.012, b: 0.035),
    highlights: (r: -0.005, g: 0.0, b: 0.025),
  );
  return saturate(x, 1.0);
}

/// Matte: the soft faded look. Blacks lifted and flattened, whites dimmed,
/// colours muted, shadows faintly cool and highlights faintly warm.
Rgb matte(Rgb c) {
  var x = curve(c, const [
    (0, 0.13),
    (0.15, 0.18),
    (0.5, 0.5),
    (0.85, 0.84),
    (1, 0.92),
  ]);
  x = splitTone(
    x,
    shadows: (r: -0.01, g: 0.0, b: 0.015),
    highlights: (r: 0.015, g: 0.008, b: -0.01),
  );
  return saturate(x, 0.75);
}

/// Bleach bypass: cold, hard and silvery, as when film skips its bleach.
/// The picture's own greys are laid over it for contrast, then most of the
/// colour drains out and a cool cast stays.
Rgb bleachBypass(Rgb c) {
  final y = luma(c);
  final overlaid = (r: overlay(c.r, y), g: overlay(c.g, y), b: overlay(c.b, y));
  var x = mixRgb(c, overlaid, 0.75);
  x = curve(x, const [(0, 0), (0.5, 0.5), (0.8, 0.84), (1, 0.95)]);
  x = saturate(x, 0.5);
  return splitTone(
    x,
    shadows: (r: -0.02, g: 0.0, b: 0.02),
    highlights: (r: -0.01, g: 0.0, b: 0.01),
  );
}

/// Cross process: slide film developed as a negative. Contrasty reds and
/// greens over a flattened blue channel, so shadows go blue and highlights
/// yellow.
Rgb crossProcess(Rgb c) {
  final x = (
    r: spline(const [
      (0, 0),
      (0.25, 0.16),
      (0.5, 0.52),
      (0.75, 0.87),
      (1, 1),
    ], c.r),
    g: spline(const [
      (0, 0.02),
      (0.25, 0.2),
      (0.5, 0.54),
      (0.75, 0.85),
      (1, 0.98),
    ], c.g),
    b: spline(const [(0, 0.2), (0.5, 0.48), (1, 0.78)], c.b),
  );
  return saturate(x, 1.1);
}

/// Golden hour: late warm sun. Lifted mids, golden highlights, greens
/// towards yellow and skies paler.
Rgb goldenHour(Rgb c) {
  var x = curve(c, const [
    (0, 0.015),
    (0.3, 0.33),
    (0.6, 0.66),
    (0.85, 0.88),
    (1, 0.98),
  ]);
  x = hueShift(x, [
    (center: 30, width: 30, toward: 33, amount: 0.3, saturation: 1.15),
    (center: 110, width: 40, toward: 80, amount: 0.4, saturation: 0.95),
    (center: 215, width: 40, toward: 205, amount: 0.2, saturation: 0.75),
  ]);
  x = splitTone(
    x,
    shadows: (r: 0.03, g: 0.005, b: -0.03),
    highlights: (r: 0.09, g: 0.045, b: -0.08),
  );
  return saturate(x, 1.1);
}

/// Moonlight: day for night. Darker by a stop and a half in the shadows,
/// with most of the colour gone and a deep blue cast; the brightest parts
/// stay as moonlit highlights.
Rgb moonlight(Rgb c) {
  var x = saturate(c, 0.45);
  x = curve(x, const [
    (0, 0),
    (0.3, 0.13),
    (0.6, 0.35),
    (0.85, 0.62),
    (1, 0.8),
  ]);
  x = (r: x.r * 0.78, g: x.g * 0.92, b: math.min(1, x.b * 1.12 + 0.025));
  return splitTone(
    x,
    shadows: (r: -0.005, g: 0.005, b: 0.03),
    highlights: (r: 0.0, g: 0.0, b: 0.0),
  );
}

/// Silver: black-and-white film through an orange filter, which darkens
/// blue skies, with deep blacks, bright whites and a soft shoulder.
Rgb silver(Rgb c) {
  final y = 0.5 * c.r + 0.43 * c.g + 0.07 * c.b;
  final v = spline(const [
    (0, 0),
    (0.2, 0.12),
    (0.5, 0.5),
    (0.8, 0.88),
    (1, 0.98),
  ], y);
  return (r: v, g: v, b: v);
}

/// One hue range a look pulls: hues within about [width] degrees of
/// [center] turn by [amount] of the way towards [toward], and their
/// saturation is scaled by [saturation].
typedef HueRange = ({
  double center,
  double width,
  double toward,
  double amount,
  double saturation,
});

/// Pulls the hues and saturations of [ranges] on [c], each weighted by how
/// close its hue is to the range's centre. Greys keep their hue-less self.
Rgb hueShift(Rgb c, List<HueRange> ranges) {
  final (h, s, v) = toHsv(c);
  var hue = h;
  var saturation = s;
  for (final range in ranges) {
    final weight = math.exp(
      -math.pow(hueDistance(h, range.center) / range.width, 2),
    );
    hue += weight * range.amount * hueDistance(range.toward, h);
    saturation = scaleSaturation(
      saturation,
      1 + weight * (range.saturation - 1),
    );
  }
  return fromHsv(hue % 360, saturation, v);
}

/// Adds [shadows] to the dark parts of [c] and [highlights] to the bright
/// ones, fading out towards the other end.
Rgb splitTone(Rgb c, {required Rgb shadows, required Rgb highlights}) {
  final y = luma(c);
  final dark = math.pow(1 - y, 2).toDouble();
  final bright = math.pow(y, 2).toDouble();
  return (
    r: c.r + dark * shadows.r + bright * highlights.r,
    g: c.g + dark * shadows.g + bright * highlights.g,
    b: c.b + dark * shadows.b + bright * highlights.b,
  );
}

/// Scales the colour of [c] around its own grey by [factor], easing off as
/// colours get more saturated so the strongest ones do not clip.
Rgb saturate(Rgb c, double factor) {
  final (h, s, v) = toHsv(clamp(c));
  final grey = luma(c);
  final scaled = fromHsv(h, scaleSaturation(s, factor), v);
  // Keep the brightness: HSV saturation moves the luma, so put it back.
  final shift = grey - luma(scaled);
  return (r: scaled.r + shift, g: scaled.g + shift, b: scaled.b + shift);
}

/// Saturation [s] scaled by [factor] along a curve that keeps 1 at 1: a
/// factor above 1 lifts dull colours most and vivid ones least.
double scaleSaturation(double s, double factor) =>
    factor >= 1 ? s * factor / (1 + (factor - 1) * s) : s * factor;

/// The master tone curve through [points], on each channel alike.
Rgb curve(Rgb c, List<(double, double)> points) =>
    (r: spline(points, c.r), g: spline(points, c.g), b: spline(points, c.b));

/// Monotone cubic interpolation (Fritsch–Carlson) through [points], which
/// are sorted by x and span 0 to 1, as a curves panel draws them.
double spline(List<(double, double)> points, double x) {
  final n = points.length;
  final xs = [for (final p in points) p.$1];
  final ys = [for (final p in points) p.$2];
  final slopes = [
    for (var i = 0; i < n - 1; i++) (ys[i + 1] - ys[i]) / (xs[i + 1] - xs[i]),
  ];
  final tangents = List<double>.filled(n, 0);
  tangents[0] = slopes.first;
  tangents[n - 1] = slopes.last;
  for (var i = 1; i < n - 1; i++) {
    // The weighted harmonic mean of the neighbouring slopes, as PCHIP takes
    // it, keeps the curve from overshooting between points.
    final before = xs[i] - xs[i - 1];
    final after = xs[i + 1] - xs[i];
    final w1 = 2 * after + before;
    final w2 = after + 2 * before;
    tangents[i] = slopes[i - 1] * slopes[i] <= 0
        ? 0
        : (w1 + w2) / (w1 / slopes[i - 1] + w2 / slopes[i]);
  }
  final t = x.clamp(0.0, 1.0);
  var i = 0;
  while (i < n - 2 && t > xs[i + 1]) {
    i++;
  }
  final h = xs[i + 1] - xs[i];
  final u = (t - xs[i]) / h;
  final u2 = u * u;
  final u3 = u2 * u;
  return (2 * u3 - 3 * u2 + 1) * ys[i] +
      (u3 - 2 * u2 + u) * h * tangents[i] +
      (-2 * u3 + 3 * u2) * ys[i + 1] +
      (u3 - u2) * h * tangents[i + 1];
}

/// The Rec. 709 luma of [c].
double luma(Rgb c) => 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b;

/// The overlay blend of [blend] onto [base].
double overlay(double base, double blend) =>
    base < 0.5 ? 2 * base * blend : 1 - 2 * (1 - base) * (1 - blend);

Rgb mixRgb(Rgb a, Rgb b, double t) => (
  r: a.r + (b.r - a.r) * t,
  g: a.g + (b.g - a.g) * t,
  b: a.b + (b.b - a.b) * t,
);

Rgb clamp(Rgb c) =>
    (r: c.r.clamp(0.0, 1.0), g: c.g.clamp(0.0, 1.0), b: c.b.clamp(0.0, 1.0));

/// The signed angle from [from] to [to], in degrees, from -180 to 180.
double hueDistance(double to, double from) => (to - from + 540) % 360 - 180;

/// Hue in degrees, saturation and value of [c].
(double, double, double) toHsv(Rgb c) {
  final max = math.max(c.r, math.max(c.g, c.b));
  final min = math.min(c.r, math.min(c.g, c.b));
  final delta = max - min;
  if (delta <= 0 || max <= 0) return (0, 0, max);
  final double hue;
  if (max == c.r) {
    hue = 60 * (((c.g - c.b) / delta) % 6);
  } else if (max == c.g) {
    hue = 60 * ((c.b - c.r) / delta + 2);
  } else {
    hue = 60 * ((c.r - c.g) / delta + 4);
  }
  return (hue, delta / max, max);
}

Rgb fromHsv(double h, double s, double v) {
  final chroma = v * s;
  final x = chroma * (1 - ((h / 60) % 2 - 1).abs());
  final m = v - chroma;
  final (r, g, b) = switch (h ~/ 60) {
    0 => (chroma, x, 0.0),
    1 => (x, chroma, 0.0),
    2 => (0.0, chroma, x),
    3 => (0.0, x, chroma),
    4 => (x, 0.0, chroma),
    _ => (chroma, 0.0, x),
  };
  return (r: r + m, g: g + m, b: b + m);
}

/// The table of [look], as 8-bit RGB rows of the PNG strip.
Uint8List tableOf(Rgb Function(Rgb) look) {
  const width = lutSize * lutSize;
  final pixels = Uint8List(width * lutSize * 3);
  for (var b = 0; b < lutSize; b++) {
    for (var g = 0; g < lutSize; g++) {
      for (var r = 0; r < lutSize; r++) {
        const last = lutSize - 1;
        final out = clamp(look((r: r / last, g: g / last, b: b / last)));
        final i = (g * width + b * lutSize + r) * 3;
        pixels[i] = (out.r * 255).round();
        pixels[i + 1] = (out.g * 255).round();
        pixels[i + 2] = (out.b * 255).round();
      }
    }
  }
  return pixels;
}

/// Reads a 33-point `.cube` file into the rows of the PNG strip.
Uint8List readCube(String source) {
  final values = <double>[];
  var size = 0;
  for (final raw in source.split('\n')) {
    final line = raw.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    if (line.startsWith('LUT_3D_SIZE')) {
      size = int.parse(line.split(RegExp(r'\s+')).last);
    } else if (RegExp(r'^[-+.\d]').hasMatch(line)) {
      values.addAll(line.split(RegExp(r'\s+')).take(3).map(double.parse));
    }
  }
  if (size != lutSize || values.length != 3 * lutSize * lutSize * lutSize) {
    throw FormatException('Expected a $lutSize-point 3D LUT, got size $size');
  }
  // A .cube lists red fastest, then green, then blue.
  const width = lutSize * lutSize;
  final pixels = Uint8List(width * lutSize * 3);
  for (var i = 0; i < lutSize * lutSize * lutSize; i++) {
    final r = i % lutSize;
    final g = i ~/ lutSize % lutSize;
    final b = i ~/ (lutSize * lutSize);
    final o = (g * width + b * lutSize + r) * 3;
    for (var channel = 0; channel < 3; channel++) {
      pixels[o + channel] = (values[i * 3 + channel].clamp(0.0, 1.0) * 255)
          .round();
    }
  }
  return pixels;
}

/// An 8-bit RGB PNG of the strip, without colour-space chunks, so every
/// decoder hands back exactly these values.
Uint8List encodePng(Uint8List pixels) {
  const width = lutSize * lutSize;
  const height = lutSize;
  const stride = width * 3;
  final raw = BytesBuilder();
  for (var y = 0; y < height; y++) {
    final row = Uint8List.sublistView(pixels, y * stride, (y + 1) * stride);
    final above = y == 0
        ? Uint8List(stride)
        : Uint8List.sublistView(pixels, (y - 1) * stride, y * stride);
    // The smooth tables compress to about a fifth with the filter that
    // leaves the smallest differences in each row.
    Uint8List? best;
    var bestCost = 0;
    for (var filter = 0; filter < 5; filter++) {
      final filtered = _filterRow(filter, row, above);
      var cost = 0;
      for (var i = 1; i < filtered.length; i++) {
        cost += filtered[i] < 128 ? filtered[i] : 256 - filtered[i];
      }
      if (best == null || cost < bestCost) {
        best = filtered;
        bestCost = cost;
      }
    }
    raw.add(best!);
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

/// [row] run through the PNG [filter] (0 none, 1 sub, 2 up, 3 average,
/// 4 Paeth), led by the filter's type byte.
Uint8List _filterRow(int filter, Uint8List row, Uint8List above) {
  final out = Uint8List(row.length + 1)..[0] = filter;
  for (var i = 0; i < row.length; i++) {
    final left = i >= 3 ? row[i - 3] : 0;
    final up = above[i];
    final upLeft = i >= 3 ? above[i - 3] : 0;
    final predicted = switch (filter) {
      0 => 0,
      1 => left,
      2 => up,
      3 => (left + up) >> 1,
      _ => _paeth(left, up, upLeft),
    };
    out[i + 1] = (row[i] - predicted) & 0xFF;
  }
  return out;
}

int _paeth(int a, int b, int c) {
  final p = a + b - c;
  final pa = (p - a).abs();
  final pb = (p - b).abs();
  final pc = (p - c).abs();
  if (pa <= pb && pa <= pc) return a;
  return pb <= pc ? b : c;
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
