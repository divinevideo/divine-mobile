import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DivineIconName', () {
    test('assetPath returns correct path', () {
      expect(DivineIconName.arrowLeft.assetPath, 'assets/icon/arrow_left.svg');
    });

    test('assetPath handles mixed case file names', () {
      expect(DivineIconName.caretDown.assetPath, 'assets/icon/CaretDown.svg');
    });

    test('fileName returns the raw file name', () {
      expect(DivineIconName.x.fileName, 'close');
    });

    test('divineMark maps to the 32x32 standalone brand mark asset', () {
      expect(DivineIconName.divineMark.fileName, 'divine_mark');
      expect(
        DivineIconName.divineMark.assetPath,
        'assets/icon/divine_mark.svg',
      );
    });

    test('users maps to the two-person collaborations glyph', () {
      expect(DivineIconName.users.fileName, 'users');
      expect(DivineIconName.users.assetPath, 'assets/icon/users.svg');
    });

    test('squaresFour maps to the four-square grid glyph', () {
      expect(DivineIconName.squaresFour.fileName, 'squares_four');
      expect(
        DivineIconName.squaresFour.assetPath,
        'assets/icon/squares_four.svg',
      );
    });

    test('microphone maps to the voice-over capture glyph', () {
      expect(DivineIconName.microphone.fileName, 'microphone');
      expect(DivineIconName.microphone.assetPath, 'assets/icon/microphone.svg');
    });

    test('flipHorizontal maps to the mirror glyph', () {
      expect(DivineIconName.flipHorizontal.fileName, 'flip_horizontal');
      expect(
        DivineIconName.flipHorizontal.assetPath,
        'assets/icon/flip_horizontal.svg',
      );
    });

    test('bug maps to the diagnostics glyph pair', () {
      expect(DivineIconName.bug.fileName, 'bug');
      expect(DivineIconName.bug.assetPath, 'assets/icon/bug.svg');
      expect(DivineIconName.bugFill.fileName, 'bug_fill');
      expect(DivineIconName.bugFill.assetPath, 'assets/icon/bug_fill.svg');
    });

    test('all enum values have non-empty file names', () {
      for (final icon in DivineIconName.values) {
        expect(
          icon.fileName,
          isNotEmpty,
          reason: '${icon.name} has empty fileName',
        );
      }
    });
  });

  group('DivineIcon', () {
    testWidgets('renders an SvgPicture', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: DivineIcon(icon: DivineIconName.arrowLeft)),
        ),
      );

      expect(find.byType(SvgPicture), findsOneWidget);
    });

    testWidgets('uses default size of 24', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: DivineIcon(icon: DivineIconName.arrowLeft)),
        ),
      );

      final svgPicture = tester.widget<SvgPicture>(find.byType(SvgPicture));
      expect(svgPicture.width, 24);
      expect(svgPicture.height, 24);
    });

    testWidgets('uses custom size', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DivineIcon(icon: DivineIconName.arrowLeft, size: 32),
          ),
        ),
      );

      final svgPicture = tester.widget<SvgPicture>(find.byType(SvgPicture));
      expect(svgPicture.width, 32);
      expect(svgPicture.height, 32);
    });

    testWidgets('letterboxes the artwork by default', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: DivineIcon(icon: DivineIconName.arrowLeft)),
        ),
      );

      final svgPicture = tester.widget<SvgPicture>(find.byType(SvgPicture));
      expect(svgPicture.fit, BoxFit.contain);
    });

    testWidgets('crops the artwork when fit is cover', (tester) async {
      // A wide asset standing in for a square avatar has to fill the box and
      // crop, not shrink to a letterboxed sliver.
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DivineIcon(
              icon: DivineIconName.logo,
              size: 40,
              fit: BoxFit.cover,
            ),
          ),
        ),
      );

      final svgPicture = tester.widget<SvgPicture>(find.byType(SvgPicture));
      expect(svgPicture.fit, BoxFit.cover);
    });

    testWidgets('applies color filter when color is provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DivineIcon(
              icon: DivineIconName.arrowLeft,
              color: VineTheme.onSurface,
            ),
          ),
        ),
      );

      final svgPicture = tester.widget<SvgPicture>(find.byType(SvgPicture));
      expect(
        svgPicture.colorFilter,
        const ColorFilter.mode(VineTheme.onSurface, BlendMode.srcIn),
      );
    });

    testWidgets('does not apply color filter when color is null', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: DivineIcon(icon: DivineIconName.arrowLeft)),
        ),
      );

      final svgPicture = tester.widget<SvgPicture>(find.byType(SvgPicture));
      expect(svgPicture.colorFilter, isNull);
    });

    testWidgets('can be used with const constructor', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DivineIcon(
              icon: DivineIconName.check,
              color: VineTheme.primary,
            ),
          ),
        ),
      );

      expect(find.byType(DivineIcon), findsOneWidget);
    });
  });

  group('DivineIcon text scaling', () {
    Widget buildSubject({required double textScale, double size = 24}) {
      return MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(
            body: DivineIcon(icon: DivineIconName.arrowLeft, size: size),
          ),
        ),
      );
    }

    double renderedSize(WidgetTester tester) =>
        tester.widget<SvgPicture>(find.byType(SvgPicture)).width!;

    testWidgets('grows with the system text scale', (tester) async {
      await tester.pumpWidget(buildSubject(textScale: 1.2));

      expect(renderedSize(tester), closeTo(24 * 1.2, 0.001));
    });

    testWidgets('stops growing at maxScaleFactor', (tester) async {
      await tester.pumpWidget(buildSubject(textScale: 2));

      expect(
        renderedSize(tester),
        closeTo(24 * DivineIcon.maxScaleFactor, 0.001),
      );
    });

    testWidgets('scales width and height together', (tester) async {
      await tester.pumpWidget(buildSubject(textScale: 2, size: 40));

      final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
      expect(svg.width, svg.height);
      expect(svg.width, closeTo(40 * DivineIcon.maxScaleFactor, 0.001));
    });

    testWidgets('scaleSize caps at maxScaleFactor, and a tighter ambient '
        'clamp wins over it', (tester) async {
      late double outer;
      late double inner;

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Builder(
              builder: (context) {
                outer = DivineIcon.scaleSize(context, 48);
                return MediaQuery.withClampedTextScaling(
                  maxScaleFactor: 1.1,
                  child: Builder(
                    builder: (context) {
                      inner = DivineIcon.scaleSize(context, 48);
                      return const SizedBox.shrink();
                    },
                  ),
                );
              },
            ),
          ),
        ),
      );

      expect(outer, closeTo(48 * DivineIcon.maxScaleFactor, 0.001));
      expect(inner, closeTo(48 * 1.1, 0.001));
    });
  });
}
