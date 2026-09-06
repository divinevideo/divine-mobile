// ABOUTME: Unit tests for WatermarkImageGenerator — guards the refreshed Divine
// ABOUTME: wordmark asset and its bottom-right composition into export overlays.

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/watermark_image_generator.dart';

import '../helpers/flutter_assets_channel.dart';

const _wordmarkAssetKey = 'assets/icon/divine_wordmark.png';

/// Mocks `flutter/assets` so [rootBundle] serves [bytes] for the wordmark
/// path, restoring the default handler via [restoreFlutterAssetsDefaultHandler]
/// so the override stays safe under the merged VGV isolate.
void _mockWordmarkAsset(Uint8List bytes) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler('flutter/assets', (ByteData? message) async {
        if (message == null) return null;
        final assetName = utf8.decode(message.buffer.asUint8List());
        if (assetName == _wordmarkAssetKey) {
          return ByteData.sublistView(bytes);
        }
        return null;
      });
}

// Restores flutter_test's default `flutter/assets` handler. Nulling it would
// strand asset loading for every later suite in the shared VGV isolate.
void _clearAssetMock() {
  restoreFlutterAssetsDefaultHandler();
}

/// Installs an asset handler that returns `null` for every key, so
/// [rootBundle] cannot resolve the wordmark and `load` throws. (Merely
/// clearing the mock lets `flutter test` fall back to the real bundled asset.)
void _mockAssetMissing() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler(
        'flutter/assets',
        (ByteData? message) async => null,
      );
}

Future<({int width, int height, Uint8List rgba})> _decodeRgba(
  Uint8List png,
) async {
  final codec = await ui.instantiateImageCodec(png);
  final frame = await codec.getNextFrame();
  final image = frame.image;
  final data = await image.toByteData();
  final result = (
    width: image.width,
    height: image.height,
    rgba: data!.buffer.asUint8List(),
  );
  image.dispose();
  codec.dispose();
  return result;
}

int _alphaAt(Uint8List rgba, int width, int x, int y) =>
    rgba[(y * width + x) * 4 + 3];

