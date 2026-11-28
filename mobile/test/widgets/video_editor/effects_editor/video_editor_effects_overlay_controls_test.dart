import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_editor/effects_editor/video_editor_effects_cubit.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/editor_video_effect.dart';
import 'package:openvine/widgets/video_editor/effects_editor/video_editor_effects_overlay_controls.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/video_editor_vertical_slider.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:pro_video_editor/pro_video_editor.dart'
    show VideoEffect, VideoEffectType;

class _MockVideoEditorMainBloc
    extends MockBloc<VideoEditorMainEvent, VideoEditorMainState>
    implements VideoEditorMainBloc {}

class _MockProImageEditorState extends Mock implements ProImageEditorState {
  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) =>
      '_MockProImageEditorState';
}

class _MockStateManager extends Mock implements StateManager {}

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  final closeLabel = l10n.videoEditorDiscardToolChangesSemanticLabel(
    l10n.videoEditorEffectsLabel,
  );
  final doneLabel = l10n.videoEditorApplyToolChangesSemanticLabel(
    l10n.videoEditorEffectsLabel,
  );

  setUpAll(() {
    registerFallbackValue(const VideoEditorMainSubEditorClosed());
  });

  group(VideoEditorEffectsOverlayControls, () {
    late _MockVideoEditorMainBloc mainBloc;
    late _MockProImageEditorState editor;
    late VideoEditorEffectsCubit cubit;

    setUp(() {
      mainBloc = _MockVideoEditorMainBloc();
      when(() => mainBloc.state).thenReturn(const VideoEditorMainState());
      editor = _MockProImageEditorState();
      final stateManager = _MockStateManager();
      when(() => editor.stateManager).thenReturn(stateManager);
      when(() => stateManager.activeMeta).thenReturn({});
      when(() => editor.addHistory(meta: any(named: 'meta'))).thenReturn(null);
      when(() => editor.setState(any())).thenAnswer((invocation) {
        (invocation.positionalArguments.single as VoidCallback)();
      });
      cubit = VideoEditorEffectsCubit(
        createId: () => 'effect-1',
        createSeed: () => 42,
      )..startEditing();
    });

    tearDown(() => cubit.close());

    Widget buildWidget({
      double height = 600,
      double width = 400,
      Locale? locale,
    }) {
      return MaterialApp(
        locale: locale,
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: VideoEditorScope(
            editorKey: GlobalKey<ProImageEditorState>(),
            editorOverride: editor,
            removeAreaKey: GlobalKey(),
            originalClipAspectRatio: 9 / 16,
            bodySizeNotifier: ValueNotifier(const Size(400, 600)),
            zoomMatrixNotifier: ValueNotifier(Matrix4.identity()),
            playTimeNotifier: ValueNotifier(Duration.zero),
            playheadAdvancingNotifier: ValueNotifier<bool>(false),
            fromLibrary: false,
            onOpenCamera: () {},
            onOpenClipsEditor: () {},
            onAddStickers: () {},
            onOpenMusicLibrary: () {},
            onOpenVoiceOver: () {},
            onOpenCaptions: () {},
            onOpenEffects: () {},
            onAddEditTextLayer: ([layer]) async => null,
            child: MultiBlocProvider(
              providers: [
                BlocProvider<VideoEditorEffectsCubit>.value(value: cubit),
                BlocProvider<VideoEditorMainBloc>.value(value: mainBloc),
              ],
              child: SizedBox(
                width: width,
                height: height,
                child: const VideoEditorEffectsOverlayControls(),
              ),
            ),
          ),
        ),
      );
    }

    group('intensity slider', () {
      testWidgets('is hidden while no effect is picked', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(find.byType(VideoEditorVerticalSlider), findsNothing);
      });

      testWidgets('shows the intensity of the picked effect', (tester) async {
        cubit
          ..selectType(const EditorEffectType.builtIn(VideoEffectType.vhs))
          ..setIntensity(0.35);
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        final slider = tester.widget<VideoEditorVerticalSlider>(
          find.byType(VideoEditorVerticalSlider),
        );
        expect(slider.value, 0.35);
      });

      testWidgets('stays below the toolbar over a short preview', (
        tester,
      ) async {
        cubit.selectType(const EditorEffectType.builtIn(VideoEffectType.vhs));
        // The preview left above the effects picker on a phone.
        await tester.pumpWidget(buildWidget(height: 380));
        await tester.pumpAndSettle();

        expect(
          tester.getRect(find.byType(VideoEditorVerticalSlider)).top,
          greaterThanOrEqualTo(
            tester.getRect(find.bySemanticsLabel(doneLabel)).bottom,
          ),
        );
      });
    });

    group('picking an intro or outro', () {
      setUp(() {
        cubit.emit(
          cubit.state.copyWith(timelineEnd: const Duration(seconds: 6)),
        );
      });

      testWidgets('moves the playing video to a second before the outro', (
        tester,
      ) async {
        when(
          () => mainBloc.state,
        ).thenReturn(const VideoEditorMainState(isPlaying: true));
        await tester.pumpWidget(buildWidget());

        cubit.selectType(EditorEffectType.outroCurtain);
        await tester.pump();

        verify(
          () => mainBloc.add(
            const VideoEditorSeekRequested(Duration(seconds: 4)),
          ),
        ).called(1);
      });

      testWidgets('moves the paused video into the middle of the intro', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget());

        cubit.selectType(EditorEffectType.introCircle);
        await tester.pump();

        verify(
          () => mainBloc.add(
            const VideoEditorSeekRequested(Duration(milliseconds: 500)),
          ),
        ).called(1);
      });

      testWidgets('leaves the playhead where it is for an effect over the '
          'whole video', (tester) async {
        await tester.pumpWidget(buildWidget());

        cubit.selectType(EditorEffectType.snow);
        await tester.pump();

        verifyNever(
          () => mainBloc.add(any(that: isA<VideoEditorSeekRequested>())),
        );
      });
    });

    group('slider of an intro or outro', () {
      String? sliderLabel(WidgetTester tester) => tester
          .widget<VideoEditorVerticalSlider>(
            find.byType(VideoEditorVerticalSlider),
          )
          .semanticLabel;

      testWidgets('names the structure it changes for each look', (
        tester,
      ) async {
        final labels = {
          EditorEffectType.introFade: l10n.videoEditorEffectShapeFadeColor,
          EditorEffectType.outroCircle:
              l10n.videoEditorEffectShapeCircleSoftness,
          EditorEffectType.introCinema: l10n.videoEditorEffectShapeCinemaBars,
          EditorEffectType.outroCurtain:
              l10n.videoEditorEffectShapeCurtainFolds,
          EditorEffectType.introFocus: l10n.videoEditorEffectShapeFocusBlur,
        };
        await tester.pumpWidget(buildWidget());
        for (final MapEntry(key: type, value: label) in labels.entries) {
          cubit.selectType(type);
          await tester.pumpAndSettle();

          expect(sliderLabel(tester), label);
        }

        // Any other effect keeps the slider's own label.
        cubit.selectType(EditorEffectType.snow);
        await tester.pumpAndSettle();
        expect(sliderLabel(tester), isNull);
      });
    });

    group('settings button', () {
      final settingsLabel = l10n.videoEditorEffectSettingsOpen;

      testWidgets('shows only for an effect with settings', (tester) async {
        cubit.selectType(EditorEffectType.tealOrange);
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();
        expect(find.bySemanticsLabel(settingsLabel), findsNothing);

        for (final type in [
          const EditorEffectType.builtIn(VideoEffectType.zoomPulse),
          EditorEffectType.shockwave,
          EditorEffectType.plasma,
          EditorEffectType.drops,
        ]) {
          cubit.selectType(type);
          await tester.pumpAndSettle();
          expect(
            find.bySemanticsLabel(settingsLabel),
            findsOneWidget,
            reason: type.name,
          );
        }
      });

      testWidgets('opens the settings, and closes them again', (tester) async {
        cubit.selectType(EditorEffectType.shockwave);
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.bySemanticsLabel(settingsLabel));
        await tester.pumpAndSettle();
        expect(cubit.state.showsSettings, isTrue);

        await tester.tap(find.bySemanticsLabel(settingsLabel));
        await tester.pumpAndSettle();
        expect(cubit.state.showsSettings, isFalse);
      });

      testWidgets('sits on the right just above the bar under the preview, '
          'clear of the slider', (tester) async {
        cubit.selectType(EditorEffectType.plasma);
        await tester.pumpWidget(buildWidget(height: 380));
        await tester.pumpAndSettle();

        final slider = tester.getRect(find.byType(VideoEditorVerticalSlider));
        final button = tester.getRect(find.bySemanticsLabel(settingsLabel));
        final controls = tester.getRect(
          find.byType(VideoEditorEffectsOverlayControls),
        );
        expect(button.top, greaterThan(slider.bottom));
        expect(controls.bottom - button.bottom, inInclusiveRange(8, 24));
        expect(controls.right - button.right, lessThanOrEqualTo(24));
        expect(tester.takeException(), isNull);
      });
    });

    group('at a large text size', () {
      // The preview left above the effects picker on a small phone, which
      // gets shorter as the picker grows with the text.
      Future<void> pumpAt(
        WidgetTester tester, {
        required double textScale,
        required double width,
        required double height,
        Locale locale = const Locale('en'),
      }) async {
        tester.platformDispatcher.textScaleFactorTestValue = textScale;
        addTearDown(tester.platformDispatcher.clearAllTestValues);
        await tester.pumpWidget(
          buildWidget(width: width, height: height, locale: locale),
        );
        await tester.pumpAndSettle();
      }

      testWidgets('lays the preview notice over the preview, beside the '
          'slider', (tester) async {
        cubit.selectType(const EditorEffectType.builtIn(VideoEffectType.vhs));

        await pumpAt(tester, textScale: 1.5, width: 360, height: 300);

        // flutter_test cannot preview effects, so the notice always shows.
        final notice = tester.getRect(
          find.text(l10n.videoEditorChromaKeyPreviewUnavailable),
        );
        final slider = tester.getRect(find.byType(VideoEditorVerticalSlider));
        expect(slider.top, lessThan(notice.bottom));
        expect(slider.left, greaterThanOrEqualTo(notice.right));
      });
    });

    group('toolbar', () {
      testWidgets('done commits the picked effect as one history entry and '
          'closes the editor', (tester) async {
        cubit
          ..selectType(const EditorEffectType.builtIn(VideoEffectType.glitch))
          ..setIntensity(0.5);
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.bySemanticsLabel(doneLabel));
        await tester.pump();

        final meta =
            verify(
                  () => editor.addHistory(meta: captureAny(named: 'meta')),
                ).captured.single
                as Map<String, dynamic>;
        expect(meta[VideoEditorConstants.effectsStateHistoryKey], [
          {
            'type': 'glitch',
            'intensity': 0.5,
            'startTime': null,
            'endTime': null,
            'id': 'effect-1',
          },
        ]);
        verify(
          () => mainBloc.add(const VideoEditorMainSubEditorClosed()),
        ).called(1);
        expect(cubit.state.isEditing, isFalse);
      });

      testWidgets('done explains when a flashing effect replaced another', (
        tester,
      ) async {
        cubit
          ..syncApplied(const [
            EditorVideoEffect(
              id: 'negative',
              effect: VideoEffect.negativeFlash(),
            ),
          ])
          ..selectType(const EditorEffectType.builtIn(VideoEffectType.strobe));
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.bySemanticsLabel(doneLabel));
        await tester.pump();

        expect(
          find.text(l10n.videoEditorEffectsFlashingReplaced),
          findsOneWidget,
        );
      });

      testWidgets('close discards the pick without touching the history', (
        tester,
      ) async {
        cubit.selectType(
          const EditorEffectType.builtIn(VideoEffectType.pixelate),
        );
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.bySemanticsLabel(closeLabel));
        await tester.pump();

        verifyNever(() => editor.addHistory(meta: any(named: 'meta')));
        verify(
          () => mainBloc.add(const VideoEditorMainSubEditorClosed()),
        ).called(1);
        expect(cubit.state.isEditing, isFalse);
        expect(cubit.state.previewEffects, isEmpty);
      });
    });
  });
}
