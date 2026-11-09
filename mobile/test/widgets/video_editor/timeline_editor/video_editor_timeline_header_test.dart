// ABOUTME: Widget tests for VideoEditorTimelineHeader.
// ABOUTME: Validates play/pause, undo/redo buttons, volume arc, and time display.

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/stop_motion_clip_frame.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/video_editor_timeline_header.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

class _MockVideoEditorMainBloc
    extends MockBloc<VideoEditorMainEvent, VideoEditorMainState>
    implements VideoEditorMainBloc {}

class _MockClipEditorBloc extends MockBloc<ClipEditorEvent, ClipEditorState>
    implements ClipEditorBloc {}

class _MockTimelineOverlayBloc
    extends MockBloc<TimelineOverlayEvent, TimelineOverlayState>
    implements TimelineOverlayBloc {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(VideoEditorTimelineHeader, () {
    late _MockVideoEditorMainBloc mockMainBloc;
    late _MockClipEditorBloc mockClipBloc;
    late _MockTimelineOverlayBloc mockTimelineOverlayBloc;
    late ValueNotifier<Duration> playheadPosition;
    late ValueNotifier<double?> volumePreviewNotifier;

    setUp(() {
      mockMainBloc = _MockVideoEditorMainBloc();
      mockClipBloc = _MockClipEditorBloc();
      mockTimelineOverlayBloc = _MockTimelineOverlayBloc();
      playheadPosition = ValueNotifier(Duration.zero);
      volumePreviewNotifier = ValueNotifier<double?>(null);

      when(() => mockMainBloc.state).thenReturn(const VideoEditorMainState());
      when(
        () => mockMainBloc.stream,
      ).thenAnswer((_) => const Stream<VideoEditorMainState>.empty());
      when(() => mockClipBloc.state).thenReturn(const ClipEditorState());
      when(
        () => mockClipBloc.stream,
      ).thenAnswer((_) => const Stream<ClipEditorState>.empty());
      when(
        () => mockTimelineOverlayBloc.state,
      ).thenReturn(const TimelineOverlayState());
      when(
        () => mockTimelineOverlayBloc.stream,
      ).thenAnswer((_) => const Stream<TimelineOverlayState>.empty());
    });

    tearDown(() {
      playheadPosition.dispose();
      volumePreviewNotifier.dispose();
    });

    Widget buildWidget({
      VideoEditorMainState? mainState,
      ClipEditorState? clipState,
      TimelineOverlayState? overlayState,
      Duration? position,
      Locale? locale,
      double textScale = 1,
    }) {
      if (mainState != null) {
        when(() => mockMainBloc.state).thenReturn(mainState);
      }
      if (clipState != null) {
        when(() => mockClipBloc.state).thenReturn(clipState);
      }
      if (overlayState != null) {
        when(() => mockTimelineOverlayBloc.state).thenReturn(overlayState);
      }
      if (position != null) {
        playheadPosition.value = position;
      }

      return MaterialApp(
        locale: locale,
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: VideoEditorScope(
            editorKey: GlobalKey<ProImageEditorState>(),
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
                BlocProvider<VideoEditorMainBloc>.value(value: mockMainBloc),
                BlocProvider<ClipEditorBloc>.value(value: mockClipBloc),
                BlocProvider<TimelineOverlayBloc>.value(
                  value: mockTimelineOverlayBloc,
                ),
              ],
              child: VideoEditorTimelineHeader(
                playheadPosition: playheadPosition,
                volumePreviewNotifier: volumePreviewNotifier,
              ),
            ),
          ),
        ),
      );
    }

    group('renders', () {
      testWidgets('renders $VideoEditorTimelineHeader', (tester) async {
        await tester.pumpWidget(buildWidget());

        expect(find.byType(VideoEditorTimelineHeader), findsOneWidget);
      });

      testWidgets('renders play/pause button', (tester) async {
        await tester.pumpWidget(buildWidget());

        expect(find.bySemanticsLabel('Play'), findsOneWidget);
      });

      testWidgets('renders undo button', (tester) async {
        await tester.pumpWidget(buildWidget());

        expect(find.bySemanticsLabel('Undo'), findsOneWidget);
      });

      testWidgets('renders redo button', (tester) async {
        await tester.pumpWidget(buildWidget());

        expect(find.bySemanticsLabel('Redo'), findsOneWidget);
      });
    });

    group('play/pause', () {
      testWidgets('shows play label when not playing', (tester) async {
        await tester.pumpWidget(
          buildWidget(mainState: const VideoEditorMainState()),
        );

        expect(find.bySemanticsLabel('Play'), findsOneWidget);
      });

      testWidgets('shows pause label when playing', (tester) async {
        await tester.pumpWidget(
          buildWidget(mainState: const VideoEditorMainState(isPlaying: true)),
        );

        expect(find.bySemanticsLabel('Pause'), findsOneWidget);
      });

      testWidgets('dispatches toggle event on tap', (tester) async {
        await tester.pumpWidget(
          buildWidget(
            mainState: const VideoEditorMainState(isPlayerReady: true),
          ),
        );

        await tester.tap(find.bySemanticsLabel('Play'));
        await tester.pump();

        verify(
          () => mockMainBloc.add(const VideoEditorPlaybackToggleRequested()),
        ).called(1);
      });

      testWidgets('disables play button while the player is not ready', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(mainState: const VideoEditorMainState()),
        );

        final playButton = buttonBySemanticLabel(tester, 'Play');

        expect(playButton.onPressed, isNull);
      });

      // A frames-only composition never creates a native player, so
      // isPlayerReady stays false for its whole lifetime — gating the button
      // on it alone would make stop-motion preview permanently unplayable.
      testWidgets('keeps play button enabled for a stop-motion composition', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(
            mainState: const VideoEditorMainState(),
            clipState: ClipEditorState(clips: [_stopMotionClip()]),
          ),
        );

        final playButton = buttonBySemanticLabel(tester, 'Play');

        expect(playButton.onPressed, isNotNull);
      });

      testWidgets('dispatches toggle event for a stop-motion composition', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(
            mainState: const VideoEditorMainState(),
            clipState: ClipEditorState(clips: [_stopMotionClip()]),
          ),
        );

        await tester.tap(find.bySemanticsLabel('Play'));
        await tester.pump();

        verify(
          () => mockMainBloc.add(const VideoEditorPlaybackToggleRequested()),
        ).called(1);
      });
    });

    group('undo/redo', () {
      testWidgets('undo button is disabled when canUndo is false', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(mainState: const VideoEditorMainState()),
        );

        final l10n = lookupAppLocalizations(const Locale('en'));
        final undoButton = buttonBySemanticLabel(
          tester,
          l10n.videoEditorUndoSemanticLabel,
        );
        expect(undoButton.onPressed, isNull);
      });

      testWidgets('undo button is enabled when canUndo is true', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(mainState: const VideoEditorMainState(canUndo: true)),
        );

        final l10n = lookupAppLocalizations(const Locale('en'));
        final undoButton = buttonBySemanticLabel(
          tester,
          l10n.videoEditorUndoSemanticLabel,
        );
        expect(undoButton.onPressed, isNotNull);
      });

      testWidgets('redo button is disabled when canRedo is false', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(mainState: const VideoEditorMainState()),
        );

        final l10n = lookupAppLocalizations(const Locale('en'));
        final redoButton = buttonBySemanticLabel(
          tester,
          l10n.videoEditorRedoSemanticLabel,
        );
        expect(redoButton.onPressed, isNull);
      });

      testWidgets('redo button is enabled when canRedo is true', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(mainState: const VideoEditorMainState(canRedo: true)),
        );

        final l10n = lookupAppLocalizations(const Locale('en'));
        final redoButton = buttonBySemanticLabel(
          tester,
          l10n.videoEditorRedoSemanticLabel,
        );
        expect(redoButton.onPressed, isNotNull);
      });
    });

    group('time display', () {
      testWidgets('displays time from playhead position', (tester) async {
        await tester.pumpWidget(
          buildWidget(position: const Duration(seconds: 5)),
        );

        // formatCompactDuration(5s) = "05:00"
        expect(find.textContaining('05:00'), findsOneWidget);
      });

      testWidgets('updates time when playhead position changes', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget());

        // Initial: 0s = "00:00"
        expect(find.textContaining('00:00'), findsOneWidget);

        playheadPosition.value = const Duration(seconds: 3, milliseconds: 500);
        await tester.pump();

        // 3.5s = "03:50"
        expect(find.textContaining('03:50'), findsOneWidget);
      });

      testWidgets('shows total duration from ClipEditorBloc', (tester) async {
        final clips = [
          _createTestClip(id: 'a', seconds: 5),
          _createTestClip(id: 'b', seconds: 3),
        ];

        await tester.pumpWidget(
          buildWidget(
            clipState: ClipEditorState(clips: clips),
            position: const Duration(seconds: 2),
          ),
        );

        // totalDuration = 8s → "08:00"
        expect(find.textContaining('08:00'), findsOneWidget);
      });

      testWidgets('shows the rendered output duration, not the editor sum, '
          'for an overlap transition', (tester) async {
        final clips = [
          _createTestClip(id: 'a').copyWith(
            // ClipTransition defaults to a 500ms duration.
            transition: const ClipTransition(
              type: ClipTransitionType.dissolve,
            ),
          ),
          _createTestClip(id: 'b'),
        ];

        await tester.pumpWidget(
          buildWidget(clipState: ClipEditorState(clips: clips)),
        );

        // The editor timeline sums to 4s, but a 500ms dissolve blends both
        // clips, so the rendered output is 3.5s — that's what the header shows.
        expect(find.textContaining('03:50'), findsOneWidget);
        expect(find.textContaining('04:00'), findsNothing);
      });
    });

    group('volume mode', () {
      testWidgets('shows slide-to-adjust copy in volume edit mode', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(
            mainState: const VideoEditorMainState(isVolumeEditMode: true),
            clipState: ClipEditorState(clips: [_createTestClip(id: 'a')]),
          ),
        );

        expect(find.text('Slide to adjust'), findsOneWidget);
      });

      testWidgets('shows live preview percentage when notifier updates', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(
            mainState: const VideoEditorMainState(isVolumeEditMode: true),
            clipState: ClipEditorState(clips: [_createTestClip(id: 'a')]),
          ),
        );

        volumePreviewNotifier.value = 0.42;
        await tester.pump();

        expect(find.text('Volume 42%'), findsOneWidget);
      });

      testWidgets(
        'volume button uses highlighted override colors when active',
        (
          tester,
        ) async {
          await tester.pumpWidget(
            buildWidget(
              mainState: const VideoEditorMainState(isVolumeEditMode: true),
              clipState: ClipEditorState(clips: [_createTestClip(id: 'a')]),
            ),
          );

          final l10n = lookupAppLocalizations(const Locale('en'));
          final volumeButton = buttonBySemanticLabel(
            tester,
            l10n.videoEditorVolumeSemanticLabel,
          );

          expect(volumeButton.backgroundColor, VineTheme.accentYellow);
          expect(
            volumeButton.foregroundColor,
            VineTheme.accentYellowBackground,
          );
        },
      );

      testWidgets(
        'volume button uses accent icon when any volume is modified',
        (
          tester,
        ) async {
          await tester.pumpWidget(
            buildWidget(
              clipState: ClipEditorState(
                clips: [
                  _createTestClip(id: 'a').copyWith(volume: 0.6),
                ],
              ),
            ),
          );

          final l10n = lookupAppLocalizations(const Locale('en'));
          final volumeButton = buttonBySemanticLabel(
            tester,
            l10n.videoEditorVolumeSemanticLabel,
          );

          expect(volumeButton.foregroundColor, VineTheme.accentYellow);
          expect(volumeButton.backgroundColor, isNull);
        },
      );
    });

    group('on a small phone', () {
      final l10n = lookupAppLocalizations(const Locale('en'));

      void useSmallPhone(WidgetTester tester, {double width = 375}) {
        tester.view.physicalSize = Size(width, 667);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
      }

      Rect buttonRect(WidgetTester tester, String label) => tester.getRect(
        find.ancestor(
          of: find.bySemanticsLabel(label),
          matching: find.byType(DivineIconButton),
        ),
      );

      testWidgets('keeps the time between the buttons at the default size', (
        tester,
      ) async {
        useSmallPhone(tester);
        await tester.pumpWidget(
          buildWidget(
            clipState: ClipEditorState(clips: [_createTestClip(id: 'a')]),
          ),
        );

        final time = tester.getRect(find.textContaining('00:00'));
        final undo = buttonRect(tester, l10n.videoEditorUndoSemanticLabel);
        expect(time.center.dy, moreOrLessEquals(undo.center.dy));
      });

      testWidgets('moves the time under the buttons at the largest text size, '
          'keeping undo and redo on screen', (tester) async {
        useSmallPhone(tester);
        await tester.pumpWidget(
          buildWidget(
            clipState: ClipEditorState(clips: [_createTestClip(id: 'a')]),
            textScale: 3.12,
          ),
        );

        final redo = buttonRect(tester, l10n.videoEditorRedoSemanticLabel);
        expect(redo.right, lessThanOrEqualTo(375));
        final timeFinder = find.textContaining('00:00');
        final time = tester.getRect(timeFinder);
        expect(time.top, greaterThanOrEqualTo(redo.bottom));
        // Drawn at the size it is laid out at, not shrunk to fit.
        expect(
          time.height,
          moreOrLessEquals(tester.getSize(timeFinder).height),
        );
      });

      testWidgets('wraps the German volume hint between the buttons on a '
          '360 dp phone', (tester) async {
        useSmallPhone(tester, width: 360);
        await tester.pumpWidget(
          buildWidget(
            mainState: const VideoEditorMainState(isVolumeEditMode: true),
            clipState: ClipEditorState(clips: [_createTestClip(id: 'a')]),
            locale: const Locale('de'),
          ),
        );

        final de = lookupAppLocalizations(const Locale('de'));
        final volume = buttonRect(tester, de.videoEditorVolumeSemanticLabel);
        final undo = buttonRect(tester, de.videoEditorUndoSemanticLabel);
        final redo = buttonRect(tester, de.videoEditorRedoSemanticLabel);
        expect(redo.right, lessThanOrEqualTo(360));
        final hintFinder = find.text(de.videoEditorTimelineSlideToAdjust);
        final hint = tester.getRect(hintFinder);
        expect(hint.left, greaterThanOrEqualTo(volume.right));
        expect(hint.right, lessThanOrEqualTo(undo.left));
        expect(hint.center.dy, moreOrLessEquals(undo.center.dy, epsilon: 1));
        expect(
          tester.renderObject<RenderParagraph>(hintFinder).didExceedMaxLines,
          isFalse,
        );
      });

      testWidgets('moves the German volume hint under the buttons at 1.3x on '
          'a 360 dp phone', (tester) async {
        useSmallPhone(tester, width: 360);
        await tester.pumpWidget(
          buildWidget(
            mainState: const VideoEditorMainState(isVolumeEditMode: true),
            clipState: ClipEditorState(clips: [_createTestClip(id: 'a')]),
            locale: const Locale('de'),
            textScale: 1.3,
          ),
        );

        final de = lookupAppLocalizations(const Locale('de'));
        final redo = buttonRect(tester, de.videoEditorRedoSemanticLabel);
        expect(redo.right, lessThanOrEqualTo(360));
        final hint = tester.getRect(
          find.text(de.videoEditorTimelineSlideToAdjust),
        );
        expect(hint.top, greaterThanOrEqualTo(redo.bottom));
      });

      testWidgets('keeps every button on screen and never shrinks the time '
          'as the text size grows', (tester) async {
        useSmallPhone(tester);
        for (var step = 0; step <= 10; step++) {
          final scale = 1 + step * 0.05;
          await tester.pumpWidget(
            buildWidget(
              clipState: ClipEditorState(clips: [_createTestClip(id: 'a')]),
              textScale: scale,
            ),
          );

          final reason = 'at text scale ${scale.toStringAsFixed(2)}';
          final redo = buttonRect(tester, l10n.videoEditorRedoSemanticLabel);
          expect(redo.right, lessThanOrEqualTo(375), reason: reason);
          final timeFinder = find.textContaining('00:00');
          expect(
            tester.getRect(timeFinder).height,
            moreOrLessEquals(tester.getSize(timeFinder).height),
            reason: reason,
          );
        }
      });
    });
  });
}

