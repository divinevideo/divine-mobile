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
      cubit = VideoEditorEffectsCubit(createId: () => 'effect-1')
        ..startEditing();
    });

    tearDown(() => cubit.close());

    Widget buildWidget() {
      return MaterialApp(
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
              child: const SizedBox(
                width: 400,
                height: 600,
                child: VideoEditorEffectsOverlayControls(),
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
    });

    group('on the beat switch', () {
      testWidgets('shows for an effect that can fire on the beat, and turns '
          'it on', (tester) async {
        cubit.selectType(const EditorEffectType.builtIn(VideoEffectType.vhs));
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();
        expect(find.text(l10n.videoEditorEffectsOnBeat), findsNothing);

        cubit.selectType(
          const EditorEffectType.builtIn(VideoEffectType.zoomPulse),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.videoEditorEffectsOnBeat));
        await tester.pumpAndSettle();

        expect(cubit.state.onBeat, isTrue);
      });

      testWidgets('says when nothing in the video makes a sound', (
        tester,
      ) async {
        cubit
          ..syncBeatSource(sounds: const [], clips: const [])
          ..selectType(const EditorEffectType.builtIn(VideoEffectType.strobe))
          ..setOnBeat(onBeat: true);
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(find.text(l10n.videoEditorEffectsOnBeatNoSound), findsOneWidget);
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
