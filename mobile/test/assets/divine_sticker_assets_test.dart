// ABOUTME: Guards the DivineSticker artwork bundled with the app: every
// ABOUTME: variant has a file, every file is a transparent PNG within 512 px,
// ABOUTME: and the directory holds nothing the catalog does not name.

import 'dart:io';
import 'dart:typed_data';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';

const _directory = 'assets/divine_stickers';
const _maxLongEdge = 512;
const _pngSignature = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];

// PNG colour types that carry an alpha channel: grey+alpha and RGBA.
const _alphaColorTypes = {4, 6};

({int width, int height, int colorType}) _readPngHeader(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  return (
    width: data.getUint32(16),
    height: data.getUint32(20),
    colorType: data.getUint8(25),
  );
}

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
          .toSet();
      final expected = figmaBacked
          .map((sticker) => '${sticker.fileName}.png')
          .toSet();

      expect(onDisk, equals(expected));
    });

    test('every artwork file is a PNG with an alpha channel', () {
      for (final sticker in figmaBacked) {
        final bytes = File(sticker.assetPath).readAsBytesSync();

        expect(
          bytes.sublist(0, 8),
          equals(_pngSignature),
          reason: '${sticker.assetPath} is not a PNG.',
        );
        expect(
          _alphaColorTypes,
          contains(_readPngHeader(bytes).colorType),
          reason: '${sticker.assetPath} has no alpha channel.',
        );
      }
    });

    test('no artwork file exceeds $_maxLongEdge px on its long edge', () {
      for (final sticker in figmaBacked) {
        final header = _readPngHeader(
          File(sticker.assetPath).readAsBytesSync(),
        );
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
        (DivineStickerName.hangLoose, DivineStickerName.ceramicHands),
        (DivineStickerName.alert, DivineStickerName.hazardSign),
        (DivineStickerName.blocked, DivineStickerName.stopSign),
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
