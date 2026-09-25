// ABOUTME: Pure rules for when a post may be scheduled (#3538): the earliest
// ABOUTME: and latest allowed time, the picker's step, and the quick presets.

/// The choices the "Post time" tile offers.
enum ScheduleTimeOption { now, tonight, tomorrowMorning, custom }

/// Why a chosen time is not usable, or [ok].
enum ScheduleTimeValidation { ok, tooSoon, tooFar }

/// Bounds and presets for a scheduled publish time.
///
/// The relay accepts anything more than 60 s out and up to 90 days ahead
/// and publishes on a five-minute sweep. The app asks for more room: an
/// upload plus a remote signature can take minutes, and a post the relay
/// would refuse as "not far enough in the future" is posted immediately,
/// which is not what someone who just picked a time expects.
abstract final class ScheduleTimePolicy {
  /// Earliest lead the picker allows.
  static const Duration minLead = Duration(minutes: 15);

  /// The picker's minute step; presets and the minimum snap to it.
  static const Duration step = Duration(minutes: 5);

  /// Latest lead the picker allows: the relay's 90-day horizon with an hour
  /// spare, since the relay measures the horizon against its own clock.
  static const Duration maxLead = Duration(hours: 90 * 24 - 1);

  static const int _tonightHour = 20;
  static const int _morningHour = 9;

  /// [now] + [minLead], rounded up to the next [step] boundary.
  static DateTime minScheduleTime(DateTime now) =>
      roundUpToStep(now.add(minLead));

  /// [now] + [maxLead].
  static DateTime maxScheduleTime(DateTime now) => now.add(maxLead);

  /// The next [step] boundary at or after [time], seconds dropped.
  static DateTime roundUpToStep(DateTime time) {
    final floor = time.isUtc
        ? DateTime.utc(time.year, time.month, time.day, time.hour, time.minute)
        : DateTime(time.year, time.month, time.day, time.hour, time.minute);
    final remainder = floor.minute % step.inMinutes;
    if (remainder == 0 && floor.isAtSameMomentAs(time)) return floor;
    final minutesUp = remainder == 0
        ? step.inMinutes
        : step.inMinutes - remainder;
    return floor.add(Duration(minutes: minutesUp));
  }

  /// Whether [time] can be scheduled at [now].
  static ScheduleTimeValidation validate(DateTime time, DateTime now) {
    if (time.isBefore(minScheduleTime(now))) {
      return ScheduleTimeValidation.tooSoon;
    }
    if (time.isAfter(maxScheduleTime(now))) {
      return ScheduleTimeValidation.tooFar;
    }
    return ScheduleTimeValidation.ok;
  }

  /// Today at 20:00 local time, or null once that is too soon to pick.
  static DateTime? tonight(DateTime now) {
    final candidate = DateTime(now.year, now.month, now.day, _tonightHour);
    return candidate.isBefore(minScheduleTime(now)) ? null : candidate;
  }

  /// Tomorrow at 09:00 local time.
  static DateTime tomorrowMorning(DateTime now) =>
      DateTime(now.year, now.month, now.day + 1, _morningHour);

  /// The option [current] came from, so reopening the menu ticks back what
  /// the last visit chose rather than always landing on
  /// [ScheduleTimeOption.custom].
  ///
  /// Compares instants, so a stored UTC time still matches a local preset.
  static ScheduleTimeOption optionFor(DateTime? current, DateTime now) {
    if (current == null) return ScheduleTimeOption.now;
    final tonightAt = tonight(now);
    if (tonightAt != null && current.isAtSameMomentAs(tonightAt)) {
      return ScheduleTimeOption.tonight;
    }
    if (current.isAtSameMomentAs(tomorrowMorning(now))) {
      return ScheduleTimeOption.tomorrowMorning;
    }
    return ScheduleTimeOption.custom;
  }

  /// The time a preset stands for at [now]; null for [ScheduleTimeOption.now]
  /// and for a preset that is not available any more.
  static DateTime? resolve(ScheduleTimeOption option, DateTime now) =>
      switch (option) {
        ScheduleTimeOption.now => null,
        ScheduleTimeOption.tonight => tonight(now),
        ScheduleTimeOption.tomorrowMorning => tomorrowMorning(now),
        ScheduleTimeOption.custom => null,
      };
}
