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
