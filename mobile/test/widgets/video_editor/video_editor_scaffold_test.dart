// ABOUTME: Widget tests for VideoEditorScaffold.
// ABOUTME: Verifies loading UI and editing-tools visibility rules.

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/blocs/video_editor/effects_editor/video_editor_effects_cubit.dart';
import 'package:openvine/blocs/video_editor/filter_editor/video_editor_filter_bloc.dart';
import 'package:openvine/blocs/video_editor/layer_tracking/layer_tracking_cubit.dart';
import 'package:openvine/blocs/video_editor/loop_suggestion/loop_suggestion_cubit.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/blocs/video_editor/style_clipboard/style_clipboard_cubit.dart';
import 'package:openvine/blocs/video_editor/text_wrap_hint/text_wrap_hint_cubit.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/clip_chroma_key.dart';
import 'package:openvine/models/video_editor/detached_clip_layer.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/widgets/branded_loading_scaffold.dart';
import 'package:openvine/widgets/video_editor/effects_editor/open_effects_editor.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_main_overlay_actions.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/mask_editor/video_editor_mask_editor_view.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/video_editor_timeline.dart';
import 'package:openvine/widgets/video_editor/video_editor_scaffold.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:pro_video_editor/pro_video_editor.dart'
    show ChromaKey, EditorVideo;
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/video_editor/loop_repair.dart';

class _MockClipEditorBloc extends MockBloc<ClipEditorEvent, ClipEditorState>
    implements ClipEditorBloc {}

class _MockProImageEditorState extends Mock implements ProImageEditorState {
  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) =>
      '_MockProImageEditorState';
}

class _MockStateManager extends Mock implements StateManager {}

class _MockLoopSuggestionCubit extends MockCubit<LoopSuggestionState>
    implements LoopSuggestionCubit {}

class _FakeLayer extends Fake implements Layer {}

