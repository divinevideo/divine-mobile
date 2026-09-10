// ABOUTME: Widget tests for VideoEditorMainOverlayActions toolbar.
// ABOUTME: Tests button rendering, music sub-editor hiding, and close/done.

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/models/stop_motion/stop_motion_frame_ops.dart';
import 'package:openvine/models/stop_motion_clip_frame.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/models/video_publish/video_publish_provider_state.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/providers/video_publish_provider.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_main_overlay_actions.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/video_editor_toolbar.dart';

import '../../../helpers/go_router.dart';

class _MockVideoEditorMainBloc
    extends MockBloc<VideoEditorMainEvent, VideoEditorMainState>
    implements VideoEditorMainBloc {}

class _MockDivineVideoDraft extends Mock implements DivineVideoDraft {}

class _FakeVideoEditorNotifier extends VideoEditorNotifier {
  _FakeVideoEditorNotifier({
    required this.initialState,
    required this.activeDraft,
    this.saveAsDraftResult = DraftSaveOutcome.saved,
  });

  final VideoEditorProviderState initialState;
  final DivineVideoDraft activeDraft;
  final DraftSaveOutcome saveAsDraftResult;

  int saveAsDraftCalls = 0;

  @override
  VideoEditorProviderState build() => initialState;

  @override
  DivineVideoDraft getActiveDraft({bool isAutosave = false, String? draftId}) =>
      activeDraft;

  @override
  Future<DraftSaveOutcome> saveAsDraft({
    bool enforceCreateNewDraft = false,
  }) async {
    saveAsDraftCalls++;
    return saveAsDraftResult;
  }
}

class _FakeVideoPublishNotifier extends VideoPublishNotifier {
  int clearAllCalls = 0;
  final keepAutosavedDraftValues = <bool>[];

  @override
  VideoPublishProviderState build() => const VideoPublishProviderState();

