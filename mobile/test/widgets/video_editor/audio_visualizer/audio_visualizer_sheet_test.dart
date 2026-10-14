// ABOUTME: Tests the audio visualizer sheet: its styles and colors, and what
// ABOUTME: it returns for a new visualizer and for one being changed.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/audio_visualizer/video_editor_audio_visualizer_cubit.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/audio_visualizer_layer.dart';
import 'package:openvine/widgets/video_editor/audio_visualizer/audio_visualizer_sheet.dart';
import 'package:openvine/widgets/video_editor/video_editor_color_row.dart';
import 'package:pro_video_editor/pro_video_editor.dart'
    show AudioVisualizerStyle;

void main() {
  group(AudioVisualizerSheet, () {
    final l10n = lookupAppLocalizations(const Locale('en'));

    /// Opens the sheet from a button and records what it resolves with.
    Future<List<AudioVisualizerLayerData?>> pumpSheet(
      WidgetTester tester, {
      AudioVisualizerLayerData? initial,
      VideoEditorAudioVisualizerCubit? soundLevels,
    }) async {
      final results = <AudioVisualizerLayerData?>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: VineTheme.theme,
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          // The preview loops for as long as the sheet is open; with reduced
          // motion it holds still, so the sheet can settle.
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async => results.add(
                  await showAudioVisualizerSheet(
                    context,
                    initial: initial,
                    soundLevels: soundLevels,
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return results;
    }

    group('renders', () {
      testWidgets('every style by name and the color row', (tester) async {
        await pumpSheet(tester);

        for (final name in [
          l10n.videoEditorAudioVisualizerStyleBars,
          l10n.videoEditorAudioVisualizerStyleMirrored,
          l10n.videoEditorAudioVisualizerStyleWave,
          l10n.videoEditorAudioVisualizerStyleCircle,
        ]) {
          expect(find.text(name), findsOneWidget);
        }
        expect(find.byType(VideoEditorColorRow), findsOneWidget);
        expect(find.text(l10n.videoEditorAudioVisualizerAdd), findsOneWidget);
      });

      testWidgets('the band, reaction and bar width sliders', (
        tester,
      ) async {
        await pumpSheet(tester);

        expect(
          find.text(l10n.videoEditorAudioVisualizerDensityLabel),
          findsOneWidget,
        );
        expect(
          find.text(l10n.videoEditorAudioVisualizerReactionLabel),
          findsOneWidget,
        );
        expect(
          find.text(l10n.videoEditorAudioVisualizerBarWidthLabel),
          findsOneWidget,
        );
        expect(find.byType(DivineSlider), findsNWidgets(3));
      });

      testWidgets('no bar width for the wave, which has no bars', (
        tester,
      ) async {
        await pumpSheet(
          tester,
          initial: const AudioVisualizerLayerData(
            style: AudioVisualizerStyle.wave,
          ),
        );

        expect(
          find.text(l10n.videoEditorAudioVisualizerBarWidthLabel),
          findsNothing,
        );
        expect(find.byType(DivineSlider), findsNWidgets(2));
      });

      testWidgets('marks the style in use as selected', (tester) async {
        final semantics = tester.ensureSemantics();
        await pumpSheet(
          tester,
          initial: const AudioVisualizerLayerData(
            style: AudioVisualizerStyle.circle,
          ),
        );

        expect(
          tester.getSemantics(
            find.bySemanticsLabel(l10n.videoEditorAudioVisualizerStyleCircle),
          ),
          matchesSemantics(
            label: l10n.videoEditorAudioVisualizerStyleCircle,
            isButton: true,
            hasSelectedState: true,
            isSelected: true,
            hasTapAction: true,
          ),
        );
        semantics.dispose();
      });
    });

    group('interactions', () {
      testWidgets('previews the sound it is given while it is open', (
        tester,
      ) async {
        final soundLevels = VideoEditorAudioVisualizerCubit();
        addTearDown(soundLevels.close);
        await pumpSheet(tester, soundLevels: soundLevels);

        expect(soundLevels.state.isPreviewing, isTrue);
        await tester.tap(find.text(l10n.videoEditorAudioVisualizerAdd));
        await tester.pumpAndSettle();
        expect(soundLevels.state.isPreviewing, isFalse);
      });

      testWidgets('adds the default look when nothing is changed', (
        tester,
      ) async {
        final results = await pumpSheet(tester);

        await tester.tap(find.text(l10n.videoEditorAudioVisualizerAdd));
        await tester.pumpAndSettle();

        expect(results, [const AudioVisualizerLayerData()]);
      });

      testWidgets('returns the style and color picked', (tester) async {
        final results = await pumpSheet(tester);
        final pink = VideoEditorConstants.colors[6];

        await tester.tap(find.text(l10n.videoEditorAudioVisualizerStyleWave));
        await tester.pump();
        await tester.tap(
          find.byWidgetPredicate(
            (widget) =>
                widget is VideoEditorColorTile &&
                !widget.isCustom &&
                widget.color == pink,
          ),
        );
        await tester.pump();
        await tester.tap(find.text(l10n.videoEditorAudioVisualizerAdd));
        await tester.pumpAndSettle();

        expect(results, [
          AudioVisualizerLayerData(
            style: AudioVisualizerStyle.wave,
            color: pink,
          ),
        ]);
      });

      testWidgets('returns the band count, reaction and bar width set', (
        tester,
      ) async {
        final results = await pumpSheet(tester);
        DivineSlider slider(int index) =>
            tester.widget<DivineSlider>(find.byType(DivineSlider).at(index));

        // Bands move one at a time.
        slider(0).onChanged!(40.4);
        await tester.pump();
        slider(1).onChanged!(0.9);
        await tester.pump();
        slider(2).onChanged!(0.4);
        await tester.pump();
        await tester.tap(find.text(l10n.videoEditorAudioVisualizerAdd));
        await tester.pumpAndSettle();

        expect(results, [
          const AudioVisualizerLayerData(
            bands: 40,
            reaction: 0.9,
            barFill: 0.4,
          ),
        ]);
      });

      testWidgets('starts from the visualizer being changed and confirms '
          'with Done', (tester) async {
        const initial = AudioVisualizerLayerData(
          style: AudioVisualizerStyle.mirroredBars,
          color: VineTheme.whiteText,
        );
        final results = await pumpSheet(tester, initial: initial);

        expect(find.text(l10n.videoEditorAudioVisualizerAdd), findsNothing);
        await tester.tap(find.text(l10n.videoEditorDoneLabel));
        await tester.pumpAndSettle();

        expect(results, [initial]);
      });
    });
  });
}
