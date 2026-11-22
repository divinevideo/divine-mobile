// ABOUTME: Regenerates the web icon files flutter_launcher_icons cannot model:
// ABOUTME: a plate-free favicon and padded maskable launcher icons.
//
// USAGE: dart run scripts/generate_web_favicon.dart
//
// Run this AFTER `dart run flutter_launcher_icons`. That tool's `web:` block
// has no separate favicon setting and writes the maskable icons with no safe
// zone padding, so this script has to run second to win.

// A command-line script run by hand; printing is how it reports what it wrote.
// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart';

const faviconOutput = 'web/favicon.png';

const appIconSource = 'assets/icon/app_icon.png';

const maskableOutputs = {
  192: 'web/icons/Icon-maskable-192.png',
  512: 'web/icons/Icon-maskable-512.png',
};

final brandGreen = ColorRgb8(0x27, 0xC5, 0x8B);

/// Divides evenly by 16, 32 and 48, so every tab size a browser asks for is a
/// clean downscale of the one file.
const faviconExtent = 96;

/// Breathing room around the isolated avatar after the launcher plate is
/// removed.
const faviconPaddingFraction = 0.06;

/// Matches the native adaptive icon foreground inset in
/// `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml`.
const maskableInsetFraction = 0.16;

void main() {
  final appIconSourceImage = _readSquarePng(appIconSource, 'app icon');
  if (appIconSourceImage == null) {
    exitCode = 1;
    return;
  }

  _writeFavicon(appIconSourceImage);
  _writeMaskableIcons(appIconSourceImage);
}

Image? _readSquarePng(String path, String label) {
  final source = decodePng(File(path).readAsBytesSync());
  if (source == null) {
    stderr.writeln('Could not decode $path');
    return null;
  }

  // Squaring a non-square source would silently squash the mark, and the
  // 8x8 signature the icon guard compares on normalises aspect away.
  if (source.width != source.height) {
    stderr.writeln(
      '$path is ${source.width}x${source.height}; the $label needs a square '
      'source',
    );
    return null;
  }

  return source;
}

void _writeFavicon(Image source) {
  final isolatedAvatar = _isolateAvatar(source);

  // Matches flutter_launcher_icons' own downscale filter so the favicon and
  // the launcher icons resample identically.
  final favicon = copyResize(
    isolatedAvatar,
    width: faviconExtent,
    height: faviconExtent,
    interpolation: Interpolation.average,
  );

  File(faviconOutput).writeAsBytesSync(encodePng(favicon));
  print(
    'Wrote $faviconOutput (${faviconExtent}x$faviconExtent) '
    'from the plate-free foreground of $appIconSource',
  );
}

/// Removes the green launcher plate while preserving the green play button.
///
/// Both regions use the same palette, so a colour key alone would punch a hole
/// through the mark. The play button is the green component at the image
/// centre; every other green-dominant pixel belongs to the plate or its glow.
/// Keeping the favicon derived from [appIconSource] prevents an older isolated
/// avatar export from drifting away from the installed app icon.
Image _isolateAvatar(Image source) {
  final avatar = source.convert(format: Format.uint8, numChannels: 4);
  final protectedPlayPixels = _connectedGreenRegion(
    avatar,
    avatar.width ~/ 2,
    avatar.height ~/ 2,
  );
  final centerIndex = (avatar.height ~/ 2) * avatar.width + (avatar.width ~/ 2);
  if (protectedPlayPixels[centerIndex] == 0) {
    throw StateError(
      '$appIconSource has no green play-button region at its centre',
    );
  }

  for (final pixel in avatar) {
    final index = pixel.y * avatar.width + pixel.x;
    if (_isGreenDominant(pixel) && protectedPlayPixels[index] == 0) {
      pixel.setRgba(0, 0, 0, 0);
    }
  }

  return _cropAndPad(avatar);
}

Uint8List _connectedGreenRegion(Image image, int startX, int startY) {
  final pixelCount = image.width * image.height;
  final region = Uint8List(pixelCount);
  if (!_isGreenDominant(image.getPixel(startX, startY))) return region;

  final queue = Uint32List(pixelCount);
  var head = 0;
  var tail = 0;

  void add(int x, int y) {
    if (x < 0 || x >= image.width || y < 0 || y >= image.height) return;
    final index = y * image.width + x;
    if (region[index] != 0 || !_isGreenDominant(image.getPixel(x, y))) return;
    region[index] = 1;
    queue[tail++] = index;
  }

  add(startX, startY);
  while (head < tail) {
    final index = queue[head++];
    final x = index % image.width;
    final y = index ~/ image.width;
    add(x - 1, y);
    add(x + 1, y);
    add(x, y - 1);
    add(x, y + 1);
  }
  return region;
}

bool _isGreenDominant(Pixel pixel) {
  final green = pixel.g.toDouble();
  return pixel.a > 0 &&
      green - pixel.r.toDouble() >= 8 &&
      green - pixel.b.toDouble() >= 4;
}

Image _cropAndPad(Image image) {
  var minX = image.width;
  var minY = image.height;
  var maxX = -1;
  var maxY = -1;

  for (final pixel in image) {
    if (pixel.a == 0) continue;
    minX = math.min(minX, pixel.x);
    minY = math.min(minY, pixel.y);
    maxX = math.max(maxX, pixel.x);
    maxY = math.max(maxY, pixel.y);
  }
  if (maxX < minX || maxY < minY) {
    throw StateError('$appIconSource has no foreground after plate removal');
  }

  final content = copyCrop(
    image,
    x: minX,
    y: minY,
    width: maxX - minX + 1,
    height: maxY - minY + 1,
  );
  final contentExtent = math.max(content.width, content.height);
  final padding = (contentExtent * faviconPaddingFraction).round();
  final canvasExtent = contentExtent + padding * 2;
  final canvas = Image(
    width: canvasExtent,
    height: canvasExtent,
    numChannels: 4,
  );
  canvas.clear(ColorRgba8(0, 0, 0, 0));
  compositeImage(
    canvas,
    content,
    dstX: (canvasExtent - content.width) ~/ 2,
    dstY: (canvasExtent - content.height) ~/ 2,
  );
  return canvas;
}

void _writeMaskableIcons(Image source) {
  for (final entry in maskableOutputs.entries) {
    final extent = entry.key;
    final foregroundExtent = (extent * (1 - maskableInsetFraction * 2)).round();
    final foreground = copyResize(
      source,
      width: foregroundExtent,
      height: foregroundExtent,
      interpolation: Interpolation.average,
    );
    final icon = Image(width: extent, height: extent);
    fill(icon, color: brandGreen);
    compositeImage(
      icon,
      foreground,
      dstX: ((extent - foregroundExtent) / 2).round(),
      dstY: ((extent - foregroundExtent) / 2).round(),
    );

    File(entry.value).writeAsBytesSync(encodePng(icon));
    print(
      'Wrote ${entry.value} (${extent}x$extent) from $appIconSource '
      'with ${(maskableInsetFraction * 100).round()}% inset',
    );
  }
}
