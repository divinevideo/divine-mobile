// ABOUTME: Shows the app-wide "confirm your email" reminder and the outcome of
// ABOUTME: a resend request, wherever in the app the request was made.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/email_confirmation/email_confirmation_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:unified_logger/unified_logger.dart';

/// Reminds an account that signed in before confirming its email, once each
/// time the app learns the email is still unconfirmed, and reports resends.
///
/// Mounted in `MaterialApp.builder`, below the app's [ScaffoldMessenger], so
/// the reminder shows over whichever screen is open. The reminder names one
/// account's address, so it is closed as soon as that account signs out, is
/// switched away from, or confirms.
class EmailConfirmationNotice extends StatefulWidget {
  const EmailConfirmationNotice({required this.child, super.key});

  final Widget child;

  @override
  State<EmailConfirmationNotice> createState() =>
      _EmailConfirmationNoticeState();
}

class _EmailConfirmationNoticeState extends State<EmailConfirmationNotice> {
  ({String account, String email, VoidCallback dismiss})? _reminder;

  void _closeReminder() {
    final reminder = _reminder;
    _reminder = null;
    reminder?.dismiss();
  }

  void _showReminder(
    EmailConfirmationCubit cubit,
    EmailConfirmationState state,
  ) {
    final email = state.email;
    final account = state.account;
    if (email == null || account == null) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    final l10n = context.l10n;
    _closeReminder();

    var cancelled = false;
    var visible = false;
    late final ScaffoldFeatureController<SnackBar, SnackBarClosedReason>
    controller;
    void dismiss() {
      cancelled = true;
      // A ScaffoldMessenger controller may only close the first snackbar.
      if (visible && messenger.mounted) controller.close();
    }

    controller = messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 8),
        backgroundColor: VineTheme.transparent,
        elevation: 0,
        padding: EdgeInsets.zero,
        behavior: SnackBarBehavior.floating,
        onVisible: () {
          visible = true;
          if (cancelled) dismiss();
        },
        content: BlocBuilder<EmailConfirmationCubit, EmailConfirmationState>(
          bloc: cubit,
          builder: (context, current) {
            if (cancelled ||
                current.account != account ||
                current.email != email ||
                !current.isUnconfirmed) {
              return const SizedBox.shrink();
            }
            return DivineSnackbarContainer(
              label: l10n.emailConfirmationNotice(email),
              actionLabel: l10n.emailConfirmationResendButton,
              onActionPressed: () => runDetached(
                cubit.resend(account: account),
                'resend confirmation email',
                logName: 'EmailConfirmationNotice',
                category: LogCategory.auth,
              ),
            );
          },
        ),
      ),
    );
    _reminder = (account: account, email: email, dismiss: dismiss);
    runDetached(
      controller.closed.then((_) {
        visible = false;
        if (identical(_reminder?.dismiss, dismiss)) _reminder = null;
      }),
      'forget closed confirmation reminder',
      logName: 'EmailConfirmationNotice',
      category: LogCategory.ui,
    );
  }

  void _showCapReached(
    EmailConfirmationCubit cubit,
    EmailConfirmationState state,
  ) {
    final account = state.account;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (account == null || messenger == null) return;
    final l10n = context.l10n;
    _closeReminder();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        DivineSnackbarContainer.snackBar(
          l10n.emailConfirmationCapReached,
          duration: const Duration(seconds: 8),
          actionLabel: l10n.emailConfirmationResendButton,
          onActionPressed: () => runDetached(
            cubit.resend(account: account),
            'resend confirmation email',
            logName: 'EmailConfirmationNotice',
            category: LogCategory.auth,
          ),
        ),
      );
  }

  void _showResendOutcome(EmailConfirmationState state) {
    final failed = state.resendStatus == EmailConfirmationResendStatus.failed;
    final l10n = context.l10n;
    _closeReminder();
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        DivineSnackbarContainer.snackBar(
          failed
              ? l10n.emailConfirmationResendFailed
              : l10n.emailConfirmationResendSent,
          error: failed,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    // Absent only in trees built without the app composition root.
    final cubit = context.read<EmailConfirmationCubit?>();
    if (cubit == null) return widget.child;
    return MultiBlocListener(
      listeners: [
        BlocListener<EmailConfirmationCubit, EmailConfirmationState>(
          bloc: cubit,
          listener: (context, state) {
            final reminder = _reminder;
            if (reminder != null &&
                (state.account != reminder.account ||
                    state.email != reminder.email ||
                    !state.isUnconfirmed)) {
              _closeReminder();
            }
          },
        ),
        BlocListener<EmailConfirmationCubit, EmailConfirmationState>(
          bloc: cubit,
          listenWhen: (previous, current) =>
              current.isUnconfirmed &&
              (!previous.isUnconfirmed ||
                  previous.account != current.account ||
                  previous.email != current.email),
          listener: (context, state) => _showReminder(cubit, state),
        ),
        BlocListener<EmailConfirmationCubit, EmailConfirmationState>(
          bloc: cubit,
          listenWhen: (previous, current) =>
              previous.account == current.account &&
              current.capRefusals > previous.capRefusals,
          listener: (context, state) => _showCapReached(cubit, state),
        ),
        BlocListener<EmailConfirmationCubit, EmailConfirmationState>(
          bloc: cubit,
          listenWhen: (previous, current) =>
              previous.account == current.account &&
              previous.resendStatus != current.resendStatus &&
              (current.resendStatus == EmailConfirmationResendStatus.sent ||
                  current.resendStatus == EmailConfirmationResendStatus.failed),
          listener: (context, state) => _showResendOutcome(state),
        ),
      ],
      child: widget.child,
    );
  }
}
