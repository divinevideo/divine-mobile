import 'dart:convert';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

// 1×1 transparent PNG bytes (from Flutter's test suite).
final _transparentPng = Uint8List.fromList(const <int>[
  0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, //
  0x00, 0x00, 0x00, 0x0d, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1f, 0x15, 0xc4,
  0x89, 0x00, 0x00, 0x00, 0x0a, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9c, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0d, 0x0a, 0x2d, 0xb4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4e, 0x44, 0xae,
  0x42, 0x60, 0x82,
]);

const _emptySvg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1 1"/>';

// The real artwork ships with the app, not with this package, so every
// sticker path resolves to a stand-in of the right format.
class _TestAssetBundle extends CachingAssetBundle {
  _TestAssetBundle() {
    final manifest = <String, List<Map<String, Object>>>{
      for (final sticker in DivineStickerName.values)
        sticker.assetPath: [
          <String, Object>{'asset': sticker.assetPath},
        ],
    };
    _manifest = const StandardMessageCodec().encodeMessage(manifest)!;
  }

  late final ByteData _manifest;
  final ByteData _png = ByteData.sublistView(_transparentPng);
  final ByteData _svg = ByteData.sublistView(utf8.encode(_emptySvg));

  @override
  Future<ByteData> load(String key) {
    if (key == 'AssetManifest.bin') {
      return SynchronousFuture<ByteData>(_manifest);
    }
    return SynchronousFuture<ByteData>(key.endsWith('.svg') ? _svg : _png);
  }
}

String _snakeCase(String identifier) => identifier.replaceAllMapped(
  RegExp('(?<=[a-z0-9])[A-Z]'),
  (match) => '_${match[0]!.toLowerCase()}',
);

void main() {
  group(DivineStickerName, () {
    test('has 133 variants', () {
      expect(DivineStickerName.values.length, equals(133));
    });

    test('assetPath points Figma artwork at the PNG directory', () {
      expect(
        DivineStickerName.boom.assetPath,
        equals('assets/divine_stickers/boom.png'),
      );
    });

    test('assetPath returns correct path for multi-word name', () {
      expect(
        DivineStickerName.forgotPassword.assetPath,
        equals('assets/divine_stickers/forgot_password.png'),
      );
    });

    test('all variants have unique file names', () {
      final fileNames = DivineStickerName.values.map((s) => s.fileName).toSet();
      expect(fileNames.length, equals(DivineStickerName.values.length));
    });

    test('all file names use snake_case', () {
      for (final sticker in DivineStickerName.values) {
        expect(
          sticker.fileName,
          matches(RegExp(r'^[a-z0-9_]+$')),
          reason:
              '${sticker.name} fileName "${sticker.fileName}" '
              'is not snake_case',
        );
      }
    });

    test('every file name is the snake_case form of its variant name', () {
      for (final sticker in DivineStickerName.values) {
        expect(
          sticker.fileName,
          equals(_snakeCase(sticker.name)),
          reason: sticker.name,
        );
      }
    });

    group('figmaName', () {
      test('matches the variant name when that is a valid identifier', () {
        expect(DivineStickerName.alert.figmaName, equals('alert'));
      });

      test('keeps the Figma spelling a Dart identifier cannot express', () {
        expect(DivineStickerName.dAndD.figmaName, equals('d&d'));
      });

      test('is unique across the Figma-backed variants', () {
        final figmaNames = DivineStickerName.values
            .where((sticker) => !sticker.isLegacySvg)
            .map((sticker) => sticker.figmaName)
            .toList();

        expect(figmaNames, hasLength(132));
        expect(figmaNames.toSet(), hasLength(figmaNames.length));
      });
    });

    group('grandfather', () {
      test('is the only legacy variant', () {
        expect(
          DivineStickerName.values.where((sticker) => sticker.isLegacySvg),
          equals([DivineStickerName.grandfather]),
        );
      });

      test('keeps its original SVG artwork', () {
        expect(
          DivineStickerName.grandfather.assetPath,
          equals('assets/stickers/grandfather.svg'),
        );
      });

      test('has no Figma name', () {
        expect(DivineStickerName.grandfather.figmaName, isNull);
      });
    });
  });

  group(DivineSticker, () {
    Widget buildSubject({
      DivineStickerName sticker = DivineStickerName.boom,
      double? size,
    }) {
      return MaterialApp(
        home: DefaultAssetBundle(
          bundle: _TestAssetBundle(),
          // Centered so the sticker is laid out at its own size rather than
          // stretched to the screen by the tight constraints home receives.
          child: Center(
            child: size != null
                ? DivineSticker(sticker: sticker, size: size)
                : DivineSticker(sticker: sticker),
          ),
        ),
      );
    }

    testWidgets('renders Figma artwork as an $Image, not an $SvgPicture', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());

      expect(find.byType(Image), findsOneWidget);
      expect(find.byType(SvgPicture), findsNothing);
    });

    testWidgets('loads the asset the variant points at', (tester) async {
      await tester.pumpWidget(
        buildSubject(sticker: DivineStickerName.hangLoose),
      );

      final image = tester.widget<Image>(find.byType(Image));
      expect(
        image.image,
        isA<AssetImage>().having(
          (asset) => asset.assetName,
          'assetName',
          equals('assets/divine_stickers/hang_loose.png'),
        ),
      );
    });

    testWidgets('renders with default size', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(tester.getSize(find.byType(DivineSticker)), const Size(132, 132));
    });

    testWidgets('renders with custom size', (tester) async {
      await tester.pumpWidget(
        buildSubject(sticker: DivineStickerName.sparkle, size: 64),
      );

      expect(tester.getSize(find.byType(DivineSticker)), const Size(64, 64));
    });

    testWidgets('scales artwork to fit the box without stretching it', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());

      final image = tester.widget<Image>(find.byType(Image));
      expect(image.fit, equals(BoxFit.contain));
    });

    testWidgets('applies no tint to full-color artwork', (tester) async {
      await tester.pumpWidget(buildSubject());

      final image = tester.widget<Image>(find.byType(Image));
      expect(image.color, isNull);
      expect(image.colorBlendMode, isNull);
    });

    testWidgets('renders the legacy variant as an $SvgPicture', (tester) async {
      await tester.pumpWidget(
        buildSubject(sticker: DivineStickerName.grandfather, size: 96),
      );

      expect(find.byType(SvgPicture), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      expect(tester.getSize(find.byType(DivineSticker)), const Size(96, 96));
    });
  });
}