  @override
  Future<void> clearAll({bool keepAutosavedDraft = false}) async {
    clearAllCalls++;
    keepAutosavedDraftValues.add(keepAutosavedDraft);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final l10n = lookupAppLocalizations(const Locale('en'));
  final closeLabel = l10n.videoEditorCloseEditorSemanticLabel;
  final doneLabel = l10n.videoEditorContinueToPostDetailsSemanticLabel;

  group(VideoEditorMainOverlayActions, () {
    late _MockVideoEditorMainBloc mockBloc;
    late ClipEditorBloc clipEditorBloc;
    late MockGoRouter mockGoRouter;
    late _FakeVideoEditorNotifier fakeVideoEditorNotifier;
    late _FakeVideoPublishNotifier fakeVideoPublishNotifier;

    setUp(() {
      mockBloc = _MockVideoEditorMainBloc();
      clipEditorBloc = ClipEditorBloc(
        onFinalClipInvalidated: () {},
        saveClipToLibrary: ({required clip}) async => false,
      );
      mockGoRouter = MockGoRouter();

      when(() => mockBloc.state).thenReturn(const VideoEditorMainState());
      when(
        () => mockBloc.stream,
      ).thenAnswer((_) => const Stream<VideoEditorMainState>.empty());
      when(() => mockGoRouter.pop<Object?>(any())).thenAnswer((_) async {});
    });

    tearDown(() => clipEditorBloc.close());

    Widget buildWidget({
      VideoEditorMainState? state,
      bool isAutosavedDraft = false,
      bool hasBeenEdited = false,
      DraftSaveOutcome saveAsDraftResult = DraftSaveOutcome.saved,
    }) {
      if (state != null) {
        when(() => mockBloc.state).thenReturn(state);
      }

      final mockDraft = _MockDivineVideoDraft();
      when(() => mockDraft.hasBeenEdited).thenReturn(hasBeenEdited);

      fakeVideoEditorNotifier = _FakeVideoEditorNotifier(
        initialState: VideoEditorProviderState(
          isAutosavedDraft: isAutosavedDraft,
        ),
        activeDraft: mockDraft,
        saveAsDraftResult: saveAsDraftResult,
      );
      fakeVideoPublishNotifier = _FakeVideoPublishNotifier();

      return ProviderScope(
        overrides: [
          videoEditorProvider.overrideWith(() => fakeVideoEditorNotifier),
          videoPublishProvider.overrideWith(() => fakeVideoPublishNotifier),
        ],
        child: MockGoRouterProvider(
          goRouter: mockGoRouter,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: VideoEditorScope(
                editorKey: GlobalKey(),
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
                onAddEditTextLayer: ([layer]) async => null,
                child: MultiBlocProvider(
                  providers: [
                    BlocProvider<VideoEditorMainBloc>.value(value: mockBloc),
                    BlocProvider<ClipEditorBloc>.value(value: clipEditorBloc),
                  ],
                  child: const VideoEditorMainOverlayActions(),
                ),
              ),
            ),
          ),
        ),
      );
    }

    group('renders', () {
      testWidgets('renders $VideoEditorMainOverlayActions', (tester) async {
        await tester.pumpWidget(buildWidget());

        expect(find.byType(VideoEditorMainOverlayActions), findsOneWidget);
      });

      testWidgets('renders $VideoEditorToolbar', (tester) async {
        await tester.pumpWidget(buildWidget());

        expect(find.byType(VideoEditorToolbar), findsOneWidget);
      });

      testWidgets('renders Close button with caret-left icon', (tester) async {
        await tester.pumpWidget(buildWidget());

        expect(find.bySemanticsLabel(closeLabel), findsOneWidget);
        expect(
          find.byWidgetPredicate(
            (w) => w is DivineIcon && w.icon == DivineIconName.caretLeft,
          ),
          findsOneWidget,
        );
      });

      testWidgets('renders Done button with caret-right icon', (tester) async {
        await tester.pumpWidget(buildWidget());

        expect(
          find.bySemanticsLabel(doneLabel),
          findsOneWidget,
        );
        expect(
          find.byWidgetPredicate(
            (w) => w is DivineIcon && w.icon == DivineIconName.arrowRight,
          ),
          findsOneWidget,
        );
      });
    });

    group('music sub-editor hiding', () {
      Finder findOverlayOpacity() => find
          .descendant(
            of: find.byType(VideoEditorMainOverlayActions),
            matching: find.byType(AnimatedOpacity),
          )
          .first;

      testWidgets('is hidden when music sub-editor is open', (tester) async {
        await tester.pumpWidget(
          buildWidget(
            state: const VideoEditorMainState(
              openSubEditor: SubEditorType.music,
            ),
          ),
        );
        // Use pump instead of pumpAndSettle — CircularProgressIndicator
        // never settles.
        await tester.pump(const Duration(milliseconds: 300));

        final animatedOpacity = tester.widget<AnimatedOpacity>(
          findOverlayOpacity(),
        );
        expect(animatedOpacity.opacity, equals(0));
      });

      testWidgets('is visible when no sub-editor is open', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pump(const Duration(milliseconds: 300));

        final animatedOpacity = tester.widget<AnimatedOpacity>(
          findOverlayOpacity(),
        );
        expect(animatedOpacity.opacity, equals(1));
      });

      testWidgets('is visible when non-music sub-editor is open', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(
            state: const VideoEditorMainState(
              openSubEditor: SubEditorType.text,
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));

        final animatedOpacity = tester.widget<AnimatedOpacity>(
          findOverlayOpacity(),
        );
        expect(animatedOpacity.opacity, equals(1));
      });
    });

    group('interactions', () {
      testWidgets(
        'tapping Close when no sub-editor is open calls context.pop',
        (tester) async {
          await tester.pumpWidget(buildWidget());

          await tester.tap(find.bySemanticsLabel(closeLabel));

          verify(() => mockGoRouter.pop<Object?>(any())).called(1);
        },
      );

      testWidgets('autosaved draft without edits closes directly', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget(isAutosavedDraft: true));

        await tester.tap(find.bySemanticsLabel(closeLabel));
        await tester.pumpAndSettle();

        verify(() => mockGoRouter.pop<Object?>(any())).called(1);
        expect(find.text('Save your draft?'), findsNothing);
      });

      testWidgets('autosaved draft with edits shows save/discard prompt', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(isAutosavedDraft: true, hasBeenEdited: true),
        );

        await tester.tap(find.bySemanticsLabel(closeLabel));
        await tester.pumpAndSettle();

        expect(find.text('Save your draft?'), findsOneWidget);
        expect(find.text('Save draft'), findsOneWidget);
        expect(find.text('Discard changes'), findsOneWidget);
      });

      testWidgets(
        'save draft action calls saveAsDraft, closes twice and shows success snackbar',
        (tester) async {
          await tester.pumpWidget(
            buildWidget(isAutosavedDraft: true, hasBeenEdited: true),
          );

          await tester.tap(find.bySemanticsLabel(closeLabel));
          await tester.pumpAndSettle();

          await tester.tap(find.text('Save draft'));
          await tester.pumpAndSettle();

          expect(fakeVideoEditorNotifier.saveAsDraftCalls, equals(1));
          verify(() => mockGoRouter.pop<Object?>(any())).called(2);
          expect(find.text('Saved to library'), findsOneWidget);
          // The draft owns the session now; leaving it selected would carry
          // its clips — and their aspect ratio — into the next camera open.
          expect(fakeVideoPublishNotifier.clearAllCalls, equals(1));
          // `saveAsDraft` already awaited the autosave delete, so this clear
          // must not re-issue it: a late fixed-id delete would wipe whatever
          // session is active by the time it lands.
          expect(fakeVideoPublishNotifier.keepAutosavedDraftValues, [isTrue]);
        },
      );

      testWidgets('discard action clears publish state and closes twice', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(isAutosavedDraft: true, hasBeenEdited: true),
        );

        await tester.tap(find.bySemanticsLabel(closeLabel));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Discard changes'));
        await tester.pumpAndSettle();

        expect(fakeVideoPublishNotifier.clearAllCalls, equals(1));
        verify(() => mockGoRouter.pop<Object?>(any())).called(2);
      });

      testWidgets(
        'save draft failure keeps editor open and shows failure snackbar',
        (tester) async {
          await tester.pumpWidget(
            buildWidget(
              isAutosavedDraft: true,
              hasBeenEdited: true,
              saveAsDraftResult: DraftSaveOutcome.failed,
            ),
          );

          await tester.tap(find.bySemanticsLabel(closeLabel));
          await tester.pumpAndSettle();

          await tester.tap(find.text('Save draft'));
          await tester.pumpAndSettle();

          expect(fakeVideoEditorNotifier.saveAsDraftCalls, equals(1));
          verify(() => mockGoRouter.pop<Object?>(any())).called(1);
          expect(find.text('Failed to save'), findsOneWidget);
          expect(find.bySemanticsLabel(closeLabel), findsOneWidget);
          // Nothing was saved, so the session is all the user has left.
          expect(fakeVideoPublishNotifier.clearAllCalls, isZero);
        },
      );

      testWidgets('save draft already in flight leaves the prompt open with no '
          'snackbar or navigation', (tester) async {
        await tester.pumpWidget(
          buildWidget(
            isAutosavedDraft: true,
            hasBeenEdited: true,
            saveAsDraftResult: DraftSaveOutcome.alreadyInProgress,
          ),
        );

        await tester.tap(find.bySemanticsLabel(closeLabel));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Save draft'));
        await tester.pumpAndSettle();

        expect(fakeVideoEditorNotifier.saveAsDraftCalls, equals(1));
        verifyNever(() => mockGoRouter.pop<Object?>(any()));
        expect(find.text('Saved to library'), findsNothing);
        expect(find.text('Failed to save'), findsNothing);
        // The prompt stays open so the in-flight save can land.
        expect(find.text('Save your draft?'), findsOneWidget);
      });
    });

    group('stop-motion minimum length gate', () {
      DivineVideoClip stopMotionClip(Duration total) => DivineVideoClip(
        id: 'sm1',
        stopMotionFrames: [
          StopMotionClipFrame(path: '/frames/f0.jpg', duration: total),
        ],
        duration: total,
        recordedAt: DateTime(2024),
        targetAspectRatio: model.AspectRatio.vertical,
        originalAspectRatio: 9 / 16,
      );

      Finder doneButton() => find.ancestor(
        of: find.byWidgetPredicate(
          (w) => w is DivineIcon && w.icon == DivineIconName.arrowRight,
        ),
        matching: find.byType(DivineIconButton),
      );

      testWidgets('a too-short composition shows the snackbar and stays', (
        tester,
      ) async {
        clipEditorBloc.add(
          ClipEditorInitialized([
            stopMotionClip(const Duration(milliseconds: 500)),
          ]),
        );
        await tester.pumpWidget(buildWidget());
        await tester.pump();

        await tester.tap(doneButton());
        await tester.pump();

        expect(
          find.text(l10n.videoEditorStopMotionTooShortSnackbar(1)),
          findsOneWidget,
        );
      });

      testWidgets('a long-enough composition passes without a snackbar', (
        tester,
      ) async {
        clipEditorBloc.add(
          ClipEditorInitialized([stopMotionClip(const Duration(seconds: 2))]),
        );
        await tester.pumpWidget(buildWidget());
        await tester.pump();

        await tester.tap(doneButton());
        await tester.pump();

        expect(
          find.text(l10n.videoEditorStopMotionTooShortSnackbar(1)),
          findsNothing,
        );
      });
    });

    group('stop-motion frames chip', () {
      DivineVideoClip clipWithHolds(List<int> holds) {
        final frames = [
          for (final (i, hold) in holds.indexed)
            StopMotionClipFrame(
              path: '/frames/f$i.jpg',
              duration: StopMotionFrameOps.framesPerImageToDuration(hold),
            ),
        ];
        return DivineVideoClip(
          id: 'sm1',
          stopMotionFrames: frames,
          duration: StopMotionFrameOps.totalDuration(frames),
          recordedAt: DateTime(2024),
          targetAspectRatio: model.AspectRatio.vertical,
          originalAspectRatio: 9 / 16,
        );
      }

      testWidgets('shows the shared global hold', (tester) async {
        clipEditorBloc.add(
          ClipEditorInitialized([
            clipWithHolds([3, 3, 3]),
          ]),
        );
        await tester.pumpWidget(buildWidget());
        await tester.pump();

        expect(
          find.text(l10n.videoEditorStopMotionFramesCount(3)),
          findsOneWidget,
        );
      });

      testWidgets('exposes at least a 48dp square tap target', (tester) async {
        clipEditorBloc.add(
          ClipEditorInitialized([
            clipWithHolds([3, 3, 3]),
          ]),
        );
        await tester.pumpWidget(buildWidget());
        await tester.pump();

        final chipLabel = find.text(l10n.videoEditorStopMotionFramesCount(3));
        expect(chipLabel, findsOneWidget);

        // The visible pill is ~28dp tall; the tap target must still reach the
        // 48dp minimum touch size.
        final tapTarget = find
            .ancestor(of: chipLabel, matching: find.byType(GestureDetector))
            .first;
        final size = tester.getSize(tapTarget);
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
        // ...but it must NOT stretch to fill the toolbar's loose height (a
        // plain Center did, dragging the whole back/done row down the editor).
        expect(size.height, lessThan(80));
      });

      testWidgets('shows the most common hold instead of the bare label when '
          'frames disagree', (tester) async {
        clipEditorBloc.add(
          ClipEditorInitialized([
            clipWithHolds([2, 2, 1, 2]),
          ]),
        );
        await tester.pumpWidget(buildWidget());
        await tester.pump();

        expect(
          find.text(l10n.videoEditorStopMotionFramesCount(2)),
          findsOneWidget,
        );
        expect(
          find.text(l10n.videoEditorStopMotionFramesPerImageLabel),
          findsNothing,
        );
      });
    });
  });
}
