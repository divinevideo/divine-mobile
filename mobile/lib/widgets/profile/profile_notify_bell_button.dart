// ABOUTME: Follow-gated bell on a creator's profile that subscribes the
// ABOUTME: viewer to their new posts. Optimistic, reverts on publish failure.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/notify_bell/notify_bell_cubit.dart';
import 'package:openvine/l10n/l10n.dart';

/// Bell toggle shown next to Follow once the viewer follows the creator.
///
/// Expects a [NotifyBellCubit] above it — `ProfileActionButtons` provides one
/// so the cubit outlives this widget's follow-gated mount and can still run
/// unfollow teardown after the bell disappears.
class ProfileNotifyBellButton extends StatelessWidget {
  const ProfileNotifyBellButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<NotifyBellCubit, NotifyBellState>(
      listenWhen: (previous, current) =>
          current.status == NotifyBellStatus.failure &&
          previous.status != NotifyBellStatus.failure,
      listener: (context, state) {
        ScaffoldMessenger.of(context).showSnackBar(
          DivineSnackbarContainer.snackBar(
            context.l10n.profileNotifyUpdateFailed,
            error: true,
          ),
        );
      },
      builder: (context, state) {
        final l10n = context.l10n;
        return DivineIconButton(
          icon: .bellSimple,
          // Filled while subscribed so the on state reads at a glance in a row
          // of otherwise-secondary buttons.
          type: state.isSubscribed
              ? DivineIconButtonType.primary
              : DivineIconButtonType.secondary,
          size: .small,
          semanticLabel: state.isSubscribed
              ? l10n.profileNotifyBellOn
              : l10n.profileNotifyBellOff,
          tooltip: state.isSubscribed
              ? l10n.profileNotifyBellOn
              : l10n.profileNotifyBellOff,
          onPressed: state.isInteractive
              ? () => context.read<NotifyBellCubit>().toggle()
              : null,
        );
      },
    );
  }
}
