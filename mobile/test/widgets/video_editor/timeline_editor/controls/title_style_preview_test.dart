// ABOUTME: Tests for TitleStylePreview: the text enters, holds and leaves
// ABOUTME: with the style's animations, and the pill follows the color mode.

import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/title_style.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/title_style_preview.dart';
import 'package:pro_image_editor/pro_image_editor.dart'
    show LayerBackgroundMode;
import 'package:pro_video_editor/pro_video_editor.dart' as pve;

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  const width = 96.0;
  const height = 56.0;
  const loopMs = 2400;

  const enterFade = pve.LayerAnimation(
    type: pve.LayerAnimationType.fade,
    phase: pve.AnimationPhase.animateIn,
    duration: Duration(milliseconds: 400),
  );
  const enterSlideLeft = pve.LayerAnimation(
    type: pve.LayerAnimationType.slide,
    phase: pve.AnimationPhase.animateIn,
    duration: Duration(milliseconds: 400),
    slideDirection: pve.SlideDirection.left,
  );
  const leaveFade = pve.LayerAnimation(
    type: pve.LayerAnimationType.fade,
    phase: pve.AnimationPhase.animateOut,
    duration: Duration(milliseconds: 400),
  );
  const leaveScale = pve.LayerAnimation(
    type: pve.LayerAnimationType.scale,
    phase: pve.AnimationPhase.animateOut,
    duration: Duration(milliseconds: 400),
    scaleFrom: 0.2,
  );

  TitleStyle styleWith({
    List<pve.LayerAnimation> enter = const [],
    List<pve.LayerAnimation> leave = const [],
    Offset? enterPoint,
    LayerBackgroundMode colorMode = LayerBackgroundMode.backgroundAndColor,
  }) => TitleStyle(
    fontIndex: 0,
    color: const Color(0xFFFFFFFF),
    background: const Color(0xFF123456),
    colorMode: colorMode,
    enter: enter,
    leave: leave,
    enterPoint: enterPoint,
  );

  Future<void> pump(
    WidgetTester tester,
    TitleStyle style, {
    required double loopValue,
  }) => tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Center(
        child: TitleStylePreview(
          style: style,
          text: 'Episode 13',
          loopValue: loopValue,
          loopMs: loopMs,
          width: width,
          height: height,
        ),
      ),
    ),
  );

  double opacity(WidgetTester tester) =>
      tester.widget<Opacity>(find.byType(Opacity)).opacity;

  Offset translation(WidgetTester tester) {
    final transform = tester
        .widget<Transform>(find.byType(Transform).first)
        .transform
        .getTranslation();
    return Offset(transform.x, transform.y);
  }

  double scale(WidgetTester tester) => tester
      .widget<Transform>(find.byType(Transform).last)
      .transform
      .entry(0, 0);

  group(TitleStylePreview, () {
    testWidgets('holds the text fully on screen mid-loop', (tester) async {
      await pump(
        tester,
        styleWith(enter: [enterFade, enterSlideLeft], leave: [leaveScale]),
        loopValue: TitleStylePreview.holdValue,
      );

      expect(find.text('Episode 13'), findsOneWidget);
      expect(opacity(tester), 1);
      expect(translation(tester), Offset.zero);
      expect(scale(tester), 1);
    });

    testWidgets('starts hidden past the edge the slide comes from', (
      tester,
    ) async {
      await pump(
        tester,
        styleWith(enter: [enterFade, enterSlideLeft]),
        loopValue: 0,
      );

      expect(opacity(tester), 0);
      expect(translation(tester), const Offset(-width, 0));
    });

    testWidgets('slides along the line to a custom point instead', (
      tester,
    ) async {
      await pump(
        tester,
        styleWith(enter: [enterSlideLeft], enterPoint: const Offset(0, -0.4)),
        loopValue: 0,
      );

      // Straight up, the full preview width away — not from the left edge
      // the animation's direction still names.
      expect(translation(tester), const Offset(0, -width));
    });

    testWidgets('fades and shrinks away at the end of the loop', (
      tester,
    ) async {
      await pump(
        tester,
        styleWith(leave: [leaveFade, leaveScale]),
        loopValue: 1,
      );

      // Floating-point tail of the linear curve, not a visible sliver.
      expect(opacity(tester), closeTo(0, 1e-9));
      expect(scale(tester), closeTo(0.2, 1e-9));
    });

    testWidgets('maps the font scale onto the tile-sized range', (
      tester,
    ) async {
      double fontSize() =>
          tester.widget<Text>(find.text('Episode 13')).style!.fontSize!;

      await pump(tester, styleWith(), loopValue: 0.5);
      final base = fontSize();
      expect(
        base,
        TitleStylePreview.minFontSize +
            (TitleStylePreview.maxFontSize - TitleStylePreview.minFontSize) *
                (1 - 0.5) /
                3.5,
      );

      await pump(
        tester,
        const TitleStyle(
          fontIndex: 0,
          color: Color(0xFFFFFFFF),
          background: Color(0xFF123456),
          colorMode: LayerBackgroundMode.backgroundAndColor,
          fontScale: 99,
        ),
        loopValue: 0.5,
      );
      // Bigger previews bigger, and even an out-of-range scale stays in the
      // tile.
      expect(fontSize(), greaterThan(base));
      expect(fontSize(), TitleStylePreview.maxFontSize);
    });

    testWidgets('draws a pill only when the style has a background', (
      tester,
    ) async {
      await pump(tester, styleWith(), loopValue: 0.5);
      Container pill() => tester.widget<Container>(
        find.ancestor(
          of: find.text('Episode 13'),
          matching: find.byType(Container),
        ),
      );
      expect(
        (pill().decoration! as BoxDecoration).color,
        const Color(0xFF123456),
      );

      await pump(
        tester,
        styleWith(colorMode: LayerBackgroundMode.onlyColor),
        loopValue: 0.5,
      );
      expect(pill().decoration, isNull);
    });
  });
}
