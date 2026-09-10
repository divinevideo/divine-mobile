import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group(DivineStickerName, () {
    test('has 71 variants', () {
      expect(DivineStickerName.values.length, equals(71));
    });

    test('assetPath returns correct path', () {
      expect(
        DivineStickerName.boom.assetPath,
        equals('assets/stickers/boom.svg'),
      );
    });

    test('assetPath returns correct path for multi-word name', () {
      expect(
        DivineStickerName.forgotPasswordAlt.assetPath,
        equals('assets/stickers/forgot_password_alt.svg'),
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
  });

  group(DivineSticker, () {
    Widget buildSubject({
      DivineStickerName sticker = DivineStickerName.boom,
      double? size,
    }) {
      return MaterialApp(
        home: size != null
            ? DivineSticker(sticker: sticker, size: size)
            : DivineSticker(sticker: sticker),
      );
    }

    testWidgets('renders an $SvgPicture widget', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.byType(SvgPicture), findsOneWidget);
    });

    testWidgets('renders with default size', (tester) async {
      await tester.pumpWidget(buildSubject());

      final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
      expect(svg.width, equals(132));
      expect(svg.height, equals(132));
    });

    testWidgets('renders with custom size', (tester) async {
      await tester.pumpWidget(
        buildSubject(sticker: DivineStickerName.sparkle, size: 64),
      );

      final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
      expect(svg.width, equals(64));
      expect(svg.height, equals(64));
    });
  });
}
