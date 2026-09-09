// ABOUTME: Widget tests for VideoEditorScaffold.
// ABOUTME: Verifies loading UI and FAB visibility rules.

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/blocs/video_editor/filter_editor/video_editor_filter_bloc.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/widgets/branded_loading_scaffold.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/video_editor_scaffold.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockClipEditorBloc extends MockBloc<ClipEditorEvent, ClipEditorState>
    implements ClipEditorBloc {}

class _MockProImageEditorState extends Mock implements ProImageEditorState {
  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) =>
      '_MockProImageEditorState';
}

class _MockStateManager extends Mock implements StateManager {}

void main() {
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
      ClipEditorBloc? clipBlocOverride,
      ProImageEditorState? editorOverride,
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
          originalClipAspectRatio: 9 / 16,
          bodySizeNotifier: ValueNotifier(const Size(400, 800)),
          zoomMatrixNotifier: ValueNotifier(Matrix4.identity()),
          playTimeNotifier: ValueNotifier(Duration.zero),
          playheadAdvancingNotifier: ValueNotifier<bool>(false),
          fromLibrary: false,
          child: MultiBlocProvider(
            providers: [
              BlocProvider<VideoEditorMainBloc>.value(value: mainBloc),
              BlocProvider<TimelineOverlayBloc>.value(value: overlayBloc),
              BlocProvider<ClipEditorBloc>.value(
                value: clipBlocOverride ?? clipBloc,
              ),
              BlocProvider<VideoEditorFilterBloc>.value(value: filterBloc),
            ],
            child: MaterialApp(
              theme: theme,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
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
      expect(find.bySemanticsLabel('Add element'), findsOneWidget);
    });

    testWidgets('add-element glyph follows the palette on light', (
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
          of: find.bySemanticsLabel('Add element'),
          matching: find.byType(DivineIcon),
        ),
      );

      // This FAB is a hand-rolled twin of `DivineIconButtonType.secondary`,
      // so it takes that variant's icon rule. The brand green only reaches
      // 1.92:1 on the light `surfaceContainer` fill; `onSurface` is 11.06:1.
      expect(icon.color, VineTheme.lightColors.onSurface);
      expect(icon.color, isNot(VineTheme.primary));
    });

    testWidgets('add-element glyph stays brand green on dark', (tester) async {
      await tester.pumpWidget(
        buildWidget(isLoading: true, theme: VineTheme.theme),
      );
      await tester.pump();

      final icon = tester.widget<DivineIcon>(
        find.descendant(
          of: find.bySemanticsLabel('Add element'),
          matching: find.byType(DivineIcon),
        ),
      );

      expect(icon.color, VineTheme.primary);
    });

    testWidgets('hides FAB while a sub-editor is open', (tester) async {
      mainBloc.add(const VideoEditorMainOpenSubEditor(SubEditorType.text));

      await tester.pumpWidget(buildWidget(isLoading: true));
      await tester.pump();

      expect(find.bySemanticsLabel('Add element'), findsNothing);
    });

    testWidgets('hides FAB when an overlay item is selected', (tester) async {
      overlayBloc.add(const TimelineOverlayItemSelected('overlay-1'));

      await tester.pumpWidget(buildWidget(isLoading: true));
      await tester.pump();

      expect(find.bySemanticsLabel('Add element'), findsNothing);
    });

    testWidgets('hides FAB during draw-layer multi-select', (tester) async {
      overlayBloc.add(const TimelineOverlayLayerMultiSelectStarted('draw-1'));

      await tester.pumpWidget(buildWidget(isLoading: true));
      await tester.pump();

      expect(find.bySemanticsLabel('Add element'), findsNothing);
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
