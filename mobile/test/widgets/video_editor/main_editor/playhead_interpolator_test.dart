// ABOUTME: Tests for the frame-rate playhead interpolator between native
// ABOUTME: player reports: anchoring, speed, clamping, stop and re-anchor.

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/video_editor/main_editor/playhead_interpolator.dart';

/// Records every callback the interpolator makes, in order.
class _Recorder {
  final ticks = <Duration>[];
  final advancing = <bool>[];

  PlayheadInterpolator build() => PlayheadInterpolator(
    vsync: const TestVSync(),
    onTick: ticks.add,
    onAdvancingChanged: advancing.add,
    // Drive the clock from the test binding's fake time so pumped frames and
    // the stopwatch agree.
    createStopwatch: clock.stopwatch,
  );
}

void main() {
  const frame = Duration(milliseconds: 16);
  const maxDuration = Duration(seconds: 10);

  group(PlayheadInterpolator, () {
    late _Recorder recorder;
    late PlayheadInterpolator interpolator;

    setUp(() => recorder = _Recorder());

    /// Built inside the test body, not [setUp]: only there does `clock`
    /// resolve to the binding's fake clock.
    void build() => interpolator = recorder.build();

    /// A ticker left running fails the binding's leak check before any
    /// [addTearDown] runs, so every test releases it explicitly.
    tearDown(() => interpolator.dispose());

    group('anchor', () {
      testWidgets('starts ticking and advances from the anchor at 1x', (
        tester,
      ) async {
        build();
        interpolator.anchor(
          position: const Duration(seconds: 1),
          speed: 1,
          maxDuration: maxDuration,
        );

        expect(interpolator.isActive, isTrue);
        expect(recorder.advancing, [true]);

        await tester.pump(frame);
        await tester.pump(frame);

        expect(recorder.ticks, hasLength(2));
        expect(recorder.ticks.last, const Duration(seconds: 1) + frame * 2);
        interpolator.stop();
      });

      testWidgets('scales the elapsed by the playback speed', (tester) async {
        build();
        interpolator.anchor(
          position: const Duration(seconds: 1),
          speed: 2,
          maxDuration: maxDuration,
        );

        await tester.pump(const Duration(milliseconds: 100));

        expect(
          recorder.ticks.single,
          const Duration(seconds: 1, milliseconds: 200),
        );
        interpolator.stop();
      });

      testWidgets('treats a non-positive speed as 1x', (tester) async {
        build();
        interpolator.anchor(
          position: const Duration(seconds: 1),
          speed: 0,
          maxDuration: maxDuration,
        );

        await tester.pump(const Duration(milliseconds: 100));

        expect(
          recorder.ticks.single,
          const Duration(seconds: 1, milliseconds: 100),
        );
        interpolator.stop();
      });

      testWidgets('clamps the interpolated position to the duration', (
        tester,
      ) async {
        build();
        interpolator.anchor(
          position: maxDuration - const Duration(milliseconds: 50),
          speed: 1,
          maxDuration: maxDuration,
        );

        await tester.pump(const Duration(milliseconds: 100));

        expect(recorder.ticks.single, maxDuration);
        interpolator.stop();
      });

      testWidgets('re-anchoring while active corrects drift without a '
          'restart', (tester) async {
        build();
        interpolator.anchor(
          position: const Duration(seconds: 1),
          speed: 1,
          maxDuration: maxDuration,
        );
        await tester.pump(const Duration(milliseconds: 100));

        // The next authoritative report lands behind where interpolation ran
        // to; the clock must snap to it rather than keep the drifted value.
        interpolator.anchor(
          position: const Duration(seconds: 1),
          speed: 1,
          maxDuration: maxDuration,
        );
        await tester.pump(frame);

        expect(recorder.ticks, hasLength(2));
        expect(recorder.ticks.last, const Duration(seconds: 1) + frame);
        expect(recorder.advancing, [true, true]);
        interpolator.stop();
      });
    });

    group('stop', () {
      testWidgets('halts ticking and reports the playhead as idle', (
        tester,
      ) async {
        build();
        interpolator.anchor(
          position: Duration.zero,
          speed: 1,
          maxDuration: maxDuration,
        );
        await tester.pump(frame);

        interpolator.stop();
        await tester.pump(frame);
        await tester.pump(frame);

        expect(interpolator.isActive, isFalse);
        expect(recorder.ticks, hasLength(1));
        expect(recorder.advancing, [true, false]);
      });

      testWidgets('is safe before any anchor and when already stopped', (
        tester,
      ) async {
        build();
        interpolator
          ..stop()
          ..stop();

        expect(interpolator.isActive, isFalse);
        expect(recorder.advancing, [false, false]);
      });

      testWidgets('a later anchor resumes from the new report', (
        tester,
      ) async {
        build();
        interpolator.anchor(
          position: Duration.zero,
          speed: 1,
          maxDuration: maxDuration,
        );
        await tester.pump(frame);
        interpolator.stop();
        await tester.pump(const Duration(seconds: 1));

        interpolator.anchor(
          position: const Duration(seconds: 5),
          speed: 1,
          maxDuration: maxDuration,
        );
        await tester.pump(frame);

        expect(recorder.ticks.last, const Duration(seconds: 5) + frame);
        interpolator.stop();
      });
    });

    group('dispose', () {
      testWidgets('releases the ticker so no further frames tick', (
        tester,
      ) async {
        build();
        interpolator.anchor(
          position: Duration.zero,
          speed: 1,
          maxDuration: maxDuration,
        );
        await tester.pump(frame);

        interpolator.dispose();
        await tester.pump(frame);

        expect(interpolator.isActive, isFalse);
        expect(recorder.ticks, hasLength(1));
      });
    });
  });
}
