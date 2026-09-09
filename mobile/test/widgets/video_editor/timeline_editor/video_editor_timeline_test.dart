// ABOUTME: Widget tests for VideoEditorTimeline.
// ABOUTME: Validates timeline rendering, scroll content, playhead, and empty state.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/blocs/video_editor/filter_editor/video_editor_filter_bloc.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/constants/video_editor_timeline_constants.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/stop_motion_clip_frame.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/strips/video_editor_timeline_clip_strip.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/video_editor_timeline.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/video_editor_timeline_body.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/video_editor_timeline_geometry.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/video_editor_timeline_header.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/video_editor_timeline_interactive_body.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/video_editor_timeline_playhead.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/video_editor_timeline_rules_indicator.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

class _MockProVideoEditor extends ProVideoEditor {
  @override
  Stream<dynamic> initializeStream() => const Stream.empty();

  @override
  Future<List<Uint8List>> getThumbnails(
    ThumbnailConfigs configs, {
    NativeLogLevel? nativeLogLevel,
  }) async {
    return List.filled(configs.timestamps.length, Uint8List(0));
  }

  @override
  Future<VideoMetadata> getMetadata(
    EditorVideo value, {
    bool checkStreamingOptimization = false,
    NativeLogLevel? nativeLogLevel,
  }) async {
    return VideoMetadata(
      duration: const Duration(seconds: 5),
      extension: 'mp4',
      fileSize: 1024000,
      resolution: const Size(1920, 1080),
      rotation: 0,
      bitrate: 3000000,
    );
  }
}

class _MockVideoEditorMainBloc
    extends MockBloc<VideoEditorMainEvent, VideoEditorMainState>
    implements VideoEditorMainBloc {}

class _MockClipEditorBloc extends MockBloc<ClipEditorEvent, ClipEditorState>
    implements ClipEditorBloc {}

class _MockTimelineOverlayBloc
    extends MockBloc<TimelineOverlayEvent, TimelineOverlayState>
    implements TimelineOverlayBloc {}

class _MockVideoEditorFilterBloc
    extends MockBloc<VideoEditorFilterEvent, VideoEditorFilterState>
    implements VideoEditorFilterBloc {}

class _MockProImageEditorState extends Mock implements ProImageEditorState {
  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) =>
      '_MockProImageEditorState';
}

