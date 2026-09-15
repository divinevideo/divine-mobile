// ABOUTME: Tests for the frames-only stop-motion playhead clock: play, pause,
// ABOUTME: seek, looping, and the throttled versus frame-rate consumers.

import 'package:clock/clock.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/video_editor/main_editor/stop_motion_playback_clock.dart';

/// One callback the clock made, in the order it was made.
sealed class _Event extends Equatable {
  const _Event();

  @override
  bool get stringify => true;
}

class _Advancing extends _Event {
  const _Advancing(this.advancing);
  final bool advancing;

  @override
  List<Object?> get props => [advancing];
}

class _PlayTime extends _Event {
  const _PlayTime(this.position);
  final Duration position;

  @override
  List<Object?> get props => [position];
}

class _AudioSync extends _Event {
  const _AudioSync(
    this.position, {
    required this.isPlaying,
    required this.isSeek,
  });
  final Duration position;
  final bool isPlaying;
  final bool isSeek;

  @override
  List<Object?> get props => [position, isPlaying, isSeek];
}

class _AudioPause extends _Event {
  const _AudioPause();

  @override
  List<Object?> get props => const [];
}

class _Position extends _Event {
  const _Position(this.position);
  final Duration position;

  @override
  List<Object?> get props => [position];
}

class _Playing extends _Event {
  const _Playing(this.isPlaying);
  final bool isPlaying;

  @override
  List<Object?> get props => [isPlaying];
}

/// Records every callback the clock makes, in order.
class _Recorder {
  final events = <_Event>[];
  Duration total = const Duration(seconds: 2);

  Iterable<_Position> get positions => events.whereType<_Position>();
  Iterable<_PlayTime> get playTimes => events.whereType<_PlayTime>();

  StopMotionPlaybackClock build() => StopMotionPlaybackClock(
    vsync: const TestVSync(),
    totalDuration: () => total,
    emitInterval: const Duration(milliseconds: 40),
    onAdvancingChanged: (advancing) => events.add(_Advancing(advancing)),
    onPlayTime: (position) => events.add(_PlayTime(position)),
    onAudioSync: (position, {required isPlaying, required isSeek}) =>
        events.add(
          _AudioSync(position, isPlaying: isPlaying, isSeek: isSeek),
        ),
    onAudioPause: () => events.add(const _AudioPause()),
    onPositionChanged: (position) => events.add(_Position(position)),
    onPlayingChanged: (isPlaying) => events.add(_Playing(isPlaying)),
    // Drive the clock from the test binding's fake time so pumped frames and
    // the stopwatch agree.
    createStopwatch: clock.stopwatch,
  );
}

