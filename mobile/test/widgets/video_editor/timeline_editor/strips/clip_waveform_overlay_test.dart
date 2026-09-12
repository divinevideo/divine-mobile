// ABOUTME: Widget tests for the clip waveform overlay and its painter.
// ABOUTME: Validates bottom anchoring, volume scaling, and short-audio bounds.

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/constants/video_editor_timeline_constants.dart';
import 'package:openvine/models/video_editor/clip_waveform.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/strips/clip_waveform_overlay.dart';

void main() {
  group(ClipWaveformOverlay, () {
    const height = TimelineConstants.thumbnailStripHeight;
    const width = 100.0;
    const barStep =
        TimelineConstants.clipWaveformBarWidth +
        TimelineConstants.clipWaveformBarSpacing;
    const band = TimelineConstants.clipWaveformBandHeight;

    Future<void> pumpOverlay(
      WidgetTester tester, {
      required ClipWaveform waveform,
      double volume = 1,
      Duration clipDuration = const Duration(seconds: 2),
    }) {
      return tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: width,
              height: height,
              child: ClipWaveformOverlay(
                waveform: waveform,
                clipDuration: clipDuration,
                volume: volume,
              ),
            ),
          ),
        ),
      );
    }

    final waveformPaint = find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is ClipWaveformPainter,
    );

    RenderObject overlayRender(WidgetTester tester) =>
        tester.renderObject(waveformPaint);

    /// The bar at [index] with [barHeight], grown up from the bottom edge.
    RRect barAt(int index, double barHeight) => RRect.fromRectAndRadius(
      Rect.fromLTWH(
        index * barStep,
        height - barHeight,
        TimelineConstants.clipWaveformBarWidth,
        barHeight,
      ),
      const Radius.circular(TimelineConstants.clipWaveformBarWidth / 2),
    );

    /// The leftmost bar at [barHeight], grown up from the bottom edge.
    RRect firstBar(double barHeight) => barAt(0, barHeight);

    /// A bar at the band's ceiling — what the clip's own loudest sample draws.
    final fullBandBar = firstBar(band * TimelineConstants.clipWaveformGain);

    testWidgets('draws a bar per step, anchored to the bottom edge', (
      tester,
    ) async {
      await pumpOverlay(tester, waveform: _waveform(peaks: [1, 1, 1, 1]));

      expect(overlayRender(tester), paints..rrect(rrect: fullBandBar));
      expect(
        overlayRender(tester),
        paintsExactlyCountTimes(#drawRRect, width ~/ barStep),
      );
    });

    testWidgets('fills the band for a quietly recorded clip', (tester) async {
      // Real recordings peak well below full scale — mapped linearly they draw
      // as a barely visible ripple, so the band normalizes per clip.
      await pumpOverlay(tester, waveform: _waveform(peaks: [0.3, 0.3, 0.3]));

      expect(overlayRender(tester), paints..rrect(rrect: fullBandBar));
    });

    testWidgets('keeps a near-silent clip below the band', (tester) async {
      await pumpOverlay(tester, waveform: _waveform(peaks: [0.02, 0.02, 0.02]));

      // Quiet, but still audible-looking: the floor holds the band down
      // without collapsing it to the silent baseline or hiding it outright.
      expect(overlayRender(tester), paints..rrect());
      expect(overlayRender(tester), isNot(paints..rrect(rrect: fullBandBar)));
      expect(
        overlayRender(tester),
        isNot(
          paints..rrect(
            rrect: firstBar(TimelineConstants.clipWaveformMinBarHeight),
          ),
        ),
      );
    });

    testWidgets('scales bar heights with the clip volume', (tester) async {
      await pumpOverlay(
        tester,
        waveform: _waveform(peaks: [1, 1, 1, 1]),
        volume: 0.5,
      );

      expect(
        overlayRender(tester),
        paints..rrect(
          rrect: firstBar(band * TimelineConstants.clipWaveformGain * 0.5),
        ),
      );
    });

    testWidgets('flattens to the baseline for a muted clip', (tester) async {
      await pumpOverlay(
        tester,
        waveform: _waveform(peaks: [1, 1, 1, 1]),
        volume: 0,
      );

      expect(
        overlayRender(tester),
        paints..rrect(
          rrect: firstBar(TimelineConstants.clipWaveformMinBarHeight),
        ),
      );
    });

    testWidgets('stops at the audio track end when it ends before the video', (
      tester,
    ) async {
      await pumpOverlay(
        tester,
        waveform: _waveform(
          peaks: [1, 1],
          duration: const Duration(seconds: 1),
        ),
      );

      // The clip runs 2s, its audio 1s — only half the width gets bars.
      expect(
        overlayRender(tester),
        paintsExactlyCountTimes(#drawRRect, width ~/ barStep ~/ 2),
      );
    });

    testWidgets("draws only the clip's own share of a longer audio track", (
      tester,
    ) async {
      // A trim-based split rebases the start half's duration to the split
      // point while it keeps sharing the full-length source file, so its
      // waveform outlasts it 4:1 here.
      await pumpOverlay(
        tester,
        waveform: _waveform(
          peaks: [1, 0, 0, 0],
          duration: const Duration(seconds: 4),
        ),
        clipDuration: const Duration(seconds: 1),
      );

      // The loud first quarter is this clip's entire span, so every bar —
      // right up to the tile's edge — stays at the ceiling. Fitting all four
      // samples into the tile instead would drop the band to the baseline
      // after a few bars, drawing the later halves' sound under these frames.
      const gain = TimelineConstants.clipWaveformGain;
      final ceilingBars = paints;
      for (var i = 0; i < width ~/ barStep; i++) {
        ceilingBars.rrect(rrect: barAt(i, band * gain));
      }
      expect(overlayRender(tester), ceilingBars);
      expect(
        overlayRender(tester),
        paintsExactlyCountTimes(#drawRRect, width ~/ barStep),
      );
    });

    testWidgets('renders nothing for a file without an audio track', (
      tester,
    ) async {
      await pumpOverlay(tester, waveform: const ClipWaveform.empty());

      expect(waveformPaint, findsNothing);
    });
  });
}

ClipWaveform _waveform({
  required List<double> peaks,
  Duration duration = const Duration(seconds: 2),
}) => ClipWaveform(
  peaks: peaks,
  duration: duration,
  peak: peaks.reduce(math.max),
);
