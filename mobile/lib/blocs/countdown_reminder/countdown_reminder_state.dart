part of 'countdown_reminder_cubit.dart';

/// What the last tap on a countdown sticker did.
enum CountdownReminderStatus {
  /// Nothing tapped yet.
  idle,

  /// A reminder is set for when the countdown ends.
  scheduled,

  /// The reminder set before is removed.
  cancelled,

  /// The app may not show notifications, so no reminder was set.
  notificationsOff,

  /// The countdown is over; there is nothing to remind of.
  over,

  /// The phone could not set the reminder, as on the web.
  failed,
}

/// The outcome of the last tap on a countdown sticker.
class CountdownReminderState extends Equatable {
  const CountdownReminderState({
    this.status = CountdownReminderStatus.idle,
    this.taps = 0,
  });

  final CountdownReminderStatus status;

  /// How many taps have had an outcome, so a second tap with the same one
  /// still tells the viewer again.
  final int taps;

  CountdownReminderState _next(CountdownReminderStatus status) =>
      CountdownReminderState(status: status, taps: taps + 1);

  @override
  List<Object?> get props => [status, taps];
}
