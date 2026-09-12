// ABOUTME: Widget tests for VideoEditorTimelineMarkers.
// ABOUTME: Validates visibility gating, reorder hiding, and the delete flow.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/video_editor_timeline_markers.dart';

class _MockVideoEditorMainBloc
    extends MockBloc<VideoEditorMainEvent, VideoEditorMainState>
    implements VideoEditorMainBloc {}

class _MockTimelineOverlayBloc
    extends MockBloc<TimelineOverlayEvent, TimelineOverlayState>
    implements TimelineOverlayBloc {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(VideoEditorTimelineMarkers, () {
    late _MockVideoEditorMainBloc mainBloc;
    late _MockTimelineOverlayBloc overlayBloc;
    late ScrollController scrollController;

    setUp(() {
      mainBloc = _MockVideoEditorMainBloc();
      overlayBloc = _MockTimelineOverlayBloc();
      scrollController = ScrollController();

      when(() => mainBloc.state).thenReturn(const VideoEditorMainState());
      when(() => overlayBloc.state).thenReturn(const TimelineOverlayState());
    });

    tearDown(() {
      scrollController.dispose();
    });

    Widget buildWidget() {
      return MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(splashFactory: NoSplash.splashFactory),
        home: Scaffold(
          body: MultiBlocProvider(
            providers: [
              BlocProvider<VideoEditorMainBloc>.value(value: mainBloc),
              BlocProvider<TimelineOverlayBloc>.value(value: overlayBloc),
            ],
            child: VideoEditorTimelineMarkers(
              scrollController: scrollController,
              scrollPadding: 100,
              pixelsPerSecond: 50,
            ),
          ),
        ),
      );
    }

    testWidgets('renders $VideoEditorTimelineMarkers', (tester) async {
      await tester.pumpWidget(buildWidget());

      expect(find.byType(VideoEditorTimelineMarkers), findsOneWidget);
    });

    testWidgets('is hidden when there are no markers', (tester) async {
      await tester.pumpWidget(buildWidget());

      final opacity = tester.widget<AnimatedOpacity>(
        find.byType(AnimatedOpacity),
      );
      expect(opacity.opacity, 0.0);
    });

    testWidgets('exposes a delete target for each marker', (tester) async {
      when(() => overlayBloc.state).thenReturn(
        const TimelineOverlayState(
          timelineMarkers: [Duration.zero, Duration(seconds: 1)],
        ),
      );

      await tester.pumpWidget(buildWidget());

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(
        find.bySemanticsLabel(
          l10n.videoEditorRemoveTimelineMarkerSemanticLabel,
        ),
        findsNWidgets(2),
      );
    });

    testWidgets('hides markers while reordering', (tester) async {
      when(() => mainBloc.state).thenReturn(
        const VideoEditorMainState(isReordering: true),
      );
      when(() => overlayBloc.state).thenReturn(
        const TimelineOverlayState(timelineMarkers: [Duration.zero]),
      );

      await tester.pumpWidget(buildWidget());

      final opacity = tester.widget<AnimatedOpacity>(
        find.byType(AnimatedOpacity),
      );
      expect(opacity.opacity, 0.0);
    });

    testWidgets(
      'dispatches $TimelineMarkerRemoved after confirming delete',
      (tester) async {
        const marker = Duration(seconds: 1);
        when(() => overlayBloc.state).thenReturn(
          const TimelineOverlayState(timelineMarkers: [marker]),
        );

        await tester.pumpWidget(buildWidget());

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(
          find.bySemanticsLabel(
            l10n.videoEditorRemoveTimelineMarkerSemanticLabel,
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text(l10n.videoEditorDeleteTimelineMarkerTitle),
          findsOneWidget,
        );

        await tester.tap(find.text(l10n.commonDelete));
        await tester.pumpAndSettle();

        verify(
          () => overlayBloc.add(const TimelineMarkerRemoved(marker)),
        ).called(1);
      },
    );
  });
}
