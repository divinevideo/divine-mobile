// ABOUTME: Guards the native splash — pins the Android and iOS launch images to
// ABOUTME: the current Divine wordmark, Brand Green, and fixed launch sizing.

import 'dart:convert';
import 'dart:io';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/brand_silhouette.dart';

/// Vector source of the Divine wordmark. The launch images are raster cuts of
/// it, so a brand refresh has to move all of them together.
const _wordmarkAssetKey = 'assets/icon/logo.svg';

/// Retired cursive wordmark from the pre-refresh brand pack. Present only to
/// prove the silhouette check can tell a wrong wordmark apart from the right
/// one — without it, [_minWordmarkOverlap] could be meaninglessly low.
const _retiredWordmarkAssetKey =
    'test/fixtures/brand/retired_white_cropped.png';

/// Overlap a launch image must reach against [_wordmarkAssetKey].
///
/// Measured on this set: Android `0.980`, iOS `0.888`–`0.971` (the 1x cut is
/// only 196px wide, so it resamples the least faithfully). Wrong artwork lands
/// far below — retired cursive wordmark `0.235`, its full brand-pack export
/// `0.256`, the standalone mark `0.243`, the 3D app icon `0.126`.
const _minWordmarkOverlap = 0.80;

/// Canvas the Android launch image occupies when the legacy layer-list draws it.
const _androidCanvasDp = 240;

/// Full-resolution source used by both the legacy window background and the
/// Android 12+ system splash icon.
const _androidSourcePx = 960;

/// Point size `LaunchScreen.storyboard` pins the launch image view to.
const _iosWidthPt = 196;
const _iosHeightPt = 70;

const _iosScales = <String, int>{
  'LaunchImage.png': 1,
  'LaunchImage@2x.png': 2,
  'LaunchImage@3x.png': 3,
};

// Paths below are relative because `flutter test` runs with CWD = mobile/.
const _resDir = 'android/app/src/main/res';
const _imagesetDir = 'ios/Runner/Assets.xcassets/LaunchImage.imageset';
const _storyboardPath = 'ios/Runner/Base.lproj/LaunchScreen.storyboard';
const _androidLaunchImage = '$_resDir/drawable-nodpi/launch_image.png';

Future<DecodedImage> _decodeFile(String path) async =>
    decodeRgba(await File(path).readAsBytes());

/// Colours of every fully-opaque pixel. Raw bytes are premultiplied, so
/// anti-aliased edges carry attenuated colour and are skipped.
Set<int> _solidColors(DecodedImage image) {
  final colors = <int>{};
  for (var i = 0; i < image.rgba.length; i += 4) {
    if (image.rgba[i + 3] != 255) continue;
    colors.add(
      (0xFF << 24) |
          (image.rgba[i] << 16) |
          (image.rgba[i + 1] << 8) |
          image.rgba[i + 2],
    );
  }
  return colors;
}

int _solidPixelCount(DecodedImage image) {
  var count = 0;
  for (var i = 0; i < image.rgba.length; i += 4) {
    if (image.rgba[i + 3] == 255) count++;
  }
  return count;
}

/// Squared distance from the canvas centre to the furthest visible pixel.
double _artworkRadiusSquared(DecodedImage image) {
  final centerX = (image.width - 1) / 2;
  final centerY = (image.height - 1) / 2;
  var radiusSquared = 0.0;
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      if (image.rgba[(y * image.width + x) * 4 + 3] <= 128) continue;
      final dx = x - centerX;
      final dy = y - centerY;
      final distanceSquared = dx * dx + dy * dy;
      if (distanceSquared > radiusSquared) radiusSquared = distanceSquared;
    }
  }
  return radiusSquared;
}

