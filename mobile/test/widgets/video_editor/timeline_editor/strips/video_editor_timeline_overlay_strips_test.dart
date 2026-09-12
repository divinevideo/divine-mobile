// ABOUTME: Widget tests for TimelineOverlayStrips.
// ABOUTME: Verifies strip rendering from overlay bloc state.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/timeline_overlay_item.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/strips/video_editor_timeline_overlay_strip.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/strips/video_editor_timeline_overlay_strips.dart';
import 'package:pro_image_editor/pro_image_editor.dart'
    show PaintLayer, PaintMode, PaintedModel;

class _MockTimelineOverlayBloc
    extends MockBloc<TimelineOverlayEvent, TimelineOverlayState>
    implements TimelineOverlayBloc {}

void main() {
  group(TimelineOverlayStrips, () {
    late _MockTimelineOverlayBloc overlayBloc;
    late VideoEditorMainBloc mainBloc;

    setUp(() {
      overlayBloc = _MockTimelineOverlayBloc();
      mainBloc = VideoEditorMainBloc();
      when(
        () => overlayBloc.stream,
      ).thenAnswer((_) => const Stream<TimelineOverlayState>.empty());
    });

    tearDown(() {
      mainBloc.close();
    });

    Widget build() {
      return MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MultiBlocProvider(
            providers: [
              BlocProvider<TimelineOverlayBloc>.value(value: overlayBloc),
              BlocProvider<VideoEditorMainBloc>.value(value: mainBloc),
            ],
            child: TimelineOverlayStrips(
              totalWidth: 600,
              pixelsPerSecond: 80,
              totalDuration: const Duration(seconds: 10),
              clipEdgesMs: const [0, 3000, 7000],
              playheadPosition: ValueNotifier(Duration.zero),
            ),
          ),
        ),
      );
    }

    testWidgets('renders no strip when overlay items are empty', (
      tester,
    ) async {
      when(() => overlayBloc.state).thenReturn(const TimelineOverlayState());

      await tester.pumpWidget(build());

      expect(find.byType(TimelineOverlayStrip), findsNothing);
    });

    testWidgets('renders one strip per overlay type with items', (
      tester,
    ) async {
      when(() => overlayBloc.state).thenReturn(
        const TimelineOverlayState(
          items: [
            TimelineOverlayItem(
              id: 'sound',
              type: TimelineOverlayType.sound,
              startTime: Duration.zero,
              endTime: Duration(seconds: 1),
            ),
            TimelineOverlayItem(
              id: 'filter',
              type: TimelineOverlayType.filter,
              startTime: Duration(seconds: 1),
              endTime: Duration(seconds: 2),
            ),
            TimelineOverlayItem(
              id: 'layer',
              type: TimelineOverlayType.layer,
              startTime: Duration(seconds: 2),
              endTime: Duration(seconds: 3),
            ),
          ],
        ),
      );

      await tester.pumpWidget(build());

      expect(find.byType(TimelineOverlayStrip), findsNWidgets(3));
    });

    testWidgets(
      'dims non-mergeable items on every strip during draw multi-select',
      (tester) async {
        final handle = tester.ensureSemantics();
        when(() => overlayBloc.state).thenReturn(
          TimelineOverlayState(
            isLayerMultiSelectMode: true,
            multiSelectedLayerIds: const {'draw-1'},
            items: [
              const TimelineOverlayItem(
                id: 'sound',
                type: TimelineOverlayType.sound,
                startTime: Duration.zero,
                endTime: Duration(seconds: 1),
                label: 'My Sound',
              ),
              TimelineOverlayItem(
                id: 'draw-1',
                type: TimelineOverlayType.layer,
                startTime: const Duration(seconds: 2),
                endTime: const Duration(seconds: 3),
                label: 'My Drawing',
                layer: PaintLayer(
                  id: 'draw-1',
                  rawSize: const Size(10, 10),
                  opacity: 1,
                  item: PaintedModel(
                    mode: PaintMode.freeStyle,
                    offsets: const [Offset.zero, Offset(10, 10)],
                    erasedOffsets: const [],
                    color: const Color(0xFFFF0000),
                    strokeWidth: 6,
                    opacity: 1,
                  ),
                ),
              ),
            ],
          ),
        );

        await tester.pumpWidget(build());

        // The audio tile can't be combined: announced disabled, tap inert.
        // RegExp: the tile merges its title text into the label ("My Sound\n…").
        expect(
          tester.getSemantics(find.bySemanticsLabel(RegExp('^My Sound'))),
          isSemantics(isButton: true, hasEnabledState: true, isEnabled: false),
        );
        // The selected draw tile is announced as selected.
        expect(
          tester.getSemantics(find.bySemanticsLabel('My Drawing')),
          isSemantics(isButton: true, isSelected: true),
        );
        handle.dispose();
      },
    );
  });
}
