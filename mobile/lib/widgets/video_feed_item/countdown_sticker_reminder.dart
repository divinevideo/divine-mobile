// ABOUTME: What a tap on a countdown sticker in the player did with its
// ABOUTME: reminder, told to the viewer in a snackbar.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/countdown_reminder/countdown_reminder_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/notifications_providers.dart';

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
            // Logged by the service.
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