String _argbHex(int color) =>
    '#${color.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<bool> wordmark;

  setUpAll(() async {
    final svg = await File(_wordmarkAssetKey).readAsString();
    wordmark = normalizedSilhouette(await rasterizeSvg(svg));
  });

  group('Android launch image', () {
    test('ships one no-density source and no bucket-specific copies', () {
      final shipped =
          Directory(_resDir)
              .listSync(recursive: true)
              .whereType<File>()
              .map((file) => file.path)
              .where((path) => path.endsWith('/launch_image.png'))
              .toList()
            ..sort();
      expect(
        shipped,
        equals([_androidLaunchImage]),
        reason:
            'the layer-list bounds the source in dp, so density buckets would '
            'only reintroduce per-device resolution differences',
      );
    });

    test('keeps the full-resolution source image', () async {
      final image = await _decodeFile(_androidLaunchImage);
      expect(
        [image.width, image.height],
        equals([_androidSourcePx, _androidSourcePx]),
        reason:
            'the legacy layer-list scales this source into a fixed '
            '${_androidCanvasDp}dp box; keeping the 4x source preserves '
            'resolution headroom on lower-density devices',
      );
    });

    test('paints the mark in Brand Green', () async {
      final image = await _decodeFile(_androidLaunchImage);
      expect(
        _solidPixelCount(image),
        greaterThan(1000),
        reason: 'the source should have a solid mark body',
      );
      expect(
        _solidColors(image),
        equals({VineTheme.vineGreen.toARGB32()}),
        reason: 'the source must be flat Brand Green, not a retired green',
      );
    });

    test('keeps the mark inside the Android 12+ splash mask', () async {
      final image = await _decodeFile(_androidLaunchImage);
      final radiusLimit = image.width / 3;
      expect(
        _artworkRadiusSquared(image),
        lessThanOrEqualTo(radiusLimit * radiusLimit),
        reason:
            'values-v31 sets windowSplashScreenAnimatedIcon, and Android clips '
            'it to a circle two thirds of the canvas wide; artwork outside '
            'that circle is cropped off the system splash',
      );
    });

    test('draws the current Divine wordmark', () async {
      final image = await _decodeFile(_androidLaunchImage);
      expect(
        silhouetteOverlap(wordmark, normalizedSilhouette(image)),
        greaterThanOrEqualTo(_minWordmarkOverlap),
        reason: 'Android launch image no longer matches $_wordmarkAssetKey',
      );
    });

    test('fills the splash with the app surface colour', () {
      final expected = _argbHex(VineTheme.surfaceBackground.toARGB32());
      for (final variant in ['values', 'values-night']) {
        final colors = File('$_resDir/$variant/colors.xml').readAsStringSync();
        expect(
          RegExp(
            '<color name="splash_background">([^<]+)</color>',
          ).firstMatch(colors)?.group(1)?.toUpperCase(),
          equals(expected),
          reason:
              '$variant/colors.xml must match VineTheme.surfaceBackground or '
              'the splash flashes a different colour into the first frame',
        );
      }
    });

    test('bounds the legacy splash path to a fixed dp launch image', () {
      final layers = File(
        '$_resDir/drawable/launch_background.xml',
      ).readAsStringSync();
      expect(layers, contains('@color/splash_background'));
      expect(layers, contains('@drawable/launch_image'));
      expect(
        layers,
        contains('android:width="${_androidCanvasDp}dp"'),
        reason:
            'the layer-list must size the launch image in dp instead of using '
            'the bitmap intrinsic size',
      );
      expect(
        layers,
        contains('android:height="${_androidCanvasDp}dp"'),
        reason:
            'the layer-list must keep the bounded launch image square so the '
            'wordmark is not stretched',
      );
      expect(
        layers,
        contains('android:gravity="fill"'),
        reason:
            'the bitmap should fill the bounded square; the source itself is '
            'square, so this preserves the wordmark aspect ratio',
      );

      String item(String name, String value) =>
          '<item name="android:$name">$value</item>';
      for (final variant in ['values-v31', 'values-night-v31']) {
        final styles = File('$_resDir/$variant/styles.xml').readAsStringSync();
        expect(
          styles,
          contains(
            item('windowSplashScreenAnimatedIcon', '@drawable/launch_image'),
          ),
        );
        expect(
          styles,
          contains(
            item('windowSplashScreenBackground', '@color/splash_background'),
          ),
        );
      }
    });
  });

  group('iOS launch image', () {
    test(
      'sizes every scale from one ${_iosWidthPt}x${_iosHeightPt}pt box',
      () async {
        final contents = jsonDecode(
          File('$_imagesetDir/Contents.json').readAsStringSync(),
        ) as Map<String, dynamic>;
        final declared = {
          for (final image in contents['images']! as List<dynamic>)
            (image as Map<String, dynamic>)['filename'] as String:
                image['scale'] as String,
        };
        expect(
          declared,
          equals(_iosScales.map((name, scale) => MapEntry(name, '${scale}x'))),
        );

        for (final entry in _iosScales.entries) {
          final image = await _decodeFile('$_imagesetDir/${entry.key}');
          expect(
            [image.width, image.height],
            equals([_iosWidthPt * entry.value, _iosHeightPt * entry.value]),
            reason:
                '${entry.key} must fill the storyboard image view exactly at '
                '${entry.value}x, or it renders soft on that device class',
          );
        }
      },
    );

    test('paints the mark in Brand Green', () async {
      for (final name in _iosScales.keys) {
        final image = await _decodeFile('$_imagesetDir/$name');
        expect(_solidPixelCount(image), greaterThan(1000));
        expect(
          _solidColors(image),
          equals({VineTheme.vineGreen.toARGB32()}),
          reason: '$name must be flat Brand Green, not a retired green',
        );
      }
    });

    test('draws the current Divine wordmark', () async {
      for (final name in _iosScales.keys) {
        final image = await _decodeFile('$_imagesetDir/$name');
        expect(
          silhouetteOverlap(wordmark, normalizedSilhouette(image)),
          greaterThanOrEqualTo(_minWordmarkOverlap),
          reason: '$name no longer matches $_wordmarkAssetKey',
        );
      }
    });

    test('backs the mark with the app surface colour', () {
      final storyboard = File(_storyboardPath).readAsStringSync();
      final match = RegExp(
        r'<color key="backgroundColor" red="([\d.]+)" green="([\d.]+)" '
        r'blue="([\d.]+)"',
      ).firstMatch(storyboard);
      expect(match, isNotNull, reason: 'storyboard lost its background colour');
      final channels = [
        for (var group = 1; group <= 3; group++)
          (double.parse(match!.group(group)!) * 255).round(),
      ];
      final surface = VineTheme.surfaceBackground.toARGB32();
      expect(
        channels,
        equals([(surface >> 16) & 0xFF, (surface >> 8) & 0xFF, surface & 0xFF]),
        reason:
            'the storyboard must match VineTheme.surfaceBackground so the '
            'splash does not flash a different colour into the first frame',
      );
    });

    test('declares the shipped image size', () {
      final storyboard = File(_storyboardPath).readAsStringSync();
      expect(
        RegExp(
          r'constant="(\d+)" id="imageWidth"',
        ).firstMatch(storyboard)?.group(1),
        equals('$_iosWidthPt'),
      );
      expect(
        RegExp(
          r'constant="(\d+)" id="imageHeight"',
        ).firstMatch(storyboard)?.group(1),
        equals('$_iosHeightPt'),
      );
    });

    test('is the storyboard the launch surface points at', () {
      final plist = File('ios/Runner/Info.plist').readAsStringSync();
      expect(
        RegExp(
          r'<key>\s*UILaunchStoryboardName\s*</key>\s*'
          r'<string>\s*LaunchScreen\s*</string>',
        ).hasMatch(plist),
        isTrue,
      );
    });
  });

  test('tells the retired cursive wordmark apart', () async {
    final retired = await _decodeFile(_retiredWordmarkAssetKey);
    expect(
      silhouetteOverlap(wordmark, normalizedSilhouette(retired)),
      lessThan(_minWordmarkOverlap),
      reason:
          'the launch-image checks above are only meaningful while a wrong '
          'wordmark scores below the threshold',
    );
  });
}
