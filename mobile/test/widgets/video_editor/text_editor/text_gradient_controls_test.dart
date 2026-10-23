// ABOUTME: Tests for TextGradientControls: the ready-made gradients, the
// ABOUTME: colors and the direction of a text gradient, and what they report.

import 'dart:math' as math;
import 'dart:ui' show Tristate;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/text_gradient_presets.dart';
import 'package:openvine/widgets/video_editor/text_editor/text_gradient_controls.dart';
import 'package:pro_image_editor/pro_image_editor.dart' show TextGradient;

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  group(TextGradientControls, () {
    late List<TextGradient> changes;

    setUp(() => changes = []);

    // The color picker closes through the router.
    Future<void> pumpControls(WidgetTester tester, TextGradient gradient) {
      return tester.pumpWidget(
        MaterialApp.router(
          theme: VineTheme.theme,
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (_, _) => Scaffold(
                  body: SingleChildScrollView(
                    child: TextGradientControls(
                      gradient: gradient,
                      onChanged: changes.add,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    Future<void> tapLabel(WidgetTester tester, String label) async {
      await tester.tap(find.bySemanticsLabel(label));
      await tester.pumpAndSettle();
    }

    group('interactions', () {
      testWidgets('picks a ready-made gradient in the current direction', (
        tester,
      ) async {
        await pumpControls(
          tester,
          TextGradientPreset.sunset.withAngle(math.pi / 2),
        );

        await tapLabel(tester, l10n.videoEditorTextGradientOcean);

        expect(changes.single.colors, TextGradientPreset.ocean.colors);
        expect(changes.single.angle, math.pi / 2);
      });

      testWidgets('turns the gradient to the direction picked', (
        tester,
      ) async {
        await pumpControls(tester, TextGradientPreset.sunset.withAngle(0));

        await tapLabel(tester, l10n.videoEditorTextGradientBottomToTop);

        expect(
          changes.single.angle,
          TextGradientDirection.bottomToTop.angle,
        );
        expect(changes.single.colors, TextGradientPreset.sunset.colors);
      });

      testWidgets('removes the last color', (tester) async {
        await pumpControls(tester, TextGradientPreset.sunset.withAngle(1));

        await tapLabel(tester, l10n.videoEditorTextGradientRemoveColor);

        expect(
          changes.single.colors,
          TextGradientPreset.sunset.colors.sublist(0, 2),
        );
        expect(changes.single.angle, 1);
      });

      testWidgets('adds the color picked to the end', (tester) async {
        // Stops fit the colors they came with, so adding one drops them.
        const gradient = TextGradient(
          colors: [VineTheme.accentBlue, VineTheme.accentPurple],
          stops: [0.2, 1],
        );
        await pumpControls(tester, gradient);

        await tapLabel(tester, l10n.videoEditorTextGradientAddColor);
        await tapLabel(tester, l10n.videoEditorConfirmColorSemanticLabel);

        expect(changes.single.colors, hasLength(3));
        expect(changes.single.colors.take(2), gradient.colors);
        expect(changes.single.stops, isNull);
        expect(changes.single.isValid, isTrue);
      });

      testWidgets('keeps between two and six colors', (tester) async {
        await pumpControls(tester, TextGradientPreset.mint.withAngle(0));
        await tapLabel(tester, l10n.videoEditorTextGradientRemoveColor);

        await pumpControls(tester, TextGradientPreset.rainbow.withAngle(0));
        await tapLabel(tester, l10n.videoEditorTextGradientAddColor);

        expect(changes, isEmpty);
      });
    });

    group('renders', () {
      testWidgets('marks the preset and the direction in use as selected', (
        tester,
      ) async {
        await pumpControls(
          tester,
          TextGradientPreset.candy.withAngle(math.pi / 4),
        );

        Tristate selected(String label) => tester
            .getSemantics(find.bySemanticsLabel(label))
            .getSemanticsData()
            .flagsCollection
            .isSelected;

        expect(selected(l10n.videoEditorTextGradientCandy), Tristate.isTrue);
        expect(selected(l10n.videoEditorTextGradientSunset), Tristate.isFalse);
        expect(
          selected(l10n.videoEditorTextGradientTopLeftToBottomRight),
          Tristate.isTrue,
        );
        expect(
          selected(l10n.videoEditorTextGradientLeftToRight),
          Tristate.isFalse,
        );
      });
    });
  });
}
