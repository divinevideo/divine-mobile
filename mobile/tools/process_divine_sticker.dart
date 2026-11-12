// ABOUTME: Turns an unedited image-generator original into a shipped
// ABOUTME: DivineSticker WebP. Deterministic steps: alpha floor, crop to the
// ABOUTME: subject, padding, Lanczos down to 512 px, then cwebp.

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;

/// Alpha values below this are generator residue around the cutout and are
/// cleared to fully transparent.
const alphaFloor = 8;

/// Pixels with alpha above this define the subject's bounding box, so faint
/// residue near the canvas edge does not widen the crop.
const subjectAlpha = 32;

/// Transparent margin around the subject, as a fraction of its long side.
const paddingFraction = 0.02;

/// Smallest transparent margin, in source pixels.
const minPadding = 2;

/// Long edge of the shipped bitmap. Smaller subjects are never upscaled.
const maxLongEdge = 512;

/// Encoder settings shared by every sticker in `assets/divine_stickers/`.
const cwebpArguments = <String>[
  '-near_lossless',
  '60',
  '-z',
  '9',
  '-mt',
  '-metadata',
  'none',
];

/// Where [prepareSticker] cropped the source, in source pixels.
typedef StickerCrop = ({int left, int top, int width, int height, int padding});

/// Clears residue, crops to the subject with padding, and downsizes the
/// result so its long edge is at most [maxLongEdge].
///
/// Resampling uses Lanczos-3 on premultiplied alpha, so semi-transparent
/// edges keep their colour instead of darkening.
///
/// Throws a [StateError] when no pixel is more opaque than [subjectAlpha].
({img.Image image, StickerCrop crop}) prepareSticker(img.Image source) {
  final rgba = source.convert(format: img.Format.uint8, numChannels: 4);
  final width = rgba.width;
  final height = rgba.height;
  final pixels = Uint8List.fromList(
    rgba.getBytes(order: img.ChannelOrder.rgba),
  );

  for (var i = 0; i < pixels.length; i += 4) {
    if (pixels[i + 3] < alphaFloor) {
      pixels.fillRange(i, i + 4, 0);
    }
  }

  var left = width;
  var top = height;
  var right = -1;
  var bottom = -1;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      if (pixels[(y * width + x) * 4 + 3] > subjectAlpha) {
        left = math.min(left, x);
        right = math.max(right, x);
        top = math.min(top, y);
        bottom = math.max(bottom, y);
      }
    }
  }
  if (right < 0) {
    throw StateError('No pixel is more opaque than alpha $subjectAlpha.');
  }

  final longSide = math.max(right - left + 1, bottom - top + 1);
  final padding = math.max(minPadding, (longSide * paddingFraction).round());
  final crop = (
    left: left - padding,
    top: top - padding,
    width: right - left + 1 + 2 * padding,
    height: bottom - top + 1 + 2 * padding,
    padding: padding,
  );

  final premultiplied = Float64List(crop.width * crop.height * 4);
  for (var y = 0; y < crop.height; y++) {
    final sy = crop.top + y;
    if (sy < 0 || sy >= height) continue;
    for (var x = 0; x < crop.width; x++) {
      final sx = crop.left + x;
      if (sx < 0 || sx >= width) continue;
      final from = (sy * width + sx) * 4;
      final to = (y * crop.width + x) * 4;
      final alpha = pixels[from + 3];
      final coverage = alpha / 255;
      premultiplied[to] = pixels[from] * coverage;
      premultiplied[to + 1] = pixels[from + 1] * coverage;
      premultiplied[to + 2] = pixels[from + 2] * coverage;
      premultiplied[to + 3] = alpha.toDouble();
    }
  }

  final scale = math.min(
    1.0,
    maxLongEdge / math.max(crop.width, crop.height),
  );
  final targetWidth = math.max(1, (crop.width * scale).round());
  final targetHeight = math.max(1, (crop.height * scale).round());

  final resized = _resampleVertically(
    _resampleHorizontally(premultiplied, crop.width, crop.height, targetWidth),
    targetWidth,
    crop.height,
    targetHeight,
  );

  final output = img.Image(
    width: targetWidth,
    height: targetHeight,
    numChannels: 4,
  );
  for (var y = 0; y < targetHeight; y++) {
    for (var x = 0; x < targetWidth; x++) {
      final i = (y * targetWidth + x) * 4;
      final alpha = resized[i + 3].clamp(0, 255).toDouble();
      final alphaByte = alpha.round();
      if (alphaByte == 0) {
        output.setPixelRgba(x, y, 0, 0, 0, 0);
        continue;
      }
      int channel(double value) =>
          (value.clamp(0, alpha) * 255 / alpha).round().clamp(0, 255);
      output.setPixelRgba(
        x,
        y,
        channel(resized[i]),
        channel(resized[i + 1]),
        channel(resized[i + 2]),
        alphaByte,
      );
    }
  }
  return (image: output, crop: crop);
}

