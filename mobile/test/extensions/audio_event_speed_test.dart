import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/extensions/audio_event_speed.dart';
import 'package:pro_video_editor/pro_video_editor.dart'
    show VideoSpeedRamp, VideoSpeedRampPoint;

/// The window's first half plays at 2x and its second half at 0.5x: half of
/// the sound plays in a quarter of the time, the rest in four times as long.
const _fastThenSlow = VideoSpeedRamp([
  VideoSpeedRampPoint(position: 0, speed: 2),
  VideoSpeedRampPoint(position: 0.5, speed: 2),
  VideoSpeedRampPoint(position: 0.5 + 1e-9, speed: 0.5),
  VideoSpeedRampPoint(position: 1, speed: 0.5),
]);

AudioEvent _sound({
  double playbackSpeed = 1,
  Duration startTime = Duration.zero,
  Duration? endTime = const Duration(seconds: 5),
  double? duration = 30,
}) => AudioEvent(
  id: 'sound',
  pubkey: 'pubkey',
  createdAt: 0,
  url: '/sound.wav',
  duration: duration,
  startOffset: const Duration(seconds: 3),
  startTime: startTime,
  endTime: endTime,
  playbackSpeed: playbackSpeed,
);

/// Within a microsecond either way, as the ramp's steps round.
Matcher _about(Duration expected) => predicate<Duration>(
  (actual) => (actual - expected).inMicroseconds.abs() <= 1,
  'within 1µs of $expected',
);

void main() {
  group('AudioEventSpeed', () {
    group('at a constant speed', () {
      final spedUp = _sound(playbackSpeed: 2);

      test('converts between timeline and sound time', () {
        expect(
          spedUp.sourceSpanOf(const Duration(seconds: 3)),
          const Duration(seconds: 6),
        );
        expect(
          spedUp.timelineSpanOf(const Duration(seconds: 6)),
          const Duration(seconds: 3),
        );
        expect(
          spedUp.sourceOffsetAt(const Duration(seconds: 1)),
          const Duration(seconds: 2),
        );
        expect(
          spedUp.timelineOffsetOf(const Duration(seconds: 2)),
          const Duration(seconds: 1),
        );
      });

      test('has no ramp to read, follow or cut', () {
        expect(spedUp.speedRamp, isNull);
        expect(spedUp.changesSpeed, isTrue);
        expect(_sound().changesSpeed, isFalse);
        expect(spedUp.speedAtSourceOffset(const Duration(seconds: 7)), 2);
        expect(
          spedUp.speedRampBetween(Duration.zero, const Duration(seconds: 1)),
          isNull,
        );
      });
    });

    group('along a speed ramp', () {
      // A 5 s window plays 4 s of the sound along the ramp.
      final ramped = _sound().withSpeedRamp(_fastThenSlow);

      test('reads back the ramp it stores, once per stored map', () {
        expect(ramped.speedRamp, _fastThenSlow);
        expect(identical(ramped.speedRamp, ramped.speedRamp), isTrue);
        expect(ramped.playbackSpeed, 1);
        expect(ramped.changesSpeed, isTrue);
        expect(ramped.withSpeedRamp(null).speedRamp, isNull);
      });

      test('spreads the ramp over the stretch its window plays', () {
        expect(ramped.averageSpeed, closeTo(0.8, 1e-6));
        expect(ramped.playedSourceSpan, _about(const Duration(seconds: 4)));
        expect(
          ramped.timelineSpanOf(const Duration(seconds: 4)),
          _about(const Duration(seconds: 5)),
        );
      });

      test('maps a moment of the sound through the curve', () {
        // Two seconds of sound at 2x take one second of the timeline.
        expect(
          ramped.sourceOffsetAt(const Duration(seconds: 1)),
          _about(const Duration(seconds: 2)),
        );
        expect(
          ramped.timelineOffsetOf(const Duration(seconds: 2)),
          _about(const Duration(seconds: 1)),
        );
        // Then half a second of sound at 0.5x takes another second.
        expect(
          ramped.sourceOffsetAt(const Duration(seconds: 2)),
          _about(const Duration(milliseconds: 2500)),
        );
        expect(
          ramped.timelineOffsetOf(const Duration(milliseconds: 2500)),
          _about(const Duration(seconds: 2)),
        );
      });

      test('plays past either end at the speed of that end', () {
        expect(
          ramped.sourceOffsetAt(const Duration(seconds: 6)),
          _about(const Duration(milliseconds: 4500)),
        );
        expect(
          ramped.sourceOffsetAt(const Duration(seconds: -1)),
          _about(const Duration(seconds: -2)),
        );
        expect(
          ramped.timelineOffsetOf(const Duration(milliseconds: 4500)),
          _about(const Duration(seconds: 6)),
        );
      });

      test('names the speed the render plays at each moment', () {
        expect(ramped.speedAtSourceOffset(const Duration(seconds: 1)), 2);
        expect(ramped.speedAtSourceOffset(const Duration(seconds: 3)), 0.5);
        expect(ramped.speedAtSourceOffset(const Duration(seconds: 9)), 0.5);
      });

      test('cuts into two ramps that keep every moment in place', () {
        final cut = ramped.sourceOffsetAt(const Duration(milliseconds: 1500));
        final head = ramped.speedRampBetween(Duration.zero, cut)!;
        final tail = ramped.speedRampBetween(
          cut,
          ramped.playedSourceSpan!,
        )!;

        expect(
          head.outputDuration(cut),
          _about(const Duration(milliseconds: 1500)),
        );
        expect(
          tail.outputDuration(ramped.playedSourceSpan! - cut),
          _about(const Duration(milliseconds: 3500)),
        );
        expect(head.points.first.speed, 2);
        expect(tail.points.last.speed, 0.5);
      });

      test('runs to the end of the sound without a window', () {
        final open = _sound(
          endTime: null,
        ).withSpeedRamp(_fastThenSlow);
        expect(open.playedSourceSpan, const Duration(seconds: 27));
        expect(
          _sound(endTime: null, duration: null).playedSourceSpan,
          isNull,
        );
      });
    });
  });
}
