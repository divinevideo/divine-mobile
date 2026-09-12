// ABOUTME: Widget tests for TimelineMarkerControls.
// ABOUTME: Verifies add/delete gating and the marker-mode exit action.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_timeline_marker_controls.dart';

class _MockVideoEditorMainBloc
    extends MockBloc<VideoEditorMainEvent, VideoEditorMainState>
    implements VideoEditorMainBloc {}

class _MockClipEditorBloc extends MockBloc<ClipEditorEvent, ClipEditorState>
    implements ClipEditorBloc {}

class _MockTimelineOverlayBloc
    extends MockBloc<TimelineOverlayEvent, TimelineOverlayState>
    implements TimelineOverlayBloc {}

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
    registerFallbackValue(const TimelineMarkerRemoved(Duration.zero));
  });

  group(TimelineMarkerControls, () {
    late _MockVideoEditorMainBloc mainBloc;
    late _MockClipEditorBloc clipBloc;
    late _MockTimelineOverlayBloc overlayBloc;

    setUp(() {
      mainBloc = _MockVideoEditorMainBloc();
      clipBloc = _MockClipEditorBloc();
      overlayBloc = _MockTimelineOverlayBloc();

      when(() => clipBloc.state).thenReturn(
        const _FakeClipEditorState(Duration(seconds: 10)),
      );
      when(
        () => mainBloc.stream,
      ).thenAnswer((_) => const Stream<VideoEditorMainState>.empty());
      when(
        () => clipBloc.stream,
      ).thenAnswer((_) => const Stream<ClipEditorState>.empty());
      when(
        () => overlayBloc.stream,
      ).thenAnswer((_) => const Stream<TimelineOverlayState>.empty());
    });

    Widget build({
      required Duration currentPosition,
      required List<Duration> markers,
      ValueNotifier<Duration>? playhead,
    }) {
      when(
        () => mainBloc.state,
      ).thenReturn(const VideoEditorMainState(isMarkerMode: true));
      when(() => overlayBloc.state).thenReturn(
        TimelineOverlayState(timelineMarkers: markers),
      );

      return MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MultiBlocProvider(
            providers: [
              BlocProvider<VideoEditorMainBloc>.value(value: mainBloc),
              BlocProvider<ClipEditorBloc>.value(value: clipBloc),
              BlocProvider<TimelineOverlayBloc>.value(value: overlayBloc),
            ],
            child: TimelineMarkerControls(
              playheadPosition: playhead ?? ValueNotifier(currentPosition),
            ),
          ),
        ),
      );
    }

    Finder addButton() =>
        find.bySemanticsLabel(l10n.videoEditorAddTimelineMarkerSemanticLabel);
    Finder deleteButton() => find.bySemanticsLabel(
      l10n.videoEditorRemoveTimelineMarkerAtPlayheadSemanticLabel,
    );

    testWidgets('renders add, delete and done controls', (tester) async {
      await tester.pumpWidget(
        build(currentPosition: const Duration(seconds: 2), markers: const []),
      );

      expect(addButton(), findsOneWidget);
      expect(deleteButton(), findsOneWidget);
      expect(find.text(l10n.videoEditorDoneLabel), findsOneWidget);
    });

    testWidgets('adds a marker at the playhead when not on a marker', (
      tester,
    ) async {
      await tester.pumpWidget(
        build(currentPosition: const Duration(seconds: 3), markers: const []),
      );

      await tester.tap(addButton());
      await tester.pump();

      verify(
        () => overlayBloc.add(
          const TimelineMarkerAdded(
            position: Duration(seconds: 3),
            totalDuration: Duration(seconds: 10),
          ),
        ),
      ).called(1);
    });

    testWidgets('deletes the marker under the playhead', (tester) async {
      const marker = Duration(seconds: 4);
      await tester.pumpWidget(
        build(currentPosition: marker, markers: const [marker]),
      );

      await tester.tap(deleteButton());
      await tester.pump();

      verify(
        () => overlayBloc.add(const TimelineMarkerRemoved(marker)),
      ).called(1);
    });

    testWidgets('does not add while the playhead sits on a marker', (
      tester,
    ) async {
      const marker = Duration(seconds: 4);
      await tester.pumpWidget(
        build(currentPosition: marker, markers: const [marker]),
      );

      await tester.tap(addButton());
      await tester.pump();

      verifyNever(
        () => overlayBloc.add(any(that: isA<TimelineMarkerAdded>())),
      );
    });

    testWidgets(
      'add re-enables as the playhead scrolls off a marker, tracking the '
      'notifier without any bloc update',
      (tester) async {
        const marker = Duration(seconds: 4);
        final playhead = ValueNotifier<Duration>(marker);
        addTearDown(playhead.dispose);

        await tester.pumpWidget(
          build(
            currentPosition: marker,
            markers: const [marker],
            playhead: playhead,
          ),
        );

        // Sitting on the marker: add is blocked.
        await tester.tap(addButton());
        await tester.pump();
        verifyNever(
          () => overlayBloc.add(any(that: isA<TimelineMarkerAdded>())),
        );

        // Scrolling moves only the visual playhead notifier — the player's
        // bloc position never changes here. Add must re-enable regardless.
        playhead.value = const Duration(seconds: 6);
        await tester.pump();

        await tester.tap(addButton());
        await tester.pump();
        verify(
          () => overlayBloc.add(
            const TimelineMarkerAdded(
              position: Duration(seconds: 6),
              totalDuration: Duration(seconds: 10),
            ),
          ),
        ).called(1);
      },
    );

    testWidgets('Done leaves marker mode', (tester) async {
      await tester.pumpWidget(
        build(currentPosition: const Duration(seconds: 2), markers: const []),
      );

      await tester.tap(
        find.bySemanticsLabel(
          l10n.videoEditorFinishTimelineEditingSemanticLabel,
        ),
      );
      await tester.pump();

      verify(
        () => mainBloc.add(
          const VideoEditorMarkerModeChanged(isActive: false),
        ),
      ).called(1);
    });
  });
}
