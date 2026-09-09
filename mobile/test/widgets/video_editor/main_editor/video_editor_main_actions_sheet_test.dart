// ABOUTME: Widget tests for VideoEditorMainActionsSheet.
// ABOUTME: Verifies action rendering and callback behavior.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/blocs/video_editor/tune_editor/video_editor_tune_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/stop_motion_clip_frame.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_main_actions_sheet.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

class _MockVideoEditorMainBloc
    extends MockBloc<VideoEditorMainEvent, VideoEditorMainState>
    implements VideoEditorMainBloc {}

class _MockClipEditorBloc extends MockBloc<ClipEditorEvent, ClipEditorState>
    implements ClipEditorBloc {}

class _MockTimelineOverlayBloc
    extends MockBloc<TimelineOverlayEvent, TimelineOverlayState>
    implements TimelineOverlayBloc {}

class _MockVideoEditorTuneBloc
    extends MockBloc<VideoEditorTuneEvent, VideoEditorTuneState>
    implements VideoEditorTuneBloc {}

/// [ClipEditorState.totalDuration] is derived from clips; this fake supplies it
/// directly so tests don't need to construct clip fixtures.
class _FakeClipEditorState extends ClipEditorState {
  const _FakeClipEditorState(this._total);

  final Duration _total;

  @override
  Duration get totalDuration => _total;
}

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  setUpAll(() {
    registerFallbackValue(const VideoEditorTuneSessionStarted());
    registerFallbackValue(const VideoEditorMarkerModeChanged(isActive: false));
  });

  group(VideoEditorMainActionsSheet, () {
    late _MockVideoEditorMainBloc mainBloc;
    late _MockClipEditorBloc clipBloc;
    late _MockTimelineOverlayBloc timelineOverlayBloc;
    late _MockVideoEditorTuneBloc tuneBloc;

    setUp(() {
      mainBloc = _MockVideoEditorMainBloc();
      clipBloc = _MockClipEditorBloc();
      timelineOverlayBloc = _MockTimelineOverlayBloc();
      tuneBloc = _MockVideoEditorTuneBloc();

      when(() => mainBloc.state).thenReturn(const VideoEditorMainState());
      when(() => clipBloc.state).thenReturn(const ClipEditorState());
      when(
        () => timelineOverlayBloc.state,
      ).thenReturn(const TimelineOverlayState());
      when(() => tuneBloc.state).thenReturn(
        const VideoEditorTuneState(
          adjustments: VideoEditorConstants.tuneAdjustments,
        ),
      );
    });

    testWidgets('renders all action labels', (tester) async {
      await tester.pumpWidget(
        _buildWidget(
          mainBloc: mainBloc,
          clipBloc: clipBloc,
          timelineOverlayBloc: timelineOverlayBloc,
        ),
      );

      expect(find.text(l10n.videoEditorCameraLabel), findsOneWidget);
      expect(find.text(l10n.videoEditorLibraryLabel), findsOneWidget);
      expect(find.text(l10n.videoEditorAudioLabel), findsOneWidget);
      expect(find.text(l10n.videoEditorVoiceOverLabel), findsOneWidget);
      expect(find.text(l10n.videoEditorTextLabel), findsOneWidget);
      expect(find.text(l10n.videoEditorDrawLabel), findsOneWidget);
      expect(find.text(l10n.videoEditorFilterLabel), findsOneWidget);
      expect(find.text(l10n.videoEditorStickers), findsOneWidget);
      expect(find.text(l10n.videoEditorMarkerLabel), findsOneWidget);
    });

    testWidgets('hides the marker action for a stop-motion composition', (
      tester,
    ) async {
      when(() => clipBloc.state).thenReturn(
        ClipEditorState(
          clips: [
            DivineVideoClip(
              id: 'sm1',
              stopMotionFrames: const [
                StopMotionClipFrame(
                  path: '/frames/f0.jpg',
                  duration: Duration(milliseconds: 83),
                ),
              ],
              duration: const Duration(milliseconds: 83),
              recordedAt: DateTime(2024),
              targetAspectRatio: model.AspectRatio.vertical,
              originalAspectRatio: 9 / 16,
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        _buildWidget(
          mainBloc: mainBloc,
          clipBloc: clipBloc,
          timelineOverlayBloc: timelineOverlayBloc,
        ),
      );

      expect(find.text(l10n.videoEditorMarkerLabel), findsNothing);
      // The rest of the actions stay available.
      expect(find.text(l10n.videoEditorCameraLabel), findsOneWidget);
    });

    testWidgets('tap on Clips triggers onOpenClipsEditor', (tester) async {
      var openedClips = false;

      await tester.pumpWidget(
        _buildWidget(
          mainBloc: mainBloc,
          clipBloc: clipBloc,
          timelineOverlayBloc: timelineOverlayBloc,
          onOpenClipsEditor: () => openedClips = true,
        ),
      );

      await tester.tap(
        find.bySemanticsLabel(l10n.videoEditorOpenLibrarySemanticLabel),
      );
      await tester.pumpAndSettle();

      expect(openedClips, isTrue);
    });

    testWidgets('tap on Audio triggers onOpenMusicLibrary', (tester) async {
      var openedMusic = false;

      await tester.pumpWidget(
        _buildWidget(
          mainBloc: mainBloc,
          clipBloc: clipBloc,
          timelineOverlayBloc: timelineOverlayBloc,
          onOpenMusicLibrary: () => openedMusic = true,
        ),
      );

      await tester.tap(
        find.bySemanticsLabel(l10n.videoEditorOpenAudioSemanticLabel),
      );
      await tester.pumpAndSettle();

      expect(openedMusic, isTrue);
    });

    testWidgets('tap on Voice over triggers onOpenVoiceOver', (tester) async {
      var openedVoiceOver = false;

      await tester.pumpWidget(
        _buildWidget(
          mainBloc: mainBloc,
          clipBloc: clipBloc,
          timelineOverlayBloc: timelineOverlayBloc,
          onOpenVoiceOver: () => openedVoiceOver = true,
        ),
      );

      await tester.tap(
        find.bySemanticsLabel(l10n.videoEditorOpenVoiceOverSemanticLabel),
      );
      await tester.pumpAndSettle();

      expect(openedVoiceOver, isTrue);
    });

    testWidgets('tap on Captions triggers onOpenCaptions', (tester) async {
      var openedCaptions = false;

      await tester.pumpWidget(
        _buildWidget(
          mainBloc: mainBloc,
          clipBloc: clipBloc,
          timelineOverlayBloc: timelineOverlayBloc,
          onOpenCaptions: () => openedCaptions = true,
        ),
      );

      await tester.tap(
        find.bySemanticsLabel(l10n.videoEditorOpenCaptionsSemanticLabel),
      );
      await tester.pumpAndSettle();

      expect(openedCaptions, isTrue);
    });

    testWidgets('tap on Stickers triggers onAddStickers', (tester) async {
      var addedStickers = false;

      await tester.pumpWidget(
        _buildWidget(
          mainBloc: mainBloc,
          clipBloc: clipBloc,
          timelineOverlayBloc: timelineOverlayBloc,
          onAddStickers: () => addedStickers = true,
        ),
      );

      await tester.tap(
        find.bySemanticsLabel(l10n.videoEditorOpenStickerSemanticLabel),
      );
      await tester.pumpAndSettle();

      expect(addedStickers, isTrue);
    });

    testWidgets('tap on Marker enters marker mode', (tester) async {
      when(
        () => clipBloc.state,
      ).thenReturn(const _FakeClipEditorState(Duration(seconds: 5)));

      await tester.pumpWidget(
        _buildWidget(
          mainBloc: mainBloc,
          clipBloc: clipBloc,
          timelineOverlayBloc: timelineOverlayBloc,
        ),
      );

      await tester.tap(
        find.bySemanticsLabel(l10n.videoEditorAddTimelineMarkerSemanticLabel),
      );
      await tester.pumpAndSettle();

      verify(
        () => mainBloc.add(
          const VideoEditorMarkerModeChanged(isActive: true),
        ),
      ).called(1);
    });

    testWidgets('tap on Marker does nothing when there is no duration', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildWidget(
          mainBloc: mainBloc,
          clipBloc: clipBloc,
          timelineOverlayBloc: timelineOverlayBloc,
        ),
      );

      await tester.tap(
        find.bySemanticsLabel(l10n.videoEditorAddTimelineMarkerSemanticLabel),
      );
      await tester.pumpAndSettle();

      verifyNever(
        () => mainBloc.add(any(that: isA<VideoEditorMarkerModeChanged>())),
      );
    });

    // Regression: the sheet opens on a separate route, so `show` must
    // re-provide every bloc its actions read. When the tune bloc was left out,
    // tapping Adjust threw a ProviderNotFoundException instead of starting a
    // tune session.
    testWidgets(
      'tap on Adjust in the shown sheet starts a tune session',
      (tester) async {
        await tester.pumpWidget(
          _buildShowHost(
            mainBloc: mainBloc,
            clipBloc: clipBloc,
            timelineOverlayBloc: timelineOverlayBloc,
            tuneBloc: tuneBloc,
          ),
        );

        await tester.tap(find.byKey(const Key('open-sheet')));
        await tester.pumpAndSettle();

        await tester.tap(
          find.bySemanticsLabel(l10n.videoEditorOpenTuneSemanticLabel),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        verify(
          () => tuneBloc.add(any(that: isA<VideoEditorTuneSessionStarted>())),
        ).called(1);
      },
    );
  });
}

/// Wraps [child] in the app + localization shell every test here needs.
Widget _app({required Widget child}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

/// Builds a [VideoEditorScope] with test defaults, overriding only the
/// callbacks a given test asserts on.
VideoEditorScope _scope({
  Widget? child,
  VoidCallback? onOpenClipsEditor,
  VoidCallback? onOpenMusicLibrary,
  VoidCallback? onOpenVoiceOver,
  VoidCallback? onOpenCaptions,
  VoidCallback? onAddStickers,
}) => VideoEditorScope(
  editorKey: GlobalKey<ProImageEditorState>(),
  removeAreaKey: GlobalKey(),
  onOpenCamera: () {},
  onAddStickers: onAddStickers ?? () {},
  onOpenClipsEditor: onOpenClipsEditor ?? () {},
  onAddEditTextLayer: ([layer]) async => null,
  onOpenMusicLibrary: onOpenMusicLibrary ?? () {},
  onOpenVoiceOver: onOpenVoiceOver ?? () {},
  onOpenCaptions: onOpenCaptions ?? () {},
  originalClipAspectRatio: 9 / 16,
  bodySizeNotifier: ValueNotifier(const Size(400, 800)),
  zoomMatrixNotifier: ValueNotifier(Matrix4.identity()),
  playTimeNotifier: ValueNotifier(Duration.zero),
  playheadAdvancingNotifier: ValueNotifier<bool>(false),
  fromLibrary: false,
  child: child ?? const SizedBox.shrink(),
);

/// Hosts a button that opens the real sheet via
/// [VideoEditorMainActionsSheet.show], so the sheet's own `MultiBlocProvider`
/// (not the host's) is what resolves the blocs each action reads.
Widget _buildShowHost({
  required _MockVideoEditorMainBloc mainBloc,
  required _MockClipEditorBloc clipBloc,
  required _MockTimelineOverlayBloc timelineOverlayBloc,
  required _MockVideoEditorTuneBloc tuneBloc,
}) => _app(
  child: MultiBlocProvider(
    providers: [
      BlocProvider<VideoEditorMainBloc>.value(value: mainBloc),
      BlocProvider<ClipEditorBloc>.value(value: clipBloc),
      BlocProvider<TimelineOverlayBloc>.value(value: timelineOverlayBloc),
      BlocProvider<VideoEditorTuneBloc>.value(value: tuneBloc),
    ],
    child: _scope(
      child: Builder(
        builder: (context) => ElevatedButton(
          key: const Key('open-sheet'),
          onPressed: () => VideoEditorMainActionsSheet.show(context),
          child: const Text('open'),
        ),
      ),
    ),
  ),
);

/// Renders the sheet directly under a host-provided bloc list, for asserting
/// individual action callbacks without driving the `show` route. The sheet
/// reads its scope from the constructor, so no `VideoEditorScope` ancestor is
/// needed here (unlike [_buildShowHost], where `show` reads it via context).
Widget _buildWidget({
  required _MockVideoEditorMainBloc mainBloc,
  required _MockClipEditorBloc clipBloc,
  required _MockTimelineOverlayBloc timelineOverlayBloc,
  VoidCallback? onOpenClipsEditor,
  VoidCallback? onOpenMusicLibrary,
  VoidCallback? onOpenVoiceOver,
  VoidCallback? onOpenCaptions,
  VoidCallback? onAddStickers,
}) => _app(
  child: MultiBlocProvider(
    providers: [
      BlocProvider<VideoEditorMainBloc>.value(value: mainBloc),
      BlocProvider<ClipEditorBloc>.value(value: clipBloc),
      BlocProvider<TimelineOverlayBloc>.value(value: timelineOverlayBloc),
    ],
    child: VideoEditorMainActionsSheet(
      scope: _scope(
        onOpenClipsEditor: onOpenClipsEditor,
        onOpenMusicLibrary: onOpenMusicLibrary,
        onOpenVoiceOver: onOpenVoiceOver,
        onOpenCaptions: onOpenCaptions,
        onAddStickers: onAddStickers,
      ),
    ),
  ),
);
