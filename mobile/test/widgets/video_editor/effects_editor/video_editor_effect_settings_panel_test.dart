import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/effects_editor/video_editor_effects_cubit.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/drops_effect_settings.dart';
import 'package:openvine/models/video_editor/editor_video_effect.dart';
import 'package:openvine/models/video_editor/effect_settings_catalog.dart';
import 'package:openvine/models/video_editor/hit_timing_settings.dart';
import 'package:openvine/widgets/video_editor/effects_editor/video_editor_effect_settings_panel.dart';
import 'package:openvine/widgets/video_editor/video_editor_color_row.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show VideoEffectType;

import '../../../helpers/scroll.dart';
import '../../../helpers/text_lines.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  group(VideoEditorEffectSettingsPanel, () {
    late VideoEditorEffectsCubit cubit;

    setUp(() {
      cubit = VideoEditorEffectsCubit(createSeed: () => 42)..startEditing();
    });

    tearDown(() => cubit.close());

    Widget buildWidget({double height = 320, Locale? locale}) {
      return MaterialApp(
        locale: locale,
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BlocProvider<VideoEditorEffectsCubit>.value(
            value: cubit,
            child: Align(
              alignment: .bottomCenter,
              child: SizedBox(
                height: height,
                child: const VideoEditorEffectSettingsPanel(),
              ),
            ),
          ),
        ),
      );
    }

    Future<void> pumpPanel(WidgetTester tester, EditorEffectType type) async {
      cubit
        ..selectType(type)
        ..setSettingsOpen(open: true);
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();
    }

    group('header', () {
      testWidgets('names the effect, and goes back to the picker', (
        tester,
      ) async {
        await pumpPanel(tester, EditorEffectType.shockwave);

        expect(
          find.text(
            l10n.videoEditorEffectSettingsTitle(
              l10n.videoEditorEffectShockwave,
            ),
          ),
          findsOneWidget,
        );
        await tester.tap(find.bySemanticsLabel(l10n.commonBack));
        await tester.pump();

        expect(cubit.state.isSettingsOpen, isFalse);
      });
    });

    group('on the beat', () {
      testWidgets('shows for an effect that can fire on the beat, and turns '
          'it on', (tester) async {
        await pumpPanel(tester, EditorEffectType.drops);
        expect(find.text(l10n.videoEditorEffectsOnBeat), findsNothing);

        cubit.selectType(
          const EditorEffectType.builtIn(VideoEffectType.zoomPulse),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.videoEditorEffectsOnBeat));
        await tester.pumpAndSettle();

        expect(cubit.state.selectionOnBeat, isTrue);
      });

      testWidgets('says when nothing in the video makes a sound', (
        tester,
      ) async {
        cubit
          ..syncBeatSource(sounds: const [], clips: const [])
          ..setOnBeat(onBeat: true);
        await pumpPanel(
          tester,
          const EditorEffectType.builtIn(VideoEffectType.strobe),
        );

        expect(find.text(l10n.videoEditorEffectsOnBeatNoSound), findsOneWidget);
      });
    });

    group('hit timing', () {
      testWidgets('shows for the effects that hit, starting at their '
          'own timing', (tester) async {
        await pumpPanel(
          tester,
          const EditorEffectType.builtIn(VideoEffectType.zoomPulse),
        );
        expect(find.text(l10n.videoEditorEffectHitDuration), findsNothing);

        cubit.selectType(EditorEffectType.plasma);
        await tester.pumpAndSettle();

        expect(find.text(l10n.videoEditorEffectTimingTitle), findsOneWidget);
        expect(
          tester.getSemantics(
            find.bySemanticsLabel(l10n.videoEditorEffectHitDuration),
          ),
          isSemantics(
            label: l10n.videoEditorEffectHitDuration,
            isSlider: true,
            value: l10n.videoEditorEffectSeconds('0.8'),
          ),
        );
        expect(find.text(l10n.videoEditorEffectHitRepeat), findsOneWidget);
        expect(find.text(l10n.videoEditorEffectHitInterval), findsOneWidget);
      });

      testWidgets('a longer duration slows the hit down, and resetting the '
          'timing puts it back', (tester) async {
        await pumpPanel(tester, EditorEffectType.shockwave);

        await tester.drag(
          find.bySemanticsLabel(l10n.videoEditorEffectHitDuration),
          const Offset(800, 0),
        );
        await tester.pumpAndSettle();

        expect(
          cubit.state.selection?.custom?.params[HitTimingSettings.hitParam],
          HitTimingSettings.maxDuration.inMicroseconds,
        );

        final reset = find.text(l10n.videoEditorEffectTimingReset);
        await scrollUntilTappable(tester, reset, 50);
        await tester.tap(reset);
        await tester.pump();

        expect(
          cubit.state.selectedSettings[HitTimingSettings.hitParam],
          EditorEffectType.shockwave.hitTiming!.duration.inMicroseconds,
        );
      });

      testWidgets('turning repeat off hits once and hides the interval', (
        tester,
      ) async {
        await pumpPanel(tester, EditorEffectType.subwoofer);

        await tester.tap(find.text(l10n.videoEditorEffectHitRepeat));
        await tester.pumpAndSettle();

        expect(
          cubit.state.selectedSettings[HitTimingSettings.repeatParam],
          isFalse,
        );
        expect(find.text(l10n.videoEditorEffectHitOnce), findsOneWidget);
        expect(find.text(l10n.videoEditorEffectHitInterval), findsNothing);
      });

      testWidgets('on the beat, leaves out repeat and the interval', (
        tester,
      ) async {
        cubit.setOnBeat(onBeat: true);
        await pumpPanel(tester, EditorEffectType.shockwave);

        expect(find.text(l10n.videoEditorEffectHitDuration), findsOneWidget);
        expect(find.text(l10n.videoEditorEffectHitRepeat), findsNothing);
        expect(find.text(l10n.videoEditorEffectHitInterval), findsNothing);
      });
    });

    group('hit look', () {
      testWidgets("picks a blast's colour and where it hits", (tester) async {
        await pumpPanel(tester, EditorEffectType.energyWave);
        // The panel scrolls, and so does the colour row in it.
        final panel = find.byType(Scrollable).first;
        final palette = find.descendant(
          of: find.byType(VideoEditorColorRow),
          matching: find.byType(VideoEditorColorTile),
        );
        await scrollUntilTappable(tester, palette.at(1), 50, scrollable: panel);
        await tester.tap(palette.at(1));
        await tester.pumpAndSettle();
        final horizontal = find.bySemanticsLabel(
          l10n.videoEditorEffectHitHorizontal,
        );
        await scrollUntilTappable(tester, horizontal, 50, scrollable: panel);
        await tester.drag(horizontal, const Offset(800, 0));
        await tester.pumpAndSettle();

        final params = cubit.state.selection!.custom!.params;
        expect(params[EffectSettingKeys.centerX], 1);
        expect(
          params[EffectSettingKeys.color],
          VideoEditorConstants.colors.first.toARGB32(),
        );
      });

      testWidgets('offers the subwoofer a size and no colour, zoom punch or '
          'fringes', (tester) async {
        await pumpPanel(tester, EditorEffectType.subwoofer);

        expect(find.byType(VideoEditorColorRow), findsNothing);
        expect(find.text(l10n.videoEditorDropsSizeLabel), findsOneWidget);
        expect(find.text(l10n.videoEditorEffectHitReach), findsNothing);
        expect(find.text(l10n.videoEditorEffectHitPunch), findsNothing);
        expect(find.text(l10n.videoEditorDropsFringesLabel), findsNothing);
      });

      testWidgets('offers the shockwave its fringes, and puts the look back', (
        tester,
      ) async {
        cubit
          ..selectType(EditorEffectType.shockwave)
          ..setSetting(EffectSettingKeys.shake, 2)
          ..setSetting(EffectSettingKeys.fringe, 0);
        await pumpPanel(tester, EditorEffectType.shockwave);
        final reset = find.text(l10n.videoEditorEffectLookReset);

        expect(find.text(l10n.videoEditorDropsFringesLabel), findsOneWidget);
        await scrollUntilTappable(tester, reset, 50);
        await tester.tap(reset);
        await tester.pump();

        expect(cubit.state.settingValues, isEmpty);
      });
    });

    group('choices', () {
      testWidgets('turn the swirl the other way', (tester) async {
        await pumpPanel(tester, EditorEffectType.swirl);
        final anticlockwise = find.text(
          l10n.videoEditorEffectSettingAnticlockwise,
        );

        await scrollUntilTappable(tester, anticlockwise, 50);
        await tester.tap(anticlockwise);
        await tester.pump();

        expect(
          cubit.state.selection?.custom?.params[EffectSettingKeys.direction],
          -1,
        );
        expect(
          tester.getSemantics(
            find.bySemanticsLabel(
              '${l10n.videoEditorEffectSettingDirection}: '
              '${l10n.videoEditorEffectSettingAnticlockwise}',
            ),
          ),
          isSemantics(isSelected: true, isButton: true),
        );
      });
    });

    group('movement', () {
      testWidgets('offers a tunnel its speed, except on the beat, and which '
          'way it zooms', (tester) async {
        await pumpPanel(tester, EditorEffectType.tunnel);
        expect(find.text(l10n.videoEditorEffectMotionTitle), findsOneWidget);
        expect(find.text(l10n.videoEditorDropsSpeedLabel), findsOneWidget);

        cubit.setOnBeat(onBeat: true);
        await tester.pumpAndSettle();

        expect(find.text(l10n.videoEditorDropsSpeedLabel), findsNothing);
        expect(find.text(l10n.videoEditorEffectSettingZoomOut), findsOneWidget);
      });
    });

    group('angles', () {
      testWidgets('read out in degrees', (tester) async {
        final semantics = tester.ensureSemantics();
        await pumpPanel(tester, EditorEffectType.flutedGlass);
        final angle = find.bySemanticsLabel(l10n.videoEditorEffectSettingAngle);

        await scrollUntilTappable(tester, angle, 50);
        await tester.drag(angle, const Offset(800, 0));
        await tester.pumpAndSettle();

        expect(
          tester.getSemantics(angle),
          isSemantics(
            label: l10n.videoEditorEffectSettingAngle,
            isSlider: true,
            value: '180°',
          ),
        );
        expect(cubit.state.selectedSettings[EffectSettingKeys.angle], 180.0);
        semantics.dispose();
      });
    });

    group('drops', () {
      testWidgets('sliders change the drops', (tester) async {
        final semantics = tester.ensureSemantics();
        await pumpPanel(tester, EditorEffectType.drops);
        // A count, not a share of the range.
        expect(
          tester.getSemantics(
            find.bySemanticsLabel(l10n.videoEditorDropsCountLabel),
          ),
          isSemantics(
            label: l10n.videoEditorDropsCountLabel,
            isSlider: true,
            value: '${DropsEffectSettings.defaultCount}',
          ),
        );

        await tester.drag(
          find.bySemanticsLabel(l10n.videoEditorDropsCountLabel),
          const Offset(800, 0),
        );
        await tester.pumpAndSettle();

        expect(
          DropsEffectSettings.fromParams(cubit.state.selectedSettings),
          const DropsEffectSettings(count: DropsEffectSettings.maxCount),
        );
        semantics.dispose();
      });

      testWidgets('shuffle gives the drops a new arrangement', (tester) async {
        await pumpPanel(tester, EditorEffectType.drops);
        final shuffle = find.text(l10n.videoEditorDropsShuffle);

        await scrollUntilTappable(tester, shuffle, 50);
        await tester.tap(shuffle);
        await tester.pump();

        expect(
          cubit.state.selectedSettings[DropsEffectSettings.seedParam],
          42,
        );
      });

      testWidgets('keeps its labels whole at a large text size', (
        tester,
      ) async {
        final de = lookupAppLocalizations(const Locale('de'));
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearAllTestValues);
        cubit
          ..selectType(EditorEffectType.drops)
          ..setSettingsOpen(open: true);
        await tester.pumpWidget(buildWidget(locale: const Locale('de')));
        await tester.pumpAndSettle();

        final fringes = find.text(de.videoEditorDropsFringesLabel);
        await scrollUntilTappable(tester, fringes, 50);

        expect(wordsSplitAcrossLines(tester, fringes), isEmpty);
        expect(tester.takeException(), isNull);
      });
    });
  });
}
