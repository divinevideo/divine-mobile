// ABOUTME: Unit tests for StereoWaveformPainter and WaveformConstants.
// ABOUTME: Tests shouldRepaint logic, paint with empty/valid data, and constants.

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/constants/video_editor_timeline_constants.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/stereo_waveform_painter.dart';

void main() {
  group(WaveformConstants, () {
    test('barStep equals barWidth + barSpacing', () {
      expect(
        WaveformConstants.barStep,
        equals(WaveformConstants.barWidth + WaveformConstants.barSpacing),
      );
    });

    test('barWidth is positive', () {
      expect(WaveformConstants.barWidth, greaterThan(0));
    });

    test('minBarHeight is positive', () {
      expect(WaveformConstants.minBarHeight, greaterThan(0));
    });

    test('amplitudeScale is between 0 and 1', () {
      expect(WaveformConstants.amplitudeScale, greaterThan(0));
      expect(WaveformConstants.amplitudeScale, lessThanOrEqualTo(1));
    });

    test('amplitude shaping knobs match TimelineConstants clip waveform', () {
      // Intentionally duplicated across packages — lock the values so a
      // future tuning change cannot drift one site without the other.
      expect(
        WaveformConstants.amplitudeNormalizerFloor,
        TimelineConstants.clipWaveformNormalizerFloor,
      );
      expect(
        WaveformConstants.amplitudeCurve,
        TimelineConstants.clipWaveformCurve,
      );
    });
  });

  group(StereoWaveformPainter, () {
    StereoWaveformPainter createPainter({
      Float32List? leftChannel,
      Float32List? rightChannel,
      double progress = 0.5,
      Color activeColor = Colors.green,
      Color inactiveColor = Colors.grey,
      Color? activeBackgroundColor,
      Duration audioDuration = const Duration(seconds: 10),
      Duration maxDuration = const Duration(seconds: 10),
      Duration startOffset = Duration.zero,
      double heightFactor = 1.0,
    }) {
      return StereoWaveformPainter(
        leftChannel: leftChannel ?? Float32List(0),
        rightChannel: rightChannel,
        progress: progress,
        activeColor: activeColor,
        inactiveColor: inactiveColor,
        activeBackgroundColor: activeBackgroundColor,
        audioDuration: audioDuration,
        maxDuration: maxDuration,
        startOffset: startOffset,
        heightFactor: heightFactor,
      );
    }

    group('shouldRepaint', () {
      test('returns false when all properties are identical', () {
        final left = Float32List.fromList([0.5, 0.3]);
        final painter = createPainter(leftChannel: left);
        final other = createPainter(leftChannel: left);

        expect(painter.shouldRepaint(other), isFalse);
      });

      test('returns true when progress changes', () {
        final left = Float32List.fromList([0.5]);
        final painter = createPainter(leftChannel: left);
        final other = createPainter(leftChannel: left, progress: 0.8);

        expect(painter.shouldRepaint(other), isTrue);
      });

      test('returns true when activeColor changes', () {
        final left = Float32List.fromList([0.5]);
        final painter = createPainter(leftChannel: left);
        final other = createPainter(leftChannel: left, activeColor: Colors.red);

        expect(painter.shouldRepaint(other), isTrue);
      });

      test('returns true when inactiveColor changes', () {
        final left = Float32List.fromList([0.5]);
        final painter = createPainter(leftChannel: left);
        final other = createPainter(
          leftChannel: left,
          inactiveColor: Colors.white,
        );

        expect(painter.shouldRepaint(other), isTrue);
      });

      test('returns true when leftChannel changes', () {
        final painter = createPainter(leftChannel: Float32List.fromList([0.5]));
        final other = createPainter(leftChannel: Float32List.fromList([0.8]));

        expect(painter.shouldRepaint(other), isTrue);
      });

      test('returns true when rightChannel changes', () {
        final left = Float32List.fromList([0.5]);
        final painter = createPainter(
          leftChannel: left,
          rightChannel: Float32List.fromList([0.3]),
        );
        final other = createPainter(
          leftChannel: left,
          rightChannel: Float32List.fromList([0.7]),
        );

        expect(painter.shouldRepaint(other), isTrue);
      });

      test('returns true when audioDuration changes', () {
        final left = Float32List.fromList([0.5]);
        final painter = createPainter(leftChannel: left);
        final other = createPainter(
          leftChannel: left,
          audioDuration: const Duration(seconds: 20),
        );

        expect(painter.shouldRepaint(other), isTrue);
      });

      test('returns true when maxDuration changes', () {
        final left = Float32List.fromList([0.5]);
        final painter = createPainter(leftChannel: left);
        final other = createPainter(
          leftChannel: left,
          maxDuration: const Duration(seconds: 5),
        );

        expect(painter.shouldRepaint(other), isTrue);
      });

      test('returns true when heightFactor changes', () {
        final left = Float32List.fromList([0.5]);
        final painter = createPainter(leftChannel: left);
        final other = createPainter(leftChannel: left, heightFactor: 0.5);

        expect(painter.shouldRepaint(other), isTrue);
      });

      test('returns true when startOffset changes', () {
        final left = Float32List.fromList([0.5]);
        final painter = createPainter(leftChannel: left);
        final other = createPainter(
          leftChannel: left,
          startOffset: const Duration(seconds: 2),
        );

        expect(painter.shouldRepaint(other), isTrue);
      });
    });

    group('paint', () {
      test('does not throw with empty leftChannel', () {
        final painter = createPainter();
        final recorder = PictureRecorder();
        final canvas = Canvas(recorder);

        expect(
          () => painter.paint(canvas, const Size(200, 72)),
          returnsNormally,
        );
      });

      test('does not throw with valid waveform data', () {
        final painter = createPainter(
          leftChannel: Float32List.fromList([0.5, 0.3, 0.8, 0.1, 0.6]),
          rightChannel: Float32List.fromList([0.4, 0.2, 0.7, 0.3, 0.5]),
        );
        final recorder = PictureRecorder();
        final canvas = Canvas(recorder);

        expect(
          () => painter.paint(canvas, const Size(200, 72)),
          returnsNormally,
        );
      });

      test('does not throw with mono (no rightChannel)', () {
        final painter = createPainter(
          leftChannel: Float32List.fromList([0.5, 0.3, 0.8]),
        );
        final recorder = PictureRecorder();
        final canvas = Canvas(recorder);

        expect(
          () => painter.paint(canvas, const Size(200, 72)),
          returnsNormally,
        );
      });

      test('does not throw when audio is shorter than maxDuration', () {
        final painter = createPainter(
          leftChannel: Float32List.fromList([0.5, 0.3]),
          audioDuration: const Duration(seconds: 3),
        );
        final recorder = PictureRecorder();
        final canvas = Canvas(recorder);

        expect(
          () => painter.paint(canvas, const Size(200, 72)),
          returnsNormally,
        );
      });

      test('does not throw with startOffset', () {
        final painter = createPainter(
          leftChannel: Float32List.fromList(List.generate(100, (i) => i / 100)),
          audioDuration: const Duration(seconds: 30),
          startOffset: const Duration(seconds: 5),
        );
        final recorder = PictureRecorder();
        final canvas = Canvas(recorder);

        expect(
          () => painter.paint(canvas, const Size(200, 72)),
          returnsNormally,
        );
      });

      test('does not throw with zero audioDuration', () {
        final painter = createPainter(
          leftChannel: Float32List.fromList([0.5]),
          audioDuration: Duration.zero,
        );
        final recorder = PictureRecorder();
        final canvas = Canvas(recorder);

        expect(
          () => painter.paint(canvas, const Size(200, 72)),
          returnsNormally,
        );
      });

      test('does not throw with activeBackgroundColor', () {
        final painter = createPainter(
          leftChannel: Float32List.fromList([0.5, 0.3, 0.8]),
          activeBackgroundColor: Colors.green.withValues(alpha: 0.2),
        );
        final recorder = PictureRecorder();
        final canvas = Canvas(recorder);

        expect(
          () => painter.paint(canvas, const Size(200, 72)),
          returnsNormally,
        );
      });

      test('does not throw with heightFactor 0', () {
        final painter = createPainter(
          leftChannel: Float32List.fromList([0.5, 0.3]),
          heightFactor: 0,
        );
        final recorder = PictureRecorder();
        final canvas = Canvas(recorder);

        expect(
          () => painter.paint(canvas, const Size(200, 72)),
          returnsNormally,
        );
      });

      test('does not throw with progress at boundaries', () {
        final left = Float32List.fromList([0.5, 0.3, 0.8]);

        for (final progress in [0.0, 1.0]) {
          final painter = createPainter(leftChannel: left, progress: progress);
          final recorder = PictureRecorder();
          final canvas = Canvas(recorder);

          expect(
            () => painter.paint(canvas, const Size(200, 72)),
            returnsNormally,
          );
        }
      });

      test('does not throw with zero-size canvas', () {
        final painter = createPainter(
          leftChannel: Float32List.fromList([0.5, 0.3]),
        );
        final recorder = PictureRecorder();
        final canvas = Canvas(recorder);

        expect(() => painter.paint(canvas, Size.zero), returnsNormally);
      });

      test('does not throw with startOffset exceeding audioDuration', () {
        final painter = createPainter(
          leftChannel: Float32List.fromList([0.5, 0.3]),
          audioDuration: const Duration(seconds: 5),
          startOffset: const Duration(seconds: 10),
        );
        final recorder = PictureRecorder();
        final canvas = Canvas(recorder);

        expect(
          () => painter.paint(canvas, const Size(200, 72)),
          returnsNormally,
        );
      });
    });

    group('amplitude shaping', () {
      const size = Size(200, 72);
      const halfHeight = 36.0;
      const scaledHalfHeight = halfHeight * WaveformConstants.amplitudeScale;

      /// The bar at [index], mirrored around the vertical centre.
      RRect barAt(int index, double armHeight) => RRect.fromRectAndRadius(
        Rect.fromLTWH(
          index * WaveformConstants.barStep,
          halfHeight - armHeight,
          WaveformConstants.barWidth,
          armHeight * 2,
        ),
        WaveformConstants.barRadius,
      );

      /// A bar at the band's ceiling — what the source's loudest sample draws.
      RRect ceilingBar(int index) => barAt(index, scaledHalfHeight);

      final waveformPaint = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is StereoWaveformPainter,
      );

      Future<RenderObject> pumpPainter(
        WidgetTester tester,
        StereoWaveformPainter painter,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: SizedBox(
                width: size.width,
                height: size.height,
                child: CustomPaint(painter: painter),
              ),
            ),
          ),
        );
        return tester.renderObject(waveformPaint);
      }

      testWidgets('fills the band for a quietly recorded source', (
        tester,
      ) async {
        // Real recordings peak well below full scale — mapped linearly they
        // draw as a barely visible ripple, so the bars normalize per source.
        final render = await pumpPainter(
          tester,
          createPainter(leftChannel: Float32List.fromList([0.25, 0.25])),
        );

        expect(render, paints..rrect(rrect: ceilingBar(0)));
      });

      testWidgets('keeps a near-silent source below the band', (tester) async {
        final render = await pumpPainter(
          tester,
          createPainter(leftChannel: Float32List.fromList([0.03125, 0.03125])),
        );

        // Quiet, but still audible-looking: the floor holds the bars down
        // without collapsing them to the silent baseline or hiding them.
        expect(render, paints..rrect());
        expect(render, isNot(paints..rrect(rrect: ceilingBar(0))));
        expect(
          render,
          isNot(
            paints..rrect(rrect: barAt(0, WaveformConstants.minBarHeight)),
          ),
        );
      });

      testWidgets('scales quiet passages against the source peak', (
        tester,
      ) async {
        // 40 bars fit the 200px canvas, so each sample of a two-sample source
        // owns half of them: the loud sample the first 20, the quiet one the
        // rest.
        final render = await pumpPainter(
          tester,
          createPainter(leftChannel: Float32List.fromList([0.5, 0.25])),
        );

        // The quiet half is drawn relative to the loud one, not to itself:
        // normalizing per passage would flatten the dynamics away.
        final quietArm =
            math.pow(0.5, WaveformConstants.amplitudeCurve).toDouble() *
            scaledHalfHeight;
        const barCount = 40;
        final bars = paints;
        for (var i = 0; i < barCount ~/ 2; i++) {
          bars.rrect(rrect: ceilingBar(i));
        }
        for (var i = barCount ~/ 2; i < barCount; i++) {
          bars.rrect(rrect: barAt(i, quietArm));
        }
        expect(render, bars);
      });
    });

    group('renders via CustomPaint widget', () {
      testWidgets('renders $StereoWaveformPainter in widget tree', (
        tester,
      ) async {
        final painter = createPainter(
          leftChannel: Float32List.fromList([0.5, 0.3, 0.8]),
        );

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: CustomPaint(size: const Size(200, 72), painter: painter),
            ),
          ),
        );

        expect(find.byType(CustomPaint), findsWidgets);
      });
    });
  });
}
