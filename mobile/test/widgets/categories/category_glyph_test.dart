// ABOUTME: Widget tests for CategoryGlyph's SVG-with-emoji-fallback behavior.
// ABOUTME: Covers the #4398/#6116 crash fix: a missing asset degrades to emoji.

import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart' show VideoCategory;
import 'package:openvine/widgets/categories/category_glyph.dart';
import 'package:openvine/widgets/categories/category_visuals.dart';

void main() {
  group(CategoryGlyph, () {
    Widget buildSubject({required String? assetPath, required String emoji}) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: CategoryGlyph(
              assetPath: assetPath,
              emoji: emoji,
              height: 88,
            ),
          ),
        ),
      );
    }

    testWidgets('wires an errorBuilder so a missing asset can fall back', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(assetPath: 'assets/categories/music.svg', emoji: '🥤'),
      );

      final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
      expect(svg.errorBuilder, isNotNull);
    });

    testWidgets('errorBuilder renders the emoji fallback', (tester) async {
      await tester.pumpWidget(
        buildSubject(assetPath: 'assets/categories/music.svg', emoji: '🥤'),
      );
      final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));

      // Invoke the wired errorBuilder directly so the assertion does not depend
      // on flutter_svg's async asset-load timing (which flakes under the fake
      // test clock). vector_graphics calls this builder on asset-not-found.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) =>
                  svg.errorBuilder!(context, 'missing', StackTrace.empty),
            ),
          ),
        ),
      );

      expect(find.text('🥤'), findsOneWidget);
    });

    testWidgets('emoji fallback does not scale with system text size', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(assetPath: 'x.svg', emoji: '🥤'));
      final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(3)),
            child: Scaffold(
              body: Builder(
                builder: (context) =>
                    svg.errorBuilder!(context, 'missing', StackTrace.empty),
              ),
            ),
          ),
        ),
      );

      expect(find.text('🥤'), findsOneWidget);
      final clamped = tester
          .widgetList<MediaQuery>(find.byType(MediaQuery))
          .any((m) => m.data.textScaler == TextScaler.noScaling);
      expect(clamped, isTrue);
    });

    testWidgets('renders an SvgPicture for a bundled asset (no fallback)', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(assetPath: 'assets/categories/music.svg', emoji: '🎸'),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SvgPicture), findsOneWidget);
      expect(find.text('🎸'), findsNothing);
    });

    testWidgets('renders the emoji directly when assetPath is null (#6116)', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(assetPath: null, emoji: '🥊'));
      await tester.pumpAndSettle();

      // No SvgPicture is built at all, so flutter_svg never attempts (and never
      // reports) a missing-asset load.
      expect(find.byType(SvgPicture), findsNothing);
      expect(find.text('🥊'), findsOneWidget);
    });

    testWidgets('an unknown category renders its emoji, not an SVG (#6116)', (
      tester,
    ) async {
      // End-to-end: the exact Crashlytics scenario — a backend category with no
      // bundled SVG resolves to a null path and degrades to the emoji.
      const category = VideoCategory(name: 'fighting', videoCount: 42);
      final visuals = CategoryVisuals.forCategory(category, 0);
      expect(visuals.assetPath, isNull);

      await tester.pumpWidget(
        buildSubject(assetPath: visuals.assetPath, emoji: category.emoji),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SvgPicture), findsNothing);
      expect(find.text(category.emoji), findsOneWidget);
    });
  });
}