double _lanczos3(double x) {
  if (x == 0) return 1;
  if (x <= -3 || x >= 3) return 0;
  final px = math.pi * x;
  return 3 * math.sin(px) * math.sin(px / 3) / (px * px);
}

/// Normalised Lanczos-3 taps for each output position, widened by the
/// downscale factor so every source pixel contributes.
List<({int start, Float64List weights})> _taps(int inSize, int outSize) {
  final scale = inSize / outSize;
  final filterScale = math.max(scale, 1.0);
  final support = 3 * filterScale;
  return List.generate(outSize, (out) {
    final center = (out + 0.5) * scale;
    final start = math.max(0, (center - support + 0.5).floor());
    final end = math.min(inSize, (center + support + 0.5).floor());
    final weights = Float64List(end - start);
    var sum = 0.0;
    for (var i = start; i < end; i++) {
      final weight = _lanczos3((i - center + 0.5) / filterScale);
      weights[i - start] = weight;
      sum += weight;
    }
    for (var k = 0; k < weights.length; k++) {
      weights[k] /= sum;
    }
    return (start: start, weights: weights);
  });
}

Float64List _resampleHorizontally(
  Float64List source,
  int width,
  int height,
  int targetWidth,
) {
  if (targetWidth == width) return source;
  final taps = _taps(width, targetWidth);
  final result = Float64List(targetWidth * height * 4);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < targetWidth; x++) {
      final tap = taps[x];
      final to = (y * targetWidth + x) * 4;
      for (var k = 0; k < tap.weights.length; k++) {
        final from = (y * width + tap.start + k) * 4;
        final weight = tap.weights[k];
        for (var c = 0; c < 4; c++) {
          result[to + c] += source[from + c] * weight;
        }
      }
    }
  }
  return result;
}

Float64List _resampleVertically(
  Float64List source,
  int width,
  int height,
  int targetHeight,
) {
  if (targetHeight == height) return source;
  final taps = _taps(height, targetHeight);
  final result = Float64List(width * targetHeight * 4);
  for (var y = 0; y < targetHeight; y++) {
    final tap = taps[y];
    for (var x = 0; x < width; x++) {
      final to = (y * width + x) * 4;
      for (var k = 0; k < tap.weights.length; k++) {
        final from = ((tap.start + k) * width + x) * 4;
        final weight = tap.weights[k];
        for (var c = 0; c < 4; c++) {
          result[to + c] += source[from + c] * weight;
        }
      }
    }
  }
  return result;
}

/// Usage: `dart run tools/process_divine_sticker.dart <original.png> <out.webp>`
///
/// Prints one JSON line describing the run, for the provenance record.
Future<void> main(List<String> args) async {
  if (args.length != 2) {
    stderr.writeln(
      'Usage: dart run tools/process_divine_sticker.dart '
      '<original.png> <output.webp>',
    );
    exitCode = 64;
    return;
  }
  final originalFile = File(args[0]);
  final outputFile = File(args[1]);

  final originalBytes = await originalFile.readAsBytes();
  final decoded = img.decodePng(originalBytes);
  if (decoded == null) {
    stderr.writeln('Not a PNG: ${originalFile.path}');
    exitCode = 65;
    return;
  }

  final prepared = prepareSticker(decoded);
  final tempDir = await Directory.systemTemp.createTemp('divine_sticker_');
  try {
    final intermediate = File('${tempDir.path}/sticker.png');
    await intermediate.writeAsBytes(img.encodePng(prepared.image));
    final cwebp = await Process.run('cwebp', [
      ...cwebpArguments,
      intermediate.path,
      '-o',
      outputFile.path,
    ]);
    if (cwebp.exitCode != 0) {
      stderr.writeln('cwebp failed: ${cwebp.stderr}');
      exitCode = cwebp.exitCode;
      return;
    }
  } finally {
    await tempDir.delete(recursive: true);
  }

  final outputBytes = await outputFile.readAsBytes();
  stdout.writeln(
    jsonEncode({
      'original': originalFile.path,
      'originalSha256': sha256.convert(originalBytes).toString(),
      'originalSize': [decoded.width, decoded.height],
      'crop': {
        'left': prepared.crop.left,
        'top': prepared.crop.top,
        'width': prepared.crop.width,
        'height': prepared.crop.height,
        'padding': prepared.crop.padding,
      },
      'output': outputFile.path,
      'outputSize': [prepared.image.width, prepared.image.height],
      'outputBytes': outputBytes.length,
      'outputSha256': sha256.convert(outputBytes).toString(),
      'cwebp': cwebpArguments.join(' '),
    }),
  );
}
