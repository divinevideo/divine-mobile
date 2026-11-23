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
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _reminder;

  /// The account the open reminder was shown for.
  String? _reminderAccount;

  void _closeReminder() {
    _reminder?.close();
    _reminder = null;
    _reminderAccount = null;
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
    final reminder = messenger.showSnackBar(
      DivineSnackbarContainer.snackBar(
        l10n.emailConfirmationNotice(email),
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
    _reminder = reminder;
    _reminderAccount = account;
    runDetached(
      reminder.closed.then((_) {
        if (identical(_reminder, reminder)) {
          _reminder = null;
          _reminderAccount = null;
        }
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
            final reminderIsStale =
                _reminder != null &&
                (state.account != _reminderAccount || !state.isUnconfirmed);
            if (reminderIsStale) _closeReminder();
          },
        ),
        BlocListener<EmailConfirmationCubit, EmailConfirmationState>(
          bloc: cubit,
          listenWhen: (previous, current) =>
              current.isUnconfirmed &&
              (!previous.isUnconfirmed || previous.account != current.account),
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
