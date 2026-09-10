// ABOUTME: Widget tests for TimelineControlsBar.
// ABOUTME: Verifies visibility logic for clip controls.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_timeline_clip_controls.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_timeline_control_bar.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_timeline_layer_multi_select_controls.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_timeline_marker_controls.dart';

class _MockVideoEditorMainBloc
    extends MockBloc<VideoEditorMainEvent, VideoEditorMainState>
    implements VideoEditorMainBloc {}

class _MockClipEditorBloc extends MockBloc<ClipEditorEvent, ClipEditorState>
    implements ClipEditorBloc {}

class _MockTimelineOverlayBloc
    extends MockBloc<TimelineOverlayEvent, TimelineOverlayState>
    implements TimelineOverlayBloc {}

void main() {
  group(TimelineControlsBar, () {
    late _MockVideoEditorMainBloc mainBloc;
    late _MockClipEditorBloc clipBloc;
    late _MockTimelineOverlayBloc overlayBloc;

    setUp(() {
      mainBloc = _MockVideoEditorMainBloc();
      clipBloc = _MockClipEditorBloc();
      overlayBloc = _MockTimelineOverlayBloc();

      when(() => mainBloc.state).thenReturn(const VideoEditorMainState());

      when(() => clipBloc.state).thenReturn(const ClipEditorState());
      when(
        () => clipBloc.stream,
      ).thenAnswer((_) => const Stream<ClipEditorState>.empty());

      when(() => overlayBloc.state).thenReturn(const TimelineOverlayState());
      when(
        () => overlayBloc.stream,
      ).thenAnswer((_) => const Stream<TimelineOverlayState>.empty());
    });

    Widget build({required bool isEditing, bool isMarkerMode = false}) {
      return ProviderScope(
        child: MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MultiBlocProvider(
              providers: [
                BlocProvider<VideoEditorMainBloc>.value(value: mainBloc),
                BlocProvider<ClipEditorBloc>.value(value: clipBloc),
                BlocProvider<TimelineOverlayBloc>.value(value: overlayBloc),
              ],
              child: TimelineControlsBar(
                isEditing: isEditing,
                isMarkerMode: isMarkerMode,
                playheadPosition: ValueNotifier(Duration.zero),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('shows no controls when not editing and no overlay selected', (
      tester,
    ) async {
      await tester.pumpWidget(build(isEditing: false));

      expect(find.byType(TimelineClipControls), findsNothing);
    });

    testWidgets('shows clip controls when editing is active', (tester) async {
      await tester.pumpWidget(build(isEditing: true));

      expect(find.byType(TimelineClipControls), findsOneWidget);
    });

    testWidgets('shows marker controls when marker mode is active', (
      tester,
    ) async {
      await tester.pumpWidget(build(isEditing: false, isMarkerMode: true));

      expect(find.byType(TimelineMarkerControls), findsOneWidget);
      expect(find.byType(TimelineClipControls), findsNothing);
    });

    testWidgets(
      'shows layer multi-select controls when that mode is active',
      (tester) async {
        when(() => overlayBloc.state).thenReturn(
          const TimelineOverlayState(
            isLayerMultiSelectMode: true,
            multiSelectedLayerIds: {'a', 'b'},
          ),
        );

        await tester.pumpWidget(build(isEditing: false));

        expect(
          find.byType(TimelineLayerMultiSelectControls),
          findsOneWidget,
        );
        expect(find.byType(TimelineClipControls), findsNothing);
      },
    );
  });
}