void main() {
  const frame = Duration(milliseconds: 16);

  group(StopMotionPlaybackClock, () {
    late _Recorder recorder;
    late StopMotionPlaybackClock stopMotionClock;

    setUp(() => recorder = _Recorder());

    /// Built inside the test body, not [setUp]: only there does `clock`
    /// resolve to the binding's fake clock.
    void build() => stopMotionClock = recorder.build();

    /// A ticker left running fails the binding's leak check before any
    /// [addTearDown] runs, so every test releases it explicitly.
    tearDown(() => stopMotionClock.dispose());

    group('play', () {
      testWidgets('anchors at the requested position and reports every '
          'consumer in order', (tester) async {
        build();
        const from = Duration(milliseconds: 500);

        stopMotionClock.play(from: from);

        expect(stopMotionClock.isPlaying, isTrue);
        expect(recorder.events, const [
          _Advancing(true),
          _PlayTime(from),
          _AudioSync(from, isPlaying: true, isSeek: true),
          _Position(from),
          _Playing(true),
        ]);
        stopMotionClock.pause();
      });

      testWidgets('wraps to the start when asked to play from the end', (
        tester,
      ) async {
        build();

        stopMotionClock.play(from: recorder.total);

        expect(recorder.positions.single, const _Position(Duration.zero));
        stopMotionClock.pause();
      });

      testWidgets('ignores an empty loop', (tester) async {
        build();
        recorder.total = Duration.zero;

        stopMotionClock.play(from: Duration.zero);

        expect(stopMotionClock.isPlaying, isFalse);
        expect(recorder.events, isEmpty);
      });

      testWidgets('re-anchors a running clock without restarting the '
          'ticker', (tester) async {
        build();
        stopMotionClock.play(from: Duration.zero);
        await tester.pump(frame);

        stopMotionClock.play(from: const Duration(seconds: 1));
        await tester.pump(frame);

        expect(
          recorder.playTimes.last,
          const _PlayTime(Duration(seconds: 1, milliseconds: 16)),
        );
        stopMotionClock.pause();
      });
    });

    group('tick', () {
      testWidgets('drives play time and audio every frame but throttles the '
          'timeline position', (tester) async {
        build();
        stopMotionClock.play(from: Duration.zero);
        recorder.events.clear();

        await tester.pump(frame);
        await tester.pump(frame);
        await tester.pump(frame);

        expect(recorder.playTimes, const [
          _PlayTime(Duration(milliseconds: 16)),
          _PlayTime(Duration(milliseconds: 32)),
          _PlayTime(Duration(milliseconds: 48)),
        ]);
        expect(
          recorder.events.whereType<_AudioSync>().last,
          const _AudioSync(
            Duration(milliseconds: 48),
            isPlaying: true,
            isSeek: false,
          ),
        );
        // 16 and 32 ms fall inside the 40 ms emit interval; 48 ms is the
        // first tick past it.
        expect(recorder.positions, const [
          _Position(Duration(milliseconds: 48)),
        ]);
        stopMotionClock.pause();
      });

      testWidgets('loops past the end and always emits the wrap', (
        tester,
      ) async {
        build();
        recorder.total = const Duration(milliseconds: 100);
        stopMotionClock.play(from: const Duration(milliseconds: 80));
        recorder.events.clear();

        // 80 + 16 = 96 (inside the emit interval: swallowed), then
        // 80 + 32 = 112 → wraps to 12, which must reach the timeline even
        // though it advanced by less than the interval.
        await tester.pump(frame);
        await tester.pump(frame);

        expect(recorder.playTimes, const [
          _PlayTime(Duration(milliseconds: 96)),
          _PlayTime(Duration(milliseconds: 12)),
        ]);
        expect(recorder.positions, const [
          _Position(Duration(milliseconds: 12)),
        ]);
        stopMotionClock.pause();
      });

      testWidgets('pauses itself when the loop empties mid-playback', (
        tester,
      ) async {
        build();
        stopMotionClock.play(from: Duration.zero);
        recorder
          ..events.clear()
          ..total = Duration.zero;

        await tester.pump(frame);

        expect(stopMotionClock.isPlaying, isFalse);
        expect(recorder.events, const [
          _Advancing(false),
          _AudioPause(),
          _Playing(false),
        ]);
      });
    });

    group('pause', () {
      testWidgets('stops the clock and reports every consumer in order', (
        tester,
      ) async {
        build();
        stopMotionClock.play(from: Duration.zero);
        await tester.pump(frame);
        recorder.events.clear();

        stopMotionClock.pause();
        await tester.pump(frame);

        expect(stopMotionClock.isPlaying, isFalse);
        expect(recorder.events, const [
          _Advancing(false),
          _AudioPause(),
          _Playing(false),
        ]);
      });

      testWidgets('is safe before any play and when already paused', (
        tester,
      ) async {
        build();

        stopMotionClock
          ..pause()
          ..pause();

        expect(recorder.events.whereType<_Playing>(), hasLength(2));
      });
    });

    group('seek', () {
      testWidgets('while paused moves the playhead without starting the '
          'clock', (tester) async {
        build();
        const target = Duration(milliseconds: 700);

        stopMotionClock.seek(target);
        await tester.pump(frame);

        expect(stopMotionClock.isPlaying, isFalse);
        expect(recorder.events, const [
          _PlayTime(target),
          _AudioSync(target, isPlaying: false, isSeek: true),
          _Position(target),
        ]);
      });

      testWidgets('while playing re-anchors so playback continues from '
          'there', (tester) async {
        build();
        stopMotionClock.play(from: Duration.zero);
        await tester.pump(frame);
        recorder.events.clear();
        const target = Duration(seconds: 1);

        stopMotionClock.seek(target);
        await tester.pump(frame);

        expect(recorder.events, const [
          _PlayTime(target),
          _AudioSync(target, isPlaying: true, isSeek: true),
          _Position(target),
          _PlayTime(Duration(seconds: 1, milliseconds: 16)),
          _AudioSync(
            Duration(seconds: 1, milliseconds: 16),
            isPlaying: true,
            isSeek: false,
          ),
        ]);
        stopMotionClock.pause();
      });

      testWidgets('clamps the target into the loop', (tester) async {
        build();

        stopMotionClock
          ..seek(const Duration(seconds: 5))
          ..seek(const Duration(seconds: -1));

        expect(recorder.positions, [
          _Position(recorder.total),
          const _Position(Duration.zero),
        ]);
      });

      testWidgets('lands on zero when the loop is empty', (tester) async {
        build();
        recorder.total = Duration.zero;

        stopMotionClock.seek(const Duration(seconds: 1));

        expect(recorder.positions.single, const _Position(Duration.zero));
      });
    });

    group('dispose', () {
      testWidgets('releases the ticker so no further frames tick', (
        tester,
      ) async {
        build();
        stopMotionClock.play(from: Duration.zero);
        await tester.pump(frame);
        recorder.events.clear();

        stopMotionClock.dispose();
        await tester.pump(frame);

        expect(recorder.events, isEmpty);
      });
    });
  });
}