DivineVideoClip _detachedClip({String file = 'clip-1.mp4'}) => DivineVideoClip(
  id: 'clip-1',
  video: EditorVideo.file('/docs/$file'),
  duration: const Duration(seconds: 6),
  recordedAt: DateTime(2026),
  targetAspectRatio: .square,
  originalAspectRatio: 1,
);

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  group(VideoEditorScaffold, () {
    late VideoEditorMainBloc mainBloc;
    late TimelineOverlayBloc overlayBloc;
    late ClipEditorBloc clipBloc;
    late VideoEditorFilterBloc filterBloc;
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      mainBloc = VideoEditorMainBloc();
      overlayBloc = TimelineOverlayBloc();
      clipBloc = ClipEditorBloc(
        onFinalClipInvalidated: () {},
        saveClipToLibrary: ({required clip}) async => false,
      );
      filterBloc = VideoEditorFilterBloc();
    });

    tearDown(() async {
      await mainBloc.close();
      await overlayBloc.close();
      await clipBloc.close();
      await filterBloc.close();
    });

    Widget buildWidget({
      required bool isLoading,
      VideoEditorMainBloc? mainBlocOverride,
      ClipEditorBloc? clipBlocOverride,
      ProImageEditorState? editorOverride,
      VideoEditorEffectsCubit? effectsCubit,
      LoopSuggestionCubit? loopSuggestionCubit,
      ValueNotifier<double>? maskPanelHeight,
      ThemeData? theme,
    }) {
      final editorKey = GlobalKey<ProImageEditorState>();
      final removeAreaKey = GlobalKey();

      return ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: VideoEditorScope(
          editorKey: editorKey,
          editorOverride: editorOverride,
          removeAreaKey: removeAreaKey,
          onOpenCamera: () {},
          onAddStickers: () {},
          onOpenClipsEditor: () {},
          onAddEditTextLayer: ([layer]) async => null,
          onOpenMusicLibrary: () {},
          onOpenVoiceOver: () {},
          onOpenCaptions: () {},
          onOpenEffects: () {},
          originalClipAspectRatio: 9 / 16,
          bodySizeNotifier: ValueNotifier(const Size(400, 800)),
          zoomMatrixNotifier: ValueNotifier(Matrix4.identity()),
          playTimeNotifier: ValueNotifier(Duration.zero),
          playheadAdvancingNotifier: ValueNotifier<bool>(false),
          canvasToolPanelHeightNotifier: maskPanelHeight,
          fromLibrary: false,
          child: MultiBlocProvider(
            providers: [
              BlocProvider<VideoEditorMainBloc>.value(
                value: mainBlocOverride ?? mainBloc,
              ),
              BlocProvider<TimelineOverlayBloc>.value(value: overlayBloc),
              BlocProvider<ClipEditorBloc>.value(
                value: clipBlocOverride ?? clipBloc,
              ),
              BlocProvider<VideoEditorFilterBloc>.value(value: filterBloc),
              BlocProvider<LayerTrackingCubit>(
                create: (_) => LayerTrackingCubit(),
              ),
              BlocProvider(create: (_) => StyleClipboardCubit()),
              BlocProvider(create: (_) => TextWrapHintCubit()),
              if (loopSuggestionCubit != null)
                BlocProvider<LoopSuggestionCubit>.value(
                  value: loopSuggestionCubit,
                )
              else
                BlocProvider(
                  create: (_) =>
                      LoopSuggestionCubit(repository: noMatchLoopRepository()),
                ),
              if (effectsCubit != null)
                BlocProvider<VideoEditorEffectsCubit>.value(
                  value: effectsCubit,
                ),
            ],
            child: MaterialApp(
              theme: theme,
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: VideoEditorScaffold(isLoading: isLoading),
            ),
          ),
        ),
      );
    }

    testWidgets('shows loading scaffold when isLoading is true', (
      tester,
    ) async {
      await tester.pumpWidget(buildWidget(isLoading: true));

      expect(find.byType(BrandedLoadingScaffold), findsOneWidget);
      expect(find.text(l10n.videoActionEdit), findsOneWidget);
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.bottomNavigationBar, isNotNull);
      expect(scaffold.floatingActionButton, isNull);
      expect(
        find.bySemanticsLabel(l10n.videoActionEdit),
        findsOneWidget,
      );
    });

    testWidgets('editing-tools glyph follows the palette on light', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildWidget(isLoading: true, theme: VineTheme.lightTheme),
      );
      // Not pumpAndSettle: the loading scaffold animates forever. A fresh
      // tree resolves its theme on the first frame anyway.
      await tester.pump();

      final icon = tester.widget<DivineIcon>(
        find.descendant(
          of: find.bySemanticsLabel(l10n.videoActionEdit),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is DivineIcon &&
                widget.icon == DivineIconName.slidersHorizontal,
          ),
        ),
      );

      expect(icon.color, VineTheme.lightColors.onSurfaceVariant);
      expect(icon.color, isNot(VineTheme.primary));
    });

    testWidgets('editing-tools glyph follows the palette on dark', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildWidget(isLoading: true, theme: VineTheme.theme),
      );
      await tester.pump();

      final icon = tester.widget<DivineIcon>(
        find.descendant(
          of: find.bySemanticsLabel(l10n.videoActionEdit),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is DivineIcon &&
                widget.icon == DivineIconName.slidersHorizontal,
          ),
        ),
      );

      expect(icon.color, VineTheme.darkColors.onSurfaceVariant);
    });

    testWidgets('hides editing tools while a sub-editor is open', (
      tester,
    ) async {
      mainBloc.add(const VideoEditorMainOpenSubEditor(SubEditorType.text));

      await tester.pumpWidget(buildWidget(isLoading: true));
      await tester.pump();

      expect(
        find.bySemanticsLabel(l10n.videoActionEdit),
        findsNothing,
      );
    });

    testWidgets('restores the body safe area when editing tools hide', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.padding = const FakeViewPadding(bottom: 34);
      tester.view.viewPadding = const FakeViewPadding(bottom: 34);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewPadding);
      final mainBloc = VideoEditorMainBloc();
      addTearDown(mainBloc.close);

      await tester.pumpWidget(
        buildWidget(isLoading: true, mainBlocOverride: mainBloc),
      );
      final timelineContext = tester.element(
        find.byType(VideoEditorTimelineScaffold),
      );
      // The visible tools bar owns the inset instead of the body.
      expect(MediaQuery.paddingOf(timelineContext).bottom, 0);
      expect(find.text(l10n.videoActionEdit), findsOneWidget);

      mainBloc.add(const VideoEditorMainOpenSubEditor(SubEditorType.text));
      await tester.pump();

      expect(find.text(l10n.videoActionEdit), findsNothing);
      // Hidden tools must leave the inset available to editor controls.
      expect(MediaQuery.paddingOf(timelineContext).bottom, 34);
      expect(MediaQuery.viewPaddingOf(timelineContext).bottom, 34);
    });

    testWidgets(
      'collapses the timeline and its own controls under the voice-over '
      'recorder',
      (tester) async {
        // Created inside the test so its state stream runs in the test's own
        // zone; a bloc from setUp delivers its states on the real event loop,
        // which a pump never turns.
        final mainBloc = VideoEditorMainBloc();
        addTearDown(mainBloc.close);
        SizeTransition collapseSection() => tester.widget<SizeTransition>(
          find
              .ancestor(
                of: find.byType(VideoEditorTimelineScaffold),
                matching: find.byType(SizeTransition),
              )
              .last,
        );

        await tester.pumpWidget(
          buildWidget(isLoading: true, mainBlocOverride: mainBloc),
        );
        await tester.pump();

        expect(find.byType(VideoEditorMainOverlayActions), findsOneWidget);
        expect(collapseSection().sizeFactor.value, 1);

        mainBloc.add(
          const VideoEditorMainOpenSubEditor(SubEditorType.voiceOver),
        );
        // The loading scaffold spins forever, so settle the 240ms switch
        // animation by hand.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // The recorder brings its own toolbar over the preview, and the
        // section collapses whole so the video fills the screen behind it.
        expect(find.byType(VideoEditorMainOverlayActions), findsNothing);
        expect(collapseSection().sizeFactor.value, 0);

        mainBloc.add(const VideoEditorMainSubEditorClosed());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(VideoEditorMainOverlayActions), findsOneWidget);
        expect(collapseSection().sizeFactor.value, 1);
      },
    );

    testWidgets(
      'keeps the canvas above the mask editor panel while a mask is edited',
      (tester) async {
        // Created inside the test, as in the voice-over test above.
        final mainBloc = VideoEditorMainBloc();
        addTearDown(mainBloc.close);
        final panelHeight = ValueNotifier(videoEditorMaskPanelHeight(null));
        addTearDown(panelHeight.dispose);

        await tester.pumpWidget(
          buildWidget(
            isLoading: true,
            mainBlocOverride: mainBloc,
            maskPanelHeight: panelHeight,
          ),
        );
        await tester.pump();

        mainBloc.add(const VideoEditorMaskEditingChanged(isEditing: true));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // The timeline steps aside, and the canvas ends where the panel the
        // mask editor draws over this space begins, so a shape dragged down
        // can never slip under it.
        expect(find.byType(VideoEditorMainOverlayActions), findsNothing);
        final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
        double canvasBottom() =>
            tester.getRect(find.byType(BrandedLoadingScaffold)).bottom;
        expect(canvasBottom(), screen.height - panelHeight.value);

        // A rectangle brings two sliders, and the canvas makes room for them.
        panelHeight.value = videoEditorMaskPanelHeight(
          const LayerMask(shape: LayerMaskShape.rectangle),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(canvasBottom(), screen.height - panelHeight.value);

        mainBloc.add(const VideoEditorMaskEditingChanged(isEditing: false));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(VideoEditorMainOverlayActions), findsOneWidget);
      },
    );

    testWidgets(
      'pauses the video again when the effects editor closes after '
      'starting it',
      (tester) async {
        final mainBloc = VideoEditorMainBloc();
        addTearDown(mainBloc.close);
        final effectsCubit = VideoEditorEffectsCubit();
        addTearDown(effectsCubit.close);

        await tester.pumpWidget(
          buildWidget(
            isLoading: true,
            mainBlocOverride: mainBloc,
            effectsCubit: effectsCubit,
          ),
        );
        await tester.pump();

        openEffectsEditor(mainBloc, effectsCubit, reduceMotion: false);
        mainBloc.add(const VideoEditorPlaybackChanged(isPlaying: true));
        await tester.pump();
        expect(mainBloc.state.playbackToggleCounter, 1);

        mainBloc.add(const VideoEditorMainSubEditorClosed());
        await tester.pump();

        // The second toggle pauses the video the editor started.
        expect(mainBloc.state.playbackToggleCounter, 2);
      },
    );

    testWidgets('hides editing tools while a loop repair runs', (
      tester,
    ) async {
      final loopSuggestionCubit = _MockLoopSuggestionCubit();
      whenListen(
        loopSuggestionCubit,
        const Stream<LoopSuggestionState>.empty(),
        initialState: const LoopSuggestionState(
          status: LoopSuggestionStatus.searching,
        ),
      );

      await tester.pumpWidget(
        buildWidget(isLoading: true, loopSuggestionCubit: loopSuggestionCubit),
      );
      await tester.pump();

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(
        find.bySemanticsLabel(l10n.videoActionEdit),
        findsNothing,
      );
    });

    testWidgets('hides editing tools when an overlay item is selected', (
      tester,
    ) async {
      overlayBloc.add(const TimelineOverlayItemSelected('overlay-1'));

      await tester.pumpWidget(buildWidget(isLoading: true));
      await tester.pump();

      expect(
        find.bySemanticsLabel(l10n.videoActionEdit),
        findsNothing,
      );
    });

    testWidgets('hides editing tools during draw-layer multi-select', (
      tester,
    ) async {
      overlayBloc.add(const TimelineOverlayLayerMultiSelectStarted('draw-1'));

      await tester.pumpWidget(buildWidget(isLoading: true));
      await tester.pump();

      expect(
        find.bySemanticsLabel(l10n.videoActionEdit),
        findsNothing,
      );
    });

    testWidgets(
      'shows reverse progress overlay while clip reverse is running',
      (
        tester,
      ) async {
        final clipBloc = _MockClipEditorBloc();
        const reversingState = ClipEditorState(
          isReversing: true,
          reversingClipId: 'clip-1',
        );

        when(() => clipBloc.state).thenReturn(reversingState);
        whenListen(
          clipBloc,
          const Stream<ClipEditorState>.empty(),
          initialState: reversingState,
        );

        await tester.pumpWidget(
          buildWidget(isLoading: false, clipBlocOverride: clipBloc),
        );

        expect(find.byType(PartialCircleSpinner), findsOneWidget);
      },
    );

    testWidgets(
      'hides the editing tools from screen readers while clips import',
      (tester) async {
        final clipBloc = _MockClipEditorBloc();
        whenListen(
          clipBloc,
          Stream.value(
            const ClipEditorState(
              isImportingLibraryClips: true,
              libraryImportRenderId: 'library_import',
              libraryImportProgress: 0.5,
            ),
          ),
          initialState: const ClipEditorState(),
        );

        await tester.pumpWidget(
          buildWidget(isLoading: true, clipBlocOverride: clipBloc),
        );
        expect(find.semantics.byLabel(l10n.videoActionEdit), findsOne);

        await tester.pump();

        expect(find.semantics.byLabel(l10n.videoActionEdit), findsNothing);
      },
    );

    testWidgets(
      'writes history on extraction success even when handled above clip controls',
      (tester) async {
        final clipBloc = _MockClipEditorBloc();
        final mockEditor = _MockProImageEditorState();
        final mockStateManager = _MockStateManager();
        final audioEvent = AudioEvent(
          id: 'audio-1',
          pubkey: '',
          createdAt: 1,
          url: '/tmp/audio.wav',
          mimeType: 'audio/wav',
          sha256: 'abc123',
          fileSize: 123,
          duration: 1,
          title: 'Test',
        );
        final successState = ClipEditorState(
          lastAudioExtraction: ClipAudioExtractionSuccess(
            audioEvent: audioEvent,
          ),
        );

        when(() => clipBloc.state).thenReturn(const ClipEditorState());
        whenListen(
          clipBloc,
          Stream<ClipEditorState>.fromIterable([successState]),
          initialState: const ClipEditorState(),
        );
        when(() => mockEditor.stateManager).thenReturn(mockStateManager);
        when(() => mockStateManager.activeMeta).thenReturn({
          VideoEditorConstants.timelineMarkersStateHistoryKey: [1250],
        });
        when(
          () => mockEditor.addHistory(
            layers: any(named: 'layers'),
            filters: any(named: 'filters'),
            meta: any(named: 'meta'),
            newLayer: any(named: 'newLayer'),
            transformConfigs: any(named: 'transformConfigs'),
            tuneAdjustments: any(named: 'tuneAdjustments'),
            blur: any(named: 'blur'),
            heroScreenshotRequired: any(named: 'heroScreenshotRequired'),
            blockCaptureScreenshot: any(named: 'blockCaptureScreenshot'),
          ),
        ).thenAnswer((_) {});

        await tester.pumpWidget(
          buildWidget(
            isLoading: true,
            clipBlocOverride: clipBloc,
            editorOverride: mockEditor,
          ),
        );
        await tester.pump();

        final captured =
            verify(
                  () => mockEditor.addHistory(meta: captureAny(named: 'meta')),
                ).captured.single
                as Map<String, dynamic>;
        expect(
          captured[VideoEditorConstants.clipsStateHistoryKey],
          equals(<Map<String, dynamic>>[]),
        );
        expect(
          captured[VideoEditorConstants.audioStateHistoryKey],
          equals([audioEvent.toJson()]),
        );
        expect(
          captured[VideoEditorConstants.timelineMarkersStateHistoryKey],
          equals([1250]),
        );
      },
    );

    testWidgets('shows a snackbar when a clip reverse render fails', (
      tester,
    ) async {
      final clipBloc = _MockClipEditorBloc();
      final failureState = ClipEditorState(
        lastReverseResult: ClipReverseFailure(),
      );

      when(() => clipBloc.state).thenReturn(const ClipEditorState());
      whenListen(
        clipBloc,
        Stream<ClipEditorState>.fromIterable([failureState]),
        initialState: const ClipEditorState(),
      );

      await tester.pumpWidget(
        buildWidget(isLoading: true, clipBlocOverride: clipBloc),
      );
      await tester.pump();

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.videoEditorReverseFailed), findsOneWidget);
    });

    testWidgets(
      'shows a snackbar when a clip reverse has no local file',
      (tester) async {
        final clipBloc = _MockClipEditorBloc();
        final noFileState = ClipEditorState(
          lastReverseResult: ClipReverseNoLocalFile(),
        );

        when(() => clipBloc.state).thenReturn(const ClipEditorState());
        whenListen(
          clipBloc,
          Stream<ClipEditorState>.fromIterable([noFileState]),
          initialState: const ClipEditorState(),
        );

        await tester.pumpWidget(
          buildWidget(isLoading: true, clipBlocOverride: clipBloc),
        );
        await tester.pump();

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.text(l10n.videoEditorReverseNoLocalFile), findsOneWidget);
      },
    );

    testWidgets(
      'ignores discarded reverse results without a snackbar',
      (tester) async {
        final clipBloc = _MockClipEditorBloc();
        final discardedState = ClipEditorState(
          lastReverseResult: ClipReverseDiscarded(),
        );

        when(() => clipBloc.state).thenReturn(const ClipEditorState());
        whenListen(
          clipBloc,
          Stream<ClipEditorState>.fromIterable([discardedState]),
          initialState: const ClipEditorState(),
        );

        await tester.pumpWidget(
          buildWidget(isLoading: true, clipBlocOverride: clipBloc),
        );
        await tester.pump();

        expect(find.byType(SnackBar), findsNothing);
      },
    );

    testWidgets('shows a snackbar when a clip is saved to the library', (
      tester,
    ) async {
      final clipBloc = _MockClipEditorBloc();
      final successState = ClipEditorState(
        lastClipLibrarySave: ClipLibrarySaveSuccess(),
      );

      when(() => clipBloc.state).thenReturn(const ClipEditorState());
      whenListen(
        clipBloc,
        Stream<ClipEditorState>.fromIterable([successState]),
        initialState: const ClipEditorState(),
      );

      await tester.pumpWidget(
        buildWidget(isLoading: true, clipBlocOverride: clipBloc),
      );
      await tester.pump();

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.videoEditorClipSavedSuccess), findsOneWidget);
    });

    testWidgets('shows a snackbar when a clip library save fails', (
      tester,
    ) async {
      final clipBloc = _MockClipEditorBloc();
      final failureState = ClipEditorState(
        lastClipLibrarySave: ClipLibrarySaveFailure(),
      );

      when(() => clipBloc.state).thenReturn(const ClipEditorState());
      whenListen(
        clipBloc,
        Stream<ClipEditorState>.fromIterable([failureState]),
        initialState: const ClipEditorState(),
      );

      await tester.pumpWidget(
        buildWidget(isLoading: true, clipBlocOverride: clipBloc),
      );
      await tester.pump();

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.videoEditorClipSaveFailed), findsOneWidget);
    });

    testWidgets(
      'ignores a discarded clip library save without a snackbar',
      (tester) async {
        final clipBloc = _MockClipEditorBloc();
        final discardedState = ClipEditorState(
          lastClipLibrarySave: ClipLibrarySaveDiscarded(),
        );

        when(() => clipBloc.state).thenReturn(const ClipEditorState());
        whenListen(
          clipBloc,
          Stream<ClipEditorState>.fromIterable([discardedState]),
          initialState: const ClipEditorState(),
        );

        await tester.pumpWidget(
          buildWidget(isLoading: true, clipBlocOverride: clipBloc),
        );
        await tester.pump();

        expect(find.byType(SnackBar), findsNothing);
      },
    );

    testWidgets(
      'ignores discarded extraction results without snackbar or history write',
      (tester) async {
        final clipBloc = _MockClipEditorBloc();
        final mockEditor = _MockProImageEditorState();
        final mockStateManager = _MockStateManager();
        final discardedState = ClipEditorState(
          lastAudioExtraction: ClipAudioExtractionDiscarded(),
        );

        when(() => clipBloc.state).thenReturn(const ClipEditorState());
        whenListen(
          clipBloc,
          Stream<ClipEditorState>.fromIterable([discardedState]),
          initialState: const ClipEditorState(),
        );
        when(() => mockEditor.stateManager).thenReturn(mockStateManager);
        when(() => mockStateManager.activeMeta).thenReturn(const {});
        when(
          () => mockEditor.addHistory(
            layers: any(named: 'layers'),
            filters: any(named: 'filters'),
            meta: any(named: 'meta'),
            newLayer: any(named: 'newLayer'),
            transformConfigs: any(named: 'transformConfigs'),
            tuneAdjustments: any(named: 'tuneAdjustments'),
            blur: any(named: 'blur'),
            heroScreenshotRequired: any(named: 'heroScreenshotRequired'),
            blockCaptureScreenshot: any(named: 'blockCaptureScreenshot'),
          ),
        ).thenAnswer((_) {});

        await tester.pumpWidget(
          buildWidget(
            isLoading: true,
            clipBlocOverride: clipBloc,
            editorOverride: mockEditor,
          ),
        );
        await tester.pump();

        verifyNever(
          () => mockEditor.addHistory(
            layers: any(named: 'layers'),
            filters: any(named: 'filters'),
            meta: any(named: 'meta'),
            newLayer: any(named: 'newLayer'),
            transformConfigs: any(named: 'transformConfigs'),
            tuneAdjustments: any(named: 'tuneAdjustments'),
            blur: any(named: 'blur'),
            heroScreenshotRequired: any(named: 'heroScreenshotRequired'),
            blockCaptureScreenshot: any(named: 'blockCaptureScreenshot'),
          ),
        );
        expect(find.byType(SnackBar), findsNothing);
      },
    );

    testWidgets(
      'shows transform progress overlay while clip transform is running',
      (tester) async {
        final clipBloc = _MockClipEditorBloc();
        const transformingState = ClipEditorState(
          isTransforming: true,
          transformingClipId: 'clip-1',
        );

        when(() => clipBloc.state).thenReturn(transformingState);
        whenListen(
          clipBloc,
          const Stream<ClipEditorState>.empty(),
          initialState: transformingState,
        );

        await tester.pumpWidget(
          buildWidget(isLoading: false, clipBlocOverride: clipBloc),
        );

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(
          find.text(l10n.videoEditorTransformProgressLabel),
          findsOneWidget,
        );
      },
    );

    testWidgets('shows a snackbar when a clip transform render fails', (
      tester,
    ) async {
      final clipBloc = _MockClipEditorBloc();
      final failureState = ClipEditorState(
        lastTransformResult: ClipTransformFailure(),
      );

      when(() => clipBloc.state).thenReturn(const ClipEditorState());
      whenListen(
        clipBloc,
        Stream<ClipEditorState>.fromIterable([failureState]),
        initialState: const ClipEditorState(),
      );

      await tester.pumpWidget(
        buildWidget(isLoading: true, clipBlocOverride: clipBloc),
      );
      await tester.pump();

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.videoEditorTransformFailed), findsOneWidget);
    });

    testWidgets(
      "writes a cropped detached clip back without dropping the layer's "
      'own settings',
      (tester) async {
        registerFallbackValue(_FakeLayer());
        final clipBloc = _MockClipEditorBloc();
        final mockEditor = _MockProImageEditorState();
        // A split tail with a live green screen: both belong to the layer,
        // not to the footage the crop replaces.
        final meta = DetachedClipLayerData(
          clip: _detachedClip(),
          layerId: 'layer-1',
          sourceOffset: const Duration(seconds: 2),
          chromaKey: const ClipChromaKey(key: ChromaKey.blueScreen()),
        ).toMeta();
        final layer = WidgetLayer(
          id: 'layer-1',
          widget: const SizedBox.shrink(),
          meta: meta,
          exportConfigs: WidgetLayerExportConfigs(id: 'layer-1', meta: meta),
        );
        final result = ClipEditorState(
          lastDetachedClipTransformResult: DetachedClipTransformSuccess(
            layerId: 'layer-1',
            clip: _detachedClip(file: 'clip-1_cropped.mp4'),
          ),
        );

        when(() => clipBloc.state).thenReturn(const ClipEditorState());
        whenListen(
          clipBloc,
          Stream<ClipEditorState>.fromIterable([result]),
          initialState: const ClipEditorState(),
        );
        when(() => mockEditor.activeLayers).thenReturn([layer]);
        when(
          () => mockEditor.replaceLayer(
            index: any(named: 'index'),
            layer: any(named: 'layer'),
          ),
        ).thenAnswer((_) {});

        await tester.pumpWidget(
          buildWidget(
            isLoading: true,
            clipBlocOverride: clipBloc,
            editorOverride: mockEditor,
          ),
        );
        await tester.pump();

        final written =
            verify(
                  () => mockEditor.replaceLayer(
                    index: 0,
                    layer: captureAny(named: 'layer'),
                  ),
                ).captured.single
                as WidgetLayer;
        final restored = DetachedClipLayerData.fromMeta(
          DetachedClipLayerData.metaOf(written),
          '/docs',
        )!;
        expect(restored.clip.video?.file?.path, '/docs/clip-1_cropped.mp4');
        // Rebuilding the meta from the clip alone used to rewind the tail
        // to the clip's first frame and drop the key with it.
        expect(restored.sourceOffset, const Duration(seconds: 2));
        expect(
          restored.chromaKey?.key.color,
          const ChromaKey.blueScreen().color,
        );
      },
    );

    testWidgets(
      'keeps a detached last clip on the timeline when its slot closes',
      (tester) async {
        registerFallbackValue(_FakeLayer());
        final clipBloc = _MockClipEditorBloc();
        final mockEditor = _MockProImageEditorState();
        final mockStateManager = _MockStateManager();
        // 4 s then 3 s; the 3 s tail is detached and its slot closed, so
        // the timeline is 4 s long afterwards.
        final head = DivineVideoClip(
          id: 'head',
          video: EditorVideo.file('/docs/head.mp4'),
          duration: const Duration(seconds: 4),
          recordedAt: DateTime(2026),
          targetAspectRatio: .square,
          originalAspectRatio: 1,
        );
        final tail = DivineVideoClip(
          id: 'tail',
          video: EditorVideo.file('/docs/tail.mp4'),
          duration: const Duration(seconds: 3),
          recordedAt: DateTime(2026),
          targetAspectRatio: .square,
          originalAspectRatio: 1,
        );
        final detached = ClipEditorState(
          clips: [head],
          lastDetachResult: ClipDetachSuccess(
            previousClips: [head, tail],
            detachedClip: tail,
          ),
        );

        when(() => clipBloc.state).thenReturn(const ClipEditorState());
        whenListen(
          clipBloc,
          Stream<ClipEditorState>.fromIterable([detached]),
          initialState: const ClipEditorState(),
        );
        when(() => mockEditor.stateManager).thenReturn(mockStateManager);
        when(() => mockStateManager.activeMeta).thenReturn(const {});
        when(
          () => mockEditor.addHistory(
            layers: any(named: 'layers'),
            filters: any(named: 'filters'),
            meta: any(named: 'meta'),
            newLayer: any(named: 'newLayer'),
            transformConfigs: any(named: 'transformConfigs'),
            tuneAdjustments: any(named: 'tuneAdjustments'),
            blur: any(named: 'blur'),
            heroScreenshotRequired: any(named: 'heroScreenshotRequired'),
            blockCaptureScreenshot: any(named: 'blockCaptureScreenshot'),
          ),
        ).thenAnswer((_) {});

        await tester.pumpWidget(
          buildWidget(
            isLoading: true,
            clipBlocOverride: clipBloc,
            editorOverride: mockEditor,
          ),
        );
        await tester.pump();

        final layer =
            verify(
                  () => mockEditor.addHistory(
                    layers: any(named: 'layers'),
                    filters: any(named: 'filters'),
                    meta: any(named: 'meta'),
                    newLayer: captureAny(named: 'newLayer'),
                    transformConfigs: any(named: 'transformConfigs'),
                    tuneAdjustments: any(named: 'tuneAdjustments'),
                    blur: any(named: 'blur'),
                    heroScreenshotRequired: any(
                      named: 'heroScreenshotRequired',
                    ),
                    blockCaptureScreenshot: any(
                      named: 'blockCaptureScreenshot',
                    ),
                  ),
                ).captured.single
                as Layer;
        // The slot started at 4 s — the new end of the timeline — so a
        // window kept there would never be on screen. It is pulled back to
        // end on the composition's end instead.
        expect(layer.startTime, const Duration(seconds: 1));
        expect(layer.endTime, const Duration(seconds: 4));
      },
    );

    testWidgets('shows a snackbar when a clip transform has no local file', (
      tester,
    ) async {
      final clipBloc = _MockClipEditorBloc();
      final noFileState = ClipEditorState(
        lastTransformResult: ClipTransformNoLocalFile(),
      );

      when(() => clipBloc.state).thenReturn(const ClipEditorState());
      whenListen(
        clipBloc,
        Stream<ClipEditorState>.fromIterable([noFileState]),
        initialState: const ClipEditorState(),
      );

      await tester.pumpWidget(
        buildWidget(isLoading: true, clipBlocOverride: clipBloc),
      );
      await tester.pump();

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.videoEditorTransformNoLocalFile), findsOneWidget);
    });
  });
}
