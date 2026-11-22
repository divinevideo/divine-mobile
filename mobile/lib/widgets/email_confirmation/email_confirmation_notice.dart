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
/// the reminder shows over whichever screen is open.
class EmailConfirmationNotice extends StatelessWidget {
  const EmailConfirmationNotice({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<EmailConfirmationCubit, EmailConfirmationState>(
          listenWhen: (previous, current) =>
              current.isUnconfirmed &&
              (!previous.isUnconfirmed || previous.account != current.account),
          listener: (context, state) {
            final email = state.email;
            if (email == null) return;
            final l10n = context.l10n;
            ScaffoldMessenger.maybeOf(context)?.showSnackBar(
              DivineSnackbarContainer.snackBar(
                l10n.emailConfirmationNotice(email),
                duration: const Duration(seconds: 8),
                actionLabel: l10n.emailConfirmationResendButton,
                onActionPressed: () => runDetached(
                  context.read<EmailConfirmationCubit>().resend(),
                  'resend confirmation email',
                  logName: 'EmailConfirmationNotice',
                  category: LogCategory.auth,
                ),
              ),
            );
          },
        ),
        BlocListener<EmailConfirmationCubit, EmailConfirmationState>(
          listenWhen: (previous, current) =>
              previous.resendStatus != current.resendStatus &&
              (current.resendStatus == EmailConfirmationResendStatus.sent ||
                  current.resendStatus == EmailConfirmationResendStatus.failed),
          listener: (context, state) {
            final failed =
                state.resendStatus == EmailConfirmationResendStatus.failed;
            final l10n = context.l10n;
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
          },
        ),
      ],
      child: child,
    );
  }
}
