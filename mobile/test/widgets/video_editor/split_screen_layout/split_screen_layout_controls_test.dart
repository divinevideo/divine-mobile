// ABOUTME: Tests for the split-screen layout controls: the selected layout
// ABOUTME: tile stands out in both appearances, and only changed tiles repaint

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/blocs/video_editor/split_screen_layout/split_screen_layout_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/split_screen_layout.dart';
import 'package:openvine/widgets/video_editor/split_screen_layout/split_screen_layout_controls.dart';

import '../../../helpers/contrast.dart';

void main() {
  group(SplitScreenPresetPicker, () {
    final l10n = lookupAppLocalizations(const Locale('en'));

    Future<SplitScreenLayoutCubit> pump(
      WidgetTester tester,
      ThemeData theme,
    ) async {
      final cubit = SplitScreenLayoutCubit(
        aspectRatio: model.AspectRatio.vertical,
        borderColor: VineTheme.backgroundColor,
      );
      addTearDown(cubit.close);
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BlocProvider.value(
              value: cubit,
              child: const SplitScreenPresetPicker(),
            ),
          ),
        ),
      );
      return cubit;
    }

    Finder tileLabelled(String label) => find.byWidgetPredicate(
      (widget) => widget is Semantics && widget.properties.label == label,
    );

    /// The outline of the tile labelled [label] and the fill inside it.
    ({Color outline, Color fill}) tileColors(
      WidgetTester tester,
      String label,
    ) {
      final tile = tileLabelled(label);
      final decoration =
          tester
                  .widget<Container>(
                    find
                        .descendant(of: tile, matching: find.byType(Container))
                        .first,
                  )
                  .decoration!
              as BoxDecoration;
      return (
        outline: (decoration.border! as Border).top.color,
        fill: decoration.color!,
      );
    }

    for (final (name, theme) in [
      ('dark', VineTheme.theme),
      ('light', VineTheme.lightTheme),
    ]) {
      testWidgets(
        'draws the selected layout at 3:1 or more in $name mode',
        (tester) async {
          await pump(tester, theme);

          final label = l10n.videoEditorLayoutPresetSideBySide;
          final (:outline, :fill) = tileColors(tester, label);
          Color? glyph;
          expect(
            find.descendant(
              of: find.byWidgetPredicate(
                (widget) =>
                    widget is Semantics && widget.properties.label == label,
              ),
              matching: find.byType(CustomPaint),
            ),
            paints..something((method, arguments) {
              if (method != #drawRRect) return false;
              glyph = (arguments[1] as Paint).color;
              return true;
            }),
          );

          for (final (part, color) in [
            ('outline', outline),
            ('glyph', glyph!),
          ]) {
            final ratio = contrastRatio(color, fill);
            expect(
              ratio,
              greaterThanOrEqualTo(3),
              reason: '$name $part measured ${ratio.toStringAsFixed(2)}:1',
            );
          }
        },
      );
    }

    testWidgets('repaints only the tiles a new selection changes', (
      tester,
    ) async {
      final cubit = await pump(tester, VineTheme.theme);
      CustomPainter painterOf(String label) => tester
          .widget<CustomPaint>(
            find.descendant(
              of: tileLabelled(label),
              matching: find.byType(CustomPaint),
            ),
          )
          .painter!;
      final grid = l10n.videoEditorLayoutPresetGrid;
      final stacked = l10n.videoEditorLayoutPresetStacked;
      final gridBefore = painterOf(grid);
      final stackedBefore = painterOf(stacked);

      cubit.presetSelected(SplitScreenLayoutPreset.stacked);
      await tester.pump();

      expect(identical(painterOf(grid), gridBefore), isFalse);
      expect(painterOf(grid).shouldRepaint(gridBefore), isFalse);
      expect(painterOf(stacked).shouldRepaint(stackedBefore), isTrue);
    });
  });
}
