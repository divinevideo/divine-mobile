// ABOUTME: Guards the DivineSticker artwork bundled with the app: every
// ABOUTME: variant has a file, every file is a lossless WebP within 512 px that
// ABOUTME: keeps its alpha, and the directory holds nothing the catalog does not name.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';

const _directory = 'assets/divine_stickers';
const _maxLongEdge = 512;

/// Stickers whose artwork has no transparent pixel at all, so the encoder
/// stores them without an alpha channel. The Polaroid is a rectangular print.
/// Anything else arriving here has been flattened onto a background.
const Set<DivineStickerName> _opaqueStickers = {DivineStickerName.polaroid};

/// What the RIFF container of a WebP file declares about its image.
typedef _WebpHeader = ({
  int width,
  int height,
  bool lossless,
  bool alpha,
  List<String> chunks,
});

/// Reads the container at [path] without decoding pixels.
///
/// A simple lossless file is one `VP8L` chunk, whose 5-byte header carries
/// the size and an alpha flag. A simple lossy file is one `VP8 ` chunk, whose
/// frame header carries the size, and has no alpha. An extended file starts
/// with `VP8X`, which carries the canvas size and the flags, followed by the
/// image chunks; the image is lossless only when it is a `VP8L` chunk rather
/// than a lossy `VP8 ` one.
_WebpHeader _readWebpHeader(String path) {
  final bytes = File(path).readAsBytesSync();
  final data = ByteData.sublistView(bytes);
  // latin1, not ascii: a renamed PNG must fail the expect, not throw first.
  expect(
    latin1.decode(bytes.sublist(0, 4)),
    equals('RIFF'),
    reason: '$path is not a WebP file.',
  );
  expect(
    latin1.decode(bytes.sublist(8, 12)),
    equals('WEBP'),
    reason: '$path is not a WebP file.',
  );

  final chunks = <String, int>{};
  var offset = 12;
  while (offset + 8 <= bytes.length) {
    final fourCc = latin1.decode(bytes.sublist(offset, offset + 4));
    final size = data.getUint32(offset + 4, Endian.little);
    chunks.putIfAbsent(fourCc, () => offset + 8);
    offset += 8 + size + (size.isOdd ? 1 : 0);
  }

  final lossless = chunks.containsKey('VP8L') && !chunks.containsKey('VP8 ');
  if (chunks.containsKey('VP8X')) {
    final payload = chunks['VP8X']!;
    return (
      width: _uint24(data, payload + 4) + 1,
      height: _uint24(data, payload + 7) + 1,
      lossless: lossless,
      alpha: data.getUint8(payload) & 0x10 != 0,
      chunks: chunks.keys.toList(),
    );
  }

  if (chunks.containsKey('VP8L')) {
    final payload = chunks['VP8L']!;
    expect(
      data.getUint8(payload),
      equals(0x2f),
      reason: '$path has no VP8L signature.',
    );
    final bits = data.getUint32(payload + 1, Endian.little);
    return (
      width: (bits & 0x3fff) + 1,
      height: ((bits >> 14) & 0x3fff) + 1,
      lossless: lossless,
      alpha: (bits >> 28) & 0x1 != 0,
      chunks: chunks.keys.toList(),
    );
  }

  final payload = chunks['VP8 '];
  if (payload == null) {
    fail('$path carries no image chunk: ${chunks.keys.toList()}.');
  }
  return (
    width: data.getUint16(payload + 6, Endian.little) & 0x3fff,
    height: data.getUint16(payload + 8, Endian.little) & 0x3fff,
    lossless: false,
    alpha: false,
    chunks: chunks.keys.toList(),
  );
}

int _uint24(ByteData data, int offset) =>
    data.getUint8(offset) |
    (data.getUint8(offset + 1) << 8) |
    (data.getUint8(offset + 2) << 16);

void main() {
  // Tests run with the package root as the working directory.
  final figmaBacked = DivineStickerName.values
      .where((sticker) => !sticker.isLegacySvg)
      .toList();

  group(DivineStickerName, () {
    test('every variant points at a bundled asset', () {
      for (final sticker in DivineStickerName.values) {
        expect(
          File(sticker.assetPath).existsSync(),
          isTrue,
          reason: '${sticker.name} points at ${sticker.assetPath}.',
        );
      }
    });

    test('the artwork directory holds exactly the Figma-backed variants', () {
      final onDisk = Directory(_directory)
          .listSync()
          .whereType<File>()
          .map((file) => file.uri.pathSegments.last)
          // Finder writes a gitignored .DS_Store into folders it opens.
          .where((name) => !name.startsWith('.'))
          .toSet();
      final expected = figmaBacked
          .map((sticker) => '${sticker.fileName}.webp')
          .toSet();

      expect(onDisk, equals(expected));
    });

    test('every artwork file is a lossless WebP', () {
      for (final sticker in figmaBacked) {
        final header = _readWebpHeader(sticker.assetPath);

        expect(
          header.lossless,
          isTrue,
          reason: '${sticker.assetPath} carries ${header.chunks}.',
        );
      }
    });

    test('every artwork file keeps its transparency', () {
      final withoutAlpha = figmaBacked
          .where((sticker) => !_readWebpHeader(sticker.assetPath).alpha)
          .toSet();

      expect(withoutAlpha, equals(_opaqueStickers));
    });

    test('no artwork file exceeds $_maxLongEdge px on its long edge', () {
      for (final sticker in figmaBacked) {
        final header = _readWebpHeader(sticker.assetPath);
        final longEdge = header.width > header.height
            ? header.width
            : header.height;

        expect(
          longEdge,
          inInclusiveRange(1, _maxLongEdge),
          reason: '${sticker.assetPath} is ${header.width}x${header.height}.',
        );
      }
    });

    group('stickers that must stay separate do not share artwork', () {
      const pairs = [
        (DivineStickerName.alert, DivineStickerName.policeSiren),
        (DivineStickerName.alert, DivineStickerName.hazardSign),
        (DivineStickerName.blocked, DivineStickerName.raisedHand),
        (DivineStickerName.blocked, DivineStickerName.stopSign),
        (DivineStickerName.hangLoose, DivineStickerName.ceramicHands),
        (DivineStickerName.unicornFloat, DivineStickerName.inflatableFlamingo),
        (DivineStickerName.unicornFloat, DivineStickerName.floatingLilo),
      ];

      for (final (first, second) in pairs) {
        test('${first.name} and ${second.name}', () {
          expect(
            File(first.assetPath).readAsBytesSync(),
            isNot(equals(File(second.assetPath).readAsBytesSync())),
          );
        });
      }
    });
  });
}
