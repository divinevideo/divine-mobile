// ABOUTME: Tests for ScheduleTimePolicy: bounds, step rounding and the
// ABOUTME: quick presets of the "Post time" picker.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_metadata/schedule_time_policy.dart';

void main() {
  group(ScheduleTimePolicy, () {
    group('roundUpToStep', () {
      test('keeps a time already on the step', () {
        final time = DateTime(2026, 9, 22, 12, 15);
        expect(ScheduleTimePolicy.roundUpToStep(time), time);
      });

      test('rounds up seconds and minutes to the next step', () {
        expect(
          ScheduleTimePolicy.roundUpToStep(DateTime(2026, 9, 22, 12, 15, 1)),
          DateTime(2026, 9, 22, 12, 20),
        );
        expect(
          ScheduleTimePolicy.roundUpToStep(DateTime(2026, 9, 22, 12, 16)),
          DateTime(2026, 9, 22, 12, 20),
        );
        expect(
          ScheduleTimePolicy.roundUpToStep(DateTime(2026, 9, 22, 12, 59)),
          DateTime(2026, 9, 22, 13),
        );
      });

      test('keeps the time zone of its input', () {
        final rounded = ScheduleTimePolicy.roundUpToStep(
          DateTime.utc(2026, 9, 22, 12, 16),
        );
        expect(rounded.isUtc, isTrue);
        expect(rounded, DateTime.utc(2026, 9, 22, 12, 20));
      });
    });

    group('bounds', () {
      final now = DateTime(2026, 9, 22, 12, 3, 30);

      test('the earliest time is 15 minutes out, on the step', () {
        expect(
          ScheduleTimePolicy.minScheduleTime(now),
          DateTime(2026, 9, 22, 12, 20),
        );
      });

      test('the latest time is an hour short of 90 days', () {
        expect(
          ScheduleTimePolicy.maxScheduleTime(now),
          now.add(const Duration(days: 90)).subtract(const Duration(hours: 1)),
        );
      });

      test('validate classifies too soon, ok and too far', () {
        expect(
          ScheduleTimePolicy.validate(DateTime(2026, 9, 22, 12, 15), now),
          ScheduleTimeValidation.tooSoon,
        );
        expect(
          ScheduleTimePolicy.validate(DateTime(2026, 9, 22, 12, 20), now),
          ScheduleTimeValidation.ok,
        );
        expect(
          ScheduleTimePolicy.validate(
            now.add(const Duration(days: 90)),
            now,
          ),
          ScheduleTimeValidation.tooFar,
        );
      });
    });

    group('presets', () {
      test('tonight is 20:00 today while that is far enough away', () {
        final now = DateTime(2026, 9, 22, 12);
        expect(
          ScheduleTimePolicy.tonight(now),
          DateTime(2026, 9, 22, 20),
        );
        expect(
          ScheduleTimePolicy.resolve(ScheduleTimeOption.tonight, now),
          DateTime(2026, 9, 22, 20),
        );
      });

      test('tonight disappears once 20:00 is too close or past', () {
        expect(
          ScheduleTimePolicy.tonight(DateTime(2026, 9, 22, 19, 50)),
          isNull,
        );
        expect(ScheduleTimePolicy.tonight(DateTime(2026, 9, 22, 23)), isNull);
      });

      test('tomorrow morning is 09:00 the next day', () {
        expect(
          ScheduleTimePolicy.tomorrowMorning(DateTime(2026, 9, 22, 23, 50)),
          DateTime(2026, 9, 23, 9),
        );
        expect(
          ScheduleTimePolicy.tomorrowMorning(DateTime(2026, 12, 31, 10)),
          DateTime(2027, 1, 1, 9),
        );
      });

      test('now and custom resolve to no preset time', () {
        final now = DateTime(2026, 9, 22, 12);
        expect(ScheduleTimePolicy.resolve(ScheduleTimeOption.now, now), isNull);
        expect(
          ScheduleTimePolicy.resolve(ScheduleTimeOption.custom, now),
          isNull,
        );
      });
    });

    group('optionFor', () {
      final now = DateTime(2026, 9, 22, 12);

      test('no time is "now"', () {
        expect(
          ScheduleTimePolicy.optionFor(null, now),
          ScheduleTimeOption.now,
        );
      });

      test('a preset time is that preset, not custom', () {
        expect(
          ScheduleTimePolicy.optionFor(ScheduleTimePolicy.tonight(now), now),
          ScheduleTimeOption.tonight,
        );
        expect(
          ScheduleTimePolicy.optionFor(
            ScheduleTimePolicy.tomorrowMorning(now),
            now,
          ),
          ScheduleTimeOption.tomorrowMorning,
        );
      });

      test('a preset stored as UTC still matches its local preset', () {
        expect(
          ScheduleTimePolicy.optionFor(
            ScheduleTimePolicy.tonight(now)!.toUtc(),
            now,
          ),
          ScheduleTimeOption.tonight,
        );
      });

      test('any other time is custom', () {
        expect(
          ScheduleTimePolicy.optionFor(DateTime(2026, 9, 22, 18, 35), now),
          ScheduleTimeOption.custom,
        );
      });

      test('tonight past its cut-off falls back to custom', () {
        final late = DateTime(2026, 9, 22, 19, 55);
        expect(ScheduleTimePolicy.tonight(late), isNull);
        expect(
          ScheduleTimePolicy.optionFor(DateTime(2026, 9, 22, 20), late),
          ScheduleTimeOption.custom,
        );
      });
    });
  });
}
