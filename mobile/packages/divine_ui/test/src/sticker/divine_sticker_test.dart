import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

// 1×1 transparent lossless WebP, the format the real stickers ship in.
final _transparentWebp = Uint8List.fromList(const <int>[
  0x52, 0x49, 0x46, 0x46, 0x1a, 0x00, 0x00, 0x00, //
  0x57, 0x45, 0x42, 0x50, 0x56, 0x50, 0x38, 0x4c,
  0x0d, 0x00, 0x00, 0x00, 0x2f, 0x00, 0x00, 0x00,
  0x10, 0x07, 0x10, 0x11, 0x11, 0x88, 0x88, 0xfe,
  0x07, 0x00,
]);

// The real artwork ships with the app, not with this package, so every
// sticker path resolves to a stand-in WebP.
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
  final ByteData _webp = ByteData.sublistView(_transparentWebp);

  @override
  Future<ByteData> load(String key) {
    if (key == 'AssetManifest.bin') {
      return SynchronousFuture<ByteData>(_manifest);
    }
    return SynchronousFuture<ByteData>(_webp);
  }
}

String _snakeCase(String identifier) => identifier.replaceAllMapped(
  RegExp('(?<=[a-z0-9])[A-Z]'),
  (match) => '_${match[0]!.toLowerCase()}',
);

void main() {
  group(DivineStickerName, () {
    test('has 180 variants', () {
      expect(DivineStickerName.values.length, equals(180));
    });

    test('assetPath points WebP artwork at the WebP directory', () {
      expect(
        DivineStickerName.boom.assetPath,
        equals('assets/divine_stickers/boom.webp'),
      );
    });

    test('assetPath returns correct path for multi-word name', () {
      expect(
        DivineStickerName.forgotPassword.assetPath,
        equals('assets/divine_stickers/forgot_password.webp'),
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

    testWidgets('renders the artwork as an $Image', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('loads the asset the variant points at', (tester) async {
      await tester.pumpWidget(
        buildSubject(sticker: DivineStickerName.hangLoose),
      );

      final image = tester.widget<Image>(find.byType(Image));
      // Equality covers the package too, which decides the key the app's
      // asset bundle is asked for.
      expect(
        image.image,
        equals(const AssetImage('assets/divine_stickers/hang_loose.webp')),
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
  });
}
