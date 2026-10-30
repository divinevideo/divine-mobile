// ABOUTME: What a countdown sticker on a playing video shows and says: the
// ABOUTME: time left over its date, and what a tap did with its reminder.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/countdown_reminder/countdown_reminder_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/notifications_providers.dart';

/// The time [left] on a countdown, as its sticker shows it in the player:
/// whole days, then hours, minutes and seconds, such as "12 days 04:33:10".
String countdownTimeLeft(AppLocalizations l10n, Duration left) {
  String twoDigits(int value) => value.toString().padLeft(2, '0');
  final clockTime = [
    left.inHours.remainder(Duration.hoursPerDay),
    left.inMinutes.remainder(Duration.minutesPerHour),
    left.inSeconds.remainder(Duration.secondsPerMinute),
  ].map(twoDigits).join(':');
  final days = left.inDays;
  return days == 0
      ? clockTime
      : '${l10n.videoStickerCountdownDays(days)} $clockTime';
}

/// Provides the [CountdownReminderCubit] a tap on a countdown sticker below
/// sets its reminder through, and tells the viewer what each tap did.
class CountdownReminderScope extends ConsumerWidget {
  const CountdownReminderScope({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationServiceProvider);
    return BlocProvider(
      key: ValueKey(notifications),
      create: (_) => CountdownReminderCubit(notifications: notifications),
      child: BlocListener<CountdownReminderCubit, CountdownReminderState>(
        listener: (context, state) {
          final l10n = context.l10n;
          final message = switch (state.status) {
            CountdownReminderStatus.scheduled =>
              l10n.videoStickerCountdownReminderSet,
            CountdownReminderStatus.cancelled =>
              l10n.videoStickerCountdownReminderRemoved,
            CountdownReminderStatus.notificationsOff =>
              l10n.videoStickerCountdownNotificationsOff,
            CountdownReminderStatus.over => l10n.videoStickerCountdownOver,
            // Logged by the service; the web has no reminders to set.
            CountdownReminderStatus.idle ||
            CountdownReminderStatus.failed => null,
          };
          if (message == null) return;
          ScaffoldMessenger.maybeOf(
            context,
          )?.showSnackBar(DivineSnackbarContainer.snackBar(message));
        },
        child: child,
      ),
    );
  }
}
