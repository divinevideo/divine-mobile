// ABOUTME: Timer duration enum for the recorder's timer button
// ABOUTME: A delayed start for video modes, the repeat interval in stop-motion

import 'package:divine_ui/divine_ui.dart';

/// Timer settings the recorder's timer button cycles through.
///
/// Video modes count down once before the take starts. Stop-motion counts
/// down before every still. `VideoRecorderMode.timerDurations` says which
/// mode offers which values.
enum TimerDuration {
  /// No timer.
  off,

  /// 2 seconds.
  two,

  /// 3 seconds.
  three,

  /// 5 seconds.
  five,

  /// 10 seconds.
  ten;

  /// Icon representing the timer duration.
  DivineIconName get icon => switch (this) {
    .off => .timer,
    .two => .timer2,
    .three => .timer3,
    .five => .timer5,
    .ten => .timer10,
  };

  /// Duration value for the timer.
  Duration get duration => switch (this) {
    .off => Duration.zero,
    .two => const Duration(seconds: 2),
    .three => const Duration(seconds: 3),
    .five => const Duration(seconds: 5),
    .ten => const Duration(seconds: 10),
  };
}