DivineIconButton buttonBySemanticLabel(WidgetTester tester, String label) {
  final finder = find.ancestor(
    of: find.bySemanticsLabel(label),
    matching: find.byType(DivineIconButton),
  );
  return tester.widget<DivineIconButton>(finder.first);
}

/// A frames-only clip: `isStopMotion` requires a null [EditorVideo] plus
/// frames, which is exactly the shape that never gets a native player.
DivineVideoClip _stopMotionClip() {
  return DivineVideoClip(
    id: 'stop-motion-1',
    stopMotionFrames: const [
      StopMotionClipFrame(
        path: '/d/a.jpg',
        duration: Duration(milliseconds: 83),
      ),
      StopMotionClipFrame(
        path: '/d/b.jpg',
        duration: Duration(milliseconds: 83),
      ),
    ],
    duration: const Duration(milliseconds: 166),
    recordedAt: DateTime(2025),
    originalAspectRatio: 9 / 16,
    targetAspectRatio: .vertical,
  );
}

DivineVideoClip _createTestClip({required String id, int seconds = 2}) {
  return DivineVideoClip(
    id: id,
    video: EditorVideo.file('/tmp/test_$id.mp4'),
    duration: Duration(seconds: seconds),
    recordedAt: DateTime(2025),
    originalAspectRatio: 9 / 16,
    targetAspectRatio: .vertical,
  );
}