class _MockStateManager extends Mock implements StateManager {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(VideoEditorTimelineScaffold, () {
    late _MockVideoEditorMainBloc mockMainBloc;
    late _MockClipEditorBloc mockClipBloc;
    late _MockTimelineOverlayBloc mockOverlayBloc;
    late _MockVideoEditorFilterBloc mockFilterBloc;
    late ProVideoEditor originalProVideoEditor;

    setUpAll(() {
      registerFallbackValue(const VideoEditorSeekRequested(Duration.zero));
    });

    setUp(() {
      originalProVideoEditor = ProVideoEditor.instance;
      ProVideoEditor.instance = _MockProVideoEditor();

      mockMainBloc = _MockVideoEditorMainBloc();
      mockClipBloc = _MockClipEditorBloc();
      mockOverlayBloc = _MockTimelineOverlayBloc();
      mockFilterBloc = _MockVideoEditorFilterBloc();

      when(() => mockMainBloc.state).thenReturn(const VideoEditorMainState());
      when(
        () => mockMainBloc.stream,
      ).thenAnswer((_) => const Stream<VideoEditorMainState>.empty());
      when(() => mockClipBloc.state).thenReturn(const ClipEditorState());
      when(
        () => mockClipBloc.stream,
      ).thenAnswer((_) => const Stream<ClipEditorState>.empty());
      when(
        () => mockOverlayBloc.state,
      ).thenReturn(const TimelineOverlayState());
      when(
        () => mockOverlayBloc.stream,
      ).thenAnswer((_) => const Stream<TimelineOverlayState>.empty());
      when(
        () => mockFilterBloc.state,
      ).thenReturn(const VideoEditorFilterState(filters: []));
      when(
        () => mockFilterBloc.stream,
      ).thenAnswer((_) => const Stream<VideoEditorFilterState>.empty());
    });

    tearDown(() {
      ProVideoEditor.instance = originalProVideoEditor;
    });

    Widget buildWidget({
      VideoEditorMainState? mainState,
      ClipEditorState? clipState,
      ProImageEditorState? editor,
    }) {
      if (mainState != null) {
        when(() => mockMainBloc.state).thenReturn(mainState);
      }
      if (clipState != null) {
        when(() => mockClipBloc.state).thenReturn(clipState);
      }

      return ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
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
              onAddEditTextLayer: ([layer]) async => null,
              child: MultiBlocProvider(
                providers: [
                  BlocProvider<VideoEditorMainBloc>.value(value: mockMainBloc),
                  BlocProvider<ClipEditorBloc>.value(value: mockClipBloc),
                  BlocProvider<TimelineOverlayBloc>.value(
                    value: mockOverlayBloc,
                  ),
                  BlocProvider<VideoEditorFilterBloc>.value(
                    value: mockFilterBloc,
                  ),
                ],

                child: const VideoEditorTimelineScaffold(),
              ),
            ),
          ),
        ),
      );
    }

    group('empty state', () {
      testWidgets('renders $SizedBox when clips are empty', (tester) async {
        await tester.pumpWidget(
          buildWidget(clipState: const ClipEditorState()),
        );

        // Should shrink — no header, no strip, no playhead
        expect(find.byType(VideoEditorTimelineHeader), findsNothing);
        expect(find.byType(VideoEditorTimelineClipStrip), findsNothing);
      });
    });

    group('renders', () {
      testWidgets('renders timeline with clips', (tester) async {
        final clips = [
          _createTestClip(id: 'clip1', seconds: 3),
          _createTestClip(id: 'clip2', seconds: 5),
        ];

        await tester.pumpWidget(
          buildWidget(clipState: ClipEditorState(clips: clips)),
        );

        expect(find.byType(VideoEditorTimelineScaffold), findsOneWidget);
      });

      testWidgets('renders $VideoEditorTimelineHeader', (tester) async {
        final clips = [_createTestClip(id: 'a')];

        await tester.pumpWidget(
          buildWidget(clipState: ClipEditorState(clips: clips)),
        );

        expect(find.byType(VideoEditorTimelineHeader), findsOneWidget);
      });

      testWidgets('renders $VideoEditorTimelinePlayhead', (tester) async {
        final clips = [_createTestClip(id: 'a')];

        await tester.pumpWidget(
          buildWidget(clipState: ClipEditorState(clips: clips)),
        );

        expect(find.byType(VideoEditorTimelinePlayhead), findsOneWidget);
      });

      testWidgets('renders $VideoEditorTimelineRulesIndicator', (tester) async {
        final clips = [_createTestClip(id: 'a')];

        await tester.pumpWidget(
          buildWidget(clipState: ClipEditorState(clips: clips)),
        );

        expect(find.byType(VideoEditorTimelineRulesIndicator), findsOneWidget);
      });

      testWidgets('renders $VideoEditorTimelineClipStrip', (tester) async {
        final clips = [_createTestClip(id: 'a')];

        await tester.pumpWidget(
          buildWidget(clipState: ClipEditorState(clips: clips)),
        );

        expect(find.byType(VideoEditorTimelineClipStrip), findsOneWidget);
      });

      testWidgets('does not show controls when not editing', (tester) async {
        final clips = [_createTestClip(id: 'a')];

        await tester.pumpWidget(
          buildWidget(clipState: ClipEditorState(clips: clips)),
        );

        expect(find.text('Done'), findsNothing);
      });
    });

    group('playhead visibility', () {
      testWidgets('playhead is visible when not reordering', (tester) async {
        final clips = [_createTestClip(id: 'a')];

        await tester.pumpWidget(
          buildWidget(
            mainState: const VideoEditorMainState(),
            clipState: ClipEditorState(clips: clips),
          ),
        );

        final opacity = tester.widget<AnimatedOpacity>(
          find.byWidgetPredicate(
            (widget) =>
                widget is AnimatedOpacity && widget.child is IgnorePointer,
          ),
        );
        expect(opacity.opacity, equals(1.0));
      });

      testWidgets('playhead is hidden when reordering', (tester) async {
        final clips = [_createTestClip(id: 'a')];

        await tester.pumpWidget(
          buildWidget(
            mainState: const VideoEditorMainState(isReordering: true),
            clipState: ClipEditorState(clips: clips),
          ),
        );

        final opacity = tester.widget<AnimatedOpacity>(
          find.byWidgetPredicate(
            (widget) =>
                widget is AnimatedOpacity && widget.child is IgnorePointer,
          ),
        );
        expect(opacity.opacity, equals(0.0));
      });
    });

    group('ruler visibility', () {
      testWidgets('ruler fades out when reordering', (tester) async {
        final clips = [
          _createTestClip(id: 'a'),
          _createTestClip(id: 'b', seconds: 3),
        ];

        await tester.pumpWidget(
          buildWidget(
            mainState: const VideoEditorMainState(isReordering: true),
            clipState: ClipEditorState(clips: clips),
          ),
        );

        final opacity = tester.widget<AnimatedOpacity>(
          find.ancestor(
            of: find.byType(VideoEditorTimelineRulesIndicator),
            matching: find.byType(AnimatedOpacity),
          ),
        );
        expect(opacity.opacity, equals(0.0));
      });

      testWidgets('ruler is visible when not reordering', (tester) async {
        final clips = [_createTestClip(id: 'a')];

        await tester.pumpWidget(
          buildWidget(
            mainState: const VideoEditorMainState(),
            clipState: ClipEditorState(clips: clips),
          ),
        );

        final opacity = tester.widget<AnimatedOpacity>(
          find.ancestor(
            of: find.byType(VideoEditorTimelineRulesIndicator),
            matching: find.byType(AnimatedOpacity),
          ),
        );
        expect(opacity.opacity, equals(1.0));
      });
    });

    group('accessibility', () {
      testWidgets('has Video timeline semantics label', (tester) async {
        final clips = [_createTestClip(id: 'a')];

        await tester.pumpWidget(
          buildWidget(clipState: ClipEditorState(clips: clips)),
        );

        expect(find.bySemanticsLabel('Video timeline'), findsOneWidget);
      });
    });

    group('scrollable content', () {
      testWidgets('uses horizontal SingleChildScrollView', (tester) async {
        final clips = [_createTestClip(id: 'a')];

        await tester.pumpWidget(
          buildWidget(clipState: ClipEditorState(clips: clips)),
        );

        expect(find.byType(SingleChildScrollView), findsWidgets);
      });
    });

    group('scrub pause', () {
      Finder timelineScrollView() => find.ancestor(
        of: find.byType(VideoEditorTimelineBody),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is SingleChildScrollView &&
              widget.scrollDirection == Axis.horizontal,
        ),
      );

      testWidgets('pauses playback when the user drags the timeline', (
        tester,
      ) async {
        final clips = [_createTestClip(id: 'a', seconds: 20)];

        await tester.pumpWidget(
          buildWidget(clipState: ClipEditorState(clips: clips)),
        );

        await tester.drag(
          timelineScrollView(),
          const Offset(-100, 0),
        );
        await tester.pumpAndSettle();

        verify(
          () => mockMainBloc.add(
            const VideoEditorExternalPauseRequested(isPaused: true),
          ),
        ).called(1);

        // The scrub also seeks — the user-visible payload the pause enables.
        // Throttled on real wall-clock, so assert at-least-once.
        verify(
          () => mockMainBloc.add(any(that: isA<VideoEditorSeekRequested>())),
        ).called(isPositive);
      });

      testWidgets(
        'pauses playback when a drag grabs the timeline while a '
        'playback-sync animation restarts mid touch-down',
        (tester) async {
          // Regression: while playing, every position update animates the
          // timeline to follow the playhead. When the finger lands in the
          // idle gap between two follow animations and the next animateTo
          // restarts during the touch-down hold, the drag then begins from
          // an already-scrolling activity, so Flutter emits no
          // ScrollStartNotification — the scrub used to go undetected and
          // the video kept playing, fighting the user's drag.
          final clips = [_createTestClip(id: 'a', seconds: 20)];
          final states = StreamController<VideoEditorMainState>.broadcast();
          addTearDown(states.close);
          whenListen(
            mockMainBloc,
            states.stream,
            initialState: const VideoEditorMainState(),
          );

          await tester.pumpWidget(
            buildWidget(clipState: ClipEditorState(clips: clips)),
          );

          // Playback position update → follow animation runs to completion,
          // leaving the scroll position idle.
          states.add(
            const VideoEditorMainState(
              currentPosition: Duration(seconds: 2),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 250));
          await tester.pump(const Duration(milliseconds: 50));

          // The follow animation scrolls via a DrivenScrollActivity
          // (dragDetails == null); it must never be misread as a user scrub.
          // This negative case is the exact discriminator the fix relies on.
          verifyNever(
            () => mockMainBloc.add(
              const VideoEditorExternalPauseRequested(isPaused: true),
            ),
          );

          // Touch down on the clip strip while idle. The clip's tap /
          // long-press recognizers join the gesture arena, so the scroll
          // drag only wins after touch slop — as with a real finger on a
          // clip. (Mid animation the viewport ignores pointers, so the
          // scroll drag would win the arena instantly at touch-down, which
          // sidesteps the race.)
          final strip = find.byType(VideoEditorTimelineClipStrip);
          final touchPoint =
              tester.getTopLeft(strip) +
              Offset(60, tester.getSize(strip).height / 2);
          final gesture = await tester.startGesture(touchPoint);

          // The next position update restarts the follow animation while
          // the finger is down, swallowing the upcoming
          // ScrollStartNotification.
          states.add(
            const VideoEditorMainState(
              currentPosition: Duration(milliseconds: 2200),
            ),
          );
          await tester.pump();

          // First move wins the arena and starts the drag mid animation
          // (no start notification); the second move emits the first
          // drag-driven ScrollUpdateNotification.
          await gesture.moveBy(const Offset(-40, 0));
          await tester.pump();
          await gesture.moveBy(const Offset(-40, 0));
          await tester.pump();

          verify(
            () => mockMainBloc.add(
              const VideoEditorExternalPauseRequested(isPaused: true),
            ),
          ).called(1);

          // The scrub also seeks — the user-visible payload the pause enables.
          // Throttled on real wall-clock, so assert at-least-once.
          verify(
            () => mockMainBloc.add(any(that: isA<VideoEditorSeekRequested>())),
          ).called(isPositive);

          await gesture.up();
          await tester.pumpAndSettle();

          // ScrollEnd cleared _isUserScrolling, re-enabling follow-sync: a new
          // position update now drives a fresh follow animation. The scrub left
          // the timeline scrolled forward, so a jump back near the start scrolls
          // it toward zero — proving the follow ran, not that the flag stayed
          // stuck.
          final scrollView = tester.widget<SingleChildScrollView>(
            timelineScrollView(),
          );
          final offsetBeforeFollow = scrollView.controller!.offset;
          expect(offsetBeforeFollow, greaterThan(0));
          states.add(
            const VideoEditorMainState(
              currentPosition: Duration(milliseconds: 500),
            ),
          );
          await tester.pumpAndSettle();

          expect(
            scrollView.controller!.offset,
            lessThan(offsetBeforeFollow),
          );
        },
      );
    });

    group('marker-mode mutual exclusion', () {
      testWidgets(
        'entering marker mode clears volume mode, clip edit, and overlay '
        'selection',
        (tester) async {
          final clips = [_createTestClip(id: 'a')];
          final mainStates = StreamController<VideoEditorMainState>.broadcast();
          addTearDown(mainStates.close);
          // Start already in volume mode with a clip being edited: entering
          // marker mode must clear all of it. Volume mode starts on so the
          // enter-volume listener can't also fire and inflate the counts.
          whenListen(
            mockMainBloc,
            mainStates.stream,
            initialState: const VideoEditorMainState(isVolumeEditMode: true),
          );

          await tester.pumpWidget(
            buildWidget(
              clipState: ClipEditorState(clips: clips, isEditing: true),
            ),
          );

          mainStates.add(
            const VideoEditorMainState(
              isMarkerMode: true,
              isVolumeEditMode: true,
            ),
          );
          await tester.pump();

          verify(
            () => mockClipBloc.add(const ClipEditorEditingToggled()),
          ).called(1);
          verify(
            () => mockOverlayBloc.add(const TimelineOverlayItemSelected(null)),
          ).called(1);
          verify(
            () => mockMainBloc.add(const VideoEditorVolumeEditModeToggled()),
          ).called(1);
        },
      );

      testWidgets('starting clip editing exits marker mode', (tester) async {
        final clips = [_createTestClip(id: 'a')];
        final clipStates = StreamController<ClipEditorState>.broadcast();
        addTearDown(clipStates.close);
        whenListen(
          mockMainBloc,
          const Stream<VideoEditorMainState>.empty(),
          initialState: const VideoEditorMainState(isMarkerMode: true),
        );
        whenListen(
          mockClipBloc,
          clipStates.stream,
          initialState: ClipEditorState(clips: clips),
        );

        await tester.pumpWidget(buildWidget());

        clipStates.add(ClipEditorState(clips: clips, isEditing: true));
        await tester.pump();

        verify(
          () => mockMainBloc.add(
            const VideoEditorMarkerModeChanged(isActive: false),
          ),
        ).called(1);
      });
    });

    group('stop-motion auto-zoom', () {
      late Directory tempDir;

      setUp(() {
        tempDir = Directory.systemTemp.createTempSync('tl_auto_zoom');
      });
      tearDown(() => tempDir.deleteSync(recursive: true));

      // Drives the empty→populated transition through the mock: the state stub
      // is flipped to [populated] before the stream emit, so `context.select`
      // (which reads `bloc.state`) reads the fresh value when the always-mounted
      // BlocListener catches the transition. Mirrors production, where the
      // composition is dispatched after the (empty) first build.
      Future<void> transitionTo(
        WidgetTester tester,
        StreamController<ClipEditorState> clipStates,
        ClipEditorState populated,
      ) async {
        when(() => mockClipBloc.state).thenReturn(populated);
        clipStates.add(populated);
        // Two pumps: the broadcast emit is delivered on a microtask after the
        // first frame, then the second frame builds the rebuilt tree.
        await tester.pump();
        await tester.pump();
      }

      testWidgets('zooms in when the first stop-motion composition loads', (
        tester,
      ) async {
        final clipStates = StreamController<ClipEditorState>.broadcast();
        addTearDown(clipStates.close);
        when(() => mockClipBloc.stream).thenAnswer((_) => clipStates.stream);
        when(() => mockClipBloc.state).thenReturn(const ClipEditorState());

        await tester.pumpWidget(buildWidget());
        await tester.pump();
        // The empty first build renders nothing but keeps the listener mounted.
        expect(find.byType(VideoEditorTimelineInteractiveBody), findsNothing);

        final clip = _stopMotionClip(tempDir);
        await transitionTo(tester, clipStates, ClipEditorState(clips: [clip]));

        final body = tester.widget<VideoEditorTimelineInteractiveBody>(
          find.byType(VideoEditorTimelineInteractiveBody),
        );
        // Zoomed to the computed stop-motion default, above the video default
        // that would render the tens-of-ms stills a couple of pixels wide.
        expect(
          body.pixelsPerSecond,
          stopMotionInitialPixelsPerSecond(clip.stopMotionFrames!),
        );
        expect(
          body.pixelsPerSecond,
          greaterThan(TimelineConstants.pixelsPerSecond),
        );
      });

      testWidgets('leaves the zoom at the video default for a regular '
          'composition', (tester) async {
        final clipStates = StreamController<ClipEditorState>.broadcast();
        addTearDown(clipStates.close);
        when(() => mockClipBloc.stream).thenAnswer((_) => clipStates.stream);
        when(() => mockClipBloc.state).thenReturn(const ClipEditorState());

        await tester.pumpWidget(buildWidget());
        await tester.pump();

        await transitionTo(
          tester,
          clipStates,
          ClipEditorState(clips: [_createTestClip(id: 'a')]),
        );

        final body = tester.widget<VideoEditorTimelineInteractiveBody>(
          find.byType(VideoEditorTimelineInteractiveBody),
        );
        expect(body.pixelsPerSecond, TimelineConstants.pixelsPerSecond);
      });
    });

    // #6401 on the trim path: dragging a trim handle back out lengthens the
    // composition, and a sound clamped to the trimmed end has to follow it.
    group('trim-extension sound growth', () {
      late _MockProImageEditorState editor;
      late _MockStateManager stateManager;

      final coveringSound = AudioEvent(
        id: 'sound-1',
        pubkey: 'bundled',
        createdAt: 0,
        url: 'asset://sounds/loop.mp3',
        duration: 30,
        endTime: const Duration(seconds: 2),
      );

      setUp(() {
        editor = _MockProImageEditorState();
        stateManager = _MockStateManager();

        when(() => editor.stateManager).thenReturn(stateManager);
        when(() => stateManager.activeMeta).thenReturn({
          VideoEditorConstants.audioStateHistoryKey: [coveringSound.toJson()],
        });
        when(
          () => editor.addHistory(
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
        when(() => editor.setState(any())).thenAnswer((invocation) {
          (invocation.positionalArguments.single as VoidCallback)();
        });
      });

      testWidgets('extending a trim grows a sound that covered the trimmed '
          'end onto the restored end', (tester) async {
        // A 3s clip trimmed to 2s; the sound covers the 2s composition.
        final trimmed = _createTestClip(
          id: 'a',
          seconds: 3,
        ).copyWith(trimEnd: const Duration(seconds: 1));
        when(
          () => mockClipBloc.state,
        ).thenReturn(ClipEditorState(clips: [trimmed]));

        await tester.pumpWidget(buildWidget(editor: editor));
        await tester.pump();

        final strip = tester.widget<VideoEditorTimelineClipStrip>(
          find.byType(VideoEditorTimelineClipStrip),
        );

        // Drag start captures the trimmed composition as the previous clips.
        strip.onTrimDragChanged!(true);
        await tester.pump();

        // The user drags the end handle back out to the full 3s; the bloc
        // state now carries the restored clip.
        when(() => mockClipBloc.state).thenReturn(
          ClipEditorState(clips: [_createTestClip(id: 'a', seconds: 3)]),
        );
        strip.onTrimDragChanged!(false);
        await tester.pump();

        final meta =
            verify(
                  () => editor.addHistory(
                    layers: any(named: 'layers'),
                    filters: any(named: 'filters'),
                    meta: captureAny(named: 'meta'),
                    newLayer: any(named: 'newLayer'),
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
                as Map<String, dynamic>;
        final raw =
            meta[VideoEditorConstants.audioStateHistoryKey] as List<dynamic>;
        final audio = raw
            .cast<Map<String, dynamic>>()
            .map(AudioEvent.fromJson)
            .toList();

        expect(audio.single.endTime, const Duration(seconds: 3));
      });
    });
  });
}

/// A frames-only stop-motion clip backed by real 1×1 PNG files under [dir] so
/// the timeline frame strip's `Image.file` decode does not raise a load error.
DivineVideoClip _stopMotionClip(Directory dir) {
  final pngBytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
    '+M8AAAMBAQDJ/IY1AAAAAElFTkSuQmCC',
  );
  final frames = [
    for (var i = 0; i < 4; i++)
      StopMotionClipFrame(
        path: (File('${dir.path}/f$i.png')..writeAsBytesSync(pngBytes)).path,
        duration: const Duration(milliseconds: 83),
      ),
  ];
  return DivineVideoClip(
    id: 'stop_motion',
    stopMotionFrames: frames,
    duration: const Duration(milliseconds: 332),
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
