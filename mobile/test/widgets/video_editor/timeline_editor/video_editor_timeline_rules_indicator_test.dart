// ABOUTME: Widget tests for VideoEditorTimelineRulesIndicator.
// ABOUTME: Validates ruler rendering, label formatting, and zoom-dependent density.

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model;
import 'package:openvine/constants/video_editor_timeline_constants.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/video_editor_timeline_rules_indicator.dart';
import 'package:pro_video_editor/pro_video_editor.dart'
    show ClipTransition, ClipTransitionType, EditorVideo;

void main() {
  group(VideoEditorTimelineRulesIndicator, () {
    late ScrollController scrollController;

    setUp(() {
      scrollController = ScrollController();
    });

    tearDown(() {
      scrollController.dispose();
    });

    DivineVideoClip clip(
      String id,
      Duration duration, {
      ClipTransition? transition,
    }) => DivineVideoClip(
      id: id,
      video: EditorVideo.file('${Directory.systemTemp.path}/$id.mp4'),
      duration: duration,
      recordedAt: DateTime(2026),
      targetAspectRatio: model.AspectRatio.vertical,
      originalAspectRatio: 9 / 16,
      transition: transition,
    );

    Widget buildWidget({
      Duration totalDuration = const Duration(seconds: 10),
      double pixelsPerSecond = TimelineConstants.pixelsPerSecond,
      double scrollPadding = 0,
      List<DivineVideoClip> clips = const [],
    }) {
      return Directionality(
        textDirection: TextDirection.ltr,
        child: SingleChildScrollView(
          controller: scrollController,
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.only(left: scrollPadding),
          child: VideoEditorTimelineRulesIndicator(
            totalDuration: totalDuration,
            pixelsPerSecond: pixelsPerSecond,
            scrollController: scrollController,
            scrollPadding: scrollPadding,
            clips: clips,
          ),
        ),
      );
    }

    group('renders', () {
      testWidgets('renders $VideoEditorTimelineRulesIndicator', (tester) async {
        await tester.pumpWidget(buildWidget());

        expect(find.byType(VideoEditorTimelineRulesIndicator), findsOneWidget);
      });

      testWidgets('renders with correct height', (tester) async {
        await tester.pumpWidget(buildWidget());

        final sizedBox = tester.widget<SizedBox>(
          find.byWidgetPredicate(
            (w) => w is SizedBox && w.height == TimelineConstants.rulerHeight,
          ),
        );
        expect(sizedBox.height, equals(TimelineConstants.rulerHeight));
      });

      testWidgets('computes correct total width from duration and pps', (
        tester,
      ) async {
        const duration = Duration(seconds: 5);
        const pps = 100.0;
        const expectedWidth = 5.0 * pps;

        await tester.pumpWidget(
          buildWidget(totalDuration: duration, pixelsPerSecond: pps),
        );

        final sizedBox = tester.widget<SizedBox>(
          find.byWidgetPredicate(
            (w) => w is SizedBox && w.width == expectedWidth,
          ),
        );
        expect(sizedBox.width, equals(expectedWidth));
      });

      testWidgets(
        'keeps the box on the editor axis with an overlap transition',
        (
          tester,
        ) async {
          // 2×3s clips with a 1s dissolve: the rendered output is 5s, but the box
          // must stay 6s wide so the ruler aligns with the full-length clip strip.
          const pps = 100.0;
          const dissolve1s = ClipTransition(
            type: ClipTransitionType.dissolve,
            duration: Duration(seconds: 1),
          );
          final clips = [
            clip('a', const Duration(seconds: 3), transition: dissolve1s),
            clip('b', const Duration(seconds: 3)),
          ];

          await tester.pumpWidget(
            buildWidget(
              totalDuration: const Duration(seconds: 6),
              pixelsPerSecond: pps,
              clips: clips,
            ),
          );

          final sizedBox = tester.widget<SizedBox>(
            find.byWidgetPredicate(
              (w) => w is SizedBox && w.height == TimelineConstants.rulerHeight,
            ),
          );
          expect(sizedBox.width, equals(6.0 * pps));
        },
      );
    });

    group('layout', () {
      testWidgets('uses CustomPaint for rendering', (tester) async {
        await tester.pumpWidget(buildWidget());

        expect(
          find.descendant(
            of: find.byType(VideoEditorTimelineRulesIndicator),
            matching: find.byType(CustomPaint),
          ),
          findsOneWidget,
        );
      });

      testWidgets('excludes semantics', (tester) async {
        await tester.pumpWidget(buildWidget());

        expect(find.byType(ExcludeSemantics), findsOneWidget);
      });
    });

    group('zero duration', () {
      testWidgets('renders with zero width for zero duration', (tester) async {
        await tester.pumpWidget(buildWidget(totalDuration: Duration.zero));

        final sizedBox = tester.widget<SizedBox>(
          find.byWidgetPredicate((w) => w is SizedBox && w.width == 0.0),
        );
        expect(sizedBox.width, equals(0.0));
      });
    });

    group('zoom levels', () {
      testWidgets('scales width with pixelsPerSecond', (tester) async {
        // Low zoom
        await tester.pumpWidget(buildWidget(pixelsPerSecond: 50));

        final lowZoomWidth = tester
            .widget<SizedBox>(
              find.byWidgetPredicate((w) => w is SizedBox && w.width == 500.0),
            )
            .width;

        // High zoom
        await tester.pumpWidget(buildWidget(pixelsPerSecond: 200));

        final highZoomWidth = tester
            .widget<SizedBox>(
              find.byWidgetPredicate((w) => w is SizedBox && w.width == 2000.0),
            )
            .width;

        expect(highZoomWidth, greaterThan(lowZoomWidth!));
      });
    });
  });
}