({int r, int g, int b, int a}) _rgbaAt(
  Uint8List rgba,
  int width,
  int x,
  int y,
) {
  final offset = (y * width + x) * 4;
  return (
    r: rgba[offset],
    g: rgba[offset + 1],
    b: rgba[offset + 2],
    a: rgba[offset + 3],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(WatermarkImageGenerator, () {
    late Uint8List wordmarkBytes;

    setUpAll(() async {
      // flutter test runs with CWD = package root (mobile/).
      wordmarkBytes = await File(_wordmarkAssetKey).readAsBytes();
    });

    setUp(() {
      rootBundle.clear();
      _clearAssetMock();
      _mockWordmarkAsset(wordmarkBytes);
    });

    tearDown(() {
      rootBundle.clear();
      _clearAssetMock();
    });

    test('disposes every image it rasterizes', () async {
      final live = <ui.Image>{};
      final previousOnCreate = ui.Image.onCreate;
      final previousOnDispose = ui.Image.onDispose;
      ui.Image.onCreate = (image) {
        previousOnCreate?.call(image);
        live.add(image);
      };
      ui.Image.onDispose = (image) {
        previousOnDispose?.call(image);
        live.remove(image);
      };
      addTearDown(() {
        ui.Image.onCreate = previousOnCreate;
        ui.Image.onDispose = previousOnDispose;
      });

      await WatermarkImageGenerator.generateWatermark(
        videoWidth: 64,
        videoHeight: 64,
        watermarkText: '@divine.video',
      );

      // The wordmark decode and the full-frame raster are both handles this
      // call owns; leaving either open keeps its native pixels alive until the
      // garbage collector finalizes the wrapper.
      expect(live, isEmpty);
    });

    test('bundled wordmark asset matches the refreshed logo mark', () async {
      final decoded = await _decodeRgba(wordmarkBytes);
      const expectedLogoAspectRatio = 125 / 33;

      // `assets/icon/logo.svg` is the source of truth for this raster
      // derivative. This catches accidental swaps back to the retired cursive
      // assets, whose aspect ratios differ from the geometric heart-V mark.
      expect(
        decoded.width / decoded.height,
        closeTo(expectedLogoAspectRatio, expectedLogoAspectRatio * 0.02),
      );

      // Only fully-opaque pixels: rawRgba bytes are premultiplied, so
      // anti-aliased edge pixels carry attenuated colour and would skew the
      // average. Interior stroke pixels are the mark's true colour.
      var solid = 0;
      var sumR = 0;
      var sumG = 0;
      var sumB = 0;
      for (var i = 0; i < decoded.rgba.length; i += 4) {
        if (decoded.rgba[i + 3] == 255) {
          solid++;
          sumR += decoded.rgba[i];
          sumG += decoded.rgba[i + 1];
          sumB += decoded.rgba[i + 2];
        }
      }

      expect(
        solid,
        greaterThan(500),
        reason: 'mark should have opaque body pixels',
      );
      // Retired mark averaged (245,246,234) — a warm cream (blue ≈ 234).
      // The refreshed mark is pure white; every channel average is ~255.
      expect(sumR / solid, greaterThan(250));
      expect(sumG / solid, greaterThan(250));
      expect(
        sumB / solid,
        greaterThan(250),
        reason: 'blue channel distinguishes white (255) from cream (234)',
      );
    });

    test(
      'generates a full-frame overlay with the mark drawn bottom-right only',
      () async {
        const width = 400;
        const height = 700;

        final png = await WatermarkImageGenerator.generateWatermark(
          videoWidth: width,
          videoHeight: height,
          watermarkText: '@divine.video',
        );
        expect(png, isNotEmpty);

        final decoded = await _decodeRgba(png);
        expect(decoded.width, width);
        expect(decoded.height, height);

        // The mark + identity block sits in the bottom-right corner, so the
        // top half of the frame must be fully transparent.
        for (final y in [10, 80, height ~/ 3, height ~/ 2 - 20]) {
          for (final x in [10, width ~/ 2, width - 10]) {
            expect(
              _alphaAt(decoded.rgba, decoded.width, x, y),
              0,
              reason: 'expected transparent overlay at ($x,$y)',
            );
          }
        }

        // Derive the aspect ratio from the actual bundled asset so this stays
        // correct across wordmark refreshes — the generator sizes the mark from
        // the asset's own dimensions, not a fixed ratio.
        final markDims = await _decodeRgba(wordmarkBytes);
        final wordmarkAspectRatio = markDims.width / markDims.height;
        const wordmarkDrawWidth = width * 0.15;
        final wordmarkDrawHeight = wordmarkDrawWidth / wordmarkAspectRatio;
        const fontSize = wordmarkDrawWidth * 0.14;
        const gap = fontSize * 0.3;
        final paragraph =
            ui.ParagraphBuilder(
                ui.ParagraphStyle(textAlign: ui.TextAlign.right, maxLines: 1),
              )
              ..pushStyle(
                ui.TextStyle(
                  color: const ui.Color.fromRGBO(255, 255, 255, 0.6),
                  fontSize: fontSize,
                  fontWeight: ui.FontWeight.w600,
                ),
              )
              ..addText('@divine.video')
              ..pop();
        final textParagraph = paragraph.build()
          ..layout(const ui.ParagraphConstraints(width: width - 32));
        final blockTop =
            height - 16 - wordmarkDrawHeight - gap - textParagraph.height;
        const wordmarkLeft = width - 16 - wordmarkDrawWidth;

        // Sample only the computed wordmark band, not the identity text below.
        // Fully opaque source pixels render as premultiplied white at 60% alpha,
        // so the RGB channels should stay close to the output alpha.
        var whiteMarkPixels = 0;
        for (
          var y = blockTop.ceil();
          y < (blockTop + wordmarkDrawHeight).floor();
          y++
        ) {
          for (var x = wordmarkLeft.ceil(); x < width - 16; x++) {
            final pixel = _rgbaAt(decoded.rgba, decoded.width, x, y);
            if (pixel.a > 120 &&
                pixel.r >= pixel.a - 2 &&
                pixel.g >= pixel.a - 2 &&
                pixel.b >= pixel.a - 2) {
              whiteMarkPixels++;
            }
          }
        }
        expect(
          whiteMarkPixels,
          greaterThan(20),
          reason: 'refreshed white wordmark should render in the bottom-right',
        );
      },
    );

    test(
      'throws WatermarkGenerationException when the asset cannot load',
      () async {
        rootBundle.clear();
        _mockAssetMissing();

        await expectLater(
          WatermarkImageGenerator.generateWatermark(
            videoWidth: 400,
            videoHeight: 700,
            watermarkText: '@divine.video',
          ),
          throwsA(isA<WatermarkGenerationException>()),
        );
      },
    );
  });
}
