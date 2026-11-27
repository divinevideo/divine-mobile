import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/email_confirmation/email_confirmation_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:unified_logger/unified_logger.dart';

/// Shows the email confirmation action and its result inside a share sheet.
class EmailConfirmationSharePrompt extends StatefulWidget {
  const EmailConfirmationSharePrompt({super.key});

  @override
  State<EmailConfirmationSharePrompt> createState() =>
      _EmailConfirmationSharePromptState();
}

class _EmailConfirmationSharePromptState
    extends State<EmailConfirmationSharePrompt> {
  String? _resendAccount;

  @override
  Widget build(BuildContext context) {
    final (account, resendStatus) = context.select(
      (EmailConfirmationCubit cubit) =>
          (cubit.state.account, cubit.state.resendStatus),
    );
    final l10n = context.l10n;
    final canResend =
        account != null &&
        resendStatus != EmailConfirmationResendStatus.sending;
    final outcome = account == _resendAccount ? resendStatus : null;

    return Semantics(
      liveRegion: true,
      child: DivineSnackbarContainer(
        label: switch (outcome) {
          EmailConfirmationResendStatus.sent =>
            l10n.emailConfirmationResendSent,
          EmailConfirmationResendStatus.failed =>
            l10n.emailConfirmationResendFailed,
          _ => l10n.emailConfirmationSendBlocked,
        },
        error: outcome == EmailConfirmationResendStatus.failed,
        actionLabel: canResend ? l10n.emailConfirmationResendButton : null,
        onActionPressed: canResend
            ? () {
                setState(() => _resendAccount = account);
                runDetached(
                  context.read<EmailConfirmationCubit>().resend(
                    account: account,
                  ),
                  'resend confirmation email from share sheet',
                  logName: 'EmailConfirmationSharePrompt',
                  category: LogCategory.auth,
                );
              }
            : null,
      ),
    );
  }
}
