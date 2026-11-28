// ABOUTME: Tests for VideoEditorFilterSettingsPanel: the cards of the picked
// ABOUTME: filter's settings, changing them and putting a card back.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/filter_editor/video_editor_filter_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/editor_filter_category.dart';
import 'package:openvine/widgets/video_editor/filter_editor/video_editor_filter_settings_panel.dart';
import 'package:openvine/widgets/video_editor/video_editor_color_row.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

import '../../../helpers/scroll.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  group(VideoEditorFilterSettingsPanel, () {
    late VideoEditorFilterBloc bloc;

    /// The bloc is created here, inside the test's zone: one created in
    /// setUp emits outside it, and the panel never hears of a change.
    Future<void> pumpPanel(WidgetTester tester, String filterName) async {
      bloc = VideoEditorFilterBloc()
        ..add(VideoEditorFilterSelected(editorFilterNamed(filterName)!))
        ..add(const VideoEditorFilterSettingsToggled(open: true));
      addTearDown(bloc.close);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BlocProvider<VideoEditorFilterBloc>.value(
              value: bloc,
              child: const Align(
                alignment: .bottomCenter,
                child: SizedBox(
                  height: 320,
                  child: VideoEditorFilterSettingsPanel(),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Finder panel() => find.byType(Scrollable).first;

    group('renders', () {
      testWidgets('names the filter, and shows its light, colour and colour '
          'balance cards', (tester) async {
        await pumpPanel(tester, 'Crema');

        expect(
          find.text(l10n.videoEditorEffectSettingsTitle('Crema')),
          findsOneWidget,
        );
        expect(find.text(l10n.videoEditorFilterLightTitle), findsOneWidget);
        expect(find.text(l10n.videoEditorTuneBrightness), findsOneWidget);
        final balance = find.text(l10n.videoEditorFilterBalanceTitle);
        await scrollUntilTappable(tester, balance, 50, scrollable: panel());
        expect(balance, findsOneWidget);
        expect(find.text(l10n.videoEditorTuneTemperature), findsOneWidget);
      });

      testWidgets('numbers the cards of a filter with two overlays', (
        tester,
      ) async {
        await pumpPanel(tester, 'Cinematic');

        for (final number in [1, 2]) {
          final title = find.text(
            l10n.videoEditorFilterSettingsNumberedTitle(
              l10n.videoEditorFilterOverlayTitle,
              '$number',
            ),
          );
          await scrollUntilTappable(tester, title, 50, scrollable: panel());
          expect(title, findsOneWidget);
        }
      });

      testWidgets('offers a black-and-white filter no saturation', (
        tester,
      ) async {
        await pumpPanel(tester, 'Inkwell');
        final sepia = find.text(l10n.videoEditorEffectSettingSepia);
        await scrollUntilTappable(tester, sepia, 50, scrollable: panel());

        expect(sepia, findsOneWidget);
        expect(find.text(l10n.videoEditorTuneSaturation), findsNothing);
      });
    });

    group('interactions', () {
      testWidgets('the back button goes back to the picker', (tester) async {
        await pumpPanel(tester, 'Crema');

        await tester.tap(find.bySemanticsLabel(l10n.commonBack));
        await tester.pump();

        expect(bloc.state.isSettingsOpen, isFalse);
      });

      testWidgets('a slider changes the filter, and resetting its card puts '
          "back the preset's own", (tester) async {
        await pumpPanel(tester, 'Crema');
        final reset = find.text(l10n.videoEditorFilterLightReset);
        await scrollUntilTappable(tester, reset, 50, scrollable: panel());
        // Nothing is changed yet, so there is nothing to put back.
        expect(
          tester
              .widget<DivineButton>(
                find.ancestor(of: reset, matching: find.byType(DivineButton)),
              )
              .onPressed,
          isNull,
        );
        final brightness = find.bySemanticsLabel(
          l10n.videoEditorTuneBrightness,
        );
        await scrollUntilTappable(tester, brightness, -50, scrollable: panel());

        await tester.drag(brightness, const Offset(800, 0));
        await tester.pumpAndSettle();

        expect(bloc.state.settingValues, {'brightness': 0.3});
        expect(
          bloc.state.edited!.filter.steps.last,
          ColorFilterStep.brightness(0.3),
        );

        await scrollUntilTappable(tester, reset, 50, scrollable: panel());
        await tester.tap(reset);
        await tester.pumpAndSettle();

        expect(bloc.state.settingValues, isEmpty);
      });

      testWidgets('picks the colour of a tint', (tester) async {
        await pumpPanel(tester, 'Ruby');
        final palette = find.descendant(
          of: find.byType(VideoEditorColorRow),
          matching: find.byType(VideoEditorColorTile),
        );
        await scrollUntilTappable(
          tester,
          palette.at(1),
          50,
          scrollable: panel(),
        );

        await tester.tap(palette.at(1));
        await tester.pumpAndSettle();

        expect(
          bloc.state.settingValues,
          {'step0.color': VideoEditorConstants.colors.first.toARGB32()},
        );
      });
    });
  });
}
