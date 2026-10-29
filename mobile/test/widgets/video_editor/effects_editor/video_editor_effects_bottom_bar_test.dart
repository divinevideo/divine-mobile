import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/effects_editor/video_editor_effects_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/editor_video_effect.dart';
import 'package:openvine/widgets/video_editor/effects_editor/video_editor_effects_bottom_bar.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show VideoEffectType;

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  group(VideoEditorEffectsBottomBar, () {
    late VideoEditorEffectsCubit cubit;

    setUp(() => cubit = VideoEditorEffectsCubit()..startEditing());
    tearDown(() => cubit.close());

    Widget buildWidget() {
      return ProviderScope(
        child: MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BlocProvider.value(
              value: cubit,
              child: const SizedBox(
                height: 100,
                child: VideoEditorEffectsBottomBar(),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('lists "none" and every effect by name', (tester) async {
      await tester.pumpWidget(buildWidget());

      for (final label in [
        l10n.videoEditorEffectNone,
        l10n.videoEditorEffectGlitch,
        l10n.videoEditorEffectRgbSplit,
        l10n.videoEditorEffectVhs,
        l10n.videoEditorEffectTvStatic,
        l10n.videoEditorEffectPixelate,
        l10n.videoEditorEffectPixelPulse,
        l10n.videoEditorEffectBlockGlitch,
        l10n.videoEditorEffectFilmGrain,
        l10n.videoEditorEffectSignalInterference,
        l10n.videoEditorEffectCrt,
        l10n.videoEditorEffectShake,
        l10n.videoEditorEffectZoomPulse,
        l10n.videoEditorEffectMirror,
        l10n.videoEditorEffectKaleidoscope,
        l10n.videoEditorEffectSplitScreen,
        l10n.videoEditorEffectWave,
        l10n.videoEditorEffectGlow,
        l10n.videoEditorEffectEcho,
        l10n.videoEditorEffectFisheye,
        l10n.videoEditorEffectDrops,
        l10n.videoEditorEffectLightLeak,
        l10n.videoEditorEffectSnow,
        l10n.videoEditorEffectRain,
        l10n.videoEditorEffectLeaves,
        l10n.videoEditorEffectBlossoms,
        l10n.videoEditorEffectConfetti,
        l10n.videoEditorEffectMoney,
        l10n.videoEditorEffectStars,
        l10n.videoEditorEffectBalloons,
        l10n.videoEditorEffectHearts,
        l10n.videoEditorEffectBubbles,
        l10n.videoEditorEffectMusicNotes,
        l10n.videoEditorEffectSparkles,
        l10n.videoEditorEffectBokeh,
        l10n.videoEditorEffectFireflies,
        l10n.videoEditorEffectEmbers,
        l10n.videoEditorEffectTiltShift,
        l10n.videoEditorEffectZoomBlur,
        l10n.videoEditorEffectComic,
      ]) {
        await tester.scrollUntilVisible(
          find.text(label),
          50,
          scrollable: find.byType(Scrollable),
        );
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('tapping an effect picks it, tapping "none" clears it', (
      tester,
    ) async {
      await tester.pumpWidget(buildWidget());

      await tester.tap(find.text(l10n.videoEditorEffectVhs));
      expect(cubit.state.selectedType?.builtIn, VideoEffectType.vhs);

      await tester.tap(find.text(l10n.videoEditorEffectNone));
      expect(cubit.state.selectedType, isNull);
    });

    test('draws the tile of every effect Divine renders but the echo with '
        'its shader', () {
      for (final type in EditorEffectType.values) {
        final tile = shaderTileOf(type);
        if (type.builtIn != null || type == EditorEffectType.echo) {
          expect(tile, isNull, reason: type.name);
        } else {
          expect(tile?.asset, startsWith('shaders/'), reason: type.name);
          expect(tile?.values, isNotEmpty, reason: type.name);
        }
      }
      // One shader draws every particle style, told apart by its last value.
      expect(
        [
          EditorEffectType.snow,
          EditorEffectType.confetti,
          EditorEffectType.hearts,
          EditorEffectType.sparkles,
          EditorEffectType.rain,
          EditorEffectType.leaves,
          EditorEffectType.blossoms,
          EditorEffectType.bubbles,
          EditorEffectType.bokeh,
          EditorEffectType.notes,
          EditorEffectType.stars,
          EditorEffectType.fireflies,
          EditorEffectType.embers,
          EditorEffectType.money,
          EditorEffectType.balloons,
        ].map((type) => shaderTileOf(type)!.values.last),
        [for (var style = 0; style < 15; style++) style],
      );
    });

    testWidgets('marks the picked effect as selected for screen readers', (
      tester,
    ) async {
      cubit.selectType(
        const EditorEffectType.builtIn(VideoEffectType.pixelate),
      );
      await tester.pumpWidget(buildWidget());

      expect(
        tester.getSemantics(
          find.bySemanticsLabel(l10n.videoEditorEffectPixelate),
        ),
        matchesSemantics(
          label: l10n.videoEditorEffectPixelate,
          isButton: true,
          isSelected: true,
          hasSelectedState: true,
          hasTapAction: true,
        ),
      );
    });
  });
}
