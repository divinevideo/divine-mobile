// ABOUTME: Tests for TextEffectsControls: the outline and shadow sliders and
// ABOUTME: color rows, and what they report back.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/text_effects.dart';
import 'package:openvine/widgets/video_editor/text_effects_controls.dart';
import 'package:openvine/widgets/video_editor/video_editor_color_row.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  const yellow = Color(0xFFFFF140);

  group(TextEffectsControls, () {
    late List<TextEffects> changes;

    setUp(() => changes = []);

    Future<void> pumpControls(
      WidgetTester tester, {
      TextEffects effects = TextEffects.none,
    }) {
      return tester.pumpWidget(
        MaterialApp(
          theme: VineTheme.theme,
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: TextEffectsControls(
                effects: effects,
                onChanged: changes.add,
              ),
            ),
          ),
        ),
      );
    }

    Finder slider(String label) => find.byWidgetPredicate(
      (widget) => widget is DivineSlider && widget.semanticLabel == label,
    );

    /// The swatches for [color]: the outline row's first, the shadow's last.
    Finder swatches(Color color) => find.byWidgetPredicate(
      (widget) =>
          widget is VideoEditorColorTile &&
          !widget.isCustom &&
          widget.color == color,
    );

    group('renders', () {
      testWidgets('an outline and a shadow section', (tester) async {
        await pumpControls(tester);

        expect(find.text(l10n.videoEditorTextOutline), findsOneWidget);
        expect(find.text(l10n.videoEditorTextShadow), findsOneWidget);
        expect(slider(l10n.videoEditorTextOutlineThickness), findsOneWidget);
        expect(slider(l10n.videoEditorTextShadowStrength), findsOneWidget);
      });

      testWidgets('each color row with every palette color', (tester) async {
        await pumpControls(tester);

        for (final color in VideoEditorConstants.colors) {
          expect(swatches(color), findsNWidgets(2), reason: '$color');
        }
      });

      testWidgets('the slider positions of the effects', (tester) async {
        await pumpControls(
          tester,
          effects: const TextEffects(
            outlineThickness: 0.25,
            shadowStrength: 0.75,
          ),
        );

        expect(
          tester
              .widget<DivineSlider>(
                slider(l10n.videoEditorTextOutlineThickness),
              )
              .value,
          0.25,
        );
        expect(
          tester
              .widget<DivineSlider>(slider(l10n.videoEditorTextShadowStrength))
              .value,
          0.75,
        );
        expect(find.text('25'), findsOneWidget);
        expect(find.text('75'), findsOneWidget);
      });
    });

    group('interactions', () {
      testWidgets('dragging the outline slider sets the thickness', (
        tester,
      ) async {
        await pumpControls(tester);

        await tester.tap(slider(l10n.videoEditorTextOutlineThickness));
        await tester.pump();

        expect(changes, hasLength(1));
        expect(changes.single.outlineThickness, greaterThan(0));
        expect(changes.single.hasShadow, isFalse);
      });

      testWidgets('dragging the shadow slider sets the strength', (
        tester,
      ) async {
        await pumpControls(tester);

        await tester.tap(slider(l10n.videoEditorTextShadowStrength));
        await tester.pump();

        expect(changes, hasLength(1));
        expect(changes.single.shadowStrength, greaterThan(0));
        expect(changes.single.hasOutline, isFalse);
      });

      testWidgets('picking an outline color turns the outline on', (
        tester,
      ) async {
        await pumpControls(tester);

        await tester.tap(swatches(yellow).first);
        await tester.pump();

        expect(changes, [TextEffects.none.withOutlineColor(yellow)]);
      });

      testWidgets('picking a shadow color turns the shadow on', (tester) async {
        await pumpControls(tester);

        await tester.ensureVisible(swatches(yellow).last);
        await tester.tap(swatches(yellow).last);
        await tester.pump();

        expect(changes, [TextEffects.none.withShadowColor(yellow)]);
      });

      testWidgets('marks the colors in use as selected', (tester) async {
        await pumpControls(
          tester,
          effects: const TextEffects(
            outlineThickness: 0.5,
            outlineColor: yellow,
          ),
        );

        final outlineSwatch = tester.widget<VideoEditorColorTile>(
          swatches(yellow).first,
        );
        final shadowSwatch = tester.widget<VideoEditorColorTile>(
          swatches(yellow).last,
        );
        expect(outlineSwatch.selected, isTrue);
        expect(shadowSwatch.selected, isFalse);
      });
    });
  });
}
